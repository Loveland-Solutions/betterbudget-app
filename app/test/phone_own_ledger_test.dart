// The phone's own whole ledger (ADR 0005, #526 piece 2): taken from the
// folder's ledger the way a second computer joins, written to with its own
// log, kept between launches.
import 'dart:io';
import 'dart:typed_data';

import 'package:betterbudget/data/backup.dart' show RestoreException;
import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/data/encryption.dart';
import 'package:betterbudget/data/keys.dart';
import 'package:betterbudget/data/ledger_file.dart';
import 'package:betterbudget/data/phone_ledger.dart';
import 'package:betterbudget/data/phone_own_ledger.dart';
import 'package:betterbudget/domain/ledger.dart' show AccountType;
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final today = DateTime(2026, 9, 16, 9, 30);

  late Directory root;
  late Uint8List folderLedger;
  late String computerLedgerId;
  final key = deriveDataKey(RecoveryKey.generate());

  setUp(() async {
    root = await Directory.systemTemp.createTemp('bb-own');
    addTearDown(() => root.delete(recursive: true));
    // The computer's ledger as it sits in the folder: demo rows, and a
    // change of the computer's own in its log.
    final file = File('${root.path}/folder/$ledgerFileName')
      ..createSync(recursive: true);
    final db = AppDatabase(
      NativeDatabase(file, setup: (raw) => applyCipherKey(raw, key)),
    );
    db.thisComputer = 'aaaa';
    await seedDemoIfEmpty(db, today);
    computerLedgerId = (await db.syncState()).ledger!;
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    await db.close();
    folderLedger = await file.readAsBytes();
  });

  PhoneOwnLedger own() =>
      PhoneOwnLedger(Directory('${root.path}/phone-own'), key);

  test('joining makes the phone\'s own ledger: the same rows and ledger, an '
      'empty log, and nothing left over', () async {
    final mine = own();
    expect(mine.exists, isFalse);
    expect(await mine.open('bbbb'), isNull);

    final db = await mine.join(folderLedger, 'bbbb');
    addTearDown(db.close);
    expect(mine.exists, isTrue);
    final names = {
      for (final a in (await db.loadLedger()).accounts.values) a.name,
    };
    expect(names, containsAll(['TDB Checking', 'Groceries']));
    final state = await db.syncState();
    expect(state.ledger, computerLedgerId);
    // Nothing of the computer's log is the phone's to publish.
    expect(await db.changesSince(0), isEmpty);
    expect(state.lastSeq, 0);
    // Only the ledger is left in its folder: no scratch copy.
    expect(
      mine.dir.listSync().map((e) => e.path.split('/').last).toSet(),
      everyElement(startsWith(ledgerFileName)),
    );
  });

  test('a change made on the phone is in its log, and it all survives a '
      'launch; joining again never writes over it', () async {
    final mine = own();
    var db = await mine.join(folderLedger, 'bbbb');
    final ledger = await db.loadLedger();
    final checking = ledger.accounts.values
        .singleWhere((a) => a.name == 'TDB Checking')
        .id;
    final groceries = ledger.accounts.values
        .singleWhere((a) => a.name == 'Groceries')
        .id;
    final before = ledger.txns.length;
    await db.postSimple(
      accountId: checking,
      date: today,
      today: today,
      payee: 'Nomin',
      counterAccountId: groceries,
      amount: -1250000,
    );
    final log = await db.changesSince(0);
    expect(log, isNotEmpty);
    expect(log.map((c) => c.tbl), contains('transactions'));
    expect(log.first.seq, 1);
    final last = (await db.syncState()).lastSeq;
    await db.close();

    // Another launch: the same ledger, the same log.
    db = (await mine.open('bbbb'))!;
    expect((await db.loadLedger()).txns.length, before + 1);
    expect((await db.syncState()).lastSeq, last);
    await db.close();

    // The folder's ledger is taken again by mistake: what the phone made stays.
    db = await mine.join(folderLedger, 'bbbb');
    addTearDown(db.close);
    expect((await db.loadLedger()).txns.length, before + 1);
    expect((await db.syncState()).lastSeq, last);
  });

  group('a person who starts on the phone (#534)', () {
    test('Start fresh makes an empty ledger that opens as this phone, and '
        'never writes over one there', () async {
      final mine = own();
      var db = await mine.create('bbbb');
      expect(mine.exists, isTrue);
      final ledger = await db.loadLedger();
      expect(ledger.accounts.values.where((a) => a.isBalanceSheet), isEmpty);
      expect(ledger.txns, isEmpty);
      // Opened with this key alone.
      expect(keyOpens(mine.file, key), isTrue);
      // Only the ledger in its folder: nothing half-made.
      expect(
        mine.dir.listSync().map((e) => e.path.split('/').last),
        everyElement(startsWith(ledgerFileName)),
      );
      expect(
        mine.dir.listSync().map((e) => e.path),
        isNot(contains(endsWith('.creating'))),
      );
      final checking = await db.addAccount(
        name: 'Khan Checking',
        type: AccountType.asset,
      );
      expect(checking, isPositive);
      await db.close();

      // Again by mistake: what is there stays.
      db = await mine.create('bbbb');
      addTearDown(db.close);
      expect(
        (await db.loadLedger()).accounts.values.map((a) => a.name),
        contains('Khan Checking'),
      );
    });

    test('Restore from backup puts the backup\'s rows in a new ledger; a file '
        'it refuses leaves nothing', () async {
      final backup = File('${root.path}/folder/$ledgerFileName');
      final mine = own();
      final db = await mine.restore(backup.path, 'bbbb', today);
      addTearDown(db.close);
      final names = {
        for (final a in (await db.loadLedger()).accounts.values) a.name,
      };
      expect(names, containsAll(['TDB Checking', 'Groceries']));
      expect(Directory('${mine.dir.path}.restoring').existsSync(), isFalse);
      // A ledger the phone has is never written over.
      await expectLater(
        mine.restore(backup.path, 'bbbb', today),
        throwsStateError,
      );

      // Another key: refused, nothing made.
      final other = PhoneOwnLedger(
        Directory('${root.path}/phone-other'),
        deriveDataKey(RecoveryKey.generate()),
      );
      await expectLater(
        other.restore(backup.path, 'bbbb', today),
        throwsA(isA<RestoreException>()),
      );
      expect(other.exists, isFalse);
      expect(Directory('${other.dir.path}.restoring').existsSync(), isFalse);

      // Not a backup at all.
      final junk = File('${root.path}/junk.betterbudget')
        ..writeAsStringSync('not a ledger');
      final third = PhoneOwnLedger(Directory('${root.path}/phone-third'), key);
      await expectLater(
        third.restore(junk.path, 'bbbb', today),
        throwsA(isA<RestoreException>()),
      );
      expect(third.exists, isFalse);
    });
  });

  test('another key is refused, and leaves no ledger and no scratch', () async {
    final other = PhoneOwnLedger(
      Directory('${root.path}/phone-other'),
      deriveDataKey(RecoveryKey.generate()),
    );
    await expectLater(
      other.join(folderLedger, 'bbbb'),
      throwsA(isA<WrongKeyException>()),
    );
    expect(other.exists, isFalse);
    expect(other.dir.listSync(), isEmpty);
  });
}
