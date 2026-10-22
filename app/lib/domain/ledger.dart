/// Turns double-entry storage (ADR 0003) into what the register shows.
/// Pure Dart: no database, no Flutter.
library;

import 'money.dart';
import 'pay.dart';
import 'payee_rules.dart';

enum AccountType { asset, liability, income, expense, equity }

/// The sidebar buckets the app makes itself. They double as the Type the
/// user picked on Add account: cash and a bank account are both
/// [AccountType.asset] to the ledger, and only this tells them apart
/// (ADR 0004, "Cash is its own Type"). Anything else in the column is a
/// group the ledger came with, and is shown as it's stored.
abstract final class LedgerGroups {
  static const cash = 'Cash';
  static const bank = 'Bank';
  static const credit = 'Credit';
}

enum Cleared { uncleared, cleared, reconciled }

/// What an account is for on the Savings steps (ADR 0004, rule 25). A bank
/// account can hold the emergency fund; a card or loan is consumer debt
/// unless it's one of the others.
enum AccountRole { emergencyFund, mortgage, studentLoan, paidMonthly }

enum RowKind { simple, split, transfer, opening }

/// The equity accounts the app makes itself, by the name each is stored
/// under. The names are in English; `rowCategory` in ui/data_words.dart
/// words them for the screen.
const openingBalancesAccountName = 'Opening balances';
const balanceAdjustmentsName = 'Balance adjustments';

/// Where a transfer between currencies passes through, so each currency's
/// entries still add up to zero with no rate stored (ROADMAP E).
const currencyExchangeName = 'Currency exchange';

/// The one income category, which the app makes itself (rule 30): money
/// coming in that isn't a refund is filed under it. Stored under this name;
/// [LedgerData.withIncomeNamed] gives it the user's word on screen.
const incomeAccountName = 'Income';

/// Income's name in every language the app speaks: no category of the
/// user's own may be called any of them.
const incomeNames = {'Income', 'Орлого'};

bool isIncomeName(String name) =>
    incomeNames.any((n) => n.toLowerCase() == name.trim().toLowerCase());

/// The payee a reconcile adjustment is stored with (`rowPayee` words it).
const reconcileAdjustmentPayee = 'Reconcile adjustment';

/// An opening row against one of the app's own equity accounts: a starting
/// balance, or the difference a reconcile posted to match a statement.
enum AppEquity { openingBalances, adjustments }

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// A calendar date as stored: `YYYY-MM-DD` (ADR 0001).
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDateKey(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

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
    this.role,
    this.currency = Currency.mnt,
  });

  /// What its money is in. A spending category has one too (rule 28): its
  /// amounts are in it, and the ledger's lists offer it to rows in it.
  final Currency currency;

  /// What it's for on the Savings steps; null for most accounts.
  final AccountRole? role;

  final int id;
  final String name;
  final AccountType type;
  final String? institution;
  final String? mask;
  final String? group;

  /// Cash in hand, not money in a bank: nothing to reconcile against and no
  /// file to import. Still an asset, and still counts as money to budget.
  bool get isCash => group == LedgerGroups.cash;
  final int sortOrder;

  /// Out of the sidebar and the account lists, still in net worth.
  final bool archived;

  /// Deleted with its own rows. What's left of it is the far side of
  /// transfers kept on other accounts, so it counts nowhere.
  final bool deleted;

  /// Accounts the user holds money in, as opposed to categories.
  bool get isBalanceSheet =>
      type == AccountType.asset || type == AccountType.liability;

  /// How other accounts' rows name it, in English (`accountLabel` in
  /// ui/data_words.dart words it for the screen).
  String get label => deleted ? '$name (deleted)' : name;

  /// A credit account: what's owed reads as a positive amount, the way the
  /// bank shows it, and owing is never a warning.
  bool get isOwed => type == AccountType.liability;

  /// The app's one income category (rule 30).
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
    this.currency = Currency.mnt,
  });

  final int id;
  final int accountId;
  final Currency currency;

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
    this.payScheduleId,
    this.planCategoryId,
    this.madeHow,
    this.madeOn,
  });

  /// How it came to be ([MadeHow]) and where: a computer's name, or a
  /// phone's id. Null for a row from before this was kept.
  final String? madeHow;
  final String? madeOn;

  /// A payday a pay schedule scheduled.
  final int? payScheduleId;

  /// A bill a category's plan scheduled (rule 27), by the category.
  final int? planCategoryId;
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

/// One category of a split row, in the row's sign convention. [deleted] is
/// the account's plain name when it's been deleted ([name] then says so in
/// English).
typedef SplitLine = ({int accountId, String name, int amount, String? deleted});

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
    this.deletedOther,
    this.equity,
    this.accountId = 0,
    this.clearedIn,
    this.estimate,
    this.payScheduleId,
    this.planCategoryId,
    this.balance = 0,
    this.clearedBalance = 0,
    this.currency = Currency.mnt,
    this.otherAmount,
    this.otherCurrency,
    this.projected = false,
    this.madeHow,
    this.madeOn,
  });

  /// Where the transaction came from, as [TxnData] holds it.
  final String? madeHow;
  final String? madeOn;

  /// Not a row in the ledger: a payday or a plan's bill the forecast
  /// expects after the scheduled one, drawn from it ([copyWith]).
  final bool projected;

  /// What [amount] and the balances are in: the account's currency.
  final Currency currency;

  /// A transfer between currencies: what the other account sent or got, in
  /// its own currency, from its own side.
  final int? otherAmount;
  final Currency? otherCurrency;

  final int txnId;
  final int entryId;
  final DateTime date;
  final String payee;
  final String memo;
  final int amount;
  final Cleared cleared;
  final bool scheduled;
  final RowKind kind;

  /// "Transfer" and "3 categories" are in English here; `rowCategory` in
  /// ui/data_words.dart words them for the screen, as `rowPayee` does an
  /// opening balance's "Opening balance".
  final String categoryLabel;

  /// Set only for simple rows, where the category can be edited inline.
  final int? categoryId;

  /// [SplitLine.name] is in English for a deleted account; its
  /// [SplitLine.deleted] holds the plain name, for the UI to word.
  final List<SplitLine> splitLines;

  /// A transfer whose other account is deleted: that account's name. [payee]
  /// then reads "… (deleted)" in English; the UI words it from this.
  final String? deletedOther;

  /// An opening row against an equity account the app made: which one.
  /// [categoryLabel] then holds its stored English name, for the UI to word.
  final AppEquity? equity;

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

  /// Filed under Income, not a refund or a transfer.
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

  /// A payday a pay schedule scheduled.
  final int? payScheduleId;

  /// A bill a category's plan scheduled (rule 27), by the category.
  final int? planCategoryId;

  /// A payday from pay that varies: the least it's likely to be. Coming in
  /// under it isn't "still owed", and the forecast calls it an estimate.
  final int? estimate;
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
    deletedOther: deletedOther,
    equity: equity,
    accountId: accountId,
    clearedIn: clearedIn,
    estimate: estimate,
    payScheduleId: payScheduleId,
    planCategoryId: planCategoryId,
    balance: balance,
    clearedBalance: clearedBalance,
    currency: currency,
    otherAmount: otherAmount,
    otherCurrency: otherCurrency,
    madeHow: madeHow,
    madeOn: madeOn,
  );

  /// The same row on another day, or for another amount: a payday or a
  /// plan's bill the forecast projects past the one that's scheduled.
  RegisterRow copyWith({DateTime? date, int? amount, bool? projected}) =>
      RegisterRow(
        txnId: txnId,
        entryId: entryId,
        date: date ?? this.date,
        payee: payee,
        memo: memo,
        amount: amount ?? this.amount,
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
        deletedOther: deletedOther,
        equity: equity,
        accountId: accountId,
        clearedIn: clearedIn,
        estimate: estimate,
        payScheduleId: payScheduleId,
        planCategoryId: planCategoryId,
        balance: balance,
        clearedBalance: clearedBalance,
        currency: currency,
        otherAmount: otherAmount,
        otherCurrency: otherCurrency,
        projected: projected ?? this.projected,
        madeHow: madeHow,
        madeOn: madeOn,
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
    deletedOther: deletedOther,
    equity: equity,
    accountId: accountId,
    estimate: estimate,
    payScheduleId: payScheduleId,
    planCategoryId: planCategoryId,
    balance: b,
    clearedBalance: clearedTotal,
    currency: currency,
    otherAmount: otherAmount,
    otherCurrency: otherCurrency,
    madeHow: madeHow,
    madeOn: madeOn,
  );
}

/// Uncleared this long in an account never reconciled, a row says so:
/// longer than a card hold usually lasts, so it may never have happened
/// (cancelled, or entered twice), yet it still counts in Working.
const staleUnclearedDays = 14;

/// On a card or loan a hold from abroad sits 20 to 30 days before it
/// clears, so its rows wait longer before they say anything.
const staleUnclearedDaysOwed = 30;

/// A row this close before a statement is likely a hold the statement was
/// too early for, not a row the bank never had.
const statementGraceDays = 3;

/// Past its account's last statement, a row says its age only this late:
/// longer than a month between reconciles and a hold together, so someone
/// who reconciles monthly never sees it.
const staleAfterStatementDays = 45;

/// What an account's uncleared rows are held against (ADR 0004 rule 20):
/// its last statement once it has been reconciled, and their age, counted
/// longer where it's [owed]. Null for cash: nothing ever clears it.
typedef UnclearedCheck = ({DateTime? statement, bool owed});

/// Whole days from [date] to [today].
int daysBefore(DateTime date, DateTime today) =>
    // In UTC: across a daylight-saving change local days are 23 or 25 hours.
    DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime.utc(date.year, date.month, date.day)).inDays;

/// Why an uncleared row may be wrong, if it may be: it is dated long enough
/// before [statement] that the statement should have had it, or it has
/// waited [days] with no statement to go by. Otherwise null.
({DateTime? statement, int? days})? unclearedDoubt(
  RegisterRow r,
  DateTime today,
  UnclearedCheck? check,
) {
  if (check == null || r.scheduled || r.cleared != Cleared.uncleared) {
    return null;
  }
  final hold = check.owed ? staleUnclearedDaysOwed : staleUnclearedDays;
  final days = daysBefore(r.date, today);
  final statement = check.statement;
  if (statement == null) {
    return days >= hold ? (statement: null, days: days) : null;
  }
  final grace = check.owed ? staleUnclearedDaysOwed : statementGraceDays;
  if (daysBefore(r.date, statement) >= grace) {
    return (statement: statement, days: null);
  }
  return days >= staleAfterStatementDays ? (statement: null, days: days) : null;
}

/// Days a scheduled row is past its date (it isn't in Working until it's
/// confirmed); otherwise null.
int? overdueDays(RegisterRow r, DateTime today) {
  if (!r.scheduled) return null;
  final days = daysBefore(r.date, today);
  return days <= 0 ? null : days;
}

/// "due 7 days ago" ([overdueDays]), in English; the UI words it with
/// `overdueNoteIn` (ui/data_words.dart).
String? overdueNote(RegisterRow r, DateTime today) =>
    switch (overdueDays(r, today)) {
      1 => 'due yesterday',
      final days? => 'due $days days ago',
      null => null,
    };

/// The setting that keeps the rows the person said didn't pay scheduled
/// bill [txnId] ("Not it"), as their ids joined by commas.
String billNotItKey(int txnId) => '$billNotItPrefix$txnId';

/// What every [billNotItKey] starts with.
const billNotItPrefix = 'bill.notIt.';

/// What every setting about bills starts with: their values hold rows'
/// ids, the same on every computer.
const billPrefsPrefix = 'bill.';

/// The setting that marks scheduled bill [txnId] as one there won't be
/// ("No bill this time", or paid ahead with the one before), as its
/// category's id and date: `12;2026-10-15`. The budget asks nothing for it.
String billSkippedKey(int txnId) => 'bill.skipped.$txnId';

/// What every [billSkippedKey] starts with.
const billSkippedPrefix = 'bill.skipped.';

/// The setting on a row taken as a bill paid ([AppDatabase.payBill]):
/// which bill, what it was for before a part payment left the rest
/// (empty when it went), and the bills after it paid with it. "Not this
/// bill" puts back exactly that.
String billPaidKey(int rowTxnId) => 'bill.paid.$rowTxnId';

/// A [billPaidKey]'s value: the bill, its date (the budget counts the row
/// on it, however late it was paid), what it was for before a part
/// payment, and the bills skipped with it.
typedef BillPaidRecord = ({
  int bill,
  DateTime? date,
  int? amount,
  List<int> skipped,
});

String encodeBillPaid(BillPaidRecord r) =>
    '${r.bill};${r.amount ?? ''};${r.skipped.join(',')};'
    '${r.date == null ? '' : dateKey(r.date!)}';

BillPaidRecord? decodeBillPaid(String? s) {
  final parts = (s ?? '').split(';');
  final bill = int.tryParse(parts.first);
  if (bill == null) return null;
  DateTime? date;
  if (parts.length > 3 && parts[3].isNotEmpty) {
    try {
      date = parseDateKey(parts[3]);
    } catch (_) {}
  }
  return (
    bill: bill,
    date: date,
    amount: parts.length > 1 ? int.tryParse(parts[1]) : null,
    skipped: [
      if (parts.length > 2)
        for (final x in parts[2].split(',')) ?int.tryParse(x),
    ],
  );
}

/// The rows said not to have paid bill [txnId] ([billNotItKey]).
Set<int> billNotIt(Map<String, String> prefs, int txnId) => {
  for (final part in (prefs[billNotItKey(txnId)] ?? '').split(','))
    ?int.tryParse(part),
};

/// A scheduled row and one already in this near in date may be the same
/// bill. Under a week, so a weekly bill doesn't find last week's.
const alreadyInDays = 6;

/// A split is the same kind of row as one with a single category, for
/// telling that a bill is already in: a receipt typed over two categories
/// is still the bill paid.
RowKind _kindFor(RowKind k) => k == RowKind.split ? RowKind.simple : k;

const _latinFor = {
  'а': 'a',
  'б': 'b',
  'в': 'v',
  'г': 'g',
  'д': 'd',
  'е': 'e',
  'ё': 'io',
  'ж': 'j',
  'з': 'z',
  'и': 'i',
  'й': 'i',
  'к': 'k',
  'л': 'l',
  'м': 'm',
  'н': 'n',
  'о': 'o',
  'ө': 'o',
  'п': 'p',
  'р': 'r',
  'с': 's',
  'т': 't',
  'у': 'u',
  'ү': 'u',
  'ф': 'f',
  'х': 'h',
  'ц': 'ts',
  'ч': 'ch',
  'ш': 'sh',
  'щ': 'sh',
  'ъ': '',
  'ы': 'i',
  'ь': '',
  'э': 'e',
  'ю': 'iu',
  'я': 'ia',
};

/// A payee reduced to what two spellings of one name share, to tell that
/// the bank's "МОБИКОМ КОРПОРАЦИ ХХК" is a bill called "Mobicom": lower
/// case, Cyrillic in Latin letters, the letters people swap made one (c and
/// k, kh and h, w and v, y and i), and nothing but letters and digits.
String payeeKey(String payee) {
  final latin = StringBuffer();
  for (final rune in payee.trim().toLowerCase().runes) {
    final c = String.fromCharCode(rune);
    latin.write(_latinFor[c] ?? c);
  }
  return latin
      .toString()
      .replaceAll('kh', 'h')
      .replaceAll(RegExp('c(?!h)'), 'k')
      .replaceAll('w', 'v')
      .replaceAll('y', 'i')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
}

/// Two payees are the same name: one's [payeeKey] holds the other's. A
/// name under four letters has to be the whole of the other, since "TDB"
/// is inside too many.
bool samePayeeName(String a, String b) {
  final x = payeeKey(a), y = payeeKey(b);
  if (x.isEmpty || y.isEmpty) return false;
  if (x == y) return true;
  final (short, long) = x.length <= y.length ? (x, y) : (y, x);
  return short.length >= 4 && long.contains(short);
}

/// The row already in [posted] that [scheduled] looks to be, so that
/// confirming would put it in twice (typed from the bank app, entered on
/// the phone, or imported, before the bill was confirmed): in any account
/// of the same currency (a bill scheduled in one account is often paid
/// from another), the same way, dated within [alreadyInDays] of the bill,
/// or up to [today] for a late one (paid late, it is dated late). What
/// makes it the bill, the surest first, each for between half and twice
/// the amount: the same payee as typed; the same name in another spelling
/// ([samePayeeName]); for a category's bill, a row in that category. Last,
/// a row still in [uncategorizedId] (as an import leaves it, under the
/// bank's own name) for exactly the amount. Among equals one in the bill's own
/// account, then the nearest in date; null when there is none. A row
/// already tied to a plan's bill paid that bill, not this one, and one in
/// [notIt] the person said isn't it. Not for a payday: money in is made a
/// pay's paycheck from its own row.
/// A split (one receipt over several categories) is found as an ordinary
/// row with the same payee, dates and total would be.
RegisterRow? alreadyIn(
  RegisterRow scheduled,
  Iterable<RegisterRow> posted,
  DateTime today, {
  int? uncategorizedId,
  Set<int> notIt = const {},
}) {
  if (scheduled.payScheduleId != null) return null;
  final payee = scheduled.payee.trim().toLowerCase();
  final plan = scheduled.planCategoryId;
  final late = daysBefore(scheduled.date, today);
  final after = late > alreadyInDays ? late : alreadyInDays;
  RegisterRow? found;
  var foundSure = 0;
  var foundHere = false;
  var nearest = 0;
  for (final r in posted) {
    if (r.scheduled ||
        r.projected ||
        r.currency != scheduled.currency ||
        _kindFor(r.kind) != _kindFor(scheduled.kind) ||
        (r.amount < 0) != (scheduled.amount < 0) ||
        r.planCategoryId != null ||
        r.payScheduleId != null ||
        notIt.contains(r.txnId)) {
      continue;
    }
    final since = daysBefore(scheduled.date, r.date);
    if (since < -alreadyInDays || since > after) continue;
    // About the bill's size: rent paid in halves is, a ₮5,000 top-up
    // against a ₮41,500 phone bill isn't, nor a phone bought at Mobicom.
    final about =
        r.amount.abs() * 2 >= scheduled.amount.abs() &&
        r.amount.abs() <= scheduled.amount.abs() * 2;
    final int sure;
    if (!about && r.categoryId != uncategorizedId) {
      continue;
    } else if (about &&
        payee.isNotEmpty &&
        r.payee.trim().toLowerCase() == payee) {
      sure = 4;
    } else if (about && samePayeeName(r.payee, scheduled.payee)) {
      sure = 3;
    } else if (about && plan != null && r.categoryId == plan) {
      sure = 2;
    } else if (uncategorizedId != null &&
        r.categoryId == uncategorizedId &&
        r.amount == scheduled.amount) {
      sure = 1;
    } else {
      continue;
    }
    final apart = since.abs();
    final here = r.accountId == scheduled.accountId;
    if (found == null ||
        sure > foundSure ||
        (sure == foundSure &&
            ((here && !foundHere) ||
                (here == foundHere &&
                    (apart < nearest ||
                        (apart == nearest && r.date.isAfter(found.date))))))) {
      found = r;
      foundSure = sure;
      foundHere = here;
      nearest = apart;
    }
  }
  return found;
}

enum ReconcileCause { notCleared, datedAfter, clearedEarly }

/// [row] is the row as its register shows it, for the UI to name.
typedef ReconcileHint = ({
  int txnId,
  DateTime date,
  RegisterRow row,
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

/// Money put into a spending category for the budget period starting
/// [date] (rule 26).
class BudgetAmount {
  const BudgetAmount({
    required this.categoryId,
    required this.date,
    required this.amount,
    this.id,
  });

  /// Its row, so an undo puts back the same one (a merge's undo finds it).
  final int? id;
  final int categoryId;
  final DateTime date;
  final int amount;
}

/// What a spending category is for, which decides how much it should be
/// assigned each period (rule 27).
enum PlanKind {
  /// Money goes out any time: a set amount each period, spent down
  /// (groceries) or built up until it's needed (car repairs).
  each,

  /// Money goes out on a date: an amount by a date, once (a birthday) or
  /// again every so many months (a bill), saved for in parts.
  byDate,
}

/// A spending category's plan (rule 27). One per category at most.
class CategoryPlan {
  const CategoryPlan({
    required this.categoryId,
    required this.kind,
    required this.amount,
    required this.start,
    this.due,
    this.everyMonths,
    this.everyDays,
    this.onDates,
    this.payScheduleId,
    this.daysAfterPay = 0,
    this.weekend = PayWeekend.keep,
    this.weekdays,
    this.nth,
    this.nthWeekday,
    this.endDate,
    this.endCount,
    this.rollover = true,
    this.upTo,
    this.paidFrom,
  });

  final int categoryId;
  final PlanKind kind;

  /// [PlanKind.each]: what goes in each period. [PlanKind.byDate]: the
  /// amount wanted by the date.
  final int amount;

  /// The day the plan was made: a bill's parts count from the period
  /// this day is in.
  final DateTime start;

  /// [PlanKind.byDate]: the date, or the first of them when it repeats;
  /// null when it follows paydays.
  final DateTime? due;

  /// [PlanKind.byDate]: it comes again every this many months (12 a
  /// year, 3 a quarter). One of the four ways to repeat, or none: once.
  final int? everyMonths;

  /// [PlanKind.byDate]: every this many days (7 a week, 14 every two).
  final int? everyDays;

  /// [PlanKind.byDate]: on these dates each year, as (month, day), when
  /// the gaps aren't even (taxes four times a year).
  final List<(int, int)>? onDates;

  /// [PlanKind.byDate]: every payday of this pay schedule, [daysAfterPay]
  /// days after it (0: on the day).
  final int? payScheduleId;
  final int daysAfterPay;

  /// A date that lands on a weekend: paid before it, after it, or on the
  /// day. Paydays bring their own rule.
  final PayWeekend weekend;

  /// Every so many weeks, on these weekdays (Monday 1 … Sunday 7), in
  /// order; null when it's the due date's own weekday (Custom…, v16).
  final List<int>? weekdays;

  /// Every so many months or years: on the [nth] [nthWeekday] of the
  /// month (1 to 4, or -1 for the last; Monday 1 … Sunday 7) instead of
  /// the due date's day of the month. Null: the day of the month.
  final int? nth;
  final int? nthWeekday;

  /// One that repeats stops: no bill after this date, or after this many
  /// bills. Null: it goes on.
  final DateTime? endDate;
  final int? endCount;

  /// It comes again, one way or another.
  /// This plan with its pay changed to [payId] (null: no pay). A set
  /// amount is then per that pay's periods, or per month. A bill every
  /// payday follows the new pay's paydays, or, with none, comes monthly
  /// from [nextPayday] (the stopped pay's next, plus its days after).
  /// Owner, 2026-10-05: stopping a pay offers to move what was per it.
  CategoryPlan movedToPay(int? payId, {required DateTime nextPayday}) {
    final bill = kind == PlanKind.byDate && payScheduleId != null;
    final monthly = bill && payId == null;
    return CategoryPlan(
      categoryId: categoryId,
      kind: kind,
      amount: amount,
      start: start,
      due: monthly
          ? DateTime(
              nextPayday.year,
              nextPayday.month,
              nextPayday.day + daysAfterPay,
            )
          : due,
      everyMonths: monthly ? 1 : everyMonths,
      everyDays: everyDays,
      onDates: onDates,
      payScheduleId: payScheduleId == null ? null : payId,
      daysAfterPay: monthly ? 0 : daysAfterPay,
      weekend: weekend,
      weekdays: weekdays,
      nth: nth,
      nthWeekday: nthWeekday,
      endDate: endDate,
      endCount: endCount,
      rollover: rollover,
      upTo: upTo,
      paidFrom: paidFrom,
    );
  }

  bool get repeats =>
      everyMonths != null ||
      everyDays != null ||
      onDates != null ||
      payScheduleId != null;

  /// The same dates as [o]: how often, from where, and the weekend rule.
  bool sameRepeat(CategoryPlan o) =>
      due == o.due &&
      everyMonths == o.everyMonths &&
      everyDays == o.everyDays &&
      _sameDates(onDates, o.onDates) &&
      payScheduleId == o.payScheduleId &&
      daysAfterPay == o.daysAfterPay &&
      weekend == o.weekend &&
      _sameInts(weekdays, o.weekdays) &&
      nth == o.nth &&
      nthWeekday == o.nthWeekday &&
      endDate == o.endDate &&
      endCount == o.endCount;

  static bool _sameInts(List<int>? a, List<int>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameDates(List<(int, int)>? a, List<(int, int)>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// [PlanKind.each]: what's left when a period ends stays in the
  /// category. False sends it back to the money not assigned; what's
  /// overspent carries either way.
  final bool rollover;

  /// [PlanKind.each] that carries over: once the category holds this
  /// much, the plan stops asking until some is spent. Null: no cap.
  final int? upTo;

  /// [PlanKind.byDate]: the account the bill is paid from. With one, the
  /// bill is kept scheduled there, so that account's forecast counts it.
  final int? paidFrom;

  @override
  bool operator ==(Object other) =>
      other is CategoryPlan &&
      other.categoryId == categoryId &&
      other.kind == kind &&
      other.amount == amount &&
      other.start == start &&
      sameRepeat(other) &&
      other.rollover == rollover &&
      other.upTo == upTo &&
      other.paidFrom == paidFrom;

  @override
  int get hashCode => Object.hash(
    categoryId,
    kind,
    amount,
    start,
    due,
    everyMonths,
    everyDays,
    onDates?.length,
    payScheduleId,
    daysAfterPay,
    weekend,
    rollover,
    upTo,
    paidFrom,
  );
}

class LedgerData {
  LedgerData({
    required List<AccountInfo> accounts,
    required this.txns,
    this.reconciliations = const [],
    this.paySchedules = const [],
    this.payeeRules = const [],
    this.stoppedPaySchedules = const [],
    this.prefs = const {},
    this.budgetAmounts = const [],
    List<CategoryPlan> plans = const [],
    this.accountsOff = const {},
  }) : accounts = {for (final a in accounts) a.id: a},
       plans = {for (final p in plans) p.categoryId: p} {
    // Amounts tell two currencies with one symbol apart only while both
    // are held.
    Currency.hold({
      for (final a in accounts)
        if (a.isBalanceSheet && !a.deleted) a.currency,
    });
  }

  /// By spending category, the accounts it doesn't use (rule 28). A
  /// category uses every account in its currency unless one is unchecked,
  /// so a new account is used by all of them.
  final Map<int, Set<int>> accountsOff;

  /// Each spending category's plan, by category (rule 27).
  final Map<int, CategoryPlan> plans;

  /// What's been put into each spending category, by period (rule 26).
  final List<BudgetAmount> budgetAmounts;

  /// The user's small settings by key, such as the Savings answers.
  final Map<String, String> prefs;

  /// Active pay schedules (rule 24).
  final List<PaySchedule> paySchedules;

  /// The payees the app remembers a category for, deleted ones left out.
  final List<PayeeRuleInfo> payeeRules;

  /// Stopped ones: their overdue paydays are still estimates.
  final List<PaySchedule> stoppedPaySchedules;

  /// A pay schedule by id, stopped ones included; null for none.
  PaySchedule? payScheduleById(int? id) => _schedulesById[id];

  late final Map<int, PaySchedule> _schedulesById = {
    for (final p in [...stoppedPaySchedules, ...paySchedules]) p.id: p,
  };

  /// This ledger with [plan] as [categoryId]'s plan (none with null):
  /// what a plan being typed, or removed, would do before it's saved.
  LedgerData withPlan(int categoryId, CategoryPlan? plan) => LedgerData(
    accounts: accounts.values.toList(),
    txns: txns,
    reconciliations: reconciliations,
    paySchedules: paySchedules,
    payeeRules: payeeRules,
    stoppedPaySchedules: stoppedPaySchedules,
    prefs: prefs,
    budgetAmounts: budgetAmounts,
    accountsOff: accountsOff,
    plans: [
      for (final p in plans.values)
        if (p.categoryId != categoryId) p,
      ?plan,
    ],
  );

  /// This ledger with the app's Income category called [name]: the word
  /// for it in the user's language, so menus, rows and typed names all use
  /// it.
  LedgerData withIncomeNamed(String name) => LedgerData(
    accounts: [
      for (final a in accounts.values)
        if (a.isIncome)
          AccountInfo(
            id: a.id,
            name: name,
            type: a.type,
            sortOrder: a.sortOrder,
            archived: a.archived,
            deleted: a.deleted,
            currency: a.currency,
          )
        else
          a,
    ],
    txns: txns,
    reconciliations: reconciliations,
    paySchedules: paySchedules,
    payeeRules: payeeRules,
    stoppedPaySchedules: stoppedPaySchedules,
    prefs: prefs,
    budgetAmounts: budgetAmounts,
    accountsOff: accountsOff,
    plans: plans.values.toList(),
  );

  /// The app's one income category (rule 30); null in a ledger built
  /// without one.
  late final AccountInfo? income = accounts.values
      .where((a) => a.isIncome && !a.deleted)
      .firstOrNull;

  /// The schedule the budget runs by, or null for calendar months.
  PaySchedule? get periodSchedule =>
      paySchedules.where((p) => p.definesPeriod).firstOrNull;

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

  /// What [accountId]'s uncleared rows are held against; null for cash.
  UnclearedCheck? unclearedCheck(int accountId) {
    final account = accounts[accountId];
    if (account == null || account.isCash) return null;
    return (
      statement: latestReconciliation(accountId)?.statementDate,
      owed: account.isOwed,
    );
  }

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
          found.add((txnId: t.id, date: t.date, row: _row(t, e), cause: cause));
        }
      }
    }
    return found.length == 1 ? found.single : null;
  }

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

  /// What's filed under [categoryId], posted rows only, in each currency it
  /// has (never added across them): spent for spending (positive), received
  /// for income (positive). MNT alone when there's nothing.
  Map<Currency, int> categoryTotals(
    int categoryId, {
    DateTime? from,
    DateTime? to,
  }) {
    final sums = <Currency, int>{};
    for (final t in txns) {
      if (t.scheduled) continue;
      if (from != null && t.date.isBefore(from)) continue;
      if (to != null && t.date.isAfter(to)) continue;
      for (final e in t.entries) {
        if (e.accountId == categoryId) {
          sums[e.currency] = (sums[e.currency] ?? 0) + e.amount;
        }
      }
    }
    final income = accounts[categoryId]?.isIncome ?? false;
    if (sums.isEmpty) return {Currency.mnt: 0};
    return {
      for (final c in Currency.values)
        if (sums[c] case final v?) c: income ? -v : v,
    };
  }

  /// What the accounts in [of] hold, by currency (net worth, and archived
  /// money in it). Each currency on its own; a currency nobody holds is left
  /// out, and MNT stands alone when there are none.
  Map<Currency, int> balancesByCurrency(Iterable<AccountInfo> of) {
    final out = <Currency, int>{};
    for (final a in of) {
      out[a.currency] = (out[a.currency] ?? 0) + balanceOf(a.id);
    }
    if (out.isEmpty) return {Currency.mnt: 0};
    return {for (final c in Currency.values) c: ?out[c]};
  }

  /// The hidden account a transfer between currencies passes through.
  late final int? _exchangeId = accounts.values
      .where(
        (a) => a.type == AccountType.equity && a.name == currencyExchangeName,
      )
      .firstOrNull
      ?.id;

  /// A transfer between currencies (it passes through the exchange account).
  bool isExchange(TxnData t) =>
      _exchangeId != null && t.entries.any((e) => e.accountId == _exchangeId);

  RegisterRow _row(TxnData t, EntryData e) {
    final others = t.entries
        .where((o) => o.id != e.id && o.accountId != _exchangeId)
        .toList();
    final exchanged = isExchange(t) && others.length == 1
        ? others.single
        : null;
    var kind = RowKind.simple;
    var payee = t.payee ?? '';
    var label = '';
    var incomeCategory = false;
    var otherClosed = false;
    int? categoryId;
    String? deletedOther;
    AppEquity? equity;
    var lines = <SplitLine>[];

    if (others.length == 1) {
      final other = accounts[others.single.accountId]!;
      if (other.type == AccountType.equity) {
        kind = RowKind.opening;
        payee = payee.isEmpty ? 'Opening balance' : payee;
        label = other.name;
        equity = switch (other.name) {
          openingBalancesAccountName => AppEquity.openingBalances,
          balanceAdjustmentsName => AppEquity.adjustments,
          _ => null,
        };
      } else if (other.isBalanceSheet) {
        kind = RowKind.transfer;
        payee = other.label;
        label = 'Transfer';
        if (other.deleted) deletedOther = other.name;
        // Not in the account lists, so the editor can't name it again.
        otherClosed = other.archived || other.deleted;
      } else {
        label = other.name;
        categoryId = other.id;
        incomeCategory = other.isIncome;
        // Pay set up with no "who from", and a bill a plan scheduled, are
        // named by their category.
        if (payee.isEmpty &&
            (t.payScheduleId != null || t.planCategoryId != null)) {
          payee = other.name;
        }
      }
    } else {
      kind = RowKind.split;
      // Split lines in this account's sign convention, so they sum to [amount].
      lines = [
        for (final o in others)
          (
            accountId: o.accountId,
            name: accounts[o.accountId]!.label,
            amount: -o.amount,
            deleted: accounts[o.accountId]!.deleted
                ? accounts[o.accountId]!.name
                : null,
          ),
      ];
      label = '${others.length} categories';
    }

    final rec = _reconciliationsById[e.reconciliationId];
    return RegisterRow(
      currency: accounts[e.accountId]!.isBalanceSheet
          ? accounts[e.accountId]!.currency
          : e.currency,
      otherAmount: exchanged?.amount,
      otherCurrency: exchanged?.currency,
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
      deletedOther: deletedOther,
      equity: equity,
      accountId: e.accountId,
      payScheduleId: t.payScheduleId,
      // A plan's bill confirmed as a split is still that bill while one
      // of its lines is in the bill's category; once none is, it isn't.
      planCategoryId:
          kind == RowKind.split &&
              !lines.any((l) => l.accountId == t.planCategoryId)
          ? null
          : t.planCategoryId,
      madeHow: t.madeHow,
      madeOn: t.madeOn,
      estimate: switch (_schedulesById[t.payScheduleId]) {
        final p? when p.varies => p.amountOn(t.date),
        _ => null,
      },
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
