import '../../../core/diagnostics/error_diagnostic.dart';
import '../domain/transfer_models.dart';

enum TransferMutationStatus { idle, saving, reviewRequired }

enum TransferMutationOutcome { invalid, failure, success, ignored }

class TransferState {
  const TransferState({
    this.mutationStatus = TransferMutationStatus.idle,
    this.lastTransfer,
    this.mutationDiagnostic,
    this.fieldErrors = const {},
  });

  final TransferMutationStatus mutationStatus;
  final Transfer? lastTransfer;
  final ErrorDiagnostic? mutationDiagnostic;
  final Map<String, List<String>> fieldErrors;

  bool get isSaving => mutationStatus == TransferMutationStatus.saving;

  bool get requiresMutationReview =>
      mutationStatus == TransferMutationStatus.reviewRequired;

  TransferState copyWith({
    TransferMutationStatus? mutationStatus,
    Transfer? lastTransfer,
    bool clearLastTransfer = false,
    ErrorDiagnostic? mutationDiagnostic,
    bool clearMutationDiagnostic = false,
    Map<String, List<String>>? fieldErrors,
  }) {
    return TransferState(
      mutationStatus: mutationStatus ?? this.mutationStatus,
      lastTransfer: clearLastTransfer
          ? null
          : lastTransfer ?? this.lastTransfer,
      mutationDiagnostic: clearMutationDiagnostic
          ? null
          : mutationDiagnostic ?? this.mutationDiagnostic,
      fieldErrors: fieldErrors ?? this.fieldErrors,
    );
  }

  TransferState withoutFieldError(String field) {
    if (!fieldErrors.containsKey(field)) {
      return this;
    }
    final next = Map<String, List<String>>.of(fieldErrors)..remove(field);
    return copyWith(fieldErrors: Map.unmodifiable(next));
  }
}
