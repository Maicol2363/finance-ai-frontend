import 'dart:async';
import 'dart:io';

import 'package:finance_ai/app.dart';
import 'package:finance_ai/core/router/app_router.dart';
import 'package:finance_ai/core/theme/app_palette.dart';
import 'package:finance_ai/core/formatters/money_formatter.dart';
import 'package:finance_ai/core/money/currency_totals.dart';
import 'package:finance_ai/core/time/clock_provider.dart';
import 'package:finance_ai/features/accounts/data/accounts_repository.dart';
import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/budgets/data/budgets_repository.dart';
import 'package:finance_ai/features/budgets/domain/budget_models.dart';
import 'package:finance_ai/features/categories/data/categories_repository.dart';
import 'package:finance_ai/features/categories/domain/category_models.dart';
import 'package:finance_ai/features/dashboard/application/dashboard_summary_provider.dart';
import 'package:finance_ai/features/dashboard/domain/dashboard_summary.dart';
import 'package:finance_ai/features/dashboard/presentation/dashboard_screen.dart';
import 'package:finance_ai/features/dashboard/presentation/spending_trend_card.dart';
import 'package:finance_ai/features/expenses/data/expenses_repository.dart';
import 'package:finance_ai/features/expenses/domain/expense_models.dart';
import 'package:finance_ai/features/expenses/domain/history_models.dart';
import 'package:finance_ai/features/income_sources/data/income_sources_repository.dart';
import 'package:finance_ai/features/income_sources/domain/income_source_models.dart';
import 'package:finance_ai/features/incomes/data/incomes_repository.dart';
import 'package:finance_ai/features/incomes/domain/income_models.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:finance_ai/features/expenses/application/monthly_totals.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/accessibility_test_helpers.dart';

const _cop = CurrencySummary(
  id: 1,
  code: 'COP',
  name: 'Colombian Peso',
  decimals: 2,
);

const _usd = CurrencySummary(
  id: 2,
  code: 'USD',
  name: 'US Dollar',
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

Expense _expense({String amount = '25.00'}) => Expense(
  id: 7,
  transactionId: 8,
  receiptId: 9,
  name: 'Groceries',
  amount: MoneyAmount.parseApi(amount),
  quantity: '1.000',
  unitPrice: MoneyAmount.parseApi(amount),
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
    items: expenses.isEmpty
        ? const []
        : [_historyItem(amount: expenses.first.amount.toApiString())],
    total: expenses.isEmpty ? 0 : 1,
    page: 1,
    pageSize: 50,
    hasNext: false,
  );
}

/// The month's expense entry as the history endpoint reports it: the Dashboard
/// breakdown is built from this, not from the first page of `/expenses`.
HistoryItem _historyItem({
  String amount = '25.00',
  ExpenseStatus status = ExpenseStatus.confirmed,
  String categoryName = 'Food',
}) => HistoryItem(
  id: 8,
  type: TransactionType.expense,
  status: status,
  occurredAt: DateTime.utc(2026, 9, 17, 12, 30),
  description: 'Purchase at Market',
  captureSource: CaptureSource.manual,
  incomeSource: null,
  movements: [
    HistoryMovement(
      accountId: 11,
      accountName: 'Cash',
      amount: MoneyAmount.parseApi('-$amount'),
      currency: _cop,
      currencyCode: 'COP',
    ),
  ],
  expense: HistoryExpense(
    receiptId: 9,
    name: 'Market',
    occurredAt: DateTime.utc(2026, 9, 17, 12, 30),
    purchasedAt: DateTime.utc(2026, 9, 17, 12, 30),
    totalAmount: MoneyAmount.parseApi(amount),
    note: null,
    store: 'Market',
    storeName: 'Market',
    items: [
      HistoryExpenseItem(
        id: 7,
        name: 'Groceries',
        amount: MoneyAmount.parseApi(amount),
        quantity: '1.000',
        unitPrice: MoneyAmount.parseApi(amount),
        note: null,
        category: ExpenseCategory(
          id: categoryName == 'Food' ? 3 : 4,
          name: categoryName,
        ),
        imagePath: null,
      ),
    ],
    receiptImage: null,
  ),
);

class _FakeAccountsRepository implements AccountsRepository {
  _FakeAccountsRepository({this.includeUsd = false});

  final bool includeUsd;

  @override
  Future<AccountListResult> list({bool includeInactive = false}) async =>
      AccountListResult(
        accounts: [_testAccount],
        suggestedCurrencyCode: 'COP',
        supportedCurrencies: includeUsd ? const [_cop, _usd] : const [_cop],
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
  _FakeBudgetsRepository({this.budgets = const []});

  final List<Budget> budgets;

  @override
  Future<BudgetListResult> list() async => BudgetListResult(
    budgets: budgets,
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
  List<Budget>? budgets,
  DashboardSummary? dashboardSummary,
  bool isolatedDashboard = false,
  bool totalsFailure = false,
  MonthlyTotals? staleSummaryTotals,
  bool includeUsd = false,
  MonthlyTotals? analysisTotals,
  Completer<MonthlyTotals>? pendingAnalysisTotals,
}) async {
  final router = isolatedDashboard
      ? GoRouter(
          initialLocation: '/dashboard',
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) {
                final theme = Theme.of(context);
                return Theme(
                  data: theme.copyWith(
                    textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
                    primaryTextTheme: theme.primaryTextTheme.apply(
                      fontFamily: 'Roboto',
                    ),
                    textButtonTheme: TextButtonThemeData(
                      style: theme.textButtonTheme.style?.copyWith(
                        textStyle: const WidgetStatePropertyAll(
                          TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const DashboardScreen(),
                );
              },
            ),
          ],
        )
      : createAppRouter(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (totalsFailure)
          monthlyTotalsProvider.overrideWith(
            (ref) async => throw StateError('private-financial-form-value'),
          ),
        if (staleSummaryTotals != null)
          monthlyTotalsProvider.overrideWith((ref) async => staleSummaryTotals),
        if (analysisTotals != null)
          periodTotalsProvider.overrideWith((ref) async {
            final period = ref.watch(dashboardPeriodProvider);
            if (period == DashboardPeriod.thisMonth ||
                pendingAnalysisTotals == null) {
              return analysisTotals;
            }
            return pendingAnalysisTotals.future;
          }),
        expensesRepositoryProvider.overrideWithValue(
          _FakeExpensesRepository(expenses: expenses),
        ),
        accountsRepositoryProvider.overrideWithValue(
          _FakeAccountsRepository(includeUsd: includeUsd),
        ),
        categoriesRepositoryProvider.overrideWithValue(
          _FakeCategoriesRepository(),
        ),
        budgetsRepositoryProvider.overrideWithValue(
          _FakeBudgetsRepository(budgets: budgets ?? const []),
        ),
        incomesRepositoryProvider.overrideWithValue(
          _FakeIncomesRepository(incomes: incomes),
        ),
        incomeSourcesRepositoryProvider.overrideWithValue(
          _FakeIncomeSourcesRepository(),
        ),
        if (dashboardSummary != null)
          dashboardSummaryProvider.overrideWith(
            (ref) async => dashboardSummary,
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
  testWidgets(
    'dashboard hides totals from a previous window while refreshing',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await _pumpAt(
        tester,
        '/dashboard',
        isolatedDashboard: true,
        staleSummaryTotals: MonthlyTotals(
          monthStart: DateTime.utc(2026, 8, 1),
          windowEnd: DateTime.utc(2026, 8, 31),
          byCurrency: const {
            'COP': CurrencyTotals(incomes: 987654, expenses: 123456),
          },
          expenseItems: const [],
        ),
      );

      expect(find.text('987.654'), findsNothing);
      expect(find.text('1.234'), findsNothing);
      expect(find.text('—'), findsNWidgets(3));
    },
  );

  testWidgets(
    'Home failure is Spanish and exposes only a safe copyable diagnostic',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _pumpAt(tester, '/home', totalsFailure: true);
      final copy = find.byKey(const Key('copy-error-details-button'));
      await tester.ensureVisible(copy);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('error-diagnostic-code')), findsNothing);
      expect(find.textContaining('private-financial-form-value'), findsNothing);
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(copied, contains('dashboard_summary_unavailable'));
      expect(copied, isNot(contains('private-financial-form-value')));
    },
  );

  setUpAll(() async {
    final font = await File(
      'test/features/dashboard/presentation/fonts/Roboto-Regular.ttf',
    ).readAsBytes();
    await (FontLoader(
      'Roboto',
    )..addFont(Future.value(ByteData.sublistView(font)))).load();
    await (FontLoader('packages/lucide_icons_flutter/Lucide500')..addFont(
          rootBundle.load(
            'packages/lucide_icons_flutter/assets/build_font/LucideVariable-w500.ttf',
          ),
        ))
        .load();
  });

  testWidgets('compact home cards fit common mobile viewports', (tester) async {
    const sizes = [
      Size(320, 568),
      Size(360, 800),
      Size(390, 844),
      Size(430, 932),
    ];
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in sizes) {
      tester.view.physicalSize = size;
      await _pumpAt(tester, '/dashboard', isolatedDashboard: true);
      expect(
        find.byKey(const Key('dashboard-account-balance')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('dashboard-weekly-insight')), findsOneWidget);
      expect(
        find.byKey(const Key('dashboard-month-projection')),
        findsOneWidget,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('Presupuestos'), findsOneWidget);
      expect(find.text('Movimientos'), findsNothing);
      expect(find.byKey(const Key('dashboard-analysis-toggle')), findsNothing);
      expect(
        tester.takeException(),
        isNull,
        reason: 'home at ${size.width}x${size.height}',
      );
    }
    tester.view.physicalSize = const Size(390, 844);
    await _pumpAt(tester, '/dashboard', isolatedDashboard: true);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/dashboard_spending_summary_390x844.png'),
    );
  });

  testWidgets(
    'dark dashboard uses accessible olive tokens and light surfaces',
    (tester) async {
      await _pumpAt(tester, '/dashboard');
      await tester.tap(find.byKey(const Key('theme-toggle-button')));
      await tester.pumpAndSettle();

      final theme = Theme.of(tester.element(find.text('Saldo en cuentas')));
      final palette = theme.extension<AppPalette>()!;
      expect(palette.primary, const Color(0xFF8FB42C));
      expect(palette.header, const Color(0xFF222B31));
      expect(find.byKey(const Key('dashboard-hero')), findsNothing);
    },
  );

  testWidgets('dashboard renders compact summary and destinations', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpAt(tester, '/dashboard', includeUsd: true);
    expect(find.text('Saldo en cuentas'), findsOneWidget);
    expect(find.text(r'$ 100 COP'), findsOneWidget);
    expect(find.text('Este mes'), findsOneWidget);
    expect(find.text('Ingresos'), findsOneWidget);
    expect(find.text('Gastos'), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);
    expect(find.text('Insight semanal'), findsOneWidget);
    expect(find.text('Proyección del mes'), findsOneWidget);
    final currencyButton = find.byKey(const Key('dashboard-currency-selector'));
    final currencySemantics = tester.getSemantics(currencyButton);
    expect(currencySemantics.label, 'Seleccionar moneda');
    expect(currencySemantics.flagsCollection.isButton, isTrue);
    expect(
      currencySemantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(tester.getSize(currencyButton).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(currencyButton).height, greaterThanOrEqualTo(48));
    await tester.tap(find.bySemanticsLabel('Seleccionar moneda'));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<String>), findsNWidgets(2));
    await tester.tap(find.text('USD').last);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('dashboard-account-balance')),
        matching: find.text(MoneyFormatter.display(0, 'USD')),
      ),
      findsOneWidget,
    );
    expect(
      find.text(MoneyFormatter.display(0, 'USD', signed: true)),
      findsNWidgets(4),
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Presupuestos'), findsOneWidget);
    expect(find.text('Ver análisis'), findsOneWidget);
    expect(find.byKey(const Key('dashboard-hero')), findsNothing);
    expect(find.text('Últimos movimientos'), findsNothing);
    await tester.ensureVisible(
      find.byKey(const Key('dashboard-open-analysis')),
    );
    await tester.tap(find.byKey(const Key('dashboard-open-analysis')));
    await tester.pumpAndSettle();
    expect(find.text('Análisis'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    final analysisAmount = tester.widget<Text>(
      find.byKey(const Key('dashboard-spending-amount')),
    );
    expect(analysisAmount.data, MoneyFormatter.display(0, 'USD'));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('trend owns the period summary without a duplicate card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final summary = DashboardSummary.fromJson({
      'period': {
        'start': '2026-09-01T00:00:00Z',
        'end': '2026-09-30T23:59:59Z',
        'today': '2026-09-29T12:00:00Z',
        'is_current': true,
        'days_elapsed': 12,
        'days_total': 30,
      },
      'flow': {'incomes': '0.00', 'expenses': '25.00', 'net': '-25.00'},
      'comparison': {
        'current': '25.00',
        'previous': '0.00',
        'previous_start': '2026-08-01T00:00:00Z',
        'previous_end': '2026-08-31T23:59:59Z',
        'pct': null,
        'direction': 'none',
      },
      'weekly': [],
      'top_categories': [],
      'projection': {'spent_mtd': '25.00', 'projected': '28.00'},
      'balance': {
        'total': '100.00',
        'avg_monthly_spend': '30.00',
        'runway_months': 16.6,
      },
      'income_average': {
        'avg_3m': '0.00',
        'avg_6m': '0.00',
        'variability': null,
      },
      'weekday_pattern': {'weekend_avg': '0.00', 'weekday_avg': '0.00'},
      'recurring_candidates': [
        {
          'merchant': 'Crepes & waffles',
          'typical_amount': '10.00',
          'next_expected': '2026-09-30T00:00:00Z',
        },
      ],
      'recent': [],
    });
    await _pumpAt(tester, '/analysis', dashboardSummary: summary);

    expect(find.text('Análisis'), findsOneWidget);
    expect(find.byKey(const Key('dashboard-period-selector')), findsOneWidget);
    expect(find.text('Gastos por categoría'), findsOneWidget);
    expect(find.text('Insight semanal'), findsNothing);
    expect(find.textContaining('Generado por IA'), findsNothing);
    expect(
      find.textContaining(
        '÷ 29 días observados × 30 días del periodo. Corte: 29 de septiembre.',
      ),
      findsOneWidget,
      reason: 'cutoff and elapsed days come from the local selected window',
    );
    final expectedCurrentMonthProjection = MoneyFormatter.display(
      (2500 * 30 / 29).round(),
      'COP',
    );
    final projectionLabel = find.textContaining('Cierre est.:');
    await tester.scrollUntilVisible(projectionLabel, 240);
    expect(
      find.text('Cierre est.: $expectedCurrentMonthProjection'),
      findsOneWidget,
      reason:
          'the chart must use the same deterministic pace as Inicio, not the '
          'different backend projection of COP 28.00',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('analysis excludes voided movements from all summaries', (
    tester,
  ) async {
    final totals = MonthlyTotals(
      monthStart: DateTime.utc(2026, 9, 1),
      windowEnd: DateTime.utc(2026, 9, 30),
      byCurrency: const {'COP': CurrencyTotals(expenses: 2500)},
      expenseItems: [
        _historyItem(),
        _historyItem(
          amount: '100.00',
          status: ExpenseStatus.voided,
          categoryName: 'Voided category',
        ),
      ],
      historyComplete: true,
      previousHistoryComplete: true,
    );
    await _pumpAt(tester, '/analysis', analysisTotals: totals);

    final amount = tester.widget<Text>(
      find.byKey(const Key('dashboard-spending-amount')),
    );
    expect(amount.data, MoneyFormatter.display(2500, 'COP'));

    final trend = tester.widget<SpendingTrendCard>(
      find.byType(SpendingTrendCard),
    );
    expect(trend.cumulativeDays, isNotEmpty);
    expect(trend.cumulativeDays!.last.cumulativeMinorUnits, 2500);
    expect(
      find.byKey(const Key('dashboard-category-Voided category')),
      findsNothing,
    );
    expect(find.byKey(const Key('dashboard-category-Food')), findsOneWidget);

    final projection = MoneyFormatter.display((2500 * 30 / 29).round(), 'COP');
    final projectionLabel = find.textContaining('Cierre est.:');
    await tester.scrollUntilVisible(projectionLabel, 240);
    expect(find.text('Cierre est.: $projection'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('analysis hides prior period totals during range reload', (
    tester,
  ) async {
    final previousMonth = MonthlyTotals(
      monthStart: DateTime.utc(2026, 9, 1),
      windowEnd: DateTime.utc(2026, 9, 30),
      byCurrency: const {'COP': CurrencyTotals(expenses: 2500)},
      expenseItems: [_historyItem(categoryName: 'September category')],
      historyComplete: true,
      previousHistoryComplete: true,
    );
    final currentYear = MonthlyTotals(
      monthStart: DateTime.utc(2026, 1, 1),
      windowEnd: DateTime.utc(2026, 12, 31),
      byCurrency: const {'COP': CurrencyTotals(expenses: 5000)},
      expenseItems: [
        _historyItem(amount: '50.00', categoryName: 'Year category'),
      ],
      historyComplete: true,
      previousHistoryComplete: true,
      period: DashboardPeriod.thisYear,
    );
    final pending = Completer<MonthlyTotals>();
    await _pumpAt(
      tester,
      '/analysis',
      analysisTotals: previousMonth,
      pendingAnalysisTotals: pending,
    );
    expect(
      find.byKey(const Key('dashboard-category-September category')),
      findsOneWidget,
    );

    final yearPeriod = find.byKey(const Key('dashboard-period-thisYear'));
    await tester.ensureVisible(yearPeriod);
    await tester.tap(yearPeriod);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final amountDuringReload = tester.widget<Text>(
      find.byKey(const Key('dashboard-spending-amount')),
    );
    expect(amountDuringReload.data, '—');
    expect(
      find.byKey(const Key('dashboard-category-September category')),
      findsNothing,
    );
    expect(tester.widget<ChoiceChip>(yearPeriod).selected, isTrue);

    pending.complete(currentYear);
    await tester.pumpAndSettle();
    final loadedAmount = tester.widget<Text>(
      find.byKey(const Key('dashboard-spending-amount')),
    );
    expect(loadedAmount.data, MoneyFormatter.display(5000, 'COP'));
    final yearCategory = find.byKey(
      const Key('dashboard-category-Year category'),
    );
    await tester.scrollUntilVisible(yearCategory, 240);
    expect(yearCategory, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard category tap drills to filtered history', (
    tester,
  ) async {
    await _pumpAt(tester, '/analysis');

    final tile = find.byKey(const Key('dashboard-category-Food'));
    await tester.scrollUntilVisible(tile, 200);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile, warnIfMissed: false);
    await tester.pumpAndSettle();
    // History screen with the drill-down filters applied.
    expect(find.byKey(const Key('history-list')), findsOneWidget);
  });

  testWidgets('analysis deep link has a safe back destination', (tester) async {
    await _pumpAt(tester, '/analysis');
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('Saldo en cuentas'), findsOneWidget);
  });

  testWidgets('dashboard period selector switches to the year', (tester) async {
    await _pumpAt(tester, '/analysis');
    final yearPeriod = find.text('Este año').last;
    await tester.ensureVisible(yearPeriod);
    await tester.tap(yearPeriod);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const Key('dashboard-period-thisYear')),
          )
          .selected,
      isTrue,
    );
  });

  testWidgets('closed previous month explains why there is no projection', (
    tester,
  ) async {
    await _pumpAt(tester, '/analysis');
    final previousMonth = find.byKey(const Key('dashboard-period-lastMonth'));
    await tester.ensureVisible(previousMonth);
    await tester.tap(previousMonth);
    await tester.pumpAndSettle();
    // The explanation sits above the period controls in a lazy ListView. Move
    // back to the top so the widget is built before asserting its copy.
    await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Periodo cerrado al 31 de agosto: se muestran los gastos reales, sin proyección.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Proyección: gasto acumulado'), findsNothing);
    expect(
      find.byKey(const Key('dashboard-trend-closed-period')),
      findsOneWidget,
    );
  });

  testWidgets('dashboard period chips have large targets and selected state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpAt(tester, '/analysis');

    for (final entry in {
      'thisMonth': 'Este mes',
      'lastMonth': 'Mes anterior',
      'last3Months': 'Últimos 3 meses',
      'thisYear': 'Este año',
    }.entries) {
      final target = find.byKey(Key('dashboard-period-${entry.key}'));
      expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
      expect(find.bySemanticsLabel(entry.value), findsOneWidget);
    }

    expect(
      tester
          .getSemantics(find.byKey(const Key('dashboard-period-thisMonth')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    semantics.dispose();
  });

  testWidgets('dashboard renders empty state without expenses', (tester) async {
    await _pumpAt(tester, '/dashboard', expenses: const [], incomes: const []);

    expect(find.text('Saldo en cuentas'), findsOneWidget);
    expect(find.text(r'$ 0 COP'), findsWidgets);
    expect(find.text('Insight semanal'), findsOneWidget);
    expect(find.text('Proyección del mes'), findsOneWidget);
    expect(find.textContaining('No se registraron gastos'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const Key('dashboard-open-analysis')),
      200,
    );
    expect(find.text('Ver análisis'), findsOneWidget);
  });

  testWidgets(
    'settings budget row opens management and back returns to settings',
    (tester) async {
      await _pumpAt(tester, '/settings');
      await tester.tap(find.byKey(const Key('settings-budgets-row')));
      await tester.pumpAndSettle();
      expect(find.text('Presupuestos'), findsOneWidget);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.text('Ajustes'), findsWidgets);
    },
  );

  testWidgets('budget form back returns to budget list and then to settings', (
    tester,
  ) async {
    await _pumpAt(tester, '/settings');
    await tester.tap(find.byKey(const Key('settings-budgets-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('budgets-add-button')));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo presupuesto'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver a presupuestos'));
    await tester.pumpAndSettle();
    expect(find.text('Presupuestos'), findsOneWidget);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('Ajustes'), findsWidgets);
  });

  testWidgets('settings renders groups, rows and logout', (tester) async {
    await _pumpAt(tester, '/settings');

    expect(find.text('Ajustes'), findsWidgets);
    expect(find.byKey(const Key('settings-accounts-row')), findsOneWidget);
    expect(find.byKey(const Key('settings-budgets-row')), findsOneWidget);
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
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('logout-button')), findsOneWidget);
  });
}
