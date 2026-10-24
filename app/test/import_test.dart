// Import: reading bank files, guessing their columns, and writing the rows
// (ADR 0002). All data here is made up.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/payee_rules.dart';
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

  group('ofx reader', () {
    // The older form as a bank writes it: one line, values never closed.
    const oneLine =
        'OFXHEADER:100 DATA:OFXSGML VERSION:102 ENCODING:USASCII '
        '<OFX><BANKMSGSRSV1><STMTTRNRS><STMTRS><CURDEF>USD<BANKTRANLIST>'
        '<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20260901120000.000[0:GMT]'
        '<TRNAMT>-12.50<FITID>900001<NAME>Corner Shop<MEMO>FOOD</STMTTRN>'
        '<STMTTRN><TRNTYPE>CREDIT<DTPOSTED>20260902120000.000[0:GMT]'
        '<TRNAMT>1000.00<FITID>900002<NAME>Tom &amp; Sons Pay</STMTTRN>'
        '<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20260903<TRNAMT>-40.00'
        '<FITID>900003<MEMO>CHECK<MEMO /></STMTTRN>'
        '</BANKTRANLIST><LEDGERBAL><BALAMT>947.50</LEDGERBAL>'
        '</STMTRS></STMTTRNRS></BANKMSGSRSV1></OFX>';

    test('one line of unclosed tags, whatever the file is called', () {
      for (final name in ['bank.ofx', 'bank.qfx', 'bank.ofx.txt', 'bank']) {
        expect(fileKindOf(utf8Bytes(oneLine), name), FileKind.ofx);
      }
      final sheet = readSheet(utf8Bytes(oneLine), 'bank.ofx.txt');
      final m = guessMapping(sheet);
      expect(m.headerRow, 0);
      expect(m.roleOf(0), ColumnRole.date);
      expect(m.roleOf(1), ColumnRole.amount);
      expect(m.roleOf(2), ColumnRole.payee);
      expect(m.roleOf(3), ColumnRole.memo);
      final read = readRows(sheet, m);
      expect(read.skipped, isEmpty);
      expect(read.rows.map((r) => r.date), [
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 2),
        DateTime(2026, 9, 3),
      ]);
      expect(read.rows.every((r) => !r.hasTime), isTrue);
      expect(read.rows.map((r) => r.amount), [-1250, 100000, -4000]);
      // A row without a name is called by its memo.
      expect(read.rows.map((r) => r.payee), [
        'Corner Shop',
        'Tom & Sons Pay',
        'CHECK',
      ]);
      expect(read.rows.map((r) => r.memo), ['FOOD', null, null]);
      expect(read.check, isNull);
    });

    test('the XML form, on lines', () {
      final sheet = readSheet(
        utf8Bytes(
          '<?xml version="1.0"?>\n<?OFX OFXHEADER="200" VERSION="211"?>\n'
          '<OFX>\n<CREDITCARDMSGSRSV1><CCSTMTRS><BANKTRANLIST>\n'
          '<STMTTRN>\n  <TRNTYPE>DEBIT</TRNTYPE>\n'
          '  <DTPOSTED>20260915</DTPOSTED>\n  <TRNAMT>-7,25</TRNAMT>\n'
          '  <FITID>A-1</FITID>\n  <NAME>Kiosk</NAME>\n</STMTTRN>\n'
          '</BANKTRANLIST></CCSTMTRS></CREDITCARDMSGSRSV1>\n</OFX>\n',
        ),
        'card.qfx',
      );
      final read = readRows(sheet, guessMapping(sheet));
      expect(read.rows.single.date, DateTime(2026, 9, 15));
      expect(read.rows.single.amount, -725);
      expect(read.rows.single.payee, 'Kiosk');
      expect(read.rows.single.bankId, 'A-1');
    });

    test("the bank's id is the key, so a reworded name still matches", () {
      final first = readSheet(utf8Bytes(oneLine), 'a.ofx');
      final later = readSheet(
        utf8Bytes(oneLine.replaceAll('Corner Shop', 'CORNER SHOP #12 KS')),
        'b.ofx',
      );
      final a = importKeys(7, readRows(first, guessMapping(first)).rows);
      final b = importKeys(7, readRows(later, guessMapping(later)).rows);
      expect(a, ['a7|id|900001', 'a7|id|900002', 'a7|id|900003']);
      expect(b, a);
    });

    test('amounts, a CDATA name, a second account, a table naming OFX', () {
      const two =
          'OFXHEADER:100\n<OFX><BANKMSGSRSV1>'
          '<STMTTRNRS><STMTRS><BANKACCTFROM><ACCTID>1</BANKACCTFROM>'
          '<BANKTRANLIST><STMTTRN><DTPOSTED>20260901<TRNAMT>-1.500'
          '<FITID>1<NAME><![CDATA[Shop & Co]]></STMTTRN></BANKTRANLIST>'
          '</STMTRS></STMTTRNRS>'
          '<STMTTRNRS><STMTRS><BANKACCTFROM><ACCTID>2</BANKACCTFROM>'
          '<BANKTRANLIST><STMTTRN><DTPOSTED>20260902<TRNAMT>-9.00'
          '<FITID>1<NAME>Other account</STMTTRN></BANKTRANLIST>'
          '</STMTRS></STMTTRNRS></BANKMSGSRSV1></OFX>';
      final sheet = readSheet(utf8Bytes(two), 'two.ofx');
      final row = readRows(sheet, guessMapping(sheet)).rows.single;
      expect(row.amount, -150); // not 1,500: OFX has no thousands dots
      expect(row.payee, 'Shop & Co');
      expect(
        fileKindOf(utf8Bytes('Date,Memo\n2026-09-01,"an <OFX> file"\n'), 'a'),
        isNot(FileKind.ofx),
      );
    });

    String statement(
      List<(String name, String memo)> rows, {
      String end = '',
    }) =>
        'OFXHEADER:100\n<OFX><STMTRS><BANKTRANLIST>'
        '${[for (final (i, r) in rows.indexed) '<STMTTRN><DTPOSTED>202609${10 + i}<TRNAMT>-${i + 1}.00<FITID>$i${r.$1.isEmpty ? '' : '<NAME>${r.$1}'}${r.$2.isEmpty ? '' : '<MEMO>${r.$2}'}</STMTTRN>'].join()}'
        '</BANKTRANLIST>$end</STMTRS></OFX>';

    test("a memo that is the bank's own category is left out", () {
      const shops = ['Kiosk', 'Corner Shop', 'Bus', 'Kiosk', 'Bakery', 'Bus'];
      const kinds = [
        'FOOD',
        'FOOD',
        'Getting Around',
        'FOOD',
        '',
        'TRAVEL_BUS',
      ];
      final sheet = readSheet(
        utf8Bytes(
          statement([for (var i = 0; i < 6; i++) (shops[i], kinds[i])]),
        ),
        'a.qfx',
      );
      final m = guessMapping(sheet);
      expect(m.roleOf(2), ColumnRole.payee);
      expect(m.roleOf(3), ColumnRole.ignore);
      expect(readRows(sheet, m).rows.every((r) => r.memo == null), isTrue);

      // Notes with figures in them, or a row with nothing but its memo:
      // the memo stays.
      final notes = readSheet(
        utf8Bytes(
          statement([
            for (var i = 0; i < 6; i++) (shops[i], 'CARD 09/1$i REF 55$i'),
          ]),
        ),
        'b.qfx',
      );
      expect(guessMapping(notes).roleOf(3), ColumnRole.memo);
      final nameless = readSheet(
        utf8Bytes(
          statement([
            for (var i = 0; i < 6; i++) (i == 2 ? '' : shops[i], 'FOOD'),
          ]),
        ),
        'c.qfx',
      );
      expect(guessMapping(nameless).roleOf(3), ColumnRole.memo);
    });

    test("the one balance in the file is the bank's, with its day", () {
      final sheet = readSheet(
        utf8Bytes(
          statement(
            [('Kiosk', ''), ('Bus', '')],
            end:
                '<LEDGERBAL><BALAMT>1,234.50<DTASOF>20260930214808.851[-6]'
                '</LEDGERBAL><AVAILBAL><BALAMT>900.00<DTASOF>20261001'
                '</AVAILBAL>',
          ),
        ),
        'a.ofx',
      );
      final read = readRows(sheet, guessMapping(sheet));
      expect(read.check, isNull);
      // Never the available balance, which counts holds.
      expect(read.closing, 123450);
      expect(read.closingDay, DateTime(2026, 9, 30));
    });

    test('a column choice saved before the guess changed is guessed again', () {
      final sheet = readSheet(utf8Bytes(oneLine), 'a.ofx');
      final m = guessMapping(sheet);
      final now = SavedMapping(
        shape: fileShape(sheet, m),
        kind: FileKind.ofx,
        mapping: m,
      );
      expect(SavedMapping.decode(now.encode())!.current, isTrue);
      final old = (jsonDecode(now.encode()) as Map)..remove('guess');
      expect(SavedMapping.decode(jsonEncode(old))!.current, isFalse);
    });

    test('a file with no transactions has no rows, and says so', () {
      final sheet = readSheet(
        utf8Bytes('OFXHEADER:100 <OFX><BANKTRANLIST></BANKTRANLIST></OFX>'),
        'empty.ofx',
      );
      expect(guessMapping(sheet).hasDate, isFalse);
    });
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
      expect(readAmount('.37'), 37); // cents alone, as a credit union writes
      expect(readAmount('-.5'), -50);
      expect(readAmount('.375'), isNull); // not thousands, not cents
      expect(readAmount('.'), isNull);
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

    // A US credit union's table: the description is who was paid, the
    // classification is the bank's own category, every row says "Posted".
    const creditUnion =
        'Account Number,Post Date,Check,Description,Debit,Credit,Status,'
        'Balance,Classification\n'
        '"*0042",9/24/2026,,"Corner Shop",12.50,,Posted,1027.87,"FOOD"\n'
        '"*0042",9/23/2026,,"Interest",,.37,Posted,1040.37,\n'
        '"*0042",9/22/2026,,"Tom & Sons Pay",,1000.00,Posted,1040.00,"PAY"\n'
        '"*0042",9/21/2026,,"CARD 09/01 KIOSK 12 KS",60.00,,Posted,40.00,""\n';

    test('a description is the payee; the bank\'s category is left out', () {
      final sheet = readSheet(utf8Bytes(creditUnion), 'history.csv');
      final m = guessMapping(sheet);
      expect(m.headerRow, 0);
      expect(m.dateOrder, DateOrder.mdy);
      expect(m.roles, {
        1: ColumnRole.date,
        3: ColumnRole.payee,
        4: ColumnRole.moneyOut,
        5: ColumnRole.moneyIn,
        7: ColumnRole.balance,
      });
      final read = readRows(sheet, m);
      expect(read.skipped, isEmpty);
      expect(read.newestFirst, isTrue);
      expect(read.rows.map((r) => r.amount), [-6000, 100000, 37, -1250]);
      expect(read.rows.map((r) => r.payee), [
        'CARD 09/01 KIOSK 12 KS',
        'Tom & Sons Pay',
        'Interest',
        'Corner Shop',
      ]);
      expect(read.rows.every((r) => r.memo == null), isTrue);
      expect(read.check!.ok, isTrue);
    });

    test('names a column to the left of their figures still find them', () {
      final sheet = readSheet(
        utf8Bytes(
          'Date,Credit,Debit,Balance,Description,\n'
          ',2026-09-21,2000.00,,2000.00,Pay\n'
          ',2026-09-22,,500.00,1500.00,Rent\n'
          ',2026-09-23,,40.00,1460.00,Kiosk\n',
        ),
        'staggered.csv',
      );
      final read = readRows(sheet, guessMapping(sheet));
      expect(read.rows.map((r) => r.amount), [200000, -50000, -4000]);
    });

    test('the only words in a file are the payee, even all the same', () {
      final sheet = readSheet(
        utf8Bytes(
          '2026-09-21,-500.00,Rent\n2026-09-22,-500.00,Rent\n'
          '2026-09-23,-500.00,Rent\n',
        ),
        'rent.csv',
      );
      final read = readRows(sheet, guessMapping(sheet));
      expect(read.rows.map((r) => r.payee), ['Rent', 'Rent', 'Rent']);
    });

    test('a status that differs by row is still not the payee', () {
      final sheet = readSheet(
        utf8Bytes(creditUnion.replaceFirst('Posted', 'Pending')),
        'history.csv',
      );
      final m = guessMapping(sheet);
      expect(m.roleOf(3), ColumnRole.payee);
      expect(m.roleOf(6), ColumnRole.ignore);
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
      // The same days again in another form (different keys), and two rows
      // the first file didn't have.
      final second = [
        row(2, -500, 'C'),
        row(3, -1000, 'A POS'),
        row(8, -2000, 'B POS'),
        row(9, -700, 'D'),
      ];
      final p = await db.planImport(bank, second, importKeys(bank, second));
      expect(p.rows.map((x) => x.fate), [
        ImportFate.add,
        ImportFate.leftOut,
        ImportFate.leftOut,
        ImportFate.add,
      ]);
      expect(p.rows.map((x) => x.repeat), [false, true, true, false]);
      expect(p.importedBefore, 2);
      expect(p.unmatched.single.payee, 'Nomin');
      expect(p.unmatched.single.amount, -1200000);
    });

    test('a repeat is one imported row for one bank row, deleted or not, and '
        'can be brought in', () async {
      final first = [row(3, -1000, 'Coffee'), row(4, -2500, 'Lunch')];
      final r = await db.applyImport(
        accountId: bank,
        plan: await plan(first),
        uncategorizedNames: ['Not categorized'],
      );
      await db.softDelete(r.added.keys.last);
      // Another kind of file: two coffees that day now, and the lunch the
      // user deleted.
      final second = [
        row(3, -1000, 'COFFEE 1'),
        row(3, -1000, 'COFFEE 2'),
        row(4, -2500, 'LUNCH'),
      ];
      final p = await plan(second);
      expect(p.map((x) => x.repeat), [true, false, true]);
      expect(p[1].fate, ImportFate.add);
      // Two things at one price on one day, one of them in already: the
      // one of the same name is the repeat, wherever it sits in the file.
      final named = await plan([
        row(3, -1000, 'Tea'),
        row(3, -1000, 'Coffee Co'),
      ]);
      expect(named.map((x) => x.repeat), [false, true]);
      // The same file as before is known by its keys, never as a repeat.
      expect(
        (await plan(first)).map((x) => x.fate),
        everyElement(ImportFate.already),
      );
      final back = p[0].withFate(ImportFate.add);
      expect(back.repeat, isTrue);
      final again = await db.applyImport(
        accountId: bank,
        plan: [back, p[1], p[2]],
        uncategorizedNames: ['Not categorized'],
      );
      expect(again.added.length, 2);
    });

    test('a new account started from its file: the opening balance and the '
        'rows are one write, one undo, one redo', () async {
      final fresh = await db.createAccount(
        name: 'Savings',
        type: AccountType.asset,
      );
      final rows = [row(3, -1000, 'Kiosk'), row(8, 25000, 'Pay')];
      final r = await db.applyImport(
        accountId: fresh,
        plan: await plan(rows, into: fresh),
        uncategorizedNames: ['Not categorized'],
        start: (date: DateTime(2026, 9, 2), amount: 50000),
      );
      Future<int> balance() async => (await db.loadLedger()).txns
          .expand((t) => t.entries)
          .where((e) => e.accountId == fresh)
          .fold<int>(0, (s, e) => s + e.amount);
      expect(r.openingId, isNotNull);
      expect(await balance(), 74000);
      final opening = await db.snapshot(r.openingId!);
      expect(opening.header.date, '2026-09-02');
      await db.undoImport(r);
      expect(await balance(), 0);
      await db.redoImport(r, fresh);
      expect(await balance(), 74000);
      // The same file again: nothing new, and no second opening balance.
      expect(
        (await plan(rows, into: fresh)).map((p) => p.fate),
        everyElement(ImportFate.already),
      );
    });

    /// What each row an import added was filed under, by payee.
    Future<Map<String, int>> filed(ImportRecord r, int account) async => {
      for (final t in (await db.loadLedger()).txns)
        if (r.added.containsKey(t.id))
          t.payee ?? '': t.entries
              .firstWhere((e) => e.accountId != account)
              .accountId,
    };

    Future<ImportRecord> bring(List<ImportRow> rows, {int? into}) async =>
        db.applyImport(
          accountId: into ?? bank,
          plan: await plan(rows, into: into),
          uncategorizedNames: ['Not categorized'],
        );

    test('a remembered payee goes where the person said, whatever the bank '
        'adds after the name; the longest words win, then the later', () async {
      final dining = await db.createCategory('Dining out');
      // Filed under Groceries last time; the rule says Dining out.
      await db.postSimple(
        accountId: bank,
        date: DateTime(2026, 9, 1),
        today: DateTime(2026, 9, 30),
        payee: 'Corner Cafe 0901',
        counterAccountId: groceries,
        amount: -500,
      );
      await db.addPayeeRule(
        name: 'Corner',
        anywhere: false,
        categoryId: groceries,
        accountIds: {bank},
      );
      await db.addPayeeRule(
        name: 'Corner Cafe',
        anywhere: false,
        categoryId: dining,
        accountIds: {bank},
      );
      var by = await filed(
        await bring([
          row(15, -700, 'CORNER CAFE 0915'),
          row(16, -900, 'Bus'),
          row(17, -200, 'Corner shop'),
        ]),
        bank,
      );
      expect(by['CORNER CAFE 0915'], dining);
      expect(by['Corner shop'], groceries);
      expect(by['Bus'], isNot(dining));
      // Two with the same words: the later decision counts.
      for (final (id, category, at) in [(1, groceries, 10), (2, dining, 20)]) {
        await db.putPayeeRule(
          PayeeRuleInfo(
            id: id,
            words: 'bus',
            name: 'Bus',
            anywhere: false,
            categoryId: category,
            accountIds: {bank},
            createdAt: at,
          ),
        );
      }
      by = await filed(await bring([row(18, -900, 'Bus 18')]), bank);
      expect(by['Bus 18'], dining);
      // The setting an older build kept still reads, for the upgrade.
      final kept = PayeeRule.decode(
        PayeeRule.encode([
          const PayeeRule('corner', 1, name: 'Corner'),
          const PayeeRule('nomin', 2, payId: 7),
        ]),
      );
      expect(kept.map((r) => r.name), ['Corner', null]);
      expect(kept.last.payId, 7);
    });

    test('words anywhere catch a payee in the middle of the bank’s text, '
        'and in its description', () async {
      final rule = await db.addPayeeRule(
        name: 'Номин',
        anywhere: true,
        categoryId: groceries,
        accountIds: {bank},
      );
      var by = await filed(
        await bring([
          row(3, -1000, 'POS 12345678: НОМИН'),
          ImportRow(
            sourceRow: 4,
            date: DateTime(2026, 9, 4),
            amount: -2000,
            payee: 'QPay',
            memo: 'QPAY*Номин 0412',
          ),
          row(5, -300, 'Nomin'),
        ]),
        bank,
      );
      expect(by['POS 12345678: НОМИН'], groceries);
      expect(by['QPay'], groceries);
      // Another spelling is another payee.
      expect(by['Nomin'], isNot(groceries));
      // At the start of the payee, the description isn't looked at.
      await db.putPayeeRule(rule.copyWith(anywhere: false));
      by = await filed(
        await bring([
          ImportRow(
            sourceRow: 6,
            date: DateTime(2026, 9, 6),
            amount: -2000,
            payee: 'Kiosk',
            memo: 'QPAY*Номин 0413',
          ),
          row(7, -400, 'номин маркет'),
        ]),
        bank,
      );
      expect(by['Kiosk'], isNot(groceries));
      expect(by['номин маркет'], groceries);
    });

    test('a deleted payee stops going to its category by itself, and goes '
        'where it is next filed by hand', () async {
      final phone = await db.createCategory('Phone');
      await db.postSimple(
        accountId: bank,
        date: DateTime(2026, 9, 1),
        today: DateTime(2026, 9, 30),
        payee: 'Unitel',
        counterAccountId: groceries,
        amount: -30000,
      );
      // Amounts no typed row matches, so each comes in as its own row.
      final rule = await db.addPayeeRule(
        name: 'Unitel',
        anywhere: false,
        categoryId: groceries,
        accountIds: {bank},
      );
      await db.putPayeeRule(rule.copyWith(deleted: true));
      // Its last row is in Groceries; it doesn't go back there.
      var by = await filed(await bring([row(10, -31000, 'Unitel')]), bank);
      final holding = (await db.loadLedger()).accounts.values
          .firstWhere((a) => a.name == 'Not categorized')
          .id;
      expect(by['Unitel'], holding);
      // Filed under Phone by hand: the next one follows that.
      await db.postSimple(
        accountId: bank,
        date: DateTime(2026, 9, 11),
        today: DateTime(2026, 9, 30),
        payee: 'Unitel',
        counterAccountId: phone,
        amount: -32000,
      );
      by = await filed(await bring([row(12, -33000, 'Unitel')]), bank);
      expect(by['Unitel'], phone);
      // Filed under Groceries by hand after the Delete: that was decided
      // later, so it counts again.
      await db.postSimple(
        accountId: bank,
        date: DateTime(2026, 9, 13),
        today: DateTime(2026, 9, 30),
        payee: 'Unitel',
        counterAccountId: groceries,
        amount: -34000,
      );
      by = await filed(await bring([row(14, -35000, 'Unitel')]), bank);
      expect(by['Unitel'], groceries);
      // A row typed by hand starts in the remembered category too, and not
      // in a deleted one.
      expect(await db.suggestedCategory('Unitel', bank), groceries);
      final nomin = await db.addPayeeRule(
        name: 'Номин',
        anywhere: true,
        categoryId: phone,
        accountIds: {bank},
      );
      expect(await db.suggestedCategory('POS 123: НОМИН', bank), phone);
      await db.putPayeeRule(nomin.copyWith(deleted: true));
      expect(await db.suggestedCategory('POS 123: НОМИН', bank), isNull);
    });

    test('a payee on two accounts holds on both and on no other', () async {
      final card = await db.createAccount(
        name: 'Card',
        type: AccountType.liability,
      );
      final other = await db.createAccount(
        name: 'Savings',
        type: AccountType.asset,
      );
      await db.addPayeeRule(
        name: 'Nomin',
        anywhere: false,
        categoryId: groceries,
        accountIds: {bank, card},
      );
      for (final (account, expected) in [
        (bank, groceries),
        (card, groceries),
        (other, null),
      ]) {
        final by = await filed(
          await bring([row(3, -1000, 'NOMIN 0412')], into: account),
          account,
        );
        if (expected == null) {
          expect(by['NOMIN 0412'], isNot(groceries));
        } else {
          expect(by['NOMIN 0412'], expected);
        }
      }
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

    test(
      'a match keeps the date of a transfer reconciled in the other account',
      () async {
        final savings = await db.createAccount(
          name: 'Savings',
          type: AccountType.asset,
        );
        final t = await db.postSimple(
          accountId: bank,
          date: DateTime(2026, 9, 30),
          today: DateTime(2026, 10, 3),
          payee: 'To savings',
          counterAccountId: savings,
          amount: -500000,
        );
        final there = (await db.snapshot(t)).entries
            .singleWhere((e) => e.accountId == savings);
        await db.toggleCleared(there.id);
        await db.reconcile(
          accountId: savings,
          statementDate: DateTime(2026, 9, 30),
          today: DateTime(2026, 10, 3),
          balance: 500000,
        );
        // Checking's bank shows it on 10.02: the month differs, but the
        // savings statement holds the date.
        final p = await plan([
          ImportRow(
            sourceRow: 0,
            date: DateTime(2026, 10, 2),
            amount: -500000,
            payee: 'To savings',
          ),
        ]);
        expect(p.single.fate, ImportFate.match);
        await db.applyImport(
          accountId: bank,
          plan: p,
          uncategorizedNames: ['Not categorized'],
        );
        expect((await db.snapshot(t)).header.date, '2026-09-30');
      },
    );

    test('a typed row at another amount is offered as the same purchase, '
        'never assumed; taken, it gets the bank\'s amount, and undo puts '
        'the typed one back', () async {
      final typed = await db.postSimple(
        accountId: bank,
        date: DateTime(2026, 9, 14),
        today: DateTime(2026, 9, 30),
        payee: 'Номин',
        counterAccountId: groceries,
        amount: -8640000,
      );
      // Far in amount and another name: not offered.
      await db.postSimple(
        accountId: bank,
        date: DateTime(2026, 9, 14),
        today: DateTime(2026, 9, 30),
        payee: 'Shunkhlai',
        counterAccountId: groceries,
        amount: -12000000,
      );
      final rows = [row(15, -8460000, 'POS 12345678: НОМИН СУПЕРМАРКЕТ')];
      final p = await plan(rows);
      expect(p.single.fate, ImportFate.add);
      expect(p.single.near?.transactionId, typed);
      expect(p.single.near?.amount, -8640000);

      final r = await db.applyImport(
        accountId: bank,
        plan: [p.single.samePurchase()],
        uncategorizedNames: ['Not categorized'],
      );
      expect(r.added, isEmpty);
      final after = await db.snapshot(typed);
      final mine = after.entries.singleWhere((e) => e.accountId == bank);
      expect(mine.amountMinor, -8460000);
      expect(mine.cleared, Cleared.cleared);
      expect(
        after.entries.singleWhere((e) => e.accountId == groceries).amountMinor,
        8460000,
      );

      await db.undoImport(r);
      final back = (await db.snapshot(typed)).entries
          .singleWhere((e) => e.accountId == bank);
      expect(back.amountMinor, -8640000);
      expect(back.cleared, Cleared.uncleared);
    });

    test('a cleared typed row, or one within a tenth by amount alone under '
        'another name, is handled as it should be', () async {
      // Cleared already: the bank had it; never offered.
      final cleared = await db.postSimple(
        accountId: bank,
        date: DateTime(2026, 9, 14),
        today: DateTime(2026, 9, 30),
        payee: 'Номин',
        counterAccountId: groceries,
        amount: -8640000,
      );
      final e = (await db.snapshot(cleared)).entries
          .singleWhere((x) => x.accountId == bank);
      await db.toggleCleared(e.id);
      expect((await plan([row(15, -8460000, 'НОМИН')])).single.near, isNull);
      // Another name, the amount within a tenth: offered.
      final other = await db.postSimple(
        accountId: bank,
        date: DateTime(2026, 9, 20),
        today: DateTime(2026, 9, 30),
        payee: 'Taxi',
        counterAccountId: groceries,
        amount: -1000000,
      );
      expect(
        (await plan([row(21, -950000, 'UBCAB')])).single.near?.transactionId,
        other,
      );
      // A week later under another name: two purchases, not offered.
      expect((await plan([row(27, -950000, 'UBCAB')])).single.near, isNull);
    });

    test('same purchase: never a transfer, and the nearest amount wins over '
        'the nearest day', () async {
      final savings = await db.createAccount(
        name: 'Savings',
        type: AccountType.asset,
      );
      // A transfer of about the bank's amount, a day off: not offered.
      await db.postSimple(
        accountId: bank,
        date: DateTime(2026, 9, 12),
        today: DateTime(2026, 9, 30),
        payee: 'To savings',
        counterAccountId: savings,
        amount: -720000,
      );
      expect((await plan([row(13, -700000, 'POS 1234')])).single.near, isNull);
      // Taxi ₮7,500 on 09.12, coffee ₮7,200 on 09.13; the bank's ₮7,000 on
      // 09.13 is the coffee by amount, and by day.
      final taxi = await db.postSimple(
        accountId: bank,
        date: DateTime(2026, 9, 12),
        today: DateTime(2026, 9, 30),
        payee: 'Taxi',
        counterAccountId: groceries,
        amount: -750000,
      );
      final coffee = await db.postSimple(
        accountId: bank,
        date: DateTime(2026, 9, 13),
        today: DateTime(2026, 9, 30),
        payee: 'Coffee',
        counterAccountId: groceries,
        amount: -720000,
      );
      expect(
        (await plan([row(13, -700000, 'POS 1234')])).single.near?.transactionId,
        coffee,
      );
      // ₮7,450 on 09.13 is nearer the taxi's amount though a day further.
      expect(
        (await plan([row(13, -745000, 'POS 1234')])).single.near?.transactionId,
        taxi,
      );
    });

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
