import 'package:finance_ai/app.dart';
import 'package:finance_ai/features/accounts/data/accounts_repository.dart';
import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/auth/register/data/auth_repository.dart';
import 'package:finance_ai/features/auth/register/domain/registration_models.dart';
import 'package:finance_ai/features/auth/session/data/auth_session_repository.dart';
import 'package:finance_ai/features/auth/session/data/secure_credential_store.dart';
import 'package:finance_ai/features/auth/session/domain/session_models.dart';
import 'package:finance_ai/features/expenses/data/expenses_repository.dart';
import 'package:finance_ai/features/expenses/domain/expense_models.dart';
import 'package:finance_ai/features/expenses/domain/history_models.dart';
import 'package:finance_ai/features/incomes/data/incomes_repository.dart';
import 'package:finance_ai/features/incomes/domain/income_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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

    expect(find.byKey(const Key('home-title')), findsOneWidget);
    expect(store.value, _SuccessfulSessionRepository.renewable);

    await tester.tap(find.byKey(const Key('home-accounts-button')));
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
    expect(find.text('Account details'), findsOneWidget);
    expect(find.text('COP 50000.25'), findsNWidgets(2));

    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-delete-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-confirm-delete-button')));
    await tester.pumpAndSettle();
    expect(find.text('Account permanently deleted.'), findsOneWidget);
    expect(accounts.accounts, isEmpty);

    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to home'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.byKey(const Key('home-title')), findsNothing);
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
