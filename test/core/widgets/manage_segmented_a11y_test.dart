import 'package:finance_ai/core/theme/app_theme.dart';
import 'package:finance_ai/core/widgets/manage_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/accessibility_test_helpers.dart';

Widget h(Widget c, {double s = 1, bool d = false}) => MaterialApp(
  theme: AppTheme.light(),
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(s),
      disableAnimations: d,
    ),
    child: Scaffold(body: c),
  ),
);

void main() {
  testWidgets('segmented: button+selected, tap, 48x48', (t) async {
    final s = t.ensureSemantics();
    int? v;
    await t.pumpWidget(
      h(
        SegmentedControl(
          labels: const ['Claro', 'Oscuro'],
          selectedIndex: 1,
          keyPrefix: 'seg',
          onChanged: (x) => v = x,
        ),
      ),
    );
    expect(find.bySemanticsLabel('Claro'), findsOneWidget);
    expect(
      t
          .getSemantics(find.bySemanticsLabel('Oscuro'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(
      t
          .getSemantics(find.bySemanticsLabel('Claro'))
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    expectMinTouchTarget(t, find.byKey(const Key('seg-0')));
    expectMinTouchTarget(t, find.byKey(const Key('seg-1')));
    await t.tap(find.byKey(const Key('seg-0')));
    expect(v, 0);
    expect(t.takeException(), isNull);
    s.dispose();
  });
  testWidgets('segmented: teclado y foco visible', (t) async {
    int? v;
    await t.pumpWidget(
      h(
        SegmentedControl(
          labels: const ['Claro', 'Oscuro'],
          selectedIndex: 1,
          keyPrefix: 'seg',
          onChanged: (x) => v = x,
        ),
      ),
    );
    for (final w in t.widgetList<InkWell>(find.byType(InkWell))) {
      expect(w.focusColor, isNot(equals(Colors.transparent)));
    }
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(v, isNotNull);
    expect(t.takeException(), isNull);
  });
  testWidgets('segmented: sin anim y scaler 2 sin overflow', (t) async {
    await t.pumpWidget(
      h(
        SegmentedControl(
          labels: const ['Claro', 'Oscuro'],
          selectedIndex: 0,
          keyPrefix: 'seg',
          onChanged: (_) {},
        ),
        d: true,
      ),
    );
    for (final c in t.widgetList<AnimatedContainer>(
      find.byType(AnimatedContainer),
    )) {
      expect(c.duration, Duration.zero);
    }
    await t.pumpWidget(
      h(
        SegmentedControl(
          labels: const ['Claro', 'Oscuro'],
          selectedIndex: 0,
          keyPrefix: 'seg',
          onChanged: (_) {},
        ),
        s: 2,
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets('chips: button+selected, tap, 48x48, gates', (t) async {
    final s = t.ensureSemantics();
    String? v;
    FilterChipRow<String> chips(String sel) => FilterChipRow<String>(
      options: const [
        FilterChipOption(value: 'all', label: 'Todos'),
        FilterChipOption(value: 'month', label: 'Este mes'),
      ],
      selected: sel,
      keyPrefix: 'chip',
      onChanged: (x) => v = x,
    );
    await t.pumpWidget(h(chips('month')));
    expect(find.bySemanticsLabel('Todos'), findsOneWidget);
    expect(
      t
          .getSemantics(find.bySemanticsLabel('Este mes'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(
      t
          .getSemantics(find.bySemanticsLabel('Todos'))
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    expectMinTouchTarget(t, find.byKey(const Key('chip-0')));
    await t.tap(find.byKey(const Key('chip-0')));
    expect(v, 'all');
    await t.pumpWidget(h(chips('all'), d: true));
    for (final c in t.widgetList<AnimatedContainer>(
      find.byType(AnimatedContainer),
    )) {
      expect(c.duration, Duration.zero);
    }
    await t.pumpWidget(h(chips('all'), s: 2));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    s.dispose();
  });
}
