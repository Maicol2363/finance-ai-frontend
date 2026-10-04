import 'package:flutter/material.dart';

import '../../../../core/formatters/money_formatter.dart';
import '../../../../core/theme/app_palette.dart';
import '../../domain/dashboard_summary.dart';

class TopCategoriesCard extends StatelessWidget {
  const TopCategoriesCard({
    required this.categories,
    required this.currency,
    required this.periodName,
    required this.onSelectCategory,
    super.key,
  });

  final List<TopCategoryItem> categories;
  final String currency;
  final String periodName;
  final void Function(TopCategoryItem item)? onSelectCategory;

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
                'Gastos por categoría',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
              Text(
                'Top 5 de $periodName',
                style: TextStyle(fontSize: 11, color: palette.muted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (categories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Sin datos suficientes para este periodo',
                  style: TextStyle(fontSize: 12, color: palette.muted),
                ),
              ),
            )
          else
            for (var i = 0; i < categories.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _CategoryProgressRow(
                item: categories[i],
                currency: currency,
                onTap: onSelectCategory != null
                    ? () => onSelectCategory!(categories[i])
                    : null,
              ),
            ],
        ],
      ),
    );
  }
}

class _CategoryProgressRow extends StatelessWidget {
  const _CategoryProgressRow({
    required this.item,
    required this.currency,
    this.onTap,
  });

  final TopCategoryItem item;
  final String currency;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shareFraction = (item.sharePct / 100).clamp(0.0, 1.0);

    return InkWell(
      key: Key('dashboard-category-${item.name}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                    ),
                  ),
                ),
                Text(
                  '${item.sharePct.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: palette.muted,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  MoneyFormatter.formatMinorUnits(
                    item.total.minorUnits,
                    currencyCode: currency,
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: shareFraction,
                backgroundColor: palette.soft,
                valueColor: AlwaysStoppedAnimation<Color>(
                  item.name == 'Otras' ? palette.muted : palette.primary,
                ),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
