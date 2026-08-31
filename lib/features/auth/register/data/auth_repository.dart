import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_problem.dart';
import '../domain/registration_models.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return HttpAuthRepository(ref.watch(financeApiClientProvider));
});

abstract interface class AuthRepository {
  Future<RegistrationResult> register(RegistrationRequest request);
}

class HttpAuthRepository implements AuthRepository {
  const HttpAuthRepository(this._apiClient);

  final FinanceApiClient _apiClient;

  @override
  Future<RegistrationResult> register(RegistrationRequest request) async {
    late final ApiResponse response;
    try {
      response = await _apiClient.postJson(
        '/api/v1/auth/register',
        request.toJson(),
      );
    } on ApiTransportException catch (failure) {
      final invalidResponse =
          failure.kind == ApiTransportFailureKind.invalidResponse;
      throw RegistrationRetryableFailure(
        code: invalidResponse ? 'unexpected_response' : 'network_unavailable',
        userMessage: invalidResponse
            ? 'The service returned an unexpected response. Please try again.'
            : 'We could not reach the service. Check your connection and try again.',
        correlationId: failure.correlationId,
        technicalReason: failure.safeReason,
      );
    }

    if (response.statusCode == 201) {
      try {
        return RegistrationResult.fromJson(_requireBody(response));
      } on FormatException {
        throw RegistrationRetryableFailure(
          code: 'unexpected_response',
          userMessage:
              'The service returned an unexpected response. Please try again.',
          correlationId: response.correlationId ?? 'unavailable',
          technicalReason: 'invalid_success_payload',
        );
      }
    }

    late final ApiProblem problem;
    try {
      problem = ApiProblem.fromJson(
        _requireBody(response),
        response.statusCode,
      );
    } on FormatException {
      throw RegistrationRetryableFailure(
        code: 'unexpected_response',
        userMessage:
            'The service returned an unexpected response. Please try again.',
        correlationId: response.correlationId ?? 'unavailable',
        technicalReason: 'missing_problem_payload',
      );
    }
    switch (problem.code) {
      case 'registration_invalid':
        throw RegistrationValidationFailure(
          userMessage: problem.detail,
          fieldErrors: problem.fieldErrors,
          correlationId: problem.correlationId,
          technicalReason: 'http_${response.statusCode}',
        );
      case 'email_already_registered':
        throw RegistrationConflictFailure(
          userMessage: problem.detail,
          correlationId: problem.correlationId,
          technicalReason: 'http_${response.statusCode}',
        );
      case 'registration_rate_limited':
        throw RegistrationRetryableFailure(
          code: 'registration_rate_limited',
          userMessage: 'Too many attempts. Wait a moment, then try again.',
          correlationId: problem.correlationId,
          technicalReason: 'http_${response.statusCode}',
        );
      case 'service_unavailable':
        throw RegistrationRetryableFailure(
          code: 'service_unavailable',
          userMessage: 'Registration is temporarily unavailable. Please try again later.',
          correlationId: problem.correlationId,
          technicalReason: 'http_${response.statusCode}',
        );
      default:
        throw RegistrationRetryableFailure(
          code: 'unexpected_response',
          userMessage: 'Registration could not be completed. Please try again.',
          correlationId: problem.correlationId,
          technicalReason: 'http_${response.statusCode}',
        );
    }
  }

  Map<String, Object?> _requireBody(ApiResponse response) {
    final body = response.body;
    if (body == null) {
      throw const FormatException('Expected a JSON response body');
    }
    return body;
  }
}
