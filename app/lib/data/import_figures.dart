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

/// A new account's start, from its bank file (owner, 2026-10-06): the day
/// before the first row coming in and what the account held then, with the
/// balance the file ends at, and its day, when the file gives one.
typedef ImportStart = ({DateTime date, int amount, int? end, DateTime? endDay});

/// The first and last days of the rows [read], or null with none.
(DateTime, DateTime)? fileSpan(ReadResult? read) {
  final rows = read?.rows;
  if (rows == null || rows.isEmpty) return null;
  var first = dateOnly(rows.first.date), last = first;
  for (final r in rows) {
    final d = dateOnly(r.date);
    if (d.isBefore(first)) first = d;
    if (d.isAfter(last)) last = d;
  }
  return (first, last);
}

/// The day a new account's rows come in from at first: the budget period
/// it's in, [periodStart], when the file reaches back before it (older
/// rows change nothing the budget shows and would all wait to be
/// categorized), else the file's first row.
DateTime startDayFor((DateTime, DateTime) span, DateTime? periodStart) =>
    periodStart != null &&
        periodStart.isAfter(span.$1) &&
        !periodStart.isAfter(span.$2)
    ? periodStart
    : span.$1;

/// The day rows come in from, [from], when it's after the file's first:
/// rows before it stay out and the account starts there. Null otherwise.
DateTime? startCut((DateTime, DateTime)? span, DateTime? from) =>
    span == null || from == null || !from.isAfter(span.$1) ? null : from;

/// A new account's start from [read]. A table's comes from its first and
/// last rows; an OFX file's one balance is worked back through every row;
/// with neither, [typed] (what's in it today, as typed: what's owed,
/// positive, on a card) is worked back through the rows [plan] adds, and
/// with nothing typed it starts at zero. [cut] is [startCut]'s day.
ImportStart? importStart({
  required ReadResult? read,
  required ImportPlan? plan,
  required DateTime? cut,
  required bool owed,
  int? typed,
}) {
  final span = fileSpan(read);
  if (read == null || span == null) return null;
  final (first, last) = span;
  final date = (cut ?? first).subtract(const Duration(days: 1));
  // What the rows left out before the start day add up to.
  final earlier = cut == null
      ? 0
      : read.rows
            .where((r) => dateOnly(r.date).isBefore(cut))
            .fold<int>(0, (s, r) => s + r.amount);
  if (read.check case final c?) {
    return (
      date: date,
      amount: c.opening + earlier,
      end: c.closing,
      endDay: last,
    );
  }
  if (read.closing case final c?) {
    // Banks write what a card owes with either sign.
    final end = owed && c > 0 ? -c : c;
    return (
      date: date,
      amount: end - read.rows.fold<int>(0, (s, r) => s + r.amount) + earlier,
      end: end,
      endDay: read.closingDay ?? last,
    );
  }
  if (typed == null) return (date: date, amount: 0, end: null, endDay: null);
  var before = owed ? -typed : typed;
  for (final p in plan?.rows ?? const <ImportPlanRow>[]) {
    if (p.fate == ImportFate.add) before -= p.row.amount;
  }
  return (date: date, amount: before, end: null, endDay: null);
}

/// How many of [read]'s rows fall before [cut], left out of a new account.
int rowsBefore(ReadResult read, DateTime? cut) => cut == null
    ? 0
    : read.rows.where((r) => dateOnly(r.date).isBefore(cut)).length;
