import 'dart:async';

import 'package:flutter/material.dart';

import 'data/backup.dart';
import 'data/database.dart';
import 'ui/ledger_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  // One copy a day, kept for two weeks, beside the database. Checked hourly
  // too, for an app left open past midnight.
  final backups = Backups(db);
  Future<void> backUp() async {
    try {
      await backups.automaticIfDue(DateTime.now());
    } catch (e) {
      debugPrint('Automatic backup failed: $e');
    }
  }

  unawaited(backUp());
  Timer.periodic(const Duration(hours: 1), (_) => backUp());
  runApp(BetterBudgetApp(db: db));
}

class BetterBudgetApp extends StatelessWidget {
  const BetterBudgetApp({super.key, required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BetterBudget',
    debugShowCheckedModeBanner: false,
    theme: midnightTheme(),
    home: LedgerScreen(db: db),
  );
}
