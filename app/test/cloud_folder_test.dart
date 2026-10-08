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

  /// The bookmark no longer opens anything.
  bool broken = false;

  @override
  Future<String?> remember(String path) async => 'token:$path';

  @override
  Future<({String path, String? token})?> open(String token) async {
    if (broken) throw StateError('the bookmark is no good');
    return (path: movedTo ?? token.substring('token:'.length), token: null);
  }
}

class _FakeDialogs extends FileSelectorPlatform {
  String? folder;

  @override
  Future<String?> getDirectoryPath({
    String? initialDirectory,
    String? confirmButtonText,
  }) async => folder;
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

    test(
      'moving to another folder takes the ledger out of the first',
      () async {
        final second = await Directory('${dir.path}/OneDrive/Budget')
            .create(recursive: true);
        final cloud = CloudFolder(backups, access: _FakeAccess());
        await cloud.keepIn(drive.path, today);
        await cloud.keepIn(second.path, today);
        expect(copy().existsSync(), isFalse);
        expect(
          File('${second.path}/${CloudFolder.fileName}').existsSync(),
          isTrue,
        );
        // Undo is the same move the other way.
        await cloud.keepIn(drive.path, today);
        expect(copy().existsSync(), isTrue);
        expect(
          File('${second.path}/${CloudFolder.fileName}').existsSync(),
          isFalse,
        );
        cloud.dispose();
      },
    );

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
        final next = CloudFolder(backups, access: access);
        final tomorrow = today.add(const Duration(days: 1));
        await next.load(tomorrow);
        expect(next.value.path, renamed.path);
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
        // With the ledger in the folder again, the phone's entry comes in.
        await tester.runAsync(() async {
          final rows = (await db.loadLedger()).txns.where(
            (t) => t.payee == 'From the phone',
          );
          expect(rows, hasLength(1));
        });

        // Leave nothing running: the screen's copy timer goes with it.
        await tester.runAsync(() async {
          await tester.pumpWidget(const SizedBox());
          await db.close();
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
      },
    );
  });
}
