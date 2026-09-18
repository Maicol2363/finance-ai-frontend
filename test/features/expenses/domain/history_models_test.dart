import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/expenses/domain/history_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> movementJson() => {
  'account_id': 11,
  'account_name': 'Cash',
  'amount': '-25.00',
  'currency': {'id': 1, 'code': 'COP', 'name': 'Colombian Peso', 'decimals': 2},
  'currency_code': 'COP',
};

Map<String, Object?> historyItemJson({int id = 8, String type = 'expense'}) => {
  'id': id,
  'type': type,
  'status': 'confirmed',
  'occurred_at': '2026-09-17T12:30:00Z',
  'description': 'Purchase at Market',
  'capture_source': 'manual',
  'income_source': type == 'income' ? 'Salary' : null,
  'movements': [movementJson()],
  'expense': type == 'expense'
      ? {
          'receipt_id': 9,
          'name': 'Market',
          'occurred_at': '2026-09-17T00:00:00Z',
          'purchased_at': '2026-09-17T00:00:00Z',
          'total_amount': '25.00',
          'note': 'Household purchase',
          'store': 'Market',
          'store_name': 'Market',
          'items': [
            {
              'id': 7,
              'name': 'Groceries',
              'amount': '25.00',
              'quantity': '1.000',
              'unit_price': '25.00',
              'note': 'Weekly food',
              'category': {'id': 3, 'name': 'Food'},
              'image_path': 'expense.jpg',
            },
          ],
          'receipt_image': 'receipt.jpg',
        }
      : null,
};

void main() {
  test('decodes unified history with money, UTC times, and grouping', () {
    final result = HistoryResult.fromJson({
      'items': [historyItemJson(), historyItemJson(id: 9, type: 'income')],
      'total': 2,
      'page': 1,
      'page_size': 50,
      'has_next': false,
    });

    final expense = result.items.first;
    expect(expense.type, TransactionType.expense);
    expect(expense.occurredAt.isUtc, isTrue);
    expect(expense.movements.single.amount, MoneyAmount.parseApi('-25.00'));
    expect(expense.expense?.totalAmount, MoneyAmount.parseApi('25.00'));
    expect(expense.expense?.items.single.category?.name, 'Food');

    final income = result.items[1];
    expect(income.type, TransactionType.income);
    expect(income.incomeSource, 'Salary');
    expect(income.expense, isNull);
  });

  test('filters build the exact backend query parameters', () {
    final params = const HistoryFilters(
      search: '  market ',
      type: TransactionType.expense,
      categoryId: 3,
      accountId: 11,
      period: HistoryPeriod.custom,
      startDate: null,
      endDate: null,
      page: 2,
      pageSize: 10,
    ).toQueryParameters();

    expect(params, {
      'page': '2',
      'page_size': '10',
      'search': 'market',
      'type': 'expense',
      'category_id': '3',
      'account_id': '11',
      'period': 'custom',
    });
  });

  test('blank search is omitted and dates use yyyy-MM-dd', () {
    final params = HistoryFilters(
      search: '   ',
      startDate: DateTime.utc(2026, 9, 1),
      endDate: DateTime.utc(2026, 9, 15),
    ).toQueryParameters();

    expect(params.containsKey('search'), isFalse);
    expect(params['start_date'], '2026-09-01');
    expect(params['end_date'], '2026-09-15');
  });

  test('malformed history fails closed', () {
    for (final value in [
      {...historyItemJson(), 'id': 0},
      {...historyItemJson(), 'type': 'refund'},
      {...historyItemJson(), 'occurred_at': 'soon'},
      {
        ...historyItemJson(),
        'movements': [
          {...movementJson(), 'amount': '25'},
        ],
      },
    ]) {
      expect(
        () => HistoryItem.fromJson(value),
        throwsA(isA<FormatException>()),
      );
    }
    expect(
      () => HistoryPeriod.fromWire('yearly'),
      throwsA(isA<FormatException>()),
    );
  });
}
