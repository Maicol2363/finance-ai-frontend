import 'package:finance_ai/core/formatters/date_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 29, 15, 30);

  test('relativeDay labels today, yesterday and tomorrow', () {
    expect(DateLabels.relativeDay(DateTime(2026, 9, 29, 8), now: now), 'Hoy');
    expect(DateLabels.relativeDay(DateTime(2026, 9, 28, 23), now: now), 'Ayer');
    expect(DateLabels.relativeDay(DateTime(2026, 9, 30), now: now), 'Mañana');
  });

  test('relativeDay uses a short day+month and adds the year when needed', () {
    expect(
      DateLabels.relativeDay(DateTime(2026, 9, 17, 12, 30), now: now),
      '17 sep',
    );
    expect(DateLabels.relativeDay(DateTime(2026, 1, 4), now: now), '4 ene');
    expect(
      DateLabels.relativeDay(DateTime(2025, 12, 31), now: now),
      '31 dic 2025',
    );
  });

  test('time renders a zero-padded 24-hour clock', () {
    expect(DateLabels.time(DateTime(2026, 9, 29, 9, 5)), '09:05');
    expect(DateLabels.time(DateTime(2026, 9, 29, 23, 59)), '23:59');
    expect(DateLabels.time(DateTime(2026, 9, 29)), '00:00');
  });
}
