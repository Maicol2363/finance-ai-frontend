import '../../../../core/diagnostics/error_diagnostic.dart';
import '../domain/income_source_models.dart';

enum IncomeSourcesStatus { loading, ready, failure }

class IncomeSourcesState {
  const IncomeSourcesState({
    this.status = IncomeSourcesStatus.loading,
    this.items = const [],
    this.busy = false,
    this.fieldErrors = const {},
    this.diagnostic,
  });

  final IncomeSourcesStatus status;
  final List<IncomeSource> items;
  final bool busy;
  final Map<String, List<String>> fieldErrors;
  final ErrorDiagnostic? diagnostic;

  IncomeSourcesState copyWith({
    IncomeSourcesStatus? status,
    List<IncomeSource>? items,
    bool? busy,
    Map<String, List<String>>? fieldErrors,
    ErrorDiagnostic? diagnostic,
    bool clearDiagnostic = false,
    bool clearFieldErrors = false,
  }) {
    return IncomeSourcesState(
      status: status ?? this.status,
      items: items ?? this.items,
      busy: busy ?? this.busy,
      fieldErrors: clearFieldErrors
          ? const {}
          : (fieldErrors ?? this.fieldErrors),
      diagnostic: clearDiagnostic ? null : (diagnostic ?? this.diagnostic),
    );
  }
}
