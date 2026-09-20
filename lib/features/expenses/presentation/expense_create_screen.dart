import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic.dart';
import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/theme/app_palette.dart';
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
  bool _showOptionalDetails = false;
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

  String _accountIcon(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return '💵';
      case AccountType.bank:
        return '🏦';
      case AccountType.digitalWallet:
        return '🟣';
      case AccountType.savings:
        return '💰';
      case AccountType.creditCard:
        return '💳';
      case AccountType.other:
        return '🪙';
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = ref.watch(expensesControllerProvider);
    final controller = ref.read(expensesControllerProvider.notifier);
    final formEnabled =
        !state.isSaving && !state.requiresMutationReview && !_loadingOptions;

    final selectedAccount = _accounts
        .where((a) => a.id == _selectedAccountId)
        .firstOrNull;
    final currencySymbol = selectedAccount?.currency.code == 'USD'
        ? '\$'
        : '\$';

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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
                  if (_loadingOptions || state.isSaving) ...[
                    Semantics(
                      liveRegion: true,
                      label: _loadingOptions
                          ? 'Cargando opciones del gasto'
                          : 'Registrando gasto',
                      child: const LinearProgressIndicator(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_loadDiagnostic case final diagnostic?) ...[
                    ErrorDiagnosticPanel(diagnostic: diagnostic),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loadOptions,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar carga de cuentas'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (state.mutationDiagnostic case final diagnostic?) ...[
                    ErrorDiagnosticPanel(diagnostic: diagnostic),
                    const SizedBox(height: 16),
                  ],

                  // HERO AMOUNT BOX (Estilo Mockup)
                  Container(
                    decoration: BoxDecoration(
                      color: palette.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _firstError(state, 'amount') != null
                            ? palette.discard
                            : palette.line,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x080F172A),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          currencySymbol,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: palette.text,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            key: const Key('expense-create-amount-field'),
                            controller: _amountController,
                            focusNode: _amountFocus,
                            enabled: formEnabled,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.next,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: palette.text,
                            ),
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: palette.placeholder,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              filled: false,
                            ),
                            onChanged: (_) =>
                                controller.clearFieldError('amount'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_firstError(state, 'amount') case final amountError?) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        amountError,
                        style: TextStyle(color: palette.discard, fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // COMERCIO O DESCRIPCIÓN (Estilo Mockup)
                  Text(
                    '¿EN QUÉ GASTASTE? / COMERCIO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: palette.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    key: const Key('expense-create-merchant-field'),
                    controller: _merchantController,
                    focusNode: _merchantFocus,
                    enabled: formEnabled,
                    textInputAction: TextInputAction.next,
                    maxLength: 150,
                    decoration: InputDecoration(
                      hintText: 'ej. Almuerzo, D1, Taxi, Café...',
                      errorText: _firstError(state, 'merchant'),
                    ),
                    onChanged: (_) => controller.clearFieldError('merchant'),
                  ),
                  const SizedBox(height: 10),

                  // CUENTA DE PAGO - CHIPS (Estilo Mockup)
                  Text(
                    'CUENTA DE PAGO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: palette.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_firstError(state, 'account_id')
                      case final accError?) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        accError,
                        style: TextStyle(color: palette.discard, fontSize: 12),
                      ),
                    ),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final account in _accounts)
                        InkWell(
                          key: Key('expense-account-chip-${account.id}'),
                          borderRadius: BorderRadius.circular(10),
                          onTap: formEnabled
                              ? () {
                                  setState(
                                    () => _selectedAccountId = account.id,
                                  );
                                  controller.clearFieldError('account_id');
                                }
                              : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedAccountId == account.id
                                  ? palette.primary
                                  : palette.card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _selectedAccountId == account.id
                                    ? palette.primary
                                    : palette.line,
                              ),
                            ),
                            child: Text(
                              '${_accountIcon(account.type)} ${account.name}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _selectedAccountId == account.id
                                    ? Colors.white
                                    : palette.text,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // DETALLES OPCIONALES COLAPSADOS (AC-3)
                  InkWell(
                    key: const Key('expense-create-optional-toggle'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() {
                        _showOptionalDetails = !_showOptionalDetails;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Detalles opcionales (categoría, fecha, nota)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: palette.muted,
                            ),
                          ),
                          Icon(
                            _showOptionalDetails
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 18,
                            color: palette.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showOptionalDetails) ...[
                    Material(
                      color: palette.soft2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: palette.line),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                  child: Text('Sin categorizar'),
                                ),
                                for (final cat in _categories)
                                  DropdownMenuItem(
                                    value: cat.id,
                                    child: Text(cat.name),
                                  ),
                              ],
                              onChanged: formEnabled
                                  ? (value) {
                                      setState(
                                        () => _selectedCategoryId = value,
                                      );
                                      controller.clearFieldError('category_id');
                                    }
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Material(
                              color: Colors.transparent,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Fecha del gasto'),
                                subtitle: Text(
                                  '${_occurredAt.year}-${_occurredAt.month.toString().padLeft(2, '0')}-${_occurredAt.day.toString().padLeft(2, '0')}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.calendar_today_outlined,
                                  ),
                                  onPressed: formEnabled ? _pickDate : null,
                                ),
                                onTap: formEnabled ? _pickDate : null,
                              ),
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
                                hintText:
                                    'Detalles adicionales sobre la compra',
                                errorText: _firstError(state, 'note'),
                              ),
                              onChanged: (_) =>
                                  controller.clearFieldError('note'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('expense-create-submit-button'),
                    onPressed: formEnabled ? _save : null,
                    icon: state.isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
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
