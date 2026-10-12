import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/domain/forecast.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/pay.dart';
import 'package:betterbudget/import/mapping.dart';
import 'package:betterbudget/ui/entry_row.dart' show EditInitial;
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
              // Moving the date is what a lock refuses.
              await db.editTransaction(
                transactionId: r.txnId,
                accountId: account.id,
                date: r.date.subtract(const Duration(days: 1)),
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

      await db.editTransaction(
        transactionId: unitel.txnId,
        accountId: checking,
        date: unitel.date,
        today: today,
        payee: 'Mobicom',
        amount: -3500000,
      );
      final edited = await db.snapshot(unitel.txnId);
      await db.restoreSnapshot(before);
      final original = await db.snapshot(unitel.txnId);
      await db.reconcile(
        accountId: checking,
        statementDate: today,
        today: today,
        balance: (await db.loadLedger())
            .clearedThrough(checking, today)
            .balance,
      );
      // Reconciled: an amount can't come back, but a payee can.
      await expectLater(
        db.restoreSnapshot(edited),
        throwsA(isA<LockedException>()),
      );
      await db.editTransaction(
        transactionId: unitel.txnId,
        accountId: checking,
        date: unitel.date,
        today: today,
        payee: 'Unitel LLC',
      );
      await db.restoreSnapshot(original);
      row = (await db.loadLedger())
          .registerFor(checking)
          .posted
          .firstWhere((r) => r.txnId == unitel.txnId);
      expect(row.cleared, Cleared.reconciled);
      expect(row.payee, 'Unitel');
      expect(row.amount, -3000000);
    },
  );

  test('the off-by hint names the one row that explains it', () async {
    var data = await db.loadLedger();
    final unitel = data
        .registerFor(checking)
        .posted
        .firstWhere((r) => r.payee == 'Unitel');
    // The bank is ₮30,000 lower: Unitel cleared there.
    var hint = data.reconcileHint(checking, today, unitel.amount);
    expect(hint?.txnId, unitel.txnId);
    expect(hint?.cause, ReconcileCause.notCleared);
    // Nothing that size: no guess.
    expect(data.reconcileHint(checking, today, 123), isNull);

    // Sakura Coffee cleared here but not at the bank: the bank is higher.
    final coffee = data
        .registerFor(checking)
        .posted
        .firstWhere((r) => r.payee == 'Sakura Coffee');
    hint = data.reconcileHint(checking, today, -coffee.amount);
    expect(hint?.cause, ReconcileCause.clearedEarly);

    // A cleared row dated after the statement date isn't counted.
    final through = coffee.date.subtract(const Duration(days: 1));
    data = await db.loadLedger();
    hint = data.reconcileHint(checking, through, coffee.amount);
    expect(hint?.cause, ReconcileCause.datedAfter);
  });

  test('the cleared balance runs over cleared rows only', () async {
    final data = await db.loadLedger();
    final posted = data.registerFor(checking).posted;
    expect(
      posted.last.clearedBalance,
      data.clearedThrough(checking, today).balance,
    );
    final unitel = posted.firstWhere((r) => r.payee == 'Unitel');
    final i = posted.indexOf(unitel);
    expect(unitel.clearedBalance, posted[i - 1].clearedBalance);
  });

  test('an adjustment makes a reconcile match, and undoes with it', () async {
    var data = await db.loadLedger();
    final cleared = data.clearedThrough(checking, today);
    final done = await db.reconcile(
      accountId: checking,
      statementDate: today,
      today: today,
      balance: cleared.balance - 3000,
      adjust: true,
    );
    expect(done.adjustmentTxnId, isNotNull);
    expect(done.entryIds, hasLength(cleared.toLock + 1));
    data = await db.loadLedger();
    final adjustment = data
        .registerFor(checking)
        .posted
        .firstWhere((r) => r.txnId == done.adjustmentTxnId);
    expect(adjustment.payee, 'Reconcile adjustment');
    expect(adjustment.amount, -3000);
    expect(adjustment.cleared, Cleared.reconciled);
    // Not spending: it sits against an equity account, not a category.
    expect(adjustment.kind, RowKind.opening);
    expect(adjustment.categoryLabel, 'Balance adjustments');
    expect(
      data.categories.map((c) => c.name),
      isNot(contains('Balance adjustments')),
    );
    expect(
      data.clearedThrough(checking, today).balance,
      cleared.balance - 3000,
    );

    await db.unreconcile(done);
    data = await db.loadLedger();
    expect(
      data
          .registerFor(checking)
          .posted
          .where((r) => r.txnId == done.adjustmentTxnId),
      isEmpty,
    );
    expect(data.clearedThrough(checking, today).balance, cleared.balance);

    await db.relock(done);
    data = await db.loadLedger();
    expect(data.summaryFor(checking).reconciledOn, today);
    expect(
      data.clearedThrough(checking, today).balance,
      cleared.balance - 3000,
    );

    // Without adjust, the same statement is still refused.
    await db.unreconcile(done);
    await expectLater(
      db.reconcile(
        accountId: checking,
        statementDate: today,
        today: today,
        balance: cleared.balance - 3000,
      ),
      throwsA(isA<ReconcileMismatchException>()),
    );
  });

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

  test('a daylight-saving change doesn\'t shorten a count of days', () {
    // 23-hour and 25-hour local days still count as one each.
    expect(daysBefore(DateTime(2026, 3, 8), DateTime(2026, 3, 22)), 14);
    expect(daysBefore(DateTime(2026, 10, 25), DateTime(2026, 11, 8)), 14);
  });

  group('moving to another account', () {
    Future<int> account(String name) async => (await db.loadLedger())
        .balanceSheetAccounts
        .firstWhere((a) => a.name == name)
        .id;
    Future<RegisterRow> row(int account, String payee) async =>
        (await db.loadLedger())
            .registerFor(account)
            .posted
            .firstWhere((r) => r.payee == payee);

    test('moves one side, uncleared there; undo and redo', () async {
      final khan = await account('Khan Savings');
      final sakura = await row(checking, 'Sakura Coffee'); // cleared
      final before = (await db.loadLedger()).summaryFor(khan).working;
      final move = await db.moveToAccount(
        transactionId: sakura.txnId,
        fromAccountId: checking,
        toAccountId: khan,
      );
      var data = await db.loadLedger();
      expect(
        data.registerFor(checking).posted.map((r) => r.payee),
        isNot(contains('Sakura Coffee')),
      );
      final moved = await row(khan, 'Sakura Coffee');
      expect(moved.cleared, Cleared.uncleared);
      expect(moved.categoryLabel, 'Dining out');
      expect(moved.date, sakura.date);
      expect(data.summaryFor(khan).working, before - 800000);

      await db.undoMove(move);
      data = await db.loadLedger();
      expect((await row(checking, 'Sakura Coffee')).cleared, Cleared.cleared);
      expect(data.summaryFor(khan).working, before);

      await db.redoMove(move);
      expect((await row(khan, 'Sakura Coffee')).cleared, Cleared.uncleared);
      // Undo is refused once it's somewhere else than the move left it.
      await db.undoMove(move);
      await expectLater(db.undoMove(move), throwsA(isA<LockedException>()));
    });

    test('a transfer moves its side, but not onto its other side', () async {
      final khan = await account('Khan Savings');
      final cash = await account('Cash wallet');
      final transfer = await row(checking, 'Khan Savings');
      await expectLater(
        db.moveToAccount(
          transactionId: transfer.txnId,
          fromAccountId: checking,
          toAccountId: khan,
        ),
        throwsA(isA<LockedException>()),
      );
      await db.moveToAccount(
        transactionId: transfer.txnId,
        fromAccountId: checking,
        toAccountId: cash,
      );
      final fromCash = (await db.loadLedger())
          .registerFor(khan)
          .posted
          .firstWhere((r) => r.txnId == transfer.txnId);
      expect(fromCash.payee, 'Cash wallet');
      expect(fromCash.amount, 50000000);
    });

    test('refused from the unlocked side of a reconciled transfer, and for '
        'opening balances', () async {
      final khan = await account('Khan Savings');
      final cash = await account('Cash wallet');
      // The card payment is reconciled on TDB Checking's side only.
      final visa = await account('Golomt Visa');
      final payment = (await db.loadLedger())
          .registerFor(visa)
          .posted
          .firstWhere((r) => r.kind == RowKind.transfer);
      expect(payment.lockedIn, 'TDB Checking');
      await expectLater(
        db.moveToAccount(
          transactionId: payment.txnId,
          fromAccountId: visa,
          toAccountId: khan,
        ),
        throwsA(isA<LockedException>()),
      );
      final opening = (await db.loadLedger())
          .registerFor(cash)
          .posted
          .firstWhere((r) => r.kind == RowKind.opening);
      await expectLater(
        db.moveToAccount(
          transactionId: opening.txnId,
          fromAccountId: cash,
          toAccountId: khan,
        ),
        throwsA(isA<LockedException>()),
      );
    });

    test(
      'redo is refused once the row was reconciled after the undo',
      () async {
        final khan = await account('Khan Savings');
        final unitel = await row(checking, 'Unitel');
        final move = await db.moveToAccount(
          transactionId: unitel.txnId,
          fromAccountId: checking,
          toAccountId: khan,
        );
        await db.undoMove(move);
        await db.setClearedMany({unitel.entryId: Cleared.cleared});
        final cleared = (await db.loadLedger()).clearedThrough(checking, today);
        await db.reconcile(
          accountId: checking,
          statementDate: today,
          today: today,
          balance: cleared.balance,
        );
        await expectLater(db.redoMove(move), throwsA(isA<LockedException>()));
      },
    );

    test('refused for reconciled rows and for categories', () async {
      final khan = await account('Khan Savings');
      final salary = await row(checking, 'Altan Gadas LLC');
      await expectLater(
        db.moveToAccount(
          transactionId: salary.txnId,
          fromAccountId: checking,
          toAccountId: khan,
        ),
        throwsA(isA<LockedException>()),
      );
      final unitel = await row(checking, 'Unitel');
      await expectLater(
        db.moveToAccount(
          transactionId: unitel.txnId,
          fromAccountId: checking,
          toAccountId: await categoryId('Groceries'),
        ),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  test(
    'a card reconciles against what is owed, as a negative balance',
    () async {
      final visa = (await db.loadLedger()).balanceSheetAccounts
          .firstWhere((a) => a.name == 'Golomt Visa')
          .id;
      // The bank says ₮640,200 owed; typed positive, stored as the card's -.
      await expectLater(
        db.reconcile(
          accountId: visa,
          statementDate: today,
          today: today,
          balance: 64020000,
        ),
        throwsA(
          isA<ReconcileMismatchException>().having(
            (e) => e.off,
            'off',
            128040000,
          ),
        ),
      );
      // Owing ₮650,200: ₮10,000 more owed, so the adjustment adds to the debt.
      final done = await db.reconcile(
        accountId: visa,
        statementDate: today,
        today: today,
        balance: -65020000,
        adjust: true,
      );
      final data = await db.loadLedger();
      expect(data.summaryFor(visa).cleared, -65020000);
      final adjustment = data
          .registerFor(visa)
          .posted
          .firstWhere((r) => r.txnId == done.adjustmentTxnId);
      expect(adjustment.amount, -1000000);
      expect(adjustment.cleared, Cleared.reconciled);
      await db.unreconcile(done);
      expect((await db.loadLedger()).summaryFor(visa).cleared, -64020000);
    },
  );

  test('a big register is built once per account, quickly', () {
    // 20,000 rows with a reconcile every 100: every row once looked up the
    // newest reconcile across the whole ledger.
    final accounts = [
      const AccountInfo(id: 1, name: 'Checking', type: AccountType.asset),
      const AccountInfo(id: 2, name: 'Food', type: AccountType.expense),
    ];
    final txns = [
      for (var i = 0; i < 20000; i++)
        TxnData(
          id: i + 1,
          date: DateTime(2020).add(Duration(days: i ~/ 10)),
          payee: 'Shop $i',
          entries: [
            EntryData(
              id: 2 * i + 1,
              accountId: 1,
              amount: -1000,
              cleared: i < 19000 ? Cleared.reconciled : Cleared.cleared,
              reconciliationId: i < 19000 ? i ~/ 100 + 1 : null,
            ),
            EntryData(id: 2 * i + 2, accountId: 2, amount: 1000),
          ],
        ),
    ];
    final data = LedgerData(
      accounts: accounts,
      txns: txns,
      reconciliations: [
        for (var r = 0; r < 190; r++)
          Reconciliation(
            id: r + 1,
            accountId: 1,
            statementDate: DateTime(2020).add(Duration(days: r * 10 + 9)),
            balance: 0,
          ),
      ],
    );
    final clock = Stopwatch()..start();
    final register = data.registerFor(1);
    // Was over 5 s; generous so a slow machine doesn't fail it.
    expect(clock.elapsedMilliseconds, lessThan(2500));
    expect(register.posted, hasLength(20000));
    expect(register.posted.where((r) => r.latestReconcile), hasLength(100));
    // A rebuild (a keystroke in search) gets the same rows back.
    expect(identical(data.registerFor(1), register), isTrue);
  });

  test(
    'confirming with a different amount and date posts what happened',
    () async {
      final rent = (await db.loadLedger())
          .registerFor(checking)
          .scheduled
          .first;
      final before = await db.snapshot(rent.txnId);
      await expectLater(
        db.editTransaction(
          transactionId: rent.txnId,
          accountId: checking,
          date: DateTime(2026, 9, 17),
          today: today,
          amount: -185000000,
          confirm: true,
        ),
        throwsA(isA<LockedException>()),
      );
      await db.editTransaction(
        transactionId: rent.txnId,
        accountId: checking,
        date: DateTime(2026, 9, 15),
        today: today,
        payee: rent.payee,
        memo: rent.memo,
        amount: -185000000,
        confirm: true,
      );
      final ledger = await db.loadLedger();
      final posted = ledger
          .registerFor(checking)
          .posted
          .firstWhere((r) => r.txnId == rent.txnId);
      expect(posted.amount, -185000000);
      expect(posted.date, DateTime(2026, 9, 15));
      expect(posted.categoryLabel, 'Housing');
      expect(ledger.registerFor(checking).scheduled, hasLength(3));
      await db.restoreSnapshot(before);
      final back = (await db.loadLedger())
          .registerFor(checking)
          .scheduled
          .first;
      expect(
        (back.txnId, back.amount, back.date),
        (rent.txnId, -180000000, rent.date),
      );
    },
  );

  test(
    'money in confirmed short can keep the rest owed; bills never',
    () async {
      Future<RegisterRow> scheduled(String payee) async =>
          (await db.loadLedger())
              .registerFor(checking)
              .scheduled
              .firstWhere((r) => r.payee == payee);
      final salary = await scheduled('Altan Gadas LLC'); // +₮2,500,000, 10.10
      final owedId = await db.editTransaction(
        transactionId: salary.txnId,
        accountId: checking,
        date: today,
        today: today,
        payee: 'Altan Gadas LLC',
        memo: salary.memo,
        amount: 125000000,
        confirm: true,
        keepOwed: true,
      );
      expect(owedId, isNotNull);
      final ledger = await db.loadLedger();
      final owed = ledger
          .registerFor(checking)
          .scheduled
          .firstWhere((r) => r.txnId == owedId);
      expect(owed.amount, 125000000);
      expect(owed.date, DateTime(2026, 10, 10));
      expect(owed.categoryLabel, 'Income');
      expect(owed.payee, 'Altan Gadas LLC');
      expect(owed.memo, salary.memo);
      expect(
        ledger
            .registerFor(checking)
            .posted
            .firstWhere((r) => r.txnId == salary.txnId)
            .amount,
        125000000,
      );
      expect(await db.customSelect(AppDatabase.unbalancedSql).get(), isEmpty);

      // Kept with the payee as corrected while confirming.
      expect(owed.txnPayee, 'Altan Gadas LLC');

      // A transfer moved short is the user's own call: nothing kept.
      final savings = ledger.balanceSheetAccounts
          .firstWhere((a) => a.name == 'Khan Savings')
          .id;
      final moveIn = await db.postTransaction(
        date: DateTime(2026, 9, 20),
        scheduled: true,
        lines: [
          (accountId: checking, amount: 100000000, cleared: Cleared.uncleared),
          (accountId: savings, amount: -100000000, cleared: Cleared.uncleared),
        ],
      );
      expect(
        await db.editTransaction(
          transactionId: moveIn,
          accountId: checking,
          date: today,
          today: today,
          amount: 50000000,
          confirm: true,
          keepOwed: true,
        ),
        isNull,
      );

      // Not short: nothing kept.
      final refund = await db.postTransaction(
        date: DateTime(2026, 9, 18),
        payee: 'Nomin',
        scheduled: true,
        lines: [
          (accountId: checking, amount: 3000000, cleared: Cleared.uncleared),
          (
            accountId: await categoryId('Clothing'),
            amount: -3000000,
            cleared: Cleared.uncleared,
          ),
        ],
      );
      expect(
        await db.editTransaction(
          transactionId: refund,
          accountId: checking,
          date: today,
          today: today,
          payee: 'Nomin',
          amount: 3000000,
          confirm: true,
          keepOwed: true,
        ),
        isNull,
      );

      // A bill that came in lower owes nothing more, even if asked.
      final rent = await scheduled('Zaisan Residence');
      expect(
        await db.editTransaction(
          transactionId: rent.txnId,
          accountId: checking,
          date: today,
          today: today,
          payee: rent.payee,
          amount: -170000000,
          confirm: true,
          keepOwed: true,
        ),
        isNull,
      );
    },
  );

  test(
    'confirm dates late money in today; late bills keep their due date',
    () async {
      final scheduled = (await db.loadLedger()).registerFor(checking).scheduled;
      final rent = scheduled.first; // 09.20
      final salary = scheduled.last; // 10.10
      final later = DateTime(2026, 10, 12);
      expect(EditInitial.fromRow(salary, confirmingOn: later).date, later);
      expect(EditInitial.fromRow(rent, confirmingOn: later).date, rent.date);
      // Not due yet: today, either way.
      expect(EditInitial.fromRow(rent, confirmingOn: today).date, today);
    },
  );

  test('old uncleared and overdue scheduled rows get a note', () {
    RegisterRow row(
      DateTime date, {
      bool scheduled = false,
      Cleared c = Cleared.uncleared,
    }) => RegisterRow(
      txnId: 1,
      entryId: 1,
      date: date,
      payee: 'X',
      memo: '',
      amount: -100,
      cleared: c,
      scheduled: scheduled,
      kind: RowKind.simple,
      categoryLabel: 'Y',
      categoryId: 2,
      splitLines: const [],
    );
    DateTime ago(int d) => DateTime(today.year, today.month, today.day - d);
    // Never reconciled: by age, a card's later than a bank account's.
    const bank = (statement: null, owed: false);
    const card = (statement: null, owed: true);
    expect(unclearedDoubt(row(ago(13)), today, bank), isNull);
    expect(unclearedDoubt(row(ago(14)), today, bank), (
      statement: null,
      days: 14,
    ));
    expect(unclearedDoubt(row(ago(29)), today, card), isNull);
    expect(unclearedDoubt(row(ago(30)), today, card)?.days, 30);
    expect(
      unclearedDoubt(row(ago(40), c: Cleared.cleared), today, bank),
      isNull,
    );
    // Reconciled: what the statement should have had, however old. A row
    // from its last days may be a hold the statement was too early for.
    final statement = (statement: ago(20), owed: false);
    expect(unclearedDoubt(row(ago(23)), today, statement), (
      statement: ago(20),
      days: null,
    ));
    expect(unclearedDoubt(row(ago(22)), today, statement), isNull);
    expect(unclearedDoubt(row(ago(19)), today, statement), isNull);
    // A card's hold sits a month: the statement has to be that much later.
    final cardStatement = (statement: ago(10), owed: true);
    expect(unclearedDoubt(row(ago(39)), today, cardStatement), isNull);
    expect(
      unclearedDoubt(row(ago(40)), today, cardStatement)?.statement,
      ago(10),
    );
    // Reconciled once, long ago: rows since then say their age, late.
    final old = (statement: ago(90), owed: false);
    expect(unclearedDoubt(row(ago(44)), today, old), isNull);
    expect(unclearedDoubt(row(ago(45)), today, old), (
      statement: null,
      days: 45,
    ));
    // Cash: nothing ever clears it.
    expect(unclearedDoubt(row(ago(400)), today, null), isNull);
    expect(overdueNote(row(today, scheduled: true), today), isNull);
    expect(overdueNote(row(ago(1), scheduled: true), today), 'due yesterday');
    expect(overdueNote(row(ago(7), scheduled: true), today), 'due 7 days ago');
    expect(overdueNote(row(ago(7)), today), isNull);
  });

  test('a row is tied to a plan as its bill, and untied', () async {
    final ledger = await db.loadLedger();
    final row = ledger.txns.firstWhere((t) => !t.scheduled);
    final category = ledger.categories.first.id;
    expect(await db.setPlanBill(row.id, category), isNull);
    expect(
      (await db.loadLedger()).txns
          .firstWhere((t) => t.id == row.id)
          .planCategoryId,
      category,
    );
    expect(await db.setPlanBill(row.id, null), category);
    expect(
      (await db.loadLedger()).txns
          .firstWhere((t) => t.id == row.id)
          .planCategoryId,
      isNull,
    );
  });

  test('a scheduled bill finds the row already in that it would repeat', () {
    RegisterRow row(
      int id,
      DateTime date, {
      String payee = 'Rent',
      int amount = -900000,
      bool scheduled = false,
      int account = 1,
      int category = 2,
      int? plan,
    }) => RegisterRow(
      txnId: id,
      entryId: id,
      date: date,
      payee: payee,
      memo: '',
      amount: amount,
      cleared: Cleared.uncleared,
      scheduled: scheduled,
      kind: RowKind.simple,
      categoryLabel: 'Y',
      categoryId: category,
      splitLines: const [],
      accountId: account,
      planCategoryId: plan,
    );
    DateTime day(int d) => DateTime(2026, 9, d);
    final bill = row(1, day(20), scheduled: true);
    int? found(List<RegisterRow> posted, {RegisterRow? of, int on = 20}) =>
        alreadyIn(of ?? bill, posted, day(on))?.txnId;

    expect(found([row(2, day(14)), row(3, day(26))]), 3); // a tie: the later
    expect(found([row(2, day(13))]), isNull); // a week off: last week's
    expect(found([row(2, day(21), payee: ' rent ')]), 2);
    expect(found([row(2, day(21), payee: 'Water')]), isNull);
    expect(found([row(2, day(21), account: 5)]), isNull);
    expect(found([row(2, day(21), amount: 900000)]), isNull); // a refund
    expect(found([row(2, day(21), scheduled: true)]), isNull);
    expect(found([row(2, day(15)), row(3, day(19))]), 3); // the nearest
    // Paid late, it is dated late: a late bill looks as far as today.
    expect(found([row(2, day(29))]), isNull);
    expect(found([row(2, day(29))], on: 30), 2);

    // A category's bill: a row in that category for about the amount counts,
    // whatever the bank called the payee, though a row with the payee comes
    // first; not the one already tied to the plan (the bill before).
    final planned = row(1, day(20), scheduled: true, plan: 9);
    final bank = row(2, day(20), payee: 'IB TRANSFER', category: 9);
    expect(found([bank], of: planned), 2);
    expect(found([bank, row(3, day(17))], of: planned), 3);
    expect(
      found([
        row(2, day(20), payee: 'Other', category: 9, amount: -400000),
      ], of: planned),
      isNull,
    );
    expect(found([row(2, day(16), plan: 9, category: 9)], of: planned), isNull);
    // The bank's spelling of the same name: Cyrillic for Latin, c for k,
    // a company's full name around the one the bill goes by.
    expect(payeeKey(' МОБИКОМ Корпораци ХХК '), 'mobikomkorporatsihhk');
    expect(payeeKey('Mobicom'), 'mobikom');
    expect(samePayeeName('Mobicom', 'МОБИКОМ КОРПОРАЦИ ХХК'), isTrue);
    expect(samePayeeName('Khan Bank', 'ХААН БАНК'), isFalse); // aa for a
    expect(samePayeeName('Номин', 'NOMIN SUPERMARKET'), isTrue);
    expect(samePayeeName('TDB', 'TDB CHARGE'), isFalse); // too short
    expect(samePayeeName('TDB', 'tdb'), isTrue);
    expect(samePayeeName('', 'Rent'), isFalse);
    final mobicom = row(1, day(20), payee: 'Mobicom', scheduled: true);
    expect(
      found([row(2, day(21), payee: 'МОБИКОМ КОРПОРАЦИ ХХК')], of: mobicom),
      2,
    );
    // As typed comes before another spelling, however near that one is.
    expect(
      found([
        row(2, day(20), payee: 'МОБИКОМ КОРПОРАЦИ ХХК'),
        row(3, day(17), payee: 'mobicom'),
      ], of: mobicom),
      3,
    );
    // An import nobody has categorized, under a name that says nothing:
    // only for exactly the bill's amount.
    int? waiting(int amount) => alreadyIn(
      bill,
      [row(2, day(21), payee: 'IB 0412', category: 7, amount: amount)],
      day(20),
      uncategorizedId: 7,
    )?.txnId;
    expect(waiting(-900000), 2);
    expect(waiting(-900100), isNull);
    expect(found([row(2, day(21), payee: 'IB 0412', category: 7)]), isNull);

    // A payday is never looked for here.
    expect(
      alreadyIn(
        RegisterRow(
          txnId: 1,
          entryId: 1,
          date: day(20),
          payee: 'Rent',
          memo: '',
          amount: 900000,
          cleared: Cleared.uncleared,
          scheduled: true,
          kind: RowKind.simple,
          categoryLabel: 'Y',
          categoryId: 2,
          splitLines: const [],
          accountId: 1,
          payScheduleId: 4,
        ),
        [row(2, day(20), amount: 900000)],
        day(20),
      ),
      isNull,
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

    test(
      'reconciled: date, amount and account locked; the rest edits',
      () async {
        final salary = await row('Altan Gadas LLC');
        Future<void> edit({
          DateTime? date,
          int? amount,
          int? counter,
          String payee = 'Altan Gadas',
        }) => db.editTransaction(
          transactionId: salary.txnId,
          accountId: checking,
          date: date ?? salary.date,
          today: today,
          payee: payee,
          memo: 'Цалин 9-р сар',
          amount: amount,
          counterAccountId: counter,
        );
        final savings = (await db.loadLedger()).balanceSheetAccounts
            .firstWhere((a) => a.name == 'Khan Savings')
            .id;
        for (final refused in [
          () => edit(amount: salary.amount + 100),
          () => edit(date: salary.date.subtract(const Duration(days: 1))),
          () => edit(counter: savings), // would become a transfer
        ]) {
          await expectLater(refused(), throwsA(isA<LockedException>()));
        }

        // Payee, memo and category aren't on a statement.
        final gifts = await categoryId('Gifts');
        await edit(amount: salary.amount, counter: gifts);
        final after = await row('Altan Gadas');
        expect(after.memo, 'Цалин 9-р сар');
        expect(after.categoryLabel, 'Gifts');
        expect(after.amount, salary.amount);
        expect(after.cleared, Cleared.reconciled);
      },
    );

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

    test('landing exactly on zero is short too', () {
      final r = RegisterRow(
        txnId: 1,
        entryId: 1,
        date: DateTime(2026, 9, 20),
        payee: 'Rent',
        memo: '',
        amount: -500,
        cleared: Cleared.uncleared,
        scheduled: true,
        kind: RowKind.simple,
        categoryLabel: 'Housing',
        categoryId: 1,
        splitLines: const [],
      );
      final f = buildForecast(working: 500, today: today, scheduled: [r]);
      expect(f.isShort, isTrue);
      expect(f.firstShort, DateTime(2026, 9, 20));
      expect(f.low, 0);
    });

    test('already below zero counts as short from today', () {
      final f = buildForecast(working: -500, today: today, scheduled: const []);
      expect(f.isShort, isTrue);
      expect(f.shortNow, isTrue);
      expect(f.firstShort, DateTime(2026, 9, 16));
      expect(f.low, -500);
    });

    test(
      'a scheduled transfer in lifts the line; only income ends it',
      () async {
        final savings = (await db.loadLedger()).balanceSheetAccounts
            .firstWhere((a) => a.name == 'Khan Savings')
            .id;
        // Money moved in from savings before rent, and a small refund.
        await db.postSimple(
          accountId: checking,
          date: DateTime(2026, 9, 19),
          today: today,
          payee: '',
          counterAccountId: savings,
          amount: 100000000,
        );
        await db.postSimple(
          accountId: checking,
          date: DateTime(2026, 9, 18),
          today: today,
          payee: 'E-Mart',
          counterAccountId: await categoryId('Groceries'),
          amount: 500000,
        );
        final f = await forecast();
        // The refund isn't payday: the forecast still runs to the salary.
        expect(f.end, DateTime(2026, 10, 10));
        expect(f.payday!.payee, 'Altan Gadas LLC');
        expect(f.inTotal, 100500000);
        expect(f.billCount, 3);
        expect(f.low, 139225000 + 100500000);
        expect(f.steps.map((s) => s.row.amount > 0), [
          true,
          true,
          false,
          false,
          false,
        ]);
      },
    );

    test('a card forecasts what will be owed, never a shortfall', () async {
      final data = await db.loadLedger();
      final visa = data.balanceSheetAccounts
          .firstWhere((a) => a.name == 'Golomt Visa')
          .id;
      final f = buildForecast(
        working: data.summaryFor(visa).working,
        today: today,
        scheduled: data.registerFor(visa).scheduled,
        owed: true,
      );
      expect(f.owed, isTrue);
      expect(f.payday, isNull);
      expect(f.isShort, isFalse);
      expect(f.startBalance, 64020000); // owed, positive
      expect(f.inTotal, 64020000); // the scheduled payment
      expect(f.endBalance, 0);
    });

    test('a late salary is not counted; the forecast runs on past it', () {
      RegisterRow row(
        DateTime date,
        int amount,
        String category, {
        bool income = false,
      }) => RegisterRow(
        txnId: date.day + amount.abs() % 97,
        entryId: 1,
        date: date,
        payee: 'P',
        memo: '',
        amount: amount,
        cleared: Cleared.uncleared,
        scheduled: true,
        kind: RowKind.simple,
        categoryLabel: category,
        categoryId: 1,
        splitLines: const [],
        incomeCategory: income,
      );
      // Today 09.16. Salary was due 09.14; rent 09.20; next salary 10.14.
      final lateSalary = row(
        DateTime(2026, 9, 14),
        250000000,
        'Salary',
        income: true,
      );
      final lateRefund = row(DateTime(2026, 9, 10), 500000, 'Clothing');
      final lateBill = row(DateTime(2026, 9, 12), -3000000, 'Phone');
      final rent = row(DateTime(2026, 9, 20), -180000000, 'Housing');
      final nextSalary = row(
        DateTime(2026, 10, 14),
        250000000,
        'Salary',
        income: true,
      );
      final f = buildForecast(
        working: 38200000,
        today: today,
        scheduled: [lateRefund, lateBill, lateSalary, rent, nextSalary],
      );
      expect(f.late, [lateRefund, lateSalary]);
      expect(f.inTotal, 0); // the late refund doesn't lift the line
      expect(f.payday, same(nextSalary));
      expect(f.end, DateTime(2026, 10, 14));
      // The late bill counts today; rent counts; no late money in.
      expect(f.steps.map((s) => s.row), [lateBill, rent]);
      expect(f.firstShort, DateTime(2026, 9, 20));
      expect(f.low, 38200000 - 3000000 - 180000000);

      // With no later salary: 30 days out, still without the late one.
      final alone = buildForecast(
        working: 38200000,
        today: today,
        scheduled: [lateSalary, rent],
      );
      expect(alone.payday, isNull);
      expect(alone.end, DateTime(2026, 10, 16));
      expect(alone.isShort, isTrue);

      // Salary due today waits too: on payday morning it may still be late,
      // and rent in four days must still show.
      final dueToday = row(today, 250000000, 'Salary', income: true);
      final onPayday = buildForecast(
        working: 38200000,
        today: today,
        scheduled: [dueToday, rent, nextSalary],
      );
      expect(onPayday.late, [dueToday]);
      expect(onPayday.payday, same(nextSalary));
      expect(onPayday.steps.map((s) => s.row), [rent]);

      // A late transfer in from savings is the user's own doing: it counts,
      // as due today, the same as on the savings side.
      final lateTransfer = RegisterRow(
        txnId: 99,
        entryId: 99,
        date: DateTime(2026, 9, 12),
        payee: 'Khan Savings',
        memo: '',
        amount: 100000000,
        cleared: Cleared.uncleared,
        scheduled: true,
        kind: RowKind.transfer,
        categoryLabel: 'Transfer',
        categoryId: null,
        splitLines: const [],
      );
      final moved = buildForecast(
        working: 38200000,
        today: today,
        scheduled: [lateTransfer, rent],
      );
      expect(moved.late, isEmpty);
      expect(moved.steps.first.date, today);
      expect(moved.inTotal, 100000000);

      // A card doesn't warn, so a late payment to it still counts.
      final card = buildForecast(
        working: -64020000,
        today: today,
        scheduled: [row(DateTime(2026, 9, 14), 64020000, 'Transfer')],
        owed: true,
      );
      expect(card.late, isEmpty);
      expect(card.endBalance, 0);
    });

    test('no scheduled income falls back to a 30 day horizon', () {
      final f = buildForecast(working: 100, today: today, scheduled: const []);
      expect(f.payday, isNull);
      expect(f.end, DateTime(2026, 10, 16));
      expect(f.isShort, isFalse);
    });

    group('through the next pay period (owner, 2026-09-30)', () {
      RegisterRow row(int txn, DateTime date, int amount, {bool pay = false}) =>
          RegisterRow(
            txnId: txn,
            entryId: txn,
            date: date,
            payee: 'P',
            memo: '',
            amount: amount,
            cleared: Cleared.uncleared,
            scheduled: true,
            kind: RowKind.simple,
            categoryLabel: pay ? 'Salary' : 'Rent',
            categoryId: 1,
            splitLines: const [],
            incomeCategory: pay,
            payScheduleId: pay ? 7 : null,
          );
      // Today 09.16, payday tomorrow; the plan's next one is 10.17.
      final salary = row(1, DateTime(2026, 9, 17), 250000000, pay: true);
      ({DateTime date, int amount})? after(RegisterRow r) =>
          (date: DateTime(2026, 10, 17), amount: 250000000);

      test('payday tomorrow shows the month after it, not one day', () {
        final rent = row(2, DateTime(2026, 9, 20), -180000000);
        final phone = row(3, DateTime(2026, 10, 17), -3000000);
        final later = row(4, DateTime(2026, 10, 18), -9000000);
        final f = buildForecast(
          working: 10000000,
          today: today,
          scheduled: [salary, rent, phone, later],
          paydayAfter: after,
        );
        expect(f.throughPeriod, isTrue);
        expect(f.payday, same(salary));
        expect(f.end, DateTime(2026, 10, 17));
        // The paycheck is a step; a bill on the last payday counts.
        expect(f.steps.map((s) => s.row), [salary, rent, phone]);
        expect(f.inTotal, 0); // the paycheck isn't "money in" beside it
        expect(f.billCount, 2);
        expect(f.low, 10000000);
        expect(f.endBalance, 10000000 + 250000000 - 183000000);
      });

      test('bills on payday go out before the paycheck', () {
        final same = row(2, DateTime(2026, 9, 17), -30000000);
        final f = buildForecast(
          working: 10000000,
          today: today,
          scheduled: [salary, same],
          paydayAfter: after,
        );
        expect(f.steps.map((s) => s.row), [same, salary]);
        expect(f.firstShort, DateTime(2026, 9, 17));
      });

      test('money in on the last day waits, like the paycheck there', () {
        // A refund, not pay: no plan, not a payday category.
        final refund = row(2, DateTime(2026, 10, 17), 5000000);
        final earlier = row(3, DateTime(2026, 10, 16), 5000000);
        final f = buildForecast(
          working: 10000000,
          today: today,
          scheduled: [salary, earlier, refund],
          paydayAfter: after,
        );
        expect(f.steps.map((s) => s.row), [salary, earlier]);
        expect(f.inTotal, 5000000);
      });

      test('with no plan it still ends at payday', () {
        final rent = row(2, DateTime(2026, 9, 20), -180000000);
        final f = buildForecast(
          working: 10000000,
          today: today,
          scheduled: [salary, rent],
        );
        expect(f.throughPeriod, isFalse);
        expect(f.end, DateTime(2026, 9, 17));
        expect(f.steps, isEmpty);
      });
    });

    test('a paycheck moved by hand still finds the payday after', () async {
      await db.savePaySchedule(
        accountId: checking,
        amount: 100000000,
        rule: PayRule.monthly,
        day1: 25,
        today: today,
      );
      final plan = (await db.loadLedger()).paySchedules.single;
      // 09.25 moved by hand to 09.23: the next is still 10.23 (a Friday,
      // 10.25 being a Sunday), not 09.25.
      expect(
        plan.nextAfter(plan.plannedFor(DateTime(2026, 9, 23))),
        DateTime(2026, 10, 23),
      );
    });

    test(
      'a chosen span runs to its date, paydays and bills projected',
      () async {
        // Pay on the 25th into checking: 09.25 is scheduled. Water on the
        // 1st, monthly, paid from checking: 10.01 is scheduled.
        await db.savePaySchedule(
          accountId: checking,
          amount: 100000000,
          rule: PayRule.monthly,
          day1: 25,
          today: today,
        );
        final water = await categoryId('Household');
        await db.changeCategoryPlan(
          water,
          CategoryPlan(
            categoryId: water,
            kind: PlanKind.byDate,
            amount: 5000000,
            start: today,
            due: DateTime(2026, 10, 1),
            everyMonths: 1,
            paidFrom: checking,
          ),
          today,
        );
        final ledger = await db.loadLedger();
        final scheduled = ledger.registerFor(checking).scheduled;
        final until = ForecastSpan.days90.endFrom(today);
        expect(until, DateTime(2026, 12, 15));
        final projected = projectScheduled(
          scheduled,
          until: DateTime(2026, 12, 31),
          payById: ledger.payScheduleById,
          planOf: (id) => ledger.plans[id],
        );
        final f = buildForecast(
          working: ledger.summaryFor(checking).working,
          today: today,
          scheduled: scheduled,
          payIsSetUp: true,
          until: DateTime(2026, 12, 31),
          projected: projected,
        );
        expect(f.fixedEnd, isTrue);
        expect(f.throughPeriod, isFalse);
        expect(f.end, DateTime(2026, 12, 31));
        // The scheduled payday is a step, and the three after it follow the
        // schedule (10.25 is a Sunday: the Friday before).
        expect(f.paydayCounted, isTrue);
        expect(
          f.steps.where((s) => s.row.payScheduleId != null).map((s) => s.date),
          [
            DateTime(2026, 9, 25),
            DateTime(2026, 10, 23),
            DateTime(2026, 11, 25),
            DateTime(2026, 12, 25),
          ],
        );
        // The projected paychecks are money in, beside the demo's own
        // salary typed by hand on 10.10 (with pay set up, money in, not a
        // payday); the scheduled payday is the step.
        expect(f.inTotal, 300000000 + 250000000);
        // The bill comes on the 1st each month through the date, the
        // projected ones as copies of the scheduled row (a click opens it).
        final bills = f.steps.where((s) => s.row.planCategoryId == water);
        expect(bills.map((s) => s.date), [
          DateTime(2026, 10, 1),
          DateTime(2026, 11, 1),
          DateTime(2026, 12, 1),
        ]);
        expect(bills.map((s) => s.row.txnId).toSet().length, 1);
        // Through the pay period (09.25 to 10.23), nothing is projected: the
        // one scheduled bill, as before.
        final pay = ledger.paySchedules.single;
        final byPay = buildForecast(
          working: ledger.summaryFor(checking).working,
          today: today,
          scheduled: scheduled,
          payIsSetUp: true,
          paydayAfter: (row) {
            final next = pay.nextAfter(row.date);
            return (date: next, amount: pay.amountOn(next));
          },
          projected: projected,
        );
        expect(byPay.fixedEnd, isFalse);
        expect(byPay.end, DateTime(2026, 10, 23));
        expect(
          byPay.steps.where((s) => s.row.planCategoryId == water).length,
          1,
        );
      },
    );

    test('a late advance on split pay still ends at the rest', () {
      // Advance on the 10th, the rest on the 25th; the 09.10 advance moved
      // to 09.18 is nearer 09.25 by date, but it's the advance by amount.
      const plan = PaySchedule(
        id: 1,
        categoryId: 1,
        accountId: 1,
        amount: 300,
        amount2: 100,
        rule: PayRule.twiceMonthly,
        day1: 25,
        day2: 10,
      );
      final moved = DateTime(2026, 9, 18);
      expect(
        plan.nextAfter(plan.plannedFor(moved, paid: 100)),
        DateTime(2026, 9, 25),
      );
    });
  });

  group('accounts', () {
    Future<int> accountId(String name) async => (await db.loadLedger())
        .balanceSheetAccounts
        .firstWhere((a) => a.name == name)
        .id;

    test('a new account goes last, in its group, and starts cleared', () async {
      final card = await db.createAccount(
        name: ' Khan Visa ',
        type: AccountType.liability,
      );
      await db.postOpeningBalance(
        accountId: card,
        date: today,
        balance: -50000000,
      );
      final data = await db.loadLedger();
      final a = data.accounts[card]!;
      expect(a.name, 'Khan Visa');
      expect(a.group, 'Credit');
      expect(data.openAccounts.last.id, card);
      final s = data.summaryFor(card);
      expect(s.cleared, -50000000);
      expect(s.working, -50000000);
      final row = data.registerFor(card).posted.single;
      expect(row.kind, RowKind.opening);
      expect(row.payee, 'Opening balance');
      // The seed's own equity account, not a second one.
      expect(
        data.accounts.values.where((a) => a.name == 'Opening balances'),
        hasLength(1),
      );
    });

    test('undoing an added account leaves it once it has rows; '
        'nothing posts to a deleted one', () async {
      final id = await db.createAccount(name: 'Spare', type: AccountType.asset);
      await db.postOpeningBalance(accountId: id, date: today, balance: 100000);
      expect(await db.deleteEmptyAccount(id), isFalse);
      expect((await db.loadLedger()).accounts[id]!.deleted, isFalse);

      final empty = await db.createAccount(
        name: 'Mistake',
        type: AccountType.asset,
      );
      expect(await db.deleteEmptyAccount(empty), isTrue);
      await expectLater(
        db.postSimple(
          accountId: checking,
          date: today,
          today: today,
          payee: 'Nowhere',
          counterAccountId: empty,
          amount: -1000,
        ),
        throwsA(isA<NotFoundException>()),
      );
      await db.undeleteAccount(DeletedAccount(empty, const []));
      expect((await db.loadLedger()).openAccounts.last.id, empty);
    });

    test(
      'changing kind flips an opening balance typed the wrong way',
      () async {
        final card = await db.createAccount(
          name: 'Golomt Visa 2',
          type: AccountType.asset,
        );
        await db.postOpeningBalance(
          accountId: card,
          date: today,
          balance: 64020000,
        );
        await db.postSimple(
          accountId: card,
          date: today,
          today: today,
          payee: 'Coffee',
          counterAccountId: await categoryId('Dining out'),
          amount: -800000,
        );
        expect(await db.setAccountType(card, AccountType.liability), isTrue);
        var data = await db.loadLedger();
        // Owed 640,200 plus the coffee, not in credit.
        expect(data.balanceOf(card), -64820000);
        expect(await db.setAccountType(card, AccountType.asset), isTrue);
        data = await db.loadLedger();
        expect(data.balanceOf(card), 63220000);
      },
    );

    test('changing kind moves the group; a reconciled opening stays', () async {
      final savings = await accountId('Khan Savings');
      await db.setAccountType(savings, AccountType.liability);
      final data = await db.loadLedger();
      expect(data.accounts[savings]!.isOwed, isTrue);
      expect(data.accounts[savings]!.group, 'Credit');
      // Checking's opening balance is locked by its statement: never flipped.
      final before = (await db.loadLedger()).summaryFor(checking).cleared;
      await db.customStatement(
        'UPDATE entries SET cleared = ${Cleared.reconciled.index} '
        'WHERE account_id = ? AND transaction_id = ('
        'SELECT MIN(transaction_id) FROM entries WHERE account_id = ?)',
        [checking, checking],
      );
      expect(await db.setAccountType(checking, AccountType.liability), isFalse);
      expect((await db.loadLedger()).summaryFor(checking).cleared, before);
    });

    test('archived: out of the lists, still in net worth', () async {
      final savings = await accountId('Khan Savings');
      await db.setArchived(savings, true);
      final data = await db.loadLedger();
      expect(data.openAccounts.map((a) => a.id), isNot(contains(savings)));
      expect(data.archivedAccounts.single.id, savings);
      expect(data.balanceSheetAccounts.map((a) => a.id), contains(savings));
      await db.setArchived(savings, false);
      expect((await db.loadLedger()).archivedAccounts, isEmpty);
    });

    test('delete: its own rows go, transfers stay on the other account, '
        'and the preview says so', () async {
      final savings = await accountId('Khan Savings');
      final before = await db.loadLedger();
      final preview = before.deletePreview(checking);
      final savingsBefore = before.registerFor(savings);
      final transfers = savingsBefore.posted
          .where((r) => r.kind == RowKind.transfer && r.payee == 'TDB Checking')
          .toList();
      expect(transfers, isNotEmpty);
      expect(
        preview.keptOn.entries
            .singleWhere((e) => e.key.name == 'Khan Savings')
            .value,
        transfers.length,
      );

      // A transfer reconciled on Checking's side locks Savings' side, until
      // Checking is deleted: its statements no longer hold anything.
      await db.customStatement(
        'UPDATE entries SET cleared = ${Cleared.reconciled.index} '
        'WHERE account_id = ? AND transaction_id = ?',
        [checking, transfers.first.txnId],
      );
      expect(
        (await db.loadLedger())
            .registerFor(savings)
            .posted
            .firstWhere((r) => r.txnId == transfers.first.txnId)
            .lockedIn,
        'TDB Checking',
      );

      final done = await db.deleteAccount(checking);
      expect(done.transactionIds, hasLength(preview.rows));
      final after = await db.loadLedger();
      expect(after.accounts[checking]!.deleted, isTrue);
      expect(
        after.balanceSheetAccounts.map((a) => a.id),
        isNot(contains(checking)),
      );
      // Savings is exactly as it was.
      expect(after.balanceOf(savings), before.balanceOf(savings));
      expect(
        after.summaryFor(savings).cleared,
        before.summaryFor(savings).cleared,
      );
      final kept = after
          .registerFor(savings)
          .posted
          .firstWhere((r) => r.txnId == transfers.first.txnId);
      expect(kept.payee, 'TDB Checking (deleted)');
      expect(kept.otherClosed, isTrue);
      expect(kept.lockedIn, isNull);
      await db.softDelete(kept.txnId); // no longer locked

      // Nothing can move onto it.
      final wallet = await accountId('Cash wallet');
      final walletRow = after.registerFor(wallet).posted.first;
      await expectLater(
        db.moveToAccount(
          transactionId: walletRow.txnId,
          fromAccountId: wallet,
          toAccountId: checking,
        ),
        throwsA(isA<NotFoundException>()),
      );

      await db.restoreMany([kept.txnId]);
      await db.undeleteAccount(done);
      final back = await db.loadLedger();
      expect(back.accounts[checking]!.deleted, isFalse);
      expect(
        back.summaryFor(checking).working,
        before.summaryFor(checking).working,
      );
      expect(
        back.registerFor(checking).posted,
        hasLength(before.registerFor(checking).posted.length),
      );
    });
  });

  group('categories', () {
    test('a category whose only rows are deleted is deleted without asking '
        'where they go; one with a row still there is not', () async {
      final dining = await categoryId('Dining out');
      final before = await db.loadLedger();
      final rows = before
          .registerFor(checking)
          .posted
          .where((r) => r.categoryId == dining)
          .toList();
      expect(rows, isNotEmpty);
      expect(await db.categoryEntryCount(dining), rows.length);
      // A row still there: it has to go somewhere.
      await expectLater(
        db.deleteCategory(dining),
        throwsA(isA<LockedException>()),
      );
      // Every row deleted, as when its account is: nothing to move.
      await db.softDeleteMany(rows.map((r) => r.txnId));
      expect(await db.categoryEntryCount(dining), 0);
      final done = await db.deleteCategory(dining);
      expect(done.entryIds, isEmpty);
      var data = await db.loadLedger();
      expect(data.categories.map((c) => c.id), isNot(contains(dining)));

      // Undo runs newest first: the category back, then its rows, in it.
      await db.undeleteCategory(done);
      await db.restoreMany(rows.map((r) => r.txnId));
      data = await db.loadLedger();
      expect(data.categories.map((c) => c.id), contains(dining));
      expect(
        data
            .registerFor(checking)
            .posted
            .where((r) => r.categoryId == dining)
            .map((r) => r.txnId),
        unorderedEquals(rows.map((r) => r.txnId)),
      );
      expect(
        data.summaryFor(checking).working,
        before.summaryFor(checking).working,
      );
    });

    test(
      'delete moves every row, deleted ones too; undo moves them back',
      () async {
        final dining = await categoryId('Dining out');
        final groceries = await categoryId('Groceries');
        final before = await db.loadLedger();
        final sakura = before
            .registerFor(checking)
            .posted
            .firstWhere((r) => r.payee == 'Sakura Coffee');
        await db.softDelete(sakura.txnId);
        final done = await db.deleteCategory(dining, into: groceries);
        expect(done.entryIds, isNotEmpty);
        await db.restore(sakura.txnId); // an old delete undone later
        var data = await db.loadLedger();
        expect(data.categories.map((c) => c.id), isNot(contains(dining)));
        expect(
          data
              .registerFor(checking)
              .posted
              .firstWhere((r) => r.txnId == sakura.txnId)
              .categoryLabel,
          'Groceries',
        );
        expect(
          data.summaryFor(checking).working,
          before.summaryFor(checking).working,
        );

        await db.undeleteCategory(done);
        data = await db.loadLedger();
        expect(
          data
              .registerFor(checking)
              .posted
              .firstWhere((r) => r.txnId == sakura.txnId)
              .categoryLabel,
          'Dining out',
        );
      },
    );

    test('without a target, only an empty category can go', () async {
      final dining = await categoryId('Dining out');
      await expectLater(
        db.deleteCategory(dining),
        throwsA(isA<LockedException>()),
      );
      final tuition = await categoryId('Tuition');
      await db.deleteCategory(tuition);
      expect(
        (await db.loadLedger()).categories.map((c) => c.name),
        isNot(contains('Tuition')),
      );
    });

    test(
      'archived categories leave the menus, their rows keep the name',
      () async {
        final dining = await categoryId('Dining out');
        await db.setArchived(dining, true);
        final data = await db.loadLedger();
        expect(data.categories.map((c) => c.id), isNot(contains(dining)));
        expect(data.archivedCategories.single.id, dining);
        expect(
          data
              .registerFor(checking)
              .posted
              .firstWhere((r) => r.payee == 'Sakura Coffee')
              .categoryLabel,
          'Dining out',
        );
      },
    );
  });

  group('pay', () {
    test('money that came in is made a pay\'s paycheck: Income, counted for '
        'that pay, its payday no longer expected; undo, redo; and by a payee '
        'rule on import', () async {
      await db.savePaySchedule(
        accountId: checking,
        amount: 210000000,
        rule: PayRule.monthly,
        day1: 25,
        name: 'Loveland Solutions',
        today: today,
      );
      final pay = (await db.loadLedger()).paySchedules.single;
      final waiting = await db.createCategory('Not categorized');
      // It arrived a day early, and came in through the bank's file.
      final id = await db.postSimple(
        accountId: checking,
        date: DateTime(2026, 9, 15),
        today: today,
        payee: 'LOVESOL PAY 0915',
        counterAccountId: waiting,
        amount: 205000000,
      );
      Future<List<DateTime>> coming() async => [
        for (final r in (await db.loadLedger()).registerFor(checking).scheduled)
          if (r.payScheduleId == pay.id) r.date,
      ];
      Future<RegisterRow> row() async => (await db.loadLedger())
          .registerFor(checking)
          .posted
          .firstWhere((r) => r.txnId == id);
      expect(await coming(), [DateTime(2026, 9, 25)]);

      final taken = await db.takeAsPay(
        transactionId: id,
        accountId: checking,
        scheduleId: pay.id,
        today: today,
      );
      expect((await row()).categoryLabel, 'Income');
      expect((await row()).payScheduleId, pay.id);
      // 09.25 has come; the next is 10.23 (10.25 is a Sunday).
      expect(await coming(), [DateTime(2026, 10, 23)]);

      await db.undoTakeAsPay(taken);
      expect((await row()).categoryLabel, 'Not categorized');
      expect((await row()).payScheduleId, isNull);
      expect(await coming(), [DateTime(2026, 9, 25)]);
      await db.redoTakeAsPay(taken);
      expect((await row()).payScheduleId, pay.id);
      expect(await coming(), [DateTime(2026, 10, 23)]);
      await db.undoTakeAsPay(taken);

      // "Always file LoveSol under Income · Loveland Solutions": the next
      // file's paycheck is the pay's without being asked.
      await db.softDelete(id);
      await db.addPayeeRule(
        name: 'LoveSol',
        anywhere: false,
        categoryId: pay.categoryId,
        payId: pay.id,
        accountIds: {checking},
      );
      final rows = [
        ImportRow(
          sourceRow: 1,
          date: DateTime(2026, 9, 14),
          amount: 206000000,
          payee: 'LoveSol pay 0914',
        ),
        ImportRow(
          sourceRow: 2,
          date: DateTime(2026, 9, 14),
          amount: -4000,
          payee: 'LoveSol canteen',
        ),
      ];
      final record = await db.applyImport(
        accountId: checking,
        plan: (await db.planImport(
          checking,
          rows,
          importKeys(checking, rows),
        )).rows,
        uncategorizedNames: ['Not categorized'],
        today: today,
      );
      expect(record.paid, hasLength(1)); // money out is never a paycheck
      expect(await coming(), [DateTime(2026, 10, 23)]);
      await db.undoImport(record);
      expect(await coming(), [DateTime(2026, 9, 25)]);
      await db.redoImport(record, checking);
      expect(await coming(), [DateTime(2026, 10, 23)]);
    });

    test('a schedule keeps its next payday scheduled; undo and redo', () async {
      final change = await db.savePaySchedule(
        accountId: checking,
        amount: 210000000,
        varies: true,
        rule: PayRule.monthly,
        day1: 25,
        today: today,
      );
      expect(change.created, hasLength(1));
      var data = await db.loadLedger();
      final next = data
          .registerFor(checking)
          .scheduled
          .firstWhere((r) => r.txnId == change.created.single);
      expect(next.date, DateTime(2026, 9, 25));
      expect(next.estimate, 210000000);
      expect(next.isIncome, isTrue);
      // Nothing more while one is waiting.
      expect(await db.ensurePaydays(today), isEmpty);

      // Confirmed (for less): the one after comes from the plan.
      await db.editTransaction(
        transactionId: next.txnId,
        accountId: checking,
        date: DateTime(2026, 9, 25),
        today: DateTime(2026, 9, 25),
        amount: 200000000,
        confirm: true,
      );
      final after = await db.ensurePaydays(DateTime(2026, 9, 25));
      data = await db.loadLedger();
      final following = data
          .registerFor(checking)
          .scheduled
          .firstWhere((r) => r.txnId == after.single);
      expect(following.date, DateTime(2026, 10, 23)); // 10.25 is a Sunday
      expect(following.amount, 210000000);

      await db.undoPayChange(change);
      data = await db.loadLedger();
      expect(data.paySchedules, isEmpty);
      await db.redoPayChange(change);
      expect((await db.loadLedger()).paySchedules, hasLength(1));
    });

    test('an advance, then the rest: each payday at its own amount', () async {
      final change = await db.savePaySchedule(
        accountId: checking,
        amount: 160000000,
        amount2: 50000000,
        rule: PayRule.twiceMonthly,
        day1: 25,
        day2: 10,
        today: DateTime(2026, 9, 1),
      );
      var data = await db.loadLedger();
      final advance = data
          .registerFor(checking)
          .scheduled
          .firstWhere((r) => r.txnId == change.created.single);
      expect(advance.date, DateTime(2026, 9, 10));
      expect(advance.amount, 50000000);
      await db.editTransaction(
        transactionId: advance.txnId,
        accountId: checking,
        date: DateTime(2026, 9, 10),
        today: DateTime(2026, 9, 10),
        amount: 50000000,
        confirm: true,
      );
      final rest = await db.ensurePaydays(DateTime(2026, 9, 10));
      data = await db.loadLedger();
      final row = data
          .registerFor(checking)
          .scheduled
          .firstWhere((r) => r.txnId == rest.single);
      expect(row.date, DateTime(2026, 9, 25));
      expect(row.amount, 160000000);
      // Confirmed a week late, on the 18th: still the advance, so the rest
      // on the 25th stays the next payday.
      await db.editTransaction(
        transactionId: row.txnId,
        accountId: checking,
        date: DateTime(2026, 9, 25),
        today: DateTime(2026, 9, 25),
        amount: 160000000,
        confirm: true,
      );
      final october = await db.ensurePaydays(DateTime(2026, 9, 25));
      data = await db.loadLedger();
      final oct = data
          .registerFor(checking)
          .scheduled
          .firstWhere((r) => r.txnId == october.single);
      await db.editTransaction(
        transactionId: oct.txnId,
        accountId: checking,
        date: DateTime(2026, 10, 18),
        today: DateTime(2026, 10, 18),
        amount: 50000000,
        confirm: true,
      );
      final late = await db.ensurePaydays(DateTime(2026, 10, 18));
      data = await db.loadLedger();
      final after = data
          .registerFor(checking)
          .scheduled
          .firstWhere((r) => r.txnId == late.single);
      expect(after.date, DateTime(2026, 10, 23)); // 10.25 is a Sunday
      expect(after.amount, 160000000);
      // The same amount twice isn't split, and monthly never is.
      final same = await db.savePaySchedule(
        id: change.after.id,
        accountId: checking,
        amount: 100000000,
        amount2: 100000000,
        rule: PayRule.twiceMonthly,
        today: DateTime(2026, 9, 10),
      );
      expect(same.after.amount2Minor, isNull);
      final monthly = await db.savePaySchedule(
        id: change.after.id,
        accountId: checking,
        amount: 100000000,
        amount2: 50000000,
        rule: PayRule.monthly,
        today: DateTime(2026, 9, 10),
      );
      expect(monthly.after.amount2Minor, isNull);
    });

    Future<PayChange> monthly({bool period = false, int? id}) =>
        db.savePaySchedule(
          id: id,
          accountId: checking,
          amount: 210000000,
          rule: PayRule.monthly,
          day1: 25,
          today: today,
          definesPeriod: period,
        );

    test(
      'Income is the app\'s own: one of it, and it can\'t be deleted',
      () async {
        final income = await db.incomeCategory();
        expect(await db.incomeCategory(), income);
        final data = await db.loadLedger();
        expect(data.accounts.values.where((a) => a.isIncome), hasLength(1));
        expect(data.income!.name, incomeAccountName);
        final other = await db.createCategory('Side jobs');
        expect(
          (await db.loadLedger()).accounts[other]!.type,
          AccountType.expense,
        );
        await expectLater(
          db.deleteCategory(income, into: other),
          throwsA(isA<NotFoundException>()),
        );
        // A category made for income by mistake merges into it.
        await db.deleteCategory(other, into: income);
        expect((await db.loadLedger()).accounts[other]!.deleted, isTrue);
      },
    );

    test('income typed by hand before a set-up payday is money in, not the '
        'payday', () async {
      final income = await db.incomeCategory();
      final pay = await monthly();
      await db.postSimple(
        accountId: checking,
        date: DateTime(2026, 9, 18),
        today: today,
        payee: 'Хүүхдийн мөнгө',
        counterAccountId: income,
        amount: 10000000,
      );
      final data = await db.loadLedger();
      final scheduled = data.registerFor(checking).scheduled;
      final allowance = scheduled.firstWhere(
        (r) => r.payee == 'Хүүхдийн мөнгө',
      );
      expect(allowance.isIncome, isTrue);
      final f = buildForecast(
        working: data.summaryFor(checking).working,
        today: today,
        scheduled: scheduled,
      );
      expect(f.payday!.payScheduleId, pay.after.id);

      // With no pay set up anywhere, the income typed by hand ends it.
      final byHand = [
        for (final r in scheduled)
          if (r.payScheduleId == null) r,
      ];
      final alone = buildForecast(
        working: data.summaryFor(checking).working,
        today: today,
        scheduled: byHand,
      );
      expect(alone.payday!.isIncome, isTrue);
      expect(alone.payday!.payScheduleId, isNull);

      // With pay set up but none of it ahead here (payday morning, or
      // another account's pay), it's money in and the forecast runs on
      // past it, bills and all.
      final late = buildForecast(
        working: data.summaryFor(checking).working,
        today: today,
        scheduled: byHand,
        payIsSetUp: true,
      );
      expect(late.payday, isNull);
    });

    test('saving pay takes over the same pay scheduled by hand, and leaves '
        'other income', () async {
      final income = await db.incomeCategory();
      Future<int> byHand(String payee, int day, int amount) => db.postSimple(
        accountId: checking,
        date: DateTime(2026, 9, day),
        today: today,
        payee: payee,
        counterAccountId: income,
        amount: amount,
      );
      final allowance = await byHand('Хүүхдийн мөнгө', 22, 10000000);
      final samePayer = await byHand('Altan Gadas LLC', 24, 200000000);
      final change = await db.savePaySchedule(
        accountId: checking,
        payee: 'Altan Gadas LLC',
        amount: 210000000,
        rule: PayRule.monthly,
        day1: 25,
        today: today,
      );
      expect(change.replaced, contains(samePayer));
      expect(change.replaced, isNot(contains(allowance)));
      await db.undoPayChange(change);
      final ids = (await db.loadLedger()).txns.map((t) => t.id);
      expect(ids, containsAll([allowance, samePayer]));
    });

    test('merging a category into Income sends its money back', () async {
      final income = await db.incomeCategory();
      final food = await categoryId('Groceries');
      final sep = (DateTime(2026, 9, 1), DateTime(2026, 9, 30));
      await db.setBudgetAmount(food, sep.$1, sep.$2, 5000000);
      await db.deleteCategory(food, into: income);
      final data = await db.loadLedger();
      expect(data.budgetAmounts.where((b) => b.categoryId == income), isEmpty);
      // Income takes no budget of its own, and isn't renamed or archived.
      await expectLater(
        db.setBudgetAmount(income, sep.$1, sep.$2, 100),
        throwsA(isA<NotFoundException>()),
      );
      await expectLater(
        db.renameAccount(income, 'Wages'),
        throwsA(isA<NotFoundException>()),
      );
      await expectLater(
        db.setArchived(income, true),
        throwsA(isA<NotFoundException>()),
      );
    });

    Future<List<RegisterRow>> paydaysOf(int scheduleId) async =>
        (await db.loadLedger())
            .registerFor(checking)
            .scheduled
            .where((r) => r.payScheduleId == scheduleId)
            .toList();

    test(
      'paid early, the next payday is the one after, not the same one',
      () async {
        final change = await monthly();
        final row = (await paydaysOf(change.after.id)).single;
        await db.editTransaction(
          transactionId: row.txnId,
          accountId: checking,
          date: DateTime(2026, 9, 23),
          today: DateTime(2026, 9, 23),
          confirm: true,
        );
        await db.ensurePaydays(DateTime(2026, 9, 23));
        final next = await paydaysOf(change.after.id);
        expect(next.map((r) => r.date), [DateTime(2026, 10, 23)]);
      },
    );

    test('a payday deleted by the user stays skipped', () async {
      final change = await monthly();
      final row = (await paydaysOf(change.after.id)).single;
      await db.softDelete(row.txnId); // unpaid leave
      await db.ensurePaydays(today);
      final next = await paydaysOf(change.after.id);
      expect(next.map((r) => r.date), [DateTime(2026, 10, 23)]);
    });

    test('an overdue payday gets the next one scheduled behind it', () async {
      final change = await monthly();
      await db.ensurePaydays(DateTime(2026, 9, 28)); // the 25th didn't come
      final rows = await paydaysOf(change.after.id);
      expect(rows.map((r) => r.date), [
        DateTime(2026, 9, 25),
        DateTime(2026, 10, 23),
      ]);
    });

    test(
      'a salary scheduled by hand is taken over, and undo brings it back',
      () async {
        final salary = await db.incomeCategory();
        final manual = await db.postSimple(
          accountId: checking,
          date: DateTime(2026, 9, 25),
          today: today,
          payee: 'Altan Gadas LLC',
          counterAccountId: salary,
          amount: 210000000,
        );
        final change = await monthly();
        expect(change.replaced, [manual]);
        var income = (await db.loadLedger())
            .registerFor(checking)
            .scheduled
            .where((r) => r.date == DateTime(2026, 9, 25) && r.amount > 0);
        expect(income, hasLength(1));
        await db.undoPayChange(change);
        income = (await db.loadLedger())
            .registerFor(checking)
            .scheduled
            .where((r) => r.date == DateTime(2026, 9, 25) && r.amount > 0);
        expect(income.single.txnId, manual);
      },
    );

    test('keep the day: saved, then undone and redone exactly', () async {
      final first = await db.savePaySchedule(
        accountId: checking,
        amount: 100000,
        rule: PayRule.monthly,
        weekend: PayWeekend.after,
        today: today,
      );
      final keep = await db.savePaySchedule(
        id: first.after.id,
        accountId: checking,
        amount: 100000,
        rule: PayRule.monthly,
        weekend: PayWeekend.keep,
        today: today,
      );
      Future<PayWeekend> weekend() async =>
          (await db.loadLedger()).paySchedules.single.weekend;
      expect(await weekend(), PayWeekend.keep);
      await db.undoPayChange(keep);
      expect(await weekend(), PayWeekend.after);
      await db.redoPayChange(keep);
      expect(await weekend(), PayWeekend.keep);
    });

    test('a start date later than today is the first payday', () async {
      final change = await db.savePaySchedule(
        accountId: checking,
        amount: 100000,
        rule: PayRule.everyWeeks,
        anchor: DateTime(2026, 10, 9),
        today: today,
      );
      expect(
        (await paydaysOf(change.after.id)).single.date,
        DateTime(2026, 10, 9),
      );
    });

    test(
      'undo puts the pay period back exactly, after an edit or a stop',
      () async {
        final s1 = await monthly();
        final s2 = await monthly(period: true);
        // Edit S1 to take the period, then undo: S2 has it again, alone.
        final edit = await monthly(id: s1.after.id, period: true);
        expect((await db.loadLedger()).periodSchedule!.id, s1.after.id);
        await db.undoPayChange(edit);
        var data = await db.loadLedger();
        expect(data.paySchedules.where((p) => p.definesPeriod), hasLength(1));
        expect(data.periodSchedule!.id, s2.after.id);

        // Stop S1, undo: nothing else moves.
        final stop = await db.stopPaySchedule(s1.after.id, today);
        await db.undoPayChange(stop);
        data = await db.loadLedger();
        expect(data.periodSchedule!.id, s2.after.id);
      },
    );

    test('a pay keeps the name it was given, trimmed; empty is none', () async {
      final made = await db.savePaySchedule(
        accountId: checking,
        amount: 100000,
        rule: PayRule.monthly,
        name: ' Jenny ',
        today: today,
      );
      expect((await db.loadLedger()).paySchedules.single.name, 'Jenny');
      await db.savePaySchedule(
        id: made.after.id,
        accountId: checking,
        amount: 100000,
        rule: PayRule.monthly,
        name: '',
        today: today,
      );
      expect((await db.loadLedger()).paySchedules.single.name, isNull);
    });

    test('one schedule defines the pay period at a time', () async {
      final a = await db.savePaySchedule(
        accountId: checking,
        amount: 100000,
        rule: PayRule.monthly,
        today: today,
        definesPeriod: true,
      );
      await db.savePaySchedule(
        accountId: checking,
        amount: 100000,
        rule: PayRule.twiceMonthly,
        today: today,
        definesPeriod: true,
      );
      final data = await db.loadLedger();
      expect(data.paySchedules.where((p) => p.definesPeriod), hasLength(1));
      expect(data.periodSchedule!.id, isNot(a.after.id));
    });
  });
}

class _Rollback implements Exception {
  const _Rollback();
}
