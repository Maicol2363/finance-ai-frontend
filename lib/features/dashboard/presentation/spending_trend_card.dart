import 'package:flutter/material.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/theme/app_palette.dart';
import 'spending_trend.dart';

// Tendency card: weekly/daily bars with average line, tap-to-see values and a
// badge comparing against the previous equivalent window.
class SpendingTrendCard extends StatelessWidget {
  const SpendingTrendCard({
    required this.days,
    required this.currency,
    required this.available,
    this.weekly,
    this.comparisonLabel,
    this.comparisonDirection,
    this.averageMinorUnits,
    this.initialShowTable = false,
    super.key,
  });
  final List<DailySpend> days;
  final String currency;
  final bool available;
  final bool initialShowTable;

  /// Weekly buckets for long windows. When non-null, the card renders weeks
  /// instead of days (same painter input shape: start + amount).
  final List<WeeklySpend>? weekly;

  /// Honest badge text, e.g. `+48% vs ago`. Null falls back to the legacy
  /// in-window label.
  final String? comparisonLabel;

  /// Direction ('up', 'down', 'flat', 'empty') for the badge arrow and color.
  final String? comparisonDirection;

  /// Mean per bucket, drawn as a dashed line. Null hides the line.
  final int? averageMinorUnits;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tendency = spendingTendency(days);
    final total = days.fold<int>(0, (s, d) => s + d.minorUnits);
    final weekDays = weekly;
    final useWeeks = weekDays != null && weekDays.isNotEmpty;
    final weekTotal = useWeeks
        ? weekDays.fold<int>(0, (s, w) => s + w.minorUnits)
        : 0;
    final shownTotal = useWeeks ? weekTotal : total;
    final bucketCount = useWeeks ? weekDays.length : days.length;
    final unit = bucketCount == 1
        ? 'semana'
        : useWeeks
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
      'up' => Icons.trending_up,
      'down' => Icons.trending_down,
      'empty' => Icons.remove,
      _ => Icons.trending_flat,
    };
    final color = switch (resolvedDirection) {
      'up' => palette.discard,
      'down' => palette.income,
      _ => palette.muted,
    };
    // Painter input: weeks collapse to (start, amount) so one painter serves
    // both granularities without a new package.
    final painted = useWeeks
        ? [
            for (final w in weekDays)
              DailySpend(day: w.start, minorUnits: w.minorUnits),
          ]
        : days;
    final axis = useWeeks
        ? [for (final w in weekDays) w.start]
        : axisDays(days);
    return _TrendBody(
      painted: painted,
      bucketCount: bucketCount,
      unit: unit,
      shownTotal: shownTotal,
      headline: headline,
      icon: icon,
      color: color,
      currency: currency,
      available: available,
      averageMinorUnits: averageMinorUnits,
      useWeeks: useWeeks,
      weeks: weekDays,
      axis: axis,
      initialShowTable: initialShowTable,
    );
  }
}

class _TrendBody extends StatefulWidget {
  const _TrendBody({
    required this.painted,
    required this.bucketCount,
    required this.unit,
    required this.shownTotal,
    required this.headline,
    required this.icon,
    required this.color,
    required this.currency,
    required this.available,
    required this.averageMinorUnits,
    required this.useWeeks,
    required this.weeks,
    required this.axis,
    this.initialShowTable = false,
  });

  final List<DailySpend> painted;
  final int bucketCount;
  final String unit;
  final int shownTotal;
  final String headline;
  final IconData icon;
  final Color color;
  final String currency;
  final bool available;
  final int? averageMinorUnits;
  final bool useWeeks;
  final List<WeeklySpend>? weeks;
  final List<DateTime> axis;
  final bool initialShowTable;

  @override
  State<_TrendBody> createState() => _TrendBodyState();
}

class _TrendBodyState extends State<_TrendBody> {
  int? selected;
  late bool _showTable = widget.initialShowTable;

  @override
  void didUpdateWidget(covariant _TrendBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialShowTable != widget.initialShowTable) {
      _showTable = widget.initialShowTable;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final painted = widget.available ? widget.painted : const <DailySpend>[];
    final sel = selected;
    final selLabel = sel == null || sel < 0 || sel >= painted.length
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
              const Expanded(
                child: Text(
                  'Tendencia de gasto',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
            widget.available
                ? '${widget.bucketCount} ${widget.unit} en ${widget.currency}'
                : 'cargando...',
            style: TextStyle(fontSize: 11, color: palette.muted),
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Tendencia de gasto: ${widget.headline}',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: widget.available
                  ? (details) {
                      final box = context.findRenderObject() as RenderBox?;
                      if (box == null || painted.isEmpty) return;
                      // Chart area: full width minus the 16px card padding.
                      final chartWidth = box.size.width - 32;
                      if (chartWidth <= 0) return;
                      final slot = chartWidth / painted.length;
                      final dx =
                          box.globalToLocal(details.globalPosition).dx - 16;
                      final index = (dx / slot).floor().clamp(
                        0,
                        painted.length - 1,
                      );
                      setState(() => selected = index);
                    }
                  : null,
              child: SizedBox(
                key: const Key('dashboard-trend-chart'),
                width: double.infinity,
                height: 92,
                child: CustomPaint(
                  painter: TrendBarsPainter(
                    days: painted,
                    placeholderCount: painted.length,
                    barColor: palette.primary,
                    emptyColor: palette.soft,
                    lineColor: palette.line,
                    averageMinorUnits: widget.averageMinorUnits,
                    selectedIndex: selected,
                    selectedColor: palette.text,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ExcludeSemantics(
            child:
                widget.useWeeks &&
                    widget.weeks != null &&
                    widget.weeks!.isNotEmpty
                ? _buildWeeksAxis(palette)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final d in widget.axis)
                        Text(
                          widget.axis.length <= 7
                              ? '${d.day} ${shortMonthName(d.month)}'
                              : '${d.day}',
                          style: TextStyle(fontSize: 10, color: palette.muted),
                        ),
                    ],
                  ),
          ),
          if (sel != null && sel >= 0 && sel < painted.length) ...[
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
                  Icon(Icons.calendar_month, size: 14, color: palette.primary),
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
          if (widget.averageMinorUnits != null &&
              widget.averageMinorUnits! > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 16,
                  height: 1.5,
                  decoration: BoxDecoration(
                    color: palette.muted,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Línea punteada: Promedio (${MoneyFormatter.display(widget.averageMinorUnits!, widget.currency)})',
                  style: TextStyle(fontSize: 10, color: palette.muted),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
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
                ),
            ],
          ),
          if (widget.available && painted.isNotEmpty) ...[
            const SizedBox(height: 10),
            Semantics(
              button: true,
              excludeSemantics: true,
              label: _showTable
                  ? 'Ocultar tabla de valores de tendencia'
                  : 'Ver tabla de valores de tendencia',
              child: InkWell(
                key: const Key('dashboard-trend-toggle-table'),
                onTap: () => setState(() => _showTable = !_showTable),
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 48,
                    minWidth: 48,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showTable
                              ? Icons.keyboard_arrow_up
                              : Icons.table_chart_outlined,
                          size: 16,
                          color: palette.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _showTable
                              ? 'Ocultar tabla de valores'
                              : 'Ver tabla de valores',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: palette.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_showTable) ...[
              const SizedBox(height: 8),
              Semantics(
                container: true,
                label: 'Tabla de valores de tendencia',
                child: Container(
                  key: const Key('dashboard-trend-table'),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: palette.soft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < painted.length; i++)
                        Semantics(
                          label:
                              '${_periodName(i)}: ${MoneyFormatter.display(painted[i].minorUnits, widget.currency)}',
                          child: InkWell(
                            key: ValueKey('dashboard-trend-row-$i'),
                            onTap: () => setState(() => selected = i),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              margin: const EdgeInsets.only(bottom: 2),
                              decoration: BoxDecoration(
                                color: selected == i
                                    ? palette.card
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _periodName(i),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: selected == i
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: selected == i
                                            ? palette.text
                                            : palette.muted,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    MoneyFormatter.display(
                                      painted[i].minorUnits,
                                      widget.currency,
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: palette.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildWeeksAxis(AppPalette palette) {
    final weeks = widget.weeks!;
    final spans = _monthSpans(weeks);
    final isMultiMonth = spans.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isMultiMonth) ...[
          Row(
            children: [
              for (final span in spans)
                Expanded(
                  flex: span.count,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: palette.soft,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      span.name.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: palette.text,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final w in weeks)
                Expanded(
                  child: Text(
                    '${w.start.day}-${w.end.day}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: palette.muted),
                  ),
                ),
            ],
          ),
        ] else ...[
          Row(
            children: [
              for (final w in weeks)
                Expanded(
                  child: Text(
                    weeks.length <= 5
                        ? '${w.start.day}\u2013${w.end.day} ${shortMonthName(w.start.month)}'
                        : '${w.start.day}-${w.end.day}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: weeks.length <= 5 ? 10.5 : 9.5,
                      fontWeight: FontWeight.w500,
                      color: palette.muted,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  List<({String name, int count, int month})> _monthSpans(
    List<WeeklySpend> weeks,
  ) {
    if (weeks.isEmpty) return const [];
    final spans = <({String name, int count, int month})>[];
    String currentName = '';
    int currentCount = 0;
    int currentMonth = 0;
    for (final w in weeks) {
      final m = w.start.month;
      final name = shortMonthName(m);
      if (name == currentName) {
        currentCount++;
      } else {
        if (currentCount > 0) {
          spans.add((
            name: currentName,
            count: currentCount,
            month: currentMonth,
          ));
        }
        currentName = name;
        currentCount = 1;
        currentMonth = m;
      }
    }
    if (currentCount > 0) {
      spans.add((name: currentName, count: currentCount, month: currentMonth));
    }
    return spans;
  }

  String _periodName(int index) {
    if (index < 0 || index >= widget.painted.length) return '';
    final bucket = widget.painted[index];
    if (widget.useWeeks &&
        widget.weeks != null &&
        index < widget.weeks!.length) {
      final week = widget.weeks![index];
      final mStart = fullMonthName(week.start.month);
      final mEnd = fullMonthName(week.end.month);
      if (week.start.month == week.end.month) {
        return 'Semana del ${week.start.day} al ${week.end.day} de $mStart';
      } else {
        return 'Semana del ${week.start.day} de $mStart al ${week.end.day} de $mEnd';
      }
    }
    final m = fullMonthName(bucket.day.month);
    return 'Día ${bucket.day.day} de $m';
  }

  String _detailedSelection(int index) {
    if (index < 0 || index >= widget.painted.length) return '';
    final bucket = widget.painted[index];
    final amount = MoneyFormatter.display(bucket.minorUnits, widget.currency);
    return '${_periodName(index)}: $amount';
  }

  String _bucketLabel(int index) {
    final bucket = widget.painted[index];
    final amount = MoneyFormatter.display(bucket.minorUnits, widget.currency);
    if (widget.useWeeks &&
        widget.weeks != null &&
        index < widget.weeks!.length) {
      final week = widget.weeks![index];
      final mStart = shortMonthName(week.start.month);
      final mEnd = shortMonthName(week.end.month);
      if (week.start.month == week.end.month) {
        return 'Sem ${week.start.day}\u2013${week.end.day} $mStart: $amount';
      } else {
        return 'Sem ${week.start.day} $mStart\u2013${week.end.day} $mEnd: $amount';
      }
    }
    final m = shortMonthName(bucket.day.month);
    return '${bucket.day.day} $m: $amount';
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
    this.averageMinorUnits,
    this.selectedIndex,
    this.selectedColor,
  });
  final List<DailySpend> days;
  final int placeholderCount;
  final Color barColor;
  final Color emptyColor;
  final Color lineColor;
  final int? averageMinorUnits;
  final int? selectedIndex;
  final Color? selectedColor;
  @override
  void paint(Canvas canvas, Size size) {
    final count = placeholderCount <= 0 ? 1 : placeholderCount;
    final slot = size.width / count;
    final barWidth = (slot * 0.52).clamp(6.0, 22.0);
    var peak = 1;
    for (final d in days) {
      if (d.minorUnits > peak) peak = d.minorUnits;
    }
    final avg = averageMinorUnits;
    if (avg != null && avg > 0) peak = avg > peak ? avg : peak;
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()..color = lineColor,
    );
    // Average: dashed horizontal line.
    if (avg != null && avg > 0) {
      final y =
          size.height -
          (avg / peak * (size.height - 10)).clamp(4.0, size.height - 4);
      final dash = Paint()
        ..color = lineColor
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, y), Offset(x + 5, y), dash);
        x += 9;
      }
    }
    for (var i = 0; i < count; i++) {
      final v = i < days.length ? days[i].minorUnits : 0;
      final h = v <= 0
          ? 4.0
          : (v / peak * (size.height - 10)).clamp(4.0, size.height - 4);
      final left = i * slot + (slot - barWidth) / 2;
      final isSel = selectedIndex == i;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - h, barWidth, h),
          const Radius.circular(4),
        ),
        Paint()
          ..color = isSel
              ? (selectedColor ?? barColor)
              : v <= 0
              ? emptyColor
              : barColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TrendBarsPainter o) =>
      o.days != days ||
      o.placeholderCount != placeholderCount ||
      o.averageMinorUnits != averageMinorUnits ||
      o.selectedIndex != selectedIndex;
}
