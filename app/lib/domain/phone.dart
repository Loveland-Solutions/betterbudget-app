// What a phone holds (ADR 0005): the Mac's snapshot of budgets and balances, and
// the entries made on phones that the Mac hasn't taken in yet. Pure Dart; the
// files these travel in aren't decided here.
import 'dart:convert';

import 'budget.dart';
import 'ledger.dart';
import 'money.dart';
import 'pay.dart';
import 'payee_rules.dart';
import 'readiness.dart' show isSafetyNet;

/// What a phone files money in under when it is the app's one Income (rule
/// 30) and not a refund. A word, not the ledger's id for it: the ledger
/// makes its Income the first time it is wanted, so there may be none to
/// read yet.
const phoneIncomeId = 'income';

/// What a phone entry shared over categories is filed under: its lines say
/// where the money went. A word no category or account has, so a computer
/// too old to know of splits leaves the entry with the phone rather than
/// filing it wrong.
const phoneSplitId = 'split';

/// One category of a phone entry shared over several: signed as the entry
/// is, the lines adding up to it.
typedef PhoneSplitLine = ({String categoryId, int amountMinor});

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
    this.transfer = false,
    this.plan,
    this.off = const {},
    this.hadMinor,
  });

  /// What it had this period to spend (what it carried in, plus what was
  /// assigned), for the ring before its name (#241): null when it has no
  /// ring, a category saving for a bill. The share is worked out here
  /// against what's left now, so entries typed on this phone count.
  final int? hadMinor;

  /// Made here: the plan its New category page set (its categoryId
  /// means nothing until the computer makes it), which the computer gives it when it comes in.
  final CategoryPlan? plan;

  /// Made here: the accounts in its currency it isn't paid from, by the
  /// ledger's id, as Paid from on the computer keeps them (rule 28).
  final Set<String> off;

  /// Not a category: another of the ledger's accounts, picked in the
  /// Category list to move money to it (cash from an ATM, a card paid).
  /// [id] is the account's.
  final bool transfer;

  /// Made on this phone and not in the ledger yet (owner, 2026-10-08: "in a
  /// pinch, if they're out of the house, they should be able to create a new
  /// category"). Nothing is assigned to it until that is done on the computer.
  final bool madeHere;

  /// The day the bill this category is saving for is due, when it has one
  /// and it isn't paid yet: its money is spoken for.
  final DateTime? due;

  final String id;
  final String name;

  /// The app's Income, offered for money in: it holds no budget, so nothing
  /// is left in it or overspent.
  bool get isIncome => id == phoneIncomeId;

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
    this.taken = const {},
    this.data,
  });

  /// The ledger the snapshot was made from: the New category page works
  /// out a plan from it as the computer does, with its pays and periods.
  /// Null for figures made up (the preview, tests).
  final LedgerData? data;

  /// What the computer has taken in from each phone, by the phone's name
  /// for itself: a phone drops these from what it has waiting.
  final Map<String, PhoneTaken> taken;

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

  /// The category the household remembered for [payee] on [accountId], on
  /// the Payees page (owner, 2026-10-26: the phone fills it, as the
  /// computer does; it's their own decision, not a guess). Null when none
  /// is, or the category isn't one the phone lists.
  PhoneCategory? rememberedFor(String payee, String? accountId) {
    final rules = data?.payeeRules;
    final account = int.tryParse(accountId ?? '');
    if (rules == null || account == null) return null;
    final id = PayeeRuleInfo.pick(rules, account, payee, null)?.categoryId;
    return id == null
        ? null
        : categories.where((c) => c.id == '$id').firstOrNull;
  }

  /// The account [e] moved money to, when it is a transfer; otherwise null.
  PhoneAccount? transferTo(PhoneEntry e) {
    for (final a in accounts) {
      if (a.id == e.categoryId) return a;
    }
    return null;
  }

  /// The accounts money can be moved to from [from]: the others in its
  /// currency (between two currencies takes both amounts, on the computer).
  List<PhoneAccount> transferTargets(PhoneAccount from) => [
    for (final a in accounts)
      if (a.id != from.id && a.currency == from.currency) a,
  ];

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
    this.lines = const [],
  });

  /// One receipt over several categories (owner, 2026-10-17): each one and
  /// its share. [categoryId] is then [phoneSplitId]. Empty otherwise.
  final List<PhoneSplitLine> lines;

  bool get isSplit => lines.isNotEmpty;

  /// The categories it is filed in: its lines', or its own.
  Iterable<String> get categoryIds =>
      isSplit ? lines.map((l) => l.categoryId) : [categoryId];

  /// The same entry with a category made on the phone named by the
  /// ledger's id for it, now the computer has it.
  PhoneEntry withCategory(String from, String to) => PhoneEntry(
    id: id,
    categoryId: categoryId == from ? to : categoryId,
    accountId: accountId,
    payee: payee,
    amountMinor: amountMinor,
    date: date,
    madeAt: madeAt,
    lines: [
      for (final l in lines)
        (
          categoryId: l.categoryId == from ? to : l.categoryId,
          amountMinor: l.amountMinor,
        ),
    ],
  );

  /// Random, so the Mac never takes the same entry in twice.
  final String id;

  /// The category, or for a transfer the account the money went to: the
  /// ledger keeps both in one list, so an id names one or the other
  /// ([PhoneSnapshot.transferTo]). A computer too old to know of transfers
  /// leaves such an entry with the phone.
  final String categoryId;
  final String accountId;
  final String payee;

  /// Money out is negative, as in the ledger; money in (a refund to its
  /// category, or income) is positive. A transfer is what left [accountId],
  /// negative.
  final int amountMinor;
  final DateTime date;
  final DateTime madeAt;
}

/// What one phone has written to the folder for the computer: its entries
/// and the categories it made, until the computer's ledger says they are in.
class PhoneInbox {
  const PhoneInbox({
    required this.device,
    this.entries = const [],
    this.categories = const [],
  });

  /// Random, made once on the phone: it names the phone's file and its
  /// part of [PhoneTaken].
  final String device;
  final List<PhoneEntry> entries;
  final List<PhoneCategory> categories;
}

/// The preference the computer keeps what it has taken from the phones in.
const phoneTakenKey = 'phone.taken';

/// A phone's name, as the person gave it: `phone.name.<device>`. The phone
/// itself only has a random id.
const phoneNamePrefix = 'phone.name.';

/// A computer's name, as the person gave it (or the system's, until then):
/// `computer.name.<id>`, the id being the one its change file is named by.
/// A row keeps the id, so a rename shows on every row.
const computerNamePrefix = 'computer.name.';

/// The Mac a computer is, as every account on it shares one:
/// `computer.machine.<id>`. A row made under another account of this Mac
/// reads as made here.
const computerMachinePrefix = 'computer.machine.';

/// The register's Source column is shown unless this is `0` (a view, like the
/// forecast's span).
const showSourceKey = 'register.source';

/// What the computer has taken in from one phone, kept for good: an older
/// copy of the phone's file turning up in the folder must not bring an
/// entry in a second time.
class PhoneTaken {
  const PhoneTaken({this.entries = const {}, this.categories = const {}});

  /// The ids of the entries that are in the ledger.
  final Set<String> entries;

  /// The id a phone gave a category it made, to the id the ledger gave it.
  final Map<String, String> categories;

  static Map<String, PhoneTaken> decode(String? json) {
    if (json == null) return {};
    try {
      return {
        for (final MapEntry(:key, :value) in (jsonDecode(json) as Map).entries)
          '$key': PhoneTaken(
            entries: {for (final id in value['entries'] as List) '$id'},
            categories: {
              for (final MapEntry(:key, :value)
                  in (value['categories'] as Map).entries)
                '$key': '$value',
            },
          ),
      };
    } catch (_) {
      return {};
    }
  }

  static String encode(Map<String, PhoneTaken> taken) => jsonEncode({
    for (final device in taken.keys.toList()..sort())
      device: {
        'entries': taken[device]!.entries.toList()..sort(),
        'categories': {
          for (final id in taken[device]!.categories.keys.toList()..sort())
            id: taken[device]!.categories[id],
        },
      },
  });
}

/// What is left in [category] once the [waiting] entries are counted: the
/// snapshot's figure doesn't know about them yet. A refund puts money back.
/// How much of what [category] had this period is used, 0 to 1, with
/// [left] what it has now ([leftNow]): the computer's rule
/// (`EnvelopeLine.usedShare`). Null when there is no ring: a bill, or
/// nothing had and nothing spent.
double? usedShareNow(PhoneCategory category, int left) {
  final had = category.hadMinor;
  if (had == null) return null;
  if (left < 0) return 1;
  if (had <= 0) return null;
  final used = had - left;
  return used <= 0 ? 0 : (used >= had ? 1 : used / had);
}

int leftNow(PhoneCategory category, Iterable<PhoneEntry> waiting) {
  var left = category.leftMinor;
  for (final e in waiting) {
    if (e.categoryId == category.id) left += e.amountMinor;
    for (final l in e.lines) {
      if (l.categoryId == category.id) left += l.amountMinor;
    }
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

/// [minor] as the pad would have it typed: `135500`, `12.5`. Unsigned.
String typedOfMinor(int minor, Currency currency) {
  final m = minor.abs();
  final whole = m ~/ currency.scale;
  final cents = m % currency.scale;
  if (cents == 0) return '$whole';
  final text = '$cents'.padLeft(currency.decimals, '0');
  return '$whole.${text.replaceFirst(RegExp(r'0+$'), '')}';
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

  // What it had this period, for the ring; a bill has none, nor the
  // safety net, which fills rather than empties, as on the computer
  // (EnvelopeLine.usedShare; ADR 0004 "Which rows").
  int? hadOf(int id) {
    final line = budget.lines[id]!;
    if (line.plan?.plan.kind == PlanKind.byDate) return null;
    if (isSafetyNet(data.accounts[id]!)) return null;
    return line.had;
  }

  return PhoneSnapshot(
    madeAt: madeAt,
    data: data,
    taken: PhoneTaken.decode(data.prefs[phoneTakenKey]),
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
            hadMinor: hadOf(c.id),
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

/// [account]'s balance once the [waiting] entries paid from it, and the
/// transfers into it, are counted. What is owed on a card grows as money
/// goes out and shrinks as a payment comes in.
int balanceNow(PhoneAccount account, Iterable<PhoneEntry> waiting) {
  var balance = account.balanceMinor;
  for (final e in waiting) {
    final change = e.accountId == account.id
        ? e.amountMinor
        : e.categoryId == account.id
        ? -e.amountMinor
        : 0;
    balance += account.owes ? -change : change;
  }
  return balance;
}
