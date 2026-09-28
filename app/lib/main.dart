import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'data/backup.dart';
import 'data/database.dart';
import 'data/encryption.dart';
import 'data/keys.dart';
import 'ui/ledger_screen.dart';
import 'ui/recovery_key_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore opens the backup it's about to put back as a second database,
  // briefly, to check it.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final keyStore = KeyStore();
  final keyResult = await resolveDataKey(keyStore);
  // An earlier build kept the recovery key so Settings could show it again.
  if (keyResult is DataKeyReady) await keyStore.forgetStoredRecoveryKey();
  if (keyResult is DataKeyNeedsRecoveryEntry) {
    final canPersist = keyResult.canPersist;
    // A ledger from before encryption has nothing to recover: make its key,
    // encrypt it, and show the key once.
    final file = File(
      '${(await getApplicationSupportDirectory()).path}/betterbudget.sqlite',
    );
    if (await isPlainSqliteFile(file)) {
      final ready = await useRecoveryKey(
        keyStore,
        RecoveryKey.generate(),
        persist: canPersist,
        isNew: true,
      );
      await _launch(ready.dataKey, newRecoveryKey: ready.newRecoveryKey);
      return;
    }
    // No key on this device and no plain ledger: a fresh install, a second
    // device, or an encrypted ledger whose key is gone from this device —
    // ADR 0001 says ask, not assume. canPersist is only false on Linux with
    // no Secret Service, where nothing can be written and this is asked
    // every launch instead.
    runApp(
      _RecoveryKeyEntryApp(
        onKey: (recovery) async {
          final ready = await useRecoveryKey(
            keyStore,
            recovery,
            persist: canPersist,
            isNew: false,
          );
          await _launch(ready.dataKey);
        },
        onGenerateNew: () async {
          final ready = await useRecoveryKey(
            keyStore,
            RecoveryKey.generate(),
            persist: canPersist,
            isNew: true,
          );
          await _launch(ready.dataKey, newRecoveryKey: ready.newRecoveryKey);
        },
        hasSecureStore: canPersist,
      ),
    );
    return;
  }
  final ready = keyResult as DataKeyReady;
  await _launch(ready.dataKey, newRecoveryKey: ready.newRecoveryKey);
}

Future<void> _launch(Uint8List dataKey, {RecoveryKey? newRecoveryKey}) async {
  final db = await AppDatabase.openEncrypted(dataKey);
  final backups = Backups(db, dataKey: dataKey);
  final converted = await backups.convertPlainBackups();
  if (converted > 0) {
    debugPrint('Converted $converted old backup(s) to encrypted.');
  }
  // One copy a day beside the database (14 days, plus the first of each of
  // 12 months). Checked hourly too, for an app left open past midnight.
  unawaited(backups.runDaily(DateTime.now()));
  Timer.periodic(
    const Duration(hours: 1),
    (_) => backups.runDaily(DateTime.now()),
  );
  runApp(
    BetterBudgetApp(db: db, backups: backups, newRecoveryKey: newRecoveryKey),
  );
}

class _RecoveryKeyEntryApp extends StatelessWidget {
  const _RecoveryKeyEntryApp({
    required this.onKey,
    required this.onGenerateNew,
    required this.hasSecureStore,
  });
  final ValueChanged<RecoveryKey> onKey;
  final VoidCallback onGenerateNew;
  final bool hasSecureStore;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BetterBudget',
    debugShowCheckedModeBanner: false,
    theme: midnightTheme(),
    home: RecoveryKeyEntryScreen(
      onKey: onKey,
      onGenerateNew: onGenerateNew,
      hasSecureStore: hasSecureStore,
    ),
  );
}

class BetterBudgetApp extends StatefulWidget {
  const BetterBudgetApp({
    super.key,
    required this.db,
    required this.backups,
    this.newRecoveryKey,
  });

  final AppDatabase db;
  final Backups backups;

  /// Set only the moment a new data key was created, so the setup screen
  /// shows exactly once (ADR 0001).
  final RecoveryKey? newRecoveryKey;

  @override
  State<BetterBudgetApp> createState() => _BetterBudgetAppState();
}

class _BetterBudgetAppState extends State<BetterBudgetApp> {
  late bool _showingSetup = widget.newRecoveryKey != null;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BetterBudget',
    debugShowCheckedModeBanner: false,
    theme: midnightTheme(),
    home: _showingSetup
        ? RecoveryKeySetupScreen(
            recoveryKey: widget.newRecoveryKey!,
            onDone: (saved) {
              if (saved) {
                unawaited(
                  widget.db.setPreference('security.recoveryKeySaved', '1'),
                );
              }
              setState(() => _showingSetup = false);
            },
          )
        : LedgerScreen(db: widget.db, backups: widget.backups, encrypted: true),
  );
}
