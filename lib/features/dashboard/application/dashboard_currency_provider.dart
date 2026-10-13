import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Display currency shared by Inicio and Análisis; amounts are never converted.
final dashboardCurrencyProvider =
    NotifierProvider<DashboardCurrencyController, String?>(
      DashboardCurrencyController.new,
    );

class DashboardCurrencyController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String currency) {
    if (state != currency) state = currency;
  }
}
