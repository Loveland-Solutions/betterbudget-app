/// An amount field's text grouped in thousands as it's typed (#324):
/// `2500000` shows as `2,500,000` before it's saved, as the phone's pad
/// already does. Every money field on the computer takes [GroupedAmount].
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../domain/money.dart';
import '../import/mapping.dart';

/// Groups the whole part of each number in an amount field ([groupTyped]),
/// keeping the caret after the digit it was after.
///
/// Backspace over the mark between thousands (`,`, or `.` in rupiah, #621)
/// takes the digit before it, Delete the one after: the mark alone would
/// only come back. A pasted amount is read as an
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
    final typedAt = identical(value, newValue)
        ? _typedAt(oldValue, value)
        : null;
    final sel = value.selection;
    if (!sel.isValid) {
      return value.copyWith(
        text: groupTyped(value.text, const [], currency, typedAt).text,
      );
    }
    final g = groupTyped(
      value.text,
      [sel.baseOffset, sel.extentOffset],
      currency,
      typedAt,
    );
    return TextEditingValue(
      text: g.text,
      selection: TextSelection(
        baseOffset: g.offsets[0],
        extentOffset: g.offsets[1],
        affinity: sel.affinity,
      ),
    );
  }

  /// Where one character was just typed, at the caret or over a selection.
  int? _typedAt(TextEditingValue old, TextEditingValue now) {
    final was = old.selection;
    if (!was.isValid) return null;
    final at = was.start;
    if (now.text.length != old.text.length - (was.end - was.start) + 1) {
      return null;
    }
    if (!now.text.startsWith(old.text.substring(0, at)) ||
        !now.text.endsWith(old.text.substring(was.end))) {
      return null;
    }
    return at;
  }

  /// The mark between thousands deleted alone: the digit beside it goes
  /// too, before it for Backspace, after it for Delete.
  TextEditingValue? _overComma(TextEditingValue old, TextEditingValue now) {
    final o = old.text;
    final n = now.text;
    final was = old.selection;
    if (!was.isValid || !was.isCollapsed || n.length != o.length - 1) {
      return null;
    }
    final i = now.selection.baseOffset;
    if (i < 0 || i >= o.length || o[i] != currency.style.group) return null;
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
        i >= 0 &&
        i < n.length &&
        (RegExp(r'[\d.,+\-−]').hasMatch(n[i]) || n[i] == currency.style.group);
    if (numeric(start - 1) || numeric(n.length - after)) return null;
    final put = n.substring(start, n.length - after);
    // Sums are for parseAmount; only a plain amount is read here.
    if (RegExp(r'[*/×÷]|\d\s*[+\-−xX]\s*\d').hasMatch(put)) return null;
    // One point and no comma is a point, as it would be typed: `12.345` in
    // dollars isn't twelve thousand, and stays for the field to call wrong.
    // In rupiah a point is between thousands, and is read as that.
    if (currency.point == '.' &&
        !put.contains(',') &&
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

/// A sum in an amount box turns into its answer when the box is left (#547):
/// `22+2` shows as `24` once the person tabs or clicks away or presses
/// Enter, so what's in the box is what's saved. One that doesn't work out
/// stays as typed ([sumAnswer]). Every field that takes [GroupedAmount] does
/// this, on the computer and the phone, without each one asking: [watch]
/// is called once, by the app, before it runs.
abstract final class SumAnswers {
  static FocusManager? _watched;

  /// True while a box's sum is being written as its answer: the same amount,
  /// so a field's listener doesn't take it for the person typing (it would
  /// clear a problem Add has just shown, for one).
  static bool get answering => _answering;
  static bool _answering = false;
  static FocusNode? _had;

  /// Once per focus manager: a test starts each with a new one.
  static void watch() {
    final m = FocusManager.instance;
    if (identical(m, _watched)) return;
    _watched?.removeListener(_moved);
    _watched = m;
    _had = m.primaryFocus;
    m.addListener(_moved);
    // Before the field sees Enter, so what it saves or checks is the answer.
    HardwareKeyboard.instance
      ..removeHandler(_key)
      ..addHandler(_key);
  }

  static void _moved() {
    final had = _had;
    _had = FocusManager.instance.primaryFocus;
    if (had != null && had != _had) answer(had);
  }

  static bool _key(KeyEvent e) {
    if (e is KeyDownEvent &&
        (e.logicalKey == LogicalKeyboardKey.enter ||
            e.logicalKey == LogicalKeyboardKey.numpadEnter)) {
      final f = FocusManager.instance.primaryFocus;
      if (f != null) answer(f);
    }
    return false;
  }

  /// The box [node] is the focus of, if it's an amount: its sum answered.
  static void answer(FocusNode node) {
    final context = node.context;
    if (context == null || !context.mounted) return;
    final field = context.findAncestorStateOfType<EditableTextState>();
    if (field == null || !field.mounted || field.widget.readOnly) return;
    final grouped = field.widget.inputFormatters
        ?.whereType<GroupedAmount>()
        .firstOrNull;
    if (grouped == null) return;
    final c = field.widget.controller;
    final shown = sumAnswer(c.text, grouped.currency);
    if (shown == null || shown == c.text) return;
    _answering = true;
    try {
      c.value = TextEditingValue(
        text: shown,
        selection: TextSelection.collapsed(offset: shown.length),
      );
    } finally {
      _answering = false;
    }
  }
}
