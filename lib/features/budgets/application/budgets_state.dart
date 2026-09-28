import '../../../core/diagnostics/error_diagnostic.dart';
import '../domain/budget_models.dart';

enum BudgetsLoadStatus { initial, loading, ready, failure }

enum BudgetMutationStatus { idle, saving }

enum BudgetMutationOutcome { invalid, failure, success, ignored }

class BudgetsState {
  const BudgetsState({
    this.loadStatus = BudgetsLoadStatus.initial,
    this.result,
    this.diagnostic,
    this.mutationStatus = BudgetMutationStatus.idle,
    this.mutationDiagnostic,
    this.fieldErrors = const {},
  });

  final BudgetsLoadStatus loadStatus;
  final BudgetListResult? result;
  final ErrorDiagnostic? diagnostic;
  final BudgetMutationStatus mutationStatus;
  final ErrorDiagnostic? mutationDiagnostic;
  final Map<String, List<String>> fieldErrors;

  bool get isSaving => mutationStatus == BudgetMutationStatus.saving;

  BudgetsState copyWith({
    BudgetsLoadStatus? loadStatus,
    BudgetListResult? result,
    ErrorDiagnostic? diagnostic,
    bool clearDiagnostic = false,
    BudgetMutationStatus? mutationStatus,
    ErrorDiagnostic? mutationDiagnostic,
    bool clearMutationDiagnostic = false,
    Map<String, List<String>>? fieldErrors,
  }) => BudgetsState(
    loadStatus: loadStatus ?? this.loadStatus,
    result: result ?? this.result,
    diagnostic: clearDiagnostic ? null : diagnostic ?? this.diagnostic,
    mutationStatus: mutationStatus ?? this.mutationStatus,
    mutationDiagnostic: clearMutationDiagnostic
        ? null
        : mutationDiagnostic ?? this.mutationDiagnostic,
    fieldErrors: fieldErrors ?? this.fieldErrors,
  );

  BudgetsState withoutFieldError(String field) {
    final next = Map<String, List<String>>.of(fieldErrors)..remove(field);
    return copyWith(fieldErrors: Map.unmodifiable(next));
  }
}
