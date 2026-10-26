// Recent problems (#294): kept on the device, plain, with no amounts.
import 'dart:io';

import 'package:betterbudget/data/database.dart'
    show ReconcileMismatchException;
import 'package:betterbudget/data/problem_log.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/common.dart' show SqliteException;

void main() {
  late Directory dir;
  late File file;
  var now = DateTime(2026, 10, 27, 14, 5);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('problems');
    file = File('${dir.path}/problems');
    now = DateTime(2026, 10, 27, 14, 5);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  ProblemLog log() =>
      ProblemLog(file, now: () => now, version: () async => '0.56.0');

  group('what of a reason is kept', () {
    test('a database error loses its statement and the values in it', () {
      expect(
        keptReason(
          SqliteException(
            extendedResultCode: 2067,
            message: 'UNIQUE constraint failed: categories.name',
            explanation: 'constraint failed (code 2067)',
            operation: 'executing statement',
            causingStatement:
                'INSERT INTO categories (name, assigned) '
                'VALUES (?, ?)',
            parametersToStatement: ['Groceries', 61900000],
          ),
        ),
        'SqliteException(2067): while executing statement, UNIQUE '
        'constraint failed: categories.name, constraint failed (code 2067)',
      );
    });

    test('a number that couldn’t be read keeps only its type', () {
      expect(
        keptReason(const FormatException('not a plan: 61900000', '1,234')),
        'FormatException',
      );
      expect(
        keptReason(ReconcileMismatchException(12500)),
        contains('Mismatch'),
      );
      expect(
        keptReason(ReconcileMismatchException(12500)),
        isNot(contains('12500')),
      );
    });

    test('the system’s errors keep their words and paths', () {
      expect(
        keptReason(
          PlatformException(code: 'busy', message: 'The disk is busy'),
        ),
        'PlatformException(busy, The disk is busy, null, null)',
      );
      expect(
        keptReason(const FileSystemException('Cannot open', '/Users/x/a.bak')),
        "FileSystemException: Cannot open, path = '/Users/x/a.bak'",
      );
    });

    test('a long one is cut', () {
      expect(keptReason('x' * 1000), '${'x' * 400}…');
    });
  });

  test('a problem is kept, read back, and copied newest first', () async {
    final first = log();
    expect(first.recent, isEmpty);
    await first.record('Couldn’t save the row', 'PlatformException(busy)');
    now = now.add(const Duration(hours: 1));
    await first.record('Couldn’t read the backup', 'FileSystemException\nmore');

    final again = log();
    expect(again.recent.map((p) => p.message), [
      'Couldn’t read the backup',
      'Couldn’t save the row',
    ]);
    expect(again.recent.first.reason, 'FileSystemException');
    expect(again.recent.first.version, '0.56.0');
    expect(
      problemsReport(again.recent),
      '2026-10-27 15:05 · 0.56.0\n'
      'Couldn’t read the backup\n'
      'FileSystemException\n'
      '\n'
      '2026-10-27 14:05 · 0.56.0\n'
      'Couldn’t save the row\n'
      'PlatformException(busy)',
    );
  });

  test('it keeps the newest 100, none older than 90 days', () async {
    final l = log();
    for (var i = 0; i < 105; i++) {
      await l.record('Problem $i', 'Reason');
    }
    expect(l.recent, hasLength(100));
    expect(l.recent.last.message, 'Problem 5');
    expect(file.readAsLinesSync(), hasLength(100));

    now = now.add(const Duration(days: 91));
    expect(l.recent, isEmpty);
    await l.record('Today’s', 'Reason');
    expect(file.readAsLinesSync(), hasLength(1));
  });

  test('a line it can’t read is passed over, not the whole record', () async {
    file.writeAsStringSync('not json\n{"at": "nonsense"}\n');
    final l = log();
    expect(l.recent, isEmpty);
    await l.record('Couldn’t save the row', 'Reason');
    expect(log().recent.single.message, 'Couldn’t save the row');
  });

  test('a record it can’t write still says what happened here', () async {
    final l = ProblemLog(
      File('${dir.path}/problems/in/a/file'),
      now: () => now,
      version: () async => '',
    );
    File('${dir.path}/problems').writeAsStringSync('a file in the way');
    await l.record('Couldn’t save the row', 'Reason');
    expect(l.recent.single.message, 'Couldn’t save the row');
  });
}
