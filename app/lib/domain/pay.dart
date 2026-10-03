/// When pay comes: the dates a pay schedule lands on, and the pay period a
/// day falls in. Pure Dart: no database, no Flutter (ADR 0004, rule 24).
library;

import 'ledger.dart';

enum PayRule { monthly, twiceMonthly, everyWeeks }

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
    this.payee,
    this.varies = false,
    this.day1 = 25,
    this.day2 = 10,
    this.weeks = 2,
    this.anchor,
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
  final String? payee;
  final PayRule rule;

  /// Monthly: [day1]. Twice a month: [day2] and [day1] (either order). Days
  /// past a month's end land on its last day.
  final int day1;
  final int day2;

  /// Every [weeks] weeks, counting from [anchor] (a payday).
  final int weeks;
  final DateTime? anchor;

  /// Where a payday on a Saturday or Sunday goes.
  final PayWeekend weekend;

  /// Budget by pay period, and this schedule's paydays are its bounds.
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
  };

  /// Paydays a year, for the "26 paydays" note.
  int get perYear => switch (rule) {
    PayRule.monthly => 12,
    PayRule.twiceMonthly => 24,
    PayRule.everyWeeks => (52 / weeks).round(),
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
    throw StateError('unreachable');
  }

  /// The last payday on or before [day] (the schedule's rhythm, even before
  /// an every-N-weeks start), or null if none is found.
  DateTime? lastOnOrBefore(DateTime day) {
    final d = dateOnly(day);
    // Far enough back to hold one whole interval, whatever the weeks.
    final back = 7 * weeks + 14 > 70 ? 7 * weeks + 14 : 70;
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
  /// late is still the advance, not the rest that's due sooner.
  DateTime plannedFor(DateTime posted, {int? paid}) {
    final p = dateOnly(posted);
    final before = lastOnOrBefore(p);
    final after = nextAfter(p);
    if (before == null) return after;
    if (split && paid != null) {
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

  DateTime _offWeekend(DateTime d) => switch ((d.weekday, weekend)) {
    (_, PayWeekend.keep) => d,
    (DateTime.saturday, PayWeekend.before) => _addDays(d, -1),
    (DateTime.saturday, _) => _addDays(d, 2),
    (DateTime.sunday, PayWeekend.before) => _addDays(d, -2),
    (DateTime.sunday, _) => _addDays(d, 1),
    _ => d,
  };

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
