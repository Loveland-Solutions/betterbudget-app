// Where a transaction came from (ADR 0005, "Where a row came from"): the
// words stored on the row, that a ledger from before them keeps every row,
// and that two computers that made one row each say so and compare equal.
import 'dart:io';

import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/sync.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

final _today = DateTime(2026, 10, 13);

Future<({int account, int category})> _ids(AppDatabase db) async {
  final data = await db.loadLedger();
  return (
    account: data.accounts.values
        .firstWhere((a) => a.name == 'TDB Checking')
        .id,
    category: data.accounts.values
        .firstWhere((a) => a.type == AccountType.expense)
        .id,
  );
}

TxnData _last(LedgerData data) =>
    (data.txns.toList()..sort((a, b) => a.id.compareTo(b.id))).last;

void main() {
  test('a row typed here says typed and this computer; a phone entry says '
      'the phone; a row of the app’s own says what made it', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedDemoIfEmpty(db, _today);
    final ids = await _ids(db);
    db.thisComputer = 'Tom’s MacBook Air';

    await db.postSimple(
      accountId: ids.account,
      date: _today,
      today: _today,
      payee: 'Shop',
      counterAccountId: ids.category,
      amount: -5000,
    );
    var t = (await db.loadLedger()).txns.singleWhere((t) => t.payee == 'Shop');
    expect(t.madeHow, MadeHow.typed);
    expect(t.madeOn, 'Tom’s MacBook Air');

    await db.postSimple(
      accountId: ids.account,
      date: _today,
      today: _today,
      payee: 'Taxi',
      counterAccountId: ids.category,
      amount: -3000,
      how: MadeHow.phone,
      on: '7b8abfb7',
    );
    t = (await db.loadLedger()).txns.singleWhere((t) => t.payee == 'Taxi');
    expect(t.madeHow, MadeHow.phone);
    expect(t.madeOn, '7b8abfb7');

    // A payday the app scheduled is nobody's typing.
    final scheduled = (await db.loadLedger()).txns.where(
      (t) => t.payScheduleId != null,
    );
    for (final s in scheduled) {
      expect(s.madeHow, MadeHow.scheduled);
      expect(s.madeOn, isNull);
    }
  });

  test('where a row came from is no part of what two ledgers hold: the '
      'digest is the same', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedDemoIfEmpty(db, _today);
    final before = (await db.sealState()).digest;
    await db.customStatement(
      "UPDATE transactions SET made_how = 'imported', made_on = 'Mac mini'",
    );
    expect((await db.sealState()).digest, before);
  });

  test('a v20 file upgrades with every row, none of them saying where '
      'it came from', () async {
    final dir = await Directory.systemTemp.createTemp('bb-source');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/betterbudget.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    await seedDemoIfEmpty(db, _today);
    final txns = (await db.loadLedger()).txns.length;
    final digest = (await db.sealState()).digest;
    // The triggers name the columns, so they go first (made afresh on open).
    for (final name in await db.changeTriggersPresent()) {
      await db.customStatement('DROP TRIGGER IF EXISTS temp."$name"');
    }
    await db.customStatement('ALTER TABLE transactions DROP COLUMN made_how');
    await db.customStatement('ALTER TABLE transactions DROP COLUMN made_on');
    await db.customStatement('PRAGMA user_version = 20');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    final data = await db.loadLedger();
    expect(data.txns, hasLength(txns));
    expect(
      data.txns.every((t) => t.madeHow == null && t.madeOn == null),
      isTrue,
    );
    expect((await db.sealState()).digest, digest);
    // A row made now is stamped, and the change log carries the columns.
    final ids = await _ids(db);
    db.thisComputer = 'Mac mini';
    await db.postSimple(
      accountId: ids.account,
      date: _today,
      today: _today,
      payee: 'Shop',
      counterAccountId: ids.category,
      amount: -1000,
    );
    expect(_last(await db.loadLedger()).madeOn, 'Mac mini');
    await db.close();

    final check = raw.sqlite3.open(file.path);
    addTearDown(check.close);
    expect(
      check
          .select(
            "SELECT COUNT(*) AS n FROM pragma_table_info('transactions') "
            "WHERE name IN ('made_how', 'made_on')",
          )
          .single['n'],
      2,
    );
  });
}
