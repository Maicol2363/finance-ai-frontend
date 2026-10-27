import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:finance_ai/app.dart';
import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:finance_ai/core/router/app_router.dart';
import 'package:finance_ai/core/time/clock_provider.dart';
import 'package:finance_ai/core/widgets/app_header.dart';
import 'package:finance_ai/features/accounts/data/accounts_repository.dart';
import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/accounts/presentation/account_form_screen.dart';
import 'package:finance_ai/features/accounts/presentation/accounts_screen.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_controller.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_state.dart';
import 'package:finance_ai/features/auth/session/domain/session_models.dart';
import 'package:finance_ai/features/budgets/application/budgets_controller.dart';
import 'package:finance_ai/features/budgets/application/budgets_state.dart';
import 'package:finance_ai/features/categories/data/categories_repository.dart';
import 'package:finance_ai/features/categories/domain/category_models.dart';
import 'package:finance_ai/features/categories/presentation/categories_screen.dart';
import 'package:finance_ai/features/categories/presentation/category_form_screen.dart';
import 'package:finance_ai/features/expenses/data/expenses_repository.dart';
import 'package:finance_ai/features/expenses/domain/expense_models.dart';
import 'package:finance_ai/features/expenses/domain/history_models.dart';
import 'package:finance_ai/features/income_sources/data/income_sources_repository.dart';
import 'package:finance_ai/features/income_sources/domain/income_source_models.dart';
import 'package:finance_ai/features/incomes/data/incomes_repository.dart';
import 'package:finance_ai/features/incomes/domain/income_models.dart';
import 'package:finance_ai/features/receipt_capture/data/receipt_photo_cache_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const cop = CurrencySummary(
  id: 1,
  code: 'COP',
  name: 'Colombian Peso',
  decimals: 2,
);
const usd = CurrencySummary(id: 2, code: 'USD', name: 'US Dollar', decimals: 2);

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

Expense expense({
  int id = 7,
  String name = 'Groceries',
  CaptureSource captureSource = CaptureSource.manual,
  ExpenseStatus status = ExpenseStatus.confirmed,
  List<ExpenseItem> items = const [],
}) => Expense(
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
  status: status,
  captureSource: captureSource,
  accountId: 11,
  accountName: 'Cash',
  accountIsActive: true,
  currency: cop,
  currencyCode: 'COP',
  createdAt: DateTime.utc(2026, 9, 17, 12, 30),
  updatedAt: DateTime.utc(2026, 9, 17, 12, 30),
  receiptImage: 'receipt.jpg',
  imagePath: 'expense.jpg',
  items: items,
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

class FailingWidgetOptionsAccountsRepository
    extends WidgetOptionsAccountsRepository {
  @override
  Future<AccountListResult> list({required bool includeInactive}) async =>
      throw StateError('private-account-response');
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

class FailingWidgetOptionsCategoriesRepository
    extends WidgetOptionsCategoriesRepository {
  @override
  Future<CategoryListResult> list() async =>
      throw StateError('private-category-response');
}

class NeedsWidgetOptionsCategoriesRepository
    extends WidgetOptionsCategoriesRepository {
  @override
  Future<CategoryListResult> list() async => CategoryListResult(
    categories: [optionCategory(name: 'needs')],
    supportedColors: CategoryColor.values,
    supportedIcons: CategoryIcon.values,
  );
}

class _AuthenticatedWidgetSessionController extends AuthSessionController {
  @override
  AuthSessionState build() => const AuthSessionState(
    status: AuthSessionStatus.authenticated,
    user: AuthenticatedUser(
      id: 42,
      email: 'person@example.com',
      preferredCurrency: 'COP',
    ),
    accessCredential: 'test-access-credential',
  );
}

class _WidgetIncomeSourcesRepository implements IncomeSourcesRepository {
  @override
  Future<List<IncomeSource>> list({required String accessCredential}) async =>
      const [];

  @override
  Future<IncomeSource> create({
    required String accessCredential,
    required String name,
  }) => throw UnimplementedError();

  @override
  Future<IncomeSource> rename({
    required String accessCredential,
    required int id,
    required String name,
  }) => throw UnimplementedError();

  @override
  Future<void> delete({required String accessCredential, required int id}) =>
      throw UnimplementedError();
}

class FailingWidgetIncomeSourcesRepository
    extends _WidgetIncomeSourcesRepository {
  bool fail = true;

  @override
  Future<List<IncomeSource>> list({required String accessCredential}) async {
    if (fail) throw StateError('private-income-source-response');
    return const [IncomeSource(id: 21, name: 'Salario')];
  }
}

HistoryItem historyItem({
  int id = 8,
  int accountId = 11,
  HistoryExpense? expense,
}) => HistoryItem(
  id: id,
  type: TransactionType.expense,
  status: ExpenseStatus.confirmed,
  occurredAt: DateTime.utc(2026, 9, 17, 12, 30),
  description: 'Purchase at Market',
  captureSource: CaptureSource.manual,
  incomeSource: null,
  movements: [
    HistoryMovement(
      accountId: accountId,
      accountName: accountId == 11 ? 'Cash' : 'Bank',
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

HistoryItem transferHistoryItem({int id = 44, bool crossCurrency = false}) =>
    HistoryItem(
      id: id,
      type: TransactionType.transfer,
      status: ExpenseStatus.confirmed,
      occurredAt: DateTime.utc(2026, 9, 17),
      description: 'Ahorro',
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
        HistoryMovement(
          accountId: 12,
          accountName: 'Bank',
          amount: MoneyAmount.parseApi('25.00'),
          currency: crossCurrency ? usd : cop,
          currencyCode: crossCurrency ? 'USD' : 'COP',
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
    historyItems = [historyItem(id: 99), ...historyItems];
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

class _WidgetBudgetsController extends BudgetsController {
  _WidgetBudgetsController(this.onLoad);

  final void Function()? onLoad;

  @override
  BudgetsState build() => const BudgetsState();

  @override
  Future<void> load() async => onLoad?.call();
}

class _DelayedAccountsRepository extends FakeAccountsRepository {
  final result = Completer<AccountListResult>();

  @override
  Future<AccountListResult> list({bool includeInactive = false}) =>
      result.future;
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
  void Function(Income income)? onCreated;

  @override
  Future<Income> create(IncomeWriteCommand command) async {
    lastCreateCommand = command;
    final income = Income(
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
    onCreated?.call(income);
    return income;
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

/// Fake for the receipt photo store: records deletions and reports the photo it
/// is holding so a delete can be observed without touching the file system.
class _FakeReceiptPhotoCacheRepository implements ReceiptPhotoCacheRepository {
  final List<int> deleted = [];
  final List<int> deletedOwners = [];
  Uint8List? photo;

  @override
  Future<void> quarantineLegacyPhotos() async {}

  @override
  Future<String> saveReceiptPhoto({
    required int userId,
    required int expenseId,
    required String sourceFilePath,
  }) async => sourceFilePath;

  @override
  Future<Uint8List?> getCachedReceiptPhoto({
    required int userId,
    required int expenseId,
  }) async => photo;

  @override
  Future<void> deleteCachedReceiptPhoto({
    required int userId,
    required int expenseId,
  }) async {
    deleted.add(expenseId);
    deletedOwners.add(userId);
    photo = null;
  }
}

Future<void> pumpExpensesApp(
  WidgetTester tester,
  WidgetExpensesRepository repository, {
  String initialLocation = '/expenses',
  AccountsRepository? accountsRepository,
  CategoriesRepository? categoriesRepository,
  IncomeSourcesRepository? incomeSourcesRepository,
  IncomesRepository? incomesRepository,
  ReceiptPhotoCacheRepository? receiptPhotoCacheRepository,
  DateTime Function()? clock,
  void Function()? onBudgetsLoad,
  bool authenticatedSession = true,
  bool settle = true,
}) async {
  final router = createAppRouter(initialLocation: initialLocation);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (authenticatedSession)
          authSessionControllerProvider.overrideWith(
            _AuthenticatedWidgetSessionController.new,
          ),
        if (authenticatedSession)
          incomeSourcesRepositoryProvider.overrideWithValue(
            incomeSourcesRepository ?? _WidgetIncomeSourcesRepository(),
          ),
        expensesRepositoryProvider.overrideWithValue(repository),
        budgetsControllerProvider.overrideWith(
          () => _WidgetBudgetsController(onBudgetsLoad),
        ),
        // The month-scoped cards read "now" from here: pinned so the tests do
        // not depend on the machine date.
        clockProvider.overrideWithValue(
          clock ?? () => DateTime(2026, 9, 29, 12),
        ),
        accountsRepositoryProvider.overrideWithValue(
          accountsRepository ?? FakeAccountsRepository(),
        ),
        categoriesRepositoryProvider.overrideWithValue(
          categoriesRepository ?? FakeCategoriesRepository(),
        ),
        incomesRepositoryProvider.overrideWithValue(
          incomesRepository ?? FakeIncomesRepository(),
        ),
        receiptPhotoCacheRepositoryProvider.overrideWithValue(
          receiptPhotoCacheRepository ?? _FakeReceiptPhotoCacheRepository(),
        ),
      ],
      child: FinanceApp(router: router),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

void main() {
  testWidgets('manual amount opens keyboard after delayed options enable it', (
    tester,
  ) async {
    final accounts = _DelayedAccountsRepository();
    await pumpExpensesApp(
      tester,
      WidgetExpensesRepository(),
      initialLocation: '/expenses/new',
      accountsRepository: accounts,
      settle: false,
    );
    await tester.pump();
    final amount = find.byKey(const Key('expense-create-amount-field'));
    expect(tester.widget<TextField>(amount).enabled, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    accounts.result.complete(await FakeAccountsRepository().list());
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(amount).focusNode!.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tap(find.byKey(const Key('expense-create-merchant-field')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(amount).focusNode!.hasFocus, isFalse);
  });

  testWidgets('Manual wheel entry opens keyboard every time', (tester) async {
    await pumpExpensesApp(tester, WidgetExpensesRepository());
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.tap(find.byKey(const Key('expenses-create-fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('expenses-wheel-manual')));
      await tester.pumpAndSettle();
      final amount = find.byKey(const Key('expense-create-amount-field'));
      expect(tester.widget<TextField>(amount).focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('manual expense catalog displays canonical labels in Spanish', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpExpensesApp(
      tester,
      WidgetExpensesRepository(),
      initialLocation: '/expenses/new',
      categoriesRepository: NeedsWidgetOptionsCategoriesRepository(),
    );

    expect(find.byKey(const Key('expense-category-chip-3')), findsOneWidget);
    expect(find.text('Necesidades'), findsOneWidget);
    expect(find.text('needs'), findsNothing);
  });

  testWidgets('category catalog failure keeps manual expense form available', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpExpensesApp(
      tester,
      WidgetExpensesRepository(),
      initialLocation: '/expenses/new',
      categoriesRepository: FailingWidgetOptionsCategoriesRepository(),
    );

    expect(
      find.byKey(const Key('expense-create-amount-field')),
      findsOneWidget,
    );
    expect(
      find.textContaining('No pudimos cargar las categorías'),
      findsOneWidget,
    );
    expect(find.textContaining('private-category-response'), findsNothing);
  });

  testWidgets('income source failure is shown only in income context', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpExpensesApp(
      tester,
      WidgetExpensesRepository(),
      initialLocation: '/expenses/new',
      incomeSourcesRepository: FailingWidgetIncomeSourcesRepository(),
    );

    expect(find.textContaining('No se cargaron las fuentes'), findsNothing);
    expect(
      find.byKey(const Key('expense-create-submit-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('segment-ingreso')));
    await tester.pumpAndSettle();

    expect(find.textContaining('No se cargaron las fuentes'), findsOneWidget);
    expect(find.text('Copiar detalles del error'), findsNothing);
    expect(
      find.byKey(const Key('income-create-submit-button')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('income-create-submit-button')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('retry preserves a custom income source and saves without ID', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final sourcesRepository = FailingWidgetIncomeSourcesRepository();
    final incomesRepository = FakeIncomesRepository();

    await pumpExpensesApp(
      tester,
      WidgetExpensesRepository(),
      initialLocation: '/expenses/new',
      incomeSourcesRepository: sourcesRepository,
      incomesRepository: incomesRepository,
    );
    await tester.tap(find.byKey(const Key('segment-ingreso')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('income-create-source-custom-field')),
      'Consultoría externa',
    );

    sourcesRepository.fail = false;
    await tester.ensureVisible(find.text('Reintentar'));
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('income-create-source-custom-field')),
          )
          .controller
          ?.text,
      'Consultoría externa',
    );
    await tester.enterText(
      find.byKey(const Key('expense-create-amount-field')),
      '250',
    );
    await tester.ensureVisible(
      find.byKey(const Key('income-create-submit-button')),
    );
    await tester.tap(find.byKey(const Key('income-create-submit-button')));
    await tester.pumpAndSettle();

    expect(incomesRepository.lastCreateCommand?.incomeSourceId, isNull);
    expect(
      incomesRepository.lastCreateCommand?.description,
      'Consultoría externa',
    );
  });

  testWidgets('account load failure blocks save without claiming no accounts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpExpensesApp(
      tester,
      WidgetExpensesRepository(),
      initialLocation: '/expenses/new',
      accountsRepository: FailingWidgetOptionsAccountsRepository(),
    );

    expect(find.text('No tienes cuentas registradas'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('expense-create-submit-button')),
          )
          .onPressed,
      isNull,
    );
  });

  for (final route in ['/accounts/new', '/categories/new', '/budgets/new']) {
    testWidgets(
      'Android Back from deep linked $route preserves section then Inicio',
      (tester) async {
        await pumpExpensesApp(
          tester,
          WidgetExpensesRepository(),
          initialLocation: route,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('dashboard-account-balance')),
          findsOneWidget,
        );
      },
    );
  }

  for (final section in [
    '/accounts',
    '/budgets',
    '/categories',
    '/income-sources',
  ]) {
    testWidgets('Android Back returns from deep linked $section to Inicio', (
      tester,
    ) async {
      await pumpExpensesApp(
        tester,
        WidgetExpensesRepository(),
        initialLocation: section,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('dashboard-account-balance')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('bottom-nav-inicio')), findsOneWidget);
    });
  }

  testWidgets('the expense detail screen shows the saved expense', (
    tester,
  ) async {
    final repository = WidgetExpensesRepository();
    await pumpExpensesApp(tester, repository, initialLocation: '/expenses/7');

    expect(find.text('Detalle del gasto'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    final edit = find.byKey(const Key('expense-edit-button'));
    final delete = find.byKey(const Key('expense-delete-button'));
    expect(edit, findsOneWidget);
    expect(delete, findsOneWidget);
    expect(find.byTooltip('Editar gasto'), findsOneWidget);
    expect(find.byTooltip('Eliminar gasto'), findsOneWidget);
    expect(find.bySemanticsLabel('Editar gasto'), findsOneWidget);
    expect(find.bySemanticsLabel('Eliminar gasto'), findsOneWidget);
    expect(tester.getSize(edit), const Size(48, 48));
    expect(tester.getSize(delete), tester.getSize(edit));
    expect(tester.getTopLeft(edit).dy, tester.getTopLeft(delete).dy);
    expect(tester.getTopRight(edit).dx, tester.getTopLeft(delete).dx);
    expect(tester.getTopLeft(edit).dy, lessThan(100));
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: delete,
              matching: find.byIcon(FinanceIcons.deleteOutline),
            ),
          )
          .color,
      Theme.of(tester.element(delete)).colorScheme.error,
    );
    expect(find.text('Eliminar gasto definitivamente'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byKey(const Key('theme-toggle-button')), findsNothing);
  });

  testWidgets('expense header edit action opens the expense form', (
    tester,
  ) async {
    await pumpExpensesApp(
      tester,
      WidgetExpensesRepository(),
      initialLocation: '/expenses/7',
    );

    await tester.tap(find.byKey(const Key('expense-edit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Editar gasto'), findsWidgets);
    expect(find.byKey(const Key('expense-name-field')), findsOneWidget);
  });

  testWidgets('saved receipt uses adjacent edit and delete header actions', (
    tester,
  ) async {
    final repository = WidgetExpensesRepository()
      ..expenses = [expense(captureSource: CaptureSource.ai)];
    await pumpExpensesApp(tester, repository, initialLocation: '/expenses/7');

    expect(find.text('Detalle del recibo'), findsOneWidget);
    final edit = find.byKey(const Key('expense-edit-button'));
    final delete = find.byKey(const Key('expense-delete-button'));
    expect(edit, findsOneWidget);
    expect(delete, findsOneWidget);
    expect(find.byTooltip('Editar recibo'), findsOneWidget);
    expect(find.byTooltip('Eliminar recibo'), findsOneWidget);
    expect(find.bySemanticsLabel('Editar recibo'), findsOneWidget);
    expect(find.bySemanticsLabel('Eliminar recibo'), findsOneWidget);
    expect(tester.getSize(delete), tester.getSize(edit));
    expect(tester.getTopLeft(edit).dy, tester.getTopLeft(delete).dy);
    expect(tester.getTopRight(edit).dx, tester.getTopLeft(delete).dx);
    expect(find.text('Eliminar recibo'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);

    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.text('Editar recibo'), findsWidgets);
    expect(find.byKey(const Key('expense-receipt-name-field')), findsOneWidget);
  });

  testWidgets('non-editable expense keeps both header actions disabled', (
    tester,
  ) async {
    final repository = WidgetExpensesRepository()
      ..expenses = [expense(status: ExpenseStatus.pending)];
    await pumpExpensesApp(tester, repository, initialLocation: '/expenses/7');

    for (final key in [
      const Key('expense-edit-button'),
      const Key('expense-delete-button'),
    ]) {
      final button = tester.widget<HeaderIconButton>(find.byKey(key));
      expect(button.onPressed, isNull);
      expect(tester.getSize(find.byKey(key)), const Size(48, 48));
    }
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
    expect(find.byKey(const Key('home-title')), findsNothing);
  });

  testWidgets(
    'new expense appears in Movimientos after switching tabs from Inicio',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = WidgetExpensesRepository()
        ..expenses = []
        ..historyItems = [];
      var budgetLoadCalls = 0;
      await pumpExpensesApp(
        tester,
        repository,
        initialLocation: '/home',
        onBudgetsLoad: () => budgetLoadCalls += 1,
      );

      await tester.tap(find.byKey(const Key('expenses-create-fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('expenses-wheel-manual')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('expense-create-merchant-field')),
        'Compra inmediata',
      );
      await tester.enterText(
        find.byKey(const Key('expense-create-amount-field')),
        '25.00',
      );
      final historyCallsBeforeSave = repository.seenHistoryFilters.length;
      final budgetLoadsBeforeSave = budgetLoadCalls;
      await tester.tap(find.byKey(const Key('expense-create-submit-button')));
      await tester.pumpAndSettle();

      expect(repository.lastCreateCommand?.merchant, 'Compra inmediata');
      expect(
        repository.seenHistoryFilters.length,
        greaterThan(historyCallsBeforeSave),
      );
      expect(budgetLoadCalls, greaterThan(budgetLoadsBeforeSave));
      await tester.tap(find.byKey(const Key('bottom-nav-movimientos')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-card-99')), findsOneWidget);
      expect(find.byKey(const Key('movements-empty-state')), findsNothing);
    },
  );

  testWidgets('delete asks for confirmation and returns to the list', (
    tester,
  ) async {
    final repository = WidgetExpensesRepository();
    await pumpExpensesApp(tester, repository, initialLocation: '/expenses/7');

    final deleteButton = find.byKey(const Key('expense-delete-button'));
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar este gasto definitivamente?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('expense-confirm-delete-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-title')), findsNothing);
    expect(repository.expenses, isEmpty);
  });

  testWidgets('deleting a receipt also removes its local photo', (
    tester,
  ) async {
    final repository = WidgetExpensesRepository()
      ..expenses = [expense(captureSource: CaptureSource.ai)];
    final photoStore = _FakeReceiptPhotoCacheRepository()
      ..photo = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/KxQAAAAASUVORK5CYII=',
      );
    await pumpExpensesApp(
      tester,
      repository,
      initialLocation: '/expenses/7',
      receiptPhotoCacheRepository: photoStore,
    );

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expense-delete-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expense-confirm-delete-button')));
    await tester.pumpAndSettle();

    expect(photoStore.deleted, [7]);
    expect(photoStore.deletedOwners, [42]);
    expect(photoStore.photo, isNull);
    expect(repository.expenses, isEmpty);
    expect(find.text('Recibo eliminado definitivamente.'), findsOneWidget);
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

  testWidgets('receipt edit form saves the replaced product list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final repository = WidgetExpensesRepository()
      ..expenses = [
        expense(
          captureSource: CaptureSource.ai,
          items: [
            ExpenseItem(
              name: 'Leche',
              amount: MoneyAmount.parseApi('4000.00'),
              quantity: '1.000',
              unitPrice: MoneyAmount.parseApi('4000.00'),
              categoryId: 3,
            ),
            ExpenseItem(
              name: 'Pan',
              amount: MoneyAmount.parseApi('3000.00'),
              quantity: '1.000',
              unitPrice: MoneyAmount.parseApi('3000.00'),
            ),
          ],
        ),
      ];
    await pumpExpensesApp(
      tester,
      repository,
      initialLocation: '/expenses/7/edit',
      accountsRepository: WidgetOptionsAccountsRepository(),
      categoriesRepository: WidgetOptionsCategoriesRepository(),
    );

    expect(find.text('Productos del recibo (2)'), findsOneWidget);

    // Remove the second product and rename the first one.
    await tester.tap(find.byTooltip('Eliminar producto').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar producto').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre *'),
      'Leche entera',
    );
    await tester.tap(find.text('Guardar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expense-save-button')));
    await tester.pumpAndSettle();

    final items = repository.lastCommand?.items;
    expect(items, isNotNull);
    expect(items, hasLength(1));
    expect(items!.single.name, 'Leche entera');
    expect(items.single.totalPrice, 4000.0);
    // The stored category and the total that follows the products are sent.
    expect(items.single.categoryId, 3);
    expect(repository.lastCommand?.amount?.toApiString(), '4000.00');
  });

  testWidgets('plain expense edit never submits a product list', (
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

    await tester.enterText(
      find.byKey(const Key('expense-name-field')),
      'Updated groceries',
    );
    await tester.tap(find.byKey(const Key('expense-save-button')));
    await tester.pumpAndSettle();

    expect(repository.lastCommand?.name, 'Updated groceries');
    expect(repository.lastCommand?.items, isNull);
    expect(repository.lastCommand?.toJson().containsKey('items'), isFalse);
  });

  testWidgets('history groups entries and applies the debounced search', (
    tester,
  ) async {
    final repository = WidgetExpensesRepository();
    await pumpExpensesApp(tester, repository, initialLocation: '/history');

    expect(find.byKey(const Key('history-list')), findsOneWidget);
    expect(find.byKey(const Key('history-card-8')), findsOneWidget);
    // Day header for the fixture (2026-09-17) and the app money format: the
    // card must not print the raw wire amount (`COP -25.00`).
    expect(find.textContaining('sep'), findsWidgets);
    expect(find.text('-\$ 25 COP'), findsOneWidget);
    expect(find.text('Balance -\$ 25 COP'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('history-search-field')),
      'market',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(repository.seenHistoryFilters.last.search, 'market');
    expect(find.byKey(const Key('history-active-search')), findsOneWidget);

    await tester.tap(find.byKey(const Key('history-search-clear')));
    await tester.pumpAndSettle();

    expect(repository.seenHistoryFilters.last.search, isNull);
  });

  testWidgets('history income rows render with a plus sign', (tester) async {
    final repository = WidgetExpensesRepository()
      ..historyItems = [incomeHistoryItem(id: 15)];
    await pumpExpensesApp(tester, repository, initialLocation: '/history');

    expect(find.byKey(const Key('history-card-15')), findsOneWidget);
    expect(find.text('+\$ 500 COP'), findsOneWidget);
  });

  testWidgets('history type chips filter the feed and clear it again', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = WidgetExpensesRepository()
      ..historyItems = [historyItem()];
    await pumpExpensesApp(tester, repository, initialLocation: '/history');

    expect(find.byKey(const Key('history-card-8')), findsOneWidget);

    await tester.tap(find.byKey(const Key('history-filter-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history-type-chip-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver resultados'));
    await tester.pumpAndSettle();

    expect(repository.seenHistoryFilters.last.type, TransactionType.income);
    expect(find.text('Sin resultados para estos filtros'), findsOneWidget);

    await tester.tap(find.byKey(const Key('history-empty-clear-button')));
    await tester.pumpAndSettle();

    expect(repository.seenHistoryFilters.last.hasActiveFilters, isFalse);
    expect(find.byKey(const Key('history-card-8')), findsOneWidget);
  });

  testWidgets('history account dropdown filters by name and sends the id', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = WidgetExpensesRepository()
      ..historyItems = [historyItem(), historyItem(id: 9, accountId: 12)];
    await pumpExpensesApp(tester, repository, initialLocation: '/history');

    expect(find.text('Balance -\$ 50 COP'), findsOneWidget);

    await tester.tap(find.byKey(const Key('history-filter-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history-account-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver resultados'));
    await tester.pumpAndSettle();

    expect(repository.seenHistoryFilters.last.accountId, 11);
    expect(find.text('Balance -\$ 25 COP'), findsOneWidget);
    expect(find.byKey(const Key('history-active-account')), findsOneWidget);

    await tester.tap(find.byKey(const Key('history-active-account')));
    await tester.pumpAndSettle();

    expect(repository.seenHistoryFilters.last.accountId, isNull);
  });

  testWidgets('history period chips filter the request and clear the range', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = WidgetExpensesRepository();
    await pumpExpensesApp(tester, repository, initialLocation: '/history');

    await tester.tap(find.byKey(const Key('history-period-chip-2')));
    await tester.pumpAndSettle();

    expect(repository.seenHistoryFilters.last.period, HistoryPeriod.month);

    await tester.tap(find.byKey(const Key('history-active-period')));
    await tester.pumpAndSettle();

    expect(repository.seenHistoryFilters.last.period, isNull);
    expect(repository.seenHistoryFilters.last.startDate, isNull);
  });

  testWidgets('history filters by capture source, receipt shape and merchant', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = WidgetExpensesRepository();
    await pumpExpensesApp(tester, repository, initialLocation: '/history');

    await tester.tap(find.byKey(const Key('history-filter-toggle')));
    await tester.pumpAndSettle();

    // Origen: the AI chip groups photo, text and voice captures.
    await tester.tap(find.byKey(const Key('history-source-chip-1')));
    await tester.pumpAndSettle();
    expect(repository.seenHistoryFilters.last.captureSource, CaptureSource.ai);

    // Registro: receipts with several lines vs single expenses.
    await tester.tap(find.byKey(const Key('history-receipt-chip-1')));
    await tester.pumpAndSettle();
    expect(repository.seenHistoryFilters.last.receiptKind, ReceiptKind.multi);

    // Comercio: typed and submitted, or picked from the suggestions.
    await tester.enterText(
      find.byKey(const Key('history-store-field')),
      'Exito',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(repository.seenHistoryFilters.last.store, 'Exito');

    await tester.tap(find.byKey(const Key('history-store-suggestion-0')));
    await tester.pumpAndSettle();
    expect(repository.seenHistoryFilters.last.store, 'Market');
    await tester.tap(find.text('Ver resultados'));
    await tester.pumpAndSettle();

    // Every filter is visible as a removable chip and clears independently.
    expect(find.byKey(const Key('history-active-source')), findsOneWidget);
    expect(find.byKey(const Key('history-active-receipt')), findsOneWidget);
    expect(find.byKey(const Key('history-active-store')), findsOneWidget);

    await tester.tap(find.byKey(const Key('history-active-store')));
    await tester.pumpAndSettle();
    expect(repository.seenHistoryFilters.last.store, isNull);
    expect(repository.seenHistoryFilters.last.captureSource, CaptureSource.ai);
  });

  testWidgets('merchant suggestions stay separated from the account field', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = WidgetExpensesRepository()
      ..historyItems = [historyItem()];
    await pumpExpensesApp(tester, repository, initialLocation: '/history');
    expect(tester.takeException(), isNull, reason: 'history page layout');

    await tester.tap(find.byKey(const Key('history-filter-toggle')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'filters sheet layout');

    final suggestion = tester.getRect(
      find.byKey(const Key('history-store-suggestion-0')),
    );
    final account = tester.getRect(
      find.byKey(const Key('history-account-field')),
    );
    expect(account.top - suggestion.bottom, greaterThanOrEqualTo(20));
    expect(tester.takeException(), isNull, reason: 'scrolled filters layout');
  });

  testWidgets('filter results stays reachable on a short viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpExpensesApp(
      tester,
      WidgetExpensesRepository()..historyItems = [historyItem()],
      initialLocation: '/history',
    );
    await tester.tap(find.byKey(const Key('history-filter-toggle')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ver resultados'));
    await tester.pumpAndSettle();

    expect(find.text('Ver resultados'), findsOneWidget);
    expect(
      tester.getRect(find.text('Ver resultados')).bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height),
    );
    expect(tester.takeException(), isNull);
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

      expect(find.byKey(const Key('history-list')), findsOneWidget);
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

      expect(find.byKey(const Key('history-list')), findsOneWidget);
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
      authenticatedSession: true,
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
      expect(
        find.byKey(const Key('expense-create-new-category-chip')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('expense-create-optional-toggle')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('expense-create-date-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('expense-create-note-field')),
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
          matching: find.byIcon(FinanceIcons.arrowBack),
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
          matching: find.byIcon(FinanceIcons.arrowBack),
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

  testWidgets('dashboard shows the stock balance and the month flow chips', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = WidgetExpensesRepository()..expenses = [];
    await pumpExpensesApp(tester, repository, initialLocation: '/dashboard');

    expect(find.text('Saldo en cuentas'), findsOneWidget);
    // Stock: the live balance of the only active account.
    expect(find.text(r'$ 100 COP'), findsOneWidget);
    // Flow chips are the current month (2026-09 from the pinned clock): no
    // incomes in the fake, one 25.00 expense in the history fixture.
    expect(find.text('Este mes'), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);
    // Zero income and the month expense, in the new "$ 25 COP" money format.
    expect(find.text(r'$ 0 COP'), findsWidgets);
    expect(find.text(r'-$ 25 COP'), findsWidgets);
    // Accounts live in Settings now, not as a shortcut on the dashboard.
    expect(
      find.text(r'1 cuenta activa · $ 100 COP · Ver saldos'),
      findsNothing,
    );
  });

  testWidgets('dashboard groups balances by currency without mixing them', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = WidgetExpensesRepository()..expenses = [];
    await pumpExpensesApp(
      tester,
      repository,
      initialLocation: '/dashboard',
      accountsRepository: _TwoCurrencyAccountsRepository(),
    );

    expect(find.text(r'$ 2.310.200 COP'), findsOneWidget);
    expect(find.text(r'$ 1.250 USD'), findsNothing);
    await tester.tap(find.byKey(const Key('dashboard-currency-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD').last);
    await tester.pumpAndSettle();
    expect(find.text(r'$ 1.250 USD'), findsOneWidget);
    expect(find.text(r'$ 2.310.200 COP'), findsNothing);
    await tester.tap(find.byKey(const Key('dashboard-currency-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('COP').last);
    await tester.pumpAndSettle();
    // Accounts live in Settings now, not as a shortcut on the dashboard.
    expect(
      find.text(
        r'2 cuentas activas · $ 2.310.200 COP · $ 1.250 USD · Ver saldos',
      ),
      findsNothing,
    );
    expect(find.text(r'$ 0 COP'), findsWidgets);
    expect(find.text(r'-$ 25 COP'), findsWidgets);
  });

  testWidgets(
    'Inicio shows Hero balance and does not duplicate history movements',
    (tester) async {
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpExpensesApp(
        tester,
        WidgetExpensesRepository(),
        initialLocation: '/dashboard',
      );

      expect(find.byKey(const Key('home-title')), findsNothing);
      expect(find.text('Saldo en cuentas'), findsOneWidget);
      expect(find.text('Historial reciente'), findsNothing);
      expect(find.byKey(const Key('expense-card-7')), findsNothing);
      expect(find.byKey(const Key('home-accounts-button')), findsNothing);
    },
  );

  testWidgets('a history movement opens the expense detail', (tester) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpExpensesApp(
      tester,
      WidgetExpensesRepository(),
      initialLocation: '/history',
    );
    await tester.tap(find.byKey(const Key('history-card-8')));
    await tester.pumpAndSettle();

    expect(find.text('Detalle del gasto'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
  });

  testWidgets('the history screen shows loaded movements count', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final historyItems = List.generate(10, (i) => historyItem(id: 100 + i));
    final repository = WidgetExpensesRepository()..historyItems = historyItems;

    await pumpExpensesApp(tester, repository, initialLocation: '/history');

    expect(find.text('10 movimientos'), findsOneWidget);
  });

  testWidgets('with no movements the history offers to register the first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = WidgetExpensesRepository()
      ..expenses = []
      ..historyItems = [];

    await pumpExpensesApp(tester, repository, initialLocation: '/history');

    expect(find.byKey(const Key('movements-empty-state')), findsOneWidget);
    await tester.tap(find.byKey(const Key('movements-empty-register-button')));
    await tester.pumpAndSettle();
    expect(find.text('Registrar gasto'), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('expense-create-merchant-field')),
      'Compra de prueba',
    );
    await tester.enterText(
      find.byKey(const Key('expense-create-amount-field')),
      '25.00',
    );
    await tester.tap(find.byKey(const Key('expense-create-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('history-card-99')), findsOneWidget);
    expect(find.byKey(const Key('movements-empty-state')), findsNothing);
  });

  testWidgets(
    'history refreshes after registering an income from empty state',
    (tester) async {
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = WidgetExpensesRepository()
        ..expenses = []
        ..historyItems = [];
      final incomes = FakeIncomesRepository()
        ..onCreated = (_) {
          repository.historyItems = [incomeHistoryItem(id: 99)];
        };
      await pumpExpensesApp(
        tester,
        repository,
        initialLocation: '/history',
        incomesRepository: incomes,
      );

      await tester.tap(
        find.byKey(const Key('movements-empty-register-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('segment-ingreso')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('expense-create-amount-field')),
        '150.00',
      );
      await tester.tap(find.byKey(const Key('income-create-submit-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-card-99')), findsOneWidget);
      expect(find.byKey(const Key('movements-empty-state')), findsNothing);
    },
  );

  testWidgets(
    'Inicio opens first with Hero header and Movimientos tab shows ledger',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = WidgetExpensesRepository();
      await pumpExpensesApp(tester, repository, initialLocation: '/home');

      expect(find.byKey(const Key('home-title')), findsNothing);
      expect(find.text('Saldo en cuentas'), findsOneWidget);
      expect(find.byKey(const Key('expenses-create-fab')), findsOneWidget);
      expect(find.text('Historial reciente'), findsNothing);
      expect(find.byKey(const Key('home-accounts-button')), findsNothing);

      await tester.tap(find.byKey(const Key('bottom-nav-movimientos')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-list')), findsOneWidget);
      expect(find.byKey(const Key('history-card-8')), findsOneWidget);
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
