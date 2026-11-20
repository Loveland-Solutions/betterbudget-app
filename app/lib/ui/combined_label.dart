// The line that says what another computer's changes brought in: the
// computer's popup and the phone's snack bar say it in the same words
// (ADR 0005, "The phone joins as another computer", #526 piece 4).
import 'language.dart';

/// "4 transactions from Tom’s MacBook Air": [transactions] came in, [others]
/// other changes with them, one transaction by its [payee], [from] being the
/// name of the computer that made them when it has one.
String combinedLabel(
  Words t, {
  required int transactions,
  required int others,
  String? payee,
  String? from,
}) {
  final n = transactions;
  return switch (from) {
    // One transaction came: by its payee.
    final name? when n == 1 && payee != null && others == 0 =>
      t.ledgerCombinedPayeeFrom(payee, name),
    final name? when n == 1 && payee != null => t.ledgerCombinedPayeeMoreFrom(
      payee,
      others,
      name,
    ),
    null when n == 1 && payee != null && others == 0 => t.ledgerCombinedPayee(
      payee,
    ),
    null when n == 1 && payee != null => t.ledgerCombinedPayeeMore(
      payee,
      others,
    ),
    final name? when n == 0 => t.ledgerCombinedOtherFrom(name),
    final name? when others == 0 => t.ledgerCombinedFrom(n, name),
    final name? => t.ledgerCombinedMoreFrom(n, name),
    null when n == 0 => t.ledgerCombinedOther,
    null when others == 0 => t.ledgerCombined(n),
    null => t.ledgerCombinedMore(n),
  };
}
