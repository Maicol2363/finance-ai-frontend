import 'package:flutter/material.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/theme/app_palette.dart';
import 'spending_trend.dart';

// Fast v1 tendency card: daily bars plus plain-language hint.
// Reuses month items already loaded, no new request or package.
class SpendingTrendCard extends StatelessWidget {
  const SpendingTrendCard({
    required this.days,
    required this.currency,
    required this.available,
    super.key,
  });
  final List<DailySpend> days;
  final String currency;
  final bool available;
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tendency = spendingTendency(days);
    final total = days.fold<int>(0, (s, d) => s + d.minorUnits);
    final headline = switch (tendency) {
      'up' => 'Subiendo: gastas más que antes',
      'down' => 'Bajando: gastas menos que antes',
      'empty' => 'Sin gasto reciente',
      _ => 'Estable por ahora',
    };
    final icon = switch (tendency) {
      'up' => Icons.trending_up,
      'down' => Icons.trending_down,
      'empty' => Icons.remove,
      _ => Icons.trending_flat,
    };
    final color = switch (tendency) {
      'up' => palette.discard,
      'down' => palette.income,
      _ => palette.muted,
    };
    return Container(
      padding: const EdgeInsets.all(16),
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
              const Expanded(
                child: Text(
                  'Tendencia de gasto',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                key: const Key('dashboard-trend-badge'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(
                      headline,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            available ? '${days.length} días en $currency' : 'cargando...',
            style: TextStyle(fontSize: 11, color: palette.muted),
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Tendencia de gasto: $headline',
            child: SizedBox(
              height: 92,
              child: CustomPaint(
                painter: TrendBarsPainter(
                  days: available ? days : const [],
                  placeholderCount: days.length,
                  barColor: palette.primary,
                  emptyColor: palette.soft,
                  lineColor: palette.line,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final d in axisDays(days))
                Text(
                  '${d.day}',
                  style: TextStyle(fontSize: 10, color: palette.muted),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            available
                ? 'Total: ${MoneyFormatter.formatMinorUnits(total)} $currency'
                : 'Total: --',
            style: TextStyle(fontSize: 11, color: palette.muted),
          ),
        ],
      ),
    );
  }
}

List<DateTime> axisDays(List<DailySpend> v) {
  if (v.isEmpty) return const [];
  if (v.length == 1) return [v.first.day];
  return [v.first.day, v[v.length ~/ 2].day, v.last.day];
}

class TrendBarsPainter extends CustomPainter {
  const TrendBarsPainter({
    required this.days,
    required this.placeholderCount,
    required this.barColor,
    required this.emptyColor,
    required this.lineColor,
  });
  final List<DailySpend> days;
  final int placeholderCount;
  final Color barColor;
  final Color emptyColor;
  final Color lineColor;
  @override
  void paint(Canvas canvas, Size size) {
    final count = placeholderCount <= 0 ? 1 : placeholderCount;
    final slot = size.width / count;
    final barWidth = (slot * 0.52).clamp(6.0, 22.0);
    var peak = 1;
    for (final d in days) {
      if (d.minorUnits > peak) peak = d.minorUnits;
    }
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()..color = lineColor,
    );
    for (var i = 0; i < count; i++) {
      final v = i < days.length ? days[i].minorUnits : 0;
      final h = v <= 0
          ? 4.0
          : (v / peak * (size.height - 10)).clamp(4.0, size.height - 4);
      final left = i * slot + (slot - barWidth) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - h, barWidth, h),
          const Radius.circular(4),
        ),
        Paint()..color = v <= 0 ? emptyColor : barColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TrendBarsPainter o) =>
      o.days != days || o.placeholderCount != placeholderCount;
}
