import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../application/history_controller.dart';
import '../application/history_state.dart';
import '../domain/history_models.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  final _accountIdController = TextEditingController();
  final _categoryIdController = TextEditingController();
  TransactionType? _selectedType;
  HistoryPeriod? _selectedPeriod;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      final state = ref.read(historyControllerProvider);
      if (state.status == HistoryLoadStatus.initial) {
        ref.read(historyControllerProvider.notifier).load();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _accountIdController.dispose();
    _categoryIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyControllerProvider);
    final controller = ref.read(historyControllerProvider.notifier);
    final result = state.result;
    final isBusy =
        state.status == HistoryLoadStatus.loading ||
        state.status == HistoryLoadStatus.loadingMore;
    final showCustomDates = _selectedPeriod == HistoryPeriod.custom;
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
              child: ListView(
                key: const Key('history-list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  TextField(
                    key: const Key('history-search-field'),
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      labelText: 'Buscar',
                      hintText: 'Comercio, nota o descripción…',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _applyFilters(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<TransactionType?>(
                          key: const Key('history-type-field'),
                          initialValue: _selectedType,
                          decoration: const InputDecoration(labelText: 'Tipo'),
                          items: [
                            const DropdownMenuItem(
                              child: Text('Todos los tipos'),
                            ),
                            ...TransactionType.values.map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(_typeLabel(type)),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedType = value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<HistoryPeriod?>(
                          key: const Key('history-period-field'),
                          initialValue: _selectedPeriod,
                          decoration: const InputDecoration(
                            labelText: 'Periodo',
                          ),
                          items: [
                            const DropdownMenuItem(
                              child: Text('Todo el periodo'),
                            ),
                            ...HistoryPeriod.values.map(
                              (period) => DropdownMenuItem(
                                value: period,
                                child: Text(_periodLabel(period)),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedPeriod = value),
                        ),
                      ),
                    ],
                  ),
                  if (showCustomDates) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('history-start-date-button'),
                            onPressed: () => _pickDate(isStart: true),
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: Text(
                              _startDate == null
                                  ? 'Fecha inicial'
                                  : _formatDate(_startDate!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('history-end-date-button'),
                            onPressed: () => _pickDate(isStart: false),
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: Text(
                              _endDate == null
                                  ? 'Fecha final'
                                  : _formatDate(_endDate!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('history-account-id-field'),
                          controller: _accountIdController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'ID de cuenta',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: const Key('history-category-id-field'),
                          controller: _categoryIdController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'ID de categoría',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('history-apply-button'),
                    onPressed: isBusy ? null : _applyFilters,
                    icon: const Icon(Icons.filter_alt_outlined),
                    label: const Text('Aplicar filtros'),
                  ),
                  const SizedBox(height: 16),
                  if (isBusy) ...[
                    Semantics(
                      liveRegion: true,
                      label: 'Cargando el historial',
                      child: const LinearProgressIndicator(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (state.diagnostic case final diagnostic?) ...[
                    ErrorDiagnosticPanel(diagnostic: diagnostic),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: controller.load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (result == null &&
                      state.status != HistoryLoadStatus.loading &&
                      state.diagnostic == null)
                    const _HistoryLoadingPlaceholder(),
                  if (result != null && result.items.isEmpty)
                    const _HistoryEmptyState(),
                  if (result != null)
                    for (final item in result.items) ...[
                      _HistoryCard(item: item),
                      const SizedBox(height: 12),
                    ],
                  if (result != null && result.hasNext) ...[
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      key: const Key('history-load-more-button'),
                      onPressed: isBusy ? null : controller.loadMore,
                      icon: const Icon(Icons.expand_more),
                      label: const Text('Cargar más historial'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now().toUtc(),
      firstDate: DateTime.utc(2000),
      lastDate: DateTime.now().toUtc(),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startDate = DateTime.utc(picked.year, picked.month, picked.day);
        } else {
          _endDate = DateTime.utc(picked.year, picked.month, picked.day);
        }
      });
    }
  }

  String _formatDate(DateTime value) {
    final date = value.toUtc();
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  int? _asOptionalId(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return int.tryParse(trimmed);
  }

  Future<void> _applyFilters() async {
    await ref
        .read(historyControllerProvider.notifier)
        .updateFilters(
          HistoryFilters(
            search: _searchController.text,
            type: _selectedType,
            categoryId: _asOptionalId(_categoryIdController.text),
            accountId: _asOptionalId(_accountIdController.text),
            period: _selectedPeriod,
            startDate: _startDate,
            endDate: _endDate,
          ),
        );
  }
}

String _typeLabel(TransactionType type) => switch (type) {
  TransactionType.expense => 'Gasto',
  TransactionType.income => 'Ingreso',
  TransactionType.transfer => 'Transferencia',
};

String _periodLabel(HistoryPeriod period) => switch (period) {
  HistoryPeriod.week => 'Semana',
  HistoryPeriod.weekly => 'Semanal',
  HistoryPeriod.month => 'Mes',
  HistoryPeriod.monthly => 'Mensual',
  HistoryPeriod.custom => 'Personalizado',
};

String _itemsLabel(int count) => count == 1 ? '1 elemento' : '$count elementos';

class _HistoryLoadingPlaceholder extends StatelessWidget {
  const _HistoryLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(
            Icons.manage_search_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Sin resultados para estos filtros',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Prueba otra búsqueda o un periodo más amplio.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.item});

  final HistoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = item.movements.isEmpty ? null : item.movements.first;
    final title =
        item.expense?.store ?? item.description ?? _typeLabel(item.type);
    final subtitle = [
      _typeLabel(item.type),
      if (item.incomeSource != null) item.incomeSource!,
      if (item.expense != null) _itemsLabel(item.expense!.items.length),
    ].join(' · ');
    final expenseId =
        item.expense?.items.firstOrNull?.id ?? item.expense?.receiptId;
    final canNavigate =
        (item.type == TransactionType.expense && expenseId != null) ||
        item.type == TransactionType.income;

    return Card(
      key: Key('history-card-${item.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canNavigate
            ? () async {
                if (item.type == TransactionType.expense) {
                  await context.push('/expenses/$expenseId');
                } else if (item.type == TransactionType.income) {
                  await context.push('/incomes/${item.id}');
                }
                if (context.mounted) {
                  ref.read(historyControllerProvider.notifier).load();
                }
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                child: Icon(switch (item.type) {
                  TransactionType.expense => Icons.shopping_cart_outlined,
                  TransactionType.income => Icons.savings_outlined,
                  TransactionType.transfer => Icons.swap_horiz_outlined,
                }),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (primary != null)
                Text(
                  primary.amount.formatWithCurrency(primary.currencyCode),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: primary.amount.isNegative
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                  textAlign: TextAlign.end,
                ),
              if (canNavigate) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
