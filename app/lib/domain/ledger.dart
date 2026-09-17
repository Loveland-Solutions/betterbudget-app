/// Turns double-entry storage (ADR 0003) into what the register shows.
/// Pure Dart: no database, no Flutter.
library;

enum AccountType { asset, liability, income, expense, equity }

enum Cleared { uncleared, cleared, reconciled }

enum RowKind { simple, split, transfer, opening }

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class AccountInfo {
  const AccountInfo({
    required this.id,
    required this.name,
    required this.type,
    this.institution,
    this.mask,
    this.group,
    this.sortOrder = 0,
  });

  final int id;
  final String name;
  final AccountType type;
  final String? institution;
  final String? mask;
  final String? group;
  final int sortOrder;

  /// Accounts the user holds money in, as opposed to categories.
  bool get isBalanceSheet =>
      type == AccountType.asset || type == AccountType.liability;
  bool get isCategory =>
      type == AccountType.income || type == AccountType.expense;
}

class EntryData {
  const EntryData({
    required this.id,
    required this.accountId,
    required this.amount,
    this.cleared = Cleared.uncleared,
    this.reconciliationId,
  });

  final int id;
  final int accountId;

  /// The reconcile that locked this entry.
  final int? reconciliationId;

  /// Signed minor units from the perspective of [accountId].
  final int amount;
  final Cleared cleared;
}

class TxnData {
  const TxnData({
    required this.id,
    required this.date,
    required this.entries,
    this.payee,
    this.memo,
    this.scheduled = false,
  });

  final int id;
  final DateTime date;
  final String? payee;
  final String? memo;

  /// Pending: not yet happened or not yet confirmed. Excluded from balances.
  final bool scheduled;
  final List<EntryData> entries;
}

class Reconciliation {
  const Reconciliation({
    this.id = 0,
    required this.accountId,
    required this.statementDate,
    required this.balance,
  });

  final int id;
  final int accountId;
  final DateTime statementDate;
  final int balance;
}

class RegisterRow {
  const RegisterRow({
    required this.txnId,
    required this.entryId,
    required this.date,
    required this.payee,
    required this.memo,
    required this.amount,
    required this.cleared,
    required this.scheduled,
    required this.kind,
    required this.categoryLabel,
    required this.categoryId,
    required this.splitLines,
    this.txnPayee,
    this.lockedIn,
    this.reconciledOn,
    this.latestReconcile = false,
    this.balance = 0,
  });

  final int txnId;
  final int entryId;
  final DateTime date;
  final String payee;
  final String memo;
  final int amount;
  final Cleared cleared;
  final bool scheduled;
  final RowKind kind;
  final String categoryLabel;

  /// Set only for simple rows, where the category can be edited inline.
  final int? categoryId;
  final List<({String name, int amount})> splitLines;

  /// The payee as stored. [payee] is what the row shows, which for a
  /// transfer is the other account.
  final String? txnPayee;

  /// A transfer reconciled on the other account's side: this side can still
  /// be cleared, but not edited or deleted. Names that account.
  final String? lockedIn;

  /// The statement date of the reconcile that locked this row, if known.
  final DateTime? reconciledOn;

  /// Locked by the account's most recent reconcile, which can be taken back.
  final bool latestReconcile;
  final int balance;

  /// Can't be edited or deleted, from either side.
  bool get locked => cleared == Cleared.reconciled || lockedIn != null;

  bool get isIncome => kind == RowKind.simple && amount > 0;

  RegisterRow withBalance(int b) => RegisterRow(
    txnId: txnId,
    entryId: entryId,
    date: date,
    payee: payee,
    memo: memo,
    amount: amount,
    cleared: cleared,
    scheduled: scheduled,
    kind: kind,
    categoryLabel: categoryLabel,
    categoryId: categoryId,
    splitLines: splitLines,
    txnPayee: txnPayee,
    lockedIn: lockedIn,
    reconciledOn: reconciledOn,
    latestReconcile: latestReconcile,
    balance: b,
  );
}

class AccountSummary {
  const AccountSummary({
    required this.working,
    required this.cleared,
    this.unclearedCount = 0,
    this.reconciledOn,
  });

  final int working;
  final int cleared;
  final int unclearedCount;

  /// Not settled at the bank yet: why working and cleared differ.
  int get uncleared => working - cleared;

  /// Date of the last statement reconciled against.
  final DateTime? reconciledOn;
}

class LedgerData {
  LedgerData({
    required List<AccountInfo> accounts,
    required this.txns,
    this.reconciliations = const [],
  }) : accounts = {for (final a in accounts) a.id: a};

  final Map<int, AccountInfo> accounts;
  final List<TxnData> txns;
  final List<Reconciliation> reconciliations;

  List<AccountInfo> get balanceSheetAccounts =>
      accounts.values.where((a) => a.isBalanceSheet).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  List<AccountInfo> get categories =>
      accounts.values.where((a) => a.isCategory).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  int balanceOf(int accountId) {
    var sum = 0;
    for (final t in txns) {
      if (t.scheduled) continue;
      for (final e in t.entries) {
        if (e.accountId == accountId) sum += e.amount;
      }
    }
    return sum;
  }

  /// [accountId]'s most recent reconcile; with [lockedRows], the most recent
  /// that locked any, which is the one taken back first.
  Reconciliation? latestReconciliation(
    int accountId, {
    bool lockedRows = false,
  }) {
    final used = lockedRows
        ? {
            for (final t in txns)
              for (final e in t.entries)
                if (e.reconciliationId != null) e.reconciliationId,
          }
        : null;
    final recs =
        reconciliations
            .where(
              (r) =>
                  r.accountId == accountId &&
                  (used == null || used.contains(r.id)),
            )
            .toList()
          ..sort((a, b) {
            final c = a.statementDate.compareTo(b.statementDate);
            return c != 0 ? c : a.id.compareTo(b.id);
          });
    return recs.lastOrNull;
  }

  AccountSummary summaryFor(int accountId) {
    var working = 0, cleared = 0, unclearedCount = 0;
    for (final t in txns) {
      if (t.scheduled) continue;
      for (final e in t.entries.where((e) => e.accountId == accountId)) {
        working += e.amount;
        if (e.cleared == Cleared.uncleared) unclearedCount++;
        if (e.cleared != Cleared.uncleared) {
          cleared += e.amount;
        }
      }
    }
    return AccountSummary(
      working: working,
      cleared: cleared,
      unclearedCount: unclearedCount,
      reconciledOn: latestReconciliation(accountId)?.statementDate,
    );
  }

  /// What the bank should show on [date] if the cleared rows are right:
  /// cleared and reconciled entries dated on or before it.
  ({int balance, int toLock}) clearedThrough(int accountId, DateTime date) {
    var balance = 0, toLock = 0;
    final through = dateOnly(date);
    for (final t in txns) {
      if (t.scheduled || t.date.isAfter(through)) continue;
      for (final e in t.entries.where((e) => e.accountId == accountId)) {
        if (e.cleared == Cleared.uncleared) continue;
        balance += e.amount;
        if (e.cleared == Cleared.cleared) toLock++;
      }
    }
    return (balance: balance, toLock: toLock);
  }

  /// Posted rows oldest first with running balances, and scheduled rows
  /// soonest first (their balance is projected on from the working balance).
  ({List<RegisterRow> posted, List<RegisterRow> scheduled}) registerFor(
    int accountId,
  ) {
    final posted = <RegisterRow>[];
    final scheduled = <RegisterRow>[];
    for (final t in txns) {
      for (final e in t.entries.where((e) => e.accountId == accountId)) {
        (t.scheduled ? scheduled : posted).add(_row(t, e));
      }
    }
    int byDate(RegisterRow a, RegisterRow b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.txnId.compareTo(b.txnId);
    }

    posted.sort(byDate);
    scheduled.sort(byDate);
    var bal = 0;
    final withBal = [for (final r in posted) r.withBalance(bal += r.amount)];
    final projected = [
      for (final r in scheduled) r.withBalance(bal += r.amount),
    ];
    return (posted: withBal, scheduled: projected);
  }

  RegisterRow _row(TxnData t, EntryData e) {
    final others = t.entries.where((o) => o.id != e.id).toList();
    var kind = RowKind.simple;
    var payee = t.payee ?? '';
    var label = '';
    int? categoryId;
    var lines = <({String name, int amount})>[];

    if (others.length == 1) {
      final other = accounts[others.single.accountId]!;
      if (other.type == AccountType.equity) {
        kind = RowKind.opening;
        payee = payee.isEmpty ? 'Opening balance' : payee;
        label = other.name;
      } else if (other.isBalanceSheet) {
        kind = RowKind.transfer;
        payee = other.name;
        label = 'Transfer';
      } else {
        label = other.name;
        categoryId = other.id;
      }
    } else {
      kind = RowKind.split;
      // Split lines in this account's sign convention, so they sum to [amount].
      lines = [
        for (final o in others)
          (name: accounts[o.accountId]!.name, amount: -o.amount),
      ];
      label = '${others.length} categories';
    }

    final rec = e.reconciliationId == null
        ? null
        : reconciliations.where((r) => r.id == e.reconciliationId).firstOrNull;
    return RegisterRow(
      reconciledOn: rec?.statementDate,
      latestReconcile:
          rec != null &&
          latestReconciliation(e.accountId, lockedRows: true)?.id == rec.id,
      txnId: t.id,
      entryId: e.id,
      date: t.date,
      payee: payee,
      memo: t.memo ?? '',
      amount: e.amount,
      cleared: e.cleared,
      scheduled: t.scheduled,
      kind: kind,
      categoryLabel: label,
      categoryId: categoryId,
      splitLines: lines,
      txnPayee: t.payee,
      lockedIn: e.cleared == Cleared.reconciled
          ? null
          : others
                .where((o) => o.cleared == Cleared.reconciled)
                .map((o) => accounts[o.accountId]!)
                .where((a) => a.isBalanceSheet)
                .firstOrNull
                ?.name,
    );
  }
}
