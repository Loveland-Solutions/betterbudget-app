import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/domain/budget.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/money.dart';
import 'package:betterbudget/domain/pay.dart';
import 'package:betterbudget/domain/phone.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// The paydays on the phone's Income page (#528): each payday of the period
// marked as the sum at the top counts it.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('paydays are listed by date, the pay that came goes to the earliest, '
      'and a day gone by with no pay is missed', () async {
    final today = DateTime(2026, 10, 12);
    final bank = await db.addAccount(name: 'Bank', type: AccountType.asset);
    final job = await db.savePaySchedule(
      accountId: bank,
      amount: 105000000,
      rule: PayRule.twiceMonthly,
      day1: 25,
      day2: 10,
      name: 'Jenny’s job',
      today: today,
    );
    final support = await db.savePaySchedule(
      accountId: bank,
      amount: 40000000,
      rule: PayRule.monthly,
      day1: 5,
      today: today,
    );
    final income = await db.incomeCategory();
    // The 10th is a Saturday, so its payday is the 9th (and the 25th's the
    // 23rd). The 10th's pay came; the 5th's did not.
    await db.postTransaction(
      date: DateTime(2026, 10, 10),
      payScheduleId: job.after.id,
      lines: [
        (accountId: bank, amount: 105000000, cleared: Cleared.cleared),
        (accountId: income, amount: -105000000, cleared: Cleared.cleared),
      ],
    );
    final data = await db.loadLedger();
    final days = paydaysIn(
      data,
      start: DateTime(2026, 10),
      end: DateTime(2026, 10, 31),
      today: today,
    );
    expect(
      [for (final d in days) (d.date.day, d.pay.id, d.state)],
      [
        (5, support.after.id, PaydayState.missed),
        (9, job.after.id, PaydayState.came),
        (23, job.after.id, PaydayState.ahead),
      ],
    );
    // What the page says still to come is what the sum counts.
    final ahead = periodPay(
      data,
      start: DateTime(2026, 10),
      end: DateTime(2026, 10, 31),
      today: today,
    ).toCome;
    expect(ahead[Currency.mnt], 105000000);
  });

  test('the snapshot carries the paydays, money in waiting to be filed and '
      'whether regular income was declined', () async {
    final today = DateTime(2026, 10, 12);
    final bank = await db.addAccount(name: 'Bank', type: AccountType.asset);
    await db.savePaySchedule(
      accountId: bank,
      amount: 105000000,
      rule: PayRule.monthly,
      day1: 25,
      today: today,
    );
    var snap = snapshotOf(await db.loadLedger(), today: today, madeAt: today);
    final only = snap.income.paydays.single;
    expect(
      (only.date, only.amount, only.state, only.account, only.alone),
      (DateTime(2026, 10, 23), 105000000, PaydayState.ahead, 'Bank', true),
    );
    expect(snap.income.saidNone, isFalse);
    expect(snap.income.waiting, isEmpty);
    await db.setPreference(noRegularPayKey, '1');
    snap = snapshotOf(await db.loadLedger(), today: today, madeAt: today);
    expect(snap.income.saidNone, isTrue);
  });
}
