import 'package:flutter/foundation.dart';

import '../../accounts/domain/account_models.dart';

@immutable
class PeriodSummary {
  const PeriodSummary({
    required this.start,
    required this.end,
    required this.today,
    required this.isCurrent,
    required this.daysElapsed,
    required this.daysTotal,
  });

  factory PeriodSummary.fromJson(Map<String, dynamic> json) {
    return PeriodSummary(
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      today: DateTime.parse(json['today'] as String),
      isCurrent: json['is_current'] as bool? ?? false,
      daysElapsed: json['days_elapsed'] as int? ?? 0,
      daysTotal: json['days_total'] as int? ?? 0,
    );
  }

  final DateTime start;
  final DateTime end;
  final DateTime today;
  final bool isCurrent;
  final int daysElapsed;
  final int daysTotal;
}

@immutable
class FlowSummary {
  const FlowSummary({
    required this.incomes,
    required this.expenses,
    required this.net,
  });

  factory FlowSummary.fromJson(Map<String, dynamic> json) {
    return FlowSummary(
      incomes: MoneyAmount.parseApi(json['incomes'] as String),
      expenses: MoneyAmount.parseApi(json['expenses'] as String),
      net: MoneyAmount.parseApi(json['net'] as String),
    );
  }

  final MoneyAmount incomes;
  final MoneyAmount expenses;
  final MoneyAmount net;
}

@immutable
class ComparisonSummary {
  const ComparisonSummary({
    required this.current,
    required this.previous,
    required this.previousStart,
    required this.previousEnd,
    required this.pct,
    required this.direction,
  });

  factory ComparisonSummary.fromJson(Map<String, dynamic> json) {
    final pctRaw = json['pct'];
    return ComparisonSummary(
      current: MoneyAmount.parseApi(json['current'] as String),
      previous: MoneyAmount.parseApi(json['previous'] as String),
      previousStart: DateTime.parse(json['previous_start'] as String),
      previousEnd: DateTime.parse(json['previous_end'] as String),
      pct: pctRaw != null ? double.tryParse(pctRaw.toString()) : null,
      direction: json['direction'] as String? ?? 'none',
    );
  }

  final MoneyAmount current;
  final MoneyAmount previous;
  final DateTime previousStart;
  final DateTime previousEnd;
  final double? pct;
  final String direction;
}

@immutable
class WeeklySpendItem {
  const WeeklySpendItem({
    required this.start,
    required this.end,
    required this.expenses,
    required this.isFuture,
  });

  factory WeeklySpendItem.fromJson(Map<String, dynamic> json) {
    return WeeklySpendItem(
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      expenses: MoneyAmount.parseApi(json['expenses'] as String),
      isFuture: json['is_future'] as bool? ?? false,
    );
  }

  final DateTime start;
  final DateTime end;
  final MoneyAmount expenses;
  final bool isFuture;
}

@immutable
class TopCategoryItem {
  const TopCategoryItem({
    required this.categoryId,
    required this.name,
    required this.total,
    required this.sharePct,
  });

  factory TopCategoryItem.fromJson(Map<String, dynamic> json) {
    return TopCategoryItem(
      categoryId: json['category_id'] as int?,
      name: json['name'] as String? ?? 'Sin categoría',
      total: MoneyAmount.parseApi(json['total'] as String),
      sharePct: double.tryParse(json['share_pct']?.toString() ?? '0') ?? 0.0,
    );
  }

  final int? categoryId;
  final String name;
  final MoneyAmount total;
  final double sharePct;
}

@immutable
class ProjectionSummary {
  const ProjectionSummary({
    required this.spentMtd,
    required this.projected,
  });

  factory ProjectionSummary.fromJson(Map<String, dynamic> json) {
    return ProjectionSummary(
      spentMtd: MoneyAmount.parseApi(json['spent_mtd'] as String),
      projected: MoneyAmount.parseApi(json['projected'] as String),
    );
  }

  final MoneyAmount spentMtd;
  final MoneyAmount projected;
}

@immutable
class BalanceSummary {
  const BalanceSummary({
    required this.total,
    required this.avgMonthlySpend,
    required this.runwayMonths,
  });

  factory BalanceSummary.fromJson(Map<String, dynamic> json) {
    final runwayRaw = json['runway_months'];
    return BalanceSummary(
      total: MoneyAmount.parseApi(json['total'] as String),
      avgMonthlySpend: MoneyAmount.parseApi(json['avg_monthly_spend'] as String),
      runwayMonths: runwayRaw != null ? double.tryParse(runwayRaw.toString()) : null,
    );
  }

  final MoneyAmount total;
  final MoneyAmount avgMonthlySpend;
  final double? runwayMonths;
}

@immutable
class IncomeAverageSummary {
  const IncomeAverageSummary({
    required this.avg3m,
    required this.avg6m,
    required this.variability,
  });

  factory IncomeAverageSummary.fromJson(Map<String, dynamic> json) {
    final vRaw = json['variability'];
    return IncomeAverageSummary(
      avg3m: MoneyAmount.parseApi(json['avg_3m'] as String),
      avg6m: MoneyAmount.parseApi(json['avg_6m'] as String),
      variability: vRaw != null ? double.tryParse(vRaw.toString()) : null,
    );
  }

  final MoneyAmount avg3m;
  final MoneyAmount avg6m;
  final double? variability;
}

@immutable
class WeekdayPattern {
  const WeekdayPattern({
    required this.weekendAvg,
    required this.weekdayAvg,
  });

  factory WeekdayPattern.fromJson(Map<String, dynamic> json) {
    return WeekdayPattern(
      weekendAvg: MoneyAmount.parseApi(json['weekend_avg'] as String),
      weekdayAvg: MoneyAmount.parseApi(json['weekday_avg'] as String),
    );
  }

  final MoneyAmount weekendAvg;
  final MoneyAmount weekdayAvg;
}

@immutable
class RecurringCandidate {
  const RecurringCandidate({
    required this.merchant,
    required this.typicalAmount,
    required this.nextExpected,
  });

  factory RecurringCandidate.fromJson(Map<String, dynamic> json) {
    return RecurringCandidate(
      merchant: json['merchant'] as String? ?? '',
      typicalAmount: MoneyAmount.parseApi(json['typical_amount'] as String),
      nextExpected: DateTime.parse(json['next_expected'] as String),
    );
  }

  final String merchant;
  final MoneyAmount typicalAmount;
  final DateTime nextExpected;
}

@immutable
class RecentMovementItem {
  const RecentMovementItem({
    required this.id,
    required this.type,
    required this.occurredAt,
    required this.title,
    required this.amount,
  });

  factory RecentMovementItem.fromJson(Map<String, dynamic> json) {
    return RecentMovementItem(
      id: json['id'] as int,
      type: json['type'] as String? ?? 'expense',
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      title: json['title'] as String? ?? 'Sin detalle',
      amount: MoneyAmount.parseApi(json['amount'] as String),
    );
  }

  final int id;
  final String type;
  final DateTime occurredAt;
  final String title;
  final MoneyAmount amount;
}

@immutable
class DashboardSummary {
  const DashboardSummary({
    required this.period,
    required this.flow,
    required this.comparison,
    required this.weekly,
    required this.topCategories,
    required this.projection,
    required this.balance,
    required this.incomeAverage,
    required this.weekdayPattern,
    required this.recurringCandidates,
    required this.recent,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      period: PeriodSummary.fromJson(json['period'] as Map<String, dynamic>),
      flow: FlowSummary.fromJson(json['flow'] as Map<String, dynamic>),
      comparison: ComparisonSummary.fromJson(
        json['comparison'] as Map<String, dynamic>,
      ),
      weekly: (json['weekly'] as List<dynamic>? ?? const [])
          .map((e) => WeeklySpendItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      topCategories: (json['top_categories'] as List<dynamic>? ?? const [])
          .map((e) => TopCategoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      projection: ProjectionSummary.fromJson(
        json['projection'] as Map<String, dynamic>,
      ),
      balance: BalanceSummary.fromJson(json['balance'] as Map<String, dynamic>),
      incomeAverage: IncomeAverageSummary.fromJson(
        json['income_average'] as Map<String, dynamic>,
      ),
      weekdayPattern: WeekdayPattern.fromJson(
        json['weekday_pattern'] as Map<String, dynamic>,
      ),
      recurringCandidates: (json['recurring_candidates'] as List<dynamic>? ?? const [])
          .map((e) => RecurringCandidate.fromJson(e as Map<String, dynamic>))
          .toList(),
      recent: (json['recent'] as List<dynamic>? ?? const [])
          .map((e) => RecentMovementItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final PeriodSummary period;
  final FlowSummary flow;
  final ComparisonSummary comparison;
  final List<WeeklySpendItem> weekly;
  final List<TopCategoryItem> topCategories;
  final ProjectionSummary projection;
  final BalanceSummary balance;
  final IncomeAverageSummary incomeAverage;
  final WeekdayPattern weekdayPattern;
  final List<RecurringCandidate> recurringCandidates;
  final List<RecentMovementItem> recent;
}
