import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_problem.dart';
import '../domain/session_models.dart';

final authSessionRepositoryProvider = Provider<AuthSessionRepository>((ref) {
  return HttpAuthSessionRepository(ref.watch(financeApiClientProvider));
});

abstract interface class AuthSessionRepository {
  Future<IssuedAuthSession> login(LoginRequest request);

  Future<IssuedAuthSession> refresh(String renewableCredential);

  Future<AuthenticatedUser> currentUser(String accessCredential);

  Future<void> logout(String renewableCredential);
}

class HttpAuthSessionRepository implements AuthSessionRepository {
  const HttpAuthSessionRepository(this._apiClient);

  final FinanceApiClient _apiClient;

  @override
  Future<IssuedAuthSession> login(LoginRequest request) async {
    final response = await _transport(
      () => _apiClient.postJson('/api/v1/auth/login', request.toJson()),
      fallbackMessage: 'We could not reach the service. Check your connection and try again.',
    );
    if (response.statusCode == 200) {
      return _decodeSession(response);
    }
    final problem = _problem(response);
    if (problem.code == 'invalid_credentials') {
      throw InvalidCredentialsFailure(
        correlationId: problem.correlationId,
        technicalReason: 'http_${response.statusCode}',
      );
    }
    if (problem.code == 'login_rate_limited') {
      throw AuthRetryableFailure(
        code: 'login_rate_limited',
        userMessage: 'Too many login attempts. Wait a moment, then try again.',
        correlationId: problem.correlationId,
        technicalReason: 'http_${response.statusCode}',
      );
    }
    throw _unexpectedProblem(problem, response.statusCode, operation: 'Login');
  }

  @override
  Future<IssuedAuthSession> refresh(String renewableCredential) async {
    final response = await _transport(
      () => _apiClient.postJson('/api/v1/auth/refresh', {
        'renewable_credential': renewableCredential,
      }),
      fallbackMessage:
          'We could not restore your session. Check your connection and retry.',
    );
    if (response.statusCode == 200) {
      return _decodeSession(response);
    }
    final problem = _problem(response);
    if (problem.code == 'session_invalid' ||
        problem.code == 'authentication_required') {
      throw InvalidSessionFailure(
        correlationId: problem.correlationId,
        technicalReason: 'http_${response.statusCode}',
      );
    }
    throw _unexpectedProblem(
      problem,
      response.statusCode,
      operation: 'Session restoration',
    );
  }

  @override
  Future<AuthenticatedUser> currentUser(String accessCredential) async {
    final response = await _transport(
      () => _apiClient.getJson(
        '/api/v1/auth/me',
        bearerCredential: accessCredential,
      ),
      fallbackMessage: 'We could not validate your session. Please try again.',
    );
    if (response.statusCode == 200) {
      try {
        return AuthenticatedUser.fromJson(_requireBody(response));
      } on FormatException {
        throw _invalidSuccess(response, 'invalid_current_user_payload');
      }
    }
    final problem = _problem(response);
    if (problem.code == 'authentication_required' ||
        problem.code == 'session_invalid') {
      throw InvalidSessionFailure(
        correlationId: problem.correlationId,
        technicalReason: 'http_${response.statusCode}',
      );
    }
    throw _unexpectedProblem(
      problem,
      response.statusCode,
      operation: 'Session validation',
    );
  }

  @override
  Future<void> logout(String renewableCredential) async {
    final response = await _transport(
      () => _apiClient.postJson('/api/v1/auth/logout', {
        'renewable_credential': renewableCredential,
      }),
      fallbackMessage: 'You are logged out on this device, but server revocation could not be confirmed.',
    );
    if (response.statusCode == 204) {
      return;
    }
    final problem = _problem(response);
    throw _unexpectedProblem(
      problem,
      response.statusCode,
      operation: 'Logout',
      userMessage: 'You are logged out on this device, but server revocation could not be confirmed.',
    );
  }

  Future<ApiResponse> _transport(
    Future<ApiResponse> Function() request, {
    required String fallbackMessage,
  }) async {
    try {
      return await request();
    } on ApiTransportException catch (failure) {
      final invalidResponse =
          failure.kind == ApiTransportFailureKind.invalidResponse;
      throw AuthRetryableFailure(
        code: invalidResponse ? 'unexpected_response' : 'network_unavailable',
        userMessage: invalidResponse
            ? 'The service returned an unexpected response. Please try again.'
            : fallbackMessage,
        correlationId: failure.correlationId,
        technicalReason: failure.safeReason,
      );
    }
  }

  IssuedAuthSession _decodeSession(ApiResponse response) {
    try {
      return IssuedAuthSession.fromJson(_requireBody(response));
    } on FormatException {
      throw _invalidSuccess(response, 'invalid_session_payload');
    }
  }

  ApiProblem _problem(ApiResponse response) {
    final body = response.body;
    if (body == null) {
      return ApiProblem(
        status: response.statusCode,
        code: 'unexpected_response',
        detail: 'The request could not be completed.',
        correlationId: response.correlationId ?? 'unavailable',
      );
    }
    return ApiProblem.fromJson(body, response.statusCode);
  }

  Map<String, Object?> _requireBody(ApiResponse response) {
    final body = response.body;
    if (body == null) {
      throw const FormatException('Expected a JSON response body');
    }
    return body;
  }

  AuthRetryableFailure _invalidSuccess(
    ApiResponse response,
    String technicalReason,
  ) {
    return AuthRetryableFailure(
      code: 'unexpected_response',
      userMessage:
          'The service returned an unexpected response. Please try again.',
      correlationId: response.correlationId ?? 'unavailable',
      technicalReason: technicalReason,
    );
  }

  AuthRetryableFailure _unexpectedProblem(
    ApiProblem problem,
    int statusCode, {
    required String operation,
    String? userMessage,
  }) {
    return AuthRetryableFailure(
      code: problem.code == 'service_unavailable'
          ? 'service_unavailable'
          : 'unexpected_response',
      userMessage:
          userMessage ?? '$operation could not be completed. Please try again.',
      correlationId: problem.correlationId,
      technicalReason: 'http_$statusCode',
    );
  }
}
