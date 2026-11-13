import 'package:finance_ai/core/formatters/money_formatter.dart';
import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoneyFormatter', () {
    test('formatWhole formats integers with dots', () {
      expect(MoneyFormatter.formatWhole(1600000), '1.600.000');
      expect(MoneyFormatter.formatWhole(25000), '25.000');
      expect(MoneyFormatter.formatWhole(500), '500');
      expect(MoneyFormatter.formatWhole(-1500000), '-1.500.000');
      expect(MoneyFormatter.formatWhole(0), '0');
    });

    test(
      'formatMinorUnits formats cents to currency with dots and suffix code',
      () {
        expect(MoneyFormatter.formatMinorUnits(160000000), '\$ 1.600.000');
        expect(MoneyFormatter.formatMinorUnits(160000050), '\$ 1.600.000,50');
        expect(
          MoneyFormatter.formatMinorUnits(160000000, currencyCode: 'COP'),
          '\$ 1.600.000 COP',
        );
        expect(
          MoneyFormatter.formatMinorUnits(-10570000, currencyCode: 'COP'),
          '-\$ 105.700 COP',
        );
        expect(
          MoneyFormatter.formatMinorUnits(-25075, currencyCode: 'COP'),
          '-\$ 250,75 COP',
        );
        expect(
          MoneyFormatter.formatMinorUnits(2550, currencyCode: 'COP'),
          '\$ 25,50 COP',
        );
        expect(
          MoneyFormatter.formatMinorUnits(125000, currencyCode: 'EUR'),
          '€ 1.250 EUR',
        );
        expect(
          MoneyFormatter.formatMinorUnits(125000, currencyCode: 'USD'),
          '\$ 1.250 USD',
        );
        expect(MoneyFormatter.formatMinorUnits(-250000), '-\$ 2.500');
      },
    );

    test('formatSignedMinorUnits formats zero and signed values honestly', () {
      expect(
        MoneyFormatter.formatSignedMinorUnits(50000000, currencyCode: 'COP'),
        '+\$ 500.000 COP',
      );
      expect(
        MoneyFormatter.formatSignedMinorUnits(-2500000, currencyCode: 'COP'),
        '-\$ 25.000 COP',
      );
      expect(
        MoneyFormatter.formatSignedMinorUnits(0, currencyCode: 'COP'),
        '\$ 0 COP',
      );
      expect(MoneyFormatter.formatSignedMinorUnits(0), '+\$ 0');
    });

    test('display and displayMajor format minor/major values with suffix', () {
      expect(MoneyFormatter.display(77180000, 'COP'), '\$ 771.800 COP');
      expect(MoneyFormatter.displayMajor(25.5, 'COP'), '\$ 25,50 COP');
      expect(
        MoneyFormatter.displayMajor(5000.0, 'COP', signed: true),
        '+\$ 5.000 COP',
      );
    });

    test('formatInputAmount formats minor units without currency symbol', () {
      expect(MoneyFormatter.formatInputAmount(160000000), '1.600.000');
      expect(MoneyFormatter.formatInputAmount(160000050), '1.600.000,50');
      expect(MoneyFormatter.formatInputAmount(0), '0');
      expect(MoneyFormatter.formatInputAmount(-250000), '-2.500');
      expect(MoneyFormatter.formatInputAmount(1250), '12,50');
    });

    test(
      'clean normalizes formatted strings for MoneyAmount.tryParseUserInput',
      () {
        expect(MoneyFormatter.clean('1.600.000'), '1600000');
        expect(MoneyFormatter.clean('1.600.000,50'), '1600000.50');
        expect(MoneyFormatter.clean('-1.600.000'), '-1600000');
        expect(MoneyFormatter.clean('1600000'), '1600000');
        expect(MoneyFormatter.clean('12.50'), '12.50');
        expect(MoneyFormatter.clean('12,5'), '12.5');
        expect(MoneyFormatter.clean('\$ 1.600.000'), '1600000');
        expect(MoneyFormatter.clean('COP 1.600.000'), '1600000');
      },
    );
  });

  group('MoneyInputFormatter', () {
    const formatter = MoneyInputFormatter(allowNegative: true);

    TextEditingValue value(String text, [int? cursor]) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor ?? text.length),
    );

    test('backspace keeps grouped integers editable down to empty', () {
      var current = value('50.000');
      for (final expected in ['5.000', '500', '50', '5', '']) {
        final raw = current.text.substring(0, current.text.length - 1);
        current = formatter.formatEditUpdate(current, value(raw));
        expect(current.text, expected);
        expect(current.selection.baseOffset, expected.length);
      }
      expect(formatter.formatEditUpdate(current, value('7')).text, '7');
    });

    test('deletion in the middle does not reinterpret existing grouping', () {
      expect(
        formatter.formatEditUpdate(value('50.000', 5), value('50.00', 4)),
        value('5.000', 4),
      );
      expect(
        formatter.formatEditUpdate(value('1.000', 2), value('1000', 1)),
        value('1.000', 1),
      );
    });

    test('intentional decimal dots and replacement paste remain supported', () {
      expect(
        formatter
            .formatEditUpdate(
              const TextEditingValue(
                text: '50.000',
                selection: TextSelection(baseOffset: 0, extentOffset: 6),
              ),
              value('50.00'),
            )
            .text,
        '50,00',
      );
      for (final text in ['12.50', '12,50']) {
        expect(
          formatter.formatEditUpdate(value('50.000'), value(text)).text,
          '12,50',
        );
      }
      expect(
        formatter.formatEditUpdate(value('5.000'), value('5.000.')).text,
        '5.000,',
      );
      expect(
        formatter.formatEditUpdate(value('50,00'), value('50,0')).text,
        '50,0',
      );
      expect(
        formatter.formatEditUpdate(value('50,0'), value('50,')).text,
        '50,',
      );
      expect(formatter.formatEditUpdate(value('50,'), value('50')).text, '50');
    });

    test('preserves selection ranges and active IME composition', () {
      final selected = TextEditingValue(
        text: '5.000',
        selection: const TextSelection(baseOffset: 1, extentOffset: 4),
      );
      expect(formatter.formatEditUpdate(value('5.000'), selected), selected);
      const composing = TextEditingValue(
        text: '1000',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 0, end: 4),
      );
      expect(formatter.formatEditUpdate(value('100'), composing), composing);
    });

    test('generated integer deletions preserve digit value and cursor bounds', () {
      // Ascending bounded enumeration reports the smallest failing integer;
      // additional large boundary cases exercise multiple grouping separators.
      for (final amount in [
        for (var n = 1; n <= 2500; n++) n,
        10000,
        50000,
        100000,
        1000000,
        123456789,
      ]) {
        var current = value(MoneyFormatter.formatWhole(amount));
        var digits = amount.toString();
        while (digits.isNotEmpty) {
          digits = digits.substring(0, digits.length - 1);
          current = formatter.formatEditUpdate(
            current,
            value(current.text.substring(0, current.text.length - 1)),
          );
          expect(current.text.replaceAll('.', ''), digits, reason: '$amount');
          expect(current.text.contains(','), isFalse, reason: '$amount');
          expect(
            current.selection.baseOffset,
            inInclusiveRange(0, current.text.length),
          );
          expect(
            current.selection.extentOffset,
            inInclusiveRange(0, current.text.length),
          );
        }
      }
    });

    test('formats digits with dot thousands separators as user types', () {
      final v1 = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '1600000',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      expect(v1.text, '1.600.000');

      final v2 = formatter.formatEditUpdate(
        const TextEditingValue(text: '1.600.000'),
        const TextEditingValue(
          text: '1.600.000,5',
          selection: TextSelection.collapsed(offset: 11),
        ),
      );
      expect(v2.text, '1.600.000,5');

      final v3 = formatter.formatEditUpdate(
        const TextEditingValue(text: '1.600.000,5'),
        const TextEditingValue(
          text: '1.600.000,50',
          selection: TextSelection.collapsed(offset: 12),
        ),
      );
      expect(v3.text, '1.600.000,50');
    });

    test('converts typed dot to comma when user types dot at end', () {
      final v = formatter.formatEditUpdate(
        const TextEditingValue(text: '1.600.000'),
        const TextEditingValue(
          text: '1.600.000.',
          selection: TextSelection.collapsed(offset: 10),
        ),
      );
      expect(v.text, '1.600.000,');
    });

    test('handles negative values when allowed', () {
      final v = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '-25000',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );
      expect(v.text, '-25.000');
    });
  });

  group('MoneyAmount.formatWithCurrency', () {
    test('formats with suffix and dots everywhere', () {
      expect(
        MoneyAmount.fromMinorUnits(77180000).formatWithCurrency('COP'),
        r'$ 771.800 COP',
      );
      expect(
        MoneyAmount.fromMinorUnits(-10570000).formatWithCurrency('COP'),
        r'-$ 105.700 COP',
      );
      expect(
        MoneyAmount.fromMinorUnits(-25075).formatWithCurrency('COP'),
        r'-$ 250,75 COP',
      );
      expect(
        MoneyAmount.fromMinorUnits(2550).formatWithCurrency('COP'),
        r'$ 25,50 COP',
      );
    });
  });
}
