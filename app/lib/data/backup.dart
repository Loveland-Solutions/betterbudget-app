import 'dart:io';

import 'database.dart';

/// Backups stay on this machine: a daily copy in the app's own folder, and a
/// copy saved wherever the user picks. Nothing is uploaded anywhere.
class Backups {
  Backups(this.db, {this.keep = 14});

  final AppDatabase db;

  /// Automatic copies kept, one per day the app was opened; older ones go.
  final int keep;

  static const _prefix = 'betterbudget-';
  static final _name = RegExp(r'^betterbudget-(\d{8})-\d{6}\.sqlite$');

  /// `Backups/` beside the database file, or null for an in-memory database.
  Future<Directory?> folder() async {
    final path = await db.filePath();
    if (path == null) return null;
    return Directory('${File(path).parent.path}/Backups');
  }

  /// The automatic copies, newest first.
  Future<List<File>> automatic() async {
    final dir = await folder();
    if (dir == null || !dir.existsSync()) return const [];
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => _name.hasMatch(_basename(f.path)))
            .toList()
          ..sort((a, b) => _basename(b.path).compareTo(_basename(a.path)));
    return files;
  }

  /// Makes today's copy unless there already is one, then keeps only the
  /// newest [keep]. Returns the new copy, or null when none was needed.
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
    final file = File('${dir.path}/$_prefix${fileStamp(now)}.sqlite');
    await db.copyTo(file.path);
    for (final old in (await automatic()).skip(keep)) {
      await old.delete();
    }
    return file;
  }

  /// A copy saved to [destination], replacing a file already there. SQLite
  /// writes it in the app's folder first, then it's copied over, so only
  /// the one file the user picked is touched outside the app.
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

  static String _basename(String path) =>
      path.substring(path.lastIndexOf(Platform.pathSeparator) + 1);
}
