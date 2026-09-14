import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../diagnostics/error_diagnostic.dart';

/// Preference key mirroring the mockup's `finance-mock-theme`.
const themePreferenceKey = 'finance_ai.theme_mode';

/// Holds copyable diagnostics when theme persistence fails.
final themeDiagnosticProvider =
    NotifierProvider<ThemeDiagnosticNotifier, ErrorDiagnostic?>(
      ThemeDiagnosticNotifier.new,
    );

class ThemeDiagnosticNotifier extends Notifier<ErrorDiagnostic?> {
  @override
  ErrorDiagnostic? build() => null;

  void set(ErrorDiagnostic? diagnostic) => state = diagnostic;
  void clear() => state = null;
}

/// Holds the light/dark choice and persists it locally.
class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final stored = preferences.getString(themePreferenceKey);
      if (stored == 'dark') {
        state = ThemeMode.dark;
      } else if (stored == 'light') {
        state = ThemeMode.light;
      }
    } catch (error) {
      ref
          .read(themeDiagnosticProvider.notifier)
          .set(
            ErrorDiagnostic.capture(
              code: 'theme_load_failed',
              operation: 'load_theme_mode',
              userMessage: 'No se pudo cargar la preferencia de tema.',
              technicalReason: error.toString(),
            ),
          );
    }
  }

  Future<void> toggle() => setDark(state != ThemeMode.dark);

  Future<bool> setDark(bool dark) async {
    final previous = state;
    state = dark ? ThemeMode.dark : ThemeMode.light;
    try {
      final preferences = await SharedPreferences.getInstance();
      final success = await preferences.setString(
        themePreferenceKey,
        dark ? 'dark' : 'light',
      );
      if (!success) {
        state = previous;
        ref
            .read(themeDiagnosticProvider.notifier)
            .set(
              ErrorDiagnostic.capture(
                code: 'theme_write_failed',
                operation: 'persist_theme_mode',
                userMessage: 'No se pudo guardar la preferencia de tema.',
                technicalReason: 'shared_preferences_set_string_failed',
              ),
            );
        return false;
      }
      ref.read(themeDiagnosticProvider.notifier).clear();
      return true;
    } catch (error) {
      state = previous;
      ref
          .read(themeDiagnosticProvider.notifier)
          .set(
            ErrorDiagnostic.capture(
              code: 'theme_storage_unavailable',
              operation: 'persist_theme_mode',
              userMessage: 'No se pudo guardar la preferencia de tema.',
              technicalReason: error.toString(),
            ),
          );
      return false;
    }
  }
}

final themeControllerProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);
