import 'dart:io';

import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/ui/ledger_screen.dart';
import 'package:betterbudget/ui/theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFont(String family, String path) async {
  final bytes = await File(path).readAsBytes();
  await (FontLoader(
    family,
  )..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
}

void main() {
  setUpAll(() async {
    await _loadFont('Onest', 'assets/fonts/Onest-Variable.ttf');
    await _loadFont('Manrope', 'assets/fonts/Manrope-Variable.ttf');
    final icons =
        '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    if (File(icons).existsSync()) await _loadFont('MaterialIcons', icons);
  });

  Future<AppDatabase> pumpLedger(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: midnightTheme(),
          home: LedgerScreen(db: db, clock: () => DateTime(2026, 9, 16, 10)),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    return db;
  }

  Future<void> tidy(WidgetTester tester, AppDatabase db) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
      await db.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ledger renders balances, forecast and register', (tester) async {
    final db = await pumpLedger(tester);
    expect(find.text('TDB Checking'), findsWidgets);
    expect(find.text('Lowest ₮1,392,250 on 10.01'), findsOneWidget);
    expect(find.text('Bank data through 09.15'), findsOneWidget);
    expect(find.text('Номин супермаркет'), findsOneWidget);
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/ledger.png'),
    );
    await tidy(tester, db);
  });

  testWidgets('the header is the key to the row symbols', (tester) async {
    final db = await pumpLedger(tester);
    expect(find.text('Uncleared'), findsWidgets);
    expect(find.text('2 transactions the bank hasn’t posted'), findsOneWidget);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(find.text('2 transactions the bank hasn’t posted')),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/ledger_key_hover.png'),
    );
    await mouse.removePointer();
    await tidy(tester, db);
  });

  testWidgets('cmd-click and shift-click select several rows', (tester) async {
    final db = await pumpLedger(tester);
    await tester.tap(find.text('Unitel'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.tap(find.text('Шунхлай'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pumpAndSettle();
    expect(find.text('5 selected'), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.tap(find.text('TDB').last);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
    expect(find.text('4 selected'), findsOneWidget);
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/ledger_bulk.png'),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('4 selected'), findsNothing);
    await tidy(tester, db);
  });

  group('adding a transaction in any order', () {
    Finder field(String hint) => find.widgetWithText(TextField, hint);
    bool focused(WidgetTester tester, String hint) => tester
        .widget<EditableText>(
          find.descendant(of: field(hint), matching: find.byType(EditableText)),
        )
        .focusNode
        .hasFocus;

    Future<void> enter(WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
    }

    testWidgets('Enter with fields missing goes to the first one missing', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await tester.enterText(field('0.00'), '8000');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // border fade-in
      expect(find.text('needs 2 more'), findsOneWidget);
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/entry_needs.png'),
      );
      await enter(tester);
      expect(focused(tester, 'New transaction — payee'), isTrue);
      expect(find.text('Sakura Coffee'), findsOneWidget); // nothing added yet
      await tidy(tester, db);
    });

    testWidgets('amount first, payee last, Enter in payee adds it', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await tester.enterText(field('0.00'), '8000');
      await tester.enterText(field('New transaction — payee'), 'Sakura Coffee');
      await enter(tester); // category is filled from the payee's last one
      expect(find.text('Sakura Coffee'), findsNWidgets(2));
      expect(find.text('₮4,174,450'), findsWidgets);
      await tidy(tester, db);
    });

    testWidgets('the Add button adds a complete row', (tester) async {
      final db = await pumpLedger(tester);
      await tester.enterText(field('Category'), 'Dining out');
      await tester.enterText(field('New transaction — payee'), 'Modern Nomads');
      await tester.enterText(field('0.00'), '42000');
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(GestureDetector, 'Add').last);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(find.text('Modern Nomads'), findsOneWidget);
      await tidy(tester, db);
    });
  });

  testWidgets('a future bill turns the forecast into a warning', (
    tester,
  ) async {
    final db = await pumpLedger(tester);
    await tester.tap(find.widgetWithText(TextField, 'Date'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Date'), '09.30');
    await tester.enterText(
      find.widgetWithText(TextField, 'New transaction — payee'),
      'МУИС',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Category'),
      'Tuition',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '0.00'),
      '2000000+100000',
    );
    // The write is real SQLite I/O, so let it run outside the fake clock.
    await tester.runAsync(() async {
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    expect(
      find.text('Runs out on 09.30 · up to ₮707,750 short'),
      findsOneWidget,
    );
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/ledger_short.png'),
    );
    await tidy(tester, db);
  });
}
