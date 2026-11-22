import '../domain/goals.dart';
import '../domain/money.dart';
import '../domain/readiness.dart';
import 'language.dart';

// What the Savings steps say, worked out the same on the computer's Savings
// page and the phone's Savings tab (#533): a rate, interest said with
// "about", a month of expenses, a goal's lines.

/// A rate as said: "2% a month", "24% a year".
String rateWords(Words t, DebtRate r) => r.perYear
    ? t.planRateYearly(ratePercent(r.percent))
    : t.planRateMonthly(ratePercent(r.percent));

/// Interest a month, as said with "about": ₮48,000, not ₮47,836.
String interestAbout(int minor, Currency c) =>
    formatShort(roundAbout((minor / c.scale).round()) * c.scale, currency: c);

/// "Golomt Visa and Khan loan", "A, B and C".
String namesAnd(Words t, Iterable<String> names) {
  final l = names.toList();
  if (l.length < 2) return l.join();
  return t.planNamesAnd(l.sublist(0, l.length - 1).join(', '), l.last);
}

/// Where a month of expenses comes from: typed, the budget, the average, or
/// not known yet.
String monthOfExpensesSays(Words t, MonthOfSpending m, Currency c) {
  String here(int v) => formatShort(v, currency: c);
  final loans = m.loanPayments > 0 ? 'yes' : 'no';
  return m.amount == 0
      ? (m.days < MonthOfSpending.minDays
            ? t.planMonthUnknown
            : t.planMonthNoSpending(m.days))
      : m.typed
      ? t.planMonthTyped(here(m.amount))
      : m.fromBudget
      ? t.planMonthBudget(here(m.amount))
      : m.days >= MonthOfSpending.spanDays
      ? t.planMonthAverage3(here(m.amount), loans)
      : t.planMonthAverageDays(here(m.amount), m.days, loans);
}

/// A payment no bigger than the interest, said as it is: what's owed grows
/// when it's less. That it goes down once another's payment moves to it is
/// said only of one [behind] another in the list, which isn't getting the
/// extra (reviews).
String onlyInterestSays(
  Words t, {
  required bool below,
  required bool behind,
  required String amount,
}) => below
    ? (behind
          ? t.planPayBelowInterestNext(amount)
          : t.planPayBelowInterest(amount))
    : (behind
          ? t.planPayOnlyInterestNext(amount)
          : t.planPayOnlyInterest(amount));

/// [months] after the month [r] was worked out in, as said: "June 2028".
String payoffMonth(Words t, Readiness r, int months) {
  final d = DateTime(r.today.year, r.today.month + months);
  return t.calendarMonth(monthName(t, d.month), '${d.year}', d.month);
}

/// A goal's date: without the year in its own year.
String goalDate(Words t, Goal g, DateTime d) =>
    d.year == g.today.year ? sayDate(t, d) : sayFullDate(t, d);

/// A month as a goal says it: "April 2027".
String goalMonth(Words t, DateTime d) =>
    t.calendarMonth(monthName(t, d.month), '${d.year}', d.month);

/// How far along a goal is, beside its bar.
String goalStatus(Words t, Goal g) {
  String money(int v) => formatShort(v, currency: g.currency);
  return g.ready
      ? t.goalReady(money(g.amount))
      : g.finished
      ? t.goalDoneStatus
      : [
          t.planFundOf(money(g.saved), money(g.amount)),
          if (!g.late)
            g.behind > 0 ? t.goalBehind(money(g.behind)) : t.goalOnTrack,
        ].join(' · ');
}

/// The line under a goal's bar: late, behind with what catches up, or what
/// Budget asks. Null once it's ready.
String? goalLine(Words t, Goal g) {
  if (g.ready) return null;
  String money(int v) => formatShort(v, currency: g.currency);
  if (g.late) {
    return !g.finished
        ? t.goalLate(goalDate(t, g, g.due), money(g.toGo))
        : g.left > 0
        ? t.goalDoneLeft(money(g.left), g.category.name)
        : t.goalDoneNote;
  }
  final readyAt = g.readyAtUsual;
  if (g.behind > 0) {
    return [
      t.goalCatchUp(goalDate(t, g, g.due), money(g.asks)),
      if (readyAt != null) t.goalAtUsual(money(g.usual), goalMonth(t, readyAt)),
    ].join(' ');
  }
  final thisMonth = g.due.year == g.today.year && g.due.month == g.today.month;
  return thisMonth
      ? t.goalAsksThisMonth(money(g.asks))
      : t.goalAsks(money(g.asks));
}

/// What two or more goals ask this month, by currency, said as money.
List<String> goalTotals(List<Goal> goals) {
  final sums = <Currency, int>{}, count = <Currency, int>{};
  for (final g in goals) {
    if (g.asks <= 0 || g.ready || g.finished) continue;
    sums[g.currency] = (sums[g.currency] ?? 0) + g.asks;
    count[g.currency] = (count[g.currency] ?? 0) + 1;
  }
  return [
    for (final MapEntry(key: c, value: v) in sums.entries)
      if (count[c]! > 1) formatShort(v, currency: c),
  ];
}

/// Said over the goals while there's one: what saving for it now costs the
/// steps before it. A warning; nothing is stopped.
String? goalsBefore(Words t, Readiness r, Currency c) {
  final owed = r.consumerDebts.fold(0, (sum, d) => sum + d.owed);
  return owed > 0
      ? t.goalsDebtNote(formatShort(owed, currency: c))
      : r.stateOf(ReadyStep.oneMonth) == ReadyState.current
      ? t.goalsNetNote
      : null;
}

/// The place [units] is said to with "about": two figures, so 53,412 is
/// said to the thousand.
int aboutUnit(int units) {
  var step = 1;
  while (units.abs() / step >= 100) {
    step *= 10;
  }
  return step;
}

/// Interest as both ways' cards say it: to the place their difference
/// needs, so the two figures and the sentence under them agree (budget
/// review). [gap] is the difference between the two in minor units.
String payoffInterest(int minor, int gap, Currency c) {
  final unit = gap == 0 ? 0 : aboutUnit((gap / c.scale).round());
  if (unit == 0) return interestAbout(minor, c);
  final whole = ((minor / c.scale) / unit).round() * unit;
  return formatShort(whole * c.scale, currency: c);
}

/// One to three sentences under the two ways: what one saves, which ends
/// sooner, which pays off its first debt sooner. Empty when nothing differs
/// that can be said.
String payoffDifference(
  Words t,
  Currency c,
  Readiness r,
  PayoffPlan s,
  PayoffPlan h,
) {
  final out = <String>[];
  if ((s.months == null) != (h.months == null)) {
    out.add(s.months == null ? t.planOnlyRateEnds : t.planOnlySmallestEnds);
  }
  if (s.months != null && h.months != null) {
    final saved = s.interest - h.interest;
    final about = roundAbout((saved.abs() / c.scale).round());
    if (about > 0) {
      final said = formatShort(about * c.scale, currency: c);
      out.add(saved > 0 ? t.planRateSaves(said) : t.planSmallestSaves(said));
    }
    final sooner = s.months! - h.months!;
    out.add(
      sooner == 0
          ? t.planBothEndSame
          : sooner > 0
          ? t.planRateEndsSooner(sooner)
          : t.planSmallestEndsSooner(-sooner),
    );
  }
  final fs = s.firstIn(r.orderOf(PayoffMethod.smallest));
  final fh = h.firstIn(r.orderOf(PayoffMethod.highestRate));
  if (fs != null && fh != null && fs.month != fh.month) {
    out.add(
      fs.month < fh.month
          ? t.planSmallestFirstSooner(fh.month - fs.month)
          : t.planRateFirstSooner(fs.month - fh.month),
    );
  }
  return out.join(' ');
}

/// What the goals in [c] ask a month while kept up with (not a one-off
/// rest), and the goal's name when there's one; null when none asks.
(int, String?)? goalsAskOf(Readiness r, Currency c) {
  final asking = [
    for (final g in r.goals)
      if (!g.ready && !g.finished && g.usual > 0 && g.currency == c) g,
  ];
  if (asking.isEmpty) return null;
  final sum = asking.fold(0, (s, g) => s + g.usual);
  return (sum, asking.length == 1 ? asking.single.category.name : null);
}
