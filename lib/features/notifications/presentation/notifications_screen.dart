import 'dart:async';

import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/manage_widgets.dart';
import '../../../core/widgets/management_page_scaffold.dart';
import '../application/notifications_controller.dart';
import '../application/notifications_state.dart';
import '../domain/notification_models.dart';

/// Settings > Notificaciones: verify the address, choose what to receive, send a test email.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _codeController = TextEditingController();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (mounted) {
        ref.read(notificationsControllerProvider.notifier).load();
      }
    });
    // Repaints the resend countdown once a second; it does nothing else.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          ref.read(notificationsControllerProvider).resendAvailableAt != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);
    final preferences = state.preferences;

    return ManagementPageScaffold(
      title: 'Notificaciones',
      subtitle: 'Avisos por correo',
      leading: HeaderIconButton(
        icon: FinanceIcons.arrowBack,
        tooltip: 'Volver',
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/settings'),
      ),
      body: ListView(
        children: [
          if (state.loadStatus == NotificationsLoadStatus.loading ||
              state.isBusy)
            const LinearProgressIndicator(semanticsLabel: 'Procesando'),
          if (state.diagnostic != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: ErrorDiagnosticPanel(diagnostic: state.diagnostic!),
            ),
          if (state.loadStatus == NotificationsLoadStatus.failure &&
              preferences == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                key: const Key('notifications-retry'),
                onPressed: controller.load,
                child: const Text('Reintentar'),
              ),
            ),
          if (preferences != null) ..._content(state, preferences, controller),
        ],
      ),
    );
  }

  List<Widget> _content(
    NotificationsState state,
    NotificationPreferences preferences,
    NotificationsController controller,
  ) {
    if (!preferences.deliveryAvailable) {
      return const [
        SectionTitle('Avisos por correo'),
        _InfoCard(
          key: Key('notifications-unavailable'),
          text: 'Los avisos por correo no están disponibles por ahora. Tu app sigue funcionando igual.',
        ),
      ];
    }
    if (!preferences.emailVerified) {
      return _verification(state, preferences, controller);
    }
    return [
      const SectionTitle('Avisos por correo'),
      SettingsGroup(
        children: [
          _SwitchRow(
            switchKey: const Key('notifications-email-switch'),
            label: 'Recibir avisos por correo',
            subtitle: 'Enviados a ${preferences.emailHint}',
            value: preferences.emailEnabled,
            onChanged: state.isBusy ? null : controller.setEmailEnabled,
          ),
        ],
      ),
      if (preferences.emailEnabled) ...[
        const SectionTitle('Qué quieres recibir'),
        SettingsGroup(
          children: [
            _SwitchRow(
              switchKey: const Key('notifications-budget-switch'),
              label: 'Alertas de presupuesto',
              subtitle: 'Cuando llegues al 80 % y al 100 % de un límite',
              value: preferences.budgetAlerts,
              onChanged: state.isBusy ? null : controller.setBudgetAlerts,
            ),
            _SwitchRow(
              switchKey: const Key('notifications-amounts-switch'),
              label: 'Mostrar montos en el correo',
              subtitle: 'Si lo apagas, el correo solo dice el porcentaje usado',
              value: preferences.showAmounts,
              onChanged: state.isBusy ? null : controller.setShowAmounts,
            ),
          ],
        ),
        const SectionTitle('Prueba'),
        SettingsGroup(
          children: [
            SettingsRow(
              rowKey: const Key('notifications-test-row'),
              label: 'Enviarme un correo de prueba',
              subtitle: _testMessage(state.testStatus),
              onTap: state.isBusy ? null : controller.sendTestEmail,
            ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _verification(
    NotificationsState state,
    NotificationPreferences preferences,
    NotificationsController controller,
  ) {
    final codeSent =
        state.verificationStep == VerificationStep.codeSent ||
        state.verificationStep == VerificationStep.verifying;
    final remaining = _resendSeconds(state);
    return [
      const SectionTitle('Avisos por correo'),
      _InfoCard(
        key: const Key('notifications-verify-intro'),
        text: codeSent
            ? 'Te enviamos un código de 6 dígitos a ${preferences.emailHint}. '
                  'Vence en ${((state.verification?.expiresInSeconds ?? 900) / 60).round()} minutos.'
            : 'Para recibir avisos, primero confirma que ${preferences.emailHint} es tuyo. '
                  'Te enviaremos un código de 6 dígitos.',
      ),
      if (!codeSent)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: FilledButton(
            key: const Key('notifications-send-code'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: state.isBusy ? null : controller.startVerification,
            child: const Text('Enviar código'),
          ),
        )
      else ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: TextField(
            key: const Key('notifications-code-field'),
            controller: _codeController,
            enabled: !state.isBusy,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Código de 6 dígitos',
              counterText: '',
            ),
            onSubmitted: (_) => _submitCode(controller),
          ),
        ),
        FilledButton(
          key: const Key('notifications-verify'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: state.isBusy ? null : () => _submitCode(controller),
          child: const Text('Verificar'),
        ),
        TextButton(
          key: const Key('notifications-resend'),
          onPressed: state.isBusy || remaining > 0
              ? null
              : controller.startVerification,
          child: Text(
            remaining > 0
                ? 'Pedir otro código en $remaining s'
                : 'Pedir otro código',
          ),
        ),
      ],
    ];
  }

  Future<void> _submitCode(NotificationsController controller) async {
    final verified = await controller.verify(_codeController.text.trim());
    if (verified) _codeController.clear();
  }

  int _resendSeconds(NotificationsState state) {
    final until = state.resendAvailableAt;
    if (until == null) return 0;
    final seconds = until
        .difference(ref.read(notificationsClockProvider)())
        .inSeconds;
    return seconds < 0 ? 0 : seconds + 1;
  }

  String? _testMessage(TestEmailStatus? status) => switch (status) {
    TestEmailStatus.sent => 'Enviado. Revisa tu bandeja de entrada.',
    TestEmailStatus.queued =>
      'En cola: llegará en unos minutos. Revisa tu bandeja.',
    null => 'Comprueba que los avisos te llegan',
  };
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.switchKey,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final Key switchKey;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    // The group paints its own background; the tile needs a Material to draw its ink on.
    return Material(
      color: Colors.transparent,
      child: SwitchListTile(
        key: switchKey,
        title: Text(label),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
