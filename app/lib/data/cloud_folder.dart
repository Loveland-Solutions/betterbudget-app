// The ledger stored in a folder the user picked (ADR 0005, "All of the data
// lives in the cloud folder"): a complete encrypted copy, written again after
// every change, in a folder Google Drive, OneDrive, Box or Dropbox keeps on the
// disk. This app only writes a file; the sync app does the network. The file
// the app works in stays where it is, so a half-written database is never
// uploaded.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'backup.dart';
import 'ledger_file.dart';

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
}

class CloudFolderState {
  const CloudFolderState({this.path, this.copiedAt, this.failing = false});

  /// The folder, or null when the ledger is stored on this computer only.
  final String? path;

  /// When the ledger there was last written.
  final DateTime? copiedAt;

  /// The last try at writing it threw: the folder is gone, full or offline.
  final bool failing;
}

/// The picked folder is the app's own: the ledger can't be moved onto itself.
class OwnFolderException implements Exception {}

class CloudFolder extends ValueNotifier<CloudFolderState> {
  CloudFolder(
    this.backups, {
    this.access = const FolderAccess(),
    this.wait = const Duration(seconds: 5),
  }) : super(const CloudFolderState());

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
  Future<void> _writing = Future.value();
  String? _token;

  /// Which folder, kept in a small file beside the ledger: it is this
  /// computer's own setting, so it doesn't travel inside the ledger.
  Future<File?> _settings() async {
    final dir = await backups.folder();
    return dir == null ? null : File('${dir.parent.path}/cloud-folder');
  }

  /// Reads the setting at launch and writes the ledger afresh. Never throws.
  Future<void> load(DateTime now) async {
    try {
      final file = await _settings();
      if (file == null || !file.existsSync()) return;
      final saved = jsonDecode(await file.readAsString()) as Map;
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
      await copyNow(now);
    } catch (e) {
      debugPrint('Cloud folder setting unreadable: $e');
    }
  }

  Future<void> _save() async {
    final file = await _settings();
    if (file == null) return;
    final path = value.path;
    if (path == null) {
      if (file.existsSync()) await file.delete();
      return;
    }
    await file.writeAsString(
      jsonEncode({
        'path': path,
        'token': ?_token,
        'copiedAt': ?value.copiedAt?.toIso8601String(),
      }),
    );
  }

  /// Moves the ledger to [path]: writes it there and, when it was in another
  /// folder, takes it out of that one. Throws when it can't be written,
  /// leaving everything as it was, and [OwnFolderException] for the folder
  /// the app works in.
  Future<void> keepIn(String path, DateTime now) async {
    final live = await backups.db.filePath();
    if (live != null && _same(File(live).parent.path, path)) {
      throw OwnFolderException();
    }
    final before = value;
    final tokenBefore = _token;
    _cancel();
    _token = await access.remember(path);
    value = CloudFolderState(path: path);
    try {
      await _write(now);
    } catch (_) {
      _token = tokenBefore;
      value = before;
      rethrow;
    }
    await _save();
    final left = before.path;
    if (left != null && !_same(left, path)) {
      try {
        final old = File('$left/$fileName');
        if (old.existsSync()) await old.delete();
      } catch (e) {
        debugPrint('The ledger in the folder it left stays there: $e');
      }
    }
  }

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
  /// folder. The file already there is left alone.
  Future<void> stop() async {
    _cancel();
    _token = null;
    value = const CloudFolderState();
    await _save();
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
    _due = null;
  }

  /// The ledger changed: write it once things have been quiet for [wait].
  void ledgerChanged(DateTime Function() clock) {
    if (value.path == null) return;
    _timer?.cancel();
    _due = clock;
    _timer = Timer(wait, () {
      _due = null;
      copyNow(clock());
    });
  }

  /// Writes a change still waiting out [wait], as the app quits.
  Future<void> flush() async {
    final clock = _due;
    if (clock == null) return;
    _cancel();
    await copyNow(clock());
  }

  /// Writes the ledger now. Never throws: a failure shows in [value].
  Future<void> copyNow(DateTime now) async {
    final path = value.path;
    if (path == null) return;
    try {
      await _write(now);
      await _save();
    } catch (e) {
      debugPrint('Writing the ledger to its folder failed: $e');
      if (value.path == path) {
        value = CloudFolderState(
          path: path,
          copiedAt: value.copiedAt,
          failing: true,
        );
      }
    }
  }

  /// One write at a time, each a whole file from SQLite's own consistent
  /// read of the ledger, written beside its name and renamed over it: a
  /// phone, or the sync app, never meets half a ledger.
  Future<void> _write(DateTime now) {
    final path = value.path!;
    final done = _writing.then((_) async {
      final arriving = File('$path/$fileName.tmp');
      try {
        await backups.saveTo(arriving.path, now);
        await arriving.rename('$path/$fileName');
      } finally {
        if (arriving.existsSync()) await arriving.delete();
      }
      final earlier = File('$path/$earlierFileName');
      if (earlier.existsSync()) await earlier.delete();
      if (value.path == path) {
        value = CloudFolderState(path: path, copiedAt: now);
      }
    });
    _writing = done.catchError((_) {});
    return done;
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }
}
