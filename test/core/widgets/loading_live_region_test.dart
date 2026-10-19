import 'package:finance_ai/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: child),
);

Future<void> _expectLoadingLiveRegion(
  WidgetTester tester,
  Widget Function() builder,
) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(_host(builder()));
  await tester.pump();

  final indicator = find.byType(CircularProgressIndicator);
  expect(indicator, findsOneWidget);

  final semantics = tester.getSemantics(indicator);
  expect(semantics.label, 'Cargando…');
  expect(semantics.flagsCollection.isLiveRegion, isTrue);
  expect(tester.takeException(), isNull);
  handle.dispose();
}

void main() {
  testWidgets('loading liveRegion en patrones base (cuentas/categorias)', (
    tester,
  ) async {
    // Replica exacta del patron aplicado (Semantics liveRegion + spinner).
    await _expectLoadingLiveRegion(
      tester,
      () => Semantics(
        label: 'Cargando…',
        liveRegion: true,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  });

  testWidgets('loading liveRegion en patrones base (hub/movimientos)', (
    tester,
  ) async {
    await _expectLoadingLiveRegion(
      tester,
      () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Semantics(
          label: 'Cargando…',
          liveRegion: true,
          child: const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  });
}
