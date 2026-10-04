import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_problem.dart';
import '../../auth/session/application/auth_session_controller.dart';
import '../domain/dashboard_summary.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return HttpDashboardRepository(
    ref.watch(financeApiClientProvider),
    ref.watch(authSessionControllerProvider.notifier),
  );
});

abstract interface class DashboardRepository {
  Future<DashboardSummary> getSummary({
    required DateTime start,
    required DateTime end,
    required String currency,
    String tz = 'America/Bogota',
  });
}

class HttpDashboardRepository implements DashboardRepository {
  const HttpDashboardRepository(this._apiClient, this._sessionController);

  final FinanceApiClient _apiClient;
  final AuthSessionController _sessionController;

  @override
  Future<DashboardSummary> getSummary({
    required DateTime start,
    required DateTime end,
    required String currency,
    String tz = 'America/Bogota',
  }) => _sessionController.runProtected((credential) async {
    final startStr = _formatDate(start);
    final endStr = _formatDate(end);
    final query =
        'start_date=$startStr&end_date=$endStr&currency=$currency&tz=${Uri.encodeQueryComponent(tz)}';

    final response = await _transport(
      () => _apiClient.getJson(
        '/api/v1/dashboard/summary?$query',
        bearerCredential: credential,
      ),
      message: 'No pudimos cargar el resumen del dashboard. Revisa la conexión e inténtalo de nuevo.',
    );

    if (response.statusCode == 200) {
      try {
        return DashboardSummary.fromJson(_body(response));
      } on FormatException {
        throw _invalidSuccess(response, 'invalid_dashboard_summary_payload');
      }
    }
    throw _failure(response, operation: 'Cargar resumen del dashboard');
  });

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<ApiResponse> _transport(
    Future<ApiResponse> Function() request, {
    required String message,
  }) async {
    try {
      return await request();
    } on ApiTransportException catch (e) {
      throw ApiProblem(
        status: 503,
        code: e.safeReason,
        detail: message,
        correlationId: e.correlationId,
      );
    }
  }

  Map<String, dynamic> _body(ApiResponse response) {
    final body = response.body;
    if (body == null) {
      throw ApiProblem(
        status: response.statusCode,
        code: 'empty_response',
        detail: 'El servidor no devolvió datos para el dashboard.',
        correlationId: response.correlationId ?? 'unavailable',
      );
    }
    return Map<String, dynamic>.from(body);
  }

  ApiProblem _invalidSuccess(ApiResponse response, String code) {
    return ApiProblem(
      status: 500,
      code: code,
      detail: 'El formato de los datos recibidos no es válido.',
      correlationId: response.correlationId ?? 'unavailable',
    );
  }

  ApiProblem _failure(ApiResponse response, {required String operation}) {
    final body = response.body;
    if (body != null) {
      try {
        return ApiProblem.fromJson(body, response.statusCode);
      } catch (_) {}
    }
    return ApiProblem(
      status: response.statusCode,
      code: 'dashboard_request_failed',
      detail: 'No se pudo completar la operación ($operation).',
      correlationId: response.correlationId ?? 'unavailable',
    );
  }
}
