import 'package:finance_ai/app.dart';
import 'package:finance_ai/features/auth/session/data/secure_credential_store.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/real_api_helpers.dart';

const runRealAuthFlow = bool.fromEnvironment('RUN_REAL_AUTH_FLOW_TEST');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('registers logs in restores and logs out through the real API', (
    tester,
  ) async {
    final store = IntegrationMemoryCredentialStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [secureCredentialStoreProvider.overrideWithValue(store)],
        child: const FinanceApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('login-create-account-button')));
    await tester.pumpAndSettle();
    final uniqueEmail =
        'flutter-${DateTime.now().microsecondsSinceEpoch}@example.com';
    await tester.enterText(
      find.byKey(const Key('register-email-input')),
      uniqueEmail,
    );
    await tester.enterText(
      find.byKey(const Key('register-password-input')),
      'integration-safe-password-2026',
    );
    await tester.enterText(
      find.byKey(const Key('register-password-confirmation-input')),
      'integration-safe-password-2026',
    );

    await tester.tap(find.byKey(const Key('register-submit-button')));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(const Key('register-success-message')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('login-email-input')),
      uniqueEmail,
    );
    await tester.enterText(
      find.byKey(const Key('login-password-input')),
      'integration-safe-password-2026',
    );
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byKey(const Key('home-title')), findsOneWidget);
    expect(store.value, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [secureCredentialStoreProvider.overrideWithValue(store)],
        child: const FinanceApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byKey(const Key('home-title')), findsOneWidget);

    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(const Key('home-title')), findsNothing);
    expect(store.value, isNull);

    GoRouter.of(tester.element(find.byKey(const Key('login-email-input'))))
        .go('/accounts');
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(const Key('accounts-list')), findsNothing);
  }, skip: !runRealAuthFlow);
}
