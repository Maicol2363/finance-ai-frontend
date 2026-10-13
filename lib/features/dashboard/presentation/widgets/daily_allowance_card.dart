import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';

import '../../../../core/formatters/money_formatter.dart';
import '../../../../core/theme/app_palette.dart';

class DailyAllowanceCard extends StatelessWidget {
  const DailyAllowanceCard({
    required this.dailyAllowanceMinorUnits,
    required this.spentMtdMinorUnits,
    required this.projectedMinorUnits,
    required this.remainingDays,
    required this.currency,
    super.key,
  });

  final int? dailyAllowanceMinorUnits;
  final int spentMtdMinorUnits;
  final int projectedMinorUnits;
  final int remainingDays;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final allowanceText = dailyAllowanceMinorUnits != null
        ? MoneyFormatter.formatMinorUnits(
            dailyAllowanceMinorUnits!,
            currencyCode: currency,
          )
        : '—';

    final projectedText = MoneyFormatter.formatMinorUnits(
      projectedMinorUnits,
      currencyCode: currency,
    );

    final mtdText = MoneyFormatter.formatMinorUnits(
      spentMtdMinorUnits,
      currencyCode: currency,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                FinanceIcons.speedOutlined,
                size: 18,
                color: palette.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ritmo de gasto diario',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$remainingDays días restantes',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: palette.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Puedes gastar hasta',
            style: TextStyle(fontSize: 11, color: palette.muted),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                allowanceText,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: palette.text,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/ día',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: palette.line),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gastado hasta hoy (MTD)',
                    style: TextStyle(fontSize: 10, color: palette.muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mtdText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Proyección a fin de mes',
                    style: TextStyle(fontSize: 10, color: palette.muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    projectedText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: palette.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
