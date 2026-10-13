import 'package:finance_ai/core/money/currency_totals.dart';
import 'package:finance_ai/core/time/clock_provider.dart';
import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/expenses/application/monthly_totals.dart';
import 'package:finance_ai/features/expenses/data/expenses_repository.dart';
import 'package:finance_ai/features/expenses/domain/expense_models.dart';
import 'package:finance_ai/features/expenses/domain/history_models.dart';
import 'package:finance_ai/features/incomes/data/incomes_repository.dart';
import 'package:finance_ai/features/incomes/domain/income_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _cop = CurrencySummary(
  id: 1,
  code: 'COP',
  name: 'Colombian Peso',
  decimals: 2,
);

HistoryItem expenseItem({
  required int id,
  required String amount,
  String occurredAt = '2026-09-17T12:30:00Z',
  String currencyCode = 'COP',
}) => HistoryItem(
  id: id,
  type: TransactionType.expense,
  status: ExpenseStatus.confirmed,
  occurredAt: DateTime.parse(occurredAt),
  description: 'Purchase at Market',
  captureSource: CaptureSource.manual,
  incomeSource: null,
  movements: [
    HistoryMovement(
      accountId: 11,
      accountName: 'Cash',
      amount: MoneyAmount.parseApi(amount),
      currency: _cop,
      currencyCode: currencyCode,
    ),
  ],
  expense: null,
);

Income income({
  required int id,
  required String amount,
  String date = '2026-09-18',
}) => Income(
  id: id,
  accountId: 11,
  accountName: 'Cash',
  currencyCode: 'COP',
  amount: MoneyAmount.parseApi(amount),
  date: DateTime.parse(date),
  description: 'Salary',
  incomeSourceId: null,
  incomeSourceName: null,
);

class _FakeExpensesRepository implements ExpensesRepository {
  _FakeExpensesRepository({this.pages = const {}});

  /// Page number -> items of that page.
  final Map<int, List<HistoryItem>> pages;
  final List<HistoryFilters> seenFilters = [];

  @override
  Future<HistoryResult> history(HistoryFilters filters) async {
    seenFilters.add(filters);
    final page = filters.page;
    return HistoryResult(
      items: pages[page] ?? const <HistoryItem>[],
      total: pages.values.fold(0, (sum, value) => sum + value.length),
      page: page,
      pageSize: filters.pageSize,
      hasNext: pages.containsKey(page + 1),
    );
  }

  @override
  Future<ExpenseListResult> list({int page = 1, int pageSize = 50}) async =>
      throw UnimplementedError();

  @override
  Future<Expense> get(int expenseId) async => throw UnimplementedError();

  @override
  Future<Expense> create(ExpenseCreateCommand command) async =>
      throw UnimplementedError();

  @override
  Future<Expense> update(int expenseId, ExpenseUpdateCommand command) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteExpense(int expenseId) async => throw UnimplementedError();
}

class _FakeIncomesRepository implements IncomesRepository {
  _FakeIncomesRepository(this.incomes);

  final List<Income> incomes;

  @override
  Future<List<Income>> list({int? accountId}) async => incomes;

  @override
  Future<Income> get(int incomeId) async => incomes.first;

  @override
  Future<Income> create(IncomeWriteCommand command) async =>
      throw UnimplementedError();

  @override
  Future<Income> update(int incomeId, IncomeWriteCommand command) async =>
      throw UnimplementedError();

  @override
  Future<void> delete(int incomeId) async => throw UnimplementedError();
}

ProviderContainer _container({
  required _FakeExpensesRepository expenses,
  List<Income> incomes = const [],
  DashboardPeriod period = DashboardPeriod.thisMonth,
}) {
  final container = ProviderContainer(
    overrides: [
      expensesRepositoryProvider.overrideWithValue(expenses),
      incomesRepositoryProvider.overrideWithValue(
        _FakeIncomesRepository(incomes),
      ),
      clockProvider.overrideWithValue(() => DateTime(2026, 9, 29, 12)),
      dashboardPeriodProvider.overrideWith(() => _FixedPeriod(period)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

class _FixedPeriod extends DashboardPeriodController {
  _FixedPeriod(this.fixed);

  final DashboardPeriod fixed;

  @override
  DashboardPeriod build() => fixed;
}

void main() {
  test(
    'reports incomplete history when capped, for both comparison windows',
    () async {
      final expenses = _FakeExpensesRepository(
        pages: {
          for (var page = 1; page <= 6; page++)
            page: [expenseItem(id: page, amount: '-1.00')],
        },
      );
      final container = _container(expenses: expenses, incomes: []);
      final totals = await container.read(monthlyTotalsProvider.future);
      expect(totals.historyComplete, isFalse);
      expect(totals.previousHistoryComplete, isFalse);
      expect(totals.expenseItems, hasLength(5));
      expect(expenses.seenFilters.map((f) => f.page), [
        1,
        2,
        3,
        4,
        5,
        1,
        2,
        3,
        4,
        5,
      ]);
    },
  );

  test('sums the month expenses per currency and asks for the month', () async {
    final expenses = _FakeExpensesRepository(
      pages: {
        1: [
          expenseItem(id: 1, amount: '-25.00'),
          expenseItem(id: 2, amount: '-100.50'),
        ],
      },
    );
    final totals = await _container(expenses: expenses)
        .read(monthlyTotalsProvider.future);

    expect(totals.byCurrency['COP']!.expenses, 12550);
    expect(totals.byCurrency['COP']!.incomes, 0);
    expect(totals.expenseItems, hasLength(2));
    expect(totals.monthStart, DateTime.utc(2026, 9, 1));

    // Current window + one previous-window first page.
    expect(expenses.seenFilters, hasLength(2));
    final sent = expenses.seenFilters.first;
    expect(sent.type, TransactionType.expense);
    expect(sent.startDate, DateTime.utc(2026, 9, 1));
    expect(sent.endDate, DateTime.utc(2026, 9, 30));
    expect(sent.pageSize, 100);
    final prev = expenses.seenFilters.last;
    expect(prev.startDate, DateTime.utc(2026, 8, 2));
    expect(prev.endDate, DateTime.utc(2026, 8, 31));
    expect(prev.page, 1);
  });

  test(
    'walks every page of a busy month instead of stopping at the first',
    () async {
      final expenses = _FakeExpensesRepository(
        pages: {
          1: [expenseItem(id: 1, amount: '-10.00')],
          2: [expenseItem(id: 2, amount: '-20.00')],
          3: [expenseItem(id: 3, amount: '-30.00')],
        },
      );
      final totals = await _container(expenses: expenses)
          .read(monthlyTotalsProvider.future);

      expect(totals.byCurrency['COP']!.expenses, 6000);
      expect(totals.expenseItems, hasLength(3));
      expect(expenses.seenFilters.map((filters) => filters.page), [
        1,
        2,
        3,
        1,
        2,
        3,
      ]);
    },
  );

  test('counts only the incomes of the reported month', () async {
    final totals = await _container(
      expenses: _FakeExpensesRepository(),
      incomes: [
        income(id: 1, amount: '500.00'),
        income(id: 2, amount: '120.00', date: '2026-09-01'),
        income(id: 3, amount: '999.00', date: '2026-08-31'),
        income(id: 4, amount: '999.00', date: '2025-09-15'),
      ],
    ).read(monthlyTotalsProvider.future);

    expect(totals.byCurrency['COP']!.incomes, 62000);
    expect(totals.byCurrency['COP']!.expenses, 0);
    expect(totals.expenseItems, isEmpty);
  });

  test(
    'keeps currencies apart and ignores positive expense movements',
    () async {
      final expenses = _FakeExpensesRepository(
        pages: {
          1: [
            expenseItem(id: 1, amount: '-25.00'),
            expenseItem(id: 2, amount: '-10.00', currencyCode: 'USD'),
            expenseItem(id: 3, amount: '5.00'),
          ],
        },
      );
      final totals = await _container(expenses: expenses)
          .read(monthlyTotalsProvider.future);

      expect(totals.byCurrency['COP']!.expenses, 2500);
      expect(totals.byCurrency['USD']!.expenses, 1000);
      expect(totals.forCurrency('EUR'), const CurrencyTotals());
      expect(totals.forCurrency(null), const CurrencyTotals());
    },
  );

  test('period windows resolve the expected date ranges', () {
    final now = DateTime(2026, 10, 3, 12);
    expect(periodWindow(DashboardPeriod.thisMonth, now), (
      start: DateTime.utc(2026, 10, 1),
      end: DateTime.utc(2026, 10, 31),
    ));
    expect(periodWindow(DashboardPeriod.lastMonth, now), (
      start: DateTime.utc(2026, 9, 1),
      end: DateTime.utc(2026, 9, 30),
    ));
    expect(periodWindow(DashboardPeriod.last3Months, now), (
      start: DateTime.utc(2026, 8, 1),
      end: DateTime.utc(2026, 10, 31),
    ));
    expect(periodWindow(DashboardPeriod.thisYear, now), (
      start: DateTime.utc(2026),
      end: DateTime.utc(2026, 12, 31),
    ));
    final custom = (
      start: DateTime.utc(2026, 9, 15),
      end: DateTime.utc(2026, 10, 5),
    );
    expect(
      periodWindow(DashboardPeriod.custom, now, customRange: custom),
      custom,
    );
    expect(periodLabel(DashboardPeriod.thisMonth, now), 'octubre');
    expect(periodLabel(DashboardPeriod.lastMonth, now), 'septiembre');
    expect(periodLabel(DashboardPeriod.last3Months, now), 'ago – oct');
    expect(periodLabel(DashboardPeriod.thisYear, now), '2026');
    expect(
      periodLabel(DashboardPeriod.custom, now, customRange: custom),
      '15 sep – 5 oct',
    );
  });

  test('last month preset asks for august only', () async {
    final expenses = _FakeExpensesRepository(
      pages: {
        1: [expenseItem(id: 1, amount: '-25.00')],
      },
    );
    final totals = await _container(
      expenses: expenses,
      period: DashboardPeriod.lastMonth,
      incomes: [income(id: 1, amount: '500.00', date: '2026-08-10')],
    ).read(periodTotalsProvider.future);

    expect(totals.period, DashboardPeriod.lastMonth);
    final sent = expenses.seenFilters.first;
    expect(sent.startDate, DateTime.utc(2026, 8, 1));
    expect(sent.endDate, DateTime.utc(2026, 8, 31));
    // The Sep-18 income fixture belongs to septiembre; agosto preset ignores it.
    final withSep = await _container(
      expenses: _FakeExpensesRepository(),
      period: DashboardPeriod.lastMonth,
      incomes: [income(id: 1, amount: '500.00')],
    ).read(periodTotalsProvider.future);
    expect(withSep.byCurrency['COP']?.incomes ?? 0, 0);
    expect(totals.byCurrency['COP']?.incomes ?? 0, 50000);
  });

  test('last 3 months preset spans jul-sep', () async {
    final expenses = _FakeExpensesRepository(
      pages: {
        1: [expenseItem(id: 1, amount: '-25.00')],
      },
    );
    await _container(
      expenses: expenses,
      period: DashboardPeriod.last3Months,
    ).read(periodTotalsProvider.future);

    final sent = expenses.seenFilters.first;
    expect(sent.startDate, DateTime.utc(2026, 7, 1));
    expect(sent.endDate, DateTime.utc(2026, 9, 30));
  });

  test('year preset filters incomes to the same year', () async {
    final totals = await _container(
      expenses: _FakeExpensesRepository(),
      period: DashboardPeriod.thisYear,
      incomes: [
        income(id: 1, amount: '500.00', date: '2026-09-18'),
        income(id: 2, amount: '999.00', date: '2025-09-15'),
      ],
    ).read(periodTotalsProvider.future);

    expect(totals.byCurrency['COP']!.incomes, 50000);
  });

  test('previous window covers the same length right before', () {
    expect(
      previousWindow((
        start: DateTime.utc(2026, 9, 1),
        end: DateTime.utc(2026, 9, 30),
      )),
      (start: DateTime.utc(2026, 8, 2), end: DateTime.utc(2026, 8, 31)),
    );
    expect(
      previousWindow((
        start: DateTime.utc(2026, 10, 1),
        end: DateTime.utc(2026, 10, 3),
      )),
      (start: DateTime.utc(2026, 9, 28), end: DateTime.utc(2026, 9, 30)),
    );
  });

  test('previous-window expenses land in previousExpensesByCurrency', () async {
    final expenses = _FakeExpensesRepository(
      pages: {
        1: [expenseItem(id: 1, amount: '-25.00')],
      },
    );
    final totals = await _container(expenses: expenses)
        .read(monthlyTotalsProvider.future);

    // Same fake serves both windows: previous sums the same first page.
    expect(totals.previousExpensesByCurrency['COP'], 2500);
  });
}
