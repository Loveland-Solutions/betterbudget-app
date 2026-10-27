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

  test('where it sits: the account its category is paid from', () {
    // Paid from none said: nothing to say.
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
        paidFrom: {net: savings},
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

  test('a rate is kept as typed, a month\'s or a year\'s', () {
    expect(parseDebtRate('2 month'), (percent: 2.0, perYear: false));
    expect(parseDebtRate('24.5 year'), (percent: 24.5, perYear: true));
    for (final bad in [null, '', '2', 'x month', '2 week', '-1 month']) {
      expect(parseDebtRate(bad), isNull, reason: '$bad');
    }
    expect(parseRatePercent('1,4%'), 1.4);
    for (final bad in ['1e5', '2.', '.5', '2%%', '2 3']) {
      expect(parseRatePercent(bad), isNull, reason: bad);
    }
    expect(parseRatePercent(' 2 % '), 2);
    const DebtRate monthly = (percent: 1.4, perYear: false);
    expect(monthly.value, '1.4 month');
    expect(parseDebtRate(monthly.value), monthly);
    expect(ratePercent(2), '2');
    expect(ratePercent(24.99), '24.99');
    // A year's rate is spread over twelve months.
    const DebtRate yearly = (percent: 24, perYear: true);
    expect(yearly.interestOn(240000000), 4800000);
    const DebtRate twoAMonth = (percent: 2, perYear: false);
    expect(twoAMonth.interestOn(240000000), 4800000);
    // "About" is said in two figures.
    expect(roundAbout(47836), 48000);
    expect(roundAbout(41), 41);
    expect(roundAbout(155), 160);
    // A rate that looks typed under the wrong period is warned about.
    expect(rateLooksYearly((percent: 21.6, perYear: false)), isTrue);
    expect(rateLooksYearly((percent: 2, perYear: false)), isFalse);
    expect(
      rateLooksMonthly((percent: 1.8, perYear: true), Currency.mnt),
      isTrue,
    );
    expect(
      rateLooksMonthly((percent: 1.8, perYear: true), Currency.usd),
      isFalse,
    );
    expect(
      rateLooksMonthly((percent: 24, perYear: true), Currency.mnt),
      isFalse,
    );
    // Where a new one starts: tugrik by the month, others by the year.
    expect(ratePerYearFor(Currency.mnt), isFalse);
    expect(ratePerYearFor(Currency.usd), isTrue);
  });

  test('step 2 goes smallest first, or highest rate first when picked', () {
    // Visa owes 900.00, the home loan (unmarked) 200,000.00: smallest first.
    var r = Readiness.of(ledger(mortgageRole: null), today);
    expect(r.method, PayoffMethod.smallest);
    expect(r.debtsInOrder.map((d) => d.account.name), ['Visa', 'Home loan']);
    // Rates don't move smallest first (owner, 2026-10-27: the snowball
    // leaves them out), but they show what each costs.
    final rates = {
      ReadyKeys.rate(mortgage): '2 month',
      ReadyKeys.rate(visa): '12 year',
    };
    r = Readiness.of(ledger(mortgageRole: null, prefs: rates), today);
    expect(r.debtsInOrder.map((d) => d.account.name), ['Visa', 'Home loan']);
    expect(r.interestOf(r.debtsInOrder.last), 400000);
    expect(r.target!.account.name, 'Visa');
    // Highest rate first: 2% a month before 12% a year.
    r = Readiness.of(
      ledger(mortgageRole: null, prefs: {...rates, ReadyKeys.method: 'rate'}),
      today,
    );
    expect(r.method, PayoffMethod.highestRate);
    expect(r.debtsInOrder.map((d) => d.account.name), ['Home loan', 'Visa']);
    expect(r.target!.account.name, 'Home loan');
    expect(r.picked, isNull);
    // One picked by hand heads the list; the two ways still compare
    // without it.
    r = Readiness.of(
      ledger(
        mortgageRole: null,
        prefs: {...rates, ReadyKeys.method: 'rate', ReadyKeys.target: '$visa'},
      ),
      today,
    );
    expect(r.picked!.account.name, 'Visa');
    expect(r.debtsInOrder.map((d) => d.account.name), ['Visa', 'Home loan']);
    expect(r.orderOf(PayoffMethod.highestRate), [mortgage, visa]);
    // A debt without a rate goes last when it's highest rate first.
    r = Readiness.of(
      ledger(
        mortgageRole: null,
        prefs: {ReadyKeys.rate(visa): '1 month', ReadyKeys.method: 'rate'},
      ),
      today,
    );
    expect(r.debtsInOrder.map((d) => d.account.name), ['Visa', 'Home loan']);
    expect(r.methodsDiffer, isFalse);
  });

  test('a debt\'s monthly payment: typed, else its category\'s plan', () {
    const payment = 9;
    final data = ledger(mortgageRole: null);
    LedgerData withPlan(Map<String, String> prefs) => LedgerData(
      accounts: [
        ...data.accounts.values,
        acct(payment, 'Loan payment', AccountType.expense),
      ],
      txns: data.txns,
      prefs: {'budget.loan.$mortgage': '$payment', ...prefs},
      budgetAmounts: data.budgetAmounts,
      plans: [
        CategoryPlan(
          categoryId: payment,
          kind: PlanKind.byDate,
          amount: 25000000,
          start: DateTime(2026, 9, 1),
          due: DateTime(2026, 9, 20),
          everyMonths: 1,
        ),
      ],
    );
    var r = Readiness.of(withPlan({}), today);
    expect(r.payments[mortgage]!.amount, 25000000);
    expect(r.payments[mortgage]!.from!.name, 'Loan payment');
    expect(r.payments[visa], isNull);
    expect(r.missingPayments.map((d) => d.account.name), ['Visa']);
    expect(r.payoff(PayoffMethod.smallest), isNull);
    // Typed wins over the plan.
    r = Readiness.of(
      withPlan({
        ReadyKeys.pay(mortgage): '30000000',
        ReadyKeys.pay(visa): '10000',
      }),
      today,
    );
    expect(r.payments[mortgage], (amount: 30000000, from: null));
    expect(r.missingPayments, isEmpty);
    final plan = r.payoff(PayoffMethod.smallest)!;
    // 200,900.00 at 300,100.00 a month: paid off next month.
    expect(plan.months, 1);
    expect(plan.interest, 0);
  });

  test('what was paid in lately is offered, never filled in', () {
    final data = ledger(owedOnVisa: 900000);
    final r = Readiness.of(
      LedgerData(
        accounts: data.accounts.values.toList(),
        txns: [
          ...data.txns,
          // June, July and August: 300.00, 300.00, 150.00 paid in. The
          // Visa's first row is in June, so June isn't a whole month of it.
          move(DateTime(2026, 6, 10), checking, visa, 30000),
          move(DateTime(2026, 7, 10), checking, visa, 30000),
          move(DateTime(2026, 8, 10), checking, visa, 15000),
          // This month's isn't whole yet.
          move(DateTime(2026, 9, 10), checking, visa, 99900),
        ],
        prefs: data.prefs,
        budgetAmounts: data.budgetAmounts,
      ),
      today,
    );
    expect(r.paidLately[visa], 22500);
    expect(r.payments[visa], isNull);
  });

  test('a debt picked by hand heads the list; the ways compare without it', () {
    final rates = {
      ReadyKeys.rate(mortgage): '2 month',
      ReadyKeys.rate(visa): '1 month',
      ReadyKeys.pay(mortgage): '30000000',
      ReadyKeys.pay(visa): '10000',
    };
    // Smallest first, the home loan picked: it heads the list, and the
    // two ways still differ, so both cards show.
    final r = Readiness.of(
      ledger(
        mortgageRole: null,
        prefs: {...rates, ReadyKeys.target: '$mortgage'},
      ),
      today,
    );
    expect(r.picked!.account.name, 'Home loan');
    expect(r.debtsInOrder.map((d) => d.account.name), ['Home loan', 'Visa']);
    expect(r.orderOf(PayoffMethod.smallest), [visa, mortgage]);
    expect(r.orderOf(PayoffMethod.highestRate), [mortgage, visa]);
    expect(r.methodsDiffer, isTrue);
  });

  test('a plan by pay period is not a monthly payment; every 3 months is', () {
    const payment = 9;
    final data = ledger(mortgageRole: null);
    Readiness withPlan(CategoryPlan plan) => Readiness.of(
      LedgerData(
        accounts: [
          ...data.accounts.values,
          acct(payment, 'Loan payment', AccountType.expense),
        ],
        txns: data.txns,
        prefs: {'budget.loan.$mortgage': '$payment'},
        budgetAmounts: data.budgetAmounts,
        plans: [plan],
      ),
      today,
    );
    expect(
      withPlan(
        CategoryPlan(
          categoryId: payment,
          kind: PlanKind.each,
          amount: 12500000,
          start: DateTime(2026, 9, 1),
        ),
      ).payments[mortgage],
      isNull,
    );
    expect(
      withPlan(
        CategoryPlan(
          categoryId: payment,
          kind: PlanKind.byDate,
          amount: 30000000,
          start: DateTime(2026, 9, 1),
          due: DateTime(2026, 9, 20),
          everyMonths: 3,
        ),
      ).payments[mortgage]!.amount,
      10000000,
    );
  });

  test('progress: the most each owed, and the debts paid off', () {
    const car = 10, card = 11;
    final data = ledger(owedOnVisa: 0, mortgageRole: AccountRole.mortgage);
    final d = DateTime(2026, 5, 1);
    LedgerData withRows(List<TxnData> more) => LedgerData(
      accounts: [
        ...data.accounts.values,
        acct(car, 'Car loan', AccountType.liability),
        acct(card, 'Golomt card', AccountType.liability),
      ],
      txns: [...data.txns, ...more],
      prefs: data.prefs,
      budgetAmounts: data.budgetAmounts,
    );
    final r = Readiness.of(
      withRows([
        move(d, car, opening, 6000000),
        move(d, card, food, 90000),
        move(d.add(const Duration(days: 20)), card, food, 30000),
        // The card is paid off; the car loan paid down to 4,000.00.
        move(DateTime(2026, 8, 1), checking, card, 120000),
        move(DateTime(2026, 8, 1), checking, car, 2000000),
      ]),
      today,
    );
    expect(r.mostOwed[car], 6000000);
    expect(r.mostOwed[card], isNull);
    expect(r.paidOff.map((a) => a.name), ['Golomt card']);
    final loan = r.consumerDebts.single;
    expect(loan.account.name, 'Car loan');
    expect(r.paidOffOf(loan), 2000000);
    // The house loan counts from the most it owed too.
    expect(r.mostOwed[mortgage], 20000000);
    // A card owed and paid off before the car loan began isn't counted:
    // there was a day nothing was owed.
    final before = Readiness.of(
      withRows([
        move(DateTime(2026, 3, 1), card, food, 90000),
        move(DateTime(2026, 4, 1), checking, card, 90000),
        move(d, car, opening, 6000000),
      ]),
      today,
    );
    expect(before.paidOff, isEmpty);
    // Spent on again lately: in use, not paid off; and said under the
    // payoff with what went on it.
    final used = Readiness.of(
      withRows([
        move(d, car, opening, 6000000),
        move(d, card, food, 90000),
        move(DateTime(2026, 8, 1), checking, card, 90000),
        move(DateTime(2026, 9, 1), card, food, 5000),
        move(DateTime(2026, 9, 2), checking, card, 5000),
      ]),
      today,
    );
    expect(used.paidOff, isEmpty);
    expect(used.chargedLately[card], 5000);
    // Archived once paid off, it still counts.
    final archived = Readiness.of(
      LedgerData(
        accounts: [
          ...data.accounts.values,
          acct(car, 'Car loan', AccountType.liability),
          AccountInfo(
            id: card,
            name: 'Golomt card',
            type: AccountType.liability,
            archived: true,
          ),
        ],
        txns: [
          ...data.txns,
          move(d, car, opening, 6000000),
          move(d, card, food, 90000),
          move(DateTime(2026, 8, 1), checking, card, 90000),
        ],
        prefs: data.prefs,
        budgetAmounts: data.budgetAmounts,
      ),
      today,
    );
    expect(archived.paidOff.map((a) => a.name), ['Golomt card']);
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

  test('a card paid in full by statement is not flagged as carrying', () {
    LedgerData withCard(List<TxnData> card, {AccountRole? role}) {
      final data = ledger(owedOnVisa: 0);
      return LedgerData(
        accounts: [
          for (final a in data.accounts.values)
            a.id == visa ? acct(visa, 'Visa', AccountType.liability, role) : a,
        ],
        txns: [...data.txns, ...card],
      );
    }

    DateTime ago(int days) =>
        DateTime(today.year, today.month, today.day - days);
    // Used most days; each statement paid in full, so it never reads ₮0.
    final daily = [
      for (var d = 70; d > 0; d--) move(ago(d), visa, food, 10000),
      move(ago(40), checking, visa, 300000),
      move(ago(10), checking, visa, 300000),
    ];
    var r = Readiness.of(withCard(daily, role: AccountRole.paidMonthly), today);
    expect(r.carriedSince, isEmpty);
    // Unmarked, it's debt to pay off, said to look paid in full, and left
    // out of "pay only the minimums".
    r = Readiness.of(withCard(daily), today);
    expect(r.consumerDebts.map((d) => d.account.id), contains(visa));
    expect(r.looksPaidInFull, {visa});
    // Paid less than it owed five weeks ago: carrying, and not paid in full.
    final short = [
      for (var d = 70; d > 0; d--) move(ago(d), visa, food, 10000),
      move(ago(10), checking, visa, 100000),
    ];
    r = Readiness.of(withCard(short, role: AccountRole.paidMonthly), today);
    expect(r.carriedSince[visa], ago(70));
    expect(Readiness.of(withCard(short), today).looksPaidInFull, isEmpty);
  });

  LedgerData budgetedWith({
    Map<String, String> prefs = const {},
    List<BudgetAmount> amounts = const [],
    List<CategoryPlan> plans = const [],
    List<AccountInfo> more = const [],
  }) {
    final data = ledger();
    return LedgerData(
      accounts: [...data.accounts.values, ...more],
      txns: data.txns,
      prefs: prefs,
      budgetAmounts: amounts,
      plans: plans,
    );
  }

  test('a category with no plan counts last month\'s assigned too', () {
    // On 10.01 nothing is assigned to Food yet; September had 900,000.00.
    final data = budgetedWith(
      amounts: [
        BudgetAmount(
          categoryId: food,
          date: DateTime(2026, 9),
          amount: 90000000,
        ),
        BudgetAmount(categoryId: rent, date: DateTime(2026, 10), amount: 1000),
      ],
    );
    expect(
      MonthOfSpending.budgeted(data, DateTime(2026, 10, 1), Currency.mnt),
      90000000 + 1000,
    );
  });

  test('a category left out is not in a month of expenses', () {
    final amounts = [
      BudgetAmount(categoryId: food, date: DateTime(2026, 9), amount: 90000000),
      BudgetAmount(categoryId: rent, date: DateTime(2026, 9), amount: 80000000),
    ];
    var m = MonthOfSpending.of(budgetedWith(amounts: amounts), today);
    expect(m.amount, 170000000);
    m = MonthOfSpending.of(
      budgetedWith(amounts: amounts, prefs: {ReadyKeys.leftOut(rent): 'yes'}),
      today,
    );
    expect(m.amount, 90000000);
    // The average leaves its rows out too.
    final average = MonthOfSpending.of(
      ledger(prefs: {ReadyKeys.leftOut(food): 'yes'}),
      today,
    );
    expect(average.spent, 0);
  });

  test('a typed month the budget has outgrown is said, and kept', () {
    final amounts = [
      BudgetAmount(categoryId: food, date: DateTime(2026, 9), amount: 2400000),
    ];
    var m = MonthOfSpending.of(
      budgetedWith(amounts: amounts, prefs: {ReadyKeys.month: 'MNT:2000000'}),
      today,
    );
    expect(m.amount, 2000000);
    expect(m.outgrown, isTrue);
    m = MonthOfSpending.of(
      budgetedWith(amounts: amounts, prefs: {ReadyKeys.month: 'MNT:2200000'}),
      today,
    );
    expect(m.outgrown, isFalse);
  });

  test('Savings counts in the Safety net\'s currency', () {
    final data = ledger();
    final dollars = LedgerData(
      accounts: [
        ...data.accounts.values,
        for (final id in [50, 51, 52, 53, 54])
          AccountInfo(
            id: id,
            name: 'Dollars $id',
            type: AccountType.asset,
            currency: Currency.usd,
          ),
      ],
      txns: data.txns,
      budgetAmounts: data.budgetAmounts,
    );
    expect(mainCurrency(dollars), Currency.usd);
    expect(savingsCurrency(dollars), Currency.mnt);
    expect(Readiness.of(dollars, today).hasFund, isTrue);
  });

  test('the Assign offer leaves this month\'s bills their money', () {
    // A month typed; Rent is a bill due 09.30 with 400,000.00 still to assign.
    final plans = [
      CategoryPlan(
        categoryId: rent,
        kind: PlanKind.byDate,
        amount: 40000000,
        due: DateTime(2026, 9, 30),
        start: DateTime(2026, 9),
      ),
    ];
    final prefs = {ReadyKeys.month: 'MNT:9999999900'};
    final r = Readiness.of(budgetedWith(plans: plans, prefs: prefs), today);
    expect(r.billsToAssign, 40000000);
    final free = r.notAssigned - r.billsToAssign;
    expect(r.offerFor(ReadyStep.oneMonth), free > 0 ? free : 0);
    // No month known: nothing offered.
    final none = Readiness.of(ledger(days: 10), today);
    expect(none.offerFor(ReadyStep.oneMonth), 0);
  });

  test('more assigned than there is is said on step 1', () {
    final r = Readiness.of(
      budgetedWith(
        amounts: [
          BudgetAmount(
            categoryId: net,
            date: DateTime(2026, 9),
            amount: 900000000000,
          ),
        ],
      ),
      today,
    );
    expect(r.notAssigned, 0);
    expect(r.overAssigned, greaterThan(0));
  });

  test('very large figures don\'t overflow', () {
    expect(parseRatePercent('1' * 22), isNull);
    expect(parseRatePercent('1000'), 1000);
    final data = ledger();
    final huge = LedgerData(
      accounts: data.accounts.values.toList(),
      txns: [...data.txns, move(today, checking, food, 99999999999999900)],
    );
    expect(MonthOfSpending.of(huge, today).amount, greaterThan(0));
  });

  test('set aside works from what is stored', () {
    expect(
      Readiness.setAsideStored('future', ReadyStep.oneMonth, true),
      'oneMonth,future',
    );
    expect(Readiness.setAsideStored('future', ReadyStep.future, false), isNull);
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
