import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/error_diagnostic.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../accounts/domain/account_models.dart';
import '../../auth/session/domain/session_models.dart';
import '../data/budgets_repository.dart';
import '../domain/budget_models.dart';
import 'budgets_state.dart';

final budgetsControllerProvider =
    NotifierProvider<BudgetsController, BudgetsState>(BudgetsController.new);

class BudgetsController extends Notifier<BudgetsState> {
  bool _reloadRequested = false;

  @override
  BudgetsState build() => const BudgetsState();

  Future<void> load() async {
    if (state.loadStatus == BudgetsLoadStatus.loading) {
      _reloadRequested = true;
      return;
    }
    state = state.copyWith(
      loadStatus: BudgetsLoadStatus.loading,
      clearDiagnostic: true,
    );
    try {
      final result = await ref.read(budgetsRepositoryProvider).list();
      state = state.copyWith(
        loadStatus: BudgetsLoadStatus.ready,
        result: result,
        clearDiagnostic: true,
      );
    } on InvalidSessionFailure catch (failure) {
      state = state.copyWith(
        loadStatus: BudgetsLoadStatus.failure,
        diagnostic: _sessionDiagnostic(failure, 'load_budgets'),
      );
    } on BudgetFailure catch (failure) {
      state = state.copyWith(
        loadStatus: BudgetsLoadStatus.failure,
        diagnostic: _diagnostic(failure, 'load_budgets'),
      );
    } on Object {
      state = state.copyWith(
        loadStatus: BudgetsLoadStatus.failure,
        diagnostic: _unexpected('load_budgets'),
      );
    } finally {
      if (_reloadRequested) {
        _reloadRequested = false;
        await load();
      }
    }
  }

  Future<BudgetMutationOutcome> save({
    int? budgetId,
    required int? categoryId,
    String nameInput = '',
    required String amountInput,
    required String? currencyCode,
    BudgetPeriod? period,
    BudgetSchedule? schedule,
  }) async {
    if (state.isSaving) return BudgetMutationOutcome.ignored;
    final validated = _validate(
      categoryId: categoryId,
      nameInput: nameInput,
      amountInput: amountInput,
      currencyCode: currencyCode,
      period: period,
      schedule: schedule,
    );
    if (validated == null) return BudgetMutationOutcome.invalid;
    state = state.copyWith(
      mutationStatus: BudgetMutationStatus.saving,
      fieldErrors: const {},
      clearMutationDiagnostic: true,
    );
    try {
      final repository = ref.read(budgetsRepositoryProvider);
      final saved = budgetId == null
          ? await repository.create(validated)
          : await repository.update(budgetId, validated);
      _acceptSaved(saved);
      return BudgetMutationOutcome.success;
    } on InvalidSessionFailure catch (failure) {
      _reject(
        _sessionDiagnostic(
          failure,
          budgetId == null ? 'create_budget' : 'update_budget',
        ),
      );
    } on BudgetFailure catch (failure) {
      await _rejectFailure(
        failure,
        budgetId == null ? 'create_budget' : 'update_budget',
      );
    } on Object {
      _reject(
        _unexpected(budgetId == null ? 'create_budget' : 'update_budget'),
      );
    }
    return BudgetMutationOutcome.failure;
  }

  Future<BudgetMutationOutcome> deleteBudget(int budgetId) async {
    if (state.isSaving) return BudgetMutationOutcome.ignored;
    state = state.copyWith(
      mutationStatus: BudgetMutationStatus.saving,
      clearMutationDiagnostic: true,
    );
    try {
      await ref.read(budgetsRepositoryProvider).deleteBudget(budgetId);
      _acceptDeleted(budgetId);
      return BudgetMutationOutcome.success;
    } on InvalidSessionFailure catch (failure) {
      _reject(_sessionDiagnostic(failure, 'delete_budget'));
    } on BudgetFailure catch (failure) {
      await _rejectFailure(failure, 'delete_budget');
    } on Object {
      _reject(_unexpected('delete_budget'));
    }
    return BudgetMutationOutcome.failure;
  }

  void clearFieldError(String field) {
    state = state.withoutFieldError(field);
  }

  void clearMutationFeedback() {
    if (state.isSaving) return;
    state = state.copyWith(
      fieldErrors: const {},
      clearMutationDiagnostic: true,
    );
  }

  BudgetCreateCommand? _validate({
    required int? categoryId,
    required String nameInput,
    required String amountInput,
    required String? currencyCode,
    required BudgetPeriod? period,
    required BudgetSchedule? schedule,
  }) {
    final result = state.result;
    final errors = <String, List<String>>{};
    if (categoryId != null &&
        (result == null ||
            !result.categories.any((item) => item.id == categoryId))) {
      errors['category_id'] = ['Selecciona una categoría válida.'];
    }
    final amount = MoneyAmount.tryParseUserInput(
      MoneyFormatter.clean(amountInput),
    );
    if (amount == null || amount.minorUnits <= 0) {
      errors['amount'] = ['Ingresa un monto mayor que cero.'];
    }
    final normalizedCurrency = currencyCode?.trim().toUpperCase();
    if (normalizedCurrency == null ||
        result == null ||
        !result.supportedCurrencies.any(
          (item) => item.code == normalizedCurrency,
        )) {
      errors['currency_code'] = ['Selecciona una moneda disponible.'];
    }
    if ((period == null) == (schedule == null)) {
      errors['schedule'] = ['Selecciona una frecuencia válida.'];
    } else if (schedule != null) {
      if (schedule.endsOn != null &&
          schedule.endsOn!.isBefore(schedule.startsOn)) {
        errors['ends_on'] = [
          'La fecha final no puede ser anterior a la inicial.',
        ];
      }
      if (schedule.scheduleType == BudgetScheduleType.recurring &&
          (schedule.frequencyUnit == null ||
              schedule.frequencyInterval == null ||
              schedule.frequencyInterval! < 1 ||
              schedule.frequencyInterval! > 999)) {
        errors['frequency_interval'] = [
          'La frecuencia debe estar entre 1 y 999.',
        ];
      }
    }
    if (errors.isNotEmpty) {
      state = state.copyWith(
        fieldErrors: Map.unmodifiable(errors),
        mutationDiagnostic: ErrorDiagnostic.capture(
          code: 'budget_invalid',
          operation: 'validate_budget',
          userMessage: 'Corrige los campos indicados.',
          technicalReason: 'client_validation',
        ),
      );
      return null;
    }
    return BudgetCreateCommand(
      categoryId: categoryId,
      name: nameInput.trim().isEmpty ? null : nameInput.trim(),
      amount: amount!,
      currencyCode: normalizedCurrency!,
      period: period,
      schedule: schedule,
    );
  }

  void _acceptSaved(Budget saved) {
    final current = state.result;
    if (current == null) {
      state = state.copyWith(
        mutationStatus: BudgetMutationStatus.idle,
        clearMutationDiagnostic: true,
      );
      return;
    }
    final budgets = [
      saved,
      ...current.budgets.where((item) => item.id != saved.id),
    ];
    state = state.copyWith(
      loadStatus: BudgetsLoadStatus.ready,
      result: BudgetListResult(
        budgets: List.unmodifiable(budgets),
        categories: current.categories,
        supportedCurrencies: current.supportedCurrencies,
        suggestedCurrencyCode: current.suggestedCurrencyCode,
      ),
      mutationStatus: BudgetMutationStatus.idle,
      fieldErrors: const {},
      clearDiagnostic: true,
      clearMutationDiagnostic: true,
    );
  }

  void _acceptDeleted(int budgetId) {
    final current = state.result;
    state = state.copyWith(
      result: current == null
          ? null
          : BudgetListResult(
              budgets: List.unmodifiable(
                current.budgets.where((item) => item.id != budgetId),
              ),
              categories: current.categories,
              supportedCurrencies: current.supportedCurrencies,
              suggestedCurrencyCode: current.suggestedCurrencyCode,
            ),
      mutationStatus: BudgetMutationStatus.idle,
      fieldErrors: const {},
      clearMutationDiagnostic: true,
    );
  }

  Future<void> _rejectFailure(BudgetFailure failure, String operation) async {
    if (failure.isMutationOutcomeUncertain) {
      try {
        final result = await ref.read(budgetsRepositoryProvider).list();
        state = state.copyWith(
          result: result,
          loadStatus: BudgetsLoadStatus.ready,
        );
      } on Object {
        // Preserve the original safe mutation diagnostic for manual refresh.
      }
    }
    state = state.copyWith(
      mutationStatus: BudgetMutationStatus.idle,
      mutationDiagnostic: _diagnostic(failure, operation),
      fieldErrors: Map.unmodifiable(failure.fieldErrors),
    );
  }

  void _reject(ErrorDiagnostic diagnostic) {
    state = state.copyWith(
      mutationStatus: BudgetMutationStatus.idle,
      mutationDiagnostic: diagnostic,
      fieldErrors: const {},
    );
  }

  ErrorDiagnostic _diagnostic(BudgetFailure failure, String operation) =>
      ErrorDiagnostic.capture(
        code: failure.code,
        operation: operation,
        userMessage: failure.userMessage,
        correlationId: failure.correlationId,
        technicalReason: failure.technicalReason,
      );

  ErrorDiagnostic _sessionDiagnostic(
    InvalidSessionFailure failure,
    String operation,
  ) => ErrorDiagnostic.capture(
    code: failure.code,
    operation: operation,
    userMessage: failure.userMessage,
    correlationId: failure.correlationId,
    technicalReason: failure.technicalReason,
  );

  ErrorDiagnostic _unexpected(String operation) => ErrorDiagnostic.capture(
    code: 'unexpected_client_error',
    operation: operation,
    userMessage: 'La operación no se pudo completar. Inténtalo de nuevo.',
    technicalReason: 'unclassified_client_failure',
  );
}
