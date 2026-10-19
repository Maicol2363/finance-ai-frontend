import 'package:finance_ai/core/theme/app_theme.dart';
import 'package:finance_ai/core/widgets/manage_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/accessibility_test_helpers.dart';

void main() {
  group('DashedRoundedBorderPainter', () {
    test('shouldRepaint returns true when any property changes', () {
      const painter = DashedRoundedBorderPainter(
        color: Colors.blue,
        radius: 12,
        dashLength: 6,
        gapLength: 4,
        strokeWidth: 1.5,
      );

      expect(
        painter.shouldRepaint(
          const DashedRoundedBorderPainter(
            color: Colors.blue,
            radius: 12,
            dashLength: 6,
            gapLength: 4,
            strokeWidth: 1.5,
          ),
        ),
        isFalse,
      );

      expect(
        painter.shouldRepaint(
          const DashedRoundedBorderPainter(
            color: Colors.red,
            radius: 12,
            dashLength: 6,
            gapLength: 4,
            strokeWidth: 1.5,
          ),
        ),
        isTrue,
      );

      expect(
        painter.shouldRepaint(
          const DashedRoundedBorderPainter(
            color: Colors.blue,
            radius: 8,
            dashLength: 6,
            gapLength: 4,
            strokeWidth: 1.5,
          ),
        ),
        isTrue,
      );

      expect(
        painter.shouldRepaint(
          const DashedRoundedBorderPainter(
            color: Colors.blue,
            radius: 12,
            dashLength: 8,
            gapLength: 4,
            strokeWidth: 1.5,
          ),
        ),
        isTrue,
      );

      expect(
        painter.shouldRepaint(
          const DashedRoundedBorderPainter(
            color: Colors.blue,
            radius: 12,
            dashLength: 6,
            gapLength: 6,
            strokeWidth: 1.5,
          ),
        ),
        isTrue,
      );

      expect(
        painter.shouldRepaint(
          const DashedRoundedBorderPainter(
            color: Colors.blue,
            radius: 12,
            dashLength: 6,
            gapLength: 4,
            strokeWidth: 2.0,
          ),
        ),
        isTrue,
      );
    });

    testWidgets('CatalogAddButton renders and paints custom dashed border', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CatalogAddButton(
              label: 'Test Add',
              hint: 'Optional hint',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Test Add'), findsOneWidget);
      expect(find.text('Optional hint'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.tap(find.text('Test Add'));
      expect(tapped, isTrue);
    });
  });

  testWidgets('selection controls expose 48dp targets and unique semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    int? chosenSegment;
    String? chosenFilter;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedControl(
                labels: const ['Claro', 'Oscuro'],
                selectedIndex: 1,
                keyPrefix: 'theme-option',
                onChanged: (value) => chosenSegment = value,
              ),
              FilterChipRow<String>(
                options: const [
                  FilterChipOption(value: 'all', label: 'Todos'),
                  FilterChipOption(value: 'month', label: 'Este mes'),
                ],
                selected: 'month',
                keyPrefix: 'period-option',
                onChanged: (value) => chosenFilter = value,
              ),
            ],
          ),
        ),
      ),
    );

    for (final key in [
      'theme-option-0',
      'theme-option-1',
      'period-option-0',
      'period-option-1',
    ]) {
      expectMinTouchTarget(tester, find.byKey(Key(key)));
    }

    expect(find.bySemanticsLabel('Claro'), findsOneWidget);
    expect(find.bySemanticsLabel('Oscuro'), findsOneWidget);
    expect(find.bySemanticsLabel('Todos'), findsOneWidget);
    expect(find.bySemanticsLabel('Este mes'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Oscuro'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Este mes'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Oscuro'))
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('theme-option-0')));
    await tester.tap(find.byKey(const Key('period-option-0')));
    expect(chosenSegment, 0);
    expect(chosenFilter, 'all');
    semantics.dispose();
  });

  testWidgets('SettingsRow exposes one action and hides its chevron', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SettingsRow(
            label: 'Cuentas y saldos',
            subtitle: 'Administrar cuentas',
            rowKey: const Key('settings-test-row'),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    final row = find.byKey(const Key('settings-test-row'));
    expectMinTouchTarget(tester, row);
    expect(tester.getSemantics(row).hasAction(SemanticsAction.tap), isTrue);
    expect(find.bySemanticsLabel(RegExp('Cuentas y saldos')), findsOneWidget);
    await tester.tap(row);
    expect(tapped, isTrue);
    semantics.dispose();
  });
}
