import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters/date_labels.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/money/currency_totals.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/time/clock_provider.dart';
import '../../accounts/application/account_balances.dart';
import '../../accounts/application/accounts_controller.dart';
import '../../accounts/application/accounts_state.dart';
import '../../accounts/domain/account_models.dart';
import '../../auth/session/application/auth_session_controller.dart';
import '../application/dashboard_currency_provider.dart';
import '../../expenses/application/expenses_controller.dart';
import '../../expenses/application/expenses_state.dart';
import '../../expenses/application/history_controller.dart';
import '../../expenses/application/monthly_totals.dart';
import '../../expenses/presentation/transaction_visuals.dart';
import '../../incomes/data/incomes_repository.dart';
import '../application/dashboard_metrics.dart';
import '../application/dashboard_summary_provider.dart';
import 'spending_trend.dart';
import 'spending_trend_card.dart';
import 'widgets/insights_card.dart';

/// Resumen y tendencias.
///
/// The balance card uses the same definition as the Gastos hub: stock (the sum
/// of the live balances of the active accounts, per currency) plus the current
/// month's flow chips, both from `activeAccountBalances` and
/// `monthlyTotalsProvider`. The category breakdown is month-scoped too, so it
/// cannot contradict the header of the same screen.
class DashboardAnalysisScreen extends ConsumerStatefulWidget {
  const DashboardAnalysisScreen({super.key});

  @override
  ConsumerState<DashboardAnalysisScreen> createState() =>
      _DashboardAnalysisScreenState();
}

class _DashboardAnalysisScreenState
    extends ConsumerState<DashboardAnalysisScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) return;
      if (ref.read(expensesControllerProvider).listStatus ==
          ExpensesLoadStatus.initial) {
        ref.read(expensesControllerProvider.notifier).load();
      }
      if (ref.read(accountsControllerProvider).listStatus ==
          AccountsLoadStatus.initial) {
        ref.read(accountsControllerProvider.notifier).load();
      }
      ref.read(incomesListProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(accountsControllerProvider).result?.accounts ??
        const <Account>[];
    final supportedCurrencies = ref
        .watch(accountsControllerProvider)
        .result
        ?.supportedCurrencies;
    final preferredCurrency =
        ref.watch(authSessionControllerProvider).user?.preferredCurrency ??
        'COP';
    final selectedCurrency = ref.watch(dashboardCurrencyProvider);

    final now = ref.watch(clockProvider)();
    final stock = activeAccountBalances(accounts);
    final period = ref.watch(dashboardPeriodProvider);
    final customRange = ref.watch(dashboardCustomRangeProvider);
    final window = period == DashboardPeriod.thisMonth
        ? currentMonthWindow(now)
        : periodWindow(period, now, customRange: customRange);
    final windowName = period == DashboardPeriod.thisMonth
        ? DateLabels.monthName(now)
        : periodLabel(period, now, customRange: customRange);
    final monthTotalsAsync = ref.watch(periodTotalsProvider);
    final monthlyTotals = monthTotalsAsync.value;

    final availableCodes = <String>{
      preferredCurrency,
      ...?supportedCurrencies?.map((currency) => currency.code),
      ...stock.keys,
      ...?monthlyTotals?.byCurrency.keys,
    }.toList()..sort();
    final currencyTotalsByCode = <String, CurrencyTotals>{
      ...stock,
      ...?monthlyTotals?.byCurrency,
    };
    for (final code in availableCodes) {
      currencyTotalsByCode.putIfAbsent(code, () => const CurrencyTotals());
    }
    final orderedCodes = orderedCurrencyCodes(
      currencyTotalsByCode,
      preferred: selectedCurrency ?? preferredCurrency,
    );
    final currency = availableCodes.contains(selectedCurrency)
        ? selectedCurrency!
        : orderedCodes.firstOrNull ?? preferredCurrency;
    final breakdown = _breakdownFor(monthlyTotals, currency);
    // Tendency: daily bars for short windows, weekly for longer ones, monthly
    // buckets for the year. Longer windows show the last 30 days worth of
    final useYear = period == DashboardPeriod.thisYear;
    final trendWeeks = useYear
        ? monthlyExpenseSeries(
            items: monthlyTotals?.expenseItems ?? const [],
            currencyCode: currency,
            windowStart: window.start,
            windowEnd: window.end,
          )
        : null;
    final trend = dailyExpenseSeries(
      items: monthlyTotals?.expenseItems ?? const [],
      currencyCode: currency,
      now: now,
      maxDays: useYear ? 365 : 14,
      windowStart: window.start,
      windowEnd: window.end,
    );
    final cumulative = cumulativeExpenseSeries(
      items: monthlyTotals?.expenseItems ?? const [],
      currencyCode: currency,
      windowStart: window.start,
      windowEnd: window.end,
      asOf: now,
    );
    final totalDaysInWindow = window.end.difference(window.start).inDays + 1;
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    // Riverpod may retain the previous currency's value while the request for
    // the newly selected currency is loading. Keep local, currency-scoped
    // totals visible, but don't reuse currency-dependent summary metrics.
    final summary = summaryAsync.isLoading ? null : summaryAsync.value;
    final summaryMatchesWindow =
        summary != null &&
        summary.period.start.year == window.start.year &&
        summary.period.start.month == window.start.month &&
        summary.period.start.day == window.start.day &&
        summary.period.end.year == window.end.year &&
        summary.period.end.month == window.end.month &&
        summary.period.end.day == window.end.day;
    final isCurrent = period == DashboardPeriod.thisMonth;

    // Honest badge: check summary first if available, otherwise fallback to compareWindows.
    final totals = monthlyTotals?.byCurrency[currency];
    final comparison = summaryMatchesWindow
        ? (
            ratio: summary.comparison.pct != null
                ? (summary.comparison.direction == 'down'
                      ? (1.0 - (summary.comparison.pct! / 100.0))
                      : (1.0 + (summary.comparison.pct! / 100.0)))
                : 1.0,
            direction: summary.comparison.direction,
          )
        : ((monthlyTotals?.historyComplete == true &&
                  monthlyTotals?.previousHistoryComplete == true &&
                  (period == DashboardPeriod.lastMonth ||
                      (isCurrent && now.day == window.end.day)))
              ? compareWindows(
                  current: totals?.expenses ?? 0,
                  previous:
                      monthlyTotals?.previousExpensesByCurrency[currency] ?? 0,
                )
              : null);
    final comparisonLabel = _comparisonLabel(
      comparison,
      window,
      now,
      previousStart: summaryMatchesWindow
          ? summary.comparison.previousStart
          : null,
      previousEnd: summaryMatchesWindow ? summary.comparison.previousEnd : null,
    );
    final int daysTotal = totalDaysInWindow;
    final int daysElapsed = summaryMatchesWindow
        ? summary.period.daysElapsed
        : now.isBefore(window.start)
        ? 0
        : now.isAfter(window.end)
        ? daysTotal
        : DateTime(now.year, now.month, now.day)
                  .difference(
                    DateTime(
                      window.start.year,
                      window.start.month,
                      window.start.day,
                    ),
                  )
                  .inDays +
              1;

    final insights = summaryMatchesWindow
        ? DashboardMetrics.buildInsights(
            summary: summary,
            currencyCode: currency,
          )
        : const <DashboardInsight>[];

    final expenses = totals?.expenses ?? 0;
    final monthAvailable = monthTotalsAsync.hasValue || summaryMatchesWindow;

    final int? trendProjectedMinorUnits;
    if (monthlyTotals?.historyComplete == true &&
        daysElapsed > 0 &&
        daysElapsed < totalDaysInWindow) {
      final currentSpend = cumulative.isNotEmpty
          ? cumulative.last.cumulativeMinorUnits
          : 0;
      if (currentSpend <= 0) {
        trendProjectedMinorUnits = null;
      } else {
        // Keep cumulative spending monotonic: estimates never fall below what
        // has already been spent. Other periods use a simple daily-pace model.
        final paceEstimate = (currentSpend / daysElapsed * totalDaysInWindow)
            .round();
        final monthEstimate =
            period == DashboardPeriod.thisMonth && summaryMatchesWindow
            ? summary.projection.projected.minorUnits
            : null;
        trendProjectedMinorUnits = monthEstimate != null && monthEstimate > 0
            ? (monthEstimate > currentSpend ? monthEstimate : currentSpend)
            : paceEstimate;
      }
    } else {
      trendProjectedMinorUnits = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Análisis'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Semantics(
                label: 'Moneda del análisis: $currency',
                child: Text(
                  currency,
                  style: TextStyle(
                    color: context.palette.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(FinanceIcons.arrowBack),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.only(top: 16, bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  daysElapsed > 0
                      ? 'Proyección: gasto acumulado ÷ $daysElapsed días observados × $daysTotal días del periodo. Corte: ${now.day} de ${DateLabels.monthName(now)}. Los porcentajes comparan el rango indicado; los importes se mantienen en $currency.'
                      : 'Aún no hay días observados para proyectar este periodo. Los importes se mantienen en $currency.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: context.palette.muted,
                  ),
                ),
              ),
              if (monthTotalsAsync.hasError)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No pudimos cargar el análisis. Revisa tu conexión e inténtalo de nuevo.',
                          ),
                          TextButton(
                            onPressed: () {
                              ref.invalidate(periodTotalsProvider);
                              ref.invalidate(dashboardSummaryProvider);
                            },
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              _DashboardAnalysis(
                key: const ValueKey('dashboard-analysis-panel'),
                currency: currency,
                available: monthAvailable,
                spentMinorUnits: expenses,
                comparisonLabel: comparisonLabel,
                comparisonDirection: comparison?.direction,
                topCategory: breakdown.firstOrNull?.category,
                insights: insights,
                breakdown: breakdown,
                window: window,
                windowName: windowName,
                trend: trend,
                trendWeeks: trendWeeks,
                cumulative: cumulative,
                totalDaysInWindow: totalDaysInWindow,
                projectedMinorUnits: trendProjectedMinorUnits,
                period: period,
                customRange: customRange,
                onSelectPeriod: (value) async {
                  if (value == DashboardPeriod.custom) {
                    final picked = await showDateRangePicker(
                      context: context,
                      initialEntryMode: DatePickerEntryMode.input,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                      initialDateRange: customRange != null
                          ? DateTimeRange(
                              start: DateTime(
                                customRange.start.year,
                                customRange.start.month,
                                customRange.start.day,
                              ),
                              end: DateTime(
                                customRange.end.year,
                                customRange.end.month,
                                customRange.end.day,
                              ),
                            )
                          : DateTimeRange(
                              start: now.subtract(const Duration(days: 30)),
                              end: now,
                            ),
                      helpText: 'Seleccionar periodo de análisis',
                      confirmText: 'Aplicar',
                      cancelText: 'Cancelar',
                    );
                    if (picked != null) {
                      ref
                          .read(dashboardCustomRangeProvider.notifier)
                          .setRange(picked.start, picked.end);
                      ref
                          .read(dashboardPeriodProvider.notifier)
                          .select(DashboardPeriod.custom);
                    }
                  } else {
                    ref.read(dashboardPeriodProvider.notifier).select(value);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The window's expenses in [currency], grouped by category with the top
  /// merchant of each group (that's the "dónde se va" answer).
  List<_BreakdownRow> _breakdownFor(MonthlyTotals? totals, String currency) {
    if (totals == null) {
      return const [];
    }
    final byCategory = <String, _CategoryAcc>{};
    for (final item in totals.expenseItems) {
      if (item.movements.isEmpty) {
        continue;
      }
      final movement = item.movements.first;
      if (movement.currencyCode != currency) {
        continue;
      }
      final minorUnits = movement.amount.minorUnits.abs();
      final category = item.expense?.items.firstOrNull?.category?.name;
      final key = category ?? '';
      final acc = byCategory.putIfAbsent(key, () => _CategoryAcc());
      acc.total += minorUnits;
      final store = (item.expense?.store ?? '').trim();
      if (store.isNotEmpty) {
        acc.stores[store] = (acc.stores[store] ?? 0) + minorUnits;
      }
      final itemCategoryId = item.expense?.items.firstOrNull?.category?.id;
      if (itemCategoryId != null && itemCategoryId > 0) {
        acc.categoryId ??= itemCategoryId;
      }
    }
    final rows = <_BreakdownRow>[];
    for (final entry in byCategory.entries) {
      final acc = entry.value;
      final topStore = acc.stores.entries.fold<MapEntry<String, int>?>(null, (
        best,
        e,
      ) {
        if (best == null || e.value > best.value) return e;
        return best;
      });
      rows.add(
        _BreakdownRow(
          category: entry.key.isEmpty ? null : entry.key,
          categoryId: acc.categoryId,
          title: topStore?.key ?? 'Varios comercios',
          minorUnits: acc.total,
        ),
      );
    }
    rows.sort((a, b) => b.minorUnits.compareTo(a.minorUnits));
    return rows;
  }
}

class _DashboardAnalysis extends StatefulWidget {
  const _DashboardAnalysis({
    super.key,
    required this.trend,
    required this.trendWeeks,
    required this.currency,
    required this.available,
    required this.spentMinorUnits,
    required this.comparisonLabel,
    required this.comparisonDirection,
    required this.topCategory,
    required this.insights,
    required this.breakdown,
    required this.window,
    required this.windowName,
    required this.cumulative,
    required this.totalDaysInWindow,
    required this.period,
    required this.onSelectPeriod,
    this.customRange,
    this.projectedMinorUnits,
  });

  final List<DailySpend> trend;
  final List<WeeklySpend>? trendWeeks;
  final String currency;
  final bool available;
  final int spentMinorUnits;
  final String? comparisonLabel;
  final String? comparisonDirection;
  final String? topCategory;
  final List<DashboardInsight> insights;
  final List<_BreakdownRow> breakdown;
  final ({DateTime start, DateTime end}) window;
  final String windowName;
  final List<CumulativeSpendDay> cumulative;
  final int totalDaysInWindow;
  final int? projectedMinorUnits;
  final DashboardPeriod period;
  final ({DateTime start, DateTime end})? customRange;
  final ValueChanged<DashboardPeriod> onSelectPeriod;

  @override
  State<_DashboardAnalysis> createState() => _DashboardAnalysisState();
}

class _DashboardAnalysisState extends State<_DashboardAnalysis> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final periodName = widget.period == DashboardPeriod.thisMonth
        ? 'este mes'
        : widget.windowName;
    final title = 'Gastos $periodName';
    final amount = widget.available
        ? MoneyFormatter.display(widget.spentMinorUnits, widget.currency)
        : '—';
    final comparisonColor = switch (widget.comparisonDirection) {
      'up' => palette.discard,
      'down' => palette.income,
      _ => palette.muted,
    };
    final comparisonIcon = switch (widget.comparisonDirection) {
      'up' => FinanceIcons.trendingUp,
      'down' => FinanceIcons.trendingDown,
      _ => FinanceIcons.trendingFlat,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        key: const Key('dashboard-analysis'),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: palette.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          FinanceIcons.queryStatsRounded,
                          color: palette.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: palette.muted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              alignment: Alignment.centerLeft,
                              fit: BoxFit.scaleDown,
                              child: Text(
                                amount,
                                key: const Key('dashboard-spending-amount'),
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  color: palette.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (widget.comparisonLabel != null) ...[
                        Icon(comparisonIcon, size: 16, color: comparisonColor),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            widget.comparisonLabel!,
                            key: const Key('dashboard-spending-comparison'),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: comparisonColor,
                            ),
                          ),
                        ),
                      ] else if (widget.topCategory != null) ...[
                        Icon(
                          FinanceIcons.categoryOutlined,
                          size: 16,
                          color: palette.muted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Mayor categoría: ${widget.topCategory}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.muted,
                            ),
                          ),
                        ),
                      ] else
                        Expanded(
                          child: Text(
                            'Consulta la tendencia y los gastos por categoría.',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 0),
                    child: Semantics(
                      expanded: _expanded,
                      child: TextButton.icon(
                        key: const Key('dashboard-analysis-toggle'),
                        onPressed: () => setState(() {
                          _expanded = !_expanded;
                        }),
                        icon: Icon(
                          _expanded
                              ? FinanceIcons.expandLess
                              : FinanceIcons.expandMore,
                        ),
                        label: Text(
                          _expanded ? 'Ocultar análisis' : 'Ver análisis',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _DashboardPeriodSelector(
                            selected: widget.period,
                            customRange: widget.customRange,
                            onSelect: widget.onSelectPeriod,
                          ),
                          const SizedBox(height: 16),
                          SpendingTrendCard(
                            days: widget.trend,
                            currency: widget.currency,
                            available: widget.available,
                            cumulativeDays: widget.cumulative,
                            totalDaysInPeriod: widget.totalDaysInWindow,
                            projectedMinorUnits: widget.projectedMinorUnits,
                            weekly: widget.trendWeeks,
                            comparisonLabel: widget.comparisonLabel,
                            comparisonDirection: widget.comparisonDirection,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Gastos por categoría',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Movimientos de ${widget.windowName}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          widget.breakdown.isEmpty
                              ? _EmptyBreakdown(monthName: widget.windowName)
                              : _CategoryBreakdown(
                                  rows: widget.breakdown,
                                  currency: widget.currency,
                                  window: widget.window,
                                  windowName: widget.windowName,
                                ),
                          if (widget.insights.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            InsightsCard(insights: widget.insights),
                          ],
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryAcc {
  int total = 0;
  int? categoryId;
  final Map<String, int> stores = {};
}

/// Honest badge: `+48% vs ago`, `-12% vs sep`, `Igual que antes`, or null when
/// there is nothing to compare.
String? _comparisonLabel(
  ({double ratio, String direction})? comparison,
  ({DateTime start, DateTime end}) window,
  DateTime now, {
  DateTime? previousStart,
  DateTime? previousEnd,
}) {
  if (comparison == null) return null;
  final fallback = previousWindow(window);
  final prev = (
    start: previousStart ?? fallback.start,
    end: previousEnd ?? fallback.end,
  );
  final prevName = _comparisonRangeLabel(prev);
  switch (comparison.direction) {
    case 'up':
      if (comparison.ratio.isInfinite) return 'Gastando de nuevo';
      final pct = ((comparison.ratio - 1) * 100).round();
      return '+$pct% vs $prevName';
    case 'down':
      final pct = ((1 - comparison.ratio) * 100).round();
      return '-$pct% vs $prevName';
    case 'flat':
      return 'Igual que $prevName';
  }
  return null;
}

String _comparisonRangeLabel(({DateTime start, DateTime end}) range) {
  final startMonth = shortMonthName(range.start.month);
  final endMonth = shortMonthName(range.end.month);
  if (range.start.year != range.end.year) {
    return '${range.start.day} $startMonth ${range.start.year}–${range.end.day} $endMonth ${range.end.year}';
  }
  if (range.start.month != range.end.month) {
    return '${range.start.day} $startMonth–${range.end.day} $endMonth';
  }
  final lastDay = DateTime(range.end.year, range.end.month + 1, 0).day;
  if (range.start.day == 1 && range.end.day == lastDay) return startMonth;
  return '${range.start.day}–${range.end.day} $startMonth';
}

/// Quick period presets stay visible; the custom range opens the date picker
/// directly instead of hiding the periods inside a dropdown.
class _DashboardPeriodSelector extends StatelessWidget {
  const _DashboardPeriodSelector({
    required this.selected,
    required this.onSelect,
    this.customRange,
  });

  final DashboardPeriod selected;
  final ValueChanged<DashboardPeriod> onSelect;
  final ({DateTime start, DateTime end})? customRange;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final options = [
      (DashboardPeriod.thisMonth, 'Este mes'),
      (DashboardPeriod.lastMonth, 'Mes anterior'),
      (DashboardPeriod.last3Months, 'Últimos 3 meses'),
      (DashboardPeriod.thisYear, 'Este año'),
    ];
    final customLabel = customRange == null
        ? 'Fechas'
        : '${customRange!.start.day}/${customRange!.start.month}–${customRange!.end.day}/${customRange!.end.month}';

    return Semantics(
      label: 'Periodo de análisis',
      child: Wrap(
        key: const Key('dashboard-period-selector'),
        spacing: 8,
        runSpacing: 2,
        children: [
          for (final option in options)
            ChoiceChip(
              key: Key('dashboard-period-${option.$1.name}'),
              label: Text(option.$2),
              selected: selected == option.$1,
              showCheckmark: false,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              visualDensity: VisualDensity.standard,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected == option.$1 ? palette.primary : palette.text,
              ),
              selectedColor: palette.primarySoft,
              backgroundColor: palette.card,
              side: BorderSide(
                color: selected == option.$1 ? palette.primary : palette.line,
              ),
              onSelected: (_) => onSelect(option.$1),
            ),
          ChoiceChip(
            key: const Key('dashboard-period-custom'),
            avatar: const Icon(FinanceIcons.calendarMonthOutlined, size: 16),
            label: Text(customLabel),
            selected: selected == DashboardPeriod.custom,
            showCheckmark: false,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            visualDensity: VisualDensity.standard,
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected == DashboardPeriod.custom
                  ? palette.primary
                  : palette.text,
            ),
            selectedColor: palette.primarySoft,
            backgroundColor: palette.card,
            side: BorderSide(
              color: selected == DashboardPeriod.custom
                  ? palette.primary
                  : palette.line,
            ),
            onSelected: (_) => onSelect(DashboardPeriod.custom),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow {
  const _BreakdownRow({
    required this.category,
    required this.categoryId,
    required this.title,
    required this.minorUnits,
  });

  final String? category;

  /// Backend category id for the history drill-down. Null when the items
  /// carry no id (older captures): the row then navigates unfiltered.
  final int? categoryId;
  final String title;
  final int minorUnits;
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({
    required this.rows,
    required this.currency,
    required this.window,
    required this.windowName,
  });

  final List<_BreakdownRow> rows;

  /// Headline currency of the dashboard (single-currency rows).
  final String currency;

  /// Current window for the history drill-down.
  final ({DateTime start, DateTime end}) window;
  final String windowName;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final palette = context.palette;
        final visible = rows.take(5).toList();
        final total = rows.fold<int>(0, (s, r) => s + r.minorUnits);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.line),
          ),
          child: Column(
            children: [
              for (var index = 0; index < visible.length; index++) ...[
                if (index > 0) Divider(height: 1, color: palette.line),
                _BreakdownTile(
                  row: visible[index],
                  currency: currency,
                  share: total > 0 ? visible[index].minorUnits / total : 0,
                  onTap: () {
                    ref
                        .read(historyControllerProvider.notifier)
                        .showWindowForCategory(
                          categoryId: visible[index].categoryId,
                          startDate: window.start,
                          endDate: window.end,
                        );
                    context.push('/history');
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BreakdownTile extends StatelessWidget {
  const _BreakdownTile({
    required this.row,
    required this.currency,
    required this.share,
    required this.onTap,
  });

  final _BreakdownRow row;
  final String currency;
  final double share;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pct = (share * 100).round();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('dashboard-category-${row.category ?? 'sin-categoria'}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: palette.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    categoryIcon(row.category),
                    size: 16,
                    color: palette.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.category ?? 'Sin categoría',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: palette.text,
                            ),
                          ),
                        ),
                        Text(
                          '$pct%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: palette.text,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      row.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: palette.muted),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: share.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: palette.soft,
                        color: palette.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    MoneyFormatter.display(
                      -row.minorUnits,
                      currency,
                      signed: true,
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: palette.discard,
                    ),
                  ),
                  Icon(
                    FinanceIcons.chevronRight,
                    size: 16,
                    color: palette.muted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBreakdown extends StatelessWidget {
  const _EmptyBreakdown({required this.monthName});

  final String monthName;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              FinanceIcons.analyticsOutlined,
              size: 36,
              color: palette.primary,
            ),
            const SizedBox(height: 10),
            Text(
              'Sin datos suficientes',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Registra gastos de $monthName para ver el desglose.',
              style: TextStyle(fontSize: 12, color: palette.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// The month totals could not be read: say so instead of showing a fake zero.
