import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../application/dashboard_metrics.dart';

class InsightsCard extends StatelessWidget {
  const InsightsCard({
    required this.insights,
    super.key,
  });

  final List<DashboardInsight> insights;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const SizedBox.shrink();
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
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: palette.primary),
              const SizedBox(width: 8),
              Text(
                'Análisis inteligente',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < insights.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _InsightRow(insight: insights[i]),
          ],
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.insight});

  final DashboardInsight insight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final (icon, iconColor) = switch (insight.type) {
      InsightType.warning => (Icons.warning_amber_rounded, palette.discard),
      InsightType.positive => (Icons.shield_outlined, palette.income),
      InsightType.info => (Icons.insights, palette.primary),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  insight.message,
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.muted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
