import '../../../core/diagnostics/error_diagnostic.dart';
import '../domain/history_models.dart';

enum HistoryLoadStatus { initial, loading, ready, loadingMore, failure }

class HistoryState {
  const HistoryState({
    this.status = HistoryLoadStatus.initial,
    this.result,
    this.filters = const HistoryFilters(),
    this.diagnostic,
  });

  final HistoryLoadStatus status;
  final HistoryResult? result;
  final HistoryFilters filters;
  final ErrorDiagnostic? diagnostic;

  HistoryState copyWith({
    HistoryLoadStatus? status,
    HistoryResult? result,
    bool clearResult = false,
    HistoryFilters? filters,
    ErrorDiagnostic? diagnostic,
    bool clearDiagnostic = false,
  }) {
    return HistoryState(
      status: status ?? this.status,
      result: clearResult ? null : result ?? this.result,
      filters: filters ?? this.filters,
      diagnostic: clearDiagnostic ? null : diagnostic ?? this.diagnostic,
    );
  }
}
