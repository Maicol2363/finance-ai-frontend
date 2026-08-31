class ApiProblem {
  const ApiProblem({
    required this.status,
    required this.code,
    required this.detail,
    required this.correlationId,
    this.fieldErrors = const {},
  });

  factory ApiProblem.fromJson(Map<String, Object?> json, int fallbackStatus) {
    final rawFieldErrors = json['field_errors'];
    final fieldErrors = <String, List<String>>{};
    if (rawFieldErrors is Map<String, Object?>) {
      for (final entry in rawFieldErrors.entries) {
        final value = entry.value;
        if (value is List<Object?>) {
          final messages = value.whereType<String>().toList(growable: false);
          if (messages.isNotEmpty) {
            fieldErrors[entry.key] = messages;
          }
        }
      }
    }
    return ApiProblem(
      status: json['status'] is int ? json['status']! as int : fallbackStatus,
      code: json['code'] is String
          ? json['code']! as String
          : 'unexpected_response',
      detail: json['detail'] is String
          ? json['detail']! as String
          : 'The request could not be completed.',
      correlationId: json['correlation_id'] is String
          ? json['correlation_id']! as String
          : 'unavailable',
      fieldErrors: fieldErrors,
    );
  }

  final int status;
  final String code;
  final String detail;
  final String correlationId;
  final Map<String, List<String>> fieldErrors;
}
