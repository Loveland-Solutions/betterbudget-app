// More than one computer on one ledger (ADR 0005, "Never write blind"): the
// ledger in the folder is never written over unless everything in it is
// already in the ledger of the computer writing.
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;

import 'package:betterbudget/data/backup.dart';
import 'package:betterbudget/data/change_file.dart';
import 'package:betterbudget/data/cloud_folder.dart';
import 'package:betterbudget/domain/combine.dart'
    show Ask, AskKind, Pick, rowOpsBetween, rowsOf;
import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/data/ledger_seal.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/pay.dart';
import 'package:betterbudget/domain/payee_rules.dart';
import 'package:betterbudget/domain/phone.dart';
import 'package:betterbudget/domain/sync.dart';
import 'package:betterbudget/import/mapping.dart';
import 'package:drift/drift.dart' show Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

class _Access extends FolderAccess {
  _Access(this.name, {this.id});
  final String name;

  /// The computer's id, fixed for a test that says which is the lower;
  /// random otherwise.
  final String? id;

  @override
  Future<String?> derivedComputerId() async => id;

  @override
  Future<String?> remember(String path) async => null;

  @override
  Future<String> computerName() async => name;
}

/// One computer: its own ledger file, backups and folder setting.
class _Computer {
  _Computer(this.dir, this.name, {this.id})
    : db = AppDatabase(NativeDatabase(File('${dir.path}/Ledger.betterbudget')));

  final String? id;

  final Directory dir;
  final String name;
  final AppDatabase db;
  late final backups = Backups(db);
  late final cloud = CloudFolder(backups, access: _Access(name, id: id));

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
      expect(await laptop.payees(), contains('Nomin'));
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

    test('an erase here starts another ledger: written to the folder as '
        'before, and the other computer is asked, never folded', () async {
      await mac.spend('Nomin', monday);
      await mac.cloud.check(monday);
      await laptop.cloud.keepIn(drive.path, monday);
      if (await laptop.cloud.check(monday, fresh: true) ==
          FolderStanding.combine) {
        await laptop.cloud.bringIn(monday);
      }
      expect(await laptop.cloud.check(monday, fresh: true), FolderStanding.ok);
      final id = (await laptop.db.syncState()).ledger;
      // A new ledger here: its own id, nothing in common.
      await laptop.db.startNewLedger(tuesday, keepCategories: false);
      expect((await laptop.db.syncState()).ledger, isNot(id));
      // An erase falls back to the older look, whose counts the Mac's
      // writes moved on since: asked, and "keep this computer's" writes
      // the new ledger there (step 5 writes it without the question).
      expect(
        await laptop.cloud.check(tuesday, fresh: true),
        FolderStanding.apart,
      );
      await laptop.cloud.keepMine(tuesday);
      expect(await laptop.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      expect((await lookAtLedger(folderLedger(), null)).ledger, isNot(id));
      final written = await folderLedger().readAsBytes();
      // Two ledgers: the Mac is asked, and nothing of either is folded
      // into the other.
      expect(await mac.cloud.check(tuesday, fresh: true), FolderStanding.apart);
      expect(await mac.payees(), contains('Nomin'));
      expect(await folderLedger().readAsBytes(), written);
    });

    test(
      '“Use this computer’s” keeps the folder’s first, and undoes',
      () async {
        await laptop.cloud.keepIn(drive.path, monday);
        // A transaction taken out of the tables on the Mac, which no
        // ordinary change does (a ledger replaced whole): the laptop can't
        // bring that in row by row, and is asked which ledger to keep.
        final gone = (await mac.db.loadLedger()).txns.first.id;
        await mac.db.customStatement(
          'DELETE FROM entries WHERE transaction_id = $gone',
        );
        await mac.db.customStatement(
          'DELETE FROM transactions WHERE id = $gone',
        );
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
        expect(took.quiet, isFalse);
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
      // And each knows where the other stands: what it has of the other's
      // is the other's log, up to the change that says what that one has
      // applied in turn (written down after it, step 4).
      final macId = await mac.cloud.computerId();
      final laptopId = await laptop.cloud.computerId();
      for (final (c, other) in [(mac, laptopId), (laptop, macId)]) {
        final had = (await c.db.syncState()).applied[other] ?? 0;
        final theirs = identical(c, mac) ? laptop : mac;
        expect(had, greaterThan(0));
        expect(had, lessThanOrEqualTo(await theirs.db.lastChangeSeq()));
      }
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

    test('the second computer to upgrade, with changes its log never saw, '
        'joins the first: one ledger id, nothing lost', () async {
      // The laptop as the older build left it: no vector, no id, and a
      // change its log never saw.
      await laptop.db.setPreference(SyncKeys.applied, null);
      await laptop.db.setPreference(SyncKeys.ledger, null);
      await laptop.spend('E-Mart', monday);
      await laptop.db.customStatement('DELETE FROM changes');
      final id = (await lookAtLedger(folderLedger(), null)).ledger;
      expect(id, isNotNull);
      // Its first write: the older look, whole, which carries the folder's
      // id and vector on and marks the file.
      await laptop.cloud.keepIn(drive.path, tuesday);
      expect(laptop.cloud.value.standing, FolderStanding.ok);
      final look = await lookAtLedger(folderLedger(), null);
      expect(look.ledger, id);
      expect(look.applied.keys, hasLength(2));
      expect(look.whole, isNotNull);
      // The Mac takes it whole, as the older look would, once.
      expect(await mac.cloud.check(tuesday, fresh: true), FolderStanding.newer);
      await mac.open(tuesday);
      expect(await mac.payees(), contains('E-Mart'));
      expect(await mac.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      expect((await mac.db.syncState()).ledger, id);
      // From here on, change files.
      await laptop.spend('Nomin', tuesday);
      expect(await laptop.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      expect((await bringIn(mac)).transactions, 1);
      expect(
        (await mac.db.sealState()).digest,
        (await laptop.db.sealState()).digest,
      );
    });

    test('a folder ledger ahead on a computer whose file hasn’t come is '
        'taken whole, once', () async {
      await agree();
      await laptop.spend('E-Mart', tuesday);
      await laptop.cloud.check(tuesday, fresh: true);
      await bringIn(mac);
      await mac.spend('Nomin', tuesday);
      await mac.cloud.check(tuesday, fresh: true);
      // The Mac's file hasn't arrived.
      final macFile = File(
        '${drive.path}/${changeFileName(await mac.cloud.computerId())}',
      );
      final aside = File('${root.path}/aside.betterbudget-changes');
      await macFile.rename(aside.path);
      expect(
        await laptop.cloud.check(tuesday, fresh: true),
        FolderStanding.newer,
      );
      await laptop.open(tuesday);
      expect(await laptop.payees(), containsAll(['Nomin', 'E-Mart']));
      // Once: the laptop's own count didn't go down with its log.
      expect(await laptop.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      await aside.rename(macFile.path);
      expect(await laptop.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      expect(await mac.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      expect(
        (await mac.db.sealState()).digest,
        (await laptop.db.sealState()).digest,
      );
    });

    test('the same row deleted on both: the two agree to the byte, and '
        'nobody rewrites the folder’s ledger', () async {
      await mac.spend('Nomin', monday);
      await agree();
      final id = (await bought(mac, 'Nomin')).id;
      await mac.db.softDelete(id);
      await mac.cloud.check(tuesday, fresh: true);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await laptop.db.softDelete(id);
      await settle(laptop, tuesday);
      await settle(mac, tuesday);
      expect(
        (await mac.db.sealState()).digest,
        (await laptop.db.sealState()).digest,
      );
      final bytes = await folderLedger().readAsBytes();
      for (var round = 0; round < 2; round++) {
        expect(await mac.cloud.check(tuesday, fresh: true), FolderStanding.ok);
        expect(
          await laptop.cloud.check(tuesday, fresh: true),
          FolderStanding.ok,
        );
      }
      expect(await folderLedger().readAsBytes(), bytes);
    });

    test('a change file that starts past what was applied here: the folder’s '
        'ledger, which holds what the file dropped, is taken whole', () async {
      await agree();
      final older = File('${root.path}/older.betterbudget');
      await folderLedger().copy(older.path);
      await laptop.spend('Shangri-La', tuesday);
      await laptop.cloud.check(tuesday, fresh: true);
      expect((await bringIn(mac)).transactions, 1);
      // Published, but the Mac hasn't looked; then the laptop takes an
      // older copy of the folder's ledger whole (its log is cleared) and
      // spends again.
      await laptop.spend('Emart', tuesday);
      await laptop.cloud.check(tuesday, fresh: true);
      await laptop.backups.restore(
        await laptop.backups.inspect(older.path, tuesday),
        tuesday,
        fromFolder: true,
      );
      await laptop.spend('Unitel', tuesday);
      expect(await laptop.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      expect(await mac.cloud.check(tuesday, fresh: true), FolderStanding.newer);
      await mac.open(tuesday);
      expect(await mac.payees(), contains('Unitel'));
      expect(await mac.payees(), isNot(contains('Emart')));
      expect(await mac.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      expect(
        (await mac.db.sealState()).digest,
        (await laptop.db.sealState()).digest,
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

    // ---------- settled the same way on both (ADR 0005, step 4) ----------

    /// Each computer in [order] looks, and brings in what it finds, until
    /// neither has anything more; what each was told of its own that was
    /// replaced.
    Future<void> converge(
      List<_Computer> order,
      Map<_Computer, List<Ask>> told,
    ) async {
      for (var round = 0; round < 4; round++) {
        for (final c in order) {
          for (var i = 0; i < 6; i++) {
            final standing = await c.cloud.check(tuesday, fresh: true);
            expect(c.cloud.value.held, isFalse, reason: "${c.name} $standing");
            if (standing == FolderStanding.newer) {
              await c.open(tuesday);
              continue;
            }
            if (standing != FolderStanding.combine) break;
            final done = await c.cloud.bringIn(tuesday);
            if (done == null) break;
            told[c]!.addAll(done.replaced);
          }
        }
      }
    }

    /// The Mac's change [onMac] and the laptop's [onLaptop], made apart on
    /// a ledger both agree on, brought together in [how]: the Mac settling
    /// first, the laptop first, or both looking before either brings the
    /// other's in. Afterwards the two ledgers are the same to the row.
    /// What each was told of its own that was replaced.
    Future<Map<_Computer, List<Ask>>> apart(
      String how,
      Future<void> Function(_Computer) onMac,
      Future<void> Function(_Computer) onLaptop,
    ) async {
      await onMac(mac);
      await onLaptop(laptop);
      final told = {mac: <Ask>[], laptop: <Ask>[]};
      if (how == 'at once') {
        await mac.cloud.check(tuesday, fresh: true);
        expect(
          await laptop.cloud.check(tuesday, fresh: true),
          FolderStanding.combine,
        );
        expect(
          await mac.cloud.check(tuesday, fresh: true),
          FolderStanding.combine,
        );
        for (final c in [mac, laptop]) {
          told[c]!.addAll((await c.cloud.bringIn(tuesday))!.replaced);
        }
        await converge([mac, laptop], told);
      } else {
        final first = how == 'the laptop first' ? laptop : mac;
        final second = identical(first, mac) ? laptop : mac;
        // The second publishes its change; the first finds it and settles.
        await second.cloud.check(tuesday, fresh: true);
        await converge([first, second], told);
      }
      expect(
        (await mac.db.sealState()).digest,
        (await laptop.db.sealState()).digest,
      );
      for (final c in [mac, laptop]) {
        expect(await c.cloud.check(tuesday, fresh: true), FolderStanding.ok);
      }
      return told;
    }

    /// The computer whose version stands when nothing else decides: the
    /// lower id's.
    Future<_Computer> lower() async =>
        (await mac.cloud.computerId()).compareTo(
              await laptop.cloud.computerId(),
            ) <
            0
        ? mac
        : laptop;

    _Computer otherThan(_Computer c) => identical(c, mac) ? laptop : mac;

    Future<void> edit(_Computer c, int amount, {String? category}) async =>
        c.db.editTransaction(
          transactionId: (await bought(c, 'Nomin')).id,
          accountId: await c.account('TDB Checking'),
          date: monday,
          today: tuesday,
          payee: 'Nomin',
          counterAccountId: await c.account(category ?? 'Groceries'),
          amount: amount,
        );

    Future<int> bankAmount(_Computer c) async {
      final checking = await c.account('TDB Checking');
      return (await bought(
        c,
        'Nomin',
      )).entries.singleWhere((e) => e.accountId == checking).amount;
    }

    /// Spending categories other than Groceries, by name.
    Future<List<String>> others(_Computer c) async => [
      for (final a in (await c.db.loadLedger()).accounts.values)
        if (a.type == AccountType.expense && a.name != 'Groceries') a.name,
    ]..sort();

    Future<String> otherCategory(_Computer c) async => (await others(c)).first;

    for (final how in ['the Mac first', 'the laptop first', 'at once']) {
      group('settled the same on both, $how:', () {
        test('an amount changed two ways: the lower id’s, never asked; the '
            'other is told', () async {
          await mac.spend('Nomin', monday);
          await agree();
          final told = await apart(
            how,
            (c) => edit(c, -900000),
            (c) => edit(c, -700000),
          );
          final winner = await lower();
          final stands = identical(winner, mac) ? -900000 : -700000;
          for (final c in [mac, laptop]) {
            expect(await bankAmount(c), stands);
          }
          expect(told[winner], isEmpty);
          final ask = told[otherThan(winner)]!.single;
          expect(ask.kind, AskKind.transaction);
          expect(ask.inLedger, Pick.theirs);
          expect(
            ask.mine.lines.map((l) => l.amountMinor),
            contains(identical(winner, mac) ? -700000 : -900000),
          );
        });

        test('deleted on one and changed on the other: it stays, with the '
            'change, and the one that deleted it is told', () async {
          await mac.spend('Nomin', monday);
          await agree();
          final told = await apart(
            how,
            (c) async => c.db.softDelete((await bought(c, 'Nomin')).id),
            (c) => edit(c, -700000),
          );
          for (final c in [mac, laptop]) {
            expect(await bankAmount(c), -700000);
          }
          expect(told[laptop], isEmpty);
          final ask = told[mac]!.single;
          expect(ask.mine.deleted, isTrue);
          expect(ask.now!.deleted, isFalse);
        });

        test('reconciled on one and edited on the other: the reconciled '
            'money stays', () async {
          await mac.spend('Nomin', monday);
          await agree();
          final told = await apart(how, (c) async {
            final checking = await c.account('TDB Checking');
            final nomin = await bought(c, 'Nomin');
            await c.db.toggleCleared(
              nomin.entries.singleWhere((e) => e.accountId == checking).id,
            );
            final cleared = await c.db
                .customSelect(
                  'SELECT COALESCE(SUM(e.amount_minor), 0) AS n FROM '
                  'entries e JOIN transactions t ON t.id = '
                  'e.transaction_id WHERE e.account_id = ? AND '
                  'e.cleared != 0 AND t.deleted_at IS NULL AND '
                  't.date <= ?',
                  variables: [
                    Variable.withInt(checking),
                    Variable.withString(dateKey(monday)),
                  ],
                )
                .getSingle();
            await c.db.reconcile(
              accountId: checking,
              statementDate: monday,
              today: tuesday,
              balance: cleared.read<int>('n'),
            );
          }, (c) => edit(c, -700000));
          for (final c in [mac, laptop]) {
            expect(await bankAmount(c), -1250000);
            final checking = await c.account('TDB Checking');
            expect(
              (await bought(
                c,
                'Nomin',
              )).entries.singleWhere((e) => e.accountId == checking).cleared,
              Cleared.reconciled,
            );
          }
          expect(told[mac], isEmpty);
          expect(told[laptop], hasLength(1));
        });

        test('matched to the bank on one and edited on the other: the '
            'bank’s amount, the typed category', () async {
          await mac.spend('Nomin', monday);
          await agree();
          final other = await otherCategory(mac);
          final told = await apart(how, (c) async {
            final checking = await c.account('TDB Checking');
            final nomin = await bought(c, 'Nomin');
            await c.db.customUpdate(
              'UPDATE entries SET import_key = ? WHERE id = ?',
              variables: [
                Variable.withString('a$checking|test-bank-row'),
                Variable.withInt(
                  nomin.entries.singleWhere((e) => e.accountId == checking).id,
                ),
              ],
              updates: {c.db.entries},
            );
          }, (c) => edit(c, -700000, category: other));
          for (final c in [mac, laptop]) {
            expect(await bankAmount(c), -1250000);
            final category = await c.account(other);
            expect(
              (await bought(
                c,
                'Nomin',
              )).entries.singleWhere((e) => e.accountId == category).amount,
              1250000,
            );
          }
          expect(told[mac], isEmpty);
          expect(told[laptop], hasLength(1));
        });

        test('an account renamed two ways: one name on both, and the other '
            'is told', () async {
          await agree();
          final told = await apart(
            how,
            (c) async =>
                c.db.renameAccount(await c.account('Cash wallet'), 'Wallet'),
            (c) async =>
                c.db.renameAccount(await c.account('Cash wallet'), 'Purse'),
          );
          final winner = await lower();
          final name = identical(winner, mac) ? 'Wallet' : 'Purse';
          for (final c in [mac, laptop]) {
            await c.account(name);
          }
          expect(told[winner], isEmpty);
          final ask = told[otherThan(winner)]!.single;
          expect(ask.kind, AskKind.renamed);
          expect(ask.name, 'Cash wallet');
          expect(ask.now!.name, name);
        });

        test('one category assigned two amounts for one period: never '
            'added together, never the larger; the lower id’s', () async {
          await agree();
          final start = DateTime(2026, 10), end = DateTime(2026, 10, 31);
          final told = await apart(
            how,
            (c) async => c.db.setBudgetAmount(
              await c.account('Groceries'),
              start,
              end,
              45000000,
            ),
            (c) async => c.db.setBudgetAmount(
              await c.account('Groceries'),
              start,
              end,
              30000000,
            ),
          );
          final winner = await lower();
          for (final c in [mac, laptop]) {
            final groceries = await c.account('Groceries');
            expect(
              (await c.db.loadLedger()).budgetAmounts
                  .where((b) => b.categoryId == groceries)
                  .fold<int>(0, (s, b) => s + b.amount),
              identical(winner, mac) ? 45000000 : 30000000,
            );
          }
          expect(told[winner], isEmpty);
          expect(told[otherThan(winner)]!.single.kind, AskKind.assigned);
        });

        test('a pay changed in the same column on both: one of the two, '
            'and the other is told', () async {
          await mac.db.savePaySchedule(
            accountId: await mac.account('TDB Checking'),
            amount: 400000000,
            rule: PayRule.monthly,
            today: monday,
          );
          await agree();
          final pay = (await mac.db.loadLedger()).paySchedules.first.id;
          final told = await apart(
            how,
            (c) => c.db.customStatement(
              'UPDATE pay_schedules SET amount_minor = 410000000 '
              'WHERE id = $pay',
            ),
            (c) => c.db.customStatement(
              'UPDATE pay_schedules SET amount_minor = 420000000 '
              'WHERE id = $pay',
            ),
          );
          final winner = await lower();
          for (final c in [mac, laptop]) {
            expect(
              (await c.db.loadLedger()).paySchedules
                  .singleWhere((p) => p.id == pay)
                  .amount,
              identical(winner, mac) ? 410000000 : 420000000,
            );
          }
          expect(told[winner], isEmpty);
          expect(told[otherThan(winner)]!.single.kind, AskKind.pay);
        });

        test('a setting changed two ways: one of the two', () async {
          await agree();
          final told = await apart(
            how,
            (c) => c.db.setPreference('test.setting', 'the Mac’s'),
            (c) => c.db.setPreference('test.setting', 'the laptop’s'),
          );
          final winner = await lower();
          for (final c in [mac, laptop]) {
            expect(
              (await c.db.allRows())['preferences']!.singleWhere(
                (r) => r['key'] == 'test.setting',
              )['value'],
              identical(winner, mac) ? 'the Mac’s' : 'the laptop’s',
            );
          }
          expect(told[winner], isEmpty);
          expect(told[otherThan(winner)]!.single.kind, AskKind.setting);
        });

        test('one payday confirmed for two amounts: one payday, the lower '
            'id’s amount', () async {
          await mac.db.savePaySchedule(
            accountId: await mac.account('TDB Checking'),
            amount: 400000000,
            rule: PayRule.monthly,
            today: monday,
          );
          await mac.db.ensurePaydays(DateTime(2026, 12, 1));
          await agree();
          final row = (await mac.db.allRows())['transactions']!.firstWhere(
            (t) => t['scheduled'] == 1 && t['pay_schedule_id'] != null,
          );
          final id = row['id'] as int;
          Future<void> confirm(_Computer c, int amount) async {
            await c.db.customStatement(
              'UPDATE transactions SET scheduled = 0 WHERE id = $id',
            );
            for (final e in (await c.db.allRows())['entries']!.where(
              (e) => e['transaction_id'] == id,
            )) {
              final sign = (e['amount_minor'] as int) < 0 ? -1 : 1;
              await c.db.customStatement(
                'UPDATE entries SET amount_minor = ${sign * amount} '
                'WHERE id = ${e['id']}',
              );
            }
          }

          final told = await apart(
            how,
            (c) => confirm(c, 410000000),
            (c) => confirm(c, 380000000),
          );
          final winner = await lower();
          for (final c in [mac, laptop]) {
            final rows = (await c.db.allRows());
            expect(
              rows['transactions']!.where((t) => t['id'] == id),
              hasLength(1),
            );
            expect(
              rows['entries']!
                  .where((e) => e['transaction_id'] == id)
                  .map((e) => (e['amount_minor'] as int).abs())
                  .toSet(),
              {identical(winner, mac) ? 410000000 : 380000000},
            );
          }
          expect(told[winner], isEmpty);
          expect(told[otherThan(winner)], hasLength(1));
        });

        test(
          'a bank row both have, filed two ways: one filing on both',
          () async {
            await mac.spend('Nomin', monday);
            final checking = await mac.account('TDB Checking');
            final nomin = await bought(mac, 'Nomin');
            await mac.db.customStatement(
              "UPDATE entries SET import_key = 'a$checking|both-banks' "
              'WHERE id = '
              '${nomin.entries.singleWhere((e) => e.accountId == checking).id}',
            );
            await agree();
            final names = await others(mac);
            Future<void> file(_Computer c, String category) async =>
                c.db.setCategory(
                  transactionId: nomin.id,
                  accountId: checking,
                  categoryId: await c.account(category),
                );
            final told = await apart(
              how,
              (c) => file(c, names[0]),
              (c) => file(c, names[1]),
            );
            final winner = await lower();
            final filed = identical(winner, mac) ? names[0] : names[1];
            for (final c in [mac, laptop]) {
              final category = await c.account(filed);
              expect(
                (await bought(c, 'Nomin')).entries.map((e) => e.accountId),
                contains(category),
              );
            }
            expect(told[winner], isEmpty);
            expect(told[otherThan(winner)], hasLength(1));
          },
        );
      });
    }

    test('nothing is held: what else the other changed comes in with the '
        'settled row, and this computer’s own go out at once', () async {
      await mac.spend('Nomin', monday);
      await agree();
      await edit(mac, -900000);
      await mac.spend('E-Mart', tuesday);
      await edit(laptop, -700000);
      await laptop.spend('Shangri-La', tuesday);
      await mac.cloud.check(tuesday, fresh: true);
      final told = {mac: <Ask>[], laptop: <Ask>[]};
      await converge([laptop, mac], told);
      for (final c in [mac, laptop]) {
        expect(await c.payees(), containsAll(['E-Mart', 'Shangri-La']));
      }
      expect(
        (await mac.db.sealState()).digest,
        (await laptop.db.sealState()).digest,
      );
    });

    for (final pick in [Pick.mine, Pick.neither]) {
      test('the one told picks ${pick.name} afterwards: an ordinary change, '
          'taken in on the other computer, which is told nothing', () async {
        await mac.spend('Nomin', monday);
        await agree();
        await edit(mac, -900000);
        await edit(laptop, -700000);
        final told = {mac: <Ask>[], laptop: <Ask>[]};
        await mac.cloud.check(tuesday, fresh: true);
        await converge([laptop, mac], told);
        final loser = told[mac]!.isEmpty ? laptop : mac;
        final ask = told[loser]!.single;
        await loser.db.applyChangesHere(
          rowOpsBetween(rowsOf(ask, await loser.db.allRows()), ask.rows[pick]!),
        );
        final again = {mac: <Ask>[], laptop: <Ask>[]};
        await converge([mac, laptop], again);
        expect(again[mac], isEmpty);
        expect(again[laptop], isEmpty);
        final mineWas = identical(loser, mac) ? -900000 : -700000;
        for (final c in [mac, laptop]) {
          expect(await bankAmount(c), pick == Pick.mine ? mineWas : -1250000);
        }
        expect(
          (await mac.db.sealState()).digest,
          (await laptop.db.sealState()).digest,
        );
      });
    }

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

  // ---------- settled the same on both, under stress (step 4 reviews) ----------
  //
  // From the code review's adversarial tests: what a computer had seen of
  // the other's when it made a change, not equal values, says whether it
  // crossed; an amount assigned on both is one row; the locks stay when a
  // version is picked afterwards; three computers are asked; and a seeded
  // random interleaving of edits, looks and bring-ins always ends with the
  // two ledgers the same, across many seeds.
  for (final macIsLower in [true, false]) {
    group('settled the same on both, under stress, the Mac '
        '${macIsLower ? 'lower' : 'higher'}', () {
      final monday = DateTime(2026, 10, 5, 21, 40);
      final tuesday = DateTime(2026, 10, 6, 8, 15);
      late Directory root;
      late Directory drive;
      late _Computer mac;
      late _Computer laptop;
      final told = <String, List<Ask>>{};

      File folderLedger() => File('${drive.path}/${CloudFolder.fileName}');

      setUp(() async {
        told.clear();
        root = await Directory.systemTemp.createTemp('bb-stress');
        drive = await Directory('${root.path}/My Drive/BetterBudget')
            .create(recursive: true);
        mac = _Computer(
          await Directory('${root.path}/mac').create(),
          'The desk Mac',
          id: macIsLower ? 'aaaaaaaa-mac' : 'zzzzzzzz-mac',
        );
        await seedDemoIfEmpty(mac.db, monday);
        await mac.cloud.keepIn(drive.path, monday);
        laptop = _Computer(
          await Directory('${root.path}/laptop').create(),
          'The laptop',
          id: macIsLower ? 'zzzzzzzz-laptop' : 'aaaaaaaa-laptop',
        );
        await seedDemoIfEmpty(laptop.db, monday);
        await laptop.backups.restore(
          await laptop.backups.inspect(folderLedger().path, monday),
          monday,
          fromFolder: true,
        );
      });

      tearDown(() async {
        await mac.close();
        await laptop.close();
        await root.delete(recursive: true);
      });

      Future<void> settle(_Computer on) async {
        for (var i = 0; i < 6; i++) {
          final s = await on.cloud.check(monday, fresh: true);
          if (s == FolderStanding.newer) {
            await on.open(monday);
          } else if (s == FolderStanding.combine) {
            await on.cloud.bringIn(monday);
          } else {
            return;
          }
        }
      }

      Future<void> agree() async {
        expect(await mac.cloud.check(monday, fresh: true), FolderStanding.ok);
        await laptop.cloud.keepIn(drive.path, monday);
        await settle(laptop);
      }

      Future<FolderStanding> step(_Computer c) async {
        var s = FolderStanding.ok;
        for (var i = 0; i < 6; i++) {
          s = await c.cloud.check(tuesday, fresh: true);
          if (s == FolderStanding.newer) {
            await c.open(tuesday);
            continue;
          }
          if (s != FolderStanding.combine) break;
          final done = await c.cloud.bringIn(tuesday);
          if (done == null) break;
          (told[c.name] ??= []).addAll(done.replaced);
        }
        return s;
      }

      /// Five rounds of both looking; what each round left, to see that the
      /// two stopped moving.
      Future<List<String>> converge([List<_Computer>? order]) async {
        final out = <String>[];
        for (var r = 0; r < 5; r++) {
          for (final c in order ?? [mac, laptop]) {
            await step(c);
          }
          out.add(
            '${(await mac.db.sealState()).digest} '
            '${(await laptop.db.sealState()).digest} '
            '${await mac.db.lastChangeSeq()} ${await laptop.db.lastChangeSeq()}',
          );
        }
        return out;
      }

      Future<void> expectSame() async {
        expect(
          (await mac.db.sealState()).digest,
          (await laptop.db.sealState()).digest,
        );
      }

      Future<TxnData> bought(_Computer on, String payee) async =>
          (await on.db.loadLedger()).txns.singleWhere((t) => t.payee == payee);

      Future<void> edit(
        _Computer c,
        int amount, {
        String? memo,
        String category = 'Groceries',
      }) async => c.db.editTransaction(
        transactionId: (await bought(c, 'Nomin')).id,
        accountId: await c.account('TDB Checking'),
        date: monday,
        today: tuesday,
        payee: 'Nomin',
        memo: memo,
        counterAccountId: await c.account(category),
        amount: amount,
      );

      Future<EntryData> bankLine(_Computer c) async {
        final checking = await c.account('TDB Checking');
        return (await bought(
          c,
          'Nomin',
        )).entries.singleWhere((e) => e.accountId == checking);
      }

      Future<int> bank(_Computer c) async => (await bankLine(c)).amount;

      Future<bool> macLower() async =>
          (await mac.cloud.computerId()).compareTo(
            await laptop.cloud.computerId(),
          ) <
          0;

      Future<int> assigned(_Computer c) async {
        final g = await c.account('Groceries');
        return (await c.db.loadLedger()).budgetAmounts
            .where((b) => b.categoryId == g)
            .fold<int>(0, (s, b) => s + b.amount);
      }

      Future<void> assign(_Computer c, int amount) async =>
          c.db.setBudgetAmount(
            await c.account('Groceries'),
            DateTime(2026, 10),
            DateTime(2026, 10, 31),
            amount,
          );

      for (final order in ['the Mac first', 'the laptop first', 'at once']) {
        test('crossed twice, each editing again before seeing the other '
            '($order)', () async {
          await mac.spend('Nomin', monday);
          await agree();
          await edit(mac, -900000);
          await edit(laptop, -700000);
          await mac.cloud.check(tuesday, fresh: true);
          await laptop.cloud.check(tuesday, fresh: true);
          if (order == 'the Mac first') await step(mac);
          if (order == 'the laptop first') await step(laptop);
          await edit(mac, -910000, memo: 'm2');
          await edit(laptop, -710000, memo: 'l2');
          final d = await converge();
          await expectSame();
          expect(d.last, d[d.length - 2]);
        });

        test('renamed two ways, and put away on one ($order)', () async {
          await agree();
          await mac.db.renameAccount(
            await mac.account('Cash wallet'),
            'Wallet',
          );
          await laptop.db.renameAccount(
            await laptop.account('Cash wallet'),
            'Purse',
          );
          await laptop.db.customStatement(
            "UPDATE accounts SET archived_at = '2026-10-06' WHERE name = 'Purse'",
          );
          await mac.cloud.check(tuesday, fresh: true);
          await laptop.cloud.check(tuesday, fresh: true);
          if (order == 'the Mac first') await step(mac);
          if (order == 'the laptop first') await step(laptop);
          final d = await converge();
          await expectSame();
          expect(d.last, d[d.length - 2]);
        });

        test('changed in different parts on the two: each part kept, only the '
            'part changed both ways by the rule ($order)', () async {
          await mac.spend('Nomin', monday);
          await agree();
          final other = (await laptop.db.loadLedger()).accounts.values
              .where(
                (a) => a.type == AccountType.expense && a.name != 'Groceries',
              )
              .map((a) => a.name)
              .reduce((a, b) => a.compareTo(b) < 0 ? a : b);
          // The amount both ways; the memo only on the Mac, the category only
          // on the laptop.
          await edit(mac, -900000, memo: 'lunch');
          await edit(laptop, -700000, category: other);
          await mac.cloud.check(tuesday, fresh: true);
          await laptop.cloud.check(tuesday, fresh: true);
          if (order == 'the Mac first') await step(mac);
          if (order == 'the laptop first') await step(laptop);
          await converge();
          await expectSame();
          final stands = await macLower() ? -900000 : -700000;
          for (final c in [mac, laptop]) {
            final row = await bought(c, 'Nomin');
            expect(await bank(c), stands);
            expect(row.memo, 'lunch');
            expect(
              row.entries.map((e) => e.accountId),
              contains(await c.account(other)),
            );
          }
        });
      }

      test('an independent edit to the same amount as an older version is '
          'not seeing it', () async {
        for (var k = 0; k < 3; k++) {
          await mac.spend('Nomin $k', monday);
        }
        await mac.spend('Nomin', monday);
        await agree();
        final lo = await macLower() ? mac : laptop;
        final hi = identical(lo, mac) ? laptop : mac;
        await edit(lo, -1250000, memo: 'memo0');
        await edit(hi, -1250000, memo: 'memo1');
        await lo.cloud.check(tuesday, fresh: true);
        await edit(hi, -600000);
        await edit(hi, -900000);
        await hi.cloud.check(tuesday, fresh: true);
        await step(hi);
        await edit(lo, -1250000, memo: 'memo2');
        await edit(lo, -600000);
        final d = await converge();
        expect(await bank(mac), await bank(laptop));
        await expectSame();
        expect(d.last, d[d.length - 2]);
      });

      for (final first in ['the Mac', 'the laptop']) {
        test('the same amount assigned on both is one row, and a later change '
            'on one is the amount ($first first)', () async {
          await agree();
          await assign(mac, 3000000);
          await assign(laptop, 3000000);
          await mac.cloud.check(tuesday, fresh: true);
          await laptop.cloud.check(tuesday, fresh: true);
          final order = first == 'the Mac' ? [mac, laptop] : [laptop, mac];
          await converge(order);
          expect(await assigned(mac), 3000000);
          expect(await assigned(laptop), 3000000);
          await assign(mac, 2000000);
          await converge(order);
          expect(await assigned(mac), 2000000);
          expect(await assigned(laptop), 2000000);
          await expectSame();
        });
      }

      test('rows of one amount assigned made before one id was shared: one '
          'set on both, never added together', () async {
        await agree();
        for (final c in [mac, laptop]) {
          await c.db.customStatement(
            'INSERT INTO budget_amounts (id, category_id, date, amount_minor) '
            "VALUES (${newRowId()}, ${await c.account('Groceries')}, "
            "'2026-10-01', 3000000)",
          );
        }
        await mac.cloud.check(tuesday, fresh: true);
        await laptop.cloud.check(tuesday, fresh: true);
        await converge();
        expect(await assigned(mac), 3000000);
        expect(await assigned(laptop), 3000000);
        await expectSame();
      });

      Future<void> reconcile(_Computer c) async {
        final checking = await c.account('TDB Checking');
        await c.db.toggleCleared((await bankLine(c)).id);
        final cleared = await c.db
            .customSelect(
              'SELECT COALESCE(SUM(e.amount_minor), 0) AS n FROM entries e '
              'JOIN transactions t ON t.id = e.transaction_id '
              'WHERE e.account_id = ? AND e.cleared != 0 '
              'AND t.deleted_at IS NULL AND t.date <= ?',
              variables: [
                Variable.withInt(checking),
                Variable.withString('2026-10-05'),
              ],
            )
            .getSingle();
        await c.db.reconcile(
          accountId: checking,
          statementDate: monday,
          today: tuesday,
          balance: cleared.read<int>('n'),
        );
      }

      Future<void> match(_Computer c) async {
        final checking = await c.account('TDB Checking');
        await c.db.customStatement(
          "UPDATE entries SET import_key = 'a$checking|stress' "
          'WHERE id = ${(await bankLine(c)).id}',
        );
      }

      for (final (fact, make) in [
        ('reconciled', reconcile),
        ('matched to the bank', match),
      ]) {
        for (final pick in Pick.values) {
          test('picked afterwards on a row $fact: the money stays ('
              '${pick.name})', () async {
            await mac.spend('Nomin', monday);
            await agree();
            final before = await bankLine(mac);
            await make(mac);
            final locked = await bankLine(mac);
            await edit(laptop, -700000, memo: 'typed');
            await mac.cloud.check(tuesday, fresh: true);
            await laptop.cloud.check(tuesday, fresh: true);
            await converge();
            final ask = told['The laptop']!.single;
            expect(ask.lock, fact == 'reconciled' ? 'reconciled' : 'bank');
            await laptop.db.applyChangesHere(
              rowOpsBetween(
                rowsOf(ask, await laptop.db.allRows()),
                ask.rows[pick]!,
              ),
            );
            await converge();
            await expectSame();
            for (final c in [mac, laptop]) {
              final line = await bankLine(c);
              expect(line.amount, before.amount);
              expect(line.cleared, locked.cleared);
            }
            final row = await bought(laptop, 'Nomin');
            expect(row.memo, pick == Pick.mine ? 'typed' : null);
          });
        }
      }

      test(
        'three computers: a row changed two ways among them is asked, not '
        'settled by the rule, and nothing is taken as ok until it is',
        () async {
          final third = _Computer(
            await Directory('${root.path}/third').create(),
            'The third',
          );
          addTearDown(third.close);
          await seedDemoIfEmpty(third.db, monday);
          await mac.spend('Nomin', monday);
          await agree();
          await mac.cloud.check(monday, fresh: true);
          await third.backups.restore(
            await third.backups.inspect(folderLedger().path, monday),
            monday,
            fromFolder: true,
          );
          await third.cloud.keepIn(drive.path, monday);
          await settle(third);
          for (final c in [mac, laptop, third]) {
            await c.cloud.check(monday, fresh: true);
          }
          for (final c in [mac, laptop, third]) {
            await settle(c);
          }
          await edit(mac, -900000);
          await edit(laptop, -700000);
          for (final c in [mac, laptop]) {
            await c.cloud.check(tuesday, fresh: true);
          }
          final standings = [
            for (final c in [mac, laptop]) await step(c),
          ];
          // Asked, and held: the red line, never a quiet ok on two amounts.
          expect(standings, everyElement(FolderStanding.rows));
          for (final c in [mac, laptop]) {
            expect(c.cloud.value.held, isTrue);
            expect(c.cloud.asks, hasLength(1));
          }
          expect(await bank(mac), -900000);
          expect(await bank(laptop), -700000);
        },
      );

      for (var seed = 0; seed < 40; seed++) {
        test('a random run of edits, looks and bring-ins ends the same on '
            'both (seed $seed)', () async {
          final rnd = Random(seed);
          await mac.spend('Nomin', monday);
          await agree();
          final cs = [mac, laptop];
          for (var i = 0; i < 14; i++) {
            final c = cs[rnd.nextInt(2)];
            try {
              switch (rnd.nextInt(8)) {
                case 0:
                  await edit(c, -100000 * (1 + rnd.nextInt(9)));
                case 1:
                  await edit(c, await bank(c), memo: 'memo${rnd.nextInt(5)}');
                case 2:
                  final id =
                      (await c.db.allRows())['accounts']!.firstWhere(
                            (a) =>
                                a['type'] == 'asset' &&
                                a['currency'] == 'MNT' &&
                                a['name'] != 'TDB Checking' &&
                                a['name'] != 'Khan Savings',
                          )['id']
                          as int;
                  await c.db.renameAccount(id, 'Name${rnd.nextInt(4)}');
                case 3:
                  await assign(c, 1000000 * (1 + rnd.nextInt(5)));
                case 4:
                  await c.cloud.check(tuesday, fresh: true);
                case 5:
                  await step(c);
                case 6:
                  if (await c.cloud.check(tuesday, fresh: true) ==
                      FolderStanding.combine) {
                    final done = await c.cloud.bringIn(tuesday);
                    (told[c.name] ??= []).addAll(done?.replaced ?? const []);
                  }
                case 7:
                  await c.db.toggleCleared((await bankLine(c)).id);
              }
            } on LockedException {
              // A reconciled row refuses an edit, as on screen.
            }
          }
          final d = await converge();
          for (final c in cs) {
            expect(
              await c.cloud.check(tuesday, fresh: true),
              FolderStanding.ok,
            );
          }
          await expectSame();
          expect(d.last, d[d.length - 2]);
        });
      }
    });
  }
}
