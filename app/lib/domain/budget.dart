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
    this.offSpent = 0,
    this.offAccounts = const [],
    this.backing,
  });

  /// The currency the category is in (rule 28): its amounts, its plan,
  /// and the only spending that counts against it.
  final Currency currency;

  /// Rows filed under it in another currency since the budget began,
  /// which aren't counted (they stay until they're fixed): how many, what
  /// they add up to, and in what.
  final int otherRows;
  final int otherAmount;
  final Currency? otherCurrency;

  /// This period's spending paid from accounts it doesn't keep its money
  /// in (it still counts), and those accounts. Less whatever was moved
  /// into them this period from an account it does use: money moved to
  /// cover a payment isn't worth a note.
  final int offSpent;
  final List<int> offAccounts;

  /// Set when it keeps its money in only some accounts and they hold
  /// less than is left in the categories kept there: what's left in
  /// them, in how many categories (this one included), and what the
  /// accounts hold. As of today.
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

/// One currency's money in the budget (rule 28): tugrik and dollars are
/// never added together.
class BudgetPool {
  const BudgetPool({
    required this.currency,
    required this.money,
    required this.notAssigned,
    required this.uncategorizedRows,
    required this.uncategorizedNet,
  });
  final Currency currency;

  /// Cash and bank in this currency, less what its cards owe.
  final int money;

  /// [money] less what sits in this currency's categories, as of today.
  final int notAssigned;

  /// Posted rows in "Not categorized" in this currency, and their sum.
  final int uncategorizedRows;
  final int uncategorizedNet;
}

class Budget {
  Budget._({
    required this.currency,
    required this.began,
    required this.lines,
    required this.cameIn,
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

  /// In [currency]: what the user has, less what's in the categories, as
  /// of today, with every amount assigned counted, a later period's too.
  /// Negative when more was assigned than there is, or cards owe more
  /// than there is.
  int get notAssigned => _main.notAssigned;

  /// What [notAssigned] starts from: cash and bank, less what cards owe.
  int get money => _main.money;

  /// Posted rows in "Not categorized", and what they add up to (negative:
  /// money out). Both already count in [notAssigned].
  int get uncategorizedRows => _main.uncategorizedRows;
  int get uncategorizedNet => _main.uncategorizedNet;

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
    Currency currencyOfCategory(int id) => data.accounts[id]!.currency;
    // A long loan's payments are its category's spending, when the two
    // are in the same currency.
    final loans = <int, int>{};
    for (final a in data.accounts.values) {
      if (a.deleted || !isLongLoan(a)) continue;
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
    final cameIn = <int, Map<Currency, int>>{};
    final uncategorizedRows = <Currency, int>{};
    final uncategorizedNet = <Currency, int>{};
    final otherRows = <int, int>{}, otherAmount = <int, int>{};
    final otherCurrency = <int, Currency>{};
    // By category, what each account it doesn't use paid this period;
    // and what was moved between accounts this period, by (from, to).
    final offPaid = <int, Map<int, int>>{};
    final moved = <(int, int), int>{};
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

    // A category whose currency was changed counts from that period on.
    final countsFrom = <int, DateTime>{
      for (final id in envelopes)
        if (data.prefs['${BudgetKeys.fromPrefix}$id'] case final String day)
          id: parseDateKey(day),
    };

    for (final t in data.txns) {
      if (t.scheduled) continue;
      final d = dateOnly(t.date);
      final budgetBegun = began != null && !d.isBefore(began);
      // A plain move between two of the user's accounts this period.
      if (within(d) && t.entries.length == 2) {
        final a = t.entries[0], b = t.entries[1];
        if (a.currency == b.currency &&
            (data.accounts[a.accountId]?.isBalanceSheet ?? false) &&
            (data.accounts[b.accountId]?.isBalanceSheet ?? false)) {
          final (from, to) = a.amount < 0 ? (a, b) : (b, a);
          final key = (from.accountId, to.accountId);
          moved[key] = (moved[key] ?? 0) + to.amount;
        }
      }
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
          uncategorizedRows[x.currency] =
              (uncategorizedRows[x.currency] ?? 0) + 1;
          uncategorizedNet[x.currency] =
              (uncategorizedNet[x.currency] ?? 0) - x.amount;
        } else if (envelopes.contains(a.id)) {
          final from = countsFrom[a.id];
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
          spend(a.id, d, x.amount, counted);
          // Paid from an account it doesn't use: counted all the same.
          final off = data.accountsOff[a.id];
          if (off != null && counted && within(d)) {
            for (final y in t.entries) {
              if (off.contains(y.accountId)) {
                final paid = offPaid.putIfAbsent(a.id, () => {});
                paid[y.accountId] = (paid[y.accountId] ?? 0) + x.amount;
                break;
              }
            }
          }
        } else if (loans[a.id] case final c?
            when x.amount > 0 && fromMoney(x.currency)) {
          // A payment into a long loan, from money that counts.
          final from = countsFrom[c];
          spend(
            c,
            d,
            x.amount,
            budgetBegun && (from == null || !d.isBefore(from)),
          );
        }
      }
    }

    for (final changes in dated.values) {
      changes.sort((a, b) => a.date.compareTo(b.date));
    }
    final BudgetSpan viewed = (start: s, end: e, label: '');
    final current = budgetPeriod(today, by);

    final lines = <int, EnvelopeLine>{};
    final held = <Currency, int>{}, holding = <int, int>{};
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
        currency: currency,
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
                began: began,
                assigned: assigned[id] ?? 0,
                left: left,
                spent: counted,
                wentBack: wentBack,
              ),
      );
      held[currency] = (held[currency] ?? 0) + holds;
      holding[id] = holds;
      if (currency == main && (assignedBy[id] ?? 0) == 0 && counted > 0) {
        unassignedCount++;
        unassignedAmount += counted;
      }
    }

    // The accounts a category uses: those in its currency it hasn't
    // unchecked, cards included (a bill can be planned for the Visa).
    // Its money is kept in the cash and bank ones among them: a card
    // holds none.
    Set<int> used(int id, {bool moneyOnly = false}) {
      final off = data.accountsOff[id] ?? const <int>{};
      final c = currencyOfCategory(id);
      return {
        for (final a in data.accounts.values)
          if (counts(a, c) &&
              (!moneyOnly || a.type == AccountType.asset) &&
              !off.contains(a.id))
            a.id,
      };
    }

    // Limited only by an account still in use: one unchecked and later
    // archived or deleted limits nothing anyone can see.
    bool limits(int id, int account) {
      final a = data.accounts[account];
      return a != null && !a.archived && counts(a, currencyOfCategory(id));
    }

    final limited = {
      for (final id in envelopes)
        if (data.accountsOff[id]?.any((a) => limits(id, a)) ?? false)
          id: used(id),
    };
    for (final MapEntry(key: id, value: accounts) in limited.entries) {
      // Paid from an account it doesn't use, less what was moved there
      // this period from one it does (the card paid, cash taken out).
      var offSpent = 0;
      final offAccounts = <int>[];
      for (final MapEntry(key: account, value: paid)
          in (offPaid[id] ?? const <int, int>{}).entries) {
        var covered = 0;
        for (final a in accounts) {
          covered += moved[(a, account)] ?? 0;
        }
        if (paid > covered) {
          offSpent += paid - covered;
          offAccounts.add(account);
        }
      }
      // It can't hold more than its cash and bank accounts do. Others
      // kept in the same ones (or fewer of them) share them. One that
      // uses only cards keeps its money nowhere in particular, so
      // there's nothing to compare.
      ({int setAside, int categories, int have})? backing;
      final kept = used(id, moneyOnly: true);
      if ((holding[id] ?? 0) > 0 && kept.isNotEmpty) {
        var have = 0, setAside = 0, categories = 0;
        for (final a in kept) {
          have += data.balanceOf(a);
        }
        for (final other in limited.keys) {
          final theirs = used(other, moneyOnly: true);
          if (currencyOfCategory(other) == currencyOfCategory(id) &&
              theirs.isNotEmpty &&
              kept.containsAll(theirs) &&
              (holding[other] ?? 0) > 0) {
            setAside += holding[other]!;
            categories++;
          }
        }
        if (setAside > have) {
          backing = (setAside: setAside, categories: categories, have: have);
        }
      }
      if (offSpent == 0 && backing == null) continue;
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
        offSpent: offSpent,
        offAccounts: offAccounts,
        backing: backing,
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
            uncategorizedRows: uncategorizedRows[c] ?? 0,
            uncategorizedNet: uncategorizedNet[c] ?? 0,
          );
        }(),
    ];

    return Budget._(
      currency: main,
      began: began,
      lines: lines,
      cameIn: cameIn,
      pools: pools,
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
