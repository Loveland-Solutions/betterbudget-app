import '../domain/ledger.dart';
import 'database.dart';

/// Synthetic demo data (never real statement data), dated relative to [today]
/// so the register and forecast look the same whenever the app is first run.
/// Only seeds an empty database, and never one the user emptied by starting
/// a new ledger.
Future<void> seedDemoIfEmpty(AppDatabase db, DateTime today) async {
  if ((await db.select(db.accounts).get()).isNotEmpty) return;
  if (await db.startedOwnLedger()) return;

  await db.transaction(() async {
    final checking = await db.addAccount(
      name: 'TDB Checking',
      type: AccountType.asset,
      institution: 'Trade and Development Bank',
      mask: '4410',
      group: 'Cash & bank',
      sortOrder: 0,
    );
    final savings = await db.addAccount(
      name: 'Khan Savings',
      type: AccountType.asset,
      institution: 'Khan Bank',
      mask: '2291',
      group: 'Cash & bank',
      sortOrder: 1,
    );
    final cash = await db.addAccount(
      name: 'Cash wallet',
      type: AccountType.asset,
      group: 'Cash & bank',
      sortOrder: 2,
    );
    final visa = await db.addAccount(
      name: 'Golomt Visa',
      type: AccountType.liability,
      institution: 'Golomt Bank',
      mask: '7788',
      group: 'Credit',
      sortOrder: 3,
    );
    final opening = await db.addAccount(
      name: AppDatabase.openingBalancesName,
      type: AccountType.equity,
    );

    final cat = <String, int>{};
    for (final n in ['Salary']) {
      cat[n] = await db.addAccount(
        name: n,
        type: AccountType.income,
        payday: true,
      );
    }
    for (final n in [
      'Groceries',
      'Household',
      'Dining out',
      'Transport',
      'Utilities',
      'Phone & internet',
      'Entertainment',
      'Bank fees',
      'Housing',
      'Childcare',
      'Tuition',
      'Health',
      'Clothing',
      'Gifts',
    ]) {
      cat[n] = await db.addAccount(name: n, type: AccountType.expense);
    }

    DateTime day(int offset) => dateOnly(today).add(Duration(days: offset));
    const unc = Cleared.uncleared,
        clr = Cleared.cleared,
        rec = Cleared.reconciled;
    // Only an account's own side is ever reconciled, and only by a statement:
    // the other side of a locked row (category, opening balance, the other
    // account of a transfer) stays cleared.
    Cleared other(Cleared c) => c == rec ? clr : c;

    Future<void> open(int account, int amount, int offset, Cleared c) =>
        db.postTransaction(
          date: day(offset),
          lines: [
            (accountId: account, amount: amount, cleared: c),
            (accountId: opening, amount: -amount, cleared: other(c)),
          ],
        );
    await open(checking, 310419100, -15, rec);
    await open(savings, 1210000000, -15, clr);
    await open(cash, 8650000, -15, clr);
    await open(visa, -99020000, -15, clr);

    Future<void> spend(
      int offset,
      String payee,
      String category,
      int amount,
      Cleared c, {
      String? memo,
    }) => db.postTransaction(
      date: day(offset),
      payee: payee,
      memo: memo,
      lines: [
        (accountId: checking, amount: amount, cleared: c),
        (accountId: cat[category]!, amount: -amount, cleared: other(c)),
      ],
    );
    Future<void> transfer(
      int offset,
      int to,
      int amount,
      Cleared c, {
      String? memo,
    }) => db.postTransaction(
      date: day(offset),
      memo: memo,
      lines: [
        (accountId: checking, amount: -amount, cleared: c),
        (accountId: to, amount: amount, cleared: other(c)),
      ],
    );

    await transfer(-14, visa, 35000000, rec, memo: 'Card payment');
    await spend(
      -11,
      'Өргөө кино театр',
      'Entertainment',
      -4800000,
      rec,
      memo: 'POS · Сүхбаатар дүүрэг',
    );
    await spend(
      -8,
      'УБЦТС ТӨХК',
      'Utilities',
      -6421050,
      rec,
      memo: 'Electricity',
    );
    await spend(-6, 'Altan Gadas LLC', 'Salary', 250000000, rec, memo: 'Цалин');
    await db.addReconciliation(checking, day(-6), 514198050);
    await db.linkReconciledEntries();
    await spend(
      -4,
      'E-Mart Хан-Уул',
      'Groceries',
      -21475050,
      clr,
      memo: 'QPay',
    );
    await spend(
      -3,
      'Шунхлай',
      'Transport',
      -12000000,
      clr,
      memo: 'Fuel · АИ-92',
    );
    await spend(-2, 'Sakura Coffee', 'Dining out', -800000, clr, memo: 'POS');
    await spend(-1, 'TDB', 'Bank fees', -38000, clr, memo: 'CHARGE: 380.00 ₮');
    await transfer(-1, savings, 50000000, clr, memo: 'Monthly savings');
    await spend(
      0,
      'Unitel',
      'Phone & internet',
      -3000000,
      unc,
      memo: 'Postpaid',
    );
    await db.postTransaction(
      date: day(0),
      payee: 'Номин супермаркет',
      lines: [
        (accountId: checking, amount: -8640000, cleared: unc),
        (accountId: cat['Groceries']!, amount: 6190000, cleared: unc),
        (accountId: cat['Household']!, amount: 2450000, cleared: unc),
      ],
    );

    Future<void> schedule(
      int offset,
      String payee,
      String category,
      int amount, {
      String? memo,
    }) => db.postTransaction(
      date: day(offset),
      payee: payee,
      memo: memo,
      scheduled: true,
      lines: [
        (accountId: checking, amount: amount, cleared: unc),
        (accountId: cat[category]!, amount: -amount, cleared: unc),
      ],
    );
    await schedule(4, 'Zaisan Residence', 'Housing', -180000000, memo: 'Rent');
    await db.postTransaction(
      date: day(9),
      memo: 'Card payment',
      scheduled: true,
      lines: [
        (accountId: checking, amount: -64020000, cleared: unc),
        (accountId: visa, amount: 64020000, cleared: unc),
      ],
    );
    await schedule(15, 'Нарлаг цэцэрлэг', 'Childcare', -35000000);
    await schedule(24, 'Altan Gadas LLC', 'Salary', 250000000, memo: 'Цалин');
  });
}
