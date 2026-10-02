// Accounts in tugrik and dollars (ROADMAP E): each amount in its account's
// currency, totals never added across currencies, and transfers between
// them with both sides entered.
import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/money.dart';
import 'package:betterbudget/domain/readiness.dart';
import 'package:betterbudget/import/mapping.dart';
import 'package:betterbudget/import/sheet.dart';
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
    // Tugrik per dollar, whichever side is which.
    for (final x in [
      exchangeRate(345000000, Currency.mnt, 100000, Currency.usd),
      exchangeRate(100000, Currency.usd, 345000000, Currency.mnt),
    ]) {
      expect(x!.rate, 345000);
      expect(x.quote, Currency.mnt);
      expect(x.base, Currency.usd);
    }
  });

  test('every currency: its own decimals, its own people\'s symbol', () {
    addTearDown(() => Currency.hold(const []));
    expect(Currency.values, hasLength(155));
    expect(Currency.values.take(2), [Currency.mnt, Currency.usd]);
    expect({for (final c in Currency.values) c.code}, hasLength(155));
    // The long form tells any two apart.
    expect({for (final c in Currency.values) c.long}, hasLength(155));
    final yen = Currency.fromCode('JPY');
    final yuan = Currency.fromCode('CNY');
    final dinar = Currency.fromCode('KWD');
    final krona = Currency.fromCode('SEK');
    final rand = Currency.fromCode('ZAR');
    final cad = Currency.fromCode('CAD');
    final clp = Currency.fromCode('CLP');

    // The symbol is the one its people write, shared or not.
    expect(
      [cad.symbol, clp.symbol, yuan.symbol, yen.symbol],
      [r'$', r'$', '¥', '¥'],
    );
    expect([krona.symbol, rand.symbol, dinar.symbol], ['kr', 'R', 'KD']);
    // Every currency has a symbol; none falls back to its code.
    for (final c in Currency.values) {
      expect(c.symbol, isNot(c.code), reason: c.code);
      expect(c.symbol, isNotEmpty, reason: c.code);
    }
    expect(Currency.fromCode('THB').symbol, '฿');
    expect(Currency.fromCode('GNF').symbol, 'FG');

    // Alone in a ledger, a Canadian dollar is a dollar.
    Currency.hold([Currency.mnt, cad]);
    expect(formatMoney(120050, currency: cad), r'$1,200.50');
    // Beside a US account, each says which; the tugrik is untouched.
    Currency.hold([Currency.mnt, cad, Currency.usd]);
    expect(formatMoney(120050, currency: cad), r'CA$1,200.50');
    expect(formatMoney(120050, currency: Currency.usd), r'$1,200.50');
    expect(formatMoney(120050), '₮1,200.50');
    // Two with no longer symbol fall back to their codes.
    Currency.hold([clp, Currency.fromCode('COP')]);
    expect(formatMoney(1200, currency: clp), 'CLP 1,200');
    expect(parseAmount('CLP 1,200', clp), 1200);
    Currency.hold([yen, yuan]);
    expect(formatMoney(1200, currency: yen), '¥1,200');
    expect(formatMoney(1200, currency: yuan), 'CN¥12.00');
    Currency.hold(const []);

    // Yen has no cents: minor units are whole yen.
    expect(formatMoney(120000, currency: yen), '¥120,000');
    expect(formatShort(-1200, currency: yen), '−¥1,200');
    expect(parseAmount('1,200', yen), 1200);
    expect(parseAmount('1200.5', yen), isNull);
    expect(parseAmount('3*400', yen), 1200);
    expect(zeroHint(yen), '¥0');

    // A Kuwaiti dinar has three decimals.
    expect(formatMoney(1234567, currency: dinar), 'KD 1,234.567');
    expect(formatShort(5000, currency: dinar), 'KD 5');
    expect(parseAmount('1.5', dinar), 1500);
    expect(parseAmount('1.2345', dinar), isNull);
    expect(parseAmount('KD 12.250', dinar), 12250);
    expect(parseAmount('KWD 12.250', dinar), 12250);
    expect(typedAmount(12250, dinar), '12.250');

    // Letters are set off from the amount; a sign isn't.
    expect(formatMoney(120050, currency: krona), 'kr 1,200.50');
    expect(
      formatMoney(120050, currency: Currency.fromCode('PEN')),
      'S/ 1,200.50',
    );
    expect(
      formatMoney(120050, currency: Currency.fromCode('CHF')),
      'Fr. 1,200.50',
    );
    expect(
      formatMoney(120050, currency: Currency.fromCode('THB')),
      '฿1,200.50',
    );
    expect(
      formatMoney(120050, currency: Currency.fromCode('GHS')),
      'GH₵1,200.50',
    );
    expect(formatMoney(120050, currency: rand), 'R 1,200.50');
    expect(formatMoney(120050, currency: Currency.usd), r'$1,200.50');

    // Yen per dollar: one side has cents, the other doesn't.
    final x = exchangeRate(15000, yen, 10000, Currency.usd)!;
    expect((x.rate, x.quote, x.base), (150, yen, Currency.usd));
    expect(formatMoney(x.rate, currency: x.quote), '¥150');
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

      // Undo is the snapshot from before: plain tugrik again.
      await db.restoreSnapshot(before);
      data = await db.loadLedger();
      expect(data.balanceOf(chase), 0);
      expect(data.balanceOf(khan), 345000000);
      expect(await currencies(id), ['MNT', 'MNT']);

      // And back from dollars to tugrik by edit, the exchange legs go.
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

    test(
      'a memo edit on a reconciled exchange writes no money and undoes',
      () async {
        final id = await db.postExchange(
          fromAccountId: tdb,
          toAccountId: chase,
          date: DateTime(2026, 9, 5),
          today: today,
          sent: 345000000,
          received: 100000,
        );
        final entry = (await db.snapshot(id)).entries
            .firstWhere((e) => e.accountId == tdb)
            .id;
        await db.customStatement(
          'UPDATE entries SET cleared = ? WHERE id = ?',
          [Cleared.reconciled.index, entry],
        );
        final before = await db.snapshot(id);
        // The entry row sends the second amount as it was.
        await db.editTransaction(
          transactionId: id,
          accountId: tdb,
          date: DateTime(2026, 9, 5),
          today: today,
          memo: 'Tuition',
          amount: -345000000,
          counterAmount: 100000,
        );
        final after = await db.snapshot(id);
        expect(
          after.entries.map((e) => e.id).toSet(),
          before.entries.map((e) => e.id).toSet(),
        );
        await db.restoreSnapshot(before);
        expect((await db.snapshot(id)).header.memo, isNull);
        await db.restoreSnapshot(after);
        expect((await db.snapshot(id)).header.memo, 'Tuition');
      },
    );

    test('editing a tugrik row makes no exchange account', () async {
      final id = await db.postSimple(
        accountId: tdb,
        date: DateTime(2026, 9, 5),
        today: today,
        payee: 'Coffee',
        counterAccountId: food,
        amount: -800000,
      );
      await db.editTransaction(
        transactionId: id,
        accountId: tdb,
        date: DateTime(2026, 9, 5),
        today: today,
        memo: 'with a friend',
      );
      final data = await db.loadLedger();
      expect(
        data.accounts.values.any((a) => a.name == currencyExchangeName),
        isFalse,
      );
    });

    test('an exchange needs two accounts and two amounts', () async {
      Future<void> bad(int to, int received) => db.postExchange(
        fromAccountId: tdb,
        toAccountId: to,
        date: DateTime(2026, 9, 5),
        today: today,
        sent: 100,
        received: received,
      );
      expect(() => bad(food, 1), throwsA(isA<NotFoundException>()));
      expect(() => bad(chase, 0), throwsA(isA<LockedException>()));
    });

    test('a restored file must add up in each currency', () async {
      final id = await db.postSimple(
        accountId: tdb,
        date: DateTime(2026, 9, 5),
        today: today,
        payee: 'Coffee',
        counterAccountId: food,
        amount: -100,
      );
      expect(await db.customSelect(AppDatabase.unbalancedSql).get(), isEmpty);
      // +₮100 and −$100: zero in all, not in each.
      await db.customStatement(
        "UPDATE entries SET currency = 'USD' WHERE transaction_id = ? "
        'AND account_id = ?',
        [id, food],
      );
      expect(
        (await db.customSelect(AppDatabase.unbalancedSql).get()).single
            .read<int>('transaction_id'),
        id,
      );
    });

    test('Savings counts the currency most accounts are in', () async {
      final data = await db.loadLedger();
      expect(mainCurrency(data), Currency.mnt); // one each: tugrik
      await db.createAccount(
        name: 'Ally',
        type: AccountType.asset,
        currency: Currency.usd,
      );
      expect(mainCurrency(await db.loadLedger()), Currency.usd);
    });
  });

  test('a typed month is kept in its currency', () {
    expect(typedMonth('MNT:300000000', Currency.mnt), 300000000);
    expect(typedMonth('MNT:300000000', Currency.usd), isNull);
    expect(typedMonth('300000000', Currency.mnt), 300000000); // from before
    expect(typedMonth(null, Currency.mnt), isNull);
  });

  test('a file that names one currency says which', () {
    expect(
      fileCurrency(
        const Sheet([
          ['Данс: 0000000000 MNT'],
          ['2026.09.01', '100'],
        ]),
      ),
      Currency.mnt,
    );
    expect(
      fileCurrency(
        const Sheet([
          ['Date', 'Amount'],
          ['2026-09-01', r'$12.00'],
        ]),
      ),
      Currency.usd,
    );
    expect(
      fileCurrency(
        const Sheet([
          ['USD', 'MNT'],
        ]),
      ),
      isNull,
    );
  });
}
