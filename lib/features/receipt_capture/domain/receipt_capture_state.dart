import 'package:flutter/foundation.dart';

import '../../../core/diagnostics/error_diagnostic.dart';
import 'receipt_review_form_data.dart';

@immutable
sealed class ReceiptCaptureState {
  const ReceiptCaptureState();
}

class ReceiptCaptureIdle extends ReceiptCaptureState {
  const ReceiptCaptureIdle();
}

class ReceiptCapturePreCheck extends ReceiptCaptureState {
  final String imagePath;
  final int fileSizeBytes;
  final int rotationDegrees;

  const ReceiptCapturePreCheck({
    required this.imagePath,
    required this.fileSizeBytes,
    this.rotationDegrees = 0,
  });

  ReceiptCapturePreCheck copyWith({
    String? imagePath,
    int? fileSizeBytes,
    int? rotationDegrees,
  }) {
    return ReceiptCapturePreCheck(
      imagePath: imagePath ?? this.imagePath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
    );
  }
}

class ReceiptCaptureAnalyzing extends ReceiptCaptureState {
  final String imagePath;
  final int rotationDegrees;

  const ReceiptCaptureAnalyzing({
    required this.imagePath,
    this.rotationDegrees = 0,
  });
}

class ReceiptCaptureReview extends ReceiptCaptureState {
  final String proposalId;
  final String status;
  final String localImagePath;
  final ReceiptReviewFormData formData;
  final List<String> issues;
  final bool isSubmitting;
  final String? submissionError;
  final ErrorDiagnostic? submissionDiagnostic;
  final bool possibleDuplicate;
  final String? duplicateWarning;

  const ReceiptCaptureReview({
    required this.proposalId,
    required this.status,
    required this.localImagePath,
    required this.formData,
    this.issues = const [],
    this.isSubmitting = false,
    this.submissionError,
    this.submissionDiagnostic,
    this.possibleDuplicate = false,
    this.duplicateWarning,
  });

  ReceiptCaptureReview copyWith({
    String? proposalId,
    String? status,
    String? localImagePath,
    ReceiptReviewFormData? formData,
    List<String>? issues,
    bool? isSubmitting,
    String? submissionError,
    ErrorDiagnostic? submissionDiagnostic,
    bool? possibleDuplicate,
    String? duplicateWarning,
  }) {
    return ReceiptCaptureReview(
      proposalId: proposalId ?? this.proposalId,
      status: status ?? this.status,
      localImagePath: localImagePath ?? this.localImagePath,
      formData: formData ?? this.formData,
      issues: issues ?? this.issues,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submissionError: submissionError,
      submissionDiagnostic: submissionDiagnostic,
      possibleDuplicate: possibleDuplicate ?? this.possibleDuplicate,
      duplicateWarning: duplicateWarning ?? this.duplicateWarning,
    );
  }
}

class ReceiptCaptureSuccess extends ReceiptCaptureState {
  final int expenseId;
  final String merchant;
  final double totalAmount;
  final String? localSavedImagePath;

  const ReceiptCaptureSuccess({
    required this.expenseId,
    required this.merchant,
    required this.totalAmount,
    this.localSavedImagePath,
  });
}

/// A user-visible capture failure.
///
/// [diagnostic] carries the shared, privacy-safe report (stable code, operation,
/// safe message and technical reason). Raw exception text, file paths and
/// platform details must never be rendered from this state.
///
/// [rotationDegrees] keeps the correction the user applied before the failed
/// attempt so a retry analyses the same orientation instead of the original one.
class ReceiptCaptureError extends ReceiptCaptureState {
  final ErrorDiagnostic diagnostic;
  final String? localImagePath;
  final bool canRetry;
  final int rotationDegrees;

  const ReceiptCaptureError({
    required this.diagnostic,
    this.localImagePath,
    this.canRetry = true,
    this.rotationDegrees = 0,
  });
}
