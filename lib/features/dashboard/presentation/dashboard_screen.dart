import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../accounts/application/accounts_controller.dart';
import '../../accounts/application/accounts_state.dart';
import '../../expenses/application/expenses_controller.dart';
import '../../expenses/application/expenses_state.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) return;
      if (ref.read(expensesControllerProvider).listStatus ==
          ExpensesLoadStatus.initial) {
        ref.read(expensesControllerProvider.notifier).load();
      }
      if (ref.read(accountsControllerProvider).listStatus ==
          AccountsLoadStatus.initial) {
        ref.read(accountsControllerProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final expensesState = ref.watch(expensesControllerProvider);
    final expenses = expensesState.result?.items ?? const [];

    var totalExpenses = 0.0;
    for (final exp in expenses) {
      totalExpenses += double.tryParse(exp.amount.toApiString()) ?? 0.0;
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(
              title: 'Dashboard',
              subtitle: 'Resumen y tendencias',
              actions: [ThemeToggleButton()],
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      // Balance del mes card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: palette.card,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: palette.line),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x060F172A),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Balance del mes',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: palette.muted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '- \$ ${totalExpenses.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} COP',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: palette.text,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: palette.soft,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: palette.income,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Ingresos',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: palette.muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '+ \$ 0 COP',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: palette.income,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: palette.soft,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: palette.discard,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Gastos',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: palette.muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '- \$ ${totalExpenses.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} COP',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: palette.discard,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Categorías de gasto
                      Text(
                        'Gastos por categoría',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (expenses.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: palette.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: palette.line),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                const Text('📊', style: TextStyle(fontSize: 36)),
                                const SizedBox(height: 10),
                                Text(
                                  'Sin datos suficientes',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: palette.text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Registra gastos para ver gráficos y tendencias.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: palette.muted,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: palette.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: palette.line),
                          ),
                          child: Column(
                            children: [
                              for (final exp in expenses.take(5)) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: palette.primarySoft,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            exp.category?.name.isNotEmpty ==
                                                    true
                                                ? '🏷️'
                                                : '🛒',
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              exp.category?.name ??
                                                  'Sin categoría',
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w600,
                                                color: palette.text,
                                              ),
                                            ),
                                            Text(
                                              exp.store,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: palette.muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        exp.amount.formatWithCurrency(
                                          exp.currencyCode,
                                        ),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: palette.text,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (exp != expenses.take(5).last)
                                  Divider(height: 1, color: palette.line),
                              ],
                            ],
                          ),
                        ),
                    ],
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
