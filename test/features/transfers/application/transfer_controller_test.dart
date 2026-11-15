import 'package:finance_ai/core/state/financial_data_revision.dart';
import 'package:finance_ai/features/accounts/application/accounts_controller.dart';
import 'package:finance_ai/features/accounts/application/accounts_state.dart';
import 'package:finance_ai/features/accounts/data/accounts_repository.dart';
import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/expenses/data/expenses_repository.dart';
import 'package:finance_ai/features/expenses/domain/expense_models.dart';
import 'package:finance_ai/features/expenses/domain/history_models.dart';
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
  MoneyAmount? balance,
}) => Account(
  id: id,
  name: name,
  type: AccountType.cash,
  currency: currency,
  openingBalance: MoneyAmount.parseApi('1000.00'),
  balance: balance ?? MoneyAmount.parseApi('1000.00'),
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
  int createCalls = 0;

  @override
  Future<Transfer> create(TransferCreateCommand command) async {
    createCalls += 1;
    lastCommand = command;
    if (failure case final error?) {
      throw error;
    }
    return result;
  }
}

class FakeAccountsRepository implements AccountsRepository {
  AccountListResult listResult = AccountListResult(
    accounts: [
      account(),
      account(id: 12, name: 'Savings'),
    ],
    suggestedCurrencyCode: 'COP',
    supportedCurrencies: const [cop, usd],
    accountTypes: AccountType.values,
  );
  int listCalls = 0;

  @override
  Future<AccountListResult> list({required bool includeInactive}) async {
    listCalls += 1;
    return listResult;
  }

  @override
  Future<Account> get(int accountId) => throw UnimplementedError();

  @override
  Future<Account> create(AccountCreateCommand command) =>
      throw UnimplementedError();

  @override
  Future<Account> update(int accountId, AccountUpdateCommand command) =>
      throw UnimplementedError();

  @override
  Future<Account> setActive(int accountId, {required bool isActive}) =>
      throw UnimplementedError();

  @override
  Future<void> deleteAccount(int accountId) => throw UnimplementedError();
}

class FakeExpensesRepository implements ExpensesRepository {
  int historyCalls = 0;
  Object? historyFailure;

  @override
  Future<ExpenseListResult> list({int page = 1, int pageSize = 50}) =>
      throw UnimplementedError();

  @override
  Future<Expense> get(int expenseId) => throw UnimplementedError();

  @override
  Future<Expense> create(ExpenseCreateCommand command) =>
      throw UnimplementedError();

  @override
  Future<Expense> update(int expenseId, ExpenseUpdateCommand command) =>
      throw UnimplementedError();

  @override
  Future<void> deleteExpense(int expenseId) => throw UnimplementedError();

  @override
  Future<HistoryResult> history(HistoryFilters filters) async {
    historyCalls += 1;
    if (historyFailure case final failure?) {
      throw failure;
    }
    return HistoryResult(
      items: const [],
      total: 0,
      page: 1,
      pageSize: 50,
      hasNext: false,
    );
  }
}

ProviderContainer containerWith(
  FakeTransfersRepository repository, {
  FakeAccountsRepository? accountsRepository,
  FakeExpensesRepository? expensesRepository,
}) {
  return ProviderContainer(
    overrides: [
      transfersRepositoryProvider.overrideWithValue(repository),
      accountsRepositoryProvider.overrideWithValue(
        accountsRepository ?? FakeAccountsRepository(),
      ),
      expensesRepositoryProvider.overrideWithValue(
        expensesRepository ?? FakeExpensesRepository(),
      ),
    ],
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
}) async {
  final outcome = await container
      .read(transferControllerProvider.notifier)
      .create(
        sourceAccountId: source,
        destinationAccountId: destination,
        sourceAmountInput: sourceAmount,
        destinationAmountInput: destinationAmount,
        date: date ?? DateTime.utc(2026, 9, 18),
      );
  // Let the account controller finish the refresh scheduled by the movement
  // revision before the test disposes its ProviderContainer.
  await Future<void>.delayed(Duration.zero);
  return outcome;
}

void main() {
  test('same-currency creation omits the destination amount', () async {
    final repository = FakeTransfersRepository();
    final accountsRepository = FakeAccountsRepository()
      ..listResult = AccountListResult(
        accounts: [
          account(balance: MoneyAmount.parseApi('900.00')),
          account(
            id: 12,
            name: 'Savings',
            balance: MoneyAmount.parseApi('1100.00'),
          ),
        ],
        suggestedCurrencyCode: 'COP',
        supportedCurrencies: const [cop, usd],
        accountTypes: AccountType.values,
      );
    final container = containerWith(
      repository,
      accountsRepository: accountsRepository,
    );
    addTearDown(container.dispose);
    seedAccounts(container, [account(), account(id: 12, name: 'Savings')]);

    final outcome = await submit(container);

    expect(outcome, TransferMutationOutcome.success);
    expect(repository.lastCommand?.destinationAmount, isNull);
    expect(repository.createCalls, 1);
    expect(accountsRepository.listCalls, 1);
    expect(
      container
          .read(accountsControllerProvider)
          .result
          ?.accountById(11)
          ?.balance
          .toApiString(),
      '900.00',
    );
    expect(container.read(financialMovementRevisionProvider), 1);
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
    'amounts beyond the cached source balance are submitted to the server',
    () async {
      final repository = FakeTransfersRepository();
      final container = containerWith(repository);
      addTearDown(container.dispose);
      seedAccounts(container, [account(), account(id: 12, name: 'Savings')]);

      final outcome = await submit(container, sourceAmount: '1000.01');

      expect(outcome, TransferMutationOutcome.success);
      expect(repository.lastCommand?.sourceAmount.toApiString(), '1000.01');

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
    expect(container.read(financialMovementRevisionProvider), 0);
  });

  test(
    'uncertain transfer refreshes accounts and history before retry',
    () async {
      final repository = FakeTransfersRepository()
        ..failure = const TransferFailure(
          code: 'network_unavailable',
          userMessage: 'Could not confirm transfer.',
          isMutationOutcomeUncertain: true,
        );
      final accountsRepository = FakeAccountsRepository();
      final expensesRepository = FakeExpensesRepository();
      final container = containerWith(
        repository,
        accountsRepository: accountsRepository,
        expensesRepository: expensesRepository,
      );
      addTearDown(container.dispose);
      seedAccounts(container, [account(), account(id: 12, name: 'Savings')]);

      expect(await submit(container), TransferMutationOutcome.failure);
      expect(
        container.read(transferControllerProvider).requiresMutationReview,
        isTrue,
      );

      await container
          .read(transferControllerProvider.notifier)
          .resolveUncertainMutation();

      expect(accountsRepository.listCalls, 1);
      expect(expensesRepository.historyCalls, 1);
      expect(
        container.read(transferControllerProvider).mutationStatus,
        TransferMutationStatus.idle,
      );
      expect(container.read(financialMovementRevisionProvider), 0);
    },
  );

  test('uncertain transfer stays blocked when history refresh fails', () async {
    final repository = FakeTransfersRepository()
      ..failure = const TransferFailure(
        code: 'network_unavailable',
        userMessage: 'Could not confirm transfer.',
        isMutationOutcomeUncertain: true,
      );
    final expensesRepository = FakeExpensesRepository()
      ..historyFailure = StateError('fixture history failure');
    final container = containerWith(
      repository,
      expensesRepository: expensesRepository,
    );
    addTearDown(container.dispose);
    seedAccounts(container, [account(), account(id: 12, name: 'Savings')]);

    expect(await submit(container), TransferMutationOutcome.failure);
    await container
        .read(transferControllerProvider.notifier)
        .resolveUncertainMutation();

    expect(
      container.read(transferControllerProvider).requiresMutationReview,
      isTrue,
    );
  });
}
