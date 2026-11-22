import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/payee_acts.dart';
import 'package:betterbudget/data/phone_sync.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/payee_offers.dart';
import 'package:betterbudget/domain/payee_rules.dart';
import 'package:betterbudget/domain/phone.dart';
import 'package:betterbudget/domain/sync.dart' show MadeHow;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// The payee acts the phone's Payees page makes (#532), through
// `actOnPayee`, the code the phone's ledger runs: Save, Delete, the offer to
// file what is still in Not categorized, and the offer to show a name.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final today = DateTime(2026, 10, 12);
  Future<PhoneSnapshot> again() async =>
      snapshotOf(await db.loadLedger(), today: today, madeAt: today);
  Future<PhoneActed> act(PhoneRowAct a) => actOnPayee(db, a, today, again);

  late int bank, groceries, holding;
  setUp(() async {
    bank = await db.createAccount(name: 'Tight', type: AccountType.asset);
    groceries = await db.createCategory('Groceries');
    holding = await db.createCategory('Not categorized');
  });

  Future<int> row(String payee, {int to = 0, String? bankPayee}) =>
      db.postTransaction(
        date: DateTime(2026, 10, 5),
        payee: payee,
        how: MadeHow.imported,
        bankPayee: bankPayee,
        lines: [
          (accountId: bank, amount: -1000000, cleared: Cleared.uncleared),
          (
            accountId: to == 0 ? holding : to,
            amount: 1000000,
            cleared: Cleared.uncleared,
          ),
        ],
      );

  PayeeRuleInfo nomin() => PayeeRuleInfo(
    id: 0,
    spellings: const [PayeeSpelling(PayeeMatch.contains, 'NOMIN')],
    shownAs: 'Nomin Supermarket',
    categoryId: groceries,
    accountIds: {bank},
  );

  test('Save makes a payee; Undo removes it and Redo brings it back', () async {
    final a = PhoneSavePayee(null, nomin());
    final done = await act(a);
    final saved = a.saved!;
    expect((await db.loadLedger()).payeeRules.map((r) => r.id), [saved.id]);
    await done.undo();
    expect(
      (await db.loadLedger()).payeeRules.where((r) => !r.deleted),
      isEmpty,
    );
    await done.redo();
    final rule = (await db.loadLedger()).payeeRules.single;
    expect(rule.title, 'Nomin Supermarket');
    expect(rule.categoryId, groceries);
  });

  test(
    'Save of a changed payee keeps its id; Undo puts the words back',
    () async {
      final first = PhoneSavePayee(null, nomin());
      await act(first);
      final before = first.saved!;
      final changed = PhoneSavePayee(
        before,
        before.copyWith(
          spellings: const [PayeeSpelling(PayeeMatch.starts, 'NOMIN HYPER')],
        ),
      );
      final done = await act(changed);
      var rule = (await db.loadLedger()).payeeRules.single;
      expect(rule.id, before.id);
      expect(rule.spellings.single.how, PayeeMatch.starts);
      await done.undo();
      rule = (await db.loadLedger()).payeeRules.single;
      expect(rule.spellings.single.how, PayeeMatch.contains);
    },
  );

  test('another payee that goes by the same words is a clash, said before '
      'Save and refused by it', () async {
    await act(PhoneSavePayee(null, nomin()));
    final data = await db.loadLedger();
    final other = nomin().copyWith(shownAs: 'Nomin again');
    expect(payeeOverlaps(data, null, other).clash, isNotNull);
    await expectLater(
      act(PhoneSavePayee(null, other)),
      throwsA(isA<StateError>()),
    );
    expect((await db.loadLedger()).payeeRules, hasLength(1));
  });

  test('Delete keeps the rule as deleted, so an import does not bring it '
      'back; Undo restores it', () async {
    final s = PhoneSavePayee(null, nomin());
    await act(s);
    final done = await act(PhoneDeletePayee(s.saved!));
    expect((await db.loadLedger()).payeeRules, isEmpty);
    expect((await db.allPayeeRules(deletedToo: true)).single.deleted, isTrue);
    await done.undo();
    expect((await db.loadLedger()).payeeRules.single.deleted, isFalse);
  });

  test('the offer files this period\'s Not categorized rows only, as one '
      'change; Undo puts them back in Not categorized', () async {
    final a = await row('NOMIN UB 0412');
    final b = await row('NOMIN HYPER');
    final elsewhere = await row('UNITEL');
    final s = PhoneSavePayee(null, nomin());
    await act(s);
    var data = await db.loadLedger();
    expect(payeeWaitingFor(data, s.saved!, today), hasLength(2));
    final file = PhoneFilePayees([s.saved!.id]);
    final done = await act(file);
    expect(file.filed, 2);
    Future<int?> categoryOf(int id) async => (await db.loadLedger())
        .registerAll()
        .posted
        .firstWhere((r) => r.txnId == id)
        .categoryId;
    expect(await categoryOf(a), groceries);
    expect(await categoryOf(b), groceries);
    expect(await categoryOf(elsewhere), holding);
    await done.undo();
    expect(await categoryOf(a), holding);
    expect(await categoryOf(b), holding);
    await done.redo();
    expect(await categoryOf(a), groceries);
  });

  test(
    'the offer to show a name changes only rows brought in from a bank '
    'file, keeps the bank\'s words in the memo, and Undo takes it back',
    () async {
      final imported = await row('NOMIN UB 0412');
      final typed = await db.postTransaction(
        date: DateTime(2026, 10, 6),
        payee: 'NOMIN by hand',
        lines: [
          (accountId: bank, amount: -500000, cleared: Cleared.uncleared),
          (accountId: groceries, amount: 500000, cleared: Cleared.uncleared),
        ],
      );
      final s = PhoneSavePayee(null, nomin());
      await act(s);
      var data = await db.loadLedger();
      expect(payeeUnnamedFor(data, s.saved!).map((r) => r.txnId), [imported]);
      final show = PhoneShowPayeeNames([s.saved!.id]);
      final done = await act(show);
      expect(show.shown, 1);
      data = await db.loadLedger();
      RegisterRow r(int id) =>
          data.registerAll().posted.firstWhere((x) => x.txnId == id);
      expect(r(imported).txnPayee, 'Nomin Supermarket');
      expect(r(imported).bankPayee, 'NOMIN UB 0412');
      expect(r(typed).txnPayee, 'NOMIN by hand');
      await done.undo();
      data = await db.loadLedger();
      expect(r(imported).txnPayee, 'NOMIN UB 0412');
    },
  );

  test('Save and Undo take the payee as it stands, not as the card opened '
      'on it: a change from another computer meanwhile is what Undo puts '
      'back', () async {
    final first = PhoneSavePayee(null, nomin());
    await act(first);
    final opened = first.saved!;
    // Another computer adds a way of writing it while the card is open.
    final theirs = opened.copyWith(
      spellings: const [
        PayeeSpelling(PayeeMatch.contains, 'NOMIN'),
        PayeeSpelling(PayeeMatch.contains, 'NOMIN HYPER'),
      ],
    );
    await db.putPayeeRule(theirs);
    final done = await act(
      PhoneSavePayee(opened, opened.copyWith(shownAs: 'Nomin')),
    );
    await done.undo();
    final rule = (await db.loadLedger()).payeeRules.single;
    expect(rule.spellings, hasLength(2));
    expect(rule.shownAs, 'Nomin Supermarket');
  });

  test('Delete writes the payee as it stands, and a payee deleted '
      'elsewhere meanwhile is said, not brought back', () async {
    final first = PhoneSavePayee(null, nomin());
    await act(first);
    final opened = first.saved!;
    await db.putPayeeRule(opened.copyWith(shownAs: 'Nomin (theirs)'));
    final done = await act(PhoneDeletePayee(opened));
    await done.undo();
    expect((await db.loadLedger()).payeeRules.single.shownAs, 'Nomin (theirs)');
    await act(PhoneDeletePayee(opened));
    await expectLater(
      act(PhoneDeletePayee(opened)),
      throwsA(isA<NotFoundException>()),
    );
  });

  test('a payee that is money moved to another account files its waiting '
      'rows as transfers; Undo puts them back in Not categorized', () async {
    final savings = await db.createAccount(
      name: 'Khan Savings',
      type: AccountType.asset,
    );
    final moved = await row('KHAN SAVINGS TOPUP');
    final s = PhoneSavePayee(
      null,
      PayeeRuleInfo(
        id: 0,
        spellings: const [PayeeSpelling(PayeeMatch.contains, 'KHAN SAVINGS')],
        shownAs: 'Khan Savings',
        categoryId: savings,
        accountIds: {bank},
      ),
    );
    await act(s);
    final file = PhoneFilePayees([s.saved!.id]);
    final done = await act(file);
    expect(file.filed, 1);
    Future<RegisterRow> rowOf() async => (await db.loadLedger())
        .registerAll()
        .posted
        .firstWhere((r) => r.txnId == moved && r.accountId == bank);
    expect((await rowOf()).kind, RowKind.transfer);
    await done.undo();
    expect((await rowOf()).kind, RowKind.simple);
    expect((await rowOf()).categoryId, holding);
  });
}
