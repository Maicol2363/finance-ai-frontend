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
          userMessage: 'Por favor, corrige los campos marcados.',
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
      final fieldErrors = _safeFieldErrors(failure.fieldErrors);
      state = RegistrationState(
        status: RegistrationStatus.failure,
        fieldErrors: Map.unmodifiable(fieldErrors),
        generalError: fieldErrors.isEmpty
            ? _safeRegistrationMessage(failure.code)
            : null,
        diagnostic: _diagnosticForFailure(failure),
      );
    } on RegistrationConflictFailure catch (failure) {
      state = RegistrationState(
        status: RegistrationStatus.failure,
        fieldErrors: {
          'email': [_safeRegistrationMessage(failure.code)],
        },
        diagnostic: _diagnosticForFailure(failure),
      );
    } on RegistrationFailure catch (failure) {
      state = RegistrationState(
        status: RegistrationStatus.failure,
        generalError: _safeRegistrationMessage(failure.code),
        diagnostic: _diagnosticForFailure(failure),
      );
    } on Object {
      const message = 'No se pudo completar el registro. Inténtalo de nuevo.';
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
      userMessage: _safeRegistrationMessage(failure.code),
      correlationId: failure.correlationId,
      technicalReason: failure.technicalReason,
    );
  }

  Map<String, List<String>> _safeFieldErrors(
    Map<String, List<String>> fieldErrors,
  ) {
    return {
      for (final entry in fieldErrors.entries)
        if (_registrationFieldMessage(entry.key) case final message?)
          entry.key: [message],
    };
  }

  String? _registrationFieldMessage(String field) => switch (field) {
    'email' => 'Ingresa un correo electrónico válido.',
    'password' => 'La contraseña no cumple los requisitos.',
    'password_confirmation' => 'Las contraseñas no coinciden.',
    _ => null,
  };

  String _safeRegistrationMessage(String code) => switch (code) {
    'email_already_registered' => 'Este correo ya está registrado.',
    'registration_invalid' => 'Revisa los campos e inténtalo de nuevo.',
    'network_unavailable' => 'No se pudo conectar con el servicio. Revisa tu conexión e inténtalo de nuevo.',
    'service_unavailable' => 'El servicio de registro no está disponible temporalmente. Inténtalo de nuevo más tarde.',
    'registration_rate_limited' =>
      'Demasiados intentos. Espera un momento e inténtalo de nuevo.',
    'unexpected_response' =>
      'No se pudo completar el registro. Inténtalo de nuevo.',
    _ => 'No se pudo completar el registro. Inténtalo de nuevo.',
  };

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
      errors['email'] = ['El correo electrónico es obligatorio.'];
    } else if (email.length > 320 || !_emailPattern.hasMatch(email)) {
      errors['email'] = ['Ingresa un correo electrónico válido.'];
    }
    final passwordLength = password.runes.length;
    if (passwordLength < 8) {
      errors['password'] = ['La contraseña debe tener al menos 8 caracteres.'];
    } else if (passwordLength > 128) {
      errors['password'] = ['La contraseña debe tener 128 caracteres o menos.'];
    }
    if (passwordConfirmation.isEmpty) {
      errors['password_confirmation'] = [
        'La confirmación de la contraseña es obligatoria.',
      ];
    } else if (password != passwordConfirmation) {
      errors['password_confirmation'] = ['Las contraseñas no coinciden.'];
    }
    return errors;
  }
}
