// What a phone writes to the cloud folder for the computer (ADR 0005, "One
// writer per file"): its entries and the categories it made, in one small
// file only that phone writes. It is a database encrypted with the ledger's
// key, the same way the ledger is, so nothing about the money sits in the
// folder in the clear. The computer reads every phone's file and never
// writes one.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqlite3/sqlite3.dart';

import '../domain/money.dart';
import '../domain/phone.dart';
import 'encryption.dart';

/// Not a ledger, so not the ledger's extension.
const phoneInboxExtension = 'betterbudget-phone';

/// The name of the file the phone called [device] writes in the folder.
String phoneInboxName(String device) => 'Phone $device.$phoneInboxExtension';

bool isPhoneInboxName(String name) =>
    name.startsWith('Phone ') && name.endsWith('.$phoneInboxExtension');

/// Writes [inbox] to [file], whole, beside its name and then over it. A
/// null [key] writes it plain (tests).
void writePhoneInbox(File file, Uint8List? key, PhoneInbox inbox) {
  final arriving = File('${file.path}.tmp');
  if (arriving.existsSync()) arriving.deleteSync();
  final db = sqlite3.open(arriving.path);
  try {
    if (key != null) applyCipherKey(db, key);
    withoutKeyInErrors(() {
      db.execute('CREATE TABLE phone (device TEXT NOT NULL)');
      db.execute(
        'CREATE TABLE categories (id TEXT PRIMARY KEY, name TEXT NOT NULL, '
        'currency TEXT NOT NULL)',
      );
      db.execute(
        'CREATE TABLE entries (id TEXT PRIMARY KEY, category_id TEXT NOT NULL, '
        'account_id TEXT NOT NULL, payee TEXT NOT NULL, '
        'amount_minor INTEGER NOT NULL, date TEXT NOT NULL, '
        'made_at TEXT NOT NULL)',
      );
      // A split's lines (an entry filed under phoneSplitId). A file from
      // before splits has no such table.
      db.execute(
        'CREATE TABLE entry_lines (entry_id TEXT NOT NULL, '
        'category_id TEXT NOT NULL, amount_minor INTEGER NOT NULL)',
      );
      db.execute('BEGIN');
      db.execute('INSERT INTO phone VALUES (?)', [inbox.device]);
      for (final c in inbox.categories) {
        db.execute('INSERT INTO categories VALUES (?, ?, ?)', [
          c.id,
          c.name,
          c.currency.code,
        ]);
      }
      for (final e in inbox.entries) {
        db.execute('INSERT INTO entries VALUES (?, ?, ?, ?, ?, ?, ?)', [
          e.id,
          e.categoryId,
          e.accountId,
          e.payee,
          e.amountMinor,
          e.date.toIso8601String(),
          e.madeAt.toIso8601String(),
        ]);
        for (final l in e.lines) {
          db.execute('INSERT INTO entry_lines VALUES (?, ?, ?)', [
            e.id,
            l.categoryId,
            l.amountMinor,
          ]);
        }
      }
      db.execute('COMMIT');
    });
  } finally {
    db.close();
  }
  arriving.renameSync(file.path);
}

/// Reads a phone's file. Throws when [key] doesn't open it or it isn't one
/// (half-arrived, or from another ledger).
PhoneInbox readPhoneInbox(File file, Uint8List? key) {
  final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    if (key != null) applyCipherKey(db, key);
    return withoutKeyInErrors(() {
      final lines = <String, List<PhoneSplitLine>>{};
      final hasLines = db
          .select(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'entry_lines'",
          )
          .isNotEmpty;
      if (hasLines) {
        for (final r in db.select('SELECT * FROM entry_lines ORDER BY rowid')) {
          lines.putIfAbsent(r['entry_id'] as String, () => []).add((
            categoryId: r['category_id'] as String,
            amountMinor: r['amount_minor'] as int,
          ));
        }
      }
      return PhoneInbox(
        device:
            db.select('SELECT device FROM phone').single['device'] as String,
        categories: [
          for (final r in db.select('SELECT * FROM categories ORDER BY rowid'))
            PhoneCategory(
              id: r['id'] as String,
              name: r['name'] as String,
              leftMinor: 0,
              currency: Currency.fromCode(r['currency'] as String),
              madeHere: true,
            ),
        ],
        entries: [
          for (final r in db.select('SELECT * FROM entries ORDER BY rowid'))
            PhoneEntry(
              id: r['id'] as String,
              categoryId: r['category_id'] as String,
              accountId: r['account_id'] as String,
              payee: r['payee'] as String,
              amountMinor: r['amount_minor'] as int,
              date: DateTime.parse(r['date'] as String),
              madeAt: DateTime.parse(r['made_at'] as String),
              lines: lines[r['id']] ?? const [],
            ),
        ],
      );
    });
  } finally {
    db.close();
  }
}

/// Every phone's file in [folder] that [key] opens, read from a copy in
/// [scratch] so nothing is opened inside the folder a sync app is watching.
/// One that can't be read (still arriving) is left for the next look.
Future<List<PhoneInbox>> readPhoneInboxes(
  Directory folder,
  Uint8List? key, {
  required Directory scratch,
}) async {
  final found = <PhoneInbox>[];
  if (!folder.existsSync()) return found;
  await for (final f in folder.list()) {
    final name = f.uri.pathSegments.last;
    if (f is! File || !isPhoneInboxName(name)) continue;
    final copy = File('${scratch.path}/$name');
    try {
      await scratch.create(recursive: true);
      await f.copy(copy.path);
      found.add(readPhoneInbox(copy, key));
    } catch (e) {
      debugPrint('A phone’s file couldn’t be read: $e');
    } finally {
      if (copy.existsSync()) copy.deleteSync();
    }
  }
  return found;
}

/// The phone's own copy of what it has waiting, kept across launches in
/// [dir]: the same file it sends to the folder.
class PhoneOutbox {
  PhoneOutbox(this.dir, this.key);
  final Directory dir;
  final Uint8List key;

  File get _file => File('${dir.path}/waiting.$phoneInboxExtension');

  /// Whether this phone has ever had anything to keep.
  bool get exists => _file.existsSync();

  /// What was waiting when the app last closed. The first time, nothing,
  /// under a new name for this phone.
  PhoneInbox load() {
    if (_file.existsSync()) {
      try {
        return readPhoneInbox(_file, key);
      } catch (e) {
        debugPrint('The phone’s waiting entries couldn’t be read: $e');
        // Set aside, not written over: what was waiting may be got back.
        _file.renameSync('${_file.path}.unreadable');
      }
    }
    final random = Random.secure();
    return PhoneInbox(
      device: [
        for (var i = 0; i < 4; i++)
          random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ].join(),
    );
  }

  /// Keeps [inbox] on the phone and gives the file's bytes, for the folder.
  Uint8List save(PhoneInbox inbox) {
    dir.createSync(recursive: true);
    writePhoneInbox(_file, key, inbox);
    return _file.readAsBytesSync();
  }
}
