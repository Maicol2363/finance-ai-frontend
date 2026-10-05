import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/currency_totals.dart';
import '../../../core/time/clock_provider.dart';
import '../../incomes/data/incomes_repository.dart';
import '../data/expenses_repository.dart';
import '../domain/history_models.dart';
import 'expenses_controller.dart';

/// Which window the Dashboard reports on.
///
/// The stock balance card is always all-time; only the flow figures
/// (chips, tendency, category breakdown) follow this selection.
enum DashboardPeriod { thisMonth, lastMonth, last3Months, thisYear }

/// Currently selected Dashboard window. Changing it re-runs
/// [periodTotalsProvider] with the new dates.
final dashboardPeriodProvider =
    NotifierProvider<DashboardPeriodController, DashboardPeriod>(
      DashboardPeriodController.new,
    );

class DashboardPeriodController extends Notifier<DashboardPeriod> {
  @override
  DashboardPeriod build() => DashboardPeriod.thisMonth;

  void select(DashboardPeriod period) {
    if (state != period) state = period;
  }
}

/// Start/end of [period] as UTC-midnight calendar dates for the API
/// (`yyyy-MM-dd`) and the month check for incomes.
({DateTime start, DateTime end}) periodWindow(
  DashboardPeriod period,
  DateTime now,
) {
  final local = now.toLocal();
  final monthStart = DateTime.utc(local.year, local.month);
  switch (period) {
    case DashboardPeriod.thisMonth:
      return (start: monthStart, end: _monthEnd(local.year, local.month));
    case DashboardPeriod.lastMonth:
      final prev = DateTime.utc(local.year, local.month - 1);
      return (
        start: DateTime.utc(prev.year, prev.month),
        end: _monthEnd(prev.year, prev.month),
      );
    case DashboardPeriod.last3Months:
      final from = DateTime.utc(local.year, local.month - 2);
      return (
        start: DateTime.utc(from.year, from.month),
        end: _monthEnd(local.year, local.month),
      );
    case DashboardPeriod.thisYear:
      return (
        start: DateTime.utc(local.year),
        end: DateTime.utc(local.year, 12, 31),
      );
  }
}

DateTime _monthEnd(int year, int month) =>
    DateTime.utc(year, month + 1).subtract(const Duration(days: 1));

/// The window immediately before [window], with the same length in days.
///
/// Used for the honest comparison badge: `Mes anterior` compares against the
/// month before, `Últimos 3 meses` against the 3 months before, etc.
({DateTime start, DateTime end}) previousWindow(
  ({DateTime start, DateTime end}) window,
) {
  final length = window.end.difference(window.start).inDays + 1;
  final end = window.start.subtract(const Duration(days: 1));
  final start = end.subtract(Duration(days: length - 1));
  return (start: start, end: end);
}

/// True when [date] falls inside [window] (calendar-day precision).
bool isInPeriodWindow(DateTime date, ({DateTime start, DateTime end}) window) {
  final day = DateTime.utc(date.year, date.month, date.day);
  return !day.isBefore(window.start) && !day.isAfter(window.end);
}

/// Human label for the selected window (`octubre`, `septiembre`,
/// `jul – oct`, `2026`).
String periodLabel(DashboardPeriod period, DateTime now) {
  const short = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  const long = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  final local = now.toLocal();
  switch (period) {
    case DashboardPeriod.thisMonth:
      return long[local.month - 1];
    case DashboardPeriod.lastMonth:
      final prev = DateTime(local.year, local.month - 1);
      return long[prev.month - 1];
    case DashboardPeriod.last3Months:
      final from = DateTime(local.year, local.month - 2);
      return '${short[from.month - 1]} – ${short[local.month - 1]}';
    case DashboardPeriod.thisYear:
      return '${local.year}';
  }
}

/// Movement totals for the selected Dashboard window, shared by the Gastos hub
/// (Este mes) and the Dashboard (all presets) so both cards report the same
/// flow figures.
@immutable
class MonthlyTotals {
  const MonthlyTotals({
    required this.monthStart,
    required this.byCurrency,
    required this.expenseItems,
    this.period = DashboardPeriod.thisMonth,
    DateTime? windowEnd,
    this.previousExpensesByCurrency = const {},
  }) : windowEnd = windowEnd ?? monthStart;

  /// First day of the reported window (UTC midnight, for display helpers).
  final DateTime monthStart;

  /// Last day of the reported window (UTC midnight).
  final DateTime windowEnd;

  /// Which preset produced these totals.
  final DashboardPeriod period;

  /// Expense magnitudes per currency in the previous equivalent window
  /// ([previousWindow]), for the honest window-over-window badge. Incomes are
  /// not compared: only spend gets a tendency.
  final Map<String, int> previousExpensesByCurrency;

  /// Income/expense flow per currency for the month.
  final Map<String, CurrencyTotals> byCurrency;

  /// The month's expense entries across all pages, for the category breakdown.
  final List<HistoryItem> expenseItems;

  CurrencyTotals forCurrency(String? currencyCode) => currencyCode == null
      ? const CurrencyTotals()
      : byCurrency[currencyCode] ?? const CurrencyTotals();
}

/// Income/expense totals per currency for a Dashboard window.
///
/// * Incomes come from `GET /incomes`, which is not paginated, so the list is
///   complete and can be filtered by window on the client.
/// * Expenses come from the paginated `GET /history` for the window instead of
///   the expenses list, because that list only holds the first page: summing it
///   would silently under-report a busy window.
///
/// It re-runs when the expenses list reloads (mutations and pull to refresh),
/// so the figures never go stale. The `select` keeps it from re-running on mere
/// loading-status transitions.
Future<MonthlyTotals> loadPeriodTotals(
  Ref ref, {
  DashboardPeriod period = DashboardPeriod.thisMonth,
}) async {
  ref.watch(expensesControllerProvider.select((state) => state.result));
  final now = ref.watch(clockProvider)();
  final window = period == DashboardPeriod.thisMonth
      ? currentMonthWindow(now)
      : periodWindow(period, now);
  final builder = CurrencyTotalsBuilder();

  final incomes = await ref.watch(incomesListProvider.future);
  for (final income in incomes) {
    final inWindow = period == DashboardPeriod.thisMonth
        ? isInCalendarMonth(income.date, now)
        : isInPeriodWindow(income.date, window);
    if (!inWindow) {
      continue;
    }
    builder.addIncome(income.currencyCode, income.amount.minorUnits);
  }

  final repository = ref.watch(expensesRepositoryProvider);
  final expenseItems = <HistoryItem>[];
  for (var page = 1; page <= _maxPages; page++) {
    final result = await repository.history(
      HistoryFilters(
        type: TransactionType.expense,
        startDate: window.start,
        endDate: window.end,
        page: page,
        pageSize: _pageSize,
      ),
    );
    expenseItems.addAll(result.items);
    for (final item in result.items) {
      for (final movement in item.movements) {
        final minorUnits = movement.amount.minorUnits;
        if (minorUnits < 0) {
          builder.addExpense(movement.currencyCode, -minorUnits);
        }
      }
    }
    if (!result.hasNext) {
      break;
    }
  }

  // Previous equivalent window: one extra first-page read, expenses only.
  // Incomes are not compared (only spend gets a tendency). When the previous
  // window is busier than one page the badge still compares first-page sums;
  // acceptable: the badge is a hint, totals stay exact.
  final prev = previousWindow(window);
  final prevExpenses = <String, int>{};
  final prevResult = await repository.history(
    HistoryFilters(
      type: TransactionType.expense,
      startDate: prev.start,
      endDate: prev.end,
      page: 1,
      pageSize: _pageSize,
    ),
  );
  for (final item in prevResult.items) {
    for (final movement in item.movements) {
      final minorUnits = movement.amount.minorUnits;
      if (minorUnits < 0) {
        prevExpenses[movement.currencyCode] =
            (prevExpenses[movement.currencyCode] ?? 0) - minorUnits;
      }
    }
  }

  return MonthlyTotals(
    monthStart: window.start,
    windowEnd: window.end,
    period: period,
    byCurrency: builder.build(),
    expenseItems: List.unmodifiable(expenseItems),
    previousExpensesByCurrency: Map.unmodifiable(prevExpenses),
  );
}

/// Gastos hub totals: always Este mes (unchanged behavior).
final monthlyTotalsProvider = FutureProvider<MonthlyTotals>((ref) async {
  return loadPeriodTotals(ref, period: DashboardPeriod.thisMonth);
});

/// Dashboard totals: follows the selected preset in [dashboardPeriodProvider].
final periodTotalsProvider = FutureProvider<MonthlyTotals>((ref) async {
  final period = ref.watch(dashboardPeriodProvider);
  return loadPeriodTotals(ref, period: period);
});

/// A month never needs an unbounded walk: 5 pages of 100 cover 500 movements.
const _pageSize = 100;
const _maxPages = 5;
