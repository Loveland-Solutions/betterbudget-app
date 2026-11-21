import '../domain/forecast.dart';
import 'language.dart';

/// The sentences a forecast says about itself, as the computer's account
/// header says them and the phone's does: the [headline] (when it runs out,
/// its lowest day, what a card will owe) and the [detail] (the bills and
/// money in before its end). [money] writes an amount.
({String headline, String detail}) forecastSays(
  Words t,
  Forecast f,
  String Function(int) money,
) {
  final payday = f.payday;
  final String headline;
  String detail;
  if (f.owed) {
    // A card: what will be owed once scheduled charges and payments land.
    final payments = f.rowSteps.where((s) => s.row.amount > 0).length;
    final bal = f.endBalance;
    // The budget's spending on the card counts too (#179).
    headline = f.steps.isEmpty
        ? t.planNothingScheduled
        : bal < 0
        ? t.planCreditAfter(money(bal), sayDate(t, f.steps.last.date))
        : t.planOwedAfterDate(money(bal), sayDate(t, f.steps.last.date));
    final end = sayDate(t, f.end);
    detail = f.rowSteps.isEmpty && f.spendingTotal == 0
        ? t.planCardNothing
        : f.rowSteps.isEmpty
        ? t.planNoBillsBefore(end)
        : f.billCount > 0 && payments > 0
        ? t.planCardChargesPayments(
            f.billCount,
            money(f.billTotal),
            payments,
            money(f.inTotal),
            end,
          )
        : f.billCount > 0
        ? t.planCardCharges(f.billCount, money(f.billTotal), end)
        : t.planCardPayments(payments, money(f.inTotal), end);
  } else {
    // Money due today that hasn't landed: on payday the warning is
    // conditional, not news.
    final dueToday = f.late
        .where((r) => !r.date.isBefore(f.start))
        .fold(0, (s, r) => s + r.amount);
    final unless = dueToday > 0 ? money(dueToday) : null;
    if (f.shortNow) {
      // Already under: say so, not a future "runs out" date. The amount is
      // the Working total beside it, so it isn't repeated.
      headline = unless != null
          ? t.planBelowZeroUnless(unless)
          : f.low < f.startBalance
          ? t.planBelowZeroShort(money(f.low))
          : t.planBelowZeroNow;
    } else if (f.isShort) {
      final on = sayDate(t, f.firstShort!);
      headline = unless != null
          ? t.planRunsOutUnless(on, unless)
          : f.low == 0
          ? t.planRunsOutZero(on)
          : t.planRunsOut(on, money(f.low));
    } else if (f.takeOutBy case final by?) {
      // Cash the budget's spending would take below zero: filled from
      // the bank, said in ordinary ink (owner, 2026-10-28).
      headline = t.planTakeOut(money(f.takeOut), sayDate(t, by));
    } else if (f.steps.isEmpty) {
      // The budget's spending lowers the line too (#179).
      headline = t.planNothingScheduled;
    } else if (f.low >= f.startBalance) {
      headline = t.planLowestToday(money(f.startBalance));
    } else if (f.paydayCounted &&
        f.lowDate.isAfter(
          f.rowSteps.firstWhere((s) => identical(s.row, payday)).date,
        )) {
      // That low leans on the paycheck coming on time, in full.
      headline = t.planLowestAfterPay(money(f.low), sayDate(t, f.lowDate));
    } else {
      headline = t.planLowest(money(f.low), sayDate(t, f.lowDate));
    }
    // No payee names here: they can be any length. The count opens the list.
    // Money moved in from another account, refunds: they lift the line.
    final end = sayDate(t, f.end);
    detail = f.rowSteps.isEmpty
        ? payday == null
              ? t.planNoBillsOrIncome
              : t.planNoBillsBefore(end)
        // Through a pay period the paycheck is a step, not "money in".
        : f.billCount == 0 && f.inTotal == 0
        ? t.planNoBillsBefore(end)
        : f.billCount == 0
        ? t.planInBefore(money(f.inTotal), end)
        : f.inTotal > 0
        ? t.planBillsBeforeIn(
            f.billCount,
            money(f.billTotal),
            end,
            money(f.inTotal),
          )
        : t.planBillsBefore(f.billCount, money(f.billTotal), end);
  }
  return (headline: headline, detail: detail);
}
