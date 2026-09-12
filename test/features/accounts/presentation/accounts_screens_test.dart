import 'package:finance_ai/app.dart';
import 'package:finance_ai/core/router/app_router.dart';
import 'package:finance_ai/features/accounts/data/accounts_repository.dart';
import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const cop = CurrencySummary(
  id: 1,
  code: 'COP',
  name: 'Colombian Peso',
  decimals: 2,
);

Account account({
  int id = 11,
  String name = 'Credit card',
  bool isActive = true,
  bool currencyIsLocked = true,
}) => Account(
  id: id,
  name: name,
  type: AccountType.creditCard,
  currency: cop,
  openingBalance: MoneyAmount.parseApi('-100.00'),
  balance: MoneyAmount.parseApi('-250.75'),
  currencyIsLocked: currencyIsLocked,
  isActive: isActive,
  createdAt: DateTime.utc(2026, 9, 8),
  updatedAt: DateTime.utc(2026, 9, 8),
);

AccountListResult result(List<Account> accounts) => AccountListResult(
  accounts: accounts,
  suggestedCurrencyCode: 'COP',
  supportedCurrencies: const [cop],
  accountTypes: AccountType.values,
);

class WidgetAccountsRepository implements AccountsRepository {
  WidgetAccountsRepository() : current = result([account()]);

  AccountListResult current;
  AccountFailure? createFailure;
  AccountFailure? deleteFailure;
  AccountCreateCommand? createdCommand;
  final includeInactiveValues = <bool>[];

  @override
  Future<AccountListResult> list({required bool includeInactive}) async {
    includeInactiveValues.add(includeInactive);
    return result(
      includeInactive
          ? current.accounts
          : current.accounts.where((account) => account.isActive).toList(),
    );
  }

  @override
  Future<Account> get(int accountId) async =>
      current.accountById(accountId) ?? (throw StateError('missing fixture'));

  @override
  Future<Account> create(AccountCreateCommand command) async {
    createdCommand = command;
    if (createFailure case final failure?) {
      throw failure;
    }
    final created = account(
      id: 12,
      name: command.name,
      currencyIsLocked: false,
    );
    current = result([...current.accounts, created]);
    return created;
  }

  @override
  Future<Account> update(int accountId, AccountUpdateCommand command) async {
    final existing = current.accountById(accountId)!;
    final updated = Account(
      id: existing.id,
      name: command.name ?? existing.name,
      type: command.type ?? existing.type,
      currency: existing.currency,
      openingBalance: command.openingBalance ?? existing.openingBalance,
      balance: existing.balance,
      currencyIsLocked: existing.currencyIsLocked,
      isActive: existing.isActive,
      createdAt: existing.createdAt,
      updatedAt: existing.updatedAt,
    );
    _replace(updated);
    return updated;
  }

  @override
  Future<Account> setActive(int accountId, {required bool isActive}) async {
    final existing = current.accountById(accountId)!;
    final changed = Account(
      id: existing.id,
      name: existing.name,
      type: existing.type,
      currency: existing.currency,
      openingBalance: existing.openingBalance,
      balance: existing.balance,
      currencyIsLocked: existing.currencyIsLocked,
      isActive: isActive,
      createdAt: existing.createdAt,
      updatedAt: existing.updatedAt,
    );
    _replace(changed);
    return changed;
  }

  @override
  Future<void> deleteAccount(int accountId) async {
    if (deleteFailure case final failure?) {
      throw failure;
    }
    current = result(
      current.accounts.where((account) => account.id != accountId).toList(),
    );
  }

  void _replace(Account replacement) {
    current = result([
      for (final value in current.accounts)
        if (value.id == replacement.id) replacement else value,
    ]);
  }
}

Future<void> pumpAccountsApp(
  WidgetTester tester,
  WidgetAccountsRepository repository, {
  String initialLocation = '/accounts',
}) async {
  final router = createAppRouter(initialLocation: initialLocation);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [accountsRepositoryProvider.overrideWithValue(repository)],
      child: FinanceApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('list shows exact negative meaning, filter, and account detail', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repository = WidgetAccountsRepository();
    await pumpAccountsApp(tester, repository);

    expect(find.byKey(const Key('accounts-list')), findsOneWidget);
    expect(find.text('COP -250.75'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Negative balance COP -250.75')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('accounts-show-inactive')));
    await tester.pumpAndSettle();
    expect(repository.includeInactiveValues, [false, true]);

    await tester.tap(find.byKey(const Key('account-card-11')));
    await tester.pumpAndSettle();
    expect(find.text('Account details'), findsOneWidget);
    expect(
      find.text(
        'Currency is locked because this account has confirmed activity.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('account-edit-button')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('deactivation is confirmed as reversible history retention', (
    tester,
  ) async {
    final repository = WidgetAccountsRepository();
    await pumpAccountsApp(tester, repository, initialLocation: '/accounts/11');

    await tester.tap(find.byKey(const Key('account-deactivate-button')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This account will remain in your history but will no longer be available for new financial entries.',
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('account-confirm-deactivate-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Inactive'), findsOneWidget);
    expect(find.byKey(const Key('account-reactivate-button')), findsOneWidget);
    expect(repository.current.accountById(11)?.isActive, isFalse);
  });

  testWidgets('create form uses suggestions and submits exact signed money', (
    tester,
  ) async {
    final repository = WidgetAccountsRepository();
    await pumpAccountsApp(tester, repository, initialLocation: '/accounts/new');

    await tester.enterText(
      find.byKey(const Key('account-name-field')),
      'Nequi',
    );
    await tester.enterText(
      find.byKey(const Key('account-opening-balance-field')),
      '-1234,5',
    );
    await tester.ensureVisible(find.byKey(const Key('account-save-button')));
    await tester.tap(find.byKey(const Key('account-save-button')));
    await tester.pumpAndSettle();

    expect(repository.createdCommand?.name, 'Nequi');
    expect(repository.createdCommand?.type, AccountType.cash);
    expect(repository.createdCommand?.currencyCode, 'COP');
    expect(repository.createdCommand?.openingBalance.toApiString(), '-1234.50');
    expect(find.text('Account details'), findsOneWidget);
  });

  testWidgets('permanent deletion requires confirmation and returns to list', (
    tester,
  ) async {
    final repository = WidgetAccountsRepository();
    await pumpAccountsApp(tester, repository, initialLocation: '/accounts/11');

    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-delete-button')));
    await tester.pumpAndSettle();
    expect(find.text('Delete this account permanently?'), findsOneWidget);
    expect(
      find.textContaining('Accounts with activity must be deactivated'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('account-confirm-delete-button')));
    await tester.pumpAndSettle();

    expect(find.text('Accounts'), findsOneWidget);
    expect(repository.current.accountById(11), isNull);
    expect(find.text('Account permanently deleted.'), findsOneWidget);
  });

  testWidgets('blocked deletion stays on detail with copyable safe failure', (
    tester,
  ) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText =
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
    final repository = WidgetAccountsRepository()
      ..deleteFailure = const AccountFailure(
        code: 'account_delete_blocked',
        userMessage: 'This account has financial activity. Deactivate it to preserve its history.',
        correlationId: 'widget-blocked-delete',
        technicalReason: 'http_409',
      );
    await pumpAccountsApp(tester, repository, initialLocation: '/accounts/11');

    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-delete-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-confirm-delete-button')));
    await tester.pumpAndSettle();

    expect(find.text('Error code: account_delete_blocked'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('copy-error-details-button')));
    await tester.pump();
    expect(copiedText, contains('widget-blocked-delete'));
    expect(copiedText, isNot(contains('Credit card')));
    expect(copiedText, isNot(contains('-250.75')));
  });

  testWidgets('locked edit keeps currency disabled', (tester) async {
    final repository = WidgetAccountsRepository();
    await pumpAccountsApp(
      tester,
      repository,
      initialLocation: '/accounts/11/edit',
    );

    final currency = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('account-currency-field')),
    );
    expect(currency.onChanged, isNull);
    expect(
      find.text('Currency is locked after confirmed account activity.'),
      findsOneWidget,
    );
  });

  testWidgets('copied account failure omits name and amount', (tester) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText =
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
    final repository = WidgetAccountsRepository()
      ..createFailure = const AccountFailure(
        code: 'account_name_conflict',
        userMessage: 'Choose a different name for this active account.',
        fieldErrors: {
          'name': ['An active account already uses this name.'],
        },
        correlationId: 'widget-account-conflict',
        technicalReason: 'http_409',
      );
    await pumpAccountsApp(tester, repository, initialLocation: '/accounts/new');

    await tester.enterText(
      find.byKey(const Key('account-name-field')),
      'Private platinum account',
    );
    await tester.enterText(
      find.byKey(const Key('account-opening-balance-field')),
      '987654.32',
    );
    await tester.ensureVisible(find.byKey(const Key('account-save-button')));
    await tester.tap(find.byKey(const Key('account-save-button')));
    await tester.pumpAndSettle();
    expect(find.text('Error code: account_name_conflict'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('copy-error-details-button')),
    );
    await tester.tap(find.byKey(const Key('copy-error-details-button')));
    await tester.pump();
    expect(copiedText, isNot(contains('Private platinum account')));
    expect(copiedText, isNot(contains('987654.32')));
    expect(copiedText, contains('widget-account-conflict'));
  });
}
