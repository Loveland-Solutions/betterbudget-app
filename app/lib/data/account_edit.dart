// An account's Edit… (owner, 2026-11-21: "'Edit...' is what's expected in a
// program"): its name, whether it is a bank account or a card or loan, a
// card's interest rate and the category its payments come out of, written
// together as one change, on the computer and the phone alike.
import '../domain/budget.dart' show BudgetKeys;
import '../domain/ledger.dart' show AccountType;
import '../domain/readiness.dart' show ReadyKeys;
import 'database.dart' show AppDatabase, DbProblem, NotFoundException;

/// What Edit… holds when Save is pressed: the whole state, not what changed.
/// [rate] is a card's or loan's rate as Savings keeps it (`DebtRate.value`),
/// null for none; [loan] the category its payments come out of, null for
/// none. Both are left as they were on a bank account.
typedef AccountEdit = ({String name, bool owed, String? rate, int? loan});

/// What an edit did: undo and redo, and whether an opening balance flipped
/// with the kind.
typedef AccountEdited = ({
  Future<void> Function() undo,
  Future<void> Function() redo,
  bool flipped,
});

/// Writes [e] for [accountId] as one change. Throws [NotFoundException] when
/// the account has gone (deleted on another computer since).
Future<AccountEdited> editAccount(
  AppDatabase db,
  int accountId,
  AccountEdit e,
) async {
  final data = await db.loadLedger();
  final a = data.accounts[accountId];
  if (a == null || a.deleted) {
    throw NotFoundException(DbProblem.accountDeleted);
  }
  final name = e.name.trim();
  final oldName = a.name;
  final renamed = name.isNotEmpty && name != oldName;
  final oldType = a.type;
  final newType = e.owed ? AccountType.liability : AccountType.asset;
  final kind = a.isOwed != e.owed;
  final rateKey = ReadyKeys.rate(accountId);
  final loanKey = '${BudgetKeys.loanPrefix}$accountId';
  final rateWas = data.prefs[rateKey], loanWas = data.prefs[loanKey];
  // A bank account has neither: what a card had stays for if it goes back.
  final rateNow = e.owed ? e.rate : rateWas;
  final loanNow = e.owed ? e.loan?.toString() : loanWas;
  var flipped = false;

  Future<void> write() => db.transaction(() async {
    if (renamed) await db.renameAccount(accountId, name);
    if (kind) flipped = await db.setAccountType(accountId, newType);
    if (rateNow != rateWas) await db.setPreference(rateKey, rateNow);
    if (loanNow != loanWas) await db.setPreference(loanKey, loanNow);
  });

  await write();
  return (
    flipped: flipped,
    undo: () => db.transaction(() async {
      if (loanNow != loanWas) await db.setPreference(loanKey, loanWas);
      if (rateNow != rateWas) await db.setPreference(rateKey, rateWas);
      if (kind) await db.setAccountType(accountId, oldType);
      if (renamed) await db.renameAccount(accountId, oldName);
    }),
    redo: write,
  );
}
