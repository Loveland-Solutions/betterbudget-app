/// The Savings steps (ADR 0004, rule 25): getting financially prepared, in
/// the order the Church's *Personal Finances for Self-Reliance* course
/// teaches ("What Is My Current Financial Priority?", chapter 5). For
/// everyone, so tithing isn't one of them (owner's call). The current step is
/// the first not done; nothing is locked, and any step can be set aside.
/// Pure Dart: no database, no Flutter.
library;

import 'ledger.dart';

enum ReadyStep {
  /// One month of living expenses, not pay (course, chapter 6).
  oneMonth,
  health,
  consumerDebt,

  /// Three to six months, once consumer debt is gone (chapter 9).
  moreMonths,
  retirement,
  longLoans,
}

enum ReadyState { done, current, later, setAside }

/// Preference keys the steps keep their answers under.
abstract final class ReadyKeys {
  /// 'yes' or 'no'; unanswered is not yet.
  static const health = 'ready.health';
  static const retirement = 'ready.retirement';

  /// 'yes': paying the mortgage and student loans down on purpose.
  static const longLoans = 'ready.longLoans';

  /// A month of expenses the user typed, in minor units; overrides the
  /// average.
  static const month = 'ready.month';

  /// How many months the bigger fund aims for, 3 to 6. Starts at 3.
  static const months = 'ready.months';

  /// Steps set aside, by name, comma separated.
  static const setAside = 'ready.setAside';
}

typedef Debt = ({AccountInfo account, int owed});

/// What a month of living costs. [amount] is 0 while it isn't known: no
/// typed figure and under [minDays] of history.
class MonthOfSpending {
  const MonthOfSpending({
    required this.amount,
    required this.typed,
    required this.days,
    required this.spent,
  });

  final int amount;

  /// Typed by the user rather than averaged.
  final bool typed;

  /// Days of history the average covers (up to [spanDays]).
  final int days;

  /// Spent in those days.
  final int spent;

  static const spanDays = 91;
  static const minDays = 28;

  /// Spending categories' posted rows over the last three months (or since
  /// the ledger began), scaled to an average month and rounded up to a whole
  /// unit. Refunds count against spending; transfers, card payments and
  /// opening balances aren't spending.
  static MonthOfSpending of(LedgerData data, DateTime today) {
    final typed = int.tryParse(data.prefs[ReadyKeys.month] ?? '');
    final end = dateOnly(today);
    DateTime? first;
    for (final t in data.txns) {
      if (t.scheduled) continue;
      if (first == null || t.date.isBefore(first)) first = t.date;
    }
    var start = end.subtract(const Duration(days: spanDays - 1));
    if (first != null && first.isAfter(start)) start = first;
    final days = first == null || start.isAfter(end)
        ? 0
        : DateTime.utc(end.year, end.month, end.day)
                  .difference(DateTime.utc(start.year, start.month, start.day))
                  .inDays +
              1;
    var spent = 0;
    for (final t in data.txns) {
      if (t.scheduled || t.date.isBefore(start) || t.date.isAfter(end)) {
        continue;
      }
      for (final e in t.entries) {
        if (data.accounts[e.accountId]?.type == AccountType.expense) {
          spent += e.amount;
        }
      }
    }
    if (typed != null && typed > 0) {
      return MonthOfSpending(
        amount: typed,
        typed: true,
        days: days,
        spent: spent,
      );
    }
    if (days < minDays || spent <= 0) {
      return MonthOfSpending(amount: 0, typed: false, days: days, spent: spent);
    }
    final perMonth = spent * 365.25 / 12 / days;
    return MonthOfSpending(
      amount: (perMonth / 100).ceil() * 100,
      typed: false,
      days: days,
      spent: spent,
    );
  }
}

class Readiness {
  Readiness._({
    required this.month,
    required this.fundAccounts,
    required this.fund,
    required this.consumerDebts,
    required this.longLoans,
    required this.monthsTarget,
    required this.answers,
    required this.setAside,
  });

  factory Readiness.of(LedgerData data, DateTime today) {
    final open = data.balanceSheetAccounts;
    final fundAccounts = [
      for (final a in open)
        if (!a.isOwed && a.role == AccountRole.emergencyFund) a,
    ];
    List<Debt> owed(bool Function(AccountInfo) which) => [
      for (final a in open)
        if (a.isOwed && which(a) && data.balanceOf(a.id) < 0)
          (account: a, owed: -data.balanceOf(a.id)),
    ]..sort((a, b) => a.owed.compareTo(b.owed));
    const long = {AccountRole.mortgage, AccountRole.studentLoan};
    final months = int.tryParse(data.prefs[ReadyKeys.months] ?? '') ?? 3;
    return Readiness._(
      month: MonthOfSpending.of(data, today),
      fundAccounts: fundAccounts,
      fund: fundAccounts.fold(0, (s, a) => s + data.balanceOf(a.id)),
      consumerDebts: owed(
        (a) => !long.contains(a.role) && a.role != AccountRole.paidMonthly,
      ),
      longLoans: owed((a) => long.contains(a.role)),
      monthsTarget: months.clamp(3, 6),
      answers: {
        ReadyStep.health: data.prefs[ReadyKeys.health] == 'yes',
        ReadyStep.retirement: data.prefs[ReadyKeys.retirement] == 'yes',
        ReadyStep.longLoans: data.prefs[ReadyKeys.longLoans] == 'yes',
      },
      setAside: {
        for (final n in (data.prefs[ReadyKeys.setAside] ?? '').split(','))
          for (final s in ReadyStep.values)
            if (s.name == n) s,
      },
    );
  }

  final MonthOfSpending month;

  /// Bank accounts marked as holding the emergency fund.
  final List<AccountInfo> fundAccounts;

  /// What's in them together.
  final int fund;

  /// Cards and loans owing, smallest first: consumer debt unless marked a
  /// mortgage, a student loan, or a card paid in full every month.
  final List<Debt> consumerDebts;
  final List<Debt> longLoans;
  final int monthsTarget;
  final Map<ReadyStep, bool> answers;
  final Set<ReadyStep> setAside;

  int get consumerOwed => consumerDebts.fold(0, (s, d) => s + d.owed);
  int get longOwed => longLoans.fold(0, (s, d) => s + d.owed);

  /// What each fund step aims for; 0 while a month isn't known.
  int targetOf(ReadyStep s) => switch (s) {
    ReadyStep.oneMonth => month.amount,
    ReadyStep.moreMonths => month.amount * monthsTarget,
    _ => 0,
  };

  bool isDone(ReadyStep s) => switch (s) {
    ReadyStep.oneMonth || ReadyStep.moreMonths =>
      targetOf(s) > 0 && fundAccounts.isNotEmpty && fund >= targetOf(s),
    ReadyStep.consumerDebt => consumerDebts.isEmpty,
    ReadyStep.longLoans => longLoans.isEmpty || answers[s]!,
    ReadyStep.health || ReadyStep.retirement => answers[s]!,
  };

  /// The first step not done and not set aside; null when all are.
  late final ReadyStep? current = ReadyStep.values
      .where((s) => !isDone(s) && !setAside.contains(s))
      .firstOrNull;

  ReadyState stateOf(ReadyStep s) => isDone(s)
      ? ReadyState.done
      : setAside.contains(s)
      ? ReadyState.setAside
      : s == current
      ? ReadyState.current
      : ReadyState.later;

  /// The set-aside list with [s] added or taken out, for the preference.
  String? setAsideWith(ReadyStep s, bool aside) {
    final next = {...setAside};
    aside ? next.add(s) : next.remove(s);
    return next.isEmpty
        ? null
        : [
            for (final x in ReadyStep.values)
              if (next.contains(x)) x.name,
          ].join(',');
  }
}
