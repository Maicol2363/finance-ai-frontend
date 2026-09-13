import 'dart:async';

import 'package:finance_ai/features/accounts/application/accounts_controller.dart';
import 'package:finance_ai/features/accounts/application/accounts_state.dart';
import 'package:finance_ai/features/accounts/data/accounts_repository.dart';
import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const cop = CurrencySummary(
  id: 1,
  code: 'COP',
  name: 'Colombian Peso',
  decimals: 2,
);

Account account({
  int id = 11,
  String name = 'Daily cash',
  bool isActive = true,
  bool currencyIsLocked = false,
}) => Account(
  id: id,
  name: name,
  type: AccountType.cash,
  currency: cop,
  openingBalance: MoneyAmount.parseApi('100.00'),
  balance: MoneyAmount.parseApi('75.00'),
  currencyIsLocked: currencyIsLocked,
  isActive: isActive,
  createdAt: DateTime.utc(2026, 9, 8),
  updatedAt: DateTime.utc(2026, 9, 8),
);

AccountListResult result([List<Account>? accounts]) => AccountListResult(
  accounts: accounts ?? [account()],
  suggestedCurrencyCode: 'COP',
  supportedCurrencies: const [cop],
  accountTypes: AccountType.values,
);

class FakeAccountsRepository implements AccountsRepository {
  AccountListResult listResult = result();
  Object? listFailure;
  Object? createFailure;
  Object? deleteFailure;
  Completer<Account>? pendingCreate;
  Completer<void>? pendingDelete;
  bool deleteRemovesBeforeFailure = false;
  int listCalls = 0;
  int createCalls = 0;
  int deleteCalls = 0;
  final includeInactiveValues = <bool>[];

  @override
  Future<AccountListResult> list({required bool includeInactive}) async {
    listCalls += 1;
    includeInactiveValues.add(includeInactive);
    if (listFailure case final failure?) {
      throw failure;
    }
    return listResult;
  }

  @override
  Future<Account> get(int accountId) async =>
      listResult.accountById(accountId) ?? account(id: accountId);

  @override
  Future<Account> create(AccountCreateCommand command) async {
    createCalls += 1;
    if (createFailure case final failure?) {
      throw failure;
    }
    if (pendingCreate case final pending?) {
      return pending.future;
    }
    final created = account(id: 12, name: command.name);
    listResult = result([...listResult.accounts, created]);
    return created;
  }

  @override
  Future<Account> update(int accountId, AccountUpdateCommand command) async {
    final updated = account(id: accountId, name: command.name ?? 'Daily cash');
    listResult = result([
      for (final value in listResult.accounts)
        if (value.id == accountId) updated else value,
    ]);
    return updated;
  }

  @override
  Future<Account> setActive(int accountId, {required bool isActive}) async {
    final changed = account(id: accountId, isActive: isActive);
    listResult = result([
      for (final value in listResult.accounts)
        if (value.id == accountId) changed else value,
    ]);
    return changed;
  }

  @override
  Future<void> deleteAccount(int accountId) async {
    deleteCalls += 1;
    if (deleteRemovesBeforeFailure) {
      listResult = result(
        listResult.accounts
            .where((account) => account.id != accountId)
            .toList(),
      );
    }
    if (deleteFailure case final failure?) {
      throw failure;
    }
    if (pendingDelete case final pending?) {
      await pending.future;
    }
    listResult = result(
      listResult.accounts.where((account) => account.id != accountId).toList(),
    );
  }
}

ProviderContainer containerFor(FakeAccountsRepository repository) {
  return ProviderContainer(
    overrides: [accountsRepositoryProvider.overrideWithValue(repository)],
  );
}

void main() {
  test('loads active by default and reloads with inactive filter', () async {
    final repository = FakeAccountsRepository();
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(accountsControllerProvider.notifier);

    await controller.load();
    await controller.setIncludeInactive(true);

    final state = container.read(accountsControllerProvider);
    expect(state.listStatus, AccountsLoadStatus.ready);
    expect(state.result?.accounts.single.id, 11);
    expect(repository.includeInactiveValues, [false, true]);
    expect(state.includeInactive, isTrue);
  });

  test('client validation is exact and diagnostics omit form values', () async {
    final repository = FakeAccountsRepository();
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(accountsControllerProvider.notifier);
    await controller.load();

    final outcome = await controller.create(
      name: 'Private account name that should stay only in the form',
      type: AccountType.cash,
      currencyCode: 'COP',
      openingBalanceInput: '123.456',
    );

    final state = container.read(accountsControllerProvider);
    expect(outcome, AccountMutationOutcome.invalid);
    expect(state.fieldErrors, contains('opening_balance'));
    expect(state.mutationDiagnostic?.code, 'account_invalid');
    expect(
      state.mutationDiagnostic?.clipboardText,
      isNot(contains('Private account name')),
    );
    expect(state.mutationDiagnostic?.clipboardText, isNot(contains('123.456')));
    expect(repository.createCalls, 0);
  });

  test(
    'repeated save is ignored and success refreshes canonical state',
    () async {
      final pending = Completer<Account>();
      final repository = FakeAccountsRepository()..pendingCreate = pending;
      final container = containerFor(repository);
      addTearDown(container.dispose);
      final controller = container.read(accountsControllerProvider.notifier);
      await controller.load();

      final first = controller.create(
        name: 'Wallet',
        type: AccountType.digitalWallet,
        currencyCode: 'COP',
        openingBalanceInput: '25,5',
      );
      final repeated = await controller.create(
        name: 'Wallet',
        type: AccountType.digitalWallet,
        currencyCode: 'COP',
        openingBalanceInput: '25,5',
      );
      final created = account(id: 12, name: 'Wallet');
      repository.listResult = result([account(), created]);
      pending.complete(created);

      expect(repeated, AccountMutationOutcome.ignored);
      expect(await first, AccountMutationOutcome.success);
      expect(repository.createCalls, 1);
      expect(repository.listCalls, 2);
      expect(
        container.read(accountsControllerProvider).lastMutationAccount?.id,
        12,
      );
    },
  );

  test(
    'repeated delete is ignored and success clears detail and list',
    () async {
      final pending = Completer<void>();
      final repository = FakeAccountsRepository()..pendingDelete = pending;
      final container = containerFor(repository);
      addTearDown(container.dispose);
      final controller = container.read(accountsControllerProvider.notifier);
      await controller.load(includeInactive: true);
      await controller.loadDetail(11);

      final first = controller.deleteAccount(11);
      final repeated = await controller.deleteAccount(11);
      pending.complete();

      expect(repeated, AccountMutationOutcome.ignored);
      expect(await first, AccountMutationOutcome.success);
      final state = container.read(accountsControllerProvider);
      expect(repository.deleteCalls, 1);
      expect(state.detailAccount, isNull);
      expect(state.detailAccountId, isNull);
      expect(state.result?.accountById(11), isNull);
      expect(state.mutationStatus, AccountMutationStatus.idle);
    },
  );

  test('blocked delete preserves detail and creates safe diagnostic', () async {
    final repository = FakeAccountsRepository()
      ..deleteFailure = const AccountFailure(
        code: 'account_delete_blocked',
        userMessage: 'This account has financial activity. Deactivate it to preserve its history.',
        correlationId: 'blocked-delete',
        technicalReason: 'http_409',
      );
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(accountsControllerProvider.notifier);
    await controller.load();
    await controller.loadDetail(11);

    final outcome = await controller.deleteAccount(11);

    final state = container.read(accountsControllerProvider);
    expect(outcome, AccountMutationOutcome.failure);
    expect(state.detailAccount?.id, 11);
    expect(state.mutationDiagnostic?.code, 'account_delete_blocked');
    expect(state.mutationDiagnostic?.operation, 'delete_account');
    expect(
      state.mutationDiagnostic?.clipboardText,
      isNot(contains('Daily cash')),
    );
    expect(state.mutationDiagnostic?.clipboardText, isNot(contains('75.00')));
  });

  test(
    'uncertain delete resolves as success when authoritative list omits it',
    () async {
      final repository = FakeAccountsRepository()
        ..deleteRemovesBeforeFailure = true
        ..deleteFailure = const AccountFailure(
          code: 'network_unavailable',
          userMessage: 'Refresh accounts before trying again.',
          correlationId: 'uncertain-delete',
          technicalReason: 'request_timeout',
          isRetryable: true,
          isMutationOutcomeUncertain: true,
        );
      final container = containerFor(repository);
      addTearDown(container.dispose);
      final controller = container.read(accountsControllerProvider.notifier);
      await controller.load();
      await controller.loadDetail(11);

      final outcome = await controller.deleteAccount(11);

      expect(outcome, AccountMutationOutcome.success);
      final state = container.read(accountsControllerProvider);
      expect(state.detailAccount, isNull);
      expect(state.result?.accountById(11), isNull);
      expect(state.mutationDiagnostic, isNull);
    },
  );

  test('lifecycle mutation replaces detail and refreshes list', () async {
    final repository = FakeAccountsRepository();
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(accountsControllerProvider.notifier);
    await controller.load(includeInactive: true);
    await controller.loadDetail(11);

    final outcome = await controller.setActive(11, isActive: false);

    final state = container.read(accountsControllerProvider);
    expect(outcome, AccountMutationOutcome.success);
    expect(state.detailAccount?.isActive, isFalse);
    expect(state.result?.accountById(11)?.isActive, isFalse);
    expect(state.mutationStatus, AccountMutationStatus.idle);
  });

  test(
    'uncertain mutation refresh failure blocks retry until resolution',
    () async {
      final repository = FakeAccountsRepository()
        ..createFailure = const AccountFailure(
          code: 'network_unavailable',
          userMessage: 'Refresh accounts before trying again.',
          correlationId: 'uncertain-create',
          technicalReason: 'request_timeout',
          isRetryable: true,
          isMutationOutcomeUncertain: true,
        )
        ..listFailure = const AccountFailure(
          code: 'network_unavailable',
          userMessage: 'Could not refresh.',
        );
      final container = containerFor(repository);
      addTearDown(container.dispose);
      final controller = container.read(accountsControllerProvider.notifier);

      final outcome = await controller.create(
        name: 'Wallet',
        type: AccountType.digitalWallet,
        currencyCode: 'COP',
        openingBalanceInput: '0',
      );

      expect(outcome, AccountMutationOutcome.failure);
      expect(
        container.read(accountsControllerProvider).mutationStatus,
        AccountMutationStatus.reviewRequired,
      );
      expect(
        await controller.create(
          name: 'Wallet',
          type: AccountType.digitalWallet,
          currencyCode: 'COP',
          openingBalanceInput: '0',
        ),
        AccountMutationOutcome.ignored,
      );

      repository.listFailure = null;
      await controller.resolveUncertainMutation();
      expect(
        container.read(accountsControllerProvider).mutationStatus,
        AccountMutationStatus.idle,
      );
    },
  );
}
