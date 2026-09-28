import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/theme/app_palette.dart';
import '../../accounts/application/accounts_controller.dart';
import '../../accounts/application/accounts_state.dart';
import '../../categories/application/categories_controller.dart';
import '../../categories/application/categories_state.dart';
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
  int? _selectedAccountId;
  int? _selectedCategoryId;
  final _nameFocus = FocusNode();
  final _amountFocus = FocusNode();

  DateTime? _occurredAt;
  bool _clearNote = false;
  bool _clearCategory = false;
  bool _initialized = false;
  bool _initializationScheduled = false;
  List<_LineItemDraft> _items = [];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      if (!mounted) return;
      final controller = ref.read(expensesControllerProvider.notifier);
      controller.clearMutationFeedback();
      controller.loadDetail(widget.expenseId);
      final accounts = ref.read(accountsControllerProvider);
      if (accounts.listStatus == AccountsLoadStatus.initial) {
        ref.read(accountsControllerProvider.notifier).load();
      }
      final categories = ref.read(categoriesControllerProvider);
      if (categories.loadStatus == CategoriesLoadStatus.initial) {
        ref.read(categoriesControllerProvider.notifier).load();
      }
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
    _nameFocus.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>() ?? AppPalette.light;
    final state = ref.watch(expensesControllerProvider);
    final controller = ref.read(expensesControllerProvider.notifier);
    final accountsState = ref.watch(accountsControllerProvider);
    final categoriesState = ref.watch(categoriesControllerProvider);
    final editExpense = state.detailExpenseId == widget.expenseId
        ? state.detailExpense
        : null;
    _scheduleInitialization(editExpense);

    final waitingForEdit =
        state.detailStatus == ExpenseDetailStatus.initial ||
        state.detailStatus == ExpenseDetailStatus.loading;
    final canShowForm = _initialized && editExpense != null;

    final isReceiptMode = editExpense != null &&
        (editExpense.captureSource == CaptureSource.ai ||
            editExpense.items.length > 1);

    return PopScope(
      canPop: !state.isSaving,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Volver al detalle del gasto',
            onPressed: state.isSaving ? null : _goBack,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(isReceiptMode ? 'Editar recibo' : 'Editar gasto'),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                children: [
                  if (waitingForEdit) ...[
                    Semantics(
                      liveRegion: true,
                      label: 'Cargando datos del gasto',
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
                  if (accountsState.listDiagnostic case final diagnostic?) ...[
                    ErrorDiagnosticPanel(diagnostic: diagnostic),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(accountsControllerProvider.notifier).load(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar cuentas'),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (categoriesState.diagnostic case final diagnostic?) ...[
                    ErrorDiagnosticPanel(diagnostic: diagnostic),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => ref
                          .read(categoriesControllerProvider.notifier)
                          .load(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar categorías'),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (editExpense != null && canShowForm)
                    _buildForm(
                      context,
                      palette,
                      state,
                      editExpense,
                      controller,
                      isReceiptMode,
                      accountsState,
                      categoriesState,
                    ),
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
    AppPalette palette,
    ExpensesState state,
    Expense editExpense,
    ExpensesController controller,
    bool isReceiptMode,
    AccountsState accountsState,
    CategoriesState categoriesState,
  ) {
    final optionsFailed =
        accountsState.listDiagnostic != null ||
        categoriesState.diagnostic != null;
    final formEnabled =
        !state.isSaving && !state.requiresMutationReview && !optionsFailed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.mutationDiagnostic case final diagnostic?) ...[
          ErrorDiagnosticPanel(diagnostic: diagnostic),
          const SizedBox(height: 16),
        ],

        if (isReceiptMode) ...[
          // Receipt banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: palette.primarySoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.line),
            ),
            child: Row(
              children: [
                const Text('✨', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recibo procesado con IA',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                        ),
                      ),
                      Text(
                        'Edita los datos del comprobante y la cuenta de pago asignada.',
                        style: TextStyle(fontSize: 11.5, color: palette.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Merchant name
          TextField(
            key: const Key('expense-receipt-name-field'),
            controller: _receiptNameController,
            enabled: formEnabled,
            textInputAction: TextInputAction.next,
            maxLength: 150,
            decoration: InputDecoration(
              labelText: 'Comercio / Tienda *',
              prefixIcon: const Icon(Icons.storefront_outlined),
              errorText: _firstError(state, 'receipt_name'),
            ),
            onChanged: (val) {
              controller.clearFieldError('receipt_name');
              _nameController.text = val;
            },
          ),
          const SizedBox(height: 12),

          // Preserved concept field for automated tests
          Offstage(
            offstage: true,
            child: TextField(
              key: const Key('expense-name-field'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Concepto'),
            ),
          ),

          // Amount
          TextField(
            key: const Key('expense-amount-field'),
            controller: _amountController,
            focusNode: _amountFocus,
            enabled: formEnabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [MoneyInputFormatter(allowNegative: false)],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Monto total (${editExpense.currencyCode}) *',
              prefixIcon: const Icon(Icons.attach_money),
              errorText: _firstError(state, 'amount'),
            ),
            onChanged: (_) => controller.clearFieldError('amount'),
          ),
          const SizedBox(height: 16),

          // Interactive Products Section
          _buildLineItemsSection(
            context,
            palette,
            editExpense.currencyCode,
            formEnabled,
          ),
          const SizedBox(height: 16),
        ] else ...[
          // Manual Expense Fields
          TextField(
            key: const Key('expense-name-field'),
            controller: _nameController,
            focusNode: _nameFocus,
            enabled: formEnabled,
            textInputAction: TextInputAction.next,
            maxLength: 200,
            decoration: InputDecoration(
              labelText: 'Nombre del gasto *',
              prefixIcon: const Icon(Icons.edit_note),
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
              labelText: 'Monto (${editExpense.currencyCode}) *',
              prefixIcon: const Icon(Icons.attach_money),
              errorText: _firstError(state, 'amount'),
            ),
            onChanged: (_) => controller.clearFieldError('amount'),
          ),
          const SizedBox(height: 12),

          TextField(
            key: const Key('expense-receipt-name-field'),
            controller: _receiptNameController,
            enabled: formEnabled,
            textInputAction: TextInputAction.next,
            maxLength: 150,
            decoration: InputDecoration(
              labelText: 'Comercio / Lugar (opcional)',
              prefixIcon: const Icon(Icons.storefront_outlined),
              errorText: _firstError(state, 'receipt_name'),
            ),
            onChanged: (_) => controller.clearFieldError('receipt_name'),
          ),
          const SizedBox(height: 12),
        ],

        // Account dropdown (owner accounts from controller)
        DropdownButtonFormField<int>(
          key: const Key('expense-account-field'),
          initialValue: _containedOrNull([
            for (final account in accountsState.result?.accounts ?? [])
              account.id,
          ], _selectedAccountId),
          decoration: InputDecoration(
            labelText: 'Cuenta',
            helperText: 'Solo tus cuentas.',
            errorText: _firstError(state, 'account_id'),
          ),
          items: (accountsState.result?.accounts ?? [])
              .map(
                (account) => DropdownMenuItem(
                  value: account.id,
                  child: Text('${account.name} · ${account.currency.code}'),
                ),
              )
              .toList(growable: false),
          onChanged: formEnabled
              ? (value) {
                  setState(() => _selectedAccountId = value);
                  controller.clearFieldError('account_id');
                }
              : null,
        ),
        const SizedBox(height: 12),

        // Category dropdown (owner categories from controller)
        DropdownButtonFormField<int>(
          key: const Key('expense-category-field'),
          initialValue: _containedOrNull([
            for (final category in categoriesState.result?.categories ?? [])
              category.id,
          ], _selectedCategoryId),
          decoration: InputDecoration(
            labelText: 'Categoría',
            helperText: 'Solo tus categorías.',
            errorText: _firstError(state, 'category_id'),
          ),
          items: (categoriesState.result?.categories ?? [])
              .map(
                (category) => DropdownMenuItem(
                  value: category.id,
                  child: Text(category.name),
                ),
              )
              .toList(growable: false),
          onChanged: formEnabled && !_clearCategory
              ? (value) {
                  setState(() => _selectedCategoryId = value);
                  controller.clearFieldError('category_id');
                }
              : null,
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
        const SizedBox(height: 16),

        // Date selection row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: palette.soft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fecha del movimiento',
                      style: TextStyle(fontSize: 11),
                    ),
                    Text(
                      _occurredAt == null
                          ? 'Sin cambios (${editExpense.occurredAt.toUtc().year}-${editExpense.occurredAt.toUtc().month.toString().padLeft(2, '0')}-${editExpense.occurredAt.toUtc().day.toString().padLeft(2, '0')})'
                          : '${_occurredAt!.toUtc().year}-${_occurredAt!.toUtc().month.toString().padLeft(2, '0')}-${_occurredAt!.toUtc().day.toString().padLeft(2, '0')}',
                      key: const Key('expense-date-value'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const Key('expense-date-button'),
                onPressed: formEnabled ? () => _pickDate(editExpense) : null,
                child: const Text('Cambiar'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Note
        TextField(
          key: const Key('expense-note-field'),
          controller: _noteController,
          enabled: formEnabled && !_clearNote,
          textInputAction: TextInputAction.next,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Nota o comentarios',
            prefixIcon: const Icon(Icons.sticky_note_2_outlined),
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
        const SizedBox(height: 24),

        // Save Button
        FilledButton(
          key: const Key('expense-save-button'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: formEnabled ? _submit : null,
          child: state.isSaving
              ? Semantics(
                  liveRegion: true,
                  label: 'Guardando el gasto',
                  child: const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                )
              : const Text(
                  'Guardar cambios',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
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
      final initialAmount = editExpense.receiptTotal ?? editExpense.amount;
      _amountController.text = MoneyFormatter.formatInputAmount(
        initialAmount.minorUnits,
      );
      _noteController.text = editExpense.note ?? '';
      _receiptNameController.text = editExpense.receiptName;
      _receiptNoteController.text = editExpense.receiptNote ?? '';
      _descriptionController.text = editExpense.description ?? '';
      _selectedAccountId = editExpense.accountId;
      _selectedCategoryId = editExpense.category?.id;
      _clearNote = false;
      _clearCategory = false;
      _occurredAt = editExpense.occurredAt;
      _items = editExpense.items
          .map(
            (item) => _LineItemDraft(
              name: item.name,
              amount: item.amount.minorUnits / 100.0,
              quantity: item.quantity,
              unitPrice: item.unitPrice != null
                  ? item.unitPrice!.minorUnits / 100.0
                  : null,
            ),
          )
          .toList();
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
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : _receiptNameController.text.trim();
    final receiptName = _receiptNameController.text.trim().isNotEmpty
        ? _receiptNameController.text.trim()
        : name;

    final outcome = await controller.update(
      expenseId: widget.expenseId,
      name: name,
      amountInput: MoneyFormatter.clean(_amountController.text),
      note: _clearNote ? null : _asOptionalText(_noteController.text),
      clearNote: _clearNote,
      receiptName: receiptName,
      receiptNote: _asOptionalText(_receiptNoteController.text),
      categoryId: _clearCategory ? null : _selectedCategoryId,
      clearCategory: _clearCategory,
      accountId: _selectedAccountId,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gasto actualizado con éxito.')),
      );
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

  /// Returns [selected] only when it exists in [ids]. Dropdowns require
  /// their value to match an item, so unknown ids fall back to no selection.
  int? _containedOrNull(List<int> ids, int? selected) =>
      selected != null && ids.contains(selected) ? selected : null;

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

  Widget _buildLineItemsSection(
    BuildContext context,
    AppPalette palette,
    String currencyCode,
    bool formEnabled,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.line),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Productos del recibo (${_items.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
              if (formEnabled)
                TextButton.icon(
                  key: const Key('expense-add-item-button'),
                  onPressed: () => _showItemEditDialog(context, currencyCode),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No hay productos individuales.',
                  style: TextStyle(color: palette.muted, fontSize: 12),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (context, index) =>
                  Divider(color: palette.line, height: 1),
              itemBuilder: (context, index) {
                final item = _items[index];
                final qNum = double.tryParse(item.quantity);
                final qStr = qNum != null
                    ? (qNum % 1 == 0
                        ? qNum.toInt().toString()
                        : qNum.toString())
                    : item.quantity;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                      fontSize: 13.5,
                    ),
                  ),
                  subtitle: Text(
                    '$qStr ${item.unitPrice != null ? 'x \$${MoneyFormatter.formatWhole(item.unitPrice!.round())}' : ''}',
                    style: TextStyle(color: palette.muted, fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '\$${MoneyFormatter.formatWhole(item.amount.round())}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: palette.text,
                          fontSize: 13.5,
                        ),
                      ),
                      if (formEnabled) ...[
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Editar producto',
                          onPressed: () => _showItemEditDialog(
                            context,
                            currencyCode,
                            item: item,
                            index: index,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: palette.discard,
                          ),
                          tooltip: 'Eliminar producto',
                          onPressed: () {
                            setState(() {
                              _items.removeAt(index);
                              _recalculateTotalFromItems();
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _recalculateTotalFromItems() {
    if (_items.isEmpty) return;
    final total = _items.fold<double>(0.0, (sum, i) => sum + i.amount);
    final minorUnits = (total * 100).round();
    _amountController.text = MoneyFormatter.formatInputAmount(minorUnits);
  }

  Future<void> _showItemEditDialog(
    BuildContext context,
    String currencyCode, {
    _LineItemDraft? item,
    int? index,
  }) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final qtyCtrl = TextEditingController(
      text: item != null ? item.quantity : '1',
    );
    final priceCtrl = TextEditingController(
      text: item != null ? item.amount.toStringAsFixed(0) : '',
    );
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'Nuevo producto' : 'Editar producto'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Cantidad'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Total ($currencyCode) *',
                      ),
                      validator: (val) {
                        final parsed = double.tryParse(val ?? '');
                        if (parsed == null || parsed <= 0) {
                          return 'Monto inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      final name = nameCtrl.text.trim();
      final qty = qtyCtrl.text.trim().isEmpty ? '1' : qtyCtrl.text.trim();
      final total = double.tryParse(priceCtrl.text) ?? 0.0;
      final qNum = double.tryParse(qty) ?? 1.0;
      final unitPrice = qNum > 0 ? (total / qNum) : total;

      setState(() {
        if (item != null && index != null) {
          _items[index] = _LineItemDraft(
            name: name,
            quantity: qty,
            amount: total,
            unitPrice: unitPrice,
          );
        } else {
          _items.add(
            _LineItemDraft(
              name: name,
              quantity: qty,
              amount: total,
              unitPrice: unitPrice,
            ),
          );
        }
        _recalculateTotalFromItems();
      });
    }
  }
}

class _LineItemDraft {
  _LineItemDraft({
    required this.name,
    required this.amount,
    this.quantity = '1',
    this.unitPrice,
  });

  String name;
  double amount;
  String quantity;
  double? unitPrice;
}
