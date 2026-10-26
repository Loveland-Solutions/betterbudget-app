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
import 'package:betterbudget/data/problem_log.dart';
import 'package:betterbudget/domain/budget.dart';
import 'package:betterbudget/domain/ledger.dart'
    show AccountType, CategoryPlan, LedgerData, PlanKind, RowKind;
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
import 'package:url_launcher_platform_interface/link.dart' show LinkDelegate;
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

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
  await tester.tap(find.text('Add'));
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

  testWidgets('Report a problem… ends Budget and opens the form', (
    tester,
  ) async {
    final browser = _FakeBrowser();
    final before = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = browser;
    addTearDown(() => UrlLauncherPlatform.instance = before);
    await _pump(tester);
    await _toBudget(tester);
    final line = find.byKey(const ValueKey('report-problem'));
    await tester.scrollUntilVisible(
      line,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(line);
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

  testWidgets('Recent problems sits above Report a problem… while there are '
      'any, and Copy all copies them', (tester) async {
    final dir = _phoneDir();
    final problems = ProblemLog(
      File('${dir.path}/problems'),
      now: () => _now,
      version: () async => '0.56.0',
    );
    await _pump(tester, problems: problems);
    await _toBudget(tester);
    final report = find.byKey(const ValueKey('report-problem'));
    await tester.scrollUntilVisible(
      report,
      200,
      scrollable: find.byType(Scrollable).last,
    );
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

  testWidgets('New category on the phone asks everything the computer\'s '
      'window does, and the bill goes with the category', (tester) async {
    final store = await _pump(tester);
    await _toBudget(tester);
    await tester.tap(find.byKey(const ValueKey('budget-new-category')));
    await tester.pumpAndSettle();
    // One page, as on the computer: the name, then is there a due date.
    expect(find.text('Is there a due date?'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('new-category-name')),
      'Mobicom',
    );
    await tester.tap(find.byKey(const ValueKey('plan-dated-yes')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('plan-amount')), '45000');
    await tester.tap(find.byKey(const ValueKey('plan-repeat')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every month'));
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
    await tester.tap(find.byKey(const ValueKey('new-category-another')));
    await tester.pumpAndSettle();
    expect(find.text('Added: Taxi'), findsOneWidget);
    expect(store.made.single.plan, isNull);

    // A bill with no amount: nothing is made, and the page stays.
    await tester.enterText(
      find.byKey(const ValueKey('new-category-name')),
      'Gym',
    );
    await tester.tap(find.byKey(const ValueKey('plan-dated-yes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new-category-add')));
    await tester.pumpAndSettle();
    expect(store.made, hasLength(1));
    expect(find.text('New category'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan-dated-no')));
    await tester.pumpAndSettle();
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
    expect(find.text('Waiting for your computer'), findsOneWidget);
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
    // The ring before Groceries: ₮752,000 of ₮900,000 used; a bill has
    // none (#241).
    expect(find.byKey(const ValueKey('used-g')), findsOneWidget);
    expect(find.byKey(const ValueKey('used-r')), findsNothing);
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
      expect(p.paidFrom, 3);
      expect(p.rollover, isTrue);

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
        ],
      );
      final take = (await db.takePhoneEntries([inbox], today: today))!;
      data = await db.loadLedger();
      final mobicom = id('Mobicom');
      final plan = data.plans[mobicom]!;
      expect(plan.kind, PlanKind.byDate);
      expect(plan.amount, 4500000);
      expect(plan.everyMonths, 1);
      expect(plan.paidFrom, checking);
      expect(data.accountsOff[mobicom], {savings});
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
    Future<({_FakeKeys keys, _FakeFolder folder, List<Uint8List> read})> start(
      WidgetTester tester, {
      _FakeKeys? keys,
      _FakeFolder? folder,
      Uint8List? opens,
      Directory? dir,
      Map<String, PhoneTaken> Function()? taken,
      ProblemLog? problems,
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
            problems: problems,
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
      expect(find.byKey(const ValueKey('report-problem')), findsOneWidget);
      await tester.tap(find.text('Enter the key again'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your recovery key'), findsOneWidget);
      // Typing the key is no problem yet.
      expect(find.byKey(const ValueKey('report-problem')), findsNothing);
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

    testWidgets('a problem screen ends with Report a problem…', (tester) async {
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
