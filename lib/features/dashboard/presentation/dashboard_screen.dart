import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters/date_labels.dart';
import '../../../core/diagnostics/error_diagnostic.dart';
import '../../../core/diagnostics/error_diagnostic_panel.dart';
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
import '../../expenses/application/expenses_controller.dart';
import '../../expenses/application/expenses_state.dart';
import '../../expenses/application/monthly_totals.dart';
import '../application/dashboard_currency_provider.dart';
import '../application/home_financial_metrics.dart';

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
      if (ref.read(budgetsControllerProvider).loadStatus ==
          BudgetsLoadStatus.initial) {
        ref.read(budgetsControllerProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    final user = ref.watch(authSessionControllerProvider).user;
    final preferredCurrency = user?.preferredCurrency ?? 'COP';
    final selectedCurrency = ref.watch(dashboardCurrencyProvider);
    final accounts =
        ref.watch(accountsControllerProvider).result?.accounts ??
        const <Account>[];
    final budgets = ref.watch(budgetsControllerProvider);
    final totalsAsync = ref.watch(monthlyTotalsProvider);
    final currentWindow = currentMonthWindow(now);
    final loadedTotals = totalsAsync.value;
    final totals =
        loadedTotals != null &&
            _sameCalendarDay(loadedTotals.monthStart, currentWindow.start) &&
            _sameCalendarDay(loadedTotals.windowEnd, currentWindow.end)
        ? loadedTotals
        : null;
    final stock = activeAccountBalances(accounts);
    final currencyOptions = <String>{
      preferredCurrency,
      ...?ref
          .watch(accountsControllerProvider)
          .result
          ?.supportedCurrencies
          .map((item) => item.code),
      ...stock.keys,
      ...?totals?.byCurrency.keys,
    }.toList()..sort();
    final currency = selectedCurrency ?? preferredCurrency;
    final currencyTotals = totals?.byCurrency[currency];
    final incomes = currencyTotals?.incomes ?? 0;
    final expenses = currencyTotals?.expenses ?? 0;
    final saved = incomes - expenses;
    final hasTotals = totals != null;
    final previousWindowRange = previousWindow((
      start: totals?.monthStart ?? DateTime(now.year, now.month),
      end: totals?.windowEnd ?? now,
    ));
    final weekly = HomeFinancialMetrics.buildWeeklyInsight(
      expenseItems: [
        ...?totals?.previousExpenseItems,
        ...?totals?.expenseItems,
      ],
      currencyCode: currency,
      now: now,
      coverageStart: previousWindowRange.start,
      coverageEnd: totals?.windowEnd ?? now,
      historyIsComplete:
          totals?.historyComplete == true &&
          totals?.previousHistoryComplete == true,
    );
    final projection = HomeFinancialMetrics.buildMonthlyProjection(
      expenseItems: totals?.expenseItems ?? const [],
      currencyCode: currency,
      now: now,
      coverageStart: totals?.monthStart ?? DateTime(now.year, now.month),
      coverageEnd: totals?.windowEnd ?? now,
      historyIsComplete: totals?.historyComplete ?? false,
    );
    final displayName = user?.email.split('@').firstOrNull;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                _HomeHeader(
                  name: displayName,
                  currency: currency,
                  currencyOptions: currencyOptions,
                  onCurrencySelected: ref
                      .read(dashboardCurrencyProvider.notifier)
                      .select,
                ),
                const SizedBox(height: 22),
                Text(
                  'Saldo en cuentas',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                FittedBox(
                  key: const Key('dashboard-account-balance'),
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    MoneyFormatter.display(
                      stock[currency]?.balance ?? 0,
                      currency,
                    ),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                      color: context.palette.text,
                    ),
                  ),
                ),
                Text(
                  'Este mes',
                  style: TextStyle(fontSize: 12, color: context.palette.muted),
                ),
                const SizedBox(height: 8),
                _PeriodSummary(
                  incomes: hasTotals
                      ? MoneyFormatter.display(incomes, currency, signed: true)
                      : '—',
                  expenses: hasTotals
                      ? MoneyFormatter.display(
                          -expenses,
                          currency,
                          signed: true,
                        )
                      : '—',
                  balance: hasTotals
                      ? MoneyFormatter.display(saved, currency, signed: true)
                      : '—',
                ),
                const SizedBox(height: 20),
                if (totalsAsync.hasError)
                  _HomeError(
                    onRetry: () {
                      ref.invalidate(monthlyTotalsProvider);
                    },
                  )
                else ...[
                  _WeeklyInsightCard(insight: weekly),
                  const SizedBox(height: 14),
                  _ProjectionCard(
                    projection: projection,
                    currency: currency,
                    now: now,
                  ),
                ],
                const SizedBox(height: 14),
                _BudgetLink(
                  hasBudgets: budgets.result?.budgets.isNotEmpty ?? false,
                  onTap: () => context.push('/budgets'),
                ),
                const SizedBox(height: 12),
                Material(
                  color: context.palette.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    key: const Key('dashboard-open-analysis'),
                    onTap: () => context.push('/analysis'),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            FinanceIcons.queryStatsRounded,
                            color: context.palette.primaryDark,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Ver análisis',
                              style: TextStyle(
                                color: context.palette.primaryDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(
                            FinanceIcons.chevronRight,
                            color: context.palette.primaryDark,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatefulWidget {
  const _HomeHeader({
    required this.name,
    required this.currency,
    required this.currencyOptions,
    required this.onCurrencySelected,
  });
  final String? name;
  final String currency;
  final List<String> currencyOptions;
  final ValueChanged<String> onCurrencySelected;

  @override
  State<_HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<_HomeHeader> {
  final _currencyMenuKey = GlobalKey<PopupMenuButtonState<String>>();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.name == null || widget.name!.isEmpty
                    ? 'Hola'
                    : 'Hola, ${widget.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: palette.text,
                ),
              ),
              Text(
                'Aquí tienes un resumen de tus finanzas',
                style: TextStyle(fontSize: 13, color: palette.muted),
              ),
            ],
          ),
        ),
        Semantics(
          key: const Key('dashboard-currency-selector'),
          container: true,
          label: 'Seleccionar moneda',
          button: true,
          onTap: () => _currencyMenuKey.currentState?.showButtonMenu(),
          child: ExcludeSemantics(
            child: PopupMenuButton<String>(
              key: _currencyMenuKey,
              tooltip: 'Seleccionar moneda',
              initialValue: widget.currency,
              onSelected: widget.onCurrencySelected,
              itemBuilder: (context) => [
                for (final code in widget.currencyOptions)
                  PopupMenuItem(value: code, child: Text(code)),
              ],
              child: Container(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: palette.primarySoft,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.currency,
                      style: TextStyle(
                        color: palette.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      FinanceIcons.expandMore,
                      size: 16,
                      color: palette.text,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        const ThemeToggleButton(),
      ],
    );
  }
}

class _PeriodSummary extends StatelessWidget {
  const _PeriodSummary({
    required this.incomes,
    required this.expenses,
    required this.balance,
  });
  final String incomes;
  final String expenses;
  final String balance;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
      decoration: BoxDecoration(
        color: palette.primarySoft.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              icon: FinanceIcons.arrowUpwardRounded,
              label: 'Ingresos',
              value: incomes,
              color: palette.income,
            ),
          ),
          _summaryDivider(palette),
          Expanded(
            child: _SummaryItem(
              icon: FinanceIcons.arrowDownwardRounded,
              label: 'Gastos',
              value: expenses,
              color: palette.discard,
            ),
          ),
          _summaryDivider(palette),
          Expanded(
            child: _SummaryItem(
              icon: FinanceIcons.trendingFlat,
              label: 'Balance',
              value: balance,
              color: palette.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider(AppPalette palette) =>
      Container(width: 1, height: 46, color: palette.line);
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: context.palette.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

class _WeeklyInsightCard extends StatelessWidget {
  const _WeeklyInsightCard({required this.insight});
  final WeeklySpendInsight insight;
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final maxDailySpend = insight.dailySpend.fold<int>(
      0,
      (maximum, value) => value > maximum ? value : maximum,
    );
    return Card(
      key: const Key('dashboard-weekly-insight'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  FinanceIcons.autoAwesome,
                  color: palette.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Insight semanal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: palette.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              insight.message,
              style: TextStyle(fontSize: 13, height: 1.4, color: palette.muted),
            ),
            if (insight.isAvailable) ...[
              const SizedBox(height: 14),
              Semantics(
                label: 'Gasto diario durante los últimos siete días',
                child: SizedBox(
                  height: 70,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < insight.dailySpend.length; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: FractionallySizedBox(
                                      heightFactor: maxDailySpend == 0
                                          ? 0.06
                                          : (insight.dailySpend[i] /
                                                    maxDailySpend)
                                                .clamp(0.08, 1),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: palette.primary.withValues(
                                            alpha: maxDailySpend == 0
                                                ? 0.4
                                                : 0.35 +
                                                      0.65 *
                                                          (insight.dailySpend[i] /
                                                              maxDailySpend),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _weekdayLabel(
                                    insight.currentStart
                                        .add(Duration(days: i))
                                        .weekday,
                                  ),
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: palette.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

bool _sameCalendarDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _weekdayLabel(int weekday) =>
    const ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'][weekday - 1];

class _ProjectionCard extends StatelessWidget {
  const _ProjectionCard({
    required this.projection,
    required this.currency,
    required this.now,
  });
  final MonthlySpendProjection projection;
  final String currency;
  final DateTime now;
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final month = DateLabels.monthName(now);
    return Card(
      key: const Key('dashboard-month-projection'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  FinanceIcons.queryStatsRounded,
                  size: 20,
                  color: palette.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Proyección del mes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: palette.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              projection.isAvailable
                  ? 'Al ritmo actual, cerrarías $month con ${MoneyFormatter.display(projection.projected!, currency)} en gastos.'
                  : projection.message,
              style: TextStyle(fontSize: 13, height: 1.4, color: palette.muted),
            ),
            const SizedBox(height: 6),
            Text(
              'Corte: ${now.day} de $month · ${projection.daysElapsed} días de ${projection.daysInMonth}.',
              style: TextStyle(fontSize: 11, color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetLink extends StatelessWidget {
  const _BudgetLink({required this.hasBudgets, required this.onTap});
  final bool hasBudgets;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      key: const Key('dashboard-budget-link'),
      onPressed: onTap,
      icon: const Icon(FinanceIcons.accountBalanceWalletOutlined, size: 18),
      label: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Presupuestos'),
          SizedBox(width: 6),
          Icon(FinanceIcons.chevronRight, size: 16),
        ],
      ),
      style: TextButton.styleFrom(
        foregroundColor: context.palette.primaryDark,
        minimumSize: const Size(48, 48),
      ),
    ),
  );
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ErrorDiagnosticPanel(
            diagnostic: ErrorDiagnostic.capture(
              code: 'dashboard_summary_unavailable',
              operation: 'load_dashboard',
              userMessage: 'No pudimos cargar el resumen. Revisa tu conexión e inténtalo de nuevo.',
              technicalReason: 'service_unavailable',
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}
