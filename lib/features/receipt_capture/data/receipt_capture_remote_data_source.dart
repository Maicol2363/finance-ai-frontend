import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_problem.dart';
import '../../../core/config/app_config.dart';
import '../../auth/session/application/auth_session_controller.dart';
import '../../auth/session/domain/session_models.dart';
import '../../expenses/domain/expense_models.dart';
import '../domain/receipt_proposal_dto.dart';

final receiptCaptureRemoteDataSourceProvider =
    Provider<ReceiptCaptureRemoteDataSource>((ref) {
      return ReceiptCaptureRemoteDataSource(
        ref.watch(financeApiClientProvider),
        ref.watch(authSessionControllerProvider.notifier),
      );
    });

class ReceiptCaptureRemoteDataSource {
  ReceiptCaptureRemoteDataSource(this._apiClient, this._sessionController);

  final FinanceApiClient _apiClient;
  final AuthSessionController _sessionController;

  Future<ReceiptProposalResponseDto> uploadProposal({
    required String filePath,
    int rotationDegrees = 0,
  }) {
    return _sessionController.runProtected((credential) async {
      final response = await _apiClient.postMultipart(
        '/api/v1/receipts/proposal?rotation=$rotationDegrees',
        filePath: filePath,
        fileField: 'file',
        bearerCredential: credential,
        timeout: AppConfig.aiRequestTimeout,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ReceiptProposalResponseDto.fromJson(_requireBody(response));
      }
      throw _failure(response, operation: 'upload_receipt');
    });
  }

  Future<ReceiptProposalResponseDto> retryProposal({
    required String proposalId,
    required String filePath,
    int rotationDegrees = 0,
  }) {
    return _sessionController.runProtected((credential) async {
      final response = await _apiClient.postMultipart(
        '/api/v1/receipts/proposal/$proposalId/retry?rotation_degrees=$rotationDegrees&rotation=$rotationDegrees',
        filePath: filePath,
        fileField: 'file',
        fields: {'rotation_degrees': rotationDegrees.toString()},
        bearerCredential: credential,
        timeout: AppConfig.aiRequestTimeout,
      );
      if (response.statusCode == 200) {
        return ReceiptProposalResponseDto.fromJson(_requireBody(response));
      }
      throw _failure(response, operation: 'retry_proposal');
    });
  }

  Future<void> discardProposal({required String proposalId}) {
    return _sessionController.runProtected((credential) async {
      final response = await _apiClient.deleteRequest(
        '/api/v1/receipts/proposal/$proposalId',
        bearerCredential: credential,
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      }
      throw _failure(response, operation: 'discard_proposal');
    });
  }

  Future<Expense> confirmProposal({
    required String proposalId,
    required ReceiptProposalConfirmRequestDto command,
  }) {
    return _sessionController.runProtected((credential) async {
      final response = await _apiClient.postJson(
        '/api/v1/receipts/proposal/$proposalId/confirm',
        command.toJson(),
        bearerCredential: credential,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Expense.fromJson(_requireBody(response));
      }
      throw _failure(response, operation: 'confirm_proposal');
    });
  }

  Map<String, Object?> _requireBody(ApiResponse response) {
    final body = response.body;
    if (body == null) {
      throw ExpenseFailure(
        code: 'unexpected_response',
        userMessage: 'El servicio devolvió una respuesta vacía.',
        correlationId: response.correlationId ?? 'unavailable',
        technicalReason: 'empty_response_body',
      );
    }
    return body;
  }

  Exception _failure(ApiResponse response, {required String operation}) {
    final body = response.body;
    final problem = body != null
        ? ApiProblem.fromJson(body, response.statusCode)
        : ApiProblem(
            status: response.statusCode,
            code: 'unexpected_response',
            detail: 'La solicitud no se pudo completar.',
            correlationId: response.correlationId ?? 'unavailable',
          );

    if (problem.code == 'authentication_required' ||
        problem.code == 'session_invalid') {
      return InvalidSessionFailure(
        correlationId: problem.correlationId,
        technicalReason: 'http_${response.statusCode}',
      );
    }

    final known = switch (problem.code) {
      'expense_not_found' => 'El borrador de recibo ya no está disponible.',
      'receipt_proposal_not_found' =>
        'El borrador de recibo ya no está disponible.',
      'request_invalid' => 'Corrige los datos del recibo e inténtalo de nuevo.',
      'receipt_unreadable' => 'La imagen del recibo no se pudo leer.',
      'unsupported_media_type' => 'El formato de imagen no es soportado.',
      'payload_too_large' =>
        'La imagen excede el tamaño máximo permitido de 10 MB.',
      'too_many_requests' =>
        'Has alcanzado el límite de intentos. Espera un momento.',
      'conflict' => 'Esta propuesta ya fue confirmada o descartada.',
      _ => 'No se pudo completar la solicitud del recibo. Inténtalo de nuevo.',
    };

    final safeCode = switch (problem.code) {
      'expense_not_found' ||
      'receipt_proposal_not_found' ||
      'request_invalid' ||
      'receipt_unreadable' ||
      'unsupported_media_type' ||
      'payload_too_large' ||
      'too_many_requests' ||
      'conflict' => problem.code,
      _ => 'unexpected_response',
    };

    return ExpenseFailure(
      code: safeCode,
      userMessage: known,
      fieldErrors: const {},
      correlationId: problem.correlationId,
      technicalReason: 'http_${response.statusCode}',
    );
  }
}
