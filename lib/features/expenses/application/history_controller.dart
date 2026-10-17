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
  bool _reloadRequested = false;

  /// Sentinel marking a field as "not provided" in [_composeFilter], so passing
  /// `null` can explicitly clear a filter while omitting it keeps it.
  static const Object _unset = Object();

  @override
  HistoryState build() => const HistoryState();

  Future<void> load() async {
    if (state.status == HistoryLoadStatus.loading ||
        state.status == HistoryLoadStatus.loadingMore) {
      _reloadRequested = true;
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
    } finally {
      if (_reloadRequested) {
        _reloadRequested = false;
        await load();
      }
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
    } finally {
      if (_reloadRequested) {
        _reloadRequested = false;
        await load();
      }
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

  /// Debounced free-text search (empty clears the filter).
  Future<void> setSearch(String search) {
    final trimmed = search.trim();
    return _applyFilters(
      _composeFilter(search: trimmed.isEmpty ? null : trimmed),
    );
  }

  /// Filters by transaction kind; `null` means "all types".
  Future<void> setType(TransactionType? type) =>
      _applyFilters(_composeFilter(type: type));

  /// Applies a period preset. `week`/`month` travel without dates, while
  /// `custom` needs both (HU-011 contract); any other preset clears the range.
  Future<void> setPeriod(
    HistoryPeriod? period, {
    DateTime? startDate,
    DateTime? endDate,
  }) => _applyFilters(
    _composeFilter(
      period: period,
      startDate: period == HistoryPeriod.custom ? startDate : null,
      endDate: period == HistoryPeriod.custom ? endDate : null,
    ),
  );

  /// Filters by account; `null` means "all accounts".
  Future<void> setAccountId(int? accountId) =>
      _applyFilters(_composeFilter(accountId: accountId));

  /// Filters by category; `null` means "all categories".
  Future<void> setCategoryId(int? categoryId) =>
      _applyFilters(_composeFilter(categoryId: categoryId));

  /// Filters by merchant (the receipt store); blank clears it.
  Future<void> setStore(String? store) {
    final trimmed = store?.trim();
    return _applyFilters(
      _composeFilter(
        store: trimmed == null || trimmed.isEmpty ? null : trimmed,
      ),
    );
  }

  /// Filters by capture-source group; `null` means "every source".
  Future<void> setCaptureSource(CaptureSource? captureSource) =>
      _applyFilters(_composeFilter(captureSource: captureSource));

  /// Filters by receipt shape; `null` means "receipts and single expenses".
  Future<void> setReceiptKind(ReceiptKind? receiptKind) =>
      _applyFilters(_composeFilter(receiptKind: receiptKind));

  /// Drops every filter and reloads the first page.
  Future<void> clearFilters() =>
      _applyFilters(HistoryFilters(pageSize: state.filters.pageSize));

  /// Drill-down from the Dashboard: shows the window's movements for one
  /// category (custom range + category id), replacing any previous filters.
  Future<void> showWindowForCategory({
    required int? categoryId,
    required DateTime startDate,
    required DateTime endDate,
  }) => _applyFilters(
    HistoryFilters(
      type: TransactionType.expense,
      categoryId: categoryId,
      period: HistoryPeriod.custom,
      startDate: DateTime.utc(startDate.year, startDate.month, startDate.day),
      endDate: DateTime.utc(endDate.year, endDate.month, endDate.day),
      pageSize: state.filters.pageSize,
    ),
  );

  Future<void> _applyFilters(HistoryFilters filters) async {
    if (state.status == HistoryLoadStatus.loading ||
        state.status == HistoryLoadStatus.loadingMore) {
      return;
    }
    state = state.copyWith(filters: filters);
    await load();
  }

  /// Builds the next filter set from the current one, changing only the fields
  /// passed in so a reload always keeps the rest of the query intact.
  HistoryFilters _composeFilter({
    Object? search = _unset,
    Object? type = _unset,
    Object? categoryId = _unset,
    Object? accountId = _unset,
    Object? period = _unset,
    Object? startDate = _unset,
    Object? endDate = _unset,
    Object? store = _unset,
    Object? captureSource = _unset,
    Object? receiptKind = _unset,
  }) {
    final current = state.filters;
    return HistoryFilters(
      search: _resolve(search, current.search),
      type: _resolve(type, current.type),
      categoryId: _resolve(categoryId, current.categoryId),
      accountId: _resolve(accountId, current.accountId),
      period: _resolve(period, current.period),
      startDate: _resolve(startDate, current.startDate),
      endDate: _resolve(endDate, current.endDate),
      store: _resolve(store, current.store),
      captureSource: _resolve(captureSource, current.captureSource),
      receiptKind: _resolve(receiptKind, current.receiptKind),
      page: 1,
      pageSize: current.pageSize,
    );
  }

  static T _resolve<T>(Object? value, T fallback) =>
      identical(value, _unset) ? fallback : value as T;

  HistoryFilters _firstPage(HistoryFilters filters) => HistoryFilters(
    search: filters.search,
    type: filters.type,
    categoryId: filters.categoryId,
    accountId: filters.accountId,
    period: filters.period,
    startDate: filters.startDate,
    endDate: filters.endDate,
    store: filters.store,
    captureSource: filters.captureSource,
    receiptKind: filters.receiptKind,
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
        store: filters.store,
        captureSource: filters.captureSource,
        receiptKind: filters.receiptKind,
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
