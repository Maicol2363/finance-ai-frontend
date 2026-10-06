import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_problem.dart';
import '../../auth/session/application/auth_session_controller.dart';
import '../../auth/session/domain/session_models.dart';
import '../domain/budget_models.dart';

final budgetsRepositoryProvider = Provider<BudgetsRepository>((ref) {
  return HttpBudgetsRepository(
    ref.watch(financeApiClientProvider),
    ref.watch(authSessionControllerProvider.notifier),
  );
});

abstract interface class BudgetsRepository {
  Future<BudgetListResult> list();
  Future<Budget> create(BudgetCreateCommand command);
  Future<Budget> update(int budgetId, BudgetUpdateCommand command);
  Future<void> deleteBudget(int budgetId);
}

class HttpBudgetsRepository implements BudgetsRepository {
  const HttpBudgetsRepository(this._apiClient, this._sessionController);

  final FinanceApiClient _apiClient;
  final AuthSessionController _sessionController;

  @override
  Future<BudgetListResult> list() => _sessionController.runProtected((
    credential,
  ) async {
    final response = await _transport(
      () => _apiClient.getJson('/api/v1/budgets', bearerCredential: credential),
      message: 'No pudimos cargar tus presupuestos. Revisa la conexión e inténtalo de nuevo.',
    );
    if (response.statusCode == 200) {
      try {
        return BudgetListResult.fromJson(_body(response));
      } on FormatException {
        throw _invalidSuccess(response, 'invalid_budget_list_payload');
      }
    }
    throw _failure(response, operation: 'Cargar presupuestos');
  });

  @override
  Future<Budget> create(BudgetCreateCommand command) =>
      _sessionController.runProtected((credential) async {
        final response = await _transport(
          () => _apiClient.postJson(
            '/api/v1/budgets',
            command.toJson(),
            bearerCredential: credential,
          ),
          message: 'No pudimos confirmar si se creó el presupuesto. Actualiza la lista antes de reintentar.',
          mutation: true,
        );
        if (response.statusCode == 201) return _decodeBudget(response);
        throw _failure(response, operation: 'Crear presupuesto');
      });

  @override
  Future<Budget> update(int budgetId, BudgetUpdateCommand command) =>
      _sessionController.runProtected((credential) async {
        final response = await _transport(
          () => _apiClient.patchJson(
            '/api/v1/budgets/$budgetId',
            command.toJson(),
            bearerCredential: credential,
          ),
          message: 'No pudimos confirmar si se actualizó el presupuesto. Actualiza la lista antes de reintentar.',
          mutation: true,
        );
        if (response.statusCode == 200) return _decodeBudget(response);
        throw _failure(response, operation: 'Actualizar presupuesto');
      });

  @override
  Future<void> deleteBudget(int budgetId) =>
      _sessionController.runProtected((credential) async {
        final response = await _transport(
          () => _apiClient.deleteRequest(
            '/api/v1/budgets/$budgetId',
            bearerCredential: credential,
          ),
          message: 'No pudimos confirmar si se eliminó el presupuesto. Actualiza la lista antes de reintentar.',
          mutation: true,
        );
        if (response.statusCode == 204) return;
        throw _failure(response, operation: 'Eliminar presupuesto');
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
      throw BudgetFailure(
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

  Budget _decodeBudget(ApiResponse response) {
    try {
      return Budget.fromJson(_body(response));
    } on FormatException {
      throw _invalidSuccess(response, 'invalid_budget_payload');
    }
  }

  Map<String, Object?> _body(ApiResponse response) {
    final body = response.body;
    if (body == null) throw const FormatException('Expected a JSON object');
    return body;
  }

  BudgetFailure _invalidSuccess(
    ApiResponse response,
    String reason,
  ) => BudgetFailure(
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
      'budget_not_found' => 'Este presupuesto ya no está disponible.',
      'budget_category_unavailable' => 'Selecciona una de tus categorías.',
      'budget_currency_invalid' => 'Selecciona una moneda disponible.',
      'request_invalid' => 'Corrige los campos indicados.',
      _ => '$operation no se pudo completar. Inténtalo de nuevo.',
    };
    return BudgetFailure(
      code: problem.code,
      userMessage: message,
      fieldErrors: Map.unmodifiable(problem.fieldErrors),
      correlationId: problem.correlationId,
      technicalReason: 'http_${response.statusCode}',
    );
  }
}
