// What an import works out before anything is written (ADR 0002; ADR 0004
// "Import"): the file as read, a date that reads two ways, the rows the
// opening balance already counts, the cleared balance against the bank's,
// and the typed rows the file lacks. Lifted out of the computer's import
// window so the phone's page says the same things from the same sums (#531).
import 'dart:typed_data';

import '../domain/ledger.dart' show Cleared, dateOnly;
import '../import/mapping.dart';
import '../import/sheet.dart';
import 'database.dart'
    show ImportFate, ImportPlan, ImportPlanRow, UnmatchedTyped;

/// A bank file read: its table, what kind of file it is, and the columns
/// to start from, which are the account's saved ones when [fits].
typedef OpenedBankFile = ({
  Sheet sheet,
  FileKind kind,
  bool fits,
  ImportMapping mapping,
});

/// Reads the bank file [bytes], told apart by its contents and [name]. The
/// columns [saved] for the account are used when the file is shaped as the
/// last one was and its balance had proved them; otherwise they are guessed.
/// Throws when the file can't be read.
OpenedBankFile openBankFile(Uint8List bytes, String name, SavedMapping? saved) {
  final kind =
      fileKindOf(bytes, name) ??
      (throw const UnreadableFileException('unknown kind'));
  final sheet = readSheet(bytes, name);
  final fits =
      saved != null &&
      saved.current &&
      saved.proven &&
      mappingFits(sheet, saved);
  return (
    sheet: sheet,
    kind: kind,
    fits: fits,
    mapping: fits ? saved.mapping : guessMapping(sheet),
  );
}

/// Whether [name] ends as a kind of file the app reads: one that then
/// didn't read is damaged, and the list of kinds would only repeat what
/// it is.
bool isBankFileName(String name) => RegExp(
  r'\.(xlsx?|csv|txt|tsv|ofx|qfx|qbo)$',
  caseSensitive: false,
).hasMatch(name);

/// A date of the file's that reads both day first and month first, like
/// 03.04, when every date in the column fits both orders: the person is
/// asked which. Null when there is nothing to ask.
String? dateReadBothWays(Sheet sheet, ImportMapping mapping) {
  final dateCol = mapping.columnOf(ColumnRole.date);
  if (dateCol == null) return null;
  final texts = [
    for (var r = (mapping.headerRow ?? -1) + 1; r < sheet.rows.length; r++)
      if (sheet.cell(r, dateCol) case final String s)
        if (parseDateText(s, DateOrder.dmy) != null ||
            parseDateText(s, DateOrder.mdy) != null)
          s,
  ];
  final fits = fittingOrders(texts);
  if (!fits.contains(DateOrder.dmy) || !fits.contains(DateOrder.mdy)) {
    return null;
  }
  return texts
      .where(
        (s) =>
            parseDateText(s, DateOrder.dmy) != parseDateText(s, DateOrder.mdy),
      )
      .firstOrNull;
}

/// New rows the opening balance already holds (dated on or before its
/// day), and where it would move so today's balance stays: the day before
/// them, less what they add. Null when there are none.
({List<ImportPlanRow> rows, DateTime date, int amount})? heldByOpening(
  ImportPlan? plan,
) {
  final opening = plan?.opening;
  if (plan == null || opening == null) return null;
  final rows = [
    for (final p in plan.rows)
      if (p.fate == ImportFate.add &&
          !dateOnly(p.row.date).isAfter(opening.asOf))
        p,
  ];
  if (rows.isEmpty) return null;
  final first = rows
      .map((p) => dateOnly(p.row.date))
      .reduce((a, b) => a.isBefore(b) ? a : b);
  final before = first.subtract(const Duration(days: 1));
  return (
    rows: rows,
    date: before.isBefore(opening.date) ? before : opening.date,
    amount: opening.amount - rows.fold(0, (s, p) => s + p.row.amount),
  );
}

/// What the account's cleared balance will be after the import ([ours])
/// against the bank's ([bank]): the balance on the file's last row, or the
/// one balance an OFX file gives, which is [day]'s. [held] is what the rows
/// skipped for the opening balance come to, each: apart from the bank, they
/// may be why. Null when the file gives no balance.
({int ours, int bank, DateTime? day, List<int> held})? clearedAgainstBank({
  required ReadResult read,
  required ImportPlan plan,
  required int cleared,
  required bool owed,
  ({DateTime date, int amount})? openingMove,
}) {
  final check = read.check;
  var bank = check?.closing ?? read.closing;
  if (bank == null) return null;
  var ours = cleared;
  if (openingMove != null) ours += openingMove.amount - plan.opening!.amount;
  for (final p in plan.rows) {
    if (p.fate == ImportFate.add) ours += p.row.amount;
    if (p.fate == ImportFate.match && p.match!.cleared == Cleared.uncleared) {
      ours += p.row.amount;
    }
  }
  // Banks write what a card owes with either sign; take the one nearer.
  if (check == null && owed && (ours + bank).abs() < (ours - bank).abs()) {
    bank = -bank;
  }
  return (
    ours: ours,
    bank: bank,
    day: check == null ? read.closingDay : null,
    held: [
      for (final p in plan.rows)
        if (p.held && p.fate == ImportFate.leftOut) p.row.amount,
    ],
  );
}

/// Typed rows in the file's dates that nothing in it matched. One a same
/// purchase took isn't left out any more, and one offered as a same
/// purchase is said there.
List<UnmatchedTyped> typedNotInFile(ImportPlan plan) {
  final taken = {
    for (final p in plan.rows)
      if (p.fate == ImportFate.match)
        ?p.match?.entryId
      else if (p.fate == ImportFate.add)
        ?p.near?.entryId,
  };
  return [
    for (final u in plan.unmatched)
      if (!taken.contains(u.entryId)) u,
  ];
}
