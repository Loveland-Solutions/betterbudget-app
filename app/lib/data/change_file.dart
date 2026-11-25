// What a computer writes to the cloud folder for the other computers (ADR
// 0005, "Two computers: the way chosen, 2026-10-12", step 3): what it
// changed, row by row, in one file only that computer writes, as the phones
// do. A database encrypted with the ledger's key, written whole and in
// place, so the sync service sees one file with a new version. Every
// computer reads every other's file and never writes one that isn't its
// own.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqlite3/sqlite3.dart';

import '../domain/sync.dart';
import 'database.dart' show ChangeRow;
import 'encryption.dart';
import 'folder_io.dart';

/// Not a ledger, so not the ledger's extension; not a phone's either.
const changeFileExtension = 'betterbudget-changes';

/// The name of the file the computer with id [computer] writes.
String changeFileName(String computer) =>
    'Computer $computer.$changeFileExtension';

bool isChangeFileName(String name) =>
    name.startsWith('Computer ') && name.endsWith('.$changeFileExtension');

/// The computer id a change file's name carries. A sync service's copy of
/// a file it saw written from two places at once ("Computer abc (1)…", as
/// Google Drive names one) carries the same computer's: the file's own
/// header says whose it is either way (#662).
String? computerOfChangeFile(String name) => isChangeFileName(name)
    ? name
          .substring(
            'Computer '.length,
            name.length - changeFileExtension.length - 1,
          )
          .replaceFirst(_syncCopySuffix, '')
    : null;

/// " (1)", " (2)": what a sync service adds to a copy's name.
final _syncCopySuffix = RegExp(r' \(\d+\)$');

/// What the writing computer says about itself and what it has applied.
class ChangeFileHeader {
  const ChangeFileHeader({
    required this.computer,
    required this.name,
    required this.ledger,
    required this.schema,
    required this.applied,
    this.firstSeq = 0,
    required this.lastSeq,
    required this.writtenAt,
    this.knowsCuts = true,
  });

  final String computer;

  /// What the computer calls itself, for the screen.
  final String? name;

  /// Which ledger ([SyncKeys.ledger]) the changes are to, when known.
  final String? ledger;

  /// The tables' version the changes were written under.
  final int schema;

  /// For every computer the writer knows, the last change of that
  /// computer's it had applied when it wrote the file: what its own
  /// changes may rest on.
  final Map<String, int> applied;

  /// The first change the file holds (0 when none): what came before was
  /// dropped by the writer as no longer anyone's to take (a ledger taken
  /// whole from the folder, or compacted away).
  final int firstSeq;

  /// The writer's last change, in the file or compacted away.
  final int lastSeq;

  /// When, by the writer's clock: for the screen, and to tell a computer
  /// put away from one only idle ([awayAfter]; rewritten at least weekly).
  final DateTime writtenAt;

  /// Written by a build that compacts (ADR 0005 step 5) and so knows a cut
  /// when it is behind one. A file without it is from an older build, which
  /// would pass over what was cut: such a computer is never counted away.
  final bool knowsCuts;
}

/// One row's change as the file carries it: the key and the whole row
/// before and after, by column name.
class ChangeRecord {
  const ChangeRecord({
    required this.seq,
    required this.tbl,
    required this.pk,
    required this.op,
    required this.before,
    required this.after,
    required this.atMs,
  });

  final int seq;
  final String tbl;
  final Map<String, Object?> pk;

  /// `insert`, `update`, `delete`; `restore` or `erase` marks a whole
  /// ledger put in or cleared, with no row.
  final String op;
  final Map<String, Object?>? before;
  final Map<String, Object?>? after;
  final int atMs;

  /// A whole-ledger act, not a row's change.
  bool get isMarker => op == 'restore' || op == 'erase';

  /// An answer to a question about a thing both computers changed: the
  /// row as the other computer had it, and as chosen.
  bool get isResolve => op == 'resolve';

  /// What the writer had applied of the others from here on, not a row's
  /// change ([appliedMarkerOp]).
  bool get isApplied => op == appliedMarkerOp;

  /// For [isApplied]: the vector.
  Map<String, int> get vector => {
    for (final e in (after ?? const {}).entries)
      if (e.value is int) e.key: e.value as int,
  };

  factory ChangeRecord.fromRow(ChangeRow r) => ChangeRecord(
    seq: r.seq,
    tbl: r.tbl,
    pk: _json(r.pk) ?? const {},
    op: r.op,
    before: _json(r.before),
    after: _json(r.after),
    atMs: r.atMs,
  );

  static Map<String, Object?>? _json(String? text) =>
      text == null ? null : (jsonDecode(text) as Map).cast<String, Object?>();
}

class ChangeFile {
  const ChangeFile(this.header, this.changes, {this.knewBefore});
  final ChangeFileHeader header;

  /// Oldest first.
  final List<ChangeRecord> changes;

  /// What the writer had applied of the others when it made the first of
  /// [changes], from the last [ChangeRecord.isApplied] before them; null
  /// when the file has none there (a build before step 4's reviews).
  final Map<String, int>? knewBefore;

  /// For each of [changes], the last change of [computer]'s the writer had
  /// applied when it made it; null where the file doesn't say.
  List<int?> knewOf(String computer) {
    // Before the first one written down, unknown: equal values are trusted,
    // as a build before this did.
    int? knew = knewBefore == null ? null : (knewBefore![computer] ?? 0);
    return [
      for (final c in changes)
        if (c.isApplied) (knew = c.vector[computer] ?? 0) else knew,
    ];
  }
}

/// A computer whose change file hasn't been written for this long is away:
/// it no longer holds the others' change files back from being compacted,
/// and when it comes back it takes the folder's ledger whole, which holds
/// everything it missed (ADR 0005 step 5). A computer that's in use writes
/// its file whenever it takes something in, so six weeks of silence is a
/// computer put away, not one that is only idle; 45 days leaves room for one
/// used once a month for the bills.
const awayAfter = Duration(days: 45);

/// How far computer [me] may cut its log (ADR 0005 step 5): to the last of
/// its changes that the folder's ledger holds ([folder], its vector) and
/// that every other computer of [ledger] seen in the last [awayAfter]
/// ([files], their headers) has applied. A new computer starts from the
/// folder's ledger, and one away longer takes it whole when it is back.
int compactionCut({
  required String me,
  required String? ledger,
  required Map<String, int> folder,
  required List<ChangeFileHeader> files,
  required DateTime now,
}) {
  var cut = folder[me] ?? 0;
  for (final h in files) {
    if (h.computer == me) continue;
    if (h.ledger != null && ledger != null && h.ledger != ledger) continue;
    if (h.knowsCuts && now.difference(h.writtenAt) > awayAfter) continue;
    final had = h.applied[me] ?? 0;
    if (had < cut) cut = had;
  }
  return cut;
}

/// The first change a file of [rows] holds, for its header: the row after
/// the cut when the log was compacted (its first row only says where it
/// was cut, [cutOfNote]); 0 when none.
int firstSeqOf(List<ChangeRow> rows) {
  if (rows.isEmpty) return 0;
  final cut = cutOfNote(rows.first.op, rows.first.before);
  return cut != null ? cut + 1 : rows.first.seq;
}

/// Writes [rows] with [header] to [target], whole: made beside the app's
/// own files in [scratch], then written over [target] in place (or made,
/// the first time), so a sync service sees one file with a new version. A
/// null [key] writes it plain (tests).
Future<void> writeChangeFile(
  FolderIo io,
  String folder,
  String name,
  Uint8List? key,
  ChangeFileHeader header,
  List<ChangeRow> rows, {
  required Directory scratch,
}) async {
  await scratch.create(recursive: true);
  final made = File('${scratch.path}/$name.tmp');
  if (made.existsSync()) await made.delete();
  final db = sqlite3.open(made.path);
  try {
    if (key != null) applyCipherKey(db, key);
    withoutKeyInErrors(() {
      db.execute(
        'CREATE TABLE computer (id TEXT NOT NULL, name TEXT, ledger TEXT, '
        'schema INTEGER NOT NULL, applied TEXT NOT NULL, '
        'first_seq INTEGER NOT NULL, last_seq INTEGER NOT NULL, '
        'written_at TEXT NOT NULL, notes_applied INTEGER NOT NULL, '
        'knows_cuts INTEGER NOT NULL)',
      );
      db.execute(
        'CREATE TABLE changes (seq INTEGER PRIMARY KEY, tbl TEXT NOT NULL, '
        'pk TEXT NOT NULL, op TEXT NOT NULL, before TEXT, after TEXT, '
        'at_ms INTEGER NOT NULL, with_schema INTEGER NOT NULL)',
      );
      db.execute('BEGIN');
      db.execute('INSERT INTO computer VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', [
        header.computer,
        header.name,
        header.ledger,
        header.schema,
        encodeApplied(header.applied),
        firstSeqOf(rows),
        header.lastSeq,
        header.writtenAt.toIso8601String(),
        // Its log writes down what it applied ([appliedMarkerOp]): no note
        // before a change means nothing applied, not "unknown".
        1,
        // It knows a cut (step 5).
        1,
      ]);
      final insert = db.prepare(
        'INSERT INTO changes VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      );
      try {
        for (final r in rows) {
          insert.execute([
            r.seq,
            r.tbl,
            r.pk,
            r.op,
            r.before,
            r.after,
            r.atMs,
            r.withSchema,
          ]);
        }
      } finally {
        insert.close();
      }
      db.execute('COMMIT');
    });
  } finally {
    db.close();
  }
  try {
    await io.write(folder, name, await made.readAsBytes());
  } finally {
    if (made.existsSync()) await made.delete();
  }
}

/// Reads a computer's change file: its header and the changes after
/// [afterSeq]. Throws when [key] doesn't open it or it isn't one
/// (half-arrived, or another ledger's).
ChangeFile readChangeFile(File file, Uint8List? key, {int afterSeq = 0}) {
  final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    if (key != null) applyCipherKey(db, key);
    return withoutKeyInErrors(() {
      final c = db.select('SELECT * FROM computer').single;
      final header = ChangeFileHeader(
        computer: c['id'] as String,
        name: c['name'] as String?,
        ledger: c['ledger'] as String?,
        schema: c['schema'] as int,
        applied: parseApplied(c['applied'] as String?),
        firstSeq: c['first_seq'] as int,
        lastSeq: c['last_seq'] as int,
        writtenAt:
            DateTime.tryParse(c['written_at'] as String) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        knowsCuts: c.containsKey('knows_cuts') && c['knows_cuts'] == 1,
      );
      final changes = [
        for (final r in db.select(
          'SELECT * FROM changes WHERE seq > ? ORDER BY seq',
          [afterSeq],
        ))
          ChangeRecord(
            seq: r['seq'] as int,
            tbl: r['tbl'] as String,
            pk: ChangeRecord._json(r['pk'] as String?) ?? const {},
            op: r['op'] as String,
            before: ChangeRecord._json(r['before'] as String?),
            after: ChangeRecord._json(r['after'] as String?),
            atMs: r['at_ms'] as int,
          ),
      ];
      final before = db.select(
        'SELECT after FROM changes WHERE op = ? AND seq <= ? '
        'ORDER BY seq DESC LIMIT 1',
        [appliedMarkerOp, afterSeq],
      );
      Map<String, int>? knewBefore;
      final notes = c.containsKey('notes_applied') && c['notes_applied'] == 1;
      if (before.isNotEmpty) {
        knewBefore = ChangeRecord(
          seq: 0,
          tbl: '',
          pk: const {},
          op: appliedMarkerOp,
          before: null,
          after: ChangeRecord._json(before.single['after'] as String?),
          atMs: 0,
        ).vector;
      } else if (notes) {
        knewBefore = const {};
      }
      return ChangeFile(header, changes, knewBefore: knewBefore);
    });
  } finally {
    db.close();
  }
}

/// Every other computer's change file in [folder] that [key] opens, read
/// from a copy in [scratch] so nothing is opened inside the folder a sync
/// app is watching. [afterSeq] says, by computer, what is already applied.
/// A file that can't be read (still arriving) is named in [unreadable] and
/// left for the next look.
Future<List<ChangeFile>> readChangeFiles(
  FolderIo io,
  String folder,
  Uint8List? key, {
  required Directory scratch,
  required String butComputer,
  required Map<String, int> afterSeq,
  List<String>? unreadable,
  String? ledger,
}) async {
  // One file a computer: a sync service's copy of one ("Computer abc (1)…")
  // is the same computer's, never a new one read from its start (#662). Of
  // two, the one of this [ledger], then the one further along, then the one
  // under its own name.
  final found = <String, ChangeFile>{};
  final ownName = <String, bool>{};
  final failed = <String>{};
  final names = [
    for (final n in await io.names(folder))
      if (isChangeFileName(n)) n,
  ]..sort();
  for (final name in names) {
    final computer = computerOfChangeFile(name);
    if (computer == null || computer == butComputer) continue;
    final copy = File('${scratch.path}/$name');
    try {
      final bytes = await io.read(folder, name);
      if (bytes == null) continue;
      await scratch.create(recursive: true);
      await copy.writeAsBytes(bytes, flush: true);
      var f = readChangeFile(copy, key, afterSeq: afterSeq[computer] ?? 0);
      // Whose it is, by its own header: read again from where that
      // computer's changes are applied up to, when the name said otherwise.
      final whose = f.header.computer;
      if (whose == butComputer) continue;
      if (whose != computer) {
        f = readChangeFile(copy, key, afterSeq: afterSeq[whose] ?? 0);
      }
      final mine = name == changeFileName(whose);
      final other = found[whose];
      if (other == null || _before(f, mine, other, ownName[whose]!, ledger)) {
        found[whose] = f;
        ownName[whose] = mine;
      }
    } catch (e) {
      debugPrint('A computer’s change file couldn’t be read: $e');
      failed.add(computer);
    } finally {
      if (copy.existsSync()) copy.deleteSync();
    }
  }
  // Unreadable only when no file of that computer's could be read: a copy
  // that never will (cut short) doesn't hold the look up for good.
  unreadable?.addAll(failed.where((c) => !found.containsKey(c)));
  return [...found.values];
}

/// Whether [a] (under its computer's own name: [aOwn]) is read rather
/// than [b]: of this [ledger] first, then further along, then written
/// later, then the one under the computer's own name.
bool _before(ChangeFile a, bool aOwn, ChangeFile b, bool bOwn, String? ledger) {
  if (ledger != null) {
    final aHere = a.header.ledger == null || a.header.ledger == ledger;
    final bHere = b.header.ledger == null || b.header.ledger == ledger;
    if (aHere != bHere) return aHere;
  }
  if (a.header.lastSeq != b.header.lastSeq) {
    return a.header.lastSeq > b.header.lastSeq;
  }
  if (a.header.writtenAt != b.header.writtenAt) {
    return a.header.writtenAt.isAfter(b.header.writtenAt);
  }
  return aOwn && !bOwn;
}
