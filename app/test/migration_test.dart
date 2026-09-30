import 'dart:io';

import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/pay.dart';
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
      await dropAddedInV9(db);
      await dropAddedInV8(db);
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
      await dropAddedInV7(db);
      await dropAddedInV6(db);
      await dropAddedInV5(db);
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
          .where(
            (f) => f.path.contains('.before-v${db.schemaVersion}-from-v$from-'),
          )
          .toList();
      expect(backups, hasLength(1));
      final copy = sqlite3.open(backups.single.path);
      addTearDown(copy.close);
      expect(copy.select('PRAGMA user_version').single.values.single, from);
    });
  }

  test('upgrades a v6 file: pay keeps its one amount', () async {
    final dir = await Directory.systemTemp.createTemp('bb-migration');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/betterbudget.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    await seedDemoIfEmpty(db, today);
    final salary = (await db.loadLedger()).categories.firstWhere(
      (c) => c.name == 'Salary',
    );
    final checking = (await db.loadLedger()).openAccounts.first.id;
    await db.savePaySchedule(
      categoryId: salary.id,
      accountId: checking,
      amount: 100000000,
      rule: PayRule.twiceMonthly,
      today: today,
    );
    await dropAddedInV9(db);
    await dropAddedInV8(db);
    await dropAddedInV7(db);
    await db.customStatement('PRAGMA user_version = 6');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final pay = (await db.loadLedger()).paySchedules.single;
    expect(pay.amount, 100000000);
    expect(pay.split, isFalse);
    expect(
      dir.listSync().whereType<File>().map((f) => f.path.split('/').last),
      contains(startsWith('betterbudget.before-v10-from-v6-')),
    );
  });

  test(
    'upgrades a v9 file: the budget starts empty and can be filled',
    () async {
      final dir = await Directory.systemTemp.createTemp('bb-migration');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/betterbudget.sqlite');

      var db = AppDatabase(NativeDatabase(file));
      await seedDemoIfEmpty(db, today);
      await dropAddedInV10(db);
      await db.customStatement('PRAGMA user_version = 9');
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      var data = await db.loadLedger();
      expect(data.budgetAmounts, isEmpty);
      final food = data.categories.firstWhere((c) => c.name == 'Groceries');
      await db.setBudgetAmount(
        food.id,
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 30),
        90000000,
      );
      data = await db.loadLedger();
      expect(data.budgetAmounts.single.amount, 90000000);
      expect(
        dir.listSync().whereType<File>().map((f) => f.path.split('/').last),
        contains(startsWith('betterbudget.before-v10-from-v9-')),
      );
    },
  );

  test('upgrades a v8 file: a weekend payday still moves', () async {
    final dir = await Directory.systemTemp.createTemp('bb-migration');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/betterbudget.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    await seedDemoIfEmpty(db, today);
    final data = await db.loadLedger();
    final salary = data.categories.firstWhere((c) => c.name == 'Salary');
    await db.savePaySchedule(
      categoryId: salary.id,
      accountId: data.openAccounts.first.id,
      amount: 100000000,
      rule: PayRule.monthly,
      weekend: PayWeekend.after,
      today: today,
    );
    await db.savePaySchedule(
      categoryId: salary.id,
      accountId: data.openAccounts.last.id,
      amount: 50000000,
      rule: PayRule.monthly,
      today: today,
    );
    await dropAddedInV9(db);
    await db.customStatement('PRAGMA user_version = 8');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final pays = (await db.loadLedger()).paySchedules;
    expect(pays.map((p) => p.weekend), [PayWeekend.after, PayWeekend.before]);
    expect(
      dir.listSync().whereType<File>().map((f) => f.path.split('/').last),
      contains(startsWith('betterbudget.before-v10-from-v8-')),
    );
  });

  test('upgrades a v7 file: an import key moves to the account side', () async {
    final dir = await Directory.systemTemp.createTemp('bb-migration');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/betterbudget.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    await seedDemoIfEmpty(db, today);
    final data = await db.loadLedger();
    final checking = data.balanceSheetAccounts
        .firstWhere((a) => a.name == 'TDB Checking')
        .id;
    final txn = data.txns.firstWhere(
      (t) => !t.scheduled && t.entries.any((e) => e.accountId == checking),
    );
    await dropAddedInV9(db);
    await dropAddedInV8(db);
    await db.customStatement(
      "UPDATE transactions SET import_key = 'a1|2026-09-01|-100|5' WHERE id = ?",
      [txn.id],
    );
    await db.customStatement('PRAGMA user_version = 7');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final rows = await db
        .customSelect(
          'SELECT account_id FROM entries WHERE import_key IS NOT NULL',
        )
        .get();
    expect(rows.map((r) => r.read<int>('account_id')), [checking]);
    final left = await db
        .customSelect('SELECT 1 FROM transactions WHERE import_key IS NOT NULL')
        .get();
    expect(left, isEmpty);
  });

  test('a v8 file an older build relabeled v7 opens with its rows', () async {
    final dir = await Directory.systemTemp.createTemp('bb-migration');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/betterbudget.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    await seedDemoIfEmpty(db, today);
    final before = (await db.loadLedger()).txns.length;
    // What the old build did: the version number, and nothing else.
    await db.customStatement('PRAGMA user_version = 7');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect((await db.loadLedger()).txns.length, before);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), db.schemaVersion);
  });

  test('a ledger from a newer build is refused and left as it was', () async {
    final dir = await Directory.systemTemp.createTemp('bb-migration');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/betterbudget.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    await seedDemoIfEmpty(db, today);
    await db.customStatement('PRAGMA user_version = 99');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    await expectLater(db.loadLedger(), throwsA(isA<NewerLedgerException>()));
    await db.close();
    final raw = sqlite3.open(file.path);
    addTearDown(raw.close);
    expect(raw.select('PRAGMA user_version').first.values.first, 99);
    expect(dir.listSync().where((f) => f.path.contains('.before-')), isEmpty);
  });

  test(
    'upgrades a v5 file: no roles, no answers, Savings starts fresh',
    () async {
      final dir = await Directory.systemTemp.createTemp('bb-migration');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/betterbudget.sqlite');

      var db = AppDatabase(NativeDatabase(file));
      await seedDemoIfEmpty(db, today);
      final before = await db.loadLedger();
      await dropAddedInV9(db);
      await dropAddedInV8(db);
      await dropAddedInV7(db);
      await dropAddedInV6(db);
      await db.customStatement('PRAGMA user_version = 5');
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final data = await db.loadLedger();
      expect(data.accounts.values.map((a) => a.role), everyElement(isNull));
      expect(data.prefs, isEmpty);
      expect(data.txns.length, before.txns.length);
      expect(
        dir.listSync().whereType<File>().map((f) => f.path.split('/').last),
        contains(startsWith('betterbudget.before-v10-from-v5-')),
      );
      await db.setPreference('ready.health', 'yes');
      expect((await db.loadLedger()).prefs, {'ready.health': 'yes'});
    },
  );

  test('upgrades a v4 file: income categories stay paydays', () async {
    final dir = await Directory.systemTemp.createTemp('bb-migration');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/betterbudget.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    await seedDemoIfEmpty(db, today);
    await dropAddedInV9(db);
    await dropAddedInV8(db);
    await dropAddedInV7(db);
    await dropAddedInV6(db);
    await dropAddedInV5(db);
    await db.customStatement('PRAGMA user_version = 4');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final data = await db.loadLedger();
    final salary = data.accounts.values.firstWhere((a) => a.name == 'Salary');
    expect(salary.payday, isTrue);
    expect(data.paySchedules, isEmpty);
    final fk = await db.customSelect('PRAGMA foreign_key_check').get();
    expect(fk, isEmpty);
  });

  test('upgrades a v3 file: accounts can be archived and deleted', () async {
    final dir = await Directory.systemTemp.createTemp('bb-migration');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/betterbudget.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    await seedDemoIfEmpty(db, today);
    final before = await db.loadLedger();
    await dropAddedInV9(db);
    await dropAddedInV8(db);
    await dropAddedInV7(db);
    await dropAddedInV6(db);
    await dropAddedInV5(db);
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

/// The v6 schema: pay has one amount.
/// The v7 schema: import keys sat on transactions, not entries. A unique
/// column can't be dropped, so entries is rebuilt without it.
/// The v9 schema: no budget amounts.
Future<void> dropAddedInV10(AppDatabase db) async {
  await db.customStatement('DROP TABLE budget_amounts');
}

/// The v8 schema: a weekend payday always moved.
Future<void> dropAddedInV9(AppDatabase db) async {
  await db.customStatement(
    'ALTER TABLE pay_schedules DROP COLUMN weekend_keep',
  );
}

Future<void> dropAddedInV8(AppDatabase db) async {
  final sql =
      (await db
              .customSelect(
                "SELECT sql FROM sqlite_master WHERE name = 'entries'",
              )
              .getSingle())
          .read<String>('sql');
  final v7 = sql.replaceFirst(RegExp(r',\s*"import_key" TEXT NULL'), '');
  expect(v7, isNot(sql));
  final cols = (await db.customSelect('PRAGMA table_info(entries)').get())
      .map((r) => r.read<String>('name'))
      .where((n) => n != 'import_key')
      .join(', ');
  await db.customStatement('PRAGMA foreign_keys = OFF');
  await db.customStatement('ALTER TABLE entries RENAME TO entries_v8');
  await db.customStatement(v7);
  await db.customStatement(
    'INSERT INTO entries ($cols) SELECT $cols FROM entries_v8',
  );
  await db.customStatement('DROP TABLE entries_v8');
  await db.customStatement('PRAGMA foreign_keys = ON');
}

Future<void> dropAddedInV7(AppDatabase db) async {
  await db.customStatement(
    'ALTER TABLE pay_schedules DROP COLUMN amount2_minor',
  );
}

/// The v5 schema: no account roles or preferences.
Future<void> dropAddedInV6(AppDatabase db) async {
  await db.customStatement('ALTER TABLE accounts DROP COLUMN role');
  await db.customStatement('DROP TABLE preferences');
}

/// The v3 accounts table: no archived or deleted columns.
Future<void> dropAccountColumnsAddedInV4(AppDatabase db) async {
  await db.customStatement('ALTER TABLE accounts DROP COLUMN archived_at');
  await db.customStatement('ALTER TABLE accounts DROP COLUMN deleted_at');
}

/// The v4 schema: no payday mark, pay schedules or links to them. A column in
/// a foreign key can't be dropped, so transactions is rebuilt without it.
Future<void> dropAddedInV5(AppDatabase db) async {
  await db.customStatement('PRAGMA foreign_keys = OFF');
  // Or the rename would re-point entries' references at the old copy.
  await db.customStatement('PRAGMA legacy_alter_table = ON');
  final sql =
      (await db
              .customSelect(
                "SELECT sql FROM sqlite_master WHERE name = 'transactions'",
              )
              .getSingle())
          .read<String>('sql');
  final v4 = sql.replaceFirst(
    RegExp(r',\s*"pay_schedule_id"[^,)]*REFERENCES pay_schedules \(id\)'),
    '',
  );
  expect(v4, isNot(sql));
  final columns =
      (await db.customSelect('PRAGMA table_info(transactions)').get())
          .map((r) => r.read<String>('name'))
          .where((c) => c != 'pay_schedule_id')
          .map((c) => '"$c"')
          .join(', ');
  await db.customStatement(
    'ALTER TABLE transactions RENAME TO transactions_v5',
  );
  await db.customStatement(v4);
  await db.customStatement(
    'INSERT INTO transactions ($columns) SELECT $columns FROM transactions_v5',
  );
  await db.customStatement('DROP TABLE transactions_v5');
  await db.customStatement('DROP TABLE pay_schedules');
  await db.customStatement('ALTER TABLE accounts DROP COLUMN payday');
  await db.customStatement('PRAGMA legacy_alter_table = OFF');
  await db.customStatement('PRAGMA foreign_keys = ON');
}
