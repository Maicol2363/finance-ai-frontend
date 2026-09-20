import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic.dart';
import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../accounts/domain/account_models.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/category_models.dart';
import '../application/expenses_controller.dart';
import '../application/expenses_state.dart';

class ExpenseCreateOptions {
  const ExpenseCreateOptions({
    required this.accounts,
    required this.categories,
  });

  final List<Account> accounts;
  final List<Category> categories;
}

final expenseCreateOptionsProvider =
    Provider<Future<ExpenseCreateOptions> Function()>((ref) {
      return () async {
        final accountsResult = await ref
            .read(accountsRepositoryProvider)
            .list(includeInactive: false);
        final categoriesResult = await ref
            .read(categoriesRepositoryProvider)
            .list();
        return ExpenseCreateOptions(
          accounts: accountsResult.accounts,
          categories: categoriesResult.categories,
        );
      };
    });

class ExpenseCreateScreen extends ConsumerStatefulWidget {
  const ExpenseCreateScreen({super.key});

  @override
  ConsumerState<ExpenseCreateScreen> createState() =>
      _ExpenseCreateScreenState();
}

class _ExpenseCreateScreenState extends ConsumerState<ExpenseCreateScreen> {
  final _merchantController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _merchantFocus = FocusNode();
  final _amountFocus = FocusNode();

  List<Account> _accounts = const [];
  List<Category> _categories = const [];
  int? _selectedAccountId;
  int? _selectedCategoryId;
  DateTime _occurredAt = DateTime.now();

  bool _loadingOptions = true;
  ErrorDiagnostic? _loadDiagnostic;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) return;
      ref.read(expensesControllerProvider.notifier).clearMutationFeedback();
      _loadOptions();
    });
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _merchantFocus.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loadingOptions = true;
      _loadDiagnostic = null;
    });
    try {
      final options = await ref.read(expenseCreateOptionsProvider)();
      if (!mounted) return;
      setState(() {
        _accounts = options.accounts;
        _categories = options.categories;
        _selectedAccountId = options.accounts
            .where((a) => a.isActive)
            .firstOrNull
            ?.id;
        _loadingOptions = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loadingOptions = false;
        _loadDiagnostic = ErrorDiagnostic.capture(
          code: 'expense_options_unavailable',
          operation: 'load_expense_create_options',
          userMessage:
              'No pudimos cargar tus cuentas y categorías. Inténtalo de nuevo.',
          technicalReason: 'form_options_failure',
        );
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null && mounted) {
      setState(() {
        _occurredAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _occurredAt.hour,
          _occurredAt.minute,
          _occurredAt.second,
        );
      });
    }
  }

  Future<void> _save() async {
    final controller = ref.read(expensesControllerProvider.notifier);
    final outcome = await controller.create(
      accountId: _selectedAccountId,
      amountInput: _amountController.text,
      merchant: _merchantController.text,
      occurredAt: _occurredAt,
      categoryId: _selectedCategoryId,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text,
    );
    if (!mounted) return;
    if (outcome == ExpenseMutationOutcome.success) {
      context.go('/expenses');
    }
  }

  String? _firstError(ExpensesState state, String field) {
    return state.fieldErrors[field]?.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(expensesControllerProvider);
    final controller = ref.read(expensesControllerProvider.notifier);
    final formEnabled =
        !state.isSaving && !state.requiresMutationReview && !_loadingOptions;

    final selectedAccount = _accounts
        .where((a) => a.id == _selectedAccountId)
        .firstOrNull;
    final currencyLabel = selectedAccount?.currency.code ?? 'COP';

    return PopScope(
      canPop: !state.isSaving,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Volver a gastos',
            onPressed: state.isSaving ? null : () => context.go('/expenses'),
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Registrar gasto'),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                children: [
                  if (_loadingOptions || state.isSaving) ...[
                    Semantics(
                      liveRegion: true,
                      label: _loadingOptions
                          ? 'Cargando opciones del gasto'
                          : 'Registrando gasto',
                      child: const LinearProgressIndicator(),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (_loadDiagnostic case final diagnostic?) ...[
                    ErrorDiagnosticPanel(diagnostic: diagnostic),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loadOptions,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar carga de cuentas'),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (state.mutationDiagnostic case final diagnostic?) ...[
                    ErrorDiagnosticPanel(diagnostic: diagnostic),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    'Registra un gasto indicando el comercio o lugar y el monto gastado.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    key: const Key('expense-create-merchant-field'),
                    controller: _merchantController,
                    focusNode: _merchantFocus,
                    enabled: formEnabled,
                    textInputAction: TextInputAction.next,
                    maxLength: 150,
                    decoration: InputDecoration(
                      labelText: 'Comercio o lugar',
                      hintText: 'Ej. Supermercado, Restaurante, Uber',
                      errorText: _firstError(state, 'merchant'),
                    ),
                    onChanged: (_) => controller.clearFieldError('merchant'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('expense-create-amount-field'),
                    controller: _amountController,
                    focusNode: _amountFocus,
                    enabled: formEnabled,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Monto ($currencyLabel)',
                      hintText: '0.00',
                      helperText: 'Monto positivo con hasta dos decimales.',
                      errorText: _firstError(state, 'amount'),
                    ),
                    onChanged: (_) => controller.clearFieldError('amount'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: const Key('expense-create-account-field'),
                    initialValue: _selectedAccountId,
                    decoration: InputDecoration(
                      labelText: 'Cuenta de pago',
                      errorText: _firstError(state, 'account_id'),
                    ),
                    items: [
                      for (final account in _accounts)
                        DropdownMenuItem(
                          value: account.id,
                          child: Text(
                            '${account.name} (${account.currency.code})',
                          ),
                        ),
                    ],
                    onChanged: formEnabled
                        ? (value) {
                            setState(() => _selectedAccountId = value);
                            controller.clearFieldError('account_id');
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    key: const Key('expense-create-category-field'),
                    initialValue: _selectedCategoryId,
                    decoration: InputDecoration(
                      labelText: 'Categoría (opcional)',
                      errorText: _firstError(state, 'category_id'),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Sin categoría'),
                      ),
                      for (final cat in _categories)
                        DropdownMenuItem(value: cat.id, child: Text(cat.name)),
                    ],
                    onChanged: formEnabled
                        ? (value) {
                            setState(() => _selectedCategoryId = value);
                            controller.clearFieldError('category_id');
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fecha del gasto'),
                    subtitle: Text(
                      '${_occurredAt.year}-${_occurredAt.month.toString().padLeft(2, '0')}-${_occurredAt.day.toString().padLeft(2, '0')}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_today_outlined),
                      onPressed: formEnabled ? _pickDate : null,
                    ),
                    onTap: formEnabled ? _pickDate : null,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('expense-create-note-field'),
                    controller: _noteController,
                    enabled: formEnabled,
                    textInputAction: TextInputAction.done,
                    maxLines: 2,
                    maxLength: 5000,
                    decoration: InputDecoration(
                      labelText: 'Nota (opcional)',
                      hintText: 'Detalles adicionales sobre la compra',
                      errorText: _firstError(state, 'note'),
                    ),
                    onChanged: (_) => controller.clearFieldError('note'),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const Key('expense-create-submit-button'),
                    onPressed: formEnabled ? _save : null,
                    icon: state.isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      state.isSaving ? 'Guardando...' : 'Registrar gasto',
                    ),
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
