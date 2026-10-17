import 'package:flutter/foundation.dart';

import '../../expenses/domain/expense_models.dart';
import '../../expenses/domain/history_models.dart';

/// Pure, deterministic calculations used by the Inicio financial cards.
///
/// These calculations describe recorded expenses. They do not generate
/// predictions with an LLM and do not add amounts in different currencies.
class HomeFinancialMetrics {
  const HomeFinancialMetrics._();

  /// Compares two adjacent, complete seven-calendar-day windows.
  ///
  /// The current window ends yesterday in the device's local calendar. This
  /// avoids comparing a partial current day with a complete previous day. The
  /// source must cover the previous window's first date; otherwise the result
  /// is unavailable instead of treating missing history as zero spending.
  static WeeklySpendInsight buildWeeklyInsight({
    required List<HistoryItem> expenseItems,
    required String currencyCode,
    required DateTime now,
    required DateTime coverageStart,
    required DateTime coverageEnd,
    required bool historyIsComplete,
  }) {
    final today = _localDate(now);
    final currentEnd = today.subtract(const Duration(days: 1));
    final currentStart = currentEnd.subtract(const Duration(days: 6));
    final previousEnd = currentStart.subtract(const Duration(days: 1));
    final previousStart = previousEnd.subtract(const Duration(days: 6));
    final coveredFrom = _calendarDate(coverageStart);
    final coveredThrough = _calendarDate(coverageEnd);

    if (!historyIsComplete ||
        coveredFrom.isAfter(previousStart) ||
        coveredThrough.isBefore(currentEnd)) {
      return WeeklySpendInsight.unavailable(
        currentStart: currentStart,
        currentEnd: currentEnd,
        previousStart: previousStart,
        previousEnd: previousEnd,
        reason: !historyIsComplete
            ? WeeklyInsightUnavailableReason.incompleteHistory
            : WeeklyInsightUnavailableReason.insufficientWindow,
      );
    }

    final previousByDay = List<int>.filled(7, 0);
    final currentByDay = List<int>.filled(7, 0);
    for (final item in expenseItems) {
      if (item.type != TransactionType.expense ||
          item.status == ExpenseStatus.voided) {
        continue;
      }
      final day = _localDate(item.occurredAt);
      final previousIndex = day.difference(previousStart).inDays;
      final currentIndex = day.difference(currentStart).inDays;
      if (previousIndex < 0 || previousIndex >= 7) {
        if (currentIndex < 0 || currentIndex >= 7) continue;
      }

      final amount = _expenseAmount(item, currencyCode);
      if (previousIndex >= 0 && previousIndex < 7) {
        previousByDay[previousIndex] += amount;
      } else if (currentIndex >= 0 && currentIndex < 7) {
        currentByDay[currentIndex] += amount;
      }
    }

    final previousTotal = previousByDay.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final currentTotal = currentByDay.fold<int>(0, (sum, value) => sum + value);
    final changePercent = previousTotal == 0
        ? null
        : (currentTotal - previousTotal) * 100 / previousTotal;
    final message = _weeklyMessage(
      currentTotal: currentTotal,
      previousTotal: previousTotal,
      changePercent: changePercent,
    );

    return WeeklySpendInsight(
      isAvailable: true,
      unavailableReason: null,
      currentTotal: currentTotal,
      previousTotal: previousTotal,
      changePercent: changePercent,
      currentStart: currentStart,
      currentEnd: currentEnd,
      previousStart: previousStart,
      previousEnd: previousEnd,
      dailySpend: List<int>.unmodifiable(currentByDay),
      title: 'Insight semanal',
      message: message,
    );
  }

  /// Projects month-end spending from the month-to-date daily average.
  ///
  /// A projection is only available when the source is known to be complete,
  /// covers the first calendar day of this month, and includes at least three
  /// elapsed calendar days. [historyIsComplete] must come from the caller's
  /// pagination state; a truncated history must never be extrapolated.
  static MonthlySpendProjection buildMonthlyProjection({
    required List<HistoryItem> expenseItems,
    required String currencyCode,
    required DateTime now,
    required DateTime coverageStart,
    required DateTime coverageEnd,
    required bool historyIsComplete,
  }) {
    final localNow = now.toLocal();
    final monthStart = DateTime(localNow.year, localNow.month);
    final daysInMonth = DateTime(localNow.year, localNow.month + 1, 0).day;
    final daysElapsed = localNow.day;
    final coveredFrom = _calendarDate(coverageStart);
    final coveredThrough = _calendarDate(coverageEnd);
    final spent = _monthToDateSpend(
      expenseItems: expenseItems,
      currencyCode: currencyCode,
      monthStart: monthStart,
      through: _localDate(localNow),
    );

    MonthlyProjectionUnavailableReason? reason;
    if (!historyIsComplete) {
      reason = MonthlyProjectionUnavailableReason.incompleteHistory;
    } else if (coveredFrom.isAfter(monthStart) ||
        coveredThrough.isBefore(_localDate(localNow))) {
      reason = MonthlyProjectionUnavailableReason.monthNotCovered;
    } else if (daysElapsed < 3) {
      reason = MonthlyProjectionUnavailableReason.insufficientElapsedDays;
    }

    if (reason != null) {
      return MonthlySpendProjection.unavailable(
        spentMtd: spent,
        daysElapsed: daysElapsed,
        daysInMonth: daysInMonth,
        reason: reason,
      );
    }

    final projected = spent == 0
        ? 0
        : (spent * daysInMonth / daysElapsed).round();
    final message = spent == 0
        ? 'No hay gastos registrados en lo que va del mes; la proyección es cero.'
        : 'Al ritmo promedio de los $daysElapsed días transcurridos, el gasto total del mes sería de $projected.';
    return MonthlySpendProjection(
      isAvailable: true,
      unavailableReason: null,
      spentMtd: spent,
      projected: projected,
      daysElapsed: daysElapsed,
      daysInMonth: daysInMonth,
      dailySpend: List<int>.unmodifiable(
        _monthlyDailySpend(
          expenseItems: expenseItems,
          currencyCode: currencyCode,
          monthStart: monthStart,
          through: _localDate(localNow),
          daysElapsed: daysElapsed,
        ),
      ),
      message: message,
    );
  }

  static String _weeklyMessage({
    required int currentTotal,
    required int previousTotal,
    required double? changePercent,
  }) {
    if (currentTotal == 0 && previousTotal == 0) {
      return 'No se registraron gastos en ninguna de las dos semanas comparadas.';
    }
    if (previousTotal == 0) {
      return 'Se registraron gastos esta semana; no hay una base anterior para calcular un porcentaje.';
    }
    if (currentTotal == 0) {
      return 'No se registraron gastos esta semana; la semana anterior sí tuvo gastos.';
    }
    final pct = changePercent!.round().abs();
    if (changePercent == 0) {
      return 'El gasto registrado fue igual en las dos semanas comparadas.';
    }
    final direction = changePercent > 0 ? 'mayor' : 'menor';
    return 'El gasto registrado fue un $pct% $direction que en la semana anterior.';
  }

  static int _monthToDateSpend({
    required List<HistoryItem> expenseItems,
    required String currencyCode,
    required DateTime monthStart,
    required DateTime through,
  }) {
    var total = 0;
    for (final item in expenseItems) {
      if (item.type != TransactionType.expense ||
          item.status == ExpenseStatus.voided) {
        continue;
      }
      final day = _localDate(item.occurredAt);
      if (day.isBefore(monthStart) || day.isAfter(through)) continue;
      total += _expenseAmount(item, currencyCode);
    }
    return total;
  }

  static List<int> _monthlyDailySpend({
    required List<HistoryItem> expenseItems,
    required String currencyCode,
    required DateTime monthStart,
    required DateTime through,
    required int daysElapsed,
  }) {
    final result = List<int>.filled(daysElapsed, 0);
    for (final item in expenseItems) {
      if (item.type != TransactionType.expense ||
          item.status == ExpenseStatus.voided) {
        continue;
      }
      final day = _localDate(item.occurredAt);
      if (day.isBefore(monthStart) || day.isAfter(through)) continue;
      result[day.day - 1] += _expenseAmount(item, currencyCode);
    }
    return result;
  }

  static int _expenseAmount(HistoryItem item, String currencyCode) {
    var amount = 0;
    for (final movement in item.movements) {
      if (movement.currencyCode == currencyCode &&
          movement.amount.minorUnits < 0) {
        amount += -movement.amount.minorUnits;
      }
    }
    return amount;
  }

  static DateTime _localDate(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Coverage dates from PeriodTotals are UTC-midnight calendar dates; use
  /// their date components without shifting them through the local timezone.
  static DateTime _calendarDate(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

enum WeeklyInsightUnavailableReason { insufficientWindow, incompleteHistory }

@immutable
class WeeklySpendInsight {
  const WeeklySpendInsight({
    required this.isAvailable,
    required this.unavailableReason,
    required this.currentTotal,
    required this.previousTotal,
    required this.changePercent,
    required this.currentStart,
    required this.currentEnd,
    required this.previousStart,
    required this.previousEnd,
    required this.dailySpend,
    required this.title,
    required this.message,
  });

  factory WeeklySpendInsight.unavailable({
    required DateTime currentStart,
    required DateTime currentEnd,
    required DateTime previousStart,
    required DateTime previousEnd,
    required WeeklyInsightUnavailableReason reason,
  }) => WeeklySpendInsight(
    isAvailable: false,
    unavailableReason: reason,
    currentTotal: 0,
    previousTotal: 0,
    changePercent: null,
    currentStart: currentStart,
    currentEnd: currentEnd,
    previousStart: previousStart,
    previousEnd: previousEnd,
    dailySpend: List<int>.unmodifiable(List<int>.filled(7, 0)),
    title: 'Insight semanal',
    message: switch (reason) {
      WeeklyInsightUnavailableReason.insufficientWindow =>
        'Aún no hay dos semanas completas de datos para comparar.',
      WeeklyInsightUnavailableReason.incompleteHistory =>
        'No se comparan semanas porque el historial puede estar incompleto.',
    },
  );

  final bool isAvailable;
  final WeeklyInsightUnavailableReason? unavailableReason;
  final int currentTotal;
  final int previousTotal;
  final double? changePercent;
  final DateTime currentStart;
  final DateTime currentEnd;
  final DateTime previousStart;
  final DateTime previousEnd;
  final List<int> dailySpend;
  final String title;
  final String message;
}

enum MonthlyProjectionUnavailableReason {
  incompleteHistory,
  monthNotCovered,
  insufficientElapsedDays,
}

@immutable
class MonthlySpendProjection {
  const MonthlySpendProjection({
    required this.isAvailable,
    required this.unavailableReason,
    required this.spentMtd,
    required this.projected,
    required this.daysElapsed,
    required this.daysInMonth,
    required this.dailySpend,
    required this.message,
  });

  factory MonthlySpendProjection.unavailable({
    required int spentMtd,
    required int daysElapsed,
    required int daysInMonth,
    required MonthlyProjectionUnavailableReason reason,
  }) => MonthlySpendProjection(
    isAvailable: false,
    unavailableReason: reason,
    spentMtd: spentMtd,
    projected: null,
    daysElapsed: daysElapsed,
    daysInMonth: daysInMonth,
    dailySpend: const [],
    message: switch (reason) {
      MonthlyProjectionUnavailableReason.incompleteHistory =>
        'No se proyecta porque el historial puede estar incompleto.',
      MonthlyProjectionUnavailableReason.monthNotCovered =>
        'No se proyecta porque los datos no cubren todo el mes.',
      MonthlyProjectionUnavailableReason.insufficientElapsedDays =>
        'Aún hay pocos días transcurridos para calcular una proyección.',
    },
  );

  final bool isAvailable;
  final MonthlyProjectionUnavailableReason? unavailableReason;
  final int spentMtd;
  final int? projected;
  final int daysElapsed;
  final int daysInMonth;
  final List<int> dailySpend;
  final String message;
}
