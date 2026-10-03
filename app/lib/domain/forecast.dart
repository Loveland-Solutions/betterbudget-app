import 'ledger.dart';

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

  /// What the plan expects on [nextPayday] (not counted: it ends the
  /// forecast).
  final int? nextPayAmount;

  /// Runs through the pay period [payday] starts, not just up to it.
  bool get throughPeriod => payday != null && nextPayday != null;
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
  final nextPayday = after?.date;
  final end =
      nextPayday ??
      (payday != null ? when(payday) : start.add(_fallbackHorizon));

  // Bills on the last day count; money in on it doesn't (like the paycheck
  // that ends it, it may land after them), except a transfer, the user's own
  // doing. The next paycheck counts only when the forecast runs past it.
  bool counts(RegisterRow r) {
    if (when(r).isAfter(end)) return false;
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
        for (final (i, r) in counted.indexed)
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
    if (!owed && bal < 0 && firstShort == null) firstShort = when(r);
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
    nextPayAmount: after?.amount,
  );
}
