import 'package:flutter/material.dart';

import '../../../../core/formatters/money_formatter.dart';
import '../../../../core/money/currency_totals.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../accounts/domain/account_models.dart';

/// "3 cuentas activas · $ 100 COP · Ver saldos": the way into accounts and
/// balances. It used to sit in the balance card of the Gastos tab, which is now
/// the capture chat.
class AccountsShortcut extends StatelessWidget {
  const AccountsShortcut({
    super.key,
    required this.accounts,
    required this.stock,
    required this.orderedCodes,
    required this.onTap,
  });

  final List<Account> accounts;
  final Map<String, CurrencyTotals> stock;
  final List<String> orderedCodes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final activeCount = accounts.where((account) => account.isActive).length;
    final perCurrency = orderedCodes
        .map((code) => MoneyFormatter.display(stock[code]?.balance ?? 0, code))
        .join(' · ');
    final label = activeCount > 0
        ? '$activeCount ${activeCount == 1 ? 'cuenta activa' : 'cuentas activas'}'
              '${perCurrency.isEmpty ? '' : ' · $perCurrency'} · Ver saldos'
        : 'Gestionar cuentas y saldos';
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: InkWell(
        key: const Key('home-accounts-button'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 20,
                  color: palette.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: palette.primary,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: palette.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
