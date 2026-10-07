// The phone screens (ADR 0005; ADR 0004 "Phone screens"): what is left in each
// category, and the amount pad a category's + opens. Drawn on a 390 × 844 phone.
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

Future<PhoneStore> _pump(WidgetTester tester, {PhoneSnapshot? snapshot}) async {
  tester.view.physicalSize = const Size(390, 844);
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

  testWidgets('opens on what is left, with the cents where there is room', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Left in October'), findsOneWidget);
    expect(find.text('From your Mac today 08:10'), findsOneWidget);
    expect(find.text('₮148,000.00'), findsOneWidget);
    expect(find.text('−₮18,400.00'), findsOneWidget);
    // Nothing is waiting, so nothing is said about waiting.
    expect(find.textContaining('waiting for the Mac'), findsNothing);
    await expectLater(
      find.byType(PhoneApp),
      matchesGoldenFile('goldens/phone_left.png'),
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
            leftMinor: 1234567800,
          ),
        ],
      ),
    );
    expect(find.text('₮12,345,678'), findsOneWidget);
    expect(find.text('From your Mac 2026.10.06 21:40'), findsOneWidget);
  });

  testWidgets('a category’s + opens the pad, and Save takes it from Left', (
    tester,
  ) async {
    final store = await _pump(tester);
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
      matchesGoldenFile('goldens/phone_spend.png'),
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
    expect(entry.accountId, 'tdb');
    expect(entry.date, DateTime(2026, 10, 7));
    expect(find.text('₮135,500.00'), findsOneWidget);
    expect(
      find.text('1 of your entries is waiting for the Mac'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Save with nothing typed says what is missing and saves nothing',
    (tester) async {
      final store = await _pump(tester);
      await tester.tap(find.text('Clothing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Enter an amount'), findsOneWidget);

      // Clothing has no payees yet, so an amount alone still isn't enough.
      await _type(tester, '5');
      expect(find.text('Enter an amount'), findsNothing);
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

  testWidgets('Cancel leaves nothing behind', (tester) async {
    final store = await _pump(tester);
    await tester.tap(find.text('Transport'));
    await tester.pumpAndSettle();
    await _type(tester, '8000');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.waiting, isEmpty);
    expect(find.text('₮61,500.00'), findsOneWidget);
  });

  testWidgets('a waiting entry can be deleted, and Left goes back', (
    tester,
  ) async {
    final store = await _pump(tester);
    await tester.tap(find.text('Transport'));
    await tester.pumpAndSettle();
    await _type(tester, '8000');
    await _payee(tester, 'ub', pick: 'UB Cab');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('₮53,500.00'), findsOneWidget);

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
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    expect(find.text('₮2,431,800.00'), findsOneWidget);
    expect(find.text('Owed ₮312,000.00'), findsOneWidget);
  });

  testWidgets('an overspent category is said in words, not with a minus', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Eating out'));
    await tester.pumpAndSettle();
    expect(find.text('Overspent by ₮18,400.00'), findsOneWidget);
    await _type(tester, '12500');
    expect(
      find.text('Overspent by ₮18,400.00 · by ₮30,900.00 after this'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Money now, and this entry would go past it.
    await tester.tap(find.text('Transport'));
    await tester.pumpAndSettle();
    await _type(tester, '70000');
    expect(
      find.text('₮61,500.00 left now · overspent by ₮8,500.00 after this'),
      findsOneWidget,
    );
  });

  testWidgets('a bill’s due date is under its name', (tester) async {
    await _pump(
      tester,
      snapshot: PhoneSnapshot(
        madeAt: DateTime(2026, 10, 7, 8, 10),
        periodEnd: DateTime(2026, 10, 14),
        accounts: const [
          PhoneAccount(id: 'a', name: 'TDB Checking', balanceMinor: 0),
        ],
        categories: [
          PhoneCategory(
            id: 'h',
            name: 'Housing',
            leftMinor: 180000000,
            due: DateTime(2026, 10, 20),
          ),
          const PhoneCategory(id: 'g', name: 'Groceries', leftMinor: 100),
        ],
      ),
    );
    // A budget that runs by pay periods says when this one ends.
    expect(find.text('Left until 10.14'), findsOneWidget);
    expect(find.text('Due 10.20'), findsOneWidget);
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
    await tester.tap(find.text('Travel'));
    await tester.pumpAndSettle();
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
    final line = tester.widget<Text>(find.byKey(const ValueKey('from-mac')));
    expect(line.data, 'From your Mac 2026.10.01 21:40');
    expect(line.style!.color, isNot(equals(null)));

    // ₮12,500 of groceries on TDB Checking, ₮30,000 of eating out on the Visa.
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    await _type(tester, '12500');
    await _payee(tester, 'no', pick: 'Nomin');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eating out'));
    await tester.pumpAndSettle();
    await _type(tester, '30000');
    await _payee(tester, 'Rosewood');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    expect(find.text('₮2,419,300.00'), findsOneWidget);
    expect(find.text('Owed ₮342,000.00'), findsOneWidget);
    expect(find.text('From your Mac 2026.10.01 21:40'), findsOneWidget);
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

    testWidgets('the key, then the folder, then what is left', (tester) async {
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
      expect(find.text('Left in October'), findsOneWidget);
      expect(find.text('From your Mac today 13:30'), findsOneWidget);
      expect(find.text('₮148,000.00'), findsOneWidget);
      expect(_same(s.keys.kept!, deriveDataKey(key)), isTrue);
    });

    testWidgets('the next launch goes straight to what is left', (
      tester,
    ) async {
      final keys = _FakeKeys()..kept = deriveDataKey(RecoveryKey.generate());
      final folder = _FakeFolder()..picked = 'drive:BetterBudget';
      await start(tester, keys: keys, folder: folder);
      expect(find.text('Left in October'), findsOneWidget);
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
      expect(find.text('Left in October'), findsOneWidget);
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
      expect(find.text('Left in October'), findsOneWidget);
      broken = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Left in October'), findsOneWidget);
      expect(find.textContaining('doesn’t open'), findsNothing);
      expect(_same(keys.kept!, right), isTrue);
    });

    testWidgets('an entry waiting on the phone survives a fresh read', (
      tester,
    ) async {
      final keys = _FakeKeys()..kept = deriveDataKey(RecoveryKey.generate());
      final folder = _FakeFolder()..picked = 'drive:BetterBudget';
      final s = await start(tester, keys: keys, folder: folder);
      await tester.tap(find.text('Transport'));
      await tester.pumpAndSettle();
      await _type(tester, '8000');
      await _payee(tester, 'ub', pick: 'UB Cab');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('₮53,500.00'), findsOneWidget);

      // Back from another app: the folder is read again.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(s.read.length, 2);
      expect(s.folder.asked.toSet(), {ledgerFileName});
      expect(find.text('₮53,500.00'), findsOneWidget);
      expect(
        find.text('1 of your entries is waiting for the Mac'),
        findsOneWidget,
      );
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
