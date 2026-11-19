// The change log (ADR 0005, "Two computers: the way chosen, 2026-10-12",
// step 1): every row this computer changes is recorded by a trigger, with
// the row before and after by column name; what another computer changed,
// a whole ledger put in, and the sync.* settings are not.
import 'dart:convert';
import 'dart:io';

import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/domain/combine.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/phone.dart';
import 'package:betterbudget/domain/sync.dart';
import 'package:drift/drift.dart' show DriftSqlType;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 12);
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await seedDemoIfEmpty(db, today);
  });
  tearDown(() => db.close());

  Future<int> account(String name) async => (await db.loadLedger())
      .accounts
      .values
      .singleWhere((a) => a.name == name)
      .id;

  Future<List<ChangeRow>> since(int seq) => db.changesSince(seq);

  Map<String, Object?> json(String? text) =>
      (jsonDecode(text!) as Map).cast<String, Object?>();

  test(
    'every ledger table has its three triggers and is one combine knows',
    () async {
      final logged = {
        for (final t in db.allTables)
          if (t.actualTableName != changeLogTable) t.actualTableName,
      };
      expect(logged, combineOrder.toSet());
      expect(await db.changeTriggerSql(), hasLength(3 * logged.length));
      expect(await db.changeTriggersPresent(), hasLength(3 * logged.length));
      // A new ledger has an id of its own.
      expect((await db.loadLedger()).prefs[SyncKeys.ledger], hasLength(16));
      // json_object can't hold a blob: no column may be one.
      for (final t in db.allTables) {
        for (final c in t.$columns) {
          expect(c.type, isNot(DriftSqlType.blob), reason: c.name);
        }
      }
    },
  );

  test(
    'the seed is recorded, and a purchase is its rows by column name',
    () async {
      final before = await db.lastChangeSeq();
      expect(before, greaterThan(0));
      final checking = await account('TDB Checking');
      final groceries = await account('Groceries');
      final id = await db.postSimple(
        accountId: checking,
        date: today,
        today: today,
        payee: 'Nomin',
        counterAccountId: groceries,
        amount: -45000,
      );
      final rows = await since(before);
      final txn = rows.singleWhere((r) => r.tbl == 'transactions');
      expect(txn.op, 'insert');
      expect(txn.before, isNull);
      expect(json(txn.pk), {'id': id});
      expect(json(txn.after)['date'], '2026-10-12');
      expect(json(txn.after).keys, contains('payee_id'));
      // A bool is 0 or 1, an empty column null.
      expect(json(txn.after)['scheduled'], 0);
      expect(json(txn.after)['memo'], isNull);
      final entries = rows.where((r) => r.tbl == 'entries').toList();
      expect(entries, hasLength(2));
      expect(
        entries.map((e) => json(e.after)['amount_minor']),
        containsAll([-45000, 45000]),
      );
      expect(entries.every((e) => e.withSchema == db.schemaVersion), isTrue);
      expect(entries.every((e) => e.atMs > 0), isTrue);
      // Each in the order it was made.
      expect(rows.map((r) => r.seq), rows.map((r) => r.seq).toList()..sort());
    },
  );

  test('a change is the row before and after; one that changed nothing '
      'is not recorded; a delete keeps the row before', () async {
    final checking = await account('TDB Checking');
    final groceries = await account('Groceries');
    final id = await db.postSimple(
      accountId: checking,
      date: today,
      today: today,
      payee: 'Nomin',
      counterAccountId: groceries,
      amount: -45000,
    );
    final other = (await db.loadLedger()).accounts.values.firstWhere(
      (a) => a.type == AccountType.expense && a.name != 'Groceries',
    );
    var mark = await db.lastChangeSeq();
    await db.setCategory(
      transactionId: id,
      accountId: checking,
      categoryId: other.id,
    );
    final moved = (await since(mark))
        .singleWhere((r) => r.tbl == 'entries' && r.op == 'update');
    expect(json(moved.before)['account_id'], groceries);
    expect(json(moved.after)['account_id'], other.id);

    mark = await db.lastChangeSeq();
    await db.setPreference('a.setting', 'x');
    await db.setPreference('a.setting', 'x');
    final prefs = await since(mark);
    expect(prefs, hasLength(1));
    expect(prefs.single.op, 'insert');
    expect(json(prefs.single.pk), {'key': 'a.setting'});

    mark = await db.lastChangeSeq();
    await db.setPreference('a.setting', null);
    final gone = (await since(mark)).single;
    expect(gone.op, 'delete');
    expect(json(gone.before), {'key': 'a.setting', 'value': 'x'});
    expect(gone.after, isNull);
  });

  test('the sync.* settings are each computer’s own: never recorded', () async {
    final mark = await db.lastChangeSeq();
    await db.setPreference(SyncKeys.seal, 'abc');
    await db.setPreference(SyncKeys.seal, 'def');
    await db.setPreference(SyncKeys.seal, null);
    await db.setPreference(SyncKeys.applied, '{}');
    expect(await since(mark), isEmpty);
  });

  test(
    'what another computer changed is applied without being recorded',
    () async {
      final mark = await db.lastChangeSeq();
      final digest = (await db.sealState()).digest;
      await db.applyCombined([
        RowOp.insert('payees', {'id': 123456789012, 'name': 'From the laptop'}),
      ], onlyIfDigest: digest);
      expect(
        await db
            .customSelect("SELECT 1 FROM payees WHERE name = 'From the laptop'")
            .get(),
        hasLength(1),
      );
      expect(await since(mark), isEmpty);
      // And this computer's next change is recorded again.
      await db.setPreference('a.setting', 'x');
      expect(await since(mark), hasLength(1));
      // A batch the ledger refuses releases the hold too.
      final after = await db.lastChangeSeq();
      await expectLater(
        db.applyCombined([
          RowOp.insert('entries', {
            'id': 5,
            'transaction_id': 999999,
            'account_id': 999999,
            'amount_minor': 1,
            'currency': 'MNT',
            'rate': null,
            'cleared': 0,
            'reconciliation_id': null,
            'import_key': null,
          }),
        ], onlyIfDigest: (await db.sealState()).digest),
        throwsA(isA<CantCombineException>()),
      );
      await db.setPreference('a.setting', 'y');
      expect(await since(after), hasLength(1));
    },
  );

  test('a restore of this ledger is its differences, row by row, and keeps '
      'this computer’s sync settings; the folder’s own ledger taken in is '
      'nothing', () async {
    final dir = await Directory.systemTemp.createTemp('bb-changes');
    addTearDown(() => dir.delete(recursive: true));
    final copy = '${dir.path}/copy.betterbudget';
    await db.copyTo(copy);
    // The same ledger put back with nothing changed: nothing to say.
    var mark = await db.lastChangeSeq();
    await db.replaceAllFrom(copy);
    expect(await since(mark), isEmpty);

    // A purchase, a renamed account and this computer's own settings moved
    // on since the copy.
    await db.postSimple(
      accountId: await account('TDB Checking'),
      date: today,
      today: today,
      payee: 'Nomin',
      counterAccountId: await account('Groceries'),
      amount: -1250000,
    );
    await db.renameAccount(await account('Cash wallet'), 'Wallet');
    await db.setPreference(SyncKeys.applied, '{"laptop":7}');
    final id = (await db.loadLedger()).prefs[SyncKeys.ledger];
    mark = await db.lastChangeSeq();
    await db.replaceAllFrom(copy);
    final rows = await since(mark);
    // Each row put back is a change of its own: the purchase's
    // transaction and entries (and its payee) go, the account's name goes
    // back. No marker.
    expect(rows.map((r) => r.op), isNot(contains('restore')));
    expect(rows.where((r) => r.tbl == 'transactions').map((r) => r.op), [
      'delete',
    ]);
    expect(rows.where((r) => r.tbl == 'entries').map((r) => r.op).toSet(), {
      'delete',
    });
    final renamed = rows.singleWhere((r) => r.tbl == 'accounts');
    expect(renamed.op, 'update');
    expect(json(renamed.before)['name'], 'Wallet');
    expect(json(renamed.after)['name'], 'Cash wallet');
    final ledger = await db.loadLedger();
    expect(ledger.txns.map((t) => t.payee), isNot(contains('Nomin')));
    // This ledger's own: its id and what it has applied stay.
    expect(ledger.prefs[SyncKeys.ledger], id);
    expect(ledger.prefs[SyncKeys.applied], '{"laptop":7}');

    // The folder's own ledger taken in is nothing of this computer's.
    mark = await db.lastChangeSeq();
    await db.replaceAllFrom(copy, fromFolder: true);
    expect(await since(mark), isEmpty);
  });

  test('a restore and its take-back pass a unique name or bank match moved '
      'from one row to another', () async {
    final dir = await Directory.systemTemp.createTemp('bb-changes');
    addTearDown(() => dir.delete(recursive: true));
    await db.customStatement(
      "INSERT INTO payees (id, name) VALUES (900001, 'PA'), (900002, 'PB')",
    );
    final copy = '${dir.path}/copy.betterbudget';
    await db.copyTo(copy);
    await db.customStatement(
      "UPDATE payees SET name = 'PA2' WHERE id = 900001",
    );
    await db.customStatement("UPDATE payees SET name = 'PA' WHERE id = 900002");
    final changed = '${dir.path}/changed.betterbudget';
    await db.copyTo(changed);
    Future<List<String>> names() async => [
      for (final r
          in await db
              .customSelect(
                'SELECT name FROM payees WHERE id IN (900001, 900002) ORDER BY id',
              )
              .get())
        r.read<String>('name'),
    ];
    final ran = (await db.replaceAllFrom(copy))!;
    expect(await names(), ['PA', 'PB']);
    final back = await db.revertChanges(ran);
    expect(await names(), ['PA2', 'PA']);
    await db.revertChanges(back);
    expect(await names(), ['PA', 'PB']);
    await db.replaceAllFrom(changed);
    expect(await names(), ['PA2', 'PA']);

    // A bank match moved from one entry to another.
    final two = (await db.loadLedger()).txns
        .expand((t) => t.entries)
        .take(2)
        .map((e) => e.id)
        .toList();
    await db.customStatement(
      "UPDATE entries SET import_key = 'K' WHERE id = ${two[1]}",
    );
    final keyed = '${dir.path}/keyed.betterbudget';
    await db.copyTo(keyed);
    await db.customStatement(
      'UPDATE entries SET import_key = NULL WHERE id = ${two[1]}',
    );
    await db.customStatement(
      "UPDATE entries SET import_key = 'K' WHERE id = ${two[0]}",
    );
    final moved = (await db.replaceAllFrom(keyed))!;
    Future<int?> holder() async =>
        (await db
                .customSelect("SELECT id FROM entries WHERE import_key = 'K'")
                .getSingleOrNull())
            ?.read<int>('id');
    expect(await holder(), two[1]);
    await db.revertChanges(moved);
    expect(await holder(), two[0]);
  });

  test('a restore and an erase keep the phones’ names and which of their '
      'entries were taken in', () async {
    final dir = await Directory.systemTemp.createTemp('bb-changes');
    addTearDown(() => dir.delete(recursive: true));
    final copy = '${dir.path}/copy.betterbudget';
    await db.copyTo(copy);
    await db.setPreference(phoneTakenKey, 'taken-now');
    await db.setPreference('${phoneNamePrefix}pixel', 'Pixel');
    await db.replaceAllFrom(copy);
    var prefs = (await db.loadLedger()).prefs;
    expect(prefs[phoneTakenKey], 'taken-now');
    expect(prefs['${phoneNamePrefix}pixel'], 'Pixel');
    await db.startNewLedger(today, keepCategories: true);
    prefs = (await db.loadLedger()).prefs;
    expect(prefs[phoneTakenKey], 'taken-now');
    expect(prefs['${phoneNamePrefix}pixel'], 'Pixel');
  });

  test('another ledger’s file put in is one marker, with its id', () async {
    final dir = await Directory.systemTemp.createTemp('bb-changes');
    addTearDown(() => dir.delete(recursive: true));
    final other = AppDatabase(
      NativeDatabase(File('${dir.path}/other.betterbudget')),
    );
    await seedDemoIfEmpty(other, today);
    final theirs = (await other.loadLedger()).prefs[SyncKeys.ledger];
    await other.close();
    expect(theirs, isNot((await db.loadLedger()).prefs[SyncKeys.ledger]));
    final mark = await db.lastChangeSeq();
    await db.replaceAllFrom('${dir.path}/other.betterbudget');
    final rows = await since(mark);
    expect(rows, hasLength(1));
    expect(rows.single.op, 'restore');
    expect(rows.single.tbl, '');
    expect((await db.loadLedger()).prefs[SyncKeys.ledger], theirs);
  });

  test('erasing is every row deleted, as ordinary changes; the ledger keeps '
      'its id, Income and this computer’s sync settings', () async {
    await db.setPreference(SyncKeys.applied, '{"laptop":7}');
    final was = (await db.loadLedger()).prefs[SyncKeys.ledger];
    final income = (await db.loadLedger()).accounts.values
        .singleWhere((a) => a.type == AccountType.income)
        .id;
    final mark = await db.lastChangeSeq();
    await db.startNewLedger(today, keepCategories: false);
    final rows = await since(mark);
    // Rows deleted; the two settings an erase writes added.
    expect(rows.map((r) => r.op).toSet(), {'delete', 'insert'});
    expect(rows.where((r) => r.op == 'insert').map((r) => r.tbl).toSet(), {
      'preferences',
    });
    expect(rows.where((r) => r.tbl == 'transactions'), isNotEmpty);
    expect(
      rows.where((r) => r.tbl == 'transactions').map((r) => r.op).toSet(),
      {'delete'},
    );
    // The log before it stays.
    expect(await since(0), hasLength(greaterThan(mark)));
    final ledger = await db.loadLedger();
    expect(ledger.txns, isEmpty);
    expect(ledger.prefs[SyncKeys.ledger], was);
    expect(ledger.prefs[SyncKeys.applied], '{"laptop":7}');
    // Income is the same row, never deleted and made again.
    expect(
      ledger.accounts.values
          .singleWhere((a) => a.type == AccountType.income)
          .id,
      income,
    );
    expect(
      rows.where((r) => r.tbl == 'accounts' && r.pk.contains('$income')),
      isEmpty,
    );
  });

  test(
    'the log is no part of the ledger’s digest or of what is compared',
    () async {
      final digest = (await db.sealState()).digest;
      final mark = await db.lastChangeSeq();
      await db.setPreference('a.setting', 'x');
      await db.setPreference('a.setting', null);
      expect(await since(mark), hasLength(2));
      expect((await db.sealState()).digest, digest);
      expect((await db.allRows()).keys, isNot(contains(changeLogTable)));
    },
  );

  test('the write paths a person uses each leave a record', () async {
    final checking = await account('TDB Checking');
    final groceries = await account('Groceries');
    final start = DateTime(2026, 10), end = DateTime(2026, 10, 31);
    final id = await db.postSimple(
      accountId: checking,
      date: today,
      today: today,
      payee: 'Nomin',
      counterAccountId: groceries,
      amount: -45000,
    );
    // The row just posted: the seed's first rows are reconciled and locked.
    final entry = (await db.loadLedger()).txns
        .singleWhere((t) => t.id == id)
        .entries
        .singleWhere((e) => e.accountId == checking);
    final writes = <String, Future<void> Function()>{
      'edit': () => db.editTransaction(
        transactionId: id,
        accountId: checking,
        date: today,
        today: today,
        payee: 'Nomin',
        counterAccountId: groceries,
        amount: -46000,
      ),
      'clear': () => db.toggleCleared(entry.id),
      'assign': () => db.setBudgetAmount(groceries, start, end, 500000),
      'rename': () => db.renameAccount(checking, 'TDB Current'),
      'new category': () => db.createCategory('Books'),
      'delete': () => db.softDelete(id),
    };
    for (final e in writes.entries) {
      final mark = await db.lastChangeSeq();
      await e.value();
      expect(await since(mark), isNotEmpty, reason: e.key);
    }
  });
}
