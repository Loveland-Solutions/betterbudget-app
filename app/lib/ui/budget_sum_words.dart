import '../domain/budget.dart';
import 'language.dart';

/// What the sum's result is called when it is below zero, and the parts
/// under it when more than one thing made it short (#470): the same words
/// on the computer's Budget page and the phone's (#528).
///
/// One cause is named by its own box; more than one is Short, with each
/// part named. Spending alone, overspent or not categorized or both, is
/// Over budget (owner's pick, 2026-11-16).
({String label, String? parts}) overWords(
  Words t,
  ShortBy cause, {
  required bool byPay,
  required String beforeMonth,
  required String Function(int) short,
}) {
  final label = switch (cause) {
    ShortBy(exchanged: > 0) => t.planKeyOverMixed,
    ShortBy(carried: 0, assigned: 0) => t.planKeyOverSpent,
    _ when cause.causes > 1 => t.planKeyOverMixed,
    ShortBy(carried: > 0) when byPay => t.planKeyOverCarriedPay,
    ShortBy(carried: > 0) => t.planKeyOverCarriedMonth(beforeMonth),
    _ => t.planKeyOver,
  };
  final parts = cause.causes < 2 && cause.exchanged == 0
      ? null
      : [
          if (cause.carried > 0)
            byPay
                ? t.planKeyOverCarriedPayPart(short(cause.carried))
                : t.planKeyOverCarriedMonthPart(
                    short(cause.carried),
                    beforeMonth,
                  ),
          if (cause.exchanged > 0)
            t.planKeyOverExchangedPart(short(cause.exchanged)),
          if (cause.assigned > 0)
            t.planKeyOverAssignedPart(short(cause.assigned)),
          if (cause.spent > 0) t.planKeyOverSpentPart(short(cause.spent)),
          if (cause.loose > 0) t.planKeyOverLoosePart(short(cause.loose)),
        ].join(' · ');
  return (label: label, parts: parts);
}
