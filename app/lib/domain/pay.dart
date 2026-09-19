/// When pay comes: the dates a pay schedule lands on, and the pay period a
/// day falls in. Pure Dart: no database, no Flutter (ADR 0004, rule 24).
library;

import 'ledger.dart';

enum PayRule { monthly, twiceMonthly, everyWeeks }

class PaySchedule {
  const PaySchedule({
    required this.id,
    required this.categoryId,
    required this.accountId,
    required this.amount,
    required this.rule,
    this.payee,
    this.varies = false,
    this.day1 = 25,
    this.day2 = 10,
    this.weeks = 2,
    this.anchor,
    this.weekendBefore = true,
    this.definesPeriod = false,
  });

  final int id;

  /// The income category it's filed under (Salary), which it marks payday.
  final int categoryId;

  /// The account it's paid into.
  final int accountId;

  /// Positive minor units. With [varies], the least it's likely to be: the
  /// forecast counts on it, so the low end is the safe one.
  final int amount;
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

  /// A payday on a Saturday or Sunday moves to the Friday before, or with
  /// false the Monday after.
  final bool weekendBefore;

  /// Budget by pay period, and this schedule's paydays are its bounds.
  final bool definesPeriod;

  /// Paydays a year, for the "26 paydays" note.
  int get perYear => switch (rule) {
    PayRule.monthly => 12,
    PayRule.twiceMonthly => 24,
    PayRule.everyWeeks => (52 / weeks).round(),
  };

  /// The first payday strictly after [after], weekend rule applied.
  DateTime nextAfter(DateTime after) {
    final a = dateOnly(after);
    // Nominal dates are generated in order and each is moved off a weekend;
    // a move can't reorder two paydays a week or more apart.
    for (final d in _nominalFrom(a.subtract(const Duration(days: 7)))) {
      final moved = _offWeekend(d);
      if (moved.isAfter(a)) return moved;
    }
    throw StateError('unreachable');
  }

  /// The last payday on or before [day], or null if none can be (an every-N-
  /// weeks schedule that starts later).
  DateTime? lastOnOrBefore(DateTime day) {
    final d = dateOnly(day);
    DateTime? last;
    for (final n in _nominalFrom(d.subtract(const Duration(days: 70)))) {
      final moved = _offWeekend(n);
      if (moved.isAfter(d)) break;
      last = moved;
    }
    return last;
  }

  /// The pay period [day] is in: from its last payday up to the day before
  /// the next.
  ({DateTime start, DateTime end})? periodOf(DateTime day) {
    final start = lastOnOrBefore(day);
    if (start == null) return null;
    final next = nextAfter(day);
    return (start: start, end: next.subtract(const Duration(days: 1)));
  }

  DateTime _offWeekend(DateTime d) => switch (d.weekday) {
    DateTime.saturday => d.add(Duration(days: weekendBefore ? -1 : 2)),
    DateTime.sunday => d.add(Duration(days: weekendBefore ? -2 : 1)),
    _ => d,
  };

  /// Nominal paydays (before the weekend rule) from [from] on, in order.
  Iterable<DateTime> _nominalFrom(DateTime from) sync* {
    switch (rule) {
      case PayRule.monthly || PayRule.twiceMonthly:
        final days = rule == PayRule.monthly ? [day1] : ([day1, day2]..sort());
        var y = from.year, m = from.month;
        while (true) {
          for (final day in days) {
            final d = DateTime(y, m, _clampDay(y, m, day));
            if (!d.isBefore(from)) yield d;
          }
          if (++m > 12) {
            m = 1;
            y++;
          }
        }
      case PayRule.everyWeeks:
        final step = Duration(days: 7 * weeks);
        var d = dateOnly(anchor ?? from);
        // Back to the first on or after [from], in whole steps.
        while (d.isAfter(from)) {
          d = d.subtract(step);
        }
        while (d.isBefore(from)) {
          d = d.add(step);
        }
        while (true) {
          yield d;
          d = DateTime(d.year, d.month, d.day + 7 * weeks);
        }
    }
  }

  static int _clampDay(int y, int m, int day) {
    final last = DateTime(y, m + 1, 0).day;
    return day < 1 ? 1 : (day > last ? last : day);
  }

  /// "monthly on the 25th", "on the 10th and 25th", "every 2 weeks".
  String get describe => switch (rule) {
    PayRule.monthly => 'monthly on the ${_ordinal(day1)}',
    PayRule.twiceMonthly =>
      'on the ${_ordinal(day1 < day2 ? day1 : day2)} and '
          '${_ordinal(day1 < day2 ? day2 : day1)}',
    PayRule.everyWeeks => weeks == 1 ? 'every week' : 'every $weeks weeks',
  };

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
/// Today it decides the span a category's rows open with.
({DateTime start, DateTime end, String label}) budgetPeriod(
  DateTime today,
  PaySchedule? by,
) {
  final t = dateOnly(today);
  final period = by?.periodOf(t);
  if (period != null) {
    return (start: period.start, end: period.end, label: 'this pay period');
  }
  return (
    start: DateTime(t.year, t.month),
    end: DateTime(t.year, t.month + 1, 0),
    label: 'this month',
  );
}
