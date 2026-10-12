// Another computer's changes, folded into what `combine` compares (ADR
// 0005, "the way chosen 2026-10-12", step 3). The other computer's file says,
// row by row, what it changed and what the row was before; this computer's
// ledger says what it holds. From the two, the three ledgers `combine` wants:
// the base both came from, this computer's, and the other's.
//
// Pure: rows are plain maps, as `combine` takes them.
import 'combine.dart' show LedgerRows, Row, combineKeys;

/// One change as the other computer's file carries it, with the key and
/// the whole row before and after by column name.
typedef FoldChange = ({String tbl, Row pk, String op, Row? before, Row? after});

/// The base and the other's ledger, worked out from [mine], the other
/// computer's [changes] (oldest first), and this computer's own
/// [mineSince]: its changes since the other last saw its ledger, which the
/// other can't have.
///
/// The common ground is [mine] with [mineSince] taken back (every row this
/// computer touched since, as it was before). The other's ledger is that
/// with its [changes] made. The base is the common ground, except where the
/// other's first change found a row otherwise (then what it found, which is
/// the safer base), and except where one of its changes found the row as it
/// is here now (the other saw this version, perhaps brought in from here,
/// and chose over it: then this row is the base). Rows neither touched are
/// the same in all three, so `combine` passes over them.
({LedgerRows base, LedgerRows theirs}) foldChanges(
  LedgerRows mine,
  List<FoldChange> changes, {
  List<FoldChange> mineSince = const [],
}) {
  final common = _copy(mine);
  for (final e in _byKey(mineSince).entries) {
    final keys = combineKeys[e.key]!;
    for (final run in e.value.entries) {
      _set(common, e.key, keys, run.key, run.value.first.before);
    }
  }
  final base = _copy(common);
  final theirs = _copy(common);
  for (final e in _byKey(changes).entries) {
    final table = e.key;
    final keys = combineKeys[table]!;
    final mineRows = _index(keys, mine[table]);
    final commonRows = _index(keys, common[table]);
    for (final run in e.value.entries) {
      final here = mineRows[run.key];
      final seq = run.value;
      final sawThis = seq.any((c) => _same(c.before, here));
      final Row? wasBefore;
      if (sawThis) {
        wasBefore = here;
      } else if (_same(seq.first.before, commonRows[run.key])) {
        wasBefore = commonRows[run.key];
      } else {
        wasBefore = seq.first.before;
      }
      _set(base, table, keys, run.key, wasBefore);
      _set(theirs, table, keys, run.key, seq.last.after);
    }
  }
  return (base: base, theirs: theirs);
}

/// [changes] by table and key, each key's in the order given.
Map<String, Map<String, List<FoldChange>>> _byKey(List<FoldChange> changes) {
  final out = <String, Map<String, List<FoldChange>>>{};
  for (final c in changes) {
    final keys = combineKeys[c.tbl];
    if (keys == null) continue;
    final k = [for (final col in keys) '${c.pk[col]}'].join('|');
    ((out[c.tbl] ??= {})[k] ??= []).add(c);
  }
  return out;
}

LedgerRows _copy(LedgerRows of) => {
  for (final e in of.entries)
    e.key: [
      for (final r in e.value) {...r},
    ],
};

Map<String, Row> _index(List<String> keys, List<Row>? rows) => {
  for (final r in rows ?? const <Row>[])
    [for (final c in keys) '${r[c]}'].join('|'): r,
};

/// Puts [row] in [of]'s [table] under [key], or takes the row there out
/// when [row] is null.
void _set(
  LedgerRows of,
  String table,
  List<String> keys,
  String key,
  Row? row,
) {
  final rows = of[table] ??= [];
  rows.removeWhere((r) => [for (final c in keys) '${r[c]}'].join('|') == key);
  if (row != null) rows.add({...row});
}

bool _same(Row? a, Row? b) {
  if (a == null || b == null) return a == null && b == null;
  final columns = {...a.keys, ...b.keys};
  for (final c in columns) {
    if (!a.containsKey(c) || !b.containsKey(c)) return false;
    final x = a[c], y = b[c];
    if (x == y) continue;
    // JSON gives a whole number back as an int, SQLite may hold a REAL.
    if (x is num && y is num && x == y) continue;
    return false;
  }
  return true;
}
