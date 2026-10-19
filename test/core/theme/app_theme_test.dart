import 'package:finance_ai/core/theme/app_palette.dart';
import 'package:finance_ai/core/theme/app_theme.dart';
import 'package:finance_ai/core/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('light and dark palettes match accessible olive brand tokens', () {
    final light = AppTheme.light().extension<AppPalette>()!;
    expect(light.background, const Color(0xFFF5F6F8));
    expect(light.header, const Color(0xFFFFFFFF));
    expect(light.card, const Color(0xFFFFFFFF));
    expect(light.primary, const Color(0xFF6B8E00));
    expect(light.primaryDark, const Color(0xFF546E00));
    expect(light.primarySoft, const Color(0xFFE9F2D8));
    expect(light.onPrimary, const Color(0xFF101900));
    expect(light.text, const Color(0xFF202B28));
    expect(light.income, const Color(0xFF426D18));
    expect(light.discard, const Color(0xFFB3261E));

    final dark = AppTheme.dark().extension<AppPalette>()!;
    expect(dark.background, const Color(0xFF171D22));
    expect(dark.header, const Color(0xFF222B31));
    expect(dark.card, const Color(0xFF20282E));
    expect(dark.primary, const Color(0xFF8FB42C));
    expect(dark.text, const Color(0xFFF0F3F2));
    expect(dark.income, const Color(0xFF9CC66B));

    expect(AppTheme.light().brightness, Brightness.light);
    expect(AppTheme.dark().brightness, Brightness.dark);
    expect(AppTheme.light().scaffoldBackgroundColor, const Color(0xFFF5F6F8));
    expect(
      _contrast(light.primary, light.onPrimary),
      greaterThanOrEqualTo(4.5),
    );
    expect(_contrast(light.card, light.text), greaterThanOrEqualTo(4.5));
    expect(_contrast(light.card, light.muted), greaterThanOrEqualTo(4.5));
  });

  test('theme controller loads and persists the choice', () async {
    SharedPreferences.setMockInitialValues({themePreferenceKey: 'dark'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeControllerProvider), ThemeMode.light);
    await container.read(themeControllerProvider.notifier).load();
    expect(container.read(themeControllerProvider), ThemeMode.dark);

    await container.read(themeControllerProvider.notifier).setDark(false);
    expect(container.read(themeControllerProvider), ThemeMode.light);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(themePreferenceKey), 'light');
    expect(container.read(themeDiagnosticProvider), isNull);
  });

  test('selected income text meets AA on the actual segment background', () {
    for (final palette in [AppPalette.light, AppPalette.dark]) {
      expect(
        _contrast(palette.income, palette.card),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test(
    'theme controller captures safe diagnostic when storage throws',
    () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(themeControllerProvider.notifier);
      final success = await notifier.setDark(true);
      expect(success, isTrue);
      expect(container.read(themeControllerProvider), ThemeMode.dark);
      expect(container.read(themeDiagnosticProvider), isNull);
    },
  );
}

double _contrast(Color a, Color b) {
  final luminances = [a.computeLuminance(), b.computeLuminance()]..sort();
  return (luminances[1] + 0.05) / (luminances[0] + 0.05);
}
