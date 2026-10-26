/// The Savings steps (ADR 0004, rule 25 and "Four Savings steps"): a safety
/// net, no debt but the house, three to six months, saving for the future
/// (owner, 2026-10-09). The current step is the first not done; nothing is
/// locked, and any step can be set aside. Pure Dart: no database, no Flutter.
library;

import 'dart:math' show max;

import 'budget.dart';
import 'ledger.dart';
import 'money.dart';

/// The names are what a ledger keeps a set-aside step under, so the three
/// that came from the six steps before keep theirs.
enum ReadyStep {
  /// The safety net: one month of living expenses, not pay.
  oneMonth,

  /// Every card and loan but the house.
  consumerDebt,

  /// Three to six months, once that debt is gone.
  moreMonths,

  /// Saving for retirement, and paying off the house.
  future,
}

enum ReadyState { done, current, later, setAside }

/// Preference keys the steps keep their answers under.
abstract final class ReadyKeys {
  /// 'yes'; unanswered is not yet. (A ledger from the six steps may also
  /// hold `ready.health`, which nothing reads now.)
  static const retirement = 'ready.retirement';

  /// 'yes': paying the mortgage down on purpose; 'none': there isn't one.
  static const longLoans = 'ready.longLoans';

  /// The debt to pay extra on, by account id; unset is the smallest.
  static const target = 'ready.target';

  /// From the build before Safety net was built in: the id of a category
  /// the user made for it. Read once, to make that one the app's own.
  static const fundCategories = 'ready.fundCategories';

  /// A month of expenses the user typed, in minor units; overrides the
  /// average.
  static const month = 'ready.month';

  /// How many months the bigger fund aims for, 3 to 6. Starts at 3.
  static const months = 'ready.months';

  /// Steps set aside, by name, comma separated.
  static const setAside = 'ready.setAside';

  /// A card's or loan's interest rate, as [DebtRate.value] writes it:
  /// `2 month`, `24 year`. Kept by account id, so a rename keeps it.
  static String rate(int accountId) => 'ready.rate.$accountId';

  /// 'yes': the category is left out of a month of expenses (owner,
  /// 2026-10-26: "an option on each category where if checked, it counts
  /// towards the 1 month expense total"). Unset counts, so a ledger from
  /// before keeps its month. Kept by category id.
  static String leftOut(int categoryId) => 'ready.out.$categoryId';
}

/// Whether category [id] counts in a month of expenses ([ReadyKeys.leftOut]).
bool inMonthOfExpenses(LedgerData data, int id) =>
    data.prefs[ReadyKeys.leftOut(id)] != 'yes';

/// A card's or loan's interest rate, as the person reads it off the bank:
/// a month's or a year's (owner, 2026-10-14: "something that works in both
/// the US and in Mongolia").
typedef DebtRate = ({double percent, bool perYear});

extension DebtRateValue on DebtRate {
  /// How it is stored under [ReadyKeys.rate].
  String get value => '${ratePercent(percent)} ${perYear ? 'year' : 'month'}';

  /// What it costs a month on [owed]: a year's rate is spread over twelve.
  int interestOn(int owed) =>
      (owed * percent / 100 / (perYear ? 12 : 1)).round();
}

/// Reads [ReadyKeys.rate]'s value; null for none or one that doesn't read.
DebtRate? parseDebtRate(String? s) {
  final parts = (s ?? '').trim().split(' ');
  if (parts.length != 2) return null;
  final percent = parseRatePercent(parts[0]);
  if (percent == null) return null;
  return switch (parts[1]) {
    'month' => (percent: percent, perYear: false),
    'year' => (percent: percent, perYear: true),
    _ => null,
  };
}

/// A percent as typed: `2`, `1.4`, `1,4`, with or without `%`. Null for
/// anything else, or below zero.
double? parseRatePercent(String s) {
  final m = RegExp(r'^(\d+(?:[.,]\d+)?)\s*%?$').firstMatch(s.trim());
  if (m == null) return null;
  final v = double.tryParse(m[1]!.replaceAll(',', '.'));
  // Past 1000% it isn't a rate anyone is charged: the field says so, and
  // what it costs a month stays a number that fits.
  return v == null || v < 0 || v > 1000 || v.isNaN ? null : v;
}

/// A percent as a person writes it: `2`, `1.4`, `24.99`.
String ratePercent(double p) {
  final s = p.toStringAsFixed(2);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// A month's rate this high is most likely a year's typed under "a month".
/// Pawnshops and some non-bank lenders do charge up to about 10% a month,
/// so below 15% it isn't questioned (budget review, 2026-10-26).
bool rateLooksYearly(DebtRate r) => !r.perYear && r.percent > 15;

/// A tugrik debt's year rate this low is most likely a month's.
bool rateLooksMonthly(DebtRate r, Currency c) =>
    r.perYear && c == Currency.mnt && r.percent > 0 && r.percent < 3;

/// Whole units said the way a person says "about": two figures, so
/// 47,836 is 48,000 and 41 stays 41.
int roundAbout(int units) {
  var step = 1;
  while (units.abs() / step >= 100) {
    step *= 10;
  }
  return (units / step).round() * step;
}

/// Where a new card's or loan's rate starts: tugrik rates are said by the
/// month ("сарын хүү"), others by the year. A switch beside it changes it.
bool ratePerYearFor(Currency c) => c != Currency.mnt;

typedef Debt = ({AccountInfo account, int owed});

/// What a month of living costs: the figure typed, else what the budget
/// holds for this month, else the average of what was spent (owner,
/// 2026-10-09: "pull it from the budget and let them adjust it"). [amount]
/// is 0 while it isn't known: nothing typed, nothing budgeted and under
/// [minDays] of history.
class MonthOfSpending {
  const MonthOfSpending({
    required this.amount,
    required this.typed,
    required this.days,
    required this.spent,
    this.loanPayments = 0,
    this.fromBudget = false,
    this.inBudget = 0,
  });

  final int amount;

  /// [amount] is what the budget holds for this month ([budgeted]).
  final bool fromBudget;

  /// What the budget holds for this month, typed month or not: a typed
  /// month the budget has outgrown is said (budget review, 2026-10-26).
  final int inBudget;

  /// A typed month more than a tenth under what the budget now holds.
  bool get outgrown => typed && inBudget * 10 > amount * 11;

  /// Of [spent], paid into a mortgage or student loan: a bill that has to
  /// keep being paid, though it's a transfer and not spending.
  final int loanPayments;

  /// Typed by the user rather than averaged.
  final bool typed;

  /// Days of history the average covers (up to [spanDays]).
  final int days;

  /// Spent in those days.
  final int spent;

  static const spanDays = 91;
  static const minDays = 28;

  /// What the budget holds for the calendar month [today] is in: for each
  /// spending category in [main] that isn't archived, what its plan asks
  /// for the month or what is assigned to it, whichever is more (a month
  /// half assigned still counts the plan; a category with no plan counts
  /// what it was given this month or last, whichever is more). A card or loan payment budgeted as a category is
  /// in it like rent. A category that holds the safety net isn't an
  /// expense, so it's left out, as is one the person left out
  /// ([inMonthOfExpenses]). 0 when nothing is budgeted.
  static int budgeted(
    LedgerData data,
    DateTime today,
    Currency main, {
    Budget? budget,
  }) {
    budget ??= monthBudget(data, today);
    // A category with no plan is assigned as the month goes: last month's
    // too, so the month doesn't fall on the 1st, before payday's assigning
    // (budget review, 2026-10-26).
    final day = dateOnly(today);
    final last = monthBudget(data, DateTime(day.year, day.month, 0));
    final fund = fundCategoryIds(data, main);
    var sum = 0;
    for (final MapEntry(key: id, value: line) in budget.lines.entries) {
      if (line.currency != main || data.accounts[id]!.archived) continue;
      if (fund.contains(id) || !inMonthOfExpenses(data, id)) continue;
      final planned = line.plan?.planned ?? 0;
      final before = line.plan == null ? last.lines[id]?.assigned ?? 0 : 0;
      final most = [planned, line.assigned, before].reduce(max);
      if (most > 0) sum += most;
    }
    return sum;
  }

  /// Spending categories' posted rows over the last three months (or since
  /// the first one, so an opening balance dated months earlier doesn't
  /// thin the average), scaled to an average month and rounded up to a whole
  /// unit. Payments into a mortgage or student loan count too. Refunds count
  /// against spending; other transfers, card payments (the card's own
  /// spending already counts) and opening balances don't.
  static MonthOfSpending of(LedgerData data, DateTime today, {Budget? budget}) {
    final main = savingsCurrency(data);
    final typed = typedMonth(data.prefs[ReadyKeys.month], main);
    final end = dateOnly(today);
    bool spending(EntryData e) =>
        e.currency == main &&
        data.accounts[e.accountId]?.type == AccountType.expense &&
        inMonthOfExpenses(data, e.accountId);
    bool loanPayment(TxnData t, EntryData e) {
      final a = data.accounts[e.accountId];
      return a != null &&
          e.currency == main &&
          e.amount > 0 &&
          (a.role == AccountRole.mortgage ||
              a.role == AccountRole.studentLoan) &&
          t.entries.any(
            (o) => o.id != e.id && data.accounts[o.accountId]!.isBalanceSheet,
          );
    }

    DateTime? first;
    for (final t in data.txns) {
      if (t.scheduled) continue;
      if (!t.entries.any((e) => spending(e) || loanPayment(t, e))) continue;
      if (first == null || t.date.isBefore(first)) first = t.date;
    }
    var start = end.subtract(const Duration(days: spanDays - 1));
    if (first != null && first.isAfter(start)) start = first;
    final days = first == null || start.isAfter(end)
        ? 0
        : DateTime.utc(end.year, end.month, end.day)
                  .difference(DateTime.utc(start.year, start.month, start.day))
                  .inDays +
              1;
    var spent = 0, loans = 0;
    for (final t in data.txns) {
      if (t.scheduled || t.date.isBefore(start) || t.date.isAfter(end)) {
        continue;
      }
      for (final e in t.entries) {
        if (spending(e)) spent += e.amount;
        if (loanPayment(t, e)) loans += e.amount;
      }
    }
    spent += loans;
    final inBudget = budgeted(data, today, main, budget: budget);
    if (typed != null && typed > 0) {
      return MonthOfSpending(
        amount: typed,
        typed: true,
        days: days,
        spent: spent,
        loanPayments: loans,
        inBudget: inBudget,
      );
    }
    if (inBudget > 0) {
      return MonthOfSpending(
        amount: inBudget,
        typed: false,
        fromBudget: true,
        days: days,
        spent: spent,
      );
    }
    if (days < minDays || spent <= 0) {
      return MonthOfSpending(
        amount: 0,
        typed: false,
        days: days,
        spent: spent,
        loanPayments: loans,
      );
    }
    // A month is 365.25 / 12 = 1461 / 48 days; whole units, rounded up, in
    // integers so an exact month doesn't gain a unit.
    // BigInt: spending in the trillions would overflow spent * 1461.
    final per = BigInt.from(48 * days * main.scale);
    final units =
        (BigInt.from(spent) * BigInt.from(1461) + per - BigInt.one) ~/ per;
    return MonthOfSpending(
      amount: units.toInt() * main.scale,
      typed: false,
      days: days,
      spent: spent,
      loanPayments: loans,
    );
  }
}

/// The budget for the calendar month [today] is in, as of today.
Budget monthBudget(LedgerData data, DateTime today) {
  final day = dateOnly(today);
  return Budget.of(
    data,
    start: DateTime(day.year, day.month),
    end: DateTime(day.year, day.month + 1, 0),
    today: day,
  );
}

/// The app's own Safety net category (owner, 2026-10-09: "a dedicated
/// safety net category built into the app"): the spending category marked
/// [AccountRole.emergencyFund]. What is left in it is the safety net; an
/// account is only where the money sits.
bool isSafetyNet(AccountInfo a) =>
    a.type == AccountType.expense &&
    a.role == AccountRole.emergencyFund &&
    !a.deleted;

/// The Safety net category, when it counts in [main]. A set, as the rest
/// was written for: there is one.
Set<int> fundCategoryIds(LedgerData data, Currency main) => {
  for (final a in data.accounts.values)
    if (isSafetyNet(a) && !a.archived && a.currency == main) a.id,
};

/// A month of expenses the user typed, stored as `MNT:300000000` (a bare
/// number is from before currencies, in tugrik). Null when it's in another
/// currency than Savings counts in now.
int? typedMonth(String? stored, Currency main) {
  if (stored == null) return null;
  final parts = stored.split(':');
  final currency = parts.length == 2
      ? Currency.fromCode(parts[0])
      : Currency.mnt;
  if (currency != main) return null;
  return int.tryParse(parts.last);
}

/// The currency Savings counts in: the Safety net category's, so a new
/// account in another currency doesn't move the page (budget review,
/// 2026-10-26); before there is one, [mainCurrency].
Currency savingsCurrency(LedgerData data) =>
    data.accounts.values
        .where((a) => isSafetyNet(a) && !a.archived)
        .firstOrNull
        ?.currency ??
    mainCurrency(data);

/// The currency most open accounts are in; on
/// a tie, the first in the list (tugrik, then dollars, then by code). Accounts in the other currency aren't in its sums (the page says
/// so) until the owner decides how Savings treats two currencies.
Currency mainCurrency(LedgerData data) {
  final n = <Currency, int>{};
  for (final a in data.openAccounts) {
    n[a.currency] = (n[a.currency] ?? 0) + 1;
  }
  var main = Currency.mnt;
  for (final c in Currency.values) {
    if ((n[c] ?? 0) > (n[main] ?? 0)) main = c;
  }
  return main;
}

class Readiness {
  Readiness._({
    required this.month,
    required this.fundCategories,
    required this.keptIn,
    required this.keptThere,
    required this.notAssigned,
    required this.overAssigned,
    required this.billsToAssign,
    required this.fundAssigned,
    required this.held,
    required this.fund,
    required this.consumerDebts,
    required this.longLoans,
    required this.monthsTarget,
    required this.retirement,
    required this.longAnswer,
    required this.setAside,
    required this.longMarked,
    required this.carriedSince,
    required this.looksPaidInFull,
    required this.target,
    required this.rates,
  });

  factory Readiness.of(LedgerData data, DateTime today) {
    // Archived accounts are out of the picker and the lists, so they're out
    // of the sums too: nothing counts that can't be seen and changed. One
    // currency, never added across (ROADMAP E).
    final main = savingsCurrency(data);
    final open = [
      for (final a in data.openAccounts)
        if (a.currency == main) a,
    ];
    List<Debt> owed(bool Function(AccountInfo) which) => [
      for (final a in open)
        if (a.isOwed && which(a) && data.balanceOf(a.id) < 0)
          (account: a, owed: -data.balanceOf(a.id)),
    ]..sort((a, b) => a.owed.compareTo(b.owed));
    // Only the house waits for the last step (owner: "credit cards,
    // vehicles, not house"), so a student loan is debt to pay off now.
    const long = {AccountRole.mortgage};
    final months = int.tryParse(data.prefs[ReadyKeys.months] ?? '') ?? 3;
    final consumer = owed(
      (a) => !long.contains(a.role) && a.role != AccountRole.paidMonthly,
    );
    final targetId = int.tryParse(data.prefs[ReadyKeys.target] ?? '');
    final budget = monthBudget(data, today);
    // Not assigned in the currency Savings counts in, whichever the
    // Budget page began with.
    final free = budget.pools
        .where((p) => p.currency == main)
        .fold(0, (s, p) => s + p.notAssigned);
    // What each spending category holds today; one overspent holds nothing.
    final held = {
      for (final MapEntry(key: id, value: line) in budget.lines.entries)
        id: line.left > 0 ? line.left : 0,
    };
    final fundCategories = [
      for (final id in fundCategoryIds(data, main)) data.accounts[id]!,
    ];
    final fund = fundCategories.fold(0, (s, c) => s + (held[c.id] ?? 0));
    // Where it sits, when the category is paid from only some accounts.
    final banks = [
      for (final a in open)
        if (!a.isOwed) a,
    ];
    final off = fundCategories.length == 1
        ? data.accountsOff[fundCategories.single.id] ?? const <int>{}
        : const <int>{};
    final keptIn = [
      for (final a in banks)
        if (!off.contains(a.id)) a,
    ];
    final limited = keptIn.isNotEmpty && keptIn.length < banks.length;
    final there = keptIn.fold(0, (s, a) => s + data.balanceOf(a.id));
    return Readiness._(
      longMarked: open.any((a) => a.isOwed && long.contains(a.role)),
      carriedSince: {
        for (final a in open)
          if (a.isOwed &&
              a.role == AccountRole.paidMonthly &&
              data.balanceOf(a.id) < 0)
            if (_paying(data, a.id, dateOnly(today)) case (
              paid: false,
              :final since,
            ))
              a.id: since,
      },
      looksPaidInFull: {
        for (final d in consumer)
          if (_paying(data, d.account.id, dateOnly(today))?.paid ?? false)
            d.account.id,
      },
      rates: {
        for (final a in open)
          if (a.isOwed) a.id: ?parseDebtRate(data.prefs[ReadyKeys.rate(a.id)]),
      },
      target:
          consumer.where((d) => d.account.id == targetId).firstOrNull ??
          consumer.firstOrNull,
      month: MonthOfSpending.of(data, today, budget: budget),
      fundCategories: fundCategories,
      keptIn: limited ? keptIn : const [],
      keptThere: limited ? there.clamp(0, fund) : 0,
      notAssigned: free > 0 ? free : 0,
      overAssigned: free < 0 ? -free : 0,
      billsToAssign: [
        for (final line in budget.lines.values)
          if (line.currency == main &&
              line.plan?.due != null &&
              line.plan!.planned > line.assigned)
            line.plan!.planned - line.assigned,
      ].fold(0, (s, v) => s + v),
      fundAssigned: fundCategories.length == 1
          ? budget.lines[fundCategories.single.id]?.assigned ?? 0
          : 0,
      held: held,
      fund: fund,
      consumerDebts: consumer,
      longLoans: owed((a) => long.contains(a.role)),
      monthsTarget: months.clamp(3, 6),
      retirement: data.prefs[ReadyKeys.retirement] == 'yes',
      longAnswer: switch (data.prefs[ReadyKeys.longLoans]) {
        'yes' => true,
        'none' => !open.any((a) => a.isOwed && long.contains(a.role)),
        _ => false,
      },
      setAside: {
        for (final n in (data.prefs[ReadyKeys.setAside] ?? '').split(','))
          for (final s in ReadyStep.values)
            if (s.name == n) s,
      },
    );
  }

  final MonthOfSpending month;

  /// The app's Safety net category ([isSafetyNet]). A bank account marked
  /// as the fund's under the first build is no longer counted: its mark
  /// stays in the ledger unread.
  final List<AccountInfo> fundCategories;

  /// The accounts the safety net's category is paid from, when that is
  /// only some of the bank and cash accounts: where it is kept. Empty when
  /// it uses them all.
  final List<AccountInfo> keptIn;

  /// How much of [fund] is in [keptIn] already; the rest is still to move.
  final int keptThere;

  /// Money in the budget not assigned to any category, when there is some.
  final int notAssigned;

  /// How much more the budget has assigned than there is in cash and bank:
  /// the safety net's Left may not all be there (owner, 2026-10-26: keep
  /// the check, and say so).
  final int overAssigned;

  /// What this month's bills on the Budget page still ask to be assigned:
  /// the safety net isn't offered their money (budget review, 2026-10-26).
  final int billsToAssign;

  /// What [step]'s Assign offers the safety net: what's not assigned less
  /// the bills' share, no more than fills it; 0 while a month isn't known.
  int offerFor(ReadyStep step) {
    final toGo = targetOf(step) - fund;
    if (targetOf(step) == 0 || toGo <= 0) return 0;
    final spare = notAssigned - billsToAssign;
    return spare <= 0 ? 0 : (spare < toGo ? spare : toGo);
  }

  /// Assigned to the safety net's category this calendar month.
  final int fundAssigned;

  /// What each spending category holds today, never below zero.
  final Map<int, int> held;
  int heldIn(int categoryId) => held[categoryId] ?? 0;

  /// There is a category for it.
  bool get hasFund => fundCategories.isNotEmpty;

  /// What's left in the safety net's category.
  final int fund;

  /// Cards and loans owing, smallest first: debt to pay off unless marked a
  /// mortgage, or a card paid in full every month.
  final List<Debt> consumerDebts;

  /// Mortgages owing.
  final List<Debt> longLoans;
  final int monthsTarget;

  /// The user says they are saving for retirement.
  final bool retirement;

  /// The user says there is no mortgage (and none is marked), or that they
  /// are paying extra on it.
  final bool longAnswer;
  final Set<ReadyStep> setAside;

  /// Some card or loan is marked a mortgage.
  final bool longMarked;

  /// Cards marked paid in full every month that haven't paid off what they
  /// owed five weeks ago: since when a balance has carried. A warning, not
  /// a reclassing.
  final Map<int, DateTime> carriedSince;

  /// Debts to pay off that have paid off what they owed five weeks ago:
  /// cards that may be paid in full every month, not yet marked so. Left
  /// out of "pay only the minimums", which would start interest on them.
  final Set<int> looksPaidInFull;

  /// The consumer debt to pay extra on: the one picked, or the smallest.
  final Debt? target;

  /// How a card has been paid lately: [_carryDays] days ago it owed
  /// something, and what has been paid in since covers it (paid in full by
  /// statement, though new purchases mean it never reads zero) or doesn't.
  /// Null when it owed nothing then. [since] is the day after it last owed
  /// nothing (or its first row): when a balance started carrying.
  static const _carryDays = 35;

  static ({bool paid, DateTime since})? _paying(
    LedgerData data,
    int id,
    DateTime today,
  ) {
    final rows = <(DateTime, int)>[];
    for (final t in data.txns) {
      if (t.scheduled || t.date.isAfter(today)) continue;
      for (final e in t.entries) {
        if (e.accountId == id) rows.add((dateOnly(t.date), e.amount));
      }
    }
    if (rows.isEmpty) return null;
    rows.sort((a, b) => a.$1.compareTo(b.$1));
    final cut = DateTime(today.year, today.month, today.day - _carryDays);
    var then = 0, paidSince = 0, balance = 0;
    DateTime? lastClear;
    for (var i = 0; i < rows.length; i++) {
      final (day, amount) = rows[i];
      balance += amount;
      if (day.isAfter(cut)) {
        if (amount > 0) paidSince += amount;
      } else {
        then = balance;
      }
      final endOfDay = i == rows.length - 1 || rows[i + 1].$1 != day;
      if (endOfDay && balance >= 0) lastClear = day;
    }
    if (then >= 0) return null;
    final since = lastClear == null
        ? rows.first.$1
        : DateTime(lastClear.year, lastClear.month, lastClear.day + 1);
    return (paid: paidSince >= -then, since: since);
  }

  /// Each card's and loan's rate the person gave, by account id.
  final Map<int, DebtRate> rates;

  /// What [d] costs a month in interest; null without a rate.
  int? interestOf(Debt d) => rates[d.account.id]?.interestOn(d.owed);

  /// The debts to pay off in the order step 2 lists them: once two or more
  /// have a rate, the one costing the most interest a month first, those
  /// without a rate last; otherwise smallest first, as before.
  List<Debt> get debtsByCost {
    // One rate has nothing to rank against: smallest first, as before.
    if (consumerDebts.where((d) => interestOf(d) != null).length < 2) {
      return consumerDebts;
    }
    final order = {for (final (i, d) in consumerDebts.indexed) d.account.id: i};
    int compare(Debt a, Debt b) {
      final x = interestOf(a), y = interestOf(b);
      final byCost = x == null || y == null
          ? (x == null ? 1 : 0) - (y == null ? 1 : 0)
          : y.compareTo(x);
      // Equal ones keep smallest first.
      return byCost != 0
          ? byCost
          : order[a.account.id]!.compareTo(order[b.account.id]!);
    }

    return [...consumerDebts]..sort(compare);
  }

  /// The debts with a rate that costs something, most first.
  List<Debt> get ratedByCost => [
    for (final d in debtsByCost)
      if ((interestOf(d) ?? 0) > 0) d,
  ];

  /// The debt costing the most interest a month, when two or more have a
  /// rate to compare; otherwise there is nothing to say.
  Debt? get costliest {
    final rated = ratedByCost;
    return rated.length >= 2 ? rated.first : null;
  }

  int get consumerOwed => consumerDebts.fold(0, (s, d) => s + d.owed);
  int get longOwed => longLoans.fold(0, (s, d) => s + d.owed);

  /// What each fund step aims for; 0 while a month isn't known.
  int targetOf(ReadyStep s) => switch (s) {
    ReadyStep.oneMonth => month.amount,
    ReadyStep.moreMonths => month.amount * monthsTarget,
    _ => 0,
  };

  bool isDone(ReadyStep s) => switch (s) {
    ReadyStep.oneMonth ||
    ReadyStep.moreMonths => targetOf(s) > 0 && hasFund && fund >= targetOf(s),
    ReadyStep.consumerDebt => consumerDebts.isEmpty,
    ReadyStep.future => retirement && mortgageDone,
  };

  /// Nothing marked isn't "paid off": the mortgage may just not be kept
  /// here. Done when there's none, when it's paid, or when paying extra.
  bool get mortgageDone => (longMarked && longLoans.isEmpty) || longAnswer;

  /// The first step not done and not set aside; null when all are.
  late final ReadyStep? current = ReadyStep.values
      .where((s) => !isDone(s) && !setAside.contains(s))
      .firstOrNull;

  ReadyState stateOf(ReadyStep s) => isDone(s)
      ? ReadyState.done
      : setAside.contains(s)
      ? ReadyState.setAside
      : s == current
      ? ReadyState.current
      : ReadyState.later;

  /// The set-aside list with [s] added or taken out, for the preference.
  String? setAsideWith(ReadyStep s, bool aside) =>
      setAsideIn(setAside, s, aside);

  /// [stored] (as [ReadyKeys.setAside] holds it) with [s] added or taken
  /// out.
  static String? setAsideStored(String? stored, ReadyStep s, bool aside) =>
      setAsideIn(
        {
          for (final n in (stored ?? '').split(','))
            for (final x in ReadyStep.values)
              if (x.name == n) x,
        },
        s,
        aside,
      );

  static String? setAsideIn(Set<ReadyStep> setAside, ReadyStep s, bool aside) {
    final next = {...setAside};
    aside ? next.add(s) : next.remove(s);
    return next.isEmpty
        ? null
        : [
            for (final x in ReadyStep.values)
              if (next.contains(x)) x.name,
          ].join(',');
  }
}
