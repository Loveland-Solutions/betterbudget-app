// Finishing first-time setup (ADR 0004, "The first-time walkthrough", #475):
// what the budget uses of the money already in the accounts, the day the
// budget began, the Safety net's money, and that setup is done, in one write
// and one undo. The computer's setup and the phone's (#534) both call it.
import '../domain/budget.dart' show Budget, BudgetKeys;
import '../domain/budget_amounts.dart' show BudgetBegan, beganBy, budgetRows;
import '../domain/ledger.dart' show BudgetAmount, dateKey;
import '../domain/money.dart' show Currency;
import '../domain/pay.dart' show budgetPeriod;
import '../domain/readiness.dart' show mainCurrency;
import '../domain/setup.dart' show SetupKeys, WalkKeys;
import 'database.dart' show AppDatabase;

/// The undo and redo of a finished setup.
typedef SetupDone = ({
  Future<void> Function() undo,
  Future<void> Function() redo,
});

/// Ends setup in [db] as of [today]. [had] is what the budget uses of each
/// currency's money in the accounts; [emergency], in the budget's own
/// currency, is assigned to the Safety net, made as [safetyNetName] when
/// there is none. The Safety net, once made, is kept on undo: there is only
/// ever one. Throws what the ledger refuses; nothing of the finish is then
/// written.
Future<SetupDone> finishSetup(
  AppDatabase db, {
  required Map<Currency, int> had,
  required int emergency,
  required DateTime today,
  required String safetyNetName,
}) async {
  final data = await db.loadLedger();
  final period = budgetPeriod(today, data.periodSchedule);
  final start = period.start, end = period.end;
  final main = mainCurrency(data);
  final using = {
    for (final e in had.entries)
      if (e.value > 0) e.key,
    if (emergency > 0) main,
  };
  final keys = [
    SetupKeys.done,
    WalkKeys.started,
    BudgetKeys.keptStart,
    for (final c in had.keys) BudgetKeys.hadBefore(c),
  ];
  final old = {for (final k in keys) k: data.prefs[k]};
  final began = beganBy(data, start, using);
  int? net;
  var before = const <BudgetAmount>[];

  Future<void> writeBegan(List<BudgetBegan> began, {bool back = false}) async {
    for (final b in began) {
      await db.setPreference(b.key, back ? b.was : b.now);
      if (b.currency != null) {
        await db.setPreference(BudgetKeys.currency, back ? null : b.currency);
      }
    }
  }

  // All of it or none of it: a half-written finish would leave Had before
  // and the day it began with nothing to undo them (code review).
  Future<void> write() => db.transaction(() async {
    for (final e in had.entries) {
      await db.setPreference(
        BudgetKeys.hadBefore(e.key),
        e.value > 0 ? '${e.value}' : null,
      );
    }
    await writeBegan(began);
    // Setup said where the budget starts: the first-period offer to start
    // next period instead isn't asked (it would leave Had before counted a
    // period late).
    await db.setPreference(BudgetKeys.keptStart, '1');
    if (net case final id?) {
      final fresh = await db.loadLedger();
      final c = fresh.accounts[id]!;
      final rows = budgetRows(
        fresh,
        Budget.of(fresh, start: start, end: end, today: today),
        c,
        period,
        emergency,
        today: today,
      );
      before = await db.setBudgetAmount(
        id,
        start,
        end,
        emergency,
        rows: rows,
      );
    }
    // The Budget page walks a ledger set up from now on through its first
    // steps (#475); one set up before is never walked.
    await db.setPreference(WalkKeys.started, dateKey(today));
    await db.setPreference(SetupKeys.done, '1');
  });

  // Built in, as Income is; made here rather than after setup, since its
  // money is assigned now.
  if (emergency > 0) {
    net = await db.safetyNetCategory(name: safetyNetName, currency: main);
  }
  await write();
  return (
    undo: () async {
      if (net case final id?) {
        await db.restoreBudgetAmounts(id, start, end, before);
      }
      await writeBegan(began, back: true);
      for (final e in old.entries) {
        await db.setPreference(e.key, e.value);
      }
    },
    redo: write,
  );
}
