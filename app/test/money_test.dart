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

  group('as its people write it (#621)', () {
    final idr = Currency.fromCode('IDR');
    final eur = Currency.fromCode('EUR');
    final rub = Currency.fromCode('RUB');
    final chf = Currency.fromCode('CHF');

    test('rupiah: points between thousands, a comma before the cents', () {
      expect(formatMoney(100000095, currency: idr), 'Rp 1.000.000,95');
      // Its people don't write cents: shown only when there are some.
      expect(formatMoney(100000000, currency: idr), 'Rp 1.000.000');
      expect(formatMoney(-5000000, currency: idr), '−Rp 50.000');
      expect(zeroHint(idr), 'Rp 0');
      expect(typedAmount(100000095, idr), '1.000.000,95');
      expect(typedAmount(100000000, idr), '1.000.000');
    });

    test('rupiah typed as Indonesians write it', () {
      expect(parseAmount('1.000.000,95', idr), 100000095);
      expect(parseAmount('1.000.000', idr), 100000000);
      expect(parseAmount('50.000', idr), 5000000);
      expect(parseAmount('1000000,95', idr), 100000095);
      expect(parseAmount('Rp 12.500', idr), 1250000);
      expect(parseAmount('12.000+8.500', idr), 2050000);
      expect(parseAmount('3*4.500', idr), 1350000);
      // Typed the English way, with both marks, it's read as meant.
      expect(parseAmount('1,000,000.95', idr), 100000095);
      // Not a thousands pattern and not cents: wrong, not guessed.
      expect(parseAmount('1,234,5', idr), isNull);
      // A point with three digits after it is between thousands, as typed.
      expect(parseAmount('12,345', idr), 1234500);
    });

    test(
      'euros as in Germany, rubles with a space, francs with an apostrophe',
      () {
        expect(formatMoney(123495, currency: eur), '€1.234,95');
        expect(parseAmount('1.234,95', eur), 123495);
        expect(formatMoney(123495, currency: rub), '₽1 234,95');
        expect(parseAmount('1 234,95', rub), 123495);
        expect(parseAmount('1 234,95', rub), 123495);
        // The number pad's point is read as the ruble's comma.
        expect(parseAmount('1234.95', rub), 123495);
        expect(formatMoney(123495, currency: chf), "Fr. 1'234.95");
        expect(parseAmount("1'234.95", chf), 123495);
      },
    );

    test('read back, a comma with one or two digits after it is a point', () {
      // As a paste or a row's text reads; typed in the field, a comma is
      // between thousands in tugrik and dollars.
      expect(parseAmount('12,5', Currency.usd), 1250);
      expect(parseAmount('12,50'), 1250);
      // Three digits after it are still thousands.
      expect(parseAmount('12,500'), 1250000);
      expect(parseAmount('1,000,000.95'), 100000095);
      // Typed in tugrik the Indonesian way, it reads as meant too.
      expect(parseAmount('1.000.000,95'), 100000095);
      expect(parseAmount('1.000.000'), 100000000);
    });

    test('as typed, the field groups with the currency\'s own marks', () {
      String g(String t, Currency c) => groupTyped(t, const [], c).text;
      expect(g('1000000,95', idr), '1.000.000,95');
      // A point typed in rupiah is between thousands: the field puts its own.
      expect(g('50.000', idr), '50.000');
      expect(g('5.0000', idr), '50.000');
      // The `.` just typed is the point in euros; one already there stays
      // between thousands.
      final eur = Currency.fromCode('EUR');
      expect(groupTyped('12.', const [], eur, 2).text, '12,');
      expect(groupTyped('1.25', const [], eur).text, '125');
      expect(groupTyped('1,234', const [], eur).text, '1.234');
      expect(g('12000+8500', idr), '12.000+8.500');
      expect(g('1234567.5', rub), '1 234 567,5');
      expect(g('1 234 567', rub), '1 234 567');
      expect(g('2500000', Currency.mnt), '2,500,000');
      // A caret after a digit stays after it.
      final r = groupTyped('100000', const [4], idr);
      expect(r.text, '100.000');
      expect(r.offsets, [5]);
    });

    test('tugrik and dollars are written as before', () {
      expect(formatMoney(418245050), '₮4,182,450.50');
      expect(formatMoney(418245000, currency: Currency.usd), r'$4,182,450.00');
      expect(zeroHint(Currency.mnt), '₮0.00');
    });
  });
}
