import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'expenses_screens_test.dart' as screens;

void main() {
  testWidgets('p6_form: amount and merchant fields expose labels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final semanticsHandle = tester.ensureSemantics();

    await screens.pumpExpensesApp(
      tester,
      screens.WidgetExpensesRepository(),
      initialLocation: '/expenses/new',
    );

    final amountField = tester.widget<TextField>(
      find.byKey(const Key('expense-create-amount-field')),
    );
    expect(amountField.decoration?.labelText, 'Monto');

    expect(
      find.ancestor(
        of: find.byKey(const Key('expense-create-amount-field')),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Monto en pesos' &&
              w.explicitChildNodes,
        ),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('expense-create-amount-field')))
          .label,
      contains('Monto'),
    );

    final merchantField = tester.widget<TextField>(
      find.byKey(const Key('expense-create-merchant-field')),
    );
    expect(merchantField.decoration?.labelText, isNotNull);
    expect(merchantField.decoration!.labelText!, isNotEmpty);

    await tester.tap(find.byKey(const Key('segment-ingreso')));
    await tester.pumpAndSettle();

    final customSourceField = tester.widget<TextField>(
      find.byKey(const Key('income-create-source-custom-field')),
    );
    expect(customSourceField.decoration?.labelText, isNotNull);
    expect(customSourceField.decoration!.labelText!, isNotEmpty);
    semanticsHandle.dispose();
  });
}
