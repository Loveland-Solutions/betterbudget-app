import 'package:betterbudget/domain/goals.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/money.dart';
import 'package:betterbudget/domain/readiness.dart';
import 'package:betterbudget/ui/plan_form.dart';
import 'package:flutter_test/flutter_test.dart';

/// Goals on Savings (#101, #102): a once-only "On a date" line marked a
/// goal, counted by what was put toward it.
void main() {
  const checking = 1, wedding = 2, opening = 3;
  var nextId = 100;

  /// ₮12,000 wanted by 12.31, planned from September: four months of
  /// ₮3,000. [assigned] is what went in each month, by month number
  /// (13 is January 2027).
  LedgerData ledger({
    Map<int, int> assigned = const {},
    Map<String, String>? prefs,
    CategoryPlan? plan,
  }) => LedgerData(
    accounts: [
      AccountInfo(id: checking, name: 'Checking', type: AccountType.asset),
      AccountInfo(id: wedding, name: 'Wedding', type: AccountType.expense),
      AccountInfo(id: opening, name: 'Opening', type: AccountType.equity),
    ],
    txns: [
      TxnData(
        id: nextId++,
        date: DateTime(2026, 9),
        entries: [
          EntryData(id: nextId++, accountId: opening, amount: -10000000),
          EntryData(id: nextId++, accountId: checking, amount: 10000000),
        ],
      ),
    ],
    prefs: prefs ?? {ReadyKeys.goal(wedding): 'yes'},
    plans: [
      plan ??
          CategoryPlan(
            categoryId: wedding,
            kind: PlanKind.byDate,
            amount: 1200000,
            start: DateTime(2026, 9),
            due: DateTime(2026, 12, 31),
          ),
    ],
    budgetAmounts: [
      for (final MapEntry(key: m, value: v) in assigned.entries)
        BudgetAmount(categoryId: wedding, date: DateTime(2026, m), amount: v),
    ],
  );

  Goal goalOn(LedgerData data, DateTime today) =>
      goalsOf(data, monthBudget(data, today), today).single;

  test('kept up with: on track, asking its usual part', () {
    final g = goalOn(
      ledger(assigned: {9: 300000, 10: 300000}),
      DateTime(2026, 10, 16),
    );
    expect(g.saved, 600000);
    expect(g.usual, 300000);
    expect(g.asks, 300000);
    expect(g.behind, 0);
    expect(g.ready, isFalse);
    expect(g.late, isFalse);
  });

  test('a month missed: behind, the part rises, and when the usual ends', () {
    final g = goalOn(ledger(assigned: {9: 300000}), DateTime(2026, 11, 10));
    expect(g.behind, 300000);
    // ₮9,000 still to go over November and December.
    expect(g.asks, 450000);
    // At ₮3,000 a month from November: three months.
    expect(g.readyAtUsual, DateTime(2027, 1));
  });

  test('all put in: ready, nothing more asked', () {
    final g = goalOn(
      ledger(assigned: {9: 300000, 10: 900000}),
      DateTime(2026, 10, 20),
    );
    expect(g.ready, isTrue);
    expect(g.readyAtUsual, isNull);
  });

  test('spending on the thing itself is still saved toward it', () {
    final data = ledger(assigned: {9: 300000, 10: 300000});
    final paid = LedgerData(
      accounts: data.accounts.values.toList(),
      txns: [
        ...data.txns,
        TxnData(
          id: nextId++,
          date: DateTime(2026, 10, 5),
          entries: [
            EntryData(id: nextId++, accountId: checking, amount: -200000),
            EntryData(id: nextId++, accountId: wedding, amount: 200000),
          ],
        ),
      ],
      prefs: data.prefs,
      plans: data.plans.values.toList(),
      budgetAmounts: data.budgetAmounts,
    );
    final g = goalOn(paid, DateTime(2026, 10, 16));
    expect(g.saved, 600000);
    expect(g.behind, 0);
  });

  group('its date passed short', () {
    final late = DateTime(2027, 1, 10);

    test('keeps asking its usual part until the person picks', () {
      final data = ledger(assigned: {9: 300000});
      final g = goalOn(data, late);
      expect(g.late, isTrue);
      expect(g.askAll, isFalse);
      expect(g.asks, 300000);
      final line = monthBudget(data, late).lines[wedding]!;
      expect(line.plan!.late, isTrue);
      expect(line.short, 0);
    });

    test('asks for all of the rest when the person picks that', () {
      final data = ledger(
        assigned: {9: 300000},
        prefs: {
          ReadyKeys.goal(wedding): 'yes',
          ReadyKeys.goalLate(wedding): 'all',
        },
      );
      final g = goalOn(data, late);
      expect(g.askAll, isTrue);
      expect(g.asks, 900000);
    });

    test('a line that isn\'t a goal asks for all of it, as before', () {
      final data = ledger(assigned: {9: 300000}, prefs: const {});
      expect(goalsOf(data, monthBudget(data, late), late), isEmpty);
      final line = monthBudget(data, late).lines[wedding]!;
      expect(line.plan!.planned, 900000);
      expect(line.short, 900000);
    });
  });

  test('only an amount by one date is a goal', () {
    final repeating = ledger(
      plan: CategoryPlan(
        categoryId: wedding,
        kind: PlanKind.byDate,
        amount: 1200000,
        start: DateTime(2026, 9),
        due: DateTime(2026, 12, 31),
        everyMonths: 12,
      ),
    );
    expect(isGoal(repeating, wedding), isFalse);
    expect(isGoal(ledger(), wedding), isTrue);
    expect(isGoal(ledger(prefs: const {}), wedding), isFalse);
  });

  test('moving the date keeps its day where the month has it', () {
    final g = goalOn(ledger(assigned: {9: 300000}), DateTime(2026, 11, 10));
    expect(g.movedTo(DateTime(2027, 2)).due, DateTime(2027, 2, 28));
    expect(g.movedTo(DateTime(2027, 3)).due, DateTime(2027, 3, 31));
    expect(g.movedTo(DateTime(2027, 3)).amount, 1200000);
  });

  /// [ledger] with ₮[amount] spent from Wedding on [day].
  LedgerData spend(LedgerData data, DateTime day, int amount) => LedgerData(
    accounts: data.accounts.values.toList(),
    txns: [
      ...data.txns,
      TxnData(
        id: nextId++,
        date: day,
        entries: [
          EntryData(id: nextId++, accountId: checking, amount: -amount),
          EntryData(id: nextId++, accountId: wedding, amount: amount),
        ],
      ),
    ],
    prefs: data.prefs,
    plans: data.plans.values.toList(),
    budgetAmounts: data.budgetAmounts,
  );

  test('a category with a past, made a goal, counts only what it held', () {
    // Assigned and spent on repairs before the plan began in October.
    final before = spend(
      ledger(
        assigned: {7: 500000, 8: 500000},
        plan: CategoryPlan(
          categoryId: wedding,
          kind: PlanKind.byDate,
          amount: 1200000,
          start: DateTime(2026, 10),
          due: DateTime(2026, 12, 31),
        ),
      ),
      DateTime(2026, 8, 20),
      800000,
    );
    final g = goalOn(before, DateTime(2026, 10, 16));
    // ₮2,000 held when it began, not the ₮10,000 ever assigned.
    expect(g.saved, 200000);
    expect(g.ready, isFalse);
  });

  test('its date passed earlier this month: not late until next month', () {
    final data = ledger(
      assigned: {9: 300000},
      plan: CategoryPlan(
        categoryId: wedding,
        kind: PlanKind.byDate,
        amount: 1200000,
        start: DateTime(2026, 9),
        due: DateTime(2026, 10, 10),
      ),
    );
    final g = goalOn(data, DateTime(2026, 10, 20));
    expect(g.late, isFalse);
    // Budget asks the rest in its last month, and the card says so.
    expect(g.asks, 900000);
  });

  test('ready, past its date and spent: left off Savings', () {
    final data = spend(
      ledger(assigned: {9: 1200000}),
      DateTime(2026, 12, 20),
      1200000,
    );
    expect(
      goalsOf(
        data,
        monthBudget(data, DateTime(2027, 1, 5)),
        DateTime(2027, 1, 5),
      ),
      isEmpty,
    );
    // Still there while it holds money.
    final kept = ledger(assigned: {9: 1200000});
    expect(
      goalsOf(
        kept,
        monthBudget(kept, DateTime(2027, 1, 5)),
        DateTime(2027, 1, 5),
      ),
      hasLength(1),
    );
  });

  test('a goal\'s Edit keeps where it began through a new amount', () {
    final old = CategoryPlan(
      categoryId: wedding,
      kind: PlanKind.byDate,
      amount: 1200000,
      start: DateTime(2026, 9),
      due: DateTime(2026, 12, 31),
    );
    final p = PlanAnswers(today: DateTime(2026, 10, 16), currency: Currency.mnt)
      ..show(old);
    p.amount.text = '15000';
    expect(
      p.draft(categoryId: wedding, old: old, keepOnceStart: true)!.start,
      DateTime(2026, 9),
    );
    // A line that isn't a goal starts over, as before.
    expect(
      p.draft(categoryId: wedding, old: old)!.start,
      DateTime(2026, 10, 16),
    );
    p.dispose();
  });

  test('a date stays where it\'s typed (#342)', () {
    final today = DateTime(2026, 11, 2);
    final old = CategoryPlan(
      categoryId: wedding,
      kind: PlanKind.byDate,
      amount: 4000000,
      start: DateTime(2026, 9, 1),
      due: DateTime(2026, 9, 15),
      everyMonths: 1,
    );
    final p = PlanAnswers(today: today, currency: Currency.mnt)..show(old);

    // A monthly bill, typed for yesterday, with or without the year.
    for (final text in ['11.01', '2026.11.01', '11/01']) {
      p.date.text = text;
      expect(p.typedDate, DateTime(2026, 11, 1));
      final plan = p.draft(categoryId: wedding, old: old)!;
      expect(plan.due, DateTime(2026, 11, 1));
      expect(plan.start, today);
    }
    p.dispose();

    DateTime? read(String text, DateTime on) {
      final a = PlanAnswers(today: on, currency: Currency.mnt)
        ..hasDate = true
        ..date.text = text;
      final d = a.typedDate;
      a.dispose();
      return d;
    }

    // On these dates: one gone by this month stays; last month's is next
    // year's.
    final a = PlanAnswers(today: today, currency: Currency.mnt);
    expect(a.firstOfDates(const [(11, 1), (5, 1)]), DateTime(2026, 11, 1));
    expect(a.firstOfDates(const [(5, 1)]), DateTime(2027, 5, 1));
    a.dispose();

    // Once-only too, and with no year, this year's while that's near.
    expect(read('03.15', DateTime(2026, 10, 2)), DateTime(2026, 3, 15));
    expect(read('12.31', DateTime(2026, 1, 2)), DateTime(2026, 12, 31));
    // A new year's date typed in December is the one coming.
    expect(read('01.05', DateTime(2026, 12, 28)), DateTime(2027, 1, 5));
  });

  test('twice a month: two days, from this month, kept while they stay', () {
    PlanAnswers on(DateTime day) =>
        PlanAnswers(today: day, currency: Currency.mnt)..hasDate = true;

    final a = on(DateTime(2026, 11, 20))
      ..repeat = PlanRepeat.twice
      ..amount.text = '50000';
    expect(a.missing, PlanMissing.days);
    a.day1.text = '15';
    expect(a.missing, PlanMissing.days);
    a.day2.text = '15';
    expect(a.missing, PlanMissing.days, reason: 'one day, not two');
    a.day2.text = '32';
    expect(a.missing, PlanMissing.days, reason: 'not a day of a month');
    // Either order; one gone by this month stays there, like a date.
    a.day2.text = '1';
    expect(a.missing, isNull);
    final p = a.draft(categoryId: wedding)!;
    expect(p.monthDays, [1, 15]);
    expect(p.due, DateTime(2026, 11, 1));
    a.dispose();

    // Opened later and saved as it is: nothing about it changes.
    final later = on(DateTime(2026, 12, 20))..show(p);
    expect(later.repeat, PlanRepeat.twice);
    expect((later.day1.text, later.day2.text), ('1', '15'));
    expect(later.draft(categoryId: wedding, old: p), p);
    // Other days come from today on: this month's bills were the old
    // days'.
    later.day2.text = '25';
    final moved = later.draft(categoryId: wedding, old: p)!;
    expect(moved.monthDays, [1, 25]);
    expect(moved.due, DateTime(2026, 12, 25));
    expect(moved.start, DateTime(2026, 12, 20));
    later.day2.text = '10';
    expect(later.draft(categoryId: wedding, old: p)!.due, DateTime(2027, 1, 1));
    later.dispose();

    // Ends is asked, as for every other repeat by the month.
    final ending = on(DateTime(2027, 2, 2))
      ..repeat = PlanRepeat.twice
      ..amount.text = '50000'
      ..day1.text = '30'
      ..day2.text = '31'
      ..ends = PlanEnds.count;
    expect(ending.endsOn, isTrue);
    final q = ending.draft(categoryId: wedding)!;
    expect(q.endCount, 12);
    // A day past the month's end: its last.
    expect(q.due, DateTime(2027, 2, 28));
    ending.dispose();
  });

  test('a late goal marked done asks nothing more, and goes when spent', () {
    final late = DateTime(2027, 1, 10);
    final prefs = {
      ReadyKeys.goal(wedding): 'yes',
      ReadyKeys.goalLate(wedding): 'done',
    };
    final data = ledger(assigned: {9: 300000}, prefs: prefs);
    final g = goalOn(data, late);
    expect(g.finished, isTrue);
    expect(g.asks, 0);
    expect(g.left, 300000);
    final line = monthBudget(data, late).lines[wedding]!;
    expect(line.plan!.finished, isTrue);
    expect(line.short, 0);
    // Spent on the wedding: nothing left to say.
    final spent = spend(data, DateTime(2026, 12, 20), 300000);
    expect(goalsOf(spent, monthBudget(spent, late), late), isEmpty);
  });
}
