import 'dart:math';

import 'ledger.dart';
import 'money.dart';
import 'pay.dart';
import 'readiness.dart' show ReadyKeys, isGoal, mainCurrency;

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

  /// [began] for a currency other than the budget's own, by its code
  /// (`budget.began.USD`): dollars assigned first don't start the tugrik
  /// budget, nor the other way round (#163). Without one, [began].
  static String beganIn(Currency c) => '$began.${c.code}';

  /// The currency amounts are in, set with [began], so adding accounts in
  /// the other currency can't change what the amounts mean.
  static const currency = 'budget.currency';

  /// '1' once the first-month offer was answered with "Keep".
  static const keptStart = 'budget.keptStart';

  /// Prefix, then a spending category's id: `YYYY-MM-DD`, the day its
  /// spending counts from when that's later than [began]. Set when its
  /// currency is changed, to the start of that period: what was paid in
  /// the new currency before then was never counted against it, and
  /// doesn't start it off overspent.
  static const fromPrefix = 'budget.from.';

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

/// Whether a row in [currency] filed under [category] is counted there
/// (rule 28): a spending category is in one currency; Income and "Not
/// categorized" take any. The ledger's dropdowns offer only these.
bool categoryTakes(AccountInfo category, Currency currency) =>
    category.isIncome ||
    isUncategorized(category) ||
    category.currency == currency;

/// One spending category in one period.
class EnvelopeLine {
  const EnvelopeLine({
    required this.assigned,
    required this.spent,
    required this.left,
    required this.fromBefore,
    this.currency = Currency.mnt,
    this.plan,
    this.otherRows = 0,
    this.otherAmount = 0,
    this.otherCurrency,
    this.backing,
    this.paidOn,
    this.counted = 0,
  });

  /// This period's spending that counts against it: since the budget
  /// began, in its currency. [spent] shows the whole period's.
  final int counted;

  /// The currency the category is in (rule 28): its amounts, its plan,
  /// and the only spending that counts against it.
  final Currency currency;

  /// The day the bill that counts in this period was last paid, when it
  /// has one and a row was tied to it (a scheduled bill confirmed, or a
  /// payment taken as the bill; ADR 0004 "A bill paid another way"). The
  /// bill's date places it, as [spent] counts it: rent for 11.01 paid
  /// 10.30 is November's. Null otherwise. For "paid 10.30" on its line
  /// (#274).
  final DateTime? paidOn;

  /// What it had this period to spend: what's left plus what it spent
  /// that counted, so it agrees with Left however Left was reached (money
  /// from before, nothing assigned, the period the budget began in, where
  /// Spent shows the whole period's spending and Left counts only what
  /// came after). For a category that doesn't carry over, what went back
  /// to not assigned inside the period is out (code review).
  int get had => left + counted;

  /// What of that is used: the spending that counted, never below zero.
  int get used => counted < 0 ? 0 : counted;

  /// How much of what it had is used, 0 to 1, for the ring before its
  /// name (#241; ADR 0004 "How used up a category is"). 1 at zero or
  /// below. Null when there's nothing to picture: a category saving for
  /// a bill (its line says due or paid), or nothing had and nothing
  /// spent.
  double? get usedShare {
    if (plan?.plan.kind == PlanKind.byDate) return null;
    if (left < 0) return 1;
    if (had <= 0) return null;
    return used >= had ? 1 : used / had;
  }

  /// Rows filed under it in another currency since the budget began,
  /// which aren't counted (they stay until they're fixed): how many, what
  /// they add up to, and in what.
  final int otherRows;
  final int otherAmount;
  final Currency? otherCurrency;

  /// Set when the account it keeps its money in (its Paid from, cash or
  /// bank) holds less than is left in the categories kept there: what's
  /// left in them, in how many categories (this one included), and what
  /// the account holds. As of today.
  final ({int setAside, int categories, int have})? backing;

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
    this.lastPeriod = false,
    this.ended = false,
    this.approx = false,
    this.shares = const [],
    this.wentBackOn,
    this.once = false,
    this.onceFrom,
    this.usual = 0,
    this.late = false,
    this.toward = 0,
    this.pastDate = false,
    this.finished = false,
  });

  final CategoryPlan plan;

  /// A once-only amount by a date: the part each period asks while it's
  /// kept up with, from the plan's first period to its date.
  final int usual;

  /// A goal whose date has passed short, still asking its [usual] part
  /// rather than all of the rest at once ([ReadyKeys.goalLate]).
  final bool late;

  /// A once-only amount by a date: what counts toward it through this
  /// period, as the parts are worked out: what the category held when the
  /// plan began, and every amount assigned since. Spending on the thing
  /// itself doesn't take it down.
  final int toward;

  /// A once-only amount whose date is before this period: a bill would be
  /// overdue now.
  final bool pastDate;

  /// A goal past its date that the person said is done: it asks for
  /// nothing more, short or not.
  final bool finished;

  /// A set amount seen by its own period, which was given an amount of its
  /// own ([CategoryPlan.once]): [each] is that one, not the plan's.
  final bool once;

  /// The day the own period [once] is about starts.
  final DateTime? onceFrom;

  /// [planned] is a share, by days, of what the plan's own period still
  /// wants: the period on screen isn't the plan's (a monthly allowance
  /// seen by a fortnight's pay, or the other way round). Said as "about".
  final bool approx;

  /// A set amount seen by another period than its own: what each of its
  /// own periods the span touches wants in the span, dated where that
  /// period and the span first overlap. They add up to [planned]. Money
  /// assigned from this view is dated by them, so each period keeps its
  /// own ([Budget.spread]). Empty when the span is the plan's own period.
  final List<({DateTime date, int amount})> shares;

  /// When [wentBack] went back: the latest of the category's own period
  /// ends in the span, or at its start. Null when nothing went back.
  final DateTime? wentBackOn;

  /// A repeating plan past its last bill (Custom…'s Ends): it asks for
  /// nothing more, and [due] is that last bill.
  final bool ended;

  /// What goes in each period: the set amount, or a dated plan's part,
  /// worked out from what's still missing and the periods left. 0 when
  /// nothing more is asked (a date passed, an amount reached or a cap
  /// held, a period before the plan).
  final int each;

  /// What Assigned should come to this period: [each], plus any more
  /// bills due before the period ends; for a capped plan, no more than
  /// the cap leaves room for.
  final int planned;

  /// What should have been in before this period and wasn't: what
  /// "short" names. For a plan whose date has passed, all of it.
  final int overdue;

  /// The date this period is saving for: the bill's due date, or the day
  /// a one-time amount is wanted by.
  final DateTime? due;

  /// A one-time amount reached (or its date passed), or a capped plan
  /// holding its cap.
  final bool done;

  /// A period before the plan began: it asks for nothing yet.
  final bool waiting;

  /// A dated plan in the last period before its date: [each] is the
  /// rest, said as "this month" rather than "a month".
  final bool lastPeriod;

  /// A category that doesn't carry over: what was left when the period
  /// before this one ended, which went back to the money not assigned.
  final int wentBack;
}

/// One currency's money in the budget (rule 28): tugrik and dollars are
/// never added together.
class BudgetPool {
  const BudgetPool({
    required this.currency,
    required this.money,
    required this.notAssigned,
    this.overspent = 0,
  });
  final Currency currency;

  /// Cash and bank in this currency (ADR 0004, "What's owed is not the
  /// Budget page's job").
  final int money;

  /// [money] less what this currency's categories with money hold, as of
  /// today. An overspent category counts as nothing here: what it went
  /// over is already gone from [money] (owner, 2026-10-24).
  final int notAssigned;

  /// What this currency's overspent categories went over, together, as of
  /// today: shown under In categories, not taken off again.
  final int overspent;
}

class Budget {
  Budget._({
    required this.currency,
    required this.began,
    required this.lines,
    required this.cameIn,
    required this.cameInUncategorized,
    required this.pools,
    required this.unassignedSpent,
  });

  /// The budget's first currency: new categories start in it, and its
  /// pool comes first.
  final Currency currency;

  /// Each currency with accounts or categories in it, [currency] first.
  final List<BudgetPool> pools;

  BudgetPool get _main => pools.first;

  /// The day the budget began; null until an amount is assigned.
  final DateTime? began;

  /// Each spending category (archived ones included: money can still sit
  /// in one), for the period asked for. Not "Not categorized".
  final Map<int, EnvelopeLine> lines;

  /// Each income category: what came in during the period.
  final Map<int, Map<Currency, int>> cameIn;

  /// Money that came in during the period and is still in Not categorized
  /// (imported pay waits there), by currency: said beside Income, which
  /// doesn't count it (owner, 2026-10-28, #182).
  final Map<Currency, int> cameInUncategorized;

  /// In [currency]: what the user has, less what the categories with money
  /// hold, as of today, with every amount assigned counted, a later
  /// period's too. Negative when more was assigned than there is.
  int get notAssigned => _main.notAssigned;

  /// What [notAssigned] starts from: cash and bank.
  int get money => _main.money;

  /// This period's spending since the budget began in categories nothing
  /// was assigned to: what the first-month offer names.
  final ({int count, int amount}) unassignedSpent;

  /// Accounts whose balance counts as money to budget: cash and bank, and
  /// nothing else (ADR 0004, "What's owed is not the Budget page's job").
  /// What a credit card or loan owes is tracked on the Savings page; here
  /// only its payment matters, which is budgeted as a category like rent.
  static bool counts(AccountInfo a, Currency main) =>
      a.type == AccountType.asset && !a.deleted && a.currency == main;

  /// Accounts a category can be spent from: cash, bank and credit cards (a
  /// card is an account; if they plan to pay with it, let them — ADR 0004).
  /// Wider than [counts], which is only about where money sits: a card holds
  /// none but is spent from all the time. A mortgage or student loan is
  /// neither, so it's out of both.
  static bool spendable(AccountInfo a, Currency c) =>
      a.isBalanceSheet && !a.deleted && a.currency == c && !isLongLoan(a);

  static bool isLongLoan(AccountInfo a) =>
      a.role == AccountRole.mortgage || a.role == AccountRole.studentLoan;

  /// The currency the budget counts in: the one it began in, for as long
  /// as an account or a category is in it. Once the last of those is gone
  /// (every dollar account deleted), it's the currency the accounts are in,
  /// so the Budget page doesn't lead with a currency nothing is in.
  static Currency currencyOf(LedgerData data) {
    final code = data.prefs[BudgetKeys.currency];
    if (code != null) {
      final began = Currency.fromCode(code);
      final inUse = data.accounts.values.any(
        (a) =>
            !a.deleted &&
            a.currency == began &&
            (a.isBalanceSheet ||
                (a.isCategory && !a.isIncome && !isUncategorized(a))),
      );
      if (inUse) return began;
    }
    return mainCurrency(data);
  }

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
    Currency currencyOfCategory(int id) => data.accounts[id]!.currency;
    // Paying a credit card or loan is its category's spending, when the two
    // are in the same currency: the payment is budgeted like rent, and what's
    // owed is the Savings page's business.
    final loans = <int, int>{};
    for (final a in data.accounts.values) {
      if (a.deleted || !a.isOwed) continue;
      final c = loanCategory(data, a.id);
      if (c != null &&
          envelopes.contains(c) &&
          currencyOfCategory(c) == a.currency) {
        loans[a.id] = c;
      }
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
      for (final p in plans.values) p.categoryId: [],
    };

    final earliest = <Currency, DateTime>{};
    final assigned = <int, int>{}, assignedBy = <int, int>{};
    final assignedAll = <int, int>{};
    for (final b in data.budgetAmounts) {
      if (!envelopes.contains(b.categoryId)) continue;
      final d = dateOnly(b.date);
      dated[b.categoryId]?.add((date: d, amount: b.amount));
      final c = currencyOfCategory(b.categoryId);
      if (earliest[c] == null || d.isBefore(earliest[c]!)) earliest[c] = d;
      assignedAll[b.categoryId] = (assignedAll[b.categoryId] ?? 0) + b.amount;
      if (!d.isAfter(e)) {
        assignedBy[b.categoryId] = (assignedBy[b.categoryId] ?? 0) + b.amount;
      }
      if (within(d)) {
        assigned[b.categoryId] = (assigned[b.categoryId] ?? 0) + b.amount;
      }
    }
    final stored = data.prefs[BudgetKeys.began];
    final began = stored != null ? parseDateKey(stored) : earliest[main];
    // Each currency's own first day: its key, else the budget's, else its
    // first amount.
    DateTime? beganFor(Currency c) {
      if (c == main) return began;
      final own = data.prefs[BudgetKeys.beganIn(c)];
      if (own != null) return parseDateKey(own);
      return stored != null ? parseDateKey(stored) : earliest[c];
    }

    final spent = <int, int>{}, spentCounted = <int, int>{};
    final spentBy = <int, int>{}, spentAll = <int, int>{};
    final cameIn = <int, Map<Currency, int>>{};
    final cameInUncategorized = <Currency, int>{};
    final otherRows = <int, int>{}, otherAmount = <int, int>{};
    final otherCurrency = <int, Currency>{};
    // [on]: the day the plan counts it, when that isn't [d] (a bill the
    // bank took a day before its date).
    void spend(int id, DateTime d, int amount, bool counted, {DateTime? on}) {
      if (within(d)) {
        spent[id] = (spent[id] ?? 0) + amount;
        if (counted) spentCounted[id] = (spentCounted[id] ?? 0) + amount;
      }
      if (counted) {
        spentAll[id] = (spentAll[id] ?? 0) + amount;
        if (!d.isAfter(e)) spentBy[id] = (spentBy[id] ?? 0) + amount;
        dated[id]?.add((date: on ?? d, amount: -amount));
      }
    }

    // A category whose currency was changed counts from that period on.
    final countsFrom = <int, DateTime>{
      for (final id in envelopes)
        if (data.prefs['${BudgetKeys.fromPrefix}$id'] case final String day)
          id: parseDateKey(day),
    };

    // By category, the day of the last payment of a bill that counts in
    // this period, for "paid 10.30" on its line (#274).
    final paidOn = <int, DateTime>{};
    // The bill a row tied to [category] paid, dated as its spending is
    // counted: the bill it was taken as paid for, else the plan's bill
    // nearest the row.
    DateTime? billDateOf(TxnData t, int category, DateTime d) =>
        decodeBillPaid(data.prefs[billPaidKey(t.id)])?.date ??
        switch (plans[category]) {
          final p? when p.kind == PlanKind.byDate => billDate(
            p,
            d,
            pay: data.payScheduleById(p.payScheduleId),
          ),
          _ => null,
        };
    // A bill paid: kept on the line of the period the bill counts in
    // (rent for 11.01 paid 10.30 is November's), said by the day it was
    // paid; the latest when there are two.
    void notePaid(int category, DateTime d, DateTime? bill) {
      if (bill == null || !within(bill)) return;
      final was = paidOn[category];
      if (was == null || d.isAfter(was)) paidOn[category] = d;
    }

    for (final t in data.txns) {
      if (t.scheduled) continue;
      final d = dateOnly(t.date);
      // Paid out of money that counts, in this currency.
      bool fromMoney(Currency c) => t.entries.any((x) {
        final a = data.accounts[x.accountId];
        return x.amount < 0 && x.currency == c && a != null && counts(a, c);
      });
      for (final x in t.entries) {
        final a = data.accounts[x.accountId];
        if (a == null || a.deleted) continue;
        if (a.type == AccountType.income) {
          // Each currency on its own: pay in dollars is dollars.
          if (within(d)) {
            final came = cameIn.putIfAbsent(a.id, () => {});
            came[x.currency] = (came[x.currency] ?? 0) - x.amount;
          }
        } else if (uncategorized.contains(a.id)) {
          // Holds no money: its rows stay in what's not assigned. Money in
          // there is said beside Income.
          if (within(d) && x.amount < 0) {
            cameInUncategorized[x.currency] =
                (cameInUncategorized[x.currency] ?? 0) - x.amount;
          }
        } else if (envelopes.contains(a.id)) {
          final from = countsFrom[a.id];
          final starts = beganFor(a.currency);
          final budgetBegun = starts != null && !d.isBefore(starts);
          final counted = budgetBegun && (from == null || !d.isBefore(from));
          if (x.currency != a.currency) {
            // In the other currency: it can't be counted against this
            // category's amounts, so the line says it's there.
            if (counted) {
              otherRows[a.id] = (otherRows[a.id] ?? 0) + 1;
              otherAmount[a.id] = (otherAmount[a.id] ?? 0) + x.amount;
              otherCurrency[a.id] = x.currency;
            }
            continue;
          }
          // A bill the plan itself scheduled counts on the date it was
          // for: taken on the 30th instead of the 1st, it's still that
          // month's bill, not an extra one the month before.
          // A row taken as a bill paid counts on that bill's date, however
          // late ([billPaidKey]).
          final planned = t.planCategoryId == a.id
              ? billDateOf(t, a.id, d)
              : null;
          spend(a.id, d, x.amount, counted, on: planned);
          notePaid(a.id, d, planned);
        } else if (loans[a.id] case final c?
            when x.amount > 0 && fromMoney(x.currency)) {
          // A payment into a long loan, from money that counts.
          final from = countsFrom[c];
          final starts = beganFor(x.currency);
          spend(
            c,
            d,
            x.amount,
            starts != null &&
                !d.isBefore(starts) &&
                (from == null || !d.isBefore(from)),
          );
          // The loan's bill paid by it: counted on its own day, so said
          // on that day's period (code review).
          if (t.planCategoryId == c) notePaid(c, d, d);
        }
      }
    }

    for (final changes in dated.values) {
      changes.sort((a, b) => a.date.compareTo(b.date));
    }
    final BudgetSpan viewed = (start: s, end: e, label: '');

    final lines = <int, EnvelopeLine>{};
    final held = <Currency, int>{}, over = <Currency, int>{};
    final holding = <int, int>{};
    var unassignedCount = 0, unassignedAmount = 0;
    for (final id in envelopes) {
      final currency = currencyOfCategory(id);
      final counted = spentCounted[id] ?? 0;
      final plan = plans[id];
      final changes = dated[id] ?? const [];
      var left = (assignedBy[id] ?? 0) - (spentBy[id] ?? 0);
      var fromBefore = left - (assigned[id] ?? 0) + counted;
      var holds = (assignedAll[id] ?? 0) - (spentAll[id] ?? 0);
      var wentBack = 0;
      DateTime? wentBackOn;
      // The period the category itself runs by: a set amount's month or
      // pay (its own choice, in its plan); a bill divides over whatever
      // periods are on screen. [by] is only the view.
      final own = plan != null && plan.kind == PlanKind.each
          ? data.payScheduleById(plan.payScheduleId)
          : by;
      if (plan != null && _emptied(plan)) {
        // Emptied at the end of each of its own periods: before the span
        // on screen, so it begins with nothing (or what it overspent),
        // and at any of its period ends inside the span, when the span
        // is longer than its period.
        final walk = _emptying(changes, plan.start, s, e, own, today: today);
        fromBefore = walk.atStart;
        wentBack = walk.emptiedAtStart + walk.emptiedInside;
        wentBackOn = walk.lastOn;
        left = fromBefore + (assigned[id] ?? 0) - counted - walk.emptiedInside;
        // What it holds now: emptied up to today's period, then every
        // amount since, a later period's too.
        final current = budgetPeriod(today, own);
        holds = _emptying(
          changes,
          plan.start,
          current.start,
          current.start,
          own,
          today: today,
        ).atStart;
        for (final c in changes) {
          if (!c.date.isBefore(current.start)) holds += c.amount;
        }
      }
      lines[id] = EnvelopeLine(
        assigned: assigned[id] ?? 0,
        spent: spent[id] ?? 0,
        left: left,
        fromBefore: fromBefore,
        currency: currency,
        counted: counted,
        paidOn: paidOn[id],
        otherRows: otherRows[id] ?? 0,
        otherAmount: otherAmount[id] ?? 0,
        otherCurrency: otherCurrency[id],
        plan: plan == null
            ? null
            : _planLine(
                plan,
                data.budgetAmounts,
                changes,
                viewed,
                by,
                pay: data.payScheduleById(plan.payScheduleId),
                began: beganFor(currency),
                assigned: assigned[id] ?? 0,
                left: left,
                spent: counted,
                wentBack: wentBack,
                wentBackOn: wentBackOn,
                skipped: skippedBills(data, plan),
                pays: data.paySchedules,
                lateWay: isGoal(data, id)
                    ? data.prefs[ReadyKeys.goalLate(id)] ?? 'keep'
                    : 'all',
              ),
      );
      // Only what a category with money holds is out of the money not
      // assigned; an overspent one's minus was spent from it already.
      if (holds > 0) {
        held[currency] = (held[currency] ?? 0) + holds;
      } else {
        over[currency] = (over[currency] ?? 0) - holds;
      }
      holding[id] = holds;
      if (currency == main && (assignedBy[id] ?? 0) == 0 && counted > 0) {
        unassignedCount++;
        unassignedAmount += counted;
      }
    }

    // Where a category keeps its money: the account it's paid from, when
    // that's cash or bank (a card holds none). Only one keeping money for
    // later is compared with it (#180).
    int? keptIn(int id) {
      final a = data.accounts[data.paidFrom[id]];
      if (a == null ||
          a.archived ||
          a.type != AccountType.asset ||
          !spendable(a, currencyOfCategory(id))) {
        return null;
      }
      return a.id;
    }

    // A plan that keeps money (a bill, a goal, one that carries over), or
    // the Safety net. One with no plan, or spent down, is spent from its
    // account as it goes.
    bool keeps(int id) => switch (data.plans[id]) {
      final p? => !_emptied(p),
      null => data.accounts[id]?.role == AccountRole.emergencyFund,
    };
    final kept = <int, int>{
      for (final id in envelopes)
        if (keeps(id)) id: ?keptIn(id),
    };
    for (final MapEntry(key: id, value: account) in kept.entries) {
      if ((holding[id] ?? 0) <= 0) continue;
      // It can't hold more than its account does. Others kept there share
      // it.
      final have = data.balanceOf(account);
      var setAside = 0, categories = 0;
      for (final MapEntry(key: other, value: theirs) in kept.entries) {
        if (theirs == account && (holding[other] ?? 0) > 0) {
          setAside += holding[other]!;
          categories++;
        }
      }
      if (setAside <= have) continue;
      final backing = (setAside: setAside, categories: categories, have: have);
      final l = lines[id]!;
      lines[id] = EnvelopeLine(
        assigned: l.assigned,
        spent: l.spent,
        left: l.left,
        fromBefore: l.fromBefore,
        currency: l.currency,
        plan: l.plan,
        otherRows: l.otherRows,
        otherAmount: l.otherAmount,
        otherCurrency: l.otherCurrency,
        backing: backing,
        paidOn: l.paidOn,
        counted: l.counted,
      );
    }

    // A pool for each currency with money or a category in it.
    final currencies = <Currency>[main];
    for (final a in data.accounts.values) {
      final inUse =
          (counts(a, a.currency) && !a.archived) || envelopes.contains(a.id);
      if (inUse && !currencies.contains(a.currency)) {
        currencies.add(a.currency);
      }
    }
    final pools = [
      for (final c in currencies)
        () {
          var money = 0;
          for (final a in data.accounts.values) {
            if (counts(a, c)) money += data.balanceOf(a.id);
          }
          return BudgetPool(
            currency: c,
            money: money,
            notAssigned: money - (held[c] ?? 0),
            overspent: over[c] ?? 0,
          );
        }(),
    ];

    return Budget._(
      currency: main,
      began: began,
      lines: lines,
      cameIn: cameIn,
      cameInUncategorized: cameInUncategorized,
      pools: pools,
      unassignedSpent: (count: unassignedCount, amount: unassignedAmount),
    );
  }

  /// A plan's part is rounded up to one whole unit of the currency (both
  /// have two decimals), so a bill in seven parts isn't ₮171,428.57 each.
  static const _unit = 100;

  /// The dates of [plan]'s bills there won't be, as the person said
  /// ("No bill this time", or a payment for more than one): kept as
  /// settings ([billSkippedKey]). A bill deleted any other way isn't one.
  static Set<DateTime> skippedBills(LedgerData data, CategoryPlan plan) {
    final out = <DateTime>{};
    for (final e in data.prefs.entries) {
      if (!e.key.startsWith(billSkippedPrefix)) continue;
      final parts = e.value.split(';');
      if (parts.length != 2 || int.tryParse(parts[0]) != plan.categoryId) {
        continue;
      }
      try {
        out.add(parseDateKey(parts[1]));
      } catch (_) {}
    }
    return out;
  }

  /// An each-period category that doesn't carry over.
  static bool _emptied(CategoryPlan p) =>
      p.kind == PlanKind.each && !p.rollover;

  static int _ceilTo(int amount, int unit) =>
      amount <= 0 ? 0 : ((amount + unit - 1) ~/ unit) * unit;

  /// The date of [plan]'s bill that a row dated [d] paid: the nearest of
  /// its dates. Null when [d] is more than half a gap before the first,
  /// which was some earlier plan's bill, not this one's. A plan that
  /// doesn't repeat has one date.
  static DateTime? billDate(CategoryPlan plan, DateTime d, {PaySchedule? pay}) {
    if (plan.due == null && plan.payScheduleId == null) return null;
    final first = dueAfter(plan, 0, pay: pay);
    if (!plan.repeats) return first;
    var n = 0;
    while (dueAfter(plan, n, pay: pay).isBefore(d) && n < _mostPeriods) {
      n++;
    }
    final after = dueAfter(plan, n, pay: pay);
    if (n == 0) {
      final gap = dueAfter(plan, 1, pay: pay).difference(first);
      return first.difference(d) * 2 > gap ? null : first;
    }
    final before = dueAfter(plan, n - 1, pay: pay);
    return d.difference(before) < after.difference(d) ? before : after;
  }

  /// The date of [plan]'s bill number [n], counting from its first: by
  /// months, by days, through its list of dates each year, or payday by
  /// payday ([pay] is its schedule; without it, the first date stands
  /// alone). Moved off a weekend by the plan's rule.
  static DateTime dueAfter(CategoryPlan plan, int n, {PaySchedule? pay}) {
    final first = dateOnly(plan.due ?? plan.start);
    DateTime shift(DateTime d) => offWeekend(d, plan.weekend);
    if (plan.payScheduleId != null && pay != null) {
      var d = DateTime(plan.start.year, plan.start.month, plan.start.day - 1);
      for (var i = 0; i <= n; i++) {
        d = pay.nextAfter(d);
      }
      return DateTime(d.year, d.month, d.day + plan.daysAfterPay);
    }
    if (plan.onDates case final dates? when dates.isNotEmpty) {
      final sorted = [...dates]
        ..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
      // The first is the date in the list [first] falls on, or the next
      // one after it.
      var i0 = sorted.indexWhere(
        (x) => x.$1 > first.month || (x.$1 == first.month && x.$2 >= first.day),
      );
      var year = first.year;
      if (i0 < 0) {
        i0 = 0;
        year++;
      }
      final k = i0 + n;
      final y = year + k ~/ sorted.length;
      final (m, d) = sorted[k % sorted.length];
      final last = DateTime(y, m + 1, 0).day;
      return shift(DateTime(y, m, d < last ? d : last));
    }
    if (plan.everyDays case final days?) {
      // Every so many weeks on chosen weekdays: the dates in the first
      // date's week from it on, then each chosen week's.
      if (days % 7 == 0 && (plan.weekdays?.isNotEmpty ?? false)) {
        final wds = [...plan.weekdays!]..sort();
        final weeks = days ~/ 7;
        final monday = DateTime(
          first.year,
          first.month,
          first.day - (first.weekday - 1),
        );
        DateTime day(int w, int wd) =>
            DateTime(monday.year, monday.month, monday.day + 7 * w + wd - 1);
        final week0 = [
          for (final wd in wds)
            if (!day(0, wd).isBefore(first)) day(0, wd),
        ];
        if (n < week0.length) return shift(week0[n]);
        final m = n - week0.length;
        return shift(day(weeks * (1 + m ~/ wds.length), wds[m % wds.length]));
      }
      return shift(DateTime(first.year, first.month, first.day + days * n));
    }
    if (plan.everyMonths case final every?) {
      // The nth weekday of the month: the first date's month, or the step
      // after when that month's is already before the date.
      if (plan.nth case final nth? when plan.nthWeekday != null) {
        final wd = plan.nthWeekday!;
        final k0 = nthWeekday(first.year, first.month, nth, wd).isBefore(first)
            ? 1
            : 0;
        final base = _monthsAfter(first, every, n + k0);
        return shift(nthWeekday(base.year, base.month, nth, wd));
      }
      return shift(_monthsAfter(first, every, n));
    }
    return first;
  }

  /// The [nth] (1 to 4, or -1 for the last) [weekday] (Monday 1 … Sunday
  /// 7) of the month.
  static DateTime nthWeekday(int y, int m, int nth, int weekday) {
    if (nth > 0) {
      final first = DateTime(y, m, 1);
      final offset = (weekday - first.weekday + 7) % 7;
      return DateTime(y, m, 1 + offset + 7 * (nth - 1));
    }
    final last = DateTime(y, m + 1, 0);
    final back = (last.weekday - weekday + 7) % 7;
    return DateTime(y, m, last.day - back);
  }

  /// A repeating plan's last bill, when it ends (Custom…'s Ends): by
  /// count, or the last on or before its end date (the end date itself
  /// when the first bill is already past it). Null: it goes on.
  static DateTime? lastDue(CategoryPlan plan, {PaySchedule? pay}) {
    if (!plan.repeats) return null;
    if (plan.endCount case final c? when c > 0) {
      return dueAfter(plan, c - 1, pay: pay);
    }
    if (plan.endDate case final end?) {
      final e = dateOnly(end);
      if (dueAfter(plan, 0, pay: pay).isAfter(e)) return e;
      var n = 0;
      while (n < _mostPeriods && !dueAfter(plan, n + 1, pay: pay).isAfter(e)) {
        n++;
      }
      return dueAfter(plan, n, pay: pay);
    }
    return null;
  }

  /// The plan's first bill on [today] or after; when there is none, its
  /// last, already passed (a once-only one taken in late, #244).
  static ({DateTime date, bool passed}) nextDue(
    CategoryPlan plan,
    DateTime today, {
    PaySchedule? pay,
  }) {
    final day = dateOnly(today);
    final last = plan.repeats
        ? lastDue(plan, pay: pay)
        : dueAfter(plan, 0, pay: pay);
    var n = 0;
    while (n < _mostPeriods) {
      final d = dueAfter(plan, n, pay: pay);
      if (last != null && d.isAfter(last)) break;
      if (!d.isBefore(day)) return (date: d, passed: false);
      if (!plan.repeats) break;
      n++;
    }
    final at = last ?? dueAfter(plan, n, pay: pay);
    // An end typed before the first bill is the date it stops, which can
    // still be ahead.
    return (date: at, passed: at.isBefore(day));
  }

  /// [date] is past the plan's last bill.
  static bool over(CategoryPlan plan, DateTime date, {PaySchedule? pay}) =>
      switch (lastDue(plan, pay: pay)) {
        final last? => date.isAfter(last),
        null => false,
      };

  /// The day [n] steps of [every] months after [first], kept on the same
  /// day of the month where the month has it.
  static DateTime _monthsAfter(DateTime first, int every, int n) {
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

  /// A category that doesn't carry over, walked period by period: at
  /// each of its periods' ends, whatever is left goes back to the money
  /// not assigned, and what's overspent carries. Only from the period
  /// [since] is in (the day the plan was made): what it held before then
  /// stays, so choosing this doesn't reach into the past. [changes] are
  /// its amounts and spending in date order.
  ///
  /// For the span [start]–[end] on screen: what it held as the span began
  /// (emptied at a period end falling on [start] too), what went back
  /// then, and what went back at period ends inside the span, when the
  /// span is longer than the category's period. Inside the span only
  /// period ends up to [today] count: one still ahead hasn't emptied
  /// anything yet (budget review, 2026-10-05). [lastOn] is the latest
  /// period end that emptied something, at the start or inside.
  static ({
    int atStart,
    int emptiedAtStart,
    int emptiedInside,
    DateTime? lastOn,
  })
  _emptying(
    List<({DateTime date, int amount})> changes,
    DateTime since,
    DateTime start,
    DateTime end,
    PaySchedule? by, {
    required DateTime today,
  }) {
    var p = budgetPeriod(since, by);
    var balance = 0, i = 0, walked = 0;
    var emptiedAtStart = 0, emptiedInside = 0;
    DateTime? lastOn;
    void take(DateTime before) {
      while (i < changes.length && changes[i].date.isBefore(before)) {
        balance += changes[i++].amount;
      }
    }

    // The period after [p], or null when the schedule can't step on.
    BudgetSpan? step() {
      final next = nextBudgetPeriod(p, by);
      return next.start.isAfter(p.start) ? next : null;
    }

    // A period ends where the next begins: emptied there.
    int emptyAt(DateTime boundary) {
      take(boundary);
      final emptied = balance > 0 ? balance : 0;
      balance -= emptied;
      return emptied;
    }

    while (walked++ < _mostPeriods) {
      final next = step();
      if (next == null || next.start.isAfter(start)) break;
      final emptied = emptyAt(next.start);
      if (emptied > 0) lastOn = next.start;
      if (next.start.isAtSameMomentAs(start)) emptiedAtStart = emptied;
      p = next;
    }
    take(start);
    final atStart = balance;
    final t = dateOnly(today);
    while (walked++ < _mostPeriods) {
      final next = step();
      if (next == null || next.start.isAfter(end) || next.start.isAfter(t)) {
        break;
      }
      final emptied = emptyAt(next.start);
      if (emptied > 0) lastOn = next.start;
      emptiedInside += emptied;
      p = next;
    }
    return (
      atStart: atStart,
      emptiedAtStart: emptiedAtStart,
      emptiedInside: emptiedInside,
      lastOn: lastOn,
    );
  }

  /// A set amount's share rounds to a hundred units (₮100, $1): a day's
  /// share shown to the tugrik would read as exact.
  static const _shareUnit = _unit * 100;

  /// How an amount assigned from the span on screen is dated for a
  /// category whose own period isn't the span's (budget review,
  /// 2026-10-05: one row at the span's start landed in one of its
  /// periods, and an emptying category gave it back at the next payday).
  /// [delta] (what's being added, or taken out when negative) is split
  /// over the category's own periods the span touches, by [shares] (what
  /// the plan says each still wants) where those add up to anything, else
  /// by days; the rounding lands on the last. Each row is dated where its
  /// period and the span first overlap. Rows of zero are left out.
  static List<({DateTime date, int amount})> spread({
    required BudgetSpan span,
    required PaySchedule? own,
    required List<({DateTime date, int amount})> shares,
    required int delta,
  }) {
    if (delta == 0) return const [];
    final periods = <({DateTime date, int weight})>[];
    var p = budgetPeriod(span.start, own);
    var walked = 0;
    var total = 0;
    final byShare = shares.fold(0, (sum, x) => sum + x.amount) > 0;
    while (!p.start.isAfter(span.end) && walked++ < _mostPeriods) {
      final from = p.start.isBefore(span.start) ? span.start : p.start;
      final to = p.end.isBefore(span.end) ? p.end : span.end;
      final weight = byShare
          ? shares
                .where((x) => x.date.isAtSameMomentAs(from))
                .fold(0, (sum, x) => sum + x.amount)
          : _daysThrough(from, to);
      periods.add((date: from, weight: weight));
      total += weight;
      final next = nextBudgetPeriod(p, own);
      if (!next.start.isAfter(p.start)) break;
      p = next;
    }
    if (periods.isEmpty || total == 0) {
      return [(date: span.start, amount: delta)];
    }
    final rows = <({DateTime date, int amount})>[];
    var given = 0;
    for (var i = 0; i < periods.length; i++) {
      final last = i == periods.length - 1;
      final amount = last
          ? delta - given
          : (delta * periods[i].weight) ~/ total;
      given += amount;
      if (amount != 0) rows.add((date: periods[i].date, amount: amount));
    }
    return rows;
  }

  /// Calendar days from [a] through [b], both whole dates; 0 when [b] is
  /// before [a]. In UTC, so a daylight-saving day still counts as one.
  static int _daysThrough(DateTime a, DateTime b) {
    final n =
        DateTime.utc(
          b.year,
          b.month,
          b.day,
        ).difference(DateTime.utc(a.year, a.month, a.day)).inDays +
        1;
    return n < 0 ? 0 : n;
  }

  /// [plan] worked out for the period [p] (rule 27). [assigned], [left]
  /// and [spent] are the category's own for that period. [by] is the
  /// period on screen; [pay] is the plan's own pay: the one a set amount
  /// is per (null: per month), or the one a bill follows payday by payday.
  static PlanLine _planLine(
    CategoryPlan plan,
    List<BudgetAmount> amounts,
    List<({DateTime date, int amount})> changes,
    BudgetSpan p,
    PaySchedule? by, {
    required PaySchedule? pay,
    required DateTime? began,
    required int assigned,
    required int left,
    required int spent,
    required int wentBack,
    DateTime? wentBackOn,
    Set<DateTime> skipped = const {},
    List<PaySchedule> pays = const [],
    String lateWay = 'all',
  }) {
    // The day a bill is counted in: the last payday on or before it is
    // due, since that pay is what has to cover it (owner, 2026-10-24).
    // Rent due 11.01 after the 10.25 pay is asked for in October. With no
    // pay set up, its own date. In a pay period view it lands in the same
    // period either way.
    DateTime asked(DateTime due) {
      DateTime? last;
      for (final s in pays) {
        final d = s.lastOnOrBefore(due);
        if (d != null && (last == null || d.isAfter(last))) last = d;
      }
      return last ?? due;
    }

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
    int atLeast0(int v) => v < 0 ? 0 : v;

    if (plan.kind == PlanKind.each) {
      final cap = plan.rollover ? plan.upTo : null;
      // What one of its own periods wants, counting from what it held
      // when that period began: a capped one asks only for the room
      // left, so a repair this period is asked for from the next one on,
      // not twice over.
      // A period given its own amount asks for that one (#100).
      int wanted(int before, DateTime start) {
        final amount = plan.amountIn(dateOnly(start));
        if (cap == null) return amount;
        final room = cap - before;
        return room <= 0
            ? 0
            : room < amount
            ? room
            : amount;
      }

      // Seen by its own period (the month, or its pay): exact.
      if (pay?.id == by?.id) {
        final start = dateOnly(p.start);
        return PlanLine(
          plan: plan,
          each: plan.amountIn(start),
          planned: wanted(left - assigned + spent, start),
          done: cap != null && left >= cap,
          wentBack: wentBack,
          wentBackOn: wentBackOn,
          once: plan.once.containsKey(start),
          onceFrom: start,
        );
      }
      // Seen by another period (owner, 2026-10-05: a monthly allowance by
      // a fortnight's pay, or a fortnightly one by the month): each of
      // its own periods the span touches still wants its amount less what
      // was put in before the span began, spread by days over the rest
      // of that period, and the span takes its days' share. So the
      // shares add up to the whole over time, and a period already
      // filled asks for nothing more.
      var planned = 0, shared = false;
      final shares = <({DateTime date, int amount})>[];
      var own = budgetPeriod(p.start, pay);
      var walked = 0;
      while (!own.start.isAfter(p.end) && walked++ < _mostPeriods) {
        final from = own.start.isBefore(p.start) ? p.start : own.start;
        final to = own.end.isBefore(p.end) ? own.end : p.end;
        final need = atLeast0(
          wanted(heldBefore(own.start), own.start) -
              assignedIn(own.start, from),
        );
        final share = _daysThrough(from, to),
            rest = _daysThrough(from, own.end);
        final int part;
        if (share >= rest || rest == 0 || need == 0) {
          // All of what's left of that period is in view: the whole.
          part = need;
        } else {
          final cut = _ceilTo(need * share ~/ rest, _shareUnit);
          part = cut > need ? need : cut;
          shared = true;
        }
        planned += part;
        shares.add((date: from, amount: part));
        final next = nextBudgetPeriod(own, pay);
        if (!next.start.isAfter(own.start)) break;
        own = next;
      }
      // A monthly amount seen by a pay: its month's own amount, when it
      // has one, is said as on the month's page (budget review).
      final monthStart = budgetPeriod(p.start, pay).start;
      final monthOnce = pay == null && plan.once.containsKey(monthStart);
      return PlanLine(
        plan: plan,
        each: monthOnce ? plan.amountIn(monthStart) : plan.amount,
        planned: planned,
        once: monthOnce,
        onceFrom: monthStart,
        done: cap != null && left >= cap,
        wentBack: wentBack,
        wentBackOn: wentBackOn,
        // Only a cut share is "about"; the whole of a period's rest is
        // exact.
        approx: shared,
        shares: shares,
      );
    }
    final repeats = plan.repeats;
    DateTime dueOf(int n) => dueAfter(plan, n, pay: pay);
    final first = dueOf(0);

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
    final bill = plan.amount;
    // Bills are numbered from the first the plan could save for: the
    // first due in its first period or later.
    var n0 = 0;
    if (repeats) {
      while (asked(dueOf(n0)).isBefore(begins.start) && n0 < _mostPeriods) {
        n0++;
      }
    }
    final firstNeed = atLeast0(bill - base);
    // Once: the part it asks when kept up with, from its first period.
    final usual = repeats
        ? 0
        : ceilDiv(firstNeed, _periodsThrough(begins, asked(first), by));
    // Once, its date gone: whatever is still missing is wanted now. A goal
    // can keep asking its usual part instead, the person's choice.
    if (!repeats && asked(first).isBefore(p.start)) {
      final put = assignedIn(begins.start, p.start);
      final missing = atLeast0(firstNeed - put);
      final toward = base + put + assigned;
      if (lateWay == 'done') {
        return PlanLine(
          plan: plan,
          each: 0,
          planned: 0,
          due: first,
          done: true,
          usual: usual,
          toward: toward,
          pastDate: true,
          finished: true,
        );
      }
      if (lateWay == 'keep' && missing > 0) {
        final part = usual < missing ? usual : missing;
        return PlanLine(
          plan: plan,
          each: part,
          planned: part,
          due: first,
          usual: usual,
          late: true,
          toward: toward,
          pastDate: true,
        );
      }
      return PlanLine(
        plan: plan,
        each: 0,
        planned: missing,
        overdue: missing,
        due: first,
        done: true,
        usual: usual,
        toward: toward,
        pastDate: true,
      );
    }
    // The bill this period saves for: the first due on or after it
    // starts.
    var n = n0;
    if (repeats) {
      while (asked(dueOf(n)).isBefore(p.start) && n - n0 < _mostPeriods) {
        n++;
      }
      // A bill there won't be ("No bill this time", or paid ahead with
      // the one before): the period saves for the next.
      while (skipped.contains(dueOf(n)) && n - n0 < _mostPeriods) {
        n++;
      }
    }
    final due = dueOf(n);
    // Past its last bill, the plan asks for nothing more.
    if (repeats && over(plan, due, pay: pay)) {
      return PlanLine(
        plan: plan,
        each: 0,
        planned: 0,
        due: lastDue(plan, pay: pay),
        done: true,
        ended: true,
      );
    }
    // Each bill is counted on its own, from the plan's first period or
    // from the period after the one before it was due. So a bill skipped
    // and never owed isn't asked for again, and "short" never grows past
    // one bill.
    // The last bill before it that there was: a skipped one counts from
    // the one before.
    var kept = n - 1;
    while (kept >= n0 && skipped.contains(dueOf(kept))) {
      kept--;
    }
    final from = kept < n0
        ? begins
        : nextBudgetPeriod(budgetPeriod(asked(dueOf(kept)), by), by);
    final int need;
    if (kept < n0) {
      need = firstNeed;
    } else if (kept < n - 1) {
      // Bills skipped since: what the category holds is all toward this
      // one. Left from a bill that didn't come counts for the next (owner,
      // 2026-10-21); a minus from paying ahead is made up by the periods
      // up to it, a bill's worth each.
      need = atLeast0(bill - heldBefore(from.start));
    } else {
      // What a later bill starts from. A minus (the last one cost more
      // than was saved) is added to this one. What's left over isn't
      // counted, since it may be the last bill not paid yet; only what
      // the category held beyond a whole bill when the plan began is.
      final carried = heldBefore(from.start);
      final extra = base - bill * (n - n0);
      need = atLeast0(bill + atLeast0(-carried) - atLeast0(extra));
    }
    // What was assigned toward it before this period, and what's still
    // missing. Counted by what was assigned, not what's left: spending
    // the money on the thing itself (a gift bought early) isn't falling
    // behind.
    final before = assignedIn(from.start, p.start);
    final missing = atLeast0(need - before);
    // What's missing, split over the periods left through the date: a
    // thin period spreads over the rest instead of being asked for all
    // at once. With one period left, that is the rest.
    int partIn(BudgetSpan span, int missing) {
      final part = ceilDiv(missing, _periodsThrough(span, asked(due), by));
      return part > missing ? missing : part;
    }

    final lastPeriod = _periodsThrough(p, asked(due), by) == 1;

    var each = partIn(p, missing);
    // Behind by what last period asked for and didn't get: how far the
    // part had to rise. Kept up with, a part that rose isn't "short"
    // again. The first period has nothing behind it.
    var behind = 0;
    final prev = previousBudgetPeriod(p, by);
    if (!prev.start.isBefore(from.start)) {
      final beforePrev = assignedIn(from.start, prev.start);
      final asked = partIn(prev, atLeast0(need - beforePrev));
      behind = atLeast0(beforePrev + asked - before);
    }
    // More bills due before this period ends (a monthly bill just before
    // a payday that a weekend moved): each is wanted whole.
    if (repeats) {
      var more = 0;
      for (
        var k = n + 1;
        !asked(dueOf(k)).isAfter(p.end) &&
            !over(plan, dueOf(k), pay: pay) &&
            k - n < _mostPeriods;
        k++
      ) {
        if (!skipped.contains(dueOf(k))) more++;
      }
      each += bill * more;
    }
    return PlanLine(
      plan: plan,
      each: each,
      planned: each,
      overdue: behind,
      due: due,
      // Once: it had all of it already, or this period's amount
      // completes it. A bill that comes again is never done.
      done: !repeats && missing - assigned <= 0,
      lastPeriod: lastPeriod,
      usual: usual,
      toward: repeats ? 0 : base + before + assigned,
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

/// How a payment stands against the bill it pays (ADR 0004, "A bill paid
/// another way"): near enough to be the bill, which is taken as paid
/// without asking; for part of it; far less or far more, where the person
/// is asked; or two or three bills' worth at once.
enum BillFit { paid, part, small, more, several }

/// [paid] against a bill of [bill], both in minor units of one currency.
/// Paid is from nine tenths of the bill (a bill a little low owes nothing
/// more) to half again over it (a winter electricity bill); part is from
/// half; two or three bills' worth is within a tenth of that many.
({BillFit fit, int bills}) billFit(int bill, int paid) {
  final b = bill.abs(), p = paid.abs();
  if (b == 0) return (fit: BillFit.paid, bills: 1);
  for (final n in const [2, 3]) {
    if ((p - b * n).abs() * 10 <= b) return (fit: BillFit.several, bills: n);
  }
  if (p * 10 >= b * 9 && p * 2 <= b * 3) return (fit: BillFit.paid, bills: 1);
  if (p * 2 >= b && p < b) return (fit: BillFit.part, bills: 1);
  return (fit: p < b ? BillFit.small : BillFit.more, bills: 1);
}

/// A scheduled bill and the row already in that pays it.
typedef BillPayment = ({
  RegisterRow bill,
  RegisterRow row,
  BillFit fit,
  int bills,
});

/// What part of [r] is in [categoryId]: the row, or its line there.
int _amountIn(RegisterRow r, int categoryId) {
  if (r.categoryId == categoryId) return r.amount;
  for (final l in r.splitLines) {
    if (l.accountId == categoryId) {
      return r.amount < 0 ? -l.amount.abs() : l.amount.abs();
    }
  }
  return 0;
}

final _billPaymentsMemo =
    Expando<Map<(DateTime, int?), Map<int, BillPayment>>>();

/// Each scheduled bill that a row already in pays, by the bill's
/// transaction (owner, 2026-10-21: "Electricity bills only come once per
/// time period. Really any bills. So if any transaction in that category
/// takes place, it should be assumed to be paying that bill"). For a
/// category's bill, the first money-out row in that category (or with a
/// line in it), in any account in its currency, whose date is that bill's
/// ([Budget.billDate], the nearest of the plan's dates), or, the bill
/// being late, any day from the bill's date up to the next bill's. For a
/// bill scheduled by hand, the row [alreadyIn] finds. Soonest bill first,
/// each row once; never a row already tied to a bill, one the person said
/// isn't it ([billNotIt]), a transfer or a payday.
Map<int, BillPayment> billPayments(
  LedgerData data,
  DateTime today, {
  int? uncategorizedId,
}) {
  final memo = _billPaymentsMemo[data] ??= {};
  return memo[(dateOnly(today), uncategorizedId)] ??= () {
    final bills = <RegisterRow>[];
    final posted = <RegisterRow>[];
    for (final a in data.accounts.values) {
      if (a.deleted ||
          (a.type != AccountType.asset && a.type != AccountType.liability)) {
        continue;
      }
      final r = data.registerFor(a.id);
      posted.addAll(r.posted);
      bills.addAll(
        r.scheduled.where(
          (b) =>
              b.amount < 0 &&
              // A card's or loan's payment, scheduled by its category's
              // plan, is a transfer to it.
              (b.kind != RowKind.transfer || b.planCategoryId != null) &&
              b.payScheduleId == null,
        ),
      );
    }
    int byDate(RegisterRow a, RegisterRow b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.txnId.compareTo(b.txnId);
    }

    bills.sort(byDate);
    posted.sort(byDate);
    final loanOf = <int, int>{};
    for (final a in data.accounts.values) {
      final c = a.deleted || !a.isOwed ? null : Budget.loanCategory(data, a.id);
      if (c != null) loanOf[c] = a.id;
    }
    final start = dateOnly(today);
    final taken = <int>{};
    final out = <int, BillPayment>{};
    for (final b in bills) {
      final notIt = billNotIt(data.prefs, b.txnId);
      final plan = switch (b.planCategoryId) {
        final id? => data.plans[id],
        null => null,
      };
      RegisterRow? found;
      var amount = 0;
      if (plan != null && plan.kind == PlanKind.byDate) {
        final pay = data.payScheduleById(plan.payScheduleId);
        // The bill after this one, for how late a late one can be paid.
        DateTime? next;
        if (plan.repeats) {
          for (var n = 0; n < 400; n++) {
            final d = Budget.dueAfter(plan, n, pay: pay);
            if (d.isAfter(b.date)) {
              next = d;
              break;
            }
          }
        }
        // Paying the card or loan whose payments come out of the category
        // pays its bill, as the budget counts it (seen from the card: money
        // in).
        final loan = loanOf[plan.categoryId];
        for (final r in posted) {
          final toLoan =
              loan != null &&
              r.kind == RowKind.transfer &&
              r.accountId == loan &&
              r.amount > 0;
          if (taken.contains(r.txnId) ||
              r.projected ||
              r.currency != b.currency ||
              (r.kind == RowKind.transfer && !toLoan) ||
              r.kind == RowKind.opening ||
              r.planCategoryId != null ||
              r.payScheduleId != null ||
              notIt.contains(r.txnId)) {
            continue;
          }
          final part = toLoan ? -r.amount : _amountIn(r, plan.categoryId);
          if (part >= 0) continue;
          final late =
              b.date.isBefore(start) &&
              !r.date.isBefore(b.date) &&
              (next == null || r.date.isBefore(next));
          if (late || Budget.billDate(plan, r.date, pay: pay) == b.date) {
            found = r;
            amount = part;
            break;
          }
        }
      } else {
        found = alreadyIn(
          b,
          posted.where((p) => !taken.contains(p.txnId)),
          today,
          uncategorizedId: uncategorizedId,
          notIt: notIt,
        );
        amount = found?.amount ?? 0;
      }
      if (found == null) continue;
      var fit = billFit(b.amount, amount);
      // Only a category's bill has bills after it to pay ahead.
      if (fit.fit == BillFit.several && (plan == null || !plan.repeats)) {
        fit = (fit: BillFit.more, bills: 1);
      }
      out[b.txnId] = (bill: b, row: found, fit: fit.fit, bills: fit.bills);
      taken.add(found.txnId);
    }
    return out;
  }();
}

/// A period's pay by currency (#163): what the schedules expect in it,
/// and what has come. Any row filed under a pay's category counts as
/// come, not only a payday the app scheduled, so pay typed or imported
/// is "received" too, as the Income line counts it. [toCome] is what's
/// still expected from [today] on (#234): a payday that passed without its
/// pay isn't counted on, and pay that came early isn't counted twice.
typedef PeriodPay = ({
  Map<Currency, int> expected,
  Map<Currency, int> came,
  Map<Currency, int> toCome,
});

PeriodPay periodPay(
  LedgerData data, {
  required DateTime start,
  required DateTime end,
  required DateTime today,
}) {
  final day = dateOnly(today);
  final expected = <Currency, int>{}, toCome = <Currency, int>{};
  // Each schedule's pay that came in the period: rows tied to it, and
  // money filed under its category into its account, as typed or imported
  // pay is (it isn't tied to the payday). Money in elsewhere, a gift into
  // another account, takes nothing off the pay still due.
  final tied = <int, int>{};
  for (final x in data.txns) {
    if (x.scheduled || x.date.isBefore(start) || x.date.isAfter(end)) {
      continue;
    }
    for (final p in data.paySchedules) {
      if (x.payScheduleId != null && x.payScheduleId != p.id) continue;
      if (x.payScheduleId == null &&
          !x.entries.any((e) => e.accountId == p.categoryId)) {
        continue;
      }
      for (final e in x.entries) {
        if (e.amount > 0 && e.accountId == p.accountId) {
          tied[p.id] = (tied[p.id] ?? 0) + e.amount;
        }
      }
      if (x.payScheduleId != null) break;
    }
  }
  for (final p in data.paySchedules) {
    final c = data.accounts[p.accountId]?.currency ?? Currency.mnt;
    var all = 0, ahead = 0;
    var d = p.nextAfter(DateTime(start.year, start.month, start.day - 1));
    for (var i = 0; i < 40 && !d.isAfter(end); i++) {
      all += p.amountOn(d);
      if (!d.isBefore(day)) ahead += p.amountOn(d);
      d = p.nextAfter(d);
    }
    expected[c] = (expected[c] ?? 0) + all;
    final owed = min(ahead, max(all - (tied[p.id] ?? 0), 0));
    if (owed > 0) toCome[c] = (toCome[c] ?? 0) + owed;
  }
  final moneyIds = {for (final a in data.balanceSheetAccounts) a.id};
  final payCategories = {for (final p in data.paySchedules) p.categoryId};
  final came = <Currency, int>{};
  for (final x in data.txns) {
    if (x.scheduled) continue;
    if (x.payScheduleId == null &&
        !x.entries.any((e) => payCategories.contains(e.accountId))) {
      continue;
    }
    if (x.date.isBefore(start) || x.date.isAfter(end)) continue;
    for (final e in x.entries) {
      if (e.amount > 0 && moneyIds.contains(e.accountId)) {
        came[e.currency] = (came[e.currency] ?? 0) + e.amount;
      }
    }
  }
  return (expected: expected, came: came, toCome: toCome);
}

/// One currency's period against its income (#234, the owner's pick B,
/// 2026-10-27: "we need to help them live within their means"). The
/// income is the period's own, never the balance or an average: what
/// came in, plus the pay still expected. Money put aside counts against
/// it too, since it has to leave the account it's spent from ("The
/// checking account is a dangerous place for money").
///
/// What a category takes from the period: its plan for it (a yearly
/// bill's share), or, with no plan, what's assigned; and what it spends
/// past what it held from before, when that's more. So money saved up in
/// earlier months and spent now isn't counted again, and money already
/// there that's assigned past a plan isn't counted as this period's. A loan
/// paid with no category counts as spent too.
class IncomeFit {
  const IncomeFit({
    required this.currency,
    required this.cameIn,
    required this.toCome,
    required this.spent,
    required this.toSpend,
    required this.putAside,
    required this.sure,
  });

  final Currency currency;

  /// Filed under Income in the period.
  final int cameIn;

  /// Pay the schedules still expect in the period, from today on.
  final int toCome;

  /// Spent so far from the categories that aren't put aside, as far as it
  /// counts against this period.
  final int spent;

  /// What those categories still take past what's spent.
  final int toSpend;

  /// The Safety net and goals.
  final int putAside;

  /// Whether the income is known: the period has ended, or pay is set up
  /// in this currency. Otherwise more may still come, and a shortfall
  /// isn't one yet.
  final bool sure;

  int get income => cameIn + toCome;
  int get takes => spent + toSpend + putAside;

  /// What the period takes past its income; below zero, what it leaves.
  int get over => takes - income;

  /// Each currency with income in the period, or pay set up in it, from
  /// [start] to [end] ([b]'s period), tugrik first; with none, the
  /// budget's own currency when anything is planned. [categories] are the
  /// ones the Budget page counts, archived ones too; [saved] those put
  /// aside.
  static List<IncomeFit> of(
    LedgerData data,
    Budget b,
    Iterable<AccountInfo> categories, {
    required Set<int> saved,
    required DateTime start,
    required DateTime end,
    required DateTime today,
    required PeriodPay pay,
  }) {
    final spent = <Currency, int>{},
        toSpend = <Currency, int>{},
        aside = <Currency, int>{};
    void add(Map<Currency, int> m, Currency c, int v) {
      if (v > 0) m[c] = (m[c] ?? 0) + v;
    }

    for (final c in categories) {
      final l = b.lines[c.id];
      if (l == null) continue;
      final plan = l.plan;
      final asked = plan != null ? plan.planned : max(l.assigned, 0);
      if (saved.contains(c.id) || isGoal(data, c.id)) {
        // Spending from what was put aside is what it was for.
        add(aside, l.currency, asked);
      } else {
        final out = max(l.spent, 0);
        final takes = max<int>(asked, out - max(l.fromBefore, 0));
        final now = min<int>(out, takes);
        add(spent, l.currency, now);
        add(toSpend, l.currency, takes - now);
      }
    }
    // Money out left without a category was spent all the same; it's in
    // no envelope, so count it from the rows. Money in waiting there isn't
    // taken off it.
    final waiting = {
      for (final c in data.categories)
        if (isUncategorized(c)) c.id,
    };
    for (final x in data.txns) {
      if (x.scheduled || x.date.isBefore(start) || x.date.isAfter(end)) {
        continue;
      }
      for (final e in x.entries) {
        if (waiting.contains(e.accountId)) add(spent, e.currency, e.amount);
      }
    }
    // A loan paid from cash or bank with no category, typed as a transfer,
    // left all the same (owner, 2026-10-27: "Anything that leaves the
    // checking account should be tracked and budgeted for"). A bill's row
    // counts in its category, and paying a card isn't counted: the card's
    // purchases already were.
    bool loan(int id) => switch (data.accounts[id]?.role) {
      AccountRole.mortgage || AccountRole.studentLoan => true,
      _ => false,
    };
    for (final x in data.txns) {
      if (x.scheduled || x.planCategoryId != null) continue;
      if (x.date.isBefore(start) || x.date.isAfter(end)) continue;
      final fromMoney = x.entries.any(
        (e) =>
            e.amount < 0 &&
            !loan(e.accountId) &&
            (data.accounts[e.accountId]?.isBalanceSheet ?? false),
      );
      if (!fromMoney) continue;
      for (final e in x.entries) {
        if (loan(e.accountId)) add(spent, e.currency, e.amount);
      }
    }
    final came = b.cameIn[data.income?.id] ?? const <Currency, int>{};
    bool earns(Currency c) => (came[c] ?? 0) > 0 || (pay.expected[c] ?? 0) > 0;
    int takes(Currency c) =>
        (spent[c] ?? 0) + (toSpend[c] ?? 0) + (aside[c] ?? 0);
    final shown = [
      for (final c in Currency.values)
        if (earns(c)) c,
    ];
    if (shown.isEmpty && takes(b.currency) > 0) shown.add(b.currency);
    final ended = dateOnly(today).isAfter(end);
    return [
      for (final c in shown)
        IncomeFit(
          currency: c,
          cameIn: came[c] ?? 0,
          toCome: pay.toCome[c] ?? 0,
          spent: spent[c] ?? 0,
          toSpend: toSpend[c] ?? 0,
          putAside: aside[c] ?? 0,
          sure: ended || (pay.expected[c] ?? 0) > 0,
        ),
    ];
  }
}
