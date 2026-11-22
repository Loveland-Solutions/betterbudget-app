import 'money.dart';
import 'ledger.dart';

/// The first half hour (ADR 0004, "Onboarding"): what the setup keeps in the
/// `Preferences` table while it's open, and when it shows.
abstract final class SetupKeys {
  /// The one day every balance typed in setup is as of, as a date key. Set
  /// when setup first opens, so it also says a setup is under way.
  static const date = 'setup.date';

  /// Set when setup is left for the ledger. It never opens again after.
  static const done = 'setup.done';

  /// The step setup is on, so a quit comes back to it: [stepPay],
  /// [stepMoney], or unset for the accounts.
  static const step = 'setup.step';
  static const stepAccounts = 'accounts';
  static const stepPay = 'pay';
  static const stepMoney = 'money';

  /// How much of what a currency's accounts hold today the budget uses
  /// (#475, "Money you have"): unset or [hadAll] for all of it, [hadNone],
  /// or an amount in the currency's smallest units for part of it.
  static String had(Currency c) => 'setup.had.${c.code}';
  static const hadAll = 'all';
  static const hadNone = 'none';

  /// What the person said they keep for emergencies, in the budget's own
  /// currency's smallest units: assigned to the Safety net when setup ends.
  static const emergency = 'setup.emergency';

  /// Set to [backupOfferNo] once "Open your newest backup?" needn't be asked
  /// again: the recovery key was made here, or the answer was "Start empty".
  static const backupOffer = 'setup.backupOffer';
  static const backupOfferNo = 'no';

  /// The answer to "How do you pay for everyday things?".
  static const everyday = 'setup.everyday';
  static const everydayBank = 'bank';
  static const everydayCash = 'cash';
  static const everydayBoth = 'both';
}

/// Whether the ledger opens on setup: one that's under way, or a ledger that
/// has never had an account. A ledger that had accounts before setup existed
/// has neither key and never sees it, even with its last account deleted:
/// a deleted account is still in [LedgerData.accounts], and only starting a
/// new ledger takes them out.
bool inSetup(LedgerData data) =>
    data.prefs[SetupKeys.done] == null &&
    (data.prefs[SetupKeys.date] != null ||
        !data.accounts.values.any((a) => a.isBalanceSheet));

/// What the bank and cash accounts hold today, by currency, where it's more
/// than nothing: what "Money you have" asks about (#475). What a credit
/// card or loan owes isn't taken off: its payment is a category's.
Map<Currency, int> setupHeld(LedgerData data) {
  final held = <Currency, int>{};
  for (final a in data.openAccounts) {
    if (a.isOwed) continue;
    held[a.currency] = (held[a.currency] ?? 0) + data.balanceOf(a.id);
  }
  return {
    for (final e in held.entries)
      if (e.value > 0) e.key: e.value,
  };
}

/// Whether setup has its Money you have step: while there's money to ask
/// about.
bool setupAsksMoney(LedgerData data) => setupHeld(data).isNotEmpty;

/// The amount typed for emergencies, or 0.
int setupEmergency(LedgerData data) =>
    int.tryParse(data.prefs[SetupKeys.emergency] ?? '') ?? 0;

/// The day setup's balances are as of: the one stored, or [today].
DateTime setupDate(LedgerData data, DateTime today) =>
    switch (data.prefs[SetupKeys.date]) {
      final String key => parseDateKey(key),
      null => today,
    };

/// The first steps after setup, on the Budget page (#475, ADR 0004 "The
/// first-time walkthrough"): a band names them and shows one at a time.
enum WalkStep { bills, debts, dayToDay, assign }

abstract final class WalkKeys {
  /// Set when setup ends: this ledger came through setup since the walk
  /// was built, so its Budget page walks it through its first steps. A
  /// ledger set up before has none, and is never walked.
  static const started = 'walk.started';

  /// 'yes': the person went past [s] (That's all, or Not now). Their own
  /// answer, undone with ⌘Z.
  static String passed(WalkStep s) => 'walk.${s.name}';

  /// 'yes': Not now on one credit card or loan's bill; the others are
  /// still asked (budget review: a salary loan, a card and лизинг at once).
  static String debtPassed(int accountId) => 'walk.debt.$accountId';
}

/// Every credit card or loan that owes money in [currency]: the ones the
/// walk asks a paying category for.
List<AccountInfo> walkDebts(LedgerData data, Currency currency) => [
  for (final a in data.openAccounts)
    if (a.isOwed && a.currency == currency && data.balanceOf(a.id) < 0) a,
];

/// The step the walk is on, given whether [anyToAssign] (a category's plan
/// still has money to be assigned this period) and which of [debts] no
/// category pays yet; null when there's no walk or it's done. A step is
/// done when the person went past it, or, for the debts and Assign, when
/// there's nothing left for it.
WalkStep? walkStep(
  LedgerData data, {
  required List<AccountInfo> unpaidDebts,
  required bool anyToAssign,
}) {
  if (data.prefs[WalkKeys.started] == null) return null;
  bool passed(WalkStep s) => data.prefs[WalkKeys.passed(s)] != null;
  for (final s in WalkStep.values) {
    if (passed(s)) continue;
    switch (s) {
      case WalkStep.debts when unpaidDebts.isEmpty:
      case WalkStep.assign when !anyToAssign:
        continue;
      default:
        return s;
    }
  }
  return null;
}

/// The next payday of any regular income, today or later; null with none.
DateTime? nextPayday(LedgerData data, DateTime today) {
  final from = DateTime(today.year, today.month, today.day - 1);
  DateTime? next;
  for (final p in data.paySchedules) {
    final d = p.nextAfter(from);
    if (next == null || d.isBefore(next)) next = d;
  }
  return next;
}
