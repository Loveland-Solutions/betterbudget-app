import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/readiness.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Savings steps (rule 25), worked out from a small ledger.
void main() {
  final today = DateTime(2026, 9, 16);
  const checking = 1, savings = 2, visa = 3, mortgage = 4, food = 5;
  const opening = 6, rent = 7;
  var nextId = 100;

  AccountInfo acct(int id, String name, AccountType t, [AccountRole? role]) =>
      AccountInfo(id: id, name: name, type: t, role: role);

  TxnData move(DateTime date, int from, int to, int amount) => TxnData(
    id: nextId++,
    date: date,
    entries: [
      EntryData(id: nextId++, accountId: from, amount: -amount),
      EntryData(id: nextId++, accountId: to, amount: amount),
    ],
  );

  /// 91 days of 3,000.00 a day on food from checking, and opening balances.
  LedgerData ledger({
    AccountRole? savingsRole = AccountRole.emergencyFund,
    AccountRole? mortgageRole = AccountRole.mortgage,
    int inSavings = 5000000,
    int owedOnVisa = 90000,
    Map<String, String> prefs = const {},
    int days = 91,
  }) {
    final start = today.subtract(Duration(days: days - 1));
    return LedgerData(
      accounts: [
        acct(checking, 'Checking', AccountType.asset),
        acct(savings, 'Savings', AccountType.asset, savingsRole),
        acct(visa, 'Visa', AccountType.liability),
        acct(mortgage, 'Home loan', AccountType.liability, mortgageRole),
        acct(food, 'Food', AccountType.expense),
        acct(rent, 'Rent', AccountType.expense),
        acct(opening, 'Opening balances', AccountType.equity),
      ],
      txns: [
        move(start, opening, checking, 100000000),
        move(start, opening, savings, inSavings),
        if (owedOnVisa > 0) move(start, visa, opening, owedOnVisa),
        move(start, mortgage, opening, 20000000),
        for (var d = 0; d < days; d++)
          move(start.add(Duration(days: d)), checking, food, 300000),
        // Scheduled rows aren't spending yet.
        TxnData(
          id: nextId++,
          date: today.add(const Duration(days: 3)),
          scheduled: true,
          entries: [
            EntryData(id: nextId++, accountId: checking, amount: -9999900),
            EntryData(id: nextId++, accountId: rent, amount: 9999900),
          ],
        ),
      ],
      prefs: prefs,
    );
  }

  test('a month of spending is the last 3 months averaged, rounded up', () {
    final m = MonthOfSpending.of(ledger(), today);
    expect(m.days, 91);
    expect(m.spent, 91 * 300000);
    // 3,000.00 a day × 30.4375 days = 91,312.50, rounded up to 91,313.
    expect(m.amount, 9131300);
    expect(m.typed, isFalse);
  });

  test('a typed month wins over the average', () {
    final m = MonthOfSpending.of(
      ledger(prefs: {ReadyKeys.month: '5000000'}),
      today,
    );
    expect(m.amount, 5000000);
    expect(m.typed, isTrue);
  });

  test('under four weeks of rows, a month is not known yet', () {
    final m = MonthOfSpending.of(ledger(days: 20), today);
    expect(m.amount, 0);
    expect(m.days, 20);
    final r = Readiness.of(ledger(days: 20), today);
    expect(r.isDone(ReadyStep.oneMonth), isFalse);
    expect(r.current, ReadyStep.oneMonth);
  });

  test('the current step is the first one not done', () {
    var r = Readiness.of(ledger(inSavings: 5000000), today);
    expect(r.fund, 5000000);
    expect(r.isDone(ReadyStep.oneMonth), isFalse);
    expect(r.current, ReadyStep.oneMonth);
    expect(r.stateOf(ReadyStep.health), ReadyState.later);

    r = Readiness.of(ledger(inSavings: 9131300), today);
    expect(r.isDone(ReadyStep.oneMonth), isTrue);
    expect(r.current, ReadyStep.health);

    r = Readiness.of(
      ledger(inSavings: 9131300, prefs: {ReadyKeys.health: 'yes'}),
      today,
    );
    expect(r.current, ReadyStep.consumerDebt);
    expect(r.consumerDebts.single.account.name, 'Visa');
    expect(r.consumerOwed, 90000);
  });

  test('no account holds the fund: step 1 is not done, whatever is saved', () {
    final r = Readiness.of(
      ledger(savingsRole: null, inSavings: 999999900),
      today,
    );
    expect(r.fundAccounts, isEmpty);
    expect(r.isDone(ReadyStep.oneMonth), isFalse);
  });

  test('a mortgage is not consumer debt; a card paid monthly is neither', () {
    var r = Readiness.of(ledger(owedOnVisa: 0), today);
    expect(r.isDone(ReadyStep.consumerDebt), isTrue);
    expect(r.longLoans.single.account.name, 'Home loan');
    expect(r.isDone(ReadyStep.longLoans), isFalse);

    r = Readiness.of(ledger(owedOnVisa: 0, mortgageRole: null), today);
    expect(r.consumerDebts.single.account.name, 'Home loan');

    r = Readiness.of(ledger(prefs: {ReadyKeys.longLoans: 'yes'}), today);
    expect(r.isDone(ReadyStep.longLoans), isTrue);
  });

  test('3 to 6 months: the target follows the choice', () {
    var r = Readiness.of(ledger(inSavings: 9131300 * 3), today);
    expect(r.monthsTarget, 3);
    expect(r.isDone(ReadyStep.moreMonths), isTrue);

    r = Readiness.of(
      ledger(inSavings: 9131300 * 3, prefs: {ReadyKeys.months: '6'}),
      today,
    );
    expect(r.targetOf(ReadyStep.moreMonths), 9131300 * 6);
    expect(r.isDone(ReadyStep.moreMonths), isFalse);
  });

  test('a step set aside is skipped for now, and can come back', () {
    final r = Readiness.of(
      ledger(prefs: {ReadyKeys.setAside: 'oneMonth,health'}),
      today,
    );
    expect(r.stateOf(ReadyStep.oneMonth), ReadyState.setAside);
    expect(r.current, ReadyStep.consumerDebt);
    expect(r.setAsideWith(ReadyStep.health, false), 'oneMonth');
    expect(r.setAsideWith(ReadyStep.oneMonth, false), 'health');
    expect(
      Readiness.of(ledger(), today).setAsideWith(ReadyStep.retirement, true),
      'retirement',
    );
  });

  test('an opening balance dated months back does not thin the month', () {
    final data = ledger(days: 30);
    final early = today.subtract(const Duration(days: 200));
    final withOld = LedgerData(
      accounts: data.accounts.values.toList(),
      txns: [move(early, opening, checking, 100), ...data.txns],
    );
    final m = MonthOfSpending.of(withOld, today);
    expect(m.days, 30);
    // 3,000.00 a day × 30.4375 = 91,312.50, rounded up.
    expect(m.amount, 9131300);
  });

  test('mortgage payments count as a month of expenses; card payments not', () {
    final data = ledger();
    final start = today.subtract(const Duration(days: 90));
    final more = LedgerData(
      accounts: data.accounts.values.toList(),
      txns: [
        ...data.txns,
        move(start.add(const Duration(days: 5)), checking, mortgage, 1000000),
        move(start.add(const Duration(days: 6)), checking, visa, 5000000),
      ],
    );
    final m = MonthOfSpending.of(more, today);
    expect(m.loanPayments, 1000000);
    expect(m.spent, 91 * 300000 + 1000000);
  });

  test('step 6 is done only when there are none, they are paid, or extra', () {
    // Nothing marked isn't the same as paid off.
    var r = Readiness.of(ledger(mortgageRole: null, owedOnVisa: 0), today);
    expect(r.longMarked, isFalse);
    expect(r.isDone(ReadyStep.longLoans), isFalse);
    r = Readiness.of(
      ledger(
        mortgageRole: null,
        owedOnVisa: 0,
        prefs: {ReadyKeys.longLoans: 'none'},
      ),
      today,
    );
    expect(r.isDone(ReadyStep.longLoans), isTrue);
    // "None" stops counting once a loan is marked and owing.
    r = Readiness.of(ledger(prefs: {ReadyKeys.longLoans: 'none'}), today);
    expect(r.isDone(ReadyStep.longLoans), isFalse);
  });

  test('pay extra on the smallest debt, unless another is picked', () {
    var r = Readiness.of(ledger(mortgageRole: null), today);
    expect(r.consumerDebts.map((d) => d.account.name), ['Visa', 'Home loan']);
    expect(r.target!.account.name, 'Visa');
    r = Readiness.of(
      ledger(mortgageRole: null, prefs: {ReadyKeys.target: '$mortgage'}),
      today,
    );
    expect(r.target!.account.name, 'Home loan');
    // A pick that's paid off falls back to the smallest.
    r = Readiness.of(ledger(prefs: {ReadyKeys.target: '$mortgage'}), today);
    expect(r.target!.account.name, 'Visa');
  });

  test('a card marked paid monthly that carries a balance is flagged', () {
    LedgerData withCard(List<TxnData> card) {
      final data = ledger(owedOnVisa: 0);
      return LedgerData(
        accounts: [
          for (final a in data.accounts.values)
            a.id == visa
                ? acct(
                    visa,
                    'Visa',
                    AccountType.liability,
                    AccountRole.paidMonthly,
                  )
                : a,
        ],
        txns: [...data.txns, ...card],
      );
    }

    final d = today.subtract(const Duration(days: 60));
    // Owed since 60 days ago, never paid down.
    var r = Readiness.of(withCard([move(d, visa, food, 50000)]), today);
    expect(r.carriedSince[visa], d);
    expect(r.isDone(ReadyStep.consumerDebt), isTrue);
    // Paid to zero 10 days ago, spent again since: paid in full.
    r = Readiness.of(
      withCard([
        move(d, visa, food, 50000),
        move(today.subtract(const Duration(days: 10)), checking, visa, 50000),
        move(today.subtract(const Duration(days: 3)), visa, food, 20000),
      ]),
      today,
    );
    expect(r.carriedSince, isEmpty);
  });

  test('an archived account is out of the fund', () {
    final data = ledger(inSavings: 9131300);
    final archived = LedgerData(
      accounts: [
        for (final a in data.accounts.values)
          a.id == savings
              ? AccountInfo(
                  id: savings,
                  name: 'Savings',
                  type: AccountType.asset,
                  role: AccountRole.emergencyFund,
                  archived: true,
                )
              : a,
      ],
      txns: data.txns,
    );
    final r = Readiness.of(archived, today);
    expect(r.fundAccounts, isEmpty);
    expect(r.isDone(ReadyStep.oneMonth), isFalse);
  });

  group('database', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('roles and preferences are saved and cleared', () async {
      final id = await db.createAccount(
        name: 'Rainy day',
        type: AccountType.asset,
      );
      await db.setAccountRole(id, AccountRole.emergencyFund);
      await db.setPreference(ReadyKeys.health, 'yes');
      await db.setPreference(ReadyKeys.health, 'yes');
      var data = await db.loadLedger();
      expect(data.accounts[id]!.role, AccountRole.emergencyFund);
      expect(data.prefs, {ReadyKeys.health: 'yes'});

      await db.setAccountRole(id, null);
      await db.setPreference(ReadyKeys.health, null);
      data = await db.loadLedger();
      expect(data.accounts[id]!.role, isNull);
      expect(data.prefs, isEmpty);
    });
  });
}
