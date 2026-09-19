import 'dart:io';

import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Upgrades a file shaped like an older schema, with the locks the pre-v3
/// seed wrote: category and opening-balance sides reconciled, and account
/// sides reconciled with no statement.
void main() {
  final today = DateTime(2026, 9, 16);
  final rec = Cleared.reconciled.index;

  for (final from in [1, 2]) {
    test('upgrades a v$from file with data, backs it up first', () async {
      final dir = await Directory.systemTemp.createTemp('bb-migration');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/betterbudget.sqlite');

      var db = AppDatabase(NativeDatabase(file));
      await seedDemoIfEmpty(db, today);
      final visaOpening = await db
          .customSelect(
            'SELECT e.id FROM entries e JOIN accounts a ON a.id = e.account_id '
            "WHERE a.name = 'Golomt Visa' ORDER BY e.id LIMIT 1",
          )
          .getSingle();
      // The old seed: the other side of every locked row was reconciled too,
      // and the Visa opening balance was reconciled with no statement.
      await db.customStatement(
        'UPDATE entries SET cleared = $rec WHERE transaction_id IN '
        '(SELECT transaction_id FROM entries WHERE cleared = $rec)',
      );
      await db.customStatement(
        'UPDATE entries SET cleared = $rec WHERE id = ?',
        [visaOpening.read<int>('id')],
      );
      if (from == 1) {
        final sql =
            (await db
                    .customSelect(
                      "SELECT sql FROM sqlite_master WHERE name = 'entries'",
                    )
                    .getSingle())
                .read<String>('sql');
        final v1 = sql.replaceFirst(
          RegExp(
            r',\s*"reconciliation_id"[^,]*REFERENCES reconciliations \(id\)',
          ),
          '',
        );
        expect(v1, isNot(sql));
        await db.customStatement('PRAGMA foreign_keys = OFF');
        await db.customStatement('ALTER TABLE entries RENAME TO entries_v2');
        await db.customStatement(v1);
        await db.customStatement(
          'INSERT INTO entries SELECT id, transaction_id, account_id, '
          'amount_minor, currency, rate, cleared FROM entries_v2',
        );
        await db.customStatement('DROP TABLE entries_v2');
      }
      await dropAccountColumnsAddedInV4(db);
      await db.customStatement('PRAGMA user_version = $from');
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      final data = await db.loadLedger();
      final checking = data.balanceSheetAccounts
          .firstWhere((a) => a.name == 'TDB Checking')
          .id;

      // Checking's locked rows are tied to the seed's statement; nothing else
      // is reconciled.
      final stray = await db
          .customSelect(
            'SELECT e.id FROM entries e JOIN accounts a ON a.id = e.account_id '
            'WHERE e.cleared = $rec AND '
            "(a.type NOT IN ('asset', 'liability') OR e.reconciliation_id IS NULL)",
          )
          .get();
      expect(stray, isEmpty);
      final locked = data
          .registerFor(checking)
          .posted
          .where((r) => r.cleared == Cleared.reconciled);
      expect(locked, hasLength(5));
      expect(
        locked.every((r) => r.reconciledOn == DateTime(2026, 9, 10)),
        isTrue,
      );

      // So taking the reconcile back unlocks every row, in every account.
      await db.unreconcileLast(checking);
      final after = await db.loadLedger();
      for (final a in after.balanceSheetAccounts) {
        expect(after.registerFor(a.id).posted.where((r) => r.locked), isEmpty);
      }
      final fk = await db.customSelect('PRAGMA foreign_key_check').get();
      expect(fk, isEmpty);
      await db.close();

      // The copy from before the upgrade is still the old version.
      final backups = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('.before-v4-from-v$from-'))
          .toList();
      expect(backups, hasLength(1));
      final copy = sqlite3.open(backups.single.path);
      addTearDown(copy.close);
      expect(copy.select('PRAGMA user_version').single.values.single, from);
    });
  }

  test('upgrades a v3 file: accounts can be archived and deleted', () async {
    final dir = await Directory.systemTemp.createTemp('bb-migration');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/betterbudget.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    await seedDemoIfEmpty(db, today);
    final before = await db.loadLedger();
    await dropAccountColumnsAddedInV4(db);
    await db.customStatement('PRAGMA user_version = 3');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final data = await db.loadLedger();
    expect(
      data.balanceSheetAccounts.map((a) => a.name),
      before.balanceSheetAccounts.map((a) => a.name),
    );
    expect(data.accounts.values.any((a) => a.archived || a.deleted), isFalse);
    final savings = data.balanceSheetAccounts
        .firstWhere((a) => a.name == 'Khan Savings')
        .id;
    await db.setArchived(savings, true);
    expect((await db.loadLedger()).accounts[savings]!.archived, isTrue);
  });
}

/// The v3 accounts table: no archived or deleted columns.
Future<void> dropAccountColumnsAddedInV4(AppDatabase db) async {
  await db.customStatement('ALTER TABLE accounts DROP COLUMN archived_at');
  await db.customStatement('ALTER TABLE accounts DROP COLUMN deleted_at');
}
