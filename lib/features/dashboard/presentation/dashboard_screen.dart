import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters/date_labels.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/money/currency_totals.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/time/clock_provider.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../accounts/application/account_balances.dart';
import '../../accounts/application/accounts_controller.dart';
import '../../accounts/application/accounts_state.dart';
import '../../accounts/domain/account_models.dart';
import '../../auth/session/application/auth_session_controller.dart';
import '../../budgets/application/budgets_controller.dart';
import '../../budgets/application/budgets_state.dart';
import '../../budgets/presentation/budget_dashboard_section.dart';
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
import 'widgets/daily_allowance_card.dart';
import 'widgets/insights_card.dart';

/// Resumen y tendencias.
///
/// The balance card uses the same definition as the Gastos hub: stock (the sum
/// of the live balances of the active accounts, per currency) plus the current
/// month's flow chips, both from `activeAccountBalances` and
/// `monthlyTotalsProvider`. The category breakdown is month-scoped too, so it
/// cannot contradict the header of the same screen.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
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
      if (ref.read(budgetsControllerProvider).loadStatus ==
          BudgetsLoadStatus.initial) {
        ref.read(budgetsControllerProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accounts =
        ref.watch(accountsControllerProvider).result?.accounts ??
        const <Account>[];
    final budgetsState = ref.watch(budgetsControllerProvider);
    final preferredCurrency =
        ref.watch(authSessionControllerProvider).user?.preferredCurrency ??
        'COP';

    final now = ref.watch(clockProvider)();
    final stock = activeAccountBalances(accounts);
    final period = ref.watch(dashboardPeriodProvider);
    final window = period == DashboardPeriod.thisMonth
        ? currentMonthWindow(now)
        : periodWindow(period, now);
    final windowName = period == DashboardPeriod.thisMonth
        ? DateLabels.monthName(now)
        : periodLabel(period, now);
    final monthTotalsAsync = ref.watch(periodTotalsProvider);
    final monthlyTotals = monthTotalsAsync.value;

    final orderedCodes = orderedCurrencyCodes({
      ...stock,
      ...?monthlyTotals?.byCurrency,
    }, preferred: preferredCurrency);
    final currency = orderedCodes.isEmpty
        ? preferredCurrency
        : orderedCodes.first;
    final otherCodes = orderedCodes.where((code) => code != currency).toList();
    final breakdown = _breakdownFor(monthlyTotals, currency);
    // Tendency: daily bars for short windows, weekly for longer ones, monthly
    // buckets for the year. Longer windows show the last 30 days worth of
    // buckets so bars keep volume instead of turning into zero-filled noise.
    final useYear = period == DashboardPeriod.thisYear;
    final useWeeks =
        !useYear && window.end.difference(window.start).inDays > 21;
    final trendWeeks = useYear
        ? monthlyExpenseSeries(
            items: monthlyTotals?.expenseItems ?? const [],
            currencyCode: currency,
            windowStart: window.start,
            windowEnd: window.end,
          )
        : useWeeks
        ? weeklyExpenseSeries(
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
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final summary = summaryAsync.value;

    // Honest badge: check summary first if available, otherwise fallback to compareWindows.
    final totals = monthlyTotals?.byCurrency[currency];
    final comparison = summary != null
        ? (
            ratio: summary.comparison.pct != null
                ? (summary.comparison.direction == 'down'
                      ? (1.0 - (summary.comparison.pct! / 100.0))
                      : (1.0 + (summary.comparison.pct! / 100.0)))
                : 1.0,
            direction: summary.comparison.direction,
          )
        : compareWindows(
            current: totals?.expenses ?? 0,
            previous: monthlyTotals?.previousExpensesByCurrency[currency] ?? 0,
          );
    final comparisonLabel = _comparisonLabel(comparison, window, now);
    final bucketTotal = useYear || useWeeks
        ? (trendWeeks ?? const <WeeklySpend>[]).fold<int>(
            0,
            (s, w) => s + w.minorUnits,
          )
        : trend.fold<int>(0, (s, d) => s + d.minorUnits);
    final bucketCount = useYear || useWeeks
        ? (trendWeeks?.length ?? 0)
        : trend.length;
    final average = bucketCount > 0
        ? (bucketTotal / bucketCount).round()
        : null;

    final isCurrent = period == DashboardPeriod.thisMonth;
    final int daysElapsed =
        summary?.period.daysElapsed ??
        (isCurrent ? now.day : window.end.difference(window.start).inDays + 1);
    final int daysTotal =
        summary?.period.daysTotal ??
        (window.end.difference(window.start).inDays + 1);

    final dailyAllowance = summary != null
        ? DashboardMetrics.calculateDailyAllowance(summary: summary)
        : null;

    final insights = summary != null
        ? DashboardMetrics.buildInsights(
            summary: summary,
            currencyCode: currency,
          )
        : const <DashboardInsight>[];

    final incomes = totals?.incomes ?? 0;
    final expenses = totals?.expenses ?? 0;
    final saved = incomes - expenses;
    final monthAvailable = monthTotalsAsync.hasValue || summary != null;
    final incomesLabel = monthAvailable
        ? MoneyFormatter.display(incomes, currency, signed: true)
        : '—';
    final expensesLabel = monthAvailable
        ? MoneyFormatter.display(-expenses, currency, signed: true)
        : '—';
    final user = ref.watch(authSessionControllerProvider).user;
    final userName = user?.email.split('@').firstOrNull;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  _HeroHeader(
                    currency: currency,
                    otherCodes: otherCodes,
                    stock: stock,
                    monthName: windowName,
                    incomesLabel: incomesLabel,
                    expensesLabel: expensesLabel,
                    userName: userName,
                  ),
                  Positioned(
                    bottom: -22,
                    left: 16,
                    right: 16,
                    child: _ExecutiveMetricsCard(
                      dailyAllowance: dailyAllowance,
                      averageMinorUnits: average,
                      savedMinorUnits: saved,
                      currency: currency,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _DashboardPeriodChips(
                  selected: period,
                  onSelect: (value) =>
                      ref.read(dashboardPeriodProvider.notifier).select(value),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _PeriodNetFlowCard(
                  currency: currency,
                  monthTotals: monthlyTotals?.byCurrency ?? const {},
                  monthName: windowName,
                  monthAvailable: monthAvailable,
                  isCurrent: isCurrent,
                  daysElapsed: daysElapsed,
                  daysTotal: daysTotal,
                ),
              ),
              if (monthTotalsAsync.hasError && summaryAsync.hasError) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _MonthTotalsError(
                    onRetry: () {
                      ref.invalidate(periodTotalsProvider);
                      ref.invalidate(dashboardSummaryProvider);
                    },
                  ),
                ),
              ],
              if (isCurrent && dailyAllowance != null && summary != null) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DailyAllowanceCard(
                    dailyAllowanceMinorUnits: dailyAllowance,
                    spentMtdMinorUnits: summary.projection.spentMtd.minorUnits,
                    projectedMinorUnits:
                        summary.projection.projected.minorUnits,
                    remainingDays: daysTotal > daysElapsed
                        ? (daysTotal - daysElapsed)
                        : 0,
                    currency: currency,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SpendingTrendCard(
                  days: trend,
                  currency: currency,
                  available: monthAvailable,
                  weekly: trendWeeks,
                  comparisonLabel: comparisonLabel,
                  comparisonDirection: comparison?.direction,
                  averageMinorUnits: average,
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: BudgetDashboardSection(
                  state: budgetsState,
                  onRetry: ref.read(budgetsControllerProvider.notifier).load,
                  onManage: () => context.go('/budgets'),
                ),
              ),
              if (insights.isNotEmpty) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: InsightsCard(insights: insights),
                ),
              ],
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Gastos por categoría',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Movimientos de $windowName',
                  style: TextStyle(fontSize: 11, color: palette.muted),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: breakdown.isEmpty
                    ? _EmptyBreakdown(monthName: windowName)
                    : _CategoryBreakdown(
                        rows: breakdown,
                        currency: currency,
                        window: window,
                        windowName: windowName,
                      ),
              ),
              const SizedBox(height: 80),
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
  DateTime now,
) {
  if (comparison == null) return null;
  final prev = previousWindow(window);
  final isMultiMonth = prev.start.month != prev.end.month;
  final prevName = isMultiMonth
      ? '${shortMonthName(prev.start.month)}\u2013${shortMonthName(prev.end.month)}'
      : shortMonthName(prev.start.month);
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

/// Window presets above the balance card: Este mes / Mes anterior /
/// Últimos 3 meses / Este año. Reuses the history screen chip look.
class _DashboardPeriodChips extends StatelessWidget {
  const _DashboardPeriodChips({required this.selected, required this.onSelect});

  final DashboardPeriod selected;
  final ValueChanged<DashboardPeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const options = [
      (DashboardPeriod.thisMonth, 'Este mes'),
      (DashboardPeriod.lastMonth, 'Mes anterior'),
      (DashboardPeriod.last3Months, 'Últimos 3 meses'),
      (DashboardPeriod.thisYear, 'Este año'),
    ];
    return Semantics(
      label: 'Periodo del dashboard',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            _PeriodChip(
              label: option.$2,
              selected: option.$1 == selected,
              onTap: () => onSelect(option.$1),
              palette: palette,
            ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.palette,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('dashboard-period-$label'),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? palette.primary : palette.card,
          border: Border.all(color: selected ? palette.primary : palette.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? palette.onPrimary : palette.muted,
          ),
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.currency,
    required this.otherCodes,
    required this.stock,
    required this.monthName,
    required this.incomesLabel,
    required this.expensesLabel,
    this.userName,
  });

  final String currency;
  final List<String> otherCodes;
  final Map<String, CurrencyTotals> stock;
  final String monthName;
  final String incomesLabel;
  final String expensesLabel;
  final String? userName;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final totalBalance = stock[currency]?.balance ?? 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.primary, palette.primaryDark],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 42),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName != null && userName!.isNotEmpty
                            ? 'Hola, $userName'
                            : 'Finance AI',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: palette.onPrimary.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Inicio',
                        key: const Key('home-title'),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: palette.onPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: palette.onPrimary.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$currency ▾',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: palette.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconTheme(
                        data: IconThemeData(color: palette.onPrimary),
                        child: const ThemeToggleButton(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Saldo en cuentas',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.onPrimary.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                MoneyFormatter.display(totalBalance, currency),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: palette.onPrimary,
                  letterSpacing: -0.8,
                ),
              ),
              for (final code in otherCodes) ...[
                const SizedBox(height: 2),
                Text(
                  MoneyFormatter.display(stock[code]?.balance ?? 0, code),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.onPrimary.withValues(alpha: 0.8),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  _HeroFlowChip(
                    icon: Icons.arrow_upward_rounded,
                    label: 'Ingresos',
                    value: incomesLabel,
                    color: palette.onPrimary,
                    backgroundColor: palette.onPrimary.withValues(alpha: 0.18),
                  ),
                  _HeroFlowChip(
                    icon: Icons.arrow_downward_rounded,
                    label: 'Gastos',
                    value: expensesLabel,
                    color: palette.onPrimary,
                    backgroundColor: palette.onPrimary.withValues(alpha: 0.18),
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

class _HeroFlowChip extends StatelessWidget {
  const _HeroFlowChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.backgroundColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutiveMetricsCard extends StatelessWidget {
  const _ExecutiveMetricsCard({
    required this.dailyAllowance,
    required this.averageMinorUnits,
    required this.savedMinorUnits,
    required this.currency,
  });

  final int? dailyAllowance;
  final int? averageMinorUnits;
  final int savedMinorUnits;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isPositive = savedMinorUnits >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _MetricColumn(
              label: 'Hoy puedes',
              value: dailyAllowance != null
                  ? MoneyFormatter.display(dailyAllowance!, currency)
                  : '—',
              valueColor: palette.primary,
            ),
          ),
          Container(width: 1, height: 36, color: palette.line),
          Expanded(
            child: _MetricColumn(
              label: 'Promedio/día',
              value: averageMinorUnits != null
                  ? MoneyFormatter.display(averageMinorUnits!, currency)
                  : '—',
              valueColor: palette.text,
            ),
          ),
          Container(width: 1, height: 36, color: palette.line),
          Expanded(
            child: _MetricColumn(
              label: 'Fin de mes',
              value: MoneyFormatter.display(
                savedMinorUnits,
                currency,
                signed: true,
              ),
              valueColor: isPositive ? palette.income : palette.discard,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: palette.muted,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _PeriodNetFlowCard extends StatelessWidget {
  const _PeriodNetFlowCard({
    required this.currency,
    required this.monthTotals,
    required this.monthName,
    required this.monthAvailable,
    required this.isCurrent,
    required this.daysElapsed,
    required this.daysTotal,
  });

  final String currency;
  final Map<String, CurrencyTotals> monthTotals;
  final String monthName;
  final bool monthAvailable;
  final bool isCurrent;
  final int daysElapsed;
  final int daysTotal;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final totals = monthTotals[currency] ?? const CurrencyTotals();
    final incomes = totals.incomes;
    final expenses = totals.expenses;
    final saved = incomes - expenses;
    final positive = saved >= 0;

    final progressPct = (daysTotal > 0 && daysElapsed > 0)
        ? (daysElapsed / daysTotal).clamp(0.0, 1.0)
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Movimientos de $monthName',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
              if (isCurrent && progressPct != null)
                Text(
                  'Día $daysElapsed de $daysTotal (${(progressPct * 100).round()}%)',
                  style: TextStyle(fontSize: 11, color: palette.muted),
                ),
            ],
          ),
          if (isCurrent && progressPct != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressPct,
                backgroundColor: palette.soft,
                valueColor: AlwaysStoppedAnimation<Color>(palette.primary),
                minHeight: 4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  positive ? Icons.check_circle_outline : Icons.error_outline,
                  size: 18,
                  color: positive ? palette.income : palette.discard,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Balance de $monthName',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: palette.muted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            positive ? 'Ahorro' : 'Déficit',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: positive
                                  ? palette.income
                                  : palette.discard,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        positive
                            ? 'Superávit del periodo'
                            : 'Gastos superan ingresos',
                        style: TextStyle(fontSize: 10, color: palette.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  !monthAvailable
                      ? '—'
                      : MoneyFormatter.display(saved, currency, signed: true),
                  key: const Key('dashboard-savings-amount'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: positive ? palette.income : palette.discard,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One expense of the month, for the category breakdown.
@immutable
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
                  child: Text(
                    categoryEmoji(row.category),
                    style: const TextStyle(fontSize: 14),
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
                  Icon(Icons.chevron_right, size: 16, color: palette.muted),
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
            const Text('📊', style: TextStyle(fontSize: 36)),
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
class _MonthTotalsError extends StatelessWidget {
  const _MonthTotalsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Icon(Icons.error_outline, size: 16, color: palette.discard),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'No pudimos calcular los movimientos del mes.',
            style: TextStyle(fontSize: 12, color: palette.muted),
          ),
        ),
        TextButton(
          key: const Key('dashboard-month-totals-retry'),
          onPressed: onRetry,
          child: const Text('Reintentar'),
        ),
      ],
    );
  }
}
