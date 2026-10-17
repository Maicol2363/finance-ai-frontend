import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Material themes built from the mockup palette (`docs/mockups/index.html`).
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(AppPalette.light, Brightness.light);

  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      primaryContainer: p.primarySoft,
      onPrimaryContainer: p.text,
      secondary: p.income,
      onSecondary: p.onPrimary,
      secondaryContainer: p.primarySoft,
      onSecondaryContainer: p.primary,
      error: p.discard,
      onError: p.onPrimary,
      errorContainer: p.errorSoft,
      onErrorContainer: p.discard,
      surface: p.card,
      onSurface: p.text,
      onSurfaceVariant: p.muted,
      surfaceContainerLowest: p.background,
      surfaceContainerLow: p.soft2,
      surfaceContainer: p.soft,
      surfaceContainerHigh: p.soft,
      surfaceContainerHighest: p.soft,
      outline: p.line,
      outlineVariant: p.rowLine,
      shadow: const Color(0x1A0F172A),
      scrim: const Color(0x730F172A),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );

    OutlineInputBorder border(Color color, double radius, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return base.copyWith(
      scaffoldBackgroundColor: p.background,
      extensions: <ThemeExtension<dynamic>>[p],
      appBarTheme: AppBarTheme(
        backgroundColor: p.header,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: p.text),
        titleTextStyle: TextStyle(
          color: p.text,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: p.line),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.rowLine, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: p.muted),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: border(p.line, 12),
        enabledBorder: border(p.line, 12),
        focusedBorder: border(p.primary, 12, 1.6),
        errorBorder: border(p.discard, 12),
        focusedErrorBorder: border(p.discard, 12, 1.6),
        labelStyle: TextStyle(color: p.muted, fontSize: 13),
        hintStyle: TextStyle(color: p.placeholder, fontSize: 13.5),
        floatingLabelStyle: TextStyle(color: p.primary, fontSize: 13),
        errorStyle: TextStyle(color: p.discard, fontSize: 11.5),
        alignLabelWithHint: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.soft,
          disabledForegroundColor: p.nav,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: p.primary,
          side: BorderSide(color: p.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary),
      drawerTheme: DrawerThemeData(backgroundColor: p.background),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: TextStyle(
          color: p.text,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: p.muted, fontSize: 13, height: 1.5),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.card,
        contentTextStyle: TextStyle(color: p.text, fontSize: 13),
        behavior: SnackBarBehavior.floating,
      ),
      textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
    );
  }
}
