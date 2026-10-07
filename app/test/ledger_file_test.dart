// The ledger's file names (`data/ledger_file.dart`): a ledger under its
// earlier name, `betterbudget.sqlite`, is renamed once, with everything in it.
import 'dart:io';

import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/data/ledger_file.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('bb-name'));
  tearDown(() => dir.delete(recursive: true));

  File earlier() => File('${dir.path}/$earlierLedgerFileName');
  File ledger() => File('${dir.path}/$ledgerFileName');

  /// A ledger under the earlier name as a killed app leaves it: rows in the
  /// file, and newer rows still only in the `-wal` beside it.
  Future<void> leftByAKilledApp() async {
    final work = await Directory('${dir.path}/work').create();
    final db = sqlite3.open('${work.path}/x');
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('CREATE TABLE rows (n INTEGER)');
    db.execute('INSERT INTO rows VALUES (1), (2)');
    db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    db.execute('PRAGMA wal_autocheckpoint = 0');
    db.execute('INSERT INTO rows VALUES (3)');
    // Copied while open, so the last row is in the -wal alone.
    await File('${work.path}/x').copy(earlier().path);
    await File('${work.path}/x-wal').copy('${earlier().path}-wal');
    await File('${work.path}/x-shm').copy('${earlier().path}-shm');
    db.close();
    await work.delete(recursive: true);
  }

  int rowsIn(File file) {
    final db = sqlite3.open(file.path);
    try {
      return db.select('SELECT count(*) AS c FROM rows').single['c'] as int;
    } finally {
      db.close();
    }
  }

  test('the names', () {
    expect(ledgerFileName, 'Ledger.betterbudget');
    expect(withoutLedgerExtension('Ledger.betterbudget'), 'Ledger');
    expect(withoutLedgerExtension('betterbudget.sqlite'), 'betterbudget');
    expect(withoutLedgerExtension('notes.txt'), 'notes.txt');
  });

  test('a new computer: the new name, and nothing made', () async {
    final file = await ledgerFileIn(dir);
    expect(file.path, ledger().path);
    expect(dir.listSync(), isEmpty);
  });

  test('a ledger under the earlier name is renamed with every row', () async {
    final db = AppDatabase(NativeDatabase(earlier()));
    await seedDemoIfEmpty(db, DateTime(2026, 10, 7));
    final before = await db.loadLedger();
    await db.close();
    final size = earlier().lengthSync();

    final file = await ledgerFileIn(dir);
    expect(file.path, ledger().path);
    expect(earlier().existsSync(), isFalse);
    expect(file.lengthSync(), size);

    final reopened = AppDatabase(NativeDatabase(file));
    final after = await reopened.loadLedger();
    await reopened.close();
    expect(after.txns.length, before.txns.length);
    expect(after.accounts.length, before.accounts.length);
    expect(after.txns.length, greaterThan(0));
  });

  test('rows not yet folded into the file come along', () async {
    await leftByAKilledApp();
    final file = await ledgerFileIn(dir);
    expect(File('${earlier().path}-wal').existsSync(), isFalse);
    expect(File('${earlier().path}-shm').existsSync(), isFalse);
    expect(earlier().existsSync(), isFalse);
    expect(rowsIn(file), 3);
  });

  test('stopped halfway, the next launch finishes it', () async {
    await leftByAKilledApp();
    // The -wal had moved and the ledger hadn't.
    await File('${earlier().path}-wal').rename('${ledger().path}-wal');
    final file = await ledgerFileIn(dir);
    expect(earlier().existsSync(), isFalse);
    expect(rowsIn(file), 3);
  });

  test('run again, it changes nothing', () async {
    await leftByAKilledApp();
    final first = await ledgerFileIn(dir);
    expect(rowsIn(first), 3);
    final names = dir.listSync().map((f) => f.path).toSet();
    final again = await ledgerFileIn(dir);
    expect(again.path, first.path);
    expect(dir.listSync().map((f) => f.path).toSet(), names);
  });

  test('both names there: neither is touched', () async {
    await earlier().writeAsString('the earlier file');
    await ledger().writeAsString('the ledger');
    final file = await ledgerFileIn(dir);
    expect(file.readAsStringSync(), 'the ledger');
    expect(earlier().readAsStringSync(), 'the earlier file');
  });
}
