import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/error_diagnostic.dart';
import '../../auth/session/domain/session_models.dart';
import '../data/expenses_repository.dart';
import '../domain/expense_models.dart';
import '../domain/history_models.dart';
import 'history_state.dart';

final historyControllerProvider =
    NotifierProvider<HistoryController, HistoryState>(HistoryController.new);

class HistoryController extends Notifier<HistoryState> {
  @override
  HistoryState build() => const HistoryState();

  Future<void> load() async {
    if (state.status == HistoryLoadStatus.loading ||
        state.status == HistoryLoadStatus.loadingMore) {
      return;
    }
    final filters = state.filters;
    state = state.copyWith(
      status: HistoryLoadStatus.loading,
      clearDiagnostic: true,
    );
    try {
      final result = await ref
          .read(expensesRepositoryProvider)
          .history(_firstPage(filters));
      state = state.copyWith(
        status: HistoryLoadStatus.ready,
        result: result,
        clearDiagnostic: true,
      );
    } on InvalidSessionFailure catch (failure) {
      state = state.copyWith(
        status: HistoryLoadStatus.failure,
        diagnostic: _sessionDiagnostic(failure, operation: 'load_history'),
      );
    } on ExpenseFailure catch (failure) {
      state = state.copyWith(
        status: HistoryLoadStatus.failure,
        diagnostic: _diagnosticFor(failure, operation: 'load_history'),
      );
    } on HistoryFailure catch (failure) {
      state = state.copyWith(
        status: HistoryLoadStatus.failure,
        diagnostic: ErrorDiagnostic.capture(
          code: failure.code,
          operation: 'load_history',
          userMessage: failure.userMessage,
          correlationId: failure.correlationId,
          technicalReason: failure.technicalReason,
        ),
      );
    } on Object {
      state = state.copyWith(
        status: HistoryLoadStatus.failure,
        diagnostic: _unexpected(operation: 'load_history'),
      );
    }
  }

  Future<void> loadMore() async {
    final current = state.result;
    if (state.status != HistoryLoadStatus.ready || current == null) {
      return;
    }
    if (!current.hasNext) {
      return;
    }
    state = state.copyWith(
      status: HistoryLoadStatus.loadingMore,
      clearDiagnostic: true,
    );
    try {
      final next = await ref
          .read(expensesRepositoryProvider)
          .history(_page(state.filters, current.page + 1, current.pageSize));
      final combined = HistoryResult(
        items: List.unmodifiable([...current.items, ...next.items]),
        total: next.total,
        page: next.page,
        pageSize: next.pageSize,
        hasNext: next.hasNext,
      );
      state = state.copyWith(
        status: HistoryLoadStatus.ready,
        result: combined,
        clearDiagnostic: true,
      );
    } on InvalidSessionFailure catch (failure) {
      state = state.copyWith(
        status: HistoryLoadStatus.failure,
        diagnostic: _sessionDiagnostic(failure, operation: 'load_more_history'),
      );
    } on ExpenseFailure catch (failure) {
      state = state.copyWith(
        status: HistoryLoadStatus.failure,
        diagnostic: _diagnosticFor(failure, operation: 'load_more_history'),
      );
    } on HistoryFailure catch (failure) {
      state = state.copyWith(
        status: HistoryLoadStatus.failure,
        diagnostic: ErrorDiagnostic.capture(
          code: failure.code,
          operation: 'load_more_history',
          userMessage: failure.userMessage,
          correlationId: failure.correlationId,
          technicalReason: failure.technicalReason,
        ),
      );
    } on Object {
      state = state.copyWith(
        status: HistoryLoadStatus.failure,
        diagnostic: _unexpected(operation: 'load_more_history'),
      );
    }
  }

  Future<void> updateFilters(HistoryFilters filters) async {
    if (state.status == HistoryLoadStatus.loading ||
        state.status == HistoryLoadStatus.loadingMore) {
      return;
    }
    state = state.copyWith(filters: filters);
    await load();
  }

  HistoryFilters _firstPage(HistoryFilters filters) => HistoryFilters(
    search: filters.search,
    type: filters.type,
    categoryId: filters.categoryId,
    accountId: filters.accountId,
    period: filters.period,
    startDate: filters.startDate,
    endDate: filters.endDate,
    page: 1,
    pageSize: filters.pageSize,
  );

  HistoryFilters _page(HistoryFilters filters, int page, int pageSize) =>
      HistoryFilters(
        search: filters.search,
        type: filters.type,
        categoryId: filters.categoryId,
        accountId: filters.accountId,
        period: filters.period,
        startDate: filters.startDate,
        endDate: filters.endDate,
        page: page,
        pageSize: pageSize,
      );

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
