import 'package:flutter_test/flutter_test.dart';
import 'package:retail_shop/core/format/money.dart';

import '../helpers/fixtures.dart';

void main() {
  group('formatRupees', () {
    test('uses Indian digit grouping', () {
      expect(formatRupees(money('482500')), '₹4,82,500');
      expect(formatRupees(money('1234567.89')), '₹12,34,567.89');
      expect(formatRupees(money('15999')), '₹15,999');
      expect(formatRupees(money('1000')), '₹1,000');
      expect(formatRupees(money('100')), '₹100');
      expect(formatRupees(money('0')), '₹0');
    });

    test('shows paise only when present', () {
      expect(formatRupees(money('15999.00')), '₹15,999');
      expect(formatRupees(money('499.5')), '₹499.50');
    });

    test('puts the minus sign before the rupee symbol', () {
      expect(formatRupees(money('-1200')), '-₹1,200');
    });
  });

  group('parseMoneyInput', () {
    test('accepts what shopkeepers type', () {
      expect(parseMoneyInput('15,999'), money('15999'));
      expect(parseMoneyInput('₹ 500'), money('500'));
      expect(parseMoneyInput('499.5'), money('499.5'));
    });

    test('rejects empty, negative and over-precise amounts', () {
      expect(parseMoneyInput(''), isNull);
      expect(parseMoneyInput('abc'), isNull);
      expect(parseMoneyInput('-5'), isNull);
      expect(parseMoneyInput('1.234'), isNull);
    });
  });

  test('moneyInputText drops empty paise', () {
    expect(moneyInputText(money('15999.00')), '15999');
    expect(moneyInputText(money('499.50')), '499.50');
  });

  test('parseMoney keeps API strings exact', () {
    expect(parseMoney('0.10') + parseMoney('0.20'), money('0.30'));
  });
}
