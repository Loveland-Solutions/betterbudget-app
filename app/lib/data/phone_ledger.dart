// The phone's side of the cloud folder (ADR 0005): finding the folder the
// ledger was moved to, and reaching the files in it. The phone never writes the
// folder's whole ledger; it keeps a ledger of its own (`phone_own_ledger.dart`,
// `phone_sync.dart`). What it writes there is its change file and its entries
// file (`phone_inbox.dart`).
import 'package:flutter/services.dart';

import 'folder_io.dart';

/// The folder picked with the system's own picker, which is how a phone
/// reaches Google Drive or OneDrive without this app touching the network
/// (`MainActivity.kt`). The permission is kept across launches.
class PhoneFolder {
  const PhoneFolder();

  static const _channel = MethodChannel('betterbudget/folder');

  /// Opens the picker; the folder's address, or null when none was chosen.
  Future<String?> pick() => _channel.invokeMethod<String>('pick');

  /// Back up to… (#534): the phone's own Save to for the file at [path],
  /// offered as [name]. Where it went, or null when nothing was chosen;
  /// throws when it couldn't be written, or while another is open.
  Future<SavedTo?> save(String path, String name) async =>
      switch (await _channel.invokeMethod<String>('save', {
        'path': path,
        'name': name,
      })) {
        'phone' => SavedTo.thisPhone,
        null => null,
        _ => SavedTo.elsewhere,
      };

  /// The folder picked on an earlier launch, if the phone still allows it.
  Future<String?> kept() => _channel.invokeMethod<String>('kept');

  /// The file [name] in [folder] and when it was last changed, or null when
  /// there is no such file.
  Future<({Uint8List bytes, DateTime? changed})?> read(
    String folder,
    String name,
  ) async {
    final found = await _channel.invokeMapMethod<String, Object?>('read', {
      'folder': folder,
      'name': name,
    });
    if (found == null) return null;
    final at = found['changed'] as int?;
    return (
      bytes: found['bytes']! as Uint8List,
      changed: at == null ? null : DateTime.fromMillisecondsSinceEpoch(at),
    );
  }

  /// When the file [name] in [folder] was last changed, without fetching
  /// it; null when there is no such file or the folder doesn't say.
  Future<DateTime?> changed(String folder, String name) async {
    final at = await _channel.invokeMethod<int>('changed', {
      'folder': folder,
      'name': name,
    });
    return at == null ? null : DateTime.fromMillisecondsSinceEpoch(at);
  }

  /// Writes [bytes] as the file [name] in [folder], over one already there:
  /// this phone's own entries, for the computer.
  Future<void> write(String folder, String name, Uint8List bytes) =>
      _channel.invokeMethod<void>('write', {
        'folder': folder,
        'name': name,
        'bytes': bytes,
      });

  /// The file's [FolderStat], or null when there is no such file.
  Future<FolderStat?> stat(String folder, String name) async {
    final found = await _channel.invokeMapMethod<String, Object?>('stat', {
      'folder': folder,
      'name': name,
    });
    if (found == null) return null;
    final at = found['changed'] as int?;
    // A provider that doesn't say reads as "no time", never as a change.
    return (
      modified: DateTime.fromMillisecondsSinceEpoch(at ?? 0),
      size: (found['size'] as int?) ?? -1,
    );
  }

  /// The names of the files in [folder], not its sub-folders.
  Future<List<String>> names(String folder) async =>
      (await _channel.invokeListMethod<String>('list', {'folder': folder})) ??
      const [];

  /// Takes the file [name] out of [folder]; nothing when there is none.
  Future<void> delete(String folder, String name) =>
      _channel.invokeMethod<void>('delete', {'folder': folder, 'name': name});

  /// Gives the folder up, before another is picked.
  Future<void> forget(String folder) =>
      _channel.invokeMethod<void>('forget', {'folder': folder});
}

/// The folder cycle's way into the folder on a phone ([FolderIo]): the system's
/// picker, through [PhoneFolder]. [folder] is the address it gave.
class PhoneFolderIo extends FolderIo {
  const PhoneFolderIo([this.folders = const PhoneFolder()]);

  final PhoneFolder folders;

  @override
  Future<FolderStat?> stat(String folder, String name) =>
      folders.stat(folder, name);

  @override
  Future<List<String>> names(String folder) => folders.names(folder);

  @override
  Future<Uint8List?> read(String folder, String name) async =>
      (await folders.read(folder, name))?.bytes;

  @override
  Future<void> write(String folder, String name, List<int> bytes) =>
      folders.write(folder, name, Uint8List.fromList(bytes));

  @override
  Future<void> delete(String folder, String name) =>
      folders.delete(folder, name);
}

/// The recovery key typed on this phone doesn't open the ledger in the folder.
class WrongKeyException implements Exception {}

/// Where Back up to… saved its copy: somewhere off the phone (a cloud
/// service, or a place the phone can't tell), or on the phone itself
/// (Downloads, its own storage, a card in it), which is lost with it.
enum SavedTo { elsewhere, thisPhone }
