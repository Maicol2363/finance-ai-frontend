import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/budgets/domain/budget_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../budget_test_helpers.dart';

void main() {
  test('decodes exact money, category, period, dates, and progress', () {
    final value = Budget.fromJson(budgetJson(frequencyUnit: 'week'));

    expect(value.id, 7);
    expect(value.category?.name, 'Mercado');
    expect(value.amount.toApiString(), '500000.00');
    expect(value.spentAmount.toApiString(), '125000.50');
    expect(value.remainingAmount.toApiString(), '374999.50');
    expect(value.simplePeriod, BudgetPeriod.weekly);
    expect(value.startsOn, DateTime(2026, 9));
    expect(value.createdAt.isUtc, isTrue);
    expect(value.progressFraction, .25);
  });

  test('caps visual progress while retaining over-budget percentage', () {
    final value = Budget.fromJson(
      budgetJson(
        spentAmount: '600000.00',
        remainingAmount: '-100000.00',
        progressPercent: '120.00',
      ),
    );

    expect(value.progressPercent, 120);
    expect(value.progressFraction, 1);
    expect(value.remainingAmount.isNegative, isTrue);
  });

  test('list supports simultaneous budgets and multiple currencies', () {
    final result = BudgetListResult.fromJson(
      budgetListJson(
        budgets: [
          budgetJson(),
          budgetJson(
            id: 8,
            currencyCode: 'USD',
            frequencyUnit: 'week',
            amount: '100.00',
            spentAmount: '10.00',
            remainingAmount: '90.00',
            progressPercent: '10.00',
          ),
        ],
      ),
    );

    expect(result.budgets, hasLength(2));
    expect(result.budgetById(8)?.currency.code, 'USD');
    expect(result.budgetById(999), isNull);
    expect(result.supportedCurrencies.map((item) => item.code), ['COP', 'USD']);
  });

  test('write command sends canonical amount and simple wire period', () {
    final command = BudgetCreateCommand(
      categoryId: 4,
      amount: MoneyAmount.parseApi('250000.50'),
      currencyCode: 'COP',
      period: BudgetPeriod.monthly,
    );

    expect(command.toJson(), {
      'category_id': 4,
      'amount': '250000.50',
      'currency_code': 'COP',
      'period': 'monthly',
    });
  });

  test(
    'advanced command serializes custom recurrence and all-expense scope',
    () {
      final command = BudgetCreateCommand(
        categoryId: null,
        name: 'Family fortnight',
        amount: MoneyAmount.parseApi('900.00'),
        currencyCode: 'USD',
        schedule: BudgetSchedule(
          scheduleType: BudgetScheduleType.recurring,
          frequencyUnit: BudgetFrequencyUnit.week,
          frequencyInterval: 2,
          startsOn: DateTime(2026, 10, 5),
          endsOn: DateTime(2026, 12, 31),
        ),
      );

      expect(command.toJson(), {
        'category_id': null,
        'name': 'Family fortnight',
        'amount': '900.00',
        'currency_code': 'USD',
        'schedule': {
          'schedule_type': 'recurring',
          'frequency_unit': 'week',
          'frequency_interval': 2,
          'starts_on': '2026-10-05',
          'ends_on': '2026-12-31',
        },
      });
    },
  );

  test('malformed payloads fail closed', () {
    expect(
      () => Budget.fromJson({...budgetJson(), 'progress_percent': '-1.00'}),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => Budget.fromJson({...budgetJson(), 'starts_on': 'not-a-date'}),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => BudgetListResult.fromJson({
        ...budgetListJson(),
        'suggested_currency_code': 'EUR',
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => Budget.fromJson({
        ...budgetJson(),
        'category': {'id': 0},
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
