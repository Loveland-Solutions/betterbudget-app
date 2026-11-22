// The phone as a member of the folder (ADR 0005, "The phone joins as another
// computer", #526 piece 3): its own whole ledger (`phone_own_ledger.dart`) is
// kept up by the same cycle a computer runs (`CloudFolder`): the phone's
// change file is written when its log has grown, and the other computers'
// change files are folded in and brought in. What differs from a computer:
// the phone never writes the folder's whole ledger (too much to send over
// mobile data; the computers keep it), and what it asks is asked in its own
// window (piece 4, part 3): a row changed two ways ([PhoneSync.asks]), and
// two ledgers that can't be combined ([PhoneSync.apart]), the figures staying
// as they were until it is answered.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

import '../domain/budget.dart'
    show
        BillFit,
        Budget,
        BudgetKeys,
        CategoryType,
        billPayments,
        isUncategorized,
        uncategorizedNames;
import '../domain/budget_amounts.dart';
import '../domain/combine.dart' show Ask, Pick;
import '../domain/forecast.dart' show ForecastSpan;
import '../domain/ledger.dart'
    show
        AccountRole,
        AccountType,
        BudgetAmount,
        CategoryPlan,
        Cleared,
        PlanKind,
        RegisterRow,
        splitEmoji,
        withEmoji,
        dateOnly,
        RowKind,
        billNotIt,
        billNotItKey,
        billPaidKey,
        billSkippedDayKey,
        billSkippedKey,
        billSkippedValue,
        dateKey,
        decodeBillPaid;
import '../domain/pay.dart'
    show
        PayRepeat,
        PayRule,
        PayWeekend,
        budgetPeriod,
        noRegularPayKey,
        payNever;
import '../domain/payee_offers.dart';
import '../domain/payee_rules.dart' show PayeeBefore, PayeeRuleInfo, Remembered;
import '../domain/phone.dart';
import '../domain/money.dart' show Currency;
import '../domain/readiness.dart' show ReadyKeys, ReadyStep, Readiness;
import '../domain/setup.dart' show SetupKeys;
import '../domain/sync.dart' show appliedMarkerOp, sharedRowId;
import 'account_edit.dart';
import 'backup.dart';
import 'cloud_folder.dart';
import 'database.dart'
    show
        AppDatabase,
        CategoryMoney,
        ChangedSinceException,
        DeletedAccount,
        PlanChange,
        DbProblem,
        ImportPlan,
        ImportPlanRow,
        ImportRecord,
        LockedException,
        NotFoundException,
        PayChange,
        PhoneTake,
        ReconcileRecord,
        SplitPart,
        TxnSnapshot;
import '../import/mapping.dart' show ImportRow;
import 'folder_io.dart';
import 'payee_acts.dart';
import 'phone_ledger.dart';
import 'phone_own_ledger.dart';
import 'setup_finish.dart';

/// What the phone shows and keeps up, as [PhoneStart] asks it: swapped in
/// tests.
/// What [PhoneLedgerSource.take] did: the ledger as it stands after, and what
/// was taken, which [PhoneLedgerSource.undoTake] takes back ([take] is null
/// when the inbox held nothing new).
typedef PhoneTook = ({PhoneSnapshot snapshot, PhoneTake? take});

/// What a look brought in from another computer, for the phone to say
/// (#526 piece 4): [transactions] and [others] changes, one transaction by
/// its [payee], and the name of the computer, [from], when it has one.
typedef PhoneNews = ({
  int transactions,
  int others,
  String? payee,
  String? from,
});

/// What waits for an answer on the phone: [asks] are things changed on this
/// phone and on the computer called [from] both; with [apart] set the two
/// ledgers can't be put together at all, and [notOnComputer] is how many of
/// this phone's entries no computer has applied, which taking the folder's
/// ledger would lose.
typedef PhoneAsking = ({
  List<Ask> asks,
  String? from,
  bool apart,
  int notOnComputer,
  int otherChanges,
  String digest,
  String? mineDigest,
});

/// What an answer did: [done] when it was made, and the ledger as it stands
/// after. Not done when what was asked about changed since (a computer
/// saved again, or something was entered here): the person is asked again.
typedef PhoneAnswered = ({PhoneSnapshot snapshot, bool done});

/// What the person changed on a row of the register (#527), as the
/// computer's edit takes it: [amount] is signed from [account]'s side and
/// [counter] is the category (or the other account); null leaves them as
/// they are. [splits] are a split's lines, in the account's sign, null to
/// leave them. [remember] is the category to remember for the payee, when
/// the box under the row was ticked (#403).
typedef PhoneRowEdit = ({
  int txn,
  int account,
  DateTime date,
  String? payee,
  String? memo,
  int? counter,
  int? amount,
  List<SplitPart>? splits,
  int? remember,
});

/// A scheduled row confirmed (#527): the edit as the person made it, and the
/// payday's schedule or the plan's category the row came from, whose next
/// one is scheduled once this one is real.
typedef PhoneRowConfirm = ({
  PhoneRowEdit edit,
  int? paySchedule,
  int? planCategory,
  bool keepOwed,
});

/// An edit done: the ledger as it stands after, and the row as it was and
/// as it is, which undo and redo put back.
typedef PhoneEdited = ({
  PhoneSnapshot snapshot,
  TxnSnapshot before,
  TxnSnapshot after,
  Remembered? remembered,
});

/// What a row's ⋯ menu does (#527): mark one entry cleared or uncleared,
/// move a row's side to another account, or delete the row.
sealed class PhoneRowAct {
  const PhoneRowAct();
}

class PhoneMarkCleared extends PhoneRowAct {
  const PhoneMarkCleared(this.entry, this.to);
  final int entry;
  final Cleared to;
}

class PhoneMoveRow extends PhoneRowAct {
  const PhoneMoveRow(this.txn, this.from, this.to);
  final int txn;
  final int from;
  final int to;
}

/// No bill this time (#527): a category's scheduled bill, due [date], is
/// skipped, and its money stays for the next one.
class PhoneNoBill extends PhoneRowAct {
  const PhoneNoBill(this.txn, this.planCategory, this.date);
  final int txn;
  final int planCategory;
  final DateTime date;
}

/// A row already in paid a bill, as the person answered (#527): [found]
/// is [bill] paid, and the bill goes, or with [keepRest] stays for what is
/// still to pay; with [bills] over one, the bills after it are paid with it.
class PhoneBillPaid extends PhoneRowAct {
  const PhoneBillPaid(
    this.bill,
    this.found, {
    this.keepRest = false,
    this.bills = 1,
  });
  final RegisterRow bill;
  final RegisterRow found;
  final bool keepRest;
  final int bills;
}

/// No on "Paid on…?": [found] isn't [bill], and the bill stops asking.
class PhoneNotIt extends PhoneRowAct {
  const PhoneNotIt(this.bill, this.found);
  final int bill;
  final int found;
}

/// "Not this bill" on a row taken as a bill paid: it wasn't, and what the
/// tie did is put back.
class PhoneNotTheBill extends PhoneRowAct {
  const PhoneNotTheBill(this.row);
  final RegisterRow row;
}

/// A category's Assigned for this period set to [amount] on Budget
/// (#528): a typed amount, Assign what's planned (the plan's) or Clear
/// (0), written the way the computer writes it.
class PhoneAssign extends PhoneRowAct {
  const PhoneAssign(this.category, this.amount);
  final int category;
  final int amount;
}

/// Money moved between two categories' Assigned this period (#528); a
/// null side is Not assigned. Written as the computer's Move money is.
class PhoneMove extends PhoneRowAct {
  const PhoneMove(this.from, this.to, this.amount);
  final int? from;
  final int? to;
  final int amount;
}

/// A category of the ledger edited on Budget (#528): its name (with its
/// emoji), its plan and type as the four cards make them, and, when it was
/// changed, the account it is paid from. Written as the computer's Edit
/// writes it, in one change.
class PhoneEditCategory extends PhoneRowAct {
  const PhoneEditCategory(
    this.category, {
    required this.name,
    required this.plan,
    required this.type,
    this.paidFrom,
    this.skip = const [],
    this.back = const [],
    this.group,
    this.note,
  });
  final int category;
  final String name;

  /// Its group heading on Budget and its note (#100); empty is none.
  final String? group;
  final String? note;

  /// Bills of this period the switches turned off, and skipped ones turned
  /// on again, by date (#365), as the computer's Edit does on Save.
  final List<DateTime> skip;
  final List<DateTime> back;
  final CategoryPlan? plan;
  final CategoryType type;

  /// Null when Paid from wasn't changed.
  final int? paidFrom;
}

/// A category put away, or brought back, as the computer's Archive does
/// (#528): its rows keep it, and it leaves the menus.
class PhoneArchiveCategory extends PhoneRowAct {
  const PhoneArchiveCategory(this.category, this.archived);
  final int category;
  final bool archived;
}

/// A category deleted, its rows moved to [into] (null when it has none), as
/// the computer's Delete does (#528).
class PhoneDeleteCategory extends PhoneRowAct {
  const PhoneDeleteCategory(this.category, this.into);
  final int category;
  final int? into;
}

/// A regular income as the pay form answered it (#528): the fields of the
/// computer's `PayDraft`.
typedef PhonePayDraft = ({
  int accountId,
  String? name,
  String? payee,
  int amount,
  int? amount2,
  bool varies,
  PayRule rule,
  int day1,
  int day2,
  int weeks,
  DateTime anchor,
  PayRepeat? repeat,
  PayWeekend weekend,
});

/// A regular income saved on the Income page (#528), new when [id] is null,
/// written as the computer's `_applyPay` writes it. [replaced] is filled in
/// by the ledger: how many rows of the person's own it took over.
class PhoneSavePay extends PhoneRowAct {
  PhoneSavePay(this.id, this.draft);
  final int? id;
  final PhonePayDraft draft;
  int replaced = 0;
}

/// A regular income stopped (#528). The categories budgeted by its pay
/// periods, as the ledger has them now, go by the month, in the same Undo.
class PhoneStopPay extends PhoneRowAct {
  const PhoneStopPay(this.id);
  final int id;
}

/// "I don't have regular income" said, or asked again (#528).
class PhoneNoPay extends PhoneRowAct {
  const PhoneNoPay(this.none);
  final bool none;
}

/// Setup on the phone (#534): the one day every balance typed in setup is
/// as of, the accounts' opening balances moved with it, as the computer's
/// setup moves them.
class PhoneSetupDate extends PhoneRowAct {
  const PhoneSetupDate(this.date);
  final DateTime date;
}

/// Budget by month ([schedule] null) or by that pay's paychecks (#474),
/// asked in setup once there is pay.
class PhoneBudgetBy extends PhoneRowAct {
  const PhoneBudgetBy(this.schedule);
  final int? schedule;
}

/// Setup ends with Money you have's answers (#475, #534): [had], what the
/// budget uses of each currency's money in the accounts; [emergency], in
/// the budget's own currency, assigned to the Safety net, made as
/// [safetyNetName] when there is none. `finishSetup`, the computer's too.
class PhoneFinishSetup extends PhoneRowAct {
  const PhoneFinishSetup({
    required this.had,
    required this.emergency,
    required this.safetyNetName,
    this.follows = const {},
    this.saveIn,
  });
  final Map<Currency, int> had;
  final int emergency;
  final String safetyNetName;

  /// The currencies whose money follows the accounts (#618), and the one
  /// picked to save in (#616): `finishSetup`'s.
  final Set<Currency> follows;
  final Currency? saveIn;
}

/// How far every forecast looks, picked on the Ledger tab's header (#529):
/// one choice for every account, kept in the ledger's preferences quietly
/// as on the computer; [customEnd] is the day Custom… runs to.
class PhoneSetSpan extends PhoneRowAct {
  const PhoneSetSpan(this.span, {this.customEnd});
  final ForecastSpan span;
  final DateTime? customEnd;
}

/// A Savings answer or setting from the phone's Savings tab (#533):
/// `ready.*` preferences written together, as the computer's Savings page
/// writes them, undone together. [aside] skips a step or brings it back,
/// worked out from what's stored when it's written, so two quick taps both
/// count. [role] marks what a card or loan counts as on step 2 (an account's
/// role, null for debt to pay off). [plan] is a goal's plan with its date
/// moved, written as the computer's Move the date writes it.
class PhoneSavingsAnswer extends PhoneRowAct {
  const PhoneSavingsAnswer(this.values, {this.aside, this.role, this.plan});
  final Map<String, String?> values;
  final (ReadyStep, bool)? aside;
  final (int, AccountRole?)? role;
  final (int, CategoryPlan)? plan;
}

/// An account added on the Accounts page (#529): its name, what it is,
/// its currency, a card's or loan's [rate] (kept for Savings), and what it
/// starts with, [balance] as typed (a card's is what is owed), on [date].
/// [made] is filled in by the ledger.
class PhoneAddAccount extends PhoneRowAct {
  PhoneAddAccount({
    required this.name,
    required this.type,
    required this.currency,
    this.cash = false,
    this.rate,
    this.balance,
    required this.date,
  });
  final String name;
  final AccountType type;
  final Currency currency;
  final bool cash;
  final String? rate;
  final int? balance;
  final DateTime date;
  int? made;
}

/// An account's Edit… saved (#529): its name, type, rate and what its
/// payments come out of, as one change (`editAccount`, the computer's too).
/// [flipped] is filled in: its opening balance turned round with the type.
class PhoneEditAccount extends PhoneRowAct {
  PhoneEditAccount(this.account, this.edit);
  final int account;
  final AccountEdit edit;
  bool flipped = false;
}

/// An account put away, or brought back.
class PhoneArchiveAccount extends PhoneRowAct {
  const PhoneArchiveAccount(this.account, this.archived);
  final int account;
  final bool archived;
}

/// An account deleted with the rows that are only its own, as the
/// computer's Delete does.
class PhoneDeleteAccount extends PhoneRowAct {
  const PhoneDeleteAccount(this.account);
  final int account;
}

/// A payee saved on the Payees page (#532): new ([before] null) or
/// changed, as the computer's Save is, with its twins taken into it.
class PhoneSavePayee extends PhoneRowAct {
  PhoneSavePayee(this.before, this.after);
  final PayeeRuleInfo? before;
  final PayeeRuleInfo after;

  /// The payee as written, once done.
  PayeeRuleInfo? saved;
}

/// A payee deleted: the app stops filing by it; rows already filed stay.
class PhoneDeletePayee extends PhoneRowAct {
  const PhoneDeletePayee(this.rule);
  final PayeeRuleInfo rule;
}

/// The offer to file what is still in Not categorized (this period's) for
/// each of these payees, as one change. [filed] is how many rows went.
class PhoneFilePayees extends PhoneRowAct {
  PhoneFilePayees(this.rules);
  final List<int> rules;
  int filed = 0;
}

/// The offer to show these payees' names on the rows already in that don't
/// (each keeping the bank's words in its memo). [shown] is how many.
class PhoneShowPayeeNames extends PhoneRowAct {
  PhoneShowPayeeNames(this.rules);
  final List<int> rules;
  int shown = 0;
}

class PhoneDeleteRow extends PhoneRowAct {
  const PhoneDeleteRow(this.txn);
  final int txn;
}

/// An account reconciled against a statement (#530), as the computer's
/// Lock does: [balance] is the statement's in the account's own sign, and
/// with [adjustBy], the difference the person was shown, that much goes in
/// as a Reconcile adjustment first (and nothing does when the difference is
/// no longer that).
class PhoneReconcile extends PhoneRowAct {
  PhoneReconcile(
    this.account, {
    required this.date,
    required this.balance,
    this.adjustBy,
  });
  final int account;
  final DateTime date;
  final int balance;
  final int? adjustBy;

  /// What it locked, once done: the snack bar says how many.
  ReconcileRecord? done;
}

/// The account's newest reconcile taken back, whenever it was done.
class PhoneUndoReconcile extends PhoneRowAct {
  PhoneUndoReconcile(this.account);
  final int account;

  /// What went back to cleared, once done.
  ReconcileRecord? done;
}

/// A bank file's rows written into [account] (#531), as the computer's
/// import window's Import does: [plan] is what each row does, as the page
/// showed it, and with [moveOpening] the opening balance goes before the
/// rows it already counted. The rows a bill's category takes pay the bill,
/// in the same undo.
class PhoneImport extends PhoneRowAct {
  PhoneImport(
    this.account, {
    required this.plan,
    required this.uncategorized,
    this.moveOpening,
    this.start,
    this.mapping,
  });
  final int account;
  final List<ImportPlanRow> plan;
  final ({DateTime date, int amount})? moveOpening;

  /// A new account's opening balance, from its file: the day before its
  /// first row coming in and what it held then.
  final ({DateTime date, int amount})? start;

  /// Not categorized's name in the language showing, for the category the
  /// rows no payee files go to when the ledger has none yet.
  final String uncategorized;

  /// The columns as set (`SavedMapping.encode`), kept for the account's
  /// next file.
  final String? mapping;

  /// What it wrote, once done, with how many bills its rows paid and how
  /// many more a row may have paid: the snack bar says them, and its Show
  /// opens [checkRow], the first row that may have paid one.
  ({ImportRecord record, int billsPaid, int billsToCheck, int? checkRow})? done;
}

/// An act done: the ledger after it, and what Undo and Redo do, each
/// returning the ledger after (and throwing what the ledger refuses).
typedef PhoneActed = ({
  PhoneSnapshot snapshot,
  Future<PhoneSnapshot> Function() undo,
  Future<PhoneSnapshot> Function() redo,
});

/// Where in the phone's folder [dir] its own ledger is kept.
Directory phoneOwnDir(Directory dir) => Directory('${dir.path}/own');

abstract class PhoneLedgerSource {
  /// Whether this phone already has a ledger of its own.
  bool get joined;

  /// Takes [folderLedger], the ledger as it sits in the folder, as this
  /// phone's own. Throws [WrongKeyException] when the key doesn't open it.
  Future<void> join(Uint8List folderLedger);

  /// Makes a new, empty ledger as the phone's own, for a person who starts
  /// on the phone (#534); one the phone already has is kept.
  Future<void> startNew() =>
      throw UnsupportedError('This source can’t make a ledger');

  /// The phone keeps its ledger in no folder (#534): nothing it holds is
  /// waiting for a computer, and no look at a folder is made.
  bool onItsOwn = false;

  /// Makes the phone's own ledger from the backup file at [path] (#534).
  /// Throws a `RestoreException` for a file it refuses; nothing is kept.
  Future<void> restoreFrom(String path, DateTime now) =>
      throw UnsupportedError('This source can’t make a ledger');

  /// Looks at the folder and shows the phone's own ledger as of [now]: its
  /// change file written, the others' brought in. Never throws for the
  /// folder not answering: the figures are the ledger's as it stands, said
  /// to be as old as the last look that went through.
  Future<PhoneSnapshot> look(String folder, DateTime now);

  /// The phone's own ledger as it stands, with no look at the folder: what
  /// is shown while the folder doesn't answer.
  Future<PhoneSnapshot> asItStands(DateTime now);

  /// Takes what the person made on this phone, [inbox], into the phone's
  /// own ledger, as the computer takes a phone's file in (#526 piece 4):
  /// each entry becomes a row, a category made here is made, a count is
  /// saved. Returns the ledger as it stands after, in which what was taken
  /// is listed under this phone ([PhoneSnapshot.taken]) for the store to
  /// let go of. Null when this source keeps no ledger of its own to take
  /// them into: the entries then wait for the computer in the folder.
  Future<PhoneTook?> take(PhoneInbox inbox, DateTime now) async => null;

  /// Takes back what [take] brought into the phone's own ledger: its rows go
  /// (soft-deleted, as a change the others will see), and the categories it
  /// made. Returns the ledger as it stands after.
  Future<PhoneSnapshot> undoTake(PhoneTake take, DateTime now) =>
      throw UnsupportedError('This source keeps no ledger to take back from');

  /// Edits a row of the phone's own ledger, as a change the computers see
  /// (#527). Throws what the ledger refuses (a reconciled row's amount).
  Future<PhoneEdited> editRow(PhoneRowEdit edit, DateTime now) =>
      throw UnsupportedError('This source keeps no ledger to edit');

  /// Confirms a scheduled row: it happened, so it is dated and valued as
  /// [confirm] says and the next payday or bill is scheduled (#527). Throws
  /// what the ledger refuses (a date after today).
  Future<PhoneActed> confirmRow(PhoneRowConfirm confirm, DateTime now) =>
      throw UnsupportedError('This source keeps no ledger to edit');

  /// Puts a row back as [row] was, for Undo and Redo of an edit; with
  /// [remembered], the payee's category the edit remembered is forgotten.
  Future<PhoneSnapshot> restoreRow(
    TxnSnapshot row,
    DateTime now, {
    Remembered? remembered,
  }) => throw UnsupportedError('This source keeps no ledger to edit');

  /// Does what a row's ⋯ menu asked, as a change the computers see (#527).
  /// Throws what the ledger refuses (a reconciled row).
  Future<PhoneActed> actOnRow(PhoneRowAct act, DateTime now) =>
      throw UnsupportedError('This source keeps no ledger to edit');

  /// How many rows are filed under category [id] in the phone's own ledger
  /// right now, counted live as the computer's Delete does (#528).
  Future<int> categoryRows(int id) =>
      throw UnsupportedError('This source keeps no ledger to count in');

  /// What each row of a bank file would do in [account], against the
  /// phone's own ledger as it is now (#531): nothing is written.
  Future<ImportPlan> planImport(
    int account,
    List<ImportRow> rows,
    List<String> keys,
  ) => throw UnsupportedError('This source keeps no ledger to import into');

  /// What the looks since the last call brought in from the other
  /// computers, said once: the phone shows it, with no Undo, as a computer's
  /// popup has none (undo is for what the person here did).
  List<PhoneNews> takeNews() => const [];

  /// What the last look found changed on this phone and on another computer
  /// both, and waits to be asked about (#526 piece 4, part 3): nothing comes
  /// in until it is answered.
  PhoneAsking? get asking => null;

  /// Answers [PhoneAsking.asks] with [picks], one for each: the rest comes
  /// in with them. Returns the ledger as it stands after.
  Future<PhoneAnswered> answer(Map<String, Pick> picks, DateTime now) =>
      throw UnsupportedError('This source asks nothing');

  /// Takes the folder's whole ledger as this phone's own, for two ledgers
  /// that can't be put together ([PhoneAsking.apart]). What this phone had
  /// is gone, and the computers hold their own.
  Future<PhoneAnswered> takeFoldersLedger(DateTime now) =>
      throw UnsupportedError('This source asks nothing');

  Future<void> close();

  /// Gives this phone's own ledger up, before another folder's is taken.
  Future<void> leave();
}

/// A phone has no hardware id or name of its own to give: its id is the one
/// its entries file is named by.
class PhoneFolderAccess extends FolderAccess {
  const PhoneFolderAccess(this.device, this.nameOf);

  final String device;

  /// The name the person gave this phone (Settings → Register on a
  /// computer), or a plain one until then.
  final Future<String> Function() nameOf;

  @override
  Future<String?> derivedComputerId() async => device;

  @override
  Future<String?> remember(String path) async => null;

  @override
  Future<({String path, String? token})?> open(String token) async => null;

  @override
  Future<String> computerName() => nameOf();
}

/// How far a look goes round before it stops: each brings in one computer's
/// changes, and a few computers is all there are.
const _roundsOfLook = 6;

class PhoneSync implements PhoneLedgerSource {
  PhoneSync({
    required Directory dir,
    required Uint8List dataKey,
    required this.device,
    this.io = const PhoneFolderIo(),
    this.wait = const Duration(seconds: 5),
  }) : _own = PhoneOwnLedger(phoneOwnDir(dir), dataKey),
       _key = dataKey;

  /// This phone's id: its ledger's computer, its change file's name.
  final String device;
  final Duration wait;
  final PhoneOwnLedger _own;
  final FolderIo io;
  final Uint8List _key;

  AppDatabase? _db;
  CloudFolder? _cloud;
  final _news = <PhoneNews>[];
  PhoneAsking? _asking;

  @override
  PhoneAsking? get asking => _asking;

  @override
  List<PhoneNews> takeNews() {
    final out = [..._news];
    _news.clear();
    return out;
  }

  /// Given up or closed: nothing reopens the ledger or writes beside it, so
  /// a look still running when the phone leaves it can't undo that.
  bool _closed = false;

  /// Where the person was last sure the figures were whole: a look that
  /// went through, or the ledger's own join.
  File get _lookedFile => File('${_own.dir.path}/looked');

  /// The folder cycle, once the phone has a ledger, and its state.
  CloudFolder? get cloud => _cloud;

  /// The phone's own ledger, once it has one.
  AppDatabase? get db => _db;

  @override
  bool get joined => _own.exists;

  @override
  Future<void> join(Uint8List folderLedger) async {
    _db ??= await _own.join(folderLedger, device);
  }

  @override
  bool onItsOwn = false;

  @override
  Future<void> startNew() async {
    _db ??= await _own.create(device);
  }

  @override
  Future<void> restoreFrom(String path, DateTime now) async {
    if (_db != null) throw StateError('The phone already has a ledger open');
    _db = await _own.restore(path, device, now);
  }

  Future<String> _name() async {
    final named = await _db?.preference('$phoneNamePrefix$device');
    return named == null || named.trim().isEmpty ? 'Phone' : named.trim();
  }

  /// The cycle on [folder], or null when the phone couldn't be put on it
  /// (the folder's ledger still arriving, or from a newer app).
  Future<CloudFolder?> _cycle(String folder, DateTime now) async {
    var cloud = _cloud;
    if (cloud == null) {
      cloud = CloudFolder(
        Backups(_db!, dataKey: _key),
        access: PhoneFolderAccess(device, _name),
        io: io,
        wait: wait,
        writesLedger: false,
      );
      await cloud.load(now);
      _cloud = cloud;
    }
    if (cloud.value.path != folder) {
      try {
        await cloud.keepIn(folder, now);
      } on FolderLedgerUnreadable {
        // Still arriving: the next look.
      } on FolderLedgerNewer {
        // A newer version of the app wrote it: nothing is taken in.
      }
    }
    return cloud.value.path == folder ? cloud : null;
  }

  @override
  Future<PhoneSnapshot> look(String folder, DateTime now) async {
    if (_closed) throw StateError('The phone’s ledger was closed');
    _db ??= await _own.open(device);
    final db = _db;
    if (db == null) throw StateError('The phone has no ledger of its own yet');
    var whole = false;
    _asking = null;
    try {
      final cloud = await _cycle(folder, now);
      if (cloud == null) throw StateError('The phone isn’t on the folder yet');
      var standing = cloud.value.standing;
      for (var round = 0; round < _roundsOfLook; round++) {
        standing = await cloud.check(now);
        if (standing == FolderStanding.combine) {
          final done = await cloud.bringIn(now);
          // A phone has no use for the copy a computer keeps to restore from.
          if (done != null && done.before.existsSync()) {
            await done.before.delete();
          }
          if (done == null) break;
          if (!done.quiet) {
            _news.add((
              transactions: done.transactions,
              others: done.others,
              payee: done.payee,
              from: done.from.savedByName,
            ));
          }
          continue;
        }
        if (standing == FolderStanding.newer) {
          await _takeFolderLedger(cloud, now);
          continue;
        }
        break;
      }
      whole = standing == FolderStanding.ok;
      _asking = await _askingNow(cloud, standing);
    } catch (e) {
      // Offline, or the folder gone: the ledger the phone has stands.
      debugPrint('The phone’s look at the folder failed: $e');
    }
    if (whole && !_closed) await _keepLooked(now);
    return asItStands(now);
  }

  /// What the standing after a look asks, if anything.
  Future<PhoneAsking?> _askingNow(CloudFolder cloud, FolderStanding st) async {
    final digest = cloud.theirs?.look.digest;
    if (digest == null) return null;
    if (st == FolderStanding.rows) {
      final asks = cloud.asks;
      if (asks.isEmpty) return null;
      return (
        asks: asks,
        from: cloud.theirs?.look.savedByName,
        apart: false,
        notOnComputer: 0,
        otherChanges: 0,
        digest: digest,
        mineDigest: cloud.mineDigest,
      );
    }
    if (st == FolderStanding.apart) {
      final db = _db;
      final lost = db == null
          ? (entries: <int>{}, others: 0)
          : await _unapplied(db, cloud.seenOfMine ?? 0);
      return (
        asks: const <Ask>[],
        from: cloud.theirs?.look.savedByName,
        apart: true,
        notOnComputer: lost.entries.length,
        otherChanges: lost.others,
        digest: digest,
        mineDigest: cloud.mineDigest,
      );
    }
    return null;
  }

  /// What this phone changed that no computer has applied: its entries by
  /// id, and how many changes besides (assigned amounts, categories,
  /// payees). The lines of an entry go with it.
  Future<({Set<int> entries, int others})> _unapplied(
    AppDatabase db,
    int seen,
  ) async {
    final ids = <int>{};
    var others = 0;
    for (final c in await db.changesSince(seen)) {
      if (c.op == appliedMarkerOp) continue;
      if (c.tbl == 'entries') continue;
      if (c.tbl != 'transactions') {
        others++;
        continue;
      }
      if (c.op == 'delete') continue;
      final id = (jsonDecode(c.pk) as Map<String, dynamic>)['id'];
      if (id is int) ids.add(id);
    }
    return (entries: ids, others: others);
  }

  @override
  Future<PhoneAnswered> answer(Map<String, Pick> picks, DateTime now) async {
    if (_closed) throw StateError('The phone’s ledger was closed');
    final cloud = _cloud;
    if (cloud == null) throw StateError('The phone isn’t on the folder yet');
    final done = await cloud.bringIn(now, picks: picks);
    if (done == null) {
      // What was asked about changed meanwhile: the choices were not made.
      return (snapshot: await asItStands(now), done: false);
    }
    if (done.before.existsSync()) await done.before.delete();
    if (!done.quiet) {
      _news.add((
        transactions: done.transactions,
        others: done.others,
        payee: done.payee,
        from: done.from.savedByName,
      ));
    }
    _asking = null;
    return (snapshot: await asItStands(now), done: true);
  }

  @override
  Future<PhoneAnswered> takeFoldersLedger(DateTime now) async {
    if (_closed) throw StateError('The phone’s ledger was closed');
    final cloud = _cloud;
    final asked = _asking;
    if (cloud == null || asked == null || !asked.apart) {
      return (snapshot: await asItStands(now), done: false);
    }
    // Worked out afresh: what is replaced is what the page said, or nothing.
    final standing = await cloud.check(now, fresh: true);
    if (standing != FolderStanding.apart ||
        cloud.mineDigest != asked.mineDigest ||
        cloud.theirs?.look.digest != asked.digest) {
      return (snapshot: await asItStands(now), done: false);
    }
    await _takeFolderLedger(cloud, now);
    _asking = null;
    return (snapshot: await asItStands(now), done: true);
  }

  @override
  Future<PhoneSnapshot> asItStands(DateTime now) async {
    if (_closed) throw StateError('The phone’s ledger was closed');
    _db ??= await _own.open(device);
    final db = _db;
    if (db == null) throw StateError('The phone has no ledger of its own yet');
    // The rows of this phone's own that no other computer has applied: the
    // changes since the last one all of them have seen. With no other
    // computer heard from, all of them.
    final seen = _cloud?.seenOfMine ?? 0;
    final ids = onItsOwn ? const <int>{} : (await _unapplied(db, seen)).entries;
    return snapshotOf(
      await db.loadLedger(),
      today: now,
      madeAt: await _looked() ?? now,
      mineIds: ids,
      device: device,
      onItsOwn: onItsOwn,
    );
  }

  @override
  Future<PhoneTook?> take(PhoneInbox inbox, DateTime now) async {
    if (_closed) throw StateError('The phone’s ledger was closed');
    _db ??= await _own.open(device);
    final db = _db;
    if (db == null) return null;
    // Each is a row of this phone's own, written to its log: the folder
    // cycle's next look puts it in the phone's change file.
    final took = await db.takePhoneEntries([inbox], today: now);
    return (snapshot: await asItStands(now), take: took);
  }

  @override
  Future<PhoneSnapshot> undoTake(PhoneTake take, DateTime now) async {
    if (_closed) throw StateError('The phone’s ledger was closed');
    _db ??= await _own.open(device);
    final db = _db;
    if (db == null) throw StateError('The phone has no ledger of its own yet');
    await db.undoPhoneTake(take);
    return asItStands(now);
  }

  @override
  Future<PhoneEdited> editRow(PhoneRowEdit edit, DateTime now) async {
    final db = await _ledger();
    final before = await db.snapshot(edit.txn);
    await db.editTransaction(
      transactionId: edit.txn,
      accountId: edit.account,
      date: edit.date,
      today: now,
      payee: edit.payee,
      memo: edit.memo,
      counterAccountId: edit.counter,
      amount: edit.amount,
      splits: edit.splits,
    );
    final remembered = await _remember(db, edit);
    final after = await db.snapshot(edit.txn);
    return (
      snapshot: await asItStands(now),
      before: before,
      after: after,
      remembered: remembered,
    );
  }

  /// The box under the row: the category the row is in is remembered for
  /// its payee, with every spelling it has (#403).
  Future<Remembered?> _remember(AppDatabase db, PhoneRowEdit edit) async {
    final payee = edit.payee?.trim() ?? '';
    final category = edit.remember;
    if (category == null || payee.isEmpty) return null;
    return db.rememberPayee(
      accountId: edit.account,
      payee: payee,
      categoryId: category,
    );
  }

  @override
  Future<PhoneActed> confirmRow(PhoneRowConfirm confirm, DateTime now) async {
    final db = await _ledger();
    final edit = confirm.edit;
    final before = await db.snapshot(edit.txn);
    final owedId = await db.editTransaction(
      transactionId: edit.txn,
      accountId: edit.account,
      date: edit.date,
      today: now,
      payee: edit.payee,
      memo: edit.memo,
      counterAccountId: edit.counter,
      amount: edit.amount,
      confirm: true,
      keepOwed: confirm.keepOwed,
    );
    final remembered = await _remember(db, edit);
    final after = await db.snapshot(edit.txn);
    // Only its own: confirming a bill never touches pay.
    var next = const <int>[];
    var nextBills = const <int>[];
    final schedule = confirm.paySchedule;
    final planned = confirm.planCategory;
    if (schedule != null) {
      try {
        next = await db.ensurePaydays(now, only: schedule);
      } catch (e) {
        debugPrint('Scheduling the next payday failed: $e');
      }
    }
    if (planned != null) {
      try {
        nextBills = await db.ensurePlanBills(now, only: planned);
      } catch (e) {
        debugPrint('Scheduling the next bill failed: $e');
      }
    }
    return (
      snapshot: await asItStands(now),
      undo: () async {
        await db.transaction(() async {
          // The rule first: it may name a category the row's undo takes.
          if (remembered != null) await db.forgetRemembered(remembered);
          await db.dropPaydays(next);
          await db.dropPlanBills(nextBills);
          await db.restoreSnapshot(before);
          if (owedId != null) await db.softDeleteMany([owedId]);
        });
        return asItStands(now);
      },
      redo: () async {
        await db.transaction(() async {
          await db.restoreSnapshot(after);
          if (owedId != null) await db.restoreMany([owedId]);
          if (schedule != null) await db.bringBackPaydays(next, schedule);
          if (planned != null) await db.bringBackPlanBills(nextBills, planned);
          if (remembered != null) await db.redoRemembered(remembered);
        });
        return asItStands(now);
      },
    );
  }

  @override
  Future<PhoneSnapshot> restoreRow(
    TxnSnapshot row,
    DateTime now, {
    Remembered? remembered,
  }) async {
    final db = await _ledger();
    await db.transaction(() async {
      if (remembered != null) await db.forgetRemembered(remembered);
      await db.restoreSnapshot(row);
    });
    return asItStands(now);
  }

  @override
  Future<int> categoryRows(int id) async =>
      (await _ledger()).categoryEntryCount(id);

  @override
  Future<ImportPlan> planImport(
    int account,
    List<ImportRow> rows,
    List<String> keys,
  ) async => (await _ledger()).planImport(account, rows, keys);

  @override
  Future<PhoneActed> actOnRow(PhoneRowAct act, DateTime now) async {
    final db = await _ledger();
    Future<PhoneSnapshot> again() => asItStands(now);
    switch (act) {
      case PhoneMarkCleared(:final entry, :final to):
        final previous = await db.setClearedMany({entry: to});
        if (previous.isEmpty) throw LockedException(DbProblem.reconciled);
        return (
          snapshot: await again(),
          undo: () async {
            await db.setClearedMany(previous);
            return again();
          },
          redo: () async {
            await db.setClearedMany({entry: to});
            return again();
          },
        );
      case PhoneMoveRow(:final txn, :final from, :final to):
        final done = await db.moveToAccount(
          transactionId: txn,
          fromAccountId: from,
          toAccountId: to,
        );
        return (
          snapshot: await again(),
          undo: () async {
            await db.undoMove(done);
            return again();
          },
          redo: () async {
            await db.redoMove(done);
            return again();
          },
        );
      case PhoneNoBill(:final txn, :final planCategory, :final date):
        final data = await db.loadLedger();
        final plan = data.plans[planCategory];
        final pay = data.payScheduleById(plan?.payScheduleId);
        final due =
            (plan == null
                ? null
                : Budget.billDate(
                    plan,
                    date,
                    pay: pay,
                    skipped: Budget.skippedBills(data, plan),
                  )) ??
            date;
        final skipKey = billSkippedKey(txn);
        final skipValue = billSkippedValue(planCategory, due);
        final deleted = await db.softDeleteMany([txn]);
        if (deleted.isEmpty) throw LockedException(DbProblem.reconciled);
        await db.setPreference(skipKey, skipValue);
        final made = await db.ensurePlanBills(now, only: planCategory);
        return (
          snapshot: await again(),
          undo: () async {
            await db.transaction(() async {
              await db.dropPlanBills(made);
              await db.restoreMany(deleted);
              await db.setPreference(skipKey, null);
            });
            return again();
          },
          redo: () async {
            await db.transaction(() async {
              await db.softDeleteMany(deleted);
              await db.setPreference(skipKey, skipValue);
              await db.bringBackPlanBills(made, planCategory);
            });
            return again();
          },
        );
      case PhoneBillPaid():
        return _billPaid(db, act, now);
      case PhoneNotIt(:final bill, :final found):
        final key = billNotItKey(bill);
        final prefs = (await db.loadLedger()).prefs;
        final before = prefs[key];
        final after = {...billNotIt(prefs, bill), found}.join(',');
        await db.setPreference(key, after);
        return (
          snapshot: await again(),
          undo: () async {
            await db.setPreference(key, before);
            return again();
          },
          redo: () async {
            await db.setPreference(key, after);
            return again();
          },
        );
      case PhoneNotTheBill(:final row):
        return _notTheBill(db, row, now);
      case PhoneAssign(:final category, :final amount):
        final data = await db.loadLedger();
        final c = data.accounts[category];
        if (c == null) throw NotFoundException(DbProblem.notCategory);
        final today = dateOnly(now);
        final period = budgetPeriod(today, data.periodSchedule);
        final start = period.start, end = period.end;
        final began = beganBy(data, start, [c.currency]);
        final rows = budgetRows(
          data,
          Budget.of(data, start: start, end: end, today: today),
          c,
          period,
          amount,
          today: today,
        );
        Future<List<BudgetAmount>> write() async {
          final before = await db.setBudgetAmount(
            category,
            start,
            end,
            amount,
            rows: rows,
          );
          await _writeBegan(db, began);
          return before;
        }

        var before = await write();
        return (
          snapshot: await again(),
          undo: () async {
            await db.restoreBudgetAmounts(category, start, end, before);
            await _writeBegan(db, began, back: true);
            return again();
          },
          redo: () async {
            before = await write();
            return again();
          },
        );
      case PhoneMove(:final from, :final to, :final amount):
        final data = await db.loadLedger();
        final f = from == null ? null : data.accounts[from];
        final c = to == null ? null : data.accounts[to];
        if (amount <= 0 ||
            (f == null && c == null) ||
            (from != null && f == null) ||
            (to != null && c == null)) {
          throw NotFoundException(DbProblem.notCategory);
        }
        final today = dateOnly(now);
        final period = budgetPeriod(today, data.periodSchedule);
        final start = period.start, end = period.end;
        final began = beganBy(data, start, [?f?.currency, ?c?.currency]);
        final byId = moveRows(
          data,
          Budget.of(data, start: start, end: end, today: today),
          period,
          from: f,
          to: c,
          amount: amount,
          today: today,
        );
        late Map<int, List<BudgetAmount>> before;
        Future<void> write() async {
          before = await db.setBudgetAmounts(byId, start, end);
          await _writeBegan(db, began);
        }

        await write();
        return (
          snapshot: await again(),
          undo: () async {
            await db.restoreBudgetAmountsOf(before, start, end);
            await _writeBegan(db, began, back: true);
            return again();
          },
          redo: () async {
            await write();
            return again();
          },
        );
      case PhoneEditCategory(
        :final category,
        :final name,
        :final plan,
        :final type,
        :final paidFrom,
        :final skip,
        :final back,
        :final group,
        :final note,
      ):
        final data = await db.loadLedger();
        final c = data.accounts[category];
        if (c == null) throw NotFoundException(DbProblem.notCategory);
        final today = dateOnly(now);
        // Edit writes a name with an emoji as "🛒 Groceries"; one stored as
        // "🛒Groceries" that wasn't touched isn't renamed by a Save.
        final asEdit = withEmoji(
          splitEmoji(c.name).emoji,
          splitEmoji(c.name).rest,
        );
        final renamed = name != c.name && name != asEdit;
        String? text(String? v) =>
            v == null || v.trim().isEmpty ? null : v.trim();
        final details =
            text(group) != text(c.budgetGroup) || text(note) != text(c.note);
        final newPlan = plan?.forCategory(category);
        final planned = newPlan != data.plans[category];
        final money = paidFrom != null && paidFrom != data.paidFrom[category];
        final goalKey = ReadyKeys.goal(category);
        final goalWas = data.prefs[goalKey];
        final wantsGoal =
            type == CategoryType.goal && newPlan?.kind == PlanKind.byDate;
        final goal = wantsGoal != (goalWas == 'yes');
        // A late goal's choice goes with the mark, so it can't come back on
        // its own.
        final lateKey = ReadyKeys.goalLate(category);
        final lateWas = data.prefs[lateKey];
        final fundKey = BudgetKeys.fund(category);
        final fundWas = data.prefs[fundKey];
        final fund =
            (type == CategoryType.fund && newPlan == null) !=
            (fundWas == 'yes');
        late CategoryMoney moneyBefore;
        PlanChange? planChange;
        // A bill's switch (#365): skipped on its row when one is scheduled
        // for the date, else by a setting that keeps it from being
        // scheduled; brought back by the ledger's own way.
        final skips = <({String key, String value, List<int> deleted})>[];
        var skipMade = <int>[];
        final backs = <({Map<String, String> settings, List<int> made})>[];
        Future<void> billsWrite() async {
          for (final d in skip) {
            final rowId = sharedRowId('bill', '$category|${dateKey(d)}');
            int? row;
            for (final a in data.accounts.keys) {
              for (final r in data.registerFor(a).scheduled) {
                if (r.planCategoryId != category || r.amount >= 0) continue;
                if (r.txnId == rowId || r.date == d) row = r.txnId;
              }
            }
            final value = billSkippedValue(category, d);
            if (row == null) {
              final key = billSkippedDayKey(category, d);
              await db.setPreference(key, value);
              skips.add((key: key, value: value, deleted: const []));
            } else {
              final deleted = await db.softDeleteMany([row]);
              if (deleted.isEmpty) throw LockedException(DbProblem.reconciled);
              final key = billSkippedKey(row);
              await db.setPreference(key, value);
              skips.add((key: key, value: value, deleted: deleted));
            }
          }
          if (skip.isNotEmpty) {
            skipMade = await db.ensurePlanBills(now, only: category);
          }
          for (final d in back) {
            backs.add(await db.bringBackBill(category, d, today));
          }
        }

        Future<void> billsUndo() async {
          for (final b in backs.reversed) {
            await db.dropPlanBills(b.made);
            for (final e in b.settings.entries) {
              await db.setPreference(e.key, e.value);
            }
          }
          if (skips.isNotEmpty) {
            await db.dropPlanBills(skipMade);
            for (final k in skips) {
              if (k.deleted.isNotEmpty) await db.restoreMany(k.deleted);
              await db.setPreference(k.key, null);
            }
          }
        }

        Future<void> billsRedo() async {
          for (final k in skips) {
            if (k.deleted.isNotEmpty) await db.softDeleteMany(k.deleted);
            await db.setPreference(k.key, k.value);
          }
          if (skips.isNotEmpty) {
            await db.bringBackPlanBills(skipMade, category);
          }
          for (final b in backs) {
            for (final k in b.settings.keys) {
              await db.setPreference(k, null);
            }
            await db.bringBackPlanBills(b.made, category);
          }
        }

        Future<void> write() => db.transaction(() async {
          if (renamed) await db.renameAccount(category, name);
          if (money) {
            moneyBefore = await db.setCategoryMoney(
              category,
              currency: c.currency,
              paidFrom: paidFrom,
            );
          }
          if (planned) {
            planChange = await db.changeCategoryPlan(category, newPlan, today);
          }
          if (goal) {
            await db.setPreference(goalKey, wantsGoal ? 'yes' : null);
            await db.setPreference(lateKey, null);
          }
          if (fund) {
            await db.setPreference(
              fundKey,
              type == CategoryType.fund && newPlan == null ? 'yes' : null,
            );
          }
          if (details) {
            await db.setCategoryDetails(category, group: group, note: note);
          }
        });

        await db.transaction(() async {
          await billsWrite();
          await write();
        });
        return (
          snapshot: await again(),
          undo: () async {
            await db.transaction(() async {
              if (details) {
                await db.setCategoryDetails(
                  category,
                  group: c.budgetGroup,
                  note: c.note,
                );
              }
              if (fund) await db.setPreference(fundKey, fundWas);
              if (goal) {
                await db.setPreference(goalKey, goalWas);
                await db.setPreference(lateKey, lateWas);
              }
              if (planned) await db.undoPlanChange(category, planChange!);
              if (money) {
                await db.restoreCategoryMoney(category, moneyBefore);
                // A plan a change of Paid from took away comes back.
                await db.ensurePlanBills(today, only: category);
              }
              if (renamed) await db.renameAccount(category, c.name);
              await billsUndo();
            });
            return again();
          },
          redo: () async {
            await db.transaction(() async {
              await billsRedo();
              await write();
            });
            return again();
          },
        );
      case PhoneArchiveCategory(:final category, :final archived):
        await db.setArchived(category, archived);
        return (
          snapshot: await again(),
          undo: () async {
            await db.setArchived(category, !archived);
            return again();
          },
          redo: () async {
            await db.setArchived(category, archived);
            return again();
          },
        );
      case PhoneDeleteCategory(:final category, :final into):
        var done = await db.deleteCategory(category, into: into);
        return (
          snapshot: await again(),
          undo: () async {
            await db.undeleteCategory(done);
            return again();
          },
          redo: () async {
            done = await db.deleteCategory(category, into: into);
            return again();
          },
        );
      case PhoneSavePay() || PhoneStopPay() || PhoneNoPay():
        return actOnPay(db, act, now, again);
      case PhoneSetSpan():
        return actOnSpan(db, act, again);
      case PhoneSetupDate() || PhoneBudgetBy() || PhoneFinishSetup():
        return actOnSetup(db, act, now, again);
      case PhoneSavingsAnswer():
        return actOnSavings(db, act, now, again);
      case PhoneAddAccount() ||
          PhoneEditAccount() ||
          PhoneArchiveAccount() ||
          PhoneDeleteAccount():
        return actOnAccount(db, act, now, again);
      case PhoneSavePayee() ||
          PhoneDeletePayee() ||
          PhoneFilePayees() ||
          PhoneShowPayeeNames():
        return actOnPayee(db, act, now, again);
      case PhoneDeleteRow(:final txn):
        final deleted = await db.softDeleteMany([txn]);
        if (deleted.isEmpty) throw LockedException(DbProblem.reconciled);
        return (
          snapshot: await again(),
          undo: () async {
            await db.restoreMany(deleted);
            return again();
          },
          redo: () async {
            await db.softDeleteMany(deleted);
            return again();
          },
        );
      case PhoneReconcile() || PhoneUndoReconcile():
        return actOnReconcile(db, act, now, again);
      case PhoneImport():
        return actOnImport(db, act, now, again);
    }
  }

  /// The day the budget began, and its currency, written or put back, as
  /// the computer's `_writeBegan` does.
  Future<void> _writeBegan(
    AppDatabase db,
    List<BudgetBegan> began, {
    bool back = false,
  }) async {
    for (final b in began) {
      await db.setPreference(b.key, back ? b.was : b.now);
      if (b.currency != null) {
        await db.setPreference(BudgetKeys.currency, back ? null : b.currency);
      }
    }
  }

  /// Ties [act]'s row to its bill, as the computer's `_tieBill` does.
  Future<PhoneActed> _billPaid(
    AppDatabase db,
    PhoneBillPaid act,
    DateTime now,
  ) async {
    final tied = await tieBill(db, act, now);
    return (
      snapshot: await asItStands(now),
      undo: () async {
        await tied.undo();
        return asItStands(now);
      },
      redo: () async {
        await tied.redo();
        return asItStands(now);
      },
    );
  }

  /// "Not this bill", as the computer's `_notThisBill` does.
  Future<PhoneActed> _notTheBill(
    AppDatabase db,
    RegisterRow r,
    DateTime now,
  ) async {
    final data = await db.loadLedger();
    final paidKey = billPaidKey(r.txnId);
    final recordValue = data.prefs[paidKey];
    final record = decodeBillPaid(recordValue);
    if (record == null) throw NotFoundException(DbProblem.notSingleCategory);
    final planned = r.planCategoryId;
    final notItKey = billNotItKey(record.bill);
    final notItBefore = data.prefs[notItKey];
    final skippedBefore = {
      for (final s in record.skipped)
        billSkippedKey(s): data.prefs[billSkippedKey(s)],
    };
    final billBefore = await db.snapshot(record.bill);
    final made = await db.notTheBill(
      rowId: r.txnId,
      planCategoryId: planned,
      record: record,
      today: now,
    );
    final billAfter = await db.snapshot(record.bill);
    final notItAfter = await db.preference(notItKey);
    return (
      snapshot: await asItStands(now),
      undo: () async {
        await db.transaction(() async {
          await db.dropPlanBills(made);
          await db.restoreSnapshot(billBefore);
          if (record.skipped.isNotEmpty) {
            await db.softDeleteMany(record.skipped);
          }
          for (final e in skippedBefore.entries) {
            await db.setPreference(e.key, e.value);
          }
          await db.setPreference(notItKey, notItBefore);
          await db.setPreference(paidKey, recordValue);
          if (planned != null) await db.setPlanBill(r.txnId, planned);
        });
        return asItStands(now);
      },
      redo: () async {
        await db.transaction(() async {
          if (planned != null) await db.setPlanBill(r.txnId, null);
          await db.restoreSnapshot(billAfter);
          if (record.skipped.isNotEmpty) await db.restoreMany(record.skipped);
          for (final k in skippedBefore.keys) {
            await db.setPreference(k, null);
          }
          await db.setPreference(notItKey, notItAfter);
          await db.setPreference(paidKey, null);
          if (planned != null) await db.bringBackPlanBills(made, planned);
        });
        return asItStands(now);
      },
    );
  }

  Future<AppDatabase> _ledger() async {
    if (_closed) throw StateError('The phone’s ledger was closed');
    _db ??= await _own.open(device);
    final db = _db;
    if (db == null) throw StateError('The phone has no ledger of its own yet');
    return db;
  }

  /// The folder's ledger has everything this phone's has and more, and
  /// nothing was changed here (the folder's change files were cut past what
  /// this phone had seen: it was away a long time): it is taken in whole.
  Future<void> _takeFolderLedger(CloudFolder cloud, DateTime now) async {
    final theirs = cloud.theirs;
    if (theirs == null) return;
    final backups = Backups(_db!, dataKey: _key);
    final candidate = await backups.inspect(theirs.copy.path, now);
    final before = cloud.mineDigest;
    if (before == null) {
      await backups.discard(candidate);
      return;
    }
    try {
      final done = await backups.restore(
        candidate,
        now,
        fromFolder: true,
        onlyIfDigest: before,
      );
      // A phone keeps no copies to restore from: the folder holds them.
      for (final f in [done.before, done.restored]) {
        if (f.existsSync()) await f.delete();
      }
    } on ChangedSinceException {
      // Changed meanwhile: the next look works it out again.
    }
  }

  Future<void> _keepLooked(DateTime at) async {
    try {
      await _own.dir.create(recursive: true);
      await _lookedFile.writeAsString(
        '${at.millisecondsSinceEpoch}',
        flush: true,
      );
    } catch (e) {
      debugPrint('The time of the last look couldn’t be kept: $e');
    }
  }

  Future<DateTime?> _looked() async {
    try {
      if (!_lookedFile.existsSync()) return null;
      return DateTime.fromMillisecondsSinceEpoch(
        int.parse((await _lookedFile.readAsString()).trim()),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
    _cloud?.dispose();
    _cloud = null;
    await _db?.close();
    _db = null;
  }

  @override
  Future<void> leave() async {
    await close();
    if (_own.dir.existsSync()) await _own.dir.delete(recursive: true);
  }
}

/// Does a regular income's act (#528): save, stop, or say there is none,
/// each with its undo and redo, as the computer's `_applyPay` does. Shared
/// by the phone's ledger and the tests' stand-in, so there is one copy.
Future<PhoneActed> actOnPay(
  AppDatabase db,
  PhoneRowAct act,
  DateTime now,
  Future<PhoneSnapshot> Function() again,
) async {
  switch (act) {
    case PhoneSavePay(:final id, :final draft):
      final data = await db.loadLedger();
      final today = dateOnly(now);
      late PayChange change;
      final wasNone = id == null ? data.prefs[noRegularPayKey] : null;
      await db.transaction(() async {
        change = await db.savePaySchedule(
          id: id,
          accountId: draft.accountId,
          name: draft.name,
          payee: draft.payee,
          amount: draft.amount,
          amount2: draft.amount2,
          varies: draft.varies,
          rule: draft.rule,
          day1: draft.day1,
          day2: draft.day2,
          weeks: draft.weeks,
          anchor: draft.anchor,
          repeat: draft.repeat,
          weekend: draft.weekend,
          // The Budget page's view is chosen there; editing a pay leaves it.
          definesPeriod: id == null
              ? false
              : data.payScheduleById(id)?.definesPeriod ?? false,
          today: today,
        );
        // Pay added after "I don't have regular income": the saying no
        // longer holds. Undone together.
        if (wasNone != null) await db.setPreference(noRegularPayKey, null);
      });
      act.replaced = change.replaced.length;
      return (
        snapshot: await again(),
        undo: () async {
          await db.transaction(() async {
            await db.undoPayChange(change);
            if (wasNone != null) {
              await db.setPreference(noRegularPayKey, wasNone);
            }
          });
          return again();
        },
        redo: () async {
          await db.transaction(() async {
            await db.redoPayChange(change);
            if (wasNone != null) await db.setPreference(noRegularPayKey, null);
          });
          return again();
        },
      );
    case PhoneStopPay(:final id):
      final data = await db.loadLedger();
      final today = dateOnly(now);
      final existing = data.payScheduleById(id);
      if (existing == null) throw NotFoundException(DbProblem.payIsIn);
      // The categories per this pay go by the month, as the computer's
      // dialog starts them: one undo with the stop.
      final moved = <int, CategoryPlan>{};
      final after = existing.nextAfter(today);
      final next = after == payNever ? today : after;
      for (final p in data.plans.values) {
        if (p.payScheduleId == id) {
          moved[p.categoryId] = p.movedToPay(null, nextPayday: next);
        }
      }
      late PayChange change;
      final planChanges = <int, PlanChange>{};
      await db.transaction(() async {
        change = await db.stopPaySchedule(id, today);
        for (final e in moved.entries) {
          planChanges[e.key] = await db.changeCategoryPlan(
            e.key,
            e.value,
            today,
          );
        }
      });
      return (
        snapshot: await again(),
        undo: () async {
          await db.transaction(() async {
            for (final e in planChanges.entries) {
              await db.undoPlanChange(e.key, e.value);
            }
            await db.undoPayChange(change);
          });
          return again();
        },
        redo: () async {
          await db.transaction(() async {
            await db.redoPayChange(change);
            for (final e in planChanges.entries) {
              await db.redoPlanChange(e.key, moved[e.key], e.value);
            }
          });
          return again();
        },
      );
    case PhoneNoPay(:final none):
      final old = (await db.loadLedger()).prefs[noRegularPayKey];
      final value = none ? '1' : null;
      // Said already: nothing changes, so nothing is undone (as the
      // computer's `_setNoRegularPay`).
      if (old != value) await db.setPreference(noRegularPayKey, value);
      return (
        snapshot: await again(),
        undo: () async {
          await db.setPreference(noRegularPayKey, old);
          return again();
        },
        redo: () async {
          await db.setPreference(noRegularPayKey, value);
          return again();
        },
      );
    default:
      throw ArgumentError('Not a regular income act: $act');
  }
}

/// Setup's writes on the phone (#534), as the computer's setup makes them:
/// the balances' day, budget by month or paycheck, and the finish, each
/// with its undo and redo.
Future<PhoneActed> actOnSetup(
  AppDatabase db,
  PhoneRowAct act,
  DateTime now,
  Future<PhoneSnapshot> Function() again,
) async {
  switch (act) {
    case PhoneSetupDate(:final date):
      final old = await db.preference(SetupKeys.date);
      final key = dateKey(date);
      var was = <int, String>{};
      Future<void> write() => db.transaction(() async {
        was = await db.redateOpeningBalances(date);
        await db.setPreference(SetupKeys.date, key);
      });
      if (old != key) await write();
      return (
        snapshot: await again(),
        undo: () async {
          if (old != key) {
            await db.transaction(() async {
              await db.setTransactionDates(was);
              await db.setPreference(SetupKeys.date, old);
            });
          }
          return again();
        },
        redo: () async {
          if (old != key) await write();
          return again();
        },
      );
    case PhoneBudgetBy(:final schedule):
      final splitWas = await db.preference(BudgetKeys.splitBy);
      Future<List<int>> write() => db.transaction(() async {
        final before = await db.setPeriodSchedule(schedule);
        // Kept: a month's Assigned is split by the pay last viewed by.
        if (schedule != null) {
          await db.setPreference(BudgetKeys.splitBy, '$schedule');
        }
        return before;
      });
      final before = await write();
      return (
        snapshot: await again(),
        undo: () async {
          await db.transaction(() async {
            await db.setPeriodSchedule(before.firstOrNull);
            await db.setPreference(BudgetKeys.splitBy, splitWas);
          });
          return again();
        },
        redo: () async {
          await write();
          return again();
        },
      );
    case PhoneFinishSetup(
      :final had,
      :final emergency,
      :final safetyNetName,
      :final follows,
      :final saveIn,
    ):
      final done = await finishSetup(
        db,
        had: had,
        emergency: emergency,
        today: dateOnly(now),
        safetyNetName: safetyNetName,
        follows: follows,
        saveIn: saveIn,
      );
      return (
        snapshot: await again(),
        undo: () async {
          await done.undo();
          return again();
        },
        redo: () async {
          await done.redo();
          return again();
        },
      );
    default:
      throw ArgumentError('Not a setup act: $act');
  }
}

/// A forecast range picked (#529): the choice, and with Custom… its day,
/// written as the computer writes them, with the earlier choice put back by
/// Undo (the page offers none: it is a view).
Future<PhoneActed> actOnSpan(
  AppDatabase db,
  PhoneSetSpan act,
  Future<PhoneSnapshot> Function() again,
) async {
  final prefs = (await db.loadLedger()).prefs;
  final before = (
    span: prefs[ForecastSpan.prefKey],
    end: prefs[ForecastSpan.customEndKey],
  );
  Future<void> write(String? span, String? end) async {
    await db.transaction(() async {
      if (end != null || act.customEnd != null) {
        await db.setPreference(ForecastSpan.customEndKey, end);
      }
      await db.setPreference(ForecastSpan.prefKey, span);
    });
  }

  final end = act.customEnd == null
      ? null
      : dateOnly(act.customEnd!).toIso8601String();
  await db.transaction(() async {
    if (end != null) await db.setPreference(ForecastSpan.customEndKey, end);
    await db.setPreference(ForecastSpan.prefKey, act.span.name);
  });
  return (
    snapshot: await again(),
    undo: () async {
      await write(before.span, before.end);
      return again();
    },
    redo: () async {
      await write(act.span.name, end);
      return again();
    },
  );
}

/// Writes a Savings answer (#533) and returns its Undo and Redo, which put
/// back and write again every preference it changed, in one go. One that
/// changes nothing writes nothing.
Future<PhoneActed> actOnSavings(
  AppDatabase db,
  PhoneSavingsAnswer act,
  DateTime now,
  Future<PhoneSnapshot> Function() again,
) async {
  final values = {...act.values};
  if (act.aside case (final step, final aside)?) {
    values[ReadyKeys.setAside] = Readiness.setAsideStored(
      await db.preference(ReadyKeys.setAside),
      step,
      aside,
    );
  }
  final before = <String, String?>{
    for (final key in values.keys) key: await db.preference(key),
  };
  final role = act.role;
  final roleWas = role == null
      ? null
      : (await db.loadLedger()).accounts[role.$1]?.role;
  final changes =
      values.entries.any((e) => before[e.key] != e.value) ||
      (role != null && roleWas != role.$2);
  Future<void> write(Map<String, String?> v, AccountRole? r) async {
    if (!changes) return;
    await db.transaction(() async {
      for (final e in v.entries) {
        await db.setPreference(e.key, e.value);
      }
      if (role != null) await db.setAccountRole(role.$1, r);
    });
  }

  // The answers and a goal's moved plan in one transaction: a plan the
  // ledger refuses (its category gone meanwhile) leaves the answers as they
  // were too (code review, #533).
  final plan = act.plan;
  final change = await db.transaction(() async {
    await write(values, role?.$2);
    return plan == null
        ? null
        : await db.changeCategoryPlan(plan.$1, plan.$2, dateOnly(now));
  });
  return (
    snapshot: await again(),
    undo: () async {
      await db.transaction(() async {
        if (plan != null) await db.undoPlanChange(plan.$1, change!);
        await write(before, roleWas);
      });
      return again();
    },
    redo: () async {
      await db.transaction(() async {
        await write(values, role?.$2);
        if (plan != null) await db.redoPlanChange(plan.$1, plan.$2, change!);
      });
      return again();
    },
  );
}

/// Ties [act]'s row to its bill, as the computer's `_tieBill` does: the
/// row is that bill paid and the bill goes. Returns what Undo and Redo
/// write. Shared by a bill answered on the phone and by an import, whose
/// rows pay their bills in its own undo.
Future<({Future<void> Function() undo, Future<void> Function() redo})> tieBill(
  AppDatabase db,
  PhoneBillPaid act,
  DateTime now,
) async {
  final bill = act.bill, found = act.found;
  final planned = bill.planCategoryId;
  // A split is that bill only with a line in its category.
  final tie =
      planned != null &&
      (found.kind == RowKind.simple ||
          found.splitLines.any((l) => l.accountId == planned));
  final short = bill.amount.abs() - found.amount.abs();
  final rest = act.keepRest && short > 0 && bill.kind == RowKind.simple
      ? bill.amount - found.amount
      : null;
  final notItKey = billNotItKey(bill.txnId);
  final prefs = (await db.loadLedger()).prefs;
  final notItBefore = prefs[notItKey];
  final notIt = rest == null
      ? null
      : tie
      ? notItBefore
      : {...billNotIt(prefs, bill.txnId), found.txnId}.join(',');
  final tiedBefore = found.planCategoryId;
  final billBefore = await db.snapshot(bill.txnId);
  final done = await db.payBill(
    billId: bill.txnId,
    billAccountId: bill.accountId,
    foundId: found.txnId,
    today: now,
    planCategoryId: planned,
    tie: tie,
    rest: rest,
    notIt: notIt,
    bills: act.bills,
  );
  final billAfter = await db.snapshot(bill.txnId);
  // Bills scheduled before and skipped with this one come back on undo.
  final hadSkipped = [
    for (final id in done.skipped)
      if (!done.made.contains(id)) id,
  ];
  return (
    undo: () async {
      await db.transaction(() async {
        await db.dropPlanBills(done.made);
        if (hadSkipped.isNotEmpty) await db.restoreMany(hadSkipped);
        // Only its tie: whatever was done to the row since stays.
        if (tie) await db.setPlanBill(found.txnId, tiedBefore);
        await db.restoreSnapshot(billBefore);
        await db.setPreference(notItKey, notItBefore);
        for (final k in done.wrote.keys) {
          await db.setPreference(k, null);
        }
      });
    },
    redo: () async {
      await db.transaction(() async {
        await db.restoreSnapshot(billAfter);
        if (tie) await db.setPlanBill(found.txnId, planned);
        if (planned != null) await db.bringBackPlanBills(done.made, planned);
        if (done.skipped.isNotEmpty) await db.softDeleteMany(done.skipped);
        await db.setPreference(notItKey, notIt);
        for (final e in done.wrote.entries) {
          await db.setPreference(e.key, e.value);
        }
      });
    },
  );
}

/// Writes a bank file's rows into an account (#531) with its undo and redo,
/// as the computer's `_startImport` does once Import is clicked: the rows,
/// then each bill one of them paid, tied now and undone with the rows; the
/// columns are kept for the account's next file. Shared by the phone's
/// ledger and the tests' stand-in, so there is one copy.
Future<PhoneActed> actOnImport(
  AppDatabase db,
  PhoneImport act,
  DateTime now,
  Future<PhoneSnapshot> Function() again,
) async {
  final record = await db.applyImport(
    accountId: act.account,
    plan: act.plan,
    moveOpening: act.moveOpening,
    start: act.start,
    today: dateOnly(now),
    uncategorizedNames: {act.uncategorized, ...uncategorizedNames}.toList(),
  );
  final ties =
      <({Future<void> Function() undo, Future<void> Function() redo})>[];
  var toCheck = 0;
  // The earliest row to check, which the bar's Show opens.
  RegisterRow? checkRow;
  void toAsk(RegisterRow r) {
    toCheck++;
    final c = checkRow;
    if (c == null ||
        r.date.isBefore(c.date) ||
        (r.date == c.date && r.txnId < c.txnId)) {
      checkRow = r;
    }
  }

  if (record.added.isNotEmpty) {
    try {
      final data = await db.loadLedger();
      final payments = billPayments(
        data,
        dateOnly(now),
        uncategorizedId: data.categories.where(isUncategorized).firstOrNull?.id,
      );
      for (final p in payments.values) {
        if (!record.added.containsKey(p.row.txnId) ||
            p.bill.planCategoryId == null) {
          continue;
        }
        // Not near its bill: left for the person, who is asked on the row.
        if (p.fit != BillFit.paid) {
          toAsk(p.row);
          continue;
        }
        // One that can't be tied is left to be asked about, and the rest
        // go on, as on the computer.
        try {
          ties.add(await tieBill(db, PhoneBillPaid(p.bill, p.row), now));
        } catch (e) {
          debugPrint('Tying an imported row to its bill failed: $e');
          toAsk(p.row);
        }
      }
    } catch (e) {
      debugPrint('Looking for bills an import paid failed: $e');
    }
  }
  // The rows are in either way, so a failure here only costs guessing the
  // columns again next time.
  if (act.mapping case final mapping?) {
    try {
      await db.setPreference(
        AppDatabase.importMappingKey(act.account),
        mapping,
      );
    } catch (e) {
      debugPrint('Saving the import columns failed: $e');
    }
  }
  act.done = (
    record: record,
    billsPaid: ties.length,
    billsToCheck: toCheck,
    checkRow: checkRow?.txnId,
  );
  return (
    snapshot: await again(),
    // One write each way: a tie undone and the import refused would leave
    // half of it.
    undo: () async {
      await db.transaction(() async {
        for (final tie in ties.reversed) {
          await tie.undo();
        }
        await db.undoImport(record);
      });
      return again();
    },
    redo: () async {
      await db.transaction(() async {
        await db.redoImport(record, act.account);
        for (final tie in ties) {
          await tie.redo();
        }
      });
      return again();
    },
  );
}

/// Reconciles an account or takes its newest reconcile back (#530), each
/// with its undo and redo, as the computer's header does. Shared by the
/// phone's ledger and the tests' stand-in, so there is one copy. Throws
/// what the ledger refuses: a statement that no longer matches, a date it
/// can't take, no reconcile to take back.
Future<PhoneActed> actOnReconcile(
  AppDatabase db,
  PhoneRowAct act,
  DateTime now,
  Future<PhoneSnapshot> Function() again,
) async {
  switch (act) {
    case PhoneReconcile():
      final done = await db.reconcile(
        accountId: act.account,
        statementDate: act.date,
        today: now,
        balance: act.balance,
        adjust: act.adjustBy != null,
        adjustBy: act.adjustBy,
      );
      act.done = done;
      return (
        snapshot: await again(),
        undo: () async {
          await db.unreconcile(done);
          return again();
        },
        redo: () async {
          await db.relock(done);
          return again();
        },
      );
    case PhoneUndoReconcile():
      final done = await db.unreconcileLast(act.account);
      act.done = done;
      return (
        snapshot: await again(),
        undo: () async {
          await db.relock(done);
          return again();
        },
        redo: () async {
          await db.unreconcile(done);
          return again();
        },
      );
    default:
      throw ArgumentError('Not a reconcile: $act');
  }
}

/// Does a payee's act (#532), each with its undo and redo, as the
/// computer's Payees page does. Shared by the phone's ledger and the tests'
/// stand-in, so there is one copy.
Future<PhoneActed> actOnPayee(
  AppDatabase db,
  PhoneRowAct act,
  DateTime now,
  Future<PhoneSnapshot> Function() again,
) async {
  switch (act) {
    case PhoneSavePayee(before: final opened, :final after):
      final data = await db.loadLedger();
      // As it stands now, not as the card opened on it: a change brought in
      // from another computer since is what Undo puts back.
      final before = opened == null
          ? null
          : data.payeeRules.where((r) => r.id == opened.id).firstOrNull;
      if (opened != null && before == null) {
        throw NotFoundException(DbProblem.changedSince);
      }
      final (:twins, :clash) = payeeOverlaps(data, before, after);
      if (clash != null) {
        throw StateError('Another payee already goes by those words');
      }
      final written = await writePayee(db, before, after, twins);
      act.saved = written.saved;
      return (
        snapshot: await again(),
        undo: () async {
          await written.undo();
          return again();
        },
        redo: () async {
          await written.redo();
          return again();
        },
      );
    case PhoneDeletePayee(rule: final opened):
      // As it stands now: a change brought in since isn't written over.
      final rule = (await db.loadLedger()).payeeRules
          .where((r) => r.id == opened.id)
          .firstOrNull;
      if (rule == null) throw NotFoundException(DbProblem.changedSince);
      final gone = rule.copyWith(deleted: true);
      await db.putPayeeRule(gone);
      return (
        snapshot: await again(),
        undo: () async {
          await db.putPayeeRule(rule);
          return again();
        },
        redo: () async {
          await db.putPayeeRule(gone);
          return again();
        },
      );
    case PhoneFilePayees(:final rules):
      final data = await db.loadLedger();
      final filings = [
        for (final r in data.payeeRules)
          if (rules.contains(r.id) && !r.deleted)
            WaitingFiling(db, data, r, payeeWaitingFor(data, r, now), now),
      ];
      await db.transaction(() async {
        for (final f in filings) {
          await f.write();
        }
      });
      act.filed = filings.fold(0, (n, f) => n + f.waiting.length);
      return (
        snapshot: await again(),
        undo: () async {
          await db.transaction(() async {
            for (final f in filings.reversed) {
              await f.undo();
            }
          });
          return again();
        },
        redo: () async {
          await db.transaction(() async {
            for (final f in filings) {
              await f.write();
            }
          });
          return again();
        },
      );
    case PhoneShowPayeeNames(:final rules):
      final data = await db.loadLedger();
      // Each row once, under the payee its own words pick.
      final byRule = {
        for (final r in data.payeeRules)
          if (rules.contains(r.id) && !r.deleted)
            r: {for (final x in payeeUnnamedFor(data, r)) x.txnId},
      };
      var before = <int, PayeeBefore>{};
      Future<void> write() => db.transaction(() async {
        before = {};
        for (final e in byRule.entries) {
          if (e.value.isEmpty) continue;
          before.addAll(
            await db.renamePayeeMany(
              transactionIds: e.value,
              name: e.key.shownAs.trim(),
            ),
          );
        }
      });
      await write();
      act.shown = before.length;
      return (
        snapshot: await again(),
        undo: () async {
          await db.restorePayees(before);
          return again();
        },
        redo: () async {
          await write();
          return again();
        },
      );
    default:
      throw ArgumentError('Not a payee act: $act');
  }
}

/// Does an account's act (#529), each with its undo and redo, as the
/// computer's accounts page does. Shared by the phone's ledger and the
/// tests' stand-in, so there is one copy.
Future<PhoneActed> actOnAccount(
  AppDatabase db,
  PhoneRowAct act,
  DateTime now,
  Future<PhoneSnapshot> Function() again,
) async {
  switch (act) {
    case PhoneAddAccount():
      late int id;
      int? opening;
      // The account, its rate and what it starts with are one write: none of
      // them is left behind when another fails.
      await db.transaction(() async {
        id = await db.createAccount(
          name: act.name,
          type: act.type,
          currency: act.currency,
          cash: act.cash,
        );
        // Kept for Savings, step 2.
        if (act.rate != null) {
          await db.setPreference(ReadyKeys.rate(id), act.rate);
        }
        final typed = act.balance;
        if (typed != null && typed != 0) {
          // A card's balance is typed as what's owed, positive, as the bank
          // shows it.
          opening = await db.postOpeningBalance(
            accountId: id,
            date: act.date,
            balance: act.type == AccountType.liability ? -typed : typed,
          );
        }
      });
      act.made = id;
      return (
        snapshot: await again(),
        undo: () async {
          // Only while it is still empty: undo never deletes rows unasked.
          // All or nothing: a row entered since leaves the opening balance
          // where it is, and the refusal is said.
          await db.transaction(() async {
            if (opening != null) {
              final gone = await db.softDeleteMany([opening!]);
              if (gone.length != 1) {
                throw LockedException(DbProblem.reconciled);
              }
            }
            if (!await db.deleteEmptyAccount(id)) {
              throw LockedException(DbProblem.stillHasRows);
            }
          });
          return again();
        },
        redo: () async {
          await db.transaction(() async {
            await db.undeleteAccount(DeletedAccount(id, const []));
            if (opening != null) await db.restoreMany([opening!]);
            if (act.rate != null) {
              await db.setPreference(ReadyKeys.rate(id), act.rate);
            }
          });
          return again();
        },
      );
    case PhoneEditAccount(:final account, :final edit):
      final done = await editAccount(db, account, edit);
      act.flipped = done.flipped;
      return (
        snapshot: await again(),
        undo: () async {
          await done.undo();
          return again();
        },
        redo: () async {
          await done.redo();
          return again();
        },
      );
    case PhoneArchiveAccount(:final account, :final archived):
      await db.setArchived(account, archived);
      return (
        snapshot: await again(),
        undo: () async {
          await db.setArchived(account, !archived);
          return again();
        },
        redo: () async {
          await db.setArchived(account, archived);
          return again();
        },
      );
    case PhoneDeleteAccount(:final account):
      var deleted = await db.deleteAccount(account);
      return (
        snapshot: await again(),
        undo: () async {
          await db.undeleteAccount(deleted);
          return again();
        },
        redo: () async {
          deleted = await db.deleteAccount(account);
          return again();
        },
      );
    default:
      throw ArgumentError('Not an account act: $act');
  }
}
