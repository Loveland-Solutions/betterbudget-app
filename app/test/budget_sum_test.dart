import 'package:betterbudget/data/database.dart';
import 'package:betterbudget/data/demo_seed.dart';
import 'package:betterbudget/domain/budget.dart';
import 'package:betterbudget/domain/ledger.dart';
import 'package:betterbudget/domain/pay.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('the sum on the Budget page adds up from its terms, whatever was '
      'spent ahead, saved or overspent (#528)', () async {
    final today = DateTime(2026, 10, 7);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedDemoIfEmpty(db, today);
    final data = await db.loadLedger();
    final period = budgetPeriod(today, data.periodSchedule);
    final budget = Budget.of(
      data,
      start: period.start,
      end: period.end,
      today: today,
    );
    final spending = [
      for (final a in data.accounts.values)
        if (a.type == AccountType.expense && !a.deleted) a,
    ];
    final ahead = spentAhead(data, budget, periodEnd: period.end, today: today);
    expect(budget.pools, isNotEmpty);
    for (final p in budget.pools) {
      final sum = BudgetSum.of(
        p,
        budget: budget,
        spending: spending,
        saved: {for (final a in spending.take(1)) a.id},
        aheadBy: ahead,
      );
      expect(
        p.income +
            p.toCome +
            p.fromBefore +
            p.hadBefore +
            p.exchanged -
            sum.given -
            sum.aside -
            sum.overspent -
            p.loose,
        p.notAssigned,
      );
      expect(sum.over, p.notAssigned < 0);
    }
  });
}
