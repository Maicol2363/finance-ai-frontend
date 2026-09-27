import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/budgets/domain/budget_models.dart';
import 'package:finance_ai/features/categories/domain/category_models.dart';

const cop = CurrencySummary(
  id: 1,
  code: 'COP',
  name: 'Peso colombiano',
  decimals: 2,
);

const usd = CurrencySummary(id: 2, code: 'USD', name: 'US Dollar', decimals: 2);

const groceries = BudgetCategory(
  id: 4,
  name: 'Mercado',
  color: CategoryColor.green,
  icon: CategoryIcon.food,
);

Map<String, Object?> budgetJson({
  int id = 7,
  String currencyCode = 'COP',
  String frequencyUnit = 'month',
  String amount = '500000.00',
  String spentAmount = '125000.50',
  String remainingAmount = '374999.50',
  String progressPercent = '25.00',
  Object? category = const {
    'id': 4,
    'name': 'Mercado',
    'color': 'green',
    'icon': 'food',
  },
}) => {
  'id': id,
  'category': category,
  'currency': {
    'id': currencyCode == 'COP' ? 1 : 2,
    'code': currencyCode,
    'name': currencyCode == 'COP' ? 'Peso colombiano' : 'US Dollar',
    'decimals': 2,
  },
  'amount': amount,
  'schedule_type': 'recurring',
  'frequency_unit': frequencyUnit,
  'frequency_interval': 1,
  'starts_on': '2026-09-01',
  'ends_on': null,
  'current_period_start': '2026-09-01',
  'current_period_end': '2026-09-30',
  'spent_amount': spentAmount,
  'remaining_amount': remainingAmount,
  'progress_percent': progressPercent,
  'is_active': true,
  'created_at': '2026-09-12T12:00:00Z',
  'updated_at': '2026-09-12T13:00:00Z',
};

Map<String, Object?> budgetListJson({List<Object?>? budgets}) => {
  'budgets': budgets ?? [budgetJson()],
  'categories': [
    {'id': 4, 'name': 'Mercado', 'color': 'green', 'icon': 'food'},
  ],
  'supported_currencies': [
    {'id': 1, 'code': 'COP', 'name': 'Peso colombiano', 'decimals': 2},
    {'id': 2, 'code': 'USD', 'name': 'US Dollar', 'decimals': 2},
  ],
  'suggested_currency_code': 'COP',
};

Budget budget({
  int id = 7,
  CurrencySummary currency = cop,
  BudgetCategory? category = groceries,
  BudgetPeriod period = BudgetPeriod.monthly,
  String amount = '500000.00',
  String spent = '125000.50',
  String remaining = '374999.50',
  double progress = 25,
}) => Budget(
  id: id,
  category: category,
  currency: currency,
  amount: MoneyAmount.parseApi(amount),
  scheduleType: 'recurring',
  frequencyUnit: period == BudgetPeriod.weekly ? 'week' : 'month',
  frequencyInterval: 1,
  startsOn: DateTime.utc(2026, 9),
  endsOn: null,
  currentPeriodStart: DateTime.utc(2026, 9),
  currentPeriodEnd: DateTime.utc(2026, 9, 30),
  spentAmount: MoneyAmount.parseApi(spent),
  remainingAmount: MoneyAmount.parseApi(remaining),
  progressPercent: progress,
  isActive: true,
  createdAt: DateTime.utc(2026, 9, 12, 12),
  updatedAt: DateTime.utc(2026, 9, 12, 13),
);

BudgetListResult budgetResult({List<Budget>? budgets}) => BudgetListResult(
  budgets: budgets ?? [budget()],
  categories: const [groceries],
  supportedCurrencies: const [cop, usd],
  suggestedCurrencyCode: 'COP',
);
