import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/domain/forecast.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 9, 16);
  late AppDatabase db;
  late int checking;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await seedDemoIfEmpty(db, today);
    checking = (await db.loadLedger()).balanceSheetAccounts
        .firstWhere((a) => a.name == 'TDB Checking')
        .id;
  });
  tearDown(() => db.close());

  Future<int> categoryId(String name) async =>
      (await db.loadLedger()).categories.firstWhere((c) => c.name == name).id;

  test('every stored transaction sums to zero', () async {
    final rows = await db
        .customSelect(
          'SELECT transaction_id, SUM(amount_minor) s FROM entries GROUP BY transaction_id HAVING s != 0',
        )
        .get();
    expect(rows, isEmpty);
  });

  test('working, cleared and reconciled are different numbers', () async {
    final s = (await db.loadLedger()).summaryFor(checking);
    expect(s.working, 418245000);
    expect(s.cleared, 429885000);
    expect(s.reconciledOn, DateTime(2026, 9, 10));
  });

  test('register: running balance, transfers and splits', () async {
    final reg = (await db.loadLedger()).registerFor(checking);
    expect(reg.posted.last.balance, 418245000);
    final split = reg.posted.firstWhere((r) => r.kind == RowKind.split);
    expect(split.splitLines.map((l) => l.amount), [-6190000, -2450000]);
    expect(split.splitLines.fold(0, (s, l) => s + l.amount), split.amount);
    final transfer = reg.posted.lastWhere((r) => r.kind == RowKind.transfer);
    expect(transfer.payee, 'Khan Savings');
    expect(reg.scheduled.map((r) => r.date.day), [20, 25, 1, 10]);
  });

  test('unbalanced writes are refused and leave nothing behind', () async {
    final groceries = await categoryId('Groceries');
    await expectLater(
      db.postTransaction(
        date: today,
        payee: 'Broken',
        lines: [
          (accountId: checking, amount: -1000, cleared: Cleared.uncleared),
          (accountId: groceries, amount: 999, cleared: Cleared.uncleared),
        ],
      ),
      throwsA(isA<UnbalancedTransactionException>()),
    );
    final orphans = await db
        .customSelect("SELECT 1 FROM payees WHERE name = 'Broken'")
        .get();
    expect(orphans, isEmpty);
  });

  test(
    'future-dated entry is scheduled and does not move the balance',
    () async {
      final tuition = await categoryId('Tuition');
      await db.postSimple(
        accountId: checking,
        date: DateTime(2026, 9, 30),
        today: today,
        payee: 'МУИС',
        counterAccountId: tuition,
        amount: -210000000,
      );
      final ledger = await db.loadLedger();
      expect(ledger.summaryFor(checking).working, 418245000);
      expect(ledger.registerFor(checking).scheduled.length, 5);
    },
  );

  test('category edit, cleared toggle, soft delete and restore', () async {
    final ledger = await db.loadLedger();
    final unitel = ledger
        .registerFor(checking)
        .posted
        .firstWhere((r) => r.payee == 'Unitel');
    final utilities = await categoryId('Utilities');

    await db.setCategory(
      transactionId: unitel.txnId,
      accountId: checking,
      categoryId: utilities,
    );
    await db.toggleCleared(unitel.entryId);
    var row = (await db.loadLedger())
        .registerFor(checking)
        .posted
        .firstWhere((r) => r.payee == 'Unitel');
    expect(row.categoryLabel, 'Utilities');
    expect(row.cleared, Cleared.cleared);

    await db.softDelete(unitel.txnId);
    expect(
      (await db.loadLedger()).summaryFor(checking).working,
      418245000 + 3000000,
    );
    await db.restore(unitel.txnId);
    expect((await db.loadLedger()).summaryFor(checking).working, 418245000);
  });

  test('reconciled entries are locked against toggling', () async {
    final reg = (await db.loadLedger()).registerFor(checking);
    final salary = reg.posted.firstWhere((r) => r.payee == 'Altan Gadas LLC');
    await db.toggleCleared(salary.entryId);
    final after = (await db.loadLedger())
        .registerFor(checking)
        .posted
        .firstWhere((r) => r.entryId == salary.entryId);
    expect(after.cleared, Cleared.reconciled);
  });

  test(
    'reconcile locks cleared rows through the date, only if they match',
    () async {
      final data = await db.loadLedger();
      final through = data.clearedThrough(checking, today);
      expect(through.balance, 429885000);

      // A statement that disagrees locks nothing.
      await expectLater(
        db.reconcile(
          accountId: checking,
          statementDate: today,
          today: today,
          balance: through.balance + 100,
        ),
        throwsA(
          isA<ReconcileMismatchException>().having((e) => e.off, 'off', 100),
        ),
      );
      expect(
        (await db.loadLedger()).summaryFor(checking).reconciledOn,
        DateTime(2026, 9, 10),
      );

      final done = await db.reconcile(
        accountId: checking,
        statementDate: today,
        today: today,
        balance: through.balance,
      );
      expect(done.entryIds, hasLength(through.toLock));
      var after = await db.loadLedger();
      expect(after.summaryFor(checking).reconciledOn, today);
      final posted = after.registerFor(checking).posted;
      // Cleared rows are now reconciled; uncleared ones are left alone.
      expect(posted.where((r) => r.cleared == Cleared.cleared), isEmpty);
      expect(
        posted.firstWhere((r) => r.payee == 'Unitel').cleared,
        Cleared.uncleared,
      );
      // Only this account's side of a transfer is locked.
      final savings = after.balanceSheetAccounts
          .firstWhere((a) => a.name == 'Khan Savings')
          .id;
      expect(
        after
            .registerFor(savings)
            .posted
            .lastWhere((r) => r.kind == RowKind.transfer)
            .cleared,
        Cleared.cleared,
      );

      await db.unreconcile(done);
      after = await db.loadLedger();
      expect(after.summaryFor(checking).reconciledOn, DateTime(2026, 9, 10));
      expect(after.clearedThrough(checking, today).toLock, through.toLock);
    },
  );

  test('a transfer reconciled on one side is locked from the other', () async {
    var data = await db.loadLedger();
    await db.reconcile(
      accountId: checking,
      statementDate: today,
      today: today,
      balance: data.clearedThrough(checking, today).balance,
    );
    data = await db.loadLedger();
    final savings = data.balanceSheetAccounts
        .firstWhere((a) => a.name == 'Khan Savings')
        .id;
    final row = data
        .registerFor(savings)
        .posted
        .lastWhere((r) => r.kind == RowKind.transfer);
    expect(row.cleared, Cleared.cleared);
    expect(row.lockedIn, 'TDB Checking');
    expect(row.locked, isTrue);

    await expectLater(
      db.editTransaction(
        transactionId: row.txnId,
        accountId: savings,
        date: row.date,
        today: today,
        amount: row.amount + 100,
      ),
      throwsA(isA<LockedException>()),
    );
    expect(await db.softDeleteMany([row.txnId]), isEmpty);
    // Its own cleared state still changes.
    expect(await db.setClearedMany({row.entryId: Cleared.uncleared}), {
      row.entryId: Cleared.cleared,
    });
  });

  test('reconciles unwind newest first, in any later session', () async {
    // The seed's 09.10 reconcile, as if from an earlier session.
    var data = await db.loadLedger();
    final done = await db.reconcile(
      accountId: checking,
      statementDate: today,
      today: today,
      balance: data.clearedThrough(checking, today).balance,
    );

    final newest = await db.unreconcileLast(checking);
    expect(newest.statements.single.id, done.statements.single.id);
    expect(newest.entryIds, unorderedEquals(done.entryIds));
    data = await db.loadLedger();
    expect(data.summaryFor(checking).reconciledOn, DateTime(2026, 9, 10));
    // Rows from the older reconcile stay locked.
    final salary = data
        .registerFor(checking)
        .posted
        .firstWhere((r) => r.payee == 'Altan Gadas LLC');
    expect(salary.cleared, Cleared.reconciled);
    expect(salary.latestReconcile, isTrue);

    final older = await db.unreconcileLast(checking);
    expect(older.entryIds, hasLength(5));
    data = await db.loadLedger();
    expect(data.summaryFor(checking).reconciledOn, isNull);
    // Nothing stays locked: the seed's other sides were never reconciled.
    expect(
      data
          .registerFor(checking)
          .posted
          .where((r) => r.cleared == Cleared.reconciled),
      isEmpty,
    );

    // A later reconcile that locked nothing goes with it.
    await db.relock(older);
    data = await db.loadLedger();
    final empty = await db.reconcile(
      accountId: checking,
      statementDate: DateTime(2026, 9, 11),
      today: today,
      balance: data.clearedThrough(checking, DateTime(2026, 9, 11)).balance,
    );
    expect(empty.entryIds, isEmpty);
    expect(
      (await db.loadLedger())
          .registerFor(checking)
          .posted
          .firstWhere((r) => r.payee == 'Altan Gadas LLC')
          .latestReconcile,
      isTrue,
    );
    final both = await db.unreconcileLast(checking);
    expect(both.statements, hasLength(2));
    expect((await db.loadLedger()).summaryFor(checking).reconciledOn, isNull);
    await db.relock(both);
    data = await db.loadLedger();
    expect(data.summaryFor(checking).reconciledOn, DateTime(2026, 9, 11));
    expect(
      data
          .registerFor(checking)
          .posted
          .firstWhere((r) => r.payee == 'Altan Gadas LLC')
          .reconciledOn,
      DateTime(2026, 9, 10),
    );
  });

  test('a row looks locked exactly when the database refuses it', () async {
    Future<void> check() async {
      final data = await db.loadLedger();
      for (final account in data.balanceSheetAccounts) {
        final reg = data.registerFor(account.id);
        for (final r in [...reg.posted, ...reg.scheduled]) {
          Object? error;
          try {
            await db.transaction(() async {
              await db.editTransaction(
                transactionId: r.txnId,
                accountId: account.id,
                date: r.date,
                today: today,
                payee: r.txnPayee,
                memo: r.memo,
              );
              // Only probing: roll the edit back.
              throw const _Rollback();
            });
          } catch (e) {
            error = e;
          }
          expect(
            error is LockedException,
            r.locked,
            reason: '${account.name} · ${r.payee} ${r.date}',
          );
        }
      }
    }

    // Only account sides are reconciled, and each by a statement.
    final stray = await db
        .customSelect(
          'SELECT e.id FROM entries e JOIN accounts a ON a.id = e.account_id '
          'WHERE e.cleared = ${Cleared.reconciled.index} AND '
          "(a.type NOT IN ('asset', 'liability') OR e.reconciliation_id IS NULL)",
        )
        .get();
    expect(stray, isEmpty);
    await check();
    await db.unreconcileLast(checking);
    await check();
    final data = await db.loadLedger();
    for (final a in data.balanceSheetAccounts) {
      expect(data.registerFor(a.id).posted.where((r) => r.locked), isEmpty);
    }
  });

  test('the database refuses statement dates out of order', () async {
    final data = await db.loadLedger();
    await expectLater(
      db.reconcile(
        accountId: checking,
        statementDate: today.add(const Duration(days: 1)),
        today: today,
        balance: data.clearedThrough(checking, today).balance,
      ),
      throwsA(isA<ReconcileDateException>()),
    );
    // The seed's last statement is 09.10.
    await expectLater(
      db.reconcile(
        accountId: checking,
        statementDate: DateTime(2026, 9, 9),
        today: today,
        balance: data.clearedThrough(checking, DateTime(2026, 9, 9)).balance,
      ),
      throwsA(
        isA<ReconcileDateException>().having(
          (e) => e.message,
          'message',
          'Already reconciled through 09.10',
        ),
      ),
    );
  });

  test(
    'restoring a snapshot keeps later clears, and refuses a locked row',
    () async {
      final reg = (await db.loadLedger()).registerFor(checking);
      final unitel = reg.posted.firstWhere((r) => r.payee == 'Unitel');
      final before = await db.snapshot(unitel.txnId);
      await db.editTransaction(
        transactionId: unitel.txnId,
        accountId: checking,
        date: unitel.date,
        today: today,
        payee: 'Mobicom',
        amount: -3500000,
      );
      await db.setClearedMany({unitel.entryId: Cleared.cleared});
      await db.restoreSnapshot(before);
      var row = (await db.loadLedger())
          .registerFor(checking)
          .posted
          .firstWhere((r) => r.txnId == unitel.txnId);
      expect(row.payee, 'Unitel');
      expect(row.amount, -3000000);
      expect(row.cleared, Cleared.cleared);

      final after = await db.snapshot(unitel.txnId);
      await db.reconcile(
        accountId: checking,
        statementDate: today,
        today: today,
        balance: (await db.loadLedger())
            .clearedThrough(checking, today)
            .balance,
      );
      await expectLater(
        db.restoreSnapshot(after),
        throwsA(isA<LockedException>()),
      );
      row = (await db.loadLedger())
          .registerFor(checking)
          .posted
          .firstWhere((r) => r.txnId == unitel.txnId);
      expect(row.cleared, Cleared.reconciled);
    },
  );

  test('payee remembers its last category', () async {
    expect(
      await db.lastCategoryFor('Sakura Coffee', checking),
      await categoryId('Dining out'),
    );
    expect(await db.lastCategoryFor('Nobody', checking), isNull);
  });

  test('bulk cleared skips reconciled and returns what it changed', () async {
    final reg = (await db.loadLedger()).registerFor(checking).posted;
    final unitel = reg.firstWhere((r) => r.payee == 'Unitel');
    final salary = reg.firstWhere((r) => r.payee == 'Altan Gadas LLC');
    final previous = await db.setClearedMany({
      unitel.entryId: Cleared.cleared,
      salary.entryId: Cleared.uncleared,
    });
    expect(previous, {unitel.entryId: Cleared.uncleared});
    expect((await db.loadLedger()).summaryFor(checking).unclearedCount, 1);
    await db.setClearedMany(previous);
    expect((await db.loadLedger()).summaryFor(checking).unclearedCount, 2);
  });

  test(
    'bulk categorize leaves splits and transfers alone, and undoes',
    () async {
      final reg = (await db.loadLedger()).registerFor(checking).posted;
      final ids = reg
          .where((r) => r.date == today || r.kind == RowKind.transfer)
          .map((r) => r.txnId)
          .toList();
      final gifts = await categoryId('Gifts');
      final previous = await db.setCategoryMany(
        transactionIds: ids,
        accountId: checking,
        categoryId: gifts,
      );
      expect(
        previous.length,
        1,
      ); // Unitel only: the split and transfers are skipped
      var after = (await db.loadLedger()).registerFor(checking).posted;
      expect(
        after.firstWhere((r) => r.payee == 'Unitel').categoryLabel,
        'Gifts',
      );
      expect(after.where((r) => r.kind == RowKind.transfer).length, 2);
      await db.restoreCategories(previous, checking);
      after = (await db.loadLedger()).registerFor(checking).posted;
      expect(
        after.firstWhere((r) => r.payee == 'Unitel').categoryLabel,
        'Phone & internet',
      );
    },
  );

  test('delete skips reconciled transactions', () async {
    final reg = (await db.loadLedger()).registerFor(checking).posted;
    final unitel = reg.firstWhere((r) => r.payee == 'Unitel');
    final salary = reg.firstWhere((r) => r.payee == 'Altan Gadas LLC');
    expect(await db.softDeleteMany([unitel.txnId, salary.txnId]), [
      unitel.txnId,
    ]);
    await expectLater(
      db.softDelete(salary.txnId),
      throwsA(isA<LockedException>()),
    );
    final left = (await db.loadLedger()).registerFor(checking).posted;
    expect(left.map((r) => r.payee), contains('Altan Gadas LLC'));
    expect(left.map((r) => r.payee), isNot(contains('Unitel')));
  });

  test('bulk delete and restore', () async {
    final ids = (await db.loadLedger())
        .registerFor(checking)
        .posted
        .where((r) => r.date == today)
        .map((r) => r.txnId)
        .toList();
    await db.softDeleteMany(ids);
    expect(
      (await db.loadLedger()).summaryFor(checking).working,
      418245000 + 3000000 + 8640000,
    );
    await db.restoreMany(ids);
    expect((await db.loadLedger()).summaryFor(checking).working, 418245000);
  });

  test('confirming early posts today, not on the future due date', () async {
    final scheduled = (await db.loadLedger()).registerFor(checking).scheduled;
    final rent = scheduled.first; // due 09.20
    final salary = scheduled.last; // due 10.10
    await db.confirmScheduled(rent.txnId, today);
    await db.confirmScheduled(salary.txnId, DateTime(2026, 10, 12));
    final posted = (await db.loadLedger()).registerFor(checking).posted;
    expect(posted.firstWhere((r) => r.txnId == rent.txnId).date, today);
    expect(
      posted.firstWhere((r) => r.txnId == salary.txnId).date,
      DateTime(2026, 10, 10),
    );
  });

  group('editing', () {
    Future<RegisterRow> row(String payee) async => (await db.loadLedger())
        .registerFor(checking)
        .posted
        .firstWhere((r) => r.payee == payee);

    test('changes every field of a simple transaction, and undoes', () async {
      final unitel = await row('Unitel');
      final before = await db.snapshot(unitel.txnId);
      await db.editTransaction(
        transactionId: unitel.txnId,
        accountId: checking,
        date: DateTime(2026, 9, 15),
        today: today,
        payee: 'Mobicom',
        memo: 'Prepaid',
        counterAccountId: await categoryId('Utilities'),
        amount: -3500000,
      );
      final edited = await row('Mobicom');
      expect(edited.date, DateTime(2026, 9, 15));
      expect(edited.memo, 'Prepaid');
      expect(edited.categoryLabel, 'Utilities');
      expect(
        (await db.loadLedger()).summaryFor(checking).working,
        418245000 - 500000,
      );

      await db.restoreSnapshot(before);
      final restored = await row('Unitel');
      expect(restored.amount, -3000000);
      expect(restored.categoryLabel, 'Phone & internet');
    });

    test('a split keeps its lines when only its header changes', () async {
      final split = (await db.loadLedger())
          .registerFor(checking)
          .posted
          .firstWhere((r) => r.kind == RowKind.split);
      await db.editTransaction(
        transactionId: split.txnId,
        accountId: checking,
        date: split.date,
        today: today,
        payee: 'Nomin',
        memo: 'Weekly shop',
      );
      final after = await row('Nomin');
      expect(after.splitLines.length, 2);
      expect(after.amount, -8640000);
      await expectLater(
        db.editTransaction(
          transactionId: split.txnId,
          accountId: checking,
          date: split.date,
          today: today,
          payee: 'Nomin',
          amount: -1,
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('reconciled transactions are locked', () async {
      final salary = await row('Altan Gadas LLC');
      await expectLater(
        db.editTransaction(
          transactionId: salary.txnId,
          accountId: checking,
          date: salary.date,
          today: today,
          payee: 'X',
          amount: 1,
        ),
        throwsA(isA<LockedException>()),
      );
    });

    test('moving a posted transaction into the future schedules it', () async {
      final coffee = await row('Sakura Coffee');
      await db.editTransaction(
        transactionId: coffee.txnId,
        accountId: checking,
        date: DateTime(2026, 9, 30),
        today: today,
        payee: 'Sakura Coffee',
      );
      final reg = (await db.loadLedger()).registerFor(checking);
      expect(reg.scheduled.any((r) => r.txnId == coffee.txnId), isTrue);
    });
  });

  group('forecast', () {
    Future<Forecast> forecast() async {
      final ledger = await db.loadLedger();
      return buildForecast(
        working: ledger.summaryFor(checking).working,
        today: today,
        scheduled: ledger.registerFor(checking).scheduled,
      );
    }

    test('comfortable: names the lowest point before payday', () async {
      final f = await forecast();
      expect(f.isShort, isFalse);
      expect(f.end, DateTime(2026, 10, 10));
      expect(f.billCount, 3);
      expect(f.billTotal, 279020000);
      expect(f.low, 139225000);
      expect(f.lowDate, DateTime(2026, 10, 1));
    });

    test('short: finds the day it runs out and what causes it', () async {
      await db.postSimple(
        accountId: checking,
        date: DateTime(2026, 9, 30),
        today: today,
        payee: 'МУИС',
        counterAccountId: await categoryId('Tuition'),
        amount: -210000000,
      );
      final f = await forecast();
      expect(f.isShort, isTrue);
      expect(f.firstShort, DateTime(2026, 9, 30));
      expect(f.low, -70775000);
    });

    test('already below zero counts as short from today', () {
      final f = buildForecast(working: -500, today: today, scheduled: const []);
      expect(f.isShort, isTrue);
      expect(f.shortNow, isTrue);
      expect(f.firstShort, DateTime(2026, 9, 16));
      expect(f.low, -500);
    });

    test('no scheduled income falls back to a 30 day horizon', () {
      final f = buildForecast(working: 100, today: today, scheduled: const []);
      expect(f.payday, isNull);
      expect(f.end, DateTime(2026, 10, 16));
      expect(f.isShort, isFalse);
    });
  });
}

class _Rollback implements Exception {
  const _Rollback();
}
