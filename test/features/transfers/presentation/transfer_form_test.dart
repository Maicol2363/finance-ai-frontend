import 'package:finance_ai/app.dart';
import 'package:finance_ai/core/router/app_router.dart';
import 'package:finance_ai/features/accounts/data/accounts_repository.dart';
import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/transfers/data/transfers_repository.dart';
import 'package:finance_ai/features/transfers/domain/transfer_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const cop = CurrencySummary(
  id: 1,
  code: 'COP',
  name: 'Colombian Peso',
  decimals: 2,
);
const usd = CurrencySummary(id: 2, code: 'USD', name: 'US Dollar', decimals: 2);

Account optionAccount({
  int id = 11,
  String name = 'Cash',
  CurrencySummary currency = cop,
  String balance = '1000000.00',
}) => Account(
  id: id,
  name: name,
  type: AccountType.cash,
  currency: currency,
  openingBalance: MoneyAmount.parseApi(balance),
  balance: MoneyAmount.parseApi(balance),
  currencyIsLocked: false,
  isActive: true,
  createdAt: DateTime.utc(2026, 9, 8),
  updatedAt: DateTime.utc(2026, 9, 8),
);

Transfer storedTransfer() => Transfer(
  id: 9,
  sourceAccount: const TransferAccount(
    id: 11,
    name: 'Cash',
    currencyCode: 'COP',
  ),
  sourceAmount: MoneyAmount.parseApi('100.00'),
  destinationAccount: const TransferAccount(
    id: 12,
    name: 'Savings',
    currencyCode: 'COP',
  ),
  destinationAmount: MoneyAmount.parseApi('100.00'),
  date: DateTime.utc(2026, 9, 18),
  description: null,
  createdAt: DateTime.utc(2026, 9, 18),
  updatedAt: DateTime.utc(2026, 9, 18),
);

class WidgetTransfersRepository implements TransfersRepository {
  TransferCreateCommand? lastCommand;

  @override
  Future<Transfer> create(TransferCreateCommand command) async {
    lastCommand = command;
    return storedTransfer();
  }
}

class WidgetOptionsAccountsRepository implements AccountsRepository {
  @override
  Future<AccountListResult> list({required bool includeInactive}) async =>
      AccountListResult(
        accounts: [
          optionAccount(),
          optionAccount(id: 12, name: 'Nequi'),
          optionAccount(id: 13, name: 'Dólares', currency: usd),
        ],
        suggestedCurrencyCode: 'COP',
        supportedCurrencies: const [cop, usd],
        accountTypes: AccountType.values,
      );

  @override
  Future<Account> get(int accountId) async => optionAccount(id: accountId);

  @override
  Future<Account> create(AccountCreateCommand command) async =>
      throw UnimplementedError();

  @override
  Future<Account> update(int accountId, AccountUpdateCommand command) async =>
      throw UnimplementedError();

  @override
  Future<Account> setActive(int accountId, {required bool isActive}) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteAccount(int accountId) async => throw UnimplementedError();
}

Future<void> pumpTransferForm(
  WidgetTester tester,
  WidgetTransfersRepository repository,
) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  final router = createAppRouter(initialLocation: '/accounts/transfer');
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        transfersRepositoryProvider.overrideWithValue(repository),
        accountsRepositoryProvider.overrideWithValue(
          WidgetOptionsAccountsRepository(),
        ),
      ],
      child: FinanceApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> selectOption(
  WidgetTester tester,
  Key fieldKey,
  String optionLabel,
) async {
  await tester.tap(find.byKey(fieldKey));
  await tester.pumpAndSettle();
  await tester.tap(find.text(optionLabel).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('transfer button opens the form from accounts', (tester) async {
    final transfers = WidgetTransfersRepository();
    final router = createAppRouter(initialLocation: '/accounts');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transfersRepositoryProvider.overrideWithValue(transfers),
          accountsRepositoryProvider.overrideWithValue(
            WidgetOptionsAccountsRepository(),
          ),
        ],
        child: FinanceApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('accounts-transfer-button')),
      200,
    );
    await tester.tap(find.byKey(const Key('accounts-transfer-button')));
    await tester.pumpAndSettle();

    expect(find.text('Transferir entre cuentas'), findsWidgets);
  });

  testWidgets('same-currency transfer submits a single amount', (tester) async {
    final transfers = WidgetTransfersRepository();
    await pumpTransferForm(tester, transfers);

    await selectOption(
      tester,
      const Key('transfer-source-field'),
      'Cash · COP',
    );
    await selectOption(
      tester,
      const Key('transfer-destination-field'),
      'Nequi · COP',
    );
    await tester.enterText(
      find.byKey(const Key('transfer-source-amount-field')),
      '100.00',
    );
    await tester.tap(find.byKey(const Key('transfer-save-button')));
    await tester.pumpAndSettle();

    expect(transfers.lastCommand?.sourceAccountId, 11);
    expect(transfers.lastCommand?.destinationAccountId, 12);
    expect(transfers.lastCommand?.sourceAmount.toApiString(), '100.00');
    expect(transfers.lastCommand?.destinationAmount, isNull);
  });

  testWidgets('cross-currency transfer requires the arriving amount', (
    tester,
  ) async {
    final transfers = WidgetTransfersRepository();
    await pumpTransferForm(tester, transfers);

    await selectOption(
      tester,
      const Key('transfer-source-field'),
      'Cash · COP',
    );
    await selectOption(
      tester,
      const Key('transfer-destination-field'),
      'Dólares · USD',
    );
    await tester.enterText(
      find.byKey(const Key('transfer-source-amount-field')),
      '410000.00',
    );
    await tester.tap(find.byKey(const Key('transfer-save-button')));
    await tester.pumpAndSettle();

    expect(transfers.lastCommand, isNull);
    expect(
      find.text('Indica cuánto llega en la moneda de destino.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('transfer-destination-amount-field')),
      '100.00',
    );
    await tester.tap(find.byKey(const Key('transfer-save-button')));
    await tester.pumpAndSettle();

    expect(transfers.lastCommand?.destinationAmount?.toApiString(), '100.00');
    expect(find.text('Transferencia guardada.'), findsOneWidget);
  });
}
