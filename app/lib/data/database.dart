import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
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

/// Everything needed to put a transaction back exactly as it was (undo).
class TxnSnapshot {
  const TxnSnapshot(this.header, this.entries);
  final TransactionRow header;
  final List<EntryRow> entries;
}

class NotFoundException implements Exception {
  NotFoundException(this.message);
  final String message;
  @override
  String toString() => message;
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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
    },
  );

  int get _now => DateTime.now().millisecondsSinceEpoch;

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

  /// Undo for [setCategoryMany].
  Future<void> restoreCategories(Map<int, int> previous, int accountId) =>
      transaction(() async {
        for (final e in previous.entries) {
          await setCategoryMany(
            transactionIds: [e.key],
            accountId: accountId,
            categoryId: e.value,
          );
        }
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

  /// Transactions with any reconciled entry: they match a bank statement.
  Future<Set<int>> _reconciledAmong(Iterable<int> transactionIds) async {
    final rows =
        await (selectOnly(entries)
              ..addColumns([entries.transactionId])
              ..where(
                entries.transactionId.isIn(transactionIds) &
                    entries.cleared.equalsValue(Cleared.reconciled),
              ))
            .get();
    return {for (final r in rows) r.read(entries.transactionId)!};
  }

  Future<void> restoreMany(Iterable<int> transactionIds) =>
      (update(transactions)..where((t) => t.id.isIn(transactionIds))).write(
        const TransactionsCompanion(deletedAt: Value(null)),
      );

  /// Posts a scheduled transaction. Confirming means "this happened", so one
  /// confirmed ahead of its date is posted on [today], never in the future.
  Future<void> confirmScheduled(int transactionId, DateTime today) async {
    final t = await (select(
      transactions,
    )..where((t) => t.id.equals(transactionId))).getSingle();
    final due = parseDateKey(t.date);
    await (update(
      transactions,
    )..where((t) => t.id.equals(transactionId))).write(
      TransactionsCompanion(
        scheduled: const Value(false),
        date: due.isAfter(dateOnly(today))
            ? Value(dateKey(dateOnly(today)))
            : const Value.absent(),
        updatedAt: Value(_now),
      ),
    );
  }

  Future<TxnSnapshot> snapshot(int transactionId) async => TxnSnapshot(
    await (select(
      transactions,
    )..where((t) => t.id.equals(transactionId))).getSingle(),
    await (select(
      entries,
    )..where((e) => e.transactionId.equals(transactionId))).get(),
  );

  Future<void> restoreSnapshot(TxnSnapshot s) => transaction(() async {
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
          cleared: Value(e.cleared),
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
  Future<void> editTransaction({
    required int transactionId,
    required int accountId,
    required DateTime date,
    required DateTime today,
    String? payee,
    String? memo,
    int? counterAccountId,
    int? amount,
  }) {
    return transaction(() async {
      final header = await (select(
        transactions,
      )..where((t) => t.id.equals(transactionId))).getSingle();
      final rows = await (select(
        entries,
      )..where((e) => e.transactionId.equals(transactionId))).get();
      final mine = rows.where((e) => e.accountId == accountId).firstOrNull;
      if (mine == null) throw NotFoundException('Not in this account');
      if (mine.cleared == Cleared.reconciled) {
        throw LockedException('Reconciled transactions are locked');
      }

      await (update(
        transactions,
      )..where((t) => t.id.equals(transactionId))).write(
        TransactionsCompanion(
          date: Value(dateKey(date)),
          payeeId: Value(await _payeeId(payee)),
          memo: Value(memo?.trim().isEmpty ?? true ? null : memo!.trim()),
          scheduled: Value(
            header.scheduled || dateOnly(date).isAfter(dateOnly(today)),
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
    });
  }

  /// Soft delete: nothing disappears until purged, which makes undo trivial.
  /// Reconciled transactions are locked and throw [LockedException].
  Future<void> softDelete(int transactionId) async {
    if (await softDeleteMany([transactionId]) case []) {
      throw LockedException('Reconciled transactions are locked');
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
