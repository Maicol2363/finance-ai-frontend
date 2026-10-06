import 'package:flutter/foundation.dart';

/// Money totals for one currency, in integer minor units.
///
/// Amounts in different currencies are never added together: every total is
/// accumulated under its own currency code (see [CurrencyTotalsBuilder]).
@immutable
class CurrencyTotals {
  const CurrencyTotals({this.balance = 0, this.incomes = 0, this.expenses = 0});

  /// Stock: Σ live account balances (all-time), the money actually available.
  final int balance;

  /// Flow: Σ incomes inside the reported period.
  final int incomes;

  /// Flow: Σ expenses inside the reported period, as a positive magnitude.
  final int expenses;

  /// Period result (`ingresos − gastos`).
  int get flow => incomes - expenses;

  bool get isEmpty => balance == 0 && incomes == 0 && expenses == 0;

  CurrencyTotals copyWith({int? balance, int? incomes, int? expenses}) {
    return CurrencyTotals(
      balance: balance ?? this.balance,
      incomes: incomes ?? this.incomes,
      expenses: expenses ?? this.expenses,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CurrencyTotals &&
      other.balance == balance &&
      other.incomes == incomes &&
      other.expenses == expenses;

  @override
  int get hashCode => Object.hash(balance, incomes, expenses);

  @override
  String toString() =>
      'CurrencyTotals(balance: $balance, incomes: $incomes, '
      'expenses: $expenses)';
}

/// Accumulates [CurrencyTotals] keyed by currency code.
class CurrencyTotalsBuilder {
  final Map<String, CurrencyTotals> _totals = <String, CurrencyTotals>{};

  /// Adds a live account balance to the stock total of [currencyCode].
  void addBalance(String currencyCode, int minorUnits) => _mutate(
    currencyCode,
    (totals) => totals.copyWith(balance: totals.balance + minorUnits),
  );

  /// Adds an income to the period total of [currencyCode].
  void addIncome(String currencyCode, int minorUnits) => _mutate(
    currencyCode,
    (totals) => totals.copyWith(incomes: totals.incomes + minorUnits),
  );

  /// Adds an expense magnitude to the period total of [currencyCode].
  void addExpense(String currencyCode, int minorUnits) => _mutate(
    currencyCode,
    (totals) => totals.copyWith(expenses: totals.expenses + minorUnits),
  );

  Map<String, CurrencyTotals> build() => Map.unmodifiable(_totals);

  void _mutate(
    String currencyCode,
    CurrencyTotals Function(CurrencyTotals totals) update,
  ) {
    final current = _totals[currencyCode] ?? const CurrencyTotals();
    _totals[currencyCode] = update(current);
  }
}

/// Currency codes present in [totals], `preferred` first and the rest
/// alphabetically. Codes with zero totals are kept: an account with a zero
/// balance still belongs to the list.
List<String> orderedCurrencyCodes(
  Map<String, CurrencyTotals> totals, {
  String? preferred,
}) {
  final codes = totals.keys.toList();
  codes.sort((a, b) {
    if (a == preferred) {
      return -1;
    }
    if (b == preferred) {
      return 1;
    }
    return a.compareTo(b);
  });
  return codes;
}

/// The code rendered as the headline: [preferred] when it has data, the first
/// ordered code otherwise, and `null` when there is nothing to show.
String? primaryCurrencyCode(
  Map<String, CurrencyTotals> totals, {
  String? preferred,
}) {
  final codes = orderedCurrencyCodes(totals, preferred: preferred);
  if (codes.isEmpty) {
    return null;
  }
  return codes.first;
}

/// First and last day of the calendar month (local time) that contains [now].
///
/// Returned as UTC midnight so their `year/month/day` stay intact when they are
/// formatted for the API (`yyyy-MM-dd`), regardless of the device timezone.
({DateTime start, DateTime end}) currentMonthWindow(DateTime now) {
  final local = now.toLocal();
  final start = DateTime.utc(local.year, local.month);
  final end = DateTime.utc(
    local.year,
    local.month + 1,
  ).subtract(const Duration(days: 1));
  return (start: start, end: end);
}

/// True when [date] belongs to the calendar month of [now] (local time).
///
/// [date] may be a UTC-midnight calendar date (incomes) or a real instant
/// (expenses); only its year/month fields are compared.
bool isInCalendarMonth(DateTime date, DateTime now) {
  final local = now.toLocal();
  return date.year == local.year && date.month == local.month;
}
