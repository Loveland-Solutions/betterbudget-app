/// A bank file read into a grid of cells, whatever it came as. The import
/// screen maps columns of this grid; it never looks at the file itself.
///
/// Pure Dart: no Flutter, no database.
library;

import 'dart:typed_data';

import 'csv.dart';
import 'ofx.dart';
import 'xls.dart';
import 'xlsx.dart';

/// Cells past these are ignored: no bank statement is that big, and a
/// damaged file mustn't make every row thousands of cells wide.
const maxColumns = 256, maxRows = 200000;

/// Rows of cells. A cell is a [String], a [double], a [DateTime], a [bool]
/// or null (empty). Rows can be ragged; a missing cell reads as null.
class Sheet {
  const Sheet(
    this.rows, {
    this.rowIds = const {},
    this.closing,
    this.closingDay,
  });
  final List<List<Object?>> rows;

  /// Row index → the bank's own id for that transaction, when the file
  /// gives one (OFX does). It never shows as a column.
  final Map<int, String> rowIds;

  /// The one balance a file states apart from its rows, as a cell, and the
  /// day it's for (OFX: the bank's balance when the file was made).
  final Object? closing;
  final DateTime? closingDay;

  int get width => rows.fold(0, (w, r) => r.length > w ? r.length : w);

  Object? cell(int row, int col) {
    if (row < 0 || row >= rows.length) return null;
    final r = rows[row];
    if (col < 0 || col >= r.length) return null;
    final v = r[col];
    if (v is String && v.trim().isEmpty) return null;
    return v;
  }
}

/// The kinds of file the import reads. The last one used on an account is
/// offered first next time.
enum FileKind { xls, xlsx, csv, ofx }

/// Which reader a file needs, from its first bytes, then its name.
FileKind? fileKindOf(Uint8List bytes, String name) {
  if (looksLikeXls(bytes)) return FileKind.xls;
  if (bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
    return FileKind.xlsx;
  }
  // Before the name: an OFX file is text and may be named anything.
  if (looksLikeOfx(bytes)) return FileKind.ofx;
  final lower = name.toLowerCase();
  if (lower.endsWith('.csv') ||
      lower.endsWith('.txt') ||
      lower.endsWith('.tsv')) {
    return FileKind.csv;
  }
  // Some banks name a text or HTML file .xls; text that decodes is CSV-ish.
  if (!bytes.take(512).contains(0)) return FileKind.csv;
  return null;
}

/// The file can't be read as any kind the import knows.
class UnreadableFileException implements Exception {
  const UnreadableFileException(this.detail);
  final String detail;
  @override
  String toString() => 'UnreadableFileException: $detail';
}

Sheet readSheet(Uint8List bytes, String name) {
  final kind = fileKindOf(bytes, name);
  try {
    return switch (kind) {
      FileKind.xls => readXls(bytes),
      FileKind.xlsx => readXlsx(bytes),
      FileKind.csv => readCsv(bytes),
      FileKind.ofx => readOfx(bytes),
      null => throw const UnreadableFileException('unknown kind'),
    };
  } on UnreadableFileException {
    rethrow;
  } catch (e) {
    throw UnreadableFileException('$e');
  }
}
