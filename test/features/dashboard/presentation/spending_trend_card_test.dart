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
}
