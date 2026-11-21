import 'dart:convert';
import 'dart:typed_data';

import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/import_figures.dart';
import 'package:betterbudget/data/phone_sync.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/phone.dart';
import 'package:betterbudget/import/mapping.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// A bank file imported on the phone (#531), through `actOnImport`, the code
// the phone's ledger runs: the rows, the bills they pay, the columns kept
// for next time, and one undo for all of it.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final today = DateTime(2026, 10, 7);
  Future<PhoneSnapshot> again() async =>
      snapshotOf(await db.loadLedger(), today: today, madeAt: today);

  /// A bank's CSV with its own column names, a line each.
  Uint8List file(List<String> lines) => Uint8List.fromList(
    utf8.encode(
      '${['Огноо;Орлого;Зарлага;Харьцсан данс;Үлдэгдэл;Гүйлгээний утга', ...lines].join('\n')}\n',
    ),
  );

  /// What the page hands over for [bytes] read into [account].
  Future<PhoneImport> importOf(int account, Uint8List bytes) async {
    final opened = openBankFile(bytes, 'statement.csv', null);
    final read = readRows(opened.sheet, opened.mapping);
    final plan = await db.planImport(
      account,
      read.rows,
      importKeys(account, read.rows),
    );
    return PhoneImport(
      account,
      plan: plan.rows,
      uncategorized: 'Not categorized',
      mapping: SavedMapping(
        shape: fileShape(opened.sheet, opened.mapping),
        kind: opened.kind,
        mapping: opened.mapping,
        proven: read.check?.ok ?? true,
      ).encode(),
    );
  }

  test('the rows come in cleared, a typed row the file has is cleared, and '
      'the columns are kept; Undo takes all of it back and Redo brings it '
      'back', () async {
    final bank = await db.addAccount(
      name: 'Statement',
      type: AccountType.asset,
    );
    final food = await db.createCategory('Food');
    await db.postTransaction(
      date: DateTime(2026, 10, 3),
      payee: 'Unitel',
      lines: [
        (accountId: bank, amount: -800000, cleared: Cleared.uncleared),
        (accountId: food, amount: 800000, cleared: Cleared.uncleared),
      ],
    );
    final act = await importOf(
      bank,
      file([
        '2026.10.01;100 000,00;0,00;Ажил олгогч;100 000,00;Цалин',
        '2026.10.02;0,00;30 000,00;Номин;70 000,00;Худалдан авалт',
        '2026.10.03;0,00;8 000,00;Юнител;62 000,00;Төлбөр',
      ]),
    );
    final done = await actOnImport(db, act, today, again);
    expect(act.done!.record.added, hasLength(2));
    expect(act.done!.record.matched, hasLength(1));
    var data = await db.loadLedger();
    var rows = data.registerFor(bank).posted;
    expect(rows, hasLength(3));
    expect(rows.every((r) => r.cleared == Cleared.cleared), isTrue);
    expect(data.summaryFor(bank).cleared, 6200000);
    // The typed row keeps its payee and its category.
    final typed = rows.firstWhere((r) => r.amount == -800000);
    expect(typed.payee, 'Unitel');
    expect(typed.categoryId, food);
    expect(
      SavedMapping.decode(data.prefs[AppDatabase.importMappingKey(bank)])
          ?.mapping
          .hasDate,
      isTrue,
    );

    await done.undo();
    data = await db.loadLedger();
    rows = data.registerFor(bank).posted;
    expect(rows, hasLength(1));
    expect(rows.single.cleared, Cleared.uncleared);

    await done.redo();
    data = await db.loadLedger();
    rows = data.registerFor(bank).posted;
    expect(rows, hasLength(3));
    expect(rows.every((r) => r.cleared == Cleared.cleared), isTrue);
  });

  test('a row the file brings into a bill\'s category pays the bill, and the '
      'import\'s Undo brings the bill back with the rows gone', () async {
    final bank = await db.addAccount(
      name: 'Statement',
      type: AccountType.asset,
    );
    final phone = await db.createCategory('Phone');
    await db.setCategoryPlan(
      phone,
      CategoryPlan(
        categoryId: phone,
        kind: PlanKind.byDate,
        amount: 3000000,
        start: DateTime(2026, 10, 1),
        due: DateTime(2026, 10, 2),
        everyMonths: 1,
        paidFrom: bank,
      ),
    );
    await db.ensurePlanBills(DateTime(2026, 10, 1), only: phone);
    // The payee's category is remembered, so its bank row is filed there.
    await db.rememberPayee(
      accountId: bank,
      payee: 'Мобиком',
      categoryId: phone,
    );

    List<DateTime> billsDue(LedgerData d) => [
      for (final r in d.registerFor(bank).scheduled)
        if (r.planCategoryId == phone) r.date,
    ];
    var data = await db.loadLedger();
    expect(billsDue(data), contains(DateTime(2026, 10, 2)));

    final act = await importOf(
      bank,
      // Near the bill's amount, not exactly it: the row comes in and pays
      // the bill (exactly the amount, the bill itself is paid: #597).
      file(['2026.10.02;0,00;29 000,00;Мобиком;-29 000,00;Төлбөр']),
    );
    final done = await actOnImport(db, act, today, again);
    expect(act.done!.billsPaid, 1);
    expect(act.done!.billsToCheck, 0);
    data = await db.loadLedger();
    final paid = data.registerFor(bank).posted.single;
    expect(paid.categoryId, phone);
    // October's bill is paid, so it no longer waits.
    expect(billsDue(data), isNot(contains(DateTime(2026, 10, 2))));

    await done.undo();
    data = await db.loadLedger();
    expect(data.registerFor(bank).posted, isEmpty);
    expect(billsDue(data), contains(DateTime(2026, 10, 2)));

    await done.redo();
    data = await db.loadLedger();
    expect(data.registerFor(bank).posted, hasLength(1));
    expect(billsDue(data), isNot(contains(DateTime(2026, 10, 2))));
  });
}
