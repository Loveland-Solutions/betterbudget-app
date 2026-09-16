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
    expect(s.reconciled, 514198050);
    expect(s.reconciledOn, DateTime(2026, 9, 10));
    expect(s.bankDataThrough, DateTime(2026, 9, 15));
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
      expect(f.causes, ['Tuition', 'Childcare']);
    });

    test('no scheduled income falls back to a 30 day horizon', () {
      final f = buildForecast(working: 100, today: today, scheduled: const []);
      expect(f.payday, isNull);
      expect(f.end, DateTime(2026, 10, 16));
      expect(f.isShort, isFalse);
    });
  });
}
