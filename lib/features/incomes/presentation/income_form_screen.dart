import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic.dart';
import '../../../core/formatters/catalog_labels.dart';
import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/management_page_scaffold.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../accounts/domain/account_models.dart';
import '../../auth/session/application/auth_session_controller.dart';
import '../../income_sources/data/income_sources_repository.dart';
import '../../income_sources/domain/income_source_models.dart';
import '../data/incomes_repository.dart';
import '../domain/income_models.dart';

class IncomeFormOptions {
  const IncomeFormOptions({required this.accounts, required this.sources});

  final List<Account> accounts;
  final List<IncomeSource> sources;
}

final incomeFormOptionsProvider =
    Provider<Future<IncomeFormOptions> Function()>((ref) {
      return () async {
        final accounts = await ref
            .read(accountsRepositoryProvider)
            .list(includeInactive: true);
        final sources = await ref
            .read(authSessionControllerProvider.notifier)
            .runProtected(
              (access) => ref
                  .read(incomeSourcesRepositoryProvider)
                  .list(accessCredential: access),
            );
        return IncomeFormOptions(accounts: accounts.accounts, sources: sources);
      };
    });

class IncomeFormScreen extends ConsumerStatefulWidget {
  const IncomeFormScreen({this.incomeId, super.key});

  final int? incomeId;

  @override
  ConsumerState<IncomeFormScreen> createState() => _IncomeFormScreenState();
}

class _IncomeFormScreenState extends ConsumerState<IncomeFormScreen> {
  final _amount = TextEditingController();
  final _date = TextEditingController();
  final _description = TextEditingController();
  List<Account> _accounts = const [];
  List<IncomeSource> _sources = const [];
  int? _accountId;
  int? _sourceId;
  bool _loading = true;
  bool _saving = false;
  bool _uncertain = false;
  Map<String, List<String>> _fieldErrors = const {};
  ErrorDiagnostic? _diagnostic;

  @override
  void initState() {
    super.initState();
    _date.text = incomeDateWire(DateTime.now());
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _amount.dispose();
    _date.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _diagnostic = null;
    });
    try {
      final options = await ref.read(incomeFormOptionsProvider)();
      final income = widget.incomeId == null
          ? null
          : await ref.read(incomesRepositoryProvider).get(widget.incomeId!);
      if (!mounted) return;
      setState(() {
        _accounts = options.accounts;
        _sources = options.sources;
        _accountId =
            income?.accountId ??
            options.accounts
                .where((account) => account.isActive)
                .firstOrNull
                ?.id;
        _sourceId = income?.incomeSourceId;
        if (income != null) {
          _amount.text = MoneyFormatter.formatInputAmount(
            income.amount.minorUnits,
          );
          _date.text = incomeDateWire(income.date);
          _description.text = income.description ?? '';
        }
        _loading = false;
        _uncertain = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _diagnostic = ErrorDiagnostic.capture(
          code: 'income_options_unavailable',
          operation: 'load_income_form',
          userMessage:
              'No pudimos cargar las cuentas y fuentes. Inténtalo de nuevo.',
          technicalReason: 'form_options_failure',
        );
      });
    }
  }

  Future<void> _save() async {
    if (_saving || _uncertain) return;
    final errors = <String, List<String>>{};
    final account = _accounts
        .where((item) => item.id == _accountId)
        .firstOrNull;
    if (account == null || !account.isActive) {
      errors['account_id'] = ['Selecciona una cuenta activa.'];
    }
    final amount = MoneyAmount.tryParseUserInput(
      MoneyFormatter.clean(_amount.text),
    );
    if (amount == null || amount.minorUnits <= 0) {
      errors['amount'] = [
        'Ingresa un monto positivo con máximo dos decimales.',
      ];
    }
    DateTime? date;
    try {
      date = parseIncomeDate(_date.text.trim());
    } on FormatException {
      errors['date'] = ['Usa una fecha válida en formato AAAA-MM-DD.'];
    }
    if (_description.text.trim().length > 500) {
      errors['description'] = [
        'La descripción debe tener 500 caracteres o menos.',
      ];
    }
    if (errors.isNotEmpty) {
      setState(() {
        _fieldErrors = errors;
        _diagnostic = ErrorDiagnostic.capture(
          code: 'income_invalid',
          operation: 'save_income',
          userMessage: 'Corrige los campos indicados.',
          technicalReason: 'client_validation',
        );
      });
      return;
    }
    setState(() {
      _saving = true;
      _fieldErrors = const {};
      _diagnostic = null;
    });
    final command = IncomeWriteCommand(
      accountId: account!.id,
      amount: amount!,
      date: date!,
      description: _description.text,
      incomeSourceId: _sourceId,
    );
    try {
      final repository = ref.read(incomesRepositoryProvider);
      final saved = widget.incomeId == null
          ? await repository.create(command)
          : await repository.update(widget.incomeId!, command);
      if (!mounted) return;
      ref.read(incomeRevisionProvider.notifier).changed();
      if (widget.incomeId != null && context.canPop()) {
        context.pop();
      } else {
        context.go('/incomes/${saved.id}');
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ingreso guardado.')));
    } on IncomeFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _uncertain = failure.outcomeUncertain;
        _fieldErrors = failure.fieldErrors;
        _diagnostic = ErrorDiagnostic.capture(
          code: failure.code,
          operation: 'save_income',
          userMessage: failure.userMessage,
          correlationId: failure.correlationId,
          technicalReason: failure.technicalReason,
        );
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _diagnostic = ErrorDiagnostic.capture(
          code: 'unexpected_client_error',
          operation: 'save_income',
          userMessage: 'No pudimos guardar el ingreso. Inténtalo de nuevo.',
          technicalReason: 'unclassified_client_failure',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => ManagementPageScaffold(
    title: widget.incomeId == null ? 'Nuevo ingreso' : 'Editar ingreso',
    maxWidth: 680,
    leading: HeaderIconButton(
      icon: FinanceIcons.arrowBack,
      tooltip: 'Volver',
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(
            widget.incomeId == null
                ? '/incomes'
                : '/incomes/${widget.incomeId}',
          );
        }
      },
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: EdgeInsets.zero,
            children: [
              if (_diagnostic != null) ...[
                ErrorDiagnosticPanel(diagnostic: _diagnostic!),
                const SizedBox(height: 16),
              ],
              if (_accounts.isEmpty)
                const Text(
                  'Crea una cuenta activa antes de registrar ingresos.',
                ),
              DropdownButtonFormField<int>(
                key: const Key('income-account-field'),
                initialValue: _accountId,
                decoration: InputDecoration(
                  labelText: 'Cuenta',
                  errorText: _fieldErrors['account_id']?.firstOrNull,
                ),
                items: _accounts
                    .map(
                      (account) => DropdownMenuItem(
                        value: account.id,
                        child: Text(
                          '${account.name} (${account.currency.code})${account.isActive ? '' : ' · inactiva'}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _accountId = value),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('income-amount-field'),
                controller: _amount,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Monto',
                  errorText: _fieldErrors['amount']?.firstOrNull,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('income-date-field'),
                controller: _date,
                enabled: !_saving,
                decoration: InputDecoration(
                  labelText: 'Fecha',
                  hintText: 'AAAA-MM-DD',
                  errorText: _fieldErrors['date']?.firstOrNull,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: const Key('income-source-field'),
                initialValue: _sourceId ?? 0,
                decoration: InputDecoration(
                  labelText: 'Fuente (opcional)',
                  errorText: _fieldErrors['income_source_id']?.firstOrNull,
                ),
                items: [
                  const DropdownMenuItem(value: 0, child: Text('Sin fuente')),
                  ..._sources.map(
                    (source) => DropdownMenuItem(
                      value: source.id,
                      child: Text(CatalogLabels.display(source.name)),
                    ),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (value) =>
                          setState(() => _sourceId = value == 0 ? null : value),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('income-description-field'),
                controller: _description,
                enabled: !_saving,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Descripción (opcional)',
                  errorText: _fieldErrors['description']?.firstOrNull,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('income-save-button'),
                onPressed: _saving || _uncertain || _accounts.isEmpty
                    ? null
                    : _save,
                child: Text(_saving ? 'Guardando…' : 'Guardar ingreso'),
              ),
              if (_uncertain)
                OutlinedButton(
                  onPressed: () => context.go('/incomes'),
                  child: const Text(
                    'Revisar ingresos antes de volver a intentar',
                  ),
                ),
              if (_diagnostic != null && !_uncertain)
                OutlinedButton(
                  onPressed: _load,
                  child: const Text('Actualizar opciones'),
                ),
            ],
          ),
  );
}
