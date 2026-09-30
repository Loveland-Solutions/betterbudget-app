import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/domain/budget.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/money.dart';
import 'package:betterbudget/domain/pay.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The envelopes (rule 26), worked out from a small ledger.
void main() {
  final today = DateTime(2026, 10, 20);
  final oct = (start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 31));
  final nov = (start: DateTime(2026, 11, 1), end: DateTime(2026, 11, 30));
  const checking = 1, visa = 2, mortgage = 3, dollars = 4;
  const food = 10, dining = 11, xmas = 12, coffee = 13, salary = 20;
  const opening = 30, waiting = 31, housing = 32;
  var nextId = 100;

  AccountInfo acct(
    int id,
    String name,
    AccountType t, {
    AccountRole? role,
    Currency currency = Currency.mnt,
    bool deleted = false,
  }) => AccountInfo(
    id: id,
    name: name,
    type: t,
    role: role,
    currency: currency,
    deleted: deleted,
  );

  TxnData move(
    DateTime date,
    int from,
    int to,
    int amount, {
    bool scheduled = false,
    Currency currency = Currency.mnt,
  }) => TxnData(
    id: nextId++,
    date: date,
    scheduled: scheduled,
    entries: [
      EntryData(
        id: nextId++,
        accountId: from,
        amount: -amount,
        currency: currency,
      ),
      EntryData(
        id: nextId++,
        accountId: to,
        amount: amount,
        currency: currency,
      ),
    ],
  );

  BudgetAmount put(int category, DateTime date, int amount) =>
      BudgetAmount(categoryId: category, date: date, amount: amount);

  /// ₮5,400,000 in checking, ₮860,000 owed on the card, a mortgage and a
  /// dollar account that don't count.
  LedgerData ledger({
    List<TxnData> rows = const [],
    List<BudgetAmount> amounts = const [],
    bool diningDeleted = false,
    Map<String, String> prefs = const {},
  }) => LedgerData(
    prefs: prefs,
    accounts: [
      acct(checking, 'Checking', AccountType.asset),
      acct(visa, 'Visa', AccountType.liability),
      acct(mortgage, 'Home', AccountType.liability, role: AccountRole.mortgage),
      acct(dollars, 'AFCU', AccountType.asset, currency: Currency.usd),
      acct(food, 'Groceries', AccountType.expense),
      acct(dining, 'Dining out', AccountType.expense, deleted: diningDeleted),
      acct(xmas, 'Christmas', AccountType.expense),
      acct(coffee, 'Coffee', AccountType.expense),
      acct(salary, 'Salary', AccountType.income),
      acct(waiting, 'Not categorized', AccountType.expense),
      acct(housing, 'Housing', AccountType.expense),
      acct(opening, 'Opening balances', AccountType.equity),
    ],
    txns: [
      move(DateTime(2026, 8, 1), opening, checking, 540000000),
      move(DateTime(2026, 8, 1), visa, opening, 86000000),
      move(DateTime(2026, 8, 1), mortgage, opening, 9000000000),
      move(
        DateTime(2026, 8, 1),
        opening,
        dollars,
        250000,
        currency: Currency.usd,
      ),
      ...rows,
    ],
    budgetAmounts: amounts,
  );

  Budget of(LedgerData d, ({DateTime start, DateTime end}) p) =>
      Budget.of(d, start: p.start, end: p.end, today: today);

  test('money not given out: cash and bank less cards less categories', () {
    final b = of(
      ledger(
        amounts: [
          put(food, oct.start, 90000000),
          put(xmas, oct.start, 30000000),
        ],
      ),
      oct,
    );
    // 5,400,000 − 860,000; the mortgage and the dollars aren't counted.
    expect(b.money, 454000000);
    expect(b.notAssigned, 454000000 - 120000000);
    expect(b.lines[food]!.assigned, 90000000);
    expect(b.lines[food]!.left, 90000000);
    expect(b.began, oct.start);
  });

  test('a card purchase comes out of its category and nothing else', () {
    final amounts = [put(food, oct.start, 90000000)];
    final before = of(ledger(amounts: amounts), oct);
    final after = of(
      ledger(
        amounts: amounts,
        rows: [move(DateTime(2026, 10, 5), visa, food, 8800000)],
      ),
      oct,
    );
    expect(after.lines[food]!.spent, 8800000);
    expect(after.lines[food]!.left, 90000000 - 8800000);
    expect(after.notAssigned, before.notAssigned);

    // Paying the card moves nothing on the Budget page.
    final paid = of(
      ledger(
        amounts: amounts,
        rows: [
          move(DateTime(2026, 10, 5), visa, food, 8800000),
          move(DateTime(2026, 10, 9), checking, visa, 8800000),
        ],
      ),
      oct,
    );
    expect(paid.notAssigned, after.notAssigned);
    expect(paid.lines[food]!.left, after.lines[food]!.left);
  });

  test('income adds to the money not given out', () {
    final b = of(
      ledger(rows: [move(DateTime(2026, 10, 10), salary, checking, 420000000)]),
      oct,
    );
    expect(b.cameIn[salary], 420000000);
    expect(b.notAssigned, 454000000 + 420000000);
  });

  test('overspending carries as minus into the next period', () {
    final d = ledger(
      amounts: [
        put(dining, oct.start, 15000000),
        put(dining, nov.start, 15000000),
      ],
      rows: [move(DateTime(2026, 10, 12), checking, dining, 18200000)],
    );
    final o = of(d, oct);
    expect(o.lines[dining]!.left, -3200000);
    final n = of(d, nov);
    expect(n.lines[dining]!.fromBefore, -3200000);
    expect(n.lines[dining]!.assigned, 15000000);
    expect(n.lines[dining]!.spent, 0);
    expect(n.lines[dining]!.left, 11800000);
  });

  test('what is left builds up in a category that is saved in', () {
    final d = ledger(
      amounts: [
        put(xmas, DateTime(2026, 9, 1), 10000000),
        put(xmas, oct.start, 10000000),
      ],
    );
    final o = of(d, oct);
    expect(o.lines[xmas]!.fromBefore, 10000000);
    expect(o.lines[xmas]!.left, 20000000);
  });

  test('spending before the budget began counts against no category', () {
    final d = ledger(
      amounts: [put(food, oct.start, 90000000)],
      rows: [
        move(DateTime(2026, 9, 20), checking, food, 5000000),
        move(DateTime(2026, 10, 3), checking, food, 1000000),
      ],
    );
    final o = of(d, oct);
    expect(o.lines[food]!.left, 89000000);
    expect(o.lines[food]!.fromBefore, 0);
    // September still shows what it spent; nothing was in it yet.
    final sep = of(d, (
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 9, 30),
    ));
    expect(sep.lines[food]!.spent, 5000000);
    expect(sep.lines[food]!.left, 0);
    expect(sep.lines[food]!.fromBefore, 0);
  });

  test('a category nothing was put in goes below zero when spent from', () {
    final d = ledger(
      amounts: [put(food, oct.start, 90000000)],
      rows: [move(DateTime(2026, 10, 3), checking, coffee, 450000)],
    );
    final o = of(d, oct);
    expect(o.lines[coffee]!.left, -450000);
    // Coffee carries it as minus, so the money not given out doesn't move.
    expect(o.notAssigned, 454000000 - 90000000);
  });

  test('refunds put money back', () {
    final d = ledger(
      amounts: [put(food, oct.start, 90000000)],
      rows: [
        move(DateTime(2026, 10, 3), checking, food, 2000000),
        move(DateTime(2026, 10, 4), food, checking, 500000),
      ],
    );
    expect(of(d, oct).lines[food]!.spent, 1500000);
    expect(of(d, oct).lines[food]!.left, 88500000);
  });

  test('scheduled rows and the other currency are left out', () {
    final d = ledger(
      amounts: [put(food, oct.start, 90000000)],
      rows: [
        move(DateTime(2026, 10, 25), checking, food, 7000000, scheduled: true),
        move(
          DateTime(2026, 10, 5),
          dollars,
          food,
          2500,
          currency: Currency.usd,
        ),
      ],
    );
    expect(of(d, oct).lines[food]!.spent, 0);
    expect(of(d, oct).notAssigned, 454000000 - 90000000);
  });

  test('a later period already given to counts now', () {
    final d = ledger(
      amounts: [put(food, oct.start, 90000000), put(food, nov.start, 90000000)],
    );
    expect(of(d, oct).lines[food]!.left, 90000000);
    expect(of(d, oct).notAssigned, 454000000 - 180000000);
  });

  test('a deleted category gives its money back', () {
    final d = ledger(
      amounts: [put(dining, oct.start, 15000000)],
      diningDeleted: true,
    );
    expect(of(d, oct).lines.containsKey(dining), isFalse);
    expect(of(d, oct).notAssigned, 454000000);
    expect(of(d, oct).began, isNull);
  });

  test('periods step by month, or by pay period', () {
    final m = budgetPeriod(DateTime(2026, 10, 20), null);
    expect(nextBudgetPeriod(m, null).start, nov.start);
    expect(previousBudgetPeriod(m, null).end, DateTime(2026, 9, 30));
    const pay = PaySchedule(
      id: 1,
      categoryId: salary,
      accountId: checking,
      amount: 100,
      rule: PayRule.twiceMonthly,
      day1: 10,
      day2: 25,
      weekend: PayWeekend.keep,
    );
    final p = budgetPeriod(DateTime(2026, 10, 20), pay);
    expect(p.start, DateTime(2026, 10, 10));
    expect(p.end, DateTime(2026, 10, 24));
    expect(nextBudgetPeriod(p, pay).start, DateTime(2026, 10, 25));
    expect(previousBudgetPeriod(p, pay).start, DateTime(2026, 9, 25));
  });

  test(
    'the saved start never moves: an earlier amount counts, not its spending',
    () {
      final d = ledger(
        prefs: {BudgetKeys.began: '2026-10-01'},
        amounts: [
          put(food, oct.start, 90000000),
          put(dining, DateTime(2026, 9, 1), 100),
        ],
        rows: [move(DateTime(2026, 9, 10), checking, dining, 18200000)],
      );
      final o = of(d, oct);
      expect(o.began, oct.start);
      // September's dining isn't counted; the ₮1 assigned then is.
      expect(o.lines[dining]!.left, 100);
      expect(o.notAssigned, 454000000 - 18200000 - 90000000 - 100);
    },
  );

  test('a first period under way: what unassigned categories spent', () {
    final d = ledger(
      amounts: [put(food, oct.start, 90000000)],
      rows: [
        move(DateTime(2026, 10, 3), checking, dining, 800000),
        move(DateTime(2026, 10, 4), checking, coffee, 450000),
        move(DateTime(2026, 10, 5), checking, food, 1000000),
      ],
    );
    expect(of(d, oct).unassignedSpent, (count: 2, amount: 1250000));
  });

  test('Not categorized holds nothing: its rows count in the top line', () {
    final d = ledger(
      amounts: [put(food, oct.start, 90000000)],
      rows: [
        move(DateTime(2026, 10, 10), waiting, checking, 250000000),
        move(DateTime(2026, 10, 11), checking, waiting, 3000000),
      ],
    );
    final o = of(d, oct);
    expect(o.lines.containsKey(waiting), isFalse);
    expect(o.uncategorizedRows, 2);
    expect(o.uncategorizedNet, 247000000);
    expect(o.notAssigned, 454000000 + 247000000 - 90000000);
  });

  test('a loan paid from a category spends from it', () {
    final key = '${BudgetKeys.loanPrefix}$mortgage';
    final rows = [move(DateTime(2026, 10, 15), checking, mortgage, 100000000)];
    final amounts = [put(housing, oct.start, 100000000)];
    final linked = of(
      ledger(prefs: {key: '$housing'}, amounts: amounts, rows: rows),
      oct,
    );
    expect(linked.lines[housing]!.spent, 100000000);
    expect(linked.lines[housing]!.left, 0);
    expect(linked.notAssigned, 454000000 - 100000000 - 0);
    // Without the link, the payment just lowers the money.
    final plain = of(ledger(amounts: amounts, rows: rows), oct);
    expect(plain.lines[housing]!.left, 100000000);
    expect(plain.notAssigned, linked.notAssigned - 100000000);
  });

  test('the budget keeps its currency when dollar accounts outnumber', () {
    final d = LedgerData(
      accounts: [
        AccountInfo(id: 1, name: 'A', type: AccountType.asset),
        for (final i in [2, 3])
          AccountInfo(
            id: i,
            name: 'D$i',
            type: AccountType.asset,
            currency: Currency.usd,
          ),
        AccountInfo(id: food, name: 'Groceries', type: AccountType.expense),
      ],
      txns: const [],
      prefs: {BudgetKeys.currency: 'MNT'},
    );
    expect(Budget.currencyOf(d), Currency.mnt);
  });

  group('database', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('setting an amount replaces it, undo puts it back', () async {
      final food = await db.createCategory('Groceries', income: false);
      await db.setBudgetAmount(food, oct.start, oct.end, 90000000);
      final before = await db.setBudgetAmount(
        food,
        oct.start,
        oct.end,
        95000000,
      );
      expect(before.single.amount, 90000000);
      var d = await db.loadLedger();
      expect(d.budgetAmounts.single.amount, 95000000);
      await db.restoreBudgetAmounts(food, oct.start, oct.end, before);
      d = await db.loadLedger();
      expect(d.budgetAmounts.single.amount, 90000000);
      // Zero clears it.
      await db.setBudgetAmount(food, oct.start, oct.end, 0);
      expect((await db.loadLedger()).budgetAmounts, isEmpty);
    });

    test('an amount anywhere in the period is replaced or cleared', () async {
      final food = await db.createCategory('Groceries', income: false);
      // Assigned by month, then viewed by a pay period 09.25–10.09.
      await db.setBudgetAmount(food, oct.start, oct.end, 50000000);
      final p = (start: DateTime(2026, 9, 25), end: DateTime(2026, 10, 9));
      final before = await db.setBudgetAmount(food, p.start, p.end, 30000000);
      var d = await db.loadLedger();
      expect(d.budgetAmounts.single.amount, 30000000);
      expect(d.budgetAmounts.single.date, p.start);
      // Undo puts the old one back on its own day.
      await db.restoreBudgetAmounts(food, p.start, p.end, before);
      d = await db.loadLedger();
      expect(d.budgetAmounts.single.date, oct.start);
      await db.setBudgetAmount(food, p.start, p.end, 0);
      expect((await db.loadLedger()).budgetAmounts, isEmpty);
    });

    test(
      'starting next period moves the amounts, undo moves them back',
      () async {
        final food = await db.createCategory('Groceries', income: false);
        await db.setBudgetAmount(food, oct.start, oct.end, 50000000);
        final moved = await db.moveBudgetAmounts(oct.start, oct.end, nov.start);
        expect((await db.loadLedger()).budgetAmounts.single.date, nov.start);
        await db.unmoveBudgetAmounts(moved);
        expect((await db.loadLedger()).budgetAmounts.single.date, oct.start);
      },
    );

    test('a new ledger clears the amounts', () async {
      final food = await db.createCategory('Groceries', income: false);
      await db.setBudgetAmount(food, oct.start, oct.end, 50000000);
      await db.startNewLedger(today, keepCategories: true);
      expect((await db.loadLedger()).budgetAmounts, isEmpty);
    });

    test('a merge moves the amounts, undo moves them back', () async {
      final food = await db.createCategory('Groceries', income: false);
      final snacks = await db.createCategory('Snacks', income: false);
      await db.setBudgetAmount(food, oct.start, oct.end, 90000000);
      await db.setBudgetAmount(snacks, oct.start, oct.end, 5000000);
      final gone = await db.deleteCategory(snacks, into: food);
      var d = await db.loadLedger();
      final o = Budget.of(d, start: oct.start, end: oct.end, today: today);
      expect(o.lines[food]!.assigned, 95000000);
      // Setting it again makes one amount of the two.
      final before = await db.setBudgetAmount(
        food,
        oct.start,
        oct.end,
        96000000,
      );
      expect(before, hasLength(2));
      await db.restoreBudgetAmounts(food, oct.start, oct.end, before);
      await db.undeleteCategory(gone);
      d = await db.loadLedger();
      final back = Budget.of(d, start: oct.start, end: oct.end, today: today);
      expect(back.lines[food]!.assigned, 90000000);
      expect(back.lines[snacks]!.assigned, 5000000);
    });
  });
}
