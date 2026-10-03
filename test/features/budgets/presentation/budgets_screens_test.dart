import 'package:finance_ai/app.dart';
import 'package:finance_ai/core/router/app_router.dart';
import 'package:finance_ai/core/theme/app_theme.dart';
import 'package:finance_ai/features/budgets/application/budgets_state.dart';
import 'package:finance_ai/features/budgets/data/budgets_repository.dart';
import 'package:finance_ai/features/budgets/domain/budget_models.dart';
import 'package:finance_ai/features/budgets/presentation/budget_dashboard_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../budget_test_helpers.dart';

class WidgetBudgetsRepository implements BudgetsRepository {
  BudgetListResult current = budgetResult();
  BudgetCreateCommand? createdCommand;
  BudgetUpdateCommand? updatedCommand;
  int? deletedBudgetId;

  @override
  Future<BudgetListResult> list() async => current;

  @override
  Future<Budget> create(BudgetCreateCommand command) async {
    createdCommand = command;
    final created = budget(
      id: 9,
      currency: command.currencyCode == 'USD' ? usd : cop,
      period:
          command.period ??
          (command.schedule?.frequencyUnit == BudgetFrequencyUnit.week
              ? BudgetPeriod.weekly
              : BudgetPeriod.monthly),
      amount: command.amount.toApiString(),
      spent: '0.00',
      remaining: command.amount.toApiString(),
      progress: 0,
    );
    current = budgetResult(budgets: [created, ...current.budgets]);
    return created;
  }

  @override
  Future<Budget> update(int budgetId, BudgetUpdateCommand command) async {
    updatedCommand = command;
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
    deletedBudgetId = budgetId;
    current = budgetResult(
      budgets: current.budgets.where((item) => item.id != budgetId).toList(),
    );
  }
}

Future<void> pumpBudgetsApp(
  WidgetTester tester,
  WidgetBudgetsRepository repository, {
  String initialLocation = '/budgets',
  Size surfaceSize = const Size(390, 844),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = createAppRouter(initialLocation: initialLocation);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [budgetsRepositoryProvider.overrideWithValue(repository)],
      child: FinanceApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mobile list presents each currency and over-budget state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repository = WidgetBudgetsRepository()
      ..current = budgetResult(
        budgets: [
          budget(),
          budget(
            id: 8,
            currency: usd,
            amount: '100.00',
            spent: '120.00',
            remaining: '-20.00',
            progress: 120,
          ),
        ],
      );
    await pumpBudgetsApp(tester, repository);

    expect(find.byKey(const Key('budgets-list')), findsOneWidget);
    expect(find.byKey(const Key('budget-card-7')), findsOneWidget);
    expect(find.byKey(const Key('budget-card-8')), findsOneWidget);
    expect(find.textContaining('COP \$ 125.000,50'), findsOneWidget);
    expect(find.textContaining('USD \$ 120'), findsOneWidget);
    expect(find.text('Excedido USD \$ 20'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label ==
                'Mercado: 120 por ciento usado, excedido',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets(
    'desktop create supports presets and submits weekly exact money',
    (tester) async {
      final repository = WidgetBudgetsRepository();
      await pumpBudgetsApp(
        tester,
        repository,
        initialLocation: '/budgets/new',
        surfaceSize: const Size(1280, 800),
      );

      expect(find.text('Alcance, calendario, monto y moneda'), findsOneWidget);
      await tester.tap(find.byKey(const Key('budget-recurrence-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Semanal').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('budget-amount-field')),
        '1234,5',
      );
      await tester.ensureVisible(find.byKey(const Key('budget-save-button')));
      await tester.tap(find.byKey(const Key('budget-save-button')));
      await tester.pumpAndSettle();

      expect(repository.createdCommand?.categoryId, 4);
      expect(repository.createdCommand?.period, isNull);
      expect(
        repository.createdCommand?.schedule?.frequencyUnit,
        BudgetFrequencyUnit.week,
      );
      expect(repository.createdCommand?.schedule?.frequencyInterval, 1);
      expect(repository.createdCommand?.currencyCode, 'COP');
      expect(repository.createdCommand?.amount.toApiString(), '1234.50');
      expect(find.text('Presupuestos'), findsOneWidget);
      expect(find.byKey(const Key('budget-card-9')), findsOneWidget);
    },
  );

  testWidgets('advanced editor submits custom all-expense recurrence', (
    tester,
  ) async {
    final repository = WidgetBudgetsRepository();
    await pumpBudgetsApp(
      tester,
      repository,
      initialLocation: '/budgets/new',
      surfaceSize: const Size(1280, 1000),
    );

    await tester.enterText(
      find.byKey(const Key('budget-name-field')),
      'Plan familiar',
    );
    await tester.tap(find.byKey(const Key('budget-category-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todos los gastos').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('budget-recurrence-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personalizado').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('budget-interval-field')), '2');
    await tester.tap(find.byKey(const Key('budget-frequency-unit-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('semanas').last);
    await tester.enterText(find.byKey(const Key('budget-amount-field')), '900');
    await tester.ensureVisible(find.byKey(const Key('budget-save-button')));
    await tester.tap(find.byKey(const Key('budget-save-button')));
    await tester.pumpAndSettle();

    final command = repository.createdCommand;
    expect(command?.categoryId, isNull);
    expect(command?.name, 'Plan familiar');
    expect(command?.schedule?.scheduleType, BudgetScheduleType.recurring);
    expect(command?.schedule?.frequencyUnit, BudgetFrequencyUnit.week);
    expect(command?.schedule?.frequencyInterval, 2);
  });

  testWidgets('edit can delete after explicit confirmation', (tester) async {
    final repository = WidgetBudgetsRepository();
    await pumpBudgetsApp(
      tester,
      repository,
      initialLocation: '/budgets/7/edit',
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('budget-delete-button')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('¿Eliminar presupuesto?'), findsOneWidget);
    expect(find.textContaining('Tus gastos no cambiarán'), findsOneWidget);
    await tester.tap(find.byKey(const Key('budget-confirm-delete-button')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(repository.deletedBudgetId, 7);
    expect(find.text('Crea tu primer presupuesto'), findsOneWidget);
  });

  testWidgets('dashboard shows up to three budgets and manage action', (
    tester,
  ) async {
    var managed = false;
    final state = BudgetsState(
      loadStatus: BudgetsLoadStatus.ready,
      result: budgetResult(
        budgets: [budget(), budget(id: 8), budget(id: 9), budget(id: 10)],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BudgetDashboardSection(
            state: state,
            onRetry: () {},
            onManage: () => managed = true,
          ),
        ),
      ),
    );

    expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
    expect(find.text('Administrar'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dashboard-manage-budgets')));
    expect(managed, isTrue);
  });
}
