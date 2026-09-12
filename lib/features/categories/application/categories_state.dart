import '../../../core/diagnostics/error_diagnostic.dart';
import '../domain/category_models.dart';

enum CategoriesLoadStatus { initial, loading, ready, failure }

enum CategoryMutationStatus { idle, saving }

enum CategoryMutationOutcome { invalid, failure, success, ignored }

class CategoriesState {
  const CategoriesState({
    this.loadStatus = CategoriesLoadStatus.initial,
    this.result,
    this.diagnostic,
    this.mutationStatus = CategoryMutationStatus.idle,
    this.mutationDiagnostic,
    this.fieldErrors = const {},
  });

  final CategoriesLoadStatus loadStatus;
  final CategoryListResult? result;
  final ErrorDiagnostic? diagnostic;
  final CategoryMutationStatus mutationStatus;
  final ErrorDiagnostic? mutationDiagnostic;
  final Map<String, List<String>> fieldErrors;

  bool get isSaving => mutationStatus == CategoryMutationStatus.saving;

  CategoriesState copyWith({
    CategoriesLoadStatus? loadStatus,
    CategoryListResult? result,
    ErrorDiagnostic? diagnostic,
    bool clearDiagnostic = false,
    CategoryMutationStatus? mutationStatus,
    ErrorDiagnostic? mutationDiagnostic,
    bool clearMutationDiagnostic = false,
    Map<String, List<String>>? fieldErrors,
  }) => CategoriesState(
    loadStatus: loadStatus ?? this.loadStatus,
    result: result ?? this.result,
    diagnostic: clearDiagnostic ? null : diagnostic ?? this.diagnostic,
    mutationStatus: mutationStatus ?? this.mutationStatus,
    mutationDiagnostic: clearMutationDiagnostic
        ? null
        : mutationDiagnostic ?? this.mutationDiagnostic,
    fieldErrors: fieldErrors ?? this.fieldErrors,
  );

  CategoriesState withoutFieldError(String field) {
    final next = Map<String, List<String>>.of(fieldErrors)..remove(field);
    return copyWith(fieldErrors: Map.unmodifiable(next));
  }
}
