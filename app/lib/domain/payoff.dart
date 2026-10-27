/// When step 2's debts are paid off, one way or the other (owner,
/// 2026-10-27: "Let's give them both the avalanche and snowball methods.
/// They should have a preview showing when they'll have things paid off
/// with either method"). Pure Dart: no database, no Flutter.
library;

/// The order extra money goes in.
enum PayoffMethod {
  /// The snowball: smallest balance first, rates left out. The default.
  smallest,

  /// The avalanche: highest rate first; debts without one last.
  highestRate,
}

/// One debt as the projection sees it: what's owed, its rate a month as a
/// fraction (0 without one), and what is paid into it each month.
typedef PayoffDebt = ({int id, int owed, double monthlyRate, int payment});

/// How a projection came out.
class PayoffPlan {
  const PayoffPlan({
    required this.months,
    required this.interest,
    required this.paidOffIn,
  });

  /// Months until everything is paid off; null past [PayoffPlan.maxMonths].
  final int? months;

  /// Interest charged on the way, in minor units.
  final int interest;

  /// The month each debt is paid off in, by id; one that isn't by
  /// [PayoffPlan.maxMonths] is missing.
  final Map<int, int> paidOffIn;

  /// Thirty years: past that it is said as more than thirty years.
  static const maxMonths = 360;

  /// The debt paid off first and its month; on a tie, the first in order.
  ({int id, int month})? firstIn(List<int> order) {
    ({int id, int month})? first;
    for (final id in order) {
      final m = paidOffIn[id];
      if (m != null && (first == null || m < first.month)) {
        first = (id: id, month: m);
      }
    }
    return first;
  }
}

/// Month by month: interest on each balance, each debt's own payment, then
/// [extra] and every payment a paid-off debt frees go to the first debt in
/// [order] still owing; what is left over goes on to the next that month.
/// The payments are kept up as they are and nothing new is borrowed.
PayoffPlan projectPayoff(List<PayoffDebt> debts, List<int> order, int extra) {
  final owed = {for (final d in debts) d.id: d.owed};
  final byId = {for (final d in debts) d.id: d};
  final paidOffIn = <int, int>{
    for (final d in debts)
      if (d.owed <= 0) d.id: 0,
  };
  var interest = 0;
  for (var month = 1; month <= PayoffPlan.maxMonths; month++) {
    if (owed.values.every((v) => v <= 0)) break;
    var pool = extra;
    for (final d in debts) {
      final left = owed[d.id]!;
      if (left <= 0) {
        // Paid off: its payment goes on to the next.
        pool += d.payment;
        continue;
      }
      final charged = (left * d.monthlyRate).round();
      interest += charged;
      final due = left + charged;
      final paid = d.payment < due ? d.payment : due;
      owed[d.id] = due - paid;
      pool += d.payment - paid;
    }
    for (final id in order) {
      if (pool <= 0) break;
      final left = owed[id]!;
      if (left <= 0) continue;
      final paid = pool < left ? pool : left;
      owed[id] = left - paid;
      pool -= paid;
    }
    for (final MapEntry(key: id, value: left) in owed.entries) {
      if (left <= 0) paidOffIn.putIfAbsent(id, () => month);
    }
  }
  final done = paidOffIn.length == byId.length;
  return PayoffPlan(
    months: done
        ? paidOffIn.values.fold<int>(0, (a, b) => a > b ? a : b)
        : null,
    interest: interest,
    paidOffIn: paidOffIn,
  );
}
