import 'package:finance_ai/core/theme/app_theme.dart';
import 'package:finance_ai/core/widgets/manage_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

    testWidgets('SegmentedControl renders labels with InkWell and triggers onChanged', (
      tester,
    ) async {
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SegmentedControl(
              keyPrefix: 'theme',
              labels: const ['Claro', 'Oscuro'],
              selectedIndex: 0,
              onChanged: (index) => selected = index,
            ),
          ),
        ),
      );

      expect(find.text('Claro'), findsOneWidget);
      expect(find.text('Oscuro'), findsOneWidget);
      expect(find.byType(InkWell), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('theme-1')));
      expect(selected, equals(1));
    });
  });
}
