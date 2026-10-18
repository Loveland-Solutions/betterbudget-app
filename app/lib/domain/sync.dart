// More than one computer on one ledger (ADR 0005, "Never write blind"): what
// a ledger carries so that a computer can tell, before it writes the folder's
// file, whether the one there is its own last write, an older one, or holds
// another computer's changes. No clocks: a count per computer.
import 'dart:convert';
import 'dart:math';

/// Keys in the `Preferences` table. They travel inside the ledger, and they
/// are not part of what [SyncKeys.seal] is worked out from.
abstract final class SyncKeys {
  /// Every key here starts with this.
  static const prefix = 'sync.';

  /// For each computer that has written this ledger to a folder: how many
  /// times, and what it calls itself. JSON, `{"<id>": {"n": 3, "name": "…"}}`.
  static const computers = '${prefix}computers';

  /// The ledger's contents as they were when it was last written to the
  /// folder or taken from it, as a digest. Contents that no longer give this
  /// digest were changed since.
  static const seal = '${prefix}seal';

  /// Which computer wrote it last and when by its own clock, for saying so
  /// on screen only. JSON, `{"by": "<id>", "at": "2026-10-09T21:40:00"}`.
  static const saved = '${prefix}saved';

  /// For each computer whose change file this ledger has applied, the last
  /// change number taken from it (ADR 0005, "the way chosen 2026-10-12").
  /// JSON, `{"<id>": 123}`. Written from step 3 on; the key is reserved here.
  static const applied = '${prefix}applied';

  /// Which ledger this is, so two computers never combine two different
  /// ledgers. Random, given to a new ledger when it is made; a ledger
  /// upgraded without one takes the folder's when it is first met there.
  static const ledger = '${prefix}ledger';

  /// Set on a folder ledger written whole by the older look (a computer's
  /// first write after upgrading, whose log never saw the changes it made
  /// before; "keep this computer's ledger"): a token the readers compare
  /// with their own, and take the ledger whole when it differs. Cleared by
  /// the next ordinary write.
  static const whole = '${prefix}whole';
}

/// The table that holds what this computer changed, row by row, filled by
/// triggers ([AppDatabase.changeTriggerSql]). It is this computer's own:
/// not part of the ledger's digest, never combined, not restored over.
const changeLogTable = 'changes';

/// A row of the change log that records what the computer had applied of
/// the others from then on (its vector, as `after`), not a row's change:
/// its `op` and `tbl`. No ledger table is called this, so the fold and
/// `combine` pass over it.
const appliedMarkerOp = 'applied';
const appliedMarkerTable = 'sync';

/// A new ledger's id: 16 hex characters, random.
String newLedgerId() {
  final random = Random.secure();
  return [
    for (var i = 0; i < 8; i++)
      random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

/// What [SyncKeys.applied] holds, parsed; a value that can't be read is an
/// empty vector.
Map<String, int> parseApplied(String? value) {
  if (value == null) return const {};
  try {
    return {
      for (final e in (jsonDecode(value) as Map).entries)
        '${e.key}': (e.value as num).toInt(),
    };
  } catch (_) {
    return const {};
  }
}

String encodeApplied(Map<String, int> applied) => jsonEncode({
  for (final id in applied.keys.toList()..sort()) id: applied[id],
});

/// How many times each computer has written the ledger, by the computer's id.
typedef Counters = Map<String, int>;

/// What [SyncKeys.computers] holds.
class SyncComputers {
  const SyncComputers([this.counters = const {}, this.names = const {}]);

  final Counters counters;
  final Map<String, String> names;

  /// Never throws: a value that can't be read is no computers at all.
  factory SyncComputers.parse(String? value) {
    if (value == null) return const SyncComputers();
    try {
      final counters = <String, int>{};
      final names = <String, String>{};
      (jsonDecode(value) as Map).forEach((id, v) {
        counters['$id'] = ((v as Map)['n'] as num).toInt();
        if (v['name'] case final String name) names['$id'] = name;
      });
      return SyncComputers(counters, names);
    } catch (_) {
      return const SyncComputers();
    }
  }

  String encode() => jsonEncode({
    for (final id in counters.keys.toList()..sort())
      id: {'n': counters[id], 'name': ?names[id]},
  });

  /// These with [other]'s folded in, and [computer]'s own count one higher:
  /// what a ledger carries once [computer] has written it over [other].
  SyncComputers writtenBy(String computer, String? name, Counters other) {
    final next = <String, int>{...counters};
    for (final e in other.entries) {
      if (e.value > (next[e.key] ?? 0)) next[e.key] = e.value;
    }
    next[computer] = (next[computer] ?? 0) + 1;
    return SyncComputers(next, {...names, computer: ?name});
  }

  /// These with [other]'s folded in and nothing raised.
  SyncComputers joined(SyncComputers other) {
    final next = <String, int>{...counters};
    for (final e in other.counters.entries) {
      if (e.value > (next[e.key] ?? 0)) next[e.key] = e.value;
    }
    return SyncComputers(next, {...other.names, ...names});
  }
}

/// Who wrote a ledger last, from [SyncKeys.saved].
({String? by, DateTime? at}) parseSaved(String? value) {
  if (value == null) return (by: null, at: null);
  try {
    final m = jsonDecode(value) as Map;
    final at = m['at'];
    return (
      by: m['by'] as String?,
      at: at is String ? DateTime.tryParse(at) : null,
    );
  } catch (_) {
    return (by: null, at: null);
  }
}

/// How two ledgers' counts stand to each other.
enum Standing {
  same,

  /// Mine holds every write theirs does, and more.
  mineAhead,

  /// Theirs holds every write mine does, and more.
  theirsAhead,

  /// Each holds a write the other doesn't.
  apart,
}

Standing compareCounters(Counters mine, Counters theirs) {
  var mineMore = false;
  var theirsMore = false;
  for (final id in {...mine.keys, ...theirs.keys}) {
    final m = mine[id] ?? 0;
    final t = theirs[id] ?? 0;
    if (m > t) mineMore = true;
    if (t > m) theirsMore = true;
  }
  if (mineMore && theirsMore) return Standing.apart;
  if (mineMore) return Standing.mineAhead;
  if (theirsMore) return Standing.theirsAhead;
  return Standing.same;
}

/// What a computer does about the ledger it found in the folder.
enum FolderMove {
  /// The folder holds what this computer has. Where the rows are the same
  /// and only the counts differ, this computer takes the folder's counts
  /// and seal as its own and writes nothing: were each to write, two
  /// computers would go on answering each other for good.
  nothing,

  /// Write this computer's ledger there.
  write,

  /// Take the folder's ledger in: it has everything this computer has, and
  /// this computer has changed nothing since.
  take,

  /// Both were changed apart: neither is written over the other.
  ask,
}

/// The rule of "Never write blind". The folder's file is written over only
/// when it is certain that everything in it is already in this computer's
/// ledger.
///
/// [identical]: the two hold the same contents. [changedHere]: this
/// computer's ledger was changed since it was last written to a folder or
/// taken from one. [theirsSealed]: the folder's contents are what its own
/// seal says, so no build that doesn't keep the counts has changed it since.
/// [theirsIsMyOldWrite]: the folder's file carries no counts at all and is
/// the one this computer wrote before it kept any (the first run of a build
/// that does).
FolderMove decideFolderMove({
  required bool identical,
  required bool changedHere,
  required bool theirsSealed,
  required Counters mine,
  required Counters theirs,
  bool theirsIsMyOldWrite = false,
}) {
  final standing = compareCounters(mine, theirs);
  if (identical) {
    // The same contents: nothing can be lost either way. Written only when
    // the folder's file lacks a seal or a count this computer has; a file
    // that is sealed and level or ahead is adopted as it is.
    return theirsSealed &&
            (standing == Standing.same || standing == Standing.theirsAhead)
        ? FolderMove.nothing
        : FolderMove.write;
  }
  if (!theirsSealed) {
    return theirsIsMyOldWrite ? FolderMove.write : FolderMove.ask;
  }
  return switch (standing) {
    // The folder holds this computer's last write. Unchanged here and yet
    // not identical can't be, short of two computers with one id: ask.
    Standing.same => changedHere ? FolderMove.write : FolderMove.ask,
    Standing.mineAhead => FolderMove.write,
    Standing.theirsAhead => changedHere ? FolderMove.ask : FolderMove.take,
    Standing.apart => FolderMove.ask,
  };
}

var _lastRowId = 0;
final _rowIdRandom = Random.secure();

/// An id for a new row that no other computer gives a row of its own (ADR
/// 0005, "Combine"): the time in milliseconds, then 20 random bits. So a
/// row made on one computer keeps its id on every other, and nothing that
/// names a row by its id (an entry's account, a setting's key, a bank
/// row's import key, a phone's entry) has to be renumbered when two
/// ledgers are combined. Each is higher than the last one made here, so
/// rows still sort in the order they were made. Rows made before this had
/// ids counted from 1, and keep them.
int newRowId() {
  var id =
      DateTime.now().millisecondsSinceEpoch * (1 << 20) +
      _rowIdRandom.nextInt(1 << 20);
  if (id <= _lastRowId) id = _lastRowId + 1;
  return _lastRowId = id;
}

/// The id of a row two computers would each make on their own from the
/// same fact (ADR 0005, "the way chosen 2026-10-12", step 2): the payday or
/// bill of one pay or plan on one date, a phone's entry, a bank row by its
/// import key, Income, the Safety net. The same [kind] and [key] give the
/// same id everywhere, so the two computers hold one row, not two. In a
/// range of its own, [2^62, 2^63), above anything [newRowId] gives for the
/// next century and above [carriedRuleId]'s. A row already under the id
/// (one skipped, or made and undone) makes the caller fall back to
/// [newRowId]: see `AppDatabase._freeId`.
int sharedRowId(String kind, String key) {
  // FNV-1a, as carriedRuleId.
  var h = 0xcbf29ce484222325;
  for (final unit in '$kind|$key'.codeUnits) {
    h ^= unit;
    h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return (h & 0x3FFFFFFFFFFFFFFF) | 0x4000000000000000;
}

/// Whether [id] is one [sharedRowId] gives.
bool isSharedRowId(int id) => id >= 0x4000000000000000;

/// How a transaction came to be, kept on the row (`made_how`). Words stored
/// in the ledger: never rename one.
abstract final class MadeHow {
  /// Typed in the register, here or on another computer.
  static const typed = 'typed';

  /// Brought in from a bank's file.
  static const imported = 'imported';

  /// Saved on a phone; `made_on` is the phone's own id.
  static const phone = 'phone';

  /// A payday or a bill the app scheduled from a pay or a plan.
  static const scheduled = 'scheduled';

  /// An account's opening balance.
  static const opening = 'opening';

  /// The adjustment a reconcile adds.
  static const adjustment = 'adjustment';

  /// Whether `made_on` is a computer's name, as against a phone's id or
  /// nothing: only what a person did at a computer is named for it.
  static bool onComputer(String how) => how == typed || how == imported;
}
