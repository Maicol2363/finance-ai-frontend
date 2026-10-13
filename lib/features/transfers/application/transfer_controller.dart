import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/error_diagnostic.dart';
import '../../accounts/application/accounts_controller.dart';
import '../../accounts/domain/account_models.dart';
import '../../auth/session/domain/session_models.dart';
import '../data/transfers_repository.dart';
import '../domain/transfer_models.dart';
import 'transfer_state.dart';

final transferControllerProvider =
    NotifierProvider<TransferController, TransferState>(TransferController.new);

class TransferController extends Notifier<TransferState> {
  @override
  TransferState build() => const TransferState();

  Future<TransferMutationOutcome> create({
    required int? sourceAccountId,
    required int? destinationAccountId,
    required String sourceAmountInput,
    required String? destinationAmountInput,
    required DateTime? date,
    String? description,
  }) async {
    if (state.mutationStatus != TransferMutationStatus.idle) {
      return TransferMutationOutcome.ignored;
    }
    final validated = _validate(
      sourceAccountId: sourceAccountId,
      destinationAccountId: destinationAccountId,
      sourceAmountInput: sourceAmountInput,
      destinationAmountInput: destinationAmountInput,
      date: date,
      description: description,
    );
    if (validated == null) {
      return TransferMutationOutcome.invalid;
    }
    state = state.copyWith(
      mutationStatus: TransferMutationStatus.saving,
      clearLastTransfer: true,
      fieldErrors: const {},
      clearMutationDiagnostic: true,
    );
    try {
      final transfer = await ref
          .read(transfersRepositoryProvider)
          .create(validated);
      state = state.copyWith(
        mutationStatus: TransferMutationStatus.idle,
        lastTransfer: transfer,
        fieldErrors: const {},
        clearMutationDiagnostic: true,
      );
      return TransferMutationOutcome.success;
    } on InvalidSessionFailure catch (failure) {
      state = state.copyWith(
        mutationStatus: TransferMutationStatus.idle,
        mutationDiagnostic: _sessionDiagnostic(
          failure,
          operation: 'create_transfer',
        ),
        fieldErrors: const {},
      );
    } on TransferFailure catch (failure) {
      state = state.copyWith(
        mutationStatus: failure.isMutationOutcomeUncertain
            ? TransferMutationStatus.reviewRequired
            : TransferMutationStatus.idle,
        mutationDiagnostic: _diagnosticFor(
          failure,
          operation: 'create_transfer',
        ),
        fieldErrors: Map.unmodifiable(failure.fieldErrors),
      );
    } on Object {
      state = state.copyWith(
        mutationStatus: TransferMutationStatus.idle,
        mutationDiagnostic: _unexpected(operation: 'create_transfer'),
        fieldErrors: const {},
      );
    }
    return TransferMutationOutcome.failure;
  }

  void clearFieldError(String field) {
    state = state.withoutFieldError(field);
  }

  void clearMutationFeedback() {
    if (state.isSaving) {
      return;
    }
    state = state.copyWith(
      mutationStatus: TransferMutationStatus.idle,
      clearLastTransfer: true,
      fieldErrors: const {},
      clearMutationDiagnostic: true,
    );
  }

  Future<void> resolveUncertainMutation() async {
    if (!state.requiresMutationReview) {
      return;
    }
    state = state.copyWith(mutationStatus: TransferMutationStatus.saving);
    try {
      await ref.read(accountsControllerProvider.notifier).load();
      state = state.copyWith(
        mutationStatus: TransferMutationStatus.idle,
        clearMutationDiagnostic: true,
      );
    } on Object {
      state = state.copyWith(
        mutationStatus: TransferMutationStatus.reviewRequired,
      );
    }
  }

  TransferCreateCommand? _validate({
    required int? sourceAccountId,
    required int? destinationAccountId,
    required String sourceAmountInput,
    required String? destinationAmountInput,
    required DateTime? date,
    required String? description,
  }) {
    final errors = <String, List<String>>{};
    if (sourceAccountId == null || sourceAccountId < 1) {
      errors['source_account_id'] = ['Elige la cuenta de origen.'];
    }
    if (destinationAccountId == null || destinationAccountId < 1) {
      errors['destination_account_id'] = ['Elige la cuenta de destino.'];
    }
    if (sourceAccountId != null &&
        destinationAccountId != null &&
        sourceAccountId == destinationAccountId) {
      errors['destination_account_id'] = [
        'Elige una cuenta distinta a la de origen.',
      ];
    }
    final sourceAmount = MoneyAmount.tryParseUserInput(sourceAmountInput);
    if (sourceAmount == null ||
        sourceAmount.isNegative ||
        sourceAmount.minorUnits == 0) {
      errors['source_amount'] = ['Ingresa un monto positivo válido.'];
    }
    MoneyAmount? destinationAmount;
    final rawDestination = destinationAmountInput?.trim();
    if (rawDestination != null && rawDestination.isNotEmpty) {
      destinationAmount = MoneyAmount.tryParseUserInput(rawDestination);
      if (destinationAmount == null ||
          destinationAmount.isNegative ||
          destinationAmount.minorUnits == 0) {
        errors['destination_amount'] = ['Ingresa un monto positivo válido.'];
      }
    }
    if (date == null) {
      errors['date'] = ['Elige la fecha de la transferencia.'];
    }
    String? normalizedDescription;
    if (description != null) {
      normalizedDescription = description.trim();
      if (normalizedDescription.isEmpty) {
        normalizedDescription = null;
      } else if (normalizedDescription.runes.length > 500) {
        errors['description'] = [
          'La descripción debe tener 500 caracteres o menos.',
        ];
      }
    }
    final sourceBalance = _balanceOf(sourceAccountId);
    if (sourceAmount != null &&
        sourceBalance != null &&
        sourceAmount.minorUnits > sourceBalance.minorUnits) {
      errors['source_amount'] = [
        'Fondos insuficientes en la cuenta de origen.',
      ];
    }
    final crossCurrency = _isCrossCurrency(
      sourceAccountId,
      destinationAccountId,
    );
    if (crossCurrency && destinationAmount == null) {
      errors['destination_amount'] = [
        'Indica cuánto llega en la moneda de destino.',
      ];
    }
    if (errors.isNotEmpty) {
      state = state.copyWith(
        mutationStatus: TransferMutationStatus.idle,
        fieldErrors: Map.unmodifiable(errors),
        mutationDiagnostic: ErrorDiagnostic.capture(
          code: 'transfer_invalid',
          operation: 'validate_transfer',
          userMessage: 'Corrige los campos marcados.',
          technicalReason: 'client_validation',
        ),
      );
      return null;
    }
    return TransferCreateCommand(
      sourceAccountId: sourceAccountId!,
      destinationAccountId: destinationAccountId!,
      sourceAmount: sourceAmount!,
      destinationAmount: crossCurrency ? destinationAmount : null,
      date: date!,
      description: normalizedDescription,
    );
  }

  MoneyAmount? _balanceOf(int? accountId) {
    if (accountId == null) {
      return null;
    }
    final accounts =
        ref.read(accountsControllerProvider).result?.accounts ?? const [];
    for (final account in accounts) {
      if (account.id == accountId) {
        return account.balance;
      }
    }
    return null;
  }

  bool _isCrossCurrency(int? sourceAccountId, int? destinationAccountId) {
    if (sourceAccountId == null || destinationAccountId == null) {
      return false;
    }
    final accounts =
        ref.read(accountsControllerProvider).result?.accounts ?? const [];
    String? codeOf(int id) {
      for (final account in accounts) {
        if (account.id == id) {
          return account.currency.code;
        }
      }
      return null;
    }

    final sourceCode = codeOf(sourceAccountId);
    final destinationCode = codeOf(destinationAccountId);
    if (sourceCode == null || destinationCode == null) {
      return false;
    }
    return sourceCode != destinationCode;
  }

  ErrorDiagnostic _diagnosticFor(
    TransferFailure failure, {
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
      userMessage: 'La operación no se pudo completar. Inténtalo de nuevo.',
      technicalReason: 'unclassified_client_failure',
    );
  }
}
