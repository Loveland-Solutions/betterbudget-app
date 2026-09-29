import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'data/backup.dart';
import 'data/database.dart';
import 'data/keys.dart';
import 'ui/startup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore opens the backup it's about to put back as a second database,
  // briefly, to check it.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final dir = await getApplicationSupportDirectory();
  runApp(
    BetterBudgetStartup(
      store: KeyStore(),
      ledgerFile: File('${dir.path}/betterbudget.sqlite'),
      open: (dataKey) async {
        final db = await AppDatabase.openEncrypted(dataKey);
        final backups = Backups(db, dataKey: dataKey);
        final report = await backups.convertPlainBackups();
        // One copy a day beside the database (14 days, plus the first of
        // each of 12 months). Checked hourly too, for an app left open past
        // midnight.
        unawaited(backups.runDaily(DateTime.now()));
        Timer.periodic(
          const Duration(hours: 1),
          (_) => backups.runDaily(DateTime.now()),
        );
        return (db: db, backups: backups, report: report);
      },
    ),
  );
}
