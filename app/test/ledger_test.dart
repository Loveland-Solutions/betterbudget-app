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
        payee: salary.payee,
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
      expect(owed.categoryLabel, 'Salary');
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
    expect(staleNote(row(ago(13)), today), isNull);
    expect(staleNote(row(ago(14)), today), 'not cleared for 14 days');
    expect(staleNote(row(ago(40), c: Cleared.cleared), today), isNull);
    expect(overdueNote(row(today, scheduled: true), today), isNull);
    expect(overdueNote(row(ago(1), scheduled: true), today), 'due yesterday');
    expect(overdueNote(row(ago(7), scheduled: true), today), 'due 7 days ago');
    expect(overdueNote(row(ago(7)), today), isNull);
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
  });
}

class _Rollback implements Exception {
  const _Rollback();
}
