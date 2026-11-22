// Finishing setup (#475), with the owner's answers of 2026-11-23: the
// currency saved in is picked when the accounts hold more than one (#616), an
// overdrawn start starts the budget short (#617), and All of it follows the
// accounts from setup's balances' day to the day the budget began (#618).
import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/setup_finish.dart';
import 'package:betterbudget/domain/budget.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/money.dart';
import 'package:betterbudget/domain/readiness.dart' show isSafetyNet;
import 'package:betterbudget/domain/setup.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final today = DateTime(2026, 11, 3);
  final began = DateTime(2026, 11, 1);

  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> account(
    String name,
    int balance,
    DateTime on, {
    Currency currency = Currency.mnt,
  }) async {
    final id = await db.createAccount(
      name: name,
      type: AccountType.asset,
      currency: currency,
    );
    await db.postOpeningBalance(accountId: id, date: on, balance: balance);
    return id;
  }

  Future<int> category(String name) => db.createAccount(
    name: name,
    type: AccountType.expense,
  );

  Future<void> spend(int from, int to, int amount, DateTime on) =>
      db.postSimple(
        accountId: from,
        date: on,
        today: today,
        payee: 'Shop',
        counterAccountId: to,
        amount: amount,
      );

  test('All of it follows the accounts: rows added later between the '
      'balances\' day and the budget\'s first day change it, rows from the '
      'budget\'s first day on don\'t (#618)', () async {
    final asOf = DateTime(2026, 10, 7);
    await db.setPreference(SetupKeys.date, dateKey(asOf));
    final khan = await account('Khan Checking', 80000000, asOf);
    await finishSetup(
      db,
      had: {Currency.mnt: 80000000},
      emergency: 0,
      today: today,
      safetyNetName: 'Safety net',
      follows: {Currency.mnt},
    );
    var data = await db.loadLedger();
    expect(data.prefs[BudgetKeys.hadBefore(Currency.mnt)], isNull);
    expect(hadBeforeOf(data, Currency.mnt, began), 80000000);

    // October's salary and rent, typed a week later, and November's food.
    final income = await db.incomeCategory();
    final rent = await category('Rent');
    final food = await category('Food');
    await spend(khan, income, 250000000, DateTime(2026, 10, 25));
    await spend(khan, rent, -90000000, DateTime(2026, 10, 28));
    await spend(khan, food, -5000000, DateTime(2026, 11, 1));
    data = await db.loadLedger();
    // What the bank showed on November 1: ₮800,000 + ₮2,500,000 − ₮900,000.
    expect(hadBeforeOf(data, Currency.mnt, began), 240000000);
    // The budget counts it on its first day.
    final b = Budget.of(
      data,
      start: began,
      end: DateTime(2026, 11, 30),
      today: today,
    );
    expect(b.pools.single.hadBefore, 240000000);

    // A figure typed in Settings takes its place.
    await db.setPreference(BudgetKeys.hadBefore(Currency.mnt), '100000000');
    await db.setPreference(BudgetKeys.hadFrom(Currency.mnt), null);
    data = await db.loadLedger();
    expect(hadBeforeOf(data, Currency.mnt, began), 100000000);
  });

  test('balances as of a day in the budget\'s first period are what it had, '
      'as before (#618)', () async {
    final asOf = DateTime(2026, 11, 3);
    await db.setPreference(SetupKeys.date, dateKey(asOf));
    await account('Khan Checking', 80000000, asOf);
    await finishSetup(
      db,
      had: {Currency.mnt: 80000000},
      emergency: 0,
      today: today,
      safetyNetName: 'Safety net',
      follows: {Currency.mnt},
    );
    var data = await db.loadLedger();
    // Kept as an amount: rows from the budget's first day on count in the
    // period itself (code review: following them too counted them twice).
    expect(data.prefs[BudgetKeys.hadFrom(Currency.mnt)], isNull);
    expect(data.prefs[BudgetKeys.hadBefore(Currency.mnt)], '80000000');
    final khan = data.accounts.values.singleWhere(
      (a) => a.name == 'Khan Checking',
    );
    await spend(khan.id, await category('Food'), -5000000, asOf);
    data = await db.loadLedger();
    expect(hadBeforeOf(data, Currency.mnt, began), 80000000);
  });

  test('an overdrawn start is asked about, and the budget starts that much '
      'short (#617)', () async {
    await db.setPreference(SetupKeys.date, dateKey(today));
    await account('Khan Checking', -40000000, today);
    var data = await db.loadLedger();
    expect(setupHeld(data), {Currency.mnt: -40000000});
    expect(setupAsksMoney(data), isTrue);
    await finishSetup(
      db,
      had: {Currency.mnt: -40000000},
      emergency: 0,
      today: today,
      safetyNetName: 'Safety net',
      follows: {Currency.mnt},
    );
    data = await db.loadLedger();
    expect(hadBeforeOf(data, Currency.mnt, began), -40000000);
    expect(data.prefs[BudgetKeys.began], dateKey(began));
    final b = Budget.of(
      data,
      start: began,
      end: DateTime(2026, 11, 30),
      today: today,
    );
    expect(b.pools.single.hadBefore, -40000000);
    // Short by it: nothing to assign until it's made up, and named as
    // what it is, not "short from October" (code review).
    expect(b.pools.single.notAssigned, -40000000);
    expect(b.pools.single.shortBy().overdrawn, 40000000);
    expect(b.pools.single.shortBy().carried, 0);
  });

  test('the currency saved in, picked when the accounts hold two, is the '
      'Safety net\'s and the budget\'s own; undo puts it back (#616)', () async {
    await db.setPreference(SetupKeys.date, dateKey(today));
    await account('Khan Checking', 120000000, today);
    await account(
      'Golomt Savings',
      300000,
      today,
      currency: Currency.usd,
    );
    await account('TDB Deposit', 500000, today, currency: Currency.usd);
    var data = await db.loadLedger();
    expect(setupCurrencies(data), [Currency.mnt, Currency.usd]);
    // Two of three bank and cash accounts are in dollars: dollars to begin
    // with, one of the answers offered.
    expect(setupSaveIn(data), Currency.usd);
    await db.setPreference(SetupKeys.saveIn, Currency.mnt.code);
    data = await db.loadLedger();
    expect(setupSaveIn(data), Currency.mnt);

    final done = await finishSetup(
      db,
      had: {Currency.mnt: 120000000, Currency.usd: 800000},
      emergency: 50000000,
      today: today,
      safetyNetName: 'Safety net',
      follows: {Currency.mnt, Currency.usd},
      saveIn: Currency.mnt,
    );
    data = await db.loadLedger();
    final net = data.accounts.values.singleWhere(isSafetyNet);
    expect(net.currency, Currency.mnt);
    expect(Budget.currencyOf(data), Currency.mnt);
    expect(data.prefs[BudgetKeys.currency], Currency.mnt.code);
    await done.undo();
    data = await db.loadLedger();
    expect(data.prefs[BudgetKeys.currency], isNull);
    expect(data.prefs[SetupKeys.done], isNull);
    await done.redo();
    expect((await db.loadLedger()).prefs[BudgetKeys.currency], 'MNT');
  });
}
