import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/error_diagnostic.dart';
import '../../auth/session/domain/session_models.dart';
import '../data/notifications_repository.dart';
import '../domain/notification_models.dart';
import 'notifications_state.dart';

/// The current time, replaceable in tests so the resend countdown is deterministic.
final notificationsClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final notificationsControllerProvider =
    NotifierProvider<NotificationsController, NotificationsState>(
      NotificationsController.new,
    );

class NotificationsController extends Notifier<NotificationsState> {
  @override
  NotificationsState build() => const NotificationsState();

  NotificationsRepository get _repository =>
      ref.read(notificationsRepositoryProvider);

  Future<void> load() async {
    if (state.loadStatus == NotificationsLoadStatus.loading) return;
    state = state.copyWith(
      loadStatus: NotificationsLoadStatus.loading,
      clearDiagnostic: true,
    );
    await _run(
      'load_notifications',
      onFailure: () {
        state = state.copyWith(loadStatus: NotificationsLoadStatus.failure);
      },
      action: () async {
        final preferences = await _repository.load();
        state = state.copyWith(
          loadStatus: NotificationsLoadStatus.ready,
          preferences: preferences,
        );
      },
    );
  }

  Future<void> setEmailEnabled(bool value) =>
      _save('update_notifications', emailEnabled: value);

  Future<void> setBudgetAlerts(bool value) =>
      _save('update_notifications', budgetAlerts: value);

  Future<void> setShowAmounts(bool value) =>
      _save('update_notifications', showAmounts: value);

  Future<void> startVerification() async {
    if (state.isBusy) return;
    state = state.copyWith(
      verificationStep: VerificationStep.sending,
      clearDiagnostic: true,
    );
    await _run(
      'request_email_verification',
      onFailure: () {
        state = state.copyWith(verificationStep: _stepAfterFailure());
      },
      action: () async {
        final issued = await _repository.requestVerification();
        final now = ref.read(notificationsClockProvider)();
        state = state.copyWith(
          verificationStep: VerificationStep.codeSent,
          verification: issued,
          resendAvailableAt: now.add(Duration(seconds: issued.resendInSeconds)),
        );
      },
    );
  }

  /// Returns true when the address is now verified.
  Future<bool> verify(String code) async {
    if (state.isBusy) return false;
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      state = state.copyWith(
        diagnostic: ErrorDiagnostic.capture(
          code: 'verification_code_invalid',
          operation: 'verify_email',
          userMessage: 'Escribe los 6 dígitos del código.',
          technicalReason: 'client_validation',
        ),
      );
      return false;
    }
    state = state.copyWith(
      verificationStep: VerificationStep.verifying,
      clearDiagnostic: true,
    );
    var verified = false;
    await _run(
      'verify_email',
      onFailure: () {
        state = state.copyWith(verificationStep: VerificationStep.codeSent);
      },
      action: () async {
        final preferences = await _repository.verify(code);
        state = state.copyWith(
          preferences: preferences,
          verificationStep: VerificationStep.idle,
          clearVerification: true,
          clearResend: true,
        );
        verified = true;
      },
    );
    return verified;
  }

  Future<void> sendTestEmail() async {
    if (state.isBusy) return;
    state = state.copyWith(
      isSendingTest: true,
      clearTestStatus: true,
      clearDiagnostic: true,
    );
    await _run(
      'send_test_email',
      onFailure: () {
        state = state.copyWith(isSendingTest: false);
      },
      action: () async {
        final status = await _repository.sendTestEmail();
        state = state.copyWith(isSendingTest: false, testStatus: status);
      },
    );
  }

  void dismissDiagnostic() => state = state.copyWith(clearDiagnostic: true);

  Future<void> _save(
    String operation, {
    bool? emailEnabled,
    bool? budgetAlerts,
    bool? showAmounts,
  }) async {
    if (state.isBusy) return;
    state = state.copyWith(
      isSaving: true,
      clearTestStatus: true,
      clearDiagnostic: true,
    );
    await _run(
      operation,
      onFailure: () async {
        state = state.copyWith(isSaving: false);
      },
      action: () async {
        final preferences = await _repository.update(
          emailEnabled: emailEnabled,
          budgetAlerts: budgetAlerts,
          showAmounts: showAmounts,
        );
        state = state.copyWith(isSaving: false, preferences: preferences);
      },
      refreshOnUncertainFailure: true,
    );
  }

  VerificationStep _stepAfterFailure() => state.verification == null
      ? VerificationStep.idle
      : VerificationStep.codeSent;

  /// Runs one action and turns every failure into a safe, copyable diagnostic.
  Future<void> _run(
    String operation, {
    required Future<void> Function() action,
    required void Function() onFailure,
    bool refreshOnUncertainFailure = false,
  }) async {
    try {
      await action();
    } on InvalidSessionFailure catch (failure) {
      onFailure();
      state = state.copyWith(
        diagnostic: ErrorDiagnostic.capture(
          code: failure.code,
          operation: operation,
          userMessage: failure.userMessage,
          correlationId: failure.correlationId,
          technicalReason: failure.technicalReason,
        ),
      );
    } on NotificationFailure catch (failure) {
      onFailure();
      var diagnostic = ErrorDiagnostic.capture(
        code: failure.code,
        operation: operation,
        userMessage: failure.userMessage,
        correlationId: failure.correlationId,
        technicalReason: failure.technicalReason,
      );
      if (failure.retryAfterSeconds != null) {
        final until = ref
            .read(notificationsClockProvider)()
            .add(Duration(seconds: failure.retryAfterSeconds!));
        state = state.copyWith(resendAvailableAt: until);
      }
      if (refreshOnUncertainFailure && failure.isMutationOutcomeUncertain) {
        try {
          state = state.copyWith(preferences: await _repository.load());
        } on Object {
          // Keep the original diagnostic; the person can reload manually.
        }
      }
      state = state.copyWith(diagnostic: diagnostic);
    } on Object {
      onFailure();
      state = state.copyWith(
        diagnostic: ErrorDiagnostic.capture(
          code: 'unexpected_client_error',
          operation: operation,
          userMessage: 'La operación no se pudo completar. Inténtalo de nuevo.',
          technicalReason: 'unclassified_client_failure',
        ),
      );
    }
  }
}
