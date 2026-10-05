import 'package:flutter/material.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/theme/app_palette.dart';
import '../application/budgets_state.dart';
import 'budget_widgets.dart';

class BudgetDashboardSection extends StatelessWidget {
  const BudgetDashboardSection({
    required this.state,
    required this.onRetry,
    required this.onManage,
    super.key,
  });

  final BudgetsState state;
  final VoidCallback onRetry;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final budgets = state.result?.budgets ?? const [];
    // Fast v1: riskiest first, so a budget close to its limit is never
    // buried below safe ones on the Dashboard preview.
    final ordered = [...budgets]
      ..sort((a, b) => b.progressPercent.compareTo(a.progressPercent));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Presupuestos',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
            ),
            TextButton(
              key: const Key('dashboard-manage-budgets'),
              onPressed: onManage,
              child: Text(budgets.isEmpty ? 'Crear' : 'Administrar'),
            ),
          ],
        ),
        if (state.loadStatus == BudgetsLoadStatus.loading) ...[
          const LinearProgressIndicator(
            semanticsLabel: 'Actualizando progreso de presupuestos',
          ),
          const SizedBox(height: 10),
        ],
        if (state.diagnostic case final diagnostic?) ...[
          ErrorDiagnosticPanel(diagnostic: diagnostic),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar presupuestos'),
          ),
        ] else if (state.result != null && budgets.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.line),
            ),
            child: const Column(
              children: [
                Icon(Icons.savings_outlined, size: 34),
                SizedBox(height: 8),
                Text(
                  'Aún no tienes presupuestos',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Crea una meta con el alcance y calendario que prefieras.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          for (final budget in ordered.take(3)) ...[
            BudgetProgressCard(budget: budget, compact: true),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}
