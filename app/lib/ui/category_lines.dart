import '../domain/budget.dart' show categoryTakes;
import '../domain/ledger.dart';
import '../domain/money.dart';

/// One line of a row's Category list: a category, a pay (filed under
/// Income, [payId] its pay), or an account money moves to ("→ Savings").
typedef CategoryLine = ({String label, AccountInfo account, int? payId});

/// What a row's Category list offers, in its order, wherever it opens: in
/// the row's editor and in the quick list on its category (owner,
/// 2026-11-25: "Those two lists should be the same!"). New category and
/// Split sit above these in both.
///
/// Not archived categories, nor ones in another currency than the row's
/// ([keepId], the row's own, stays either way). With money in, the pays
/// and Income come first; otherwise the spending categories do (owner,
/// 2026-10-06). The accounts come last, never the row's own
/// ([fromAccountId]).
List<CategoryLine> categoryLines({
  required Iterable<AccountInfo> categories,
  required Iterable<AccountInfo> transfers,
  required Iterable<({int id, String label})> pays,
  required Currency currency,
  required bool moneyIn,
  int? keepId,
  int? fromAccountId,
}) {
  final offered = [
    for (final c in categories)
      if (!c.archived && (c.id == keepId || categoryTakes(c, currency))) c,
  ];
  final income = offered.where((c) => c.isIncome);
  final payLines = switch (income.firstOrNull) {
    final into? => [
      for (final p in pays) (label: p.label, account: into, payId: p.id),
    ],
    null => const <CategoryLine>[],
  };
  CategoryLine line(AccountInfo c) => (label: c.name, account: c, payId: null);
  final incomeLines = [...payLines, ...income.map(line)];
  final spending = offered.where((c) => !c.isIncome).map(line);
  return [
    if (moneyIn) ...[
      ...incomeLines,
      ...spending,
    ] else ...[
      ...spending,
      ...incomeLines,
    ],
    for (final a in transfers)
      if (!a.archived && a.isBalanceSheet && a.id != fromAccountId)
        (label: '→ ${a.name}', account: a, payId: null),
  ];
}
