import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/movements_empty_state.dart';
import '../../incomes/data/incomes_repository.dart';
import '../../incomes/domain/income_models.dart';
import '../application/expenses_controller.dart';
import '../application/expenses_state.dart';
import '../domain/expense_models.dart';
import 'transaction_visuals.dart';

/// How many movements the recent feed shows.
const recentMovementsLimit = 10;

/// "Historial reciente": the latest expenses and incomes, newest first.
///
/// Lives in the Dashboard (it used to be on the Gastos screen). It reads the
/// same providers as before, so a movement recorded from the chat, the manual
/// forms or a receipt photo shows up here the same way.
class RecentMovementsSection extends ConsumerWidget {
  const RecentMovementsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final expensesState = ref.watch(expensesControllerProvider);
    final result = expensesState.result;
    final incomes = ref.watch(incomesListProvider).value ?? const <Income>[];
    final movements = recentMovements(
      result?.items ?? const <Expense>[],
      incomes,
    );
    final isBusy =
        expensesState.listStatus == ExpensesLoadStatus.loading ||
        expensesState.listStatus == ExpensesLoadStatus.loadingMore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'Historial reciente',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                  ),
                  if (result != null && movements.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: palette.soft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${movements.length} ${movements.length == 1 ? 'movimiento' : 'movimientos'}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: palette.muted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            TextButton(
              key: const Key('recent-movements-see-all'),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: palette.primary,
              ),
              onPressed: () => context.push('/history'),
              child: const Text('Ver todo'),
            ),
          ],
        ),
        if (isBusy) ...[
          Semantics(
            liveRegion: true,
            label: 'Cargando movimientos',
            child: const LinearProgressIndicator(),
          ),
          const SizedBox(height: 12),
        ],
        if (expensesState.listDiagnostic case final diagnostic?) ...[
          ErrorDiagnosticPanel(diagnostic: diagnostic),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: ref.read(expensesControllerProvider.notifier).load,
              icon: const Icon(FinanceIcons.refresh),
              label: const Text('Reintentar'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (result == null &&
            expensesState.listStatus != ExpensesLoadStatus.loading &&
            expensesState.listDiagnostic == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (result != null && movements.isEmpty)
          MovementsEmptyState(onRegister: () => context.push('/expenses/new')),
        if (result != null && movements.isNotEmpty)
          for (final movement in movements) ...[
            switch (movement) {
              ExpenseMovement(:final expense) => _HubExpenseCard(
                expense: expense,
              ),
              IncomeMovement(:final income) => _HubIncomeCard(income: income),
            },
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

/// One row of the recent feed.
sealed class RecentMovement {
  const RecentMovement();
  DateTime get date;
}

class ExpenseMovement extends RecentMovement {
  const ExpenseMovement(this.expense);
  final Expense expense;

  @override
  DateTime get date => expense.occurredAt;
}

class IncomeMovement extends RecentMovement {
  const IncomeMovement(this.income);
  final Income income;

  @override
  DateTime get date => income.date;
}

/// Newest [recentMovementsLimit] expenses and incomes.
///
/// A receipt photo is stored as one expense row per product, so its rows are
/// shown once per receipt.
List<RecentMovement> recentMovements(
  List<Expense> rawExpenses,
  List<Income> incomes,
) {
  final seenReceiptIds = <int>{};
  final expenses = <Expense>[];
  for (final expense in rawExpenses) {
    if (expense.captureSource == CaptureSource.ai &&
        !seenReceiptIds.add(expense.receiptId)) {
      continue;
    }
    expenses.add(expense);
  }
  int idOf(RecentMovement movement) => switch (movement) {
    ExpenseMovement(:final expense) => expense.id,
    IncomeMovement(:final income) => income.id,
  };
  final all =
      <RecentMovement>[
        ...expenses.map(ExpenseMovement.new),
        ...incomes.map(IncomeMovement.new),
      ]..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : idOf(b).compareTo(idOf(a));
      });
  return all.take(recentMovementsLimit).toList(growable: false);
}

// =================== EXPENSE CARD ===================
class _HubExpenseCard extends StatelessWidget {
  const _HubExpenseCard({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final displayAmount = expense.receiptTotal ?? expense.amount;

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        key: Key('expense-card-${expense.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/expenses/${expense.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.primarySoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Icon(
                    categoryIcon(expense.category?.name),
                    size: 20,
                    color: palette.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.store.isNotEmpty ? expense.store : expense.name,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: palette.soft,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            captureSourceLabel(
                              expense.captureSource,
                              expense.items.length,
                            ),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: palette.muted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${expense.accountName}${expense.category == null ? '' : ' · ${expense.category!.name}'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.muted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                MoneyFormatter.display(
                  displayAmount.minorUnits,
                  expense.currencyCode,
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: displayAmount.isNegative
                      ? palette.discard
                      : palette.text,
                ),
                textAlign: TextAlign.end,
              ),
              const SizedBox(width: 4),
              Icon(FinanceIcons.chevronRight, size: 16, color: palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// =================== INCOME CARD ===================
class _HubIncomeCard extends ConsumerWidget {
  const _HubIncomeCard({required this.income});

  final Income income;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final title = income.description != null && income.description!.isNotEmpty
        ? income.description!
        : (income.incomeSourceName ?? 'Ingreso');

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        key: Key('income-card-${income.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await context.push('/incomes/${income.id}');
          if (context.mounted) {
            ref.read(incomeRevisionProvider.notifier).changed();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.incomeSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Icon(
                    FinanceIconCatalog.dataFor(FinanceIconKey.income),
                    size: 20,
                    color: palette.income,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: palette.incomeSoft,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'ingreso',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: palette.income,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${income.accountName}${income.incomeSourceName != null ? ' · ${income.incomeSourceName}' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.muted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                MoneyFormatter.display(
                  income.amount.minorUnits,
                  income.currencyCode,
                  signed: true,
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: palette.income,
                ),
                textAlign: TextAlign.end,
              ),
              const SizedBox(width: 4),
              Icon(FinanceIcons.chevronRight, size: 16, color: palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}
