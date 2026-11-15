import 'dart:async';

import 'package:finance_ai/features/budgets/application/budgets_controller.dart';
import 'package:finance_ai/features/budgets/application/budgets_state.dart';
import 'package:finance_ai/features/budgets/data/budgets_repository.dart';
import 'package:finance_ai/features/budgets/domain/budget_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../budget_test_helpers.dart';

class FakeBudgetsRepository implements BudgetsRepository {
  BudgetListResult current = budgetResult();
  Object? listFailure;
  Object? saveFailure;
  Object? deleteFailure;
  Completer<Budget>? pendingCreate;
  Completer<BudgetListResult>? pendingList;
  Completer<void>? pendingDelete;
  BudgetCreateCommand? savedCommand;
  int listCalls = 0;
  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;

  @override
  Future<BudgetListResult> list() async {
    listCalls += 1;
    if (listFailure case final failure?) throw failure;
    final pending = pendingList;
    pendingList = null;
    if (pending != null) return pending.future;
    return current;
  }

  @override
  Future<Budget> create(BudgetCreateCommand command) async {
    createCalls += 1;
    savedCommand = command;
    if (saveFailure case final failure?) throw failure;
    if (pendingCreate case final pending?) return pending.future;
    final created = budget(
      id: 9,
      currency: command.currencyCode == 'USD' ? usd : cop,
      period:
          command.period ??
          (command.schedule?.frequencyUnit == BudgetFrequencyUnit.week
              ? BudgetPeriod.weekly
              : BudgetPeriod.monthly),
      amount: command.amount.toApiString(),
    );
    current = budgetResult(budgets: [created, ...current.budgets]);
    return created;
  }

  @override
  Future<Budget> update(int budgetId, BudgetUpdateCommand command) async {
    updateCalls += 1;
    savedCommand = command;
    if (saveFailure case final failure?) throw failure;
    final updated = budget(
      id: budgetId,
      currency: command.currencyCode == 'USD' ? usd : cop,
      period:
          command.period ??
          (command.schedule?.frequencyUnit == BudgetFrequencyUnit.week
              ? BudgetPeriod.weekly
              : BudgetPeriod.monthly),
      amount: command.amount.toApiString(),
    );
    current = budgetResult(
      budgets: [
        for (final item in current.budgets)
          if (item.id == budgetId) updated else item,
      ],
    );
    return updated;
  }

  @override
  Future<void> deleteBudget(int budgetId) async {
    deleteCalls += 1;
    if (deleteFailure case final failure?) throw failure;
    if (pendingDelete case final pending?) await pending.future;
    current = budgetResult(
      budgets: current.budgets.where((item) => item.id != budgetId).toList(),
    );
  }
}

ProviderContainer containerFor(FakeBudgetsRepository repository) =>
    ProviderContainer(
      overrides: [budgetsRepositoryProvider.overrideWithValue(repository)],
    );

void main() {
  test(
    'queues a refresh requested while a budget load is in progress',
    () async {
      final firstList = Completer<BudgetListResult>();
      final oldBudget = budget(id: 7);
      final newBudget = budget(id: 8, currency: usd);
      final repository = FakeBudgetsRepository()
        ..pendingList = firstList
        ..current = budgetResult(budgets: [oldBudget]);
      final container = containerFor(repository);
      addTearDown(container.dispose);
      final controller = container.read(budgetsControllerProvider.notifier);

      final initialLoad = controller.load();
      await Future<void>.delayed(Duration.zero);
      await controller.load();
      repository.current = budgetResult(budgets: [newBudget]);
      firstList.complete(budgetResult(budgets: [oldBudget]));
      await initialLoad;

      expect(repository.listCalls, 2);
      expect(
        container.read(budgetsControllerProvider).loadStatus,
        BudgetsLoadStatus.ready,
      );
      expect(
        container
            .read(budgetsControllerProvider)
            .result
            ?.budgets
            .map((item) => item.id),
        [newBudget.id],
      );
    },
  );

  test('loads all simultaneous budgets', () async {
    final repository = FakeBudgetsRepository()
      ..current = budgetResult(
        budgets: [
          budget(),
          budget(id: 8, currency: usd),
        ],
      );
    final container = containerFor(repository);
    addTearDown(container.dispose);

    await container.read(budgetsControllerProvider.notifier).load();

    final state = container.read(budgetsControllerProvider);
    expect(state.loadStatus, BudgetsLoadStatus.ready);
    expect(state.result?.budgets, hasLength(2));
  });

  test('validation is exact and diagnostics omit entered values', () async {
    final repository = FakeBudgetsRepository();
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(budgetsControllerProvider.notifier);
    await controller.load();

    final outcome = await controller.save(
      categoryId: 999,
      amountInput: '12.3456',
      currencyCode: 'EUR',
      period: BudgetPeriod.monthly,
    );

    final state = container.read(budgetsControllerProvider);
    expect(outcome, BudgetMutationOutcome.invalid);
    expect(state.fieldErrors.keys, {'category_id', 'amount', 'currency_code'});
    expect(state.mutationDiagnostic?.code, 'budget_invalid');
    expect(state.mutationDiagnostic?.clipboardText, isNot(contains('12.3456')));
    expect(repository.createCalls, 0);
  });

  test('empty, zero, and negative budget amounts are rejected', () async {
    for (final value in ['', '0', '-1']) {
      final repository = FakeBudgetsRepository();
      final container = containerFor(repository);
      final controller = container.read(budgetsControllerProvider.notifier);
      await controller.load();

      final outcome = await controller.save(
        categoryId: 4,
        amountInput: value,
        currencyCode: 'COP',
        period: BudgetPeriod.monthly,
      );

      expect(outcome, BudgetMutationOutcome.invalid, reason: 'amount=$value');
      expect(
        container.read(budgetsControllerProvider).fieldErrors,
        contains('amount'),
        reason: 'amount=$value',
      );
      expect(repository.createCalls, 0, reason: 'amount=$value');
      container.dispose();
    }
  });

  test(
    'repeated create is ignored and exact result enters local list',
    () async {
      final pending = Completer<Budget>();
      final repository = FakeBudgetsRepository()..pendingCreate = pending;
      final container = containerFor(repository);
      addTearDown(container.dispose);
      final controller = container.read(budgetsControllerProvider.notifier);
      await controller.load();

      final first = controller.save(
        categoryId: 4,
        amountInput: '1234,5',
        currencyCode: 'USD',
        period: BudgetPeriod.weekly,
      );
      final repeated = await controller.save(
        categoryId: 4,
        amountInput: '10',
        currencyCode: 'COP',
        period: BudgetPeriod.monthly,
      );
      pending.complete(
        budget(
          id: 9,
          currency: usd,
          period: BudgetPeriod.weekly,
          amount: '1234.50',
        ),
      );

      expect(repeated, BudgetMutationOutcome.ignored);
      expect(await first, BudgetMutationOutcome.success);
      expect(repository.createCalls, 1);
      expect(repository.savedCommand?.amount.toApiString(), '1234.50');
      expect(repository.savedCommand?.currencyCode, 'USD');
      expect(repository.savedCommand?.period, BudgetPeriod.weekly);
      expect(
        container.read(budgetsControllerProvider).result?.budgetById(9),
        isNotNull,
      );
    },
  );

  test('update replaces one budget and preserves the others', () async {
    final repository = FakeBudgetsRepository()
      ..current = budgetResult(budgets: [budget(), budget(id: 8)]);
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(budgetsControllerProvider.notifier);
    await controller.load();

    final outcome = await controller.save(
      budgetId: 7,
      categoryId: 4,
      amountInput: '700000',
      currencyCode: 'COP',
      period: BudgetPeriod.monthly,
    );

    final state = container.read(budgetsControllerProvider);
    expect(outcome, BudgetMutationOutcome.success);
    expect(repository.updateCalls, 1);
    expect(state.result?.budgetById(7)?.amount.toApiString(), '700000.00');
    expect(state.result?.budgetById(8), isNotNull);
  });

  test('advanced one-time all-expense schedule is accepted', () async {
    final repository = FakeBudgetsRepository();
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(budgetsControllerProvider.notifier);
    await controller.load();

    final outcome = await controller.save(
      categoryId: null,
      nameInput: 'Viaje',
      amountInput: '900',
      currencyCode: 'USD',
      schedule: BudgetSchedule(
        scheduleType: BudgetScheduleType.oneTime,
        startsOn: DateTime(2026, 12),
        endsOn: DateTime(2026, 12, 20),
      ),
    );

    expect(outcome, BudgetMutationOutcome.success);
    expect(repository.savedCommand?.categoryId, isNull);
    expect(repository.savedCommand?.name, 'Viaje');
    expect(
      repository.savedCommand?.schedule?.scheduleType,
      BudgetScheduleType.oneTime,
    );
  });

  test('advanced schedule rejects reversed dates', () async {
    final repository = FakeBudgetsRepository();
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(budgetsControllerProvider.notifier);
    await controller.load();

    final outcome = await controller.save(
      categoryId: null,
      amountInput: '900',
      currencyCode: 'COP',
      schedule: BudgetSchedule(
        scheduleType: BudgetScheduleType.oneTime,
        startsOn: DateTime(2026, 12, 20),
        endsOn: DateTime(2026, 12),
      ),
    );

    expect(outcome, BudgetMutationOutcome.invalid);
    expect(
      container.read(budgetsControllerProvider).fieldErrors,
      contains('ends_on'),
    );
    expect(repository.createCalls, 0);
  });

  test(
    'repeated delete is ignored and success removes only its budget',
    () async {
      final pending = Completer<void>();
      final repository = FakeBudgetsRepository()
        ..current = budgetResult(budgets: [budget(), budget(id: 8)])
        ..pendingDelete = pending;
      final container = containerFor(repository);
      addTearDown(container.dispose);
      final controller = container.read(budgetsControllerProvider.notifier);
      await controller.load();

      final first = controller.deleteBudget(7);
      final repeated = await controller.deleteBudget(7);
      pending.complete();

      expect(repeated, BudgetMutationOutcome.ignored);
      expect(await first, BudgetMutationOutcome.success);
      expect(repository.deleteCalls, 1);
      expect(
        container.read(budgetsControllerProvider).result?.budgetById(7),
        isNull,
      );
      expect(
        container.read(budgetsControllerProvider).result?.budgetById(8),
        isNotNull,
      );
    },
  );

  test('controlled failure exposes fields and a safe diagnostic', () async {
    final repository = FakeBudgetsRepository()
      ..saveFailure = const BudgetFailure(
        code: 'budget_currency_invalid',
        userMessage: 'Selecciona una moneda disponible.',
        fieldErrors: {
          'currency_code': ['Unavailable.'],
        },
        correlationId: 'budget-invalid-currency',
        technicalReason: 'http_422',
      );
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(budgetsControllerProvider.notifier);
    await controller.load();

    final outcome = await controller.save(
      categoryId: 4,
      amountInput: '1234.50',
      currencyCode: 'COP',
      period: BudgetPeriod.monthly,
    );

    final state = container.read(budgetsControllerProvider);
    expect(outcome, BudgetMutationOutcome.failure);
    expect(state.fieldErrors, contains('currency_code'));
    expect(state.mutationDiagnostic?.code, 'budget_currency_invalid');
    expect(state.mutationStatus, BudgetMutationStatus.idle);
  });

  test(
    'uncertain mutation refreshes canonical list before reporting',
    () async {
      final repository = FakeBudgetsRepository()
        ..saveFailure = const BudgetFailure(
          code: 'network_unavailable',
          userMessage: 'Actualiza antes de reintentar.',
          correlationId: 'uncertain-budget',
          technicalReason: 'request_timeout',
          isMutationOutcomeUncertain: true,
        );
      final container = containerFor(repository);
      addTearDown(container.dispose);
      final controller = container.read(budgetsControllerProvider.notifier);
      await controller.load();
      repository.current = budgetResult(budgets: [budget(), budget(id: 9)]);

      final outcome = await controller.save(
        categoryId: 4,
        amountInput: '200.00',
        currencyCode: 'COP',
        period: BudgetPeriod.weekly,
      );

      expect(outcome, BudgetMutationOutcome.failure);
      expect(repository.listCalls, 2);
      expect(
        container.read(budgetsControllerProvider).result?.budgetById(9),
        isNotNull,
      );
      expect(
        container.read(budgetsControllerProvider).mutationDiagnostic?.code,
        'network_unavailable',
      );
    },
  );
}
