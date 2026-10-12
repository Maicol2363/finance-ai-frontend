import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/diagnostics/error_diagnostic.dart';
import '../domain/speech_service.dart';

enum VoicePhase {
  preparing,
  ready,
  starting,
  listening,
  finalizing,
  review,
  failed,
  downloading,
}

/// One recognition session can produce at most one accepted text message.
/// The existing text controller owns AI requests and financial confirmation.
class VoiceCaptureController extends ChangeNotifier {
  // A new Dart runtime also gets a fresh namespace; native messages can outlive
  // a development hot restart. Within the runtime, identifiers only increase.
  static int _nextSession = DateTime.now().microsecondsSinceEpoch;
  VoiceCaptureController({
    required SpeechService service,
    required this.onTranscript,
    required this.onAccepted,
    required this.canSubmit,
    this.finalizationTimeout = const Duration(seconds: 2),
    this.preparationTimeout = const Duration(seconds: 20),
    this.openingTimeout = const Duration(seconds: 12),
  }) : _service = service {
    _subscription = service.events.listen(
      _event,
      onError: (_) => _fail('speech_provider_error'),
    );
  }

  final SpeechService _service;
  final ValueChanged<String> onTranscript;
  final ValueChanged<String> onAccepted;
  final bool Function() canSubmit;
  final Duration finalizationTimeout;
  final Duration preparationTimeout;
  final Duration openingTimeout;
  late final StreamSubscription<SpeechEvent> _subscription;
  Timer? _deadline;
  bool _disposed = false, _held = false, _queued = false;
  bool _automatic = false, _acceptEvents = false, _submitted = false;
  bool _prepared = false;
  int _session = 0;
  String _seed = '';
  VoicePhase phase = VoicePhase.preparing;
  SpeechLanguage language = SpeechLanguage.spanish;
  String transcript = '';
  ErrorDiagnostic? diagnostic;
  bool canDownload = false;
  SpeechEngine engine = SpeechEngine.device;
  SpeechDownloadStage downloadStage = SpeechDownloadStage.requested;
  int? downloadProgress, apiLevel;
  String _reason = 'none', _operation = 'prepare';

  bool get downloading => phase == VoicePhase.downloading;

  int get session => _session;
  bool get capturing =>
      phase == VoicePhase.starting || phase == VoicePhase.listening;
  bool get active => capturing || phase == VoicePhase.finalizing || _queued;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void prepare([SpeechLanguage? selected]) {
    if (_disposed || active || downloading) return;
    if (selected != null) language = selected;
    phase = VoicePhase.preparing;
    diagnostic = null;
    canDownload = false;
    _operation = 'prepare';
    final id = _session = ++_nextSession;
    _deadline?.cancel();
    _deadline = Timer(preparationTimeout, () {
      if (id == _session && phase == VoicePhase.preparing) {
        _fail('speech_preparation_timeout');
      }
    });
    _invoke(() => _service.prepare(id, language), id);
    _changed();
  }

  void begin(String existingText) {
    if (_disposed || active || downloading) return;
    _seed = existingText.trimRight();
    transcript = existingText;
    _held = true;
    _automatic = false;
    _submitted = false;
    diagnostic = null;
    canDownload = false;
    if (phase == VoicePhase.preparing) {
      _queued = true;
      _changed();
      return;
    }
    if (!_prepared) {
      prepare();
      _queued = phase == VoicePhase.preparing && _held;
      if (phase == VoicePhase.ready && _held) {
        _start();
      } else {
        _changed();
      }
      return;
    }
    _start();
  }

  void _start() {
    _queued = false;
    if (!_held || _disposed) return;
    phase = VoicePhase.starting;
    _operation = 'start';
    _acceptEvents = true;
    final id = _session = ++_nextSession;
    _deadline?.cancel();
    _deadline = Timer(openingTimeout, () {
      if (id == _session && phase == VoicePhase.starting) {
        _fail('speech_preparation_timeout');
      }
    });
    _invoke(() => _service.start(id, language), id);
    _changed();
  }

  void release() {
    if (!_held) return;
    _held = false;
    if (_queued) {
      _queued = false;
      _changed();
      return;
    }
    if (capturing) finishForSend();
  }

  void finishForSend() => _finish(true);
  void finishForReview() => _finish(false);

  void _finish(bool automatic) {
    _held = false;
    if (_queued) {
      _queued = false;
      _changed();
      return;
    }
    if (!capturing) return;
    _automatic = automatic;
    phase = VoicePhase.finalizing;
    _deadline?.cancel();
    final id = _session;
    _deadline = Timer(finalizationTimeout, () {
      if (id == _session && phase == VoicePhase.finalizing) {
        _fail('speech_finalize_timeout');
      }
    });
    _invoke(() => _service.stop(id), id);
    _changed();
  }

  void _event(SpeechEvent event) {
    if (_disposed || event.session != _session) return;
    engine = event.engine;
    _reason = SpeechFailure.safeReason(event.reason);
    apiLevel = event.apiLevel ?? apiLevel;
    switch (event.type) {
      case SpeechEventType.ready:
        if (phase != VoicePhase.preparing && !downloading) return;
        _deadline?.cancel();
        diagnostic = null;
        canDownload = false;
        downloadProgress = null;
        phase = VoicePhase.ready;
        _prepared = true;
        if (_queued && _held) {
          _start();
        } else {
          _changed();
        }
      case SpeechEventType.listening:
        if (!_acceptEvents || !capturing) return;
        _deadline?.cancel();
        phase = VoicePhase.listening;
        _changed();
      case SpeechEventType.partial:
        if (!_acceptEvents || (!capturing && phase != VoicePhase.finalizing)) {
          return;
        }
        if (phase == VoicePhase.starting && event.text.trim().isNotEmpty) {
          _deadline?.cancel();
          phase = VoicePhase.listening;
        }
        _update(event.text);
      case SpeechEventType.finalResult:
        if (!_acceptEvents) return;
        final stoppedByUser = phase == VoicePhase.finalizing;
        if (!stoppedByUser && !capturing) return;
        _deadline?.cancel();
        if (event.text.trim().isEmpty) {
          _fail('speech_no_speech');
          return;
        }
        _update(event.text);
        if (!_acceptEvents) return;
        _acceptEvents = false;
        _held = false;
        if (stoppedByUser && _automatic && !_submitted && canSubmit()) {
          _submitted = true;
          phase = VoicePhase.ready;
          _changed();
          onAccepted(transcript.trim());
        } else {
          phase = VoicePhase.review;
          _changed();
        }
      case SpeechEventType.error:
        if (phase != VoicePhase.preparing && !downloading && !_acceptEvents) {
          return;
        }
        canDownload = event.canDownload;
        _fail(SpeechFailure.safeCode(event.code));
      case SpeechEventType.download:
        if (phase != VoicePhase.preparing && !downloading) return;
        _deadline?.cancel();
        phase = VoicePhase.downloading;
        diagnostic = null;
        downloadStage = event.downloadStage;
        downloadProgress = event.progress;
        if (downloadStage == SpeechDownloadStage.loading) {
          final id = _session;
          _deadline = Timer(preparationTimeout, () {
            if (id == _session && downloading) {
              _fail('speech_preparation_timeout');
            }
          });
        }
        _changed();
    }
  }

  void _update(String recognized) {
    transcript = [
      _seed,
      recognized.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    onTranscript(transcript);
    if (transcript.length > 1000) {
      _fail('speech_text_too_long');
    } else {
      _changed();
    }
  }

  void _fail(String code) {
    if (_disposed) return;
    final safe = SpeechFailure.safeCode(code);
    _deadline?.cancel();
    _automatic = false;
    _acceptEvents = false;
    _held = false;
    _queued = false;
    _prepared = false;
    final old = _session;
    _session = ++_nextSession;
    unawaited(_service.cancel(old).catchError((_) {}));
    diagnostic = ErrorDiagnostic.capture(
      code: safe,
      operation: 'voice_capture',
      userMessage: SpeechFailure(safe).userMessage,
      technicalReason:
          '$safe; stage=$_operation; engine=${engine.name}; '
          'cause=$_reason${apiLevel == null ? '' : '; android_api=$apiLevel'}',
    );
    phase = transcript.trim().isNotEmpty
        ? VoicePhase.review
        : SpeechFailure.retryableUtterances.contains(safe)
        ? VoicePhase.ready
        : VoicePhase.failed;
    _changed();
  }

  Future<void> _invoke(Future<void> Function() action, int id) async {
    try {
      await action();
    } on SpeechFailure catch (failure) {
      if (id == _session) _fail(failure.code);
    } catch (_) {
      if (id == _session) _fail('speech_provider_error');
    }
  }

  /// Interruptions preserve visible words, never submit, and reject late events.
  void interrupt() {
    if (_disposed || !active) return;
    _deadline?.cancel();
    _automatic = false;
    _acceptEvents = false;
    _held = false;
    _queued = false;
    _prepared = false;
    final old = _session;
    _session = ++_nextSession;
    unawaited(_service.cancel(old).catchError((_) {}));
    phase = transcript.trim().isEmpty ? VoicePhase.ready : VoicePhase.review;
    _changed();
  }

  void clearAfterSend() {
    final keepDownload = downloading;
    interrupt();
    _acceptEvents = false;
    if (!keepDownload) _session = ++_nextSession;
    transcript = '';
    _seed = '';
    diagnostic = null;
    if (!keepDownload) phase = VoicePhase.ready;
    _changed();
  }

  void discard() {
    interrupt();
    _acceptEvents = false;
    _session = ++_nextSession;
    transcript = _seed;
    onTranscript(_seed);
    diagnostic = null;
    phase = VoicePhase.ready;
    _changed();
  }

  void download() {
    if (_disposed || active || downloading || !canDownload) return;
    phase = VoicePhase.downloading;
    _operation = 'download';
    _queued = false;
    _held = false;
    _prepared = false;
    canDownload = false;
    downloadStage = SpeechDownloadStage.requested;
    downloadProgress = null;
    diagnostic = null;
    final id = _session = ++_nextSession;
    // A download can take longer than preparation. Completion refreshes readiness,
    // but must never start recognition or submit the existing typed draft.
    _deadline?.cancel();
    _invoke(() => _service.download(id, language), id);
    _changed();
  }

  Future<void> openSettings() => _invoke(_service.openSettings, _session);

  /// Returning from permission settings or background downloads never starts the mic.
  void refreshAfterResume() {
    if (_disposed || active) return;
    if (downloading) {
      _invoke(() => _service.prepare(_session, language), _session);
    } else if (diagnostic != null) {
      prepare();
    }
  }

  void closeSetup() {
    if (!downloading) {
      interrupt();
      return;
    }
    _deadline?.cancel();
    final old = _session;
    _session = ++_nextSession;
    unawaited(_service.cancel(old).catchError((_) {}));
    canDownload = true;
    phase = VoicePhase.failed;
    diagnostic = ErrorDiagnostic.capture(
      code: 'speech_fallback_model_missing',
      operation: 'voice_capture',
      userMessage: SpeechFailure('speech_fallback_model_missing').userMessage,
      technicalReason: 'speech_fallback_model_missing',
    );
    _changed();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _deadline?.cancel();
    final old = _session;
    _session = ++_nextSession;
    unawaited(_service.cancel(old).catchError((_) {}));
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
