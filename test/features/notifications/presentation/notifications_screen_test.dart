import 'package:finance_ai/app.dart';
import 'package:finance_ai/core/router/app_router.dart';
import 'package:finance_ai/features/notifications/application/notifications_controller.dart';
import 'package:finance_ai/features/notifications/data/notifications_repository.dart';
import 'package:finance_ai/features/notifications/domain/notification_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../notifications_test_helpers.dart';

Future<void> pumpScreen(
  WidgetTester tester,
  FakeNotificationsRepository repository, {
  DateTime Function()? clock,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = createAppRouter(initialLocation: '/notifications');
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationsRepositoryProvider.overrideWithValue(repository),
        if (clock != null) notificationsClockProvider.overrideWithValue(clock),
      ],
      child: FinanceApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an unverified address starts with sending a code', (
    tester,
  ) async {
    final repository = FakeNotificationsRepository(
      initial: preferences(verified: false, enabled: false),
    );
    await pumpScreen(tester, repository);

    expect(find.byKey(const Key('notifications-send-code')), findsOneWidget);
    expect(find.textContaining('a***@example.com'), findsOneWidget);
    expect(find.byKey(const Key('notifications-email-switch')), findsNothing);
  });

  testWidgets(
    'sending a code reveals the field, then verifying opens the switches',
    (tester) async {
      final repository = FakeNotificationsRepository(
        initial: preferences(verified: false, enabled: false),
      );
      await pumpScreen(tester, repository);

      await tester.tap(find.byKey(const Key('notifications-send-code')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notifications-code-field')), findsOneWidget);
      expect(find.textContaining('Pedir otro código en'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('notifications-code-field')),
        '123456',
      );
      await tester.tap(find.byKey(const Key('notifications-verify')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('notifications-email-switch')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('notifications-budget-switch')),
        findsOneWidget,
      );
      expect(repository.calls, containsAllInOrder(['request', 'verify']));
    },
  );

  testWidgets('a wrong code shows a copyable diagnostic and keeps the field', (
    tester,
  ) async {
    final repository = FakeNotificationsRepository(
      initial: preferences(verified: false, enabled: false),
    );
    await pumpScreen(tester, repository);
    await tester.tap(find.byKey(const Key('notifications-send-code')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('notifications-code-field')),
      '000000',
    );
    await tester.tap(find.byKey(const Key('notifications-verify')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ese código no es correcto'), findsOneWidget);
    // The shared diagnostic panel offers the copyable report (it carries the correlation id).
    expect(find.byKey(const Key('copy-error-details-button')), findsOneWidget);
    expect(find.byKey(const Key('notifications-code-field')), findsOneWidget);
  });

  testWidgets('the code field accepts only digits and at most six', (
    tester,
  ) async {
    final repository = FakeNotificationsRepository(
      initial: preferences(verified: false, enabled: false),
    );
    await pumpScreen(tester, repository);
    await tester.tap(find.byKey(const Key('notifications-send-code')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('notifications-code-field')),
      '12a34 5678',
    );

    final field = tester.widget<TextField>(
      find.byKey(const Key('notifications-code-field')),
    );
    expect(field.controller?.text, '123456');
  });

  testWidgets('the resend button waits for the countdown', (tester) async {
    var now = DateTime.utc(2026, 11, 16, 15);
    final repository = FakeNotificationsRepository(
      initial: preferences(verified: false, enabled: false),
    );
    await pumpScreen(tester, repository, clock: () => now);
    await tester.tap(find.byKey(const Key('notifications-send-code')));
    await tester.pumpAndSettle();

    TextButton resend() => tester.widget<TextButton>(
      find.byKey(const Key('notifications-resend')),
    );
    expect(resend().onPressed, isNull);

    now = now.add(const Duration(seconds: 61));
    await tester.pump(const Duration(seconds: 1));
    expect(resend().onPressed, isNotNull);
    expect(find.text('Pedir otro código'), findsOneWidget);
  });

  testWidgets('a verified person sees the switches and can send a test email', (
    tester,
  ) async {
    final repository = FakeNotificationsRepository();
    await pumpScreen(tester, repository);

    expect(
      find.byKey(const Key('notifications-budget-switch')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('notifications-amounts-switch')));
    await tester.pumpAndSettle();
    expect(repository.current.showAmounts, isFalse);

    await tester.tap(find.byKey(const Key('notifications-test-row')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enviado. Revisa tu bandeja'), findsOneWidget);
  });

  testWidgets('turning the master switch off hides what depends on it', (
    tester,
  ) async {
    final repository = FakeNotificationsRepository();
    await pumpScreen(tester, repository);

    await tester.tap(find.byKey(const Key('notifications-email-switch')));
    await tester.pumpAndSettle();

    expect(repository.current.emailEnabled, isFalse);
    expect(find.byKey(const Key('notifications-budget-switch')), findsNothing);
    expect(find.byKey(const Key('notifications-test-row')), findsNothing);
  });

  testWidgets(
    'a deployment that cannot send email says so instead of offering it',
    (tester) async {
      final repository = FakeNotificationsRepository(
        initial: preferences(
          verified: false,
          enabled: false,
          deliveryAvailable: false,
        ),
      );
      await pumpScreen(tester, repository);

      expect(
        find.byKey(const Key('notifications-unavailable')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('notifications-send-code')), findsNothing);
    },
  );

  testWidgets('a failed load offers a retry', (tester) async {
    final repository = FakeNotificationsRepository()
      ..failNext = const NotificationFailure(
        code: 'network_unavailable',
        userMessage: 'No pudimos cargar tus avisos.',
      );
    await pumpScreen(tester, repository);

    expect(find.textContaining('No pudimos cargar tus avisos'), findsOneWidget);
    await tester.tap(find.byKey(const Key('notifications-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notifications-email-switch')), findsOneWidget);
  });
}
