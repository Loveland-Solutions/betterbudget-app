// What a phone holds (ADR 0005): the Mac's snapshot of budgets and balances, and
// the entries made on phones that the Mac hasn't taken in yet. Pure Dart; the
// files these travel in aren't decided here.
import 'budget.dart';
import 'ledger.dart';
import 'money.dart';
import 'pay.dart';

/// A spending category as the Mac last reported it.
class PhoneCategory {
  const PhoneCategory({
    required this.id,
    required this.name,
    required this.leftMinor,
    this.currency = Currency.mnt,
    this.paidFromId,
    this.recentPayees = const [],
    this.due,
    this.madeHere = false,
  });

  /// Made on this phone and not in the ledger yet (owner, 2026-10-08: "in a
  /// pinch, if they're out of the house, they should be able to create a new
  /// category"). Nothing is assigned to it until that is done on the computer.
  final bool madeHere;

  /// The day the bill this category is saving for is due, when it has one
  /// and it isn't paid yet: its money is spoken for.
  final DateTime? due;

  final String id;
  final String name;

  /// What was left when the snapshot was made; below zero when overspent.
  final int leftMinor;
  final Currency currency;

  /// The account an entry here starts with: the category's Paid from, or the
  /// one its rows were last paid from. Null: the first account in its currency.
  final String? paidFromId;

  /// Payees of this category's rows, newest first, each once: offered
  /// first as a payee is typed.
  final List<String> recentPayees;
}

class PhoneAccount {
  const PhoneAccount({
    required this.id,
    required this.name,
    required this.balanceMinor,
    this.currency = Currency.mnt,
    this.owes = false,
  });

  final String id;
  final String name;

  /// The working balance; for a card or loan, what is owed, as a positive.
  final int balanceMinor;
  final Currency currency;

  /// A credit card or loan: its balance reads "Owed".
  final bool owes;
}

class PhoneSnapshot {
  const PhoneSnapshot({
    required this.madeAt,
    required this.categories,
    required this.accounts,
    this.periodEnd,
    this.payees = const [],
  });

  /// Every payee in the ledger, newest first, each once.
  final List<String> payees;

  /// Payees from the ledger's history that fit what has been [typed] for an
  /// entry in [category] (null while none is chosen): none until something is typed (owner, 2026-10-07:
  /// no payee filled in, no row of ready-made ones), then this category's
  /// own before the rest, and names that begin with it before names that
  /// only hold it.
  List<String> payeesMatching(String typed, PhoneCategory? category) {
    final want = typed.trim().toLowerCase();
    if (want.isEmpty) return const [];
    final begins = <String>[], holds = <String>[];
    for (final p in [...?category?.recentPayees, ...payees]) {
      final name = p.toLowerCase();
      if (begins.contains(p) || holds.contains(p)) continue;
      if (name.startsWith(want)) {
        begins.add(p);
      } else if (name.contains(want)) {
        holds.add(p);
      }
    }
    return [...begins, ...holds].take(5).toList();
  }

  /// The last day of the budget period the figures are for, when the budget
  /// runs by pay periods; null when it runs by calendar months.
  final DateTime? periodEnd;

  /// When the Mac wrote it; the phone shows this, since its figures are only
  /// as fresh as the last copy to arrive.
  final DateTime madeAt;
  final List<PhoneCategory> categories;
  final List<PhoneAccount> accounts;

  /// The accounts an entry in [category] can be paid from: those in its
  /// currency.
  List<PhoneAccount> accountsFor(PhoneCategory category) => [
    for (final a in accounts)
      if (a.currency == category.currency) a,
  ];
}

/// One transaction typed on a phone, waiting for the Mac.
class PhoneEntry {
  const PhoneEntry({
    required this.id,
    required this.categoryId,
    required this.accountId,
    required this.payee,
    required this.amountMinor,
    required this.date,
    required this.madeAt,
  });

  /// Random, so the Mac never takes the same entry in twice.
  final String id;
  final String categoryId;
  final String accountId;
  final String payee;

  /// Money out is negative, as in the ledger.
  final int amountMinor;
  final DateTime date;
  final DateTime madeAt;
}

/// What is left in [category] once the [waiting] entries are counted: the
/// snapshot's figure doesn't know about them yet.
int leftNow(PhoneCategory category, Iterable<PhoneEntry> waiting) {
  var left = category.leftMinor;
  for (final e in waiting) {
    if (e.categoryId == category.id) left += e.amountMinor;
  }
  return left;
}

/// The [categories] that fit what has been [typed] in the category list: all
/// of them, in their own order, until something is typed; then names that
/// begin with it before names that only hold it.
List<PhoneCategory> categoriesMatching(
  Iterable<PhoneCategory> categories,
  String typed,
) {
  final want = typed.trim().toLowerCase();
  if (want.isEmpty) return categories.toList();
  final begins = <PhoneCategory>[], holds = <PhoneCategory>[];
  for (final c in categories) {
    final name = c.name.toLowerCase();
    if (name.startsWith(want)) {
      begins.add(c);
    } else if (name.contains(want)) {
      holds.add(c);
    }
  }
  return [...begins, ...holds];
}

/// The category already called [name], whatever its capitals: a second one
/// by the same name is never made.
PhoneCategory? categoryNamed(Iterable<PhoneCategory> categories, String name) {
  final want = name.trim().toLowerCase();
  for (final c in categories) {
    if (c.name.trim().toLowerCase() == want) return c;
  }
  return null;
}

/// The amount pad's text after [key] is pressed: a digit, `.` or `<` for
/// delete. A second point, digits past the currency's cents, and a leading
/// zero before another digit are left out.
String pressAmountKey(String typed, String key, Currency currency) {
  if (key == '<') {
    return typed.isEmpty ? typed : typed.substring(0, typed.length - 1);
  }
  final point = typed.indexOf('.');
  if (key == '.') {
    if (currency.decimals == 0 || point >= 0) return typed;
    return typed.isEmpty ? '0.' : '$typed.';
  }
  if (point >= 0 && typed.length - point - 1 >= currency.decimals) return typed;
  if (typed == '0') return key;
  // Twelve whole digits is past any household amount and well inside an int.
  if (point < 0 && typed.length >= 12) return typed;
  return '$typed$key';
}

/// The pad's text as minor units: `12500` is 1250000 in tugrik, `12.5` is 1250.
int typedAmountMinor(String typed, Currency currency) {
  if (typed.isEmpty) return 0;
  final parts = typed.split('.');
  final whole = int.parse(parts[0].isEmpty ? '0' : parts[0]);
  final cents = parts.length > 1
      ? parts[1].padRight(currency.decimals, '0')
      : '0' * currency.decimals;
  return whole * currency.scale + (cents.isEmpty ? 0 : int.parse(cents));
}

/// The pad's text as it reads above the keys, grouped in thousands with the
/// currency in front: `₮12,500`, `$12.5`.
String typedAmountShown(String typed, Currency currency) {
  final parts = typed.split('.');
  final whole = int.parse(parts[0].isEmpty ? '0' : parts[0]);
  final grouped = formatWhole(whole * currency.scale, currency);
  return '${currency.prefix}$grouped${parts.length > 1 ? '.${parts[1]}' : ''}';
}

/// What a phone shows of [data], the ledger as the computer last stored it:
/// what each spending category holds as of [today], each account's balance,
/// and the payees and account its latest rows used, so an entry starts with
/// them. [madeAt] is when that copy of the ledger was written.
PhoneSnapshot snapshotOf(
  LedgerData data, {
  required DateTime today,
  required DateTime madeAt,
}) {
  // The period the Mac's Budget page opens on, so the two agree.
  final by = data.periodSchedule;
  final period = budgetPeriod(today, by);
  final budget = Budget.of(
    data,
    start: period.start,
    end: period.end,
    today: today,
  );
  List<AccountInfo> sorted(Iterable<AccountInfo> accounts) =>
      accounts.toList()..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order != 0 ? order : a.name.compareTo(b.name);
      });

  // Newest first, to find what each category's latest rows used.
  final rows =
      [
        for (final t in data.txns)
          if (!t.scheduled) t,
      ]..sort((a, b) {
        final day = b.date.compareTo(a.date);
        return day != 0 ? day : b.id.compareTo(a.id);
      });
  final payees = <int, List<String>>{};
  final everyPayee = <String>[];
  final paidFrom = <int, int>{};
  for (final t in rows) {
    final payee = t.payee?.trim() ?? '';
    if (payee.isNotEmpty &&
        everyPayee.length < 500 &&
        !everyPayee.contains(payee)) {
      everyPayee.add(payee);
    }
    for (final e in t.entries) {
      if (!budget.lines.containsKey(e.accountId)) continue;
      final seen = payees.putIfAbsent(e.accountId, () => []);
      if (payee.isNotEmpty && seen.length < 50 && !seen.contains(payee)) {
        seen.add(payee);
      }
      for (final other in t.entries) {
        final account = data.accounts[other.accountId];
        if (account != null && account.isBalanceSheet && !account.deleted) {
          paidFrom.putIfAbsent(e.accountId, () => account.id);
        }
      }
    }
  }

  DateTime? dueOf(int id) {
    final plan = budget.lines[id]!.plan;
    return plan == null || plan.done || plan.ended ? null : plan.due;
  }

  return PhoneSnapshot(
    madeAt: madeAt,
    periodEnd: by == null ? null : period.end,
    payees: everyPayee,
    categories: [
      for (final c in sorted([
        for (final id in budget.lines.keys) data.accounts[id]!,
      ]))
        // An archived category shows only while money still sits in it.
        if (!c.archived || budget.lines[c.id]!.left != 0)
          PhoneCategory(
            id: '${c.id}',
            name: c.name,
            leftMinor: budget.lines[c.id]!.left,
            currency: budget.lines[c.id]!.currency,
            // Its own Paid from when it has one, else where its last row was paid.
            paidFromId: (data.plans[c.id]?.paidFrom ?? paidFrom[c.id])
                ?.toString(),
            recentPayees: payees[c.id] ?? const [],
            due: dueOf(c.id),
          ),
    ],
    accounts: [
      for (final a in sorted(data.accounts.values))
        if (a.isBalanceSheet && !a.deleted && !a.archived)
          PhoneAccount(
            id: '${a.id}',
            name: a.name,
            // What's owed reads as a positive amount, the way the bank shows it.
            balanceMinor: a.isOwed
                ? -data.balanceOf(a.id)
                : data.balanceOf(a.id),
            currency: a.currency,
            owes: a.isOwed,
          ),
    ],
  );
}

/// [account]'s balance once the [waiting] entries paid from it are counted.
/// What is owed on a card grows as money goes out.
int balanceNow(PhoneAccount account, Iterable<PhoneEntry> waiting) {
  var balance = account.balanceMinor;
  for (final e in waiting) {
    if (e.accountId != account.id) continue;
    balance += account.owes ? -e.amountMinor : e.amountMinor;
  }
  return balance;
}
