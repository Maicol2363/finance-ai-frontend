import 'package:finance_ai/core/money/currency_totals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accumulates each currency without ever mixing them', () {
    final builder = CurrencyTotalsBuilder()
      ..addBalance('COP', 100000)
      ..addBalance('COP', 25000)
      ..addBalance('USD', 9870)
      ..addIncome('COP', 50000000)
      ..addExpense('COP', 2500)
      ..addExpense('USD', 1200);

    final totals = builder.build();
    expect(
      totals['COP'],
      const CurrencyTotals(balance: 125000, incomes: 50000000, expenses: 2500),
    );
    expect(totals['USD'], const CurrencyTotals(balance: 9870, expenses: 1200));
    expect(totals['COP']!.flow, 50000000 - 2500);
  });

  test('start values are zero and the map is unmodifiable', () {
    final totals = CurrencyTotalsBuilder()..addExpense('COP', 10);
    final built = totals.build();
    expect(built['COP'], const CurrencyTotals(expenses: 10));
    expect(built['COP']!.balance, 0);
    expect(built['COP']!.incomes, 0);
    expect(() => built['COP'] = const CurrencyTotals(), throwsUnsupportedError);
  });

  test('orders the preferred currency first and keeps zero balances', () {
    final builder = CurrencyTotalsBuilder()
      ..addBalance('USD', 0)
      ..addBalance('COP', 0)
      ..addBalance('EUR', 500);

    expect(orderedCurrencyCodes(builder.build(), preferred: 'COP'), [
      'COP',
      'EUR',
      'USD',
    ]);
    expect(orderedCurrencyCodes(builder.build(), preferred: 'EUR'), [
      'EUR',
      'COP',
      'USD',
    ]);
    expect(primaryCurrencyCode(builder.build(), preferred: 'COP'), 'COP');
    expect(primaryCurrencyCode(const {}), isNull);
  });

  test('currentMonthWindow returns the whole local month as UTC dates', () {
    final window = currentMonthWindow(DateTime(2026, 9, 29, 12, 30));
    expect(window.start, DateTime.utc(2026, 9, 1));
    expect(window.end, DateTime.utc(2026, 9, 30));
  });

  test('currentMonthWindow handles December and February', () {
    expect(
      currentMonthWindow(DateTime(2026, 12, 31, 23)).end,
      DateTime.utc(2026, 12, 31),
    );
    expect(
      currentMonthWindow(DateTime(2027, 1, 1)).start,
      DateTime.utc(2027, 1, 1),
    );
    expect(
      currentMonthWindow(DateTime(2026, 2, 10)).end,
      DateTime.utc(2026, 2, 28),
    );
  });

  test('isInCalendarMonth compares the calendar month', () {
    final now = DateTime(2026, 9, 29, 12);
    expect(isInCalendarMonth(DateTime.utc(2026, 9, 1), now), isTrue);
    expect(isInCalendarMonth(DateTime.utc(2026, 9, 30, 23, 59), now), isTrue);
    expect(isInCalendarMonth(DateTime.utc(2026, 8, 31), now), isFalse);
    expect(isInCalendarMonth(DateTime.utc(2026, 10, 1), now), isFalse);
    expect(isInCalendarMonth(DateTime.utc(2025, 9, 15), now), isFalse);
  });
}
