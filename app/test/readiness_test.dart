import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/money.dart';
import 'package:betterbudget/domain/readiness.dart';
import 'package:betterbudget/domain/sync.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Savings steps (rule 25), worked out from a small ledger.
void main() {
  final today = DateTime(2026, 9, 16);
  const checking = 1, savings = 2, visa = 3, mortgage = 4, food = 5;
  const opening = 6, rent = 7, net = 8;
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

  /// 91 days of 3,000.00 a day on food from checking, opening balances, and
  /// a Safety net category holding [inSavings] ([hasNet]: the app's own,
  /// by its mark).
  LedgerData ledger({
    bool hasNet = true,
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
        acct(savings, 'Savings', AccountType.asset),
        acct(
          net,
          'Safety net',
          AccountType.expense,
          hasNet ? AccountRole.emergencyFund : null,
        ),
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
      budgetAmounts: [
        BudgetAmount(
          categoryId: net,
          date: DateTime(2026, 9),
          amount: inSavings,
        ),
      ],
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

  test('a month comes from the budget before the average, typed first', () {
    final data = ledger();
    LedgerData budgeted(Map<String, String> prefs) => LedgerData(
      accounts: data.accounts.values.toList(),
      txns: data.txns,
      prefs: prefs,
      // Food has 2,000,000.00 assigned this month and a plan for
      // 2,500,000.00 a month; Rent has 800,000.00 and no plan.
      budgetAmounts: [
        BudgetAmount(
          categoryId: food,
          date: DateTime(2026, 9),
          amount: 200000000,
        ),
        BudgetAmount(
          categoryId: rent,
          date: DateTime(2026, 9),
          amount: 80000000,
        ),
        // Another month's isn't this month's.
        BudgetAmount(categoryId: rent, date: DateTime(2026, 8), amount: 999900),
      ],
      plans: [
        CategoryPlan(
          categoryId: food,
          kind: PlanKind.each,
          amount: 250000000,
          start: DateTime(2026, 9),
        ),
      ],
    );
    var m = MonthOfSpending.of(budgeted(const {}), today);
    expect(m.fromBudget, isTrue);
    expect(m.typed, isFalse);
    expect(m.amount, 250000000 + 80000000);
    expect(
      Readiness.of(budgeted(const {}), today).targetOf(ReadyStep.oneMonth),
      330000000,
    );

    m = MonthOfSpending.of(budgeted({ReadyKeys.month: '5000000'}), today);
    expect(m.typed, isTrue);
    expect(m.fromBudget, isFalse);
    expect(m.amount, 5000000);

    // Nothing budgeted: the average, as before.
    expect(MonthOfSpending.of(data, today).fromBudget, isFalse);
  });

  test('the safety net is what is left in its category, and nothing else', () {
    final data = ledger(
      inSavings: 6000000,
      prefs: {ReadyKeys.month: '5000000'},
    );
    var r = Readiness.of(data, today);
    expect(r.fundCategories.single.name, 'Safety net');
    // Not the 1,000,000.00 in Checking, nor what Savings holds.
    expect(r.fund, 6000000);
    expect(r.isDone(ReadyStep.oneMonth), isTrue);

    // Using it takes it down.
    r = Readiness.of(
      LedgerData(
        accounts: data.accounts.values.toList(),
        txns: [...data.txns, move(today, checking, net, 2000000)],
        prefs: data.prefs,
        budgetAmounts: data.budgetAmounts,
      ),
      today,
    );
    expect(r.fund, 4000000);
    expect(r.isDone(ReadyStep.oneMonth), isFalse);

    // What is assigned to it isn't a month's expense; unmarked, it is.
    final main = mainCurrency(data);
    expect(MonthOfSpending.budgeted(data, today, main), 0);
    expect(
      MonthOfSpending.budgeted(
        ledger(hasNet: false, inSavings: 6000000),
        today,
        main,
      ),
      6000000,
    );
  });

  test('an account marked as the fund before no longer counts', () {
    final data = ledger(hasNet: false);
    final r = Readiness.of(
      LedgerData(
        accounts: [
          for (final a in data.accounts.values)
            a.id == checking
                ? acct(
                    checking,
                    'Checking',
                    AccountType.asset,
                    AccountRole.emergencyFund,
                  )
                : a,
        ],
        txns: data.txns,
      ),
      today,
    );
    expect(r.hasFund, isFalse);
    expect(r.fund, 0);
  });

  test('where it sits: the accounts its category is paid from', () {
    // Paid from every account: nothing to say.
    var r = Readiness.of(ledger(inSavings: 6000000), today);
    expect(r.keptIn, isEmpty);
    // Paid from Savings only, which holds 60,000.00 of it... all of it.
    LedgerData only(int inAccount) {
      final data = ledger(inSavings: 6000000);
      return LedgerData(
        accounts: data.accounts.values.toList(),
        txns: [
          for (final t in data.txns)
            if (!t.entries.any((e) => e.accountId == savings)) t,
          if (inAccount > 0) move(today, opening, savings, inAccount),
        ],
        prefs: data.prefs,
        budgetAmounts: data.budgetAmounts,
        accountsOff: {
          net: {checking},
        },
      );
    }

    r = Readiness.of(only(6000000), today);
    expect(r.keptIn.single.name, 'Savings');
    expect(r.keptThere, 6000000);
    // Some of it still to move: the transfer changes where, not how much.
    r = Readiness.of(only(2500000), today);
    expect(r.fund, 6000000);
    expect(r.keptThere, 2500000);
    // More in the account than the category holds: no more than the net.
    r = Readiness.of(only(9000000), today);
    expect(r.keptThere, 6000000);
  });

  test('money not assigned is offered, with what the net has this month', () {
    final r = Readiness.of(ledger(inSavings: 6000000), today);
    // Checking and Savings hold what was opened less the food; the
    // categories hold the net less the food overspent, so the rest is free.
    expect(r.notAssigned, greaterThan(0));
    expect(r.fundAssigned, 6000000);
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
    expect(r.stateOf(ReadyStep.consumerDebt), ReadyState.later);

    // With the safety net full, the debt is next: nothing stands between.
    r = Readiness.of(ledger(inSavings: 9131300), today);
    expect(r.isDone(ReadyStep.oneMonth), isTrue);
    expect(r.current, ReadyStep.consumerDebt);
    expect(r.consumerDebts.single.account.name, 'Visa');
    expect(r.consumerOwed, 90000);
  });

  test('no category for it: step 1 is not done, whatever is saved', () {
    final r = Readiness.of(ledger(hasNet: false, inSavings: 999999900), today);
    expect(r.fundCategories, isEmpty);
    expect(r.isDone(ReadyStep.oneMonth), isFalse);
  });

  test('a mortgage is not consumer debt; a card paid monthly is neither', () {
    var r = Readiness.of(ledger(owedOnVisa: 0), today);
    expect(r.isDone(ReadyStep.consumerDebt), isTrue);
    expect(r.longLoans.single.account.name, 'Home loan');
    expect(r.mortgageDone, isFalse);

    r = Readiness.of(ledger(owedOnVisa: 0, mortgageRole: null), today);
    expect(r.consumerDebts.single.account.name, 'Home loan');

    r = Readiness.of(ledger(prefs: {ReadyKeys.longLoans: 'yes'}), today);
    expect(r.mortgageDone, isTrue);
  });

  test('a student loan is debt to pay off, not left for the last step', () {
    final r = Readiness.of(
      ledger(owedOnVisa: 0, mortgageRole: AccountRole.studentLoan),
      today,
    );
    expect(r.consumerDebts.single.account.name, 'Home loan');
    expect(r.longLoans, isEmpty);
    expect(r.longMarked, isFalse);
    expect(r.isDone(ReadyStep.consumerDebt), isFalse);
  });

  test('the last step is done with retirement and the mortgage both', () {
    const full = 9131300 * 3;
    var r = Readiness.of(ledger(inSavings: full, owedOnVisa: 0), today);
    expect(r.current, ReadyStep.future);
    r = Readiness.of(
      ledger(
        inSavings: full,
        owedOnVisa: 0,
        prefs: {ReadyKeys.retirement: 'yes'},
      ),
      today,
    );
    expect(r.retirement, isTrue);
    expect(r.isDone(ReadyStep.future), isFalse); // the home loan is owing
    r = Readiness.of(
      ledger(
        inSavings: full,
        owedOnVisa: 0,
        prefs: {ReadyKeys.retirement: 'yes', ReadyKeys.longLoans: 'yes'},
      ),
      today,
    );
    expect(r.isDone(ReadyStep.future), isTrue);
    expect(r.current, isNull);
    // The mortgage alone isn't enough either.
    r = Readiness.of(
      ledger(
        inSavings: full,
        owedOnVisa: 0,
        prefs: {ReadyKeys.longLoans: 'yes'},
      ),
      today,
    );
    expect(r.isDone(ReadyStep.future), isFalse);
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
      ledger(prefs: {ReadyKeys.setAside: 'oneMonth,consumerDebt'}),
      today,
    );
    expect(r.stateOf(ReadyStep.oneMonth), ReadyState.setAside);
    expect(r.current, ReadyStep.moreMonths);
    expect(r.setAsideWith(ReadyStep.consumerDebt, false), 'oneMonth');
    expect(r.setAsideWith(ReadyStep.oneMonth, false), 'consumerDebt');
    expect(
      Readiness.of(ledger(), today).setAsideWith(ReadyStep.future, true),
      'future',
    );
  });

  test('a ledger from the six steps: its kept steps stay set aside', () {
    // Health, retirement and the loans were steps then; their names are
    // passed over, and the answers to the last two still count.
    final r = Readiness.of(
      ledger(
        prefs: {
          ReadyKeys.setAside: 'oneMonth,health,retirement,longLoans',
          'ready.health': 'yes',
          ReadyKeys.retirement: 'yes',
        },
      ),
      today,
    );
    expect(r.setAside, {ReadyStep.oneMonth});
    expect(r.current, ReadyStep.consumerDebt);
    expect(r.stateOf(ReadyStep.future), ReadyState.later);
    expect(r.retirement, isTrue);
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

  test(
    'the mortgage is done only when there is none, it is paid, or extra',
    () {
      // Nothing marked isn't the same as paid off.
      var r = Readiness.of(ledger(mortgageRole: null, owedOnVisa: 0), today);
      expect(r.longMarked, isFalse);
      expect(r.mortgageDone, isFalse);
      r = Readiness.of(
        ledger(
          mortgageRole: null,
          owedOnVisa: 0,
          prefs: {ReadyKeys.longLoans: 'none'},
        ),
        today,
      );
      expect(r.mortgageDone, isTrue);
      // "None" stops counting once a loan is marked and owing.
      r = Readiness.of(ledger(prefs: {ReadyKeys.longLoans: 'none'}), today);
      expect(r.mortgageDone, isFalse);
    },
  );

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

  test('an archived category is not the safety net', () {
    final data = ledger(inSavings: 9131300);
    final archived = LedgerData(
      accounts: [
        for (final a in data.accounts.values)
          a.id == net
              ? AccountInfo(
                  id: net,
                  name: 'Safety net',
                  type: AccountType.expense,
                  role: AccountRole.emergencyFund,
                  archived: true,
                )
              : a,
      ],
      txns: data.txns,
      prefs: data.prefs,
      budgetAmounts: data.budgetAmounts,
    );
    final r = Readiness.of(archived, today);
    expect(r.fundCategories, isEmpty);
    expect(r.isDone(ReadyStep.oneMonth), isFalse);
  });

  group('database', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test(
      'Safety net is made once, and a category made for it is taken',
      () async {
        final first = await db.safetyNetCategory(
          name: 'Safety net',
          currency: Currency.mnt,
        );
        expect(
          await db.safetyNetCategory(
            name: 'Safety net',
            currency: Currency.mnt,
          ),
          first,
        );
        var data = await db.loadLedger();
        expect(data.accounts.values.where(isSafetyNet).single.id, first);
        expect(fundCategoryIds(data, Currency.mnt), {first});
        await db.close();

        // A ledger where the user had made one: that one, not a second.
        db = AppDatabase(NativeDatabase.memory());
        final theirs = await db.createCategory('Rainy day');
        await db.setArchived(theirs, true);
        expect(
          await db.safetyNetCategory(
            name: 'Safety net',
            currency: Currency.mnt,
            adopt: theirs,
          ),
          theirs,
        );
        data = await db.loadLedger();
        final net = data.accounts.values.where(isSafetyNet).single;
        expect(net.name, 'Rainy day');
        expect(net.archived, isFalse);
      },
    );

    test('roles and preferences are saved and cleared', () async {
      final id = await db.createAccount(
        name: 'Rainy day',
        type: AccountType.asset,
      );
      await db.setAccountRole(id, AccountRole.emergencyFund);
      await db.setPreference(ReadyKeys.retirement, 'yes');
      await db.setPreference(ReadyKeys.retirement, 'yes');
      // A new ledger carries its own id among the settings (sync.ledger).
      Map<String, String> own(LedgerData d) => {
        for (final e in d.prefs.entries)
          if (!e.key.startsWith(SyncKeys.prefix)) e.key: e.value,
      };
      var data = await db.loadLedger();
      expect(data.accounts[id]!.role, AccountRole.emergencyFund);
      expect(own(data), {ReadyKeys.retirement: 'yes'});

      await db.setAccountRole(id, null);
      await db.setPreference(ReadyKeys.retirement, null);
      data = await db.loadLedger();
      expect(data.accounts[id]!.role, isNull);
      expect(own(data), isEmpty);
    });
  });
}
