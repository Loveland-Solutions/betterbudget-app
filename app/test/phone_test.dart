// The phone screens (ADR 0005; ADR 0004 "Phone screens"): Ledger, where a
// transaction is typed and its category picked or made, and Budget, what is
// left in each category. Drawn on a 390 × 844 phone.
import 'dart:io';

import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/data/encryption.dart';
import 'package:betterbudget/data/keys.dart';
import 'package:betterbudget/data/ledger_file.dart';
import 'package:betterbudget/data/phone_ledger.dart';
import 'package:betterbudget/domain/budget.dart';
import 'package:betterbudget/domain/money.dart';
import 'package:betterbudget/domain/phone.dart';
import 'package:betterbudget/phone_preview.dart';
import 'package:betterbudget/ui/phone/phone_app.dart';
import 'package:betterbudget/ui/phone/phone_start.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// A whole entry: category, amount, payee, Save.
Future<void> _spend(
  WidgetTester tester,
  String category,
  String amount,
  String payee, {
  String? pick,
}) async {
  await _category(tester, category);
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
  DateTime? changed = DateTime(2026, 10, 7, 13, 30);
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
    return bytes == null ? null : (bytes: bytes, changed: changed);
  }

  @override
  Future<void> forget(String folder) async => forgotten.add(folder);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() async {
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

  testWidgets('opens on Ledger with nothing chosen', (tester) async {
    await _pump(tester);
    expect(find.text('−₮0'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Payee'), findsOneWidget);
    // Paid from and Date have their defaults; no category, so nothing is
    // said about what is left.
    expect(find.text('TDB Checking'), findsOneWidget);
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
    expect(find.text('From your Mac today 08:10'), findsOneWidget);
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
    expect(find.text('From your Mac 2026.10.06 21:40'), findsOneWidget);
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
    expect(find.text('−₮0'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);
    expect(
      find.text('1 of your entries is waiting for the Mac'),
      findsOneWidget,
    );
    await _toBudget(tester);
    expect(find.text('₮135,500.00'), findsOneWidget);
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
    // Paid from follows the category until an account is chosen by hand.
    expect(find.text('Golomt Visa'), findsOneWidget);
  });

  testWidgets('a name that isn’t a category makes one, waiting for the Mac', (
    tester,
  ) async {
    final store = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('category-field')), 'Cof');
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
    expect(find.text('1 new category is waiting for the Mac'), findsOneWidget);

    await _type(tester, '4500');
    expect(find.text('Nothing assigned yet'), findsOneWidget);
    await _payee(tester, 'Tom N Toms');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.waiting.single.categoryId, made.id);
    expect(
      find.text('1 of your entries and 1 new category are waiting for the Mac'),
      findsOneWidget,
    );

    // A name that is already a category is listed, not offered again.
    await tester.tap(find.byKey(const ValueKey('category-row')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('category-field')), 'cof');
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
  });

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
    expect(find.text('Cash wallet'), findsOneWidget);
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
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Choose a category'), findsOneWidget);

      await _category(tester, 'Clothing');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Enter a payee'), findsOneWidget);
      expect(store.waiting, isEmpty);

      // A payee the ledger has never seen is typed in full.
      await _payee(tester, 'Shoppy');
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

    await tester.tap(find.text('1 of your entries is waiting for the Mac'));
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
    await _spend(tester, 'Eating out', '30000', 'Rosewood');

    await _toBudget(tester);
    final line = tester.widget<Text>(find.byKey(const ValueKey('from-mac')));
    expect(line.data, 'From your Mac 2026.10.01 21:40');
    expect(line.style!.color, isNot(equals(null)));
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    expect(find.text('₮2,419,300.00'), findsOneWidget);
    expect(find.text('Owed ₮342,000.00'), findsOneWidget);
    expect(find.text('From your Mac 2026.10.01 21:40'), findsOneWidget);
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
      find.text('1 of your entries and 1 new category are waiting for the Mac'),
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

  group('first launch', () {
    Future<({_FakeKeys keys, _FakeFolder folder, List<Uint8List> read})> start(
      WidgetTester tester, {
      _FakeKeys? keys,
      _FakeFolder? folder,
      Uint8List? opens,
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
            dir: Directory.systemTemp,
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
                  return previewSnapshot(madeAt);
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
      expect(find.text('From your Mac today 13:30'), findsOneWidget);
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
            dir: Directory.systemTemp,
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
        find.text('1 of your entries is waiting for the Mac'),
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
