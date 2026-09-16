import 'package:finance_ai/core/theme/app_theme.dart';
import 'package:finance_ai/core/widgets/app_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppHeader', () {
    testWidgets('renders title, subtitle, leading, and actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: AppHeader(
              title: 'Título de prueba',
              subtitle: 'Subtítulo de prueba',
              leading: Icon(Icons.arrow_back),
              actions: [Icon(Icons.more_vert)],
            ),
          ),
        ),
      );

      expect(find.text('Título de prueba'), findsOneWidget);
      expect(find.text('Subtítulo de prueba'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });
  });

  group('HeaderIconButton', () {
    testWidgets('renders tooltip, semantics, icon, and handles tap when enabled', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: HeaderIconButton(
              icon: Icons.close,
              tooltip: 'Cerrar',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byTooltip('Cerrar'), findsOneWidget);
      expect(find.bySemanticsLabel('Cerrar'), findsWidgets);

      await tester.tap(find.byType(HeaderIconButton));
      expect(tapped, isTrue);
    });

    testWidgets('renders disabled state when onPressed is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: HeaderIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Volver',
              onPressed: null,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byTooltip('Volver'), findsOneWidget);
      expect(find.bySemanticsLabel('Volver'), findsWidgets);
    });
  });
}
