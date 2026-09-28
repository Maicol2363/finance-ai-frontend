import 'package:finance_ai/app.dart';
import 'package:finance_ai/core/router/app_router.dart';
import 'package:finance_ai/features/accounts/data/accounts_repository.dart';
import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/accounts/presentation/account_form_screen.dart';
import 'package:finance_ai/features/accounts/presentation/accounts_screen.dart';
import 'package:finance_ai/features/categories/data/categories_repository.dart';
import 'package:finance_ai/features/categories/domain/category_models.dart';
import 'package:finance_ai/features/categories/presentation/categories_screen.dart';
import 'package:finance_ai/features/categories/presentation/category_form_screen.dart';
import 'package:finance_ai/features/expenses/data/expenses_repository.dart';
import 'package:finance_ai/features/expenses/domain/expense_models.dart';
import 'package:finance_ai/features/expenses/domain/history_models.dart';
import 'package:finance_ai/features/incomes/data/incomes_repository.dart';
import 'package:finance_ai/features/incomes/domain/income_models.dart';
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

Account optionAccount({int id = 11, String name = 'Cash'}) => Account(
  id: id,
  name: name,
  type: AccountType.cash,
  currency: cop,
  openingBalance: MoneyAmount.parseApi('100.00'),
  balance: MoneyAmount.parseApi('100.00'),
  currencyIsLocked: false,
  isActive: true,
  createdAt: DateTime.utc(2026, 9, 8),
  updatedAt: DateTime.utc(2026, 9, 8),
);

Category optionCategory({int id = 3, String name = 'Food'}) => Category(
  id: id,
  name: name,
  color: CategoryColor.blue,
  icon: CategoryIcon.food,
  sortOrder: 0,
  createdAt: DateTime.utc(2026, 9, 12),
  updatedAt: DateTime.utc(2026, 9, 12),
);

class WidgetOptionsAccountsRepository implements AccountsRepository {
  @override
  Future<AccountListResult> list({required bool includeInactive}) async =>
      AccountListResult(
        accounts: [
          optionAccount(),
          optionAccount(id: 12, name: 'Bank'),
        ],
        suggestedCurrencyCode: 'COP',
        supportedCurrencies: const [cop],
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

class WidgetOptionsCategoriesRepository implements CategoriesRepository {
  @override
  Future<CategoryListResult> list() async => CategoryListResult(
    categories: [
      optionCategory(),
      optionCategory(id: 4, name: 'Transport'),
    ],
    supportedColors: CategoryColor.values,
    supportedIcons: CategoryIcon.values,
  );

  @override
  Future<Category> get(int categoryId) async => optionCategory(id: categoryId);

  @override
  Future<Category> create(CategoryCreateCommand command) async =>
      throw UnimplementedError();

  @override
  Future<Category> update(
    int categoryId,
    CategoryUpdateCommand command,
  ) async => throw UnimplementedError();

  @override
  Future<CategoryListResult> reorder(List<int> categoryIds) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteCategory(int categoryId) async =>
      throw UnimplementedError();
}

HistoryItem historyItem({int id = 8, HistoryExpense? expense}) => HistoryItem(
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
  expense:
      expense ??
      HistoryExpense(
        receiptId: 9,
        name: 'Market',
        occurredAt: DateTime.utc(2026, 9, 17, 12, 30),
        purchasedAt: DateTime.utc(2026, 9, 17, 12, 30),
        totalAmount: MoneyAmount.parseApi('25.00'),
        note: 'Weekly food',
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

HistoryItem incomeHistoryItem({int id = 15}) => HistoryItem(
  id: id,
  type: TransactionType.income,
  status: ExpenseStatus.confirmed,
  occurredAt: DateTime.utc(2026, 9, 18, 10, 0),
  description: 'Salary payment',
  captureSource: CaptureSource.manual,
  incomeSource: 'Trabajo',
  movements: [
    HistoryMovement(
      accountId: 11,
      accountName: 'Cash',
      amount: MoneyAmount.parseApi('500.00'),
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

class FakeIncomesRepository implements IncomesRepository {
  FakeIncomesRepository([this._incomes = const []]);

  final List<Income> _incomes;
  IncomeWriteCommand? lastCreateCommand;

  @override
  Future<Income> create(IncomeWriteCommand command) async {
    lastCreateCommand = command;
    return Income(
      id: 99,
      accountId: command.accountId,
      amount: command.amount,
      date: command.date,
      description: command.description,
      incomeSourceId: command.incomeSourceId,
      incomeSourceName: 'Salario',
      accountName: 'Cash',
      currencyCode: 'COP',
    );
  }

  @override
  Future<void> delete(int incomeId) async {}

  @override
  Future<Income> get(int incomeId) async => Income(
    id: incomeId,
    accountId: 11,
    accountName: 'Cash',
    currencyCode: 'COP',
    amount: MoneyAmount.parseApi('500.00'),
    date: DateTime.utc(2026, 9, 18),
    description: 'Salary payment',
    incomeSourceId: 1,
    incomeSourceName: 'Trabajo',
  );

  @override
  Future<List<Income>> list({int? accountId}) async => _incomes;

  @override
  Future<Income> update(int incomeId, IncomeWriteCommand command) async =>
      throw UnimplementedError();
}

class _TwoCurrencyAccountsRepository implements AccountsRepository {
  Account _account({
    int id = 11,
    String name = 'Cash',
    String balance = '2310200.00',
    CurrencySummary currency = cop,
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

  @override
  Future<AccountListResult> list({required bool includeInactive}) async =>
      AccountListResult(
        accounts: [
          _account(),
          _account(
            id: 12,
            name: 'Dólares',
            balance: '1250.00',
            currency: const CurrencySummary(
              id: 2,
              code: 'USD',
              name: 'US Dollar',
              decimals: 2,
            ),
          ),
        ],
        suggestedCurrencyCode: 'COP',
        supportedCurrencies: const [cop],
        accountTypes: AccountType.values,
      );

  @override
  Future<Account> get(int accountId) async => _account(id: accountId);

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

Future<void> pumpExpensesApp(
  WidgetTester tester,
  WidgetExpensesRepository repository, {
  String initialLocation = '/expenses',
  AccountsRepository? accountsRepository,
  CategoriesRepository? categoriesRepository,
  IncomesRepository? incomesRepository,
}) async {
  final router = createAppRouter(initialLocation: initialLocation);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        expensesRepositoryProvider.overrideWithValue(repository),
        accountsRepositoryProvider.overrideWithValue(
          accountsRepository ?? FakeAccountsRepository(),
        ),
        categoriesRepositoryProvider.overrideWithValue(
          categoriesRepository ?? FakeCategoriesRepository(),
        ),
        incomesRepositoryProvider.overrideWithValue(
          incomesRepository ?? FakeIncomesRepository(),
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
    await tester.tap(find.byKey(const Key('expenses-wheel-manual')));
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
      accountsRepository: WidgetOptionsAccountsRepository(),
      categoriesRepository: WidgetOptionsCategoriesRepository(),
    );

    expect(find.byKey(const Key('expense-name-field')), findsOneWidget);
    expect(find.text('Cash · COP'), findsOneWidget);
    expect(find.text('Food'), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('expense-name-field')),
      'Updated groceries',
    );
    await tester.enterText(
      find.byKey(const Key('expense-amount-field')),
      '30.00',
    );
    await tester.tap(find.byKey(const Key('expense-account-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank · COP').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expense-category-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transport').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expense-save-button')));
    await tester.pumpAndSettle();

    expect(repository.lastCommand?.name, 'Updated groceries');
    expect(repository.lastCommand?.amount?.toApiString(), '30.00');
    expect(repository.lastCommand?.accountId, 12);
    expect(repository.lastCommand?.categoryId, 4);
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

  testWidgets(
    'history item tap navigates to expense detail and returns on back',
    (tester) async {
      final repository = WidgetExpensesRepository();
      await pumpExpensesApp(tester, repository, initialLocation: '/history');

      expect(find.byKey(const Key('history-card-8')), findsOneWidget);
      await tester.tap(find.byKey(const Key('history-card-8')));
      await tester.pumpAndSettle();

      expect(find.text('Detalle del gasto'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);

      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();

      expect(find.text('Historial'), findsOneWidget);
      expect(find.byKey(const Key('history-card-8')), findsOneWidget);
    },
  );

  testWidgets(
    'history item tap navigates to income detail and returns on back',
    (tester) async {
      final repository = WidgetExpensesRepository()
        ..historyItems = [incomeHistoryItem(id: 15)];
      await pumpExpensesApp(tester, repository, initialLocation: '/history');

      expect(find.byKey(const Key('history-card-15')), findsOneWidget);
      await tester.tap(find.byKey(const Key('history-card-15')));
      await tester.pumpAndSettle();

      expect(find.text('Detalle del ingreso'), findsOneWidget);

      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();

      expect(find.text('Historial'), findsOneWidget);
      expect(find.byKey(const Key('history-card-15')), findsOneWidget);
    },
  );

  testWidgets('segmented control switches to income and creates income', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = WidgetExpensesRepository();
    final incomesRepo = FakeIncomesRepository();
    await pumpExpensesApp(
      tester,
      repository,
      incomesRepository: incomesRepo,
      initialLocation: '/expenses/new',
    );

    expect(find.byKey(const Key('segment-gasto')), findsOneWidget);
    expect(find.byKey(const Key('segment-ingreso')), findsOneWidget);

    // Switch to income
    await tester.tap(find.byKey(const Key('segment-ingreso')));
    await tester.pumpAndSettle();

    expect(find.text('Registrar ingreso'), findsWidgets);
    expect(find.text('CUENTA DE DESTINO'), findsOneWidget);

    // Enter amount
    await tester.enterText(
      find.byKey(const Key('expense-create-amount-field')),
      '1500000.00',
    );
    await tester.pumpAndSettle();

    // Submit income
    await tester.tap(find.byKey(const Key('income-create-submit-button')));
    await tester.pumpAndSettle();

    expect(incomesRepo.lastCreateCommand?.amount.toApiString(), '1500000.00');
    expect(incomesRepo.lastCreateCommand?.accountId, 11);
  });

  testWidgets('empty accounts shows helper message and quick create button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = WidgetExpensesRepository();
    await pumpExpensesApp(
      tester,
      repository,
      accountsRepository: EmptyAccountsRepository(),
      initialLocation: '/expenses/new',
    );

    expect(find.text('No tienes cuentas registradas'), findsOneWidget);
    expect(
      find.byKey(const Key('expense-create-account-button')),
      findsOneWidget,
    );
  });

  testWidgets(
    'create form displays category quick-add button and account quick-add chip',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = WidgetExpensesRepository();
      await pumpExpensesApp(
        tester,
        repository,
        initialLocation: '/expenses/new',
      );

      expect(
        find.byKey(const Key('expense-create-new-account-chip')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('expense-create-optional-toggle')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('expense-create-new-category-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('expense-create-category-field')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'quick-add account from the capture form returns to the form it came from',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = WidgetExpensesRepository();
      await pumpExpensesApp(
        tester,
        repository,
        initialLocation: '/expenses/new',
      );

      await tester.enterText(
        find.byKey(const Key('expense-create-merchant-field')),
        'Panaderia La 80',
      );

      await tester.tap(
        find.byKey(const Key('expense-create-new-account-chip')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AccountFormScreen), findsOneWidget);
      expect(find.byKey(const Key('account-name-field')), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AccountFormScreen),
          matching: find.byIcon(Icons.arrow_back),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AccountFormScreen), findsNothing);
      expect(find.byType(AccountsScreen), findsNothing);
      expect(
        find.byKey(const Key('expense-create-merchant-field')),
        findsOneWidget,
      );
      expect(find.text('Panaderia La 80'), findsOneWidget);
    },
  );

  testWidgets(
    'quick-add category from the capture form returns to the form it came from',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = WidgetExpensesRepository();
      await pumpExpensesApp(
        tester,
        repository,
        initialLocation: '/expenses/new',
      );

      await tester.enterText(
        find.byKey(const Key('expense-create-merchant-field')),
        'Almuerzo',
      );
      await tester.tap(find.byKey(const Key('expense-create-optional-toggle')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('expense-create-new-category-chip')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CategoryFormScreen), findsOneWidget);
      expect(find.byKey(const Key('category-name-field')), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(CategoryFormScreen),
          matching: find.byIcon(Icons.arrow_back),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CategoryFormScreen), findsNothing);
      expect(find.byType(CategoriesScreen), findsNothing);
      expect(find.text('Almuerzo'), findsOneWidget);
    },
  );

  testWidgets(
    'saving a quick-add account returns to the capture form, not the account detail',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = WidgetExpensesRepository();
      await pumpExpensesApp(
        tester,
        repository,
        initialLocation: '/expenses/new',
      );

      await tester.enterText(
        find.byKey(const Key('expense-create-merchant-field')),
        'Cafe',
      );
      await tester.tap(
        find.byKey(const Key('expense-create-new-account-chip')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('account-name-field')),
        'Nequi',
      );
      await tester.tap(find.byKey(const Key('account-save-button')));
      await tester.pumpAndSettle();

      expect(find.byType(AccountFormScreen), findsNothing);
      expect(find.byType(AccountsScreen), findsNothing);
      expect(
        find.byKey(const Key('expense-create-merchant-field')),
        findsOneWidget,
      );
      expect(find.text('Cafe'), findsOneWidget);
    },
  );

  testWidgets(
    'expenses hub renders styled empty state card with action button when no expenses',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = WidgetExpensesRepository()..expenses = [];
      await pumpExpensesApp(tester, repository, initialLocation: '/expenses');

      expect(find.byKey(const Key('movements-empty-state')), findsOneWidget);
      expect(find.text('Aún no tienes movimientos'), findsOneWidget);
      expect(
        find.text('Registra tu primer gasto o ingreso y aparecerá aquí.'),
        findsOneWidget,
      );
      expect(find.textContaining('la IA prepara'), findsNothing);

      await tester.tap(
        find.byKey(const Key('movements-empty-register-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Registrar gasto'), findsWidgets);
      expect(
        find.byKey(const Key('expense-create-merchant-field')),
        findsOneWidget,
      );
    },
  );

  testWidgets('gastos hub reuses the shared movements empty state card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = WidgetExpensesRepository()..expenses = [];
    await pumpExpensesApp(tester, repository, initialLocation: '/home');

    expect(find.byKey(const Key('movements-empty-state')), findsOneWidget);
    expect(
      find.text('Registra tu primer gasto o ingreso y aparecerá aquí.'),
      findsOneWidget,
    );
    expect(find.textContaining('la IA prepara'), findsNothing);
  });

  testWidgets(
    'expenses hub calculates and displays balance, incomes, and account balances',
    (tester) async {
      final repository = WidgetExpensesRepository()..expenses = [];
      await pumpExpensesApp(tester, repository, initialLocation: '/home');

      expect(find.text(r'$ 100 COP'), findsOneWidget);
      expect(find.text(r'+ $ 0'), findsOneWidget);
      expect(find.text(r'- $ 0'), findsOneWidget);
      expect(
        find.text(r'1 cuenta activa · $ 100 COP · Ver saldos'),
        findsOneWidget,
      );
    },
  );

  testWidgets('hub groups balances by currency without mixing them', (
    tester,
  ) async {
    final repository = WidgetExpensesRepository()..expenses = [];
    await pumpExpensesApp(
      tester,
      repository,
      initialLocation: '/home',
      accountsRepository: _TwoCurrencyAccountsRepository(),
    );

    expect(find.text(r'$ 2.310.200 COP'), findsOneWidget);
    expect(find.text(r'$ 1.250 USD'), findsOneWidget);
    expect(
      find.text(
        r'2 cuentas activas · $ 2.310.200 COP · $ 1.250 USD · Ver saldos',
      ),
      findsOneWidget,
    );
    expect(find.text(r'+ $ 0'), findsOneWidget);
    expect(find.text(r'- $ 0'), findsOneWidget);
  });

  testWidgets(
    'home screen displays unified recent movements (expenses and incomes) and opens income detail',
    (tester) async {
      final repository = WidgetExpensesRepository();
      final testIncome = Income(
        id: 42,
        accountId: 11,
        accountName: 'Cash',
        currencyCode: 'COP',
        amount: MoneyAmount.parseApi('500.00'),
        date: DateTime.utc(2026, 9, 20),
        description: 'Pago de nómina',
        incomeSourceId: 1,
        incomeSourceName: 'Trabajo',
      );
      final incomesRepository = FakeIncomesRepository([testIncome]);

      await pumpExpensesApp(
        tester,
        repository,
        initialLocation: '/home',
        incomesRepository: incomesRepository,
      );

      expect(find.text('2 movimientos'), findsOneWidget);
      expect(find.byKey(const Key('expense-card-7')), findsOneWidget);
      expect(find.byKey(const Key('income-card-42')), findsOneWidget);
      expect(find.text('Pago de nómina'), findsOneWidget);
      expect(find.text('+ COP 500.00'), findsOneWidget);

      await tester.tap(find.byKey(const Key('income-card-42')));
      await tester.pumpAndSettle();

      expect(find.text('Detalle del ingreso'), findsOneWidget);
    },
  );

  testWidgets(
    'home screen caps recent movements at top 10 and has no load more button',
    (tester) async {
      final repository = WidgetExpensesRepository();
      final incomes = List.generate(
        15,
        (i) => Income(
          id: 100 + i,
          accountId: 11,
          accountName: 'Cash',
          currencyCode: 'COP',
          amount: MoneyAmount.parseApi('10.00'),
          date: DateTime.utc(2026, 9, 1 + i),
          description: 'Income $i',
          incomeSourceId: 1,
          incomeSourceName: 'Trabajo',
        ),
      );
      final incomesRepository = FakeIncomesRepository(incomes);

      await pumpExpensesApp(
        tester,
        repository,
        initialLocation: '/home',
        incomesRepository: incomesRepository,
      );

      expect(find.text('10 movimientos'), findsOneWidget);
      expect(find.byKey(const Key('expenses-load-more-button')), findsNothing);
    },
  );
}

class EmptyAccountsRepository extends FakeAccountsRepository {
  @override
  Future<AccountListResult> list({bool includeInactive = false}) async {
    return const AccountListResult(
      accounts: [],
      suggestedCurrencyCode: 'COP',
      supportedCurrencies: [cop],
      accountTypes: [AccountType.cash],
    );
  }
}
