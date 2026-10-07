import 'dart:convert';
import 'dart:io';

import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/data/keys.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/ui/data_words.dart';
import 'package:betterbudget/ui/entry_row.dart' show EditInitial;
import 'package:betterbudget/ui/language.dart';
import 'package:betterbudget/ui/ledger_screen.dart';
import 'package:betterbudget/ui/startup.dart';
import 'package:betterbudget/ui/theme.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

/// A keychain with nothing in it, so launch asks for a key.
class _EmptySecureStorage extends FlutterSecureStoragePlatform {
  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {}

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => null;

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => false;

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {}

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => {};

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {}
}

Future<void> _loadFont(String family, String path) async {
  final bytes = await File(path).readAsBytes();
  await (FontLoader(
    family,
  )..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
}

Map<String, Object?> _arb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, Object?>;

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

  group('which language', () {
    test('Mongolian when the computer prefers it, otherwise English', () {
      expect(resolveLocale(const [Locale('mn', 'MN')]), const Locale('mn'));
      expect(
        resolveLocale(const [Locale('ru'), Locale('mn'), Locale('en')]),
        const Locale('mn'),
      );
      expect(
        resolveLocale(const [Locale('en', 'US'), Locale('mn')]),
        const Locale('en'),
      );
      expect(resolveLocale(const [Locale('ru')]), const Locale('en'));
      expect(resolveLocale(null), const Locale('en'));
    });

    test('the choice is kept in a file on this computer', () async {
      final dir = await Directory.systemTemp.createTemp('language');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/language');
      expect((await LanguageController.load(file)).value, Language.system);
      await (await LanguageController.load(file)).set(Language.mongolian);
      expect((await LanguageController.load(file)).value, Language.mongolian);
      await file.writeAsString('klingon');
      expect((await LanguageController.load(file)).value, Language.system);
    });

    test('dates in sentences', () {
      final en = lookupWords(const Locale('en'));
      final mn = lookupWords(const Locale('mn'));
      final d = DateTime(2026, 9, 5);
      expect(sayDate(en, d), '09.05');
      expect(sayDate(mn, d), '9-р сарын 5');
      expect(sayFullDate(en, d), '2026.09.05');
      expect(sayFullDate(mn, d), '2026 оны 9-р сарын 5');
      expect(monthName(en, 9), 'September');
      expect(monthName(mn, 9), '9-р сар');
    });
  });

  test('every English phrase has its Mongolian', () {
    final en = _arb('en').keys.where((k) => !k.startsWith('@')).toSet();
    final mn = _arb('mn').keys.where((k) => !k.startsWith('@')).toSet();
    expect(en.difference(mn), isEmpty, reason: 'missing in app_mn.arb');
    expect(mn.difference(en), isEmpty, reason: 'only in app_mn.arb');
  });

  test('every placeholder is used in Mongolian too', () {
    final en = _arb('en'), mn = _arb('mn');
    // Left out on purpose, and why.
    const unused = {
      // Mongolian writes the month and day as plain numbers
      // (monthNumber, dayNumber), not zero-padded.
      'dayMonth': {'month', 'day'},
      'dayMonthYear': {'month', 'day'},
      'calendarMonth': {'month'},
      // The case ending follows the number (isTwo), not an English ordinal.
      'startDayOn': {'ordinal'},
      // Only the second day takes the case ending: "10, 25-нд" (firstDay).
      'startPayTwiceMonthly': {'first'},
    };
    final missing = <String>[];
    for (final MapEntry(:key, :value) in en.entries) {
      if (!key.startsWith('@') || key.startsWith('@@')) continue;
      final name = key.substring(1);
      final placeholders =
          ((value as Map<String, Object?>)['placeholders']
                  as Map<String, Object?>?)
              ?.keys ??
          const <String>[];
      final message = mn[name] as String? ?? '';
      for (final p in placeholders) {
        if (unused[name]?.contains(p) ?? false) continue;
        // `{count}`, or `{count, plural, …}` and `{isTwo, select, …}`.
        if (message.contains('{$p}') || message.contains('{$p,')) continue;
        missing.add('$name: {$p}');
      }
    }
    expect(missing, isEmpty, reason: 'placeholders dropped in app_mn.arb');

    // A dropped field here would silently remove an input box.
    final t = lookupWords(const Locale('mn'));
    expect(t.setupOnDayField('\u0001'), contains('\u0001'));
    final days = t.setupOnDaysField('\u0001', '\u0002');
    expect(days, allOf(contains('\u0001'), contains('\u0002')));
    for (final count in [1, 2]) {
      final weeks = t.setupEveryWeeksField(count, '\u0001', '\u0002');
      expect(weeks, allOf(contains('\u0001'), contains('\u0002')));
    }
  });

  test('the app’s own opening balance and adjustment rows', () async {
    final today = DateTime(2026, 9, 16);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedDemoIfEmpty(db, today);
    var data = await db.loadLedger();
    final checking = data.balanceSheetAccounts.first.id;
    final done = await db.reconcile(
      accountId: checking,
      statementDate: today,
      today: today,
      balance: data.clearedThrough(checking, today).balance - 3000,
      adjust: true,
    );
    data = await db.loadLedger();
    final posted = data.registerFor(checking).posted;
    final opening = posted.firstWhere(
      (r) => r.equity == AppEquity.openingBalances,
    );
    final adjustment = posted.firstWhere(
      (r) => r.txnId == done.adjustmentTxnId,
    );
    expect(adjustment.equity, AppEquity.adjustments);

    final en = lookupWords(const Locale('en'));
    final mn = lookupWords(const Locale('mn'));
    expect(rowPayee(en, opening), 'Opening balance');
    expect(rowCategory(en, opening), 'Opening balance');
    expect(rowPayee(en, adjustment), 'Reconcile adjustment');
    expect(rowCategory(en, adjustment), 'Balance adjustments');
    expect(rowPayee(mn, opening), 'Эхний үлдэгдэл');
    expect(rowCategory(mn, opening), 'Эхний үлдэгдэл');
    expect(rowPayee(mn, adjustment), 'Тулгалтын залруулга');
    expect(rowCategory(mn, adjustment), 'Залруулга');
    expect(EditInitial.fromRow(opening).lockedCategory(mn), 'Эхний үлдэгдэл');
    expect(EditInitial.fromRow(adjustment).lockedCategory(mn), 'Залруулга');

    // An earlier statement date: the last one's date, in words.
    Object? refused;
    try {
      await db.reconcile(
        accountId: checking,
        statementDate: today.subtract(const Duration(days: 1)),
        today: today,
        balance: 0,
      );
    } on DbException catch (e) {
      refused = e;
    }
    expect(
      dbProblem(en, refused! as DbException),
      'Already reconciled through 09.16',
    );
    expect(
      dbProblem(mn, refused as DbException),
      mn.ledgerAlreadyReconciled('9-р сарын 16'),
    );
  });

  testWidgets('launch shows the first screen in the chosen language', (
    tester,
  ) async {
    FlutterSecureStoragePlatform.instance = _EmptySecureStorage();
    final dir = await tester.runAsync(
      () => Directory.systemTemp.createTemp('bb-language'),
    );
    addTearDown(() => dir!.delete(recursive: true));
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final mn = lookupWords(const Locale('mn'));
    await tester.runAsync(() async {
      await tester.pumpWidget(
        LanguageScope(
          controller: LanguageController(initial: Language.mongolian),
          child: BetterBudgetStartup(
            store: KeyStore(),
            ledgerFile: File('${dir!.path}/betterbudget.sqlite'),
            open: (_) => throw StateError('no ledger is opened'),
            clock: () => DateTime(2026, 9, 16, 10),
          ),
        ),
      );
    });
    // No ledger and no key: it asks for the key, in Mongolian.
    for (var i = 0; i < 100; i++) {
      await tester.pump();
      if (find.textContaining(mn.startEntryNoLedger).evaluate().isNotEmpty) {
        break;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    expect(find.textContaining(mn.startEntryNoLedger), findsOneWidget);
    await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
  });

  testWidgets('Settings switches to Mongolian, and ⌘Z switches back', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    final language = LanguageController();
    await tester.runAsync(() async {
      await tester.pumpWidget(
        LanguageScope(
          controller: language,
          child: Builder(
            builder: (context) => MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: appTheme(),
              locale: LanguageScope.maybeOf(context)?.locale,
              supportedLocales: supportedLocales,
              localizationsDelegates: Words.localizationsDelegates,
              localeListResolutionCallback: (preferred, _) =>
                  resolveLocale(preferred),
              home: LedgerScreen(
                demo: true,
                db: db,
                clock: () => DateTime(2026, 9, 16, 10),
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    final en = lookupWords(const Locale('en'));
    final mn = lookupWords(const Locale('mn'));

    await tester.tap(find.byKey(const ValueKey('settings')));
    await tester.pumpAndSettle();
    expect(find.text(en.languageTitle), findsOneWidget);
    expect(
      find.text('Showing English now · changes when the Mac does'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('language-mongolian')));
    await tester.pumpAndSettle();
    expect(language.value, Language.mongolian);
    expect(find.text(mn.languageTitle), findsOneWidget);
    expect(find.text(en.languageTitle), findsNothing);
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/settings_mn.png'),
    );

    // Every section in Mongolian, to look at and to catch anything that no
    // longer fits (an overflow fails the test).
    final sections = {
      'budget': find.byIcon(Icons.pie_chart_outline_rounded),
      'savings': find.byIcon(Icons.savings_outlined),
      'ledger': find.text(mn.ledgerSectionLedger),
    };
    for (final MapEntry(key: name, value: tab) in sections.entries) {
      await tester.tap(tab);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/${name}_mn.png'),
      );
    }

    // The longest phrases: the reconcile panel and pay setup.
    await tester.tap(find.text(mn.planReconcile));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/reconcile_mn.png'),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    // Pay is added from the Budget page's Income tab.
    await tester.tap(find.byIcon(Icons.pie_chart_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget-tab-income')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(mn.setupAddYourPay));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp), // the dialog lives in the app's overlay
      matchesGoldenFile('goldens/pay_setup_mn.png'),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(language.value, Language.system);

    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
      await db.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    debugDefaultTargetPlatformOverride = null;
  });
}
