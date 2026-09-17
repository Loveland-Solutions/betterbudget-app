import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';

import '../domain/ledger.dart';

part 'database.g.dart';

// Schema per ADR 0003: transactions are headers; entries carry the money and
// must sum to zero per transaction. Categories are income/expense accounts.

class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => textEnum<AccountType>()();
  TextColumn get currency => text().withDefault(const Constant('MNT'))();
  TextColumn get institution => text().nullable()();
  TextColumn get mask => text().nullable()();
  TextColumn get sidebarGroup => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class Payees extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

@DataClassName('TransactionRow')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Calendar date as `YYYY-MM-DD`, never a timestamp (ADR 0001).
  TextColumn get date => text()();
  IntColumn get payeeId => integer().nullable().references(Payees, #id)();
  TextColumn get memo => text().nullable()();
  TextColumn get importKey => text().nullable().unique()();
  BoolColumn get scheduled => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
}

@DataClassName('EntryRow')
class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer().references(Transactions, #id)();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('MNT'))();

  /// Decimal string from the statement's Ханш column; not money, not REAL.
  TextColumn get rate => text().nullable()();
  IntColumn get cleared => intEnum<Cleared>()();

  /// The reconcile that locked this entry, so it can be taken back later.
  IntColumn get reconciliationId =>
      integer().nullable().references(Reconciliations, #id)();
}

@DataClassName('ReconciliationRow')
class Reconciliations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  TextColumn get statementDate => text()();
  IntColumn get statementBalanceMinor => integer()();
  IntColumn get createdAt => integer()();
}

class UnbalancedTransactionException implements Exception {
  UnbalancedTransactionException(this.transactionId, this.sum);
  final int transactionId;
  final int sum;
  @override
  String toString() => 'Transaction $transactionId sums to $sum, not 0';
}

class LockedException implements Exception {
  LockedException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The cleared balance doesn't match the statement; [off] is statement
/// minus cleared.
class ReconcileMismatchException implements Exception {
  ReconcileMismatchException(this.off);
  final int off;
  @override
  String toString() => 'Off by $off';
}

/// A statement date the reconcile can't take: after today, or before the
/// account's last statement (reconciles unwind newest first).
class ReconcileDateException implements Exception {
  ReconcileDateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One reconcile's statement.
typedef Statement = ({int id, String date, int balance});

/// What a reconcile, or taking one back, changed: the statements and the
/// entries they locked. Taking back a reconcile also removes any later ones
/// that locked nothing, so there can be several statements.
class ReconcileRecord {
  const ReconcileRecord({
    required this.accountId,
    required this.statements,
    required this.entryIds,
    this.adjustmentTxnId,
  });
  final int accountId;

  /// The "Reconcile adjustment" posted to make the statement match, if any.
  /// Undo removes it along with the locks; redo brings it back.
  final int? adjustmentTxnId;

  /// Oldest first; the entries belong to the first.
  final List<Statement> statements;
  final List<int> entryIds;

  DateTime get date => parseDateKey(statements.first.date);
}

/// Everything needed to put a transaction back exactly as it was (undo).
class TxnSnapshot {
  const TxnSnapshot(this.header, this.entries);
  final TransactionRow header;
  final List<EntryRow> entries;
}

/// What [AppDatabase.moveToAccount] changed: one entry's account, and its
/// cleared state before the move.
class MoveRecord {
  const MoveRecord({
    required this.entryId,
    required this.transactionId,
    required this.fromAccountId,
    required this.toAccountId,
    required this.cleared,
  });
  final int entryId;
  final int transactionId;
  final int fromAccountId;
  final int toAccountId;
  final Cleared cleared;
}

class NotFoundException implements Exception {
  NotFoundException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// `20260917-153000`, for backup file names.
String fileStamp(DateTime n) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${n.year}${two(n.month)}${two(n.day)}-${two(n.hour)}${two(n.minute)}${two(n.second)}';
}

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDateKey(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

@DriftDatabase(
  tables: [Accounts, Payees, Transactions, Entries, Reconciliations],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'betterbudget',
              native: const DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ),
      );

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      await _backupBeforeUpgrade(from);
      // Drift doesn't wrap upgrades; a failure halfway must leave the old
      // version intact so the next launch can try again.
      await transaction(() async {
        if (from < 2) {
          await m.addColumn(entries, entries.reconciliationId);
          await linkReconciledEntries();
        }
        if (from < 3) await repairReconciledEntries();
      });
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
    },
  );

  int get _now => DateTime.now().millisecondsSinceEpoch;

  /// Copies the database next to itself before a schema upgrade, e.g.
  /// `betterbudget.before-v3-from-v2-20260917-153000.sqlite`. In-memory
  /// databases (tests) have no file and are skipped. VACUUM INTO can't run
  /// inside a transaction, so this comes first.
  Future<void> _backupBeforeUpgrade(int from) async {
    final path = await filePath();
    if (path == null) return;
    final base = path.endsWith('.sqlite')
        ? path.substring(0, path.length - '.sqlite'.length)
        : path;
    await copyTo(
      '$base.before-v$schemaVersion-from-v$from-${fileStamp(DateTime.now())}.sqlite',
    );
  }

  /// The database file, or null for an in-memory database.
  Future<String?> filePath() async {
    final rows = await customSelect('PRAGMA database_list').get();
    final path = rows
        .where((r) => r.read<String>('name') == 'main')
        .map((r) => r.read<String>('file'))
        .firstOrNull;
    return path == null || path.isEmpty ? null : path;
  }

  /// A consistent copy of everything, written to [path] (which must not
  /// exist). Safe while the app is open: SQLite takes a snapshot.
  Future<void> copyTo(String path) => customStatement('VACUUM INTO ?', [path]);

  /// Transactions that don't sum to zero or have fewer than two entries.
  /// Every write refuses to leave one (ADR 0003); a restored file must too.
  static const unbalancedSql =
      'SELECT transaction_id FROM entries GROUP BY transaction_id '
      'HAVING SUM(amount_minor) != 0 OR COUNT(*) < 2';

  /// Replaces every row with the rows in the database file at [path], in one
  /// transaction, while the app keeps this connection open. The file must
  /// already be at this schema version (open it with an [AppDatabase] first,
  /// which upgrades it). A file whose rows break a reference or leave a
  /// transaction unbalanced is refused and nothing changes. Watchers see the
  /// new ledger straight away.
  Future<void> replaceAllFrom(String path) async {
    const parentsFirst = [
      'accounts',
      'payees',
      'transactions',
      'reconciliations',
      'entries',
    ];
    // A table added to the schema must be added here, or a restore drops it.
    assert(
      {for (final t in allTables) t.actualTableName}
              .containsAll(parentsFirst) &&
          allTables.length == parentsFirst.length,
      'replaceAllFrom is missing a table',
    );
    await customStatement('ATTACH DATABASE ? AS src', [path]);
    try {
      await transaction(() async {
        for (final t in parentsFirst.reversed) {
          await customStatement('DELETE FROM main.$t');
        }
        for (final t in parentsFirst) {
          final columns = (await customSelect(
            'PRAGMA main.table_info($t)',
          ).get()).map((r) => '"${r.read<String>('name')}"').join(', ');
          await customStatement(
            'INSERT INTO main.$t ($columns) SELECT $columns FROM src.$t',
          );
        }
        final unbalanced = await customSelect(unbalancedSql).get();
        if (unbalanced.isNotEmpty) {
          throw UnbalancedTransactionException(
            unbalanced.first.read<int>('transaction_id'),
            0,
          );
        }
      });
    } finally {
      try {
        await customStatement('DETACH DATABASE src');
      } catch (e) {
        // The replace has committed or rolled back by now; a failure to
        // detach mustn't report a restore that happened as one that didn't.
        debugPrint('Detach after restore failed: $e');
      }
      markTablesUpdated(allTables);
    }
  }

  // ---------- reads ----------

  /// Re-emits the whole ledger whenever any ledger table changes.
  Stream<LedgerData> watchLedger() => customSelect(
    'SELECT 1',
    readsFrom: {accounts, payees, transactions, entries, reconciliations},
  ).watch().asyncMap((_) => loadLedger());

  Future<LedgerData> loadLedger() async {
    final accountRows = await select(accounts).get();
    final payeeNames = {
      for (final p in await select(payees).get()) p.id: p.name,
    };
    final txnRows = await (select(
      transactions,
    )..where((t) => t.deletedAt.isNull())).get();
    final entryRows = await customSelect(
      'SELECT e.* FROM entries e JOIN transactions t ON t.id = e.transaction_id '
      'WHERE t.deleted_at IS NULL',
      readsFrom: {entries, transactions},
    ).map((r) => entries.map(r.data)).get();
    final recRows = await select(reconciliations).get();

    final byTxn = <int, List<EntryData>>{};
    for (final e in entryRows) {
      byTxn
          .putIfAbsent(e.transactionId, () => [])
          .add(
            EntryData(
              id: e.id,
              accountId: e.accountId,
              amount: e.amountMinor,
              cleared: e.cleared,
              reconciliationId: e.reconciliationId,
            ),
          );
    }

    return LedgerData(
      accounts: [
        for (final a in accountRows)
          AccountInfo(
            id: a.id,
            name: a.name,
            type: a.type,
            institution: a.institution,
            mask: a.mask,
            group: a.sidebarGroup,
            sortOrder: a.sortOrder,
          ),
      ],
      txns: [
        for (final t in txnRows)
          TxnData(
            id: t.id,
            date: parseDateKey(t.date),
            payee: t.payeeId == null ? null : payeeNames[t.payeeId],
            memo: t.memo,
            scheduled: t.scheduled,
            entries: byTxn[t.id] ?? const [],
          ),
      ],
      reconciliations: [
        for (final r in recRows)
          Reconciliation(
            id: r.id,
            accountId: r.accountId,
            statementDate: parseDateKey(r.statementDate),
            balance: r.statementBalanceMinor,
          ),
      ],
    );
  }

  Future<List<String>> payeeNames() async =>
      (await (select(payees)..orderBy([(p) => OrderingTerm.asc(p.name)])).get())
          .map((p) => p.name)
          .toList();

  /// The category most recently used with this payee on [accountId], so
  /// entry becomes: payee, Tab, amount, Enter.
  Future<int?> lastCategoryFor(String payeeName, int accountId) async {
    final row = await customSelect(
      'SELECT other.account_id AS category_id FROM transactions t '
      'JOIN payees p ON p.id = t.payee_id '
      'JOIN entries mine ON mine.transaction_id = t.id AND mine.account_id = ? '
      'JOIN entries other ON other.transaction_id = t.id AND other.id != mine.id '
      'WHERE p.name = ? AND t.deleted_at IS NULL '
      'GROUP BY t.id HAVING COUNT(other.id) = 1 '
      'ORDER BY t.date DESC, t.id DESC LIMIT 1',
      variables: [Variable.withInt(accountId), Variable.withString(payeeName)],
      readsFrom: {transactions, payees, entries},
    ).getSingleOrNull();
    return row?.read<int>('category_id');
  }

  // ---------- writes ----------

  /// Writes a transaction with its entries atomically and checks zero-sum
  /// inside the same SQL transaction (ADR 0001, ADR 0003).
  Future<int> postTransaction({
    required DateTime date,
    String? payee,
    String? memo,
    bool scheduled = false,
    String? importKey,
    required List<({int accountId, int amount, Cleared cleared})> lines,
  }) {
    return transaction(() async {
      final payeeId = await _payeeId(payee);
      final now = _now;
      final txnId = await into(transactions).insert(
        TransactionsCompanion.insert(
          date: dateKey(date),
          payeeId: Value(payeeId),
          memo: Value(memo?.trim().isEmpty ?? true ? null : memo!.trim()),
          scheduled: Value(scheduled),
          importKey: Value(importKey),
          createdAt: now,
          updatedAt: now,
        ),
      );
      for (final l in lines) {
        await into(entries).insert(
          EntriesCompanion.insert(
            transactionId: txnId,
            accountId: l.accountId,
            amountMinor: l.amount,
            cleared: l.cleared,
          ),
        );
      }
      await _assertBalanced(txnId);
      return txnId;
    });
  }

  /// The everyday case: money in or out of [accountId], other side one
  /// category (or another account, which makes it a transfer).
  /// A future date makes it scheduled: it shows up but doesn't count yet.
  Future<int> postSimple({
    required int accountId,
    required DateTime date,
    required DateTime today,
    required String payee,
    required int counterAccountId,
    required int amount,
    String? memo,
  }) {
    return postTransaction(
      date: date,
      payee: payee,
      memo: memo,
      scheduled: dateOnly(date).isAfter(dateOnly(today)),
      lines: [
        (accountId: accountId, amount: amount, cleared: Cleared.uncleared),
        (
          accountId: counterAccountId,
          amount: -amount,
          cleared: Cleared.uncleared,
        ),
      ],
    );
  }

  /// Moves the category side of a two-entry transaction to [categoryId].
  Future<void> setCategory({
    required int transactionId,
    required int accountId,
    required int categoryId,
  }) {
    return transaction(() async {
      final rows = await (select(
        entries,
      )..where((e) => e.transactionId.equals(transactionId))).get();
      final others = rows.where((e) => e.accountId != accountId).toList();
      if (rows.length != 2 || others.length != 1) {
        throw NotFoundException('Not a single-category transaction');
      }
      await (update(entries)..where((e) => e.id.equals(others.single.id)))
          .write(EntriesCompanion(accountId: Value(categoryId)));
      await _touch(transactionId);
    });
  }

  /// Uncleared ⇄ cleared. Reconciled entries are locked.
  Future<void> toggleCleared(int entryId) async {
    final e = await (select(
      entries,
    )..where((e) => e.id.equals(entryId))).getSingle();
    if (e.cleared == Cleared.reconciled) return;
    final next = e.cleared == Cleared.uncleared
        ? Cleared.cleared
        : Cleared.uncleared;
    await (update(entries)..where((x) => x.id.equals(entryId))).write(
      EntriesCompanion(cleared: Value(next)),
    );
    await _touch(e.transactionId);
  }

  /// Sets cleared state on many entries at once. Reconciled entries stay
  /// locked. Returns the previous state of each entry that changed, for undo.
  Future<Map<int, Cleared>> setClearedMany(Map<int, Cleared> states) {
    return transaction(() async {
      final previous = <int, Cleared>{};
      final rows = await (select(
        entries,
      )..where((e) => e.id.isIn(states.keys))).get();
      for (final e in rows) {
        final next = states[e.id]!;
        if (e.cleared == Cleared.reconciled || e.cleared == next) continue;
        previous[e.id] = e.cleared;
        await (update(entries)..where((x) => x.id.equals(e.id))).write(
          EntriesCompanion(cleared: Value(next)),
        );
        await _touch(e.transactionId);
      }
      return previous;
    });
  }

  /// Recategorises every simple (one category) transaction in
  /// [transactionIds]; splits and transfers are left alone. Returns each
  /// changed transaction's previous category, for undo.
  Future<Map<int, int>> setCategoryMany({
    required Iterable<int> transactionIds,
    required int accountId,
    required int categoryId,
  }) {
    return transaction(() async {
      final categoryIds = {
        for (final a
            in await (select(accounts)..where(
                  (a) => a.type.isInValues([
                    AccountType.income,
                    AccountType.expense,
                  ]),
                ))
                .get())
          a.id,
      };
      final previous = <int, int>{};
      for (final id in transactionIds) {
        final rows = await (select(
          entries,
        )..where((e) => e.transactionId.equals(id))).get();
        final others = rows.where((e) => e.accountId != accountId).toList();
        if (rows.length != 2 || others.length != 1) continue;
        final other = others.single;
        if (!categoryIds.contains(other.accountId)) continue;
        if (other.accountId == categoryId) continue;
        previous[id] = other.accountId;
        await (update(entries)..where((e) => e.id.equals(other.id))).write(
          EntriesCompanion(accountId: Value(categoryId)),
        );
        await _touch(id);
      }
      return previous;
    });
  }

  /// Undo for [setCategoryMany]. Returns what it changed, as that does.
  Future<Map<int, int>> restoreCategories(
    Map<int, int> previous,
    int accountId,
  ) => transaction(() async {
    final changed = <int, int>{};
    for (final e in previous.entries) {
      changed.addAll(
        await setCategoryMany(
          transactionIds: [e.key],
          accountId: accountId,
          categoryId: e.value,
        ),
      );
    }
    return changed;
  });

  /// Soft deletes many transactions. Reconciled ones are locked, so they are
  /// skipped. Returns the ids actually deleted, for undo.
  Future<List<int>> softDeleteMany(Iterable<int> transactionIds) =>
      transaction(() async {
        final locked = await _reconciledAmong(transactionIds);
        final ids = transactionIds.where((id) => !locked.contains(id)).toList();
        await (update(transactions)..where((t) => t.id.isIn(ids))).write(
          TransactionsCompanion(deletedAt: Value(_now)),
        );
        return ids;
      });

  /// Transactions with a reconciled account-side entry: they match a bank
  /// statement. Only asset and liability entries are ever reconciled.
  Future<Set<int>> _reconciledAmong(Iterable<int> transactionIds) async {
    final rows =
        await (selectOnly(entries).join([
                innerJoin(accounts, accounts.id.equalsExp(entries.accountId)),
              ])
              ..addColumns([entries.transactionId])
              ..where(
                entries.transactionId.isIn(transactionIds) &
                    entries.cleared.equalsValue(Cleared.reconciled) &
                    accounts.type.isInValues(_reconcilable),
              ))
            .get();
    return {for (final r in rows) r.read(entries.transactionId)!};
  }

  static const _reconcilable = [AccountType.asset, AccountType.liability];

  static const _lockedMessage =
      'Reconciled · the date and amount match a bank statement';

  Future<Map<int, AccountType>> _accountTypes() async => {
    for (final a in await select(accounts).get()) a.id: a.type,
  };

  Future<void> restoreMany(Iterable<int> transactionIds) =>
      (update(transactions)..where((t) => t.id.isIn(transactionIds))).write(
        const TransactionsCompanion(deletedAt: Value(null)),
      );

  Future<TxnSnapshot> snapshot(int transactionId) async => TxnSnapshot(
    await (select(
      transactions,
    )..where((t) => t.id.equals(transactionId))).getSingle(),
    await (select(
      entries,
    )..where((e) => e.transactionId.equals(transactionId))).get(),
  );

  /// Puts back what an edit or a confirm changed: the header, and each
  /// entry's account and amount. Cleared state is left as it is now, since
  /// neither changes it and later clicks must survive. On a reconciled
  /// transaction only payee, memo and category can come back; a snapshot that
  /// would change its date, amounts or accounts is refused.
  Future<void> restoreSnapshot(TxnSnapshot s) => transaction(() async {
    if ((await _reconciledAmong([s.header.id])).isNotEmpty) {
      final now = await snapshot(s.header.id);
      final types = await _accountTypes();
      bool same(List<EntryRow> a, List<EntryRow> b) {
        final byId = {for (final e in b) e.id: e};
        return a.length == b.length &&
            a.every((e) {
              final o = byId[e.id];
              if (o == null || o.amountMinor != e.amountMinor) return false;
              // A category may change; a balance-sheet account may not.
              final sheet =
                  _reconcilable.contains(types[e.accountId]) ||
                  _reconcilable.contains(types[o.accountId]);
              return !sheet || o.accountId == e.accountId;
            });
      }

      if (now.header.date != s.header.date ||
          now.header.scheduled != s.header.scheduled ||
          now.header.deletedAt != s.header.deletedAt ||
          !same(s.entries, now.entries)) {
        throw LockedException(_lockedMessage);
      }
    }
    await (update(transactions)..where((t) => t.id.equals(s.header.id))).write(
      TransactionsCompanion(
        date: Value(s.header.date),
        payeeId: Value(s.header.payeeId),
        memo: Value(s.header.memo),
        scheduled: Value(s.header.scheduled),
        deletedAt: Value(s.header.deletedAt),
        updatedAt: Value(_now),
      ),
    );
    for (final e in s.entries) {
      await (update(entries)..where((x) => x.id.equals(e.id))).write(
        EntriesCompanion(
          accountId: Value(e.accountId),
          amountMinor: Value(e.amountMinor),
        ),
      );
    }
    await _assertBalanced(s.header.id);
  });

  /// Edits a transaction as seen from [accountId]'s register.
  ///
  /// Date, payee and memo always apply. [amount] (signed, from [accountId]'s
  /// side) and [counterAccountId] apply only to two-entry transactions; a
  /// split keeps its lines. Reconciled transactions are locked. A posted
  /// transaction moved into the future becomes scheduled.
  ///
  /// With [confirm], a scheduled transaction is confirmed in the same write,
  /// with whatever amount and date it really had (bills vary). Confirming
  /// means it happened, so the date can't be after [today].
  ///
  /// With [keepOwed] as well, money in that came short (half a salary) leaves
  /// the rest scheduled on the planned date, in the same write: same payee,
  /// memo and other side. Returns that remainder's id, or null.
  Future<int?> editTransaction({
    required int transactionId,
    required int accountId,
    required DateTime date,
    required DateTime today,
    String? payee,
    String? memo,
    int? counterAccountId,
    int? amount,
    bool confirm = false,
    bool keepOwed = false,
  }) {
    return transaction(() async {
      if (confirm && dateOnly(date).isAfter(dateOnly(today))) {
        throw LockedException('It can’t be confirmed on a future date');
      }
      final header = await (select(
        transactions,
      )..where((t) => t.id.equals(transactionId))).getSingle();
      final rows = await (select(
        entries,
      )..where((e) => e.transactionId.equals(transactionId))).get();
      final mine = rows.where((e) => e.accountId == accountId).firstOrNull;
      if (mine == null) throw NotFoundException('Not in this account');
      // A reconciled side locks the date, amounts and accounts of the whole
      // transaction, as delete does: a transfer edited from its other account
      // would change the locked side. Payee, memo and category stay editable.
      if ((await _reconciledAmong([transactionId])).isNotEmpty) {
        final others = rows.where((e) => e.id != mine.id).toList();
        final types = await _accountTypes();
        final movesAccount =
            counterAccountId != null &&
            others.length == 1 &&
            counterAccountId != others.single.accountId &&
            (_reconcilable.contains(types[counterAccountId]) ||
                _reconcilable.contains(types[others.single.accountId]));
        if (dateKey(date) != header.date ||
            (amount != null && amount != mine.amountMinor) ||
            movesAccount) {
          throw LockedException(_lockedMessage);
        }
      }

      await (update(
        transactions,
      )..where((t) => t.id.equals(transactionId))).write(
        TransactionsCompanion(
          date: Value(dateKey(date)),
          payeeId: Value(await _payeeId(payee)),
          memo: Value(memo?.trim().isEmpty ?? true ? null : memo!.trim()),
          scheduled: Value(
            !confirm &&
                (header.scheduled || dateOnly(date).isAfter(dateOnly(today))),
          ),
          updatedAt: Value(_now),
        ),
      );

      if (amount != null || counterAccountId != null) {
        final others = rows.where((e) => e.id != mine.id).toList();
        if (others.length != 1) {
          throw NotFoundException('Split lines can’t be edited yet');
        }
        final newAmount = amount ?? mine.amountMinor;
        await (update(entries)..where((e) => e.id.equals(mine.id))).write(
          EntriesCompanion(amountMinor: Value(newAmount)),
        );
        await (update(
          entries,
        )..where((e) => e.id.equals(others.single.id))).write(
          EntriesCompanion(
            accountId: Value(counterAccountId ?? others.single.accountId),
            amountMinor: Value(-newAmount),
          ),
        );
      }
      await _assertBalanced(transactionId);

      final planned = mine.amountMinor;
      final came = amount ?? planned;
      final others = rows.where((e) => e.id != mine.id).toList();
      if (!confirm ||
          !keepOwed ||
          !header.scheduled ||
          others.length != 1 ||
          planned <= 0 ||
          came <= 0 ||
          came >= planned) {
        return null;
      }
      final payeeName = header.payeeId == null
          ? null
          : (await (select(
              payees,
            )..where((p) => p.id.equals(header.payeeId!))).getSingle()).name;
      return postTransaction(
        date: parseDateKey(header.date),
        payee: payeeName,
        memo: header.memo,
        scheduled: true,
        lines: [
          (
            accountId: accountId,
            amount: planned - came,
            cleared: Cleared.uncleared,
          ),
          (
            accountId: counterAccountId ?? others.single.accountId,
            amount: came - planned,
            cleared: Cleared.uncleared,
          ),
        ],
      );
    });
  }

  /// Moves [transactionId]'s side in [fromAccountId] to [toAccountId], for a
  /// transaction entered in the wrong account. The money, date and other side
  /// stay; the moved side starts uncleared, since the other bank hasn't been
  /// checked. A transfer can't move onto its own other side, and reconciled
  /// transactions are locked. Returns what [undoMove] needs.
  Future<MoveRecord> moveToAccount({
    required int transactionId,
    required int fromAccountId,
    required int toAccountId,
  }) => transaction(() async {
    final types = await _accountTypes();
    if (!_reconcilable.contains(types[toAccountId])) {
      throw NotFoundException('Not an account');
    }
    if ((await _reconciledAmong([transactionId])).isNotEmpty) {
      throw LockedException(_lockedMessage);
    }
    final rows = await (select(
      entries,
    )..where((e) => e.transactionId.equals(transactionId))).get();
    final mine = rows.where((e) => e.accountId == fromAccountId).toList();
    if (mine.length != 1) throw NotFoundException('Not in this account');
    // An opening balance or a reconcile adjustment belongs to its account.
    if (rows.any((e) => types[e.accountId] == AccountType.equity)) {
      throw LockedException('An opening balance or adjustment stays put');
    }
    if (rows.any((e) => e.accountId == toAccountId)) {
      throw LockedException('It already moves money in that account');
    }
    final record = MoveRecord(
      entryId: mine.single.id,
      transactionId: transactionId,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      cleared: mine.single.cleared,
    );
    await _setEntryAccount(record.entryId, toAccountId, Cleared.uncleared);
    await _touch(transactionId);
    return record;
  });

  /// Undo for [moveToAccount]: back to the first account, cleared as it was.
  /// Refused if the entry has been locked or moved again since.
  Future<void> undoMove(MoveRecord m) => _replayMove(
    m,
    expectAt: m.toAccountId,
    moveTo: m.fromAccountId,
    cleared: m.cleared,
  );

  /// Redo for [moveToAccount].
  Future<void> redoMove(MoveRecord m) => _replayMove(
    m,
    expectAt: m.fromAccountId,
    moveTo: m.toAccountId,
    cleared: Cleared.uncleared,
  );

  Future<void> _replayMove(
    MoveRecord m, {
    required int expectAt,
    required int moveTo,
    required Cleared cleared,
  }) => transaction(() async {
    final e = await (select(
      entries,
    )..where((x) => x.id.equals(m.entryId))).getSingleOrNull();
    if (e == null ||
        e.accountId != expectAt ||
        (await _reconciledAmong([m.transactionId])).isNotEmpty) {
      throw LockedException('It changed since');
    }
    await _setEntryAccount(m.entryId, moveTo, cleared);
    await _touch(m.transactionId);
  });

  Future<void> _setEntryAccount(int entryId, int accountId, Cleared cleared) =>
      (update(entries)..where((e) => e.id.equals(entryId))).write(
        EntriesCompanion(accountId: Value(accountId), cleared: Value(cleared)),
      );

  /// Soft delete: nothing disappears until purged, which makes undo trivial.
  /// Reconciled transactions are locked and throw [LockedException].
  Future<void> softDelete(int transactionId) async {
    if (await softDeleteMany([transactionId]) case []) {
      throw LockedException(_lockedMessage);
    }
  }

  Future<void> restore(int transactionId) =>
      (update(transactions)..where((t) => t.id.equals(transactionId))).write(
        const TransactionsCompanion(deletedAt: Value(null)),
      );

  Future<int> addAccount({
    required String name,
    required AccountType type,
    String? institution,
    String? mask,
    String? group,
    int sortOrder = 0,
  }) => into(accounts).insert(
    AccountsCompanion.insert(
      name: name,
      type: type,
      institution: Value(institution),
      mask: Value(mask),
      sidebarGroup: Value(group),
      sortOrder: Value(sortOrder),
    ),
  );

  Future<void> addReconciliation(
    int accountId,
    DateTime statementDate,
    int balance,
  ) => into(reconciliations).insert(
    ReconciliationsCompanion.insert(
      accountId: accountId,
      statementDate: dateKey(statementDate),
      statementBalanceMinor: balance,
      createdAt: _now,
    ),
  );

  /// Locks [accountId]'s cleared entries dated on or before [statementDate]
  /// and records the statement. Refuses unless the cleared balance through
  /// that date equals [balance]. Returns what [unreconcile] and [relock] need.
  /// The date can't be after [today] or before the account's last statement.
  ///
  /// With [adjust], a statement that doesn't match is made to: the difference
  /// is posted as a cleared "Reconcile adjustment" on the statement date,
  /// against the "Balance adjustments" account (not spending), and locked
  /// with the rest.
  Future<ReconcileRecord> reconcile({
    required int accountId,
    required DateTime statementDate,
    required DateTime today,
    required int balance,
    bool adjust = false,
  }) => transaction(() async {
    final through = dateKey(dateOnly(statementDate));
    if (dateOnly(statementDate).isAfter(dateOnly(today))) {
      throw ReconcileDateException('The statement can’t be after today');
    }
    final last =
        await (selectOnly(reconciliations)
              ..addColumns([reconciliations.statementDate.max()])
              ..where(reconciliations.accountId.equals(accountId)))
            .map((r) => r.read(reconciliations.statementDate.max()))
            .getSingle();
    if (last != null && through.compareTo(last) < 0) {
      throw ReconcileDateException(
        'Already reconciled through ${last.substring(5).replaceAll('-', '.')}',
      );
    }
    final rows = await customSelect(
      'SELECT e.id, e.amount_minor, e.cleared FROM entries e '
      'JOIN transactions t ON t.id = e.transaction_id '
      'WHERE e.account_id = ? AND t.deleted_at IS NULL AND t.scheduled = 0 '
      'AND t.date <= ? AND e.cleared != ?',
      variables: [
        Variable.withInt(accountId),
        Variable.withString(through),
        Variable.withInt(Cleared.uncleared.index),
      ],
      readsFrom: {entries, transactions},
    ).get();
    final cleared = rows.fold(0, (s, r) => s + r.read<int>('amount_minor'));
    int? adjustmentTxnId;
    final adjustmentIds = <int>[];
    if (cleared != balance) {
      if (!adjust) throw ReconcileMismatchException(balance - cleared);
      adjustmentTxnId = await postTransaction(
        date: dateOnly(statementDate),
        payee: adjustmentPayee,
        lines: [
          (
            accountId: accountId,
            amount: balance - cleared,
            cleared: Cleared.cleared,
          ),
          (
            accountId: await _adjustmentsAccount(),
            amount: cleared - balance,
            cleared: Cleared.cleared,
          ),
        ],
      );
      adjustmentIds.addAll(
        await (selectOnly(entries)
              ..addColumns([entries.id])
              ..where(
                entries.transactionId.equals(adjustmentTxnId) &
                    entries.accountId.equals(accountId),
              ))
            .map((r) => r.read(entries.id)!)
            .get(),
      );
    }
    final id = await into(reconciliations).insert(
      ReconciliationsCompanion.insert(
        accountId: accountId,
        statementDate: through,
        statementBalanceMinor: balance,
        createdAt: _now,
      ),
    );
    final record = ReconcileRecord(
      accountId: accountId,
      statements: [(id: id, date: through, balance: balance)],
      entryIds: [
        for (final r in rows)
          if (r.read<int>('cleared') == Cleared.cleared.index)
            r.read<int>('id'),
        ...adjustmentIds,
      ],
      adjustmentTxnId: adjustmentTxnId,
    );
    await _lock(record);
    return record;
  });

  static const adjustmentPayee = 'Reconcile adjustment';
  static const adjustmentsAccountName = 'Balance adjustments';

  /// Equity, like opening balances: an adjustment isn't spending or income.
  Future<int> _adjustmentsAccount() async {
    final existing =
        await (select(accounts)..where(
              (a) =>
                  a.name.equals(adjustmentsAccountName) &
                  a.type.equalsValue(AccountType.equity),
            ))
            .getSingleOrNull();
    return existing?.id ??
        await addAccount(
          name: adjustmentsAccountName,
          type: AccountType.equity,
        );
  }

  /// Takes back [accountId]'s most recent reconcile that locked rows, from any
  /// session, along with any later ones that locked nothing. Its rows go back
  /// to cleared. Reconciles unwind newest first, so every lock left in place
  /// still matches its statement.
  Future<ReconcileRecord> unreconcileLast(int accountId) =>
      transaction(() async {
        final newestFirst =
            await (select(reconciliations)
                  ..where((r) => r.accountId.equals(accountId))
                  ..orderBy([
                    (r) => OrderingTerm.desc(r.statementDate),
                    (r) => OrderingTerm.desc(r.id),
                  ]))
                .get();
        if (newestFirst.isEmpty) throw NotFoundException('Never reconciled');
        final statements = <Statement>[];
        var ids = <int>[];
        for (final r in newestFirst) {
          statements.insert(0, (
            id: r.id,
            date: r.statementDate,
            balance: r.statementBalanceMinor,
          ));
          ids =
              await (selectOnly(entries)
                    ..addColumns([entries.id])
                    ..where(entries.reconciliationId.equals(r.id)))
                  .map((row) => row.read(entries.id)!)
                  .get();
          if (ids.isNotEmpty) break;
        }
        final record = ReconcileRecord(
          accountId: accountId,
          statements: statements,
          entryIds: ids,
        );
        await unreconcile(record);
        return record;
      });

  /// Undo for [reconcile]: the entries go back to cleared, and an adjustment
  /// it posted is removed.
  Future<void> unreconcile(ReconcileRecord record) => transaction(() async {
    await (update(entries)..where((e) => e.id.isIn(record.entryIds))).write(
      const EntriesCompanion(
        cleared: Value(Cleared.cleared),
        reconciliationId: Value(null),
      ),
    );
    await (delete(
      reconciliations,
    )..where((r) => r.id.isIn(record.statements.map((s) => s.id)))).go();
    if (record.adjustmentTxnId case final id?) {
      await softDeleteMany([id]);
    }
  });

  /// Redo for [reconcile], and undo for [unreconcileLast]: the same
  /// statements, and the same rows locked again.
  Future<void> relock(ReconcileRecord record) => transaction(() async {
    if (record.adjustmentTxnId case final id?) await restoreMany([id]);
    for (final s in record.statements) {
      await into(reconciliations).insert(
        ReconciliationsCompanion.insert(
          id: Value(s.id),
          accountId: record.accountId,
          statementDate: s.date,
          statementBalanceMinor: s.balance,
          createdAt: _now,
        ),
      );
    }
    await _lock(record);
  });

  Future<void> _lock(ReconcileRecord record) =>
      (update(entries)..where((e) => e.id.isIn(record.entryIds))).write(
        EntriesCompanion(
          cleared: const Value(Cleared.reconciled),
          reconciliationId: Value(record.statements.first.id),
        ),
      );

  /// Ties reconciled entries without a reconcile to the first statement on
  /// or after their date. For data written before entries remembered it.
  Future<void> linkReconciledEntries() => customStatement(
    'UPDATE entries SET reconciliation_id = ('
    'SELECT r.id FROM reconciliations r, transactions t '
    'WHERE t.id = entries.transaction_id AND r.account_id = entries.account_id '
    'AND r.statement_date >= t.date '
    'ORDER BY r.statement_date, r.id LIMIT 1) '
    'WHERE cleared = ${Cleared.reconciled.index} AND reconciliation_id IS NULL',
  );

  /// Only asset and liability entries are reconciled, and each by a
  /// statement. Data from before v3 (the demo seed included) also marked
  /// category and opening-balance sides, and some account sides with no
  /// statement; those locks could never be taken back, so they go back to
  /// cleared.
  Future<void> repairReconciledEntries() async {
    final rec = Cleared.reconciled.index, clr = Cleared.cleared.index;
    await customStatement(
      'UPDATE entries SET cleared = $clr, reconciliation_id = NULL '
      'WHERE cleared = $rec AND account_id NOT IN '
      "(SELECT id FROM accounts WHERE type IN ('asset', 'liability'))",
    );
    await customStatement(
      'UPDATE entries SET cleared = $clr '
      'WHERE cleared = $rec AND reconciliation_id IS NULL',
    );
  }

  Future<int?> _payeeId(String? name) async {
    final n = name?.trim();
    if (n == null || n.isEmpty) return null;
    final existing = await (select(
      payees,
    )..where((p) => p.name.equals(n))).getSingleOrNull();
    return existing?.id ??
        await into(payees).insert(PayeesCompanion.insert(name: n));
  }

  Future<void> _assertBalanced(int txnId) async {
    final row = await customSelect(
      'SELECT COALESCE(SUM(amount_minor), 0) AS s, COUNT(*) AS n '
      'FROM entries WHERE transaction_id = ?',
      variables: [Variable.withInt(txnId)],
    ).getSingle();
    final sum = row.read<int>('s');
    if (sum != 0 || row.read<int>('n') < 2) {
      throw UnbalancedTransactionException(txnId, sum);
    }
  }

  Future<void> _touch(int txnId) =>
      (update(transactions)..where((t) => t.id.equals(txnId))).write(
        TransactionsCompanion(updatedAt: Value(_now)),
      );
}
