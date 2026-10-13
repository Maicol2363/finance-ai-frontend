import 'package:finance_ai/core/icons/finance_icon_catalog.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/theme/app_palette.dart';
import 'spending_trend.dart';

/// Spending pace & trend card: cumulative burn-up curve showing actual spend
/// up to today, daily pace, and projected closing amount.
class SpendingTrendCard extends StatelessWidget {
  const SpendingTrendCard({
    required this.days,
    required this.currency,
    required this.available,
    this.cumulativeDays,
    this.totalDaysInPeriod,
    this.projectedMinorUnits,
    this.weekly,
    this.comparisonLabel,
    this.comparisonDirection,
    this.averageMinorUnits,
    super.key,
  });

  final List<DailySpend> days;
  final String currency;
  final bool available;

  /// Explicit day-by-day cumulative spend series.
  /// If null, computed automatically from [days].
  final List<CumulativeSpendDay>? cumulativeDays;

  /// Total days in the active period window (e.g. 30 or 31 in a month).
  final int? totalDaysInPeriod;

  /// Projected total spend at the end of the period.
  final int? projectedMinorUnits;

  /// Weekly buckets for multi-week / year views or fallback.
  final List<WeeklySpend>? weekly;

  /// Badge text, e.g. `+48% vs ago`.
  final String? comparisonLabel;

  /// Direction ('up', 'down', 'flat', 'empty') for the badge arrow and color.
  final String? comparisonDirection;

  /// Mean per bucket / average line.
  final int? averageMinorUnits;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tendency = spendingTendency(days);

    // Resolve cumulative points
    final List<CumulativeSpendDay> cumulative;
    if (cumulativeDays != null && cumulativeDays!.isNotEmpty) {
      cumulative = cumulativeDays!;
    } else if (days.isNotEmpty) {
      var running = 0;
      cumulative = [
        for (final d in days)
          CumulativeSpendDay(
            day: d.day,
            dailyMinorUnits: d.minorUnits,
            cumulativeMinorUnits: (running += d.minorUnits),
          ),
      ];
    } else {
      cumulative = const <CumulativeSpendDay>[];
    }

    final totalSpent = cumulative.isNotEmpty
        ? cumulative.last.cumulativeMinorUnits
        : days.fold<int>(0, (s, d) => s + d.minorUnits);

    final weekDays = weekly;
    final useWeeklyRows =
        weekDays != null && weekDays.isNotEmpty && cumulativeDays == null;

    final weekTotal = useWeeklyRows
        ? weekDays.fold<int>(0, (s, w) => s + w.minorUnits)
        : 0;
    final shownTotal = useWeeklyRows ? weekTotal : totalSpent;

    final effectiveTotalDays =
        totalDaysInPeriod ??
        (cumulative.isNotEmpty
            ? cumulative.length
            : (days.isNotEmpty ? days.length : 1));

    final daysElapsed = cumulative.isNotEmpty ? cumulative.length : days.length;

    final bucketCount = useWeeklyRows ? weekDays.length : daysElapsed;

    final unit = bucketCount == 1
        ? 'semana'
        : useWeeklyRows
        ? 'semanas'
        : 'días';

    final headline =
        comparisonLabel ??
        switch (tendency) {
          'up' => 'Subiendo: gastas más que antes',
          'down' => 'Bajando: gastas menos que antes',
          'empty' => 'Sin gasto reciente',
          _ => 'Estable por ahora',
        };

    final String resolvedDirection;
    if (comparisonDirection != null && comparisonDirection != 'none') {
      resolvedDirection = comparisonDirection!;
    } else if (comparisonLabel != null) {
      final lower = comparisonLabel!.toLowerCase();
      if (comparisonLabel!.startsWith('+') || lower.contains('subiendo')) {
        resolvedDirection = 'up';
      } else if (comparisonLabel!.startsWith('-') ||
          lower.contains('bajando')) {
        resolvedDirection = 'down';
      } else if (lower.contains('igual')) {
        resolvedDirection = 'flat';
      } else {
        resolvedDirection = tendency;
      }
    } else {
      resolvedDirection = tendency;
    }

    final icon = switch (resolvedDirection) {
      'up' => FinanceIcons.trendingUp,
      'down' => FinanceIcons.trendingDown,
      'empty' => FinanceIcons.remove,
      _ => FinanceIcons.trendingFlat,
    };
    final color = switch (resolvedDirection) {
      'up' => palette.discard,
      'down' => palette.income,
      _ => palette.muted,
    };

    final dailyPace = daysElapsed > 0 ? (totalSpent / daysElapsed).round() : 0;

    return _TrendBody(
      cumulative: cumulative,
      totalDays: effectiveTotalDays,
      daysElapsed: daysElapsed,
      dailyPace: dailyPace,
      projectedMinorUnits: projectedMinorUnits,
      useWeeklyRows: useWeeklyRows,
      weeks: weekDays,
      bucketCount: bucketCount,
      unit: unit,
      shownTotal: shownTotal,
      headline: headline,
      icon: icon,
      color: color,
      currency: currency,
      available: available,
      averageMinorUnits: averageMinorUnits,
    );
  }
}

class _TrendBody extends StatefulWidget {
  const _TrendBody({
    required this.cumulative,
    required this.totalDays,
    required this.daysElapsed,
    required this.dailyPace,
    required this.projectedMinorUnits,
    required this.useWeeklyRows,
    required this.weeks,
    required this.bucketCount,
    required this.unit,
    required this.shownTotal,
    required this.headline,
    required this.icon,
    required this.color,
    required this.currency,
    required this.available,
    required this.averageMinorUnits,
  });

  final List<CumulativeSpendDay> cumulative;
  final int totalDays;
  final int daysElapsed;
  final int dailyPace;
  final int? projectedMinorUnits;
  final bool useWeeklyRows;
  final List<WeeklySpend>? weeks;
  final int bucketCount;
  final String unit;
  final int shownTotal;
  final String headline;
  final IconData icon;
  final Color color;
  final String currency;
  final bool available;
  final int? averageMinorUnits;

  @override
  State<_TrendBody> createState() => _TrendBodyState();
}

class _TrendBodyState extends State<_TrendBody> {
  int? selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sel = selected;
    final selLabel = sel == null || sel < 0 || sel >= widget.cumulative.length
        ? null
        : _bucketLabel(sel);

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
              Expanded(
                child: Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'Tendencia de gasto',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'La línea continua muestra el gasto acumulado hasta hoy. La punteada une ese total con el estimado al cierre: en el mes actual usa la proyección del resumen; en otros periodos calcula (gasto acumulado ÷ días transcurridos) × días del periodo. Puede subir o quedar horizontal; representa un ritmo promedio, no gastos diarios exactos.',
                      triggerMode: TooltipTriggerMode.tap,
                      child: Icon(
                        FinanceIcons.infoOutlineRounded,
                        size: 15,
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Container(
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
                      Icon(widget.icon, size: 14, color: widget.color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          widget.headline,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: widget.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _buildSubtitle(),
            style: TextStyle(fontSize: 11, color: palette.muted),
          ),
          const SizedBox(height: 12),
          if (widget.useWeeklyRows && widget.weeks != null)
            _buildWeeklyRows(palette)
          else ...[
            _buildLegend(palette),
            const SizedBox(height: 10),
            Semantics(
              label:
                  'Tendencia de gasto: ${widget.headline}. Acumulado a la fecha: ${MoneyFormatter.display(widget.shownTotal, widget.currency)}.',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: widget.available && widget.cumulative.isNotEmpty
                    ? (details) {
                        final box = context.findRenderObject() as RenderBox?;
                        if (box == null) return;
                        final chartWidth = box.size.width - 32;
                        if (chartWidth <= 0) return;
                        final dx =
                            (box.globalToLocal(details.globalPosition).dx - 16)
                                .clamp(0.0, chartWidth);
                        final total = widget.totalDays > 1
                            ? widget.totalDays
                            : widget.cumulative.length;

                        final firstDay = widget.cumulative.first.day;
                        int closest = 0;
                        double minDist = double.infinity;
                        for (var i = 0; i < widget.cumulative.length; i++) {
                          final pt = widget.cumulative[i];
                          final offsetDays = pt.day.difference(firstDay).inDays;
                          final px = total > 1
                              ? (offsetDays / (total - 1)).clamp(0.0, 1.0) *
                                    chartWidth
                              : chartWidth / 2;
                          final dist = (px - dx).abs();
                          if (dist < minDist) {
                            minDist = dist;
                            closest = i;
                          }
                        }
                        setState(() => selected = closest);
                      }
                    : null,
                child: SizedBox(
                  key: const Key('dashboard-trend-chart'),
                  width: double.infinity,
                  height: 104,
                  child: CustomPaint(
                    painter: CumulativeSpendCurvePainter(
                      points: widget.available
                          ? widget.cumulative
                          : const <CumulativeSpendDay>[],
                      totalDays: widget.totalDays,
                      primaryColor: palette.primary,
                      lineColor: palette.line,
                      mutedColor: palette.muted,
                      projectedMinorUnits: widget.projectedMinorUnits,
                      selectedIndex: selected,
                      selectedColor: palette.text,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildAxisLabels(palette),
          ],
          if (sel != null && sel >= 0 && sel < widget.cumulative.length) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: palette.soft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.line),
              ),
              child: Row(
                children: [
                  Icon(
                    FinanceIcons.calendarMonth,
                    size: 14,
                    color: palette.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _detailedSelection(sel),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.available
                      ? 'Total: ${MoneyFormatter.display(widget.shownTotal, widget.currency)}'
                      : 'Total: --',
                  style: TextStyle(fontSize: 11, color: palette.muted),
                ),
              ),
              if (selLabel != null)
                Text(
                  selLabel,
                  key: const Key('dashboard-trend-selected'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                )
              else if (widget.projectedMinorUnits != null &&
                  widget.projectedMinorUnits! > 0)
                Text(
                  'Cierre est.: ${MoneyFormatter.display(widget.projectedMinorUnits!, widget.currency)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: palette.muted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _buildSubtitle() {
    if (!widget.available) return 'cargando...';
    if (widget.useWeeklyRows) {
      return '${widget.bucketCount} ${widget.unit} en ${widget.currency}';
    }
    if (widget.totalDays > widget.daysElapsed && widget.daysElapsed > 0) {
      final pace = MoneyFormatter.display(widget.dailyPace, widget.currency);
      return 'Día ${widget.daysElapsed} de ${widget.totalDays} en ${widget.currency} · Promedio: $pace/día';
    }
    return '${widget.daysElapsed} ${widget.unit} en ${widget.currency}';
  }

  Widget _buildLegend(AppPalette palette) {
    final showProjection =
        widget.projectedMinorUnits != null &&
        widget.projectedMinorUnits! > 0 &&
        widget.daysElapsed < widget.totalDays;
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 3,
              decoration: BoxDecoration(
                color: palette.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Gasto real acumulado',
              style: TextStyle(
                fontSize: 10.5,
                color: palette.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (showProjection)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size(14, 3),
                painter: _DashSamplePainter(
                  color: palette.primary.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Proyección al cierre',
                style: TextStyle(
                  fontSize: 10.5,
                  color: palette.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        if (!showProjection &&
            widget.totalDays > 0 &&
            widget.daysElapsed >= widget.totalDays)
          Row(
            key: const Key('dashboard-trend-closed-period'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FinanceIcons.checkCircleOutline,
                size: 13,
                color: palette.muted,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  'Periodo cerrado · solo gasto real',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: palette.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildAxisLabels(AppPalette palette) {
    if (widget.cumulative.isEmpty) return const SizedBox.shrink();
    final total = widget.totalDays;
    final firstDay = widget.cumulative.first.day;

    if (total >= 300) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Ene', style: TextStyle(fontSize: 10, color: palette.muted)),
          Text('Abr', style: TextStyle(fontSize: 10, color: palette.muted)),
          Text('Jul', style: TextStyle(fontSize: 10, color: palette.muted)),
          Text('Oct', style: TextStyle(fontSize: 10, color: palette.muted)),
          Text('Dic', style: TextStyle(fontSize: 10, color: palette.muted)),
        ],
      );
    } else if (total >= 60) {
      final startMonth = shortMonthName(firstDay.month);
      final endDay = firstDay.add(Duration(days: total - 1));
      final endMonth = shortMonthName(endDay.month);
      final midDay = firstDay.add(Duration(days: total ~/ 2));
      final midMonth = shortMonthName(midDay.month);
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            startMonth,
            style: TextStyle(fontSize: 10, color: palette.muted),
          ),
          Text(midMonth, style: TextStyle(fontSize: 10, color: palette.muted)),
          Text(endMonth, style: TextStyle(fontSize: 10, color: palette.muted)),
        ],
      );
    } else if (total >= 20) {
      final mShort = shortMonthName(firstDay.month);
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '1 $mShort',
            style: TextStyle(fontSize: 10, color: palette.muted),
          ),
          Text('10', style: TextStyle(fontSize: 10, color: palette.muted)),
          Text('20', style: TextStyle(fontSize: 10, color: palette.muted)),
          Text(
            '$total $mShort',
            style: TextStyle(fontSize: 10, color: palette.muted),
          ),
        ],
      );
    } else if (total <= 7) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final d in widget.cumulative)
            Text(
              '${d.day.day}',
              style: TextStyle(fontSize: 10, color: palette.muted),
            ),
        ],
      );
    } else {
      final mShort = shortMonthName(firstDay.month);
      final mid = total ~/ 2;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '1 $mShort',
            style: TextStyle(fontSize: 10, color: palette.muted),
          ),
          Text('$mid', style: TextStyle(fontSize: 10, color: palette.muted)),
          Text(
            '$total $mShort',
            style: TextStyle(fontSize: 10, color: palette.muted),
          ),
        ],
      );
    }
  }

  Widget _buildWeeklyRows(AppPalette palette) {
    final weeks = widget.weeks ?? const <WeeklySpend>[];
    var peak = 0;
    for (final week in weeks) {
      if (week.minorUnits > peak) peak = week.minorUnits;
    }
    return Column(
      key: const Key('dashboard-trend-weekly-rows'),
      children: [
        for (var i = 0; i < weeks.length; i++) ...[
          if (i > 0) Divider(height: 16, color: palette.line),
          Semantics(
            label:
                '${_weekLabel(weeks[i])}: ${MoneyFormatter.display(weeks[i].minorUnits, widget.currency)}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _weekLabel(weeks[i]),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: palette.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      MoneyFormatter.display(
                        weeks[i].minorUnits,
                        widget.currency,
                      ),
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: weeks[i].minorUnits > 0
                            ? palette.text
                            : palette.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: peak > 0 ? weeks[i].minorUnits / peak : 0,
                    minHeight: 7,
                    backgroundColor: palette.soft,
                    color: palette.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _weekLabel(WeeklySpend week) {
    final startMonth = shortMonthName(week.start.month);
    final endMonth = shortMonthName(week.end.month);
    if (week.start.year != week.end.year) {
      return '${week.start.day} $startMonth ${week.start.year} – ${week.end.day} $endMonth ${week.end.year}';
    }
    if (week.start.month == week.end.month) {
      return '${week.start.day}–${week.end.day} $startMonth';
    }
    return '${week.start.day} $startMonth – ${week.end.day} $endMonth';
  }

  String _detailedSelection(int index) {
    if (index < 0 || index >= widget.cumulative.length) return '';
    final pt = widget.cumulative[index];
    final m = fullMonthName(pt.day.month);
    final daily = MoneyFormatter.display(pt.dailyMinorUnits, widget.currency);
    final cum = MoneyFormatter.display(
      pt.cumulativeMinorUnits,
      widget.currency,
    );
    return '${pt.day.day} de $m: +$daily (Acumulado: $cum)';
  }

  String _bucketLabel(int index) {
    if (index < 0 || index >= widget.cumulative.length) return '';
    final pt = widget.cumulative[index];
    final m = shortMonthName(pt.day.month);
    return '${pt.day.day} $m: ${MoneyFormatter.display(pt.cumulativeMinorUnits, widget.currency)}';
  }
}

/// Custom painter for the continuous cumulative spending pace curve.
class CumulativeSpendCurvePainter extends CustomPainter {
  const CumulativeSpendCurvePainter({
    required this.points,
    required this.totalDays,
    required this.primaryColor,
    required this.lineColor,
    required this.mutedColor,
    this.projectedMinorUnits,
    this.selectedIndex,
    this.selectedColor,
  });

  final List<CumulativeSpendDay> points;
  final int totalDays;
  final Color primaryColor;
  final Color lineColor;
  final Color mutedColor;
  final int? projectedMinorUnits;
  final int? selectedIndex;
  final Color? selectedColor;

  @override
  void paint(Canvas canvas, Size size) {
    const topMargin = 16.0;
    const bottomMargin = 10.0;
    final chartHeight = size.height - topMargin - bottomMargin;
    final baselineY = size.height - bottomMargin;

    // Subtle baseline
    final baselinePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(0, baselineY),
      Offset(size.width, baselineY),
      baselinePaint,
    );

    if (points.isEmpty) return;

    final effectiveTotalDays = totalDays > 1 ? totalDays : points.length;

    // Peak cumulative amount calculation
    var maxSpend = 0;
    for (final p in points) {
      if (p.cumulativeMinorUnits > maxSpend) maxSpend = p.cumulativeMinorUnits;
    }
    final rawProjected = projectedMinorUnits;
    final projected = (rawProjected != null && rawProjected >= maxSpend)
        ? rawProjected
        : null;
    var peak = maxSpend;
    if (projected != null && projected > peak) peak = projected;
    if (peak <= 0) peak = 1;

    final firstDay = points.first.day;

    // Map points to canvas coordinates
    final coords = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final offsetDays = p.day.difference(firstDay).inDays;
      final x = effectiveTotalDays > 1
          ? (offsetDays / (effectiveTotalDays - 1)).clamp(0.0, 1.0) * size.width
          : size.width / 2;
      final y =
          baselineY -
          (p.cumulativeMinorUnits / peak * chartHeight).clamp(0.0, chartHeight);
      coords.add(Offset(x, y));
    }

    // Build smooth cubic Bezier curve
    final curvePath = Path();
    curvePath.moveTo(coords.first.dx, coords.first.dy);
    if (coords.length == 1) {
      curvePath.lineTo(coords.first.dx, coords.first.dy);
    } else {
      for (var i = 1; i < coords.length; i++) {
        final prev = coords[i - 1];
        final curr = coords[i];
        final midX = (prev.dx + curr.dx) / 2;
        curvePath.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
      }
    }

    // Gradient fill under the curve
    final fillPath = Path.from(curvePath);
    fillPath.lineTo(coords.last.dx, baselineY);
    fillPath.lineTo(coords.first.dx, baselineY);
    fillPath.close();

    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        primaryColor.withValues(alpha: 0.22),
        primaryColor.withValues(alpha: 0.01),
      ],
    );
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = fillGradient.createShader(
          Rect.fromLTWH(0, topMargin, size.width, chartHeight),
        )
        ..style = PaintingStyle.fill,
    );

    // Stroke the solid curve
    final linePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(curvePath, linePaint);

    // Projected dotted line towards month close if period has remaining days
    if (projected != null &&
        projected > 0 &&
        points.length < effectiveTotalDays) {
      final lastPoint = coords.last;
      final projectedY =
          baselineY - (projected / peak * chartHeight).clamp(0.0, chartHeight);
      final endPoint = Offset(size.width, projectedY);

      final dashPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.45)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      _drawDashedLine(canvas, lastPoint, endPoint, dashPaint);

      // Hollow dot at estimated end
      canvas.drawCircle(
        endPoint,
        3.5,
        Paint()
          ..color = primaryColor.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // "Hoy" active dot at the tip of real data
    final lastCoord = coords.last;
    canvas.drawCircle(
      lastCoord,
      7.0,
      Paint()..color = primaryColor.withValues(alpha: 0.22),
    );
    canvas.drawCircle(lastCoord, 4.0, Paint()..color = primaryColor);
    canvas.drawCircle(lastCoord, 1.8, Paint()..color = Colors.white);

    // Selected day guide & highlight
    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < coords.length) {
      final selCoord = coords[selectedIndex!];
      final guidePaint = Paint()
        ..color = (selectedColor ?? primaryColor).withValues(alpha: 0.35)
        ..strokeWidth = 1.2;
      canvas.drawLine(
        Offset(selCoord.dx, topMargin),
        Offset(selCoord.dx, baselineY),
        guidePaint,
      );
      canvas.drawCircle(
        selCoord,
        6.0,
        Paint()..color = (selectedColor ?? primaryColor),
      );
      canvas.drawCircle(selCoord, 3.0, Paint()..color = Colors.white);
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    double dashWidth = 4.0,
    double dashSpace = 4.0,
  }) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance <= 0) return;
    final ux = dx / distance;
    final uy = dy / distance;

    var currentDist = 0.0;
    while (currentDist < distance) {
      final segStart = Offset(
        start.dx + ux * currentDist,
        start.dy + uy * currentDist,
      );
      final nextDist = math.min(currentDist + dashWidth, distance);
      final segEnd = Offset(start.dx + ux * nextDist, start.dy + uy * nextDist);
      canvas.drawLine(segStart, segEnd, paint);
      currentDist += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CumulativeSpendCurvePainter old) =>
      old.points != points ||
      old.totalDays != totalDays ||
      old.projectedMinorUnits != projectedMinorUnits ||
      old.selectedIndex != selectedIndex ||
      old.primaryColor != primaryColor;
}

class _DashSamplePainter extends CustomPainter {
  const _DashSamplePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(4, size.height / 2),
      paint,
    );
    canvas.drawLine(
      Offset(8, size.height / 2),
      Offset(12, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DashSamplePainter old) => old.color != color;
}
