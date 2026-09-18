import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/expenses/application/history_controller.dart';
import 'package:finance_ai/features/expenses/application/history_state.dart';
import 'package:finance_ai/features/expenses/data/expenses_repository.dart';
import 'package:finance_ai/features/expenses/domain/expense_models.dart';
import 'package:finance_ai/features/expenses/domain/history_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

HistoryItem item({int id = 8}) => HistoryItem(
  id: id,
  type: TransactionType.expense,
  status: ExpenseStatus.confirmed,
  occurredAt: DateTime.utc(2026, 9, 17, 12, 30),
  description: 'Purchase at Market',
  captureSource: CaptureSource.manual,
  incomeSource: null,
  movements: [
    HistoryMovement(
      accountId: 11,
      accountName: 'Cash',
      amount: MoneyAmount.parseApi('-25.00'),
      currency: const CurrencySummary(
        id: 1,
        code: 'COP',
        name: 'Colombian Peso',
        decimals: 2,
      ),
      currencyCode: 'COP',
    ),
  ],
  expense: null,
);

HistoryResult historyPage({List<HistoryItem>? items, int page = 1}) =>
    HistoryResult(
      items: items ?? [item()],
      total: (items ?? [item()]).length,
      page: page,
      pageSize: 50,
      hasNext: false,
    );

class FakeExpensesRepository implements ExpensesRepository {
  HistoryResult historyResult = historyPage();
  Object? historyFailure;
  final List<HistoryFilters> seenFilters = [];

  @override
  Future<ExpenseListResult> list({int page = 1, int pageSize = 50}) async {
    throw UnimplementedError();
  }

  @override
  Future<Expense> get(int expenseId) async {
    throw UnimplementedError();
  }

  @override
  Future<Expense> update(int expenseId, ExpenseUpdateCommand command) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteExpense(int expenseId) async {
    throw UnimplementedError();
  }

  @override
  Future<HistoryResult> history(HistoryFilters filters) async {
    seenFilters.add(filters);
    if (historyFailure case final failure?) {
      throw failure;
    }
    return historyResult;
  }
}

void main() {
  test('load populates history and loadMore appends pages', () async {
    final repository = FakeExpensesRepository()
      ..historyResult = HistoryResult(
        items: [item()],
        total: 2,
        page: 1,
        pageSize: 50,
        hasNext: true,
      );
    final container = ProviderContainer(
      overrides: [expensesRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(historyControllerProvider.notifier);

    await controller.load();
    expect(
      container.read(historyControllerProvider).result?.items,
      hasLength(1),
    );

    repository.historyResult = historyPage(items: [item(id: 9)], page: 2);
    await controller.loadMore();

    final state = container.read(historyControllerProvider);
    expect(state.result?.items.map((entry) => entry.id), [8, 9]);
    expect(repository.seenFilters.last.page, 2);
  });

  test('updating filters reloads from the first page', () async {
    final repository = FakeExpensesRepository();
    final container = ProviderContainer(
      overrides: [expensesRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container
        .read(historyControllerProvider.notifier)
        .updateFilters(const HistoryFilters(type: TransactionType.income));

    expect(
      container.read(historyControllerProvider).status,
      HistoryLoadStatus.ready,
    );
    expect(repository.seenFilters.single.type, TransactionType.income);
    expect(repository.seenFilters.single.page, 1);
  });

  test('history failure exposes a copyable diagnostic', () async {
    final repository = FakeExpensesRepository()
      ..historyFailure = const ExpenseFailure(
        code: 'history_filter_invalid',
        userMessage: 'Please correct the selected history filters.',
      );
    final container = ProviderContainer(
      overrides: [expensesRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(historyControllerProvider.notifier).load();

    final state = container.read(historyControllerProvider);
    expect(state.status, HistoryLoadStatus.failure);
    expect(state.diagnostic?.operation, 'load_history');
    expect(state.diagnostic?.code, 'history_filter_invalid');
  });
}
