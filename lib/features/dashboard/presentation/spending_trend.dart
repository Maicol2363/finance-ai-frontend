import 'package:finance_ai/features/expenses/domain/history_models.dart';

/// One bucket of expense flow, in integer minor units (positive magnitude).
class DailySpend {
  const DailySpend({required this.day, required this.minorUnits});

  /// Local-midnight bucket start.
  final DateTime day;
  final int minorUnits;
}

/// One week of expense flow, in integer minor units (positive magnitude).
class WeeklySpend {
  const WeeklySpend({
    required this.start,
    required this.end,
    required this.minorUnits,
  });

  /// Local-midnight bucket bounds (inclusive).
  final DateTime start;
  final DateTime end;
  final int minorUnits;
}

/// Single day in a cumulative spend trajectory.
class CumulativeSpendDay {
  const CumulativeSpendDay({
    required this.day,
    required this.dailyMinorUnits,
    required this.cumulativeMinorUnits,
  });

  /// Calendar day of the spend.
  final DateTime day;

  /// Expense incurred specifically on this day (positive integer minor units).
  final int dailyMinorUnits;

  /// Total cumulative expense from the start of the window up to and including this day.
  final int cumulativeMinorUnits;
}

/// Cumulative expense series for spending pace / burn-up visualization.
///
/// Accumulates expenses day-by-day starting from [windowStart] up to the effective
/// cut-off day (the earlier of [windowEnd] and [asOf]/today). Future days are NOT
/// returned as empty points; instead, their trajectory is projected.
List<CumulativeSpendDay> cumulativeExpenseSeries({
  required List<HistoryItem> items,
  required String currencyCode,
  required DateTime windowStart,
  required DateTime windowEnd,
  DateTime? asOf,
}) {
  final startDay = DateTime(
    windowStart.year,
    windowStart.month,
    windowStart.day,
  );
  final requestedEnd = DateTime(windowEnd.year, windowEnd.month, windowEnd.day);
  final localNow = (asOf ?? DateTime.now()).toLocal();
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  final effectiveEnd = requestedEnd.isAfter(today) ? today : requestedEnd;
  if (effectiveEnd.isBefore(startDay)) return const [];

  final days = <DateTime>[];
  for (
    var d = startDay;
    !d.isAfter(effectiveEnd);
    d = d.add(const Duration(days: 1))
  ) {
    days.add(d);
  }

  final totals = <DateTime, int>{for (final d in days) d: 0};
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

  var runningTotal = 0;
  return [
    for (final d in days)
      CumulativeSpendDay(
        day: d,
        dailyMinorUnits: totals[d]!,
        cumulativeMinorUnits: (runningTotal += totals[d]!),
      ),
  ];
}

/// Weekly expense series for windows longer than ~2 weeks.
///
/// Buckets [items] in [currencyCode] into Monday-start weeks covering
/// [windowStart]..[windowEnd] (local calendar days). Daily bars turn into
/// noise when a 30/90/365-day window holds few movements; weeks keep volume
/// per bar. Days are still bucketed locally like [dailyExpenseSeries].
List<WeeklySpend> weeklyExpenseSeries({
  required List<HistoryItem> items,
  required String currencyCode,
  required DateTime windowStart,
  required DateTime windowEnd,
  DateTime? asOf,
}) {
  final startDay = DateTime(
    windowStart.year,
    windowStart.month,
    windowStart.day,
  );
  final requestedEnd = DateTime(windowEnd.year, windowEnd.month, windowEnd.day);
  final localNow = (asOf ?? DateTime.now()).toLocal();
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  final endDay = requestedEnd.isAfter(today) ? today : requestedEnd;
  if (endDay.isBefore(startDay)) return const [];
  // Monday-start weeks containing the window.
  var weekStart = startDay.subtract(Duration(days: (startDay.weekday - 1) % 7));
  final weeks = <DateTime>[];
  while (!weekStart.isAfter(endDay)) {
    weeks.add(weekStart);
    weekStart = weekStart.add(const Duration(days: 7));
  }
  final totals = <DateTime, int>{for (final w in weeks) w: 0};
  for (final item in items) {
    final itemLocal = item.occurredAt.toLocal();
    final bucket = DateTime(itemLocal.year, itemLocal.month, itemLocal.day);
    if (bucket.isBefore(startDay) || bucket.isAfter(endDay)) continue;
    final monday = bucket.subtract(Duration(days: (bucket.weekday - 1) % 7));
    if (!totals.containsKey(monday)) continue;
    for (final movement in item.movements) {
      if (movement.currencyCode != currencyCode) continue;
      final minorUnits = movement.amount.minorUnits;
      if (minorUnits < 0) totals[monday] = totals[monday]! - minorUnits;
    }
  }
  return [
    for (final w in weeks)
      WeeklySpend(
        start: w.isBefore(startDay) ? startDay : w,
        end: w.add(const Duration(days: 6)).isAfter(endDay)
            ? endDay
            : w.add(const Duration(days: 6)),
        minorUnits: totals[w]!,
      ),
  ];
}

/// Daily expense series for the Dashboard tendency.
///
/// Sums only the negative movements of [items] in [currencyCode], bucketed by
/// the item's local calendar day. The window ends at [windowEnd] (default:
/// today, local) and covers at most [maxDays] days, never reaching before
/// [windowStart] (default: local month start): single-month presets reuse the
/// window items the Dashboard already loads, so days outside the window are
/// out of scope until the backend summary lands.
List<DailySpend> dailyExpenseSeries({
  required List<HistoryItem> items,
  required String currencyCode,
  required DateTime now,
  int maxDays = 14,
  DateTime? windowStart,
  DateTime? windowEnd,
}) {
  assert(maxDays > 0);
  final local = now.toLocal();
  final endDay = windowEnd == null
      ? DateTime(local.year, local.month, local.day)
      : DateTime(windowEnd.year, windowEnd.month, windowEnd.day);
  final today = DateTime(local.year, local.month, local.day);
  final effectiveEnd = endDay.isAfter(today) ? today : endDay;
  final rangeStart = windowStart == null
      ? DateTime(local.year, local.month, 1)
      : DateTime(windowStart.year, windowStart.month, windowStart.day);
  var start = effectiveEnd.subtract(Duration(days: maxDays - 1));
  if (start.isBefore(rangeStart)) start = rangeStart;
  final days = <DateTime>[];
  for (
    var day = start;
    !day.isAfter(effectiveEnd);
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

/// Monthly expense series for the year view: 12 bars, one per month.
///
/// Buckets [items] in [currencyCode] by local calendar month within
/// [windowStart]..[windowEnd]. Returned as [WeeklySpend] range buckets (start =
/// first day, end = last day) so the trend card needs no third input shape.
List<WeeklySpend> monthlyExpenseSeries({
  required List<HistoryItem> items,
  required String currencyCode,
  required DateTime windowStart,
  required DateTime windowEnd,
}) {
  final startMonth = DateTime(windowStart.year, windowStart.month);
  final endMonth = DateTime(windowEnd.year, windowEnd.month);
  if (endMonth.isBefore(startMonth)) return const [];
  final months = <DateTime>[];
  var cursor = startMonth;
  while (!cursor.isAfter(endMonth)) {
    months.add(cursor);
    cursor = DateTime(cursor.year, cursor.month + 1);
  }
  final totals = <DateTime, int>{for (final m in months) m: 0};
  for (final item in items) {
    final itemLocal = item.occurredAt.toLocal();
    final key = DateTime(itemLocal.year, itemLocal.month);
    if (!totals.containsKey(key)) continue;
    for (final movement in item.movements) {
      if (movement.currencyCode != currencyCode) continue;
      final minorUnits = movement.amount.minorUnits;
      if (minorUnits < 0) totals[key] = totals[key]! - minorUnits;
    }
  }
  return [
    for (final m in months)
      WeeklySpend(
        start: m,
        end: DateTime(m.year, m.month + 1).subtract(const Duration(days: 1)),
        minorUnits: totals[m]!,
      ),
  ];
}

/// Short Spanish month label (`ene`, `sep`) for axis ticks.
String shortMonthName(int month) => const [
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
][month - 1];

/// Full Spanish month label (`enero`, `septiembre`).
String fullMonthName(int month) => const [
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
][month - 1];

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

/// Honest window-over-window comparison: current window spend vs the previous
/// equivalent window (same length, immediately before).
///
/// Returns `null` when there is nothing to compare (both zero). The caller
/// decides the label; this only computes the ratio so tests stay trivial.
/// `previous <= 0 && current > 0` means spend restarted after a quiet window
/// ('up'); `current <= 0` after spend means 'down'.
({double ratio, String direction})? compareWindows({
  required int current,
  required int previous,
}) {
  if (current <= 0 && previous <= 0) return null;
  if (previous <= 0) return (ratio: double.infinity, direction: 'up');
  if (current <= 0) return (ratio: 0, direction: 'down');
  final ratio = current / previous;
  if (ratio >= 1.15) return (ratio: ratio, direction: 'up');
  if (ratio <= 0.85) return (ratio: ratio, direction: 'down');
  return (ratio: ratio, direction: 'flat');
}
