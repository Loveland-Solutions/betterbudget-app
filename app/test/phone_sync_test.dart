// The phone as a member of the folder (ADR 0005, #526 piece 3): its own ledger
// takes in the computers' changes through their change files and writes its
// own, and never writes the folder's whole ledger.
import 'dart:io';

import 'package:betterbudget/data/backup.dart';
import 'package:betterbudget/data/change_file.dart';
import 'package:betterbudget/data/cloud_folder.dart';
import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/data/encryption.dart';
import 'package:betterbudget/data/folder_io.dart';
import 'package:betterbudget/data/keys.dart';
import 'package:betterbudget/data/ledger_file.dart';
import 'package:betterbudget/data/phone_sync.dart';
import 'package:betterbudget/domain/budget.dart'
    show BillFit, BillPayment, BudgetKeys, billPayments;
import 'package:betterbudget/domain/combine.dart' show Pick;
import 'package:betterbudget/domain/ledger.dart'
    show CategoryPlan, Cleared, PlanKind, RegisterRow;
import 'package:betterbudget/domain/ledger.dart' show AccountType;
import 'package:betterbudget/domain/phone.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _MacAccess extends FolderAccess {
  const _MacAccess();
  @override
  Future<String?> derivedComputerId() async => 'aaaa';
  @override
  Future<String?> remember(String path) async => null;
  @override
  Future<String> computerName() async => 'The desk Mac';
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final key = deriveDataKey(RecoveryKey.generate());
  final monday = DateTime(2026, 10, 5, 21, 40);
  final tuesday = DateTime(2026, 10, 6, 8, 15);
  late Directory root;
  late Directory drive;
  late AppDatabase macDb;
  late CloudFolder mac;
  late PhoneSync phone;

  File folderLedger() => File('${drive.path}/$ledgerFileName');

  Future<void> spend(String payee) async {
    final ledger = await macDb.loadLedger();
    int id(String name) =>
        ledger.accounts.values.singleWhere((a) => a.name == name).id;
    await macDb.postSimple(
      accountId: id('TDB Checking'),
      date: monday,
      today: monday,
      payee: payee,
      counterAccountId: id('Groceries'),
      amount: -1250000,
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('bb-phone-sync');
    drive = await Directory('${root.path}/My Drive/BetterBudget')
        .create(recursive: true);
    final file = File('${root.path}/mac/$ledgerFileName')
      ..createSync(recursive: true);
    macDb = AppDatabase(
      NativeDatabase(file, setup: (raw) => applyCipherKey(raw, key)),
    );
    macDb.thisComputer = 'aaaa';
    await seedDemoIfEmpty(macDb, monday);
    mac = CloudFolder(Backups(macDb, dataKey: key), access: const _MacAccess());
    await mac.keepIn(drive.path, monday);
    phone = PhoneSync(
      dir: await Directory('${root.path}/phone').create(),
      dataKey: key,
      device: 'bbbb',
      io: const DirectoryFolderIo(),
    );
    await phone.join(await folderLedger().readAsBytes());
  });

  tearDown(() async {
    await phone.close();
    mac.dispose();
    await macDb.close();
    await root.delete(recursive: true);
  });

  Future<List<String?>> payees() async => [
    for (final t in (await phone.db!.loadLedger()).txns) t.payee,
  ];

  test(
    'a phone with a ledger of its own is joined, and one without is not',
    () {
      expect(phone.joined, isTrue);
      expect(
        PhoneSync(
          dir: Directory('${root.path}/other'),
          dataKey: key,
          device: 'cccc',
        ).joined,
        isFalse,
      );
    },
  );

  test('a look brings in what a computer did, and writes the phone’s own '
      'change file, never the folder’s ledger', () async {
    await spend('Nomin');
    await spend('E-Mart');
    expect(await mac.check(monday), FolderStanding.ok);
    final macsLedger = await folderLedger().readAsBytes();
    expect(await payees(), isNot(contains('Nomin')));

    final snapshot = await phone.look(drive.path, tuesday);
    expect(await payees(), containsAll(['Nomin', 'E-Mart']));
    // The figures are the ledger's: a look that went through is as new as now.
    expect(snapshot.madeAt, tuesday);
    // The phone's own file is there, and the folder's ledger isn't touched.
    expect(
      File('${drive.path}/${changeFileName('bbbb')}').existsSync(),
      isTrue,
    );
    expect(await folderLedger().readAsBytes(), macsLedger);
    // And no copy of a ledger is kept for restoring from.
    final backups = Directory('${root.path}/phone/own/Backups');
    expect(
      backups.existsSync() ? backups.listSync() : const <FileSystemEntity>[],
      isEmpty,
    );

    // The Mac, looking, finds the phone's file and has nothing to take.
    expect(await mac.check(tuesday), FolderStanding.ok);
  });

  test('a look with nothing new changes nothing, and again later brings in '
      'the next', () async {
    await phone.look(drive.path, monday);
    final before = await payees();
    await phone.look(drive.path, monday);
    expect(await payees(), before);

    await spend('Nomin');
    await mac.check(tuesday);
    await phone.look(drive.path, tuesday);
    expect(await payees(), contains('Nomin'));
  });

  test('a folder that can’t be reached leaves the figures up, as old as the '
      'last look that went through', () async {
    await phone.look(drive.path, monday);
    await spend('Nomin');
    await mac.check(monday);
    // The folder goes away: no signal.
    await drive.rename('${root.path}/My Drive/gone');
    final snapshot = await phone.look(drive.path, tuesday);
    expect(snapshot.madeAt, monday);
    expect(await payees(), isNot(contains('Nomin')));
    await Directory('${root.path}/My Drive/gone').rename(drive.path);
    final again = await phone.look(drive.path, tuesday);
    expect(again.madeAt, tuesday);
    expect(await payees(), contains('Nomin'));
  });

  test('the phone is the same member on the next launch: its ledger, its '
      'id and what it applied are kept', () async {
    await spend('Nomin');
    await mac.check(monday);
    await phone.look(drive.path, monday);
    await phone.close();

    phone = PhoneSync(
      dir: Directory('${root.path}/phone'),
      dataKey: key,
      device: 'bbbb',
      io: const DirectoryFolderIo(),
    );
    expect(phone.joined, isTrue);
    await spend('E-Mart');
    await mac.check(tuesday);
    await phone.look(drive.path, tuesday);
    expect(await payees(), containsAll(['Nomin', 'E-Mart']));
    // Nothing was taken twice.
    expect((await payees()).where((p) => p == 'Nomin'), hasLength(1));
  });

  test('a folder whose ledger is still arriving is not a look that went '
      'through: the figures keep their age', () async {
    await phone.look(drive.path, monday);
    // A phone that hasn't been on the folder yet (a new launch) finds half a
    // file there.
    await phone.close();
    await folderLedger().writeAsBytes([1, 2, 3]);
    phone = PhoneSync(
      dir: Directory('${root.path}/phone'),
      dataKey: key,
      device: 'bbbb',
      io: const DirectoryFolderIo(),
    );
    final snapshot = await phone.look(drive.path, tuesday);
    expect(snapshot.madeAt, monday);
  });

  test('an entry made on the phone is taken into its own ledger, and a '
      'computer gets it through the phone’s change file', () async {
    await phone.look(drive.path, monday);
    final ledger = await phone.db!.loadLedger();
    int id(String name) =>
        ledger.accounts.values.singleWhere((a) => a.name == name).id;
    final entry = PhoneEntry(
      id: 'e1',
      categoryId: '${id('Groceries')}',
      accountId: '${id('TDB Checking')}',
      payee: 'Nomin',
      amountMinor: -1250000,
      date: tuesday,
      madeAt: tuesday,
    );
    final after = await phone.take(
      PhoneInbox(device: 'bbbb', entries: [entry]),
      tuesday,
    );
    // The ledger lists it as taken, which is how the store lets go of it.
    expect(after!.snapshot.taken['bbbb']!.entries, contains('e1'));
    expect(after.take, isNotNull);
    expect(await payees(), contains('Nomin'));
    // Taking the same inbox again adds nothing.
    await phone.take(PhoneInbox(device: 'bbbb', entries: [entry]), tuesday);
    expect((await payees()).where((p) => p == 'Nomin'), hasLength(1));

    await phone.look(drive.path, tuesday);
    expect(await mac.check(tuesday), FolderStanding.combine);
    await mac.bringIn(tuesday);
    final macPayees = [
      for (final t in (await macDb.loadLedger()).txns) t.payee,
    ];
    expect(macPayees.where((p) => p == 'Nomin'), hasLength(1));
  });

  test('a look says what it brought in, once, and a look with nothing new '
      'says nothing', () async {
    await phone.look(drive.path, monday);
    expect(phone.takeNews(), isEmpty);
    await spend('Nomin');
    await mac.check(monday);
    await phone.look(drive.path, tuesday);
    final news = phone.takeNews();
    expect(news.single.transactions, 1);
    expect(news.single.payee, 'Nomin');
    expect(phone.takeNews(), isEmpty);
    await phone.look(drive.path, tuesday);
    expect(phone.takeNews(), isEmpty);
  });

  test('taking an entry back out of the phone’s ledger goes to the computer '
      'as a change, and a second take of it doesn’t bring it back', () async {
    await phone.look(drive.path, monday);
    final ledger = await phone.db!.loadLedger();
    int id(String name) =>
        ledger.accounts.values.singleWhere((a) => a.name == name).id;
    final inbox = PhoneInbox(
      device: 'bbbb',
      entries: [
        PhoneEntry(
          id: 'e1',
          categoryId: '${id('Groceries')}',
          accountId: '${id('TDB Checking')}',
          payee: 'Nomin',
          amountMinor: -1250000,
          date: tuesday,
          madeAt: tuesday,
        ),
      ],
    );
    final took = await phone.take(inbox, tuesday);
    expect(await payees(), contains('Nomin'));
    final after = await phone.undoTake(took!.take!, tuesday);
    expect(await payees(), isNot(contains('Nomin')));
    // Still listed as taken: the next look of a computer doesn't redo it.
    expect(after.taken['bbbb']!.entries, contains('e1'));
    // The computer never sees the row, or sees it gone.
    await phone.look(drive.path, tuesday);
    await mac.check(tuesday);
    await mac.bringIn(tuesday);
    expect([
      for (final t in (await macDb.loadLedger()).txns) t.payee,
    ], isNot(contains('Nomin')));
  });

  test(
    'an entry made on the phone is listed as not on the computer yet, '
    'until a computer has applied it, and can be taken back by its row',
    () async {
      await phone.look(drive.path, monday);
      final ledger = await phone.db!.loadLedger();
      int id(String name) =>
          ledger.accounts.values.singleWhere((a) => a.name == name).id;
      final inbox = PhoneInbox(
        device: 'bbbb',
        entries: [
          PhoneEntry(
            id: 'e1',
            categoryId: '${id('Groceries')}',
            accountId: '${id('TDB Checking')}',
            payee: 'Nomin',
            amountMinor: -1250000,
            date: tuesday,
            madeAt: tuesday,
          ),
        ],
      );
      final took = await phone.take(inbox, tuesday);
      final mine = took!.snapshot.mine.single;
      expect(phoneRowOf(mine.id), isNotNull);
      expect(mine.payee, 'Nomin');
      expect(mine.amountMinor, -1250000);
      expect(mine.categoryId, '${id('Groceries')}');
      expect(mine.accountId, '${id('TDB Checking')}');

      // The Mac has not seen it: still listed after a look.
      await phone.look(drive.path, tuesday);
      expect((await phone.asItStands(tuesday)).mine, hasLength(1));
      // The Mac applies it and writes its file saying so; the phone's next look
      // reads that and lets go of it.
      await mac.check(tuesday);
      await mac.bringIn(tuesday);
      await mac.check(tuesday);
      await phone.look(drive.path, tuesday);
      expect((await phone.asItStands(tuesday)).mine, isEmpty);
    },
  );

  test('a row edited on the phone goes to the computer as a change, and '
      'Undo puts it back (#527)', () async {
    await spend('Nomin');
    await mac.check(monday);
    await phone.look(drive.path, monday);
    final ledger = await phone.db!.loadLedger();
    final row = ledger.registerAll().posted.firstWhere(
      (r) => r.payee == 'Nomin',
    );
    final done = await phone.editRow((
      txn: row.txnId,
      account: row.accountId,
      date: row.date,
      payee: 'Nomin Super',
      memo: 'Weekly',
      counter: null,
      amount: null,
      splits: null,
      remember: null,
    ), tuesday);
    expect(await payees(), contains('Nomin Super'));
    await phone.look(drive.path, tuesday);
    await mac.check(tuesday);
    await mac.bringIn(tuesday);
    expect([
      for (final t in (await macDb.loadLedger()).txns) t.payee,
    ], contains('Nomin Super'));
    // Undo is another change, which the computer takes too.
    await phone.restoreRow(done.before, tuesday);
    expect(await payees(), contains('Nomin'));
    await phone.look(drive.path, tuesday);
    await mac.check(tuesday);
    await mac.bringIn(tuesday);
    expect([
      for (final t in (await macDb.loadLedger()).txns) t.payee,
    ], isNot(contains('Nomin Super')));
  });

  test('Mark cleared and Delete on the phone reach the computer, and Undo '
      'takes them back (#527)', () async {
    await spend('Nomin');
    await mac.check(monday);
    await phone.look(drive.path, monday);
    final ledger = await phone.db!.loadLedger();
    final row = ledger.registerAll().posted.firstWhere(
      (r) => r.payee == 'Nomin',
    );
    final marked = await phone.actOnRow(
      PhoneMarkCleared(row.entryId, Cleared.cleared),
      tuesday,
    );
    Future<RegisterRow?> there(AppDatabase db) async => (await db.loadLedger())
        .registerAll()
        .posted
        .where((r) => r.txnId == row.txnId)
        .firstOrNull;
    expect((await there(phone.db!))!.cleared, Cleared.cleared);
    await phone.look(drive.path, tuesday);
    await mac.check(tuesday);
    await mac.bringIn(tuesday);
    expect((await there(macDb))!.cleared, Cleared.cleared);
    await marked.undo();
    expect((await there(phone.db!))!.cleared, Cleared.uncleared);

    final deleted = await phone.actOnRow(PhoneDeleteRow(row.txnId), tuesday);
    expect(await there(phone.db!), isNull);
    await phone.look(drive.path, tuesday);
    await mac.check(tuesday);
    await mac.bringIn(tuesday);
    expect(await there(macDb), isNull);
    await deleted.undo();
    expect(await there(phone.db!), isNotNull);
  });

  test(
    'Assigned set on the phone reaches the computer, fixes the day the '
    'budget began as the computer does, and Undo takes it back (#528)',
    () async {
      await spend('Nomin');
      await mac.check(monday);
      await phone.look(drive.path, monday);
      final ledger = await phone.db!.loadLedger();
      final food = ledger.accounts.values.firstWhere((a) => a.isCategory).id;
      Future<int> assignedIn(AppDatabase db) async {
        final d = await db.loadLedger();
        return d.budgetAmounts
            .where((b) => b.categoryId == food)
            .fold<int>(0, (sum, b) => sum + b.amount);
      }

      final assigned = await phone.actOnRow(
        PhoneAssign(food, 25000000),
        tuesday,
      );
      expect(await assignedIn(phone.db!), 25000000);
      // The first amount ever fixes the day the budget began, as it does there.
      expect((await phone.db!.loadLedger()).prefs[BudgetKeys.began], isNotNull);
      await phone.look(drive.path, tuesday);
      await mac.check(tuesday);
      await mac.bringIn(tuesday);
      expect(await assignedIn(macDb), 25000000);
      // Clear is the same act with nothing.
      final cleared = await phone.actOnRow(PhoneAssign(food, 0), tuesday);
      expect(await assignedIn(phone.db!), 0);
      await cleared.undo();
      expect(await assignedIn(phone.db!), 25000000);
      await assigned.undo();
      expect(await assignedIn(phone.db!), 0);
      expect((await phone.db!.loadLedger()).prefs[BudgetKeys.began], isNull);
      await assigned.redo();
      expect(await assignedIn(phone.db!), 25000000);
    },
  );

  test(
    'Move money on the phone moves Assigned between two categories and '
    'to Not assigned, reaches the computer, and Undo takes it back (#528)',
    () async {
      await spend('Nomin');
      await mac.check(monday);
      await phone.look(drive.path, monday);
      final cats = (await phone.db!.loadLedger()).accounts.values
          .where((a) => a.isCategory && !a.isIncome)
          .toList();
      final a = cats[0].id, b = cats[1].id;
      Future<int> assignedIn(AppDatabase db, int id) async =>
          (await db.loadLedger()).budgetAmounts
              .where((x) => x.categoryId == id)
              .fold<int>(0, (sum, x) => sum + x.amount);

      await phone.actOnRow(PhoneAssign(a, 25000000), tuesday);
      final moved = await phone.actOnRow(PhoneMove(a, b, 10000000), tuesday);
      expect(await assignedIn(phone.db!, a), 15000000);
      expect(await assignedIn(phone.db!, b), 10000000);
      await phone.look(drive.path, tuesday);
      await mac.check(tuesday);
      await mac.bringIn(tuesday);
      expect(await assignedIn(macDb, b), 10000000);
      await moved.undo();
      expect(await assignedIn(phone.db!, a), 25000000);
      expect(await assignedIn(phone.db!, b), 0);
      await moved.redo();
      // Back to Not assigned: only the one side changes.
      await phone.actOnRow(PhoneMove(b, null, 4000000), tuesday);
      expect(await assignedIn(phone.db!, b), 6000000);
    },
  );

  /// A rent bill due on the 6th each month, scheduled on the computer.
  Future<int> rentBill() async {
    final ledger = await macDb.loadLedger();
    final bank = ledger.accounts.values
        .singleWhere((a) => a.name == 'TDB Checking')
        .id;
    final rent = await macDb.createCategory('Rent');
    await macDb.setCategoryPlan(
      rent,
      CategoryPlan(
        categoryId: rent,
        kind: PlanKind.byDate,
        amount: 80000000,
        start: monday,
        due: DateTime(2026, 10, 6),
        everyMonths: 1,
        paidFrom: bank,
      ),
    );
    await macDb.ensurePlanBills(monday);
    return rent;
  }

  Future<List<RegisterRow>> billsOn(AppDatabase db, int rent) async => [
    for (final r in (await db.loadLedger()).registerAll().scheduled)
      if (r.planCategoryId == rent) r,
  ];

  test('Confirm on a scheduled bill makes it real and schedules the next, '
      'and Undo takes both back (#527)', () async {
    final rent = await rentBill();
    await mac.check(monday);
    await phone.look(drive.path, monday);
    final bill = (await billsOn(phone.db!, rent)).single;
    final done = await phone.confirmRow((
      edit: (
        txn: bill.txnId,
        account: bill.accountId,
        date: DateTime(2026, 10, 6),
        payee: null,
        memo: '',
        counter: null,
        amount: -79000000,
        splits: null,
        remember: null,
      ),
      paySchedule: null,
      planCategory: rent,
      keepOwed: false,
    ), tuesday);
    var ledger = await phone.db!.loadLedger();
    final posted = ledger.registerAll().posted.singleWhere(
      (r) => r.txnId == bill.txnId,
    );
    expect(posted.amount, -79000000);
    final next = await billsOn(phone.db!, rent);
    expect(next.single.date, DateTime(2026, 11, 6));
    // The computer takes both.
    await phone.look(drive.path, tuesday);
    await mac.check(tuesday);
    await mac.bringIn(tuesday);
    expect(
      (await macDb.loadLedger()).registerAll().posted.any(
        (r) => r.txnId == bill.txnId,
      ),
      isTrue,
    );
    await done.undo();
    ledger = await phone.db!.loadLedger();
    final back = await billsOn(phone.db!, rent);
    expect(back.single.txnId, bill.txnId);
    expect(back.single.amount, bill.amount);
    await done.redo();
    expect((await billsOn(phone.db!, rent)).single.date, DateTime(2026, 11, 6));
  });

  test('a bill can’t be confirmed for a date after today (#527)', () async {
    final rent = await rentBill();
    await mac.check(monday);
    await phone.look(drive.path, monday);
    final bill = (await billsOn(phone.db!, rent)).single;
    expect(
      () => phone.confirmRow((
        edit: (
          txn: bill.txnId,
          account: bill.accountId,
          date: DateTime(2026, 10, 9),
          payee: null,
          memo: '',
          counter: null,
          amount: null,
          splits: null,
          remember: null,
        ),
        paySchedule: null,
        planCategory: rent,
        keepOwed: false,
      ), tuesday),
      throwsA(isA<LockedException>()),
    );
  });

  test('No bill this time skips a bill, keeps the next, and Undo brings it '
      'back (#527)', () async {
    final rent = await rentBill();
    await mac.check(monday);
    await phone.look(drive.path, monday);
    final bill = (await billsOn(phone.db!, rent)).single;
    final done = await phone.actOnRow(
      PhoneNoBill(bill.txnId, rent, bill.date),
      tuesday,
    );
    final after = await billsOn(phone.db!, rent);
    expect(after.map((r) => r.txnId), isNot(contains(bill.txnId)));
    expect(after.single.date, DateTime(2026, 11, 6));
    await done.undo();
    expect((await billsOn(phone.db!, rent)).single.txnId, bill.txnId);
  });

  /// The rent bill, and a payment for it saved on the phone on the 6th.
  Future<({int rent, BillPayment p})> paidRent() async {
    final rent = await rentBill();
    await mac.check(monday);
    await phone.look(drive.path, monday);
    final ledger = await phone.db!.loadLedger();
    final bank = ledger.accounts.values
        .singleWhere((a) => a.name == 'TDB Checking')
        .id;
    await phone.db!.postSimple(
      accountId: bank,
      date: tuesday,
      today: tuesday,
      payee: 'Landlord',
      counterAccountId: rent,
      amount: -79000000,
    );
    final p = billPayments(await phone.db!.loadLedger(), tuesday).values.single;
    expect(p.fit, BillFit.paid);
    return (rent: rent, p: p);
  }

  test('a payment in a bill’s category is asked about, Yes pays the bill and '
      'schedules the next, and Undo takes it back (#527)', () async {
    final (:rent, :p) = await paidRent();
    final done = await phone.actOnRow(PhoneBillPaid(p.bill, p.row), tuesday);
    var bills = await billsOn(phone.db!, rent);
    expect(bills.map((r) => r.txnId), isNot(contains(p.bill.txnId)));
    expect(bills.single.date, DateTime(2026, 11, 6));
    // Taken as the bill paid, so it can be said not to be.
    expect(
      (await phone.db!.loadLedger()).prefs.keys.any(
        (k) => k.startsWith('bill.paid.'),
      ),
      isTrue,
    );
    await phone.look(drive.path, tuesday);
    await mac.check(tuesday);
    await mac.bringIn(tuesday);
    expect(
      (await billsOn(macDb, rent)).map((r) => r.txnId),
      isNot(contains(p.bill.txnId)),
    );
    await done.undo();
    bills = await billsOn(phone.db!, rent);
    expect(bills.single.txnId, p.bill.txnId);
    await done.redo();
    expect((await billsOn(phone.db!, rent)).single.date, DateTime(2026, 11, 6));
  });

  test(
    'Not this bill puts the bill back, and Undo ties it again (#527)',
    () async {
      final (:rent, :p) = await paidRent();
      await phone.actOnRow(PhoneBillPaid(p.bill, p.row), tuesday);
      final ledger = await phone.db!.loadLedger();
      final row = ledger.registerAll().posted.singleWhere(
        (r) => r.txnId == p.row.txnId,
      );
      final done = await phone.actOnRow(PhoneNotTheBill(row), tuesday);
      var bills = await billsOn(phone.db!, rent);
      expect(bills.map((r) => r.txnId), contains(p.bill.txnId));
      // It doesn't ask about that row again.
      expect(billPayments(await phone.db!.loadLedger(), tuesday), isEmpty);
      await done.undo();
      bills = await billsOn(phone.db!, rent);
      expect(bills.map((r) => r.txnId), isNot(contains(p.bill.txnId)));
    },
  );

  test('No on a bill’s question keeps the bill and stops asking, with Undo '
      '(#527)', () async {
    final (:rent, :p) = await paidRent();
    final done = await phone.actOnRow(
      PhoneNotIt(p.bill.txnId, p.row.txnId),
      tuesday,
    );
    expect(billPayments(await phone.db!.loadLedger(), tuesday), isEmpty);
    expect((await billsOn(phone.db!, rent)).single.txnId, p.bill.txnId);
    await done.undo();
    expect(billPayments(await phone.db!.loadLedger(), tuesday), isNotEmpty);
  });

  Future<List<String>> remembered() async => [
    for (final r in await phone.db!.allPayeeRules())
      '${r.shownAs}:${r.categoryId}',
  ];

  test('the box under a row remembers its category for the payee, in the '
      'same Undo as the edit (#403)', () async {
    await spend('Nomin');
    await mac.check(monday);
    await phone.look(drive.path, monday);
    final ledger = await phone.db!.loadLedger();
    final row = ledger.registerAll().posted.firstWhere(
      (r) => r.payee == 'Nomin',
    );
    final done = await phone.editRow((
      txn: row.txnId,
      account: row.accountId,
      date: row.date,
      payee: 'Nomin',
      memo: '',
      counter: null,
      amount: null,
      splits: null,
      remember: row.categoryId,
    ), tuesday);
    expect(await remembered(), ['Nomin:${row.categoryId}']);
    expect(done.remembered, isNotNull);
    // Undo takes the row's edit and the rule back together.
    await phone.restoreRow(done.before, tuesday, remembered: done.remembered);
    expect(await remembered(), isEmpty);
    // It reaches the computer as a change.
    await phone.editRow((
      txn: row.txnId,
      account: row.accountId,
      date: row.date,
      payee: 'Nomin',
      memo: '',
      counter: null,
      amount: null,
      splits: null,
      remember: row.categoryId,
    ), tuesday);
    await phone.look(drive.path, tuesday);
    await mac.check(tuesday);
    await mac.bringIn(tuesday);
    expect([
      for (final r in await macDb.allPayeeRules()) r.shownAs,
    ], contains('Nomin'));
  });

  test('an entry saved on the phone with the box ticked remembers its '
      'category, and taking it back forgets it (#403)', () async {
    await phone.look(drive.path, monday);
    final ledger = await phone.db!.loadLedger();
    int id(String name) =>
        ledger.accounts.values.singleWhere((a) => a.name == name).id;
    PhoneEntry entry(String id0, {required bool remember}) => PhoneEntry(
      id: id0,
      categoryId: '${id('Groceries')}',
      accountId: '${id('TDB Checking')}',
      payee: 'Nomin',
      amountMinor: -1250000,
      date: tuesday,
      madeAt: tuesday,
      remember: remember,
    );
    // Unticked: nothing is remembered.
    await phone.take(
      PhoneInbox(device: 'bbbb', entries: [entry('e0', remember: false)]),
      tuesday,
    );
    expect(await remembered(), isEmpty);
    final took = await phone.take(
      PhoneInbox(device: 'bbbb', entries: [entry('e1', remember: true)]),
      tuesday,
    );
    expect(await remembered(), ['Nomin:${id('Groceries')}']);
    await phone.undoTake(took!.take!, tuesday);
    expect(await remembered(), isEmpty);
  });

  test('a payday confirmed for less keeps the rest owed, and Undo takes it '
      'back (#527)', () async {
    final ledger = await macDb.loadLedger();
    final bank = ledger.accounts.values
        .singleWhere((a) => a.name == 'TDB Checking')
        .id;
    final income = ledger.accounts.values
        .firstWhere((a) => a.type == AccountType.income)
        .id;
    // Money in that is expected, not yet in: scheduled for the 9th.
    await macDb.postSimple(
      accountId: bank,
      date: DateTime(2026, 10, 9),
      today: monday,
      payee: 'Employer',
      counterAccountId: income,
      amount: 100000000,
    );
    await mac.check(monday);
    await phone.look(drive.path, monday);
    final planned = (await phone.db!.loadLedger())
        .registerAll()
        .scheduled
        .firstWhere((r) => r.payee == 'Employer');
    final done = await phone.confirmRow((
      edit: (
        txn: planned.txnId,
        account: planned.accountId,
        date: tuesday,
        payee: 'Employer',
        memo: '',
        counter: null,
        amount: 60000000,
        splits: null,
        remember: null,
      ),
      paySchedule: null,
      planCategory: null,
      keepOwed: true,
    ), tuesday);
    List<RegisterRow> owed(PhoneSnapshot a) => [
      for (final r in a.data!.registerAll().scheduled)
        if (r.payee == 'Employer') r,
    ];
    expect(owed(done.snapshot).single.amount, 40000000);
    await done.undo();
    final back = owed(await phone.asItStands(tuesday)).single;
    expect(back.amount, 100000000);
    expect(back.txnId, planned.txnId);
  });

  test('a row of the phone’s own is taken back from its id alone, as after '
      'the app was closed', () async {
    await phone.look(drive.path, monday);
    final ledger = await phone.db!.loadLedger();
    int id(String name) =>
        ledger.accounts.values.singleWhere((a) => a.name == name).id;
    final took = await phone.take(
      PhoneInbox(
        device: 'bbbb',
        entries: [
          PhoneEntry(
            id: 'e1',
            categoryId: '${id('Groceries')}',
            accountId: '${id('TDB Checking')}',
            payee: 'Nomin',
            amountMinor: -1250000,
            date: tuesday,
            madeAt: tuesday,
          ),
        ],
      ),
      tuesday,
    );
    final row = phoneRowOf(took!.snapshot.mine.single.id)!;
    final after = await phone.undoTake(PhoneTake([row], const []), tuesday);
    expect(after.mine, isEmpty);
    expect(await payees(), isNot(contains('Nomin')));
  });

  test('giving the ledger up leaves nothing, and nothing reopens it', () async {
    await phone.look(drive.path, monday);
    await phone.leave();
    expect(Directory('${root.path}/phone/own').existsSync(), isFalse);
    await expectLater(phone.look(drive.path, tuesday), throwsStateError);
    expect(Directory('${root.path}/phone/own').existsSync(), isFalse);
  });

  group('a thing changed on the phone and on a computer both', () {
    Future<void> assign(AppDatabase db, int amount) async {
      final ledger = await db.loadLedger();
      final groceries = ledger.accounts.values
          .singleWhere((a) => a.name == 'Groceries')
          .id;
      await db.setBudgetAmount(
        groceries,
        DateTime(2026, 10),
        DateTime(2026, 10, 31),
        amount,
      );
    }

    Future<int> assigned() async {
      final ledger = await phone.db!.loadLedger();
      final groceries = ledger.accounts.values
          .singleWhere((a) => a.name == 'Groceries')
          .id;
      return ledger.budgetAmounts
          .where((b) => b.categoryId == groceries)
          .fold<int>(0, (s, b) => s + b.amount);
    }

    Future<void> cross() async {
      await phone.look(drive.path, monday);
      await assign(macDb, 3000000);
      await assign(phone.db!, 2000000);
      await mac.check(tuesday);
    }

    test('is asked about, and nothing comes in until it is answered', () async {
      await cross();
      await phone.look(drive.path, tuesday);
      final asking = phone.asking!;
      expect(asking.apart, isFalse);
      expect(asking.asks, hasLength(1));
      // Each version says when it was changed.
      expect(asking.asks.single.mine.changedAtMs, isNotNull);
      expect(asking.asks.single.theirs.changedAtMs, isNotNull);
      expect(asking.from, 'The desk Mac');
      // The phone's amount stands as it was.
      expect(await assigned(), 2000000);
      // A look with nothing answered is asked again, and still holds.
      await phone.look(drive.path, tuesday);
      expect(phone.asking!.asks, hasLength(1));
      expect(await assigned(), 2000000);
    });

    test('the phone’s own is kept, and the Mac’s is saved', () async {
      await cross();
      await phone.look(drive.path, tuesday);
      final ask = phone.asking!.asks.single;
      expect((await phone.answer({ask.id: Pick.mine}, tuesday)).done, isTrue);
      expect(phone.asking, isNull);
      expect(await assigned(), 2000000);
      await phone.look(drive.path, tuesday);
      expect(phone.asking, isNull);
    });

    test('the computer’s is chosen', () async {
      await cross();
      await phone.look(drive.path, tuesday);
      final ask = phone.asking!.asks.single;
      expect((await phone.answer({ask.id: Pick.theirs}, tuesday)).done, isTrue);
      expect(phone.asking, isNull);
      expect(await assigned(), 3000000);
      await phone.look(drive.path, tuesday);
      expect(phone.asking, isNull);
      expect(await assigned(), 3000000);
    });
    test('an answer to what has changed since the look is not made, and the '
        'what the phone changed since stands', () async {
      await cross();
      await phone.look(drive.path, tuesday);
      final ask = phone.asking!.asks.single;
      // Something is changed on the phone before the answer is made.
      await assign(phone.db!, 2500000);
      final answered = await phone.answer({ask.id: Pick.theirs}, tuesday);
      expect(answered.done, isFalse);
      expect(await assigned(), 2500000);
      await phone.look(drive.path, tuesday);
      // What the phone changed since stands, and the choices not made are
      // not made later without asking.
      expect(await assigned(), 2500000);
    });
  });
}
