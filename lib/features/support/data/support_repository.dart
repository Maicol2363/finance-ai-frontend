import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/diagnostics/error_diagnostic.dart';
import '../../auth/session/application/auth_session_controller.dart';
import '../../auth/session/domain/session_models.dart';
import '../domain/support_models.dart';

final supportRepositoryProvider = Provider<SupportRepository>(
  (ref) => HttpSupportRepository(
    ref.watch(financeApiClientProvider),
    ref.watch(authSessionControllerProvider.notifier),
  ),
);

abstract interface class SupportRepository {
  Future<List<SupportTicket>> list();
  Future<SupportTicket> create({
    required String subject,
    required String category,
    required String description,
  });
  Future<SupportConversation> read(int id);
  Future<void> send(int id, String body);
}

class SupportFailure implements Exception {
  const SupportFailure(this.diagnostic);
  final ErrorDiagnostic diagnostic;
}

class HttpSupportRepository implements SupportRepository {
  const HttpSupportRepository(this.api, this.session);
  final FinanceApiClient api;
  final AuthSessionController session;

  Future<T> _request<T>(
    String operation,
    Future<ApiResponse> Function(String) call,
    T Function(Map<String, Object?>) decode,
  ) {
    return session.runProtected((credential) async {
      try {
        final response = await call(credential);
        if (response.statusCode == 401) {
          throw InvalidSessionFailure(
            correlationId: response.correlationId ?? 'unavailable',
          );
        }
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return decode(response.body ?? {});
        }
        const codes = {
          'support_ticket_not_found',
          'support_ticket_state_conflict',
          'request_invalid',
          'validation_error',
          'service_unavailable',
          'staff_access_denied',
        };
        final code = response.body?['code'];
        throw SupportFailure(
          ErrorDiagnostic.capture(
            code: code is String && codes.contains(code)
                ? code
                : 'unexpected_response',
            operation: operation,
            userMessage: response.statusCode == 409
                ? 'El estado del ticket cambió. Actualiza la conversación.'
                : 'No se pudo completar la operación de soporte.',
            technicalReason: 'http_${response.statusCode}',
            correlationId: response.correlationId ?? 'unavailable',
          ),
        );
      } on ApiTransportException catch (error) {
        throw SupportFailure(
          ErrorDiagnostic.capture(
            code: error.kind == ApiTransportFailureKind.invalidResponse
                ? 'invalid_response'
                : 'network_error',
            operation: operation,
            userMessage: 'No se pudo conectar con soporte. Intenta de nuevo.',
            technicalReason: error.safeReason,
            correlationId: error.correlationId,
          ),
        );
      } on FormatException {
        throw _invalid(operation);
      } on TypeError {
        throw _invalid(operation);
      }
    });
  }

  SupportFailure _invalid(String operation) => SupportFailure(
    ErrorDiagnostic.capture(
      code: 'invalid_response',
      operation: operation,
      userMessage: 'La respuesta de soporte no es válida.',
      technicalReason: 'invalid_support_payload',
    ),
  );

  @override
  Future<List<SupportTicket>> list() => _request(
    'support_list',
    (credential) =>
        api.getJson('/api/v1/support/tickets', bearerCredential: credential),
    (json) => (json['tickets'] as List<Object?>)
        .map((item) => SupportTicket.fromJson(item as Map<String, Object?>))
        .toList(growable: false),
  );
  @override
  Future<SupportTicket> create({
    required String subject,
    required String category,
    required String description,
  }) => _request(
    'support_create',
    (credential) => api.postJson('/api/v1/support/tickets', {
      'subject': subject,
      'category': category,
      'description': description,
    }, bearerCredential: credential),
    SupportTicket.fromJson,
  );
  @override
  Future<SupportConversation> read(int id) => _request(
    'support_read',
    (credential) => api.getJson(
      '/api/v1/support/tickets/$id',
      bearerCredential: credential,
    ),
    SupportConversation.fromJson,
  );
  @override
  Future<void> send(int id, String body) => _request<void>(
    'support_send',
    (credential) => api.postJson('/api/v1/support/tickets/$id/messages', {
      'body': body,
    }, bearerCredential: credential),
    (_) {},
  );
}
