import 'package:finance_ai/features/accounts/data/accounts_repository.dart';
import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'expenses_screens_test.dart' as screens;

class _UsdAccountsRepository implements AccountsRepository {
  @override
  Future<AccountListResult> list({required bool includeInactive}) async {
    const usd = CurrencySummary(
      id: 2,
      code: 'USD',
      name: 'US Dollar',
      decimals: 2,
    );
    final account = Account(
      id: 12,
      name: 'Dólares',
      type: AccountType.cash,
      currency: usd,
      balance: MoneyAmount.parseApi('1250.00'),
      openingBalance: MoneyAmount.parseApi('1250.00'),
      currencyIsLocked: false,
      isActive: true,
      createdAt: DateTime.utc(2026, 9, 1, 10, 0),
      updatedAt: DateTime.utc(2026, 9, 1, 10, 0),
    );
    return AccountListResult(
      accounts: [account],
      suggestedCurrencyCode: 'COP',
      supportedCurrencies: const [screens.cop, usd],
      accountTypes: AccountType.values,
    );
  }

  @override
  Future<Account> get(int accountId) =>
      throw UnimplementedError('get not needed in a11y label test');

  @override
  Future<Account> create(AccountCreateCommand command) =>
      throw UnimplementedError('create not needed in a11y label test');

  @override
  Future<Account> update(int accountId, AccountUpdateCommand command) =>
      throw UnimplementedError('update not needed in a11y label test');

  @override
  Future<Account> setActive(int accountId, {required bool isActive}) =>
      throw UnimplementedError('setActive not needed in a11y label test');

  @override
  Future<void> deleteAccount(int accountId) =>
      throw UnimplementedError('delete not needed in a11y label test');
}

Future<void> _pumpCreate(
  WidgetTester tester, {
  AccountsRepository? accountsRepository,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);

  await screens.pumpExpensesApp(
    tester,
    screens.WidgetExpensesRepository(),
    initialLocation: '/expenses/new',
    accountsRepository: accountsRepository,
  );
}

void _expectAmountSemantics(String expectedLabel) {
  expect(
    find.ancestor(
      of: find.byKey(const Key('expense-create-amount-field')),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == expectedLabel &&
            w.explicitChildNodes,
      ),
    ),
    findsOneWidget,
  );
}

void main() {
  testWidgets('p6_form: amount and merchant fields expose labels', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();

    await _pumpCreate(tester);

    final amountField = tester.widget<TextField>(
      find.byKey(const Key('expense-create-amount-field')),
    );
    expect(amountField.decoration?.labelText, 'Monto');

    // COP por defecto: cuenta Cash en pesos.
    _expectAmountSemantics('Monto en pesos');
    expect(
      tester
          .getSemantics(find.byKey(const Key('expense-create-amount-field')))
          .label,
      contains('Monto'),
    );

    final merchantField = tester.widget<TextField>(
      find.byKey(const Key('expense-create-merchant-field')),
    );
    expect(merchantField.decoration?.labelText, isNotNull);
    expect(merchantField.decoration!.labelText!, isNotEmpty);

    await tester.tap(find.byKey(const Key('segment-ingreso')));
    await tester.pumpAndSettle();

    final customSourceField = tester.widget<TextField>(
      find.byKey(const Key('income-create-source-custom-field')),
    );
    expect(customSourceField.decoration?.labelText, isNotNull);
    expect(customSourceField.decoration!.labelText!, isNotEmpty);
    semanticsHandle.dispose();
  });

  testWidgets('p6_form: amount label follows USD account currency', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();

    await _pumpCreate(tester, accountsRepository: _UsdAccountsRepository());

    _expectAmountSemantics('Monto en dólares');
    expect(
      find.ancestor(
        of: find.byKey(const Key('expense-create-amount-field')),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Monto en pesos' &&
              w.explicitChildNodes,
        ),
      ),
      findsNothing,
    );
    semanticsHandle.dispose();
  });
}
