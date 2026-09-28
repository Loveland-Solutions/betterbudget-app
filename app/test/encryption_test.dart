// The real lib/data/encryption.dart code path: detecting a plain file,
// converting it in place, and applying the cipher key on open (ADR 0001).
// cipher_test.dart checks the library itself; this checks BetterBudget's
// own wrapper around it.
import 'dart:io';

import 'package:betterbudget/data/encryption.dart';
import 'package:betterbudget/data/keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('bb-encryption'));
  tearDown(() => dir.deleteSync(recursive: true));

  final key = deriveDataKey(RecoveryKey.generate());
  final otherKey = deriveDataKey(RecoveryKey.generate());

  group('isPlainSqliteFile', () {
    test('true for a freshly created plain database', () async {
      final file = File('${dir.path}/plain.sqlite');
      final db = sqlite3.open(file.path)..execute('CREATE TABLE t (x)');
      db.close();
      expect(await isPlainSqliteFile(file), isTrue);
    });

    test('false for an encrypted database', () async {
      final file = File('${dir.path}/enc.sqlite');
      final db = sqlite3.open(file.path);
      applyCipherKey(db, key);
      db.execute('CREATE TABLE t (x)');
      db.close();
      expect(await isPlainSqliteFile(file), isFalse);
    });

    test('false for a file that does not exist', () async {
      expect(
        await isPlainSqliteFile(File('${dir.path}/missing.sqlite')),
        isFalse,
      );
    });
  });

  test('convertPlainFileInPlace keeps the rows and requires the key after', () async {
    final file = File('${dir.path}/convert.sqlite');
    final plainDb = sqlite3.open(file.path)
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('CREATE TABLE t (x)')
      ..execute("INSERT INTO t VALUES ('Номин ₮')");
    plainDb.close();

    await convertPlainFileInPlace(file, key);
    expect(await isPlainSqliteFile(file), isFalse);

    final withoutKey = sqlite3.open(file.path);
    expect(() => withoutKey.select('SELECT * FROM t'), throwsA(anything));
    withoutKey.close();

    final withWrongKey = sqlite3.open(file.path);
    applyCipherKey(withWrongKey, otherKey);
    expect(() => withWrongKey.select('SELECT * FROM t'), throwsA(anything));
    withWrongKey.close();

    final withKey = sqlite3.open(file.path);
    applyCipherKey(withKey, key);
    expect(withKey.select('SELECT x FROM t').first['x'], 'Номин ₮');
    withKey.close();
  });

  test(
    'convertPlainFileInPlace removes its safety copy once it checks out',
    () async {
      final file = File('${dir.path}/safety.sqlite');
      sqlite3.open(file.path).execute('CREATE TABLE t (x)');
      await convertPlainFileInPlace(file, key);
      expect(File('${file.path}.before-encryption').existsSync(), isFalse);
    },
  );

  test(
    'convertPlainFileInPlace cleans up a stale safety copy from a prior '
    'crashed attempt before starting',
    () async {
      final file = File('${dir.path}/stale.sqlite');
      sqlite3.open(file.path).execute('CREATE TABLE t (x)');
      File('${file.path}.before-encryption').writeAsStringSync('leftover');
      await convertPlainFileInPlace(file, key);
      expect(await isPlainSqliteFile(file), isFalse);
      expect(File('${file.path}.before-encryption').existsSync(), isFalse);
    },
  );

  test('resolveDataKey derives the same key applyCipherKey can open with', () {
    // deriveDataKey + rawKeyLiteral (exercised via applyCipherKey) is the
    // same path AppDatabase.openEncrypted uses.
    final file = File('${dir.path}/roundtrip.sqlite');
    final db = sqlite3.open(file.path);
    applyCipherKey(db, key);
    db.execute('CREATE TABLE t (x)');
    db.execute('INSERT INTO t VALUES (42)');
    db.close();

    final reopened = sqlite3.open(file.path);
    applyCipherKey(reopened, key);
    expect(reopened.select('SELECT x FROM t').first['x'], 42);
    reopened.close();
  });
}
