import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../../core/formatters/money_formatter.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../accounts/domain/account_models.dart';
import '../../application/text_capture_controller.dart';
import '../../application/text_capture_state.dart';
import '../../domain/text_capture_models.dart';
import 'chat_bubbles.dart';

/// The one short question asked when the text is genuinely ambiguous.
///
/// Choices are tapped (no typing, no new AI call); the other answers
/// (an amount) are typed in the composer below.
class ClarificationCard extends ConsumerWidget {
  const ClarificationCard({
    super.key,
    required this.entry,
    required this.isLatest,
  });

  final ProposalEntry entry;

  /// Only the newest question can be answered; older ones are read-only history.
  final bool isLatest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final clarification = entry.proposal.clarification;
    if (clarification == null) {
      return const SizedBox.shrink();
    }
    final controller = ref.read(textCaptureControllerProvider.notifier);
    final busy = ref.watch(
      textCaptureControllerProvider.select((state) => state.isBusy),
    );
    final understood = _understood(entry.proposal);
    return AssistantRow(
      child: Semantics(
        container: true,
        liveRegion: true,
        label: 'Pregunta del asistente: ${clarification.question}',
        child: Container(
          key: const Key('clarification-card'),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: palette.card,
            border: Border.all(color: palette.line),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (understood != null) ...[
                Text(
                  understood,
                  style: TextStyle(fontSize: 11.5, color: palette.muted),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                clarification.question,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  color: palette.text,
                ),
              ),
              const SizedBox(height: 10),
              if (clarification.isChoice)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in clarification.options)
                      _OptionPill(
                        key: Key('clarification-option-${option.value}'),
                        option: option,
                        enabled: isLatest && !busy,
                        onTap: () => controller.choose(entry, option),
                      ),
                  ],
                )
              else if (isLatest)
                Text(
                  'Respóndeme escribiendo en el cuadro de abajo.',
                  style: TextStyle(fontSize: 12.5, color: palette.muted),
                ),
              if (isLatest) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('clarification-discard'),
                    style: TextButton.styleFrom(
                      foregroundColor: palette.discard,
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: busy ? null : () => controller.discard(entry),
                    child: const Text('Descartar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// "Entendí: Gasto · $ 8.000" so the question has context.
  static String? _understood(TextProposal proposal) {
    final parts = <String>[
      if (proposal.intent != null) proposal.intent!.label,
      if (proposal.amount != null)
        () {
          try {
            return MoneyFormatter.formatMinorUnits(
              MoneyAmount.parseApi(proposal.amount!).minorUnits,
            );
          } on FormatException {
            return proposal.amount!;
          }
        }(),
    ];
    return parts.isEmpty ? null : 'Entendí: ${parts.join(' · ')}';
  }
}

class _OptionPill extends StatelessWidget {
  const _OptionPill({
    super.key,
    required this.option,
    required this.enabled,
    required this.onTap,
  });

  final ClarificationOption option;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = enabled ? palette.primary : palette.muted;
    return Semantics(
      button: true,
      enabled: enabled,
      label: option.detail == null
          ? option.label
          : '${option.label}, ${option.detail}',
      excludeSemantics: true,
      child: Material(
        color: enabled ? palette.primarySoft : palette.soft,
        shape: StadiumBorder(side: BorderSide(color: palette.line)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  if (option.detail != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      option.detail!,
                      style: TextStyle(fontSize: 11, color: palette.muted),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The operation was recorded (green tint, like a confirmation).
class ConfirmedCard extends StatelessWidget {
  const ConfirmedCard({super.key, required this.entry});

  final ConfirmedEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final confirmation = entry.confirmation;
    final noun = switch (confirmation.intent) {
      CaptureIntent.expense => 'Gasto registrado',
      CaptureIntent.income => 'Ingreso registrado',
      CaptureIntent.transfer => 'Transferencia registrada',
    };
    String amount;
    try {
      amount = MoneyFormatter.formatMinorUnits(
        MoneyAmount.parseApi(confirmation.amount).minorUnits,
      );
    } on FormatException {
      amount = confirmation.amount;
    }
    final detail = [
      '$amount ${confirmation.currencyCode}',
      if (confirmation.intent == CaptureIntent.transfer &&
          confirmation.destinationAccountName != null)
        '${confirmation.accountName} → ${confirmation.destinationAccountName}'
      else
        confirmation.accountName,
      if (confirmation.description != null &&
          confirmation.intent != CaptureIntent.transfer)
        confirmation.description!,
    ].join(' · ');
    final route = switch (confirmation.intent) {
      CaptureIntent.expense => '/expenses/${confirmation.recordId}',
      CaptureIntent.income => '/incomes/${confirmation.recordId}',
      CaptureIntent.transfer => null,
    };
    return AssistantRow(
      child: Semantics(
        container: true,
        liveRegion: true,
        label: '$noun. $detail',
        child: Container(
          key: const Key('confirmed-card'),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          decoration: BoxDecoration(
            color: palette.incomeSoft,
            border: Border.all(color: palette.income.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    FinanceIcons.checkCircle,
                    size: 18,
                    color: palette.income,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    noun,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: palette.income,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(detail, style: TextStyle(fontSize: 13, color: palette.text)),
              if (route != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('confirmed-view'),
                    style: TextButton.styleFrom(
                      foregroundColor: palette.income,
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: () => context.push(route),
                    child: const Text('Ver detalle'),
                  ),
                )
              else
                const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// A turn failed: copyable report, retry and the manual form as the way out.
class FailureCard extends ConsumerWidget {
  const FailureCard({super.key, required this.entry});

  final FailureEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final controller = ref.read(textCaptureControllerProvider.notifier);
    final busy = ref.watch(
      textCaptureControllerProvider.select((state) => state.isBusy),
    );
    return AssistantRow(
      child: Column(
        key: const Key('chat-failure'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ErrorDiagnosticPanel(diagnostic: entry.diagnostic),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (entry.canRetry)
                FilledButton.icon(
                  key: const Key('chat-retry'),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: busy ? null : controller.retry,
                  icon: const Icon(FinanceIcons.refresh, size: 18),
                  label: const Text('Reintentar'),
                ),
              OutlinedButton.icon(
                key: const Key('chat-manual'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.primary,
                  side: BorderSide(color: palette.primary),
                  minimumSize: const Size(48, 48),
                ),
                onPressed: () => context.push('/expenses/new'),
                icon: const Icon(FinanceIcons.editOutlined, size: 18),
                label: const Text('Usar formulario manual'),
              ),
              TextButton(
                key: const Key('chat-dismiss'),
                style: TextButton.styleFrom(
                  foregroundColor: palette.muted,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: controller.dismissFailure,
                child: const Text('Descartar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
