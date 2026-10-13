import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:finance_ai/core/router/app_shell.dart';
import 'package:finance_ai/core/theme/app_palette.dart';
import 'package:finance_ai/core/theme/app_theme.dart';
import 'package:finance_ai/core/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/accessibility_test_helpers.dart';

void main() {
  testWidgets('bottom nav renders both tabs and reports the tapped index', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    final taps = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(
            destinations: AppShell.destinations,
            currentIndex: 0,
            onSelected: taps.add,
          ),
        ),
      ),
    );

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Movimientos'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.bySemanticsLabel('Inicio'), findsOneWidget);
    expect(find.bySemanticsLabel('Movimientos'), findsOneWidget);
    expect(find.bySemanticsLabel('Ajustes'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Inicio'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Inicio'))
          .hasAction(SemanticsAction.tap),
      isTrue,
    );

    final activeIcon = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.byIcon(FinanceIcons.homeOutlined),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    expect(
      (activeIcon.decoration as BoxDecoration).color,
      AppPalette.light.primarySoft,
    );

    await tester.tap(find.byKey(const Key('bottom-nav-movimientos')));
    expect(taps, [1]);

    await tester.tap(find.byKey(const Key('bottom-nav-ajustes')));
    expect(taps, [1, 2]);
  });
}
