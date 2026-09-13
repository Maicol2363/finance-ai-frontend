import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_problem.dart';
import '../../auth/session/application/auth_session_controller.dart';
import '../../auth/session/domain/session_models.dart';
import '../domain/category_models.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return HttpCategoriesRepository(
    ref.watch(financeApiClientProvider),
    ref.watch(authSessionControllerProvider.notifier),
  );
});

abstract interface class CategoriesRepository {
  Future<CategoryListResult> list();
  Future<Category> get(int categoryId);
  Future<Category> create(CategoryCreateCommand command);
  Future<Category> update(int categoryId, CategoryUpdateCommand command);
  Future<CategoryListResult> reorder(List<int> categoryIds);
  Future<void> deleteCategory(int categoryId);
}

class HttpCategoriesRepository implements CategoriesRepository {
  const HttpCategoriesRepository(this._apiClient, this._sessionController);

  final FinanceApiClient _apiClient;
  final AuthSessionController _sessionController;

  @override
  Future<CategoryListResult> list() =>
      _sessionController.runProtected((credential) async {
        final response = await _transport(
          () => _apiClient.getJson(
            '/api/v1/categories',
            bearerCredential: credential,
          ),
          message: 'We could not load your categories. Check your connection and try again.',
        );
        if (response.statusCode == 200) return _decodeList(response);
        throw _failure(response, operation: 'Category list');
      });

  @override
  Future<Category> get(int categoryId) =>
      _sessionController.runProtected((credential) async {
        final response = await _transport(
          () => _apiClient.getJson(
            '/api/v1/categories/$categoryId',
            bearerCredential: credential,
          ),
          message: 'We could not load this category. Check your connection and try again.',
        );
        if (response.statusCode == 200) return _decodeCategory(response);
        throw _failure(response, operation: 'Category detail');
      });

  @override
  Future<Category> create(CategoryCreateCommand command) =>
      _sessionController.runProtected((credential) async {
        final response = await _transport(
          () => _apiClient.postJson(
            '/api/v1/categories',
            command.toJson(),
            bearerCredential: credential,
          ),
          message: 'We could not confirm whether the category was created. Refresh before trying again.',
          mutation: true,
        );
        if (response.statusCode == 201) return _decodeCategory(response);
        throw _failure(response, operation: 'Category creation');
      });

  @override
  Future<Category> update(int categoryId, CategoryUpdateCommand command) =>
      _sessionController.runProtected((credential) async {
        final response = await _transport(
          () => _apiClient.patchJson(
            '/api/v1/categories/$categoryId',
            command.toJson(),
            bearerCredential: credential,
          ),
          message: 'We could not confirm whether the category was updated. Refresh before trying again.',
          mutation: true,
        );
        if (response.statusCode == 200) return _decodeCategory(response);
        throw _failure(response, operation: 'Category update');
      });

  @override
  Future<CategoryListResult> reorder(List<int> categoryIds) =>
      _sessionController.runProtected((credential) async {
        final response = await _transport(
          () => _apiClient.putJson('/api/v1/categories/order', {
            'category_ids': categoryIds,
          }, bearerCredential: credential),
          message: 'We could not confirm the new category order. Refresh before trying again.',
          mutation: true,
        );
        if (response.statusCode == 200) return _decodeList(response);
        throw _failure(response, operation: 'Category reorder');
      });

  @override
  Future<void> deleteCategory(int categoryId) =>
      _sessionController.runProtected((credential) async {
        final response = await _transport(
          () => _apiClient.deleteRequest(
            '/api/v1/categories/$categoryId',
            bearerCredential: credential,
          ),
          message: 'We could not confirm whether the category was deleted. Refresh before trying again.',
          mutation: true,
        );
        if (response.statusCode == 204) return;
        throw _failure(response, operation: 'Category deletion');
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
      throw CategoryFailure(
        code: invalid ? 'unexpected_response' : 'network_unavailable',
        userMessage: invalid
            ? 'The service returned an unexpected response. Please try again.'
            : message,
        correlationId: failure.correlationId,
        technicalReason: failure.safeReason,
        isMutationOutcomeUncertain: mutation,
      );
    }
  }

  Category _decodeCategory(ApiResponse response) {
    try {
      return Category.fromJson(_body(response));
    } on FormatException {
      throw _invalidSuccess(response, 'invalid_category_payload');
    }
  }

  CategoryListResult _decodeList(ApiResponse response) {
    try {
      return CategoryListResult.fromJson(_body(response));
    } on FormatException {
      throw _invalidSuccess(response, 'invalid_category_list_payload');
    }
  }

  Map<String, Object?> _body(ApiResponse response) {
    final body = response.body;
    if (body == null) throw const FormatException('Expected a JSON object');
    return body;
  }

  CategoryFailure _invalidSuccess(ApiResponse response, String reason) =>
      CategoryFailure(
        code: 'unexpected_response',
        userMessage:
            'The service returned an unexpected response. Please try again.',
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
      'category_name_conflict' => 'Choose a different category name.',
      'category_not_found' => 'This category is no longer available.',
      'category_appearance_invalid' => 'Choose a supported color and icon.',
      'category_order_invalid' =>
        'Refresh categories and try reordering again.',
      'request_invalid' => 'Please correct the highlighted fields.',
      _ => '$operation could not be completed. Please try again.',
    };
    return CategoryFailure(
      code: problem.code,
      userMessage: message,
      fieldErrors: Map.unmodifiable(problem.fieldErrors),
      correlationId: problem.correlationId,
      technicalReason: 'http_${response.statusCode}',
    );
  }
}
