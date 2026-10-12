import 'dart:io';

import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/money.dart';
import 'package:betterbudget/domain/pay.dart';
import 'package:betterbudget/domain/payee_rules.dart';
import 'package:betterbudget/domain/sync.dart';
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

  test('upgrades a v19 file: the change log is made, empty, and no ledger '
      'id is invented', () async {
    final dir = await Directory.systemTemp.createTemp('bb-migration');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/betterbudget.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    await seedDemoIfEmpty(db, today);
    final txns = (await db.loadLedger()).txns.length;
    await dropAddedInV20(db);
    await db.setPreference(SyncKeys.ledger, null);
    await db.customStatement('PRAGMA user_version = 19');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final data = await db.loadLedger();
    expect(data.txns, hasLength(txns));
    expect(await db.lastChangeSeq(), 0);
    expect(
      await db.changeTriggersPresent(),
      hasLength(db.changeTriggerSql().length),
    );
    // A ledger that may already be shared takes the folder's id later.
    expect(data.prefs[SyncKeys.ledger], isNull);
    // From here on, a change is recorded.
    await db.setPreference('a.setting', 'x');
    expect(await db.lastChangeSeq(), 1);
    expect(
      dir.listSync().whereType<File>().map((f) => f.path.split('/').last),
      contains(startsWith('betterbudget.before-v20-from-v19-')),
    );
  });

  test('upgrades a v18 file: remembered payees become rows, the setting '
      'stays', () async {
    final dir = await Directory.systemTemp.createTemp('bb-migration');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/betterbudget.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    await seedDemoIfEmpty(db, today);
    final data = await db.loadLedger();
    final checking = data.balanceSheetAccounts
        .firstWhere((a) => a.name == 'TDB Checking')
        .id;
    final groceries = data.categories.firstWhere((c) => c.name == 'Groceries');
    // As v18 kept them: JSON in a setting per account, no table.
    await db.customStatement('DROP TABLE payee_rule_accounts');
    await db.customStatement('DROP TABLE payee_rules');
    await db.setPreference(
      AppDatabase.payeeRulesKey(checking),
      '[{"starts":"unitel","category":${groceries.id}},'
      '{"starts":"nomin","category":987654321}]',
    );
    await db.customStatement('PRAGMA user_version = 18');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final rules = await db.allPayeeRules();
    // The one whose category is gone is left behind.
    expect(rules, hasLength(1));
    final rule = rules.single;
    expect(rule.words, 'unitel');
    // Its capitals come from the ledger's payee of that name.
    expect(rule.name, 'Unitel');
    expect(rule.anywhere, isFalse);
    expect(rule.categoryId, groceries.id);
    expect(rule.accountIds, {checking});
    // The same id on every computer that carries this setting over.
    expect(rule.id, carriedRuleId(checking, 'unitel'));
    expect(
      (await db.loadLedger()).prefs[AppDatabase.payeeRulesKey(checking)],
      isNotNull,
    );
    expect(
      dir.listSync().whereType<File>().map((f) => f.path.split('/').last),
      contains(startsWith('betterbudget.before-v20-from-v18-')),
    );
  });

  test('upgrades a v17 file: the cash-and-bank group becomes Bank', () async {
    final dir = await Directory.systemTemp.createTemp('bb-migration');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/betterbudget.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    await seedDemoIfEmpty(db, today);
    // As v17 stored it: one bucket for cash and bank together.
    await db.customStatement(
      "UPDATE accounts SET sidebar_group = 'Cash & bank' "
      "WHERE sidebar_group IN ('Bank', 'Cash')",
    );
    await db.customStatement('PRAGMA user_version = 17');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final after = await db.loadLedger();
    final assets = after.openAccounts.where((a) => a.type == AccountType.asset);
    expect(assets, isNotEmpty);
    // Every one becomes a bank account, and none is made cash behind their
    // back: the user says which of their accounts is a wallet.
    expect(assets.map((a) => a.group), everyElement(LedgerGroups.bank));
    expect(assets.where((a) => a.isCash), isEmpty);
    expect(
      after.openAccounts
          .where((a) => a.type == AccountType.liability)
          .map((a) => a.group),
      everyElement(LedgerGroups.credit),
    );
    expect(
      dir.listSync().whereType<File>().map((f) => f.path.split('/').last),
      contains(startsWith('betterbudget.before-v20-from-v17-')),
    );
  });

  test(
    'upgrades a v16 file: a set amount keeps the pay period it ran by',
    () async {
      final dir = await Directory.systemTemp.createTemp('bb-migration');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/betterbudget.sqlite');

      var db = AppDatabase(NativeDatabase(file));
      await seedDemoIfEmpty(db, today);
      final ledger = await db.loadLedger();
      final checking = ledger.openAccounts.first.id;
      int category(String name) =>
          ledger.categories.firstWhere((c) => c.name == name).id;
      final food = category('Groceries'), rent = category('Housing');
      // Budget by this pay's periods (as v16 had it), a set amount, and a
      // bill: only the set amount meant "each pay period".
      final pay = await db.savePaySchedule(
        accountId: checking,
        amount: 210000000,
        rule: PayRule.twiceMonthly,
        today: today,
        definesPeriod: true,
      );
      await db.changeCategoryPlan(
        food,
        CategoryPlan(
          categoryId: food,
          kind: PlanKind.each,
          amount: 40000000,
          start: today,
        ),
        today,
      );
      await db.changeCategoryPlan(
        rent,
        CategoryPlan(
          categoryId: rent,
          kind: PlanKind.byDate,
          amount: 180000000,
          start: today,
          due: DateTime(2026, 10, 20),
          everyMonths: 1,
        ),
        today,
      );
      await dropAddedInV17(db);
      await db.customStatement('PRAGMA user_version = 16');
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final after = await db.loadLedger();
      expect(after.plans[food]!.payScheduleId, pay.after.id);
      expect(after.plans[rent]!.payScheduleId, isNull);
      expect(after.periodSchedule!.id, pay.after.id);
      expect(after.paySchedules.single.name, isNull);
      expect(
        dir.listSync().whereType<File>().map((f) => f.path.split('/').last),
        contains(startsWith('betterbudget.before-v20-from-v16-')),
      );
    },
  );

  test('upgrades a v15 file: a plan gets its Custom… columns', () async {
    final dir = await Directory.systemTemp.createTemp('bb-migration');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/betterbudget.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    await seedDemoIfEmpty(db, today);
    final ledger = await db.loadLedger();
    final rent = ledger.categories.firstWhere((c) => c.name == 'Housing').id;
    // A monthly plan from before, as v15 stored it.
    await db.changeCategoryPlan(
      rent,
      CategoryPlan(
        categoryId: rent,
        kind: PlanKind.byDate,
        amount: 180000000,
        start: today,
        due: DateTime(2026, 10, 20),
        everyMonths: 1,
      ),
      today,
    );
    await dropAddedInV16(db);
    await db.customStatement('PRAGMA user_version = 15');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    var plan = (await db.loadLedger()).plans[rent]!;
    expect(plan.everyMonths, 1);
    expect(plan.weekdays, isNull);
    expect(plan.endCount, isNull);
    // The new columns take a Custom… plan and give it back.
    await db.changeCategoryPlan(
      rent,
      CategoryPlan(
        categoryId: rent,
        kind: PlanKind.byDate,
        amount: 180000000,
        start: today,
        due: DateTime(2026, 10, 20),
        everyDays: 14,
        weekdays: const [1, 4],
        endDate: DateTime(2027, 3, 1),
      ),
      today,
    );
    plan = (await db.loadLedger()).plans[rent]!;
    expect(plan.weekdays, [1, 4]);
    expect(plan.endDate, DateTime(2027, 3, 1));
    expect(plan.nth, isNull);
    expect(
      dir.listSync().whereType<File>().map((f) => f.path.split('/').last),
      contains(startsWith('betterbudget.before-v20-from-v15-')),
    );
  });

  test('upgrades a v6 file: pay keeps its one amount', () async {
    final dir = await Directory.systemTemp.createTemp('bb-migration');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/betterbudget.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    await seedDemoIfEmpty(db, today);
    final checking = (await db.loadLedger()).openAccounts.first.id;
    await db.savePaySchedule(
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
      contains(startsWith('betterbudget.before-v20-from-v6-')),
    );
  });

  for (final (name, budgetIn, dollarAccounts, want) in [
    ('the currency the budget began in', 'USD', 0, Currency.usd),
    ('tugrik, when most accounts are', null, 0, Currency.mnt),
    ('dollars, when most accounts are', null, 6, Currency.usd),
  ]) {
    test('upgrades a v11 file: spending categories take $name', () async {
      final dir = await Directory.systemTemp.createTemp('bb-migration');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/betterbudget.sqlite');

      var db = AppDatabase(NativeDatabase(file));
      await seedDemoIfEmpty(db, today);
      for (var i = 0; i < dollarAccounts; i++) {
        final id = await db.addAccount(name: 'USD $i', type: AccountType.asset);
        await db.customStatement(
          "UPDATE accounts SET currency = 'USD' WHERE id = $id",
        );
      }
      if (budgetIn != null) {
        await db.setPreference('budget.currency', budgetIn);
      }
      await dropAddedInV12(db);
      await db.customStatement('PRAGMA user_version = 11');
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final data = await db.loadLedger();
      expect(data.accountsOff, isEmpty);
      final spending = data.categories.where((c) => !c.isIncome);
      expect(spending, isNotEmpty);
      if (budgetIn != null) {
        // Amounts were assigned in it: every category takes it.
        expect(spending.map((c) => c.currency).toSet(), {want});
      } else {
        // No budget yet: a category with rows takes their currency (the
        // demo's are tugrik), one without takes the accounts'.
        for (final c in spending) {
          final u = data.categoryUsage[c.id];
          final used = (u?.rows ?? 0) + (u?.scheduled ?? 0);
          expect(c.currency, used > 0 ? Currency.mnt : want, reason: c.name);
        }
        expect(spending.map((c) => c.currency), contains(want));
      }
      // Accounts keep their own.
      expect(
        data.openAccounts.where((a) => a.currency == Currency.mnt),
        isNotEmpty,
      );
      expect(
        dir.listSync().whereType<File>().map((f) => f.path.split('/').last),
        contains(startsWith('betterbudget.before-v20-from-v11-')),
      );
    });
  }

  test(
    'upgrades a v12 file: every income category becomes the one Income',
    () async {
      final dir = await Directory.systemTemp.createTemp('bb-migration');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/betterbudget.sqlite');

      var db = AppDatabase(NativeDatabase(file));
      await seedDemoIfEmpty(db, today);
      final before = await db.loadLedger();
      final checking = before.openAccounts.first.id;
      // As a v12 file had them: income categories of the user's own, one
      // archived, with rows and pay filed under them.
      final salary = await db.incomeCategory();
      await db.customStatement(
        "UPDATE accounts SET name = 'Salary' WHERE id = $salary",
      );
      final allowance = await db.addAccount(
        name: 'Child allowance',
        type: AccountType.income,
      );
      final old = await db.addAccount(
        name: 'Old job',
        type: AccountType.income,
      );
      await db.customStatement(
        'UPDATE accounts SET archived_at = 1 WHERE id = $old',
      );
      // A spending category that happens to have Income's name.
      final clash = await db.createCategory('Income');
      for (final c in [allowance, old]) {
        await db.postSimple(
          accountId: checking,
          date: DateTime(2026, 9, 1),
          today: today,
          payee: 'Money in $c',
          counterAccountId: c,
          amount: 10000000,
        );
      }
      final pay = await db.savePaySchedule(
        accountId: checking,
        amount: 210000000,
        rule: PayRule.monthly,
        day1: 25,
        today: today,
      );
      await db.customStatement(
        'UPDATE pay_schedules SET category_id = $allowance WHERE id = '
        '${pay.after.id}',
      );
      final rows = before.txns.length + 2 + pay.created.length;
      await db.customStatement('PRAGMA user_version = 12');
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final data = await db.loadLedger();
      final incomes = data.accounts.values.where((a) => a.isIncome).toList();
      expect(incomes.map((a) => a.name), [incomeAccountName]);
      expect(data.accounts[clash]!.name, 'Income (spending)');
      final income = incomes.single;
      expect(income.archived, isFalse);
      expect(data.income, income);
      expect(await db.incomeCategory(), income.id);
      expect(data.txns, hasLength(rows));
      // Their rows are Income's now, and still add up.
      final moved = data
          .registerFor(checking)
          .posted
          .where((r) => r.payee.startsWith('Money in'));
      expect(moved.map((r) => r.categoryId), [income.id, income.id]);
      expect(await db.customSelect(AppDatabase.unbalancedSql).get(), isEmpty);
      expect(data.paySchedules.single.categoryId, income.id);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect(
        dir.listSync().whereType<File>().map((f) => f.path.split('/').last),
        contains(startsWith('betterbudget.before-v20-from-v12-')),
      );
    },
  );

  test('upgrades a v13 file: four kinds of plan become two', () async {
    final dir = await Directory.systemTemp.createTemp('bb-migration');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/betterbudget.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    await seedDemoIfEmpty(db, today);
    final ids = (await db.loadLedger()).categories.map((c) => c.id).toList();
    final kinds = ['spend', 'saveUp', 'dueOn', 'goal'];
    for (var i = 0; i < kinds.length; i++) {
      await db.customStatement(
        'INSERT INTO category_plans (category_id, kind, amount_minor, start, '
        'due, every_months, rollover) VALUES (?, ?, 100, ?, ?, ?, 0)',
        [
          ids[i],
          kinds[i],
          '2026-09-01',
          i < 2 ? null : '2027-01-15',
          i == 2 ? 12 : null,
        ],
      );
    }
    await db.customStatement('PRAGMA user_version = 13');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final plans = (await db.loadLedger()).plans;
    // Spend keeps its carry-over choice; save up always carried over.
    expect(
      (plans[ids[0]]!.kind, plans[ids[0]]!.rollover),
      (PlanKind.each, false),
    );
    expect(
      (plans[ids[1]]!.kind, plans[ids[1]]!.rollover),
      (PlanKind.each, true),
    );
    expect(
      (plans[ids[2]]!.kind, plans[ids[2]]!.everyMonths),
      (PlanKind.byDate, 12),
    );
    expect(
      (plans[ids[3]]!.kind, plans[ids[3]]!.everyMonths),
      (PlanKind.byDate, null),
    );
    expect(plans[ids[3]]!.due, DateTime(2027, 1, 15));
    expect(
      dir.listSync().whereType<File>().map((f) => f.path.split('/').last),
      contains(startsWith('betterbudget.before-v20-from-v13-')),
    );
  });

  test('upgrades a v10 file: amounts stay and a plan can be made', () async {
    final dir = await Directory.systemTemp.createTemp('bb-migration');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/betterbudget.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    await seedDemoIfEmpty(db, today);
    var data = await db.loadLedger();
    final food = data.categories.firstWhere((c) => c.name == 'Groceries');
    await db.setBudgetAmount(
      food.id,
      DateTime(2026, 9, 1),
      DateTime(2026, 9, 30),
      90000000,
    );
    await dropAddedInV12(db);
    await dropAddedInV11(db);
    await db.customStatement('PRAGMA user_version = 10');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    data = await db.loadLedger();
    expect(data.budgetAmounts.single.amount, 90000000);
    expect(data.plans, isEmpty);
    final plan = CategoryPlan(
      categoryId: food.id,
      kind: PlanKind.each,
      amount: 90000000,
      start: DateTime(2026, 9, 16),
    );
    await db.setCategoryPlan(food.id, plan);
    expect((await db.loadLedger()).plans[food.id], plan);
    expect(
      dir.listSync().whereType<File>().map((f) => f.path.split('/').last),
      contains(startsWith('betterbudget.before-v20-from-v10-')),
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
      await dropAddedInV12(db);
      await dropAddedInV11(db);
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
        contains(startsWith('betterbudget.before-v20-from-v9-')),
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
    await db.savePaySchedule(
      accountId: data.openAccounts.first.id,
      amount: 100000000,
      rule: PayRule.monthly,
      weekend: PayWeekend.after,
      today: today,
    );
    await db.savePaySchedule(
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
      contains(startsWith('betterbudget.before-v20-from-v8-')),
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
        contains(startsWith('betterbudget.before-v20-from-v5-')),
      );
      await db.setPreference('ready.health', 'yes');
      expect((await db.loadLedger()).prefs, {'ready.health': 'yes'});
    },
  );

  test('upgrades a v4 file: pay schedules', () async {
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
/// The v11 schema: a category has no accounts unchecked.
Future<void> dropAddedInV12(AppDatabase db) async {
  await dropAddedInV20(db);
  await db.customStatement('DROP TABLE category_accounts_off');
}

/// The v10 schema: no category plans.
Future<void> dropAddedInV11(AppDatabase db) async {
  await dropAddedInV20(db);
  await db.customStatement('DROP TABLE category_plans');
}

/// The v9 schema: no budget amounts.
Future<void> dropAddedInV10(AppDatabase db) async {
  await dropAddedInV20(db);
  await db.customStatement('DROP TABLE budget_amounts');
}

/// The v8 schema: a weekend payday always moved.
/// v17: a pay's name; set amounts per pay period keep their pay.
Future<void> dropAddedInV17(AppDatabase db) async {
  await dropAddedInV20(db);
  await db.customStatement('ALTER TABLE pay_schedules DROP COLUMN name');
}

/// v16: Custom…'s weekday patterns and an end on a category's plan.
Future<void> dropAddedInV16(AppDatabase db) async {
  await dropAddedInV20(db);
  for (final column in [
    'weekdays',
    'nth',
    'nth_weekday',
    'end_date',
    'end_count',
  ]) {
    await db.customStatement('ALTER TABLE category_plans DROP COLUMN $column');
  }
}

Future<void> dropAddedInV9(AppDatabase db) async {
  await dropAddedInV20(db);
  await db.customStatement(
    'ALTER TABLE pay_schedules DROP COLUMN weekend_keep',
  );
}

Future<void> dropAddedInV8(AppDatabase db) async {
  await dropAddedInV20(db);
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
  await dropAddedInV20(db);
  await db.customStatement(
    'ALTER TABLE pay_schedules DROP COLUMN amount2_minor',
  );
}

/// The v5 schema: no account roles or preferences.
Future<void> dropAddedInV6(AppDatabase db) async {
  await dropAddedInV20(db);
  await db.customStatement('ALTER TABLE accounts DROP COLUMN role');
  await db.customStatement('DROP TABLE preferences');
}

/// The v3 accounts table: no archived or deleted columns.
Future<void> dropAccountColumnsAddedInV4(AppDatabase db) async {
  await dropAddedInV20(db);
  await db.customStatement('ALTER TABLE accounts DROP COLUMN archived_at');
  await db.customStatement('ALTER TABLE accounts DROP COLUMN deleted_at');
}

/// The v4 schema: no payday mark, pay schedules or links to them. A column in
/// a foreign key can't be dropped, so transactions is rebuilt without it.
Future<void> dropAddedInV5(AppDatabase db) async {
  await dropAddedInV20(db);
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

/// v20: the change log, and this connection's triggers that fill it.
/// Dropped first wherever a file is taken back to an older shape: a trigger
/// that names a column stops that column being dropped.
Future<void> dropAddedInV20(AppDatabase db) async {
  for (final name in await db.changeTriggersPresent()) {
    await db.customStatement('DROP TRIGGER IF EXISTS temp."$name"');
  }
  await db.customStatement('DROP TABLE IF EXISTS changes');
}
