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
    // Header sum: cleared + uncleared = working; reconciled shows only when.
    expect(find.text('−₮116,400.00', findRichText: true), findsOneWidget);
    expect(find.text('Last reconciled on 09.10'), findsOneWidget);
    expect(find.text('Номин супермаркет'), findsOneWidget);
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/ledger.png'),
    );
    await tidy(tester, db);
  });

  testWidgets('sidebar sections: the one you are in expands', (tester) async {
    final db = await pumpLedger(tester);
    expect(find.text('Cash wallet'), findsOneWidget);
    expect(find.text('Later'), findsNWidgets(2));

    await tester.tap(find.text('Budget'));
    await tester.pumpAndSettle();
    expect(find.text('Not built yet. The ledger comes first.'), findsOneWidget);
    expect(find.text('Cash wallet'), findsNothing); // Ledger collapsed
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/section_budget.png'),
    );

    await tester.tap(find.text('Ledger'));
    await tester.pumpAndSettle();
    expect(find.text('Cash wallet'), findsOneWidget);
    expect(find.text('Not built yet. The ledger comes first.'), findsNothing);
    await tidy(tester, db);
  });

  testWidgets('the ledger section spills open and closes quicker', (
    tester,
  ) async {
    final db = await pumpLedger(tester);
    double savingsTop() => tester.getTopLeft(find.text('Savings')).dy;
    final open = savingsTop();

    await tester.tap(find.text('Budget'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(savingsTop(), inExclusiveRange(0, open)); // still closing
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('Cash wallet'), findsNothing); // closed within 200 ms
    final closed = savingsTop();

    await tester.tap(find.text('Ledger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(savingsTop(), inExclusiveRange(closed, open)); // making room
    Opacity fade(String account) => tester.widget<Opacity>(
      find
          .ancestor(of: find.text(account), matching: find.byType(Opacity))
          .first,
    );
    // Accounts higher up are further along than the ones below.
    expect(
      fade('TDB Checking').opacity,
      greaterThan(fade('Golomt Visa').opacity),
    );
    await tester.pumpAndSettle();
    expect(savingsTop(), open);
    await tidy(tester, db);
  });

  testWidgets('reduced motion opens sections instantly', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final db = await pumpLedger(tester);
    await tester.tap(find.text('Budget'));
    await tester.pump();
    expect(find.text('Cash wallet'), findsNothing);
    await tester.tap(find.text('Ledger'));
    await tester.pump();
    expect(find.text('Cash wallet'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Cash wallet'),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
    await tidy(tester, db);
  });

  testWidgets('uncleared money coming in shows with a plus', (tester) async {
    final db = await pumpLedger(tester);
    // An uncleared ₮500,000 deposit outweighs the ₮116,400 uncleared spending.
    await tester.enterText(
      find.widgetWithText(TextField, 'New transaction — payee'),
      'Refund',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Category'),
      'Salary',
    );
    await tester.enterText(find.widgetWithText(TextField, '0.00'), '+500000');
    await tester.runAsync(() async {
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('+₮383,600.00', findRichText: true), findsOneWidget);
    expect(find.text('3 not cleared yet'), findsOneWidget);
    await tidy(tester, db);
  });

  testWidgets('the header is the key to the row symbols', (tester) async {
    final db = await pumpLedger(tester);
    expect(find.text('Uncleared'), findsWidgets);
    expect(find.text('2 not cleared yet'), findsOneWidget);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('2 not cleared yet')));
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

  testWidgets('delete leaves reconciled rows locked', (tester) async {
    final db = await pumpLedger(tester);
    await tester.tap(find.text('Unitel'));
    final salary = find.text('Altan Gadas LLC', skipOffstage: false);
    await tester.ensureVisible(salary);
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.tap(salary);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await settle(tester);
    expect(
      find.text('1 transaction deleted · 1 reconciled left locked'),
      findsOneWidget,
    );
    expect(find.text('Unitel'), findsNothing);
    expect(salary, findsOneWidget);
    await tidy(tester, db);
  });

  testWidgets('delete and C type into fields, not into row shortcuts', (
    tester,
  ) async {
    final db = await pumpLedger(tester);
    final payee = find.widgetWithText(TextField, 'New transaction — payee');
    // A selected row is exactly when the shortcuts would steal the keys.
    await tester.tap(find.text('Unitel'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.enterText(payee, 'Sakura');
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await settle(tester);

    expect(tester.widget<TextField>(payee).controller!.text, 'Sakur');
    expect(find.text('Unitel'), findsOneWidget); // not deleted
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.textContaining('marked'), findsNothing); // C didn't clear it

    // Clicking a row leaves the field; then the keys act on the selection.
    // The payee suggestions also list "Sakura Coffee"; tap the register row.
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is Text && w.data == 'Sakura Coffee' && w.style?.fontSize == 14.5,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('1 transaction marked uncleared'), findsOneWidget);
    expect(tester.widget<TextField>(payee).controller!.text, 'Sakur');
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

  group('editing an existing transaction', () {
    Future<void> save(WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
    }

    testWidgets(
      'double-click the amount, change it, Enter saves, Undo restores',
      (tester) async {
        final db = await pumpLedger(tester);
        final amount = find
            .text('₮30,000.00', findRichText: true)
            .first; // Unitel
        await tester.tap(amount);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(amount);
        await tester.pump();
        await tester.pump();
        expect(find.text('Save'), findsOneWidget);
        await expectLater(
          find.byType(LedgerScreen),
          matchesGoldenFile('goldens/edit_row.png'),
        );

        // The double-clicked amount has the cursor, with its text selected.
        final focused = tester.widget<EditableText>(
          find.byWidgetPredicate(
            (w) => w is EditableText && w.focusNode.hasFocus,
          ),
        );
        expect(focused.controller.text, '30000');
        tester.testTextInput.enterText('35000');
        await tester.pump();
        await save(tester);
        expect(find.text('Changes saved'), findsOneWidget);
        expect(find.text('₮35,000.00', findRichText: true), findsWidgets);

        await tester.runAsync(() async {
          await tester.tap(find.text('Undo'));
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await tester.pumpAndSettle();
        expect(find.text('₮30,000.00', findRichText: true), findsWidgets);
        await tidy(tester, db);
      },
    );

    testWidgets('Enter on a selected row opens it; Esc cancels', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await tester.tap(find.text('Sakura Coffee'));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();
      expect(find.text('Save'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsNothing);
      expect(find.text('Sakura Coffee'), findsOneWidget);
      await tidy(tester, db);
    });

    testWidgets('reconciled rows explain that they are locked', (tester) async {
      final db = await pumpLedger(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Search payee, memo, amount'),
        'Altan',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Altan Gadas LLC'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Altan Gadas LLC'));
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsNothing);
      expect(
        find.textContaining('Reconciled transactions are locked'),
        findsOneWidget,
      );
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
