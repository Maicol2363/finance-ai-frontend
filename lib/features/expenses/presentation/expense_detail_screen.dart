import 'package:finance_ai/core/icons/finance_icon_catalog.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/management_page_scaffold.dart';
import '../../receipt_capture/data/receipt_photo_cache_repository.dart';
import '../../receipt_capture/presentation/widgets/receipt_photo_viewer_dialog.dart';
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
  File? _cachedReceiptPhoto;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (mounted) {
        final controller = ref.read(expensesControllerProvider.notifier);
        controller.clearMutationFeedback();
        controller.loadDetail(widget.expenseId);
        _checkCachedReceiptPhoto();
      }
    });
  }

  Future<void> _checkCachedReceiptPhoto() async {
    try {
      final repo = ref.read(receiptPhotoCacheRepositoryProvider);
      final photo = await repo.getCachedReceiptPhoto(widget.expenseId);
      if (mounted) {
        setState(() {
          _cachedReceiptPhoto = photo;
        });
      }
    } catch (_) {}
  }

  /// The backend stores no receipt image, so this local copy is the only one:
  /// a definitive delete must remove it as well. Best effort - a missing or
  /// locked file must not break the deletion flow.
  Future<void> _deleteCachedReceiptPhoto(int expenseId) async {
    try {
      await ref
          .read(receiptPhotoCacheRepositoryProvider)
          .deleteCachedReceiptPhoto(expenseId);
    } catch (_) {}
  }

  @override
  void didUpdateWidget(ExpenseDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expenseId != widget.expenseId) {
      ref
          .read(expensesControllerProvider.notifier)
          .loadDetail(widget.expenseId);
      _checkCachedReceiptPhoto();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(expensesControllerProvider);
    final controller = ref.read(expensesControllerProvider.notifier);
    final expense = state.detailExpenseId == widget.expenseId
        ? state.detailExpense
        : null;
    final isReceipt =
        expense != null &&
        (expense.captureSource == CaptureSource.ai || expense.items.length > 1);

    return ManagementPageScaffold(
      title: isReceipt ? 'Detalle del recibo' : 'Detalle del gasto',
      leading: HeaderIconButton(
        icon: FinanceIcons.arrowBack,
        tooltip: context.canPop() ? 'Volver' : 'Volver a gastos',
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        },
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (state.detailStatus == ExpenseDetailStatus.loading) ...[
            Semantics(
              liveRegion: true,
              label: isReceipt
                  ? 'Cargando el detalle del recibo'
                  : 'Cargando el detalle del gasto',
              child: const LinearProgressIndicator(),
            ),
            const SizedBox(height: 20),
          ],
          if (state.detailDiagnostic case final diagnostic?) ...[
            ErrorDiagnosticPanel(diagnostic: diagnostic),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => controller.loadDetail(widget.expenseId),
              icon: const Icon(FinanceIcons.refresh),
              label: const Text('Reintentar'),
            ),
            const SizedBox(height: 20),
          ],
          if (expense != null) _ExpenseDetails(expense: expense),
          if (expense != null && _cachedReceiptPhoto != null) ...[
            const SizedBox(height: 20),
            _AttachedReceiptCard(
              photoFile: _cachedReceiptPhoto!,
              onTap: () {
                ReceiptPhotoViewerDialog.show(
                  context,
                  imageFile: _cachedReceiptPhoto!,
                );
              },
            ),
          ],
          if (expense != null) ...[
            const SizedBox(height: 28),
            FilledButton.icon(
              key: const Key('expense-edit-button'),
              onPressed: state.isSaving || !expense.isEditable
                  ? null
                  : () async {
                      await context.push('/expenses/${widget.expenseId}/edit');
                      if (context.mounted) {
                        controller.loadDetail(widget.expenseId);
                      }
                    },
              icon: const Icon(FinanceIcons.editOutlined),
              label: Text(isReceipt ? 'Editar recibo' : 'Editar gasto'),
            ),
            if (!expense.isEditable)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  isReceipt
                      ? 'Solo los recibos confirmados se pueden editar o eliminar.'
                      : 'Solo los gastos confirmados se pueden editar o eliminar.',
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
              icon: const Icon(FinanceIcons.deleteOutline),
              label: Text(
                isReceipt
                    ? 'Eliminar recibo definitivamente'
                    : 'Eliminar gasto definitivamente',
              ),
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
              icon: const Icon(FinanceIcons.sync),
              label: const Text('Actualizar antes de reintentar'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDeletion(Expense expense) async {
    final isReceipt =
        expense.captureSource == CaptureSource.ai || expense.items.length > 1;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isReceipt
              ? '¿Eliminar este recibo definitivamente?'
              : '¿Eliminar este gasto definitivamente?',
        ),
        content: Text(
          isReceipt
              ? 'Esto elimina el recibo completo con todos sus productos y su movimiento de cuenta. No se puede deshacer.'
              : 'Esto elimina el gasto, su recibo y su movimiento de cuenta. No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('expense-confirm-delete-button'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
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
    await _deleteCachedReceiptPhoto(expense.id);
    if (!mounted) {
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isReceipt
              ? 'Recibo eliminado definitivamente.'
              : 'Gasto eliminado definitivamente.',
        ),
      ),
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
    final isReceipt =
        expense.captureSource == CaptureSource.ai || expense.items.length > 1;
    final displayAmount = expense.receiptTotal ?? expense.amount;
    final amount = displayAmount.formatWithCurrency(expense.currencyCode);
    final title = isReceipt && expense.store.isNotEmpty
        ? expense.store
        : expense.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Chip(
            avatar: Icon(
              expense.isEditable
                  ? FinanceIcons.checkCircleOutline
                  : FinanceIcons.lock,
            ),
            label: Text(expense.isEditable ? 'Editable' : 'No editable'),
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          label: displayAmount.isNegative
              ? 'Monto negativo $amount'
              : 'Monto $amount',
          child: ExcludeSemantics(
            child: _DetailRow(
              label: isReceipt ? 'Total compra' : 'Monto',
              value: amount,
            ),
          ),
        ),
        if (isReceipt &&
            expense.store.isNotEmpty &&
            expense.name != expense.store)
          _DetailRow(label: 'Descripción / Item', value: expense.name),
        if (isReceipt)
          _DetailRow(label: 'Comercio', value: expense.receiptName)
        else if (expense.receiptName.isNotEmpty &&
            expense.receiptName != expense.name)
          _DetailRow(label: 'Lugar / Comercio', value: expense.receiptName),
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
        if (!isReceipt) ...[
          _DetailRow(label: 'Cantidad', value: expense.quantity),
          if (expense.unitPrice != null)
            _DetailRow(
              label: 'Precio unitario',
              value: expense.unitPrice!.formatWithCurrency(
                expense.currencyCode,
              ),
            ),
        ],
        if (expense.note != null && expense.note!.isNotEmpty)
          _DetailRow(label: 'Nota', value: expense.note!),
        if (expense.receiptNote != null && expense.receiptNote!.isNotEmpty)
          _DetailRow(label: 'Nota del recibo', value: expense.receiptNote!),
        if (expense.description != null && expense.description!.isNotEmpty)
          _DetailRow(label: 'Descripción', value: expense.description!),

        // Receipt Products Breakdown Card (only for receipts)
        if (isReceipt && expense.items.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Productos del recibo',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${expense.items.length} ${expense.items.length == 1 ? 'producto' : 'productos'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  for (final item in expense.items) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (item.quantity != '1.000' &&
                                    item.quantity != '1')
                                  Text(
                                    'Cant: ${item.quantity}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).hintColor,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            item.amount.formatWithCurrency(
                              expense.currencyCode,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
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

class _AttachedReceiptCard extends StatelessWidget {
  const _AttachedReceiptCard({required this.photoFile, required this.onTap});

  final File photoFile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  FinanceIcons.receiptLongOutlined,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Comprobante adjunto',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Foto física guardada localmente en el dispositivo',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.file(
                      photoFile,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Container(
                      height: 160,
                      width: double.infinity,
                      color: Colors.black.withValues(alpha: 0.25),
                      child: const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              FinanceIcons.zoomIn,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Tocar para ampliar',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onTap,
                icon: const Icon(FinanceIcons.fullscreen, size: 18),
                label: const Text('Ver comprobante completo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
