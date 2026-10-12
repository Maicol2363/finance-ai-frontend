import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> accountJson({
  String openingBalance = '100000.00',
  String balance = '85000.50',
  bool currencyIsLocked = true,
}) => {
  'id': 11,
  'name': 'Daily cash',
  'type': 'cash',
  'currency': {'id': 1, 'code': 'COP', 'name': 'Colombian Peso', 'decimals': 2},
  'opening_balance': openingBalance,
  'balance': balance,
  'currency_is_locked': currencyIsLocked,
  'is_active': true,
  'created_at': '2026-09-08T01:00:00Z',
  'updated_at': '2026-09-08T02:00:00Z',
};

void main() {
  test('account type labels are Spanish while API wire values stay stable', () {
    expect(AccountType.values.map((type) => type.label).toList(), [
      'Efectivo',
      'Cuenta bancaria',
      'Billetera digital',
      'Ahorros',
      'Tarjeta de crédito',
      'Otra',
    ]);
    expect(AccountType.values.map((type) => type.wireValue).toList(), [
      'cash',
      'bank',
      'digital_wallet',
      'savings',
      'credit_card',
      'other',
    ]);
  });

  group('MoneyAmount', () {
    test('round-trips exact positive, negative, and zero API strings', () {
      for (final value in ['0.00', '100000.05', '-9999999999999999.99']) {
        expect(MoneyAmount.parseApi(value).toApiString(), value);
      }
    });

    test(
      'accepts dot or comma user decimals without binary floating point',
      () {
        expect(MoneyAmount.tryParseUserInput(' 12,5 ')?.toApiString(), '12.50');
        expect(MoneyAmount.tryParseUserInput('-0.07')?.minorUnits, -7);
        expect(MoneyAmount.tryParseUserInput('42')?.toApiString(), '42.00');
      },
    );

    test('rejects grouping, extra precision, invalid text, and overflow', () {
      for (final value in [
        '1,234.50',
        '1.2.3',
        '0.001',
        'COP 10',
        '10000000000000000.00',
      ]) {
        expect(MoneyAmount.tryParseUserInput(value), isNull);
      }
      expect(
        () => MoneyAmount.parseApi('12.3'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('account decoding retains exact balance and currency lock state', () {
    final account = Account.fromJson(accountJson());

    expect(account.id, 11);
    expect(account.type, AccountType.cash);
    expect(account.openingBalance.minorUnits, 10000000);
    expect(account.balance.toApiString(), '85000.50');
    expect(account.currencyIsLocked, isTrue);
    expect(account.createdAt.isUtc, isTrue);
  });

  test('list contract requires supported suggestion and controlled types', () {
    final result = AccountListResult.fromJson({
      'accounts': [accountJson()],
      'suggested_currency_code': 'COP',
      'supported_currencies': [accountJson()['currency']],
      'account_types': ['cash', 'bank'],
    });

    expect(result.accounts.single.id, 11);
    expect(result.accountTypes, [AccountType.cash, AccountType.bank]);
    expect(result.accountById(11)?.name, 'Daily cash');

    expect(
      () => AccountListResult.fromJson({
        'accounts': const [],
        'suggested_currency_code': 'USD',
        'supported_currencies': [accountJson()['currency']],
        'account_types': ['cash'],
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('commands serialize money only as canonical strings', () {
    final command = AccountCreateCommand(
      name: 'Card',
      type: AccountType.creditCard,
      currencyCode: 'COP',
      openingBalance: MoneyAmount.parseApi('-250.00'),
    );

    expect(command.toJson(), {
      'name': 'Card',
      'type': 'credit_card',
      'currency_code': 'COP',
      'opening_balance': '-250.00',
    });
    expect(command.toJson()['opening_balance'], isA<String>());
  });

  test('malformed success payloads fail closed', () {
    expect(
      () => Account.fromJson({...accountJson(), 'currency_is_locked': 'yes'}),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => Account.fromJson({...accountJson(), 'type': 'brokerage'}),
      throwsA(isA<FormatException>()),
    );
  });
}
