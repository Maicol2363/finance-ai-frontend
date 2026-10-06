import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Injectable clock.
///
/// The month-scoped cards (Gastos hub and Dashboard) read "now" from here so a
/// test can pin the month instead of depending on the machine date.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
