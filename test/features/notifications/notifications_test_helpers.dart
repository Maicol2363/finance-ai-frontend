import 'package:finance_ai/features/notifications/data/notifications_repository.dart';
import 'package:finance_ai/features/notifications/domain/notification_models.dart';

Map<String, Object?> preferencesJson({
  bool verified = true,
  bool enabled = true,
  bool budgetAlerts = true,
  bool showAmounts = true,
  bool deliveryAvailable = true,
}) => {
  'email_hint': 'a***@example.com',
  'email_verified': verified,
  'email_enabled': enabled,
  'budget_alerts': budgetAlerts,
  'show_amounts': showAmounts,
  'delivery_available': deliveryAvailable,
};

NotificationPreferences preferences({
  bool verified = true,
  bool enabled = true,
  bool budgetAlerts = true,
  bool showAmounts = true,
  bool deliveryAvailable = true,
}) => NotificationPreferences.fromJson(
  preferencesJson(
    verified: verified,
    enabled: enabled,
    budgetAlerts: budgetAlerts,
    showAmounts: showAmounts,
    deliveryAvailable: deliveryAvailable,
  ),
);

/// An in-memory server: it records every call and can be told to fail the next one.
class FakeNotificationsRepository implements NotificationsRepository {
  FakeNotificationsRepository({NotificationPreferences? initial})
    : current = initial ?? preferences();

  NotificationPreferences current;
  Object? failNext;
  String expectedCode = '123456';
  TestEmailStatus testStatus = TestEmailStatus.sent;
  final calls = <String>[];

  void _maybeFail() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  @override
  Future<NotificationPreferences> load() async {
    calls.add('load');
    _maybeFail();
    return current;
  }

  @override
  Future<NotificationPreferences> update({
    bool? emailEnabled,
    bool? budgetAlerts,
    bool? showAmounts,
  }) async {
    calls.add(
      'update:${emailEnabled ?? '-'}:${budgetAlerts ?? '-'}:${showAmounts ?? '-'}',
    );
    _maybeFail();
    current = current.copyWith(
      emailEnabled: emailEnabled,
      budgetAlerts: budgetAlerts,
      showAmounts: showAmounts,
    );
    return current;
  }

  @override
  Future<VerificationIssued> requestVerification() async {
    calls.add('request');
    _maybeFail();
    return const VerificationIssued(
      emailHint: 'a***@example.com',
      expiresInSeconds: 900,
      resendInSeconds: 60,
    );
  }

  @override
  Future<NotificationPreferences> verify(String code) async {
    calls.add('verify');
    _maybeFail();
    if (code != expectedCode) {
      throw const NotificationFailure(
        code: 'verification_code_invalid',
        userMessage: 'Ese código no es correcto, o no hay un código pendiente. Pide uno nuevo.',
        correlationId: 'verify-1',
        technicalReason: 'http_400',
      );
    }
    current = preferences(verified: true, enabled: true);
    return current;
  }

  @override
  Future<TestEmailStatus> sendTestEmail() async {
    calls.add('test');
    _maybeFail();
    return testStatus;
  }
}
