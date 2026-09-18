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
          tooltip: 'Back to home',
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('History'),
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
                      labelText: 'Search',
                      hintText: 'Merchant, note, or description…',
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
                          decoration: const InputDecoration(labelText: 'Type'),
                          items: [
                            const DropdownMenuItem(child: Text('All types')),
                            ...TransactionType.values.map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type.name),
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
                            labelText: 'Period',
                          ),
                          items: [
                            const DropdownMenuItem(child: Text('All time')),
                            ...HistoryPeriod.values.map(
                              (period) => DropdownMenuItem(
                                value: period,
                                child: Text(period.name),
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
                                  ? 'Start date'
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
                                  ? 'End date'
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
                            labelText: 'Account ID',
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
                            labelText: 'Category ID',
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
                    label: const Text('Apply filters'),
                  ),
                  const SizedBox(height: 16),
                  if (isBusy) ...[
                    Semantics(
                      liveRegion: true,
                      label: 'Loading history',
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
                      label: const Text('Retry'),
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
                      label: const Text('Load more history'),
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
            'No entries match these filters',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Try a different search or a wider period.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});

  final HistoryItem item;

  @override
  Widget build(BuildContext context) {
    final primary = item.movements.isEmpty ? null : item.movements.first;
    final title = item.expense?.store ?? item.description ?? item.type.name;
    final subtitle = [
      item.type.name,
      if (item.incomeSource != null) item.incomeSource!,
      if (item.expense != null) '${item.expense!.items.length} items',
    ].join(' · ');
    return Card(
      key: Key('history-card-${item.id}'),
      clipBehavior: Clip.antiAlias,
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
          ],
        ),
      ),
    );
  }
}
