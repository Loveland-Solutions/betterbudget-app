import 'ledger.dart';
import 'money.dart';
import 'pay.dart';
import 'readiness.dart' show mainCurrency;

/// The budget's envelopes (ADR 0004 rule 26). Each spending category keeps
/// its own balance from period to period, below zero too: every amount
/// assigned, less what it spent since the budget began. The money not
/// assigned is what the user has (cash and bank, less what cards owe) less
/// what sits in the categories, so a card purchase moves money from a
/// category and nothing else, and paying the card moves nothing.

/// The budget's settings, kept in preferences.
abstract final class BudgetKeys {
  /// `YYYY-MM-DD`: the day the budget began, set when the first amount is
  /// assigned. It never moves on its own; only the first-month offer or
  /// the user moves it.
  static const began = 'budget.began';

  /// The currency amounts are in, set with [began], so adding accounts in
  /// the other currency can't change what the amounts mean.
  static const currency = 'budget.currency';

  /// '1' once the first-month offer was answered with "Keep".
  static const keptStart = 'budget.keptStart';

  /// Prefix, then a mortgage or student loan's id: the spending category
  /// its payments come out of.
  static const loanPrefix = 'budget.loan.';
}

/// The category imported rows wait in, by the names the import gives it.
/// It holds no money: its rows count straight in the money not assigned
/// until they're categorized (owner's call, 2026-09-30).
const uncategorizedNames = {'Not categorized', 'Ангилаагүй'};

bool isUncategorized(AccountInfo a) =>
    a.type == AccountType.expense && uncategorizedNames.contains(a.name);

/// One spending category in one period.
class EnvelopeLine {
  const EnvelopeLine({
    required this.assigned,
    required this.spent,
    required this.left,
    required this.fromBefore,
  });

  /// Assigned for this period.
  final int assigned;

  /// Spent in this period: positive is spending, a refund takes it down.
  final int spent;

  /// What the category holds at the period's end (today, for this one).
  final int left;

  /// What it held when the period began.
  final int fromBefore;
}

class Budget {
  Budget._({
    required this.currency,
    required this.began,
    required this.lines,
    required this.cameIn,
    required this.notAssigned,
    required this.money,
    required this.uncategorizedRows,
    required this.uncategorizedNet,
    required this.unassignedSpent,
  });

  final Currency currency;

  /// The day the budget began; null until an amount is assigned.
  final DateTime? began;

  /// Each spending category (archived ones included: money can still sit
  /// in one), for the period asked for. Not "Not categorized".
  final Map<int, EnvelopeLine> lines;

  /// Each income category: what came in during the period.
  final Map<int, int> cameIn;

  /// What the user has, less what's in the categories, as of today, with
  /// every amount assigned counted, a later period's too. Negative when
  /// more was assigned than there is, or cards owe more than there is.
  final int notAssigned;

  /// What [notAssigned] starts from: cash and bank, less what cards owe.
  final int money;

  /// Posted rows in "Not categorized", and what they add up to (negative:
  /// money out). Both already count in [notAssigned].
  final int uncategorizedRows;
  final int uncategorizedNet;

  /// This period's spending since the budget began in categories nothing
  /// was assigned to: what the first-month offer names.
  final ({int count, int amount}) unassignedSpent;

  /// Accounts whose balance counts as money to budget: cash, bank and
  /// cards. A mortgage or student loan is paid down over years, not out of
  /// this month's money, so it's left out (the line Savings draws too);
  /// its payments come out of the category it's paid from.
  static bool counts(AccountInfo a, Currency main) =>
      a.isBalanceSheet && !a.deleted && a.currency == main && !isLongLoan(a);

  static bool isLongLoan(AccountInfo a) =>
      a.role == AccountRole.mortgage || a.role == AccountRole.studentLoan;

  /// The currency the budget counts in.
  static Currency currencyOf(LedgerData data) =>
      switch (data.prefs[BudgetKeys.currency]) {
        final String code => Currency.fromCode(code),
        null => mainCurrency(data),
      };

  /// The spending category a long loan's payments come out of, if any.
  static int? loanCategory(LedgerData data, int loanId) =>
      int.tryParse(data.prefs['${BudgetKeys.loanPrefix}$loanId'] ?? '');

  /// The budget for the period [start]–[end], as of [today].
  static Budget of(
    LedgerData data, {
    required DateTime start,
    required DateTime end,
    required DateTime today,
  }) {
    final main = currencyOf(data);
    final s = dateOnly(start), e = dateOnly(end);
    bool within(DateTime d) => !d.isBefore(s) && !d.isAfter(e);

    // Spending categories that still exist; a deleted one's money goes
    // back to not assigned (a merge moved its amounts first).
    final envelopes = {
      for (final a in data.accounts.values)
        if (a.type == AccountType.expense && !a.deleted && !isUncategorized(a))
          a.id,
    };
    final uncategorized = {
      for (final a in data.accounts.values)
        if (!a.deleted && isUncategorized(a)) a.id,
    };
    // A long loan's payments are its category's spending.
    final loans = <int, int>{};
    for (final a in data.accounts.values) {
      if (a.deleted || !isLongLoan(a) || a.currency != main) continue;
      final c = loanCategory(data, a.id);
      if (c != null && envelopes.contains(c)) loans[a.id] = c;
    }

    DateTime? earliest;
    final assigned = <int, int>{}, assignedBy = <int, int>{};
    final assignedAll = <int, int>{};
    for (final b in data.budgetAmounts) {
      if (!envelopes.contains(b.categoryId)) continue;
      final d = dateOnly(b.date);
      if (earliest == null || d.isBefore(earliest)) earliest = d;
      assignedAll[b.categoryId] = (assignedAll[b.categoryId] ?? 0) + b.amount;
      if (!d.isAfter(e)) {
        assignedBy[b.categoryId] = (assignedBy[b.categoryId] ?? 0) + b.amount;
      }
      if (within(d)) {
        assigned[b.categoryId] = (assigned[b.categoryId] ?? 0) + b.amount;
      }
    }
    final stored = data.prefs[BudgetKeys.began];
    final began = stored != null ? parseDateKey(stored) : earliest;

    final spent = <int, int>{}, spentCounted = <int, int>{};
    final spentBy = <int, int>{}, spentAll = <int, int>{};
    final cameIn = <int, int>{};
    var uncategorizedRows = 0, uncategorizedNet = 0;
    void spend(int id, DateTime d, int amount, bool counted) {
      if (within(d)) {
        spent[id] = (spent[id] ?? 0) + amount;
        if (counted) spentCounted[id] = (spentCounted[id] ?? 0) + amount;
      }
      if (counted) {
        spentAll[id] = (spentAll[id] ?? 0) + amount;
        if (!d.isAfter(e)) spentBy[id] = (spentBy[id] ?? 0) + amount;
      }
    }

    bool isMoney(int accountId) {
      final a = data.accounts[accountId];
      return a != null && counts(a, main);
    }

    for (final t in data.txns) {
      if (t.scheduled) continue;
      final d = dateOnly(t.date);
      final counted = began != null && !d.isBefore(began);
      final fromMoney = t.entries.any(
        (x) => x.amount < 0 && x.currency == main && isMoney(x.accountId),
      );
      for (final x in t.entries) {
        if (x.currency != main) continue;
        final a = data.accounts[x.accountId];
        if (a == null || a.deleted) continue;
        if (a.type == AccountType.income) {
          if (within(d)) cameIn[a.id] = (cameIn[a.id] ?? 0) - x.amount;
        } else if (uncategorized.contains(a.id)) {
          uncategorizedRows++;
          uncategorizedNet -= x.amount;
        } else if (envelopes.contains(a.id)) {
          spend(a.id, d, x.amount, counted);
        } else if (loans[a.id] case final c? when fromMoney && x.amount > 0) {
          // A payment into a long loan, from money that counts.
          spend(c, d, x.amount, counted);
        }
      }
    }

    final lines = <int, EnvelopeLine>{};
    var held = 0, unassignedCount = 0, unassignedAmount = 0;
    for (final id in envelopes) {
      final left = (assignedBy[id] ?? 0) - (spentBy[id] ?? 0);
      final counted = spentCounted[id] ?? 0;
      lines[id] = EnvelopeLine(
        assigned: assigned[id] ?? 0,
        spent: spent[id] ?? 0,
        left: left,
        fromBefore: left - (assigned[id] ?? 0) + counted,
      );
      held += (assignedAll[id] ?? 0) - (spentAll[id] ?? 0);
      if ((assignedBy[id] ?? 0) == 0 && counted > 0) {
        unassignedCount++;
        unassignedAmount += counted;
      }
    }

    var money = 0;
    for (final a in data.accounts.values) {
      if (counts(a, main)) money += data.balanceOf(a.id);
    }

    return Budget._(
      currency: main,
      began: began,
      lines: lines,
      cameIn: cameIn,
      notAssigned: money - held,
      money: money,
      uncategorizedRows: uncategorizedRows,
      uncategorizedNet: uncategorizedNet,
      unassignedSpent: (count: unassignedCount, amount: unassignedAmount),
    );
  }
}

/// A budget period: a calendar month, or a pay period of the schedule the
/// budget runs by.
typedef BudgetSpan = ({DateTime start, DateTime end, String label});

/// The period after [p].
BudgetSpan nextBudgetPeriod(BudgetSpan p, PaySchedule? by) =>
    budgetPeriod(DateTime(p.end.year, p.end.month, p.end.day + 1), by);

/// The period before [p].
BudgetSpan previousBudgetPeriod(BudgetSpan p, PaySchedule? by) =>
    budgetPeriod(DateTime(p.start.year, p.start.month, p.start.day - 1), by);
