import 'ledger.dart';

/// Answers "will this account make it to the next income?" from scheduled
/// transactions alone. Deterministic and local: no history, no guessing.
class Forecast {
  const Forecast({
    required this.start,
    required this.startBalance,
    required this.end,
    required this.steps,
    required this.payday,
    required this.low,
    required this.lowDate,
    required this.firstShort,
    required this.causes,
    required this.billTotal,
  });

  final DateTime start;
  final int startBalance;

  /// Payday when one is scheduled, otherwise the fallback horizon.
  final DateTime end;

  /// Balance after each bill, in date order, with the bill that caused it.
  final List<ForecastStep> steps;
  final RegisterRow? payday;
  final int low;
  final DateTime lowDate;

  /// First day the balance is below zero, if it is before [end]. Today when
  /// the account is already under.
  final DateTime? firstShort;

  /// Bills from [firstShort] on: what pushes the account under.
  final List<String> causes;
  final int billTotal;

  bool get isShort => firstShort != null;

  /// Below zero before any scheduled bill lands.
  bool get shortNow => startBalance < 0;
  int get billCount => steps.length;
}

typedef ForecastStep = ({
  DateTime date,
  int balance,
  String label,
  RegisterRow row,
});

const _fallbackHorizon = Duration(days: 30);
const _paydayLookahead = Duration(days: 45);

Forecast buildForecast({
  required int working,
  required DateTime today,
  required List<RegisterRow> scheduled,
}) {
  final start = dateOnly(today);
  // Overdue scheduled items still have to happen; treat them as today.
  DateTime when(RegisterRow r) => r.date.isBefore(start) ? start : r.date;

  final incomes = scheduled
      .where((r) => r.isIncome && !when(r).isAfter(start.add(_paydayLookahead)))
      .toList();
  final payday = incomes.isEmpty ? null : incomes.first;
  final end = payday != null ? when(payday) : start.add(_fallbackHorizon);

  var bal = working, low = working, billTotal = 0;
  var lowDate = start;
  DateTime? firstShort = working < 0 ? start : null;
  final steps = <ForecastStep>[];
  final causes = <String>[];

  // Bills landing on payday itself count before the income: conservative.
  for (final r in scheduled) {
    if (r.amount >= 0 || when(r).isAfter(end)) continue;
    bal += r.amount;
    billTotal -= r.amount;
    final label = r.kind == RowKind.transfer ? r.payee : r.categoryLabel;
    steps.add((date: when(r), balance: bal, label: label, row: r));
    if (bal < low) {
      low = bal;
      lowDate = when(r);
    }
    if (bal < 0 && firstShort == null) firstShort = when(r);
    if (firstShort != null && !causes.contains(label)) causes.add(label);
  }

  return Forecast(
    start: start,
    startBalance: working,
    end: end,
    steps: steps,
    payday: payday,
    low: low,
    lowDate: lowDate,
    firstShort: firstShort,
    causes: causes,
    billTotal: billTotal,
  );
}
