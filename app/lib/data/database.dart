import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';

import '../domain/budget.dart' show Budget;
import '../domain/ledger.dart';
import '../domain/money.dart';
import '../domain/pay.dart';
import '../import/mapping.dart';
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

  /// Unused since v13: there's one income category, and its rows end the
  /// forecast.
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

  /// A weekend payday stays on its day, whatever [weekendBefore] says (v9).
  BoolColumn get weekendKeep => boolean().withDefault(const Constant(false))();

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

  /// Unused since v8: the key is on each account's entry.
  TextColumn get importKey => text().nullable().unique()();
  BoolColumn get scheduled => boolean().withDefault(const Constant(false))();

  /// A payday a pay schedule scheduled.
  IntColumn get payScheduleId =>
      integer().nullable().references(PaySchedules, #id)();

  /// A bill a category's plan scheduled (rule 27), by the category.
  IntColumn get planCategoryId =>
      integer().nullable().references(Accounts, #id)();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
}

@DataClassName('EntryRow')
@TableIndex(name: 'entries_import_key', columns: {#importKey}, unique: true)
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

  /// The bank row this entry came from or was matched to (ADR 0002). On the
  /// entry, not the transaction, so each side of a transfer matches its own
  /// bank's file. Unique through `entries_import_key` (SQLite can't add a
  /// unique column to a table that exists).
  TextColumn get importKey => text().nullable()();
}

@DataClassName('ReconciliationRow')
class Reconciliations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  TextColumn get statementDate => text()();
  IntColumn get statementBalanceMinor => integer()();
  IntColumn get createdAt => integer()();
}

/// Money put into a spending category for a budget period (rule 26). Keyed
/// by the day the period starts; a category's balance is every amount put
/// in less what it spent since the budget began, so switching between
/// months and pay periods loses nothing. A merge can leave two for the same
/// category and day, and they add up.
@DataClassName('BudgetAmountRow')
class BudgetAmounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Accounts, #id)();

  /// Calendar date as `YYYY-MM-DD`: the first day of its period.
  TextColumn get date => text()();

  /// Negative takes money back out.
  IntColumn get amountMinor => integer()();
}

/// A spending category's plan (rule 27): what it's for, and so how much
/// it should be assigned each period. One per category.
@DataClassName('CategoryPlanRow')
class CategoryPlans extends Table {
  IntColumn get categoryId => integer().references(Accounts, #id)();
  TextColumn get kind => textEnum<PlanKind>()();

  /// Each period's amount, or the amount wanted by the date, by [kind].
  IntColumn get amountMinor => integer()();

  /// Calendar date as `YYYY-MM-DD`: the day the plan was made.
  TextColumn get start => text()();

  /// The date, or the first of them when it repeats.
  TextColumn get due => text().nullable()();

  /// It comes again every this many months; null unless by months.
  IntColumn get everyMonths => integer().nullable()();

  /// Every this many days (7 a week); null unless by days (v15).
  IntColumn get everyDays => integer().nullable()();

  /// On these dates each year, `MM-DD,MM-DD`; null unless so (v15).
  TextColumn get onDates => text().nullable()();

  /// Every payday of this schedule, [daysAfterPay] days after (v15).
  IntColumn get payScheduleId =>
      integer().nullable().references(PaySchedules, #id)();
  IntColumn get daysAfterPay => integer().withDefault(const Constant(0))();

  /// A date on a weekend: before, after or keep (v15).
  TextColumn get weekend =>
      textEnum<PayWeekend>().withDefault(const Constant('keep'))();

  /// Every so many weeks, on these weekdays, `1,4` (Monday 1); null
  /// unless chosen (v16, Custom…).
  TextColumn get weekdays => text().nullable()();

  /// Every so many months: the nth weekday of the month (1–4, -1 the
  /// last) and which weekday (Monday 1); null unless chosen (v16).
  IntColumn get nth => integer().nullable()();
  IntColumn get nthWeekday => integer().nullable()();

  /// No bill after this date `YYYY-MM-DD`, or after this many (v16).
  TextColumn get endDate => text().nullable()();
  IntColumn get endCount => integer().nullable()();

  /// Each period: what's left stays in the category.
  BoolColumn get rollover => boolean().withDefault(const Constant(true))();

  /// Each period, carrying over: stop asking once it holds this much.
  IntColumn get upToMinor => integer().nullable()();

  /// The account a dated plan's bill is paid from: it's kept scheduled
  /// there.
  IntColumn get paidFromId => integer().nullable().references(Accounts, #id)();

  @override
  Set<Column> get primaryKey => {categoryId};
}

/// An account a spending category doesn't use (rule 28). A category uses
/// every account in its currency unless it has a row here, so a new
/// account is used by all of them.
@DataClassName('CategoryAccountOffRow')
class CategoryAccountsOff extends Table {
  IntColumn get categoryId => integer().references(Accounts, #id)();
  IntColumn get accountId => integer().references(Accounts, #id)();

  @override
  Set<Column> get primaryKey => {categoryId, accountId};
}

/// What [AppDatabase.setCategoryMoney] replaced, so undo can put it back:
/// the category's currency and unchecked accounts, and what a change of
/// currency took away (its amounts and its plan).
class CategoryMoney {
  const CategoryMoney({
    required this.currency,
    required this.off,
    this.amounts = const [],
    this.plan,
  });
  final Currency currency;
  final Set<int> off;
  final List<BudgetAmount> amounts;
  final CategoryPlan? plan;
}

class UnbalancedTransactionException implements Exception {
  UnbalancedTransactionException(this.transactionId, this.sum);
  final int transactionId;
  final int sum;
  @override
  String toString() => 'Transaction $transactionId sums to $sum, not 0';
}

/// Why a write was refused, as a code the UI words in the chosen language;
/// [english] is the plain message, kept for logs and tests.
enum DbProblem {
  reconciled('Reconciled · the date and amount match a bank statement'),
  ownAccount('It can’t move money to its own account'),
  futureConfirm('It can’t be confirmed on a future date'),
  openingStays('An opening balance or adjustment stays put'),
  alreadyThere('It already moves money in that account'),
  changedSince('It changed since'),
  stillHasRows('It still has rows; pick where they go'),
  notSingleCategory('Not a single-category transaction'),
  notInAccount('Not in this account'),
  notAnAccount('Not an account'),
  splitNotEditable('Split lines can’t be edited yet'),
  payIsIn('Pay is money in'),
  notCategory('Not a category'),
  sameCategory('Same category'),
  accountDeleted('That account was deleted'),
  neverReconciled('Never reconciled'),
  statementAfterToday('The statement can’t be after today'),
  otherCurrency('That account is in another currency'),
  needsOtherAmount('Say what arrives in the other currency'),

  /// With the last statement's date as the exception's `through`, and in
  /// English, `09.30`, as its detail.
  alreadyReconciledThrough('Already reconciled through');

  const DbProblem(this.english);
  final String english;
}

/// A refused write: its [problem], and for some a [detail] such as a date.
abstract class DbException implements Exception {
  DbException(this.problem, [this.detail]);
  final DbProblem problem;
  final String? detail;
  String get message =>
      detail == null ? problem.english : '${problem.english} $detail';
  @override
  String toString() => message;
}

class LockedException extends DbException {
  LockedException(super.problem);
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
class ReconcileDateException extends DbException {
  ReconcileDateException(DbProblem problem, {this.through})
    : super(
        problem,
        through == null
            ? null
            : dateKey(through).substring(5).replaceAll('-', '.'),
      );

  /// The account's last statement date, when the date is before it.
  final DateTime? through;
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
/// the schedule before and after, paydays it scheduled or took away, and
/// the schedule that defined the budget period before.
class PayChange {
  const PayChange({
    required this.before,
    required this.after,
    required this.created,
    required this.removed,
    required this.replaced,
    required this.periodBefore,
  });
  final PayScheduleRow? before;
  final PayScheduleRow after;

  /// Paydays it scheduled, and ones of its own it took away.
  final List<int> created;
  final List<int> removed;

  /// Income the user had scheduled by hand, which the schedule took over.
  final List<int> replaced;
  final List<int> periodBefore;
}

/// What [AppDatabase.deleteCategory] did: the category, and which entries
/// moved to [into], so undo can move them back.
class DeletedCategory {
  const DeletedCategory(
    this.categoryId,
    this.into,
    this.entryIds, [
    this.budgetIds = const [],
  ]);
  final int categoryId;
  final int? into;
  final List<int> entryIds;

  /// Budget amounts that moved with a merge.
  final List<int> budgetIds;
}

/// What [AppDatabase.deleteAccount] deleted, so undo can put it back.
class DeletedAccount {
  const DeletedAccount(this.accountId, this.transactionIds);
  final int accountId;
  final List<int> transactionIds;
}

/// What a row of a bank file does on import. The person can turn a match
/// into its own row, or leave a row out.
enum ImportFate { add, match, already, leftOut }

/// A row the user typed that a bank row matches.
class TypedMatch {
  const TypedMatch({
    required this.transactionId,
    required this.entryId,
    required this.date,
    required this.payee,
    required this.cleared,
    required this.hasMemo,
  });
  final int transactionId;
  final int entryId;
  final DateTime date;
  final String payee;
  final Cleared cleared;
  final bool hasMemo;
}

class ImportPlanRow {
  const ImportPlanRow({
    required this.row,
    required this.key,
    required this.fate,
    this.match,
  });
  final ImportRow row;
  final String key;
  final ImportFate fate;

  /// Kept when the person turns the match off, so it can be turned back on.
  final TypedMatch? match;

  ImportPlanRow withFate(ImportFate f) =>
      ImportPlanRow(row: row, key: key, fate: f, match: match);
}

/// A typed row in the file's dates that no bank row matched.
class UnmatchedTyped {
  const UnmatchedTyped(this.date, this.payee, this.amount);
  final DateTime date;
  final String payee;
  final int amount;
}

/// What an import would do, and what around it deserves a look.
class ImportPlan {
  const ImportPlan({
    required this.rows,
    this.unmatched = const [],
    this.importedBefore = 0,
    this.firstDay,
    this.lastDay,
    this.opening,
  });
  final List<ImportPlanRow> rows;

  /// The account's opening balance, when it has one.
  final OpeningBalance? opening;

  /// Uncleared typed rows dated within the file that nothing matched: the
  /// bank never had them, or has them at another amount.
  final List<UnmatchedTyped> unmatched;

  /// Rows imported earlier on this account, dated within the new rows'
  /// dates. Many means the file may repeat them under different keys.
  final int importedBefore;
  final DateTime? firstDay;
  final DateTime? lastDay;

  ImportPlan withRows(List<ImportPlanRow> r) => ImportPlan(
    rows: r,
    unmatched: unmatched,
    importedBefore: importedBefore,
    firstDay: firstDay,
    lastDay: lastDay,
    opening: opening,
  );
}

/// An account's opening balance row: where it sits and what it holds.
class OpeningBalance {
  const OpeningBalance({
    required this.transactionId,
    required this.date,
    required this.amount,
    required this.locked,
  });
  final int transactionId;
  final DateTime date;

  /// On the account's side.
  final int amount;

  /// Reconciled: its date and amount stay.
  final bool locked;
}

/// Where an import moved the opening balance, for undo and redo.
typedef OpeningMove = ({
  int transactionId,
  DateTime fromDate,
  int fromAmount,
  DateTime toDate,
  int toAmount,
});

/// A matched row's date: the typed one, unless the bank's falls in another
/// month (owner, 2026-09-30), so a reconcile for that month matches the
/// bank's statement. A reconciled row keeps its date.
DateTime matchedDate(TypedMatch m, DateTime bank) {
  final b = dateOnly(bank);
  if (m.cleared == Cleared.reconciled) return m.date;
  return b.year == m.date.year && b.month == m.date.month ? m.date : b;
}

class MatchedImport {
  const MatchedImport(
    this.transactionId,
    this.entryId,
    this.before,
    this.key, {
    this.memo,
    this.dateBefore,
    this.dateAfter,
  });
  final int transactionId;
  final int entryId;
  final Cleared before;
  final String key;

  /// Set when the match took the bank's date (another month).
  final DateTime? dateBefore;
  final DateTime? dateAfter;

  /// The bank's text, put in as the memo when the typed row had none.
  final String? memo;
}

/// What an import wrote, for undo and redo: new transactions with their
/// keys, typed rows it matched, and the category it made, if any.
class ImportRecord {
  const ImportRecord({
    required this.added,
    required this.matched,
    this.madeCategory,
    this.uncategorizedCount = 0,
    this.openingMove,
  });
  final Map<int, String> added;

  /// The opening balance moved before the file's rows, when it was.
  final OpeningMove? openingMove;
  final List<MatchedImport> matched;
  final int? madeCategory;

  /// New rows that went to the holding category (made or found).
  final int uncategorizedCount;
}

/// The ledger was saved by a newer BetterBudget than this one. Nothing was
/// changed.
class NewerLedgerException implements Exception {
  NewerLedgerException(this.version);
  final int version;
  @override
  String toString() => 'NewerLedgerException: saved as version $version';
}

class NotFoundException extends DbException {
  NotFoundException(super.problem);
}

/// `20260917-153000`, for backup file names.
String fileStamp(DateTime n) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${n.year}${two(n.month)}${two(n.day)}-${two(n.hour)}${two(n.minute)}${two(n.second)}';
}

/// A plan change, for undo (rule 27): the plan before, the scheduled
/// bills it took away, and the ones it made.
typedef PlanChange = ({
  CategoryPlan? before,
  List<int> removed,
  List<int> made,
});

@DriftDatabase(
  tables: [
    Accounts,
    PaySchedules,
    Payees,
    Transactions,
    Entries,
    Reconciliations,
    Preferences,
    BudgetAmounts,
    CategoryPlans,
    CategoryAccountsOff,
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
  int get schemaVersion => 16;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // Opened by an older build than the one that last saved it: refuse,
      // before anything is written. Going on would mark it as the older
      // version while its newer columns stay, and the newer build could
      // then no longer open it (2026-09-30).
      if (from > to) throw NewerLedgerException(from);
      await _backupBeforeUpgrade(from);
      // Drift doesn't wrap upgrades; a failure halfway must leave the old
      // version intact so the next launch can try again.
      await transaction(() async {
        if (from < 2) {
          await _addColumnOnce(m, entries, entries.reconciliationId);
          await linkReconciledEntries();
        }
        if (from < 3) await repairReconciledEntries();
        if (from < 4) {
          await _addColumnOnce(m, accounts, accounts.archivedAt);
          await _addColumnOnce(m, accounts, accounts.deletedAt);
        }
        if (from < 5) {
          await _addColumnOnce(m, accounts, accounts.payday);
          await m.createTable(paySchedules);
          await _addColumnOnce(m, transactions, transactions.payScheduleId);
          // Every income row ended the forecast before; nothing changes
          // until the user unmarks one.
          await customStatement(
            "UPDATE accounts SET payday = 1 WHERE type = 'income'",
          );
        }
        if (from < 6) {
          await _addColumnOnce(m, accounts, accounts.role);
          await m.createTable(preferences);
        }
        // Before v5 the table was just made, with the column already.
        if (from >= 5 && from < 7) {
          await _addColumnOnce(m, paySchedules, paySchedules.amount2Minor);
        }
        if (from < 8) {
          await _addColumnOnce(m, entries, entries.importKey);
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS entries_import_key '
            'ON entries (import_key)',
          );
          // A key on a transaction goes to the side of the account it names
          // (`a<id>|…`), else its first account side.
          await customStatement(
            'UPDATE entries SET import_key = (SELECT t.import_key FROM '
            'transactions t WHERE t.id = entries.transaction_id) '
            'WHERE id IN (SELECT e.id FROM entries e '
            'JOIN transactions t ON t.id = e.transaction_id '
            "WHERE t.import_key LIKE 'a' || e.account_id || '|%')",
          );
          await customStatement(
            'UPDATE entries SET import_key = (SELECT t.import_key FROM '
            'transactions t WHERE t.id = entries.transaction_id) '
            'WHERE id IN (SELECT MIN(e.id) FROM entries e '
            'JOIN transactions t ON t.id = e.transaction_id '
            'JOIN accounts a ON a.id = e.account_id '
            "WHERE t.import_key IS NOT NULL AND a.type IN ('asset', 'liability') "
            'AND NOT EXISTS (SELECT 1 FROM entries k WHERE '
            'k.transaction_id = e.transaction_id AND k.import_key IS NOT NULL) '
            'GROUP BY e.transaction_id)',
          );
          await customStatement('UPDATE transactions SET import_key = NULL');
        }
        // Before v5 the table was just made, with the column already.
        if (from >= 5 && from < 9) {
          await _addColumnOnce(m, paySchedules, paySchedules.weekendKeep);
        }
        // Drift makes it IF NOT EXISTS, so a relabeled file is safe too.
        if (from < 10) await m.createTable(budgetAmounts);
        if (from < 11) await m.createTable(categoryPlans);
        if (from < 12) {
          await m.createTable(categoryAccountsOff);
          // A category is in one currency now. Until here the whole budget
          // was in one. With amounts assigned, that's the one it began in,
          // and every spending category takes it. With none yet, each
          // takes the currency most of its own rows are in, or the one
          // most open accounts are in (tugrik on a tie). Income too, so
          // one changed to spending later starts out right.
          await customStatement(
            "UPDATE accounts SET currency = COALESCE("
            "(SELECT value FROM preferences WHERE key = 'budget.currency'), "
            // No budget yet: the currency most of its own rows are in.
            "(SELECT e.currency FROM entries e JOIN transactions t ON "
            "t.id = e.transaction_id WHERE e.account_id = accounts.id AND "
            "t.deleted_at IS NULL GROUP BY e.currency ORDER BY COUNT(*) DESC, "
            "e.currency LIMIT 1), "
            "CASE WHEN (SELECT COUNT(*) FROM accounts WHERE type IN "
            "('asset', 'liability') AND deleted_at IS NULL AND archived_at "
            "IS NULL AND currency = 'USD') > (SELECT COUNT(*) FROM accounts "
            "WHERE type IN ('asset', 'liability') AND deleted_at IS NULL AND "
            "archived_at IS NULL AND currency = 'MNT') THEN 'USD' ELSE 'MNT' "
            "END) WHERE type IN ('expense', 'income')",
          );
        }
        if (from < 13) {
          await _oneIncome();
          await incomeCategory();
        }
        if (from < 14) {
          // Two kinds of plan instead of four (rule 27): "save up" is
          // each period, carrying over; a goal is an amount by a date,
          // once. SQLite reads the old row in every SET.
          await _addColumnOnce(m, categoryPlans, categoryPlans.upToMinor);
          await _addColumnOnce(m, categoryPlans, categoryPlans.paidFromId);
          await _addColumnOnce(m, transactions, transactions.planCategoryId);
          await customStatement(
            "UPDATE category_plans SET kind = CASE WHEN kind IN ('spend', "
            "'saveUp') THEN 'each' ELSE 'byDate' END, rollover = CASE WHEN "
            "kind = 'saveUp' THEN 1 ELSE rollover END WHERE kind IN "
            "('spend', 'saveUp', 'dueOn', 'goal')",
          );
        }
        if (from < 15) {
          // How often a dated plan comes: by days, on fixed dates, every
          // payday, and a weekend rule, beside by months (rule 27).
          await _addColumnOnce(m, categoryPlans, categoryPlans.everyDays);
          await _addColumnOnce(m, categoryPlans, categoryPlans.onDates);
          await _addColumnOnce(m, categoryPlans, categoryPlans.payScheduleId);
          await _addColumnOnce(m, categoryPlans, categoryPlans.daysAfterPay);
          await _addColumnOnce(m, categoryPlans, categoryPlans.weekend);
        }
        if (from < 16) {
          // Custom… (owner, 2026-10-05): weekday patterns and an end.
          await _addColumnOnce(m, categoryPlans, categoryPlans.weekdays);
          await _addColumnOnce(m, categoryPlans, categoryPlans.nth);
          await _addColumnOnce(m, categoryPlans, categoryPlans.nthWeekday);
          await _addColumnOnce(m, categoryPlans, categoryPlans.endDate);
          await _addColumnOnce(m, categoryPlans, categoryPlans.endCount);
        }
      });
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
    },
  );

  /// v13 (rule 30): every income category becomes the one Income. Their
  /// rows and pay schedules move to it; the names go.
  Future<void> _oneIncome() async {
    final all = await customSelect(
      "SELECT id FROM accounts WHERE type = 'income' ORDER BY "
      'deleted_at IS NOT NULL, archived_at IS NOT NULL, id',
    ).get();
    // A spending category that has Income's name gives it up.
    await customStatement(
      "UPDATE accounts SET name = name || ' (spending)' WHERE type = "
      "'expense' AND name IN ('Income', 'income', 'Орлого', 'орлого')",
    );
    if (all.isEmpty) return;
    final keep = all.first.read<int>('id');
    await customStatement(
      'UPDATE accounts SET name = ?, archived_at = NULL, deleted_at = NULL '
      'WHERE id = ?',
      [incomeAccountName, keep],
    );
    const others =
        "(SELECT id FROM accounts WHERE type = 'income' AND id <> ?)";
    // What pointed at a category that's going: when it counts from, and
    // the loan paid out of it.
    await customStatement(
      "DELETE FROM preferences WHERE key IN (SELECT 'budget.from.' || id "
      "FROM accounts WHERE id IN $others) OR (key LIKE 'budget.loan.%' "
      'AND value IN (SELECT CAST(id AS TEXT) FROM accounts WHERE id IN '
      '$others))',
      [keep, keep],
    );
    await customStatement(
      'UPDATE entries SET account_id = ? WHERE account_id IN $others',
      [keep, keep],
    );
    await customStatement(
      'UPDATE pay_schedules SET category_id = ? WHERE category_id IN $others',
      [keep, keep],
    );
    // What a category held while it was a spending one.
    for (final t in ['budget_amounts', 'category_plans']) {
      await customStatement(
        "DELETE FROM $t WHERE category_id IN "
        "(SELECT id FROM accounts WHERE type = 'income')",
      );
    }
    await customStatement(
      'DELETE FROM category_accounts_off WHERE category_id IN '
      "(SELECT id FROM accounts WHERE type = 'income')",
    );
    await customStatement(
      "DELETE FROM accounts WHERE type = 'income' AND id <> ?",
      [keep],
    );
  }

  int get _now => DateTime.now().millisecondsSinceEpoch;

  /// Adds [column] unless [table] has it already: an upgrade that ran, or a
  /// file an older build relabeled, mustn't stop the ledger opening.
  Future<void> _addColumnOnce(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    final have = await customSelect(
      'PRAGMA table_info("${table.actualTableName}")',
    ).get();
    if (have.any((r) => r.read<String>('name') == column.name)) return;
    await m.addColumn(table, column);
  }

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
  /// Each currency adds up to zero on its own, as every write checks.
  static const unbalancedSql =
      'SELECT transaction_id FROM entries GROUP BY transaction_id '
      'HAVING COUNT(*) < 2 '
      'UNION SELECT transaction_id FROM entries '
      'GROUP BY transaction_id, currency HAVING SUM(amount_minor) != 0';

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
      'budget_amounts',
      'category_plans',
      'category_accounts_off',
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
      budgetAmounts,
      categoryPlans,
      categoryAccountsOff,
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
    final budgetRows = await select(budgetAmounts).get();
    final planRows = await select(categoryPlans).get();
    final offRows = await select(categoryAccountsOff).get();
    final accountsOff = <int, Set<int>>{};
    for (final r in offRows) {
      accountsOff.putIfAbsent(r.categoryId, () => {}).add(r.accountId);
    }

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
              currency: Currency.fromCode(e.currency),
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
            role: a.role,
            currency: Currency.fromCode(a.currency),
          ),
      ],
      prefs: {for (final p in prefRows) p.key: p.value},
      plans: [for (final p in planRows) _plan(p)],
      accountsOff: accountsOff,
      budgetAmounts: [
        for (final b in budgetRows)
          BudgetAmount(
            id: b.id,
            categoryId: b.categoryId,
            date: parseDateKey(b.date),
            amount: b.amountMinor,
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
            payScheduleId: t.payScheduleId,
            planCategoryId: t.planCategoryId,
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
    int? payScheduleId,
    int? planCategoryId,
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
          payScheduleId: Value(payScheduleId),
          planCategoryId: Value(planCategoryId),
          createdAt: now,
          updatedAt: now,
        ),
      );
      final currency = await _currencyOfLines(lines.map((l) => l.accountId));
      for (final l in lines) {
        await into(entries).insert(
          EntriesCompanion.insert(
            transactionId: txnId,
            accountId: l.accountId,
            amountMinor: l.amount,
            cleared: l.cleared,
            currency: Value(currency.code),
          ),
        );
      }
      await _assertBalanced(txnId);
      return txnId;
    });
  }

  /// The currency of a transaction whose accounts share one: the accounts'
  /// (a category takes whatever is filed under it). Accounts in two
  /// currencies need [postExchange].
  Future<Currency> _currencyOfLines(Iterable<int> accountIds) async {
    final rows = await (select(
      accounts,
    )..where((a) => a.id.isIn(accountIds.toSet()))).get();
    final found = {
      for (final a in rows)
        if (_reconcilable.contains(a.type)) Currency.fromCode(a.currency),
    };
    if (found.length > 1) throw LockedException(DbProblem.needsOtherAmount);
    return found.firstOrNull ?? Currency.mnt;
  }

  Future<Currency> currencyOf(int accountId) async => Currency.fromCode(
    (await (select(
      accounts,
    )..where((a) => a.id.equals(accountId))).getSingle()).currency,
  );

  /// A transfer between accounts in two currencies (ROADMAP E): [sent]
  /// leaves [fromAccountId] in its currency, [received] arrives in
  /// [toAccountId] in its own. Each currency's side passes through the
  /// hidden exchange account, so each still adds up to zero; the rate is
  /// never stored, only shown (sent / received).
  Future<int> postExchange({
    required int fromAccountId,
    required int toAccountId,
    required DateTime date,
    required DateTime today,
    required int sent,
    required int received,
    String? payee,
    String? memo,
  }) => transaction(() async {
    await _assertLive(fromAccountId);
    await _assertLive(toAccountId);
    if (fromAccountId == toAccountId) {
      throw LockedException(DbProblem.ownAccount);
    }
    final types = await _accountTypes();
    if (!_reconcilable.contains(types[fromAccountId]) ||
        !_reconcilable.contains(types[toAccountId])) {
      throw NotFoundException(DbProblem.notAnAccount);
    }
    if (sent == 0 || received == 0) {
      throw LockedException(DbProblem.needsOtherAmount);
    }
    final from = await currencyOf(fromAccountId);
    final to = await currencyOf(toAccountId);
    if (from == to) throw LockedException(DbProblem.otherCurrency);
    final exchange = await _equityAccount(currencyExchangeName);
    final now = _now;
    final txnId = await into(transactions).insert(
      TransactionsCompanion.insert(
        date: dateKey(date),
        payeeId: Value(await _payeeId(payee)),
        memo: Value(memo?.trim().isEmpty ?? true ? null : memo!.trim()),
        scheduled: Value(dateOnly(date).isAfter(dateOnly(today))),
        createdAt: now,
        updatedAt: now,
      ),
    );
    for (final (account, amount, currency) in [
      (fromAccountId, -sent.abs(), from),
      (exchange, sent.abs(), from),
      (exchange, -received.abs(), to),
      (toAccountId, received.abs(), to),
    ]) {
      await into(entries).insert(
        EntriesCompanion.insert(
          transactionId: txnId,
          accountId: account,
          amountMinor: amount,
          cleared: Cleared.uncleared,
          currency: Value(currency.code),
        ),
      );
    }
    await _assertBalanced(txnId);
    return txnId;
  });

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
        throw LockedException(DbProblem.ownAccount);
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
        throw NotFoundException(DbProblem.notSingleCategory);
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
        throw LockedException(DbProblem.reconciled);
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
    // An edit between currencies adds or drops the exchange entries, so the
    // snapshot's set of entries comes back exactly.
    final keep = s.entries.map((e) => e.id).toSet();
    await (delete(entries)..where(
          (x) => x.transactionId.equals(s.header.id) & x.id.isNotIn(keep),
        ))
        .go();
    for (final e in s.entries) {
      final n = await (update(entries)..where((x) => x.id.equals(e.id))).write(
        EntriesCompanion(
          accountId: Value(e.accountId),
          amountMinor: Value(e.amountMinor),
          currency: Value(e.currency),
        ),
      );
      if (n == 0) await into(entries).insert(e);
    }
    await _assertBalanced(s.header.id);
  });

  /// The part of an edit that involves two currencies: a transfer between
  /// them, or one being moved to an account in another currency. Returns
  /// false when neither side is in another currency, for the plain edit.
  Future<bool> _editAcrossCurrencies({
    required int transactionId,
    required List<EntryRow> rows,
    required EntryRow mine,
    required int? exchangeId,
    int? amount,
    int? counterAccountId,
    int? counterAmount,
  }) async {
    final exchange = rows.where((e) => e.accountId == exchangeId).toList();
    final others = rows
        .where((e) => e.id != mine.id && e.accountId != exchangeId)
        .toList();
    if (others.length != 1) return false;
    final other = others.single;
    final targetId = counterAccountId ?? other.accountId;
    final mineCurrency = Currency.fromCode(mine.currency);
    final target = await (select(
      accounts,
    )..where((a) => a.id.equals(targetId))).getSingle();
    final targetCurrency = _reconcilable.contains(target.type)
        ? Currency.fromCode(target.currency)
        : mineCurrency;
    final newMine = amount ?? mine.amountMinor;
    // A side moved to another account starts over there, as Move to does.
    final moved = targetId != other.accountId;
    if (targetCurrency == mineCurrency) {
      if (exchange.isEmpty) return false;
      // Back to one currency: the exchange legs go.
      await (delete(
        entries,
      )..where((e) => e.id.isIn(exchange.map((x) => x.id)))).go();
      await (update(entries)..where((e) => e.id.equals(mine.id))).write(
        EntriesCompanion(amountMinor: Value(newMine)),
      );
      await (update(entries)..where((e) => e.id.equals(other.id))).write(
        EntriesCompanion(
          accountId: Value(targetId),
          amountMinor: Value(-newMine),
          currency: Value(mineCurrency.code),
          cleared: moved
              ? const Value(Cleared.uncleared)
              : const Value.absent(),
        ),
      );
      return true;
    }
    final otherSize =
        counterAmount?.abs() ??
        (exchange.isEmpty ? null : other.amountMinor.abs());
    if (otherSize == null || otherSize == 0) {
      throw LockedException(DbProblem.needsOtherAmount);
    }
    // Money leaves one side and arrives on the other, whichever way.
    final newOther = -newMine.sign * otherSize;
    if (exchange.isNotEmpty &&
        !moved &&
        newMine == mine.amountMinor &&
        newOther == other.amountMinor) {
      return true; // nothing about the money changed: nothing is written
    }
    await (update(entries)..where((e) => e.id.equals(mine.id))).write(
      EntriesCompanion(amountMinor: Value(newMine)),
    );
    await (update(entries)..where((e) => e.id.equals(other.id))).write(
      EntriesCompanion(
        accountId: Value(targetId),
        amountMinor: Value(newOther),
        currency: Value(targetCurrency.code),
        cleared: moved ? const Value(Cleared.uncleared) : const Value.absent(),
      ),
    );
    // The legs are updated in place when there are two, one per currency,
    // so an undo finds the same entries it saved.
    final legMine = exchange
        .where((e) => e.currency == mineCurrency.code)
        .firstOrNull;
    final legOther = exchange
        .where((e) => e.currency == targetCurrency.code)
        .firstOrNull;
    if (exchange.length == 2 && legMine != null && legOther != null) {
      await (update(entries)..where((e) => e.id.equals(legMine.id))).write(
        EntriesCompanion(amountMinor: Value(-newMine)),
      );
      await (update(entries)..where((e) => e.id.equals(legOther.id))).write(
        EntriesCompanion(amountMinor: Value(-newOther)),
      );
      return true;
    }
    await (delete(
      entries,
    )..where((e) => e.id.isIn(exchange.map((x) => x.id)))).go();
    final legs = exchangeId ?? await _equityAccount(currencyExchangeName);
    for (final (amount, currency) in [
      (-newMine, mineCurrency),
      (-newOther, targetCurrency),
    ]) {
      await into(entries).insert(
        EntriesCompanion.insert(
          transactionId: transactionId,
          accountId: legs,
          amountMinor: amount,
          cleared: Cleared.uncleared,
          currency: Value(currency.code),
        ),
      );
    }
    return true;
  }

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
    int? counterAmount,
    bool confirm = false,
    bool keepOwed = false,
  }) {
    return transaction(() async {
      if (confirm && dateOnly(date).isAfter(dateOnly(today))) {
        throw LockedException(DbProblem.futureConfirm);
      }
      final header = await (select(
        transactions,
      )..where((t) => t.id.equals(transactionId))).getSingle();
      final rows = await (select(
        entries,
      )..where((e) => e.transactionId.equals(transactionId))).get();
      final mine = rows.where((e) => e.accountId == accountId).firstOrNull;
      if (mine == null) throw NotFoundException(DbProblem.notInAccount);
      // Looked up, never made here: an edit in a ledger with no dollars
      // mustn't leave an exchange account behind.
      final exchangeId = await _findEquity(currencyExchangeName);
      final isExchange = rows.any((e) => e.accountId == exchangeId);
      // A reconciled side locks the date, amounts and accounts of the whole
      // transaction, as delete does: a transfer edited from its other account
      // would change the locked side. Payee, memo and category stay editable.
      if ((await _reconciledAmong([transactionId])).isNotEmpty) {
        final others = rows
            .where((e) => e.id != mine.id && e.accountId != exchangeId)
            .toList();
        final types = await _accountTypes();
        final movesAccount =
            counterAccountId != null &&
            others.length == 1 &&
            counterAccountId != others.single.accountId &&
            (_reconcilable.contains(types[counterAccountId]) ||
                _reconcilable.contains(types[others.single.accountId]));
        final otherAmount = others.length == 1
            ? others.single.amountMinor
            : null;
        if (dateKey(date) != header.date ||
            (amount != null && amount != mine.amountMinor) ||
            (isExchange &&
                counterAmount != null &&
                counterAmount.abs() != otherAmount?.abs()) ||
            movesAccount) {
          throw LockedException(DbProblem.reconciled);
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
        throw LockedException(DbProblem.ownAccount);
      }
      if (amount != null || counterAccountId != null || counterAmount != null) {
        if (await _editAcrossCurrencies(
          transactionId: transactionId,
          rows: rows,
          mine: mine,
          exchangeId: exchangeId,
          amount: amount,
          counterAccountId: counterAccountId,
          counterAmount: counterAmount,
        )) {
          await _assertBalanced(transactionId);
          return null;
        }
        final others = rows.where((e) => e.id != mine.id).toList();
        if (others.length != 1) {
          throw NotFoundException(DbProblem.splitNotEditable);
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
      throw NotFoundException(DbProblem.notAnAccount);
    }
    if ((await _reconciledAmong([transactionId])).isNotEmpty) {
      throw LockedException(DbProblem.reconciled);
    }
    final rows = await (select(
      entries,
    )..where((e) => e.transactionId.equals(transactionId))).get();
    final mine = rows.where((e) => e.accountId == fromAccountId).toList();
    if (mine.length != 1) throw NotFoundException(DbProblem.notInAccount);
    if (rows.map((e) => e.currency).toSet().length > 1) {
      throw LockedException(DbProblem.otherCurrency);
    }
    // An opening balance or a reconcile adjustment belongs to its account.
    if (rows.any((e) => types[e.accountId] == AccountType.equity)) {
      throw LockedException(DbProblem.openingStays);
    }
    if (rows.any((e) => e.accountId == toAccountId)) {
      throw LockedException(DbProblem.alreadyThere);
    }
    // The amount means something else in another currency.
    if (await currencyOf(fromAccountId) != await currencyOf(toAccountId)) {
      throw LockedException(DbProblem.otherCurrency);
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
      throw LockedException(DbProblem.changedSince);
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
      throw LockedException(DbProblem.reconciled);
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

  // ---------- accounts ----------

  static const openingBalancesName = openingBalancesAccountName;

  /// The sidebar group a new or changed account goes in.
  static String groupFor(AccountType type) =>
      type == AccountType.liability ? 'Credit' : 'Cash & bank';

  /// A bank account or credit card, last in the sidebar.
  Future<int> createAccount({
    required String name,
    required AccountType type,
    Currency currency = Currency.mnt,
  }) => transaction(() async {
    final last =
        await (selectOnly(accounts)..addColumns([accounts.sortOrder.max()]))
            .map((r) => r.read(accounts.sortOrder.max()))
            .getSingle();
    final id = await addAccount(
      name: name.trim(),
      type: type,
      group: groupFor(type),
      sortOrder: (last ?? 0) + 1,
    );
    await (update(accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(currency: Value(currency.code)),
    );
    // A category already narrowed to some accounts doesn't take a new one
    // on its own: it starts unchecked there. Categories using every
    // account get it, as before.
    if (type == AccountType.asset || type == AccountType.liability) {
      await customStatement(
        'INSERT INTO category_accounts_off (category_id, account_id) '
        'SELECT DISTINCT o.category_id, ? FROM category_accounts_off o '
        'JOIN accounts c ON c.id = o.category_id '
        'JOIN accounts a ON a.id = o.account_id '
        'WHERE c.currency = ? AND c.deleted_at IS NULL '
        'AND a.deleted_at IS NULL AND a.archived_at IS NULL',
        [id, currency.code],
      );
    }
    return id;
  });

  /// Marks what an account is for on the Savings steps; null clears it.
  Future<void> setAccountRole(int accountId, AccountRole? role) =>
      (update(accounts)..where((a) => a.id.equals(accountId))).write(
        AccountsCompanion(role: Value(role)),
      );

  /// What [categoryId] has assigned for the period [start]–[end]: every
  /// amount it has in the period goes, and one dated [start] takes their
  /// place (none for 0). Returns what went, each on its own date, for
  /// [restoreBudgetAmounts]. Amounts can sit anywhere in a period after
  /// Settings switched between months and pay periods.
  Future<List<BudgetAmount>> setBudgetAmount(
    int categoryId,
    DateTime start,
    DateTime end,
    int amount,
  ) => transaction(() async {
    await _assertOwnCategory(categoryId);
    final before = await _budgetIn(categoryId, start, end);
    await _clearBudgetIn(categoryId, start, end);
    if (amount != 0) {
      await into(budgetAmounts).insert(
        BudgetAmountsCompanion.insert(
          categoryId: categoryId,
          date: dateKey(dateOnly(start)),
          amountMinor: amount,
        ),
      );
    }
    return before;
  });

  /// Undo for [setBudgetAmount]: [categoryId]'s amounts in [start]–[end]
  /// back to [before], the same rows on their own dates.
  Future<void> restoreBudgetAmounts(
    int categoryId,
    DateTime start,
    DateTime end,
    List<BudgetAmount> before,
  ) => transaction(() async {
    await _clearBudgetIn(categoryId, start, end);
    for (final b in before) {
      await into(budgetAmounts).insert(
        BudgetAmountsCompanion.insert(
          id: Value.absentIfNull(b.id),
          categoryId: b.categoryId,
          date: dateKey(dateOnly(b.date)),
          amountMinor: b.amount,
        ),
      );
    }
  });

  /// Every amount dated in [start]–[end] moves to [to]. Returns what moved
  /// with its old date, for [unmoveBudgetAmounts].
  Future<List<BudgetAmount>> moveBudgetAmounts(
    DateTime start,
    DateTime end,
    DateTime to,
  ) => transaction(() async {
    final moved = [
      for (final b in await (select(
        budgetAmounts,
      )..where((b) => _dateIn(b, start, end))).get())
        _budgetAmount(b),
    ];
    await (update(budgetAmounts)..where((b) => _dateIn(b, start, end))).write(
      BudgetAmountsCompanion(date: Value(dateKey(dateOnly(to)))),
    );
    return moved;
  });

  /// Undo for [moveBudgetAmounts].
  Future<void> unmoveBudgetAmounts(List<BudgetAmount> moved) =>
      transaction(() async {
        for (final b in moved) {
          await (update(budgetAmounts)..where((r) => r.id.equals(b.id!))).write(
            BudgetAmountsCompanion(date: Value(dateKey(b.date))),
          );
        }
      });

  /// Several categories' amounts for the period [start]–[end] in one write
  /// (the plans' amounts, assigned together). Returns what each had, for
  /// [restoreBudgetAmountsOf].
  Future<Map<int, List<BudgetAmount>>> setBudgetAmounts(
    Map<int, int> amounts,
    DateTime start,
    DateTime end,
  ) => transaction(() async {
    return {
      for (final e in amounts.entries)
        e.key: await setBudgetAmount(e.key, start, end, e.value),
    };
  });

  /// Undo for [setBudgetAmounts].
  Future<void> restoreBudgetAmountsOf(
    Map<int, List<BudgetAmount>> before,
    DateTime start,
    DateTime end,
  ) => transaction(() async {
    for (final e in before.entries) {
      await restoreBudgetAmounts(e.key, start, end, e.value);
    }
  });

  /// Gives [categoryId] the plan [plan], or takes its plan away with null.
  /// Returns the plan it had, so undo can put it back. The bills the old
  /// plan had scheduled go with it unless the new one has the same bill
  /// in the same account ([ensurePlanBills] schedules the new plan's);
  /// confirmed ones stay. [changeCategoryPlan] does the same and keeps
  /// what it took away and made, for an exact undo.
  Future<CategoryPlan?> setCategoryPlan(int categoryId, CategoryPlan? plan) =>
      transaction(() async => (await _changePlan(categoryId, plan)).before);

  /// [setCategoryPlan], then the new plan's next bill scheduled, with
  /// what it took away and made kept for [undoPlanChange] and
  /// [redoPlanChange].
  Future<PlanChange> changeCategoryPlan(
    int categoryId,
    CategoryPlan? plan,
    DateTime today,
  ) => transaction(() async {
    final c = await _changePlan(categoryId, plan);
    final made = await ensurePlanBills(today, only: categoryId);
    return (before: c.before, removed: c.removed, made: made);
  });

  /// Puts back the plan [change] replaced, and the very bills it took
  /// away (with whatever the user had typed on them), and takes away the
  /// ones it made.
  Future<void> undoPlanChange(int categoryId, PlanChange change) =>
      transaction(() async {
        await _dropPlanBills(change.made);
        await _writePlan(categoryId, change.before);
        await bringBackPlanBills(change.removed, categoryId);
      });

  /// [changeCategoryPlan] again, with the same bills as the first time.
  Future<void> redoPlanChange(
    int categoryId,
    CategoryPlan? plan,
    PlanChange change,
  ) => transaction(() async {
    await _dropPlanBills(change.removed);
    await _writePlan(categoryId, plan);
    await bringBackPlanBills(change.made, categoryId);
  });

  Future<({CategoryPlan? before, List<int> removed})> _changePlan(
    int categoryId,
    CategoryPlan? plan,
  ) async {
    await _assertOwnCategory(categoryId);
    final old = await (select(
      categoryPlans,
    )..where((p) => p.categoryId.equals(categoryId))).getSingleOrNull();
    final before = old == null ? null : _plan(old);
    var removed = const <int>[];
    if (before != null && !_sameBills(before, plan)) {
      removed = await _comingPlanBills(categoryId);
      await _dropPlanBills(removed);
    }
    await _writePlan(categoryId, plan);
    return (before: before, removed: removed);
  }

  Future<void> _writePlan(int categoryId, CategoryPlan? plan) async {
    await (delete(
      categoryPlans,
    )..where((p) => p.categoryId.equals(categoryId))).go();
    if (plan != null) {
      await into(categoryPlans).insert(
        CategoryPlansCompanion.insert(
          categoryId: Value(categoryId),
          kind: plan.kind,
          amountMinor: plan.amount,
          start: dateKey(dateOnly(plan.start)),
          due: Value(plan.due == null ? null : dateKey(plan.due!)),
          everyMonths: Value(plan.everyMonths),
          everyDays: Value(plan.everyDays),
          onDates: Value(
            plan.onDates == null
                ? null
                : [
                    for (final (m, d) in plan.onDates!)
                      '${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}',
                  ].join(','),
          ),
          payScheduleId: Value(plan.payScheduleId),
          daysAfterPay: Value(plan.daysAfterPay),
          weekend: Value(plan.weekend),
          weekdays: Value(plan.weekdays?.join(',')),
          nth: Value(plan.nth),
          nthWeekday: Value(plan.nthWeekday),
          endDate: Value(plan.endDate == null ? null : dateKey(plan.endDate!)),
          endCount: Value(plan.endCount),
          rollover: Value(plan.rollover),
          upToMinor: Value(plan.upTo),
          paidFromId: Value(plan.paidFrom),
        ),
      );
    }
  }

  /// A pay schedule that's still going, for a plan that follows its
  /// paydays; null once it's stopped, when the plan's first date stands
  /// alone.
  Future<PaySchedule?> _livePaySchedule(int id) async {
    final row = await (select(
      paySchedules,
    )..where((p) => p.id.equals(id) & p.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : _schedule(row);
  }

  /// Two plans schedule the same bills: dated, the same amount on the
  /// same dates, paid from the same account.
  static bool _sameBills(CategoryPlan a, CategoryPlan? b) =>
      b != null &&
      a.kind == PlanKind.byDate &&
      b.kind == PlanKind.byDate &&
      a.amount == b.amount &&
      a.sameRepeat(b) &&
      a.paidFrom == b.paidFrom;

  /// The category's bills still scheduled.
  Future<List<int>> _comingPlanBills(int categoryId) =>
      (selectOnly(transactions)
            ..addColumns([transactions.id])
            ..where(
              transactions.planCategoryId.equals(categoryId) &
                  transactions.scheduled.equals(true) &
                  transactions.deletedAt.isNull(),
            ))
          .map((r) => r.read(transactions.id)!)
          .get();

  /// Bills the app takes away itself (a changed plan, an undo) are
  /// unlinked as well as deleted, like [dropPaydays]: only a bill the
  /// user deleted stays linked, which is how a skipped bill stays skipped.
  Future<void> dropPlanBills(List<int> ids) =>
      transaction(() => _dropPlanBills(ids));

  Future<void> _dropPlanBills(List<int> ids) async {
    if (ids.isEmpty) return;
    await (update(transactions)..where((t) => t.id.isIn(ids))).write(
      TransactionsCompanion(
        deletedAt: Value(_now),
        planCategoryId: const Value(null),
      ),
    );
  }

  /// Undo for [dropPlanBills]: back, and linked to [categoryId] again.
  Future<void> bringBackPlanBills(List<int> ids, int categoryId) =>
      transaction(() async {
        if (ids.isEmpty) return;
        await (update(transactions)..where((t) => t.id.isIn(ids))).write(
          TransactionsCompanion(
            deletedAt: const Value(null),
            planCategoryId: Value(categoryId),
          ),
        );
      });

  /// Keeps each dated plan's next bill scheduled in the account it's paid
  /// from (rule 27), the way [ensurePaydays] keeps paydays: a plan with
  /// nothing waiting from [today] on gets the bill after its latest
  /// planned one (confirmed early or late, it counts as the bill it was
  /// for; deleted by the user, it's skipped and doesn't come back). An
  /// amount wanted once is scheduled once. Returns what it scheduled,
  /// for undo.
  Future<List<int>> ensurePlanBills(
    DateTime today, {
    int? only,
  }) => transaction(() async {
    final created = <int>[];
    final t = dateOnly(today);
    final todayKey = dateKey(t);
    final rows =
        await (select(categoryPlans)..where(
              (p) =>
                  p.paidFromId.isNotNull() &
                  (only == null
                      ? const Constant(true)
                      : p.categoryId.equals(only)),
            ))
            .get();
    for (final row in rows) {
      final plan = _plan(row);
      final paidFrom = plan.paidFrom;
      if (plan.kind != PlanKind.byDate ||
          paidFrom == null ||
          (plan.due == null && plan.payScheduleId == null)) {
        continue;
      }
      // Payday by payday: its schedule, while that's still going.
      final pay = plan.payScheduleId == null
          ? null
          : await _livePaySchedule(plan.payScheduleId!);
      final first = Budget.dueAfter(plan, 0, pay: pay);
      final repeats = plan.repeats;
      final category = await (select(
        accounts,
      )..where((a) => a.id.equals(plan.categoryId))).getSingle();
      final account = await (select(
        accounts,
      )..where((a) => a.id.equals(paidFrom))).getSingle();
      // Nothing lands in an account or category that's gone or put away.
      if (category.deletedAt != null ||
          account.deletedAt != null ||
          category.archivedAt != null ||
          account.archivedAt != null) {
        continue;
      }
      // The plan's own rows: from the day it was made (a changed
      // amount or date is a new plan, and the old one's confirmed
      // bills aren't its).
      final linked =
          await (select(transactions)..where(
                (x) =>
                    x.planCategoryId.equals(plan.categoryId) &
                    x.date.isBiggerOrEqualValue(dateKey(dateOnly(plan.start))),
              ))
              .get();
      if (linked.any(
        (x) =>
            x.deletedAt == null &&
            x.scheduled &&
            x.date.compareTo(todayKey) >= 0,
      )) {
        continue;
      }
      // Once: scheduled once, whatever became of it.
      if (!repeats && linked.isNotEmpty) continue;
      // The bill each row was for: a scheduled one's date, else the
      // bill date nearest the day it was confirmed.
      DateTime? latest;
      for (final x in linked) {
        final d = parseDateKey(x.date);
        final bill = x.scheduled ? d : Budget.billDate(plan, d, pay: pay);
        if (bill != null && (latest == null || bill.isAfter(latest))) {
          latest = bill;
        }
      }
      final yesterday = DateTime(t.year, t.month, t.day - 1);
      final from = latest == null || latest.isBefore(yesterday)
          ? yesterday
          : latest;
      final DateTime date;
      if (!repeats) {
        if (!first.isAfter(from)) continue;
        date = first;
      } else {
        var n = 0;
        while (!Budget.dueAfter(plan, n, pay: pay).isAfter(from) && n < 5200) {
          n++;
        }
        date = Budget.dueAfter(plan, n, pay: pay);
        // Past its last bill (Custom…'s Ends): nothing more to schedule.
        if (Budget.over(plan, date, pay: pay)) continue;
      }
      created.add(
        await postTransaction(
          date: date,
          scheduled: true,
          planCategoryId: plan.categoryId,
          lines: [
            (
              accountId: paidFrom,
              amount: -plan.amount,
              cleared: Cleared.uncleared,
            ),
            (
              accountId: plan.categoryId,
              amount: plan.amount,
              cleared: Cleared.uncleared,
            ),
          ],
        ),
      );
    }
    return created;
  });

  /// Puts [categoryId] in [currency], using every account in it but
  /// [off]. A change of currency takes back what was assigned to it and
  /// removes its plan: those were amounts in the old currency. Returns
  /// what it replaced, for [restoreCategoryMoney].
  Future<CategoryMoney> setCategoryMoney(
    int categoryId, {
    required Currency currency,
    required Set<int> off,
  }) => transaction(() async {
    await _assertOwnCategory(categoryId);
    final row = await (select(
      accounts,
    )..where((a) => a.id.equals(categoryId))).getSingle();
    final was = Currency.fromCode(row.currency);
    final oldOff = {
      for (final r in await (select(
        categoryAccountsOff,
      )..where((r) => r.categoryId.equals(categoryId))).get())
        r.accountId,
    };
    var amounts = const <BudgetAmount>[];
    CategoryPlan? plan;
    if (was != currency) {
      amounts = [
        for (final b in await (select(
          budgetAmounts,
        )..where((b) => b.categoryId.equals(categoryId))).get())
          _budgetAmount(b),
      ];
      await (delete(
        budgetAmounts,
      )..where((b) => b.categoryId.equals(categoryId))).go();
      plan = await setCategoryPlan(categoryId, null);
      await (update(accounts)..where((a) => a.id.equals(categoryId))).write(
        AccountsCompanion(currency: Value(currency.code)),
      );
    }
    await _setAccountsOff(categoryId, off);
    return CategoryMoney(
      currency: was,
      off: oldOff,
      amounts: amounts,
      plan: plan,
    );
  });

  /// Undo for [setCategoryMoney].
  Future<void> restoreCategoryMoney(int categoryId, CategoryMoney before) =>
      transaction(() async {
        await (update(accounts)..where((a) => a.id.equals(categoryId))).write(
          AccountsCompanion(currency: Value(before.currency.code)),
        );
        await _setAccountsOff(categoryId, before.off);
        for (final b in before.amounts) {
          await into(budgetAmounts).insert(
            BudgetAmountsCompanion.insert(
              id: Value.absentIfNull(b.id),
              categoryId: b.categoryId,
              date: dateKey(dateOnly(b.date)),
              amountMinor: b.amount,
            ),
          );
        }
        if (before.plan != null) {
          await setCategoryPlan(categoryId, before.plan);
        }
      });

  Future<void> _setAccountsOff(int categoryId, Set<int> off) async {
    await (delete(
      categoryAccountsOff,
    )..where((r) => r.categoryId.equals(categoryId))).go();
    for (final a in off) {
      await into(categoryAccountsOff).insert(
        CategoryAccountsOffCompanion.insert(
          categoryId: categoryId,
          accountId: a,
        ),
      );
    }
  }

  CategoryPlan _plan(CategoryPlanRow p) => CategoryPlan(
    categoryId: p.categoryId,
    kind: p.kind,
    amount: p.amountMinor,
    start: parseDateKey(p.start),
    due: p.due == null ? null : parseDateKey(p.due!),
    everyMonths: p.everyMonths,
    everyDays: p.everyDays,
    onDates: p.onDates == null || p.onDates!.isEmpty
        ? null
        : [
            for (final piece in p.onDates!.split(','))
              (int.parse(piece.split('-')[0]), int.parse(piece.split('-')[1])),
          ],
    payScheduleId: p.payScheduleId,
    daysAfterPay: p.daysAfterPay,
    weekend: p.weekend,
    weekdays: p.weekdays == null || p.weekdays!.isEmpty
        ? null
        : [for (final piece in p.weekdays!.split(',')) int.parse(piece)],
    nth: p.nth,
    nthWeekday: p.nthWeekday,
    endDate: p.endDate == null ? null : parseDateKey(p.endDate!),
    endCount: p.endCount,
    rollover: p.rollover,
    upTo: p.upToMinor,
    paidFrom: p.paidFromId,
  );

  Expression<bool> _dateIn(
    $BudgetAmountsTable b,
    DateTime start,
    DateTime end,
  ) => b.date.isBetweenValues(dateKey(dateOnly(start)), dateKey(dateOnly(end)));

  BudgetAmount _budgetAmount(BudgetAmountRow b) => BudgetAmount(
    id: b.id,
    categoryId: b.categoryId,
    date: parseDateKey(b.date),
    amount: b.amountMinor,
  );

  Future<List<BudgetAmount>> _budgetIn(
    int categoryId,
    DateTime start,
    DateTime end,
  ) async => [
    for (final b
        in await (select(budgetAmounts)..where(
              (b) => b.categoryId.equals(categoryId) & _dateIn(b, start, end),
            ))
            .get())
      _budgetAmount(b),
  ];

  Future<void> _clearBudgetIn(int categoryId, DateTime start, DateTime end) =>
      (delete(budgetAmounts)..where(
            (b) => b.categoryId.equals(categoryId) & _dateIn(b, start, end),
          ))
          .go();

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
        await delete(budgetAmounts).go();
        await delete(categoryPlans).go();
        await delete(categoryAccountsOff).go();
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
        await incomeCategory();
        await setPreference(startedKey, dateKey(dateOnly(today)));
      });

  Future<void> renameAccount(int accountId, String name) async {
    await _refuseIncome(accountId);
    await (update(accounts)..where((a) => a.id.equals(accountId))).write(
      AccountsCompanion(name: Value(name.trim())),
    );
  }

  /// The app's Income isn't the user's to rename, archive or delete.
  Future<void> _refuseIncome(int accountId) async {
    final rows = await customSelect(
      "SELECT 1 FROM accounts WHERE id = ? AND type = 'income'",
      variables: [Variable.withInt(accountId)],
      readsFrom: {accounts},
    ).get();
    if (rows.isNotEmpty) throw NotFoundException(DbProblem.notCategory);
  }

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

  Future<void> setArchived(int accountId, bool archived) async {
    if (archived) await _refuseIncome(accountId);
    await (update(accounts)..where((a) => a.id.equals(accountId))).write(
      AccountsCompanion(archivedAt: Value(archived ? _now : null)),
    );
  }

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
    weekend: p.weekendKeep
        ? PayWeekend.keep
        : p.weekendBefore
        ? PayWeekend.before
        : PayWeekend.after,
    definesPeriod: p.definesPeriod,
  );

  /// Recent pay into [accountId], newest first: what an estimate should
  /// come from. With [scheduleId], that schedule's own paydays once it has
  /// any; otherwise income from [payee], and nothing with no payer named
  /// (an allowance or interest isn't pay).
  Future<List<int>> payHistory(
    int accountId, {
    int? scheduleId,
    String? payee,
  }) async {
    final categoryId = await incomeCategory();
    final from = payee?.trim() ?? '';
    Future<List<int>> read(bool linked) async {
      final rows = await customSelect(
        'SELECT mine.amount_minor AS amount FROM transactions t '
        'JOIN entries mine ON mine.transaction_id = t.id AND mine.account_id = ?1 '
        'JOIN entries cat ON cat.transaction_id = t.id AND cat.account_id = ?2 '
        '${linked ? '' : 'JOIN payees py ON py.id = t.payee_id AND py.name = ?3 '}'
        'WHERE t.deleted_at IS NULL AND t.scheduled = 0 AND mine.amount_minor > 0 '
        '${linked ? 'AND t.pay_schedule_id = ?3 ' : ''}'
        'ORDER BY t.date DESC, t.id DESC LIMIT 6',
        variables: [
          Variable.withInt(accountId),
          Variable.withInt(categoryId),
          linked ? Variable.withInt(scheduleId!) : Variable.withString(from),
        ],
        readsFrom: {transactions, entries, payees},
      ).get();
      return [for (final r in rows) r.read<int>('amount')];
    }

    if (scheduleId != null) {
      final own = await read(true);
      if (own.isNotEmpty) return own;
    }
    return from.isEmpty ? const [] : read(false);
  }

  /// Adds or changes a pay schedule. With [definesPeriod] the budget runs
  /// by it and no other. Paydays it had scheduled from today on are replaced
  /// by ones from the new plan, and so is the same pay the user had
  /// scheduled by hand in that account within a week of the first payday:
  /// income from the same payer or, with no payer named, of the same
  /// amount.
  Future<PayChange> savePaySchedule({
    int? id,
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
    PayWeekend weekend = PayWeekend.before,
    bool definesPeriod = false,
  }) => transaction(() async {
    final categoryId = await incomeCategory();
    await _assertLive(accountId);
    if (amount <= 0 || (amount2 != null && amount2 <= 0)) {
      throw NotFoundException(DbProblem.payIsIn);
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
      // Keep also writes weekend_before as true (before, the default), so an
      // older reading of the row alone would move it to the Friday before.
      weekendBefore: Value(weekend != PayWeekend.after),
      weekendKeep: Value(weekend == PayWeekend.keep),
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
        'LEFT JOIN payees py ON py.id = t.payee_id '
        'WHERE t.deleted_at IS NULL AND t.scheduled = 1 '
        'AND t.pay_schedule_id IS NULL AND mine.amount_minor > 0 '
        'AND t.date BETWEEN ?3 AND ?4 '
        // Only what is this pay: from the same payer, or with none named,
        // for the same amount. Other income (an allowance) stays.
        'AND (py.name = ?5 OR (?5 IS NULL AND mine.amount_minor IN (?6, ?7)))',
        variables: [
          Variable.withInt(accountId),
          Variable.withInt(categoryId),
          Variable.withString(key(-7)),
          Variable.withString(key(7)),
          Variable<String>(companion.payee.value),
          Variable.withInt(amount),
          Variable.withInt(amount2 ?? amount),
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
    );
  });

  /// Stops a pay schedule: paydays it scheduled from today on go; ones
  /// already past stay to be confirmed.
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
  });

  /// Redo for [savePaySchedule] and [stopPaySchedule].
  Future<void> redoPayChange(PayChange c) => transaction(() async {
    final sid = c.after.id;
    await update(paySchedules).replace(c.after);
    if (c.after.definesPeriod) await _onlyPeriod(sid);
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
              payee: p.payee,
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

  /// A spending category, in one [currency] (rule 28).
  Future<int> createCategory(String name, {Currency currency = Currency.mnt}) =>
      into(accounts).insert(
        AccountsCompanion.insert(
          name: name.trim(),
          type: AccountType.expense,
          currency: Value(currency.code),
        ),
      );

  /// The one income category (rule 30), made the first time it's wanted.
  /// Its rows are in the currency of the account the money came into.
  Future<int> incomeCategory() async {
    // Plain SQL: the upgrade calls this, before later columns exist.
    final existing = await customSelect(
      "SELECT id FROM accounts WHERE type = 'income' ORDER BY id LIMIT 1",
      readsFrom: {accounts},
    ).getSingleOrNull();
    if (existing == null) {
      return addAccount(name: incomeAccountName, type: AccountType.income);
    }
    return existing.read<int>('id');
  }

  /// A category of the user's own: not the app's Income, which holds no
  /// budget and can't be deleted or merged away.
  Future<void> _assertOwnCategory(int id) async {
    await _assertCategory(id);
    await _refuseIncome(id);
  }

  /// Refuses anything but a live income or spending category: a wrong id
  /// must never move a bank account's rows.
  Future<void> _assertCategory(int id) async {
    final a = await (select(
      accounts,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (a == null ||
        a.deletedAt != null ||
        (a.type != AccountType.income && a.type != AccountType.expense)) {
      throw NotFoundException(DbProblem.notCategory);
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
        await _assertOwnCategory(categoryId);
        final moved = <int>[];
        final budgetMoved = <int>[];
        if (into != null) {
          if (into == categoryId) {
            throw NotFoundException(DbProblem.sameCategory);
          }
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
          // What was put in moves too, so a merge keeps the money where it
          // was going. Not into a category in another currency: there the
          // amounts would be read as that currency's, so they stay with
          // the deleted one and go back to not assigned.
          final currencies =
              await (selectOnly(accounts)
                    ..addColumns([accounts.currency])
                    ..where(accounts.id.isIn([categoryId, into])))
                  .map((r) => r.read(accounts.currency))
                  .get();
          final intoIncome = into == await incomeCategory();
          // Nor into Income, which holds no budget.
          if (currencies.toSet().length == 1 && !intoIncome) {
            budgetMoved.addAll(
              await (selectOnly(budgetAmounts)
                    ..addColumns([budgetAmounts.id])
                    ..where(budgetAmounts.categoryId.equals(categoryId)))
                  .map((r) => r.read(budgetAmounts.id)!)
                  .get(),
            );
          }
          await (update(budgetAmounts)..where((b) => b.id.isIn(budgetMoved)))
              .write(BudgetAmountsCompanion(categoryId: Value(into)));
        } else if (await categoryEntryCount(categoryId) > 0) {
          throw LockedException(DbProblem.stillHasRows);
        }
        await (update(accounts)..where((a) => a.id.equals(categoryId))).write(
          AccountsCompanion(deletedAt: Value(_now)),
        );
        return DeletedCategory(categoryId, into, moved, budgetMoved);
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
    await (update(budgetAmounts)
          ..where((b) => b.id.isIn(d.budgetIds) & b.categoryId.equals(into)))
        .write(BudgetAmountsCompanion(categoryId: Value(d.categoryId)));
  });

  /// Undo for adding an account: deletes it only while nothing is in it.
  /// Returns false, deleting nothing, once it holds any live row.
  Future<bool> deleteEmptyAccount(int accountId) => transaction(() async {
    await _refuseIncome(accountId);
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
      throw NotFoundException(DbProblem.accountDeleted);
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
      throw ReconcileDateException(DbProblem.statementAfterToday);
    }
    final last =
        await (selectOnly(reconciliations)
              ..addColumns([reconciliations.statementDate.max()])
              ..where(reconciliations.accountId.equals(accountId)))
            .map((r) => r.read(reconciliations.statementDate.max()))
            .getSingle();
    if (last != null && through.compareTo(last) < 0) {
      throw ReconcileDateException(
        DbProblem.alreadyReconciledThrough,
        through: parseDateKey(last),
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

  static const adjustmentPayee = reconcileAdjustmentPayee;
  static const adjustmentsAccountName = balanceAdjustmentsName;

  /// Equity, like opening balances: an adjustment isn't spending or income.
  Future<int> _adjustmentsAccount() => _equityAccount(adjustmentsAccountName);

  Future<int?> _findEquity(String name) async =>
      (await (select(accounts)
                ..where(
                  (a) =>
                      a.name.equals(name) &
                      a.type.equalsValue(AccountType.equity),
                )
                ..limit(1))
              .getSingleOrNull())
          ?.id;

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
        if (newestFirst.isEmpty) {
          throw NotFoundException(DbProblem.neverReconciled);
        }
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

  // ---------- import (ADR 0002) ----------

  /// The preference a bank file's column mapping is kept under, per account.
  static String importMappingKey(int accountId) => 'import.mapping.$accountId';

  /// What each row of a bank file would do: be added, mark a row the user
  /// typed as cleared (the same amount within a few days, on an entry not
  /// imported before), or be skipped as already in the ledger by its key.
  /// Deleted rows count as already in, so a row the user deleted stays
  /// deleted.
  Future<ImportPlan> planImport(
    int accountId,
    List<ImportRow> rows,
    List<String> keys,
  ) async {
    final known = <String>{};
    for (var i = 0; i < keys.length; i += 500) {
      final chunk = keys.sublist(i, (i + 500).clamp(0, keys.length));
      final found =
          await (selectOnly(entries)
                ..addColumns([entries.importKey])
                ..where(entries.importKey.isIn(chunk)))
              .get();
      known.addAll(found.map((r) => r.read(entries.importKey)!));
    }
    // Rows typed on this account near the file's dates, never a starting
    // balance or an adjustment (the other side is an equity account).
    // Reconciled ones match too, or they'd come in twice.
    var from = rows.isEmpty ? DateTime(1900) : dateOnly(rows.first.date);
    var to = from;
    for (final r in rows) {
      final d = dateOnly(r.date);
      if (d.isBefore(from)) from = d;
      if (d.isAfter(to)) to = d;
    }
    final typed = await customSelect(
      'SELECT e.id AS entry_id, e.amount_minor AS amount, e.cleared AS cleared, '
      't.id AS txn_id, t.date AS date, t.memo AS memo, p.name AS payee '
      'FROM entries e JOIN transactions t ON t.id = e.transaction_id '
      'LEFT JOIN payees p ON p.id = t.payee_id '
      'WHERE e.account_id = ? AND t.deleted_at IS NULL AND t.scheduled = 0 '
      'AND e.import_key IS NULL AND NOT EXISTS (SELECT 1 FROM entries o '
      'JOIN accounts a ON a.id = o.account_id WHERE o.transaction_id = t.id '
      "AND o.id != e.id AND a.type = 'equity') AND t.date BETWEEN ? AND ?",
      variables: [
        Variable.withInt(accountId),
        Variable.withString(
          dateKey(from.subtract(const Duration(days: matchDaysAfter))),
        ),
        Variable.withString(
          dateKey(to.add(const Duration(days: matchDaysBefore))),
        ),
      ],
      readsFrom: {entries, transactions, payees, accounts},
    ).get();
    final used = <int>{};
    final plan = <ImportPlanRow>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      if (known.contains(keys[i])) {
        plan.add(ImportPlanRow(row: r, key: keys[i], fate: ImportFate.already));
        continue;
      }
      final bankDay = dateOnly(r.date);
      QueryRow? best;
      var bestGap = 1 << 30;
      for (final t in typed) {
        if (used.contains(t.read<int>('entry_id'))) continue;
        if (t.read<int>('amount') != r.amount) continue;
        // The bank posts on the day or a few days after; rarely before.
        final gap = bankDay
            .difference(parseDateKey(t.read<String>('date')))
            .inDays;
        if (gap < -matchDaysBefore || gap > matchDaysAfter) continue;
        if (gap.abs() < bestGap) {
          bestGap = gap.abs();
          best = t;
        }
      }
      if (best == null) {
        plan.add(ImportPlanRow(row: r, key: keys[i], fate: ImportFate.add));
        continue;
      }
      used.add(best.read<int>('entry_id'));
      plan.add(
        ImportPlanRow(
          row: r,
          key: keys[i],
          fate: ImportFate.match,
          match: TypedMatch(
            transactionId: best.read<int>('txn_id'),
            entryId: best.read<int>('entry_id'),
            date: parseDateKey(best.read<String>('date')),
            payee: best.read<String?>('payee') ?? '',
            cleared: Cleared.values[best.read<int>('cleared')],
            hasMemo: (best.read<String?>('memo') ?? '').trim().isNotEmpty,
          ),
        ),
      );
    }

    final opening = await _openingOf(accountId);
    final fresh = plan.where((p) => p.fate != ImportFate.already).toList();
    if (fresh.isEmpty) return ImportPlan(rows: plan, opening: opening);
    var first = dateOnly(fresh.first.row.date);
    var last = first;
    for (final p in fresh) {
      final d = dateOnly(p.row.date);
      if (d.isBefore(first)) first = d;
      if (d.isAfter(last)) last = d;
    }
    bool within(DateTime d) => !d.isBefore(first) && !d.isAfter(last);
    final unmatched = [
      for (final t in typed)
        if (!used.contains(t.read<int>('entry_id')) &&
            Cleared.values[t.read<int>('cleared')] == Cleared.uncleared &&
            within(parseDateKey(t.read<String>('date'))))
          UnmatchedTyped(
            parseDateKey(t.read<String>('date')),
            t.read<String?>('payee') ?? '',
            t.read<int>('amount'),
          ),
    ]..sort((a, b) => a.date.compareTo(b.date));
    final before = await customSelect(
      'SELECT COUNT(*) AS n FROM entries e '
      'JOIN transactions t ON t.id = e.transaction_id '
      'WHERE e.account_id = ? AND e.import_key IS NOT NULL '
      'AND t.deleted_at IS NULL AND t.date BETWEEN ? AND ?',
      variables: [
        Variable.withInt(accountId),
        Variable.withString(dateKey(first)),
        Variable.withString(dateKey(last)),
      ],
      readsFrom: {entries, transactions},
    ).getSingle();
    return ImportPlan(
      rows: plan,
      unmatched: unmatched,
      importedBefore: before.read<int>('n'),
      firstDay: first,
      lastDay: last,
      opening: opening,
    );
  }

  /// [accountId]'s opening balance (its earliest row against Opening
  /// balances), or null.
  Future<OpeningBalance?> _openingOf(int accountId) async {
    final row = await customSelect(
      'SELECT t.id AS txn_id, t.date AS date, e.amount_minor AS amount, '
      'e.cleared AS cleared FROM entries e '
      'JOIN transactions t ON t.id = e.transaction_id '
      'JOIN entries o ON o.transaction_id = t.id AND o.id != e.id '
      'JOIN accounts a ON a.id = o.account_id '
      "WHERE e.account_id = ? AND t.deleted_at IS NULL AND a.type = 'equity' "
      'AND a.name = ? ORDER BY t.date, t.id LIMIT 1',
      variables: [
        Variable.withInt(accountId),
        Variable.withString(openingBalancesName),
      ],
      readsFrom: {entries, transactions, accounts},
    ).getSingleOrNull();
    if (row == null) return null;
    return OpeningBalance(
      transactionId: row.read<int>('txn_id'),
      date: parseDateKey(row.read<String>('date')),
      amount: row.read<int>('amount'),
      locked: row.read<int>('cleared') == Cleared.reconciled.index,
    );
  }

  Future<void> _setOpening(int transactionId, DateTime date, int amount) async {
    await (update(
      transactions,
    )..where((t) => t.id.equals(transactionId))).write(
      TransactionsCompanion(date: Value(dateKey(date)), updatedAt: Value(_now)),
    );
    final rows = await (select(
      entries,
    )..where((e) => e.transactionId.equals(transactionId))).get();
    final types = await _accountTypes();
    for (final e in rows) {
      final equity = types[e.accountId] == AccountType.equity;
      await (update(entries)..where((x) => x.id.equals(e.id))).write(
        EntriesCompanion(amountMinor: Value(equity ? -amount : amount)),
      );
    }
    await _assertBalanced(transactionId);
  }

  /// How far a typed row's date may be from the bank's and still match.
  static const matchDaysBefore = 3, matchDaysAfter = 10;

  /// Writes [plan] to [accountId] in one go: new rows come in cleared, with
  /// the category (income or spending, never another account) last used for
  /// their payee here, else the holding category found by any of
  /// [uncategorizedNames] or made as the first. Matched rows take the bank's
  /// key, become cleared, and keep the bank's text as a memo if they had
  /// none. Rows already in or left out are untouched.
  Future<ImportRecord> applyImport({
    required int accountId,
    required List<ImportPlanRow> plan,
    required List<String> uncategorizedNames,
    ({DateTime date, int amount})? moveOpening,
  }) => transaction(() async {
    await _assertLive(accountId);
    final categories = {
      for (final a
          in await (select(accounts)..where(
                (a) =>
                    a.deletedAt.isNull() &
                    a.archivedAt.isNull() &
                    a.type.isInValues([
                      AccountType.income,
                      AccountType.expense,
                    ]),
              ))
              .get())
        a.id,
    };
    int? made;
    int? fallback;
    var holding = 0;
    Future<int> uncategorized() async {
      holding++;
      if (fallback != null) return fallback!;
      final existing =
          await (select(accounts)..where(
                (a) =>
                    a.name.isIn(uncategorizedNames) &
                    a.type.equalsValue(AccountType.expense) &
                    a.deletedAt.isNull() &
                    a.archivedAt.isNull(),
              ))
              .get();
      if (existing.isNotEmpty) return fallback = existing.first.id;
      return fallback = made = await createCategory(uncategorizedNames.first);
    }

    final remembered = <String, int?>{};
    final added = <int, String>{};
    final matched = <MatchedImport>[];
    for (final p in plan) {
      switch (p.fate) {
        case ImportFate.already || ImportFate.leftOut:
          continue;
        case ImportFate.add:
          final payee = p.row.payee;
          final last = remembered.containsKey(payee)
              ? remembered[payee]
              : remembered[payee] = await lastCategoryFor(payee, accountId);
          final category = last != null && categories.contains(last)
              ? last
              : await uncategorized();
          final id = await postTransaction(
            date: dateOnly(p.row.date),
            payee: payee,
            memo: p.row.memo,
            lines: [
              (
                accountId: accountId,
                amount: p.row.amount,
                cleared: Cleared.cleared,
              ),
              (
                accountId: category,
                amount: -p.row.amount,
                cleared: Cleared.uncleared,
              ),
            ],
          );
          added[id] = p.key;
        case ImportFate.match:
          final m = p.match!;
          final text = p.row.memo ?? p.row.payee;
          final redated = matchedDate(m, p.row.date);
          matched.add(
            MatchedImport(
              m.transactionId,
              m.entryId,
              m.cleared,
              p.key,
              dateBefore: redated == m.date ? null : m.date,
              dateAfter: redated == m.date ? null : redated,
              // A reconciled row is locked: it takes the key and nothing else.
              memo:
                  m.hasMemo ||
                      m.cleared == Cleared.reconciled ||
                      text.trim().isEmpty
                  ? null
                  : text.trim(),
            ),
          );
      }
    }
    OpeningMove? openingMove;
    final opening = moveOpening == null ? null : await _openingOf(accountId);
    if (moveOpening != null && opening != null && !opening.locked) {
      openingMove = (
        transactionId: opening.transactionId,
        fromDate: opening.date,
        fromAmount: opening.amount,
        toDate: dateOnly(moveOpening.date),
        toAmount: moveOpening.amount,
      );
      await _setOpening(
        opening.transactionId,
        openingMove.toDate,
        openingMove.toAmount,
      );
    }
    final record = ImportRecord(
      added: added,
      matched: matched,
      madeCategory: made,
      uncategorizedCount: holding,
      openingMove: openingMove,
    );
    await _keyAdded(accountId, record);
    await _applyMatches(record);
    return record;
  });

  Future<void> _keyAdded(int accountId, ImportRecord r) async {
    for (final e in r.added.entries) {
      await (update(entries)..where(
            (x) =>
                x.transactionId.equals(e.key) & x.accountId.equals(accountId),
          ))
          .write(EntriesCompanion(importKey: Value(e.value)));
    }
  }

  Future<void> _applyMatches(ImportRecord r) async {
    for (final m in r.matched) {
      await (update(entries)..where((e) => e.id.equals(m.entryId))).write(
        EntriesCompanion(importKey: Value(m.key)),
      );
      if (m.before == Cleared.uncleared) {
        await (update(entries)..where(
              (e) =>
                  e.id.equals(m.entryId) &
                  e.cleared.equalsValue(Cleared.uncleared),
            ))
            .write(const EntriesCompanion(cleared: Value(Cleared.cleared)));
      }
      await (update(
        transactions,
      )..where((t) => t.id.equals(m.transactionId))).write(
        TransactionsCompanion(
          memo: m.memo == null ? const Value.absent() : Value(m.memo),
          date: m.dateAfter == null
              ? const Value.absent()
              : Value(dateKey(m.dateAfter!)),
          updatedAt: Value(_now),
        ),
      );
    }
  }

  /// Takes an import back: its new rows go (their keys freed, so the same
  /// file can come in again), matched rows lose the key, their memo from the
  /// bank, and go back to uncleared; a category it made goes if nothing else
  /// uses it.
  Future<void> undoImport(ImportRecord r) => transaction(() async {
    final ids = r.added.keys.toList();
    final gone = await softDeleteMany(ids);
    if (gone.length != ids.length) throw LockedException(DbProblem.reconciled);
    await (update(entries)..where((e) => e.transactionId.isIn(ids))).write(
      const EntriesCompanion(importKey: Value(null)),
    );
    for (final m in r.matched) {
      await (update(entries)..where((e) => e.id.equals(m.entryId))).write(
        const EntriesCompanion(importKey: Value(null)),
      );
      // Only a row still cleared goes back: one reconciled since stays.
      if (m.before == Cleared.uncleared) {
        await (update(entries)..where(
              (e) =>
                  e.id.equals(m.entryId) &
                  e.cleared.equalsValue(Cleared.cleared),
            ))
            .write(const EntriesCompanion(cleared: Value(Cleared.uncleared)));
      }
      if (m.memo != null) {
        await (update(transactions)..where(
              (t) => t.id.equals(m.transactionId) & t.memo.equals(m.memo!),
            ))
            .write(const TransactionsCompanion(memo: Value(null)));
      }
      if (m.dateBefore != null) {
        await (update(transactions)..where((t) => t.id.equals(m.transactionId)))
            .write(TransactionsCompanion(date: Value(dateKey(m.dateBefore!))));
      }
    }
    if (r.openingMove case final o?) {
      await _setOpening(o.transactionId, o.fromDate, o.fromAmount);
    }
    if (r.madeCategory case final c?) await deleteEmptyAccount(c);
  });

  Future<void> redoImport(ImportRecord r, int accountId) =>
      transaction(() async {
        if (r.madeCategory case final c?) {
          await undeleteAccount(DeletedAccount(c, const []));
        }
        await restoreMany(r.added.keys);
        await _keyAdded(accountId, r);
        await _applyMatches(r);
        if (r.openingMove case final o?) {
          await _setOpening(o.transactionId, o.toDate, o.toAmount);
        }
      });

  Future<int?> _payeeId(String? name) async {
    final n = name?.trim();
    if (n == null || n.isEmpty) return null;
    final existing = await (select(
      payees,
    )..where((p) => p.name.equals(n))).getSingleOrNull();
    return existing?.id ??
        await into(payees).insert(PayeesCompanion.insert(name: n));
  }

  /// Each currency's entries add up to zero on their own (ROADMAP E).
  Future<void> _assertBalanced(int txnId) async {
    final rows = await customSelect(
      'SELECT currency, COALESCE(SUM(amount_minor), 0) AS s, COUNT(*) AS n '
      'FROM entries WHERE transaction_id = ? GROUP BY currency',
      variables: [Variable.withInt(txnId)],
    ).get();
    final count = rows.fold(0, (n, r) => n + r.read<int>('n'));
    final off = rows.where((r) => r.read<int>('s') != 0).firstOrNull;
    if (off != null || count < 2) {
      throw UnbalancedTransactionException(txnId, off?.read<int>('s') ?? 0);
    }
  }

  Future<void> _touch(int txnId) =>
      (update(transactions)..where((t) => t.id.equals(txnId))).write(
        TransactionsCompanion(updatedAt: Value(_now)),
      );
}
