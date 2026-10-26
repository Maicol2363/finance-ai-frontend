import 'package:finance_ai/core/theme/app_theme.dart';
import 'package:finance_ai/features/text_capture/presentation/widgets/capture_wheel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

Future<SemanticsHandle> pumpWheel(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: CaptureWheel(onPhoto: () {}, onAi: () {}, onManual: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return handle;
}

void main() {
  testWidgets('bubbles y scrim exponen tap action', (tester) async {
    final handle = await pumpWheel(tester);
    await tester.tap(find.byKey(const Key('expenses-create-fab')));
    await tester.pumpAndSettle();

    // Las burbujas exponen su nombre por etiqueta semantica (la Key
    // esta en el widget contenedor, no en el nodo semantico).
    for (final label in [
      'Foto de un recibo',
      'Escribir o dictar',
      'Formulario manual',
    ]) {
      final node = tester.getSemantics(find.bySemanticsLabel(label));
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
        reason: '$label debe exponer tap action',
      );
    }
    // El scrim lleva la Key en el InkWell, que expone tap directo.
    final scrim = tester.getSemantics(
      find.byKey(const Key('expenses-wheel-scrim')),
    );
    expect(
      scrim.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
      reason: 'expenses-wheel-scrim debe exponer tap action',
    );
    handle.dispose();
  });

  testWidgets('abrir mueve el foco a la primera opcion', (tester) async {
    final handle = await pumpWheel(tester);
    await tester.tap(find.byKey(const Key('expenses-create-fab')));
    await tester.pumpAndSettle();

    final scope = FocusScope.of(
      tester.element(find.byKey(const Key('expenses-wheel-photo'))),
    );
    expect(scope.focusedChild?.debugLabel, 'capture-wheel-first');
    handle.dispose();
  });

  testWidgets('cerrar por scrim retorna el foco al FAB', (tester) async {
    final handle = await pumpWheel(tester);
    await tester.tap(find.byKey(const Key('expenses-create-fab')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('expenses-wheel-scrim')));
    await tester.pumpAndSettle();

    final scope = FocusScope.of(
      tester.element(find.byKey(const Key('expenses-create-fab'))),
    );
    expect(scope.focusedChild?.debugLabel, 'capture-wheel-fab');
    expect(find.byKey(const Key('expenses-wheel-photo')), findsNothing);
    handle.dispose();
  });
}
