import '../../../core/money/currency_totals.dart';
import '../domain/account_models.dart';

/// Stock totals: the sum of the live balances of the active accounts, grouped
/// by currency.
///
/// This is the only definition of "balance" in the app: it is what the accounts
/// really hold (`opening_balance + Σ movements`, computed by the API), so the
/// Gastos hub and the Dashboard show the same number. Flow figures
/// (month incomes/expenses) come from `monthlyTotalsProvider` instead.
Map<String, CurrencyTotals> activeAccountBalances(Iterable<Account> accounts) {
  final builder = CurrencyTotalsBuilder();
  for (final account in accounts) {
    if (!account.isActive) {
      continue;
    }
    builder.addBalance(account.currency.code, account.balance.minorUnits);
  }
  return builder.build();
}
