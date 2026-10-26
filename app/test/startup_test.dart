// What happens at launch (ADR 0001): a key is checked against the ledger
// before it's stored, a new key is shown before anything is stored or
// encrypted, and a ledger already here is never opened with a new key.
import 'dart:convert';
import 'dart:io';

import 'package:betterbudget/data/backup.dart';
import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/data/encryption.dart';
import 'package:betterbudget/data/keys.dart';
import 'package:betterbudget/domain/ledger.dart' show AccountType;
import 'package:betterbudget/ui/ledger_screen.dart';
import 'package:betterbudget/ui/recovery_key_screen.dart';
import 'package:betterbudget/ui/start_choice.dart';
import 'package:betterbudget/ui/startup.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart' show LinkDelegate;
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _FakeSecureStorage extends FlutterSecureStoragePlatform {
  final values = <String, String>{};

  /// Thrown by every read while set, as the Keychain does on a locked Mac.
  PlatformException? refuse;

  /// Thrown by every write while set.
  PlatformException? refuseWrite;

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    if (refuseWrite case final e?) throw e;
    values[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    if (refuse case final e?) throw e;
    return values[key];
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => values.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => values.remove(key);

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(values);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      values.clear();
}

/// The system's open and folder dialogs: cancelled, unless given what was
/// picked.
class _CancelledDialogs extends FileSelectorPlatform {
  var opened = 0;
  var folders = 0;
  String? openPath;
  String? folder;

  @override
  Future<String?> getDirectoryPath({
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    folders++;
    return folder;
  }

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    opened++;
    return openPath == null ? null : XFile(openPath!);
  }
}

/// The browser Report a problem… opens; [opens] false is one that won't.
class _FakeBrowser extends UrlLauncherPlatform {
  final opened = <String>[];
  var opens = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened.add(url);
    return opens;
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
  final now = DateTime(2026, 9, 16, 10);
  late Directory dir;
  late File file;
  late _FakeSecureStorage storage;
  final opened = <AppDatabase>[];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('bb-startup');
    file = File('${dir.path}/betterbudget.sqlite');
    storage = _FakeSecureStorage();
    FlutterSecureStoragePlatform.instance = storage;
  });
  tearDown(() async {
    opened.clear();
    await dir.delete(recursive: true);
  });

  /// Unmounts the app, then closes what it opened, outside the fake clock
  /// (real SQLite work never finishes under it).
  Future<void> tidy(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
      for (final db in opened) {
        await db.close();
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  }

  Future<OpenedLedger> open(Uint8List key) async {
    await prepareLedgerFile(file, key);
    final db = AppDatabase(
      NativeDatabase(file, setup: (raw) => applyCipherKey(raw, key)),
    );
    opened.add(db);
    final backups = Backups(db, dataKey: key);
    return (
      db: db,
      backups: backups,
      report: await backups.convertPlainBackups(),
      startDaily: () {},
    );
  }

  /// A ledger with demo rows, encrypted with [recovery]'s key, or plain.
  Future<void> makeLedger({RecoveryKey? recovery, File? at}) async {
    final key = recovery == null ? null : deriveDataKey(recovery);
    final db = AppDatabase(
      NativeDatabase(
        at ?? file,
        setup: key == null ? null : (raw) => applyCipherKey(raw, key),
      ),
    );
    await seedDemoIfEmpty(db, now);
    await db.close();
  }

  /// Waits, in real time, until [ready] (the next screen is up), so a slow
  /// machine doesn't turn into a failure or a hang.
  Future<void> until(WidgetTester tester, bool Function() ready) async {
    for (var i = 0; i < 150; i++) {
      await tester.pump();
      if (ready()) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
    fail('Timed out waiting for the next screen');
  }

  bool shown(Finder f) => f.evaluate().isNotEmpty;

  final failed = find.byKey(const ValueKey('startup-failed'));

  /// Launches with [opener] in place of [open], until a screen is up.
  Future<void> launch(
    WidgetTester tester, {
    Future<OpenedLedger> Function(Uint8List key)? opener,
  }) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        BetterBudgetStartup(
          store: KeyStore(),
          ledgerFile: file,
          open: opener ?? open,
          clock: () => now,
        ),
      );
    });
    await until(
      tester,
      () =>
          shown(find.byType(RecoveryKeySetupScreen)) ||
          shown(find.byType(RecoveryKeyEntryScreen)) ||
          shown(find.byType(StartChoiceScreen)) ||
          shown(find.byType(LedgerScreen)) ||
          shown(failed),
    );
  }

  Future<void> tapAndWait(WidgetTester tester, Finder f) async {
    await tester.runAsync(() async {
      await tester.tap(f);
      await Future<void>.delayed(const Duration(milliseconds: 800));
    });
    await tester.pump();
    await tester.pump();
  }

  /// On the first screen of a computer with no ledger: opens one of the
  /// ways that need the key ('start-restore', 'start-open').
  Future<void> choose(WidgetTester tester, String way) async {
    await tapAndWait(tester, find.byKey(ValueKey(way)));
    expect(find.byKey(ValueKey('$way-open')), findsOne);
  }

  Future<void> typeKey(WidgetTester tester, RecoveryKey k) async {
    await tester.enterText(
      find.byKey(const ValueKey('recovery-key-field')),
      k.display,
    );
    await tapAndWait(tester, find.byKey(const ValueKey('recovery-key-submit')));
  }

  testWidgets('a plain ledger: the key is shown before anything is stored', (
    tester,
  ) async {
    await tester.runAsync(makeLedger);
    await launch(tester);
    expect(find.byType(RecoveryKeySetupScreen), findsOne);
    expect(find.byKey(const ValueKey('recovery-key-old-copies')), findsOne);
    // Quitting here would leave everything as it was.
    expect(storage.values, isEmpty);
    expect(await tester.runAsync(() => isPlainSqliteFile(file)), isTrue);

    await tapAndWait(
      tester,
      find.byKey(const ValueKey('recovery-key-continue')),
    );
    await until(tester, () => shown(find.byType(LedgerScreen)));
    expect(storage.values['betterbudget.dataKey'], isNotNull);
    expect(storage.values['betterbudget.recoveryKeySaved'], '0');
    expect(await tester.runAsync(() => isPlainSqliteFile(file)), isFalse);
    await tidy(tester);
  });

  testWidgets('an encrypted ledger: only its own key is kept', (tester) async {
    final recovery = RecoveryKey.generate();
    await tester.runAsync(() => makeLedger(recovery: recovery));
    await launch(tester);
    expect(find.textContaining('There’s a ledger on this computer'), findsOne);
    expect(find.text('Start a new ledger instead…'), findsOne);

    await typeKey(tester, RecoveryKey.generate());
    await until(
      tester,
      () =>
          shown(find.text('That key doesn’t open the ledger on this computer')),
    );
    expect(
      find.text('That key doesn’t open the ledger on this computer'),
      findsOne,
    );
    expect(storage.values, isEmpty);

    await typeKey(tester, recovery);
    await until(tester, () => shown(find.byType(LedgerScreen)));
    expect(find.byType(LedgerScreen), findsOne);
    expect(storage.values['betterbudget.dataKey'], isNotNull);
    expect(storage.values['betterbudget.recoveryKeySaved'], '1');
    await tidy(tester);
  });

  testWidgets(
    'a stored key that no longer fits asks again, not a blank window',
    (tester) async {
      await tester.runAsync(() => makeLedger(recovery: RecoveryKey.generate()));
      await tester.runAsync(
        () => KeyStore().writeDataKey(deriveDataKey(RecoveryKey.generate())),
      );
      await launch(tester);
      expect(
        find.textContaining('The key kept on this computer doesn’t open'),
        findsOne,
      );
      await tidy(tester);
    },
  );

  testWidgets('a key the Keychain refuses says so, with Try again, not a '
      'blank window', (tester) async {
    final recovery = RecoveryKey.generate();
    await tester.runAsync(() => makeLedger(recovery: recovery));
    await tester.runAsync(
      () => KeyStore().writeDataKey(deriveDataKey(recovery)),
    );
    storage.refuse = PlatformException(
      code: 'Unexpected security result code',
      message: 'Code: -25308, Message: User interaction is not allowed.',
    );
    final before = file.readAsBytesSync();
    await launch(tester);
    expect(failed, findsOne);
    expect(find.text('Couldn’t read the key kept on this computer'), findsOne);
    expect(find.text('Your ledger hasn’t been touched.'), findsOne);
    // The error itself waits behind a click.
    expect(find.textContaining('-25308'), findsNothing);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/startup_failed.png'),
    );
    await tester.tap(find.byKey(const ValueKey('startup-show-details')));
    await tester.pump();
    expect(find.textContaining('-25308'), findsOne);
    expect(find.byKey(const ValueKey('startup-show-details')), findsNothing);
    expect(file.readAsBytesSync(), before);

    // Unlocked: Try again opens the ledger without a relaunch.
    storage.refuse = null;
    await tapAndWait(tester, find.byKey(const ValueKey('startup-try-again')));
    await until(tester, () => shown(find.byType(LedgerScreen)));
    expect(find.byType(LedgerScreen), findsOne);
    await tidy(tester);
  });

  testWidgets('a ledger that fails to open says so, and Try again opens it', (
    tester,
  ) async {
    final recovery = RecoveryKey.generate();
    await tester.runAsync(() => makeLedger(recovery: recovery));
    await tester.runAsync(
      () => KeyStore().writeDataKey(deriveDataKey(recovery)),
    );
    var tries = 0;
    await launch(
      tester,
      opener: (key) async {
        final o = await open(key);
        // Opened, then a later step fails: the one opened is closed.
        if (tries++ == 0) throw const FileSystemException('The disk is busy');
        return o;
      },
    );
    expect(find.text('Couldn’t open your ledger'), findsOne);

    // Report a problem… opens lls.mn's form; a browser that won't open it
    // leaves the address on the screen.
    final browser = _FakeBrowser()..opens = false;
    final before = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = browser;
    addTearDown(() => UrlLauncherPlatform.instance = before);
    await tester.tap(find.byKey(const ValueKey('report-problem')));
    await until(tester, () => browser.opened.isNotEmpty);
    await tester.pump();
    final link = Uri.parse(browser.opened.single);
    expect('${link.host}${link.path}', 'lls.mn/en/contact/');
    expect(link.queryParameters['from'], 'betterbudget');
    expect(
      find.text('The browser didn’t open. The form is at lls.mn/en/contact.'),
      findsOne,
    );

    await tapAndWait(tester, find.byKey(const ValueKey('startup-try-again')));
    await until(tester, () => shown(find.byType(LedgerScreen)));
    expect(tries, 2);
    await tidy(tester);
  });

  testWidgets('a new key that can’t be kept says nothing was encrypted, and '
      'Try again keeps the same key', (tester) async {
    await tester.runAsync(makeLedger);
    await launch(tester);
    expect(find.byType(RecoveryKeySetupScreen), findsOne);
    storage.refuseWrite = PlatformException(code: 'write refused');
    await tapAndWait(
      tester,
      find.byKey(const ValueKey('recovery-key-continue')),
    );
    await until(tester, () => shown(failed));
    expect(find.text('Couldn’t keep the key on this computer'), findsOne);
    expect(find.text('Nothing was encrypted.'), findsOne);
    expect(storage.values, isEmpty);
    expect(await tester.runAsync(() => isPlainSqliteFile(file)), isTrue);
    await tester.tap(find.byKey(const ValueKey('startup-show-details')));
    await tester.pump();
    // Only the error's type, never what was being stored.
    expect(
      tester
          .widget<SelectableText>(find.byKey(const ValueKey('startup-details')))
          .data,
      'PlatformException',
    );
    final copied = _catchClipboard(tester);
    await tester.tap(find.byKey(const ValueKey('copy-details')));
    await tester.pump();
    expect(copied, [
      'Couldn’t keep the key on this computer\n\nPlatformException',
    ]);
    expect(find.text('Copied'), findsOne);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/startup_failed_details.png'),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Copy'), findsOne);

    storage.refuseWrite = null;
    await tapAndWait(tester, find.byKey(const ValueKey('startup-try-again')));
    await until(tester, () => shown(find.byType(LedgerScreen)));
    // The key that was shown is the one kept, and it opens the ledger.
    final kept = storage.values['betterbudget.dataKey']!;
    expect(keyOpens(file, Uint8List.fromList(base64Decode(kept))), isTrue);
    expect(await tester.runAsync(() => isPlainSqliteFile(file)), isFalse);
    await tidy(tester);
  });

  testWidgets(
    'starting new with a ledger here moves it aside, never opens it',
    (tester) async {
      await tester.runAsync(() => makeLedger(recovery: RecoveryKey.generate()));
      final before = file.lengthSync();
      await launch(tester);
      await tapAndWait(
        tester,
        find.byKey(const ValueKey('recovery-key-generate-new')),
      );
      expect(find.text('Start a new ledger?'), findsOne);
      await tapAndWait(tester, find.byKey(const ValueKey('set-aside-confirm')));
      await until(tester, () => shown(find.byType(RecoveryKeySetupScreen)));
      expect(find.byType(RecoveryKeySetupScreen), findsOne);
      expect(file.existsSync(), isFalse);
      final aside = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('set-aside-'))
          .toList();
      expect(aside, hasLength(1));
      expect(aside.single.lengthSync(), before);
      await tidy(tester);
    },
  );

  /// A backup saved elsewhere, made under [recovery]'s key.
  Future<String> makeBackup(RecoveryKey recovery) async {
    final saved = File('${dir.path}/usb/BetterBudget 2026.09.15.betterbudget');
    await saved.parent.create(recursive: true);
    await makeLedger(recovery: recovery, at: saved);
    return saved.path;
  }

  _CancelledDialogs fakeDialogs() {
    final dialogs = _CancelledDialogs();
    final before = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = dialogs;
    addTearDown(() => FileSelectorPlatform.instance = before);
    return dialogs;
  }

  testWidgets('a new computer opens on three ways to start; a key is kept '
      'only once it opens what was picked', (tester) async {
    final dialogs = fakeDialogs();
    final recovery = RecoveryKey.generate();
    final backup = await tester.runAsync(() => makeBackup(recovery));
    await launch(tester);
    // Three ways to start, and no key asked for until one that needs it is
    // chosen.
    expect(find.text('How do you want to start?'), findsOne);
    expect(find.text('My household is new to BetterBudget.'), findsOne);
    expect(find.byKey(const ValueKey('recovery-key-field')), findsNothing);
    // The one clicked opens where it is, with the key and its button.
    await choose(tester, 'start-open');
    expect(find.text('Choose the folder…'), findsOne);
    await expectLater(
      find.byType(StartChoiceScreen),
      matchesGoldenFile('goldens/start_choice_open.png'),
    );
    // A click on its name closes it, and so does Esc.
    await tapAndWait(tester, find.byKey(const ValueKey('start-open')));
    expect(find.byKey(const ValueKey('recovery-key-field')), findsNothing);
    await choose(tester, 'start-open');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const ValueKey('recovery-key-field')), findsNothing);

    // A folder with no ledger in it: said under the key, nothing kept.
    await choose(tester, 'start-open');
    final empty = await tester.runAsync(
      () => Directory('${dir.path}/My Drive/Photos').create(recursive: true),
    );
    dialogs.folder = empty!.path;
    await typeKey(tester, recovery);
    expect(dialogs.folders, 1);
    expect(
      find.textContaining('There’s no ledger in My Drive/Photos'),
      findsOne,
    );
    expect(storage.values, isEmpty);
    expect(file.existsSync(), isFalse);

    // Another opens in its place. Its dialog closed: still here.
    await choose(tester, 'start-restore');
    expect(find.text('Choose the folder…'), findsNothing);
    expect(find.text('Choose the backup…'), findsOne);
    await typeKey(tester, recovery);
    expect(dialogs.opened, 1);
    expect(find.byType(StartChoiceScreen), findsOne);
    expect(storage.values, isEmpty);

    // Another ledger's key: it doesn't open the backup, and isn't kept.
    dialogs.openPath = backup;
    await typeKey(tester, RecoveryKey.generate());
    expect(find.textContaining('That key doesn’t open this backup'), findsOne);
    expect(storage.values, isEmpty);
    expect(file.existsSync(), isFalse);

    // Its own key: kept, and the backup is the one asked about.
    await typeKey(tester, recovery);
    await until(tester, () => shown(find.text('Restore this backup?')));
    expect(storage.values['betterbudget.dataKey'], isNotNull);
    expect(dialogs.opened, 3);
    await tapAndWait(tester, find.byKey(const ValueKey('restore-confirm')));
    await until(
      tester,
      () => shown(find.textContaining('Restored the copy from')),
    );
    final ledger = await tester.runAsync(() => opened.single.loadLedger());
    expect(ledger!.txns, isNotEmpty);
    expect(find.text('Where is your ledger?'), findsNothing);
    await tidy(tester);
  });

  /// A new computer with the key typed and the backup picked, then the
  /// restore cancelled: an empty ledger, and nothing answered.
  Future<_CancelledDialogs> keyTypedNothingOpened(WidgetTester tester) async {
    final dialogs = fakeDialogs();
    final recovery = RecoveryKey.generate();
    dialogs.openPath = await tester.runAsync(() => makeBackup(recovery));
    await launch(tester);
    await choose(tester, 'start-restore');
    await typeKey(tester, recovery);
    await until(tester, () => shown(find.text('Restore this backup?')));
    dialogs.openPath = null;
    await tapAndWait(tester, find.byKey(const ValueKey('restore-cancel')));
    await until(tester, () => shown(find.text('Where is your ledger?')));
    return dialogs;
  }

  testWidgets('with nothing opened, it asks where the ledger is, and a '
      'dialog closed comes back to that', (tester) async {
    final dialogs = await keyTypedNothingOpened(tester);
    final files = dialogs.opened;
    await tapAndWait(tester, find.byKey(const ValueKey('offer-restore-open')));
    await until(
      tester,
      () =>
          dialogs.opened == files + 1 &&
          shown(find.text('Where is your ledger?')),
    );
    // The folder's dialog, closed too, comes back the same way.
    await tapAndWait(
      tester,
      find.byKey(const ValueKey('offer-restore-folder')),
    );
    await until(
      tester,
      () => dialogs.folders == 1 && shown(find.text('Where is your ledger?')),
    );
    await tapAndWait(tester, find.byKey(const ValueKey('offer-restore-empty')));
    expect(find.text('Where is your ledger?'), findsNothing);
    final ledger = await tester.runAsync(() => opened.single.loadLedger());
    expect(ledger!.txns, isEmpty);
    expect(ledger.balanceSheetAccounts, isEmpty);
    await tidy(tester);
  });

  testWidgets(
    'the question left unanswered is asked at the next launch, until Start '
    'empty',
    (tester) async {
      await keyTypedNothingOpened(tester);
      // Quit without answering.
      await tidy(tester);
      opened.clear();

      await launch(tester);
      await until(tester, () => shown(find.text('Where is your ledger?')));
      await tapAndWait(
        tester,
        find.byKey(const ValueKey('offer-restore-empty')),
      );
      await tidy(tester);
      opened.clear();

      await launch(tester);
      expect(find.byType(LedgerScreen), findsOne);
      await tapAndWait(tester, find.byType(LedgerScreen));
      expect(find.text('Where is your ledger?'), findsNothing);
      await tidy(tester);
    },
  );

  testWidgets('a key made on this computer is not offered a backup', (
    tester,
  ) async {
    await launch(tester);
    await tapAndWait(tester, find.byKey(const ValueKey('start-fresh')));
    await until(tester, () => shown(find.byType(RecoveryKeySetupScreen)));
    await tapAndWait(
      tester,
      find.byKey(const ValueKey('recovery-key-continue')),
    );
    await until(tester, () => shown(find.byType(LedgerScreen)));
    await tapAndWait(tester, find.byType(LedgerScreen));
    expect(find.text('Where is your ledger?'), findsNothing);
    await tidy(tester);
  });

  group('whether a backup is still to be offered', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('an empty ledger nobody has answered for: yes', () async {
      expect(await db.backupOfferOpen(), isTrue);
    });

    test(
      'a ledger that has held an account: no, even with it deleted',
      () async {
        final bank = await db.addAccount(name: 'Bank', type: AccountType.asset);
        expect(await db.backupOfferOpen(), isFalse);
        await db.deleteAccount(bank);
        expect(await db.backupOfferOpen(), isFalse);
      },
    );

    test('categories alone don’t count as a ledger in use', () async {
      await db.createCategory('Groceries');
      expect(await db.backupOfferOpen(), isTrue);
    });

    test('a new ledger started here: no', () async {
      await db.addAccount(name: 'Bank', type: AccountType.asset);
      await db.startNewLedger(now, keepCategories: false);
      expect(await db.backupOfferOpen(), isFalse);
    });
  });
}

/// The clipboard, caught: what Copy put there. Only the clipboard's calls
/// are answered, and only until the test ends.
List<String> _catchClipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}
