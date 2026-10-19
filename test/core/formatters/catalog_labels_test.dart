import 'package:finance_ai/core/formatters/catalog_labels.dart';
import 'package:finance_ai/core/formatters/date_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('localizes known seeded catalog labels for presentation', () {
    expect(CatalogLabels.display('Needs'), 'Necesidades');
    expect(CatalogLabels.display('Wants'), 'Deseos');
    expect(CatalogLabels.display('Other'), 'Otros');
    expect(CatalogLabels.display('Salary'), 'Salario');
    expect(CatalogLabels.display('Colombian Peso'), 'Peso colombiano');
  });

  test('preserves unknown catalog labels exactly as received', () {
    expect(CatalogLabels.display('Beca universitaria'), 'Beca universitaria');
    expect(CatalogLabels.display('  Custom source  '), '  Custom source  ');
  });

  test(
    'formats transfer API calendar dates in Spanish without timezone shift',
    () {
      expect(
        DateLabels.calendarDate(DateTime.utc(2026, 10, 18)),
        '18 de octubre de 2026',
      );
    },
  );
}
