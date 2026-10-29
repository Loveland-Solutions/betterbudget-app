import 'dart:io';

import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/setup.dart';
import 'package:betterbudget/ui/fit_window.dart';
import 'package:betterbudget/ui/ledger_screen.dart';
import 'package:betterbudget/ui/theme.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Setup (ADR 0004, "Onboarding"): what a new, empty ledger opens on. All
// amounts here are made up.

Future<void> _loadFont(String family, String path) async {
  final bytes = await File(path).readAsBytes();
  await (FontLoader(
    family,
  )..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
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

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
  }

  /// The app as it opens on [db], with no demo data, on 2026.10.07.
  Future<void> open(WidgetTester tester, AppDatabase db) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          debugShowCheckedModeBanner: false,
          theme: appTheme(),
          builder: (context, child) => FitWindow(child: child!),
          home: LedgerScreen(db: db, clock: () => DateTime(2026, 10, 7, 10)),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    await settle(tester);
  }

  Future<void> tidy(WidgetTester tester, AppDatabase db) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
      await db.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  }

  Future<void> add(
    WidgetTester tester,
    String button,
    String name,
    String amount,
  ) async {
    await tester.tap(find.byKey(ValueKey(button)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('setup-name')), name);
    await tester.enterText(find.byKey(const ValueKey('setup-amount')), amount);
    await tester.tap(find.byKey(const ValueKey('setup-add')));
    await settle(tester);
  }

  /// A click whose write and the ledger's answer are both waited for.
  Future<void> press(WidgetTester tester, String key) async {
    // The write runs in real time, or the next read waits behind it.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(ValueKey(key)));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    await settle(tester);
    await settle(tester);
  }

  /// From the Accounts step on to Pay.
  Future<void> toPay(WidgetTester tester) async {
    await press(tester, 'setup-continue');
  }

  Future<void> undo(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
  }

  Future<LedgerData> ledger(WidgetTester tester, AppDatabase db) async =>
      (await tester.runAsync(db.loadLedger))!;

  testWidgets('a new ledger opens on setup, with no demo data', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await open(tester, db);
    expect(find.text('Your accounts'), findsOneWidget);
    expect(find.text('Add the accounts you want to track.'), findsOneWidget);
    expect(find.text('TDB Checking'), findsNothing);
    // Nothing to go to and nothing to add up yet.
    expect(find.text('Budget'), findsNothing);
    expect(find.text('Net worth'), findsNothing);
    expect(find.byKey(const ValueKey('setup-done')), findsNothing);
    final data = await ledger(tester, db);
    expect(data.prefs[SetupKeys.date], '2026-10-07');
    expect(await tester.runAsync(db.startedOwnLedger), isTrue);
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/setup_first_launch.png'),
    );
    await tidy(tester, db);
  });

  testWidgets('accounts are added with what is in them, on the one date', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    await open(tester, db);
    await add(tester, 'setup-add-bank', 'TDB Checking', '4,182,450');
    await add(tester, 'setup-add-cash', 'Wallet', '86,500');
    await tester.tap(find.byKey(const ValueKey('setup-add-owed')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('setup-name')),
      'Golomt Visa',
    );
    await tester.enterText(
      find.byKey(const ValueKey('setup-amount')),
      '640,200',
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/setup_adding.png'),
    );
    await tester.tap(find.byKey(const ValueKey('setup-add')));
    await settle(tester);
    var data = await ledger(tester, db);
    final visa = data.openAccounts.singleWhere((a) => a.name == 'Golomt Visa');
    expect(visa.isOwed, isTrue);
    // Typed as the bank shows it; owed in the ledger.
    expect(data.balanceOf(visa.id), -64020000);
    expect(
      data.openAccounts.singleWhere((a) => a.name == 'Wallet').isCash,
      isTrue,
    );
    expect(data.txns.map((t) => dateKey(t.date)).toSet(), {'2026-10-07'});
    // The sidebar fills, and the foot adds up what the sidebar shows.
    expect(find.text('TDB Checking'), findsNWidgets(2));
    expect(find.text('Net worth'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('setup-held-MNT'))).data,
      '₮4,268,950.00',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('setup-owed-MNT'))).data,
      '₮640,200.00 owed',
    );
    // With a Cash account there, how they pay isn't asked.
    expect(find.text('How do you pay for everyday things?'), findsNothing);
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/setup_accounts.png'),
    );
    // One ⌘Z takes the account and its balance.
    await undo(tester);
    data = await ledger(tester, db);
    expect(data.openAccounts.map((a) => a.name), ['TDB Checking', 'Wallet']);
    expect(data.txns, hasLength(2));
    await tidy(tester, db);
  });

  testWidgets('an amount that cannot be read is said, and nothing is added', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    await open(tester, db);
    await add(tester, 'setup-add-bank', 'Khan', 'lots');
    expect(find.text('“lots” isn’t an amount'), findsOneWidget);
    expect((await ledger(tester, db)).openAccounts, isEmpty);
    // Cancel closes the line with the mouse alone.
    await tester.tap(find.byKey(const ValueKey('setup-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('setup-entry')), findsNothing);
    // Left empty, the account starts at zero, named as the field shows.
    await add(tester, 'setup-add-bank', '', '');
    final data = await ledger(tester, db);
    expect(data.openAccounts.single.name, 'Bank account');
    expect(data.txns, isEmpty);
    await tidy(tester, db);
  });

  testWidgets('changing the date moves every balance, and ⌘Z moves them back', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    await open(tester, db);
    await add(tester, 'setup-add-bank', 'TDB Checking', '1,000,000');
    await add(tester, 'setup-add-bank', 'Khan Savings', '2,000,000');
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('setup-date')),
        matching: find.byType(EditableText),
      ),
      '2026.10.01',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    var data = await ledger(tester, db);
    expect(data.prefs[SetupKeys.date], '2026-10-01');
    expect(data.txns.map((t) => dateKey(t.date)).toSet(), {'2026-10-01'});
    // The next account takes the same day.
    await add(tester, 'setup-add-cash', 'Wallet', '50,000');
    data = await ledger(tester, db);
    expect(data.txns.map((t) => dateKey(t.date)).toSet(), {'2026-10-01'});
    await undo(tester);
    await undo(tester);
    data = await ledger(tester, db);
    expect(data.prefs[SetupKeys.date], '2026-10-07');
    expect(data.txns.map((t) => dateKey(t.date)).toSet(), {'2026-10-07'});
    await tidy(tester, db);
  });

  testWidgets('an account is removed with ×, and Undo brings it back', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    await open(tester, db);
    await add(tester, 'setup-add-bank', 'TDB Checking', '1,000,000');
    final id = (await ledger(tester, db)).openAccounts.single.id;
    await tester.tap(find.byKey(ValueKey('setup-remove-$id')));
    await settle(tester);
    expect((await ledger(tester, db)).openAccounts, isEmpty);
    expect(find.text('TDB Checking deleted'), findsOneWidget);
    await undo(tester);
    final data = await ledger(tester, db);
    expect(data.openAccounts.single.name, 'TDB Checking');
    expect(data.balanceOf(id), 100000000);
    await tidy(tester, db);
  });

  testWidgets('paying with cash and no Cash account is warned about, not '
      'refused', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await open(tester, db);
    await add(tester, 'setup-add-bank', 'TDB Checking', '1,000,000');
    expect(find.byKey(const ValueKey('setup-no-cash')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('setup-everyday-cash')));
    await settle(tester);
    expect(find.byKey(const ValueKey('setup-no-cash')), findsOneWidget);
    // Going on is still there.
    expect(find.byKey(const ValueKey('setup-continue')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('setup-add-cash-now')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('setup-name')), 'Wallet');
    await tester.tap(find.byKey(const ValueKey('setup-add')));
    await settle(tester);
    expect(find.byKey(const ValueKey('setup-no-cash')), findsNothing);
    expect((await ledger(tester, db)).openAccounts.last.isCash, isTrue);
    await tidy(tester, db);
  });

  testWidgets('a line still being typed is kept: another Type keeps its '
      'words, and Continue adds it', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await open(tester, db);
    await add(tester, 'setup-add-bank', 'TDB Checking', '1,000,000');
    await tester.tap(find.byKey(const ValueKey('setup-add-bank')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('setup-name')),
      'Golomt Visa',
    );
    await tester.enterText(
      find.byKey(const ValueKey('setup-amount')),
      '640,200',
    );
    // The wrong button was clicked first; the right one keeps the typing.
    await tester.tap(find.byKey(const ValueKey('setup-add-owed')));
    await tester.pumpAndSettle();
    expect(find.text('Golomt Visa'), findsOneWidget);
    expect(find.text('You owe'), findsOneWidget);
    await toPay(tester);
    final data = await ledger(tester, db);
    final visa = data.openAccounts.singleWhere((a) => a.name == 'Golomt Visa');
    expect(data.balanceOf(visa.id), -64020000);
    expect(find.text('Your regular income'), findsOneWidget);
    await tidy(tester, db);
  });

  testWidgets('Continue stays when the line’s amount can’t be read', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    await open(tester, db);
    await add(tester, 'setup-add-bank', 'TDB Checking', '1,000,000');
    await tester.tap(find.byKey(const ValueKey('setup-add-cash')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('setup-amount')), 'some');
    await toPay(tester);
    expect(find.text('“some” isn’t an amount'), findsOneWidget);
    expect(find.text('Your accounts'), findsOneWidget);
    expect(find.text('Your regular income'), findsNothing);
    await tidy(tester, db);
  });

  testWidgets('setup is where it was left, and never comes back once done', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    await open(tester, db);
    await add(tester, 'setup-add-bank', 'TDB Checking', '1,000,000');
    // Quit and opened again: still setup, with the account in it.
    await open(tester, db);
    expect(find.text('Your accounts'), findsOneWidget);
    expect(find.text('TDB Checking'), findsNWidgets(2));
    await toPay(tester);
    // Quit on the Pay step: that is the step it opens on.
    await open(tester, db);
    expect(find.text('Your regular income'), findsOneWidget);
    expect(find.text('Your accounts'), findsNothing);
    await press(tester, 'pay-none');
    await tester.tap(find.byKey(const ValueKey('setup-done')));
    await settle(tester);
    expect(find.text('Your regular income'), findsNothing);
    expect(find.text('Budget'), findsOneWidget);
    expect((await ledger(tester, db)).prefs[SetupKeys.done], '1');
    await open(tester, db);
    expect(find.text('Your accounts'), findsNothing);
    expect(find.text('Budget'), findsOneWidget);
    await tidy(tester, db);
  });

  testWidgets('Continue goes on to Your pay, the form on the page, and Save '
      'pay lists it', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await open(tester, db);
    // One name alone has nowhere to go: Pay is there, and can't be clicked.
    await press(tester, 'setup-step-pay');
    expect(find.text('Your accounts'), findsOneWidget);
    await add(tester, 'setup-add-bank', 'TDB Checking', '1,000,000');
    await add(tester, 'setup-add-cash', 'Wallet', '80,000');
    await toPay(tester);
    expect(find.text('Your regular income'), findsOneWidget);
    // The page has the heading; the form doesn't say it again.
    expect(find.text('Add your regular income'), findsNothing);
    // The bank, not the wallet, and take-home pay is asked for.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('pay-account')),
        matching: find.text('TDB Checking'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('pay-arrives')), findsOneWidget);
    // Two answers and nothing else: no Cancel, no Open my ledger.
    expect(find.byKey(const ValueKey('pay-none')), findsOneWidget);
    expect(find.byKey(const ValueKey('pay-cancel')), findsNothing);
    expect(find.byKey(const ValueKey('setup-done')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('pay-name')), 'Tom');
    await tester.enterText(
      find.byKey(const ValueKey('pay-amount')),
      '2,100,000',
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/setup_pay.png'),
    );
    await press(tester, 'pay-save');
    var data = await ledger(tester, db);
    expect(data.paySchedules.single.amount, 210000000);
    expect(data.paySchedules.single.accountId, data.openAccounts.first.id);
    // The pay on the page is the confirmation: no popup.
    expect(find.text('Undo'), findsNothing);
    expect(find.byKey(const ValueKey('pay-save')), findsNothing);
    expect(find.byKey(const ValueKey('setup-pays')), findsOneWidget);
    expect(
      find.text(
        '₮2,100,000 · monthly on the 25th · into TDB Checking · '
        'next 10.23',
      ),
      findsOneWidget,
    );
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/setup_pay_saved.png'),
    );
    // ⌘Z takes the pay back, and the form is open again.
    await undo(tester);
    await settle(tester);
    data = await ledger(tester, db);
    expect(data.paySchedules, isEmpty);
    expect(find.byKey(const ValueKey('pay-save')), findsOneWidget);
    await tidy(tester, db);
  });

  testWidgets('a saved pay is edited on the page, another is added, and '
      'Cancel closes the form', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await open(tester, db);
    await add(tester, 'setup-add-bank', 'TDB Checking', '1,000,000');
    await toPay(tester);
    await tester.enterText(find.byKey(const ValueKey('pay-name')), 'Tom');
    await tester.enterText(
      find.byKey(const ValueKey('pay-amount')),
      '2,100,000',
    );
    await press(tester, 'pay-save');
    final id = (await ledger(tester, db)).paySchedules.single.id;
    await press(tester, 'setup-edit-pay-$id');
    // What's typed would be dropped: Open my ledger waits for the form.
    expect(find.byKey(const ValueKey('setup-done')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('pay-name')), 'Tom');
    await tester.enterText(
      find.byKey(const ValueKey('pay-amount')),
      '2,300,000',
    );
    await press(tester, 'pay-save');
    expect((await ledger(tester, db)).paySchedules.single.amount, 230000000);
    // A second earner's pay. Esc closes the form, as Cancel does.
    await press(tester, 'setup-add-other-pay');
    expect(find.byKey(const ValueKey('pay-save')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pay-save')), findsNothing);
    await press(tester, 'setup-add-other-pay');
    expect(find.byKey(const ValueKey('pay-none')), findsNothing);
    await press(tester, 'pay-cancel');
    expect(find.byKey(const ValueKey('pay-save')), findsNothing);
    expect((await ledger(tester, db)).paySchedules, hasLength(1));
    await tester.tap(find.byKey(const ValueKey('setup-done')));
    await settle(tester);
    expect((await ledger(tester, db)).prefs[SetupKeys.done], '1');
    await tidy(tester, db);
  });

  testWidgets('"I don’t have regular pay" is an answer, and can be changed', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    await open(tester, db);
    await add(tester, 'setup-add-bank', 'TDB Checking', '1,000,000');
    await toPay(tester);
    await press(tester, 'pay-none');
    expect((await ledger(tester, db)).prefs['pay.none'], '1');
    expect(find.text('No regular income'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
    expect(find.byKey(const ValueKey('setup-done')), findsOneWidget);
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/setup_pay_none.png'),
    );
    await press(tester, 'setup-add-pay');
    await tester.enterText(find.byKey(const ValueKey('pay-name')), 'Tom');
    await tester.enterText(find.byKey(const ValueKey('pay-amount')), '900,000');
    await press(tester, 'pay-save');
    final data = await ledger(tester, db);
    expect(data.paySchedules, hasLength(1));
    expect(data.prefs['pay.none'], isNull);
    await tidy(tester, db);
  });

  testWidgets('pay with no set day: saved as no regular pay; a pay with no '
      'name says what is missing (#175)', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await open(tester, db);
    await add(tester, 'setup-add-bank', 'TDB Checking', '1,000,000');
    await toPay(tester);
    // Every paycheck has a name: Save waits, and says so.
    await tester.enterText(find.byKey(const ValueKey('pay-amount')), '900,000');
    await tester.pumpAndSettle();
    expect(
      find.text('Give it a name, like Jenny’s job or Child support.'),
      findsOneWidget,
    );
    await press(tester, 'pay-save');
    expect((await ledger(tester, db)).paySchedules, isEmpty);
    // It varies, and comes when it comes.
    await press(tester, 'pay-varies');
    await press(tester, 'pay-no-day');
    expect(find.byKey(const ValueKey('pay-day1')), findsNothing);
    expect(
      find.text(
        'With no set day, the forecast doesn’t expect it. When it comes, '
        'file it under Income.',
      ),
      findsOneWidget,
    );
    await press(tester, 'pay-save');
    final data = await ledger(tester, db);
    expect(data.paySchedules, isEmpty);
    expect(data.prefs['pay.none'], '1');
    expect(find.text('No regular income'), findsOneWidget);
    await tidy(tester, db);
  });

  testWidgets('Back and the step names only move: nothing is taken away', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    await open(tester, db);
    await add(tester, 'setup-add-bank', 'TDB Checking', '1,000,000');
    await toPay(tester);
    await press(tester, 'setup-back');
    expect(find.text('Your accounts'), findsOneWidget);
    expect(find.text('TDB Checking'), findsNWidgets(2));
    expect((await ledger(tester, db)).prefs[SetupKeys.step], 'accounts');
    await press(tester, 'setup-step-pay');
    expect(find.text('Your regular income'), findsOneWidget);
    await press(tester, 'setup-step-accounts');
    expect(find.text('Your accounts'), findsOneWidget);
    // The account undone from the Pay step: back to where one is added.
    await press(tester, 'setup-step-pay');
    // The amount has the keys on arriving, and there ⌘Z acts on typing.
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('pay-amount')))
          .focusNode!
          .hasFocus,
      isTrue,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await undo(tester);
    await settle(tester);
    expect(find.text('Your accounts'), findsOneWidget);
    expect(find.text('TDB Checking'), findsNothing);
    // And adding one doesn't jump on to Pay.
    await add(tester, 'setup-add-bank', 'Khan', '500,000');
    await settle(tester);
    expect(find.text('Your accounts'), findsOneWidget);
    expect((await ledger(tester, db)).prefs[SetupKeys.step], 'accounts');
    await tidy(tester, db);
  });

  testWidgets('a pay whose account was removed is listed with nothing to '
      'click that does nothing', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await open(tester, db);
    await add(tester, 'setup-add-bank', 'TDB Checking', '1,000,000');
    await add(tester, 'setup-add-owed', 'Golomt Visa', '640,200');
    await toPay(tester);
    await tester.enterText(find.byKey(const ValueKey('pay-name')), 'Tom');
    await tester.enterText(
      find.byKey(const ValueKey('pay-amount')),
      '2,100,000',
    );
    await press(tester, 'pay-save');
    await press(tester, 'setup-back');
    final data = await ledger(tester, db);
    final bank = data.openAccounts.firstWhere((a) => !a.isOwed).id;
    await press(tester, 'setup-remove-$bank');
    await press(tester, 'setup-step-pay');
    expect(
      find.byKey(const ValueKey('setup-pay-needs-account')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('setup-pays')), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(find.byKey(const ValueKey('setup-add-other-pay')), findsNothing);
    await tidy(tester, db);
  });

  testWidgets('with only a credit card, Pay says where pay goes and the '
      'ledger still opens', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await open(tester, db);
    await add(tester, 'setup-add-owed', 'Golomt Visa', '640,200');
    await toPay(tester);
    expect(
      find.byKey(const ValueKey('setup-pay-needs-account')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('pay-save')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('setup-done')));
    await settle(tester);
    expect((await ledger(tester, db)).prefs[SetupKeys.done], '1');
    await tidy(tester, db);
  });

  testWidgets('a ledger that had accounts before setup existed never sees it', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      final id = await db.createAccount(
        name: 'TDB MNT',
        type: AccountType.asset,
      );
      await db.postOpeningBalance(
        accountId: id,
        date: DateTime(2026, 9, 1),
        balance: 50000000,
      );
    });
    await open(tester, db);
    expect(find.text('Your accounts'), findsNothing);
    expect(find.text('Budget'), findsOneWidget);
    final data = await ledger(tester, db);
    expect(inSetup(data), isFalse);
    expect(data.prefs[SetupKeys.date], isNull);
    expect(data.balanceOf(data.openAccounts.single.id), 50000000);
    await tidy(tester, db);
  });

  testWidgets('such a ledger with its only account deleted still never sees '
      'setup, and nothing is written to it', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    late int id;
    await tester.runAsync(() async {
      id = await db.createAccount(name: 'TDB MNT', type: AccountType.asset);
      await db.postOpeningBalance(
        accountId: id,
        date: DateTime(2026, 9, 1),
        balance: 50000000,
      );
    });
    await open(tester, db);
    final deleted = (await tester.runAsync(() => db.deleteAccount(id)))!;
    await settle(tester);
    expect(find.text('Your accounts'), findsNothing);
    // The Add account page, as before setup existed.
    expect(find.byKey(const ValueKey('new-account-name')), findsOneWidget);
    var data = await ledger(tester, db);
    expect(inSetup(data), isFalse);
    expect(data.prefs.keys.where((k) => k.startsWith('setup.')), isEmpty);
    expect(await tester.runAsync(db.startedOwnLedger), isFalse);
    await tester.runAsync(() => db.undeleteAccount(deleted));
    await settle(tester);
    data = await ledger(tester, db);
    expect(data.balanceOf(id), 50000000);
    expect(find.text('Budget'), findsOneWidget);
    await tidy(tester, db);
  });

  testWidgets('erasing everything opens setup', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      await db.createAccount(name: 'TDB MNT', type: AccountType.asset);
      await db.startNewLedger(DateTime(2026, 10, 7), keepCategories: false);
    });
    await open(tester, db);
    expect(find.text('Your accounts'), findsOneWidget);
    await tidy(tester, db);
  });

  test(
    'the one date leaves a reconciled opening balance where it is',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final a = await db.createAccount(name: 'A', type: AccountType.asset);
      final b = await db.createAccount(name: 'B', type: AccountType.asset);
      final locked = await db.postOpeningBalance(
        accountId: a,
        date: DateTime(2026, 9, 1),
        balance: 100000,
      );
      final free = await db.postOpeningBalance(
        accountId: b,
        date: DateTime(2026, 9, 1),
        balance: 200000,
      );
      await db.reconcile(
        accountId: a,
        statementDate: DateTime(2026, 9, 30),
        today: DateTime(2026, 10, 7),
        balance: 100000,
      );
      final was = await db.redateOpeningBalances(DateTime(2026, 10, 5));
      expect(was, {free: '2026-09-01'});
      final data = await db.loadLedger();
      final dates = {for (final t in data.txns) t.id: dateKey(t.date)};
      expect(dates[locked], '2026-09-01');
      expect(dates[free], '2026-10-05');
      // Putting dates back refuses a row reconciled since.
      await expectLater(
        db.setTransactionDates({locked: '2026-08-01'}),
        throwsA(isA<LockedException>()),
      );
      await db.close();
    },
  );
}
