import 'package:finance_ai/features/accounts/application/accounts_controller.dart';
import 'package:finance_ai/features/accounts/application/accounts_state.dart';
import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/transfers/application/transfer_controller.dart';
import 'package:finance_ai/features/transfers/application/transfer_state.dart';
import 'package:finance_ai/features/transfers/data/transfers_repository.dart';
import 'package:finance_ai/features/transfers/domain/transfer_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const cop = CurrencySummary(
  id: 1,
  code: 'COP',
  name: 'Colombian Peso',
  decimals: 2,
);
const usd = CurrencySummary(id: 2, code: 'USD', name: 'US Dollar', decimals: 2);

Account account({
  int id = 11,
  String name = 'Cash',
  CurrencySummary currency = cop,
}) => Account(
  id: id,
  name: name,
  type: AccountType.cash,
  currency: currency,
  openingBalance: MoneyAmount.parseApi('1000.00'),
  balance: MoneyAmount.parseApi('1000.00'),
  currencyIsLocked: false,
  isActive: true,
  createdAt: DateTime.utc(2026, 9, 8),
  updatedAt: DateTime.utc(2026, 9, 8),
);

Transfer transfer() => Transfer(
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

class FakeTransfersRepository implements TransfersRepository {
  Transfer result = transfer();
  Object? failure;
  TransferCreateCommand? lastCommand;

  @override
  Future<Transfer> create(TransferCreateCommand command) async {
    lastCommand = command;
    if (failure case final error?) {
      throw error;
    }
    return result;
  }
}

ProviderContainer containerWith(FakeTransfersRepository repository) {
  return ProviderContainer(
    overrides: [transfersRepositoryProvider.overrideWithValue(repository)],
  );
}

void seedAccounts(ProviderContainer container, List<Account> accounts) {
  container.read(accountsControllerProvider.notifier).state = AccountsState(
    listStatus: AccountsLoadStatus.ready,
    result: AccountListResult(
      accounts: accounts,
      suggestedCurrencyCode: 'COP',
      supportedCurrencies: const [cop, usd],
      accountTypes: AccountType.values,
    ),
  );
}

Future<TransferMutationOutcome> submit(
  ProviderContainer container, {
  int? source = 11,
  int? destination = 12,
  String sourceAmount = '100.00',
  String? destinationAmount,
  DateTime? date,
}) {
  return container
      .read(transferControllerProvider.notifier)
      .create(
        sourceAccountId: source,
        destinationAccountId: destination,
        sourceAmountInput: sourceAmount,
        destinationAmountInput: destinationAmount,
        date: date ?? DateTime.utc(2026, 9, 18),
      );
}

void main() {
  test('same-currency creation omits the destination amount', () async {
    final repository = FakeTransfersRepository();
    final container = containerWith(repository);
    addTearDown(container.dispose);
    seedAccounts(container, [account(), account(id: 12, name: 'Savings')]);

    final outcome = await submit(container);

    expect(outcome, TransferMutationOutcome.success);
    expect(repository.lastCommand?.destinationAmount, isNull);
    expect(container.read(transferControllerProvider).lastTransfer?.id, 9);
  });

  test('cross-currency creation requires and sends both amounts', () async {
    final repository = FakeTransfersRepository();
    final container = containerWith(repository);
    addTearDown(container.dispose);
    seedAccounts(container, [
      account(),
      account(id: 13, name: 'Dólares', currency: usd),
    ]);

    final missing = await submit(container, destination: 13);
    expect(missing, TransferMutationOutcome.invalid);
    expect(repository.lastCommand, isNull);
    expect(
      container.read(transferControllerProvider).fieldErrors,
      contains('destination_amount'),
    );

    final outcome = await submit(
      container,
      destination: 13,
      destinationAmount: '410000.00',
    );
    expect(outcome, TransferMutationOutcome.success);
    expect(
      repository.lastCommand?.destinationAmount?.toApiString(),
      '410000.00',
    );
  });

  test(
    'amounts beyond the source balance are invalid without API calls',
    () async {
      final repository = FakeTransfersRepository();
      final container = containerWith(repository);
      addTearDown(container.dispose);
      seedAccounts(container, [account(), account(id: 12, name: 'Savings')]);

      final outcome = await submit(container, sourceAmount: '1000.01');

      expect(outcome, TransferMutationOutcome.invalid);
      expect(repository.lastCommand, isNull);
      expect(
        container.read(transferControllerProvider).fieldErrors,
        contains('source_amount'),
      );

      final exact = await submit(container, sourceAmount: '1000.00');
      expect(exact, TransferMutationOutcome.success);
    },
  );

  test('same account and bad amounts are invalid without API calls', () async {
    final repository = FakeTransfersRepository();
    final container = containerWith(repository);
    addTearDown(container.dispose);
    seedAccounts(container, [account(), account(id: 12, name: 'Savings')]);
    final controller = container.read(transferControllerProvider.notifier);

    expect(
      await submit(container, destination: 11),
      TransferMutationOutcome.invalid,
    );
    expect(
      container.read(transferControllerProvider).fieldErrors,
      contains('destination_account_id'),
    );
    expect(
      await submit(container, sourceAmount: 'abc'),
      TransferMutationOutcome.invalid,
    );
    expect(controller.state.fieldErrors, contains('source_amount'));
    expect(repository.lastCommand, isNull);
  });

  test('server failure maps to a safe diagnostic', () async {
    final repository = FakeTransfersRepository()
      ..failure = const TransferFailure(
        code: 'transfer_same_account',
        userMessage: 'Elige dos cuentas distintas.',
      );
    final container = containerWith(repository);
    addTearDown(container.dispose);
    seedAccounts(container, [account(), account(id: 12, name: 'Savings')]);

    final outcome = await submit(container);

    expect(outcome, TransferMutationOutcome.failure);
    expect(
      container.read(transferControllerProvider).mutationDiagnostic?.code,
      'transfer_same_account',
    );
  });
}
