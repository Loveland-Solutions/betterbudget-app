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
    this.archived = false,
    this.deleted = false,
  });

  final int id;
  final String name;
  final AccountType type;
  final String? institution;
  final String? mask;
  final String? group;
  final int sortOrder;

  /// Out of the sidebar and the account lists, still in net worth.
  final bool archived;

  /// Deleted with its own rows. What's left of it is the far side of
  /// transfers kept on other accounts, so it counts nowhere.
  final bool deleted;

  /// Accounts the user holds money in, as opposed to categories.
  bool get isBalanceSheet =>
      type == AccountType.asset || type == AccountType.liability;

  /// How other accounts' rows name it.
  String get label => deleted ? '$name (deleted)' : name;

  /// A credit account: what's owed reads as a positive amount, the way the
  /// bank shows it, and owing is never a warning.
  bool get isOwed => type == AccountType.liability;
  bool get isIncome => type == AccountType.income;
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
    this.incomeCategory = false,
    this.otherClosed = false,
    this.accountId = 0,
    this.clearedIn,
    this.balance = 0,
    this.clearedBalance = 0,
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

  /// The category is an income category (Salary), not a refund or transfer.
  final bool incomeCategory;

  /// A transfer whose other account is archived or deleted: that side stays
  /// where it is.
  final bool otherClosed;

  /// The account this row is seen from: its own register's, or in All
  /// accounts the one it belongs to.
  final int accountId;

  /// All accounts: the cleared state shown is this account's side of the
  /// transfer (less settled than the side the money left).
  final String? clearedIn;
  final int balance;

  /// Running total of cleared and reconciled rows only, in date order: what a
  /// statement's running balance should read after this row.
  final int clearedBalance;

  /// Matches a bank statement: its date, amount and accounts can't change and
  /// it can't be deleted, from either side. Payee, memo and category still
  /// can, since a statement doesn't confirm them.
  bool get locked => cleared == Cleared.reconciled || lockedIn != null;

  /// Income that ends a forecast: money in, filed under an income category.
  bool get isIncome => kind == RowKind.simple && amount > 0 && incomeCategory;

  /// The same row with another side's cleared state (All accounts).
  RegisterRow withSide({
    required int entryId,
    required Cleared cleared,
    required String clearedIn,
  }) => RegisterRow(
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
    incomeCategory: incomeCategory,
    otherClosed: otherClosed,
    accountId: accountId,
    clearedIn: clearedIn,
    balance: balance,
    clearedBalance: clearedBalance,
  );

  RegisterRow withBalance(int b, {int clearedTotal = 0}) => RegisterRow(
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
    incomeCategory: incomeCategory,
    otherClosed: otherClosed,
    accountId: accountId,
    balance: b,
    clearedBalance: clearedTotal,
  );
}

/// Uncleared this long, a row says so: longer than a card hold usually
/// lasts, so it may never have happened (cancelled, or entered twice), yet it
/// still counts in Working.
const staleUnclearedDays = 14;

/// Whole days from [date] to [today].
int daysBefore(DateTime date, DateTime today) =>
    // In UTC: across a daylight-saving change local days are 23 or 25 hours.
    DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime.utc(date.year, date.month, date.day)).inDays;

/// "not cleared for 34 days", on an uncleared row that old; otherwise null.
String? staleNote(RegisterRow r, DateTime today) {
  if (r.scheduled || r.cleared != Cleared.uncleared) return null;
  final days = daysBefore(r.date, today);
  return days >= staleUnclearedDays ? 'not cleared for $days days' : null;
}

/// "due 7 days ago" on a scheduled row past its date, which isn't in
/// Working until it's confirmed; otherwise null.
String? overdueNote(RegisterRow r, DateTime today) {
  if (!r.scheduled) return null;
  final days = daysBefore(r.date, today);
  return days <= 0
      ? null
      : (days == 1 ? 'due yesterday' : 'due $days days ago');
}

enum ReconcileCause { notCleared, datedAfter, clearedEarly }

typedef ReconcileHint = ({
  int txnId,
  DateTime date,
  String payee,
  ReconcileCause cause,
});

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

typedef CategoryUsage = ({int rows, int scheduled, DateTime? last});

typedef AccountDeletePreview = ({
  /// Rows that go with the account, and how many of those were reconciled.
  int rows,
  int reconciled,

  /// Transfers that stay, by the other account (two may share a name).
  Map<AccountInfo, int> keptOn,

  /// Scheduled transfers that stay on another account's forecast, by date.
  List<({String on, DateTime date})> keptScheduled,
});

/// Case-insensitive, so "coffee" sits beside "Coffee" and a duplicate shows.
int _byName(AccountInfo a, AccountInfo b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

class LedgerData {
  LedgerData({
    required List<AccountInfo> accounts,
    required this.txns,
    this.reconciliations = const [],
  }) : accounts = {for (final a in accounts) a.id: a};

  final Map<int, AccountInfo> accounts;
  final List<TxnData> txns;
  final List<Reconciliation> reconciliations;

  /// Every account that still exists, archived ones included: net worth.
  List<AccountInfo> get balanceSheetAccounts =>
      accounts.values.where((a) => a.isBalanceSheet && !a.deleted).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  /// The accounts in use: the sidebar, transfers and Move to.
  List<AccountInfo> get openAccounts =>
      balanceSheetAccounts.where((a) => !a.archived).toList();

  List<AccountInfo> get archivedAccounts =>
      balanceSheetAccounts.where((a) => a.archived).toList();

  /// Categories in use: the menus and the entry row.
  List<AccountInfo> get categories =>
      accounts.values
          .where((a) => a.isCategory && !a.archived && !a.deleted)
          .toList()
        ..sort(_byName);

  /// Every category a row can still be filed under, archived included: the
  /// entry row knows them all and lists only [categories].
  List<AccountInfo> get knownCategories => [
    ...categories,
    ...archivedCategories,
  ];

  List<AccountInfo> get archivedCategories =>
      accounts.values
          .where((a) => a.isCategory && a.archived && !a.deleted)
          .toList()
        ..sort(_byName);

  /// How many live rows use each category (posted, and scheduled apart),
  /// and the latest posted date: what decides whether to keep, merge or
  /// archive it.
  late final Map<int, CategoryUsage> categoryUsage = () {
    final out = <int, CategoryUsage>{};
    for (final t in txns) {
      for (final id in {
        for (final e in t.entries)
          if (accounts[e.accountId]!.isCategory) e.accountId,
      }) {
        final u = out[id] ?? (rows: 0, scheduled: 0, last: null);
        final last = u.last;
        out[id] = t.scheduled
            ? (rows: u.rows, scheduled: u.scheduled + 1, last: last)
            : (
                rows: u.rows + 1,
                scheduled: u.scheduled,
                last: last != null && !t.date.isAfter(last) ? last : t.date,
              );
      }
    }
    return out;
  }();

  /// What deleting [accountId] takes with it, worked out the way the
  /// database does it: every row that is only its own goes; a transfer with
  /// another account stays on that account.
  AccountDeletePreview deletePreview(int accountId) {
    var rows = 0, reconciled = 0;
    final kept = <int, int>{};
    final keptScheduled = <({String on, DateTime date})>[];
    for (final t in txns) {
      final mine = t.entries.where((e) => e.accountId == accountId);
      if (mine.isEmpty) continue;
      final others = {
        for (final e in t.entries)
          if (e.accountId != accountId) accounts[e.accountId]!,
      }.where((a) => a.isBalanceSheet && !a.deleted).toList();
      if (others.isEmpty) {
        rows++;
        if (mine.any((e) => e.cleared == Cleared.reconciled)) reconciled++;
      } else {
        for (final a in others) {
          kept[a.id] = (kept[a.id] ?? 0) + 1;
          if (t.scheduled) keptScheduled.add((on: a.name, date: t.date));
        }
      }
    }
    keptScheduled.sort((a, b) => a.date.compareTo(b.date));
    return (
      rows: rows,
      reconciled: reconciled,
      keptOn: {for (final e in kept.entries) accounts[e.key]!: e.value},
      keptScheduled: keptScheduled,
    );
  }

  // LedgerData is rebuilt on every database change and never mutated, so
  // what the screen asks for on each rebuild (every keystroke in search) is
  // worked out once per account and kept.
  final _balances = <int, int>{};
  final _summaries = <int, AccountSummary>{};
  final _registers =
      <int, ({List<RegisterRow> posted, List<RegisterRow> scheduled})>{};
  final _latest = <(int, bool), Reconciliation?>{};
  late final Map<int, Reconciliation> _reconciliationsById = {
    for (final r in reconciliations) r.id: r,
  };

  /// Reconciles that locked at least one entry.
  late final Set<int> _usedReconciliations = {
    for (final t in txns)
      for (final e in t.entries)
        if (e.reconciliationId != null) e.reconciliationId!,
  };

  int balanceOf(int accountId) => _balances.putIfAbsent(accountId, () {
    var sum = 0;
    for (final t in txns) {
      if (t.scheduled) continue;
      for (final e in t.entries) {
        if (e.accountId == accountId) sum += e.amount;
      }
    }
    return sum;
  });

  /// [accountId]'s most recent reconcile; with [lockedRows], the most recent
  /// that locked any, which is the one taken back first.
  Reconciliation? latestReconciliation(
    int accountId, {
    bool lockedRows = false,
  }) => _latest.putIfAbsent((accountId, lockedRows), () {
    final recs =
        reconciliations
            .where(
              (r) =>
                  r.accountId == accountId &&
                  (!lockedRows || _usedReconciliations.contains(r.id)),
            )
            .toList()
          ..sort((a, b) {
            final c = a.statementDate.compareTo(b.statementDate);
            return c != 0 ? c : a.id.compareTo(b.id);
          });
    return recs.lastOrNull;
  });

  AccountSummary summaryFor(int accountId) =>
      _summaries.putIfAbsent(accountId, () => _summary(accountId));

  AccountSummary _summary(int accountId) {
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

  /// A likely cause when a statement is [off] (statement minus cleared) from
  /// the rows cleared through [through]: one row whose amount is exactly the
  /// difference. Null when nothing matches, or when several do.
  ReconcileHint? reconcileHint(int accountId, DateTime through, int off) {
    if (off == 0) return null;
    final end = dateOnly(through);
    final found = <ReconcileHint>[];
    for (final t in txns) {
      if (t.scheduled) continue;
      for (final e in t.entries.where((e) => e.accountId == accountId)) {
        final after = t.date.isAfter(end);
        final ReconcileCause? cause = switch (e.cleared) {
          // Clearing it would close the gap.
          Cleared.uncleared when !after && e.amount == off =>
            ReconcileCause.notCleared,
          // Cleared, but dated after the statement, so not counted.
          Cleared.cleared when after && e.amount == off =>
            ReconcileCause.datedAfter,
          // Cleared here, but not at the bank yet (or entered twice).
          Cleared.cleared when !after && e.amount == -off =>
            ReconcileCause.clearedEarly,
          _ => null,
        };
        if (cause != null) {
          found.add((
            txnId: t.id,
            date: t.date,
            payee: _rowPayee(t, e),
            cause: cause,
          ));
        }
      }
    }
    return found.length == 1 ? found.single : null;
  }

  String _rowPayee(TxnData t, EntryData e) => _row(t, e).payee;

  /// Posted rows oldest first with running balances, and scheduled rows
  /// soonest first (their balance is projected on from the working balance).
  ({List<RegisterRow> posted, List<RegisterRow> scheduled}) registerFor(
    int accountId,
  ) => _registers.putIfAbsent(accountId, () => _register(accountId));

  ({List<RegisterRow> posted, List<RegisterRow> scheduled}) _register(
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
    var bal = 0, clr = 0;
    final withBal = List<RegisterRow>.unmodifiable([
      for (final r in posted)
        r.withBalance(
          bal += r.amount,
          clearedTotal: r.cleared == Cleared.uncleared ? clr : clr += r.amount,
        ),
    ]);
    // Kept and handed out on every rebuild, so nobody may reorder them.
    final projected = List<RegisterRow>.unmodifiable([
      for (final r in scheduled) r.withBalance(bal += r.amount),
    ]);
    return (posted: withBal, scheduled: projected);
  }

  /// Every account's rows in one list (All accounts), oldest first. A
  /// transfer shows once, from the side the money leaves. With [categoryId],
  /// only rows filed (wholly or as a split line) under that category.
  ({List<RegisterRow> posted, List<RegisterRow> scheduled}) registerAll({
    int? categoryId,
  }) => _allRegisters.putIfAbsent(categoryId, () => _registerAll(categoryId));

  final _allRegisters =
      <int?, ({List<RegisterRow> posted, List<RegisterRow> scheduled})>{};

  ({List<RegisterRow> posted, List<RegisterRow> scheduled}) _registerAll(
    int? categoryId,
  ) {
    final posted = <RegisterRow>[];
    final scheduled = <RegisterRow>[];
    for (final t in txns) {
      if (categoryId != null &&
          !t.entries.any((e) => e.accountId == categoryId)) {
        continue;
      }
      // An open account's side before an archived one's (it has no register
      // to edit it from), then the side money leaves.
      final sides =
          t.entries.where((e) {
            final a = accounts[e.accountId]!;
            return a.isBalanceSheet && !a.deleted;
          }).toList()..sort((a, b) {
            final x = accounts[a.accountId]!.archived ? 1 : 0;
            final y = accounts[b.accountId]!.archived ? 1 : 0;
            return x != y ? x - y : a.amount.compareTo(b.amount);
          });
      if (sides.isEmpty) continue;
      var row = _row(t, sides.first);
      // A transfer shows once, so it shows the side least settled: a card
      // payment that left the bank but hasn't reached the card reads
      // uncleared, and clearing it clears the card's side.
      if (sides.length == 2 && !t.scheduled) {
        final other = sides[1];
        if (other.cleared.index < row.cleared.index) {
          row = row.withSide(
            entryId: other.id,
            cleared: other.cleared,
            clearedIn: accounts[other.accountId]!.name,
          );
        }
      }
      (t.scheduled ? scheduled : posted).add(row);
    }
    int byDate(RegisterRow a, RegisterRow b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.txnId.compareTo(b.txnId);
    }

    return (
      posted: List.unmodifiable(posted..sort(byDate)),
      scheduled: List.unmodifiable(scheduled..sort(byDate)),
    );
  }

  /// What's filed under [categoryId], posted rows only: spent for spending
  /// (positive), received for income (positive).
  int categoryTotal(int categoryId) {
    var sum = 0;
    for (final t in txns) {
      if (t.scheduled) continue;
      for (final e in t.entries) {
        if (e.accountId == categoryId) sum += e.amount;
      }
    }
    return accounts[categoryId]?.isIncome ?? false ? -sum : sum;
  }

  RegisterRow _row(TxnData t, EntryData e) {
    final others = t.entries.where((o) => o.id != e.id).toList();
    var kind = RowKind.simple;
    var payee = t.payee ?? '';
    var label = '';
    var incomeCategory = false;
    var otherClosed = false;
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
        payee = other.label;
        label = 'Transfer';
        // Not in the account lists, so the editor can't name it again.
        otherClosed = other.archived || other.deleted;
      } else {
        label = other.name;
        categoryId = other.id;
        incomeCategory = other.type == AccountType.income;
      }
    } else {
      kind = RowKind.split;
      // Split lines in this account's sign convention, so they sum to [amount].
      lines = [
        for (final o in others)
          (name: accounts[o.accountId]!.label, amount: -o.amount),
      ];
      label = '${others.length} categories';
    }

    final rec = _reconciliationsById[e.reconciliationId];
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
      incomeCategory: incomeCategory,
      otherClosed: otherClosed,
      accountId: e.accountId,
      lockedIn: e.cleared == Cleared.reconciled
          ? null
          : others
                .where((o) => o.cleared == Cleared.reconciled)
                .map((o) => accounts[o.accountId]!)
                // A deleted account's statements no longer hold anything.
                .where((a) => a.isBalanceSheet && !a.deleted)
                .firstOrNull
                ?.name,
    );
  }
}
