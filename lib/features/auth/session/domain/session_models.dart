class LoginRequest {
  const LoginRequest({
    required this.email,
    required this.password,
    required this.platform,
  });

  final String email;
  final String password;
  final String platform;

  Map<String, Object?> toJson() => {
    'email': email,
    'password': password,
    'platform': platform,
  };
}

class AuthenticatedUser {
  const AuthenticatedUser({
    required this.id,
    required this.email,
    required this.preferredCurrency,
  });

  factory AuthenticatedUser.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final email = json['email'];
    final currency = json['preferred_currency'];
    if (id is! int || email is! String || currency is! String) {
      throw const FormatException('Invalid authenticated user response');
    }
    return AuthenticatedUser(id: id, email: email, preferredCurrency: currency);
  }

  final int id;
  final String email;
  final String preferredCurrency;
}

class IssuedAuthSession {
  const IssuedAuthSession({
    required this.user,
    required this.accessCredential,
    required this.renewableCredential,
    required this.accessExpiresAt,
    required this.renewableExpiresAt,
    required this.absoluteExpiresAt,
  });

  factory IssuedAuthSession.fromJson(Map<String, Object?> json) {
    final user = json['user'];
    final tokenType = json['token_type'];
    final access = json['access_credential'];
    final renewable = json['renewable_credential'];
    final accessExpiry = json['access_expires_at'];
    final renewableExpiry = json['renewable_expires_at'];
    final absoluteExpiry = json['absolute_expires_at'];
    if (user is! Map<String, Object?> ||
        tokenType != 'Bearer' ||
        access is! String ||
        renewable is! String ||
        access.length != 43 ||
        renewable.length != 43 ||
        accessExpiry is! String ||
        renewableExpiry is! String ||
        absoluteExpiry is! String) {
      throw const FormatException('Invalid issued session response');
    }
    final parsedAccess = DateTime.tryParse(accessExpiry);
    final parsedRenewable = DateTime.tryParse(renewableExpiry);
    final parsedAbsolute = DateTime.tryParse(absoluteExpiry);
    if (parsedAccess == null ||
        parsedRenewable == null ||
        parsedAbsolute == null) {
      throw const FormatException('Invalid session expiry response');
    }
    return IssuedAuthSession(
      user: AuthenticatedUser.fromJson(user),
      accessCredential: access,
      renewableCredential: renewable,
      accessExpiresAt: parsedAccess.toUtc(),
      renewableExpiresAt: parsedRenewable.toUtc(),
      absoluteExpiresAt: parsedAbsolute.toUtc(),
    );
  }

  final AuthenticatedUser user;
  final String accessCredential;
  final String renewableCredential;
  final DateTime accessExpiresAt;
  final DateTime renewableExpiresAt;
  final DateTime absoluteExpiresAt;
}

sealed class AuthSessionFailure implements Exception {
  const AuthSessionFailure({
    required this.code,
    required this.userMessage,
    this.correlationId = 'unavailable',
    this.technicalReason = 'application_failure',
  });

  final String code;
  final String userMessage;
  final String correlationId;
  final String technicalReason;
}

class InvalidCredentialsFailure extends AuthSessionFailure {
  const InvalidCredentialsFailure({
    super.correlationId,
    super.technicalReason = 'credentials_rejected',
  }) : super(
         code: 'invalid_credentials',
         userMessage: 'Invalid email or password.',
       );
}

class InvalidSessionFailure extends AuthSessionFailure {
  const InvalidSessionFailure({
    super.correlationId,
    super.technicalReason = 'session_rejected',
  }) : super(
         code: 'session_invalid',
         userMessage: 'Your session is no longer valid. Please log in again.',
       );
}

class AuthRetryableFailure extends AuthSessionFailure {
  const AuthRetryableFailure({
    required super.code,
    required super.userMessage,
    super.correlationId,
    super.technicalReason = 'retryable_failure',
  });
}
