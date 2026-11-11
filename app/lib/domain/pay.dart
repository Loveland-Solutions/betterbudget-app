/// When pay comes: the dates a pay schedule lands on, and the pay period a
/// day falls in. Pure Dart: no database, no Flutter (ADR 0004, rule 24).
library;

import 'budget.dart' show Budget;
import 'ledger.dart';

/// [custom] is every other way a category's How often can repeat: its dates
/// come from the same code a category's bills do ([PayRepeat], #438); the
/// first three are the shapes a pay had before and keep their own maths.
enum PayRule { monthly, twiceMonthly, everyWeeks, custom }

/// How a [PayRule.custom] pay repeats, in the words of a category's plan:
/// every so many days or months, on chosen weekdays, the nth weekday, on
/// dates in a year, on days of the month, and when it ends. The first
/// payday is the schedule's [PaySchedule.anchor].
class PayRepeat {
  const PayRepeat({
    this.everyMonths,
    this.everyDays,
    this.onDates,
    this.monthDays,
    this.weekdays,
    this.nth,
    this.nthWeekday,
    this.endDate,
    this.endCount,
  });

  final int? everyMonths;
  final int? everyDays;
  final List<(int, int)>? onDates;
  final List<int>? monthDays;
  final List<int>? weekdays;
  final int? nth;
  final int? nthWeekday;
  final DateTime? endDate;
  final int? endCount;

  /// Paydays a year, about, for the monthly figure.
  int get perYear {
    if (onDates case final d? when d.isNotEmpty) return d.length;
    if (monthDays case final d? when d.isNotEmpty) return 12 * d.length;
    if (everyDays case final days?) {
      final per = (weekdays?.isNotEmpty ?? false) ? weekdays!.length : 1;
      return days <= 0 ? 0 : (365 * per / days).round();
    }
    if (everyMonths case final m? when m > 0) return (12 / m).round();
    return 1;
  }

  @override
  bool operator ==(Object other) =>
      other is PayRepeat &&
      everyMonths == other.everyMonths &&
      everyDays == other.everyDays &&
      nth == other.nth &&
      nthWeekday == other.nthWeekday &&
      endDate == other.endDate &&
      endCount == other.endCount &&
      '$onDates|$monthDays|$weekdays' ==
          '${other.onDates}|${other.monthDays}|${other.weekdays}';

  @override
  int get hashCode => Object.hash(
    everyMonths,
    everyDays,
    nth,
    nthWeekday,
    endDate,
    endCount,
    '$onDates|$monthDays|$weekdays',
  );
}

/// What [PaySchedule.nextAfter] says when a pay that ends has no payday
/// left: a day so far off that nothing reaches it.
final payNever = DateTime(9999, 12, 31);

/// Where a payday that falls on a Saturday or Sunday goes: the Friday
/// before, the Monday after, or nowhere (some are paid on a Saturday).
enum PayWeekend { before, after, keep }

/// The preference set by "I don't have regular pay": nothing asks for pay
/// while there's none (self-employed, between jobs). '1' when set.
const noRegularPayKey = 'pay.none';

class PaySchedule {
  const PaySchedule({
    required this.id,
    required this.categoryId,
    required this.accountId,
    required this.amount,
    required this.rule,
    this.amount2,
    this.name,
    this.payee,
    this.varies = false,
    this.day1 = 25,
    this.day2 = 10,
    this.weeks = 2,
    this.anchor,
    this.repeat,
    this.weekend = PayWeekend.before,
    this.definesPeriod = false,
  });

  final int id;

  /// The Income category, which every payday is filed under.
  final int categoryId;

  /// The account it's paid into.
  final int accountId;

  /// Positive minor units. With [varies], the least it's likely to be: the
  /// forecast counts on it, so the low end is the safe one.
  final int amount;

  /// Twice a month only: what comes on [day2], when it isn't [amount] (an
  /// advance on one day, the rest on the other). Null: the same both days.
  final int? amount2;
  final bool varies;

  /// What the user calls this pay ("Jenny", "Jeff's school"): how two
  /// earners' pays are told apart on the Budget page. Null until named;
  /// `payTitle` in ui/data_words.dart falls back to the payer, then the
  /// account.
  final String? name;

  /// Who it comes from (the employer), optional. Pay history is matched by
  /// it.
  final String? payee;
  final PayRule rule;

  /// Monthly: [day1]. Twice a month: [day2] and [day1] (either order). Days
  /// past a month's end land on its last day.
  final int day1;
  final int day2;

  /// Every [weeks] weeks, counting from [anchor] (a payday).
  final int weeks;

  /// Every N weeks: the payday it counts from. [PayRule.custom]: the first.
  final DateTime? anchor;

  /// [PayRule.custom] only: how it repeats.
  final PayRepeat? repeat;

  /// Where a payday on a Saturday or Sunday goes.
  final PayWeekend weekend;

  /// The Budget page is viewed by this schedule's pay periods (at most
  /// one is; none means by month). A view: each category keeps its own
  /// period, a month or a pay's, in its plan.
  final bool definesPeriod;

  /// Two different amounts, one for each day of the month.
  bool get split =>
      rule == PayRule.twiceMonthly && amount2 != null && amount2 != amount;

  /// Split pay by day of the month, the earlier day first:
  /// `[(day: 10, amount: advance), (day: 25, amount: rest)]`. One entry for
  /// pay that's the same each payday.
  List<({int day, int amount})> get byDay {
    if (!split) return [(day: day1, amount: amount)];
    final a = (day: day1, amount: amount), b = (day: day2, amount: amount2!);
    return day1 < day2 ? [a, b] : [b, a];
  }

  /// What comes on [payday] (a date this schedule lands on, weekend rule
  /// applied): [amount2] when it's [day2]'s payday.
  int amountOn(DateTime payday) {
    if (!split) return amount;
    final p = dateOnly(payday);
    for (final n in _nominalDays(_addDays(p, -7))) {
      final moved = _offWeekend(n.date);
      if (moved == p) return n.day == day2 ? amount2! : amount;
      if (moved.isAfter(p)) break;
    }
    // Not one of its paydays (a row moved by hand): the nearest plan's.
    return amountOn(plannedFor(p));
  }

  /// About what comes in a month: both days' pay for twice a month.
  int get perMonth => switch (rule) {
    PayRule.monthly => amount,
    PayRule.twiceMonthly => amount + (amount2 ?? amount),
    PayRule.everyWeeks => amount * perYear ~/ 12,
    PayRule.custom => amount * perYear ~/ 12,
  };

  /// Paydays a year, for the "26 paydays" note.
  int get perYear => switch (rule) {
    PayRule.monthly => 12,
    PayRule.twiceMonthly => 24,
    PayRule.everyWeeks => (52 / weeks).round(),
    PayRule.custom => repeat?.perYear ?? 1,
  };

  /// The first payday strictly after [after], weekend rule applied. An
  /// every-N-weeks schedule starts at [anchor]: nothing before it.
  DateTime nextAfter(DateTime after) {
    var a = dateOnly(after);
    final start = anchor;
    if (rule == PayRule.everyWeeks && start != null) {
      final dayBefore = _addDays(dateOnly(start), -1);
      if (a.isBefore(dayBefore)) a = dayBefore;
    }
    // Nominal dates are generated in order and each is moved off a weekend;
    // a move can't reorder two paydays a week or more apart.
    for (final d in _nominalFrom(_addDays(a, -7))) {
      final moved = _offWeekend(d);
      if (moved.isAfter(a)) return moved;
    }
    // Only a pay that ends runs out of paydays.
    return payNever;
  }

  /// The last payday on or before [day] (the schedule's rhythm, even before
  /// an every-N-weeks start), or null if none is found.
  DateTime? lastOnOrBefore(DateTime day) {
    final d = dateOnly(day);
    // Far enough back to hold one whole interval, whatever the weeks.
    final back = rule == PayRule.custom
        ? 800
        : (7 * weeks + 14 > 70 ? 7 * weeks + 14 : 70);
    DateTime? last;
    for (final n in _nominalFrom(_addDays(d, -back))) {
      final moved = _offWeekend(n);
      if (moved.isAfter(d)) break;
      last = moved;
    }
    return last;
  }

  /// The planned payday a paycheck posted on [posted] belongs to: the
  /// nearest one. Pay confirmed two days early (before a holiday) or a few
  /// days late is still that payday, so the next is the one after it.
  ///
  /// Split pay with [paid] goes by amount first: an advance confirmed a week
  /// late is still the advance, not the rest that's due sooner. Pay on a
  /// payday is that payday's, whatever it came to: a main pay short this
  /// month isn't next month's advance (budget review, #187).
  DateTime plannedFor(DateTime posted, {int? paid}) {
    final p = dateOnly(posted);
    final before = lastOnOrBefore(p);
    final after = nextAfter(p);
    if (before == null) return after;
    if (split && paid != null && before != p) {
      final b = (amountOn(before) - paid).abs();
      final a = (amountOn(after) - paid).abs();
      if (a != b) return b < a ? before : after;
    }
    return p.difference(before).inHours <= after.difference(p).inHours
        ? before
        : after;
  }

  /// The pay period [day] is in: from its last payday up to the day before
  /// the next.
  ({DateTime start, DateTime end})? periodOf(DateTime day) {
    final start = lastOnOrBefore(day);
    if (start == null) return null;
    final next = nextAfter(day);
    return (start: start, end: _addDays(next, -1));
  }

  // Calendar days, never Durations: across a daylight-saving change a day
  // is 23 or 25 hours and a Duration lands on the wrong date.
  static DateTime _addDays(DateTime d, int n) =>
      DateTime(d.year, d.month, d.day + n);

  DateTime _offWeekend(DateTime d) => offWeekend(d, weekend);

  /// Nominal paydays (before the weekend rule) from [from] on, in order.
  Iterable<DateTime> _nominalFrom(DateTime from) =>
      _nominalDays(from).map((n) => n.date);

  /// [_nominalFrom] with the day of the month each came from (0 for every
  /// N weeks), so split pay knows which amount a payday is.
  Iterable<({DateTime date, int day})> _nominalDays(DateTime from) sync* {
    switch (rule) {
      case PayRule.monthly || PayRule.twiceMonthly:
        final days = rule == PayRule.monthly ? [day1] : ([day1, day2]..sort());
        var y = from.year, m = from.month;
        while (true) {
          for (final day in days) {
            final d = DateTime(y, m, _clampDay(y, m, day));
            if (!d.isBefore(from)) yield (date: d, day: day);
          }
          if (++m > 12) {
            m = 1;
            y++;
          }
        }
      case PayRule.custom:
        // The same dates a category's bills have (Budget.dueAfter): the
        // first at or after [from], then on, until it ends.
        final plan = _repeatPlan;
        final last = Budget.lastDue(plan);
        var i = _firstFrom(plan, from);
        while (true) {
          final d = Budget.dueAfter(plan, i++);
          if (last != null && d.isAfter(last)) return;
          yield (date: d, day: 0);
          // A repeat with nothing to repeat has its one date.
          if (!plan.repeats) return;
        }
      case PayRule.everyWeeks:
        final step = 7 * weeks;
        var d = dateOnly(anchor ?? from);
        // Straight to about [from] in whole steps (UTC days, so a
        // daylight-saving change can't miscount); walking there one step
        // at a time made a far date slow, and a budget counts periods to
        // dates years ahead.
        final apart = DateTime.utc(
          from.year,
          from.month,
          from.day,
        ).difference(DateTime.utc(d.year, d.month, d.day)).inDays;
        d = _addDays(d, (apart ~/ step) * step);
        // Back to the first on or after [from], in whole steps.
        while (d.isAfter(from)) {
          d = _addDays(d, -step);
        }
        while (d.isBefore(from)) {
          d = _addDays(d, step);
        }
        while (true) {
          yield (date: d, day: 0);
          d = DateTime(d.year, d.month, d.day + 7 * weeks);
        }
    }
  }

  /// This pay as a category's plan says it, the answers How often asks: the
  /// form shows and changes it as a plan, [shapeOf] turns it back. Its first
  /// date is the next payday's day (the nominal one, before the weekend rule)
  /// from [today], or the first of a custom pay.
  CategoryPlan asPlan(DateTime today) {
    final t = dateOnly(today);
    DateTime onOrAfter(int day) {
      var d = DateTime(t.year, t.month, _clampDay(t.year, t.month, day));
      if (d.isBefore(t)) {
        d = DateTime(t.year, t.month + 1, _clampDay(t.year, t.month + 1, day));
      }
      return d;
    }

    final days = [day1, day2]..sort();
    return switch (rule) {
      PayRule.custom => CategoryPlan(
        categoryId: categoryId,
        kind: PlanKind.byDate,
        amount: amount,
        start: t,
        due: dateOnly(anchor ?? t),
        everyMonths: repeat?.everyMonths,
        everyDays: repeat?.everyDays,
        onDates: repeat?.onDates,
        monthDays: repeat?.monthDays,
        weekdays: repeat?.weekdays,
        nth: repeat?.nth,
        nthWeekday: repeat?.nthWeekday,
        endDate: repeat?.endDate,
        endCount: repeat?.endCount,
        weekend: weekend,
      ),
      PayRule.monthly => CategoryPlan(
        categoryId: categoryId,
        kind: PlanKind.byDate,
        amount: amount,
        start: t,
        due: onOrAfter(day1),
        everyMonths: 1,
        weekend: weekend,
      ),
      PayRule.twiceMonthly => CategoryPlan(
        categoryId: categoryId,
        kind: PlanKind.byDate,
        amount: amount,
        start: t,
        due: onOrAfter(days.first),
        monthDays: days,
        weekend: weekend,
      ),
      PayRule.everyWeeks => CategoryPlan(
        categoryId: categoryId,
        kind: PlanKind.byDate,
        amount: amount,
        start: t,
        due: dateOnly(anchor ?? t),
        everyDays: 7 * weeks,
        weekend: weekend,
      ),
    };
  }

  /// How [plan], as How often's answers made it, is kept: the three shapes
  /// a pay had before keep their own rule and days (they are exact and
  /// every pay already saved is one), anything else is [PayRule.custom].
  /// Twice a month keeps the later day as [day1], as it always has.
  static ({
    PayRule rule,
    int day1,
    int day2,
    int weeks,
    DateTime anchor,
    PayRepeat? repeat,
  })
  shapeOf(CategoryPlan plan) {
    final due = dateOnly(plan.due ?? plan.start);
    final ends = plan.endDate != null || plan.endCount != null;
    final plain =
        !ends &&
        plan.onDates == null &&
        plan.weekdays == null &&
        plan.nth == null;
    if (plain && plan.monthDays?.length == 2 && plan.everyDays == null) {
      final d = [...plan.monthDays!]..sort();
      return (
        rule: PayRule.twiceMonthly,
        day1: d.last,
        day2: d.first,
        weeks: 2,
        anchor: due,
        repeat: null,
      );
    }
    if (plain &&
        plan.monthDays == null &&
        plan.everyMonths == 1 &&
        plan.everyDays == null) {
      return (
        rule: PayRule.monthly,
        day1: due.day,
        day2: 10,
        weeks: 2,
        anchor: due,
        repeat: null,
      );
    }
    final days = plan.everyDays;
    if (plain &&
        plan.monthDays == null &&
        plan.everyMonths == null &&
        days != null &&
        days % 7 == 0 &&
        days <= 56) {
      return (
        rule: PayRule.everyWeeks,
        day1: 25,
        day2: 10,
        weeks: days ~/ 7,
        anchor: due,
        repeat: null,
      );
    }
    return (
      rule: PayRule.custom,
      day1: 25,
      day2: 10,
      weeks: 2,
      anchor: due,
      repeat: PayRepeat(
        everyMonths: plan.everyMonths,
        everyDays: plan.everyDays,
        onDates: plan.onDates,
        monthDays: plan.monthDays,
        weekdays: plan.weekdays,
        nth: plan.nth,
        nthWeekday: plan.nthWeekday,
        endDate: plan.endDate,
        endCount: plan.endCount,
      ),
    );
  }

  static final _plans = Expando<CategoryPlan>();

  /// This pay's repeat as a category's plan: the same dates come from it.
  /// The weekend rule is the pay's own, applied after, so not here.
  CategoryPlan get _repeatPlan => _plans[this] ??= () {
    final r = repeat ?? const PayRepeat(everyMonths: 1);
    final first = dateOnly(anchor ?? DateTime.now());
    return CategoryPlan(
      categoryId: categoryId,
      kind: PlanKind.byDate,
      amount: amount,
      start: first,
      due: first,
      everyMonths: r.everyMonths,
      everyDays: r.everyDays,
      onDates: r.onDates,
      monthDays: r.monthDays,
      weekdays: r.weekdays,
      nth: r.nth,
      nthWeekday: r.nthWeekday,
      endDate: r.endDate,
      endCount: r.endCount,
    );
  }();

  /// The index of the first date of [plan] on or after [from]: found by
  /// doubling and halving, so a date years ahead costs a few steps.
  static int _firstFrom(CategoryPlan plan, DateTime from) {
    const most = 5200;
    if (!plan.repeats || !Budget.dueAfter(plan, 0).isBefore(from)) return 0;
    var hi = 1;
    while (hi < most && Budget.dueAfter(plan, hi).isBefore(from)) {
      hi *= 2;
    }
    var lo = hi ~/ 2;
    hi = hi < most ? hi : most;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (Budget.dueAfter(plan, mid).isBefore(from)) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  static int _clampDay(int y, int m, int day) {
    final last = DateTime(y, m + 1, 0).day;
    return day < 1 ? 1 : (day > last ? last : day);
  }

  /// How much and when, with [money] formatting an amount: "₮2,100,000 or
  /// more on the 10th and 25th", or split, "₮500,000 on the 10th and
  /// ₮1,600,000 on the 25th" ("at least" in front when it varies). English;
  /// `payAmounts` in ui/data_words.dart words it for the screen.
  String describeAmounts(String Function(int) money, {String sep = ' '}) {
    if (!split) {
      return '${money(amount)}${varies ? ' or more' : ''}$sep$describe';
    }
    final d = byDay;
    return '${varies ? 'at least ' : ''}${money(d[0].amount)} on the '
        '${_ordinal(d[0].day)} and ${money(d[1].amount)} on the '
        '${_ordinal(d[1].day)}';
  }

  /// "monthly on the 25th", "on the 10th and 25th", "every 2 weeks". English;
  /// `payWhen` in ui/data_words.dart words it for the screen.
  String get describe => switch (rule) {
    PayRule.monthly => 'monthly on the ${_ordinal(day1)}',
    PayRule.twiceMonthly =>
      'on the ${_ordinal(day1 < day2 ? day1 : day2)} and '
          '${_ordinal(day1 < day2 ? day2 : day1)}',
    PayRule.everyWeeks => weeks == 1 ? 'every week' : 'every $weeks weeks',
    PayRule.custom => 'on its own dates',
  };

  static String ordinal(int n) => _ordinal(n);

  static String _ordinal(int n) {
    final mod100 = n % 100;
    final suffix = mod100 >= 11 && mod100 <= 13
        ? 'th'
        : switch (n % 10) {
            1 => 'st',
            2 => 'nd',
            3 => 'rd',
            _ => 'th',
          };
    return '$n$suffix';
  }
}

/// What the budget runs by: calendar months, or a pay schedule's periods.
/// Today it decides the span a category's rows open with. [label] is in
/// English, [payPeriodLabel] or [monthLabel]; `periodName` in
/// ui/data_words.dart words it for the screen.
({DateTime start, DateTime end, String label}) budgetPeriod(
  DateTime today,
  PaySchedule? by,
) {
  final t = dateOnly(today);
  final period = by?.periodOf(t);
  if (period != null) {
    return (start: period.start, end: period.end, label: payPeriodLabel);
  }
  return (
    start: DateTime(t.year, t.month),
    end: DateTime(t.year, t.month + 1, 0),
    label: monthLabel,
  );
}

/// [budgetPeriod]'s labels, in English.
const payPeriodLabel = 'this pay period';
const monthLabel = 'this month';

/// [d] moved off a weekend by [rule]: the Friday before, the Monday
/// after, or left where it is. Paydays and a plan's bills share it.
DateTime offWeekend(DateTime d, PayWeekend rule) => switch ((d.weekday, rule)) {
  (_, PayWeekend.keep) => d,
  (DateTime.saturday, PayWeekend.before) => DateTime(
    d.year,
    d.month,
    d.day - 1,
  ),
  (DateTime.saturday, _) => DateTime(d.year, d.month, d.day + 2),
  (DateTime.sunday, PayWeekend.before) => DateTime(d.year, d.month, d.day - 2),
  (DateTime.sunday, _) => DateTime(d.year, d.month, d.day + 1),
  _ => d,
};
