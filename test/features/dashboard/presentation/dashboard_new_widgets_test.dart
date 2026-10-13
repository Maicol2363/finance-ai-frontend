import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/dashboard/application/dashboard_metrics.dart';
import 'package:finance_ai/features/dashboard/domain/dashboard_summary.dart';
import 'package:finance_ai/features/dashboard/presentation/widgets/daily_allowance_card.dart';
import 'package:finance_ai/features/dashboard/presentation/widgets/insights_card.dart';
import 'package:finance_ai/features/dashboard/presentation/widgets/top_categories_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('New Dashboard Widgets', () {
    testWidgets(
      'DailyAllowanceCard renders daily budget and projection stats',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const DailyAllowanceCard(
              dailyAllowanceMinorUnits: 5000000,
              spentMtdMinorUnits: 250000000,
              projectedMinorUnits: 375000000,
              remainingDays: 10,
              currency: 'COP',
            ),
          ),
        );

        expect(find.text('Ritmo de gasto diario'), findsOneWidget);
        expect(find.text('Puedes gastar hasta'), findsOneWidget);
        expect(find.text(r'$ 50.000 COP'), findsOneWidget);
        expect(find.text('10 días restantes'), findsOneWidget);
        expect(find.text(r'$ 2.500.000 COP'), findsOneWidget);
        expect(find.text(r'$ 3.750.000 COP'), findsOneWidget);
      },
    );

    testWidgets(
      'TopCategoriesCard renders sorted categories with share percentage',
      (tester) async {
        final categories = [
          TopCategoryItem(
            categoryId: 1,
            name: 'Alimentación',
            total: MoneyAmount.parseApi('1200000.00'),
            sharePct: 60.0,
          ),
          TopCategoryItem(
            categoryId: 2,
            name: 'Transporte',
            total: MoneyAmount.parseApi('800000.00'),
            sharePct: 40.0,
          ),
        ];

        await tester.pumpWidget(
          _wrap(
            TopCategoriesCard(
              categories: categories,
              currency: 'COP',
              periodName: 'septiembre',
              onSelectCategory: (_) {},
            ),
          ),
        );

        expect(find.text('Gastos por categoría'), findsOneWidget);
        expect(find.text('Alimentación'), findsOneWidget);
        expect(find.text('Transporte'), findsOneWidget);
        expect(find.text('60.0%'), findsOneWidget);
        expect(find.text('40.0%'), findsOneWidget);
        expect(find.text(r'$ 1.200.000 COP'), findsOneWidget);
        expect(find.text(r'$ 800.000 COP'), findsOneWidget);
      },
    );

    testWidgets('InsightsCard renders insights with semantic styling', (
      tester,
    ) async {
      const insights = [
        DashboardInsight(
          title: 'Colchón financiero sólido',
          message: 'Cuentas con 6.2 meses de reserva para imprevistos.',
          type: InsightType.positive,
        ),
        DashboardInsight(
          title: 'Patrón de fin de semana',
          message: 'Gastas un 45% más los fines de semana.',
          type: InsightType.info,
        ),
      ];

      await tester.pumpWidget(_wrap(const InsightsCard(insights: insights)));

      expect(find.text('Patrones y estimaciones'), findsOneWidget);
      expect(find.text('Colchón financiero sólido'), findsOneWidget);
      expect(
        find.text('Cuentas con 6.2 meses de reserva para imprevistos.'),
        findsOneWidget,
      );
      expect(find.text('Patrón de fin de semana'), findsOneWidget);
    });
  });
}
