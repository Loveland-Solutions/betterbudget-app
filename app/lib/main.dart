import 'package:flutter/material.dart';

import 'data/database.dart';
import 'ui/ledger_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(BetterBudgetApp(db: AppDatabase()));
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
