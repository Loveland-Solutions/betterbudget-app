import 'package:betterbudget/domain/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatMoney', () {
    test('7–8 digit tugrik with cents', () {
      expect(formatMoney(418245000), '₮4,182,450.00');
      expect(formatMoney(514198050), '₮5,141,980.50');
      expect(formatMoney(-64020000), '−₮640,200.00');
      expect(formatMoney(38000), '₮380.00');
      expect(formatMoney(5), '₮0.05');
    });
  });

  group('parseAmount', () {
    test('plain numbers become minor units', () {
      expect(parseAmount('8000'), 800000);
      expect(parseAmount('2,500,000'), 250000000);
      expect(parseAmount('380.5'), 38050);
      expect(parseAmount('₮ 1 250.75'), 125075);
    });

    test('calculator arithmetic', () {
      expect(parseAmount('12000+8500'), 2050000);
      expect(parseAmount('3*4500'), 1350000);
      expect(parseAmount('100000-2500*2'), 9500000);
      expect(parseAmount('10000/3'), 333333);
    });

    test('signs', () {
      expect(parseAmount('+2500000'), 250000000);
      expect(parseAmount('-500'), -50000);
    });

    test('rejects garbage rather than guessing', () {
      expect(parseAmount(''), isNull);
      expect(parseAmount('abc'), isNull);
      expect(parseAmount('12000+'), isNull);
      expect(parseAmount('1.234'), isNull);
      expect(parseAmount('5/0'), isNull);
    });
  });
}
