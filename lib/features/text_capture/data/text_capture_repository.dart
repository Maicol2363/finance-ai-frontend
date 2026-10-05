import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_problem.dart';
import '../../../core/config/app_config.dart';
import '../../auth/session/application/auth_session_controller.dart';
import '../../auth/session/domain/session_models.dart';
import '../domain/text_capture_models.dart';

final textCaptureRepositoryProvider = Provider<TextCaptureRepository>((ref) {
  return HttpTextCaptureRepository(
    ref.watch(financeApiClientProvider),
    ref.watch(authSessionControllerProvider.notifier),
  );
});

abstract interface class TextCaptureRepository {
  /// Sends one chat turn. Pass [proposalId] to correct or answer an earlier
  /// proposal (the server keeps the original text), and [choice] when the user
  /// tapped one of its options.
  Future<TextProposal> propose({
    required DateTime clientNow,
    String? text,
    String? proposalId,
    ({String field, String value})? choice,
  });

  Future<TextCaptureConfirmation> confirm(
    String proposalId,
    TextProposalConfirmCommand command,
  );

  Future<void> discard(String proposalId);
}

/// `2026-10-02T15:30:00.000-05:00`: the API needs the UTC offset to resolve
/// words like "ayer" and "hoy" in the user's own day.
String isoWithOffset(DateTime moment) {
  final local = moment.toLocal();
  final offset = local.timeZoneOffset;
  final absolute = offset.abs();
  final hours = absolute.inHours.toString().padLeft(2, '0');
  final minutes = (absolute.inMinutes % 60).toString().padLeft(2, '0');
  final sign = offset.isNegative ? '-' : '+';
  return '${local.toIso8601String()}$sign$hours:$minutes';
}

class HttpTextCaptureRepository implements TextCaptureRepository {
  const HttpTextCaptureRepository(this._apiClient, this._sessionController);

  static const _base = '/api/v1/capture/text/proposals';

  final FinanceApiClient _apiClient;
  final AuthSessionController _sessionController;

  @override
  Future<TextProposal> propose({
    required DateTime clientNow,
    String? text,
    String? proposalId,
    ({String field, String value})? choice,
  }) {
    return _sessionController.runProtected((credential) async {
      final response = await _transport(
        () => _apiClient.postJson(
          _base,
          {
            'text': ?text,
            'client_now': isoWithOffset(clientNow),
            'proposal_id': ?proposalId,
            if (choice != null)
              'choice': {'field': choice.field, 'value': choice.value},
          },
          bearerCredential: credential,
          timeout: AppConfig.textCaptureTimeout,
        ),
        unreachable: 'No pude conectar con el servidor. Revisa tu conexión.',
      );
      if (response.statusCode == 201) {
        return _parse(response, TextProposal.fromJson);
      }
      throw _failure(response);
    });
  }

  @override
  Future<TextCaptureConfirmation> confirm(
    String proposalId,
    TextProposalConfirmCommand command,
  ) {
    return _sessionController.runProtected((credential) async {
      final response = await _transport(
        () => _apiClient.postJson(
          '$_base/$proposalId/confirm',
          command.toJson(),
          bearerCredential: credential,
        ),
        unreachable:
            'No pudimos confirmar si se guardó. Reintenta: no se duplicará.',
        isMutation: true,
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return _parse(response, TextCaptureConfirmation.fromJson);
      }
      throw _failure(response);
    });
  }

  @override
  Future<void> discard(String proposalId) {
    return _sessionController.runProtected((credential) async {
      final response = await _transport(
        () => _apiClient.deleteRequest(
          '$_base/$proposalId',
          bearerCredential: credential,
        ),
        unreachable: 'No pude conectar con el servidor.',
      );
      if (response.statusCode == 204 || response.statusCode == 200) {
        return;
      }
      throw _failure(response);
    });
  }

  Future<ApiResponse> _transport(
    Future<ApiResponse> Function() request, {
    required String unreachable,
    bool isMutation = false,
  }) async {
    try {
      return await request();
    } on ApiTransportException catch (failure) {
      final invalid = failure.kind == ApiTransportFailureKind.invalidResponse;
      final timedOut = failure.kind == ApiTransportFailureKind.timeout;
      throw TextCaptureFailure(
        code: invalid
            ? 'unexpected_response'
            : timedOut
            ? 'request_timeout'
            : 'network_unavailable',
        userMessage: invalid
            ? 'El servicio respondió algo inesperado. Inténtalo de nuevo.'
            : timedOut
            ? 'La respuesta tardó demasiado. Puedes reintentar.'
            : unreachable,
        correlationId: failure.correlationId,
        technicalReason: failure.safeReason,
        isMutationOutcomeUncertain: isMutation,
      );
    }
  }

  T _parse<T>(ApiResponse response, T Function(Map<String, Object?>) build) {
    final body = response.body;
    try {
      if (body == null) {
        throw const FormatException('Expected a JSON response body');
      }
      return build(body);
    } on FormatException {
      throw TextCaptureFailure(
        code: 'unexpected_response',
        userMessage:
            'El servicio respondió algo inesperado. Inténtalo de nuevo.',
        correlationId: response.correlationId ?? 'unavailable',
        technicalReason: 'invalid_text_capture_payload',
      );
    }
  }

  Exception _failure(ApiResponse response) {
    final body = response.body;
    final problem = body != null
        ? ApiProblem.fromJson(body, response.statusCode)
        : ApiProblem(
            status: response.statusCode,
            code: 'unexpected_response',
            detail: '',
            correlationId: response.correlationId ?? 'unavailable',
          );
    if (problem.code == 'authentication_required' ||
        problem.code == 'session_invalid') {
      return InvalidSessionFailure(
        correlationId: problem.correlationId,
        technicalReason: 'http_${response.statusCode}',
      );
    }
    final (message, retryable) = switch (problem.code) {
      'text_capture_unavailable' => (
        'No pude leer tu mensaje ahora. Reintenta o usa el formulario manual.',
        true,
      ),
      'text_capture_not_configured' => (
        'El asistente de IA aún no está configurado en el servidor. Usa el formulario manual.',
        false,
      ),
      'text_capture_rate_limited' => (
        'Vas muy rápido. Espera un momento y reintenta.',
        true,
      ),
      'text_proposal_not_found' => (
        'Ese borrador ya no está disponible. Escribe tu mensaje de nuevo.',
        false,
      ),
      'text_proposal_closed' => (
        'Ese borrador ya fue cerrado. Escribe tu mensaje de nuevo.',
        false,
      ),
      'request_invalid' => (
        'Revisa los datos del borrador e inténtalo de nuevo.',
        false,
      ),
      'expense_account_invalid' ||
      'income_account_unavailable' ||
      'transfer_account_unavailable' => (
        'Esa cuenta ya no está disponible. Elige otra.',
        false,
      ),
      'expense_category_not_found' => (
        'Esa categoría ya no existe. Elige otra.',
        false,
      ),
      'income_source_unavailable' => (
        'Esa fuente de ingreso ya no existe. Elige otra.',
        false,
      ),
      'transfer_same_account' => (
        'Elige dos cuentas distintas para la transferencia.',
        false,
      ),
      'transfer_destination_amount_required' => (
        'Indica el monto que llega a la cuenta de destino.',
        false,
      ),
      'transfer_source_destination_mismatch' => (
        'En la misma moneda el monto debe ser igual en ambas cuentas.',
        false,
      ),
      _ => ('La operación no se pudo completar. Inténtalo de nuevo.', true),
    };
    return TextCaptureFailure(
      code: problem.code,
      userMessage: message,
      correlationId: problem.correlationId,
      technicalReason: 'http_${response.statusCode}',
      isRetryable: retryable,
    );
  }
}
