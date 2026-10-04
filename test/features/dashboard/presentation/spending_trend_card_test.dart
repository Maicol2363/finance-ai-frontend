import 'package:finance_ai/core/theme/app_theme.dart';
import 'package:finance_ai/features/dashboard/presentation/spending_trend.dart';
import 'package:finance_ai/features/dashboard/presentation/spending_trend_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<DailySpend> _days(List<int> vs) => [
  for (var i = 0; i < vs.length; i++)
    DailySpend(day: DateTime(2026, 9, 16 + i), minorUnits: vs[i]),
];
Future<void> _pump(WidgetTester t, SpendingTrendCard c) async {
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: c),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('up trend shows Subiendo badge', (t) async {
    await _pump(
      t,
      SpendingTrendCard(
        days: _days([100, 100, 300, 300]),
        currency: 'COP',
        available: true,
      ),
    );
    expect(find.text('Tendencia de gasto'), findsOneWidget);
    expect(find.textContaining('Subiendo'), findsOneWidget);
    expect(find.byKey(const Key('dashboard-trend-badge')), findsOneWidget);
  });
  testWidgets('empty trend shows Sin gasto reciente', (t) async {
    await _pump(
      t,
      SpendingTrendCard(
        days: _days([0, 0, 0]),
        currency: 'COP',
        available: true,
      ),
    );
    expect(find.textContaining('Sin gasto'), findsOneWidget);
  });
  testWidgets('loading shows placeholder total', (t) async {
    await _pump(
      t,
      SpendingTrendCard(
        days: _days([100, 200]),
        currency: 'COP',
        available: false,
      ),
    );
    expect(find.text('Total: --'), findsOneWidget);
    expect(find.text('cargando...'), findsOneWidget);
  });

  testWidgets('honest badge overrides the in-window label', (t) async {
    await _pump(
      t,
      SpendingTrendCard(
        days: _days([100, 100, 100, 100]),
        currency: 'COP',
        available: true,
        comparisonLabel: '+48% vs ago',
      ),
    );
    expect(find.text('+48% vs ago'), findsOneWidget);
    expect(find.textContaining('Subiendo'), findsNothing);
  });

  testWidgets('weekly buckets render weeks and tap shows the value', (t) async {
    await _pump(
      t,
      SpendingTrendCard(
        days: _days([100, 100]),
        currency: 'COP',
        available: true,
        weekly: [
          WeeklySpend(
            start: DateTime(2026, 9, 1),
            end: DateTime(2026, 9, 7),
            minorUnits: 15200000,
          ),
          WeeklySpend(
            start: DateTime(2026, 9, 8),
            end: DateTime(2026, 9, 14),
            minorUnits: 4800000,
          ),
        ],
      ),
    );
    expect(find.text('2 semanas en COP'), findsOneWidget);
    // Tap inside the chart area: the selected bucket value appears.
    final chartCenter = t.getCenter(find.byKey(const Key('dashboard-trend-chart')));
    await t.tapAt(chartCenter);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('dashboard-trend-selected')), findsOneWidget);
  });
}
