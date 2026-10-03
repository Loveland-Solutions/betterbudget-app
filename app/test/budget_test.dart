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
  }) => TxnData(
    id: nextId++,
    date: date,
    scheduled: scheduled,
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
    // 5,400,000 − 860,000; the mortgage and the dollars aren't counted.
    expect(b.money, 454000000);
    expect(b.notAssigned, 454000000 - 120000000);
    expect(b.lines[food]!.assigned, 90000000);
    expect(b.lines[food]!.left, 90000000);
    expect(b.began, oct.start);
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
    expect(after.notAssigned, before.notAssigned);

    // Paying the card moves nothing on the Budget page.
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
    expect(paid.notAssigned, after.notAssigned);
    expect(paid.lines[food]!.left, after.lines[food]!.left);
  });

  test('income adds to the money not given out', () {
    final b = of(
      ledger(rows: [move(DateTime(2026, 10, 10), salary, checking, 420000000)]),
      oct,
    );
    expect(b.cameIn[salary], {Currency.mnt: 420000000});
    expect(b.notAssigned, 454000000 + 420000000);
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
    // Coffee carries it as minus, so the money not given out doesn't move.
    expect(o.notAssigned, 454000000 - 90000000);
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
    expect(of(d, oct).notAssigned, 454000000 - 90000000);
  });

  test('a later period already given to counts now', () {
    final d = ledger(
      amounts: [put(food, oct.start, 90000000), put(food, nov.start, 90000000)],
    );
    expect(of(d, oct).lines[food]!.left, 90000000);
    expect(of(d, oct).notAssigned, 454000000 - 180000000);
  });

  test('a deleted category gives its money back', () {
    final d = ledger(
      amounts: [put(dining, oct.start, 15000000)],
      diningDeleted: true,
    );
    expect(of(d, oct).lines.containsKey(dining), isFalse);
    expect(of(d, oct).notAssigned, 454000000);
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
      expect(o.notAssigned, 454000000 - 18200000 - 90000000 - 100);
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
    expect(o.uncategorizedRows, 2);
    expect(o.uncategorizedNet, 247000000);
    expect(o.notAssigned, 454000000 + 247000000 - 90000000);
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
    expect(linked.notAssigned, 454000000 - 100000000 - 0);
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
    }) => CategoryPlan(
      categoryId: category,
      kind: kind,
      amount: amount,
      start: start ?? DateTime(2026, 10, 5),
      due: due,
      everyMonths: every,
      rollover: rollover,
    );

    test('spend and save up: the set amount each period', () {
      final d = ledger(
        plans: [
          plan(food, PlanKind.spend, 90000000),
          plan(xmas, PlanKind.saveUp, 5000000),
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
            PlanKind.spend,
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
      expect(o.money, 454000000 - 85800000 - 10000000);
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
            PlanKind.spend,
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

    test('carried over: the same category keeps what is left', () {
      final d = ledger(
        plans: [plan(food, PlanKind.spend, 90000000)],
        amounts: [put(food, sep.start, 90000000)],
        rows: [move(DateTime(2026, 9, 12), checking, food, 85800000)],
      );
      expect(of(d, oct).lines[food]!.fromBefore, 4200000);
    });

    test('a bill due on a date: equal parts up to it', () {
      final bill = plan(
        xmas,
        PlanKind.dueOn,
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

      // October's part in, November's skipped: December wants both, and
      // one of them is short.
      d = ledger(plans: [bill], amounts: [put(xmas, oct.start, 20000000)]);
      final dc = of(d, dec).lines[xmas]!;
      expect(dc.plan!.planned, 40000000);
      expect(dc.toAssign, 40000000);
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
      // More than the part one period: the next asks for less.
      d = ledger(plans: [bill], amounts: [put(xmas, oct.start, 30000000)]);
      expect(of(d, nov).lines[xmas]!.plan!.planned, 10000000);
      // Before the plan was made it asks for nothing.
      expect(of(d, sep).lines[xmas]!.plan!.planned, 0);
    });

    test('a bill: what the category held already counts toward it', () {
      final d = ledger(
        plans: [
          plan(xmas, PlanKind.dueOn, 120000000, due: DateTime(2027, 3, 15)),
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
            PlanKind.dueOn,
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
            PlanKind.dueOn,
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
        PlanKind.dueOn,
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

    test('a goal: each period follows what is left and the time left', () {
      final goal = plan(
        coffee,
        PlanKind.goal,
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
      // Reached.
      d = ledger(plans: [goal], amounts: [put(coffee, sep.start, 350000000)]);
      o = of(d, oct).lines[coffee]!;
      expect(o.plan!.done, isTrue);
      expect(o.toAssign, 0);
      // Its date gone: all of what's missing, and it's short.
      d = ledger(
        plans: [
          plan(coffee, PlanKind.goal, 5000000, due: DateTime(2026, 9, 30)),
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
          plan(xmas, PlanKind.dueOn, 6000000, due: DateTime(2026, 11, 30)),
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
            PlanKind.dueOn,
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
          plan(coffee, PlanKind.goal, 520000000, due: DateTime(2046, 10, 16)),
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

    test('a goal reached and then spent stays reached', () {
      final goal = plan(
        coffee,
        PlanKind.goal,
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
        plans: [plan(food, PlanKind.spend, 90000000, rollover: false)],
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
        PlanKind.dueOn,
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
            PlanKind.dueOn,
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

    test('on track only while the money is still there', () {
      final bill = plan(
        xmas,
        PlanKind.dueOn,
        120000000,
        due: DateTime(2027, 3, 15),
      );
      final amounts = [
        put(xmas, oct.start, 20000000),
        put(xmas, nov.start, 20000000),
      ];
      var n = of(ledger(plans: [bill], amounts: amounts), nov).lines[xmas]!;
      expect((n.toAssign, n.plan!.held), (0, true));
      // A repair filed under it: assigned, but not there any more.
      n = of(
        ledger(
          plans: [bill],
          amounts: amounts,
          rows: [move(DateTime(2026, 11, 3), checking, xmas, 30000000)],
        ),
        nov,
      ).lines[xmas]!;
      expect((n.toAssign, n.plan!.held), (0, false));
      // Paying the bill in the period it's due isn't that.
      final march = (start: DateTime(2027, 3, 1), end: DateTime(2027, 3, 31));
      final paid = ledger(
        plans: [bill],
        amounts: [
          for (var m = 10; m <= 15; m++)
            put(xmas, DateTime(2026, m, 1), 20000000),
        ],
        rows: [move(DateTime(2027, 3, 15), checking, xmas, 120000000)],
      );
      final m = of(paid, march).lines[xmas]!;
      expect((m.toAssign, m.plan!.held), (0, true));
    });

    test('the budget’s start moved on: a bill counts from there', () {
      // Made on 09.20, then "start the budget on 10.01 instead".
      final d = ledger(
        prefs: {BudgetKeys.began: '2026-10-01'},
        plans: [
          plan(
            xmas,
            PlanKind.dueOn,
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
      expect(o.notAssigned, 454000000 - 90000000);
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
      // Without a day of its own, September's $600 would count.
      expect(
        of(
          ledger(more: [usd], amounts: amounts, rows: rows),
          oct,
        ).lines[insurance]!.left,
        -69000,
      );
      final o = of(
        ledger(
          more: [usd],
          amounts: amounts,
          rows: rows,
          prefs: {'${BudgetKeys.fromPrefix}$insurance': '2026-10-01'},
        ),
        oct,
      );
      expect(o.lines[insurance]!.left, -9000);
      // The pool still adds up: what's there, less what the lines hold.
      expect(o.pools[1].notAssigned, o.pools[1].money + 9000);
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
        kind: PlanKind.dueOn,
        amount: 120000000,
        start: DateTime(2026, 10, 5),
        due: DateTime(2027, 3, 15),
        everyMonths: 12,
      );
      expect(await db.setCategoryPlan(food, plan), isNull);
      expect((await db.loadLedger()).plans[food], plan);
      final other = CategoryPlan(
        categoryId: food,
        kind: PlanKind.spend,
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
      'a plan stays with a deleted category; starting over erases it',
      () async {
        final food = await db.createCategory('Groceries');
        final plan = CategoryPlan(
          categoryId: food,
          kind: PlanKind.spend,
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
        kind: PlanKind.spend,
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
        {food: 90000000, fun: 10000000},
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
}
