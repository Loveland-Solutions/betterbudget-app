import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/phone_sync.dart';
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

  // The regular income acts the phone's Income page makes (#528), through
  // `actOnPay`, the code the phone's ledger runs.
  group('actOnPay', () {
    final today = DateTime(2026, 10, 12);
    Future<PhoneSnapshot> again() async =>
        snapshotOf(await db.loadLedger(), today: today, madeAt: today);
    Future<PhoneActed> act(PhoneRowAct a) => actOnPay(db, a, today, again);
    PhonePayDraft draft(
      int account, {
      int amount = 105000000,
      int? amount2,
      bool varies = false,
      PayRule rule = PayRule.monthly,
      int day1 = 25,
      int day2 = 10,
    }) => (
      accountId: account,
      name: 'Jenny’s job',
      payee: null,
      amount: amount,
      amount2: amount2,
      varies: varies,
      rule: rule,
      day1: day1,
      day2: day2,
      weeks: 2,
      anchor: DateTime(2026, 10, 25),
      repeat: null,
      weekend: PayWeekend.before,
    );

    test('twice a month with two amounts keeps the later day\'s as amount '
        'and the earlier day\'s as amount2, and a pay that varies', () async {
      final bank = await db.addAccount(name: 'Bank', type: AccountType.asset);
      await act(
        PhoneSavePay(
          null,
          draft(
            bank,
            amount: 160000000,
            amount2: 50000000,
            varies: true,
            rule: PayRule.twiceMonthly,
          ),
        ),
      );
      final pay = (await db.loadLedger()).paySchedules.single;
      expect(pay.varies, isTrue);
      expect(
        [for (final d in pay.byDay) (d.day, d.amount)],
        [(10, 50000000), (25, 160000000)],
      );
    });

    test('an Edit keeps the pay periods the budget is viewed by, and Undo '
        'and Redo put the pay back as it was and as it is', () async {
      final bank = await db.addAccount(name: 'Bank', type: AccountType.asset);
      final first = await db.savePaySchedule(
        accountId: bank,
        amount: 105000000,
        rule: PayRule.monthly,
        day1: 25,
        definesPeriod: true,
        today: today,
      );
      final id = first.after.id;
      final done = await act(PhoneSavePay(id, draft(bank, amount: 120000000)));
      var pay = (await db.loadLedger()).paySchedules.single;
      expect((pay.amount, pay.definesPeriod), (120000000, true));
      await done.undo();
      pay = (await db.loadLedger()).paySchedules.single;
      expect(pay.amount, 105000000);
      await done.redo();
      pay = (await db.loadLedger()).paySchedules.single;
      expect(pay.amount, 120000000);
    });

    test('a pay added after "I don\'t have regular income" clears the saying, '
        'and Undo and Redo bring it back and take it away', () async {
      final bank = await db.addAccount(name: 'Bank', type: AccountType.asset);
      await db.setPreference(noRegularPayKey, '1');
      final done = await act(PhoneSavePay(null, draft(bank)));
      Future<String?> said() async =>
          (await db.loadLedger()).prefs[noRegularPayKey];
      expect(await said(), isNull);
      await done.undo();
      expect(await said(), '1');
      expect((await db.loadLedger()).paySchedules, isEmpty);
      await done.redo();
      expect(await said(), isNull);
      expect((await db.loadLedger()).paySchedules, hasLength(1));
    });

    test('Stop sends the categories budgeted by its pay periods to the month, '
        'as the ledger has them now, and Undo and Redo follow', () async {
      final bank = await db.addAccount(name: 'Bank', type: AccountType.asset);
      final loan = await db.createCategory('Loan');
      final pay = await db.savePaySchedule(
        accountId: bank,
        amount: 105000000,
        rule: PayRule.monthly,
        day1: 25,
        today: today,
      );
      final id = pay.after.id;
      await db.setCategoryPlan(
        loan,
        CategoryPlan(
          categoryId: loan,
          kind: PlanKind.byDate,
          amount: 15000000,
          start: today,
          payScheduleId: id,
          daysAfterPay: 1,
          paidFrom: bank,
        ),
      );
      Future<int?> per() async =>
          (await db.loadLedger()).plans[loan]?.payScheduleId;
      expect(await per(), id);
      final done = await act(PhoneStopPay(id));
      expect((await db.loadLedger()).paySchedules, isEmpty);
      expect(await per(), isNull);
      await done.undo();
      expect((await db.loadLedger()).paySchedules, hasLength(1));
      expect(await per(), id);
      await done.redo();
      expect((await db.loadLedger()).paySchedules, isEmpty);
      expect(await per(), isNull);
    });

    test('saying there is no regular income twice changes nothing the second '
        'time', () async {
      await act(const PhoneNoPay(true));
      final again2 = await act(const PhoneNoPay(true));
      await again2.undo();
      // The second said nothing new, so its Undo leaves the first standing.
      expect((await db.loadLedger()).prefs[noRegularPayKey], '1');
    });
  });
}
