import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'accessibility_test_helpers.dart';

void main() {
  group('calculateRelativeLuminance', () {
    test('pure white has luminance 1.0', () {
      expect(
        calculateRelativeLuminance(const Color(0xFFFFFFFF)),
        closeTo(1.0, 0.001),
      );
    });

    test('pure black has luminance 0.0', () {
      expect(
        calculateRelativeLuminance(const Color(0xFF000000)),
        closeTo(0.0, 0.001),
      );
    });
  });

  group('calculateContrastRatio & expectContrastRatio', () {
    test('black on white yields 21.0:1', () {
      final ratio = calculateContrastRatio(
        const Color(0xFF000000),
        const Color(0xFFFFFFFF),
      );
      expect(ratio, closeTo(21.0, 0.1));
      expectContrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF));
    });

    test('white on black yields 21.0:1 (order independent)', () {
      final ratio = calculateContrastRatio(
        const Color(0xFFFFFFFF),
        const Color(0xFF000000),
      );
      expect(ratio, closeTo(21.0, 0.1));
      expectContrastRatio(const Color(0xFFFFFFFF), const Color(0xFF000000));
    });

    test('identical colors yield 1.0:1', () {
      final ratio = calculateContrastRatio(
        const Color(0xFF2E7D32),
        const Color(0xFF2E7D32),
      );
      expect(ratio, closeTo(1.0, 0.01));
    });

    test('fails assertion with informative error when below threshold', () {
      expect(
        () => expectContrastRatio(
          const Color(0xFFCCCCCC),
          const Color(0xFFFFFFFF),
          minRatio: 4.5,
        ),
        throwsA(isA<TestFailure>()),
      );
    });
  });

  group('expectMinTouchTarget', () {
    testWidgets('passes for element >= 48x48', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(key: Key('large-button'), width: 50, height: 50),
          ),
        ),
      );
      expectMinTouchTarget(tester, find.byKey(const Key('large-button')));
    });

    testWidgets('throws TestFailure for element < 48x48', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(key: Key('small-button'), width: 30, height: 30),
          ),
        ),
      );
      expect(
        () =>
            expectMinTouchTarget(tester, find.byKey(const Key('small-button'))),
        throwsA(isA<TestFailure>()),
      );
    });
  });

  group('expectAccessibleName', () {
    testWidgets('passes for element with semantic label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Semantics(
              label: 'Guardar cambios',
              child: SizedBox(key: Key('named-button'), width: 48, height: 48),
            ),
          ),
        ),
      );
      expectAccessibleName(
        tester,
        find.byKey(const Key('named-button')),
        expectedName: 'Guardar cambios',
      );
    });

    testWidgets('passes for element with tooltip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Tooltip(
              message: 'Ayuda',
              child: SizedBox(
                key: Key('tooltip-button'),
                width: 48,
                height: 48,
              ),
            ),
          ),
        ),
      );
      expectAccessibleName(
        tester,
        find.byKey(const Key('tooltip-button')),
        expectedName: 'Ayuda',
      );
    });

    testWidgets('throws TestFailure for element without accessible name', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(key: Key('unnamed-button'), width: 48, height: 48),
          ),
        ),
      );
      expect(
        () => expectAccessibleName(
          tester,
          find.byKey(const Key('unnamed-button')),
        ),
        throwsA(isA<TestFailure>()),
      );
    });
  });
}
