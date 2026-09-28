import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';

import 'database.dart';

/// How the daily copies are going, for the sidebar.
@immutable
class BackupHealth {
  const BackupHealth({this.newest, this.failed = false});

  /// When the newest automatic copy was made.
  final DateTime? newest;

  /// The last attempt at a daily copy threw.
  final bool failed;

  /// Worth telling the user: copies are failing and the newest is more than
  /// two days old (or there is none). One failed hour isn't news.
  bool alarmingAt(DateTime now) =>
      failed &&
      (newest == null || now.difference(newest!) > const Duration(days: 2));
}

/// A backup file picked for restore, already copied into the app's folder
/// and upgraded to this version, with what it holds.
class RestoreCandidate {
  const RestoreCandidate({
    required this.file,
    required this.madeAt,
    required this.transactions,
    required this.accounts,
  });

  /// The working copy in `Backups/`. The picked file itself is never changed.
  final File file;
  final DateTime madeAt;
  final int transactions;
  final int accounts;
}

/// What a restore replaced and with what, so it can be undone and redone.
typedef RestoreRecord = ({File before, File restored});

/// A file that can't be restored, with a reason fit to show.
class RestoreException implements Exception {
  RestoreException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Backups stay on this machine: a daily copy in the app's own folder, and a
/// copy saved wherever the user picks. Nothing is uploaded anywhere.
class Backups {
  Backups(this.db, {this.keep = 14, this.months = 12});

  final AppDatabase db;

  /// Daily copies kept: the newest [keep], one per day the app was opened.
  final int keep;

  /// Also kept: the first copy of each of the last [months] months, for a
  /// mistake found long after it was made.
  final int months;

  final health = ValueNotifier(const BackupHealth());

  static const _prefix = 'betterbudget-';
  static final _name = RegExp(r'^betterbudget-(\d{8})-(\d{6})\.sqlite$');
  static final _stamp = RegExp(r'(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})');

  /// Kept from each restore: what was replaced, and what replaced it.
  static const _restoreKeep = 5;

  /// `Backups/` beside the database file, or null for an in-memory database.
  Future<Directory?> folder() async {
    final path = await db.filePath();
    if (path == null) return null;
    return Directory('${File(path).parent.path}/Backups');
  }

  /// The automatic copies, newest first.
  Future<List<File>> automatic() async => _files(_name);

  Future<List<File>> _files(RegExp pattern) async {
    final dir = await folder();
    if (dir == null || !dir.existsSync()) return const [];
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => pattern.hasMatch(_basename(f.path)))
        .toList()
      ..sort((a, b) => _basename(b.path).compareTo(_basename(a.path)));
  }

  /// Which automatic copies to delete, given their names newest first: all
  /// but the newest [keep], and the first copy of each of the newest
  /// [months] months.
  static List<String> expired(
    List<String> newestFirst, {
    required int keep,
    required int months,
  }) {
    final firstOfMonth = <String, String>{};
    for (final name in newestFirst.reversed) {
      final month = _name.firstMatch(name)!.group(1)!.substring(0, 6);
      firstOfMonth.putIfAbsent(month, () => name);
    }
    final monthly = (firstOfMonth.keys.toList()..sort()).reversed
        .take(months)
        .map((m) => firstOfMonth[m]!);
    final kept = {...newestFirst.take(keep), ...monthly};
    return [
      for (final n in newestFirst)
        if (!kept.contains(n)) n,
    ];
  }

  /// The daily copy, run at launch and hourly. Never throws: a failure is
  /// recorded in [health] for the sidebar to show.
  Future<void> runDaily(DateTime now) async {
    var failed = false;
    try {
      await automaticIfDue(now);
    } catch (e) {
      debugPrint('Automatic backup failed: $e');
      failed = true;
    }
    File? newest;
    try {
      newest = (await automatic()).firstOrNull;
    } catch (e) {
      debugPrint('Listing backups failed: $e');
      failed = true;
    }
    health.value = BackupHealth(
      newest: newest == null ? null : _madeAt(newest),
      failed: failed,
    );
  }

  /// Makes today's copy unless there already is one, then prunes (see
  /// [expired]). Returns the new copy, or null when none was needed.
  Future<File?> automaticIfDue(DateTime now) async {
    final dir = await folder();
    if (dir == null) return null;
    final day = fileStamp(now).substring(0, 8);
    final existing = await automatic();
    if (existing.any(
      (f) => _name.firstMatch(_basename(f.path))!.group(1) == day,
    )) {
      return null;
    }
    await dir.create(recursive: true);
    // Leftovers from a copy or a restore cut short (the app quit mid-way).
    // A backup picked in the last hour may still be waiting in the dialog.
    for (final f in dir.listSync().whereType<File>()) {
      final name = _basename(f.path);
      final stale =
          name.endsWith('.tmp') ||
          (name.startsWith('incoming-') &&
              now.difference(f.lastModifiedSync()) > const Duration(hours: 1));
      if (stale) await f.delete();
    }
    // Written under a temporary name and renamed once complete, so a copy
    // cut short never passes for today's backup.
    final file = File('${dir.path}/$_prefix${fileStamp(now)}.sqlite');
    final temp = File('${file.path}.tmp');
    try {
      await db.copyTo(temp.path);
      await temp.rename(file.path);
    } finally {
      if (temp.existsSync()) await temp.delete();
    }
    final all = await automatic();
    final gone = expired(
      [for (final f in all) _basename(f.path)],
      keep: keep,
      months: months,
    ).toSet();
    for (final f in all.where((f) => gone.contains(_basename(f.path)))) {
      await f.delete();
    }
    for (final kind in ['before-restore-', 'restored-', 'before-new-ledger-']) {
      final pattern = RegExp('^$kind\\d{8}-\\d{6}\\.sqlite\$');
      for (final old in (await _files(pattern)).skip(_restoreKeep)) {
        await old.delete();
      }
    }
    return file;
  }

  /// A copy saved to [destination], replacing a file already there. SQLite
  /// writes it in the app's folder first, then it's copied over, so only
  /// the one file the user picked is touched outside the app. The sandbox
  /// grants only that file, not its folder, so it can't be written under
  /// another name and renamed: a copy cut short (a USB stick pulled out)
  /// leaves that file broken.
  Future<void> saveTo(String destination, DateTime now) async {
    final dir = await folder();
    if (dir == null) throw StateError('No database file to back up');
    await dir.create(recursive: true);
    final temp = File('${dir.path}/export-${fileStamp(now)}.sqlite.tmp');
    if (temp.existsSync()) await temp.delete();
    try {
      await db.copyTo(temp.path);
      await temp.copy(destination);
    } finally {
      if (temp.existsSync()) await temp.delete();
    }
  }

  /// Reads a backup the user picked, without touching it or the ledger: it's
  /// copied into `Backups/`, checked, and upgraded if it came from an older
  /// version. Throws [RestoreException] when it can't be restored. Pass the
  /// result to [restore], or to [discard] if the user cancels.
  Future<RestoreCandidate> inspect(String path, DateTime now) async {
    final dir = await folder();
    if (dir == null) throw RestoreException('Nothing to restore into');
    await dir.create(recursive: true);
    final file = File('${dir.path}/incoming-${fileStamp(now)}.sqlite');
    try {
      await File(path).copy(file.path);
      final header = await _header(file);
      if (header == null ||
          String.fromCharCodes(header.sublist(0, 15)) != 'SQLite format 3') {
        throw RestoreException('That file isn’t a BetterBudget backup');
      }
      final version = ByteData.sublistView(header).getUint32(60);
      if (version > db.schemaVersion) {
        throw RestoreException(
          'That backup is from a newer BetterBudget · update the app first',
        );
      }
      // Off the UI isolate: a big or odd file mustn't freeze the app.
      final copy = AppDatabase(NativeDatabase.createInBackground(file));
      try {
        final check = await copy
            .customSelect('PRAGMA quick_check')
            .map((r) => r.data.values.first)
            .get();
        final brokenLinks = await copy
            .customSelect('PRAGMA foreign_key_check')
            .get();
        final unbalanced = await copy
            .customSelect(AppDatabase.unbalancedSql)
            .get();
        if (check.join() != 'ok' ||
            brokenLinks.isNotEmpty ||
            unbalanced.isNotEmpty) {
          throw RestoreException('That backup is damaged');
        }
        final ledger = await copy.loadLedger();
        if (ledger.balanceSheetAccounts.isEmpty) {
          throw RestoreException('That backup has no accounts in it');
        }
        return RestoreCandidate(
          file: file,
          madeAt: _madeAt(File(path)),
          transactions: ledger.txns.length,
          accounts: ledger.balanceSheetAccounts.length,
        );
      } on RestoreException {
        rethrow;
      } catch (e) {
        debugPrint('Backup unreadable: $e');
        throw RestoreException('That file isn’t a BetterBudget backup');
      } finally {
        await copy.close();
      }
    } catch (_) {
      await _deleteIncoming(dir, file);
      rethrow;
    }
  }

  /// The user cancelled: remove the working copy.
  Future<void> discard(RestoreCandidate c) async {
    final dir = await folder();
    if (dir != null) await _deleteIncoming(dir, c.file);
  }

  /// Replaces the ledger with [c]. What was there is saved first as
  /// `before-restore-….sqlite`, and the restored copy is kept as
  /// `restored-….sqlite`, so the restore can be undone and redone.
  Future<RestoreRecord> restore(RestoreCandidate c, DateTime now) async {
    final dir = (await folder())!;
    final before = _unused(dir, 'before-restore-', now);
    await db.copyTo(before.path);
    final restored = _unused(dir, 'restored-', now);
    await c.file.rename(restored.path);
    await _deleteIncoming(dir, c.file);
    await db.replaceAllFrom(restored.path);
    return (before: before, restored: restored);
  }

  /// Saves what's here as `before-new-ledger-….sqlite` before a new ledger
  /// replaces it, for undo and for Restore from… later.
  Future<File> saveBeforeNewLedger(DateTime now) async {
    final dir = await folder();
    if (dir == null) throw StateError('No database file to save');
    await dir.create(recursive: true);
    final file = _unused(dir, 'before-new-ledger-', now);
    await db.copyTo(file.path);
    return file;
  }

  /// Undo and redo of a restore: puts [file] back, saving what's here first
  /// (as another `before-restore-…`), since anything done after the restore
  /// that couldn't be undone would otherwise be in no file at all.
  Future<void> replaceWith(File file, DateTime now) async {
    final dir = (await folder())!;
    await db.copyTo(_unused(dir, 'before-restore-', now).path);
    await db.replaceAllFrom(file.path);
  }

  /// `<prefix><stamp>.sqlite`, a second later if that name is taken.
  static File _unused(Directory dir, String prefix, DateTime now) {
    var at = now;
    while (true) {
      final f = File('${dir.path}/$prefix${fileStamp(at)}.sqlite');
      if (!f.existsSync()) return f;
      at = at.add(const Duration(seconds: 1));
    }
  }

  /// The working copy, plus anything opening it left beside it (an upgrade
  /// backup, a journal).
  Future<void> _deleteIncoming(Directory dir, File file) async {
    final base = _basename(file.path).replaceFirst('.sqlite', '');
    for (final f in dir.listSync().whereType<File>()) {
      if (_basename(f.path).startsWith(base)) await f.delete();
    }
  }

  static Future<Uint8List?> _header(File f) async {
    final raf = await f.open();
    try {
      final bytes = await raf.read(100);
      return bytes.length < 100 ? null : bytes;
    } finally {
      await raf.close();
    }
  }

  /// From the time in the file's name when it has one (every copy the app
  /// makes does), otherwise when the file was last changed.
  static DateTime _madeAt(File f) {
    final m = _stamp.firstMatch(_basename(f.path));
    if (m == null) return f.lastModifiedSync();
    final p = [for (var i = 1; i <= 6; i++) int.parse(m.group(i)!)];
    return DateTime(p[0], p[1], p[2], p[3], p[4], p[5]);
  }

  static String _basename(String path) =>
      path.substring(path.lastIndexOf(Platform.pathSeparator) + 1);
}
