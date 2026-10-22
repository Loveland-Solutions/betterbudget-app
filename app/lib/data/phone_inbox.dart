// What a phone writes to the cloud folder for the computer (ADR 0005, "One
// writer per file"): its entries and the categories it made, in one small
// file only that phone writes. It is a database encrypted with the ledger's
// key, the same way the ledger is, so nothing about the money sits in the
// folder in the clear. The computer reads every phone's file and never
// writes one.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqlite3/sqlite3.dart';

import '../domain/ledger.dart';
import '../domain/money.dart';
import '../domain/pay.dart';
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
      // A category's plan and the accounts it isn't paid from, as its New
      // category page set them. A computer from before reads neither and
      // makes the category bare.
      db.execute(
        'CREATE TABLE category_plans (category_id TEXT PRIMARY KEY, '
        'plan TEXT NOT NULL)',
      );
      db.execute(
        'CREATE TABLE category_off (category_id TEXT NOT NULL, '
        'account_id TEXT NOT NULL)',
      );
      db.execute('BEGIN');
      db.execute('INSERT INTO phone VALUES (?)', [inbox.device]);
      for (final c in inbox.categories) {
        db.execute('INSERT INTO categories VALUES (?, ?, ?)', [
          c.id,
          c.name,
          c.currency.code,
        ]);
        if (c.plan case final plan?) {
          db.execute('INSERT INTO category_plans VALUES (?, ?)', [
            c.id,
            jsonEncode(planToJson(plan)),
          ]);
        }
        for (final a in c.off) {
          db.execute('INSERT INTO category_off VALUES (?, ?)', [c.id, a]);
        }
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
      bool has(String table) => db.select(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        [table],
      ).isNotEmpty;
      final plans = <String, CategoryPlan>{};
      if (has('category_plans')) {
        for (final r in db.select('SELECT * FROM category_plans')) {
          // One this computer can't read (a newer phone's) is left out:
          // the category still comes in.
          final plan = planFromJson(r['plan'] as String);
          if (plan != null) plans[r['category_id'] as String] = plan;
        }
      }
      final off = <String, Set<String>>{};
      if (has('category_off')) {
        for (final r in db.select('SELECT * FROM category_off')) {
          off
              .putIfAbsent(r['category_id'] as String, () => {})
              .add(r['account_id'] as String);
        }
      }
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
              plan: plans[r['id']],
              // A bill shows with the bills, by its date, as when it was made.
              due: plans[r['id']]?.kind == PlanKind.byDate
                  ? plans[r['id']]?.due
                  : null,
              off: off[r['id']] ?? const {},
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

/// [plan] as the phone's file keeps it: by name, so a field added later
/// leaves an older reader with the rest.
Map<String, Object?> planToJson(CategoryPlan plan) {
  String? day(DateTime? d) => d == null ? null : dateKey(d);
  return {
    'kind': plan.kind.name,
    'amount': plan.amount,
    'start': day(plan.start),
    'due': day(plan.due),
    'everyMonths': plan.everyMonths,
    'everyDays': plan.everyDays,
    'onDates': plan.onDates == null
        ? null
        : [
            for (final (m, d) in plan.onDates!) [m, d],
          ],
    'payScheduleId': plan.payScheduleId,
    'daysAfterPay': plan.daysAfterPay,
    'weekend': plan.weekend.name,
    'weekdays': plan.weekdays,
    'nth': plan.nth,
    'nthWeekday': plan.nthWeekday,
    'endDate': day(plan.endDate),
    'endCount': plan.endCount,
    'rollover': plan.rollover,
    'upTo': plan.upTo,
    'paidFrom': plan.paidFrom,
  };
}

/// The plan [text] holds, for no category yet (0); null when it can't be
/// read as one.
CategoryPlan? planFromJson(String text) {
  try {
    final j = jsonDecode(text) as Map<String, Object?>;
    DateTime? day(Object? v) => v == null ? null : parseDateKey(v as String);
    final kind = PlanKind.values.byName(j['kind'] as String);
    final weekend = PayWeekend.values.byName(
      j['weekend'] as String? ?? PayWeekend.keep.name,
    );
    final plan = CategoryPlan(
      categoryId: 0,
      kind: kind,
      amount: j['amount'] as int,
      start: day(j['start'])!,
      due: day(j['due']),
      everyMonths: j['everyMonths'] as int?,
      everyDays: j['everyDays'] as int?,
      onDates: switch (j['onDates']) {
        final List<Object?> l => [
          for (final x in l) ((x as List<Object?>)[0] as int, x[1] as int),
        ],
        _ => null,
      },
      payScheduleId: j['payScheduleId'] as int?,
      daysAfterPay: j['daysAfterPay'] as int? ?? 0,
      weekend: weekend,
      weekdays: (j['weekdays'] as List<Object?>?)?.cast<int>(),
      nth: j['nth'] as int?,
      nthWeekday: j['nthWeekday'] as int?,
      endDate: day(j['endDate']),
      endCount: j['endCount'] as int?,
      rollover: j['rollover'] as bool? ?? true,
      upTo: j['upTo'] as int?,
      paidFrom: j['paidFrom'] as int?,
    );
    // Only a plan the computer could have made: an amount, counts above
    // nothing, and a dated one with a date or a pay to come by.
    bool above(int? n) => n == null || n > 0;
    if (plan.amount <= 0 ||
        !above(plan.everyDays) ||
        !above(plan.everyMonths) ||
        !above(plan.endCount) ||
        !above(plan.upTo) ||
        (plan.kind == PlanKind.byDate &&
            plan.due == null &&
            plan.payScheduleId == null)) {
      throw FormatException('not a plan: $text');
    }
    return plan;
  } catch (e) {
    debugPrint('A phone’s category plan couldn’t be read: $e');
    return null;
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
