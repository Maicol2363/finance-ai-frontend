import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/theme_toggle_button.dart';
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Presupuestos',
              subtitle: 'Metas flexibles y personalizadas',
              leading: HeaderIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Volver al dashboard',
                onPressed: () => context.go('/dashboard'),
              ),
              actions: const [ThemeToggleButton()],
            ),
            if (state.loadStatus == BudgetsLoadStatus.loading)
              const LinearProgressIndicator(
                semanticsLabel: 'Cargando presupuestos',
              ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: RefreshIndicator(
                    onRefresh: controller.load,
                    child: ListView(
                      key: const Key('budgets-list'),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      children: [
                        FilledButton.icon(
                          key: const Key('budgets-add-button'),
                          onPressed: state.result == null || state.isSaving
                              ? null
                              : () => context.go('/budgets/new'),
                          icon: const Icon(Icons.add),
                          label: const Text('Crear presupuesto'),
                        ),
                        const SizedBox(height: 12),
                        if (state.diagnostic case final diagnostic?) ...[
                          ErrorDiagnosticPanel(diagnostic: diagnostic),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: controller.load,
                            icon: const Icon(Icons.refresh),
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
                          const Padding(
                            padding: EdgeInsets.only(top: 64),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (budgets?.isEmpty == true)
                          const _EmptyBudgets()
                        else
                          for (final budget in budgets ?? const []) ...[
                            BudgetProgressCard(
                              budget: budget,
                              onTap: state.isSaving
                                  ? null
                                  : () => context.go(
                                      '/budgets/${budget.id}/edit',
                                    ),
                            ),
                            const SizedBox(height: 12),
                          ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBudgets extends StatelessWidget {
  const _EmptyBudgets();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(28, 56, 28, 12),
    child: Column(
      children: [
        Icon(Icons.savings_outlined, size: 58),
        SizedBox(height: 16),
        Text(
          'Crea tu primer presupuesto',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          'Elige qué gastos incluir, personaliza el calendario, el monto y la moneda. El progreso se calcula desde tus gastos confirmados.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
