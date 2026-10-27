import 'dart:async';

import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/formatters/date_labels.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/management_page_scaffold.dart';
import '../../../core/widgets/manage_widgets.dart';
import '../../accounts/application/accounts_controller.dart';
import '../../accounts/application/accounts_state.dart';
import '../../accounts/domain/account_models.dart';
import '../../expenses/application/history_controller.dart';
import '../application/transfer_controller.dart';
import '../application/transfer_state.dart';

class TransferFormScreen extends ConsumerStatefulWidget {
  const TransferFormScreen({super.key});

  @override
  ConsumerState<TransferFormScreen> createState() => _TransferFormScreenState();
}

class _TransferFormScreenState extends ConsumerState<TransferFormScreen> {
  final _sourceAmountController = TextEditingController();
  final _destinationAmountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sourceAmountFocus = FocusNode();
  int? _sourceAccountId;
  int? _destinationAccountId;
  DateTime _date = DateTime.now().toUtc();

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      ref.read(transferControllerProvider.notifier).clearMutationFeedback();
      final accounts = ref.read(accountsControllerProvider);
      if (accounts.listStatus == AccountsLoadStatus.initial) {
        ref.read(accountsControllerProvider.notifier).load();
      }
    });
  }

  @override
  void dispose() {
    _sourceAmountController.dispose();
    _destinationAmountController.dispose();
    _descriptionController.dispose();
    _sourceAmountFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transferControllerProvider);
    final controller = ref.read(transferControllerProvider.notifier);
    final accountsState = ref.watch(accountsControllerProvider);
    final List<Account> accounts = [
      for (final account in accountsState.result?.accounts ?? const <Account>[])
        if (account.isActive) account,
    ];
    final formEnabled = !state.isSaving && !state.requiresMutationReview;
    final optionsFailed = accountsState.listDiagnostic != null;
    final sourceCurrency = _currencyOf(accounts, _sourceAccountId);
    final destinationCurrency = _currencyOf(accounts, _destinationAccountId);
    final crossCurrency =
        sourceCurrency != null &&
        destinationCurrency != null &&
        sourceCurrency != destinationCurrency;

    return PopScope(
      canPop: !state.isSaving,
      child: ManagementPageScaffold(
        title: 'Transferir entre cuentas',
        subtitle: 'Origen, destino y monto',
        leading: HeaderIconButton(
          icon: FinanceIcons.arrowBack,
          tooltip: 'Volver a cuentas',
          onPressed: state.isSaving
              ? null
              : () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/accounts');
                  }
                },
        ),
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            ManagementFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Mueve dinero entre tus cuentas. En la misma moneda viaja el mismo monto; con monedas distintas indica cuánto sale y cuánto llega.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  if (state.mutationDiagnostic case final diagnostic?) ...[
                    ErrorDiagnosticPanel(diagnostic: diagnostic),
                    const SizedBox(height: 16),
                  ],
                  if (optionsFailed) ...[
                    ErrorDiagnosticPanel(
                      diagnostic: accountsState.listDiagnostic!,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(accountsControllerProvider.notifier).load(),
                      icon: const Icon(FinanceIcons.refresh),
                      label: const Text('Reintentar cuentas'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  DropdownButtonFormField<int>(
                    key: const Key('transfer-source-field'),
                    initialValue: _containedOrNull([
                      for (final account in accounts) account.id,
                    ], _sourceAccountId),
                    decoration: InputDecoration(
                      labelText: 'Cuenta origen',
                      helperText: 'De dónde sale el dinero.',
                      errorText: _firstError(state, 'source_account_id'),
                    ),
                    items: [
                      for (final account in accounts)
                        DropdownMenuItem(
                          value: account.id,
                          child: Text(
                            '${account.name} · ${account.currency.code}',
                          ),
                        ),
                    ],
                    onChanged: formEnabled && !optionsFailed
                        ? (value) {
                            setState(() {
                              _sourceAccountId = value;
                              _dropStaleDestinationAmount(accounts);
                            });
                            controller.clearFieldError('source_account_id');
                            controller.clearFieldError(
                              'destination_account_id',
                            );
                            controller.clearFieldError('source_amount');
                          }
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    key: const Key('transfer-destination-field'),
                    initialValue: _containedOrNull([
                      for (final account in accounts) account.id,
                    ], _destinationAccountId),
                    decoration: InputDecoration(
                      labelText: 'Cuenta destino',
                      helperText: 'A dónde llega el dinero.',
                      errorText: _firstError(state, 'destination_account_id'),
                    ),
                    items: [
                      for (final account in accounts)
                        DropdownMenuItem(
                          value: account.id,
                          child: Text(
                            '${account.name} · ${account.currency.code}',
                          ),
                        ),
                    ],
                    onChanged: formEnabled && !optionsFailed
                        ? (value) {
                            setState(() {
                              _destinationAccountId = value;
                              _dropStaleDestinationAmount(accounts);
                            });
                            controller.clearFieldError(
                              'destination_account_id',
                            );
                          }
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('transfer-source-amount-field'),
                    controller: _sourceAmountController,
                    focusNode: _sourceAmountFocus,
                    enabled: formEnabled && !optionsFailed,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText:
                          'Monto que sale${sourceCurrency == null ? '' : ' ($sourceCurrency)'}',
                      helperText: _availableBalanceHint(accounts),
                      errorText: _firstError(state, 'source_amount'),
                    ),
                    onChanged: (_) =>
                        controller.clearFieldError('source_amount'),
                  ),
                  if (crossCurrency) ...[
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('transfer-destination-amount-field'),
                      controller: _destinationAmountController,
                      enabled: formEnabled && !optionsFailed,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Monto que llega ($destinationCurrency)',
                        helperText: 'Monedas distintas: indica cuánto llega al otro lado.',
                        errorText: _firstError(state, 'destination_amount'),
                      ),
                      onChanged: (_) =>
                          controller.clearFieldError('destination_amount'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('transfer-description-field'),
                    controller: _descriptionController,
                    enabled: formEnabled && !optionsFailed,
                    textInputAction: TextInputAction.done,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                  ),
                  const SizedBox(height: 16),
                  const Text('Fecha'),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(_date),
                    key: const Key('transfer-date-value'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('transfer-date-button'),
                    onPressed: formEnabled && !optionsFailed ? _pickDate : null,
                    icon: const Icon(FinanceIcons.calendarTodayOutlined),
                    label: const Text('Cambiar fecha'),
                  ),
                  if (_firstError(state, 'date') case final error?) ...[
                    const SizedBox(height: 4),
                    Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('transfer-save-button'),
                    onPressed: formEnabled && !optionsFailed ? _submit : null,
                    child: state.isSaving
                        ? Semantics(
                            liveRegion: true,
                            label: 'Guardando transferencia',
                            child: const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            ),
                          )
                        : const Text('Transferir'),
                  ),
                  if (state.requiresMutationReview) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: controller.resolveUncertainMutation,
                      icon: const Icon(FinanceIcons.sync),
                      label: const Text(
                        'Actualizar cuentas antes de reintentar',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.toUtc(),
      firstDate: DateTime.utc(2000),
      lastDate: DateTime.now().toUtc(),
    );
    if (picked != null && mounted) {
      setState(
        () => _date = DateTime.utc(picked.year, picked.month, picked.day),
      );
    }
  }

  String _formatDate(DateTime value) {
    return DateLabels.calendarDate(value);
  }

  String? _currencyOf(List<Account> accounts, int? accountId) {
    if (accountId == null) {
      return null;
    }
    for (final account in accounts) {
      if (account.id == accountId) {
        return account.currency.code;
      }
    }
    return null;
  }

  int? _containedOrNull(List<int> ids, int? selected) =>
      selected != null && ids.contains(selected) ? selected : null;

  /// Discards a typed destination amount when the picked pair stops being
  /// cross-currency, so a hidden stale value can never be submitted.
  void _dropStaleDestinationAmount(List<Account> accounts) {
    final sourceCurrency = _currencyOf(accounts, _sourceAccountId);
    final destinationCurrency = _currencyOf(accounts, _destinationAccountId);
    if (sourceCurrency == null ||
        destinationCurrency == null ||
        sourceCurrency == destinationCurrency) {
      _destinationAmountController.clear();
    }
  }

  String _availableBalanceHint(List<Account> accounts) {
    for (final account in accounts) {
      if (account.id == _sourceAccountId) {
        final available = account.balance.formatWithCurrency(
          account.currency.code,
        );
        return 'Disponible: $available. Monto positivo con hasta dos decimales.';
      }
    }
    return 'Monto positivo con hasta dos decimales.';
  }

  String? _firstError(TransferState state, String field) {
    final errors = state.fieldErrors[field];
    return errors == null || errors.isEmpty ? null : errors.first;
  }

  Future<void> _submit() async {
    final controller = ref.read(transferControllerProvider.notifier);
    final rawDestination = _destinationAmountController.text.trim();
    final outcome = await controller.create(
      sourceAccountId: _sourceAccountId,
      destinationAccountId: _destinationAccountId,
      sourceAmountInput: _sourceAmountController.text,
      destinationAmountInput: rawDestination.isEmpty ? null : rawDestination,
      date: _date,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text,
    );
    if (!mounted) {
      return;
    }
    if (outcome == TransferMutationOutcome.success) {
      unawaited(ref.read(historyControllerProvider.notifier).load());
      await ref.read(accountsControllerProvider.notifier).load();
      if (!mounted) {
        return;
      }
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/accounts');
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transferencia guardada.')));
      return;
    }
    if (outcome == TransferMutationOutcome.invalid ||
        outcome == TransferMutationOutcome.failure) {
      _focusFirstError(ref.read(transferControllerProvider));
    }
  }

  void _focusFirstError(TransferState state) {
    if (state.fieldErrors.containsKey('source_account_id')) {
      return;
    } else if (state.fieldErrors.containsKey('source_amount')) {
      _sourceAmountFocus.requestFocus();
    }
  }
}
