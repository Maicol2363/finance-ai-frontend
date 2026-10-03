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
}) => HistoryItem(
  id: id,
  type: TransactionType.expense,
  status: ExpenseStatus.confirmed,
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
}
