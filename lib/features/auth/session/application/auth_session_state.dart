import '../../../../core/diagnostics/error_diagnostic.dart';
import '../domain/session_models.dart';

enum AuthSessionStatus {
  checking,
  unauthenticated,
  submitting,
  authenticated,
  restorationRetry,
  loggingOut,
}

class AuthSessionState {
  const AuthSessionState({
    this.status = AuthSessionStatus.checking,
    this.user,
    this.accessCredential,
    this.accessExpiresAt,
    this.fieldErrors = const {},
    this.diagnostic,
    this.logoutWarning,
  });

  final AuthSessionStatus status;
  final AuthenticatedUser? user;
  final String? accessCredential;
  final DateTime? accessExpiresAt;
  final Map<String, List<String>> fieldErrors;
  final ErrorDiagnostic? diagnostic;
  final ErrorDiagnostic? logoutWarning;

  bool get isAuthenticated =>
      status == AuthSessionStatus.authenticated ||
      status == AuthSessionStatus.loggingOut;

  bool get isBusy =>
      status == AuthSessionStatus.submitting ||
      status == AuthSessionStatus.loggingOut;

  AuthSessionState withoutFieldError(String field) {
    if (!fieldErrors.containsKey(field)) {
      return this;
    }
    final nextErrors = Map<String, List<String>>.of(fieldErrors)..remove(field);
    return AuthSessionState(
      status: AuthSessionStatus.unauthenticated,
      fieldErrors: Map.unmodifiable(nextErrors),
      diagnostic: diagnostic,
      logoutWarning: logoutWarning,
    );
  }
}

enum LoginSubmitOutcome { invalid, failure, success, ignored }
