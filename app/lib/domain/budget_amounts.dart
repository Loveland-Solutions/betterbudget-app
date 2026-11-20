import 'ledger.dart';
import 'money.dart';
import 'pay.dart';
import 'budget.dart';

/// How an Assigned amount is written, shared by the computer's Budget and
/// the phone's, so both keep it the same way (#528).

/// The day the budget began, before and after an amount moved it, and
/// the currency fixed with the first amount ever (null after that).
typedef BudgetBegan = ({
  String key,
  String? was,
  String now,
  bool moved,
  String? currency,
});

/// How a new Assigned [amount] for [period] is written for [c]: one row
/// at the period's start, or, when the category's own period (its set
/// amount's month or pay) isn't the one on screen and the span holds
/// more than one of them, the rows already dated in the span kept and
/// the difference spread over its periods ([Budget.spread]), so an
/// emptying category isn't handed the lot in its first period.
List<({DateTime date, int amount})> budgetRows(
  LedgerData data,
  Budget budget,
  AccountInfo c,
  BudgetSpan period,
  int amount, {
  required DateTime today,
}) {
  final plan = data.plans[c.id];
  final own = plan?.kind == PlanKind.each
      ? data.payScheduleById(plan!.payScheduleId)
      : data.periodSchedule;
  final onePeriod =
      own?.id == data.periodSchedule?.id ||
      !budgetPeriod(period.start, own).end.isBefore(period.end);
  // A month's Assigned, typed on the month's page, is kept where each
  // paycheck it pays for is (owner, 2026-11-15, #468), so the paycheck
  // holding the 1st isn't handed the whole month: Day-to-day and Funds
  // by days, a bill or goal by what each paycheck asks toward it.
  final split = splitScheduleOf(data);
  if (onePeriod &&
      own == null &&
      split != null &&
      data.periodSchedule == null &&
      period.label != payPeriodLabel) {
    return byPaychecks(data, c, period, split, amount, today: today);
  }
  if (onePeriod) return [(date: period.start, amount: amount)];
  final kept = [
    for (final b in data.budgetAmounts)
      if (b.categoryId == c.id &&
          !b.date.isBefore(period.start) &&
          !b.date.isAfter(period.end))
        (date: dateOnly(b.date), amount: b.amount),
  ];
  final have = kept.fold(0, (sum, r) => sum + r.amount);
  return [
    ...kept,
    ...Budget.spread(
      span: period,
      own: own,
      shares: budget.lines[c.id]?.plan?.shares ?? const [],
      delta: amount - have,
    ),
  ];
}

/// A month's Assigned typed on the month's page, kept by [split]'s
/// paychecks (#468). The first time, or over rows all on the 1st (from
/// before), the whole by days; after that the rows there stay and only
/// the difference goes, by days, to the paychecks still running (code
/// review: a retyped month wiped what was set per paycheck). A bill or
/// goal fills its paychecks in order, each what it asks.
List<({DateTime date, int amount})> byPaychecks(
  LedgerData data,
  AccountInfo c,
  BudgetSpan period,
  PaySchedule split,
  int amount, {
  required DateTime today,
}) {
  final start = dateOnly(period.start), end = dateOnly(period.end);
  final kept = <DateTime, int>{};
  for (final b in data.budgetAmounts) {
    if (b.categoryId != c.id) continue;
    final d = dateOnly(b.date);
    if (d.isBefore(start) || d.isAfter(end)) continue;
    kept[d] = (kept[d] ?? 0) + b.amount;
  }
  if (data.plans[c.id]?.kind == PlanKind.byDate) {
    final base = data.withoutAmounts({c.id}, start, end).viewedBy(split);
    final rows = <({DateTime date, int amount})>[];
    var given = 0;
    final paychecks = <BudgetSpan>[];
    for (
      var q = budgetPeriod(start, split);
      !q.start.isAfter(end) && paychecks.length < 40;
      q = nextBudgetPeriod(q, split)
    ) {
      paychecks.add(q);
    }
    for (final (i, q) in paychecks.indexed) {
      final from = q.start.isBefore(start) ? start : dateOnly(q.start);
      final rest = amount - given;
      final int part;
      if (i == paychecks.length - 1 || rest <= 0) {
        part = rest;
      } else {
        final ask =
            Budget.of(
              base.withAmounts([
                for (final r in rows)
                  BudgetAmount(
                    categoryId: c.id,
                    date: r.date,
                    amount: r.amount,
                  ),
              ]),
              start: q.start,
              end: q.end,
              today: today,
            ).lines[c.id]?.toAssign ??
            0;
        part = ask < rest ? ask : rest;
      }
      given += part;
      if (part != 0) rows.add((date: from, amount: part));
      if (given == amount) break;
    }
    return rows;
  }
  final have = kept.values.fold(0, (sum, v) => sum + v);
  final fromBefore = kept.keys.every((d) => d == start);
  if (have == 0 || fromBefore) {
    return Budget.byPaychecks(
      span: period,
      pay: split,
      amount: amount,
      currency: c.currency,
    );
  }
  final running = !today.isBefore(start) && !today.isAfter(end);
  for (final r in Budget.byPaychecks(
    span: period,
    pay: split,
    amount: amount - have,
    currency: c.currency,
    notBefore: running || today.isAfter(end) ? today : null,
  )) {
    kept[r.date] = (kept[r.date] ?? 0) + r.amount;
  }
  return [
    for (final e in kept.entries)
      if (e.value != 0) (date: e.key, amount: e.value),
  ]..sort((a, b) => a.date.compareTo(b.date));
}

/// What a write into the period starting [start] does to the day the
/// budget began: the first amount ever fixes it (with its currency), and
/// one put in a period before it moves it back there, so that period's
/// spending counts against its categories as its amounts say (#163).
/// Null when it stays.
/// Each currency has its own first day: dollars assigned don't start the
/// tugrik budget (#163). [currencies] are those of the categories
/// written to.
List<BudgetBegan> beganBy(
  LedgerData data,
  DateTime start,
  Iterable<Currency> currencies,
) {
  final main = Budget.currencyOf(data);
  final shared = data.prefs[BudgetKeys.began];
  // The budget's own currency, fixed with the first amount ever.
  final fixes = data.prefs[BudgetKeys.currency] == null;
  return [
    for (final c in currencies.toSet())
      if ((c == main ? BudgetKeys.began : BudgetKeys.beganIn(c)) case final key)
        if (c == main ? shared : (data.prefs[key] ?? shared) case final was
            when was == null || dateOnly(start).isBefore(parseDateKey(was)))
          (
            key: key,
            was: data.prefs[key],
            now: dateKey(start),
            moved: was != null,
            currency: fixes ? main.code : null,
          ),
  ];
}
