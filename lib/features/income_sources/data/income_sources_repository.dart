import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_problem.dart';
import '../domain/income_source_models.dart';

final incomeSourcesRepositoryProvider = Provider<IncomeSourcesRepository>((
  ref,
) {
  return HttpIncomeSourcesRepository(ref.watch(financeApiClientProvider));
});

abstract interface class IncomeSourcesRepository {
  Future<List<IncomeSource>> list({required String accessCredential});

  Future<IncomeSource> create({
    required String accessCredential,
    required String name,
  });

  Future<IncomeSource> rename({
    required String accessCredential,
    required int id,
    required String name,
  });

  Future<void> delete({required String accessCredential, required int id});
}

class HttpIncomeSourcesRepository implements IncomeSourcesRepository {
  const HttpIncomeSourcesRepository(this._apiClient);

  final FinanceApiClient _apiClient;
  static const _basePath = '/api/v1/income-sources';

  @override
  Future<List<IncomeSource>> list({required String accessCredential}) async {
    final response = await _send(
      () => _apiClient.getJson(_basePath, bearerCredential: accessCredential),
    );
    if (response.statusCode == 200) {
      final items = _requireBody(response)['items'];
      if (items is! List<Object?>) {
        throw _unexpected(response);
      }
      try {
        return items
            .whereType<Map<String, Object?>>()
            .map(IncomeSource.fromJson)
            .toList(growable: false);
      } on FormatException {
        throw _unexpected(response);
      }
    }
    throw _failureFrom(response);
  }

  @override
  Future<IncomeSource> create({
    required String accessCredential,
    required String name,
  }) async {
    final response = await _send(
      () => _apiClient.postJson(_basePath, {
        'name': name,
      }, bearerCredential: accessCredential),
    );
    if (response.statusCode == 201) {
      return _parseSource(response);
    }
    throw _failureFrom(response);
  }

  @override
  Future<IncomeSource> rename({
    required String accessCredential,
    required int id,
    required String name,
  }) async {
    final response = await _send(
      () => _apiClient.patchJson('$_basePath/$id', {
        'name': name,
      }, bearerCredential: accessCredential),
    );
    if (response.statusCode == 200) {
      return _parseSource(response);
    }
    throw _failureFrom(response);
  }

  @override
  Future<void> delete({
    required String accessCredential,
    required int id,
  }) async {
    final response = await _send(
      () => _apiClient.deleteRequest(
        '$_basePath/$id',
        bearerCredential: accessCredential,
      ),
    );
    if (response.statusCode == 204) {
      return;
    }
    throw _failureFrom(response);
  }

  Future<ApiResponse> _send(Future<ApiResponse> Function() call) async {
    try {
      return await call();
    } on ApiTransportException catch (failure) {
      final invalidResponse =
          failure.kind == ApiTransportFailureKind.invalidResponse;
      throw IncomeSourcesRetryableFailure(
        code: invalidResponse ? 'unexpected_response' : 'network_unavailable',
        userMessage: invalidResponse
            ? 'The service returned an unexpected response. Please try again.'
            : 'We could not reach the service. Check your connection and try again.',
        correlationId: failure.correlationId,
        technicalReason: failure.safeReason,
      );
    }
  }

  IncomeSource _parseSource(ApiResponse response) {
    try {
      return IncomeSource.fromJson(_requireBody(response));
    } on FormatException {
      throw _unexpected(response);
    }
  }

  Map<String, Object?> _requireBody(ApiResponse response) {
    final body = response.body;
    if (body == null) {
      throw const FormatException('Expected a JSON response body');
    }
    return body;
  }

  IncomeSourcesFailure _unexpected(ApiResponse response) {
    return IncomeSourcesRetryableFailure(
      code: 'unexpected_response',
      userMessage:
          'The service returned an unexpected response. Please try again.',
      correlationId: response.correlationId ?? 'unavailable',
      technicalReason: 'invalid_payload',
    );
  }

  IncomeSourcesFailure _failureFrom(ApiResponse response) {
    late final ApiProblem problem;
    try {
      problem = ApiProblem.fromJson(
        _requireBody(response),
        response.statusCode,
      );
    } on FormatException {
      return _unexpected(response);
    }
    switch (problem.code) {
      case 'income_source_invalid':
        return IncomeSourcesValidationFailure(
          userMessage: 'Revisa el nombre de la fuente de ingreso.',
          fieldErrors: problem.fieldErrors.containsKey('name')
              ? const {
                  'name': ['Revisa el nombre de la fuente de ingreso.'],
                }
              : const {},
          correlationId: problem.correlationId,
          technicalReason: 'http_${response.statusCode}',
        );
      case 'income_source_name_taken':
        return IncomeSourcesConflictFailure(
          userMessage: 'Ya existe una fuente de ingreso con ese nombre.',
          correlationId: problem.correlationId,
          technicalReason: 'http_${response.statusCode}',
        );
      case 'income_source_not_found':
        return IncomeSourcesNotFoundFailure(
          userMessage:
              'This income source no longer exists. Refresh and try again.',
          correlationId: problem.correlationId,
          technicalReason: 'http_${response.statusCode}',
        );
      default:
        return IncomeSourcesRetryableFailure(
          code: 'unexpected_response',
          userMessage: 'La operación no se pudo completar. Inténtalo de nuevo.',
          correlationId: problem.correlationId,
          technicalReason: 'http_${response.statusCode}',
        );
    }
  }
}
