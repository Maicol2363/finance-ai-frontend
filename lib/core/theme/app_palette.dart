import 'package:flutter/material.dart';

/// Shared brand and semantic color tokens for the app's light and dark themes.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.header,
    required this.card,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.primaryDark,
    required this.income,
    required this.incomeSoft,
    required this.text,
    required this.muted,
    required this.line,
    required this.confirm,
    required this.discard,
    required this.errorSoft,
    required this.nav,
    required this.soft,
    required this.soft2,
    required this.rowLine,
    required this.warnBg,
    required this.warnFg,
    required this.placeholder,
  });

  final Color background;
  final Color header;
  final Color card;
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color primaryDark;
  final Color income;
  final Color incomeSoft;
  final Color text;
  final Color muted;
  final Color line;
  final Color confirm;
  final Color discard;
  final Color errorSoft;
  final Color nav;
  final Color soft;
  final Color soft2;
  final Color rowLine;
  final Color warnBg;
  final Color warnFg;
  final Color placeholder;

  /// Olive brand with restrained neutral surfaces.
  static const light = AppPalette(
    background: Color(0xFFF5F6F8),
    header: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    // P3 a11y: primary 3.82:1 sobre blanco solo para texto grande/componentes
    // (≥3:1). Textos normales deben usar primaryDark/income (≥4.5:1).
    primary: Color(0xFF6B8E00),
    onPrimary: Color(0xFF101900),
    primarySoft: Color(0xFFE9F2D8),
    primaryDark: Color(0xFF546E00),
    income: Color(0xFF426D18),
    incomeSoft: Color(0xFFE9F2D8),
    text: Color(0xFF202B28),
    muted: Color(0xFF5E6860),
    line: Color(0xFFE1E5DC),
    confirm: Color(0xFF426D18),
    discard: Color(0xFFB3261E),
    errorSoft: Color(0xFFFFEFEE),
    nav: Color(0xFF5E6860),
    soft: Color(0xFFF0F3EA),
    soft2: Color(0xFFFAFBF9),
    rowLine: Color(0xFFF0F2EC),
    warnBg: Color(0xFFFFF4DA),
    warnFg: Color(0xFF8A6900),
    // P3 a11y: placeholder oscurecido a 5.99:1 sobre blanco (≥4.5 texto normal).
    placeholder: Color(0xFF5B665E),
  );

  /// Dark counterpart with accessible olive highlights.
  static const dark = AppPalette(
    background: Color(0xFF171D22),
    header: Color(0xFF222B31),
    card: Color(0xFF20282E),
    primary: Color(0xFF8FB42C),
    onPrimary: Color(0xFF171D22),
    primarySoft: Color(0xFF354220),
    primaryDark: Color(0xFFB4D875),
    income: Color(0xFF9CC66B),
    incomeSoft: Color(0xFF293720),
    text: Color(0xFFF0F3F2),
    muted: Color(0xFFADB8B4),
    line: Color(0xFF303A40),
    confirm: Color(0xFF9CC66B),
    discard: Color(0xFFFF8A80),
    errorSoft: Color(0xFF351D20),
    nav: Color(0xFFADB8B4),
    soft: Color(0xFF293238),
    soft2: Color(0xFF242D33),
    rowLine: Color(0xFF2A3339),
    warnBg: Color(0xFF382F18),
    warnFg: Color(0xFFE8CC74),
    placeholder: Color(0xFF87938E),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? header,
    Color? card,
    Color? primary,
    Color? onPrimary,
    Color? primarySoft,
    Color? primaryDark,
    Color? income,
    Color? incomeSoft,
    Color? text,
    Color? muted,
    Color? line,
    Color? confirm,
    Color? discard,
    Color? errorSoft,
    Color? nav,
    Color? soft,
    Color? soft2,
    Color? rowLine,
    Color? warnBg,
    Color? warnFg,
    Color? placeholder,
  }) {
    return AppPalette(
      background: background ?? this.background,
      header: header ?? this.header,
      card: card ?? this.card,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primarySoft: primarySoft ?? this.primarySoft,
      primaryDark: primaryDark ?? this.primaryDark,
      income: income ?? this.income,
      incomeSoft: incomeSoft ?? this.incomeSoft,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      confirm: confirm ?? this.confirm,
      discard: discard ?? this.discard,
      errorSoft: errorSoft ?? this.errorSoft,
      nav: nav ?? this.nav,
      soft: soft ?? this.soft,
      soft2: soft2 ?? this.soft2,
      rowLine: rowLine ?? this.rowLine,
      warnBg: warnBg ?? this.warnBg,
      warnFg: warnFg ?? this.warnFg,
      placeholder: placeholder ?? this.placeholder,
    );
  }

  @override
  AppPalette lerp(covariant ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) {
      return this;
    }
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? b;
    return AppPalette(
      background: mix(background, other.background),
      header: mix(header, other.header),
      card: mix(card, other.card),
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      primarySoft: mix(primarySoft, other.primarySoft),
      primaryDark: mix(primaryDark, other.primaryDark),
      income: mix(income, other.income),
      incomeSoft: mix(incomeSoft, other.incomeSoft),
      text: mix(text, other.text),
      muted: mix(muted, other.muted),
      line: mix(line, other.line),
      confirm: mix(confirm, other.confirm),
      discard: mix(discard, other.discard),
      errorSoft: mix(errorSoft, other.errorSoft),
      nav: mix(nav, other.nav),
      soft: mix(soft, other.soft),
      soft2: mix(soft2, other.soft2),
      rowLine: mix(rowLine, other.rowLine),
      warnBg: mix(warnBg, other.warnBg),
      warnFg: mix(warnFg, other.warnFg),
      placeholder: mix(placeholder, other.placeholder),
    );
  }
}

extension AppPaletteContext on BuildContext {
  /// Mockup palette for the current brightness.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
