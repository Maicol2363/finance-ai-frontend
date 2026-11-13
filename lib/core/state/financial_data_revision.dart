import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Signals that a confirmed financial operation may have changed account data.
final financialMovementRevisionProvider =
    NotifierProvider<FinancialMovementRevision, int>(
      FinancialMovementRevision.new,
    );

class FinancialMovementRevision extends Notifier<int> {
  @override
  int build() => 0;

  void changed() => state += 1;
}

/// Signals an expense created outside the expense controller, such as capture.
final externalExpenseRevisionProvider =
    NotifierProvider<ExternalExpenseRevision, int>(ExternalExpenseRevision.new);

class ExternalExpenseRevision extends Notifier<int> {
  @override
  int build() => 0;

  void changed() => state += 1;
}
