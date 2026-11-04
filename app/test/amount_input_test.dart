import 'package:betterbudget/domain/money.dart';
import 'package:betterbudget/ui/amount_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// An amount field grouped as it's typed (#324), driven as a person would:
/// a key at a time, Backspace and Delete, a paste.
void main() {
  late TextEditingController c;

  Future<void> pumpField(WidgetTester tester, [Currency? currency]) async {
    c = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: TextField(
            controller: c,
            autofocus: true,
            inputFormatters: [GroupedAmount(currency ?? Currency.mnt)],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// [put] at the caret, or over the selection, as typing or a paste does.
  Future<void> put(WidgetTester tester, String put) async {
    final v = c.value;
    final s = v.selection;
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: v.text.replaceRange(s.start, s.end, put),
        selection: TextSelection.collapsed(offset: s.start + put.length),
      ),
    );
    await tester.pump();
  }

  Future<void> typeEach(WidgetTester tester, String keys) async {
    for (final k in keys.split('')) {
      await put(tester, k);
    }
  }

  Future<void> caret(WidgetTester tester, int at) async {
    c.selection = TextSelection.collapsed(offset: at);
    await tester.pump();
  }

  /// The text with a `|` at the caret.
  String shown() =>
      c.text.replaceRange(c.selection.baseOffset, c.selection.baseOffset, '|');

  testWidgets('a salary typed a digit at a time is grouped as it grows', (
    tester,
  ) async {
    await pumpField(tester);
    await typeEach(tester, '2500');
    expect(shown(), '2,500|');
    await typeEach(tester, '000');
    expect(shown(), '2,500,000|');
    expect(parseAmount(c.text), 250000000);
    await typeEach(tester, '.5');
    expect(shown(), '2,500,000.5|');
  });

  testWidgets('a digit typed mid-number keeps the caret after it', (
    tester,
  ) async {
    await pumpField(tester);
    await typeEach(tester, '250000');
    expect(c.text, '250,000');
    await caret(tester, 1); // 2|50,000
    await put(tester, '1');
    expect(shown(), '2,1|50,000');
    await put(tester, '9');
    expect(shown(), '21,9|50,000');
  });

  testWidgets('Backspace over a comma takes the digit before it, Delete the '
      'one after', (tester) async {
    await pumpField(tester);
    await typeEach(tester, '2500000');
    await caret(tester, 2); // 2,|500,000
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(shown(), '|500,000');

    await typeEach(tester, '2');
    expect(shown(), '2|,500,000');
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(shown(), '2|00,000');

    await caret(tester, 7); // the end
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(shown(), '20,000|');
  });

  testWidgets('a minus in front stays in front', (tester) async {
    await pumpField(tester);
    await typeEach(tester, '-1500000');
    expect(shown(), '-1,500,000|');
    expect(parseAmount(c.text), -150000000);
  });

  testWidgets('a sum is grouped number by number and still adds up', (
    tester,
  ) async {
    await pumpField(tester);
    await typeEach(tester, '12000+8500');
    expect(shown(), '12,000+8,500|');
    expect(parseAmount(c.text), 2050000);
  });

  testWidgets('a pasted amount reads as an import reads a bank\'s cell', (
    tester,
  ) async {
    await pumpField(tester);
    await put(tester, '1.250.000');
    expect(shown(), '1,250,000|');

    c.clear();
    await put(tester, '1 250,50');
    expect(shown(), '1,250.50|');

    c.clear();
    await put(tester, '(64,210.50)');
    expect(shown(), '-64,210.50|');
    expect(parseAmount(c.text), -6421050);

    c.clear();
    await put(tester, '₮2,500,000.00');
    expect(shown(), '2,500,000|');

    // Against a number already there, a paste is part of it.
    c.clear();
    await put(tester, '1');
    await put(tester, '000');
    expect(shown(), '1,000|');

    // A sum is left for the field to work out.
    c.clear();
    await put(tester, '12000+8500');
    expect(shown(), '12,000+8,500|');

    // A + is money in, and stays.
    c.clear();
    await put(tester, '+125,000.00 ₮');
    expect(shown(), '+125,000|');
    expect(parseAmount(c.text), 12500000);

    c.clear();
    await put(tester, '1,250,000 төгрөг');
    expect(shown(), '1,250,000|');

    // After a sign already typed, the paste is part of that number.
    c.clear();
    await put(tester, '-');
    await put(tester, '(1,250)');
    expect(shown(), '-(1,250)|');
    expect(parseAmount(c.text), isNull);
  });

  testWidgets('one point and three digits pasted is a point, as typed', (
    tester,
  ) async {
    await pumpField(tester);
    await put(tester, '1234.567');
    expect(shown(), '1,234.567|');
    expect(parseAmount(c.text), isNull); // the field calls it wrong
    c.clear();
    await put(tester, '0.125');
    expect(shown(), '0.125|');
  });

  testWidgets('yen has no point and still groups', (tester) async {
    await pumpField(tester, Currency.values.firstWhere((x) => x.code == 'JPY'));
    await typeEach(tester, '1250000');
    expect(shown(), '1,250,000|');
    expect(
      parseAmount(c.text, Currency.values.firstWhere((x) => x.code == 'JPY')),
      1250000,
    );
  });

  testWidgets('a digit typed over a selection that held a comma', (
    tester,
  ) async {
    await pumpField(tester);
    await typeEach(tester, '2500000');
    c.selection = const TextSelection(baseOffset: 1, extentOffset: 4);
    await tester.pump(); // 2[,50]0,000
    await put(tester, '7');
    expect(shown(), '27|0,000');
  });

  testWidgets('a currency with three decimals reads a pasted point as one', (
    tester,
  ) async {
    await pumpField(tester, Currency.values.firstWhere((x) => x.code == 'KWD'));
    await put(tester, '1.500');
    expect(shown(), '1.500|');
  });
}
