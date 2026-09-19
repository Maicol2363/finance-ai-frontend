import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../application/expenses_controller.dart';
import '../application/expenses_state.dart';
import '../domain/expense_models.dart';

class ExpenseDetailScreen extends ConsumerStatefulWidget {
  const ExpenseDetailScreen({required this.expenseId, super.key});

  final int expenseId;

  @override
  ConsumerState<ExpenseDetailScreen> createState() =>
      _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends ConsumerState<ExpenseDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (mounted) {
        final controller = ref.read(expensesControllerProvider.notifier);
        controller.clearMutationFeedback();
        controller.loadDetail(widget.expenseId);
      }
    });
  }

  @override
  void didUpdateWidget(ExpenseDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expenseId != widget.expenseId) {
      ref
          .read(expensesControllerProvider.notifier)
          .loadDetail(widget.expenseId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(expensesControllerProvider);
    final controller = ref.read(expensesControllerProvider.notifier);
    final expense = state.detailExpenseId == widget.expenseId
        ? state.detailExpense
        : null;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver a gastos',
          onPressed: () => context.go('/expenses'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Detalle del gasto'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              children: [
                if (state.detailStatus == ExpenseDetailStatus.loading) ...[
                  Semantics(
                    liveRegion: true,
                    label: 'Cargando el detalle del gasto',
                    child: const LinearProgressIndicator(),
                  ),
                  const SizedBox(height: 20),
                ],
                if (state.detailDiagnostic case final diagnostic?) ...[
                  ErrorDiagnosticPanel(diagnostic: diagnostic),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => controller.loadDetail(widget.expenseId),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                  const SizedBox(height: 20),
                ],
                if (expense != null) _ExpenseDetails(expense: expense),
                if (expense != null) ...[
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    key: const Key('expense-edit-button'),
                    onPressed: state.isSaving || !expense.isEditable
                        ? null
                        : () =>
                              context.go('/expenses/${widget.expenseId}/edit'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar gasto'),
                  ),
                  if (!expense.isEditable)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Solo los gastos confirmados se pueden editar o eliminar.',
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('expense-delete-button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: state.isSaving || !expense.isEditable
                        ? null
                        : () => _confirmDeletion(expense),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar gasto definitivamente'),
                  ),
                ],
                if (state.isSaving) ...[
                  const SizedBox(height: 20),
                  Semantics(
                    liveRegion: true,
                    label: 'Guardando los cambios del gasto',
                    child: const LinearProgressIndicator(),
                  ),
                ],
                if (state.mutationDiagnostic case final diagnostic?) ...[
                  const SizedBox(height: 20),
                  ErrorDiagnosticPanel(diagnostic: diagnostic),
                ],
                if (state.requiresMutationReview) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: controller.resolveUncertainMutation,
                    icon: const Icon(Icons.sync),
                    label: const Text('Actualizar antes de reintentar'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeletion(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar este gasto definitivamente?'),
        content: const Text(
          'Esto elimina el gasto, su recibo y su movimiento de cuenta. No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('expense-confirm-delete-button'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar definitivamente'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final outcome = await ref
        .read(expensesControllerProvider.notifier)
        .deleteExpense(expense.id);
    if (!mounted || outcome != ExpenseMutationOutcome.success) {
      return;
    }
    context.go('/expenses');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gasto eliminado definitivamente.')),
    );
  }
}

String _statusLabel(ExpenseStatus status) => switch (status) {
  ExpenseStatus.pending => 'Pendiente',
  ExpenseStatus.confirmed => 'Confirmado',
  ExpenseStatus.voided => 'Anulado',
};

class _ExpenseDetails extends StatelessWidget {
  const _ExpenseDetails({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final amount = expense.amount.formatWithCurrency(expense.currencyCode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(expense.name, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Chip(
            avatar: Icon(
              expense.isEditable ? Icons.check_circle_outline : Icons.lock,
            ),
            label: Text(expense.isEditable ? 'Editable' : 'No editable'),
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          label: expense.amount.isNegative
              ? 'Monto negativo $amount'
              : 'Monto $amount',
          child: ExcludeSemantics(
            child: _DetailRow(label: 'Monto', value: amount),
          ),
        ),
        _DetailRow(label: 'Comercio', value: expense.receiptName),
        _DetailRow(label: 'Tienda', value: expense.store),
        _DetailRow(
          label: 'Categoría',
          value: expense.category?.name ?? 'Sin categoría',
        ),
        _DetailRow(
          label: 'Cuenta',
          value:
              '${expense.accountName}${expense.accountIsActive ? '' : ' · Inactiva'}',
        ),
        _DetailRow(
          label: 'Moneda',
          value: '${expense.currency.code} · ${expense.currency.name}',
        ),
        _DetailRow(label: 'Estado', value: _statusLabel(expense.status)),
        _DetailRow(label: 'Cantidad', value: expense.quantity),
        if (expense.unitPrice != null)
          _DetailRow(
            label: 'Precio unitario',
            value: expense.unitPrice!.formatWithCurrency(expense.currencyCode),
          ),
        if (expense.note != null)
          _DetailRow(label: 'Nota', value: expense.note!),
        if (expense.receiptNote != null)
          _DetailRow(label: 'Nota del recibo', value: expense.receiptNote!),
        if (expense.description != null)
          _DetailRow(label: 'Descripción', value: expense.description!),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
