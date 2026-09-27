import '../../accounts/domain/account_models.dart';
import '../../categories/domain/category_models.dart';

enum BudgetPeriod {
  weekly('weekly', 'Semanal'),
  monthly('monthly', 'Mensual');

  const BudgetPeriod(this.wireValue, this.label);

  final String wireValue;
  final String label;
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
    required this.period,
  });

  final int categoryId;
  final MoneyAmount amount;
  final String currencyCode;
  final BudgetPeriod period;

  Map<String, Object?> toJson() => {
    'category_id': categoryId,
    'amount': amount.toApiString(),
    'currency_code': currencyCode,
    'period': period.wireValue,
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
