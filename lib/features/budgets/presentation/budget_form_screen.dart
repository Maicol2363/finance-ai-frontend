import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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
  static const _allExpensesCategoryId = 0;

  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _intervalController = TextEditingController(text: '1');
  final _amountFocus = FocusNode();
  int _categoryId = _allExpensesCategoryId;
  String? _currencyCode;
  BudgetScheduleType _scheduleType = BudgetScheduleType.recurring;
  BudgetRecurrencePreset _preset = BudgetRecurrencePreset.monthly;
  BudgetFrequencyUnit _customUnit = BudgetFrequencyUnit.month;
  late DateTime _startsOn;
  DateTime? _endsOn;
  bool _initialized = false;
  bool _initializationScheduled = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startsOn = DateTime(now.year, now.month);
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
    _nameController.dispose();
    _amountController.dispose();
    _intervalController.dispose();
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
        TextField(
          key: const Key('budget-name-field'),
          controller: _nameController,
          enabled: !state.isSaving,
          maxLength: 120,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Nombre personalizado (opcional)',
            hintText: 'Ej. Vacaciones, mercado familiar…',
            counterText: '',
          ),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<int>(
          key: const Key('budget-category-field'),
          isExpanded: true,
          initialValue: _categoryId,
          decoration: InputDecoration(
            labelText: 'Gastos incluidos',
            helperText: _categoryId == _allExpensesCategoryId
                ? 'Cuenta todos tus gastos en la moneda elegida.'
                : 'Cuenta únicamente los gastos de esta categoría.',
            errorText: _firstError(state, 'category_id'),
          ),
          items: [
            const DropdownMenuItem(
              value: _allExpensesCategoryId,
              child: Row(
                children: [
                  Icon(Icons.all_inclusive, size: 18),
                  SizedBox(width: 8),
                  Text('Todos los gastos'),
                ],
              ),
            ),
            ...result.categories.map(
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
            ),
          ],
          onChanged: state.isSaving
              ? null
              : (value) {
                  setState(() {
                    _categoryId = value ?? _allExpensesCategoryId;
                  });
                  controller.clearFieldError('category_id');
                },
        ),
        if (result.categories.isEmpty) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('budget-create-category-button'),
            onPressed: state.isSaving ? null : _createCategory,
            icon: const Icon(Icons.add),
            label: const Text('Crear una categoría opcional'),
          ),
        ],
        const FieldLabel('Tipo de calendario', uppercase: false),
        SegmentedControl(
          labels: BudgetScheduleType.values.map((item) => item.label).toList(),
          selectedIndex: BudgetScheduleType.values.indexOf(_scheduleType),
          keyPrefix: 'budget-schedule-type',
          onChanged: state.isSaving
              ? (_) {}
              : (index) => setState(() {
                  _scheduleType = BudgetScheduleType.values[index];
                  if (_scheduleType == BudgetScheduleType.oneTime) {
                    _endsOn ??= _startsOn;
                  }
                }),
        ),
        const SizedBox(height: 20),
        if (_scheduleType == BudgetScheduleType.recurring) ...[
          DropdownButtonFormField<BudgetRecurrencePreset>(
            key: const Key('budget-recurrence-field'),
            initialValue: _preset,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Frecuencia',
              errorText: _firstError(state, 'schedule'),
            ),
            items: BudgetRecurrencePreset.values
                .map(
                  (item) =>
                      DropdownMenuItem(value: item, child: Text(item.label)),
                )
                .toList(growable: false),
            onChanged: state.isSaving
                ? null
                : (value) => setState(() {
                    _preset = value ?? BudgetRecurrencePreset.monthly;
                    if (_preset != BudgetRecurrencePreset.custom) {
                      _intervalController.text =
                          _preset.interval?.toString() ?? '1';
                      _customUnit = _preset.unit ?? BudgetFrequencyUnit.month;
                    }
                  }),
          ),
          if (_preset == BudgetRecurrencePreset.custom) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('budget-interval-field'),
                    controller: _intervalController,
                    enabled: !state.isSaving,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Cada',
                      errorText: _firstError(state, 'frequency_interval'),
                    ),
                    onChanged: (_) =>
                        controller.clearFieldError('frequency_interval'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<BudgetFrequencyUnit>(
                    key: const Key('budget-frequency-unit-field'),
                    initialValue: _customUnit,
                    decoration: const InputDecoration(labelText: 'Unidad'),
                    items: BudgetFrequencyUnit.values
                        .map(
                          (unit) => DropdownMenuItem(
                            value: unit,
                            child: Text(unit.plural),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: state.isSaving
                        ? null
                        : (value) => setState(() {
                            _customUnit = value ?? BudgetFrequencyUnit.month;
                          }),
                  ),
                ),
              ],
            ),
          ],
        ],
        const SizedBox(height: 16),
        _DatePickerField(
          key: const Key('budget-start-date-field'),
          label: _scheduleType == BudgetScheduleType.recurring
              ? 'Comienza el'
              : 'Desde',
          value: _startsOn,
          enabled: !state.isSaving,
          onPressed: () => _pickDate(isStart: true),
        ),
        const SizedBox(height: 12),
        if (_scheduleType == BudgetScheduleType.recurring) ...[
          SwitchListTile.adaptive(
            key: const Key('budget-end-toggle'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Definir fecha de finalización'),
            subtitle: const Text(
              'Si se desactiva, el presupuesto se repite indefinidamente.',
            ),
            value: _endsOn != null,
            onChanged: state.isSaving
                ? null
                : (enabled) => setState(() {
                    _endsOn = enabled ? _startsOn : null;
                  }),
          ),
          if (_endsOn != null)
            _DatePickerField(
              key: const Key('budget-end-date-field'),
              label: 'Finaliza el',
              value: _endsOn!,
              enabled: !state.isSaving,
              errorText: _firstError(state, 'ends_on'),
              onPressed: () => _pickDate(isStart: false),
            ),
        ] else
          _DatePickerField(
            key: const Key('budget-end-date-field'),
            label: 'Hasta',
            value: _endsOn ?? _startsOn,
            enabled: !state.isSaving,
            errorText: _firstError(state, 'ends_on'),
            onPressed: () => _pickDate(isStart: false),
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
            helperText:
                'Solo los gastos en la misma moneda cuentan para el progreso.',
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
        _categoryId = budget != null
            ? budget.category?.id ?? _allExpensesCategoryId
            : (result.categories.isEmpty
                  ? _allExpensesCategoryId
                  : result.categories.first.id);
        _currencyCode = budget?.currency.code ?? result.suggestedCurrencyCode;
        if (budget != null) {
          _nameController.text = budget.name;
          _amountController.text = MoneyFormatter.formatInputAmount(
            budget.amount.minorUnits,
          );
          _scheduleType = budget.scheduleType == 'one_time'
              ? BudgetScheduleType.oneTime
              : BudgetScheduleType.recurring;
          _startsOn = DateTime(
            budget.startsOn.year,
            budget.startsOn.month,
            budget.startsOn.day,
          );
          _endsOn = budget.endsOn == null
              ? null
              : DateTime(
                  budget.endsOn!.year,
                  budget.endsOn!.month,
                  budget.endsOn!.day,
                );
          final frequencyUnit = BudgetFrequencyUnit.values
              .where((item) => item.wireValue == budget.frequencyUnit)
              .firstOrNull;
          final interval = budget.frequencyInterval;
          if (frequencyUnit != null && interval != null) {
            _preset = _presetFor(frequencyUnit, interval);
            _customUnit = frequencyUnit;
            _intervalController.text = interval.toString();
          }
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
          categoryId: _categoryId == _allExpensesCategoryId
              ? null
              : _categoryId,
          nameInput: _nameController.text,
          amountInput: _amountController.text,
          currencyCode: _currencyCode,
          schedule: _schedule(),
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
          'Se eliminará “${budget.name}”. Tus gastos no cambiarán.',
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

  BudgetSchedule _schedule() {
    if (_scheduleType == BudgetScheduleType.oneTime) {
      return BudgetSchedule(
        scheduleType: _scheduleType,
        startsOn: _startsOn,
        endsOn: _endsOn ?? _startsOn,
      );
    }
    final unit = _preset.unit ?? _customUnit;
    final interval =
        _preset.interval ?? int.tryParse(_intervalController.text.trim()) ?? 0;
    return BudgetSchedule(
      scheduleType: _scheduleType,
      frequencyUnit: unit,
      frequencyInterval: interval,
      startsOn: _startsOn,
      endsOn: _endsOn,
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _startsOn : (_endsOn ?? _startsOn);
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
      helpText: isStart
          ? 'Selecciona la fecha inicial'
          : 'Selecciona la fecha final',
    );
    if (selected == null || !mounted) return;
    setState(() {
      final normalized = DateTime(selected.year, selected.month, selected.day);
      if (isStart) {
        _startsOn = normalized;
        if (_endsOn != null && _endsOn!.isBefore(normalized)) {
          _endsOn = normalized;
        }
      } else {
        _endsOn = normalized;
      }
    });
    ref.read(budgetsControllerProvider.notifier).clearFieldError('ends_on');
  }

  BudgetRecurrencePreset _presetFor(BudgetFrequencyUnit unit, int interval) {
    for (final preset in BudgetRecurrencePreset.values) {
      if (preset.unit == unit && preset.interval == interval) return preset;
    }
    return BudgetRecurrencePreset.custom;
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onPressed,
    this.errorText,
    super.key,
  });

  final String label;
  final DateTime value;
  final bool enabled;
  final VoidCallback onPressed;
  final String? errorText;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: enabled ? onPressed : null,
    borderRadius: BorderRadius.circular(12),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        suffixIcon: const Icon(Icons.calendar_month_outlined),
      ),
      child: Text(
        '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}',
      ),
    ),
  );
}
