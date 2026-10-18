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
class FoldChange {
  const FoldChange({
    required this.tbl,
    required this.pk,
    required this.op,
    this.before,
    this.after,
    this.seq = 0,
    this.knew,
  });
  final String tbl;
  final Row pk;
  final String op;
  final Row? before;
  final Row? after;

  /// Its number in its writer's log.
  final int seq;

  /// The last change of this computer's (the reader's) its writer had
  /// applied when it made it; null where its file doesn't say (ADR 0005
  /// step 4, from the reviews).
  final int? knew;
}

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
///
/// One exception (ADR 0005 step 4): the other's change found the row as it
/// is here by an answer (`resolve`) that settled it over this computer's
/// own version, which [mineAll], this computer's whole log, says it made.
/// Then the base is that version's before, so `combine` sees the two
/// changes, and the row is in [answered] (`table|key`): the other's version
/// is taken, and the person here is told theirs was replaced.
///
/// For what is [answered], how the person reads it: [asItWas], the base
/// with each row this computer had made as it is taken back to before its
/// own change, where the other's answer found it; [theirsOwn], that with
/// the other's own last change of each row, not its answer.
({
  LedgerRows base,
  LedgerRows theirs,
  Set<String> answered,
  LedgerRows asItWas,
  LedgerRows theirsOwn,
  Set<String> madeUp,
})
foldChanges(
  LedgerRows mine,
  List<FoldChange> changes, {
  List<FoldChange> mineSince = const [],
  List<FoldChange> mineAll = const [],
}) {
  final own = _byKey([
    for (final c in mineAll)
      if (c.op != 'resolve') c,
  ]);
  final answered = <String>{};
  final madeUp = <String>{};
  final common = _copy(mine);
  for (final e in _byKey(mineSince).entries) {
    final keys = combineKeys[e.key]!;
    for (final run in e.value.entries) {
      _set(common, e.key, keys, run.key, run.value.first.before);
    }
  }
  final base = _copy(common);
  final theirs = _copy(common);
  final ownBefore = <(String, String), Row?>{};
  final theirLast = <(String, String), Row?>{};
  for (final e in _byKey(changes).entries) {
    final table = e.key;
    final keys = combineKeys[table]!;
    final mineRows = _index(keys, mine[table]);
    final commonRows = _index(keys, common[table]);
    for (final run in e.value.entries) {
      final here = mineRows[run.key];
      final seq = run.value;
      // This computer's own change that made the row as it is here, if
      // one did.
      final last = own[table]?[run.key]?.lastOrNull;
      final made = last != null && _same(last.after, here) ? last : null;
      // A change of the other's found this version: the same values, and,
      // where its file says, made after it had this computer's change that
      // made them (equal values from an independent edit aren't seeing).
      bool seen(FoldChange c) =>
          _same(c.before, here) &&
          (c.knew == null || made == null || c.knew! >= made.seq);
      final sawThis = seq.any(seen);
      // Settled over this computer's own version by the other.
      FoldChange? overMine;
      if (made != null &&
          // The answer is the other's last word on it: a change it made
          // after is a change of its own, crossed as any is.
          seq.last.op == 'resolve' &&
          !_same(seq.last.after, here) &&
          seq.any((c) => c.op == 'resolve' && seen(c)) &&
          // Not when one of the other's own changes found this version: it
          // was seen, and changed, as any edit is.
          !seq.any((c) => c.op != 'resolve' && seen(c))) {
        overMine = made;
      }
      final ordinary = seq.where((c) => c.op != 'resolve').lastOrNull;
      if (ordinary != null) theirLast[(table, run.key)] = ordinary.after;
      // This computer's first change of the row the other hadn't seen when
      // it first changed it, where its file says.
      final firstKnew = seq.first.knew;
      final unseen = firstKnew == null || made == null
          ? null
          : (own[table]?[run.key] ?? const <FoldChange>[])
                .where((c) => c.seq > firstKnew)
                .firstOrNull;
      if (made != null && seq.any((c) => c.op == 'resolve' && seen(c))) {
        ownBefore[(table, run.key)] = (unseen ?? made).before;
      }
      final Row? wasBefore;
      if (overMine != null) {
        // From before this computer's first change the other hadn't seen.
        wasBefore = (unseen ?? overMine).before;
        answered.add('$table|${run.key}');
      } else if (sawThis) {
        wasBefore = here;
      } else if (unseen != null &&
          seq.every((c) => c.op == 'resolve') &&
          _same(seq.last.after, unseen.before)) {
        // Only the other's answer, and this computer's own change started
        // from what it settled on: nothing new here.
        wasBefore = seq.last.after;
      } else if (unseen != null &&
          here != null &&
          seq.last.after != null &&
          seq.first.before != null) {
        // This computer changed it after what the other had of it when it
        // changed it: the two changed it apart. Column by column, by which
        // each changed, not by equal values (a value both came to apart,
        // or one changed and changed back, is no common ground): one only
        // the other changed is taken, one only this computer changed
        // stays, and one both changed to different values is crossed.
        final apart = _apart(
          here,
          seq.last.after!,
          mine: [
            for (final c in own[table]?[run.key] ?? const <FoldChange>[])
              if (c.seq > firstKnew!) c,
          ],
          theirs: seq,
        );
        wasBefore = apart.row;
        if (apart.madeUp) madeUp.add('$table|${run.key}');
      } else if (_same(seq.first.before, commonRows[run.key])) {
        wasBefore = commonRows[run.key];
      } else {
        wasBefore = seq.first.before;
      }
      _set(base, table, keys, run.key, wasBefore);
      _set(theirs, table, keys, run.key, seq.last.after);
    }
  }
  final asItWas = _copy(base);
  for (final e in ownBefore.entries) {
    _set(asItWas, e.key.$1, combineKeys[e.key.$1]!, e.key.$2, e.value);
  }
  final theirsOwn = _copy(asItWas);
  for (final e in theirLast.entries) {
    _set(theirsOwn, e.key.$1, combineKeys[e.key.$1]!, e.key.$2, e.value);
  }
  return (
    base: base,
    theirs: theirs,
    answered: answered,
    asItWas: asItWas,
    theirsOwn: theirsOwn,
    madeUp: madeUp,
  );
}

/// What `combine` reads as an ancestor for a row both changed apart, by
/// column ([foldChanges]).
({Row row, bool madeUp}) _apart(
  Row here,
  Row there, {
  required List<FoldChange> mine,
  required List<FoldChange> theirs,
}) {
  Set<String> changed(List<FoldChange> of) => {
    for (final c in of)
      for (final k in {...?c.before?.keys, ...?c.after?.keys})
        if (c.before == null || c.after == null || c.before![k] != c.after![k])
          k,
  };
  final mineCols = changed(mine), theirCols = changed(theirs);
  final out = <String, Object?>{};
  var madeUp = false;
  for (final k in {...here.keys, ...there.keys}) {
    final h = here[k], t = there[k];
    if (k == 'created_at' || k == 'updated_at' || !theirCols.contains(k)) {
      out[k] = t;
    } else if (!mineCols.contains(k) || h == t) {
      out[k] = h;
    } else {
      // Crossed: what each started from, where it differs from both.
      final from = [
        for (final c in [...theirs, ...mine])
          if (c.before != null) c.before![k],
      ].where((v) => v != h && v != t);
      if (from.isNotEmpty) {
        out[k] = from.first;
      } else {
        // Nothing to show as it was: a value neither holds, said to be
        // made up so no one is offered it.
        madeUp = true;
        out[k] = h is int && t is int
            ? (h < t ? h : t) - 1
            : h is int
            ? h - 1
            : t is int
            ? t - 1
            : crossedValue;
      }
    }
  }
  return (row: out, madeUp: madeUp);
}

/// Stands in a base row for a column both computers changed apart where
/// nothing either started from differs from what each made: not a value
/// any row holds.
const crossedValue = '\u0000crossed';

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
    // When a computer wrote it is no part of it (as in the digest).
    if (c == 'created_at' || c == 'updated_at') continue;
    // A row written before v21 has no where-it-came-from: it is empty.
    if ((!a.containsKey(c) || !b.containsKey(c)) &&
        c != 'made_how' &&
        c != 'made_on') {
      return false;
    }
    final x = a[c], y = b[c];
    if (x == y) continue;
    // JSON gives a whole number back as an int, SQLite may hold a REAL.
    if (x is num && y is num && x == y) continue;
    return false;
  }
  return true;
}
