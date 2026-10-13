import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic.dart';
import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/management_page_scaffold.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../accounts/domain/account_models.dart';
import '../../auth/session/application/auth_session_controller.dart';
import '../../auth/session/domain/session_models.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/category_models.dart';
import '../../categories/presentation/category_visuals.dart';
import '../../income_sources/data/income_sources_repository.dart';
import '../../income_sources/domain/income_source_models.dart';
import '../../incomes/data/incomes_repository.dart';
import '../../incomes/domain/income_models.dart';
import '../application/expenses_controller.dart';
import '../application/expenses_state.dart';

enum MovementType { expense, income }

class ExpenseCreateOptions {
  const ExpenseCreateOptions({
    required this.accounts,
    required this.categories,
    required this.incomeSources,
  });

  final List<Account> accounts;
  final List<Category> categories;
  final List<IncomeSource> incomeSources;
}

final expenseCreateOptionsProvider =
    Provider<Future<ExpenseCreateOptions> Function()>((ref) {
      return () async {
        final accountsFuture = ref
            .read(accountsRepositoryProvider)
            .list(includeInactive: false);
        final categoriesFuture = ref.read(categoriesRepositoryProvider).list();

        final accountsResult = await accountsFuture;
        CategoryListResult? categoriesResult;
        try {
          categoriesResult = await categoriesFuture;
        } catch (e) {
          debugPrint('Warning: Failed to load categories: $e');
        }

        List<IncomeSource> sources = const [];
        try {
          sources = await ref
              .read(authSessionControllerProvider.notifier)
              .runProtected(
                (access) => ref
                    .read(incomeSourcesRepositoryProvider)
                    .list(accessCredential: access),
              );
        } catch (_) {}

        return ExpenseCreateOptions(
          accounts: accountsResult.accounts,
          categories: categoriesResult?.categories ?? const [],
          incomeSources: sources,
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
  MovementType _type = MovementType.expense;

  final _merchantController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _customSourceController = TextEditingController();
  final _merchantFocus = FocusNode();
  final _amountFocus = FocusNode();

  List<Account> _accounts = const [];
  List<Category> _categories = const [];
  List<IncomeSource> _incomeSources = const [];
  int? _selectedAccountId;
  int? _selectedCategoryId;
  int? _selectedSourceId;
  String? _selectedSourceName;
  DateTime _occurredAt = DateTime.now();

  bool _loadingOptions = true;
  bool _showOptionalDetails = false;
  bool _isSavingIncome = false;
  Map<String, List<String>> _incomeFieldErrors = const {};
  ErrorDiagnostic? _loadDiagnostic;
  ErrorDiagnostic? _incomeDiagnostic;

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
    _customSourceController.dispose();
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
        _incomeSources = options.incomeSources;
        if (_selectedAccountId == null ||
            !_accounts.any((a) => a.id == _selectedAccountId)) {
          _selectedAccountId = options.accounts
              .where((a) => a.isActive)
              .firstOrNull
              ?.id;
        }
        if (_selectedSourceId == null && options.incomeSources.isNotEmpty) {
          _selectedSourceId = options.incomeSources.first.id;
          _selectedSourceName = options.incomeSources.first.name;
        }
        _loadingOptions = false;
      });
      Future<void>.microtask(() {
        if (mounted) {
          _amountFocus.requestFocus();
        }
      });
    } on Object catch (e, stack) {
      debugPrint('Error loading expense create options: $e\n$stack');
      if (!mounted) return;
      final (code, message, correlationId, reason) = switch (e) {
        AccountFailure f => (
          f.code,
          f.userMessage,
          f.correlationId,
          f.technicalReason,
        ),
        CategoryFailure f => (
          f.code,
          f.userMessage,
          f.correlationId,
          f.technicalReason,
        ),
        InvalidSessionFailure f => (
          f.code,
          f.userMessage,
          f.correlationId,
          f.technicalReason,
        ),
        _ => (
          'expense_options_unavailable',
          'No pudimos cargar tus cuentas y catálogos. Inténtalo de nuevo.',
          'unavailable',
          e.toString(),
        ),
      };
      setState(() {
        _loadingOptions = false;
        _loadDiagnostic = ErrorDiagnostic.capture(
          code: code,
          operation: 'load_expense_create_options',
          userMessage: message,
          correlationId: correlationId,
          technicalReason: reason,
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
    if (_type == MovementType.income) {
      await _saveIncome();
    } else {
      await _saveExpense();
    }
  }

  Future<void> _saveExpense() async {
    final controller = ref.read(expensesControllerProvider.notifier);
    final outcome = await controller.create(
      accountId: _selectedAccountId,
      amountInput: MoneyFormatter.clean(_amountController.text),
      merchant: _merchantController.text,
      occurredAt: _occurredAt,
      categoryId: _selectedCategoryId,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text,
    );
    if (!mounted) return;
    if (outcome == ExpenseMutationOutcome.success) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gasto registrado exitosamente.')),
      );
    }
  }

  Future<void> _saveIncome() async {
    if (_isSavingIncome) return;
    final errors = <String, List<String>>{};
    final account = _accounts
        .where((a) => a.id == _selectedAccountId)
        .firstOrNull;
    if (account == null || !account.isActive) {
      errors['account_id'] = ['Selecciona una cuenta activa.'];
    }
    final amount = MoneyAmount.tryParseUserInput(
      MoneyFormatter.clean(_amountController.text),
    );
    if (amount == null || amount.minorUnits <= 0) {
      errors['amount'] = [
        'Ingresa un monto positivo con máximo dos decimales.',
      ];
    }
    if (errors.isNotEmpty) {
      setState(() {
        _incomeFieldErrors = errors;
      });
      return;
    }
    setState(() {
      _isSavingIncome = true;
      _incomeFieldErrors = const {};
      _incomeDiagnostic = null;
    });

    final sourceText = _customSourceController.text.trim().isNotEmpty
        ? _customSourceController.text.trim()
        : _selectedSourceName ?? 'Ingreso';

    final command = IncomeWriteCommand(
      accountId: account!.id,
      amount: amount!,
      date: _occurredAt,
      description: _merchantController.text.trim().isNotEmpty
          ? _merchantController.text.trim()
          : sourceText,
      incomeSourceId: _selectedSourceId,
    );

    try {
      final repository = ref.read(incomesRepositoryProvider);
      await repository.create(command);
      if (!mounted) return;
      ref.read(incomeRevisionProvider.notifier).changed();
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingreso registrado exitosamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSavingIncome = false;
        _incomeDiagnostic = ErrorDiagnostic.capture(
          code: 'income_save_failed',
          operation: 'save_income',
          userMessage: 'No pudimos guardar el ingreso. Inténtalo de nuevo.',
          technicalReason: e.toString(),
        );
      });
    }
  }

  String? _firstError(ExpensesState state, String field) {
    if (_type == MovementType.income) {
      return _incomeFieldErrors[field]?.firstOrNull;
    }
    return state.fieldErrors[field]?.firstOrNull;
  }

  IconData _accountIcon(AccountType type) => switch (type) {
    AccountType.cash => FinanceIcons.paymentsOutlined,
    AccountType.bank => FinanceIcons.accountBalanceOutlined,
    AccountType.digitalWallet => FinanceIcons.accountBalanceWalletOutlined,
    AccountType.savings => FinanceIcons.savingsOutlined,
    AccountType.creditCard => FinanceIcons.creditCardOutlined,
    AccountType.other => FinanceIconCatalog.dataFor(FinanceIconKey.account),
  };

  IconData _incomeSourceIcon(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('freelance')) {
      return FinanceIcons.workOutlineRounded;
    }
    if (normalized.contains('transfer')) {
      return FinanceIconCatalog.dataFor(FinanceIconKey.transfer);
    }
    if (normalized.contains('regalo')) {
      return FinanceIconCatalog.dataFor(FinanceIconKey.gift);
    }
    return FinanceIconCatalog.dataFor(FinanceIconKey.income);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = ref.watch(expensesControllerProvider);
    final controller = ref.read(expensesControllerProvider.notifier);
    final isSaving = state.isSaving || _isSavingIncome;
    final formEnabled =
        !isSaving && !state.requiresMutationReview && !_loadingOptions;

    final selectedAccount = _accounts
        .where((a) => a.id == _selectedAccountId)
        .firstOrNull;
    final currencySymbol = selectedAccount?.currency.code == 'USD'
        ? '\$'
        : '\$';

    final isIncome = _type == MovementType.income;

    return PopScope(
      canPop: !isSaving,
      child: ManagementPageScaffold(
        title: isIncome ? 'Registrar ingreso' : 'Registrar gasto',
        leading: HeaderIconButton(
          icon: FinanceIcons.arrowBack,
          tooltip: context.canPop() ? 'Volver' : 'Volver al inicio',
          onPressed: isSaving
              ? null
              : () {
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
            // =================== SEGMENTED TOGGLE (GASTO / INGRESO) ===================
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        key: const Key('segment-gasto'),
                        onTap: formEnabled
                            ? () => setState(() => _type = MovementType.expense)
                            : null,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isIncome
                                ? palette.card
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: !isIncome
                                ? const [
                                    BoxShadow(
                                      color: Color(0x0A0F172A),
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'Gasto',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: !isIncome
                                    ? palette.discard
                                    : palette.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        key: const Key('segment-ingreso'),
                        onTap: formEnabled
                            ? () => setState(() => _type = MovementType.income)
                            : null,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isIncome ? palette.card : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: isIncome
                                ? const [
                                    BoxShadow(
                                      color: Color(0x0A0F172A),
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'Ingreso',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isIncome
                                    ? palette.income
                                    : palette.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_loadingOptions || isSaving) ...[
              Semantics(
                liveRegion: true,
                label: _loadingOptions
                    ? 'Cargando opciones'
                    : (isIncome ? 'Registrando ingreso' : 'Registrando gasto'),
                child: const LinearProgressIndicator(),
              ),
              const SizedBox(height: 16),
            ],
            if (_loadDiagnostic case final diagnostic?) ...[
              ErrorDiagnosticPanel(diagnostic: diagnostic),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadOptions,
                icon: const Icon(FinanceIcons.refresh),
                label: const Text('Reintentar carga de cuentas'),
              ),
              const SizedBox(height: 16),
            ],
            if (state.mutationDiagnostic case final diagnostic?) ...[
              ErrorDiagnosticPanel(diagnostic: diagnostic),
              const SizedBox(height: 16),
            ],
            if (_incomeDiagnostic case final diagnostic?) ...[
              ErrorDiagnosticPanel(diagnostic: diagnostic),
              const SizedBox(height: 16),
            ],

            // =================== HERO AMOUNT BOX ===================
            Container(
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _firstError(state, 'amount') != null
                      ? palette.discard
                      : (isIncome
                            ? palette.income.withValues(alpha: 0.3)
                            : palette.discard.withValues(alpha: 0.3)),
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x080F172A),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    isIncome ? '+ $currencySymbol' : '- $currencySymbol',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: isIncome ? palette.income : palette.discard,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const Key('expense-create-amount-field'),
                      controller: _amountController,
                      focusNode: _amountFocus,
                      autofocus: true,
                      enabled: formEnabled,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: const [
                        MoneyInputFormatter(allowNegative: false),
                      ],
                      textInputAction: TextInputAction.next,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: isIncome ? palette.income : palette.discard,
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
                      onChanged: (_) {
                        controller.clearFieldError('amount');
                        setState(() {
                          _incomeFieldErrors = Map.from(_incomeFieldErrors)
                            ..remove('amount');
                        });
                      },
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

            // =================== CONCEPTO O FUENTE DE INGRESO ===================
            if (isIncome) ...[
              Text(
                'FUENTE DE INGRESO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: palette.muted,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_incomeSources.isNotEmpty)
                    for (final source in _incomeSources)
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: formEnabled
                            ? () {
                                setState(() {
                                  _selectedSourceId = source.id;
                                  _selectedSourceName = source.name;
                                  _customSourceController.clear();
                                });
                              }
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedSourceId == source.id
                                ? palette.incomeSoft
                                : palette.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _selectedSourceId == source.id
                                  ? palette.income
                                  : palette.line,
                              width: _selectedSourceId == source.id ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _incomeSourceIcon(source.name),
                                size: 15,
                                color: _selectedSourceId == source.id
                                    ? palette.income
                                    : palette.muted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                source.name,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: _selectedSourceId == source.id
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: _selectedSourceId == source.id
                                      ? palette.income
                                      : palette.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                  else ...[
                    for (final defaultName in [
                      'Salario',
                      'Freelance',
                      'Transferencia',
                      'Regalo',
                    ])
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: formEnabled
                            ? () {
                                setState(() {
                                  _selectedSourceName = defaultName;
                                  _selectedSourceId = null;
                                  _customSourceController.clear();
                                });
                              }
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedSourceName == defaultName
                                ? palette.incomeSoft
                                : palette.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _selectedSourceName == defaultName
                                  ? palette.income
                                  : palette.line,
                              width: _selectedSourceName == defaultName
                                  ? 1.5
                                  : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _incomeSourceIcon(defaultName),
                                size: 15,
                                color: _selectedSourceName == defaultName
                                    ? palette.income
                                    : palette.muted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                defaultName,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: _selectedSourceName == defaultName
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: _selectedSourceName == defaultName
                                      ? palette.income
                                      : palette.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _customSourceController,
                enabled: formEnabled,
                decoration: const InputDecoration(
                  hintText: 'O escribe otra fuente de ingreso...',
                ),
                onChanged: (text) {
                  if (text.isNotEmpty) {
                    setState(() {
                      _selectedSourceId = null;
                      _selectedSourceName = text;
                    });
                  }
                },
              ),
            ] else ...[
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
            ],
            const SizedBox(height: 12),

            // =================== CUENTA DE PAGO / DESTINO ===================
            Text(
              isIncome ? 'CUENTA DE DESTINO' : 'CUENTA DE PAGO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: palette.muted,
              ),
            ),
            const SizedBox(height: 6),
            if (_firstError(state, 'account_id') case final accError?) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  accError,
                  style: TextStyle(color: palette.discard, fontSize: 12),
                ),
              ),
            ],

            // Si no hay cuentas (y ya terminamos de cargar), mostramos un card con el botón para crearla directamente
            if (!_loadingOptions && _accounts.isEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.line),
                ),
                child: Row(
                  children: [
                    Icon(
                      FinanceIcons.accountBalanceWalletOutlined,
                      size: 22,
                      color: isIncome ? palette.income : palette.discard,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No tienes cuentas registradas',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: palette.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Crea una cuenta (Efectivo, Bancolombia, etc.) para registrar movimientos.',
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      key: const Key('expense-create-account-button'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(60, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () async {
                        final createdId = await context.push<int>(
                          '/quick-add/account',
                        );
                        await _loadOptions();
                        if (!mounted || createdId == null) {
                          return;
                        }
                        setState(() => _selectedAccountId = createdId);
                      },
                      child: const Text('＋ Crear'),
                    ),
                  ],
                ),
              ),
            ] else if (!_loadingOptions) ...[
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
                              setState(() => _selectedAccountId = account.id);
                              controller.clearFieldError('account_id');
                              setState(() {
                                _incomeFieldErrors = Map.from(
                                  _incomeFieldErrors,
                                )..remove('account_id');
                              });
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
                              ? (isIncome
                                    ? palette.incomeSoft
                                    : palette.errorSoft)
                              : palette.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedAccountId == account.id
                                ? (isIncome ? palette.income : palette.discard)
                                : palette.line,
                            width: _selectedAccountId == account.id ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _accountIcon(account.type),
                              size: 15,
                              color: _selectedAccountId == account.id
                                  ? (isIncome
                                        ? palette.income
                                        : palette.discard)
                                  : palette.muted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              account.name,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: _selectedAccountId == account.id
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: _selectedAccountId == account.id
                                    ? (isIncome
                                          ? palette.income
                                          : palette.discard)
                                    : palette.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Chip para agregar otra cuenta rápidamente
                  ActionChip(
                    key: const Key('expense-create-new-account-chip'),
                    avatar: const Icon(FinanceIcons.add, size: 16),
                    label: const Text('Nueva cuenta'),
                    onPressed: formEnabled
                        ? () async {
                            final createdId = await context.push<int>(
                              '/quick-add/account',
                            );
                            await _loadOptions();
                            if (!mounted || createdId == null) {
                              return;
                            }
                            setState(() => _selectedAccountId = createdId);
                          }
                        : null,
                  ),
                ],
              ),
            ],
            if (!isIncome) ...[
              const SizedBox(height: 16),
              Text(
                'Categoría',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: palette.muted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InkWell(
                    key: const Key('expense-category-chip-none'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: formEnabled
                        ? () {
                            setState(() => _selectedCategoryId = null);
                            controller.clearFieldError('category_id');
                          }
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedCategoryId == null
                            ? palette.errorSoft
                            : palette.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedCategoryId == null
                              ? palette.discard
                              : palette.line,
                          width: _selectedCategoryId == null ? 1.5 : 1.0,
                        ),
                      ),
                      child: Text(
                        'Sin categoría',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: _selectedCategoryId == null
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: _selectedCategoryId == null
                              ? palette.discard
                              : palette.text,
                        ),
                      ),
                    ),
                  ),
                  for (final cat in _categories)
                    InkWell(
                      key: Key('expense-category-chip-${cat.id}'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: formEnabled
                          ? () {
                              setState(() => _selectedCategoryId = cat.id);
                              controller.clearFieldError('category_id');
                            }
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedCategoryId == cat.id
                              ? palette.errorSoft
                              : palette.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedCategoryId == cat.id
                                ? palette.discard
                                : palette.line,
                            width: _selectedCategoryId == cat.id ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              cat.icon.value,
                              size: 15,
                              color: _selectedCategoryId == cat.id
                                  ? palette.discard
                                  : cat.color.value,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cat.name,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: _selectedCategoryId == cat.id
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: _selectedCategoryId == cat.id
                                    ? palette.discard
                                    : palette.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ActionChip(
                    key: const Key('expense-create-new-category-chip'),
                    avatar: const Icon(FinanceIcons.add, size: 16),
                    label: const Text('Nueva categoría'),
                    onPressed: formEnabled
                        ? () async {
                            await context.push('/quick-add/category');
                            _loadOptions();
                          }
                        : null,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // =================== DETALLES OPCIONALES COLAPSADOS ===================
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
                      'Detalles opcionales (fecha, nota)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: palette.muted,
                      ),
                    ),
                    Icon(
                      _showOptionalDetails
                          ? FinanceIcons.keyboardArrowUp
                          : FinanceIcons.keyboardArrowDown,
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
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        key: const Key('expense-create-date-field'),
                        onTap: formEnabled ? _pickDate : null,
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Fecha',
                            suffixIcon: Icon(
                              FinanceIcons.calendarTodayOutlined,
                            ),
                          ),
                          child: Text(
                            '${_occurredAt.year}-${_occurredAt.month.toString().padLeft(2, '0')}-${_occurredAt.day.toString().padLeft(2, '0')}',
                            style: TextStyle(color: palette.text),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('expense-create-note-field'),
                        controller: _noteController,
                        enabled: formEnabled,
                        maxLength: 5000,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Nota (opcional)',
                          hintText: 'Observación o motivo...',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            const SizedBox(height: 20),

            // =================== BOTÓN DE GUARDAR ===================
            FilledButton.icon(
              key: isIncome
                  ? const Key('income-create-submit-button')
                  : const Key('expense-create-submit-button'),
              onPressed: formEnabled ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor: isIncome ? palette.income : palette.discard,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(FinanceIcons.check, size: 20),
              label: Text(
                isIncome ? 'Registrar ingreso' : 'Registrar gasto',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
