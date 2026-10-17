import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../../core/formatters/catalog_labels.dart';
import '../../../../core/formatters/date_labels.dart';
import '../../../../core/formatters/money_formatter.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/time/clock_provider.dart';
import '../../../accounts/application/accounts_controller.dart';
import '../../../accounts/domain/account_models.dart';
import '../../../categories/application/categories_controller.dart';
import '../../../income_sources/presentation/income_sources_controller.dart';
import '../../application/text_capture_controller.dart';
import '../../application/text_capture_state.dart';
import '../../domain/text_capture_models.dart';
import 'chat_bubbles.dart';

/// The values of a proposal while the user looks at or edits them.
class ProposalDraft {
  ProposalDraft({
    required this.intent,
    required this.amountText,
    required this.description,
    required this.accountId,
    required this.destinationId,
    required this.destinationAmountText,
    required this.categoryId,
    required this.incomeSourceId,
    required this.date,
  });

  factory ProposalDraft.from(TextProposal proposal) {
    String money(String? apiValue) {
      if (apiValue == null) return '';
      try {
        return MoneyFormatter.formatInputAmount(
          MoneyAmount.parseApi(apiValue).minorUnits,
        );
      } on FormatException {
        return '';
      }
    }

    final date = proposal.date ?? DateTime.now();
    return ProposalDraft(
      intent: proposal.intent ?? CaptureIntent.expense,
      amountText: money(proposal.amount),
      description: proposal.description ?? '',
      accountId: proposal.account?.id,
      destinationId: proposal.destinationAccount?.id,
      destinationAmountText: money(proposal.destinationAmount),
      categoryId: proposal.category?.id,
      incomeSourceId: proposal.incomeSource?.id,
      date: DateTime(date.year, date.month, date.day),
    );
  }

  CaptureIntent intent;
  String amountText;
  String description;
  int? accountId;
  int? destinationId;
  String destinationAmountText;
  int? categoryId;
  int? incomeSourceId;
  DateTime date;

  static MoneyAmount? parseMoney(String text) {
    final cleaned = MoneyFormatter.clean(text);
    if (cleaned.isEmpty) return null;
    final parsed = MoneyAmount.tryParseUserInput(cleaned);
    return parsed == null || parsed.minorUnits <= 0 ? null : parsed;
  }
}

/// Review card for a proposal: compact by default, editable in place.
///
/// Accept is one tap and sends exactly what is on screen; the server runs the
/// same validated operation as the manual forms.
class ProposalCard extends ConsumerStatefulWidget {
  const ProposalCard({super.key, required this.entry});

  final ProposalEntry entry;

  @override
  ConsumerState<ProposalCard> createState() => _ProposalCardState();
}

class _ProposalCardState extends ConsumerState<ProposalCard> {
  late ProposalDraft _draft = ProposalDraft.from(widget.entry.proposal);
  late final _amount = TextEditingController(text: _draft.amountText);
  late final _description = TextEditingController(text: _draft.description);
  late final _destinationAmount = TextEditingController(
    text: _draft.destinationAmountText,
  );
  bool _editing = false;
  final Map<String, String> _errors = {};

  TextProposal get _proposal => widget.entry.proposal;

  @override
  void initState() {
    super.initState();
    // A card that shows a refined proposal is built again with a new revision,
    // so the editing controllers always start from the server's values.
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _destinationAmount.dispose();
    super.dispose();
  }

  List<Account> get _accounts {
    final all =
        ref.read(accountsControllerProvider).result?.accounts ??
        const <Account>[];
    return all.where((account) => account.isActive).toList(growable: false);
  }

  Account? _account(int? id) {
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  String _accountName(int? id, AccountRef? fallback) =>
      _account(id)?.name ?? (fallback?.id == id ? fallback?.name : null) ?? '—';

  String _currencyOf(int? id, AccountRef? fallback) =>
      _account(id)?.currency.code ??
      (fallback?.id == id ? fallback?.currencyCode : null) ??
      _proposal.currencyCode ??
      '';

  void _syncDraftFromFields() {
    _draft
      ..amountText = _amount.text
      ..description = _description.text
      ..destinationAmountText = _destinationAmount.text;
  }

  bool _validate() {
    _syncDraftFromFields();
    _errors.clear();
    if (ProposalDraft.parseMoney(_draft.amountText) == null) {
      _errors['amount'] = 'Escribe un monto mayor que cero.';
    }
    if (_draft.accountId == null) {
      _errors['account'] = 'Elige una cuenta.';
    }
    if (_draft.intent == CaptureIntent.transfer) {
      if (_draft.destinationId == null) {
        _errors['destination'] = 'Elige la cuenta de destino.';
      } else if (_draft.destinationId == _draft.accountId) {
        _errors['destination'] = 'Elige una cuenta distinta al origen.';
      } else if (_needsDestinationAmount &&
          ProposalDraft.parseMoney(_draft.destinationAmountText) == null) {
        _errors['destinationAmount'] = 'Indica cuánto llegó.';
      }
    }
    return _errors.isEmpty;
  }

  bool get _needsDestinationAmount {
    if (_draft.intent != CaptureIntent.transfer ||
        _draft.accountId == null ||
        _draft.destinationId == null) {
      return false;
    }
    return _currencyOf(_draft.accountId, _proposal.account) !=
        _currencyOf(_draft.destinationId, _proposal.destinationAccount);
  }

  TextProposalConfirmCommand _command() {
    final amount = ProposalDraft.parseMoney(_draft.amountText)!;
    final isTransfer = _draft.intent == CaptureIntent.transfer;
    return TextProposalConfirmCommand(
      intent: _draft.intent,
      amount: amount.toApiString(),
      date: _draft.date,
      accountId: _draft.accountId!,
      description: _draft.description,
      destinationAccountId: isTransfer ? _draft.destinationId : null,
      destinationAmount: isTransfer && _needsDestinationAmount
          ? ProposalDraft.parseMoney(_draft.destinationAmountText)
                ?.toApiString()
          : null,
      categoryId: _draft.categoryId,
      incomeSourceId: _draft.incomeSourceId,
    );
  }

  void _confirm() {
    if (!_validate()) {
      setState(() => _editing = true);
      return;
    }
    setState(() => _editing = false);
    ref
        .read(textCaptureControllerProvider.notifier)
        .confirm(widget.entry, _command());
  }

  void _saveEdit() {
    if (_validate()) {
      setState(() => _editing = false);
    } else {
      setState(() {});
    }
  }

  void _cancelEdit() {
    setState(() {
      _draft = ProposalDraft.from(_proposal);
      _amount.text = _draft.amountText;
      _description.text = _draft.description;
      _destinationAmount.text = _draft.destinationAmountText;
      _errors.clear();
      _editing = false;
    });
  }

  Future<void> _pickDate() async {
    final now = ref.read(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.date.isAfter(today) ? today : _draft.date,
      firstDate: DateTime(2000),
      lastDate: today,
      helpText: 'Fecha del movimiento',
    );
    if (picked != null && mounted) {
      setState(() => _draft.date = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Rebuild when the catalogs arrive; the helpers below only read them.
    ref
      ..watch(accountsControllerProvider)
      ..watch(categoriesControllerProvider)
      ..watch(incomeSourcesControllerProvider);
    final isIncome = _draft.intent == CaptureIntent.income;
    final accent = isIncome ? palette.income : palette.primary;
    final entry = widget.entry;
    final busy = entry.isConfirming;
    return AssistantRow(
      child: Semantics(
        container: true,
        label: 'Propuesta de ${_draft.intent.label.toLowerCase()}',
        child: Container(
          key: const Key('proposal-card'),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: palette.card,
            border: Border.all(color: palette.line),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0F172A),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(accent, palette),
              const SizedBox(height: 4),
              if (_editing)
                ..._editFields(palette)
              else
                ..._summaryRows(palette),
              for (final note in _proposal.notes) _note(note, palette),
              if (entry.failure case final failure?) ...[
                const SizedBox(height: 10),
                ErrorDiagnosticPanel(
                  key: const Key('proposal-save-error-panel'),
                  diagnostic: failure,
                ),
                const SizedBox(height: 8),
                Text(
                  key: const Key('proposal-retry-safety-note'),
                  'Puedes reintentar: no se guardará dos veces.',
                  style: TextStyle(fontSize: 11.5, color: palette.muted),
                ),
              ],
              const SizedBox(height: 12),
              if (busy)
                Semantics(
                  liveRegion: true,
                  label: 'Guardando',
                  child: const LinearProgressIndicator(),
                )
              else if (_editing)
                _editActions(palette)
              else
                _reviewActions(palette),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(Color accent, AppPalette palette) {
    final ready = _proposal.oneTap;
    final noun = switch (_draft.intent) {
      CaptureIntent.expense => 'un gasto',
      CaptureIntent.income => 'un ingreso',
      CaptureIntent.transfer => 'una transferencia',
    };
    // A Wrap keeps the title and the tag readable with large text.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Icon(
              FinanceIconCatalog.dataFor(FinanceIconKey.aiCapture),
              size: 14,
              color: accent,
            ),
            Text(
              'IA · Entendí $noun',
              softWrap: true,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: accent,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: ready ? palette.soft : palette.warnBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            ready ? 'listo para confirmar' : 'revisa los datos',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: ready ? palette.muted : palette.warnFg,
            ),
          ),
        ),
      ],
    );
  }

  Widget _note(String text, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(FinanceIcons.infoOutline, size: 15, color: palette.warnFg),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: palette.warnFg),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ summary

  List<Widget> _summaryRows(AppPalette palette) {
    final amount = ProposalDraft.parseMoney(_draft.amountText);
    final sourceCode = _currencyOf(_draft.accountId, _proposal.account);
    final formatted = amount == null
        ? '—'
        : '${MoneyFormatter.formatMinorUnits(amount.minorUnits)} $sourceCode';
    final now = ref.read(clockProvider)();
    final category = _categoryName(_draft.categoryId, _proposal.category);
    final source = _sourceName(_draft.incomeSourceId, _proposal.incomeSource);
    final description = _draft.description.trim();
    final destinationAmount = _needsDestinationAmount
        ? ProposalDraft.parseMoney(_draft.destinationAmountText)
        : null;
    final destinationCode = _currencyOf(
      _draft.destinationId,
      _proposal.destinationAccount,
    );
    final rows = <(String, String, Key)>[
      (
        _draft.intent == CaptureIntent.transfer ? 'Monto que sale' : 'Monto',
        formatted,
        const Key('proposal-amount'),
      ),
      if (destinationAmount != null)
        (
          'Monto que llega',
          '${MoneyFormatter.formatMinorUnits(destinationAmount.minorUnits)} $destinationCode',
          const Key('proposal-destination-amount'),
        ),
      if (description.isNotEmpty || _draft.intent != CaptureIntent.transfer)
        (
          'Descripción',
          description.isEmpty ? 'Sin descripción' : description,
          const Key('proposal-description'),
        ),
      (
        _draft.intent == CaptureIntent.transfer
            ? 'De'
            : _draft.intent == CaptureIntent.income
            ? 'Entra a'
            : 'Cuenta',
        _accountName(_draft.accountId, _proposal.account),
        const Key('proposal-account'),
      ),
      if (_draft.intent == CaptureIntent.transfer)
        (
          'A',
          _accountName(_draft.destinationId, _proposal.destinationAccount),
          const Key('proposal-destination'),
        ),
      if (_draft.intent == CaptureIntent.expense)
        (
          'Categoría',
          category ?? 'Sin categoría',
          const Key('proposal-category'),
        ),
      if (_draft.intent == CaptureIntent.income)
        ('Fuente', source ?? 'Sin fuente', const Key('proposal-source')),
      (
        'Fecha',
        DateLabels.relativeDay(_draft.date, now: now),
        const Key('proposal-date'),
      ),
    ];
    return [
      for (var index = 0; index < rows.length; index++)
        _SummaryRow(
          key: rows[index].$3,
          label: rows[index].$1,
          value: rows[index].$2,
          emphasized: index == 0,
          last: index == rows.length - 1,
        ),
    ];
  }

  String? _categoryName(int? id, CatalogRef? fallback) {
    if (id == null) return null;
    final categories =
        ref.read(categoriesControllerProvider).result?.categories ?? const [];
    for (final category in categories) {
      if (category.id == id) return CatalogLabels.display(category.name);
    }
    return fallback?.id == id ? CatalogLabels.display(fallback!.name) : null;
  }

  String? _sourceName(int? id, CatalogRef? fallback) {
    if (id == null) return null;
    for (final source in ref.read(incomeSourcesControllerProvider).items) {
      if (source.id == id) return CatalogLabels.display(source.name);
    }
    return fallback?.id == id ? CatalogLabels.display(fallback!.name) : null;
  }

  // ------------------------------------------------------------ editing

  List<Widget> _editFields(AppPalette palette) {
    final accounts = _accounts;
    final categories =
        ref.read(categoriesControllerProvider).result?.categories ?? const [];
    final sources = ref.read(incomeSourcesControllerProvider).items;
    final isTransfer = _draft.intent == CaptureIntent.transfer;
    final sourceCode = _currencyOf(_draft.accountId, _proposal.account);

    DropdownMenuItem<int> accountItem(Account account) => DropdownMenuItem(
      value: account.id,
      child: Text('${account.name} · ${account.currency.code}'),
    );

    return [
      const SizedBox(height: 8),
      Semantics(
        label: 'Tipo de movimiento',
        container: true,
        child: Wrap(
          key: const Key('proposal-intent-selector'),
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final intent in CaptureIntent.values)
              ChoiceChip(
                key: Key('proposal-intent-${intent.wireValue}'),
                label: Text(intent.label),
                selected: _draft.intent == intent,
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _draft.intent == intent
                      ? palette.primary
                      : palette.text,
                ),
                selectedColor: palette.primarySoft,
                backgroundColor: palette.card,
                side: BorderSide(
                  color: _draft.intent == intent
                      ? palette.primary
                      : palette.line,
                ),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (_) {
                  _syncDraftFromFields();
                  setState(() => _draft.intent = intent);
                },
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('proposal-amount-field'),
        controller: _amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: const [MoneyInputFormatter()],
        decoration: InputDecoration(
          labelText: isTransfer ? 'Monto que sale' : 'Monto',
          prefixText: r'$ ',
          suffixText: sourceCode,
          errorText: _errors['amount'],
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        key: const Key('proposal-description-field'),
        controller: _description,
        maxLength: 150,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: 'Descripción',
          counterText: '',
          errorText: _errors['description'],
        ),
      ),
      const SizedBox(height: 10),
      KeyedSubtree(
        key: const Key('proposal-account-field'),
        child: DropdownButtonFormField<int>(
          key: ValueKey('account-${_draft.accountId}-${_errors['account']}'),
          initialValue: accounts.any((a) => a.id == _draft.accountId)
              ? _draft.accountId
              : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: isTransfer
                ? 'Cuenta de origen'
                : _draft.intent == CaptureIntent.income
                ? 'Cuenta que recibe'
                : 'Cuenta',
            errorText: _errors['account'],
          ),
          items: [for (final account in accounts) accountItem(account)],
          onChanged: (value) => setState(() {
            _draft.accountId = value;
            if (_draft.destinationId == value) {
              _draft.destinationId = null;
            }
          }),
        ),
      ),
      if (isTransfer) ...[
        const SizedBox(height: 10),
        KeyedSubtree(
          key: const Key('proposal-destination-field'),
          child: DropdownButtonFormField<int>(
            key: ValueKey(
              'destination-${_draft.accountId}-${_draft.destinationId}-'
              '${_errors['destination']}',
            ),
            initialValue: accounts.any((a) => a.id == _draft.destinationId)
                ? _draft.destinationId
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Cuenta de destino',
              errorText: _errors['destination'],
            ),
            items: [
              for (final account in accounts)
                if (account.id != _draft.accountId) accountItem(account),
            ],
            onChanged: (value) => setState(() => _draft.destinationId = value),
          ),
        ),
        if (_needsDestinationAmount) ...[
          const SizedBox(height: 10),
          TextField(
            key: const Key('proposal-destination-amount-field'),
            controller: _destinationAmount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [MoneyInputFormatter()],
            decoration: InputDecoration(
              labelText: 'Monto que llega',
              prefixText: r'$ ',
              suffixText: _currencyOf(
                _draft.destinationId,
                _proposal.destinationAccount,
              ),
              errorText: _errors['destinationAmount'],
            ),
          ),
        ],
      ],
      if (_draft.intent == CaptureIntent.expense) ...[
        const SizedBox(height: 10),
        KeyedSubtree(
          key: const Key('proposal-category-field'),
          child: DropdownButtonFormField<int?>(
            key: ValueKey('category-${_draft.categoryId}'),
            initialValue: categories.any((c) => c.id == _draft.categoryId)
                ? _draft.categoryId
                : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Categoría'),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Sin categoría'),
              ),
              for (final category in categories)
                DropdownMenuItem<int?>(
                  value: category.id,
                  child: Text(CatalogLabels.display(category.name)),
                ),
            ],
            onChanged: (value) => setState(() => _draft.categoryId = value),
          ),
        ),
      ],
      if (_draft.intent == CaptureIntent.income) ...[
        const SizedBox(height: 10),
        KeyedSubtree(
          key: const Key('proposal-source-field'),
          child: DropdownButtonFormField<int?>(
            key: ValueKey('source-${_draft.incomeSourceId}'),
            initialValue: sources.any((s) => s.id == _draft.incomeSourceId)
                ? _draft.incomeSourceId
                : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Fuente de ingreso'),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Sin fuente'),
              ),
              for (final source in sources)
                DropdownMenuItem<int?>(
                  value: source.id,
                  child: Text(CatalogLabels.display(source.name)),
                ),
            ],
            onChanged: (value) => setState(() => _draft.incomeSourceId = value),
          ),
        ),
      ],
      const SizedBox(height: 10),
      InkWell(
        key: const Key('proposal-date-field'),
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Fecha',
            suffixIcon: Icon(FinanceIcons.calendarTodayOutlined, size: 18),
          ),
          child: Text(
            DateLabels.relativeDay(_draft.date, now: ref.read(clockProvider)()),
          ),
        ),
      ),
    ];
  }

  // ------------------------------------------------------------ actions

  Widget _reviewActions(AppPalette palette) {
    final confirm = FilledButton(
      key: const Key('proposal-confirm'),
      style: FilledButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        minimumSize: const Size(0, 48),
      ),
      onPressed: _confirm,
      child: Text(
        widget.entry.failure == null ? 'Confirmar y guardar' : 'Reintentar',
      ),
    );
    final edit = OutlinedButton(
      key: const Key('proposal-edit'),
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.primary,
        side: BorderSide(color: palette.primary, width: 1.5),
        minimumSize: const Size(0, 48),
      ),
      onPressed: () => setState(() => _editing = true),
      child: const Text('Editar'),
    );
    final discard = OutlinedButton(
      key: const Key('proposal-discard'),
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.discard,
        side: BorderSide(color: palette.discard, width: 1.5),
        minimumSize: const Size(0, 48),
      ),
      onPressed: () => ref
          .read(textCaptureControllerProvider.notifier)
          .discard(widget.entry),
      child: const Text('Descartar'),
    );
    // Large text sizes stack the buttons instead of squeezing their labels.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.25;
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          confirm,
          const SizedBox(height: 8),
          edit,
          const SizedBox(height: 8),
          discard,
        ],
      );
    }
    return Row(
      children: [
        Expanded(flex: 5, child: confirm),
        const SizedBox(width: 8),
        Expanded(flex: 3, child: edit),
        const SizedBox(width: 8),
        Expanded(flex: 3, child: discard),
      ],
    );
  }

  Widget _editActions(AppPalette palette) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: const Key('proposal-cancel-edit'),
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.muted,
              side: BorderSide(color: palette.line, width: 1.5),
              minimumSize: const Size(0, 48),
            ),
            onPressed: _cancelEdit,
            child: const Text('Cancelar'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: FilledButton(
            key: const Key('proposal-save-edit'),
            style: FilledButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: palette.onPrimary,
              minimumSize: const Size(0, 48),
            ),
            onPressed: _saveEdit,
            child: const Text('Guardar cambios'),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    super.key,
    required this.label,
    required this.value,
    required this.emphasized,
    required this.last,
  });

  final String label;
  final String value;
  final bool emphasized;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.25;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: palette.line)),
      ),
      child: MergeSemantics(
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: palette.muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: emphasized ? 16 : 13.5,
                      fontWeight: emphasized
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: palette.text,
                    ),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    flex: 2,
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 12, color: palette.muted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Text(
                      value,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: emphasized ? 16 : 13.5,
                        fontWeight: emphasized
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: palette.text,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
