/// Which column of a bank file is which, and the rows that come out of it
/// (ADR 0002, "Mapping any bank's file"). The app guesses a mapping, the
/// person corrects it on the import screen, and it's saved per account so the
/// next file of the same shape goes straight to the preview.
///
/// Pure Dart: no Flutter, no database.
library;

import 'dart:convert';

import '../domain/money.dart';
import 'sheet.dart';

/// What a column holds. Everything not named is ignored.
enum ColumnRole {
  ignore,
  date,
  amount,
  moneyIn,
  moneyOut,
  payee,
  memo,
  balance,
}

/// How a text date is ordered. Real dates in a spreadsheet need none.
enum DateOrder { ymd, dmy, mdy }

class ImportMapping {
  const ImportMapping({
    required this.roles,
    this.headerRow,
    this.dateOrder = DateOrder.ymd,
    this.spendingPositive = false,
  });

  /// Column index → what it holds. Columns not listed are ignored.
  final Map<int, ColumnRole> roles;

  /// The row with the file's own column names, or null when it has none.
  /// Rows above it are never transactions.
  final int? headerRow;

  final DateOrder dateOrder;

  /// A single amount column that shows money out as positive (some card
  /// statements do), so every amount is turned around.
  final bool spendingPositive;

  int? columnOf(ColumnRole role) {
    for (final e in roles.entries) {
      if (e.value == role) return e.key;
    }
    return null;
  }

  ColumnRole roleOf(int col) => roles[col] ?? ColumnRole.ignore;

  /// One role per column: giving a column a role takes it from any other.
  /// Date, amount, in, out and balance appear once; payee and memo too.
  ImportMapping withRole(int col, ColumnRole role) {
    final next = Map<int, ColumnRole>.of(roles)..remove(col);
    if (role != ColumnRole.ignore) {
      next.removeWhere((_, r) => r == role);
      // A signed amount and an in/out pair can't both be used.
      if (role == ColumnRole.amount) {
        next.removeWhere(
          (_, r) => r == ColumnRole.moneyIn || r == ColumnRole.moneyOut,
        );
      } else if (role == ColumnRole.moneyIn || role == ColumnRole.moneyOut) {
        next.removeWhere((_, r) => r == ColumnRole.amount);
      }
      next[col] = role;
    }
    return ImportMapping(
      roles: next,
      headerRow: headerRow,
      dateOrder: dateOrder,
      spendingPositive: spendingPositive,
    );
  }

  ImportMapping copyWith({
    int? Function()? headerRow,
    DateOrder? dateOrder,
    bool? spendingPositive,
  }) => ImportMapping(
    roles: roles,
    headerRow: headerRow == null ? this.headerRow : headerRow(),
    dateOrder: dateOrder ?? this.dateOrder,
    spendingPositive: spendingPositive ?? this.spendingPositive,
  );

  /// What's still needed before rows can come out: a date and an amount.
  bool get hasDate => columnOf(ColumnRole.date) != null;
  bool get hasAmount =>
      columnOf(ColumnRole.amount) != null ||
      columnOf(ColumnRole.moneyIn) != null ||
      columnOf(ColumnRole.moneyOut) != null;
  bool get complete => hasDate && hasAmount;

  Map<String, Object?> toJson() => {
    'roles': {for (final e in roles.entries) '${e.key}': e.value.name},
    'headerRow': headerRow,
    'dateOrder': dateOrder.name,
    'spendingPositive': spendingPositive,
  };

  static ImportMapping? fromJson(Object? j) {
    if (j is! Map) return null;
    final roles = <int, ColumnRole>{};
    final r = j['roles'];
    if (r is Map) {
      for (final e in r.entries) {
        final col = int.tryParse('${e.key}');
        final role = ColumnRole.values.asNameMap()['${e.value}'];
        if (col != null && role != null) roles[col] = role;
      }
    }
    return ImportMapping(
      roles: roles,
      headerRow: j['headerRow'] is int ? j['headerRow'] as int : null,
      dateOrder:
          DateOrder.values.asNameMap()['${j['dateOrder']}'] ?? DateOrder.ymd,
      spendingPositive: j['spendingPositive'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ImportMapping &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

/// A saved mapping for one account: the file's shape it was made for, the
/// kind of file, and the columns.
class SavedMapping {
  const SavedMapping({
    required this.shape,
    required this.kind,
    required this.mapping,
    this.proven = true,
  });
  final String shape;

  /// The bank's balance added up (or there was none) when it was saved.
  /// Only then does the next file skip the columns.
  final bool proven;
  final FileKind kind;
  final ImportMapping mapping;

  String encode() => jsonEncode({
    'shape': shape,
    'kind': kind.name,
    'mapping': mapping.toJson(),
    'proven': proven,
  });

  static SavedMapping? decode(String? s) {
    if (s == null) return null;
    try {
      final j = jsonDecode(s);
      if (j is! Map) return null;
      final m = ImportMapping.fromJson(j['mapping']);
      final k = FileKind.values.asNameMap()['${j['kind']}'];
      if (m == null || k == null || j['shape'] is! String) return null;
      return SavedMapping(
        shape: j['shape'] as String,
        kind: k,
        mapping: m,
        proven: j['proven'] != false,
      );
    } on FormatException {
      return null;
    }
  }
}

// ---------------------------------------------------------------- dates

final _dateText = RegExp(
  r'^\s*(\d{1,4})\s*[./\-]\s*(\d{1,2})\s*[./\-]\s*(\d{1,4})'
  r'(?:[ T]+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([AaPp][Mm])?)?',
);

/// A date (and time, if the text has one) read in [order]. Four digits
/// first always means year first, whatever [order] says.
DateTime? parseDateText(String s, DateOrder order) {
  final m = _dateText.firstMatch(s);
  if (m == null) return null;
  final a = int.parse(m[1]!);
  final b = int.parse(m[2]!);
  final c = int.parse(m[3]!);
  int y, mo, d;
  if (m[1]!.length == 4) {
    (y, mo, d) = (a, b, c);
  } else {
    switch (order) {
      case DateOrder.ymd:
        return null; // year-first text always has four digits
      case DateOrder.dmy:
        (d, mo, y) = (a, b, c);
      case DateOrder.mdy:
        (mo, d, y) = (a, b, c);
    }
    if (m[3]!.length == 2) y += 2000;
    if (m[3]!.length != 2 && m[3]!.length != 4) return null;
  }
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  var h = int.tryParse(m[4] ?? '') ?? 0;
  final min = int.tryParse(m[5] ?? '') ?? 0;
  final sec = int.tryParse(m[6] ?? '') ?? 0;
  final ampm = m[7]?.toLowerCase();
  if (ampm == 'pm' && h < 12) h += 12;
  if (ampm == 'am' && h == 12) h = 0;
  final out = DateTime(y, mo, d, h, min, sec);
  if (out.month != mo || out.day != d) return null; // 31 April
  return out;
}

DateTime? readDate(Object? cell, DateOrder order) => switch (cell) {
  DateTime d => d,
  String s => parseDateText(s, order),
  _ => null,
};

/// The orders every text date in [cells] reads in. Real dates fit all.
Set<DateOrder> fittingOrders(Iterable<Object?> cells) {
  final fit = DateOrder.values.toSet();
  for (final c in cells) {
    if (c is! String) continue;
    fit.removeWhere((o) => parseDateText(c, o) == null);
  }
  return fit;
}

// ---------------------------------------------------------------- amounts

/// A cell as minor units of a currency with [decimals] digits after the
/// point (2 unless the account's has another). Text may carry thousands
/// separators in either style, a currency sign, a trailing minus or
/// parentheses.
int? readAmount(Object? cell, [int decimals = 2]) {
  final scale = const [1, 10, 100, 1000, 10000][decimals];
  if (cell is double) {
    // Past 2^53 minor units a double no longer holds whole numbers.
    if (!cell.isFinite || cell.abs() * scale >= 9e15) return null;
    return (cell * scale).round();
  }
  if (cell is! String) return null;
  var s = cell.replaceAll(
    RegExp(r'[\s ₮$€]|MNT|USD|төг', caseSensitive: false),
    '',
  );
  if (s.isEmpty) return null;
  var negative = false;
  if (s.startsWith('(') && s.endsWith(')')) {
    negative = true;
    s = s.substring(1, s.length - 1);
  }
  if (s.startsWith('-') || s.startsWith('−')) {
    negative = !negative;
    s = s.substring(1);
  } else if (s.endsWith('-')) {
    negative = !negative;
    s = s.substring(0, s.length - 1);
  } else if (s.startsWith('+')) {
    s = s.substring(1);
  }
  final lastDot = s.lastIndexOf('.');
  final lastComma = s.lastIndexOf(',');
  String whole;
  String frac = '';
  if (lastDot >= 0 && lastComma >= 0) {
    final dec = lastDot > lastComma ? lastDot : lastComma;
    whole = s.substring(0, dec);
    frac = s.substring(dec + 1);
  } else if (lastComma >= 0 && s.length - lastComma - 1 != 3) {
    whole = s.substring(0, lastComma); // 12,5 or 12,50: a decimal comma
    frac = s.substring(lastComma + 1);
  } else if (lastDot >= 0 && s.length - lastDot - 1 == 3 && decimals != 3) {
    whole = s; // 1.500 or 1.234.567: dots as thousands, as commas are
  } else if (lastDot >= 0) {
    whole = s.substring(0, lastDot);
    frac = s.substring(lastDot + 1);
  } else {
    whole = s;
  }
  whole = whole.replaceAll(RegExp(r'[.,\x27’]'), '');
  if (!RegExp(r'^\d+$').hasMatch(whole) || !RegExp(r'^\d*$').hasMatch(frac)) {
    return null;
  }
  // Beyond this it's a reference number, not money.
  if (whole.length > 15) return null;
  if (frac.length > decimals) {
    // No fractions of a mönggö.
    if (!RegExp(r'^0*$').hasMatch(frac.substring(decimals))) return null;
    frac = frac.substring(0, decimals);
  }
  final v =
      int.parse(whole) * scale +
      (decimals == 0 ? 0 : int.parse(frac.padRight(decimals, '0')));
  return negative ? -v : v;
}

// ---------------------------------------------------------------- reading

/// One transaction as read from the file.
class ImportRow {
  const ImportRow({
    required this.sourceRow,
    required this.date,
    required this.amount,
    required this.payee,
    this.memo,
    this.balance,
    this.hasTime = false,
  });

  /// Row index in the sheet (0-based), so the screen can point at it.
  final int sourceRow;

  /// The date, with the time of day when the file had one.
  final DateTime date;
  final bool hasTime;

  /// Minor units, signed for the account: money in is positive.
  final int amount;
  final String payee;
  final String? memo;

  /// The bank's own running balance after this row, when mapped.
  final int? balance;

  ImportRow withBalance(int? b) => ImportRow(
    sourceRow: sourceRow,
    date: date,
    hasTime: hasTime,
    amount: amount,
    payee: payee,
    memo: memo,
    balance: b,
  );
}

/// A row with something in it that didn't become a transaction, and why.
enum SkipReason { noDate, noAmount, zeroAmount }

class SkippedRow {
  const SkippedRow(this.sourceRow, this.reason);
  final int sourceRow;
  final SkipReason reason;
}

/// The bank's running balance against the amounts: if our reading of the
/// file is right, each balance is the one before it plus the row's amount.
class BalanceCheck {
  const BalanceCheck({
    required this.opening,
    required this.closing,
    required this.mismatches,
    this.firstMismatchRow,
    this.expected,
    this.found,
  });

  /// Before the first row (its balance less its amount) and after the last.
  final int opening;
  final int closing;

  /// Rows whose balance isn't the previous one plus their amount.
  final int mismatches;
  final int? firstMismatchRow;
  final int? expected;
  final int? found;

  bool get ok => mismatches == 0;
}

class ReadResult {
  const ReadResult({
    required this.rows,
    required this.skipped,
    this.check,
    this.newestFirst = false,
  });

  /// Oldest first, whatever order the file had.
  final List<ImportRow> rows;
  final List<SkippedRow> skipped;
  final BalanceCheck? check;

  /// The file listed newest first (the rows above are turned around).
  final bool newestFirst;
}

String _text(Object? c) => switch (c) {
  null => '',
  String s => s.trim().replaceAll(RegExp(r'\s+'), ' '),
  double d => d == d.roundToDouble() ? d.toInt().toString() : '$d',
  DateTime d => d.toIso8601String(),
  _ => '$c',
};

/// A counterparty cell without the account number banks put in front
/// (ADR 0002: the first token, when the field doesn't start with a space).
String cleanPayee(Object? cell) {
  final raw = cell is String ? cell : _text(cell);
  if (raw.trim().isEmpty) return '';
  if (raw.startsWith(' ')) return _text(raw);
  final t = _text(raw);
  final space = t.indexOf(' ');
  final first = space < 0 ? t : t.substring(0, space);
  final looksLikeAccount =
      RegExp(r'\d').allMatches(first).length >= 6 &&
      RegExp(r'^[A-Z]{0,2}[\d\-]+$').hasMatch(first);
  if (!looksLikeAccount) return t;
  return space < 0 ? '' : t.substring(space + 1).trim();
}

ReadResult readRows(Sheet sheet, ImportMapping m, {int decimals = 2}) {
  final dateCol = m.columnOf(ColumnRole.date);
  final amountCol = m.columnOf(ColumnRole.amount);
  final inCol = m.columnOf(ColumnRole.moneyIn);
  final outCol = m.columnOf(ColumnRole.moneyOut);
  final payeeCol = m.columnOf(ColumnRole.payee);
  final memoCol = m.columnOf(ColumnRole.memo);
  final balanceCol = m.columnOf(ColumnRole.balance);
  final rows = <ImportRow>[];
  final skipped = <SkippedRow>[];
  final start = (m.headerRow ?? -1) + 1;
  for (var r = start; r < sheet.rows.length; r++) {
    if (sheet.rows[r].every((c) => c == null || _text(c).isEmpty)) continue;
    final dateCell = dateCol == null ? null : sheet.cell(r, dateCol);
    final date = readDate(dateCell, m.dateOrder);
    if (date == null) {
      skipped.add(SkippedRow(r, SkipReason.noDate));
      continue;
    }
    int? amount;
    if (amountCol != null) {
      final a = readAmount(sheet.cell(r, amountCol), decimals);
      if (a != null) amount = m.spendingPositive ? -a : a;
    } else if (inCol != null || outCol != null) {
      final inCell = inCol == null ? null : sheet.cell(r, inCol);
      final outCell = outCol == null ? null : sheet.cell(r, outCol);
      final i = readAmount(inCell, decimals);
      final o = readAmount(outCell, decimals);
      if ((inCell != null && i == null) || (outCell != null && o == null)) {
        amount = null;
      } else if (i != null || o != null) {
        // Money out is shown positive or negative; either way it goes out.
        amount = (i ?? 0).abs() - (o ?? 0).abs();
      }
    }
    if (amount == null) {
      skipped.add(SkippedRow(r, SkipReason.noAmount));
      continue;
    }
    final balanceCell = balanceCol == null ? null : sheet.cell(r, balanceCol);
    if (amount == 0) {
      skipped.add(SkippedRow(r, SkipReason.zeroAmount));
      continue;
    }
    final counterparty = payeeCol == null
        ? ''
        : cleanPayee(sheet.cell(r, payeeCol));
    final description = memoCol == null ? '' : _text(sheet.cell(r, memoCol));
    final payee = counterparty.isNotEmpty ? counterparty : description;
    rows.add(
      ImportRow(
        sourceRow: r,
        date: date,
        hasTime: dateCell is DateTime
            ? (date.hour != 0 || date.minute != 0 || date.second != 0)
            : _dateText.firstMatch(dateCell as String)?[4] != null,
        amount: amount,
        payee: payee,
        memo: counterparty.isNotEmpty && description.isNotEmpty
            ? description
            : null,
        balance: readAmount(balanceCell, decimals),
      ),
    );
  }

  // Newest first when the dates run backwards overall.
  var newestFirst = false;
  if (rows.length > 1 && rows.first.date.isAfter(rows.last.date)) {
    newestFirst = true;
    rows.setAll(0, rows.reversed.toList());
  }

  // A card file may show what's owed as a positive balance: when the chain
  // fits better turned around, the balances are read that way.
  var read = rows;
  var check = balanceCol == null ? null : checkBalances(rows);
  if (check != null && !check.ok) {
    final flipped = [
      for (final r in rows)
        r.withBalance(r.balance == null ? null : -r.balance!),
    ];
    final other = checkBalances(flipped);
    if (other != null && other.mismatches < check.mismatches) {
      read = flipped;
      check = other;
    }
  }

  return ReadResult(
    rows: read,
    skipped: skipped,
    check: check,
    newestFirst: newestFirst,
  );
}

/// [rows] oldest first. Null when too few rows carry a balance.
BalanceCheck? checkBalances(List<ImportRow> rows) {
  final withBalance = rows.where((r) => r.balance != null).toList();
  if (withBalance.isEmpty) return null;
  var mismatches = 0;
  int? firstRow;
  int? expected;
  int? found;
  var running = withBalance.first.balance! - withBalance.first.amount;
  final opening = running;
  for (final r in rows) {
    running += r.amount;
    if (r.balance == null) continue;
    if (r.balance != running) {
      mismatches++;
      if (firstRow == null) {
        firstRow = r.sourceRow;
        expected = running;
        found = r.balance;
      }
      running = r.balance!; // count each break once, not every row after
    }
  }
  return BalanceCheck(
    opening: opening,
    closing: withBalance.last.balance!,
    mismatches: mismatches,
    firstMismatchRow: firstRow,
    expected: expected,
    found: found,
  );
}

// ---------------------------------------------------------------- keys

/// A key per row that's the same every time the same transaction comes in
/// from the bank, so a second import of an overlapping file skips it (ADR
/// 0002). Rows that would share a key within one file get #2, #3, in file
/// order.
List<String> importKeys(int accountId, List<ImportRow> rows) {
  final seen = <String, int>{};
  return [
    for (final r in rows)
      () {
        final when = r.hasTime
            ? r.date.toIso8601String()
            : r.date.toIso8601String().substring(0, 10);
        final base = r.balance != null
            ? 'a$accountId|$when|${r.amount}|${r.balance}'
            : 'a$accountId|$when|${r.amount}|${r.payee}|${r.memo ?? ''}';
        final n = (seen[base] ?? 0) + 1;
        seen[base] = n;
        return n == 1 ? base : '$base#$n';
      }(),
  ];
}

// ---------------------------------------------------------------- shape

/// What a file of this layout looks like, to know a saved mapping fits: the
/// header names when it has a header row, otherwise what kind of value each
/// column mostly holds (TDB's plain export has no header row).
String fileShape(Sheet sheet, ImportMapping m) {
  final h = m.headerRow;
  if (h != null && h < sheet.rows.length) {
    return 'h:${sheet.rows[h].map(_text).join('|')}';
  }
  return 't:${_columnKinds(sheet, m).join()}';
}

List<String> _columnKinds(Sheet sheet, ImportMapping m) {
  final dateCol = m.columnOf(ColumnRole.date);
  final dataRows = [
    for (var r = 0; r < sheet.rows.length; r++)
      if (dateCol != null &&
          readDate(sheet.cell(r, dateCol), m.dateOrder) != null)
        r,
  ];
  return [for (var c = 0; c < sheet.width; c++) _dominant(sheet, dataRows, c)];
}

String _dominant(Sheet sheet, List<int> rows, int col) {
  final n = <String, int>{};
  for (final r in rows) {
    final v = sheet.cell(r, col);
    final k = switch (v) {
      null => null,
      DateTime _ => 'D',
      double _ => 'N',
      bool _ => 'B',
      String s when readAmount(s) != null => 'N',
      String s
          when parseDateText(s, DateOrder.ymd) != null ||
              parseDateText(s, DateOrder.dmy) != null =>
        'D',
      _ => 'T',
    };
    if (k != null) n[k] = (n[k] ?? 0) + 1;
  }
  if (n.isEmpty) return '.';
  return n.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

/// Whether a saved mapping still fits [sheet]: the same shape.
bool mappingFits(Sheet sheet, SavedMapping saved) =>
    fileShape(sheet, saved.mapping) == saved.shape;

// ---------------------------------------------------------------- guessing

/// The columns that hold something on a transaction row.
List<int> dataColumns(Sheet sheet, List<int> dataRows) => [
  for (var c = 0; c < sheet.width; c++)
    if (dataRows.any((r) => sheet.cell(r, c) != null)) c,
];

/// The file's own name for each column that holds data. A print-layout
/// export merges cells, so a name can sit a column or two away from its
/// figures; each name goes to the nearest data column without one.
Map<int, String> headerLabels(Sheet sheet, int? headerRow, List<int> dataRows) {
  if (headerRow == null || headerRow >= sheet.rows.length) return const {};
  final cols = dataColumns(sheet, dataRows);
  final out = <int, String>{};
  final row = sheet.rows[headerRow];
  for (var c = 0; c < row.length; c++) {
    final name = _text(row[c]);
    if (name.isEmpty) continue;
    int? target;
    for (var d = 0; d <= 3 && target == null; d++) {
      for (final t in [c - d, c + d]) {
        if (cols.contains(t) && !out.containsKey(t)) {
          target = t;
          break;
        }
      }
    }
    if (target != null) out[target] = name;
  }
  return out;
}

/// Rows whose date cell reads as a date in [m]'s order.
List<int> dataRowsOf(Sheet sheet, ImportMapping m) {
  final dateCol = m.columnOf(ColumnRole.date);
  if (dateCol == null) return const [];
  return [
    for (var r = (m.headerRow ?? -1) + 1; r < sheet.rows.length; r++)
      if (readDate(sheet.cell(r, dateCol), m.dateOrder) != null) r,
  ];
}

/// The words banks put over their columns, lowercased. Mongolian first.
const _headerWords = <ColumnRole, List<String>>{
  ColumnRole.date: ['огноо', 'date', 'posted', 'гүйлгээний огноо'],
  ColumnRole.moneyIn: ['орлого', 'credit', 'deposit', 'money in', 'in'],
  ColumnRole.moneyOut: ['зарлага', 'debit', 'withdrawal', 'money out', 'out'],
  ColumnRole.amount: ['дүн', 'amount', 'гүйлгээний дүн', 'sum'],
  ColumnRole.balance: ['үлдэгдэл', 'balance', 'running balance'],
  ColumnRole.payee: [
    'харьцсан данс',
    'payee',
    'counterparty',
    'name',
    'харилцагч',
  ],
  ColumnRole.memo: [
    'гүйлгээний утга',
    'утга',
    'description',
    'memo',
    'details',
    'narrative',
  ],
};

ColumnRole? _roleFromHeader(String h) {
  final t = h.trim().toLowerCase();
  if (t.isEmpty) return null;
  for (final e in _headerWords.entries) {
    if (e.value.contains(t)) return e.key;
  }
  for (final e in _headerWords.entries) {
    if (e.value.any((w) => w.length > 3 && t.contains(w))) return e.key;
  }
  return null;
}

/// The app's best reading of [sheet], for the person to confirm or fix.
ImportMapping guessMapping(Sheet sheet) {
  final width = sheet.width;
  if (width == 0) return const ImportMapping(roles: {});

  // The date column: the one where the most cells are dates.
  int? dateCol;
  var best = 0;
  for (var c = 0; c < width; c++) {
    var n = 0;
    for (var r = 0; r < sheet.rows.length; r++) {
      final v = sheet.cell(r, c);
      if (v is DateTime ||
          (v is String &&
              DateOrder.values.any((o) => parseDateText(v, o) != null))) {
        n++;
      }
    }
    if (n > best) {
      best = n;
      dateCol = c;
    }
  }
  if (dateCol == null) return const ImportMapping(roles: {});

  final orders = fittingOrders(
    [for (var r = 0; r < sheet.rows.length; r++) sheet.cell(r, dateCol)].where(
      (c) =>
          c is String &&
          DateOrder.values.any((o) => parseDateText(c, o) != null),
    ),
  );
  final order = orders.contains(DateOrder.ymd)
      ? DateOrder.ymd
      : orders.contains(DateOrder.dmy)
      ? DateOrder.dmy
      : orders.contains(DateOrder.mdy)
      ? DateOrder.mdy
      : DateOrder.dmy;

  final dataRows = [
    for (var r = 0; r < sheet.rows.length; r++)
      if (readDate(sheet.cell(r, dateCol), order) != null) r,
  ];
  if (dataRows.isEmpty) return ImportMapping(roles: {dateCol: ColumnRole.date});

  // The header: the nearest row above the first transaction whose cells
  // are all short text without figures in them.
  int? headerRow;
  for (var r = dataRows.first - 1; r >= 0; r--) {
    final cells = sheet.rows[r].where((c) => c != null && _text(c).isNotEmpty);
    if (cells.isEmpty) continue;
    final looksLikeNames =
        cells.length >= 2 &&
        cells.every(
          (c) =>
              c is String &&
              c.trim().length <= 40 &&
              RegExp(r'\d').allMatches(c).length <= 3,
        );
    if (looksLikeNames) headerRow = r;
    break;
  }

  final roles = <int, ColumnRole>{dateCol: ColumnRole.date};

  // Named columns first.
  if (headerRow != null) {
    final labels = headerLabels(sheet, headerRow, dataRows);
    for (final e in labels.entries) {
      if (e.key == dateCol) continue;
      final role = _roleFromHeader(e.value);
      if (role == null || role == ColumnRole.date) continue;
      if (roles.containsValue(role)) continue;
      roles[e.key] = role;
    }
    // A counterparty split into account and name: the name is the payee.
    for (final e in labels.entries) {
      final t = e.value.toLowerCase();
      if (roles[e.key] != null && roles[e.key] != ColumnRole.payee) continue;
      if (t.contains('нэр') || t.contains('name')) {
        roles.removeWhere((_, r) => r == ColumnRole.payee);
        roles[e.key] = ColumnRole.payee;
        break;
      }
    }
  }

  // A counterparty header over two cells, the account number and then the
  // name: the name is the payee.
  final payeeCol = roles.entries
      .where((e) => e.value == ColumnRole.payee)
      .firstOrNull
      ?.key;
  if (payeeCol != null && _mostlyAccounts(sheet, dataRows, payeeCol)) {
    final next = dataColumns(
      sheet,
      dataRows,
    ).where((c) => c > payeeCol).firstOrNull;
    if (next != null &&
        !roles.containsKey(next) &&
        (_wordsLength(sheet, dataRows, next) ?? 0) > 0) {
      roles
        ..remove(payeeCol)
        ..[next] = ColumnRole.payee;
    }
  }

  // Figures: which numeric columns are the amount and the balance.
  final numeric = <int>[
    for (var c = 0; c < width; c++)
      if (c != dateCol && _mostlyNumbers(sheet, dataRows, c)) c,
  ];
  final hasAmount = roles.values.any(
    (r) =>
        r == ColumnRole.amount ||
        r == ColumnRole.moneyIn ||
        r == ColumnRole.moneyOut,
  );
  if (!hasAmount || !roles.containsValue(ColumnRole.balance)) {
    final chain = _bestChain(sheet, dataRows, numeric);
    if (chain != null) {
      if (!hasAmount) {
        roles.removeWhere((c, _) => chain.columns.contains(c));
        if (chain.outCol != null) {
          roles[chain.inCol] = ColumnRole.moneyIn;
          roles[chain.outCol!] = ColumnRole.moneyOut;
        } else {
          roles[chain.inCol] = ColumnRole.amount;
        }
      }
      roles.removeWhere((c, r) => c == chain.balanceCol);
      if (!roles.containsValue(ColumnRole.balance)) {
        roles[chain.balanceCol] = ColumnRole.balance;
      }
    } else if (!hasAmount) {
      // No balance to prove it: a column with both signs is a signed
      // amount; otherwise two columns never both filled are in and out.
      final signed = numeric.where((c) => _hasBothSigns(sheet, dataRows, c));
      if (signed.isNotEmpty) {
        roles[signed.first] = ColumnRole.amount;
      } else {
        final pair = _exclusivePair(sheet, dataRows, numeric);
        if (pair != null) {
          roles[pair.$1] = ColumnRole.moneyIn;
          roles[pair.$2] = ColumnRole.moneyOut;
        } else if (numeric.isNotEmpty) {
          roles[numeric.first] = ColumnRole.amount;
        }
      }
    }
  }

  // Words: the longest text is the description; the next, when it's words
  // and not codes, the payee.
  final textCols = <(int, double)>[
    for (var c = 0; c < width; c++)
      if (!roles.containsKey(c) && !numeric.contains(c))
        if (_wordsLength(sheet, dataRows, c) case final len? when len > 0)
          (c, len),
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  // A column that often starts with an account number is the counterparty.
  if (!roles.containsValue(ColumnRole.payee)) {
    final counterparty = textCols
        .where((e) => _accountShare(sheet, dataRows, e.$1) >= 1 / 3)
        .firstOrNull;
    if (counterparty != null) {
      roles[counterparty.$1] = ColumnRole.payee;
      textCols.remove(counterparty);
    }
  }
  if (!roles.containsValue(ColumnRole.memo) && textCols.isNotEmpty) {
    roles[textCols.first.$1] = ColumnRole.memo;
    textCols.removeAt(0);
  }
  if (!roles.containsValue(ColumnRole.payee) && textCols.isNotEmpty) {
    roles[textCols.first.$1] = ColumnRole.payee;
  }
  // With only one column of words, it's who the money went to or came from.
  if (!roles.containsValue(ColumnRole.payee)) {
    final memo = roles.entries
        .where((e) => e.value == ColumnRole.memo)
        .firstOrNull
        ?.key;
    if (memo != null) roles[memo] = ColumnRole.payee;
  }

  return ImportMapping(roles: roles, headerRow: headerRow, dateOrder: order);
}

/// The share of filled cells that begin with an account number.
double _accountShare(Sheet sheet, List<int> rows, int col) {
  var filled = 0;
  var accounts = 0;
  for (final r in rows) {
    final v = sheet.cell(r, col);
    if (v is! String) continue;
    filled++;
    if (_text(v) != cleanPayee(v)) accounts++;
  }
  return filled == 0 ? 0 : accounts / filled;
}

bool _mostlyAccounts(Sheet sheet, List<int> rows, int col) {
  var filled = 0;
  var accounts = 0;
  for (final r in rows) {
    final v = sheet.cell(r, col);
    if (v == null) continue;
    filled++;
    if (v is double || cleanPayee(v).isEmpty) accounts++;
  }
  return filled > 0 && accounts * 2 > filled;
}

bool _mostlyNumbers(Sheet sheet, List<int> rows, int col) {
  var nums = 0;
  var filled = 0;
  for (final r in rows) {
    final v = sheet.cell(r, col);
    if (v == null) continue;
    filled++;
    if (v is double || (v is String && readAmount(v) != null)) nums++;
  }
  return filled > 0 && nums * 10 >= filled * 9;
}

bool _hasBothSigns(Sheet sheet, List<int> rows, int col) {
  var pos = false;
  var neg = false;
  for (final r in rows) {
    final a = readAmount(sheet.cell(r, col));
    if (a == null) continue;
    if (a > 0) pos = true;
    if (a < 0) neg = true;
  }
  return pos && neg;
}

(int, int)? _exclusivePair(Sheet sheet, List<int> rows, List<int> numeric) {
  for (final a in numeric) {
    for (final b in numeric) {
      if (a >= b) continue;
      var ok = true;
      var both = 0;
      for (final r in rows) {
        final x = readAmount(sheet.cell(r, a)) ?? 0;
        final y = readAmount(sheet.cell(r, b)) ?? 0;
        if (x != 0 && y != 0) ok = false;
        if (x != 0 || y != 0) both++;
      }
      if (ok && both > 0) return (a, b);
    }
  }
  return null;
}

double? _wordsLength(Sheet sheet, List<int> rows, int col) {
  var total = 0;
  var n = 0;
  var letters = 0;
  for (final r in rows) {
    final v = sheet.cell(r, col);
    if (v is! String) continue;
    total += v.trim().length;
    letters += RegExp(r'\p{L}', unicode: true).allMatches(v).length;
    n++;
  }
  if (n == 0) return null;
  // Codes like "100 - 10" are mostly figures; skip them.
  if (letters * 3 < total) return 0;
  return total / n;
}

class _Chain {
  _Chain(this.inCol, this.outCol, this.balanceCol);
  final int inCol;
  final int? outCol;
  final int balanceCol;
  List<int> get columns => [inCol, ?outCol, balanceCol];
}

/// The amount column (or in/out pair) and balance column whose running
/// balance adds up on the most rows, in either row order.
_Chain? _bestChain(Sheet sheet, List<int> rows, List<int> numeric) {
  if (rows.length < 2) return null;
  _Chain? best;
  var bestHits = 0;
  var bestScore = 0;
  // Each column read once: the search below tries every combination.
  final amounts = {
    for (final c in numeric)
      c: [for (final r in rows) readAmount(sheet.cell(r, c))],
  };
  int? amt(int i, int a, int? b) {
    final x = amounts[a]![i];
    if (b == null) return x;
    final y = amounts[b]![i];
    if (x == null && y == null) return null;
    return (x ?? 0).abs() - (y ?? 0).abs();
  }

  for (final bal in numeric) {
    final balances = amounts[bal]!;
    for (final a in numeric) {
      if (a == bal) continue;
      for (final b in [null, ...numeric]) {
        if (b == bal || b == a) continue;
        var hits = 0;
        // On a tie, the reading that gives more rows an amount: in and out
        // together beat money in alone.
        var covered = 0;
        for (var i = 0; i < rows.length; i++) {
          if ((amt(i, a, b) ?? 0) != 0) covered++;
        }
        for (var i = 1; i < rows.length; i++) {
          final prev = balances[i - 1];
          final cur = balances[i];
          if (prev == null || cur == null) continue;
          final forward = amt(i, a, b);
          final backward = amt(i - 1, a, b);
          if ((forward != null && forward != 0 && prev + forward == cur) ||
              (backward != null && backward != 0 && cur + backward == prev)) {
            hits++;
          }
        }
        // In-then-out beats out-then-in only by what the numbers say.
        final score = hits * (rows.length + 1) + covered;
        if (hits > 0 && score > bestScore) {
          bestScore = score;
          bestHits = hits;
          best = _Chain(a, b, bal);
        }
      }
    }
  }
  if (best == null || bestHits * 2 < rows.length - 1) return null;
  return best;
}

/// The currency a file names, when it names only one: TDB's header row says
/// "MNT", other files put ₮ or $ in their amounts. Null when it names none
/// or both.
Currency? fileCurrency(Sheet sheet) {
  final mnt = RegExp(r'\bMNT\b|₮|төг', caseSensitive: false);
  final usd = RegExp(r'\bUSD\b|\$');
  var m = false, u = false;
  for (final row in sheet.rows) {
    for (final c in row) {
      if (c is! String) continue;
      m = m || mnt.hasMatch(c);
      u = u || usd.hasMatch(c);
    }
  }
  if (m == u) return null;
  return m ? Currency.mnt : Currency.usd;
}
