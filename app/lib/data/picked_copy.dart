// A phone's file picker hands the app a copy of the picked file in one of
// the app's own folders: an iPhone's in its temporary folder, Android's in
// a folder of its own inside the app's cache. A bank file is read once and
// its copy removed, so nothing of it stays on the phone but the rows (#531;
// PRIVACY.md, "Bank files you import").
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;

/// Deletes the picked file at [path] when it sits inside one of the app's
/// [own] folders, and the folder the picker made for it when that is left
/// empty. A file anywhere else is the person's and is never touched.
/// Returns whether a copy was removed.
Future<bool> dropPickedCopy(
  String path, {
  required Iterable<String> own,
}) async {
  if (path.isEmpty) return false;
  try {
    final file = File(path);
    if (!file.existsSync()) return false;
    // Where it really is: a link out of the app's folder isn't followed.
    final real = file.resolveSymbolicLinksSync();
    for (final folder in own) {
      final dir = Directory(folder);
      if (!dir.existsSync()) continue;
      final root = dir.resolveSymbolicLinksSync();
      if (!real.startsWith('$root${Platform.pathSeparator}')) continue;
      await file.delete();
      final parent = File(real).parent;
      if (parent.path != root &&
          parent.existsSync() &&
          parent.listSync().isEmpty) {
        parent.deleteSync();
      }
      return true;
    }
  } catch (e) {
    debugPrint('Removing the picked file\'s copy failed: $e');
  }
  return false;
}
