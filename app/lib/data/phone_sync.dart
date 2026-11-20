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

import '../domain/budget.dart' show Budget;
import '../domain/combine.dart' show Ask, Pick;
import '../domain/ledger.dart' show Cleared, billSkippedKey, billSkippedValue;
import '../domain/phone.dart';
import '../domain/sync.dart' show appliedMarkerOp;
import 'backup.dart';
import 'cloud_folder.dart';
import 'database.dart'
    show
        AppDatabase,
        ChangedSinceException,
        DbProblem,
        LockedException,
        PhoneTake,
        SplitPart,
        TxnSnapshot;
import 'folder_io.dart';
import 'phone_ledger.dart';
import 'phone_own_ledger.dart';

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
/// leave them.
typedef PhoneRowEdit = ({
  int txn,
  int account,
  DateTime date,
  String? payee,
  String? memo,
  int? counter,
  int? amount,
  List<SplitPart>? splits,
});

/// A scheduled row confirmed (#527): the edit as the person made it, and the
/// payday's schedule or the plan's category the row came from, whose next
/// one is scheduled once this one is real.
typedef PhoneRowConfirm = ({
  PhoneRowEdit edit,
  int? paySchedule,
  int? planCategory,
});

/// An edit done: the ledger as it stands after, and the row as it was and
/// as it is, which undo and redo put back.
typedef PhoneEdited = ({
  PhoneSnapshot snapshot,
  TxnSnapshot before,
  TxnSnapshot after,
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

class PhoneDeleteRow extends PhoneRowAct {
  const PhoneDeleteRow(this.txn);
  final int txn;
}

/// An act done: the ledger after it, and what Undo and Redo do, each
/// returning the ledger after (and throwing what the ledger refuses).
typedef PhoneActed = ({
  PhoneSnapshot snapshot,
  Future<PhoneSnapshot> Function() undo,
  Future<PhoneSnapshot> Function() redo,
});

abstract class PhoneLedgerSource {
  /// Whether this phone already has a ledger of its own.
  bool get joined;

  /// Takes [folderLedger], the ledger as it sits in the folder, as this
  /// phone's own. Throws [WrongKeyException] when the key doesn't open it.
  Future<void> join(Uint8List folderLedger);

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

  /// Puts a row back as [row] was, for Undo and Redo of an edit.
  Future<PhoneSnapshot> restoreRow(TxnSnapshot row, DateTime now) =>
      throw UnsupportedError('This source keeps no ledger to edit');

  /// Does what a row's ⋯ menu asked, as a change the computers see (#527).
  /// Throws what the ledger refuses (a reconciled row).
  Future<PhoneActed> actOnRow(PhoneRowAct act, DateTime now) =>
      throw UnsupportedError('This source keeps no ledger to edit');

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
  }) : _own = PhoneOwnLedger(Directory('${dir.path}/own'), dataKey),
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
    final ids = (await _unapplied(db, seen)).entries;
    return snapshotOf(
      await db.loadLedger(),
      today: now,
      madeAt: await _looked() ?? now,
      mineIds: ids,
      device: device,
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
    final after = await db.snapshot(edit.txn);
    return (snapshot: await asItStands(now), before: before, after: after);
  }

  @override
  Future<PhoneActed> confirmRow(PhoneRowConfirm confirm, DateTime now) async {
    final db = await _ledger();
    final edit = confirm.edit;
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
      confirm: true,
    );
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
          await db.dropPaydays(next);
          await db.dropPlanBills(nextBills);
          await db.restoreSnapshot(before);
        });
        return asItStands(now);
      },
      redo: () async {
        await db.transaction(() async {
          await db.restoreSnapshot(after);
          if (schedule != null) await db.bringBackPaydays(next, schedule);
          if (planned != null) await db.bringBackPlanBills(nextBills, planned);
        });
        return asItStands(now);
      },
    );
  }

  @override
  Future<PhoneSnapshot> restoreRow(TxnSnapshot row, DateTime now) async {
    final db = await _ledger();
    await db.restoreSnapshot(row);
    return asItStands(now);
  }

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
    }
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
