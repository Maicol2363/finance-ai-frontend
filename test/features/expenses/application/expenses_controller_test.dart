import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/expenses/application/expenses_controller.dart';
import 'package:finance_ai/features/expenses/application/expenses_state.dart';
import 'package:finance_ai/features/expenses/data/expenses_repository.dart';
import 'package:finance_ai/features/expenses/domain/expense_models.dart';
import 'package:finance_ai/features/expenses/domain/history_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const cop = CurrencySummary(
  id: 1,
  code: 'COP',
  name: 'Colombian Peso',
  decimals: 2,
);

Expense expense({int id = 7, String name = 'Groceries'}) => Expense(
  id: id,
  transactionId: 8,
  receiptId: 9,
  name: name,
  amount: MoneyAmount.parseApi('25.00'),
  quantity: '1.000',
  unitPrice: MoneyAmount.parseApi('25.00'),
  note: 'Weekly food',
  category: const ExpenseCategory(id: 3, name: 'Food'),
  receiptName: 'Market',
  receiptNote: 'Household purchase',
  store: 'Market',
  description: 'Purchase at Market',
  occurredAt: DateTime.utc(2026, 9, 17, 12, 30),
  status: ExpenseStatus.confirmed,
  captureSource: CaptureSource.manual,
  accountId: 11,
  accountName: 'Cash',
  accountIsActive: true,
  currency: cop,
  currencyCode: 'COP',
  createdAt: DateTime.utc(2026, 9, 17, 12, 30),
  updatedAt: DateTime.utc(2026, 9, 17, 12, 30),
  receiptImage: 'receipt.jpg',
  imagePath: 'expense.jpg',
);

ExpenseListResult pageResult({
  List<Expense>? items,
  int page = 1,
  bool hasNext = false,
}) => ExpenseListResult(
  items: items ?? [expense()],
  total: (items ?? [expense()]).length,
  page: page,
  pageSize: 50,
  hasNext: hasNext,
);

class FakeExpensesRepository implements ExpensesRepository {
  ExpenseListResult listResult = pageResult();
  Object? listFailure;
  Object? getFailure;
  Object? updateFailure;
  Object? deleteFailure;
  int listCalls = 0;
  int deleteCalls = 0;
  bool deleteRemovesBeforeFailure = false;
  ExpenseCreateCommand? lastCreateCommand;
  Object? createFailure;
  ExpenseUpdateCommand? lastCommand;

  @override
  Future<ExpenseListResult> list({int page = 1, int pageSize = 50}) async {
    listCalls += 1;
    if (listFailure case final failure?) {
      throw failure;
    }
    return listResult;
  }

  @override
  Future<Expense> get(int expenseId) async {
    if (getFailure case final failure?) {
      throw failure;
    }
    return expense(id: expenseId);
  }

  @override
  Future<Expense> create(ExpenseCreateCommand command) async {
    lastCreateCommand = command;
    if (createFailure case final failure?) {
      throw failure;
    }
    final created = expense(id: 99, name: command.merchant);
    listResult = pageResult(items: [created, ...listResult.items]);
    return created;
  }

  @override
  Future<Expense> update(int expenseId, ExpenseUpdateCommand command) async {
    lastCommand = command;
    if (updateFailure case final failure?) {
      throw failure;
    }
    final updated = expense(id: expenseId, name: command.name ?? 'Groceries');
    listResult = pageResult(
      items: [
        for (final item in listResult.items)
          if (item.id == expenseId) updated else item,
      ],
    );
    return updated;
  }

  @override
  Future<void> deleteExpense(int expenseId) async {
    deleteCalls += 1;
    if (deleteRemovesBeforeFailure) {
      listResult = pageResult(
        items: listResult.items.where((item) => item.id != expenseId).toList(),
      );
    }
    if (deleteFailure case final failure?) {
      throw failure;
    }
    listResult = pageResult(
      items: listResult.items.where((item) => item.id != expenseId).toList(),
    );
  }

  @override
  Future<HistoryResult> history(HistoryFilters filters) async {
    throw UnimplementedError();
  }
}

ProviderContainer containerWith(FakeExpensesRepository repository) {
  return ProviderContainer(
    overrides: [expensesRepositoryProvider.overrideWithValue(repository)],
  );
}

void main() {
  test('load populates the list and loadMore appends once', () async {
    final repository = FakeExpensesRepository()
      ..listResult = pageResult(hasNext: true);
    final container = containerWith(repository);
    addTearDown(container.dispose);
    final controller = container.read(expensesControllerProvider.notifier);

    await controller.load();
    expect(
      container.read(expensesControllerProvider).result?.items,
      hasLength(1),
    );

    repository.listResult = pageResult(
      items: [expense(id: 8, name: 'Bread')],
      page: 2,
    );
    await controller.loadMore();

    final state = container.read(expensesControllerProvider);
    expect(state.result?.items.map((item) => item.id), [7, 8]);
    expect(state.result?.hasNext, isFalse);
    expect(repository.listCalls, 2);
  });

  test('load failure exposes a copyable list diagnostic', () async {
    final repository = FakeExpensesRepository()
      ..listFailure = const ExpenseFailure(
        code: 'service_unavailable',
        userMessage: 'Try again later.',
      );
    final container = containerWith(repository);
    addTearDown(container.dispose);

    await container.read(expensesControllerProvider.notifier).load();

    final state = container.read(expensesControllerProvider);
    expect(state.listStatus, ExpensesLoadStatus.failure);
    expect(state.listDiagnostic?.operation, 'load_expenses');
  });

  test('update without changes is invalid and never calls the API', () async {
    final repository = FakeExpensesRepository();
    final container = containerWith(repository);
    addTearDown(container.dispose);

    final outcome = await container
        .read(expensesControllerProvider.notifier)
        .update(expenseId: 7);

    expect(outcome, ExpenseMutationOutcome.invalid);
    expect(repository.lastCommand, isNull);
    expect(
      container.read(expensesControllerProvider).fieldErrors,
      contains('request'),
    );
  });

  test('update with a bad amount is invalid and never calls the API', () async {
    final repository = FakeExpensesRepository();
    final container = containerWith(repository);
    addTearDown(container.dispose);

    final outcome = await container
        .read(expensesControllerProvider.notifier)
        .update(expenseId: 7, amountInput: 'abc');

    expect(outcome, ExpenseMutationOutcome.invalid);
    expect(repository.lastCommand, isNull);
    expect(
      container.read(expensesControllerProvider).fieldErrors,
      contains('amount'),
    );
  });

  test('update success refreshes the canonical list', () async {
    final repository = FakeExpensesRepository();
    final container = containerWith(repository);
    addTearDown(container.dispose);
    final controller = container.read(expensesControllerProvider.notifier);

    await controller.load();
    final outcome = await controller.update(
      expenseId: 7,
      name: 'Updated groceries',
    );

    expect(outcome, ExpenseMutationOutcome.success);
    expect(repository.lastCommand?.name, 'Updated groceries');
    expect(
      container.read(expensesControllerProvider).result?.items.single.name,
      'Updated groceries',
    );
  });

  test('update sends the replaced receipt lines', () async {
    final repository = FakeExpensesRepository();
    final container = containerWith(repository);
    addTearDown(container.dispose);
    final controller = container.read(expensesControllerProvider.notifier);

    await controller.load();
    final outcome = await controller.update(
      expenseId: 7,
      items: const [
        ExpenseItemUpdateCommand(
          name: 'Leche',
          totalPrice: 4000,
          quantity: 2,
          categoryId: 3,
        ),
        ExpenseItemUpdateCommand(name: 'Pan', totalPrice: 3000),
      ],
    );

    expect(outcome, ExpenseMutationOutcome.success);
    expect(repository.lastCommand?.items, hasLength(2));
    expect(repository.lastCommand?.toJson()['items'], [
      {
        'name': 'Leche',
        'total_price': '4000.00',
        'quantity': '2.0',
        'category_id': 3,
      },
      {'name': 'Pan', 'total_price': '3000.00', 'quantity': '1.0'},
    ]);
  });

  test(
    'update rejects an invalid receipt line and never calls the API',
    () async {
      final repository = FakeExpensesRepository();
      final container = containerWith(repository);
      addTearDown(container.dispose);
      final controller = container.read(expensesControllerProvider.notifier);

      final outcome = await controller.update(
        expenseId: 7,
        items: const [ExpenseItemUpdateCommand(name: '   ', totalPrice: 0)],
      );

      expect(outcome, ExpenseMutationOutcome.invalid);
      expect(repository.lastCommand, isNull);
      expect(
        container.read(expensesControllerProvider).fieldErrors,
        contains('items'),
      );
    },
  );

  test('uncertain delete resolves to success when the item is gone', () async {
    final repository = FakeExpensesRepository()
      ..deleteRemovesBeforeFailure = true
      ..deleteFailure = const ExpenseFailure(
        code: 'network_unavailable',
        userMessage: 'Uncertain.',
        isMutationOutcomeUncertain: true,
      );
    final container = containerWith(repository);
    addTearDown(container.dispose);

    final outcome = await container
        .read(expensesControllerProvider.notifier)
        .deleteExpense(7);

    expect(outcome, ExpenseMutationOutcome.success);
    expect(container.read(expensesControllerProvider).result?.items, isEmpty);
  });

  test('uncertain delete keeps the diagnostic when the item remains', () async {
    final repository = FakeExpensesRepository()
      ..deleteFailure = const ExpenseFailure(
        code: 'network_unavailable',
        userMessage: 'Uncertain.',
        isMutationOutcomeUncertain: true,
      );
    final container = containerWith(repository);
    addTearDown(container.dispose);

    final outcome = await container
        .read(expensesControllerProvider.notifier)
        .deleteExpense(7);

    expect(outcome, ExpenseMutationOutcome.failure);
    expect(
      container.read(expensesControllerProvider).mutationDiagnostic,
      isNotNull,
    );
  });
}
