import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/error_diagnostic.dart';
import '../../auth/session/domain/session_models.dart';
import '../data/categories_repository.dart';
import '../domain/category_models.dart';
import 'categories_state.dart';

final categoriesControllerProvider =
    NotifierProvider<CategoriesController, CategoriesState>(
      CategoriesController.new,
    );

class CategoriesController extends Notifier<CategoriesState> {
  @override
  CategoriesState build() => const CategoriesState();

  Future<void> load() async {
    if (state.loadStatus == CategoriesLoadStatus.loading) return;
    state = state.copyWith(
      loadStatus: CategoriesLoadStatus.loading,
      clearDiagnostic: true,
    );
    try {
      final result = await ref.read(categoriesRepositoryProvider).list();
      state = state.copyWith(
        loadStatus: CategoriesLoadStatus.ready,
        result: result,
        clearDiagnostic: true,
      );
    } on InvalidSessionFailure catch (failure) {
      state = state.copyWith(
        loadStatus: CategoriesLoadStatus.failure,
        diagnostic: _sessionDiagnostic(failure, 'load_categories'),
      );
    } on CategoryFailure catch (failure) {
      state = state.copyWith(
        loadStatus: CategoriesLoadStatus.failure,
        diagnostic: _diagnostic(failure, 'load_categories'),
      );
    } on Object {
      state = state.copyWith(
        loadStatus: CategoriesLoadStatus.failure,
        diagnostic: _unexpected('load_categories'),
      );
    }
  }

  Future<CategoryMutationOutcome> save({
    int? categoryId,
    required String name,
    required CategoryColor color,
    required CategoryIcon icon,
  }) async {
    if (state.isSaving) return CategoryMutationOutcome.ignored;
    final normalized = name.trim();
    if (normalized.isEmpty || normalized.runes.length > 100) {
      final message = normalized.isEmpty
          ? 'El nombre de la categoría es obligatorio.'
          : 'El nombre no puede superar los 100 caracteres.';
      state = state.copyWith(
        fieldErrors: {
          'name': [message],
        },
        mutationDiagnostic: ErrorDiagnostic.capture(
          code: 'category_invalid',
          operation: 'validate_category',
          userMessage: 'Corrige el nombre de la categoría.',
          technicalReason: 'local_validation_failure',
        ),
      );
      return CategoryMutationOutcome.invalid;
    }
    state = state.copyWith(
      mutationStatus: CategoryMutationStatus.saving,
      fieldErrors: const {},
      clearMutationDiagnostic: true,
    );
    final command = CategoryCreateCommand(
      name: normalized,
      color: color,
      icon: icon,
    );
    try {
      final saved = categoryId == null
          ? await ref.read(categoriesRepositoryProvider).create(command)
          : await ref
                .read(categoriesRepositoryProvider)
                .update(categoryId, command);
      _acceptSaved(saved);
      return CategoryMutationOutcome.success;
    } on InvalidSessionFailure catch (failure) {
      _reject(
        _sessionDiagnostic(
          failure,
          categoryId == null ? 'create_category' : 'update_category',
        ),
      );
    } on CategoryFailure catch (failure) {
      await _rejectFailure(
        failure,
        categoryId == null ? 'create_category' : 'update_category',
      );
    } on Object {
      _reject(
        _unexpected(categoryId == null ? 'create_category' : 'update_category'),
      );
    }
    return CategoryMutationOutcome.failure;
  }

  Future<CategoryMutationOutcome> reorder(List<int> categoryIds) async {
    if (state.isSaving) return CategoryMutationOutcome.ignored;
    state = state.copyWith(
      mutationStatus: CategoryMutationStatus.saving,
      clearMutationDiagnostic: true,
    );
    try {
      final result = await ref
          .read(categoriesRepositoryProvider)
          .reorder(categoryIds);
      state = state.copyWith(
        result: result,
        loadStatus: CategoriesLoadStatus.ready,
        mutationStatus: CategoryMutationStatus.idle,
      );
      return CategoryMutationOutcome.success;
    } on CategoryFailure catch (failure) {
      await _rejectFailure(failure, 'reorder_categories');
    } on InvalidSessionFailure catch (failure) {
      _reject(_sessionDiagnostic(failure, 'reorder_categories'));
    } on Object {
      _reject(_unexpected('reorder_categories'));
    }
    return CategoryMutationOutcome.failure;
  }

  Future<CategoryMutationOutcome> deleteCategory(int categoryId) async {
    if (state.isSaving) return CategoryMutationOutcome.ignored;
    state = state.copyWith(
      mutationStatus: CategoryMutationStatus.saving,
      clearMutationDiagnostic: true,
    );
    try {
      await ref.read(categoriesRepositoryProvider).deleteCategory(categoryId);
      _acceptDeleted(categoryId);
      return CategoryMutationOutcome.success;
    } on CategoryFailure catch (failure) {
      await _rejectFailure(failure, 'delete_category');
    } on InvalidSessionFailure catch (failure) {
      _reject(_sessionDiagnostic(failure, 'delete_category'));
    } on Object {
      _reject(_unexpected('delete_category'));
    }
    return CategoryMutationOutcome.failure;
  }

  void clearFieldError(String field) {
    final next = state.withoutFieldError(field);
    state = next.copyWith(clearMutationDiagnostic: next.fieldErrors.isEmpty);
  }

  void clearMutationFeedback() {
    if (state.isSaving) return;
    state = state.copyWith(
      fieldErrors: const {},
      clearMutationDiagnostic: true,
    );
  }

  Future<void> _refreshAfterMutation() async {
    final result = await ref.read(categoriesRepositoryProvider).list();
    state = state.copyWith(
      result: result,
      loadStatus: CategoriesLoadStatus.ready,
      mutationStatus: CategoryMutationStatus.idle,
      clearMutationDiagnostic: true,
    );
  }

  void _acceptSaved(Category saved) {
    final current = state.result;
    final categories =
        [...?current?.categories.where((item) => item.id != saved.id), saved]
          ..sort((left, right) {
            final order = left.sortOrder.compareTo(right.sortOrder);
            return order == 0 ? left.id.compareTo(right.id) : order;
          });
    state = state.copyWith(
      result: CategoryListResult(
        categories: List.unmodifiable(categories),
        supportedColors: current?.supportedColors ?? CategoryColor.values,
        supportedIcons: current?.supportedIcons ?? CategoryIcon.values,
      ),
      loadStatus: CategoriesLoadStatus.ready,
      mutationStatus: CategoryMutationStatus.idle,
      fieldErrors: const {},
      clearDiagnostic: true,
      clearMutationDiagnostic: true,
    );
  }

  void _acceptDeleted(int categoryId) {
    final current = state.result;
    state = state.copyWith(
      result: current == null
          ? CategoryListResult(
              categories: const [],
              supportedColors: CategoryColor.values,
              supportedIcons: CategoryIcon.values,
            )
          : CategoryListResult(
              categories: List.unmodifiable(
                current.categories.where((item) => item.id != categoryId),
              ),
              supportedColors: current.supportedColors,
              supportedIcons: current.supportedIcons,
            ),
      loadStatus: CategoriesLoadStatus.ready,
      mutationStatus: CategoryMutationStatus.idle,
      fieldErrors: const {},
      clearDiagnostic: true,
      clearMutationDiagnostic: true,
    );
  }

  Future<void> _rejectFailure(CategoryFailure failure, String operation) async {
    if (failure.isMutationOutcomeUncertain) {
      try {
        await _refreshAfterMutation();
      } on Object {
        // Keep the original safe diagnostic; the user can retry the list refresh.
      }
    }
    state = state.copyWith(
      mutationStatus: CategoryMutationStatus.idle,
      mutationDiagnostic: _diagnostic(failure, operation),
      fieldErrors: Map.unmodifiable(failure.fieldErrors),
    );
  }

  void _reject(ErrorDiagnostic diagnostic) {
    state = state.copyWith(
      mutationStatus: CategoryMutationStatus.idle,
      mutationDiagnostic: diagnostic,
      fieldErrors: const {},
    );
  }

  ErrorDiagnostic _diagnostic(CategoryFailure failure, String operation) =>
      ErrorDiagnostic.capture(
        code: failure.code,
        operation: operation,
        userMessage: failure.userMessage,
        correlationId: failure.correlationId,
        technicalReason: failure.technicalReason,
      );

  ErrorDiagnostic _sessionDiagnostic(
    InvalidSessionFailure failure,
    String operation,
  ) => ErrorDiagnostic.capture(
    code: failure.code,
    operation: operation,
    userMessage: failure.userMessage,
    correlationId: failure.correlationId,
    technicalReason: failure.technicalReason,
  );

  ErrorDiagnostic _unexpected(String operation) => ErrorDiagnostic.capture(
    code: 'unexpected_client_error',
    operation: operation,
    userMessage: 'La operación no se pudo completar. Inténtalo de nuevo.',
    technicalReason: 'unclassified_client_failure',
  );
}
