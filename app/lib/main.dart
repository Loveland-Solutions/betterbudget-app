import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'data/backup.dart';
import 'data/database.dart';
import 'data/keys.dart';
import 'data/ledger_file.dart';
import 'data/store_folder.dart';
import 'ui/appearance.dart';
import 'ui/language.dart';
import 'ui/phone/phone_app.dart';
import 'ui/phone/phone_start.dart';
import 'ui/startup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore opens the backup it's about to put back as a second database,
  // briefly, to check it.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  // Before anything asks where the app's folder is.
  useStoreFolderIfPackaged();

  final dir = await getApplicationSupportDirectory();
  // A phone records and checks (ADR 0005); it never holds the ledger itself.
  if (Platform.isAndroid || Platform.isIOS) {
    usePhoneColors();
    runApp(
      PhoneFrame(
        child: PhoneStart(keys: KeyStore(), dir: dir),
      ),
    );
    return;
  }
  // Light, dark or the system's, chosen in Settings; known before the ledger
  // opens so the recovery-key screens match too.
  final appearance = await AppearanceController.load(
    File('${dir.path}/appearance'),
  );
  // English, Mongolian or the system's; the same small-file arrangement.
  final language = await LanguageController.load(File('${dir.path}/language'));
  // Before anything opens it: a ledger under its earlier name gets the new one.
  final ledgerFile = await ledgerFileIn(dir);
  runApp(
    AppearanceScope(
      controller: appearance,
      child: LanguageScope(
        controller: language,
        child: BetterBudgetStartup(
          store: KeyStore(),
          ledgerFile: ledgerFile,
          open: (dataKey) async {
            final db = await AppDatabase.openEncrypted(dataKey);
            final backups = Backups(db, dataKey: dataKey);
            final ConversionReport report;
            try {
              report = await backups.convertPlainBackups();
            } catch (_) {
              // Try again opens it afresh; this one mustn't stay open beside.
              await db.close();
              rethrow;
            }
            return (
              db: db,
              backups: backups,
              report: report,
              // One copy a day beside the database (14 days, plus the first
              // of each of 12 months). Checked hourly too, for an app left
              // open past midnight.
              startDaily: () {
                unawaited(backups.runDaily(DateTime.now()));
                Timer.periodic(
                  const Duration(hours: 1),
                  (_) => backups.runDaily(DateTime.now()),
                );
              },
            );
          },
        ),
      ),
    ),
  );
}
