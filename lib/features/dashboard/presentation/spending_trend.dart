import 'package:finance_ai/features/expenses/domain/history_models.dart';

/// One day of expense flow, in integer minor units (positive magnitude).
class DailySpend {
  const DailySpend({required this.day, required this.minorUnits});

  /// Local-midnight day bucket.
  final DateTime day;
  final int minorUnits;
}

/// Daily expense series for the fast Dashboard tendency (v1).
///
/// Sums only the negative movements of [items] in [currencyCode], bucketed by
/// the item's local calendar day. The window ends today (local) and covers at
/// most [maxDays] days, never reaching before the local month start: v1 reuses
/// the month-scoped items the Dashboard already loads, so days from the
/// previous month are out of scope until the backend summary lands.
List<DailySpend> dailyExpenseSeries({
  required List<HistoryItem> items,
  required String currencyCode,
  required DateTime now,
  int maxDays = 14,
}) {
  assert(maxDays > 0);
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  final monthStart = DateTime(local.year, local.month, 1);
  var start = today.subtract(Duration(days: maxDays - 1));
  if (start.isBefore(monthStart)) start = monthStart;
  final days = <DateTime>[];
  for (
    var day = start;
    !day.isAfter(today);
    day = day.add(const Duration(days: 1))
  ) {
    days.add(day);
  }
  final totals = <DateTime, int>{for (final day in days) day: 0};
  for (final item in items) {
    final itemLocal = item.occurredAt.toLocal();
    final bucket = DateTime(itemLocal.year, itemLocal.month, itemLocal.day);
    if (!totals.containsKey(bucket)) continue;
    for (final movement in item.movements) {
      if (movement.currencyCode != currencyCode) continue;
      final minorUnits = movement.amount.minorUnits;
      if (minorUnits < 0) totals[bucket] = totals[bucket]! - minorUnits;
    }
  }
  return [
    for (final day in days) DailySpend(day: day, minorUnits: totals[day]!),
  ];
}

/// Cheap tendency label for [days]: compares the second half against the
/// first half. Returns 'up', 'down', 'flat', or 'empty' (no spend at all).
String spendingTendency(List<DailySpend> days) {
  if (days.isEmpty) return 'empty';
  final total = days.fold<int>(0, (sum, day) => sum + day.minorUnits);
  if (total <= 0) return 'empty';
  if (days.length < 2) return 'flat';
  final split = days.length ~/ 2;
  final first = days
      .take(split)
      .fold<int>(0, (sum, day) => sum + day.minorUnits);
  final second = days
      .skip(split)
      .fold<int>(0, (sum, day) => sum + day.minorUnits);
  if (first <= 0) return second > 0 ? 'up' : 'flat';
  final ratio = second / first;
  if (ratio >= 1.15) return 'up';
  if (ratio <= 0.85) return 'down';
  return 'flat';
}
