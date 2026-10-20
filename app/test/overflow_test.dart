import 'dart:io';

import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/pay.dart';
import 'package:betterbudget/ui/fit_window.dart';
import 'package:betterbudget/ui/language.dart';
import 'package:betterbudget/domain/phone.dart' show snapshotOf;
import 'package:betterbudget/ui/ledger_screen.dart';
import 'package:betterbudget/ui/phone/phone_app.dart';
import 'package:betterbudget/ui/theme.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kDoubleTapMinTime;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The yellow-and-black stripe Flutter draws where something is wider than its
// space must never show (owner, 2026-10-14: "We need to constrain things so
// the user doesn't see that."). Every page is laid out here with balances
// past a billion tugrik, with cents, and names far longer than anyone types,
// in English and in Mongolian, and any overflow fails the test.

Future<void> _loadFont(String family, String path) async {
  final bytes = await File(path).readAsBytes();
  await (FontLoader(
    family,
  )..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
}

const _longName = ' for the household, the children and the school fees';
const _longMn = ' гэр бүл, хүүхдүүд болон сургалтын төлбөрт зориулсан';

/// Amounts a thousand times the demo's and then some, so they carry cents:
/// a whole number of tugrik u becomes 1,000.37 × u, which keeps every
/// transaction balanced.
String _bigger(String column) =>
    "$column = CASE WHEN $column % 100 = 0 "
    "THEN $column / 100 * 100037 ELSE $column * 1000 END";

/// What the demo leaves out: pay, amounts assigned, a plan on every
/// category, remembered payees.
Future<void> _fillIn(AppDatabase db, DateTime today) async {
  final data = await db.loadLedger();
  final checking = data.openAccounts.firstWhere(
    (a) => a.name == 'TDB Checking',
  );
  await db.savePaySchedule(
    accountId: checking.id,
    amount: 250000000,
    rule: PayRule.monthly,
    day1: 25,
    today: today,
    name: 'Salary from the ministry',
    payee: 'Ministry of Education',
  );
  final month = DateTime(today.year, today.month);
  final monthEnd = DateTime(today.year, today.month + 1, 0);
  var i = 0;
  for (final c in data.accounts.values.where(
    (a) => a.type == AccountType.expense && !a.deleted,
  )) {
    i++;
    await db.setBudgetAmount(c.id, month, monthEnd, 50000000 + i * 1000000);
    await db.setCategoryPlan(
      c.id,
      CategoryPlan(
        categoryId: c.id,
        kind: i.isEven ? PlanKind.each : PlanKind.byDate,
        amount: 40000000,
        start: today,
        due: i.isEven ? null : today.add(Duration(days: i)),
        everyMonths: 1,
      ),
    );
    if (i <= 4) {
      await db.addPayeeRule(
        name: 'Payee number $i with a long name',
        anywhere: i.isEven,
        categoryId: c.id,
        accountIds: {checking.id},
      );
    }
  }
}

Future<void> _stretch(AppDatabase db, {required bool mongolian}) async {
  final more = mongolian ? _longMn : _longName;
  for (final sql in [
    "UPDATE accounts SET name = name || '$more' "
        "WHERE type IN ('asset', 'liability', 'expense')",
    "UPDATE payees SET name = name || '$more'",
    "UPDATE payee_rules SET name = name || '$more'",
    "UPDATE transactions SET memo = 'A memo that goes on and on$more'",
    "UPDATE entries SET ${_bigger('amount_minor')}",
    "UPDATE reconciliations SET ${_bigger('statement_balance_minor')}",
    "UPDATE budget_amounts SET ${_bigger('amount_minor')}",
    "UPDATE category_plans SET ${_bigger('amount_minor')}",
    "UPDATE pay_schedules SET ${_bigger('amount_minor')}",
  ]) {
    await db.customStatement(sql);
  }
  final off = await db
      .customSelect(
        'SELECT transaction_id FROM entries GROUP BY transaction_id '
        'HAVING SUM(amount_minor) != 0',
      )
      .get();
  expect(off, isEmpty, reason: 'every transaction still balances');
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

  for (final mongolian in [false, true]) {
    for (final size in [FitWindow.smallest, const Size(1920, 1080)]) {
      final words = mongolian ? 'Mongolian' : 'English';
      testWidgets('nothing overflows: $words, ${size.width.toInt()} × '
          '${size.height.toInt()}, huge amounts and long names', (
        tester,
      ) async {
        final overflows = <String>[];
        var page = 'the first page';
        final cut = <String>{};
        addTearDown(_catchOverflows(overflows, () => page));

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final db = AppDatabase(NativeDatabase.memory());
        final today = DateTime(2026, 9, 16, 10);
        final language = LanguageController(
          initial: mongolian ? Language.mongolian : Language.english,
        );
        await tester.runAsync(() async {
          await seedDemoIfEmpty(db, today);
          await _fillIn(db, today);
          await _stretch(db, mongolian: mongolian);
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
                  builder: (context, child) => FitWindow(child: child!),
                  home: LedgerScreen(demo: true, db: db, clock: () => today),
                ),
              ),
            ),
          );
        });
        // Until the ledger has loaded, however long that takes.
        for (
          var i = 0;
          i < 100 &&
              find.byKey(const ValueKey('add-transaction')).evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        final t = lookupWords(Locale(mongolian ? 'mn' : 'en'));

        Future<void> tap(Finder f) async {
          expect(f, findsWidgets, reason: 'on $page');
          await tester.ensureVisible(f.first);
          await tester.pumpAndSettle();
          await tester.tap(f.first);
          await tester.pumpAndSettle();
          cut.addAll(_cutText(tester).map((w) => '$w, on $page'));
        }

        Future<void> escape() async {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
        }

        // Each account's page, the entry row and reconcile on it.
        final accounts = (await tester.runAsync(db.loadLedger))!.openAccounts
            .map((a) => a.name)
            .toList();
        for (final name in accounts) {
          page = name;
          await tap(find.text(name));
          await tap(find.byKey(const ValueKey('add-transaction')));
          await escape();
          // Cash has no Reconcile.
          if (find.text(t.planReconcile).evaluate().isNotEmpty) {
            await tap(find.text(t.planReconcile));
            await escape();
          }
        }
        await tap(find.text(t.ledgerSectionLedger));

        page = 'Add account';
        await tap(find.byKey(const ValueKey('add-account')));
        await escape();

        // Budget, both tabs, pay's Edit, a new category and a category's
        // Edit.
        page = 'Budget';
        await tap(find.text(t.ledgerSectionBudget));
        await tap(find.byKey(const ValueKey('budget-tab-income')));
        page = 'Pay';
        await tap(_keyed('edit-pay-'));
        await escape();
        page = 'Budget';
        await tap(find.byKey(const ValueKey('budget-tab-spending')));
        page = 'Add category';
        await tap(find.byKey(const ValueKey('add-category')));
        await escape();
        page = "a category's Edit";
        final groceries = find.textContaining('Groceries');
        await tester.tap(groceries.first);
        await tester.pump(kDoubleTapMinTime);
        await tap(groceries);
        await escape();

        page = 'Savings';
        await tap(find.text(t.ledgerSectionSavings));
        page = 'Payees';
        await tap(find.text(t.ledgerSectionPayees));
        page = "a payee's Edit";
        await tap(find.textContaining('Payee number 1'));
        await escape();
        page = 'Add a payee';
        await tap(find.byKey(const ValueKey('payee-add')));
        await escape();
        page = 'Settings';
        await tap(find.byKey(const ValueKey('settings')));

        await tester.runAsync(() async {
          await tester.pumpWidget(const SizedBox());
          await db.close();
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        expect(overflows.toSet().toList(), isEmpty);
        expect(cut.toList(), isEmpty, reason: 'text cut off without "…"');
      });
    }
  }

  testWidgets('Shrink: smaller in a narrow box, on the same baseline', (
    tester,
  ) async {
    debugCheckIntrinsicSizes = true;
    Widget line(double width) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: width,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('a', style: TextStyle(fontSize: 20)),
              Expanded(
                child: Shrink(
                  end: true,
                  Text('1234567890', style: onest(20), maxLines: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // With the intrinsic checks on, Flutter fails the test where the
    // baseline measured ahead of layout differs from the one drawn.
    await tester.pumpWidget(line(400));
    final shrink = tester.renderObject<RenderShrink>(find.byType(Shrink));
    expect(shrink.scale, 1);
    final fullBottom = tester.getBottomLeft(find.text('a')).dy;
    await tester.pumpWidget(line(60));
    expect(shrink.scale, lessThan(1));
    // The row's baseline, and so the line beside it, stays where it was.
    expect(tester.getBottomLeft(find.text('a')).dy, fullBottom);
    // Drawn against the end of its box.
    final right = tester.getBottomRight(find.text('1234567890'));
    expect(right.dx, closeTo(tester.getBottomRight(find.byType(Shrink)).dx, 1));
    debugCheckIntrinsicSizes = false;
  });

  // The phone: the same ledger, on an ordinary phone and a small one.
  for (final mongolian in [false, true]) {
    for (final size in [const Size(390, 844), const Size(320, 640)]) {
      final words = mongolian ? 'Mongolian' : 'English';
      testWidgets('nothing overflows on the phone: $words, '
          '${size.width.toInt()} × ${size.height.toInt()}', (tester) async {
        final overflows = <String>[];
        final cut = <String>{};
        var page = 'Ledger';
        addTearDown(_catchOverflows(overflows, () => page));
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final today = DateTime(2026, 9, 16, 10);
        final db = AppDatabase(NativeDatabase.memory());
        final data = (await tester.runAsync(() async {
          await seedDemoIfEmpty(db, today);
          await _fillIn(db, today);
          await _stretch(db, mongolian: mongolian);
          final data = await db.loadLedger();
          await db.close();
          return data;
        }))!;
        final store = PhoneStore(snapshotOf(data, today: today, madeAt: today));
        await tester.pumpWidget(
          LanguageScope(
            controller: LanguageController(
              initial: mongolian ? Language.mongolian : Language.english,
            ),
            child: PhoneApp(store: store, now: () => today),
          ),
        );
        await tester.pumpAndSettle();

        void look() => cut.addAll(_cutText(tester).map((w) => '$w, on $page'));

        Future<void> tap(Finder f) async {
          expect(f, findsWidgets, reason: 'on $page');
          await tester.ensureVisible(f.first);
          await tester.pumpAndSettle();
          await tester.tap(f.first);
          await tester.pumpAndSettle();
          look();
        }

        look();
        // The biggest amount the pad takes, in a category with a long name.
        for (final k in '999999999999'.split('')) {
          final key = find.byKey(ValueKey('pad-$k'));
          if (key.evaluate().isEmpty) break;
          await tester.tap(key);
        }
        await tester.pumpAndSettle();
        look();
        page = 'the Category list';
        await tap(find.byKey(const ValueKey('category-row')));
        page = 'Ledger, a category picked';
        await tap(_keyed('menu-'));
        page = 'the Paid from list';
        await tap(find.byKey(const ValueKey('account-row')));
        page = 'Ledger, an account picked';
        await tester.tap(find.textContaining('TDB Checking').last);
        await tester.pumpAndSettle();
        look();
        page = 'Budget';
        await tap(find.byKey(const ValueKey('to-budget')));
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -2000),
        );
        await tester.pumpAndSettle();
        look();

        expect(overflows.toSet().toList(), isEmpty);
        expect(cut.toList(), isEmpty, reason: 'text cut off without "…"');
      });
    }
  }
}

/// Collects each overflow Flutter reports, with where it was drawn and on
/// [page]; any other error goes on as before. The function returned stops it.
VoidCallback _catchOverflows(List<String> into, String Function() page) {
  final before = FlutterError.onError;
  FlutterError.onError = (details) {
    final said = details.exceptionAsString();
    if (said.contains('overflowed')) {
      into.add('${said.split('\n').first} at ${_where(details)}, on ${page()}');
    } else {
      before?.call(details);
    }
  };
  return () => FlutterError.onError = before;
}

/// Whatever has a key starting with [prefix].
Finder _keyed(String prefix) => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith(prefix),
);

/// Text drawn cut off: a line wider than its box that doesn't end in "…",
/// more lines than the box is tall, an amount on two lines, an amount cut
/// off with "…", or one shrunk below 60% to fit.
List<String> _cutText(WidgetTester tester) {
  final cut = <String>[];
  void visit(RenderObject o) {
    if (o is RenderShrink && o.scale < 0.6) {
      cut.add('${o.child} drawn at ${(o.scale * 100).round()}%');
    }
    if (o is RenderParagraph && o.hasSize && o.size.width > 0) {
      final text = o.text.toPlainText();
      final ends =
          o.overflow == TextOverflow.ellipsis ||
          o.overflow == TextOverflow.fade;
      final oneLine = o.maxLines == 1 || !o.softWrap;
      final wide = o.getMaxIntrinsicWidth(double.infinity) > o.size.width + 1;
      final tall = o.getMinIntrinsicHeight(o.size.width) > o.size.height + 1;
      // An amount or a date on two lines.
      final number = RegExp(r'^\S*\d\S*( [A-Z]{3}| owed| өр)?$')
          .hasMatch(text.trim());
      // An amount cut off with "…". Not in a row's memo: a split's shares
      // there are whole once the row opens.
      final memo = o.debugCreator.toString().contains("'row-memo'");
      final amountCut =
          !memo &&
          ends &&
          ((oneLine && wide) || o.didExceedMaxLines) &&
          RegExp(r'\d\.\d\d\b|\d,\d{3}').hasMatch(text);
      if (text.trim().isNotEmpty &&
          ((!ends && ((oneLine && wide) || tall)) ||
              (number && wide) ||
              amountCut)) {
        cut.add('"${text.length > 60 ? '${text.substring(0, 60)}…' : text}"');
      }
    }
    o.visitChildren(visit);
  }

  for (final view in tester.binding.renderViews) {
    view.visitChildren(visit);
  }
  return cut;
}

/// The widget that overflowed, from the report's lines.
String _where(FlutterErrorDetails details) {
  final info = details.toString();
  final at =
      RegExp(r'lib/(\S+\.dart:\d+)').firstMatch(info) ??
      RegExp(r'(Render\w+#\w+)').firstMatch(info);
  return at?.group(1) ?? details.library ?? '';
}
