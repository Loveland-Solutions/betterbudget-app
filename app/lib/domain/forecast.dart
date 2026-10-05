import 'budget.dart' show Budget;
import 'ledger.dart';
import 'pay.dart';

/// How far the forecast looks (owner's request, 2026-10-05): through the
/// next pay period, as it always has, or a fixed span from today. One
/// choice for every account, kept in the ledger's preferences.
enum ForecastSpan {
  payPeriod,
  days30,
  days60,
  days90,
  months6,
  year;

  static const prefKey = 'forecast.span';

  static ForecastSpan parse(String? stored) =>
      values.where((s) => s.name == stored).firstOrNull ?? payPeriod;

  /// The last day a fixed span covers, from [start]; null for the pay
  /// period, which the forecast works out from the paydays.
  DateTime? endFrom(DateTime start) {
    final d = dateOnly(start);
    return switch (this) {
      payPeriod => null,
      days30 => DateTime(d.year, d.month, d.day + 30),
      days60 => DateTime(d.year, d.month, d.day + 60),
      days90 => DateTime(d.year, d.month, d.day + 90),
      months6 => DateTime(d.year, d.month + 6, d.day),
      year => DateTime(d.year + 1, d.month, d.day),
    };
  }
}

/// Only the next payday of a pay schedule, and the next bill of a plan,
/// is ever scheduled. A forecast that looks further needs the ones after:
/// each as a copy of its scheduled row, dated when it will come, through
/// [until] (a click on one opens the scheduled row it continues). Paydays
/// follow the schedule's dates and amounts; bills follow the plan's.
List<RegisterRow> projectScheduled(
  List<RegisterRow> scheduled, {
  required DateTime until,
  required PaySchedule? Function(int? id) payById,
  required CategoryPlan? Function(int categoryId) planOf,
}) {
  const atMost = 400;
  // From the latest scheduled one of each: an overdue payday beside the
  // next one mustn't project the same dates twice.
  final paydays = <int, RegisterRow>{}, bills = <int, RegisterRow>{};
  for (final r in scheduled) {
    if (r.payScheduleId case final id? when r.amount > 0) {
      if ((paydays[id]?.date.isBefore(r.date)) ?? true) paydays[id] = r;
    } else if (r.planCategoryId case final id? when r.amount < 0) {
      if ((bills[id]?.date.isBefore(r.date)) ?? true) bills[id] = r;
    }
  }
  final out = <RegisterRow>[];
  for (final MapEntry(key: id, value: r) in paydays.entries) {
    final pay = payById(id);
    if (pay == null) continue;
    // From the payday it was planned as, like the one the app schedules
    // after it's confirmed.
    var d = pay.plannedFor(r.date, paid: r.amount);
    for (var i = 0; i < atMost; i++) {
      d = pay.nextAfter(d);
      if (d.isAfter(until)) break;
      if (!d.isAfter(r.date)) continue;
      out.add(r.copyWith(date: d, amount: pay.amountOn(d)));
    }
  }
  for (final MapEntry(key: id, value: r) in bills.entries) {
    final plan = planOf(id);
    if (plan == null || !plan.repeats) continue;
    final pay = payById(plan.payScheduleId);
    if (plan.payScheduleId != null && pay == null) continue;
    for (var n = 0; n < atMost; n++) {
      final d = Budget.dueAfter(plan, n, pay: pay);
      if (d.isAfter(until) || Budget.over(plan, d, pay: pay)) break;
      if (!d.isAfter(r.date)) continue;
      out.add(r.copyWith(date: d));
    }
  }
  return out;
}

/// Answers "will this account make it through the next pay period?" from
/// scheduled transactions and the pay plan. Deterministic and local: no
/// history, no guessing.
///
/// With the payday after the next one known ([nextPayday]), it runs through
/// the whole period that the next paycheck starts: the paycheck is a step,
/// and the forecast ends as the one after lands (owner, 2026-09-30: payday
/// tomorrow used to show one day). Without it, it ends at the next payday.
///
/// On a credit account ([owed]) it answers "what will I owe?" instead:
/// balances are what's owed, positive, and owing is never a shortfall.
class Forecast {
  const Forecast({
    required this.start,
    required this.startBalance,
    required this.end,
    required this.steps,
    required this.payday,
    required this.low,
    required this.lowDate,
    this.fixedEnd = false,
    required this.firstShort,
    required this.billTotal,
    required this.billCount,
    required this.inTotal,
    this.late = const [],
    this.owed = false,
    this.nextPayday,
    this.nextPayAmount,
  });

  final DateTime start;

  /// On a credit account, what's owed today.
  final int startBalance;

  /// The payday after [payday] when it's known, else [payday]'s date, else
  /// the fallback horizon.
  final DateTime end;

  /// Balance after each scheduled bill or money coming in, in date order,
  /// with the row that caused it. With [nextPayday], the next paycheck is a
  /// step too; without it, payday ends the forecast and isn't one.
  final List<ForecastStep> steps;

  /// The next paycheck.
  final RegisterRow? payday;

  /// The payday after [payday], from its pay plan: where the forecast ends.
  final DateTime? nextPayday;

  /// The forecast runs to a date the user chose ([ForecastSpan]), not to
  /// a payday: the end is just where it stops looking.
  final bool fixedEnd;

  /// What the plan expects on [nextPayday] (not counted: it ends the
  /// forecast).
  final int? nextPayAmount;

  /// Runs through the pay period [payday] starts, not just up to it.
  bool get throughPeriod => payday != null && nextPayday != null;

  /// The next paycheck is one of the steps: through the pay period it
  /// always is; with a fixed end, when it comes before that end.
  bool get paydayCounted =>
      payday != null && steps.any((s) => identical(s.row, payday));
  final int low;
  final DateTime lowDate;

  /// First day the balance is below zero, if it is before [end]. Today when
  /// the account is already under. Never set on a credit account.
  final DateTime? firstShort;

  /// Money going out before [end], and how many rows.
  final int billTotal;
  final int billCount;

  /// Money coming in before [end] other than the next paycheck: transfers
  /// from another account, refunds. Late money in isn't in it (see [late]).
  final int inTotal;

  /// Money in due today or earlier and not confirmed (a late salary, a
  /// refund that hasn't come): left out until it arrives, so a forecast never
  /// leans on money that may be late again. Bills past their date still
  /// count, as due today, and so do transfers between the user's own
  /// accounts, which count on both sides.
  final List<RegisterRow> late;

  final bool owed;

  bool get isShort => firstShort != null;

  /// Below zero before any scheduled bill lands.
  bool get shortNow => !owed && startBalance < 0;

  /// The balance once every step has happened.
  int get endBalance => steps.isEmpty ? startBalance : steps.last.balance;
}

typedef ForecastStep = ({
  DateTime date,
  int balance,
  String label,
  RegisterRow row,
});

const _fallbackHorizon = Duration(days: 30);
const _paydayLookahead = Duration(days: 45);

Forecast buildForecast({
  required int working,
  required DateTime today,
  required List<RegisterRow> scheduled,
  bool owed = false,
  ({DateTime date, int amount})? Function(RegisterRow payday)? paydayAfter,
  bool payIsSetUp = false,
  DateTime? until,
  List<RegisterRow> projected = const [],
}) {
  final start = dateOnly(today);
  // Overdue bills still have to be paid; treat them as due today.
  DateTime when(RegisterRow r) => r.date.isBefore(start) ? start : r.date;

  // Money in due today or earlier isn't counted until it's confirmed: a
  // salary on payday morning may still be late. A transfer is the user's
  // own doing and counts on both sides, as due today. (On a card, owing is
  // never a warning, so a late payment still counts.)
  final late = <RegisterRow>[], counted = <RegisterRow>[];
  for (final r in scheduled) {
    final waiting =
        !owed &&
        r.amount > 0 &&
        r.kind != RowKind.transfer &&
        !r.date.isAfter(start);
    (waiting ? late : counted).add(r);
  }

  // A card has no payday: it looks 30 days out. A late salary isn't payday:
  // the forecast runs on to the next one.
  // Pay that was set up is the payday. Income typed by hand ends the
  // forecast only when no pay is set up anywhere ([payIsSetUp], rule 30):
  // with pay set up it's money in like any other, so an allowance before
  // rent, or on the morning the paycheck is late, doesn't hide the bills
  // after it.
  final coming = owed
      ? const <RegisterRow>[]
      : counted
            .where(
              (r) =>
                  r.isIncome && !when(r).isAfter(start.add(_paydayLookahead)),
            )
            .toList();
  final payday =
      coming.where((r) => r.payScheduleId != null).firstOrNull ??
      (payIsSetUp ? null : coming.firstOrNull);
  // The payday after it, from its pay plan: only the next payday of a plan
  // is ever scheduled.
  var after = payday == null ? null : paydayAfter?.call(payday);
  if (payday != null && after != null && !after.date.isAfter(when(payday))) {
    after = null;
  }
  // To a chosen date, the paydays after the next come as projected rows,
  // not as the period's end.
  final nextPayday = until == null ? after?.date : null;
  final end =
      until ??
      nextPayday ??
      (payday != null ? when(payday) : start.add(_fallbackHorizon));
  final rows = [...counted, if (until != null) ...projected];

  // Bills on the last day count; money in on it doesn't (like the paycheck
  // that ends it, it may land after them), except a transfer, the user's own
  // doing. The next paycheck counts only when the forecast runs past it.
  // To a chosen date, everything through it counts.
  bool counts(RegisterRow r) {
    if (when(r).isAfter(end)) return false;
    if (until != null) return true;
    if (identical(r, payday)) return nextPayday != null;
    final lastDayIn =
        nextPayday != null &&
        r.amount > 0 &&
        r.kind != RowKind.transfer &&
        !when(r).isBefore(end);
    return !lastDayIn;
  }

  // In date order; on a payday its bills count before the paycheck (they may
  // go out first), which is the conservative order.
  int paidLast(RegisterRow r) => r.isIncome ? 1 : 0;
  final inRange =
      [
        for (final (i, r) in rows.indexed)
          if (counts(r)) (i: i, r: r),
      ]..sort((a, b) {
        final d = when(a.r).compareTo(when(b.r));
        if (d != 0) return d;
        final o = paidLast(a.r).compareTo(paidLast(b.r));
        return o != 0 ? o : a.i.compareTo(b.i);
      });

  // On a card, balances are shown as what's owed.
  int shown(int v) => owed ? -v : v;
  var bal = working, billTotal = 0, billCount = 0, inTotal = 0;
  var low = shown(working);
  var lowDate = start;
  DateTime? firstShort = !owed && working < 0 ? start : null;
  final steps = <ForecastStep>[];

  for (final (i: _, :r) in inRange) {
    bal += r.amount;
    if (r.amount < 0) {
      billTotal -= r.amount;
      billCount++;
    } else if (!identical(r, payday)) {
      inTotal += r.amount;
    }
    final label = r.kind == RowKind.transfer ? r.payee : r.categoryLabel;
    steps.add((date: when(r), balance: shown(bal), label: label, row: r));
    if (!owed && bal < low) {
      low = bal;
      lowDate = when(r);
    }
    // To zero or below (owner, 2026-10-05): nothing left is already short.
    if (!owed && bal <= 0 && firstShort == null) firstShort = when(r);
  }

  return Forecast(
    start: start,
    startBalance: shown(working),
    end: end,
    steps: steps,
    payday: payday,
    low: low,
    lowDate: lowDate,
    firstShort: firstShort,
    billTotal: billTotal,
    billCount: billCount,
    inTotal: inTotal,
    late: late,
    owed: owed,
    nextPayday: nextPayday,
    nextPayAmount: until == null ? after?.amount : null,
    fixedEnd: until != null,
  );
}
