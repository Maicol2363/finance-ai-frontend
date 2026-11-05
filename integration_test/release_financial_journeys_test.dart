import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/real_api_helpers.dart';

const runRealFinancialJourneys = bool.fromEnvironment(
  'RUN_REAL_FINANCIAL_JOURNEYS',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('manual expense updates history and account balances', (
    tester,
  ) async {
    await registerAndLogInToRealApi(tester, IntegrationMemoryCredentialStore());
    await openAccountsFromSettings(tester);
    await createAccount(
      tester,
      name: 'Release Expense Account',
      openingBalance: '100000',
    );
    expect(find.text(r'$ 100.000 COP'), findsOneWidget);

    await returnFromAccountsToSettings(tester);
    await tester.tap(find.byKey(const Key('bottom-nav-inicio')));
    await tester.pumpAndSettle();
    expect(find.text(r'$ 100.000 COP'), findsOneWidget);

    await tester.tap(find.byKey(const Key('expenses-create-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expenses-wheel-manual')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('expense-create-merchant-field')),
      'Release expense smoke',
    );
    await tester.enterText(
      find.byKey(const Key('expense-create-amount-field')),
      '20000',
    );
    await tester.ensureVisible(
      find.byKey(const Key('expense-create-submit-button')),
    );
    await tester.tap(find.byKey(const Key('expense-create-submit-button')));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.byKey(const Key('dashboard-account-balance')), findsOneWidget);
    expect(find.text(r'$ 80.000 COP'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bottom-nav-movimientos')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history-list')), findsOneWidget);
    expect(find.text('Release expense smoke'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bottom-nav-ajustes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-accounts-row')));
    await tester.pumpAndSettle();
    expect(find.text(r'$ 80.000 COP'), findsOneWidget);
    expect(find.text('Release Expense Account'), findsOneWidget);
  }, skip: !runRealFinancialJourneys);

  testWidgets(
    'transfer updates both accounts once and survives tab navigation',
    (tester) async {
      await registerAndLogInToRealApi(
        tester,
        IntegrationMemoryCredentialStore(),
      );
      await openAccountsFromSettings(tester);
      await createAccount(
        tester,
        name: 'Release Transfer Source',
        openingBalance: '100000',
      );
      await createAccount(
        tester,
        name: 'Release Transfer Destination',
        openingBalance: '10000',
      );

      await tester.tap(find.byKey(const Key('accounts-transfer-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('transfer-source-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Release Transfer Source · COP').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('transfer-destination-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Release Transfer Destination · COP').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('transfer-source-amount-field')),
        '30000',
      );
      await tester.enterText(
        find.byKey(const Key('transfer-description-field')),
        'Release transfer smoke',
      );
      await tester.ensureVisible(find.byKey(const Key('transfer-save-button')));
      await tester.tap(find.byKey(const Key('transfer-save-button')));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.byKey(const Key('accounts-list')), findsOneWidget);
      expect(find.text(r'$ 70.000 COP'), findsOneWidget);
      expect(find.text(r'$ 40.000 COP'), findsOneWidget);

      await returnFromAccountsToSettings(tester);
      await tester.tap(find.byKey(const Key('bottom-nav-movimientos')));
      await tester.pumpAndSettle();
      expect(find.text('Release transfer smoke'), findsOneWidget);

      await tester.tap(find.byKey(const Key('bottom-nav-inicio')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bottom-nav-movimientos')));
      await tester.pumpAndSettle();
      expect(find.text('Release transfer smoke'), findsOneWidget);

      await tester.tap(find.byKey(const Key('bottom-nav-ajustes')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-accounts-row')));
      await tester.pumpAndSettle();
      expect(find.text(r'$ 70.000 COP'), findsOneWidget);
      expect(find.text(r'$ 40.000 COP'), findsOneWidget);
    },
    skip: !runRealFinancialJourneys,
  );
}
