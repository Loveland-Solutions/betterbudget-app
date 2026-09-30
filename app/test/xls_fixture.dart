// Builds small `.xls` files (BIFF8 in an OLE2 compound file) for tests, so
// the reader is checked without any real bank statement in the repo.
import 'dart:convert';
import 'dart:typed_data';

class _Rec {
  _Rec(this.type, this.data);
  final int type;
  final List<int> data;
}

List<int> _u16(int v) => [v & 0xFF, (v >> 8) & 0xFF];
List<int> _u32(int v) => [..._u16(v & 0xFFFF), ..._u16((v >> 16) & 0xFFFF)];
List<int> _f64(double v) =>
    (ByteData(8)..setFloat64(0, v, Endian.little)).buffer.asUint8List();

/// A string as BIFF8 writes it: 16-bit when any character needs it.
List<int> _chars(String s) {
  final wide = s.codeUnits.any((c) => c > 0xFF);
  return [
    wide ? 1 : 0,
    for (final c in s.codeUnits) ...(wide ? _u16(c) : [c]),
  ];
}

/// Cells by (row, col): String, double, or DateTime (written as a dated
/// NUMBER). Integers written as RK when [rk] is true. When [splitSst] is set,
/// the shared strings break across a CONTINUE record inside a string.
Uint8List buildXls(
  Map<(int, int), Object> cells, {
  bool rk = false,
  bool splitSst = false,
}) {
  final strings = <String>[];
  for (final v in cells.values) {
    if (v is String && !strings.contains(v)) strings.add(v);
  }

  // Globals.
  final globals = <_Rec>[
    _Rec(0x0809, [
      ..._u16(0x0600),
      ..._u16(0x0005),
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
    ]),
    _Rec(0x0022, _u16(0)),
    // XF 0: general; XF 1: built-in date format 14.
    _Rec(0x00E0, [..._u16(0), ..._u16(0), ...List.filled(16, 0)]),
    _Rec(0x00E0, [..._u16(0), ..._u16(14), ...List.filled(16, 0)]),
  ];
  final sst = <int>[..._u32(strings.length), ..._u32(strings.length)];
  final continues = <List<int>>[];
  for (final s in strings) {
    final chars = _chars(s);
    if (splitSst && continues.isEmpty && s.length > 4) {
      // Break after two characters; the rest restarts with a flag byte.
      final wide = chars[0] == 1;
      final cut = 1 + (wide ? 4 : 2);
      sst.addAll([..._u16(s.length), ...chars.sublist(0, cut)]);
      continues.add([chars[0], ...chars.sublist(cut)]);
      continue;
    }
    (continues.isEmpty ? sst : continues.last).addAll([
      ..._u16(s.length),
      ...chars,
    ]);
  }
  globals.add(_Rec(0x00FC, sst));
  for (final c in continues) {
    globals.add(_Rec(0x003C, c));
  }
  final sheetName = _chars('Sheet1');
  // BOUNDSHEET's offset is filled in once the globals' length is known.
  final boundIndex = globals.length;
  globals.add(_Rec(0x0085, [0, 0, 0, 0, 0, 0, 6, ...sheetName]));
  globals.add(_Rec(0x000A, []));

  List<int> write(List<_Rec> recs) => [
    for (final r in recs) ...[
      ..._u16(r.type),
      ..._u16(r.data.length),
      ...r.data,
    ],
  ];
  final globalsLen = write(globals).length;
  globals[boundIndex] = _Rec(0x0085, [
    ..._u32(globalsLen),
    0,
    0,
    6,
    ...sheetName,
  ]);

  final sheet = <_Rec>[
    _Rec(0x0809, [
      ..._u16(0x0600),
      ..._u16(0x0010),
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
    ]),
  ];
  for (final e in cells.entries) {
    final (r, c) = e.key;
    final head = [..._u16(r), ..._u16(c)];
    switch (e.value) {
      case final String s:
        sheet.add(
          _Rec(0x00FD, [...head, ..._u16(0), ..._u32(strings.indexOf(s))]),
        );
      case final DateTime d:
        final serial =
            DateTime.utc(
              d.year,
              d.month,
              d.day,
              d.hour,
              d.minute,
              d.second,
            ).difference(DateTime.utc(1899, 12, 30)).inMilliseconds /
            86400000;
        sheet.add(_Rec(0x0203, [...head, ..._u16(1), ..._f64(serial)]));
      case final double n
          when rk && n == n.roundToDouble() && n.abs() < 1 << 28:
        sheet.add(
          _Rec(0x027E, [...head, ..._u16(0), ..._u32((n.toInt() << 2) | 2)]),
        );
      case final double n when rk && (n * 100) == (n * 100).roundToDouble():
        final x = (n * 100).round();
        sheet.add(_Rec(0x027E, [...head, ..._u16(0), ..._u32((x << 2) | 3)]));
      case final double n:
        sheet.add(_Rec(0x0203, [...head, ..._u16(0), ..._f64(n)]));
    }
  }
  sheet.add(_Rec(0x000A, []));

  final stream = [...write(globals), ...write(sheet)];
  // Past the mini-stream cutoff, so it lives in regular sectors.
  while (stream.length < 4096) {
    stream.add(0);
  }
  return _ole(stream);
}

Uint8List _ole(List<int> stream) {
  const size = 512;
  final sectors = (stream.length + size - 1) ~/ size;
  const endOfChain = 0xFFFFFFFE, free = 0xFFFFFFFF, fatSect = 0xFFFFFFFD;
  final header = <int>[
    0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1, //
    ...List.filled(16, 0),
    ..._u16(0x3E), ..._u16(3), ..._u16(0xFFFE), ..._u16(9), ..._u16(6),
    ...List.filled(6, 0),
    ..._u32(0), // directory sectors (v3: 0)
    ..._u32(1), // FAT sectors
    ..._u32(1), // first directory sector
    ..._u32(0),
    ..._u32(4096),
    ..._u32(endOfChain), ..._u32(0), // mini FAT
    ..._u32(endOfChain), ..._u32(0), // DIFAT
    ..._u32(0), // DIFAT[0]: the FAT is sector 0
    for (var i = 1; i < 109; i++) ..._u32(free),
  ];
  final fat = <int>[
    ..._u32(fatSect),
    ..._u32(endOfChain),
    for (var i = 0; i < sectors; i++)
      ..._u32(i == sectors - 1 ? endOfChain : 3 + i),
  ];
  while (fat.length < size) {
    fat.addAll(_u32(free));
  }
  List<int> entry(String name, int type, int start, int bytes) {
    final n = [for (final c in name.codeUnits) ..._u16(c), 0, 0];
    return [
      ...n,
      ...List.filled(64 - n.length, 0),
      ..._u16(n.length),
      type,
      1,
      ..._u32(free),
      ..._u32(free),
      ..._u32(type == 5 ? 1 : free),
      ...List.filled(16 + 4 + 16, 0),
      ..._u32(start),
      ..._u32(bytes),
      ..._u32(0),
    ];
  }

  final dir = [
    ...entry('Root Entry', 5, endOfChain, 0),
    ...entry('Workbook', 2, 2, stream.length),
    ...List.filled(256, 0),
  ];
  final body = [...stream];
  while (body.length % size != 0) {
    body.add(0);
  }
  return Uint8List.fromList([...header, ...fat, ...dir, ...body]);
}

Uint8List utf8Bytes(String s) => Uint8List.fromList(utf8.encode(s));
