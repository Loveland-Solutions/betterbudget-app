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

  group('groupTyped', () {
    String g(String s) => groupTyped(s, const []).text;
    int at(String s, int caret) => groupTyped(s, [caret]).offsets.single;

    test('groups each whole number in thousands, not what follows a point', () {
      expect(g('2500000'), '2,500,000');
      expect(g('999'), '999');
      expect(g('1000.5'), '1,000.5');
      expect(g('1250.12345'), '1,250.12345');
      expect(g('-2500000'), '-2,500,000');
      expect(g('12000+8500*3'), '12,000+8,500*3');
      expect(g('.50'), '.50');
      expect(g(''), '');
    });

    test('commas typed anywhere are put where they belong', () {
      expect(g('2,50,0000'), '2,500,000');
      expect(g('12,5'), '125');
      expect(g('1,'), '1');
    });

    test('the caret stays after the digit it was after', () {
      expect(at('2500000', 7), 9); // at the end
      expect(at('2500000', 1), 1); // 2|,500,000: ahead of the comma
      expect(at('2500000', 2), 3); // 2,5|00,000
      expect(at('25,00000', 3), 3); // after a comma that moves: 2,5|00,000
      expect(at('1,2345', 2), 1); // 1|2,345
      expect(at('1234', 0), 0);
    });

    test('what it shows reads as the same amount', () {
      for (final s in ['2500000', '1234567.89', '12000+8500', '-1000']) {
        expect(parseAmount(g(s)), parseAmount(s), reason: s);
      }
    });
  });

  group('parseAmount', () {
    test('more than 15 whole digits is not an amount, typed or worked out '
        '(#163)', () {
      expect(parseAmount('999999999999999'), 99999999999999900);
      expect(parseAmount('100000000000000000'), isNull);
      expect(parseAmount('1234567890123456789012'), isNull);
      expect(parseAmount('999999999999999+1'), isNull);
      expect(parseAmount('999999999999999*10'), isNull);
      expect(parseAmount('-999999999999999-1'), isNull);
    });
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
