import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_problem.dart';
import '../../auth/session/application/auth_session_controller.dart';
import '../../auth/session/domain/session_models.dart';
import '../domain/income_models.dart';

final incomesRepositoryProvider = Provider<IncomesRepository>(
  (ref) => HttpIncomesRepository(
    ref.watch(financeApiClientProvider),
    ref.watch(authSessionControllerProvider.notifier),
  ),
);

final incomeRevisionProvider = NotifierProvider<IncomeRevision, int>(
  IncomeRevision.new,
);

class IncomeRevision extends Notifier<int> {
  @override
  int build() => 0;

  void changed() => state += 1;
}

abstract interface class IncomesRepository {
  Future<List<Income>> list({int? accountId});
  Future<Income> get(int incomeId);
  Future<Income> create(IncomeWriteCommand command);
  Future<Income> update(int incomeId, IncomeWriteCommand command);
  Future<void> delete(int incomeId);
}

class HttpIncomesRepository implements IncomesRepository {
  const HttpIncomesRepository(this._api, this._session);

  final FinanceApiClient _api;
  final AuthSessionController _session;
  static const _path = '/api/v1/incomes';

  @override
  Future<List<Income>> list({int? accountId}) =>
      _session.runProtected((access) async {
        final path = accountId == null ? _path : '$_path?account_id=$accountId';
        final response = await _send(
          () => _api.getJson(path, bearerCredential: access),
        );
        if (response.statusCode != 200) {
          throw _failure(response);
        }
        try {
          final items = response.body?['items'];
          if (items is! List<Object?>) {
            throw const FormatException('Invalid income list');
          }
          return items
              .map((item) {
                if (item is! Map<String, Object?>) {
                  throw const FormatException('Invalid income item');
                }
                return Income.fromJson(item);
              })
              .toList(growable: false);
        } on FormatException {
          throw _unexpected(response);
        }
      });

  @override
  Future<Income> get(int incomeId) => _session.runProtected((access) async {
    final response = await _send(
      () => _api.getJson('$_path/$incomeId', bearerCredential: access),
    );
    if (response.statusCode != 200) throw _failure(response);
    return _decode(response);
  });

  @override
  Future<Income> create(IncomeWriteCommand command) =>
      _session.runProtected((access) async {
        final response = await _send(
          () =>
              _api.postJson(_path, command.toJson(), bearerCredential: access),
          mutation: true,
        );
        if (response.statusCode != 201) throw _failure(response);
        return _decode(response);
      });

  @override
  Future<Income> update(int incomeId, IncomeWriteCommand command) =>
      _session.runProtected((access) async {
        final response = await _send(
          () => _api.putJson(
            '$_path/$incomeId',
            command.toJson(),
            bearerCredential: access,
          ),
          mutation: true,
        );
        if (response.statusCode != 200) throw _failure(response);
        return _decode(response);
      });

  @override
  Future<void> delete(int incomeId) => _session.runProtected((access) async {
    final response = await _send(
      () => _api.deleteRequest('$_path/$incomeId', bearerCredential: access),
      mutation: true,
    );
    if (response.statusCode != 204) throw _failure(response);
  });

  Future<ApiResponse> _send(
    Future<ApiResponse> Function() call, {
    bool mutation = false,
  }) async {
    try {
      return await call();
    } on ApiTransportException catch (failure) {
      throw IncomeFailure(
        code: failure.kind == ApiTransportFailureKind.invalidResponse
            ? 'unexpected_response'
            : 'network_unavailable',
        userMessage: mutation
            ? 'No pudimos confirmar el cambio. Actualiza los ingresos antes de intentarlo de nuevo.'
            : 'No pudimos cargar tus ingresos. Revisa la conexión e inténtalo de nuevo.',
        correlationId: failure.correlationId,
        technicalReason: failure.safeReason,
        outcomeUncertain: mutation,
      );
    }
  }

  Income _decode(ApiResponse response) {
    try {
      final body = response.body;
      if (body == null) throw const FormatException('Missing income body');
      return Income.fromJson(body);
    } on FormatException {
      throw _unexpected(response);
    }
  }

  IncomeFailure _unexpected(ApiResponse response) => IncomeFailure(
    code: 'unexpected_response',
    userMessage:
        'El servicio devolvió una respuesta inesperada. Inténtalo de nuevo.',
    correlationId: response.correlationId ?? 'unavailable',
    technicalReason: 'invalid_income_payload',
  );

  Exception _failure(ApiResponse response) {
    try {
      final body = response.body;
      if (body == null) return _unexpected(response);
      final problem = ApiProblem.fromJson(body, response.statusCode);
      if (problem.code == 'authentication_required' ||
          problem.code == 'session_invalid') {
        return InvalidSessionFailure(
          correlationId: problem.correlationId,
          technicalReason: 'http_${response.statusCode}',
        );
      }
      final message = switch (problem.code) {
        'income_not_found' => 'Este ingreso ya no está disponible.',
        'income_account_unavailable' => 'Selecciona una cuenta activa propia.',
        'income_source_unavailable' =>
          'Selecciona una fuente propia o deja el campo vacío.',
        'request_invalid' => 'Corrige los campos indicados.',
        _ => 'No pudimos completar la operación. Inténtalo de nuevo.',
      };
      return IncomeFailure(
        code: problem.code,
        userMessage: message,
        correlationId: problem.correlationId,
        technicalReason: 'http_${response.statusCode}',
        fieldErrors: problem.fieldErrors,
      );
    } on FormatException {
      return _unexpected(response);
    }
  }
}
