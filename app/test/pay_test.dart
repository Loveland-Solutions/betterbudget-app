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
}
