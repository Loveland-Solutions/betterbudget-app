/// Reads a delimited text file (CSV, semicolon or tab separated) into a
/// [Sheet]. Every cell stays text; the mapping decides what's a date or an
/// amount. Handles UTF-8, UTF-16 with a byte-order mark, and Windows-1251,
/// the older Cyrillic code page some Mongolian exports still use.
///
/// Pure Dart: no Flutter, no database.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'sheet.dart';

Sheet readCsv(Uint8List bytes) {
  final text = decodeText(bytes);
  final lines = text.split(RegExp(r'\r\n|\r|\n'));
  final delimiter = guessDelimiter(lines.take(50).toList());
  return Sheet(parseDelimited(text, delimiter));
}

String decodeText(Uint8List b) {
  if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) {
    return utf8.decode(b.sublist(3), allowMalformed: true);
  }
  if (b.length >= 2 && b[0] == 0xFF && b[1] == 0xFE) {
    return _utf16(b.sublist(2), Endian.little);
  }
  if (b.length >= 2 && b[0] == 0xFE && b[1] == 0xFF) {
    return _utf16(b.sublist(2), Endian.big);
  }
  try {
    return utf8.decode(b);
  } on FormatException {
    return _cp1251(b);
  }
}

String _utf16(Uint8List b, Endian e) {
  final d = ByteData.sublistView(b);
  return String.fromCharCodes([
    for (var i = 0; i + 1 < b.length; i += 2) d.getUint16(i, e),
  ]);
}

// Windows-1251, 0x80–0xBF (0xC0–0xFF are А–я in order). Mongolian Ө, Ү
// have no place in 1251; files that need them are UTF-8 or UTF-16.
const _cp1251High = [
  0x0402, 0x0403, 0x201A, 0x0453, 0x201E, 0x2026, 0x2020, 0x2021, //
  0x20AC, 0x2030, 0x0409, 0x2039, 0x040A, 0x040C, 0x040B, 0x040F,
  0x0452, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
  0xFFFD, 0x2122, 0x0459, 0x203A, 0x045A, 0x045C, 0x045B, 0x045F,
  0x00A0, 0x040E, 0x045E, 0x0408, 0x00A4, 0x0490, 0x00A6, 0x00A7,
  0x0401, 0x00A9, 0x0404, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x0407,
  0x00B0, 0x00B1, 0x0406, 0x0456, 0x0491, 0x00B5, 0x00B6, 0x00B7,
  0x0451, 0x2116, 0x0454, 0x00BB, 0x0458, 0x0405, 0x0455, 0x0457,
];

String _cp1251(Uint8List b) => String.fromCharCodes([
  for (final c in b)
    c < 0x80
        ? c
        : c < 0xC0
        ? _cp1251High[c - 0x80]
        : 0x0410 + (c - 0xC0),
]);

/// The delimiter that splits the most lines into the same number (more than
/// one) of fields.
String guessDelimiter(List<String> lines) {
  var best = ',';
  var bestScore = -1;
  for (final d in const [',', ';', '\t', '|']) {
    final counts = <int, int>{};
    for (final l in lines) {
      if (l.trim().isEmpty) continue;
      final n = parseDelimited(l, d).firstOrNull?.length ?? 0;
      if (n > 1) counts[n] = (counts[n] ?? 0) + 1;
    }
    if (counts.isEmpty) continue;
    final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final score = top.value * 1000 + top.key;
    if (score > bestScore) {
      bestScore = score;
      best = d;
    }
  }
  return best;
}

/// RFC 4180-style fields: quotes around a field, "" for a quote inside.
/// Quoted fields may hold line breaks.
List<List<Object?>> parseDelimited(String text, String delimiter) {
  final rows = <List<Object?>>[];
  var row = <Object?>[];
  final field = StringBuffer();
  var quoted = false;
  var i = 0;
  void endField() {
    row.add(field.toString());
    field.clear();
  }

  void endRow() {
    endField();
    rows.add(row);
    row = <Object?>[];
  }

  while (i < text.length) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i += 2;
          continue;
        }
        quoted = false;
      } else {
        field.write(c);
      }
      i++;
      continue;
    }
    if (c == '"' && field.isEmpty) {
      quoted = true;
    } else if (c == delimiter) {
      endField();
    } else if (c == '\r' || c == '\n') {
      endRow();
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
    } else {
      field.write(c);
    }
    i++;
  }
  if (field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}
