import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/phone_sync.dart';
import 'package:betterbudget/domain/forecast.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/money.dart';
import 'package:betterbudget/domain/phone.dart';
import 'package:betterbudget/domain/readiness.dart' show ReadyKeys;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// The account acts the phone's Accounts page and Ledger header make (#529),
// through `actOnAccount` and `actOnSpan`, the code the phone's ledger runs.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final today = DateTime(2026, 10, 12);
  Future<PhoneSnapshot> again() async =>
      snapshotOf(await db.loadLedger(), today: today, madeAt: today);
  Future<PhoneActed> act(PhoneRowAct a) => actOnAccount(db, a, today, again);
  Future<LedgerData> ledger() => db.loadLedger();

  PhoneAddAccount add({
    String name = 'Khan Card',
    AccountType type = AccountType.liability,
    int? balance = 40000000,
    String? rate = '24 year',
  }) => PhoneAddAccount(
    name: name,
    type: type,
    currency: Currency.mnt,
    rate: rate,
    balance: balance,
    date: DateTime(2026, 10, 1),
  );

  test('Add account makes the account, its rate and its opening balance '
      'together; Undo takes all away and Redo brings all back', () async {
    final a = add();
    final done = await act(a);
    final id = a.made!;
    var data = await ledger();
    expect(data.accounts[id]!.name, 'Khan Card');
    // A card's balance is typed as what is owed, and kept as a debt.
    expect(data.summaryFor(id).working, -40000000);
    expect(data.prefs[ReadyKeys.rate(id)], '24 year');
    await done.undo();
    data = await ledger();
    expect(data.accounts[id]?.deleted ?? true, isTrue);
    await done.redo();
    data = await ledger();
    expect(data.accounts[id]!.deleted, isFalse);
    expect(data.summaryFor(id).working, -40000000);
    expect(data.prefs[ReadyKeys.rate(id)], '24 year');
  });

  test('Undo of Add account, once a row was entered in it, leaves the account '
      'and its opening balance as they are and says so', () async {
    final a = add(type: AccountType.asset, rate: null, balance: 50000000);
    final done = await act(a);
    final id = a.made!;
    final food = await db.createCategory('Food');
    await db.postTransaction(
      date: today,
      lines: [
        (accountId: id, amount: -1000000, cleared: Cleared.uncleared),
        (accountId: food, amount: 1000000, cleared: Cleared.uncleared),
      ],
    );
    await expectLater(done.undo(), throwsA(isA<LockedException>()));
    final data = await ledger();
    expect(data.accounts[id]!.deleted, isFalse);
    // The opening balance is still counted: nothing was half undone.
    expect(data.summaryFor(id).working, 49000000);
  });

  test('Edit… saves the name, the type (its opening balance turning round), '
      'the rate and what payments come out of as one change, which Undo and '
      'Redo take back and bring back whole', () async {
    final a = add(type: AccountType.asset, rate: null);
    await act(a);
    final id = a.made!;
    final loan = await db.createCategory('Loan');
    final before = await ledger();
    // What Edit says before Save: the opening balance becomes owed.
    expect(openingThatFlips(before, id), 40000000);
    final edit = PhoneEditAccount(id, (
      name: 'Khan Visa',
      owed: true,
      rate: '2 month',
      loan: loan,
    ));
    final done = await act(edit);
    expect(edit.flipped, isTrue);
    var data = await ledger();
    expect(data.accounts[id]!.name, 'Khan Visa');
    expect(data.accounts[id]!.isOwed, isTrue);
    expect(data.prefs[ReadyKeys.rate(id)], '2 month');
    expect(data.prefs['budget.loan.$id'], '$loan');
    await done.undo();
    data = await ledger();
    expect(data.accounts[id]!.name, 'Khan Card');
    expect(data.accounts[id]!.isOwed, isFalse);
    expect(data.summaryFor(id).working, 40000000);
    expect(data.prefs[ReadyKeys.rate(id)], isNull);
    expect(data.prefs['budget.loan.$id'], isNull);
    await done.redo();
    data = await ledger();
    expect(data.accounts[id]!.name, 'Khan Visa');
    expect(data.accounts[id]!.isOwed, isTrue);
    expect(data.prefs['budget.loan.$id'], '$loan');
  });

  test('Archive and Delete each undo and redo; an Edit of an account deleted '
      'since is refused, not crashed on', () async {
    final a = add(rate: null);
    await act(a);
    final id = a.made!;
    final archived = await act(PhoneArchiveAccount(id, true));
    expect((await ledger()).accounts[id]!.archived, isTrue);
    await archived.undo();
    expect((await ledger()).accounts[id]!.archived, isFalse);

    final deleted = await act(PhoneDeleteAccount(id));
    expect((await ledger()).accounts[id]?.deleted ?? true, isTrue);
    await deleted.undo();
    expect((await ledger()).accounts[id]!.deleted, isFalse);
    await deleted.redo();
    expect((await ledger()).accounts[id]?.deleted ?? true, isTrue);

    // Deleted since this page was drawn, say on another computer.
    await expectLater(
      act(
        PhoneEditAccount(id, (
          name: 'Again',
          owed: true,
          rate: null,
          loan: null,
        )),
      ),
      throwsA(isA<NotFoundException>()),
    );
  });

  test('a forecast range picked is kept in the ledger, with Custom…\'s day, '
      'and Undo puts the earlier choice back', () async {
    Future<PhoneActed> pick(PhoneSetSpan s) => actOnSpan(db, s, again);
    final first = await pick(PhoneSetSpan(ForecastSpan.days90));
    var prefs = (await ledger()).prefs;
    expect(prefs[ForecastSpan.prefKey], 'days90');
    final custom = await pick(
      PhoneSetSpan(ForecastSpan.custom, customEnd: DateTime(2026, 12, 31)),
    );
    prefs = (await ledger()).prefs;
    expect(prefs[ForecastSpan.prefKey], 'custom');
    expect(prefs[ForecastSpan.customEndKey], startsWith('2026-12-31'));
    await custom.undo();
    prefs = (await ledger()).prefs;
    expect(prefs[ForecastSpan.prefKey], 'days90');
    expect(prefs[ForecastSpan.customEndKey], isNull);
    await first.undo();
    expect((await ledger()).prefs[ForecastSpan.prefKey], isNull);
  });
}
