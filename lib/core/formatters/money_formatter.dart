import 'package:flutter/services.dart';

/// Utilities for formatting, cleaning, and input-formatting monetary amounts
/// using Colombian / Latin American conventions (dot for thousands, comma for decimals).
class MoneyFormatter {
  const MoneyFormatter._();

  /// Formats an integer [whole] with dot thousands separators.
  /// E.g. 1600000 -> "1.600.000", -25000 -> "-25.000"
  static String formatWhole(int whole) {
    final isNeg = whole < 0;
    final str = whole.abs().toString();
    final formatted = str.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return '${isNeg ? '-' : ''}$formatted';
  }

  /// Formats [minorUnits] (cents) into a readable currency string.
  /// E.g. 160000000 -> "$ 1.600.000"
  /// E.g. 1250 -> "$ 12,50"
  /// E.g. -450000 -> "-$ 4.500"
  static String formatMinorUnits(
    int minorUnits, {
    String? currencyCode,
    bool trimZeroDecimals = true,
  }) {
    final isNeg = minorUnits < 0;
    final absUnits = minorUnits.abs();
    final whole = absUnits ~/ 100;
    final cents = absUnits % 100;

    final formattedWhole = whole.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );

    final showDecimals = !(cents == 0 && trimZeroDecimals);
    final decimalStr = showDecimals
        ? ',${cents.toString().padLeft(2, '0')}'
        : '';
    final sign = isNeg ? '-' : '';

    if (currencyCode != null) {
      return '$currencyCode $sign\$ $formattedWhole$decimalStr';
    }
    return '$sign\$ $formattedWhole$decimalStr';
  }

  /// Formats [minorUnits] (cents) into an input-friendly string without currency symbol.
  /// E.g. 160000000 -> "1.600.000"
  /// E.g. 160000050 -> "1.600.000,50"
  /// E.g. -250000 -> "-2.500"
  static String formatInputAmount(
    int minorUnits, {
    bool trimZeroDecimals = true,
  }) {
    final isNeg = minorUnits < 0;
    final absUnits = minorUnits.abs();
    final whole = absUnits ~/ 100;
    final cents = absUnits % 100;

    final formattedWhole = whole.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );

    final showDecimals = !(cents == 0 && trimZeroDecimals);
    final decimalStr = showDecimals
        ? ',${cents.toString().padLeft(2, '0')}'
        : '';
    final sign = isNeg ? '-' : '';

    return '$sign$formattedWhole$decimalStr';
  }

  /// Cleans a user-entered monetary string so that it can be parsed by
  /// [MoneyAmount.tryParseUserInput].
  ///
  /// Examples:
  /// - "1.600.000" -> "1600000"
  /// - "1.600.000,50" -> "1600000.50"
  /// - "-1.600.000" -> "-1600000"
  /// - "1600000" -> "1600000"
  /// - "12.50" -> "12.50"
  /// - "12,5" -> "12.5"
  static String clean(String input) {
    var s = input.trim();
    if (s.isEmpty) return '';

    final isNeg = s.startsWith('-');
    if (isNeg) {
      s = s.substring(1).trim();
    }

    // Remove any currency symbols, spaces, or letters
    s = s.replaceAll(RegExp(r'[^\d\.,]'), '');
    if (s.isEmpty) return isNeg ? '-' : '';

    if (s.contains('.') && s.contains(',')) {
      final lastDot = s.lastIndexOf('.');
      final lastComma = s.lastIndexOf(',');
      if (lastComma > lastDot) {
        // Dot is thousands, comma is decimal: 1.600.000,50 -> 1600000.50
        s = s.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // Comma is thousands, dot is decimal: 1,600,000.50 -> 1600000.50
        s = s.replaceAll(',', '');
      }
    } else if (s.contains('.')) {
      final parts = s.split('.');
      if (parts.length > 2) {
        // Multiple dots -> thousands separators: 1.600.000 -> 1600000
        s = s.replaceAll('.', '');
      } else if (parts.length == 2) {
        if (parts[1].length == 3) {
          // Exactly 3 digits after single dot (e.g. 1.000, 16.000) -> thousands separator
          s = s.replaceAll('.', '');
        } else {
          // Decimal separator: 12.50 or 12.5
        }
      }
    } else if (s.contains(',')) {
      final parts = s.split(',');
      if (parts.length > 2) {
        s = s.replaceAll(',', '');
      } else if (parts.length == 2) {
        if (parts[1].length == 3) {
          s = s.replaceAll(',', '');
        } else {
          s = '${parts[0]}.${parts[1]}';
        }
      }
    }

    return '${isNeg ? '-' : ''}$s';
  }
}

/// A [TextInputFormatter] that formats numeric input with thousands separators
/// (dots) and allows an optional decimal part (comma or dot) as the user types.
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter({this.allowNegative = false, this.maxDecimals = 2});

  final bool allowNegative;
  final int maxDecimals;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String text = newValue.text;
    final isNegative = allowNegative && text.startsWith('-');
    if (isNegative) {
      text = text.substring(1);
    }

    String integerPart = '';
    String? decimalPart;

    // Check for comma or dot as decimal separator
    final commaIndex = text.indexOf(',');
    int decIndex = -1;
    if (commaIndex != -1) {
      decIndex = commaIndex;
    } else {
      final lastDotIndex = text.lastIndexOf('.');
      if (lastDotIndex != -1) {
        final afterLastDot = text.substring(lastDotIndex + 1);
        if (afterLastDot.length <= maxDecimals) {
          decIndex = lastDotIndex;
        }
      }
    }

    if (decIndex != -1) {
      integerPart = text
          .substring(0, decIndex)
          .replaceAll(RegExp(r'[^\d]'), '');
      decimalPart = text
          .substring(decIndex + 1)
          .replaceAll(RegExp(r'[^\d]'), '');
      if (decimalPart.length > maxDecimals) {
        decimalPart = decimalPart.substring(0, maxDecimals);
      }
    } else {
      integerPart = text.replaceAll(RegExp(r'[^\d]'), '');
    }

    if (integerPart.isEmpty && decimalPart == null) {
      return isNegative
          ? const TextEditingValue(text: '-')
          : const TextEditingValue();
    }

    String formattedInteger = '';
    if (integerPart.isNotEmpty) {
      formattedInteger = integerPart.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
    }

    final buffer = StringBuffer();
    if (isNegative) {
      buffer.write('-');
    }
    buffer.write(
      formattedInteger.isEmpty && decimalPart != null ? '0' : formattedInteger,
    );
    if (decimalPart != null) {
      buffer.write(',');
      buffer.write(decimalPart);
    }

    final formattedText = buffer.toString();

    int newCursor;
    if (newValue.selection.baseOffset >= newValue.text.length) {
      newCursor = formattedText.length;
    } else {
      int digitsBeforeCursor = 0;
      final oldCommaIdx = newValue.text.indexOf(',');
      final cursorAfterComma =
          oldCommaIdx != -1 && newValue.selection.baseOffset > oldCommaIdx;

      for (
        int i = 0;
        i < newValue.selection.baseOffset && i < newValue.text.length;
        i++
      ) {
        if (RegExp(r'\d').hasMatch(newValue.text[i])) {
          digitsBeforeCursor++;
        }
      }

      newCursor = formattedText.length;
      int digitsFound = 0;
      final newCommaIdx = formattedText.indexOf(',');
      for (int i = 0; i < formattedText.length; i++) {
        if (digitsFound == digitsBeforeCursor) {
          if (cursorAfterComma && newCommaIdx != -1 && i <= newCommaIdx) {
            // Keep advancing past comma
          } else {
            newCursor = i;
            break;
          }
        }
        if (RegExp(r'\d').hasMatch(formattedText[i])) {
          digitsFound++;
        }
        newCursor = i + 1;
      }
    }

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }
}
