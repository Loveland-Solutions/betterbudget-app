// The ledger stored in a folder the user picked (ADR 0005, "All of the data
// lives in the cloud folder"): a complete encrypted copy, written again after
// every change, in a folder Google Drive, OneDrive, Box or Dropbox keeps on the
// disk. This app only writes a file; the sync app does the network. The file
// the app works in stays where it is, so a half-written database is never
// uploaded.
//
// More than one computer may have the same folder (ADR 0005, "Never write
// blind"). So the file there is never written without being looked at first:
// it is written over only when everything in it is already in this
// computer's ledger (`decideFolderMove`). A newer one is handed to the screen
// to take in, and when both were changed neither is touched until the person
// has chosen.
//
// Changed on both ("Combine"): this computer keeps the file both last agreed
// on, and what the other changed since is worked out against it and brought
// in. The person is asked only when the two can't both stand.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/combine.dart';
import '../domain/fold.dart';
import '../domain/sync.dart';
import 'backup.dart';
import 'change_file.dart';
import 'database.dart'
    show CantCombineException, ChangedSinceException, fileStamp, SyncState;
import 'ledger_file.dart';
import 'ledger_seal.dart';

/// Keeps permission to a picked folder across launches. A sandboxed Mac app
/// loses a folder the user picked when it quits unless it holds a bookmark
/// for it (`MainFlutterWindow.swift`); elsewhere the path is enough.
class FolderAccess {
  const FolderAccess();

  static const _channel = MethodChannel('betterbudget/folder');

  /// Something to keep for [path], or null where a path needs nothing more.
  Future<String?> remember(String path) async {
    if (!Platform.isMacOS) return null;
    return _channel.invokeMethod<String>('remember', {'path': path});
  }

  /// Opens what [remember] gave and says where the folder is now (it may
  /// have been moved or renamed), with a newer token to keep when the old
  /// one has gone stale. Null when the folder can't be reached any more.
  Future<({String path, String? token})?> open(String token) async {
    if (!Platform.isMacOS) return null;
    final found = await _channel.invokeMapMethod<String, Object?>('open', {
      'token': token,
    });
    final path = found?['path'] as String?;
    return path == null
        ? null
        : (path: path, token: found?['token'] as String?);
  }

  /// Whether a folder has to be picked by itself before it can be kept. A
  /// sandboxed Mac app is given only the file picked in an open dialog,
  /// never the folder around it.
  bool get folderMustBePicked => Platform.isMacOS;

  /// What this computer is called, for telling the other one whose changes
  /// it has opened: the name its owner gave it where the system has one.
  Future<String> computerName() async {
    if (Platform.isMacOS) {
      try {
        final name = await _channel.invokeMethod<String>('computerName');
        if (name != null && name.trim().isNotEmpty) return name.trim();
      } catch (e) {
        debugPrint('The computer’s name couldn’t be asked for: $e');
      }
    }
    final host = Platform.localHostname;
    return host.endsWith('.local')
        ? host.substring(0, host.length - '.local'.length)
        : host;
  }
}

/// How this computer's ledger stands to the one in its folder.
enum FolderStanding {
  /// The folder holds this computer's ledger.
  ok,

  /// The last try at reaching or writing the folder threw: it is gone, full
  /// or offline.
  failing,

  /// The folder's ledger can't be read: still arriving, or not this
  /// ledger's. Nothing is written over it.
  arriving,

  /// The folder's ledger was saved by a newer BetterBudget than this one.
  /// Nothing is written over it.
  newerApp,

  /// The folder's ledger has everything this computer's has and more, and
  /// nothing was changed here: the screen takes it in.
  newer,

  /// Both were changed apart, and what the folder's has that this
  /// computer's lacks can be brought in: the screen does it.
  combine,

  /// Both were changed apart, and some things in the two can't both stand:
  /// one row's amount, what a category is assigned for a month. The person
  /// chooses for each ([CloudFolder.asks]) and the rest comes in with the
  /// answer. Nothing is written until then.
  rows,

  /// Both were changed apart in a way that can't be combined. Nothing is
  /// written until the person chooses.
  apart,
}

@immutable
class CloudFolderState {
  const CloudFolderState({
    this.path,
    this.copiedAt,
    this.standing = FolderStanding.ok,
    this.stuck = false,
  });

  /// The folder, or null when the ledger is stored on this computer only.
  final String? path;

  /// When the ledger there was last written by this computer.
  final DateTime? copiedAt;

  final FolderStanding standing;

  /// [FolderStanding.arriving] for some minutes now: it isn't just on its
  /// way.
  final bool stuck;

  /// The last try at writing it threw: the folder is gone, full or offline.
  bool get failing => standing == FolderStanding.failing;

  /// This computer's changes aren't reaching the folder, and won't until
  /// something is done about it.
  bool get held =>
      standing == FolderStanding.failing ||
      standing == FolderStanding.apart ||
      standing == FolderStanding.rows ||
      standing == FolderStanding.newerApp ||
      (standing == FolderStanding.arriving && stuck);

  @override
  bool operator ==(Object other) =>
      other is CloudFolderState &&
      other.path == path &&
      other.copiedAt == copiedAt &&
      other.standing == standing &&
      other.stuck == stuck;

  @override
  int get hashCode => Object.hash(path, copiedAt, standing, stuck);
}

/// The picked folder is the app's own: the ledger can't be moved onto itself.
class OwnFolderException implements Exception {}

/// The picked folder holds a ledger this computer can't read: another
/// ledger's, or one still arriving. It was left as it is.
class FolderLedgerUnreadable implements Exception {}

/// The picked folder holds a ledger saved by a newer BetterBudget. It was
/// left as it is.
class FolderLedgerNewer implements Exception {}

/// The ledger found in the folder at the last look: a copy of it outside
/// the folder, and what it carries.
typedef FolderTheirs = ({File copy, LedgerLook look, DateTime modified});

/// What [CloudFolder.keepMine] replaced and what it wrote, so the one can
/// be put back while the folder still holds the other.
typedef KeptMine = ({File? theirs, String? theirsDigest, String wrote});

/// What [CloudFolder.bringIn] brought in. This computer's ledger as it was
/// before is kept as [before], which Restore from… opens.
typedef CombinedIn = ({
  File before,
  int transactions,
  int others,
  List<({int transaction, int account})> alike,
  LedgerLook from,
  DateTime modified,

  /// Nothing the person would call a change came in: what the two had
  /// made alike was settled (when each wrote a row, a category a phone
  /// made that both took in) and no more. Nothing to say, and no reason to
  /// clear the undo stack.
  bool quiet,
});

/// The folder no longer holds what [CloudFolder.keepMine] wrote: another
/// computer has written since, and nothing was put back over it.
class FolderMovedOn implements Exception {}

class CloudFolder extends ValueNotifier<CloudFolderState> {
  CloudFolder(
    this.backups, {
    this.access = const FolderAccess(),
    this.wait = const Duration(seconds: 5),
  }) : super(const CloudFolderState()) {
    // Any write to the ledger, the app's own scheduling included: what was
    // worked out about it no longer holds.
    _changes = backups.db.tableUpdates().listen((_) {
      _changed++;
      _mine = null;
    });
  }

  StreamSubscription<void>? _changes;
  var _changed = 0;

  final Backups backups;
  final FolderAccess access;

  /// How long after the last change the ledger is written: a run of edits
  /// makes one write, not one each.
  final Duration wait;

  /// One name, replaced each time: the sync service keeps the versions. The
  /// phones look for the same name.
  static const fileName = ledgerFileName;

  /// What the file was called for a few hours on 2026-10-07. Once the ledger
  /// is written under [fileName], one left under this name is removed.
  static const earlierFileName = 'BetterBudget ledger.sqlite';

  Timer? _timer;
  DateTime Function()? _due;

  /// Everything that looks at the folder or writes to it, one at a time.
  Future<void> _queue = Future.value();
  String? _token;

  /// This computer's own id, random, made the first time it is wanted. It
  /// is kept beside the ledger and never inside it: a ledger restored on
  /// another computer mustn't bring this one's id along.
  String? _computer;
  String? _name;

  /// A write to the folder was begun and not seen to finish: a file there
  /// that can't be read is this computer's own, cut short.
  bool _writingMark = false;

  /// This computer's ledger as last worked out, until it changes.
  ({String digest, String? seal, SyncComputers computers})? _mine;

  /// The folder's file as last read, until the file changes.
  ({DateTime modified, int size, FolderTheirs theirs})? _seen;

  /// Since when the folder's file couldn't be read.
  DateTime? _arrivingSince;

  /// A ledger in the folder this computer mustn't write over whatever the
  /// counts say, by its digest: the one put back by [undoKeepMine]. Kept
  /// in `cloud-folder`.
  String? _askAbout;

  /// What the folder's ledger has that this computer's lacks, worked out
  /// for the two as they were then.
  _Plan? _plan;

  /// What the other computers call themselves, by id, from their change
  /// files' headers. Kept in `cloud-folder`.
  final _names = <String, String>{};

  /// What this computer's own change file last carried: its last change and
  /// its vector, so the file is written again only when either moved.
  int _publishedSeq = -1;
  String? _publishedVector;

  /// What the person chose for the things both computers changed, for the
  /// folder's ledger of this digest: held to until the folder's ledger is
  /// another, so the choice isn't asked again over what it wrote.
  ({String theirs, Map<String, Pick> picks})? _decided;

  /// Two ledgers that couldn't be combined after all, by their digests:
  /// asked about, not tried again.
  String? _cantCombine;

  /// The folder's ledger whose changes were last brought in, by its digest.
  String? _broughtIn;

  /// The digest of the file kept by [_keepAgreed].
  String? _agreed;

  /// The ledger both computers last agreed on: the one this computer last
  /// wrote to the folder or took from it, whole. What each changed since is
  /// found by comparing with it.
  Future<File> _agreedFile() async =>
      File('${(await backups.folder())!.parent.path}/cloud-folder-agreed');

  /// Keeps [file], whose contents give [digest], as the ledger both agreed
  /// on. Whole or not at all.
  Future<void> _keepAgreed(File file, String digest) async {
    final kept = await _agreedFile();
    if (_agreed == digest && kept.existsSync()) return;
    try {
      final temp = await file.copy('${kept.path}.tmp');
      await temp.rename(kept.path);
      _agreed = digest;
      await _save();
    } catch (e) {
      debugPrint('The agreed ledger couldn’t be kept: $e');
    }
  }

  /// This computer's ledger as the last look found it, for the screen to
  /// hand back when it takes the folder's in: null once it has changed.
  String? get mineDigest => _mine?.digest;

  /// The ledger found in the folder at the last look, when one could be
  /// read: what the screen takes in or asks about.
  FolderTheirs? get theirs => _seen?.theirs;

  /// What both computers changed that needs the person's choice, found at
  /// the last look ([FolderStanding.rows]); empty otherwise.
  List<Ask> get asks {
    final plan = _plan;
    if (plan == null || !plan.found.asking) return const [];
    return plan.found.asks;
  }

  Future<T> _queued<T>(Future<T> Function() work) {
    final done = _queue.then((_) => work());
    _queue = done.then<void>((_) {}, onError: (_) {});
    return done;
  }

  /// Which folder, kept in a small file beside the ledger: it is this
  /// computer's own setting, so it doesn't travel inside the ledger.
  Future<File?> _settings() async {
    final dir = await backups.folder();
    return dir == null ? null : File('${dir.parent.path}/cloud-folder');
  }

  /// Where the folder's ledger is copied to be read, so nothing is opened
  /// inside a folder a sync app is watching.
  Future<Directory> _scratch() async =>
      Directory('${(await backups.folder())!.parent.path}/folder-look');

  /// Whether [load] has finished: until then nobody knows whether the
  /// ledger is in a folder, and nothing should be said as though it isn't.
  final loaded = ValueNotifier(false);

  /// Reads the setting at launch and looks at the folder: the ledger is
  /// written there afresh, or the one there is found to be newer. Never
  /// throws.
  Future<void> load(DateTime now) async {
    try {
      await _load(now);
    } finally {
      loaded.value = true;
    }
  }

  Future<void> _load(DateTime now) async {
    try {
      final file = await _settings();
      if (file == null || !file.existsSync()) return;
      final saved = jsonDecode(await file.readAsString()) as Map;
      _computer = saved['computer'] as String?;
      _writingMark = saved['writing'] == true;
      _askAbout = saved['askAbout'] as String?;
      if (saved['names'] case final Map names) {
        _names.addAll({
          for (final e in names.entries) '${e.key}': '${e.value}',
        });
      }
      if (saved['published'] case {
        'seq': final int seq,
        'vector': final String v,
      }) {
        _publishedSeq = seq;
        _publishedVector = v;
      }
      if (saved['decided'] case {
        'theirs': final String theirs,
        'picks': final Map picks,
      }) {
        _decided = (
          theirs: theirs,
          picks: {
            for (final e in picks.entries)
              '${e.key}': Pick.values.firstWhere(
                (p) => p.name == e.value,
                orElse: () => Pick.mine,
              ),
          },
        );
      }
      _agreed = saved['agreed'] as String?;
      _token = saved['token'] as String?;
      var path = saved['path'] as String?;
      if (_token != null) {
        // A folder that can't be opened still shows where it was, failing,
        // rather than the ledger quietly going back to this computer.
        try {
          final opened = await access.open(_token!);
          path = opened?.path ?? path;
          _token = opened?.token ?? _token;
        } catch (e) {
          debugPrint('The folder couldn’t be opened: $e');
        }
      }
      if (path == null) return;
      final at = saved['copiedAt'] as String?;
      value = CloudFolderState(
        path: path,
        copiedAt: at == null ? null : DateTime.tryParse(at),
      );
      await check(now);
    } catch (e) {
      debugPrint('Cloud folder setting unreadable: $e');
    }
  }

  Future<void> _save() async {
    final file = await _settings();
    if (file == null) return;
    final path = value.path;
    if (path == null && _computer == null && _agreed == null) {
      if (file.existsSync()) await file.delete();
      return;
    }
    // Whole or not at all: a write cut short mustn't lose the folder.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode({
        'computer': ?_computer,
        'agreed': ?_agreed,
        'path': ?path,
        if (path != null) 'token': ?_token,
        if (path != null) 'copiedAt': ?value.copiedAt?.toIso8601String(),
        if (path != null && _writingMark) 'writing': true,
        if (path != null) 'askAbout': ?_askAbout,
        if (_names.isNotEmpty) 'names': _names,
        if (path != null && _publishedVector != null)
          'published': {'seq': _publishedSeq, 'vector': _publishedVector},
        if (path != null && _decided != null)
          'decided': {
            'theirs': _decided!.theirs,
            'picks': {
              for (final e in _decided!.picks.entries) e.key: e.value.name,
            },
          },
      }),
      flush: true,
    );
    await temp.rename(file.path);
  }

  Future<String> _computerId() async {
    if (_computer case final id?) return id;
    final random = Random.secure();
    _computer = [
      for (var i = 0; i < 8; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    await _save();
    return _computer!;
  }

  /// Moves the ledger to [path]. A folder with no ledger in it gets this
  /// computer's. One that already holds a ledger is looked at as at any
  /// other time: afterwards [value] may say the one there is newer, or that
  /// both were changed, and nothing of it has been written over.
  ///
  /// Throws when the folder can't be written, [OwnFolderException] for the
  /// folder the app works in, [FolderLedgerNewer], and
  /// [FolderLedgerUnreadable] unless [replaceUnreadable], which keeps the
  /// file that was there in the app's backups first and gives it back.
  /// Whatever is thrown, everything is left as it was.
  ///
  /// The ledger in a folder it leaves stays there: a phone may be reading it.
  Future<File?> keepIn(
    String path,
    DateTime now, {
    bool replaceUnreadable = false,
  }) async {
    final live = await backups.db.filePath();
    if (live != null && _same(File(live).parent.path, path)) {
      throw OwnFolderException();
    }
    _cancel();
    // After any write under way to the folder it is leaving.
    return _queued(() async {
      final before = value;
      final tokenBefore = _token;
      final seenBefore = _seen;
      final askBefore = _askAbout;
      _token = await access.remember(path);
      value = CloudFolderState(path: path);
      _seen = null;
      _askAbout = null;
      try {
        final found = await _sync(now, replaceUnreadable: replaceUnreadable);
        if (found.standing == FolderStanding.arriving) {
          throw FolderLedgerUnreadable();
        }
        if (found.standing == FolderStanding.newerApp) {
          throw FolderLedgerNewer();
        }
        value = CloudFolderState(
          path: path,
          copiedAt: value.copiedAt,
          standing: found.standing,
        );
        await _save();
        return found.replaced;
      } catch (_) {
        _token = tokenBefore;
        value = before;
        _seen = seenBefore;
        _askAbout = askBefore;
        rethrow;
      }
    });
  }

  /// The folder [file] is in, when [file] is a ledger as one is stored in a
  /// folder ([fileName]) and the folder isn't the app's own: restored from
  /// there, this computer can be kept on that folder's ledger. Null for any
  /// other file.
  Future<String?> folderOfLedger(String file) async {
    final parts = file.split(RegExp(r'[/\\]'));
    if (parts.length < 2 || parts.last != fileName) return null;
    final live = await backups.db.filePath();
    if (live == null) return null;
    final folder = File(file).parent.path;
    return _same(File(live).parent.path, folder) ? null : folder;
  }

  /// A folder as it's named on screen: its last two parts, which for a Drive
  /// folder reads "My Drive/BetterBudget".
  static String nameOf(String path) {
    final parts = path.split(RegExp(r'[/\\]')).where((p) => p.isNotEmpty);
    return parts.skip(parts.length > 2 ? parts.length - 2 : 0).join('/');
  }

  /// The folder that holds the ledger when [picked] was pointed to: [picked]
  /// itself, or the one folder directly inside it that does (My Drive
  /// picked, for My Drive/BetterBudget). Null when none does, or more than
  /// one.
  static String? folderWithLedger(String picked) {
    try {
      if (File('$picked/$fileName').existsSync()) return picked;
      final inside = [
        for (final d in Directory(picked).listSync().whereType<Directory>())
          if (File('${d.path}/$fileName').existsSync()) d.path,
      ];
      return inside.length == 1 ? inside.single : null;
    } on FileSystemException {
      return null;
    }
  }

  /// Whether [a] and [b] are one folder, however each was reached.
  static bool sameFolder(String a, String b) => _same(a, b);

  static bool _same(String a, String b) {
    String real(String p) {
      try {
        return Directory(p).resolveSymbolicLinksSync();
      } on FileSystemException {
        return p;
      }
    }

    return real(a) == real(b);
  }

  /// Moves the ledger back to this computer: nothing more is written to the
  /// folder, once a write under way has finished. The file already there is
  /// left alone.
  Future<void> stop() {
    _cancel();
    return _queued(() async {
      _token = null;
      _seen = null;
      _askAbout = null;
      value = const CloudFolderState();
      await _save();
    });
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
    _due = null;
  }

  /// The ledger changed: look and write once things have been quiet for
  /// [wait].
  void ledgerChanged(DateTime Function() clock) {
    _mine = null;
    if (value.path == null) return;
    _timer?.cancel();
    _due = clock;
    _timer = Timer(wait, () {
      _due = null;
      check(clock());
    });
  }

  /// Writes a change still waiting out [wait], as the app quits.
  Future<void> flush() async {
    final clock = _due;
    if (clock == null) return;
    _cancel();
    await check(clock());
  }

  /// Looks at the folder and writes this computer's ledger there if it may.
  /// Never throws: what was found is in [value], and given back. [fresh]
  /// works everything out again, trusting nothing remembered from the last
  /// look: asked for before the folder's ledger is taken in.
  Future<FolderStanding> check(DateTime now, {bool fresh = false}) =>
      _queued(() async {
        final path = value.path;
        if (path == null) return FolderStanding.ok;
        FolderStanding standing;
        try {
          if (fresh) {
            _mine = null;
            _seen = null;
          }
          standing = (await _sync(now)).standing;
        } catch (e) {
          debugPrint('Writing the ledger to its folder failed: $e');
          standing = FolderStanding.failing;
        }
        if (standing == FolderStanding.arriving) {
          _arrivingSince ??= now;
        } else {
          _arrivingSince = null;
        }
        if (value.path == path) {
          value = CloudFolderState(
            path: path,
            copiedAt: value.copiedAt,
            standing: standing,
            stuck:
                _arrivingSince != null &&
                now.difference(_arrivingSince!).abs() >
                    const Duration(minutes: 3),
          );
        }
        return standing;
      });

  /// As [check]; the name the daily use had before there was a look.
  Future<void> copyNow(DateTime now) => check(now);

  /// Writes this computer's ledger over the folder's whatever that holds:
  /// the person chose this computer's. The file that was there is kept in
  /// the app's backups first. Throws when it can't be written.
  Future<KeptMine> keepMine(DateTime now) => _queued(() async {
    final path = value.path!;
    final file = File('$path/$fileName');
    // On change files, "keep this computer's" is a choice over everything
    // the others changed that isn't here: each of their rows is written
    // down as changed from their version to this computer's, so they take
    // the choice rather than asking the same question, and their changes
    // count as applied without coming in.
    var state = await backups.db.syncState();
    if (state.applied.isNotEmpty) {
      final db = backups.db;
      final me = await _computerId();
      final files = await readChangeFiles(
        Directory(path),
        backups.dataKey,
        scratch: await _scratch(),
        butComputer: me,
        afterSeq: state.applied,
      );
      for (final f in files) {
        if (f.changes.isEmpty) continue;
        final mine = await db.sealState();
        final rows = await db.allRows();
        final folded = foldChanges(
          rows,
          [for (final c in f.changes) _fold(c)],
          mineSince: [
            for (final c in await db.changesSince(f.header.applied[me] ?? 0))
              if (c.op != 'restore' && c.op != 'erase')
                _fold(ChangeRecord.fromRow(c)),
          ],
        );
        final resolutions = <Resolution>[];
        for (final c in f.changes) {
          final keys = combineKeys[c.tbl];
          if (keys == null || c.isMarker) continue;
          final key = {for (final k in keys) k: c.pk[k]};
          Row? find(LedgerRows of) => (of[c.tbl] ?? const <Row>[])
              .where((r) => keys.every((k) => r[k] == c.pk[k]))
              .firstOrNull;
          final theirRow = find(folded.theirs), mineRow = find(rows);
          if (resolutions.any(
            (r) => r.table == c.tbl && keys.every((k) => r.key[k] == key[k]),
          )) {
            continue;
          }
          resolutions.add(Resolution(c.tbl, key, theirRow, mineRow));
        }
        await db.applyCombined(
          const [],
          onlyIfDigest: mine.digest,
          resolutions: resolutions,
          applied: (computer: f.header.computer, seq: f.header.lastSeq),
        );
      }
      _plan = null;
      state = await db.syncState();
      await _publish(path, me, state, now);
    }
    File? kept;
    var over = const <String, int>{};
    FileStat? expected;
    if (file.existsSync()) {
      expected = file.statSync();
      final found = await _read(file);
      kept = await backups.keepFromFolder(found?.copy ?? file, now);
      over = found?.look.computers.counters ?? over;
    }
    final theirsDigest = (await _read(file))?.look.digest;
    _askAbout = null;
    final wrote = await _put(path, now, over: over, expected: expected);
    value = CloudFolderState(path: path, copiedAt: now);
    await _save();
    return (theirs: kept, theirsDigest: theirsDigest, wrote: wrote);
  });

  /// Takes [keepMine] back: the file it replaced is in the folder again,
  /// and the two are asked about again, whatever the counts say (this
  /// computer's own count never goes down). Throws [FolderMovedOn], with
  /// nothing done, unless the folder still holds exactly what [keepMine]
  /// wrote.
  Future<void> undoKeepMine(KeptMine kept, DateTime now) async {
    await _queued(() async {
      final path = value.path;
      final theirs = kept.theirs;
      if (path == null || theirs == null) throw FolderMovedOn();
      // On change files the choice went out as changes of this computer's
      // the moment it was made; the other computer may have taken it.
      if ((await backups.db.syncState()).applied.isNotEmpty) {
        throw FolderMovedOn();
      }
      final file = File('$path/$fileName');
      _seen = null;
      final there = file.existsSync() ? await _read(file) : null;
      if (there == null || there.look.digest != kept.wrote) {
        throw FolderMovedOn();
      }
      _askAbout = kept.theirsDigest;
      await _save();
      await _replace(file, await theirs.readAsBytes());
      _seen = null;
    });
    await check(now);
  }

  /// One look. The folder's file is read from a copy; what to do about it
  /// is [decideFolderMove]'s. Throws when the folder can't be reached or
  /// written.
  Future<({FolderStanding standing, File? replaced})> _sync(
    DateTime now, {
    bool replaceUnreadable = false,
  }) async {
    final path = value.path!;
    final file = File('$path/$fileName');
    // Twice at most: the second time when the file changed between being
    // read and being written over.
    for (var tries = 0; ; tries++) {
      if (!file.existsSync()) {
        await _put(path, now, over: const {});
        return (standing: FolderStanding.ok, replaced: null);
      }
      final stat = file.statSync();
      final found = await _read(file);
      try {
        if (found == null) {
          // Unreadable. This computer's own write cut short is written
          // again; anything else is waited for.
          if (!_writingMark && !replaceUnreadable) {
            return (standing: FolderStanding.arriving, replaced: null);
          }
          final kept = replaceUnreadable
              ? await backups.keepFromFolder(file, now)
              : null;
          await _put(path, now, over: const {}, expected: stat);
          return (standing: FolderStanding.ok, replaced: kept);
        }
        // A whole file is there: no write of this computer's was cut short.
        if (_writingMark) {
          _writingMark = false;
          await _save();
        }
        final theirs = found.look;
        if (theirs.schemaVersion > backups.db.schemaVersion) {
          return (standing: FolderStanding.newerApp, replaced: null);
        }
        final at = _changed;
        final mine = _mine ?? await backups.db.sealState();
        // Remembered only if nothing was written while it was worked out.
        if (at == _changed) _mine = mine;
        // Both the folder's ledger and this one say where they stand on
        // change files: the computers talk through those (step 3). Until
        // both do, the older way, whose write stamps the file so the next
        // look is on change files.
        final state = await backups.db.syncState();
        if (theirs.applied.isNotEmpty && state.applied.isNotEmpty) {
          return await _syncLogs(now, path, found, mine, state, stat);
        }
        if (_askAbout != null && theirs.digest != _askAbout) {
          _askAbout = null;
          await _save();
        }
        if (theirs.digest == _askAbout && mine.digest != theirs.digest) {
          return (standing: FolderStanding.apart, replaced: null);
        }
        // The folder holds exactly what this computer last wrote or took:
        // the ledger both agree on, kept for comparing later.
        if (theirs.digest == mine.seal) {
          await _keepAgreed(found.copy, theirs.digest);
        }
        final copied = value.copiedAt;
        final move = decideFolderMove(
          identical: mine.digest == theirs.digest,
          // A choice made for this folder's ledger is a change made here,
          // even where it put every row back as it was.
          changedHere:
              mine.seal != mine.digest || _decided?.theirs == theirs.digest,
          theirsSealed: theirs.sealed,
          mine: mine.computers.counters,
          theirs: theirs.computers.counters,
          // The first run of a build that keeps counts: the folder's file
          // is the one this computer wrote, by the time on it.
          theirsIsMyOldWrite:
              theirs.seal == null &&
              theirs.computers.counters.isEmpty &&
              mine.computers.counters.isEmpty &&
              copied != null &&
              found.modified.difference(copied).abs() <
                  const Duration(minutes: 2),
        );
        switch (move) {
          case FolderMove.nothing:
            await backups.db.adoptSeal(
              theirs.computers,
              theirs.digest,
              applied: theirs.applied,
              ledger: theirs.ledger,
            );
            return (standing: FolderStanding.ok, replaced: null);
          case FolderMove.take:
            return (standing: FolderStanding.newer, replaced: null);
          case FolderMove.ask:
            final plan = await _combinable(mine, found);
            if (plan == null) {
              return (standing: FolderStanding.apart, replaced: null);
            }
            if (plan.asking) {
              return (standing: FolderStanding.rows, replaced: null);
            }
            if (plan.ops.isNotEmpty) {
              // Brought in once already and still not all here: never
              // again by itself.
              return (
                standing: theirs.digest == _broughtIn
                    ? FolderStanding.apart
                    : FolderStanding.combine,
                replaced: null,
              );
            }
            // Everything the folder's has is here already, and more.
            await _put(
              path,
              now,
              over: theirs.computers.counters,
              expected: stat,
            );
            await _forgetDecided();
            return (standing: FolderStanding.ok, replaced: null);
          case FolderMove.write:
            await _put(
              path,
              now,
              over: theirs.computers.counters,
              expected: stat,
            );
            await _forgetDecided();
            return (standing: FolderStanding.ok, replaced: null);
        }
      } on _FolderFileMoved {
        if (tries > 0) rethrow;
        _seen = null;
      }
    }
  }

  /// What the folder's ledger has that this computer's lacks, when the two
  /// were changed apart and can be combined: null when they can't, and the
  /// person is asked. They can't without the ledger both last agreed on
  /// (after a restore, or before this computer ever wrote one), when the
  /// folder's was written by a build that keeps no seal, or was saved by
  /// another version of the tables.
  Future<Combined?> _combinable(
    ({String digest, String? seal, SyncComputers computers}) mine,
    FolderTheirs found, {
    bool again = false,
  }) async {
    final theirs = found.look;
    final pair = '${mine.digest}|${theirs.digest}';
    if (pair == _cantCombine && !again) return null;
    final cached = _plan;
    if (!again &&
        cached != null &&
        cached.mine == mine.digest &&
        cached.theirs == theirs.digest) {
      return cached.found.conflict == null ? cached.found : null;
    }
    _plan = null;
    final db = backups.db;
    if (mine.seal == null ||
        !theirs.sealed ||
        theirs.schemaVersion != db.schemaVersion) {
      return null;
    }
    try {
      final agreed = await _agreedFile();
      if (!agreed.existsSync()) return null;
      final was = await lookAtLedger(agreed, backups.dataKey);
      if (was.digest != mine.seal || was.schemaVersion != db.schemaVersion) {
        return null;
      }
      final at = _changed;
      final rows = await db.allRows();
      // Changed while it was read: the next look works it out.
      if (at != _changed) return null;
      final combined = combine(
        base: await readLedgerRows(agreed, backups.dataKey),
        mine: rows,
        theirs: await readLedgerRows(found.copy, backups.dataKey),
        picks: _decided?.theirs == theirs.digest ? _decided!.picks : const {},
      );
      if (combined.conflict case final why?) {
        debugPrint('The two ledgers can’t be combined: $why');
      }
      _plan = _Plan(mine: mine.digest, theirs: theirs.digest, found: combined);
      return combined.conflict == null ? combined : null;
    } catch (e) {
      debugPrint('The two ledgers couldn’t be compared: $e');
      return null;
    }
  }

  /// Brings into this computer's ledger what the last look found the
  /// folder's to have ([FolderStanding.combine]), and writes the two
  /// together to the folder. This computer's ledger as it was is kept
  /// first. Null, with nothing changed, when the two are no longer the ones
  /// that were compared (something was changed here meanwhile: the next
  /// look works it out again) or can't be combined after all (then the
  /// person is asked).
  ///
  /// With [picks], the person's choice for each of [asks]: the two are
  /// compared again with them, and what was chosen is made here with the
  /// rest. Nothing is chosen for, or brought in, until each has a pick.
  Future<CombinedIn?> bringIn(DateTime now, {Map<String, Pick>? picks}) =>
      _queued(() async {
        final path = value.path;
        var plan = _plan;
        final seen = _seen;
        if (path == null ||
            plan == null ||
            seen == null ||
            (plan.file == null && plan.theirs != seen.theirs.look.digest)) {
          return null;
        }
        if (picks != null) {
          final mine = _mine;
          if (mine == null ||
              mine.digest != plan.mine ||
              plan.found.asks.any((a) => !picks.containsKey(a.id))) {
            return null;
          }
          _decided = (theirs: plan.theirs, picks: {...picks});
          final found = plan.file != null
              ? (await _planFor(plan.file!, mine.digest))?.found
              : await _combinable(mine, seen.theirs, again: true);
          if (found == null || found.asking || found.conflict != null) {
            _decided = null;
            return null;
          }
          plan = _Plan(
            mine: plan.mine,
            theirs: plan.theirs,
            found: found,
            file: plan.file,
          );
          _plan = plan;
        }
        if (plan.found.conflict != null ||
            plan.found.asking ||
            (plan.found.ops.isEmpty && picks == null)) {
          return null;
        }
        final dir = (await backups.folder())!;
        await dir.create(recursive: true);
        final before = await backups.keepBefore(now);
        try {
          if (plan.found.ops.isNotEmpty ||
              plan.found.resolutions.isNotEmpty ||
              plan.file != null) {
            await backups.db.applyCombined(
              plan.found.ops,
              onlyIfDigest: plan.mine,
              resolutions: plan.found.resolutions,
              applied: plan.file == null
                  ? null
                  : (computer: plan.computer!, seq: plan.upTo!),
            );
          }
        } on ChangedSinceException {
          if (before.existsSync()) await before.delete();
          return null;
        } on CantCombineException {
          if (before.existsSync()) await before.delete();
          _cantCombine = '${plan.mine}|${plan.theirs}';
          _plan = null;
          value = CloudFolderState(
            path: path,
            copiedAt: value.copiedAt,
            standing: FolderStanding.apart,
          );
          return null;
        }
        _mine = null;
        _plan = null;
        if (plan.file == null) _broughtIn = plan.theirs;
        final header = plan.file?.header;
        return (
          before: before,
          transactions: plan.found.transactions,
          others: plan.found.others,
          alike: plan.found.alike,
          from: header == null
              ? seen.theirs.look
              : LedgerLook(
                  schemaVersion: header.schema,
                  digest: '',
                  seal: null,
                  computers: SyncComputers(const {}, {
                    header.computer: ?header.name,
                  }),
                  savedBy: header.computer,
                  savedAt: header.writtenAt,
                ),
          modified: header?.writtenAt ?? seen.theirs.modified,
          quiet:
              picks == null &&
              plan.found.transactions == 0 &&
              plan.found.others == 0 &&
              plan.found.alike.isEmpty,
        );
      });

  /// The choices made were used, or not applied: they are not held to again.
  Future<void> _forgetDecided() async {
    if (_decided == null) return;
    _decided = null;
    await _save();
  }

  // ---------- change files (step 3) ----------

  /// One look, on change files: this computer's own file is written when
  /// its log has grown; every other computer's file is read, and the first
  /// with changes not yet here is folded into what [combine] compares and
  /// left for the screen to bring in ([FolderStanding.combine]) or ask about
  /// ([FolderStanding.rows]); with nothing pending, the folder's ledger is
  /// written afresh when this one holds everything it holds and more. Nothing
  /// is ever written over another computer's file.
  Future<({FolderStanding standing, File? replaced})> _syncLogs(
    DateTime now,
    String path,
    FolderTheirs found,
    ({String digest, String? seal, SyncComputers computers}) mineAtFirst,
    SyncState state,
    FileStat stat,
  ) async {
    var mine = mineAtFirst;
    final db = backups.db;
    final me = await _computerId();
    final theirs = found.look;
    // The folder's ledger isn't what its seal says: written blind by a
    // build before change files, or changed by hand. Nothing is written
    // over it, and the person is asked, as before.
    if (!theirs.sealed) {
      return (standing: FolderStanding.apart, replaced: null);
    }
    // Which ledger. One that has never said takes the folder's; two that
    // say differently are two ledgers, and nothing of either is folded into
    // the other (step 5 tells an erase apart and asks in its own words).
    var ledger = state.ledger;
    if (ledger == null && theirs.ledger != null) {
      ledger = theirs.ledger;
      await db.setPreference(SyncKeys.ledger, ledger);
    } else if (ledger != null &&
        theirs.ledger != null &&
        theirs.ledger != ledger) {
      return (standing: FolderStanding.apart, replaced: null);
    }
    await _publish(path, me, state, now);
    final unreadable = <String>[];
    final files = await readChangeFiles(
      Directory(path),
      backups.dataKey,
      scratch: await _scratch(),
      butComputer: me,
      afterSeq: state.applied,
      unreadable: unreadable,
    );
    var held = false;
    var names = false;
    // What is applied, kept up as the look goes.
    final applied = {...state.applied};
    for (final f in files) {
      final h = f.header;
      if (h.name != null && _names[h.computer] != h.name) {
        _names[h.computer] = h.name!;
        names = true;
      }
      if (h.schema > db.schemaVersion) {
        return (standing: FolderStanding.newerApp, replaced: null);
      }
      if (h.ledger != null && ledger != null && h.ledger != ledger) {
        return (standing: FolderStanding.apart, replaced: null);
      }
      if (f.changes.isEmpty) continue;
      // Its changes may rest on another computer's that aren't here yet:
      // waited for, so a change never names a row that hasn't come.
      if (h.applied.entries.any(
        (e) =>
            e.key != me &&
            e.key != h.computer &&
            e.value > (applied[e.key] ?? 0),
      )) {
        held = true;
        continue;
      }
      // What came before the file's first change was dropped by its writer
      // (a ledger taken whole from the folder): nothing to wait for unless
      // some of that computer's was applied here already.
      if ((applied[h.computer] ?? 0) > 0 &&
          (applied[h.computer] ?? 0) + 1 < h.firstSeq) {
        held = true;
        continue;
      }
      // A whole ledger put in or cleared there: step 5 makes it a batch of
      // its own; until then the whole-ledger question.
      if (f.changes.any((c) => c.isMarker)) {
        return (standing: FolderStanding.apart, replaced: null);
      }
      final plan = await _planFor(f, mine.digest);
      if (plan == null) return (standing: FolderStanding.ok, replaced: null);
      if (plan.found.conflict != null) {
        return (standing: FolderStanding.apart, replaced: null);
      }
      if (plan.found.asking) {
        _plan = plan;
        return (standing: FolderStanding.rows, replaced: null);
      }
      final found = plan.found;
      if (found.transactions == 0 &&
          found.others == 0 &&
          found.alike.isEmpty &&
          found.resolutions.isEmpty) {
        // Nothing the person would call a change: everything it changed is
        // here already, or the two made the same rows and only when each
        // wrote them differs. Settled here, with nothing to say.
        try {
          await db.applyCombined(
            found.ops,
            onlyIfDigest: mine.digest,
            applied: (computer: h.computer, seq: plan.upTo!),
          );
        } on ChangedSinceException {
          return (standing: FolderStanding.ok, replaced: null);
        } on CantCombineException {
          _cantCombine = '${mine.digest}|${plan.theirs}';
          return (standing: FolderStanding.apart, replaced: null);
        }
        applied[h.computer] = plan.upTo!;
        mine = await db.sealState();
        _mine = mine;
        continue;
      }
      _plan = plan;
      return (standing: FolderStanding.combine, replaced: null);
    }
    if (names) await _save();
    // The folder's ledger is behind this one: written afresh. Ahead on a
    // computer whose file didn't come: waited for, unless it holds every
    // change of this computer's, when it is taken in whole.
    final vector = {...applied, me: state.lastSeq};
    final behind = theirs.applied.entries.where(
      (e) => e.value > (vector[e.key] ?? 0),
    );
    if (behind.isEmpty) {
      if (!_sameVector(theirs.applied, vector) ||
          theirs.digest != mine.digest) {
        await _put(path, now, over: theirs.computers.counters, expected: stat);
      }
      return (
        standing: held || unreadable.isNotEmpty
            ? FolderStanding.arriving
            : FolderStanding.ok,
        replaced: null,
      );
    }
    if (held || unreadable.isNotEmpty) {
      return (standing: FolderStanding.arriving, replaced: null);
    }
    if ((theirs.applied[me] ?? 0) >= state.lastSeq) {
      return (standing: FolderStanding.newer, replaced: null);
    }
    return (standing: FolderStanding.arriving, replaced: null);
  }

  static bool _sameVector(Map<String, int> a, Map<String, int> b) {
    Map<String, int> live(Map<String, int> v) => {
      for (final e in v.entries)
        if (e.value > 0) e.key: e.value,
    };
    return encodeApplied(live(a)) == encodeApplied(live(b));
  }

  /// Writes this computer's change file when its log has grown or its
  /// vector moved since the file was last written.
  Future<void> _publish(
    String path,
    String me,
    SyncState state,
    DateTime now,
  ) async {
    final vector = encodeApplied({...state.applied, me: state.lastSeq});
    final file = File('$path/${changeFileName(me)}');
    if (_publishedSeq == state.lastSeq &&
        _publishedVector == vector &&
        file.existsSync()) {
      return;
    }
    _name ??= await access.computerName();
    final db = backups.db;
    await writeChangeFile(
      file,
      backups.dataKey,
      ChangeFileHeader(
        computer: me,
        name: _name,
        ledger: state.ledger,
        schema: db.schemaVersion,
        applied: {...state.applied, me: state.lastSeq},
        lastSeq: state.lastSeq,
        writtenAt: now,
      ),
      await db.changesSince(0),
      scratch: await _scratch(),
    );
    _publishedSeq = state.lastSeq;
    _publishedVector = vector;
    await _save();
  }

  /// Another computer's changes, folded into what [combine] compares with
  /// this ledger's rows, and compared, with the picks remembered for them.
  /// Null when this ledger changed while it was read (the next look works
  /// it out again).
  Future<_Plan?> _planFor(ChangeFile f, String mineDigest) async {
    final key = '${f.header.computer}|${f.changes.last.seq}';
    if ('$mineDigest|$key' == _cantCombine) {
      return _Plan(
        mine: mineDigest,
        theirs: key,
        found: const Combined.conflict('refused by the ledger'),
        file: f,
      );
    }
    final at = _changed;
    final rows = await backups.db.allRows();
    // This computer's own changes since the other last saw its ledger,
    // which the other can't have.
    final me = await _computerId();
    final since = [
      for (final c in await backups.db.changesSince(f.header.applied[me] ?? 0))
        ChangeRecord.fromRow(c),
    ];
    if (at != _changed) return null;
    final folded = foldChanges(
      rows,
      [for (final c in f.changes) _fold(c)],
      mineSince: [
        for (final c in since)
          if (!c.isMarker) _fold(c),
      ],
    );
    final madeHere = <Object?>{
      for (final c in since)
        if (c.tbl == 'transactions' && c.op == 'insert') c.pk['id'],
    };
    final found = combine(
      base: folded.base,
      mine: rows,
      theirs: folded.theirs,
      picks: _decided?.theirs == key ? _decided!.picks : const {},
      madeHere: madeHere,
    );
    if (found.conflict case final why?) {
      debugPrint('${f.header.computer}’s changes can’t be brought in: $why');
    }
    return _Plan(mine: mineDigest, theirs: key, found: found, file: f);
  }

  static FoldChange _fold(ChangeRecord c) =>
      (tbl: c.tbl, pk: c.pk, op: c.op, before: c.before, after: c.after);

  /// The folder's file, copied out and read; null when it can't be read.
  /// Read again only when the file has changed.
  Future<FolderTheirs?> _read(File file) async {
    final stat = file.statSync();
    if (_seen case final seen?
        when seen.modified == stat.modified && seen.size == stat.size) {
      return seen.theirs;
    }
    _seen = null;
    final scratch = await _scratch();
    FolderTheirs? theirs;
    try {
      if (scratch.existsSync()) await scratch.delete(recursive: true);
      await scratch.create(recursive: true);
      final copy = await file.copy('${scratch.path}/$fileName');
      theirs = (
        copy: copy,
        look: await lookAtLedger(copy, backups.dataKey),
        modified: stat.modified,
      );
    } catch (e) {
      debugPrint('The ledger in the folder couldn’t be read: $e');
    }
    // One that couldn't be read is never remembered: it is tried again at
    // the next look, since the folder may only have been away. Nor is one
    // that changed while it was being copied.
    final after = file.statSync();
    if (theirs != null &&
        after.modified == stat.modified &&
        after.size == stat.size) {
      _seen = (modified: stat.modified, size: stat.size, theirs: theirs);
    }
    return theirs;
  }

  /// Writes this computer's ledger to the folder, sealed and ahead of the
  /// counts [over]. The file is made whole outside the folder, checked, and
  /// then written over the one there in place, so the sync service sees the
  /// same file with a new version and never a second one. [expected] is the
  /// file as it was when it was read: changed since, nothing is written.
  /// Gives back the digest of what was written.
  Future<String> _put(
    String path,
    DateTime now, {
    required Counters over,
    FileStat? expected,
  }) async {
    final db = backups.db;
    final dir = await backups.folder();
    if (dir == null) throw StateError('No database file to copy');
    await dir.create(recursive: true);
    final computer = await _computerId();
    _name ??= await access.computerName();
    final made = File(
      '${dir.path}/for-folder-${fileStamp(now)}.$ledgerExtension.tmp',
    );
    try {
      String? wrote;
      var sealed = false;
      // A change made between the seal and the copy leaves a file that
      // isn't what its seal says; sealed again, it is.
      for (var tries = 0; tries < 3 && !sealed; tries++) {
        if (made.existsSync()) await made.delete();
        await db.sealAs(computer, name: _name, at: now, over: over);
        _mine = null;
        await db.copyTo(made.path);
        final look = await lookAtLedger(made, backups.dataKey);
        sealed = look.sealed;
        wrote = look.digest;
      }
      if (!sealed) throw StateError('The ledger changed while it was copied');
      final file = File('$path/$fileName');
      if (expected != null) {
        final stat = file.statSync();
        if (stat.type == FileSystemEntityType.notFound ||
            stat.modified != expected.modified ||
            stat.size != expected.size) {
          throw _FolderFileMoved();
        }
      }
      final bytes = await made.readAsBytes();
      final untouched = file.statSync();
      _writingMark = true;
      await _save();
      try {
        await _replace(file, bytes);
      } catch (_) {
        // Not a byte went in: there is no write of this computer's cut
        // short there.
        final now = file.statSync();
        if (now.type == untouched.type &&
            now.modified == untouched.modified &&
            now.size == untouched.size) {
          _writingMark = false;
          await _save();
        }
        rethrow;
      }
      _writingMark = false;
      _seen = null;
      await _keepAgreed(made, wrote!);
      final earlier = File('$path/$earlierFileName');
      if (earlier.existsSync()) await earlier.delete();
      if (value.path == path) {
        value = CloudFolderState(path: path, copiedAt: now);
      }
      await _save();
      return wrote;
    } finally {
      if (made.existsSync()) await made.delete();
    }
  }

  /// [bytes] written over [file] where it is, not beside it and renamed.
  static Future<void> _replace(File file, List<int> bytes) async {
    final out = await file.open(mode: FileMode.write);
    try {
      await out.writeFrom(bytes);
      await out.flush();
    } finally {
      await out.close();
    }
  }

  @override
  void dispose() {
    _cancel();
    _changes?.cancel();
    loaded.dispose();
    super.dispose();
  }
}

/// The folder's file changed between being read and being written over.
class _FolderFileMoved implements Exception {}

/// What the last look worked out for the screen to bring in: what the two
/// ledgers were when it was worked out, and what to change. [file] is the
/// other computer's change file it brings in; null when it is the folder's
/// whole ledger (the older way).
class _Plan {
  _Plan({
    required this.mine,
    required this.theirs,
    required this.found,
    this.file,
  });
  final String mine;

  /// The folder's ledger's digest, or the change file's computer and last
  /// change: what a remembered choice is held to.
  final String theirs;
  final Combined found;
  final ChangeFile? file;

  String? get computer => file?.header.computer;
  int? get upTo => file?.changes.last.seq;
}
