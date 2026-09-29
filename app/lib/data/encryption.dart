// Wires the data key from keys.dart into SQLite3 Multiple Ciphers (ADR
// 0001): applies the cipher pragmas to every connection Drift opens, and
// converts a plain file to SQLCipher v4 in place the first time it's seen.
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';

import 'keys.dart';

/// A SQLite error with its statement and arguments left out: those can
/// carry the key (`PRAGMA key`, `ATTACH … KEY ?`), and errors get logged.
class CipherException implements Exception {
  CipherException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Runs [body], turning a SQLite error into a [CipherException] that names
/// only the error, never the statement.
T withoutKeyInErrors<T>(T Function() body) {
  try {
    return body();
  } on SqliteException catch (e) {
    throw CipherException('SQLite error ${e.extendedResultCode}: ${e.message}');
  }
}

/// Sets the pragmas that make a connection read and write SQLCipher v4,
/// with the raw 256-bit key (no passphrase stretching on open). The raw-key
/// literal must be wrapped in a quoted string for `PRAGMA key` — SQLite's
/// pragma grammar takes a name, number or string, never a bare blob
/// literal, so `PRAGMA key = x'...'` is a syntax error; `PRAGMA key =
/// "x'...'"` is how SQLCipher recognizes a raw (unstretched) key (verified
/// against the linked SQLite3 Multiple Ciphers build).
void applyCipherKey(CommonDatabase db, Uint8List key) => withoutKeyInErrors(() {
  db.execute("PRAGMA cipher = 'sqlcipher'");
  db.execute('PRAGMA legacy = 4');
  db.execute('PRAGMA key = "${rawKeyLiteral(key)}"');
});

/// A plain (unencrypted) SQLite file starts with this exact 16-byte header;
/// an SQLCipher file's first page is encrypted, so it never matches.
Future<bool> isPlainSqliteFile(File file) async {
  if (!file.existsSync()) return false;
  final raf = await file.open();
  try {
    final header = await raf.read(16);
    return header.length == 16 &&
        String.fromCharCodes(header.sublist(0, 15)) == 'SQLite format 3';
  } finally {
    await raf.close();
  }
}

/// Whether [key] opens the encrypted database [file] and it reads back
/// clean. Checked before a key is stored or used, so a key that doesn't fit
/// is never kept (a lockout on every launch).
bool keyOpens(File file, Uint8List key) {
  if (!file.existsSync()) return false;
  final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    applyCipherKey(db, key);
    db.select('SELECT count(*) FROM sqlite_master');
    return true;
  } on Object {
    return false;
  } finally {
    db.close();
  }
}

/// Encrypts a plain file with [key], keeping every row, without ever
/// changing the file itself until an encrypted copy has checked out:
///
/// 1. Recent changes still in its `-wal` are folded into the file.
/// 2. A copy is encrypted (`rekey`) and checked with a fresh connection.
/// 3. The copy is renamed over the file, which is atomic.
///
/// A crash before step 3 leaves the plain file as it was, and the next
/// launch starts over. The caller puts WAL mode back on the next open
/// (`AppDatabase.migration.beforeOpen` does).
Future<void> convertPlainFileInPlace(File file, Uint8List key) async {
  final temp = File('${file.path}.encrypting');
  if (temp.existsSync()) await temp.delete();
  final plain = sqlite3.open(file.path);
  final int tables;
  try {
    withoutKeyInErrors(() {
      plain.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    });
    tables =
        plain.select('SELECT count(*) AS n FROM sqlite_master').first['n']
            as int;
  } finally {
    plain.close();
  }
  await file.copy(temp.path);
  try {
    final enc = sqlite3.open(temp.path);
    try {
      withoutKeyInErrors(() {
        enc.execute('PRAGMA journal_mode = DELETE');
        enc.execute("PRAGMA cipher = 'sqlcipher'");
        enc.execute('PRAGMA legacy = 4');
        enc.execute('PRAGMA rekey = "${rawKeyLiteral(key)}"');
      });
    } finally {
      enc.close();
    }
    final check = sqlite3.open(temp.path);
    try {
      applyCipherKey(check, key);
      final ok = check.select('PRAGMA quick_check').first.values.first;
      final n = check
          .select('SELECT count(*) AS n FROM sqlite_master')
          .first['n'];
      if (ok != 'ok' || n != tables) {
        throw CipherException(
          'The encrypted copy of ${_name(file)} didn’t check out',
        );
      }
    } finally {
      check.close();
    }
  } catch (_) {
    if (temp.existsSync()) await temp.delete();
    rethrow;
  }
  // Nothing has the file open, and the checkpoint emptied its -wal.
  for (final side in ['-wal', '-shm']) {
    final f = File('${file.path}$side');
    if (f.existsSync()) await f.delete();
  }
  await temp.rename(file.path);
}

/// An older build encrypted the file in place and kept a plain copy beside
/// it (`.before-encryption`) until it checked out. If one is still there,
/// that conversion was cut short: the file may be half encrypted. Puts the
/// plain copy back when [key] doesn't open the file, so conversion starts
/// over; removes it when the file is fine.
Future<void> recoverInterruptedConversion(File file, Uint8List key) async {
  final safety = File('${file.path}.before-encryption');
  if (!safety.existsSync()) return;
  if (await isPlainSqliteFile(file) || keyOpens(file, key)) {
    await safety.delete();
    return;
  }
  for (final side in ['-journal', '-wal', '-shm']) {
    final f = File('${file.path}$side');
    if (f.existsSync()) await f.delete();
  }
  await safety.rename(file.path);
}

/// Gets the ledger file ready to open with [key]: finishes or undoes a
/// conversion an older build cut short, and encrypts it if it's plain.
Future<void> prepareLedgerFile(File file, Uint8List key) async {
  await recoverInterruptedConversion(file, key);
  if (await isPlainSqliteFile(file)) await convertPlainFileInPlace(file, key);
}

String _name(File f) => f.path.split(Platform.pathSeparator).last;

/// What resolving the data key came back with.
sealed class DataKeyResult {}

/// The key is ready to use. [newRecoveryKey] is set only the moment it was
/// created — the one chance to show it before it's only in the secure
/// store (setup screen, ADR 0001).
class DataKeyReady extends DataKeyResult {
  DataKeyReady(this.dataKey, {this.newRecoveryKey});
  final Uint8List dataKey;
  final RecoveryKey? newRecoveryKey;
}

/// Nothing is stored on this device yet. That's either a genuinely new
/// ledger, or a second or replacement device for someone who already has a
/// recovery key (ADR 0001, "adding a device") — this device can't tell
/// the difference, so the caller must ask rather than assume either way.
class DataKeyNeedsRecoveryEntry extends DataKeyResult {
  DataKeyNeedsRecoveryEntry({required this.canPersist});

  /// Whether there's a working secure store to write the key into once the
  /// user provides or generates one. False only on Linux with no Secret
  /// Service, where nothing can be written and this is asked every launch.
  final bool canPersist;
}

/// Reads the data key from [store]. When nothing is stored yet, the caller
/// must ask the user for a recovery key (an existing one, or a new one to
/// generate) — see [DataKeyNeedsRecoveryEntry] and [useRecoveryKey].
Future<DataKeyResult> resolveDataKey(KeyStore store) async {
  try {
    final existing = await store.readDataKey();
    if (existing != null) return DataKeyReady(existing);
    return DataKeyNeedsRecoveryEntry(canPersist: true);
  } on NoSecureStoreException {
    return DataKeyNeedsRecoveryEntry(canPersist: false);
  }
}

/// Derives the data key from a recovery key the user typed or just
/// generated, storing it in [store] when [persist] is true (mirrors
/// [DataKeyNeedsRecoveryEntry.canPersist]). [isNew] set means this key was
/// just generated, not typed, so the caller should show the setup screen.
Future<DataKeyReady> useRecoveryKey(
  KeyStore store,
  RecoveryKey recovery, {
  required bool persist,
  required bool isNew,
}) async {
  final key = deriveDataKey(recovery);
  // Only the data key is kept. The recovery key is shown once and never
  // stored (owner, 2026-09-28), and HKDF can't turn the data key back into it.
  if (persist) await store.writeDataKey(key);
  return DataKeyReady(key, newRecoveryKey: isNew ? recovery : null);
}
