import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters/date_labels.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/money/currency_totals.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/time/clock_provider.dart';
import '../../../core/widgets/app_header.dart';
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
import '../../expenses/application/monthly_totals.dart';
import '../../expenses/presentation/transaction_visuals.dart';
import '../../incomes/data/incomes_repository.dart';
import 'spending_trend.dart';
import 'spending_trend_card.dart';

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
    // Tendency reuses the window items already loaded above: no new request,
    // no new package, one currency at a time. Longer windows still show the
    // last 30 days so the bars stay readable.
    final trend = dailyExpenseSeries(
      items: monthlyTotals?.expenseItems ?? const [],
      currencyCode: currency,
      now: now,
      maxDays: period == DashboardPeriod.thisYear ? 30 : 14,
      windowStart: window.start,
      windowEnd: window.end,
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(
              title: 'Dashboard',
              subtitle: 'Resumen y tendencias',
              actions: [ThemeToggleButton()],
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _DashboardPeriodChips(
                        selected: period,
                        onSelect: (value) => ref
                            .read(dashboardPeriodProvider.notifier)
                            .select(value),
                      ),
                      const SizedBox(height: 12),
                      _DashboardBalanceCard(
                        currency: currency,
                        otherCodes: otherCodes,
                        stock: stock,
                        monthTotals: monthlyTotals?.byCurrency ?? const {},
                        monthName: windowName,
                        monthAvailable: monthTotalsAsync.hasValue,
                      ),
                      if (monthTotalsAsync.hasError) ...[
                        const SizedBox(height: 12),
                        _MonthTotalsError(
                          onRetry: () => ref.invalidate(periodTotalsProvider),
                        ),
                      ],
                      const SizedBox(height: 24),

                      SpendingTrendCard(
                        days: trend,
                        currency: currency,
                        available: monthTotalsAsync.hasValue,
                      ),
                      const SizedBox(height: 24),

                      BudgetDashboardSection(
                        state: budgetsState,
                        onRetry: ref
                            .read(budgetsControllerProvider.notifier)
                            .load,
                        onManage: () => context.go('/budgets'),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Gastos por categoría',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Movimientos de $windowName',
                        style: TextStyle(fontSize: 11, color: palette.muted),
                      ),
                      const SizedBox(height: 12),

                      if (breakdown.isEmpty)
                        _EmptyBreakdown(monthName: windowName)
                      else
                        _CategoryBreakdown(rows: breakdown),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The month's expenses in [currency], as the category breakdown rows.
  List<_BreakdownRow> _breakdownFor(MonthlyTotals? totals, String currency) {
    if (totals == null) {
      return const [];
    }
    final rows = <_BreakdownRow>[];
    for (final item in totals.expenseItems) {
      if (item.movements.isEmpty) {
        continue;
      }
      final movement = item.movements.first;
      if (movement.currencyCode != currency) {
        continue;
      }
      rows.add(
        _BreakdownRow(
          category: item.expense?.items.firstOrNull?.category?.name,
          title: item.expense?.store ?? item.description ?? 'Gasto',
          minorUnits: movement.amount.minorUnits.abs(),
        ),
      );
    }
    rows.sort((a, b) => b.minorUnits.compareTo(a.minorUnits));
    return rows;
  }
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

/// The Dashboard balance card: stock headline + the window's flow chips.
class _DashboardBalanceCard extends StatelessWidget {
  const _DashboardBalanceCard({
    required this.currency,
    required this.otherCodes,
    required this.stock,
    required this.monthTotals,
    required this.monthName,
    required this.monthAvailable,
  });

  final String currency;
  final List<String> otherCodes;
  final Map<String, CurrencyTotals> stock;
  final Map<String, CurrencyTotals> monthTotals;
  final String monthName;

  /// False while the month totals load or fail: the chips show `—` then.
  final bool monthAvailable;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final totals = monthTotals[currency] ?? const CurrencyTotals();
    final incomesLabel = monthAvailable
        ? MoneyFormatter.formatSignedMinorUnits(totals.incomes)
        : '—';
    final expensesLabel = monthAvailable
        ? '-${MoneyFormatter.formatMinorUnits(totals.expenses)}'
        : '—';

    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(
            'Saldo en cuentas',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${MoneyFormatter.formatMinorUnits(stock[currency]?.balance ?? 0)} $currency',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: palette.text,
              letterSpacing: -0.5,
            ),
          ),
          for (final code in otherCodes) ...[
            const SizedBox(height: 2),
            Text(
              '${MoneyFormatter.formatMinorUnits(stock[code]?.balance ?? 0)} $code',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.muted,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Movimientos de $monthName',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _FlowChip(
                  label: 'Ingresos',
                  value: incomesLabel,
                  color: palette.income,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FlowChip(
                  label: 'Gastos',
                  value: expensesLabel,
                  color: palette.discard,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Income/expense chip of the month (`+ $ 500.000` / `- $ 25.000`).
class _FlowChip extends StatelessWidget {
  const _FlowChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: palette.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
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
    required this.title,
    required this.minorUnits,
  });

  final String? category;
  final String title;
  final int minorUnits;
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.rows});

  final List<_BreakdownRow> rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final visible = rows.take(5).toList();
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
            Padding(
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
                        categoryEmoji(visible[index].category),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visible[index].category ?? 'Sin categoría',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: palette.text,
                          ),
                        ),
                        Text(
                          visible[index].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: palette.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '-${MoneyFormatter.formatMinorUnits(visible[index].minorUnits)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: palette.discard,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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
