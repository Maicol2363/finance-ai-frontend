import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/diagnostics/error_diagnostic.dart';
import '../data/auth_session_repository.dart';
import '../data/secure_credential_store.dart';
import '../domain/session_models.dart';
import 'auth_session_state.dart';

final authSessionControllerProvider =
    NotifierProvider<AuthSessionController, AuthSessionState>(
      AuthSessionController.new,
    );

class AuthSessionController extends Notifier<AuthSessionState> {
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  Future<bool>? _refreshInFlight;

  @override
  AuthSessionState build() {
    Future<void>.microtask(restoreSession);
    return const AuthSessionState();
  }

  Future<LoginSubmitOutcome> login({
    required String email,
    required String password,
  }) async {
    if (state.isBusy) {
      return LoginSubmitOutcome.ignored;
    }
    final normalizedEmail = email.trim();
    final localErrors = _validate(email: normalizedEmail, password: password);
    if (localErrors.isNotEmpty) {
      state = AuthSessionState(
        status: AuthSessionStatus.unauthenticated,
        fieldErrors: Map.unmodifiable(localErrors),
        diagnostic: _diagnostic(
          code: 'login_invalid',
          operation: 'login_account',
          userMessage: 'Por favor, corrige los campos marcados.',
          technicalReason: 'client_validation',
        ),
      );
      return LoginSubmitOutcome.invalid;
    }

    state = const AuthSessionState(status: AuthSessionStatus.submitting);
    try {
      final issued = await ref
          .read(authSessionRepositoryProvider)
          .login(
            LoginRequest(
              email: normalizedEmail,
              password: password,
              platform: AppConfig.sessionPlatform,
            ),
          );
      if (!await _storeAndPublish(issued, operation: 'login_account')) {
        return LoginSubmitOutcome.failure;
      }
      return LoginSubmitOutcome.success;
    } on AuthSessionFailure catch (failure) {
      state = AuthSessionState(
        status: AuthSessionStatus.unauthenticated,
        diagnostic: _diagnosticFor(failure, operation: 'login_account'),
      );
    } on Object {
      state = AuthSessionState(
        status: AuthSessionStatus.unauthenticated,
        diagnostic: _diagnostic(
          code: 'unexpected_client_error',
          operation: 'login_account',
          userMessage: 'No se pudo iniciar sesión. Inténtalo de nuevo.',
          technicalReason: 'unclassified_client_failure',
        ),
      );
    }
    return LoginSubmitOutcome.failure;
  }

  Future<void> restoreSession() async {
    state = const AuthSessionState(status: AuthSessionStatus.checking);
    String? renewable;
    try {
      renewable = await ref.read(secureCredentialStoreProvider).read();
    } on Object {
      state = AuthSessionState(
        status: AuthSessionStatus.restorationRetry,
        diagnostic: _storageDiagnostic(operation: 'restore_session'),
      );
      return;
    }
    if (renewable == null || renewable.isEmpty) {
      state = const AuthSessionState(status: AuthSessionStatus.unauthenticated);
      return;
    }
    await _refreshFrom(renewable, restoration: true);
  }

  Future<bool> refreshSession() {
    final existing = _refreshInFlight;
    if (existing != null) {
      return existing;
    }
    final operation = _refreshFromStore();
    _refreshInFlight = operation;
    operation.whenComplete(() {
      if (identical(_refreshInFlight, operation)) {
        _refreshInFlight = null;
      }
    });
    return operation;
  }

  Future<T> runProtected<T>(
    Future<T> Function(String accessCredential) request,
  ) async {
    final access = state.accessCredential;
    if (!state.isAuthenticated || access == null) {
      throw const InvalidSessionFailure();
    }
    try {
      return await request(access);
    } on InvalidSessionFailure {
      if (!await refreshSession()) {
        rethrow;
      }
      final replacement = state.accessCredential;
      if (!state.isAuthenticated || replacement == null) {
        throw const InvalidSessionFailure();
      }
      return request(replacement);
    }
  }

  Future<void> logout() async {
    if (!state.isAuthenticated ||
        state.status == AuthSessionStatus.loggingOut) {
      return;
    }
    final user = state.user;
    final access = state.accessCredential;
    final accessExpiry = state.accessExpiresAt;
    state = AuthSessionState(
      status: AuthSessionStatus.loggingOut,
      user: user,
      accessCredential: access,
      accessExpiresAt: accessExpiry,
    );

    ErrorDiagnostic? warning;
    String? renewable;
    try {
      renewable = await ref.read(secureCredentialStoreProvider).read();
      if (renewable != null && renewable.isNotEmpty) {
        await ref.read(authSessionRepositoryProvider).logout(renewable);
      }
    } on AuthSessionFailure catch (failure) {
      warning = _diagnosticFor(failure, operation: 'logout_account');
    } on Object {
      warning = _diagnostic(
        code: 'logout_unconfirmed',
        operation: 'logout_account',
        userMessage: 'Se cerró la sesión en este dispositivo, pero no se pudo confirmar en el servidor.',
        technicalReason: 'unclassified_logout_failure',
      );
    }

    try {
      await ref.read(secureCredentialStoreProvider).delete();
    } on Object {
      warning = _storageDiagnostic(
        operation: 'logout_account',
        userMessage: 'No se pudo borrar la sesión segura. Cierra la aplicación e inténtalo de nuevo.',
      );
    }
    state = AuthSessionState(
      status: AuthSessionStatus.unauthenticated,
      logoutWarning: warning,
    );
  }

  Future<void> clearLocalSession() async {
    try {
      await ref.read(secureCredentialStoreProvider).delete();
      state = const AuthSessionState(status: AuthSessionStatus.unauthenticated);
    } on Object {
      state = AuthSessionState(
        status: AuthSessionStatus.restorationRetry,
        diagnostic: _storageDiagnostic(operation: 'clear_local_session'),
      );
    }
  }

  void clearFieldError(String field) {
    state = state.withoutFieldError(field);
  }

  Future<bool> _refreshFromStore() async {
    String? renewable;
    try {
      renewable = await ref.read(secureCredentialStoreProvider).read();
    } on Object {
      state = AuthSessionState(
        status: AuthSessionStatus.restorationRetry,
        diagnostic: _storageDiagnostic(operation: 'refresh_session'),
      );
      return false;
    }
    if (renewable == null || renewable.isEmpty) {
      state = const AuthSessionState(status: AuthSessionStatus.unauthenticated);
      return false;
    }
    return _refreshFrom(renewable, restoration: false);
  }

  Future<bool> _refreshFrom(
    String renewable, {
    required bool restoration,
  }) async {
    try {
      final issued = await ref
          .read(authSessionRepositoryProvider)
          .refresh(renewable);
      return await _storeAndPublish(
        issued,
        operation: restoration ? 'restore_session' : 'refresh_session',
      );
    } on InvalidSessionFailure {
      try {
        await ref.read(secureCredentialStoreProvider).delete();
      } on Object {
        state = AuthSessionState(
          status: AuthSessionStatus.restorationRetry,
          diagnostic: _storageDiagnostic(operation: 'clear_invalid_session'),
        );
        return false;
      }
      state = const AuthSessionState(status: AuthSessionStatus.unauthenticated);
      return false;
    } on AuthSessionFailure catch (failure) {
      state = AuthSessionState(
        status: AuthSessionStatus.restorationRetry,
        diagnostic: _diagnosticFor(
          failure,
          operation: restoration ? 'restore_session' : 'refresh_session',
        ),
      );
      return false;
    } on Object {
      state = AuthSessionState(
        status: AuthSessionStatus.restorationRetry,
        diagnostic: _diagnostic(
          code: 'unexpected_client_error',
          operation: restoration ? 'restore_session' : 'refresh_session',
          userMessage: 'No se pudo restaurar la sesión. Inténtalo de nuevo.',
          technicalReason: 'unclassified_client_failure',
        ),
      );
      return false;
    }
  }

  Future<bool> _storeAndPublish(
    IssuedAuthSession issued, {
    required String operation,
  }) async {
    try {
      await ref
          .read(secureCredentialStoreProvider)
          .replace(issued.renewableCredential);
    } on Object {
      await _bestEffortRevoke(issued.renewableCredential);
      try {
        await ref.read(secureCredentialStoreProvider).delete();
      } on Object {
        // The diagnostic below remains the only safe user-visible detail.
      }
      state = AuthSessionState(
        status: AuthSessionStatus.unauthenticated,
        diagnostic: _storageDiagnostic(operation: operation),
      );
      return false;
    }
    state = AuthSessionState(
      status: AuthSessionStatus.authenticated,
      user: issued.user,
      accessCredential: issued.accessCredential,
      accessExpiresAt: issued.accessExpiresAt,
    );
    return true;
  }

  Future<void> _bestEffortRevoke(String renewable) async {
    try {
      await ref.read(authSessionRepositoryProvider).logout(renewable);
    } on Object {
      return;
    }
  }

  Map<String, List<String>> _validate({
    required String email,
    required String password,
  }) {
    final errors = <String, List<String>>{};
    if (email.isEmpty) {
      errors['email'] = ['El correo electrónico es obligatorio.'];
    } else if (email.length > 320 || !_emailPattern.hasMatch(email)) {
      errors['email'] = ['Ingresa un correo electrónico válido.'];
    }
    final length = password.runes.length;
    if (length < 1) {
      errors['password'] = ['La contraseña es obligatoria.'];
    } else if (length > 128) {
      errors['password'] = ['La contraseña debe tener 128 caracteres o menos.'];
    }
    return errors;
  }

  ErrorDiagnostic _diagnosticFor(
    AuthSessionFailure failure, {
    required String operation,
  }) {
    return _diagnostic(
      code: failure.code,
      operation: operation,
      userMessage: _safeAuthMessage(failure.code),
      correlationId: failure.correlationId,
      technicalReason: failure.technicalReason,
    );
  }

  String _safeAuthMessage(String code) => switch (code) {
    'invalid_credentials' =>
      'El correo electrónico o la contraseña no son correctos.',
    'session_invalid' => 'La sesión ya no es válida. Inicia sesión de nuevo.',
    'network_unavailable' => 'No se pudo conectar con el servicio. Revisa tu conexión e inténtalo de nuevo.',
    'service_unavailable' => 'El servicio no está disponible temporalmente. Inténtalo de nuevo más tarde.',
    'login_rate_limited' =>
      'Demasiados intentos. Espera un momento e inténtalo de nuevo.',
    'unexpected_response' =>
      'No se pudo completar la operación. Inténtalo de nuevo.',
    _ => 'No se pudo completar la operación. Inténtalo de nuevo.',
  };

  ErrorDiagnostic _storageDiagnostic({
    required String operation,
    String userMessage = 'No se pudo acceder al almacenamiento seguro. Cierra la aplicación e inténtalo de nuevo.',
  }) {
    return _diagnostic(
      code: 'secure_storage_unavailable',
      operation: operation,
      userMessage: userMessage,
      technicalReason: 'platform_secure_storage_failure',
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
