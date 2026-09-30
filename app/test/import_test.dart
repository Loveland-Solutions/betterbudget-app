// Import: reading bank files, guessing their columns, and writing the rows
// (ADR 0002). All data here is made up.
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/import/csv.dart';
import 'package:betterbudget/import/mapping.dart';
import 'package:betterbudget/import/sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'xls_fixture.dart';

/// A plain TDB-style export: a metadata row, then date, teller, in, out,
/// rate, counterparty, balance, description; a totals footer.
Map<(int, int), Object> tdbLike() {
  final cells = <(int, int), Object>{
    (0, 0): 'Харилцагч: Туршилт',
    (0, 1): 'Данс: 1234567890 MNT',
    (0, 2): 'Хугацаа: 2026.09.01-2026.09.05',
  };
  var balance = 100000.0;
  final rows = [
    (
      DateTime(2026, 9, 1, 9, 15),
      0.0,
      12500.0,
      '5000123456 Номин',
      'POS 12345678: НОМИН',
    ),
    (DateTime(2026, 9, 1, 9, 15), 0.0, 250.0, ' ', 'CHARGE: 250.00'),
    (
      DateTime(2026, 9, 2, 14, 2),
      850000.0,
      0.0,
      '5000999888 Ажил ХХК',
      'Цалин 9-р сар',
    ),
    (DateTime(2026, 9, 4, 18, 40), 0.0, 4200.5, ' ', 'QPay кофе'),
  ];
  for (final (i, (date, credit, debit, who, what)) in rows.indexed) {
    final r = i + 1;
    balance += credit - debit;
    cells[(r, 0)] = date;
    cells[(r, 1)] = '100 - 10';
    cells[(r, 2)] = credit;
    cells[(r, 3)] = debit;
    cells[(r, 4)] = 1.0;
    if (who.trim().isNotEmpty) cells[(r, 5)] = who;
    cells[(r, 6)] = balance;
    cells[(r, 7)] = what;
  }
  cells[(5, 0)] = 'Нийт:';
  cells[(5, 2)] = 850000.0;
  cells[(5, 3)] = 16950.5;
  return cells;
}

void main() {
  group('xls reader', () {
    test('reads text, numbers, dates, RK numbers and split shared strings', () {
      final bytes = buildXls(tdbLike(), rk: true, splitSst: true);
      final sheet = readSheet(bytes, 'statement.xls');
      expect(sheet.rows.length, 6);
      expect(sheet.cell(1, 0), DateTime(2026, 9, 1, 9, 15));
      expect(sheet.cell(1, 3), 12500.0);
      expect(sheet.cell(4, 3), 4200.5);
      expect(sheet.cell(1, 5), '5000123456 Номин');
      expect(sheet.cell(3, 7), 'Цалин 9-р сар');
      expect(sheet.cell(0, 0), 'Харилцагч: Туршилт');
    });

    test('a cut-short or looping file says so instead of hanging', () {
      final good = buildXls(tdbLike());
      expect(
        () => readSheet(Uint8List.sublistView(good, 0, 700), 'x.xls'),
        throwsA(isA<UnreadableFileException>()),
      );
      // The FAT's first entry pointing at itself: a chain that loops.
      final looped = Uint8List.fromList(good);
      looped.buffer.asByteData().setUint32(512 + 8, 2, Endian.little);
      expect(
        () => readSheet(looped, 'x.xls'),
        throwsA(isA<UnreadableFileException>()),
      );
    });

    test('a file that is not an xls says so', () {
      expect(
        () => readSheet(Uint8List.fromList([0, 1, 2, 3, 0]), 'x.xls'),
        throwsA(isA<UnreadableFileException>()),
      );
    });
  });

  group('csv reader', () {
    test('quotes, semicolons and a byte-order mark', () {
      final s = readCsv(
        Uint8List.fromList([
          0xEF, 0xBB, 0xBF, //
          ...utf8Bytes(
            'Огноо;Утга;Дүн\n2026.09.01;"Номин; дэлгүүр";-12 500,00\n',
          ),
        ]),
      );
      expect(s.rows[1], ['2026.09.01', 'Номин; дэлгүүр', '-12 500,00']);
    });

    test('Windows-1251 Cyrillic', () {
      // "Дүн" can't be written in 1251; "Сумма" can.
      final s = readCsv(
        Uint8List.fromList([0xD1, 0xF3, 0xEC, 0xEC, 0xE0, 0x2C, 0x31]),
      );
      expect(s.rows.first, ['Сумма', '1']);
    });

    test('UTF-16 with a byte-order mark', () {
      final units = 'a,b\n1,2'.codeUnits;
      final s = readCsv(
        Uint8List.fromList([
          0xFF,
          0xFE,
          for (final u in units) ...[u, 0],
        ]),
      );
      expect(s.rows, [
        ['a', 'b'],
        ['1', '2'],
      ]);
    });
  });

  test('xlsx reader: shared strings, numbers and a dated cell', () {
    final a = Archive()
      ..addFile(
        _f(
          'xl/workbook.xml',
          '<workbook><sheets><sheet name="S" sheetId="1" r:id="rId1" xmlns:r="r"/></sheets></workbook>',
        ),
      )
      ..addFile(
        _f(
          'xl/_rels/workbook.xml.rels',
          '<Relationships><Relationship Id="rId1" Target="worksheets/sheet1.xml"/></Relationships>',
        ),
      )
      ..addFile(_f('xl/sharedStrings.xml', '<sst><si><t>Кофе</t></si></sst>'))
      ..addFile(
        _f(
          'xl/styles.xml',
          '<styleSheet><cellXfs><xf numFmtId="0"/><xf numFmtId="14"/></cellXfs></styleSheet>',
        ),
      )
      ..addFile(
        _f(
          'xl/worksheets/sheet1.xml',
          '<worksheet><sheetData><row r="1"><c r="A1" s="1"><v>46266</v></c>'
              '<c r="B1" t="s"><v>0</v></c><c r="C1"><v>-4200.5</v></c></row></sheetData></worksheet>',
        ),
      );
    final bytes = Uint8List.fromList(ZipEncoder().encode(a)!);
    final s = readSheet(bytes, 'x.xlsx');
    expect(s.rows.first, [DateTime(2026, 9, 1), 'Кофе', -4200.5]);
  });

  group('amounts and dates', () {
    test('amount text in either style', () {
      expect(readAmount('1,234.56'), 123456);
      expect(readAmount('1 234,56'), 123456);
      expect(readAmount('1.234.567'), 123456700);
      expect(readAmount('-12,5'), -1250);
      expect(readAmount('(300.00)'), -30000);
      expect(readAmount('₮4,200'), 420000);
      expect(readAmount('4,200'), 420000);
      expect(readAmount('500-'), -50000);
      expect(readAmount('1.500'), 150000); // dots as thousands, like commas
      expect(readAmount('15.000'), 1500000);
      expect(readAmount('1.2345'), null); // fractions of a mönggö
      expect(readAmount('12.50000'), 1250);
      expect(readAmount('12345678901234567890'), null); // a reference number
      expect(readAmount(double.nan), null);
      expect(readAmount(double.infinity), null);
      expect(readAmount('abc'), null);
      expect(readAmount(4200.5), 420050);
    });

    test('text dates, with and without time', () {
      expect(
        parseDateText('2026.9.1 2:49:04PM', DateOrder.ymd),
        DateTime(2026, 9, 1, 14, 49, 4),
      );
      expect(parseDateText('03/04/2026', DateOrder.mdy), DateTime(2026, 3, 4));
      expect(parseDateText('03/04/2026', DateOrder.dmy), DateTime(2026, 4, 3));
      expect(parseDateText('31.04.2026', DateOrder.dmy), null);
      expect(fittingOrders(['03/04/2026', '13/04/2026']), {DateOrder.dmy});
    });
  });

  group('guessing the columns', () {
    test('TDB-style: in, out and balance proved by the running balance', () {
      final sheet = readSheet(buildXls(tdbLike()), 's.xls');
      final m = guessMapping(sheet);
      expect(m.roles, {
        0: ColumnRole.date,
        2: ColumnRole.moneyIn,
        3: ColumnRole.moneyOut,
        5: ColumnRole.payee,
        6: ColumnRole.balance,
        7: ColumnRole.memo,
      });
      expect(m.headerRow, isNull); // the metadata row has figures in it
      final read = readRows(sheet, m);
      expect(read.rows.map((r) => r.amount), [
        -1250000,
        -25000,
        85000000,
        -420050,
      ]);
      expect(read.rows.first.payee, 'Номин'); // account number dropped
      expect(read.rows.first.memo, 'POS 12345678: НОМИН');
      expect(read.rows[1].payee, 'CHARGE: 250.00'); // no counterparty
      expect(read.rows[1].memo, isNull);
      expect(read.skipped.map((s) => s.sourceRow), [0, 5]);
      expect(read.check!.ok, isTrue);
      expect(read.check!.opening, 10000000);
    });

    test('a header row names the columns; newest first is turned around', () {
      final csv = utf8Bytes(
        'Date,Description,Amount,Balance\n'
        '09/05/2026,Coffee,-4.50,95.50\n'
        '09/03/2026,Refund,10.00,100.00\n'
        '09/01/2026,Groceries,-20.00,90.00\n',
      );
      final sheet = readSheet(csv, 'bank.csv');
      final m = guessMapping(sheet);
      expect(m.headerRow, 0);
      expect(m.roleOf(0), ColumnRole.date);
      expect(m.roleOf(2), ColumnRole.amount);
      expect(m.roleOf(3), ColumnRole.balance);
      expect(m.roleOf(1), ColumnRole.payee);
      final read = readRows(sheet, m);
      expect(read.newestFirst, isTrue);
      expect(read.rows.map((r) => r.payee), ['Groceries', 'Refund', 'Coffee']);
      expect(read.check!.ok, isTrue);
    });

    test('a balance that does not add up is reported, not refused', () {
      final csv = utf8Bytes(
        'Date,Payee,Amount,Balance\n'
        '2026-09-01,A,-10.00,90.00\n'
        '2026-09-02,B,-10.00,75.00\n'
        '2026-09-03,C,-5.00,70.00\n',
      );
      final sheet = readSheet(csv, 'b.csv');
      final read = readRows(sheet, guessMapping(sheet));
      expect(read.rows.length, 3);
      expect(read.check!.ok, isFalse);
      expect(read.check!.mismatches, 1);
      expect(read.check!.firstMismatchRow, 2);
      expect(read.check!.expected, 8000);
      expect(read.check!.found, 7500);
    });

    test('a card file showing what is owed as positive still adds up', () {
      final csv = utf8Bytes(
        'Date,Payee,Amount,Balance\n'
        '2026-09-01,Shop,-100.00,600.00\n'
        '2026-09-02,Payment,300.00,300.00\n',
      );
      final sheet = readSheet(csv, 'card.csv');
      final m = const ImportMapping(
        roles: {
          0: ColumnRole.date,
          1: ColumnRole.payee,
          2: ColumnRole.amount,
          3: ColumnRole.balance,
        },
        headerRow: 0,
      );
      final read = readRows(sheet, m);
      expect(read.check!.ok, isTrue);
      expect(read.rows.map((r) => r.balance), [-60000, -30000]);
    });

    test('a print-layout header sits beside its figures', () {
      final cells = <(int, int), Object>{
        (0, 1): 'Огноо',
        (0, 3): 'Орлого',
        (0, 6): 'Зарлага',
        (0, 9): 'Харьцсан данс',
        (0, 13): 'Үлдэгдэл',
        (0, 15): 'Гүйлгээний утга',
      };
      var bal = 1000.0;
      for (var i = 0; i < 3; i++) {
        final r = 2 + i * 2; // blank spacer rows between
        bal -= 100;
        cells[(r, 0)] = DateTime(2026, 9, 1 + i);
        cells[(r, 2)] = 0.0;
        cells[(r, 5)] = 100.0;
        cells[(r, 8)] = '5000111222';
        cells[(r, 10)] = 'Нэр $i';
        cells[(r, 12)] = bal;
        cells[(r, 14)] = 'Утга $i';
      }
      final sheet = readSheet(buildXls(cells), 'f.xls');
      final m = guessMapping(sheet);
      expect(m.headerRow, 0);
      expect(m.roleOf(2), ColumnRole.moneyIn);
      expect(m.roleOf(5), ColumnRole.moneyOut);
      expect(m.roleOf(10), ColumnRole.payee);
      expect(m.roleOf(12), ColumnRole.balance);
      expect(m.roleOf(14), ColumnRole.memo);
      final read = readRows(sheet, m);
      expect(read.rows.map((r) => r.payee), ['Нэр 0', 'Нэр 1', 'Нэр 2']);
      expect(read.check!.ok, isTrue);
    });

    test('one role per column; amount and in/out exclude each other', () {
      var m = const ImportMapping(roles: {0: ColumnRole.date});
      m = m.withRole(1, ColumnRole.moneyIn).withRole(2, ColumnRole.moneyOut);
      m = m.withRole(3, ColumnRole.amount);
      expect(m.roles, {0: ColumnRole.date, 3: ColumnRole.amount});
      m = m.withRole(3, ColumnRole.date);
      expect(m.roles, {3: ColumnRole.date});
    });
  });

  group('saved mapping and keys', () {
    test('a file of the same shape fits; another does not', () {
      final sheet = readSheet(buildXls(tdbLike()), 's.xls');
      final m = guessMapping(sheet);
      final saved = SavedMapping.decode(
        SavedMapping(
          shape: fileShape(sheet, m),
          kind: FileKind.xls,
          mapping: m,
        ).encode(),
      )!;
      expect(saved.mapping, m);
      expect(mappingFits(sheet, saved), isTrue);
      final other = readSheet(
        utf8Bytes('Date,Amount\n2026-09-01,5\n'),
        'o.csv',
      );
      expect(mappingFits(other, saved), isFalse);
    });

    test('keys are stable and rows alike in one file get #2', () {
      final rows = [
        for (var i = 0; i < 2; i++)
          ImportRow(
            sourceRow: i,
            date: DateTime(2026, 9, 1),
            amount: -500,
            payee: 'Кофе',
          ),
      ];
      expect(importKeys(7, rows), [
        'a7|2026-09-01|-500|Кофе|',
        'a7|2026-09-01|-500|Кофе|#2',
      ]);
    });
  });

  group('writing an import', () {
    late AppDatabase db;
    late int bank;
    late int groceries;
    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      bank = await db.createAccount(name: 'Checking', type: AccountType.asset);
      groceries = await db.createCategory('Groceries');
    });
    tearDown(() => db.close());

    ImportRow row(int day, int amount, String payee, {int? balance}) =>
        ImportRow(
          sourceRow: day,
          date: DateTime(2026, 9, day),
          amount: amount,
          payee: payee,
          balance: balance,
        );

    Future<List<ImportPlanRow>> plan(List<ImportRow> rows, {int? into}) async =>
        (await db.planImport(
          into ?? bank,
          rows,
          importKeys(into ?? bank, rows),
        )).rows;

    test('new rows come in cleared; a typed row matches; a second import '
        'skips what the first brought', () async {
      // Typed by hand on the 2nd, the bank posts it on the 3rd.
      final typed = await db.postSimple(
        accountId: bank,
        date: DateTime(2026, 9, 2),
        today: DateTime(2026, 9, 30),
        payee: 'Nomin',
        counterAccountId: groceries,
        amount: -1250000,
      );
      // An earlier row for this payee sets the category new ones get.
      await db.postSimple(
        accountId: bank,
        date: DateTime(2026, 8, 20),
        today: DateTime(2026, 9, 30),
        payee: 'Emart',
        counterAccountId: groceries,
        amount: -300000,
      );
      final rows = [
        row(3, -1250000, 'НОМИН POS'),
        row(4, -500000, 'Emart'),
        row(5, -25000, 'Fee'),
      ];
      final p = await plan(rows);
      expect(p.map((x) => x.fate), [
        ImportFate.match,
        ImportFate.add,
        ImportFate.add,
      ]);
      expect(p.first.match!.transactionId, typed);

      final record = await db.applyImport(
        accountId: bank,
        plan: p,
        uncategorizedNames: ['Not categorized'],
      );
      expect(record.added.length, 2);
      expect(record.madeCategory, isNotNull);
      expect(record.uncategorizedCount, 1);

      var data = await db.loadLedger();
      final bankRows = data.txns
          .where((t) => t.entries.any((e) => e.accountId == bank))
          .toList();
      expect(bankRows.length, 4);
      final emart = bankRows.firstWhere(
        (t) => t.payee == 'Emart' && t.date.day == 4,
      );
      expect(
        emart.entries.firstWhere((e) => e.accountId != bank).accountId,
        groceries,
      );
      final fee = bankRows.firstWhere((t) => t.payee == 'Fee');
      expect(
        data
            .accounts[fee.entries
                .firstWhere((e) => e.accountId != bank)
                .accountId]!
            .name,
        'Not categorized',
      );
      final typedRow = bankRows.firstWhere((t) => t.id == typed);
      expect(
        typedRow.entries.firstWhere((e) => e.accountId == bank).cleared,
        Cleared.cleared,
      );
      expect(typedRow.payee, 'Nomin'); // the user's words stay
      expect(typedRow.memo, 'НОМИН POS'); // and the bank's, as the memo

      // The same file again: everything is already in.
      final again = await plan(rows);
      expect(again.every((x) => x.fate == ImportFate.already), isTrue);

      // Undo takes it all back, so the file can come in again.
      await db.undoImport(record);
      data = await db.loadLedger();
      expect(
        data.txns
            .where((t) => t.entries.any((e) => e.accountId == bank))
            .length,
        2,
      );
      expect(
        data.txns
            .firstWhere((t) => t.id == typed)
            .entries
            .firstWhere((e) => e.accountId == bank)
            .cleared,
        Cleared.uncleared,
      );
      expect(data.accounts[record.madeCategory]!.deleted, isTrue);
      expect((await plan(rows)).map((x) => x.fate), [
        ImportFate.match,
        ImportFate.add,
        ImportFate.add,
      ]);

      // Redo brings it back as it was.
      await db.redoImport(record, bank);
      expect(
        (await plan(rows)).every((x) => x.fate == ImportFate.already),
        isTrue,
      );
      data = await db.loadLedger();
      expect(data.accounts[record.madeCategory]!.deleted, isFalse);
    });

    test('each side of a transfer matches its own bank file', () async {
      final savings = await db.createAccount(
        name: 'Savings',
        type: AccountType.asset,
      );
      await db.postSimple(
        accountId: bank,
        date: DateTime(2026, 9, 10),
        today: DateTime(2026, 9, 30),
        payee: 'To savings',
        counterAccountId: savings,
        amount: -50000000,
      );
      final out = [row(10, -50000000, 'Өөрийн нэр')];
      final pOut = await plan(out);
      expect(pOut.single.fate, ImportFate.match);
      await db.applyImport(
        accountId: bank,
        plan: pOut,
        uncategorizedNames: ['Not categorized'],
      );
      final inn = [row(10, 50000000, 'Өөрийн нэр')];
      final pIn = await plan(inn, into: savings);
      expect(pIn.single.fate, ImportFate.match);
      final r = await db.applyImport(
        accountId: savings,
        plan: pIn,
        uncategorizedNames: ['Not categorized'],
      );
      expect(r.added, isEmpty);
      expect((await plan(out)).single.fate, ImportFate.already);
      expect((await plan(inn, into: savings)).single.fate, ImportFate.already);
    });

    test('payee memory never sends a row to another account', () async {
      final card = await db.createAccount(
        name: 'Card',
        type: AccountType.liability,
      );
      // The owner's own name last went to the card, as a transfer.
      await db.postSimple(
        accountId: bank,
        date: DateTime(2026, 8, 1),
        today: DateTime(2026, 9, 30),
        payee: 'Own name',
        counterAccountId: card,
        amount: -100000,
      );
      final rows = [row(20, -700000, 'Own name')];
      final r = await db.applyImport(
        accountId: bank,
        plan: await plan(rows),
        uncategorizedNames: ['Not categorized'],
      );
      expect(r.uncategorizedCount, 1);
      final data = await db.loadLedger();
      final t = data.txns.firstWhere((t) => t.id == r.added.keys.single);
      expect(
        data
            .accounts[t.entries
                .firstWhere((e) => e.accountId != bank)
                .accountId]!
            .name,
        'Not categorized',
      );
    });

    test('an opening balance is never matched to a bank row', () async {
      await db.postOpeningBalance(
        accountId: bank,
        date: DateTime(2026, 9, 1),
        balance: 250000,
      );
      final p = await plan([row(2, 250000, 'Deposit')]);
      expect(p.single.fate, ImportFate.add);
    });

    test(
      'left-out rows and matches turned into rows are written as chosen',
      () async {
        await db.postSimple(
          accountId: bank,
          date: DateTime(2026, 9, 2),
          today: DateTime(2026, 9, 30),
          payee: 'Taxi',
          counterAccountId: groceries,
          amount: -1000000,
        );
        final rows = [row(3, -1000000, 'QPay'), row(4, -2000, 'Fee')];
        final p = await plan(rows);
        expect(p.first.fate, ImportFate.match);
        final r = await db.applyImport(
          accountId: bank,
          plan: [
            p[0].withFate(ImportFate.add),
            p[1].withFate(ImportFate.leftOut),
          ],
          uncategorizedNames: ['Not categorized'],
        );
        expect(r.added.length, 1);
        expect(r.matched, isEmpty);
        final again = await plan(rows);
        expect(again[0].fate, ImportFate.already);
        expect(again[1].fate, ImportFate.add);
      },
    );

    test('the plan names typed rows the file lacks, and earlier imports '
        'in the same days', () async {
      await db.postSimple(
        accountId: bank,
        date: DateTime(2026, 9, 5),
        today: DateTime(2026, 9, 30),
        payee: 'Nomin',
        counterAccountId: groceries,
        amount: -1200000,
      );
      final first = [row(3, -1000, 'A'), row(8, -2000, 'B')];
      await db.applyImport(
        accountId: bank,
        plan: await plan(first),
        uncategorizedNames: ['Not categorized'],
      );
      // The same days again in another form: different keys.
      final second = [row(3, -1000, 'A POS'), row(8, -2000, 'B POS')];
      final p = await db.planImport(bank, second, importKeys(bank, second));
      expect(p.rows.every((x) => x.fate == ImportFate.add), isTrue);
      expect(p.importedBefore, 2);
      expect(p.unmatched.single.payee, 'Nomin');
      expect(p.unmatched.single.amount, -1200000);
    });

    test('a reconciled row matches but keeps its memo and its lock', () async {
      final id = await db.postSimple(
        accountId: bank,
        date: DateTime(2026, 9, 2),
        today: DateTime(2026, 9, 30),
        payee: 'Rent',
        counterAccountId: groceries,
        amount: -100000,
      );
      final snap = await db.snapshot(id);
      final entry = snap.entries.firstWhere((e) => e.accountId == bank).id;
      await db.customStatement('UPDATE entries SET cleared = ? WHERE id = ?', [
        Cleared.reconciled.index,
        entry,
      ]);
      final p = await plan([row(3, -100000, 'Landlord')]);
      expect(p.single.fate, ImportFate.match);
      final r = await db.applyImport(
        accountId: bank,
        plan: p,
        uncategorizedNames: ['Not categorized'],
      );
      var t = await db.snapshot(id);
      expect(t.header.memo, isNull);
      expect(
        t.entries.firstWhere((e) => e.id == entry).cleared,
        Cleared.reconciled,
      );
      await db.undoImport(r);
      t = await db.snapshot(id);
      expect(
        t.entries.firstWhere((e) => e.id == entry).cleared,
        Cleared.reconciled,
      );
      expect(
        (await plan([row(3, -100000, 'Landlord')])).single.fate,
        ImportFate.match,
      );
    });

    test('rows before the opening balance: it moves before them, and undo '
        'puts it back', () async {
      await db.postOpeningBalance(
        accountId: bank,
        date: DateTime(2026, 9, 30),
        balance: 100000000,
      );
      final rows = [row(5, -2000000, 'A'), row(10, 5000000, 'B')];
      final p = await db.planImport(bank, rows, importKeys(bank, rows));
      expect(p.opening!.date, DateTime(2026, 9, 30));
      expect(p.opening!.amount, 100000000);
      final r = await db.applyImport(
        accountId: bank,
        plan: p.rows,
        uncategorizedNames: ['Not categorized'],
        moveOpening: (date: DateTime(2026, 9, 4), amount: 97000000),
      );
      var data = await db.loadLedger();
      // Today's balance is what it was: the opening balance holds the rest.
      expect(data.balanceOf(bank), 100000000);
      expect(
        (await db.snapshot(r.openingMove!.transactionId)).header.date,
        '2026-09-04',
      );
      await db.undoImport(r);
      data = await db.loadLedger();
      expect(data.balanceOf(bank), 100000000);
      expect(
        (await db.snapshot(r.openingMove!.transactionId)).header.date,
        '2026-09-30',
      );
      await db.redoImport(r, bank);
      expect((await db.loadLedger()).balanceOf(bank), 100000000);
    });

    test(
      'a match keeps the typed date unless the bank\'s is another month',
      () async {
        Future<int> typed(int day, int month) => db.postSimple(
          accountId: bank,
          date: DateTime(2026, month, day),
          today: DateTime(2026, 10, 30),
          payee: 'X',
          counterAccountId: groceries,
          amount: -100000 * day,
        );
        final same = await typed(3, 9);
        final across = await typed(29, 9);
        final rows = [
          ImportRow(
            sourceRow: 0,
            date: DateTime(2026, 9, 5),
            amount: -300000,
            payee: 'X',
          ),
          ImportRow(
            sourceRow: 1,
            date: DateTime(2026, 10, 2),
            amount: -2900000,
            payee: 'X',
          ),
        ];
        final p = await plan(rows);
        expect(p.every((x) => x.fate == ImportFate.match), isTrue);
        final r = await db.applyImport(
          accountId: bank,
          plan: p,
          uncategorizedNames: ['Not categorized'],
        );
        expect((await db.snapshot(same)).header.date, '2026-09-03');
        expect((await db.snapshot(across)).header.date, '2026-10-02');
        await db.undoImport(r);
        expect((await db.snapshot(across)).header.date, '2026-09-29');
      },
    );

    test('a typed row too far from the bank date is not matched', () async {
      await db.postSimple(
        accountId: bank,
        date: DateTime(2026, 9, 1),
        today: DateTime(2026, 9, 30),
        payee: 'Rent',
        counterAccountId: groceries,
        amount: -100000,
      );
      final p = await plan([row(20, -100000, 'Rent')]);
      expect(p.single.fate, ImportFate.add);
    });

    test('a row the user deleted stays deleted on the next import', () async {
      final rows = [row(3, -1000, 'X')];
      final r = await db.applyImport(
        accountId: bank,
        plan: await plan(rows),
        uncategorizedNames: ['Not categorized'],
      );
      await db.softDelete(r.added.keys.single);
      expect((await plan(rows)).single.fate, ImportFate.already);
    });
  });
}

ArchiveFile _f(String name, String xml) {
  final bytes = utf8Bytes(xml);
  return ArchiveFile(name, bytes.length, bytes);
}
