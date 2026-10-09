// More than one computer on one ledger (ADR 0005, "Never write blind"): what
// a ledger carries so that a computer can tell, before it writes the folder's
// file, whether the one there is its own last write, an older one, or holds
// another computer's changes. No clocks: a count per computer.
import 'dart:convert';

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
}

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
