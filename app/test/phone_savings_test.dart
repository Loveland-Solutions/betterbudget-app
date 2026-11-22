import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/data/phone_sync.dart';
import 'package:betterbudget/domain/budget.dart'
    show Budget, BudgetKeys, CategoryType;
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/phone.dart';
import 'package:betterbudget/domain/readiness.dart';
import 'package:betterbudget/domain/setup.dart' show WalkKeys, WalkStep;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// The Savings answers the phone's Savings tab writes (#533), through
// `actOnSavings`, the code the phone's ledger runs: preferences together, a
// step skipped, what a debt counts as, and a goal's date moved, each undone
// and done again exactly; and a goal made by Savings' Add a goal left out
// of a month of expenses when the phone's ledger takes it in.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final today = DateTime(2026, 10, 7);
  Future<PhoneSnapshot> again() async =>
      snapshotOf(await db.loadLedger(), today: today, madeAt: today);
  Future<PhoneActed> act(PhoneSavingsAnswer a) =>
      actOnSavings(db, a, today, again);

  test('answers are written together; Undo puts back each as it was and '
      'Redo writes them again', () async {
    await db.setPreference(ReadyKeys.method, 'rate');
    await db.setPreference(ReadyKeys.target, '12');
    final done = await act(
      const PhoneSavingsAnswer({
        ReadyKeys.method: null,
        ReadyKeys.target: null,
      }),
    );
    expect(await db.preference(ReadyKeys.method), isNull);
    expect(await db.preference(ReadyKeys.target), isNull);
    await done.undo();
    expect(await db.preference(ReadyKeys.method), 'rate');
    expect(await db.preference(ReadyKeys.target), '12');
    await done.redo();
    expect(await db.preference(ReadyKeys.method), isNull);
    expect(await db.preference(ReadyKeys.target), isNull);
  });

  test('a step skipped is worked out from what is stored, so two count; '
      'Undo of the second keeps the first', () async {
    await act(const PhoneSavingsAnswer({}, aside: (ReadyStep.oneMonth, true)));
    final second = await act(
      const PhoneSavingsAnswer({}, aside: (ReadyStep.moreMonths, true)),
    );
    expect(
      (await db.preference(ReadyKeys.setAside))!.split(','),
      unorderedEquals(['oneMonth', 'moreMonths']),
    );
    await second.undo();
    expect(await db.preference(ReadyKeys.setAside), 'oneMonth');
    await second.redo();
    expect(
      (await db.preference(ReadyKeys.setAside))!.split(','),
      unorderedEquals(['oneMonth', 'moreMonths']),
    );
  });

  test('what a debt counts as: Undo puts back the very role it had, a '
      'student loan included', () async {
    final loan = await db.createAccount(
      name: 'School loan',
      type: AccountType.liability,
    );
    await db.setAccountRole(loan, AccountRole.studentLoan);
    final done = await act(
      PhoneSavingsAnswer(const {}, role: (loan, AccountRole.mortgage)),
    );
    Future<AccountRole?> role() async =>
        (await db.loadLedger()).accounts[loan]!.role;
    expect(await role(), AccountRole.mortgage);
    await done.undo();
    expect(await role(), AccountRole.studentLoan);
    await done.redo();
    expect(await role(), AccountRole.mortgage);
  });

  test('Move the date: the plan and the late answer together, Undo puts '
      'both back and Redo moves it again', () async {
    final wedding = await db.createCategory('Wedding');
    final plan = CategoryPlan(
      categoryId: wedding,
      kind: PlanKind.byDate,
      amount: 300000000,
      start: DateTime(2026, 6, 1),
      due: DateTime(2026, 9, 30),
    );
    await db.setCategoryPlan(wedding, plan);
    await db.setPreference(ReadyKeys.goal(wedding), 'yes');
    await db.setPreference(ReadyKeys.goalLate(wedding), 'all');
    final moved = CategoryPlan(
      categoryId: wedding,
      kind: PlanKind.byDate,
      amount: 300000000,
      start: DateTime(2026, 6, 1),
      due: DateTime(2026, 12, 31),
    );
    final done = await act(
      PhoneSavingsAnswer(
        {ReadyKeys.goalLate(wedding): null},
        plan: (wedding, moved),
      ),
    );
    Future<DateTime?> due() async =>
        (await db.loadLedger()).plans[wedding]!.due;
    expect(await due(), DateTime(2026, 12, 31));
    expect(await db.preference(ReadyKeys.goalLate(wedding)), isNull);
    await done.undo();
    expect(await due(), DateTime(2026, 9, 30));
    expect(await db.preference(ReadyKeys.goalLate(wedding)), 'all');
    await done.redo();
    expect(await due(), DateTime(2026, 12, 31));
    expect(await db.preference(ReadyKeys.goalLate(wedding)), isNull);
  });

  test('a plan the ledger refuses leaves the answers as they were', () async {
    await db.setPreference(ReadyKeys.goalLate(999999), 'all');
    await expectLater(
      act(
        PhoneSavingsAnswer(
          {ReadyKeys.goalLate(999999): null},
          plan: (
            999999,
            CategoryPlan(
              categoryId: 999999,
              kind: PlanKind.byDate,
              amount: 100,
              start: DateTime(2026, 6, 1),
              due: DateTime(2026, 12, 31),
            ),
          ),
        ),
      ),
      throwsA(anything),
    );
    expect(await db.preference(ReadyKeys.goalLate(999999)), 'all');
  });

  test('an answer that changes nothing writes nothing', () async {
    await db.setPreference(ReadyKeys.months, '5');
    final done = await act(const PhoneSavingsAnswer({ReadyKeys.months: '5'}));
    await done.undo();
    expect(await db.preference(ReadyKeys.months), '5');
  });

  group('a goal made on the phone, taken in', () {
    PhoneCategory goal(String name, {required bool outOfMonth}) =>
        PhoneCategory(
          id: 'new-$name',
          name: name,
          leftMinor: 0,
          madeHere: true,
          type: CategoryType.goal,
          outOfMonth: outOfMonth,
          plan: CategoryPlan(
            categoryId: 0,
            kind: PlanKind.byDate,
            amount: 700000000,
            start: today,
            due: DateTime(2027, 6, 30),
          ),
        );

    test('from Savings’ Add a goal is left out of a month of expenses; one '
        'from Budget stays in, as on the computer', () async {
      await seedDemoIfEmpty(db, today);
      await db.takePhoneEntries([
        PhoneInbox(
          device: 'ab12',
          categories: [
            goal('Wedding', outOfMonth: true),
            goal('Car', outOfMonth: false),
          ],
        ),
      ], today: today);
      final data = await db.loadLedger();
      int id(String name) =>
          data.accounts.values.singleWhere((a) => a.name == name).id;
      expect(data.prefs[ReadyKeys.goal(id('Wedding'))], 'yes');
      expect(data.prefs[ReadyKeys.goal(id('Car'))], 'yes');
      expect(inMonthOfExpenses(data, id('Wedding')), isFalse);
      expect(inMonthOfExpenses(data, id('Car')), isTrue);
    });
  });

  test('the walkthrough’s bill that pays a card (#475): the card’s payments '
      'come out of it once taken in; Undo of the take puts back what the '
      'card had, Redo ties it again', () async {
    final card = await db.createAccount(
      name: 'Golomt card',
      type: AccountType.liability,
    );
    final key = '${BudgetKeys.loanPrefix}$card';
    await db.setPreference(key, '424242');
    final take = await db.takePhoneEntries([
      PhoneInbox(
        device: 'ab12',
        categories: [
          PhoneCategory(
            id: 'new-card-bill',
            name: 'Card payment',
            leftMinor: 0,
            madeHere: true,
            type: CategoryType.bill,
            paysLoan: card,
          ),
          // One with no card to pay ties nothing.
          const PhoneCategory(
            id: 'new-rent',
            name: 'Rent',
            leftMinor: 0,
            madeHere: true,
            type: CategoryType.bill,
          ),
        ],
      ),
    ], today: today);
    final data = await db.loadLedger();
    final bill = data.accounts.values
        .singleWhere((a) => a.name == 'Card payment')
        .id;
    expect(Budget.loanCategory(data, card), bill);
    expect(Budget.loanOfCategory(data, bill), card);
    await db.undoPhoneTake(take!);
    expect(await db.preference(key), '424242');
    await db.redoPhoneTake(take);
    expect(await db.preference(key), '$bill');
    // Tied elsewhere since: an undo of the take leaves that be.
    await db.setPreference(key, '777');
    await db.undoPhoneTake(take);
    expect(await db.preference(key), '777');
  });

  test('a card gone before the take ties nothing', () async {
    await db.takePhoneEntries([
      const PhoneInbox(
        device: 'ab12',
        categories: [
          PhoneCategory(
            id: 'new-card-bill',
            name: 'Card payment',
            leftMinor: 0,
            madeHere: true,
            type: CategoryType.bill,
            paysLoan: 987654,
          ),
        ],
      ),
    ], today: today);
    expect(await db.preference('${BudgetKeys.loanPrefix}987654'), isNull);
  });

  test('the walk’s Assign step: more assigned than there is is said as '
      'short, not as waiting for pay (#475)', () async {
    final food = await db.createCategory('Food');
    await db.setCategoryPlan(
      food,
      CategoryPlan(
        categoryId: food,
        kind: PlanKind.each,
        amount: 10000000,
        start: DateTime(2026, 10),
      ),
    );
    await db.setBudgetAmount(
      food,
      DateTime(2026, 10),
      DateTime(2026, 10, 31),
      5000000,
    );
    await db.setPreference(WalkKeys.started, '2026-10-07');
    for (final s in [WalkStep.bills, WalkStep.dayToDay]) {
      await db.setPreference(WalkKeys.passed(s), 'yes');
    }
    final walk = (await again()).walk!;
    expect(walk.step, WalkStep.assign);
    expect(walk.short, isTrue);
  });
}
