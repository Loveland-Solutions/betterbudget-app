// A computer's change file in the folder (ADR 0005, step 3): written whole
// and in place, read back from a copy, and only the other computers' read.
import 'dart:io';

import 'package:betterbudget/data/change_file.dart';
import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late AppDatabase db;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('bb-change-file');
    db = AppDatabase(NativeDatabase.memory());
    await seedDemoIfEmpty(db, DateTime(2026, 10, 12));
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  ChangeFileHeader header(
    String computer, {
    Map<String, int> applied = const {},
  }) => ChangeFileHeader(
    computer: computer,
    name: 'The desk Mac',
    ledger: 'abcd',
    schema: db.schemaVersion,
    applied: applied,
    lastSeq: 0,
    writtenAt: DateTime(2026, 10, 12, 10),
  );

  test('the name says which computer, and isn’t a phone’s or the ledger’s', () {
    final name = changeFileName('a1b2');
    expect(isChangeFileName(name), isTrue);
    expect(computerOfChangeFile(name), 'a1b2');
    expect(isChangeFileName('Ledger.betterbudget'), isFalse);
    expect(isChangeFileName('Phone pixel.betterbudget-phone'), isFalse);
  });

  test('written whole and read back, in order, after a given change', () async {
    final rows = await db.changesSince(0);
    expect(rows.length, greaterThan(3));
    final file = File('${root.path}/${changeFileName('a1b2')}');
    await writeChangeFile(
      file,
      null,
      header('a1b2', applied: {'a1b2': rows.last.seq, 'c3d4': 7}),
      rows,
      scratch: Directory('${root.path}/scratch'),
    );
    final read = readChangeFile(file, null);
    expect(read.header.computer, 'a1b2');
    expect(read.header.name, 'The desk Mac');
    expect(read.header.ledger, 'abcd');
    expect(read.header.applied, {'a1b2': rows.last.seq, 'c3d4': 7});
    expect(read.changes.map((c) => c.seq), rows.map((r) => r.seq));
    final first = read.changes.first;
    expect(first.tbl, rows.first.tbl);
    expect(first.pk.keys, isNotEmpty);
    expect(first.after, isNotNull);
    // After a change: only what follows.
    final later = readChangeFile(file, null, afterSeq: rows[2].seq);
    expect(later.changes.first.seq, rows[3].seq);
    // Written again over the same file: one file, the new contents.
    await writeChangeFile(
      file,
      null,
      header('a1b2'),
      rows.take(2).toList(),
      scratch: Directory('${root.path}/scratch'),
    );
    expect(readChangeFile(file, null).changes, hasLength(2));
    expect(root.listSync().whereType<File>(), hasLength(1));
  });

  test('every other computer’s file is read from a copy; a torn one is '
      'named and left', () async {
    final rows = await db.changesSince(0);
    final scratch = Directory('${root.path}/scratch');
    for (final c in ['a1b2', 'c3d4', 'e5f6']) {
      await writeChangeFile(
        File('${root.path}/${changeFileName(c)}'),
        null,
        header(c),
        rows,
        scratch: scratch,
      );
    }
    await File('${root.path}/${changeFileName('e5f6')}')
        .writeAsBytes([1, 2, 3]);
    final unreadable = <String>[];
    final read = await readChangeFiles(
      root,
      null,
      scratch: scratch,
      butComputer: 'a1b2',
      afterSeq: {'c3d4': rows[1].seq},
      unreadable: unreadable,
    );
    expect(read.map((f) => f.header.computer), ['c3d4']);
    expect(read.single.changes.first.seq, rows[2].seq);
    expect(unreadable, ['e5f6']);
    expect(scratch.listSync(), isEmpty);
  });

  // ---------- compaction (ADR 0005 step 5) ----------

  test('a compacted log keeps a note at the cut: the file starts after it, '
      'and a reader still knows what the writer had seen of it', () async {
    // What the writer had applied of the laptop, then a change after it.
    await db.customStatement(
      'INSERT INTO changes (tbl, pk, op, before, after, at_ms, with_schema) '
      "VALUES ('sync', '{}', 'applied', NULL, ?, 0, 1)",
      ['{"c3d4":7}'],
    );
    final cut = await db.lastChangeSeq();
    final account = (await db.loadLedger()).accounts.values.first;
    await db.renameAccount(account.id, 'Wallet');
    final rows = await db.changesSince(0);
    final last = await db.lastChangeSeq();
    expect(await db.compactChanges(cut), isTrue);
    // Once is enough: nothing more to drop at the same cut.
    expect(await db.compactChanges(cut), isFalse);
    expect(await db.lastChangeSeq(), last);
    final kept = await db.changesSince(0);
    expect(kept.first.seq, cut);
    expect(kept.skip(1).map((r) => r.seq), [
      for (final r in rows)
        if (r.seq > cut) r.seq,
    ]);
    expect(firstSeqOf(kept), cut + 1);

    final file = File('${root.path}/${changeFileName('a1b2')}');
    await writeChangeFile(
      file,
      null,
      header('a1b2', applied: {'a1b2': last}),
      kept,
      scratch: Directory('${root.path}/scratch'),
    );
    final read = readChangeFile(file, null, afterSeq: cut);
    expect(read.header.firstSeq, cut + 1);
    expect(read.header.knowsCuts, isTrue);
    expect(read.knewBefore, {'c3d4': 7});
    expect(read.changes.first.seq, cut + 1);
  });

  test('cut no further than the folder’s ledger and every computer seen in '
      'the last six weeks hold', () {
    final now = DateTime(2026, 11, 19);
    ChangeFileHeader seen(String id, int had, {int daysAgo = 1}) =>
        ChangeFileHeader(
          computer: id,
          name: null,
          ledger: 'abcd',
          schema: 1,
          applied: {'me': had},
          lastSeq: 1,
          writtenAt: now.subtract(Duration(days: daysAgo)),
        );
    int cut(List<ChangeFileHeader> files, {int folder = 50}) => compactionCut(
      me: 'me',
      ledger: 'abcd',
      folder: {'me': folder},
      files: files,
      now: now,
    );
    expect(cut([]), 50);
    expect(cut([seen('mac', 70)]), 50);
    expect(cut([seen('mac', 70), seen('laptop', 30)]), 30);
    expect(cut([seen('mac', 70), seen('laptop', 30, daysAgo: 46)]), 50);
    // A file from a build before compaction is never counted away: that
    // build would pass over what was cut.
    final older = seen('laptop', 30, daysAgo: 200);
    expect(
      cut([
        ChangeFileHeader(
          computer: older.computer,
          name: null,
          ledger: older.ledger,
          schema: 1,
          applied: older.applied,
          lastSeq: 1,
          writtenAt: older.writtenAt,
          knowsCuts: false,
        ),
      ]),
      30,
    );
    expect(cut([seen('mac', 70)], folder: 0), 0);
    // Another ledger's file holds nothing back.
    expect(
      compactionCut(
        me: 'me',
        ledger: 'abcd',
        folder: {'me': 50},
        files: [
          ChangeFileHeader(
            computer: 'old',
            name: null,
            ledger: 'ffff',
            schema: 1,
            applied: const {},
            lastSeq: 1,
            writtenAt: now,
          ),
        ],
        now: now,
      ),
      50,
    );
  });
}
