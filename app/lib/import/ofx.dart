/// Reads an OFX file (the "Quicken" or "Money" download many banks offer,
/// also named .qfx or .qbo) into a [Sheet]: a row of column names, then one
/// row per transaction with its date, amount, name and memo, and beside
/// them the one balance the file states. Both the older
/// form, where a value's tag is never closed and the whole file may be one
/// line, and the XML form are read.
///
/// The bank's own id for each transaction (FITID) is kept beside the rows,
/// so a later file that overlaps this one is recognised even when the bank
/// has reworded a name in between.
///
/// Pure Dart: no Flutter, no database.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'sheet.dart';

/// The names over the columns of the sheet an OFX file becomes.
const ofxColumns = ['Date', 'Amount', 'Name', 'Memo'];

/// Whether [bytes] start like an OFX file, whatever the file is called.
bool looksLikeOfx(Uint8List bytes) {
  var head = latin1
      .decode(bytes.sublist(0, bytes.length < 4096 ? bytes.length : 4096))
      .toUpperCase();
  // Past a UTF-8 mark, the file must open with it: a table that only
  // mentions OFX in some cell isn't one.
  if (head.startsWith('\u00EF\u00BB\u00BF')) head = head.substring(3);
  head = head.trimLeft();
  return head.startsWith('OFXHEADER') ||
      head.startsWith('<OFX>') ||
      (head.startsWith('<?') && head.contains('<OFX>'));
}

Sheet readOfx(Uint8List bytes) {
  var text = _decode(bytes).replaceAllMapped(
    _cdata,
    (m) => m[1]!.replaceAll('&', '&amp;').replaceAll('<', '&lt;'),
  );
  // One account's statement: a file can hold several, and their rows
  // belong to different accounts. The first is read.
  final next = _statementEnd.firstMatch(text);
  if (next != null) text = text.substring(0, next.end);
  final rows = <List<Object?>>[ofxColumns];
  final ids = <int, String>{};
  for (final m in _transaction.allMatches(text)) {
    final t = m[1]!;
    final id = _value(t, 'FITID');
    if (id != null) ids[rows.length] = id;
    rows.add([
      _date(_value(t, 'DTPOSTED')),
      _amount(_value(t, 'TRNAMT')),
      _value(t, 'NAME'),
      _value(t, 'MEMO'),
    ]);
    if (rows.length > maxRows) break;
  }
  // The bank's balance, never the available one (that counts holds).
  final at = text.toUpperCase().indexOf('<LEDGERBAL>');
  var ledger = at < 0 ? '' : text.substring(at);
  final end = RegExp(
    r'</LEDGERBAL>|<AVAILBAL>',
    caseSensitive: false,
  ).firstMatch(ledger);
  if (end != null) ledger = ledger.substring(0, end.start);
  return Sheet(
    rows,
    rowIds: ids,
    closing: _amount(_value(ledger, 'BALAMT')),
    closingDay: _date(_value(ledger, 'DTASOF')),
  );
}

String _decode(Uint8List b) {
  try {
    final s = utf8.decode(b);
    return s.startsWith('﻿') ? s.substring(1) : s;
  } on FormatException {
    // The older form is usually Windows-1252; Latin-1 reads its letters.
    return latin1.decode(b);
  }
}

final _cdata = RegExp(r'<!\[CDATA\[(.*?)\]\]>', dotAll: true);
final _statementEnd = RegExp(r'</(CC)?STMTRS>', caseSensitive: false);

/// OFX writes an amount with a point or a comma before the cents and
/// nothing between thousands, so "-1.500" is one and a half, not 1,500.
Object? _amount(String? s) {
  if (s == null) return null;
  return double.tryParse(s.replaceAll(',', '.')) ?? s;
}

// A transaction runs to its closing tag, or, in a file that leaves that
// out, to the next transaction or the end of the list.
final _transaction = RegExp(
  r'<STMTTRN>(.*?)(?=</STMTTRN>|<STMTTRN>|</BANKTRANLIST>|$)',
  caseSensitive: false,
  dotAll: true,
);

/// The text after the first `<tag>` in [block], up to the next tag.
String? _value(String block, String tag) {
  final m = RegExp('<$tag>([^<]*)', caseSensitive: false).firstMatch(block);
  if (m == null) return null;
  final v = _unescape(m[1]!).trim().replaceAll(RegExp(r'\s+'), ' ');
  return v.isEmpty ? null : v;
}

String _unescape(String s) => s.replaceAllMapped(
  RegExp(r'&(amp|lt|gt|quot|apos|nbsp|#\d{1,7});', caseSensitive: false),
  (m) => switch (m[1]!.toLowerCase()) {
    'amp' => '&',
    'lt' => '<',
    'gt' => '>',
    'quot' => '"',
    'apos' => "'",
    'nbsp' => ' ',
    final n => switch (int.tryParse(n.substring(1))) {
      final c? when c > 0 && c <= 0x10FFFF => String.fromCharCode(c),
      _ => m[0]!,
    },
  },
);

/// The day a transaction posted. OFX writes YYYYMMDD, then perhaps a time
/// and a zone; the day is taken as written, since banks put midday or
/// midnight GMT there and turning it to local time could move the day.
DateTime? _date(String? s) {
  if (s == null) return null;
  final m = RegExp(r'^(\d{4})(\d{2})(\d{2})').firstMatch(s);
  if (m == null) return null;
  final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
  final out = DateTime(y, mo, d);
  return out.month == mo && out.day == d ? out : null;
}
