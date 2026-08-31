class RegistrationRequest {
  const RegistrationRequest({
    required this.email,
    required this.password,
    required this.passwordConfirmation,
  });

  final String email;
  final String password;
  final String passwordConfirmation;

  Map<String, Object?> toJson() => {
    'email': email,
    'password': password,
    'password_confirmation': passwordConfirmation,
  };
}

class RegisteredUser {
  const RegisteredUser({
    required this.id,
    required this.email,
    required this.preferredCurrency,
  });

  factory RegisteredUser.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final email = json['email'];
    final preferredCurrency = json['preferred_currency'];
    if (id is! int || email is! String || preferredCurrency is! String) {
      throw const FormatException('Invalid registered user response');
    }
    return RegisteredUser(
      id: id,
      email: email,
      preferredCurrency: preferredCurrency,
    );
  }

  final int id;
  final String email;
  final String preferredCurrency;
}

class RegistrationResult {
  const RegistrationResult({required this.user, required this.message});

  factory RegistrationResult.fromJson(Map<String, Object?> json) {
    final user = json['user'];
    final message = json['message'];
    if (user is! Map<String, Object?> || message is! String) {
      throw const FormatException('Invalid registration response');
    }
    return RegistrationResult(
      user: RegisteredUser.fromJson(user),
      message: message,
    );
  }

  final RegisteredUser user;
  final String message;
}

sealed class RegistrationFailure implements Exception {
  const RegistrationFailure({
    required this.code,
    required this.userMessage,
    this.fieldErrors = const {},
    this.correlationId = 'unavailable',
    this.technicalReason = 'application_failure',
  });

  final String code;
  final String userMessage;
  final Map<String, List<String>> fieldErrors;
  final String correlationId;
  final String technicalReason;
}

class RegistrationValidationFailure extends RegistrationFailure {
  const RegistrationValidationFailure({
    required super.userMessage,
    required super.fieldErrors,
    super.correlationId,
    super.technicalReason = 'validation_failure',
  }) : super(code: 'registration_invalid');
}

class RegistrationConflictFailure extends RegistrationFailure {
  const RegistrationConflictFailure({
    required super.userMessage,
    super.correlationId,
    super.technicalReason = 'duplicate_conflict',
  }) : super(code: 'email_already_registered');
}

class RegistrationRetryableFailure extends RegistrationFailure {
  const RegistrationRetryableFailure({
    required super.code,
    required super.userMessage,
    super.correlationId,
    super.technicalReason = 'retryable_failure',
  });
}
