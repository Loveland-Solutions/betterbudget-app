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
    expect(pay.nextAfter(DateTime(2026, 8, 1)), DateTime(2026, 8, 14));
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
}
