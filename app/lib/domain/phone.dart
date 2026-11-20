// What a phone holds (ADR 0005): the Mac's snapshot of budgets and balances, and
// the entries made on phones that the Mac hasn't taken in yet. Pure Dart; the
// files these travel in aren't decided here.
import 'dart:convert';

import 'budget.dart';
import 'ledger.dart';
import 'money.dart';
import 'pay.dart';
import 'payee_rules.dart';
import 'readiness.dart' show fundCategoryIds, isSafetyNet, savingsCurrency;
import 'sync.dart' show MadeHow;

/// What a phone files money in under when it is the app's one Income (rule
/// 30) and not a refund. A word, not the ledger's id for it: the ledger
/// makes its Income the first time it is wanted, so there may be none to
/// read yet.
const phoneIncomeId = 'income';

/// What a phone files money in under when it is one pay's paycheck (#187):
/// this, then the pay's id. The computer makes the row that pay's, so the
/// payday it stands for stops being expected. A computer too old to know
/// of it leaves the entry with the phone rather than filing it wrong.
const phonePayPrefix = 'pay:';

String phonePayId(int payId) => '$phonePayPrefix$payId';

/// The pay [id] names, or null when it isn't one.
int? phonePayOf(String id) => id.startsWith(phonePayPrefix)
    ? int.tryParse(id.substring(phonePayPrefix.length))
    : null;

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
    this.group,
    this.note,
    this.onceMinor,
    this.usualMinor,
    this.payInto,
    this.type,
    this.coverMinor = 0,
    this.coverMonth,
  });

  /// By a paycheck, what of its month's money lies outside this one, for
  /// a monthly category (#468, owner 2026-11-16: "Say it's ahead, not
  /// red"): spending past this paycheck's part that this still covers
  /// isn't overspent. 0 otherwise.
  final int coverMinor;

  /// That month (1–12), named in what's said; null with no cover.
  final int? coverMonth;

  /// Whether [left] is really short: past what its month still covers.
  bool overAt(int left) => left + coverMinor < 0;

  /// Made here: the type its New category page picked (#429), for what its
  /// plan can't say: a Goal, or a Fund with no amount yet. Null from a
  /// phone before 0.89.0.
  final CategoryType? type;

  /// A pay's paycheck, offered for money in as Income is (#187): the
  /// account the pay goes into, the only one it can come into.
  final String? payInto;

  /// Its group, a heading on Budget as on the computer (#100); none for
  /// a bill or the Safety net, which have their own places.
  final String? group;

  /// What was written about it on the computer, under its name.
  final String? note;

  /// This period has an amount of its own ("Just for September", #100):
  /// that amount, 0 when skipped, and the plan's usual one. Null otherwise.
  final int? onceMinor;
  final int? usualMinor;

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

  /// The app's Income, or one pay of it, offered for money in: it holds no
  /// budget, so nothing is left in it or overspent.
  bool get isIncome => id == phoneIncomeId || payInto != null;

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
    this.cash = false,
    this.opened = true,
    this.ahead = const [],
  });

  final String id;
  final String name;

  /// Rows dated after the day the copy was made, signed as [balanceMinor]
  /// is: a count leaves out those after its day, as the computer's does.
  final List<({DateTime date, int amountMinor})> ahead;

  /// Cash in hand (#119): counted, not reconciled.
  final bool cash;

  /// It has an opening balance. A count of one that hasn't, finding more
  /// than its rows, makes that its opening balance, as on the computer.
  final bool opened;

  /// The working balance; for a card or loan, what is owed, as a positive.
  final int balanceMinor;
  final Currency currency;

  /// A credit card or loan: its balance reads "Owed".
  final bool owes;
}

/// A pay set up on the computer, which the forecast expects (#187): a
/// phone offers it by name for money in.
class PhonePay {
  const PhonePay({required this.id, required this.accountId, this.name});

  /// [phonePayId] of the ledger's id.
  final String id;

  /// The account it goes into.
  final String accountId;

  /// What the person called it (or, from before every pay had one, who
  /// pays it); null when neither.
  final String? name;
}

class PhoneSnapshot {
  const PhoneSnapshot({
    required this.madeAt,
    required this.categories,
    required this.accounts,
    this.pays = const [],
    this.periodEnd,
    this.payees = const [],
    this.taken = const {},
    this.data,
    this.mine = const [],
    this.sums = const [],
    this.beforeMonth,
    this.budgetCurrency,
  });

  /// The Budget page's sum for each currency worth showing, worked out as
  /// the computer's is so the phone's adds up the same (#528).
  final List<BudgetSum> sums;

  /// The month the period before this one began in, for "From October".
  final int? beforeMonth;

  /// The budget's own currency: its sum shows even when it holds nothing.
  final Currency? budgetCurrency;

  /// What this phone entered that the computers haven't applied yet: rows of
  /// its own ledger, each named `row:<id>` ([phoneRowPrefix]), so one can be
  /// fixed or deleted until a computer has it (#526 piece 4).
  final List<PhoneEntry> mine;

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

  /// The pays the forecast expects, into an account the phone lists.
  final List<PhonePay> pays;

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
    this.remember = false,
  });

  /// The box under the category was ticked: the ledger remembers the
  /// category for the payee when it takes the entry in (#403).
  final bool remember;

  /// One receipt over several categories (owner, 2026-10-17): each one and
  /// its share. [categoryId] is then [phoneSplitId]. Empty otherwise.
  final List<PhoneSplitLine> lines;

  bool get isSplit => lines.isNotEmpty;

  /// The categories it is filed in: its lines', or its own.
  Iterable<String> get categoryIds =>
      isSplit ? lines.map((l) => l.categoryId) : [categoryId];

  /// The same entry under another id.
  PhoneEntry withId(String id) => PhoneEntry(
    id: id,
    categoryId: categoryId,
    accountId: accountId,
    payee: payee,
    amountMinor: amountMinor,
    date: date,
    madeAt: madeAt,
    lines: lines,
    remember: remember,
  );

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
    remember: remember,
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

/// A cash account counted on a phone (#119): what was in it. The computer
/// saves the difference from its rows as its own Count does, against
/// [categoryId] (null: Not categorized), in the order the phone's entries
/// were made, so a purchase typed after the count isn't in it.
class PhoneCount {
  const PhoneCount({
    required this.id,
    required this.accountId,
    required this.countedMinor,
    required this.date,
    required this.madeAt,
    required this.heldMinor,
    this.categoryId,
  });

  /// Random, as an entry's; the computer keeps it with the entries taken.
  final String id;
  final String accountId;
  final int countedMinor;

  /// What the phone said the account held when it was counted: the phone
  /// shows the account as counted from then on ([balanceNow]), even after
  /// a newer copy of the ledger arrives.
  final int heldMinor;
  final DateTime date;
  final DateTime madeAt;
  final String? categoryId;

  PhoneCount withCategory(String from, String to) => PhoneCount(
    id: id,
    accountId: accountId,
    countedMinor: countedMinor,
    date: date,
    madeAt: madeAt,
    heldMinor: heldMinor,
    categoryId: categoryId == from ? to : categoryId,
  );

  /// The same count with its difference to Not categorized.
  PhoneCount uncategorized() => PhoneCount(
    id: id,
    accountId: accountId,
    countedMinor: countedMinor,
    date: date,
    madeAt: madeAt,
    heldMinor: heldMinor,
  );
}

/// What of [inbox] goes to the folder now (#119): for each cash account
/// counted here, its first waiting count goes, with the entries made before
/// it or dated before its day; the entries touching that account typed
/// after it, and its later counts, stay on the phone until the computer has
/// taken that count. So no computer, of any version, takes in spending
/// from after a count before the count itself. A count of an account the
/// computer won't take ([countable] false) holds nothing back.
PhoneInbox sendingOf(
  PhoneInbox inbox,
  bool Function(String accountId) countable,
) {
  final first = <String, PhoneCount>{};
  for (final c in inbox.counts) {
    if (!countable(c.accountId)) continue;
    final was = first[c.accountId];
    if (was == null || c.madeAt.isBefore(was.madeAt)) first[c.accountId] = c;
  }
  if (first.isEmpty) return inbox;
  bool held(PhoneEntry e) {
    for (final c in first.values) {
      final touches = e.accountId == c.accountId || e.categoryId == c.accountId;
      if (touches &&
          e.madeAt.isAfter(c.madeAt) &&
          !dateOnly(e.date).isBefore(dateOnly(c.date))) {
        return true;
      }
    }
    return false;
  }

  return PhoneInbox(
    device: inbox.device,
    categories: inbox.categories,
    entries: [
      for (final e in inbox.entries)
        if (!held(e)) e,
    ],
    counts: [
      for (final c in inbox.counts)
        if (!countable(c.accountId) || identical(first[c.accountId], c)) c,
    ],
  );
}

/// What one phone has written to the folder for the computer: its entries
/// and the categories it made, until the computer's ledger says they are in.
class PhoneInbox {
  const PhoneInbox({
    required this.device,
    this.entries = const [],
    this.categories = const [],
    this.counts = const [],
  });

  /// Cash counted here (#119). A computer before 0.108.0 doesn't read them,
  /// and they wait.
  final List<PhoneCount> counts;

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
  const PhoneTaken({
    this.entries = const {},
    this.categories = const {},
    this.seen = const {},
  });

  /// The ids of the entries that are in the ledger.
  final Set<String> entries;

  /// The id a phone gave a category it made, to the id the ledger gave it.
  final Map<String, String> categories;

  /// Each taken category as the phone's file had it when last read (its
  /// name, currency, plan and accounts, in one string): one the phone
  /// changes after the computer took it in is said, not applied (#243).
  /// None for a category taken by an older version: read again, it's
  /// recorded with nothing said.
  final Map<String, String> seen;

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
            seen: {
              for (final MapEntry(:key, :value)
                  in ((value['seen'] as Map?) ?? const {}).entries)
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
        if (taken[device]!.seen.isNotEmpty)
          'seen': {
            for (final id in taken[device]!.seen.keys.toList()..sort())
              id: taken[device]!.seen[id],
          },
      },
  });
}

/// What is left in [category] once the [waiting] entries are counted: the
/// snapshot's figure doesn't know about them yet. A refund puts money back.
/// How much of what [category] had this period is used, 0 to 1, with
/// [left] what it has now ([leftNow]): the computer's rule
/// (`EnvelopeLine.usedShare`). Null when there is no ring: a bill, or
/// nothing had this period, spent from or not.
double? usedShareNow(PhoneCategory category, int left) {
  final had = category.hadMinor;
  if (had == null) return null;
  if (had <= 0) return null;
  if (left < 0) return 1;
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
    final name = nameKey(c.name);
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
  for (final c in categories) {
    if (sameName(c.name, name)) return c;
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
  Set<int> mineIds = const {},
  String? device,
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
        return order != 0 ? order : compareNames(a.name, b.name);
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
      // A count of cash says nothing about where a category is paid from.
      if (t.counted != null) continue;
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
  // By a paycheck, a monthly category's month still covering it (#468).
  final month = by == null ? null : budgetPeriod(period.end, null);
  final monthBudget = month == null
      ? null
      : Budget.of(data, start: month.start, end: month.end, today: today);
  int coverOf(int id) {
    final plan = data.plans[id];
    if (monthBudget == null) return 0;
    if (plan != null &&
        (plan.kind != PlanKind.each || plan.payScheduleId != null)) {
      return 0;
    }
    final m = monthBudget.lines[id];
    if (m == null || m.left < 0) return 0;
    final rest = m.left - budget.lines[id]!.left;
    return rest > 0 ? rest : 0;
  }

  int? hadOf(int id) {
    final line = budget.lines[id]!;
    if (line.plan?.plan.kind == PlanKind.byDate) return null;
    if (isSafetyNet(data.accounts[id]!)) return null;
    return line.had;
  }

  final spending = [for (final id in budget.lines.keys) ?data.accounts[id]];
  final aheadBy = spentAhead(data, budget, periodEnd: period.end, today: today);
  final saved = fundCategoryIds(data, savingsCurrency(data));
  return PhoneSnapshot(
    madeAt: madeAt,
    data: data,
    sums: [
      for (final p in budget.pools)
        if (p.currency == budget.currency ||
            p.income != 0 ||
            p.toCome != 0 ||
            p.fromBefore != 0 ||
            p.hadBefore != 0 ||
            p.exchanged != 0 ||
            p.assigned != 0 ||
            p.overspent != 0 ||
            p.loose != 0)
          BudgetSum.of(
            p,
            budget: budget,
            spending: spending,
            saved: saved,
            aheadBy: aheadBy,
          ),
    ],
    beforeMonth: previousBudgetPeriod(period, by).start.month,
    budgetCurrency: budget.currency,
    mine: device == null ? const [] : ownEntriesOf(data, mineIds, device),
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
            // Its own Paid from (#180), else where its last row was paid.
            paidFromId: (data.paidFrom[c.id] ?? paidFrom[c.id])?.toString(),
            recentPayees: payees[c.id] ?? const [],
            due: dueOf(c.id),
            hadMinor: hadOf(c.id),
            coverMinor: coverOf(c.id),
            coverMonth: coverOf(c.id) > 0 ? month!.start.month : null,
            group:
                budget.lines[c.id]!.plan?.plan.kind == PlanKind.byDate ||
                    isSafetyNet(c)
                ? null
                : c.budgetGroup,
            note: c.note,
            onceMinor: switch (budget.lines[c.id]!.plan) {
              final p? when p.once => p.each,
              _ => null,
            },
            usualMinor: switch (budget.lines[c.id]!.plan) {
              final p? when p.once => p.plan.amount,
              _ => null,
            },
          ),
    ],
    pays: [
      for (final p in data.paySchedules)
        if (data.accounts[p.accountId] case final a?
            when !a.deleted && !a.archived)
          PhonePay(
            id: phonePayId(p.id),
            accountId: '${p.accountId}',
            name: [p.name, p.payee]
                .map((n) => n?.trim() ?? '')
                .where((n) => n.isNotEmpty)
                .firstOrNull,
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
            cash: a.isCash,
            ahead: [
              for (final t in data.txns)
                if (!t.scheduled && t.date.isAfter(today))
                  for (final e in t.entries)
                    if (e.accountId == a.id)
                      (
                        date: t.date,
                        amountMinor: a.isOwed ? -e.amount : e.amount,
                      ),
            ],
            opened:
                !a.isCash ||
                data
                    .registerFor(a.id)
                    .posted
                    .any(
                      (r) =>
                          r.kind == RowKind.opening &&
                          r.equity == AppEquity.openingBalances,
                    ),
          ),
    ],
  );
}

/// [account]'s balance once the [waiting] entries paid from it, and the
/// transfers into it, are counted. What is owed on a card grows as money
/// goes out and shrinks as a payment comes in. A cash account counted here
/// ([counts]) is off from it by what each count found: counted, the moment
/// it is saved, and what is typed after it. With [through], only what is
/// dated through that day: what a count there measures, as the computer's
/// does.
int balanceNow(
  PhoneAccount account,
  Iterable<PhoneEntry> waiting, [
  Iterable<PhoneCount> counts = const [],
  DateTime? through,
]) {
  bool later(DateTime d) => through != null && d.isAfter(through);
  var balance = account.balanceMinor;
  for (final r in account.ahead) {
    if (later(r.date)) balance -= r.amountMinor;
  }
  for (final e in waiting) {
    if (later(e.date)) continue;
    final change = e.accountId == account.id
        ? e.amountMinor
        : e.categoryId == account.id
        ? -e.amountMinor
        : 0;
    balance += account.owes ? -change : change;
  }
  for (final c in counts) {
    if (c.accountId == account.id && !later(c.date)) {
      balance += c.countedMinor - c.heldMinor;
    }
  }
  return balance;
}

/// What names an entry that is a row of the phone's own ledger, not one
/// waiting: `row:` and the transaction's id.
const phoneRowPrefix = 'row:';

/// The id of the ledger row a phone entry names, or null for a waiting one.
int? phoneRowOf(String id) => id.startsWith(phoneRowPrefix)
    ? int.tryParse(id.substring(phoneRowPrefix.length))
    : null;

/// The rows [ids] of [data] that this phone ([device]) made, as entries a
/// person can open again: money out of one account to a category, money in,
/// a transfer (its "category" is the account it went to), or one receipt
/// over several categories. A count is not an entry, and a row made
/// elsewhere isn't this phone's.
List<PhoneEntry> ownEntriesOf(LedgerData data, Set<int> ids, String device) {
  bool holds(int account) => switch (data.accounts[account]?.type) {
    AccountType.asset || AccountType.liability => true,
    _ => false,
  };
  final out = <PhoneEntry>[];
  for (final t in data.txns) {
    if (!ids.contains(t.id) ||
        t.madeHow != MadeHow.phone ||
        t.madeOn != device ||
        t.counted != null ||
        t.scheduled) {
      continue;
    }
    final mine = [
      for (final e in t.entries)
        if (holds(e.accountId)) e,
    ];
    final others = [
      for (final e in t.entries)
        if (!holds(e.accountId)) e,
    ];
    // A transfer has two accounts and no category: the one money left is
    // where it was paid from.
    final account = mine.length == 2
        ? mine.firstWhere((e) => e.amount < 0, orElse: () => mine.first)
        : mine.singleOrNull;
    if (account == null) continue;
    final to = mine.length == 2
        ? mine.firstWhere((e) => !identical(e, account))
        : null;
    String category(EntryData e) =>
        data.accounts[e.accountId]?.type == AccountType.income
        ? phoneIncomeId
        : '${e.accountId}';
    if (to == null && others.isEmpty) continue;
    final split = to == null && others.length > 1;
    out.add(
      PhoneEntry(
        id: '$phoneRowPrefix${t.id}',
        categoryId: split
            ? phoneSplitId
            : to != null
            ? '${to.accountId}'
            : category(others.single),
        accountId: '${account.accountId}',
        payee: to != null ? '' : t.payee ?? '',
        amountMinor: account.amount,
        date: t.date,
        madeAt: t.date,
        lines: split
            ? [
                for (final e in others)
                  (categoryId: category(e), amountMinor: -e.amount),
              ]
            : const [],
      ),
    );
  }
  return out;
}
