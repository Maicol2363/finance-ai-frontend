import '../../accounts/domain/account_models.dart';
import '../../categories/domain/category_models.dart';

enum BudgetPeriod {
  weekly('weekly', 'Semanal'),
  monthly('monthly', 'Mensual');

  const BudgetPeriod(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

enum BudgetScheduleType {
  recurring('recurring', 'Recurrente'),
  oneTime('one_time', 'Una sola vez');

  const BudgetScheduleType(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

enum BudgetFrequencyUnit {
  day('day', 'día', 'días'),
  week('week', 'semana', 'semanas'),
  month('month', 'mes', 'meses'),
  year('year', 'año', 'años');

  const BudgetFrequencyUnit(this.wireValue, this.singular, this.plural);

  final String wireValue;
  final String singular;
  final String plural;
}

enum BudgetRecurrencePreset {
  daily('Diario', BudgetFrequencyUnit.day, 1),
  weekly('Semanal', BudgetFrequencyUnit.week, 1),
  fortnightly('Cada 2 semanas', BudgetFrequencyUnit.week, 2),
  monthly('Mensual', BudgetFrequencyUnit.month, 1),
  quarterly('Cada 3 meses', BudgetFrequencyUnit.month, 3),
  yearly('Anual', BudgetFrequencyUnit.year, 1),
  custom('Personalizado', null, null);

  const BudgetRecurrencePreset(this.label, this.unit, this.interval);

  final String label;
  final BudgetFrequencyUnit? unit;
  final int? interval;
}

class BudgetSchedule {
  const BudgetSchedule({
    required this.scheduleType,
    required this.startsOn,
    this.frequencyUnit,
    this.frequencyInterval,
    this.endsOn,
  });

  final BudgetScheduleType scheduleType;
  final BudgetFrequencyUnit? frequencyUnit;
  final int? frequencyInterval;
  final DateTime startsOn;
  final DateTime? endsOn;

  Map<String, Object?> toJson() => {
    'schedule_type': scheduleType.wireValue,
    'frequency_unit': frequencyUnit?.wireValue,
    'frequency_interval': frequencyInterval,
    'starts_on': _date(startsOn),
    'ends_on': endsOn == null ? null : _date(endsOn!),
  };

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class BudgetCategory {
  const BudgetCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
  });

  factory BudgetCategory.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! int || id < 1 || name is! String || name.trim().isEmpty) {
      throw const FormatException('Invalid budget category');
    }
    return BudgetCategory(
      id: id,
      name: name,
      color: CategoryColor.fromWire(json['color']),
      icon: CategoryIcon.fromWire(json['icon']),
    );
  }

  final int id;
  final String name;
  final CategoryColor color;
  final CategoryIcon icon;
}

class Budget {
  const Budget({
    required this.id,
    required this.name,
    required this.category,
    required this.currency,
    required this.amount,
    required this.scheduleType,
    required this.frequencyUnit,
    required this.frequencyInterval,
    required this.startsOn,
    required this.endsOn,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.spentAmount,
    required this.remainingAmount,
    required this.progressPercent,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Budget.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final category = json['category'];
    final currency = json['currency'];
    final amount = json['amount'];
    final scheduleType = json['schedule_type'];
    final frequencyUnit = json['frequency_unit'];
    final frequencyInterval = json['frequency_interval'];
    final startsOn = json['starts_on'];
    final endsOn = json['ends_on'];
    final currentPeriodStart = json['current_period_start'];
    final currentPeriodEnd = json['current_period_end'];
    final spentAmount = json['spent_amount'];
    final remainingAmount = json['remaining_amount'];
    final progressPercent = json['progress_percent'];
    final isActive = json['is_active'];
    final createdAt = json['created_at'];
    final updatedAt = json['updated_at'];
    if (id is! int ||
        id < 1 ||
        name is! String ||
        name.trim().isEmpty ||
        (category != null && category is! Map<String, Object?>) ||
        currency is! Map<String, Object?> ||
        amount is! String ||
        scheduleType is! String ||
        (frequencyUnit != null && frequencyUnit is! String) ||
        (frequencyInterval != null && frequencyInterval is! int) ||
        startsOn is! String ||
        (endsOn != null && endsOn is! String) ||
        currentPeriodStart is! String ||
        currentPeriodEnd is! String ||
        spentAmount is! String ||
        remainingAmount is! String ||
        progressPercent is! String ||
        isActive is! bool ||
        createdAt is! String ||
        updatedAt is! String) {
      throw const FormatException('Invalid budget response');
    }
    final parsedStartsOn = DateTime.tryParse(startsOn);
    final parsedEndsOn = endsOn == null
        ? null
        : DateTime.tryParse(endsOn as String);
    final parsedCurrentStart = DateTime.tryParse(currentPeriodStart);
    final parsedCurrentEnd = DateTime.tryParse(currentPeriodEnd);
    final parsedCreatedAt = DateTime.tryParse(createdAt);
    final parsedUpdatedAt = DateTime.tryParse(updatedAt);
    final parsedProgress = double.tryParse(progressPercent);
    if (parsedStartsOn == null ||
        (endsOn != null && parsedEndsOn == null) ||
        parsedCurrentStart == null ||
        parsedCurrentEnd == null ||
        parsedCreatedAt == null ||
        parsedUpdatedAt == null ||
        parsedProgress == null ||
        !parsedProgress.isFinite ||
        parsedProgress < 0) {
      throw const FormatException('Invalid budget values');
    }
    return Budget(
      id: id,
      name: name,
      category: category == null
          ? null
          : BudgetCategory.fromJson(category as Map<String, Object?>),
      currency: CurrencySummary.fromJson(currency),
      amount: MoneyAmount.parseApi(amount),
      scheduleType: scheduleType,
      frequencyUnit: frequencyUnit as String?,
      frequencyInterval: frequencyInterval as int?,
      startsOn: parsedStartsOn,
      endsOn: parsedEndsOn,
      currentPeriodStart: parsedCurrentStart,
      currentPeriodEnd: parsedCurrentEnd,
      spentAmount: MoneyAmount.parseApi(spentAmount),
      remainingAmount: MoneyAmount.parseApi(remainingAmount),
      progressPercent: parsedProgress,
      isActive: isActive,
      createdAt: parsedCreatedAt.toUtc(),
      updatedAt: parsedUpdatedAt.toUtc(),
    );
  }

  final int id;
  final String name;
  final BudgetCategory? category;
  final CurrencySummary currency;
  final MoneyAmount amount;
  final String scheduleType;
  final String? frequencyUnit;
  final int? frequencyInterval;
  final DateTime startsOn;
  final DateTime? endsOn;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final MoneyAmount spentAmount;
  final MoneyAmount remainingAmount;
  final double progressPercent;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  BudgetPeriod? get simplePeriod {
    if (scheduleType != 'recurring' || frequencyInterval != 1) return null;
    return switch (frequencyUnit) {
      'week' => BudgetPeriod.weekly,
      'month' => BudgetPeriod.monthly,
      _ => null,
    };
  }

  double get progressFraction => (progressPercent / 100).clamp(0, 1);

  String get scheduleLabel {
    if (scheduleType == BudgetScheduleType.oneTime.wireValue) {
      return 'Una sola vez';
    }
    final unit = BudgetFrequencyUnit.values
        .where((item) => item.wireValue == frequencyUnit)
        .firstOrNull;
    final interval = frequencyInterval;
    if (unit == null || interval == null) return 'Personalizado';
    if (interval == 1) {
      return switch (unit) {
        BudgetFrequencyUnit.day => 'Diario',
        BudgetFrequencyUnit.week => 'Semanal',
        BudgetFrequencyUnit.month => 'Mensual',
        BudgetFrequencyUnit.year => 'Anual',
      };
    }
    return 'Cada $interval ${interval == 1 ? unit.singular : unit.plural}';
  }
}

class BudgetListResult {
  const BudgetListResult({
    required this.budgets,
    required this.categories,
    required this.supportedCurrencies,
    required this.suggestedCurrencyCode,
  });

  factory BudgetListResult.fromJson(Map<String, Object?> json) {
    final rawBudgets = json['budgets'];
    final rawCategories = json['categories'];
    final rawCurrencies = json['supported_currencies'];
    final suggestedCurrency = json['suggested_currency_code'];
    if (rawBudgets is! List<Object?> ||
        rawCategories is! List<Object?> ||
        rawCurrencies is! List<Object?> ||
        suggestedCurrency is! String ||
        suggestedCurrency.isEmpty) {
      throw const FormatException('Invalid budget list response');
    }
    final budgets = rawBudgets
        .map((item) {
          if (item is! Map<String, Object?>) {
            throw const FormatException('Invalid budget list item');
          }
          return Budget.fromJson(item);
        })
        .toList(growable: false);
    final categories = rawCategories
        .map((item) {
          if (item is! Map<String, Object?>) {
            throw const FormatException('Invalid budget category option');
          }
          return BudgetCategory.fromJson(item);
        })
        .toList(growable: false);
    final currencies = rawCurrencies
        .map((item) {
          if (item is! Map<String, Object?>) {
            throw const FormatException('Invalid budget currency option');
          }
          return CurrencySummary.fromJson(item);
        })
        .toList(growable: false);
    if (currencies.isEmpty ||
        !currencies.any((item) => item.code == suggestedCurrency)) {
      throw const FormatException('Invalid budget currency suggestion');
    }
    return BudgetListResult(
      budgets: List.unmodifiable(budgets),
      categories: List.unmodifiable(categories),
      supportedCurrencies: List.unmodifiable(currencies),
      suggestedCurrencyCode: suggestedCurrency,
    );
  }

  final List<Budget> budgets;
  final List<BudgetCategory> categories;
  final List<CurrencySummary> supportedCurrencies;
  final String suggestedCurrencyCode;

  Budget? budgetById(int id) {
    for (final budget in budgets) {
      if (budget.id == id) return budget;
    }
    return null;
  }
}

class BudgetCreateCommand {
  const BudgetCreateCommand({
    required this.categoryId,
    required this.amount,
    required this.currencyCode,
    this.name,
    this.period,
    this.schedule,
  }) : assert(period != null || schedule != null),
       assert(period == null || schedule == null);

  final int? categoryId;
  final String? name;
  final MoneyAmount amount;
  final String currencyCode;
  final BudgetPeriod? period;
  final BudgetSchedule? schedule;

  Map<String, Object?> toJson() => {
    'category_id': categoryId,
    if (name != null) 'name': name,
    'amount': amount.toApiString(),
    'currency_code': currencyCode,
    if (period != null) 'period': period!.wireValue,
    if (schedule != null) 'schedule': schedule!.toJson(),
  };
}

typedef BudgetUpdateCommand = BudgetCreateCommand;

class BudgetFailure implements Exception {
  const BudgetFailure({
    required this.code,
    required this.userMessage,
    this.fieldErrors = const {},
    this.correlationId = 'unavailable',
    this.technicalReason = 'budget_operation_failure',
    this.isMutationOutcomeUncertain = false,
  });

  final String code;
  final String userMessage;
  final Map<String, List<String>> fieldErrors;
  final String correlationId;
  final String technicalReason;
  final bool isMutationOutcomeUncertain;
}
