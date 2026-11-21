import '../data/database.dart' show ImportRecord;
import '../domain/ledger.dart';
import '../domain/money.dart';
import 'language.dart';

// What an import did, said after it: the computer's popup and the phone's
// bar say it in the same words (#531).

/// The first thing said: the rows brought in, or, with none, the typed
/// rows the file matched. A bank row joined to the other account's row is
/// a row brought in.
String importDoneLabel(Words t, ImportRecord record) {
  final brought = record.added.length + record.joined.length;
  return brought > 0
      ? t.importDone(brought)
      : t.importMatchedToast(record.matched.length);
}

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

  final brought = record.added.length + record.joined.length;
  final newlyCleared = record.matched
      .where((m) => m.before == Cleared.uncleared)
      .length;
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
    if (billsPaid > 0) t.ledgerBillsPaidCount(billsPaid),
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
