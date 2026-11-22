// The phone screens (ADR 0005; ADR 0004 "Phone screens"): Ledger, where a
// transaction is typed and its category picked or made, and Budget, what is
// left in each category. Drawn on a 390 × 844 phone.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/data/incoming_file.dart';
import 'package:betterbudget/data/keys.dart';
import 'package:betterbudget/data/ledger_file.dart';
import 'package:betterbudget/data/phone_inbox.dart';
import 'package:betterbudget/data/phone_ledger.dart';
import 'package:betterbudget/data/phone_sync.dart';
import 'package:betterbudget/data/problem_log.dart';
import 'package:betterbudget/domain/budget.dart';
import 'package:betterbudget/domain/setup.dart'
    show SetupKeys, WalkKeys, WalkStep;
import 'package:betterbudget/domain/budget_amounts.dart';
import 'package:betterbudget/domain/combine.dart'
    show Ask, AskKind, AskLine, AskSide, Pick;
import 'package:betterbudget/domain/ledger.dart'
    show
        AccountInfo,
        AccountRole,
        LedgerGroups,
        AccountType,
        dateKey,
        BudgetAmount,
        Cleared,
        CategoryPlan,
        LedgerData,
        dateOnly,
        PlanKind,
        RegisterRow,
        RowKind;
import 'package:betterbudget/domain/money.dart';
import 'package:betterbudget/domain/pay.dart'
    show PayRule, budgetPeriod, noRegularPayKey;
import 'package:betterbudget/domain/payee_rules.dart'
    show PayeeMatch, PayeeSpelling, Remembered;
import 'package:betterbudget/domain/phone.dart';
import 'package:betterbudget/domain/readiness.dart' show ReadyKeys, isGoal;
import 'package:betterbudget/domain/sync.dart' show MadeHow;
import 'package:betterbudget/import/mapping.dart' show ImportRow;
import 'package:betterbudget/l10n/app_localizations.dart';
import 'package:betterbudget/phone_preview.dart';
import 'package:betterbudget/ui/ledger_screen.dart' show phonePlanNotes;
import 'package:betterbudget/ui/phone/phone_app.dart';
import 'package:betterbudget/ui/phone/phone_asking.dart' show PhoneAnswer;
import 'package:betterbudget/ui/phone/phone_start.dart';
import 'package:betterbudget/ui/category_types.dart' show TypeCards;
import 'package:betterbudget/ui/schemes.dart';
import 'package:betterbudget/ui/theme.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:url_launcher_platform_interface/link.dart' show LinkDelegate;
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'xls_fixture.dart' show lockedXlsx;

Future<void> _loadFont(String family, String path) async {
  final bytes = await File(path).readAsBytes();
  await (FontLoader(
    family,
  )..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
}

final _now = DateTime(2026, 10, 7, 14, 5);

Future<PhoneStore> _pump(
  WidgetTester tester, {
  PhoneSnapshot? snapshot,
  Size size = const Size(390, 844),
  ProblemLog? problems,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = PhoneStore(
    snapshot ?? previewSnapshot(DateTime(2026, 10, 7, 8, 10)),
  );
  await tester.pumpWidget(
    PhoneApp(store: store, now: () => _now, problems: problems),
  );
  await tester.pumpAndSettle();
  return store;
}

/// The demo ledger with a Safety net holding ₮800,000 put in this month, of
/// a month of expenses typed on the computer's Savings: ₮2,000,000. And the
/// Safety net's id.
Future<(LedgerData, int)> _stepLedger(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      final net = await db.safetyNetCategory(
        name: 'Safety net',
        currency: Currency.mnt,
      );
      await db.setBudgetAmount(
        net,
        DateTime(2026, 10),
        DateTime(2026, 10, 31),
        80000000,
      );
      await db.setPreference(ReadyKeys.month, '200000000');
      final data = await db.loadLedger();
      await db.close();
      return (data, net);
    }))!;

/// Types a payee on the amount screen: [pick] taps one the history offers,
/// otherwise what was typed is kept.
Future<void> _payee(WidgetTester tester, String typed, {String? pick}) async {
  await tester.tap(find.byKey(const ValueKey('payee-row')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('payee-field')), typed);
  await tester.pump();
  await tester.tap(pick == null ? find.text('Save').last : find.text(pick));
  await tester.pumpAndSettle();
}

Future<void> _toBudget(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('to-budget')));
  await tester.pumpAndSettle();
}

/// A category on Budget opens where it is; Add a transaction starts an
/// entry in it (#528).
Future<void> _addIn(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add a transaction'));
  await tester.pumpAndSettle();
}

Future<void> _toLedger(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('to-ledger')));
  await tester.pumpAndSettle();
}

/// [name] in the open Category dropdown.
Finder _inMenu(String name) =>
    find.descendant(of: find.byType(MenuItemButton), matching: find.text(name));

/// Picks [name] from the Category dropdown on the entry screen.
Future<void> _category(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('category-row')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(_inMenu(name));
  await tester.tap(_inMenu(name));
  await tester.pumpAndSettle();
}

/// Makes a category called [name] from the dropdown's "+ New category".
Future<void> _newCategory(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('category-row')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('new-category')));
  await tester.tap(find.byKey(const ValueKey('new-category')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('new-category-name')), name);
  await _paidFrom(tester);
  await tester.tap(find.text('Add'));
  await tester.pumpAndSettle();
}

/// Picks the [n]th account under New category's Paid from (#180): TDB
/// Checking first.
Future<void> _paidFrom(WidgetTester tester, [int n = 0]) async {
  // Under the four type cards: a scroll away.
  await _scrollTo(tester, const ValueKey('money-accounts'));
  await tester.tap(find.byKey(const ValueKey('money-accounts')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('money-account-$n')));
  await tester.pumpAndSettle();
}

/// Picks [type]'s card on New category, then brings its amount into view.
Future<void> _pickType(WidgetTester tester, CategoryType type) async {
  final card = find.byKey(ValueKey('plan-type-${type.name}'));
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.tap(card);
  await tester.pumpAndSettle();
  await _scrollTo(tester, const ValueKey('plan-amount'));
}

/// Scrolls New category until the row keyed [key] can be tapped.
Future<void> _scrollTo(WidgetTester tester, Key key) async {
  // Typing the name first scrolls its cursor into view: let that finish.
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(key),
    100,
    scrollable: find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

/// Closes the open dropdown.
Future<void> _closeMenu(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
}

/// Picks [name] under Paid from on the entry screen.
Future<void> _account(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('account-row')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

/// A whole entry: category, amount, payee, Paid from, Save.
Future<void> _spend(
  WidgetTester tester,
  String category,
  String amount,
  String payee, {
  String? pick,
  String from = 'TDB Checking',
}) async {
  await _category(tester, category);
  await _account(tester, from);
  await _type(tester, amount);
  await _payee(tester, payee, pick: pick);
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String keys) async {
  for (final k in keys.split('')) {
    await tester.tap(find.byKey(ValueKey('pad-$k')));
  }
  await tester.pump();
}

/// Stands in for the phone's key storage.
class _FakeKeys extends KeyStore {
  Uint8List? kept;

  @override
  Future<Uint8List?> readDataKey() async => kept;

  @override
  Future<void> writeDataKey(Uint8List key) async => kept = key;
}

/// Stands in for the system folder picker and the folder behind it.
class _FakeFolder extends PhoneFolder {
  String? picked;
  String? willPick = 'drive:BetterBudget';
  Uint8List? ledger = Uint8List.fromList([1, 2, 3]);
  DateTime? changedAt = DateTime(2026, 10, 7, 13, 30);
  final forgotten = <String>[];
  final asked = <String>[];

  /// The kept folder's bookmark no longer opens.
  bool keptFails = false;

  /// No signal: the folder's provider answers with an error, or never.
  bool readFails = false;
  bool readHangs = false;

  @override
  Future<String?> pick() async => picked = willPick ?? picked;

  @override
  Future<String?> kept() async {
    if (keptFails) {
      throw PlatformException(code: 'NSCocoaErrorDomain');
    }
    return picked;
  }

  @override
  Future<({Uint8List bytes, DateTime? changed})?> read(
    String folder,
    String name,
  ) async {
    asked.add(name);
    if (readHangs) return Completer<Never>().future;
    if (readFails) throw PlatformException(code: 'NSURLErrorDomain');
    final bytes = ledger;
    return bytes == null ? null : (bytes: bytes, changed: changedAt);
  }

  @override
  Future<void> forget(String folder) async => forgotten.add(folder);

  @override
  Future<DateTime?> changed(String folder, String name) async =>
      ledger == null ? null : changedAt;

  /// The files this phone has written to the folder, by name.
  final written = <String, Uint8List>{};

  @override
  Future<void> write(String folder, String name, Uint8List bytes) async =>
      written[name] = bytes;
}

/// A place for one test's phone to keep its files.
Directory _phoneDir() {
  final dir = Directory.systemTemp.createTempSync('bb-phone');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

/// Stands in for the phone's own ledger and its cycle with the folder
/// (`PhoneSync`, tested on real ledgers in `phone_sync_test.dart`): joined once
/// (kept between launches by a file in the phone's folder), then a look asks
/// the folder as the real one would and shows the figures as of the last
/// look that went through.
/// What `PhoneSync.actOnRow` does, on a ledger the test holds.
class _ActingSource {
  _ActingSource(this.db, this.now, this.onLedger);
  final AppDatabase db;
  final DateTime Function() now;
  final void Function(LedgerData) onLedger;

  Future<PhoneSnapshot> _after() async {
    final data = await db.loadLedger();
    onLedger(data);
    return snapshotOf(data, today: now(), madeAt: now());
  }

  Future<PhoneActed> act(PhoneRowAct act) async {
    switch (act) {
      case PhoneMarkCleared(:final entry, :final to):
        final before = await db.setClearedMany({entry: to});
        return (
          snapshot: await _after(),
          undo: () async {
            await db.setClearedMany(before);
            return _after();
          },
          redo: () async => _after(),
        );
      case PhoneAssign(:final category, :final amount):
        final data = await db.loadLedger();
        final c = data.accounts[category]!;
        final today = dateOnly(now());
        final period = budgetPeriod(today, data.periodSchedule);
        final rows = budgetRows(
          data,
          Budget.of(data, start: period.start, end: period.end, today: today),
          c,
          period,
          amount,
          today: today,
        );
        var before = await db.setBudgetAmount(
          category,
          period.start,
          period.end,
          amount,
          rows: rows,
        );
        return (
          snapshot: await _after(),
          undo: () async {
            await db.restoreBudgetAmounts(
              category,
              period.start,
              period.end,
              before,
            );
            return _after();
          },
          redo: () async {
            before = await db.setBudgetAmount(
              category,
              period.start,
              period.end,
              amount,
              rows: rows,
            );
            return _after();
          },
        );
      case PhoneMove(:final from, :final to, :final amount):
        final data = await db.loadLedger();
        final today = dateOnly(now());
        final period = budgetPeriod(today, data.periodSchedule);
        final byId = moveRows(
          data,
          Budget.of(data, start: period.start, end: period.end, today: today),
          period,
          from: from == null ? null : data.accounts[from],
          to: to == null ? null : data.accounts[to],
          amount: amount,
          today: today,
        );
        late Map<int, List<BudgetAmount>> before;
        before = await db.setBudgetAmounts(byId, period.start, period.end);
        return (
          snapshot: await _after(),
          undo: () async {
            await db.restoreBudgetAmountsOf(before, period.start, period.end);
            return _after();
          },
          redo: () async {
            before = await db.setBudgetAmounts(byId, period.start, period.end);
            return _after();
          },
        );
      case PhoneEditCategory(
        :final category,
        :final name,
        :final group,
        :final note,
      ):
        // The name, group and note: the plan and Paid from are PhoneSync's,
        // tested in phone_sync_test.dart.
        final was = (await db.loadLedger()).accounts[category]!;
        await db.renameAccount(category, name);
        await db.setCategoryDetails(category, group: group, note: note);
        return (
          snapshot: await _after(),
          undo: () async {
            await db.renameAccount(category, was.name);
            await db.setCategoryDetails(
              category,
              group: was.budgetGroup,
              note: was.note,
            );
            return _after();
          },
          redo: () async {
            await db.renameAccount(category, name);
            await db.setCategoryDetails(category, group: group, note: note);
            return _after();
          },
        );
      case PhoneArchiveCategory(:final category, :final archived):
        await db.setArchived(category, archived);
        return (
          snapshot: await _after(),
          undo: () async {
            await db.setArchived(category, !archived);
            return _after();
          },
          redo: () async {
            await db.setArchived(category, archived);
            return _after();
          },
        );
      case PhoneDeleteCategory(:final category, :final into):
        var done = await db.deleteCategory(category, into: into);
        return (
          snapshot: await _after(),
          undo: () async {
            await db.undeleteCategory(done);
            return _after();
          },
          redo: () async {
            done = await db.deleteCategory(category, into: into);
            return _after();
          },
        );
      case PhoneDeleteRow(:final txn):
        final ids = await db.softDeleteMany([txn]);
        return (
          snapshot: await _after(),
          undo: () async {
            await db.restoreMany(ids);
            return _after();
          },
          redo: () async => _after(),
        );
      case PhoneSavePay() || PhoneStopPay() || PhoneNoPay():
        return actOnPay(db, act, now(), _after);
      case PhoneSetSpan():
        return actOnSpan(db, act, _after);
      case PhoneSavingsAnswer():
        return actOnSavings(db, act, now(), _after);
      case PhoneAddAccount() ||
          PhoneEditAccount() ||
          PhoneArchiveAccount() ||
          PhoneDeleteAccount():
        return actOnAccount(db, act, now(), _after);
      case PhoneSavePayee() ||
          PhoneDeletePayee() ||
          PhoneFilePayees() ||
          PhoneShowPayeeNames():
        return actOnPayee(db, act, now(), _after);
      case PhoneReconcile() || PhoneUndoReconcile():
        return actOnReconcile(db, act, now(), _after);
      case PhoneImport():
        return actOnImport(db, act, now(), _after);
      case PhoneMoveRow() ||
          PhoneNoBill() ||
          PhoneBillPaid() ||
          PhoneNotIt() ||
          PhoneNotTheBill():
        throw UnimplementedError();
    }
  }
}

class _FakeSource implements PhoneLedgerSource {
  @override
  Future<int> categoryRows(int id) => throw UnsupportedError('no ledger');

  @override
  Future<ImportPlan> planImport(
    int account,
    List<ImportRow> rows,
    List<String> keys,
  ) => throw UnsupportedError('no ledger');

  /// This stand-in has no ledger to take entries into: they wait for the
  /// computer in the folder, as before the phone's own ledger.
  @override
  Future<PhoneTook?> take(PhoneInbox inbox, DateTime now) async => null;

  @override
  Future<PhoneSnapshot> undoTake(PhoneTake take, DateTime now) =>
      throw UnsupportedError('no ledger');

  @override
  Future<PhoneEdited> editRow(PhoneRowEdit edit, DateTime now) =>
      throw UnsupportedError('no ledger');

  @override
  Future<PhoneSnapshot> restoreRow(
    TxnSnapshot row,
    DateTime now, {
    Remembered? remembered,
  }) => throw UnsupportedError('no ledger');

  @override
  Future<PhoneActed> actOnRow(PhoneRowAct act, DateTime now) =>
      throw UnsupportedError('no ledger');

  @override
  Future<PhoneActed> confirmRow(PhoneRowConfirm confirm, DateTime now) =>
      throw UnsupportedError('no ledger');

  @override
  List<PhoneNews> takeNews() => const [];

  @override
  PhoneAsking? get asking => null;

  @override
  Future<PhoneAnswered> answer(Map<String, Pick> picks, DateTime now) =>
      throw UnsupportedError('asks nothing');

  @override
  Future<PhoneAnswered> takeFoldersLedger(DateTime now) =>
      throw UnsupportedError('asks nothing');

  _FakeSource({
    required this.dir,
    required this.key,
    required this.folder,
    this.opens,
    this.taken,
    this.fails,
    required this.joins,
    required this.looks,
  });

  final Directory dir;
  final Uint8List key;
  final _FakeFolder folder;
  final Uint8List? opens;
  final Map<String, PhoneTaken> Function()? taken;
  final bool Function()? fails;
  final List<Uint8List> joins;
  final List<DateTime> looks;

  File get _marker => File('${dir.path}/fake-joined');
  File get _looked => File('${dir.path}/fake-looked');

  @override
  bool get joined => _marker.existsSync();

  @override
  Future<void> join(Uint8List folderLedger) async {
    joins.add(key);
    if (opens != null && !_same(key, opens!)) throw WrongKeyException();
    _marker.writeAsStringSync('1');
  }

  PhoneSnapshot _snapshot(DateTime madeAt) {
    final snapshot = previewSnapshot(madeAt);
    final kept = taken?.call();
    return kept == null
        ? snapshot
        : PhoneSnapshot(
            madeAt: snapshot.madeAt,
            categories: snapshot.categories,
            accounts: snapshot.accounts,
            payees: snapshot.payees,
            taken: kept,
          );
  }

  @override
  Future<PhoneSnapshot> asItStands(DateTime now) async => _snapshot(
    _looked.existsSync()
        ? DateTime.fromMillisecondsSinceEpoch(
            int.parse(_looked.readAsStringSync()),
          )
        : now,
  );

  @override
  Future<PhoneSnapshot> look(String at, DateTime now) async {
    looks.add(now);
    // Half-arrived, or another ledger's: what the phone has can't be opened.
    if (fails?.call() ?? false) throw StateError('cannot open');
    try {
      final found = await folder.read(at, ledgerFileName);
      if (found != null) {
        _looked.writeAsStringSync(
          '${(found.changed ?? now).millisecondsSinceEpoch}',
        );
      }
    } on PlatformException {
      // No signal: the figures are as old as the last look that went through.
    }
    return asItStands(now);
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> leave() async {
    if (_marker.existsSync()) _marker.deleteSync();
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() async {
    usePhoneColors();
    await _loadFont('Onest', 'assets/fonts/Onest-Variable.ttf');
    await _loadFont('Manrope', 'assets/fonts/Manrope-Variable.ttf');
    await _loadFont(
      'BetterBudget Symbols',
      'assets/fonts/BetterBudgetSymbols.ttf',
    );
    final icons =
        '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    if (File(icons).existsSync()) await _loadFont('MaterialIcons', icons);
  });

  group('the amount pad', () {
    test('digits build a tugrik amount, with at most two after the point', () {
      var typed = '';
      for (final k in '12500.759'.split('')) {
        typed = pressAmountKey(typed, k, Currency.mnt);
      }
      expect(typed, '12500.75');
      expect(typedAmountMinor(typed, Currency.mnt), 1250075);
      expect(typedAmountShown(typed, Currency.mnt), '₮12,500.75');
    });

    test('delete takes the last key back, and a second point is ignored', () {
      expect(pressAmountKey('12.', '.', Currency.mnt), '12.');
      expect(pressAmountKey('12.5', '<', Currency.mnt), '12.');
      expect(pressAmountKey('', '<', Currency.mnt), '');
      expect(pressAmountKey('', '.', Currency.mnt), '0.');
      expect(pressAmountKey('0', '7', Currency.mnt), '7');
      expect(typedAmountMinor('12.5', Currency.mnt), 1250);
      expect(typedAmountMinor('', Currency.mnt), 0);
    });

    test('a currency with no cents takes no point', () {
      final yen = Currency.fromCode('JPY');
      expect(pressAmountKey('12', '.', yen), '12');
      expect(typedAmountMinor('1250', yen), 1250);
    });
  });

  test('what is left counts the entries the Mac has not taken in', () {
    const groceries = PhoneCategory(
      id: 'g',
      name: 'Groceries',
      leftMinor: 14800000,
    );
    final waiting = [
      PhoneEntry(
        id: 'a',
        categoryId: 'g',
        accountId: 'x',
        payee: 'Nomin',
        amountMinor: -1250000,
        date: _now,
        madeAt: _now,
      ),
      PhoneEntry(
        id: 'b',
        categoryId: 'other',
        accountId: 'x',
        payee: 'UB Cab',
        amountMinor: -800000,
        date: _now,
        madeAt: _now,
      ),
    ];
    expect(leftNow(groceries, waiting), 13550000);
  });

  test('the phone keeps dark Blue eclipse for now', () {
    usePhoneColors();
    expect(Mid.palette, same(Palette.of(blueEclipseScheme, Brightness.dark)));
  });

  testWidgets('opens on Ledger with nothing chosen', (tester) async {
    await _pump(tester);
    expect(find.text('−₮0'), findsOneWidget);
    // Payee is above Category (owner, 2026-10-08).
    expect(
      tester.getTopLeft(find.text('Payee')).dy,
      lessThan(tester.getTopLeft(find.text('Category')).dy),
    );
    // Paid from is theirs to choose, like Payee: nothing is filled in.
    expect(find.text('Paid from'), findsOneWidget);
    expect(find.text('TDB Checking'), findsNothing);
    // Date says Today; no category, so nothing is said about what is left.
    expect(find.text('Today'), findsOneWidget);
    expect(find.byKey(const ValueKey('left-line')), findsNothing);
    // Nothing is typed or waiting, so neither is offered.
    expect(find.text('Clear'), findsNothing);
    expect(find.byKey(const ValueKey('waiting-link')), findsNothing);
  });

  // Common phones, in points, with their status bar and the bar at the
  // foot (Android's three buttons, the iPhone's home line): Save and the
  // pad stay above Ledger and Budget on every one, with the text at its
  // ordinary size and turned up. Only the smallest scroll the rows above.
  const phones = <(String, Size, double, double, {bool scrolls})>[
    ('iPhone SE', Size(375, 667), 20, 0, scrolls: false),
    ('iPhone mini', Size(375, 812), 50, 34, scrolls: false),
    ('iPhone 15', Size(393, 852), 59, 34, scrolls: false),
    ('iPhone Pro Max', Size(440, 956), 62, 34, scrolls: false),
    // A Galaxy at its larger screen zoom: 1080 × 2340 at 3 to a point.
    ('Galaxy S zoomed', Size(360, 780), 43, 49, scrolls: false),
    ('Galaxy A', Size(360, 800), 24, 48, scrolls: false),
    ('Pixel', Size(412, 915), 24, 48, scrolls: false),
    ('small Android', Size(360, 720), 24, 48, scrolls: false),
    ('old Android', Size(360, 640), 24, 48, scrolls: true),
  ];
  for (final (name, size, top, bottom, :scrolls) in phones) {
    for (final text in [1.0, 1.3]) {
      testWidgets('Save and the pad fit on $name (${size.width.toInt()} × '
          '${size.height.toInt()}), text ×$text', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
        tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
        tester.platformDispatcher.textScaleFactorTestValue = text;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          PhoneApp(
            store: PhoneStore(previewSnapshot(DateTime(2026, 10, 7, 8, 10))),
            now: () => _now,
          ),
        );
        await tester.pumpAndSettle();
        final save = find.widgetWithText(FilledButton, 'Save');
        double barTop() =>
            tester.getTopLeft(find.byKey(const ValueKey('to-ledger'))).dy;
        expect(tester.getBottomLeft(save).dy, lessThanOrEqualTo(barTop()));
        expect(
          tester.getSize(find.byKey(const ValueKey('pad-1'))).height,
          greaterThanOrEqualTo(44),
        );
        final rows = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        if (!scrolls && text == 1.0) expect(rows.maxScrollExtent, 0);
        if (name == 'Galaxy S zoomed') {
          if (text == 1.0) {
            await expectLater(
              find.byType(PhoneApp),
              matchesGoldenFile('goldens/phone_short.png'),
            );
          }
          // Her phone, text turned up: nothing above the pad scrolls.
          expect(rows.maxScrollExtent, 0);
        }
        // What's missing is said above Save, which stays in sight.
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.text('Enter an amount'), findsOneWidget);
        expect(tester.getBottomLeft(save).dy, lessThanOrEqualTo(barTop()));
      });
    }
  }

  testWidgets('Budget lists what is left, with the cents where there is room', (
    tester,
  ) async {
    await _pump(tester);
    await _toBudget(tester);
    expect(find.text('Left in October'), findsOneWidget);
    expect(find.text('From your computer today 08:10'), findsOneWidget);
    expect(find.text('₮148,000.00'), findsOneWidget);
    expect(find.text('−₮18,400.00'), findsOneWidget);
    // No + on the rows (owner, 2026-10-08).
    expect(find.byIcon(Icons.add), findsNothing);
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_budget.png'),
    );
  });

  testWidgets('Ledger is the register: rows, an account, a search, and Add '
      'opens the pad (#527)', (tester) async {
    final (data, _) = await _stepLedger(tester);
    await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    // Rows of every account, and the chip says so.
    expect(find.byKey(const ValueKey('register-list')), findsOneWidget);
    expect(find.text('All accounts'), findsOneWidget);
    final rows = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('register-row-'),
    );
    expect(rows, findsWidgets);
    // A tapped row opens where it is, and closes on a second tap.
    await tester.tap(rows.first);
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('register-open-'),
      ),
      findsOneWidget,
    );
    // A search with nothing in it leaves no row.
    await tester.tap(find.byKey(const ValueKey('register-search-open')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('register-search')),
      'zzzzqq',
    );
    await tester.pumpAndSettle();
    expect(rows, findsNothing);
    await tester.tap(find.byKey(const ValueKey('register-search-close')));
    await tester.pumpAndSettle();
    expect(rows, findsWidgets);
    // Add opens the amount pad, and Back comes home to the register.
    await tester.tap(find.byKey(const ValueKey('add-transaction')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('category-row')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pad-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('register-list')), findsOneWidget);
  });

  testWidgets('a row opened in the register is saved into the ledger and '
      'taken back by Undo (#527)', (tester) async {
    late AppDatabase db;
    late LedgerData data;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      data = await db.loadLedger();
    });
    addTearDown(() => tester.runAsync(db.close));
    final store = await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    store.editRowIn = (edit) async => await (() async {
      final before = await db.snapshot(edit.txn);
      await db.editTransaction(
        transactionId: edit.txn,
        accountId: edit.account,
        date: edit.date,
        today: _now,
        payee: edit.payee,
        memo: edit.memo,
        counterAccountId: edit.counter,
        amount: edit.amount,
      );
      final after = await db.snapshot(edit.txn);
      data = await db.loadLedger();
      return (
        snapshot: snapshotOf(data, today: _now, madeAt: _now),
        before: before,
        after: after,
        remembered: null,
      );
    })();
    store.restoreRowIn = (row, _) async => await (() async {
      await db.restoreSnapshot(row);
      data = await db.loadLedger();
      return snapshotOf(data, today: _now, madeAt: _now);
    })();
    // The first row that is a plain one and not locked.
    final all = data.registerAll().posted.reversed.where(
      (r) => r.kind == RowKind.simple && !r.locked,
    );
    final row = all.first;
    final key = '${row.txnId}-${row.entryId}';
    await tester.tap(find.byKey(ValueKey('register-row-$key')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('row-memo')), 'Gift');
    await tester.ensureVisible(find.byKey(const ValueKey('row-save')));
    await tester.tap(find.byKey(const ValueKey('row-save')));
    await tester.pump();
    // The ledger is a real file's worth of work: let it finish.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('row-save')), findsNothing);
    expect(find.byKey(const ValueKey('row-saved')), findsOneWidget);
    RegisterRow now() => data.registerAll().posted.firstWhere(
      (r) => r.txnId == row.txnId && r.entryId == row.entryId,
    );
    expect(now().memo, 'Gift');
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(now().memo, row.memo);
  });

  testWidgets('a split row opened in the register has its lines on the split '
      'page, and a sum that is off is said before Save (#527)', (tester) async {
    late AppDatabase db;
    late LedgerData data;
    late int txn;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      data = await db.loadLedger();
      final account = data.accounts.values.firstWhere(
        (a) => a.type == AccountType.asset && a.currency == Currency.mnt,
      );
      final cats = data.accounts.values
          .where(
            (a) => a.type == AccountType.expense && a.currency == Currency.mnt,
          )
          .take(2)
          .toList();
      txn = await db.postSplit(
        accountId: account.id,
        date: DateTime(2026, 10, 5),
        today: _now,
        payee: 'Emart',
        splits: [
          (categoryId: cats[0].id, amount: -3000000),
          (categoryId: cats[1].id, amount: -2000000),
        ],
      );
      data = await db.loadLedger();
    });
    addTearDown(() => tester.runAsync(db.close));
    final store = await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    var saved = <SplitPart>[];
    store.editRowIn = (edit) async => await (() async {
      saved = edit.splits ?? [];
      final before = await db.snapshot(edit.txn);
      await db.editTransaction(
        transactionId: edit.txn,
        accountId: edit.account,
        date: edit.date,
        today: _now,
        payee: edit.payee,
        memo: edit.memo,
        splits: edit.splits,
      );
      final after = await db.snapshot(edit.txn);
      data = await db.loadLedger();
      return (
        snapshot: snapshotOf(data, today: _now, madeAt: _now),
        before: before,
        after: after,
        remembered: null,
      );
    })();
    final row = data.registerAll().posted.firstWhere((r) => r.txnId == txn);
    await tester.tap(find.byKey(ValueKey('register-row-$txn-${row.entryId}')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('row-lines')));
    expect(find.text('Split · 2 categories'), findsOneWidget);
    // Lines changed on the page so they no longer add up: said, not saved.
    await tester.tap(find.byKey(const ValueKey('row-lines')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pad-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('split-done')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('row-save')));
    await tester.tap(find.byKey(const ValueKey('row-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('row-said')), findsOneWidget);
    expect(saved, isEmpty);
    // Back to as it was on the page: the lines are saved, adding up.
    await tester.ensureVisible(find.byKey(const ValueKey('row-lines')));
    await tester.drag(
      find.byKey(const ValueKey('register-list')),
      const Offset(0, 150),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('row-lines')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pad-<')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('split-done')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('row-save')));
    await tester.tap(find.byKey(const ValueKey('row-save')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(saved.length, 2);
    expect(saved.fold(0, (s, p) => s + p.amount), -5000000);
    expect(find.byKey(const ValueKey('row-saved')), findsOneWidget);
  });

  testWidgets('a row’s ⋯ marks it cleared, moves it and deletes it, each with '
      'Undo (#527)', (tester) async {
    late AppDatabase db;
    late LedgerData data;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      data = await db.loadLedger();
    });
    addTearDown(() => tester.runAsync(db.close));
    final store = await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    final source = _ActingSource(db, () => _now, (d) => data = d);
    store.actRowIn = (act) => source.act(act);
    Future<void> settle() async {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }

    final row = data.registerAll().posted.reversed.firstWhere(
      (r) => r.kind == RowKind.simple && !r.locked && !r.scheduled,
    );
    RegisterRow? now() => data
        .registerAll()
        .posted
        .where((r) => r.txnId == row.txnId && r.entryId == row.entryId)
        .firstOrNull;
    final key = '${row.txnId}-${row.entryId}';
    Future<void> menu(String item) async {
      await tester.drag(
        find.byKey(const ValueKey('register-list')),
        const Offset(0, 2000),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('register-row-$key')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('row-more')));
      await tester.tap(find.byKey(const ValueKey('row-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(item));
      await settle();
    }

    await menu(
      row.cleared == Cleared.uncleared ? 'Mark cleared' : 'Mark uncleared',
    );
    expect(now()!.cleared, isNot(row.cleared));
    expect(find.byKey(const ValueKey('row-acted')), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await settle();
    expect(now()!.cleared, row.cleared);

    await menu('Delete');
    expect(now(), isNull);
    await tester.tap(find.text('Undo'));
    await settle();
    expect(now(), isNotNull);
  });

  testWidgets('a scheduled bill opened in the register has Confirm and No bill '
      'this time, and Confirm makes it real, with Undo (#527)', (tester) async {
    late AppDatabase db;
    late LedgerData data;
    late int rent;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      final bank = (await db.loadLedger()).accounts.values
          .firstWhere((a) => a.name == 'TDB Checking')
          .id;
      rent = await db.createCategory('Rent');
      await db.setCategoryPlan(
        rent,
        CategoryPlan(
          categoryId: rent,
          kind: PlanKind.byDate,
          amount: 80000000,
          start: _now,
          due: DateTime(2026, 10, 9),
          everyMonths: 1,
          paidFrom: bank,
        ),
      );
      await db.ensurePlanBills(_now);
      data = await db.loadLedger();
    });
    addTearDown(() => tester.runAsync(db.close));
    final store = await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    store.confirmRowIn = (c) async => await (() async {
      final before = await db.snapshot(c.edit.txn);
      await db.editTransaction(
        transactionId: c.edit.txn,
        accountId: c.edit.account,
        date: c.edit.date,
        today: _now,
        payee: c.edit.payee,
        memo: c.edit.memo,
        amount: c.edit.amount,
        confirm: true,
      );
      data = await db.loadLedger();
      return (
        snapshot: snapshotOf(data, today: _now, madeAt: _now),
        undo: () async {
          await db.restoreSnapshot(before);
          data = await db.loadLedger();
          return snapshotOf(data, today: _now, madeAt: _now);
        },
        redo: () async => snapshotOf(data, today: _now, madeAt: _now),
      );
    })();
    Future<void> settle() async {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }

    final bill = data.registerAll().scheduled.firstWhere(
      (r) => r.planCategoryId == rent,
    );
    await tester.tap(find.byKey(const ValueKey('register-tab-scheduled')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('register-row-${bill.txnId}-${bill.entryId}')),
    );
    await tester.pumpAndSettle();
    // Confirm in place of Save; the ⋯ has No bill this time, not Delete.
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.byKey(const ValueKey('row-save')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('row-more')));
    await tester.tap(find.byKey(const ValueKey('row-more')));
    await tester.pumpAndSettle();
    expect(find.text('No bill this time'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('row-save')));
    await tester.tap(find.byKey(const ValueKey('row-save')));
    await settle();
    expect(find.byKey(const ValueKey('row-confirmed')), findsOneWidget);
    expect(data.registerAll().posted.any((r) => r.txnId == bill.txnId), isTrue);
    await tester.tap(find.text('Undo'));
    await settle();
    expect(
      data.registerAll().scheduled.any((r) => r.txnId == bill.txnId),
      isTrue,
    );
  });

  testWidgets('a payment in a bill’s category is asked about under the bill '
      'and under the payment, and No stops asking (#527)', (tester) async {
    late AppDatabase db;
    late LedgerData data;
    late int rent;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      final bank = (await db.loadLedger()).accounts.values
          .firstWhere((a) => a.name == 'TDB Checking')
          .id;
      rent = await db.createCategory('Rent');
      await db.setCategoryPlan(
        rent,
        CategoryPlan(
          categoryId: rent,
          kind: PlanKind.byDate,
          amount: 80000000,
          start: _now,
          due: DateTime(2026, 10, 7),
          everyMonths: 1,
          paidFrom: bank,
        ),
      );
      await db.ensurePlanBills(_now);
      await db.postSimple(
        accountId: bank,
        date: _now,
        today: _now,
        payee: 'Landlord',
        counterAccountId: rent,
        amount: -79000000,
      );
      data = await db.loadLedger();
    });
    addTearDown(() => tester.runAsync(db.close));
    final store = await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    PhoneRowAct? asked;
    store.actRowIn = (act) async {
      asked = act;
      return (
        snapshot: snapshotOf(data, today: _now, madeAt: _now),
        undo: () async => snapshotOf(data, today: _now, madeAt: _now),
        redo: () async => snapshotOf(data, today: _now, madeAt: _now),
      );
    };
    // Under the row that may have paid it, on the All tab.
    expect(find.text('Did this pay the Rent bill?'), findsOneWidget);
    // Under the bill, on the Scheduled tab.
    await tester.tap(find.byKey(const ValueKey('register-tab-scheduled')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Paid on'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('paid-no')));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(asked, isA<PhoneNotIt>());
  });

  testWidgets('a payday confirmed for less offers Still owed or Paid in full, '
      'and the box under a row remembers its category (#527, #403)', (
    tester,
  ) async {
    late AppDatabase db;
    late LedgerData data;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      data = await db.loadLedger();
      final bank = data.accounts.values
          .firstWhere((a) => a.name == 'TDB Checking')
          .id;
      final income = data.accounts.values
          .firstWhere((a) => a.type == AccountType.income)
          .id;
      await db.postSimple(
        accountId: bank,
        date: DateTime(2026, 10, 9),
        today: _now,
        payee: 'Employer',
        counterAccountId: income,
        amount: 100000000,
      );
      data = await db.loadLedger();
    });
    addTearDown(() => tester.runAsync(db.close));
    final store = await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    PhoneRowConfirm? confirmed;
    store.confirmRowIn = (c) async {
      confirmed = c;
      return (
        snapshot: snapshotOf(data, today: _now, madeAt: _now),
        undo: () async => snapshotOf(data, today: _now, madeAt: _now),
        redo: () async => snapshotOf(data, today: _now, madeAt: _now),
      );
    };
    final pay = data.registerAll().scheduled.firstWhere(
      (r) => r.payee == 'Employer',
    );
    await tester.tap(find.byKey(const ValueKey('register-tab-scheduled')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('register-row-${pay.txnId}-${pay.entryId}')),
    );
    await tester.pumpAndSettle();
    // At the planned amount: nothing is owed.
    expect(find.byKey(const ValueKey('owed-line')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('row-amount')), '600,000');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('owed-line')), findsOneWidget);
    expect(find.textContaining('less than planned'), findsOneWidget);
    // More than a tenth is missing: the rest is still owed, as on the computer.
    await tester.ensureVisible(find.byKey(const ValueKey('owed-paid')));
    await tester.tap(find.byKey(const ValueKey('owed-paid')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('row-save')));
    await tester.tap(find.byKey(const ValueKey('row-save')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(confirmed, isNotNull);
    expect(confirmed!.keepOwed, isFalse);
  });

  testWidgets('a row whose category isn’t remembered for its payee has the '
      'box, off until ticked, and Save carries it (#403)', (tester) async {
    late AppDatabase db;
    late LedgerData data;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      data = await db.loadLedger();
      final bank = data.accounts.values
          .firstWhere((a) => a.name == 'TDB Checking')
          .id;
      final food = data.accounts.values
          .firstWhere((a) => a.name == 'Groceries')
          .id;
      await db.postSimple(
        accountId: bank,
        date: _now,
        today: _now,
        payee: 'Nomin Supermarket',
        counterAccountId: food,
        amount: -1250000,
      );
      data = await db.loadLedger();
    });
    addTearDown(() => tester.runAsync(db.close));
    final store = await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    PhoneRowEdit? saved;
    store.editRowIn = (edit) async {
      saved = edit;
      final before = await db.snapshot(edit.txn);
      return (
        snapshot: snapshotOf(data, today: _now, madeAt: _now),
        before: before,
        after: before,
        remembered: null,
      );
    };
    final row = data.registerAll().posted.firstWhere(
      (r) => r.payee == 'Nomin Supermarket',
    );
    await tester.tap(
      find.byKey(ValueKey('register-row-${row.txnId}-${row.entryId}')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('remember-line')));
    expect(find.byKey(const ValueKey('remember-line')), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outline_blank_rounded), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('remember-line')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('row-save')));
    await tester.tap(find.byKey(const ValueKey('row-save')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(saved?.remember, row.categoryId);
  });

  testWidgets('on the amount screen the box to remember the category shows '
      'once there is a payee, a category and an account, off until ticked, '
      'and Save carries it (#403)', (tester) async {
    final store = await _pump(tester);
    expect(find.byKey(const ValueKey('remember-line')), findsNothing);
    await _payee(tester, 'Nomin');
    await _category(tester, 'Groceries');
    await tester.tap(find.byKey(const ValueKey('account-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TDB Checking').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('remember-line')), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outline_blank_rounded), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('remember-line')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_box_rounded), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pad-5')));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.waiting.single.remember, isTrue);
    // The next entry starts with the box off.
    expect(find.byKey(const ValueKey('remember-line')), findsNothing);
  });

  testWidgets('the sum\'s Income line opens a page of the period\'s paydays by '
      'date, each came, still to come or didn\'t come (#528)', (tester) async {
    final data = (await tester.runAsync(() async {
      final db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      // New accounts, so the demo's own income rows tie to neither pay.
      final payroll = await db.addAccount(
        name: 'Payroll',
        type: AccountType.asset,
      );
      final bank = await db.addAccount(
        name: 'Support',
        type: AccountType.asset,
      );
      final job = await db.savePaySchedule(
        accountId: payroll,
        amount: 105000000,
        rule: PayRule.twiceMonthly,
        day1: 25,
        day2: 10,
        name: 'Jenny’s job',
        today: _now,
      );
      final support = await db.savePaySchedule(
        accountId: bank,
        amount: 40000000,
        rule: PayRule.monthly,
        day1: 5,
        name: 'Child support',
        today: _now,
      );
      final income = await db.incomeCategory();
      await db.postTransaction(
        date: DateTime(2026, 10, 5),
        payScheduleId: support.after.id,
        lines: [
          (accountId: bank, amount: 40000000, cleared: Cleared.cleared),
          (accountId: income, amount: -40000000, cleared: Cleared.cleared),
        ],
      );
      expect(job.after.id, isNot(support.after.id));
      final data = await db.loadLedger();
      await db.close();
      return data;
    }))!;
    await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    await _toBudget(tester);
    await tester.tap(find.byKey(const ValueKey('sum-income-open')));
    await tester.pumpAndSettle();
    expect(find.text('Income in October'), findsOneWidget);
    expect(find.byKey(const ValueKey('income-page')), findsOneWidget);
    // Child support came on the 5th; Jenny's job is paid on the 9th (the
    // 10th is a Saturday) and the 23rd, both still ahead on the 7th.
    final rows = [
      for (final k in [
        '10-5-Child support',
        '10-9-Jenny’s job',
        '10-23-Jenny’s job',
      ])
        find.byKey(ValueKey('payday-$k')),
    ];
    for (final r in rows) {
      expect(r, findsOneWidget);
    }
    expect(
      find.descendant(of: rows[0], matching: find.text('came')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rows[1], matching: find.text('still to come')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(rows[0]).dy,
      lessThan(tester.getTopLeft(rows[1]).dy),
    );
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_income.png'),
    );
    // Back to Budget.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('budget-sum')), findsOneWidget);
  });

  testWidgets('Add regular income on the Income page saves the pay form into '
      'the ledger, Edit changes it, Stop asks first, each with Undo (#528)', (
    tester,
  ) async {
    late AppDatabase db;
    late LedgerData data;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      data = await db.loadLedger();
    });
    addTearDown(() => tester.runAsync(db.close));
    final store = await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    final source = _ActingSource(db, () => _now, (d) => data = d);
    store.actRowIn = (act) => source.act(act);
    Future<void> settle() async {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }

    await _toBudget(tester);
    await tester.tap(find.byKey(const ValueKey('sum-income-open')));
    await tester.pumpAndSettle();
    // None yet: Add your regular income, and the way to say there is none.
    expect(find.byKey(const ValueKey('income-no-pay')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('income-no-pay')));
    await settle();
    expect(data.prefs[noRegularPayKey], '1');
    expect(find.text('Ask me again'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await settle();
    expect(data.prefs[noRegularPayKey], isNull);
    await tester.tap(find.byKey(const ValueKey('income-add-pay')));
    await tester.pumpAndSettle();
    // Save with nothing typed: said above Save, and the name takes the cursor.
    await tester.tap(find.byKey(const ValueKey('pay-save')));
    await tester.pumpAndSettle();
    expect(find.text('Type a name.'), findsOneWidget);
    expect(data.paySchedules, isEmpty);
    await tester.enterText(
      find.byKey(const ValueKey('pay-name')),
      'Jenny’s job',
    );
    await tester.enterText(find.byKey(const ValueKey('pay-amount')), '1050000');
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('pay-page')),
      const Offset(0, 800),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_pay.png'),
    );
    await tester.tap(find.byKey(const ValueKey('pay-save')));
    await settle();
    expect(data.paySchedules, hasLength(1));
    final pay = data.paySchedules.single;
    expect(
      (pay.name, pay.amount, pay.rule),
      ('Jenny’s job', 105000000, PayRule.monthly),
    );
    expect(find.byKey(const ValueKey('pay-done')), findsOneWidget);
    expect(find.byKey(ValueKey('regular-${pay.id}')), findsOneWidget);
    // Undo takes it back out.
    await tester.tap(find.text('Undo'));
    await settle();
    expect(data.paySchedules, isEmpty);
    await tester.tap(find.byKey(const ValueKey('income-add-pay')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('pay-name')),
      'Jenny’s job',
    );
    await tester.enterText(find.byKey(const ValueKey('pay-amount')), '1050000');
    await tester.tap(find.byKey(const ValueKey('pay-save')));
    await settle();
    final id = data.paySchedules.single.id;

    // Edit: the form opens filled in, and leaving it changed asks first.
    await tester.tap(find.byKey(ValueKey('edit-pay-$id')));
    await tester.pumpAndSettle();
    expect(find.text('1,050,000'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('pay-amount')), '1200000');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pay-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pay-leave-ask')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pay-keep-editing')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pay-page')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pay-save')));
    await settle();
    expect(data.paySchedules.single.amount, 120000000);

    // Stop: asked first, with this income's own figures, then goes ahead.
    await tester.tap(find.byKey(ValueKey('edit-pay-$id')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('pay-stop')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('pay-stop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stop-pay-ask')), findsOneWidget);
    expect(find.textContaining('Jenny’s job stops.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stop-pay-cancel')));
    await tester.pumpAndSettle();
    expect(data.paySchedules, hasLength(1));
    await tester.tap(find.byKey(const ValueKey('pay-stop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stop-pay-confirm')));
    await settle();
    expect(data.paySchedules, isEmpty);
    await tester.tap(find.text('Undo'));
    await settle();
    expect(data.paySchedules, hasLength(1));
  });

  testWidgets(
    'Accounts shows Net worth and which account runs out; a tap opens '
    'the Ledger on it with its header, whose Forecast opens and keeps the '
    'range chosen (#529)',
    (tester) async {
      late AppDatabase db;
      late LedgerData data;
      late int tight;
      await tester.runAsync(() async {
        db = AppDatabase(NativeDatabase.memory());
        await seedDemoIfEmpty(db, _now);
        tight = await db.addAccount(name: 'Tight', type: AccountType.asset);
        final rent = await db.createCategory('Rent');
        // A bill ten days ahead the account can't meet.
        await db.postTransaction(
          date: DateTime(2026, 10, 17),
          scheduled: true,
          lines: [
            (accountId: tight, amount: -50000000, cleared: Cleared.uncleared),
            (accountId: rent, amount: 50000000, cleared: Cleared.uncleared),
          ],
        );
        data = await db.loadLedger();
      });
      addTearDown(() => tester.runAsync(db.close));
      final store = await _pump(
        tester,
        snapshot: snapshotOf(data, today: _now, madeAt: _now),
      );
      final source = _ActingSource(db, () => _now, (d) => data = d);
      store.actRowIn = (act) => source.act(act);
      await _toBudget(tester);
      await tester.tap(find.text('Accounts'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('net-worth')), findsOneWidget);
      expect(find.byKey(const ValueKey('net-worth-MNT')), findsOneWidget);
      expect(find.text('Bank'), findsOneWidget);
      expect(find.byKey(ValueKey('runs-out-$tight')), findsOneWidget);
      expect(find.text('Runs out on 10.17'), findsOneWidget);
      // A tap opens the Ledger on that account, its header over its rows.
      await tester.tap(find.byKey(ValueKey('open-account-$tight')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('account-header-$tight')), findsOneWidget);
      expect(find.byKey(const ValueKey('account-working')), findsOneWidget);
      expect(find.byKey(const ValueKey('account-cleared')), findsOneWidget);
      expect(find.text('Never reconciled'), findsOneWidget);
      expect(find.textContaining('10.17'), findsWidgets);
      // Its Forecast opens, with the computer's ranges.
      expect(find.byKey(const ValueKey('forecast-chart')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('account-forecast-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('forecast-chart')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('forecast-span-days90')),
        findsOneWidget,
      );
      await expectLater(
        find.byType(PhoneApp),
        matchesGoldenFile('goldens/phone_account.png'),
      );
      await tester.tap(find.byKey(const ValueKey('forecast-span-days90')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      expect(data.prefs['forecast.span'], 'days90');
    },
  );

  group('reconcile on the phone (#530)', () {
    /// A bank account, Statement, with ₮100,000 in and ₮30,000 out cleared
    /// and ₮8,000 out not cleared: ₮70,000 cleared here.
    Future<({AppDatabase db, int bank, int cash})> ledger(
      WidgetTester tester,
    ) async {
      late AppDatabase db;
      late int bank, cash;
      await tester.runAsync(() async {
        db = AppDatabase(NativeDatabase.memory());
        await seedDemoIfEmpty(db, _now);
        bank = await db.addAccount(name: 'Statement', type: AccountType.asset);
        cash = await db.createAccount(
          name: 'Pocket',
          type: AccountType.asset,
          currency: Currency.mnt,
          cash: true,
        );
        final food = await db.createCategory('Food');
        Future<int> row(int day, String payee, int amount, Cleared c) =>
            db.postTransaction(
              date: DateTime(2026, 10, day),
              payee: payee,
              lines: [
                (accountId: bank, amount: amount, cleared: c),
                (accountId: food, amount: -amount, cleared: Cleared.uncleared),
              ],
            );
        await row(1, 'Pay', 10000000, Cleared.cleared);
        await row(2, 'Nomin', -3000000, Cleared.cleared);
        await row(3, 'Unitel', -800000, Cleared.uncleared);
        await db.postTransaction(
          date: DateTime(2026, 10, 4),
          payee: 'Taxi',
          lines: [
            (accountId: cash, amount: -500000, cleared: Cleared.uncleared),
            (accountId: food, amount: 500000, cleared: Cleared.uncleared),
          ],
        );
        await db.postCount(
          accountId: cash,
          date: DateTime(2026, 10, 5),
          counted: 2000000,
          categoryId: food,
        );
      });
      addTearDown(() => tester.runAsync(db.close));
      return (db: db, bank: bank, cash: cash);
    }

    /// Types the bank's balance and puts the keyboard away, as Done does.
    /// The Food category's id.
    int data0(LedgerData d) =>
        d.categories.firstWhere((c) => c.name == 'Food').id;

    Future<void> typeBalance(WidgetTester tester, String typed) async {
      await tester.enterText(
        find.byKey(const ValueKey('reconcile-balance')),
        typed,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
    }

    testWidgets('Reconcile in the header: the bank\'s balance typed, a row '
        'cleared by its symbol until it matches, Lock with Undo, and Undo '
        'this reconcile on a locked row', (tester) async {
      final made = await ledger(tester);
      final db = made.db, bank = made.bank;
      late LedgerData data;
      await tester.runAsync(() async => data = await db.loadLedger());
      final store = await _pump(
        tester,
        snapshot: snapshotOf(data, today: _now, madeAt: _now),
      );
      final source = _ActingSource(db, () => _now, (d) => data = d);
      store.actRowIn = (act) => source.act(act);
      Future<void> settle() async {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pumpAndSettle();
      }

      List<RegisterRow> rows() => data.registerFor(bank).posted;
      store.registerRequest.value = bank;
      await tester.pumpAndSettle();
      expect(find.text('Never reconciled'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('account-reconcile')));
      await tester.pumpAndSettle();
      // The card takes the header's place, and Cancel and Lock the tabs'.
      expect(find.byKey(ValueKey('reconcile-card-$bank')), findsOneWidget);
      expect(find.byKey(ValueKey('account-header-$bank')), findsNothing);
      expect(find.byKey(const ValueKey('to-budget')), findsNothing);
      // Nothing typed: the bank's number is asked for, and nothing locks.
      expect(find.text('Not the “available” balance'), findsOneWidget);
      expect(find.text('Not reconciled, through 10.07'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('reconcile-lock')))
            .onPressed,
        isNull,
      );
      // While the number is being typed no way out is offered: every digit
      // on the way is a difference.
      await tester.enterText(
        find.byKey(const ValueKey('reconcile-balance')),
        '62',
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('reconcile-adjust')), findsNothing);
      expect(find.byKey(const ValueKey('reconcile-lock')), findsOneWidget);
      await typeBalance(tester, '62000');
      expect(find.text('Bank is lower'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('reconcile-off'))).data,
        '₮8,000',
      );
      expect(
        find.text('Unitel on 10.03 is ₮8,000 and isn’t cleared'),
        findsOneWidget,
      );
      // Not matching: the way out is named, with its amount.
      expect(find.text('Take ₮8,000 off the balance and lock'), findsOneWidget);
      await expectLater(
        find.byType(PhoneApp),
        matchesGoldenFile('goldens/phone_reconcile.png'),
      );
      // A cleared row says the cleared balance after it; an uncleared one
      // has none until its symbol is tapped.
      final unitel = rows().firstWhere((r) => r.txnPayee == 'Unitel');
      expect(
        find.byKey(ValueKey('reconcile-balance-${unitel.entryId}')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(ValueKey('reconcile-tick-${unitel.entryId}')),
      );
      await settle();
      expect(
        find.byKey(ValueKey('reconcile-balance-${unitel.entryId}')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('reconcile-matches')), findsOneWidget);
      // No snack bar for a tick: the symbol changing says it.
      expect(find.byKey(const ValueKey('row-acted')), findsNothing);
      // A second tap takes it back, and a third clears it again.
      await tester.tap(
        find.byKey(ValueKey('reconcile-tick-${unitel.entryId}')),
      );
      await settle();
      expect(find.byKey(const ValueKey('reconcile-matches')), findsNothing);
      expect(find.byKey(const ValueKey('row-refused')), findsNothing);
      await tester.tap(
        find.byKey(ValueKey('reconcile-tick-${unitel.entryId}')),
      );
      await settle();
      expect(find.byKey(const ValueKey('reconcile-matches')), findsOneWidget);
      // Add is still there, for a row the bank shows and the ledger lacks.
      expect(find.byKey(const ValueKey('add-transaction')), findsOneWidget);
      expect(find.text('Lock 3 transactions'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reconcile-lock')));
      await settle();
      expect(rows().every((r) => r.cleared == Cleared.reconciled), isTrue);
      expect(
        find.text('Statement reconciled through 10.07 · 3 locked'),
        findsOneWidget,
      );
      // The header and the tabs are back.
      expect(find.byKey(const ValueKey('to-budget')), findsOneWidget);
      expect(find.text('Last reconciled on 10.07'), findsOneWidget);
      // Its Undo takes the locks off.
      await tester.tap(find.text('Undo'));
      await settle();
      expect(rows().every((r) => r.cleared == Cleared.cleared), isTrue);
      expect(find.text('Never reconciled'), findsOneWidget);

      // Locked again, then taken back from a locked row, whenever.
      await tester.tap(find.byKey(const ValueKey('account-reconcile')));
      await tester.pumpAndSettle();
      await typeBalance(tester, '62000');
      await tester.tap(find.byKey(const ValueKey('reconcile-lock')));
      await settle();
      expect(rows().every((r) => r.cleared == Cleared.reconciled), isTrue);
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
          .hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nomin'));
      await tester.pumpAndSettle();
      expect(
        find.text('Reconciled on 10.07 · date and amount locked'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('row-unreconcile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('row-unreconcile')));
      await settle();
      expect(rows().every((r) => r.cleared == Cleared.cleared), isTrue);
      expect(
        find.text('Reconcile of 10.07 undone · 3 rows back to cleared'),
        findsOneWidget,
      );
    });

    testWidgets('a difference nobody can find goes in as an adjustment, and '
        'Cancel leaves the reconcile with the rows as they are', (
      tester,
    ) async {
      final made = await ledger(tester);
      final db = made.db, bank = made.bank;
      late LedgerData data;
      await tester.runAsync(() async => data = await db.loadLedger());
      final store = await _pump(
        tester,
        snapshot: snapshotOf(data, today: _now, madeAt: _now),
      );
      final source = _ActingSource(db, () => _now, (d) => data = d);
      store.actRowIn = (act) => source.act(act);
      Future<void> settle() async {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pumpAndSettle();
      }

      store.registerRequest.value = bank;
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('account-reconcile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reconcile-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('account-header-$bank')), findsOneWidget);
      expect(find.byKey(const ValueKey('to-budget')), findsOneWidget);
      // Back leaves the reconcile too, not the app.
      await tester.tap(find.byKey(const ValueKey('account-reconcile')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('account-header-$bank')), findsOneWidget);
      expect(find.byKey(const ValueKey('to-budget')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('account-reconcile')));
      await tester.pumpAndSettle();
      await typeBalance(tester, '75000');
      expect(find.text('Bank is higher'), findsOneWidget);
      // No one row is ₮5,000.
      expect(find.text('Clear the rows your bank shows'), findsOneWidget);
      // Unitel is still uncleared: what the adjustment does is said first,
      // with the numbers, and Cancel leaves everything as it is.
      await tester.tap(find.byKey(const ValueKey('reconcile-adjust')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          '1 transaction through 10.07 isn’t cleared, and stays that way.',
        ),
        findsOneWidget,
      );
      expect(find.text('Working will be ₮67,000.'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('reconcile-adjust-ask-cancel')),
      );
      await tester.pumpAndSettle();
      expect(data.registerFor(bank).posted, hasLength(3));
      expect(find.byKey(ValueKey('reconcile-card-$bank')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reconcile-adjust')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reconcile-adjust-ask-go')));
      await settle();
      expect(
        find.text(
          'Statement reconciled through 10.07 · 2 locked · '
          '₮5,000 adjustment added',
        ),
        findsOneWidget,
      );
      final rows = data.registerFor(bank).posted;
      expect(rows, hasLength(4));
      expect(rows.where((r) => r.cleared == Cleared.reconciled), hasLength(3));
      expect(data.summaryFor(bank).cleared, 7500000);
      await tester.tap(find.text('Undo'));
      await settle();
      expect(data.registerFor(bank).posted, hasLength(3));
      expect(data.summaryFor(bank).cleared, 7000000);
    });

    testWidgets('the reconcile fits a small phone with large text', (
      tester,
    ) async {
      final made = await ledger(tester);
      late LedgerData data;
      await tester.runAsync(() async => data = await made.db.loadLedger());
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = await _pump(
        tester,
        snapshot: snapshotOf(data, today: _now, madeAt: _now),
        size: const Size(360, 640),
      );
      store.registerRequest.value = made.bank;
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('account-reconcile')));
      await tester.pumpAndSettle();
      // The long way out, on two lines, and the hint under the card's sum.
      // With the keyboard up there is still room for the bar.
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(
        find.byKey(const ValueKey('reconcile-balance')),
        '62000',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('reconcile-cancel')), findsOneWidget);
      tester.view.resetViewInsets();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reconcile-adjust')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a card is reconciled by what the bank says is owed', (
      tester,
    ) async {
      final made = await ledger(tester);
      final db = made.db;
      late LedgerData data;
      late int card;
      await tester.runAsync(() async {
        card = await db.addAccount(name: 'Card', type: AccountType.liability);
        final food = data0(await db.loadLedger());
        Future<int> row(int day, String payee, int amount, Cleared c) =>
            db.postTransaction(
              date: DateTime(2026, 10, day),
              payee: payee,
              lines: [
                (accountId: card, amount: amount, cleared: c),
                (accountId: food, amount: -amount, cleared: Cleared.uncleared),
              ],
            );
        // ₮40,000 spent and cleared, ₮6,000 spent and not: ₮40,000 owed.
        await row(1, 'Emart', -4000000, Cleared.cleared);
        await row(2, 'Shell', -600000, Cleared.uncleared);
        data = await db.loadLedger();
      });
      final store = await _pump(
        tester,
        snapshot: snapshotOf(data, today: _now, madeAt: _now),
      );
      final source = _ActingSource(db, () => _now, (d) => data = d);
      store.actRowIn = (act) => source.act(act);
      Future<void> settle() async {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pumpAndSettle();
      }

      store.registerRequest.value = card;
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('account-reconcile')));
      await tester.pumpAndSettle();
      expect(find.text('Bank says you owe'), findsOneWidget);
      // What is owed is typed as the bank shows it, positive.
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('reconcile-cleared')))
            .data,
        '₮40,000',
      );
      await typeBalance(tester, '46000');
      expect(find.text('Bank says you owe more'), findsOneWidget);
      expect(
        find.text('Shell on 10.02 is ₮6,000 and isn’t cleared'),
        findsOneWidget,
      );
      expect(find.text('Add ₮6,000 to what you owe and lock'), findsOneWidget);
      final shell = data
          .registerFor(card)
          .posted
          .firstWhere((r) => r.txnPayee == 'Shell');
      await tester.tap(find.byKey(ValueKey('reconcile-tick-${shell.entryId}')));
      await settle();
      // The cleared balance after it, as owed.
      expect(
        tester
            .widget<Text>(
              find.byKey(ValueKey('reconcile-balance-${shell.entryId}')),
            )
            .data,
        '₮46,000',
      );
      await tester.tap(find.byKey(const ValueKey('reconcile-lock')));
      await settle();
      expect(
        data
            .registerFor(card)
            .posted
            .every((r) => r.cleared == Cleared.reconciled),
        isTrue,
      );
      expect(data.reconciliations.last.balance, -4600000);
    });

    testWidgets('a cash account\'s header says its newest count and has '
        'Count the cash where Reconcile is', (tester) async {
      final made = await ledger(tester);
      late LedgerData data;
      await tester.runAsync(() async => data = await made.db.loadLedger());
      final store = await _pump(
        tester,
        snapshot: snapshotOf(data, today: _now, madeAt: _now),
      );
      store.registerRequest.value = made.cash;
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('account-reconcile')), findsNothing);
      expect(find.text('Counted on 10.05'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('account-counted'))).data,
        '₮20,000',
      );
      await tester.tap(find.byKey(const ValueKey('account-count')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('count-save')), findsOneWidget);
    });
  });

  testWidgets('Add account makes an account with what it starts with, and the '
      'Ledger\'s ⋯ edits, archives and deletes it, each said first where it '
      'leaves something behind and each with an Undo (#529)', (tester) async {
    late AppDatabase db;
    late LedgerData data;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      data = await db.loadLedger();
    });
    addTearDown(() => tester.runAsync(db.close));
    final store = await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    final source = _ActingSource(db, () => _now, (d) => data = d);
    store.actRowIn = (act) => source.act(act);
    Future<void> settle() async {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }

    AccountInfo? named(String n) => data.accounts.values
        .where((a) => a.name == n && !a.deleted)
        .firstOrNull;

    await _toBudget(tester);
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('add-account')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('add-account')));
    await tester.pumpAndSettle();
    // A balance that can't be read is said, not stopped at the door.
    await tester.enterText(
      find.byKey(const ValueKey('account-name')),
      'Golomt Savings',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-balance')),
      '500000',
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_new_account.png'),
    );
    await tester.tap(find.byKey(const ValueKey('new-account-create')));
    await settle();
    final made = named('Golomt Savings')!;
    expect(data.summaryFor(made.id).working, 50000000);
    expect(find.byKey(const ValueKey('account-done')), findsOneWidget);
    // The Ledger shows the new account, its header over its rows.
    expect(find.byKey(ValueKey('account-header-${made.id}')), findsOneWidget);
    // Undo takes it away while it is still empty.
    await tester.tap(find.text('Undo'));
    await settle();
    expect(named('Golomt Savings'), isNull);

    // Again, then Rename from the ⋯.
    await tester.tap(find.byKey(const ValueKey('to-budget')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('add-account')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('add-account')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('account-name')),
      'Golomt Savings',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-balance')),
      '500000',
    );
    await tester.tap(find.byKey(const ValueKey('new-account-create')));
    await settle();
    final id = named('Golomt Savings')!.id;
    await tester.tap(find.byKey(const ValueKey('account-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-act-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('edit-account-name')),
      'Golomt Main',
    );
    // A changed Type says what it does before Save, with the numbers.
    await tester.tap(find.byKey(const ValueKey('edit-kind-owed')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('edit-account-says')), findsOneWidget);
    expect(find.textContaining('becomes ₮500,000 owed'), findsOneWidget);
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_edit_account.png'),
    );
    await tester.tap(find.byKey(const ValueKey('edit-account-save')));
    await settle();
    expect(data.accounts[id]!.name, 'Golomt Main');
    expect(data.accounts[id]!.isOwed, isTrue);
    await tester.tap(find.text('Undo'));
    await settle();
    expect(data.accounts[id]!.name, 'Golomt Savings');
    expect(data.accounts[id]!.isOwed, isFalse);

    // Archive: it holds money, so it says so first, then goes ahead.
    await tester.tap(find.byKey(const ValueKey('account-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-act-archive')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-ask')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('account-ask-cancel')));
    await tester.pumpAndSettle();
    expect(data.accounts[id]!.archived, isFalse);
    await tester.tap(find.byKey(const ValueKey('account-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-act-archive')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-ask-go')));
    await settle();
    expect(data.accounts[id]!.archived, isTrue);
    // Gone from view: the Ledger shows every account again.
    expect(find.byKey(ValueKey('account-header-$id')), findsNothing);
    await tester.tap(find.text('Undo'));
    await settle();
    expect(data.accounts[id]!.archived, isFalse);
  });

  testWidgets('Payees: a page from Accounts, a card with Save pinned, and the '
      'offer to file what waits in Not categorized (#532)', (tester) async {
    late AppDatabase db;
    late LedgerData data;
    late int checking, groceries, fuel, holding;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      data = await db.loadLedger();
      checking = data.accounts.values
          .firstWhere((a) => a.name == 'TDB Checking')
          .id;
      groceries = data.categories.firstWhere((c) => c.name == 'Groceries').id;
      fuel = await db.createCategory('Fuel');
      holding = await db.createCategory('Not categorized');
      await db.addPayeeRule(
        spellings: const [PayeeSpelling(PayeeMatch.contains, 'NOMIN')],
        shownAs: 'Nomin Supermarket',
        categoryId: groceries,
        accountIds: {checking},
      );
      await db.addPayeeRule(
        spellings: const [PayeeSpelling(PayeeMatch.starts, 'TENGIS')],
        shownAs: 'Tengis Gas Station',
        categoryId: fuel,
        accountIds: {checking},
      );
      await db.postTransaction(
        date: DateTime(2026, 10, 5),
        payee: 'TENGIS GAS 0412',
        how: MadeHow.imported,
        lines: [
          (accountId: checking, amount: -2000000, cleared: Cleared.uncleared),
          (accountId: holding, amount: 2000000, cleared: Cleared.uncleared),
        ],
      );
      data = await db.loadLedger();
    });
    addTearDown(() => tester.runAsync(db.close));
    final store = await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    final source = _ActingSource(db, () => _now, (d) => data = d);
    store.actRowIn = (act) => source.act(act);
    Future<void> settle() async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
    }

    await _toBudget(tester);
    await tester.tap(find.byKey(const ValueKey('to-accounts')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('to-payees')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('to-payees')));
    await tester.pumpAndSettle();
    expect(find.text('Nomin Supermarket'), findsOneWidget);
    expect(find.text('Tengis Gas Station'), findsOneWidget);
    expect(
      find.text('1 row in Not categorized this period fits a payee here'),
      findsOneWidget,
    );
    // Where it goes is said before the button is pressed.
    expect(find.textContaining('Tengis Gas Station: 1 row, '), findsOneWidget);
    expect(find.textContaining(', to Fuel'), findsOneWidget);
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_payees.png'),
    );

    // The offer files the one waiting row, with an Undo.
    await tester.tap(find.byKey(const ValueKey('payees-file')));
    await settle();
    expect(find.text('Filed 1 row'), findsOneWidget);
    expect(find.byKey(const ValueKey('payees-file')), findsNothing);
    await tester.tap(find.text('Undo'));
    await settle();
    expect(find.byKey(const ValueKey('payees-file')), findsOneWidget);

    // A payee's card: the name as its heading, the ways, Cancel and Save.
    await tester.tap(
      find.byKey(
        ValueKey(
          'payee-${data.payeeRules.firstWhere((r) => r.shownAs == 'Nomin Supermarket').id}',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('payee-card')), findsOneWidget);
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_payee_card.png'),
    );
    await tester.tap(find.byKey(const ValueKey('way-0-starts')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('payee-name')),
      'Nomin Hyper',
    );
    await tester.tap(find.byKey(const ValueKey('payee-save')));
    await settle();
    expect(find.text('Nomin Hyper'), findsOneWidget);
    expect(
      data.payeeRules
          .firstWhere((r) => r.shownAs == 'Nomin Hyper')
          .spellings
          .first
          .how,
      PayeeMatch.starts,
    );
    await tester.tap(find.text('Undo'));
    await settle();
    expect(find.text('Nomin Supermarket'), findsOneWidget);

    // Save with nothing picked says what is missing and stays.
    await tester.tap(find.byKey(const ValueKey('add-payee')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('payee-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('payee-missing')), findsOneWidget);
    expect(find.byKey(const ValueKey('payee-card')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('payee-cancel')));
    await tester.pumpAndSettle();

    // Delete from the ⋯, with an Undo.
    await tester.tap(find.text('Tengis Gas Station'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('payee-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('payee-delete')));
    await settle();
    expect(find.text('Tengis Gas Station'), findsNothing);
    await tester.tap(find.text('Undo'));
    await settle();
    expect(find.text('Tengis Gas Station'), findsOneWidget);

    // Its card offers its name on the row brought in under the bank's
    // words, as the computer's does; one Undo.
    await tester.tap(find.text('Tengis Gas Station'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('payee-show-name')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('payee-show-name')));
    await settle();
    expect(find.text('1 row now shows «Tengis Gas Station»'), findsOneWidget);
    expect(
      data.registerAll().posted.where(
        (r) => r.txnPayee == 'Tengis Gas Station',
      ),
      hasLength(1),
    );
    await tester.tap(find.text('Undo'));
    await settle();
    expect(
      data.registerAll().posted.where((r) => r.txnPayee == 'TENGIS GAS 0412'),
      hasLength(1),
    );
  });

  testWidgets('an archived account is listed on Accounts, with what it holds, '
      'and Show again brings it back (#529)', (tester) async {
    late AppDatabase db;
    late LedgerData data;
    late int old;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      old = await db.addAccount(name: 'Old savings', type: AccountType.asset);
      await db.postOpeningBalance(
        accountId: old,
        date: DateTime(2026, 9, 1),
        balance: 30000000,
      );
      await db.setArchived(old, true);
      data = await db.loadLedger();
    });
    addTearDown(() => tester.runAsync(db.close));
    final store = await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    final source = _ActingSource(db, () => _now, (d) => data = d);
    store.actRowIn = (act) => source.act(act);
    await _toBudget(tester);
    await tester.tap(find.byKey(const ValueKey('to-accounts')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('archived-$old')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Archived accounts'), findsOneWidget);
    expect(find.text('₮300,000'), findsWidgets);
    await tester.tap(find.byKey(ValueKey('show-again-$old')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(data.accounts[old]!.archived, isFalse);
    expect(find.byKey(ValueKey('archived-$old')), findsNothing);
    expect(find.byKey(ValueKey('account-$old')), findsOneWidget);
  });

  testWidgets('Budget opens with the sum, the computer\'s terms with their '
      'signs, above the step and the categories (#528)', (tester) async {
    final (data, _) = await _stepLedger(tester);
    final snapshot = snapshotOf(data, today: _now, madeAt: _now);
    await _pump(tester, snapshot: snapshot);
    await _toBudget(tester);
    final sum = find.byKey(const ValueKey('budget-sum'));
    expect(sum, findsOneWidget);
    expect(
      tester.getTopLeft(sum).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('step-band'))).dy),
    );
    expect(find.text('Income'), findsWidgets);
    final pool = snapshot.sums.first.pool;
    final terms = snapshot.sums.first;
    expect(
      pool.income +
          pool.toCome +
          pool.fromBefore +
          pool.hadBefore +
          pool.exchanged -
          terms.given -
          terms.aside -
          terms.overspent -
          pool.loose,
      pool.notAssigned,
    );
    expect(
      find.descendant(
        of: sum,
        matching: find.byKey(
          ValueKey(terms.over ? 'assigned-over' : 'not-assigned'),
        ),
      ),
      findsOneWidget,
    );
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_budget_sum.png'),
    );
  });

  testWidgets('Budget opens with the Savings step and its progress, and no '
      'button (#487)', (tester) async {
    final (data, _) = await _stepLedger(tester);
    await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    await _toBudget(tester);
    final band = find.byKey(const ValueKey('step-band'));
    expect(band, findsOneWidget);
    // First in the list after the sum, above the categories (the sum is
    // tall enough that the first category is below the fold).
    expect(find.text('Groceries'), findsNothing);
    expect(
      find.descendant(of: band, matching: find.text('Build a safety net')),
      findsOneWidget,
    );
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp('Step 1 of 4')), findsOneWidget);
    semantics.dispose();
    expect(
      find.descendant(
        of: band,
        matching: find.text('₮800,000 of ₮2,000,000 · ₮1,200,000 to go'),
      ),
      findsOneWidget,
    );
    // The phone records and checks: money is assigned on the computer.
    expect(
      find.descendant(of: band, matching: find.byType(TextButton)),
      findsNothing,
    );
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_budget_step.png'),
    );
  });

  testWidgets('Savings is a third tab: it opens on the step they are on, '
      'and a tap on a stop shows that one (#533)', (tester) async {
    final data = (await tester.runAsync(() async {
      final db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      final net = await db.safetyNetCategory(
        name: 'Safety net',
        currency: Currency.mnt,
      );
      await db.setBudgetAmount(
        net,
        DateTime(2026, 10),
        DateTime(2026, 10, 31),
        80000000,
      );
      await db.setPreference(ReadyKeys.month, '200000000');
      final visa = (await db.loadLedger()).openAccounts.firstWhere(
        (a) => a.name == 'Golomt Visa',
      );
      await db.setPreference(ReadyKeys.rate(visa.id), '3 month');
      final data = await db.loadLedger();
      await db.close();
      return data;
    }))!;
    await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    await tester.tap(find.byKey(const ValueKey('to-savings')));
    await tester.pumpAndSettle();
    // Step 1, the one they're on, with the computer's words.
    expect(
      find.byKey(const ValueKey('savings-oneMonth-progress')),
      findsOneWidget,
    );
    expect(
      find.text('₮800,000 of ₮2,000,000 · ₮1,200,000 to go'),
      findsOneWidget,
    );
    expect(find.text('Now'), findsOneWidget);
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_savings.png'),
    );
    // Step 2's debts, each a card with its rate.
    await tester.tap(find.byKey(const ValueKey('savings-stop-consumerDebt')));
    await tester.pumpAndSettle();
    final visa = data.openAccounts.firstWhere((a) => a.name == 'Golomt Visa');
    final card = find.byKey(ValueKey('savings-debt-${visa.id}'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(ValueKey('savings-debt-${visa.id}-rate')),
        matching: find.textContaining('3% a month · about '),
      ),
      findsOneWidget,
    );
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_savings_debt.png'),
    );
    // A swipe goes on to the next.
    await tester.drag(
      find.byKey(const ValueKey('savings-pages')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('savings-page-moreMonths')),
      findsOneWidget,
    );
    // Goals, the fifth stop.
    await tester.tap(find.byKey(const ValueKey('savings-stop-goals')));
    await tester.pumpAndSettle();
    expect(
      find.text('Things with a date: a wedding, school, a car, a home.'),
      findsOneWidget,
    );
    // Back goes to Ledger, as it does from Budget.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('savings-pages')), findsNothing);
  });

  testWidgets('Savings: the month of expenses, Assign to Safety net, skip a '
      'step, three to six months and step 4, each with Undo (#533)', (
    tester,
  ) async {
    late AppDatabase db;
    late LedgerData data;
    late int net;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      net = await db.safetyNetCategory(
        name: 'Safety net',
        currency: Currency.mnt,
      );
      await db.setBudgetAmount(
        net,
        DateTime(2026, 10),
        DateTime(2026, 10, 31),
        80000000,
      );
      await db.setPreference(ReadyKeys.month, '200000000');
      data = await db.loadLedger();
    });
    addTearDown(() => tester.runAsync(db.close));
    final store = await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    final source = _ActingSource(db, () => _now, (d) => data = d);
    store.actRowIn = (act) => source.act(act);
    Future<void> settle() async {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }

    Future<String?> pref(String key) async =>
        tester.runAsync<String?>(() => db.preference(key));
    Future<void> undo() async {
      await tester.tap(find.text('Undo'));
      await settle();
    }

    Future<void> tap(Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(key));
      await settle();
    }

    await tester.tap(find.byKey(const ValueKey('to-savings')));
    await tester.pumpAndSettle();

    // A month of expenses typed, then put back by Undo.
    await tap(const ValueKey('savings-month-edit'));
    await tester.enterText(
      find.byKey(const ValueKey('savings-month-field')),
      '2500000',
    );
    await tap(const ValueKey('savings-month-save'));
    expect(await pref(ReadyKeys.month), 'MNT:250000000');
    expect(
      find.text('₮800,000 of ₮2,500,000 · ₮1,700,000 to go'),
      findsOneWidget,
    );
    await undo();
    expect(await pref(ReadyKeys.month), '200000000');

    // Something not a number is said under the field, and nothing saved.
    await tap(const ValueKey('savings-month-edit'));
    await tester.enterText(
      find.byKey(const ValueKey('savings-month-field')),
      'abc',
    );
    await tap(const ValueKey('savings-month-save'));
    expect(find.byKey(const ValueKey('savings-month-wrong')), findsOneWidget);
    await tap(const ValueKey('savings-month-cancel'));
    expect(await pref(ReadyKeys.month), '200000000');

    // What isn't assigned goes to the Safety net, as much as fills it.
    int assigned() => snapshotOf(
      data,
      today: _now,
      madeAt: _now,
    ).categories.firstWhere((c) => c.id == '$net').assignedMinor;
    await tap(const ValueKey('savings-assign-oneMonth'));
    expect(assigned(), greaterThan(80000000));
    await undo();
    expect(assigned(), 80000000);

    // Skip this step for now, and Undo.
    await tester.tap(find.byKey(const ValueKey('savings-oneMonth-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('savings-oneMonth-aside')));
    await settle();
    expect(await pref(ReadyKeys.setAside), 'oneMonth');
    expect(find.text('Skipped for now'), findsOneWidget);
    await undo();
    expect(await pref(ReadyKeys.setAside), isNull);

    // Step 3 aims for five months.
    await tester.tap(find.byKey(const ValueKey('savings-stop-moreMonths')));
    await tester.pumpAndSettle();
    await tap(const ValueKey('savings-months-5'));
    expect(await pref(ReadyKeys.months), '5');
    // Two quick taps: the second waits for the first, so the Undo shown is
    // the real one and puts back five.
    await tester.tap(find.byKey(const ValueKey('savings-months-4')));
    await tester.tap(find.byKey(const ValueKey('savings-months-4')));
    await settle();
    expect(await pref(ReadyKeys.months), '4');
    await undo();
    expect(await pref(ReadyKeys.months), '5');

    // Step 4's answers.
    await tester.tap(find.byKey(const ValueKey('savings-stop-future')));
    await tester.pumpAndSettle();
    await tap(const ValueKey('savings-retirement-yes'));
    expect(await pref(ReadyKeys.retirement), 'yes');
    await tap(const ValueKey('savings-longLoans-none'));
    expect(await pref(ReadyKeys.longLoans), 'none');
    await undo();
    expect(await pref(ReadyKeys.longLoans), isNull);
    expect(await pref(ReadyKeys.retirement), 'yes');
  });

  testWidgets('Savings step 2: a debt’s rate, payment and what it counts as, '
      'Extra each month, and Compare the two ways, each with Undo (#533)', (
    tester,
  ) async {
    late AppDatabase db;
    late LedgerData data;
    late int visa, loan;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      final first = await db.loadLedger();
      visa = first.openAccounts.firstWhere((a) => a.name == 'Golomt Visa').id;
      final checking = first.openAccounts.first.id;
      loan = await db.createAccount(
        name: 'Khan loan',
        type: AccountType.liability,
      );
      // Borrowed into checking: the loan owes ₮5,000,000.
      await db.postTransaction(
        date: DateTime(2026, 8, 1),
        lines: [
          (accountId: loan, amount: -500000000, cleared: Cleared.cleared),
          (accountId: checking, amount: 500000000, cleared: Cleared.cleared),
        ],
      );
      await db.setPreference(ReadyKeys.rate(visa), '3 month');
      await db.setPreference(ReadyKeys.rate(loan), '4 month');
      await db.setPreference(ReadyKeys.pay(visa), '10000000');
      await db.setPreference(ReadyKeys.pay(loan), '50000000');
      data = await db.loadLedger();
    });
    addTearDown(() => tester.runAsync(db.close));
    final store = await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    final source = _ActingSource(db, () => _now, (d) => data = d);
    store.actRowIn = (act) => source.act(act);
    Future<void> settle() async {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }

    Future<String?> pref(String key) async =>
        tester.runAsync<String?>(() => db.preference(key));
    Future<void> undo() async {
      await tester.tap(find.text('Undo'));
      await settle();
    }

    Future<void> tap(Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(key));
      await settle();
    }

    await tester.tap(find.byKey(const ValueKey('to-savings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('savings-stop-consumerDebt')));
    await tester.pumpAndSettle();

    // The way followed, smallest first until picked, and Compare.
    expect(find.byKey(const ValueKey('savings-way-smallest')), findsOneWidget);
    await tap(const ValueKey('savings-compare'));
    expect(
      find.byKey(const ValueKey('savings-way-highestRate')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('savings-payoff-difference')),
      findsOneWidget,
    );
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_savings_compare.png'),
    );
    await tap(const ValueKey('savings-way-highestRate'));
    expect(await pref(ReadyKeys.method), 'rate');
    await undo();
    expect(await pref(ReadyKeys.method), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // A rate that looks like a year's is said, and saved as typed.
    await tap(ValueKey('savings-debt-$loan-rate'));
    await tester.enterText(
      find.byKey(ValueKey('savings-debt-$loan-rate-field')),
      '30',
    );
    await tester.pump();
    expect(
      find.byKey(ValueKey('savings-debt-$loan-rate-warning')),
      findsOneWidget,
    );
    await tap(ValueKey('savings-debt-$loan-rate-save'));
    expect(await pref(ReadyKeys.rate(loan)), '30 month');
    await undo();
    expect(await pref(ReadyKeys.rate(loan)), '4 month');

    // What's paid a month.
    await tap(ValueKey('savings-debt-$visa-pay'));
    await tester.enterText(
      find.byKey(ValueKey('savings-debt-$visa-pay-field')),
      '150000',
    );
    await tap(ValueKey('savings-debt-$visa-pay-save'));
    expect(await pref(ReadyKeys.pay(visa)), '15000000');

    // Extra each month.
    await tap(const ValueKey('savings-extra-edit'));
    await tester.enterText(
      find.byKey(const ValueKey('savings-extra-field')),
      '200000',
    );
    await tap(const ValueKey('savings-extra-save'));
    expect(await pref(ReadyKeys.extra), 'MNT:20000000');

    // Pay extra on the loan first, then the Visa counted as paid in full.
    await tap(ValueKey('savings-debt-$loan-menu'));
    await tap(ValueKey('savings-debt-$loan-target'));
    expect(await pref(ReadyKeys.target), '$loan');
    await tap(ValueKey('savings-debt-$visa-menu'));
    await tap(ValueKey('savings-debt-$visa-paidMonthly'));
    expect(data.accounts[visa]!.role, AccountRole.paidMonthly);
    await undo();
    expect(data.accounts[visa]!.role, isNull);
  });

  testWidgets('Savings goals: a date passed short asks what to do, Move the '
      'date, Edit, and Add a goal opening on its Goal card (#533)', (
    tester,
  ) async {
    late AppDatabase db;
    late LedgerData data;
    late int wedding, school;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      wedding = await db.createCategory('Wedding');
      await db.setCategoryPlan(
        wedding,
        CategoryPlan(
          categoryId: wedding,
          kind: PlanKind.byDate,
          amount: 300000000,
          start: DateTime(2026, 6, 1),
          due: DateTime(2026, 9, 30),
        ),
      );
      await db.setPreference(ReadyKeys.goal(wedding), 'yes');
      school = await db.createCategory('University');
      await db.setCategoryPlan(
        school,
        CategoryPlan(
          categoryId: school,
          kind: PlanKind.byDate,
          amount: 1000000000,
          start: DateTime(2026, 9, 1),
          due: DateTime(2027, 6, 30),
        ),
      );
      await db.setPreference(ReadyKeys.goal(school), 'yes');
      data = await db.loadLedger();
    });
    addTearDown(() => tester.runAsync(db.close));
    final store = await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    final source = _ActingSource(db, () => _now, (d) => data = d);
    store.actRowIn = (act) => source.act(act);
    Future<void> settle() async {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }

    Future<String?> pref(String key) async =>
        tester.runAsync<String?>(() => db.preference(key));
    Future<void> tap(Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(key));
      await settle();
    }

    await tester.tap(find.byKey(const ValueKey('to-savings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('savings-stop-goals')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('savings-goal-$wedding')), findsOneWidget);
    expect(find.byKey(ValueKey('savings-goal-$school')), findsOneWidget);
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_savings_goals.png'),
    );

    // The wedding happened, the family covering the rest.
    await tap(ValueKey('savings-goal-done-$wedding'));
    expect(await pref(ReadyKeys.goalLate(wedding)), 'done');
    await tester.tap(find.text('Undo'));
    await settle();
    expect(await pref(ReadyKeys.goalLate(wedding)), isNull);

    // Its date moved to when the usual amount has it ready.
    final due = data.plans[wedding]!.due;
    await tap(ValueKey('savings-goal-move-$wedding'));
    expect(data.plans[wedding]!.due!.isAfter(due!), isTrue);
    await tester.tap(find.text('Undo'));
    await settle();
    expect(data.plans[wedding]!.due, due);

    // Edit opens the category's Edit, as on Budget.
    await tap(ValueKey('savings-goal-edit-$school'));
    expect(find.text('University'), findsWidgets);
    await tap(const ValueKey('new-category-cancel'));

    // Add a goal opens New category on its Goal card.
    await tap(const ValueKey('savings-goal-add'));
    final goal = find.byKey(const ValueKey('plan-type-goal'));
    expect(goal, findsOneWidget);
    expect(
      tester.widget<TypeCards>(find.byType(TypeCards)).type,
      CategoryType.goal,
    );
  });

  testWidgets('Budget: a tap on the step band opens Savings on that step '
      '(#533)', (tester) async {
    final (data, _) = await _stepLedger(tester);
    await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    // Savings left on another stop: the band still opens on its own step.
    await tester.tap(find.byKey(const ValueKey('to-savings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('savings-stop-goals')));
    await tester.pumpAndSettle();
    await _toBudget(tester);
    await tester.tap(find.byKey(const ValueKey('step-band')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('savings-oneMonth-progress')),
      findsOneWidget,
    );
  });

  testWidgets('No Savings tab without a ledger behind the figures: the demo '
      '(#533)', (tester) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('to-budget')), findsOneWidget);
    expect(find.byKey(const ValueKey('to-savings')), findsNothing);
  });

  testWidgets('Budget: the step band counts what this phone took from the '
      'Safety net, as its row does (#487)', (tester) async {
    final (data, net) = await _stepLedger(tester);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = PhoneStore(
      snapshotOf(data, today: _now, madeAt: _now),
      waiting: [
        PhoneEntry(
          id: 'e1',
          categoryId: '$net',
          accountId: '${data.openAccounts.first.id}',
          payee: 'Repair',
          amountMinor: -5000000,
          date: _now,
          madeAt: _now,
        ),
      ],
    );
    await tester.pumpWidget(PhoneApp(store: store, now: () => _now));
    await tester.pumpAndSettle();
    await _toBudget(tester);
    expect(
      find.text('₮750,000 of ₮2,000,000 · ₮1,250,000 to go'),
      findsOneWidget,
    );
  });

  // The first steps after setup (#475), on the phone: a ledger set up on
  // the computer since the walk was built, with money in the bank and a
  // credit card owing.
  Future<(AppDatabase, LedgerData, int)> walkLedger(
    WidgetTester tester,
  ) async => (await tester.runAsync(() async {
    final db = AppDatabase(NativeDatabase.memory());
    final bank = await db.createAccount(
      name: 'TDB Checking',
      type: AccountType.asset,
    );
    final card = await db.createAccount(
      name: 'Golomt Visa',
      type: AccountType.liability,
    );
    await db.postOpeningBalance(
      accountId: bank,
      date: _now,
      balance: 100000000,
    );
    await db.postOpeningBalance(
      accountId: card,
      date: _now,
      balance: -30000000,
    );
    await db.setPreference(SetupKeys.done, '1');
    await db.setPreference(WalkKeys.started, dateKey(_now));
    return (db, await db.loadLedger(), card);
  }))!;

  testWidgets('Budget: the first steps after setup take the step band’s '
      'spot, one at a time, each passed with Undo (#475)', (tester) async {
    var (db, data, _) = await walkLedger(tester);
    addTearDown(() => tester.runAsync(db.close));
    final store = await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    final source = _ActingSource(db, () => _now, (d) => data = d);
    store.actRowIn = (act) => source.act(act);
    Future<void> settle() async {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }

    await _toBudget(tester);
    expect(find.byKey(const ValueKey('walk-band')), findsOneWidget);
    expect(find.byKey(const ValueKey('step-band')), findsNothing);
    expect(
      find.text(
        'Start with the bills you pay on a set date, such as Rent, СӨХ or '
        'a Storepay instalment.',
      ),
      findsOneWidget,
    );
    // The card's step is coming, so the bills' line says so.
    expect(
      find.text(
        'Each one is a category with its date, so the forecast plans for it. '
        'Credit card and loan payments come next.',
      ),
      findsOneWidget,
    );
    for (final s in ['bills', 'debts', 'dayToDay', 'assign']) {
      expect(find.byKey(ValueKey('walk-step-$s')), findsOneWidget);
    }
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_walk.png'),
    );

    // Not now is their own answer: said, with Undo.
    await tester.tap(find.byKey(const ValueKey('walk-pass')));
    await settle();
    expect(data.prefs[WalkKeys.passed(WalkStep.bills)], 'yes');
    expect(find.text('“Bills” skipped for now'), findsOneWidget);
    expect(
      find.text(
        'Golomt Visa owes ₮300,000. Add the bill that pays it, so your '
        'budget plans for the payment.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Undo'));
    await settle();
    expect(data.prefs[WalkKeys.passed(WalkStep.bills)], isNull);
    expect(find.byKey(const ValueKey('walk-add-bill')), findsOneWidget);

    // Bills, the card (that one only), day-to-day: with nothing planned
    // there's nothing to assign, and the band is gone.
    await tester.tap(find.byKey(const ValueKey('walk-pass')));
    await settle();
    await tester.tap(find.byKey(const ValueKey('walk-pass')));
    await settle();
    expect(
      data.prefs.keys.where((k) => k.startsWith('walk.debt.')),
      hasLength(1),
    );
    expect(data.prefs[WalkKeys.passed(WalkStep.debts)], isNull);
    expect(
      find.text('Then everyday spending, such as groceries and bus fare.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('walk-pass')));
    await settle();
    expect(find.byKey(const ValueKey('walk-band')), findsNothing);
  });

  testWidgets('Budget: the walk’s buttons open New category on its card; the '
      'card’s bill has no Add another and comes in paying the card (#475)', (
    tester,
  ) async {
    var (db, data, card) = await walkLedger(tester);
    addTearDown(() => tester.runAsync(db.close));
    final store = await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    final source = _ActingSource(db, () => _now, (d) => data = d);
    store.actRowIn = (act) => source.act(act);
    await _toBudget(tester);
    await tester.tap(find.byKey(const ValueKey('walk-add-bill')));
    await tester.pumpAndSettle();
    // On the Bill card: its date is asked.
    expect(find.byKey(const ValueKey('plan-date')), findsOneWidget);
    expect(find.byKey(const ValueKey('new-category-another')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('new-category-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('walk-pass')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add the bill that pays Golomt Visa'), findsOneWidget);
    // Not now's snack bar gone, so it doesn't cover the page's Add.
    await tester.pump(phoneSnackTime + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('walk-add-debt-bill')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-date')), findsOneWidget);
    expect(find.byKey(const ValueKey('new-category-another')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('new-category-name')),
      'Card payment',
    );
    await tester.pumpAndSettle();
    await _scrollTo(tester, const ValueKey('plan-amount'));
    await tester.enterText(find.byKey(const ValueKey('plan-amount')), '50000');
    await tester.tap(find.byKey(const ValueKey('plan-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await _paidFrom(tester);
    await tester.tap(find.byKey(const ValueKey('new-category-add')));
    await tester.pumpAndSettle();
    final made = store.made.single;
    expect(made.name, 'Card payment');
    expect(made.paysLoan, card);
    expect(made.type, CategoryType.bill);
  });

  testWidgets('Budget: with no ledger behind the figures (the preview), no '
      'step band', (tester) async {
    await _pump(tester);
    await _toBudget(tester);
    expect(find.byKey(const ValueKey('step-band')), findsNothing);
  });

  testWidgets('Budget: a group under its heading, a month of its own, a '
      'note, as on the computer (#100)', (tester) async {
    final base = previewSnapshot(DateTime(2026, 10, 7, 8, 10));
    PhoneCategory grouped(
      PhoneCategory c, {
      String? group,
      String? note,
      int? once,
      int? usual,
    }) => PhoneCategory(
      id: c.id,
      name: c.name,
      leftMinor: c.leftMinor,
      hadMinor: c.hadMinor,
      paidFromId: c.paidFromId,
      recentPayees: c.recentPayees,
      due: c.due,
      group: group,
      note: note,
      onceMinor: once,
      usualMinor: usual,
    );
    await _pump(
      tester,
      snapshot: PhoneSnapshot(
        madeAt: base.madeAt,
        payees: base.payees,
        accounts: base.accounts,
        categories: [
          for (final c in base.categories)
            switch (c.id) {
              'groceries' => grouped(
                c,
                group: 'Home',
                once: 120000000,
                usual: 90000000,
              ),
              'utilities' => grouped(c, group: 'Home'),
              'clothing' => grouped(
                c,
                note: 'School uniforms in August',
                once: 0,
                usual: 8000000,
              ),
              _ => c,
            },
        ],
      ),
    );
    await _toBudget(tester);
    expect(find.byKey(const ValueKey('group-heading-Home')), findsOneWidget);
    // The group comes after the categories in no group, before Bills.
    final heading = tester
        .getTopLeft(find.byKey(const ValueKey('group-heading-Home')))
        .dy;
    expect(tester.getTopLeft(find.text('Groceries')).dy, greaterThan(heading));
    expect(tester.getTopLeft(find.text('Transport')).dy, lessThan(heading));
    expect(
      find.text('₮1,200,000 in October only, then ₮900,000 a month'),
      findsOneWidget,
    );
    expect(
      find.text('Skipped in October, then ₮80,000 a month'),
      findsOneWidget,
    );
    expect(find.text('School uniforms in August'), findsOneWidget);
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_budget_groups.png'),
    );
  });

  testWidgets('Send feedback… sits beside Accounts and opens the form', (
    tester,
  ) async {
    final browser = _FakeBrowser();
    final before = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = browser;
    addTearDown(() => UrlLauncherPlatform.instance = before);
    await _pump(tester);
    await _toBudget(tester);
    // In sight without scrolling, on the row Accounts is on.
    final button = find.byKey(const ValueKey('report-problem'));
    expect(button.hitTestable(), findsOneWidget);
    expect(
      tester.getCenter(button).dy,
      closeTo(tester.getCenter(find.text('Accounts')).dy, 2),
    );
    expect(find.byTooltip('Send feedback…'), findsOneWidget);
    await tester.tap(button);
    // Until the browser is asked: the version is read first.
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && browser.opened.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    final link = Uri.parse(browser.opened.single);
    expect('${link.host}${link.path}', 'lls.mn/en/contact/');
    expect(link.queryParameters['from'], 'betterbudget');
  });

  testWidgets('Recent problems ends Budget while there are any, and Copy '
      'all copies them', (tester) async {
    final dir = _phoneDir();
    final problems = ProblemLog(
      File('${dir.path}/problems'),
      now: () => _now,
      version: () async => '0.56.0',
    );
    await _pump(tester, problems: problems);
    await _toBudget(tester);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recent-problems')), findsNothing);

    await tester.runAsync(
      () => problems.record(
        'Couldn’t save this phone’s entries on the phone. While the app is '
        'open, it tries again every half minute.',
        PlatformException(code: 'full', message: 'No space left'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('recent-problems')));
    await tester.pumpAndSettle();
    expect(find.text('Recent problems'), findsOneWidget);
    expect(
      find.text('PlatformException(full, No space left, null, null)'),
      findsOneWidget,
    );
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_recent_problems.png'),
    );
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('copy-all-problems')));
    await tester.pump();
    expect(copied.single, startsWith('${_stamp(_now)} · 0.56.0\n'));
    expect(find.text('Copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    // Send feedback… is beside Copy all, for the form to paste them into.
    expect(
      find.byKey(const ValueKey('problems-send-feedback')),
      findsOneWidget,
    );
  });

  testWidgets('a long name beside a large amount drops the cents', (
    tester,
  ) async {
    await _pump(
      tester,
      snapshot: PhoneSnapshot(
        madeAt: DateTime(2026, 10, 6, 21, 40),
        accounts: const [
          PhoneAccount(id: 'a', name: 'TDB Checking', balanceMinor: 0),
        ],
        categories: const [
          PhoneCategory(
            id: 'c',
            name: 'Apartment renovation',
            leftMinor: 123456789000,
          ),
        ],
      ),
    );
    await _toBudget(tester);
    expect(find.text('₮1,234,567,890'), findsOneWidget);
    expect(find.text('From your computer 2026.10.06 21:40'), findsOneWidget);
  });

  testWidgets('a category is picked from the list, and Save takes it from '
      'what is left', (tester) async {
    final store = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    // Every category with what is left in it, the bills apart.
    expect(find.text('₮148,000.00'), findsOneWidget);
    expect(find.text('Bills'), findsOneWidget);
    expect(find.text('+ New category'), findsOneWidget);
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_category.png'),
    );
    await tester.tap(_inMenu('Groceries'));
    await tester.pumpAndSettle();
    expect(find.text('₮148,000.00 left now'), findsOneWidget);

    await _type(tester, '12500');
    expect(find.text('−₮12,500'), findsOneWidget);
    expect(
      find.text('₮148,000.00 left now · ₮135,500.00 after this'),
      findsOneWidget,
    );
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_ledger.png'),
    );

    await tester.tap(find.text('Save'));
    await tester.pump();
    // No payee is filled in ahead, and none is offered until one is typed.
    expect(find.text('Enter a payee'), findsOneWidget);
    expect(find.text('Nomin'), findsNothing);
    expect(store.waiting, isEmpty);
    await tester.tap(find.byKey(const ValueKey('payee-row')));
    await tester.pumpAndSettle();
    expect(find.text('Nomin'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('payee-field')), 'n');
    await tester.pump();
    // This category's own payee that begins with it comes first; one that
    // only holds the letter comes after.
    final offered = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Text),
          ),
        )
        .map((w) => w.data)
        .toList();
    expect(
      offered.indexOf('Nomin'),
      lessThan(offered.indexOf('Modern Nomads')),
    );
    expect(offered, isNot(contains('E-Mart')));
    await tester.tap(find.text('Nomin'));
    await tester.pumpAndSettle();
    expect(find.text('Nomin'), findsOneWidget);

    // Nor is an account: Groceries' own in the ledger isn't put in for them.
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Choose an account'), findsOneWidget);
    expect(store.waiting, isEmpty);
    await _account(tester, 'TDB Checking');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final entry = store.waiting.single;
    expect(entry.amountMinor, -1250000);
    expect(entry.payee, 'Nomin');
    expect(entry.categoryId, 'groceries');
    expect(entry.accountId, 'tdb');
    expect(entry.date, DateTime(2026, 10, 7));
    // It says what went in, and the form is ready for the next one.
    expect(find.text('Saved · Nomin −₮12,500.00'), findsOneWidget);
    expect(find.text('Groceries · ₮135,500.00 left'), findsOneWidget);
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_saved.png'),
    );
    expect(find.text('−₮0'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);
    expect(find.text('1 entry isn’t on your computer yet'), findsOneWidget);
    // The toast goes by itself.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('saved-toast')), findsNothing);
    expect(find.text('Undo'), findsNothing);
    await _toBudget(tester);
    expect(find.text('₮135,500.00'), findsOneWidget);
  });

  testWidgets('one receipt split over categories: the split page, Save '
      'waits, one entry with its lines', (tester) async {
    final store = await _pump(tester);
    await _type(tester, '135500');
    await _payee(tester, 'Nomin');
    await _category(tester, 'Groceries');
    // The category list offers to split; Groceries starts the first line.
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('split-option')));
    await tester.pumpAndSettle();
    expect(find.text('Split'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    await _type(tester, '98000');
    await tester.pumpAndSettle();
    // Not "left", which on the phone is what a budget has.
    expect(find.text('₮37,500 to place'), findsOneWidget);
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_split.png'),
    );

    // Done with some left: Save waits, and says how much (owner, 2026-10-17).
    await tester.tap(find.byKey(const ValueKey('split-done')));
    await tester.pumpAndSettle();
    expect(find.text('1 category'), findsOneWidget);
    await _account(tester, 'TDB Checking');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Place the last ₮37,500.00'), findsOneWidget);
    expect(store.waiting, isEmpty);

    // Back to the split page from Category; Groceries isn't offered twice.
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('split-another')));
    await tester.pumpAndSettle();
    expect(_inMenu('Groceries'), findsNothing);
    expect(find.byKey(const ValueKey('split-option')), findsNothing);
    await tester.tap(_inMenu('Clothing'));
    await tester.pumpAndSettle();
    await _type(tester, '37500');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('split-left')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('split-done')));
    await tester.pumpAndSettle();
    expect(find.text('2 categories'), findsOneWidget);
    expect(find.text('Groceries ₮98,000 · Clothing ₮37,500'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final entry = store.waiting.single;
    expect(entry.categoryId, phoneSplitId);
    expect(entry.amountMinor, -13550000);
    expect(entry.lines, [
      (categoryId: 'groceries', amountMinor: -9800000),
      (categoryId: 'clothing', amountMinor: -3750000),
    ]);
    // The toast says what it did to each category.
    expect(find.text('Saved · Nomin −₮135,500.00'), findsOneWidget);
    expect(find.text('Groceries · ₮50,000.00 left'), findsOneWidget);
    expect(find.text('Clothing · ₮42,500.00 left'), findsOneWidget);
    await _toBudget(tester);
    expect(find.text('₮50,000.00'), findsOneWidget);
    expect(find.text('₮42,500.00'), findsOneWidget);
  });

  testWidgets('the Category dropdown opens on the same screen, Split first '
      'with its icon', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    // The entry screen stays: no page in front of it (owner, 2026-10-17).
    expect(find.byKey(const ValueKey('payee-row')), findsOneWidget);
    final split = find.byKey(const ValueKey('split-option'));
    expect(
      find.descendant(
        of: split,
        matching: find.byIcon(Icons.call_split_rounded),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(split).dy,
      lessThan(tester.getTopLeft(_inMenu('Groceries')).dy),
    );
    await tester.tap(_inMenu('Eating out'));
    await tester.pumpAndSettle();
    expect(find.text('Eating out'), findsOneWidget);
    expect(find.text('Overspent by ₮18,400.00'), findsOneWidget);
    // Its account in the ledger is the Visa; Paid from is still theirs.
    expect(find.text('Golomt Visa'), findsNothing);
  });

  testWidgets('Paid from lists each account with what it holds now (#184)', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('account-row')));
    await tester.pumpAndSettle();
    final rows = find.byWidgetPredicate(
      (w) => w is ListTile && '${w.key}'.contains('paid-from-'),
    );
    expect(rows, findsWidgets);
    for (final row in tester.widgetList<ListTile>(rows)) {
      expect((row.subtitle! as Text).data, contains('₮'));
    }
    // A card says what's owed.
    expect(find.textContaining('Owed ₮'), findsWidgets);
  });

  testWidgets(
    'a name that isn’t a category makes one, waiting for your computer',
    (tester) async {
      final store = await _pump(tester);
      await _newCategory(tester, 'Cof');
      final made = store.made.single;
      expect(made.name, 'Cof');
      expect(made.currency, Currency.mnt);
      // Back on the entry with it chosen; it isn't called overspent.
      expect(find.text('Cof'), findsOneWidget);
      expect(find.text('Nothing assigned yet'), findsOneWidget);
      expect(
        find.text('1 new category isn’t on your computer yet'),
        findsOneWidget,
      );

      await _type(tester, '4500');
      expect(find.text('Nothing assigned yet'), findsOneWidget);
      await _payee(tester, 'Tom N Toms');
      await _account(tester, 'Cash wallet');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(store.waiting.single.categoryId, made.id);
      expect(find.text('Cof · nothing assigned yet'), findsOneWidget);
      expect(
        find.text('1 entry and 1 new category aren’t on your computer yet'),
        findsOneWidget,
      );

      await _toBudget(tester);
      expect(find.text('Cof'), findsOneWidget);
      expect(find.text('Nothing assigned yet'), findsOneWidget);
      expect(find.text('−₮4,500.00'), findsOneWidget);

      // Deleting it says what goes with it, then takes both.
      await _toLedger(tester);
      await tester.tap(find.byKey(const ValueKey('waiting-link')));
      await tester.pumpAndSettle();
      expect(find.text('new category'), findsOneWidget);
      await tester.tap(find.text('Delete').first);
      await tester.pumpAndSettle();
      expect(
        find.text('Delete Cof and the 1 entry in it (₮4,500.00)?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(store.made, isEmpty);
      expect(store.waiting, isEmpty);
    },
  );

  testWidgets('Budget makes a new category, and says when the name is taken', (
    tester,
  ) async {
    final store = await _pump(tester);
    await _toBudget(tester);
    await tester.tap(find.byKey(const ValueKey('budget-new-category')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('new-category-name')),
      'groceries',
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Groceries is already a category'), findsOneWidget);
    expect(store.made, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('new-category-name')),
      'Vet',
    );
    await _paidFrom(tester);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(store.made.single.name, 'Vet');
    // It lands with the money to spend, above the bills.
    await tester.scrollUntilVisible(find.text('Vet'), 100);
    expect(find.text('Vet'), findsOneWidget);
  });

  testWidgets('New category on the phone takes an emoji from its list or '
      'from the keyboard (#486)', (tester) async {
    final store = await _pump(tester);
    await _toBudget(tester);
    await tester.tap(find.byKey(const ValueKey('budget-new-category')));
    await tester.pumpAndSettle();
    final name = find.byKey(const ValueKey('new-category-name'));
    // Typed at the start from the keyboard, it moves into the square.
    await tester.enterText(name, '🐶 Vet');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(name).controller!.text, 'Vet');
    final square = find.byKey(const ValueKey('new-category-emoji'));
    expect(
      find.descendant(of: square, matching: find.text('🐶')),
      findsOneWidget,
    );
    // The list, from the square: another one replaces it.
    await tester.tap(square);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('emoji-💊')));
    await tester.pumpAndSettle();
    await _paidFrom(tester);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(store.made.single.name, '💊 Vet');
  });

  testWidgets('a bill twice a month on the phone: two days, and when it '
      'starts', (tester) async {
    final store = await _pump(tester);
    await _toBudget(tester);
    await tester.tap(find.byKey(const ValueKey('budget-new-category')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('new-category-name')),
      'Mobicom',
    );
    await _pickType(tester, CategoryType.bill);
    await tester.enterText(find.byKey(const ValueKey('plan-amount')), '45000');
    await tester.tap(find.byKey(const ValueKey('plan-repeat')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Twice a month'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-date')), findsNothing);
    expect(find.text('First due day'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('plan-day2')), '1');
    await tester.enterText(find.byKey(const ValueKey('plan-day1')), '15');
    await tester.pumpAndSettle();
    // When it starts: this month until a day is picked (#356).
    expect(find.text('This month'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('plan-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('This month'), findsNothing);
    await _paidFrom(tester);
    await tester.tap(find.byKey(const ValueKey('new-category-add')));
    await tester.pumpAndSettle();
    final made = store.made.single;
    expect(made.plan!.monthDays, [1, 15]);
    expect(made.plan!.everyMonths, isNull);
    // Picked 10.20: the first of its days from then is 11.01.
    expect(made.plan!.due, DateTime(_now.year, _now.month + 1, 1));
    expect(made.due, made.plan!.due);
  });

  testWidgets('New category on the phone asks everything the computer\'s '
      'window does, and the bill goes with the category', (tester) async {
    final store = await _pump(tester);
    await _toBudget(tester);
    await tester.tap(find.byKey(const ValueKey('budget-new-category')));
    await tester.pumpAndSettle();
    // One page, as on the computer: the name, then the four type cards.
    expect(find.text('How will this money be spent?'), findsOneWidget);
    for (final type in CategoryType.values) {
      expect(find.byKey(ValueKey('plan-type-${type.name}')), findsOneWidget);
    }
    await tester.enterText(
      find.byKey(const ValueKey('new-category-name')),
      'Mobicom',
    );
    await tester.tap(find.byKey(const ValueKey('plan-type-bill')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_new_category_types.png'),
    );
    await _pickType(tester, CategoryType.bill);
    // A bill starts on every month (#429).
    expect(find.text('Every month'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('plan-amount')), '45000');
    await tester.tap(find.byKey(const ValueKey('plan-repeat')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every month').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    // The row as it will read on the computer's Budget page.
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('plan-preview')),
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    expect(find.textContaining('₮45,000 due 10.15'), findsOneWidget);
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_new_category.png'),
    );
    await _paidFrom(tester);
    await tester.tap(find.byKey(const ValueKey('new-category-add')));
    await tester.pumpAndSettle();
    final made = store.made.single;
    expect(made.name, 'Mobicom');
    expect(made.plan!.kind, PlanKind.byDate);
    expect(made.plan!.amount, 4500000);
    expect(made.plan!.everyMonths, 1);
    expect(made.plan!.due, DateTime(2026, 10, 15));
    // A bill: it shows with the bills, by its date.
    expect(made.due, DateTime(2026, 10, 15));
  });

  testWidgets('on the phone a Goal asks for an amount to have ready, once; '
      'a Fund can wait for its amount (#429)', (tester) async {
    final store = await _pump(tester);
    await _toBudget(tester);
    await tester.tap(find.byKey(const ValueKey('budget-new-category')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('new-category-name')),
      'Laptop',
    );
    await _pickType(tester, CategoryType.goal);
    expect(find.text('Amount to have ready'), findsOneWidget);
    expect(find.text('Ready by'), findsOneWidget);
    expect(find.text('Once'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('plan-amount')),
      '3000000',
    );
    await tester.tap(find.byKey(const ValueKey('plan-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('28'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await _paidFrom(tester);
    await tester.tap(find.byKey(const ValueKey('new-category-another')));
    await tester.pumpAndSettle();
    expect(store.made.single.type, CategoryType.goal);
    expect(store.made.single.plan!.repeats, isFalse);

    // A Fund with no amount yet: made, with no plan, as a Fund.
    await tester.enterText(
      find.byKey(const ValueKey('new-category-name')),
      'Car repairs',
    );
    await _pickType(tester, CategoryType.fund);
    // A fund keeps what's left: nothing to ask about it.
    expect(find.byKey(const ValueKey('plan-carry-off')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('new-category-add')));
    await tester.pumpAndSettle();
    expect(store.made.last.name, 'Car repairs');
    expect(store.made.last.plan, isNull);
    expect(store.made.last.type, CategoryType.fund);
  });

  testWidgets('Add another keeps the page open for the next one; Add with '
      'something missing says what', (tester) async {
    final store = await _pump(tester);
    await _toBudget(tester);
    await tester.tap(find.byKey(const ValueKey('budget-new-category')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('new-category-name')),
      'Taxi',
    );
    await _paidFrom(tester);
    await tester.tap(find.byKey(const ValueKey('new-category-another')));
    await tester.pumpAndSettle();
    expect(find.text('Added: Taxi'), findsOneWidget);
    expect(store.made.single.plan, isNull);

    // A bill with no amount: nothing is made, and the page stays.
    await tester.enterText(
      find.byKey(const ValueKey('new-category-name')),
      'Gym',
    );
    await _pickType(tester, CategoryType.bill);
    await tester.tap(find.byKey(const ValueKey('new-category-add')));
    await tester.pumpAndSettle();
    expect(store.made, hasLength(1));
    expect(find.text('New category'), findsOneWidget);

    await _pickType(tester, CategoryType.dayToDay);
    await tester.enterText(find.byKey(const ValueKey('plan-amount')), '50000');
    await tester.tap(find.byKey(const ValueKey('new-category-add')));
    await tester.pumpAndSettle();
    expect(store.made.map((c) => c.name), ['Taxi', 'Gym']);
    expect(store.made.last.plan!.kind, PlanKind.each);
    expect(store.made.last.plan!.amount, 5000000);
  });

  testWidgets('from an entry it has no Add another, and a name that is a '
      'category already goes in the entry', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('new-category')));
    await tester.tap(find.byKey(const ValueKey('new-category')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('new-category-another')), findsNothing);
    expect(find.byKey(const ValueKey('money-currency')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('new-category-name')),
      'groceries',
    );
    await tester.pump();
    expect(
      find.text('Groceries is already a category. Add puts it in this row.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('new-category-add')));
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);
    // Cancel goes back with nothing made.
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('new-category')));
    await tester.tap(find.byKey(const ValueKey('new-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new-category-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('New category'), findsNothing);
  });

  testWidgets('a category on Budget opens where it is, with its figures', (
    tester,
  ) async {
    await _pump(
      tester,
      snapshot: PhoneSnapshot(
        madeAt: DateTime(2026, 10, 7, 8, 10),
        accounts: const [
          PhoneAccount(id: 'a', name: 'TDB Checking', balanceMinor: 0),
        ],
        categories: const [
          PhoneCategory(
            id: 'g',
            name: 'Groceries',
            leftMinor: 14800000,
            hadMinor: 20000000,
            assignedMinor: 20000000,
            spentMinor: 5200000,
          ),
          PhoneCategory(id: 't', name: 'Transport', leftMinor: 100000),
        ],
      ),
    );
    await _toBudget(tester);
    expect(find.text('Add a transaction'), findsNothing);
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-assigned-g')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('open-assigned-g'))).data,
      '₮200,000.00',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('open-spent-g'))).data,
      '₮52,000.00',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('open-left-g'))).data,
      '₮148,000.00',
    );
    // One at a time; a second tap closes it.
    await tester.tap(find.text('Transport'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-row-g')), findsNothing);
    expect(find.byKey(const ValueKey('open-row-t')), findsOneWidget);
    await tester.tap(find.text('Transport'));
    await tester.pumpAndSettle();
    expect(find.text('Add a transaction'), findsNothing);
  });

  testWidgets('a category on Budget takes an Assigned amount, Assign what’s '
      'planned and Clear Assigned, each with Undo (#528)', (tester) async {
    late AppDatabase db;
    late LedgerData data;
    late int groceries;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      data = await db.loadLedger();
      groceries = data.accounts.values
          .firstWhere((a) => a.name == 'Groceries')
          .id;
      await db.setCategoryPlan(
        groceries,
        CategoryPlan(
          categoryId: groceries,
          kind: PlanKind.each,
          amount: 30000000,
          start: DateTime(2026, 10),
        ),
      );
      data = await db.loadLedger();
    });
    addTearDown(() => tester.runAsync(db.close));
    int assigned() => snapshotOf(
      data,
      today: _now,
      madeAt: _now,
    ).categories.firstWhere((c) => c.id == '$groceries').assignedMinor;
    final store = await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    final source = _ActingSource(db, () => _now, (d) => data = d);
    store.actRowIn = (act) => source.act(act);
    Future<void> settle() async {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }

    await _toBudget(tester);
    // Below the fold, past the sum and the step band: built once scrolled to.
    await tester.dragUntilVisible(
      find.text('Groceries'),
      find.byKey(const ValueKey('step-band')),
      const Offset(0, -100),
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Groceries')),
      alignment: 0.2,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    final before = assigned();
    // A typed amount, kept when the keyboard's Done is pressed.
    await tester.enterText(
      find.byKey(ValueKey('open-assigned-field-$groceries')),
      '123456',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle();
    expect(assigned(), 12345600);
    expect(find.byKey(const ValueKey('assign-done')), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await settle();
    expect(assigned(), before);
    // Assign what's planned sets it to its plan's amount, Undo undoes it.
    await tester.tap(find.byKey(ValueKey('open-planned-$groceries')));
    await settle();
    expect(assigned(), 30000000);
    await tester.tap(find.text('Undo'));
    await settle();
    expect(assigned(), before);
    // Typed again, then Clear Assigned takes it to nothing; Undo puts it back.
    await tester.enterText(
      find.byKey(ValueKey('open-assigned-field-$groceries')),
      '123456',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle();
    await tester.tap(find.byKey(ValueKey('open-clear-$groceries')));
    await settle();
    expect(assigned(), 0);
    expect(find.text('Cleared Groceries’s Assigned'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await settle();
    expect(assigned(), 12345600);
  });

  testWidgets('Move money on a Budget row moves between two categories or '
      'back to Not assigned, warns past what is there, and Undo takes it back '
      '(#528)', (tester) async {
    late AppDatabase db;
    late LedgerData data;
    late int groceries, other;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      data = await db.loadLedger();
      final cats = data.accounts.values.where((a) => a.isCategory).toList();
      groceries = cats.firstWhere((a) => a.name == 'Groceries').id;
      other = cats.firstWhere((a) => a.id != groceries && !a.isIncome).id;
      await db.setBudgetAmount(
        groceries,
        DateTime(2026, 10),
        DateTime(2026, 10, 31),
        30000000,
      );
      data = await db.loadLedger();
    });
    addTearDown(() => tester.runAsync(db.close));
    int assigned(int id) => snapshotOf(
      data,
      today: _now,
      madeAt: _now,
    ).categories.firstWhere((c) => c.id == '$id').assignedMinor;
    final store = await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    final source = _ActingSource(db, () => _now, (d) => data = d);
    store.actRowIn = (act) => source.act(act);
    Future<void> settle() async {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }

    await _toBudget(tester);
    await tester.scrollUntilVisible(
      find.text('Groceries'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('open-move-$groceries')));
    await tester.pumpAndSettle();
    // Out of Groceries into another category.
    await tester.tap(find.byKey(ValueKey('move-choice-$other')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('move-amount')), '1000');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('move-warning')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('move-go')));
    await settle();
    expect(assigned(groceries), 29900000);
    expect(assigned(other), 100000);
    expect(find.byKey(const ValueKey('move-done')), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await settle();
    expect(assigned(groceries), 30000000);
    expect(assigned(other), 0);
    // More than it has: said first, and Move still goes ahead.
    await tester.tap(find.byKey(ValueKey('open-move-$groceries')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('move-choice-none')));
    await tester.enterText(
      find.byKey(const ValueKey('move-amount')),
      '999999999',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('move-warning')), findsOneWidget);
    // No category picked is said, and nothing moves.
    await tester.tap(find.byKey(const ValueKey('move-cancel')));
    await tester.pumpAndSettle();
    expect(assigned(groceries), 30000000);
  });

  testWidgets('Edit on a Budget row opens the category on its type cards, '
      'saves a new name into the ledger, and Undo takes it back (#528)', (
    tester,
  ) async {
    late AppDatabase db;
    late LedgerData data;
    late int groceries;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      data = await db.loadLedger();
      groceries = data.accounts.values
          .firstWhere((a) => a.isCategory && a.name == 'Groceries')
          .id;
    });
    addTearDown(() => tester.runAsync(db.close));
    String nameOf() => data.accounts[groceries]!.name;
    final store = await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    final source = _ActingSource(db, () => _now, (d) => data = d);
    store.actRowIn = (act) => source.act(act);
    Future<void> settle() async {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }

    await _toBudget(tester);
    await tester.scrollUntilVisible(
      find.text('Groceries'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('open-edit-$groceries')));
    await tester.pumpAndSettle();
    expect(find.text('Edit Groceries'), findsOneWidget);
    expect(find.byType(TypeCards), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('new-category-name')),
      'Food',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new-category-add')));
    await settle();
    expect(nameOf(), 'Food');
    expect(find.byKey(const ValueKey('edit-done')), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await settle();
    expect(nameOf(), 'Groceries');
  });

  testWidgets('the Undo bar after an Edit clears by itself, with no swipe', (
    tester,
  ) async {
    late AppDatabase db;
    late LedgerData data;
    late int groceries;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      data = await db.loadLedger();
      groceries = data.accounts.values
          .firstWhere((a) => a.isCategory && a.name == 'Groceries')
          .id;
    });
    addTearDown(() => tester.runAsync(db.close));
    final store = await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    final source = _ActingSource(db, () => _now, (d) => data = d);
    store.actRowIn = (act) => source.act(act);
    await _toBudget(tester);
    await tester.scrollUntilVisible(
      find.text('Groceries'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('open-edit-$groceries')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('new-category-name')),
      'Food',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new-category-add')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('edit-done')), findsOneWidget);
    // Flutter keeps a snack bar with an action until it is swiped away,
    // unless told it may go.
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('edit-done')), findsNothing);
  });

  testWidgets('Edit has a Note and a Group saved with Save, and Archive and '
      'Delete…, each with Undo (#528)', (tester) async {
    late AppDatabase db;
    late LedgerData data;
    late int groceries;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      data = await db.loadLedger();
      groceries = data.accounts.values
          .firstWhere((a) => a.isCategory && a.name == 'Groceries')
          .id;
    });
    addTearDown(() => tester.runAsync(db.close));
    final store = await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    final source = _ActingSource(db, () => _now, (d) => data = d);
    store.actRowIn = (act) => source.act(act);
    store.categoryRowsIn = db.categoryEntryCount;
    Future<void> settle() async {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }

    var onBudget = false;
    Future<void> openEdit() async {
      if (!onBudget) await _toBudget(tester);
      onBudget = true;
      final edit = find.byKey(ValueKey('open-edit-$groceries'));
      if (edit.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          find.text('Groceries'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Groceries'));
        await tester.pumpAndSettle();
      }
      await tester.tap(edit);
      await tester.pumpAndSettle();
    }

    Future<void> see(String key) async {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey(key)),
        200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axis == Axis.vertical,
            )
            .last,
      );
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }

    await openEdit();
    await see('category-note');
    await tester.enterText(
      find.byKey(const ValueKey('category-note')),
      'Weekly shop',
    );
    // Typed here and not kept by Archive or Delete: said, not stopped.
    await see('edit-archive');
    expect(find.byKey(const ValueKey('edit-unsaved')), findsOneWidget);
    await see('category-group');
    await tester.tap(find.byKey(const ValueKey('category-group')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New group…'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('category-new-group')),
      'Home',
    );
    await tester.tap(find.byKey(const ValueKey('category-new-group-ok')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new-category-add')));
    await settle();
    expect(data.accounts[groceries]!.note, 'Weekly shop');
    expect(data.accounts[groceries]!.budgetGroup, 'Home');
    await tester.tap(find.text('Undo'));
    await settle();
    expect(data.accounts[groceries]!.note, isNull);
    expect(data.accounts[groceries]!.budgetGroup, isNull);

    // Archive asks nothing.
    await openEdit();
    await see('edit-archive');
    await tester.tap(find.byKey(const ValueKey('edit-archive')));
    await settle();
    expect(data.accounts[groceries]!.archived, isTrue);
    expect(find.textContaining('Groceries archived'), findsOneWidget);
    // It is brought back from Budget's Show archived, with Undo.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('budget-archived')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('budget-archived')));
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('unarchive-category-$groceries')));
    await settle();
    expect(data.accounts[groceries]!.archived, isFalse);
    expect(find.text('Groceries'), findsNothing);
    await tester.tap(find.text('Undo'));
    await settle();
    expect(data.accounts[groceries]!.archived, isTrue);
    await tester.tap(find.byKey(ValueKey('unarchive-category-$groceries')));
    await settle();
    expect(data.accounts[groceries]!.archived, isFalse);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Delete asks where its rows go (the demo has no Not categorized to
    // start with, so one is picked).
    await openEdit();
    await see('category-delete');
    await tester.tap(find.byKey(const ValueKey('category-delete')));
    await tester.pumpAndSettle();
    expect(find.text('Delete Groceries?'), findsOneWidget);
    expect(find.byKey(const ValueKey('delete-category-into')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('warning-cancel')));
    await tester.pumpAndSettle();
    expect(data.categories.any((a) => a.id == groceries), isTrue);
    await tester.tap(find.byKey(const ValueKey('category-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-category-into')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-into-0')));
    await tester.pumpAndSettle();
    // Moved into a category of its own currency, its money moves with the
    // rows: nothing goes back to Not assigned.
    expect(find.byKey(const ValueKey('delete-money-back')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('warning-confirm')));
    await settle();
    expect(data.categories.any((a) => a.id == groceries), isFalse);
    await tester.tap(find.text('Undo'));
    await settle();
    expect(data.categories.any((a) => a.id == groceries), isTrue);
  });

  testWidgets('Delete says its money going back before it goes, a category '
      'with nothing in it just goes, and a refusal is said (#528)', (
    tester,
  ) async {
    late AppDatabase db;
    late LedgerData data;
    late int groceries;
    late int empty;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      await db.incomeCategory();
      data = await db.loadLedger();
      groceries = data.accounts.values
          .firstWhere((a) => a.isCategory && a.name == 'Groceries')
          .id;
      empty = data.accounts.values
          .firstWhere((a) => a.isCategory && a.name == 'Tuition')
          .id;
      // Money assigned to it, which Delete gives back.
      await _ActingSource(
        db,
        () => _now,
        (d) => data = d,
      ).act(PhoneAssign(groceries, 20000000));
    });
    addTearDown(() => tester.runAsync(db.close));
    final store = await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    final source = _ActingSource(db, () => _now, (d) => data = d);
    var refuse = false;
    store.actRowIn = (act) =>
        refuse ? throw StateError('refused') : source.act(act);
    store.categoryRowsIn = db.categoryEntryCount;
    Future<void> settle() async {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openEdit(String name, int id) async {
      final edit = find.byKey(ValueKey('open-edit-$id'));
      if (edit.evaluate().isEmpty) {
        // From the top: the list builds its rows as it scrolls.
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
        await tester.pumpAndSettle();
        for (var i = 0; i < 12 && find.text(name).evaluate().isEmpty; i++) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -300),
          );
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text(name));
        await tester.pumpAndSettle();
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
      }
      await tester.tap(edit);
      await tester.pumpAndSettle();
    }

    Future<void> see(String key) async {
      // The page builds its rows as it scrolls.
      final page = find
          .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical)
          .last;
      for (
        var i = 0;
        i < 12 && find.byKey(ValueKey(key)).evaluate().isEmpty;
        i++
      ) {
        await tester.drag(page, const Offset(0, -300));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }

    await _toBudget(tester);
    // Its rows into Income: its money goes back, and the dialog says so.
    await openEdit('Groceries', groceries);
    await see('category-delete');
    await tester.tap(find.byKey(const ValueKey('category-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-category-into')));
    await tester.pumpAndSettle();
    final incomeAt = data.categories
        .where((a) => a.id != groceries)
        .toList()
        .indexWhere((a) => a.isIncome);
    final income = find.byKey(ValueKey('delete-into-$incomeAt'));
    // The list builds its rows as it scrolls.
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(income);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('delete-money-back')), findsOneWidget);
    await expectLater(
      find.byType(AlertDialog),
      matchesGoldenFile('goldens/phone_delete_money.png'),
    );
    await tester.tap(find.byKey(const ValueKey('warning-cancel')));
    await tester.pumpAndSettle();
    expect(data.categories.any((a) => a.id == groceries), isTrue);

    // A refusal from the ledger is said, and nothing changes.
    refuse = true;
    await tester.tap(find.byKey(const ValueKey('edit-archive')));
    await settle();
    expect(find.byKey(const ValueKey('edit-category-refused')), findsOneWidget);
    expect(data.accounts[groceries]!.archived, isFalse);
    refuse = false;
    await tester.tap(find.byKey(const ValueKey('new-category-cancel')));
    await tester.pumpAndSettle();

    // Nothing filed, nothing assigned: no question, it goes, with Undo.
    await openEdit('Tuition', empty);
    await see('category-delete');
    await tester.tap(find.byKey(const ValueKey('category-delete')));
    await settle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(data.categories.any((a) => a.id == empty), isFalse);
    await tester.tap(find.text('Undo'));
    await settle();
    expect(data.categories.any((a) => a.id == empty), isTrue);
  });

  testWidgets('Delete counts the rows when it is tapped: one filed after the '
      'page was drawn is asked about, never refused (#528)', (tester) async {
    late AppDatabase db;
    late LedgerData data;
    late int empty;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      data = await db.loadLedger();
      empty = data.accounts.values
          .firstWhere((a) => a.isCategory && a.name == 'Tuition')
          .id;
    });
    addTearDown(() => tester.runAsync(db.close));
    final store = await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    final source = _ActingSource(db, () => _now, (d) => data = d);
    store.actRowIn = (act) => source.act(act);
    store.categoryRowsIn = db.categoryEntryCount;
    await _toBudget(tester);
    for (var i = 0; i < 12 && find.text('Tuition').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('Tuition'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tuition'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('open-edit-$empty')));
    await tester.pumpAndSettle();
    final page = find
        .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical)
        .last;
    for (
      var i = 0;
      i < 12 &&
          find.byKey(const ValueKey('category-delete')).evaluate().isEmpty;
      i++
    ) {
      await tester.drag(page, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.byKey(const ValueKey('category-delete')));
    await tester.pumpAndSettle();
    // A row another computer filed since the page was drawn.
    await tester.runAsync(() async {
      final bank = data.accounts.values
          .firstWhere((a) => a.isBalanceSheet && !a.archived)
          .id;
      await db.postSimple(
        accountId: bank,
        date: _now,
        today: _now,
        payee: 'School',
        counterAccountId: empty,
        amount: -100000,
      );
    });
    await tester.tap(find.byKey(const ValueKey('category-delete')));
    await tester.pumpAndSettle();
    expect(find.text('Delete Tuition?'), findsOneWidget);
    expect(find.byKey(const ValueKey('delete-category-into')), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-category-refused')), findsNothing);
  });

  testWidgets('Edit on a bill has a switch for this period\'s bill, and Save '
      'skips it, with Undo (#365)', (tester) async {
    late AppDatabase db;
    late LedgerData data;
    late AccountInfo bill;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, _now);
      final id = await db.createCategory('Gym');
      await db.changeCategoryPlan(
        id,
        CategoryPlan(
          categoryId: id,
          kind: PlanKind.byDate,
          amount: 5000000,
          start: _now,
          due: DateTime(_now.year, _now.month, _now.day + 3),
          everyMonths: 1,
        ),
        _now,
      );
      data = await db.loadLedger();
      bill = data.accounts[id]!;
    });
    addTearDown(() => tester.runAsync(db.close));
    final day = billSwitches(data, bill.id, _now).first.date;
    final store = await _pump(
      tester,
      snapshot: snapshotOf(data, today: _now, madeAt: _now),
    );
    final source = _ActingSource(db, () => _now, (d) => data = d);
    PhoneEditCategory? got;
    store.actRowIn = (act) {
      if (act is PhoneEditCategory) got = act;
      return source.act(act);
    };
    Future<void> settle() async {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }

    await _toBudget(tester);
    await tester.scrollUntilVisible(
      find.text(bill.name),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(bill.name));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('open-edit-${bill.id}')));
    await tester.pumpAndSettle();
    final switchKey = ValueKey('bill-switch-${dateKey(day)}');
    await tester.scrollUntilVisible(
      find.byKey(switchKey),
      200,
      scrollable: find
          .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical)
          .last,
    );
    await tester.ensureVisible(find.byKey(switchKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(switchKey));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('new-category-add')),
      -200,
      scrollable: find
          .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical)
          .last,
    );
    await tester.tap(find.byKey(const ValueKey('new-category-add')));
    await settle();
    // What the skip does, and its Undo, is in phone_sync_test.
    expect(got?.skip, [day]);
    expect(got?.back, isEmpty);
  });

  testWidgets('a category on Budget starts an entry in it, and what was '
      'typed stays', (tester) async {
    await _pump(tester);
    await _type(tester, '500');
    await _toBudget(tester);
    await _addIn(tester, 'Transport');
    expect(find.text('−₮500'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
    expect(
      find.text('₮61,500.00 left now · ₮61,000.00 after this'),
      findsOneWidget,
    );
    expect(find.text('Cash wallet'), findsNothing);
  });

  testWidgets('an account chosen by hand stays when a category is chosen', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('account-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash wallet'));
    await tester.pumpAndSettle();
    await _category(tester, 'Groceries');
    expect(find.text('Cash wallet'), findsOneWidget);
    expect(find.text('TDB Checking'), findsNothing);
  });

  testWidgets(
    'Save with nothing typed says what is missing and saves nothing',
    (tester) async {
      final store = await _pump(tester);
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Enter an amount'), findsOneWidget);

      await _type(tester, '5');
      expect(find.text('Enter an amount'), findsNothing);
      // Named in the order they are on the screen: payee, then category.
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Enter a payee'), findsOneWidget);

      // A payee the ledger has never seen is typed in full.
      await _payee(tester, 'Shoppy');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Choose a category'), findsOneWidget);
      expect(store.waiting, isEmpty);

      await _category(tester, 'Clothing');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Choose an account'), findsOneWidget);
      await _account(tester, 'Cash wallet');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(store.waiting.single.payee, 'Shoppy');
    },
  );

  testWidgets('Clear empties the entry, and Undo brings a saved one back', (
    tester,
  ) async {
    final store = await _pump(tester);
    await _type(tester, '8000');
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(find.text('−₮0'), findsOneWidget);
    expect(find.text('Clear'), findsNothing);
    expect(store.waiting, isEmpty);

    await _spend(tester, 'Transport', '8000', 'ub', pick: 'UB Cab');
    expect(store.waiting, hasLength(1));
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(store.waiting, isEmpty);
    expect(find.text('−₮8,000'), findsOneWidget);
    expect(find.text('UB Cab'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
  });

  testWidgets('an entry the phone’s ledger took in at once keeps its toast, '
      'and Undo takes it back out of the ledger (#526 piece 4)', (
    tester,
  ) async {
    final store = await _pump(tester);
    final undone = <PhoneTake>[];
    const take = PhoneTake([1], []);
    store.undoTake = (t) async {
      undone.add(t);
      return store.snapshot;
    };
    await _spend(tester, 'Transport', '8000', 'ub', pick: 'UB Cab');
    final id = store.waiting.single.id;
    // The ledger took it in: the store lets go of it as the snapshot says.
    store.tookInto([id], take);
    store.snapshot = PhoneSnapshot(
      madeAt: store.snapshot.madeAt,
      accounts: store.snapshot.accounts,
      categories: store.snapshot.categories,
      taken: {
        store.device: PhoneTaken(entries: {id}),
      },
    );
    await tester.pump();
    expect(store.waiting, isEmpty);
    // Reading the ledger again didn't take the toast away.
    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(undone, [take]);
    // The form has the entry back, to go on with.
    expect(find.text('−₮8,000'), findsOneWidget);
    expect(find.text('UB Cab'), findsOneWidget);
  });

  test('a second take over an entry already taken leaves the first take its '
      'own entry, and a failing Undo says so by returning false', () async {
    final store = PhoneStore(
      PhoneSnapshot(
        madeAt: DateTime(2026, 11, 20),
        categories: [],
        accounts: [],
      ),
    );
    const first = PhoneTake([1], []);
    const second = PhoneTake([2], []);
    store.tookInto(['a'], first);
    store.tookInto(['a', 'b'], second);
    final undone = <PhoneTake>[];
    store.undoTake = (t) async {
      undone.add(t);
      return store.snapshot;
    };
    expect(await store.takeBack(['a']), isTrue);
    expect(undone, [first]);
    store.undoTake = (_) async => throw StateError('closed');
    expect(await store.takeBack(['b']), isFalse);
  });

  testWidgets('what another computer’s changes brought in is said as the '
      'computer says it, with no Undo', (tester) async {
    final store = await _pump(tester);
    store.news.value = [
      (transactions: 4, others: 0, payee: null, from: 'Tom’s MacBook Air'),
    ];
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('brought-in')), findsOneWidget);
    expect(find.textContaining('Tom’s MacBook Air'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('what changed here and on a computer both is asked once: this '
      'phone’s kept unless changed, one Save', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const line = AskLine(
      account: 'Groceries',
      amountMinor: 0,
      currency: 'MNT',
      isCategory: true,
    );
    AskSide side(int amount) => AskSide(
      date: '2026-11-12',
      payee: 'Corner shop',
      lines: [
        AskLine(
          account: 'Checking',
          amountMinor: -amount,
          currency: 'MNT',
          isCategory: false,
        ),
        line,
      ],
    );
    const bus = AskLine(
      account: 'Transport',
      amountMinor: 300000,
      currency: 'MNT',
      isCategory: true,
    );
    final asks = [
      Ask(
        id: 'a',
        kind: AskKind.transaction,
        mine: side(1200000),
        theirs: side(1500000),
        neither: side(1000000),
      ),
      Ask(
        id: 'b',
        kind: AskKind.transaction,
        mine: AskSide(date: '2026-11-16', payee: 'Bus pass', lines: [bus]),
        theirs: AskSide(deleted: true, payee: 'Bus pass'),
        neither: AskSide(date: '2026-11-16', payee: 'Bus pass', lines: [bus]),
      ),
    ];
    final store = PhoneStore(previewSnapshot(DateTime(2026, 11, 20)));
    final answers = <PhoneAnswer>[];
    await tester.pumpWidget(
      PhoneApp(
        store: store,
        now: () => _now,
        onAnswer: (a) async {
          answers.add(a);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('phone-asking-line')), findsNothing);
    store.asking.value = (
      asks: asks,
      from: 'Tom’s Mac',
      apart: false,
      notOnComputer: 0,
      otherChanges: 0,
      mineDigest: null,
      digest: 'd1',
    );
    await tester.pumpAndSettle();
    // Put once, by itself.
    expect(
      find.text('2 things were changed here and on a computer'),
      findsOneWidget,
    );
    expect(find.text('Keeping this phone’s'), findsOneWidget);
    // One computer deleted the other's, so nothing is chosen: asked.
    expect(find.text('Choose one:'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('ask-save')))
          .onPressed,
      isNull,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/phone_asking.png'),
    );
    // The second was deleted on the computer: chosen as that.
    await tester.tap(find.byKey(const ValueKey('ask-b-theirs')));
    await tester.pumpAndSettle();
    expect(find.text('Keeping it deleted (Tom’s Mac’s)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ask-save')));
    await tester.pumpAndSettle();
    expect(answers.single.picks, {'a': Pick.mine, 'b': Pick.theirs});
    // Not now leaves the line, which opens it again.
    store.asking.value = (
      asks: asks,
      from: 'Tom’s Mac',
      apart: false,
      notOnComputer: 0,
      otherChanges: 0,
      mineDigest: null,
      digest: 'd2',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ask-not-now')));
    await tester.pumpAndSettle();
    expect(answers, hasLength(1));
    await tester.tap(find.byKey(const ValueKey('phone-asking-line')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ask-save')), findsOneWidget);
  });

  testWidgets('a snack bar from the page underneath doesn’t lie over Save on '
      'the asking page', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    AskSide side(String payee) => AskSide(
      date: '2026-11-12',
      payee: payee,
      lines: const [
        AskLine(
          account: 'Checking',
          amountMinor: -1200000,
          currency: 'MNT',
          isCategory: false,
        ),
        AskLine(
          account: 'Groceries',
          amountMinor: 0,
          currency: 'MNT',
          isCategory: true,
        ),
      ],
    );
    final store = PhoneStore(previewSnapshot(DateTime(2026, 11, 20)));
    await tester.pumpWidget(
      PhoneApp(store: store, now: () => _now, onAnswer: (a) async => true),
    );
    await tester.pumpAndSettle();
    // An edit's snack bar is up when the question arrives.
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
        .showSnackBar(
          const SnackBar(
            duration: Duration(minutes: 1),
            content: Text('Corner shop 3 edited'),
          ),
        );
    await tester.pump();
    expect(find.text('Corner shop 3 edited'), findsOneWidget);
    store.asking.value = (
      asks: [
        Ask(
          id: 'a',
          kind: AskKind.transaction,
          mine: side('Corner shop 3'),
          theirs: side('Corner shop 4'),
          neither: side('Corner shop 2'),
        ),
      ],
      from: 'Tom’s Mac',
      apart: false,
      notOnComputer: 0,
      otherChanges: 0,
      mineDigest: null,
      digest: 'd1',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ask-save')), findsOneWidget);
    expect(find.text('Corner shop 3 edited'), findsNothing);
  });

  testWidgets('two ledgers that can’t be put together say what would be '
      'lost, and Not now loses nothing', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = PhoneStore(previewSnapshot(DateTime(2026, 11, 20)));
    final answers = <PhoneAnswer>[];
    await tester.pumpWidget(
      PhoneApp(
        store: store,
        now: () => _now,
        onAnswer: (a) async {
          answers.add(a);
          return true;
        },
      ),
    );
    store.asking.value = (
      asks: const <Ask>[],
      from: null,
      apart: true,
      notOnComputer: 3,
      otherChanges: 0,
      mineDigest: null,
      digest: 'd',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('3 entries made on this phone'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('apart-keep-folder')));
    await tester.pumpAndSettle();
    expect(answers.single.keepFolder, isTrue);
  });

  testWidgets('a waiting entry opens on the entry screen, and Save puts '
      'the fix in its place', (tester) async {
    final store = await _pump(tester);
    await _spend(tester, 'Transport', '8000', 'ub', pick: 'UB Cab');
    final first = store.waiting.single;
    await tester.tap(find.byKey(const ValueKey('waiting-link')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('waiting-${first.id}')));
    await tester.pumpAndSettle();

    // Filled in as it was, and saying what Save will do.
    expect(find.text('−₮8,000'), findsOneWidget);
    expect(find.text('UB Cab'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('TDB Checking'), findsOneWidget);
    expect(find.text('Changing an entry that’s waiting'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    // The entry on the screen isn't also counted as waiting.
    expect(
      find.text('₮61,500.00 left now · ₮53,500.00 after this'),
      findsOneWidget,
    );
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const ValueKey('pad-<')));
    }
    await _type(tester, '9500');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    // The same entry, so the computer never gets both.
    expect(store.waiting.single.id, first.id);
    expect(store.waiting.single.amountMinor, -950000);
    expect(find.text('Saved · UB Cab −₮9,500.00'), findsOneWidget);
    expect(find.text('Changing an entry that’s waiting'), findsNothing);

    // Undo brings the first back, and the fix to go on with.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(store.waiting.single.amountMinor, -800000);
    expect(find.text('−₮9,500'), findsOneWidget);
    expect(find.text('Changing an entry that’s waiting'), findsOneWidget);
    // Cancel leaves the waiting entry as it was.
    await tester.tap(find.byKey(const ValueKey('clear')));
    await tester.pumpAndSettle();
    expect(store.waiting.single.amountMinor, -800000);
    expect(find.text('−₮0'), findsOneWidget);
    expect(find.text('Changing an entry that’s waiting'), findsNothing);
  });

  testWidgets('an entry in the phone’s ledger that no computer has applied is '
      'on the same list, and Save puts the fix in its place (#526 piece 4)', (
    tester,
  ) async {
    final store = await _pump(tester);
    await _spend(tester, 'Transport', '8000', 'ub', pick: 'UB Cab');
    final first = store.waiting.single;
    // The ledger took it in; no computer has applied it yet.
    final row = first.withId('${phoneRowPrefix}7');
    PhoneSnapshot with_(List<PhoneEntry> mine) => PhoneSnapshot(
      madeAt: store.snapshot.madeAt,
      accounts: store.snapshot.accounts,
      categories: store.snapshot.categories,
      taken: {
        store.device: PhoneTaken(entries: {first.id}),
      },
      mine: mine,
    );
    final undone = <PhoneTake>[];
    store.undoTake = (t) async {
      undone.add(t);
      return with_(const []);
    };
    store.snapshot = with_([row]);
    await tester.pump();
    expect(store.waiting, isEmpty);
    expect(store.nothingOnTheWay, isFalse);

    await tester.tap(find.byKey(const ValueKey('waiting-link')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('waiting-${row.id}')));
    await tester.pumpAndSettle();
    expect(find.text('−₮8,000'), findsOneWidget);
    expect(find.text('Changing an entry that’s waiting'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const ValueKey('pad-<')));
    }
    await _type(tester, '9500');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    // The old row went out of the ledger, the fix is a new entry.
    expect(undone.single.transactionIds, [7]);
    expect(store.waiting.single.amountMinor, -950000);
    expect(store.waiting.single.id, isNot(row.id));
    expect(find.text('Saved · UB Cab −₮9,500.00'), findsOneWidget);

    // Undo takes the fix out and brings the first back as an entry.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(store.waiting.single.amountMinor, -800000);
    expect(find.text('−₮9,500'), findsOneWidget);
  });

  testWidgets('a waiting split opens with its lines, a return among them', (
    tester,
  ) async {
    final store = await _pump(tester);
    store.add(
      PhoneEntry(
        id: 's1',
        categoryId: phoneSplitId,
        accountId: 'tdb',
        payee: 'Nomin',
        amountMinor: -1250000,
        date: DateTime(2026, 10, 6),
        madeAt: _now,
        lines: const [
          (categoryId: 'groceries', amountMinor: -5000000),
          (categoryId: 'clothing', amountMinor: 3750000),
        ],
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('waiting-link')));
    await tester.pumpAndSettle();
    // The return says its sign.
    expect(
      find.textContaining('Groceries ₮50,000 · Clothing +₮37,500'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('waiting-s1')));
    await tester.pumpAndSettle();
    expect(find.text('−₮12,500'), findsOneWidget);
    expect(find.text('2 categories'), findsOneWidget);
    expect(find.text('Groceries ₮50,000 · Clothing +₮37,500'), findsOneWidget);
    expect(find.text('TDB Checking'), findsOneWidget);

    // Its split page has the lines, the return marked.
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    expect(find.text('+₮37,500'), findsOneWidget);
    expect(find.byKey(const ValueKey('split-left')), findsNothing);
    // Groceries, the line the pad types into, 52,500 now: the receipt is
    // 15,000.
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const ValueKey('pad-<')));
    }
    await _type(tester, '52500');
    await tester.pumpAndSettle();
    expect(find.text('₮2,500 too much'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('split-done')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const ValueKey('pad-<')));
    }
    await _type(tester, '15000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final fixed = store.waiting.single;
    expect(fixed.id, 's1');
    expect(fixed.amountMinor, -1500000);
    expect(fixed.date, DateTime(2026, 10, 6));
    expect(fixed.lines, [
      (categoryId: 'groceries', amountMinor: -5250000),
      (categoryId: 'clothing', amountMinor: 3750000),
    ]);
  });

  testWidgets('a fix the computer took in meanwhile is saved as a new '
      'entry, and says so', (tester) async {
    final store = await _pump(tester);
    await _spend(tester, 'Transport', '8000', 'ub', pick: 'UB Cab');
    final first = store.waiting.single;
    await tester.tap(find.byKey(const ValueKey('waiting-link')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('waiting-${first.id}')));
    await tester.pumpAndSettle();
    await _type(tester, '0');

    // The computer takes the first one in while it is being fixed.
    final s = store.snapshot;
    store.snapshot = PhoneSnapshot(
      madeAt: s.madeAt,
      categories: s.categories,
      accounts: s.accounts,
      periodEnd: s.periodEnd,
      payees: s.payees,
      taken: {
        store.device: PhoneTaken(entries: {first.id}),
      },
    );
    await tester.pumpAndSettle();
    expect(store.waiting, isEmpty);
    expect(
      find.text(
        'Your computer has taken this entry in. Save will add it as a new one.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    // Nothing typed is lost.
    final again = store.waiting.single;
    expect(again.id, isNot(first.id));
    expect(again.amountMinor, -8000000);
    expect(again.payee, 'UB Cab');
    expect(
      find.text(
        'Your computer had already taken in the first one, so this is saved '
        'as a new entry. Fix or delete the first one on your computer.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('opening a waiting entry while one is typed asks first', (
    tester,
  ) async {
    final store = await _pump(tester);
    await _spend(tester, 'Transport', '8000', 'ub', pick: 'UB Cab');
    await _type(tester, '500');
    await tester.tap(find.byKey(const ValueKey('waiting-link')));
    await tester.pumpAndSettle();
    final row = find.byKey(ValueKey('waiting-${store.waiting.single.id}'));
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Open this entry? What you’ve typed on the entry screen will be '
        'cleared.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Not on your computer yet'), findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('−₮8,000'), findsOneWidget);
  });

  testWidgets('a return on the same receipt: a line marked Returned counts '
      'the other way', (tester) async {
    final store = await _pump(tester);
    Color? colorOf(Finder f) => tester.widget<Text>(f).style?.color;
    await _type(tester, '12500');
    // Money out is ordinary ink with its minus (owner's correction).
    expect(colorOf(find.text('−₮12,500')), Mid.ink);
    await _payee(tester, 'Nomin');
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('split-option')));
    await tester.pumpAndSettle();
    await tester.tap(_inMenu('Groceries'));
    await tester.pumpAndSettle();
    await _type(tester, '50000');
    await tester.pumpAndSettle();
    expect(colorOf(find.byKey(const ValueKey('split-total'))), Mid.ink);
    expect(find.text('₮37,500 too much'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('split-another')));
    await tester.pumpAndSettle();
    await tester.tap(_inMenu('Clothing'));
    await tester.pumpAndSettle();
    await _type(tester, '37500');
    await tester.pumpAndSettle();
    // Offered on the line being typed only.
    expect(find.text('Returned'), findsOneWidget);
    await tester.tap(find.text('Returned'));
    await tester.pumpAndSettle();
    expect(find.text('+₮37,500'), findsOneWidget);
    expect(find.byKey(const ValueKey('split-left')), findsNothing);
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_split_return.png'),
    );
    await tester.tap(find.byKey(const ValueKey('split-done')));
    await tester.pumpAndSettle();
    expect(find.text('Groceries ₮50,000 · Clothing +₮37,500'), findsOneWidget);
    await _account(tester, 'TDB Checking');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final entry = store.waiting.single;
    expect(entry.amountMinor, -1250000);
    expect(entry.lines, [
      (categoryId: 'groceries', amountMinor: -5000000),
      (categoryId: 'clothing', amountMinor: 3750000),
    ]);
    // The shirt's money is back in Clothing.
    expect(find.text('Groceries · ₮98,000.00 left'), findsOneWidget);
    expect(find.text('Clothing · ₮117,500.00 left'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('waiting-link')));
    await tester.pumpAndSettle();
    expect(colorOf(find.text('−₮12,500.00')), Mid.ink);
  });

  testWidgets('returns that come to more than was bought make the receipt '
      'money in', (tester) async {
    final store = await _pump(tester);
    await _payee(tester, 'Nomin');
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('split-option')));
    await tester.pumpAndSettle();
    await tester.tap(_inMenu('Groceries'));
    await tester.pumpAndSettle();
    await _type(tester, '37500');
    await tester.tap(find.byKey(const ValueKey('split-another')));
    await tester.pumpAndSettle();
    await tester.tap(_inMenu('Clothing'));
    await tester.pumpAndSettle();
    await _type(tester, '50000');
    await tester.tap(find.text('Returned'));
    await tester.pumpAndSettle();
    expect(find.text('+₮12,500'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('split-done')));
    await tester.pumpAndSettle();
    expect(find.text('+₮12,500'), findsOneWidget);
    expect(find.text('Paid into'), findsOneWidget);
    // Each line still goes the way it was marked.
    expect(find.text('Groceries −₮37,500 · Clothing ₮50,000'), findsOneWidget);
    await _account(tester, 'TDB Checking');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final entry = store.waiting.single;
    expect(entry.amountMinor, 1250000);
    expect(entry.lines, [
      (categoryId: 'groceries', amountMinor: -3750000),
      (categoryId: 'clothing', amountMinor: 5000000),
    ]);
  });

  testWidgets('after a split only the overspent category’s line is red', (
    tester,
  ) async {
    await _pump(tester);
    await _type(tester, '2000');
    await _payee(tester, 'Nomin');
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('split-option')));
    await tester.pumpAndSettle();
    await tester.tap(_inMenu('Groceries'));
    await tester.pumpAndSettle();
    await _type(tester, '1000');
    await tester.tap(find.byKey(const ValueKey('split-another')));
    await tester.pumpAndSettle();
    await tester.tap(_inMenu('Eating out'));
    await tester.pumpAndSettle();
    await _type(tester, '1000');
    await tester.tap(find.byKey(const ValueKey('split-done')));
    await tester.pumpAndSettle();
    await _account(tester, 'TDB Checking');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    Color? colorOf(String text) =>
        tester.widget<Text>(find.text(text)).style?.color;
    expect(colorOf('Saved · Nomin −₮2,000.00'), isNot(Mid.coral));
    expect(colorOf('Groceries · ₮147,000.00 left'), Mid.ink2);
    expect(colorOf('Eating out · overspent by ₮19,400.00'), Mid.coral);
  });

  testWidgets('a second tap on the category just picked doesn’t land on '
      'what was under the list', (tester) async {
    await _pump(tester);
    await _category(tester, 'Groceries');
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    final at = tester.getCenter(_inMenu('Groceries'));
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.tapAt(at);
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Groceries'), findsOneWidget);
    // Tapping the chosen row again while the list is open only closes it.
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    expect(find.text('Groceries'), findsOneWidget);

    // On the split page the list doesn't open again under the second tap.
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('split-option')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('split-line-0')));
    await tester.pumpAndSettle();
    final line = tester.getCenter(_inMenu('Groceries'));
    await tester.tapAt(line);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.tapAt(line);
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    expect(find.text('Groceries'), findsOneWidget);
  });

  testWidgets('a waiting entry can be deleted, and Left goes back', (
    tester,
  ) async {
    final store = await _pump(tester);
    await _spend(tester, 'Transport', '8000', 'ub', pick: 'UB Cab');
    await _toBudget(tester);
    expect(find.text('₮53,500.00'), findsOneWidget);
    await _toLedger(tester);

    await tester.tap(find.text('1 entry isn’t on your computer yet'));
    await tester.pumpAndSettle();
    expect(find.text('UB Cab'), findsOneWidget);
    expect(find.text('−₮8,000.00'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(store.waiting, isEmpty);
  });

  testWidgets('Accounts lists balances, a card as Owed', (tester) async {
    await _pump(tester);
    await _toBudget(tester);
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    expect(find.text('₮2,431,800.00'), findsOneWidget);
    expect(find.text('Owed ₮312,000.00'), findsOneWidget);
  });

  group('counting cash (#119)', () {
    Future<void> openCount(WidgetTester tester) async {
      await _toBudget(tester);
      await tester.tap(find.text('Accounts'));
      await tester.pumpAndSettle();
      // Only the cash account is counted.
      expect(find.byKey(const ValueKey('count-tdb')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('count-cash')));
      await tester.pumpAndSettle();
    }

    Future<void> type(WidgetTester tester, String digits) async {
      for (final d in digits.split('')) {
        await tester.tap(find.byKey(ValueKey('pad-$d')));
        await tester.pump();
      }
    }

    testWidgets('the count says the rows and the difference, and waits', (
      tester,
    ) async {
      final store = await _pump(tester);
      await openCount(tester);
      expect(find.text('The rows say ₮86,000.'), findsOneWidget);
      // Nothing counted, nothing saved: it says what's missing.
      await tester.tap(find.byKey(const ValueKey('count-save')));
      await tester.pump();
      expect(find.text('Type how much cash you counted'), findsOneWidget);
      expect(store.counts, isEmpty);

      await type(tester, '50000');
      expect(
        find.text('The rows say ₮86,000. You counted ₮50,000.'),
        findsOneWidget,
      );
      expect(find.text('₮36,000 less than the rows'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/phone_count.png'),
      );
      expect(
        find.text('Put −₮36,000 in Not categorized and save the count'),
        findsOneWidget,
      );

      // The difference can go to a category the person picks.
      await tester.tap(find.byKey(const ValueKey('count-category')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('new-category')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('menu-groceries')).last);
      await tester.pumpAndSettle();
      expect(
        find.text('Put −₮36,000 in Groceries and save the count'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('count-save')));
      await tester.pumpAndSettle();
      final count = store.counts.single;
      expect(count.accountId, 'cash');
      expect(count.countedMinor, 5000000);
      expect(count.categoryId, 'groceries');
      expect(count.date, DateTime(2026, 10, 7));
      expect(
        find.text('Cash wallet counted · −₮36,000 to Groceries'),
        findsOneWidget,
      );
      // The wallet holds what was counted now.
      expect(find.text('₮50,000.00'), findsOneWidget);

      // Undo takes it back.
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(store.counts, isEmpty);
      expect(find.text('₮86,000.00'), findsOneWidget);
    });

    test('a count measures the rows through its day, as the computer\'s '
        'does: a row dated ahead isn\'t in the wallet yet', () {
      final wallet = PhoneAccount(
        id: 'cash',
        name: 'Cash wallet',
        balanceMinor: 6000000,
        cash: true,
        ahead: [(date: DateTime(2026, 10, 9), amountMinor: -2000000)],
      );
      PhoneEntry typed(String id, DateTime date) => PhoneEntry(
        id: id,
        categoryId: 'groceries',
        accountId: 'cash',
        payee: 'Market',
        amountMinor: -500000,
        date: date,
        madeAt: _now,
      );
      final waiting = [
        typed('today', DateTime(2026, 10, 7)),
        typed('ahead', DateTime(2026, 10, 12)),
      ];
      // The balance shown has every row; the count leaves out the 9th's
      // and the 12th's.
      expect(balanceNow(wallet, waiting), 5000000);
      expect(
        balanceNow(wallet, waiting, const [], DateTime(2026, 10, 7)),
        7500000,
      );
      // Once the 9th has come, its row is in.
      expect(
        balanceNow(wallet, waiting, const [], DateTime(2026, 10, 9)),
        5500000,
      );
    });

    testWidgets('a count waits with the entries, and can be deleted', (
      tester,
    ) async {
      final store = await _pump(tester);
      store.addCount(
        PhoneCount(
          id: 'count-1',
          accountId: 'cash',
          countedMinor: 8600000,
          date: DateTime(2026, 10, 7),
          madeAt: _now,
          heldMinor: 8600000,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 entry isn’t on your computer yet'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('waiting-link')));
      await tester.pumpAndSettle();
      expect(find.text('Cash wallet counted'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('waiting-count-1')),
          matching: find.text('Delete'),
        ),
      );
      await tester.pumpAndSettle();
      expect(store.counts, isEmpty);
    });

    test('a balance holds the count, then what was typed after it', () {
      const wallet = PhoneAccount(
        id: 'cash',
        name: 'Cash wallet',
        balanceMinor: 100,
        cash: true,
      );
      PhoneEntry spent(int minute, int amount) => PhoneEntry(
        id: 'e$minute',
        categoryId: 'groceries',
        accountId: 'cash',
        payee: 'Market',
        amountMinor: amount,
        date: DateTime(2026, 10, 7),
        madeAt: DateTime(2026, 10, 7, 9, minute),
      );
      // Counted 60 when the phone said 80: 20 missing.
      final count = PhoneCount(
        id: 'c',
        accountId: 'cash',
        countedMinor: 60,
        date: DateTime(2026, 10, 7),
        madeAt: DateTime(2026, 10, 7, 9, 30),
        heldMinor: 80,
      );
      expect(balanceNow(wallet, [spent(10, -20)]), 80);
      expect(balanceNow(wallet, [spent(10, -20), spent(40, -5)], [count]), 55);
      // A newer copy arrives with the purchase before the count in it (an
      // older computer took it): still counted, not frozen.
      const newer = PhoneAccount(
        id: 'cash',
        name: 'Cash wallet',
        balanceMinor: 80,
        cash: true,
      );
      expect(balanceNow(newer, [spent(40, -5)], [count]), 55);
    });

    test('what is typed after a count waits on the phone until the count '
        'is taken; an earlier day\'s purchase goes with it', () {
      PhoneEntry typed(
        String id,
        int minute, {
        int day = 7,
        String at = 'cash',
      }) => PhoneEntry(
        id: id,
        categoryId: 'groceries',
        accountId: at,
        payee: 'Market',
        amountMinor: -100,
        date: DateTime(2026, 10, day),
        madeAt: DateTime(2026, 10, 7, 9, minute),
      );
      PhoneCount count(String id, int minute, {String at = 'cash'}) =>
          PhoneCount(
            id: id,
            accountId: at,
            countedMinor: 0,
            date: DateTime(2026, 10, 7),
            madeAt: DateTime(2026, 10, 7, 9, minute),
            heldMinor: 0,
          );
      final inbox = PhoneInbox(
        device: 'ab12',
        entries: [
          typed('before', 10),
          typed('lunch', 40),
          typed('sunday', 50, day: 6),
          typed('card', 45, at: 'tdb'),
        ],
        counts: [count('first', 30), count('second', 60)],
      );
      final send = sendingOf(inbox, (id) => id == 'cash');
      expect(send.entries.map((e) => e.id), ['before', 'sunday', 'card']);
      expect(send.counts.map((c) => c.id), ['first']);
      // A count the computer won't take holds nothing back.
      expect(identical(sendingOf(inbox, (_) => false), inbox), isTrue);
    });
  });

  testWidgets('+/− makes a return money in, and Save puts it back in its '
      'category', (tester) async {
    final store = await _pump(tester);
    Color? amountColor(String text) =>
        tester.widget<Text>(find.text(text)).style?.color;

    // Money out until the button beside the amount is tapped.
    await tester.tap(find.byKey(const ValueKey('sign')));
    await tester.pump();
    expect(find.text('+₮0'), findsOneWidget);
    expect(find.text('Paid into'), findsOneWidget);
    expect(find.text('Paid from'), findsNothing);
    // And back.
    await tester.tap(find.byKey(const ValueKey('sign')));
    await tester.pump();
    expect(find.text('−₮0'), findsOneWidget);
    expect(find.text('Paid from'), findsOneWidget);
    expect(find.text('Clear'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('sign')));
    await tester.pump();
    // Clear takes money in back too.
    expect(find.text('Clear'), findsOneWidget);
    await _category(tester, 'Groceries');
    await _type(tester, '12500');
    expect(amountColor('+₮12,500'), Mid.green);
    // A refund puts money back in the category.
    expect(
      find.text('₮148,000.00 left now · ₮160,500.00 after this'),
      findsOneWidget,
    );
    await _payee(tester, 'Walmart');
    await _account(tester, 'TDB Checking');
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_money_in.png'),
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final entry = store.waiting.single;
    expect(entry.amountMinor, 1250000);
    expect(entry.categoryId, 'groceries');
    expect(entry.accountId, 'tdb');
    expect(find.text('Saved · Walmart +₮12,500.00'), findsOneWidget);
    expect(find.text('Groceries · ₮160,500.00 left'), findsOneWidget);
    // The next entry is money out again: a refund isn't carried over.
    expect(find.text('−₮0'), findsOneWidget);
    expect(find.text('Paid from'), findsOneWidget);

    // Undo brings it back as money in.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(store.waiting, isEmpty);
    expect(find.text('+₮12,500'), findsOneWidget);
    expect(find.text('Paid into'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // The account has it, and the waiting list shows it as money in.
    expect(balanceNow(store.snapshot.accounts.first, store.waiting), 244430000);
    await tester.tap(find.byKey(const ValueKey('waiting-link')));
    await tester.pumpAndSettle();
    expect(amountColor('+₮12,500.00'), Mid.green);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _toBudget(tester);
    expect(find.text('₮160,500.00'), findsOneWidget);
  });

  testWidgets('an account picked in the Category list makes a transfer: '
      'cash from an ATM, and a card paid', (tester) async {
    final store = await _pump(tester);
    PhoneAccount account(String id) =>
        store.snapshot.accounts.singleWhere((a) => a.id == id);
    Future<void> to(String name) async {
      // The accounts are the dropdown's last rows.
      await _category(tester, name);
    }

    // The accounts are at the foot of the Category list, under a heading.
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_inMenu('→ Golomt Visa'));
    await tester.pumpAndSettle();
    expect(find.text('Move to an account'), findsOneWidget);
    expect(find.text('→ Cash wallet'), findsOneWidget);
    expect(find.text('Owed ₮312,000.00'), findsOneWidget);
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_transfer_list.png'),
    );
    await tester.tap(find.text('→ Cash wallet'));
    await tester.pumpAndSettle();

    // No payee to ask for, no sign to turn, and the account row reads From.
    expect(find.byKey(const ValueKey('payee-row')), findsNothing);
    expect(find.byKey(const ValueKey('sign')), findsNothing);
    expect(find.text('→ Cash wallet'), findsOneWidget);
    expect(find.text('From'), findsOneWidget);
    expect(find.text('Paid from'), findsNothing);
    await _type(tester, '100000');
    expect(find.text('₮100,000'), findsOneWidget);
    expect(tester.widget<Text>(find.text('₮100,000')).style?.color, Mid.ink);
    // Nothing is said until the account it leaves is known.
    expect(find.byKey(const ValueKey('left-line')), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Choose an account'), findsOneWidget);
    // The account it goes to isn't offered to take it from.
    await tester.tap(find.byKey(const ValueKey('account-row')));
    await tester.pumpAndSettle();
    expect(find.text('Cash wallet'), findsNothing);
    await tester.tap(find.text('TDB Checking'));
    await tester.pumpAndSettle();
    expect(
      find.text('TDB Checking · ₮2,331,800.00 after this'),
      findsOneWidget,
    );
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_transfer.png'),
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final atm = store.waiting.single;
    expect(atm.categoryId, 'cash');
    expect(atm.accountId, 'tdb');
    expect(atm.amountMinor, -10000000);
    expect(atm.payee, '');
    expect(
      find.text('Saved · TDB Checking → Cash wallet ₮100,000.00'),
      findsOneWidget,
    );
    expect(find.text('Cash wallet · ₮186,000.00 now'), findsOneWidget);
    expect(balanceNow(account('tdb'), store.waiting), 233180000);
    expect(balanceNow(account('cash'), store.waiting), 18600000);
    // The next entry is spending again, with its payee row.
    expect(find.byKey(const ValueKey('payee-row')), findsOneWidget);
    expect(find.text('−₮0'), findsOneWidget);

    // Undo brings the transfer back as it was typed.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(store.waiting, isEmpty);
    expect(find.text('→ Cash wallet'), findsOneWidget);
    expect(find.text('₮100,000'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // A card paid: what is owed on it goes down.
    await _account(tester, 'TDB Checking');
    await to('→ Golomt Visa');
    await _type(tester, '200000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Saved · TDB Checking → Golomt Visa ₮200,000.00'),
      findsOneWidget,
    );
    expect(find.text('Golomt Visa · ₮112,000.00 owed now'), findsOneWidget);
    expect(balanceNow(account('visa'), store.waiting), 11200000);

    // The waiting list names a transfer by its two accounts, in plain ink.
    await tester.tap(find.byKey(const ValueKey('waiting-link')));
    await tester.pumpAndSettle();
    expect(find.text('TDB Checking → Cash wallet'), findsOneWidget);
    expect(find.text('Transfer · 2026.10.07'), findsNWidgets(2));
    expect(tester.widget<Text>(find.text('₮100,000.00')).style?.color, Mid.ink);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // With an account already chosen, it isn't in the list to move to; and
    // money in is never a transfer.
    await _account(tester, 'Cash wallet');
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    expect(_inMenu('→ Golomt Visa'), findsOneWidget);
    expect(_inMenu('→ Cash wallet'), findsNothing);
    expect(_inMenu('→ TDB Checking'), findsOneWidget);
    await _closeMenu(tester);
    await tester.tap(find.byKey(const ValueKey('sign')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    expect(_inMenu('Move to an account'), findsNothing);
    expect(find.text('Move to an account'), findsNothing);
    await _closeMenu(tester);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    // A payee typed before the transfer was picked isn't kept out of sight.
    await _payee(tester, 'Nomin');
    await to('→ Cash wallet');
    await _category(tester, 'Groceries');
    expect(find.text('Nomin'), findsNothing);
    expect(find.byKey(const ValueKey('payee-row')), findsOneWidget);
  });

  testWidgets('an account with no other in its currency is not offered to '
      'move money to', (tester) async {
    final base = previewSnapshot(DateTime(2026, 10, 7, 8, 10));
    await _pump(
      tester,
      snapshot: PhoneSnapshot(
        madeAt: base.madeAt,
        categories: base.categories,
        accounts: [
          ...base.accounts.take(2),
          const PhoneAccount(
            id: 'usd',
            name: 'Dollars',
            balanceMinor: 50000,
            currency: Currency.usd,
          ),
        ],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('→ Cash wallet'), findsOneWidget);
    expect(find.text('→ Dollars'), findsNothing);
  });

  testWidgets('a refund to an overspent category says what it leaves', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('sign')));
    await _category(tester, 'Eating out');
    await _type(tester, '10000');
    expect(
      find.text('Overspent by ₮18,400.00 · by ₮8,400.00 after this'),
      findsOneWidget,
    );
    await _type(tester, '0');
    final line = tester.widget<Text>(find.byKey(const ValueKey('left-line')));
    expect(line.data, 'Overspent by ₮18,400.00 · ₮81,600.00 left after this');
    // No longer overspent once this is in, so not in red.
    expect(line.style?.color, Mid.ink2);
  });

  testWidgets('Income is offered for money in and never for money out', (
    tester,
  ) async {
    final store = await _pump(tester);
    // Money out: Income isn't in the list, and its name can't be made
    // into a category of their own.
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    expect(find.text('Income'), findsNothing);
    await _closeMenu(tester);

    // Money in: Income is the list's first line, with no figure beside it.
    await tester.tap(find.byKey(const ValueKey('sign')));
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(_inMenu('Income')).dy,
      lessThan(tester.getTopLeft(_inMenu('Groceries')).dy),
    );
    await tester.tap(_inMenu('Income'));
    await tester.pumpAndSettle();
    await _type(tester, '50000');
    // Income holds no budget: nothing is said about what is left.
    expect(find.byKey(const ValueKey('left-line')), findsNothing);
    await _payee(tester, 'Bat');
    await _account(tester, 'Cash wallet');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final entry = store.waiting.single;
    expect(entry.categoryId, phoneIncomeId);
    expect(entry.accountId, 'cash');
    expect(entry.amountMinor, 5000000);
    expect(find.text('Saved · Bat +₮50,000.00'), findsOneWidget);
    expect(find.textContaining('Income ·'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('waiting-link')));
    await tester.pumpAndSettle();
    expect(find.text('Income · 2026.10.07'), findsOneWidget);
    expect(find.text('+₮50,000.00'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Chosen, then the entry is turned back to money out: Income goes.
    await tester.tap(find.byKey(const ValueKey('sign')));
    await _category(tester, 'Income');
    expect(find.text('Income'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sign')));
    await tester.pump();
    expect(find.text('Income'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter an amount'), findsOneWidget);

    // Nor does Budget make a category called that.
    await _toBudget(tester);
    await tester.tap(find.byKey(const ValueKey('budget-new-category')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('new-category-name')),
      'Income',
    );
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(find.text('Income is already a category'), findsOneWidget);
    expect(store.made, isEmpty);
  });

  testWidgets('each pay is offered by name for money in, into its own '
      'account (#187)', (tester) async {
    final store = await _pump(
      tester,
      snapshot: PhoneSnapshot(
        madeAt: DateTime(2026, 10, 7, 8, 10),
        accounts: const [
          PhoneAccount(id: 'khan', name: 'Khan', balanceMinor: 0),
          PhoneAccount(id: 'golomt', name: 'Golomt', balanceMinor: 0),
        ],
        pays: [
          PhonePay(
            id: phonePayId(4),
            accountId: 'khan',
            name: 'Loveland Solutions',
          ),
        ],
        categories: const [
          PhoneCategory(id: 'g', name: 'Groceries', leftMinor: 14800000),
        ],
      ),
    );
    const named = 'Income · Loveland Solutions';
    await _account(tester, 'Golomt');
    // Money out: no pay.
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    expect(find.text(named), findsNothing);
    await _closeMenu(tester);

    // Money in: under Income, above the categories.
    await tester.tap(find.byKey(const ValueKey('sign')));
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(_inMenu('Income')).dy,
      lessThan(tester.getTopLeft(_inMenu(named)).dy),
    );
    expect(
      tester.getTopLeft(_inMenu(named)).dy,
      lessThan(tester.getTopLeft(_inMenu('Groceries')).dy),
    );
    await tester.tap(_inMenu(named));
    await tester.pumpAndSettle();
    // The pay goes into Khan: the only account it can come into.
    expect(find.text('Khan'), findsOneWidget);
    expect(find.text('Golomt'), findsNothing);
    await _type(tester, '2050000');
    await _payee(tester, 'Loveland Solutions');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final entry = store.waiting.single;
    expect(entry.categoryId, phonePayId(4));
    expect(entry.accountId, 'khan');
    expect(entry.amountMinor, 205000000);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('waiting-link')));
    await tester.pumpAndSettle();
    expect(find.text('$named · 2026.10.07'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Turned to money out, the pay goes, as Income does.
    await tester.tap(find.byKey(const ValueKey('sign')));
    await _category(tester, named);
    await tester.tap(find.byKey(const ValueKey('sign')));
    await tester.pump();
    expect(find.text(named), findsNothing);

    // Split from a pay: its share is plain Income, since only a whole
    // paycheck stands in for its payday.
    await tester.tap(find.byKey(const ValueKey('sign')));
    await _category(tester, named);
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('split-option')));
    await tester.pumpAndSettle();
    expect(find.text('Income'), findsWidgets);
    expect(find.text(named), findsNothing);
  });

  testWidgets('an account a category rules out is let go, and Income takes '
      'the currency of the account it is paid into', (tester) async {
    final dollars = Currency.fromCode('USD');
    final store = await _pump(
      tester,
      snapshot: PhoneSnapshot(
        madeAt: DateTime(2026, 10, 7, 8, 10),
        accounts: [
          const PhoneAccount(id: 'khan', name: 'Khan', balanceMinor: 0),
          const PhoneAccount(id: 'golomt', name: 'Golomt', balanceMinor: 0),
          PhoneAccount(
            id: 'usd',
            name: 'Dollar',
            balanceMinor: 0,
            currency: dollars,
          ),
        ],
        categories: const [
          PhoneCategory(id: 'g', name: 'Groceries', leftMinor: 14800000),
        ],
      ),
    );
    await _account(tester, 'Dollar');
    await _type(tester, '500');
    expect(find.text(r'−$500'), findsOneWidget);
    // Groceries is in tugrik: the dollar account can't pay for it, so
    // Paid from is empty again.
    await _category(tester, 'Groceries');
    expect(find.text('−₮500'), findsOneWidget);
    expect(find.text('Dollar'), findsNothing);
    // And it doesn't come back by itself once Income would allow it.
    await tester.tap(find.byKey(const ValueKey('sign')));
    await _category(tester, 'Income');
    expect(find.text('+₮500'), findsOneWidget);
    expect(find.text('Dollar'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter a payee'), findsOneWidget);

    // Chosen by hand, the income is in that account's currency.
    await _account(tester, 'Dollar');
    expect(find.text(r'+$500'), findsOneWidget);
    await _payee(tester, 'Bat');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final entry = store.waiting.single;
    expect(entry.categoryId, phoneIncomeId);
    expect(entry.accountId, 'usd');
    expect(entry.amountMinor, 50000);
    expect(find.text(r'Saved · Bat +$500.00'), findsOneWidget);

    // Undo brings an income entry back whole.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(store.waiting, isEmpty);
    expect(find.text(r'+$500'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Dollar'), findsOneWidget);
    expect(find.text('Paid into'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('waiting-link')));
    await tester.pumpAndSettle();
    expect(find.text(r'+$500.00'), findsOneWidget);
  });

  testWidgets('deleting a category made here says what was spent in it, '
      'less what came back', (tester) async {
    final store = await _pump(tester);
    await _newCategory(tester, 'Coffee');
    await _account(tester, 'Cash wallet');
    await _type(tester, '4500');
    await _payee(tester, 'Tom N Toms');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    // ₮1,500 of it comes back.
    await tester.tap(find.byKey(const ValueKey('sign')));
    await _category(tester, 'Coffee');
    await _account(tester, 'Cash wallet');
    await _type(tester, '1500');
    await _payee(tester, 'Tom N Toms');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.waiting, hasLength(2));

    await tester.tap(find.byKey(const ValueKey('waiting-link')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();
    expect(
      find.text('Delete Coffee and the 2 entries in it (₮3,000.00)?'),
      findsOneWidget,
    );
  });

  testWidgets('a category still waiting opens filled in, and Save changes '
      'it with its entries kept in it', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final day = DateTime(2026, 10, 7);
    final snapshot = previewSnapshot(DateTime(2026, 10, 7, 8, 10));
    final account = snapshot.accounts.firstWhere((a) => !a.owes);
    // ₮450,000 typed for ₮45,000 (#243).
    final store = PhoneStore(
      snapshot,
      made: [
        PhoneCategory(
          id: 'new-1',
          name: 'Mobicom',
          leftMinor: 0,
          currency: account.currency,
          madeHere: true,
          plan: CategoryPlan(
            categoryId: -1,
            kind: PlanKind.byDate,
            amount: 45000000,
            start: day,
            due: DateTime(2026, 10, 15),
            everyMonths: 1,
          ),
          due: DateTime(2026, 10, 15),
        ),
      ],
      waiting: [
        PhoneEntry(
          id: 'e1',
          categoryId: 'new-1',
          accountId: account.id,
          payee: 'Mobicom',
          amountMinor: -4500000,
          date: day,
          madeAt: day,
        ),
      ],
    );
    await tester.pumpWidget(PhoneApp(store: store, now: () => _now));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('waiting-link')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('waiting-category-new-1')));
    await tester.pumpAndSettle();
    expect(find.text('Edit Mobicom'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.byKey(const ValueKey('new-category-another')), findsNothing);
    // An entry is filed in it: its currency stays.
    expect(find.byKey(const ValueKey('money-currency')), findsNothing);
    // Its own name isn't "taken".
    expect(find.byKey(const ValueKey('new-category-note')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('plan-amount')), '45000');
    // Made on a phone before 0.62.0, it has no Paid from yet.
    await _paidFrom(tester);
    await tester.tap(find.byKey(const ValueKey('new-category-add')));
    await tester.pumpAndSettle();
    expect(find.text('Edit Mobicom'), findsNothing);
    final c = store.made.single;
    expect(c.id, 'new-1');
    expect(c.plan!.amount, 4500000);
    expect(c.plan!.due, DateTime(2026, 10, 15));
    expect(c.plan!.everyMonths, 1);
    expect(store.waiting.single.categoryId, 'new-1');

    // Taken in by the computer while the page is open: its own name isn't
    // called taken, and Save says it went.
    await tester.tap(find.byKey(const ValueKey('waiting-category-new-1')));
    await tester.pumpAndSettle();
    store.removeCategory('new-1');
    await tester.pump();
    expect(find.byKey(const ValueKey('new-category-note')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('new-category-add')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'The computer took in Mobicom while this was open, so these changes '
        'weren’t kept. Change it on the computer’s Budget page.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Mobicom'), findsNothing);
  });

  testWidgets('an overspent category is said in words, not with a minus', (
    tester,
  ) async {
    await _pump(tester);
    await _category(tester, 'Eating out');
    expect(find.text('Overspent by ₮18,400.00'), findsOneWidget);
    await _type(tester, '12500');
    expect(
      find.text('Overspent by ₮18,400.00 · by ₮30,900.00 after this'),
      findsOneWidget,
    );
    await tester.tap(find.text('Clear'));
    await tester.pump();

    // Money now, and this entry would go past it.
    await _category(tester, 'Transport');
    await _type(tester, '70000');
    expect(
      find.text('₮61,500.00 left now · overspent by ₮8,500.00 after this'),
      findsOneWidget,
    );
  });

  testWidgets('money waiting for a bill is listed apart, under Bills', (
    tester,
  ) async {
    await _pump(
      tester,
      snapshot: PhoneSnapshot(
        madeAt: DateTime(2026, 10, 7, 8, 10),
        periodEnd: DateTime(2026, 10, 14),
        accounts: const [
          PhoneAccount(id: 'a', name: 'TDB Checking', balanceMinor: 0),
        ],
        categories: [
          // First in the ledger's order, and still shown after the money
          // that is free to spend.
          PhoneCategory(
            id: 'r',
            name: 'Rent',
            leftMinor: 180000000,
            due: DateTime(2026, 10, 20),
          ),
          const PhoneCategory(
            id: 'g',
            name: 'Groceries',
            leftMinor: 14800000,
            hadMinor: 90000000,
          ),
        ],
      ),
    );
    await _toBudget(tester);
    // A budget that runs by pay periods says when this one ends.
    expect(find.text('Left until 10.14'), findsOneWidget);
    expect(find.text('Due 10.20'), findsOneWidget);
    // The ring before Groceries: ₮148,000 of ₮900,000 left, in gold since
    // some is spent (#465); a bill has none (#241).
    expect(find.byKey(const ValueKey('used-g')), findsOneWidget);
    final ring = tester.widget<UsedRing>(find.byKey(const ValueKey('used-g')));
    expect(ring.left, closeTo(14800000 / 90000000, 1e-9));
    expect(ring.over, isFalse);
    expect(usedColor(left: ring.left, over: ring.over), Mid.gold);
    expect(usedColor(left: 1, over: false), Mid.green);
    expect(usedColor(left: 0, over: false), Mid.gold);
    expect(usedColor(left: 0, over: true), Mid.coral);
    // Nothing had this period: no ring, spent from or not (#465).
    const bare = PhoneCategory(
      id: 'b',
      name: 'Bank fees',
      leftMinor: -40000,
      hadMinor: 0,
    );
    expect(usedShareNow(bare, -40000), isNull);
    // Over what it had: all of it used, and the ring whole and coral.
    const over = PhoneCategory(
      id: 'd',
      name: 'Dining out',
      leftMinor: -3000000,
      hadMinor: 20000000,
    );
    expect(usedShareNow(over, -3000000), 1);
    expect(over.overAt(-3000000), isTrue);
    expect(find.byKey(const ValueKey('used-r')), findsNothing);
    final groceries = tester.getTopLeft(find.text('Groceries')).dy;
    final add = tester.getTopLeft(find.text('+ New category')).dy;
    final heading = tester.getTopLeft(find.text('Bills')).dy;
    final rent = tester.getTopLeft(find.text('Rent')).dy;
    expect(groceries, lessThan(add));
    expect(add, lessThan(heading));
    expect(heading, lessThan(rent));
    // Both are green, money that is there (#327); a bill's is lighter.
    final spend = tester.widget<Text>(find.text('₮148,000.00')).style!;
    final bill = tester.widget<Text>(find.text('₮1,800,000.00')).style!;
    expect(spend.color, Mid.green);
    expect(bill.color, Mid.green);
    expect(bill.fontWeight, isNot(spend.fontWeight));

    // It can still be paid from here.
    await _addIn(tester, 'Rent');
    expect(find.text('₮1,800,000.00 left now'), findsOneWidget);
  });

  testWidgets('with one account there is nothing to choose: it is shown', (
    tester,
  ) async {
    final store = await _pump(
      tester,
      snapshot: PhoneSnapshot(
        madeAt: DateTime(2026, 10, 7, 8, 10),
        accounts: const [
          PhoneAccount(id: 'a', name: 'TDB Checking', balanceMinor: 0),
        ],
        categories: const [
          PhoneCategory(id: 'g', name: 'Groceries', leftMinor: 14800000),
        ],
      ),
    );
    expect(find.text('TDB Checking'), findsOneWidget);
    await _category(tester, 'Groceries');
    await _type(tester, '500');
    await _payee(tester, 'Nomin');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.waiting.single.accountId, 'a');
  });

  testWidgets('with no bills there is no Bills heading', (tester) async {
    await _pump(
      tester,
      snapshot: PhoneSnapshot(
        madeAt: DateTime(2026, 10, 7, 8, 10),
        accounts: const [
          PhoneAccount(id: 'a', name: 'TDB Checking', balanceMinor: 0),
        ],
        categories: const [
          PhoneCategory(id: 'g', name: 'Groceries', leftMinor: 14800000),
        ],
      ),
    );
    await _toBudget(tester);
    expect(find.byKey(const ValueKey('bills-heading')), findsNothing);
  });

  testWidgets('with no account to pay from, Save says so', (tester) async {
    final store = await _pump(
      tester,
      snapshot: PhoneSnapshot(
        madeAt: DateTime(2026, 10, 7, 8, 10),
        accounts: const [
          PhoneAccount(id: 'a', name: 'TDB Checking', balanceMinor: 0),
        ],
        categories: const [
          PhoneCategory(
            id: 't',
            name: 'Travel',
            leftMinor: 50000,
            currency: Currency.usd,
            recentPayees: ['Delta'],
          ),
        ],
      ),
    );
    await _category(tester, 'Travel');
    // The tugrik account isn't offered for a dollar category.
    expect(find.text('TDB Checking'), findsNothing);
    await _type(tester, '20');
    await _payee(tester, 'Delta');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Choose an account'), findsOneWidget);
    expect(store.waiting, isEmpty);
  });

  testWidgets('figures from an earlier day are marked, and Accounts counts '
      'what is waiting', (tester) async {
    await _pump(
      tester,
      snapshot: previewSnapshot(DateTime(2026, 10, 1, 21, 40)),
    );
    // ₮12,500 of groceries on TDB Checking, ₮30,000 of eating out on the Visa.
    await _spend(tester, 'Groceries', '12500', 'no', pick: 'Nomin');
    await _spend(
      tester,
      'Eating out',
      '30000',
      'Rosewood',
      from: 'Golomt Visa',
    );
    // Already overspent, and more so now: the card says by how much.
    expect(find.text('Eating out · overspent by ₮48,400.00'), findsOneWidget);

    await _toBudget(tester);
    final line = tester.widget<Text>(find.byKey(const ValueKey('from-mac')));
    expect(line.data, 'From your computer 2026.10.01 21:40');
    expect(line.style!.color, isNot(equals(null)));
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    expect(find.text('₮2,419,300.00'), findsOneWidget);
    expect(find.text('Owed ₮342,000.00'), findsOneWidget);
    expect(find.text('From your computer 2026.10.01 21:40'), findsOneWidget);
  });

  testWidgets('cents a category’s currency can’t hold are cut, and a saved '
      'line’s Undo goes once another entry is begun', (tester) async {
    final yen = Currency.fromCode('JPY');
    final store = await _pump(
      tester,
      snapshot: PhoneSnapshot(
        madeAt: DateTime(2026, 10, 7, 8, 10),
        accounts: [
          const PhoneAccount(
            id: 'u',
            name: 'Dollars',
            balanceMinor: 0,
            currency: Currency.usd,
          ),
          PhoneAccount(id: 'y', name: 'Yen', balanceMinor: 0, currency: yen),
        ],
        categories: [
          PhoneCategory(id: 't', name: 'Trip', leftMinor: 50000, currency: yen),
          const PhoneCategory(
            id: 'f',
            name: 'Food',
            leftMinor: 5000,
            currency: Currency.usd,
          ),
        ],
      ),
    );
    // Typed in dollars, then filed from Budget in a yen category.
    await _type(tester, '12.50');
    await _toBudget(tester);
    await _addIn(tester, 'Trip');
    expect(find.text('−¥12'), findsOneWidget);
    await _payee(tester, 'Lawson');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.waiting.single.amountMinor, -12);
    expect(find.text('Undo'), findsOneWidget);

    // The next entry is begun from Budget: Undo would write over it.
    await _toBudget(tester);
    await _addIn(tester, 'Food');
    expect(find.text('Undo'), findsNothing);
    expect(store.waiting, hasLength(1));
  });

  testWidgets('on a short phone the entry scrolls instead of running off', (
    tester,
  ) async {
    final store = await _pump(tester, size: const Size(360, 640));
    store.categoryCalled('Coffee', Currency.mnt);
    expect(tester.takeException(), isNull);
    await _category(tester, 'Groceries');
    await _payee(tester, 'no', pick: 'Nomin');
    await _account(tester, 'TDB Checking');
    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    await _type(tester, '12500');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(store.waiting.single.amountMinor, -1250000);
    await tester.ensureVisible(find.byKey(const ValueKey('waiting-link')));
    await tester.pumpAndSettle();
    expect(
      find.text('1 entry and 1 new category aren’t on your computer yet'),
      findsOneWidget,
    );
  });

  test('the category list fits what is typed, whatever its capitals', () {
    const all = [
      PhoneCategory(id: 'g', name: 'Groceries', leftMinor: 0),
      PhoneCategory(id: 'e', name: 'Eating out', leftMinor: 0),
      PhoneCategory(id: 'r', name: 'Rent', leftMinor: 0),
    ];
    expect(categoriesMatching(all, '  ').map((c) => c.id), ['g', 'e', 'r']);
    expect(categoriesMatching(all, 'R').map((c) => c.id), ['r', 'g']);
    expect(categoriesMatching(all, 'vet'), isEmpty);
    expect(categoryNamed(all, ' rent ')!.id, 'r');
    expect(categoryNamed(all, 'Ren'), isNull);
  });

  test('a card paid past what was owed is in credit', () {
    const visa = PhoneAccount(
      id: 'v',
      name: 'Visa',
      balanceMinor: -500000,
      owes: true,
    );
    expect(balanceNow(visa, const []), -500000);
    expect(
      balanceNow(visa, [
        PhoneEntry(
          id: 'a',
          categoryId: 'c',
          accountId: 'v',
          payee: 'x',
          amountMinor: -800000,
          date: _now,
          madeAt: _now,
        ),
      ]),
      300000,
    );
  });

  group('from the ledger', () {
    final today = DateTime(2026, 9, 16, 9, 30);

    test('a payee remembered on the Payees page fills its category on the '
        'account it holds on (owner, 2026-10-26)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, today);
      var data = await db.loadLedger();
      final checking = data.accounts.values.firstWhere(
        (a) => a.name == 'TDB Checking',
      );
      final groceries = data.categories.firstWhere(
        (c) => c.name == 'Groceries',
      );
      await db.addPayeeRule(
        name: 'Nomin',
        anywhere: false,
        categoryId: groceries.id,
        accountIds: {checking.id},
      );
      data = await db.loadLedger();
      await db.close();
      final snapshot = snapshotOf(data, today: today, madeAt: today);
      expect(
        snapshot.rememberedFor('Nomin Super', '${checking.id}')?.name,
        'Groceries',
      );
      // Another account, or a payee nobody remembered: nothing filled.
      final other = data.openAccounts.firstWhere((a) => a.id != checking.id);
      expect(snapshot.rememberedFor('Nomin', '${other.id}'), isNull);
      expect(snapshot.rememberedFor('Emart', '${checking.id}'), isNull);
    });

    test('a category’s group, note and month of its own reach the phone; '
        'a bill keeps no group (#100)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await seedDemoIfEmpty(db, today);
      var data = await db.loadLedger();
      int id(String name) =>
          data.categories.firstWhere((c) => c.name == name).id;
      final groceries = id('Groceries'), housing = id('Housing');
      await db.changeCategoryPlan(
        groceries,
        CategoryPlan(
          categoryId: groceries,
          kind: PlanKind.each,
          amount: 90000000,
          start: today,
          once: {DateTime(2026, 9): 0},
        ),
        today,
      );
      await db.changeCategoryPlan(
        housing,
        CategoryPlan(
          categoryId: housing,
          kind: PlanKind.byDate,
          amount: 180000000,
          start: today,
          due: DateTime(2026, 10, 1),
          everyMonths: 1,
        ),
        today,
      );
      await db.setCategoryDetails(groceries, group: 'Home', note: 'Market');
      await db.setCategoryDetails(housing, group: 'Home', note: null);
      data = await db.loadLedger();
      await db.close();
      final snapshot = snapshotOf(data, today: today, madeAt: today);
      PhoneCategory of(int id) =>
          snapshot.categories.firstWhere((c) => c.id == '$id');
      expect((of(groceries).group, of(groceries).note), ('Home', 'Market'));
      expect(
        (of(groceries).onceMinor, of(groceries).usualMinor),
        (0, 90000000),
      );
      // Under Bills, as on the computer.
      expect(of(housing).group, isNull);
      expect(of(housing).onceMinor, isNull);
    });

    test(
      'each category holds what the Budget page says, and a card is owed',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        await seedDemoIfEmpty(db, today);
        final data = await db.loadLedger();
        await db.close();
        final snapshot = snapshotOf(data, today: today, madeAt: today);
        final budget = Budget.of(
          data,
          start: DateTime(2026, 9),
          end: DateTime(2026, 9, 30),
          today: today,
        );
        expect(snapshot.categories, isNotEmpty);
        for (final c in snapshot.categories) {
          expect(
            c.leftMinor,
            budget.lines[int.parse(c.id)]!.left,
            reason: c.name,
          );
        }
        final groceries = snapshot.categories.singleWhere(
          (c) => c.name == 'Groceries',
        );
        expect(groceries.recentPayees, isNotEmpty);
        expect(
          snapshot.accounts.map((a) => a.id),
          contains(groceries.paidFromId),
        );
        final visa = snapshot.accounts.singleWhere(
          (a) => a.name == 'Golomt Visa',
        );
        expect(visa.owes, isTrue);
        expect(visa.balanceMinor, -data.balanceOf(int.parse(visa.id)));
        final checking = snapshot.accounts.singleWhere(
          (a) => a.name == 'TDB Checking',
        );
        expect(checking.balanceMinor, data.balanceOf(int.parse(checking.id)));
      },
    );
  });

  group('entries reach the computer', () {
    final today = DateTime(2026, 9, 16, 9, 30);

    PhoneEntry entry(String id, String category, String account, int amount) =>
        PhoneEntry(
          id: id,
          categoryId: category,
          accountId: account,
          payee: 'Nomin',
          amountMinor: amount,
          date: DateTime(2026, 9, 15),
          madeAt: today,
        );

    test('a phone’s file opens with the ledger’s key and no other', () {
      final dir = _phoneDir();
      final key = deriveDataKey(RecoveryKey.generate());
      final file = File('${dir.path}/${phoneInboxName('ab12')}');
      writePhoneInbox(
        file,
        key,
        PhoneInbox(
          device: 'ab12',
          entries: [entry('e1', '7', '3', -1250000)],
          categories: const [
            PhoneCategory(
              id: 'new-1',
              name: 'Coffee',
              leftMinor: 0,
              madeHere: true,
            ),
          ],
        ),
      );
      expect(isPhoneInboxName('Phone ab12.betterbudget-phone'), isTrue);
      expect(isPhoneInboxName(ledgerFileName), isFalse);
      // Nothing about the money is in the clear.
      expect(
        String.fromCharCodes(file.readAsBytesSync()),
        isNot(contains('Nomin')),
      );
      final back = readPhoneInbox(file, key);
      expect(back.device, 'ab12');
      expect(back.entries.single.amountMinor, -1250000);
      expect(back.entries.single.date, DateTime(2026, 9, 15));
      expect(back.categories.single.name, 'Coffee');
      expect(back.categories.single.madeHere, isTrue);
      expect(
        () => readPhoneInbox(file, deriveDataKey(RecoveryKey.generate())),
        throwsA(anything),
      );
    });

    test('a split travels with its lines; an older file has none', () {
      final dir = _phoneDir();
      final file = File('${dir.path}/${phoneInboxName('ab12')}');
      final split = PhoneEntry(
        id: 's1',
        categoryId: phoneSplitId,
        accountId: '3',
        payee: 'Nomin',
        amountMinor: -13550000,
        date: DateTime(2026, 9, 15),
        madeAt: today,
        lines: const [
          (categoryId: '7', amountMinor: -9800000),
          (categoryId: 'new-1', amountMinor: -3750000),
        ],
      );
      writePhoneInbox(
        file,
        null,
        PhoneInbox(device: 'ab12', entries: [split, entry('e1', '7', '3', -1)]),
      );
      final back = readPhoneInbox(file, null);
      expect(back.entries.first.lines, split.lines);
      expect(back.entries.last.lines, isEmpty);
      // A category made here, then taken in: the line follows it.
      expect(split.withCategory('new-1', '9').lines.last.categoryId, '9');

      // A file written before splits.
      final db = sqlite3.open(file.path);
      db.execute('DROP TABLE entry_lines');
      db.close();
      expect(readPhoneInbox(file, null).entries.first.lines, isEmpty);
    });

    test('money in filed under a pay on the phone is that pay\'s paycheck: '
        'its payday no longer expected; undo and redo (#187)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedDemoIfEmpty(db, today);
      var data = await db.loadLedger();
      final checking = data.accounts.values
          .singleWhere((a) => a.name == 'TDB Checking')
          .id;
      await db.savePaySchedule(
        accountId: checking,
        amount: 210000000,
        rule: PayRule.monthly,
        day1: 25,
        name: 'Loveland Solutions',
        today: today,
      );
      data = await db.loadLedger();
      final pay = data.paySchedules.single;
      // The phone offers it by name, into the account it goes into.
      final snapshot = snapshotOf(data, madeAt: today, today: today);
      expect(snapshot.pays.single.id, phonePayId(pay.id));
      expect(snapshot.pays.single.name, 'Loveland Solutions');
      expect(snapshot.pays.single.accountId, '$checking');
      Future<List<DateTime>> coming() async => [
        for (final r in (await db.loadLedger()).registerFor(checking).scheduled)
          if (r.payScheduleId == pay.id) r.date,
      ];
      expect(await coming(), [DateTime(2026, 9, 25)]);

      final take = (await db.takePhoneEntries([
        PhoneInbox(
          device: 'ab12',
          entries: [
            entry('p1', phonePayId(pay.id), '$checking', 205000000),
            // A pay stopped on the computer meanwhile: it comes in as
            // Income all the same.
            entry('p2', phonePayId(999999), '$checking', 5000000),
            // Money out can't be a paycheck: left with the phone.
            entry('p3', phonePayId(pay.id), '$checking', -5000000),
          ],
        ),
      ], today: today))!;
      expect(take.transactionIds, hasLength(2));
      expect(take.paychecks, hasLength(1));
      data = await db.loadLedger();
      row(int id) =>
          data.registerFor(checking).posted.singleWhere((r) => r.txnId == id);
      final paycheck = row(take.transactionIds.first);
      expect(paycheck.categoryLabel, 'Income');
      expect(paycheck.payScheduleId, pay.id);
      expect(paycheck.madeHow, MadeHow.phone);
      final other = row(take.transactionIds.last);
      expect(other.categoryLabel, 'Income');
      expect(other.payScheduleId, isNull);
      // 09.25's pay came early; the next is 10.23 (10.25 is a Sunday).
      expect(await coming(), [DateTime(2026, 10, 23)]);

      await db.undoPhoneTake(take);
      expect(await coming(), [DateTime(2026, 9, 25)]);
      await db.redoPhoneTake(take);
      data = await db.loadLedger();
      expect(row(take.transactionIds.first).payScheduleId, pay.id);
      expect(await coming(), [DateTime(2026, 10, 23)]);
    });

    test('a split on the phone is one split row on the computer', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedDemoIfEmpty(db, today);
      var data = await db.loadLedger();
      int id(String name) =>
          data.accounts.values.singleWhere((a) => a.name == name).id;
      final checking = id('TDB Checking');
      final groceries = id('Groceries');
      PhoneEntry split(String key, List<PhoneSplitLine> lines) => PhoneEntry(
        id: key,
        categoryId: phoneSplitId,
        accountId: '$checking',
        payee: 'Nomin',
        amountMinor: lines.fold(0, (s, l) => s + l.amountMinor),
        date: DateTime(2026, 9, 15),
        madeAt: today,
        lines: lines,
      );
      final inbox = PhoneInbox(
        device: 'ab12',
        entries: [
          split('s1', [
            (categoryId: '$groceries', amountMinor: -9800000),
            (categoryId: 'new-1', amountMinor: -3750000),
          ]),
          // A category deleted on the computer meanwhile: that share comes
          // in as Not categorized (owner, 2026-10-17).
          split('s2', [
            (categoryId: '$groceries', amountMinor: -100),
            (categoryId: '999999', amountMinor: -100),
          ]),
          // Lines that don't add up to the amount: left with the phone.
          PhoneEntry(
            id: 's3',
            categoryId: phoneSplitId,
            accountId: '$checking',
            payee: 'Nomin',
            amountMinor: -500,
            date: DateTime(2026, 9, 15),
            madeAt: today,
            lines: [(categoryId: '$groceries', amountMinor: -400)],
          ),
          // Filed under the split word with no lines (all an older phone
          // file could say): never filed somewhere wrong.
          PhoneEntry(
            id: 's4',
            categoryId: phoneSplitId,
            accountId: '$checking',
            payee: 'Nomin',
            amountMinor: -500,
            date: DateTime(2026, 9, 15),
            madeAt: today,
          ),
        ],
        categories: const [
          PhoneCategory(
            id: 'new-1',
            name: 'Shoes',
            leftMinor: 0,
            madeHere: true,
          ),
        ],
      );
      final before = data.balanceOf(checking);
      final take = (await db.takePhoneEntries([inbox], today: today))!;
      expect(take.transactionIds, hasLength(2));
      data = await db.loadLedger();
      expect(data.balanceOf(checking), before - 13550000 - 200);
      final row = data
          .registerFor(checking)
          .posted
          .singleWhere((r) => r.txnId == take.transactionIds.first);
      final gone = data
          .registerFor(checking)
          .posted
          .singleWhere((r) => r.txnId == take.transactionIds.last);
      expect(
        gone.splitLines.map((l) => (l.name, l.amount)),
        unorderedEquals([('Groceries', -100), ('Not categorized', -100)]),
      );
      expect(row.kind, RowKind.split);
      expect(row.madeHow, MadeHow.phone);
      expect(row.splitLines.map((l) => (l.name, l.amount)), [
        ('Groceries', -9800000),
        ('Shoes', -3750000),
      ]);
      expect(
        snapshotOf(data, today: today, madeAt: today).taken['ab12']!.entries,
        {'s1', 's2'},
      );

      // Undo takes the split row and the category it made; redo brings
      // both back.
      await db.undoPhoneTake(take);
      data = await db.loadLedger();
      expect(data.balanceOf(checking), before);
      expect(data.categories.any((c) => c.name == 'Shoes'), isFalse);
      await db.redoPhoneTake(take);
      data = await db.loadLedger();
      expect(data.balanceOf(checking), before - 13550000 - 200);
    });

    test('a category made on the phone carries its plan and accounts; an '
        'older file or plan it can\'t read leaves the category bare', () {
      final dir = _phoneDir();
      final file = File('${dir.path}/${phoneInboxName('ab12')}');
      final plan = CategoryPlan(
        categoryId: 0,
        kind: PlanKind.byDate,
        amount: 4500000,
        start: DateTime(2026, 9, 16),
        due: DateTime(2026, 10, 15),
        everyMonths: 1,
        endCount: 12,
        weekdays: const [1, 3],
        onDates: const [(4, 15), (10, 15)],
        monthDays: const [1, 15],
        paidFrom: 3,
      );
      writePhoneInbox(
        file,
        null,
        PhoneInbox(
          device: 'ab12',
          categories: [
            PhoneCategory(
              id: 'new-1',
              name: 'Mobicom',
              leftMinor: 0,
              madeHere: true,
              plan: plan,
              off: const {'4'},
            ),
          ],
        ),
      );
      final back = readPhoneInbox(file, null).categories.single;
      expect(back.off, {'4'});
      // A bill keeps its date on the phone across a restart.
      expect(back.due, DateTime(2026, 10, 15));
      final p = back.plan!;
      expect(p.kind, PlanKind.byDate);
      expect(p.amount, 4500000);
      expect(p.start, DateTime(2026, 9, 16));
      expect(p.due, DateTime(2026, 10, 15));
      expect(p.everyMonths, 1);
      expect(p.endCount, 12);
      expect(p.weekdays, [1, 3]);
      expect(p.onDates, [(4, 15), (10, 15)]);
      expect(p.monthDays, [1, 15]);
      expect(p.paidFrom, 3);
      expect(p.rollover, isTrue);
      expect(p.spentEach, isTrue);

      // Whether the money is spent within its period goes over and comes
      // back (#404), and a phone from before 0.82.0 says nothing, which
      // reads as spent each period — the answer nearly every category has.
      final built = CategoryPlan(
        categoryId: 0,
        kind: PlanKind.each,
        amount: 2000000,
        start: DateTime(2026, 9, 16),
        spentEach: false,
      );
      expect(planFromJson(jsonEncode(planToJson(built)))!.spentEach, isFalse);
      final older = planToJson(built)..remove('spentEach');
      expect(planFromJson(jsonEncode(older))!.spentEach, isTrue);

      // A plan with no days says nothing of them, so one saved before there
      // were any reads the same.
      expect(
        planToJson(
          CategoryPlan(
            categoryId: 0,
            kind: PlanKind.byDate,
            amount: 4500000,
            start: DateTime(2026, 9, 16),
            due: DateTime(2026, 10, 15),
          ),
        ).containsKey('monthDays'),
        isFalse,
      );
      // Days the form couldn't have saved aren't a plan.
      for (final days in [
        <int>[],
        [15, 1],
        [1, 1],
        [1, 15, 20],
        [0, 15],
        [15, 32],
      ]) {
        final j = planToJson(plan)..['monthDays'] = days;
        expect(planFromJson(jsonEncode(j)), isNull, reason: '$days');
      }

      // A plan this computer can't read: the category still comes.
      var db = sqlite3.open(file.path);
      db.execute("UPDATE category_plans SET plan = '{\"kind\": \"later\"}'");
      db.close();
      expect(readPhoneInbox(file, null).categories.single.plan, isNull);
      // A file from before plans.
      db = sqlite3.open(file.path);
      db.execute('DROP TABLE category_plans');
      db.execute('DROP TABLE category_off');
      db.close();
      final old = readPhoneInbox(file, null).categories.single;
      expect(old.name, 'Mobicom');
      expect(old.plan, isNull);
      expect(old.off, isEmpty);
    });

    test('a Goal and a Fund made on the phone come in as that type, and a '
        'file from before types reads as it did (#429)', () async {
      final dir = _phoneDir();
      final file = File('${dir.path}/${phoneInboxName('ab12')}');
      final christmas = PhoneCategory(
        id: 'new-1',
        name: 'Christmas',
        leftMinor: 0,
        madeHere: true,
        type: CategoryType.goal,
        plan: CategoryPlan(
          categoryId: 0,
          kind: PlanKind.byDate,
          amount: 700000000,
          start: today,
          due: DateTime(2026, 11, 1),
          everyMonths: 12,
        ),
      );
      const repairs = PhoneCategory(
        id: 'new-2',
        name: 'Car repairs',
        leftMinor: 0,
        madeHere: true,
        type: CategoryType.fund,
      );
      writePhoneInbox(
        file,
        null,
        PhoneInbox(device: 'ab12', categories: [christmas, repairs]),
      );
      final back = readPhoneInbox(file, null).categories;
      expect(back.map((c) => c.type), [CategoryType.goal, CategoryType.fund]);

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedDemoIfEmpty(db, today);
      final take = (await db.takePhoneEntries([
        PhoneInbox(device: 'ab12', categories: back),
      ], today: today))!;
      var data = await db.loadLedger();
      int id(String name) =>
          data.accounts.values.singleWhere((a) => a.name == name).id;
      expect(isGoal(data, id('Christmas')), isTrue);
      expect(data.plans[id('Car repairs')], isNull);
      expect(data.prefs[BudgetKeys.fund(id('Car repairs'))], 'yes');
      expect(data.prefs[ReadyKeys.goal(id('Christmas'))], 'yes');
      // Undone, the categories go; redone, they're that type again.
      await db.undoPhoneTake(take);
      await db.redoPhoneTake(take);
      data = await db.loadLedger();
      expect(isGoal(data, id('Christmas')), isTrue);

      // From a phone before 0.89.0: no type, and a waiting category's
      // print is what it was, so it isn't taken for changed.
      final old = sqlite3.open(file.path);
      old.execute('DROP TABLE category_types');
      old.close();
      expect(readPhoneInbox(file, null).categories.map((c) => c.type), [
        null,
        null,
      ]);
      const bare = PhoneCategory(
        id: 'new-2',
        name: 'Car repairs',
        leftMinor: 0,
        madeHere: true,
      );
      expect(
        (jsonDecode(phoneCategoryPrint(bare)) as Map).keys,
        isNot(contains('type')),
      );
    });

    test('a phone\'s bill for a category the computer has keeps the '
        'computer\'s Paid from, the bill with it (#180)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedDemoIfEmpty(db, today);
      var data = await db.loadLedger();
      int id(String name) =>
          data.accounts.values.singleWhere((a) => a.name == name).id;
      final checking = id('TDB Checking'), cash = id('Cash wallet');
      final utilities = id('Utilities');
      expect(data.paidFrom[utilities], checking);
      expect(data.plans[utilities], isNull);
      await db.takePhoneEntries([
        PhoneInbox(
          device: 'ab12',
          categories: [
            PhoneCategory(
              id: 'new-1',
              name: 'Utilities',
              leftMinor: 0,
              madeHere: true,
              paidFromId: '$cash',
              plan: CategoryPlan(
                categoryId: 0,
                kind: PlanKind.byDate,
                amount: 9000000,
                start: today,
                due: DateTime(2026, 10, 20),
                everyMonths: 1,
                paidFrom: cash,
              ),
            ),
          ],
        ),
      ], today: today);
      data = await db.loadLedger();
      expect(data.plans[utilities]!.kind, PlanKind.byDate);
      expect(data.paidFrom[utilities], checking);
      expect(data.plans[utilities]!.paidFrom, checking);
    });

    test('the computer gives a phone\'s category its plan and Paid from, '
        'and undo takes the category and its bill', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedDemoIfEmpty(db, today);
      var data = await db.loadLedger();
      int id(String name) =>
          data.accounts.values.singleWhere((a) => a.name == name).id;
      final checking = id('TDB Checking');
      final savings = id('Khan Savings');
      PhoneCategory made(String key, String name, CategoryPlan plan) =>
          PhoneCategory(
            id: key,
            name: name,
            leftMinor: 0,
            madeHere: true,
            plan: plan,
            off: {'$savings', '999999'},
          );
      final inbox = PhoneInbox(
        device: 'ab12',
        categories: [
          made(
            'new-1',
            'Mobicom',
            CategoryPlan(
              categoryId: 0,
              kind: PlanKind.byDate,
              amount: 4500000,
              start: today,
              due: DateTime(2026, 10, 15),
              everyMonths: 1,
              paidFrom: checking,
            ),
          ),
          // On a pay deleted on the computer since: made, without it.
          made(
            'new-2',
            'Bonus fund',
            CategoryPlan(
              categoryId: 0,
              kind: PlanKind.each,
              amount: 100000,
              start: today,
              payScheduleId: 999999,
            ),
          ),
          // Once only, its day gone by before the computer took it in.
          made(
            'new-3',
            'Car tax',
            CategoryPlan(
              categoryId: 0,
              kind: PlanKind.byDate,
              amount: 12000000,
              start: DateTime(2026, 9, 1),
              due: DateTime(2026, 9, 10),
            ),
          ),
        ],
      );
      final take = (await db.takePhoneEntries([inbox], today: today))!;
      data = await db.loadLedger();
      // The computer's popup says each bill, and what came without one
      // (#244).
      expect(
        phonePlanNotes(lookupWords(const Locale('en')), take, data, today),
        [
          'Bonus fund came in without its amount of ₮1,000: the payday it '
              'was set on was deleted on this computer',
          'Mobicom · ₮45,000 due 10.15',
          'Car tax · ₮120,000 due 09.10, already passed',
        ],
      );
      // Read again unchanged: nothing more to say.
      expect(await db.takePhoneEntries([inbox], today: today), isNull);
      final mobicom = id('Mobicom');
      final plan = data.plans[mobicom]!;
      expect(plan.kind, PlanKind.byDate);
      expect(plan.amount, 4500000);
      expect(plan.everyMonths, 1);
      expect(plan.paidFrom, checking);
      // The one account it left checked is its Paid from.
      expect(data.paidFrom[mobicom], checking);
      // Its bill is scheduled in TDB Checking, as the computer's would be.
      bool billed(LedgerData d) => d.txns.any(
        (t) => t.scheduled && t.entries.any((e) => e.accountId == mobicom),
      );
      expect(billed(data), isTrue);
      expect(data.plans[id('Bonus fund')], isNull);

      await db.undoPhoneTake(take);
      data = await db.loadLedger();
      expect(data.categories.any((c) => c.name == 'Mobicom'), isFalse);
      expect(billed(data), isFalse);
      await db.redoPhoneTake(take);
      data = await db.loadLedger();
      expect(data.plans[id('Mobicom')]!.amount, 4500000);
      expect(billed(data), isTrue);
    });

    test('a name the computer has already: one with no plan takes the '
        'phone\'s bill (an archived one comes back), one with a plan keeps '
        'its own', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedDemoIfEmpty(db, today);
      final internet = await db.createCategory('Internet');
      await db.setArchived(internet, true);
      final rent = await db.createCategory('Gym');
      final own = CategoryPlan(
        categoryId: rent,
        kind: PlanKind.each,
        amount: 7000000,
        start: today,
      );
      await db.setCategoryPlan(rent, own);
      CategoryPlan bill(int amount) => CategoryPlan(
        categoryId: 0,
        kind: PlanKind.byDate,
        amount: amount,
        start: today,
        due: DateTime(2026, 10, 20),
        everyMonths: 1,
      );
      final inbox = PhoneInbox(
        device: 'ab12',
        categories: [
          PhoneCategory(
            id: 'new-1',
            name: 'internet',
            leftMinor: 0,
            madeHere: true,
            plan: bill(6000000),
          ),
          PhoneCategory(
            id: 'new-2',
            name: 'Gym',
            leftMinor: 0,
            madeHere: true,
            plan: bill(100),
          ),
        ],
      );
      final take = (await db.takePhoneEntries([inbox], today: today))!;
      var data = await db.loadLedger();
      expect(
        phonePlanNotes(lookupWords(const Locale('en')), take, data, today),
        [
          'Gym was here already, so the phone’s ₮1 bill for it wasn’t used',
          'Internet · ₮60,000 due 10.20',
        ],
      );
      expect(data.accounts[internet]!.archived, isFalse);
      expect(data.plans[internet]!.amount, 6000000);
      expect(data.plans[rent]!.amount, 7000000);

      await db.undoPhoneTake(take);
      data = await db.loadLedger();
      expect(data.accounts[internet]!.archived, isTrue);
      expect(data.plans[internet], isNull);
      expect(data.plans[rent]!.amount, 7000000);
      await db.redoPhoneTake(take);
      data = await db.loadLedger();
      expect(data.accounts[internet]!.archived, isFalse);
      expect(data.plans[internet]!.amount, 6000000);
    });

    test('a category the phone changes after the computer took it in is '
        'said once, and the ledger\'s plan stays (#243)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedDemoIfEmpty(db, today);
      PhoneInbox inbox(int amount) => PhoneInbox(
        device: 'ab12',
        categories: [
          PhoneCategory(
            id: 'new-1',
            name: 'Mobicom',
            leftMinor: 0,
            madeHere: true,
            plan: CategoryPlan(
              categoryId: 0,
              kind: PlanKind.byDate,
              amount: amount,
              start: today,
              due: DateTime(2026, 10, 15),
              everyMonths: 1,
            ),
          ),
        ],
      );
      await db.takePhoneEntries([inbox(45000000)], today: today);
      // Fixed on the phone before it heard the computer had it.
      final late = (await db.takePhoneEntries([inbox(4500000)], today: today))!;
      final data = await db.loadLedger();
      final mobicom = data.categories.singleWhere((c) => c.name == 'Mobicom');
      expect(data.plans[mobicom.id]!.amount, 45000000);
      expect(late.transactionIds, isEmpty);
      expect(late.plans, isEmpty);
      expect(
        phonePlanNotes(lookupWords(const Locale('en')), late, data, today),
        [
          'Mobicom was changed on the phone after it came in, to ₮45,000 '
              'due 10.15; this computer’s stays as it was',
        ],
      );
      expect(await db.takePhoneEntries([inbox(4500000)], today: today), isNull);
    });

    test('a bill\'s next date, or that it has passed', () {
      CategoryPlan plan({
        DateTime? due,
        int? everyMonths,
        int? endCount,
        DateTime? endDate,
      }) => CategoryPlan(
        categoryId: 1,
        kind: PlanKind.byDate,
        amount: 100,
        start: DateTime(2026, 8, 1),
        due: due,
        everyMonths: everyMonths,
        endCount: endCount,
        endDate: endDate,
      );
      final day = DateTime(2026, 9, 16);
      expect(Budget.nextDue(plan(due: DateTime(2026, 9, 20)), day), (
        date: DateTime(2026, 9, 20),
        passed: false,
      ));
      expect(Budget.nextDue(plan(due: DateTime(2026, 9, 10)), day), (
        date: DateTime(2026, 9, 10),
        passed: true,
      ));
      expect(
        Budget.nextDue(plan(due: DateTime(2026, 8, 15), everyMonths: 1), day),
        (date: DateTime(2026, 10, 15), passed: false),
      );
      // Its two bills are both behind it.
      expect(
        Budget.nextDue(
          plan(due: DateTime(2026, 8, 1), everyMonths: 1, endCount: 2),
          day,
        ),
        (date: DateTime(2026, 9, 1), passed: true),
      );
      // An end typed before the first bill, still ahead: not passed.
      expect(
        Budget.nextDue(
          plan(
            due: DateTime(2026, 11, 20),
            everyMonths: 1,
            endDate: DateTime(2026, 11, 10),
          ),
          day,
        ),
        (date: DateTime(2026, 11, 10), passed: false),
      );
    });

    test(
      'a return on the same receipt comes in as a line the other way',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await seedDemoIfEmpty(db, today);
        var data = await db.loadLedger();
        int id(String name) =>
            data.accounts.values.singleWhere((a) => a.name == name).id;
        final checking = id('TDB Checking');
        final groceries = id('Groceries'), clothing = id('Clothing');
        PhoneEntry receipt(String key, List<PhoneSplitLine> lines) =>
            PhoneEntry(
              id: key,
              categoryId: phoneSplitId,
              accountId: '$checking',
              payee: 'Nomin',
              amountMinor: lines.fold(0, (s, l) => s + l.amountMinor),
              date: DateTime(2026, 9, 16),
              madeAt: today,
              lines: lines,
            );
        final inbox = PhoneInbox(
          device: 'ab12',
          entries: [
            // A ₮37,500 shirt returned, ₮50,000 of groceries bought.
            receipt('r1', [
              (categoryId: '$groceries', amountMinor: -5000000),
              (categoryId: '$clothing', amountMinor: 3750000),
            ]),
            // Returned more than was bought: money in.
            receipt('r2', [
              (categoryId: '$groceries', amountMinor: -1000000),
              (categoryId: '$clothing', amountMinor: 3000000),
            ]),
          ],
        );
        final before = data.balanceOf(checking);
        final take = (await db.takePhoneEntries([inbox], today: today))!;
        expect(take.transactionIds, hasLength(2));
        data = await db.loadLedger();
        expect(data.balanceOf(checking), before - 1250000 + 2000000);
        final rows = data.registerFor(checking).posted;
        final first = rows.singleWhere(
          (r) => r.txnId == take.transactionIds[0],
        );
        expect(first.kind, RowKind.split);
        expect(
          first.splitLines.map((l) => (l.name, l.amount)),
          unorderedEquals([('Groceries', -5000000), ('Clothing', 3750000)]),
        );
        final second = rows.singleWhere(
          (r) => r.txnId == take.transactionIds[1],
        );
        expect(
          second.splitLines.map((l) => (l.name, l.amount)),
          unorderedEquals([('Groceries', -1000000), ('Clothing', 3000000)]),
        );
      },
    );

    test('a transfer on the phone is a transfer on the computer', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedDemoIfEmpty(db, today);
      var data = await db.loadLedger();
      int id(String name) =>
          data.accounts.values.singleWhere((a) => a.name == name).id;
      final checking = id('TDB Checking'), cash = id('Cash wallet');
      final visa = id('Golomt Visa');
      final dollars = await db.createAccount(
        name: 'Dollars',
        type: AccountType.asset,
        currency: Currency.usd,
      );
      final was = (
        checking: data.balanceOf(checking),
        cash: data.balanceOf(cash),
        visa: data.balanceOf(visa),
      );
      final rows = data.txns.length;

      // The phone's own sums, before the computer has seen anything.
      final snapshot = snapshotOf(data, today: today, madeAt: today);
      PhoneAccount phone(int id) =>
          snapshot.accounts.singleWhere((a) => a.id == '$id');
      final atm = entry('t1', '$cash', '$checking', -10000000);
      final card = entry('t2', '$visa', '$checking', -20000000);
      expect(snapshot.transferTo(atm)!.name, 'Cash wallet');
      expect(
        snapshot.transferTo(entry('e', '${id('Groceries')}', '$checking', -1)),
        isNull,
      );
      expect(
        snapshot.transferTargets(phone(checking)).map((a) => a.name),
        isNot(contains('TDB Checking')),
      );
      expect(
        balanceNow(phone(checking), [atm, card]),
        phone(checking).balanceMinor - 30000000,
      );
      expect(
        balanceNow(phone(cash), [atm, card]),
        phone(cash).balanceMinor + 10000000,
      );
      // A card paid: what is owed goes down.
      expect(
        balanceNow(phone(visa), [atm, card]),
        phone(visa).balanceMinor - 20000000,
      );

      // Cash wallet was put away on the computer since the phone looked:
      // the transfer still comes in, and the account comes back.
      await db.setArchived(cash, true);
      final inbox = PhoneInbox(
        device: 'ab12',
        entries: [
          atm,
          card,
          // To itself, to another currency, or the wrong way round: left
          // with the phone.
          entry('t3', '$checking', '$checking', -500),
          entry('t4', '$dollars', '$checking', -500),
          entry('t5', '$cash', '$checking', 500),
        ],
      );
      final take = (await db.takePhoneEntries([inbox], today: today))!;
      expect(take.transactionIds, hasLength(2));
      data = await db.loadLedger();
      expect(data.txns.length, rows + 2);
      expect(data.balanceOf(checking), was.checking - 30000000);
      expect(data.balanceOf(cash), was.cash + 10000000);
      expect(data.balanceOf(visa), was.visa + 20000000);
      final row = data
          .registerFor(checking)
          .posted
          .singleWhere((r) => r.txnId == take.transactionIds.first);
      expect(data.accounts[cash]!.archived, isFalse);
      expect(row.kind, RowKind.transfer);
      expect(row.payee, 'Cash wallet');
      expect(row.amount, -10000000);
      expect(
        snapshotOf(data, today: today, madeAt: today).taken['ab12']!.entries,
        {'t1', 't2'},
      );

      await db.undoPhoneTake(take);
      data = await db.loadLedger();
      expect(data.balanceOf(checking), was.checking);
      expect(data.balanceOf(cash), was.cash);
      expect(data.balanceOf(visa), was.visa);
      expect(data.accounts[cash]!.archived, isTrue);
      await db.redoPhoneTake(take);
      data = await db.loadLedger();
      expect(data.balanceOf(cash), was.cash + 10000000);
      expect(data.accounts[cash]!.archived, isFalse);
    });

    test('the computer takes each entry in once, with one undo, and the '
        'phone lets go of them', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedDemoIfEmpty(db, today);
      var data = await db.loadLedger();
      int id(String name) =>
          data.accounts.values.singleWhere((a) => a.name == name).id;
      final groceries = id('Groceries'), checking = id('TDB Checking');
      final before = data.balanceOf(checking);
      final rows = data.txns.length;
      final inbox = PhoneInbox(
        device: 'ab12',
        entries: [
          entry('e1', '$groceries', '$checking', -1250000),
          entry('e2', 'new-1', '$checking', -450000),
          // Its account was deleted on the computer: left with the phone.
          entry('e3', '$groceries', '99999', -100),
        ],
        categories: const [
          PhoneCategory(
            id: 'new-1',
            name: 'Coffee',
            leftMinor: 0,
            madeHere: true,
          ),
          // Already a category, whatever its capitals: no second one.
          PhoneCategory(
            id: 'new-2',
            name: ' groceries',
            leftMinor: 0,
            madeHere: true,
          ),
        ],
      );
      final take = (await db.takePhoneEntries([inbox], today: today))!;
      expect(take.transactionIds, hasLength(2));
      expect(take.categoryIds, hasLength(1));
      data = await db.loadLedger();
      expect(data.txns.length, rows + 2);
      expect(data.balanceOf(checking), before - 1700000);
      expect(data.accounts[take.categoryIds.single]!.name, 'Coffee');

      // The same file again brings nothing: nothing comes in twice.
      expect(await db.takePhoneEntries([inbox], today: today), isNull);
      expect((await db.loadLedger()).txns.length, rows + 2);

      // The ledger says what is in, and the phone drops it.
      final snapshot = snapshotOf(data, today: today, madeAt: today);
      expect(snapshot.taken['ab12']!.entries, {'e1', 'e2'});
      expect(snapshot.taken['ab12']!.categories, {
        'new-1': '${take.categoryIds.single}',
        'new-2': '$groceries',
      });
      final store = PhoneStore(
        snapshot,
        device: 'ab12',
        waiting: [...inbox.entries, entry('e4', 'new-1', '$checking', -200)],
        made: inbox.categories,
      );
      expect(store.waiting.map((e) => e.id), ['e3', 'e4']);
      expect(store.made, isEmpty);
      // One typed since, in the category the ledger now has, follows it.
      expect(store.waiting.last.categoryId, '${take.categoryIds.single}');

      // One undo takes the lot out, and they don't come back by themselves.
      await db.undoPhoneTake(take);
      data = await db.loadLedger();
      expect(data.txns.length, rows);
      expect(data.balanceOf(checking), before);
      expect(await db.takePhoneEntries([inbox], today: today), isNull);
      await db.redoPhoneTake(take);
      expect((await db.loadLedger()).balanceOf(checking), before - 1700000);

      // The phone's file no longer holds them; they are still known, so
      // an older copy of the file turning up brings nothing in.
      await db.takePhoneEntries([
        const PhoneInbox(device: 'ab12'),
      ], today: today);
      expect(await db.takePhoneEntries([inbox], today: today), isNull);
      expect((await db.loadLedger()).txns.length, rows + 2);
    });

    test(
      'two copies of one phone’s file, and two phones, each entry once',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await seedDemoIfEmpty(db, today);
        final data = await db.loadLedger();
        int id(String name) =>
            data.accounts.values.singleWhere((a) => a.name == name).id;
        final g = '${id('Groceries')}', c = '${id('TDB Checking')}';
        final rows = data.txns.length;
        // Drive holds a newer and an older file from the same phone.
        final files = [
          PhoneInbox(
            device: 'ab12',
            entries: [entry('a', g, c, -100), entry('b', g, c, -200)],
          ),
          PhoneInbox(device: 'ab12', entries: [entry('a', g, c, -100)]),
          PhoneInbox(device: 'cd34', entries: [entry('a', g, c, -300)]),
          // Money moved to the account it came from is nothing: left out.
          PhoneInbox(device: 'ef56', entries: [entry('x', c, c, -400)]),
        ];
        final take = (await db.takePhoneEntries(files, today: today))!;
        expect(take.transactionIds, hasLength(3));
        for (var look = 0; look < 3; look++) {
          expect(await db.takePhoneEntries(files, today: today), isNull);
        }
        expect((await db.loadLedger()).txns.length, rows + 3);
      },
    );

    test('a category the take made and undo removed is made again for a '
        'later entry', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedDemoIfEmpty(db, today);
      final data = await db.loadLedger();
      final c =
          '${data.accounts.values.singleWhere((a) => a.name == 'TDB Checking').id}';
      const coffee = PhoneCategory(
        id: 'new-1',
        name: 'Coffee',
        leftMinor: 0,
        madeHere: true,
      );
      final first = (await db.takePhoneEntries([
        PhoneInbox(
          device: 'ab12',
          entries: [entry('a', 'new-1', c, -100)],
          categories: const [coffee],
        ),
      ], today: today))!;
      await db.undoPhoneTake(first);
      final second = (await db.takePhoneEntries([
        PhoneInbox(
          device: 'ab12',
          entries: [entry('a', 'new-1', c, -100), entry('b', 'new-1', c, -200)],
          categories: const [coffee],
        ),
      ], today: today))!;
      // Only the later entry comes in, in a Coffee that is live again.
      expect(second.transactionIds, hasLength(1));
      expect(second.categoryIds, hasLength(1));
    });

    test('an entry dated after the computer’s today is still spending, not '
        'a scheduled row', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedDemoIfEmpty(db, today);
      final data = await db.loadLedger();
      int id(String name) =>
          data.accounts.values.singleWhere((a) => a.name == name).id;
      final take = (await db.takePhoneEntries([
        PhoneInbox(
          device: 'ab12',
          entries: [
            PhoneEntry(
              id: 'late',
              categoryId: '${id('Groceries')}',
              accountId: '${id('TDB Checking')}',
              payee: 'Nomin',
              amountMinor: -500000,
              // The phone's clock is a day ahead.
              date: DateTime(2026, 9, 17),
              madeAt: DateTime(2026, 9, 17, 0, 5),
            ),
          ],
        ),
      ], today: today))!;
      final row = (await db.loadLedger()).txns.singleWhere(
        (t) => t.id == take.transactionIds.single,
      );
      expect(row.scheduled, isFalse);
    });

    test('an entry filed in an archived category brings it back', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedDemoIfEmpty(db, today);
      final data = await db.loadLedger();
      int id(String name) =>
          data.accounts.values.singleWhere((a) => a.name == name).id;
      final groceries = id('Groceries');
      await db.setArchived(groceries, true);
      // The phone can't see it, so it makes "Groceries" again.
      final take = (await db.takePhoneEntries([
        PhoneInbox(
          device: 'ab12',
          entries: [entry('a', 'new-1', '${id('TDB Checking')}', -100)],
          categories: const [
            PhoneCategory(
              id: 'new-1',
              name: 'groceries',
              leftMinor: 0,
              madeHere: true,
            ),
          ],
        ),
      ], today: today))!;
      expect(take.categoryIds, isEmpty);
      expect((await db.loadLedger()).accounts[groceries]!.archived, isFalse);
      await db.undoPhoneTake(take);
      expect((await db.loadLedger()).accounts[groceries]!.archived, isTrue);
    });

    test(
      'money in arrives as a refund to its category, or as income',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await seedDemoIfEmpty(db, today);
        var data = await db.loadLedger();
        int id(String name) =>
            data.accounts.values.singleWhere((a) => a.name == name).id;
        Budget budget() => Budget.of(
          data,
          start: DateTime(2026, 9),
          end: DateTime(2026, 9, 30),
          today: today,
        );
        final groceries = id('Groceries'), checking = id('TDB Checking');
        // A budget, so Groceries has something left to put money back in.
        await db.setBudgetAmount(
          groceries,
          DateTime(2026, 9),
          DateTime(2026, 9, 30),
          50000000,
        );
        data = await db.loadLedger();
        final balance = data.balanceOf(checking);
        final left = budget().lines[groceries]!.left;
        expect(left, isNot(0));
        final spent = budget().lines[groceries]!.spent;
        final take = (await db.takePhoneEntries([
          PhoneInbox(
            device: 'ab12',
            entries: [
              entry('refund', '$groceries', '$checking', 1250000),
              entry('pay', phoneIncomeId, '$checking', 5000000),
              // Money out is never income on a phone: left with it.
              entry('odd', phoneIncomeId, '$checking', -100),
            ],
          ),
        ], today: today))!;
        expect(take.transactionIds, hasLength(2));
        data = await db.loadLedger();
        expect(data.balanceOf(checking), balance + 6250000);
        // The refund is back in Groceries, as spending that didn't happen.
        expect(budget().lines[groceries]!.left, left + 1250000);
        expect(budget().lines[groceries]!.spent, spent - 1250000);
        // The other is under the ledger's own Income.
        final pay = data.txns.singleWhere(
          (t) => t.entries.any(
            (e) => e.accountId == data.income!.id && e.amount == -5000000,
          ),
        );
        expect(take.transactionIds, contains(pay.id));
        final snapshot = snapshotOf(data, today: today, madeAt: today);
        expect(snapshot.taken['ab12']!.entries, {'refund', 'pay'});

        await db.undoPhoneTake(take);
        data = await db.loadLedger();
        expect(data.balanceOf(checking), balance);
        expect(budget().lines[groceries]!.left, left);
      },
    );

    test(
      'income from a phone makes Income in a ledger that has none',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final wallet = await db.addAccount(
          name: 'Wallet',
          type: AccountType.asset,
        );
        expect((await db.loadLedger()).income, isNull);
        // An entry for an account that has gone doesn't make it.
        expect(
          await db.takePhoneEntries([
            PhoneInbox(
              device: 'ab12',
              entries: [entry('lost', phoneIncomeId, '99999', 5000000)],
            ),
          ], today: today),
          isNull,
        );
        expect((await db.loadLedger()).income, isNull);

        await db.takePhoneEntries([
          PhoneInbox(
            device: 'ab12',
            entries: [entry('pay', phoneIncomeId, '$wallet', 5000000)],
          ),
        ], today: today);
        final data = await db.loadLedger();
        expect(data.income, isNotNull);
        expect(data.balanceOf(wallet), 5000000);
        expect(data.balanceOf(data.income!.id), -5000000);
      },
    );

    test('a category an older phone made called Income is the ledger’s own '
        'Income, not a second one', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedDemoIfEmpty(db, today);
      var data = await db.loadLedger();
      final checking = data.accounts.values
          .singleWhere((a) => a.name == 'TDB Checking')
          .id;
      final categories = data.accounts.values.where((a) => a.isCategory).length;
      final take = (await db.takePhoneEntries([
        PhoneInbox(
          device: 'ab12',
          entries: [entry('pay', 'new-1', '$checking', 5000000)],
          categories: const [
            PhoneCategory(
              id: 'new-1',
              name: 'income',
              leftMinor: 0,
              madeHere: true,
            ),
          ],
        ),
      ], today: today))!;
      data = await db.loadLedger();
      // No category was made, so the take's undo has none to remove.
      expect(take.categoryIds, isEmpty);
      expect(
        data.accounts.values.where((a) => a.isCategory).length,
        categories,
      );
      final row = data.txns.singleWhere(
        (t) => t.id == take.transactionIds.single,
      );
      expect(row.entries.map((e) => e.accountId), contains(data.income!.id));
      await db.undoPhoneTake(take);
      expect((await db.loadLedger()).income, isNotNull);
    });

    test('the computer finds each phone’s file in the folder', () async {
      final dir = _phoneDir();
      for (final device in ['ab12', 'cd34']) {
        writePhoneInbox(
          File('${dir.path}/${phoneInboxName(device)}'),
          null,
          PhoneInbox(
            device: device,
            entries: [entry('e-$device', '1', '2', -5)],
          ),
        );
      }
      // Not a phone's file, and one that is still arriving.
      File('${dir.path}/$ledgerFileName').writeAsBytesSync([1, 2, 3]);
      File('${dir.path}/${phoneInboxName('half')}').writeAsBytesSync([1, 2]);
      final found = await readPhoneInboxes(
        dir,
        null,
        scratch: Directory('${dir.path}/scratch'),
      );
      expect(found.map((i) => i.device).toSet(), {'ab12', 'cd34'});
    });
  });

  group('first launch', () {
    Future<
      ({
        _FakeKeys keys,
        _FakeFolder folder,
        List<Uint8List> read,
        List<DateTime> looks,
      })
    >
    start(
      WidgetTester tester, {
      _FakeKeys? keys,
      _FakeFolder? folder,
      Uint8List? opens,
      Directory? dir,
      Map<String, PhoneTaken> Function()? taken,
      ProblemLog? problems,
      bool Function()? fails,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final k = keys ?? _FakeKeys();
      final f = folder ?? _FakeFolder();
      final read = <Uint8List>[];
      final looks = <DateTime>[];
      await tester.pumpWidget(
        PhoneFrame(
          child: PhoneStart(
            keys: k,
            folder: f,
            dir: dir ?? _phoneDir(),
            now: () => _now,
            problems: problems,
            open:
                ({
                  required dir,
                  required key,
                  required device,
                  required folder,
                }) => _FakeSource(
                  dir: dir,
                  key: key,
                  folder: f,
                  opens: opens,
                  taken: taken,
                  fails: fails,
                  joins: read,
                  looks: looks,
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (keys: k, folder: f, read: read, looks: looks);
    }

    testWidgets('the demo key opens made-up figures, reads and keeps nothing '
        '(Play review)', (tester) async {
      final s = await start(tester);
      await tester.enterText(
        find.byKey(const ValueKey('phone-key')),
        'demo demo demo demo demo',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        find.text('Made-up figures for a look around. Nothing here is saved.'),
        findsOneWidget,
      );
      expect(find.text('Where is your ledger?'), findsNothing);
      // No key kept, no ledger read, no folder asked about.
      expect(s.keys.kept, isNull);
      expect(s.read, isEmpty);
      expect(s.folder.asked, isEmpty);
      await tester.tap(find.byKey(const ValueKey('to-budget')));
      await tester.pumpAndSettle();
      expect(find.text('Groceries'), findsOneWidget);
      await expectLater(
        find.byType(PhoneFrame),
        matchesGoldenFile('goldens/phone_demo.png'),
      );
    });

    testWidgets('the key, then the folder, then Ledger', (tester) async {
      final key = RecoveryKey.generate();
      final s = await start(tester);
      expect(find.text('Enter your recovery key'), findsOneWidget);
      await expectLater(
        find.byType(PhoneFrame),
        matchesGoldenFile('goldens/phone_key.png'),
      );

      // A mistyped key is caught before anything else is asked.
      await tester.enterText(find.byKey(const ValueKey('phone-key')), 'ABCDE');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your recovery key'), findsOneWidget);
      expect(find.text('Where is your ledger?'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('phone-key')),
        key.display,
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Where is your ledger?'), findsOneWidget);
      // Not kept until it has opened the ledger.
      expect(s.keys.kept, isNull);

      await tester.tap(find.text('Choose the folder'));
      await tester.pumpAndSettle();
      // It opens on Ledger; the figures are on Budget.
      expect(find.text('Save'), findsOneWidget);
      await _toBudget(tester);
      expect(find.text('Left in October'), findsOneWidget);
      expect(find.text('From your computer today 13:30'), findsOneWidget);
      expect(find.text('₮148,000.00'), findsOneWidget);
      expect(_same(s.keys.kept!, deriveDataKey(key)), isTrue);
    });

    testWidgets('the next launch goes straight to Ledger', (tester) async {
      final keys = _FakeKeys()..kept = deriveDataKey(RecoveryKey.generate());
      final folder = _FakeFolder()..picked = 'drive:BetterBudget';
      await start(tester, keys: keys, folder: folder);
      expect(find.byKey(const ValueKey('to-budget')), findsOneWidget);
    });

    testWidgets('a key that is not this ledger’s is not kept', (tester) async {
      final right = deriveDataKey(RecoveryKey.generate());
      final s = await start(tester, opens: right);
      await tester.enterText(
        find.byKey(const ValueKey('phone-key')),
        RecoveryKey.generate().display,
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose the folder'));
      await tester.pumpAndSettle();
      expect(
        find.text('That recovery key doesn’t open the ledger in this folder'),
        findsOneWidget,
      );
      expect(s.keys.kept, isNull);
      expect(find.byKey(const ValueKey('report-problem')), findsOneWidget);
      await tester.tap(find.text('Enter the key again'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your recovery key'), findsOneWidget);
      // Typing the key is no problem yet.
      expect(find.byKey(const ValueKey('report-problem')), findsNothing);
    });

    testWidgets('a wrong key and then the right one: what is written is under '
        'the right key and is there after a relaunch', (tester) async {
      final rightKey = RecoveryKey.generate();
      final right = deriveDataKey(rightKey);
      final dir = _phoneDir();
      final keys = _FakeKeys();
      final folder = _FakeFolder();
      await start(tester, keys: keys, folder: folder, dir: dir, opens: right);
      await tester.enterText(
        find.byKey(const ValueKey('phone-key')),
        RecoveryKey.generate().display,
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose the folder'));
      await tester.pumpAndSettle();
      expect(
        find.text('That recovery key doesn’t open the ledger in this folder'),
        findsOneWidget,
      );
      // Nothing kept under the key that didn't fit.
      expect(Directory('${dir.path}/waiting').existsSync(), isFalse);

      await tester.tap(find.text('Enter the key again'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('phone-key')),
        rightKey.display,
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await _spend(tester, 'Transport', '8000', 'ub', pick: 'UB Cab');
      await tester.pumpWidget(const SizedBox());
      await start(tester, keys: keys, folder: folder, dir: dir, opens: right);
      expect(find.text('1 entry isn’t on your computer yet'), findsOneWidget);
    });

    testWidgets('a ledger the kept key no longer opens goes in the record', (
      tester,
    ) async {
      final dir = _phoneDir();
      final keys = _FakeKeys()..kept = deriveDataKey(RecoveryKey.generate());
      final folder = _FakeFolder()..picked = 'drive:BetterBudget';
      await start(
        tester,
        keys: keys,
        folder: folder,
        dir: dir,
        opens: deriveDataKey(RecoveryKey.generate()),
        problems: ProblemLog(
          File('${dir.path}/problems'),
          now: () => _now,
          version: () async => '0.56.0',
        ),
      );
      expect(find.byKey(const ValueKey('report-problem')), findsOneWidget);
      // Read back from the file, as the next launch would.
      final kept = ProblemLog(
        File('${dir.path}/problems'),
        now: () => _now,
      ).recent.single;
      expect(kept.reason, 'WrongKeyException');
      expect(kept.version, '0.56.0');
    });

    testWidgets('a folder with no ledger says so, and another can be picked', (
      tester,
    ) async {
      final keys = _FakeKeys()..kept = deriveDataKey(RecoveryKey.generate());
      final folder = _FakeFolder()
        ..picked = 'drive:Photos'
        ..ledger = null;
      await start(tester, keys: keys, folder: folder);
      expect(find.text('There is no ledger in that folder'), findsOneWidget);
      expect(find.textContaining('Ledger.betterbudget'), findsOneWidget);

      folder
        ..willPick = 'drive:BetterBudget'
        ..ledger = Uint8List.fromList([1]);
      await tester.tap(find.text('Choose another folder'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('to-budget')), findsOneWidget);
      expect(folder.forgotten, ['drive:Photos']);
    });

    testWidgets('the copies an earlier version kept apart are removed once the '
        'phone’s own ledger is up', (tester) async {
      final dir = _phoneDir();
      for (final old in ['phone', 'phone-last']) {
        File('${dir.path}/$old/$ledgerFileName')
          ..createSync(recursive: true)
          ..writeAsBytesSync([1, 2, 3]);
      }
      final keys = _FakeKeys()..kept = deriveDataKey(RecoveryKey.generate());
      final folder = _FakeFolder()..picked = 'drive:BetterBudget';
      await start(tester, keys: keys, folder: folder, dir: dir);
      expect(find.byKey(const ValueKey('to-budget')), findsOneWidget);
      expect(Directory('${dir.path}/phone').existsSync(), isFalse);
      expect(Directory('${dir.path}/phone-last').existsSync(), isFalse);
    });

    testWidgets('a problem screen ends with Send feedback…', (tester) async {
      final browser = _FakeBrowser();
      final before = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = browser;
      addTearDown(() => UrlLauncherPlatform.instance = before);
      final keys = _FakeKeys()..kept = deriveDataKey(RecoveryKey.generate());
      final folder = _FakeFolder()
        ..picked = 'drive:Photos'
        ..ledger = null;
      await start(tester, keys: keys, folder: folder);
      expect(find.text('There is no ledger in that folder'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('report-problem')));
      // Until the browser is asked: the version is read first.
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && browser.opened.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pumpAndSettle();
      final link = Uri.parse(browser.opened.single);
      expect('${link.host}${link.path}', 'lls.mn/en/contact/');
      expect(link.queryParameters['from'], 'betterbudget');
    });

    testWidgets('a file that won’t open later leaves the figures up', (
      tester,
    ) async {
      final right = deriveDataKey(RecoveryKey.generate());
      final keys = _FakeKeys()..kept = right;
      final folder = _FakeFolder()..picked = 'drive:BetterBudget';
      var broken = false;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        PhoneFrame(
          child: PhoneStart(
            keys: keys,
            folder: folder,
            dir: _phoneDir(),
            now: () => _now,
            open:
                ({
                  required dir,
                  required key,
                  required device,
                  required folder,
                }) => _FakeSource(
                  dir: dir,
                  key: key,
                  folder: folder as _FakeFolder,
                  fails: () => broken,
                  joins: [],
                  looks: [],
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('to-budget')), findsOneWidget);
      broken = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('to-budget')), findsOneWidget);
      expect(find.textContaining('doesn’t open'), findsNothing);
      expect(_same(keys.kept!, right), isTrue);
    });

    testWidgets('a kept folder that no longer opens leaves the figures up, '
        'and asks for the folder only before there are any', (tester) async {
      final keys = _FakeKeys()..kept = deriveDataKey(RecoveryKey.generate());
      final folder = _FakeFolder()..picked = 'drive:BetterBudget';
      final dir = _phoneDir();
      await start(tester, keys: keys, folder: folder, dir: dir);
      expect(find.byKey(const ValueKey('to-budget')), findsOneWidget);

      folder.keptFails = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('to-budget')), findsOneWidget);
      expect(find.text('Where is your ledger?'), findsNothing);

      // Opened again: nothing up yet, so the folder is asked for.
      await tester.pumpWidget(const SizedBox());
      await start(tester, keys: keys, folder: folder, dir: dir);
      expect(find.text('Where is your ledger?'), findsOneWidget);
    });

    group('opened with no signal', () {
      // Each test's first launch reads the folder's ledger, changed at
      // 13:30; the next can't reach the folder.
      Future<void> expectLastRead(WidgetTester tester) async {
        expect(find.byKey(const ValueKey('to-budget')), findsOneWidget);
        expect(
          find.text('The ledger in this folder couldn’t be read'),
          findsNothing,
        );
        await _toBudget(tester);
        // The ledger last read, with its own time.
        expect(find.text('From your computer today 13:30'), findsOneWidget);
      }

      testWidgets('a folder that fails opens the ledger last read', (
        tester,
      ) async {
        final dir = _phoneDir();
        final keys = _FakeKeys()..kept = deriveDataKey(RecoveryKey.generate());
        final folder = _FakeFolder()..picked = 'drive:BetterBudget';
        await start(tester, keys: keys, folder: folder, dir: dir);
        await tester.pumpWidget(const SizedBox());
        folder.readFails = true;
        await start(tester, keys: keys, folder: folder, dir: dir);
        await expectLastRead(tester);

        // An entry can still be made, and is written for the computer.
        await _toLedger(tester);
        await _spend(tester, 'Transport', '8000', 'ub', pick: 'UB Cab');
        expect(isPhoneInboxName(folder.written.keys.single), isTrue);
      });

      testWidgets('a folder that never answers opens it after a wait', (
        tester,
      ) async {
        final dir = _phoneDir();
        final keys = _FakeKeys()..kept = deriveDataKey(RecoveryKey.generate());
        final folder = _FakeFolder()..picked = 'drive:BetterBudget';
        await start(tester, keys: keys, folder: folder, dir: dir);
        await tester.pumpWidget(const SizedBox());
        folder.readHangs = true;
        await start(tester, keys: keys, folder: folder, dir: dir);
        expect(find.byKey(const ValueKey('to-budget')), findsNothing);
        await tester.pump(phoneFolderPatience + const Duration(seconds: 1));
        await tester.pumpAndSettle();
        await expectLastRead(tester);
      });

      testWidgets('with nothing read before, it says the ledger couldn’t be '
          'read', (tester) async {
        final keys = _FakeKeys()..kept = deriveDataKey(RecoveryKey.generate());
        final folder = _FakeFolder()
          ..picked = 'drive:BetterBudget'
          ..readFails = true;
        await start(tester, keys: keys, folder: folder);
        expect(
          find.text('The ledger in this folder couldn’t be read'),
          findsOneWidget,
        );
      });
    });

    testWidgets('an entry is written to the folder, is still there after '
        'the app is closed, and goes once the computer has it', (tester) async {
      final keys = _FakeKeys()..kept = deriveDataKey(RecoveryKey.generate());
      final folder = _FakeFolder()..picked = 'drive:BetterBudget';
      final dir = _phoneDir();
      var taken = <String, PhoneTaken>{};
      await start(tester, keys: keys, folder: folder, dir: dir);
      // Nothing to say yet, so no file.
      expect(folder.written, isEmpty);
      await _spend(tester, 'Transport', '8000', 'ub', pick: 'UB Cab');
      final name = folder.written.keys.single;
      expect(isPhoneInboxName(name), isTrue);
      final file = File('${dir.path}/check')
        ..writeAsBytesSync(folder.written[name]!);
      final sent = readPhoneInbox(file, keys.kept);
      expect(sent.entries.single.payee, 'UB Cab');
      expect(sent.entries.single.amountMinor, -800000);

      // Closed and opened again.
      await tester.pumpWidget(const SizedBox());
      await start(
        tester,
        keys: keys,
        folder: folder,
        dir: dir,
        taken: () => taken,
      );
      expect(find.text('1 entry isn’t on your computer yet'), findsOneWidget);

      // The computer's next ledger says it is in.
      taken = {
        sent.device: PhoneTaken(entries: {sent.entries.single.id}),
      };
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('waiting-link')), findsNothing);
      file.writeAsBytesSync(folder.written[name]!);
      expect(readPhoneInbox(file, keys.kept).entries, isEmpty);
    });

    testWidgets('a waiting category changed on the phone is written to '
        'the folder again (#243)', (tester) async {
      final keys = _FakeKeys()..kept = deriveDataKey(RecoveryKey.generate());
      final folder = _FakeFolder()..picked = 'drive:BetterBudget';
      final dir = _phoneDir();
      await start(tester, keys: keys, folder: folder, dir: dir);
      await _toBudget(tester);
      await tester.tap(find.byKey(const ValueKey('budget-new-category')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('new-category-name')),
        'Taxi',
      );
      await tester.enterText(
        find.byKey(const ValueKey('plan-amount')),
        '500000',
      );
      await _paidFrom(tester);
      await tester.tap(find.byKey(const ValueKey('new-category-add')));
      await tester.pumpAndSettle();
      final name = folder.written.keys.single;
      final file = File('${dir.path}/check');
      PhoneCategory sent() {
        file.writeAsBytesSync(folder.written[name]!);
        return readPhoneInbox(file, keys.kept).categories.single;
      }

      expect(sent().plan!.amount, 50000000);
      final id = sent().id;
      await _toLedger(tester);
      await tester.tap(find.byKey(const ValueKey('waiting-link')));
      await tester.pumpAndSettle();
      expect(find.text('new category · ₮500,000'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('waiting-category-$id')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('plan-amount')),
        '50000',
      );
      await tester.tap(find.byKey(const ValueKey('new-category-add')));
      await tester.pumpAndSettle();
      expect(find.text('new category · ₮50,000'), findsOneWidget);
      expect(sent().id, id);
      expect(sent().plan!.amount, 5000000);
    });

    testWidgets('entries the phone can’t save go in the record once, '
        'not at every try', (tester) async {
      final keys = _FakeKeys()..kept = deriveDataKey(RecoveryKey.generate());
      final folder = _FakeFolder()..picked = 'drive:BetterBudget';
      final dir = _phoneDir();
      final problems = ProblemLog(
        File('${dir.path}/problems'),
        now: () => _now,
        version: () async => '0.56.0',
      );
      await start(
        tester,
        keys: keys,
        folder: folder,
        dir: dir,
        problems: problems,
      );
      // A folder where the phone's file goes: saving it fails.
      Directory('${dir.path}/waiting/waiting.$phoneInboxExtension')
          .createSync(recursive: true);
      await _spend(tester, 'Transport', '8000', 'ub', pick: 'UB Cab');
      await _spend(tester, 'Transport', '5000', 'ub', pick: 'UB Cab');
      expect(folder.written, isEmpty);
      expect(problems.recent.single.message, startsWith('Couldn’t save'));
    });

    testWidgets('the folder is looked at every half minute while the app is '
        'open, with nothing waiting too: the phone is another computer on '
        'the ledger (#526)', (tester) async {
      final keys = _FakeKeys()..kept = deriveDataKey(RecoveryKey.generate());
      final folder = _FakeFolder()..picked = 'drive:BetterBudget';
      final s = await start(tester, keys: keys, folder: folder);
      expect(s.looks, hasLength(1));
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(s.looks, hasLength(2));

      await _spend(tester, 'Transport', '8000', 'ub', pick: 'UB Cab');
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(s.looks, hasLength(3));
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(s.looks, hasLength(4));
    });

    testWidgets('an entry waiting on the phone survives a fresh read', (
      tester,
    ) async {
      final keys = _FakeKeys()..kept = deriveDataKey(RecoveryKey.generate());
      final folder = _FakeFolder()..picked = 'drive:BetterBudget';
      final s = await start(tester, keys: keys, folder: folder);
      await _spend(tester, 'Transport', '8000', 'ub', pick: 'UB Cab');

      // Back from another app: the folder is read again.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(s.looks.length, 2);
      expect(find.text('1 entry isn’t on your computer yet'), findsOneWidget);
      await _toBudget(tester);
      expect(find.text('₮53,500.00'), findsOneWidget);
    });
  });

  group('importing a bank file on the phone (#531)', () {
    /// The bank's file, saved where the stand-in picker hands it over.
    String bankFile(String name, String text) {
      final dir = Directory.systemTemp.createTempSync('bb-phone-import');
      addTearDown(() => dir.deleteSync(recursive: true));
      return (File('${dir.path}/$name')..writeAsStringSync(text)).path;
    }

    const statement =
        'Огноо;Орлого;Зарлага;Харьцсан данс;Үлдэгдэл;Гүйлгээний утга\n'
        '2026.10.01;100 000,00;0,00;Ажил олгогч;100 000,00;Цалин\n'
        '2026.10.02;0,00;30 000,00;Номин;70 000,00;Худалдан авалт\n'
        '2026.10.03;0,00;8 000,00;Юнител;62 000,00;Төлбөр\n';

    testWidgets('Import transactions… in a bank account\'s header picks a '
        'file; the page shows the file\'s table with a choice over each '
        'column and the two counts; Import writes the rows with Undo, and '
        'the next file skips the columns', (tester) async {
      late AppDatabase db;
      late LedgerData data;
      late int bank, cash;
      await tester.runAsync(() async {
        db = AppDatabase(NativeDatabase.memory());
        await seedDemoIfEmpty(db, _now);
        bank = await db.addAccount(name: 'Statement', type: AccountType.asset);
        cash = await db.createAccount(
          name: 'Pocket',
          type: AccountType.asset,
          currency: Currency.mnt,
          cash: true,
        );
        final food = await db.createCategory('Food');
        // Typed before the bank had it: the file's row clears it.
        await db.postTransaction(
          date: DateTime(2026, 10, 3),
          payee: 'Unitel',
          lines: [
            (accountId: bank, amount: -800000, cleared: Cleared.uncleared),
            (accountId: food, amount: 800000, cleared: Cleared.uncleared),
          ],
        );
        data = await db.loadLedger();
      });
      addTearDown(() => tester.runAsync(db.close));
      final dialogs = _FakePicker();
      final before = FileSelectorPlatform.instance;
      FileSelectorPlatform.instance = dialogs;
      addTearDown(() => FileSelectorPlatform.instance = before);
      final store = await _pump(
        tester,
        snapshot: snapshotOf(data, today: _now, madeAt: _now),
      );
      final source = _ActingSource(db, () => _now, (d) => data = d);
      store.actRowIn = (act) => source.act(act);
      store.planImportIn = db.planImport;

      Future<void> run(Finder f) async {
        await tester.runAsync(() async {
          await tester.tap(f);
          await Future<void>.delayed(const Duration(milliseconds: 400));
        });
        for (var i = 0; i < 3; i++) {
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 200)),
          );
        }
        await tester.pumpAndSettle();
      }

      List<RegisterRow> rows() => data.registerFor(bank).posted;

      // A cash account has no bank file, so no Import.
      store.registerRequest.value = cash;
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('account-import')), findsNothing);
      store.registerRequest.value = bank;
      await tester.pumpAndSettle();
      expect(find.text('Import transactions…'), findsOneWidget);
      expect(find.byKey(const ValueKey('account-reconcile')), findsOneWidget);

      // The picker closed with nothing chosen: nothing opens.
      await run(find.byKey(const ValueKey('account-import')));
      expect(find.byKey(const ValueKey('import-page')), findsNothing);

      // A file with no dated rows says so, in the computer's words.
      dialogs.openPath = bankFile('notes.txt', 'Shopping list\nMilk\nBread\n');
      await run(find.byKey(const ValueKey('account-import')));
      expect(find.byKey(const ValueKey('import-page')), findsNothing);
      expect(
        find.text('notes.txt has no rows with a date in them.'),
        findsOneWidget,
      );

      dialogs.openPath = bankFile('statement.csv', statement);
      await run(find.byKey(const ValueKey('account-import')));
      expect(find.text('Import into Statement'), findsOneWidget);
      expect(find.text('statement.csv'), findsOneWidget);
      // The first file into the account: its own columns, a choice on each.
      expect(find.byKey(const ValueKey('import-columns')), findsOneWidget);
      expect(find.byKey(const ValueKey('import-role-0')), findsOneWidget);
      expect(find.text('Огноо'), findsOneWidget);
      expect(find.text('3 rows to import'), findsOneWidget);
      expect(
        find.text(
          'After this, the cleared balance matches the bank: ₮62,000.00.',
        ),
        findsOneWidget,
      );
      expect(find.text('Import 2 rows · clear 1'), findsOneWidget);
      await expectLater(
        find.byType(PhoneApp),
        matchesGoldenFile('goldens/phone_import.png'),
      );

      // The date column taken away: it says what is missing, and nothing
      // can be imported until it is back.
      await tester.tap(find.byKey(const ValueKey('import-role-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not used').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('import-need')), findsOneWidget);
      expect(find.byKey(const ValueKey('import-summary')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('import-role-0')));
      await tester.pumpAndSettle();
      await run(find.text('Date').last);
      expect(find.byKey(const ValueKey('import-need')), findsNothing);
      expect(find.text('3 rows to import'), findsOneWidget);

      await run(find.byKey(const ValueKey('import-do')));
      expect(find.byKey(const ValueKey('import-page')), findsNothing);
      expect(
        find.text(
          'Imported 2 rows · 1 typed row now cleared · 2 in “Not categorized”',
        ),
        findsOneWidget,
      );
      expect(rows(), hasLength(3));
      expect(rows().every((r) => r.cleared == Cleared.cleared), isTrue);

      // One Undo takes the file's rows out and the typed row back to
      // uncleared.
      await run(find.text('Undo'));
      expect(rows(), hasLength(1));
      expect(rows().single.cleared, Cleared.uncleared);

      // The same shape again: read with the columns kept, which Change
      // columns opens.
      await run(find.byKey(const ValueKey('account-import')));
      expect(
        find.text('Read with the columns you set for this account last time.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('import-columns')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('import-change-columns')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('import-columns')), findsOneWidget);
      // Cancel leaves the ledger as it was.
      await tester.tap(find.byKey(const ValueKey('import-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('import-page')), findsNothing);
      expect(rows(), hasLength(1));
    });

    testWidgets('Add account\'s "Or import a file from your bank" adds the '
        'account with no balance and opens its file, which says where the '
        'account starts; a file with no balance asks what is in it today '
        '(#531)', (tester) async {
      late AppDatabase db;
      late LedgerData data;
      await tester.runAsync(() async {
        db = AppDatabase(NativeDatabase.memory());
        await seedDemoIfEmpty(db, _now);
        data = await db.loadLedger();
      });
      addTearDown(() => tester.runAsync(db.close));
      final dialogs = _FakePicker();
      final before = FileSelectorPlatform.instance;
      FileSelectorPlatform.instance = dialogs;
      addTearDown(() => FileSelectorPlatform.instance = before);
      final store = await _pump(
        tester,
        snapshot: snapshotOf(data, today: _now, madeAt: _now),
      );
      final source = _ActingSource(db, () => _now, (d) => data = d);
      store.actRowIn = (act) => source.act(act);
      store.planImportIn = db.planImport;

      Future<void> run(Finder f) async {
        await tester.runAsync(() async {
          await tester.tap(f);
          await Future<void>.delayed(const Duration(milliseconds: 400));
        });
        for (var i = 0; i < 4; i++) {
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 200)),
          );
        }
        await tester.pumpAndSettle();
      }

      AccountInfo? named(String n) => data.accounts.values
          .where((a) => a.name == n && !a.deleted)
          .firstOrNull;

      Future<void> addAccount(String name) async {
        // The import's bar would sit over the way back.
        tester
            .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
            .removeCurrentSnackBar();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('to-budget')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Accounts'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('add-account')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(const ValueKey('add-account')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('account-name')),
          name,
        );
        await tester.pumpAndSettle();
      }

      await _toBudget(tester);
      await addAccount('Statement');
      // Cash has no file to import.
      await tester.tap(find.byKey(const ValueKey('kind-cash')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('new-account-import')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('kind-bank')));
      await tester.pumpAndSettle();
      // Offered while no balance is typed: the file answers it instead.
      await tester.enterText(
        find.byKey(const ValueKey('account-balance')),
        '5000',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('new-account-import')), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('account-balance')), '');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('new-account-import')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Or import a file from your bank'), findsOneWidget);

      dialogs.openPath = bankFile('statement.csv', statement);
      await run(find.byKey(const ValueKey('new-account-import')));
      final made = named('Statement')!;
      // The account is added, then the picker opens over its rows.
      for (var i = 0; i < 4; i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
      }
      await tester.pumpAndSettle();
      expect(find.text('Import into Statement'), findsOneWidget);
      // Nothing in the account yet: the file says where it starts, from
      // the budget period's first day, and no cleared-balance line.
      expect(find.byKey(const ValueKey('import-from')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('import-start'))).data,
        startsWith('This file starts at ₮0.00 on'),
      );
      expect(find.textContaining('the cleared balance'), findsNothing);
      await expectLater(
        find.byType(PhoneApp),
        matchesGoldenFile('goldens/phone_import_new_account.png'),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('import-start')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await run(find.byKey(const ValueKey('import-do')));
      expect(find.byKey(const ValueKey('import-page')), findsNothing);
      expect(data.registerFor(made.id).posted, hasLength(3));
      expect(data.summaryFor(made.id).working, 6200000);

      // A file with no balance column asks what's in the account today,
      // and works the start back from it through the rows.
      await addAccount('No balance');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('new-account-import')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      dialogs.openPath = bankFile(
        'plain.csv',
        'Огноо;Орлого;Зарлага;Гүйлгээний утга\n'
            '2026.10.02;0,00;30 000,00;Номин\n'
            '2026.10.03;0,00;8 000,00;Юнител\n',
      );
      await run(find.byKey(const ValueKey('new-account-import')));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
      }
      await tester.pumpAndSettle();
      final plain = named('No balance')!;
      expect(
        find.textContaining('This file doesn’t give a balance.'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('import-today')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const ValueKey('import-today')),
        '62000',
      );
      await tester.pumpAndSettle();
      await run(find.byKey(const ValueKey('import-do')));
      expect(data.registerFor(plain.id).posted, hasLength(3));
      expect(data.summaryFor(plain.id).working, 6200000);
      // The opening balance worked back from it is in the import's one
      // Undo: the account is empty again.
      await run(find.text('Undo'));
      expect(data.registerFor(plain.id).posted, isEmpty);
      expect(data.summaryFor(plain.id).working, 0);
      // What Undo says goes away on its own.
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pump(const Duration(seconds: 10));
      }
      await tester.pumpAndSettle();
    });

    /// A phone on [db]'s ledger with the import's acts wired to it.
    Future<(PhoneStore, LedgerData Function())> importPhone(
      WidgetTester tester,
      AppDatabase db,
    ) async {
      late LedgerData data;
      await tester.runAsync(() async => data = await db.loadLedger());
      final store = await _pump(
        tester,
        snapshot: snapshotOf(data, today: _now, madeAt: _now),
      );
      final source = _ActingSource(db, () => _now, (d) => data = d);
      store.actRowIn = (act) => source.act(act);
      store.planImportIn = db.planImport;
      return (store, () => data);
    }

    Future<void> settleImport(WidgetTester tester, [Finder? tap]) async {
      await tester.runAsync(() async {
        if (tap != null) await tester.tap(tap);
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      for (var i = 0; i < 3; i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
      }
      await tester.pumpAndSettle();
    }

    SentFile sentCsv(String name, String text) =>
        (name: name, bytes: Uint8List.fromList(utf8.encode(text)));

    testWidgets('a file sent from another app asks which account it is for, '
        'with nothing picked, then opens the import page; the Ledger shows '
        'that account once its rows are in', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() => tester.runAsync(db.close));
      await tester.runAsync(() => seedDemoIfEmpty(db, _now));
      final (store, data) = await importPhone(tester, db);
      final khan = data().accounts.values.firstWhere(
        (a) => a.name == 'Khan Savings',
      );
      final before = data().registerFor(khan.id).posted.length;

      store.sent.value = sentCsv('statement.csv', statement);
      await tester.pumpAndSettle();
      expect(find.text('Which account is this file for?'), findsOneWidget);
      expect(find.text('statement.csv'), findsOneWidget);
      expect(find.text('Rows from 10.01 to 10.03'), findsOneWidget);
      // Banks and the card, not cash.
      expect(find.text('TDB Checking'), findsOneWidget);
      expect(find.text('Khan Savings'), findsOneWidget);
      expect(find.text('Golomt Visa'), findsOneWidget);
      expect(find.text('Cash wallet'), findsNothing);
      expect(store.sent.value, isNull);
      await expectLater(
        find.byType(PhoneApp),
        matchesGoldenFile('goldens/phone_import_which_account.png'),
      );

      // Back leaves the file and the ledger as they were.
      await tester.tap(find.byKey(const ValueKey('import-which-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('import-which-account')), findsNothing);
      expect(store.importing.value, isFalse);

      store.sent.value = sentCsv('statement.csv', statement);
      await tester.pumpAndSettle();
      await settleImport(
        tester,
        find.byKey(ValueKey('import-into-${khan.id}')),
      );
      expect(find.text('Import into Khan Savings'), findsOneWidget);
      await settleImport(tester, find.byKey(const ValueKey('import-do')));
      expect(find.byKey(const ValueKey('import-page')), findsNothing);
      expect(data().registerFor(khan.id).posted.length, before + 3);
      // The Ledger is on Khan Savings, its header over its rows.
      expect(find.byKey(const ValueKey('account-import')), findsOneWidget);
      expect(find.text('Khan Savings'), findsWidgets);
    });

    testWidgets('a file sent with one bank account goes straight to its '
        'page; with none, it says to add one; a locked or unreadable file '
        'says so before anything is asked', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() => tester.runAsync(db.close));
      await tester.runAsync(
        () => db.addAccount(
          name: 'Pocket',
          type: AccountType.asset,
          group: LedgerGroups.cash,
        ),
      );
      final (store, _) = await importPhone(tester, db);

      store.sent.value = sentCsv('statement.csv', statement);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'To import statement.csv, first add the bank account or card '
          'it’s from on Accounts.',
        ),
        findsOneWidget,
      );

      store.sent.value = (name: 'statement.xls', bytes: lockedXlsx());
      await tester.pumpAndSettle();
      expect(find.textContaining('statement.xls is locked.'), findsOneWidget);
      store.sent.value = (name: 'statement.xls', bytes: Uint8List(0));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Couldn’t read statement.xls. The file may be damaged; download '
          'it from your bank again.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('import-which-account')), findsNothing);

      await tester.runAsync(
        () => db.addAccount(name: 'Statement', type: AccountType.asset),
      );
      final (again, _) = await importPhone(tester, db);
      again.sent.value = sentCsv('statement.csv', statement);
      await settleImport(tester);
      expect(find.byKey(const ValueKey('import-which-account')), findsNothing);
      expect(find.text('Import into Statement'), findsOneWidget);
    });

    testWidgets('a file sent while a reconcile is open waits until it ends', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() => tester.runAsync(db.close));
      await tester.runAsync(
        () => db.addAccount(name: 'Statement', type: AccountType.asset),
      );
      final (store, _) = await importPhone(tester, db);
      store.reconciling.value = true;
      store.sent.value = sentCsv('statement.csv', statement);
      await settleImport(tester);
      expect(find.byKey(const ValueKey('import-page')), findsNothing);
      expect(store.sent.value, isNotNull);
      store.reconciling.value = false;
      await settleImport(tester);
      expect(find.text('Import into Statement'), findsOneWidget);
      expect(store.sent.value, isNull);
    });

    testWidgets('a locked file picked with Import transactions… says so '
        '(#531)', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() => tester.runAsync(db.close));
      late int bank;
      await tester.runAsync(
        () async => bank = await db.addAccount(
          name: 'Statement',
          type: AccountType.asset,
        ),
      );
      final dialogs = _FakePicker();
      final was = FileSelectorPlatform.instance;
      FileSelectorPlatform.instance = dialogs;
      addTearDown(() => FileSelectorPlatform.instance = was);
      final (store, _) = await importPhone(tester, db);
      final dir = Directory.systemTemp.createTempSync('bb-locked');
      addTearDown(() => dir.deleteSync(recursive: true));
      dialogs.openPath = (File(
        '${dir.path}/locked.xlsx',
      )..writeAsBytesSync(lockedXlsx())).path;
      store.registerRequest.value = bank;
      await tester.pumpAndSettle();
      await settleImport(tester, find.byKey(const ValueKey('account-import')));
      expect(find.byKey(const ValueKey('import-page')), findsNothing);
      expect(
        find.text(
          'locked.xlsx is locked. Open it in Excel or Numbers (type its '
          'password if it asks for one), save a copy without a password, and '
          'import that copy.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a new account\'s file starts from the budget period, the '
        'earlier rows left out until The whole file; a card\'s typed balance '
        'is what it owes; a balance that can\'t be read stops Import (from '
        'the review of #596)', (tester) async {
      Future<(AppDatabase, int, PhoneStore, LedgerData Function())> phoneWith(
        AccountType type,
      ) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => tester.runAsync(db.close));
        late int id;
        await tester.runAsync(
          () async => id = await db.addAccount(name: 'Statement', type: type),
        );
        final (store, data) = await importPhone(tester, db);
        return (db, id, store, data);
      }

      Future<void> into(Finder f) async {
        await tester.scrollUntilVisible(
          f,
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
      }

      // Two September rows and one in October, the budget's period.
      var (_, bank, store, data) = await phoneWith(AccountType.asset);
      store.sent.value = sentCsv(
        'statement.csv',
        'Огноо;Орлого;Зарлага;Харьцсан данс;Үлдэгдэл;Гүйлгээний утга\n'
            '2026.09.20;100 000,00;0,00;Ажил олгогч;100 000,00;Цалин\n'
            '2026.09.25;0,00;30 000,00;Номин;70 000,00;Худалдан авалт\n'
            '2026.10.02;0,00;8 000,00;Юнител;62 000,00;Төлбөр\n',
      );
      await settleImport(tester);
      expect(find.text('Import into Statement'), findsOneWidget);
      await into(find.byKey(const ValueKey('import-earlier')));
      expect(
        find.text('2 earlier rows in this file are left out'),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('import-start'))).data,
        contains('₮70,000.00'),
      );
      await into(find.byKey(const ValueKey('import-whole-file')));
      await settleImport(
        tester,
        find.byKey(const ValueKey('import-whole-file')),
      );
      expect(find.byKey(const ValueKey('import-earlier')), findsNothing);
      await settleImport(tester, find.byKey(const ValueKey('import-do')));
      expect(data().registerFor(bank).posted, hasLength(3));
      expect(data().summaryFor(bank).working, 6200000);

      // A card, with no balance in its file: what is typed is what it owes
      // today, and the start is worked back through the rows.
      const plain =
          'Огноо;Орлого;Зарлага;Гүйлгээний утга\n'
          '2026.10.02;0,00;30 000,00;Номин\n'
          '2026.10.03;0,00;8 000,00;Юнител\n';
      int card;
      (_, card, store, data) = await phoneWith(AccountType.liability);
      store.sent.value = sentCsv('card.csv', plain);
      await settleImport(tester);
      await into(find.byKey(const ValueKey('import-today')));
      await tester.enterText(
        find.byKey(const ValueKey('import-today')),
        '62000',
      );
      await tester.pumpAndSettle();
      await settleImport(tester, find.byKey(const ValueKey('import-do')));
      // The two rows and the opening balance worked back from it.
      expect(data().registerFor(card).posted, hasLength(3));
      expect(data().summaryFor(card).working, -6200000);

      // A balance that isn't an amount: said under the field, and Import
      // writes nothing until it is one.
      (_, bank, store, data) = await phoneWith(AccountType.asset);
      store.sent.value = sentCsv('plain.csv', plain);
      await settleImport(tester);
      await into(find.byKey(const ValueKey('import-today')));
      await tester.enterText(find.byKey(const ValueKey('import-today')), 'abc');
      await tester.pumpAndSettle();
      expect(find.text('“abc” isn’t an amount'), findsOneWidget);
      await settleImport(tester, find.byKey(const ValueKey('import-do')));
      expect(find.byKey(const ValueKey('import-page')), findsOneWidget);
      expect(data().registerFor(bank).posted, isEmpty);
    });

    testWidgets('a row that may have paid a bill: the bar after the import '
        'has Show, which opens that row where it is, with the question '
        'under it', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() => tester.runAsync(db.close));
      late int bank;
      await tester.runAsync(() async {
        bank = await db.addAccount(name: 'Statement', type: AccountType.asset);
        final phone = await db.createCategory('Phone');
        await db.setCategoryPlan(
          phone,
          CategoryPlan(
            categoryId: phone,
            kind: PlanKind.byDate,
            amount: 3000000,
            start: DateTime(2026, 10, 1),
            due: DateTime(2026, 10, 2),
            everyMonths: 1,
            paidFrom: bank,
          ),
        );
        await db.ensurePlanBills(DateTime(2026, 10, 1), only: phone);
        await db.rememberPayee(
          accountId: bank,
          payee: 'Мобиком',
          categoryId: phone,
        );
      });
      final (store, data) = await importPhone(tester, db);
      store.registerRequest.value = bank;
      await tester.pumpAndSettle();
      // Two thirds of the bill: asked about, not taken as paid.
      store.sent.value = sentCsv(
        'statement.csv',
        'Огноо;Орлого;Зарлага;Харьцсан данс;Үлдэгдэл;Гүйлгээний утга\n'
            '2026.10.02;0,00;20 000,00;Мобиком;-20 000,00;Төлбөр\n',
      );
      await settleImport(tester);
      await settleImport(tester, find.byKey(const ValueKey('import-do')));
      expect(find.textContaining('1 bill to check'), findsOneWidget);
      final row = data().registerFor(bank).posted.single;
      expect(
        find.byKey(ValueKey('register-open-${row.txnId}-${row.entryId}')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('import-show')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('register-open-${row.txnId}-${row.entryId}')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('paid-yes')), findsOneWidget);
      // The bar and its Undo are still there.
      expect(find.byKey(const ValueKey('import-done')), findsOneWidget);
    });
  });
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Stands in for the phone's browser: keeps each link it was asked to open.
class _FakeBrowser extends UrlLauncherPlatform {
  final opened = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened.add(url);
    return true;
  }
}

/// A time as Copy all writes it.
String _stamp(DateTime at) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${at.year}-${two(at.month)}-${two(at.day)} '
      '${two(at.hour)}:${two(at.minute)}';
}

/// Stands in for the phone's own file picker.
class _FakePicker extends FileSelectorPlatform {
  String? openPath;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => openPath == null ? null : XFile(openPath!);
}
