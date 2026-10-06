import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/transfers/domain/transfer_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> transferJson() => {
  'id': 9,
  'source_account': {'id': 3, 'name': 'Cash', 'currency_code': 'COP'},
  'source_amount': '100.00',
  'destination_account': {'id': 4, 'name': 'Savings', 'currency_code': 'COP'},
  'destination_amount': '100.00',
  'date': '2026-09-18',
  'description': null,
  'created_at': '2026-09-18T12:00:00Z',
  'updated_at': '2026-09-18T12:00:00Z',
};

void main() {
  test('decodes transfers with both amounts and UTC timestamps', () {
    final transfer = Transfer.fromJson(transferJson());

    expect(transfer.id, 9);
    expect(transfer.sourceAmount, MoneyAmount.parseApi('100.00'));
    expect(transfer.destinationAmount, MoneyAmount.parseApi('100.00'));
    expect(transfer.sourceAccount.currencyCode, 'COP');
    expect(transfer.isCrossCurrency, isFalse);
    expect(transfer.createdAt.isUtc, isTrue);
  });

  test('detects cross-currency transfers', () {
    final transfer = Transfer.fromJson({
      ...transferJson(),
      'destination_account': {
        'id': 5,
        'name': 'Dólares',
        'currency_code': 'USD',
      },
      'destination_amount': '25.00',
    });

    expect(transfer.isCrossCurrency, isTrue);
    expect(transfer.destinationAmount, MoneyAmount.parseApi('25.00'));
  });

  test('commands use the exact server wire format', () {
    expect(
      TransferCreateCommand(
        sourceAccountId: 3,
        destinationAccountId: 4,
        sourceAmount: MoneyAmount.parseApi('100.00'),
        destinationAmount: null,
        date: DateTime.utc(2026, 9, 18),
        description: null,
      ).toJson(),
      {
        'source_account_id': 3,
        'destination_account_id': 4,
        'source_amount': '100.00',
        'date': '2026-09-18',
      },
    );

    final cross = TransferCreateCommand(
      sourceAccountId: 3,
      destinationAccountId: 5,
      sourceAmount: MoneyAmount.parseApi('100.00'),
      destinationAmount: MoneyAmount.parseApi('410000.00'),
      date: DateTime.utc(2026, 9, 18),
      description: 'Ahorro',
    ).toJson();
    expect(cross['destination_amount'], '410000.00');
    expect(cross['description'], 'Ahorro');
  });

  test('malformed responses fail closed', () {
    for (final value in [
      {...transferJson(), 'id': 0},
      {...transferJson(), 'source_amount': '100.000'},
      {...transferJson(), 'date': 'mañana'},
      {
        ...transferJson(),
        'source_account': {'id': 0, 'name': ''},
      },
    ]) {
      expect(() => Transfer.fromJson(value), throwsA(isA<FormatException>()));
    }
  });
}
