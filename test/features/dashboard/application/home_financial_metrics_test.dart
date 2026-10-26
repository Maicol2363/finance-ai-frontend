import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/dashboard/application/home_financial_metrics.dart';
import 'package:finance_ai/features/expenses/domain/expense_models.dart';
import 'package:finance_ai/features/expenses/domain/history_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeFinancialMetrics.buildWeeklyInsight', () {
    final now = DateTime(2026, 10, 15, 12);

    test(
      'compares adjacent seven-day windows and filters type, status, currency',
      () {
        final result = HomeFinancialMetrics.buildWeeklyInsight(
          expenseItems: [
            _historyItem(id: 1, date: DateTime(2026, 10, 7), units: -500),
            _historyItem(id: 2, date: DateTime(2026, 10, 8), units: -100),
            _historyItem(id: 3, date: DateTime(2026, 10, 14), units: -200),
            _historyItem(
              id: 4,
              date: DateTime(2026, 10, 9),
              units: -999,
              currencyCode: 'USD',
            ),
            _historyItem(
              id: 5,
              date: DateTime(2026, 10, 10),
              units: -999,
              type: TransactionType.transfer,
            ),
            _historyItem(
              id: 6,
              date: DateTime(2026, 10, 11),
              units: -999,
              status: ExpenseStatus.voided,
            ),
            _historyItem(id: 7, date: DateTime(2026, 10, 15), units: -999),
          ],
          currencyCode: 'COP',
          now: now,
          coverageStart: DateTime.utc(2026, 10, 1),
          coverageEnd: DateTime.utc(2026, 10, 31),
          historyIsComplete: true,
        );

        expect(result.isAvailable, isTrue);
        expect(result.currentStart, DateTime(2026, 10, 8));
        expect(result.currentEnd, DateTime(2026, 10, 14));
        expect(result.previousStart, DateTime(2026, 10, 1));
        expect(result.previousEnd, DateTime(2026, 10, 7));
        expect(result.currentTotal, 300);
        expect(result.previousTotal, 500);
        expect(result.changePercent, -40);
        expect(result.dailySpend, [100, 0, 0, 0, 0, 0, 200]);
        expect(result.message, contains('40% menor'));
        expect(result.title, 'Insight semanal');
      },
    );

    test('does not compare when source starts inside the previous window', () {
      final result = HomeFinancialMetrics.buildWeeklyInsight(
        expenseItems: const [],
        currencyCode: 'COP',
        now: now,
        coverageStart: DateTime.utc(2026, 10, 2),
        coverageEnd: DateTime.utc(2026, 10, 31),
        historyIsComplete: true,
      );

      expect(result.isAvailable, isFalse);
      expect(
        result.unavailableReason,
        WeeklyInsightUnavailableReason.insufficientWindow,
      );
      expect(result.changePercent, isNull);
      expect(result.message, contains('dos semanas completas'));
    });

    test(
      'does not treat a selected historical window as current zero spending',
      () {
        final result = HomeFinancialMetrics.buildWeeklyInsight(
          expenseItems: const [],
          currencyCode: 'COP',
          now: now,
          coverageStart: DateTime.utc(2026, 9, 1),
          coverageEnd: DateTime.utc(2026, 9, 30),
          historyIsComplete: true,
        );

        expect(result.isAvailable, isFalse);
        expect(
          result.unavailableReason,
          WeeklyInsightUnavailableReason.insufficientWindow,
        );
      },
    );

    test(
      'keeps zero previous spend honest instead of inventing a percentage',
      () {
        final result = HomeFinancialMetrics.buildWeeklyInsight(
          expenseItems: [
            _historyItem(id: 1, date: DateTime(2026, 10, 8), units: -25),
          ],
          currencyCode: 'COP',
          now: now,
          coverageStart: DateTime.utc(2026, 10, 1),
          coverageEnd: DateTime.utc(2026, 10, 31),
          historyIsComplete: true,
        );

        expect(result.isAvailable, isTrue);
        expect(result.previousTotal, 0);
        expect(result.changePercent, isNull);
        expect(result.message, contains('no hay una base anterior'));
      },
    );

    test('uses local calendar dates for UTC timestamps around midnight', () {
      // This instant is Oct 8 in UTC and Oct 7 in America/Bogota.
      final result = HomeFinancialMetrics.buildWeeklyInsight(
        expenseItems: [
          _historyItem(id: 1, date: DateTime.utc(2026, 10, 8, 2), units: -75),
        ],
        currencyCode: 'COP',
        now: now,
        coverageStart: DateTime.utc(2026, 10, 1),
        coverageEnd: DateTime.utc(2026, 10, 31),
        historyIsComplete: true,
      );

      final expectedDay = DateTime.utc(2026, 10, 8, 2).toLocal().day;
      expect(result.isAvailable, isTrue);
      expect(result.currentTotal + result.previousTotal, 75);
      expect(expectedDay == 7 ? result.previousTotal : result.currentTotal, 75);
    });

    test(
      'does not compare when the loaded history is known to be truncated',
      () {
        final result = HomeFinancialMetrics.buildWeeklyInsight(
          expenseItems: const [],
          currencyCode: 'COP',
          now: now,
          coverageStart: DateTime.utc(2026, 10, 1),
          coverageEnd: DateTime.utc(2026, 10, 31),
          historyIsComplete: false,
        );

        expect(result.isAvailable, isFalse);
        expect(
          result.unavailableReason,
          WeeklyInsightUnavailableReason.incompleteHistory,
        );
        expect(result.message, contains('historial puede estar incompleto'));
      },
    );
  });

  group('HomeFinancialMetrics.buildMonthlyProjection', () {
    test('projects month-end from complete month-to-date spend, excluding future dates', () {
      final result = HomeFinancialMetrics.buildMonthlyProjection(
        expenseItems: [
          _historyItem(id: 1, date: DateTime(2026, 10, 1), units: -1000),
          _historyItem(id: 2, date: DateTime(2026, 10, 31), units: -5000),
          _historyItem(id: 3, date: DateTime(2026, 9, 30), units: -7000),
        ],
        currencyCode: 'COP',
        now: DateTime(2026, 10, 31, 18),
        coverageStart: DateTime.utc(2026, 10, 1),
        coverageEnd: DateTime.utc(2026, 10, 31),
        historyIsComplete: true,
      );

      expect(result.isAvailable, isTrue);
      expect(result.spentMtd, 6000);
      expect(result.projected, 6000);
      expect(result.daysElapsed, 31);
      expect(result.daysInMonth, 31);
      expect(result.dailySpend, hasLength(31));
    });

    test('returns a zero projection when a complete month has no spending', () {
      final result = HomeFinancialMetrics.buildMonthlyProjection(
        expenseItems: const [],
        currencyCode: 'COP',
        now: DateTime(2026, 10, 10),
        coverageStart: DateTime.utc(2026, 10, 1),
        coverageEnd: DateTime.utc(2026, 10, 31),
        historyIsComplete: true,
      );

      expect(result.isAvailable, isTrue);
      expect(result.spentMtd, 0);
      expect(result.projected, 0);
      expect(result.message, contains('proyección es cero'));
    });

    test('requires explicit complete history and month coverage', () {
      final incomplete = HomeFinancialMetrics.buildMonthlyProjection(
        expenseItems: [
          _historyItem(id: 1, date: DateTime(2026, 10, 5), units: -100),
        ],
        currencyCode: 'COP',
        now: DateTime(2026, 10, 10),
        coverageStart: DateTime.utc(2026, 10, 1),
        coverageEnd: DateTime.utc(2026, 10, 31),
        historyIsComplete: false,
      );
      final uncovered = HomeFinancialMetrics.buildMonthlyProjection(
        expenseItems: const [],
        currencyCode: 'COP',
        now: DateTime(2026, 10, 10),
        coverageStart: DateTime.utc(2026, 10, 2),
        coverageEnd: DateTime.utc(2026, 10, 31),
        historyIsComplete: true,
      );

      expect(incomplete.isAvailable, isFalse);
      expect(
        incomplete.unavailableReason,
        MonthlyProjectionUnavailableReason.incompleteHistory,
      );
      expect(incomplete.projected, isNull);
      expect(uncovered.isAvailable, isFalse);
      expect(
        uncovered.unavailableReason,
        MonthlyProjectionUnavailableReason.monthNotCovered,
      );
      final historicalWindow = HomeFinancialMetrics.buildMonthlyProjection(
        expenseItems: const [],
        currencyCode: 'COP',
        now: DateTime(2026, 10, 10),
        coverageStart: DateTime.utc(2026, 9, 1),
        coverageEnd: DateTime.utc(2026, 9, 30),
        historyIsComplete: true,
      );
      expect(historicalWindow.isAvailable, isFalse);
      expect(
        historicalWindow.unavailableReason,
        MonthlyProjectionUnavailableReason.monthNotCovered,
      );
    });

    test('waits for three elapsed calendar days and handles leap February', () {
      final tooEarly = HomeFinancialMetrics.buildMonthlyProjection(
        expenseItems: const [],
        currencyCode: 'COP',
        now: DateTime(2024, 2, 2, 23),
        coverageStart: DateTime.utc(2024, 2, 1),
        coverageEnd: DateTime.utc(2024, 2, 29),
        historyIsComplete: true,
      );
      final leapMonth = HomeFinancialMetrics.buildMonthlyProjection(
        expenseItems: [
          _historyItem(id: 1, date: DateTime(2024, 2, 1), units: -100),
          _historyItem(id: 2, date: DateTime(2024, 2, 2), units: -100),
          _historyItem(id: 3, date: DateTime(2024, 2, 3), units: -100),
        ],
        currencyCode: 'COP',
        now: DateTime(2024, 2, 3, 12),
        coverageStart: DateTime.utc(2024, 2, 1),
        coverageEnd: DateTime.utc(2024, 2, 29),
        historyIsComplete: true,
      );

      expect(tooEarly.isAvailable, isFalse);
      expect(
        tooEarly.unavailableReason,
        MonthlyProjectionUnavailableReason.insufficientElapsedDays,
      );
      expect(leapMonth.daysInMonth, 29);
      expect(leapMonth.projected, 2900);
    });

    test(
      'deterministic generated cases preserve the daily-average formula',
      () {
        for (var day = 3; day <= 31; day++) {
          final items = <HistoryItem>[];
          var expectedSpend = 0;
          for (var itemDay = 1; itemDay <= day; itemDay++) {
            final units = (day * 17 + itemDay * 31) % 1000;
            expectedSpend += units;
            items.add(
              _historyItem(
                id: itemDay,
                date: DateTime(2026, 3, itemDay),
                units: -units,
              ),
            );
          }
          final result = HomeFinancialMetrics.buildMonthlyProjection(
            expenseItems: items,
            currencyCode: 'COP',
            now: DateTime(2026, 3, day, 12),
            coverageStart: DateTime.utc(2026, 3, 1),
            coverageEnd: DateTime.utc(2026, 3, 31),
            historyIsComplete: true,
          );

          expect(result.isAvailable, isTrue, reason: 'day $day');
          expect(result.spentMtd, expectedSpend, reason: 'day $day');
          expect(
            result.projected,
            (expectedSpend * 31 / day).round(),
            reason: 'day $day',
          );
          expect(result.projected, greaterThanOrEqualTo(expectedSpend));
        }
      },
    );
  });
}

HistoryItem _historyItem({
  required int id,
  required DateTime date,
  required int units,
  String currencyCode = 'COP',
  TransactionType type = TransactionType.expense,
  ExpenseStatus status = ExpenseStatus.confirmed,
}) {
  final magnitude = units.abs();
  final amount = MoneyAmount.parseApi(
    '${units < 0 ? '-' : ''}${magnitude ~/ 100}.${(magnitude % 100).toString().padLeft(2, '0')}',
  );
  final currency = CurrencySummary(
    id: currencyCode == 'COP' ? 1 : 2,
    code: currencyCode,
    name: currencyCode,
    decimals: 2,
  );
  return HistoryItem(
    id: id,
    type: type,
    status: status,
    occurredAt: date,
    description: null,
    captureSource: CaptureSource.manual,
    incomeSource: null,
    movements: [
      HistoryMovement(
        accountId: 1,
        accountName: 'Fixture',
        amount: amount,
        currency: currency,
        currencyCode: currencyCode,
      ),
    ],
    expense: null,
  );
}
