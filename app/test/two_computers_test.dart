// More than one computer on one ledger (ADR 0005, "Never write blind"): the
// ledger in the folder is never written over unless everything in it is
// already in the ledger of the computer writing.
import 'dart:convert';
import 'dart:io';

import 'package:betterbudget/data/backup.dart';
import 'package:betterbudget/data/change_file.dart';
import 'package:betterbudget/data/cloud_folder.dart';
import 'package:betterbudget/domain/combine.dart' show AskKind, Pick;
import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/data/ledger_seal.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/pay.dart';
import 'package:betterbudget/domain/payee_rules.dart';
import 'package:betterbudget/domain/phone.dart';
import 'package:betterbudget/domain/sync.dart';
import 'package:betterbudget/import/mapping.dart';
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
        'of spending: it brings the week in, and writes both', () async {
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

      // Nothing is written, and nothing brought in, until the screen is
      // free to.
      expect(laptop.cloud.value.standing, FolderStanding.combine);
      expect(await folderLedger().readAsBytes(), mondays);
      expect(await laptop.payees(), isNot(contains('Nomin')));
      // And the Mac, looking again, finds the laptop's change in the
      // laptop's file; the folder's ledger is as the Mac wrote it.
      expect(await mac.cloud.check(tuesday), FolderStanding.combine);
      expect(await folderLedger().readAsBytes(), mondays);

      final done = (await laptop.cloud.bringIn(tuesday))!;
      expect(done.transactions, 2);
      expect(done.others, 0);
      expect(done.from.savedByName, 'The desk Mac');
      expect(await laptop.payees(), containsAll(['Nomin', 'E-Mart']));
      await laptop.account('Wallet');
      // Both go to the folder, and the Mac brings in the new name.
      expect(await laptop.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      expect(await folderLedger().readAsBytes(), isNot(mondays));
      final back = (await mac.cloud.bringIn(tuesday))!;
      expect(back.transactions, 0);
      expect(back.others, 1);
      expect(back.from.savedByName, 'The laptop');
      await mac.account('Wallet');
      expect(await mac.payees(), containsAll(['Nomin', 'E-Mart']));
      expect(await mac.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      // The same rows on both, to the last one.
      expect(
        (await mac.db.sealState()).digest,
        (await laptop.db.sealState()).digest,
      );
    });

    test('a computer that changed nothing finds the folder’s newer, takes it '
        'in, and then writes nothing', () async {
      await laptop.cloud.keepIn(drive.path, monday);
      await mac.spend('Nomin', monday);
      await mac.cloud.check(monday);
      final mondays = await folderLedger().readAsBytes();

      // The Mac's change is in the Mac's file: brought in, not the whole
      // ledger taken.
      expect(await laptop.cloud.check(tuesday), FolderStanding.combine);
      expect(await folderLedger().readAsBytes(), mondays);
      final theirs = laptop.cloud.theirs!.look;
      expect(theirs.savedByName, 'The desk Mac');
      expect(theirs.savedAt, monday);

      final done = (await laptop.cloud.bringIn(tuesday))!;
      expect(done.transactions, 1);
      expect(done.from.savedByName, 'The desk Mac');
      expect(await laptop.payees(), contains('Nomin'));
      // Nothing of its own: the folder's ledger is left as it is.
      expect(await laptop.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      expect(await folderLedger().readAsBytes(), mondays);

      // The laptop's next change is written, and the Mac brings it in.
      await laptop.spend('Shangri-La', tuesday);
      expect(await laptop.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      expect(await mac.cloud.check(tuesday), FolderStanding.combine);
      expect((await mac.cloud.bringIn(tuesday))!.transactions, 1);
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
      // Not taken for an old one: the Mac's change comes in on top of it,
      // and the laptop writes the folder's ledger.
      expect(
        await laptop.cloud.check(tuesday, fresh: true),
        FolderStanding.combine,
      );
      expect(await laptop.payees(), isNot(contains('Nomin')));
      await laptop.cloud.bringIn(tuesday);
      expect(await laptop.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      final inFolder = await lookAtLedger(folderLedger(), null);
      expect(inFolder.savedByName, 'The laptop');
      // A ledger put back whole is a whole-ledger act: until step 5 makes
      // it a batch of its own, the Mac is asked.
      expect(await mac.cloud.check(tuesday), FolderStanding.apart);
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

    test('picking a folder whose ledger moved on writes over nothing: the '
        'changes are brought in', () async {
      // The laptop made changes of its own before it ever had the folder.
      await laptop.spend('Shangri-La', tuesday);
      await mac.spend('Nomin', monday);
      await mac.cloud.check(monday);
      final mondays = await folderLedger().readAsBytes();

      await laptop.cloud.keepIn(drive.path, tuesday);
      expect(laptop.cloud.value.standing, FolderStanding.combine);
      expect(await folderLedger().readAsBytes(), mondays);
    });

    test('a folder that holds another ledger is left alone', () async {
      await laptop.cloud.keepIn(drive.path, monday);
      // A new ledger here: its own id, nothing in common.
      await laptop.db.startNewLedger(tuesday, keepCategories: false);
      await mac.spend('Nomin', monday);
      await mac.cloud.check(monday);
      final mondays = await folderLedger().readAsBytes();
      expect(
        await laptop.cloud.check(tuesday, fresh: true),
        FolderStanding.apart,
      );
      expect(await folderLedger().readAsBytes(), mondays);
      expect(await laptop.payees(), isNot(contains('Nomin')));
    });

    test(
      '“Use this computer’s” keeps the folder’s first, and undoes',
      () async {
        await laptop.cloud.keepIn(drive.path, monday);
        // One account, given two names: that can't be combined.
        await mac.db.renameAccount(await mac.account('Cash wallet'), 'Pocket');
        await mac.cloud.check(monday);
        await laptop.db.renameAccount(
          await laptop.account('Cash wallet'),
          'Wallet',
        );
        expect(
          await laptop.cloud.check(tuesday, fresh: true),
          FolderStanding.apart,
        );
        final mondays = await folderLedger().readAsBytes();

        final kept = await laptop.cloud.keepMine(tuesday);
        expect(laptop.cloud.value.standing, FolderStanding.ok);
        expect(await kept.theirs!.readAsBytes(), mondays);
        // The choice went out as the laptop's changes: the Mac takes it,
        // and isn't asked.
        expect(await mac.cloud.check(tuesday), FolderStanding.combine);
        final took = (await mac.cloud.bringIn(tuesday))!;
        expect(took.others, 1);
        await mac.account('Wallet');
        expect(await mac.cloud.check(tuesday, fresh: true), FolderStanding.ok);

        // Once out, the choice can't be taken back.
        await expectLater(
          laptop.cloud.undoKeepMine(kept, tuesday),
          throwsA(isA<FolderMovedOn>()),
        );
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
      // And each knows where the other stands.
      Map<String, int> live(Map<String, int> v) => {
        for (final e in v.entries)
          if (e.value > 0) e.key: e.value,
      };
      expect(
        live((await mac.db.syncState()).applied),
        live((await laptop.db.syncState()).applied),
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
        FolderStanding.combine,
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
      // Changed on both now: the next look finds what to bring in.
      expect(
        await laptop.cloud.check(tuesday, fresh: true),
        FolderStanding.combine,
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
      // The ledger and each computer's change file, and nothing half
      // written.
      final names = drive.listSync().map((f) => f.uri.pathSegments.last);
      expect(names, contains(CloudFolder.fileName));
      expect(names.where(isChangeFileName), hasLength(2));
      expect(names, hasLength(3));
    });

    // ---------- combine (ADR 0005, step 2) ----------

    /// Both hold the Mac's ledger, and each has looked at the folder.
    /// [on] takes in, or brings in, whatever the folder has that it lacks,
    /// as the screen does, until it holds it all.
    Future<void> settle(_Computer on, [DateTime? at]) async {
      for (var i = 0; i < 6; i++) {
        final standing = await on.cloud.check(at ?? monday, fresh: true);
        if (standing == FolderStanding.newer) {
          await on.open(at ?? monday);
        } else if (standing == FolderStanding.combine) {
          await on.cloud.bringIn(at ?? monday);
        } else {
          return;
        }
      }
    }

    Future<void> agree() async {
      expect(await mac.cloud.check(monday, fresh: true), FolderStanding.ok);
      await laptop.cloud.keepIn(drive.path, monday);
      await settle(laptop);
      expect(await laptop.cloud.check(monday, fresh: true), FolderStanding.ok);
    }

    /// [on] finds the other's changes, brings them in and writes both.
    Future<CombinedIn> bringIn(_Computer on) async {
      expect(
        await on.cloud.check(tuesday, fresh: true),
        FolderStanding.combine,
      );
      final done = await on.cloud.bringIn(tuesday);
      expect(await on.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      return done!;
    }

    Future<TxnData> bought(_Computer on, String payee) async =>
        (await on.db.loadLedger()).txns.singleWhere((t) => t.payee == payee);

    test('a new row’s id is one no other computer gives', () async {
      await agree();
      await mac.spend('Nomin', tuesday);
      await laptop.spend('E-Mart', tuesday);
      await laptop.spend('Shangri-La', tuesday);
      final ids = [
        (await bought(mac, 'Nomin')).id,
        (await bought(laptop, 'E-Mart')).id,
        (await bought(laptop, 'Shangri-La')).id,
      ];
      expect(ids.toSet(), hasLength(3));
      expect(ids.every((id) => id > 1 << 50), isTrue);
      // And rows still sort in the order they were made.
      expect(ids[2], greaterThan(ids[1]));
    });

    test('round after round, each brings in only what is new', () async {
      await agree();
      await mac.spend('Nomin', tuesday);
      await mac.cloud.check(tuesday, fresh: true);
      await laptop.spend('E-Mart', tuesday);
      expect((await bringIn(laptop)).transactions, 1);

      // The Mac goes on before it has seen what the laptop wrote: both
      // open at once.
      await mac.spend('Shangri-La', tuesday);
      expect((await bringIn(mac)).transactions, 1);
      await laptop.db.renameAccount(
        await laptop.account('Cash wallet'),
        'Wallet',
      );
      final third = await bringIn(laptop);
      expect(third.transactions, 1);
      expect(third.others, 0);

      final fourth = await bringIn(mac);
      expect(fourth.transactions, 0);
      expect(fourth.others, 1);
      for (final computer in [mac, laptop]) {
        final payees = await computer.payees();
        for (final payee in ['Nomin', 'E-Mart', 'Shangri-La']) {
          expect(payees.where((p) => p == payee), hasLength(1));
        }
        await computer.account('Wallet');
      }
      expect(
        (await mac.db.sealState()).digest,
        (await laptop.db.sealState()).digest,
      );
    });

    test('a phone’s entries both took in are in once, and nobody is asked, '
        'nor told', () async {
      await agree();
      final inbox = PhoneInbox(
        device: 'pixel',
        categories: const [
          PhoneCategory(id: 'p1', name: 'Coffee', leftMinor: 0),
        ],
        entries: [
          for (final (id, category) in [
            ('e1', 'p1'),
            ('e2', '${await mac.account('Groceries')}'),
          ])
            PhoneEntry(
              id: id,
              categoryId: category,
              accountId: '${await mac.account('TDB Checking')}',
              payee: 'Tom N Toms',
              amountMinor: -850000,
              date: DateTime(2026, 10, 6),
              madeAt: tuesday,
            ),
        ],
      );
      final before = (await mac.db.loadLedger()).txns.length;
      await mac.db.takePhoneEntries([inbox], today: tuesday);
      await laptop.db.takePhoneEntries([inbox], today: tuesday);
      expect(await mac.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      // The two made the same rows under the same ids: the ledgers are
      // one, and the laptop has nothing to write.
      expect(await laptop.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      final data = await laptop.db.loadLedger();
      expect(data.txns, hasLength(before + 2));
      expect(
        data.accounts.values.where((a) => a.name == 'Coffee'),
        hasLength(1),
      );
      expect(await mac.cloud.check(tuesday, fresh: true), FolderStanding.ok);
    });

    test('the same payday, phone entry and bank rows get one id on both '
        'computers, and the two are one ledger with nothing to tell', () async {
      // A pay, which agree() carries to the laptop; then the next payday,
      // scheduled on each from it.
      await mac.db.savePaySchedule(
        accountId: await mac.account('TDB Checking'),
        amount: 2500000,
        rule: PayRule.monthly,
        today: monday,
      );
      await agree();
      final mac1 = await mac.db.ensurePaydays(DateTime(2026, 12, 1));
      final laptop1 = await laptop.db.ensurePaydays(DateTime(2026, 12, 1));
      expect(mac1, isNotEmpty);
      expect(mac1, laptop1);
      expect(mac1.every(isSharedRowId), isTrue);
      // A phone's entry, taken in on each.
      final inbox = PhoneInbox(
        device: 'pixel',
        categories: const [],
        entries: [
          PhoneEntry(
            id: 'e9',
            categoryId: '${await mac.account('Groceries')}',
            accountId: '${await mac.account('TDB Checking')}',
            payee: 'Tom N Toms',
            amountMinor: -850000,
            date: DateTime(2026, 10, 6),
            madeAt: tuesday,
          ),
        ],
      );
      final mac2 = (await mac.db.takePhoneEntries([inbox], today: tuesday))!;
      final laptop2 = (await laptop.db.takePhoneEntries([
        inbox,
      ], today: tuesday))!;
      expect(mac2.transactionIds, laptop2.transactionIds);
      expect(mac2.transactionIds.every(isSharedRowId), isTrue);
      // The same bank file, imported on each.
      final checking = await mac.account('TDB Checking');
      final rows = [
        for (final (day, amount, payee) in [
          (3, -1250000, 'НОМИН POS'),
          (4, -500000, 'Emart'),
        ])
          ImportRow(
            sourceRow: day,
            date: DateTime(2026, 10, day),
            amount: amount,
            payee: payee,
          ),
      ];
      Future<List<int>> import(_Computer on) async {
        final plan = await on.db.planImport(
          checking,
          rows,
          importKeys(checking, rows),
        );
        final record = await on.db.applyImport(
          accountId: checking,
          plan: plan.rows,
          uncategorizedNames: ['Not categorized'],
        );
        return record.added.keys.toList()..sort();
      }

      final mac3 = await import(mac);
      final laptop3 = await import(laptop);
      expect(mac3, hasLength(2));
      expect(mac3, laptop3);
      expect(mac3.every(isSharedRowId), isTrue);
      // Their entries too, so the two ledgers hold the same rows.
      Future<Set<int>> entryIds(_Computer on) async => {
        for (final t in (await on.db.loadLedger()).txns)
          if ([...mac1, ...mac2.transactionIds, ...mac3].contains(t.id))
            for (final e in t.entries) e.id,
      };
      expect(await entryIds(mac), await entryIds(laptop));

      // Each changed its ledger, alike: the two are one, nothing is
      // combined, written or said, and each holds one of everything.
      await mac.cloud.check(tuesday, fresh: true);
      expect(await laptop.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      expect(await mac.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      final before = (await mac.db.loadLedger()).txns.length;
      expect((await laptop.db.loadLedger()).txns, hasLength(before));
      expect(
        (await laptop.db.loadLedger()).txns.where((t) => t.payee == 'Emart'),
        hasLength(1),
      );
    });

    test('cleared on one and filed on the other: the row is both', () async {
      await mac.spend('Nomin', monday);
      await agree();
      final checking = await mac.account('TDB Checking');
      final nomin = await bought(mac, 'Nomin');
      await mac.db.toggleCleared(
        nomin.entries.singleWhere((e) => e.accountId == checking).id,
      );
      await mac.cloud.check(tuesday, fresh: true);
      final other = (await laptop.db.loadLedger()).accounts.values.firstWhere(
        (a) => a.type == AccountType.expense && a.name != 'Groceries',
      );
      await laptop.db.setCategory(
        transactionId: nomin.id,
        accountId: checking,
        categoryId: other.id,
      );
      // A row changed, not one that arrived.
      final done = await bringIn(laptop);
      expect(done.transactions, 0);
      expect(done.others, 1);
      final row = await bought(laptop, 'Nomin');
      expect(row.entries.map((e) => e.accountId), contains(other.id));
      expect(
        row.entries.singleWhere((e) => e.accountId == checking).cleared,
        Cleared.cleared,
      );
    });

    test('one transaction edited on both is asked about, with the other '
        'changes held until it is answered', () async {
      await mac.spend('Nomin', monday);
      await agree();
      for (final (computer, amount) in [(mac, -900000), (laptop, -700000)]) {
        await computer.db.editTransaction(
          transactionId: (await bought(computer, 'Nomin')).id,
          accountId: await computer.account('TDB Checking'),
          date: monday,
          today: tuesday,
          payee: 'Nomin',
          counterAccountId: await computer.account('Groceries'),
          amount: amount,
        );
      }
      // Something else the other did, which has to wait for the answer.
      await mac.spend('E-Mart', tuesday);
      await mac.cloud.check(tuesday, fresh: true);
      final mondays = await folderLedger().readAsBytes();
      expect(
        await laptop.cloud.check(tuesday, fresh: true),
        FolderStanding.rows,
      );
      expect(laptop.cloud.value.held, isTrue);
      final ask = laptop.cloud.asks.single;
      expect(ask.kind, AskKind.transaction);
      expect(ask.mine.lines.map((l) => l.amountMinor), contains(-700000));
      expect(ask.theirs.lines.map((l) => l.amountMinor), contains(-900000));
      expect(
        ask.neither.lines.map((l) => l.amountMinor),
        isNot(contains(-900000)),
      );
      // Not answered: nothing comes in and nothing is written.
      expect(await laptop.cloud.bringIn(tuesday), isNull);
      expect(await folderLedger().readAsBytes(), mondays);
      expect(
        (await laptop.db.loadLedger()).txns.where((t) => t.payee == 'E-Mart'),
        isEmpty,
      );
      // Answered: the other's amount, and what else came.
      final done = await laptop.cloud.bringIn(
        tuesday,
        picks: {ask.id: Pick.theirs},
      );
      expect(done, isNotNull);
      expect(done!.transactions, 1);
      expect(await laptop.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      final row = await bought(laptop, 'Nomin');
      expect(row.entries.map((e) => e.amount), containsAll([-900000, 900000]));
      expect(await bought(laptop, 'E-Mart'), isNotNull);
      // The same as the first computer's now, and nobody is asked.
      expect(await mac.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      expect(await bought(mac, 'E-Mart'), isNotNull);
    });

    test('this computer’s way is kept and written, and the other computer is '
        'not asked afterwards', () async {
      await mac.spend('Nomin', monday);
      await agree();
      for (final (computer, amount) in [(mac, -900000), (laptop, -700000)]) {
        await computer.db.editTransaction(
          transactionId: (await bought(computer, 'Nomin')).id,
          accountId: await computer.account('TDB Checking'),
          date: monday,
          today: tuesday,
          payee: 'Nomin',
          counterAccountId: await computer.account('Groceries'),
          amount: amount,
        );
      }
      await mac.cloud.check(tuesday, fresh: true);
      expect(
        await laptop.cloud.check(tuesday, fresh: true),
        FolderStanding.rows,
      );
      final ask = laptop.cloud.asks.single;
      expect(
        await laptop.cloud.bringIn(tuesday, picks: {ask.id: Pick.mine}),
        isNotNull,
      );
      expect(await laptop.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      expect(
        (await bought(laptop, 'Nomin')).entries.map((e) => e.amount),
        containsAll([-700000, 700000]),
      );
      // The answer travels as the laptop's change: the Mac takes it and
      // isn't asked.
      expect(
        await mac.cloud.check(tuesday, fresh: true),
        FolderStanding.combine,
      );
      final took = (await mac.cloud.bringIn(tuesday))!;
      expect(took.transactions, 0);
      expect(
        (await bought(mac, 'Nomin')).entries.map((e) => e.amount),
        containsAll([-700000, 700000]),
      );
      expect(await mac.cloud.check(tuesday, fresh: true), FolderStanding.ok);
    });

    test('neither: the row goes back to what it was', () async {
      await mac.spend('Nomin', monday);
      await agree();
      for (final (computer, amount) in [(mac, -900000), (laptop, -700000)]) {
        await computer.db.editTransaction(
          transactionId: (await bought(computer, 'Nomin')).id,
          accountId: await computer.account('TDB Checking'),
          date: monday,
          today: tuesday,
          payee: 'Nomin',
          counterAccountId: await computer.account('Groceries'),
          amount: amount,
        );
      }
      await mac.cloud.check(tuesday, fresh: true);
      expect(
        await laptop.cloud.check(tuesday, fresh: true),
        FolderStanding.rows,
      );
      final ask = laptop.cloud.asks.single;
      await laptop.cloud.bringIn(tuesday, picks: {ask.id: Pick.neither});
      expect(await laptop.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      final row = await bought(laptop, 'Nomin');
      expect(row.entries.map((e) => e.amount), isNot(contains(-700000)));
      expect(row.entries.map((e) => e.amount), isNot(contains(-900000)));
      // The answer travels as the laptop's change: the Mac's row goes back
      // as it was too.
      expect(
        await mac.cloud.check(tuesday, fresh: true),
        FolderStanding.combine,
      );
      await mac.cloud.bringIn(tuesday);
      expect(
        (await bought(mac, 'Nomin')).entries.map((e) => e.amount),
        isNot(contains(-900000)),
      );
    });

    test('one category assigned on both is asked about; two aren’t', () async {
      await agree();
      final start = DateTime(2026, 10), end = DateTime(2026, 10, 31);
      final groceries = await mac.account('Groceries');
      final other = (await mac.db.loadLedger()).accounts.values.firstWhere(
        (a) => a.type == AccountType.expense && a.name != 'Groceries',
      );
      await mac.db.setBudgetAmount(groceries, start, end, 40000000);
      await mac.cloud.check(tuesday, fresh: true);
      await laptop.db.setBudgetAmount(other.id, start, end, 9000000);
      final done = await bringIn(laptop);
      expect(done.transactions, 0);
      expect(done.others, 1);
      expect((await bringIn(mac)).others, 1);

      await mac.db.setBudgetAmount(groceries, start, end, 45000000);
      await mac.cloud.check(tuesday, fresh: true);
      await laptop.db.setBudgetAmount(groceries, start, end, 50000000);
      expect(
        await laptop.cloud.check(tuesday, fresh: true),
        FolderStanding.rows,
      );
      final ask = laptop.cloud.asks.single;
      expect(ask.kind, AskKind.assigned);
      expect(ask.category, 'Groceries');
      expect(ask.mine.assignedMinor, 50000000);
      expect(ask.theirs.assignedMinor, 45000000);
      expect(ask.neither.assignedMinor, 40000000);
      expect(
        await laptop.cloud.bringIn(tuesday, picks: {ask.id: Pick.theirs}),
        isNotNull,
      );
      expect(await laptop.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      expect(
        (await laptop.db.loadLedger()).budgetAmounts
            .where((b) => b.categoryId == groceries)
            .fold<int>(0, (s, b) => s + b.amount),
        45000000,
      );
    });

    test(
      'this computer’s ledger as it was is kept; putting it back is a '
      'change made here, and takes back nothing the other computer did',
      () async {
        await agree();
        await mac.spend('Nomin', tuesday);
        await mac.cloud.check(tuesday, fresh: true);
        await laptop.spend('E-Mart', tuesday);
        final done = await bringIn(laptop);
        expect(await laptop.payees(), containsAll(['Nomin', 'E-Mart']));

        // As Restore from… does with the file.
        await laptop.backups.replaceWith(done.before, tuesday);
        expect(await laptop.payees(), isNot(contains('Nomin')));
        expect(await laptop.payees(), contains('E-Mart'));
        // The Mac's purchase is the Mac's doing, still in the Mac's file: it
        // comes back in (ADR 0004: undo only what the person here did).
        expect(
          await laptop.cloud.check(tuesday, fresh: true),
          FolderStanding.combine,
        );
        await laptop.cloud.bringIn(tuesday);
        expect(await laptop.payees(), containsAll(['Nomin', 'E-Mart']));
      },
    );

    test('a purchase typed here and brought in from there is in twice, and '
        'said to look the same', () async {
      await agree();
      await mac.spend('Nomin', tuesday);
      await mac.spend('E-Mart', tuesday);
      await mac.cloud.check(tuesday, fresh: true);
      // The same money from the same account, typed here under another
      // name three days on.
      await laptop.spend('NOMIN UB', tuesday.add(const Duration(days: 3)));
      final done = await bringIn(laptop);
      expect(done.transactions, 2);
      expect(done.alike, hasLength(1));
      expect(done.alike.single.account, await laptop.account('TDB Checking'));
      expect(await laptop.payees(), containsAll(['Nomin', 'NOMIN UB']));
    });

    test('after a restore here the other’s changes still come in; the other '
        'computer is asked about the restore (until step 5)', () async {
      await agree();
      final old = await laptop.backups.keepBefore(monday);
      await laptop.spend('E-Mart', tuesday);
      await laptop.backups.replaceWith(old, tuesday);
      await mac.spend('Nomin', tuesday);
      await mac.cloud.check(tuesday, fresh: true);
      expect(
        await laptop.cloud.check(tuesday, fresh: true),
        FolderStanding.combine,
      );
      await laptop.cloud.bringIn(tuesday);
      expect(await laptop.payees(), contains('Nomin'));
      expect(await laptop.payees(), isNot(contains('E-Mart')));
      expect(await laptop.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      expect(await mac.cloud.check(tuesday, fresh: true), FolderStanding.apart);
    });

    test('the ledger both agreed on isn’t needed: the other’s file says what '
        'each row was', () async {
      await agree();
      final agreed = File('${laptop.dir.path}/cloud-folder-agreed');
      if (agreed.existsSync()) await agreed.delete();
      await mac.spend('Nomin', tuesday);
      await mac.cloud.check(tuesday, fresh: true);
      await laptop.spend('E-Mart', tuesday);
      expect((await bringIn(laptop)).transactions, 1);
      expect(await laptop.payees(), containsAll(['Nomin', 'E-Mart']));
    });

    test('something changed here while it was worked out stops it', () async {
      await agree();
      await mac.spend('Nomin', tuesday);
      await mac.cloud.check(tuesday, fresh: true);
      await laptop.spend('E-Mart', tuesday);
      expect(
        await laptop.cloud.check(tuesday, fresh: true),
        FolderStanding.combine,
      );
      await laptop.spend('Shangri-La', tuesday);
      expect(await laptop.cloud.bringIn(tuesday), isNull);
      expect(await laptop.payees(), isNot(contains('Nomin')));
      // The next look works it out again, with all three.
      await bringIn(laptop);
      expect(
        await laptop.payees(),
        containsAll(['Nomin', 'E-Mart', 'Shangri-La']),
      );
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

  group('a shared id', () {
    test('is the same for the same fact, and in a range of its own', () {
      final a = sharedRowId('payday', '7|2026-10-25');
      expect(a, sharedRowId('payday', '7|2026-10-25'));
      expect(a, isNot(sharedRowId('payday', '7|2026-11-25')));
      expect(a, isNot(sharedRowId('bill', '7|2026-10-25')));
      expect(isSharedRowId(a), isTrue);
      expect(a, greaterThanOrEqualTo(0x4000000000000000));
      expect(a, greaterThan(newRowId()));
      expect(isSharedRowId(newRowId()), isFalse);
      expect(isSharedRowId(carriedRuleId(3, 'unitel')), isFalse);
    });

    test(
      'a row already under the id makes the next one an ordinary id',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await seedDemoIfEmpty(db, DateTime(2026, 10, 9));
        final data = await db.loadLedger();
        int id(String name) =>
            data.accounts.values.singleWhere((a) => a.name == name).id;
        Future<int> post() => db.postTransaction(
          date: DateTime(2026, 10, 25),
          scheduled: true,
          lines: [
            (
              accountId: id('TDB Checking'),
              amount: 100,
              cleared: Cleared.uncleared,
            ),
            (
              accountId: id('Groceries'),
              amount: -100,
              cleared: Cleared.uncleared,
            ),
          ],
          shared: const SharedKey('payday', '1|2026-10-25'),
        );
        final first = await post();
        expect(isSharedRowId(first), isTrue);
        // Skipped (a soft delete keeps the row), then scheduled again.
        await db.softDelete(first);
        final second = await post();
        expect(second, isNot(first));
        expect(isSharedRowId(second), isFalse);
      },
    );
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
        // When a row was written is no part of it: two computers that each
        // made the same payday wrote it at different moments.
        await db.customStatement(
          'UPDATE transactions SET updated_at = updated_at + 1, '
          'created_at = created_at + 1',
        );
        expect((await db.sealState()).digest, changed.digest);
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
