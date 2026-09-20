import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../application/expenses_controller.dart';
import '../application/expenses_state.dart';
import '../domain/expense_models.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      final state = ref.read(expensesControllerProvider);
      if (state.listStatus == ExpensesLoadStatus.initial) {
        ref.read(expensesControllerProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(expensesControllerProvider);
    final controller = ref.read(expensesControllerProvider.notifier);
    final result = state.result;
    final isBusy =
        state.listStatus == ExpensesLoadStatus.loading ||
        state.listStatus == ExpensesLoadStatus.loadingMore;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver al inicio',
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Gastos'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('expenses-create-fab'),
        onPressed: () => context.go('/expenses/new'),
        icon: const Icon(Icons.add),
        label: const Text('Registrar gasto'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: RefreshIndicator(
              onRefresh: controller.load,
              child: ListView(
                key: const Key('expenses-list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  if (isBusy) ...[
                    Semantics(
                      liveRegion: true,
                      label: 'Cargando gastos',
                      child: const LinearProgressIndicator(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (state.listDiagnostic case final diagnostic?) ...[
                    ErrorDiagnosticPanel(diagnostic: diagnostic),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: controller.load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (result == null &&
                      state.listStatus != ExpensesLoadStatus.loading &&
                      state.listDiagnostic == null)
                    const _ExpensesLoadingPlaceholder(),
                  if (result != null && result.items.isEmpty)
                    const _ExpensesEmptyState(),
                  if (result != null)
                    for (final expense in result.items) ...[
                      _ExpenseCard(expense: expense),
                      const SizedBox(height: 12),
                    ],
                  if (result != null && result.hasNext) ...[
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      key: const Key('expenses-load-more-button'),
                      onPressed: isBusy ? null : controller.loadMore,
                      icon: const Icon(Icons.expand_more),
                      label: const Text('Cargar más gastos'),
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

class _ExpensesLoadingPlaceholder extends StatelessWidget {
  const _ExpensesLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ExpensesEmptyState extends StatelessWidget {
  const _ExpensesEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Sin gastos todavía',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Tus gastos aparecerán aquí cuando se registren. Desliza hacia abajo para actualizar.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final amount = expense.amount.formatWithCurrency(expense.currencyCode);
    final meaning = expense.amount.isNegative
        ? 'Monto negativo $amount'
        : 'Monto $amount';
    final statusLabel = expense.isEditable ? 'editable' : 'no editable';
    return Semantics(
      container: true,
      button: true,
      label: '${expense.name}, $meaning, ${expense.store}, $statusLabel',
      child: ExcludeSemantics(
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('expense-card-${expense.id}'),
            onTap: () => context.go('/expenses/${expense.id}'),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    child: Icon(
                      expense.isEditable
                          ? Icons.receipt_outlined
                          : Icons.lock_outline,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${expense.store} · ${expense.accountName}'
                          '${expense.category == null ? '' : ' · ${expense.category!.name}'}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    amount,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: expense.amount.isNegative
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
