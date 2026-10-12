import 'package:finance_ai/core/theme/app_theme.dart';
import 'package:finance_ai/features/dashboard/presentation/spending_trend.dart';
import 'package:finance_ai/features/dashboard/presentation/spending_trend_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/accessibility_test_helpers.dart';

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
    final chartCenter = t.getCenter(
      find.byKey(const Key('dashboard-trend-chart')),
    );
    await t.tapAt(chartCenter);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('dashboard-trend-selected')), findsOneWidget);
  });

  testWidgets(
    'accessible table toggle button expands and collapses daily bucket table',
    (t) async {
      await _pump(
        t,
        SpendingTrendCard(
          days: _days([10000, 25000]),
          currency: 'COP',
          available: true,
        ),
      );

      final toggleFinder = find.byKey(
        const Key('dashboard-trend-toggle-table'),
      );
      expect(toggleFinder, findsOneWidget);
      expect(find.text('Ver tabla de valores'), findsOneWidget);
      expect(find.byKey(const Key('dashboard-trend-table')), findsNothing);

      // Tap to expand table
      await t.tap(toggleFinder);
      await t.pumpAndSettle();

      expect(find.text('Ocultar tabla de valores'), findsOneWidget);
      expect(find.byKey(const Key('dashboard-trend-table')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dashboard-trend-row-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dashboard-trend-row-1')),
        findsOneWidget,
      );
      expect(find.text('Día 16 de septiembre'), findsOneWidget);
      expect(find.text('Día 17 de septiembre'), findsOneWidget);

      // Tap again to collapse table
      await t.tap(toggleFinder);
      await t.pumpAndSettle();

      expect(find.text('Ver tabla de valores'), findsOneWidget);
      expect(find.byKey(const Key('dashboard-trend-table')), findsNothing);
    },
  );

  testWidgets(
    'initialShowTable exposes all daily buckets with complete period and amount semantics',
    (t) async {
      await _pump(
        t,
        SpendingTrendCard(
          days: _days([15000, 45000]),
          currency: 'COP',
          available: true,
          initialShowTable: true,
        ),
      );

      expect(find.byKey(const Key('dashboard-trend-table')), findsOneWidget);
      expect(find.text('Día 16 de septiembre'), findsOneWidget);
      expect(find.text('Día 17 de septiembre'), findsOneWidget);

      final row0 = t.getSemantics(
        find.byKey(const ValueKey('dashboard-trend-row-0')),
      );
      expect(row0.label, contains('Día 16 de septiembre'));

      final row1 = t.getSemantics(
        find.byKey(const ValueKey('dashboard-trend-row-1')),
      );
      expect(row1.label, contains('Día 17 de septiembre'));
    },
  );

  testWidgets(
    'initialShowTable exposes weekly buckets with full week range labels',
    (t) async {
      await _pump(
        t,
        SpendingTrendCard(
          days: _days([100, 100]),
          currency: 'COP',
          available: true,
          initialShowTable: true,
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

      expect(find.byKey(const Key('dashboard-trend-table')), findsOneWidget);
      expect(find.text('Semana del 1 al 7 de septiembre'), findsOneWidget);
      expect(find.text('Semana del 8 al 14 de septiembre'), findsOneWidget);
    },
  );

  testWidgets('tapping a table row selects the bucket and updates selection', (
    t,
  ) async {
    await _pump(
      t,
      SpendingTrendCard(
        days: _days([10000, 20000]),
        currency: 'COP',
        available: true,
        initialShowTable: true,
      ),
    );

    await t.tap(find.byKey(const ValueKey('dashboard-trend-row-1')));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-trend-selected')), findsOneWidget);
    expect(
      find.textContaining('Día 17 de septiembre'),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('loading and empty states do not render the table or toggle', (
    t,
  ) async {
    // Loading state
    await _pump(
      t,
      SpendingTrendCard(
        days: _days([100]),
        currency: 'COP',
        available: false,
        initialShowTable: true,
      ),
    );
    expect(find.byKey(const Key('dashboard-trend-toggle-table')), findsNothing);
    expect(find.byKey(const Key('dashboard-trend-table')), findsNothing);

    // Empty list
    await _pump(
      t,
      SpendingTrendCard(
        days: const [],
        currency: 'COP',
        available: true,
        initialShowTable: true,
      ),
    );
    expect(find.byKey(const Key('dashboard-trend-toggle-table')), findsNothing);
    expect(find.byKey(const Key('dashboard-trend-table')), findsNothing);
  });

  testWidgets(
    'toggle button satisfies touch target and accessible name guidelines',
    (t) async {
      await _pump(
        t,
        SpendingTrendCard(
          days: _days([10000, 20000]),
          currency: 'COP',
          available: true,
        ),
      );

      final toggle = find.byKey(const Key('dashboard-trend-toggle-table'));
      expectMinTouchTarget(t, toggle);
      expectAccessibleName(
        t,
        toggle,
        expectedName: 'Ver tabla de valores de tendencia',
      );
    },
  );
}
