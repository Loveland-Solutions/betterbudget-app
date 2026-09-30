// Accounts in tögrög and dollars (ROADMAP E): each amount in its account's
// currency, totals never added across currencies, and transfers between
// them with both sides entered.
import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/money.dart';
import 'package:betterbudget/domain/readiness.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('money reads and writes in either currency', () {
    expect(formatMoney(123450), '₮1,234.50');
    expect(formatMoney(-123450, currency: Currency.usd), r'−$1,234.50');
    expect(formatRounded(-123450, currency: Currency.usd), r'−$1,234');
    expect(parseAmount(r'$12.50'), 1250);
    expect(Currency.fromCode('USD'), Currency.usd);
    expect(Currency.fromCode(null), Currency.mnt);
    expect(mntPerDollar(345000000, Currency.mnt, 100000, Currency.usd), 345000);
    expect(mntPerDollar(100000, Currency.usd, 345000000, Currency.mnt), 345000);
  });

  group('database', () {
    late AppDatabase db;
    late int tdb;
    late int chase;
    late int food;
    final today = DateTime(2026, 9, 30);
    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      tdb = await db.createAccount(name: 'TDB', type: AccountType.asset);
      chase = await db.createAccount(
        name: 'Chase',
        type: AccountType.asset,
        currency: Currency.usd,
      );
      food = await db.createCategory('Food');
    });
    tearDown(() => db.close());

    Future<List<String>> currencies(int txn) async => [
      for (final e in (await db.snapshot(txn)).entries) e.currency,
    ];

    test('an account keeps its currency; its rows are in it', () async {
      final id = await db.postSimple(
        accountId: chase,
        date: DateTime(2026, 9, 2),
        today: today,
        payee: 'Groceries',
        counterAccountId: food,
        amount: -4250,
      );
      expect(await currencies(id), ['USD', 'USD']);
      await db.postSimple(
        accountId: tdb,
        date: DateTime(2026, 9, 3),
        today: today,
        payee: 'Номин',
        counterAccountId: food,
        amount: -1250000,
      );
      final data = await db.loadLedger();
      expect(data.accounts[chase]!.currency, Currency.usd);
      expect(data.accounts[tdb]!.currency, Currency.mnt);
      expect(data.registerFor(chase).posted.single.currency, Currency.usd);
      // One category, two currencies: never added together.
      expect(data.categoryTotals(food), {
        Currency.mnt: 1250000,
        Currency.usd: 4250,
      });
      expect(data.balancesByCurrency(data.balanceSheetAccounts), {
        Currency.mnt: -1250000,
        Currency.usd: -4250,
      });
    });

    test('a transfer between currencies records both sides', () async {
      final id = await db.postExchange(
        fromAccountId: tdb,
        toAccountId: chase,
        date: DateTime(2026, 9, 5),
        today: today,
        sent: 345000000,
        received: 100000,
      );
      var data = await db.loadLedger();
      expect(data.balanceOf(tdb), -345000000);
      expect(data.balanceOf(chase), 100000);
      final out = data.registerFor(tdb).posted.single;
      expect(out.kind, RowKind.transfer);
      expect(out.payee, 'Chase');
      expect(out.otherAmount, 100000);
      expect(out.otherCurrency, Currency.usd);
      final inn = data.registerFor(chase).posted.single;
      expect(inn.kind, RowKind.transfer);
      expect(inn.amount, 100000);
      expect(inn.otherAmount, -345000000);
      // Once in All accounts, from the side the money leaves.
      expect(data.registerAll().posted.length, 1);
      await db.softDelete(id);
      data = await db.loadLedger();
      expect(data.balanceOf(tdb), 0);
      expect(data.balanceOf(chase), 0);
    });

    test(
      'one amount across currencies, or a move between them, is refused',
      () async {
        expect(
          () => db.postSimple(
            accountId: tdb,
            date: DateTime(2026, 9, 5),
            today: today,
            payee: '',
            counterAccountId: chase,
            amount: -100,
          ),
          throwsA(
            isA<LockedException>().having(
              (e) => e.problem,
              'problem',
              DbProblem.needsOtherAmount,
            ),
          ),
        );
        final id = await db.postSimple(
          accountId: tdb,
          date: DateTime(2026, 9, 5),
          today: today,
          payee: 'Coffee',
          counterAccountId: food,
          amount: -800000,
        );
        expect(
          () => db.moveToAccount(
            transactionId: id,
            fromAccountId: tdb,
            toAccountId: chase,
          ),
          throwsA(
            isA<LockedException>().having(
              (e) => e.problem,
              'problem',
              DbProblem.otherCurrency,
            ),
          ),
        );
      },
    );

    test('an edit can take a transfer across currencies and back, and undo '
        'restores it exactly', () async {
      final khan = await db.createAccount(
        name: 'Khan',
        type: AccountType.asset,
      );
      final id = await db.postSimple(
        accountId: tdb,
        date: DateTime(2026, 9, 5),
        today: today,
        payee: '',
        counterAccountId: khan,
        amount: -345000000,
      );
      final before = await db.snapshot(id);

      // Without the other side it can't go to dollars.
      expect(
        () => db.editTransaction(
          transactionId: id,
          accountId: tdb,
          date: DateTime(2026, 9, 5),
          today: today,
          counterAccountId: chase,
        ),
        throwsA(isA<LockedException>()),
      );
      await db.editTransaction(
        transactionId: id,
        accountId: tdb,
        date: DateTime(2026, 9, 5),
        today: today,
        counterAccountId: chase,
        counterAmount: 100000,
      );
      var data = await db.loadLedger();
      expect(data.balanceOf(khan), 0);
      expect(data.balanceOf(chase), 100000);
      expect(data.registerFor(tdb).posted.single.otherAmount, 100000);

      // The dollar side changes on its own.
      await db.editTransaction(
        transactionId: id,
        accountId: chase,
        date: DateTime(2026, 9, 5),
        today: today,
        amount: 99000,
      );
      data = await db.loadLedger();
      expect(data.balanceOf(chase), 99000);
      expect(data.balanceOf(tdb), -345000000);

      // Undo is the snapshot from before: plain tögrög again.
      await db.restoreSnapshot(before);
      data = await db.loadLedger();
      expect(data.balanceOf(chase), 0);
      expect(data.balanceOf(khan), 345000000);
      expect(await currencies(id), ['MNT', 'MNT']);

      // And back from dollars to tögrög by edit, the exchange legs go.
      await db.editTransaction(
        transactionId: id,
        accountId: tdb,
        date: DateTime(2026, 9, 5),
        today: today,
        counterAccountId: chase,
        counterAmount: 100000,
      );
      await db.editTransaction(
        transactionId: id,
        accountId: tdb,
        date: DateTime(2026, 9, 5),
        today: today,
        counterAccountId: khan,
      );
      expect((await db.snapshot(id)).entries.length, 2);
      data = await db.loadLedger();
      expect(data.balanceOf(khan), 345000000);
    });

    test('Savings counts the currency most accounts are in', () async {
      final data = await db.loadLedger();
      expect(mainCurrency(data), Currency.mnt); // one each: tögrög
      await db.createAccount(
        name: 'Ally',
        type: AccountType.asset,
        currency: Currency.usd,
      );
      expect(mainCurrency(await db.loadLedger()), Currency.usd);
    });
  });
}
