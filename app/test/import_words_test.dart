import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/money.dart';
import 'package:betterbudget/import/mapping.dart';
import 'package:betterbudget/ui/import_words.dart';
import 'package:betterbudget/ui/language.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// What an import says about a bill waiting for Confirm that a bank row
// paid (#597): the window's line, and the sentence after.
void main() {
  final t = lookupWords(const Locale('en'));
  const account = AccountInfo(
    id: 1,
    name: 'Checking',
    type: AccountType.asset,
  );

  ImportPlanRow billRow(String name) => ImportPlanRow(
    row: ImportRow(
      sourceRow: 0,
      date: DateTime(2026, 9, 20, 9, 57),
      amount: -50000000,
      payee: 'POS Purchase',
    ),
    key: 'k',
    fate: ImportFate.match,
    match: TypedMatch(
      transactionId: 7,
      entryId: 8,
      date: DateTime(2026, 9, 16),
      payee: name,
      cleared: Cleared.uncleared,
      hasMemo: false,
      bill: true,
    ),
  );

  test('the window names each bill, its amount, due date, the bank\'s day '
      'and the bank\'s words; past three, how many more', () {
    expect(
      importBillsPaidLines(t, [billRow('Giving')], Currency.mnt),
      [
        'Giving −₮500,000.00, due ${sayFullDate(t, DateTime(2026, 9, 16))}, '
            'was paid on ${sayFullDate(t, DateTime(2026, 9, 20))} by '
            '“POS Purchase”: it’s confirmed and cleared.',
      ],
    );
    final five = importBillsPaidLines(t, [
      for (final n in ['A', 'B', 'C', 'D', 'E']) billRow(n),
    ], Currency.mnt);
    expect(five, hasLength(4));
    expect(
      five.last,
      '2 more bills waiting for Confirm are paid the same way.',
    );
    expect(importBillsPaidLines(t, const [], Currency.mnt), isEmpty);
  });

  test('after: a bill paid is a bill paid, not a typed row cleared', () {
    const bill = MatchedImport(7, 8, Cleared.uncleared, 'k', confirmed: true);
    const typed = MatchedImport(9, 10, Cleared.uncleared, 'j');
    String said(ImportRecord r) => importSays(
      t,
      record: r,
      account: account,
      accounts: const {1: account},
      uncategorized: 'Not categorized',
    );
    expect(
      said(const ImportRecord(added: {}, matched: [bill])),
      '1 bill paid',
    );
    expect(
      said(const ImportRecord(added: {}, matched: [typed, bill])),
      '1 typed row now cleared · 1 bill paid.',
    );
    expect(
      said(const ImportRecord(added: {3: 'x'}, matched: [typed, bill])),
      'Imported 1 row · 1 typed row now cleared · 1 bill paid.',
    );
  });
}
