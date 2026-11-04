/// An amount field's text grouped in thousands as it's typed (#324):
/// `2500000` shows as `2,500,000` before it's saved, as the phone's pad
/// already does. Every money field on the computer takes [GroupedAmount].
library;

import 'package:flutter/services.dart';

import '../domain/money.dart';
import '../import/mapping.dart';

/// Groups the whole part of each number in an amount field ([groupTyped]),
/// keeping the caret after the digit it was after.
///
/// Backspace over a comma takes the digit before it, Delete the one after:
/// a comma alone would only come back. A pasted amount is read as an
/// import reads a bank's cell ([readAmount]), so `1.250.000`, `1 250,50`,
/// `+125,000.00 ₮` or `(1,250.00)` come in as the amount they say.
class GroupedAmount extends TextInputFormatter {
  GroupedAmount(this.currency);

  final Currency currency;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Letters still being composed by an input method are left alone.
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    var value = _overComma(oldValue, newValue) ?? newValue;
    value = _pasted(oldValue, value) ?? value;
    final sel = value.selection;
    if (!sel.isValid) {
      return value.copyWith(text: groupTyped(value.text, const []).text);
    }
    final g = groupTyped(value.text, [sel.baseOffset, sel.extentOffset]);
    return TextEditingValue(
      text: g.text,
      selection: TextSelection(
        baseOffset: g.offsets[0],
        extentOffset: g.offsets[1],
        affinity: sel.affinity,
      ),
    );
  }

  /// A comma deleted alone: the digit beside it goes too, before it for
  /// Backspace, after it for Delete.
  TextEditingValue? _overComma(TextEditingValue old, TextEditingValue now) {
    final o = old.text;
    final n = now.text;
    final was = old.selection;
    if (!was.isValid || !was.isCollapsed || n.length != o.length - 1) {
      return null;
    }
    final i = now.selection.baseOffset;
    if (i < 0 || i >= o.length || o[i] != ',') return null;
    if (o.substring(0, i) + o.substring(i + 1) != n) return null;
    if (was.baseOffset == i + 1 && i > 0) {
      return TextEditingValue(
        text: o.substring(0, i - 1) + o.substring(i + 1),
        selection: TextSelection.collapsed(offset: i - 1),
      );
    }
    if (was.baseOffset == i && i + 1 < o.length) {
      return TextEditingValue(
        text: o.substring(0, i) + o.substring(i + 2),
        selection: TextSelection.collapsed(offset: i),
      );
    }
    return null;
  }

  /// More than one character put in at once, which reads as one amount:
  /// that amount, as this field would show it typed.
  TextEditingValue? _pasted(TextEditingValue old, TextEditingValue now) {
    final was = old.selection;
    if (!was.isValid) return null;
    final start = was.start;
    final after = old.text.length - was.end;
    final n = now.text;
    if (n.length - start - after < 2) return null;
    if (!n.startsWith(old.text.substring(0, start)) ||
        !n.endsWith(old.text.substring(was.end))) {
      return null;
    }
    // Put against a number or a sign already there, it's part of that.
    bool numeric(int i) =>
        i >= 0 && i < n.length && RegExp(r'[\d.,+\-−]').hasMatch(n[i]);
    if (numeric(start - 1) || numeric(n.length - after)) return null;
    final put = n.substring(start, n.length - after);
    // Sums are for parseAmount; only a plain amount is read here.
    if (RegExp(r'[*/×]|\d\s*[+\-]\s*\d').hasMatch(put)) return null;
    // One point and no comma is a point, as it would be typed: `12.345` in
    // dollars isn't twelve thousand, and stays for the field to call wrong.
    if (!put.contains(',') &&
        '.'.allMatches(put).length == 1 &&
        RegExp(r'\.\d{3}(?!\d)').hasMatch(put)) {
      return null;
    }
    final v = readAmount(put, currency.decimals);
    if (v == null) return null;
    // A `+` makes a row money in, and stays.
    final sign = v < 0 ? '-' : (put.trimLeft().startsWith('+') ? '+' : '');
    final typed = '$sign${typedAmount(v.abs(), currency)}';
    return TextEditingValue(
      text: n.substring(0, start) + typed + n.substring(n.length - after),
      selection: TextSelection.collapsed(offset: start + typed.length),
    );
  }
}
