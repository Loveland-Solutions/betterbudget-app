import '../domain/ledger.dart';
import '../domain/money.dart';
import 'data_words.dart';
import 'language.dart';

// What archiving or deleting an account leaves behind, said exactly (owner,
// 2026-09-18: warn, don't block), for the computer's sidebar and the phone.

/// A line said in the reader's language, for lists built where there's no
/// [BuildContext] to ask for the words.
typedef Say = String Function(Words t);

/// Whole tugrik, with the fraction only when there is one: a ₮0.40 leftover
/// mustn't read as ₮0.
String accountMoney(int v, [Currency currency = Currency.mnt]) =>
    formatShort(v, currency: currency);

/// What an account's balance is, in words that fit its kind and sign.
String balanceWords(Words t, AccountInfo a, int balance) => a.isOwed
    ? (balance <= 0
          ? t.setupOwedStill(accountMoney(-balance, a.currency))
          : t.setupInCredit(accountMoney(balance, a.currency)))
    : (balance >= 0
          ? t.setupStillIn(accountMoney(balance, a.currency))
          : t.setupOverdrawn(accountMoney(-balance, a.currency)));

/// What archiving leaves behind, or nothing if it leaves nothing.
List<Say> archiveWarnings(
  AccountInfo a,
  int balance,
  List<RegisterRow> scheduled,
) {
  String list(Words t, Iterable<RegisterRow> rows) =>
      '${rows.take(3).map((r) => '${rowPayee(t, r)} ${sayDate(t, r.date)}').join(', ')}'
      '${rows.length > 3 ? ', …' : ''}';
  final own = scheduled.where((r) => r.kind != RowKind.transfer).toList();
  // A scheduled transfer still shows on the other account, as money coming
  // or going there.
  final transfers = scheduled.where((r) => r.kind == RowKind.transfer).toList();
  return [
    if (balance != 0) (t) => t.setupArchiveBalance(balanceWords(t, a, balance)),
    if (own.isNotEmpty)
      (t) => t.setupArchiveScheduled(own.length, list(t, own)),
    if (transfers.isNotEmpty)
      (t) => t.setupArchiveTransfers(transfers.length, list(t, transfers)),
  ];
}

List<Say> deleteWarnings(AccountInfo a, int balance, AccountDeletePreview p) {
  String rows(Words t) => p.rows == 0
      ? t.setupDeleteNoRows
      : p.reconciled == 0
      ? t.setupDeleteRows(p.rows)
      : t.setupDeleteRowsReconciled(p.rows, p.reconciled);
  // Net worth loses the account's balance: an asset takes it down, a debt
  // no longer counted takes it up.
  final Say? worth = balance == 0
      ? null
      : (t) => balance > 0
            ? t.setupWorthDown(accountMoney(balance.abs(), a.currency))
            : a.isOwed
            ? t.setupWorthUpOwed(accountMoney(balance.abs(), a.currency))
            : t.setupWorthUp(accountMoney(balance.abs(), a.currency));
  final pending = p.keptScheduled;
  final Say? pendingLine = pending.isEmpty
      ? null
      : (t) => t.setupDeletePending(
          pending.length,
          '${pending.take(3).map((k) => '${k.on} ${sayDate(t, k.date)}').join(', ')}'
          '${pending.length > 3 ? ', …' : ''}',
        );
  final kept = p.keptOn.entries.toList();
  final Say? keptLine = switch (kept.length) {
    0 => null,
    1 => (t) => t.setupKeptOne(
      kept.single.value,
      kept.single.key.name,
      t.startDeletedAccount(a.name),
    ),
    _ => (t) => t.setupKeptMany(
      t.startDeletedAccount(a.name),
      kept.map((e) => t.setupKeptOn(e.value, e.key.name)).join(', '),
    ),
  };
  return [rows, ?worth, ?keptLine, ?pendingLine];
}

/// What changing [a]'s type to a card or loan ([toOwed]) or back does, said
/// before Save with the real numbers: its opening balance turning round and
/// Net worth before and after, or that nothing it holds changes. Null when
/// the type isn't changing.
String? accountKindSays(Words t, LedgerData data, AccountInfo a, bool toOwed) {
  if (toOwed == a.isOwed) return null;
  final flip = openingThatFlips(data, a.id);
  final before =
      data.balancesByCurrency(data.balanceSheetAccounts)[a.currency] ?? 0;
  String money(int v) => formatMoney(v, currency: a.currency);
  if (flip == 0) {
    return toOwed
        ? t.accountToOwed(a.name, money(before))
        : t.accountToBank(a.name, money(before));
  }
  final after = before - 2 * flip;
  final amount = accountMoney(flip.abs(), a.currency);
  return toOwed
      ? t.accountToOwedFlips(a.name, amount, money(before), money(after))
      : t.accountToBankFlips(a.name, amount, money(before), money(after));
}
