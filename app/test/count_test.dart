// Counting a cash account (#119, ADR 0004 "Counting a cash account"): a
// count is its difference row, which keeps what was counted; the
// difference follows the rows dated up to it.

import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late int wallet;
  late int groceries;
  late int holding;
  final today = DateTime(2026, 11, 30);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    wallet = await db.createAccount(
      name: 'Wallet',
      type: AccountType.asset,
      cash: true,
    );
    groceries = await db.createCategory('Groceries');
    holding = await db.createCategory('Not categorized');
  });
  tearDown(() => db.close());

  Future<int> spend(int day, int amount) => db.postSimple(
    accountId: wallet,
    date: DateTime(2026, 11, day),
    today: today,
    payee: 'Market',
    counterAccountId: groceries,
    amount: -amount,
  );

  Future<RegisterRow> countRow(int id) async => (await db.loadLedger())
      .registerFor(wallet)
      .posted
      .singleWhere((r) => r.txnId == id);

  test(
    'a count is a row of the difference that keeps what was counted',
    () async {
      await db.postSimple(
        accountId: wallet,
        date: DateTime(2026, 11, 1),
        today: today,
        payee: 'ATM',
        counterAccountId: holding,
        amount: 300000,
      );
      await spend(5, 45000);
      await spend(9, 8000);
      // The rows say 247,000; the wallet holds 212,500.
      final id = (await db.postCount(
        accountId: wallet,
        date: DateTime(2026, 11, 18),
        counted: 212500,
        categoryId: holding,
      )).id;
      final row = await countRow(id);
      expect(row.counted, 212500);
      expect(row.amount, -34500);
      expect(row.balance, 212500);
      expect(row.categoryId, holding);
    },
  );

  test('the difference is saved once, as on a bank account: a receipt for '
      'an earlier day that comes in later changes the balance, not the '
      'count', () async {
    await spend(1, -200000); // money in
    final id = (await db.postCount(
      accountId: wallet,
      date: DateTime(2026, 11, 18),
      counted: 165500,
      categoryId: holding,
    )).id;
    expect((await countRow(id)).amount, -34500);
    await spend(16, 12000);
    expect((await countRow(id)).amount, -34500);
    final data = await db.loadLedger();
    expect(data.balanceOf(wallet), 165500 - 12000);
  });

  test('two counts: each is measured from the rows as they are when it is '
      'made; one that matches is a row of nothing', () async {
    await spend(1, -100000);
    final first = (await db.postCount(
      accountId: wallet,
      date: DateTime(2026, 11, 10),
      counted: 90000,
      categoryId: groceries,
    )).id;
    expect((await countRow(first)).amount, -10000);
    final second = (await db.postCount(
      accountId: wallet,
      date: DateTime(2026, 11, 20),
      counted: 90000,
      categoryId: holding,
    )).id;
    expect((await countRow(second)).amount, 0);
    expect((await countRow(second)).counted, 90000);
    // Undone, the first's row goes; the second stays as it was saved.
    await db.softDeleteMany([first]);
    expect((await countRow(second)).amount, 0);
    expect((await db.loadLedger()).balanceOf(wallet), 100000);
  });

  test('a wallet with no opening balance that holds more than its rows: '
      'the extra is its opening balance, at its first row (owner, '
      '2026-11-18)', () async {
    // Started at nothing, a receipt typed on the 5th.
    await spend(5, 20000);
    final saved = await db.postCount(
      accountId: wallet,
      date: DateTime(2026, 11, 18),
      counted: 85000,
      categoryId: holding,
    );
    expect(saved.difference, 105000);
    expect(saved.openingId, isNotNull);
    final rows = (await db.loadLedger()).registerFor(wallet).posted;
    final opening = rows.singleWhere((r) => r.kind == RowKind.opening);
    expect(opening.amount, 105000);
    expect(opening.date, DateTime(2026, 11, 5));
    expect((await countRow(saved.id)).amount, 0);
    expect((await countRow(saved.id)).counted, 85000);
    expect((await db.loadLedger()).balanceOf(wallet), 85000);
    // Nothing went to Not categorized.
    expect(
      rows.where((r) => r.categoryId == holding && r.amount != 0),
      isEmpty,
    );
    // A second count is an ordinary one: the opening balance is there.
    final next = await db.postCount(
      accountId: wallet,
      date: DateTime(2026, 11, 25),
      counted: 90000,
      categoryId: holding,
    );
    expect(next.openingId, isNull);
    expect((await countRow(next.id)).amount, 5000);
  });

  test('with no opening balance, less than the rows is still missing '
      'money, not a starting balance below nothing', () async {
    await spend(5, -50000);
    final saved = await db.postCount(
      accountId: wallet,
      date: DateTime(2026, 11, 18),
      counted: 40000,
      categoryId: holding,
    );
    expect(saved.openingId, isNull);
    expect((await countRow(saved.id)).amount, -10000);
  });
}
