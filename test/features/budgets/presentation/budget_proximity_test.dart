import 'package:finance_ai/core/theme/app_theme.dart';
import 'package:finance_ai/features/budgets/application/budgets_state.dart';
import 'package:finance_ai/features/budgets/presentation/budget_dashboard_section.dart';
import 'package:finance_ai/features/budgets/presentation/budget_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../budget_test_helpers.dart';

Future<void> _pump(WidgetTester t, Widget w) async {
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: w),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('shows near-limit warning at 80 percent', (t) async {
    await _pump(t, BudgetProgressCard(budget: budget(progress: 85)));
    expect(find.byKey(const Key('budget-near-limit-7')), findsOneWidget);
    expect(find.textContaining('Casi al l'), findsOneWidget);
  });
  testWidgets('no warning below 80 percent', (t) async {
    await _pump(t, BudgetProgressCard(budget: budget(progress: 25)));
    expect(find.byKey(const Key('budget-near-limit-7')), findsNothing);
  });
  testWidgets('no near-limit badge when already exceeded', (t) async {
    await _pump(
      t,
      BudgetProgressCard(
        budget: budget(
          progress: 120,
          spent: '600000.00',
          remaining: '-100000.00',
        ),
      ),
    );
    expect(find.byKey(const Key('budget-near-limit-7')), findsNothing);
    expect(find.textContaining('Excedido'), findsOneWidget);
  });
  testWidgets('dashboard section orders riskiest first', (t) async {
    final state = BudgetsState(
      loadStatus: BudgetsLoadStatus.ready,
      result: budgetResult(
        budgets: [
          budget(id: 7, progress: 10),
          budget(id: 8, progress: 95),
          budget(id: 9, progress: 50),
        ],
      ),
    );
    await _pump(
      t,
      BudgetDashboardSection(state: state, onRetry: () {}, onManage: () {}),
    );
    final cards = t
        .widgetList<BudgetProgressCard>(find.byType(BudgetProgressCard))
        .toList();
    expect(cards.map((c) => c.budget.id).toList(), [8, 9, 7]);
    expect(find.byKey(const Key('budget-near-limit-8')), findsOneWidget);
  });
}
