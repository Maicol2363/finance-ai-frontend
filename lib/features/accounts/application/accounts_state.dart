import '../../../core/diagnostics/error_diagnostic.dart';
import '../domain/account_models.dart';

enum AccountsLoadStatus { initial, loading, ready, failure }

enum AccountDetailStatus { initial, loading, ready, failure }

enum AccountMutationStatus { idle, saving, reviewRequired }

enum AccountMutationOutcome { invalid, failure, success, ignored }

class AccountsState {
  const AccountsState({
    this.listStatus = AccountsLoadStatus.initial,
    this.result,
    this.includeInactive = false,
    this.listDiagnostic,
    this.detailStatus = AccountDetailStatus.initial,
    this.detailAccountId,
    this.detailAccount,
    this.detailDiagnostic,
    this.mutationStatus = AccountMutationStatus.idle,
    this.lastMutationAccount,
    this.mutationDiagnostic,
    this.fieldErrors = const {},
  });

  final AccountsLoadStatus listStatus;
  final AccountListResult? result;
  final bool includeInactive;
  final ErrorDiagnostic? listDiagnostic;
  final AccountDetailStatus detailStatus;
  final int? detailAccountId;
  final Account? detailAccount;
  final ErrorDiagnostic? detailDiagnostic;
  final AccountMutationStatus mutationStatus;
  final Account? lastMutationAccount;
  final ErrorDiagnostic? mutationDiagnostic;
  final Map<String, List<String>> fieldErrors;

  bool get isSaving => mutationStatus == AccountMutationStatus.saving;

  bool get requiresMutationReview =>
      mutationStatus == AccountMutationStatus.reviewRequired;

  AccountsState copyWith({
    AccountsLoadStatus? listStatus,
    AccountListResult? result,
    bool clearResult = false,
    bool? includeInactive,
    ErrorDiagnostic? listDiagnostic,
    bool clearListDiagnostic = false,
    AccountDetailStatus? detailStatus,
    int? detailAccountId,
    bool clearDetailAccountId = false,
    Account? detailAccount,
    bool clearDetailAccount = false,
    ErrorDiagnostic? detailDiagnostic,
    bool clearDetailDiagnostic = false,
    AccountMutationStatus? mutationStatus,
    Account? lastMutationAccount,
    bool clearLastMutationAccount = false,
    ErrorDiagnostic? mutationDiagnostic,
    bool clearMutationDiagnostic = false,
    Map<String, List<String>>? fieldErrors,
  }) {
    return AccountsState(
      listStatus: listStatus ?? this.listStatus,
      result: clearResult ? null : result ?? this.result,
      includeInactive: includeInactive ?? this.includeInactive,
      listDiagnostic: clearListDiagnostic
          ? null
          : listDiagnostic ?? this.listDiagnostic,
      detailStatus: detailStatus ?? this.detailStatus,
      detailAccountId: clearDetailAccountId
          ? null
          : detailAccountId ?? this.detailAccountId,
      detailAccount: clearDetailAccount
          ? null
          : detailAccount ?? this.detailAccount,
      detailDiagnostic: clearDetailDiagnostic
          ? null
          : detailDiagnostic ?? this.detailDiagnostic,
      mutationStatus: mutationStatus ?? this.mutationStatus,
      lastMutationAccount: clearLastMutationAccount
          ? null
          : lastMutationAccount ?? this.lastMutationAccount,
      mutationDiagnostic: clearMutationDiagnostic
          ? null
          : mutationDiagnostic ?? this.mutationDiagnostic,
      fieldErrors: fieldErrors ?? this.fieldErrors,
    );
  }

  AccountsState withoutFieldError(String field) {
    if (!fieldErrors.containsKey(field)) {
      return this;
    }
    final next = Map<String, List<String>>.of(fieldErrors)..remove(field);
    return copyWith(fieldErrors: Map.unmodifiable(next));
  }
}
