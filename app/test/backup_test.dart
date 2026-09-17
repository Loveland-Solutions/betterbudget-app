import 'dart:io';

import 'package:betterbudget/data/backup.dart';
import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    expect(kept.map((f) => f.path.split('/').last), [
      'betterbudget-20260920-093000.sqlite',
      'betterbudget-20260919-093000.sqlite',
      'betterbudget-20260918-093000.sqlite',
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

  test('an in-memory database has nothing to back up', () async {
    final memory = AppDatabase(NativeDatabase.memory());
    addTearDown(memory.close);
    expect(await Backups(memory).automaticIfDue(today), isNull);
  });
}
