import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/currency_totals.dart';
import '../../../core/time/clock_provider.dart';
import '../../incomes/data/incomes_repository.dart';
import '../data/expenses_repository.dart';
import '../domain/history_models.dart';
import 'expenses_controller.dart';

/// Current-month movement totals, shared by the Gastos hub and the Dashboard so
/// both cards report the same flow figures.
@immutable
class MonthlyTotals {
  const MonthlyTotals({
    required this.monthStart,
    required this.byCurrency,
    required this.expenseItems,
  });

  /// First day of the reported month (UTC midnight, for display helpers).
  final DateTime monthStart;

  /// Income/expense flow per currency for the month.
  final Map<String, CurrencyTotals> byCurrency;

  /// The month's expense entries across all pages, for the category breakdown.
  final List<HistoryItem> expenseItems;

  CurrencyTotals forCurrency(String? currencyCode) => currencyCode == null
      ? const CurrencyTotals()
      : byCurrency[currencyCode] ?? const CurrencyTotals();
}

/// Current-month income/expense totals per currency.
///
/// * Incomes come from `GET /incomes`, which is not paginated, so the list is
///   complete and can be filtered by month on the client.
/// * Expenses come from the paginated `GET /history` for the month instead of
///   the expenses list, because that list only holds the first page: summing it
///   would silently under-report a busy month.
///
/// It re-runs when the expenses list reloads (mutations and pull to refresh),
/// so the figures never go stale. The `select` keeps it from re-running on mere
/// loading-status transitions.
final monthlyTotalsProvider = FutureProvider<MonthlyTotals>((ref) async {
  ref.watch(expensesControllerProvider.select((state) => state.result));
  final now = ref.watch(clockProvider)();
  final window = currentMonthWindow(now);
  final builder = CurrencyTotalsBuilder();

  final incomes = await ref.watch(incomesListProvider.future);
  for (final income in incomes) {
    if (!isInCalendarMonth(income.date, now)) {
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

  return MonthlyTotals(
    monthStart: window.start,
    byCurrency: builder.build(),
    expenseItems: List.unmodifiable(expenseItems),
  );
});

/// A month never needs an unbounded walk: 5 pages of 100 cover 500 movements.
const _pageSize = 100;
const _maxPages = 5;
