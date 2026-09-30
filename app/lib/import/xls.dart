/// Reads the old binary Excel format (`.xls`, BIFF8 inside an OLE2 compound
/// file), which is what TDB exports (ADR 0002). Only what a bank statement
/// needs: the first sheet's text, numbers and dates. No formatting, no
/// formulas beyond their cached results.
///
/// Pure Dart: no Flutter, no database.
library;

import 'dart:typed_data';

import 'sheet.dart';

/// The file isn't an `.xls` this reader understands.
class XlsFormatException implements Exception {
  const XlsFormatException(this.message);
  final String message;
  @override
  String toString() => 'XlsFormatException: $message';
}

const _oleMagic = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1];

bool looksLikeXls(Uint8List bytes) {
  if (bytes.length < 8) return false;
  for (var i = 0; i < 8; i++) {
    if (bytes[i] != _oleMagic[i]) return false;
  }
  return true;
}

/// The first worksheet of [bytes] as rows of cells.
Sheet readXls(Uint8List bytes) {
  if (!looksLikeXls(bytes)) {
    throw const XlsFormatException('not an OLE2 compound file');
  }
  final stream = _Ole(bytes).stream('Workbook') ?? _Ole(bytes).stream('Book');
  if (stream == null) throw const XlsFormatException('no Workbook stream');
  return _Biff(stream).firstSheet();
}

// ---------------------------------------------------------------- OLE2

const _endOfChain = 0xFFFFFFFE;
const _freeSect = 0xFFFFFFFF;

class _Ole {
  _Ole(this.b) : d = ByteData.sublistView(b) {
    _sectorSize = 1 << d.getUint16(0x1E, Endian.little);
    _miniSectorSize = 1 << d.getUint16(0x20, Endian.little);
    _miniCutoff = d.getUint32(0x38, Endian.little);
    _readFat();
  }

  final Uint8List b;
  final ByteData d;
  late final int _sectorSize;
  late final int _miniSectorSize;
  late final int _miniCutoff;
  final List<int> _fat = [];

  int _u32(int off) => d.getUint32(off, Endian.little);

  int _sectorOffset(int s) => (s + 1) * _sectorSize;

  void _readFat() {
    final fatSectors = <int>[];
    for (var i = 0; i < 109; i++) {
      final s = _u32(0x4C + i * 4);
      if (s == _freeSect || s == _endOfChain) break;
      fatSectors.add(s);
    }
    var difat = _u32(0x44);
    var difatCount = _u32(0x48);
    final perSector = _sectorSize ~/ 4;
    final guard = <int>{};
    while (difatCount-- > 0 && difat != _endOfChain && difat != _freeSect) {
      if (!guard.add(difat)) break;
      final off = _sectorOffset(difat);
      for (var i = 0; i < perSector - 1; i++) {
        final s = _u32(off + i * 4);
        if (s == _freeSect || s == _endOfChain) continue;
        fatSectors.add(s);
      }
      difat = _u32(off + (perSector - 1) * 4);
    }
    // A sector listed twice (or more than the file holds) is damage.
    final most = b.length ~/ _sectorSize;
    if (fatSectors.toSet().length != fatSectors.length ||
        fatSectors.length > most) {
      throw const XlsFormatException('FAT sectors repeat');
    }
    for (final s in fatSectors) {
      final off = _sectorOffset(s);
      if (off + _sectorSize > b.length) {
        throw const XlsFormatException('FAT sector out of range');
      }
      for (var i = 0; i < perSector; i++) {
        _fat.add(_u32(off + i * 4));
      }
    }
  }

  List<int> _chain(List<int> table, int start) {
    final out = <int>[];
    final seen = <int>{};
    var s = start;
    while (s != _endOfChain && s != _freeSect && s < table.length) {
      if (!seen.add(s)) throw const XlsFormatException('sector chain loops');
      out.add(s);
      s = table[s];
    }
    return out;
  }

  Uint8List _readRegular(int start, int size) {
    final out = BytesBuilder(copy: false);
    for (final s in _chain(_fat, start)) {
      final off = _sectorOffset(s);
      final end = (off + _sectorSize).clamp(0, b.length);
      if (off >= b.length) break;
      out.add(Uint8List.sublistView(b, off, end));
    }
    final all = out.takeBytes();
    return size <= all.length ? Uint8List.sublistView(all, 0, size) : all;
  }

  /// A stream by name from the root storage, or null.
  Uint8List? stream(String name) {
    final dirStart = _u32(0x30);
    final dir = _readRegular(dirStart, 1 << 30);
    final dd = ByteData.sublistView(dir);
    int? rootStart;
    int? rootSize;
    for (var off = 0; off + 128 <= dir.length; off += 128) {
      final nameLen = dd.getUint16(off + 0x40, Endian.little);
      final type = dir[off + 0x42];
      if (type == 0 || nameLen < 2) continue;
      final chars = <int>[];
      for (var i = 0; i < (nameLen ~/ 2) - 1 && i < 32; i++) {
        chars.add(dd.getUint16(off + i * 2, Endian.little));
      }
      final entryName = String.fromCharCodes(chars);
      final start = dd.getUint32(off + 0x74, Endian.little);
      final size = dd.getUint32(off + 0x78, Endian.little);
      if (type == 5) {
        rootStart = start;
        rootSize = size;
        continue;
      }
      if (type != 2 || entryName.toLowerCase() != name.toLowerCase()) continue;
      if (size >= _miniCutoff || rootStart == null) {
        return _readRegular(start, size);
      }
      return _readMini(start, size, rootStart, rootSize!);
    }
    return null;
  }

  Uint8List _readMini(int start, int size, int rootStart, int rootSize) {
    final miniStream = _readRegular(rootStart, rootSize);
    final miniFatBytes = _readRegular(_u32(0x3C), _u32(0x40) * _sectorSize);
    final mfd = ByteData.sublistView(miniFatBytes);
    final miniFat = [
      for (var i = 0; i + 4 <= miniFatBytes.length; i += 4)
        mfd.getUint32(i, Endian.little),
    ];
    final out = BytesBuilder(copy: false);
    for (final s in _chain(miniFat, start)) {
      final off = s * _miniSectorSize;
      if (off >= miniStream.length) break;
      final end = (off + _miniSectorSize).clamp(0, miniStream.length);
      out.add(Uint8List.sublistView(miniStream, off, end));
    }
    final all = out.takeBytes();
    return size <= all.length ? Uint8List.sublistView(all, 0, size) : all;
  }
}

// ---------------------------------------------------------------- BIFF8

class _Record {
  _Record(this.type, this.data);
  final int type;
  final Uint8List data;
}

class _Biff {
  _Biff(this.s);
  final Uint8List s;

  bool _date1904 = false;
  final List<String> _sst = [];
  final List<int> _xfFormat = [];
  final Map<int, String> _formats = {};

  Iterable<_Record> _records(int from) sync* {
    final d = ByteData.sublistView(s);
    var off = from;
    while (off + 4 <= s.length) {
      final type = d.getUint16(off, Endian.little);
      final len = d.getUint16(off + 2, Endian.little);
      final end = off + 4 + len;
      if (end > s.length) return;
      yield _Record(type, Uint8List.sublistView(s, off + 4, end));
      off = end;
    }
  }

  Sheet firstSheet() {
    // Workbook globals: shared strings, formats, the sheet list.
    int? sheetAt;
    final globals = <_Record>[];
    var first = true;
    for (final r in _records(0)) {
      if (first) {
        if (r.type != 0x0809) {
          throw const XlsFormatException('no BOF record');
        }
        final version = ByteData.sublistView(r.data)
            .getUint16(0, Endian.little);
        if (version != 0x0600) {
          throw const XlsFormatException('only BIFF8 (Excel 97 or later)');
        }
        first = false;
        continue;
      }
      globals.add(r);
      if (r.type == 0x000A) break; // EOF of globals
    }
    for (var i = 0; i < globals.length; i++) {
      final r = globals[i];
      final d = ByteData.sublistView(r.data);
      switch (r.type) {
        case 0x0022: // DATEMODE
          _date1904 = d.getUint16(0, Endian.little) == 1;
        case 0x041E: // FORMAT
          final idx = d.getUint16(0, Endian.little);
          _formats[idx] = _unicodeString(r.data, 2, 2).$1;
        case 0x00E0: // XF
          _xfFormat.add(d.getUint16(2, Endian.little));
        case 0x0085: // BOUNDSHEET
          final kind = r.data[5];
          if (kind == 0 && sheetAt == null) {
            sheetAt = d.getUint32(0, Endian.little);
          }
        case 0x00FC: // SST, with its CONTINUE records
          final parts = <Uint8List>[r.data];
          while (i + 1 < globals.length && globals[i + 1].type == 0x003C) {
            parts.add(globals[++i].data);
          }
          _readSst(parts);
      }
    }
    if (sheetAt == null) throw const XlsFormatException('no worksheet');
    return _readSheet(sheetAt);
  }

  // A string in the SST may break across CONTINUE records; at each break
  // the character data restarts with its own 8/16-bit flag byte.
  void _readSst(List<Uint8List> parts) {
    var p = 0;
    var off = 8;
    int byte() {
      while (off >= parts[p].length) {
        p++;
        off = 0;
        if (p >= parts.length) throw const XlsFormatException('SST cut short');
      }
      return parts[p][off++];
    }

    int u16() => byte() | (byte() << 8);
    int u32() => u16() | (u16() << 16);
    final unique = ByteData.sublistView(parts[0]).getUint32(4, Endian.little);
    for (var n = 0; n < unique; n++) {
      if (p >= parts.length ||
          (p == parts.length - 1 && off >= parts[p].length)) {
        break;
      }
      final count = u16();
      var flags = byte();
      final rich = flags & 0x08 != 0;
      final ext = flags & 0x04 != 0;
      final runs = rich ? u16() : 0;
      final extLen = ext ? u32() : 0;
      final codes = <int>[];
      while (codes.length < count) {
        if (off >= parts[p].length) {
          // Character data continues in the next record, flag byte first.
          p++;
          off = 0;
          flags = byte();
        }
        codes.add(flags & 0x01 != 0 ? u16() : byte());
      }
      for (var i = 0; i < runs * 4 + extLen; i++) {
        byte();
      }
      _sst.add(String.fromCharCodes(codes));
    }
  }

  /// A BIFF8 unicode string at [off] whose length field is [lenBytes] wide.
  /// Returns the string and the offset just past it.
  (String, int) _unicodeString(Uint8List data, int off, int lenBytes) {
    final d = ByteData.sublistView(data);
    final count = lenBytes == 1 ? data[off] : d.getUint16(off, Endian.little);
    var o = off + lenBytes;
    final flags = data[o++];
    final wide = flags & 0x01 != 0;
    final rich = flags & 0x08 != 0;
    final ext = flags & 0x04 != 0;
    var runs = 0;
    var extLen = 0;
    if (rich) {
      runs = d.getUint16(o, Endian.little);
      o += 2;
    }
    if (ext) {
      extLen = d.getUint32(o, Endian.little);
      o += 4;
    }
    final codes = <int>[];
    for (var i = 0; i < count && o < data.length; i++) {
      if (wide) {
        if (o + 2 > data.length) break;
        codes.add(d.getUint16(o, Endian.little));
        o += 2;
      } else {
        codes.add(data[o++]);
      }
    }
    return (String.fromCharCodes(codes), o + runs * 4 + extLen);
  }

  bool _isDateXf(int xf) {
    if (xf < 0 || xf >= _xfFormat.length) return false;
    final f = _xfFormat[xf];
    if (f >= 14 && f <= 17 || f == 22) return true;
    final code = _formats[f];
    return code != null && isDateFormatCode(code);
  }

  Object _number(double v, int xf) =>
      _isDateXf(xf) ? excelSerialToDate(v, date1904: _date1904) : v;

  Sheet _readSheet(int at) {
    final cells = <int, Map<int, Object>>{};
    void put(int r, int c, Object v) {
      // Past what any statement holds; a damaged file mustn't make rows
      // thousands of cells wide.
      if (c >= maxColumns || r >= maxRows) return;
      (cells[r] ??= {})[c] = v;
    }

    int? pendingRow;
    int? pendingCol;
    var first = true;
    for (final r in _records(at)) {
      final d = ByteData.sublistView(r.data);
      if (first) {
        first = false;
        if (r.type != 0x0809) throw const XlsFormatException('sheet BOF');
        continue;
      }
      if (r.type == 0x000A) break;
      if (r.data.length < 6 && r.type != 0x0207) continue;
      switch (r.type) {
        case 0x00FD: // LABELSST
          final i = d.getUint32(6, Endian.little);
          if (i < _sst.length) {
            put(_row(d), _col(d), _sst[i]);
          }
        case 0x0204: // LABEL
          put(_row(d), _col(d), _unicodeString(r.data, 6, 2).$1);
        case 0x00D6: // RSTRING
          put(_row(d), _col(d), _unicodeString(r.data, 6, 2).$1);
        case 0x0203: // NUMBER
          final xf = d.getUint16(4, Endian.little);
          put(_row(d), _col(d), _number(d.getFloat64(6, Endian.little), xf));
        case 0x027E: // RK
          final xf = d.getUint16(4, Endian.little);
          put(
            _row(d),
            _col(d),
            _number(_rk(d.getUint32(6, Endian.little)), xf),
          );
        case 0x00BD: // MULRK
          final row = _row(d);
          var col = _col(d);
          for (var o = 4; o + 6 <= r.data.length - 2; o += 6) {
            final xf = d.getUint16(o, Endian.little);
            put(
              row,
              col++,
              _number(_rk(d.getUint32(o + 2, Endian.little)), xf),
            );
          }
        case 0x0205: // BOOLERR
          if (r.data[7] == 0) put(_row(d), _col(d), r.data[6] != 0);
        case 0x0006: // FORMULA: keep the cached result
          final row = _row(d);
          final col = _col(d);
          final xf = d.getUint16(4, Endian.little);
          if (d.getUint16(12, Endian.little) != 0xFFFF) {
            put(row, col, _number(d.getFloat64(6, Endian.little), xf));
          } else if (r.data[6] == 0) {
            pendingRow = row;
            pendingCol = col;
          } else if (r.data[6] == 1) {
            put(row, col, r.data[8] != 0);
          }
        case 0x0207: // STRING, the text result of the formula just before
          if (pendingRow != null) {
            put(pendingRow, pendingCol!, _unicodeString(r.data, 0, 2).$1);
            pendingRow = null;
          }
      }
    }
    if (cells.isEmpty) return const Sheet([]);
    final lastRow = cells.keys.reduce((a, b) => a > b ? a : b);
    return Sheet([for (var r = 0; r <= lastRow; r++) _toRow(cells[r])]);
  }

  static List<Object?> _toRow(Map<int, Object>? m) {
    if (m == null || m.isEmpty) return const [];
    final last = m.keys.reduce((a, b) => a > b ? a : b);
    return [for (var c = 0; c <= last; c++) m[c]];
  }

  static int _row(ByteData d) => d.getUint16(0, Endian.little);
  static int _col(ByteData d) => d.getUint16(2, Endian.little);

  static double _rk(int rk) {
    double v;
    if (rk & 0x02 != 0) {
      v = (rk.toSigned(32) >> 2).toDouble();
    } else {
      final bd = ByteData(8)
        ..setUint32(0, 0, Endian.little)
        ..setUint32(4, rk & 0xFFFFFFFC, Endian.little);
      v = bd.getFloat64(0, Endian.little);
    }
    return rk & 0x01 != 0 ? v / 100 : v;
  }
}

/// Whether an Excel number format code shows a date (d, m, y outside quotes
/// and brackets). "mm" next to h or s is minutes, but a format with minutes
/// and no d or y is a time, not a date, and times alone aren't dates here.
bool isDateFormatCode(String code) {
  final plain = code
      .replaceAll(RegExp(r'"[^"]*"'), '')
      .replaceAll(RegExp(r'\[[^\]]*\]'), '')
      .replaceAll(RegExp(r'\\.'), '')
      .toLowerCase();
  return plain.contains('d') || plain.contains('y');
}

/// An Excel serial day number as a local calendar date and time.
DateTime excelSerialToDate(double serial, {bool date1904 = false}) {
  final base = date1904 ? DateTime.utc(1904, 1, 1) : DateTime.utc(1899, 12, 30);
  final ms = (serial * 86400000).round();
  final u = base.add(Duration(milliseconds: ms));
  return DateTime(u.year, u.month, u.day, u.hour, u.minute, u.second);
}
