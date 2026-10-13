// The ledger kept in a folder the user picked (ADR 0005, "All of the data lives
// in the cloud folder"): the copy, when it is written again, and the Settings
// line that says where it is.
import 'dart:io';

import 'package:betterbudget/data/phone_inbox.dart';
import 'package:betterbudget/domain/phone.dart';
import 'package:betterbudget/data/backup.dart';
import 'package:betterbudget/data/cloud_folder.dart';
import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/ui/ledger_screen.dart';
import 'package:betterbudget/ui/theme.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the Mac's bookmarks: a token is the path it was made for,
/// and [movedTo] says where that folder is found at the next launch.
class _FakeAccess extends FolderAccess {
  String? movedTo;

  @override
  bool get folderMustBePicked => true;

  /// The bookmark no longer opens anything.
  bool broken = false;

  @override
  Future<String?> remember(String path) async => 'token:$path';

  @override
  Future<String> computerName() async => 'The desk Mac';

  @override
  Future<({String path, String? token})?> open(String token) async {
    if (broken) throw StateError('the bookmark is no good');
    return (path: movedTo ?? token.substring('token:'.length), token: null);
  }
}

class _DerivedAccess extends _FakeAccess {
  _DerivedAccess(this.id);
  final String id;

  @override
  Future<String?> derivedComputerId() async => id;
}

class _OtherAccess extends FolderAccess {
  @override
  Future<String?> remember(String path) async => null;

  @override
  Future<String> computerName() async => 'The laptop';
}

class _FakeDialogs extends FileSelectorPlatform {
  String? folder;
  String? openPath;

  /// Where the folder dialog was opened, each time it was.
  final openedOn = <String?>[];

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => openPath == null ? null : XFile(openPath!);

  @override
  Future<String?> getDirectoryPath({
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    openedOn.add(initialDirectory);
    return folder;
  }
}

Future<void> _loadFont(String family, String path) async {
  final bytes = await File(path).readAsBytes();
  await (FontLoader(
    family,
  )..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final today = DateTime(2026, 10, 7, 10);
  late Directory dir;
  late Directory drive;
  late AppDatabase db;
  late Backups backups;

  File copy() => File('${drive.path}/${CloudFolder.fileName}');

  Future<int> transactionsIn(File file) async {
    final opened = AppDatabase(NativeDatabase(file));
    try {
      return (await opened.loadLedger()).txns.length;
    } finally {
      await opened.close();
    }
  }

  group('the copy', () {
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('bb-cloud');
      drive = await Directory('${dir.path}/My Drive/BetterBudget')
          .create(recursive: true);
      db = AppDatabase(NativeDatabase(File('${dir.path}/betterbudget.sqlite')));
      await seedDemoIfEmpty(db, today);
      backups = Backups(db);
    });
    tearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });

    test('choosing a folder writes the whole ledger there', () async {
      final cloud = CloudFolder(backups, access: _FakeAccess());
      await cloud.keepIn(drive.path, today);
      expect(cloud.value.path, drive.path);
      expect(cloud.value.copiedAt, today);
      expect(cloud.value.failing, isFalse);
      expect(await transactionsIn(copy()), (await db.loadLedger()).txns.length);
      // Nothing else is left in the folder, and nothing half-written.
      expect(drive.listSync().map((f) => f.path), [copy().path]);
      cloud.dispose();
    });

    test('the computer’s id waits for the saved settings: asked for before '
        'they are read, it doesn’t save over the folder', () async {
      final first = CloudFolder(backups, access: _FakeAccess());
      await first.load(today);
      await first.keepIn(drive.path, today);
      final id = await first.computerId();
      first.dispose();
      final settings = File('${dir.path}/cloud-folder');
      final saved = settings.readAsStringSync();
      expect(saved, contains(drive.path));

      // A new start: the id is asked for at once, the settings read after.
      final again = CloudFolder(backups, access: _FakeAccess());
      final loading = again.load(today);
      final asked = again.computerId();
      await loading;
      expect(await asked, id);
      expect(settings.readAsStringSync(), contains(drive.path));
      expect(again.value.path, drive.path);
      again.dispose();
    });

    test('a computer with no id takes the one worked out from its Mac and '
        'account; one that has an id keeps it', () async {
      final fixed = CloudFolder(backups, access: _DerivedAccess('guid-1'));
      await fixed.load(today);
      expect(await fixed.computerId(), 'guid-1');
      await fixed.keepIn(drive.path, today);
      fixed.dispose();

      // The settings were saved with it, and a different derivation
      // (another account) changes nothing for this computer.
      final again = CloudFolder(backups, access: _DerivedAccess('guid-2'));
      await again.load(today);
      expect(await again.computerId(), 'guid-1');
      again.dispose();
    });

    test('the worked-out id is a GUID, the same for the same Mac and '
        'account, and differs when either does', () {
      final a = FolderAccess.guidOf('MACHINE-1', '501');
      expect(
        a,
        matches(RegExp(r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$')),
      );
      expect(FolderAccess.guidOf('MACHINE-1', '501'), a);
      expect(FolderAccess.guidOf('MACHINE-1', '502'), isNot(a));
      expect(FolderAccess.guidOf('MACHINE-2', '501'), isNot(a));
    });

    test('only the ledger in a folder that isn’t the app’s own is one a '
        'computer can be kept on', () async {
      final cloud = CloudFolder(backups, access: _FakeAccess());
      expect(await cloud.folderOfLedger(copy().path), drive.path);
      // A backup under any other name, there or anywhere.
      expect(
        await cloud.folderOfLedger(
          '${drive.path}/BetterBudget 2026.10.07.betterbudget',
        ),
        isNull,
      );
      // The app's own working folder.
      expect(
        await cloud.folderOfLedger('${dir.path}/${CloudFolder.fileName}'),
        isNull,
      );
      cloud.dispose();
    });

    test('the file under its first name gives way to the new one', () async {
      final earlier = File('${drive.path}/${CloudFolder.earlierFileName}');
      await earlier.writeAsString('an earlier copy');
      final cloud = CloudFolder(backups, access: _FakeAccess());
      await cloud.keepIn(drive.path, today);
      expect(CloudFolder.fileName, 'Ledger.betterbudget');
      expect(copy().existsSync(), isTrue);
      expect(earlier.existsSync(), isFalse);
      cloud.dispose();
    });

    test(
      'the app’s own folder is refused, and the ledger there untouched',
      () async {
        // Under the name the app itself uses, a write here would land on the
        // open ledger.
        await db.close();
        final live = File('${dir.path}/${CloudFolder.fileName}');
        db = AppDatabase(NativeDatabase(live));
        await seedDemoIfEmpty(db, today);
        backups = Backups(db);
        final rows = (await db.loadLedger()).txns.length;
        final cloud = CloudFolder(backups, access: _FakeAccess());
        await expectLater(
          cloud.keepIn(dir.path, today),
          throwsA(isA<OwnFolderException>()),
        );
        expect(cloud.value.path, isNull);
        expect((await db.loadLedger()).txns.length, rows);
        // Nor does "Back up to…" write over it.
        await expectLater(backups.saveTo(live.path, today), throwsStateError);
        expect((await db.loadLedger()).txns.length, rows);
        cloud.dispose();
      },
    );

    test('moving to another folder leaves the ledger in the first', () async {
      // A phone may still be reading it (ADR 0005).
      final second = await Directory('${dir.path}/OneDrive/Budget')
          .create(recursive: true);
      final cloud = CloudFolder(backups, access: _FakeAccess());
      await cloud.keepIn(drive.path, today);
      await cloud.keepIn(second.path, today);
      expect(copy().existsSync(), isTrue);
      expect(
        File('${second.path}/${CloudFolder.fileName}').existsSync(),
        isTrue,
      );
      // Undo is the same move the other way.
      await cloud.keepIn(drive.path, today);
      expect(cloud.value.path, drive.path);
      expect(cloud.value.standing, FolderStanding.ok);
      cloud.dispose();
    });

    test(
      'a change made just before quitting is written on the way out',
      () async {
        final cloud = CloudFolder(
          backups,
          access: _FakeAccess(),
          wait: const Duration(minutes: 5),
        );
        await cloud.keepIn(drive.path, today);
        final later = today.add(const Duration(minutes: 1));
        await db.setPreference('budget.view', 'month');
        cloud.ledgerChanged(() => later);
        await cloud.flush();
        expect(cloud.value.copiedAt, later);
        // Nothing waiting: nothing written.
        await cloud.flush();
        expect(cloud.value.copiedAt, later);
        cloud.dispose();
      },
    );

    test(
      'a folder that can’t be opened at launch shows where it was, failing',
      () async {
        final access = _FakeAccess();
        final first = CloudFolder(backups, access: access);
        await first.keepIn(drive.path, today);
        first.dispose();
        await drive.delete(recursive: true);
        access.broken = true;
        final next = CloudFolder(backups, access: access);
        await next.load(today.add(const Duration(days: 1)));
        expect(next.value.path, drive.path);
        expect(next.value.failing, isTrue);
        expect(next.value.copiedAt, today);
        next.dispose();
      },
    );

    test('a change is copied once things have been quiet', () async {
      final cloud = CloudFolder(
        backups,
        access: _FakeAccess(),
        wait: const Duration(milliseconds: 30),
      );
      await cloud.keepIn(drive.path, today);
      final later = today.add(const Duration(minutes: 5));
      // Three changes in a row make one copy, stamped with the last.
      await db.setPreference('budget.view', 'month');
      cloud.ledgerChanged(() => today.add(const Duration(minutes: 1)));
      cloud.ledgerChanged(() => today.add(const Duration(minutes: 2)));
      cloud.ledgerChanged(() => later);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(cloud.value.copiedAt, later);
      cloud.dispose();
    });

    test(
      'the folder is remembered at the next launch, where it is now',
      () async {
        final access = _FakeAccess();
        final first = CloudFolder(backups, access: access);
        await first.keepIn(drive.path, today);
        first.dispose();

        // Renamed while the app was closed: the bookmark still finds it.
        final renamed = await drive.rename('${dir.path}/My Drive/Budget');
        access.movedTo = renamed.path;
        // Nothing changed meanwhile: the ledger there is this computer's
        // own, and isn't written again.
        final next = CloudFolder(backups, access: access);
        final tomorrow = today.add(const Duration(days: 1));
        await next.load(tomorrow);
        expect(next.value.path, renamed.path);
        expect(next.value.standing, FolderStanding.ok);
        expect(next.value.copiedAt, today);
        await db.setPreference('budget.view', 'month');
        next.ledgerChanged(() => tomorrow);
        await next.flush();
        expect(next.value.copiedAt, tomorrow);
        expect(
          File('${renamed.path}/${CloudFolder.fileName}').existsSync(),
          isTrue,
        );
        next.dispose();
      },
    );

    test('Stop leaves the copy and forgets the folder', () async {
      final access = _FakeAccess();
      final cloud = CloudFolder(backups, access: access);
      await cloud.keepIn(drive.path, today);
      await cloud.stop();
      expect(cloud.value.path, isNull);
      expect(copy().existsSync(), isTrue);
      cloud.ledgerChanged(() => today);

      final next = CloudFolder(backups, access: access);
      await next.load(today);
      expect(next.value.path, isNull);
      cloud.dispose();
      next.dispose();
    });

    test(
      'a folder that has gone shows as failing, with the last good time',
      () async {
        final cloud = CloudFolder(backups, access: _FakeAccess());
        await cloud.keepIn(drive.path, today);
        await drive.delete(recursive: true);
        await cloud.copyNow(today.add(const Duration(hours: 1)));
        expect(cloud.value.failing, isTrue);
        expect(cloud.value.copiedAt, today);
        expect(cloud.value.path, drive.path);
        cloud.dispose();
      },
    );

    test('a folder that can’t be written to is not taken', () async {
      final cloud = CloudFolder(backups, access: _FakeAccess());
      await cloud.keepIn(drive.path, today);
      await expectLater(
        cloud.keepIn('${dir.path}/not-there', today),
        throwsA(anything),
      );
      expect(cloud.value.path, drive.path);
      expect(cloud.value.failing, isFalse);
      cloud.dispose();
    });
  });

  group('Settings', () {
    setUpAll(() async {
      await _loadFont('Onest', 'assets/fonts/Onest-Variable.ttf');
      await _loadFont('Manrope', 'assets/fonts/Manrope-Variable.ttf');
      await _loadFont(
        'BetterBudget Symbols',
        'assets/fonts/BetterBudgetSymbols.ttf',
      );
      final icons =
          '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
      if (File(icons).existsSync()) await _loadFont('MaterialIcons', icons);
    });

    testWidgets(
      'says where the ledger is stored; move it to a folder, back, and undo',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final dialogs = _FakeDialogs();
        final before = FileSelectorPlatform.instance;
        FileSelectorPlatform.instance = dialogs;
        addTearDown(() => FileSelectorPlatform.instance = before);

        await tester.runAsync(() async {
          dir = await Directory.systemTemp.createTemp('bb-cloud-ui');
          drive = await Directory('${dir.path}/My Drive/BetterBudget')
              .create(recursive: true);
          db = AppDatabase(
            NativeDatabase(File('${dir.path}/betterbudget.sqlite')),
          );
        });
        final made = dir;
        addTearDown(() => made.deleteSync(recursive: true));
        dialogs.folder = drive.path;

        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(
              theme: appTheme(),
              home: LedgerScreen(
                demo: true,
                db: db,
                clock: () => today,
                folderAccess: _FakeAccess(),
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 400));
        });
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('settings')));
        await tester.pumpAndSettle();

        // Before a folder is picked: where the ledger is now, and the offer.
        expect(find.text('Stored in'), findsOneWidget);
        expect(find.text('This computer'), findsOneWidget);
        expect(find.text('Move my ledger to a folder…'), findsOneWidget);
        expect(find.byKey(const ValueKey('stop-folder')), findsNothing);

        Future<void> press(Finder f) async {
          await tester.runAsync(() async {
            await tester.tap(f);
            await Future<void>.delayed(const Duration(milliseconds: 400));
          });
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        }

        await press(find.byKey(const ValueKey('keep-in-folder')));
        expect(copy().existsSync(), isTrue);
        expect(
          find.text('My Drive/BetterBudget · Today 10:00'),
          findsOneWidget,
        );
        expect(
          find.text('Your ledger was moved to My Drive/BetterBudget'),
          findsOneWidget,
        );
        expect(find.text('Move to another folder…'), findsOneWidget);
        await expectLater(
          find.byType(LedgerScreen),
          matchesGoldenFile('goldens/settings_folder.png'),
        );

        await press(find.byKey(const ValueKey('stop-folder')));
        expect(find.text('This computer'), findsOneWidget);
        expect(
          find.text(
            'Your ledger is back on this computer · '
            'the file in My Drive/BetterBudget stays there',
          ),
          findsOneWidget,
        );
        expect(copy().existsSync(), isTrue);

        // A phone writes an entry to the folder while the ledger is away.
        await tester.runAsync(() async {
          final data = await db.loadLedger();
          int id(String name) =>
              data.accounts.values.singleWhere((a) => a.name == name).id;
          writePhoneInbox(
            File('${drive.path}/${phoneInboxName('ab12')}'),
            null,
            PhoneInbox(
              device: 'ab12',
              entries: [
                PhoneEntry(
                  id: 'e1',
                  categoryId: '${id('Groceries')}',
                  accountId: '${id('TDB Checking')}',
                  payee: 'From the phone',
                  amountMinor: -1250000,
                  date: today,
                  madeAt: today,
                ),
              ],
            ),
          );
        });

        // Ctrl+Z (⌘Z on a Mac) brings the folder back.
        await tester.runAsync(() async {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await Future<void>.delayed(const Duration(milliseconds: 400));
        });
        await tester.pump();
        expect(find.text('This computer'), findsNothing);
        expect(find.textContaining('My Drive/BetterBudget · '), findsOneWidget);
        // With the ledger in the folder again, the phone's entry comes in:
        // not over the popup that is up, but at the next look once it has
        // gone (here, the app coming back to the front).
        await tester.runAsync(() async {
          final rows = (await db.loadLedger()).txns.where(
            (t) => t.payee == 'From the phone',
          );
          expect(rows, isEmpty);
        });
        await tester.runAsync(() async {
          // The popup's own six seconds, on the real clock it was made on.
          await Future<void>.delayed(const Duration(milliseconds: 6500));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.runAsync(() async {
          for (final state in [
            AppLifecycleState.inactive,
            AppLifecycleState.hidden,
            AppLifecycleState.paused,
            AppLifecycleState.hidden,
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
          await Future<void>.delayed(const Duration(milliseconds: 400));
        });
        await tester.pump();
        expect(find.text('1 transaction from your phone'), findsOneWidget);
        await tester.runAsync(() async {
          final rows = (await db.loadLedger()).txns.where(
            (t) => t.payee == 'From the phone',
          );
          expect(rows, hasLength(1));
        });

        // ⌘Z doesn't reach it: that is for what the person did themselves
        // (here it takes the folder away again). The popup's own Undo does.
        await tester.runAsync(() async {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await Future<void>.delayed(const Duration(milliseconds: 400));
          final rows = (await db.loadLedger()).txns.where(
            (t) => t.payee == 'From the phone',
          );
          expect(rows, hasLength(1));
        });
        await tester.pump();

        // Leave nothing running: the screen's copy timer goes with it.
        await tester.runAsync(() async {
          await tester.pumpWidget(const SizedBox());
          await db.close();
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
      },
    );
  });

  group('two computers', () {
    setUpAll(() async {
      await _loadFont('Onest', 'assets/fonts/Onest-Variable.ttf');
      await _loadFont('Manrope', 'assets/fonts/Manrope-Variable.ttf');
      await _loadFont(
        'BetterBudget Symbols',
        'assets/fonts/BetterBudgetSymbols.ttf',
      );
      // As the Settings group does: the same icons whichever runs first.
      final icons =
          '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
      if (File(icons).existsSync()) await _loadFont('MaterialIcons', icons);
    });

    testWidgets('a newer ledger in the folder is opened; one changed '
        'apart is asked about, and nothing is written until then', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final dialogs = _FakeDialogs();
      final before = FileSelectorPlatform.instance;
      FileSelectorPlatform.instance = dialogs;
      addTearDown(() => FileSelectorPlatform.instance = before);

      late AppDatabase other;
      late Backups otherBackups;
      late CloudFolder otherCloud;
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('bb-two-ui');
        drive = await Directory('${dir.path}/My Drive/BetterBudget')
            .create(recursive: true);
        await Directory('${dir.path}/here').create();
        await Directory('${dir.path}/other').create();
        db = AppDatabase(
          NativeDatabase(File('${dir.path}/here/Ledger.betterbudget')),
        );
      });
      final made = dir;
      addTearDown(() => made.deleteSync(recursive: true));
      dialogs.folder = drive.path;

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: appTheme(),
            home: LedgerScreen(
              demo: true,
              db: db,
              clock: () => today,
              folderAccess: _FakeAccess(),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings')));
      await tester.pumpAndSettle();

      Future<void> press(Finder f) async {
        await tester.runAsync(() async {
          await tester.tap(f);
          await Future<void>.delayed(const Duration(milliseconds: 600));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      Future<void> comeBackToTheFront() async {
        await tester.runAsync(() async {
          // A popup still up holds an arrival back: its own six seconds,
          // on the real clock it was made on.
          await Future<void>.delayed(const Duration(milliseconds: 6500));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.runAsync(() async {
          for (final state in [
            AppLifecycleState.inactive,
            AppLifecycleState.hidden,
            AppLifecycleState.paused,
            AppLifecycleState.hidden,
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
          await Future<void>.delayed(const Duration(milliseconds: 900));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      Future<List<String?>> payees(AppDatabase of) async => [
        for (final t in (await of.loadLedger()).txns) t.payee,
      ];

      Future<void> spendOnTheOther(String payee) async {
        final data = await other.loadLedger();
        int id(String name) =>
            data.accounts.values.singleWhere((a) => a.name == name).id;
        await other.postSimple(
          accountId: id('TDB Checking'),
          date: today,
          today: today,
          payee: payee,
          counterAccountId: id('Groceries'),
          amount: -1250000,
        );
        expect(await otherCloud.check(today, fresh: true), FolderStanding.ok);
      }

      await press(find.byKey(const ValueKey('keep-in-folder')));
      expect(copy().existsSync(), isTrue);

      // A second computer opens the folder's ledger and spends.
      await tester.runAsync(() async {
        other = AppDatabase(
          NativeDatabase(File('${dir.path}/other/Ledger.betterbudget')),
        );
        await seedDemoIfEmpty(other, today);
        otherBackups = Backups(other);
        otherCloud = CloudFolder(otherBackups, access: _OtherAccess());
        await otherBackups.restore(
          await otherBackups.inspect(copy().path, today),
          today,
          fromFolder: true,
        );
        await otherCloud.keepIn(drive.path, today);
        expect(otherCloud.value.standing, FolderStanding.ok);
        await spendOnTheOther('Nomin');
      });

      // Nothing was changed here: the other's change comes in from its
      // file, and the popup says whose it was.
      await comeBackToTheFront();
      expect(find.text('1 transaction from The laptop'), findsOneWidget);
      expect(find.text('My Drive/BetterBudget · Today 10:00'), findsWidgets);
      await tester.runAsync(() async {
        expect(await payees(db), contains('Nomin'));
      });

      Future<void> rename(AppDatabase of, String from, String to) async {
        final data = await of.loadLedger();
        await of.renameAccount(
          data.accounts.values.singleWhere((a) => a.name == from).id,
          to,
        );
      }

      // Both change, each something the other didn't touch: the other's
      // spending is brought in here beside this computer's new name, and
      // nobody is asked.
      await tester.runAsync(() async {
        await spendOnTheOther('E-Mart');
        // And assigns more to Groceries than there is anywhere.
        final theirs = await other.loadLedger();
        await other.setBudgetAmount(
          theirs.accounts.values.singleWhere((a) => a.name == 'Groceries').id,
          DateTime(today.year, today.month),
          DateTime(today.year, today.month + 1, 0),
          9000000000,
        );
        expect(await otherCloud.check(today, fresh: true), FolderStanding.ok);
        await rename(db, 'Cash wallet', 'Wallet');
        // The same purchase, typed here too.
        final data = await db.loadLedger();
        int id(String name) =>
            data.accounts.values.singleWhere((a) => a.name == name).id;
        await db.postSimple(
          accountId: id('TDB Checking'),
          date: today,
          today: today,
          payee: 'EMART CHINGGIS',
          counterAccountId: id('Groceries'),
          amount: -1250000,
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await comeBackToTheFront();
      expect(
        find.text('1 transaction and other changes from The laptop'),
        findsOneWidget,
      );
      // Both rows are in; the popup says one looks the same, and that the
      // two together assign more than there is. The other computer's
      // changes aren't this person's to undo.
      final said = tester
          .widget<Text>(find.byKey(const ValueKey('toast-detail')))
          .data!
          .split('\n');
      expect(said.first, '1 looks the same as one already here');
      expect(said.last, endsWith(' more is assigned than you have'));
      expect(said.last, startsWith('₮'));
      expect(find.text('Undo'), findsNothing);
      expect(find.text('Show'), findsOneWidget);
      expect(
        find.text('Your ledger was changed on two computers'),
        findsNothing,
      );
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/two_combined.png'),
      );
      await tester.runAsync(() async {
        expect(await payees(db), containsAll(['Nomin', 'E-Mart']));
        // Both are in this computer's file now, and the other brings them
        // in.
        expect(
          await otherCloud.check(today, fresh: true),
          FolderStanding.combine,
        );
        expect(await otherCloud.bringIn(today), isNotNull);
        expect(await otherCloud.check(today, fresh: true), FolderStanding.ok);
        final data = await other.loadLedger();
        expect(data.accounts.values.map((a) => a.name), contains('Wallet'));
      });

      // Both give one category another name. That can't be combined, and
      // this computer writes nothing over the other's.
      late List<int> theirs;
      await tester.runAsync(() async {
        await rename(other, 'Groceries', 'Food');
        expect(await otherCloud.check(today, fresh: true), FolderStanding.ok);
        theirs = await copy().readAsBytes();
        await rename(db, 'Groceries', 'Supermarket');
        // The popup with Show stays twelve seconds, and holds the next
        // arrival back until it has gone.
        await Future<void>.delayed(const Duration(seconds: 6));
      });
      await tester.pump();
      await comeBackToTheFront();
      expect(
        find.text('Your ledger was changed on two computers'),
        findsOneWidget,
      );
      expect(find.text('Saved on The laptop · Today 10:00'), findsOneWidget);
      await tester.runAsync(() async {
        expect(await copy().readAsBytes(), theirs);
      });
      // The whole app: the question is drawn over the screen, not in it.
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/two_ledgers.png'),
      );

      // Put off: Settings says so, and offers the question again.
      await tester.tap(find.byKey(const ValueKey('two-not-now')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'My Drive/BetterBudget · changed on another computer too · '
          'this computer’s changes aren’t in the folder',
        ),
        findsOneWidget,
      );
      await tester.runAsync(() async {
        expect(await copy().readAsBytes(), theirs);
      });
      await expectLater(
        find.byType(LedgerScreen),
        matchesGoldenFile('goldens/settings_folder_apart.png'),
      );

      await press(find.byKey(const ValueKey('choose-ledger')));
      await press(find.byKey(const ValueKey('two-use-mine')));
      expect(
        find.text(
          'This computer’s ledger is now in My Drive/BetterBudget · '
          'the one that was there is saved in Backups',
        ),
        findsOneWidget,
      );
      await tester.runAsync(() async {
        expect(await copy().readAsBytes(), isNot(theirs));
        // The other computer's is kept, whole.
        final kept = Directory('${dir.path}/here/Backups')
            .listSync()
            .whereType<File>()
            .singleWhere((f) => f.path.contains('from-folder-'));
        expect(await kept.readAsBytes(), theirs);
      });

      // On change files the choice went out to the other computer the
      // moment it was made: nothing to take back, so the popup has no Undo;
      // the other computer takes the choice instead of being asked.
      expect(find.text('Undo'), findsNothing);
      expect(find.byKey(const ValueKey('choose-ledger')), findsNothing);
      await tester.runAsync(() async {
        expect(
          await otherCloud.check(today, fresh: true),
          FolderStanding.combine,
        );
        expect(await otherCloud.bringIn(today), isNotNull);
        expect(await otherCloud.check(today, fresh: true), FolderStanding.ok);
        final names = (await other.loadLedger()).accounts.values.map(
          (a) => a.name,
        );
        expect(names, contains('Supermarket'));
        expect(names, isNot(contains('Food')));
      });

      await tester.runAsync(() async {
        await tester.pumpWidget(const SizedBox());
        otherCloud.dispose();
        await other.close();
        await db.close();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
    });
    testWidgets('one row changed two ways on the two computers is asked '
        'about with both amounts, and the rest comes in with the answer', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final dialogs = _FakeDialogs();
      final before = FileSelectorPlatform.instance;
      FileSelectorPlatform.instance = dialogs;
      addTearDown(() => FileSelectorPlatform.instance = before);

      late AppDatabase other;
      late Backups otherBackups;
      late CloudFolder otherCloud;
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('bb-two-ui');
        drive = await Directory('${dir.path}/My Drive/BetterBudget')
            .create(recursive: true);
        await Directory('${dir.path}/here').create();
        await Directory('${dir.path}/other').create();
        db = AppDatabase(
          NativeDatabase(File('${dir.path}/here/Ledger.betterbudget')),
        );
      });
      final made = dir;
      addTearDown(() => made.deleteSync(recursive: true));
      dialogs.folder = drive.path;

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: appTheme(),
            home: LedgerScreen(
              demo: true,
              db: db,
              clock: () => today,
              folderAccess: _FakeAccess(),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings')));
      await tester.pumpAndSettle();

      Future<void> press(Finder f) async {
        await tester.runAsync(() async {
          await tester.tap(f);
          await Future<void>.delayed(const Duration(milliseconds: 600));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      Future<void> comeBackToTheFront() async {
        await tester.runAsync(() async {
          // A popup still up holds an arrival back: its own six seconds,
          // on the real clock it was made on.
          await Future<void>.delayed(const Duration(milliseconds: 6500));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.runAsync(() async {
          for (final state in [
            AppLifecycleState.inactive,
            AppLifecycleState.hidden,
            AppLifecycleState.paused,
            AppLifecycleState.hidden,
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
          await Future<void>.delayed(const Duration(milliseconds: 900));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      Future<List<String?>> payees(AppDatabase of) async => [
        for (final t in (await of.loadLedger()).txns) t.payee,
      ];

      Future<void> spendOnTheOther(String payee) async {
        final data = await other.loadLedger();
        int id(String name) =>
            data.accounts.values.singleWhere((a) => a.name == name).id;
        await other.postSimple(
          accountId: id('TDB Checking'),
          date: today,
          today: today,
          payee: payee,
          counterAccountId: id('Groceries'),
          amount: -1250000,
        );
        expect(await otherCloud.check(today, fresh: true), FolderStanding.ok);
      }

      await press(find.byKey(const ValueKey('keep-in-folder')));
      expect(copy().existsSync(), isTrue);

      // A second computer opens the folder's ledger and spends.
      await tester.runAsync(() async {
        other = AppDatabase(
          NativeDatabase(File('${dir.path}/other/Ledger.betterbudget')),
        );
        await seedDemoIfEmpty(other, today);
        otherBackups = Backups(other);
        otherCloud = CloudFolder(otherBackups, access: _OtherAccess());
        await otherBackups.restore(
          await otherBackups.inspect(copy().path, today),
          today,
          fromFolder: true,
        );
        await otherCloud.keepIn(drive.path, today);
        expect(otherCloud.value.standing, FolderStanding.ok);
        await spendOnTheOther('Nomin');
      });

      // Nothing was changed here: the other's change comes in from its
      // file, and the popup says whose it was.
      await comeBackToTheFront();
      expect(find.text('1 transaction from The laptop'), findsOneWidget);
      expect(find.text('My Drive/BetterBudget · Today 10:00'), findsWidgets);
      await tester.runAsync(() async {
        expect(await payees(db), contains('Nomin'));
      });

      // Both give the one purchase another amount, and the other spends
      // something more.
      late int id;
      await tester.runAsync(() async {
        Future<int> edit(AppDatabase of, int amount) async {
          final data = await of.loadLedger();
          final t = data.txns.singleWhere((t) => t.payee == 'Nomin');
          int account(String name) =>
              data.accounts.values.singleWhere((a) => a.name == name).id;
          await of.editTransaction(
            transactionId: t.id,
            accountId: account('TDB Checking'),
            date: today,
            today: today,
            payee: 'Nomin',
            counterAccountId: account('Groceries'),
            amount: amount,
          );
          return t.id;
        }

        await edit(other, -2100000);
        await spendOnTheOther('E-Mart');
        id = await edit(db, -1700000);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await comeBackToTheFront();
      expect(
        find.text('2 things were changed on both computers'),
        findsNothing,
      );
      expect(
        find.text('One thing was changed on both computers'),
        findsOneWidget,
      );
      expect(find.text('Nomin'), findsWidgets);
      expect(find.textContaining('17,000'), findsWidgets);
      expect(find.textContaining('21,000'), findsWidgets);
      await tester.runAsync(() async {
        // Nothing has come in, and nothing is written over the other's.
        expect(await payees(db), isNot(contains('E-Mart')));
      });
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/two_rows.png'),
      );

      // Put off, and the Settings line says so.
      await tester.tap(find.byKey(const ValueKey('rows-not-now')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'My Drive/BetterBudget · changed on another computer too · '
          'this computer’s changes aren’t in the folder',
        ),
        findsOneWidget,
      );

      // The other's amount, as chosen; the rest comes in with it.
      await press(find.byKey(const ValueKey('choose-ledger')));
      await press(find.byKey(ValueKey('rows-transaction|$id-theirs')));
      await press(find.byKey(const ValueKey('rows-save')));
      expect(
        find.text('1 transaction and other changes from The laptop'),
        findsOneWidget,
      );
      expect(find.text('Undo'), findsNothing);
      await tester.runAsync(() async {
        expect(await payees(db), containsAll(['Nomin', 'E-Mart']));
        final data = await db.loadLedger();
        final nomin = data.txns.singleWhere((t) => t.payee == 'Nomin');
        expect(nomin.entries.map((e) => e.amount), contains(-2100000));
        // Written to the folder, and the other computer has it as it is.
        expect(await otherCloud.check(today, fresh: true), FolderStanding.ok);
      });

      await tester.runAsync(() async {
        await tester.pumpWidget(const SizedBox());
        otherCloud.dispose();
        await other.close();
        await db.close();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
    });
    testWidgets('a second computer is set up in one step: Restore from… the '
        'folder’s ledger keeps this computer on it, and nothing is asked', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final dialogs = _FakeDialogs();
      final before = FileSelectorPlatform.instance;
      FileSelectorPlatform.instance = dialogs;
      addTearDown(() => FileSelectorPlatform.instance = before);

      // The first computer has its ledger in the folder already.
      late AppDatabase other;
      late Backups otherBackups;
      late CloudFolder otherCloud;
      late List<int> theirs;
      Future<void> spendOnTheOther(String payee) async {
        final data = await other.loadLedger();
        int id(String name) =>
            data.accounts.values.singleWhere((a) => a.name == name).id;
        await other.postSimple(
          accountId: id('TDB Checking'),
          date: today,
          today: today,
          payee: payee,
          counterAccountId: id('Groceries'),
          amount: -1250000,
        );
        expect(await otherCloud.check(today, fresh: true), FolderStanding.ok);
      }

      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('bb-second');
        drive = await Directory('${dir.path}/My Drive/BetterBudget')
            .create(recursive: true);
        await Directory('${dir.path}/here').create();
        await Directory('${dir.path}/other').create();
        other = AppDatabase(
          NativeDatabase(File('${dir.path}/other/Ledger.betterbudget')),
        );
        await seedDemoIfEmpty(other, today);
        otherBackups = Backups(other);
        otherCloud = CloudFolder(otherBackups, access: _OtherAccess());
        await otherCloud.keepIn(drive.path, today);
        await spendOnTheOther('Nomin');
        theirs = await copy().readAsBytes();
        // The dialog says when it was saved: a set time, for the picture.
        await copy().setLastModified(DateTime(2026, 10, 7, 9, 30));
        db = AppDatabase(
          NativeDatabase(File('${dir.path}/here/Ledger.betterbudget')),
        );
      });
      final made = dir;
      addTearDown(() => made.deleteSync(recursive: true));

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: appTheme(),
            home: LedgerScreen(
              demo: true,
              db: db,
              clock: () => today,
              folderAccess: _FakeAccess(),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings')));
      await tester.pumpAndSettle();

      Future<void> press(Finder f) async {
        await tester.runAsync(() async {
          await tester.tap(f);
          await Future<void>.delayed(const Duration(milliseconds: 600));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      Future<List<String?>> payees(AppDatabase of) async => [
        for (final t in (await of.loadLedger()).txns) t.payee,
      ];
      // Ctrl+Z (⌘Z on a Mac). Not the popup's Undo: a popup stays while
      // the pointer that clicked it is still on it.
      Future<void> undo() async {
        await tester.runAsync(() async {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await Future<void>.delayed(const Duration(milliseconds: 900));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      const keepOn = 'Share the ledger in My Drive/BetterBudget';
      const onFolder =
          'This computer is now on the ledger in My Drive/BetterBudget';

      // A backup picked anywhere else is only a backup: nothing is offered.
      await tester.runAsync(() async {
        await copy().copy('${dir.path}/Ledger copy.betterbudget');
      });
      dialogs.openPath = '${dir.path}/Ledger copy.betterbudget';
      await press(find.byKey(const ValueKey('restore')));
      expect(find.text('Restore this backup?'), findsOneWidget);
      expect(find.text(keepOn), findsNothing);
      await press(find.byKey(const ValueKey('restore-cancel')));

      // The folder's own ledger: the dialog offers to keep this computer on
      // it, ticked.
      dialogs.openPath = copy().path;
      await press(find.byKey(const ValueKey('restore')));
      expect(find.text(keepOn), findsOneWidget);
      // It is the ledger in use, not a backup, and is called that.
      expect(find.text('Bring this ledger here?'), findsOneWidget);
      expect(find.text('Last changed'), findsOneWidget);
      expect(
        find.text(
          'What you change here goes to My Drive/BetterBudget, and what is '
          'changed on another computer comes here. Your Mac asks for the '
          'folder next: press Use This Folder.',
        ),
        findsOneWidget,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/restore_keep_on_folder.png'),
      );

      // Unticked, it is a restore and no more, and the dialog says what
      // that leaves.
      await press(find.byKey(const ValueKey('restore-keep-on-folder')));
      expect(
        find.text(
          'This computer gets its own copy. What you change here won’t '
          'reach My Drive/BetterBudget.',
        ),
        findsOneWidget,
      );
      await press(find.byKey(const ValueKey('restore-confirm')));
      expect(dialogs.openedOn, isEmpty);
      expect(find.textContaining('Restored the copy from'), findsOneWidget);
      expect(find.text('This computer'), findsOneWidget);
      await tester.runAsync(() async {
        expect(await payees(db), contains('Nomin'));
      });
      await undo();
      await tester.runAsync(() async {
        expect(await payees(db), isNot(contains('Nomin')));
        await Future<void>.delayed(const Duration(milliseconds: 6500));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Ticked. The Mac's folder dialog opens on the folder; closed without
      // choosing it, the question is back and nothing was done.
      await press(find.byKey(const ValueKey('restore')));
      dialogs.folder = null;
      await press(find.byKey(const ValueKey('restore-confirm')));
      expect(dialogs.openedOn, [drive.path]);
      expect(find.text(keepOn), findsOneWidget);
      await tester.runAsync(() async {
        expect(await payees(db), isNot(contains('Nomin')));
      });

      // The first computer saves again while the question is open: the
      // file picked is no longer the folder's newest.
      await tester.runAsync(() async {
        await spendOnTheOther('Minii Delguur');
        theirs = await copy().readAsBytes();
      });

      // Chosen: the ledger is here, the later one, this computer is on the
      // folder, and nobody is asked which ledger to keep.
      dialogs.folder = drive.path;
      await press(find.byKey(const ValueKey('restore-confirm')));
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('$onFolder · what you had is saved'), findsOneWidget);
      expect(
        find.text('Your ledger was changed on two computers'),
        findsNothing,
      );
      expect(find.text('This computer'), findsNothing);
      expect(find.textContaining('My Drive/BetterBudget · '), findsWidgets);
      await tester.runAsync(() async {
        expect(await payees(db), containsAll(['Nomin', 'Minii Delguur']));
        // The first computer's file is as it left it.
        expect(await copy().readAsBytes(), theirs);
      });

      // Undo takes this computer off the folder before putting back what
      // it had: that never reaches the ledger the two share.
      await undo();
      expect(find.text('Undone · $onFolder'), findsOneWidget);
      expect(find.text('This computer'), findsOneWidget);
      await tester.runAsync(() async {
        expect(await payees(db), isNot(contains('Nomin')));
        await Future<void>.delayed(const Duration(milliseconds: 6000));
        expect(await copy().readAsBytes(), theirs);
        // And the first computer goes on meanwhile.
        await spendOnTheOther('Sansar');
      });
      await tester.pump();

      // Redo: on the folder again, with the ledger that is there now.
      await tester.runAsync(() async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await Future<void>.delayed(const Duration(milliseconds: 900));
        expect(await payees(db), containsAll(['Nomin', 'Sansar']));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('This computer'), findsNothing);
      expect(
        find.text('Your ledger was changed on two computers'),
        findsNothing,
      );

      // From here the two are two computers on one ledger: what the first
      // spends next arrives here.
      await tester.runAsync(() async {
        // Anything this computer scheduled has been written by now.
        await Future<void>.delayed(const Duration(milliseconds: 6500));
        var standing = await otherCloud.check(today, fresh: true);
        if (standing == FolderStanding.newer) {
          await otherBackups.restore(
            await otherBackups.inspect(otherCloud.theirs!.copy.path, today),
            today,
            fromFolder: true,
          );
          standing = await otherCloud.check(today, fresh: true);
        }
        expect(standing, FolderStanding.ok);
        await spendOnTheOther('E-Mart');
      });
      // The popup has had its six seconds, and goes.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(() async {
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await Future<void>.delayed(const Duration(milliseconds: 900));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Your ledger was changed on two computers'),
        findsNothing,
      );
      await tester.runAsync(() async {
        expect(await payees(db), containsAll(['Nomin', 'Sansar', 'E-Mart']));
      });

      await tester.runAsync(() async {
        await tester.pumpWidget(const SizedBox());
        otherCloud.dispose();
        await other.close();
        await db.close();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
    });
    testWidgets('Open ledger on a new computer: one pick of the folder brings '
        'the ledger here and keeps this computer on it', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final dialogs = _FakeDialogs();
      final before = FileSelectorPlatform.instance;
      FileSelectorPlatform.instance = dialogs;
      addTearDown(() => FileSelectorPlatform.instance = before);

      late AppDatabase other;
      late CloudFolder otherCloud;
      late List<int> theirs;
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('bb-open');
        drive = await Directory('${dir.path}/My Drive/BetterBudget')
            .create(recursive: true);
        await Directory('${dir.path}/My Drive/Photos').create();
        await Directory('${dir.path}/here').create();
        await Directory('${dir.path}/other').create();
        other = AppDatabase(
          NativeDatabase(File('${dir.path}/other/Ledger.betterbudget')),
        );
        await seedDemoIfEmpty(other, today);
        otherCloud = CloudFolder(Backups(other), access: _OtherAccess());
        await otherCloud.keepIn(drive.path, today);
        theirs = await copy().readAsBytes();
        // Nothing here yet: a new computer.
        db = AppDatabase(
          NativeDatabase(File('${dir.path}/here/Ledger.betterbudget')),
        );
      });
      final made = dir;
      addTearDown(() => made.deleteSync(recursive: true));

      // A folder with no ledger in it is picked first: nothing is written
      // there, it says so, and asks again.
      final photos = '${dir.path}/My Drive/Photos';
      dialogs.folder = photos;
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: appTheme(),
            home: LedgerScreen(
              db: db,
              clock: () => today,
              folderAccess: _FakeAccess(),
              offerRestore: true,
              startFrom: StartFrom.folder,
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 800));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.textContaining('There’s no ledger in My Drive/Photos'),
        findsOneWidget,
      );
      expect(find.text('Where is your ledger?'), findsOneWidget);
      expect(Directory(photos).listSync(), isEmpty);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/where_is_your_ledger.png'),
      );

      // My Drive itself is pointed to: the one folder in it that holds a
      // ledger is the one meant. The ledger is here, nothing was asked about
      // what it replaced (nothing was here), and this computer is on the
      // folder.
      dialogs.folder = '${dir.path}/My Drive';
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('offer-restore-folder')));
        await Future<void>.delayed(const Duration(milliseconds: 900));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(Dialog), findsNothing);
      expect(
        find.text(
          'This computer is now on the ledger in My Drive/BetterBudget',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Your ledger was changed on two computers'),
        findsNothing,
      );
      await tester.runAsync(() async {
        final here = await db.loadLedger();
        expect(here.txns.length, (await other.loadLedger()).txns.length);
        expect(await copy().readAsBytes(), theirs);
      });
      await tester.tap(find.byKey(const ValueKey('settings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('My Drive/BetterBudget · '), findsWidgets);

      await tester.runAsync(() async {
        await tester.pumpWidget(const SizedBox());
        otherCloud.dispose();
        await other.close();
        await db.close();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
    });
  });
}
