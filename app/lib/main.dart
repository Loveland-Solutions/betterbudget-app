import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';

import 'data/backup.dart';
import 'data/database.dart';
import 'ui/ledger_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  // Restore opens the backup it's about to put back as a second database,
  // briefly, to check it.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  // One copy a day beside the database (14 days, plus the first of each of
  // 12 months). Checked hourly too, for an app left open past midnight.
  final backups = Backups(db);
  unawaited(backups.runDaily(DateTime.now()));
  Timer.periodic(
    const Duration(hours: 1),
    (_) => backups.runDaily(DateTime.now()),
  );
  runApp(BetterBudgetApp(db: db, backups: backups));
}

class BetterBudgetApp extends StatelessWidget {
  const BetterBudgetApp({super.key, required this.db, required this.backups});

  final AppDatabase db;
  final Backups backups;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BetterBudget',
    debugShowCheckedModeBanner: false,
    theme: midnightTheme(),
    home: LedgerScreen(db: db, backups: backups),
  );
}
