import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/domain/budget.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/money.dart';
import 'package:betterbudget/domain/pay.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The envelopes (rule 26), worked out from a small ledger.
void main() {
  final today = DateTime(2026, 10, 20);
  final oct = (start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 31));
  final nov = (start: DateTime(2026, 11, 1), end: DateTime(2026, 11, 30));
  const checking = 1, visa = 2, mortgage = 3, dollars = 4;
  const food = 10, dining = 11, xmas = 12, coffee = 13, salary = 20;
  const opening = 30, waiting = 31, housing = 32;
  var nextId = 100;

  AccountInfo acct(
    int id,
    String name,
    AccountType t, {
    AccountRole? role,
    Currency currency = Currency.mnt,
    bool deleted = false,
  }) => AccountInfo(
    id: id,
    name: name,
    type: t,
    role: role,
    currency: currency,
    deleted: deleted,
  );

  TxnData move(
    DateTime date,
    int from,
    int to,
    int amount, {
    bool scheduled = false,
    Currency currency = Currency.mnt,
    int? plan,
  }) => TxnData(
    id: nextId++,
    date: date,
    scheduled: scheduled,
    planCategoryId: plan,
    entries: [
      EntryData(
        id: nextId++,
        accountId: from,
        amount: -amount,
        currency: currency,
      ),
      EntryData(
        id: nextId++,
        accountId: to,
        amount: amount,
        currency: currency,
      ),
    ],
  );

  BudgetAmount put(int category, DateTime date, int amount) =>
      BudgetAmount(categoryId: category, date: date, amount: amount);

  /// ₮5,400,000 in checking, ₮860,000 owed on the card, a mortgage and a
  /// dollar account that don't count.
  LedgerData ledger({
    List<TxnData> rows = const [],
    List<BudgetAmount> amounts = const [],
    bool diningDeleted = false,
    Map<String, String> prefs = const {},
    List<CategoryPlan> plans = const [],
    List<PaySchedule> pay = const [],
    List<AccountInfo> more = const [],
    Map<int, Set<int>> off = const {},
  }) => LedgerData(
    prefs: prefs,
    plans: plans,
    paySchedules: pay,
    accountsOff: off,
    accounts: [
      acct(checking, 'Checking', AccountType.asset),
      acct(visa, 'Visa', AccountType.liability),
      acct(mortgage, 'Home', AccountType.liability, role: AccountRole.mortgage),
      acct(dollars, 'AFCU', AccountType.asset, currency: Currency.usd),
      acct(food, 'Groceries', AccountType.expense),
      acct(dining, 'Dining out', AccountType.expense, deleted: diningDeleted),
      acct(xmas, 'Christmas', AccountType.expense),
      acct(coffee, 'Coffee', AccountType.expense),
      acct(salary, 'Salary', AccountType.income),
      acct(waiting, 'Not categorized', AccountType.expense),
      acct(housing, 'Housing', AccountType.expense),
      acct(opening, 'Opening balances', AccountType.equity),
      ...more,
    ],
    txns: [
      move(DateTime(2026, 8, 1), opening, checking, 540000000),
      move(DateTime(2026, 8, 1), visa, opening, 86000000),
      move(DateTime(2026, 8, 1), mortgage, opening, 9000000000),
      move(
        DateTime(2026, 8, 1),
        opening,
        dollars,
        250000,
        currency: Currency.usd,
      ),
      ...rows,
    ],
    budgetAmounts: amounts,
  );

  Budget of(LedgerData d, ({DateTime start, DateTime end}) p) =>
      Budget.of(d, start: p.start, end: p.end, today: today);

  test('money not given out: cash and bank less cards less categories', () {
    final b = of(
      ledger(
        amounts: [
          put(food, oct.start, 90000000),
          put(xmas, oct.start, 30000000),
        ],
      ),
      oct,
    );
    // Checking only: what's owed and the dollars aren't counted.
    expect(b.money, 540000000);
    expect(b.notAssigned, 540000000 - 120000000);
    expect(b.lines[food]!.assigned, 90000000);
    expect(b.lines[food]!.left, 90000000);
    expect(b.began, oct.start);
  });

  // ADR 0004, "What's owed is not the Budget page's job": a credit card or
  // loan balance never comes off the money there is to assign. What's owed is
  // the Savings page's business; here only the payment is budgeted.
  test('what a credit card owes is not taken off the money to assign', () {
    final b = of(ledger(), oct);
    // Checking only. The Visa's ₮860,000, the mortgage and the dollars are
    // all out of it.
    expect(b.money, 540000000);
    expect(b.notAssigned, 540000000);

    // Buying on the card is spending in its category and nothing else: the
    // money to assign doesn't move, because no money has left the bank.
    final bought = of(
      ledger(rows: [move(DateTime(2026, 10, 5), visa, food, 5000000)]),
      oct,
    );
    expect(bought.money, 540000000);
    expect(bought.lines[food]!.spent, 5000000);
  });

  test('paying a credit card is its category\'s spending', () {
    final key = '${BudgetKeys.loanPrefix}$visa';
    final paid = of(
      ledger(
        amounts: [put(housing, oct.start, 86000000)],
        rows: [move(DateTime(2026, 10, 25), checking, visa, 86000000)],
        prefs: {key: '$housing'},
      ),
      oct,
    );
    // The bank is ₮860,000 lighter, and the category it was budgeted in
    // carries the spending, the way rent does.
    expect(paid.money, 540000000 - 86000000);
    expect(paid.lines[housing]!.spent, 86000000);
    expect(paid.lines[housing]!.left, 0);
  });

  test('a card purchase comes out of its category and nothing else', () {
    final amounts = [put(food, oct.start, 90000000)];
    final before = of(ledger(amounts: amounts), oct);
    final after = of(
      ledger(
        amounts: amounts,
        rows: [move(DateTime(2026, 10, 5), visa, food, 8800000)],
      ),
      oct,
    );
    expect(after.lines[food]!.spent, 8800000);
    expect(after.lines[food]!.left, 90000000 - 8800000);

    // Nothing left the bank, so the money stands still while the category
    // it was bought in gives up ₮88,000 — which leaves that much more not
    // assigned. The money to pay the card is still in the accounts, and
    // what's owed is the Savings page's business, not this page's.
    expect(after.money, before.money);
    expect(after.notAssigned, before.notAssigned + 8800000);

    // Paying the card is what takes it out of the bank. With no category
    // budgeted for the payment it comes out of what wasn't assigned, and
    // the category it was bought in doesn't move again: the spending was
    // counted when it was bought.
    final paid = of(
      ledger(
        amounts: amounts,
        rows: [
          move(DateTime(2026, 10, 5), visa, food, 8800000),
          move(DateTime(2026, 10, 9), checking, visa, 8800000),
        ],
      ),
      oct,
    );
    expect(paid.money, after.money - 8800000);
    expect(paid.notAssigned, before.notAssigned);
    expect(paid.lines[food]!.left, after.lines[food]!.left);
  });

  test('income adds to the money not given out', () {
    final b = of(
      ledger(rows: [move(DateTime(2026, 10, 10), salary, checking, 420000000)]),
      oct,
    );
    expect(b.cameIn[salary], {Currency.mnt: 420000000});
    expect(b.notAssigned, 540000000 + 420000000);
  });

  test('overspending carries as minus into the next period', () {
    final d = ledger(
      amounts: [
        put(dining, oct.start, 15000000),
        put(dining, nov.start, 15000000),
      ],
      rows: [move(DateTime(2026, 10, 12), checking, dining, 18200000)],
    );
    final o = of(d, oct);
    expect(o.lines[dining]!.left, -3200000);
    final n = of(d, nov);
    expect(n.lines[dining]!.fromBefore, -3200000);
    expect(n.lines[dining]!.assigned, 15000000);
    expect(n.lines[dining]!.spent, 0);
    expect(n.lines[dining]!.left, 11800000);
  });

  test('what is left builds up in a category that is saved in', () {
    final d = ledger(
      amounts: [
        put(xmas, DateTime(2026, 9, 1), 10000000),
        put(xmas, oct.start, 10000000),
      ],
    );
    final o = of(d, oct);
    expect(o.lines[xmas]!.fromBefore, 10000000);
    expect(o.lines[xmas]!.left, 20000000);
  });

  test('spending before the budget began counts against no category', () {
    final d = ledger(
      amounts: [put(food, oct.start, 90000000)],
      rows: [
        move(DateTime(2026, 9, 20), checking, food, 5000000),
        move(DateTime(2026, 10, 3), checking, food, 1000000),
      ],
    );
    final o = of(d, oct);
    expect(o.lines[food]!.left, 89000000);
    expect(o.lines[food]!.fromBefore, 0);
    // September still shows what it spent; nothing was in it yet.
    final sep = of(d, (
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 9, 30),
    ));
    expect(sep.lines[food]!.spent, 5000000);
    expect(sep.lines[food]!.left, 0);
    expect(sep.lines[food]!.fromBefore, 0);
  });

  test('a category nothing was put in goes below zero when spent from', () {
    final d = ledger(
      amounts: [put(food, oct.start, 90000000)],
      rows: [move(DateTime(2026, 10, 3), checking, coffee, 450000)],
    );
    final o = of(d, oct);
    expect(o.lines[coffee]!.left, -450000);
    // Spent from the money not assigned: it's that much less, and the
    // ₮4,500 over is said, not taken off again (owner, 2026-10-24).
    expect(o.notAssigned, 540000000 - 450000 - 90000000);
    expect(o.pools.first.overspent, 450000);
  });

  test('how used up: the ring\'s share is built from Left', () {
    final d = ledger(
      amounts: [
        put(food, oct.start, 90000000),
        put(xmas, DateTime(2026, 9, 1), 200000000),
        put(dining, oct.start, 8000000),
      ],
      rows: [
        move(DateTime(2026, 10, 3), checking, food, 27665050),
        move(DateTime(2026, 10, 5), checking, xmas, 15000000),
        move(DateTime(2026, 10, 9), checking, dining, 9200000),
        move(DateTime(2026, 10, 9), checking, coffee, 38000),
      ],
    );
    final o = of(d, oct);
    // Groceries: ₮276,650.50 of ₮900,000 used.
    expect(o.lines[food]!.had, 90000000);
    expect(o.lines[food]!.used, 27665050);
    expect(o.lines[food]!.usedShare, closeTo(0.307, 0.001));
    // Christmas: nothing assigned this month, ₮2,000,000 from before and
    // ₮150,000 spent: a share of what it had, not of nothing.
    expect(o.lines[xmas]!.had, 200000000);
    expect(o.lines[xmas]!.used, 15000000);
    expect(o.lines[xmas]!.usedShare, closeTo(0.075, 0.001));
    // Over, and spent with nothing assigned: full.
    expect(o.lines[dining]!.usedShare, 1);
    expect(o.lines[coffee]!.usedShare, 1);
    expect(o.lines[coffee]!.used, 38000);
    // Nothing had and nothing spent: no ring.
    expect(o.lines[housing]!.usedShare, isNull);
    // Everything spent: full, at the slide's red end.
    final gone = ledger(
      amounts: [put(food, oct.start, 90000000)],
      rows: [move(DateTime(2026, 10, 3), checking, food, 90000000)],
    );
    expect(of(gone, oct).lines[food]!.usedShare, 1);
  });

  test('how used up, the month the budget began in: from Left, not Spent', () {
    // Spent shows the whole month's spending; Left counts only what came
    // after the start, and so does the ring.
    final d = ledger(
      amounts: [put(food, oct.start, 90000000)],
      rows: [
        move(DateTime(2026, 9, 20), checking, food, 5000000),
        move(DateTime(2026, 10, 3), checking, food, 2000000),
        move(DateTime(2026, 10, 20), checking, food, 1000000),
      ],
      prefs: {BudgetKeys.began: '2026-10-15'},
    );
    final o = of(d, oct).lines[food]!;
    expect(o.spent, 3000000);
    expect(o.left, 89000000);
    expect(o.used, 1000000);
    expect(o.usedShare, closeTo(0.011, 0.001));
    // September, before it began: nothing had, so no ring, though it
    // shows what was spent.
    final sep = of(d, (
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 9, 30),
    )).lines[food]!;
    expect(sep.spent, 5000000);
    expect(sep.usedShare, isNull);
  });

  test('refunds put money back', () {
    final d = ledger(
      amounts: [put(food, oct.start, 90000000)],
      rows: [
        move(DateTime(2026, 10, 3), checking, food, 2000000),
        move(DateTime(2026, 10, 4), food, checking, 500000),
      ],
    );
    expect(of(d, oct).lines[food]!.spent, 1500000);
    expect(of(d, oct).lines[food]!.left, 88500000);
  });

  test('scheduled rows and the other currency are left out', () {
    final d = ledger(
      amounts: [put(food, oct.start, 90000000)],
      rows: [
        move(DateTime(2026, 10, 25), checking, food, 7000000, scheduled: true),
        move(
          DateTime(2026, 10, 5),
          dollars,
          food,
          2500,
          currency: Currency.usd,
        ),
      ],
    );
    expect(of(d, oct).lines[food]!.spent, 0);
    expect(of(d, oct).notAssigned, 540000000 - 90000000);
  });

  test('a later period already given to counts now', () {
    final d = ledger(
      amounts: [put(food, oct.start, 90000000), put(food, nov.start, 90000000)],
    );
    expect(of(d, oct).lines[food]!.left, 90000000);
    expect(of(d, oct).notAssigned, 540000000 - 180000000);
  });

  test('a deleted category gives its money back', () {
    final d = ledger(
      amounts: [put(dining, oct.start, 15000000)],
      diningDeleted: true,
    );
    expect(of(d, oct).lines.containsKey(dining), isFalse);
    expect(of(d, oct).notAssigned, 540000000);
    expect(of(d, oct).began, isNull);
  });

  test('periods step by month, or by pay period', () {
    final m = budgetPeriod(DateTime(2026, 10, 20), null);
    expect(nextBudgetPeriod(m, null).start, nov.start);
    expect(previousBudgetPeriod(m, null).end, DateTime(2026, 9, 30));
    const pay = PaySchedule(
      id: 1,
      categoryId: salary,
      accountId: checking,
      amount: 100,
      rule: PayRule.twiceMonthly,
      day1: 10,
      day2: 25,
      weekend: PayWeekend.keep,
    );
    final p = budgetPeriod(DateTime(2026, 10, 20), pay);
    expect(p.start, DateTime(2026, 10, 10));
    expect(p.end, DateTime(2026, 10, 24));
    expect(nextBudgetPeriod(p, pay).start, DateTime(2026, 10, 25));
    expect(previousBudgetPeriod(p, pay).start, DateTime(2026, 9, 25));
  });

  test(
    'the saved start never moves: an earlier amount counts, not its spending',
    () {
      final d = ledger(
        prefs: {BudgetKeys.began: '2026-10-01'},
        amounts: [
          put(food, oct.start, 90000000),
          put(dining, DateTime(2026, 9, 1), 100),
        ],
        rows: [move(DateTime(2026, 9, 10), checking, dining, 18200000)],
      );
      final o = of(d, oct);
      expect(o.began, oct.start);
      // September's dining isn't counted; the ₮1 assigned then is.
      expect(o.lines[dining]!.left, 100);
      expect(o.notAssigned, 540000000 - 18200000 - 90000000 - 100);
    },
  );

  test('a first period under way: what unassigned categories spent', () {
    final d = ledger(
      amounts: [put(food, oct.start, 90000000)],
      rows: [
        move(DateTime(2026, 10, 3), checking, dining, 800000),
        move(DateTime(2026, 10, 4), checking, coffee, 450000),
        move(DateTime(2026, 10, 5), checking, food, 1000000),
      ],
    );
    expect(of(d, oct).unassignedSpent, (count: 2, amount: 1250000));
  });

  test('Not categorized holds nothing: its rows count in the top line', () {
    final d = ledger(
      amounts: [put(food, oct.start, 90000000)],
      rows: [
        move(DateTime(2026, 10, 10), waiting, checking, 250000000),
        move(DateTime(2026, 10, 11), checking, waiting, 3000000),
      ],
    );
    final o = of(d, oct);
    expect(o.lines.containsKey(waiting), isFalse);
    expect(o.notAssigned, 540000000 + 247000000 - 90000000);
  });

  test('a loan paid from a category spends from it', () {
    final key = '${BudgetKeys.loanPrefix}$mortgage';
    final rows = [move(DateTime(2026, 10, 15), checking, mortgage, 100000000)];
    final amounts = [put(housing, oct.start, 100000000)];
    final linked = of(
      ledger(prefs: {key: '$housing'}, amounts: amounts, rows: rows),
      oct,
    );
    expect(linked.lines[housing]!.spent, 100000000);
    expect(linked.lines[housing]!.left, 0);
    expect(linked.notAssigned, 540000000 - 100000000 - 0);
    // Without the link, the payment just lowers the money.
    final plain = of(ledger(amounts: amounts, rows: rows), oct);
    expect(plain.lines[housing]!.left, 100000000);
    expect(plain.notAssigned, linked.notAssigned - 100000000);
  });

  test('the budget keeps its currency when dollar accounts outnumber', () {
    final d = LedgerData(
      accounts: [
        AccountInfo(id: 1, name: 'A', type: AccountType.asset),
        for (final i in [2, 3])
          AccountInfo(
            id: i,
            name: 'D$i',
            type: AccountType.asset,
            currency: Currency.usd,
          ),
        AccountInfo(id: food, name: 'Groceries', type: AccountType.expense),
      ],
      txns: const [],
      prefs: {BudgetKeys.currency: 'MNT'},
    );
    expect(Budget.currencyOf(d), Currency.mnt);
  });

  test('once nothing is in the currency the budget began in, it is in the '
      'currency the accounts are in', () {
    LedgerData ledger({
      bool dollarAccount = false,
      bool dollarCategory = false,
    }) => LedgerData(
      accounts: [
        AccountInfo(id: 1, name: 'A', type: AccountType.asset),
        if (dollarAccount)
          AccountInfo(
            id: 2,
            name: 'D',
            type: AccountType.asset,
            currency: Currency.usd,
            archived: true,
          ),
        AccountInfo(id: food, name: 'Groceries', type: AccountType.expense),
        if (dollarCategory)
          AccountInfo(
            id: 9,
            name: 'Car insurance',
            type: AccountType.expense,
            currency: Currency.usd,
          ),
      ],
      txns: const [],
      prefs: {BudgetKeys.currency: 'USD'},
    );
    // Every dollar account deleted, no dollar category: tugrik.
    expect(Budget.currencyOf(ledger()), Currency.mnt);
    // An archived dollar account still exists, and a dollar category still
    // holds dollars: the budget stays in dollars.
    expect(Budget.currencyOf(ledger(dollarAccount: true)), Currency.usd);
    expect(Budget.currencyOf(ledger(dollarCategory: true)), Currency.usd);
  });

  group('plans', () {
    final sep = (start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30));
    final dec = (start: DateTime(2026, 12, 1), end: DateTime(2026, 12, 31));
    CategoryPlan plan(
      int category,
      PlanKind kind,
      int amount, {
      DateTime? due,
      int? every,
      bool rollover = true,
      DateTime? start,
      int? upTo,
      int? everyDays,
      List<(int, int)>? onDates,
      int? payScheduleId,
      int daysAfterPay = 0,
      PayWeekend weekend = PayWeekend.keep,
      List<int>? weekdays,
      int? nth,
      int? nthWeekday,
      DateTime? endDate,
      int? endCount,
      Map<DateTime, int> once = const {},
    }) => CategoryPlan(
      categoryId: category,
      kind: kind,
      amount: amount,
      start: start ?? DateTime(2026, 10, 5),
      due: due,
      everyMonths: every,
      everyDays: everyDays,
      onDates: onDates,
      payScheduleId: payScheduleId,
      daysAfterPay: daysAfterPay,
      weekend: weekend,
      weekdays: weekdays,
      nth: nth,
      nthWeekday: nthWeekday,
      endDate: endDate,
      endCount: endCount,
      rollover: rollover,
      upTo: upTo,
      once: once,
    );

    test('any time: the set amount each period', () {
      final d = ledger(
        plans: [
          plan(food, PlanKind.each, 90000000),
          plan(xmas, PlanKind.each, 5000000),
        ],
        amounts: [
          put(food, oct.start, 50000000),
          put(xmas, DateTime(2026, 9, 1), 5000000),
          put(xmas, oct.start, 5000000),
        ],
      );
      final o = of(d, oct);
      expect(o.lines[food]!.plan!.planned, 90000000);
      expect(o.lines[food]!.toAssign, 40000000);
      expect(o.lines[food]!.short, 0);
      // Saved in: it builds, and this period's part is in.
      expect(o.lines[xmas]!.left, 10000000);
      expect(o.lines[xmas]!.toAssign, 0);
      // A category with no plan asks for nothing.
      expect(o.lines[dining]!.plan, isNull);
      expect(o.lines[dining]!.toAssign, 0);
    });

    test('not carried over: what is left goes back when the period ends', () {
      final d = ledger(
        plans: [
          plan(
            food,
            PlanKind.each,
            90000000,
            rollover: false,
            start: sep.start,
          ),
        ],
        amounts: [
          put(food, sep.start, 90000000),
          put(food, oct.start, 90000000),
        ],
        rows: [
          move(DateTime(2026, 9, 12), checking, food, 85800000),
          move(DateTime(2026, 10, 3), checking, food, 10000000),
        ],
      );
      final s = of(d, sep);
      expect(s.lines[food]!.left, 4200000);
      final o = of(d, oct);
      // October starts empty; September's ₮42,000 went back.
      expect(o.lines[food]!.fromBefore, 0);
      expect(o.lines[food]!.plan!.wentBack, 4200000);
      expect(o.lines[food]!.left, 80000000);
      // The money: only October's ₮800,000 is held.
      expect(o.money, 540000000 - 85800000 - 10000000);
      expect(o.notAssigned, o.money - 80000000);
      // November, not here yet: October's is shown as gone back, but it
      // still counts as held today.
      final n = of(d, nov);
      expect(n.lines[food]!.fromBefore, 0);
      expect(n.lines[food]!.plan!.wentBack, 80000000);
      expect(n.notAssigned, o.notAssigned);
    });

    test('not carried over: what is overspent still carries', () {
      final d = ledger(
        plans: [
          plan(
            dining,
            PlanKind.each,
            15000000,
            rollover: false,
            start: sep.start,
          ),
        ],
        amounts: [
          put(dining, sep.start, 15000000),
          put(dining, oct.start, 15000000),
        ],
        rows: [move(DateTime(2026, 9, 12), checking, dining, 18200000)],
      );
      final o = of(d, oct);
      expect(o.lines[dining]!.fromBefore, -3200000);
      expect(o.lines[dining]!.plan!.wentBack, 0);
      expect(o.lines[dining]!.left, 11800000);
      expect(o.notAssigned, o.money - 11800000);
    });

    test('not carried over, by pay, seen by month: the ring leaves out what '
        'went back', () {
      // ₮450,000 each pay (the 10th and 25th), not carried over, seen by
      // the month on 10.20: the 09.25 pay's ₮50,000 went back on 10.09.
      const pay = PaySchedule(
        id: 1,
        categoryId: salary,
        accountId: checking,
        amount: 100,
        rule: PayRule.twiceMonthly,
        day1: 10,
        day2: 25,
        weekend: PayWeekend.keep,
      );
      final d = ledger(
        pay: [pay],
        plans: [
          plan(
            food,
            PlanKind.each,
            45000000,
            rollover: false,
            start: DateTime(2026, 9, 25),
            payScheduleId: 1,
          ),
        ],
        amounts: [
          put(food, DateTime(2026, 9, 25), 45000000),
          put(food, DateTime(2026, 10, 10), 45000000),
          put(food, DateTime(2026, 10, 25), 45000000),
        ],
        rows: [
          move(DateTime(2026, 10, 3), checking, food, 40000000),
          move(DateTime(2026, 10, 15), checking, food, 20000000),
        ],
      );
      final o = of(d, oct).lines[food]!;
      expect(o.plan!.wentBack, 5000000);
      expect(o.left, 70000000);
      // Used is what was spent, ₮600,000, of what it had less what went
      // back, ₮1,300,000: not ₮650,000 of ₮1,350,000 (code review).
      expect(o.counted, 60000000);
      expect(o.used, 60000000);
      expect(o.had, 130000000);
      expect(o.usedShare, closeTo(0.4615, 0.001));
    });

    test('carried over: the same category keeps what is left', () {
      final d = ledger(
        plans: [plan(food, PlanKind.each, 90000000)],
        amounts: [put(food, sep.start, 90000000)],
        rows: [move(DateTime(2026, 9, 12), checking, food, 85800000)],
      );
      expect(of(d, oct).lines[food]!.fromBefore, 4200000);
    });

    test('a bill due on a date: equal parts up to it', () {
      final bill = plan(
        xmas,
        PlanKind.byDate,
        120000000,
        due: DateTime(2027, 3, 15),
      );
      // October to March: six parts of ₮200,000.
      var d = ledger(plans: [bill]);
      var o = of(d, oct).lines[xmas]!;
      expect(o.plan!.each, 20000000);
      expect(o.plan!.planned, 20000000);
      expect(o.plan!.due, DateTime(2027, 3, 15));
      expect(o.toAssign, 20000000);
      // Nothing behind yet: this period's part just isn't in.
      expect(o.short, 0);

      // Nothing assigned in October (a plan made after that month's
      // money was assigned): the parts start with November, five of
      // ₮240,000, and nothing is short.
      var n = of(d, nov).lines[xmas]!;
      expect(n.plan!.each, 24000000);
      expect(n.plan!.planned, 24000000);
      expect(n.short, 0);

      // October's part in, November's skipped: the ₮1,000,000 missing is
      // spread over December to March, and November's part is short.
      d = ledger(plans: [bill], amounts: [put(xmas, oct.start, 20000000)]);
      final dc = of(d, dec).lines[xmas]!;
      expect(dc.plan!.planned, 25000000);
      expect(dc.toAssign, 25000000);
      expect(dc.short, 20000000);

      // October's part in: November is on track once its own is.
      d = ledger(
        plans: [bill],
        amounts: [
          put(xmas, oct.start, 20000000),
          put(xmas, nov.start, 20000000),
        ],
      );
      n = of(d, nov).lines[xmas]!;
      expect(n.plan!.planned, 20000000);
      expect(n.toAssign, 0);
      // More than the part one period: the rest is spread over the five
      // left, so the next asks for less.
      d = ledger(plans: [bill], amounts: [put(xmas, oct.start, 30000000)]);
      expect(of(d, nov).lines[xmas]!.plan!.planned, 18000000);
      // Before the plan was made it asks for nothing.
      expect(of(d, sep).lines[xmas]!.plan!.planned, 0);
    });

    test('a bill: what the category held already counts toward it', () {
      final d = ledger(
        plans: [
          plan(xmas, PlanKind.byDate, 120000000, due: DateTime(2027, 3, 15)),
        ],
        amounts: [put(xmas, sep.start, 40000000)],
      );
      // ₮800,000 to go in six parts, each rounded up to a whole tugrik.
      final o = of(d, oct).lines[xmas]!;
      expect(o.plan!.each, 13333400);
      // The last part is whatever is left, never past the bill.
      final march = (start: DateTime(2027, 3, 1), end: DateTime(2027, 3, 31));
      expect(of(d, march).lines[xmas]!.plan!.planned, 80000000);
    });

    test('a bill that comes again: the next one starts after it is due', () {
      final d = ledger(
        plans: [
          plan(
            xmas,
            PlanKind.byDate,
            120000000,
            due: DateTime(2027, 3, 15),
            every: 12,
          ),
        ],
        amounts: [
          for (var m = 10; m <= 15; m++)
            put(xmas, DateTime(2026, m, 1), 20000000),
        ],
        // Paid late, in April: it doesn't count as saved for next year's.
        rows: [move(DateTime(2027, 4, 2), checking, xmas, 120000000)],
      );
      final april = (start: DateTime(2027, 4, 1), end: DateTime(2027, 4, 30));
      final a = of(d, april).lines[xmas]!;
      expect(a.plan!.due, DateTime(2028, 3, 15));
      // Twelve parts of ₮100,000.
      expect(a.plan!.each, 10000000);
      expect(a.plan!.planned, 10000000);
      expect(a.short, 0);
      final may = (start: DateTime(2027, 5, 1), end: DateTime(2027, 5, 31));
      expect(of(d, may).lines[xmas]!.short, 10000000);
    });

    test('a bill every three months, and one due at a month’s end', () {
      final d = ledger(
        plans: [
          plan(
            xmas,
            PlanKind.byDate,
            9000000,
            due: DateTime(2026, 11, 30),
            every: 3,
          ),
        ],
      );
      // October and November: two parts.
      expect(of(d, oct).lines[xmas]!.plan!.each, 4500000);
      // December to February: the last day of February.
      final l = of(d, dec).lines[xmas]!;
      expect(l.plan!.due, DateTime(2027, 2, 28));
      expect(l.plan!.each, 3000000);
    });

    test('a bill that does not repeat, its date gone', () {
      final bill = plan(
        xmas,
        PlanKind.byDate,
        30000000,
        due: DateTime(2026, 11, 20),
      );
      var l = of(ledger(plans: [bill]), dec).lines[xmas]!;
      expect(l.plan!.done, isTrue);
      expect(l.toAssign, 30000000);
      expect(l.short, 30000000);
      l = of(
        ledger(
          plans: [bill],
          amounts: [
            put(xmas, oct.start, 15000000),
            put(xmas, nov.start, 15000000),
          ],
        ),
        dec,
      ).lines[xmas]!;
      expect(l.toAssign, 0);
    });

    test('an amount by a date, once: each period follows what is left', () {
      final goal = plan(
        coffee,
        PlanKind.byDate,
        350000000,
        due: DateTime(2027, 6, 1),
      );
      // ₮1,000,000 saved; ₮2,500,000 over October to June, nine periods.
      var d = ledger(
        plans: [goal],
        amounts: [put(coffee, sep.start, 100000000)],
      );
      var o = of(d, oct).lines[coffee]!;
      expect(o.plan!.each, 27777800);
      expect(o.toAssign, 27777800);
      expect(o.short, 0);
      // Nothing in October: November's part is bigger, eight periods.
      expect(of(d, nov).lines[coffee]!.plan!.each, 31250000);
      // Set aside in full.
      d = ledger(plans: [goal], amounts: [put(coffee, sep.start, 350000000)]);
      o = of(d, oct).lines[coffee]!;
      expect(o.plan!.done, isTrue);
      expect(o.toAssign, 0);
      // Its date gone: all of what's missing, and it's short.
      d = ledger(
        plans: [
          plan(coffee, PlanKind.byDate, 5000000, due: DateTime(2026, 9, 30)),
        ],
        amounts: [put(coffee, sep.start, 2000000)],
      );
      o = of(d, oct).lines[coffee]!;
      expect(o.toAssign, 3000000);
      expect(o.short, 3000000);
    });

    test('by pay period, a bill is split into pay periods', () {
      const pay = PaySchedule(
        id: 1,
        categoryId: salary,
        accountId: checking,
        amount: 100,
        rule: PayRule.twiceMonthly,
        day1: 10,
        day2: 25,
        weekend: PayWeekend.keep,
        definesPeriod: true,
      );
      final d = ledger(
        pay: [pay],
        plans: [
          plan(xmas, PlanKind.byDate, 6000000, due: DateTime(2026, 11, 30)),
        ],
      );
      // 09.25, 10.10, 10.25, 11.10 and 11.25: five pay periods.
      Budget at(DateTime day, LedgerData d) {
        final p = budgetPeriod(day, pay);
        return Budget.of(d, start: p.start, end: p.end, today: today);
      }

      expect(at(DateTime(2026, 10, 5), d).lines[xmas]!.plan!.each, 1200000);
      // The first part in, the second of them asks for one more.
      final first = budgetPeriod(DateTime(2026, 10, 5), pay);
      final l = at(
        DateTime(2026, 10, 20),
        ledger(
          pay: [pay],
          plans: d.plans.values.toList(),
          amounts: [put(xmas, first.start, 1200000)],
        ),
      ).lines[xmas]!;
      expect(l.plan!.planned, 1200000);
      expect(l.short, 0);
    });
    test('two bills due in one pay period are both asked for', () {
      // Paid on the 25th, moved back off a weekend: 10.25 is a Sunday, so
      // the period 10.23–11.24 holds the bills of 10.24 and 11.24.
      const pay = PaySchedule(
        id: 1,
        categoryId: salary,
        accountId: checking,
        amount: 100,
        rule: PayRule.monthly,
        day1: 25,
        weekend: PayWeekend.before,
        definesPeriod: true,
      );
      final p = budgetPeriod(DateTime(2026, 11, 1), pay);
      expect(
        (p.start, p.end),
        (DateTime(2026, 10, 23), DateTime(2026, 11, 24)),
      );
      final d = ledger(
        pay: [pay],
        plans: [
          plan(
            xmas,
            PlanKind.byDate,
            10000000,
            due: DateTime(2026, 10, 24),
            every: 1,
            start: DateTime(2026, 10, 23),
          ),
        ],
      );
      final l = Budget.of(
        d,
        start: p.start,
        end: p.end,
        today: today,
      ).lines[xmas]!;
      expect(l.plan!.planned, 20000000);
      expect(l.short, 0);
    });

    test('by the month, a bill due before the next pay is asked for in the '
        'month of the pay before it', () {
      // Paid on the 25th; rent due on the 1st (owner, 2026-10-24): the
      // 10.25 pay covers 11.01's rent, so October asks for it.
      const pay = PaySchedule(
        id: 1,
        categoryId: salary,
        accountId: checking,
        amount: 100,
        rule: PayRule.monthly,
        day1: 25,
        weekend: PayWeekend.keep,
      );
      final d = ledger(
        pay: [pay],
        plans: [
          plan(
            xmas,
            PlanKind.byDate,
            180000000,
            due: DateTime(2026, 11, 1),
            every: 1,
            start: DateTime(2026, 10, 1),
          ),
        ],
      );
      final october = of(d, oct).lines[xmas]!.plan!;
      expect(october.planned, 180000000);
      // The note keeps the bill's own date.
      expect(october.due, DateTime(2026, 11, 1));
      expect(october.lastPeriod, isTrue);
      // November asks for December's.
      final nov = (start: DateTime(2026, 11, 1), end: DateTime(2026, 11, 30));
      final november = of(d, nov).lines[xmas]!.plan!;
      expect(november.due, DateTime(2026, 12, 1));
      expect(november.planned, 180000000);
      // With no pay set up, October asks for nothing: the bill is
      // November's.
      final none = ledger(plans: d.plans.values.toList());
      expect(of(none, oct).lines[xmas]!.plan!.planned, lessThan(180000000));
    });

    test('paid weekly, a date years ahead is still quick', () {
      final pay = PaySchedule(
        id: 1,
        categoryId: salary,
        accountId: checking,
        amount: 100,
        rule: PayRule.everyWeeks,
        weeks: 1,
        anchor: DateTime(2024, 1, 5),
        weekend: PayWeekend.keep,
        definesPeriod: true,
      );
      final d = ledger(
        pay: [pay],
        plans: [
          plan(coffee, PlanKind.byDate, 520000000, due: DateTime(2046, 10, 16)),
        ],
      );
      final p = budgetPeriod(today, pay);
      final watch = Stopwatch()..start();
      final l = Budget.of(
        d,
        start: p.start,
        end: p.end,
        today: today,
      ).lines[coffee]!;
      expect(watch.elapsedMilliseconds, lessThan(200));
      // Twenty years of weeks, about ₮5,000 each.
      expect(l.plan!.each, inInclusiveRange(490000, 500000));
    });

    test('an amount set aside and then spent stays set aside', () {
      final goal = plan(
        coffee,
        PlanKind.byDate,
        30000000,
        due: DateTime(2026, 12, 31),
      );
      final d = ledger(
        plans: [goal],
        amounts: [
          put(coffee, oct.start, 10000000),
          put(coffee, nov.start, 10000000),
          put(coffee, dec.start, 10000000),
        ],
        rows: [move(DateTime(2026, 12, 20), checking, coffee, 30000000)],
      );
      // December's amount completes it.
      expect(of(d, dec).lines[coffee]!.plan!.done, isTrue);
      final jan = (start: DateTime(2027, 1, 1), end: DateTime(2027, 1, 31));
      final j = of(d, jan).lines[coffee]!;
      expect(j.plan!.done, isTrue);
      expect(j.toAssign, 0);
      // Bought early instead: the part doesn't jump.
      final early = ledger(
        plans: [goal],
        amounts: [put(coffee, oct.start, 10000000)],
        rows: [move(DateTime(2026, 10, 25), checking, coffee, 10000000)],
      );
      expect(of(early, nov).lines[coffee]!.plan!.each, 10000000);
    });

    test('not carried over is from the plan on: the past is left alone', () {
      // September's ₮100,000 stays; chosen in October, it empties from
      // October on.
      final d = ledger(
        plans: [plan(food, PlanKind.each, 90000000, rollover: false)],
        amounts: [put(food, sep.start, 10000000)],
        rows: [move(DateTime(2026, 10, 3), checking, food, 8000000)],
      );
      final o = of(d, oct);
      expect(o.lines[food]!.fromBefore, 10000000);
      expect(o.lines[food]!.left, 2000000);
      expect(o.lines[food]!.plan!.wentBack, 0);
      expect(o.notAssigned, o.money - 2000000);
      expect(of(d, nov).lines[food]!.plan!.wentBack, 2000000);
    });

    test('a bill is short by one bill at most, and a minus is made up', () {
      final bill = plan(
        xmas,
        PlanKind.byDate,
        12000000,
        due: DateTime(2026, 10, 20),
        every: 1,
      );
      // October's in; three months skipped and never paid: February asks
      // for February's only.
      var d = ledger(plans: [bill], amounts: [put(xmas, oct.start, 12000000)]);
      final feb = (start: DateTime(2027, 2, 1), end: DateTime(2027, 2, 28));
      final f = of(d, feb).lines[xmas]!;
      expect(f.plan!.planned, 12000000);
      expect(f.short, 0);
      // November's bill came to more than was saved: December makes up
      // the ₮30,000.
      d = ledger(
        plans: [bill],
        amounts: [
          put(xmas, oct.start, 12000000),
          put(xmas, nov.start, 12000000),
        ],
        rows: [
          move(DateTime(2026, 10, 20), checking, xmas, 12000000),
          move(DateTime(2026, 11, 20), checking, xmas, 15000000),
        ],
      );
      expect(of(d, dec).lines[xmas]!.plan!.planned, 15000000);
    });

    test('a bill: what was held beyond one bill counts toward the next', () {
      final d = ledger(
        plans: [
          plan(
            xmas,
            PlanKind.byDate,
            10000000,
            due: DateTime(2026, 10, 20),
            every: 1,
          ),
        ],
        amounts: [put(xmas, sep.start, 25000000)],
      );
      expect(of(d, oct).lines[xmas]!.plan!.planned, 0);
      expect(of(d, nov).lines[xmas]!.plan!.planned, 0);
      expect(of(d, dec).lines[xmas]!.plan!.planned, 5000000);
    });

    test('counted by what was assigned, not what is left', () {
      // A gift bought in April counts toward the birthday in August: the
      // money went where it was for, so nothing more is asked.
      final bill = plan(
        xmas,
        PlanKind.byDate,
        120000000,
        due: DateTime(2027, 3, 15),
      );
      final amounts = [
        put(xmas, oct.start, 20000000),
        put(xmas, nov.start, 20000000),
      ];
      var n = of(ledger(plans: [bill], amounts: amounts), nov).lines[xmas]!;
      expect(n.toAssign, 0);
      n = of(
        ledger(
          plans: [bill],
          amounts: amounts,
          rows: [move(DateTime(2026, 11, 3), checking, xmas, 30000000)],
        ),
        nov,
      ).lines[xmas]!;
      expect(n.toAssign, 0);
      expect(
        of(
          ledger(plans: [bill], amounts: amounts),
          dec,
        ).lines[xmas]!.plan!.each,
        20000000,
      );
    });

    test('a missed part spreads over the periods left', () {
      // СӨХ, ₮270,000 due 01.10, made in October: four parts of ₮67,500.
      final fee = plan(
        xmas,
        PlanKind.byDate,
        27000000,
        due: DateTime(2027, 1, 10),
      );
      var d = ledger(plans: [fee], amounts: [put(xmas, oct.start, 6750000)]);
      expect(of(d, oct).lines[xmas]!.plan!.each, 6750000);
      // November skipped: December asks for ₮101,250, half of what's
      // missing, and names November's part as short.
      final dc = of(d, dec).lines[xmas]!;
      expect(dc.plan!.each, 10125000);
      expect(dc.toAssign, 10125000);
      expect(dc.short, 6750000);
      // December's in: on track, and January asks for the rest, with
      // nothing short, since what was asked was put in.
      d = ledger(
        plans: [fee],
        amounts: [
          put(xmas, oct.start, 6750000),
          put(xmas, dec.start, 10125000),
        ],
      );
      expect(
        (of(d, dec).lines[xmas]!.toAssign, of(d, dec).lines[xmas]!.short),
        (0, 0),
      );
      final jan = (start: DateTime(2027, 1, 1), end: DateTime(2027, 1, 31));
      final j = of(d, jan).lines[xmas]!;
      expect((j.plan!.each, j.short), (10125000, 0));
    });

    test('any time with a cap: stops asking once it holds the cap', () {
      final repairs = plan(xmas, PlanKind.each, 10000000, upTo: 30000000);
      // ₮250,000 held: October asks only for the ₮50,000 of room left.
      var d = ledger(
        plans: [repairs],
        amounts: [put(xmas, sep.start, 25000000)],
      );
      var o = of(d, oct).lines[xmas]!;
      expect((o.plan!.planned, o.plan!.done), (5000000, false));
      // Holding the cap: nothing asked, and the line says so.
      d = ledger(plans: [repairs], amounts: [put(xmas, sep.start, 30000000)]);
      o = of(d, oct).lines[xmas]!;
      expect((o.plan!.planned, o.plan!.done, o.toAssign), (0, true, 0));
      // A repair in October: asked for again from November, in full.
      d = ledger(
        plans: [repairs],
        amounts: [put(xmas, sep.start, 30000000)],
        rows: [move(DateTime(2026, 10, 12), checking, xmas, 18000000)],
      );
      o = of(d, oct).lines[xmas]!;
      expect((o.plan!.planned, o.plan!.done), (0, false));
      expect(of(d, nov).lines[xmas]!.plan!.planned, 10000000);
      // The cap is only for a category that carries over.
      d = ledger(
        plans: [
          plan(xmas, PlanKind.each, 10000000, upTo: 30000000, rollover: false),
        ],
        amounts: [put(xmas, sep.start, 30000000)],
      );
      expect(of(d, oct).lines[xmas]!.plan!.planned, 10000000);
    });

    test('any time, just for one month: that month asks for its own amount, '
        'and the next goes back to the plan (#100)', () {
      // ₮900,000 a month, ₮1,200,000 just for December, January skipped.
      final jan = (start: DateTime(2027, 1, 1), end: DateTime(2027, 1, 31));
      final feb = (start: DateTime(2027, 2, 1), end: DateTime(2027, 2, 28));
      final groceries = plan(
        food,
        PlanKind.each,
        90000000,
        once: {dec.start: 120000000, jan.start: 0},
      );
      final d = ledger(plans: [groceries]);
      final n = of(d, nov).lines[food]!;
      expect(
        (n.plan!.each, n.toAssign, n.plan!.once),
        (90000000, 90000000, false),
      );
      final c = of(d, dec).lines[food]!;
      expect(
        (c.plan!.each, c.toAssign, c.plan!.once),
        (120000000, 120000000, true),
      );
      final j = of(d, jan).lines[food]!;
      expect((j.plan!.each, j.toAssign, j.plan!.once), (0, 0, true));
      expect(of(d, feb).lines[food]!.toAssign, 90000000);
      // A cap still holds: with ₮1,000,000 in it and room for ₮300,000,
      // December asks for no more than the room.
      final capped = ledger(
        plans: [
          plan(
            xmas,
            PlanKind.each,
            10000000,
            upTo: 130000000,
            once: {dec.start: 120000000},
          ),
        ],
        amounts: [put(xmas, sep.start, 100000000)],
      );
      expect(of(capped, dec).lines[xmas]!.plan!.planned, 30000000);
      // Seen by a pay (the 10th and 25th): December's amount is said as
      // December's, and the pay's share comes from it (budget review).
      const pay = PaySchedule(
        id: 1,
        categoryId: salary,
        accountId: checking,
        amount: 100,
        rule: PayRule.twiceMonthly,
        day1: 10,
        day2: 25,
        weekend: PayWeekend.keep,
        definesPeriod: true,
      );
      final byPay = ledger(pay: [pay], plans: [groceries]);
      final p = of(byPay, (
        start: DateTime(2026, 12, 10),
        end: DateTime(2026, 12, 24),
      )).lines[food]!.plan!;
      expect((p.once, p.onceFrom, p.each), (true, dec.start, 120000000));
      expect(p.planned, greaterThan(0));
      final skipped = of(byPay, (
        start: DateTime(2027, 1, 10),
        end: DateTime(2027, 1, 24),
      )).lines[food]!.plan!;
      expect((skipped.once, skipped.each, skipped.planned), (true, 0, 0));
    });

    test('a bill the bank took a day early counts on its date', () {
      // Water, ₮45,000 on the 1st, paid from the plan's own scheduled
      // row. December's is taken 11.30: still December's bill.
      final water = plan(
        xmas,
        PlanKind.byDate,
        4500000,
        due: DateTime(2026, 11, 1),
        every: 1,
      );
      final amounts = [
        put(xmas, oct.start, 2250000),
        put(xmas, nov.start, 2250000),
      ];
      final d = ledger(
        plans: [water],
        amounts: amounts,
        rows: [
          move(DateTime(2026, 11, 1), checking, xmas, 4500000, plan: xmas),
          move(DateTime(2026, 11, 30), checking, xmas, 4500000, plan: xmas),
        ],
      );
      expect(of(d, dec).lines[xmas]!.plan!.planned, 4500000);
      // A row the user entered by hand on 11.30 is November's spending,
      // and December makes up what it took.
      final byHand = ledger(
        plans: [water],
        amounts: amounts,
        rows: [
          move(DateTime(2026, 11, 1), checking, xmas, 4500000, plan: xmas),
          move(DateTime(2026, 11, 30), checking, xmas, 4500000),
        ],
      );
      expect(of(byHand, dec).lines[xmas]!.plan!.planned, 9000000);
      // The nearest date, either side; far before the first, not this
      // plan's bill at all.
      expect(
        Budget.billDate(water, DateTime(2026, 12, 3)),
        DateTime(2026, 12, 1),
      );
      expect(
        Budget.billDate(water, DateTime(2026, 10, 20)),
        DateTime(2026, 11, 1),
      );
      expect(Budget.billDate(water, DateTime(2026, 10, 10)), isNull);
    });

    test('every two weeks: the bills inside a month are all asked for', () {
      // A cleaner every second Friday from 10.09: twice in October.
      final cleaner = plan(
        xmas,
        PlanKind.byDate,
        6000000,
        due: DateTime(2026, 10, 9),
        everyDays: 14,
        start: DateTime(2026, 10, 1),
      );
      final o = of(ledger(plans: [cleaner]), oct).lines[xmas]!;
      expect(o.plan!.due, DateTime(2026, 10, 9));
      expect(o.plan!.planned, 12000000);
      expect(Budget.dueAfter(cleaner, 3), DateTime(2026, 11, 20));
    });

    test('on these dates: taxes four times a year, uneven gaps', () {
      final tax = plan(
        xmas,
        PlanKind.byDate,
        40000000,
        due: DateTime(2027, 1, 15),
        onDates: [(4, 15), (6, 15), (9, 15), (1, 15)],
      );
      expect(Budget.dueAfter(tax, 0), DateTime(2027, 1, 15));
      expect(Budget.dueAfter(tax, 1), DateTime(2027, 4, 15));
      expect(Budget.dueAfter(tax, 3), DateTime(2027, 9, 15));
      expect(Budget.dueAfter(tax, 4), DateTime(2028, 1, 15));
      // October to January: four parts of ₮100,000; then three to April.
      final d = ledger(plans: [tax]);
      expect(of(d, oct).lines[xmas]!.plan!.each, 10000000);
      final feb = (start: DateTime(2027, 2, 1), end: DateTime(2027, 2, 28));
      final f = of(d, feb).lines[xmas]!;
      expect((f.plan!.due, f.plan!.each), (DateTime(2027, 4, 15), 13333400));
    });

    test('Custom…: every 2 weeks on Mondays and Thursdays', () {
      // From Wednesday 09.16: that week's Thursday, then the week after
      // next's Monday and Thursday.
      final gym = plan(
        xmas,
        PlanKind.byDate,
        1000000,
        due: DateTime(2026, 9, 16),
        everyDays: 14,
        weekdays: [1, 4],
      );
      expect(
        [for (var n = 0; n < 5; n++) Budget.dueAfter(gym, n)],
        [
          DateTime(2026, 9, 17),
          DateTime(2026, 9, 28),
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 12),
          DateTime(2026, 10, 15),
        ],
      );
    });

    test('Custom…: the second Tuesday, and the last Friday, of the month', () {
      // September's second Tuesday (09.08) is before 09.16: October's is
      // the first.
      final club = plan(
        xmas,
        PlanKind.byDate,
        1000000,
        due: DateTime(2026, 9, 16),
        every: 1,
        nth: 2,
        nthWeekday: 2,
      );
      expect(Budget.dueAfter(club, 0), DateTime(2026, 10, 13));
      expect(Budget.dueAfter(club, 1), DateTime(2026, 11, 10));
      // September's last Friday is 09.25, still ahead; October's is 10.30.
      final payroll = plan(
        xmas,
        PlanKind.byDate,
        1000000,
        due: DateTime(2026, 9, 16),
        every: 1,
        nth: -1,
        nthWeekday: 5,
      );
      expect(Budget.dueAfter(payroll, 0), DateTime(2026, 9, 25));
      expect(Budget.dueAfter(payroll, 1), DateTime(2026, 10, 30));
      expect(Budget.dueAfter(payroll, 2), DateTime(2026, 11, 27));
      // Every year on the last Friday of September.
      final yearly = plan(
        xmas,
        PlanKind.byDate,
        1000000,
        due: DateTime(2026, 9, 16),
        every: 12,
        nth: -1,
        nthWeekday: 5,
      );
      expect(Budget.dueAfter(yearly, 1), DateTime(2027, 9, 24));
    });

    test('Custom…: an ended plan asks for no bill past its end', () {
      // Every week from 10.07, twice: October holds two bills, not four.
      final twice = plan(
        xmas,
        PlanKind.byDate,
        1000000,
        due: DateTime(2026, 10, 7),
        everyDays: 7,
        endCount: 2,
        start: DateTime(2026, 10, 1),
      );
      final o = of(ledger(plans: [twice]), oct).lines[xmas]!.plan!;
      expect(o.planned, 2000000);
      expect(o.ended, isFalse);
    });

    test('Custom…: Ends after so many times, or on a date', () {
      final threeTimes = plan(
        xmas,
        PlanKind.byDate,
        1000000,
        due: DateTime(2026, 10, 15),
        every: 1,
        endCount: 3,
        start: DateTime(2026, 10, 1),
      );
      expect(Budget.lastDue(threeTimes), DateTime(2026, 12, 15));
      expect(Budget.over(threeTimes, DateTime(2026, 12, 15)), isFalse);
      expect(Budget.over(threeTimes, DateTime(2027, 1, 15)), isTrue);
      final untilJan = plan(
        xmas,
        PlanKind.byDate,
        1000000,
        due: DateTime(2026, 10, 15),
        every: 1,
        endDate: DateTime(2027, 1, 20),
        start: DateTime(2026, 10, 1),
      );
      expect(Budget.lastDue(untilJan), DateTime(2027, 1, 15));
      // Past the last bill the line asks for nothing and says it ended.
      final feb = (start: DateTime(2027, 2, 1), end: DateTime(2027, 2, 28));
      final f = of(ledger(plans: [untilJan]), feb).lines[xmas]!.plan!;
      expect(f.ended, isTrue);
      expect(f.planned, 0);
      expect(f.due, DateTime(2027, 1, 15));
      // Before it, the bills count as ever.
      final nov = (start: DateTime(2026, 11, 1), end: DateTime(2026, 11, 30));
      final n = of(ledger(plans: [untilJan]), nov).lines[xmas]!.plan!;
      expect(n.ended, isFalse);
      expect(n.due, DateTime(2026, 11, 15));
      // No end: it goes on.
      expect(
        Budget.lastDue(
          plan(xmas, PlanKind.byDate, 1, due: DateTime(2026, 10, 15), every: 1),
        ),
        isNull,
      );
    });

    test('every payday: the pay schedule’s dates, days after if asked', () {
      const pay = PaySchedule(
        id: 1,
        categoryId: salary,
        accountId: checking,
        amount: 100,
        rule: PayRule.twiceMonthly,
        day1: 10,
        day2: 25,
        weekend: PayWeekend.keep,
        definesPeriod: true,
      );
      final loan = plan(
        xmas,
        PlanKind.byDate,
        15000000,
        payScheduleId: 1,
        start: DateTime(2026, 10, 1),
      );
      final d = ledger(pay: [pay], plans: [loan]);
      expect(Budget.dueAfter(loan, 0, pay: pay), DateTime(2026, 10, 10));
      expect(Budget.dueAfter(loan, 1, pay: pay), DateTime(2026, 10, 25));
      // By pay period, each period has one bill: the whole amount.
      final period = budgetPeriod(DateTime(2026, 10, 12), pay);
      final l = Budget.of(
        d,
        start: period.start,
        end: period.end,
        today: today,
      ).lines[xmas]!;
      expect(l.plan!.planned, 15000000);
      // Two days after payday.
      final later = plan(
        xmas,
        PlanKind.byDate,
        15000000,
        payScheduleId: 1,
        daysAfterPay: 2,
        start: DateTime(2026, 10, 1),
      );
      expect(Budget.dueAfter(later, 0, pay: pay), DateTime(2026, 10, 12));
      // The schedule gone, the plan has one date: the day it was made.
      expect(Budget.dueAfter(loan, 1), DateTime(2026, 10, 1));
    });

    test('a monthly amount seen by pay periods: a share by days, as about', () {
      // Paid every 2 weeks from 09.11: the periods 10.09–10.22 and
      // 10.23–11.05 (owner, 2026-10-05: Jeff and Jenny).
      final pay = PaySchedule(
        id: 1,
        categoryId: salary,
        accountId: checking,
        amount: 100,
        rule: PayRule.everyWeeks,
        weeks: 2,
        anchor: DateTime(2026, 9, 11),
        weekend: PayWeekend.keep,
        definesPeriod: true,
      );
      // ₮600,000 a month for groceries: its own period is the month.
      final groceries = plan(
        food,
        PlanKind.each,
        60000000,
        start: DateTime(2026, 10, 1),
      );
      final p = budgetPeriod(DateTime(2026, 10, 12), pay);
      expect((p.start, p.end), (DateTime(2026, 10, 9), DateTime(2026, 10, 22)));
      Budget at(LedgerData d, ({DateTime start, DateTime end}) span) =>
          Budget.of(d, start: span.start, end: span.end, today: today);
      final pp = (start: p.start, end: p.end);
      // Nothing in yet: the 14 days of October's 23 left from 10.09, said
      // in its own terms with the share beside it.
      var l = at(ledger(pay: [pay], plans: [groceries]), pp).lines[food]!;
      expect(l.plan!.approx, isTrue);
      expect(l.plan!.each, 60000000);
      expect(l.plan!.planned, 36530000);
      expect(l.toAssign, 36530000);
      // ₮300,000 already in for October: the share is of the rest.
      l = at(
        ledger(
          pay: [pay],
          plans: [groceries],
          amounts: [put(food, DateTime(2026, 10, 1), 30000000)],
        ),
        pp,
      ).lines[food]!;
      expect(l.plan!.planned, 18270000);
      // The share put in; the next pay period takes what's left of
      // October (its last 9 days, all of them) and November's first 5 of
      // 30. So the shares add up to the month.
      final next = nextBudgetPeriod(p, pay);
      l = at(
        ledger(
          pay: [pay],
          plans: [groceries],
          amounts: [
            put(food, DateTime(2026, 10, 1), 30000000),
            put(food, p.start, 18270000),
          ],
        ),
        (start: next.start, end: next.end),
      ).lines[food]!;
      expect(l.plan!.planned, 11730000 + 10000000);
      // Seen by the month (the pay no longer the view): exact, and
      // nothing is about.
      final monthView = PaySchedule(
        id: 1,
        categoryId: salary,
        accountId: checking,
        amount: 100,
        rule: PayRule.everyWeeks,
        weeks: 2,
        anchor: DateTime(2026, 9, 11),
        weekend: PayWeekend.keep,
      );
      l = at(
        ledger(
          pay: [monthView],
          plans: [groceries],
          amounts: [put(food, DateTime(2026, 10, 1), 30000000)],
        ),
        oct,
      ).lines[food]!;
      expect(l.plan!.approx, isFalse);
      expect(l.plan!.planned, 60000000);
      expect(l.toAssign, 30000000);
    });

    test(
      'an amount per pay period seen by the month: emptied at each payday',
      () {
        // ₮200,000 each 2-week pay period (09.25, 10.09, 10.23), not carried
        // over; the pay doesn't set the view.
        PaySchedule pay({bool view = false}) => PaySchedule(
          id: 1,
          categoryId: salary,
          accountId: checking,
          amount: 100,
          rule: PayRule.everyWeeks,
          weeks: 2,
          anchor: DateTime(2026, 9, 11),
          weekend: PayWeekend.keep,
          definesPeriod: view,
        );
        final groceries = plan(
          food,
          PlanKind.each,
          20000000,
          rollover: false,
          payScheduleId: 1,
          start: DateTime(2026, 9, 25),
        );
        LedgerData d({bool view = false}) => ledger(
          pay: [pay(view: view)],
          plans: [groceries],
          amounts: [
            put(food, DateTime(2026, 9, 25), 20000000),
            put(food, DateTime(2026, 10, 9), 20000000),
          ],
          rows: [
            move(DateTime(2026, 9, 30), checking, food, 5000000),
            move(DateTime(2026, 10, 12), checking, food, 8000000),
          ],
        );
        // October, by the month, today 10.20: it began with 09.25's
        // ₮150,000 left, which went back on 10.09. The 10.23 payday hasn't
        // come, so what 10.09's holds (less what was spent) is still Left,
        // as the top line counts it (both reviews, 2026-10-05).
        final o = of(d(), oct);
        final l = o.lines[food]!;
        expect(l.fromBefore, 15000000);
        expect(l.assigned, 20000000);
        expect(l.spent, 8000000);
        expect(l.left, 12000000);
        expect(l.plan!.wentBack, 15000000);
        expect(l.plan!.wentBackOn, DateTime(2026, 10, 9));
        expect(o.notAssigned, o.money - 12000000);
        // Its plan by the month: 10.09's ₮200,000 whole, 10.23's 9 of 14
        // days (to ₮100), and 09.25's already in before the month; each
        // own period's share dated where it meets the month.
        expect(l.plan!.approx, isTrue);
        expect(l.plan!.planned, 20000000 + 12860000);
        expect(l.plan!.shares, [
          (date: DateTime(2026, 10, 1), amount: 0),
          (date: DateTime(2026, 10, 9), amount: 20000000),
          (date: DateTime(2026, 10, 23), amount: 12860000),
        ]);
        // Assigning what's planned from the month view puts each period's
        // share in that period, so none of it is emptied at 10.09 (both
        // reviews, 2026-10-05: one row dated 10.01 was, and took the
        // 10.09 row with it).
        expect(
          Budget.spread(
            span: (start: oct.start, end: oct.end, label: ''),
            own: pay(),
            shares: l.plan!.shares,
            delta: l.plan!.planned,
          ),
          [
            (date: DateTime(2026, 10, 9), amount: 20000000),
            (date: DateTime(2026, 10, 23), amount: 12860000),
          ],
        );
        // Nothing planned (or more than the plan): by days, the rounding
        // on the last.
        expect(
          Budget.spread(
            span: (start: oct.start, end: oct.end, label: ''),
            own: pay(),
            shares: const [],
            delta: 3100000,
          ),
          [
            (date: DateTime(2026, 10, 1), amount: 800000),
            (date: DateTime(2026, 10, 9), amount: 1400000),
            (date: DateTime(2026, 10, 23), amount: 900000),
          ],
        );
        // Once both of October's paydays have come, the month ends at zero.
        final l2 = Budget.of(
          d(),
          start: oct.start,
          end: oct.end,
          today: DateTime(2026, 11, 1),
        ).lines[food]!;
        expect(l2.left, 0);
        expect(l2.plan!.wentBack, 27000000);
        expect(l2.plan!.wentBackOn, DateTime(2026, 10, 23));
        // By its own pay period (10.09–10.22): exact.
        final p = budgetPeriod(today, pay());
        final own = Budget.of(
          d(view: true),
          start: p.start,
          end: p.end,
          today: today,
        ).lines[food]!;
        expect(own.fromBefore, 0);
        expect(own.left, 12000000);
        expect(own.plan!.approx, isFalse);
        expect(own.plan!.planned, 20000000);
        expect(own.plan!.wentBack, 15000000);
      },
    );

    test('a plan moved off a stopped pay: to another pay, or to the month', () {
      final each = plan(food, PlanKind.each, 60000000, payScheduleId: 1);
      expect(each.movedToPay(2, nextPayday: today).payScheduleId, 2);
      expect(each.movedToPay(null, nextPayday: today).payScheduleId, isNull);
      // A bill 2 days after every payday: another pay's paydays, or
      // monthly from the stopped pay's next payday plus those days.
      final bill = plan(
        xmas,
        PlanKind.byDate,
        15000000,
        payScheduleId: 1,
        daysAfterPay: 2,
        start: DateTime(2026, 10, 1),
      );
      expect(bill.movedToPay(2, nextPayday: today).payScheduleId, 2);
      expect(bill.movedToPay(2, nextPayday: today).daysAfterPay, 2);
      final monthly = bill.movedToPay(null, nextPayday: DateTime(2026, 10, 23));
      expect(monthly.payScheduleId, isNull);
      expect(monthly.due, DateTime(2026, 10, 25));
      expect(monthly.everyMonths, 1);
      expect(monthly.daysAfterPay, 0);
      expect(monthly.amount, 15000000);
      // A bill on a date of its own has no pay to move.
      final dated = plan(xmas, PlanKind.byDate, 1, due: DateTime(2026, 11, 1));
      expect(dated.movedToPay(2, nextPayday: today).payScheduleId, isNull);
    });

    test('a weekend rule moves a bill off Saturday and Sunday', () {
      // 2026.10.10 is a Saturday.
      final before = plan(
        xmas,
        PlanKind.byDate,
        100,
        due: DateTime(2026, 10, 10),
        every: 1,
        weekend: PayWeekend.before,
      );
      expect(Budget.dueAfter(before, 0), DateTime(2026, 10, 9));
      final after = plan(
        xmas,
        PlanKind.byDate,
        100,
        due: DateTime(2026, 10, 10),
        every: 1,
        weekend: PayWeekend.after,
      );
      expect(Budget.dueAfter(after, 0), DateTime(2026, 10, 12));
      // November 10th is a Tuesday: untouched either way.
      expect(Budget.dueAfter(before, 1), DateTime(2026, 11, 10));
    });

    test('every three years', () {
      final cert = plan(
        xmas,
        PlanKind.byDate,
        36000000,
        due: DateTime(2027, 4, 1),
        every: 36,
      );
      // October to April: seven parts.
      final d = ledger(plans: [cert]);
      expect(of(d, oct).lines[xmas]!.plan!.each, 5142900);
      final may = (start: DateTime(2027, 5, 1), end: DateTime(2027, 5, 31));
      final m = of(d, may).lines[xmas]!;
      expect(m.plan!.due, DateTime(2030, 4, 1));
      expect(m.plan!.each, 1000000);
    });

    test('the budget’s start moved on: a bill counts from there', () {
      // Made on 09.20, then "start the budget on 10.01 instead".
      final d = ledger(
        prefs: {BudgetKeys.began: '2026-10-01'},
        plans: [
          plan(
            xmas,
            PlanKind.byDate,
            200000000,
            due: DateTime(2027, 1, 15),
            start: DateTime(2026, 9, 20),
          ),
        ],
        amounts: [put(xmas, oct.start, 50000000)],
      );
      // October to January: four parts of ₮500,000, none short.
      final o = of(d, oct).lines[xmas]!;
      expect(o.plan!.each, 50000000);
      expect((o.toAssign, o.short), (0, 0));
    });
  });

  group('a bill\'s line', () {
    test('has no ring, and says the day this period\'s bill was paid', () {
      // Rent on the 1st, from September on.
      final rent = CategoryPlan(
        categoryId: housing,
        kind: PlanKind.byDate,
        amount: 180000000,
        start: DateTime(2026, 9, 1),
        due: DateTime(2026, 9, 1),
        everyMonths: 1,
        rollover: true,
      );
      final d = ledger(
        plans: [rent],
        amounts: [put(housing, oct.start, 180000000)],
        rows: [
          move(
            DateTime(2026, 10, 1),
            checking,
            housing,
            180000000,
            plan: housing,
          ),
        ],
      );
      final o = of(d, oct).lines[housing]!;
      expect(o.usedShare, isNull);
      expect(o.paidOn, DateTime(2026, 10, 1));
      // Nothing tied to the bill in November yet.
      expect(of(d, nov).lines[housing]!.paidOn, isNull);
      // A row in the category not tied to the bill says nothing.
      final loose = ledger(
        plans: [rent],
        rows: [move(DateTime(2026, 10, 1), checking, housing, 180000000)],
      );
      expect(of(loose, oct).lines[housing]!.paidOn, isNull);
      // Rent for 11.01 paid on 10.30 is November's, as its spending is
      // counted: November's line says paid 10.30, October's still 10.01.
      final early = ledger(
        plans: [rent],
        rows: [
          move(
            DateTime(2026, 10, 1),
            checking,
            housing,
            180000000,
            plan: housing,
          ),
          move(
            DateTime(2026, 10, 30),
            checking,
            housing,
            180000000,
            plan: housing,
          ),
        ],
      );
      expect(of(early, oct).lines[housing]!.paidOn, DateTime(2026, 10, 1));
      expect(of(early, nov).lines[housing]!.paidOn, DateTime(2026, 10, 30));
      // And a bill paid a day late: on the bill's month, not the row's.
      final late = ledger(
        plans: [rent],
        rows: [
          move(
            DateTime(2026, 11, 2),
            checking,
            housing,
            180000000,
            plan: housing,
          ),
        ],
      );
      expect(of(late, oct).lines[housing]!.paidOn, isNull);
      expect(of(late, nov).lines[housing]!.paidOn, DateTime(2026, 11, 2));
      // Two payments of one bill: the later day.
      final twice = ledger(
        plans: [rent],
        rows: [
          move(
            DateTime(2026, 10, 1),
            checking,
            housing,
            180000000,
            plan: housing,
          ),
          move(
            DateTime(2026, 10, 3),
            checking,
            housing,
            180000000,
            plan: housing,
          ),
        ],
      );
      expect(of(twice, oct).lines[housing]!.paidOn, DateTime(2026, 10, 3));
    });
  });

  group('currencies and accounts', () {
    const insurance = 40, savings = 41, fund = 42, trip = 43;
    final usd = acct(
      insurance,
      'Car insurance',
      AccountType.expense,
      currency: Currency.usd,
    );

    test('a dollar category draws on the dollar accounts', () {
      final d = ledger(
        more: [usd],
        amounts: [
          put(insurance, oct.start, 12000),
          put(food, oct.start, 90000000),
        ],
        rows: [
          move(
            DateTime(2026, 10, 9),
            dollars,
            insurance,
            9000,
            currency: Currency.usd,
          ),
        ],
      );
      final o = of(d, oct);
      final l = o.lines[insurance]!;
      expect(l.currency, Currency.usd);
      expect((l.assigned, l.spent, l.left), (12000, 9000, 3000));
      // Two pools, never added together: $2,500 less the $90 paid, less
      // the $30 still in the category.
      expect(o.pools.map((p) => p.currency), [Currency.mnt, Currency.usd]);
      expect(o.pools[1].money, 250000 - 9000);
      expect(o.pools[1].notAssigned, 250000 - 9000 - 3000);
      expect(o.notAssigned, 540000000 - 90000000);
    });

    test('a row in the other currency is named, not counted', () {
      final d = ledger(
        more: [usd],
        amounts: [put(insurance, oct.start, 12000)],
        rows: [move(DateTime(2026, 10, 9), checking, insurance, 30000000)],
      );
      final l = of(d, oct).lines[insurance]!;
      expect((l.spent, l.left), (0, 12000));
      expect(
        (l.otherRows, l.otherAmount, l.otherCurrency),
        (1, 30000000, Currency.mnt),
      );
      // Nothing of the kind on a line in its own currency.
      expect(of(d, oct).lines[food]!.otherRows, 0);
    });

    test('with only tugrik there is one pool', () {
      final o = of(
        LedgerData(
          accounts: [
            acct(checking, 'Checking', AccountType.asset),
            acct(food, 'Groceries', AccountType.expense),
          ],
          txns: const [],
        ),
        oct,
      );
      expect(o.pools.single.currency, Currency.mnt);
    });

    test('paid from an account it does not use: counted, and named', () {
      final d = ledger(
        more: [acct(savings, 'Savings', AccountType.asset)],
        off: {
          food: {savings},
        },
        amounts: [put(food, oct.start, 90000000)],
        rows: [
          move(DateTime(2026, 8, 1), opening, savings, 100000000),
          move(DateTime(2026, 10, 3), checking, food, 10000000),
          move(DateTime(2026, 10, 4), savings, food, 5000000),
        ],
      );
      final l = of(d, oct).lines[food]!;
      expect(l.spent, 15000000);
      expect(l.offSpent, 5000000);
      expect(l.offAccounts, [savings]);
      expect(l.backing, isNull);
      // The money moved there from an account it does use: nothing to say.
      final covered = ledger(
        more: [acct(savings, 'Savings', AccountType.asset)],
        off: {
          food: {savings},
        },
        amounts: [put(food, oct.start, 90000000)],
        rows: [
          move(DateTime(2026, 10, 2), checking, savings, 5000000),
          move(DateTime(2026, 10, 4), savings, food, 5000000),
        ],
      );
      expect(of(covered, oct).lines[food]!.offSpent, 0);
      // A refund into it isn't a payment from it.
      final refund = ledger(
        more: [acct(savings, 'Savings', AccountType.asset)],
        off: {
          food: {savings},
        },
        amounts: [put(food, oct.start, 90000000)],
        rows: [move(DateTime(2026, 10, 4), food, savings, 500000)],
      );
      expect(of(refund, oct).lines[food]!.offSpent, 0);
    });

    test('dollars assigned first don\'t start the tugrik budget', () {
      // Only Car insurance's $120 is assigned, in October: its own start.
      final d = ledger(
        more: [usd],
        amounts: [put(insurance, oct.start, 12000)],
        prefs: {BudgetKeys.beganIn(Currency.usd): '2026-10-01'},
        rows: [move(DateTime(2026, 10, 3), checking, food, 27665050)],
      );
      final o = of(d, oct);
      // Tugrik hasn't begun: Groceries' spending counts against nothing.
      expect(o.began, isNull);
      expect(o.lines[food]!.left, 0);
      expect(o.lines[food]!.spent, 27665050);
      expect(o.lines[insurance]!.left, 12000);
    });

    test('changed to dollars, it counts from that period on', () {
      final rows = [
        move(
          DateTime(2026, 9, 9),
          dollars,
          insurance,
          60000,
          currency: Currency.usd,
        ),
        move(
          DateTime(2026, 10, 9),
          dollars,
          insurance,
          9000,
          currency: Currency.usd,
        ),
      ];
      final amounts = [put(food, DateTime(2026, 9, 1), 90000000)];
      // A ledger from before each currency had its own day: the budget's
      // counts for dollars too.
      const began = {BudgetKeys.began: '2026-09-01'};
      // Without a day of its own, September's $600 would count.
      expect(
        of(
          ledger(more: [usd], amounts: amounts, rows: rows, prefs: began),
          oct,
        ).lines[insurance]!.left,
        -69000,
      );
      final o = of(
        ledger(
          more: [usd],
          amounts: amounts,
          rows: rows,
          prefs: {...began, '${BudgetKeys.fromPrefix}$insurance': '2026-10-01'},
        ),
        oct,
      );
      expect(o.lines[insurance]!.left, -9000);
      // What's there, less what the lines with money hold: the $90 over
      // was spent from it, and is said, not taken off again.
      expect(o.pools[1].notAssigned, o.pools[1].money);
      expect(o.pools[1].overspent, 9000);
    });

    test('a category that uses only the card: planned for the Visa', () {
      // Checking unchecked, the Visa left: nothing to say about where its
      // money is kept, and a card purchase is its own account's.
      final d = ledger(
        off: {
          food: {checking},
        },
        amounts: [put(food, oct.start, 90000000)],
        rows: [
          move(DateTime(2026, 10, 3), visa, food, 10000000),
          move(DateTime(2026, 10, 6), checking, food, 2000000),
        ],
      );
      final l = of(d, oct).lines[food]!;
      expect(l.spent, 12000000);
      expect(l.backing, isNull);
      // Only what checking paid is named.
      expect(l.offSpent, 2000000);
      expect(l.offAccounts, [checking]);
    });

    test('paid on an unchecked card, then the card paid from its account', () {
      final rows = [move(DateTime(2026, 10, 3), visa, food, 10000000)];
      final off = {
        food: {visa},
      };
      final amounts = [put(food, oct.start, 90000000)];
      var l = of(
        ledger(off: off, amounts: amounts, rows: rows),
        oct,
      ).lines[food]!;
      expect((l.offSpent, l.spent), (10000000, 10000000));
      l = of(
        ledger(
          off: off,
          amounts: amounts,
          rows: [
            ...rows,
            move(DateTime(2026, 10, 9), checking, visa, 10000000),
          ],
        ),
        oct,
      ).lines[food]!;
      expect(l.offSpent, 0);
    });

    test('an unchecked account since archived limits nothing', () {
      final d = ledger(
        more: [
          AccountInfo(
            id: savings,
            name: 'Savings',
            type: AccountType.asset,
            archived: true,
          ),
        ],
        off: {
          food: {savings},
        },
        amounts: [put(food, oct.start, 600000000)],
      );
      // More than checking holds, and still no word about its accounts.
      expect(of(d, oct).lines[food]!.backing, isNull);
    });

    test('an overspent neighbour does not hide a shortfall', () {
      final d = ledger(
        more: [
          acct(savings, 'Savings', AccountType.asset),
          acct(fund, 'Emergency', AccountType.expense),
          acct(trip, 'Trip', AccountType.expense),
        ],
        off: {
          fund: {checking},
          trip: {checking},
        },
        amounts: [put(fund, oct.start, 100000000)],
        rows: [
          move(DateTime(2026, 8, 1), opening, savings, 60000000),
          move(DateTime(2026, 10, 5), checking, trip, 50000000),
        ],
      );
      expect(of(d, oct).lines[fund]!.backing, (
        setAside: 100000000,
        categories: 1,
        have: 60000000,
      ));
    });

    test('a row in the other currency stays named until it is fixed', () {
      final d = ledger(
        more: [usd],
        amounts: [put(insurance, oct.start, 12000)],
        rows: [move(DateTime(2026, 10, 9), checking, insurance, 30000000)],
      );
      expect(of(d, nov).lines[insurance]!.otherRows, 1);
    });

    test('money in still in Not categorized is said, not counted (#182)', () {
      final d = ledger(
        rows: [
          move(DateTime(2026, 10, 10), waiting, checking, 250000000),
          move(DateTime(2026, 10, 12), salary, checking, 100000000),
          // Money out of it isn't money in.
          move(DateTime(2026, 10, 13), checking, waiting, 500000),
        ],
      );
      final o = of(d, oct);
      expect(o.cameInUncategorized, {Currency.mnt: 250000000});
      expect(o.cameIn[salary], {Currency.mnt: 100000000});
      expect(of(d, nov).cameInUncategorized, isEmpty);
    });

    test('pay in dollars came in, in dollars', () {
      final d = ledger(
        rows: [
          move(
            DateTime(2026, 10, 10),
            salary,
            dollars,
            300000,
            currency: Currency.usd,
          ),
        ],
      );
      expect(of(d, oct).cameIn[salary], {Currency.usd: 300000});
    });

    test('its accounts hold less than is set aside from them', () {
      // An emergency fund kept in Savings alone: ₮1,000,000 there.
      final d = ledger(
        more: [
          acct(savings, 'Savings', AccountType.asset),
          acct(fund, 'Emergency', AccountType.expense),
          acct(trip, 'Trip', AccountType.expense),
        ],
        off: {
          fund: {checking, visa},
          trip: {checking, visa},
        },
        amounts: [
          put(fund, oct.start, 80000000),
          put(trip, oct.start, 30000000),
        ],
        rows: [move(DateTime(2026, 8, 1), opening, savings, 100000000)],
      );
      final o = of(d, oct);
      // The two share Savings: ₮1,100,000 set aside from ₮1,000,000.
      expect(o.lines[fund]!.backing, (
        setAside: 110000000,
        categories: 2,
        have: 100000000,
      ));
      expect(o.lines[trip]!.backing, (
        setAside: 110000000,
        categories: 2,
        have: 100000000,
      ));
      expect(o.lines[food]!.backing, isNull);
      // Within what Savings holds: nothing to say.
      final ok = of(
        ledger(
          more: [
            acct(savings, 'Savings', AccountType.asset),
            acct(fund, 'Emergency', AccountType.expense),
          ],
          off: {
            fund: {checking, visa},
          },
          amounts: [put(fund, oct.start, 80000000)],
          rows: [move(DateTime(2026, 8, 1), opening, savings, 100000000)],
        ),
        oct,
      );
      expect(ok.lines[fund]!.backing, isNull);
    });
  });

  group('database', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('setting an amount replaces it, undo puts it back', () async {
      final food = await db.createCategory('Groceries');
      await db.setBudgetAmount(food, oct.start, oct.end, 90000000);
      final before = await db.setBudgetAmount(
        food,
        oct.start,
        oct.end,
        95000000,
      );
      expect(before.single.amount, 90000000);
      var d = await db.loadLedger();
      expect(d.budgetAmounts.single.amount, 95000000);
      await db.restoreBudgetAmounts(food, oct.start, oct.end, before);
      d = await db.loadLedger();
      expect(d.budgetAmounts.single.amount, 90000000);
      // Zero clears it.
      await db.setBudgetAmount(food, oct.start, oct.end, 0);
      expect((await db.loadLedger()).budgetAmounts, isEmpty);
    });

    test('an amount anywhere in the period is replaced or cleared', () async {
      final food = await db.createCategory('Groceries');
      // Assigned by month, then viewed by a pay period 09.25–10.09.
      await db.setBudgetAmount(food, oct.start, oct.end, 50000000);
      final p = (start: DateTime(2026, 9, 25), end: DateTime(2026, 10, 9));
      final before = await db.setBudgetAmount(food, p.start, p.end, 30000000);
      var d = await db.loadLedger();
      expect(d.budgetAmounts.single.amount, 30000000);
      expect(d.budgetAmounts.single.date, p.start);
      // Undo puts the old one back on its own day.
      await db.restoreBudgetAmounts(food, p.start, p.end, before);
      d = await db.loadLedger();
      expect(d.budgetAmounts.single.date, oct.start);
      await db.setBudgetAmount(food, p.start, p.end, 0);
      expect((await db.loadLedger()).budgetAmounts, isEmpty);
    });

    test(
      'starting next period moves the amounts, undo moves them back',
      () async {
        final food = await db.createCategory('Groceries');
        await db.setBudgetAmount(food, oct.start, oct.end, 50000000);
        final moved = await db.moveBudgetAmounts(oct.start, oct.end, nov.start);
        expect((await db.loadLedger()).budgetAmounts.single.date, nov.start);
        await db.unmoveBudgetAmounts(moved);
        expect((await db.loadLedger()).budgetAmounts.single.date, oct.start);
      },
    );

    test('a plan is kept, replaced and taken away', () async {
      final food = await db.createCategory('Groceries');
      final plan = CategoryPlan(
        categoryId: food,
        kind: PlanKind.byDate,
        amount: 120000000,
        start: DateTime(2026, 10, 5),
        due: DateTime(2027, 3, 15),
        everyMonths: 12,
      );
      expect(await db.setCategoryPlan(food, plan), isNull);
      expect((await db.loadLedger()).plans[food], plan);
      final other = CategoryPlan(
        categoryId: food,
        kind: PlanKind.each,
        amount: 90000000,
        start: DateTime(2026, 10, 6),
        rollover: false,
      );
      expect(await db.setCategoryPlan(food, other), plan);
      expect((await db.loadLedger()).plans[food], other);
      expect(await db.setCategoryPlan(food, null), other);
      expect((await db.loadLedger()).plans, isEmpty);
      // A new ledger clears them, and the category can go afterwards.
      await db.setCategoryPlan(food, plan);
      await db.startNewLedger(today, keepCategories: false);
      expect((await db.loadLedger()).plans, isEmpty);
    });

    test(
      'a card’s payment bill is scheduled as a transfer to the card',
      () async {
        final payment = await db.createCategory('Visa payment');
        final bank = await db.addAccount(name: 'Bank', type: AccountType.asset);
        final card = await db.addAccount(
          name: 'Visa',
          type: AccountType.liability,
        );
        await db.setPreference('${BudgetKeys.loanPrefix}$card', '$payment');
        await db.setCategoryPlan(
          payment,
          CategoryPlan(
            categoryId: payment,
            kind: PlanKind.byDate,
            amount: 64020000,
            start: today,
            due: DateTime(2027, 1, 10),
            everyMonths: 1,
            paidFrom: bank,
          ),
        );
        await db.ensurePlanBills(today);
        final bill = (await db.loadLedger()).txns.singleWhere(
          (x) => x.planCategoryId == payment && x.scheduled,
        );
        expect(
          {for (final e in bill.entries) e.accountId: e.amount},
          {bank: -64020000, card: 64020000},
        );
      },
    );

    test(
      'a dated plan paid from an account keeps its bill scheduled',
      () async {
        final fee = await db.createCategory('СӨХ');
        final bank = await db.addAccount(name: 'Bank', type: AccountType.asset);
        CategoryPlan plan({int amount = 27000000, bool paid = true}) =>
            CategoryPlan(
              categoryId: fee,
              kind: PlanKind.byDate,
              amount: amount,
              start: today,
              due: DateTime(2027, 1, 10),
              everyMonths: 3,
              paidFrom: paid ? bank : null,
            );
        Future<List<TxnData>> coming() async => (await db.loadLedger()).txns
            .where((x) => x.planCategoryId == fee && x.scheduled)
            .toList();
        await db.setCategoryPlan(fee, plan());
        expect(await db.ensurePlanBills(today), hasLength(1));
        var bill = (await coming()).single;
        expect(bill.date, DateTime(2027, 1, 10));
        expect(
          bill.entries.singleWhere((e) => e.accountId == bank).amount,
          -27000000,
        );
        // Named by its category in the register.
        final d = await db.loadLedger();
        expect(d.registerFor(bank).scheduled.single.payee, 'СӨХ');
        // Asked again, nothing more. Confirmed early, the next is scheduled.
        expect(await db.ensurePlanBills(today), isEmpty);
        final jan8 = DateTime(2027, 1, 8);
        await db.editTransaction(
          transactionId: bill.id,
          accountId: bank,
          date: jan8,
          today: jan8,
          confirm: true,
        );
        final next = await db.ensurePlanBills(jan8, only: fee);
        expect(next, hasLength(1));
        expect((await coming()).single.date, DateTime(2027, 4, 10));
        // Undoing the confirm takes it away; redo brings it back.
        await db.dropPlanBills(next);
        expect(await coming(), isEmpty);
        await db.bringBackPlanBills(next, fee);
        expect(await coming(), hasLength(1));
        // A changed bill starts over: the scheduled one goes, a new one comes.
        await db.setCategoryPlan(fee, plan(amount: 30000000));
        await db.ensurePlanBills(jan8, only: fee);
        bill = (await coming()).single;
        expect(
          bill.entries.singleWhere((e) => e.accountId == bank).amount,
          -30000000,
        );
        // With no account, nothing is scheduled; the confirmed one stays.
        await db.setCategoryPlan(fee, plan(paid: false));
        await db.ensurePlanBills(jan8, only: fee);
        expect(await coming(), isEmpty);
        expect(
          (await db.loadLedger()).txns.where(
            (x) => x.planCategoryId == fee && !x.scheduled,
          ),
          hasLength(1),
        );
      },
    );

    test('a bill confirmed as a split is that bill while a line is in its category', () async {
      final fee = await db.createCategory('СӨХ');
      final repairs = await db.createCategory('Repairs');
      final gifts = await db.createCategory('Gifts');
      final bank = await db.addAccount(name: 'Bank', type: AccountType.asset);
      await db.setCategoryPlan(
        fee,
        CategoryPlan(
          categoryId: fee,
          kind: PlanKind.byDate,
          amount: 27000000,
          start: today,
          due: DateTime(2027, 1, 10),
          everyMonths: 3,
          paidFrom: bank,
        ),
      );
      await db.ensurePlanBills(today);
      Future<List<TxnData>> coming() async => (await db.loadLedger()).txns
          .where((x) => x.planCategoryId == fee && x.scheduled)
          .toList();
      final bill = (await coming()).single;
      final jan8 = DateTime(2027, 1, 8);
      // Confirmed as the fee and a repair on one payment.
      await db.editTransaction(
        transactionId: bill.id,
        accountId: bank,
        date: jan8,
        today: jan8,
        confirm: true,
        amount: -30000000,
        splits: [
          (categoryId: fee, amount: -27000000),
          (categoryId: repairs, amount: -3000000),
        ],
      );
      RegisterRow row(LedgerData d) =>
          d.registerFor(bank).posted.singleWhere((r) => r.txnId == bill.id);
      expect(row(await db.loadLedger()).planCategoryId, fee);
      // It counts as January's bill: the next is April's.
      final next = await db.ensurePlanBills(jan8, only: fee);
      expect(next, hasLength(1));
      expect((await coming()).single.date, DateTime(2027, 4, 10));

      // Its fee line moved elsewhere: it's no longer the bill.
      await db.editTransaction(
        transactionId: bill.id,
        accountId: bank,
        date: jan8,
        today: jan8,
        splits: [
          (categoryId: gifts, amount: -27000000),
          (categoryId: repairs, amount: -3000000),
        ],
      );
      final d = await db.loadLedger();
      expect(row(d).planCategoryId, isNull);
      // So January's bill is still to pay, once April's is out of the way.
      await db.dropPlanBills(next);
      final again = await db.ensurePlanBills(jan8, only: fee);
      expect(again, hasLength(1));
      expect((await coming()).single.date, DateTime(2027, 1, 10));
    });

    test('a plan change brings back the very bill undo took away', () async {
      final fee = await db.createCategory('СӨХ');
      final bank = await db.addAccount(name: 'Bank', type: AccountType.asset);
      CategoryPlan plan(int amount) => CategoryPlan(
        categoryId: fee,
        kind: PlanKind.byDate,
        amount: amount,
        start: today,
        due: DateTime(2027, 1, 10),
        everyMonths: 3,
        paidFrom: bank,
      );
      Future<List<TxnData>> coming() async => (await db.loadLedger()).txns
          .where((x) => x.planCategoryId == fee && x.scheduled)
          .toList();
      final first = await db.changeCategoryPlan(fee, plan(27000000), today);
      expect(first.before, isNull);
      expect(first.removed, isEmpty);
      final x = first.made.single;
      // The user types on the scheduled row; a changed amount replaces it.
      await db.editTransaction(
        transactionId: x,
        accountId: bank,
        date: DateTime(2027, 1, 10),
        today: today,
        memo: 'winter rate',
      );
      final second = await db.changeCategoryPlan(fee, plan(30000000), today);
      expect(second.removed, [x]);
      final y = second.made.single;
      expect((await coming()).single.id, y);
      // Undo: the same row, memo and all; redo: the new one again.
      await db.undoPlanChange(fee, second);
      var rows = await coming();
      expect((rows.single.id, rows.single.memo), (x, 'winter rate'));
      expect((await db.loadLedger()).plans[fee]!.amount, 27000000);
      await db.redoPlanChange(fee, plan(30000000), second);
      rows = await coming();
      expect(rows.single.id, y);
      expect((await db.loadLedger()).plans[fee]!.amount, 30000000);
    });

    test(
      'a one-time plan given a new date reaches the forecast again',
      () async {
        // Tuition $2,000 on 01.15, paid; then $1,800 on 08.20.
        final tuition = await db.createCategory('Tuition');
        final bank = await db.addAccount(name: 'Bank', type: AccountType.asset);
        final jan = DateTime(2027, 1, 15);
        await db.setCategoryPlan(
          tuition,
          CategoryPlan(
            categoryId: tuition,
            kind: PlanKind.byDate,
            amount: 200000000,
            start: today,
            due: jan,
            paidFrom: bank,
          ),
        );
        final made = await db.ensurePlanBills(today);
        await db.editTransaction(
          transactionId: made.single,
          accountId: bank,
          date: jan,
          today: jan,
          confirm: true,
        );
        expect(await db.ensurePlanBills(jan), isEmpty);
        await db.setCategoryPlan(
          tuition,
          CategoryPlan(
            categoryId: tuition,
            kind: PlanKind.byDate,
            amount: 180000000,
            start: DateTime(2027, 1, 16),
            due: DateTime(2027, 8, 20),
            paidFrom: bank,
          ),
        );
        final next = await db.ensurePlanBills(DateTime(2027, 1, 16));
        expect(next, hasLength(1));
        final row = (await db.loadLedger()).txns.singleWhere(
          (x) => x.id == next.single,
        );
        expect((row.date, row.scheduled), (DateTime(2027, 8, 20), true));
      },
    );

    test('a bill every payday is scheduled on the paydays', () async {
      final loan = await db.createCategory('Loan');
      final bank = await db.addAccount(name: 'Bank', type: AccountType.asset);
      final pay = await db.savePaySchedule(
        accountId: bank,
        amount: 210000000,
        rule: PayRule.monthly,
        day1: 25,
        today: today,
      );
      await db.setCategoryPlan(
        loan,
        CategoryPlan(
          categoryId: loan,
          kind: PlanKind.byDate,
          amount: 15000000,
          start: today,
          payScheduleId: pay.after.id,
          daysAfterPay: 1,
          paidFrom: bank,
        ),
      );
      final made = await db.ensurePlanBills(today);
      expect(made, hasLength(1));
      final row = (await db.loadLedger()).txns.singleWhere(
        (x) => x.id == made.single,
      );
      // The day after the 10.25 payday (a Sunday, moved before: 10.23).
      expect(row.date, DateTime(2026, 10, 24));
    });

    test('an amount wanted once is scheduled once', () async {
      final gift = await db.createCategory('Birthday');
      final bank = await db.addAccount(name: 'Bank', type: AccountType.asset);
      await db.setCategoryPlan(
        gift,
        CategoryPlan(
          categoryId: gift,
          kind: PlanKind.byDate,
          amount: 10000000,
          start: today,
          due: DateTime(2027, 8, 20),
          paidFrom: bank,
        ),
      );
      final made = await db.ensurePlanBills(today);
      expect(made, hasLength(1));
      // Deleted by the user: skipped, it doesn't come back.
      await db.softDeleteMany(made);
      expect(await db.ensurePlanBills(today), isEmpty);
      // A date already gone isn't scheduled.
      final past = await db.createCategory('Was due');
      await db.setCategoryPlan(
        past,
        CategoryPlan(
          categoryId: past,
          kind: PlanKind.byDate,
          amount: 10000000,
          start: today,
          due: DateTime(2026, 9, 1),
          paidFrom: bank,
        ),
      );
      expect(await db.ensurePlanBills(today), isEmpty);
    });

    test(
      'a plan stays with a deleted category; starting over erases it',
      () async {
        final food = await db.createCategory('Groceries');
        final plan = CategoryPlan(
          categoryId: food,
          kind: PlanKind.each,
          amount: 90000000,
          start: DateTime(2026, 10, 5),
        );
        await db.setCategoryPlan(food, plan);
        final gone = await db.deleteCategory(food);
        // Gone from the budget, kept for undo.
        var d = await db.loadLedger();
        expect(
          Budget.of(
            d,
            start: oct.start,
            end: oct.end,
            today: today,
          ).lines[food],
          isNull,
        );
        await db.undeleteCategory(gone);
        d = await db.loadLedger();
        expect(
          Budget.of(
            d,
            start: oct.start,
            end: oct.end,
            today: today,
          ).lines[food]!.plan!.planned,
          90000000,
        );
        await db.startNewLedger(today, keepCategories: true);
        d = await db.loadLedger();
        expect(d.plans, isEmpty);
        expect(d.categories.map((c) => c.name), contains('Groceries'));
      },
    );

    test('a category’s currency and accounts, and back', () async {
      final food = await db.createCategory('Groceries');
      final bank = await db.addAccount(name: 'Bank', type: AccountType.asset);
      await db.setBudgetAmount(food, oct.start, oct.end, 90000000);
      final plan = CategoryPlan(
        categoryId: food,
        kind: PlanKind.each,
        amount: 90000000,
        start: DateTime(2026, 10, 5),
      );
      await db.setCategoryPlan(food, plan);
      // Unchecking an account keeps the amounts and the plan.
      var before = await db.setCategoryMoney(
        food,
        currency: Currency.mnt,
        off: {bank},
      );
      var d = await db.loadLedger();
      expect(d.accountsOff[food], {bank});
      expect(d.budgetAmounts, hasLength(1));
      expect(before.off, isEmpty);
      // A change of currency takes both away; undo brings them back.
      before = await db.setCategoryMoney(
        food,
        currency: Currency.usd,
        off: const {},
      );
      d = await db.loadLedger();
      expect(d.accounts[food]!.currency, Currency.usd);
      expect(d.budgetAmounts, isEmpty);
      expect(d.plans, isEmpty);
      expect(d.accountsOff, isEmpty);
      await db.restoreCategoryMoney(food, before);
      d = await db.loadLedger();
      expect(d.accounts[food]!.currency, Currency.mnt);
      expect(d.budgetAmounts.single.amount, 90000000);
      expect(d.plans[food], plan);
      expect(d.accountsOff[food], {bank});
      // A new bank account starts unchecked on a category already
      // narrowed, and checked on the rest.
      final other = await db.createCategory('Fun');
      final next = await db.createAccount(
        name: 'Golomt',
        type: AccountType.asset,
      );
      d = await db.loadLedger();
      expect(d.accountsOff[food], {bank, next});
      expect(d.accountsOff[other], isNull);
      // Merged into a category in the other currency, its amounts don't
      // become that currency's: they go back to not assigned.
      final usd = await db.createCategory('Fun US', currency: Currency.usd);
      final gone = await db.deleteCategory(food, into: usd);
      d = await db.loadLedger();
      expect(
        Budget.of(
          d,
          start: oct.start,
          end: oct.end,
          today: today,
        ).lines[usd]!.assigned,
        0,
      );
      await db.undeleteCategory(gone);
      d = await db.loadLedger();
      expect(
        Budget.of(
          d,
          start: oct.start,
          end: oct.end,
          today: today,
        ).lines[food]!.assigned,
        90000000,
      );
      // A new category is made in the currency asked for.
      final ins = await db.createCategory('Insurance', currency: Currency.usd);
      expect((await db.loadLedger()).accounts[ins]!.currency, Currency.usd);
      await db.startNewLedger(today, keepCategories: true);
      expect((await db.loadLedger()).accountsOff, isEmpty);
    });

    test('several amounts in one write, and back', () async {
      final food = await db.createCategory('Groceries');
      final fun = await db.createCategory('Fun');
      await db.setBudgetAmount(food, oct.start, oct.end, 50000000);
      final before = await db.setBudgetAmounts(
        {
          food: [(date: oct.start, amount: 90000000)],
          fun: [(date: oct.start, amount: 10000000)],
        },
        oct.start,
        oct.end,
      );
      var d = await db.loadLedger();
      expect(
        {for (final b in d.budgetAmounts) b.categoryId: b.amount},
        {food: 90000000, fun: 10000000},
      );
      await db.restoreBudgetAmountsOf(before, oct.start, oct.end);
      d = await db.loadLedger();
      expect(
        {for (final b in d.budgetAmounts) b.categoryId: b.amount},
        {food: 50000000},
      );
      // Rows dated in the span, one per own period, keep their dates;
      // one outside the span is refused.
      await db.setBudgetAmount(
        food,
        oct.start,
        oct.end,
        0,
        rows: [
          (date: DateTime(2026, 10, 9), amount: 20000000),
          (date: DateTime(2026, 10, 23), amount: 12860000),
        ],
      );
      d = await db.loadLedger();
      expect(
        [
          for (final b in d.budgetAmounts)
            if (b.categoryId == food) (b.date, b.amount),
        ],
        [(DateTime(2026, 10, 9), 20000000), (DateTime(2026, 10, 23), 12860000)],
      );
      await expectLater(
        db.setBudgetAmount(
          food,
          oct.start,
          oct.end,
          0,
          rows: [(date: DateTime(2026, 11, 1), amount: 1)],
        ),
        throwsArgumentError,
      );
    });

    test('a new ledger clears the amounts', () async {
      final food = await db.createCategory('Groceries');
      await db.setBudgetAmount(food, oct.start, oct.end, 50000000);
      await db.startNewLedger(today, keepCategories: true);
      expect((await db.loadLedger()).budgetAmounts, isEmpty);
    });

    test('a merge moves the amounts, undo moves them back', () async {
      final food = await db.createCategory('Groceries');
      final snacks = await db.createCategory('Snacks');
      await db.setBudgetAmount(food, oct.start, oct.end, 90000000);
      await db.setBudgetAmount(snacks, oct.start, oct.end, 5000000);
      final gone = await db.deleteCategory(snacks, into: food);
      var d = await db.loadLedger();
      final o = Budget.of(d, start: oct.start, end: oct.end, today: today);
      expect(o.lines[food]!.assigned, 95000000);
      // Setting it again makes one amount of the two.
      final before = await db.setBudgetAmount(
        food,
        oct.start,
        oct.end,
        96000000,
      );
      expect(before, hasLength(2));
      await db.restoreBudgetAmounts(food, oct.start, oct.end, before);
      await db.undeleteCategory(gone);
      d = await db.loadLedger();
      final back = Budget.of(d, start: oct.start, end: oct.end, today: today);
      expect(back.lines[food]!.assigned, 90000000);
      expect(back.lines[snacks]!.assigned, 5000000);
    });
  });

  group('living on the income (#234)', () {
    const net = 40, school = 41, gifts = 42;
    const pay = PaySchedule(
      id: 1,
      categoryId: salary,
      accountId: checking,
      amount: 160000000,
      rule: PayRule.twiceMonthly,
      day1: 10,
      day2: 25,
      weekend: PayWeekend.keep,
    );
    CategoryPlan each(int category, int amount) => CategoryPlan(
      categoryId: category,
      kind: PlanKind.each,
      amount: amount,
      start: DateTime(2026, 10, 1),
    );
    LedgerData month({
      List<TxnData> more = const [],
      List<CategoryPlan> plans = const [],
      List<BudgetAmount> amounts = const [],
      List<PaySchedule> pays = const [pay],
    }) => ledger(
      pay: pays,
      more: [
        acct(
          net,
          'Safety net',
          AccountType.expense,
          role: AccountRole.emergencyFund,
        ),
        acct(school, 'School fees', AccountType.expense),
        acct(gifts, 'Cash box', AccountType.asset),
      ],
      plans: [
        each(food, 200000000),
        each(housing, 80000000),
        each(net, 25000000),
        ...plans,
      ],
      amounts: [
        put(food, oct.start, 100000000),
        put(dining, oct.start, 50000000),
        ...amounts,
      ],
      rows: [
        move(DateTime(2026, 10, 10), salary, checking, 160000000),
        move(DateTime(2026, 10, 12), checking, food, 120000000),
        move(DateTime(2026, 10, 13), checking, coffee, 10000000),
        move(DateTime(2026, 10, 14), checking, waiting, 5000000),
        ...more,
      ],
    );
    IncomeFit fit(
      LedgerData d, {
      ({DateTime start, DateTime end})? period,
      DateTime? on,
    }) {
      final p = period ?? oct;
      final day = on ?? today;
      final b = Budget.of(d, start: p.start, end: p.end, today: day);
      final fits = IncomeFit.of(
        d,
        b,
        d.categories.where((c) => !c.isIncome && !isUncategorized(c)),
        saved: {net},
        start: p.start,
        end: p.end,
        today: day,
        pay: periodPay(d, start: p.start, end: p.end, today: day),
      );
      expect(fits.map((f) => f.currency), [Currency.mnt]);
      return fits.single;
    }

    test('the month against its own income, not the balance', () {
      final f = fit(month());
      // ₮1,600,000 came on the 10th; the 25th's is still to come.
      expect(f.cameIn, 160000000);
      expect(f.toCome, 160000000);
      expect(f.income, 320000000);
      expect(f.sure, isTrue);
      // Groceries spent past what's assigned, Coffee with nothing in it,
      // and a row with no category: all spent.
      expect(f.spent, 120000000 + 10000000 + 5000000);
      // Groceries' plan past what it spent, Dining out's Assigned with no
      // plan, Housing's plan.
      expect(f.toSpend, 80000000 + 50000000 + 80000000);
      // Put aside counts against the income too (owner, 2026-10-27).
      expect(f.putAside, 25000000);
      expect(f.over, 370000000 - 320000000);
    });

    test('pay that came early still counts once', () {
      final f = fit(
        month(
          more: [move(DateTime(2026, 10, 19), salary, checking, 160000000)],
        ),
      );
      expect(f.cameIn, 320000000);
      expect(f.toCome, 0);
    });

    test('a gift into another account adds to the month', () {
      final f = fit(
        month(more: [move(DateTime(2026, 10, 12), salary, gifts, 50000000)]),
      );
      expect(f.cameIn, 210000000);
      expect(f.toCome, 160000000);
    });

    test('a payday gone by without its pay is not counted on', () {
      final late = fit(month(), on: DateTime(2026, 10, 28));
      expect(late.toCome, 0);
      expect(late.income, 160000000);
      // A month gone by expects nothing more.
      final sep = (start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30));
      expect(fit(month(), period: sep).toCome, 0);
    });

    test('a bill saved for over months counts its share when paid', () {
      final d = month(
        plans: [each(school, 10000000)],
        amounts: [
          for (var m = 2; m <= 10; m++)
            put(school, DateTime(2026, m, 1), 10000000),
        ],
        more: [move(DateTime(2026, 10, 15), checking, school, 90000000)],
      );
      final f = fit(d);
      // ₮900,000 paid, ₮800,000 of it saved before October.
      expect(f.spent, 120000000 + 10000000 + 5000000 + 10000000);
      expect(f.over, 370000000 + 10000000 - 320000000);
    });

    test('money already there, assigned past a plan, is not this month\'s', () {
      final f = fit(month(amounts: [put(net, oct.start, 500000000)]));
      expect(f.putAside, 25000000);
    });

    test('money in waiting for a category takes nothing off spending', () {
      final f = fit(
        month(
          more: [move(DateTime(2026, 10, 15), waiting, checking, 90000000)],
        ),
      );
      expect(f.spent, 120000000 + 10000000 + 5000000);
    });

    test('a loan paid with no category is spent; paying the card is not', () {
      final f = fit(
        month(
          more: [
            move(DateTime(2026, 10, 16), checking, mortgage, 30000000),
            move(DateTime(2026, 10, 17), checking, visa, 40000000),
          ],
        ),
      );
      expect(f.spent, 120000000 + 10000000 + 5000000 + 30000000);
    });

    test(
      'with no pay set up, a shortfall is not sure until the month ends',
      () {
        expect(fit(month(pays: const [])).sure, isFalse);
        final sep = (start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30));
        final gone = month(
          pays: const [],
          more: [move(DateTime(2026, 9, 10), salary, checking, 1000)],
        );
        expect(fit(gone, period: sep).sure, isTrue);
      },
    );
  });
}
