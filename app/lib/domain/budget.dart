import 'ledger.dart';
import 'money.dart';
import 'pay.dart';
import 'readiness.dart' show mainCurrency;

/// The budget's envelopes (ADR 0004 rule 26). Each spending category keeps
/// its own balance from period to period, below zero too: every amount
/// assigned, less what it spent since the budget began. The money not
/// assigned is what the user has (cash and bank, less what cards owe) less
/// what sits in the categories, so a card purchase moves money from a
/// category and nothing else, and paying the card moves nothing.

/// The budget's settings, kept in preferences.
abstract final class BudgetKeys {
  /// `YYYY-MM-DD`: the day the budget began, set when the first amount is
  /// assigned. It never moves on its own; only the first-month offer or
  /// the user moves it.
  static const began = 'budget.began';

  /// The currency amounts are in, set with [began], so adding accounts in
  /// the other currency can't change what the amounts mean.
  static const currency = 'budget.currency';

  /// '1' once the first-month offer was answered with "Keep".
  static const keptStart = 'budget.keptStart';

  /// Prefix, then a mortgage or student loan's id: the spending category
  /// its payments come out of.
  static const loanPrefix = 'budget.loan.';
}

/// The category imported rows wait in, by the names the import gives it.
/// It holds no money: its rows count straight in the money not assigned
/// until they're categorized (owner's call, 2026-09-30).
const uncategorizedNames = {'Not categorized', 'Ангилаагүй'};

bool isUncategorized(AccountInfo a) =>
    a.type == AccountType.expense && uncategorizedNames.contains(a.name);

/// One spending category in one period.
class EnvelopeLine {
  const EnvelopeLine({
    required this.assigned,
    required this.spent,
    required this.left,
    required this.fromBefore,
    this.plan,
  });

  /// Assigned for this period.
  final int assigned;

  /// Spent in this period: positive is spending, a refund takes it down.
  final int spent;

  /// What the category holds at the period's end (today, for this one).
  final int left;

  /// What it held when the period began.
  final int fromBefore;

  /// Its plan worked out for this period, when it has one (rule 27).
  final PlanLine? plan;

  /// What its plan still wants assigned this period.
  int get toAssign {
    final p = plan;
    return p == null || p.planned <= assigned ? 0 : p.planned - assigned;
  }

  /// How much of [toAssign] should already have been in before this
  /// period: what "short" names.
  int get short {
    final p = plan;
    return p == null ? 0 : (toAssign < p.overdue ? toAssign : p.overdue);
  }
}

/// A category's plan in one period (rule 27).
class PlanLine {
  const PlanLine({
    required this.plan,
    required this.each,
    required this.planned,
    this.overdue = 0,
    this.due,
    this.done = false,
    this.wentBack = 0,
    this.waiting = false,
    this.held = true,
  });

  final CategoryPlan plan;

  /// What goes in each period: the set amount, a bill's equal part, or a
  /// goal's part worked out from what's left to save and the time left.
  /// 0 when nothing more is asked (a bill whose date passed, a goal
  /// reached, a period before the plan).
  final int each;

  /// What Assigned should come to this period: [each], plus whatever a
  /// bill is behind by, less whatever it is ahead by.
  final int planned;

  /// The part of [planned] that should have been in before this period:
  /// what "short" names. For a goal or a bill past its date, all of it.
  final int overdue;

  /// The bill's due date this period is saving for, or the goal's date.
  final DateTime? due;

  /// A bill that doesn't repeat whose date has passed, or a goal reached.
  final bool done;

  /// A period before the plan began: it asks for nothing yet.
  final bool waiting;

  /// A bill: the category holds what its parts so far come to. False when
  /// the money was assigned and then spent on something else, so "on
  /// track" would be untrue.
  final bool held;

  /// A category that doesn't carry over: what was left when the period
  /// before this one ended, which went back to the money not assigned.
  final int wentBack;
}

class Budget {
  Budget._({
    required this.currency,
    required this.began,
    required this.lines,
    required this.cameIn,
    required this.notAssigned,
    required this.money,
    required this.uncategorizedRows,
    required this.uncategorizedNet,
    required this.unassignedSpent,
  });

  final Currency currency;

  /// The day the budget began; null until an amount is assigned.
  final DateTime? began;

  /// Each spending category (archived ones included: money can still sit
  /// in one), for the period asked for. Not "Not categorized".
  final Map<int, EnvelopeLine> lines;

  /// Each income category: what came in during the period.
  final Map<int, int> cameIn;

  /// What the user has, less what's in the categories, as of today, with
  /// every amount assigned counted, a later period's too. Negative when
  /// more was assigned than there is, or cards owe more than there is.
  final int notAssigned;

  /// What [notAssigned] starts from: cash and bank, less what cards owe.
  final int money;

  /// Posted rows in "Not categorized", and what they add up to (negative:
  /// money out). Both already count in [notAssigned].
  final int uncategorizedRows;
  final int uncategorizedNet;

  /// This period's spending since the budget began in categories nothing
  /// was assigned to: what the first-month offer names.
  final ({int count, int amount}) unassignedSpent;

  /// Accounts whose balance counts as money to budget: cash, bank and
  /// cards. A mortgage or student loan is paid down over years, not out of
  /// this month's money, so it's left out (the line Savings draws too);
  /// its payments come out of the category it's paid from.
  static bool counts(AccountInfo a, Currency main) =>
      a.isBalanceSheet && !a.deleted && a.currency == main && !isLongLoan(a);

  static bool isLongLoan(AccountInfo a) =>
      a.role == AccountRole.mortgage || a.role == AccountRole.studentLoan;

  /// The currency the budget counts in.
  static Currency currencyOf(LedgerData data) =>
      switch (data.prefs[BudgetKeys.currency]) {
        final String code => Currency.fromCode(code),
        null => mainCurrency(data),
      };

  /// The spending category a long loan's payments come out of, if any.
  static int? loanCategory(LedgerData data, int loanId) =>
      int.tryParse(data.prefs['${BudgetKeys.loanPrefix}$loanId'] ?? '');

  /// The budget for the period [start]–[end], as of [today].
  static Budget of(
    LedgerData data, {
    required DateTime start,
    required DateTime end,
    required DateTime today,
  }) {
    final main = currencyOf(data);
    final s = dateOnly(start), e = dateOnly(end);
    bool within(DateTime d) => !d.isBefore(s) && !d.isAfter(e);

    // Spending categories that still exist; a deleted one's money goes
    // back to not assigned (a merge moved its amounts first).
    final envelopes = {
      for (final a in data.accounts.values)
        if (a.type == AccountType.expense && !a.deleted && !isUncategorized(a))
          a.id,
    };
    final uncategorized = {
      for (final a in data.accounts.values)
        if (!a.deleted && isUncategorized(a)) a.id,
    };
    // A long loan's payments are its category's spending.
    final loans = <int, int>{};
    for (final a in data.accounts.values) {
      if (a.deleted || !isLongLoan(a) || a.currency != main) continue;
      final c = loanCategory(data, a.id);
      if (c != null && envelopes.contains(c)) loans[a.id] = c;
    }

    final by = data.periodSchedule;
    final plans = {
      for (final p in data.plans.values)
        if (envelopes.contains(p.categoryId)) p.categoryId: p,
    };
    // Categories whose balance on a given day matters: one that doesn't
    // carry over is emptied at each period's end, and a bill or goal
    // starts from what the category held when its plan began.
    final dated = <int, List<({DateTime date, int amount})>>{
      for (final p in plans.values)
        if (p.kind != PlanKind.saveUp) p.categoryId: [],
    };

    DateTime? earliest;
    final assigned = <int, int>{}, assignedBy = <int, int>{};
    final assignedAll = <int, int>{};
    for (final b in data.budgetAmounts) {
      if (!envelopes.contains(b.categoryId)) continue;
      final d = dateOnly(b.date);
      dated[b.categoryId]?.add((date: d, amount: b.amount));
      if (earliest == null || d.isBefore(earliest)) earliest = d;
      assignedAll[b.categoryId] = (assignedAll[b.categoryId] ?? 0) + b.amount;
      if (!d.isAfter(e)) {
        assignedBy[b.categoryId] = (assignedBy[b.categoryId] ?? 0) + b.amount;
      }
      if (within(d)) {
        assigned[b.categoryId] = (assigned[b.categoryId] ?? 0) + b.amount;
      }
    }
    final stored = data.prefs[BudgetKeys.began];
    final began = stored != null ? parseDateKey(stored) : earliest;

    final spent = <int, int>{}, spentCounted = <int, int>{};
    final spentBy = <int, int>{}, spentAll = <int, int>{};
    final cameIn = <int, int>{};
    var uncategorizedRows = 0, uncategorizedNet = 0;
    void spend(int id, DateTime d, int amount, bool counted) {
      if (within(d)) {
        spent[id] = (spent[id] ?? 0) + amount;
        if (counted) spentCounted[id] = (spentCounted[id] ?? 0) + amount;
      }
      if (counted) {
        spentAll[id] = (spentAll[id] ?? 0) + amount;
        if (!d.isAfter(e)) spentBy[id] = (spentBy[id] ?? 0) + amount;
        dated[id]?.add((date: d, amount: -amount));
      }
    }

    bool isMoney(int accountId) {
      final a = data.accounts[accountId];
      return a != null && counts(a, main);
    }

    for (final t in data.txns) {
      if (t.scheduled) continue;
      final d = dateOnly(t.date);
      final counted = began != null && !d.isBefore(began);
      final fromMoney = t.entries.any(
        (x) => x.amount < 0 && x.currency == main && isMoney(x.accountId),
      );
      for (final x in t.entries) {
        if (x.currency != main) continue;
        final a = data.accounts[x.accountId];
        if (a == null || a.deleted) continue;
        if (a.type == AccountType.income) {
          if (within(d)) cameIn[a.id] = (cameIn[a.id] ?? 0) - x.amount;
        } else if (uncategorized.contains(a.id)) {
          uncategorizedRows++;
          uncategorizedNet -= x.amount;
        } else if (envelopes.contains(a.id)) {
          spend(a.id, d, x.amount, counted);
        } else if (loans[a.id] case final c? when fromMoney && x.amount > 0) {
          // A payment into a long loan, from money that counts.
          spend(c, d, x.amount, counted);
        }
      }
    }

    for (final changes in dated.values) {
      changes.sort((a, b) => a.date.compareTo(b.date));
    }
    final BudgetSpan viewed = (start: s, end: e, label: '');
    final current = budgetPeriod(today, by);

    final lines = <int, EnvelopeLine>{};
    var held = 0, unassignedCount = 0, unassignedAmount = 0;
    for (final id in envelopes) {
      final counted = spentCounted[id] ?? 0;
      final plan = plans[id];
      final changes = dated[id] ?? const [];
      var left = (assignedBy[id] ?? 0) - (spentBy[id] ?? 0);
      var fromBefore = left - (assigned[id] ?? 0) + counted;
      var holds = (assignedAll[id] ?? 0) - (spentAll[id] ?? 0);
      var wentBack = 0;
      if (plan != null && _emptied(plan)) {
        // Emptied at the end of every period before the one on screen,
        // so it begins with nothing, or with what it overspent.
        final into = _emptiedUntil(changes, plan.start, s, by);
        fromBefore = into.balance;
        wentBack = into.lastEmptied;
        left = fromBefore + (assigned[id] ?? 0) - counted;
        // What it holds now: emptied up to today's period, then every
        // amount since, a later period's too.
        holds = _emptiedUntil(changes, plan.start, current.start, by).balance;
        for (final c in changes) {
          if (!c.date.isBefore(current.start)) holds += c.amount;
        }
      }
      lines[id] = EnvelopeLine(
        assigned: assigned[id] ?? 0,
        spent: spent[id] ?? 0,
        left: left,
        fromBefore: fromBefore,
        plan: plan == null
            ? null
            : _planLine(
                plan,
                data.budgetAmounts,
                changes,
                viewed,
                by,
                began: began,
                assigned: assigned[id] ?? 0,
                left: left,
                spent: counted,
                wentBack: wentBack,
              ),
      );
      held += holds;
      if ((assignedBy[id] ?? 0) == 0 && counted > 0) {
        unassignedCount++;
        unassignedAmount += counted;
      }
    }

    var money = 0;
    for (final a in data.accounts.values) {
      if (counts(a, main)) money += data.balanceOf(a.id);
    }

    return Budget._(
      currency: main,
      began: began,
      lines: lines,
      cameIn: cameIn,
      notAssigned: money - held,
      money: money,
      uncategorizedRows: uncategorizedRows,
      uncategorizedNet: uncategorizedNet,
      unassignedSpent: (count: unassignedCount, amount: unassignedAmount),
    );
  }

  /// A plan's part is rounded up to one whole unit of the currency (both
  /// have two decimals), so a bill in seven parts isn't ₮171,428.57 each.
  static const _unit = 100;

  /// A spend-through-the-period category that doesn't carry over.
  static bool _emptied(CategoryPlan p) =>
      p.kind == PlanKind.spend && !p.rollover;

  static int _ceilTo(int amount, int unit) =>
      amount <= 0 ? 0 : ((amount + unit - 1) ~/ unit) * unit;

  /// The day [n] bills after [first], [every] months apart, kept on the
  /// same day of the month where the month has it.
  static DateTime _dueAfter(DateTime first, int every, int n) {
    final months = first.month - 1 + every * n;
    final y = first.year + months ~/ 12, m = months % 12 + 1;
    final last = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, first.day < last ? first.day : last);
  }

  /// How many periods from [from] through the one [day] is in; 1 when
  /// [day] is in [from] or before it.
  static int _periodsThrough(BudgetSpan from, DateTime day, PaySchedule? by) {
    var n = 1;
    var p = from;
    while (p.end.isBefore(day) && n < _mostPeriods) {
      final next = nextBudgetPeriod(p, by);
      if (!next.start.isAfter(p.start)) break;
      p = next;
      n++;
    }
    return n;
  }

  /// A stop for the walks through periods, far past any real plan (a
  /// pay period every week for a hundred years).
  static const _mostPeriods = 5200;

  /// A category that doesn't carry over, walked period by period up to
  /// the one starting [until]: whatever is left when a period ends goes
  /// back to the money not assigned, and what's overspent carries. Only
  /// from the period [since] is in (the day the plan was made): what it
  /// held before then stays, so choosing this doesn't reach into the
  /// past. [changes] are its amounts and spending in date order.
  static ({int balance, int lastEmptied}) _emptiedUntil(
    List<({DateTime date, int amount})> changes,
    DateTime since,
    DateTime until,
    PaySchedule? by,
  ) {
    var p = budgetPeriod(since, by);
    var balance = 0, lastEmptied = 0, i = 0, walked = 0;
    // Before the plan, and never anything dated in the period asked for.
    bool takes(DateTime d, DateTime before) =>
        d.isBefore(before) && d.isBefore(until);
    while (i < changes.length && takes(changes[i].date, p.start)) {
      balance += changes[i++].amount;
    }
    while (p.start.isBefore(until) && walked++ < _mostPeriods) {
      final next = nextBudgetPeriod(p, by);
      while (i < changes.length && takes(changes[i].date, next.start)) {
        balance += changes[i++].amount;
      }
      lastEmptied = balance > 0 ? balance : 0;
      if (balance > 0) balance = 0;
      if (!next.start.isAfter(p.start)) break;
      p = next;
    }
    return (balance: balance, lastEmptied: lastEmptied);
  }

  /// [plan] worked out for the period [p] (rule 27). [assigned], [left]
  /// and [spent] are the category's own for that period.
  static PlanLine _planLine(
    CategoryPlan plan,
    List<BudgetAmount> amounts,
    List<({DateTime date, int amount})> changes,
    BudgetSpan p,
    PaySchedule? by, {
    required DateTime? began,
    required int assigned,
    required int left,
    required int spent,
    required int wentBack,
  }) {
    if (plan.kind == PlanKind.spend || plan.kind == PlanKind.saveUp) {
      return PlanLine(
        plan: plan,
        each: plan.amount,
        planned: plan.amount,
        wentBack: wentBack,
      );
    }
    final first = dateOnly(plan.due ?? plan.start);
    // What it held at the start of [day], and what was assigned from
    // [from] up to [to].
    int heldBefore(DateTime day) {
      var sum = 0;
      for (final c in changes) {
        if (c.date.isBefore(day)) sum += c.amount;
      }
      return sum;
    }

    int assignedIn(DateTime from, DateTime to) {
      var sum = 0;
      for (final b in amounts) {
        if (b.categoryId != plan.categoryId) continue;
        final d = dateOnly(b.date);
        if (!d.isBefore(from) && d.isBefore(to)) sum += b.amount;
      }
      return sum;
    }

    int ceilDiv(int amount, int n) => _ceilTo((amount + n - 1) ~/ n, _unit);

    // The plan counts from the period it was made in, or the budget's
    // first if that's later (the budget's start can be moved on).
    final planStart = dateOnly(plan.start);
    var begins = budgetPeriod(
      began != null && began.isAfter(planStart) ? began : planStart,
      by,
    );
    // Made late in a period whose money was already assigned elsewhere:
    // with nothing put in that period (and something still to save), the
    // parts start with the next, so a new plan isn't "short" through no
    // fault of anyone's.
    if (p.start.isAfter(begins.end) &&
        heldBefore(begins.start) < plan.amount &&
        assignedIn(begins.start, nextBudgetPeriod(begins, by).start) == 0) {
      begins = nextBudgetPeriod(begins, by);
    }
    if (p.end.isBefore(begins.start)) {
      return PlanLine(
        plan: plan,
        each: 0,
        planned: 0,
        due: first,
        waiting: true,
      );
    }
    // What the category held when the plan began counts toward it.
    final base = heldBefore(begins.start);

    if (plan.kind == PlanKind.goal) {
      // Counted by what was assigned, not what's left: spending the money
      // on the thing itself isn't falling behind.
      final toGo = plan.amount - base - assignedIn(begins.start, p.start);
      if (toGo <= 0) {
        return PlanLine(
          plan: plan,
          each: 0,
          planned: 0,
          due: first,
          done: true,
        );
      }
      // Past its date: all of what's missing is wanted now.
      if (first.isBefore(p.start)) {
        return PlanLine(
          plan: plan,
          each: 0,
          planned: toGo,
          overdue: toGo,
          due: first,
        );
      }
      final part = ceilDiv(toGo, _periodsThrough(p, first, by));
      final each = part > toGo ? toGo : part;
      return PlanLine(
        plan: plan,
        each: each,
        planned: each,
        due: first,
        // This period's amount completes it.
        done: assigned >= toGo,
      );
    }

    // A bill due on a date.
    final every = plan.everyMonths;
    final bill = plan.amount;
    DateTime dueOf(int n) => every == null ? first : _dueAfter(first, every, n);
    // Bills are numbered from the first the plan could save for: the
    // first due in its first period or later.
    var n0 = 0;
    if (every != null) {
      while (dueOf(n0).isBefore(begins.start) && n0 < _mostPeriods) {
        n0++;
      }
    }
    final firstNeed = bill - base < 0 ? 0 : bill - base;
    // A bill that doesn't repeat, its date gone: whatever is still
    // missing is wanted now.
    if (every == null && first.isBefore(p.start)) {
      final missing = firstNeed - assignedIn(begins.start, p.start);
      return PlanLine(
        plan: plan,
        each: 0,
        planned: missing < 0 ? 0 : missing,
        overdue: missing < 0 ? 0 : missing,
        due: first,
        done: true,
      );
    }
    // The bill this period saves for: the first due on or after it
    // starts.
    var n = n0;
    if (every != null) {
      while (dueOf(n).isBefore(p.start) && n - n0 < _mostPeriods) {
        n++;
      }
    }
    final due = dueOf(n);
    // Each bill is counted on its own, from the plan's first period or
    // from the period after the one before it was due. So a bill skipped
    // and never owed isn't asked for again, and "short" never grows past
    // one bill.
    final from = n == n0
        ? begins
        : nextBudgetPeriod(budgetPeriod(dueOf(n - 1), by), by);
    final int need, carried;
    if (n == n0) {
      need = firstNeed;
      carried = base;
    } else {
      // What a later bill starts from. A minus (the last one cost more
      // than was saved) is added to this one. What's left over isn't
      // counted, since it may be the last bill not paid yet; only what
      // the category held beyond a whole bill when the plan began is.
      carried = heldBefore(from.start);
      final extra = base - bill * (n - n0);
      final wanted =
          bill - (carried < 0 ? carried : 0) - (extra > 0 ? extra : 0);
      need = wanted < 0 ? 0 : wanted;
    }
    final parts = _periodsThrough(from, due, by);
    var k = _periodsThrough(from, p.start, by);
    if (k > parts) k = parts;
    final part = ceilDiv(need, parts);
    var target = part * k > need ? need : part * k;
    var each = part > need ? need : part;
    // More bills due before this period ends (a monthly bill just before
    // a payday that a weekend moved): each is wanted whole.
    if (every != null) {
      var more = 0;
      while (!dueOf(n + more + 1).isAfter(p.end) && more < _mostPeriods) {
        more++;
      }
      target += bill * more;
      each += bill * more;
    }
    final before = assignedIn(from.start, p.start);
    final planned = target - before < 0 ? 0 : target - before;
    // What it should hold: its parts so far on top of what it started
    // with. In the period the bill is due, paying it isn't a shortfall.
    final dueNow = !due.isBefore(p.start) && !due.isAfter(p.end);
    final should =
        (n == n0 || carried < 0 ? carried : 0) +
        (planned < assigned ? before + planned : before + assigned);
    return PlanLine(
      plan: plan,
      each: each,
      planned: planned,
      overdue: planned > each ? planned - each : 0,
      due: due,
      held: left + (dueNow && spent > 0 ? spent : 0) >= should,
    );
  }
}

/// A budget period: a calendar month, or a pay period of the schedule the
/// budget runs by.
typedef BudgetSpan = ({DateTime start, DateTime end, String label});

/// The period after [p].
BudgetSpan nextBudgetPeriod(BudgetSpan p, PaySchedule? by) =>
    budgetPeriod(DateTime(p.end.year, p.end.month, p.end.day + 1), by);

/// The period before [p].
BudgetSpan previousBudgetPeriod(BudgetSpan p, PaySchedule? by) =>
    budgetPeriod(DateTime(p.start.year, p.start.month, p.start.day - 1), by);
