// The words for what the data and domain layers report. Those layers are
// pure Dart and say what happened as a kind (an enum, a flag, a count); this
// file says it in the user's language.
import '../data/backup.dart';
import '../data/database.dart';
import '../data/encryption.dart';
import '../data/keys.dart';
import '../domain/ledger.dart';
import '../domain/pay.dart';
import 'language.dart';

/// Why a typed recovery key isn't one.
String keyProblem(Words t, KeyProblem p) => switch (p.kind) {
  KeyProblemKind.cyrillic => t.startKeyCyrillic,
  KeyProblemKind.length => t.startKeyLength(p.typed, p.total),
  KeyProblemKind.checksum => t.startKeyChecksum,
};

/// Why a file can't be restored.
String restoreProblem(Words t, RestoreProblem p) => switch (p) {
  RestoreProblem.nothingToRestoreInto => t.startRestoreNothingInto,
  RestoreProblem.newerApp => t.startRestoreNewer,
  RestoreProblem.notABackup => t.startRestoreNotABackup,
  RestoreProblem.needsKey => t.startRestoreNeedsKey,
  RestoreProblem.wrongKey => t.startRestoreWrongKey,
  RestoreProblem.damaged => t.startRestoreDamaged,
  RestoreProblem.noAccounts => t.startRestoreNoAccounts,
};

/// What went wrong opening or encrypting the ledger: a failed check in the
/// user's language, anything else as SQLite reported it.
String cipherProblem(Words t, CipherException e) => switch (e.uncheckedCopyOf) {
  final name? => t.startEncryptedCopyFailed(name),
  null => e.message,
};

/// The name of a cleared state: Uncleared, Cleared, Reconciled.
String clearedName(Words t, Cleared s) => switch (s) {
  Cleared.uncleared => t.startUncleared,
  Cleared.cleared => t.startCleared,
  Cleared.reconciled => t.startReconciled,
};

/// How other accounts' rows name [a]: "… (deleted)" once it's deleted.
String accountLabel(Words t, AccountInfo a) =>
    a.deleted ? t.startDeletedAccount(a.name) : a.name;

/// The payee a row shows: "Opening balance" when an opening balance has
/// none, "Reconcile adjustment" on one a reconcile posted, a deleted
/// account's name marked so on a transfer.
String rowPayee(Words t, RegisterRow r) {
  if (r.kind == RowKind.opening && (r.txnPayee ?? '').isEmpty) {
    return t.startOpeningBalance;
  }
  if (r.equity == AppEquity.adjustments &&
      r.txnPayee == reconcileAdjustmentPayee) {
    return t.startReconcileAdjustment;
  }
  if (r.deletedOther case final name?) return t.startDeletedAccount(name);
  return r.payee;
}

/// The category a row shows: "Transfer", "3 categories", the app's own
/// "Opening balances" or "Balance adjustments", or the name.
String rowCategory(Words t, RegisterRow r) => switch (r.kind) {
  RowKind.transfer => t.startTransfer,
  RowKind.split => t.startSplitCategories(r.splitLines.length),
  _ => switch (r.equity) {
    AppEquity.openingBalances => t.startOpeningBalances,
    AppEquity.adjustments => t.startBalanceAdjustments,
    null => r.categoryLabel,
  },
};

/// A split line's category, a deleted one marked so.
String splitLineName(Words t, SplitLine l) => switch (l.deleted) {
  final name? => t.startDeletedAccount(name),
  null => l.name,
};

/// What a forecast step is called: a transfer's other account, otherwise
/// the category.
String stepLabel(Words t, RegisterRow r) =>
    r.kind == RowKind.transfer ? rowPayee(t, r) : rowCategory(t, r);

/// "not cleared for 34 days" on an uncleared row that old; otherwise null.
String? staleNoteIn(Words t, RegisterRow r, DateTime today) =>
    switch (staleDays(r, today)) {
      final days? => t.startStaleNote(days),
      null => null,
    };

/// "due 7 days ago" on a scheduled row past its date; otherwise null.
String? overdueNoteIn(Words t, RegisterRow r, DateTime today) =>
    switch (overdueDays(r, today)) {
      1 => t.startDueYesterday,
      final days? => t.startDueDaysAgo(days),
      null => null,
    };

/// A day of the month pay comes on: "25th", `25-нд`.
String payDay(Words t, int day) =>
    t.startDayOn(PaySchedule.ordinal(day), day, day % 10 == 2 ? 'yes' : 'no');

/// When pay comes: "monthly on the 25th", "on the 10th and 25th", "every 2
/// weeks".
String payWhen(Words t, PaySchedule p) {
  switch (p.rule) {
    case PayRule.monthly:
      return t.startPayMonthly(payDay(t, p.day1));
    case PayRule.twiceMonthly:
      final a = p.day1 < p.day2 ? p.day1 : p.day2;
      final b = p.day1 < p.day2 ? p.day2 : p.day1;
      return t.startPayTwiceMonthly(payDay(t, a), payDay(t, b), a);
    case PayRule.everyWeeks:
      return p.weeks == 1 ? t.startPayEveryWeek : t.startPayEveryWeeks(p.weeks);
  }
}

/// How much and when, with [money] formatting an amount: "₮2,100,000 or
/// more monthly on the 25th", or split, "₮500,000 on the 10th and ₮1,600,000
/// on the 25th". [dotted] puts ` · ` between the amount and when.
String payAmounts(
  Words t,
  PaySchedule p,
  String Function(int) money, {
  bool dotted = false,
}) {
  if (!p.split) {
    final amount = money(p.amount), when = payWhen(t, p);
    return switch ((p.varies, dotted)) {
      (false, false) => t.startPayAmountWhen(amount, when),
      (true, false) => t.startPayAmountOrMoreWhen(amount, when),
      (false, true) => t.startPayAmountDotWhen(amount, when),
      (true, true) => t.startPayAmountOrMoreDotWhen(amount, when),
    };
  }
  final d = p.byDay;
  final first = money(d[0].amount), second = money(d[1].amount);
  final firstDay = payDay(t, d[0].day), secondDay = payDay(t, d[1].day);
  return p.varies
      ? t.startPaySplitAtLeast(first, firstDay, second, secondDay)
      : t.startPaySplit(first, firstDay, second, secondDay);
}

/// The budget span's name: "This pay period" or "This month".
String periodName(Words t, ({DateTime start, DateTime end, String label}) p) =>
    p.label == payPeriodLabel ? t.startThisPayPeriod : t.startThisMonth;

/// A refusal from the database, which gives its reason in English, in the
/// language showing. One it doesn't know stays in English.
String dbProblem(Words t, DbException e) => switch (e.problem) {
  DbProblem.reconciled => t.ledgerDbReconciled,
  DbProblem.ownAccount => t.ledgerDbOwnAccount,
  DbProblem.futureConfirm => t.ledgerDbFutureConfirm,
  DbProblem.openingStays => t.ledgerDbOpeningStays,
  DbProblem.alreadyThere => t.ledgerDbAlreadyThere,
  DbProblem.changedSince => t.ledgerDbChangedSince,
  DbProblem.stillHasRows => t.ledgerDbStillHasRows,
  DbProblem.notSingleCategory => t.ledgerDbNotSingleCategory,
  DbProblem.notInAccount => t.ledgerDbNotInAccount,
  DbProblem.notAnAccount => t.ledgerDbNotAnAccount,
  DbProblem.splitNotEditable => t.ledgerDbSplitNotEditable,
  DbProblem.payIsIn => t.ledgerDbPayIsIn,
  DbProblem.notCategoryKind => t.ledgerDbNotCategoryKind,
  DbProblem.notCategory => t.ledgerDbNotCategory,
  DbProblem.sameCategory => t.ledgerDbSameCategory,
  DbProblem.accountDeleted => t.ledgerDbAccountDeleted,
  DbProblem.neverReconciled => t.ledgerDbNeverReconciled,
  DbProblem.statementAfterToday => t.ledgerStatementAfterToday,
  DbProblem.otherCurrency => t.ledgerDbOtherCurrency,
  DbProblem.needsOtherAmount => t.ledgerDbNeedsOtherAmount,
  DbProblem.alreadyReconciledThrough => switch (e) {
    ReconcileDateException(:final through?) => t.ledgerAlreadyReconciled(
      sayDate(t, through),
    ),
    _ => e.message,
  },
};
