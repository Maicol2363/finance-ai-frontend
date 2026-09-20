import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/error_diagnostic.dart';
import '../../accounts/domain/account_models.dart';
import '../../auth/session/domain/session_models.dart';
import '../data/expenses_repository.dart';
import '../domain/expense_models.dart';
import 'expenses_state.dart';

final expensesControllerProvider =
    NotifierProvider<ExpensesController, ExpensesState>(ExpensesController.new);

class ExpensesController extends Notifier<ExpensesState> {
  @override
  ExpensesState build() => const ExpensesState();

  Future<void> load({int? page, int? pageSize}) async {
    final targetPage = page ?? 1;
    final targetSize = pageSize ?? state.pageSize;
    if (state.listStatus == ExpensesLoadStatus.loading ||
        state.listStatus == ExpensesLoadStatus.loadingMore) {
      return;
    }
    state = state.copyWith(
      listStatus: ExpensesLoadStatus.loading,
      page: targetPage,
      pageSize: targetSize,
      clearListDiagnostic: true,
    );
    try {
      final result = await ref
          .read(expensesRepositoryProvider)
          .list(page: targetPage, pageSize: targetSize);
      state = state.copyWith(
        listStatus: ExpensesLoadStatus.ready,
        result: result,
        page: result.page,
        pageSize: result.pageSize,
        clearListDiagnostic: true,
      );
    } on InvalidSessionFailure catch (failure) {
      state = state.copyWith(
        listStatus: ExpensesLoadStatus.failure,
        listDiagnostic: _sessionDiagnostic(failure, operation: 'load_expenses'),
      );
    } on ExpenseFailure catch (failure) {
      state = state.copyWith(
        listStatus: ExpensesLoadStatus.failure,
        listDiagnostic: _diagnosticFor(failure, operation: 'load_expenses'),
      );
    } on Object {
      state = state.copyWith(
        listStatus: ExpensesLoadStatus.failure,
        listDiagnostic: _unexpected(operation: 'load_expenses'),
      );
    }
  }

  Future<void> loadMore() async {
    final current = state.result;
    if (state.listStatus != ExpensesLoadStatus.ready || current == null) {
      return;
    }
    if (!current.hasNext) {
      return;
    }
    state = state.copyWith(
      listStatus: ExpensesLoadStatus.loadingMore,
      clearListDiagnostic: true,
    );
    try {
      final next = await ref
          .read(expensesRepositoryProvider)
          .list(page: current.page + 1, pageSize: current.pageSize);
      final combined = ExpenseListResult(
        items: List.unmodifiable([...current.items, ...next.items]),
        total: next.total,
        page: next.page,
        pageSize: next.pageSize,
        hasNext: next.hasNext,
      );
      state = state.copyWith(
        listStatus: ExpensesLoadStatus.ready,
        result: combined,
        page: combined.page,
        pageSize: combined.pageSize,
        clearListDiagnostic: true,
      );
    } on InvalidSessionFailure catch (failure) {
      state = state.copyWith(
        listStatus: ExpensesLoadStatus.failure,
        listDiagnostic: _sessionDiagnostic(
          failure,
          operation: 'load_more_expenses',
        ),
      );
    } on ExpenseFailure catch (failure) {
      state = state.copyWith(
        listStatus: ExpensesLoadStatus.failure,
        listDiagnostic: _diagnosticFor(
          failure,
          operation: 'load_more_expenses',
        ),
      );
    } on Object {
      state = state.copyWith(
        listStatus: ExpensesLoadStatus.failure,
        listDiagnostic: _unexpected(operation: 'load_more_expenses'),
      );
    }
  }

  Future<void> loadDetail(int expenseId) async {
    final cached = _cachedExpense(expenseId);
    state = state.copyWith(
      detailStatus: ExpenseDetailStatus.loading,
      detailExpenseId: expenseId,
      detailExpense: cached,
      clearDetailExpense: cached == null,
      clearDetailDiagnostic: true,
    );
    try {
      final expense = await ref.read(expensesRepositoryProvider).get(expenseId);
      if (state.detailExpenseId != expenseId) {
        return;
      }
      state = state.copyWith(
        detailStatus: ExpenseDetailStatus.ready,
        detailExpense: expense,
        result: _replaceInResult(state.result, expense),
        clearDetailDiagnostic: true,
      );
    } on InvalidSessionFailure catch (failure) {
      if (state.detailExpenseId == expenseId) {
        state = state.copyWith(
          detailStatus: ExpenseDetailStatus.failure,
          detailDiagnostic: _sessionDiagnostic(
            failure,
            operation: 'load_expense_detail',
          ),
        );
      }
    } on ExpenseFailure catch (failure) {
      if (state.detailExpenseId == expenseId) {
        state = state.copyWith(
          detailStatus: ExpenseDetailStatus.failure,
          detailDiagnostic: _diagnosticFor(
            failure,
            operation: 'load_expense_detail',
          ),
        );
      }
    } on Object {
      if (state.detailExpenseId == expenseId) {
        state = state.copyWith(
          detailStatus: ExpenseDetailStatus.failure,
          detailDiagnostic: _unexpected(operation: 'load_expense_detail'),
        );
      }
    }
  }

  Future<ExpenseMutationOutcome> create({
    required int? accountId,
    required String? amountInput,
    required String? merchant,
    DateTime? occurredAt,
    int? categoryId,
    String? note,
  }) async {
    if (state.mutationStatus != ExpenseMutationStatus.idle) {
      return ExpenseMutationOutcome.ignored;
    }
    final validated = _validateCreate(
      accountId: accountId,
      amountInput: amountInput,
      merchant: merchant,
      occurredAt: occurredAt,
      categoryId: categoryId,
      note: note,
    );
    if (validated == null) {
      return ExpenseMutationOutcome.invalid;
    }
    state = state.copyWith(
      mutationStatus: ExpenseMutationStatus.saving,
      clearLastMutationExpense: true,
      fieldErrors: const {},
      clearMutationDiagnostic: true,
    );
    try {
      final expense = await ref
          .read(expensesRepositoryProvider)
          .create(validated);
      await _acceptMutation(expense);
      return ExpenseMutationOutcome.success;
    } on InvalidSessionFailure catch (failure) {
      _rejectSessionMutation(failure, operation: 'create_expense');
    } on ExpenseFailure catch (failure) {
      await _rejectMutation(failure, operation: 'create_expense');
    } on Object {
      _rejectUnexpectedMutation(operation: 'create_expense');
    }
    return ExpenseMutationOutcome.failure;
  }

  Future<ExpenseMutationOutcome> update({
    required int expenseId,
    String? name,
    String? amountInput,
    String? note,
    bool clearNote = false,
    String? receiptName,
    String? receiptNote,
    int? categoryId,
    bool clearCategory = false,
    int? accountId,
    DateTime? occurredAt,
    String? description,
  }) async {
    if (state.mutationStatus != ExpenseMutationStatus.idle) {
      return ExpenseMutationOutcome.ignored;
    }
    final validated = _validateUpdate(
      name: name,
      amountInput: amountInput,
      note: note,
      clearNote: clearNote,
      receiptName: receiptName,
      receiptNote: receiptNote,
      categoryId: categoryId,
      clearCategory: clearCategory,
      accountId: accountId,
      occurredAt: occurredAt,
      description: description,
    );
    if (validated == null) {
      return ExpenseMutationOutcome.invalid;
    }
    state = state.copyWith(
      mutationStatus: ExpenseMutationStatus.saving,
      clearLastMutationExpense: true,
      fieldErrors: const {},
      clearMutationDiagnostic: true,
    );
    try {
      final expense = await ref
          .read(expensesRepositoryProvider)
          .update(expenseId, validated);
      await _acceptMutation(expense);
      return ExpenseMutationOutcome.success;
    } on InvalidSessionFailure catch (failure) {
      _rejectSessionMutation(failure, operation: 'update_expense');
    } on ExpenseFailure catch (failure) {
      await _rejectMutation(failure, operation: 'update_expense');
    } on Object {
      _rejectUnexpectedMutation(operation: 'update_expense');
    }
    return ExpenseMutationOutcome.failure;
  }

  Future<ExpenseMutationOutcome> deleteExpense(int expenseId) async {
    if (state.mutationStatus != ExpenseMutationStatus.idle) {
      return ExpenseMutationOutcome.ignored;
    }
    state = state.copyWith(
      mutationStatus: ExpenseMutationStatus.saving,
      clearLastMutationExpense: true,
      fieldErrors: const {},
      clearMutationDiagnostic: true,
    );
    try {
      await ref.read(expensesRepositoryProvider).deleteExpense(expenseId);
      await _acceptDeletion(expenseId);
      return ExpenseMutationOutcome.success;
    } on InvalidSessionFailure catch (failure) {
      _rejectSessionMutation(failure, operation: 'delete_expense');
    } on ExpenseFailure catch (failure) {
      final diagnostic = _diagnosticFor(failure, operation: 'delete_expense');
      if (failure.isMutationOutcomeUncertain) {
        final deleted = await _refreshDeletionResolution(expenseId, diagnostic);
        return deleted
            ? ExpenseMutationOutcome.success
            : ExpenseMutationOutcome.failure;
      }
      await _rejectMutation(failure, operation: 'delete_expense');
    } on Object {
      _rejectUnexpectedMutation(operation: 'delete_expense');
    }
    return ExpenseMutationOutcome.failure;
  }

  Future<void> resolveUncertainMutation() async {
    if (!state.requiresMutationReview) {
      return;
    }
    state = state.copyWith(mutationStatus: ExpenseMutationStatus.saving);
    if (await _refreshCanonicalList()) {
      state = state.copyWith(
        mutationStatus: ExpenseMutationStatus.idle,
        clearMutationDiagnostic: true,
      );
    } else {
      state = state.copyWith(
        mutationStatus: ExpenseMutationStatus.reviewRequired,
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
      mutationStatus: ExpenseMutationStatus.idle,
      clearLastMutationExpense: true,
      fieldErrors: const {},
      clearMutationDiagnostic: true,
    );
  }

  ExpenseCreateCommand? _validateCreate({
    required int? accountId,
    required String? amountInput,
    required String? merchant,
    required DateTime? occurredAt,
    required int? categoryId,
    required String? note,
  }) {
    final errors = <String, List<String>>{};
    if (accountId == null || accountId < 1) {
      errors['account_id'] = ['Elige una cuenta activa.'];
    }
    final normalizedMerchant = merchant?.trim() ?? '';
    if (normalizedMerchant.isEmpty) {
      errors['merchant'] = ['Ingresa el comercio o lugar.'];
    } else if (normalizedMerchant.runes.length > 150) {
      errors['merchant'] = ['El comercio debe tener 150 caracteres o menos.'];
    }
    MoneyAmount? amount;
    if (amountInput == null || amountInput.trim().isEmpty) {
      errors['amount'] = ['Ingresa el monto del gasto.'];
    } else {
      amount = MoneyAmount.tryParseUserInput(amountInput);
      if (amount == null || amount.isNegative || amount.minorUnits == 0) {
        errors['amount'] = ['Ingresa un monto positivo válido.'];
      }
    }
    if (categoryId != null && categoryId < 1) {
      errors['category_id'] = ['Elige una de tus categorías.'];
    }
    if (note != null && note.runes.length > 5000) {
      errors['note'] = ['La nota debe tener 5000 caracteres o menos.'];
    }
    if (errors.isNotEmpty || amount == null || accountId == null) {
      state = state.copyWith(
        mutationStatus: ExpenseMutationStatus.idle,
        fieldErrors: Map.unmodifiable(errors),
        mutationDiagnostic: ErrorDiagnostic.capture(
          code: 'expense_invalid',
          operation: 'validate_create_expense',
          userMessage: 'Corrige los campos marcados.',
          technicalReason: 'client_validation',
        ),
      );
      return null;
    }
    return ExpenseCreateCommand(
      accountId: accountId,
      amount: amount,
      merchant: normalizedMerchant,
      occurredAt: occurredAt?.toUtc(),
      categoryId: categoryId,
      note: note?.trim(),
    );
  }

  ExpenseUpdateCommand? _validateUpdate({
    required String? name,
    required String? amountInput,
    required String? note,
    required bool clearNote,
    required String? receiptName,
    required String? receiptNote,
    required int? categoryId,
    required bool clearCategory,
    required int? accountId,
    required DateTime? occurredAt,
    required String? description,
  }) {
    final errors = <String, List<String>>{};
    String? normalizedName;
    if (name != null) {
      normalizedName = name.trim();
      if (normalizedName.isEmpty) {
        errors['name'] = ['Usa un nombre no vacío.'];
      } else if (normalizedName.runes.length > 200) {
        errors['name'] = ['El nombre debe tener 200 caracteres o menos.'];
      }
    }
    MoneyAmount? amount;
    if (amountInput != null) {
      amount = MoneyAmount.tryParseUserInput(amountInput);
      if (amount == null || amount.isNegative || amount.minorUnits == 0) {
        errors['amount'] = ['Ingresa un monto positivo válido.'];
      }
    }
    if (note != null && note.runes.length > 5000) {
      errors['note'] = ['La nota debe tener 5000 caracteres o menos.'];
    }
    String? normalizedReceiptName;
    if (receiptName != null) {
      normalizedReceiptName = receiptName.trim();
      if (normalizedReceiptName.isEmpty) {
        errors['receipt_name'] = ['Usa un nombre de comercio no vacío.'];
      } else if (normalizedReceiptName.runes.length > 150) {
        errors['receipt_name'] = [
          'El comercio debe tener 150 caracteres o menos.',
        ];
      }
    }
    if (receiptNote != null && receiptNote.runes.length > 5000) {
      errors['receipt_note'] = [
        'La nota del recibo debe tener 5000 caracteres o menos.',
      ];
    }
    if (categoryId != null && categoryId < 1) {
      errors['category_id'] = ['Elige una de tus categorías.'];
    }
    if (accountId != null && accountId < 1) {
      errors['account_id'] = ['Elige una cuenta activa.'];
    }
    if (description != null && description.runes.length > 500) {
      errors['description'] = [
        'La descripción debe tener 500 caracteres o menos.',
      ];
    }
    final touched =
        name != null ||
        amountInput != null ||
        note != null ||
        clearNote ||
        receiptName != null ||
        receiptNote != null ||
        categoryId != null ||
        clearCategory ||
        accountId != null ||
        occurredAt != null ||
        description != null;
    if (!touched) {
      errors['request'] = ['Cambia al menos un campo antes de guardar.'];
    }
    if (errors.isNotEmpty) {
      state = state.copyWith(
        mutationStatus: ExpenseMutationStatus.idle,
        fieldErrors: Map.unmodifiable(errors),
        mutationDiagnostic: ErrorDiagnostic.capture(
          code: 'expense_invalid',
          operation: 'validate_expense',
          userMessage: 'Corrige los campos marcados.',
          technicalReason: 'client_validation',
        ),
      );
      return null;
    }
    return ExpenseUpdateCommand(
      name: normalizedName,
      amount: amount,
      note: note,
      clearNote: clearNote,
      receiptName: normalizedReceiptName,
      receiptNote: receiptNote,
      categoryId: categoryId,
      clearCategory: clearCategory,
      accountId: accountId,
      occurredAt: occurredAt?.toUtc(),
      description: description,
    );
  }

  Future<void> _acceptMutation(Expense expense) async {
    state = state.copyWith(
      result: _replaceInResult(state.result, expense),
      detailStatus: state.detailExpenseId == expense.id
          ? ExpenseDetailStatus.ready
          : state.detailStatus,
      detailExpense: state.detailExpenseId == expense.id ? expense : null,
      mutationStatus: ExpenseMutationStatus.saving,
      lastMutationExpense: expense,
      fieldErrors: const {},
      clearMutationDiagnostic: true,
    );
    await _refreshCanonicalList();
    state = state.copyWith(
      mutationStatus: ExpenseMutationStatus.idle,
      clearMutationDiagnostic: true,
    );
  }

  Future<void> _acceptDeletion(int expenseId) async {
    state = state.copyWith(
      result: _removeFromResult(state.result, expenseId),
      detailStatus: ExpenseDetailStatus.initial,
      clearDetailExpenseId: true,
      clearDetailExpense: true,
      clearDetailDiagnostic: true,
      mutationStatus: ExpenseMutationStatus.saving,
      clearLastMutationExpense: true,
      fieldErrors: const {},
      clearMutationDiagnostic: true,
    );
    await _refreshCanonicalList();
    state = state.copyWith(
      mutationStatus: ExpenseMutationStatus.idle,
      clearMutationDiagnostic: true,
    );
  }

  Future<bool> _refreshDeletionResolution(
    int expenseId,
    ErrorDiagnostic diagnostic,
  ) async {
    try {
      final refreshed = await ref
          .read(expensesRepositoryProvider)
          .list(page: 1, pageSize: state.pageSize);
      final stillExists = refreshed.items.any(
        (expense) => expense.id == expenseId,
      );
      state = state.copyWith(
        listStatus: ExpensesLoadStatus.ready,
        result: refreshed,
        page: refreshed.page,
        pageSize: refreshed.pageSize,
        detailStatus: stillExists
            ? state.detailStatus
            : ExpenseDetailStatus.initial,
        clearDetailExpenseId: !stillExists,
        clearDetailExpense: !stillExists,
        clearDetailDiagnostic: !stillExists,
        mutationStatus: ExpenseMutationStatus.idle,
        mutationDiagnostic: stillExists ? diagnostic : null,
        clearMutationDiagnostic: !stillExists,
        clearListDiagnostic: true,
      );
      return !stillExists;
    } on Object {
      state = state.copyWith(
        mutationStatus: ExpenseMutationStatus.reviewRequired,
        mutationDiagnostic: diagnostic,
      );
      return false;
    }
  }

  Future<void> _rejectMutation(
    ExpenseFailure failure, {
    required String operation,
  }) async {
    var refreshed = true;
    if (failure.isMutationOutcomeUncertain) {
      refreshed = await _refreshCanonicalList();
    }
    state = state.copyWith(
      mutationStatus: failure.isMutationOutcomeUncertain && !refreshed
          ? ExpenseMutationStatus.reviewRequired
          : ExpenseMutationStatus.idle,
      mutationDiagnostic: _diagnosticFor(failure, operation: operation),
      fieldErrors: Map.unmodifiable(failure.fieldErrors),
    );
  }

  void _rejectSessionMutation(
    InvalidSessionFailure failure, {
    required String operation,
  }) {
    state = state.copyWith(
      mutationStatus: ExpenseMutationStatus.idle,
      mutationDiagnostic: _sessionDiagnostic(failure, operation: operation),
      fieldErrors: const {},
    );
  }

  void _rejectUnexpectedMutation({required String operation}) {
    state = state.copyWith(
      mutationStatus: ExpenseMutationStatus.idle,
      mutationDiagnostic: _unexpected(operation: operation),
      fieldErrors: const {},
    );
  }

  Future<bool> _refreshCanonicalList() async {
    try {
      final result = await ref
          .read(expensesRepositoryProvider)
          .list(page: state.page, pageSize: state.pageSize);
      state = state.copyWith(
        listStatus: ExpensesLoadStatus.ready,
        result: result,
        page: result.page,
        pageSize: result.pageSize,
        clearListDiagnostic: true,
      );
      final detailId = state.detailExpenseId;
      if (detailId != null) {
        Expense? refreshedDetail;
        for (final expense in result.items) {
          if (expense.id == detailId) {
            refreshedDetail = expense;
          }
        }
        if (refreshedDetail != null) {
          state = state.copyWith(
            detailStatus: ExpenseDetailStatus.ready,
            detailExpense: refreshedDetail,
            clearDetailDiagnostic: true,
          );
        }
      }
      return true;
    } on Object {
      return false;
    }
  }

  Expense? _cachedExpense(int expenseId) {
    final items = state.result?.items;
    if (items == null) {
      return null;
    }
    for (final expense in items) {
      if (expense.id == expenseId) {
        return expense;
      }
    }
    return null;
  }

  ExpenseListResult? _replaceInResult(
    ExpenseListResult? result,
    Expense expense,
  ) {
    if (result == null) {
      return null;
    }
    final items = [...result.items];
    final index = items.indexWhere((item) => item.id == expense.id);
    if (index >= 0) {
      items[index] = expense;
    } else {
      items.insert(0, expense);
    }
    return ExpenseListResult(
      items: List.unmodifiable(items),
      total: result.total,
      page: result.page,
      pageSize: result.pageSize,
      hasNext: result.hasNext,
    );
  }

  ExpenseListResult? _removeFromResult(
    ExpenseListResult? result,
    int expenseId,
  ) {
    if (result == null) {
      return null;
    }
    return ExpenseListResult(
      items: List.unmodifiable(
        result.items.where((expense) => expense.id != expenseId),
      ),
      total: result.total > 0 ? result.total - 1 : 0,
      page: result.page,
      pageSize: result.pageSize,
      hasNext: result.hasNext,
    );
  }

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
