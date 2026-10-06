enum SpeechLanguage {
  spanish('es-ES', 'Español'),
  english('en-US', 'English');

  const SpeechLanguage(this.tag, this.label);
  final String tag;
  final String label;
}

enum SpeechEventType { ready, listening, partial, finalResult, error }

class SpeechEvent {
  const SpeechEvent({
    required this.session,
    required this.type,
    this.text = '',
    this.code = '',
    this.canDownload = false,
  });

  final int session;
  final SpeechEventType type;
  // The complete hypothesis for this session; revisions replace earlier words.
  final String text;
  final String code;
  final bool canDownload;
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
    'speech_model_download_pending': 'El modelo aún se está descargando. Comprueba su disponibilidad cuando termine.',
    'speech_model_download_failed': 'No se pudo descargar el modelo. Revisa la conexión y vuelve a intentarlo.',
    'speech_permission_required':
        'Permite el acceso al micrófono y vuelve a mantener el botón.',
    'speech_permission_denied': 'El micrófono no tiene permiso. Puedes activarlo en los ajustes o escribir el mensaje.',
    'speech_microphone_busy': 'No se pudo abrir el micrófono. Cierra otras aplicaciones que lo usen y reintenta.',
    'speech_no_match': 'No pude reconocer las palabras. Puedes repetirlas o editar el texto disponible.',
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
  };

  static String safeCode(String? code) =>
      messages.containsKey(code) ? code! : 'speech_provider_error';

  String get userMessage => messages[safeCode(code)]!;
}
