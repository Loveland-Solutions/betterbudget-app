import 'dart:io';

import 'package:betterbudget/data/backup.dart';
import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The copies are opened as second databases to read them back.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final today = DateTime(2026, 9, 16, 9, 30);
  late Directory dir;
  late AppDatabase db;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('bb-backup');
    db = AppDatabase(NativeDatabase(File('${dir.path}/betterbudget.sqlite')));
    await seedDemoIfEmpty(db, today);
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<int> transactionsIn(File file) async {
    final copy = AppDatabase(NativeDatabase(file));
    try {
      return (await copy.loadLedger()).txns.length;
    } finally {
      await copy.close();
    }
  }

  test('one automatic copy a day, the newest kept', () async {
    final backups = Backups(db, keep: 3);
    final first = await backups.automaticIfDue(today);
    expect(first, isNotNull);
    expect(
      first!.path,
      endsWith('Backups/betterbudget-20260916-093000.sqlite'),
    );
    expect(await transactionsIn(first), (await db.loadLedger()).txns.length);

    // Opened again the same day: nothing new.
    expect(
      await backups.automaticIfDue(today.add(const Duration(hours: 5))),
      isNull,
    );

    for (var d = 1; d <= 4; d++) {
      expect(
        await backups.automaticIfDue(today.add(Duration(days: d))),
        isNotNull,
      );
    }
    final kept = await backups.automatic();
    // The newest 3, and the first of the month.
    expect(kept.map((f) => f.path.split('/').last), [
      'betterbudget-20260920-093000.sqlite',
      'betterbudget-20260919-093000.sqlite',
      'betterbudget-20260918-093000.sqlite',
      'betterbudget-20260916-093000.sqlite',
    ]);
  });

  test('back up to a chosen file, replacing one already there', () async {
    final target = File('${dir.path}/elsewhere/BetterBudget 2026.09.16.sqlite');
    await target.parent.create();
    await target.writeAsString('an older file');
    await Backups(db).saveTo(target.path, today);
    expect(await transactionsIn(target), (await db.loadLedger()).txns.length);
    // Nothing left behind in the app's folder but the (empty) Backups folder.
    expect(Directory('${dir.path}/Backups').listSync(), isEmpty);
  });

  test('a copy cut short is cleaned up and does not count', () async {
    final backups = Backups(db, keep: 3);
    final folder = (await backups.folder())!..createSync();
    File('${folder.path}/betterbudget-20260916-080000.sqlite.tmp')
        .writeAsStringSync('half a copy');
    expect(await backups.automaticIfDue(today), isNotNull);
    expect(folder.listSync().map((f) => f.path.split('/').last), [
      'betterbudget-20260916-093000.sqlite',
    ]);
  });

  test('keeps 14 daily copies and the first of each of 12 months', () {
    // A copy every day for 400 days, newest first.
    final start = DateTime(2025, 8, 1, 9);
    final names = [
      for (var d = 399; d >= 0; d--)
        'betterbudget-${fileStamp(start.add(Duration(days: d)))}.sqlite',
    ];
    final gone = Backups.expired(names, keep: 14, months: 12).toSet();
    final kept = names.where((n) => !gone.contains(n)).toList();
    // The newest 14 days: 2026-08-22 … 2026-09-04.
    expect(kept.take(14), names.take(14));
    expect(kept.skip(14), [
      for (final m in [
        '20260801', '20260701', '20260601', '20260501', '20260401', //
        '20260301', '20260201', '20260101', '20251201', '20251101',
        '20251001',
      ])
        'betterbudget-$m-090000.sqlite',
    ]);
    // September's first copy is already among the newest 14.
    expect(kept, hasLength(25));
  });

  test(
    'a failing daily copy says so once the newest is two days old',
    () async {
      final backups = Backups(db);
      await backups.runDaily(today);
      expect(backups.health.value.failed, isFalse);
      expect(backups.health.value.newest, DateTime(2026, 9, 16, 9, 30));

      // Something where the folder should be: every copy now fails.
      final folder = (await backups.folder())!;
      await folder.delete(recursive: true);
      await File(folder.path).writeAsString('in the way');
      await backups.runDaily(today.add(const Duration(days: 1)));
      final health = backups.health.value;
      expect(health.failed, isTrue);
      expect(health.newest, isNull);
      expect(health.alarmingAt(today.add(const Duration(days: 1))), isTrue);
      // A failure with a recent copy isn't worth a warning yet.
      expect(
        BackupHealth(
          newest: today,
          failed: true,
        ).alarmingAt(today.add(const Duration(days: 1))),
        isFalse,
      );
    },
  );

  group('restore', () {
    Future<int> count() async => (await db.loadLedger()).txns.length;

    test('puts a backup back, and the data from before can return', () async {
      final backups = Backups(db);
      final saved = File('${dir.path}/saved.sqlite');
      await backups.saveTo(saved.path, today);
      final inBackup = await count();

      final ledger = await db.loadLedger();
      final checking = ledger.balanceSheetAccounts.first.id;
      await db.postSimple(
        accountId: checking,
        date: today,
        today: today,
        payee: 'After the backup',
        counterAccountId: ledger.categories.first.id,
        amount: -500000,
      );
      expect(await count(), inBackup + 1);

      final candidate = await backups.inspect(
        saved.path,
        today.add(const Duration(minutes: 5)),
      );
      expect(candidate.transactions, inBackup);
      expect(candidate.accounts, 4);
      final done = await backups.restore(
        candidate,
        today.add(const Duration(minutes: 5)),
      );
      expect(await count(), inBackup);
      expect(
        (await db.loadLedger()).txns.where(
          (t) => t.payee == 'After the backup',
        ),
        isEmpty,
      );
      // The picked file is untouched and nothing is left half-done.
      expect(await transactionsIn(saved), inBackup);
      expect(
        (await backups.folder())!
            .listSync()
            .map((f) => f.path.split('/').last)
            .where((n) => n.startsWith('incoming-')),
        isEmpty,
      );

      await db.replaceAllFrom(done.before.path); // undo
      expect(await count(), inBackup + 1);
      await db.replaceAllFrom(done.restored.path); // redo
      expect(await count(), inBackup);
      // Every stored transaction still sums to zero.
      final unbalanced = await db
          .customSelect(
            'SELECT transaction_id FROM entries GROUP BY transaction_id '
            'HAVING SUM(amount_minor) != 0',
          )
          .get();
      expect(unbalanced, isEmpty);
    });

    test(
      'refuses a damaged backup, and a failed replace changes nothing',
      () async {
        final backups = Backups(db);
        Future<File> tampered(String name, String sql) async {
          final f = File('${dir.path}/$name.sqlite');
          await backups.saveTo(f.path, today);
          final other = AppDatabase(NativeDatabase(f));
          await other.customStatement('PRAGMA foreign_keys = OFF');
          await other.customStatement(sql);
          await other.close();
          return f;
        }

        final unbalanced = await tampered(
          'unbalanced',
          'UPDATE entries SET amount_minor = amount_minor + 777 '
              'WHERE id = (SELECT MIN(id) FROM entries)',
        );
        final orphan = await tampered(
          'orphan',
          'UPDATE entries SET account_id = 9999 '
              'WHERE id = (SELECT MIN(id) FROM entries)',
        );
        for (final f in [unbalanced, orphan]) {
          await expectLater(
            backups.inspect(f.path, today),
            throwsA(
              isA<RestoreException>().having(
                (e) => e.message,
                'message',
                'That backup is damaged',
              ),
            ),
          );
        }

        // Past the check (a file changed after it), the replace still refuses
        // and rolls back whole.
        final before = await count();
        await expectLater(
          db.replaceAllFrom(unbalanced.path),
          throwsA(isA<UnbalancedTransactionException>()),
        );
        await expectLater(db.replaceAllFrom(orphan.path), throwsA(anything));
        expect(await count(), before);
        expect(await db.customSelect(AppDatabase.unbalancedSql).get(), isEmpty);
        // Still writable, and detached.
        await db.customStatement('UPDATE accounts SET sort_order = sort_order');
      },
    );

    test('undoing a restore saves what is there first', () async {
      final backups = Backups(db);
      final saved = File('${dir.path}/saved.sqlite');
      await backups.saveTo(saved.path, today);
      final done = await backups.restore(
        await backups.inspect(saved.path, today),
        today,
      );
      await backups.replaceWith(done.before, today);
      final saves =
          (await backups.folder())!
              .listSync()
              .map((f) => f.path.split('/').last)
              .where((n) => n.startsWith('before-restore-'))
              .toList()
            ..sort();
      // The same second twice: the second name moves on a second.
      expect(saves, [
        'before-restore-20260916-093000.sqlite',
        'before-restore-20260916-093001.sqlite',
      ]);
    });

    test('refuses what it can’t restore, and cleans up', () async {
      final backups = Backups(db);
      final text = File('${dir.path}/notes.sqlite')
        ..writeAsStringSync('not a database, just long enough ' * 5);
      await expectLater(
        backups.inspect(text.path, today),
        throwsA(
          isA<RestoreException>().having(
            (e) => e.message,
            'message',
            'That file isn’t a BetterBudget backup',
          ),
        ),
      );

      final newer = File('${dir.path}/newer.sqlite');
      await backups.saveTo(newer.path, today);
      final other = AppDatabase(NativeDatabase(newer));
      await other.customStatement('PRAGMA user_version = 99');
      await other.close();
      await expectLater(
        backups.inspect(newer.path, today),
        throwsA(isA<RestoreException>()),
      );

      final fine = File('${dir.path}/fine.sqlite');
      await backups.saveTo(fine.path, today);
      await backups.discard(await backups.inspect(fine.path, today));
      expect(
        (await backups.folder())!.listSync().where(
          (f) => f.path.split('/').last.startsWith('incoming-'),
        ),
        isEmpty,
      );
    });
  });

  test('an in-memory database has nothing to back up', () async {
    final memory = AppDatabase(NativeDatabase.memory());
    addTearDown(memory.close);
    expect(await Backups(memory).automaticIfDue(today), isNull);
  });
}
