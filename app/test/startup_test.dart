// What happens at launch (ADR 0001): a key is checked against the ledger
// before it's stored, a new key is shown before anything is stored or
// encrypted, and a ledger already here is never opened with a new key.
import 'dart:io';

import 'package:betterbudget/data/backup.dart';
import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/data/encryption.dart';
import 'package:betterbudget/data/keys.dart';
import 'package:betterbudget/domain/ledger.dart' show AccountType;
import 'package:betterbudget/ui/ledger_screen.dart';
import 'package:betterbudget/ui/recovery_key_screen.dart';
import 'package:betterbudget/ui/startup.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSecureStorage extends FlutterSecureStoragePlatform {
  final values = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => values[key] = value;

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => values[key];

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

/// The system's open dialog, cancelled every time.
class _CancelledDialogs extends FileSelectorPlatform {
  var opened = 0;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    opened++;
    return null;
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
    );
  }

  /// A ledger with demo rows, encrypted with [recovery]'s key, or plain.
  Future<void> makeLedger({RecoveryKey? recovery}) async {
    final key = recovery == null ? null : deriveDataKey(recovery);
    final db = AppDatabase(
      NativeDatabase(
        file,
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

  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        BetterBudgetStartup(
          store: KeyStore(),
          ledgerFile: file,
          open: open,
          clock: () => now,
        ),
      );
    });
    await until(
      tester,
      () =>
          shown(find.byType(RecoveryKeySetupScreen)) ||
          shown(find.byType(RecoveryKeyEntryScreen)) ||
          shown(find.byType(LedgerScreen)),
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

  testWidgets('a key typed on a new computer offers a backup, not the demo', (
    tester,
  ) async {
    await launch(tester);
    expect(
      find.textContaining('This computer doesn’t have a ledger yet'),
      findsOne,
    );
    await typeKey(tester, RecoveryKey.generate());
    await until(tester, () => shown(find.text('Open your newest backup?')));
    expect(find.text('Open your newest backup?'), findsOne);
    await tapAndWait(tester, find.byKey(const ValueKey('offer-restore-empty')));
    final ledger = await tester.runAsync(() => opened.single.loadLedger());
    expect(ledger!.txns, isEmpty);
    expect(ledger.balanceSheetAccounts, isEmpty);
    await tidy(tester);
  });

  testWidgets('Cancel in the file dialog comes back to the offer', (
    tester,
  ) async {
    final dialogs = _CancelledDialogs();
    final before = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = dialogs;
    addTearDown(() => FileSelectorPlatform.instance = before);
    await launch(tester);
    await typeKey(tester, RecoveryKey.generate());
    await until(tester, () => shown(find.text('Open your newest backup?')));
    await tapAndWait(tester, find.byKey(const ValueKey('offer-restore-open')));
    await until(
      tester,
      () => dialogs.opened == 1 && shown(find.text('Open your newest backup?')),
    );
    expect(find.text('Open your newest backup?'), findsOne);
    await tapAndWait(tester, find.byKey(const ValueKey('offer-restore-empty')));
    expect(find.text('Open your newest backup?'), findsNothing);
    await tidy(tester);
  });

  testWidgets(
    'an offer left unanswered is made at the next launch, until Start empty',
    (tester) async {
      await launch(tester);
      await typeKey(tester, RecoveryKey.generate());
      await until(tester, () => shown(find.text('Open your newest backup?')));
      // Quit without answering.
      await tidy(tester);
      opened.clear();

      await launch(tester);
      await until(tester, () => shown(find.text('Open your newest backup?')));
      await tapAndWait(
        tester,
        find.byKey(const ValueKey('offer-restore-empty')),
      );
      await tidy(tester);
      opened.clear();

      await launch(tester);
      expect(find.byType(LedgerScreen), findsOne);
      await tapAndWait(tester, find.byType(LedgerScreen));
      expect(find.text('Open your newest backup?'), findsNothing);
      await tidy(tester);
    },
  );

  testWidgets('a key made on this computer is not offered a backup', (
    tester,
  ) async {
    await launch(tester);
    await tapAndWait(
      tester,
      find.byKey(const ValueKey('recovery-key-generate-new')),
    );
    await until(tester, () => shown(find.byType(RecoveryKeySetupScreen)));
    await tapAndWait(
      tester,
      find.byKey(const ValueKey('recovery-key-continue')),
    );
    await until(tester, () => shown(find.byType(LedgerScreen)));
    await tapAndWait(tester, find.byType(LedgerScreen));
    expect(find.text('Open your newest backup?'), findsNothing);
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
