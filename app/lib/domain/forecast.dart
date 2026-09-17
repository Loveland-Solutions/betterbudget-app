import 'ledger.dart';

/// Answers "will this account make it to the next income?" from scheduled
/// transactions alone. Deterministic and local: no history, no guessing.
///
/// On a credit account ([owed]) it answers "what will I owe?" instead:
/// balances are what's owed, positive, and owing is never a shortfall.
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
    required this.billTotal,
    required this.billCount,
    required this.inTotal,
    this.owed = false,
  });

  final DateTime start;

  /// On a credit account, what's owed today.
  final int startBalance;

  /// Payday when one is scheduled, otherwise the fallback horizon.
  final DateTime end;

  /// Balance after each scheduled bill or money coming in, in date order,
  /// with the row that caused it. Payday itself isn't a step.
  final List<ForecastStep> steps;
  final RegisterRow? payday;
  final int low;
  final DateTime lowDate;

  /// First day the balance is below zero, if it is before [end]. Today when
  /// the account is already under. Never set on a credit account.
  final DateTime? firstShort;

  /// Money going out before [end], and how many rows.
  final int billTotal;
  final int billCount;

  /// Money coming in before [end] other than payday: transfers from another
  /// account, refunds.
  final int inTotal;

  final bool owed;

  bool get isShort => firstShort != null;

  /// Below zero before any scheduled bill lands.
  bool get shortNow => !owed && startBalance < 0;

  /// The balance once every step has happened.
  int get endBalance => steps.isEmpty ? startBalance : steps.last.balance;
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
  bool owed = false,
}) {
  final start = dateOnly(today);
  // Overdue scheduled items still have to happen; treat them as today.
  DateTime when(RegisterRow r) => r.date.isBefore(start) ? start : r.date;

  // A card has no payday: it looks 30 days out.
  final payday = owed
      ? null
      : scheduled
            .where(
              (r) =>
                  r.isIncome && !when(r).isAfter(start.add(_paydayLookahead)),
            )
            .firstOrNull;
  final end = payday != null ? when(payday) : start.add(_fallbackHorizon);

  // On a card, balances are shown as what's owed.
  int shown(int v) => owed ? -v : v;
  var bal = working, billTotal = 0, billCount = 0, inTotal = 0;
  var low = shown(working);
  var lowDate = start;
  DateTime? firstShort = !owed && working < 0 ? start : null;
  final steps = <ForecastStep>[];

  // Bills landing on payday itself count before the income: conservative.
  for (final r in scheduled) {
    if (identical(r, payday) || when(r).isAfter(end)) continue;
    bal += r.amount;
    if (r.amount < 0) {
      billTotal -= r.amount;
      billCount++;
    } else {
      inTotal += r.amount;
    }
    final label = r.kind == RowKind.transfer ? r.payee : r.categoryLabel;
    steps.add((date: when(r), balance: shown(bal), label: label, row: r));
    if (!owed && bal < low) {
      low = bal;
      lowDate = when(r);
    }
    if (!owed && bal < 0 && firstShort == null) firstShort = when(r);
  }

  return Forecast(
    start: start,
    startBalance: shown(working),
    end: end,
    steps: steps,
    payday: payday,
    low: low,
    lowDate: lowDate,
    firstShort: firstShort,
    billTotal: billTotal,
    billCount: billCount,
    inTotal: inTotal,
    owed: owed,
  );
}
