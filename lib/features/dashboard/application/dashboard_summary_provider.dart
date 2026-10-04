import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock_provider.dart';
import '../../auth/session/application/auth_session_controller.dart';
import '../../expenses/application/monthly_totals.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_summary.dart';

final dashboardSummaryProvider =
    FutureProvider.autoDispose<DashboardSummary>((ref) async {
  final period = ref.watch(dashboardPeriodProvider);
  final now = ref.watch(clockProvider)();
  final window = periodWindow(period, now);
  final currency =
      ref.watch(authSessionControllerProvider).user?.preferredCurrency ?? 'COP';
  final repository = ref.watch(dashboardRepositoryProvider);

  return repository.getSummary(
    start: window.start,
    end: window.end,
    currency: currency,
    tz: 'America/Bogota',
  );
});
