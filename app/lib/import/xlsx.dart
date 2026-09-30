/// Reads the first worksheet of a modern Excel file (`.xlsx`, zipped XML)
/// into a [Sheet]: text, numbers, dates (by their number format) and
/// formula results as cached.
///
/// Pure Dart: no Flutter, no database.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'sheet.dart';
import 'xls.dart' show excelSerialToDate, isDateFormatCode;

Sheet readXlsx(Uint8List bytes) {
  final zip = ZipDecoder().decodeBytes(bytes);
  XmlDocument? doc(String path) {
    final f = zip.findFile(path);
    if (f == null) return null;
    if (f.size > 64 << 20) throw UnreadableFileException('$path too large');
    return XmlDocument.parse(utf8.decode(f.content as List<int>));
  }

  final workbook = doc('xl/workbook.xml');
  if (workbook == null) {
    throw const UnreadableFileException('no xl/workbook.xml');
  }
  final date1904 = workbook
      .findAllElements('workbookPr')
      .any(
        (e) =>
            e.getAttribute('date1904') == '1' ||
            e.getAttribute('date1904') == 'true',
      );
  final firstSheet = workbook.findAllElements('sheet').firstOrNull;
  final relId = firstSheet?.attributes
      .where((a) => a.name.local == 'id')
      .firstOrNull
      ?.value;
  var sheetPath = 'xl/worksheets/sheet1.xml';
  final rels = doc('xl/_rels/workbook.xml.rels');
  if (rels != null && relId != null) {
    for (final r in rels.findAllElements('Relationship')) {
      if (r.getAttribute('Id') == relId) {
        final t = r.getAttribute('Target')!;
        sheetPath = t.startsWith('/') ? t.substring(1) : 'xl/$t';
      }
    }
  }

  final shared = <String>[
    for (final si
        in doc('xl/sharedStrings.xml')?.findAllElements('si') ??
            const <XmlElement>[])
      si.findAllElements('t').map((t) => t.innerText).join(),
  ];

  // Which cell styles show dates.
  final dateStyles = <int>{};
  final styles = doc('xl/styles.xml');
  if (styles != null) {
    final custom = <int, String>{
      for (final f in styles.findAllElements('numFmt'))
        int.parse(f.getAttribute('numFmtId') ?? '0'):
            f.getAttribute('formatCode') ?? '',
    };
    final xfs = styles.findAllElements('cellXfs').firstOrNull;
    var i = 0;
    for (final xf in xfs?.findElements('xf') ?? const <XmlElement>[]) {
      final id = int.tryParse(xf.getAttribute('numFmtId') ?? '0') ?? 0;
      final builtIn = (id >= 14 && id <= 17) || id == 22;
      if (builtIn || (custom[id] != null && isDateFormatCode(custom[id]!))) {
        dateStyles.add(i);
      }
      i++;
    }
  }

  final sheet = doc(sheetPath);
  if (sheet == null) throw UnreadableFileException('no $sheetPath');
  final cells = <int, Map<int, Object>>{};
  for (final c in sheet.findAllElements('c')) {
    final ref = c.getAttribute('r');
    if (ref == null) continue;
    final (row, col) = _ref(ref);
    if (col >= maxColumns || row >= maxRows) continue;
    final type = c.getAttribute('t');
    final v = c.findElements('v').firstOrNull?.innerText;
    Object? value;
    switch (type) {
      case 's':
        final i = int.tryParse(v ?? '');
        if (i != null && i < shared.length) value = shared[i];
      case 'inlineStr':
        value = c.findAllElements('t').map((t) => t.innerText).join();
      case 'str':
        value = v;
      case 'b':
        value = v == '1';
      case 'e':
        value = null;
      default:
        final n = double.tryParse(v ?? '');
        if (n != null) {
          final s = int.tryParse(c.getAttribute('s') ?? '0') ?? 0;
          value = dateStyles.contains(s)
              ? excelSerialToDate(n, date1904: date1904)
              : n;
        }
    }
    if (value != null) (cells[row] ??= {})[col] = value;
  }
  if (cells.isEmpty) return const Sheet([]);
  final lastRow = cells.keys.reduce((a, b) => a > b ? a : b);
  return Sheet([
    for (var r = 0; r <= lastRow; r++)
      if (cells[r] case final m?)
        [for (var c = 0; c <= m.keys.reduce((a, b) => a > b ? a : b); c++) m[c]]
      else
        const <Object?>[],
  ]);
}

/// "B3" → (row 2, column 1).
(int, int) _ref(String ref) {
  var col = 0;
  var i = 0;
  while (i < ref.length) {
    final u = ref.codeUnitAt(i);
    if (u < 65 || u > 90) break;
    col = col * 26 + (u - 64);
    i++;
  }
  return (int.parse(ref.substring(i)) - 1, col - 1);
}
