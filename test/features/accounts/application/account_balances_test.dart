import 'package:finance_ai/features/accounts/application/account_balances.dart';
import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _cop = CurrencySummary(
  id: 1,
  code: 'COP',
  name: 'Colombian Peso',
  decimals: 2,
);
const _usd = CurrencySummary(
  id: 2,
  code: 'USD',
  name: 'US Dollar',
  decimals: 2,
);

Account account({
  required int id,
  String code = 'COP',
  CurrencySummary currency = _cop,
  String balance = '0.00',
  bool isActive = true,
}) => Account(
  id: id,
  name: 'Account $id',
  type: AccountType.cash,
  currency: currency,
  balance: MoneyAmount.parseApi(balance),
  openingBalance: MoneyAmount.parseApi(balance),
  currencyIsLocked: false,
  isActive: isActive,
  createdAt: DateTime.utc(2026, 9, 1),
  updatedAt: DateTime.utc(2026, 9, 1),
);

void main() {
  test('sums the live balances of the active accounts per currency', () {
    final totals = activeAccountBalances([
      account(id: 1, balance: '1000000.00'),
      account(id: 2, balance: '25000.50'),
      account(id: 3, currency: _usd, balance: '12.50'),
      account(id: 4, balance: '999.00', isActive: false),
    ]);

    expect(totals['COP']!.balance, 102500050);
    expect(totals['USD']!.balance, 1250);
    expect(totals['COP']!.incomes, 0);
    expect(totals['COP']!.expenses, 0);
  });

  test(
    'keeps negative balances negative and returns no currency when empty',
    () {
      expect(
        activeAccountBalances([
          account(id: 1, balance: '-300.00'),
        ])['COP']!.balance,
        -30000,
      );
      expect(activeAccountBalances(const []), isEmpty);
      expect(activeAccountBalances([account(id: 1, isActive: false)]), isEmpty);
    },
  );
}
