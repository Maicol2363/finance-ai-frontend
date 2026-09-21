import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/formatters/money_formatter.dart';
import '../application/expenses_controller.dart';
import '../application/expenses_state.dart';
import '../domain/expense_models.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({required this.expenseId, super.key});

  final int expenseId;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _receiptNameController = TextEditingController();
  final _receiptNoteController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _accountIdController = TextEditingController();
  final _categoryIdController = TextEditingController();
  final _nameFocus = FocusNode();
  final _amountFocus = FocusNode();
  DateTime? _occurredAt;
  bool _clearNote = false;
  bool _clearCategory = false;
  bool _initialized = false;
  bool _initializationScheduled = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      final controller = ref.read(expensesControllerProvider.notifier);
      controller.clearMutationFeedback();
      controller.loadDetail(widget.expenseId);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _receiptNameController.dispose();
    _receiptNoteController.dispose();
    _descriptionController.dispose();
    _accountIdController.dispose();
    _categoryIdController.dispose();
    _nameFocus.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(expensesControllerProvider);
    final controller = ref.read(expensesControllerProvider.notifier);
    final editExpense = state.detailExpenseId == widget.expenseId
        ? state.detailExpense
        : null;
    _scheduleInitialization(editExpense);

    final waitingForEdit =
        state.detailStatus == ExpenseDetailStatus.initial ||
        state.detailStatus == ExpenseDetailStatus.loading;
    final canShowForm = _initialized && editExpense != null;

    return PopScope(
      canPop: !state.isSaving,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Volver al detalle del gasto',
            onPressed: state.isSaving ? null : _goBack,
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Editar gasto'),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                children: [
                  if (waitingForEdit) ...[
                    Semantics(
                      liveRegion: true,
                      label: 'Cargando el formulario del gasto',
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
                      label: const Text('Reintentar la carga del gasto'),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (editExpense != null && canShowForm)
                    _buildForm(context, state, editExpense, controller),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    ExpensesState state,
    Expense editExpense,
    ExpensesController controller,
  ) {
    final formEnabled = !state.isSaving && !state.requiresMutationReview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Corrige los datos de este gasto confirmado. Borrar la nota o la categoría las elimina.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        if (state.mutationDiagnostic case final diagnostic?) ...[
          ErrorDiagnosticPanel(diagnostic: diagnostic),
          const SizedBox(height: 20),
        ],
        TextField(
          key: const Key('expense-name-field'),
          controller: _nameController,
          focusNode: _nameFocus,
          enabled: formEnabled,
          textInputAction: TextInputAction.next,
          maxLength: 200,
          decoration: InputDecoration(
            labelText: 'Nombre del gasto',
            errorText: _firstError(state, 'name'),
          ),
          onChanged: (_) => controller.clearFieldError('name'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('expense-amount-field'),
          controller: _amountController,
          focusNode: _amountFocus,
          enabled: formEnabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [MoneyInputFormatter(allowNegative: false)],
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Monto (${editExpense.currencyCode})',
            helperText: 'Monto positivo con hasta dos decimales.',
            errorText: _firstError(state, 'amount'),
          ),
          onChanged: (_) => controller.clearFieldError('amount'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('expense-note-field'),
          controller: _noteController,
          enabled: formEnabled && !_clearNote,
          textInputAction: TextInputAction.next,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Nota',
            errorText: _firstError(state, 'note'),
          ),
          onChanged: (_) => controller.clearFieldError('note'),
        ),
        CheckboxListTile.adaptive(
          key: const Key('expense-clear-note'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Quitar la nota'),
          value: _clearNote,
          onChanged: formEnabled
              ? (value) => setState(() => _clearNote = value ?? false)
              : null,
        ),
        TextField(
          key: const Key('expense-receipt-name-field'),
          controller: _receiptNameController,
          enabled: formEnabled,
          textInputAction: TextInputAction.next,
          maxLength: 150,
          decoration: InputDecoration(
            labelText: 'Comercio',
            errorText: _firstError(state, 'receipt_name'),
          ),
          onChanged: (_) => controller.clearFieldError('receipt_name'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('expense-receipt-note-field'),
          controller: _receiptNoteController,
          enabled: formEnabled,
          textInputAction: TextInputAction.next,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Nota del recibo'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('expense-description-field'),
          controller: _descriptionController,
          enabled: formEnabled,
          textInputAction: TextInputAction.next,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Descripción'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('expense-account-id-field'),
          controller: _accountIdController,
          enabled: formEnabled,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'ID de cuenta',
            helperText:
                'Cuenta actual: ${editExpense.accountName}. Se requiere la misma moneda.',
            errorText: _firstError(state, 'account_id'),
          ),
          onChanged: (_) => controller.clearFieldError('account_id'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('expense-category-id-field'),
          controller: _categoryIdController,
          enabled: formEnabled && !_clearCategory,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'ID de categoría',
            helperText:
                'Actual: ${editExpense.category?.name ?? 'Sin categoría'}.',
            errorText: _firstError(state, 'category_id'),
          ),
          onChanged: (_) => controller.clearFieldError('category_id'),
        ),
        CheckboxListTile.adaptive(
          key: const Key('expense-clear-category'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Quitar la categoría'),
          value: _clearCategory,
          onChanged: formEnabled
              ? (value) => setState(() => _clearCategory = value ?? false)
              : null,
        ),
        const Text('Fecha'),
        const SizedBox(height: 4),
        Text(
          _occurredAt == null
              ? 'Sin cambios'
              : '${_occurredAt!.toUtc().year.toString().padLeft(4, '0')}-'
                    '${_occurredAt!.toUtc().month.toString().padLeft(2, '0')}-'
                    '${_occurredAt!.toUtc().day.toString().padLeft(2, '0')}',
          key: const Key('expense-date-value'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('expense-date-button'),
          onPressed: formEnabled ? () => _pickDate(editExpense) : null,
          icon: const Icon(Icons.calendar_today_outlined),
          label: const Text('Cambiar fecha'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('expense-save-button'),
          onPressed: formEnabled ? _submit : null,
          child: state.isSaving
              ? Semantics(
                  liveRegion: true,
                  label: 'Guardando el gasto',
                  child: const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              : const Text('Guardar cambios'),
        ),
        if (state.requiresMutationReview) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: controller.resolveUncertainMutation,
            icon: const Icon(Icons.sync),
            label: const Text('Actualizar los gastos antes de reintentar'),
          ),
        ],
      ],
    );
  }

  void _scheduleInitialization(Expense? editExpense) {
    if (_initialized || _initializationScheduled || editExpense == null) {
      return;
    }
    _initializationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _nameController.text = editExpense.name;
      _amountController.text = MoneyFormatter.formatInputAmount(
        editExpense.amount.minorUnits,
      );
      _noteController.text = editExpense.note ?? '';
      _receiptNameController.text = editExpense.receiptName;
      _receiptNoteController.text = editExpense.receiptNote ?? '';
      _descriptionController.text = editExpense.description ?? '';
      _accountIdController.text = '${editExpense.accountId}';
      _categoryIdController.text = editExpense.category == null
          ? ''
          : '${editExpense.category!.id}';
      _occurredAt = null;
      setState(() {
        _initialized = true;
        _initializationScheduled = false;
      });
    });
  }

  Future<void> _pickDate(Expense editExpense) async {
    final initial = _occurredAt ?? editExpense.occurredAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.toUtc(),
      firstDate: DateTime.utc(2000),
      lastDate: DateTime.now().toUtc(),
    );
    if (picked != null && mounted) {
      setState(
        () => _occurredAt = DateTime.utc(
          picked.year,
          picked.month,
          picked.day,
          12,
        ),
      );
    }
  }

  String? _firstError(ExpensesState state, String field) {
    final errors = state.fieldErrors[field];
    return errors == null || errors.isEmpty ? null : errors.first;
  }

  Future<void> _submit() async {
    final controller = ref.read(expensesControllerProvider.notifier);
    final outcome = await controller.update(
      expenseId: widget.expenseId,
      name: _nameController.text,
      amountInput: MoneyFormatter.clean(_amountController.text),
      note: _clearNote ? null : _asOptionalText(_noteController.text),
      clearNote: _clearNote,
      receiptName: _receiptNameController.text,
      receiptNote: _asOptionalText(_receiptNoteController.text),
      categoryId: _asOptionalId(_categoryIdController.text),
      clearCategory: _clearCategory,
      accountId: _asOptionalId(_accountIdController.text),
      occurredAt: _occurredAt,
      description: _asOptionalText(_descriptionController.text),
    );
    if (!mounted) {
      return;
    }
    if (outcome == ExpenseMutationOutcome.success) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/expenses/${widget.expenseId}');
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Gasto actualizado.')));
      return;
    }
    if (outcome == ExpenseMutationOutcome.invalid ||
        outcome == ExpenseMutationOutcome.failure) {
      _focusFirstError(ref.read(expensesControllerProvider));
    }
  }

  String? _asOptionalText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : value;
  }

  int? _asOptionalId(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return int.tryParse(trimmed);
  }

  void _focusFirstError(ExpensesState state) {
    if (state.fieldErrors.containsKey('name')) {
      _nameFocus.requestFocus();
    } else if (state.fieldErrors.containsKey('amount')) {
      _amountFocus.requestFocus();
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/expenses/${widget.expenseId}');
    }
  }
}
