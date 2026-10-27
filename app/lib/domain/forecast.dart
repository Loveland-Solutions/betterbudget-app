import 'budget.dart' show Budget, nextBudgetPeriod;
import 'ledger.dart';
import 'money.dart' show Currency;
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
      out.add(r.copyWith(date: d, amount: pay.amountOn(d), projected: true));
    }
  }
  for (final MapEntry(key: id, value: r) in bills.entries) {
    final plan = planOf(id);
    if (plan == null || !plan.repeats) continue;
    final pay = payById(plan.payScheduleId);
    if (plan.payScheduleId != null && pay == null) continue;
    final last = Budget.lastDue(plan, pay: pay);
    for (var n = 0; n < atMost; n++) {
      final d = Budget.dueAfter(plan, n, pay: pay);
      if (d.isAfter(until) || (last != null && d.isAfter(last))) break;
      if (!d.isAfter(r.date)) continue;
      out.add(r.copyWith(date: d, projected: true));
    }
  }
  return out;
}

/// What the budget expects spent from [accountId], day by day, from [today]
/// through [until] (owner, 2026-10-27, #179: the forecast "should also take
/// out what's budgeted for groceries, transport and the rest"; "you'd
/// pro-rate it"). From each category paid from it (#180) whose set amount
/// goes back when its period ends, so is spent within it: each period at
/// its plan's pace, by the day. In the period today is in, only the days
/// left, and never more than it still has: its Left once anything is
/// assigned, else the plan less what it spent (so the first of the month,
/// before assigning, still counts the month; and an underspent one doesn't
/// pile its Left onto the last days). Rows already scheduled in it (one
/// typed with a later date) come on their own dates, so they're taken off
/// what's spread. A bill comes on its date, and one that builds up (car
/// repairs) isn't spent by the day, so neither is here.
List<({DateTime date, int amount})> projectSpending(
  LedgerData data, {
  required int accountId,
  required DateTime today,
  required DateTime until,
}) {
  final account = data.accounts[accountId];
  if (account == null) return const [];
  final start = dateOnly(today), end = dateOnly(until);
  if (end.isBefore(start)) return const [];
  final byDay = <DateTime, int>{};
  void spread(int amount, DateTime from, DateTime to, int days) {
    // [amount] over the [days] the period has, for those from [from]
    // through [to]; what rounding leaves goes on its last day.
    if (amount <= 0 || days <= 0) return;
    var given = 0, n = 0;
    for (
      var d = from;
      !d.isAfter(to);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      n++;
      final share = n == days ? amount - given : amount ~/ days;
      given += share;
      if (share != 0) byDay[d] = (byDay[d] ?? 0) - share;
    }
  }

  int daysIn(DateTime a, DateTime b) =>
      DateTime.utc(
        b.year,
        b.month,
        b.day,
      ).difference(DateTime.utc(a.year, a.month, a.day)).inDays +
      1;
  // One budget per period the categories run by, for what each has left.
  final budgets = <(DateTime, DateTime), Budget>{};
  for (final MapEntry(key: id, value: paidFrom) in data.paidFrom.entries) {
    if (paidFrom != accountId) continue;
    final category = data.accounts[id];
    final plan = data.plans[id];
    if (category == null ||
        category.deleted ||
        category.archived ||
        category.currency != account.currency ||
        plan == null ||
        plan.kind != PlanKind.each ||
        plan.rollover) {
      continue;
    }
    final own = data.payScheduleById(plan.payScheduleId);
    // Its rows already scheduled, from today on, by day.
    final scheduled = <DateTime, int>{};
    for (final t in data.txns) {
      if (!t.scheduled) continue;
      final d = dateOnly(t.date);
      if (d.isBefore(start)) continue;
      for (final e in t.entries) {
        if (e.accountId == id) scheduled[d] = (scheduled[d] ?? 0) + e.amount;
      }
    }
    int scheduledIn(DateTime from, DateTime to) => scheduled.entries
        .where((x) => !x.key.isBefore(from) && !x.key.isAfter(to))
        .fold(0, (sum, x) => sum + x.value);
    var p = budgetPeriod(start, own);
    final budget = budgets.putIfAbsent((
      p.start,
      p.end,
    ), () => Budget.of(data, start: p.start, end: p.end, today: start));
    final line = budget.lines[id];
    final days = daysIn(p.start, p.end), left = daysIn(start, p.end);
    final pace = plan.amountIn(p.start) * left ~/ days;
    final has = line == null
        ? 0
        : line.assigned != 0
        ? line.left
        : plan.amountIn(p.start) - line.counted;
    // Not before the plan began.
    final begun = !p.end.isBefore(dateOnly(plan.start));
    final now = (pace < has ? pace : has) - scheduledIn(start, p.end);
    if (begun) spread(now, start, p.end.isAfter(end) ? end : p.end, left);
    for (var walked = 0; walked < 400; walked++) {
      final next = nextBudgetPeriod(p, own);
      if (!next.start.isAfter(p.start) || next.start.isAfter(end)) break;
      p = next;
      if (p.end.isBefore(dateOnly(plan.start))) continue;
      final to = p.end.isAfter(end) ? end : p.end;
      spread(
        plan.amountIn(p.start) - scheduledIn(p.start, p.end),
        p.start,
        to,
        daysIn(p.start, p.end),
      );
    }
  }
  return [
    for (final d in byDay.keys.toList()..sort()) (date: d, amount: byDay[d]!),
  ];
}

/// What the account pay goes into ([accountId]) will pay out for the
/// others, day by day, from [today] through [until] (owner, 2026-10-28):
/// cash taken out to fill a wallet the budget's spending would take below
/// zero, and a card's spending when nothing scheduled pays the card (a
/// card paid by a dated bill is counted through that bill). Only accounts
/// in its currency, and only for the one account pay goes into there (else
/// its first bank account).
List<({DateTime date, int amount})> projectFunding(
  LedgerData data, {
  required int accountId,
  required DateTime today,
  required DateTime until,
}) {
  final here = data.accounts[accountId];
  if (here == null || !here.isBalanceSheet || here.isOwed || here.isCash) {
    return const [];
  }
  if (fundingAccount(data, here.currency) != accountId) return const [];
  final start = dateOnly(today), end = dateOnly(until);
  final byDay = <DateTime, int>{};
  for (final a in data.openAccounts) {
    if (a.id == accountId || a.currency != here.currency) continue;
    final days = projectSpending(
      data,
      accountId: a.id,
      today: start,
      until: end,
    );
    if (days.isEmpty) continue;
    if (a.isCash) {
      // The wallet as it goes, with what's scheduled in it: what would take
      // it below zero is taken out of the bank that day.
      final events = <DateTime, int>{};
      for (final r in data.registerFor(a.id).scheduled) {
        final d = r.date.isBefore(start) ? start : dateOnly(r.date);
        if (!d.isAfter(end)) events[d] = (events[d] ?? 0) + r.amount;
      }
      for (final x in days) {
        events[x.date] = (events[x.date] ?? 0) + x.amount;
      }
      var bal = data.summaryFor(a.id).working;
      for (final d in events.keys.toList()..sort()) {
        bal += events[d]!;
        if (bal < 0) {
          byDay[d] = (byDay[d] ?? 0) + bal;
          bal = 0;
        }
      }
    } else if (a.isOwed && !_paidByBill(data, a.id)) {
      for (final x in days) {
        byDay[x.date] = (byDay[x.date] ?? 0) + x.amount;
      }
    }
  }
  return [
    for (final d in byDay.keys.toList()..sort()) (date: d, amount: byDay[d]!),
  ];
}

/// The account money for cash and cards comes from, in [currency]: the
/// one pay goes into, else the first bank account.
int? fundingAccount(LedgerData data, Currency currency) {
  bool bank(AccountInfo a) =>
      a.type == AccountType.asset && !a.isCash && a.currency == currency;
  for (final p in data.paySchedules) {
    final a = data.accounts[p.accountId];
    if (a != null && !a.archived && !a.deleted && bank(a)) return a.id;
  }
  return data.openAccounts.where(bank).firstOrNull?.id;
}

/// A card a dated bill pays: its category, or any dated plan scheduled to
/// pay into it.
bool _paidByBill(LedgerData data, int card) {
  final c = Budget.loanCategory(data, card);
  if (c != null && data.plans[c]?.kind == PlanKind.byDate) return true;
  return data.txns.any(
    (t) =>
        t.scheduled &&
        t.planCategoryId != null &&
        t.entries.any((e) => e.accountId == card && e.amount > 0),
  );
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
    this.firstShortBalance = 0,
    this.expectedBills = 0,
    this.spendingTotal = 0,
    this.takeOut = 0,
    this.takeOutBy,
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

  /// The balance that day: what it would take to stay above zero there
  /// (the first dip, not the lowest point).
  final int firstShortBalance;

  /// How many of the bills are expected (projected), not scheduled rows.
  final int expectedBills;

  /// What the budget expects spent before [end], day by day
  /// ([projectSpending]); not in [billTotal]. Its steps are [ForecastStep]
  /// with `spending` set.
  final int spendingTotal;

  /// Cash: how much has to be taken out to keep it from going below zero
  /// before [end], and the first day it's needed (owner, 2026-10-28: the
  /// wallet is filled from the bank, so that isn't a shortfall). 0 and null
  /// otherwise; a cash forecast is never [isShort] for it.
  final int takeOut;
  final DateTime? takeOutBy;

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

  /// The steps that are rows (bills, money in), not a day's spending.
  List<ForecastStep> get rowSteps => [
    for (final s in steps)
      if (!s.spending) s,
  ];

  /// The balance once every step has happened.
  int get endBalance => steps.isEmpty ? startBalance : steps.last.balance;
}

/// [spending]: a day of what the budget expects spent ([projectSpending]),
/// not a row: its [row] stands in, with only the date and amount.
typedef ForecastStep = ({
  DateTime date,
  int balance,
  String label,
  RegisterRow row,
  bool spending,
});

/// A day's spending from the budget as a row the walk can sort.
RegisterRow _spendingRow(DateTime date, int amount) => RegisterRow(
  txnId: 0,
  entryId: 0,
  date: date,
  payee: '',
  memo: '',
  amount: amount,
  cleared: Cleared.uncleared,
  scheduled: true,
  kind: RowKind.simple,
  categoryLabel: '',
  categoryId: null,
  splitLines: const [],
  projected: true,
);

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
  List<({DateTime date, int amount})> spending = const [],
  bool cash = false,
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
  // A day's spending counts through the last day, as a bill does.
  final spent = [
    for (final x in spending)
      if (!x.date.isBefore(start) && !x.date.isAfter(end))
        _spendingRow(x.date, x.amount),
  ];
  final isSpending = Set<RegisterRow>.identity()..addAll(spent);
  final rows = [...counted, if (until != null) ...projected, ...spent];

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
  var expectedBills = 0, spendingTotal = 0;
  DateTime? takeOutBy;
  var firstShortBalance = !owed && working < 0 ? working : 0;
  var low = shown(working);
  var lowDate = start;
  DateTime? firstShort = !owed && working < 0 ? start : null;
  final steps = <ForecastStep>[];

  for (final (i: _, :r) in inRange) {
    bal += r.amount;
    final day = isSpending.contains(r);
    if (day) {
      spendingTotal -= r.amount;
    } else if (r.amount < 0) {
      billTotal -= r.amount;
      billCount++;
      if (r.projected) expectedBills++;
    } else if (!identical(r, payday)) {
      inTotal += r.amount;
    }
    final label = r.kind == RowKind.transfer ? r.payee : r.categoryLabel;
    steps.add((
      date: when(r),
      balance: shown(bal),
      label: label,
      row: r,
      spending: day,
    ));
    if (!owed && bal < low) {
      low = bal;
      lowDate = when(r);
    }
    // Cash below zero is filled from the bank, not short.
    if (cash && bal < 0) takeOutBy ??= when(r);
    // To zero or below (owner, 2026-10-05): nothing left is already short.
    if (!owed && !cash && bal <= 0 && firstShort == null) {
      firstShort = when(r);
      firstShortBalance = bal;
    }
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
    firstShortBalance: firstShortBalance,
    expectedBills: expectedBills,
    spendingTotal: spendingTotal,
    takeOut: cash && low < 0 ? -low : 0,
    takeOutBy: takeOutBy,
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
