// A digest of everything a ledger holds, and a look at a ledger file that
// isn't the one the app works in (ADR 0005, "Never write blind"). The digest
// says whether two ledgers hold the same thing, and whether one was changed
// since it was sealed, without a clock.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import '../domain/combine.dart' show LedgerRows;
import '../domain/sync.dart';
import 'encryption.dart';

/// Every row of every table in what [select] reads, but for the `sync.*`
/// preferences, the change log, and when each row was written
/// (`created_at`, `updated_at`), as one digest. Two computers that each
/// made the same row from the same fact (a payday, a phone's entry: one id,
/// [sharedRowId]) wrote it at different moments, and are still holding the
/// same ledger; a person's change always changes something else too. Rows and columns are put in a fixed order
/// first, so two files holding the same rows give the same digest however
/// each was made (an upgraded file's columns are in another order than a new
/// one's).
Future<String> ledgerDigest(
  Future<List<Map<String, Object?>>> Function(String sql) select,
) async {
  final tables = await ledgerTables(select);
  final out = _Collected();
  final input = sha256.startChunkedConversion(out);
  for (final table in tables) {
    final rows = await select(
      table == 'preferences'
          ? "SELECT * FROM preferences WHERE key NOT LIKE '${SyncKeys.prefix}%'"
          : 'SELECT * FROM "$table"',
    );
    final lines = [
      for (final row in rows)
        jsonEncode([
          for (final column in row.keys.toList()..sort())
            if (!_whenWritten.contains(column)) ...[
              column,
              switch (row[column]) {
                final Uint8List bytes => {'blob': base64Encode(bytes)},
                final value => value,
              },
            ],
        ]),
    ]..sort();
    input.add(utf8.encode('$table ${lines.length}\n'));
    for (final line in lines) {
      input.add(utf8.encode('$line\n'));
    }
  }
  input.close();
  return out.value.toString();
}

/// The columns that say when a row was written here, no part of what a
/// ledger holds.
const _whenWritten = {'created_at', 'updated_at'};

/// Every row of every table in what [select] reads, as [combine] compares
/// them (ADR 0005, "Combine").
Future<LedgerRows> ledgerRows(
  Future<List<Map<String, Object?>>> Function(String sql) select,
) async => {
  for (final t in await ledgerTables(select))
    t: await select('SELECT * FROM "$t"'),
};

/// The tables that are the ledger, by name: every table in the file but
/// SQLite's own and this computer's change log ([changeLogTable]), which is
/// its own and would make two ledgers holding the same rows read as two.
Future<List<String>> ledgerTables(
  Future<List<Map<String, Object?>>> Function(String sql) select,
) async => [
  for (final r in await select(
    "SELECT name FROM sqlite_master WHERE type = 'table' "
    "AND name NOT LIKE 'sqlite_%' AND name <> '$changeLogTable' ORDER BY name",
  ))
    r['name'] as String,
];

/// The rows of [file], a whole ledger that isn't the one the app works in,
/// read without changing it. A null [key] reads it plain (tests).
Future<LedgerRows> readLedgerRows(File file, Uint8List? key) async {
  final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    if (key != null) applyCipherKey(db, key);
    return await ledgerRows(
      (sql) async => withoutKeyInErrors(
        () => [for (final row in db.select(sql)) Map.of(row)],
      ),
    );
  } finally {
    db.close();
  }
}

class _Collected implements Sink<Digest> {
  late Digest value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

/// What a ledger file other than the app's own was found to hold.
class LedgerLook {
  const LedgerLook({
    required this.schemaVersion,
    required this.digest,
    required this.seal,
    required this.computers,
    required this.savedBy,
    required this.savedAt,
  });

  /// The version of the app's tables it was saved with.
  final int schemaVersion;

  /// [ledgerDigest] of what it holds now.
  final String digest;

  /// The digest it was sealed with, if a build that seals wrote it.
  final String? seal;
  final SyncComputers computers;

  /// The computer that wrote it last, by id, and when by that computer's
  /// clock: for saying so on screen only.
  final String? savedBy;
  final DateTime? savedAt;

  /// It holds exactly what the computer that sealed it wrote.
  bool get sealed => seal == digest;

  /// What the computer that wrote it last calls itself.
  String? get savedByName => savedBy == null ? null : computers.names[savedBy];
}

/// Reads [file], a whole ledger, without changing it. A null [key] reads it
/// plain (tests). Throws when [key] doesn't open it or it isn't a ledger:
/// still arriving, or another ledger's.
Future<LedgerLook> lookAtLedger(File file, Uint8List? key) async {
  final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    if (key != null) applyCipherKey(db, key);
    final version = withoutKeyInErrors(
      () => db.select('PRAGMA user_version').first.values.first as int,
    );
    final digest = await ledgerDigest(
      (sql) async => withoutKeyInErrors(
        () => [for (final row in db.select(sql)) Map.of(row)],
      ),
    );
    final prefs = withoutKeyInErrors(
      () => {
        for (final row in db.select(
          "SELECT key, value FROM preferences "
          "WHERE key LIKE '${SyncKeys.prefix}%'",
        ))
          row['key'] as String: row['value'] as String,
      },
    );
    final saved = parseSaved(prefs[SyncKeys.saved]);
    return LedgerLook(
      schemaVersion: version,
      digest: digest,
      seal: prefs[SyncKeys.seal],
      computers: SyncComputers.parse(prefs[SyncKeys.computers]),
      savedBy: saved.by,
      savedAt: saved.at,
    );
  } finally {
    db.close();
  }
}
