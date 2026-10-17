// The phone screens (ADR 0005; ADR 0004 "Phone screens"): Ledger, where a
// transaction is typed and its category picked or made, and Budget, what is
// left in each category. Drawn on a 390 × 844 phone.
import 'dart:io';

import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/data/encryption.dart';
import 'package:betterbudget/data/keys.dart';
import 'package:betterbudget/data/ledger_file.dart';
import 'package:betterbudget/data/phone_inbox.dart';
import 'package:betterbudget/data/phone_ledger.dart';
import 'package:betterbudget/domain/budget.dart';
import 'package:betterbudget/domain/ledger.dart' show AccountType, RowKind;
import 'package:betterbudget/domain/money.dart';
import 'package:betterbudget/domain/phone.dart';
import 'package:betterbudget/domain/sync.dart' show MadeHow;
import 'package:betterbudget/phone_preview.dart';
import 'package:betterbudget/ui/phone/phone_app.dart';
import 'package:betterbudget/ui/phone/phone_start.dart';
import 'package:betterbudget/ui/schemes.dart';
import 'package:betterbudget/ui/theme.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

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
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = PhoneStore(
    snapshot ?? previewSnapshot(DateTime(2026, 10, 7, 8, 10)),
  );
  await tester.pumpWidget(PhoneApp(store: store, now: () => _now));
  await tester.pumpAndSettle();
  return store;
}

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

Future<void> _toLedger(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('to-ledger')));
  await tester.pumpAndSettle();
}

/// Picks [name] from the category list on the entry screen.
Future<void> _category(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('category-row')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
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

  @override
  Future<String?> pick() async => picked = willPick ?? picked;

  @override
  Future<String?> kept() async => picked;

  @override
  Future<({Uint8List bytes, DateTime? changed})?> read(
    String folder,
    String name,
  ) async {
    asked.add(name);
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
    await tester.tap(find.text('Groceries'));
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
    expect(
      find.text('1 of your entries is waiting for your computer'),
      findsOneWidget,
    );
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
    expect(find.text('Groceries'), findsNothing);
    expect(find.byKey(const ValueKey('split-option')), findsNothing);
    await tester.tap(find.text('Clothing'));
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
    expect(
      find.text('Groceries · ₮50,000.00 left\nClothing · ₮42,500.00 left'),
      findsOneWidget,
    );
    await _toBudget(tester);
    expect(find.text('₮50,000.00'), findsOneWidget);
    expect(find.text('₮42,500.00'), findsOneWidget);
  });

  testWidgets('typing narrows the list, and Done takes the first that fits', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('category-field')), 'e');
    await tester.pump();
    // Begins with it, before the names that only hold it.
    expect(
      tester.getTopLeft(find.text('Eating out')).dy,
      lessThan(tester.getTopLeft(find.text('Groceries')).dy),
    );
    expect(find.text('Transport'), findsNothing);
    expect(find.text('+ New category “e”'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Eating out'), findsOneWidget);
    expect(find.text('Overspent by ₮18,400.00'), findsOneWidget);
    // Its account in the ledger is the Visa; Paid from is still theirs.
    expect(find.text('Golomt Visa'), findsNothing);
  });

  testWidgets(
    'a name that isn’t a category makes one, waiting for your computer',
    (tester) async {
      final store = await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('category-row')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('category-field')),
        'Cof',
      );
      await tester.pump();
      expect(find.text('Groceries'), findsNothing);
      // Done makes nothing: only the row does.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(store.made, isEmpty);
      await tester.tap(find.text('+ New category “Cof”'));
      await tester.pumpAndSettle();
      final made = store.made.single;
      expect(made.name, 'Cof');
      expect(made.currency, Currency.mnt);
      // Back on the entry with it chosen; it isn't called overspent.
      expect(find.text('Cof'), findsOneWidget);
      expect(find.text('Nothing assigned yet'), findsOneWidget);
      expect(
        find.text('1 new category is waiting for your computer'),
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
        find.text(
          '1 of your entries and 1 new category are waiting for your computer',
        ),
        findsOneWidget,
      );

      // A name that is already a category is listed, not offered again.
      await tester.tap(find.byKey(const ValueKey('category-row')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('category-field')),
        'cof',
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('new-category')), findsNothing);
      expect(find.text('Cof'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

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
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(store.made.single.name, 'Vet');
    // It lands with the money to spend, above the bills.
    await tester.scrollUntilVisible(find.text('Vet'), 100);
    expect(find.text('Vet'), findsOneWidget);
  });

  testWidgets('a category on Budget starts an entry in it, and what was '
      'typed stays', (tester) async {
    await _pump(tester);
    await _type(tester, '500');
    await _toBudget(tester);
    await tester.tap(find.text('Transport'));
    await tester.pumpAndSettle();
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

  testWidgets('a waiting entry can be deleted, and Left goes back', (
    tester,
  ) async {
    final store = await _pump(tester);
    await _spend(tester, 'Transport', '8000', 'ub', pick: 'UB Cab');
    await _toBudget(tester);
    expect(find.text('₮53,500.00'), findsOneWidget);
    await _toLedger(tester);

    await tester.tap(
      find.text('1 of your entries is waiting for your computer'),
    );
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
      await tester.tap(find.byKey(const ValueKey('category-row')));
      await tester.pumpAndSettle();
      // The accounts are the list's last rows.
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -3000));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }

    // The accounts are at the foot of the Category list, under a heading.
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('→ Golomt Visa'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
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
    await tester.scrollUntilVisible(
      find.text('→ Golomt Visa'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('→ Cash wallet'), findsNothing);
    expect(find.text('→ TDB Checking'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sign')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('Move to an account'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    // "ATM" typed is someone looking for these, not a new category's name.
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('category-field')), 'ATM');
    await tester.pump();
    expect(find.text('Move to an account'), findsOneWidget);
    expect(find.text('→ Cash wallet'), findsOneWidget);
    expect(find.text('→ TDB Checking'), findsOneWidget);
    // An account's name narrows them, and Done takes it when no category
    // fits.
    await tester.enterText(
      find.byKey(const ValueKey('category-field')),
      'cash w',
    );
    await tester.pump();
    expect(find.text('→ TDB Checking'), findsNothing);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('→ Cash wallet'), findsOneWidget);
    expect(find.text('From'), findsOneWidget);

    // A payee typed before the transfer was picked isn't kept out of sight.
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
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
    await tester.enterText(
      find.byKey(const ValueKey('category-field')),
      'income',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('new-category')), findsNothing);
    // Not a blank page: it says how income is recorded.
    expect(
      find.text('To record income, tap +/− beside the amount first.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Money in: Income is the list's first line, with no figure beside it.
    await tester.tap(find.byKey(const ValueKey('sign')));
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Income')).dy,
      lessThan(tester.getTopLeft(find.text('Groceries')).dy),
    );
    // Its name in the other language finds it too.
    await tester.enterText(
      find.byKey(const ValueKey('category-field')),
      'орлого',
    );
    await tester.pump();
    expect(find.text('Income'), findsOneWidget);
    expect(find.byKey(const ValueKey('new-category')), findsNothing);
    await tester.tap(find.text('Income'));
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
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('category-field')),
      'Coffee',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('new-category')));
    await tester.pumpAndSettle();
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
          const PhoneCategory(id: 'g', name: 'Groceries', leftMinor: 14800000),
        ],
      ),
    );
    await _toBudget(tester);
    // A budget that runs by pay periods says when this one ends.
    expect(find.text('Left until 10.14'), findsOneWidget);
    expect(find.text('Due 10.20'), findsOneWidget);
    final groceries = tester.getTopLeft(find.text('Groceries')).dy;
    final add = tester.getTopLeft(find.text('+ New category')).dy;
    final heading = tester.getTopLeft(find.text('Bills')).dy;
    final rent = tester.getTopLeft(find.text('Rent')).dy;
    expect(groceries, lessThan(add));
    expect(add, lessThan(heading));
    expect(heading, lessThan(rent));
    // Its amount is drawn quieter than money to spend.
    final spend = tester.widget<Text>(find.text('₮148,000.00')).style!.color;
    final bill = tester.widget<Text>(find.text('₮1,800,000.00')).style!.color;
    expect(bill, isNot(spend));

    // It can still be paid from here.
    await tester.tap(find.text('Rent'));
    await tester.pumpAndSettle();
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
    await tester.tap(find.text('Trip'));
    await tester.pumpAndSettle();
    expect(find.text('−¥12'), findsOneWidget);
    await _payee(tester, 'Lawson');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.waiting.single.amountMinor, -12);
    expect(find.text('Undo'), findsOneWidget);

    // The next entry is begun from Budget: Undo would write over it.
    await _toBudget(tester);
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
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
      find.text(
        '1 of your entries and 1 new category are waiting for your computer',
      ),
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

    test(
      'the encrypted ledger opens with its key and not with another',
      () async {
        final dir = await Directory.systemTemp.createTemp('bb-phone');
        addTearDown(() => dir.delete(recursive: true));
        final key = deriveDataKey(RecoveryKey.generate());
        final file = File('${dir.path}/$ledgerFileName');
        final db = AppDatabase(
          NativeDatabase(file, setup: (raw) => applyCipherKey(raw, key)),
        );
        await seedDemoIfEmpty(db, today);
        await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
        final names = {
          for (final a in (await db.loadLedger()).accounts.values) a.name,
        };
        await db.close();
        final bytes = await file.readAsBytes();
        final private = Directory('${dir.path}/phone');

        final snapshot = await readPhoneLedger(
          bytes,
          key,
          dir: private,
          today: today,
          madeAt: today,
        );
        expect(names, containsAll(snapshot.categories.map((c) => c.name)));
        expect(snapshot.categories, isNotEmpty);
        // The file in the folder is never the one that is opened.
        expect(await file.readAsBytes(), bytes);

        await expectLater(
          readPhoneLedger(
            bytes,
            deriveDataKey(RecoveryKey.generate()),
            dir: private,
            today: today,
            madeAt: today,
          ),
          throwsA(isA<WrongKeyException>()),
        );
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
          // A category gone from the ledger: left with the phone.
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
      expect(take.transactionIds, hasLength(1));
      data = await db.loadLedger();
      expect(data.balanceOf(checking), before - 13550000);
      final row = data
          .registerFor(checking)
          .posted
          .singleWhere((r) => r.txnId == take.transactionIds.single);
      expect(row.kind, RowKind.split);
      expect(row.madeHow, MadeHow.phone);
      expect(row.splitLines.map((l) => (l.name, l.amount)), [
        ('Groceries', -9800000),
        ('Shoes', -3750000),
      ]);
      expect(
        snapshotOf(data, today: today, madeAt: today).taken['ab12']!.entries,
        {'s1'},
      );

      // Undo takes the split row and the category it made; redo brings
      // both back.
      await db.undoPhoneTake(take);
      data = await db.loadLedger();
      expect(data.balanceOf(checking), before);
      expect(data.categories.any((c) => c.name == 'Shoes'), isFalse);
      await db.redoPhoneTake(take);
      data = await db.loadLedger();
      expect(data.balanceOf(checking), before - 13550000);
    });

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
    Future<({_FakeKeys keys, _FakeFolder folder, List<Uint8List> read})> start(
      WidgetTester tester, {
      _FakeKeys? keys,
      _FakeFolder? folder,
      Uint8List? opens,
      Directory? dir,
      Map<String, PhoneTaken> Function()? taken,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final k = keys ?? _FakeKeys();
      final f = folder ?? _FakeFolder();
      final read = <Uint8List>[];
      await tester.pumpWidget(
        PhoneFrame(
          child: PhoneStart(
            keys: k,
            folder: f,
            dir: dir ?? _phoneDir(),
            now: () => _now,
            read:
                (
                  bytes,
                  key, {
                  required dir,
                  required today,
                  required madeAt,
                }) async {
                  read.add(key);
                  if (opens != null && !_same(key, opens)) {
                    throw WrongKeyException();
                  }
                  final snapshot = previewSnapshot(madeAt);
                  return taken == null
                      ? snapshot
                      : PhoneSnapshot(
                          madeAt: snapshot.madeAt,
                          categories: snapshot.categories,
                          accounts: snapshot.accounts,
                          payees: snapshot.payees,
                          taken: taken(),
                        );
                },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (keys: k, folder: f, read: read);
    }

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
      await tester.tap(find.text('Enter the key again'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your recovery key'), findsOneWidget);
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
            read:
                (
                  bytes,
                  key, {
                  required dir,
                  required today,
                  required madeAt,
                }) async {
                  // Half-arrived: the key that opened it before no longer does.
                  if (broken) throw WrongKeyException();
                  return previewSnapshot(madeAt);
                },
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
      expect(
        find.text('1 of your entries is waiting for your computer'),
        findsOneWidget,
      );

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

    testWidgets('while an entry waits the folder is asked every half minute, '
        'and the ledger fetched only when it has changed', (tester) async {
      final keys = _FakeKeys()..kept = deriveDataKey(RecoveryKey.generate());
      final folder = _FakeFolder()..picked = 'drive:BetterBudget';
      final s = await start(tester, keys: keys, folder: folder);
      // Nothing waiting: nothing to look for.
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(s.read, hasLength(1));

      await _spend(tester, 'Transport', '8000', 'ub', pick: 'UB Cab');
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      // Asked, and the same ledger is still there: not fetched again.
      expect(s.read, hasLength(1));

      folder.changedAt = DateTime(2026, 10, 7, 14, 6);
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(s.read, hasLength(2));

      // A folder that goes on giving the old time is fetched anyway on
      // every fourth look.
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(s.read, hasLength(2));
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(s.read, hasLength(3));
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
      expect(s.read.length, 2);
      expect(s.folder.asked.toSet(), {ledgerFileName});
      expect(
        find.text('1 of your entries is waiting for your computer'),
        findsOneWidget,
      );
      await _toBudget(tester);
      expect(find.text('₮53,500.00'), findsOneWidget);
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
