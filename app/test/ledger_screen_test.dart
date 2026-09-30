import 'dart:io';

import 'package:betterbudget/data/backup.dart';
import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/pay.dart';
import 'package:betterbudget/domain/readiness.dart';
import 'package:betterbudget/ui/appearance.dart';
import 'package:betterbudget/ui/balance_header.dart' show ForecastPanel;
import 'package:betterbudget/ui/ledger_screen.dart';
import 'package:betterbudget/ui/register.dart' show SmoothHeight;
import 'package:betterbudget/ui/theme.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'xls_fixture.dart';

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
          theme: appTheme(),
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

  testWidgets('savings: the steps, the fund account, answers and undo', (
    tester,
  ) async {
    final db = await pumpLedger(tester);
    await tester.tap(find.text('Savings'));
    await tester.pumpAndSettle();
    expect(find.text('One month of expenses set aside'), findsOneWidget);
    expect(find.text('Now'), findsOneWidget);
    expect(find.text('Pick the account'), findsOneWidget);

    // Khan Savings holds the fund.
    await tester.tap(find.byKey(const ValueKey('fund-picker')));
    await tester.pumpAndSettle();
    final khan = (await tester.runAsync(db.loadLedger))!.balanceSheetAccounts
        .firstWhere((a) => a.name == 'Khan Savings');
    await tester.tap(find.byKey(ValueKey('fund-${khan.id}')));
    await settle(tester);
    await settle(tester);
    await settle(tester);
    expect(find.text('Kept in Khan Savings'), findsOneWidget);
    expect(find.text('Khan Savings holds the emergency fund'), findsOneWidget);

    // Type a month, so the numbers don't hang on the demo's dates.
    await tester.tap(find.byKey(const ValueKey('month-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('month-field')),
      '2000000',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    var data = (await tester.runAsync(db.loadLedger))!;
    expect(data.prefs[ReadyKeys.month], '200000000');
    final r = Readiness.of(data, DateTime(2026, 9, 16));
    expect(r.fund, data.balanceOf(khan.id));

    // Health is a quiet answer; ⌘Z takes it back.
    await tester.tap(find.byKey(const ValueKey('answer-health-yes')));
    await settle(tester);
    expect(
      (await tester.runAsync(db.loadLedger))!.prefs[ReadyKeys.health],
      'yes',
    );
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/savings.png'),
    );
    await tester.runAsync(() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    data = (await tester.runAsync(db.loadLedger))!;
    expect(data.prefs[ReadyKeys.health], isNull);
    // Redo puts it back.
    await tester.runAsync(() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    data = (await tester.runAsync(db.loadLedger))!;
    expect(data.prefs[ReadyKeys.health], 'yes');

    // A step can be set aside, and brought back.
    await tester.tap(find.byKey(const ValueKey('step-retirement-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('step-retirement-aside')));
    await settle(tester);
    await settle(tester);
    expect(find.text('Set aside'), findsOneWidget);
    // ⌘Z brings it back.
    await tester.runAsync(() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('Set aside'), findsNothing);
    expect(
      (await tester.runAsync(db.loadLedger))!.prefs[ReadyKeys.setAside],
      isNull,
    );
    await tidy(tester, db);
  });

  testWidgets('sidebar sections: the one you are in expands', (tester) async {
    final db = await pumpLedger(tester);
    expect(find.text('Cash wallet'), findsOneWidget);

    await tester.tap(find.text('Budget'));
    await tester.pumpAndSettle();
    expect(find.text('Spending'), findsOneWidget); // the categories
    expect(find.text('Cash wallet'), findsNothing); // Ledger collapsed
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/section_budget.png'),
    );

    await tester.tap(find.text('Ledger'));
    await tester.pumpAndSettle();
    expect(find.text('Cash wallet'), findsOneWidget);
    expect(find.text('Spending'), findsNothing);
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

  testWidgets('reduced motion opens a row into the editor instantly', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final db = await pumpLedger(tester);
    await tester.tap(find.text('Unitel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pump();
    await tester.pump();
    final row = find.ancestor(
      of: find.text('Save'),
      matching: find.byType(SmoothHeight),
    );
    final now = tester.getSize(row).height;
    await tester.pumpAndSettle();
    expect(tester.getSize(row).height, now);
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
    await tester.pump(
      const Duration(milliseconds: 200),
    ); // row finishes growing
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
        await tester.pump(const Duration(milliseconds: 200)); // done growing
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

    testWidgets('a row opening into the editor grows, then shrinks back', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      Finder rowOf(String text) => find.ancestor(
        of: find.text(text),
        matching: find.byType(SmoothHeight),
      );
      final closed = tester.getSize(rowOf('Unitel')).height;

      // A double-click: the first click opens the action bar, the second the
      // editor, mid-way. It still eases the whole way.
      await tester.tap(find.text('Unitel'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Unitel'));
      await tester.pump();
      await tester.pump();
      final heights = <double>[];
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        heights.add(tester.getSize(rowOf('Save')).height);
      }
      await tester.pumpAndSettle();
      final open = tester.getSize(rowOf('Save')).height;
      expect(heights.first, greaterThan(closed));
      expect(heights.first, lessThan(open));
      for (var i = 1; i < heights.length; i++) {
        expect(heights[i], greaterThanOrEqualTo(heights[i - 1]));
      }
      expect(heights.last, open);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final shrinking = tester.getSize(rowOf('Unitel')).height;
      expect(shrinking, lessThan(open));
      expect(shrinking, greaterThan(closed));
      await tester.pumpAndSettle();
      await tidy(tester, db);
    });

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
            theme: appTheme(),
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
            theme: appTheme(),
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

  testWidgets('a new ledger clears everything, keeps categories, and undoes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('bb-new-ledger'),
    ))!;
    final db = AppDatabase(
      NativeDatabase(File('${dir.path}/betterbudget.sqlite')),
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(),
          home: LedgerScreen(db: db, clock: () => DateTime(2026, 9, 16, 10)),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 800));
    });
    await tester.pumpAndSettle();

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

    Future<LedgerData> ledger() async =>
        (await tester.runAsync(() => db.loadLedger()))!;

    await tester.tap(find.byKey(const ValueKey('settings')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('new-ledger')));
    await tester.pumpAndSettle();

    // Cancel changes nothing.
    await run(find.byKey(const ValueKey('new-ledger')));
    expect(find.text('Erase everything and start over?'), findsOneWidget);
    // Each account by name with its balance, as the sidebar shows it.
    final goes = find.byKey(const ValueKey('new-ledger-goes'));
    for (final t in [
      'TDB Checking',
      '₮4,182,450',
      'Golomt Visa',
      '₮640,200 owed',
      '19 transactions',
    ]) {
      expect(find.descendant(of: goes, matching: find.text(t)), findsOneWidget);
    }
    expect(find.text('Your 15 categories'), findsOneWidget);
    expect(
      find.text('Kept with no rows in them, ready for your real accounts.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('new-ledger-drop')));
    await tester.pumpAndSettle();
    expect(
      find.text('You’ll add categories again on the Budget screen.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('new-ledger-keep')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/new_ledger_dialog.png'),
    );
    await run(find.byKey(const ValueKey('new-ledger-cancel')));
    expect((await ledger()).txns, hasLength(19));

    await run(find.byKey(const ValueKey('new-ledger')));
    await run(find.byKey(const ValueKey('new-ledger-confirm')));
    expect(
      find.text('Everything erased · what you had is saved in Backups'),
      findsOneWidget,
    );
    var now = await ledger();
    expect(now.txns, isEmpty);
    expect(now.balanceSheetAccounts, isEmpty);
    expect(now.categories, hasLength(15));
    expect(
      Directory('${dir.path}/Backups').listSync().where(
        (f) => f.path.split('/').last.startsWith('before-new-ledger-'),
      ),
      hasLength(1),
    );

    // An emptied ledger isn't given the demo data again.
    await tester.runAsync(() => seedDemoIfEmpty(db, DateTime(2026, 9, 17)));
    expect((await ledger()).txns, isEmpty);

    await run(find.text('Undo'));
    now = await ledger();
    expect(now.txns, hasLength(19));
    expect(now.balanceSheetAccounts, hasLength(4));

    await chord(tester, LogicalKeyboardKey.keyZ, shift: true);
    await settle(tester);
    expect((await ledger()).txns, isEmpty);

    await tidy(tester, db);
    await tester.runAsync(() => dir.delete(recursive: true));
  });

  test('a new ledger without categories starts with nothing', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedDemoIfEmpty(db, DateTime(2026, 9, 16));
    await db.startNewLedger(DateTime(2026, 9, 16), keepCategories: false);
    final ledger = await db.loadLedger();
    expect(ledger.accounts, isEmpty);
    expect(ledger.txns, isEmpty);
    expect(await db.startedOwnLedger(), isTrue);
    await seedDemoIfEmpty(db, DateTime(2026, 9, 17));
    expect((await db.loadLedger()).accounts, isEmpty);
    await db.close();
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
          theme: appTheme(),
          home: LedgerScreen(db: db, clock: () => DateTime(2026, 10, 12, 10)),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('Next 30 days'), findsOneWidget);
    // The amount and how late, not a name or a date that reads like money.
    expect(find.text('+₮2,500,000 in, 2 days late'), findsOneWidget);
    expect(find.text(' · not counted'), findsOneWidget);
    expect(find.text('Lowest ₮1,392,250 on 10.12'), findsOneWidget);
    // Only the header: the register below isn't what this is about.
    await expectLater(
      find.byType(ForecastPanel),
      matchesGoldenFile('goldens/forecast_late_income.png'),
    );

    // The bill list says which bills are past due and counted as today.
    await tester.tap(find.byKey(const ValueKey('forecast-bills')));
    await tester.pumpAndSettle();
    expect(
      find.text(' · due 22 days ago'),
      findsOneWidget,
    ); // rent, in the list
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

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
    await tester.pump(
      const Duration(milliseconds: 200),
    ); // row finishes growing
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
    // Redo brings back both halves.
    await chord(tester, LogicalKeyboardKey.keyZ, shift: true);
    await settle(tester);
    expect(await salaries(), [125000000]);
    await chord(tester, LogicalKeyboardKey.keyZ);
    await settle(tester);
    expect(await salaries(), [250000000]);

    // Paid in full: nothing kept.
    await tester.tap(find.text('Confirm').last);
    await tester.pump();
    await tester.pump();
    tester.testTextInput.enterText('2400000');
    await tester.pump();
    // ₮100,000 short is a small difference: Paid in full is chosen.
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const ValueKey('owed-full')),
              matching: find.byType(Icon),
            ),
          )
          .icon,
      Icons.radio_button_checked_rounded,
    );
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

  testWidgets('on payday the warning waits for the salary', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    // The seed's salary is due 10.10; it's 10.10 and a ₮2,000,000 bill is due
    // on 10.15.
    await tester.runAsync(() async {
      await seedDemoIfEmpty(db, DateTime(2026, 9, 16));
      final ledger = await db.loadLedger();
      await db.postSimple(
        accountId: ledger.balanceSheetAccounts.first.id,
        date: DateTime(2026, 10, 15),
        today: DateTime(2026, 10, 10),
        payee: 'МУИС',
        counterAccountId: ledger.categories
            .firstWhere((c) => c.name == 'Tuition')
            .id,
        amount: -200000000,
      );
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(),
          home: LedgerScreen(db: db, clock: () => DateTime(2026, 10, 10, 9)),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(
      find.text('Runs out 10.15 unless ₮2,500,000 due today comes'),
      findsOneWidget,
    );
    expect(find.text('+₮2,500,000 in, due today'), findsOneWidget);
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
    // The entry row stays open with a blinking cursor; hold it steady so the
    // capture doesn't depend on when it's taken.
    EditableText.debugDeterministicCursor = true;
    addTearDown(() => EditableText.debugDeterministicCursor = false);
    // The row refocuses its payee once the save has come back.
    await settle(tester);
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/ledger_short.png'),
    );
    await tidy(tester, db);
  });

  group('accounts', () {
    Future<void> menu(WidgetTester tester, String item) async {
      await tester.tap(find.byKey(const ValueKey('account-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(item)));
      await tester.pumpAndSettle();
    }

    testWidgets('add a card, answer what is owed, and it starts there', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await tester.tap(find.byKey(const ValueKey('add-account')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('new-account-name')),
        'Khan Visa',
      );
      await tester.tap(find.byKey(const ValueKey('kind-liability')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/account_new.png'),
      );
      await tapAndWait(
        tester,
        find.byKey(const ValueKey('new-account-create')),
      );

      expect(find.text('What do you owe on it today?'), findsOneWidget);
      expect(
        find.text(
          'What you’ve used, not the available limit · empty starts at ₮0',
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('start-balance')),
        '500000',
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/account_start.png'),
      );
      await tapAndWait(tester, find.byKey(const ValueKey('start-account')));
      expect(find.text('₮500,000 owed'), findsOneWidget); // sidebar
      expect(find.text('Opening balance'), findsOneWidget);
      // Only what hasn't settled is left to type, so the entry row is open.
      expect(
        find.text(
          'Started at ₮500,000 owed · add only what hasn’t settled yet',
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextField, 'New transaction — payee'),
        findsOneWidget,
      );

      // Undo takes the balance back, then ⌘Z the account.
      await tapAndWait(tester, find.text('Undo'));
      expect(find.text('What do you owe on it today?'), findsOneWidget);
      await tester.tap(find.text('What do you owe on it today?'));
      await tester.pumpAndSettle();
      await chord(tester, LogicalKeyboardKey.keyZ);
      await settle(tester);
      expect(find.text('Khan Visa'), findsNothing);
      await tidy(tester, db);
    });

    testWidgets('empty starts at ₮0 with the entry row open', (tester) async {
      final db = await pumpLedger(tester);
      await tester.tap(find.byKey(const ValueKey('add-account')));
      await tester.pumpAndSettle();
      await tapAndWait(
        tester,
        find.byKey(const ValueKey('new-account-create')),
      );
      expect(find.text('New account'), findsWidgets);
      await tapAndWait(tester, find.byKey(const ValueKey('start-account')));
      expect(find.byKey(const ValueKey('account-start')), findsNothing);
      expect(
        find.widgetWithText(TextField, 'New transaction — payee'),
        findsOneWidget,
      );
      await tidy(tester, db);
    });

    testWidgets('click the name to rename it', (tester) async {
      final db = await pumpLedger(tester);
      await tester.tap(find.byKey(const ValueKey('account-name')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('account-name-field')),
        'TDB Salary',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.text('TDB Salary'), findsNWidgets(2)); // title, sidebar
      await tapAndWait(tester, find.text('Undo'));
      expect(find.text('TDB Salary'), findsNothing);
      await tidy(tester, db);
    });

    testWidgets('right-click an account in the sidebar for its menu', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      final savings = find.text('Khan Savings').first;
      await tester.tap(savings, buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('menu-archive')), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/account_right_click.png'),
      );
      // Rename opens that account with its name ready to edit.
      await tester.tap(find.byKey(const ValueKey('menu-rename')));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('account-name-field'));
      expect(tester.widget<TextField>(field).controller!.text, 'Khan Savings');
      await tester.enterText(field, 'Khan Goal');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.text('Khan Goal'), findsNWidgets(2)); // title, sidebar

      // Archive from the menu, on an account that isn't open.
      await tester.tap(find.text('Cash wallet'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-archive')));
      await tester.pumpAndSettle();
      expect(find.text('Archive Cash wallet?'), findsOneWidget);
      await tapAndWait(tester, find.byKey(const ValueKey('warning-confirm')));
      expect(find.text('Cash wallet'), findsNothing);
      expect(find.text('Khan Goal'), findsNWidgets(2)); // still open
      await tidy(tester, db);
    });

    testWidgets('archive says what it leaves; Settings brings it back', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await menu(tester, 'menu-archive');
      expect(find.textContaining('₮4,182,450 is still in it'), findsOneWidget);
      expect(
        find.textContaining('3 scheduled rows (Zaisan Residence 09.20'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          '1 scheduled transfer stays on the other account’s forecast '
          '(Golomt Visa 09.25)',
        ),
        findsOneWidget,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/account_archive.png'),
      );
      await tapAndWait(tester, find.byKey(const ValueKey('warning-confirm')));
      // Gone from the sidebar; the next account opens; net worth unchanged.
      expect(find.text('₮4,182,450'), findsNothing);
      expect(find.text('Khan Savings'), findsNWidgets(2)); // title, sidebar
      expect(find.text('₮16,228,750'), findsOneWidget);
      expect(find.text('incl. ₮4,182,450 in archived'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('settings')));
      await tester.pumpAndSettle();
      expect(find.text('Archived accounts'), findsOneWidget);
      await tapAndWait(tester, find.textContaining('Show in sidebar'));
      expect(find.text('₮4,182,450'), findsOneWidget);
      expect(find.text('TDB Checking'), findsNWidgets(2)); // title, sidebar
      await tidy(tester, db);
    });

    testWidgets('delete says what goes and what stays, then does it', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await menu(tester, 'menu-delete');
      expect(find.text('Delete TDB Checking?'), findsOneWidget);
      expect(
        find.textContaining(
          'Its transfers stay on the other accounts as “TDB Checking (deleted)”: '
          '2 on Golomt Visa, 1 on Khan Savings.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'This deletes the account and its 13 rows, 4 of them reconciled.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Net worth goes down by ₮4,182,450'),
        findsOneWidget,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/account_delete.png'),
      );
      // Enter doesn't delete: the dialog is read, then clicked.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(find.text('Delete TDB Checking?'), findsOneWidget);
      await tapAndWait(tester, find.byKey(const ValueKey('warning-confirm')));

      expect(find.text('TDB Checking deleted'), findsOneWidget);
      expect(find.text('Undo'), findsNothing); // final, as it said
      await tester.tap(find.text('Khan Savings').first);
      await tester.pumpAndSettle();
      expect(find.text('TDB Checking (deleted)'), findsWidgets);

      // ⌘Z still works, as for everything this session.
      await chord(tester, LogicalKeyboardKey.keyZ);
      await settle(tester);
      expect(find.text('TDB Checking'), findsWidgets);
      expect(find.text('TDB Checking (deleted)'), findsNothing);

      // Redo deletes it again, with the same rows.
      await chord(tester, LogicalKeyboardKey.keyZ, shift: true);
      await settle(tester);
      expect(find.text('TDB Checking (deleted)'), findsWidgets);
      final ledger = await tester.runAsync(db.loadLedger);
      final checking = ledger!.accounts.values.firstWhere(
        (a) => a.name == 'TDB Checking',
      );
      expect(checking.deleted, isTrue);
      await tidy(tester, db);
    });
  });

  group('categories', () {
    Future<void> openBudget(WidgetTester tester) async {
      await tester.tap(find.text('Budget'));
      await tester.pumpAndSettle();
    }

    Future<void> categoryMenu(
      WidgetTester tester,
      String name,
      String item,
    ) async {
      await tester.tap(find.text(name), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(item)));
      await tester.pumpAndSettle();
    }

    testWidgets('the Budget screen lists categories with how they are used', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await openBudget(tester);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('add-category')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('new-category-name')),
        'Coffee',
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/budget_categories.png'),
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Coffee added'), findsOneWidget);
      // The add row stays open for the next; the same name again adds nothing.
      await tester.enterText(
        find.byKey(const ValueKey('new-category-name')),
        'coffee',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.text('Coffee is already a category'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('new-category-cancel')));
      await tester.pumpAndSettle();

      // Rename in place.
      await tester.tap(find.text('Coffee'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('category-name-field')),
        'Coffee & tea',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.text('Coffee & tea'), findsOneWidget);

      // Archive: out of the list, into Archived, and back.
      await categoryMenu(tester, 'Coffee & tea', 'category-archive');
      await settle(tester);
      expect(find.text('Coffee & tea'), findsNothing);
      await tester.pump(const Duration(seconds: 7)); // the toast goes
      await tester.tap(find.byKey(const ValueKey('show-archived-categories')));
      await tester.pumpAndSettle();
      expect(find.text('Coffee & tea'), findsOneWidget);
      await tapAndWait(tester, find.text('Show in menus'));
      expect(
        find.byKey(const ValueKey('show-archived-categories')),
        findsNothing,
      );
      expect(find.text('Coffee & tea'), findsOneWidget);
      await tidy(tester, db);
    });

    testWidgets('deleting a category with rows moves them first; undo', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await openBudget(tester);
      await categoryMenu(tester, 'Dining out', 'category-delete');
      expect(find.text('Delete Dining out?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('delete-category-into')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Groceries').last);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/budget_delete.png'),
      );
      await tapAndWait(tester, find.byKey(const ValueKey('warning-confirm')));
      expect(find.text('Dining out'), findsNothing);
      expect(
        find.text('Dining out deleted · 1 row moved to Groceries'),
        findsOneWidget,
      );

      await tester.tap(find.text('Ledger'));
      await tester.pumpAndSettle();
      expect(find.text('Dining out'), findsNothing); // Sakura Coffee's chip
      await chord(tester, LogicalKeyboardKey.keyZ);
      await settle(tester);
      expect(find.text('Dining out'), findsOneWidget);
      await chord(tester, LogicalKeyboardKey.keyZ, shift: true); // redo
      await settle(tester);
      expect(find.text('Dining out'), findsNothing);
      await tidy(tester, db);
    });

    testWidgets('a new name in the entry row becomes a category', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await openEntry(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'New transaction — payee'),
        'Nomin Coffee',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Category'), 'Cof');
      await tester.pumpAndSettle();
      expect(find.text('+ New category “Cof”'), findsOneWidget);
      expect(find.text('new category'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Category'),
        'Coffee',
      );
      await tester.enterText(find.widgetWithText(TextField, '0.00'), '6500');
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/entry_new_category.png'),
      );
      // Saving writes to the database: outside the fake clock.
      await tester.runAsync(() async {
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await settle(tester);
      expect(
        find.text('Nomin Coffee added · new category “Coffee”'),
        findsOneWidget,
      );
      expect(find.text('Coffee'), findsOneWidget); // the row's chip

      // One undo takes both.
      await tapAndWait(tester, find.text('Undo'));
      final ledger = await tester.runAsync(db.loadLedger);
      expect(ledger!.categories.map((c) => c.name), isNot(contains('Coffee')));
      expect(find.text('Nomin Coffee'), findsNothing);
      await tidy(tester, db);
    });

    testWidgets('typing part of a name and Enter picks it, not a new one', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await openEntry(tester);
      final category = find.widgetWithText(TextField, 'Category');
      await tester.enterText(category, 'Gro');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(category).controller!.text, 'Groceries');
      await tidy(tester, db);
    });

    testWidgets('renaming onto another name offers the merge', (tester) async {
      final db = await pumpLedger(tester);
      await openBudget(tester);
      await tester.tap(find.text('Gifts'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('category-name-field')),
        'entertainment',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.text('Merge Gifts into Entertainment?'), findsOneWidget);
      await tapAndWait(tester, find.byKey(const ValueKey('warning-confirm')));
      expect(find.text('Gifts'), findsNothing);
      expect(find.text('Gifts merged into Entertainment'), findsOneWidget);
      await tidy(tester, db);
    });

    testWidgets('editing a row in an archived category keeps it', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      final before = await tester.runAsync(db.loadLedger);
      final dining = before!.categories.firstWhere(
        (c) => c.name == 'Dining out',
      );
      await tester.runAsync(() => db.setArchived(dining.id, true));
      await settle(tester);
      await tester.tap(payeeCell);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(payeeCell);
      await tester.pumpAndSettle();
      // Its own category isn't "new".
      expect(find.text('new category'), findsNothing);
      await tester.enterText(find.widgetWithText(TextField, 'POS'), 'Latte');
      await tester.runAsync(() async {
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await settle(tester);
      final after = await tester.runAsync(db.loadLedger);
      expect(after!.knownCategories, hasLength(before.knownCategories.length));
      final row = after
          .registerFor(after.openAccounts.first.id)
          .posted
          .firstWhere((r) => r.payee == 'Sakura Coffee');
      expect(row.memo, 'Latte');
      expect(row.categoryId, dining.id);
      await tidy(tester, db);
    });

    testWidgets('a half-typed name from another field is not a new category', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await openEntry(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'New transaction — payee'),
        'Nomin',
      );
      final category = find.widgetWithText(TextField, 'Category');
      await tester.enterText(category, 'Gro');
      await tester.enterText(find.widgetWithText(TextField, '0.00'), '6500');
      await tester.runAsync(() async {
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await settle(tester);
      expect(
        find.text('“Gro” isn’t a category · pick Groceries, or + New category'),
        findsOneWidget,
      );
      // An account's name means the transfer.
      await tester.enterText(category, 'Golomt Visa');
      await tester.enterText(find.widgetWithText(TextField, '6500'), '7000');
      await tester.runAsync(() async {
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await settle(tester);
      expect(find.text('Did you mean “→ Golomt Visa”?'), findsOneWidget);
      final ledger = await tester.runAsync(db.loadLedger);
      expect(
        ledger!.categories.map((c) => c.name),
        isNot(anyOf(contains('Gro'), contains('Golomt Visa'))),
      );
      await tidy(tester, db);
    });
  });

  group('all accounts', () {
    testWidgets('every account in one register, each row naming its account', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await tester.tap(find.byKey(const ValueKey('all-accounts')));
      await tester.pumpAndSettle();
      expect(find.text('All accounts'), findsWidgets);
      expect(find.text('Account'), findsOneWidget); // the last column
      // A transfer shows once, from the account the money leaves.
      final ledger = await tester.runAsync(db.loadLedger);
      final savings = ledger!.registerAll().posted.firstWhere(
        (r) => r.payee == 'Khan Savings',
      );
      expect(ledger.accounts[savings.accountId]!.name, 'TDB Checking');
      expect(savings.amount, isNegative);
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/all_accounts.png'),
      );
      await tidy(tester, db);
    });

    testWidgets('a new row goes in the account picked in the row', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await tester.tap(find.byKey(const ValueKey('all-accounts')));
      await tester.pumpAndSettle();
      await openEntry(tester);
      // It starts on the account that was open.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('entry-account')),
          matching: find.text('TDB Checking'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('entry-account')));
      await tester.pumpAndSettle();
      final ledger = await tester.runAsync(db.loadLedger);
      final wallet = ledger!.openAccounts.firstWhere(
        (a) => a.name == 'Cash wallet',
      );
      await tester.tap(find.byKey(ValueKey('pick-account-${wallet.id}')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'New transaction — payee'),
        'Хүнсний дэлгүүр',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Category'),
        'Groceries',
      );
      await tester.enterText(find.widgetWithText(TextField, '0.00'), '12000');
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/all_accounts_entry.png'),
      );
      await tester.runAsync(() async {
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await settle(tester);
      final after = await tester.runAsync(db.loadLedger);
      final row = after!
          .registerFor(wallet.id)
          .posted
          .where((r) => r.payee == 'Хүнсний дэлгүүр');
      expect(row, hasLength(1));
      await tidy(tester, db);
    });

    testWidgets('a category’s usage opens its rows, with a total', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await tester.tap(find.text('Budget'));
      await tester.pumpAndSettle();
      final ledger = await tester.runAsync(db.loadLedger);
      final groceries = ledger!.categories.firstWhere(
        (c) => c.name == 'Groceries',
      );
      await tester.tap(find.byKey(ValueKey('category-rows-${groceries.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Category: Groceries'), findsOneWidget);
      // The budget's period: this month, which the chip names.
      expect(find.text('This month · 09.01–09.30'), findsOneWidget);
      expect(find.text('2 rows · ₮276,650.50 spent'), findsOneWidget);
      expect(find.text('Sakura Coffee'), findsNothing); // Dining out
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/all_accounts_category.png'),
      );
      // Esc takes the filter off.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('filter-chip')), findsNothing);
      expect(find.text('Sakura Coffee'), findsOneWidget);
      await tidy(tester, db);
    });

    testWidgets(
      'a batch stays on the picked account; hovering its list keeps the row',
      (tester) async {
        final db = await pumpLedger(tester);
        await tester.tap(find.byKey(const ValueKey('all-accounts')));
        await tester.pumpAndSettle();
        await openEntry(tester);
        final ledger = await tester.runAsync(db.loadLedger);
        final wallet = ledger!.openAccounts.firstWhere(
          (a) => a.name == 'Cash wallet',
        );
        // Open the list and move a real mouse over it, before typing.
        await tester.tap(find.byKey(const ValueKey('entry-account')));
        await tester.pumpAndSettle();
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(
          tester.getCenter(find.byKey(ValueKey('pick-account-${wallet.id}'))),
        );
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(TextField, 'New transaction — payee'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(ValueKey('pick-account-${wallet.id}')));
        await tester.pumpAndSettle();
        await mouse.removePointer();

        Future<void> add(String payee) async {
          await tester.enterText(
            find.widgetWithText(TextField, 'New transaction — payee'),
            payee,
          );
          await tester.enterText(
            find.widgetWithText(TextField, 'Category'),
            'Groceries',
          );
          await tester.enterText(
            find.widgetWithText(TextField, '0.00'),
            '5000',
          );
          await tester.runAsync(() async {
            await tester.testTextInput.receiveAction(TextInputAction.done);
            await Future<void>.delayed(const Duration(milliseconds: 300));
          });
          await settle(tester);
        }

        await add('Market one');
        await add('Market two');
        final after = await tester.runAsync(db.loadLedger);
        final inWallet = after!
            .registerFor(wallet.id)
            .posted
            .map((r) => r.payee)
            .toSet();
        expect(inWallet, containsAll(['Market one', 'Market two']));
        await tidy(tester, db);
      },
    );

    testWidgets('Rename from the sidebar opens that account', (tester) async {
      final db = await pumpLedger(tester);
      await tester.tap(find.byKey(const ValueKey('all-accounts')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Khan Savings').first,
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-rename')));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('account-name-field'));
      expect(tester.widget<TextField>(field).controller!.text, 'Khan Savings');
      await tidy(tester, db);
    });

    testWidgets('a card payment not yet on the card reads uncleared', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      final ledger = await tester.runAsync(db.loadLedger);
      final ids = {for (final a in ledger!.openAccounts) a.name: a.id};
      late int txn;
      await tester.runAsync(() async {
        txn = await db.postSimple(
          accountId: ids['TDB Checking']!,
          date: DateTime(2026, 9, 16),
          today: DateTime(2026, 9, 16),
          payee: 'Card payment',
          counterAccountId: ids['Golomt Visa']!,
          amount: -10000000,
        );
        final bank = (await db.loadLedger())
            .registerFor(ids['TDB Checking']!)
            .posted
            .firstWhere((r) => r.txnId == txn);
        await db.toggleCleared(bank.entryId); // left the bank
      });
      final after = await tester.runAsync(db.loadLedger);
      final row = after!.registerAll().posted.firstWhere((r) => r.txnId == txn);
      expect(row.cleared, Cleared.uncleared);
      expect(row.clearedIn, 'Golomt Visa');
      await tidy(tester, db);
    });
  });

  group('pay', () {
    testWidgets('no payday ahead: the forecast asks for pay, and it’s saved', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      // Cash wallet has no payday to run to.
      await tester.tap(find.text('Cash wallet').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('add-pay')), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('add-pay')));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(find.text('Add your pay'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pay-varies')));
      await tester.pumpAndSettle();
      expect(find.text('Expect at least'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('pay-amount')),
        '2100000',
      );
      await tester.tap(find.byKey(const ValueKey('pay-weeks')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('pay-anchor')),
        '2026.09.11',
      );
      await tester.pumpAndSettle();
      // Clicking elsewhere closes the calendar.
      await tester.tap(find.text('Add your pay'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pay-26')), findsOneWidget);
      expect(
        find.text(
          'Next payday 2026.09.25 · ₮2,100,000 or more · '
          'about ₮4,550,000 a month',
        ),
        findsOneWidget,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/pay_setup.png'),
      );
      await tapAndWait(tester, find.byKey(const ValueKey('pay-save')));
      expect(find.text('Pay saved · next payday 2026.09.25'), findsOneWidget);
      // The forecast runs to it now.
      expect(find.byKey(const ValueKey('add-pay')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('settings')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Salary · ₮2,100,000 or more · every 2 weeks · into Cash wallet',
        ),
        findsOneWidget,
      );
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/settings_budget.png'),
      );
      // Undo takes it all back.
      await chord(tester, LogicalKeyboardKey.keyZ);
      await settle(tester);
      final ledger = await tester.runAsync(db.loadLedger);
      expect(ledger!.paySchedules, isEmpty);
      await tidy(tester, db);
    });

    testWidgets('twice a month: an advance, then the rest', (tester) async {
      final db = await pumpLedger(tester);
      await tester.tap(find.byKey(const ValueKey('settings')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('settings-add-pay')));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pay-twice')));
      await tester.pumpAndSettle();
      // The same both days until asked otherwise.
      expect(find.byKey(const ValueKey('pay-amount2')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('pay-amount-split')));
      await tester.pumpAndSettle();
      expect(find.text('On the 10th'), findsOneWidget);
      expect(find.text('On the 25th'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('pay-amount')),
        '500000',
      );
      await tester.pumpAndSettle();
      expect(find.text('Put in how much comes on the 25th'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('pay-amount2')),
        '1600000',
      );
      await tester.pumpAndSettle();
      // Today is 09.16: the rest on the 25th comes next.
      expect(
        find.text(
          'Next payday 2026.09.25 · ₮1,600,000 · about ₮2,100,000 a month',
        ),
        findsOneWidget,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/pay_setup_split.png'),
      );
      await tapAndWait(tester, find.byKey(const ValueKey('pay-save')));
      expect(
        find.text(
          'Salary · ₮500,000 on the 10th and ₮1,600,000 on the 25th · '
          'into TDB Checking',
        ),
        findsOneWidget,
      );
      // Editing it back to one amount keeps the larger, not the advance.
      await tester.runAsync(() async {
        await tester.tap(
          find.byKey(
            ValueKey(
              'edit-pay-${(await db.loadLedger()).paySchedules.single.id}',
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(find.text('On the 10th'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pay-monthly')));
      await tester.pumpAndSettle();
      expect(find.text('Each payday'), findsOneWidget);
      expect(find.text('1,600,000'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pay-cancel')));
      await tester.pumpAndSettle();
      final ledger = await tester.runAsync(db.loadLedger);
      final pay = ledger!.paySchedules.single;
      expect(pay.byDay, [
        (day: 10, amount: 50000000),
        (day: 25, amount: 160000000),
      ]);
      await tidy(tester, db);
    });

    testWidgets(
      '“I don’t have regular pay” stops the asking; Settings undoes it',
      (tester) async {
        final db = await pumpLedger(tester);
        await tester.tap(find.text('Cash wallet').first);
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const ValueKey('add-pay')));
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();
        await tapAndWait(tester, find.byKey(const ValueKey('pay-none')));
        expect(
          find.text(
            'No regular pay · the app won’t ask for it · Settings changes this',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('add-pay')), findsNothing);
        await tester.tap(find.text('Budget'));
        await tester.pumpAndSettle();
        expect(find.text('payday · no regular pay'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('settings')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('settings-no-pay')), findsOneWidget);
        await tapAndWait(
          tester,
          find.byKey(const ValueKey('settings-ask-pay')),
        );
        expect(find.byKey(const ValueKey('settings-no-pay')), findsNothing);
        // ⌘Z puts "no regular pay" back.
        await chord(tester, LogicalKeyboardKey.keyZ);
        await settle(tester);
        expect(find.byKey(const ValueKey('settings-no-pay')), findsOneWidget);
        // Adding pay anyway: the saying goes with it, and comes back on undo.
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const ValueKey('settings-add-pay')));
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('pay-none')), findsNothing);
        await tester.enterText(
          find.byKey(const ValueKey('pay-amount')),
          '2000000',
        );
        await tester.pumpAndSettle();
        await tapAndWait(tester, find.byKey(const ValueKey('pay-save')));
        expect(
          (await tester.runAsync(db.loadLedger))!.prefs[noRegularPayKey],
          isNull,
        );
        await chord(tester, LogicalKeyboardKey.keyZ);
        await settle(tester);
        expect(
          (await tester.runAsync(db.loadLedger))!.prefs[noRegularPayKey],
          '1',
        );
        await tidy(tester, db);
      },
    );

    testWidgets('the Budget screen says which income is payday', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await tester.tap(find.text('Budget'));
      await tester.pumpAndSettle();
      expect(find.text('payday · pay not set up'), findsOneWidget);
      await tester.tap(find.text('Salary'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tapAndWait(tester, find.byKey(const ValueKey('category-payday')));
      expect(find.text('not a payday'), findsOneWidget);
      await tidy(tester, db);
    });

    testWidgets('pay that varies, confirmed under the estimate', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      final ledger = await tester.runAsync(db.loadLedger);
      final salary = ledger!.categories.firstWhere((c) => c.name == 'Salary');
      final checking = ledger.openAccounts.first.id;
      await tester.runAsync(
        () => db.savePaySchedule(
          categoryId: salary.id,
          accountId: checking,
          amount: 210000000,
          varies: true,
          rule: PayRule.monthly,
          day1: 17,
          today: DateTime(2026, 9, 16),
        ),
      );
      await settle(tester);
      final payday = find.text('Salary').first;
      expect(payday, findsWidgets);
      final row = (await tester.runAsync(db.loadLedger))!
          .registerFor(checking)
          .scheduled
          .firstWhere((r) => r.estimate != null);
      await tester.runAsync(
        () => db.editTransaction(
          transactionId: row.txnId,
          accountId: checking,
          date: DateTime(2026, 9, 16),
          today: DateTime(2026, 9, 16),
          amount: 200000000,
          confirm: true,
        ),
      );
      final next = await tester.runAsync(
        () => db.ensurePaydays(DateTime(2026, 9, 16)),
      );
      expect(next, hasLength(1));
      // Paid a day early for the 17th: the next is October's (the 17th is a
      // Saturday, so Friday the 16th), not the 17th again.
      final after = await tester.runAsync(db.loadLedger);
      expect(
        after!.txns.firstWhere((t) => t.id == next!.single).date,
        DateTime(2026, 10, 16),
      );
      await tidy(tester, db);
    });
  });

  group('appearance', () {
    tearDown(() => Mid.palette = Palette.dark);

    testWidgets('follows the Mac, and Settings picks light or dark', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const window = MethodChannel('betterbudget/window');
      final looks = <Map<Object?, Object?>>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(window, (
        call,
      ) async {
        looks.add(call.arguments as Map<Object?, Object?>);
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          window,
          null,
        ),
      );
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final db = AppDatabase(NativeDatabase.memory());
      final appearance = AppearanceController();
      await tester.runAsync(() async {
        await tester.pumpWidget(
          AppearanceScope(
            controller: appearance,
            // A Builder, as the app's startup is: the theme is made again
            // when the appearance changes.
            child: Builder(
              builder: (_) => MaterialApp(
                debugShowCheckedModeBanner: false,
                themeAnimationDuration: Duration.zero,
                theme: appTheme(),
                home: LedgerScreen(
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
      // Same as this Mac, which is light.
      expect(Mid.isLight, isTrue);
      expect(
        Theme.of(tester.element(find.byType(LedgerScreen))).brightness,
        Brightness.light,
      );
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/ledger_light.png'),
      );

      // The Mac turns dark; the app follows.
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(Mid.isLight, isFalse);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(Mid.isLight, isTrue);

      await tester.tap(find.byKey(const ValueKey('settings')));
      await tester.pumpAndSettle();
      expect(find.text('Same as this Mac'), findsOneWidget);
      expect(
        find.text('Showing light now · changes when the Mac does'),
        findsOneWidget,
      );
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/settings_appearance_light.png'),
      );

      await tester.tap(find.byKey(const ValueKey('appearance-dark')));
      await tester.pumpAndSettle();
      expect(appearance.value, Appearance.dark);
      expect(Mid.isLight, isFalse);
      expect(find.textContaining('Showing'), findsNothing);
      // The title bar is told each time.
      expect(looks.last, {
        'dark': true,
        'ground': Palette.dark.ground.toARGB32(),
      });

      await tester.runAsync(() async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(appearance.value, Appearance.system);
      expect(Mid.isLight, isTrue);
      await settle(tester);
      expect(find.text('Undone · Appearance: Dark'), findsOneWidget);
      expect(looks.last['dark'], false);

      await tester.runAsync(() async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(appearance.value, Appearance.dark);
      expect(Mid.isLight, isFalse);
      await tidy(tester, db);
      // Checked before tear-downs run; the tear-down covers a failed expect.
      debugDefaultTargetPlatformOverride = null;
    });

    test('the choice is kept in a file on this computer', () async {
      final dir = await Directory.systemTemp.createTemp('appearance');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/appearance');
      expect((await AppearanceController.load(file)).value, Appearance.system);
      await (await AppearanceController.load(file)).set(Appearance.light);
      expect((await AppearanceController.load(file)).value, Appearance.light);
      await file.writeAsString('purple');
      expect((await AppearanceController.load(file)).value, Appearance.system);
    });
  });

  testWidgets('import: pick a bank file, check its columns, import, undo; '
      'the next file skips the columns', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dialogs = _FakeDialogs();
    final before = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = dialogs;
    addTearDown(() => FileSelectorPlatform.instance = before);
    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('bb-import'),
    ))!;
    // Made-up rows in TDB's plain layout: no header row, a totals footer.
    final file = '${dir.path}/ST_TEST.XLS';
    await tester.runAsync(
      () => File(file).writeAsBytes(
        buildXls({
          (0, 0): 'Данс: 0000000000 MNT',
          (1, 0): DateTime(2026, 9, 14, 9, 5),
          (1, 2): 0.0,
          (1, 3): 12500.0,
          (1, 5): '5000000001 Номин ХХК',
          (1, 6): 987500.0,
          (1, 7): 'POS 10000001: НОМИН',
          (2, 0): DateTime(2026, 9, 15, 13, 30),
          (2, 2): 250000.0,
          (2, 3): 0.0,
          (2, 6): 1237500.0,
          (2, 7): 'Буцаалт',
          (3, 0): DateTime(2026, 9, 15, 18, 0),
          (3, 2): 0.0,
          (3, 3): 7000.0,
          (3, 6): 1230500.0,
          (3, 7): 'QPay Туршилтын кофе',
          (4, 0): 'Нийт:',
        }),
      ),
    );
    final db = await pumpLedger(tester);

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

    Future<int> imported() async => (await tester.runAsync(
      () async => (await db.loadLedger()).txns
          .where((t) => t.payee == 'QPay Туршилтын кофе')
          .length,
    ))!;

    // Cancelled: nothing opens.
    await run(find.byKey(const ValueKey('import')));
    expect(find.byType(Dialog), findsNothing);

    dialogs.openPath = file;
    await run(find.byKey(const ValueKey('import')));
    expect(find.text('Import into TDB Checking'), findsOneWidget);
    expect(find.byKey(const ValueKey('import-role-3')), findsOneWidget);
    expect(find.textContaining('3 new rows'), findsOneWidget);
    expect(
      find.textContaining('The bank’s running balance adds up on every row'),
      findsOneWidget,
    );
    await expectLater(
      find.byType(Dialog),
      matchesGoldenFile('goldens/import_columns.png'),
    );

    await run(find.byKey(const ValueKey('import-do')));
    expect(find.byType(Dialog), findsNothing);
    expect(find.textContaining('Imported 3 rows'), findsOneWidget);
    expect(await imported(), 1);
    expect(find.text('Номин ХХК'), findsOneWidget);

    // ⌘Z takes the whole import back.
    await tester.runAsync(() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('Undone · Imported 3 rows'), findsOneWidget);
    expect(await imported(), 0);

    // The same layout again: straight to the rows, with the saved columns.
    await run(find.byKey(const ValueKey('import')));
    expect(
      find.text('Read with the columns you set for this account last time.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('import-role-3')), findsNothing);
    expect(find.textContaining('3 new rows'), findsOneWidget);
    await run(find.byKey(const ValueKey('import-cancel')));
    expect(find.byType(Dialog), findsNothing);
    await tidy(tester, db);
  });

  testWidgets('a dollar account: made in dollars, shown in dollars, and a '
      'transfer to it from tögrög takes both amounts', (tester) async {
    final db = await pumpLedger(tester);
    await tester.tap(find.byKey(const ValueKey('add-account')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('new-account-name')),
      'Chase',
    );
    await tester.tap(find.byKey(const ValueKey('currency-USD')));
    await tester.pumpAndSettle();
    await tapAndWait(tester, find.byKey(const ValueKey('new-account-create')));
    expect(
      find.text(
        'From the bank app, a statement or what you count, not the '
        '“available” balance · empty starts at \$0',
      ),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const ValueKey('start-balance')), '250');
    await tapAndWait(tester, find.byKey(const ValueKey('start-account')));
    expect(find.text(r'$250'), findsNWidgets(2)); // sidebar, net worth
    expect(find.textContaining(r'Started at $250'), findsOneWidget);
    // Net worth: each currency on its own line.
    expect(find.byKey(const ValueKey('net-worth-MNT')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('net-worth-USD'))).data,
      r'$250',
    );

    // From TDB Checking, a transfer to Chase asks what arrived there.
    await tester.tap(find.text('TDB Checking').first);
    await tester.pumpAndSettle();
    await openEntry(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Category'),
      '→ Chase',
    );
    await tester.enterText(find.widgetWithText(TextField, '0.00'), '3450000');
    await tester.pump();
    expect(find.text('Arrives in Chase:'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('exchange-amount')),
        matching: find.byType(TextField),
      ),
      '1000',
    );
    await tester.pump();
    expect(find.text(r'₮3,450.00 per $1'), findsOneWidget);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/entry_exchange.png'),
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    await settle(tester);
    final data = (await tester.runAsync(db.loadLedger))!;
    final chase = data.balanceSheetAccounts.firstWhere(
      (a) => a.name == 'Chase',
    );
    expect(data.balanceOf(chase.id), 125000);
    expect(find.text(r'$1,250'), findsNWidgets(2)); // sidebar, net worth
    expect(
      find.textContaining(r'$1,000.00 there · ₮3,450.00 per $1'),
      findsOneWidget,
    );
    await tidy(tester, db);
  });
}
