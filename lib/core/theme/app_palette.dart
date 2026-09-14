import 'package:flutter/material.dart';

/// Design tokens mirrored from `docs/mockups/index.html`
/// (light + dark palettes) so the Flutter UI matches the mockup.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
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

  /// `docs/mockups/index.html` -> `:root`
  static const light = AppPalette(
    background: Color(0xFFF5F6F8),
    card: Color(0xFFFFFFFF),
    primary: Color(0xFF6B8E00),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFE9F2D8),
    primaryDark: Color(0xFF546E00),
    income: Color(0xFF0E9F6E),
    incomeSoft: Color(0xFFE1F5EC),
    text: Color(0xFF1F2933),
    muted: Color(0xFF6B7280),
    line: Color(0xFFE5E7EB),
    confirm: Color(0xFF16A34A),
    discard: Color(0xFFDC2626),
    errorSoft: Color(0xFFFDECEC),
    nav: Color(0xFF9CA3AF),
    soft: Color(0xFFF3F4F6),
    soft2: Color(0xFFFAFAFB),
    rowLine: Color(0xFFF3F4F6),
    warnBg: Color(0xFFFDF3D8),
    warnFg: Color(0xFF9A7B00),
    placeholder: Color(0xFF9AA0A6),
  );

  /// `docs/mockups/index.html` -> `:root[data-theme="dark"]`
  static const dark = AppPalette(
    background: Color(0xFF101318),
    card: Color(0xFF1A2027),
    primary: Color(0xFF8FB42C),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFF26301A),
    primaryDark: Color(0xFFB7D45C),
    income: Color(0xFF2DB886),
    incomeSoft: Color(0xFF143129),
    text: Color(0xFFE8EBF0),
    muted: Color(0xFF9AA5B5),
    line: Color(0xFF262E38),
    confirm: Color(0xFF1FA254),
    discard: Color(0xFFE5534D),
    errorSoft: Color(0xFF351D20),
    nav: Color(0xFF5A6472),
    soft: Color(0xFF20262E),
    soft2: Color(0xFF232A33),
    rowLine: Color(0xFF1F262E),
    warnBg: Color(0xFF3A3113),
    warnFg: Color(0xFFE5C76B),
    placeholder: Color(0xFF6B7686),
  );

  @override
  AppPalette copyWith({
    Color? background,
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
