import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/theme/app_palette.dart';
import '../application/voice_capture_controller.dart';
import '../domain/speech_service.dart';

/// Recording controls sit above the existing message field. Speech state and
/// submission remain owned by the shared capture controller.
class VoiceControls extends StatefulWidget {
  const VoiceControls({
    required this.controller,
    required this.onResume,
    required this.onDiscard,
    required this.onClose,
    this.isBusy = false,
    super.key,
  });

  final VoiceCaptureController controller;
  final VoidCallback onResume, onDiscard, onClose;
  final bool isBusy;

  @override
  State<VoiceControls> createState() => _VoiceControlsState();
}

class _VoiceControlsState extends State<VoiceControls> {
  Timer? _clock;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncClock);
    _syncClock();
  }

  @override
  void didUpdateWidget(VoiceControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncClock);
      widget.controller.addListener(_syncClock);
      _seconds = 0;
      _syncClock();
    }
  }

  void _syncClock() {
    if (widget.controller.phase == VoicePhase.listening) {
      _clock ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
    } else {
      _clock?.cancel();
      _clock = null;
      if (widget.controller.phase == VoicePhase.ready &&
          widget.controller.transcript.isEmpty) {
        _seconds = 0;
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncClock);
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final palette = context.palette;
    final phase = controller.phase;
    final pending =
        phase == VoicePhase.preparing ||
        phase == VoicePhase.starting ||
        phase == VoicePhase.finalizing ||
        controller.downloading;
    final diagnostic = controller.diagnostic;
    final desktop = defaultTargetPlatform != TargetPlatform.android;
    final status = switch (phase) {
      VoicePhase.preparing => 'Preparando dictado local…',
      VoicePhase.ready => 'Dictado sin conexión',
      VoicePhase.starting => 'Abriendo micrófono…',
      VoicePhase.listening => 'Escuchando…',
      VoicePhase.finalizing => 'Micrófono detenido · terminando…',
      VoicePhase.review => 'Pausado · puedes editar',
      VoicePhase.failed =>
        controller.canDownload
            ? 'Prepara el dictado sin conexión'
            : diagnostic?.code.startsWith('speech_permission') == true
            ? 'Permiso del micrófono'
            : 'No se pudo iniciar el dictado',
      VoicePhase.downloading => switch (controller.downloadStage) {
        SpeechDownloadStage.requested => 'Preparando descarga…',
        SpeechDownloadStage.downloading =>
          controller.downloadProgress == null
              ? 'Descargando modelo…'
              : 'Descargando modelo · ${controller.downloadProgress}%',
        SpeechDownloadStage.installing => 'Verificando e instalando modelo…',
        SpeechDownloadStage.loading => 'Preparando dictado local…',
      },
    };
    final statusLabel = Row(
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
      ],
    );
    final language = Tooltip(
      message: 'Idioma del dictado',
      child: DropdownButton<SpeechLanguage>(
        key: const Key('voice-language'),
        value: controller.language,
        underline: const SizedBox.shrink(),
        style: TextStyle(fontSize: 12, color: palette.text),
        items: [
          for (final language in SpeechLanguage.values)
            DropdownMenuItem(
              value: language,
              child: Semantics(
                label: language.label,
                child: Text(language == SpeechLanguage.spanish ? 'ES' : 'EN'),
              ),
            ),
        ],
        onChanged: controller.active || controller.downloading
            ? null
            : (language) {
                if (language != null) controller.prepare(language);
              },
      ),
    );
    final elapsed = Semantics(
      label: 'Duración del dictado',
      child: Text(
        '${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}',
        key: const Key('voice-elapsed'),
        style: TextStyle(fontSize: 12, color: palette.muted),
      ),
    );
    final close = IconButton(
      key: const Key('voice-close'),
      tooltip: 'Cerrar dictado y conservar texto',
      onPressed: widget.onClose,
      icon: const Icon(Icons.close, size: 18),
    );
    return Padding(
      key: const Key('voice-controls'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 744),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final wrapHeader =
                      constraints.maxWidth < 360 &&
                      MediaQuery.textScalerOf(context).scale(12) > 16;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(child: statusLabel),
                          if (!wrapHeader) ...[
                            if (diagnostic == null && !controller.downloading)
                              elapsed,
                            const SizedBox(width: 8),
                            language,
                          ],
                          close,
                        ],
                      ),
                      if (wrapHeader)
                        Row(
                          children: [
                            if (diagnostic == null && !controller.downloading)
                              elapsed,
                            const Spacer(),
                            language,
                          ],
                        ),
                    ],
                  );
                },
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
                      onPressed: controller.active || controller.downloading
                          ? null
                          : controller.prepare,
                      child: const Text('Comprobar dictado'),
                    ),
                    if (controller.canDownload)
                      TextButton(
                        key: const Key('voice-download'),
                        onPressed: controller.download,
                        child: Text(
                          'Descargar ${controller.language.label} · 40 MB',
                        ),
                      )
                    else if (SpeechFailure.settingsFailures.contains(
                          diagnostic.code,
                        ) &&
                        (desktop ||
                            diagnostic.code.startsWith('speech_permission')))
                      TextButton(
                        key: const Key('voice-settings'),
                        onPressed: controller.openSettings,
                        child: Text(
                          diagnostic.code.startsWith('speech_permission')
                              ? 'Permiso del micrófono'
                              : 'Ajustes de reconocimiento',
                        ),
                      ),
                  ],
                ),
              ] else if (controller.downloading) ...[
                const Text(
                  'Una descarga por idioma. Después puedes dictar sin conexión. Puedes seguir escribiendo mientras se prepara.',
                  style: TextStyle(fontSize: 12),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('voice-download-cancel'),
                    onPressed: controller.closeSetup,
                    child: const Text('Cancelar descarga'),
                  ),
                ),
              ] else if (controller.active || phase == VoicePhase.review)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        key: const Key('voice-discard'),
                        tooltip: 'Descartar dictado',
                        onPressed: widget.isBusy ? null : widget.onDiscard,
                        style: IconButton.styleFrom(
                          backgroundColor: palette.errorSoft,
                          foregroundColor: palette.discard,
                          minimumSize: const Size(48, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: Key(
                            controller.active
                                ? 'voice-review-stop'
                                : 'voice-resume',
                          ),
                          onPressed:
                              widget.isBusy || phase == VoicePhase.finalizing
                              ? null
                              : controller.active
                              ? controller.finishForReview
                              : widget.onResume,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: palette.soft,
                            foregroundColor: palette.text,
                          ),
                          icon: Icon(
                            controller.active
                                ? Icons.pause
                                : Icons.mic_outlined,
                            size: 18,
                          ),
                          label: Text(
                            controller.active ? 'Pausar' : 'Continuar',
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    phase == VoicePhase.preparing ||
                            phase == VoicePhase.starting
                        ? 'Espera a que aparezca «Escuchando» para hablar.'
                        : 'Pulsa el micrófono para hablar.',
                    style: TextStyle(fontSize: 12, color: palette.muted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class VoiceMicButton extends StatelessWidget {
  const VoiceMicButton({
    required this.controller,
    required this.isBusy,
    required this.onBegin,
    super.key,
  });

  final VoiceCaptureController controller;
  final bool isBusy;
  final VoidCallback onBegin;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final blocked =
        isBusy ||
        controller.downloading ||
        controller.phase == VoicePhase.finalizing;
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton.filled(
        key: const Key('chat-voice-button'),
        tooltip: 'Dictar mensaje',
        onPressed: blocked ? null : onBegin,
        style: IconButton.styleFrom(
          backgroundColor: palette.primarySoft,
          foregroundColor: palette.primary,
          disabledBackgroundColor: palette.soft,
          disabledForegroundColor: palette.placeholder,
          minimumSize: const Size(48, 48),
        ),
        icon: const Icon(Icons.mic_outlined),
      ),
    );
  }
}
