import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_problem.dart';
import '../../auth/session/application/auth_session_controller.dart';
import '../../auth/session/domain/session_models.dart';
import '../domain/transfer_models.dart';

final transfersRepositoryProvider = Provider<TransfersRepository>((ref) {
  return HttpTransfersRepository(
    ref.watch(financeApiClientProvider),
    ref.watch(authSessionControllerProvider.notifier),
  );
});

abstract interface class TransfersRepository {
  Future<Transfer> create(TransferCreateCommand command);
}

class HttpTransfersRepository implements TransfersRepository {
  const HttpTransfersRepository(this._apiClient, this._sessionController);

  final FinanceApiClient _apiClient;
  final AuthSessionController _sessionController;

  @override
  Future<Transfer> create(TransferCreateCommand command) {
    return _sessionController.runProtected((accessCredential) async {
      final response = await _transport(
        () => _apiClient.postJson(
          '/api/v1/transfers',
          command.toJson(),
          bearerCredential: accessCredential,
        ),
        operationMessage: 'No pudimos confirmar si la transferencia se guardó. Actualiza tus cuentas antes de reintentar.',
        isMutation: true,
      );
      if (response.statusCode == 201) {
        try {
          return Transfer.fromJson(_requireBody(response));
        } on FormatException {
          throw _invalidSuccess(response, 'invalid_transfer_payload');
        }
      }
      throw _failure(response, operation: 'Transfer creation');
    });
  }

  Future<ApiResponse> _transport(
    Future<ApiResponse> Function() request, {
    required String operationMessage,
    bool isMutation = false,
  }) async {
    try {
      return await request();
    } on ApiTransportException catch (failure) {
      final invalidResponse =
          failure.kind == ApiTransportFailureKind.invalidResponse;
      throw TransferFailure(
        code: invalidResponse ? 'unexpected_response' : 'network_unavailable',
        userMessage: invalidResponse
            ? 'El servicio devolvió una respuesta inesperada. Inténtalo de nuevo.'
            : operationMessage,
        correlationId: failure.correlationId,
        technicalReason: failure.safeReason,
        isMutationOutcomeUncertain: isMutation,
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

  TransferFailure _invalidSuccess(
    ApiResponse response,
    String technicalReason,
  ) {
    return TransferFailure(
      code: 'unexpected_response',
      userMessage:
          'El servicio devolvió una respuesta inesperada. Inténtalo de nuevo.',
      correlationId: response.correlationId ?? 'unavailable',
      technicalReason: technicalReason,
    );
  }

  Exception _failure(ApiResponse response, {required String operation}) {
    final problem = _problem(response);
    if (problem.code == 'authentication_required' ||
        problem.code == 'session_invalid') {
      return InvalidSessionFailure(
        correlationId: problem.correlationId,
        technicalReason: 'http_${response.statusCode}',
      );
    }
    final known = switch (problem.code) {
      'transfer_account_unavailable' =>
        'Elige una de tus cuentas activas e inténtalo de nuevo.',
      'transfer_same_account' =>
        'Elige dos cuentas distintas para la transferencia.',
      'transfer_destination_amount_required' =>
        'Indica el monto que llega en la moneda de destino.',
      'transfer_source_destination_mismatch' =>
        'En la misma moneda el monto debe ser igual en ambos lados.',
      'transfer_insufficient_funds' =>
        'La cuenta de origen no tiene fondos suficientes.',
      'request_invalid' => 'Corrige los campos marcados.',
      _ => null,
    };
    return TransferFailure(
      code: known == null
          ? problem.code == 'service_unavailable'
                ? 'service_unavailable'
                : 'unexpected_response'
          : problem.code,
      userMessage:
          known ?? 'La operación no se pudo completar. Inténtalo de nuevo.',
      fieldErrors: Map.unmodifiable(problem.fieldErrors),
      correlationId: problem.correlationId,
      technicalReason: 'http_${response.statusCode}',
      isMutationOutcomeUncertain: known == null,
    );
  }

  ApiProblem _problem(ApiResponse response) {
    final body = response.body;
    if (body == null) {
      return ApiProblem(
        status: response.statusCode,
        code: 'unexpected_response',
        detail: 'La solicitud no se pudo completar.',
        correlationId: response.correlationId ?? 'unavailable',
      );
    }
    return ApiProblem.fromJson(body, response.statusCode);
  }
}
