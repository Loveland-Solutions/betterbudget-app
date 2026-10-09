// More than one computer on one ledger (ADR 0005, "Never write blind"): the
// ledger in the folder is never written over unless everything in it is
// already in the ledger of the computer writing.
import 'dart:convert';
import 'dart:io';

import 'package:betterbudget/data/backup.dart';
import 'package:betterbudget/data/cloud_folder.dart';
import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/data/ledger_seal.dart';
import 'package:betterbudget/domain/sync.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

class _Access extends FolderAccess {
  _Access(this.name);
  final String name;

  @override
  Future<String?> remember(String path) async => null;

  @override
  Future<String> computerName() async => name;
}

/// One computer: its own ledger file, backups and folder setting.
class _Computer {
  _Computer(this.dir, this.name)
    : db = AppDatabase(NativeDatabase(File('${dir.path}/Ledger.betterbudget')));

  final Directory dir;
  final String name;
  final AppDatabase db;
  late final backups = Backups(db);
  late final cloud = CloudFolder(backups, access: _Access(name));

  Future<int> account(String name) async => (await db.loadLedger())
      .accounts
      .values
      .singleWhere((a) => a.name == name)
      .id;

  Future<void> spend(String payee, DateTime on) async => db.postSimple(
    accountId: await account('TDB Checking'),
    date: on,
    today: on,
    payee: payee,
    counterAccountId: await account('Groceries'),
    amount: -1250000,
  );

  Future<List<String>> payees() async => [
    for (final t in (await db.loadLedger()).txns) ?t.payee,
  ];

  /// Takes the folder's ledger in, as the screen does when it is newer.
  Future<void> open(DateTime now) async {
    final candidate = await backups.inspect(cloud.theirs!.copy.path, now);
    await backups.restore(candidate, now, fromFolder: true);
  }

  Future<void> close() async {
    cloud.dispose();
    await db.close();
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('which way the ledger goes', () {
    FolderMove move({
      bool identical = false,
      bool changedHere = false,
      bool theirsSealed = true,
      Counters mine = const {},
      Counters theirs = const {},
      bool theirsIsMyOldWrite = false,
    }) => decideFolderMove(
      identical: identical,
      changedHere: changedHere,
      theirsSealed: theirsSealed,
      mine: mine,
      theirs: theirs,
      theirsIsMyOldWrite: theirsIsMyOldWrite,
    );

    test('counts are compared computer by computer', () {
      expect(compareCounters({'a': 2}, {'a': 2}), Standing.same);
      expect(compareCounters({'a': 3}, {'a': 2}), Standing.mineAhead);
      expect(compareCounters({'a': 2}, {'a': 2, 'b': 1}), Standing.theirsAhead);
      expect(compareCounters({'a': 3}, {'a': 2, 'b': 1}), Standing.apart);
      expect(compareCounters({}, {}), Standing.same);
    });

    test('the folder holds my last write: my changes are written', () {
      expect(
        move(changedHere: true, mine: {'a': 2}, theirs: {'a': 2}),
        FolderMove.write,
      );
    });

    test('the folder is ahead and nothing changed here: it is taken in', () {
      expect(move(mine: {'a': 2}, theirs: {'a': 2, 'b': 1}), FolderMove.take);
    });

    test(
      'the folder is ahead and this was changed too: nothing is written',
      () {
        expect(
          move(changedHere: true, mine: {'a': 2}, theirs: {'a': 2, 'b': 1}),
          FolderMove.ask,
        );
      },
    );

    test('each has a write the other lacks: nothing is written', () {
      expect(move(mine: {'a': 3}, theirs: {'a': 2, 'b': 1}), FolderMove.ask);
    });

    test('the folder went back to an older one of mine: written again', () {
      expect(move(mine: {'a': 3}, theirs: {'a': 2}), FolderMove.write);
    });

    test('changed by a build that keeps no counts: nothing is written', () {
      expect(
        move(theirsSealed: false, mine: {'a': 2}, theirs: {'a': 2}),
        FolderMove.ask,
      );
      // Unless it is this computer's own file from before it kept counts.
      expect(
        move(theirsSealed: false, changedHere: true, theirsIsMyOldWrite: true),
        FolderMove.write,
      );
    });

    test('the same contents are never asked about', () {
      expect(
        move(identical: true, mine: {'a': 2}, theirs: {'a': 2}),
        FolderMove.nothing,
      );
      // Sealed and ahead: adopted as it is, with nothing written.
      expect(
        move(identical: true, mine: {'a': 2}, theirs: {'a': 2, 'b': 3}),
        FolderMove.nothing,
      );
      // Written once more, to leave the folder's sealed with both counts.
      expect(move(identical: true, theirsSealed: false), FolderMove.write);
      expect(
        move(identical: true, mine: {'a': 1}, theirs: {'b': 1}),
        FolderMove.write,
      );
    });

    test('same counts, unchanged here, yet different: asked, not written', () {
      // Two computers with one id (a cloned disk).
      expect(move(mine: {'a': 2}, theirs: {'a': 2}), FolderMove.ask);
    });
  });

  group('two computers and one folder', () {
    final monday = DateTime(2026, 10, 5, 21, 40);
    final tuesday = DateTime(2026, 10, 6, 8, 15);
    late Directory root;
    late Directory drive;
    late _Computer mac;
    late _Computer laptop;

    File folderLedger() => File('${drive.path}/${CloudFolder.fileName}');

    setUp(() async {
      root = await Directory.systemTemp.createTemp('bb-two');
      drive = await Directory('${root.path}/My Drive/BetterBudget')
          .create(recursive: true);
      mac = _Computer(
        await Directory('${root.path}/mac').create(),
        'The desk Mac',
      );
      await seedDemoIfEmpty(mac.db, monday);
      await mac.cloud.keepIn(drive.path, monday);

      // The laptop gets the ledger the way a second computer does: the
      // folder's file, restored into its own.
      laptop = _Computer(
        await Directory('${root.path}/laptop').create(),
        'The laptop',
      );
      await seedDemoIfEmpty(laptop.db, monday);
      final candidate = await laptop.backups.inspect(
        folderLedger().path,
        monday,
      );
      await laptop.backups.restore(candidate, monday, fromFolder: true);
    });

    tearDown(() async {
      await mac.close();
      await laptop.close();
      await root.delete(recursive: true);
    });

    test('a second computer that picks the folder writes nothing', () async {
      final before = await folderLedger().readAsBytes();
      await laptop.cloud.keepIn(drive.path, tuesday);
      expect(laptop.cloud.value.standing, FolderStanding.ok);
      expect(await folderLedger().readAsBytes(), before);
    });

    test('a stale computer with a change of its own doesn’t write over a week '
        'of spending', () async {
      await laptop.cloud.keepIn(drive.path, monday);

      // Monday, on the Mac.
      await mac.spend('Nomin', monday);
      await mac.spend('E-Mart', monday);
      expect(await mac.cloud.check(monday), FolderStanding.ok);
      final mondays = await folderLedger().readAsBytes();

      // Tuesday the laptop, which hasn't looked since, changes something.
      await laptop.db.renameAccount(
        await laptop.account('Cash wallet'),
        'Wallet',
      );
      laptop.cloud.ledgerChanged(() => tuesday);
      await laptop.cloud.flush();

      expect(laptop.cloud.value.standing, FolderStanding.apart);
      expect(await folderLedger().readAsBytes(), mondays);
      expect(await laptop.payees(), isNot(contains('Nomin')));
      // And the Mac, looking again, sees its own file and leaves it.
      expect(await mac.cloud.check(tuesday), FolderStanding.ok);
      expect(await folderLedger().readAsBytes(), mondays);
    });

    test('a computer that changed nothing finds the folder’s newer, takes it '
        'in, and then writes nothing', () async {
      await laptop.cloud.keepIn(drive.path, monday);
      await mac.spend('Nomin', monday);
      await mac.cloud.check(monday);
      final mondays = await folderLedger().readAsBytes();

      expect(await laptop.cloud.check(tuesday), FolderStanding.newer);
      expect(await folderLedger().readAsBytes(), mondays);
      final theirs = laptop.cloud.theirs!.look;
      expect(theirs.savedByName, 'The desk Mac');
      expect(theirs.savedAt, monday);

      await laptop.open(tuesday);
      expect(await laptop.payees(), contains('Nomin'));
      expect(await laptop.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      expect(await folderLedger().readAsBytes(), mondays);

      // The laptop's next change is written, and the Mac takes that in.
      await laptop.spend('Shangri-La', tuesday);
      expect(await laptop.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      expect(await mac.cloud.check(tuesday), FolderStanding.newer);
      await mac.open(tuesday);
      expect(await mac.payees(), containsAll(['Nomin', 'Shangri-La']));
      expect(await mac.cloud.check(tuesday, fresh: true), FolderStanding.ok);
    });

    test('the one put back after the folder’s was taken in is written, not '
        'taken for an old one', () async {
      await laptop.cloud.keepIn(drive.path, monday);
      await mac.spend('Nomin', monday);
      await mac.cloud.check(monday);
      await laptop.cloud.check(tuesday);
      final candidate = await laptop.backups.inspect(
        laptop.cloud.theirs!.copy.path,
        tuesday,
      );
      final done = await laptop.backups.restore(
        candidate,
        tuesday,
        fromFolder: true,
      );
      // Undo.
      await laptop.backups.replaceWith(done.before, tuesday);
      expect(await laptop.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      expect(await laptop.payees(), isNot(contains('Nomin')));
      final inFolder = await lookAtLedger(folderLedger(), null);
      expect(inFolder.savedByName, 'The laptop');
      // The Mac has nothing of its own since: it takes the laptop's.
      expect(await mac.cloud.check(tuesday), FolderStanding.newer);
    });

    test(
      'a backup restored on one computer is written to the folder',
      () async {
        final saved = File('${root.path}/Earlier.betterbudget');
        await mac.backups.saveTo(saved.path, monday);
        await mac.spend('Nomin', monday);
        await mac.cloud.check(monday);

        final candidate = await mac.backups.inspect(saved.path, tuesday);
        await mac.backups.restore(candidate, tuesday);
        expect(await mac.payees(), isNot(contains('Nomin')));
        expect(await mac.cloud.check(tuesday, fresh: true), FolderStanding.ok);
        final inFolder = AppDatabase(
          NativeDatabase(
            File(
              (await folderLedger().copy('${root.path}/look.betterbudget'))
                  .path,
            ),
          ),
        );
        addTearDown(inFolder.close);
        expect([
          for (final t in (await inFolder.loadLedger()).txns) t.payee,
        ], isNot(contains('Nomin')));
      },
    );

    test(
      '“Erase everything and start over” is written to the folder',
      () async {
        await mac.db.startNewLedger(tuesday, keepCategories: false);
        expect(await mac.cloud.check(tuesday, fresh: true), FolderStanding.ok);
        expect((await lookAtLedger(folderLedger(), null)).sealed, isTrue);
      },
    );

    test('a change made by a build that keeps no counts is noticed', () async {
      // An older BetterBudget on a third computer: it opens the folder's
      // file as its own and saves it back with a change.
      final old = File('${root.path}/old.betterbudget');
      await folderLedger().copy(old.path);
      final third = AppDatabase(NativeDatabase(old));
      await third.renameAccount(
        (await third.loadLedger()).accounts.values
            .singleWhere((a) => a.name == 'Cash wallet')
            .id,
        'Wallet',
      );
      final written = File('${root.path}/written.betterbudget');
      await third.copyTo(written.path);
      await third.close();
      await written.copy(folderLedger().path);
      final theirs = await folderLedger().readAsBytes();

      expect(await mac.cloud.check(tuesday), FolderStanding.apart);
      expect(await folderLedger().readAsBytes(), theirs);
    });

    test(
      'a ledger that can’t be read is waited for, not written over',
      () async {
        await folderLedger().writeAsString('half of a ledger, still arriving');
        final theirs = await folderLedger().readAsBytes();
        await mac.spend('Nomin', tuesday);
        expect(
          await mac.cloud.check(tuesday, fresh: true),
          FolderStanding.arriving,
        );
        expect(await folderLedger().readAsBytes(), theirs);
      },
    );

    test('this computer’s own write, cut short, is written again', () async {
      final settings = File('${mac.dir.path}/cloud-folder');
      final saved = jsonDecode(await settings.readAsString()) as Map;
      await settings.writeAsString(jsonEncode({...saved, 'writing': true}));
      await folderLedger().writeAsString('half of a ledger');

      final again = CloudFolder(mac.backups, access: _Access('The desk Mac'));
      await again.load(tuesday);
      expect(again.value.standing, FolderStanding.ok);
      expect((await lookAtLedger(folderLedger(), null)).sealed, isTrue);
      again.dispose();
    });

    test('a ledger saved by a newer BetterBudget is left alone', () async {
      final raw = sqlite3.open(folderLedger().path);
      raw.execute('PRAGMA user_version = ${mac.db.schemaVersion + 1}');
      raw.close();
      final theirs = await folderLedger().readAsBytes();
      await mac.spend('Nomin', tuesday);
      expect(
        await mac.cloud.check(tuesday, fresh: true),
        FolderStanding.newerApp,
      );
      expect(await folderLedger().readAsBytes(), theirs);
    });

    test('picking a folder with a ledger this key doesn’t open: refused, or '
        'replaced with the old one kept', () async {
      final other = await Directory('${root.path}/Dropbox/Money')
          .create(recursive: true);
      final theirs = File('${other.path}/${CloudFolder.fileName}');
      await theirs.writeAsString('someone else’s ledger');

      await expectLater(
        mac.cloud.keepIn(other.path, tuesday),
        throwsA(isA<FolderLedgerUnreadable>()),
      );
      expect(await theirs.readAsString(), 'someone else’s ledger');
      expect(mac.cloud.value.path, drive.path);

      final kept = await mac.cloud.keepIn(
        other.path,
        tuesday,
        replaceUnreadable: true,
      );
      expect(await kept!.readAsString(), 'someone else’s ledger');
      expect(kept.path, contains('from-folder-'));
      expect((await lookAtLedger(theirs, null)).sealed, isTrue);
    });

    test(
      'picking a folder that holds a different ledger writes over nothing',
      () async {
        // The laptop made changes of its own before it ever had the folder.
        await laptop.spend('Shangri-La', tuesday);
        await mac.spend('Nomin', monday);
        await mac.cloud.check(monday);
        final mondays = await folderLedger().readAsBytes();

        await laptop.cloud.keepIn(drive.path, tuesday);
        expect(laptop.cloud.value.standing, FolderStanding.apart);
        expect(await folderLedger().readAsBytes(), mondays);
      },
    );

    test(
      '“Use this computer’s” keeps the folder’s first, and undoes',
      () async {
        await laptop.cloud.keepIn(drive.path, monday);
        await mac.spend('Nomin', monday);
        await mac.cloud.check(monday);
        await laptop.spend('Shangri-La', tuesday);
        expect(
          await laptop.cloud.check(tuesday, fresh: true),
          FolderStanding.apart,
        );
        final mondays = await folderLedger().readAsBytes();

        final kept = await laptop.cloud.keepMine(tuesday);
        expect(laptop.cloud.value.standing, FolderStanding.ok);
        expect(await kept.theirs!.readAsBytes(), mondays);
        // The Mac changed nothing since its write: the laptop's is now ahead
        // of it, and it takes it in.
        expect(await mac.cloud.check(tuesday), FolderStanding.newer);

        await laptop.cloud.undoKeepMine(kept, tuesday);
        expect(await folderLedger().readAsBytes(), mondays);
        expect(laptop.cloud.value.standing, FolderStanding.apart);
        expect(await mac.cloud.check(tuesday), FolderStanding.ok);
        // Still asked about after a restart, and the laptop's count hasn't
        // gone down: chosen again, it is a new count, not one used before.
        final again = CloudFolder(
          laptop.backups,
          access: _Access('The laptop'),
        );
        await again.load(tuesday);
        expect(again.value.standing, FolderStanding.apart);
        again.dispose();
        int total(Counters c) => c.values.fold(0, (a, b) => a + b);
        final before = (await laptop.db.sealState()).computers.counters;
        await laptop.spend('Nomin 2', tuesday);
        await laptop.cloud.keepMine(tuesday);
        final after = (await laptop.db.sealState()).computers.counters;
        expect(total(after), greaterThan(total(before)));
      },
    );

    test('the choice isn’t undone once another computer has written', () async {
      await laptop.cloud.keepIn(drive.path, monday);
      await mac.spend('Nomin', monday);
      await mac.cloud.check(monday);
      await laptop.spend('Shangri-La', tuesday);
      await laptop.cloud.check(tuesday, fresh: true);
      final kept = await laptop.cloud.keepMine(tuesday);
      // The Mac takes the laptop's in and goes on.
      await mac.cloud.check(tuesday);
      await mac.open(tuesday);
      await mac.spend('E-Mart', tuesday);
      expect(await mac.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      final macs = await folderLedger().readAsBytes();

      await expectLater(
        laptop.cloud.undoKeepMine(kept, tuesday),
        throwsA(isA<FolderMovedOn>()),
      );
      expect(await folderLedger().readAsBytes(), macs);
    });

    test('the same rows with different counts settle, and nobody goes on '
        'writing', () async {
      await laptop.cloud.keepIn(drive.path, monday);
      // The laptop changes a thing and changes it back: two writes, and
      // the same rows the Mac has.
      await laptop.db.setPreference('budget.view', 'pay');
      await laptop.cloud.check(tuesday, fresh: true);
      await laptop.db.setPreference('budget.view', null);
      await laptop.cloud.check(tuesday, fresh: true);

      var writes = 0;
      var last = (await folderLedger().readAsBytes()).toString();
      for (var round = 0; round < 4; round++) {
        for (final c in [mac, laptop]) {
          expect(await c.cloud.check(tuesday, fresh: true), FolderStanding.ok);
          final now = (await folderLedger().readAsBytes()).toString();
          if (now != last) writes++;
          last = now;
        }
      }
      expect(writes, 0);
      expect(
        (await mac.db.sealState()).computers.counters,
        (await laptop.db.sealState()).computers.counters,
      );
    });

    test('a write nobody announced to the folder code is still seen', () async {
      // As the app's own scheduling at launch: no ledgerChanged, not fresh.
      expect(await mac.cloud.check(tuesday), FolderStanding.ok);
      await mac.spend('Nomin', tuesday);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await mac.cloud.check(tuesday), FolderStanding.ok);
      final look = AppDatabase(
        NativeDatabase(
          File(
            (await folderLedger().copy('${root.path}/look.betterbudget')).path,
          ),
        ),
      );
      addTearDown(look.close);
      expect([
        for (final t in (await look.loadLedger()).txns) t.payee,
      ], contains('Nomin'));
    });

    test('a click while the folder’s is being read stops the take', () async {
      await laptop.cloud.keepIn(drive.path, monday);
      await mac.spend('Nomin', monday);
      await mac.cloud.check(monday);
      expect(
        await laptop.cloud.check(tuesday, fresh: true),
        FolderStanding.newer,
      );
      final unchanged = laptop.cloud.mineDigest!;
      final candidate = await laptop.backups.inspect(
        laptop.cloud.theirs!.copy.path,
        tuesday,
      );
      await laptop.spend('Shangri-La', tuesday);
      await expectLater(
        laptop.backups.restore(
          candidate,
          tuesday,
          fromFolder: true,
          onlyIfDigest: unchanged,
        ),
        throwsA(isA<ChangedSinceException>()),
      );
      expect(await laptop.payees(), contains('Shangri-La'));
      expect(
        await laptop.cloud.check(tuesday, fresh: true),
        FolderStanding.apart,
      );
    });

    test('a folder that was only away is read again when it is back', () async {
      await mac.spend('Nomin', tuesday);
      await mac.cloud.check(tuesday, fresh: true);
      final whole = await folderLedger().readAsBytes();
      final stat = folderLedger().statSync();
      await folderLedger().writeAsString('half');
      expect(
        await mac.cloud.check(tuesday, fresh: true),
        FolderStanding.arriving,
      );
      expect(mac.cloud.value.held, isFalse);
      // Minutes later it still can't be read: that is said out loud.
      await mac.cloud.check(tuesday.add(const Duration(minutes: 5)));
      expect(mac.cloud.value.held, isTrue);
      await folderLedger().writeAsBytes(whole);
      folderLedger().setLastModifiedSync(stat.modified);
      expect(await mac.cloud.check(tuesday), FolderStanding.ok);
      expect(mac.cloud.value.held, isFalse);
    });

    test('moving it back waits for a write under way', () async {
      await mac.spend('Nomin', tuesday);
      final writing = mac.cloud.check(tuesday, fresh: true);
      await mac.cloud.stop();
      expect(await writing, FolderStanding.ok);
      expect(mac.cloud.value.path, isNull);
      final inFolder = await lookAtLedger(folderLedger(), null);
      expect(inFolder.sealed, isTrue);
    });

    test('nothing but the ledger is left in the folder', () async {
      await mac.spend('Nomin', tuesday);
      await mac.cloud.check(tuesday, fresh: true);
      await laptop.cloud.keepIn(drive.path, tuesday);
      expect(drive.listSync().map((f) => f.path), [folderLedger().path]);
    });
  });

  group('the first run of a build that keeps counts', () {
    final today = DateTime(2026, 10, 9, 10);
    late Directory root;
    late Directory drive;
    late _Computer mac;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('bb-first');
      drive = await Directory('${root.path}/My Drive/BetterBudget')
          .create(recursive: true);
      mac = _Computer(
        await Directory('${root.path}/mac').create(),
        'The desk Mac',
      );
      await seedDemoIfEmpty(mac.db, today);
      // As the build before wrote it: the ledger, with no counts or seal.
      await mac.db.copyTo('${drive.path}/${CloudFolder.fileName}');
    });

    tearDown(() async {
      await mac.close();
      await root.delete(recursive: true);
    });

    Future<void> remembered(DateTime copiedAt) =>
        File('${mac.dir.path}/cloud-folder').writeAsString(
          jsonEncode({
            'path': drive.path,
            'copiedAt': copiedAt.toIso8601String(),
          }),
        );

    test('its own earlier file is sealed where it is', () async {
      await remembered(today);
      await mac.cloud.load(today);
      expect(mac.cloud.value.standing, FolderStanding.ok);
      final look = await lookAtLedger(
        File('${drive.path}/${CloudFolder.fileName}'),
        null,
      );
      expect(look.sealed, isTrue);
      expect(look.computers.counters.values, [1]);
    });

    test('its own earlier file, one change behind, is written over', () async {
      final file = File('${drive.path}/${CloudFolder.fileName}');
      await remembered(file.statSync().modified);
      await mac.spend('Nomin', today);
      await mac.cloud.load(today);
      expect(mac.cloud.value.standing, FolderStanding.ok);
      expect((await lookAtLedger(file, null)).sealed, isTrue);
    });

    test('a file some other computer put there since is asked about', () async {
      final file = File('${drive.path}/${CloudFolder.fileName}');
      await remembered(
        file.statSync().modified.subtract(const Duration(days: 1)),
      );
      await mac.spend('Nomin', today);
      final theirs = await file.readAsBytes();
      await mac.cloud.load(today);
      expect(mac.cloud.value.standing, FolderStanding.apart);
      expect(await file.readAsBytes(), theirs);
    });
  });

  group('the digest', () {
    late Directory root;
    late AppDatabase db;
    final today = DateTime(2026, 10, 9);

    setUp(() async {
      root = await Directory.systemTemp.createTemp('bb-digest');
      db = AppDatabase(NativeDatabase(File('${root.path}/a.betterbudget')));
      await seedDemoIfEmpty(db, today);
    });
    tearDown(() async {
      await db.close();
      await root.delete(recursive: true);
    });

    test(
      'a copy gives the same digest, and the counts aren’t part of it',
      () async {
        final before = (await db.sealState()).digest;
        await db.sealAs('abc', name: 'A Mac', at: today);
        final sealed = await db.sealState();
        expect(sealed.digest, before);
        expect(sealed.seal, before);
        expect(sealed.computers.counters, {'abc': 1});
        final copy = File('${root.path}/copy.betterbudget');
        await db.copyTo(copy.path);
        final look = await lookAtLedger(copy, null);
        expect(look.digest, before);
        expect(look.sealed, isTrue);
        expect(look.savedByName, 'A Mac');
      },
    );

    test(
      'any change gives another, and sealing again is a new count',
      () async {
        await db.sealAs('abc', at: today);
        final sealed = await db.sealState();
        await db.setPreference('budget.view', 'month');
        final changed = await db.sealState();
        expect(changed.digest, isNot(sealed.digest));
        expect(changed.seal, sealed.seal);
        // Unchanged, sealing again is nothing; changed, it counts.
        await db.sealAs('abc', at: today);
        expect((await db.sealState()).computers.counters, {'abc': 2});
        await db.sealAs('abc', at: today);
        expect((await db.sealState()).computers.counters, {'abc': 2});
        // Over another computer's counts, it comes out ahead of them.
        await db.sealAs('abc', at: today, over: {'xyz': 4});
        expect((await db.sealState()).computers.counters, {'abc': 3, 'xyz': 4});
      },
    );
  });
}
