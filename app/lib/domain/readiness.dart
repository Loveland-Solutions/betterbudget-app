/// The Savings steps (ADR 0004, rule 25 and "Four Savings steps"): a safety
/// net, no debt but the house, three to six months, saving for the future
/// (owner, 2026-10-09). The current step is the first not done; nothing is
/// locked, and any step can be set aside. Pure Dart: no database, no Flutter.
library;

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
}

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
  });

  final int amount;

  /// [amount] is what the budget holds for this month ([budgeted]).
  final bool fromBudget;

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
  /// what it was given). A card or loan payment budgeted as a category is
  /// in it like rent. A category that holds the safety net isn't an
  /// expense, so it's left out. 0 when nothing is budgeted.
  static int budgeted(
    LedgerData data,
    DateTime today,
    Currency main, {
    Budget? budget,
  }) {
    budget ??= monthBudget(data, today);
    final fund = fundCategoryIds(data, main);
    var sum = 0;
    for (final MapEntry(key: id, value: line) in budget.lines.entries) {
      if (line.currency != main || data.accounts[id]!.archived) continue;
      if (fund.contains(id)) continue;
      final planned = line.plan?.planned ?? 0;
      final most = planned > line.assigned ? planned : line.assigned;
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
    final typed = typedMonth(data.prefs[ReadyKeys.month], mainCurrency(data));
    final end = dateOnly(today);
    final main = mainCurrency(data);
    bool spending(EntryData e) =>
        e.currency == main &&
        data.accounts[e.accountId]?.type == AccountType.expense;
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
    if (typed != null && typed > 0) {
      return MonthOfSpending(
        amount: typed,
        typed: true,
        days: days,
        spent: spent,
        loanPayments: loans,
      );
    }
    final inBudget = budgeted(data, today, main, budget: budget);
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
    final per = 48 * days * main.scale;
    return MonthOfSpending(
      amount: (spent * 1461 + per - 1) ~/ per * main.scale,
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

/// The currency Savings counts in: the one most open accounts are in; on
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
    required this.target,
  });

  factory Readiness.of(LedgerData data, DateTime today) {
    // Archived accounts are out of the picker and the lists, so they're out
    // of the sums too: nothing counts that can't be seen and changed. One
    // currency, never added across (ROADMAP E).
    final main = mainCurrency(data);
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
            a.id: _carriedSince(data, a.id, dateOnly(today)),
      }..removeWhere((_, since) => since == null),
      target:
          consumer.where((d) => d.account.id == targetId).firstOrNull ??
          consumer.firstOrNull,
      month: MonthOfSpending.of(data, today, budget: budget),
      fundCategories: fundCategories,
      keptIn: limited ? keptIn : const [],
      keptThere: limited ? there.clamp(0, fund) : 0,
      notAssigned: budget.currency == main && budget.notAssigned > 0
          ? budget.notAssigned
          : 0,
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

  /// Cards marked paid in full every month that have owed something every
  /// day for over five weeks: since when. A warning, not a reclassing.
  final Map<int, DateTime?> carriedSince;

  /// The consumer debt to pay extra on: the one picked, or the smallest.
  final Debt? target;

  /// Paid in full: a card that owes nothing at the end of some day in the
  /// last [_carryDays] days. Otherwise the day after it last owed nothing
  /// (or its first row), which is when the balance started carrying.
  static const _carryDays = 35;

  static DateTime? _carriedSince(LedgerData data, int id, DateTime today) {
    final byDay = <DateTime, int>{};
    for (final t in data.txns) {
      if (t.scheduled || t.date.isAfter(today)) continue;
      for (final e in t.entries) {
        if (e.accountId == id) byDay[t.date] = (byDay[t.date] ?? 0) + e.amount;
      }
    }
    final days = byDay.keys.toList()..sort();
    if (days.isEmpty) return null;
    var balance = 0;
    DateTime? lastClear;
    for (final d in days) {
      balance += byDay[d]!;
      if (balance >= 0) lastClear = d;
    }
    final since = lastClear == null
        ? days.first
        : lastClear.add(const Duration(days: 1));
    return today.difference(since).inDays > _carryDays ? since : null;
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
  String? setAsideWith(ReadyStep s, bool aside) {
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
