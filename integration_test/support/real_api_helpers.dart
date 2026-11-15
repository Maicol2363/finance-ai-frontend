import 'package:finance_ai/app.dart';
import 'package:finance_ai/features/auth/session/data/secure_credential_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class IntegrationMemoryCredentialStore implements SecureCredentialStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> replace(String renewableCredential) async {
    value = renewableCredential;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

Future<void> mountFinanceApp(
  WidgetTester tester,
  IntegrationMemoryCredentialStore store,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [secureCredentialStoreProvider.overrideWithValue(store)],
      child: const FinanceApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> registerAndLogInToRealApi(
  WidgetTester tester,
  IntegrationMemoryCredentialStore store,
) async {
  await mountFinanceApp(tester, store);
  await tester.tap(find.byKey(const Key('login-create-account-button')));
  await tester.pumpAndSettle();

  final email = 'release-${DateTime.now().microsecondsSinceEpoch}@example.com';
  const password = 'integration-safe-password-2026';
  await tester.enterText(find.byKey(const Key('register-email-input')), email);
  await tester.enterText(
    find.byKey(const Key('register-password-input')),
    password,
  );
  await tester.enterText(
    find.byKey(const Key('register-password-confirmation-input')),
    password,
  );
  await tester.tap(find.byKey(const Key('register-submit-button')));
  await tester.pumpAndSettle(const Duration(seconds: 1));

  await tester.enterText(find.byKey(const Key('login-email-input')), email);
  await tester.enterText(
    find.byKey(const Key('login-password-input')),
    password,
  );
  await tester.tap(find.byKey(const Key('login-submit-button')));
  await tester.pumpAndSettle(const Duration(seconds: 1));
  expect(find.byKey(const Key('dashboard-account-balance')), findsOneWidget);
}

Future<void> openAccountsFromSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('bottom-nav-ajustes')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('settings-accounts-row')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('accounts-list')), findsOneWidget);
}

Future<void> createAccount(
  WidgetTester tester, {
  required String name,
  required String openingBalance,
}) async {
  await tester.tap(find.byKey(const Key('accounts-add-button')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('account-name-field')), name);
  await tester.enterText(
    find.byKey(const Key('account-opening-balance-field')),
    openingBalance,
  );
  await tester.ensureVisible(find.byKey(const Key('account-save-button')));
  await tester.tap(find.byKey(const Key('account-save-button')));
  await tester.pumpAndSettle(const Duration(seconds: 1));
  expect(find.text('Detalle de cuenta'), findsOneWidget);
  await tester.tap(find.byTooltip('Volver a cuentas'));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('accounts-list')), findsOneWidget);
}

Future<void> returnFromAccountsToSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Volver a la pantalla anterior'));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('settings-accounts-row')), findsOneWidget);
}
