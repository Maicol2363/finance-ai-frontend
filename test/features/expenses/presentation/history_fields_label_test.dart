import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'expenses_screens_test.dart';

void main() {
  testWidgets('history search expone label Buscar + hint e iconos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpExpensesApp(
      tester,
      WidgetExpensesRepository(),
      initialLocation: '/history',
    );

    final searchFinder = find.byKey(const Key('history-search-field'));
    expect(searchFinder, findsOneWidget);

    final field = tester.widget<TextField>(searchFinder);
    final decoration = field.decoration;
    expect(decoration?.labelText, 'Buscar');
    expect(decoration?.hintText, contains('Buscar'));
    expect(decoration?.prefixIcon, isA<Icon>());

    // Sin texto no hay boton limpiar; con texto aparece con tooltip.
    expect(find.byKey(const Key('history-search-clear')), findsNothing);
    await tester.enterText(searchFinder, 'market');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('history-search-clear')), findsOneWidget);
    final clear = tester.widget<IconButton>(
      find.byKey(const Key('history-search-clear')),
    );
    expect(clear.tooltip, 'Borrar búsqueda');
    expect(tester.takeException(), isNull);
  });

  testWidgets('history comercio expone label Comercio + hint e iconos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpExpensesApp(
      tester,
      WidgetExpensesRepository(),
      initialLocation: '/history',
    );

    await tester.tap(find.byKey(const Key('history-filter-toggle')));
    await tester.pumpAndSettle();

    final storeFinder = find.byKey(const Key('history-store-field'));
    expect(storeFinder, findsOneWidget);

    final field = tester.widget<TextField>(storeFinder);
    final decoration = field.decoration;
    expect(decoration?.labelText, 'Comercio');
    expect(decoration?.hintText, contains('Comercio'));
    expect(decoration?.prefixIcon, isA<Icon>());

    expect(find.byKey(const Key('history-store-clear')), findsNothing);
    await tester.enterText(storeFinder, 'Exito');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('history-store-clear')), findsOneWidget);
    final clear = tester.widget<IconButton>(
      find.byKey(const Key('history-store-clear')),
    );
    expect(clear.tooltip, 'Borrar comercio');
    expect(tester.takeException(), isNull);
  });
}
