// The phone as a member of the folder (ADR 0005, #526 piece 3): its own ledger
// takes in the computers' changes through their change files and writes its
// own, and never writes the folder's whole ledger.
import 'dart:io';

import 'package:betterbudget/data/backup.dart';
import 'package:betterbudget/data/change_file.dart';
import 'package:betterbudget/data/cloud_folder.dart';
import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/data/encryption.dart';
import 'package:betterbudget/data/folder_io.dart';
import 'package:betterbudget/data/keys.dart';
import 'package:betterbudget/data/ledger_file.dart';
import 'package:betterbudget/data/phone_sync.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _MacAccess extends FolderAccess {
  const _MacAccess();
  @override
  Future<String?> derivedComputerId() async => 'aaaa';
  @override
  Future<String?> remember(String path) async => null;
  @override
  Future<String> computerName() async => 'The desk Mac';
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final key = deriveDataKey(RecoveryKey.generate());
  final monday = DateTime(2026, 10, 5, 21, 40);
  final tuesday = DateTime(2026, 10, 6, 8, 15);
  late Directory root;
  late Directory drive;
  late AppDatabase macDb;
  late CloudFolder mac;
  late PhoneSync phone;

  File folderLedger() => File('${drive.path}/$ledgerFileName');

  Future<void> spend(String payee) async {
    final ledger = await macDb.loadLedger();
    int id(String name) =>
        ledger.accounts.values.singleWhere((a) => a.name == name).id;
    await macDb.postSimple(
      accountId: id('TDB Checking'),
      date: monday,
      today: monday,
      payee: payee,
      counterAccountId: id('Groceries'),
      amount: -1250000,
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('bb-phone-sync');
    drive = await Directory('${root.path}/My Drive/BetterBudget').create(
      recursive: true,
    );
    final file = File('${root.path}/mac/$ledgerFileName')
      ..createSync(recursive: true);
    macDb = AppDatabase(
      NativeDatabase(file, setup: (raw) => applyCipherKey(raw, key)),
    );
    macDb.thisComputer = 'aaaa';
    await seedDemoIfEmpty(macDb, monday);
    mac = CloudFolder(
      Backups(macDb, dataKey: key),
      access: const _MacAccess(),
    );
    await mac.keepIn(drive.path, monday);
    phone = PhoneSync(
      dir: await Directory('${root.path}/phone').create(),
      dataKey: key,
      device: 'bbbb',
      io: const DirectoryFolderIo(),
    );
    await phone.join(await folderLedger().readAsBytes());
  });

  tearDown(() async {
    await phone.close();
    mac.dispose();
    await macDb.close();
    await root.delete(recursive: true);
  });

  Future<List<String?>> payees() async => [
    for (final t in (await phone.db!.loadLedger()).txns) t.payee,
  ];

  test('a phone with a ledger of its own is joined, and one without is not', () {
    expect(phone.joined, isTrue);
    expect(
      PhoneSync(
        dir: Directory('${root.path}/other'),
        dataKey: key,
        device: 'cccc',
      ).joined,
      isFalse,
    );
  });

  test('a look brings in what a computer did, and writes the phone’s own '
      'change file, never the folder’s ledger', () async {
    await spend('Nomin');
    await spend('E-Mart');
    expect(await mac.check(monday), FolderStanding.ok);
    final macsLedger = await folderLedger().readAsBytes();
    expect(await payees(), isNot(contains('Nomin')));

    final snapshot = await phone.look(drive.path, tuesday);
    expect(await payees(), containsAll(['Nomin', 'E-Mart']));
    // The figures are the ledger's: a look that went through is as new as now.
    expect(snapshot.madeAt, tuesday);
    // The phone's own file is there, and the folder's ledger isn't touched.
    expect(
      File('${drive.path}/${changeFileName('bbbb')}').existsSync(),
      isTrue,
    );
    expect(await folderLedger().readAsBytes(), macsLedger);
    // And no copy of a ledger is kept for restoring from.
    final backups = Directory('${root.path}/phone/own/Backups');
    expect(
      backups.existsSync() ? backups.listSync() : const <FileSystemEntity>[],
      isEmpty,
    );

    // The Mac, looking, finds the phone's file and has nothing to take.
    expect(await mac.check(tuesday), FolderStanding.ok);
  });

  test('a look with nothing new changes nothing, and again later brings in '
      'the next', () async {
    await phone.look(drive.path, monday);
    final before = await payees();
    await phone.look(drive.path, monday);
    expect(await payees(), before);

    await spend('Nomin');
    await mac.check(tuesday);
    await phone.look(drive.path, tuesday);
    expect(await payees(), contains('Nomin'));
  });

  test('a folder that can’t be reached leaves the figures up, as old as the '
      'last look that went through', () async {
    await phone.look(drive.path, monday);
    await spend('Nomin');
    await mac.check(monday);
    // The folder goes away: no signal.
    await drive.rename('${root.path}/My Drive/gone');
    final snapshot = await phone.look(drive.path, tuesday);
    expect(snapshot.madeAt, monday);
    expect(await payees(), isNot(contains('Nomin')));
    await Directory('${root.path}/My Drive/gone').rename(drive.path);
    final again = await phone.look(drive.path, tuesday);
    expect(again.madeAt, tuesday);
    expect(await payees(), contains('Nomin'));
  });

  test('the phone is the same member on the next launch: its ledger, its '
      'id and what it applied are kept', () async {
    await spend('Nomin');
    await mac.check(monday);
    await phone.look(drive.path, monday);
    await phone.close();

    phone = PhoneSync(
      dir: Directory('${root.path}/phone'),
      dataKey: key,
      device: 'bbbb',
      io: const DirectoryFolderIo(),
    );
    expect(phone.joined, isTrue);
    await spend('E-Mart');
    await mac.check(tuesday);
    await phone.look(drive.path, tuesday);
    expect(await payees(), containsAll(['Nomin', 'E-Mart']));
    // Nothing was taken twice.
    expect((await payees()).where((p) => p == 'Nomin'), hasLength(1));
  });

  test('a folder whose ledger is still arriving is not a look that went '
      'through: the figures keep their age', () async {
    await phone.look(drive.path, monday);
    // A phone that hasn't been on the folder yet (a new launch) finds half a
    // file there.
    await phone.close();
    await folderLedger().writeAsBytes([1, 2, 3]);
    phone = PhoneSync(
      dir: Directory('${root.path}/phone'),
      dataKey: key,
      device: 'bbbb',
      io: const DirectoryFolderIo(),
    );
    final snapshot = await phone.look(drive.path, tuesday);
    expect(snapshot.madeAt, monday);
  });

  test('giving the ledger up leaves nothing, and nothing reopens it', () async {
    await phone.look(drive.path, monday);
    await phone.leave();
    expect(Directory('${root.path}/phone/own').existsSync(), isFalse);
    await expectLater(phone.look(drive.path, tuesday), throwsStateError);
    expect(Directory('${root.path}/phone/own').existsSync(), isFalse);
  });
}
