import 'package:betterbudget/domain/pay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PaySchedule s(
    PayRule rule, {
    int day1 = 25,
    int day2 = 10,
    int weeks = 2,
    DateTime? anchor,
    PayWeekend weekend = PayWeekend.before,
  }) => PaySchedule(
    id: 1,
    categoryId: 1,
    accountId: 1,
    amount: 100,
    rule: rule,
    day1: day1,
    day2: day2,
    weeks: weeks,
    anchor: anchor,
    weekend: weekend,
  );

  test('monthly: the day, moved off a weekend', () {
    final pay = s(PayRule.monthly);
    // 2026.09.25 is a Friday; 2026.10.25 a Sunday → Friday 10.23.
    expect(pay.nextAfter(DateTime(2026, 9, 16)), DateTime(2026, 9, 25));
    expect(pay.nextAfter(DateTime(2026, 9, 25)), DateTime(2026, 10, 23));
    expect(
      s(
        PayRule.monthly,
        weekend: PayWeekend.after,
      ).nextAfter(DateTime(2026, 9, 25)),
      DateTime(2026, 10, 26),
    );
  });

  test('keep the day: a Saturday or Sunday payday stays put', () {
    // 2026.10.25 is a Sunday, 2026.10.31 a Saturday.
    final keep = s(PayRule.monthly, weekend: PayWeekend.keep);
    expect(keep.nextAfter(DateTime(2026, 9, 25)), DateTime(2026, 10, 25));
    final sat = s(PayRule.monthly, day1: 31, weekend: PayWeekend.keep);
    expect(sat.nextAfter(DateTime(2026, 10, 20)), DateTime(2026, 10, 31));
    // Every other Saturday, from Saturday 2026.10.03.
    final weekly = s(
      PayRule.everyWeeks,
      anchor: DateTime(2026, 10, 3),
      weekend: PayWeekend.keep,
    );
    expect(weekly.nextAfter(DateTime(2026, 10, 3)), DateTime(2026, 10, 17));
    expect(
      weekly.lastOnOrBefore(DateTime(2026, 10, 20)),
      DateTime(2026, 10, 17),
    );
  });

  test('a day past the month’s end lands on its last day', () {
    final pay = s(PayRule.monthly, day1: 31);
    expect(pay.nextAfter(DateTime(2026, 9, 1)), DateTime(2026, 9, 30));
    // February 2027 ends on a Sunday (28th): the Friday before.
    expect(pay.nextAfter(DateTime(2027, 2, 1)), DateTime(2027, 2, 26));
  });

  test('twice a month with an advance, then the rest', () {
    const pay = PaySchedule(
      id: 1,
      categoryId: 1,
      accountId: 1,
      amount: 160000000,
      amount2: 50000000,
      rule: PayRule.twiceMonthly,
      day1: 25,
      day2: 10,
    );
    expect(pay.split, isTrue);
    expect(pay.byDay, [
      (day: 10, amount: 50000000),
      (day: 25, amount: 160000000),
    ]);
    expect(pay.amountOn(DateTime(2026, 9, 10)), 50000000);
    expect(pay.amountOn(DateTime(2026, 9, 25)), 160000000);
    // 10.10 is a Saturday, paid Friday 10.09; 10.25 a Sunday, paid 10.23.
    expect(pay.amountOn(DateTime(2026, 10, 9)), 50000000);
    expect(pay.amountOn(DateTime(2026, 10, 23)), 160000000);
    // A row moved by hand: its nearest payday's amount.
    expect(pay.amountOn(DateTime(2026, 9, 12)), 50000000);
    expect(pay.perMonth, 210000000);
    // The advance confirmed on the 18th (nearer the 25th) is still the 10th's.
    expect(
      pay.plannedFor(DateTime(2026, 9, 18), paid: 50000000),
      DateTime(2026, 9, 10),
    );
    expect(
      pay.plannedFor(DateTime(2026, 9, 18), paid: 160000000),
      DateTime(2026, 9, 25),
    );
    // The main pay short on its own day is still the 25th's, though its
    // amount is nearer the next advance's.
    expect(
      pay.plannedFor(DateTime(2026, 9, 25), paid: 90000000),
      DateTime(2026, 9, 25),
    );
    String money(int v) => '₮${v ~/ 100}';
    expect(
      pay.describeAmounts(money),
      '₮500000 on the 10th and ₮1600000 on the 25th',
    );
    // The same both days is one amount.
    expect(s(PayRule.twiceMonthly).split, isFalse);
    expect(
      s(PayRule.twiceMonthly).describeAmounts(money),
      '₮1 on the 10th and 25th',
    );
    expect(s(PayRule.twiceMonthly).perMonth, 200);
  });

  test('twice a month, in order whichever day is typed first', () {
    final pay = s(PayRule.twiceMonthly, day1: 25, day2: 10);
    expect(pay.nextAfter(DateTime(2026, 9, 1)), DateTime(2026, 9, 10));
    expect(pay.nextAfter(DateTime(2026, 9, 10)), DateTime(2026, 9, 25));
    expect(pay.describe, 'on the 10th and 25th');
  });

  test('every two weeks from a payday; the period runs to the next', () {
    final pay = s(
      PayRule.everyWeeks,
      anchor: DateTime(2026, 9, 11), // a Friday
    );
    expect(pay.nextAfter(DateTime(2026, 9, 11)), DateTime(2026, 9, 25));
    // Nothing before its first payday: a new job starting later.
    expect(pay.nextAfter(DateTime(2026, 8, 1)), DateTime(2026, 9, 11));
    expect(pay.periodOf(DateTime(2026, 9, 19)), (
      start: DateTime(2026, 9, 11),
      end: DateTime(2026, 9, 24),
    ));
    expect(pay.perYear, 26);
  });

  test('the budget runs by month unless a pay schedule defines it', () {
    final month = budgetPeriod(DateTime(2026, 9, 19), null);
    expect(month.start, DateTime(2026, 9, 1));
    expect(month.end, DateTime(2026, 9, 30));
    expect(month.label, 'this month');
    final paid = budgetPeriod(
      DateTime(2026, 9, 19),
      s(PayRule.twiceMonthly, day1: 10, day2: 25),
    );
    expect(paid.start, DateTime(2026, 9, 10));
    expect(paid.end, DateTime(2026, 9, 24));
  });

  test('pay confirmed early or late belongs to its planned payday', () {
    final pay = s(PayRule.monthly);
    // Paid on 09.23 for the 25th (before a holiday): still the 25th's.
    expect(pay.plannedFor(DateTime(2026, 9, 23)), DateTime(2026, 9, 25));
    expect(pay.plannedFor(DateTime(2026, 9, 28)), DateTime(2026, 9, 25));
    final twice = s(PayRule.twiceMonthly, day1: 10, day2: 25);
    expect(twice.plannedFor(DateTime(2026, 9, 12)), DateTime(2026, 9, 10));
  });

  test('a weekend move can cross into the previous month', () {
    // 2026.08.01 is a Saturday: the Friday before is 07.31.
    final pay = s(PayRule.monthly, day1: 1);
    expect(pay.nextAfter(DateTime(2026, 7, 20)), DateTime(2026, 7, 31));
    // Monday after, at a month's end: 2026.10.31 is a Saturday → 11.02.
    expect(
      s(
        PayRule.monthly,
        day1: 31,
        weekend: PayWeekend.after,
      ).nextAfter(DateTime(2026, 10, 20)),
      DateTime(2026, 11, 2),
    );
  });

  group('a pay on the kinds of repeat a category has (#438)', () {
    PaySchedule custom(
      PayRepeat r, {
      DateTime? first,
      PayWeekend weekend = PayWeekend.keep,
      int amount = 100,
    }) => PaySchedule(
      id: 1,
      categoryId: 1,
      accountId: 1,
      amount: amount,
      rule: PayRule.custom,
      anchor: first ?? DateTime(2026, 10, 2),
      repeat: r,
      weekend: weekend,
    );

    test('every few days, from its first date', () {
      final p = custom(const PayRepeat(everyDays: 10));
      expect(p.nextAfter(DateTime(2026, 9, 1)), DateTime(2026, 10, 2));
      expect(p.nextAfter(DateTime(2026, 10, 2)), DateTime(2026, 10, 12));
      expect(p.nextAfter(DateTime(2027, 3, 1)), DateTime(2027, 3, 11));
      expect(p.lastOnOrBefore(DateTime(2026, 10, 25)), DateTime(2026, 10, 22));
      expect(p.lastOnOrBefore(DateTime(2026, 9, 1)), isNull);
    });

    test('chosen weekdays every other week', () {
      // Monday and Thursday, every 2 weeks, from Mon 2026.10.05.
      final p = custom(
        const PayRepeat(everyDays: 14, weekdays: [1, 4]),
        first: DateTime(2026, 10, 5),
      );
      expect(p.nextAfter(DateTime(2026, 10, 5)), DateTime(2026, 10, 8));
      expect(p.nextAfter(DateTime(2026, 10, 8)), DateTime(2026, 10, 19));
      expect(p.nextAfter(DateTime(2026, 10, 19)), DateTime(2026, 10, 22));
      expect(p.perYear, 52);
    });

    test('the nth weekday of the month, the last Friday', () {
      final p = custom(
        const PayRepeat(everyMonths: 1, nth: -1, nthWeekday: 5),
        first: DateTime(2026, 10, 30),
      );
      expect(p.nextAfter(DateTime(2026, 10, 30)), DateTime(2026, 11, 27));
      expect(p.nextAfter(DateTime(2026, 11, 27)), DateTime(2026, 12, 25));
    });

    test('every quarter, and dates in a year, with the weekend rule', () {
      final quarterly = custom(
        const PayRepeat(everyMonths: 3),
        first: DateTime(2026, 10, 31),
        weekend: PayWeekend.before,
      );
      // 2027.01.31 is a Sunday: the Friday before.
      expect(
        quarterly.nextAfter(DateTime(2026, 10, 31)),
        DateTime(2027, 1, 29),
      );
      expect(quarterly.perYear, 4);
      final taxes = custom(
        const PayRepeat(onDates: [(3, 15), (9, 15)]),
        first: DateTime(2026, 9, 15),
      );
      expect(taxes.nextAfter(DateTime(2026, 9, 15)), DateTime(2027, 3, 15));
      expect(taxes.nextAfter(DateTime(2027, 3, 15)), DateTime(2027, 9, 15));
    });

    test('it ends, by a date or by a count, and then has no payday', () {
      final byDate = custom(
        PayRepeat(everyMonths: 1, endDate: DateTime(2026, 12, 31)),
        first: DateTime(2026, 10, 10),
      );
      expect(byDate.nextAfter(DateTime(2026, 11, 10)), DateTime(2026, 12, 10));
      expect(byDate.nextAfter(DateTime(2026, 12, 10)), payNever);
      final byCount = custom(
        const PayRepeat(everyDays: 7, endCount: 3),
        first: DateTime(2026, 10, 2),
      );
      expect(byCount.nextAfter(DateTime(2026, 10, 9)), DateTime(2026, 10, 16));
      expect(byCount.nextAfter(DateTime(2026, 10, 16)), payNever);
      // The last one it had is still the last on or before a later day.
      expect(
        byCount.lastOnOrBefore(DateTime(2027, 5, 1)),
        DateTime(2026, 10, 16),
      );
    });

    test('an income that has ended has no pay period: the budget goes by '
        'months', () {
      final p = custom(
        PayRepeat(everyMonths: 1, endDate: DateTime(2026, 12, 31)),
        first: DateTime(2026, 10, 10),
      );
      expect(p.periodOf(DateTime(2026, 11, 20)), isNotNull);
      expect(p.periodOf(DateTime(2027, 2, 1)), isNull);
      final b = budgetPeriod(DateTime(2027, 2, 1), p);
      expect(b.start, DateTime(2027, 2, 1));
      expect(b.end, DateTime(2027, 2, 28));
    });

    test('the three older shapes come back from the form as they went in', () {
      PaySchedule back(PaySchedule p, DateTime today) {
        final shape = PaySchedule.shapeOf(p.asPlan(today));
        return PaySchedule(
          id: p.id,
          categoryId: p.categoryId,
          accountId: p.accountId,
          amount: p.amount,
          amount2: p.amount2,
          rule: shape.rule,
          day1: shape.day1,
          day2: shape.day2,
          weeks: shape.weeks,
          anchor: shape.anchor,
          repeat: shape.repeat,
          weekend: p.weekend,
        );
      }

      // A pay on the 31st, opened in February: still the 31st.
      final monthly = s(PayRule.monthly, day1: 31);
      for (final today in [DateTime(2027, 2, 10), DateTime(2026, 11, 3)]) {
        final b = back(monthly, today);
        expect(b.rule, PayRule.monthly);
        expect(b.day1, 31);
      }
      final first = back(s(PayRule.monthly, day1: 29), DateTime(2027, 2, 10));
      expect(first.day1, 29);
      // Twice a month keeps the later day as day1.
      final twice = back(
        s(PayRule.twiceMonthly, day1: 25, day2: 10),
        DateTime(2026, 9, 16),
      );
      expect(
        (twice.rule, twice.day1, twice.day2),
        (PayRule.twiceMonthly, 25, 10),
      );
      // Every few weeks keeps its weeks and its payday.
      final weeks = back(
        PaySchedule(
          id: 1,
          categoryId: 1,
          accountId: 1,
          amount: 100,
          rule: PayRule.everyWeeks,
          weeks: 3,
          anchor: DateTime(2026, 10, 2),
        ),
        DateTime(2026, 9, 16),
      );
      expect(
        (weeks.rule, weeks.weeks, weeks.anchor),
        (PayRule.everyWeeks, 3, DateTime(2026, 10, 2)),
      );
      // Its dates are the same ones.
      expect(weeks.nextAfter(DateTime(2026, 10, 3)), DateTime(2026, 10, 23));
    });

    test('an income that has ended: the payday it was planned as is its '
        'last, not the year 9999', () {
      final p = custom(
        PayRepeat(everyMonths: 1, endDate: DateTime(2026, 12, 31)),
        first: DateTime(2026, 10, 10),
      );
      expect(p.plannedFor(DateTime(2027, 3, 1)), DateTime(2026, 12, 10));
      expect(
        custom(
          PayRepeat(everyMonths: 1, endDate: DateTime(2026, 12, 31)),
          first: DateTime(2030, 1, 1),
        ).plannedFor(DateTime(2027, 3, 1)),
        isNot(payNever),
      );
    });

    test('a far date is a few steps, and the monthly figure is about', () {
      final p = custom(const PayRepeat(everyDays: 14), amount: 1200);
      expect(
        p.nextAfter(DateTime(2056, 1, 1)).isAfter(DateTime(2056, 1, 1)),
        isTrue,
      );
      expect(p.perMonth, 1200 * 26 ~/ 12);
    });
  });
}
