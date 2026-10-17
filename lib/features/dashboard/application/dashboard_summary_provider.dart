import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock_provider.dart';
import '../../auth/session/application/auth_session_controller.dart';
import '../../expenses/application/monthly_totals.dart';
import '../../expenses/application/expenses_controller.dart';
import '../../incomes/data/incomes_repository.dart';
import '../../budgets/application/budgets_controller.dart';
import '../data/dashboard_repository.dart';
import 'dashboard_currency_provider.dart';
import '../domain/dashboard_summary.dart';

final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((
  ref,
) async {
  ref.watch(expensesControllerProvider.select((s) => s.result));
  ref.watch(incomeRevisionProvider);
  ref.watch(budgetsControllerProvider.select((s) => s.result));
  final period = ref.watch(dashboardPeriodProvider);
  final now = ref.watch(clockProvider)();
  final customRange = ref.watch(dashboardCustomRangeProvider);
  final window = periodWindow(period, now, customRange: customRange);
  final currency =
      ref.watch(dashboardCurrencyProvider) ??
      ref.watch(authSessionControllerProvider).user?.preferredCurrency ??
      'COP';
  final repository = ref.watch(dashboardRepositoryProvider);

  return repository.getSummary(
    start: window.start,
    end: window.end,
    currency: currency,
    tz: 'America/Bogota',
  );
});
