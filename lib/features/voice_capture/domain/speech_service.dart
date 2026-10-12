enum SpeechLanguage {
  spanish('es-ES', 'Español'),
  english('en-US', 'English');

  const SpeechLanguage(this.tag, this.label);
  final String tag;
  final String label;
}

enum SpeechEventType { ready, listening, partial, finalResult, error, download }

enum SpeechEngine { device, integrated }

enum SpeechDownloadStage { requested, downloading, installing, loading }

class SpeechEvent {
  const SpeechEvent({
    required this.session,
    required this.type,
    this.text = '',
    this.code = '',
    this.canDownload = false,
    this.engine = SpeechEngine.device,
    this.downloadStage = SpeechDownloadStage.requested,
    this.progress,
    this.reason = 'none',
    this.apiLevel,
  });

  final int session;
  final SpeechEventType type;
  // The complete hypothesis for this session; revisions replace earlier words.
  final String text;
  final String code;
  final bool canDownload;
  final SpeechEngine engine;
  final SpeechDownloadStage downloadStage;
  final int? progress;
  final String reason;
  final int? apiLevel;
}

/// Recognition stays on the device. This interface never accepts or sends audio.
abstract interface class SpeechService {
  Stream<SpeechEvent> get events;
  Future<void> prepare(int session, SpeechLanguage language);
  Future<void> start(int session, SpeechLanguage language);
  Future<void> stop(int session);
  Future<void> cancel(int session);
  Future<void> download(int session, SpeechLanguage language);
  Future<void> openSettings();
}

class SpeechFailure implements Exception {
  const SpeechFailure(this.code);
  final String code;

  static const messages = <String, String>{
    'speech_offline_unavailable': 'Este dispositivo no ofrece dictado local compatible. Puedes escribir el mensaje.',
    'speech_language_unavailable': 'No hay un reconocedor local para este idioma. Instálalo en los ajustes o elige otro idioma.',
    'speech_model_missing': 'Falta el modelo de voz de este idioma. Descárgalo una vez para dictar sin conexión.',
    'speech_model_download_pending':
        'La descarga está pendiente. Comprueba el dictado cuando termine.',
    'speech_model_download_failed': 'No se pudo descargar e instalar el modelo. Revisa la conexión y el espacio libre; vuelve a intentarlo.',
    'speech_permission_required':
        'Permite el acceso al micrófono y vuelve a mantener el botón.',
    'speech_permission_denied': 'El micrófono no tiene permiso. Puedes activarlo en los ajustes o escribir el mensaje.',
    'speech_microphone_busy': 'No se pudo abrir el micrófono. Cierra otras aplicaciones que lo usen y reintenta.',
    'speech_no_match': 'No entendí esta frase. Puedes volver a dictar o editar el texto disponible.',
    'speech_no_speech':
        'No se escucharon palabras. Mantén el botón mientras hablas.',
    'speech_busy': 'El reconocedor está ocupado. Vuelve a intentarlo.',
    'speech_preparation_timeout': 'El dictado local tardó en prepararse. Puedes reintentar o escribir el mensaje.',
    'speech_finalize_timeout': 'La transcripción tardó en terminar. Revisa el texto disponible antes de enviarlo.',
    'speech_text_too_long':
        'El mensaje supera los 1000 caracteres. Acórtalo antes de enviarlo.',
    'speech_session_ended':
        'El dictado se detuvo. Revisa el texto antes de enviarlo.',
    'speech_provider_error': 'El dictado local no pudo continuar. Conservamos el texto para que lo revises.',
    'speech_settings_unavailable': 'No se pudieron abrir los ajustes. Puedes abrirlos desde el dispositivo.',
    'speech_fallback_model_missing': 'Prepara el dictado de esta app con una descarga de unos 40 MB para el idioma elegido. Después funciona sin conexión y no necesita el asistente ni el teclado del teléfono.',
    'speech_model_invalid': 'El modelo local está incompleto o dañado. Descárgalo de nuevo para preparar el dictado.',
    'speech_fallback_unavailable': 'Este dispositivo no pudo cargar el dictado de la app. Puedes escribir y copiar los detalles para que revisemos la compatibilidad.',
    'speech_fallback_memory': 'No hay suficiente memoria para cargar el dictado local. Cierra otras aplicaciones y vuelve a comprobarlo.',
  };

  static const retryableUtterances = {'speech_no_match', 'speech_no_speech'};
  static const settingsFailures = {
    'speech_permission_required',
    'speech_permission_denied',
    'speech_offline_unavailable',
    'speech_language_unavailable',
  };
  static const reasons = {
    'none',
    'native_service_missing',
    'native_service_timeout',
    'native_service_error',
    'native_model_missing',
  };
  static String safeReason(String reason) =>
      reasons.contains(reason) ? reason : 'none';

  static String safeCode(String? code) =>
      messages.containsKey(code) ? code! : 'speech_provider_error';

  String get userMessage => messages[safeCode(code)]!;
}
