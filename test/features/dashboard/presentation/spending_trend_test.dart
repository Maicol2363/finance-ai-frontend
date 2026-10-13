import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/dashboard/presentation/spending_trend.dart';
import 'package:finance_ai/features/expenses/domain/expense_models.dart';
import 'package:finance_ai/features/expenses/domain/history_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _cop = CurrencySummary(id: 1, code: 'COP', name: 'Peso', decimals: 2);
const _usd = CurrencySummary(id: 2, code: 'USD', name: 'Dollar', decimals: 2);

HistoryItem _item({
  required int id,
  required String at,
  required String amount,
  String code = 'COP',
  ExpenseStatus status = ExpenseStatus.confirmed,
}) => HistoryItem(
  id: id,
  type: TransactionType.expense,
  status: status,
  occurredAt: DateTime.parse(at),
  description: 'Gasto $id',
  captureSource: CaptureSource.manual,
  incomeSource: null,
  movements: [
    HistoryMovement(
      accountId: 11,
      accountName: 'Cash',
      amount: MoneyAmount.parseApi(amount),
      currency: code == 'COP' ? _cop : _usd,
      currencyCode: code,
    ),
  ],
  expense: null,
);

void main() {
  test('all chart granularities exclude voided expenses', () {
    final items = [
      _item(id: 1, at: '2026-09-12T12:00:00Z', amount: '-25.00'),
      _item(
        id: 2,
        at: '2026-09-12T12:00:00Z',
        amount: '-100.00',
        status: ExpenseStatus.voided,
      ),
    ];
    final start = DateTime.utc(2026, 9, 1);
    final end = DateTime.utc(2026, 9, 30);
    final now = DateTime(2026, 9, 29);
    final days = dailyExpenseSeries(
      items: items,
      currencyCode: 'COP',
      now: now,
      windowStart: start,
      windowEnd: end,
      maxDays: 30,
    );
    expect(days.fold<int>(0, (sum, day) => sum + day.minorUnits), 2500);
    final cumulative = cumulativeExpenseSeries(
      items: items,
      currencyCode: 'COP',
      windowStart: start,
      windowEnd: end,
      asOf: now,
    );
    expect(cumulative.last.cumulativeMinorUnits, 2500);
    final weeks = weeklyExpenseSeries(
      items: items,
      currencyCode: 'COP',
      windowStart: start,
      windowEnd: end,
      asOf: now,
    );
    expect(weeks.fold<int>(0, (sum, week) => sum + week.minorUnits), 2500);
    final months = monthlyExpenseSeries(
      items: items,
      currencyCode: 'COP',
      windowStart: start,
      windowEnd: end,
    );
    expect(months.single.minorUnits, 2500);
  });
  test('buckets negative movements in currency, ignores rest', () {
    final items = [
      _item(id: 1, at: '2026-09-28T12:00:00Z', amount: '-25.00'),
      _item(id: 2, at: '2026-09-28T18:00:00Z', amount: '-10.00', code: 'USD'),
      _item(id: 3, at: '2026-09-28T19:00:00Z', amount: '5.00'),
      _item(id: 4, at: '2026-08-20T12:00:00Z', amount: '-99.00'),
    ];
    final days = dailyExpenseSeries(
      items: items,
      currencyCode: 'COP',
      now: DateTime(2026, 9, 29, 12),
    );
    expect(days, hasLength(14));
    final sep28 = days.firstWhere((d) => d.day.day == 28);
    expect(sep28.minorUnits, 2500);
    expect(days.fold<int>(0, (s, d) => s + d.minorUnits), 2500);
  });

  test('window never reaches before month start', () {
    final days = dailyExpenseSeries(
      items: const [],
      currencyCode: 'COP',
      now: DateTime(2026, 9, 5, 12),
    );
    expect(days, hasLength(5));
    expect(days.first.day, DateTime(2026, 9, 1));
    expect(days.last.day, DateTime(2026, 9, 5));
  });

  test('tendency labels up down flat empty', () {
    List<DailySpend> mk(List<int> vs) => [
      for (var i = 0; i < vs.length; i++)
        DailySpend(day: DateTime(2026, 9, 1 + i), minorUnits: vs[i]),
    ];
    expect(spendingTendency(const []), 'empty');
    expect(spendingTendency(mk([0, 0])), 'empty');
    expect(spendingTendency(mk([100])), 'flat');
    expect(spendingTendency(mk([100, 100, 300, 300])), 'up');
    expect(spendingTendency(mk([300, 300, 100, 100])), 'down');
    expect(spendingTendency(mk([100, 100, 105, 105])), 'flat');
    expect(spendingTendency(mk([0, 0, 50, 50])), 'up');
  });

  test('weekly buckets keep volume per bar', () {
    final items = [
      _item(id: 1, at: '2026-09-05T12:00:00Z', amount: '-152000.00'),
      _item(id: 2, at: '2026-09-08T12:00:00Z', amount: '-48000.00'),
      _item(id: 3, at: '2026-09-12T12:00:00Z', amount: '-90000.00'),
    ];
    final weeks = weeklyExpenseSeries(
      items: items,
      currencyCode: 'COP',
      windowStart: DateTime.utc(2026, 9, 1),
      windowEnd: DateTime.utc(2026, 9, 30),
    );
    expect(weeks, hasLength(5));
    expect(
      weeks.fold<int>(0, (s, w) => s + w.minorUnits),
      15200000 + 4800000 + 9000000,
    );
    // Sep 5 (Sat) belongs to the Mon Sep-1 week.
    expect(weeks.first.minorUnits, 15200000);
  });

  test(
    'weekly buckets stop at today instead of showing future weeks as zero',
    () {
      final now = DateTime.now().toLocal();
      final today = DateTime(now.year, now.month, now.day);
      final weeks = weeklyExpenseSeries(
        items: const [],
        currencyCode: 'COP',
        windowStart: DateTime(today.year, today.month, 1),
        windowEnd: DateTime(today.year, 12, 31),
      );

      expect(weeks, isNotEmpty);
      expect(weeks.last.end.isAfter(today), isFalse);
      expect(weeks.every((week) => !week.start.isAfter(today)), isTrue);
    },
  );

  test('monthly buckets split the year view', () {
    final items = [
      _item(id: 1, at: '2026-08-10T12:00:00Z', amount: '-100.00'),
      _item(id: 2, at: '2026-09-05T12:00:00Z', amount: '-200.00'),
    ];
    final months = monthlyExpenseSeries(
      items: items,
      currencyCode: 'COP',
      windowStart: DateTime.utc(2026),
      windowEnd: DateTime.utc(2026, 12, 31),
    );
    expect(months, hasLength(12));
    expect(months[7].minorUnits, 10000);
    expect(months[8].minorUnits, 20000);
    expect(shortMonthName(9), 'sep');
  });

  test('compareWindows is honest about restarts and silence', () {
    expect(compareWindows(current: 0, previous: 0), isNull);
    expect(compareWindows(current: 100, previous: 0), (
      ratio: double.infinity,
      direction: 'up',
    ));
    expect(compareWindows(current: 0, previous: 100), (
      ratio: 0,
      direction: 'down',
    ));
    expect(compareWindows(current: 148, previous: 100)!.direction, 'up');
    expect(compareWindows(current: 100, previous: 100)!.direction, 'flat');
  });

  test('cumulativeExpenseSeries accumulates day by day up to today', () {
    final items = [
      _item(id: 1, at: '2026-10-01T10:00:00Z', amount: '-50000.00'),
      _item(id: 2, at: '2026-10-03T15:00:00Z', amount: '-20000.00'),
      _item(id: 3, at: '2026-10-03T18:00:00Z', amount: '-15000.00'),
      _item(id: 4, at: '2026-10-05T12:00:00Z', amount: '-10000.00'),
    ];
    final series = cumulativeExpenseSeries(
      items: items,
      currencyCode: 'COP',
      windowStart: DateTime(2026, 10, 1),
      windowEnd: DateTime(2026, 10, 31),
      asOf: DateTime(2026, 10, 5, 23),
    );

    // Only 5 days generated (up to asOf), never days 6..31
    expect(series, hasLength(5));
    expect(series[0].day.day, 1);
    expect(series[0].dailyMinorUnits, 5000000);
    expect(series[0].cumulativeMinorUnits, 5000000);

    // Day 2 had no expenses
    expect(series[1].day.day, 2);
    expect(series[1].dailyMinorUnits, 0);
    expect(series[1].cumulativeMinorUnits, 5000000);

    // Day 3 had two expenses (20k + 15k = 35k) -> cumulative 85k
    expect(series[2].day.day, 3);
    expect(series[2].dailyMinorUnits, 3500000);
    expect(series[2].cumulativeMinorUnits, 8500000);

    // Day 5 had 10k -> cumulative 95k
    expect(series[4].day.day, 5);
    expect(series[4].dailyMinorUnits, 1000000);
    expect(series[4].cumulativeMinorUnits, 9500000);
  });
}
