import '../data/database.dart' show ImportFate, ImportPlanRow, ImportRecord;
import '../data/import_figures.dart' show isBankFileName;
import '../import/sheet.dart' show LockedFileException;
import '../domain/ledger.dart';
import '../domain/money.dart';
import 'language.dart';

// What an import did, said after it: the computer's popup and the phone's
// bar say it in the same words (#531).

/// The first thing said: the rows brought in, or, with none, the typed
/// rows the file matched. A bank row joined to the other account's row is
/// a row brought in.
String importDoneLabel(Words t, ImportRecord record) {
  final brought =
      record.added.length + record.joined.length + record.revived.length;
  final typed = record.matched.where((m) => !m.confirmed).length;
  return brought > 0
      ? t.importDone(brought)
      : typed > 0
      ? t.importMatchedToast(typed)
      // Only bills waiting for Confirm, now paid (#597).
      : t.importBillsPaidLabel(record.matched.length);
}

/// What is said when [name] couldn't be read ([e] is why): a file locked
/// with a password says so, since "damaged" would send the person back to
/// the bank for the same locked file; a kind of file it reads that didn't
/// read is damaged, and the list of kinds would only repeat what it is.
String couldntReadSays(Words t, Object e, String name) => switch (e) {
  LockedFileException() => t.importLocked(name),
  _ when isBankFileName(name) => t.importCouldntReadDamaged(name),
  _ => t.importCouldntRead(name),
};

/// Everything an import did, one part after another: the rows, the typed
/// rows now cleared, rows joined to another account's, a transfer that may
/// be the same money twice, what waits in [uncategorized], the bills its
/// rows paid ([billsPaid]) or may have ([billsToCheck]), and an opening
/// balance that moved. [accounts] are the ledger's, by id.
String importSays(
  Words t, {
  required ImportRecord record,
  required AccountInfo account,
  required Map<int, AccountInfo> accounts,
  required String uncategorized,
  int billsPaid = 0,
  int billsToCheck = 0,
}) {
  String nameOf(int id) => accounts[id]?.name ?? '';
  // What an account holds or owes, as its own register says it.
  String money(int accountId, int minor) {
    final a = accounts[accountId];
    final owed = a?.isOwed ?? false;
    final said = formatShort(
      owed ? -minor : minor,
      currency: a?.currency ?? Currency.mnt,
    );
    return owed ? t.ledgerOwed(said) : said;
  }

  final brought =
      record.added.length + record.joined.length + record.revived.length;
  final newlyCleared = record.matched
      .where((m) => m.before == Cleared.uncleared && !m.confirmed)
      .length;
  // Bills that were waiting for Confirm, which the file's rows paid (#597),
  // with those its rows paid in a category's bill.
  final confirmed = record.matched.where((m) => m.confirmed).length;
  final typed = record.matched.length - confirmed;
  final paid = billsPaid + (brought > 0 || typed > 0 ? confirmed : 0);
  // Rows joined to another account's own row, by that account.
  final joinedIn = <int, int>{};
  for (final j in record.joined) {
    joinedIn[j.otherAccountId] = (joinedIn[j.otherAccountId] ?? 0) + 1;
  }
  final doubt = record.doubts.firstOrNull;
  return [
    importDoneLabel(t, record),
    if (brought > 0 && newlyCleared > 0) t.importMatchedToast(newlyCleared),
    for (final MapEntry(:key, :value) in joinedIn.entries)
      t.importJoined(value, nameOf(key)),
    if (doubt != null)
      record.doubts.length == 1
          ? t.importTransferDoubt(
              nameOf(doubt.accountId),
              money(doubt.accountId, doubt.amount),
              sayDate(t, doubt.date),
              doubt.category,
            )
          : t.importTransferDoubts(
              record.doubts.length,
              nameOf(doubt.accountId),
            ),
    if (record.uncategorizedCount > 0)
      t.importUncategorizedToast(record.uncategorizedCount, uncategorized),
    if (paid > 0) t.ledgerBillsPaidCount(paid),
    if (billsToCheck > 0) t.ledgerBillsToCheck(billsToCheck),
    // Same purchase on a row taken out of the opening balance: the
    // balance followed it.
    if (record.openingFixes.lastOrNull case (_, final f)?)
      t.ledgerOpeningNow(
        money(account.id, f.move.toAmount),
        sayDate(t, f.move.toDate),
      ),
    if (record.openingMove case final o?)
      t.importOpeningMovedToast(
        sayDate(t, o.toDate),
        formatMoney(
          account.isOwed ? -o.toAmount : o.toAmount,
          currency: account.currency,
        ),
      ),
  ].join(' · ');
}

/// The import window's lines for the bills waiting for Confirm that the
/// file's rows pay (#597): each bill by name, amount, due date, the bank's
/// day and the bank's words for the row, so a withdrawal that only looks
/// like the bill can be seen before Import; past three, how many more.
List<String> importBillsPaidLines(
  Words t,
  List<ImportPlanRow> rows,
  Currency currency,
) {
  final paid = [
    for (final p in rows)
      if (p.fate == ImportFate.match && (p.match?.bill ?? false)) p,
  ];
  return [
    for (final p in paid.take(3))
      t.importBillPaid(
        p.match!.payee.trim(),
        formatMoney(p.row.amount, currency: currency),
        sayFullDate(t, p.match!.date),
        sayFullDate(t, dateOnly(p.row.date)),
        [
          p.row.payee,
          p.row.memo ?? '',
        ].map((w) => w.trim()).where((w) => w.isNotEmpty).join(' · '),
      ),
    if (paid.length > 3) t.importBillsPaidMore(paid.length - 3),
  ];
}
