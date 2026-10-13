import 'package:finance_ai/app.dart';
import 'package:finance_ai/features/settings/presentation/settings_screen.dart';
import 'package:finance_ai/features/voice_capture/data/native_speech_service.dart';
import 'package:finance_ai/features/voice_capture/domain/speech_service.dart';
import 'package:finance_ai/features/accounts/data/accounts_repository.dart';
import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/auth/register/data/auth_repository.dart';
import 'package:finance_ai/features/auth/register/domain/registration_models.dart';
import 'package:finance_ai/features/auth/session/data/auth_session_repository.dart';
import 'package:finance_ai/features/auth/session/data/secure_credential_store.dart';
import 'package:finance_ai/features/auth/session/domain/session_models.dart';
import 'package:finance_ai/features/budgets/data/budgets_repository.dart';
import 'package:finance_ai/features/budgets/domain/budget_models.dart';
import 'package:finance_ai/features/categories/data/categories_repository.dart';
import 'package:finance_ai/features/categories/domain/category_models.dart'
    as categories;
import 'package:finance_ai/features/dashboard/application/dashboard_summary_provider.dart';
import 'package:finance_ai/features/dashboard/domain/dashboard_summary.dart';
import 'package:finance_ai/features/expenses/data/expenses_repository.dart';
import 'package:finance_ai/features/expenses/domain/expense_models.dart';
import 'package:finance_ai/features/expenses/domain/history_models.dart';
import 'package:finance_ai/features/income_sources/data/income_sources_repository.dart';
import 'package:finance_ai/features/income_sources/domain/income_source_models.dart';
import 'package:finance_ai/features/incomes/data/incomes_repository.dart';
import 'package:finance_ai/features/incomes/domain/income_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_router/go_router.dart';

class _SuccessfulRegistrationRepository implements AuthRepository {
  @override
  Future<RegistrationResult> register(RegistrationRequest request) async {
    return RegistrationResult(
      user: RegisteredUser(
        id: 1,
        email: request.email,
        preferredCurrency: 'COP',
      ),
      message: 'Account created successfully. You can now log in.',
    );
  }
}

class _UnavailableRegistrationRepository implements AuthRepository {
  @override
  Future<RegistrationResult> register(RegistrationRequest request) {
    throw const RegistrationRetryableFailure(
      code: 'network_unavailable',
      userMessage: 'We could not reach the service. Check your connection and try again.',
      correlationId: 'windows-smoke-request',
      technicalReason: 'connection_failure',
    );
  }
}

class _MemoryStore implements SecureCredentialStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> replace(String renewableCredential) async {
    value = renewableCredential;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

class _SuccessfulSessionRepository implements AuthSessionRepository {
  static const access = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  static const renewable = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  IssuedAuthSession get _issued {
    final now = DateTime.now().toUtc();
    return IssuedAuthSession(
      user: const AuthenticatedUser(
        id: 42,
        email: 'desktop@example.com',
        preferredCurrency: 'COP',
      ),
      accessCredential: access,
      renewableCredential: renewable,
      accessExpiresAt: now.add(const Duration(minutes: 15)),
      renewableExpiresAt: now.add(const Duration(days: 30)),
      absoluteExpiresAt: now.add(const Duration(days: 90)),
    );
  }

  @override
  Future<IssuedAuthSession> login(LoginRequest request) async => _issued;

  @override
  Future<IssuedAuthSession> refresh(String renewableCredential) async =>
      _issued;

  @override
  Future<AuthenticatedUser> currentUser(String accessCredential) async =>
      _issued.user;

  @override
  Future<void> logout(String renewableCredential) async {}
}

class _WindowsAccountsRepository implements AccountsRepository {
  static const currency = CurrencySummary(
    id: 1,
    code: 'COP',
    name: 'Colombian Peso',
    decimals: 2,
  );

  final accounts = <Account>[];

  AccountListResult get _result => AccountListResult(
    accounts: List.unmodifiable(accounts),
    suggestedCurrencyCode: 'COP',
    supportedCurrencies: const [currency],
    accountTypes: AccountType.values,
  );

  @override
  Future<AccountListResult> list({required bool includeInactive}) async =>
      _result;

  @override
  Future<Account> get(int accountId) async =>
      accounts.firstWhere((account) => account.id == accountId);

  @override
  Future<Account> create(AccountCreateCommand command) async {
    final now = DateTime.now().toUtc();
    final created = Account(
      id: 1,
      name: command.name,
      type: command.type,
      currency: currency,
      openingBalance: command.openingBalance,
      balance: command.openingBalance,
      currencyIsLocked: false,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    accounts.add(created);
    return created;
  }

  @override
  Future<Account> update(int accountId, AccountUpdateCommand command) =>
      throw UnimplementedError();

  @override
  Future<Account> setActive(int accountId, {required bool isActive}) =>
      throw UnimplementedError();

  @override
  Future<void> deleteAccount(int accountId) async {
    accounts.removeWhere((account) => account.id == accountId);
  }
}

/// In-memory repositories so the smoke tests never touch the network.
///
/// Home auto-loads expenses, accounts and incomes on mount; without these
/// overrides it would issue real HTTP requests and fail where no backend
/// is available.
class _EmptyExpensesRepository implements ExpensesRepository {
  @override
  Future<ExpenseListResult> list({int page = 1, int pageSize = 50}) async =>
      const ExpenseListResult(
        items: [],
        total: 0,
        page: 1,
        pageSize: 50,
        hasNext: false,
      );

  @override
  Future<Expense> get(int expenseId) async => throw const ExpenseFailure(
    code: 'expense_not_found',
    userMessage: 'This expense is no longer available.',
  );

  @override
  Future<Expense> create(ExpenseCreateCommand command) async =>
      throw const ExpenseFailure(
        code: 'expense_not_available',
        userMessage: 'Expenses are not available in the smoke test.',
      );

  @override
  Future<Expense> update(int expenseId, ExpenseUpdateCommand command) async =>
      throw const ExpenseFailure(
        code: 'expense_not_available',
        userMessage: 'Expenses are not available in the smoke test.',
      );

  @override
  Future<void> deleteExpense(int expenseId) async {}

  @override
  Future<HistoryResult> history(HistoryFilters filters) async =>
      const HistoryResult(
        items: [],
        total: 0,
        page: 1,
        pageSize: 50,
        hasNext: false,
      );
}

class _EmptyAccountsRepository implements AccountsRepository {
  @override
  Future<AccountListResult> list({required bool includeInactive}) async =>
      const AccountListResult(
        accounts: [],
        suggestedCurrencyCode: 'COP',
        supportedCurrencies: [],
        accountTypes: [],
      );

  @override
  Future<Account> get(int accountId) async => throw const AccountFailure(
    code: 'account_not_found',
    userMessage: 'This account is no longer available.',
  );

  @override
  Future<Account> create(AccountCreateCommand command) async =>
      throw const AccountFailure(
        code: 'account_not_available',
        userMessage: 'Accounts are not available in the smoke test.',
      );

  @override
  Future<Account> update(int accountId, AccountUpdateCommand command) async =>
      throw const AccountFailure(
        code: 'account_not_available',
        userMessage: 'Accounts are not available in the smoke test.',
      );

  @override
  Future<Account> setActive(int accountId, {required bool isActive}) =>
      throw const AccountFailure(
        code: 'account_not_available',
        userMessage: 'Accounts are not available in the smoke test.',
      );

  @override
  Future<void> deleteAccount(int accountId) async {}
}

class _EmptyIncomesRepository implements IncomesRepository {
  @override
  Future<List<Income>> list({int? accountId}) async => const [];

  @override
  Future<Income> get(int incomeId) async => throw const IncomeFailure(
    code: 'income_not_found',
    userMessage: 'This income is no longer available.',
  );

  @override
  Future<Income> create(IncomeWriteCommand command) async =>
      throw const IncomeFailure(
        code: 'income_not_available',
        userMessage: 'Incomes are not available in the smoke test.',
      );

  @override
  Future<Income> update(int incomeId, IncomeWriteCommand command) async =>
      throw const IncomeFailure(
        code: 'income_not_available',
        userMessage: 'Incomes are not available in the smoke test.',
      );

  @override
  Future<void> delete(int incomeId) async {}
}

class _EmptyBudgetsRepository implements BudgetsRepository {
  @override
  Future<BudgetListResult> list() async => const BudgetListResult(
    budgets: [],
    categories: [],
    supportedCurrencies: [_WindowsAccountsRepository.currency],
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

class _EmptyCategoriesRepository implements CategoriesRepository {
  @override
  Future<categories.CategoryListResult> list() async =>
      const categories.CategoryListResult(
        categories: [],
        supportedColors: [categories.CategoryColor.red],
        supportedIcons: [categories.CategoryIcon.food],
      );

  @override
  Future<categories.Category> get(int categoryId) => throw UnimplementedError();

  @override
  Future<categories.Category> create(
    categories.CategoryCreateCommand command,
  ) => throw UnimplementedError();

  @override
  Future<categories.Category> update(
    int categoryId,
    categories.CategoryUpdateCommand command,
  ) => throw UnimplementedError();

  @override
  Future<categories.CategoryListResult> reorder(List<int> categoryIds) =>
      throw UnimplementedError();

  @override
  Future<void> deleteCategory(int categoryId) => throw UnimplementedError();
}

class _EmptyIncomeSourcesRepository implements IncomeSourcesRepository {
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

DashboardSummary _emptyDashboardSummary() {
  final zero = MoneyAmount.parseApi('0');
  return DashboardSummary(
    period: PeriodSummary(
      start: DateTime.utc(2026, 10, 1),
      end: DateTime.utc(2026, 10, 31),
      today: DateTime.utc(2026, 10, 12),
      isCurrent: true,
      daysElapsed: 12,
      daysTotal: 31,
    ),
    flow: FlowSummary(incomes: zero, expenses: zero, net: zero),
    comparison: ComparisonSummary(
      current: zero,
      previous: zero,
      previousStart: DateTime.utc(2026, 9, 1),
      previousEnd: DateTime.utc(2026, 9, 30),
      pct: null,
      direction: 'none',
    ),
    weekly: const [],
    topCategories: const [],
    projection: ProjectionSummary(spentMtd: zero, projected: zero),
    balance: BalanceSummary(
      total: zero,
      avgMonthlySpend: zero,
      runwayMonths: null,
    ),
    incomeAverage: IncomeAverageSummary(
      avg3m: zero,
      avg6m: zero,
      variability: null,
    ),
    weekdayPattern: WeekdayPattern(weekendAvg: zero, weekdayAvg: zero),
    recurringCandidates: const [],
    recent: const [],
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Windows discovers local speech models without opening the microphone',
    (tester) async {
      await tester.runAsync(() async {
        final service = NativeSpeechService();
        final watch = Stopwatch()..start();
        final result = service.events.firstWhere(
          (event) => event.session == 900001,
        );
        await service.prepare(900001, SpeechLanguage.english);
        final event = await result.timeout(const Duration(seconds: 12));
        watch.stop();
        expect(event.text, isEmpty);
        expect([
          SpeechEventType.ready,
          SpeechEventType.error,
        ], contains(event.type));
        if (event.type == SpeechEventType.error) {
          expect([
            'speech_language_unavailable',
            'speech_offline_unavailable',
          ], contains(event.code));
        }
        // Only a synthetic session identifier and duration; no audio is captured.
        debugPrint(
          'Windows local speech preparation: ${watch.elapsedMilliseconds} ms (${event.type.name})',
        );
        await service.cancel(900001);
        await service.dispose();
      });
    },
    skip: defaultTargetPlatform != TargetPlatform.windows,
  );

  testWidgets(
    'the native Windows client completes the shared registration UI flow',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureCredentialStoreProvider.overrideWithValue(_MemoryStore()),
            authRepositoryProvider.overrideWithValue(
              _SuccessfulRegistrationRepository(),
            ),
            expensesRepositoryProvider.overrideWithValue(
              _EmptyExpensesRepository(),
            ),
            accountsRepositoryProvider.overrideWithValue(
              _EmptyAccountsRepository(),
            ),
            incomesRepositoryProvider.overrideWithValue(
              _EmptyIncomesRepository(),
            ),
          ],
          child: const FinanceApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('login-create-account-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('register-email-input')),
        'desktop@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('register-password-input')),
        'desktop-safe-password',
      );
      await tester.enterText(
        find.byKey(const Key('register-password-confirmation-input')),
        'desktop-safe-password',
      );
      await tester.tap(find.byKey(const Key('register-submit-button')));
      await tester.pumpAndSettle();

      expect(find.text('Bienvenido de nuevo'), findsOneWidget);
      expect(find.byKey(const Key('register-success-message')), findsOneWidget);
    },
    skip: defaultTargetPlatform != TargetPlatform.windows,
  );

  testWidgets('the native Windows client exposes a copyable safe failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureCredentialStoreProvider.overrideWithValue(_MemoryStore()),
          authRepositoryProvider.overrideWithValue(
            _UnavailableRegistrationRepository(),
          ),
          expensesRepositoryProvider.overrideWithValue(
            _EmptyExpensesRepository(),
          ),
          accountsRepositoryProvider.overrideWithValue(
            _EmptyAccountsRepository(),
          ),
          incomesRepositoryProvider.overrideWithValue(
            _EmptyIncomesRepository(),
          ),
        ],
        child: const FinanceApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login-create-account-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('register-email-input')),
      'desktop@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register-password-input')),
      'desktop-safe-password',
    );
    await tester.enterText(
      find.byKey(const Key('register-password-confirmation-input')),
      'desktop-safe-password',
    );
    await tester.tap(find.byKey(const Key('register-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Error code: network_unavailable'), findsOneWidget);
    expect(find.byKey(const Key('copy-error-details-button')), findsOneWidget);
  }, skip: defaultTargetPlatform != TargetPlatform.windows);

  testWidgets('the native Windows client protects Home and clears on Logout', (
    tester,
  ) async {
    final store = _MemoryStore();
    final accounts = _WindowsAccountsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureCredentialStoreProvider.overrideWithValue(store),
          authSessionRepositoryProvider.overrideWithValue(
            _SuccessfulSessionRepository(),
          ),
          accountsRepositoryProvider.overrideWithValue(accounts),
          expensesRepositoryProvider.overrideWithValue(
            _EmptyExpensesRepository(),
          ),
          incomesRepositoryProvider.overrideWithValue(
            _EmptyIncomesRepository(),
          ),
          budgetsRepositoryProvider.overrideWithValue(
            _EmptyBudgetsRepository(),
          ),
          categoriesRepositoryProvider.overrideWithValue(
            _EmptyCategoriesRepository(),
          ),
          incomeSourcesRepositoryProvider.overrideWithValue(
            _EmptyIncomeSourcesRepository(),
          ),
          dashboardSummaryProvider.overrideWith(
            (ref) async => _emptyDashboardSummary(),
          ),
        ],
        child: const FinanceApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-email-input')),
      'desktop@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-input')),
      'desktop-safe-password',
    );
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-hero')), findsOneWidget);
    expect(store.value, _SuccessfulSessionRepository.renewable);

    // Account management lives under Ajustes in the current mobile navigation.
    GoRouter.of(tester.element(find.byKey(const Key('dashboard-hero'))))
        .go('/settings');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-accounts-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('accounts-add-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('account-name-field')),
      'Windows cash',
    );
    await tester.enterText(
      find.byKey(const Key('account-opening-balance-field')),
      '50000,25',
    );
    await tester.ensureVisible(find.byKey(const Key('account-save-button')));
    await tester.tap(find.byKey(const Key('account-save-button')));
    await tester.pumpAndSettle();
    expect(find.text('Detalle de cuenta'), findsOneWidget);
    expect(find.text(r'$ 50.000,25 COP'), findsNWidgets(2));

    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-delete-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-confirm-delete-button')));
    await tester.pumpAndSettle();
    expect(find.text('Cuenta eliminada definitivamente.'), findsOneWidget);
    expect(accounts.accounts, isEmpty);

    await tester.tap(find.byTooltip('Volver al inicio'));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byKey(const Key('dashboard-hero'))))
        .go('/settings');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('logout-button')),
      200,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-logout-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-submit-button')), findsOneWidget);
    expect(store.value, isNull);
  }, skip: defaultTargetPlatform != TargetPlatform.windows);

  testWidgets(
    'Windows secure storage reads replaces and deletes a synthetic value',
    (tester) async {
      const syntheticKey = 'finance_ai.integration_test.renewable_session';
      const firstValue = 'ccccccccccccccccccccccccccccccccccccccccccc';
      const secondValue = 'ddddddddddddddddddddddddddddddddddddddddddd';
      const store = FlutterSecureCredentialStore(
        FlutterSecureStorage(),
        credentialKey: syntheticKey,
      );

      await store.delete();
      try {
        await store.replace(firstValue);
        expect(await store.read(), firstValue);
        await store.replace(secondValue);
        expect(await store.read(), secondValue);
      } finally {
        await store.delete();
      }
      expect(await store.read(), isNull);
    },
    skip: defaultTargetPlatform != TargetPlatform.windows,
  );
}
