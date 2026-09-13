import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/diagnostics/error_diagnostic.dart';
import '../../auth/session/application/auth_session_controller.dart';
import '../data/income_sources_repository.dart';
import '../domain/income_source_models.dart';
import 'income_sources_state.dart';

final incomeSourcesControllerProvider =
    NotifierProvider<IncomeSourcesController, IncomeSourcesState>(
      IncomeSourcesController.new,
    );

/// Selector feed for new-entry forms: rebuilds whenever the catalog changes.
final incomeSourceSelectorProvider = Provider<List<IncomeSource>>(
  (ref) => ref.watch(incomeSourcesControllerProvider).items,
);

/// The in-memory access credential used for income-source requests.
final accessCredentialProvider = Provider<String?>(
  (ref) => ref.watch(authSessionControllerProvider).accessCredential,
);

class IncomeSourcesController extends Notifier<IncomeSourcesState> {
  @override
  IncomeSourcesState build() {
    Future<void>.microtask(load);
    return const IncomeSourcesState();
  }

  String? _credential() => ref.read(accessCredentialProvider);

  Future<void> load() async {
    final credential = _credential();
    if (credential == null) {
      state = IncomeSourcesState(
        status: IncomeSourcesStatus.failure,
        diagnostic: _diagnostic(
          code: 'authentication_required',
          operation: 'list_income_sources',
          userMessage: 'Please log in again to manage income sources.',
          technicalReason: 'missing_access_credential',
        ),
      );
      return;
    }
    state = state.copyWith(
      status: IncomeSourcesStatus.loading,
      clearDiagnostic: true,
    );
    try {
      final items = await ref
          .read(incomeSourcesRepositoryProvider)
          .list(accessCredential: credential);
      state = IncomeSourcesState(
        status: IncomeSourcesStatus.ready,
        items: items,
      );
    } on IncomeSourcesFailure catch (failure) {
      state = IncomeSourcesState(
        status: IncomeSourcesStatus.failure,
        diagnostic: _diagnosticFor(failure, operation: 'list_income_sources'),
      );
    } on Object {
      state = IncomeSourcesState(
        status: IncomeSourcesStatus.failure,
        diagnostic: _diagnostic(
          code: 'unexpected_client_error',
          operation: 'list_income_sources',
          userMessage: 'Income sources could not be loaded. Please try again.',
          technicalReason: 'unclassified_client_failure',
        ),
      );
    }
  }

  Future<bool> add(String name) => _mutate(
    operation: 'create_income_source',
    action: (credential) => ref
        .read(incomeSourcesRepositoryProvider)
        .create(accessCredential: credential, name: name),
  );

  Future<bool> rename(int id, String name) => _mutate(
    operation: 'rename_income_source',
    action: (credential) => ref
        .read(incomeSourcesRepositoryProvider)
        .rename(accessCredential: credential, id: id, name: name),
  );

  Future<bool> delete(int id) async {
    final credential = _credential();
    if (credential == null) {
      return false;
    }
    state = state.copyWith(busy: true, clearDiagnostic: true);
    try {
      await ref
          .read(incomeSourcesRepositoryProvider)
          .delete(accessCredential: credential, id: id);
      await load();
      return true;
    } on IncomeSourcesFailure catch (failure) {
      state = state.copyWith(
        busy: false,
        diagnostic: _diagnosticFor(failure, operation: 'delete_income_source'),
      );
      return false;
    } on Object {
      state = state.copyWith(
        busy: false,
        diagnostic: _diagnostic(
          code: 'unexpected_client_error',
          operation: 'delete_income_source',
          userMessage:
              'The income source could not be deleted. Please try again.',
          technicalReason: 'unclassified_client_failure',
        ),
      );
      return false;
    }
  }

  Future<bool> _mutate({
    required String operation,
    required Future<IncomeSource> Function(String credential) action,
  }) async {
    final credential = _credential();
    if (credential == null) {
      return false;
    }
    state = state.copyWith(
      busy: true,
      clearDiagnostic: true,
      clearFieldErrors: true,
    );
    try {
      await action(credential);
      await load();
      return true;
    } on IncomeSourcesValidationFailure catch (failure) {
      state = state.copyWith(
        busy: false,
        fieldErrors: failure.fieldErrors,
        diagnostic: _diagnosticFor(failure, operation: operation),
      );
      return false;
    } on IncomeSourcesFailure catch (failure) {
      state = state.copyWith(
        busy: false,
        diagnostic: _diagnosticFor(failure, operation: operation),
      );
      return false;
    } on Object {
      state = state.copyWith(
        busy: false,
        diagnostic: _diagnostic(
          code: 'unexpected_client_error',
          operation: operation,
          userMessage:
              'The operation could not be completed. Please try again.',
          technicalReason: 'unclassified_client_failure',
        ),
      );
      return false;
    }
  }

  ErrorDiagnostic _diagnosticFor(
    IncomeSourcesFailure failure, {
    required String operation,
  }) {
    return _diagnostic(
      code: failure.code,
      operation: operation,
      userMessage: failure.userMessage,
      correlationId: failure.correlationId,
      technicalReason: failure.technicalReason,
    );
  }

  ErrorDiagnostic _diagnostic({
    required String code,
    required String operation,
    required String userMessage,
    required String technicalReason,
    String correlationId = 'unavailable',
  }) {
    return ErrorDiagnostic.capture(
      code: code,
      operation: operation,
      userMessage: userMessage,
      correlationId: correlationId,
      technicalReason: technicalReason,
    );
  }
}
