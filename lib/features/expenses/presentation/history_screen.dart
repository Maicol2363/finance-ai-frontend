import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/formatters/date_labels.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/manage_widgets.dart';
import '../../../core/widgets/movements_empty_state.dart';
import '../../accounts/application/accounts_controller.dart';
import '../../accounts/application/accounts_state.dart';
import '../../accounts/domain/account_models.dart';
import '../../categories/application/categories_controller.dart';
import '../../categories/application/categories_state.dart';
import '../../categories/domain/category_models.dart';
import '../../categories/presentation/category_visuals.dart';
import '../application/history_controller.dart';
import '../application/history_state.dart';
import '../domain/expense_models.dart';
import '../domain/history_models.dart';
import 'transaction_visuals.dart';

/// Transaction kinds offered as chips. `null` means "all types".
const _typeOptions = <FilterChipOption<TransactionType?>>[
  FilterChipOption(value: null, label: 'Todos'),
  FilterChipOption(value: TransactionType.expense, label: 'Gastos'),
  FilterChipOption(value: TransactionType.income, label: 'Ingresos'),
  FilterChipOption(value: TransactionType.transfer, label: 'Transferencias'),
];

/// Period presets offered as chips. `weekly`/`monthly` stay in the domain model
/// (and in the API contract) but are not offered here: "Semanal"/"Mensual" are
/// not distinguishable from "Semana"/"Mes" for the user. `null` means "all".
const _periodOptions = <FilterChipOption<HistoryPeriod?>>[
  FilterChipOption(value: null, label: 'Todo'),
  FilterChipOption(value: HistoryPeriod.week, label: 'Semana'),
  FilterChipOption(value: HistoryPeriod.month, label: 'Mes'),
  FilterChipOption(value: HistoryPeriod.custom, label: 'Personalizado'),
];

/// Capture-source groups offered as chips. `ai` covers photo, voice and text
/// captures. `null` means "every source".
const _sourceOptions = <FilterChipOption<CaptureSource?>>[
  FilterChipOption(value: null, label: 'Todos'),
  FilterChipOption(value: CaptureSource.ai, label: '✨ IA'),
  FilterChipOption(value: CaptureSource.manual, label: '✎ Manual'),
  FilterChipOption(value: CaptureSource.import, label: '📥 Importado'),
];

/// Receipt shape offered as chips: a receipt with several lines vs a single
/// expense entry. `null` means "both".
const _receiptOptions = <FilterChipOption<ReceiptKind?>>[
  FilterChipOption(value: null, label: 'Todos'),
  FilterChipOption(value: ReceiptKind.multi, label: '🧾 Recibos'),
  FilterChipOption(value: ReceiptKind.single, label: '✎ Individuales'),
];

/// Unified transaction feed (`GET /api/v1/history`, HU-011).
///
/// The filter row stays compact on purpose: search is always visible and the
/// filters (type, period, account, category) live behind the tune button, with
/// the active ones shown as removable chips. Filtering is live — typing is
/// debounced, chips and dropdowns apply immediately — and the query always
/// comes from [HistoryState.filters], so navigating away and back keeps
/// whatever the user selected.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  static const _searchDebounce = Duration(milliseconds: 350);

  late final TextEditingController _searchController;
  late final TextEditingController _storeController;
  Timer? _debounce;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    final filters = ref.read(historyControllerProvider).filters;
    _searchController = TextEditingController(text: filters.search ?? '');
    _storeController = TextEditingController(text: filters.store ?? '');
    _searchController.addListener(_onSearchChanged);
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      final state = ref.read(historyControllerProvider);
      if (state.filters.accountId != null || state.filters.categoryId != null) {
        _ensureFilterOptions();
      }
      if (state.status == HistoryLoadStatus.initial) {
        ref.read(historyControllerProvider.notifier).load();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _storeController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, _applySearch);
  }

  void _applySearch() {
    final text = _searchController.text.trim();
    final current = ref.read(historyControllerProvider).filters.search ?? '';
    if (text == current) {
      return;
    }
    ref.read(historyControllerProvider.notifier).setSearch(text);
  }

  /// Loads the account/category catalogs the filter dropdowns need, once.
  void _ensureFilterOptions() {
    if (ref.read(accountsControllerProvider).listStatus ==
        AccountsLoadStatus.initial) {
      ref.read(accountsControllerProvider.notifier).load();
    }
    if (ref.read(categoriesControllerProvider).loadStatus ==
        CategoriesLoadStatus.initial) {
      ref.read(categoriesControllerProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyControllerProvider);
    final controller = ref.read(historyControllerProvider.notifier);
    final filters = state.filters;
    final result = state.result;
    final items = result?.items ?? const <HistoryItem>[];
    final accounts =
        ref.watch(accountsControllerProvider).result?.accounts ??
        const <Account>[];
    final categories =
        ref.watch(categoriesControllerProvider).result?.categories ??
        const <Category>[];
    final isBusy =
        state.status == HistoryLoadStatus.loading ||
        state.status == HistoryLoadStatus.loadingMore;
    final isInitialLoad =
        result == null &&
        state.diagnostic == null &&
        state.status != HistoryLoadStatus.failure;
    final groups = _groupByDay(items);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Historial'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: RefreshIndicator(
              onRefresh: controller.load,
              child: CustomScrollView(
                key: const Key('history-list'),
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _buildFilterPanel(
                        filters: filters,
                        accounts: accounts,
                        categories: categories,
                        storeSuggestions: _storeSuggestions(items),
                      ),
                    ),
                  ),
                  if (state.diagnostic case final diagnostic?)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ErrorDiagnosticPanel(diagnostic: diagnostic),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: controller.load,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (isBusy && result != null)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: Semantics(
                          liveRegion: true,
                          label: 'Actualizando el historial',
                          child: const LinearProgressIndicator(),
                        ),
                      ),
                    ),
                  if (isInitialLoad)
                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                      sliver: SliverToBoxAdapter(child: _HistorySkeletonList()),
                    ),
                  if (result != null && items.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: filters.hasActiveFilters
                            ? _HistoryNoResults(onClear: _clearFilters)
                            : MovementsEmptyState(
                                onRegister: () => context.go('/expenses/new'),
                              ),
                      ),
                    ),
                  if (result != null && items.isNotEmpty) ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: _HistoryResultHeader(
                          total: result.total,
                          loaded: items.length,
                          balance: result.total == items.length
                              ? _balanceLabel(items)
                              : null,
                        ),
                      ),
                    ),
                    for (final group in groups) ...[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(22, 18, 20, 8),
                        sliver: SliverToBoxAdapter(
                          child: _HistoryDayHeader(label: group.label),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList.separated(
                          itemCount: group.items.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) =>
                              _HistoryCard(item: group.items[index]),
                        ),
                      ),
                    ],
                    if (result.hasNext)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: OutlinedButton.icon(
                            key: const Key('history-load-more-button'),
                            onPressed: isBusy ? null : controller.loadMore,
                            icon: const Icon(Icons.expand_more),
                            label: const Text('Cargar más historial'),
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 96)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPanel({
    required HistoryFilters filters,
    required List<Account> accounts,
    required List<Category> categories,
    required List<String> storeSuggestions,
  }) {
    final controller = ref.read(historyControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildSearchField()),
            const SizedBox(width: 8),
            HeaderIconButton(
              key: const Key('history-filter-toggle'),
              icon: _showFilters ? Icons.filter_alt_off_outlined : Icons.tune,
              tooltip: _showFilters ? 'Ocultar filtros' : 'Mostrar filtros',
              onPressed: () {
                setState(() => _showFilters = !_showFilters);
                if (_showFilters) {
                  _ensureFilterOptions();
                }
              },
            ),
          ],
        ),
        if (filters.hasActiveFilters) ...[
          const SizedBox(height: 10),
          _buildActiveFilters(filters, accounts, categories),
        ],
        if (_showFilters) ...[
          const FieldLabel('Tipo', topSpacing: 14),
          FilterChipRow<TransactionType?>(
            keyPrefix: 'history-type-chip',
            options: _typeOptions,
            selected: filters.type,
            onChanged: controller.setType,
          ),
          const FieldLabel('Periodo', topSpacing: 14),
          FilterChipRow<HistoryPeriod?>(
            keyPrefix: 'history-period-chip',
            options: _periodOptions,
            selected: filters.period,
            onChanged: (period) => _selectPeriod(period, filters),
          ),
          const FieldLabel('Origen', topSpacing: 14),
          FilterChipRow<CaptureSource?>(
            keyPrefix: 'history-source-chip',
            options: _sourceOptions,
            selected: filters.captureSource,
            onChanged: controller.setCaptureSource,
          ),
          const FieldLabel('Registro', topSpacing: 14),
          FilterChipRow<ReceiptKind?>(
            keyPrefix: 'history-receipt-chip',
            options: _receiptOptions,
            selected: filters.receiptKind,
            onChanged: controller.setReceiptKind,
          ),
          const FieldLabel('Comercio', topSpacing: 16),
          _buildStoreField(),
          if (storeSuggestions.isNotEmpty) ...[
            const SizedBox(height: 6),
            FilterChipRow<String>(
              keyPrefix: 'history-store-suggestion',
              options: [
                for (final store in storeSuggestions)
                  FilterChipOption(value: store, label: store),
              ],
              selected: filters.store ?? '',
              onChanged: (store) =>
                  controller.setStore(store == filters.store ? null : store),
            ),
          ],
          if (filters.period == HistoryPeriod.custom) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Tooltip(
                    message: 'Fecha inicial',
                    child: OutlinedButton.icon(
                      key: const Key('history-start-date-button'),
                      onPressed: () =>
                          _pickCustomDate(isStart: true, filters: filters),
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text(
                        filters.startDate == null
                            ? 'Desde'
                            : _formatDate(filters.startDate!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Tooltip(
                    message: 'Fecha final',
                    child: OutlinedButton.icon(
                      key: const Key('history-end-date-button'),
                      onPressed: () =>
                          _pickCustomDate(isStart: false, filters: filters),
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text(
                        filters.endDate == null
                            ? 'Hasta'
                            : _formatDate(filters.endDate!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _buildAccountDropdown(filters, accounts),
          const SizedBox(height: 12),
          _buildCategoryDropdown(filters, categories),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('history-clear-filters-button'),
              onPressed: filters.hasActiveFilters ? _clearFilters : null,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Limpiar filtros'),
            ),
          ),
        ],
      ],
    );
  }

  /// Stores seen in the loaded page, offered as one-tap filters.
  List<String> _storeSuggestions(List<HistoryItem> items) {
    final seen = <String>{};
    for (final item in items) {
      final store = item.expense?.store.trim() ?? '';
      if (store.isNotEmpty) {
        seen.add(store);
      }
    }
    return seen.take(6).toList();
  }

  /// Merchant filter: applied on submit, cleared from its suffix icon.
  Widget _buildStoreField() {
    final controller = ref.read(historyControllerProvider.notifier);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _storeController,
      builder: (context, value, child) => TextField(
        key: const Key('history-store-field'),
        controller: _storeController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Comercio (ej. Éxito)',
          prefixIcon: const Icon(Icons.storefront_outlined),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  key: const Key('history-store-clear'),
                  tooltip: 'Borrar comercio',
                  onPressed: () {
                    _storeController.clear();
                    controller.setStore(null);
                  },
                  icon: const Icon(Icons.close),
                ),
        ),
        onSubmitted: controller.setStore,
      ),
    );
  }

  Widget _buildSearchField() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, child) => TextField(
        key: const Key('history-search-field'),
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar comercio, nota o categoría…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  key: const Key('history-search-clear'),
                  tooltip: 'Borrar búsqueda',
                  onPressed: () {
                    _debounce?.cancel();
                    _searchController.clear();
                    _applySearch();
                  },
                  icon: const Icon(Icons.close),
                ),
        ),
        onSubmitted: (_) {
          _debounce?.cancel();
          _applySearch();
        },
      ),
    );
  }

  Widget _buildAccountDropdown(HistoryFilters filters, List<Account> accounts) {
    final selectedId =
        accounts.any((account) => account.id == filters.accountId)
        ? filters.accountId
        : null;
    if (accounts.isEmpty) {
      return _FilterFieldPlaceholder(
        key: const Key('history-account-field'),
        label: 'Cuenta',
        value: filters.accountId == null
            ? 'Sin cuentas disponibles'
            : 'Cuenta #${filters.accountId}',
      );
    }
    return KeyedSubtree(
      key: const Key('history-account-field'),
      child: DropdownButtonFormField<int?>(
        key: ValueKey<String?>('history-account-$selectedId'),
        initialValue: selectedId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Cuenta'),
        items: [
          const DropdownMenuItem(child: Text('Todas las cuentas')),
          for (final account in accounts)
            DropdownMenuItem(
              value: account.id,
              child: Text(account.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (value) =>
            ref.read(historyControllerProvider.notifier).setAccountId(value),
      ),
    );
  }

  Widget _buildCategoryDropdown(
    HistoryFilters filters,
    List<Category> categories,
  ) {
    final selectedId =
        categories.any((category) => category.id == filters.categoryId)
        ? filters.categoryId
        : null;
    if (categories.isEmpty) {
      return _FilterFieldPlaceholder(
        key: const Key('history-category-field'),
        label: 'Categoría',
        value: filters.categoryId == null
            ? 'Sin categorías disponibles'
            : 'Categoría #${filters.categoryId}',
      );
    }
    return KeyedSubtree(
      key: const Key('history-category-field'),
      child: DropdownButtonFormField<int?>(
        key: ValueKey<String?>('history-category-$selectedId'),
        initialValue: selectedId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Categoría'),
        items: [
          const DropdownMenuItem(child: Text('Todas las categorías')),
          for (final category in categories)
            DropdownMenuItem(
              value: category.id,
              child: Row(
                children: [
                  Icon(
                    category.icon.value,
                    size: 16,
                    color: category.color.value,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(category.name, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
        ],
        onChanged: (value) =>
            ref.read(historyControllerProvider.notifier).setCategoryId(value),
      ),
    );
  }

  void _clearFilters() {
    _debounce?.cancel();
    _searchController.clear();
    _storeController.clear();
    ref.read(historyControllerProvider.notifier).clearFilters();
  }

  Widget _buildActiveFilters(
    HistoryFilters filters,
    List<Account> accounts,
    List<Category> categories,
  ) {
    final controller = ref.read(historyControllerProvider.notifier);
    final chips = <Widget>[];
    if (filters.search case final search?) {
      chips.add(
        _ActiveFilterChip(
          key: const Key('history-active-search'),
          label: '“$search”',
          onRemove: () {
            _debounce?.cancel();
            _searchController.clear();
            controller.setSearch('');
          },
        ),
      );
    }
    if (filters.type case final type?) {
      chips.add(
        _ActiveFilterChip(
          key: const Key('history-active-type'),
          label: transactionTypeLabel(type),
          onRemove: () => controller.setType(null),
        ),
      );
    }
    if (filters.period != null) {
      chips.add(
        _ActiveFilterChip(
          key: const Key('history-active-period'),
          label: _periodSummary(filters),
          onRemove: () => controller.setPeriod(null),
        ),
      );
    }
    if (filters.captureSource case final source?) {
      chips.add(
        _ActiveFilterChip(
          key: const Key('history-active-source'),
          label: captureSourceFilterLabel(source),
          onRemove: () => controller.setCaptureSource(null),
        ),
      );
    }
    if (filters.receiptKind case final kind?) {
      chips.add(
        _ActiveFilterChip(
          key: const Key('history-active-receipt'),
          label: _receiptKindLabel(kind),
          onRemove: () => controller.setReceiptKind(null),
        ),
      );
    }
    if (filters.store case final store?) {
      chips.add(
        _ActiveFilterChip(
          key: const Key('history-active-store'),
          label: store,
          onRemove: () {
            _storeController.clear();
            controller.setStore(null);
          },
        ),
      );
    }
    if (filters.accountId case final accountId?) {
      final name = accounts
          .where((account) => account.id == accountId)
          .map((account) => account.name)
          .firstOrNull;
      chips.add(
        _ActiveFilterChip(
          key: const Key('history-active-account'),
          label: name ?? 'Cuenta #$accountId',
          onRemove: () => controller.setAccountId(null),
        ),
      );
    }
    if (filters.categoryId case final categoryId?) {
      final name = categories
          .where((category) => category.id == categoryId)
          .map((category) => category.name)
          .firstOrNull;
      chips.add(
        _ActiveFilterChip(
          key: const Key('history-active-category'),
          label: name ?? 'Categoría #$categoryId',
          onRemove: () => controller.setCategoryId(null),
        ),
      );
    }
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  /// Chip label for the receipt-shape filter.
  String _receiptKindLabel(ReceiptKind kind) =>
      kind == ReceiptKind.multi ? '🧾 Recibos' : '✎ Individuales';

  String _periodSummary(HistoryFilters filters) {
    final period = filters.period;
    if (period == null) {
      return '';
    }
    final start = filters.startDate;
    final end = filters.endDate;
    if (period != HistoryPeriod.custom || start == null || end == null) {
      return historyPeriodLabel(period);
    }
    return '${_formatShortDate(start)} – ${_formatShortDate(end)}';
  }

  /// Presets apply immediately; `Personalizado` first asks for the range, since
  /// the API rejects `custom` without both dates.
  Future<void> _selectPeriod(
    HistoryPeriod? period,
    HistoryFilters filters,
  ) async {
    final controller = ref.read(historyControllerProvider.notifier);
    if (period != HistoryPeriod.custom) {
      await controller.setPeriod(period);
      return;
    }
    final now = DateTime.now().toUtc();
    final start =
        filters.startDate ??
        await _pickDate(initial: DateTime.utc(now.year, now.month, 1));
    if (start == null || !mounted) {
      return;
    }
    final end =
        filters.endDate ?? await _pickDate(initial: now, firstDate: start);
    if (end == null || !mounted) {
      return;
    }
    await controller.setPeriod(
      HistoryPeriod.custom,
      startDate: start,
      endDate: end,
    );
  }

  /// Edits one end of an active custom range; the missing end falls back to the
  /// picked day so the query stays valid.
  Future<void> _pickCustomDate({
    required bool isStart,
    required HistoryFilters filters,
  }) async {
    final picked = await _pickDate(
      initial:
          (isStart ? filters.startDate : filters.endDate) ??
          DateTime.now().toUtc(),
      firstDate: isStart ? null : filters.startDate,
    );
    if (picked == null || !mounted) {
      return;
    }
    final start = isStart ? picked : filters.startDate;
    final end = isStart ? filters.endDate : picked;
    await ref
        .read(historyControllerProvider.notifier)
        .setPeriod(
          HistoryPeriod.custom,
          startDate: start ?? picked,
          endDate: end ?? picked,
        );
  }

  Future<DateTime?> _pickDate({
    required DateTime initial,
    DateTime? firstDate,
  }) async {
    final now = DateTime.now().toUtc();
    var earliest = firstDate ?? DateTime.utc(2000);
    if (earliest.isAfter(now)) {
      earliest = now;
    }
    var seed = initial.toUtc();
    if (seed.isBefore(earliest)) {
      seed = earliest;
    }
    if (seed.isAfter(now)) {
      seed = now;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: seed,
      firstDate: earliest,
      lastDate: now,
    );
    if (picked == null) {
      return null;
    }
    return DateTime.utc(picked.year, picked.month, picked.day);
  }

  String _formatDate(DateTime value) {
    final date = value.toUtc();
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatShortDate(DateTime value) {
    final date = value.toUtc();
    return '${date.day}/${date.month}';
  }

  /// Splits the feed into consecutive local-day groups (`Hoy`, `Ayer`, `3 sep`).
  List<_HistoryDayGroup> _groupByDay(List<HistoryItem> items) {
    final groups = <_HistoryDayGroup>[];
    for (final item in items) {
      final local = item.occurredAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (groups.isEmpty || groups.last.day != day) {
        groups.add(
          _HistoryDayGroup(
            day: day,
            label: DateLabels.relativeDay(item.occurredAt),
            items: <HistoryItem>[item],
          ),
        );
      } else {
        groups.last.items.add(item);
      }
    }
    return groups;
  }

  /// Signed total of the loaded page, or `null` when currencies are mixed.
  String? _balanceLabel(List<HistoryItem> items) {
    final totals = <String, int>{};
    for (final item in items) {
      final movement = item.movements.isEmpty ? null : item.movements.first;
      if (movement == null) {
        return null;
      }
      totals.update(
        movement.currencyCode,
        (value) => value + movement.amount.minorUnits,
        ifAbsent: () => movement.amount.minorUnits,
      );
    }
    if (totals.length != 1) {
      return null;
    }
    final entry = totals.entries.single;
    final formatted = MoneyFormatter.formatMinorUnits(entry.value.abs());
    return 'Balance ${entry.value < 0 ? '-' : '+'}$formatted ${entry.key}';
  }
}

/// One local day of the feed with its rendered label.
class _HistoryDayGroup {
  _HistoryDayGroup({
    required this.day,
    required this.label,
    required this.items,
  });

  final DateTime day;
  final String label;
  final List<HistoryItem> items;
}

/// Mockup `.fchip.on` equivalent for "what is filtering the list right now".
///
/// Tapping anywhere on the chip removes its filter.
class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({
    super.key,
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: 'Quitar filtro $label',
      child: Material(
        color: palette.primarySoft,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onRemove,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: palette.primaryDark,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.close, size: 14, color: palette.primaryDark),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Section header for one day of the feed.
class _HistoryDayHeader extends StatelessWidget {
  const _HistoryDayHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      header: true,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: palette.muted,
        ),
      ),
    );
  }
}

/// Result counter plus, when the whole page is loaded, the signed net total.
class _HistoryResultHeader extends StatelessWidget {
  const _HistoryResultHeader({
    required this.total,
    required this.loaded,
    required this.balance,
  });

  final int total;
  final int loaded;
  final String? balance;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final countLabel = '$total ${total == 1 ? 'movimiento' : 'movimientos'}';
    final trailing = balance ?? '$loaded de $total cargados';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          countLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: palette.text,
          ),
        ),
        Text(
          trailing,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: palette.muted,
          ),
        ),
      ],
    );
  }
}

/// Placeholder cards shown while the first page loads.
class _HistorySkeletonList extends StatelessWidget {
  const _HistorySkeletonList();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      liveRegion: true,
      label: 'Cargando el historial',
      child: Column(
        key: const Key('history-loading'),
        children: [
          for (var index = 0; index < 4; index++)
            Container(
              height: 74,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.line),
              ),
            ),
        ],
      ),
    );
  }
}

/// Empty result set caused by the active filters (not by an empty account).
class _HistoryNoResults extends StatelessWidget {
  const _HistoryNoResults({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: palette.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.manage_search_outlined,
              size: 30,
              color: palette.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sin resultados para estos filtros',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Prueba otra búsqueda o un periodo más amplio.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: palette.muted, height: 1.4),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            key: const Key('history-empty-clear-button'),
            onPressed: onClear,
            icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
            label: const Text('Limpiar filtros'),
          ),
        ],
      ),
    );
  }
}

/// Read-only stand-in for a filter dropdown while its catalog is loading.
class _FilterFieldPlaceholder extends StatelessWidget {
  const _FilterFieldPlaceholder({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13.5, color: palette.muted),
      ),
    );
  }
}

/// One movement of the feed: emoji tile, title, source/category meta, the
/// signed amount in the app's money format and the capture time.
class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.item});

  final HistoryItem item;

  MoneyAmount? get _amount =>
      item.movements.isEmpty ? null : item.movements.first.amount;

  String get _title =>
      item.expense?.store ??
      item.description ??
      transactionTypeLabel(item.type);

  String get _emoji {
    if (item.type != TransactionType.expense) {
      return transactionTypeEmoji(item.type);
    }
    final category = item.expense?.items.firstOrNull?.category?.name;
    return category == null
        ? transactionTypeEmoji(item.type)
        : categoryEmoji(category);
  }

  String get _sourceTag => switch (item.type) {
    TransactionType.income => '＋ Ingreso',
    TransactionType.transfer => '🔄 Transferencia',
    TransactionType.expense => captureSourceLabel(
      item.captureSource,
      item.expense?.items.length ?? 0,
    ),
  };

  String get _accountName =>
      item.movements.isEmpty ? '' : item.movements.first.accountName;

  String get _meta => switch (item.type) {
    TransactionType.expense => [
      _accountName,
      item.expense?.items.firstOrNull?.category?.name,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · '),
    TransactionType.income => [
      item.incomeSource,
      _accountName,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · '),
    TransactionType.transfer => [
      transactionTypeLabel(item.type),
      _accountName,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · '),
  };

  String get _detail {
    final time = DateLabels.time(item.occurredAt);
    final items = item.expense?.items.length;
    if (item.type != TransactionType.expense || items == null) {
      return time;
    }
    return '$time · ${items == 1 ? '1 elemento' : '$items elementos'}';
  }

  String _amountLabel(MoneyAmount amount) {
    final formatted = MoneyFormatter.formatMinorUnits(amount.minorUnits.abs());
    return '${amount.isNegative ? '-' : '+'}$formatted';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final amount = _amount;
    final currencyCode = item.movements.isEmpty
        ? null
        : item.movements.first.currencyCode;
    final expenseId =
        item.expense?.items.firstOrNull?.id ?? item.expense?.receiptId;
    final canNavigate =
        (item.type == TransactionType.expense && expenseId != null) ||
        item.type == TransactionType.income;
    final amountText = amount == null ? 'sin monto' : _amountLabel(amount);

    return Semantics(
      container: true,
      button: canNavigate,
      label:
          '$_title, ${transactionTypeLabel(item.type)} $amountText, '
          '$_meta, $_detail',
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.line),
            boxShadow: const [
              BoxShadow(
                color: Color(0x040F172A),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: Key('history-card-${item.id}'),
              borderRadius: BorderRadius.circular(14),
              onTap: canNavigate ? () => _open(context, ref, expenseId) : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: palette.primarySoft,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Center(
                        child: Text(
                          _emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: palette.text,
                            ),
                          ),
                          const SizedBox(height: 3),
                          _buildMetaLine(palette),
                          const SizedBox(height: 3),
                          Text(
                            _detail,
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildAmount(palette, amount, currencyCode),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 16,
                      child: canNavigate
                          ? Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: palette.muted,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaLine(AppPalette palette) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: palette.soft,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            _sourceTag,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: palette.muted,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: palette.muted),
          ),
        ),
      ],
    );
  }

  Widget _buildAmount(
    AppPalette palette,
    MoneyAmount? amount,
    String? currencyCode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          amount == null ? '—' : _amountLabel(amount),
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: amount == null
                ? palette.muted
                : (amount.isNegative ? palette.discard : palette.income),
          ),
        ),
        if (currencyCode != null) ...[
          const SizedBox(height: 2),
          Text(
            currencyCode,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: palette.muted,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    int? expenseId,
  ) async {
    if (item.type == TransactionType.expense) {
      await context.push('/expenses/$expenseId');
    } else if (item.type == TransactionType.income) {
      await context.push('/incomes/${item.id}');
    }
    if (context.mounted) {
      ref.read(historyControllerProvider.notifier).load();
    }
  }
}
