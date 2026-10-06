import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/speech_service.dart';

final speechServiceProvider = Provider<SpeechService>((ref) {
  final service = NativeSpeechService();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

class NativeSpeechService implements SpeechService {
  NativeSpeechService({MethodChannel? methods, Stream<Object?>? eventStream})
    : _methods = methods ?? const MethodChannel('finance_ai/speech') {
    if (eventStream != null) {
      _connection = Future<void>.value();
      _subscribe(eventStream);
    }
  }

  final MethodChannel _methods;
  final _events = StreamController<SpeechEvent>.broadcast(sync: true);
  StreamSubscription<Object?>? _subscription;
  Future<void>? _connection;
  bool _disposed = false;

  void _subscribe(Stream<Object?> stream) {
    if (_disposed) return;
    _subscription = stream.listen(
      (value) {
        try {
          _events.add(_event(value));
        } catch (_) {
          _events.addError(const SpeechFailure('speech_provider_error'));
        }
      },
      onError: (_) =>
          _events.addError(const SpeechFailure('speech_provider_error')),
      onDone: () => _events.close(),
    );
  }

  Future<void> _connect() => _connection ??= () async {
    // An old native bundle (or an unsupported target) stays usable for typing.
    // Check registration before connecting the event channel.
    await _methods.invokeMethod<void>('initialize');
    if (_disposed) throw const SpeechFailure('speech_offline_unavailable');
    _subscribe(
      const EventChannel('finance_ai/speech/events').receiveBroadcastStream(),
    );
  }();

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    if (!_events.isClosed) await _events.close();
  }

  static SpeechEvent _event(Object? value) {
    if (value is! Map || value['session'] is! int) {
      throw const SpeechFailure('speech_provider_error');
    }
    final type = switch (value['type']) {
      'ready' => SpeechEventType.ready,
      'listening' => SpeechEventType.listening,
      'partial' => SpeechEventType.partial,
      'final' => SpeechEventType.finalResult,
      'error' => SpeechEventType.error,
      _ => throw const SpeechFailure('speech_provider_error'),
    };
    final text = value['text'];
    if (text != null && (text is! String || text.length > 8192)) {
      throw const SpeechFailure('speech_provider_error');
    }
    return SpeechEvent(
      session: value['session'] as int,
      type: type,
      text: text as String? ?? '',
      code: SpeechFailure.safeCode(value['code'] as String?),
      canDownload: value['canDownload'] == true,
    );
  }

  @override
  Stream<SpeechEvent> get events => _events.stream;

  Future<void> _call(String method, [Map<String, Object>? arguments]) async {
    try {
      await _connect();
      if (_disposed) throw const SpeechFailure('speech_offline_unavailable');
      await _methods.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      throw const SpeechFailure('speech_offline_unavailable');
    } on PlatformException catch (error) {
      // Native messages/details are untrusted. Never copy them into reports.
      throw SpeechFailure(SpeechFailure.safeCode(error.code));
    }
  }

  Map<String, Object> _arguments(int session, SpeechLanguage language) => {
    'session': session,
    'language': language.tag,
  };

  @override
  Future<void> prepare(int session, SpeechLanguage language) =>
      _call('prepare', _arguments(session, language));
  @override
  Future<void> start(int session, SpeechLanguage language) =>
      _call('start', _arguments(session, language));
  @override
  Future<void> stop(int session) => _call('stop', {'session': session});
  @override
  Future<void> cancel(int session) => _call('cancel', {'session': session});
  @override
  Future<void> download(int session, SpeechLanguage language) =>
      _call('download', _arguments(session, language));
  @override
  Future<void> openSettings() => _call('settings');
}
