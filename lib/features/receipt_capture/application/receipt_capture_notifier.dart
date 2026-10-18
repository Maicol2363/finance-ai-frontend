import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/diagnostics/error_diagnostic.dart';
import '../../expenses/application/expenses_controller.dart';
import '../../expenses/application/history_controller.dart';
import '../../expenses/domain/expense_models.dart';
import '../data/receipt_capture_remote_data_source.dart';
import '../data/receipt_photo_cache_repository.dart';
import '../domain/receipt_capture_state.dart';
import '../domain/receipt_proposal_dto.dart';
import '../domain/receipt_review_form_data.dart';

final imagePickerProvider = Provider<ImagePicker>((ref) {
  return ImagePicker();
});

final receiptCaptureNotifierProvider =
    NotifierProvider<ReceiptCaptureNotifier, ReceiptCaptureState>(
      ReceiptCaptureNotifier.new,
    );

class ReceiptCaptureNotifier extends Notifier<ReceiptCaptureState> {
  ReceiptCaptureRemoteDataSource get _remoteDataSource =>
      ref.read(receiptCaptureRemoteDataSourceProvider);
  ReceiptPhotoCacheRepository get _photoCacheRepository =>
      ref.read(receiptPhotoCacheRepositoryProvider);
  ImagePicker get _imagePicker => ref.read(imagePickerProvider);

  @override
  ReceiptCaptureState build() => const ReceiptCaptureIdle();

  /// Prompts image picker (camera or gallery) with pre-compression constraints.
  Future<void> pickImage(ImageSource source) async {
    try {
      final xFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 85,
      );

      if (xFile == null) {
        return; // User canceled
      }

      await useImageFile(xFile);
    } catch (e) {
      state = ReceiptCaptureError(
        diagnostic: _failureDiagnostic(
          e,
          operation: 'select_receipt_image',
          userMessage:
              'No se pudo leer la imagen seleccionada. Inténtalo de nuevo.',
          technicalReason: 'image_selection_failure',
        ),
      );
    }
  }

  /// Adopts an already selected image (e.g. one captured with the in-app
  /// camera) into the PreCheck state, validating its size first.
  Future<void> useImageFile(XFile xFile) async {
    try {
      final fileSizeBytes = await xFile.length();
      if (fileSizeBytes > 10 * 1024 * 1024) {
        state = ReceiptCaptureError(
          diagnostic: _unexpected(
            operation: 'validate_receipt_image',
            code: 'receipt_image_too_large',
            userMessage:
                'La imagen excede el límite máximo permitido de 10 MB.',
            technicalReason: 'image_exceeds_size_limit',
          ),
          localImagePath: xFile.path,
          // Re-uploading the same file cannot change its size.
          canRetry: false,
        );
        return;
      }

      state = ReceiptCapturePreCheck(
        imagePath: xFile.path,
        fileSizeBytes: fileSizeBytes,
        rotationDegrees: 0,
      );
    } catch (e) {
      state = ReceiptCaptureError(
        diagnostic: _failureDiagnostic(
          e,
          operation: 'validate_receipt_image',
          userMessage:
              'No se pudo leer la imagen seleccionada. Inténtalo de nuevo.',
          technicalReason: 'image_inspection_failure',
        ),
        // The file itself is unusable, so another attempt would fail the same way.
        canRetry: false,
      );
    }
  }

  /// Rotates image in PreCheck state by delta (e.g. 90° clockwise).
  void rotatePreCheck([int delta = 90]) {
    final current = state;
    if (current is ReceiptCapturePreCheck) {
      final newRotation = (current.rotationDegrees + delta) % 360;
      state = current.copyWith(rotationDegrees: newRotation);
    }
  }

  /// Initiates upload to backend proposal endpoint.
  Future<void> analyzeReceipt() async {
    final current = state;
    if (current is! ReceiptCapturePreCheck) {
      return;
    }

    await _requestProposal(
      imagePath: current.imagePath,
      rotationDegrees: current.rotationDegrees,
    );
  }

  /// Retries a failed analysis with the same photo and rotation.
  ///
  /// The error state keeps the user's correction, so a transient failure (network
  /// or provider) no longer costs the whole capture: the photo is sent again
  /// exactly as the user prepared it.
  Future<void> retryFailedAnalysis() async {
    final current = state;
    if (current is! ReceiptCaptureError) {
      return;
    }
    final imagePath = current.localImagePath;
    if (imagePath == null || !current.canRetry) {
      return;
    }

    await _requestProposal(
      imagePath: imagePath,
      rotationDegrees: current.rotationDegrees,
    );
  }

  Future<void> _requestProposal({
    required String imagePath,
    required int rotationDegrees,
  }) async {
    state = ReceiptCaptureAnalyzing(
      imagePath: imagePath,
      rotationDegrees: rotationDegrees,
    );

    try {
      final proposal = await _remoteDataSource.uploadProposal(
        filePath: imagePath,
        rotationDegrees: rotationDegrees,
      );

      _populateReviewState(proposal, imagePath);
    } catch (e) {
      state = ReceiptCaptureError(
        diagnostic: _failureDiagnostic(
          e,
          operation: 'analyze_receipt',
          userMessage: 'No se pudo analizar el recibo. Revisa tu conexión e inténtalo de nuevo.',
          technicalReason: 'receipt_analysis_failure',
        ),
        localImagePath: imagePath,
        rotationDegrees: rotationDegrees,
      );
    }
  }

  /// Retries proposal extraction with a new rotation angle.
  Future<void> retryAnalysis(int rotationDegrees) async {
    final current = state;
    if (current is! ReceiptCaptureReview) {
      return;
    }

    state = current.copyWith(isSubmitting: true, submissionError: null);

    try {
      final updated = await _remoteDataSource.retryProposal(
        proposalId: current.proposalId,
        filePath: current.localImagePath,
        rotationDegrees: rotationDegrees,
      );

      _populateReviewState(updated, current.localImagePath);
    } catch (e) {
      state = current.copyWith(
        isSubmitting: false,
        submissionDiagnostic: _failureDiagnostic(
          e,
          operation: 'retry_receipt_analysis',
          userMessage:
              'No se pudo volver a analizar el recibo. Inténtalo de nuevo.',
          technicalReason: 'receipt_retry_failure',
        ),
      );
    }
  }

  /// Discards the ephemeral proposal draft.
  Future<void> discardDraft() async {
    final current = state;
    if (current is ReceiptCaptureReview) {
      try {
        await _remoteDataSource.discardProposal(proposalId: current.proposalId);
      } catch (_) {
        // Ignored on discard cleanup
      }
    }
    state = const ReceiptCaptureIdle();
  }

  /// Alias for discardDraft.
  Future<void> discardProposal() => discardDraft();

  /// Updates current form data in Review state.
  void updateFormData(ReceiptReviewFormData newFormData) {
    final current = state;
    if (current is ReceiptCaptureReview) {
      // Editing the form clears both the validation hint and the previous
      // failure report; the next attempt generates a fresh one.
      state = current.copyWith(
        formData: newFormData,
        submissionError: null,
        submissionDiagnostic: null,
      );
    }
  }

  /// Adds a new line item draft to the review form.
  void addLineItem(ReceiptLineItemDraft item) {
    final current = state;
    if (current is ReceiptCaptureReview) {
      final updatedItems = List<ReceiptLineItemDraft>.from(
        current.formData.items,
      )..add(item);
      state = current.copyWith(
        formData: current.formData.copyWith(items: updatedItems),
      );
    }
  }

  /// Updates an existing line item in the review form.
  void updateLineItem(int index, ReceiptLineItemDraft item) {
    final current = state;
    if (current is ReceiptCaptureReview) {
      if (index >= 0 && index < current.formData.items.length) {
        final updatedItems = List<ReceiptLineItemDraft>.from(
          current.formData.items,
        );
        updatedItems[index] = item;
        state = current.copyWith(
          formData: current.formData.copyWith(items: updatedItems),
        );
      }
    }
  }

  /// Removes a line item from the review form.
  void removeLineItem(int index) {
    final current = state;
    if (current is ReceiptCaptureReview) {
      if (index >= 0 && index < current.formData.items.length) {
        final updatedItems = List<ReceiptLineItemDraft>.from(
          current.formData.items,
        )..removeAt(index);
        state = current.copyWith(
          formData: current.formData.copyWith(items: updatedItems),
        );
      }
    }
  }

  /// Submits confirmed expense to backend and caches local image (Model B).
  Future<Expense?> confirmExpense() async {
    final current = state;
    if (current is! ReceiptCaptureReview) {
      return null;
    }

    final form = current.formData;
    if (!form.isValid) {
      state = current.copyWith(
        submissionError: 'Completa los campos obligatorios antes de continuar.',
        submissionDiagnostic: null,
      );
      return null;
    }

    state = current.copyWith(
      isSubmitting: true,
      submissionError: null,
      submissionDiagnostic: null,
    );

    try {
      final isNewCategory = form.categoryId == -1;
      final command = ReceiptProposalConfirmRequestDto(
        accountId: form.accountId!,
        totalAmount: form.totalAmount,
        merchant: form.merchant.trim(),
        occurredAt: form.occurredAt.toUtc().toIso8601String(),
        currency: form.currency,
        categoryId: isNewCategory ? null : form.categoryId,
        newCategoryName: isNewCategory
            ? (form.newCategoryName ?? form.suggestedCategory)
            : null,
        note: form.note,
        items: form.items
            .map(
              (item) => ConfirmedReceiptItemDto(
                name: item.name.trim(),
                totalPrice: item.totalPrice,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                categoryId: item.categoryId == -1 ? null : item.categoryId,
                note: item.note,
              ),
            )
            .toList(),
      );

      final confirmedExpense = await _remoteDataSource.confirmProposal(
        proposalId: current.proposalId,
        command: command,
      );

      // Save local photo in cache for offline viewing (Model B)
      String? savedCachePath;
      try {
        savedCachePath = await _photoCacheRepository.saveReceiptPhoto(
          expenseId: confirmedExpense.id,
          sourceFilePath: current.localImagePath,
        );
      } catch (_) {
        // Cache persistence failure is non-blocking
      }

      // Refresh expense feed providers
      try {
        ref.read(expensesControllerProvider.notifier).load();
        ref.read(historyControllerProvider.notifier).load();
      } catch (_) {}

      state = ReceiptCaptureSuccess(
        expenseId: confirmedExpense.id,
        merchant: confirmedExpense.store,
        totalAmount:
            double.tryParse(confirmedExpense.amount.toApiString()) ??
            form.totalAmount,
        localSavedImagePath: savedCachePath,
      );

      return confirmedExpense;
    } catch (e) {
      state = current.copyWith(
        isSubmitting: false,
        submissionDiagnostic: _failureDiagnostic(
          e,
          operation: 'confirm_receipt_expense',
          userMessage: 'No se pudo guardar el gasto. Inténtalo de nuevo.',
          technicalReason: 'receipt_confirmation_failure',
        ),
      );
      return null;
    }
  }

  /// Resets state to Idle.
  void reset() {
    state = const ReceiptCaptureIdle();
  }

  void _populateReviewState(
    ReceiptProposalResponseDto proposal,
    String localImagePath,
  ) {
    final extracted = proposal.extractedData;

    DateTime parsedDate = DateTime.now();
    if (extracted.date != null && extracted.date!.isNotEmpty) {
      try {
        parsedDate = DateTime.parse(extracted.date!);
      } catch (_) {}
    }

    final items = extracted.items.asMap().entries.map((entry) {
      return ReceiptLineItemDraft(
        localId: 'item-${entry.key}-${DateTime.now().millisecondsSinceEpoch}',
        name: entry.value.name,
        quantity: entry.value.quantity,
        unitPrice: entry.value.unitPrice,
        totalPrice: entry.value.totalPrice,
        categoryId: extracted.categoryId,
      );
    }).toList();

    final formData = ReceiptReviewFormData(
      merchant: extracted.merchantName ?? '',
      totalAmount: extracted.totalAmount ?? 0.0,
      occurredAt: parsedDate,
      accountId: null, // Will be chosen or pre-selected by review screen
      categoryId: extracted.categoryId,
      suggestedCategory: extracted.categorySuggestion,
      paymentMethod: extracted.paymentMethod,
      suggestedAccount: extracted.suggestedAccount,
      currency: extracted.currency,
      items: items,
    );

    state = ReceiptCaptureReview(
      proposalId: proposal.proposalId,
      status: proposal.status,
      localImagePath: localImagePath,
      formData: formData,
      issues: proposal.issues,
      isSubmitting: false,
      possibleDuplicate: proposal.possibleDuplicate,
      duplicateWarning: proposal.duplicateWarning,
    );
  }

  /// Builds the shared privacy-safe report for a failure that reached the
  /// client, reusing the server contract when the API answered.
  ///
  /// The raw exception is deliberately never copied into the report: only a
  /// fixed [technicalReason] and the allow-listed failure fields travel to the
  /// user-visible copy panel.
  ErrorDiagnostic _failureDiagnostic(
    Object error, {
    required String operation,
    required String userMessage,
    required String technicalReason,
  }) {
    if (error is ExpenseFailure) {
      return _diagnosticFor(error, operation: operation);
    }
    return _unexpected(
      operation: operation,
      userMessage: userMessage,
      technicalReason: technicalReason,
    );
  }

  /// Maps a server-reported failure, preserving its stable code and
  /// correlation ID so a client report can be matched to the backend log.
  ErrorDiagnostic _diagnosticFor(
    ExpenseFailure failure, {
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

  /// Reports a client-side failure with a fixed, safe reason.
  ErrorDiagnostic _unexpected({
    required String operation,
    required String userMessage,
    required String technicalReason,
    String code = 'unexpected_client_error',
  }) {
    return ErrorDiagnostic.capture(
      code: code,
      operation: operation,
      userMessage: userMessage,
      technicalReason: technicalReason,
    );
  }
}
