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
}
