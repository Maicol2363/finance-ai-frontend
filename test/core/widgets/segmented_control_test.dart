import 'package:finance_ai/core/theme/app_theme.dart';
import 'package:finance_ai/core/widgets/manage_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'SegmentedControl renders labels, reports selection state, and triggers callback on tap',
    (tester) async {
      int selected = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SegmentedControl(
                  keyPrefix: 'theme-seg',
                  labels: const ['Claro', 'Oscuro'],
                  selectedIndex: selected,
                  onChanged: (index) {
                    setState(() {
                      selected = index;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Claro'), findsOneWidget);
      expect(find.text('Oscuro'), findsOneWidget);

      expect(
        tester.getSemantics(find.text('Claro')),
        matchesSemantics(
          label: 'Claro',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );

      expect(
        tester.getSemantics(find.text('Oscuro')),
        matchesSemantics(
          label: 'Oscuro',
          isButton: true,
          isSelected: false,
          hasSelectedState: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );

      await tester.tap(find.byKey(const Key('theme-seg-1')));
      await tester.pumpAndSettle();

      expect(selected, 1);
      expect(
        tester.getSemantics(find.text('Oscuro')),
        matchesSemantics(
          label: 'Oscuro',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
    },
  );
}
