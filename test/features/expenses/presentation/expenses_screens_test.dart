import 'package:finance_ai/app.dart';
import 'package:finance_ai/core/router/app_router.dart';
import 'package:finance_ai/features/accounts/data/accounts_repository.dart';
import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/categories/data/categories_repository.dart';
import 'package:finance_ai/features/categories/domain/category_models.dart';
import 'package:finance_ai/features/expenses/data/expenses_repository.dart';
import 'package:finance_ai/features/expenses/domain/expense_models.dart';
import 'package:finance_ai/features/expenses/domain/history_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const cop = CurrencySummary(
  id: 1,
  code: 'COP',
  name: 'Colombian Peso',
  decimals: 2,
);

final testAccount = Account(
  id: 11,
  name: 'Cash',
  type: AccountType.cash,
  currency: cop,
  balance: MoneyAmount.parseApi('100.00'),
  openingBalance: MoneyAmount.parseApi('100.00'),
  currencyIsLocked: false,
  isActive: true,
  createdAt: DateTime.utc(2026, 9, 1, 10, 0),
  updatedAt: DateTime.utc(2026, 9, 1, 10, 0),
);

final testCategory = Category(
  id: 3,
  name: 'Food',
  color: CategoryColor.red,
  icon: CategoryIcon.food,
  sortOrder: 1,
  createdAt: DateTime.utc(2026, 9, 1, 10, 0),
  updatedAt: DateTime.utc(2026, 9, 1, 10, 0),
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

ExpenseListResult listResult(List<Expense> items) => ExpenseListResult(
  items: items,
  total: items.length,
  page: 1,
  pageSize: 50,
  hasNext: false,
);

HistoryItem historyItem({int id = 8}) => HistoryItem(
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
      currency: cop,
      currencyCode: 'COP',
    ),
  ],
  expense: null,
);

class WidgetExpensesRepository implements ExpensesRepository {
  WidgetExpensesRepository()
    : expenses = [expense()],
      historyItems = [historyItem()];

  List<Expense> expenses;
  List<HistoryItem> historyItems;
  ExpenseUpdateCommand? lastCommand;
  ExpenseCreateCommand? lastCreateCommand;
  final List<HistoryFilters> seenHistoryFilters = [];

  @override
  Future<ExpenseListResult> list({int page = 1, int pageSize = 50}) async =>
      listResult(expenses);

  @override
  Future<Expense> get(int expenseId) async => expenses.firstWhere(
    (item) => item.id == expenseId,
    orElse: () => throw const ExpenseFailure(
      code: 'expense_not_found',
      userMessage: 'This expense is no longer available.',
    ),
  );

  @override
  Future<Expense> create(ExpenseCreateCommand command) async {
    lastCreateCommand = command;
    final created = expense(id: 99, name: command.merchant);
    expenses = [created, ...expenses];
    return created;
  }

  @override
  Future<Expense> update(int expenseId, ExpenseUpdateCommand command) async {
    lastCommand = command;
    final index = expenses.indexWhere((item) => item.id == expenseId);
    final updated = expense(
      id: expenseId,
      name: command.name ?? expenses[index].name,
    );
    expenses = [
      for (final item in expenses)
        if (item.id == expenseId) updated else item,
    ];
    return updated;
  }

  @override
  Future<void> deleteExpense(int expenseId) async {
    expenses = expenses.where((item) => item.id != expenseId).toList();
  }

  @override
  Future<HistoryResult> history(HistoryFilters filters) async {
    seenHistoryFilters.add(filters);
    final items = filters.type == TransactionType.income
        ? const <HistoryItem>[]
        : historyItems;
    return HistoryResult(
      items: items,
      total: items.length,
      page: 1,
      pageSize: 50,
      hasNext: false,
    );
  }
}

class FakeAccountsRepository implements AccountsRepository {
  @override
  Future<AccountListResult> list({bool includeInactive = false}) async {
    return AccountListResult(
      accounts: [testAccount],
      suggestedCurrencyCode: 'COP',
      supportedCurrencies: const [cop],
      accountTypes: const [AccountType.cash],
    );
  }

  @override
  Future<Account> get(int accountId) async => testAccount;

  @override
  Future<Account> create(AccountCreateCommand command) async => testAccount;

  @override
  Future<Account> update(int accountId, AccountUpdateCommand command) async =>
      testAccount;

  @override
  Future<Account> setActive(int accountId, {required bool isActive}) async =>
      testAccount;

  @override
  Future<void> deleteAccount(int accountId) async {}
}

class FakeCategoriesRepository implements CategoriesRepository {
  @override
  Future<CategoryListResult> list() async {
    return CategoryListResult(
      categories: [testCategory],
      supportedColors: const [CategoryColor.red],
      supportedIcons: const [CategoryIcon.food],
    );
  }

  @override
  Future<Category> get(int categoryId) async => testCategory;

  @override
  Future<Category> create(CategoryCreateCommand command) async => testCategory;

  @override
  Future<Category> update(
    int categoryId,
    CategoryUpdateCommand command,
  ) async => testCategory;

  @override
  Future<CategoryListResult> reorder(List<int> categoryIds) async =>
      CategoryListResult(
        categories: [testCategory],
        supportedColors: const [CategoryColor.red],
        supportedIcons: const [CategoryIcon.food],
      );

  @override
  Future<void> deleteCategory(int categoryId) async {}
}

Future<void> pumpExpensesApp(
  WidgetTester tester,
  WidgetExpensesRepository repository, {
  String initialLocation = '/expenses',
}) async {
  final router = createAppRouter(initialLocation: initialLocation);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        expensesRepositoryProvider.overrideWithValue(repository),
        accountsRepositoryProvider.overrideWithValue(FakeAccountsRepository()),
        categoriesRepositoryProvider.overrideWithValue(
          FakeCategoriesRepository(),
        ),
      ],
      child: FinanceApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('list shows expenses and opens the detail screen', (
    tester,
  ) async {
    final repository = WidgetExpensesRepository();
    await pumpExpensesApp(tester, repository);

    expect(find.byKey(const Key('expenses-list')), findsOneWidget);
    expect(find.text('COP 25.00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('expense-card-7')));
    await tester.pumpAndSettle();

    expect(find.text('Detalle del gasto'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('expense-edit-button')),
      200,
    );
    expect(find.byKey(const Key('expense-edit-button')), findsOneWidget);
  });

  testWidgets('FAB navigates to create expense form and creates expense', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = WidgetExpensesRepository();
    await pumpExpensesApp(tester, repository);

    expect(find.byKey(const Key('expenses-create-fab')), findsOneWidget);
    await tester.tap(find.byKey(const Key('expenses-create-fab')));
    await tester.pumpAndSettle();

    expect(find.text('Registrar gasto'), findsWidgets);
    expect(
      find.byKey(const Key('expense-create-merchant-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('expense-create-amount-field')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('expense-create-merchant-field')),
      'Supermarket Exito',
    );
    await tester.enterText(
      find.byKey(const Key('expense-create-amount-field')),
      '55.50',
    );
    await tester.tap(find.byKey(const Key('expense-create-optional-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('expense-create-note-field')),
      'Weekly grocery shopping',
    );

    await tester.tap(find.byKey(const Key('expense-create-submit-button')));
    await tester.pumpAndSettle();

    expect(repository.lastCreateCommand?.merchant, 'Supermarket Exito');
    expect(repository.lastCreateCommand?.amount.toApiString(), '55.50');
    expect(repository.lastCreateCommand?.accountId, 11);
    expect(repository.lastCreateCommand?.note, 'Weekly grocery shopping');
    expect(find.byKey(const Key('expenses-list')), findsOneWidget);
  });

  testWidgets('delete asks for confirmation and returns to the list', (
    tester,
  ) async {
    final repository = WidgetExpensesRepository();
    await pumpExpensesApp(tester, repository, initialLocation: '/expenses/7');

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expense-delete-button')));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar este gasto definitivamente?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('expense-confirm-delete-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('expenses-list')), findsOneWidget);
    expect(repository.expenses, isEmpty);
  });

  testWidgets('edit form prefills values and submits the wire command', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final repository = WidgetExpensesRepository();
    await pumpExpensesApp(
      tester,
      repository,
      initialLocation: '/expenses/7/edit',
    );

    expect(find.byKey(const Key('expense-name-field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('expense-name-field')),
      'Updated groceries',
    );
    await tester.enterText(
      find.byKey(const Key('expense-amount-field')),
      '30.00',
    );
    await tester.tap(find.byKey(const Key('expense-save-button')));
    await tester.pumpAndSettle();

    expect(repository.lastCommand?.name, 'Updated groceries');
    expect(repository.lastCommand?.amount?.toApiString(), '30.00');
    expect(find.text('Detalle del gasto'), findsOneWidget);
  });

  testWidgets('history renders entries and applies the search filter', (
    tester,
  ) async {
    final repository = WidgetExpensesRepository();
    await pumpExpensesApp(tester, repository, initialLocation: '/history');

    expect(find.byKey(const Key('history-list')), findsOneWidget);
    expect(find.byKey(const Key('history-card-8')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('history-search-field')),
      'market',
    );
    await tester.tap(find.byKey(const Key('history-apply-button')));
    await tester.pumpAndSettle();

    expect(repository.seenHistoryFilters.length, greaterThanOrEqualTo(2));
    expect(repository.seenHistoryFilters.last.search, 'market');
  });

  testWidgets('history shows an empty state when filters match nothing', (
    tester,
  ) async {
    final repository = WidgetExpensesRepository()..historyItems = [];
    await pumpExpensesApp(tester, repository, initialLocation: '/history');

    expect(find.text('Sin resultados para estos filtros'), findsOneWidget);
  });
}
