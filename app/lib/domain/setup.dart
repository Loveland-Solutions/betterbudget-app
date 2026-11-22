import 'budget.dart';
import 'money.dart';
import 'ledger.dart';
import 'readiness.dart' show fundCategoryIds, mainCurrency, savingsCurrency;

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

  /// The currency the household saves in (owner, 2026-11-23, #616), asked
  /// on Money you have while the accounts hold more than one: the Safety
  /// net, and with it the budget's own currency, are in it. A currency's
  /// code; unset, the one most accounts are in.
  static const saveIn = 'setup.saveIn';

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

/// What the bank and cash accounts hold today, by currency, where it isn't
/// nothing: what "Money you have" asks about (#475). Below zero, the
/// accounts are overdrawn, and the budget starts that much short (owner,
/// 2026-11-23, #617). What a credit card or loan owes isn't taken off: its
/// payment is a category's.
Map<Currency, int> setupHeld(LedgerData data) {
  final held = <Currency, int>{};
  for (final a in data.openAccounts) {
    if (a.isOwed) continue;
    held[a.currency] = (held[a.currency] ?? 0) + data.balanceOf(a.id);
  }
  return {
    for (final e in held.entries)
      if (e.value != 0) e.key: e.value,
  };
}

/// The currencies the bank and cash accounts are in, in the app's order:
/// with more than one, setup asks which the household saves in (#616).
List<Currency> setupCurrencies(LedgerData data) {
  final inUse = {
    for (final a in data.openAccounts)
      if (!a.isOwed) a.currency,
  };
  return [
    for (final c in Currency.values)
      if (inUse.contains(c)) c,
  ];
}

/// The currency the household saves in: the one picked on Money you have,
/// else the one most bank and cash accounts are in (one of the answers
/// offered, #616); with none, the one most accounts are in.
Currency setupSaveIn(LedgerData data) {
  final picked = data.prefs[SetupKeys.saveIn];
  final among = setupCurrencies(data);
  for (final c in among) {
    if (c.code == picked) return c;
  }
  if (among.isEmpty) return mainCurrency(data);
  final n = <Currency, int>{};
  for (final a in data.openAccounts) {
    if (!a.isOwed) n[a.currency] = (n[a.currency] ?? 0) + 1;
  }
  var most = among.first;
  for (final c in among) {
    if ((n[c] ?? 0) > (n[most] ?? 0)) most = c;
  }
  return most;
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

/// Where the walk is (#475), as both Budget pages show it: the computer's
/// band and the phone's read the same, so the two can't disagree.
class Walk {
  const Walk({
    required this.step,
    required this.steps,
    required this.bills,
    required this.days,
    required this.debt,
    required this.waiting,
    required this.short,
    required this.nextPay,
  });

  /// The step on screen, and every step named across the top, in order.
  final WalkStep step;
  final List<WalkStep> steps;

  /// How many bills and day-to-day categories there are in the budget's
  /// currency: once there's one, the way past is That's all, not Not now.
  final int bills, days;

  /// The first credit card or loan no category pays yet and no Not now
  /// passed, and what it owes; null with none.
  final ({AccountInfo account, int owes})? debt;

  /// The bills' line says the cards and loans come next.
  bool get cardsNext => debt != null;

  /// Nothing to give out yet: Assign waits for the income.
  final bool waiting;

  /// More assigned than there is: said as that, not as waiting for pay
  /// (budget review).
  final bool short;

  /// The next payday, when there's regular income.
  final DateTime? nextPay;

  /// The setting Not now or That's all writes on [step]: on a card or
  /// loan, that one only (budget review: a salary loan, a card and лизинг
  /// at once).
  String get passKey => step == WalkStep.debts && debt != null
      ? WalkKeys.debtPassed(debt!.account.id)
      : WalkKeys.passed(step);
}

/// The walk for [budget], the period today is in; null when there's none
/// or it's done.
Walk? walkOf(LedgerData data, Budget budget, DateTime today) {
  if (data.prefs[WalkKeys.started] == null) return null;
  final currency = Budget.currencyOf(data);
  final owing = walkDebts(data, currency);
  final unpaid = [
    for (final a in owing)
      if (Budget.loanCategory(data, a.id) == null &&
          data.prefs[WalkKeys.debtPassed(a.id)] == null)
        a,
  ];
  final saved = fundCategoryIds(data, savingsCurrency(data));
  final listed = [
    for (final c in data.categories)
      if (!c.isIncome && !isUncategorized(c) && !saved.contains(c.id)) c,
  ];
  final step = walkStep(
    data,
    unpaidDebts: unpaid,
    anyToAssign: listed.any((c) => (budget.lines[c.id]?.toAssign ?? 0) > 0),
  );
  if (step == null) return null;
  int countOf(CategoryType type) => listed
      .where((c) => c.currency == currency && typeOf(data, c.id) == type)
      .length;
  return Walk(
    step: step,
    steps: [
      WalkStep.bills,
      if (owing.isNotEmpty) WalkStep.debts,
      WalkStep.dayToDay,
      WalkStep.assign,
    ],
    bills: countOf(CategoryType.bill),
    days: countOf(CategoryType.dayToDay),
    debt: unpaid.isEmpty
        ? null
        : (account: unpaid.first, owes: -data.balanceOf(unpaid.first.id)),
    waiting: budget.notAssigned <= 0,
    short: budget.notAssigned < 0,
    nextPay: nextPayday(data, today),
  );
}
