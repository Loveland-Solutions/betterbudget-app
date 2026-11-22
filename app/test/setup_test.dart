import 'dart:io';

import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/domain/budget.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/money.dart';
import 'package:betterbudget/domain/pay.dart';
import 'package:betterbudget/domain/readiness.dart';
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
    // With money in the account, Pay goes on to Money you have.
    await press(tester, 'setup-continue');
    expect(find.text('The money in your accounts today'), findsOneWidget);
    // Quit there: that is the step it opens on.
    await open(tester, db);
    expect(find.text('The money in your accounts today'), findsOneWidget);
    await press(tester, 'setup-done');
    expect(find.text('Your regular income'), findsNothing);
    // Setup ends on Budget, with the walkthrough's band (#475).
    expect(find.byKey(const ValueKey('walk-band')), findsOneWidget);
    expect((await ledger(tester, db)).prefs[SetupKeys.done], '1');
    await open(tester, db);
    expect(find.text('Your accounts'), findsNothing);
    expect(find.text('Budget'), findsOneWidget);
    await tidy(tester, db);
  });

  testWidgets('the card names both amounts of split pay, and counts every '
      'payday of pay every few weeks (#323)', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await open(tester, db);
    await add(tester, 'setup-add-bank', 'TDB Checking', '1,000,000');
    await toPay(tester);
    await tester.enterText(find.byKey(const ValueKey('pay-name')), 'Tom');
    await tester.enterText(find.byKey(const ValueKey('pay-amount')), '500000');
    await howOften(tester, 'plan-repeat-twice');
    await tester.enterText(find.byKey(const ValueKey('plan-day1')), '10');
    await tester.enterText(find.byKey(const ValueKey('plan-day2')), '25');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pay-amount-split')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('pay-amount2')),
      '1600000',
    );
    await tester.pumpAndSettle();
    // Not "₮500,000 on every payday": the two days' amounts differ.
    expect(
      find.textContaining('₮500,000 on the 10th and ₮1,600,000 on the 25th'),
      findsOneWidget,
    );
    expect(
      find.text('Counts ₮2,100,000 a month as your income.'),
      findsOneWidget,
    );
    await howOften(tester, 'plan-repeat-d14');
    await tester.enterText(find.byKey(const ValueKey('plan-date')), '10.30');
    await tester.enterText(find.byKey(const ValueKey('pay-amount')), '500000');
    await tester.pumpAndSettle();
    // A month holds two paydays, or three: not "a month".
    expect(
      find.text('Counts ₮500,000 for each payday that falls in the month.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('pay-none')));
    await tester.pumpAndSettle();
    await tidy(tester, db);
  });

  testWidgets('Enter on a tip reads it and does not save the form, and one '
      'tip shows at a time (#325)', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await open(tester, db);
    await add(tester, 'setup-add-bank', 'TDB Checking', '1,000,000');
    await toPay(tester);
    await tester.enterText(find.byKey(const ValueKey('pay-name')), 'Tom');
    await tester.enterText(find.byKey(const ValueKey('pay-amount')), '900,000');
    await tester.pumpAndSettle();
    // Tab back from the amount to the ⓘ beside its label: the tip opens.
    await tester.tap(find.byKey(const ValueKey('pay-amount')));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.textContaining('Type what arrives in the account'), findsOne);
    // Enter reads it again; it is not Save, so nothing was saved.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pay-save')), findsOneWidget);
    expect((await ledger(tester, db)).paySchedules, isEmpty);
    // The next ⓘ back replaces the tip rather than stacking on it.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Type what arrives in the account'),
      findsNothing,
    );
    await tidy(tester, db);
  });

  testWidgets('an income on a repeat a category has saves, and its line says '
      'how often (#438)', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await open(tester, db);
    await add(tester, 'setup-add-bank', 'TDB Checking', '1,000,000');
    await toPay(tester);
    await tester.enterText(find.byKey(const ValueKey('pay-name')), 'Pension');
    await tester.enterText(find.byKey(const ValueKey('pay-amount')), '300,000');
    await howOften(tester, 'plan-repeat-3');
    await tester.enterText(find.byKey(const ValueKey('plan-date')), '11.20');
    await tester.pumpAndSettle();
    await press(tester, 'pay-save');
    expect(find.textContaining('every 3 months'), findsOneWidget);
    final pay = (await ledger(tester, db)).paySchedules.single;
    expect(pay.rule, PayRule.custom);
    expect(pay.repeat?.everyMonths, 3);
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
    // A line under the amount says which figure: what is deposited.
    expect(find.byKey(const ValueKey('pay-deposited')), findsOneWidget);
    // An ⓘ beside the amount says it's what arrives, after tax; a click
    // opens it (the mouse alone is enough).
    expect(find.byKey(const ValueKey('pay-tip-amount')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pay-tip-amount')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Type what arrives in the account after tax, in that account’s '
        'currency. If the bank converts it, type the converted amount it '
        'credits.',
      ),
      findsOneWidget,
    );
    // Nothing to say about it until there is an amount.
    expect(find.byKey(const ValueKey('pay-card')), findsNothing);
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
    // The card says what the forecast and the budget do with it, in these
    // figures (#323).
    expect(find.byKey(const ValueKey('pay-card')), findsOneWidget);
    expect(find.textContaining('coming in on'), findsOneWidget);
    expect(
      find.text('Counts ₮2,100,000 a month as your income.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('pay-varies')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Shows at least ₮2,100,000 coming in'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('pay-same')));
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
    // With pay, setup asks month or paycheck, month to begin with (#474).
    expect(find.text('Do you budget by month or by paycheck?'), findsOneWidget);
    expect((await ledger(tester, db)).periodSchedule, isNull);
    await tester.ensureVisible(find.byKey(ValueKey('budget-by-$id')));
    await tester.pumpAndSettle();
    await press(tester, 'budget-by-$id');
    expect((await ledger(tester, db)).periodSchedule?.id, id);
    await press(tester, 'budget-by-month');
    expect((await ledger(tester, db)).periodSchedule, isNull);
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
    await press(tester, 'setup-continue');
    await press(tester, 'setup-done');
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
    expect(find.byKey(const ValueKey('setup-continue')), findsOneWidget);
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
    expect(find.text('Type a name.'), findsOneWidget);
    await press(tester, 'pay-save');
    expect((await ledger(tester, db)).paySchedules, isEmpty);
    // It varies, and comes when it comes.
    await press(tester, 'pay-varies');
    await howOften(tester, 'pay-no-day');
    expect(find.byKey(const ValueKey('plan-date')), findsNothing);
    expect(
      find.text(
        'With no set day, the forecast doesn’t expect it. When it comes, '
        'mark it as Income.',
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

  // Money you have (#475): the budget counts income from the day it began,
  // so what the accounts already hold is used only as Had before the
  // budget, which setup now asks.
  int notAssigned(LedgerData data) {
    final p = budgetPeriod(DateTime(2026, 10, 7), data.periodSchedule);
    return Budget.of(
      data,
      start: p.start,
      end: p.end,
      today: DateTime(2026, 10, 7),
    ).pools.first.notAssigned;
  }

  testWidgets('Money you have: all of it to begin with, money for '
      'emergencies to the Safety net, in one undo (#475)', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await open(tester, db);
    await add(tester, 'setup-add-bank', 'TDB Checking', '1,500,000');
    await add(tester, 'setup-add-bank', 'Khan Savings', '2,000,000');
    await add(tester, 'setup-add-cash', 'Wallet', '100,000');
    await add(tester, 'setup-add-owed', 'Golomt Visa', '300,000');
    expect(find.text('Money you have'), findsOneWidget);
    await toPay(tester);
    await press(tester, 'pay-none');
    await press(tester, 'setup-continue');
    expect(find.text('The money in your accounts today'), findsOneWidget);
    // What a credit card owes isn't taken off: its payment is a category.
    expect(find.text('All of it: ₮3,600,000'), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-owed-note')), findsOneWidget);
    expect(
      find.text(
        'Your budget will use this ₮3,600,000 as well. You can change it '
        'later in Settings, under Had before the budget.',
      ),
      findsOneWidget,
    );
    // No amount filled in for them: nothing goes to the Safety net yet.
    expect(find.text('Finish setup'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('setup-emergency')),
      '2,000,000',
    );
    await tester.pumpAndSettle();
    // A click that moves money says where it goes.
    expect(
      find.text('Assign ₮2,000,000 to Safety net and finish setup'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('setup-emergency-more')), findsNothing);
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/setup_money.png'),
    );
    await press(tester, 'setup-done');
    var data = await ledger(tester, db);
    expect(data.prefs[SetupKeys.done], '1');
    expect(data.prefs[BudgetKeys.hadBefore(Currency.mnt)], '360000000');
    expect(data.prefs[BudgetKeys.began], '2026-10-01');
    // Setup said where the budget starts: no offer to start it later.
    expect(data.prefs[BudgetKeys.keptStart], '1');
    expect(data.prefs[WalkKeys.started], '2026-10-07');
    final net = data.accounts.values.singleWhere(
      (a) => !a.deleted && isSafetyNet(a),
    );
    expect(
      data.budgetAmounts
          .where((b) => b.categoryId == net.id)
          .fold(0, (s, b) => s + b.amount),
      200000000,
    );
    expect(notAssigned(data), 160000000);
    // One undo puts it all back, and setup opens where it was.
    await undo(tester);
    await settle(tester);
    data = await ledger(tester, db);
    expect(data.prefs[SetupKeys.done], isNull);
    expect(data.prefs[BudgetKeys.hadBefore(Currency.mnt)], isNull);
    expect(data.prefs[BudgetKeys.began], isNull);
    expect(data.prefs[BudgetKeys.keptStart], isNull);
    expect(data.prefs[WalkKeys.started], isNull);
    expect(data.budgetAmounts, isEmpty);
    expect(find.text('The money in your accounts today'), findsOneWidget);
    await tidy(tester, db);
  });

  testWidgets('Money you have: part of it, none of it, and more for '
      'emergencies than the budget uses is said, not refused (#475)', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    await open(tester, db);
    await add(tester, 'setup-add-bank', 'TDB Checking', '1,000,000');
    await toPay(tester);
    await press(tester, 'pay-none');
    await press(tester, 'setup-continue');
    await press(tester, 'setup-had-part-MNT');
    await tester.enterText(
      find.byKey(const ValueKey('setup-had-amount-MNT')),
      '400,000',
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Your budget will use this ₮400,000 as well.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('setup-had-amount-MNT')),
      '1,200,000',
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('That’s ₮200,000 more than your accounts hold'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('setup-had-amount-MNT')),
      '400,000',
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('setup-emergency')),
      '500,000',
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'That’s more than your budget will use, so it would start '
        '₮100,000 short.',
      ),
      findsOneWidget,
    );
    // None of it: the question about emergencies goes, and its amount
    // with it.
    await press(tester, 'setup-had-none-MNT');
    expect(
      find.text(
        'Your budget will use only the income that comes in from today on.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('setup-emergency')), findsNothing);
    expect(find.text('Finish setup'), findsOneWidget);
    // Part again keeps what was typed.
    await press(tester, 'setup-had-part-MNT');
    expect(find.text('400,000'), findsOneWidget);
    await press(tester, 'setup-done');
    final data = await ledger(tester, db);
    expect(data.prefs[BudgetKeys.hadBefore(Currency.mnt)], '40000000');
    // Warned, then let go ahead: the budget starts ₮100,000 short.
    expect(notAssigned(data), -10000000);
    await tidy(tester, db);
  });

  testWidgets('with nothing in the accounts, Money you have isn’t asked '
      '(#475)', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await open(tester, db);
    await tester.tap(find.byKey(const ValueKey('setup-add-bank')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('setup-name')),
      'TDB Checking',
    );
    await tester.tap(find.byKey(const ValueKey('setup-add')));
    await settle(tester);
    expect(find.text('Money you have'), findsNothing);
    await toPay(tester);
    await press(tester, 'pay-none');
    expect(find.byKey(const ValueKey('setup-continue')), findsNothing);
    await press(tester, 'setup-done');
    final data = await ledger(tester, db);
    expect(data.prefs[SetupKeys.done], '1');
    expect(data.prefs[BudgetKeys.hadBefore(Currency.mnt)], isNull);
    await tidy(tester, db);
  });

  // The walkthrough (#475): after setup, Budget names the next step in a
  // band where the Savings band goes, one at a time.
  Future<void> addCategory(
    WidgetTester tester,
    String name,
    String amount, {
    String? date,
    required int paidFrom,
  }) async {
    await tester.enterText(find.byKey(const ValueKey('edit-name')), name);
    await tester.enterText(find.byKey(const ValueKey('plan-amount')), amount);
    if (date != null) {
      await tester.enterText(find.byKey(const ValueKey('plan-date')), date);
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('money-accounts')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('money-account-$paidFrom')).last);
    await tester.pumpAndSettle();
    await press(tester, 'new-category-add');
  }

  testWidgets('after setup, Budget walks through bills, a credit card’s '
      'bill, day-to-day and Assign, then gives way to Savings (#475)', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    await open(tester, db);
    await add(tester, 'setup-add-bank', 'TDB Checking', '1,000,000');
    await add(tester, 'setup-add-owed', 'Golomt Visa', '300,000');
    await add(tester, 'setup-add-owed', 'Car loan', '5,000,000');
    await toPay(tester);
    await press(tester, 'pay-none');
    await press(tester, 'setup-continue');
    await press(tester, 'setup-done');
    // Setup opens on Budget, the band on its first step.
    expect(find.byKey(const ValueKey('walk-band')), findsOneWidget);
    expect(find.byKey(const ValueKey('step-band')), findsNothing);
    expect(
      find.text(
        'Start with the bills you pay on a set date, such as Rent, СӨХ or '
        'a Storepay instalment.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Credit card and loan payments come next.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('walk-step-debts')), findsOneWidget);
    await expectLater(
      find.byType(LedgerScreen),
      matchesGoldenFile('goldens/walk_bills.png'),
    );
    var data = await ledger(tester, db);
    final tdb = data.openAccounts.singleWhere((a) => a.name == 'TDB Checking');
    final visa = data.openAccounts.singleWhere((a) => a.name == 'Golomt Visa');
    // Add a bill opens New category on its Bill card.
    await press(tester, 'walk-add-bill');
    expect(find.byKey(const ValueKey('plan-date')), findsOneWidget);
    await addCategory(
      tester,
      'Rent',
      '800,000',
      date: '10.30',
      paidFrom: tdb.id,
    );
    expect(
      find.text('You have 1 bill. Add each one you pay on a set date.'),
      findsOneWidget,
    );
    expect(find.text('That’s all my bills'), findsOneWidget);
    await press(tester, 'walk-pass');
    // The credit card's bill: made, and the card's payments come out of
    // it, in one undo.
    expect(
      find.text(
        'Golomt Visa owes ₮300,000. Add the bill that pays it, so your '
        'budget plans for the payment.',
      ),
      findsOneWidget,
    );
    await press(tester, 'walk-add-debt-bill');
    expect(find.byKey(const ValueKey('new-category-another')), findsNothing);
    await addCategory(
      tester,
      'Visa payment',
      '300,000',
      date: '10.25',
      paidFrom: tdb.id,
    );
    data = await ledger(tester, db);
    final pays = data.categories.singleWhere((c) => c.name == 'Visa payment');
    expect(Budget.loanCategory(data, visa.id), pays.id);
    // The popup's Undo takes back both, the bill and the tie to the card.
    await tester.runAsync(() async {
      await tester.tap(find.text('Undo'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    data = await ledger(tester, db);
    expect(Budget.loanCategory(data, visa.id), isNull);
    expect(data.categories.where((c) => c.name == 'Visa payment'), isEmpty);
    expect(find.byKey(const ValueKey('walk-add-debt-bill')), findsOneWidget);
    // Not now passes the card only: the loan is asked next. ⌘Z brings the
    // card back.
    await press(tester, 'walk-pass');
    expect(find.textContaining('Car loan owes ₮5,000,000.'), findsOneWidget);
    await undo(tester);
    expect(find.textContaining('Golomt Visa owes'), findsOneWidget);
    await press(tester, 'walk-pass');
    await press(tester, 'walk-pass');
    expect(
      find.text('Then everyday spending, such as groceries and bus fare.'),
      findsOneWidget,
    );
    await press(tester, 'walk-add-day');
    expect(find.byKey(const ValueKey('plan-date')), findsNothing);
    await addCategory(tester, 'Groceries', '400,000', paidFrom: tdb.id);
    await press(tester, 'walk-pass');
    // Assign points to the button above rather than being a second one.
    expect(
      find.text(
        'Now give each category its money: Assign what’s planned, above, '
        'gives each one its plan’s amount.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('assign-planned')));
    await settle(tester);
    await settle(tester);
    // Every plan has its money: the walk is done, and Savings takes the
    // spot.
    expect(find.byKey(const ValueKey('walk-band')), findsNothing);
    expect(find.byKey(const ValueKey('step-band')), findsOneWidget);
    await tidy(tester, db);
  });

  testWidgets('a ledger set up before the walkthrough is never walked '
      '(#475)', (tester) async {
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
    await tester.tap(find.text('Budget'));
    await settle(tester);
    expect(find.byKey(const ValueKey('walk-band')), findsNothing);
    await tidy(tester, db);
  });
}

/// Picks one of How often's choices on the income form.
Future<void> howOften(WidgetTester tester, String item) async {
  await tester.tap(find.byKey(const ValueKey('plan-repeat')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(item)));
  await tester.pumpAndSettle();
}
