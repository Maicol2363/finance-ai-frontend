import '../../../core/diagnostics/error_diagnostic.dart';
import '../domain/expense_models.dart';

enum ExpensesLoadStatus { initial, loading, ready, loadingMore, failure }

enum ExpenseDetailStatus { initial, loading, ready, failure }

enum ExpenseMutationStatus { idle, saving, reviewRequired }

enum ExpenseMutationOutcome { invalid, failure, success, ignored }

class ExpensesState {
  const ExpensesState({
    this.listStatus = ExpensesLoadStatus.initial,
    this.result,
    this.page = 1,
    this.pageSize = 50,
    this.listDiagnostic,
    this.detailStatus = ExpenseDetailStatus.initial,
    this.detailExpenseId,
    this.detailExpense,
    this.detailDiagnostic,
    this.mutationStatus = ExpenseMutationStatus.idle,
    this.lastMutationExpense,
    this.mutationDiagnostic,
    this.fieldErrors = const {},
  });

  final ExpensesLoadStatus listStatus;
  final ExpenseListResult? result;
  final int page;
  final int pageSize;
  final ErrorDiagnostic? listDiagnostic;
  final ExpenseDetailStatus detailStatus;
  final int? detailExpenseId;
  final Expense? detailExpense;
  final ErrorDiagnostic? detailDiagnostic;
  final ExpenseMutationStatus mutationStatus;
  final Expense? lastMutationExpense;
  final ErrorDiagnostic? mutationDiagnostic;
  final Map<String, List<String>> fieldErrors;

  bool get isSaving => mutationStatus == ExpenseMutationStatus.saving;

  bool get requiresMutationReview =>
      mutationStatus == ExpenseMutationStatus.reviewRequired;

  ExpensesState copyWith({
    ExpensesLoadStatus? listStatus,
    ExpenseListResult? result,
    bool clearResult = false,
    int? page,
    int? pageSize,
    ErrorDiagnostic? listDiagnostic,
    bool clearListDiagnostic = false,
    ExpenseDetailStatus? detailStatus,
    int? detailExpenseId,
    bool clearDetailExpenseId = false,
    Expense? detailExpense,
    bool clearDetailExpense = false,
    ErrorDiagnostic? detailDiagnostic,
    bool clearDetailDiagnostic = false,
    ExpenseMutationStatus? mutationStatus,
    Expense? lastMutationExpense,
    bool clearLastMutationExpense = false,
    ErrorDiagnostic? mutationDiagnostic,
    bool clearMutationDiagnostic = false,
    Map<String, List<String>>? fieldErrors,
  }) {
    return ExpensesState(
      listStatus: listStatus ?? this.listStatus,
      result: clearResult ? null : result ?? this.result,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      listDiagnostic: clearListDiagnostic
          ? null
          : listDiagnostic ?? this.listDiagnostic,
      detailStatus: detailStatus ?? this.detailStatus,
      detailExpenseId: clearDetailExpenseId
          ? null
          : detailExpenseId ?? this.detailExpenseId,
      detailExpense: clearDetailExpense
          ? null
          : detailExpense ?? this.detailExpense,
      detailDiagnostic: clearDetailDiagnostic
          ? null
          : detailDiagnostic ?? this.detailDiagnostic,
      mutationStatus: mutationStatus ?? this.mutationStatus,
      lastMutationExpense: clearLastMutationExpense
          ? null
          : lastMutationExpense ?? this.lastMutationExpense,
      mutationDiagnostic: clearMutationDiagnostic
          ? null
          : mutationDiagnostic ?? this.mutationDiagnostic,
      fieldErrors: fieldErrors ?? this.fieldErrors,
    );
  }

  ExpensesState withoutFieldError(String field) {
    if (!fieldErrors.containsKey(field)) {
      return this;
    }
    final next = Map<String, List<String>>.of(fieldErrors)..remove(field);
    return copyWith(fieldErrors: Map.unmodifiable(next));
  }
}
