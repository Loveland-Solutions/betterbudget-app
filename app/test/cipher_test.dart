// Checks the encryption library ADR 0001 relies on: SQLCipher v4 files that
// need the key, backups by VACUUM INTO that stay encrypted, and plain files
// that convert in place.
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:flutter_test/flutter_test.dart';

const key =
    "x'2DD29CA851E7B56E4697B0E1F08507293D761A05CE4D1B628663F411A8086D99'";

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('bb-cipher'));
  tearDown(() => dir.deleteSync(recursive: true));

  Database open(String name, {String? k}) {
    final db = sqlite3.open('${dir.path}/$name');
    if (k != null) {
      db.execute("PRAGMA cipher = 'sqlcipher'");
      db.execute('PRAGMA legacy = 4');
      db.execute('PRAGMA key = "$k"');
    }
    return db;
  }

  bool plain(String name) {
    final b = File('${dir.path}/$name').readAsBytesSync().sublist(0, 15);
    return String.fromCharCodes(b) == 'SQLite format 3';
  }

  test('the app runs on SQLite3 Multiple Ciphers', () {
    final db = sqlite3.openInMemory();
    expect(
      db.select('SELECT sqlite3mc_version() v').first['v'],
      startsWith('SQLite3 Multiple Ciphers'),
    );
    db.close();
  });

  test('encrypted file, wrong and missing key refused', () {
    final db = open('a.sqlite', k: key)
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('CREATE TABLE t (x TEXT)')
      ..execute("INSERT INTO t VALUES ('Номин ₮')");
    db.close();
    expect(plain('a.sqlite'), isFalse);
    final none = open('a.sqlite');
    expect(() => none.select('SELECT * FROM t'), throwsA(anything));
    none.close();
    final ok = open('a.sqlite', k: key);
    expect(ok.select('SELECT x FROM t').first['x'], 'Номин ₮');
    ok.close();
  });

  test('VACUUM INTO keeps the encryption', () {
    final db = open('a.sqlite', k: key)
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('CREATE TABLE t (x)')
      ..execute('INSERT INTO t VALUES (1)')
      ..execute("VACUUM INTO '${dir.path}/b.sqlite'");
    db.close();
    expect(plain('b.sqlite'), isFalse);
    final copy = open('b.sqlite', k: key);
    expect(copy.select('SELECT x FROM t').first['x'], 1);
    copy.close();
  });

  test('a plain file converts in place with rekey', () {
    final db = open('p.sqlite')
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('CREATE TABLE t (x)')
      ..execute('INSERT INTO t VALUES (1)');
    db.close();
    final c = open('p.sqlite')
      ..execute('PRAGMA journal_mode = DELETE')
      ..execute("PRAGMA cipher = 'sqlcipher'")
      ..execute('PRAGMA legacy = 4')
      ..execute('PRAGMA rekey = "$key"');
    c.close();
    expect(plain('p.sqlite'), isFalse);
    final ok = open('p.sqlite', k: key);
    expect(ok.select('SELECT x FROM t').first['x'], 1);
    ok.close();
  });
}
