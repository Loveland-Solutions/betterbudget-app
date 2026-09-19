import 'package:betterbudget/domain/pay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PaySchedule s(
    PayRule rule, {
    int day1 = 25,
    int day2 = 10,
    int weeks = 2,
    DateTime? anchor,
    bool before = true,
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
    weekendBefore: before,
  );

  test('monthly: the day, moved off a weekend', () {
    final pay = s(PayRule.monthly);
    // 2026.09.25 is a Friday; 2026.10.25 a Sunday → Friday 10.23.
    expect(pay.nextAfter(DateTime(2026, 9, 16)), DateTime(2026, 9, 25));
    expect(pay.nextAfter(DateTime(2026, 9, 25)), DateTime(2026, 10, 23));
    expect(
      s(PayRule.monthly, before: false).nextAfter(DateTime(2026, 9, 25)),
      DateTime(2026, 10, 26),
    );
  });

  test('a day past the month’s end lands on its last day', () {
    final pay = s(PayRule.monthly, day1: 31);
    expect(pay.nextAfter(DateTime(2026, 9, 1)), DateTime(2026, 9, 30));
    // February 2027 ends on a Sunday (28th): the Friday before.
    expect(pay.nextAfter(DateTime(2027, 2, 1)), DateTime(2027, 2, 26));
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
        before: false,
      ).nextAfter(DateTime(2026, 10, 20)),
      DateTime(2026, 11, 2),
    );
  });
}
