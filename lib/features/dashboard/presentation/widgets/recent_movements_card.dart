import 'package:flutter/material.dart';

import '../../../../core/formatters/money_formatter.dart';
import '../../../../core/theme/app_palette.dart';
import '../../domain/dashboard_summary.dart';

class RecentMovementsCard extends StatelessWidget {
  const RecentMovementsCard({
    required this.movements,
    required this.currency,
    required this.onViewAll,
    super.key,
  });

  final List<RecentMovementItem> movements;
  final String currency;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Últimos movimientos',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
              InkWell(
                onTap: onViewAll,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Text(
                    'Ver historial',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (movements.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No hay movimientos recientes',
                  style: TextStyle(fontSize: 12, color: palette.muted),
                ),
              ),
            )
          else
            for (var i = 0; i < movements.length; i++) ...[
              if (i > 0) Divider(height: 12, color: palette.line),
              _MovementTile(movement: movements[i], currency: currency),
            ],
        ],
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement, required this.currency});

  final RecentMovementItem movement;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isIncome = movement.type == 'income';
    final amountUnits = movement.amount.minorUnits;
    final color = isIncome ? palette.income : palette.discard;
    final dateStr =
        '${movement.occurredAt.day}/${movement.occurredAt.month.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              size: 14,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 11, color: palette.muted),
                ),
              ],
            ),
          ),
          Text(
            MoneyFormatter.formatSignedMinorUnits(
              isIncome ? amountUnits : -amountUnits,
              currencyCode: currency,
            ),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
