// The phone's side of the cloud folder (ADR 0005): finding the folder the
// ledger was moved to, and reading the ledger in it. The phone never writes to
// that file; it takes a private copy and opens the copy. What the phone does
// write there is its own file (`phone_inbox.dart`).
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';

import '../domain/phone.dart';
import 'database.dart';
import 'encryption.dart';
import 'ledger_file.dart';

/// The folder picked with the system's own picker, which is how a phone
/// reaches Google Drive or OneDrive without this app touching the network
/// (`MainActivity.kt`). The permission is kept across launches.
class PhoneFolder {
  const PhoneFolder();

  static const _channel = MethodChannel('betterbudget/folder');

  /// Opens the picker; the folder's address, or null when none was chosen.
  Future<String?> pick() => _channel.invokeMethod<String>('pick');

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

  /// Gives the folder up, before another is picked.
  Future<void> forget(String folder) =>
      _channel.invokeMethod<void>('forget', {'folder': folder});
}

/// The recovery key typed on this phone doesn't open the ledger in the folder.
class WrongKeyException implements Exception {}

/// Takes [bytes], the ledger as it sits in the folder, into [dir] and reads
/// what the phone shows from it. Throws [WrongKeyException] when [dataKey]
/// doesn't open it, and whatever the database throws when it can't be read
/// (a ledger from a newer version of the app).
Future<PhoneSnapshot> readPhoneLedger(
  Uint8List bytes,
  Uint8List dataKey, {
  required Directory dir,
  required DateTime today,
  required DateTime madeAt,
}) async {
  await dir.create(recursive: true);
  final copy = File('${dir.path}/$ledgerFileName');
  // Anything the last read left beside the copy belongs to the old bytes.
  for (final f in dir.listSync().whereType<File>()) {
    await f.delete();
  }
  await copy.writeAsBytes(bytes, flush: true);
  if (!keyOpens(copy, dataKey)) throw WrongKeyException();
  final db = AppDatabase(
    NativeDatabase(copy, setup: (raw) => applyCipherKey(raw, dataKey)),
  );
  try {
    return snapshotOf(await db.loadLedger(), today: today, madeAt: madeAt);
  } finally {
    await db.close();
  }
}
