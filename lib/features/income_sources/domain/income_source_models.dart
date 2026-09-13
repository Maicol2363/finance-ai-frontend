class IncomeSource {
  const IncomeSource({required this.id, required this.name});

  factory IncomeSource.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! int || name is! String) {
      throw const FormatException('Invalid income source response');
    }
    return IncomeSource(id: id, name: name);
  }

  final int id;
  final String name;
}

sealed class IncomeSourcesFailure implements Exception {
  const IncomeSourcesFailure({
    required this.code,
    required this.userMessage,
    this.fieldErrors = const {},
    this.correlationId = 'unavailable',
    this.technicalReason = 'application_failure',
  });

  final String code;
  final String userMessage;
  final Map<String, List<String>> fieldErrors;
  final String correlationId;
  final String technicalReason;
}

class IncomeSourcesValidationFailure extends IncomeSourcesFailure {
  const IncomeSourcesValidationFailure({
    required super.userMessage,
    required super.fieldErrors,
    super.correlationId,
    super.technicalReason = 'validation_failure',
  }) : super(code: 'income_source_invalid');
}

class IncomeSourcesConflictFailure extends IncomeSourcesFailure {
  const IncomeSourcesConflictFailure({
    required super.userMessage,
    super.correlationId,
    super.technicalReason = 'duplicate_conflict',
  }) : super(code: 'income_source_name_taken');
}

class IncomeSourcesNotFoundFailure extends IncomeSourcesFailure {
  const IncomeSourcesNotFoundFailure({
    required super.userMessage,
    super.correlationId,
    super.technicalReason = 'missing_resource',
  }) : super(code: 'income_source_not_found');
}

class IncomeSourcesRetryableFailure extends IncomeSourcesFailure {
  const IncomeSourcesRetryableFailure({
    required super.code,
    required super.userMessage,
    super.correlationId,
    super.technicalReason = 'retryable_failure',
  });
}
