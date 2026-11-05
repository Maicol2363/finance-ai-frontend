import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/error_diagnostic.dart';
import '../../../core/state/financial_data_revision.dart';
import '../../auth/session/domain/session_models.dart';
import '../data/accounts_repository.dart';
import '../domain/account_models.dart';
import 'accounts_state.dart';

final accountsControllerProvider =
    NotifierProvider<AccountsController, AccountsState>(AccountsController.new);

class AccountsController extends Notifier<AccountsState> {
  bool _listReloadRequested = false;
  int? _detailReloadRequestedFor;

  @override
  AccountsState build() {
    ref.listen(financialMovementRevisionProvider, (_, _) {
      if (state.listStatus != AccountsLoadStatus.initial) {
        unawaited(load());
      }
    });
    return const AccountsState();
  }

  Future<void> load({bool? includeInactive}) async {
    final targetFilter = includeInactive ?? state.includeInactive;
    if (state.listStatus == AccountsLoadStatus.loading) {
      _listReloadRequested = true;
      if (targetFilter != state.includeInactive) {
        state = state.copyWith(includeInactive: targetFilter);
      }
      return;
    }
    state = state.copyWith(
      listStatus: AccountsLoadStatus.loading,
      includeInactive: targetFilter,
      clearListDiagnostic: true,
    );
    try {
      final result = await ref
          .read(accountsRepositoryProvider)
          .list(includeInactive: targetFilter);
      state = state.copyWith(
        listStatus: AccountsLoadStatus.ready,
        result: result,
        clearListDiagnostic: true,
      );
      final detailId = state.detailAccountId;
      final refreshedDetail = detailId == null
          ? null
          : result.accountById(detailId);
      if (refreshedDetail != null) {
        state = state.copyWith(
          detailStatus: AccountDetailStatus.ready,
          detailAccount: refreshedDetail,
          clearDetailDiagnostic: true,
        );
      }
    } on InvalidSessionFailure catch (failure) {
      state = state.copyWith(
        listStatus: AccountsLoadStatus.failure,
        listDiagnostic: _sessionDiagnostic(failure, operation: 'load_accounts'),
      );
    } on AccountFailure catch (failure) {
      state = state.copyWith(
        listStatus: AccountsLoadStatus.failure,
        listDiagnostic: _diagnosticFor(failure, operation: 'load_accounts'),
      );
    } on Object {
      state = state.copyWith(
        listStatus: AccountsLoadStatus.failure,
        listDiagnostic: _unexpected(operation: 'load_accounts'),
      );
    } finally {
      if (_listReloadRequested) {
        _listReloadRequested = false;
        await load(includeInactive: state.includeInactive);
      }
    }
  }

  Future<void> setIncludeInactive(bool value) => load(includeInactive: value);

  Future<void> loadDetail(int accountId) async {
    if (state.detailStatus == AccountDetailStatus.loading &&
        state.detailAccountId == accountId) {
      _detailReloadRequestedFor = accountId;
      return;
    }
    final cached = state.result?.accountById(accountId);
    state = state.copyWith(
      detailStatus: AccountDetailStatus.loading,
      detailAccountId: accountId,
      detailAccount: cached,
      clearDetailAccount: cached == null,
      clearDetailDiagnostic: true,
    );
    try {
      final account = await ref.read(accountsRepositoryProvider).get(accountId);
      if (state.detailAccountId != accountId) {
        return;
      }
      state = state.copyWith(
        detailStatus: AccountDetailStatus.ready,
        detailAccount: account,
        result: _replaceInResult(state.result, account),
        clearDetailDiagnostic: true,
      );
    } on InvalidSessionFailure catch (failure) {
      if (state.detailAccountId == accountId) {
        state = state.copyWith(
          detailStatus: AccountDetailStatus.failure,
          detailDiagnostic: _sessionDiagnostic(
            failure,
            operation: 'load_account_detail',
          ),
        );
      }
    } on AccountFailure catch (failure) {
      if (state.detailAccountId == accountId) {
        state = state.copyWith(
          detailStatus: AccountDetailStatus.failure,
          detailDiagnostic: _diagnosticFor(
            failure,
            operation: 'load_account_detail',
          ),
        );
      }
    } on Object {
      if (state.detailAccountId == accountId) {
        state = state.copyWith(
          detailStatus: AccountDetailStatus.failure,
          detailDiagnostic: _unexpected(operation: 'load_account_detail'),
        );
      }
    } finally {
      if (_detailReloadRequestedFor == accountId) {
        _detailReloadRequestedFor = null;
        if (state.detailAccountId == accountId) {
          await loadDetail(accountId);
        }
      }
    }
  }

  Future<AccountMutationOutcome> create({
    required String name,
    required AccountType? type,
    required String? currencyCode,
    required String openingBalanceInput,
  }) async {
    if (state.mutationStatus != AccountMutationStatus.idle) {
      return AccountMutationOutcome.ignored;
    }
    final validated = _validateForm(
      name: name,
      type: type,
      currencyCode: currencyCode,
      openingBalanceInput: openingBalanceInput,
    );
    if (validated == null) {
      return AccountMutationOutcome.invalid;
    }
    state = state.copyWith(
      mutationStatus: AccountMutationStatus.saving,
      clearLastMutationAccount: true,
      fieldErrors: const {},
      clearMutationDiagnostic: true,
    );
    try {
      final account = await ref
          .read(accountsRepositoryProvider)
          .create(
            AccountCreateCommand(
              name: validated.name,
              type: validated.type,
              currencyCode: validated.currencyCode,
              openingBalance: validated.openingBalance,
            ),
          );
      await _acceptMutation(account);
      return AccountMutationOutcome.success;
    } on InvalidSessionFailure catch (failure) {
      _rejectSessionMutation(failure, operation: 'create_account');
    } on AccountFailure catch (failure) {
      await _rejectMutation(failure, operation: 'create_account');
    } on Object {
      _rejectUnexpectedMutation(operation: 'create_account');
    }
    return AccountMutationOutcome.failure;
  }

  Future<AccountMutationOutcome> update({
    required int accountId,
    required String name,
    required AccountType? type,
    required String? currencyCode,
    required String openingBalanceInput,
  }) async {
    if (state.mutationStatus != AccountMutationStatus.idle) {
      return AccountMutationOutcome.ignored;
    }
    final validated = _validateForm(
      name: name,
      type: type,
      currencyCode: currencyCode,
      openingBalanceInput: openingBalanceInput,
    );
    if (validated == null) {
      return AccountMutationOutcome.invalid;
    }
    state = state.copyWith(
      mutationStatus: AccountMutationStatus.saving,
      clearLastMutationAccount: true,
      fieldErrors: const {},
      clearMutationDiagnostic: true,
    );
    try {
      final account = await ref
          .read(accountsRepositoryProvider)
          .update(
            accountId,
            AccountUpdateCommand(
              name: validated.name,
              type: validated.type,
              currencyCode: validated.currencyCode,
              openingBalance: validated.openingBalance,
            ),
          );
      await _acceptMutation(account);
      return AccountMutationOutcome.success;
    } on InvalidSessionFailure catch (failure) {
      _rejectSessionMutation(failure, operation: 'update_account');
    } on AccountFailure catch (failure) {
      await _rejectMutation(failure, operation: 'update_account');
    } on Object {
      _rejectUnexpectedMutation(operation: 'update_account');
    }
    return AccountMutationOutcome.failure;
  }

  Future<AccountMutationOutcome> setActive(
    int accountId, {
    required bool isActive,
  }) async {
    if (state.mutationStatus != AccountMutationStatus.idle) {
      return AccountMutationOutcome.ignored;
    }
    state = state.copyWith(
      mutationStatus: AccountMutationStatus.saving,
      clearLastMutationAccount: true,
      fieldErrors: const {},
      clearMutationDiagnostic: true,
    );
    final operation = isActive ? 'reactivate_account' : 'deactivate_account';
    try {
      final account = await ref
          .read(accountsRepositoryProvider)
          .setActive(accountId, isActive: isActive);
      await _acceptMutation(account);
      return AccountMutationOutcome.success;
    } on InvalidSessionFailure catch (failure) {
      _rejectSessionMutation(failure, operation: operation);
    } on AccountFailure catch (failure) {
      await _rejectMutation(failure, operation: operation);
    } on Object {
      _rejectUnexpectedMutation(operation: operation);
    }
    return AccountMutationOutcome.failure;
  }

  Future<AccountMutationOutcome> deleteAccount(int accountId) async {
    if (state.mutationStatus != AccountMutationStatus.idle) {
      return AccountMutationOutcome.ignored;
    }
    state = state.copyWith(
      mutationStatus: AccountMutationStatus.saving,
      clearLastMutationAccount: true,
      fieldErrors: const {},
      clearMutationDiagnostic: true,
    );
    try {
      await ref.read(accountsRepositoryProvider).deleteAccount(accountId);
      await _acceptDeletion(accountId);
      return AccountMutationOutcome.success;
    } on InvalidSessionFailure catch (failure) {
      _rejectSessionMutation(failure, operation: 'delete_account');
    } on AccountFailure catch (failure) {
      final diagnostic = _diagnosticFor(failure, operation: 'delete_account');
      if (failure.isMutationOutcomeUncertain) {
        final deleted = await _refreshDeletionResolution(accountId, diagnostic);
        return deleted
            ? AccountMutationOutcome.success
            : AccountMutationOutcome.failure;
      }
      await _rejectMutation(failure, operation: 'delete_account');
    } on Object {
      _rejectUnexpectedMutation(operation: 'delete_account');
    }
    return AccountMutationOutcome.failure;
  }

  Future<void> resolveUncertainMutation() async {
    if (!state.requiresMutationReview) {
      return;
    }
    final diagnostic = state.mutationDiagnostic;
    final deletionId = state.detailAccountId;
    if (diagnostic?.operation == 'delete_account' && deletionId != null) {
      state = state.copyWith(mutationStatus: AccountMutationStatus.saving);
      await _refreshDeletionResolution(deletionId, diagnostic!);
      return;
    }
    state = state.copyWith(mutationStatus: AccountMutationStatus.saving);
    if (await _refreshCanonicalList()) {
      state = state.copyWith(
        mutationStatus: AccountMutationStatus.idle,
        clearMutationDiagnostic: true,
      );
    } else {
      state = state.copyWith(
        mutationStatus: AccountMutationStatus.reviewRequired,
      );
    }
  }

  void clearFieldError(String field) {
    state = state.withoutFieldError(field);
  }

  void clearMutationFeedback() {
    if (state.isSaving) {
      return;
    }
    state = state.copyWith(
      mutationStatus: AccountMutationStatus.idle,
      clearLastMutationAccount: true,
      fieldErrors: const {},
      clearMutationDiagnostic: true,
    );
  }

  _ValidatedAccountForm? _validateForm({
    required String name,
    required AccountType? type,
    required String? currencyCode,
    required String openingBalanceInput,
  }) {
    final errors = <String, List<String>>{};
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      errors['name'] = ['Account name is required.'];
    } else if (normalizedName.runes.length > 100) {
      errors['name'] = ['Account name must be 100 characters or fewer.'];
    }
    final options = state.result;
    if (type == null ||
        (options != null && !options.accountTypes.contains(type))) {
      errors['type'] = ['Select an account type.'];
    }
    final normalizedCurrency = currencyCode?.trim().toUpperCase();
    if (normalizedCurrency == null ||
        normalizedCurrency.isEmpty ||
        (options != null &&
            !options.supportedCurrencies.any(
              (currency) => currency.code == normalizedCurrency,
            ))) {
      errors['currency_code'] = ['Select a supported currency.'];
    }
    final openingBalance = MoneyAmount.tryParseUserInput(openingBalanceInput);
    if (openingBalance == null) {
      errors['opening_balance'] = [
        'Enter an amount with no more than two decimal places.',
      ];
    }
    if (errors.isNotEmpty) {
      state = state.copyWith(
        mutationStatus: AccountMutationStatus.idle,
        fieldErrors: Map.unmodifiable(errors),
        mutationDiagnostic: ErrorDiagnostic.capture(
          code: 'account_invalid',
          operation: 'validate_account',
          userMessage: 'Please correct the highlighted fields.',
          technicalReason: 'client_validation',
        ),
      );
      return null;
    }
    return _ValidatedAccountForm(
      name: normalizedName,
      type: type!,
      currencyCode: normalizedCurrency!,
      openingBalance: openingBalance!,
    );
  }

  Future<void> _acceptMutation(Account account) async {
    state = state.copyWith(
      result: _replaceInResult(state.result, account),
      detailStatus: state.detailAccountId == account.id
          ? AccountDetailStatus.ready
          : state.detailStatus,
      detailAccount: state.detailAccountId == account.id ? account : null,
      mutationStatus: AccountMutationStatus.saving,
      lastMutationAccount: account,
      fieldErrors: const {},
      clearMutationDiagnostic: true,
    );
    await _refreshCanonicalList();
    state = state.copyWith(
      mutationStatus: AccountMutationStatus.idle,
      clearMutationDiagnostic: true,
    );
  }

  Future<void> _acceptDeletion(int accountId) async {
    state = state.copyWith(
      result: _removeFromResult(state.result, accountId),
      detailStatus: AccountDetailStatus.initial,
      clearDetailAccountId: true,
      clearDetailAccount: true,
      clearDetailDiagnostic: true,
      mutationStatus: AccountMutationStatus.saving,
      clearLastMutationAccount: true,
      fieldErrors: const {},
      clearMutationDiagnostic: true,
    );
    await _refreshCanonicalList();
    state = state.copyWith(
      mutationStatus: AccountMutationStatus.idle,
      clearMutationDiagnostic: true,
    );
  }

  Future<bool> _refreshDeletionResolution(
    int accountId,
    ErrorDiagnostic diagnostic,
  ) async {
    try {
      final allAccounts = await ref
          .read(accountsRepositoryProvider)
          .list(includeInactive: true);
      final stillExists = allAccounts.accountById(accountId) != null;
      final visibleResult = state.includeInactive
          ? allAccounts
          : AccountListResult(
              accounts: List.unmodifiable(
                allAccounts.accounts.where((account) => account.isActive),
              ),
              suggestedCurrencyCode: allAccounts.suggestedCurrencyCode,
              supportedCurrencies: allAccounts.supportedCurrencies,
              accountTypes: allAccounts.accountTypes,
            );
      state = state.copyWith(
        listStatus: AccountsLoadStatus.ready,
        result: visibleResult,
        detailStatus: stillExists
            ? state.detailStatus
            : AccountDetailStatus.initial,
        clearDetailAccountId: !stillExists,
        clearDetailAccount: !stillExists,
        clearDetailDiagnostic: !stillExists,
        mutationStatus: AccountMutationStatus.idle,
        mutationDiagnostic: stillExists ? diagnostic : null,
        clearMutationDiagnostic: !stillExists,
        clearListDiagnostic: true,
      );
      return !stillExists;
    } on Object {
      state = state.copyWith(
        mutationStatus: AccountMutationStatus.reviewRequired,
        mutationDiagnostic: diagnostic,
      );
      return false;
    }
  }

  Future<void> _rejectMutation(
    AccountFailure failure, {
    required String operation,
  }) async {
    var refreshed = true;
    if (failure.isMutationOutcomeUncertain) {
      refreshed = await _refreshCanonicalList();
    }
    state = state.copyWith(
      mutationStatus: failure.isMutationOutcomeUncertain && !refreshed
          ? AccountMutationStatus.reviewRequired
          : AccountMutationStatus.idle,
      mutationDiagnostic: _diagnosticFor(failure, operation: operation),
      fieldErrors: Map.unmodifiable(failure.fieldErrors),
    );
  }

  void _rejectSessionMutation(
    InvalidSessionFailure failure, {
    required String operation,
  }) {
    state = state.copyWith(
      mutationStatus: AccountMutationStatus.idle,
      mutationDiagnostic: _sessionDiagnostic(failure, operation: operation),
      fieldErrors: const {},
    );
  }

  void _rejectUnexpectedMutation({required String operation}) {
    state = state.copyWith(
      mutationStatus: AccountMutationStatus.idle,
      mutationDiagnostic: _unexpected(operation: operation),
      fieldErrors: const {},
    );
  }

  Future<bool> _refreshCanonicalList() async {
    try {
      final result = await ref
          .read(accountsRepositoryProvider)
          .list(includeInactive: state.includeInactive);
      state = state.copyWith(
        listStatus: AccountsLoadStatus.ready,
        result: result,
        clearListDiagnostic: true,
      );
      final detailId = state.detailAccountId;
      if (detailId != null) {
        final refreshedDetail = result.accountById(detailId);
        if (refreshedDetail != null) {
          state = state.copyWith(
            detailStatus: AccountDetailStatus.ready,
            detailAccount: refreshedDetail,
            clearDetailDiagnostic: true,
          );
        }
      }
      return true;
    } on Object {
      return false;
    }
  }

  AccountListResult? _replaceInResult(
    AccountListResult? result,
    Account account,
  ) {
    if (result == null) {
      return null;
    }
    final accounts = [...result.accounts];
    final index = accounts.indexWhere((item) => item.id == account.id);
    if (!account.isActive && !state.includeInactive) {
      if (index >= 0) {
        accounts.removeAt(index);
      }
    } else if (index >= 0) {
      accounts[index] = account;
    } else {
      accounts.add(account);
    }
    return AccountListResult(
      accounts: List.unmodifiable(accounts),
      suggestedCurrencyCode: result.suggestedCurrencyCode,
      supportedCurrencies: result.supportedCurrencies,
      accountTypes: result.accountTypes,
    );
  }

  AccountListResult? _removeFromResult(
    AccountListResult? result,
    int accountId,
  ) {
    if (result == null) {
      return null;
    }
    return AccountListResult(
      accounts: List.unmodifiable(
        result.accounts.where((account) => account.id != accountId),
      ),
      suggestedCurrencyCode: result.suggestedCurrencyCode,
      supportedCurrencies: result.supportedCurrencies,
      accountTypes: result.accountTypes,
    );
  }

  ErrorDiagnostic _diagnosticFor(
    AccountFailure failure, {
    required String operation,
  }) {
    return ErrorDiagnostic.capture(
      code: failure.code,
      operation: operation,
      userMessage: failure.userMessage,
      correlationId: failure.correlationId,
      technicalReason: failure.technicalReason,
    );
  }

  ErrorDiagnostic _sessionDiagnostic(
    InvalidSessionFailure failure, {
    required String operation,
  }) {
    return ErrorDiagnostic.capture(
      code: failure.code,
      operation: operation,
      userMessage: failure.userMessage,
      correlationId: failure.correlationId,
      technicalReason: failure.technicalReason,
    );
  }

  ErrorDiagnostic _unexpected({required String operation}) {
    return ErrorDiagnostic.capture(
      code: 'unexpected_client_error',
      operation: operation,
      userMessage: 'The operation could not be completed. Please try again.',
      technicalReason: 'unclassified_client_failure',
    );
  }
}

class _ValidatedAccountForm {
  const _ValidatedAccountForm({
    required this.name,
    required this.type,
    required this.currencyCode,
    required this.openingBalance,
  });

  final String name;
  final AccountType type;
  final String currencyCode;
  final MoneyAmount openingBalance;
}
