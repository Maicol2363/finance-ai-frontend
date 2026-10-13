import 'package:finance_ai/core/theme/app_theme.dart';
import 'package:finance_ai/features/text_capture/presentation/text_capture_chat.dart';
import 'package:finance_ai/features/voice_capture/domain/speech_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final platforms = TargetPlatformVariant({
    TargetPlatform.android,
    TargetPlatform.windows,
  });

  testWidgets(
    'focused Enter starts dictation and Space pauses without sending',
    (tester) async {
      final (speech, repository) = await setup(tester);
      final mic = tester.widget<IconButton>(key('chat-voice-button'));
      expect(mic.focusNode!.canRequestFocus, isTrue);
      expect(mic.focusNode!.skipTraversal, isFalse);
      mic.focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      final id = speech.starts.single.$1;
      speech.event(id, SpeechEventType.partial, text: 'Dictado privado');
      await tester.pump();

      final pause = tester.widget<OutlinedButton>(key('voice-review-stop'));
      pause.focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(speech.stops, [id]);
      speech.event(id, SpeechEventType.finalResult, text: 'Dictado privado');
      await tester.pumpAndSettle();
      expect(key('voice-resume'), findsOneWidget);
      expect(repository.proposeCalls, isEmpty);
    },
    variant: platforms,
  );

  testWidgets(
    'quick capture starts voice in the same composer without a wheel',
    (tester) async {
      final speech = FakeSpeechService()..autoReady = true;
      addTearDown(speech.dispose);
      final repository = FakeTextCaptureRepository(proposals: [proposal()]);
      await pumpChat(
        tester,
        repository,
        speech: speech,
        chat: const TextCaptureChat(showWheel: false, startVoice: true),
      );
      expect(speech.starts, hasLength(1));
      expect(key('expenses-create-fab'), findsNothing);
      speech.event(
        speech.starts.single.$1,
        SpeechEventType.partial,
        text: 'Pagué el almuerzo',
      );
      await tester.pump();
      expect(
        tester.widget<TextField>(key('chat-composer-field')).controller!.text,
        'Pagué el almuerzo',
      );
      expect(key('voice-review-stop'), findsOneWidget);
      expect(repository.proposeCalls, isEmpty);
      await tester.tap(key('voice-discard'));
      await tester.pumpAndSettle();
    },
    variant: platforms,
  );

  testWidgets('quick text capture focuses the editor without starting voice', (
    tester,
  ) async {
    final speech = FakeSpeechService()..autoReady = true;
    addTearDown(speech.dispose);
    await pumpChat(
      tester,
      FakeTextCaptureRepository(),
      speech: speech,
      chat: const TextCaptureChat(showWheel: false, autoFocus: true),
    );
    expect(
      tester.widget<TextField>(key('chat-composer-field')).focusNode!.hasFocus,
      isTrue,
    );
    expect(key('expenses-create-fab'), findsNothing);
    expect(speech.starts, isEmpty);
  });

  testWidgets('permission recovery still opens the app permission settings', (
    tester,
  ) async {
    final (speech, _) = await setup(tester);
    await tester.tap(key('chat-voice-button'));
    await tester.pump();
    speech.event(
      speech.starts.single.$1,
      SpeechEventType.error,
      code: 'speech_permission_required',
    );
    await tester.pumpAndSettle();
    expect(key('voice-settings'), findsOneWidget);
    await tester.tap(key('voice-settings'));
    expect(speech.settingsOpened, 1);
    expect(speech.starts, hasLength(1));
  });

  testWidgets(
    'missing model recovery keeps downloads and never opens an unrelated setting',
    (tester) async {
      final (speech, repository) = await setup(tester);
      await tester.tap(key('chat-voice-button'));
      await tester.pump();
      speech.event(
        speech.starts.single.$1,
        SpeechEventType.error,
        code: 'speech_fallback_model_missing',
        canDownload: true,
        engine: SpeechEngine.integrated,
      );
      await tester.pumpAndSettle();
      expect(find.text('Sube para editar'), findsNothing);
      expect(key('voice-settings'), findsNothing);
      expect(key('voice-download'), findsOneWidget);
      await tester.tap(key('voice-download'));
      await tester.pump();
      speech.event(
        speech.downloads.single.$1,
        SpeechEventType.download,
        engine: SpeechEngine.integrated,
        downloadStage: SpeechDownloadStage.downloading,
        progress: 35,
      );
      await tester.pump();
      expect(find.text('Descargando modelo · 35%'), findsOneWidget);
      expect(speech.starts, hasLength(1));
      expect(repository.proposeCalls, isEmpty);
      speech.event(
        speech.downloads.single.$1,
        SpeechEventType.ready,
        engine: SpeechEngine.integrated,
      );
      await tester.pumpAndSettle();
      expect(key('voice-download-cancel'), findsNothing);
      expect(speech.starts, hasLength(1));
    },
  );

  testWidgets(
    'setup recovery remains usable with the keyboard and enlarged text',
    (tester) async {
      final (speech, _) = await setup(
        tester,
        size: const Size(320, 600),
        scale: 1.5,
      );
      await tester.tap(key('chat-voice-button'));
      await tester.pump();
      speech.event(
        speech.starts.single.$1,
        SpeechEventType.error,
        code: 'speech_fallback_model_missing',
        canDownload: true,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(key('voice-download'));
      await tester.tap(key('voice-download'));
      await tester.pump();
      speech.event(
        speech.downloads.single.$1,
        SpeechEventType.download,
        progress: 35,
        downloadStage: SpeechDownloadStage.downloading,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(key('chat-composer-field'), 'I can still type');
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(key('chat-composer-field')).bottom,
        lessThanOrEqualTo(600 - 180),
      );
      await tester.ensureVisible(key('voice-download-cancel'));
      await tester.tap(key('voice-download-cancel'));
      await tester.pumpAndSettle();
      expect(speech.cancellations, contains(speech.downloads.single.$1));
      expect(speech.starts, hasLength(1));
    },
  );

  testWidgets(
    'one tap starts hands-free capture in the existing anchored field',
    (tester) async {
      final (speech, repository) = await setup(tester);
      final fieldElement = tester.element(key('chat-composer-field'));
      final fieldBottom = tester.getRect(key('chat-composer-field')).bottom;
      await tester.tap(key('chat-voice-button'));
      await tester.pump();
      final id = speech.starts.single.$1;
      speech.event(id, SpeechEventType.partial, text: 'Pagué quince');
      await tester.pump();
      expect(tester.element(key('chat-composer-field')), same(fieldElement));
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.widget<TextField>(key('chat-composer-field')).controller!.text,
        'Pagué quince',
      );
      expect(
        tester.getRect(key('chat-composer-field')).bottom,
        closeTo(fieldBottom, 1),
      );
      expect(
        tester.getRect(key('voice-controls')).bottom,
        lessThanOrEqualTo(tester.getRect(key('chat-composer-field')).top),
      );
      expect(key('chat-voice-button'), findsNothing);
      expect(key('voice-review-stop'), findsOneWidget);
      expect(repository.proposeCalls, isEmpty);
      speech.event(id, SpeechEventType.finalResult, text: 'Pagué quince mil');
      await tester.pumpAndSettle();
      expect(repository.proposeCalls, isEmpty);
      expect(key('voice-resume'), findsOneWidget);
    },
    variant: platforms,
  );

  testWidgets(
    'explicit send finalizes once through the existing text proposal flow',
    (tester) async {
      final (speech, repository) = await setup(tester);
      await tester.tap(key('chat-voice-button'));
      await tester.pump();
      final id = speech.starts.single.$1;
      speech.event(id, SpeechEventType.partial, text: 'Pagué quince');
      await tester.pump();
      await tester.tap(key('chat-send-button'));
      await tester.pump();
      expect(speech.stops, [id]);
      expect(repository.proposeCalls, isEmpty);
      speech.event(
        id,
        SpeechEventType.finalResult,
        text: 'Pagué quince mil en efectivo',
      );
      await tester.pumpAndSettle();
      expect(
        repository.proposeCalls.single.text,
        'Pagué quince mil en efectivo',
      );
      expect(repository.confirmCalls, isEmpty);
      expect(key('voice-controls'), findsNothing);
      speech.event(id, SpeechEventType.finalResult, text: 'duplicate');
      await tester.pump();
      expect(repository.proposeCalls, hasLength(1));
    },
    variant: platforms,
  );

  testWidgets('pause preserves final words for review without sending', (
    tester,
  ) async {
    final (speech, repository) = await setup(tester);
    await tester.tap(key('chat-voice-button'));
    await tester.pump();
    final id = speech.starts.single.$1;
    speech.event(id, SpeechEventType.partial, text: 'Pagué cinco mil');
    await tester.pump();
    await tester.tap(key('voice-review-stop'));
    await tester.pump();
    expect(speech.stops, [id]);
    speech.event(id, SpeechEventType.finalResult, text: 'Pagué quince mil');
    await tester.pumpAndSettle();
    expect(repository.proposeCalls, isEmpty);
    expect(key('voice-resume'), findsOneWidget);
    expect(
      tester.widget<TextField>(key('chat-composer-field')).controller!.text,
      'Pagué quince mil',
    );
    await tester.tap(key('chat-send-button'));
    await tester.pumpAndSettle();
    expect(repository.proposeCalls.single.text, 'Pagué quince mil');
  }, variant: platforms);

  testWidgets(
    'tapping the same text pauses immediately and resumed speech preserves edits',
    (tester) async {
      final (speech, repository) = await setup(tester);
      final fieldElement = tester.element(key('chat-composer-field'));
      await tester.tap(key('chat-voice-button'));
      await tester.pump();
      final id = speech.starts.single.$1;
      speech.event(id, SpeechEventType.partial, text: 'Pagué cinco mil');
      await tester.pump();
      await tester.tap(key('chat-composer-field'));
      await tester.pump();
      expect(speech.cancellations, contains(id));
      expect(key('voice-resume'), findsOneWidget);
      expect(
        tester.widget<TextField>(key('chat-composer-field')).readOnly,
        isFalse,
      );
      await tester.enterText(
        key('chat-composer-field'),
        'Pagué 18.500 COP por el almuerzo',
      );
      speech.event(id, SpeechEventType.partial, text: 'late replacement');
      speech.event(id, SpeechEventType.finalResult, text: 'late final');
      await tester.pump();
      expect(
        tester.widget<TextField>(key('chat-composer-field')).controller!.text,
        'Pagué 18.500 COP por el almuerzo',
      );
      await tester.tap(key('voice-resume'));
      await tester.pump();
      expect(speech.starts, hasLength(2));
      final resumedId = speech.starts.last.$1;
      speech.event(
        resumedId,
        SpeechEventType.partial,
        text: 'y pagué con Nequi',
      );
      await tester.pump();
      expect(tester.element(key('chat-composer-field')), same(fieldElement));
      expect(
        tester.widget<TextField>(key('chat-composer-field')).controller!.text,
        'Pagué 18.500 COP por el almuerzo y pagué con Nequi',
      );
      expect(repository.proposeCalls, isEmpty);
      await tester.tap(key('chat-send-button'));
      await tester.pump();
      speech.event(
        resumedId,
        SpeechEventType.finalResult,
        text: 'y pagué con Nequi',
      );
      await tester.pumpAndSettle();
      expect(
        repository.proposeCalls.single.text,
        'Pagué 18.500 COP por el almuerzo y pagué con Nequi',
      );
      expect(repository.confirmCalls, isEmpty);
    },
    variant: platforms,
  );

  testWidgets(
    'delete immediately discards dictation and retains the existing typed prefix',
    (tester) async {
      final (speech, repository) = await setup(tester);
      await tester.enterText(key('chat-composer-field'), 'Ya escrito');
      await tester.pump();
      await tester.tap(key('chat-voice-button'));
      await tester.pump();
      final id = speech.starts.single.$1;
      speech.event(id, SpeechEventType.partial, text: 'y dictado');
      await tester.pump();
      await tester.tap(key('voice-discard'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(key('voice-controls'), findsNothing);
      expect(key('chat-voice-button'), findsOneWidget);
      expect(speech.cancellations, contains(id));
      expect(
        tester.widget<TextField>(key('chat-composer-field')).controller!.text,
        'Ya escrito',
      );
      speech.event(id, SpeechEventType.finalResult, text: 'late');
      await tester.pump();
      expect(
        tester.widget<TextField>(key('chat-composer-field')).controller!.text,
        'Ya escrito',
      );
      expect(repository.proposeCalls, isEmpty);
    },
    variant: platforms,
  );

  testWidgets('close keeps visible words without sending', (tester) async {
    final (speech, repository) = await setup(tester);
    await tester.tap(key('chat-voice-button'));
    await tester.pump();
    final id = speech.starts.single.$1;
    speech.event(id, SpeechEventType.partial, text: 'Palabras conservadas');
    await tester.pump();
    await tester.tap(key('voice-close'));
    await tester.pumpAndSettle();
    speech.event(id, SpeechEventType.finalResult, text: 'late');
    await tester.pump();
    expect(repository.proposeCalls, isEmpty);
    expect(
      tester.widget<TextField>(key('chat-composer-field')).controller!.text,
      'Palabras conservadas',
    );
    expect(key('voice-controls'), findsNothing);
  });

  testWidgets(
    'a recoverable failure keeps the draft and one-tap microphone retry',
    (tester) async {
      final (speech, repository) = await setup(tester);
      await tester.tap(key('chat-voice-button'));
      await tester.pump();
      final id = speech.starts.single.$1;
      speech.event(id, SpeechEventType.partial, text: 'Palabras conservadas');
      await tester.pump();
      speech.event(id, SpeechEventType.error, code: 'speech_no_match');
      await tester.pumpAndSettle();
      expect(key('chat-voice-button'), findsOneWidget);
      expect(
        tester.widget<TextField>(key('chat-composer-field')).controller!.text,
        'Palabras conservadas',
      );
      await tester.tap(key('chat-voice-button'));
      await tester.pump();
      expect(speech.starts, hasLength(2));
      expect(key('voice-error-message'), findsNothing);
      expect(repository.proposeCalls, isEmpty);
      await tester.tap(key('voice-discard'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('backgrounding and disposing cancel the native session', (
    tester,
  ) async {
    final (speech, repository) = await setup(tester);
    await tester.tap(key('chat-voice-button'));
    await tester.pump();
    final id = speech.starts.single.$1;
    speech.event(id, SpeechEventType.partial, text: 'Borrador privado');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(speech.cancellations, contains(id));
    speech.event(id, SpeechEventType.finalResult, text: 'late');
    await tester.pump();
    expect(repository.proposeCalls, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(speech.cancellations.length, greaterThanOrEqualTo(2));
  });

  testWidgets('pause during preparation cancels a queued start', (
    tester,
  ) async {
    final (speech, repository) = await setup(tester, autoReady: false);
    await tester.tap(key('chat-voice-button'));
    await tester.pump();
    expect(speech.starts, isEmpty);
    await tester.tap(key('voice-review-stop'));
    await tester.pump();
    speech.event(speech.preparations.single.$1, SpeechEventType.ready);
    await tester.pumpAndSettle();
    expect(speech.starts, isEmpty);
    expect(repository.proposeCalls, isEmpty);
    await tester.tap(key('chat-voice-button'));
    await tester.pump();
    expect(speech.starts, hasLength(1));
  }, variant: platforms);

  testWidgets(
    'permission failure keeps the shared copy UI free of draft text',
    (tester) async {
      final (speech, repository) = await setup(tester);
      await tester.enterText(key('chat-composer-field'), 'PRIVATE-DRAFT-9382');
      await tester.pump();
      await tester.tap(key('chat-voice-button'));
      await tester.pump();
      speech.event(
        speech.starts.single.$1,
        SpeechEventType.error,
        code: 'speech_permission_denied',
      );
      await tester.pumpAndSettle();
      await tester.tap(key('voice-error-details'));
      await tester.pumpAndSettle();
      expect(find.text('Error code: speech_permission_denied'), findsOneWidget);
      expect(key('copy-error-details-button'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('PRIVATE-DRAFT-9382'),
        ),
        findsNothing,
      );
      expect(repository.proposeCalls, isEmpty);
    },
  );

  testWidgets('dragging or cancelling a pointer cannot move or start the mic', (
    tester,
  ) async {
    final (speech, repository) = await setup(tester);
    final start = tester.getCenter(key('chat-voice-button'));
    final gesture = await tester.startGesture(start);
    await gesture.moveTo(start - const Offset(0, 90));
    await tester.pump();
    expect(tester.getCenter(key('chat-voice-button')), start);
    expect(speech.starts, isEmpty);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(speech.starts, isEmpty);
    expect(repository.proposeCalls, isEmpty);
  });

  testWidgets('Escape preserves the draft and cancels capture', (tester) async {
    final (speech, repository) = await setup(tester);
    await tester.tap(key('chat-voice-button'));
    await tester.pump();
    final id = speech.starts.single.$1;
    speech.event(id, SpeechEventType.partial, text: 'Borrador');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(speech.cancellations, contains(id));
    expect(
      tester.widget<TextField>(key('chat-composer-field')).controller!.text,
      'Borrador',
    );
    expect(repository.proposeCalls, isEmpty);
  });

  testWidgets('elapsed time pauses and continues with the edited draft', (
    tester,
  ) async {
    final (speech, _) = await setup(tester);
    await tester.tap(key('chat-voice-button'));
    await tester.pump();
    speech.event(
      speech.starts.single.$1,
      SpeechEventType.partial,
      text: 'Borrador',
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('0:02'), findsOneWidget);
    await tester.tap(key('chat-composer-field'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('0:02'), findsOneWidget);
    await tester.tap(key('voice-resume'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0:03'), findsOneWidget);
    await tester.tap(key('voice-discard'));
    await tester.pumpAndSettle();
  });

  testWidgets('keyboard focus pauses dictation before text editing', (
    tester,
  ) async {
    final (speech, repository) = await setup(tester);
    await tester.tap(key('chat-voice-button'));
    await tester.pump();
    final id = speech.starts.single.$1;
    speech.event(id, SpeechEventType.partial, text: 'Ya dictado');
    await tester.pump();
    tester
        .widget<TextField>(key('chat-composer-field'))
        .focusNode!
        .requestFocus();
    await tester.pump();
    expect(speech.cancellations, contains(id));
    speech.event(id, SpeechEventType.partial, text: 'late');
    await tester.pump();
    expect(
      tester.widget<TextField>(key('chat-composer-field')).controller!.text,
      'Ya dictado',
    );
    expect(repository.proposeCalls, isEmpty);
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
  );

  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    for (final size in [
      const Size(320, 600),
      const Size(640, 360),
      const Size(1200, 800),
    ]) {
      testWidgets(
        'anchored controls fit ${size.width}x${size.height} with enlarged text in ${theme.brightness.name}',
        (tester) async {
          final (speech, repository) = await setup(
            tester,
            size: size,
            scale: 1.5,
            theme: theme,
          );
          final bottom = tester.getRect(key('chat-composer-field')).bottom;
          await tester.tap(key('chat-voice-button'));
          await tester.pump();
          final id = speech.starts.single.$1;
          speech.event(
            id,
            SpeechEventType.partial,
            text: 'Pagué dieciocho mil pesos por el almuerzo en efectivo',
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(
            tester.getRect(key('chat-composer-field')).bottom,
            closeTo(bottom, 1),
          );
          await tester.tap(key('chat-composer-field'));
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(repository.proposeCalls, isEmpty);
          await tester.tap(key('voice-discard'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
