import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/manage_widgets.dart';
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
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ManageRow(
            title: title,
            subtitle:
                '${title == scope ? schedule : '$scope · $schedule'} · ${_date(budget.currentPeriodStart)} – ${_date(budget.currentPeriodEnd)}',
            icon:
                category?.icon.emphasisValue ??
                FinanceIconCatalog.emphasisDataFor(FinanceIconKey.account),
            swatchColor: category?.color.value,
            trailing: [
              if (onTap != null)
                Icon(FinanceIcons.chevronRight, size: 20, color: palette.muted),
            ],
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              14,
              compact ? 0 : 2,
              14,
              compact ? 14 : 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (nearLimit) ...[
                  Container(
                    key: Key('budget-near-limit-${budget.id}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: palette.warnBg,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          FinanceIcons.warningAmberRounded,
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
      MoneyFormatter.display(amount.minorUnits, currency);

  static String _moneyAbs(MoneyAmount amount, String currency) =>
      MoneyFormatter.display(amount.minorUnits.abs(), currency);

  static String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}
