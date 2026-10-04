import 'package:finance_ai/app.dart';
import 'package:finance_ai/core/router/app_router.dart';
import 'package:finance_ai/core/time/clock_provider.dart';
import 'package:finance_ai/features/accounts/data/accounts_repository.dart';
import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/budgets/data/budgets_repository.dart';
import 'package:finance_ai/features/budgets/domain/budget_models.dart';
import 'package:finance_ai/features/categories/data/categories_repository.dart';
import 'package:finance_ai/features/categories/domain/category_models.dart';
import 'package:finance_ai/features/expenses/data/expenses_repository.dart';
import 'package:finance_ai/features/expenses/domain/expense_models.dart';
import 'package:finance_ai/features/expenses/domain/history_models.dart';
import 'package:finance_ai/features/income_sources/data/income_sources_repository.dart';
import 'package:finance_ai/features/income_sources/domain/income_source_models.dart';
import 'package:finance_ai/features/incomes/data/incomes_repository.dart';
import 'package:finance_ai/features/incomes/domain/income_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _cop = CurrencySummary(
  id: 1,
  code: 'COP',
  name: 'Colombian Peso',
  decimals: 2,
);

final _testAccount = Account(
  id: 11,
  name: 'Cash',
  type: AccountType.cash,
  currency: _cop,
  balance: MoneyAmount.parseApi('100.00'),
  openingBalance: MoneyAmount.parseApi('100.00'),
  currencyIsLocked: false,
  isActive: true,
  createdAt: DateTime.utc(2026, 9, 1, 10, 0),
  updatedAt: DateTime.utc(2026, 9, 1, 10, 0),
);

final _testCategory = Category(
  id: 3,
  name: 'Food',
  color: CategoryColor.red,
  icon: CategoryIcon.food,
  sortOrder: 1,
  createdAt: DateTime.utc(2026, 9, 1, 10, 0),
  updatedAt: DateTime.utc(2026, 9, 1, 10, 0),
);

Expense _expense() => Expense(
  id: 7,
  transactionId: 8,
  receiptId: 9,
  name: 'Groceries',
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
  currency: _cop,
  currencyCode: 'COP',
  createdAt: DateTime.utc(2026, 9, 17, 12, 30),
  updatedAt: DateTime.utc(2026, 9, 17, 12, 30),
  receiptImage: 'receipt.jpg',
  imagePath: 'expense.jpg',
);

Income _income() => Income(
  id: 21,
  accountId: 11,
  accountName: 'Cash',
  currencyCode: 'COP',
  amount: MoneyAmount.parseApi('500.00'),
  date: DateTime.utc(2026, 9, 18),
  description: 'Salary payment',
  incomeSourceId: 1,
  incomeSourceName: 'Trabajo',
);

class _FakeExpensesRepository implements ExpensesRepository {
  _FakeExpensesRepository({List<Expense>? expenses})
    : expenses = expenses ?? [_expense()];

  List<Expense> expenses;

  @override
  Future<ExpenseListResult> list({int page = 1, int pageSize = 50}) async =>
      ExpenseListResult(
        items: expenses,
        total: expenses.length,
        page: 1,
        pageSize: 50,
        hasNext: false,
      );

  @override
  Future<Expense> get(int expenseId) async => expenses.first;

  @override
  Future<Expense> create(ExpenseCreateCommand command) async => expenses.first;

  @override
  Future<Expense> update(int expenseId, ExpenseUpdateCommand command) async =>
      expenses.first;

  @override
  Future<void> deleteExpense(int expenseId) async {}

  @override
  Future<HistoryResult> history(HistoryFilters filters) async => HistoryResult(
    items: expenses.isEmpty ? const [] : [_historyItem()],
    total: expenses.isEmpty ? 0 : 1,
    page: 1,
    pageSize: 50,
    hasNext: false,
  );
}

/// The month's expense entry as the history endpoint reports it: the Dashboard
/// breakdown is built from this, not from the first page of `/expenses`.
HistoryItem _historyItem() => HistoryItem(
  id: 8,
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
      currency: _cop,
      currencyCode: 'COP',
    ),
  ],
  expense: HistoryExpense(
    receiptId: 9,
    name: 'Market',
    occurredAt: DateTime.utc(2026, 9, 17, 12, 30),
    purchasedAt: DateTime.utc(2026, 9, 17, 12, 30),
    totalAmount: MoneyAmount.parseApi('25.00'),
    note: null,
    store: 'Market',
    storeName: 'Market',
    items: [
      HistoryExpenseItem(
        id: 7,
        name: 'Groceries',
        amount: MoneyAmount.parseApi('25.00'),
        quantity: '1.000',
        unitPrice: MoneyAmount.parseApi('25.00'),
        note: null,
        category: ExpenseCategory(id: 3, name: 'Food'),
        imagePath: null,
      ),
    ],
    receiptImage: null,
  ),
);

class _FakeAccountsRepository implements AccountsRepository {
  @override
  Future<AccountListResult> list({bool includeInactive = false}) async =>
      AccountListResult(
        accounts: [_testAccount],
        suggestedCurrencyCode: 'COP',
        supportedCurrencies: const [_cop],
        accountTypes: const [AccountType.cash],
      );

  @override
  Future<Account> get(int accountId) async => _testAccount;

  @override
  Future<Account> create(AccountCreateCommand command) async => _testAccount;

  @override
  Future<Account> update(int accountId, AccountUpdateCommand command) async =>
      _testAccount;

  @override
  Future<Account> setActive(int accountId, {required bool isActive}) async =>
      _testAccount;

  @override
  Future<void> deleteAccount(int accountId) async {}
}

class _FakeCategoriesRepository implements CategoriesRepository {
  @override
  Future<CategoryListResult> list() async => CategoryListResult(
    categories: [_testCategory],
    supportedColors: const [CategoryColor.red],
    supportedIcons: const [CategoryIcon.food],
  );

  @override
  Future<Category> get(int categoryId) async => _testCategory;

  @override
  Future<Category> create(CategoryCreateCommand command) async => _testCategory;

  @override
  Future<Category> update(
    int categoryId,
    CategoryUpdateCommand command,
  ) async => _testCategory;

  @override
  Future<CategoryListResult> reorder(List<int> categoryIds) async =>
      CategoryListResult(
        categories: [_testCategory],
        supportedColors: const [CategoryColor.red],
        supportedIcons: const [CategoryIcon.food],
      );

  @override
  Future<void> deleteCategory(int categoryId) async {}
}

class _FakeBudgetsRepository implements BudgetsRepository {
  @override
  Future<BudgetListResult> list() async => const BudgetListResult(
    budgets: [],
    categories: [],
    supportedCurrencies: [_cop],
    suggestedCurrencyCode: 'COP',
  );

  @override
  Future<Budget> create(BudgetCreateCommand command) =>
      throw UnimplementedError();

  @override
  Future<Budget> update(int budgetId, BudgetUpdateCommand command) =>
      throw UnimplementedError();

  @override
  Future<void> deleteBudget(int budgetId) => throw UnimplementedError();
}

class _FakeIncomesRepository implements IncomesRepository {
  _FakeIncomesRepository({List<Income>? incomes})
    : incomes = incomes ?? [_income()];

  final List<Income> incomes;

  @override
  Future<List<Income>> list({int? accountId}) async => incomes;

  @override
  Future<Income> get(int incomeId) async => incomes.first;

  @override
  Future<Income> create(IncomeWriteCommand command) async => incomes.first;

  @override
  Future<Income> update(int incomeId, IncomeWriteCommand command) async =>
      incomes.first;

  @override
  Future<void> delete(int incomeId) async {}
}

class _FakeIncomeSourcesRepository implements IncomeSourcesRepository {
  @override
  Future<List<IncomeSource>> list({required String accessCredential}) async =>
      const [IncomeSource(id: 1, name: 'Trabajo')];

  @override
  Future<IncomeSource> create({
    required String accessCredential,
    required String name,
  }) async => const IncomeSource(id: 1, name: 'Trabajo');

  @override
  Future<IncomeSource> rename({
    required String accessCredential,
    required int id,
    required String name,
  }) async => IncomeSource(id: id, name: name);

  @override
  Future<void> delete({
    required String accessCredential,
    required int id,
  }) async {}
}

Future<void> _pumpAt(
  WidgetTester tester,
  String location, {
  List<Expense>? expenses,
  List<Income>? incomes,
}) async {
  final router = createAppRouter(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        expensesRepositoryProvider.overrideWithValue(
          _FakeExpensesRepository(expenses: expenses),
        ),
        accountsRepositoryProvider.overrideWithValue(_FakeAccountsRepository()),
        categoriesRepositoryProvider.overrideWithValue(
          _FakeCategoriesRepository(),
        ),
        budgetsRepositoryProvider.overrideWithValue(_FakeBudgetsRepository()),
        incomesRepositoryProvider.overrideWithValue(
          _FakeIncomesRepository(incomes: incomes),
        ),
        incomeSourcesRepositoryProvider.overrideWithValue(
          _FakeIncomeSourcesRepository(),
        ),
        // Month-scoped cards read "now" from here.
        clockProvider.overrideWithValue(() => DateTime(2026, 9, 29, 12)),
      ],
      child: FinanceApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dashboard renders balance summary with data', (tester) async {
    await _pumpAt(tester, '/dashboard');

    // Same definition as the Gastos hub: stock (live account balances), so the
    // two tabs can never disagree. Chips below are the current month's flow.
    expect(find.text('Saldo en cuentas'), findsOneWidget);
    expect(find.text(r'$ 100 COP'), findsOneWidget);
    expect(find.text('Movimientos de septiembre'), findsOneWidget);
    expect(find.text(r'+$ 500'), findsOneWidget);
    expect(find.text(r'-$ 25'), findsWidgets);
    expect(find.text('Este mes'), findsOneWidget);
    expect(find.text('Mes anterior'), findsOneWidget);
    expect(find.text('Últimos 3 meses'), findsOneWidget);
    expect(find.text('Este año'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Gastos por categoría'), 200);
    expect(find.text('Gastos por categoría'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Market'), 200);
    expect(find.text('Market'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
  });

  testWidgets('dashboard period chip switches the window label', (tester) async {
    await _pumpAt(tester, '/dashboard');

    expect(find.text('Movimientos de septiembre'), findsOneWidget);
    await tester.tap(find.text('Este año'));
    await tester.pumpAndSettle();
    expect(find.text('Movimientos de 2026'), findsOneWidget);
  });

  testWidgets('dashboard renders empty state without expenses', (tester) async {
    await _pumpAt(tester, '/dashboard', expenses: const [], incomes: const []);

    expect(find.text('Saldo en cuentas'), findsOneWidget);
    expect(find.text(r'+$ 0'), findsOneWidget);
    expect(find.text(r'-$ 0'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sin datos suficientes'), 200);
    expect(find.text('Sin datos suficientes'), findsOneWidget);
  });

  testWidgets('settings renders groups, rows and logout', (tester) async {
    await _pumpAt(tester, '/settings');

    expect(find.text('Ajustes'), findsWidgets);
    expect(find.byKey(const Key('settings-accounts-row')), findsOneWidget);
    expect(find.byKey(const Key('settings-incomes-row')), findsNothing);
    expect(find.byKey(const Key('settings-history-row')), findsNothing);
    expect(find.byKey(const Key('settings-categories-row')), findsOneWidget);
    expect(
      find.byKey(const Key('settings-income-sources-row')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('logout-button')),
      200,
    );
    expect(find.byKey(const Key('logout-button')), findsOneWidget);
  });
}
