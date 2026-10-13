import 'package:flutter/foundation.dart';

import '../../budgets/domain/budget_models.dart';
import '../domain/dashboard_summary.dart';

@immutable
class DashboardInsight {
  const DashboardInsight({
    required this.title,
    required this.message,
    required this.type,
  });

  final String title;
  final String message;
  final InsightType type;
}

enum InsightType { positive, warning, info }

class DashboardMetrics {
  const DashboardMetrics._();

  /// Sorts budgets by severity: exceeded first, then highest percentage used.
  static List<Budget> sortBudgetsBySeverity(List<Budget> budgets) {
    final list = List<Budget>.from(budgets);
    list.sort((a, b) {
      final aRatio = a.amount.minorUnits > 0
          ? a.spentAmount.minorUnits / a.amount.minorUnits
          : 0.0;
      final bRatio = b.amount.minorUnits > 0
          ? b.spentAmount.minorUnits / b.amount.minorUnits
          : 0.0;

      final aExceeded = aRatio >= 1.0;
      final bExceeded = bRatio >= 1.0;

      if (aExceeded && !bExceeded) return -1;
      if (!aExceeded && bExceeded) return 1;

      return bRatio.compareTo(aRatio);
    });
    return list;
  }

  /// Generates proactive insights tailored for an independent contractor.
  static List<DashboardInsight> buildInsights({
    required DashboardSummary summary,
    String currencyCode = 'COP',
  }) {
    final insights = <DashboardInsight>[];

    // Weekday vs Weekend spending pattern
    final weekendUnits = summary.weekdayPattern.weekendAvg.minorUnits;
    final weekdayUnits = summary.weekdayPattern.weekdayAvg.minorUnits;
    if (weekdayUnits > 0 && weekendUnits > (weekdayUnits * 1.3).round()) {
      final pct = (((weekendUnits - weekdayUnits) / weekdayUnits) * 100)
          .round();
      insights.add(
        DashboardInsight(
          title: 'Patrón de fin de semana',
          message:
              'Gastas un $pct% más en días de fin de semana que entre semana.',
          type: InsightType.info,
        ),
      );
    }

    // Contractor income variability
    final variability = summary.incomeAverage.variability;
    if (variability != null && variability >= 0.35) {
      final cv = (variability * 100).round();
      insights.add(
        DashboardInsight(
          title: 'Ingresos variables ($cv%)',
          message: 'Como contratista, tus ingresos fluctúan entre meses. Presupuesta tus gastos fijos con base en el promedio de 6 meses.',
          type: InsightType.info,
        ),
      );
    }

    return insights;
  }
}
