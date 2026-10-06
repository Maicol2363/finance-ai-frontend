import 'dart:convert';
import 'dart:io';

import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/expenses/domain/expense_models.dart';
import 'package:finance_ai/features/expenses/domain/history_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Decodes payloads captured from the live backend (PostgreSQL + commit
/// `fcd6e8f`) with the real Dart models. If the API contract drifts, these
/// tests fail: regenerate the fixtures from a live backend after any
/// intentional contract change.
Map<String, Object?> loadFixture(String name) {
  final file = File('test/features/expenses/contract/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}

void main() {
  test('live expense detail decodes with exact money and references', () {
    final expense = Expense.fromJson(loadFixture('live_expense_detail.json'));

    expect(expense.id, 1);
    expect(expense.transactionId, 1);
    expect(expense.receiptId, 1);
    expect(expense.name, 'Groceries');
    expect(expense.amount, MoneyAmount.parseApi('25.00'));
    expect(expense.quantity, '1.000');
    expect(expense.unitPrice, MoneyAmount.parseApi('25.00'));
    expect(expense.category?.id, 4);
    expect(expense.receiptName, 'Market');
    expect(expense.store, 'Market');
    expect(expense.status, ExpenseStatus.confirmed);
    expect(expense.captureSource, CaptureSource.manual);
    expect(expense.accountId, 1);
    expect(expense.accountName, 'Cash');
    expect(expense.accountIsActive, isTrue);
    expect(expense.currencyCode, 'COP');
    expect(expense.receiptImage, 'receipt.jpg');
    expect(expense.imagePath, 'expense.jpg');
    expect(expense.occurredAt.isUtc, isTrue);
    expect(expense.isEditable, isTrue);
  });

  test('live history decodes grouping, movements, and currency', () {
    final result = HistoryResult.fromJson(loadFixture('live_history.json'));

    expect(result.total, 1);
    expect(result.hasNext, isFalse);
    final item = result.items.single;
    expect(item.type, TransactionType.expense);
    expect(item.status, ExpenseStatus.confirmed);
    expect(item.incomeSource, isNull);

    final movement = item.movements.single;
    expect(movement.accountId, 1);
    expect(movement.amount, MoneyAmount.parseApi('-25.00'));
    expect(movement.currencyCode, 'COP');

    final group = item.expense!;
    expect(group.receiptId, 1);
    expect(group.totalAmount, MoneyAmount.parseApi('25.00'));
    expect(group.store, 'Market');
    final line = group.items.single;
    expect(line.name, 'Groceries');
    expect(line.amount, MoneyAmount.parseApi('25.00'));
    expect(line.category?.name, 'Food');
    expect(line.imagePath, 'expense.jpg');
  });
}
