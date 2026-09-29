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
}) {
  final container = ProviderContainer(
    overrides: [
      expensesRepositoryProvider.overrideWithValue(expenses),
      incomesRepositoryProvider.overrideWithValue(
        _FakeIncomesRepository(incomes),
      ),
      clockProvider.overrideWithValue(() => DateTime(2026, 9, 29, 12)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
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

    final sent = expenses.seenFilters.single;
    expect(sent.type, TransactionType.expense);
    expect(sent.startDate, DateTime.utc(2026, 9, 1));
    expect(sent.endDate, DateTime.utc(2026, 9, 30));
    expect(sent.pageSize, 100);
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
      expect(expenses.seenFilters.map((filters) => filters.page), [1, 2, 3]);
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
}
