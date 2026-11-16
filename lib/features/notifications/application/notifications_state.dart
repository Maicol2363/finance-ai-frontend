import '../../../core/diagnostics/error_diagnostic.dart';
import '../domain/notification_models.dart';

enum NotificationsLoadStatus { initial, loading, ready, failure }

/// Where the verification flow is. The code field appears once a code was sent.
enum VerificationStep { idle, sending, codeSent, verifying }

class NotificationsState {
  const NotificationsState({
    this.loadStatus = NotificationsLoadStatus.initial,
    this.preferences,
    this.isSaving = false,
    this.verificationStep = VerificationStep.idle,
    this.verification,
    this.resendAvailableAt,
    this.isSendingTest = false,
    this.testStatus,
    this.diagnostic,
  });

  final NotificationsLoadStatus loadStatus;
  final NotificationPreferences? preferences;

  /// A preference switch is being saved (all switches wait for it).
  final bool isSaving;
  final VerificationStep verificationStep;
  final VerificationIssued? verification;

  /// When the person may ask for another code (the server enforces it too).
  final DateTime? resendAvailableAt;
  final bool isSendingTest;
  final TestEmailStatus? testStatus;
  final ErrorDiagnostic? diagnostic;

  bool get isBusy =>
      isSaving ||
      isSendingTest ||
      verificationStep == VerificationStep.sending ||
      verificationStep == VerificationStep.verifying;

  NotificationsState copyWith({
    NotificationsLoadStatus? loadStatus,
    NotificationPreferences? preferences,
    bool? isSaving,
    VerificationStep? verificationStep,
    VerificationIssued? verification,
    bool clearVerification = false,
    DateTime? resendAvailableAt,
    bool clearResend = false,
    bool? isSendingTest,
    TestEmailStatus? testStatus,
    bool clearTestStatus = false,
    ErrorDiagnostic? diagnostic,
    bool clearDiagnostic = false,
  }) {
    return NotificationsState(
      loadStatus: loadStatus ?? this.loadStatus,
      preferences: preferences ?? this.preferences,
      isSaving: isSaving ?? this.isSaving,
      verificationStep: verificationStep ?? this.verificationStep,
      verification: clearVerification
          ? null
          : (verification ?? this.verification),
      resendAvailableAt: clearResend
          ? null
          : (resendAvailableAt ?? this.resendAvailableAt),
      isSendingTest: isSendingTest ?? this.isSendingTest,
      testStatus: clearTestStatus ? null : (testStatus ?? this.testStatus),
      diagnostic: clearDiagnostic ? null : (diagnostic ?? this.diagnostic),
    );
  }
}
