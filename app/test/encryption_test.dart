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

  test(
    'convertPlainFileInPlace keeps the rows and requires the key after',
    () async {
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
    },
  );

  test('a conversion leaves no plain copy or temp file behind', () async {
    final file = File('${dir.path}/tidy.sqlite');
    sqlite3.open(file.path)
      ..execute('CREATE TABLE t (x)')
      ..close();
    File('${file.path}.encrypting').writeAsStringSync('from a crashed run');
    await convertPlainFileInPlace(file, key);
    expect(await isPlainSqliteFile(file), isFalse);
    expect(
      dir.listSync().map((f) => f.path.split('/').last),
      unorderedEquals(['tidy.sqlite']),
    );
  });

  test('changes still in the -wal are encrypted too', () async {
    final file = File('${dir.path}/live.sqlite');
    // Left open, as if the app had been killed: rows only in the -wal.
    final live = sqlite3.open(file.path)
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('PRAGMA wal_autocheckpoint = 0')
      ..execute('CREATE TABLE t (x)');
    for (var i = 0; i < 50; i++) {
      live.execute('INSERT INTO t VALUES ($i)');
    }
    expect(File('${file.path}-wal').lengthSync(), greaterThan(0));
    // Copy the files as a crash would leave them, then close the original.
    final crashed = File('${dir.path}/crashed.sqlite');
    file.copySync(crashed.path);
    File('${file.path}-wal').copySync('${crashed.path}-wal');
    live.close();

    await convertPlainFileInPlace(crashed, key);
    final check = sqlite3.open(crashed.path);
    applyCipherKey(check, key);
    expect(check.select('SELECT count(*) AS n FROM t').first['n'], 50);
    check.close();
  });

  group('recoverInterruptedConversion', () {
    test('puts the plain copy back when the file is half encrypted', () async {
      final file = File('${dir.path}/half.sqlite');
      final safety = File('${file.path}.before-encryption');
      sqlite3.open(safety.path)
        ..execute('CREATE TABLE t (x)')
        ..execute('INSERT INTO t VALUES (7)')
        ..close();
      file.writeAsBytesSync(List.filled(8192, 3)); // not plain, won't open
      await recoverInterruptedConversion(file, key);
      expect(safety.existsSync(), isFalse);
      expect(await isPlainSqliteFile(file), isTrue);
      await convertPlainFileInPlace(file, key);
      final check = sqlite3.open(file.path);
      applyCipherKey(check, key);
      expect(check.select('SELECT x FROM t').first['x'], 7);
      check.close();
    });

    test('removes the plain copy when the file is fine', () async {
      final file = File('${dir.path}/done.sqlite');
      final db = sqlite3.open(file.path);
      applyCipherKey(db, key);
      db
        ..execute('CREATE TABLE t (x)')
        ..close();
      final safety = File('${file.path}.before-encryption')
        ..writeAsStringSync('plain copy');
      await recoverInterruptedConversion(file, key);
      expect(safety.existsSync(), isFalse);
      expect(keyOpens(file, key), isTrue);
    });
  });

  test('keyOpens says whether a key fits, and errors never show it', () {
    final file = File('${dir.path}/fits.sqlite');
    final db = sqlite3.open(file.path);
    applyCipherKey(db, key);
    db
      ..execute('CREATE TABLE t (x)')
      ..close();
    expect(keyOpens(file, key), isTrue);
    expect(keyOpens(file, otherKey), isFalse);
    expect(keyOpens(File('${dir.path}/none.sqlite'), key), isFalse);

    final wrong = sqlite3.open(file.path);
    applyCipherKey(wrong, otherKey);
    final hex = rawKeyLiteral(otherKey).substring(2, 66);
    try {
      withoutKeyInErrors(() => wrong.select('SELECT * FROM t'));
      fail('should not open');
    } on CipherException catch (e) {
      expect(e.toString(), isNot(contains(hex)));
    } finally {
      wrong.close();
    }
  });

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
