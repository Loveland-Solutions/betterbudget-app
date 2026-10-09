import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

import 'database.dart';
import 'encryption.dart';
import 'keys.dart';
import 'ledger_file.dart';

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

/// When the ledger was last copied somewhere other than this computer's
/// disk with "Back up to…": the daily copies sit beside the ledger, so a
/// lost or broken computer takes them too.
@immutable
class CopiedElsewhere {
  const CopiedElsewhere({required this.since, this.copied});

  /// Past this many days without a copy elsewhere, the sidebar says so.
  static const remindAfterDays = 30;

  /// When this was first looked at on this computer: what a ledger never
  /// copied is counted from, so a new one isn't nagged on its first day.
  final DateTime since;

  /// The last "Back up to…" that worked, if there has been one.
  final DateTime? copied;

  /// Whole days since [copied], or since [since] when there's been none.
  int daysAt(DateTime now) => DateTime.utc(now.year, now.month, now.day)
      .difference(
        DateTime.utc(
          (copied ?? since).year,
          (copied ?? since).month,
          (copied ?? since).day,
        ),
      )
      .inDays;

  bool dueAt(DateTime now) => daysAt(now) > remindAfterDays;
}

/// A backup file picked for restore, already copied into the app's folder
/// and upgraded to this version, with what it holds.
class RestoreCandidate {
  const RestoreCandidate({
    required this.file,
    required this.madeAt,
    required this.transactions,
    required this.accounts,
    required this.sourceKeyBind,
  });

  /// The working copy in `Backups/`. The picked file itself is never changed.
  final File file;
  final DateTime madeAt;
  final int transactions;
  final int accounts;

  /// What [AppDatabase.replaceAllFrom] should bind to `ATTACH ... KEY ?`
  /// when this candidate is restored: the raw-key literal when [file] is
  /// encrypted with this app's data key, `''` when it's plain, or null when
  /// the main connection itself has no cipher configured (tests).
  final String? sourceKeyBind;
}

/// What a restore replaced and with what, so it can be undone and redone.
typedef RestoreRecord = ({File before, File restored});

/// Why a file can't be restored. The UI words it (`restoreProblem` in
/// ui/data_words.dart).
enum RestoreProblem {
  /// No ledger file to restore into.
  nothingToRestoreInto,

  /// Made by a newer BetterBudget, with a schema this one can't read.
  newerApp,

  /// Not a BetterBudget backup at all.
  notABackup,

  /// Encrypted, but not with this ledger's key.
  needsKey,

  /// The key the user typed doesn't open it either.
  wrongKey,

  /// Fails SQLite's integrity check, or its rows don't add up.
  damaged,

  /// Opens, but has no accounts.
  noAccounts,
}

/// A file that can't be restored, and why.
class RestoreException implements Exception {
  RestoreException(this.problem);
  final RestoreProblem problem;

  /// The reason in English (logs and tests; the UI words [problem]).
  String get message => switch (problem) {
    RestoreProblem.nothingToRestoreInto => 'Nothing to restore into',
    RestoreProblem.newerApp =>
      'That backup is from a newer BetterBudget · update the app first',
    RestoreProblem.notABackup => 'That file isn’t a BetterBudget backup',
    RestoreProblem.needsKey =>
      'That backup can’t be opened with this ledger’s key · it may be '
          'from another ledger, or damaged',
    RestoreProblem.wrongKey =>
      'That key doesn’t open this backup · it may be from another ledger, '
          'or damaged',
    RestoreProblem.damaged => 'That backup is damaged',
    RestoreProblem.noAccounts => 'That backup has no accounts in it',
  };

  @override
  String toString() => message;
}

/// The backup is encrypted, but not with this ledger's key: it may be from
/// another ledger (its own recovery key opens it), or damaged. Pass the key
/// the user types to [Backups.inspect] as `backupKey`.
class RestoreNeedsKeyException extends RestoreException {
  RestoreNeedsKeyException() : super(RestoreProblem.needsKey);
}

/// What converting the old plain copies did: how many were encrypted, and
/// which couldn't be (they're still readable, so the user is told).
typedef ConversionReport = ({int converted, List<File> failed});

/// Backups stay on this machine: a daily copy in the app's own folder, and a
/// copy saved wherever the user picks. Nothing is uploaded anywhere.
class Backups {
  Backups(this.db, {this.dataKey, this.keep = 14, this.months = 12});

  final AppDatabase db;

  /// This app's data key (ADR 0001), or null when [db] itself has no
  /// cipher configured (tests). Every backup [db] writes via `VACUUM INTO`
  /// stays encrypted with it automatically; this is only needed to read a
  /// backup from outside that connection (restore) or convert an old plain
  /// one in place.
  final Uint8List? dataKey;

  /// Daily copies kept: the newest [keep], one per day the app was opened.
  final int keep;

  /// Also kept: the first copy of each of the last [months] months, for a
  /// mistake found long after it was made.
  final int months;

  final health = ValueNotifier(const BackupHealth());

  /// Null until [loadElsewhere] has read it, and where there's no ledger
  /// file (tests).
  final elsewhere = ValueNotifier<CopiedElsewhere?>(null);

  /// This computer's own record, in a small file beside the ledger like the
  /// folder setting: it doesn't travel inside the ledger, where a restore
  /// would turn it back.
  Future<File?> _elsewhereFile() async {
    final dir = await folder();
    return dir == null ? null : File('${dir.parent.path}/copied-elsewhere');
  }

  /// Reads the record, starting it at [now] on a computer that has none,
  /// or whose record can't be read or is dated after [now] (a clock that
  /// was set ahead): better counted again from today than silent for good.
  /// Never throws.
  Future<void> loadElsewhere(DateTime now) async {
    if (elsewhere.value != null) return;
    try {
      final file = await _elsewhereFile();
      if (file == null) return;
      CopiedElsewhere? read;
      if (file.existsSync()) {
        try {
          final saved = jsonDecode(await file.readAsString()) as Map;
          final copied = saved['copied'] as String?;
          read = CopiedElsewhere(
            since: DateTime.parse(saved['since'] as String),
            copied: copied == null ? null : DateTime.parse(copied),
          );
        } catch (e) {
          debugPrint('The copied-elsewhere record was unreadable: $e');
        }
      }
      if (read != null && read.daysAt(now) >= 0) {
        elsewhere.value = read;
        return;
      }
      await _writeElsewhere(CopiedElsewhere(since: now));
    } catch (e) {
      debugPrint('Reading the copied-elsewhere record failed: $e');
    }
  }

  /// "Back up to…" worked at [now].
  Future<void> copiedElsewhere(DateTime now) async {
    try {
      await _writeElsewhere(
        CopiedElsewhere(since: elsewhere.value?.since ?? now, copied: now),
      );
    } catch (e) {
      debugPrint('Writing the copied-elsewhere record failed: $e');
    }
  }

  Future<void> _writeElsewhere(CopiedElsewhere record) async {
    elsewhere.value = record;
    final file = await _elsewhereFile();
    if (file == null) return;
    await file.parent.create(recursive: true);
    // Whole or not at all: a write cut short mustn't leave half a record.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode({
        'since': record.since.toIso8601String(),
        'copied': ?record.copied?.toIso8601String(),
      }),
      flush: true,
    );
    await temp.rename(file.path);
  }

  static const _prefix = 'betterbudget-';

  /// A daily copy's name. They end in [extension] since 2026-10-07; the ones
  /// made before that keep their `.sqlite` name and are listed, counted and
  /// cleared away the same as the rest (`ledger_file.dart`).
  static final _name = RegExp(
    r'^betterbudget-(\d{8})-(\d{6})\.(?:sqlite|betterbudget)$',
  );

  /// What every copy made here ends in.
  static const extension = ledgerExtension;
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
    await loadElsewhere(now);
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
    final file = File('${dir.path}/$_prefix${fileStamp(now)}.$extension');
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
      final pattern = RegExp('^$kind\\d{8}-\\d{6}\\.(?:sqlite|betterbudget)\$');
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
    // Never onto the file the app is working in: that would replace the
    // open ledger under itself.
    final live = await db.filePath();
    if (live != null && _sameFile(live, destination)) {
      throw StateError('That is the ledger itself');
    }
    await dir.create(recursive: true);
    final temp = File('${dir.path}/export-${fileStamp(now)}.$extension.tmp');
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
  /// version. Handles a plain backup, one encrypted with this app's own
  /// data key, and one encrypted with a different key (ADR 0001: restore
  /// must handle all three). Throws [RestoreException] when it can't be
  /// restored. Pass the result to [restore], or to [discard] if the user
  /// cancels.
  /// [backupKey] opens a backup made under another ledger's key, after the
  /// first try threw [RestoreNeedsKeyException].
  Future<RestoreCandidate> inspect(
    String path,
    DateTime now, {
    Uint8List? backupKey,
  }) async {
    final dir = await folder();
    if (dir == null) {
      throw RestoreException(RestoreProblem.nothingToRestoreInto);
    }
    await dir.create(recursive: true);
    final file = File('${dir.path}/incoming-${fileStamp(now)}.$extension');
    try {
      await File(path).copy(file.path);
      final looksPlain = await isPlainSqliteFile(file);
      final String? sourceKeyBind;
      if (looksPlain) {
        final header = await _header(file);
        final version = ByteData.sublistView(header!).getUint32(60);
        if (version > db.schemaVersion) {
          throw RestoreException(RestoreProblem.newerApp);
        }
        sourceKeyBind = dataKey == null ? null : '';
      } else {
        final key = backupKey ?? dataKey;
        if (key == null) {
          // No key context to try against a non-plain header (tests, or a
          // corrupt/foreign file): can't tell the difference, so this is
          // the same message a truly-invalid file gets.
          throw RestoreException(RestoreProblem.notABackup);
        }
        final int version;
        try {
          version = _rawUserVersion(file, key);
        } catch (e) {
          throw backupKey == null
              ? RestoreNeedsKeyException()
              : RestoreException(RestoreProblem.wrongKey);
        }
        if (version > db.schemaVersion) {
          throw RestoreException(RestoreProblem.newerApp);
        }
        sourceKeyBind = rawKeyLiteral(key);
      }
      // A local, not `dataKey` (a `this` getter): the setup closure below
      // crosses into a background isolate, which refuses to send anything
      // that captures `this` — a Backups holding a live FFI connection.
      final cipherKey = looksPlain ? null : (backupKey ?? dataKey);
      // Off the UI isolate: a big or odd file mustn't freeze the app.
      final copy = AppDatabase(
        NativeDatabase.createInBackground(
          file,
          setup: cipherKey == null
              ? null
              : (rawDb) => applyCipherKey(rawDb, cipherKey),
        ),
      );
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
          throw RestoreException(RestoreProblem.damaged);
        }
        final ledger = await copy.loadLedger();
        if (ledger.balanceSheetAccounts.isEmpty) {
          throw RestoreException(RestoreProblem.noAccounts);
        }
        return RestoreCandidate(
          file: file,
          madeAt: _madeAt(File(path)),
          transactions: ledger.txns.length,
          accounts: ledger.balanceSheetAccounts.length,
          sourceKeyBind: sourceKeyBind,
        );
      } on RestoreException {
        rethrow;
      } catch (e) {
        debugPrint('Backup unreadable: $e');
        throw RestoreException(RestoreProblem.notABackup);
      } finally {
        await copy.close();
      }
    } catch (_) {
      await _deleteIncoming(dir, file);
      rethrow;
    }
  }

  /// The `user_version` pragma stored in a file's (encrypted) header, read
  /// with a fresh raw connection so a wrong key throws before any of
  /// [file]'s data is touched through Drift.
  static int _rawUserVersion(File file, Uint8List key) {
    final raw = sqlite3.open(file.path);
    try {
      applyCipherKey(raw, key);
      return raw.select('PRAGMA user_version').first.values.first as int;
    } finally {
      raw.close();
    }
  }

  /// Converts every plain copy of the ledger still in the app's folder to
  /// SQLCipher in place (ADR 0001: the old plain copies must be converted
  /// too, not left behind): the daily copies in `Backups/`, the copies made
  /// before each schema upgrade beside the database, and any older folder of
  /// copies. One that can't be converted (damaged, or not a ledger) is
  /// skipped and reported, never allowed to stop the app from starting.
  Future<ConversionReport> convertPlainBackups() async {
    final key = dataKey;
    final live = await db.filePath();
    if (key == null || live == null) return (converted: 0, failed: <File>[]);
    final dir = File(live).parent;
    var converted = 0;
    final failed = <File>[];
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      // Only a copy from before encryption can be plain, and those were all
      // named `.sqlite`.
      if (!f.path.endsWith('.sqlite') || f.path == live) continue;
      if (!await isPlainSqliteFile(f)) continue;
      try {
        await convertPlainFileInPlace(f, key);
        converted++;
      } catch (e) {
        debugPrint('Couldn’t encrypt an old copy: $e');
        failed.add(f);
      }
    }
    return (converted: converted, failed: failed);
  }

  /// The user cancelled: remove the working copy.
  Future<void> discard(RestoreCandidate c) async {
    final dir = await folder();
    if (dir != null) await _deleteIncoming(dir, c.file);
  }

  /// Replaces the ledger with [c]. What was there is saved first as
  /// `before-restore-….betterbudget`, and the restored copy is kept as
  /// `restored-….betterbudget`, so the restore can be undone and redone. That
  /// snapshot is taken from this connection *after* the replace, not by
  /// renaming [c.file] — [c.file] may be plain (a pre-encryption backup),
  /// and [replaceWith] (undo/redo) assumes every `restored-…`/
  /// `before-restore-…` file is encrypted with [dataKey], same as this
  /// connection.
  Future<RestoreRecord> restore(RestoreCandidate c, DateTime now) async {
    final dir = (await folder())!;
    final before = _unused(dir, 'before-restore-', now);
    await db.copyTo(before.path);
    await db.replaceAllFrom(c.file.path, sourceKeyBind: c.sourceKeyBind);
    await _deleteIncoming(dir, c.file);
    final restored = _unused(dir, 'restored-', now);
    await db.copyTo(restored.path);
    return (before: before, restored: restored);
  }

  /// Saves what's here as `before-new-ledger-….betterbudget` before a new ledger
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
  /// that couldn't be undone would otherwise be in no file at all. [file] is
  /// always one of this app's own snapshots (`before-restore-…` or
  /// `restored-…`, both written by [AppDatabase.copyTo] on this connection),
  /// so it's encrypted with [dataKey] whenever that's set, never plain.
  Future<void> replaceWith(File file, DateTime now) async {
    final dir = (await folder())!;
    await db.copyTo(_unused(dir, 'before-restore-', now).path);
    await db.replaceAllFrom(
      file.path,
      sourceKeyBind: dataKey == null ? null : rawKeyLiteral(dataKey!),
    );
  }

  static bool _sameFile(String a, String b) {
    String real(String p) {
      final f = File(p);
      try {
        return f.existsSync()
            ? f.resolveSymbolicLinksSync()
            : '${f.parent.resolveSymbolicLinksSync()}/${_basename(p)}';
      } on FileSystemException {
        return p;
      }
    }

    return real(a) == real(b);
  }

  /// `<prefix><stamp>.betterbudget`, a second later if that name is taken.
  static File _unused(Directory dir, String prefix, DateTime now) {
    var at = now;
    while (true) {
      final f = File('${dir.path}/$prefix${fileStamp(at)}.$extension');
      if (!f.existsSync()) return f;
      at = at.add(const Duration(seconds: 1));
    }
  }

  /// The working copy, plus anything opening it left beside it (an upgrade
  /// backup, a journal).
  Future<void> _deleteIncoming(Directory dir, File file) async {
    final base = withoutLedgerExtension(_basename(file.path));
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
