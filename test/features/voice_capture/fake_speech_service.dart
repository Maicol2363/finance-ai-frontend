import 'dart:async';

import 'package:finance_ai/features/voice_capture/domain/speech_service.dart';

class FakeSpeechService implements SpeechService {
  final stream = StreamController<SpeechEvent>.broadcast(sync: true);
  final starts = <(int, SpeechLanguage)>[];
  final preparations = <(int, SpeechLanguage)>[];
  final stops = <int>[];
  final cancellations = <int>[];
  final downloads = <(int, SpeechLanguage)>[];
  bool autoReady = true, autoListening = true;
  SpeechFailure? prepareFailure, startFailure;
  int settingsOpened = 0;
  @override
  Stream<SpeechEvent> get events => stream.stream;
  void event(
    int session,
    SpeechEventType type, {
    String text = '',
    String code = '',
    bool canDownload = false,
  }) => stream.add(
    SpeechEvent(
      session: session,
      type: type,
      text: text,
      code: code,
      canDownload: canDownload,
    ),
  );
  @override
  Future<void> prepare(int session, SpeechLanguage language) async {
    preparations.add((session, language));
    if (prepareFailure != null) throw prepareFailure!;
    if (autoReady) event(session, SpeechEventType.ready);
  }

  @override
  Future<void> start(int session, SpeechLanguage language) async {
    starts.add((session, language));
    if (startFailure != null) throw startFailure!;
    if (autoListening) event(session, SpeechEventType.listening);
  }

  @override
  Future<void> stop(int session) async => stops.add(session);
  @override
  Future<void> cancel(int session) async => cancellations.add(session);
  @override
  Future<void> download(int session, SpeechLanguage language) async =>
      downloads.add((session, language));
  @override
  Future<void> openSettings() async {
    settingsOpened++;
  }

  Future<void> dispose() => stream.close();
}
