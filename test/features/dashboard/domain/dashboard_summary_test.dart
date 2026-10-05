import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/budgets/domain/budget_models.dart';
import 'package:finance_ai/features/dashboard/application/dashboard_metrics.dart';
import 'package:finance_ai/features/dashboard/domain/dashboard_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DashboardSummary and Metrics', () {
    final sampleJson = <String, dynamic>{
      'period': {
        'start': '2026-09-01T00:00:00Z',
        'end': '2026-09-30T23:59:59Z',
        'today': '2026-09-20T12:00:00Z',
        'is_current': true,
        'days_elapsed': 20,
        'days_total': 30,
      },
      'flow': {
        'incomes': '5000000.00',
        'expenses': '2500000.00',
        'net': '2500000.00',
      },
      'comparison': {
        'current': '2500000.00',
        'previous': '2000000.00',
        'previous_start': '2026-08-01T00:00:00Z',
        'previous_end': '2026-08-31T23:59:59Z',
        'pct': 25.0,
        'direction': 'up',
      },
      'weekly': [
        {
          'start': '2026-09-01T00:00:00Z',
          'end': '2026-09-07T23:59:59Z',
          'expenses': '800000.00',
          'is_future': false,
        },
        {
          'start': '2026-09-08T00:00:00Z',
          'end': '2026-09-14T23:59:59Z',
          'expenses': '900000.00',
          'is_future': false,
        },
      ],
      'top_categories': [
        {
          'category_id': 1,
          'name': 'Alimentación',
          'total': '1200000.00',
          'share_pct': 48.0,
        },
        {
          'category_id': 2,
          'name': 'Transporte',
          'total': '600000.00',
          'share_pct': 24.0,
        },
      ],
      'projection': {'spent_mtd': '2500000.00', 'projected': '3750000.00'},
      'balance': {
        'total': '15000000.00',
        'avg_monthly_spend': '3000000.00',
        'runway_months': 5.0,
      },
      'income_average': {
        'avg_3m': '5200000.00',
        'avg_6m': '4800000.00',
        'variability': 0.42,
      },
      'weekday_pattern': {
        'weekend_avg': '180000.00',
        'weekday_avg': '90000.00',
      },
      'recurring_candidates': [
        {
          'merchant': 'Spotify',
          'typical_amount': '19900.00',
          'next_expected': '2026-09-25T00:00:00Z',
        },
      ],
      'recent': [
        {
          'id': 101,
          'type': 'expense',
          'occurred_at': '2026-09-20T10:30:00Z',
          'title': 'Supermercado Éxito',
          'amount': '150000.00',
        },
        {
          'id': 201,
          'type': 'income',
          'occurred_at': '2026-09-18T09:00:00Z',
          'title': 'Pago Honorarios Consultoría',
          'amount': '2500000.00',
        },
      ],
    };

    test('DashboardSummary.fromJson parses all sections correctly', () {
      final summary = DashboardSummary.fromJson(sampleJson);

      expect(summary.period.isCurrent, isTrue);
      expect(summary.period.daysElapsed, 20);
      expect(summary.period.daysTotal, 30);

      expect(summary.flow.incomes.minorUnits, 500000000);
      expect(summary.flow.expenses.minorUnits, 250000000);
      expect(summary.flow.net.minorUnits, 250000000);

      expect(summary.comparison.pct, 25.0);
      expect(summary.comparison.direction, 'up');

      expect(summary.weekly.length, 2);
      expect(summary.weekly[0].expenses.minorUnits, 80000000);

      expect(summary.topCategories.length, 2);
      expect(summary.topCategories[0].name, 'Alimentación');
      expect(summary.topCategories[0].sharePct, 48.0);

      expect(summary.projection.projected.minorUnits, 375000000);
      expect(summary.balance.runwayMonths, 5.0);
      expect(summary.incomeAverage.variability, 0.42);
      expect(summary.weekdayPattern.weekendAvg.minorUnits, 18000000);
      expect(summary.recurringCandidates.first.merchant, 'Spotify');
      expect(summary.recent.length, 2);
      expect(summary.recent.first.title, 'Supermercado Éxito');
    });

    test('DashboardMetrics.calculateDailyAllowance calculates correctly', () {
      final summary = DashboardSummary.fromJson(sampleJson);
      // 10 remaining days. avg spend = 3.000.000 (300.000.000 minor units).
      // spent MTD = 2.500.000 (250.000.000 minor units).
      // remaining = 50.000.000 minor units / 10 days = 5.000.000 minor units ($ 50.000).
      final allowance = DashboardMetrics.calculateDailyAllowance(
        summary: summary,
      );
      expect(allowance, 5000000);
    });

    test('DashboardMetrics.sortBudgetsBySeverity orders exceeded first, then highest %', () {
      const currency = CurrencySummary(
        id: 1,
        code: 'COP',
        name: 'COP',
        decimals: 2,
      );
      Budget createBudget({
        required int id,
        required String spent,
        required String total,
      }) {
        return Budget(
          id: id,
          name: 'Budget $id',
          category: null,
          currency: currency,
          amount: MoneyAmount.parseApi(total),
          scheduleType: 'recurring',
          frequencyUnit: 'month',
          frequencyInterval: 1,
          startsOn: DateTime.utc(2026, 9, 1),
          endsOn: DateTime.utc(2026, 9, 30),
          currentPeriodStart: DateTime.utc(2026, 9, 1),
          currentPeriodEnd: DateTime.utc(2026, 9, 30),
          spentAmount: MoneyAmount.parseApi(spent),
          remainingAmount: MoneyAmount.parseApi('0.00'),
          progressPercent: 0,
          isActive: true,
          createdAt: DateTime.utc(2026, 9, 1),
          updatedAt: DateTime.utc(2026, 9, 1),
        );
      }

      final b1 = createBudget(id: 1, spent: '40.00', total: '100.00');
      final b2 = createBudget(id: 2, spent: '120.00', total: '100.00');
      final b3 = createBudget(id: 3, spent: '85.00', total: '100.00');

      final sorted = DashboardMetrics.sortBudgetsBySeverity([b1, b2, b3]);
      expect(sorted.map((b) => b.id).toList(), [2, 3, 1]);
    });

    test(
      'DashboardMetrics.buildInsights generates contractor-focused insights',
      () {
        final summary = DashboardSummary.fromJson(sampleJson);
        final insights = DashboardMetrics.buildInsights(summary: summary);

        // Weekend pattern (180k vs 90k is 2x > 1.3x)
        expect(
          insights.any((i) => i.title.contains('Patrón de fin de semana')),
          isTrue,
        );
        // Variability (0.42 >= 0.35)
        expect(
          insights.any((i) => i.title.contains('Ingresos variables')),
          isTrue,
        );
        // Recurring candidate (Spotify)
        expect(
          insights.any((i) => i.title.contains('Próximo recurrente')),
          isTrue,
        );
      },
    );
  });
}
