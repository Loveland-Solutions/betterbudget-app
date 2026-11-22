// What a payee does to rows already in the ledger, worked out the same on the
// computer's Payees page and the phone's (#532): the rows it fits, the ones
// still in Not categorized that it would file, the ones that would take its
// name. Pure: the writes are in data/payee_acts.dart.

import 'budget.dart';
import 'ledger.dart';
import 'pay.dart' show budgetPeriod;
import 'payee_rules.dart';
import 'sync.dart' show MadeHow;

/// The posted rows of its accounts that [probe] fits: by any of its
/// spellings, or by its name.
List<RegisterRow> payeeFitting(LedgerData data, PayeeRuleInfo probe) => [
  for (final a in data.openAccounts)
    if (probe.accountIds.contains(a.id))
      for (final r in data.registerFor(a.id).posted)
        if (r.kind == RowKind.simple && probe.fits(r.payeeWritten, r.memo)) r,
];

/// Of [rows], the ones still in Not categorized that [rule] would file
/// now: in this period, the ones the Not categorized tab shows (owner,
/// 2026-10-26); not one a longer line wins, as an import would decide; in
/// a currency its category takes; money in only, for a pay's paycheck.
List<RegisterRow> payeeWaitingOf(
  LedgerData data,
  List<RegisterRow> rows,
  PayeeRuleInfo rule,
  DateTime today,
) {
  final holding = data.categories.where(isUncategorized).firstOrNull?.id;
  final category = data.accounts[rule.categoryId];
  if (holding == null || category == null) return const [];
  final pay = data.payScheduleById(rule.payId);
  final period = budgetPeriod(today, data.periodSchedule);
  final rules = [
    for (final r in data.payeeRules)
      if (r.id != rule.id) r,
    rule,
  ];
  return [
    for (final r in rows)
      if (r.categoryId == holding &&
          !r.date.isBefore(period.start) &&
          !r.date.isAfter(period.end) &&
          categoryTakes(category, r.currency) &&
          r.accountId != category.id &&
          // A statement holds a row's accounts: it isn't made a transfer.
          !(category.isBalanceSheet && r.cleared == Cleared.reconciled) &&
          (pay == null || r.accountId == pay.accountId) &&
          PayeeRuleInfo.pick(
                rules,
                r.accountId,
                r.payeeWritten,
                r.memo,
                amount: r.amount,
              )?.id ==
              rule.id)
        r,
  ];
}

List<RegisterRow> payeeWaitingFor(
  LedgerData data,
  PayeeRuleInfo rule,
  DateTime today,
) => payeeWaitingOf(data, payeeFitting(data, rule), rule, today);

/// The account a payee's rows are money moved to or from (#117), or null
/// for a category.
AccountInfo? payeeMovedTo(LedgerData data, PayeeRuleInfo rule) {
  final a = data.accounts[rule.categoryId];
  return a != null && a.isBalanceSheet ? a : null;
}

/// The rows already in the ledger that would show [rule]'s name had they
/// come in after it was given, and don't: brought in from a bank file (a
/// row typed by hand, here or on a phone, says what the person wrote), and
/// this payee's by the same test an import makes, so not one a longer line
/// wins or money out of a pay's payee (budget review, 2026-11-18). None
/// when it has no name.
List<RegisterRow> payeeUnnamedFor(LedgerData data, PayeeRuleInfo rule) {
  final shown = payeeWords(rule.shownAs);
  // A transfer's row names the other account, never the payee.
  if (shown.isEmpty || payeeMovedTo(data, rule) != null) return const [];
  final rules = [
    for (final r in data.payeeRules)
      if (r.id != rule.id) r,
    rule,
  ];
  return [
    for (final r in payeeFitting(data, rule))
      if (payeeWords(r.txnPayee ?? '') != shown &&
          r.madeHow != MadeHow.typed &&
          r.madeHow != MadeHow.phone &&
          PayeeRuleInfo.pick(
                rules,
                r.accountId,
                r.payeeWritten,
                r.memo,
                amount: r.amount,
              )?.id ==
              rule.id)
        r,
  ];
}

/// A payee's category as its list names it: an account, money moved to or
/// from it (#117), as the entry row's Category list writes it.
String counterLabel(AccountInfo c) => c.isBalanceSheet ? '→ ${c.name}' : c.name;
