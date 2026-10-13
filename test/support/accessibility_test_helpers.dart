import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

export 'dart:ui' show Tristate;

export 'package:flutter/rendering.dart' show SemanticsFlag, SemanticsAction;

/// Extension on [SemanticsNode] to support `.hasAction(SemanticsAction)` in tests.
extension SemanticsNodeActionExtension on SemanticsNode {
  bool hasAction(SemanticsAction action) =>
      getSemanticsData().hasAction(action);
}

/// Calculates the sRGB relative luminance of a color according to WCAG 2.1 specs.
/// Value ranges from 0.0 (pure black) to 1.0 (pure white).
double calculateRelativeLuminance(Color color) {
  double linearize(double channel) {
    return channel <= 0.04045
        ? channel / 12.92
        : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = linearize(color.r);
  final g = linearize(color.g);
  final b = linearize(color.b);

  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Calculates the contrast ratio between two colors according to WCAG 2.1.
/// Value ranges from 1.0 (identical) to 21.0 (black on white).
double calculateContrastRatio(Color color1, Color color2) {
  final l1 = calculateRelativeLuminance(color1);
  final l2 = calculateRelativeLuminance(color2);

  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);

  return (lighter + 0.05) / (darker + 0.05);
}

/// Asserts that the contrast ratio between [foreground] and [background]
/// meets or exceeds [minRatio] (default: 4.5 for standard text; 3.0 for large text).
void expectContrastRatio(
  Color foreground,
  Color background, {
  double minRatio = 4.5,
  String? reason,
}) {
  final ratio = calculateContrastRatio(foreground, background);
  expect(
    ratio,
    greaterThanOrEqualTo(minRatio),
    reason:
        reason ??
        'Expected contrast ratio >= ${minRatio.toStringAsFixed(1)}:1, '
            'but got ${ratio.toStringAsFixed(2)}:1 between '
            'foreground $foreground and background $background.',
  );
}

/// Asserts that each widget found by [finder] meets the minimum recommended
/// touch target dimensions of [minWidth] x [minHeight] dp (default 48x48 dp).
void expectMinTouchTarget(
  WidgetTester tester,
  Finder finder, {
  double minWidth = 48.0,
  double minHeight = 48.0,
  String? reason,
}) {
  expect(
    finder,
    findsAtLeastNWidgets(1),
    reason: 'No widgets found for touch target verification.',
  );
  final elements = finder.evaluate();
  for (final element in elements) {
    final size = tester.getSize(find.byElementPredicate((e) => e == element));
    expect(
      size.width,
      greaterThanOrEqualTo(minWidth),
      reason:
          reason ??
          'Widget width ${size.width} is smaller than required minimum touch target width $minWidth.',
    );
    expect(
      size.height,
      greaterThanOrEqualTo(minHeight),
      reason:
          reason ??
          'Widget height ${size.height} is smaller than required minimum touch target height $minHeight.',
    );
  }
}

/// Asserts that a widget found by [finder] has an accessible semantic name
/// (label or tooltip) that is non-empty, and optionally matches [expectedName].
void expectAccessibleName(
  WidgetTester tester,
  Finder finder, {
  String? expectedName,
  String? reason,
}) {
  expect(
    finder,
    findsAtLeastNWidgets(1),
    reason: 'No widgets found for accessible name verification.',
  );
  final semantics = tester.getSemantics(finder);
  final label = semantics.label;
  final tooltip = semantics.tooltip;
  final hasName = label.isNotEmpty || tooltip.isNotEmpty;

  expect(
    hasName,
    isTrue,
    reason:
        reason ?? 'Widget does not have a non-empty semantic label or tooltip.',
  );

  if (expectedName != null) {
    final matches =
        label == expectedName ||
        tooltip == expectedName ||
        label.contains(expectedName);
    expect(
      matches,
      isTrue,
      reason:
          reason ??
          'Expected semantic name "$expectedName", but got label "$label" and tooltip "$tooltip".',
    );
  }
}
