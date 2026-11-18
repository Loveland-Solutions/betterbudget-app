// Counting a cash account (#119, ADR 0004 "Counting a cash account"): a
// count is its difference row, which keeps what was counted; the
// difference follows the rows dated up to it.

import 'dart:io';

import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/phone_inbox.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/phone.dart';
import 'package:betterbudget/domain/sync.dart' show MadeHow;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late int wallet;
  late int groceries;
  late int holding;
  final today = DateTime(2026, 11, 30);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    wallet = await db.createAccount(
      name: 'Wallet',
      type: AccountType.asset,
      cash: true,
    );
    groceries = await db.createCategory('Groceries');
    holding = await db.createCategory('Not categorized');
  });
  tearDown(() => db.close());

  Future<int> spend(int day, int amount) => db.postSimple(
    accountId: wallet,
    date: DateTime(2026, 11, day),
    today: today,
    payee: 'Market',
    counterAccountId: groceries,
    amount: -amount,
  );

  Future<RegisterRow> countRow(int id) async => (await db.loadLedger())
      .registerFor(wallet)
      .posted
      .singleWhere((r) => r.txnId == id);

  test(
    'a count is a row of the difference that keeps what was counted',
    () async {
      await db.postSimple(
        accountId: wallet,
        date: DateTime(2026, 11, 1),
        today: today,
        payee: 'ATM',
        counterAccountId: holding,
        amount: 300000,
      );
      await spend(5, 45000);
      await spend(9, 8000);
      // The rows say 247,000; the wallet holds 212,500.
      final id = (await db.postCount(
        accountId: wallet,
        date: DateTime(2026, 11, 18),
        counted: 212500,
        categoryId: holding,
      )).id;
      final row = await countRow(id);
      expect(row.counted, 212500);
      expect(row.amount, -34500);
      expect(row.balance, 212500);
      expect(row.categoryId, holding);
    },
  );

  test('the difference is saved once, as on a bank account: a receipt for '
      'an earlier day that comes in later changes the balance, not the '
      'count', () async {
    await spend(1, -200000); // money in
    final id = (await db.postCount(
      accountId: wallet,
      date: DateTime(2026, 11, 18),
      counted: 165500,
      categoryId: holding,
    )).id;
    expect((await countRow(id)).amount, -34500);
    await spend(16, 12000);
    expect((await countRow(id)).amount, -34500);
    final data = await db.loadLedger();
    expect(data.balanceOf(wallet), 165500 - 12000);
  });

  test('two counts: each is measured from the rows as they are when it is '
      'made; one that matches is a row of nothing', () async {
    await spend(1, -100000);
    final first = (await db.postCount(
      accountId: wallet,
      date: DateTime(2026, 11, 10),
      counted: 90000,
      categoryId: groceries,
    )).id;
    expect((await countRow(first)).amount, -10000);
    final second = (await db.postCount(
      accountId: wallet,
      date: DateTime(2026, 11, 20),
      counted: 90000,
      categoryId: holding,
    )).id;
    expect((await countRow(second)).amount, 0);
    expect((await countRow(second)).counted, 90000);
    // Undone, the first's row goes; the second stays as it was saved.
    await db.softDeleteMany([first]);
    expect((await countRow(second)).amount, 0);
    expect((await db.loadLedger()).balanceOf(wallet), 100000);
  });

  test('a wallet with no opening balance that holds more than its rows: '
      'the extra is its opening balance, at its first row (owner, '
      '2026-11-18)', () async {
    // Started at nothing, a receipt typed on the 5th.
    await spend(5, 20000);
    final saved = await db.postCount(
      accountId: wallet,
      date: DateTime(2026, 11, 18),
      counted: 85000,
      categoryId: holding,
    );
    expect(saved.difference, 105000);
    expect(saved.openingId, isNotNull);
    final rows = (await db.loadLedger()).registerFor(wallet).posted;
    final opening = rows.singleWhere((r) => r.kind == RowKind.opening);
    expect(opening.amount, 105000);
    expect(opening.date, DateTime(2026, 11, 5));
    expect((await countRow(saved.id)).amount, 0);
    expect((await countRow(saved.id)).counted, 85000);
    expect((await db.loadLedger()).balanceOf(wallet), 85000);
    // Nothing went to Not categorized.
    expect(
      rows.where((r) => r.categoryId == holding && r.amount != 0),
      isEmpty,
    );
    // A second count is an ordinary one: the opening balance is there.
    final next = await db.postCount(
      accountId: wallet,
      date: DateTime(2026, 11, 25),
      counted: 90000,
      categoryId: holding,
    );
    expect(next.openingId, isNull);
    expect((await countRow(next.id)).amount, 5000);
  });

  test('with no opening balance, less than the rows is still missing '
      'money, not a starting balance below nothing', () async {
    await spend(5, -50000);
    final saved = await db.postCount(
      accountId: wallet,
      date: DateTime(2026, 11, 18),
      counted: 40000,
      categoryId: holding,
    );
    expect(saved.openingId, isNull);
    expect((await countRow(saved.id)).amount, -10000);
  });

  group('counted on a phone', () {
    final morning = DateTime(2026, 11, 18, 9);
    PhoneEntry typed(String id, int minutes, int amount) => PhoneEntry(
      id: id,
      categoryId: '$groceries',
      accountId: '$wallet',
      payee: 'Market',
      amountMinor: amount,
      date: DateTime(2026, 11, 18),
      madeAt: morning.add(Duration(minutes: minutes)),
    );
    PhoneCount counted(int minutes, int amount, {String? category}) =>
        PhoneCount(
          id: 'count-$minutes',
          accountId: '$wallet',
          countedMinor: amount,
          date: DateTime(2026, 11, 18),
          madeAt: morning.add(Duration(minutes: minutes)),
          categoryId: category,
          heldMinor: 0,
        );

    test('is saved once, in the order the phone made things', () async {
      await db.postSimple(
        accountId: wallet,
        date: DateTime(2026, 11, 1),
        today: today,
        payee: 'ATM',
        counterAccountId: holding,
        amount: 300000,
      );
      // Spent 20,000 before counting 250,000 (30,000 missing), then lunch
      // for 10,000 after: lunch isn't in what the count found missing.
      final inbox = PhoneInbox(
        device: 'ab12',
        entries: [typed('lunch', 120, -10000), typed('bread', 0, -20000)],
        counts: [counted(30, 250000)],
      );
      final take = (await db.takePhoneEntries([inbox], today: today))!;
      expect(take.counts.single.difference, -30000);
      expect(take.counts.single.categoryId, holding);
      expect(take.counts.single.opening, isFalse);
      final data = await db.loadLedger();
      expect(data.balanceOf(wallet), 240000);
      final row = data
          .registerFor(wallet)
          .posted
          .singleWhere((r) => r.counted != null);
      expect(row.counted, 250000);
      expect(row.amount, -30000);
      expect(row.madeHow, MadeHow.phone);

      // Read again, nothing comes in twice.
      expect(await db.takePhoneEntries([inbox], today: today), isNull);

      // Undo takes the count's row out with the entries.
      await db.undoPhoneTake(take);
      expect((await db.loadLedger()).balanceOf(wallet), 300000);
    });

    test('two phones: lunch typed on one after a count on the other isn\'t '
        'missing money; a forgotten purchase from the day before is taken '
        'before the count', () async {
      await db.postSimple(
        accountId: wallet,
        date: DateTime(2026, 11, 1),
        today: today,
        payee: 'ATM',
        counterAccountId: holding,
        amount: 50000,
      );
      final hers = PhoneInbox(
        device: 'aa11',
        // Counted 40,000 at 9:30; then remembered Sunday's 10,000.
        entries: [
          PhoneEntry(
            id: 'sunday',
            categoryId: '$groceries',
            accountId: '$wallet',
            payee: 'Market',
            amountMinor: -10000,
            date: DateTime(2026, 11, 16),
            madeAt: morning.add(const Duration(minutes: 40)),
          ),
        ],
        counts: [counted(30, 40000)],
      );
      // Lunch at noon on the other phone, read first.
      final his = PhoneInbox(
        device: 'bb22',
        entries: [typed('lunch', 180, -5000)],
      );
      final take = (await db.takePhoneEntries([his, hers], today: today))!;
      // The rows held 40,000 at the count, Sunday's purchase included.
      expect(take.counts.single.difference, 0);
      expect((await db.loadLedger()).balanceOf(wallet), 35000);
    });

    test('goes to the category picked, and makes an opening balance when '
        'the wallet had none', () async {
      final picked = (await db.takePhoneEntries([
        PhoneInbox(
          device: 'ab12',
          counts: [counted(0, 50000, category: '$groceries')],
        ),
      ], today: today))!;
      // No rows and no opening balance: the cash found is where it starts.
      expect(picked.counts.single.opening, isTrue);
      expect(picked.counts.single.difference, 50000);
      expect((await db.loadLedger()).balanceOf(wallet), 50000);

      final again = (await db.takePhoneEntries([
        PhoneInbox(
          device: 'ab12',
          counts: [
            counted(0, 50000, category: '$groceries'),
            counted(60, 42000, category: '$groceries'),
          ],
        ),
      ], today: today))!;
      expect(again.counts.single.categoryId, groceries);
      expect(again.counts.single.difference, -8000);
      expect((await db.loadLedger()).balanceOf(wallet), 42000);
    });

    test('a category gone since goes to Not categorized; a bank account '
        'isn\'t counted', () async {
      final bank = await db.createAccount(name: 'TDB', type: AccountType.asset);
      final take = (await db.takePhoneEntries([
        PhoneInbox(
          device: 'ab12',
          counts: [
            counted(0, 0, category: '999'),
            PhoneCount(
              id: 'bank',
              accountId: '$bank',
              countedMinor: 1000,
              date: DateTime(2026, 11, 18),
              madeAt: morning,
              heldMinor: 0,
            ),
          ],
        ),
      ], today: today))!;
      expect(take.counts.single.categoryId, holding);
      expect((await db.loadLedger()).balanceOf(bank), 0);
    });

    test('travels in the phone’s file', () {
      final dir = Directory.systemTemp.createTempSync('bb-count');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/${phoneInboxName('ab12')}');
      writePhoneInbox(
        file,
        null,
        PhoneInbox(device: 'ab12', counts: [counted(5, 125000)]),
      );
      final back = readPhoneInbox(file, null).counts.single;
      expect(back.id, 'count-5');
      expect(back.accountId, '$wallet');
      expect(back.countedMinor, 125000);
      expect(back.madeAt, morning.add(const Duration(minutes: 5)));
      expect(back.categoryId, isNull);
      expect(
        phoneInboxSaying(PhoneInbox(device: 'ab12')),
        isNot(phoneInboxSaying(readPhoneInbox(file, null))),
      );
    });
  });
}
