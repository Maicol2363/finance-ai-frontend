import 'dart:async';

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
  Completer<HistoryResult>? pendingHistory;
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
  Future<Expense> create(ExpenseCreateCommand command) async {
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
    final pending = pendingHistory;
    if (pending != null) {
      pendingHistory = null;
      return pending.future;
    }
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

  test(
    'load requested during loadMore reloads the first page afterward',
    () async {
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
      final nextPage = Completer<HistoryResult>();
      repository.pendingHistory = nextPage;

      final loadMore = controller.loadMore();
      expect(
        container.read(historyControllerProvider).status,
        HistoryLoadStatus.loadingMore,
      );
      await controller.load();

      repository.historyResult = historyPage(items: [item(id: 10)]);
      nextPage.complete(historyPage(items: [item(id: 9)], page: 2));
      await loadMore;

      final state = container.read(historyControllerProvider);
      expect(state.status, HistoryLoadStatus.ready);
      expect(state.result?.items.map((entry) => entry.id), [10]);
      expect(repository.seenFilters.map((filters) => filters.page), [1, 2, 1]);
    },
  );

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

  test(
    'intent methods keep the rest of the query and reset to page 1',
    () async {
      final repository = FakeExpensesRepository();
      final container = ProviderContainer(
        overrides: [expensesRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final controller = container.read(historyControllerProvider.notifier);

      await controller.setSearch(' market ');
      await controller.setType(TransactionType.income);
      await controller.setAccountId(11);

      final filters = container.read(historyControllerProvider).filters;
      expect(filters.search, 'market');
      expect(filters.type, TransactionType.income);
      expect(filters.accountId, 11);
      expect(filters.page, 1);
      expect(repository.seenFilters.last.accountId, 11);
      expect(repository.seenFilters.last.search, 'market');
      expect(repository.seenFilters.last.type, TransactionType.income);
    },
  );

  test('setPeriod keeps dates only for the custom preset', () async {
    final repository = FakeExpensesRepository();
    final container = ProviderContainer(
      overrides: [expensesRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(historyControllerProvider.notifier);

    await controller.setPeriod(
      HistoryPeriod.custom,
      startDate: DateTime.utc(2026, 9, 1),
      endDate: DateTime.utc(2026, 9, 15),
    );
    var filters = container.read(historyControllerProvider).filters;
    expect(filters.period, HistoryPeriod.custom);
    expect(filters.startDate, DateTime.utc(2026, 9, 1));
    expect(filters.endDate, DateTime.utc(2026, 9, 15));

    await controller.setPeriod(HistoryPeriod.month);
    filters = container.read(historyControllerProvider).filters;
    expect(filters.period, HistoryPeriod.month);
    expect(filters.startDate, isNull);
    expect(filters.endDate, isNull);

    await controller.setPeriod(null);
    expect(container.read(historyControllerProvider).filters.period, isNull);
  });

  test(
    'blank search clears the filter and clearFilters drops everything',
    () async {
      final repository = FakeExpensesRepository();
      final container = ProviderContainer(
        overrides: [expensesRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final controller = container.read(historyControllerProvider.notifier);

      await controller.setSearch('market');
      await controller.setCategoryId(3);
      await controller.setSearch('   ');

      var filters = container.read(historyControllerProvider).filters;
      expect(filters.search, isNull);
      expect(filters.categoryId, 3);

      await controller.clearFilters();
      filters = container.read(historyControllerProvider).filters;
      expect(filters.hasActiveFilters, isFalse);
      expect(repository.seenFilters.last.hasActiveFilters, isFalse);
    },
  );

  test(
    'store, source and receipt filters keep the rest of the query',
    () async {
      final repository = FakeExpensesRepository();
      final container = ProviderContainer(
        overrides: [expensesRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final controller = container.read(historyControllerProvider.notifier);

      await controller.setSearch(' mercado ');
      await controller.setStore('  Éxito ');
      await controller.setCaptureSource(CaptureSource.ai);
      await controller.setReceiptKind(ReceiptKind.multi);

      final filters = container.read(historyControllerProvider).filters;
      expect(filters.store, 'Éxito');
      expect(filters.captureSource, CaptureSource.ai);
      expect(filters.receiptKind, ReceiptKind.multi);
      expect(filters.search, 'mercado');
      expect(filters.page, 1);

      // The request must carry them too: `load()` rebuilds the query through
      // `_firstPage`, which has to know about every filter field.
      final sent = repository.seenFilters.last;
      expect(sent.store, 'Éxito');
      expect(sent.captureSource, CaptureSource.ai);
      expect(sent.receiptKind, ReceiptKind.multi);
      expect(sent.search, 'mercado');

      // Blank store and explicit nulls clear only their own filter.
      await controller.setStore('   ');
      await controller.setReceiptKind(null);
      final cleared = container.read(historyControllerProvider).filters;
      expect(cleared.store, isNull);
      expect(cleared.receiptKind, isNull);
      expect(cleared.captureSource, CaptureSource.ai);
    },
  );

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
