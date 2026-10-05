import 'dart:io';

import 'package:betterbudget/data/backup.dart';
import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/domain/budget.dart' show Budget, BudgetKeys;
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/money.dart';
import 'package:betterbudget/domain/pay.dart';
import 'package:betterbudget/domain/readiness.dart';
import 'package:betterbudget/ui/appearance.dart';
import 'package:betterbudget/ui/brand.dart';
import 'package:betterbudget/ui/fit_window.dart';
import 'package:betterbudget/ui/schemes.dart';
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
import 'package:package_info_plus/package_info_plus.dart';

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
    await _loadFont(
      'BetterBudget Symbols',
      'assets/fonts/BetterBudgetSymbols.ttf',
    );
    final icons =
        '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    if (File(icons).existsSync()) await _loadFont('MaterialIcons', icons);
  });

  Future<AppDatabase> pumpLedger(
    WidgetTester tester, {
    Size size = const Size(1440, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(),
          builder: (context, child) => FitWindow(child: child!),
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

  // The Mac window stops at 1360 wide (MainFlutterWindow.swift): there the
  // account page shows everything. A smaller screen squeezes it instead of
  // running out of room (an overflow fails the test).
  for (final (name, size) in [
    ('the smallest window', const Size(1360, 760)),
    ('a screen smaller than that', const Size(1100, 700)),
  ]) {
    testWidgets('an account page fits $name', (tester) async {
      final db = await pumpLedger(tester, size: size);
      expect(find.text('Last reconciled on 09.10'), findsOneWidget);
      expect(find.text('2 not cleared yet'), findsOneWidget);
      await expectLater(
        find.byType(FitWindow),
        matchesGoldenFile(
          size.width >= FitWindow.smallest.width
              ? 'goldens/ledger_smallest_window.png'
              : 'goldens/ledger_small_screen.png',
        ),
      );
      await openEntry(tester);
      await tester.tap(find.byKey(const ValueKey('reconcile')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Budget'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Savings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tidy(tester, db);
    });
  }

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
    expect(data.prefs[ReadyKeys.month], 'MNT:200000000');
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
    expect(find.text('3 bills · ₮2,790,200 through 10.10'), findsOneWidget);
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
    await tester.enterText(find.widgetWithText(TextField, '₮0.00'), '+500000');
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
      await tester.enterText(field('₮0.00'), '8000');
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
      await tester.enterText(field('₮0.00'), '8000');
      await tester.enterText(field('New transaction — payee'), 'Sakura Coffee');
      await enter(tester); // category is filled from the payee's last one
      expect(find.text('Sakura Coffee'), findsNWidgets(2));
      expect(find.text('₮4,174,450.00'), findsWidgets);
      await tidy(tester, db);
    });

    testWidgets('the Add button adds a complete row, memo included', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await openEntry(tester);
      await tester.enterText(field('Category'), 'Dining out');
      await tester.enterText(field('New transaction — payee'), 'Modern Nomads');
      await tester.enterText(field('₮0.00'), '42000');
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
    expect(find.text('₮640,200.00 owed'), findsOneWidget); // sidebar
    await tester.tap(find.text('Golomt Visa'));
    await tester.pumpAndSettle();
    expect(find.text('Owed'), findsWidgets); // total line and Balance column
    expect(find.text('₮640,200.00', findRichText: true), findsWidgets);
    expect(find.textContaining('Below zero'), findsNothing);
    expect(find.text('₮0 owed after 09.25'), findsOneWidget);
    expect(find.text('1 payment · ₮640,200 through 10.16'), findsOneWidget);
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

  testWidgets(
    'the search key works again after clicking out of search',
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    (tester) async {
      final db = await pumpLedger(tester);
      final search = find.widgetWithText(
        TextField,
        'Search payee, memo, amount',
      );
      bool searching() => tester.widget<TextField>(search).focusNode!.hasFocus;
      await chord(tester, LogicalKeyboardKey.keyF, meta: true);
      await tester.pumpAndSettle();
      expect(searching(), isTrue);
      // A click on nothing in particular (on a Mac that takes focus out of
      // the field): it must not fall where the screen's keys can't hear it.
      await tester.tapAt(const Offset(700, 80));
      await tester.pumpAndSettle();
      expect(searching(), isFalse);
      await chord(tester, LogicalKeyboardKey.keyF, meta: true);
      await tester.pumpAndSettle();
      expect(searching(), isTrue);
      await tidy(tester, db);
    },
  );

  testWidgets('only one row is open for typing at a time', (tester) async {
    final db = await pumpLedger(tester);
    final newPayee = find.widgetWithText(TextField, 'New transaction — payee');
    // Clicking the selected row again closes its actions, so click until
    // Edit shows.
    Future<void> rowActions() async {
      for (var i = 0; i < 2 && find.text('Edit').evaluate().isEmpty; i++) {
        await tester.tap(find.text('Unitel'));
        await tester.pumpAndSettle();
      }
    }

    // Add while a row's Edit is open (nothing changed in it): Edit closes.
    await rowActions();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cancel-edit')), findsOneWidget);
    await openEntry(tester);
    expect(newPayee, findsOneWidget);
    expect(find.byKey(const ValueKey('cancel-edit')), findsNothing);

    // Edit while the new row holds typing: it stays, and Edit doesn't open.
    await tester.enterText(newPayee, 'Nomin');
    await tester.pumpAndSettle();
    await rowActions();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cancel-edit')), findsNothing);
    expect(find.widgetWithText(TextField, 'Nomin'), findsOneWidget);
    expect(
      find.text('Save with Enter, or press Esc to discard your changes'),
      findsOneWidget,
    );

    // Add while an Edit holds changes: Edit stays, and no new row opens.
    await tester.enterText(find.widgetWithText(TextField, 'Nomin'), '');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await rowActions();
    await tester.tap(find.text('Edit'));
    await tester.pump();
    await tester.pump();
    tester.testTextInput.enterText('Unitel LLC');
    await tester.pump();
    await openEntry(tester);
    expect(find.byKey(const ValueKey('cancel-edit')), findsOneWidget);
    expect(newPayee, findsNothing);
    await tidy(tester, db);
  });

  testWidgets(
    'an Edit closes with the mouse: Cancel, or a click away when untouched',
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    (tester) async {
      final db = await pumpLedger(tester);
      final cancel = find.byKey(const ValueKey('cancel-edit'));
      Future<void> edit() async {
        for (var i = 0; i < 2 && find.text('Edit').evaluate().isEmpty; i++) {
          await tester.tap(find.text('Unitel'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        expect(cancel, findsOneWidget);
      }

      // Untouched: a click on nothing in particular closes it.
      await edit();
      await tester.tapAt(const Offset(700, 80));
      await tester.pumpAndSettle();
      expect(cancel, findsNothing);

      // A click inside the row isn't a click away: on its pencil (so its
      // buttons get their click before the row could close), or its Memo.
      await edit();
      await tester.tap(find.byIcon(Icons.edit_rounded));
      await tester.pumpAndSettle();
      expect(cancel, findsOneWidget);
      await tester.tap(find.widgetWithText(TextField, 'Postpaid'));
      await tester.pumpAndSettle();
      expect(cancel, findsOneWidget);

      // With a change it stays through a click away, and Cancel drops it.
      tester.testTextInput.enterText('Postpaid plan');
      await tester.pump();
      await tester.tapAt(const Offset(700, 80));
      await tester.pumpAndSettle();
      expect(cancel, findsOneWidget);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(cancel, findsNothing);
      expect(find.text('Postpaid plan'), findsNothing);
      expect(find.text('Postpaid'), findsOneWidget);
      await tidy(tester, db);
    },
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
      await tester.enterText(find.widgetWithText(TextField, '₮0.00'), '42000');
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
    await tester.enterText(find.widgetWithText(TextField, '₮0.00'), '640200');
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
      '₮4,182,450.00',
      'Golomt Visa',
      '₮640,200.00 owed',
      '19 transactions',
    ]) {
      expect(find.descendant(of: goes, matching: find.text(t)), findsOneWidget);
    }
    expect(find.text('Your 14 categories'), findsOneWidget);
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

  test('a new ledger without categories starts with only Income', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedDemoIfEmpty(db, DateTime(2026, 9, 16));
    await db.startNewLedger(DateTime(2026, 9, 16), keepCategories: false);
    final ledger = await db.loadLedger();
    expect(ledger.accounts.values.single, ledger.income);
    expect(ledger.txns, isEmpty);
    expect(await db.startedOwnLedger(), isTrue);
    await seedDemoIfEmpty(db, DateTime(2026, 9, 17));
    expect((await db.loadLedger()).accounts, hasLength(1));
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
    await tester.scrollUntilVisible(
      find.text('Skytel'),
      120,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .last,
    );
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
      find.widgetWithText(TextField, '₮0.00'),
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
    // The sidebar says so too, with a coral dot beside the account.
    final short = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith('runs-out-'),
    );
    expect(short, findsOneWidget);
    // The dot names the first dip, what it would take to stay above zero
    // that day; the headline keeps the lowest point.
    expect(
      find.byTooltip('Runs out on 09.30 · ₮357,750 short'),
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

  testWidgets('trouble past the view is said above the forecast', (
    tester,
  ) async {
    final db = await pumpLedger(tester);
    // Pay on the 10th into TDB Checking (it takes over the demo's salary
    // typed for 10.10), so the account is looked at a year of paychecks
    // ahead; and a bill on 11.20, past the pay period the forecast shows
    // (to the 11.10 paycheck), bigger than what's there by then.
    await tester.runAsync(() async {
      final ledger = await db.loadLedger();
      final checking = ledger.openAccounts
          .firstWhere((a) => a.name == 'TDB Checking')
          .id;
      await db.savePaySchedule(
        accountId: checking,
        amount: 250000000,
        rule: PayRule.monthly,
        day1: 10,
        today: DateTime(2026, 9, 16),
      );
      await db.postSimple(
        accountId: checking,
        date: DateTime(2026, 11, 20),
        today: DateTime(2026, 9, 16),
        payee: 'МУИС',
        counterAccountId: ledger.categories
            .firstWhere((c) => c.name == 'Tuition')
            .id,
        amount: -800000000,
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    // The headline is calm; the line above the title isn't, and the
    // sidebar's dot agrees. Both name the first dip: what it would take
    // to stay above zero that day.
    expect(find.text('Until your 11.10 paycheck'), findsOneWidget);
    expect(find.text('Lowest ₮1,392,250 on 10.01'), findsOneWidget);
    expect(
      find.text('After 11.10: runs out on 11.20 · ₮1,607,750 short'),
      findsOneWidget,
    );
    expect(
      find.byTooltip('Runs out on 11.20 · ₮1,607,750 short'),
      findsOneWidget,
    );
    // A click looks that far: 90 days reaches 11.20, 60 don't. The
    // December paycheck is expected, not a row.
    await tapAndWait(
      tester,
      find.byKey(const ValueKey('forecast-short-ahead')),
    );
    expect(find.text('Next 90 days'), findsOneWidget);
    expect(
      find.text('Runs out on 11.20 · up to ₮1,607,750 short'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('forecast-short-ahead')), findsNothing);
    await tidy(tester, db);
  });

  testWidgets('the forecast looks as far as the small title says', (
    tester,
  ) async {
    final db = await pumpLedger(tester);
    // The demo's salary on 10.10 ends the forecast; the title is the
    // dropdown, and names that choice by the date.
    expect(find.text('Until your 10.10 paycheck'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('forecast-span')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('forecast-span-payPeriod')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('forecast-span-year')), findsOneWidget);
    await tapAndWait(
      tester,
      find.byKey(const ValueKey('forecast-span-days90')),
    );
    // 90 days from 09.16 is 12.15: the title and the bill line say so.
    expect(find.text('Next 90 days'), findsOneWidget);
    expect(find.textContaining('through 12.15'), findsOneWidget);
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/forecast_span_90.png'),
    );
    // One choice for every account, kept in the ledger.
    var data = (await tester.runAsync(db.loadLedger))!;
    expect(data.prefs['forecast.span'], 'days90');
    // And back to the pay period.
    await tester.tap(find.byKey(const ValueKey('forecast-span')));
    await tester.pumpAndSettle();
    await tapAndWait(
      tester,
      find.byKey(const ValueKey('forecast-span-payPeriod')),
    );
    expect(find.text('Until your 10.10 paycheck'), findsOneWidget);
    data = (await tester.runAsync(db.loadLedger))!;
    expect(data.prefs['forecast.span'], 'payPeriod');
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
      expect(find.text('₮500,000.00 owed'), findsOneWidget); // sidebar
      // Payee and category both say it, singular (owner, 2026-09-30).
      expect(find.text('Opening balance'), findsNWidgets(2));
      expect(find.text('Opening balances'), findsNothing);
      // Only what hasn't cleared is left to type, so the entry row is open,
      // with no toast: the account was just made (owner, 2026-09-30).
      expect(find.textContaining('Started at'), findsNothing);
      expect(
        find.widgetWithText(TextField, 'New transaction — payee'),
        findsOneWidget,
      );

      // ⌘Z takes the balance back (no toast to click), then the account.
      // Esc closes the entry row and leaves ⌘Z working, no click needed.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await chord(tester, LogicalKeyboardKey.keyZ);
      await settle(tester);
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
      expect(find.text('₮16,228,750.00'), findsOneWidget);
      expect(find.text('incl. ₮4,182,450 in archived'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('settings')));
      await tester.pumpAndSettle();
      expect(find.text('Archived accounts'), findsOneWidget);
      await tapAndWait(tester, find.textContaining('Show in sidebar'));
      expect(find.text('₮4,182,450.00'), findsOneWidget);
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

    /// Edit, from a category's menu: everything about it, under its row.
    Future<void> editCategory(WidgetTester tester, String name) =>
        categoryMenu(tester, name, 'category-edit');

    testWidgets(
      'two earners: named pays, the view by one, an amount per the other',
      (tester) async {
        final db = await pumpLedger(tester);
        late int jenny;
        await tester.runAsync(() async {
          final data = await db.loadLedger();
          int account(String name) =>
              data.balanceSheetAccounts.firstWhere((a) => a.name == name).id;
          await db.savePaySchedule(
            accountId: account('TDB Checking'),
            name: 'Jeff',
            amount: 250000000,
            rule: PayRule.monthly,
            day1: 25,
            today: DateTime(2026, 9, 16),
          );
          jenny = (await db.savePaySchedule(
            accountId: account('Khan Savings'),
            name: 'Jenny',
            amount: 120000000,
            rule: PayRule.everyWeeks,
            weeks: 2,
            anchor: DateTime(2026, 9, 11),
            weekend: PayWeekend.keep,
            today: DateTime(2026, 9, 16),
          )).after.id;
        });
        await settle(tester);
        await openBudget(tester);
        String title() => tester
            .widget<Text>(find.byKey(const ValueKey('period-title')))
            .data!;
        // The view dropdown beside the period: by month, or by either pay,
        // each by its name.
        expect(title(), 'This month · 09.01–09.30');
        expect(find.byKey(const ValueKey('budget-view')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('budget-view')));
        await tester.pumpAndSettle();
        expect(find.text('Jeff'), findsOneWidget);
        expect(find.text('Jenny'), findsOneWidget);
        await tapAndWait(tester, find.byKey(ValueKey('budget-view-$jenny')));
        await settle(tester);
        expect(title(), 'This pay period · 09.11–09.24');
        // A view, not a change: no toast.
        expect(find.byKey(const ValueKey('toast')), findsNothing);

        // Groceries: a set amount per Jeff's pay, chosen in its Edit (Month
        // is the default), seen here by Jenny's periods as about a share.
        await editCategory(tester, 'Groceries');
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('plan-amount')),
            matching: find.byType(EditableText),
            matchRoot: true,
          ),
          '600000',
        );
        await tester.pumpAndSettle();
        // Made while viewing by Jenny, it starts per Jenny's pay (a
        // default, not a question); Every month is one click away.
        expect(find.text('Set aside each pay period'), findsOneWidget);
        expect(find.text('Every pay period · Jenny'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('plan-each-period')));
        await tester.pumpAndSettle();
        expect(find.text('Every month'), findsWidgets);
        expect(find.text('Every pay period · Jeff'), findsOneWidget);
        expect(find.text('Every pay period · Jenny'), findsNWidgets(2));
        final jeff = (await tester.runAsync(db.loadLedger))!.paySchedules
            .firstWhere((p) => p.name == 'Jeff')
            .id;
        await tester.tap(find.byKey(ValueKey('plan-each-pay-$jeff')));
        await tester.pumpAndSettle();
        expect(find.text('Set aside each pay period'), findsOneWidget);
        expect(find.text('What’s left at the period’s end'), findsOneWidget);
        final preview = tester
            .widget<Text>(find.byKey(const ValueKey('plan-preview')))
            .data!;
        // Jeff's period (08.25–09.24) ends with Jenny's: its whole rest is
        // in view, so nothing is about.
        expect(preview, '₮600,000 each pay period · Jeff');
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const ValueKey('edit-save')));
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await settle(tester);
        final plan = (await tester.runAsync(db.loadLedger))!.plans.values
            .firstWhere((p) => p.kind == PlanKind.each);
        expect(plan.payScheduleId, jeff);
        expect(find.text('₮600,000 each pay period · Jeff'), findsOneWidget);
        expect(find.text('Assign ₮600,000'), findsOneWidget);
        // A period later, Jeff's next (09.25–10.22: the 25th is a Sunday,
        // paid the Friday before) is cut by Jenny's (09.25–10.08): 14 of
        // its 28 days, said as about.
        await tester.tap(find.byKey(const ValueKey('period-next')));
        await tester.pumpAndSettle();
        expect(
          find.text(
            '₮600,000 each pay period · Jeff · about ₮300,000 this pay period',
          ),
          findsOneWidget,
        );
        // Jenny's 11.20–12.03 holds the last 5 days of Jeff's 10.23–11.24,
        // never filled, and 9 of his next 30: said as what that period
        // still needs, plus the share toward the next, not as "about
        // ₮780,000" (owner, 2026-10-05).
        for (var i = 0; i < 4; i++) {
          await tester.tap(find.byKey(const ValueKey('period-next')));
          await tester.pumpAndSettle();
        }
        expect(title(), 'Pay period · 11.20–12.03');
        expect(
          find.text(
            '₮600,000 each pay period · Jeff · ₮600,000 still to put in for '
            '10.23–11.24 · plus about ₮180,000 toward the next',
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('period-today')));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(LedgerScreen),
          matchesGoldenFile('goldens/budget_two_earners.png'),
        );
        // Both pays on the Income tab, by name (the view says Jenny too).
        await tester.tap(find.byKey(const ValueKey('budget-tab-income')));
        await tester.pumpAndSettle();
        for (final (id, name) in [(jeff, 'Jeff'), (jenny, 'Jenny')]) {
          expect(
            find.descendant(
              of: find.byKey(ValueKey('pay-row-$id')),
              matching: find.text(name),
            ),
            findsOneWidget,
          );
        }
        // ⌘Z undoes newest first: the plan, then the view; ⇧⌘Z redoes.
        await chord(tester, LogicalKeyboardKey.keyZ);
        await settle(tester);
        await chord(tester, LogicalKeyboardKey.keyZ);
        await settle(tester);
        expect(title(), 'This month · 09.01–09.30');
        await chord(tester, LogicalKeyboardKey.keyZ, shift: true);
        await settle(tester);
        expect(title(), 'This pay period · 09.11–09.24');
        await tidy(tester, db);
      },
    );

    testWidgets(
      'stopping a pay moves the categories per it, and ⌘Z puts all back',
      (tester) async {
        final db = await pumpLedger(tester);
        late int jeff, jenny, groceries, housing;
        await tester.runAsync(() async {
          final data = await db.loadLedger();
          int account(String name) =>
              data.balanceSheetAccounts.firstWhere((a) => a.name == name).id;
          int category(String name) =>
              data.categories.firstWhere((c) => c.name == name).id;
          groceries = category('Groceries');
          housing = category('Housing');
          final today = DateTime(2026, 9, 16);
          jeff = (await db.savePaySchedule(
            accountId: account('TDB Checking'),
            name: 'Jeff',
            amount: 250000000,
            rule: PayRule.monthly,
            day1: 25,
            today: today,
          )).after.id;
          jenny = (await db.savePaySchedule(
            accountId: account('Khan Savings'),
            name: 'Jenny',
            amount: 120000000,
            rule: PayRule.everyWeeks,
            weeks: 2,
            anchor: DateTime(2026, 9, 11),
            weekend: PayWeekend.keep,
            today: today,
          )).after.id;
          // A set amount per Jeff's pay, and a bill every payday of it.
          await db.changeCategoryPlan(
            groceries,
            CategoryPlan(
              categoryId: groceries,
              kind: PlanKind.each,
              amount: 60000000,
              start: today,
              payScheduleId: jeff,
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
              payScheduleId: jeff,
            ),
            today,
          );
        });
        await settle(tester);
        await openBudget(tester);
        await tester.tap(find.byKey(const ValueKey('budget-tab-income')));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(find.byKey(ValueKey('edit-pay-$jeff')));
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();
        // Stop: the categories per Jeff are named, and the one other pay is
        // the offered answer; Every month is the other.
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const ValueKey('pay-stop')));
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();
        expect(
          find.text(
            '2 categories are budgeted per this pay: Groceries, Housing',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('stop-move-month')), findsOneWidget);
        expect(find.byKey(ValueKey('stop-move-$jenny')), findsOneWidget);
        expect(find.text('Every pay period · Jenny'), findsOneWidget);
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const ValueKey('stop-pay-confirm')));
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await settle(tester);
        expect(
          find.text(
            'Pay no longer scheduled · 2 categories now Every pay period · Jenny',
          ),
          findsOneWidget,
        );
        var data = (await tester.runAsync(db.loadLedger))!;
        expect(data.paySchedules.map((p) => p.name), ['Jenny']);
        expect(data.plans[groceries]!.payScheduleId, jenny);
        expect(data.plans[housing]!.payScheduleId, jenny);
        expect(data.plans[housing]!.kind, PlanKind.byDate);
        // One ⌘Z: Jeff's pay back, and both categories per it again.
        await chord(tester, LogicalKeyboardKey.keyZ);
        await settle(tester);
        data = (await tester.runAsync(db.loadLedger))!;
        expect(data.paySchedules.map((p) => p.name), ['Jeff', 'Jenny']);
        expect(data.plans[groceries]!.payScheduleId, jeff);
        expect(data.plans[housing]!.payScheduleId, jeff);
        await tidy(tester, db);
      },
    );

    testWidgets('envelopes: put in, spent and left; Tab goes on; ⌘Z; periods', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await openBudget(tester);
      var data = (await tester.runAsync(db.loadLedger))!;
      int id(String name) =>
          data.categories.firstWhere((c) => c.name == name).id;
      final groceries = id('Groceries'), health = id('Health');
      String notAssigned() =>
          tester.widget<Text>(find.byKey(const ValueKey('not-assigned'))).data!;
      final before = notAssigned();
      expect(before, startsWith('₮'));
      expect(find.text('Not assigned'), findsOneWidget);
      expect(find.text('This month · 09.01–09.30'), findsOneWidget);

      // Type Groceries' amount, Tab to the next category, type, Enter.
      await tester.tap(find.byKey(ValueKey('assigned-$groceries')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('assign-field')),
        '900000',
      );
      await tester.runAsync(() async {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('assign-field')),
        '100000+50000',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      data = (await tester.runAsync(db.loadLedger))!;
      expect(
        {for (final b in data.budgetAmounts) b.categoryId: b.amount},
        {groceries: 90000000, health: 15000000},
      );
      // Groceries spent ₮276,650.50 this month.
      expect(find.text('Left'), findsOneWidget);
      final left = tester.widget<Money>(
        find.byKey(ValueKey('left-$groceries')),
      );
      expect(left.minor, 90000000 - 27665050);
      expect(notAssigned(), isNot(before));
      // Quiet: no toast for an amount.
      expect(find.textContaining('Put ₮'), findsNothing);
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/budget_envelopes.png'),
      );

      // Not an amount: the field stays, outlined, and nothing is saved.
      await tester.tap(find.byKey(ValueKey('assigned-$health')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('assign-field')), 'abc');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.byKey(const ValueKey('assign-field')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('assign-field')), findsNothing);

      // ⌘Z takes back Health's.
      await tester.runAsync(() async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      data = (await tester.runAsync(db.loadLedger))!;
      expect(data.budgetAmounts.map((b) => b.categoryId), [groceries]);

      // October: what Groceries didn't spend carries in.
      await tester.tap(find.byKey(const ValueKey('period-next')));
      await tester.pumpAndSettle();
      expect(find.text('October · 10.01–10.31'), findsOneWidget);
      expect(find.byKey(ValueKey('from-before-$groceries')), findsOneWidget);
      expect(
        tester.widget<Money>(find.byKey(ValueKey('left-$groceries'))).minor,
        90000000 - 27665050,
      );
      await tester.tap(find.byKey(const ValueKey('period-today')));
      await tester.pumpAndSettle();
      expect(find.text('This month · 09.01–09.30'), findsOneWidget);

      // Started partway through September, with spending in categories
      // nothing was assigned to: the offer to start in October.
      expect(find.byKey(const ValueKey('start-offer')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('start-later')));
      await settle(tester);
      expect(find.text('October · 10.01–10.31'), findsOneWidget);
      data = (await tester.runAsync(db.loadLedger))!;
      expect(data.budgetAmounts.single.date, DateTime(2026, 10));
      expect(data.prefs[BudgetKeys.began], '2026-10-01');
      expect(find.byKey(const ValueKey('start-offer')), findsNothing);
      // One ⌘Z puts it back in September.
      await tester.runAsync(() async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      data = (await tester.runAsync(db.loadLedger))!;
      expect(data.budgetAmounts.single.date, DateTime(2026, 9));
      expect(data.prefs[BudgetKeys.began], '2026-09-01');

      // Typing, then an arrow: what was typed is saved in the period it
      // was typed in.
      await tester.tap(find.byKey(const ValueKey('period-today')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('assigned-$health')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('assign-field')),
        '70000',
      );
      await tester.tap(find.byKey(const ValueKey('period-next')));
      await settle(tester);
      data = (await tester.runAsync(db.loadLedger))!;
      final h = data.budgetAmounts.firstWhere((b) => b.categoryId == health);
      expect((h.amount, h.date), (7000000, DateTime(2026, 9)));
      await tidy(tester, db);
    });

    testWidgets('plans: the four kinds, Assign, the top button, ⌘Z', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await openBudget(tester);
      var data = (await tester.runAsync(db.loadLedger))!;
      int id(String name) =>
          data.categories.firstWhere((c) => c.name == name).id;
      final groceries = id('Groceries'), gifts = id('Gifts');
      final tuition = id('Tuition'), clothing = id('Clothing');
      Future<void> reload() async =>
          data = (await tester.runAsync(db.loadLedger))!;
      String preview() =>
          tester.widget<Text>(find.byKey(const ValueKey('plan-preview'))).data!;
      Future<void> type(String key, String text) async {
        await tester.enterText(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(EditableText),
            matchRoot: true,
          ),
          text,
        );
        // What was typed can add a line: Edit scrolls until Save shows.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
      }

      // A click that writes to the database: in real time, so each write
      // in a chain gets its turn.
      Future<void> click(String key) async {
        await tester.runAsync(() async {
          await tester.tap(find.byKey(ValueKey(key)));
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await tester.pumpAndSettle();
      }

      Future<void> save() => click('edit-save');

      // A choice that makes Edit taller: it scrolls until Save is in view.
      Future<void> pick(String key) async {
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
      }

      // No plans yet: nothing to assign at the top.
      expect(find.byKey(const ValueKey('assign-planned')), findsNothing);

      // Groceries, spent through the month: Edit in its menu opens it
      // under the row, with no plan to begin with; the line says what a
      // plan comes to; Enter saves.
      await editCategory(tester, 'Groceries');
      expect(
        find.byKey(ValueKey('category-editor-$groceries')),
        findsOneWidget,
      );
      // No due date, and an amount each month.
      await type('plan-amount', '900000');
      expect(preview(), '₮900,000 a month');
      await tester.runAsync(() async {
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('category-editor-$groceries')), findsNothing);
      await reload();
      expect(data.plans[groceries]!.kind, PlanKind.each);
      expect(data.plans[groceries]!.amount, 90000000);
      expect(find.text('₮900,000 a month'), findsOneWidget);

      // Its own Assign fills just that line, quietly.
      await click('plan-assign-$groceries');
      await reload();
      expect(data.budgetAmounts.single.amount, 90000000);
      expect(find.byKey(ValueKey('plan-assign-$groceries')), findsNothing);

      // Tuition, a bill due on a date: 01.15 typed in September is next
      // January's. September to January is five parts.
      await editCategory(tester, 'Tuition');
      await pick('plan-dated-yes');
      await type('plan-amount', '2000000');
      // The date is still missing: Save outlines it and stays.
      await save();
      expect(find.byKey(ValueKey('category-editor-$tuition')), findsOneWidget);
      await type('plan-date', '01.15');
      expect(preview(), '₮2,000,000 by 2027.01.15 · ₮400,000 a month');
      await tester.tap(find.byKey(const ValueKey('plan-repeat')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plan-repeat-12')));
      await tester.pumpAndSettle();
      expect(find.text('Every year'), findsOneWidget);
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/budget_plan_open.png'),
      );
      await save();
      await reload();
      expect(data.plans[tuition]!.due, DateTime(2027, 1, 15));
      expect(data.plans[tuition]!.everyMonths, 12);
      expect(data.plans[tuition]!.start, DateTime(2026, 9, 16));

      // Gifts, a set amount that builds.
      await editCategory(tester, 'Gifts');
      await type('plan-amount', '50000');
      await save();
      expect(find.text('₮50,000 a month'), findsOneWidget);

      // Clothing, an amount by a date, once: September to December is
      // four parts.
      await editCategory(tester, 'Clothing');
      await pick('plan-dated-yes');
      await type('plan-amount', '600000');
      await type('plan-date', '2026.12.31');
      expect(preview(), '₮600,000 by 12.31 · ₮150,000 a month');
      await save();

      // The top button names what it will do, then does it, in one undo.
      expect(
        find.text('Assign what’s planned · ₮600,000 in 3 categories'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('assign-planned-over')), findsNothing);
      // Back to the top of the list: opening Tuition's plan scrolled it.
      await tester.drag(
        find.byKey(ValueKey('category-row-$groceries')),
        const Offset(0, 400),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/budget_plans.png'),
      );
      await click('assign-planned');
      await reload();
      expect(
        {for (final b in data.budgetAmounts) b.categoryId: b.amount},
        {
          groceries: 90000000,
          tuition: 40000000,
          gifts: 5000000,
          clothing: 15000000,
        },
      );
      expect(find.text('Assigned ₮600,000 to 3 categories'), findsOneWidget);
      expect(find.byKey(const ValueKey('assign-planned')), findsNothing);
      expect(find.byKey(ValueKey('plan-state-$tuition')), findsOneWidget);
      expect(find.text(' · on track'), findsNWidgets(2));
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/budget_plans_assigned.png'),
      );
      await chord(tester, LogicalKeyboardKey.keyZ);
      await settle(tester);
      await reload();
      expect(data.budgetAmounts.map((b) => b.categoryId), [groceries]);
      await chord(tester, LogicalKeyboardKey.keyZ, shift: true);
      await settle(tester);
      await reload();
      expect(data.budgetAmounts, hasLength(4));

      // The note opens Edit at the plan; saving No plan says so, and ⌘Z
      // brings it back.
      await tester.tap(find.byKey(ValueKey('plan-note-$gifts')));
      await tester.pumpAndSettle();
      // An empty amount is no plan.
      await type('plan-amount', '');
      await save();
      await reload();
      expect(data.plans[gifts], isNull);
      expect(find.text('Remove the plan for Gifts'), findsOneWidget);
      await chord(tester, LogicalKeyboardKey.keyZ);
      await settle(tester);
      await reload();
      expect(data.plans[gifts]!.kind, PlanKind.each);

      // Groceries no longer carries over; Esc on another leaves it alone.
      await tester.tap(find.byKey(ValueKey('plan-note-$groceries')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plan-carry-off')));
      await tester.pumpAndSettle();
      await save();
      await reload();
      expect(data.plans[groceries]!.rollover, isFalse);
      expect(
        find.text('₮900,000 a month · what’s left doesn’t carry over'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(ValueKey('plan-note-$clothing')));
      await tester.pumpAndSettle();
      await type('plan-amount', '1');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byKey(ValueKey('category-editor-$clothing')), findsNothing);
      await reload();
      expect(data.plans[clothing]!.amount, 60000000);
      await tidy(tester, db);
    });

    testWidgets('Custom…: the second Tuesday of the month, three times', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await openBudget(tester);
      var data = (await tester.runAsync(db.loadLedger))!;
      final clothing = data.categories
          .firstWhere((c) => c.name == 'Clothing')
          .id;
      Future<void> reload() async =>
          data = (await tester.runAsync(db.loadLedger))!;
      Future<void> type(String key, String text) async {
        await tester.enterText(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(EditableText),
            matchRoot: true,
          ),
          text,
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
      }

      Future<void> pick(String key) async {
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
      }

      await editCategory(tester, 'Clothing');
      await pick('plan-dated-yes');
      await type('plan-amount', '300000');
      await type('plan-date', '2026.10.15');
      // Custom… opens the block: every 1 month, on a weekday, ends after
      // 3 times.
      await pick('plan-repeat');
      await pick('plan-repeat-custom');
      expect(find.byKey(const ValueKey('plan-every-n')), findsOneWidget);
      expect(find.text('Day of the month'), findsOneWidget);
      // Picking A weekday starts from the date: 10.15 is the third
      // Thursday.
      await pick('plan-nth-on');
      expect(find.text('third'), findsOneWidget);
      expect(find.text('Thursday'), findsOneWidget);
      await pick('plan-nth');
      await pick('plan-nth-2');
      await pick('plan-nth-weekday');
      await pick('plan-nth-weekday-2');
      await pick('plan-ends-count');
      await type('plan-end-count', '3');
      // The whole panel in the picture, from its heading.
      await tester.ensureVisible(find.byKey(const ValueKey('edit-name')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/budget_plan_custom.png'),
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('edit-save')));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      await reload();
      final plan = data.plans[clothing]!;
      expect((plan.everyMonths, plan.nth, plan.nthWeekday), (1, 2, 2));
      expect(plan.endCount, 3);
      // October's second Tuesday (10.13) is before 10.15: the bills are
      // November's, December's and January's, then no more.
      expect(Budget.dueAfter(plan, 0), DateTime(2026, 11, 10));
      expect(Budget.lastDue(plan), DateTime(2027, 1, 12));
      // Opened again, the block shows what was saved.
      await editCategory(tester, 'Clothing');
      expect(find.text('second'), findsOneWidget);
      expect(find.text('Tuesday'), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-end-count')), findsOneWidget);
      // Every 2 weeks on Monday and Thursday instead.
      await pick('plan-every-unit');
      await pick('plan-every-unit-weeks');
      await type('plan-every-n', '2');
      await pick('plan-weekday-1');
      await pick('plan-weekday-4');
      await pick('plan-ends-never');
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('edit-save')));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      await reload();
      final weekly = data.plans[clothing]!;
      expect(weekly.everyDays, 14);
      expect(weekly.weekdays, [1, 4]);
      expect(weekly.endCount, isNull);
      expect(Budget.dueAfter(weekly, 0), DateTime(2026, 10, 15));
      expect(Budget.dueAfter(weekly, 1), DateTime(2026, 10, 26));
      await tidy(tester, db);
    });

    testWidgets('a plan paid from an account schedules its bill; a cap; ⌘Z', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await openBudget(tester);
      var data = (await tester.runAsync(db.loadLedger))!;
      int id(String name) =>
          data.categories.firstWhere((c) => c.name == name).id;
      final tuition = id('Tuition'), gifts = id('Gifts');
      final checking = data.openAccounts
          .firstWhere((a) => a.name == 'TDB Checking')
          .id;
      Future<void> reload() async =>
          data = (await tester.runAsync(db.loadLedger))!;
      Future<void> type(String key, String text) async {
        await tester.enterText(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(EditableText),
            matchRoot: true,
          ),
          text,
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
      }

      Future<void> pick(String key) async {
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
      }

      Future<void> save() async {
        // The panel can have grown past the window's edge (Custom…).
        await tester.ensureVisible(find.byKey(const ValueKey('edit-save')));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const ValueKey('edit-save')));
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await tester.pumpAndSettle();
      }

      Iterable<TxnData> bills() =>
          data.txns.where((x) => x.planCategoryId == tuition && x.scheduled);

      // Tuition on 01.15, paid from TDB Checking: a scheduled row there,
      // named by its category.
      await editCategory(tester, 'Tuition');
      await pick('plan-dated-yes');
      await type('plan-amount', '2000000');
      await type('plan-date', '01.15');
      // Opened low in the list, the panel's lower rows can sit under the
      // window's edge until it scrolls.
      await tester.ensureVisible(find.byKey(const ValueKey('money-accounts')));
      await tester.pumpAndSettle();
      // One control for the accounts: left checked alone, TDB Checking is
      // where the bill is scheduled.
      expect(
        find.textContaining('accounts, so this bill isn’t in any forecast'),
        findsOneWidget,
      );
      await pick('money-accounts');
      for (final a in data.openAccounts) {
        if (a.id == checking) continue;
        final box = find.byKey(ValueKey('money-account-${a.id}'));
        if (box.evaluate().isEmpty) continue;
        await tester.tap(box);
        await tester.pumpAndSettle();
      }
      await pick('money-accounts');
      expect(find.textContaining('Shows in TDB Checking'), findsOneWidget);
      // Every six months, typed under "Every…" (a gap the presets don't
      // offer).
      await pick('plan-repeat');
      await pick('plan-repeat-custom');
      await type('plan-every-n', '6');
      await pick('plan-every-unit');
      await pick('plan-every-unit-months');
      expect(find.text('Custom'), findsOneWidget);
      await save();
      await reload();
      expect(data.plans[tuition]!.everyMonths, 6);
      final bill = bills().single;
      expect(bill.date, DateTime(2027, 1, 15));
      expect(
        bill.entries.singleWhere((e) => e.accountId == checking).amount,
        -200000000,
      );
      expect(
        data.registerFor(checking).scheduled.map((r) => r.payee),
        contains('Tuition'),
      );
      // ⌘Z takes the plan and its bill away together.
      await chord(tester, LogicalKeyboardKey.keyZ);
      await settle(tester);
      await reload();
      expect(data.plans[tuition], isNull);
      expect(bills(), isEmpty);

      // Gifts, a set amount up to a cap.
      await editCategory(tester, 'Gifts');
      await type('plan-amount', '50000');
      await type('plan-up-to', '200000');
      await save();
      await reload();
      expect(data.plans[gifts]!.upTo, 20000000);
      expect(find.text('₮50,000 a month · up to ₮200,000'), findsOneWidget);
      await tidy(tester, db);
    });

    testWidgets(
      'a category’s currency and accounts: two pools, the checklist',
      (tester) async {
        final db = await pumpLedger(tester);
        // A dollar account with $2,500 in it.
        await tester.runAsync(() async {
          final afcu = await db.createAccount(
            name: 'AFCU Checking',
            type: AccountType.asset,
            currency: Currency.usd,
          );
          await db.postOpeningBalance(
            accountId: afcu,
            date: DateTime(2026, 9, 1),
            balance: 250000,
          );
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await tester.pumpAndSettle();
        await openBudget(tester);
        var data = (await tester.runAsync(db.loadLedger))!;
        Future<void> reload() async =>
            data = (await tester.runAsync(db.loadLedger))!;
        int id(String name) =>
            data.categories.firstWhere((c) => c.name == name).id;
        int account(String name) =>
            data.openAccounts.firstWhere((a) => a.name == name).id;
        Future<void> click(String key) async {
          await tester.runAsync(() async {
            await tester.tap(find.byKey(ValueKey(key)));
            await Future<void>.delayed(const Duration(milliseconds: 300));
          });
          await tester.pumpAndSettle();
        }

        String text(String key) =>
            tester.widget<Text>(find.byKey(ValueKey(key))).data!;

        // Each currency has its own column in the key.
        expect(text('not-assigned'), startsWith('₮'));
        expect(text('not-assigned-USD'), r'$2,500.00');

        // A new category in dollars.
        await tester.tap(find.byKey(const ValueKey('add-category')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('new-category-name')),
          'Car insurance',
        );
        // The currency is picked from a dropdown.
        await tester.tap(find.byKey(const ValueKey('new-category-currency')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('new-category-USD')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('new-category-create')));
        await settle(tester);
        await tester.pump(const Duration(seconds: 7)); // the toast goes
        await tester.pumpAndSettle();
        // The new category opened in Edit; nothing more to set here.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        await reload();
        final insurance = id('Car insurance');
        expect(
          find.byKey(ValueKey('category-editor-$insurance')),
          findsNothing,
        );
        expect(data.accounts[insurance]!.currency, Currency.usd);

        // Assigned in dollars, out of the dollar pool only.
        await tester.tap(find.byKey(ValueKey('assigned-$insurance')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('assign-field')),
          '120',
        );
        await tester.runAsync(() async {
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await tester.pumpAndSettle();
        expect(text('not-assigned-USD'), r'$2,380.00');
        // The tugrik line is its own: no dollars in it.
        expect(text('not-assigned'), startsWith('₮'));

        // Its accounts: the one dollar account, checked. Groceries lists
        // the tugrik ones; unchecking all but Khan Savings says so on the
        // line.
        final groceries = id('Groceries');
        await editCategory(tester, 'Car insurance');
        expect(
          find.byKey(ValueKey('category-editor-$insurance')),
          findsOneWidget,
        );
        // The accounts are a dropdown of checkboxes: it says "All
        // accounts" to begin with, and stays open while they're picked.
        expect(find.text('All accounts'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('money-accounts')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('money-accounts')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('money-account-${account('AFCU Checking')}')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('money-account-${account('TDB Checking')}')),
          findsNothing,
        );
        // Esc closes the dropdown first, then Edit.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('money-account-${account('AFCU Checking')}')),
          findsNothing,
        );
        expect(
          find.byKey(ValueKey('category-editor-$insurance')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('edit-cancel')));
        await tester.pumpAndSettle();
        await editCategory(tester, 'Groceries');
        await tester.ensureVisible(
          find.byKey(const ValueKey('money-accounts')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('money-accounts')));
        await tester.pumpAndSettle();
        // Cards are accounts too: the Visa is in the list.
        for (final name in ['TDB Checking', 'Cash wallet', 'Golomt Visa']) {
          await tester.tap(
            find.byKey(ValueKey('money-account-${account(name)}')),
          );
          await tester.pumpAndSettle();
        }
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/budget_accounts_open.png'),
        );
        // A click on the dropdown's button closes it; it names the one
        // account left.
        await tester.ensureVisible(
          find.byKey(const ValueKey('money-accounts')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('money-accounts')));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('money-accounts')),
            matching: find.text('Khan Savings'),
          ),
          findsOneWidget,
        );
        await click('edit-save');
        await reload();
        expect(data.accountsOff[groceries], {
          account('TDB Checking'),
          account('Cash wallet'),
          account('Golomt Visa'),
        });
        expect(find.text('only from Khan Savings'), findsOneWidget);
        // September's groceries were paid from the others: counted, and
        // named.
        expect(
          find.textContaining('which this category doesn’t use'),
          findsOneWidget,
        );
        await tester.drag(
          find.byKey(ValueKey('category-row-$groceries')),
          const Offset(0, 400),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(LedgerScreen),
          matchesGoldenFile('goldens/budget_currencies.png'),
        );
        // ⌘Z checks them again.
        await chord(tester, LogicalKeyboardKey.keyZ);
        await settle(tester);
        await reload();
        expect(data.accountsOff, isEmpty);

        // Changing Car insurance to tugrik says what it takes back first.
        await editCategory(tester, 'Car insurance');
        // An amount typed in dollars is emptied for the new currency.
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('plan-amount')),
            matching: find.byType(EditableText),
            matchRoot: true,
          ),
          '120',
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('plan-amount')))
              .controller!
              .text,
          '120',
        );
        await tester.tap(find.byKey(const ValueKey('money-currency')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('money-currency-MNT')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('plan-amount')))
              .controller!
              .text,
          isEmpty,
        );
        expect(
          text('money-change'),
          r'Changing the currency takes back $120.00 assigned to it',
        );
        await click('edit-save');
        await reload();
        expect(data.accounts[insurance]!.currency, Currency.mnt);
        expect(data.budgetAmounts, isEmpty);
        // It counts from this period on in its new currency.
        expect(data.prefs['budget.from.$insurance'], '2026-09-01');
        expect(text('not-assigned-USD'), r'$2,500.00');
        await chord(tester, LogicalKeyboardKey.keyZ);
        await settle(tester);
        await reload();
        expect(data.accounts[insurance]!.currency, Currency.usd);
        expect(data.budgetAmounts.single.amount, 12000);
        expect(data.prefs['budget.from.$insurance'], isNull);
        await tidy(tester, db);
      },
    );

    testWidgets('the Budget screen lists categories with how they are used', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await openBudget(tester);
      // Income isn't a category in the list: the Income tab says the
      // period's income.
      expect(find.byKey(const ValueKey('income-line')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('budget-tab-income')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('income-line')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('budget-tab-spending')));
      await tester.pumpAndSettle();
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
      expect(find.text('Coffee added'), findsOneWidget);
      // The new category opens in Edit under its row, so what it's for is
      // asked at once; the add box closes.
      expect(find.byKey(const ValueKey('new-category-name')), findsNothing);
      expect(find.byKey(const ValueKey('edit-name')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-amount')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('edit-name')), findsNothing);
      expect(find.text('Coffee'), findsOneWidget);
      // The same name again adds nothing, and the box stays for another.
      await tester.tap(find.byKey(const ValueKey('add-category')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('new-category-name')),
        'coffee',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.text('Coffee is already a category'), findsOneWidget);
      expect(find.byKey(const ValueKey('new-category-name')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('new-category-cancel')));
      await tester.pumpAndSettle();

      // Its menu, from a right-click or ⋯, is Edit and Delete.
      await tester.tap(find.text('Coffee'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNWidgets(2));
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete…'), findsOneWidget);
      await tester.tapAt(const Offset(700, 20));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);

      // A double-click opens Edit with the name selected: typing renames.
      expect(find.byKey(const ValueKey('edit-name')), findsNothing);
      await tester.tap(find.text('Coffee'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.text('Coffee'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('edit-name')),
        'Coffee & tea',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.byKey(const ValueKey('edit-name')), findsNothing);
      expect(find.text('Coffee & tea'), findsOneWidget);
      expect(find.text('Renamed Coffee to Coffee & tea'), findsOneWidget);
      await tester.pump(const Duration(seconds: 7)); // the toast goes
      await tester.pumpAndSettle();

      // A second double-click on the open row closes Edit. So does Esc,
      // after a click on a choice in it or on the page outside it.
      final coffee = (await tester.runAsync(db.loadLedger))!.categories
          .firstWhere((c) => c.name == 'Coffee & tea')
          .id;
      final row = find.byKey(ValueKey('category-$coffee'));
      final edit = find.byKey(ValueKey('category-editor-$coffee'));
      Future<void> doubleClick() async {
        await tester.tap(row);
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tap(row);
        await tester.pumpAndSettle();
      }

      await doubleClick();
      expect(edit, findsOneWidget);
      await doubleClick();
      expect(edit, findsNothing);
      // Esc straight after opening, with nothing clicked or typed.
      await doubleClick();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(edit, findsNothing);
      await doubleClick();
      await tester.tap(find.byKey(const ValueKey('plan-dated-yes')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(edit, findsNothing);
      await doubleClick();
      await tester.tap(find.byKey(const ValueKey('period-title')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(edit, findsNothing);

      // Archive, in Edit: out of the list, into Archived, and back.
      await editCategory(tester, 'Coffee & tea');
      await tester.tap(find.byKey(const ValueKey('edit-archive')));
      await settle(tester);
      expect(find.text('Coffee & tea'), findsNothing);
      await tester.pump(const Duration(seconds: 7)); // the toast goes
      await tester.ensureVisible(
        find.byKey(const ValueKey('show-archived-categories')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('show-archived-categories')));
      await tester.pumpAndSettle();
      expect(find.text('Coffee & tea'), findsOneWidget);
      // Under the key card the list runs past the window: scrolled to.
      await tester.ensureVisible(find.text('Show in menus'));
      await tester.pumpAndSettle();
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
      await tester.enterText(find.widgetWithText(TextField, '₮0.00'), '6500');
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

    testWidgets('Edit saves several changes at once, and ⌘Z undoes them all', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await openBudget(tester);
      var data = (await tester.runAsync(db.loadLedger))!;
      Future<void> reload() async =>
          data = (await tester.runAsync(db.loadLedger))!;
      final gifts = data.categories.firstWhere((c) => c.name == 'Gifts').id;
      final wallet = data.openAccounts
          .firstWhere((a) => a.name == 'Cash wallet')
          .id;
      await editCategory(tester, 'Gifts');
      await tester.enterText(
        find.byKey(const ValueKey('edit-name')),
        'Presents',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('plan-amount')),
          matching: find.byType(EditableText),
          matchRoot: true,
        ),
        '50000',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('money-accounts')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('money-accounts')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('money-account-$wallet')));
      await tester.pumpAndSettle();
      expect(find.text('3 of 4 accounts'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('money-accounts')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('money-accounts')));
      await tester.pumpAndSettle();
      await tapAndWait(tester, find.byKey(const ValueKey('edit-save')));
      await reload();
      expect(data.accounts[gifts]!.name, 'Presents');
      expect(data.plans[gifts]!.kind, PlanKind.each);
      expect(data.plans[gifts]!.amount, 5000000);
      expect(data.accountsOff[gifts], {wallet});
      expect(find.text('Changes to Presents'), findsOneWidget);

      await chord(tester, LogicalKeyboardKey.keyZ);
      await settle(tester);
      await reload();
      expect(data.accounts[gifts]!.name, 'Gifts');
      expect(data.plans[gifts], isNull);
      expect(data.accountsOff, isEmpty);
      await chord(tester, LogicalKeyboardKey.keyZ, shift: true);
      await settle(tester);
      await reload();
      expect(data.accounts[gifts]!.name, 'Presents');
      expect(data.plans[gifts]!.amount, 5000000);
      expect(data.accountsOff[gifts], {wallet});

      // Spending or income isn't a choice: income is the app's own.
      await editCategory(tester, 'Presents');
      expect(find.byKey(const ValueKey('edit-kind-income')), findsNothing);
      await tidy(tester, db);
    });

    testWidgets('renaming onto another name offers the merge', (tester) async {
      final db = await pumpLedger(tester);
      await openBudget(tester);
      await editCategory(tester, 'Gifts');
      await tester.enterText(
        find.byKey(const ValueKey('edit-name')),
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
      await tester.enterText(find.widgetWithText(TextField, '₮0.00'), '6500');
      await tester.runAsync(() async {
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await settle(tester);
      // Said in the popup at the bottom, where the whole sentence fits, and
      // taken down as soon as the row is edited.
      final popup = find.descendant(
        of: find.byWidgetPredicate((w) => '${w.runtimeType}' == '_Toast'),
        matching: find.text(
          '“Gro” isn’t a category · pick Groceries, or + New category',
        ),
      );
      expect(popup, findsOneWidget);
      expect(find.textContaining('“Gro” isn’t a category'), findsOneWidget);
      // An account's name means the transfer.
      await tester.enterText(category, 'Golomt Visa');
      await tester.pump();
      expect(find.textContaining('“Gro” isn’t a category'), findsNothing);
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
      await tester.enterText(find.widgetWithText(TextField, '₮0.00'), '12000');
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

    testWidgets('a category’s Spent opens its rows, with a total', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await tester.tap(find.text('Budget'));
      await tester.pumpAndSettle();
      final ledger = await tester.runAsync(db.loadLedger);
      final groceries = ledger!.categories.firstWhere(
        (c) => c.name == 'Groceries',
      );
      await tester.tap(find.byKey(ValueKey('spent-${groceries.id}')));
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

      // The usage, at the bottom of Edit (here from ⋯), opens every row,
      // all time.
      await tester.tap(find.text('Budget'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('category-menu-${groceries.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('category-edit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 rows · last'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('edit-rows')));
      await tester.pumpAndSettle();
      expect(find.text('Category: Groceries'), findsOneWidget);
      expect(find.byKey(const ValueKey('period-chip')), findsNothing);
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
            find.widgetWithText(TextField, '₮0.00'),
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
      // The forecast runs through the period that paycheck starts, to the
      // one after it (every 2 weeks: 10.09).
      expect(find.byKey(const ValueKey('add-pay')), findsNothing);
      // Pay but no bills: in words, not a flat chart (owner, 2026-09-30).
      expect(find.text('Forecast'), findsOneWidget);
      expect(find.byKey(const ValueKey('forecast-known')), findsOneWidget);
      expect(find.text('Today’s balance'), findsOneWidget);
      // Both paydays, each with what the plan expects.
      expect(find.text('Expected income'), findsNWidgets(2));
      expect(find.text('+₮2,100,000'), findsNWidgets(2));
      expect(find.text('10.09'), findsOneWidget);
      expect(
        find.text(
          'Nothing has been budgeted. Once you fill out your budget, this '
          'area will show you a forecast.',
        ),
        findsOneWidget,
      );
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/forecast_pay_period.png'),
      );

      // The pay is listed on the Budget page's Income tab, with its next
      // payday; Settings keeps only Budget by.
      await tester.tap(find.text('Budget'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('budget-tab-income')));
      await tester.pumpAndSettle();
      expect(find.text('Income'), findsWidgets);
      expect(
        find.text(
          '₮2,100,000 or more · every 2 weeks · into Cash wallet · next 09.25',
        ),
        findsOneWidget,
      );
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/budget_income_pay.png'),
      );
      await tester.tap(find.byKey(const ValueKey('settings')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-add-pay')), findsNothing);
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

    testWidgets('with bills, the chart names its amounts', (tester) async {
      final db = await pumpLedger(tester);
      await tester.runAsync(() async {
        final data = await db.loadLedger();
        final checking = data.balanceSheetAccounts
            .firstWhere((a) => a.name == 'TDB Checking')
            .id;
        await db.savePaySchedule(
          accountId: checking,
          amount: 250000000,
          rule: PayRule.twiceMonthly,
          day1: 25,
          day2: 10,
          today: DateTime(2026, 9, 16),
        );
      });
      await settle(tester);
      expect(find.textContaining('paycheck'), findsOneWidget);
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/forecast_labeled.png'),
      );
      await tidy(tester, db);
    });

    testWidgets('twice a month: an advance, then the rest', (tester) async {
      final db = await pumpLedger(tester);
      // Pay is set up from the Budget page's Income tab.
      await tester.tap(find.text('Budget'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('budget-tab-income')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('income-add-pay')));
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
      expect(
        find.text('Type how much you’re paid on the 25th'),
        findsOneWidget,
      );
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
        find.textContaining(
          '₮500,000 on the 10th and ₮1,600,000 on the 25th · '
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
            'No regular pay · the app won’t ask for it · the Budget page’s Income tab changes this',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('add-pay')), findsNothing);
        await tester.tap(find.text('Budget'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('budget-tab-income')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('income-no-pay')), findsOneWidget);
        await tapAndWait(tester, find.byKey(const ValueKey('income-ask-pay')));
        expect(find.byKey(const ValueKey('income-no-pay')), findsNothing);
        expect(find.byKey(const ValueKey('income-not-set-up')), findsOneWidget);
        // ⌘Z puts "no regular pay" back.
        await chord(tester, LogicalKeyboardKey.keyZ);
        await settle(tester);
        expect(find.byKey(const ValueKey('income-no-pay')), findsOneWidget);
        // Adding pay anyway: the saying goes with it, and comes back on undo.
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const ValueKey('income-add-pay')));
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

    testWidgets('the Budget screen says the income and what pay is set up', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      await tester.tap(find.text('Budget'));
      await tester.pumpAndSettle();
      // The Income tab carries a gold dot while pay isn't set up; on it,
      // the demo's salary this month, and that pay isn't set up.
      await tester.tap(find.byKey(const ValueKey('budget-tab-income')));
      await tester.pumpAndSettle();
      expect(find.text('Income: ₮2,500,000.00'), findsOneWidget);
      expect(find.text('Pay not set up'), findsOneWidget);
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/budget_income.png'),
      );
      // Add your pay opens the pay setup, which doesn't ask for a category.
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('income-add-pay')));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pay-amount')), findsOneWidget);
      expect(find.byKey(const ValueKey('pay-category')), findsNothing);
      await tidy(tester, db);
    });

    testWidgets('pay that varies, confirmed under the estimate', (
      tester,
    ) async {
      final db = await pumpLedger(tester);
      final ledger = await tester.runAsync(db.loadLedger);
      final checking = ledger!.openAccounts.first.id;
      await tester.runAsync(
        () => db.savePaySchedule(
          accountId: checking,
          amount: 210000000,
          varies: true,
          rule: PayRule.monthly,
          day1: 17,
          today: DateTime(2026, 9, 16),
        ),
      );
      await settle(tester);
      final payday = find.text('Income').first;
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
    tearDown(() => Mid.palette = Palette.of(defaultScheme, Brightness.dark));

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
        'ground': Palette.of(defaultScheme, Brightness.dark).ground.toARGB32(),
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

      // The scheme goes on a second line; a file from before has none.
      await file.writeAsString('dark');
      final c = await AppearanceController.load(file);
      expect(c.value, Appearance.dark);
      expect(c.scheme, defaultScheme);
      await c.setScheme(schemeById('harbor-haze'));
      final again = await AppearanceController.load(file);
      expect(again.value, Appearance.dark);
      expect(again.scheme.id, 'harbor-haze');
      // Changing light or dark keeps the scheme.
      await again.set(Appearance.light);
      final third = await AppearanceController.load(file);
      expect(third.value, Appearance.light);
      expect(third.scheme.id, 'harbor-haze');
      expect(File('${file.path}.part').existsSync(), isFalse);
      await file.writeAsString('light\nno-such-scheme\n');
      expect((await AppearanceController.load(file)).scheme, defaultScheme);
    });

    testWidgets('Settings picks a color scheme; the logo keeps its colors; '
        '⌘Z goes back', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = AppDatabase(NativeDatabase.memory());
      final appearance = AppearanceController(initial: Appearance.dark);
      await tester.runAsync(() async {
        await tester.pumpWidget(
          AppearanceScope(
            controller: appearance,
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
      // Blue eclipse until someone picks, with the dark-mode logo.
      expect(Mid.palette, same(Palette.of(defaultScheme, Brightness.dark)));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('logo')),
          matching: find.byType(Wordmark),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('settings')));
      await tester.pumpAndSettle();
      expect(find.text('Colors'), findsOneWidget);
      // Folded: only the scheme showing, so the cards below stay in view.
      expect(find.text('Monochromatic'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('colors-all')));
      await tester.pumpAndSettle();
      expect(find.text('Hide the colors'), findsOneWidget);
      expect(find.text('Monochromatic'), findsOneWidget);
      expect(find.text('Seasonal'), findsOneWidget);
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/settings_colors.png'),
      );

      final stormy = schemeById('stormy-morning');
      await tester.tap(find.byKey(const ValueKey('scheme-stormy-morning')));
      await tester.pumpAndSettle();
      expect(appearance.scheme, stormy);
      expect(Mid.palette, same(Palette.of(stormy, Brightness.dark)));

      // Light and dark still apply to the scheme.
      await tester.tap(find.byKey(const ValueKey('appearance-light')));
      await tester.pumpAndSettle();
      expect(Mid.palette, same(Palette.of(stormy, Brightness.light)));
      await tester.tap(find.text('Ledger'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/ledger_stormy_light.png'),
      );
      await tester.tap(find.byKey(const ValueKey('settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('appearance-dark')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ledger'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/ledger_stormy_dark.png'),
      );

      Future<void> key({bool shift = false}) => tester.runAsync(() async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      // Back through dark → light → the scheme, to the app's own colors.
      await key();
      await tester.pumpAndSettle();
      await key();
      await tester.pumpAndSettle();
      expect(appearance.scheme, stormy);
      expect(appearance.value, Appearance.dark);
      await key();
      await tester.pumpAndSettle();
      expect(appearance.scheme, defaultScheme);
      expect(Mid.palette, same(Palette.of(defaultScheme, Brightness.dark)));
      await settle(tester);
      expect(find.text('Undone · Colors: Stormy morning'), findsOneWidget);
      await key(shift: true);
      await tester.pumpAndSettle();
      expect(appearance.scheme, stormy);
      await tidy(tester, db);
      debugDefaultTargetPlatformOverride = null;
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
      'transfer to it from tugrik takes both amounts', (tester) async {
    final db = await pumpLedger(tester);
    await tester.tap(find.byKey(const ValueKey('add-account')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('new-account-name')),
      'Chase',
    );
    // Currency is a dropdown of every currency, with a search.
    expect(find.text('₮ Mongolian Tugrik'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('currency')));
    await tester.pumpAndSettle();
    // Tugrik and dollars first, then by name.
    final names = tester
        .widgetList<MenuItemButton>(find.byType(MenuItemButton))
        .map((b) => (b.child! as Text).data!)
        .toList();
    expect(names.take(3), ['Mongolian Tugrik', 'US Dollar', 'Afghan Afghani']);
    final rest = names.sublist(2).map((n) => n.toLowerCase()).toList();
    expect(rest, [...rest]..sort());
    await tester.enterText(
      find.byKey(const ValueKey('currency-search')),
      'dollar',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('currency-CAD')), findsOneWidget);
    expect(find.byKey(const ValueKey('currency-JPY')), findsNothing);
    // Every row ends with its code, whether it has a symbol or not.
    // The Canadian dollar's symbol is the dollar sign, as Canadians
    // write it.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('currency-CAD')),
        matching: find.text(r'$'),
      ),
      findsOneWidget,
    );
    for (final code in ['USD', 'CAD', 'BSD']) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('currency-$code')),
          matching: find.text(code),
        ),
        findsOneWidget,
      );
    }
    expect(find.text('Bahamian Dollar'), findsOneWidget);
    // Every currency has a symbol, drawn: the baht's sign isn't in the
    // app's two text fonts.
    await tester.enterText(find.byKey(const ValueKey('currency-search')), 'a');
    await tester.pumpAndSettle();
    for (final b in tester.widgetList<MenuItemButton>(
      find.byType(MenuItemButton),
    )) {
      expect(((b.leadingIcon! as SizedBox).child! as Text).data, isNotEmpty);
    }
    await tester.enterText(find.byKey(const ValueKey('currency-search')), 'ia');
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/account_currency_signs.png'),
    );
    await tester.enterText(
      find.byKey(const ValueKey('currency-search')),
      'dollar',
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/account_currency_list.png'),
    );
    await tester.tap(find.byKey(const ValueKey('currency-USD')));
    await tester.pumpAndSettle();
    expect(find.text(r'$ US Dollar'), findsOneWidget);
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
    expect(find.text(r'$250.00'), findsWidgets); // sidebar, net worth, the page
    // Net worth: each currency on its own line.
    expect(find.byKey(const ValueKey('net-worth-MNT')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('net-worth-USD'))).data,
      r'$250.00',
    );

    // From TDB Checking, a transfer to Chase asks what arrived there.
    await tester.tap(find.text('TDB Checking').first);
    await tester.pumpAndSettle();
    await openEntry(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Category'),
      '→ Chase',
    );
    await tester.enterText(find.widgetWithText(TextField, '₮0.00'), '3450000');
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
    expect(
      find.text(r'$1,250.00'),
      findsWidgets,
    ); // sidebar, net worth, the page
    expect(
      find.textContaining(r'Chase: $1,000.00 · ₮3,450.00 per $1'),
      findsOneWidget,
    );
    // The row stays open for the next one, with no second amount left over.
    await tester.enterText(
      find.widgetWithText(TextField, 'Category'),
      '→ Chase',
    );
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('exchange-amount')),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      '',
    );
    await tidy(tester, db);
  });

  testWidgets('import: rows before the opening balance move it, by default', (
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
      () => Directory.systemTemp.createTemp('bb-import-open'),
    ))!;
    final file = '${dir.path}/ST_TEST.XLS';
    await tester.runAsync(
      () => File(file).writeAsBytes(
        buildXls({
          (1, 0): DateTime(2026, 9, 10, 9, 5),
          (1, 2): 0.0,
          (1, 3): 20000.0,
          (1, 6): 980000.0,
          (1, 7): 'Кофе',
          (2, 0): DateTime(2026, 9, 12, 13, 30),
          (2, 2): 50000.0,
          (2, 3): 0.0,
          (2, 6): 1030000.0,
          (2, 7): 'Буцаалт',
          (3, 0): DateTime(2026, 9, 13, 18, 0),
          (3, 2): 0.0,
          (3, 3): 7000.0,
          (3, 6): 1023000.0,
          (3, 7): 'Такси',
        }),
      ),
    );
    final db = await pumpLedger(tester);
    final id = (await tester.runAsync(() async {
      final id = await db.createAccount(
        name: 'State Bank',
        type: AccountType.asset,
      );
      await db.postOpeningBalance(
        accountId: id,
        date: DateTime(2026, 9, 16),
        balance: 102300000,
      );
      return id;
    }))!;
    await settle(tester);
    await tester.tap(find.text('State Bank'));
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

    dialogs.openPath = file;
    await run(find.byKey(const ValueKey('import')));
    expect(
      find.textContaining(
        '3 rows are dated before this account’s opening balance',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Move the opening balance to 2026.09.09 at ₮1,000,000.00'),
      findsOneWidget,
    );
    // The bank's balance before its first row agrees: nothing counted twice.
    expect(
      find.textContaining(
        'the cleared balance matches the bank: ₮1,023,000.00',
      ),
      findsOneWidget,
    );
    await expectLater(
      find.byType(Dialog),
      matchesGoldenFile('goldens/import_before_opening.png'),
    );
    await run(find.byKey(const ValueKey('import-do')));
    expect(find.textContaining('opening balance now'), findsOneWidget);
    final data = (await tester.runAsync(db.loadLedger))!;
    expect(data.balanceOf(id), 102300000);
    await tidy(tester, db);
  });

  // Last in the file: the mock version can't be unset, and every test above
  // relies on the line being hidden when there's no bundle to read.
  testWidgets('Settings shows the version and build number', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'BetterBudget',
      packageName: 'com.lovelandsolutions.betterbudget',
      version: '0.1.0',
      buildNumber: '134',
      buildSignature: '',
    );
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: LedgerScreen(db: db, clock: () => DateTime(2026, 9, 30, 10)),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('app-version')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Version 0.1.0 (134)'), findsOneWidget);
    expect(
      find.text(
        'The Budget page was laid out with help from Cynthia G. Loveland.',
      ),
      findsOneWidget,
    );
    await tidy(tester, db);
  });
}
