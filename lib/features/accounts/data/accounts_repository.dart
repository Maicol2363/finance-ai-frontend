import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_problem.dart';
import '../../auth/session/application/auth_session_controller.dart';
import '../../auth/session/domain/session_models.dart';
import '../domain/account_models.dart';

final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return HttpAccountsRepository(
    ref.watch(financeApiClientProvider),
    ref.watch(authSessionControllerProvider.notifier),
  );
});

abstract interface class AccountsRepository {
  Future<AccountListResult> list({required bool includeInactive});

  Future<Account> get(int accountId);

  Future<Account> create(AccountCreateCommand command);

  Future<Account> update(int accountId, AccountUpdateCommand command);

  Future<Account> setActive(int accountId, {required bool isActive});

  Future<void> deleteAccount(int accountId);
}

class HttpAccountsRepository implements AccountsRepository {
  const HttpAccountsRepository(this._apiClient, this._sessionController);

  final FinanceApiClient _apiClient;
  final AuthSessionController _sessionController;

  @override
  Future<AccountListResult> list({required bool includeInactive}) {
    return _sessionController.runProtected((accessCredential) async {
      final response = await _transport(
        () => _apiClient.getJson(
          '/api/v1/accounts?include_inactive=$includeInactive',
          bearerCredential: accessCredential,
        ),
        operationMessage: 'We could not load your accounts. Check your connection and try again.',
      );
      if (response.statusCode == 200) {
        try {
          return AccountListResult.fromJson(_requireBody(response));
        } on FormatException {
          throw _invalidSuccess(response, 'invalid_account_list_payload');
        }
      }
      throw _failure(response, operation: 'Account list');
    });
  }

  @override
  Future<Account> get(int accountId) {
    return _sessionController.runProtected((accessCredential) async {
      final response = await _transport(
        () => _apiClient.getJson(
          '/api/v1/accounts/$accountId',
          bearerCredential: accessCredential,
        ),
        operationMessage: 'We could not load this account. Check your connection and try again.',
      );
      if (response.statusCode == 200) {
        return _decodeAccount(response);
      }
      throw _failure(response, operation: 'Account detail');
    });
  }

  @override
  Future<Account> create(AccountCreateCommand command) {
    return _sessionController.runProtected((accessCredential) async {
      final response = await _transport(
        () => _apiClient.postJson(
          '/api/v1/accounts',
          command.toJson(),
          bearerCredential: accessCredential,
        ),
        operationMessage: 'We could not confirm whether the account was created. Refresh accounts before trying again.',
        isMutation: true,
      );
      if (response.statusCode == 201) {
        return _decodeAccount(response);
      }
      throw _failure(response, operation: 'Account creation');
    });
  }

  @override
  Future<Account> update(int accountId, AccountUpdateCommand command) {
    return _sessionController.runProtected((accessCredential) async {
      final response = await _transport(
        () => _apiClient.patchJson(
          '/api/v1/accounts/$accountId',
          command.toJson(),
          bearerCredential: accessCredential,
        ),
        operationMessage: 'We could not confirm whether the account was updated. Refresh accounts before trying again.',
        isMutation: true,
      );
      if (response.statusCode == 200) {
        return _decodeAccount(response);
      }
      throw _failure(response, operation: 'Account update');
    });
  }

  @override
  Future<Account> setActive(int accountId, {required bool isActive}) {
    return _sessionController.runProtected((accessCredential) async {
      final response = await _transport(
        () => _apiClient.patchJson('/api/v1/accounts/$accountId/status', {
          'is_active': isActive,
        }, bearerCredential: accessCredential),
        operationMessage: 'We could not confirm whether the account status changed. Refresh accounts before trying again.',
        isMutation: true,
      );
      if (response.statusCode == 200) {
        return _decodeAccount(response);
      }
      throw _failure(
        response,
        operation: isActive ? 'Account reactivation' : 'Account deactivation',
      );
    });
  }

  @override
  Future<void> deleteAccount(int accountId) {
    return _sessionController.runProtected((accessCredential) async {
      final response = await _transport(
        () => _apiClient.deleteRequest(
          '/api/v1/accounts/$accountId',
          bearerCredential: accessCredential,
        ),
        operationMessage: 'We could not confirm whether the account was deleted. Refresh accounts before trying again.',
        isMutation: true,
      );
      if (response.statusCode == 204) {
        return;
      }
      throw _failure(response, operation: 'Account deletion');
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
      throw AccountFailure(
        code: invalidResponse ? 'unexpected_response' : 'network_unavailable',
        userMessage: invalidResponse
            ? 'The service returned an unexpected response. Please try again.'
            : operationMessage,
        correlationId: failure.correlationId,
        technicalReason: failure.safeReason,
        isRetryable: true,
        isMutationOutcomeUncertain: isMutation,
      );
    }
  }

  Account _decodeAccount(ApiResponse response) {
    try {
      return Account.fromJson(_requireBody(response));
    } on FormatException {
      throw _invalidSuccess(response, 'invalid_account_payload');
    }
  }

  Map<String, Object?> _requireBody(ApiResponse response) {
    final body = response.body;
    if (body == null) {
      throw const FormatException('Expected a JSON response body');
    }
    return body;
  }

  AccountFailure _invalidSuccess(ApiResponse response, String technicalReason) {
    return AccountFailure(
      code: 'unexpected_response',
      userMessage:
          'The service returned an unexpected response. Please try again.',
      correlationId: response.correlationId ?? 'unavailable',
      technicalReason: technicalReason,
      isRetryable: true,
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
      'account_name_conflict' =>
        'Choose a different name for this active account.',
      'account_currency_invalid' =>
        'Select a currently supported currency and try again.',
      'account_currency_locked' =>
        'Currency cannot change after confirmed account activity.',
      'account_not_found' => 'This account is no longer available.',
      'account_reactivation_conflict' =>
        'Update the account details before reactivating it.',
      'account_delete_blocked' => 'This account has financial activity. Deactivate it to preserve its history.',
      'request_invalid' => 'Please correct the highlighted fields.',
      _ => null,
    };
    return AccountFailure(
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
      isRetryable: known == null,
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
