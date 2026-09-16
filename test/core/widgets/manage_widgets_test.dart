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
  });

  group('ManageActionButton', () {
    testWidgets('renders with 1.0 opacity when enabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ManageActionButton(
              icon: Icons.edit,
              tooltip: 'Edit item',
              onPressed: () {},
            ),
          ),
        ),
      );

      final opacityWidget = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(ManageActionButton),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacityWidget.opacity, equals(1.0));
    });

    testWidgets('renders with 0.5 opacity when disabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: const ManageActionButton(
              icon: Icons.edit,
              tooltip: 'Edit item',
              onPressed: null,
            ),
          ),
        ),
      );

      final opacityWidget = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(ManageActionButton),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacityWidget.opacity, equals(0.5));
    });
  });
}
