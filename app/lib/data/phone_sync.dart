// The phone as a member of the folder (ADR 0005, "The phone joins as another
// computer", #526 piece 3): its own whole ledger (`phone_own_ledger.dart`) is
// kept up by the same cycle a computer runs (`CloudFolder`): the phone's
// change file is written when its log has grown, and the other computers'
// change files are folded in and brought in. What differs from a computer:
// the phone never writes the folder's whole ledger (too much to send over
// mobile data; the computers keep it), and it asks nothing yet: a row changed
// two ways, or two ledgers that can't be combined, wait for the phone's
// asking window (piece 4), the figures staying as they were.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

import '../domain/phone.dart';
import 'backup.dart';
import 'cloud_folder.dart';
import 'database.dart' show AppDatabase, ChangedSinceException;
import 'folder_io.dart';
import 'phone_ledger.dart';
import 'phone_own_ledger.dart';

/// What the phone shows and keeps up, as [PhoneStart] asks it: swapped in
/// tests.
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
  Future<PhoneSnapshot?> take(PhoneInbox inbox, DateTime now) async => null;

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
          continue;
        }
        if (standing == FolderStanding.newer) {
          await _takeFolderLedger(cloud, now);
          continue;
        }
        break;
      }
      whole = standing == FolderStanding.ok;
    } catch (e) {
      // Offline, or the folder gone: the ledger the phone has stands.
      debugPrint('The phone’s look at the folder failed: $e');
    }
    if (whole && !_closed) await _keepLooked(now);
    return asItStands(now);
  }

  @override
  Future<PhoneSnapshot> asItStands(DateTime now) async {
    if (_closed) throw StateError('The phone’s ledger was closed');
    _db ??= await _own.open(device);
    final db = _db;
    if (db == null) throw StateError('The phone has no ledger of its own yet');
    return snapshotOf(
      await db.loadLedger(),
      today: now,
      madeAt: await _looked() ?? now,
    );
  }

  @override
  Future<PhoneSnapshot?> take(PhoneInbox inbox, DateTime now) async {
    if (_closed) throw StateError('The phone’s ledger was closed');
    _db ??= await _own.open(device);
    final db = _db;
    if (db == null) return null;
    // Each is a row of this phone's own, written to its log: the folder
    // cycle's next look puts it in the phone's change file.
    await db.takePhoneEntries([inbox], today: now);
    return asItStands(now);
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
