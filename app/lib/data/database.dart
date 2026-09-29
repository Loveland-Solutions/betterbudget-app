import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';

import '../domain/ledger.dart';
import '../domain/pay.dart';
import 'encryption.dart';

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
  IntColumn get archivedAt => integer().nullable()();

  /// Deleted with its own rows; transfers with other accounts stay.
  IntColumn get deletedAt => integer().nullable()();

  /// An income category whose rows end the forecast (Salary, Pension; not
  /// child allowance).
  BoolColumn get payday => boolean().withDefault(const Constant(false))();

  /// What the account is for on the Savings steps (rule 25): the emergency
  /// fund, or a loan that isn't consumer debt.
  TextColumn get role => textEnum<AccountRole>().nullable()();
}

/// Small settings the user chose, by key. The Savings steps keep their
/// answers here (`ready.*`).
@DataClassName('PreferenceRow')
class Preferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('PayScheduleRow')
/// When pay comes into an account (rule 24). Its next payday is always
/// scheduled, from the plan, not from what last came.
class PaySchedules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Accounts, #id)();
  IntColumn get accountId => integer().references(Accounts, #id)();
  TextColumn get payee => text().nullable()();

  /// Positive; with [varies], the least it's likely to be.
  IntColumn get amountMinor => integer()();

  /// Twice a month: what comes on [day2] when it differs (an advance, then
  /// the rest). Null: the same both days.
  IntColumn get amount2Minor => integer().nullable()();
  BoolColumn get varies => boolean().withDefault(const Constant(false))();
  TextColumn get rule => textEnum<PayRule>()();
  IntColumn get day1 => integer().withDefault(const Constant(25))();
  IntColumn get day2 => integer().withDefault(const Constant(10))();
  IntColumn get weeks => integer().withDefault(const Constant(2))();
  TextColumn get anchor => text().nullable()();
  BoolColumn get weekendBefore => boolean().withDefault(const Constant(true))();

  /// The budget runs by this schedule's pay periods (at most one does).
  BoolColumn get definesPeriod =>
      boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
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

  /// A payday a pay schedule scheduled.
  IntColumn get payScheduleId =>
      integer().nullable().references(PaySchedules, #id)();
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

/// What a pay schedule change did, so undo and redo can replay it exactly:
/// the schedule before and after, paydays it scheduled or took away, the
/// schedule that defined the budget period before, and the payday mark.
class PayChange {
  const PayChange({
    required this.before,
    required this.after,
    required this.created,
    required this.removed,
    required this.replaced,
    required this.periodBefore,
    required this.paydayBefore,
  });
  final PayScheduleRow? before;
  final PayScheduleRow after;

  /// Paydays it scheduled, and ones of its own it took away.
  final List<int> created;
  final List<int> removed;

  /// Income the user had scheduled by hand, which the schedule took over.
  final List<int> replaced;
  final List<int> periodBefore;

  /// The category's payday mark before, or null if this didn't touch it.
  final bool? paydayBefore;
}

/// What [AppDatabase.deleteCategory] did: the category, and which entries
/// moved to [into], so undo can move them back.
class DeletedCategory {
  const DeletedCategory(this.categoryId, this.into, this.entryIds);
  final int categoryId;
  final int? into;
  final List<int> entryIds;
}

/// What [AppDatabase.deleteAccount] deleted, so undo can put it back.
class DeletedAccount {
  const DeletedAccount(this.accountId, this.transactionIds);
  final int accountId;
  final List<int> transactionIds;
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
  tables: [
    Accounts,
    PaySchedules,
    Payees,
    Transactions,
    Entries,
    Reconciliations,
    Preferences,
  ],
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

  /// The real app's entry point (ADR 0001): every connection is opened with
  /// [dataKey] applied as the SQLCipher key. A plain file left from before
  /// encryption is converted in place first. Tests and the restore
  /// candidate check open a plain or already-keyed executor directly with
  /// the constructor above instead.
  static Future<AppDatabase> openEncrypted(Uint8List dataKey) async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/betterbudget.sqlite');
    await prepareLedgerFile(file, dataKey);
    return AppDatabase(
      driftDatabase(
        name: 'betterbudget',
        native: DriftNativeOptions(
          databaseDirectory: getApplicationSupportDirectory,
          setup: (db) => applyCipherKey(db, dataKey),
        ),
      ),
    );
  }

  @override
  int get schemaVersion => 7;

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
        if (from < 4) {
          await m.addColumn(accounts, accounts.archivedAt);
          await m.addColumn(accounts, accounts.deletedAt);
        }
        if (from < 5) {
          await m.addColumn(accounts, accounts.payday);
          await m.createTable(paySchedules);
          await m.addColumn(transactions, transactions.payScheduleId);
          // Every income row ended the forecast before; nothing changes
          // until the user unmarks one.
          await customStatement(
            "UPDATE accounts SET payday = 1 WHERE type = 'income'",
          );
        }
        if (from < 6) {
          await m.addColumn(accounts, accounts.role);
          await m.createTable(preferences);
        }
        // Before v5 the table was just made, with the column already.
        if (from >= 5 && from < 7) {
          await m.addColumn(paySchedules, paySchedules.amount2Minor);
        }
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
  ///
  /// [sourceKeyBind] is the value to bind to `ATTACH ... KEY ?`: the raw-key
  /// literal (`x'...'`, from `rawKeyLiteral` in `keys.dart`) when [path] is
  /// SQLCipher-encrypted with this app's data key, `''` when it's a plain
  /// file. Once
  /// this connection has cipher pragmas set (the real, encrypted app),
  /// attaching with no `KEY` clause at all fails outright, even for a
  /// genuinely plain file — verified against the linked SQLite3 Multiple
  /// Ciphers build. Leave it null only when this connection itself has no
  /// cipher configured (tests, and any other plain executor).
  Future<void> replaceAllFrom(String path, {String? sourceKeyBind}) async {
    const parentsFirst = [
      'accounts',
      'pay_schedules',
      'payees',
      'transactions',
      'reconciliations',
      'entries',
      'preferences',
    ];
    // A table added to the schema must be added here, or a restore drops it.
    assert(
      {for (final t in allTables) t.actualTableName}
              .containsAll(parentsFirst) &&
          allTables.length == parentsFirst.length,
      'replaceAllFrom is missing a table',
    );
    try {
      if (sourceKeyBind == null) {
        await customStatement('ATTACH DATABASE ? AS src', [path]);
      } else {
        await customStatement('ATTACH DATABASE ? AS src KEY ?', [
          path,
          sourceKeyBind,
        ]);
      }
    } on Object catch (e) {
      // The error's text would include the bound key.
      throw CipherException(
        'Couldn’t open the backup to restore (${e.runtimeType})',
      );
    }
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
    readsFrom: {
      accounts,
      paySchedules,
      payees,
      transactions,
      entries,
      reconciliations,
      preferences,
    },
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
    final schedules = await select(paySchedules).get();
    final prefRows = await select(preferences).get();

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
            archived: a.archivedAt != null,
            deleted: a.deletedAt != null,
            payday: a.payday,
            role: a.role,
          ),
      ],
      prefs: {for (final p in prefRows) p.key: p.value},
      txns: [
        for (final t in txnRows)
          TxnData(
            id: t.id,
            date: parseDateKey(t.date),
            payee: t.payeeId == null ? null : payeeNames[t.payeeId],
            memo: t.memo,
            scheduled: t.scheduled,
            payScheduleId: t.payScheduleId,
            entries: byTxn[t.id] ?? const [],
          ),
      ],
      paySchedules: [
        for (final p in schedules)
          if (p.deletedAt == null) _schedule(p),
      ],
      stoppedPaySchedules: [
        for (final p in schedules)
          if (p.deletedAt != null) _schedule(p),
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
    int? payScheduleId,
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
          payScheduleId: Value(payScheduleId),
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
    return transaction(() async {
      await _assertLive(accountId);
      await _assertLive(counterAccountId);
      if (counterAccountId == accountId) {
        throw LockedException('It can’t move money to its own account');
      }
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
    });
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
                    accounts.type.isInValues(_reconcilable) &
                    // A deleted account's statements no longer lock anything.
                    accounts.deletedAt.isNull(),
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
  /// the rest scheduled on the planned date, in the same write, with the
  /// payee, memo and other side as confirmed. Never for a transfer between
  /// the user's own accounts: moving less is their own decision. Returns that
  /// remainder's id, or null.
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

      if (counterAccountId != null) await _assertLive(counterAccountId);
      if (counterAccountId == accountId) {
        throw LockedException('It can’t move money to its own account');
      }
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
      final other = counterAccountId ?? others.single.accountId;
      if (_reconcilable.contains((await _accountTypes())[other])) return null;
      return postTransaction(
        date: parseDateKey(header.date),
        payee: payee,
        memo: memo,
        scheduled: true,
        lines: [
          (
            accountId: accountId,
            amount: planned - came,
            cleared: Cleared.uncleared,
          ),
          (
            accountId: other,
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
    final target = await (select(
      accounts,
    )..where((a) => a.id.equals(toAccountId))).getSingleOrNull();
    if (!_reconcilable.contains(types[toAccountId]) ||
        target?.deletedAt != null) {
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
    bool payday = false,
  }) => into(accounts).insert(
    AccountsCompanion.insert(
      name: name,
      type: type,
      payday: Value(payday),
      institution: Value(institution),
      mask: Value(mask),
      sidebarGroup: Value(group),
      sortOrder: Value(sortOrder),
    ),
  );

  // ---------- accounts ----------

  static const openingBalancesName = 'Opening balances';

  /// The sidebar group a new or changed account goes in.
  static String groupFor(AccountType type) =>
      type == AccountType.liability ? 'Credit' : 'Cash & bank';

  /// A bank account or credit card, last in the sidebar.
  Future<int> createAccount({
    required String name,
    required AccountType type,
  }) => transaction(() async {
    final last =
        await (selectOnly(accounts)..addColumns([accounts.sortOrder.max()]))
            .map((r) => r.read(accounts.sortOrder.max()))
            .getSingle();
    return addAccount(
      name: name.trim(),
      type: type,
      group: groupFor(type),
      sortOrder: (last ?? 0) + 1,
    );
  });

  /// Marks what an account is for on the Savings steps; null clears it.
  Future<void> setAccountRole(int accountId, AccountRole? role) =>
      (update(accounts)..where((a) => a.id.equals(accountId))).write(
        AccountsCompanion(role: Value(role)),
      );

  /// Sets a preference; null removes it.
  Future<void> setPreference(String key, String? value) => value == null
      ? (delete(preferences)..where((p) => p.key.equals(key))).go()
      : into(preferences).insertOnConflictUpdate(
          PreferencesCompanion.insert(key: key, value: value),
        );

  /// Set when the user starts a new ledger, so an empty ledger stays empty
  /// instead of getting the demo data at the next launch.
  static const startedKey = 'ledger.started';

  /// Whether the user has started a ledger of their own (see [startedKey]).
  Future<bool> startedOwnLedger() async =>
      (await (select(
        preferences,
      )..where((p) => p.key.equals(startedKey))).getSingleOrNull()) !=
      null;

  /// A clean start: every account, transaction, reconcile, pay schedule,
  /// payee and setting goes, in one write. With [keepCategories] the open
  /// categories stay, with no rows in them. The caller saves a copy first.
  Future<void> startNewLedger(DateTime today, {required bool keepCategories}) =>
      transaction(() async {
        await delete(entries).go();
        await delete(reconciliations).go();
        await delete(transactions).go();
        await delete(paySchedules).go();
        await delete(payees).go();
        await delete(preferences).go();
        await (delete(accounts)..where(
              (a) => keepCategories
                  ? (a.type.isIn([
                              AccountType.income.name,
                              AccountType.expense.name,
                            ]) &
                            a.archivedAt.isNull() &
                            a.deletedAt.isNull())
                        .not()
                  : const Constant(true),
            ))
            .go();
        await setPreference(startedKey, dateKey(dateOnly(today)));
      });

  Future<void> renameAccount(int accountId, String name) =>
      (update(accounts)..where((a) => a.id.equals(accountId))).write(
        AccountsCompanion(name: Value(name.trim())),
      );

  /// Bank account ⇄ card or loan. Rows keep their amounts: a purchase lowers
  /// the balance either way. The opening balance is the exception, since it
  /// was typed in the kind's own sign ("₮640,200" in, or owed), so an
  /// unreconciled one flips with it. Changing back flips it back, which makes
  /// this its own undo. Returns whether an opening balance flipped.
  Future<bool> setAccountType(int accountId, AccountType type) {
    assert(_reconcilable.contains(type));
    return transaction(() async {
      final current = await (select(
        accounts,
      )..where((a) => a.id.equals(accountId))).getSingle();
      await (update(accounts)..where((a) => a.id.equals(accountId))).write(
        AccountsCompanion(
          type: Value(type),
          sidebarGroup: Value(groupFor(type)),
        ),
      );
      if (current.type == type) return false;
      final opening = await customSelect(
        'SELECT t.id FROM transactions t '
        'JOIN entries mine ON mine.transaction_id = t.id AND mine.account_id = ?1 '
        'JOIN entries other ON other.transaction_id = t.id AND other.id != mine.id '
        'JOIN accounts a ON a.id = other.account_id '
        'WHERE t.deleted_at IS NULL AND a.name = ?2 '
        "AND a.type = 'equity' AND mine.cleared != ?3 "
        'GROUP BY t.id HAVING COUNT(*) = 1',
        variables: [
          Variable.withInt(accountId),
          Variable.withString(openingBalancesName),
          Variable.withInt(Cleared.reconciled.index),
        ],
        readsFrom: {transactions, entries, accounts},
      ).get();
      for (final r in opening) {
        final id = r.read<int>('id');
        await customStatement(
          'UPDATE entries SET amount_minor = -amount_minor '
          'WHERE transaction_id = ?',
          [id],
        );
        await _assertBalanced(id);
        await _touch(id);
      }
      markTablesUpdated({entries});
      return opening.isNotEmpty;
    });
  }

  Future<void> setArchived(int accountId, bool archived) =>
      (update(accounts)..where((a) => a.id.equals(accountId))).write(
        AccountsCompanion(archivedAt: Value(archived ? _now : null)),
      );

  /// Deletes the account and every transaction that is only its own,
  /// reconciled or not. A transaction that also moves money in another
  /// account (a transfer) stays, so no other account's balance or statement
  /// changes; its side here stays on the deleted account, which counts
  /// nowhere. Soft, like every delete, so undo can put it all back.
  Future<DeletedAccount> deleteAccount(int accountId) => transaction(() async {
    final rows = await customSelect(
      'SELECT t.id FROM transactions t '
      'WHERE t.deleted_at IS NULL '
      'AND EXISTS (SELECT 1 FROM entries e '
      '  WHERE e.transaction_id = t.id AND e.account_id = ?1) '
      'AND NOT EXISTS (SELECT 1 FROM entries e JOIN accounts a '
      '  ON a.id = e.account_id WHERE e.transaction_id = t.id '
      "  AND a.id != ?1 AND a.type IN ('asset', 'liability') "
      '  AND a.deleted_at IS NULL)',
      variables: [Variable.withInt(accountId)],
      readsFrom: {transactions, entries, accounts},
    ).get();
    final ids = [for (final r in rows) r.read<int>('id')];
    final now = _now;
    await (update(transactions)..where((t) => t.id.isIn(ids))).write(
      TransactionsCompanion(deletedAt: Value(now)),
    );
    await (update(accounts)..where((a) => a.id.equals(accountId))).write(
      AccountsCompanion(deletedAt: Value(now)),
    );
    return DeletedAccount(accountId, ids);
  });

  // ---------- pay ----------

  PaySchedule _schedule(PayScheduleRow p) => PaySchedule(
    id: p.id,
    categoryId: p.categoryId,
    accountId: p.accountId,
    amount: p.amountMinor,
    amount2: p.amount2Minor,
    varies: p.varies,
    payee: p.payee,
    rule: p.rule,
    day1: p.day1,
    day2: p.day2,
    weeks: p.weeks,
    anchor: p.anchor == null ? null : parseDateKey(p.anchor!),
    weekendBefore: p.weekendBefore,
    definesPeriod: p.definesPeriod,
  );

  /// Marks an income category as payday (its rows end the forecast) or not.
  Future<void> setPayday(int categoryId, bool payday) => transaction(() async {
    await _assertCategory(categoryId);
    await (update(accounts)..where((a) => a.id.equals(categoryId))).write(
      AccountsCompanion(payday: Value(payday)),
    );
  });

  /// Recent paychecks in [categoryId] into [accountId], newest first: what
  /// an estimate should come from. With [scheduleId], only that schedule's
  /// own paydays once it has any (a bonus filed under Salary isn't pay).
  Future<List<int>> payHistory(
    int categoryId,
    int accountId, {
    int? scheduleId,
  }) async {
    Future<List<int>> read(bool linked) async {
      final rows = await customSelect(
        'SELECT mine.amount_minor AS amount FROM transactions t '
        'JOIN entries mine ON mine.transaction_id = t.id AND mine.account_id = ?1 '
        'JOIN entries cat ON cat.transaction_id = t.id AND cat.account_id = ?2 '
        'WHERE t.deleted_at IS NULL AND t.scheduled = 0 AND mine.amount_minor > 0 '
        '${linked ? 'AND t.pay_schedule_id = ?3 ' : ''}'
        'ORDER BY t.date DESC, t.id DESC LIMIT 6',
        variables: [
          Variable.withInt(accountId),
          Variable.withInt(categoryId),
          if (linked) Variable.withInt(scheduleId!),
        ],
        readsFrom: {transactions, entries},
      ).get();
      return [for (final r in rows) r.read<int>('amount')];
    }

    if (scheduleId != null) {
      final own = await read(true);
      if (own.isNotEmpty) return own;
    }
    return read(false);
  }

  /// Adds or changes a pay schedule. A new one marks its category payday;
  /// with [definesPeriod] the budget runs by it and no other. Paydays it had
  /// scheduled from today on are replaced by ones from the new plan, and so
  /// is income the user had scheduled by hand in that category and account
  /// within a week of the first payday (it's the same pay).
  Future<PayChange> savePaySchedule({
    int? id,
    required int categoryId,
    required int accountId,
    required int amount,
    int? amount2,
    required PayRule rule,
    required DateTime today,
    String? payee,
    bool varies = false,
    int day1 = 25,
    int day2 = 10,
    int weeks = 2,
    DateTime? anchor,
    bool weekendBefore = true,
    bool definesPeriod = false,
  }) => transaction(() async {
    await _assertCategory(categoryId);
    await _assertLive(accountId);
    if (amount <= 0 || (amount2 != null && amount2 <= 0)) {
      throw NotFoundException('Pay is money in');
    }
    // What it was before anything here is written, for undo.
    final before = id == null
        ? null
        : await (select(
            paySchedules,
          )..where((p) => p.id.equals(id))).getSingle();
    final periodBefore = await _periodIds();
    final companion = PaySchedulesCompanion(
      categoryId: Value(categoryId),
      accountId: Value(accountId),
      payee: Value(payee?.trim().isEmpty ?? true ? null : payee!.trim()),
      amountMinor: Value(amount),
      // Only twice a month has a second day, and the same twice is one.
      amount2Minor: Value(
        rule == PayRule.twiceMonthly && amount2 != amount ? amount2 : null,
      ),
      varies: Value(varies),
      rule: Value(rule),
      day1: Value(day1),
      day2: Value(day2),
      weeks: Value(weeks),
      anchor: Value(anchor == null ? null : dateKey(dateOnly(anchor))),
      weekendBefore: Value(weekendBefore),
      definesPeriod: Value(definesPeriod),
      deletedAt: const Value(null),
    );
    final sid =
        id ??
        await into(paySchedules)
            .insert(companion.copyWith(createdAt: Value(_now)));
    if (id != null) {
      await (update(
        paySchedules,
      )..where((p) => p.id.equals(id))).write(companion);
    }
    if (definesPeriod) await _onlyPeriod(sid);
    // A new schedule marks its category; an edit leaves a deliberate
    // "Not a payday" alone.
    bool? paydayBefore;
    if (id == null) {
      final c = await (select(
        accounts,
      )..where((a) => a.id.equals(categoryId))).getSingle();
      paydayBefore = c.payday;
      await (update(accounts)..where((a) => a.id.equals(categoryId))).write(
        const AccountsCompanion(payday: Value(true)),
      );
    }
    final removed = await _removeComing(sid, today);
    final created = await ensurePaydays(today, only: sid);
    final replaced = <int>[];
    if (created.isNotEmpty) {
      final first = await (select(
        transactions,
      )..where((t) => t.id.equals(created.first))).getSingle();
      final day = parseDateKey(first.date);
      String key(int n) => dateKey(DateTime(day.year, day.month, day.day + n));
      final rows = await customSelect(
        'SELECT DISTINCT t.id FROM transactions t '
        'JOIN entries mine ON mine.transaction_id = t.id AND mine.account_id = ?1 '
        'JOIN entries cat ON cat.transaction_id = t.id AND cat.account_id = ?2 '
        'WHERE t.deleted_at IS NULL AND t.scheduled = 1 '
        'AND t.pay_schedule_id IS NULL AND mine.amount_minor > 0 '
        'AND t.date BETWEEN ?3 AND ?4',
        variables: [
          Variable.withInt(accountId),
          Variable.withInt(categoryId),
          Variable.withString(key(-7)),
          Variable.withString(key(7)),
        ],
        readsFrom: {transactions, entries},
      ).get();
      replaced.addAll(rows.map((r) => r.read<int>('id')));
      await softDeleteMany(replaced);
    }
    return PayChange(
      before: before,
      after: await (select(
        paySchedules,
      )..where((p) => p.id.equals(sid))).getSingle(),
      created: created,
      removed: removed,
      replaced: replaced,
      periodBefore: periodBefore,
      paydayBefore: paydayBefore,
    );
  });

  /// Stops a pay schedule: paydays it scheduled from today on go; ones
  /// already past stay to be confirmed. The category's mark is left alone.
  Future<PayChange> stopPaySchedule(int id, DateTime today) =>
      transaction(() async {
        final before = await (select(
          paySchedules,
        )..where((p) => p.id.equals(id))).getSingle();
        final periodBefore = await _periodIds();
        final removed = await _removeComing(id, today);
        await (update(paySchedules)..where((p) => p.id.equals(id))).write(
          PaySchedulesCompanion(
            deletedAt: Value(_now),
            definesPeriod: const Value(false),
          ),
        );
        return PayChange(
          before: before,
          after: await (select(
            paySchedules,
          )..where((p) => p.id.equals(id))).getSingle(),
          created: const [],
          removed: removed,
          replaced: const [],
          periodBefore: periodBefore,
          paydayBefore: null,
        );
      });

  /// Undo for [savePaySchedule] and [stopPaySchedule]: everything back
  /// exactly as it was, the budget period included.
  Future<void> undoPayChange(PayChange c) => transaction(() async {
    final sid = c.after.id;
    await _dropPaydays(c.created);
    await _bringBackPaydays(c.removed, sid);
    await restoreMany(c.replaced);
    final before = c.before;
    if (before == null) {
      await (update(paySchedules)..where((p) => p.id.equals(sid))).write(
        PaySchedulesCompanion(
          deletedAt: Value(_now),
          definesPeriod: const Value(false),
        ),
      );
    } else {
      await update(paySchedules).replace(before);
    }
    await _setPeriodIds(c.periodBefore);
    if (c.paydayBefore case final was?) {
      await (update(accounts)..where((a) => a.id.equals(c.after.categoryId)))
          .write(AccountsCompanion(payday: Value(was)));
    }
  });

  /// Redo for [savePaySchedule] and [stopPaySchedule].
  Future<void> redoPayChange(PayChange c) => transaction(() async {
    final sid = c.after.id;
    await update(paySchedules).replace(c.after);
    if (c.after.definesPeriod) await _onlyPeriod(sid);
    if (c.paydayBefore != null) {
      await (update(accounts)..where((a) => a.id.equals(c.after.categoryId)))
          .write(const AccountsCompanion(payday: Value(true)));
    }
    await _dropPaydays(c.removed);
    await _bringBackPaydays(c.created, sid);
    await softDeleteMany(c.replaced);
  });

  /// The budget runs by [id]'s pay periods, or by month with null. Returns
  /// the schedules that defined it before (empty for month), for undo.
  Future<List<int>> setPeriodSchedule(int? id) => transaction(() async {
    final before = await _periodIds();
    await _setPeriodIds([?id]);
    return before;
  });

  Future<List<int>> _periodIds() =>
      (selectOnly(paySchedules)
            ..addColumns([paySchedules.id])
            ..where(paySchedules.definesPeriod.equals(true)))
          .map((r) => r.read(paySchedules.id)!)
          .get();

  /// Exactly [ids] define the budget period, no others.
  Future<void> _setPeriodIds(List<int> ids) async {
    await update(paySchedules)
        .write(const PaySchedulesCompanion(definesPeriod: Value(false)));
    await (update(paySchedules)..where((p) => p.id.isIn(ids))).write(
      const PaySchedulesCompanion(definesPeriod: Value(true)),
    );
  }

  Future<void> _onlyPeriod(int id) => _setPeriodIds([id]);

  /// Paydays the app takes away itself (a changed plan, an undo) are
  /// unlinked as well as deleted: only a payday the user deleted stays
  /// linked, which is how a skipped payday stays skipped.
  Future<void> dropPaydays(List<int> ids) =>
      transaction(() => _dropPaydays(ids));

  Future<void> _dropPaydays(List<int> ids) async {
    if (ids.isEmpty) return;
    await (update(transactions)..where((t) => t.id.isIn(ids))).write(
      TransactionsCompanion(
        deletedAt: Value(_now),
        payScheduleId: const Value(null),
      ),
    );
  }

  /// Undo for [dropPaydays]: back, and linked to [scheduleId] again.
  Future<void> bringBackPaydays(List<int> ids, int scheduleId) =>
      transaction(() => _bringBackPaydays(ids, scheduleId));

  Future<void> _bringBackPaydays(List<int> ids, int scheduleId) async {
    if (ids.isEmpty) return;
    await (update(transactions)..where((t) => t.id.isIn(ids))).write(
      TransactionsCompanion(
        deletedAt: const Value(null),
        payScheduleId: Value(scheduleId),
      ),
    );
  }

  /// Takes away the schedule's unconfirmed paydays dated [today] or later.
  Future<List<int>> _removeComing(int id, DateTime today) async {
    final ids =
        await (selectOnly(transactions)
              ..addColumns([transactions.id])
              ..where(
                transactions.payScheduleId.equals(id) &
                    transactions.scheduled.equals(true) &
                    transactions.deletedAt.isNull() &
                    transactions.date.isBiggerOrEqualValue(
                      dateKey(dateOnly(today)),
                    ),
              ))
            .map((r) => r.read(transactions.id)!)
            .get();
    await _dropPaydays(ids);
    return ids;
  }

  /// Keeps each pay schedule's next payday scheduled. One with nothing
  /// waiting from [today] on gets the payday after its latest planned one:
  /// confirmed (early or late, it counts as the payday it was for), still
  /// overdue, or deleted by the user (skipped: it doesn't come back). With
  /// nothing at all, from today. Returns what it scheduled, for undo.
  Future<List<int>> ensurePaydays(DateTime today, {int? only}) =>
      transaction(() async {
        final created = <int>[];
        final t = dateOnly(today);
        final todayKey = dateKey(t);
        final rows =
            await (select(paySchedules)..where(
                  (p) =>
                      p.deletedAt.isNull() &
                      (only == null ? const Constant(true) : p.id.equals(only)),
                ))
                .get();
        for (final p in rows) {
          final category = await (select(
            accounts,
          )..where((a) => a.id.equals(p.categoryId))).getSingle();
          final account = await (select(
            accounts,
          )..where((a) => a.id.equals(p.accountId))).getSingle();
          // Nothing lands in an account or category that's gone or put away.
          if (category.deletedAt != null ||
              account.deletedAt != null ||
              category.archivedAt != null ||
              account.archivedAt != null) {
            continue;
          }
          final linked = await (select(
            transactions,
          )..where((x) => x.payScheduleId.equals(p.id))).get();
          if (linked.any(
            (x) =>
                x.deletedAt == null &&
                x.scheduled &&
                x.date.compareTo(todayKey) >= 0,
          )) {
            continue;
          }
          final schedule = _schedule(p);
          // What came, for split pay: an advance confirmed late is the advance.
          Future<int?> paid(TransactionRow x) async => !schedule.split
              ? null
              : (await (select(entries)..where(
                          (e) =>
                              e.transactionId.equals(x.id) &
                              e.accountId.equals(p.accountId),
                        ))
                        .getSingleOrNull())
                    ?.amountMinor;
          final planned = [
            for (final x in linked)
              x.scheduled
                  ? parseDateKey(x.date)
                  : schedule.plannedFor(
                      parseDateKey(x.date),
                      paid: await paid(x),
                    ),
          ];
          final latest = planned.fold<DateTime?>(
            null,
            (m, d) => m == null || d.isAfter(m) ? d : m,
          );
          final yesterday = DateTime(t.year, t.month, t.day - 1);
          final from = latest == null || latest.isBefore(yesterday)
              ? yesterday
              : latest;
          final date = schedule.nextAfter(from);
          final amount = schedule.amountOn(date);
          created.add(
            await postTransaction(
              date: date,
              payee: p.payee ?? category.name,
              scheduled: true,
              payScheduleId: p.id,
              lines: [
                (
                  accountId: p.accountId,
                  amount: amount,
                  cleared: Cleared.uncleared,
                ),
                (
                  accountId: p.categoryId,
                  amount: -amount,
                  cleared: Cleared.uncleared,
                ),
              ],
            ),
          );
        }
        return created;
      });

  // ---------- categories ----------

  /// A spending category, or income with [income] (it ends forecasts).
  Future<int> createCategory(String name, {bool income = false}) => addAccount(
    name: name.trim(),
    type: income ? AccountType.income : AccountType.expense,
  );

  Future<void> setCategoryType(int categoryId, AccountType type) =>
      transaction(() async {
        if (type != AccountType.income && type != AccountType.expense) {
          throw NotFoundException('Not a category kind');
        }
        await _assertCategory(categoryId);
        await (update(accounts)..where((a) => a.id.equals(categoryId))).write(
          AccountsCompanion(type: Value(type)),
        );
      });

  /// Refuses anything but a live income or spending category: a wrong id
  /// must never move a bank account's rows.
  Future<void> _assertCategory(int id) async {
    final a = await (select(
      accounts,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (a == null ||
        a.deletedAt != null ||
        (a.type != AccountType.income && a.type != AccountType.expense)) {
      throw NotFoundException('Not a category');
    }
  }

  /// Rows filed under a category, deleted ones included.
  Future<int> categoryEntryCount(int categoryId) async {
    final n = entries.id.count();
    return (selectOnly(entries)
          ..addColumns([n])
          ..where(entries.accountId.equals(categoryId)))
        .map((r) => r.read(n)!)
        .getSingle();
  }

  /// Deletes a category. With [into], every row in it moves there first (a
  /// merge), deleted rows included so undoing their delete finds a live
  /// category. Without, it must have no rows at all, deleted ones included.
  Future<DeletedCategory> deleteCategory(int categoryId, {int? into}) =>
      transaction(() async {
        await _assertCategory(categoryId);
        final moved = <int>[];
        if (into != null) {
          if (into == categoryId) throw NotFoundException('Same category');
          await _assertCategory(into);
          moved.addAll(
            await (selectOnly(entries)
                  ..addColumns([entries.id])
                  ..where(entries.accountId.equals(categoryId)))
                .map((r) => r.read(entries.id)!)
                .get(),
          );
          await (update(entries)..where((e) => e.id.isIn(moved))).write(
            EntriesCompanion(accountId: Value(into)),
          );
          final txns =
              await (selectOnly(entries, distinct: true)
                    ..addColumns([entries.transactionId])
                    ..where(entries.id.isIn(moved)))
                  .map((r) => r.read(entries.transactionId)!)
                  .get();
          for (final t in txns) {
            await _touch(t);
          }
        } else if (await categoryEntryCount(categoryId) > 0) {
          throw LockedException('It still has rows; pick where they go');
        }
        await (update(accounts)..where((a) => a.id.equals(categoryId))).write(
          AccountsCompanion(deletedAt: Value(_now)),
        );
        return DeletedCategory(categoryId, into, moved);
      });

  /// Undo for [deleteCategory]: the category back, and its rows back in it.
  Future<void> undeleteCategory(DeletedCategory d) => transaction(() async {
    await (update(accounts)..where((a) => a.id.equals(d.categoryId))).write(
      const AccountsCompanion(deletedAt: Value(null)),
    );
    final into = d.into;
    if (into == null) return;
    await (update(entries)
          ..where((e) => e.id.isIn(d.entryIds) & e.accountId.equals(into)))
        .write(EntriesCompanion(accountId: Value(d.categoryId)));
  });

  /// Undo for adding an account: deletes it only while nothing is in it.
  /// Returns false, deleting nothing, once it holds any live row.
  Future<bool> deleteEmptyAccount(int accountId) => transaction(() async {
    final used = await customSelect(
      'SELECT 1 FROM entries e JOIN transactions t ON t.id = e.transaction_id '
      'WHERE e.account_id = ? AND t.deleted_at IS NULL LIMIT 1',
      variables: [Variable.withInt(accountId)],
      readsFrom: {entries, transactions},
    ).get();
    if (used.isNotEmpty) return false;
    await (update(accounts)..where((a) => a.id.equals(accountId))).write(
      AccountsCompanion(deletedAt: Value(_now)),
    );
    return true;
  });

  /// Refuses a deleted account as the place money goes: the UI never offers
  /// one, and nothing may land there.
  Future<void> _assertLive(int accountId) async {
    final a = await (select(
      accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (a == null || a.deletedAt != null) {
      throw NotFoundException('That account was deleted');
    }
  }

  /// Undo for [deleteAccount].
  Future<void> undeleteAccount(DeletedAccount d) => transaction(() async {
    await (update(accounts)..where((a) => a.id.equals(d.accountId))).write(
      const AccountsCompanion(deletedAt: Value(null)),
    );
    await restoreMany(d.transactionIds);
  });

  /// What was in [accountId] on [date], as a cleared opening balance: the
  /// first reconcile starts from it. [balance] is in the account's own sign
  /// (a card owing ₮500,000 is −500,000).
  Future<int> postOpeningBalance({
    required int accountId,
    required DateTime date,
    required int balance,
  }) => transaction(
    () async => postTransaction(
      date: dateOnly(date),
      lines: [
        (accountId: accountId, amount: balance, cleared: Cleared.cleared),
        (
          accountId: await _equityAccount(openingBalancesName),
          amount: -balance,
          cleared: Cleared.cleared,
        ),
      ],
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
  Future<int> _adjustmentsAccount() => _equityAccount(adjustmentsAccountName);

  Future<int> _equityAccount(String name) async {
    final existing =
        await (select(accounts)
              ..where(
                (a) =>
                    a.name.equals(name) &
                    a.type.equalsValue(AccountType.equity),
              )
              ..limit(1))
            .getSingleOrNull();
    return existing?.id ??
        await addAccount(name: name, type: AccountType.equity);
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
