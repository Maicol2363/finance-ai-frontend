import 'package:finance_ai/core/theme/app_theme.dart';
import 'package:finance_ai/features/voice_capture/domain/speech_service.dart';
import 'package:finance_ai/features/voice_capture/presentation/voice_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../text_capture/presentation/text_capture_chat_test.dart' show pumpChat;
import '../text_capture/text_capture_test_support.dart';
import 'fake_speech_service.dart';

Finder key(String value) => find.byKey(Key(value));

Future<(FakeSpeechService, FakeTextCaptureRepository)> setup(
  WidgetTester tester, {
  Size size = const Size(420, 900),
  double scale = 1,
  ThemeData? theme,
  bool autoReady = true,
}) async {
  final speech = FakeSpeechService()..autoReady = autoReady;
  addTearDown(speech.dispose);
  final repository = FakeTextCaptureRepository(proposals: [proposal()]);
  await pumpChat(
    tester,
    repository,
    speech: speech,
    size: size,
    textScale: scale,
    theme: theme,
  );
  return (speech, repository);
}

void main() {
  testWidgets(
    'held words appear in the current composer; release uses one text turn',
    (tester) async {
      final (speech, repository) = await setup(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(key('chat-voice-button')),
      );
      await tester.pump();
      final id = speech.starts.single.$1;
      speech.event(id, SpeechEventType.partial, text: 'Pagué quince');
      await tester.pump();
      expect(
        tester.widget<TextField>(key('chat-composer-field')).controller!.text,
        'Pagué quince',
      );
      expect(repository.proposeCalls, isEmpty);
      await gesture.up();
      await tester.pump();
      speech.event(
        id,
        SpeechEventType.finalResult,
        text: 'Pagué quince mil en efectivo',
      );
      await tester.pumpAndSettle();
      expect(repository.proposeCalls, hasLength(1));
      expect(
        repository.proposeCalls.single.text,
        'Pagué quince mil en efectivo',
      );
      expect(repository.confirmCalls, isEmpty);
      speech.event(id, SpeechEventType.finalResult, text: 'duplicate');
      await tester.pump();
      expect(repository.proposeCalls, hasLength(1));
    },
  );

  testWidgets(
    'microphone moves into its zone, stops and lets the user edit before sending',
    (tester) async {
      final (speech, repository) = await setup(tester);
      final start = tester.getCenter(key('chat-voice-button'));
      final gesture = await tester.startGesture(start);
      await tester.pump();
      final id = speech.starts.single.$1;
      speech.event(id, SpeechEventType.partial, text: 'Pagué cinco mil');
      await tester.pump();
      final controls = tester.widget<VoiceControls>(find.byType(VoiceControls));
      final target = tester.getRect(find.byKey(controls.targetKey));
      await gesture.moveTo(Offset(start.dx, target.bottom + 15));
      await tester.pump();
      final movingButton = find.descendant(
        of: find.byType(VoiceMicButton),
        matching: find.byType(IconButton),
      );
      expect(tester.getCenter(movingButton).dy, closeTo(target.bottom + 15, 1));
      expect(
        tester.widget<VoiceControls>(find.byType(VoiceControls)).nearTarget,
        isTrue,
      );
      await gesture.moveTo(Offset(start.dx, target.top - 40));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      expect(tester.getCenter(movingButton), target.center);
      expect(speech.stops, [id]);
      expect(
        tester.widget<VoiceControls>(find.byType(VoiceControls)).occupied,
        isTrue,
      );
      await gesture.moveTo(start);
      await gesture.up();
      await tester.pump();
      speech.event(id, SpeechEventType.finalResult, text: 'Pagué quince mil');
      await tester.pumpAndSettle();
      expect(repository.proposeCalls, isEmpty);
      expect(
        tester.widget<TextField>(key('chat-composer-field')).readOnly,
        isFalse,
      );
      await tester.enterText(
        key('chat-composer-field'),
        'Pagué 18.500 COP por el almuerzo',
      );
      speech.event(id, SpeechEventType.partial, text: 'late replacement');
      await tester.pump();
      expect(
        tester.widget<TextField>(key('chat-composer-field')).controller!.text,
        'Pagué 18.500 COP por el almuerzo',
      );
      await tester.tap(key('chat-send-button'));
      await tester.pumpAndSettle();
      expect(
        repository.proposeCalls.single.text,
        'Pagué 18.500 COP por el almuerzo',
      );
    },
  );

  testWidgets('pointer cancellation preserves words and never sends', (
    tester,
  ) async {
    final (speech, repository) = await setup(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(key('chat-voice-button')),
    );
    await tester.pump();
    final id = speech.starts.single.$1;
    speech.event(id, SpeechEventType.partial, text: 'Palabras conservadas');
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    speech.event(id, SpeechEventType.finalResult, text: 'late');
    await tester.pump();
    expect(repository.proposeCalls, isEmpty);
    expect(
      tester.widget<TextField>(key('chat-composer-field')).controller!.text,
      'Palabras conservadas',
    );
  });

  testWidgets('backgrounding and disposing cancel the actual native session', (
    tester,
  ) async {
    final (speech, repository) = await setup(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(key('chat-voice-button')),
    );
    await tester.pump();
    final id = speech.starts.single.$1;
    speech.event(id, SpeechEventType.partial, text: 'Borrador privado');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await gesture.up();
    expect(speech.cancellations, contains(id));
    speech.event(id, SpeechEventType.finalResult, text: 'late');
    await tester.pump();
    expect(repository.proposeCalls, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(speech.cancellations.length, greaterThanOrEqualTo(2));
  });

  testWidgets('Windows click start and stop enters editable review', (
    tester,
  ) async {
    final (speech, repository) = await setup(tester);
    await tester.tap(key('chat-voice-button'));
    await tester.pump();
    final id = speech.starts.single.$1;
    speech.event(id, SpeechEventType.partial, text: 'Paid for lunch');
    await tester.pump();
    await tester.tap(key('voice-review-stop'));
    await tester.pump();
    speech.event(id, SpeechEventType.finalResult, text: 'Paid for lunch');
    await tester.pumpAndSettle();
    expect(repository.proposeCalls, isEmpty);
    await tester.tap(key('chat-send-button'));
    await tester.pumpAndSettle();
    expect(repository.proposeCalls.single.text, 'Paid for lunch');
  }, variant: TargetPlatformVariant({TargetPlatform.windows}));

  testWidgets(
    'Windows stop during preparation cancels the queued microphone start',
    (tester) async {
      final (speech, repository) = await setup(tester, autoReady: false);
      await tester.tap(key('chat-voice-button'));
      await tester.pump();
      expect(speech.starts, isEmpty);
      await tester.tap(key('chat-voice-button'));
      await tester.pump();
      speech.event(speech.preparations.single.$1, SpeechEventType.ready);
      await tester.pumpAndSettle();
      expect(speech.starts, isEmpty);
      expect(repository.proposeCalls, isEmpty);
      await tester.tap(key('chat-voice-button'));
      await tester.pump();
      expect(speech.starts, hasLength(1));
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );

  testWidgets('permission failure has the shared copy UI without draft text', (
    tester,
  ) async {
    final (speech, repository) = await setup(tester);
    await tester.enterText(key('chat-composer-field'), 'PRIVATE-DRAFT-9382');
    final gesture = await tester.startGesture(
      tester.getCenter(key('chat-voice-button')),
    );
    await tester.pump();
    final id = speech.starts.single.$1;
    speech.event(id, SpeechEventType.error, code: 'speech_permission_denied');
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(key('voice-error-details'));
    await tester.pumpAndSettle();
    expect(find.text('Error code: speech_permission_denied'), findsOneWidget);
    expect(key('copy-error-details-button'), findsOneWidget);
    expect(repository.proposeCalls, isEmpty);
  });

  testWidgets('the held microphone stays put when the keyboard closes', (
    tester,
  ) async {
    final (speech, repository) = await setup(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await tester.enterText(key('chat-composer-field'), 'Ya escrito');
    await tester.pumpAndSettle();
    final start = tester.getCenter(key('chat-voice-button'));
    final gesture = await tester.startGesture(start);
    await tester.pump();
    final id = speech.starts.single.$1;
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pump();
    expect(tester.getCenter(key('chat-voice-button')).dy, closeTo(start.dy, 1));
    speech.event(id, SpeechEventType.partial, text: 'y dictado');
    await tester.pump();
    final controls = tester.widget<VoiceControls>(find.byType(VoiceControls));
    final zone = tester.getRect(find.byKey(controls.targetKey));
    await gesture.moveTo(zone.center);
    await tester.pump();
    expect(speech.stops, [id]);
    await gesture.up();
    speech.event(id, SpeechEventType.finalResult, text: 'y dictado');
    await tester.pumpAndSettle();
    expect(repository.proposeCalls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selecting an example cancels dictation before replacing the draft',
    (tester) async {
      final (speech, repository) = await setup(tester);
      await tester.tap(key('chat-voice-button'));
      await tester.pump();
      final id = speech.starts.single.$1;
      speech.event(id, SpeechEventType.partial, text: 'Old hypothesis');
      await tester.pump();
      await tester.tap(key('chat-suggestion-1'));
      await tester.pumpAndSettle();
      speech.event(id, SpeechEventType.finalResult, text: 'Late old words');
      await tester.pump();
      expect(speech.cancellations, contains(id));
      expect(repository.proposeCalls, isEmpty);
      expect(
        tester.widget<TextField>(key('chat-composer-field')).controller!.text,
        'Me pagaron el sueldo, 2 millones',
      );
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );

  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    testWidgets(
      'voice controls fit 320px at enlarged text in ${theme.brightness.name}',
      (tester) async {
        final (speech, _) = await setup(
          tester,
          size: const Size(320, 900),
          scale: 1.5,
          theme: theme,
        );
        final gesture = await tester.startGesture(
          tester.getCenter(key('chat-voice-button')),
        );
        await tester.pump();
        final id = speech.starts.single.$1;
        speech.event(
          id,
          SpeechEventType.partial,
          text: 'Pagué dieciocho mil pesos por el almuerzo',
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await gesture.up();
        await tester.pump();
        speech.event(id, SpeechEventType.finalResult, text: '');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
  test('swept zone hit testing requires intersection, rather than upward distance alone', () {
    const zone = Rect.fromLTRB(100, 100, 220, 160);
    expect(
      voiceDragCrosses(const Offset(160, 260), const Offset(160, 20), zone),
      isTrue,
    );
    expect(
      voiceDragCrosses(const Offset(250, 260), const Offset(250, 20), zone),
      isFalse,
    );
    expect(
      voiceDragCrosses(const Offset(0, 130), const Offset(300, 130), zone),
      isTrue,
    );
    expect(
      voiceDragCrosses(const Offset(0, 200), const Offset(50, 200), zone),
      isFalse,
    );
  });
}
