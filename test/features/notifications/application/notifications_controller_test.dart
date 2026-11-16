import 'package:finance_ai/features/auth/session/domain/session_models.dart';
import 'package:finance_ai/features/notifications/application/notifications_controller.dart';
import 'package:finance_ai/features/notifications/application/notifications_state.dart';
import 'package:finance_ai/features/notifications/data/notifications_repository.dart';
import 'package:finance_ai/features/notifications/domain/notification_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../notifications_test_helpers.dart';

final epoch = DateTime.utc(2026, 11, 16, 15);

(ProviderContainer, FakeNotificationsRepository) setup({
  NotificationPreferences? initial,
}) {
  final repository = FakeNotificationsRepository(initial: initial);
  final container = ProviderContainer(
    overrides: [
      notificationsRepositoryProvider.overrideWithValue(repository),
      notificationsClockProvider.overrideWithValue(() => epoch),
    ],
  );
  addTearDown(container.dispose);
  return (container, repository);
}

void main() {
  test('loads the preferences', () async {
    final (container, _) = setup();
    final controller = container.read(notificationsControllerProvider.notifier);

    await controller.load();

    final state = container.read(notificationsControllerProvider);
    expect(state.loadStatus, NotificationsLoadStatus.ready);
    expect(state.preferences?.emailHint, 'a***@example.com');
  });

  test('a failed load keeps a copyable diagnostic and no stale data', () async {
    final (container, repository) = setup();
    repository.failNext = const NotificationFailure(
      code: 'network_unavailable',
      userMessage: 'No pudimos cargar tus avisos.',
      correlationId: 'load-1',
      technicalReason: 'timeout',
    );

    await container.read(notificationsControllerProvider.notifier).load();

    final state = container.read(notificationsControllerProvider);
    expect(state.loadStatus, NotificationsLoadStatus.failure);
    expect(state.diagnostic?.code, 'network_unavailable');
    expect(state.diagnostic?.correlationId, 'load-1');
    expect(state.diagnostic?.operation, 'load_notifications');
  });

  test('each switch changes only its own preference', () async {
    final (container, repository) = setup();
    final controller = container.read(notificationsControllerProvider.notifier);
    await controller.load();

    await controller.setBudgetAlerts(false);
    await controller.setShowAmounts(false);
    await controller.setEmailEnabled(false);

    expect(repository.calls.skip(1), [
      'update:-:false:-',
      'update:-:-:false',
      'update:false:-:-',
    ]);
    final prefs = container.read(notificationsControllerProvider).preferences!;
    expect(
      (prefs.emailEnabled, prefs.budgetAlerts, prefs.showAmounts),
      (false, false, false),
    );
  });

  test(
    'the verification flow ends with a verified address and email on',
    () async {
      final (container, repository) = setup(
        initial: preferences(verified: false, enabled: false),
      );
      final controller = container.read(
        notificationsControllerProvider.notifier,
      );
      await controller.load();

      await controller.startVerification();
      var state = container.read(notificationsControllerProvider);
      expect(state.verificationStep, VerificationStep.codeSent);
      expect(state.resendAvailableAt, epoch.add(const Duration(seconds: 60)));

      expect(await controller.verify('123456'), isTrue);
      state = container.read(notificationsControllerProvider);
      expect(state.preferences?.emailVerified, isTrue);
      expect(state.preferences?.emailEnabled, isTrue);
      expect(state.verificationStep, VerificationStep.idle);
      expect(state.verification, isNull);
      expect(repository.calls, ['load', 'request', 'verify']);
    },
  );

  test('a badly shaped code never reaches the server', () async {
    final (container, repository) = setup(
      initial: preferences(verified: false, enabled: false),
    );
    final controller = container.read(notificationsControllerProvider.notifier);
    await controller.startVerification();

    for (final bad in ['', '12345', '1234567', '12345a', ' 12345']) {
      expect(await controller.verify(bad), isFalse);
    }

    expect(repository.calls, ['request']);
    final diagnostic = container
        .read(notificationsControllerProvider)
        .diagnostic;
    expect(diagnostic?.code, 'verification_code_invalid');
    expect(diagnostic?.technicalReason, 'client_validation');
  });

  test(
    'a wrong code keeps the code field open with a safe diagnostic',
    () async {
      final (container, _) = setup(
        initial: preferences(verified: false, enabled: false),
      );
      final controller = container.read(
        notificationsControllerProvider.notifier,
      );
      await controller.startVerification();

      expect(await controller.verify('000000'), isFalse);

      final state = container.read(notificationsControllerProvider);
      expect(state.verificationStep, VerificationStep.codeSent);
      expect(state.diagnostic?.code, 'verification_code_invalid');
      expect(state.diagnostic?.correlationId, 'verify-1');
      expect(
        '${state.diagnostic?.userMessage}${state.diagnostic?.technicalReason}',
        isNot(contains('000000')),
      );
    },
  );

  test(
    'the wait the server asks for blocks resending until it passes',
    () async {
      final (container, repository) = setup(
        initial: preferences(verified: false, enabled: false),
      );
      final controller = container.read(
        notificationsControllerProvider.notifier,
      );
      repository.failNext = const NotificationFailure(
        code: 'verification_cooldown',
        userMessage: 'Ya te enviamos un código.',
        retryAfterSeconds: 40,
      );

      await controller.startVerification();

      final state = container.read(notificationsControllerProvider);
      expect(state.verificationStep, VerificationStep.idle);
      expect(state.resendAvailableAt, epoch.add(const Duration(seconds: 40)));
      expect(state.diagnostic?.code, 'verification_cooldown');
    },
  );

  test('a test email reports whether it was sent or queued', () async {
    final (container, repository) = setup();
    final controller = container.read(notificationsControllerProvider.notifier);
    await controller.load();

    await controller.sendTestEmail();
    expect(
      container.read(notificationsControllerProvider).testStatus,
      TestEmailStatus.sent,
    );

    repository.testStatus = TestEmailStatus.queued;
    await controller.sendTestEmail();
    expect(
      container.read(notificationsControllerProvider).testStatus,
      TestEmailStatus.queued,
    );
  });

  test(
    'an uncertain save is checked against the server before showing it',
    () async {
      final (container, repository) = setup();
      final controller = container.read(
        notificationsControllerProvider.notifier,
      );
      await controller.load();
      repository.failNext = const NotificationFailure(
        code: 'network_unavailable',
        userMessage: 'No pudimos confirmar si se guardó el cambio.',
        isMutationOutcomeUncertain: true,
      );

      await controller.setShowAmounts(false);

      expect(repository.calls.last, 'load'); // re-read to show the truth
      final state = container.read(notificationsControllerProvider);
      expect(state.diagnostic?.code, 'network_unavailable');
      expect(state.isSaving, isFalse);
    },
  );

  test(
    'an expired session and a surprise are reported without raw details',
    () async {
      final (container, repository) = setup();
      final controller = container.read(
        notificationsControllerProvider.notifier,
      );
      await controller.load();

      repository.failNext = const InvalidSessionFailure(
        correlationId: 'sess-1',
        technicalReason: 'http_401',
      );
      await controller.setEmailEnabled(false);
      expect(
        container.read(notificationsControllerProvider).diagnostic?.code,
        'session_invalid',
      );

      repository.failNext = StateError(
        'secret internal detail person@example.com',
      );
      await controller.setEmailEnabled(false);
      final diagnostic = container
          .read(notificationsControllerProvider)
          .diagnostic!;
      expect(diagnostic.code, 'unexpected_client_error');
      expect(
        '${diagnostic.userMessage}${diagnostic.technicalReason}',
        isNot(contains('secret')),
      );
      expect(
        '${diagnostic.userMessage}${diagnostic.technicalReason}',
        isNot(contains('person@')),
      );
    },
  );

  test('actions are ignored while another one is running', () async {
    final (container, repository) = setup();
    final controller = container.read(notificationsControllerProvider.notifier);
    await controller.load();

    final first = controller.sendTestEmail();
    final second = controller.sendTestEmail();
    await Future.wait([first, second]);

    expect(repository.calls.where((call) => call == 'test'), hasLength(1));
  });
}
