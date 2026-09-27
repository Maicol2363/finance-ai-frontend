import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/manage_widgets.dart';
import '../../categories/presentation/category_visuals.dart';
import '../application/budgets_controller.dart';
import '../application/budgets_state.dart';
import '../domain/budget_models.dart';

class BudgetFormScreen extends ConsumerStatefulWidget {
  const BudgetFormScreen({this.budgetId, super.key});

  final int? budgetId;

  bool get isEditing => budgetId != null;

  @override
  ConsumerState<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends ConsumerState<BudgetFormScreen> {
  final _amountController = TextEditingController();
  final _amountFocus = FocusNode();
  int? _categoryId;
  String? _currencyCode;
  BudgetPeriod _period = BudgetPeriod.monthly;
  bool _initialized = false;
  bool _initializationScheduled = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) return;
      final controller = ref.read(budgetsControllerProvider.notifier);
      controller.clearMutationFeedback();
      if (ref.read(budgetsControllerProvider).result == null) {
        controller.load();
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(budgetsControllerProvider);
    final controller = ref.read(budgetsControllerProvider.notifier);
    final result = state.result;
    final budget = widget.budgetId == null
        ? null
        : result?.budgetById(widget.budgetId!);
    _scheduleInitialization(result, budget);
    final missing =
        widget.isEditing &&
        state.loadStatus == BudgetsLoadStatus.ready &&
        budget == null;

    return PopScope(
      canPop: !state.isSaving,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: widget.isEditing
                    ? 'Editar presupuesto'
                    : 'Nuevo presupuesto',
                subtitle: 'Categoría, periodo, monto y moneda',
                leading: HeaderIconButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Volver a presupuestos',
                  onPressed: state.isSaving
                      ? null
                      : () => context.go('/budgets'),
                ),
                actions: [
                  if (budget != null)
                    IconButton(
                      key: const Key('budget-delete-button'),
                      tooltip: 'Eliminar presupuesto',
                      onPressed: state.isSaving
                          ? null
                          : () => _confirmDelete(budget),
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                      children: [
                        if (state.loadStatus == BudgetsLoadStatus.loading)
                          const LinearProgressIndicator(
                            semanticsLabel:
                                'Cargando formulario de presupuesto',
                          ),
                        if (state.diagnostic case final diagnostic?) ...[
                          ErrorDiagnosticPanel(diagnostic: diagnostic),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: controller.load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                        if (missing)
                          const Padding(
                            padding: EdgeInsets.only(top: 48),
                            child: Text(
                              'Este presupuesto ya no está disponible.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        else if (_initialized && result != null)
                          _form(state, result),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(BudgetsState state, BudgetListResult result) {
    final controller = ref.read(budgetsControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.mutationDiagnostic case final diagnostic?) ...[
          ErrorDiagnosticPanel(diagnostic: diagnostic),
          const SizedBox(height: 16),
        ],
        if (result.categories.isEmpty) ...[
          const Text(
            'Necesitas una categoría antes de crear un presupuesto.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('budget-create-category-button'),
            onPressed: state.isSaving ? null : _createCategory,
            icon: const Icon(Icons.add),
            label: const Text('Crear categoría'),
          ),
        ] else ...[
          DropdownButtonFormField<int>(
            key: const Key('budget-category-field'),
            isExpanded: true,
            initialValue: _categoryId,
            decoration: InputDecoration(
              labelText: 'Categoría',
              errorText: _firstError(state, 'category_id'),
            ),
            items: result.categories
                .map(
                  (category) => DropdownMenuItem(
                    value: category.id,
                    child: Row(
                      children: [
                        Icon(
                          category.icon.value,
                          size: 18,
                          color: category.color.value,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            category.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: state.isSaving
                ? null
                : (value) {
                    setState(() => _categoryId = value);
                    controller.clearFieldError('category_id');
                  },
          ),
          const FieldLabel('Periodo', uppercase: false),
          SegmentedControl(
            labels: BudgetPeriod.values.map((item) => item.label).toList(),
            selectedIndex: BudgetPeriod.values.indexOf(_period),
            keyPrefix: 'budget-period',
            onChanged: state.isSaving
                ? (_) {}
                : (index) => setState(() {
                    _period = BudgetPeriod.values[index];
                  }),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('budget-amount-field'),
            controller: _amountController,
            focusNode: _amountFocus,
            enabled: !state.isSaving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [MoneyInputFormatter()],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Monto objetivo',
              hintText: '500.000',
              errorText: _firstError(state, 'amount'),
            ),
            onChanged: (_) => controller.clearFieldError('amount'),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            key: const Key('budget-currency-field'),
            isExpanded: true,
            initialValue: _currencyCode,
            decoration: InputDecoration(
              labelText: 'Moneda',
              helperText: 'Solo los gastos en la misma moneda cuentan para el progreso.',
              errorText: _firstError(state, 'currency_code'),
            ),
            items: result.supportedCurrencies
                .map(
                  (currency) => DropdownMenuItem(
                    value: currency.code,
                    child: Text(
                      '${currency.code} · ${currency.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: state.isSaving
                ? null
                : (value) {
                    setState(() => _currencyCode = value);
                    controller.clearFieldError('currency_code');
                  },
          ),
          const SizedBox(height: 28),
          FilledButton(
            key: const Key('budget-save-button'),
            onPressed: state.isSaving ? null : _submit,
            child: state.isSaving
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(
                    widget.isEditing ? 'Guardar cambios' : 'Crear presupuesto',
                  ),
          ),
        ],
      ],
    );
  }

  void _scheduleInitialization(BudgetListResult? result, Budget? budget) {
    if (_initialized || _initializationScheduled || result == null) return;
    if (widget.isEditing && budget == null) return;
    _initializationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializationScheduled = false;
      if (!mounted || _initialized) return;
      setState(() {
        _categoryId =
            budget?.category?.id ??
            (result.categories.isEmpty ? null : result.categories.first.id);
        _currencyCode = budget?.currency.code ?? result.suggestedCurrencyCode;
        _period = budget?.simplePeriod ?? BudgetPeriod.monthly;
        if (budget != null) {
          _amountController.text = MoneyFormatter.formatInputAmount(
            budget.amount.minorUnits,
          );
        }
        _initialized = true;
      });
    });
  }

  Future<void> _createCategory() async {
    await context.push('/quick-add/category');
    if (mounted) {
      await ref.read(budgetsControllerProvider.notifier).load();
    }
  }

  Future<void> _submit() async {
    final outcome = await ref
        .read(budgetsControllerProvider.notifier)
        .save(
          budgetId: widget.budgetId,
          categoryId: _categoryId,
          amountInput: _amountController.text,
          currencyCode: _currencyCode,
          period: _period,
        );
    if (!mounted) return;
    if (outcome == BudgetMutationOutcome.success) {
      context.go('/budgets');
    } else if (outcome == BudgetMutationOutcome.invalid) {
      _amountFocus.requestFocus();
    }
  }

  Future<void> _confirmDelete(Budget budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar presupuesto?'),
        content: Text(
          'Se eliminará el presupuesto de ${budget.category?.name ?? 'todos los gastos'}. Tus gastos no cambiarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('budget-confirm-delete-button'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final outcome = await ref
        .read(budgetsControllerProvider.notifier)
        .deleteBudget(budget.id);
    if (mounted && outcome == BudgetMutationOutcome.success) {
      context.go('/budgets');
    }
  }

  String? _firstError(BudgetsState state, String field) =>
      state.fieldErrors[field]?.firstOrNull;
}
