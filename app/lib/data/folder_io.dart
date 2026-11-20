// The one way the folder cycle reaches the shared folder (ADR 0005, "The phone
// joins as another computer"): a computer through `dart:io` paths, a phone
// through the system's picker. The cycle (`cloud_folder.dart`) and the change
// files (`change_file.dart`) ask only this, so both can run on either.
import 'dart:io';
import 'dart:typed_data';

/// A file in the folder as it stood when it was asked about: what a later
/// look compares to know it changed.
typedef FolderStat = ({DateTime modified, int size});

abstract class FolderIo {
  const FolderIo();

  /// The file [name] in [folder]; null when there is none.
  Future<FolderStat?> stat(String folder, String name);

  /// The names of the files in [folder], none of its sub-folders; empty when
  /// there is no such folder.
  Future<List<String>> names(String folder);

  /// The file's bytes; null when there is none.
  Future<Uint8List?> read(String folder, String name);

  /// [bytes] written as the file [name], over one already there where it is,
  /// not beside it and renamed, so a sync service sees the same file with a
  /// new version and never a second one. Made when there is none.
  Future<void> write(String folder, String name, List<int> bytes);

  /// Removes the file; nothing when there is none.
  Future<void> delete(String folder, String name);
}

/// A folder reached by its path, as a computer does.
class DirectoryFolderIo extends FolderIo {
  const DirectoryFolderIo();

  @override
  Future<FolderStat?> stat(String folder, String name) async {
    final s = File('$folder/$name').statSync();
    if (s.type == FileSystemEntityType.notFound) return null;
    return (modified: s.modified, size: s.size);
  }

  @override
  Future<List<String>> names(String folder) async {
    final dir = Directory(folder);
    if (!dir.existsSync()) return const [];
    return [
      await for (final f in dir.list())
        if (f is File) f.uri.pathSegments.last,
    ];
  }

  @override
  Future<Uint8List?> read(String folder, String name) async {
    final file = File('$folder/$name');
    return file.existsSync() ? file.readAsBytes() : null;
  }

  @override
  Future<void> write(String folder, String name, List<int> bytes) async {
    final out = await File('$folder/$name').open(mode: FileMode.write);
    try {
      await out.writeFrom(bytes);
      await out.flush();
    } finally {
      await out.close();
    }
  }

  @override
  Future<void> delete(String folder, String name) async {
    final file = File('$folder/$name');
    if (file.existsSync()) await file.delete();
  }
}
