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
  /// E.g. 160000000, COP -> "$ 1.600.000 COP"
  /// E.g. 1250 -> "$ 12,50"
  /// E.g. -450000 -> "-$ 4.500"
  /// E.g. -10570000, COP -> "-$ 105.700 COP"
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

    final symbol = currencyCode?.toUpperCase() == 'EUR' ? '€' : r'$';

    if (currencyCode != null) {
      return '$sign$symbol $formattedWhole$decimalStr $currencyCode';
    }
    return '$sign\$ $formattedWhole$decimalStr';
  }

  /// Like [formatMinorUnits] but always prints the sign, for flow figures
  /// (chips, balances and month results).
  /// E.g. -450000 -> "-$ 4.500", 50000000 -> "+$ 500.000"
  /// Zero never carries a plus or minus sign: "$ 0" or "$ 0 COP".
  static String formatSignedMinorUnits(int minorUnits, {String? currencyCode}) {
    if (currencyCode != null && minorUnits == 0) {
      final symbol = currencyCode.toUpperCase() == 'EUR' ? '€' : r'$';
      return '$symbol 0 $currencyCode';
    }
    final formatted = formatMinorUnits(
      minorUnits.abs(),
      currencyCode: currencyCode,
    );
    return '${minorUnits < 0 ? '-' : '+'}$formatted';
  }

  /// Unified display formatting with standard suffix notation: "$ 771.800 COP".
  static String display(
    int minorUnits,
    String currencyCode, {
    bool signed = false,
    bool trimZeroDecimals = true,
  }) {
    if (signed) {
      return formatSignedMinorUnits(minorUnits, currencyCode: currencyCode);
    }
    return formatMinorUnits(
      minorUnits,
      currencyCode: currencyCode,
      trimZeroDecimals: trimZeroDecimals,
    );
  }

  /// Formats major units (e.g. from receipt items or form totals) into display format.
  static String displayMajor(
    double amount,
    String currencyCode, {
    bool signed = false,
  }) {
    final minorUnits = (amount * 100).round();
    return display(minorUnits, currencyCode, signed: signed);
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
    if (newValue.text.isEmpty || !newValue.composing.isCollapsed) {
      return newValue;
    }

    String text = newValue.text;
    final isNegative = allowNegative && text.startsWith('-');
    if (isNegative) {
      text = text.substring(1);
    }

    String integerPart = '';
    String? decimalPart;

    // Formatter output uses dots only for grouping. A surviving grouping dot
    // must not become a decimal separator when a nearby digit is deleted.
    var editStart = 0;
    while (editStart < oldValue.text.length &&
        editStart < newValue.text.length &&
        oldValue.text[editStart] == newValue.text[editStart]) {
      editStart++;
    }
    var oldEnd = oldValue.text.length;
    var newEnd = newValue.text.length;
    while (oldEnd > editStart &&
        newEnd > editStart &&
        oldValue.text[oldEnd - 1] == newValue.text[newEnd - 1]) {
      oldEnd--;
      newEnd--;
    }
    final oldSelection = oldValue.selection;
    if (oldSelection.isValid &&
        !oldSelection.isCollapsed &&
        oldSelection.end <= oldValue.text.length) {
      final replacementEnd =
          newValue.text.length - (oldValue.text.length - oldSelection.end);
      if (replacementEnd >= oldSelection.start &&
          newValue.text.startsWith(
            oldValue.text.substring(0, oldSelection.start),
          ) &&
          newValue.text.substring(replacementEnd) ==
              oldValue.text.substring(oldSelection.end)) {
        editStart = oldSelection.start;
        newEnd = replacementEnd;
      }
    }

    // Commas are always decimal; dots are decimal only if newly entered.
    final commaIndex = text.indexOf(',');
    int decIndex = -1;
    if (commaIndex != -1) {
      decIndex = commaIndex;
    } else {
      final lastDotIndex = text.lastIndexOf('.');
      if (lastDotIndex != -1) {
        final afterLastDot = text.substring(lastDotIndex + 1);
        final originalDotIndex = lastDotIndex + (isNegative ? 1 : 0);
        final insertedDot =
            originalDotIndex >= editStart && originalDotIndex < newEnd;
        if (insertedDot && afterLastDot.length <= maxDecimals) {
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

    if (formattedText == newValue.text) return newValue;

    int mapOffset(int offset) {
      if (offset < 0 || offset >= newValue.text.length) {
        return formattedText.length;
      }
      int digitsBeforeCursor = 0;
      final oldCommaIdx = decIndex == -1 ? -1 : decIndex + (isNegative ? 1 : 0);
      final cursorAfterComma = oldCommaIdx != -1 && offset > oldCommaIdx;

      for (int i = 0; i < offset && i < newValue.text.length; i++) {
        if (RegExp(r'\d').hasMatch(newValue.text[i])) {
          digitsBeforeCursor++;
        }
      }

      var newCursor = formattedText.length;
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
      return newCursor;
    }

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection(
        baseOffset: mapOffset(newValue.selection.baseOffset),
        extentOffset: mapOffset(newValue.selection.extentOffset),
        affinity: newValue.selection.affinity,
        isDirectional: newValue.selection.isDirectional,
      ),
    );
  }
}
