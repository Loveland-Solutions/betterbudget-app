import 'budget.dart';
import 'ledger.dart';
import 'money.dart';
import 'readiness.dart';

/// A goal on Savings (#101, #102; ADR 0004 "Goals on Savings"): a
/// once-only "On a date" budget line marked [ReadyKeys.goal], such as a
/// wedding by June 2028. Budget asks for its parts; Savings says how far
/// along it is.
class Goal {
  const Goal({
    required this.category,
    required this.plan,
    required this.saved,
    required this.asks,
    required this.assigned,
    required this.usual,
    required this.behind,
    required this.today,
    required this.askAll,
    required this.pastDate,
  });

  final AccountInfo category;
  final CategoryPlan plan;

  /// What was put toward it, as Budget counts it ([PlanLine.toward]):
  /// what the category held when the plan began, and every amount
  /// assigned since, less what was moved out. Money spent on the thing
  /// itself (a deposit on the hall) doesn't take it down (owner,
  /// 2026-10-27: "like saving for a birthday or Christmas").
  final int saved;

  /// What Budget asks of it this month.
  final int asks;

  /// What is assigned to it this month.
  final int assigned;

  /// The part a month it asks while kept up with.
  final int usual;

  /// Budget's "short": behind by what earlier months asked and didn't get.
  final int behind;
  final DateTime today;

  /// Its date has passed short and the person chose to be asked for all
  /// of the rest at once ([ReadyKeys.goalLate]).
  final bool askAll;

  int get amount => plan.amount;
  DateTime get due => plan.due!;
  Currency get currency => category.currency;
  int get toGo => saved >= amount ? 0 : amount - saved;
  bool get ready => toGo == 0;

  /// Its date is before this month, as Budget has it (with pays, the
  /// last payday before the date).
  final bool pastDate;

  /// Its date has passed with money still to go: from the month Budget
  /// would call a bill overdue, so the card and Budget agree.
  bool get late => !ready && pastDate;

  /// The month it's ready in at [usual] a month from now: this month's
  /// part counts until it's all assigned. Null when nothing is asked.
  DateTime? get readyAtUsual {
    if (ready || usual <= 0) return null;
    final months = (toGo + usual - 1) ~/ usual;
    final from = assigned >= usual ? 1 : 0;
    return DateTime(today.year, today.month + from + months - 1);
  }

  /// Its plan with the date moved into [month], on its own day when that
  /// month has it.
  CategoryPlan movedTo(DateTime month) {
    final last = DateTime(month.year, month.month + 1, 0).day;
    final day = due.day < last ? due.day : last;
    return CategoryPlan(
      categoryId: plan.categoryId,
      kind: plan.kind,
      amount: plan.amount,
      start: plan.start,
      due: DateTime(month.year, month.month, day),
      weekend: plan.weekend,
      rollover: plan.rollover,
      paidFrom: plan.paidFrom,
    );
  }
}

/// Every goal in [data], soonest first, counted by [budget]: this
/// calendar month's. One that's ready, past its date and spent has
/// nothing more to say, and is left off.
List<Goal> goalsOf(LedgerData data, Budget budget, DateTime today) {
  final day = dateOnly(today);
  final out = <Goal>[];
  for (final c in data.accounts.values) {
    if (c.deleted || c.archived || !isGoal(data, c.id)) continue;
    final plan = data.plans[c.id]!;
    final line = budget.lines[c.id];
    final p = line?.plan;
    final saved = p?.toward ?? 0;
    final pastDate = p?.pastDate ?? false;
    if (saved >= plan.amount && pastDate && (line?.left ?? 0) <= 0) continue;
    out.add(
      Goal(
        category: c,
        plan: plan,
        saved: saved,
        pastDate: pastDate,
        asks: line?.plan?.planned ?? 0,
        assigned: line?.assigned ?? 0,
        usual: line?.plan?.usual ?? 0,
        behind: line?.short ?? 0,
        today: day,
        askAll: data.prefs[ReadyKeys.goalLate(c.id)] == 'all',
      ),
    );
  }
  out.sort((a, b) => a.due.compareTo(b.due));
  return out;
}
