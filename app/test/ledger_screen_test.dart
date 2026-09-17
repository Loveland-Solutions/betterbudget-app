import 'dart:io';

import 'package:betterbudget/data/backup.dart';
import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/ui/balance_header.dart' show ForecastPanel;
import 'package:betterbudget/ui/ledger_screen.dart';
import 'package:betterbudget/ui/theme.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
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

/// Stands in for the system's open and save dialogs.
class _FakeDialogs extends FileSelectorPlatform {
  String? openPath;
  String? savePath;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => openPath == null ? null : XFile(openPath!);

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async => savePath == null ? null : FileSaveLocation(savePath!);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
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

  /// The new-transaction row opens from the gold Add button.
  Future<void> openEntry(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('add-transaction')));
    await tester.pumpAndSettle();
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

  testWidgets('the new-transaction row opens from Add and closes when empty', (
    tester,
  ) async {
    final db = await pumpLedger(tester);
    final payee = find.widgetWithText(TextField, 'New transaction — payee');
    expect(payee, findsNothing);

    await openEntry(tester);
    expect(tester.widget<TextField>(payee).focusNode!.hasFocus, isTrue);
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/entry_open.png'),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(payee, findsNothing);

    // Clicking away closes an empty row, but not one with something typed.
    await openEntry(tester);
    await tester.tap(find.text('Unitel'));
    await tester.pumpAndSettle();
    expect(payee, findsNothing);
    await openEntry(tester);
    await tester.enterText(payee, 'Sak');
    await tester.tap(find.text('Unitel'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Sak'), findsOneWidget);
    await tidy(tester, db);
  });

  testWidgets('the date field opens a calendar; typing still works', (
    tester,
  ) async {
    final db = await pumpLedger(tester);
    await openEntry(tester);
    final date = find.widgetWithText(TextField, '2026.09.16');
    final payee = find.widgetWithText(TextField, 'New transaction — payee');
    expect(find.text('September 2026'), findsNothing);

    await tester.tap(date);
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);

    // Future days explain that they schedule the transaction.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('24')));
    await tester.pumpAndSettle();
    expect(find.text('After today · it will be scheduled'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp), // the calendar lives in the app's overlay
      matchesGoldenFile('goldens/date_picker.png'),
    );
    await mouse.removePointer();

    // Clicking a day fills the date and moves on to the payee.
    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsNothing);
    expect(find.widgetWithText(TextField, '2026.09.12'), findsOneWidget);
    expect(tester.widget<TextField>(payee).focusNode!.hasFocus, isTrue);

    // Typing a date jumps the calendar to its month.
    await tester.tap(find.widgetWithText(TextField, '2026.09.12'));
    await tester.enterText(
      find.widgetWithText(TextField, '2026.09.12'),
      '2026.10.03',
    );
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);

    // Esc closes the calendar first, and leaves the typed date alone.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsNothing);
    expect(find.widgetWithText(TextField, '2026.10.03'), findsOneWidget);
    await tidy(tester, db);
  });

  testWidgets('Confirm opens the bill to check its amount; early posts today', (
    tester,
  ) async {
    final db = await pumpLedger(tester);
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    await tester.pump();
    // Dated today (it happened now), the amount selected, ready to change.
    final focused = tester.widget<EditableText>(
      find.byWidgetPredicate((w) => w is EditableText && w.focusNode.hasFocus),
    );
    expect(focused.controller.text, '1800000');
    expect(focused.controller.selection.extentOffset, 7);
    expect(find.widgetWithText(TextField, '2026.09.16'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget); // the row's button
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/confirm_open.png'),
    );
    tester.testTextInput.enterText('1850000');
    await tester.pump();
    await tester.runAsync(() async {
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    expect(
      find.text(
        'Zaisan Residence confirmed early · ₮1,850,000, planned ₮1,800,000 · posted today, 09.16',
      ),
      findsOneWidget,
    );
    final box = tester.widget<Container>(
      find
          .ancestor(
            of: find.textContaining('confirmed early'),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((box.decoration as BoxDecoration).color, Mid.gold);
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/confirm_early.png'),
    );
    // Confirm can be undone like everything else: back to scheduled, and
    // back to its planned amount.
    await tester.runAsync(() async {
      await tester.tap(find.text('Undo'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    expect(find.text('Undone · Zaisan Residence confirmed'), findsOneWidget);
    expect(find.textContaining('next of 4 scheduled'), findsOneWidget);
    await tidy(tester, db);
  });

  testWidgets('a toast can only undo while its action is the newest', (
    tester,
  ) async {
    final db = await pumpLedger(tester);
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    await tester.pump();
    await tester.runAsync(() async {
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    expect(
      find.text(
        'Zaisan Residence confirmed early · ₮1,800,000 · posted today, 09.16',
      ),
      findsOneWidget,
    );

    // A quiet change after it: the confirm toast is still up.
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is Text && w.data == 'Sakura Coffee' && w.style?.fontSize == 14.5,
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('Mark cleared'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Undo'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    expect(find.text('Undo the newer changes first · Ctrl+Z'), findsOneWidget);
    // Neither change was touched.
    expect(find.text('Mark cleared'), findsOneWidget);
    expect(find.textContaining('next of 4 scheduled'), findsNothing);
    await tidy(tester, db);
  });

  testWidgets('forecast dots do nothing while reconciling', (tester) async {
    final db = await pumpLedger(tester);
    await tester.tap(find.byKey(const ValueKey('reconcile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('forecast-dot-09.20')));
    await tester.pumpAndSettle();
    expect(find.text('Finish or cancel the reconcile first'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    await tidy(tester, db);
  });

  testWidgets('forecast dots show their bill and open it', (tester) async {
    final db = await pumpLedger(tester);
    final dot = find.byKey(const ValueKey('forecast-dot-09.20'));
    expect(find.text('Balance after'), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(dot));
    await tester.pumpAndSettle();
    expect(find.text('Balance after'), findsOneWidget);
    expect(find.text('Rent'), findsWidgets); // the rent's memo, in the card
    await expectLater(
      find.byType(MaterialApp), // the card lives in the app's overlay
      matchesGoldenFile('goldens/forecast_card.png'),
    );

    // Clicking goes to the transaction: Scheduled tab, row selected.
    await mouse.moveTo(tester.getCenter(dot));
    await tester.tap(dot);
    await tester.pumpAndSettle();
    await mouse.removePointer();
    expect(find.text('Balance after'), findsNothing);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Nothing scheduled'), findsNothing);
    expect(find.text('Sakura Coffee'), findsNothing); // posted rows hidden
    await tidy(tester, db);
  });

  testWidgets('the bill count lists every bill before payday', (tester) async {
    final db = await pumpLedger(tester);
    final link = find.byKey(const ValueKey('forecast-bills'));
    expect(find.text('3 bills · ₮2,790,200 before 10.10'), findsOneWidget);
    await tester.tap(link);
    await tester.pumpAndSettle();
    // Each bill with the balance after it, then the income that ends it.
    expect(find.text('Zaisan Residence'), findsNWidgets(2));
    expect(find.text('+₮2,500,000'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/forecast_bills.png'),
    );

    // Esc closes it; clicking a bill opens that transaction.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('+₮2,500,000'), findsNothing);
    await tester.tap(link);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('forecast-bill-line')).first);
    await tester.pumpAndSettle();
    expect(find.text('+₮2,500,000'), findsNothing);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Sakura Coffee'), findsNothing);
    await tidy(tester, db);
  });

  testWidgets('uncleared money coming in shows with a plus', (tester) async {
    final db = await pumpLedger(tester);
    await openEntry(tester);
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

  testWidgets('clicking a row shows its actions under it', (tester) async {
    final db = await pumpLedger(tester);
    expect(find.text('Delete'), findsNothing);
    await tester.tap(find.text('Unitel'));
    await tester.pumpAndSettle();
    // Uncleared, so only Mark cleared applies.
    expect(find.text('Mark cleared'), findsOneWidget);
    expect(find.text('Mark uncleared'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Delete')).dy,
      greaterThan(tester.getBottomLeft(find.text('Unitel')).dy),
    );
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/row_actions.png'),
    );

    // Another row moves the actions there; one row at a time.
    await tester.tap(find.text('Sakura Coffee'));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Mark uncleared'), findsOneWidget);

    // Clicking it again, or Esc, closes them.
    await tester.tap(find.text('Sakura Coffee'));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
    await tester.tap(find.text('Unitel'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
    await tidy(tester, db);
  });

  testWidgets('delete removes the row, but reconciled rows stay locked', (
    tester,
  ) async {
    final db = await pumpLedger(tester);
    await tester.tap(find.text('Unitel'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await settle(tester);
    expect(find.text('Unitel deleted'), findsOneWidget);
    expect(find.text('Unitel'), findsNothing);

    final salary = find.text('Altan Gadas LLC', skipOffstage: false);
    await tester.ensureVisible(salary);
    await tester.pumpAndSettle();
    await tester.tap(salary);
    await tester.pumpAndSettle();
    expect(find.textContaining('date and amount locked'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await settle(tester);
    expect(
      find.text('Can’t delete · it matches a bank statement'),
      findsOneWidget,
    );
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
    expect(find.text('Mark cleared'), findsOneWidget);
    await openEntry(tester);

    await tester.enterText(payee, 'Sakura');
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await settle(tester);

    expect(tester.widget<TextField>(payee).controller!.text, 'Sakur');
    expect(find.text('Unitel'), findsOneWidget); // not deleted
    expect(find.text('Mark cleared'), findsOneWidget); // still selected
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
    expect(find.text('Mark uncleared'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    // Clearing is quiet: the symbol changing is the confirmation.
    expect(find.text('Mark cleared'), findsOneWidget);
    expect(find.textContaining('marked'), findsNothing);
    expect(tester.widget<TextField>(payee).controller!.text, 'Sakur');

    // Ctrl+Z (⌘Z on a Mac) undoes it.
    await tester.runAsync(() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(
      find.text('Undone · Sakura Coffee marked uncleared'),
      findsOneWidget,
    );
    expect(find.text('Mark uncleared'), findsOneWidget);

    // In a text field it undoes typing, not the ledger.
    await tester.tap(payee);
    await tester.pump();
    await tester.runAsync(() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('Nothing to undo'), findsNothing);
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
      await openEntry(tester);
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
      await openEntry(tester);
      await tester.enterText(field('0.00'), '8000');
      await tester.enterText(field('New transaction — payee'), 'Sakura Coffee');
      await enter(tester); // category is filled from the payee's last one
      expect(find.text('Sakura Coffee'), findsNWidgets(2));
      expect(find.text('₮4,174,450'), findsWidgets);
      await tidy(tester, db);
    });

    testWidgets('the Add button adds a complete row, memo included', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await openEntry(tester);
      await tester.enterText(field('Category'), 'Dining out');
      await tester.enterText(field('New transaction — payee'), 'Modern Nomads');
      await tester.enterText(field('0.00'), '42000');
      await tester.pump();
      // The memo line shows while the row is in use.
      await tester.enterText(field('Memo'), 'Lunch with Bat');
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(GestureDetector, 'Add').last);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(find.text('Modern Nomads'), findsOneWidget);
      expect(find.text('Lunch with Bat'), findsOneWidget); // saved, row reset
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

    testWidgets('a reconciled row edits its payee; date and amount stay', (
      tester,
    ) async {
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
      expect(find.text('Save'), findsOneWidget);
      // Date and amount show as text; payee, memo and category are fields.
      final fields = find.descendant(
        of: find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey &&
              '${(w.key as ValueKey).value}'.startsWith('edit-'),
        ),
        matching: find.byType(EditableText),
      );
      expect(fields, findsNWidgets(3));
      expect(find.text('2026.09.10'), findsOneWidget);
      // The double-clicked payee has the cursor. (A name that isn't a
      // suggestion, so Enter saves instead of picking one.)
      tester.testTextInput.enterText('Алтан Гадас');
      await tester.pump();
      await save(tester);
      expect(find.text('Changes saved'), findsOneWidget);
      final saved = await tester.runAsync(
        () async =>
            (await db.loadLedger()).txns.where((t) => t.payee == 'Алтан Гадас'),
      );
      expect(saved, hasLength(1));
      expect(saved!.single.entries.first.cleared, Cleared.reconciled);
      await tidy(tester, db);
    });
  });

  testWidgets('reconcile: match the statement, then lock', (tester) async {
    final db = await pumpLedger(tester);
    await tester.tap(find.byKey(const ValueKey('reconcile')));
    await tester.pumpAndSettle();

    // Starts empty, with the cursor there: the number comes from the statement.
    expect(find.text('Matches'), findsNothing);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('reconcile-balance')),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );
    expect(find.text('Not the “available” balance'), findsOneWidget);
    expect(find.text('Lock 5 transactions'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reconcile-lock')));
    await settle(tester);
    expect(
      find.text('Reconcile'),
      findsOneWidget,
    ); // still open, nothing locked
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.text('Last reconciled on 09.10'), findsNothing);
    // The register narrows to rows that can still be ticked off.
    expect(find.text('Not reconciled, through 2026.09.16'), findsOneWidget);
    expect(find.text('Altan Gadas LLC'), findsNothing);
    expect(find.text('Unitel'), findsOneWidget);

    // The bank shows ₮30,000 less: Unitel has cleared there.
    final balance = find.byKey(const ValueKey('reconcile-balance'));
    await tester.enterText(balance, '4268850');
    await tester.pumpAndSettle();
    expect(find.text('Matches'), findsNothing);
    expect(find.text('Bank is lower'), findsOneWidget);
    expect(
      find.text('Unitel on 09.16 is ₮30,000 and isn’t cleared'),
      findsOneWidget,
    );
    expect(find.text('Add ₮30,000 adjustment and lock'), findsOneWidget);
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/reconcile.png'),
    );

    await tester.tap(find.text('Unitel'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    expect(find.text('Matches'), findsOneWidget);
    expect(find.text('Lock 6 transactions'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('reconcile-lock')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    expect(
      find.text('TDB Checking reconciled through 09.16 · 6 locked'),
      findsOneWidget,
    );
    expect(find.text('Last reconciled on 09.16'), findsOneWidget);
    expect(find.text('1 not cleared yet'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Undo'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    expect(find.text('Last reconciled on 09.10'), findsOneWidget);
    await tidy(tester, db);
  });

  testWidgets('a difference nobody can find goes in as an adjustment', (
    tester,
  ) async {
    final db = await pumpLedger(tester);
    await tester.tap(find.byKey(const ValueKey('reconcile')));
    await tester.pumpAndSettle();
    // ₮1,000 more at the bank than here, and no row that size.
    await tester.enterText(
      find.byKey(const ValueKey('reconcile-balance')),
      '4299850',
    );
    await tester.pumpAndSettle();
    expect(find.text('Bank is higher'), findsOneWidget);
    expect(find.text('Clear the rows your bank shows'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Add ₮1,000 adjustment and lock'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    expect(
      find.text(
        'TDB Checking reconciled through 09.16 · 5 locked · ₮1,000 adjustment added',
      ),
      findsOneWidget,
    );
    expect(find.text('Reconcile adjustment'), findsOneWidget);
    expect(find.text('Balance adjustments'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Undo'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    expect(find.text('Reconcile adjustment'), findsNothing);
    expect(find.text('Last reconciled on 09.10'), findsOneWidget);
    await tidy(tester, db);
  });

  testWidgets('a credit card shows what is owed, without warnings', (
    tester,
  ) async {
    final db = await pumpLedger(tester);
    expect(find.text('₮640,200 owed'), findsOneWidget); // sidebar
    await tester.tap(find.text('Golomt Visa'));
    await tester.pumpAndSettle();
    expect(find.text('Owed'), findsWidgets); // total line and Balance column
    expect(find.text('₮640,200.00', findRichText: true), findsWidgets);
    expect(find.textContaining('Below zero'), findsNothing);
    expect(find.text('₮0 owed after 09.25'), findsOneWidget);
    expect(find.text('1 payment · ₮640,200 before 10.16'), findsOneWidget);
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/ledger_card.png'),
    );
    await tidy(tester, db);
  });

  testWidgets('a past reconcile can be undone from its rows, then redone', (
    tester,
  ) async {
    final db = await pumpLedger(tester);
    Future<void> chord(LogicalKeyboardKey key, {bool shift = false}) =>
        tester.runAsync(() async {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          if (shift) {
            await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          }
          await tester.sendKeyEvent(key);
          if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });

    final salary = find.text('Altan Gadas LLC', skipOffstage: false);
    await tester.ensureVisible(salary);
    await tester.pumpAndSettle();
    await tester.tap(salary);
    await tester.pumpAndSettle();
    expect(
      find.text('Reconciled on 09.10 · date and amount locked'),
      findsOneWidget,
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('unreconcile')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    expect(
      find.text('Reconcile of 09.10 undone · 5 rows back to cleared'),
      findsOneWidget,
    );
    expect(find.text('Never reconciled'), findsOneWidget);

    await chord(LogicalKeyboardKey.keyZ);
    await settle(tester);
    expect(find.text('Undone · Reconcile of 09.10 undone'), findsOneWidget);
    expect(find.text('Last reconciled on 09.10'), findsOneWidget);

    await chord(LogicalKeyboardKey.keyZ, shift: true);
    await settle(tester);
    expect(find.text('Redone · Reconcile of 09.10 undone'), findsOneWidget);
    expect(find.text('Never reconciled'), findsOneWidget);

    // Ctrl+Y redoes too, once something has been undone.
    await chord(LogicalKeyboardKey.keyZ);
    await settle(tester);
    await chord(LogicalKeyboardKey.keyY);
    await settle(tester);
    expect(find.text('Never reconciled'), findsOneWidget);
    await chord(LogicalKeyboardKey.keyY);
    await settle(tester);
    expect(find.text('Nothing to redo'), findsOneWidget);
    await tidy(tester, db);
  });

  testWidgets('reconcile: Esc cancels, and a future date is refused', (
    tester,
  ) async {
    final db = await pumpLedger(tester);
    await tester.tap(find.byKey(const ValueKey('reconcile')));
    await tester.pumpAndSettle();
    final date = find.descendant(
      of: find.byKey(const ValueKey('reconcile-date')),
      matching: find.byType(TextField),
    );
    await tester.enterText(date, '09.20');
    await tester.pumpAndSettle();
    expect(find.text('The statement can’t be after today'), findsOneWidget);
    await tester.enterText(date, '09.05');
    await tester.pumpAndSettle();
    expect(find.text('Already reconciled through 09.10'), findsOneWidget);
    await tester.enterText(date, '09.12');
    await tester.pumpAndSettle();
    expect(find.text('Not reconciled, through 2026.09.12'), findsOneWidget);
    expect(find.text('Sakura Coffee'), findsNothing);

    // Esc closes the date's calendar first, then cancels.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Statement date'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Statement date'), findsNothing);
    expect(find.text('Last reconciled on 09.10'), findsOneWidget);
    expect(find.text('Sakura Coffee'), findsOneWidget);
    await tidy(tester, db);
  });

  /// Ctrl (or ⌘ with [meta]) plus [key], outside the fake clock.
  Future<void> chord(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool shift = false,
    bool meta = false,
  }) => tester.runAsync(() async {
    final mod = meta
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(mod);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(mod);
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });

  /// A tap whose handler writes to the database. Menu items act a frame
  /// after the tap, so pump before letting the write run.
  Future<void> tapAndWait(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await tester.pump();
    await tester.pump();
    await settle(tester);
    await settle(tester);
  }

  final payeeCell = find.byWidgetPredicate(
    (w) => w is Text && w.data == 'Sakura Coffee' && w.style?.fontSize == 14.5,
  );

  group('undo and redo, action by action', () {
    testWidgets('add: undo removes it, redo brings it back', (tester) async {
      final db = await pumpLedger(tester);
      await openEntry(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'New transaction — payee'),
        'Modern Nomads',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Category'),
        'Dining out',
      );
      await tester.enterText(find.widgetWithText(TextField, '0.00'), '42000');
      await tester.runAsync(() async {
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await settle(tester);
      expect(find.text('Modern Nomads'), findsOneWidget);
      // Leave the row (⌘Z there undoes typing), then undo from the register.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unitel'));
      await tester.pumpAndSettle();

      await chord(tester, LogicalKeyboardKey.keyZ);
      await settle(tester);
      expect(find.text('Undone · Modern Nomads added'), findsOneWidget);
      expect(find.text('Modern Nomads'), findsNothing);
      await chord(tester, LogicalKeyboardKey.keyZ, shift: true);
      await settle(tester);
      expect(find.text('Redone · Modern Nomads added'), findsOneWidget);
      expect(find.text('Modern Nomads'), findsOneWidget);
      await tidy(tester, db);
    });

    testWidgets('edit: redo puts the change back', (tester) async {
      final db = await pumpLedger(tester);
      await tester.tap(find.text('Unitel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pump();
      await tester.pump();
      tester.testTextInput.enterText('Unitel LLC');
      await tester.pump();
      await tester.runAsync(() async {
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await settle(tester);
      expect(find.text('Changes saved'), findsOneWidget);
      expect(find.text('Unitel LLC'), findsOneWidget);

      await chord(tester, LogicalKeyboardKey.keyZ);
      await settle(tester);
      expect(find.text('Unitel'), findsOneWidget);
      await chord(tester, LogicalKeyboardKey.keyZ, shift: true);
      await settle(tester);
      expect(find.text('Redone · Unitel LLC edited'), findsOneWidget);
      expect(find.text('Unitel LLC'), findsOneWidget);
      await tidy(tester, db);
    });

    testWidgets('categorize: undo and redo', (tester) async {
      final db = await pumpLedger(tester);
      await tester.tap(find.text('Unitel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Categorize'));
      await tester.pumpAndSettle();
      // The menu item, not E-Mart's Groceries chip in the register.
      await tapAndWait(
        tester,
        find.descendant(
          of: find.byType(MenuItemButton),
          matching: find.text('Groceries'),
        ),
      );
      expect(find.text('Unitel → Groceries'), findsOneWidget);
      Future<String> category() async => (await tester.runAsync(
        () async => (await db.loadLedger())
            .registerFor(1)
            .posted
            .firstWhere((r) => r.payee == 'Unitel')
            .categoryLabel,
      ))!;
      expect(await category(), 'Groceries');

      await chord(tester, LogicalKeyboardKey.keyZ);
      await settle(tester);
      expect(find.text('Undone · Unitel → Groceries'), findsOneWidget);
      expect(await category(), 'Phone & internet');
      await chord(tester, LogicalKeyboardKey.keyZ, shift: true);
      await settle(tester);
      expect(find.text('Redone · Unitel → Groceries'), findsOneWidget);
      expect(await category(), 'Groceries');
      await tidy(tester, db);
    });

    testWidgets('delete: redo deletes it again', (tester) async {
      final db = await pumpLedger(tester);
      await tester.tap(find.text('Unitel'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await settle(tester);
      expect(find.text('Unitel'), findsNothing);
      await chord(tester, LogicalKeyboardKey.keyZ);
      await settle(tester);
      expect(find.text('Unitel'), findsOneWidget);
      await chord(tester, LogicalKeyboardKey.keyZ, shift: true);
      await settle(tester);
      expect(find.text('Redone · Unitel deleted'), findsOneWidget);
      expect(find.text('Unitel'), findsNothing);
      await tidy(tester, db);
    });

    Future<void> clearSakura(WidgetTester tester) async {
      await tester.tap(payeeCell);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await settle(tester);
      expect(find.text('Mark cleared'), findsOneWidget);
    }

    testWidgets(
      'Windows: Ctrl+Z undoes and Ctrl+Y redoes',
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
      (tester) async {
        final db = await pumpLedger(tester);
        await clearSakura(tester);
        await chord(tester, LogicalKeyboardKey.keyZ);
        await settle(tester);
        expect(find.text('Mark uncleared'), findsOneWidget);
        await chord(tester, LogicalKeyboardKey.keyY);
        await settle(tester);
        expect(
          find.text('Redone · Sakura Coffee marked uncleared'),
          findsOneWidget,
        );
        expect(find.text('Mark cleared'), findsOneWidget);
        await tidy(tester, db);
      },
    );

    testWidgets(
      'Mac: ⌘Z undoes and ⌘⇧Z redoes; Ctrl+Z is left alone',
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
      (tester) async {
        final db = await pumpLedger(tester);
        await clearSakura(tester);
        await chord(tester, LogicalKeyboardKey.keyZ);
        await settle(tester);
        expect(find.text('Mark cleared'), findsOneWidget);
        await chord(tester, LogicalKeyboardKey.keyZ, meta: true);
        await settle(tester);
        expect(find.text('Mark uncleared'), findsOneWidget);
        await chord(tester, LogicalKeyboardKey.keyZ, meta: true, shift: true);
        await settle(tester);
        expect(find.text('Mark cleared'), findsOneWidget);
        await tidy(tester, db);
      },
    );
  });

  testWidgets('switching account mid-reconcile ends the reconcile', (
    tester,
  ) async {
    final db = await pumpLedger(tester);
    await tester.tap(find.byKey(const ValueKey('reconcile')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('reconcile-balance')),
      '4268850',
    );
    await tester.pumpAndSettle();
    expect(find.text('Statement date'), findsOneWidget);

    await tester.tap(find.text('Khan Savings').first); // the sidebar
    await tester.pumpAndSettle();
    expect(find.text('Statement date'), findsNothing);
    expect(find.textContaining('Not reconciled, through'), findsNothing);
    // Nothing was locked, and going back starts fresh.
    await tester.tap(find.text('TDB Checking').first);
    await tester.pumpAndSettle();
    expect(find.text('Last reconciled on 09.10'), findsOneWidget);
    expect(find.text('Sakura Coffee'), findsOneWidget);
    await tidy(tester, db);
  });

  testWidgets('a transfer says which way it goes before it is added', (
    tester,
  ) async {
    final db = await pumpLedger(tester);
    await openEntry(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Category'),
      '→ Golomt Visa',
    );
    await tester.enterText(find.widgetWithText(TextField, '0.00'), '640200');
    await tester.pump();
    expect(
      find.text('₮640,200.00 from TDB Checking to Golomt Visa'),
      findsOneWidget,
    );
    // Entered from the account the money lands in, Swap turns it around.
    await tester.tap(find.byKey(const ValueKey('transfer-swap')));
    await tester.pump();
    expect(
      find.text('₮640,200.00 from Golomt Visa to TDB Checking'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextField, '+640200'), findsOneWidget);
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/entry_transfer.png'),
    );
    await tester.tap(find.byKey(const ValueKey('transfer-swap')));
    await tester.pump();
    expect(find.widgetWithText(TextField, '640200'), findsOneWidget);

    // Swap before any amount still needs one.
    await tester.enterText(find.widgetWithText(TextField, '640200'), '');
    await tester.tap(find.byKey(const ValueKey('transfer-swap')));
    await tester.pump();
    expect(find.text('From Golomt Visa to TDB Checking'), findsOneWidget);
    expect(find.text('needs payee'), findsNothing); // transfers need none
    expect(find.text('needs amount'), findsOneWidget);
    await tidy(tester, db);
  });

  testWidgets('Move to puts a row in another account, and undoes', (
    tester,
  ) async {
    final db = await pumpLedger(tester);
    await tester.tap(payeeCell);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('move-to')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp), // the menu lives in the overlay
      matchesGoldenFile('goldens/move_to.png'),
    );
    await tapAndWait(tester, find.text('Cash wallet').last);
    expect(
      find.text(
        'Sakura Coffee moved to Cash wallet · uncleared there until it clears',
      ),
      findsOneWidget,
    );
    expect(payeeCell, findsNothing);

    await tester.tap(find.text('Cash wallet').first);
    await tester.pumpAndSettle();
    expect(payeeCell, findsOneWidget);
    await tester.tap(find.text('TDB Checking').first);
    await tester.pumpAndSettle();
    await tapAndWait(tester, find.text('Undo'));
    expect(payeeCell, findsOneWidget);
    await tester.tap(payeeCell);
    await tester.pumpAndSettle();
    expect(find.text('Mark uncleared'), findsOneWidget); // cleared, as before

    // Reconciled rows can't move.
    final salary = find.text('Altan Gadas LLC', skipOffstage: false);
    await tester.ensureVisible(salary);
    await tester.pumpAndSettle();
    await tester.tap(salary);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('move-to')), findsNothing);
    await tidy(tester, db);
  });

  group('backups', () {
    testWidgets('a daily copy that keeps failing shows under Net worth', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = AppDatabase(NativeDatabase.memory());
      final backups = Backups(db)
        ..health.value = BackupHealth(
          newest: DateTime(2026, 9, 12, 8),
          failed: true,
        );
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: midnightTheme(),
            home: LedgerScreen(
              db: db,
              backups: backups,
              clock: () => DateTime(2026, 9, 16, 10),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      // The sidebar shows only a dot on the gear; Settings says what's wrong.
      expect(find.byKey(const ValueKey('settings-alert')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('settings')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('backup-failed')), findsOneWidget);
      expect(
        find.textContaining('the last one is from 2026.09.12 08:00'),
        findsOneWidget,
      );
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/settings_failing.png'),
      );
      // A copy made again clears it.
      backups.health.value = BackupHealth(newest: DateTime(2026, 9, 16, 9));
      await tester.pump();
      expect(find.byKey(const ValueKey('settings-alert')), findsNothing);
      expect(find.text('Today 09:00 · on this computer'), findsOneWidget);
      await tidy(tester, db);
    });

    testWidgets('back up, then restore that copy after a check, and undo', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final dialogs = _FakeDialogs();
      final before = FileSelectorPlatform.instance;
      FileSelectorPlatform.instance = dialogs;
      addTearDown(() => FileSelectorPlatform.instance = before);
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('bb-restore'),
      ))!;
      final db = AppDatabase(
        NativeDatabase(File('${dir.path}/betterbudget.sqlite')),
      );
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: midnightTheme(),
            home: LedgerScreen(db: db, clock: () => DateTime(2026, 9, 16, 10)),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 800));
      });
      await tester.pumpAndSettle();

      Future<void> run(Finder f) async {
        // File work started under the fake clock never finishes, so the
        // tap happens outside it. Dialogs still need frames between hops.
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

      Future<bool> unitel() async => (await tester.runAsync(
        () async =>
            (await db.loadLedger()).txns.any((t) => t.payee == 'Unitel'),
      ))!;

      await tester.tap(find.byKey(const ValueKey('settings')));
      await tester.pumpAndSettle();
      expect(find.text('Backups'), findsOneWidget);

      // Cancelled dialogs do nothing.
      await run(find.byKey(const ValueKey('back-up')));
      await run(find.byKey(const ValueKey('restore')));
      expect(find.byType(Dialog), findsNothing);

      final saved = '${dir.path}/BetterBudget 20260916-093000.sqlite';
      dialogs.savePath = saved;
      await run(find.byKey(const ValueKey('back-up')));
      expect(
        find.text('Backed up · BetterBudget 20260916-093000.sqlite'),
        findsOneWidget,
      );

      // Delete Unitel in the ledger after the backup, then back to Settings.
      await tester.tap(find.text('Ledger'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unitel'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await settle(tester);
      expect(await unitel(), isFalse);
      await tester.tap(find.byKey(const ValueKey('settings')));
      await tester.pumpAndSettle();

      dialogs.openPath = saved;
      // Cancel first: nothing changes, and the working copy goes.
      await run(find.byKey(const ValueKey('restore')));
      await run(find.byKey(const ValueKey('restore-cancel')));
      expect(find.byType(Dialog), findsNothing);
      expect(await unitel(), isFalse);
      expect(
        Directory('${dir.path}/Backups')
            .listSync()
            .where((f) => f.path.split('/').last.startsWith('incoming-')),
        isEmpty,
      );

      await run(find.byKey(const ValueKey('restore')));
      expect(find.text('Restore this backup?'), findsOneWidget);
      expect(find.text('2026.09.16  09:30'), findsOneWidget);
      expect(find.text('19 transactions · 4 accounts'), findsOneWidget);
      expect(find.text('18 transactions · 4 accounts'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/restore_dialog.png'),
      );

      await run(find.byKey(const ValueKey('restore-confirm')));
      expect(find.byType(Dialog), findsNothing);
      expect(
        find.text('Restored the copy from 2026.09.16 · what you had is saved'),
        findsOneWidget,
      );
      expect(await unitel(), isTrue);

      await run(find.text('Undo'));
      expect(
        find.text('Undone · Restored the copy from 2026.09.16'),
        findsOneWidget,
      );
      expect(await unitel(), isFalse);

      // The delete from before the restore can't be undone past it.
      await chord(tester, LogicalKeyboardKey.keyZ, shift: true);
      await settle(tester);
      expect(await unitel(), isTrue);
      await chord(tester, LogicalKeyboardKey.keyZ);
      await settle(tester);
      await chord(tester, LogicalKeyboardKey.keyZ);
      await settle(tester);
      expect(find.text('Nothing to undo'), findsOneWidget);

      await tidy(tester, db);
      await tester.runAsync(() => dir.delete(recursive: true));
    });
  });

  testWidgets('old items say why Working may be off', (tester) async {
    final db = await pumpLedger(tester);
    await tester.runAsync(() async {
      final ledger = await db.loadLedger();
      final checking = ledger.balanceSheetAccounts.first.id;
      final phone = ledger.categories
          .firstWhere((c) => c.name == 'Phone & internet')
          .id;
      // Uncleared for 34 days, and a bill 7 days past due, not confirmed.
      await db.postSimple(
        accountId: checking,
        date: DateTime(2026, 8, 13),
        today: DateTime(2026, 9, 16),
        payee: 'Skytel',
        counterAccountId: phone,
        amount: -2500000,
        memo: 'Prepaid',
      );
      await db.postTransaction(
        date: DateTime(2026, 9, 9),
        payee: 'Mobicom',
        scheduled: true,
        lines: [
          (accountId: checking, amount: -4000000, cleared: Cleared.uncleared),
          (accountId: phone, amount: 4000000, cleared: Cleared.uncleared),
        ],
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('· due 7 days ago'), findsOneWidget);
    expect(find.text('Mobicom'), findsOneWidget); // now the next scheduled
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/overdue_row.png'),
    );

    // Unitel is from today: no note. Skytel is old enough to question.
    final skytel = find.text('Skytel', skipOffstage: false);
    await tester.ensureVisible(skytel);
    await tester.pumpAndSettle();
    expect(find.text(' · not cleared for 34 days'), findsOneWidget);
    expect(find.byKey(const ValueKey('stale-note')), findsOneWidget);
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/stale_rows.png'),
    );

    // Confirming it keeps its due date, when auto-pay really left.
    await tester.drag(find.text('Skytel'), const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    await tester.pump();
    expect(find.widgetWithText(TextField, '2026.09.09'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    expect(find.text('Mobicom confirmed · ₮40,000'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Undo'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    expect(find.text('· due 7 days ago'), findsOneWidget);
    await tidy(tester, db);
  });

  testWidgets('a late salary is named and not counted', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    // The seed's salary is due 10.10; open the app on 10.12, before it's
    // confirmed. Rent (09.20), the card payment and childcare are overdue too.
    await tester.runAsync(() async {
      await seedDemoIfEmpty(db, DateTime(2026, 9, 16));
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: midnightTheme(),
          home: LedgerScreen(db: db, clock: () => DateTime(2026, 10, 12, 10)),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('Next 30 days'), findsOneWidget);
    // The amount and how late, not a name or a date that reads like money.
    expect(
      find.text(' · ₮2,500,000 2 days late · not counted', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Lowest ₮1,392,250 on 10.12'), findsOneWidget);
    // Only the header: the register below isn't what this is about.
    await expectLater(
      find.byType(ForecastPanel),
      matchesGoldenFile('goldens/forecast_late_income.png'),
    );

    // Clicking the note opens the salary, ready to confirm.
    await tester.tap(find.byKey(const ValueKey('forecast-late')));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Sakura Coffee'), findsNothing); // Scheduled tab
    await tidy(tester, db);
  });

  testWidgets('a salary confirmed short keeps the rest owed, undone as one', (
    tester,
  ) async {
    final db = await pumpLedger(tester);
    await tester.tap(find.text('Scheduled'));
    await tester.pumpAndSettle();

    // A bill that came in lower asks nothing.
    await tester.tap(find.text('Confirm').first);
    await tester.pump();
    await tester.pump();
    tester.testTextInput.enterText('1700000');
    await tester.pump();
    expect(find.byKey(const ValueKey('owed-line')), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    // The salary (last scheduled) came in at half.
    await tester.tap(find.text('Confirm').last);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('owed-line')), findsNothing); // as planned
    tester.testTextInput.enterText('1250000');
    await tester.pump();
    expect(find.text('₮1,250,000 less than planned:'), findsOneWidget);
    expect(find.text('Still owed, due 10.10'), findsOneWidget);
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/confirm_short.png'),
    );
    await tester.runAsync(() async {
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    expect(
      find.text(
        'Altan Gadas LLC confirmed early · ₮1,250,000 · ₮1,250,000 still owed, due 10.10 · posted today, 09.16',
      ),
      findsOneWidget,
    );
    Future<List<int>> salaries() async => (await tester.runAsync(
      () async => [
        for (final r in (await db.loadLedger()).registerFor(1).scheduled)
          if (r.payee == 'Altan Gadas LLC') r.amount,
      ],
    ))!;
    expect(await salaries(), [125000000]);

    await tester.runAsync(() async {
      await tester.tap(find.text('Undo'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    expect(await salaries(), [250000000]);

    // Paid in full: nothing kept.
    await tester.tap(find.text('Confirm').last);
    await tester.pump();
    await tester.pump();
    tester.testTextInput.enterText('2400000');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('owed-full')));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Confirm').last);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    expect(
      find.textContaining('₮2,400,000, planned ₮2,500,000'),
      findsOneWidget,
    );
    expect(await salaries(), isEmpty);
    await tidy(tester, db);
  });

  testWidgets('a future bill turns the forecast into a warning', (
    tester,
  ) async {
    final db = await pumpLedger(tester);
    await openEntry(tester);
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
