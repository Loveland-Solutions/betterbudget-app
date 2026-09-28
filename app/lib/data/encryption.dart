// Wires the data key from keys.dart into SQLite3 Multiple Ciphers (ADR
// 0001): applies the cipher pragmas to every connection Drift opens, and
// converts a plain file to SQLCipher v4 in place the first time it's seen.
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';

import 'keys.dart';

/// Sets the pragmas that make a connection read and write SQLCipher v4,
/// with the raw 256-bit key (no passphrase stretching on open). The raw-key
/// literal must be wrapped in a quoted string for `PRAGMA key` — SQLite's
/// pragma grammar takes a name, number or string, never a bare blob
/// literal, so `PRAGMA key = x'...'` is a syntax error; `PRAGMA key =
/// "x'...'"` is how SQLCipher recognizes a raw (unstretched) key (verified
/// against the linked SQLite3 Multiple Ciphers build).
void applyCipherKey(CommonDatabase db, Uint8List key) {
  db.execute("PRAGMA cipher = 'sqlcipher'");
  db.execute('PRAGMA legacy = 4');
  db.execute('PRAGMA key = "${rawKeyLiteral(key)}"');
}

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

/// Encrypts a plain file in place with [key], keeping every row: a plain
/// copy is made first (ADR 0001), `journal mode = DELETE` (checkpoints and
/// removes the `-wal`/`-shm` files, since `rekey` can't run in WAL mode),
/// then `cipher`, `legacy = 4`, `rekey`, then a fresh connection confirms
/// the result opens and reads back clean with [key]. The safety copy is
/// removed only after that check passes — this runs unattended on the
/// user's one real ledger file, so a crash or disk-full mid-`rekey` must
/// not be able to lose it. The caller is responsible for putting WAL mode
/// back on the next open (`AppDatabase.migration.beforeOpen` already does).
Future<void> convertPlainFileInPlace(File file, Uint8List key) async {
  final safety = File('${file.path}.before-encryption');
  if (safety.existsSync()) await safety.delete();
  await file.copy(safety.path);
  final db = sqlite3.open(file.path);
  try {
    db.execute('PRAGMA journal_mode = DELETE');
    db.execute("PRAGMA cipher = 'sqlcipher'");
    db.execute('PRAGMA legacy = 4');
    db.execute('PRAGMA rekey = "${rawKeyLiteral(key)}"');
  } finally {
    db.close();
  }
  final check = sqlite3.open(file.path);
  try {
    applyCipherKey(check, key);
    final result = check.select('PRAGMA quick_check');
    if (result.isEmpty || result.first.values.first != 'ok') {
      // The safety copy is left in place on purpose: something is wrong
      // with the just-encrypted file, so the plain original must survive.
      throw StateError(
        'Encrypted file failed quick_check after converting ${file.path}',
      );
    }
  } finally {
    check.close();
  }
  await safety.delete();
}

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
