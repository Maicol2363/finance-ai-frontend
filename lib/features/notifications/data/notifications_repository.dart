import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_problem.dart';
import '../../auth/session/application/auth_session_controller.dart';
import '../../auth/session/domain/session_models.dart';
import '../domain/notification_models.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return HttpNotificationsRepository(
    ref.watch(financeApiClientProvider),
    ref.watch(authSessionControllerProvider.notifier),
  );
});

abstract interface class NotificationsRepository {
  Future<NotificationPreferences> load();

  /// Only the fields that are not null are sent, so one switch never overwrites another.
  Future<NotificationPreferences> update({
    bool? emailEnabled,
    bool? budgetAlerts,
    bool? showAmounts,
  });

  Future<VerificationIssued> requestVerification();

  Future<NotificationPreferences> verify(String code);

  Future<TestEmailStatus> sendTestEmail();
}

class HttpNotificationsRepository implements NotificationsRepository {
  const HttpNotificationsRepository(this._apiClient, this._sessionController);

  final FinanceApiClient _apiClient;
  final AuthSessionController _sessionController;

  static const _preferencesPath = '/api/v1/me/notification-preferences';

  @override
  Future<NotificationPreferences> load() => _sessionController.runProtected((
    credential,
  ) async {
    final response = await _transport(
      () => _apiClient.getJson(_preferencesPath, bearerCredential: credential),
      message: 'No pudimos cargar tus avisos. Revisa la conexión e inténtalo de nuevo.',
    );
    if (response.statusCode == 200) {
      return _preferences(response, 'invalid_preferences_payload');
    }
    throw _failure(response, operation: 'Cargar avisos');
  });

  @override
  Future<NotificationPreferences> update({
    bool? emailEnabled,
    bool? budgetAlerts,
    bool? showAmounts,
  }) => _sessionController.runProtected((credential) async {
    final body = <String, Object?>{
      'email_enabled': ?emailEnabled,
      'budget_alerts': ?budgetAlerts,
      'show_amounts': ?showAmounts,
    };
    final response = await _transport(
      () => _apiClient.patchJson(
        _preferencesPath,
        body,
        bearerCredential: credential,
      ),
      message: 'No pudimos confirmar si se guardó el cambio. Actualiza la pantalla antes de reintentar.',
      mutation: true,
    );
    if (response.statusCode == 200) {
      return _preferences(response, 'invalid_preferences_payload');
    }
    throw _failure(response, operation: 'Guardar avisos');
  });

  @override
  Future<VerificationIssued> requestVerification() =>
      _sessionController.runProtected((credential) async {
        final response = await _transport(
          () => _apiClient.postJson(
            '/api/v1/me/email/verification',
            const {},
            bearerCredential: credential,
          ),
          message: 'No pudimos confirmar si se envió el código. Espera un momento y revisa tu correo.',
          mutation: true,
        );
        if (response.statusCode == 200) {
          try {
            return VerificationIssued.fromJson(_body(response));
          } on FormatException {
            throw _invalidSuccess(response, 'invalid_verification_payload');
          }
        }
        throw _failure(response, operation: 'Enviar código');
      });

  @override
  Future<NotificationPreferences> verify(String code) =>
      _sessionController.runProtected((credential) async {
        final response = await _transport(
          () => _apiClient.postJson('/api/v1/me/email/verify', {
            'code': code,
          }, bearerCredential: credential),
          message: 'No pudimos confirmar el código. Revisa la conexión e inténtalo de nuevo.',
          mutation: true,
        );
        if (response.statusCode == 200) {
          return _preferences(response, 'invalid_preferences_payload');
        }
        throw _failure(response, operation: 'Verificar correo');
      });

  @override
  Future<TestEmailStatus> sendTestEmail() =>
      _sessionController.runProtected((credential) async {
        final response = await _transport(
          () => _apiClient.postJson(
            '/api/v1/me/notifications/test',
            const {},
            bearerCredential: credential,
          ),
          message: 'No pudimos confirmar si se envió el correo de prueba. Revisa tu bandeja antes de reintentar.',
          mutation: true,
        );
        if (response.statusCode == 200) {
          return switch (_body(response)['status']) {
            'sent' => TestEmailStatus.sent,
            'queued' => TestEmailStatus.queued,
            _ => throw _invalidSuccess(response, 'invalid_test_payload'),
          };
        }
        throw _failure(response, operation: 'Enviar correo de prueba');
      });

  Future<ApiResponse> _transport(
    Future<ApiResponse> Function() request, {
    required String message,
    bool mutation = false,
  }) async {
    try {
      return await request();
    } on ApiTransportException catch (failure) {
      final invalid = failure.kind == ApiTransportFailureKind.invalidResponse;
      throw NotificationFailure(
        code: invalid ? 'unexpected_response' : 'network_unavailable',
        userMessage: invalid
            ? 'El servicio devolvió una respuesta inesperada. Inténtalo de nuevo.'
            : message,
        correlationId: failure.correlationId,
        technicalReason: failure.safeReason,
        isMutationOutcomeUncertain: mutation,
      );
    }
  }

  NotificationPreferences _preferences(ApiResponse response, String reason) {
    try {
      return NotificationPreferences.fromJson(_body(response));
    } on FormatException {
      throw _invalidSuccess(response, reason);
    }
  }

  Map<String, Object?> _body(ApiResponse response) {
    final body = response.body;
    if (body == null) throw const FormatException('Expected a JSON object');
    return body;
  }

  NotificationFailure _invalidSuccess(
    ApiResponse response,
    String reason,
  ) => NotificationFailure(
    code: 'unexpected_response',
    userMessage:
        'El servicio devolvió una respuesta inesperada. Inténtalo de nuevo.',
    correlationId: response.correlationId ?? 'unavailable',
    technicalReason: reason,
  );

  Exception _failure(ApiResponse response, {required String operation}) {
    final body = response.body;
    final problem = body == null
        ? ApiProblem(
            status: response.statusCode,
            code: 'unexpected_response',
            detail: 'The request could not be completed.',
            correlationId: response.correlationId ?? 'unavailable',
          )
        : ApiProblem.fromJson(body, response.statusCode);
    if (problem.code == 'authentication_required' ||
        problem.code == 'session_invalid') {
      return InvalidSessionFailure(
        correlationId: problem.correlationId,
        technicalReason: 'http_${response.statusCode}',
      );
    }
    final message = switch (problem.code) {
      'email_not_verified' =>
        'Primero verifica tu correo con el código que te enviamos.',
      'email_already_verified' => 'Tu correo ya está verificado.',
      'verification_code_invalid' => 'Ese código no es correcto, o no hay un código pendiente. Pide uno nuevo.',
      'verification_code_expired' =>
        'El código venció. Pide uno nuevo para continuar.',
      'verification_attempts_exceeded' =>
        'Fallaste demasiadas veces. Pide un código nuevo.',
      'verification_cooldown' =>
        'Ya te enviamos un código. Espera un momento antes de pedir otro.',
      'verification_rate_limited' =>
        'Pediste varios códigos seguidos. Inténtalo más tarde.',
      'test_email_rate_limited' =>
        'Ya pediste varios correos de prueba. Inténtalo más tarde.',
      'email_delivery_failed' =>
        'No pudimos enviar el correo ahora. Inténtalo en unos minutos.',
      'notifications_unavailable' =>
        'Los avisos por correo no están disponibles por ahora.',
      'request_invalid' => 'Revisa lo que escribiste e inténtalo de nuevo.',
      _ => '$operation no se pudo completar. Inténtalo de nuevo.',
    };
    return NotificationFailure(
      code: problem.code,
      userMessage: message,
      correlationId: problem.correlationId,
      technicalReason: 'http_${response.statusCode}',
      retryAfterSeconds: int.tryParse(response.headers['retry-after'] ?? ''),
    );
  }
}
