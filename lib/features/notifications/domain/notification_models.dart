/// What the server says about the signed-in person's email notifications.
///
/// The address only ever arrives masked (`a***@example.com`); the full address is never
/// requested, stored or shown by this feature.
class NotificationPreferences {
  const NotificationPreferences({
    required this.emailHint,
    required this.emailVerified,
    required this.emailEnabled,
    required this.budgetAlerts,
    required this.showAmounts,
    required this.deliveryAvailable,
  });

  factory NotificationPreferences.fromJson(Map<String, Object?> json) {
    return NotificationPreferences(
      emailHint: _string(json, 'email_hint'),
      emailVerified: _bool(json, 'email_verified'),
      emailEnabled: _bool(json, 'email_enabled'),
      budgetAlerts: _bool(json, 'budget_alerts'),
      showAmounts: _bool(json, 'show_amounts'),
      deliveryAvailable: _bool(json, 'delivery_available'),
    );
  }

  final String emailHint;
  final bool emailVerified;
  final bool emailEnabled;
  final bool budgetAlerts;
  final bool showAmounts;

  /// False when this deployment cannot send email: the screen explains it instead of failing.
  final bool deliveryAvailable;

  NotificationPreferences copyWith({
    bool? emailEnabled,
    bool? budgetAlerts,
    bool? showAmounts,
  }) {
    return NotificationPreferences(
      emailHint: emailHint,
      emailVerified: emailVerified,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      budgetAlerts: budgetAlerts ?? this.budgetAlerts,
      showAmounts: showAmounts ?? this.showAmounts,
      deliveryAvailable: deliveryAvailable,
    );
  }
}

class VerificationIssued {
  const VerificationIssued({
    required this.emailHint,
    required this.expiresInSeconds,
    required this.resendInSeconds,
  });

  factory VerificationIssued.fromJson(Map<String, Object?> json) {
    return VerificationIssued(
      emailHint: _string(json, 'email_hint'),
      expiresInSeconds: _positiveInt(json, 'expires_in_seconds'),
      resendInSeconds: _positiveInt(json, 'resend_in_seconds'),
    );
  }

  final String emailHint;
  final int expiresInSeconds;
  final int resendInSeconds;
}

enum TestEmailStatus { sent, queued }

class NotificationFailure implements Exception {
  const NotificationFailure({
    required this.code,
    required this.userMessage,
    this.correlationId = 'unavailable',
    this.technicalReason = 'notification_operation_failure',
    this.retryAfterSeconds,
    this.isMutationOutcomeUncertain = false,
  });

  final String code;
  final String userMessage;
  final String correlationId;
  final String technicalReason;

  /// Seconds the server asked us to wait (`Retry-After`), when it did.
  final int? retryAfterSeconds;
  final bool isMutationOutcomeUncertain;
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Expected a non-empty string for $key');
}

bool _bool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('Expected a boolean for $key');
}

int _positiveInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int && value > 0) return value;
  throw FormatException('Expected a positive integer for $key');
}
