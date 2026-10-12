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

/// Not a ledger, so not the ledger's extension; not a phone's either.
const changeFileExtension = 'betterbudget-changes';

/// The name of the file the computer with id [computer] writes.
String changeFileName(String computer) =>
    'Computer $computer.$changeFileExtension';

bool isChangeFileName(String name) =>
    name.startsWith('Computer ') && name.endsWith('.$changeFileExtension');

/// The computer id a change file's name carries.
String? computerOfChangeFile(String name) => isChangeFileName(name)
    ? name.substring(
        'Computer '.length,
        name.length - changeFileExtension.length - 1,
      )
    : null;

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

  /// When, by the writer's clock, for the screen only.
  final DateTime writtenAt;
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
  const ChangeFile(this.header, this.changes);
  final ChangeFileHeader header;

  /// Oldest first.
  final List<ChangeRecord> changes;
}

/// Writes [rows] with [header] to [target], whole: made beside the app's
/// own files in [scratch], then written over [target] in place (or made,
/// the first time), so a sync service sees one file with a new version. A
/// null [key] writes it plain (tests).
Future<void> writeChangeFile(
  File target,
  Uint8List? key,
  ChangeFileHeader header,
  List<ChangeRow> rows, {
  required Directory scratch,
}) async {
  await scratch.create(recursive: true);
  final made = File('${scratch.path}/${target.uri.pathSegments.last}.tmp');
  if (made.existsSync()) await made.delete();
  final db = sqlite3.open(made.path);
  try {
    if (key != null) applyCipherKey(db, key);
    withoutKeyInErrors(() {
      db.execute(
        'CREATE TABLE computer (id TEXT NOT NULL, name TEXT, ledger TEXT, '
        'schema INTEGER NOT NULL, applied TEXT NOT NULL, '
        'first_seq INTEGER NOT NULL, last_seq INTEGER NOT NULL, '
        'written_at TEXT NOT NULL)',
      );
      db.execute(
        'CREATE TABLE changes (seq INTEGER PRIMARY KEY, tbl TEXT NOT NULL, '
        'pk TEXT NOT NULL, op TEXT NOT NULL, before TEXT, after TEXT, '
        'at_ms INTEGER NOT NULL, with_schema INTEGER NOT NULL)',
      );
      db.execute('BEGIN');
      db.execute('INSERT INTO computer VALUES (?, ?, ?, ?, ?, ?, ?, ?)', [
        header.computer,
        header.name,
        header.ledger,
        header.schema,
        encodeApplied(header.applied),
        rows.isEmpty ? 0 : rows.first.seq,
        header.lastSeq,
        header.writtenAt.toIso8601String(),
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
    await replaceFileBytes(target, await made.readAsBytes());
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
      return ChangeFile(header, changes);
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
  Directory folder,
  Uint8List? key, {
  required Directory scratch,
  required String butComputer,
  required Map<String, int> afterSeq,
  List<String>? unreadable,
}) async {
  final found = <ChangeFile>[];
  if (!folder.existsSync()) return found;
  final files = [
    await for (final f in folder.list())
      if (f is File && isChangeFileName(f.uri.pathSegments.last)) f,
  ]..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    final name = f.uri.pathSegments.last;
    final computer = computerOfChangeFile(name);
    if (computer == null || computer == butComputer) continue;
    final copy = File('${scratch.path}/$name');
    try {
      await scratch.create(recursive: true);
      await f.copy(copy.path);
      found.add(readChangeFile(copy, key, afterSeq: afterSeq[computer] ?? 0));
    } catch (e) {
      debugPrint('A computer’s change file couldn’t be read: $e');
      unreadable?.add(computer);
    } finally {
      if (copy.existsSync()) copy.deleteSync();
    }
  }
  return found;
}

/// [bytes] written over [file] where it is, not beside it and renamed, so a
/// sync service sees the same file with a new version and never a second
/// one. Made when there is none.
Future<void> replaceFileBytes(File file, List<int> bytes) async {
  final out = await file.open(mode: FileMode.write);
  try {
    await out.writeFrom(bytes);
    await out.flush();
  } finally {
    await out.close();
  }
}
