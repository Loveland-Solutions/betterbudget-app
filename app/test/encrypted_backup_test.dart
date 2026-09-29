// Restoring encrypted, plain, and wrong-key backups into an encrypted
// ledger, and converting leftover plain backups (ADR 0001, STATUS.md
// "Next: build it").
import 'dart:io';
import 'dart:typed_data';

import 'package:betterbudget/data/backup.dart';
import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/data/encryption.dart';
import 'package:betterbudget/data/keys.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final today = DateTime(2026, 9, 16, 9, 30);
  late Directory dir;
  late AppDatabase db;
  late Uint8List key;
  late Uint8List otherKey;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('bb-enc-backup');
    key = deriveDataKey(RecoveryKey.generate());
    otherKey = deriveDataKey(RecoveryKey.generate());
    db = AppDatabase(
      NativeDatabase(
        File('${dir.path}/betterbudget.sqlite'),
        setup: (raw) => applyCipherKey(raw, key),
      ),
    );
    await seedDemoIfEmpty(db, today);
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test('a backup made by the encrypted app stays encrypted', () async {
    final backups = Backups(db, dataKey: key);
    final saved = File('${dir.path}/saved.sqlite');
    await backups.saveTo(saved.path, today);
    expect(await isPlainSqliteFile(saved), isFalse);
  });

  test('restoring a same-key encrypted backup works', () async {
    final backups = Backups(db, dataKey: key);
    final saved = File('${dir.path}/saved.sqlite');
    await backups.saveTo(saved.path, today);
    final expectedCount = (await db.loadLedger()).txns.length;

    final candidate = await backups.inspect(
      saved.path,
      today.add(const Duration(minutes: 5)),
    );
    expect(candidate.sourceKeyBind, rawKeyLiteral(key));
    await backups.restore(candidate, today.add(const Duration(minutes: 5)));
    expect((await db.loadLedger()).txns.length, expectedCount);
  });

  test(
    'restoring a plain (pre-encryption) backup works, main db stays encrypted',
    () async {
      final plainFile = File('${dir.path}/plain.sqlite');
      final plainDb = AppDatabase(NativeDatabase(plainFile));
      await seedDemoIfEmpty(plainDb, today);
      final plainCount = (await plainDb.loadLedger()).txns.length;
      await plainDb.close();
      expect(await isPlainSqliteFile(plainFile), isTrue);

      final backups = Backups(db, dataKey: key);
      final candidate = await backups.inspect(plainFile.path, today);
      expect(candidate.sourceKeyBind, '');
      await backups.restore(candidate, today);
      expect((await db.loadLedger()).txns.length, plainCount);

      // The connection was never rekeyed: still only readable with `key`.
      final path = (await db.filePath())!;
      await db.close();
      expect(await isPlainSqliteFile(File(path)), isFalse);
      final reopened = sqlite3.open(path);
      applyCipherKey(reopened, key);
      expect(reopened.select('SELECT 1').isNotEmpty, isTrue);
      reopened.close();
    },
  );

  test(
    'undo then redo of a plain-backup restore works (the restored '
    'snapshot must itself be encrypted, not the plain file renamed)',
    () async {
      final plainFile = File('${dir.path}/plain2.sqlite');
      final plainDb = AppDatabase(NativeDatabase(plainFile));
      await seedDemoIfEmpty(plainDb, today);
      final plainCount = (await plainDb.loadLedger()).txns.length;
      await plainDb.close();

      final backups = Backups(db, dataKey: key);
      final before = (await db.loadLedger()).txns.length;
      final candidate = await backups.inspect(plainFile.path, today);
      final done = await backups.restore(candidate, today);
      expect(await isPlainSqliteFile(done.restored), isFalse);
      expect(await isPlainSqliteFile(done.before), isFalse);

      // Undo.
      await backups.replaceWith(
        done.before,
        today.add(const Duration(minutes: 1)),
      );
      expect((await db.loadLedger()).txns.length, before);

      // Redo: attaches `done.restored` with the data key. This is exactly
      // where an unencrypted `restored-…` file would fail.
      await backups.replaceWith(
        done.restored,
        today.add(const Duration(minutes: 2)),
      );
      expect((await db.loadLedger()).txns.length, plainCount);
    },
  );

  test(
    'a backup under another key asks for that key, then restores under ours',
    () async {
      final otherFile = File('${dir.path}/other-key.sqlite');
      final otherDb = AppDatabase(
        NativeDatabase(
          otherFile,
          setup: (raw) => applyCipherKey(raw, otherKey),
        ),
      );
      await seedDemoIfEmpty(otherDb, today);
      await otherDb.close();

      final backups = Backups(db, dataKey: key);
      await expectLater(
        backups.inspect(otherFile.path, today),
        throwsA(isA<RestoreNeedsKeyException>()),
      );
      // A key that isn't the backup's either.
      await expectLater(
        backups.inspect(
          otherFile.path,
          today,
          backupKey: deriveDataKey(RecoveryKey.generate()),
        ),
        throwsA(
          isA<RestoreException>().having(
            (e) => e.message,
            'message',
            startsWith('That key doesn’t open this backup'),
          ),
        ),
      );
      final candidate = await backups.inspect(
        otherFile.path,
        today,
        backupKey: otherKey,
      );
      final done = await backups.restore(candidate, today);
      expect((await db.loadLedger()).txns, isNotEmpty);
      // What restore keeps for undo and redo is under this ledger's key.
      for (final f in [done.before, done.restored]) {
        expect(keyOpens(f, key), isTrue);
        expect(keyOpens(f, otherKey), isFalse);
      }
    },
  );

  test('every copy the keyed app makes is encrypted', () async {
    final backups = Backups(db, dataKey: key);
    final beforeNew = await backups.saveBeforeNewLedger(today);
    expect(keyOpens(beforeNew, key), isTrue);
    expect(await isPlainSqliteFile(beforeNew), isFalse);
    final daily = await backups.automaticIfDue(today);
    expect(keyOpens(daily!, key), isTrue);
  });

  test('a damaged old copy is reported, not allowed to stop the app', () async {
    final backups = Backups(db, dataKey: key);
    final backupsDir = (await backups.folder())!;
    await backupsDir.create(recursive: true);
    final good = File('${backupsDir.path}/betterbudget-20260101-000000.sqlite');
    sqlite3.open(good.path)
      ..execute('CREATE TABLE t (x)')
      ..close();
    // A plain header over a body that isn't a database.
    final bad = File('${backupsDir.path}/betterbudget-20260102-000000.sqlite');
    bad.writeAsBytesSync([
      ...'SQLite format 3'.codeUnits,
      0,
      ...List.filled(4000, 7),
    ]);
    final report = await backups.convertPlainBackups();
    expect(report.converted, 1);
    expect(report.failed.map((f) => f.path), [bad.path]);
    expect(keyOpens(good, key), isTrue);
  });

  test(
    'convertPlainBackups converts old plain copies, leaves the rest',
    () async {
      final backups = Backups(db, dataKey: key);
      final backupsDir = (await backups.folder())!;
      await backupsDir.create(recursive: true);

      final legacy = File(
        '${backupsDir.path}/betterbudget-20260101-000000.sqlite',
      );
      final legacyDb = sqlite3.open(legacy.path)..execute('CREATE TABLE t (x)');
      legacyDb.close();

      final already = File(
        '${backupsDir.path}/betterbudget-20260102-000000.sqlite',
      );
      final encDb = sqlite3.open(already.path);
      applyCipherKey(encDb, key);
      encDb.execute('CREATE TABLE t (x)');
      encDb.close();

      // Copies made before a schema upgrade sit beside the database, and an
      // older folder of copies may too: none may stay readable.
      final home = File((await db.filePath())!).parent.path;
      final upgrade = File('$home/betterbudget.before-v6-from-v5-x.sqlite');
      final older = File('$home/backup-before-v2/betterbudget.sqlite');
      await older.parent.create();
      for (final f in [upgrade, older]) {
        sqlite3.open(f.path)
          ..execute('CREATE TABLE t (x)')
          ..close();
      }

      final report = await backups.convertPlainBackups();
      expect(report.converted, 3);
      expect(report.failed, isEmpty);
      expect(await isPlainSqliteFile(legacy), isFalse);
      expect(await isPlainSqliteFile(upgrade), isFalse);
      expect(await isPlainSqliteFile(older), isFalse);
      expect(await isPlainSqliteFile(already), isFalse);

      // The already-encrypted one is untouched: still opens with the same key.
      final reopened = sqlite3.open(already.path);
      applyCipherKey(reopened, key);
      expect(() => reopened.select('SELECT x FROM t'), returnsNormally);
      reopened.close();
    },
  );

  test('convertPlainBackups does nothing without a data key', () async {
    final plainDb = AppDatabase(
      NativeDatabase(File('${dir.path}/plain-main.sqlite')),
    );
    await seedDemoIfEmpty(plainDb, today);
    final backups = Backups(plainDb);
    await backups.automaticIfDue(today);
    expect((await backups.convertPlainBackups()).converted, 0);
    await plainDb.close();
  });
}
