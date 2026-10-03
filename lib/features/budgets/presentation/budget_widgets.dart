import 'package:flutter/material.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/theme/app_palette.dart';
import '../../accounts/domain/account_models.dart';
import '../../categories/presentation/category_visuals.dart';
import '../domain/budget_models.dart';

class BudgetProgressCard extends StatelessWidget {
  const BudgetProgressCard({
    required this.budget,
    this.onTap,
    this.compact = false,
    super.key,
  });

  final Budget budget;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final category = budget.category;
    final scope = category?.name ?? 'Todos los gastos';
    final title = budget.name == 'All expenses' ? scope : budget.name;
    final schedule = budget.scheduleLabel;
    final exceeded = budget.remainingAmount.isNegative;
    // Fast v1 proximity: warn when the budget is active and usage hit 80%.
    final nearLimit =
        !exceeded && budget.isActive && budget.progressPercent >= 80;
    final card = Container(
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: exceeded
              ? palette.discard
              : nearLimit
              ? palette.warnFg
              : palette.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (category?.color.value ?? palette.primary).withValues(
                    alpha: 0.13,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  category?.icon.value ?? Icons.account_balance_wallet_outlined,
                  size: 20,
                  color: category?.color.value ?? palette.primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      key: Key('budget-category-${budget.id}'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${title == scope ? schedule : '$scope · $schedule'} · ${_date(budget.currentPeriodStart)} – ${_date(budget.currentPeriodEnd)}',
                      style: TextStyle(fontSize: 11, color: palette.muted),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, size: 20, color: palette.muted),
            ],
          ),
          const SizedBox(height: 14),
          if (nearLimit) ...[
            Container(
              key: Key('budget-near-limit-${budget.id}'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: palette.warnBg,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: palette.warnFg,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '¡Casi al límite! Te acercas al tope',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: palette.warnFg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          Semantics(
            label: exceeded
                ? '$title: ${budget.progressPercent.toStringAsFixed(0)} por ciento usado, excedido'
                : nearLimit
                ? '$title: ${budget.progressPercent.toStringAsFixed(0)} por ciento usado, casi al límite'
                : '$title: ${budget.progressPercent.toStringAsFixed(0)} por ciento usado',
            value: budget.progressFraction.toStringAsFixed(2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                key: Key('budget-progress-${budget.id}'),
                value: budget.progressFraction,
                minHeight: 9,
                backgroundColor: palette.soft,
                color: exceeded
                    ? palette.discard
                    : nearLimit
                    ? palette.warnFg
                    : palette.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  '${_money(budget.spentAmount, budget.currency.code)} de ${_money(budget.amount, budget.currency.code)}',
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
              ),
              Text(
                exceeded
                    ? 'Excedido ${_moneyAbs(budget.remainingAmount, budget.currency.code)}'
                    : nearLimit
                    ? '¡Quedan ${_money(budget.remainingAmount, budget.currency.code)}!'
                    : 'Quedan ${_money(budget.remainingAmount, budget.currency.code)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: exceeded
                      ? palette.discard
                      : nearLimit
                      ? palette.warnFg
                      : palette.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('budget-card-${budget.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      ),
    );
  }

  static String _money(MoneyAmount amount, String currency) =>
      MoneyFormatter.formatMinorUnits(
        amount.minorUnits,
        currencyCode: currency,
      );

  static String _moneyAbs(MoneyAmount amount, String currency) =>
      MoneyFormatter.formatMinorUnits(
        amount.minorUnits.abs(),
        currencyCode: currency,
      );

  static String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}
