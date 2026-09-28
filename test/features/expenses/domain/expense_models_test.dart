import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/expenses/domain/expense_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> expenseJson({int id = 7}) => {
  'id': id,
  'transaction_id': 8,
  'receipt_id': 9,
  'name': 'Groceries',
  'amount': '25.00',
  'quantity': '1.000',
  'unit_price': '25.00',
  'note': 'Weekly food',
  'category': {'id': 3, 'name': 'Food'},
  'receipt_name': 'Market',
  'receipt_note': 'Household purchase',
  'store': 'Market',
  'description': 'Purchase at Market',
  'occurred_at': '2026-09-17T12:30:00Z',
  'status': 'confirmed',
  'capture_source': 'manual',
  'account_id': 11,
  'account_name': 'Cash',
  'account_is_active': true,
  'currency': {'id': 1, 'code': 'COP', 'name': 'Colombian Peso', 'decimals': 2},
  'currency_code': 'COP',
  'created_at': '2026-09-17T12:30:00Z',
  'updated_at': '2026-09-17T12:30:00Z',
  'receipt_image': 'receipt.jpg',
  'image_path': 'expense.jpg',
};

void main() {
  test('decodes expense detail, list, UTC times, and editability', () {
    final result = ExpenseListResult.fromJson({
      'items': [expenseJson()],
      'total': 1,
      'page': 1,
      'page_size': 50,
      'has_next': false,
    });

    final expense = result.items.single;
    expect(expense.amount, MoneyAmount.parseApi('25.00'));
    expect(expense.unitPrice, MoneyAmount.parseApi('25.00'));
    expect(expense.category?.name, 'Food');
    expect(expense.occurredAt.isUtc, isTrue);
    expect(expense.isEditable, isTrue);
    expect(result.hasNext, isFalse);
  });

  test('pending expenses are not editable', () {
    final expense = Expense.fromJson({...expenseJson(), 'status': 'pending'});

    expect(expense.isEditable, isFalse);
  });

  test('update command uses the exact server wire format', () {
    expect(
      ExpenseUpdateCommand(
        name: 'Updated groceries',
        amount: MoneyAmount.parseApi('30.00'),
        categoryId: 3,
        accountId: 11,
        description: 'Updated purchase',
      ).toJson(),
      {
        'name': 'Updated groceries',
        'amount': '30.00',
        'category_id': 3,
        'account_id': 11,
        'description': 'Updated purchase',
      },
    );
  });

  test('update command distinguishes absent fields from explicit clears', () {
    expect(const ExpenseUpdateCommand().toJson(), isEmpty);
    expect(
      const ExpenseUpdateCommand(clearNote: true, clearCategory: true).toJson(),
      {'note': null, 'category_id': null},
    );
  });

  test('malformed responses fail closed', () {
    for (final value in [
      {...expenseJson(), 'id': 0},
      {...expenseJson(), 'amount': '25.000'},
      {...expenseJson(), 'status': 'draft'},
      {...expenseJson(), 'capture_source': 'voice'},
      {...expenseJson(), 'occurred_at': 'yesterday'},
      {...expenseJson(), 'unit_price': 25},
      {
        ...expenseJson(),
        'category': {'id': 0, 'name': ''},
      },
    ]) {
      expect(() => Expense.fromJson(value), throwsA(isA<FormatException>()));
    }
    expect(
      () => ExpenseListResult.fromJson({
        'items': const [],
        'total': -1,
        'page': 0,
        'page_size': 50,
        'has_next': false,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('expense item update command serializes money as exact strings', () {
    const command = ExpenseItemUpdateCommand(
      name: 'Leche',
      totalPrice: 4000.5,
      quantity: 2,
      unitPrice: 2000.25,
      categoryId: 3,
      note: 'Fria',
    );

    expect(command.toJson(), {
      'name': 'Leche',
      'total_price': '4000.50',
      'quantity': '2.0',
      'unit_price': '2000.25',
      'category_id': 3,
      'note': 'Fria',
    });
  });

  test(
    'expense update command omits receipt lines unless they are replaced',
    () {
      const untouched = ExpenseUpdateCommand(name: 'Renamed');
      const replaced = ExpenseUpdateCommand(
        items: [ExpenseItemUpdateCommand(name: 'Leche', totalPrice: 4000)],
      );

      expect(untouched.toJson().containsKey('items'), isFalse);
      expect(replaced.toJson()['items'], [
        {'name': 'Leche', 'total_price': '4000.00', 'quantity': '1.0'},
      ]);
    },
  );

  test('expense items expose the stored category id', () {
    final item = ExpenseItem.fromJson({
      'name': 'Leche',
      'amount': '4000.00',
      'quantity': '1.000',
      'unit_price': '4000.00',
      'category': {'id': 3, 'name': 'Food'},
      'note': null,
    });

    expect(item.categoryId, 3);
    expect(item.categoryName, 'Food');
  });
}
