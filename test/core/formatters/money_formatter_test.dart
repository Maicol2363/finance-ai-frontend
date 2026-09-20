import 'package:finance_ai/core/formatters/money_formatter.dart';
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

    test('formatMinorUnits formats cents to currency with dots', () {
      expect(MoneyFormatter.formatMinorUnits(160000000), '\$ 1.600.000');
      expect(MoneyFormatter.formatMinorUnits(160000050), '\$ 1.600.000,50');
      expect(
        MoneyFormatter.formatMinorUnits(160000000, currencyCode: 'COP'),
        'COP \$ 1.600.000',
      );
      expect(MoneyFormatter.formatMinorUnits(-250000), '-\$ 2.500');
    });

    test('formatInputAmount formats minor units without currency symbol', () {
      expect(MoneyFormatter.formatInputAmount(160000000), '1.600.000');
      expect(MoneyFormatter.formatInputAmount(160000050), '1.600.000,50');
      expect(MoneyFormatter.formatInputAmount(0), '0');
      expect(MoneyFormatter.formatInputAmount(-250000), '-2.500');
      expect(MoneyFormatter.formatInputAmount(1250), '12,50');
    });

    test('clean normalizes formatted strings for MoneyAmount.tryParseUserInput', () {
      expect(MoneyFormatter.clean('1.600.000'), '1600000');
      expect(MoneyFormatter.clean('1.600.000,50'), '1600000.50');
      expect(MoneyFormatter.clean('-1.600.000'), '-1600000');
      expect(MoneyFormatter.clean('1600000'), '1600000');
      expect(MoneyFormatter.clean('12.50'), '12.50');
      expect(MoneyFormatter.clean('12,5'), '12.5');
      expect(MoneyFormatter.clean('\$ 1.600.000'), '1600000');
      expect(MoneyFormatter.clean('COP 1.600.000'), '1600000');
    });
  });

  group('MoneyInputFormatter', () {
    const formatter = MoneyInputFormatter(allowNegative: true);

    test('formats digits with dot thousands separators as user types', () {
      final v1 = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '1600000', selection: TextSelection.collapsed(offset: 7)),
      );
      expect(v1.text, '1.600.000');

      final v2 = formatter.formatEditUpdate(
        const TextEditingValue(text: '1.600.000'),
        const TextEditingValue(text: '1.600.000,5', selection: TextSelection.collapsed(offset: 11)),
      );
      expect(v2.text, '1.600.000,5');

      final v3 = formatter.formatEditUpdate(
        const TextEditingValue(text: '1.600.000,5'),
        const TextEditingValue(text: '1.600.000,50', selection: TextSelection.collapsed(offset: 12)),
      );
      expect(v3.text, '1.600.000,50');
    });

    test('converts typed dot to comma when user types dot at end', () {
      final v = formatter.formatEditUpdate(
        const TextEditingValue(text: '1.600.000'),
        const TextEditingValue(text: '1.600.000.', selection: TextSelection.collapsed(offset: 10)),
      );
      expect(v.text, '1.600.000,');
    });

    test('handles negative values when allowed', () {
      final v = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '-25000', selection: TextSelection.collapsed(offset: 6)),
      );
      expect(v.text, '-25.000');
    });
  });
}
