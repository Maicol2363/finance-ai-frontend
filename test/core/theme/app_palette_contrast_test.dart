import 'package:finance_ai/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _lin(double c) =>
    c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) * ((c + 0.055) / 1.055);
double _lum(Color c) =>
    0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);
double _ratio(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const white = Color(0xFFFFFFFF);
  group('P3 palette contrast (WCAG)', () {
    test('placeholder light >= 4.5 sobre blanco', () {
      expect(
        _ratio(AppPalette.light.placeholder, white),
        greaterThanOrEqualTo(4.5),
      );
    });
    test('primaryDark e income light >= 4.5 (texto normal)', () {
      expect(
        _ratio(AppPalette.light.primaryDark, white),
        greaterThanOrEqualTo(4.5),
      );
      expect(_ratio(AppPalette.light.income, white), greaterThanOrEqualTo(4.5));
    });
    test('primary light >= 3.0 (solo texto grande/componentes)', () {
      expect(
        _ratio(AppPalette.light.primary, white),
        greaterThanOrEqualTo(3.0),
      );
    });
  });
}
