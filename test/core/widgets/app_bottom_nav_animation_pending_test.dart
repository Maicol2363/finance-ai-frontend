import 'package:finance_ai/core/router/app_shell.dart';
import 'package:finance_ai/core/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Regression pendiente: AppBottomNav usa AnimatedContainer 250ms sin gate.
// No se toca lib/core/widgets/app_bottom_nav.dart por AGENTS (prohibido).
// Este test documenta la conducta actual y quedara en skip hasta el fix.
void main() {
  testWidgets('documenta AnimatedContainer sin gate disableAnimations', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            bottomNavigationBar: AppBottomNav(
              destinations: AppShell.destinations,
              currentIndex: 0,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    final ds = t
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .map((c) => c.duration)
        .toList();
    expect(ds, isNotEmpty);
    // Conducta actual sin gate: sigue 250ms aun con disableAnimations=true.
    for (final d in ds) {
      expect(d, const Duration(milliseconds: 250));
    }
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'PENDIENTE: gate Duration.zero con disableAnimations',
    (t) async {},
    skip: true, // Pendiente: app_bottom_nav.dart prohibido por AGENTS; aplicar MediaQuery.disableAnimationsOf gate.
  );
}
