import 'package:finance_ai/features/voice_capture/application/voice_capture_controller.dart';
import 'package:finance_ai/features/voice_capture/domain/speech_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_speech_service.dart';

class Harness {
  Harness({bool ready = true, bool listening = true}) {
    service.autoReady = ready;
    service.autoListening = listening;
    controller = VoiceCaptureController(
      service: service,
      onTranscript: visible.add,
      onAccepted: accepted.add,
      canSubmit: () => canSubmit,
    );
    addTearDown(() async {
      controller.dispose();
      await service.dispose();
    });
    controller.prepare();
  }
  final service = FakeSpeechService();
  final visible = <String>[], accepted = <String>[];
  bool canSubmit = true;
  late final VoiceCaptureController controller;
  void begin([String seed = '']) => controller.begin(seed);
  void partial(String text) =>
      service.event(controller.session, SpeechEventType.partial, text: text);
  void finalText(String text) => service.event(
    controller.session,
    SpeechEventType.finalResult,
    text: text,
  );
}

void main() {
  test('partial revisions replace hypotheses and make no AI request', () {
    final h = Harness();
    h.begin('Hoy:');
    h.partial('Pagué cinco');
    h.partial('Pagué quince mil');
    expect(h.visible.last, 'Hoy: Pagué quince mil');
    expect(h.accepted, isEmpty);
    expect(h.controller.capturing, isTrue);
  });
  test('release accepts the final transcript exactly once', () {
    final h = Harness();
    h.begin();
    h.partial('Gasté cinco');
    final id = h.controller.session;
    h.controller.release();
    expect(h.service.stops, [id]);
    h.finalText('Gasté quince mil');
    h.finalText('Duplicate final');
    expect(h.accepted, ['Gasté quince mil']);
  });
  test('review latches and release or late partial never submits', () {
    final h = Harness();
    h.begin();
    h.partial('Texto provisional');
    h.controller.finishForReview();
    h.controller.release();
    h.finalText('Texto final');
    expect(h.controller.phase, VoicePhase.review);
    expect(h.accepted, isEmpty);
    h.partial('late incorrect words');
    h.finalText('late final');
    expect(h.visible.last, 'Texto final');
    expect(h.accepted, isEmpty);
  });
  test('unexpected terminal result while held enters review', () {
    final h = Harness();
    h.begin();
    h.finalText('Pagué 100 pesos');
    h.controller.release();
    expect(h.accepted, isEmpty);
    expect(h.controller.phase, VoicePhase.review);
  });
  test('cancel and restart reject callbacks from the previous session', () {
    final h = Harness();
    h.begin();
    final old = h.controller.session;
    h.partial('Primera frase');
    h.controller.interrupt();
    h.begin('Primera frase');
    h.service.event(old, SpeechEventType.finalResult, text: 'old final');
    h.partial('y segunda');
    h.controller.release();
    h.finalText('y segunda');
    expect(h.accepted, ['Primera frase y segunda']);
    expect(h.service.cancellations, contains(old));
  });
  test('discard restores the pre-existing typed draft', () {
    final h = Harness();
    h.begin('Ya escrito');
    h.partial('dictado añadido');
    h.controller.finishForReview();
    h.finalText('dictado añadido');
    h.controller.discard();
    expect(h.visible.last, 'Ya escrito');
    expect(h.accepted, isEmpty);
  });
  test('a busy text pipeline retains the final text for review', () {
    final h = Harness();
    h.begin();
    h.canSubmit = false;
    h.controller.release();
    h.finalText('Gasté 10 mil');
    expect(h.controller.phase, VoicePhase.review);
    expect(h.accepted, isEmpty);
  });
  test('empty final does not erase visible hypotheses or send them', () {
    final h = Harness();
    h.begin();
    h.partial('Palabras disponibles');
    h.controller.release();
    h.finalText('');
    expect(h.visible.last, 'Palabras disponibles');
    expect(h.accepted, isEmpty);
    expect(h.controller.diagnostic!.code, 'speech_no_speech');
  });
  test('too much text stays visible for editing and cannot auto-send', () {
    final h = Harness();
    h.begin();
    final long = 'a' * 1001;
    h.partial(long);
    h.controller.release();
    h.finalText(long);
    expect(h.visible.last, long);
    expect(h.accepted, isEmpty);
    expect(h.controller.diagnostic!.code, 'speech_text_too_long');
  });
  testWidgets(
    'slow finalization preserves visible words and rejects late results',
    (tester) async {
      final h = Harness();
      h.begin();
      h.partial('Revisar este texto');
      final old = h.controller.session;
      h.controller.release();
      await tester.pump(const Duration(seconds: 2));
      expect(h.controller.phase, VoicePhase.review);
      expect(h.controller.diagnostic!.code, 'speech_finalize_timeout');
      h.service.event(old, SpeechEventType.finalResult, text: 'Late final');
      expect(h.visible.last, 'Revisar este texto');
      expect(h.accepted, isEmpty);
    },
  );
  test(
    'releasing during preparation prevents deferred microphone activation',
    () {
      final h = Harness(ready: false);
      final id = h.controller.session;
      h.begin();
      h.controller.release();
      h.service.event(id, SpeechEventType.ready);
      expect(h.service.starts, isEmpty);
      expect(h.accepted, isEmpty);
    },
  );
  test('holding through preparation starts once when ready', () {
    final h = Harness(ready: false);
    final id = h.controller.session;
    h.begin();
    h.service.event(id, SpeechEventType.ready);
    expect(h.service.starts, hasLength(1));
    h.controller.interrupt();
  });
  test(
    'Spanish and English are explicitly prepared and passed to the engine',
    () {
      final h = Harness();
      h.controller.prepare(SpeechLanguage.english);
      h.begin();
      expect(h.service.starts.single.$2, SpeechLanguage.english);
      h.controller.interrupt();
      h.controller.prepare(SpeechLanguage.spanish);
      h.begin();
      expect(h.service.starts.last.$2, SpeechLanguage.spanish);
    },
  );
  test(
    'model setup never starts recognition and settings are explicit',
    () async {
      final h = Harness(ready: false);
      h.service.event(
        h.controller.session,
        SpeechEventType.error,
        code: 'speech_model_missing',
        canDownload: true,
      );
      h.controller.download();
      expect(h.service.downloads, hasLength(1));
      h.service.event(h.controller.session, SpeechEventType.ready);
      expect(h.service.starts, isEmpty);
      await h.controller.openSettings();
      expect(h.service.settingsOpened, 1);
    },
  );
  for (final code in SpeechFailure.messages.keys) {
    test('safe copyable $code failure excludes entered values', () {
      final h = Harness();
      h.begin('private@example.com fake-password');
      h.partial('sensitive financial amount');
      h.service.event(h.controller.session, SpeechEventType.error, code: code);
      final report = h.controller.diagnostic!.clipboardText;
      expect(report, contains('Error code: $code'));
      expect(report, contains('Operation: voice_capture'));
      expect(report, isNot(contains('private@example.com')));
      expect(report, isNot(contains('fake-password')));
      expect(report, isNot(contains('sensitive financial amount')));
      expect(h.accepted, isEmpty);
    });
  }
  testWidgets('preparation and opening deadlines stop without submitting', (
    tester,
  ) async {
    final h = Harness(ready: false);
    await tester.pump(const Duration(seconds: 8));
    expect(h.controller.diagnostic!.code, 'speech_preparation_timeout');
    h.service.autoReady = true;
    h.service.autoListening = false;
    h.begin();
    await tester.pump(const Duration(seconds: 8));
    expect(h.controller.diagnostic!.code, 'speech_preparation_timeout');
    expect(h.accepted, isEmpty);
  });
  test(
    'disposed controller rejects late callbacks and cancels native work',
    () {
      final h = Harness();
      h.begin();
      final id = h.controller.session;
      h.controller.dispose();
      h.service.event(id, SpeechEventType.finalResult, text: 'stale');
      expect(h.accepted, isEmpty);
      expect(h.service.cancellations, contains(id));
    },
  );
}
