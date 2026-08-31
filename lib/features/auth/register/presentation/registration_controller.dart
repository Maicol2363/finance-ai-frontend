import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/diagnostics/error_diagnostic.dart';
import '../data/auth_repository.dart';
import '../domain/registration_models.dart';
import 'registration_state.dart';

final registrationControllerProvider =
    NotifierProvider<RegistrationController, RegistrationState>(
      RegistrationController.new,
    );

class RegistrationController extends Notifier<RegistrationState> {
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  RegistrationState build() => const RegistrationState();

  Future<RegistrationSubmitOutcome> submit({
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    if (state.isSubmitting) {
      return RegistrationSubmitOutcome.ignored;
    }
    final normalizedEmail = email.trim();
    final localErrors = _validate(
      email: normalizedEmail,
      password: password,
      passwordConfirmation: passwordConfirmation,
    );
    if (localErrors.isNotEmpty) {
      state = RegistrationState(
        status: RegistrationStatus.failure,
        fieldErrors: Map.unmodifiable(localErrors),
        diagnostic: _diagnostic(
          code: 'registration_invalid',
          userMessage: 'Please correct the highlighted fields.',
          technicalReason: 'client_validation',
        ),
      );
      return RegistrationSubmitOutcome.invalid;
    }

    state = const RegistrationState(status: RegistrationStatus.submitting);
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .register(
            RegistrationRequest(
              email: normalizedEmail,
              password: password,
              passwordConfirmation: passwordConfirmation,
            ),
          );
      state = RegistrationState(
        status: RegistrationStatus.success,
        result: result,
      );
      return RegistrationSubmitOutcome.success;
    } on RegistrationValidationFailure catch (failure) {
      state = RegistrationState(
        status: RegistrationStatus.failure,
        fieldErrors: Map.unmodifiable(failure.fieldErrors),
        generalError: failure.fieldErrors.isEmpty ? failure.userMessage : null,
        diagnostic: _diagnosticForFailure(failure),
      );
    } on RegistrationConflictFailure catch (failure) {
      state = RegistrationState(
        status: RegistrationStatus.failure,
        fieldErrors: {
          'email': [failure.userMessage],
        },
        diagnostic: _diagnosticForFailure(failure),
      );
    } on RegistrationFailure catch (failure) {
      state = RegistrationState(
        status: RegistrationStatus.failure,
        generalError: failure.userMessage,
        diagnostic: _diagnosticForFailure(failure),
      );
    } on Object {
      const message = 'Registration could not be completed. Please try again.';
      state = RegistrationState(
        status: RegistrationStatus.failure,
        generalError: message,
        diagnostic: _diagnostic(
          code: 'unexpected_client_error',
          userMessage: message,
          technicalReason: 'unclassified_client_failure',
        ),
      );
    }
    return RegistrationSubmitOutcome.failure;
  }

  void clearFieldError(String field) {
    state = state.withoutFieldError(field);
  }

  ErrorDiagnostic _diagnosticForFailure(RegistrationFailure failure) {
    return _diagnostic(
      code: failure.code,
      userMessage: failure.userMessage,
      correlationId: failure.correlationId,
      technicalReason: failure.technicalReason,
    );
  }

  ErrorDiagnostic _diagnostic({
    required String code,
    required String userMessage,
    required String technicalReason,
    String correlationId = 'unavailable',
  }) {
    return ErrorDiagnostic.capture(
      code: code,
      operation: 'register_account',
      userMessage: userMessage,
      correlationId: correlationId,
      technicalReason: technicalReason,
    );
  }

  Map<String, List<String>> _validate({
    required String email,
    required String password,
    required String passwordConfirmation,
  }) {
    final errors = <String, List<String>>{};
    if (email.isEmpty) {
      errors['email'] = ['Email is required.'];
    } else if (email.length > 320 || !_emailPattern.hasMatch(email)) {
      errors['email'] = ['Enter a valid email address.'];
    }
    final passwordLength = password.runes.length;
    if (passwordLength < 8) {
      errors['password'] = ['Password must be at least 8 characters.'];
    } else if (passwordLength > 128) {
      errors['password'] = ['Password must be 128 characters or fewer.'];
    }
    if (passwordConfirmation.isEmpty) {
      errors['password_confirmation'] = ['Password confirmation is required.'];
    } else if (password != passwordConfirmation) {
      errors['password_confirmation'] = ['Passwords do not match.'];
    }
    return errors;
  }
}
