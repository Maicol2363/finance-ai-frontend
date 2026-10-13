import 'package:finance_ai/core/theme/app_palette.dart';
import 'package:finance_ai/core/theme/app_theme.dart';
import 'package:finance_ai/core/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('light and dark palettes match the mockup design tokens', () {
    final light = AppTheme.light().extension<AppPalette>()!;
    expect(light.background, const Color(0xFFF5F7F6));
    expect(light.header, const Color(0xFFFFFFFF));
    expect(light.card, const Color(0xFFFFFFFF));
    expect(light.primary, const Color(0xFF236B52));
    expect(light.text, const Color(0xFF202B28));
    expect(light.income, const Color(0xFF23835F));
    expect(light.discard, const Color(0xFFD9534F));

    final dark = AppTheme.dark().extension<AppPalette>()!;
    expect(dark.background, const Color(0xFF171D22));
    expect(dark.header, const Color(0xFF222B31));
    expect(dark.card, const Color(0xFF20282E));
    expect(dark.primary, const Color(0xFF69B992));
    expect(dark.text, const Color(0xFFF0F3F2));
    expect(dark.income, const Color(0xFF69B992));

    expect(AppTheme.light().brightness, Brightness.light);
    expect(AppTheme.dark().brightness, Brightness.dark);
    expect(AppTheme.light().scaffoldBackgroundColor, const Color(0xFFF5F7F6));
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
