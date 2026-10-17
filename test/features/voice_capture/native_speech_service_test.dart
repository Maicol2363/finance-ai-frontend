import 'dart:async';

import 'package:finance_ai/features/voice_capture/data/native_speech_service.dart';
import 'package:finance_ai/features/voice_capture/domain/speech_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('tests/voice');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(methods, null));
  test('download events expose bounded progress and allow-listed compatibility metadata', () async {
    final source = StreamController<Object?>.broadcast();
    final service = NativeSpeechService(
      methods: methods,
      eventStream: source.stream,
    );
    final received = <SpeechEvent>[];
    final failures = <Object>[];
    final subscription = service.events.listen(
      received.add,
      onError: failures.add,
    );
    source.add({
      'session': 2,
      'type': 'download',
      'engine': 'integrated',
      'stage': 'downloading',
      'progress': 42,
      'apiLevel': 29,
      'reason': 'RAW SECRET',
    });
    for (final invalid in [
      {'progress': 101},
      {'progress': 'PRIVATE'},
      {'stage': 'PRIVATE'},
      {'engine': 'PRIVATE'},
      {'apiLevel': 'PRIVATE'},
    ]) {
      source.add({'session': 2, 'type': 'download', ...invalid});
    }
    await Future<void>.delayed(Duration.zero);
    expect(received.single.progress, 42);
    expect(received.single.engine, SpeechEngine.integrated);
    expect(received.single.reason, 'none');
    expect(received.single.apiLevel, 29);
    expect(failures, hasLength(5));
    expect(
      failures.every(
        (failure) =>
            failure is SpeechFailure && failure.code == 'speech_provider_error',
      ),
      isTrue,
    );
    await subscription.cancel();
    await service.dispose();
    await source.close();
  });
  test(
    'both platforms receive the same language and session contract; no audio',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call);
        return null;
      });
      final source = StreamController<Object?>.broadcast();
      final service = NativeSpeechService(
        methods: methods,
        eventStream: source.stream,
      );
      await service.prepare(1, SpeechLanguage.spanish);
      await service.start(2, SpeechLanguage.english);
      await service.stop(2);
      await service.cancel(2);
      await service.download(3, SpeechLanguage.spanish);
      await service.openSettings();
      expect(calls.map((call) => call.method), [
        'prepare',
        'start',
        'stop',
        'cancel',
        'download',
        'settings',
      ]);
      expect(calls[0].arguments, {'session': 1, 'language': 'es-ES'});
      expect(calls[1].arguments, {'session': 2, 'language': 'en-US'});
      expect(calls[2].arguments, {'session': 2});
      expect(
        calls.map((call) => call.arguments).toString(),
        isNot(contains('audio')),
      );
      await service.dispose();
      await source.close();
    },
  );
  test(
    'native hypotheses and terminal results keep their session identifiers',
    () async {
      final source = StreamController<Object?>.broadcast();
      final service = NativeSpeechService(
        methods: methods,
        eventStream: source.stream,
      );
      final received = <SpeechEvent>[];
      final subscription = service.events.listen(received.add);
      for (final type in [
        'ready',
        'listening',
        'partial',
        'final',
        'error',
        'download',
      ]) {
        source.add({
          'session': 7,
          'type': type,
          'text': 'words',
          'code': 'speech_model_missing',
          'canDownload': true,
        });
      }
      await Future<void>.delayed(Duration.zero);
      expect(received.map((event) => event.type), SpeechEventType.values);
      expect(received.every((event) => event.session == 7), isTrue);
      expect(received.last.canDownload, isTrue);
      await subscription.cancel();
      await service.dispose();
      await source.close();
    },
  );
  test('malformed events yield only a bounded safe failure', () async {
    final source = StreamController<Object?>.broadcast();
    final service = NativeSpeechService(
      methods: methods,
      eventStream: source.stream,
    );
    final failures = <Object>[];
    final subscription = service.events.listen((_) {}, onError: failures.add);
    source.add('PRIVATE AUDIO');
    source.add({'session': 'private', 'type': 'partial'});
    source.add({'session': 1, 'type': 'unknown', 'text': 'PRIVATE DRAFT'});
    source.add({'session': 1, 'type': 'partial', 'text': 23});
    source.add({'session': 1, 'type': 'partial', 'text': 'a' * 8193});
    source.addError(const FormatException('RAW SECRET'));
    await Future<void>.delayed(Duration.zero);
    expect(failures, hasLength(6));
    expect(
      failures.every(
        (failure) =>
            failure is SpeechFailure && failure.code == 'speech_provider_error',
      ),
      isTrue,
    );
    await subscription.cancel();
    await service.dispose();
    await source.close();
  });
  test(
    'platform errors never include native messages or details in user failures',
    () async {
      messenger.setMockMethodCallHandler(methods, (_) async {
        throw PlatformException(
          code: 'unknown-private-error',
          message: 'PRIVATE WORDS',
          details: 'SECRET KEY',
        );
      });
      final source = StreamController<Object?>.broadcast();
      final service = NativeSpeechService(
        methods: methods,
        eventStream: source.stream,
      );
      await expectLater(
        service.start(1, SpeechLanguage.spanish),
        throwsA(
          isA<SpeechFailure>()
              .having(
                (failure) => failure.code,
                'code',
                'speech_provider_error',
              )
              .having(
                (failure) => failure.userMessage,
                'message',
                isNot(contains('PRIVATE')),
              ),
        ),
      );
      await service.dispose();
      await source.close();
    },
  );
  test(
    'an old native bundle is detected before any event-channel subscription',
    () async {
      final service = NativeSpeechService(methods: methods);
      await expectLater(
        service.prepare(1, SpeechLanguage.spanish),
        throwsA(
          isA<SpeechFailure>().having(
            (failure) => failure.code,
            'code',
            'speech_offline_unavailable',
          ),
        ),
      );
      await service.dispose();
    },
  );
}
