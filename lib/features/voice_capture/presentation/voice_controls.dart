import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/theme/app_palette.dart';
import '../application/voice_capture_controller.dart';
import '../domain/speech_service.dart';

class VoiceControls extends StatelessWidget {
  const VoiceControls({
    required this.controller,
    required this.targetKey,
    required this.nearTarget,
    required this.occupied,
    required this.keepTarget,
    required this.onClose,
    super.key,
  });

  final VoiceCaptureController controller;
  final GlobalKey targetKey;
  final bool nearTarget, occupied, keepTarget;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final phase = controller.phase;
    final pending =
        phase == VoicePhase.preparing ||
        phase == VoicePhase.starting ||
        phase == VoicePhase.finalizing;
    final diagnostic = controller.diagnostic;
    final desktop = defaultTargetPlatform != TargetPlatform.android;
    final showTarget = !desktop && (controller.capturing || keepTarget);
    final status = switch (phase) {
      VoicePhase.preparing => 'Preparando dictado local…',
      VoicePhase.ready => 'Dictado sin conexión',
      VoicePhase.starting => 'Abriendo micrófono…',
      VoicePhase.listening => 'Escuchando…',
      VoicePhase.finalizing => 'Micrófono detenido · terminando…',
      VoicePhase.review => 'Revisa el dictado antes de enviar',
      VoicePhase.failed => 'Dictado no disponible',
    };
    return Padding(
      key: const Key('voice-controls'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 744),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (pending)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      controller.capturing ? Icons.mic : Icons.mic_outlined,
                      size: 18,
                      color: palette.primary,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        status,
                        style: TextStyle(fontSize: 12, color: palette.muted),
                      ),
                    ),
                  ),
                  DropdownButton<SpeechLanguage>(
                    key: const Key('voice-language'),
                    value: controller.language,
                    underline: const SizedBox.shrink(),
                    style: TextStyle(fontSize: 12, color: palette.text),
                    items: [
                      for (final language in SpeechLanguage.values)
                        DropdownMenuItem(
                          value: language,
                          child: Text(language.label),
                        ),
                    ],
                    onChanged: controller.active
                        ? null
                        : (language) {
                            if (language != null) controller.prepare(language);
                          },
                  ),
                  IconButton(
                    key: const Key('voice-close'),
                    tooltip: 'Cerrar dictado y conservar texto',
                    onPressed: onClose,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              if (diagnostic != null) ...[
                Text(
                  diagnostic.userMessage,
                  key: const Key('voice-error-message'),
                  style: TextStyle(fontSize: 12, color: palette.discard),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    TextButton(
                      key: const Key('voice-error-details'),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Error de dictado'),
                          content: SingleChildScrollView(
                            child: ErrorDiagnosticPanel(diagnostic: diagnostic),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cerrar'),
                            ),
                          ],
                        ),
                      ),
                      child: const Text('Detalles'),
                    ),
                    TextButton(
                      key: const Key('voice-retry'),
                      onPressed: controller.active ? null : controller.prepare,
                      child: const Text('Comprobar dictado'),
                    ),
                    if (controller.canDownload)
                      TextButton(
                        key: const Key('voice-download'),
                        onPressed: controller.download,
                        child: const Text('Descargar modelo'),
                      )
                    else
                      TextButton(
                        key: const Key('voice-settings'),
                        onPressed: controller.openSettings,
                        child: const Text('Abrir ajustes'),
                      ),
                  ],
                ),
              ] else if (phase == VoicePhase.review)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('voice-discard'),
                    onPressed: controller.discard,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Descartar dictado'),
                  ),
                )
              else if (desktop && controller.capturing)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const Key('voice-review-stop'),
                    onPressed: controller.finishForReview,
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: const Text('Detener y revisar'),
                  ),
                )
              else if (!showTarget)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    desktop
                        ? 'Pulsa el micrófono para hablar.'
                        : 'Mantén para hablar · suelta para analizar.',
                    style: TextStyle(fontSize: 12, color: palette.muted),
                  ),
                ),
              if (showTarget) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedContainer(
                    key: targetKey,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 120),
                    width: 140,
                    height: 48,
                    decoration: BoxDecoration(
                      color: nearTarget || occupied
                          ? palette.primarySoft
                          : palette.soft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: nearTarget || occupied
                            ? palette.primary
                            : palette.line,
                      ),
                    ),
                    child: Opacity(
                      opacity: occupied ? 0 : 1,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: nearTarget ? palette.primary : palette.muted,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              nearTarget
                                  ? 'Entra para revisar'
                                  : 'Sube para editar',
                              style: TextStyle(
                                fontSize: 12,
                                color: nearTarget
                                    ? palette.primary
                                    : palette.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Swept hit testing also catches a fast move that skips the visible zone.
bool voiceDragCrosses(Offset start, Offset end, Rect zone) {
  var low = 0.0, high = 1.0;
  for (final axis in [
    (start.dx, end.dx, zone.left, zone.right),
    (start.dy, end.dy, zone.top, zone.bottom),
  ]) {
    final delta = axis.$2 - axis.$1;
    if (delta == 0) {
      if (axis.$1 < axis.$3 || axis.$1 > axis.$4) return false;
      continue;
    }
    final a = (axis.$3 - axis.$1) / delta, b = (axis.$4 - axis.$1) / delta;
    low = low > (a < b ? a : b) ? low : (a < b ? a : b);
    high = high < (a > b ? a : b) ? high : (a > b ? a : b);
    if (low > high) return false;
  }
  return true;
}

class VoiceMicButton extends StatefulWidget {
  const VoiceMicButton({
    required this.controller,
    required this.targetKey,
    required this.isBusy,
    required this.onBegin,
    required this.onGesture,
    super.key,
  });

  final VoiceCaptureController controller;
  final GlobalKey targetKey;
  final bool isBusy;
  final VoidCallback onBegin;
  final void Function(bool active, bool near, bool occupied) onGesture;

  @override
  State<VoiceMicButton> createState() => _VoiceMicButtonState();
}

class _VoiceMicButtonState extends State<VoiceMicButton>
    with WidgetsBindingObserver {
  final _micKey = GlobalKey();
  int? _pointer;
  bool _latched = false;
  Offset _origin = Offset.zero, _center = Offset.zero, _offset = Offset.zero;
  bool get _hold => defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _pointer != null) {
      widget.controller.interrupt();
      _pointer = null;
      setState(() {
        _offset = Offset.zero;
        _latched = false;
      });
      widget.onGesture(false, false, false);
    }
  }

  void _toggle() {
    if (widget.controller.capturing) {
      widget.controller.finishForReview();
    } else {
      widget.onBegin();
    }
  }

  void _down(PointerDownEvent event) {
    if (!_hold ||
        widget.isBusy ||
        widget.controller.active ||
        _pointer != null) {
      return;
    }
    final box = _micKey.currentContext!.findRenderObject()! as RenderBox;
    _center = box.localToGlobal(box.size.center(Offset.zero));
    _origin = event.position;
    _pointer = event.pointer;
    _latched = false;
    _offset = Offset.zero;
    widget.onGesture(true, false, false);
    widget.onBegin();
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer || _latched) return;
    if (!widget.controller.active) return;
    final box =
        widget.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final zone = box.localToGlobal(Offset.zero) & box.size;
    final delta = event.position - _origin;
    final next = Offset(
      delta.dx.clamp(
        24 - _center.dx,
        MediaQuery.sizeOf(context).width - 24 - _center.dx,
      ),
      delta.dy.clamp(zone.top - _center.dy - 24, 20),
    );
    final hit = voiceDragCrosses(_center + _offset, _center + next, zone);
    final near = zone.inflate(32).contains(_center + next);
    setState(() {
      _offset = hit ? zone.center - _center : next;
      if (hit) _latched = true;
    });
    widget.onGesture(true, near || hit, hit);
    if (hit) {
      HapticFeedback.selectionClick();
      widget.controller.finishForReview();
    }
  }

  void _end(PointerEvent event, {bool cancelled = false}) {
    if (event.pointer != _pointer) return;
    if (cancelled) {
      widget.controller.interrupt();
    } else if (!_latched) {
      widget.controller.release();
    }
    _pointer = null;
    setState(() {
      _offset = Offset.zero;
      _latched = false;
    });
    widget.onGesture(false, false, false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final blocked =
        widget.isBusy ||
        (widget.controller.phase == VoicePhase.finalizing && _pointer == null);
    return Semantics(
      button: true,
      enabled: !blocked,
      label: 'Dictar mensaje',
      hint: _hold
          ? 'Mantén para hablar. Sube para revisar.'
          : 'Pulsa para empezar o detener el dictado.',
      onTap: blocked ? null : _toggle,
      child: ExcludeSemantics(
        child: Focus(
          canRequestFocus: false,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              widget.controller.interrupt();
              return KeyEventResult.handled;
            }
            if (_hold &&
                !blocked &&
                (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.space)) {
              _toggle();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Listener(
            key: const Key('chat-voice-button'),
            onPointerDown: _down,
            onPointerMove: _move,
            onPointerUp: _end,
            onPointerCancel: (event) => _end(event, cancelled: true),
            child: TweenAnimationBuilder<Offset>(
              tween: Tween<Offset>(begin: Offset.zero, end: _offset),
              duration:
                  _pointer != null && !_latched ||
                      MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              builder: (context, offset, child) => Transform.translate(
                offset: offset,
                transformHitTests: false,
                child: child,
              ),
              child: SizedBox(
                key: _micKey,
                width: 48,
                height: 48,
                child: IconButton.filled(
                  tooltip: widget.controller.capturing
                      ? (_hold
                            ? 'Suelta para analizar o sube para editar'
                            : 'Detener y revisar')
                      : (_hold
                            ? 'Mantén para dictar; sube para revisar'
                            : 'Dictar mensaje'),
                  // Pointer hold/release owns Android actions. Its synthesized tap
                  // must never start a second session, including after cancellation.
                  onPressed: blocked
                      ? null
                      : _hold
                      ? () {}
                      : _toggle,
                  style: IconButton.styleFrom(
                    backgroundColor: widget.controller.capturing || _latched
                        ? palette.primary
                        : palette.primarySoft,
                    foregroundColor: widget.controller.capturing || _latched
                        ? palette.onPrimary
                        : palette.primary,
                    disabledBackgroundColor: palette.soft,
                    disabledForegroundColor: palette.placeholder,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: Icon(
                    _latched
                        ? Icons.edit_outlined
                        : widget.controller.capturing
                        ? Icons.mic
                        : Icons.mic_outlined,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
