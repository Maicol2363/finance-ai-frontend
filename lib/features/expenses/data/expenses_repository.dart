import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_problem.dart';
import '../../auth/session/application/auth_session_controller.dart';
import '../../auth/session/domain/session_models.dart';
import '../domain/expense_models.dart';
import '../domain/history_models.dart';

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return HttpExpensesRepository(
    ref.watch(financeApiClientProvider),
    ref.watch(authSessionControllerProvider.notifier),
  );
});

abstract interface class ExpensesRepository {
  Future<ExpenseListResult> list({int page = 1, int pageSize = 50});

  Future<Expense> get(int expenseId);

  Future<Expense> update(int expenseId, ExpenseUpdateCommand command);

  Future<void> deleteExpense(int expenseId);

  Future<HistoryResult> history(HistoryFilters filters);
}

class HttpExpensesRepository implements ExpensesRepository {
  const HttpExpensesRepository(this._apiClient, this._sessionController);

  final FinanceApiClient _apiClient;
  final AuthSessionController _sessionController;

  @override
  Future<ExpenseListResult> list({int page = 1, int pageSize = 50}) {
    return _sessionController.runProtected((accessCredential) async {
      final response = await _transport(
        () => _apiClient.getJson(
          '/api/v1/expenses?page=$page&page_size=$pageSize',
          bearerCredential: accessCredential,
        ),
        operationMessage: 'We could not load your expenses. Check your connection and try again.',
      );
      if (response.statusCode == 200) {
        try {
          return ExpenseListResult.fromJson(_requireBody(response));
        } on FormatException {
          throw _invalidSuccess(response, 'invalid_expense_list_payload');
        }
      }
      throw _failure(response, operation: 'Expense list');
    });
  }

  @override
  Future<Expense> get(int expenseId) {
    return _sessionController.runProtected((accessCredential) async {
      final response = await _transport(
        () => _apiClient.getJson(
          '/api/v1/expenses/$expenseId',
          bearerCredential: accessCredential,
        ),
        operationMessage: 'We could not load this expense. Check your connection and try again.',
      );
      if (response.statusCode == 200) {
        return _decodeExpense(response);
      }
      throw _failure(response, operation: 'Expense detail');
    });
  }

  @override
  Future<Expense> update(int expenseId, ExpenseUpdateCommand command) {
    return _sessionController.runProtected((accessCredential) async {
      final response = await _transport(
        () => _apiClient.patchJson(
          '/api/v1/expenses/$expenseId',
          command.toJson(),
          bearerCredential: accessCredential,
        ),
        operationMessage: 'We could not confirm whether the expense was updated. Refresh expenses before trying again.',
        isMutation: true,
      );
      if (response.statusCode == 200) {
        return _decodeExpense(response);
      }
      throw _failure(response, operation: 'Expense update');
    });
  }

  @override
  Future<void> deleteExpense(int expenseId) {
    return _sessionController.runProtected((accessCredential) async {
      final response = await _transport(
        () => _apiClient.deleteRequest(
          '/api/v1/expenses/$expenseId',
          bearerCredential: accessCredential,
        ),
        operationMessage: 'We could not confirm whether the expense was deleted. Refresh expenses before trying again.',
        isMutation: true,
      );
      if (response.statusCode == 204) {
        return;
      }
      throw _failure(response, operation: 'Expense deletion');
    });
  }

  @override
  Future<HistoryResult> history(HistoryFilters filters) {
    return _sessionController.runProtected((accessCredential) async {
      final query = filters
          .toQueryParameters()
          .entries
          .map(
            (entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}',
          )
          .join('&');
      final response = await _transport(
        () => _apiClient.getJson(
          '/api/v1/history?$query',
          bearerCredential: accessCredential,
        ),
        operationMessage: 'We could not load your history. Check your connection and try again.',
      );
      if (response.statusCode == 200) {
        try {
          return HistoryResult.fromJson(_requireBody(response));
        } on FormatException {
          throw _invalidSuccess(response, 'invalid_history_payload');
        }
      }
      throw _failure(response, operation: 'History');
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
      throw ExpenseFailure(
        code: invalidResponse ? 'unexpected_response' : 'network_unavailable',
        userMessage: invalidResponse
            ? 'The service returned an unexpected response. Please try again.'
            : operationMessage,
        correlationId: failure.correlationId,
        technicalReason: failure.safeReason,
        isMutationOutcomeUncertain: isMutation,
      );
    }
  }

  Expense _decodeExpense(ApiResponse response) {
    try {
      return Expense.fromJson(_requireBody(response));
    } on FormatException {
      throw _invalidSuccess(response, 'invalid_expense_payload');
    }
  }

  Map<String, Object?> _requireBody(ApiResponse response) {
    final body = response.body;
    if (body == null) {
      throw const FormatException('Expected a JSON response body');
    }
    return body;
  }

  ExpenseFailure _invalidSuccess(ApiResponse response, String technicalReason) {
    return ExpenseFailure(
      code: 'unexpected_response',
      userMessage:
          'The service returned an unexpected response. Please try again.',
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
      'expense_not_found' => 'This expense is no longer available.',
      'expense_not_editable' =>
        'Only confirmed expenses can be edited or deleted.',
      'expense_account_invalid' =>
        'Select an active account with the expense currency and try again.',
      'expense_category_not_found' =>
        'Select one of your categories and try again.',
      'history_filter_invalid' =>
        'Please correct the selected history filters.',
      'request_invalid' => 'Please correct the highlighted fields.',
      _ => null,
    };
    return ExpenseFailure(
      code: known == null
          ? problem.code == 'service_unavailable'
                ? 'service_unavailable'
                : 'unexpected_response'
          : problem.code,
      userMessage:
          known ?? '$operation could not be completed. Please try again.',
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
        detail: 'The request could not be completed.',
        correlationId: response.correlationId ?? 'unavailable',
      );
    }
    return ApiProblem.fromJson(body, response.statusCode);
  }
}
