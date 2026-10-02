/// The Savings steps (ADR 0004, rule 25): getting financially prepared, in
/// the order the Church's *Personal Finances for Self-Reliance* course
/// teaches ("What Is My Current Financial Priority?", chapter 5). For
/// everyone, so tithing isn't one of them (owner's call). The current step is
/// the first not done; nothing is locked, and any step can be set aside.
/// Pure Dart: no database, no Flutter.
library;

import 'ledger.dart';
import 'money.dart';

enum ReadyStep {
  /// One month of living expenses, not pay (course, chapter 6).
  oneMonth,
  health,
  consumerDebt,

  /// Three to six months, once consumer debt is gone (chapter 9).
  moreMonths,
  retirement,
  longLoans,
}

enum ReadyState { done, current, later, setAside }

/// Preference keys the steps keep their answers under.
abstract final class ReadyKeys {
  /// 'yes' or 'no'; unanswered is not yet.
  static const health = 'ready.health';
  static const retirement = 'ready.retirement';

  /// 'yes': paying the mortgage and student loans down on purpose;
  /// 'none': there aren't any.
  static const longLoans = 'ready.longLoans';

  /// The consumer debt to pay extra on, by account id; unset is the
  /// smallest.
  static const target = 'ready.target';

  /// A month of expenses the user typed, in minor units; overrides the
  /// average.
  static const month = 'ready.month';

  /// How many months the bigger fund aims for, 3 to 6. Starts at 3.
  static const months = 'ready.months';

  /// Steps set aside, by name, comma separated.
  static const setAside = 'ready.setAside';
}

typedef Debt = ({AccountInfo account, int owed});

/// What a month of living costs. [amount] is 0 while it isn't known: no
/// typed figure and under [minDays] of history.
class MonthOfSpending {
  const MonthOfSpending({
    required this.amount,
    required this.typed,
    required this.days,
    required this.spent,
    this.loanPayments = 0,
  });

  final int amount;

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

  /// Spending categories' posted rows over the last three months (or since
  /// the first one, so an opening balance dated months earlier doesn't
  /// thin the average), scaled to an average month and rounded up to a whole
  /// unit. Payments into a mortgage or student loan count too. Refunds count
  /// against spending; other transfers, card payments (the card's own
  /// spending already counts) and opening balances don't.
  static MonthOfSpending of(LedgerData data, DateTime today) {
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
    required this.fundAccounts,
    required this.fund,
    required this.consumerDebts,
    required this.longLoans,
    required this.monthsTarget,
    required this.answers,
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
    final fundAccounts = [
      for (final a in open)
        if (!a.isOwed && a.role == AccountRole.emergencyFund) a,
    ];
    List<Debt> owed(bool Function(AccountInfo) which) => [
      for (final a in open)
        if (a.isOwed && which(a) && data.balanceOf(a.id) < 0)
          (account: a, owed: -data.balanceOf(a.id)),
    ]..sort((a, b) => a.owed.compareTo(b.owed));
    const long = {AccountRole.mortgage, AccountRole.studentLoan};
    final months = int.tryParse(data.prefs[ReadyKeys.months] ?? '') ?? 3;
    final consumer = owed(
      (a) => !long.contains(a.role) && a.role != AccountRole.paidMonthly,
    );
    final targetId = int.tryParse(data.prefs[ReadyKeys.target] ?? '');
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
      month: MonthOfSpending.of(data, today),
      fundAccounts: fundAccounts,
      fund: fundAccounts.fold(0, (s, a) => s + data.balanceOf(a.id)),
      consumerDebts: consumer,
      longLoans: owed((a) => long.contains(a.role)),
      monthsTarget: months.clamp(3, 6),
      answers: {
        ReadyStep.health: data.prefs[ReadyKeys.health] == 'yes',
        ReadyStep.retirement: data.prefs[ReadyKeys.retirement] == 'yes',
        ReadyStep.longLoans: switch (data.prefs[ReadyKeys.longLoans]) {
          'yes' => true,
          'none' => !open.any((a) => a.isOwed && long.contains(a.role)),
          _ => false,
        },
      },
      setAside: {
        for (final n in (data.prefs[ReadyKeys.setAside] ?? '').split(','))
          for (final s in ReadyStep.values)
            if (s.name == n) s,
      },
    );
  }

  final MonthOfSpending month;

  /// Bank accounts marked as holding the emergency fund.
  final List<AccountInfo> fundAccounts;

  /// What's in them together.
  final int fund;

  /// Cards and loans owing, smallest first: consumer debt unless marked a
  /// mortgage, a student loan, or a card paid in full every month.
  final List<Debt> consumerDebts;
  final List<Debt> longLoans;
  final int monthsTarget;
  final Map<ReadyStep, bool> answers;
  final Set<ReadyStep> setAside;

  /// Some card or loan is marked a mortgage or student loan.
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
    ReadyStep.oneMonth || ReadyStep.moreMonths =>
      targetOf(s) > 0 && fundAccounts.isNotEmpty && fund >= targetOf(s),
    ReadyStep.consumerDebt => consumerDebts.isEmpty,
    // Nothing marked isn't "paid off": the mortgage may just not be kept
    // here. Done when there's none, when it's paid, or when paying extra.
    ReadyStep.longLoans => (longMarked && longLoans.isEmpty) || answers[s]!,
    ReadyStep.health || ReadyStep.retirement => answers[s]!,
  };

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
