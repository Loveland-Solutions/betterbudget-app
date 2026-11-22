// The phone's own whole ledger (ADR 0005, "The phone joins as another
// computer", #526 piece 2). Until now the phone only read a private copy of
// the folder's ledger, thrown away and taken again at every look. A member of
// the folder keeps a ledger of its own: written to here, with its own
// `changes` log, kept from one launch to the next. This is that ledger and
// the way into it; the phone's change file and the taking in of the others'
// are piece 3. A person who starts on the phone (#534) makes it here new, or
// from a backup file.
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';

import 'backup.dart' show Backups;
import 'database.dart';
import 'encryption.dart';
import 'keys.dart';
import 'ledger_file.dart';
import 'phone_ledger.dart';

/// Where a phone keeps its own ledger, in [dir], and how it comes to have one.
class PhoneOwnLedger {
  const PhoneOwnLedger(this.dir, this.dataKey);

  /// The folder the ledger and what is made around it live in. It is the
  /// phone's own and is never the folder the person picked.
  final Directory dir;

  /// The key every file here is encrypted with.
  final Uint8List dataKey;

  File get file => File('${dir.path}/$ledgerFileName');

  /// Whether this phone already has a ledger of its own.
  bool get exists => file.existsSync();

  AppDatabase _open(File f, String? device) {
    final db = AppDatabase(
      NativeDatabase(f, setup: (raw) => applyCipherKey(raw, dataKey)),
    );
    db.thisComputer = device;
    return db;
  }

  /// The phone's own ledger, opened as the computer [device]: what is written
  /// to it is recorded in its log as this phone's. Null when there is none
  /// yet. Throws what the database throws when it can't be read (a ledger
  /// saved by a newer version of the app).
  Future<AppDatabase?> open(String device) async {
    if (!exists) return null;
    final db = _open(file, device);
    try {
      // Opens it, and refuses a ledger from a newer build before any use.
      await db.syncState();
    } catch (_) {
      await db.close();
      rethrow;
    }
    return db;
  }

  /// Makes a new, empty ledger as this phone's own, for a person who starts
  /// on the phone (#534, "Start fresh"), and returns it opened as [device].
  /// A ledger this phone already has is never written over: it returns that
  /// one, opened. The file takes its name only once it is whole, as a join's
  /// does.
  Future<AppDatabase> create(String device) async {
    final kept = await open(device);
    if (kept != null) return kept;
    await dir.create(recursive: true);
    final made = File('${dir.path}/$ledgerFileName.creating');
    void clear() {
      for (final f in [
        made,
        File('${made.path}-wal'),
        File('${made.path}-shm'),
      ]) {
        if (f.existsSync()) f.deleteSync();
      }
    }

    clear();
    try {
      final db = _open(made, null);
      try {
        await db.syncState();
        await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      } finally {
        await db.close();
      }
      await made.rename(file.path);
    } finally {
      clear();
    }
    return (await open(device))!;
  }

  /// Makes this phone's own ledger from the backup file at [backupPath], as
  /// a computer with no ledger restores one (#534, "Restore from backup"): a
  /// new ledger is made and the backup put into it by [Backups], which
  /// refuses what it refuses on a computer (from a newer app, not a backup,
  /// not this key, damaged, no accounts) with a `RestoreException`. It is
  /// made in a folder beside [dir] and takes its place only once whole, so a
  /// refusal leaves nothing behind. Throws [StateError] when this phone
  /// already has a ledger: one is never written over.
  Future<AppDatabase> restore(
    String backupPath,
    String device,
    DateTime now,
  ) async {
    if (exists) throw StateError('This phone already has a ledger');
    final scratch = Directory('${dir.path}.restoring');
    if (scratch.existsSync()) await scratch.delete(recursive: true);
    final made = PhoneOwnLedger(scratch, dataKey);
    try {
      final db = await made.create(device);
      try {
        final backups = Backups(db, dataKey: dataKey);
        await backups.restore(await backups.inspect(backupPath, now), now);
        await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      } finally {
        await db.close();
      }
      await dir.create(recursive: true);
      await made.file.rename(file.path);
    } finally {
      if (scratch.existsSync()) await scratch.delete(recursive: true);
    }
    return (await open(device))!;
  }

  /// Takes [folderLedger], the ledger as it sits in the folder, as this
  /// phone's own, the way a second computer joins (`Backups.restore` with
  /// `fromFolder`): every row and setting comes over, the ledger keeps its id
  /// and its vector of what each computer has applied, and the log starts
  /// empty, since nothing of what is in it was made here. Throws
  /// [WrongKeyException] when [dataKey] doesn't open it. Nothing is changed
  /// when it throws, and a ledger this phone already has is never written
  /// over: it returns that one, opened.
  Future<AppDatabase> join(Uint8List folderLedger, String device) async {
    final kept = await open(device);
    if (kept != null) return kept;
    await dir.create(recursive: true);
    final scratch = await dir.createTemp('joining-');
    final incoming = File('${scratch.path}/$ledgerFileName');
    final made = File('${dir.path}/$ledgerFileName.joining');
    try {
      await incoming.writeAsBytes(folderLedger, flush: true);
      if (!keyOpens(incoming, dataKey)) throw WrongKeyException();
      // Opened as the phone's reader does, so an older ledger is upgraded and
      // a newer one is refused here and not halfway through.
      final upgraded = _open(incoming, null);
      try {
        await upgraded.syncState();
        await upgraded.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      } finally {
        await upgraded.close();
      }
      for (final f in [
        made,
        File('${made.path}-wal'),
        File('${made.path}-shm'),
      ]) {
        if (f.existsSync()) await f.delete();
      }
      final db = _open(made, device);
      try {
        await db.replaceAllFrom(
          incoming.path,
          sourceKeyBind: rawKeyLiteral(dataKey),
          fromFolder: true,
        );
        await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      } finally {
        await db.close();
      }
      // Only now is it the phone's ledger: a join cut short leaves no file
      // by that name for the next launch to take as whole.
      await made.rename(file.path);
    } finally {
      for (final f in [
        made,
        File('${made.path}-wal'),
        File('${made.path}-shm'),
      ]) {
        if (f.existsSync()) await f.delete();
      }
      await scratch.delete(recursive: true);
    }
    return (await open(device))!;
  }
}
