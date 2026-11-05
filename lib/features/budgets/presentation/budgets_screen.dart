import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/management_page_scaffold.dart';
import '../application/budgets_controller.dart';
import '../application/budgets_state.dart';
import 'budget_widgets.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (mounted) ref.read(budgetsControllerProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(budgetsControllerProvider);
    final controller = ref.read(budgetsControllerProvider.notifier);
    final budgets = state.result?.budgets;
    return ManagementPageScaffold(
      title: 'Presupuestos',
      subtitle: 'Metas flexibles y personalizadas',
      leading: HeaderIconButton(
        icon: FinanceIcons.arrowBack,
        tooltip: 'Volver',
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/settings'),
      ),
      body: Column(
        children: [
          if (state.loadStatus == BudgetsLoadStatus.loading)
            const LinearProgressIndicator(
              semanticsLabel: 'Cargando presupuestos',
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.load,
              child: ListView(
                key: const Key('budgets-list'),
                padding: EdgeInsets.zero,
                children: [
                  FilledButton.icon(
                    key: const Key('budgets-add-button'),
                    onPressed: state.result == null || state.isSaving
                        ? null
                        : () => context.push('/budgets/new'),
                    icon: const Icon(FinanceIcons.add),
                    label: const Text('Crear presupuesto'),
                  ),
                  const SizedBox(height: 12),
                  if (state.diagnostic case final diagnostic?) ...[
                    ErrorDiagnosticPanel(diagnostic: diagnostic),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: controller.load,
                      icon: const Icon(FinanceIcons.refresh),
                      label: const Text('Reintentar'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (state.mutationDiagnostic
                      case final mutationDiagnostic?) ...[
                    ErrorDiagnosticPanel(diagnostic: mutationDiagnostic),
                    const SizedBox(height: 12),
                  ],
                  if (budgets == null &&
                      state.loadStatus == BudgetsLoadStatus.loading)
                    Padding(
                      padding: const EdgeInsets.only(top: 64),
                      child: Semantics(
                        label: 'Cargando…',
                        liveRegion: true,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else if (budgets?.isEmpty == true)
                    const _EmptyBudgets()
                  else
                    for (final budget in budgets ?? const []) ...[
                      BudgetProgressCard(
                        budget: budget,
                        onTap: state.isSaving
                            ? null
                            : () => context.push('/budgets/${budget.id}/edit'),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBudgets extends StatelessWidget {
  const _EmptyBudgets();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 56, 28, 12),
    child: Column(
      children: [
        Icon(FinanceIconCatalog.dataFor(FinanceIconKey.budget), size: 58),
        const SizedBox(height: 16),
        Text(
          'Crea tu primer presupuesto',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Elige qué gastos incluir, personaliza el calendario, el monto y la moneda. El progreso se calcula desde tus gastos confirmados.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
