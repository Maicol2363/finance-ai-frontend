import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/management_page_scaffold.dart';
import '../../../core/widgets/manage_widgets.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/formatters/catalog_labels.dart';
import '../application/accounts_controller.dart';
import '../application/accounts_state.dart';
import '../domain/account_models.dart';

class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({
    this.accountId,
    this.returnToPrevious = false,
    super.key,
  });

  final int? accountId;

  /// When `true` the form was opened from another flow (manual expense/income
  /// capture) and must return to it instead of the accounts list.
  final bool returnToPrevious;

  bool get isEditing => accountId != null;

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _nameController = TextEditingController();
  final _openingBalanceController = TextEditingController(text: '0');
  final _nameFocus = FocusNode();
  final _openingBalanceFocus = FocusNode();
  AccountType? _selectedType;
  String? _selectedCurrency;
  bool _initialized = false;
  bool _initializationScheduled = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      final controller = ref.read(accountsControllerProvider.notifier);
      controller.clearMutationFeedback();
      final state = ref.read(accountsControllerProvider);
      if (state.listStatus == AccountsLoadStatus.initial ||
          state.result == null) {
        controller.load();
      }
      if (widget.accountId case final accountId?) {
        controller.loadDetail(accountId);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _openingBalanceController.dispose();
    _nameFocus.dispose();
    _openingBalanceFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountsControllerProvider);
    final controller = ref.read(accountsControllerProvider.notifier);
    final options = state.result;
    final editAccount = widget.accountId == state.detailAccountId
        ? state.detailAccount
        : null;
    _scheduleInitialization(options, editAccount);

    final waitingForEdit =
        widget.isEditing &&
        (state.detailStatus == AccountDetailStatus.initial ||
            state.detailStatus == AccountDetailStatus.loading);
    final waitingForOptions =
        options == null && state.listStatus != AccountsLoadStatus.failure;
    final canShowForm = _initialized && options != null;

    return PopScope(
      canPop: !state.isSaving,
      child: ManagementPageScaffold(
        title: widget.isEditing ? 'Editar cuenta' : 'Nueva cuenta',
        subtitle: 'Nombre, tipo, moneda y saldo',
        leading: HeaderIconButton(
          icon: FinanceIcons.arrowBack,
          tooltip: widget.returnToPrevious
              ? 'Volver al registro'
              : 'Volver a cuentas',
          onPressed: state.isSaving ? null : _goBack,
        ),
        actions: const [ThemeToggleButton()],
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            if (waitingForEdit || waitingForOptions) ...[
              Semantics(
                liveRegion: true,
                label: 'Cargando formulario de cuenta',
                child: const LinearProgressIndicator(),
              ),
              const SizedBox(height: 16),
            ],
            if (state.listDiagnostic case final diagnostic?) ...[
              ErrorDiagnosticPanel(diagnostic: diagnostic),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: controller.load,
                icon: const Icon(FinanceIcons.refresh),
                label: const Text('Reintentar opciones de cuenta'),
              ),
              const SizedBox(height: 16),
            ],
            if (widget.isEditing)
              if (state.detailDiagnostic case final diagnostic?) ...[
                ErrorDiagnosticPanel(diagnostic: diagnostic),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => controller.loadDetail(widget.accountId!),
                  icon: const Icon(FinanceIcons.refresh),
                  label: const Text('Reintentar detalles de la cuenta'),
                ),
                const SizedBox(height: 16),
              ],
            if (canShowForm)
              _buildForm(context, state, options, editAccount, controller),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    AccountsState state,
    AccountListResult options,
    Account? editAccount,
    AccountsController controller,
  ) {
    final currencyLocked =
        widget.isEditing && editAccount != null && editAccount.currencyIsLocked;
    final formEnabled = !state.isSaving && !state.requiresMutationReview;
    return ManagementFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.mutationDiagnostic case final diagnostic?) ...[
            ErrorDiagnosticPanel(diagnostic: diagnostic),
            const SizedBox(height: 16),
          ],
          TextField(
            key: const Key('account-name-field'),
            controller: _nameController,
            focusNode: _nameFocus,
            enabled: formEnabled,
            textInputAction: TextInputAction.next,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: 'Nombre de la cuenta',
              hintText: 'Efectivo, Nequi, Bancolombia…',
              errorText: _firstError(state, 'name'),
            ),
            onChanged: (_) => controller.clearFieldError('name'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<AccountType>(
            key: const Key('account-type-field'),
            initialValue: _selectedType,
            decoration: InputDecoration(
              labelText: 'Tipo de cuenta',
              errorText: _firstError(state, 'type'),
            ),
            items: options.accountTypes
                .map(
                  (type) =>
                      DropdownMenuItem(value: type, child: Text(type.label)),
                )
                .toList(growable: false),
            onChanged: formEnabled
                ? (value) {
                    setState(() => _selectedType = value);
                    controller.clearFieldError('type');
                  }
                : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const Key('account-currency-field'),
            initialValue: _selectedCurrency,
            decoration: InputDecoration(
              labelText: 'Moneda',
              helperText: currencyLocked
                  ? 'La moneda se bloquea cuando la cuenta ya tiene movimientos confirmados.'
                  : 'La sugerencia es editable y no modifica cuentas guardadas.',
              helperMaxLines: 2,
              errorText: _firstError(state, 'currency_code'),
            ),
            items: options.supportedCurrencies
                .map(
                  (currency) => DropdownMenuItem(
                    value: currency.code,
                    child: Text(
                      '${currency.code} · ${CatalogLabels.display(currency.name)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: formEnabled && !currencyLocked
                ? (value) {
                    setState(() => _selectedCurrency = value);
                    controller.clearFieldError('currency_code');
                  }
                : null,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('account-opening-balance-field'),
            controller: _openingBalanceController,
            focusNode: _openingBalanceFocus,
            enabled: formEnabled,
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: true,
            ),
            inputFormatters: const [MoneyInputFormatter(allowNegative: true)],
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Saldo inicial',
              helperText: 'Usa signo menos para deuda. Separa miles con punto.',
              helperMaxLines: 2,
              errorText: _firstError(state, 'opening_balance'),
            ),
            onChanged: (_) => controller.clearFieldError('opening_balance'),
            onSubmitted: (_) {
              if (formEnabled) {
                _submit();
              }
            },
          ),
          const SizedBox(height: 28),
          FilledButton(
            key: const Key('account-save-button'),
            onPressed: formEnabled ? _submit : null,
            child: state.isSaving
                ? Semantics(
                    liveRegion: true,
                    label: 'Guardando cuenta',
                    child: const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                : Text(widget.isEditing ? 'Guardar cambios' : 'Guardar cuenta'),
          ),
          if (state.requiresMutationReview) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: controller.resolveUncertainMutation,
              icon: const Icon(FinanceIcons.sync),
              label: const Text('Actualizar cuentas antes de reintentar'),
            ),
          ],
        ],
      ),
    );
  }

  void _scheduleInitialization(
    AccountListResult? options,
    Account? editAccount,
  ) {
    if (_initialized || _initializationScheduled || options == null) {
      return;
    }
    if (widget.isEditing && editAccount == null) {
      return;
    }
    _initializationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (editAccount != null) {
        _nameController.text = editAccount.name;
        _openingBalanceController.text = MoneyFormatter.formatInputAmount(
          editAccount.openingBalance.minorUnits,
        );
        _selectedType = editAccount.type;
        _selectedCurrency = editAccount.currency.code;
      } else {
        _selectedType = options.accountTypes.contains(AccountType.cash)
            ? AccountType.cash
            : options.accountTypes.first;
        _selectedCurrency = options.suggestedCurrencyCode;
      }
      setState(() {
        _initialized = true;
        _initializationScheduled = false;
      });
    });
  }

  String? _firstError(AccountsState state, String field) {
    final errors = state.fieldErrors[field];
    return errors == null || errors.isEmpty ? null : errors.first;
  }

  Future<void> _submit() async {
    final controller = ref.read(accountsControllerProvider.notifier);
    final accountId = widget.accountId;
    final AccountMutationOutcome outcome;
    if (accountId != null) {
      outcome = await controller.update(
        accountId: accountId,
        name: _nameController.text,
        type: _selectedType,
        currencyCode: _selectedCurrency,
        openingBalanceInput: MoneyFormatter.clean(
          _openingBalanceController.text,
        ),
      );
    } else {
      outcome = await controller.create(
        name: _nameController.text,
        type: _selectedType,
        currencyCode: _selectedCurrency,
        openingBalanceInput: MoneyFormatter.clean(
          _openingBalanceController.text,
        ),
      );
    }
    if (!mounted) {
      return;
    }
    if (outcome == AccountMutationOutcome.success) {
      final saved = ref.read(accountsControllerProvider).lastMutationAccount;
      if (widget.returnToPrevious && context.canPop()) {
        context.pop(saved?.id);
        return;
      }
      if (widget.isEditing) {
        if (context.canPop()) {
          context.pop(saved?.id);
        } else if (saved != null) {
          context.go('/accounts/${saved.id}');
        } else {
          context.go('/accounts');
        }
        return;
      }
      if (saved != null) {
        context.replace('/accounts/${saved.id}');
      } else {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/accounts');
        }
      }
      return;
    }
    if (outcome == AccountMutationOutcome.invalid ||
        outcome == AccountMutationOutcome.failure) {
      _focusFirstError(ref.read(accountsControllerProvider));
    }
  }

  void _focusFirstError(AccountsState state) {
    if (state.fieldErrors.containsKey('name')) {
      _nameFocus.requestFocus();
    } else if (state.fieldErrors.containsKey('opening_balance')) {
      _openingBalanceFocus.requestFocus();
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    if (widget.accountId case final accountId?) {
      context.go('/accounts/$accountId');
    } else {
      context.go('/accounts');
    }
  }
}
