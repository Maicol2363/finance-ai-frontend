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
      onFailure: (_) {
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
      onFailure: (failure) {
        state = state.copyWith(verificationStep: _stepAfterFailure(failure));
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
      onFailure: (_) {
        state = state.copyWith(verificationStep: VerificationStep.codeSent);
      },
      // A lost reply may hide a success: ask the server before showing the code field again.
      refreshOnUncertainFailure: true,
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
      onFailure: (_) {
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
      onFailure: (_) {
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

  /// Where the flow goes after a failed code request. A code that was just sent (cooldown) or
  /// whose reply was lost may already be in the inbox, so the field stays reachable.
  VerificationStep _stepAfterFailure(NotificationFailure? failure) {
    final codeMayBeOnItsWay =
        failure != null &&
        (failure.code == 'verification_cooldown' ||
            failure.isMutationOutcomeUncertain);
    return state.verification != null || codeMayBeOnItsWay
        ? VerificationStep.codeSent
        : VerificationStep.idle;
  }

  /// Runs one action and turns every failure into a safe, copyable diagnostic.
  Future<void> _run(
    String operation, {
    required Future<void> Function() action,
    required void Function(NotificationFailure? failure) onFailure,
    bool refreshOnUncertainFailure = false,
  }) async {
    try {
      await action();
    } on InvalidSessionFailure catch (failure) {
      onFailure(null);
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
      onFailure(failure);
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
      final shouldReload =
          (refreshOnUncertainFailure && failure.isMutationOutcomeUncertain) ||
          failure.code == 'email_already_verified';
      if (shouldReload) {
        try {
          final fresh = await _repository.load();
          state = state.copyWith(preferences: fresh);
          if (fresh.emailVerified) {
            state = state.copyWith(
              verificationStep: VerificationStep.idle,
              clearVerification: true,
              clearResend: true,
            );
          }
        } on Object {
          // Keep the original diagnostic; the person can reload manually.
        }
      }
      state = state.copyWith(diagnostic: diagnostic);
    } on Object {
      onFailure(null);
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
