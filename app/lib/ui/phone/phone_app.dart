// The phone app (ADR 0005; the screens are ADR 0004 "Phone screens"): it opens
// on Ledger, everything a transaction needs, with the category picked or typed
// from a list that can also make one; Budget, what is left in each category,
// is the other screen. Entries and new categories wait in [PhoneStore] until
// the Mac takes them in.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/ledger.dart' show isIncomeName;
import '../../domain/money.dart';
import '../../domain/phone.dart';
import '../language.dart';
import '../schemes.dart';
import '../theme.dart';

/// The snapshot and this phone's waiting entries. Where they are kept and how
/// they reach the Mac is the store's business; the screens only read and add.
class PhoneStore extends ChangeNotifier {
  PhoneStore(
    this._snapshot, {
    this.device = 'preview',
    List<PhoneEntry> waiting = const [],
    List<PhoneCategory> made = const [],
  }) : _waiting = [...waiting] {
    _made.addAll(made);
    _dropTaken();
  }

  /// This phone's name for itself in the folder.
  final String device;

  /// What this phone has for the computer.
  PhoneInbox get inbox => PhoneInbox(
    device: device,
    entries: List.unmodifiable(_waiting),
    categories: List.unmodifiable(_made),
  );

  /// Lets go of what the computer's ledger says it has taken in. An entry
  /// still waiting in a category that is now the ledger's follows it there.
  void _dropTaken() {
    final taken = _snapshot.taken[device];
    if (taken == null) return;
    _waiting.removeWhere((e) => taken.entries.contains(e.id));
    for (final c in [..._made]) {
      final real = taken.categories[c.id];
      if (real == null) continue;
      for (var i = 0; i < _waiting.length; i++) {
        final e = _waiting[i];
        if (!e.categoryIds.contains(c.id)) continue;
        _waiting[i] = e.withCategory(c.id, real);
      }
      _made.remove(c);
    }
  }

  PhoneSnapshot _snapshot;
  final List<PhoneEntry> _waiting;

  /// Categories made on this phone, waiting for the Mac as its entries do.
  final List<PhoneCategory> _made = [];

  PhoneSnapshot get snapshot => _snapshot;
  List<PhoneEntry> get waiting => List.unmodifiable(_waiting);
  List<PhoneCategory> get made => List.unmodifiable(_made);

  /// The ledger's categories, then the ones made here.
  List<PhoneCategory> get categories => [..._snapshot.categories, ..._made];

  /// The category called [name], made now unless there is one already
  /// (whatever its capitals).
  PhoneCategory categoryCalled(String name, Currency currency) {
    final already = categoryNamed(categories, name);
    if (already != null) return already;
    final random = Random.secure();
    final category = PhoneCategory(
      id: 'new-${[for (var i = 0; i < 8; i++) random.nextInt(256).toRadixString(16).padLeft(2, '0')].join()}',
      name: name.trim(),
      leftMinor: 0,
      currency: currency,
      madeHere: true,
    );
    _made.add(category);
    notifyListeners();
    return category;
  }

  /// Takes back a category made here, and the entries filed in it.
  void removeCategory(String id) {
    _made.removeWhere((c) => c.id == id);
    _waiting.removeWhere((e) => e.categoryIds.contains(id));
    notifyListeners();
  }

  set snapshot(PhoneSnapshot value) {
    _snapshot = value;
    _dropTaken();
    notifyListeners();
  }

  void add(PhoneEntry entry) {
    _waiting.add(entry);
    notifyListeners();
  }

  void remove(String id) {
    _waiting.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}

/// The phone keeps dark Blue eclipse until its own turn at the new colors
/// (owner, 2026-10-09: "Let's start with just the computer"). Called before
/// the phone's screens are built, by the app, the preview and the tests.
void usePhoneColors() =>
    Mid.palette = Palette.of(blueEclipseScheme, Brightness.dark);

/// The phone app's frame: its look and its words, around [child].
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'BetterBudget',
    theme: appTheme(),
    locale: LanguageScope.maybeOf(context)?.locale,
    supportedLocales: supportedLocales,
    localizationsDelegates: Words.localizationsDelegates,
    localeListResolutionCallback: (preferred, _) => resolveLocale(preferred),
    home: child,
  );
}

/// The phone's screens on a [store] that is already filled: tests, and the
/// preview on invented figures.
class PhoneApp extends StatelessWidget {
  const PhoneApp({super.key, required this.store, this.now});
  final PhoneStore store;

  /// The clock, so a test can hold it still.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) => PhoneFrame(
    child: PhoneHome(store: store, now: now ?? DateTime.now),
  );
}

String _clock(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// An entry's amount as the ledger shows it: money in with a plus, money
/// out with a minus.
String _signed(int minor, Currency currency) =>
    '${minor > 0 ? '+' : ''}${formatMoney(minor, currency: currency)}';

/// When the figures came from the computer. Gold once they aren't today's:
/// older figures look the same as fresh ones otherwise.
class _FromMac extends StatelessWidget {
  const _FromMac({required this.made, required this.today});
  final DateTime made;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final fresh = _sameDay(made, today);
    return Text(
      fresh
          ? t.phoneFromMacToday(_clock(made))
          : t.phoneFromMacOn(fullDate(made), _clock(made)),
      key: const ValueKey('from-mac'),
      style: onest(13, color: fresh ? Mid.ink2 : Mid.gold),
    );
  }
}

/// An amount with its cents while the line has room for them (owner,
/// 2026-10-07: "show the full tugrik amount if there is room").
class _RoomMoney extends StatelessWidget {
  const _RoomMoney(
    this.minor,
    this.currency, {
    required this.room,
    this.spokenFor = false,
  });
  final int minor;
  final Currency currency;

  /// Money waiting for a bill: drawn quieter than money free to spend.
  final bool spokenFor;

  /// The width this amount may take.
  final double room;

  static const double size = 18;

  static double width(String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: onest(size, weight: 600, tabular: true),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final w = painter.width;
    painter.dispose();
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final full = formatMoney(minor, currency: currency);
    final text = width(full) <= room
        ? full
        : formatMoney(minor, showCents: false, currency: currency);
    return Text(
      text,
      maxLines: 1,
      softWrap: false,
      style: onest(
        size,
        weight: 600,
        tabular: true,
        color: minor < 0
            ? Mid.coral
            : spokenFor
            ? Mid.ink3
            : Mid.ink,
      ),
    );
  }
}

/// The entry being typed. Held above the two screens, so a look at Budget
/// doesn't lose it.
class _Draft extends ChangeNotifier {
  String typed = '';

  /// Money coming in, a refund or income, chosen with the +/− beside the
  /// amount. Money out until then.
  bool moneyIn = false;

  /// Nothing until it is typed: a payee filled in ahead is saved by mistake.
  String? payee;
  String? categoryId;

  /// The account chosen under Paid from; null until one is.
  String? accountId;

  /// Null is today.
  DateTime? date;

  /// One receipt over several categories: each category and what is typed
  /// for it. [categoryId] is then [phoneSplitId]. Empty for one category.
  List<({String categoryId, String typed})> lines = [];

  bool get isSplit => lines.isNotEmpty;

  void change(VoidCallback make) {
    make();
    notifyListeners();
  }

  /// Files the entry in [category]. An account among [accounts] that isn't
  /// in its currency can't be used with it: the row is empty again, not
  /// kept out of sight to come back when the category changes.
  void choose(PhoneCategory category, List<PhoneAccount> accounts) =>
      change(() {
        categoryId = category.id;
        lines = [];
        // Money moved is never money in, and never to the account it left.
        // Nor is anyone paid: a payee typed before isn't kept out of sight.
        if (category.transfer) {
          moneyIn = false;
          payee = null;
          if (accountId == category.id) accountId = null;
        }
        if (!category.isIncome &&
            !accounts.any(
              (a) => a.id == accountId && a.currency == category.currency,
            )) {
          accountId = null;
        }
        fit(category.currency);
      });

  /// Cents [currency] can't hold are cut from what is typed: read in the
  /// new currency they'd be another amount.
  void fit(Currency currency) {
    final point = typed.indexOf('.');
    if (point < 0) return;
    final decimals = currency.decimals;
    typed = decimals == 0
        ? typed.substring(0, point)
        : typed.substring(0, min(typed.length, point + 1 + decimals));
  }

  /// Money out to money in, and back. Income is only for money in, so it
  /// isn't left chosen on money out.
  void flipSign() => change(() {
    moneyIn = !moneyIn;
    if (!moneyIn && categoryId == phoneIncomeId) categoryId = null;
    // Income is only for money in, on a split's line too.
    if (!moneyIn) {
      lines = [
        for (final l in lines)
          if (l.categoryId != phoneIncomeId) l,
      ];
      if (lines.isEmpty && categoryId == phoneSplitId) categoryId = null;
    }
  });

  /// Ready for the next entry, Paid from included: kept, a cash taxi would
  /// put every later entry on Cash.
  void clear() => change(() {
    typed = '';
    moneyIn = false;
    payee = null;
    categoryId = null;
    accountId = null;
    date = null;
    lines = [];
  });
}

/// Money to spend first; then, where null stands for the **Bills** heading,
/// the categories whose money is waiting for a bill (owner, 2026-10-07:
/// rent's money read as money to spend).
List<PhoneCategory?> _spendThenBills(List<PhoneCategory> categories) => [
  for (final c in categories)
    if (c.due == null) c,
  if (categories.any((c) => c.due != null)) null,
  for (final c in categories)
    if (c.due != null) c,
];

class _BillsHeading extends StatelessWidget {
  const _BillsHeading();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
    child: Text(
      context.t.phoneBills,
      key: const ValueKey('bills-heading'),
      style: onest(14, weight: 600, color: Mid.ink2),
    ),
  );
}

/// The phone's two screens (owner, 2026-10-08): **Ledger**, where the app
/// opens and a transaction is typed, and **Budget**, what is left in each
/// category, with the switch between them along the bottom.
class PhoneHome extends StatefulWidget {
  const PhoneHome({
    super.key,
    required this.store,
    required this.now,
    this.onRefresh,
  });
  final PhoneStore store;
  final DateTime Function() now;

  /// Reads the ledger from the folder again, on a pull down; null when
  /// there is no folder to read (the preview).
  final Future<void> Function()? onRefresh;

  @override
  State<PhoneHome> createState() => _PhoneHomeState();
}

class _PhoneHomeState extends State<PhoneHome> {
  final _draft = _Draft();
  var _budget = false;

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // The phone's Back on Budget goes to Ledger, not out of the app.
    return PopScope(
      canPop: !_budget,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) setState(() => _budget = false);
      },
      child: Scaffold(
        backgroundColor: Mid.ground,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: _budget ? 1 : 0,
                  children: [
                    _EntryScreen(
                      store: widget.store,
                      draft: _draft,
                      now: widget.now,
                    ),
                    _BudgetScreen(
                      store: widget.store,
                      now: widget.now,
                      onRefresh: widget.onRefresh,
                      // A category here starts an entry in it; what is
                      // already typed stays.
                      onCategory: (category) {
                        if (_draft.isSplit) {
                          // A split being typed keeps its lines: the
                          // category joins them, once.
                          if (_draft.lines.every(
                            (l) => l.categoryId != category.id,
                          )) {
                            _draft.change(
                              () => _draft.lines = [
                                ..._draft.lines,
                                (categoryId: category.id, typed: ''),
                              ],
                            );
                          }
                        } else {
                          _draft.choose(
                            category,
                            widget.store.snapshot.accounts,
                          );
                        }
                        setState(() => _budget = false);
                      },
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: Mid.rule),
              Row(
                children: [
                  _SwitchItem(
                    key: const ValueKey('to-ledger'),
                    label: t.ledgerSectionLedger,
                    chosen: !_budget,
                    onTap: () => setState(() => _budget = false),
                  ),
                  _SwitchItem(
                    key: const ValueKey('to-budget'),
                    label: t.ledgerSectionBudget,
                    chosen: _budget,
                    onTap: () => setState(() => _budget = true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchItem extends StatelessWidget {
  const _SwitchItem({
    super.key,
    required this.label,
    required this.chosen,
    required this.onTap,
  });
  final String label;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      selected: chosen,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Center(
            child: Text(
              label,
              style: onest(
                16,
                weight: chosen ? 600 : 400,
                color: chosen ? Mid.blue : Mid.ink2,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// What is left in each category, from the computer's last copy.
class _BudgetScreen extends StatelessWidget {
  const _BudgetScreen({
    required this.store,
    required this.now,
    required this.onCategory,
    this.onRefresh,
  });
  final PhoneStore store;
  final DateTime Function() now;
  final ValueChanged<PhoneCategory> onCategory;
  final Future<void> Function()? onRefresh;

  Future<void> _newCategory(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NewCategoryDialog(store: store),
    );
    if (name == null) return;
    store.categoryCalled(
      name,
      store.snapshot.accounts.firstOrNull?.currency ?? Currency.mnt,
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final t = context.t;
      final snapshot = store.snapshot;
      final today = now();
      final listed = _spendThenBills(store.categories);
      // "+ New category" ends the money to spend, where the new row lands.
      final newAt = listed.contains(null)
          ? listed.indexOf(null)
          : listed.length;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snapshot.periodEnd == null
                            ? t.phoneLeftIn(monthName(t, today.month))
                            : t.phoneLeftUntil(shortDate(snapshot.periodEnd!)),
                        style: onest(20, weight: 600),
                      ),
                      const SizedBox(height: 4),
                      _FromMac(made: snapshot.madeAt, today: today),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _AccountsScreen(store: store, now: now),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: Mid.blue,
                    textStyle: onest(15),
                  ),
                  child: Text(t.ledgerGroupAccounts),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                onRefresh: onRefresh ?? () async {},
                notificationPredicate: (_) => onRefresh != null,
                color: Mid.blue,
                backgroundColor: Mid.raised,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: listed.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    if (i == newAt) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: const ValueKey('budget-new-category'),
                          onPressed: () => _newCategory(context),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            foregroundColor: Mid.blue,
                            textStyle: onest(16),
                          ),
                          child: Text(t.phoneNewCategory),
                        ),
                      );
                    }
                    final category = listed[i > newAt ? i - 1 : i];
                    if (category == null) return const _BillsHeading();
                    return _CategoryRow(
                      category: category,
                      left: leftNow(category, store.waiting),
                      onTap: () => onCategory(category),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// A category and what is left in it: on Budget, and in the list a
/// category is chosen from.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.left,
    required this.onTap,
  });
  final PhoneCategory category;
  final int left;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // Its money is spoken for (the bill it is saving for), or it was made
    // on this phone and holds nothing until money is assigned.
    final under = category.due != null
        ? t.phoneDue(shortDate(category.due!))
        : category.madeHere
        ? t.phoneNothingAssigned
        : null;
    return Material(
      color: Mid.card,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, box) {
                final nameStyle = onest(17, weight: 500);
                final name = TextPainter(
                  text: TextSpan(text: category.name, style: nameStyle),
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                )..layout();
                // The row less the gap and the name: what the amount can
                // have before the name would be cut short.
                final room = box.maxWidth - 12 - name.width;
                name.dispose();
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            category.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: nameStyle,
                          ),
                          if (under != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                under,
                                style: onest(12, color: Mid.ink2),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Income holds no budget: there is no figure for it.
                    if (!category.isIncome) ...[
                      const SizedBox(width: 12),
                      _RoomMoney(
                        left,
                        category.currency,
                        room: room,
                        spokenFor: category.due != null,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Ledger, where the app opens: everything a transaction needs. The amount
/// on the pad, then Payee, Category, Paid from, Date and Save, in any order.
class _EntryScreen extends StatefulWidget {
  const _EntryScreen({
    required this.store,
    required this.draft,
    required this.now,
  });
  final PhoneStore store;
  final _Draft draft;
  final DateTime Function() now;

  @override
  State<_EntryScreen> createState() => _EntryState();
}

class _EntryState extends State<_EntryScreen> {
  /// What Save found missing, said above it until the next key or choice.
  String? _missing;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  PhoneStore get _store => widget.store;
  _Draft get _draft => widget.draft;

  /// The account money is being moved to, when that is what was picked in
  /// the Category list.
  PhoneAccount? get _to {
    for (final a in _store.snapshot.accounts) {
      if (a.id == _draft.categoryId) return a;
    }
    return null;
  }

  PhoneCategory _transferTo(PhoneAccount to) => PhoneCategory(
    id: to.id,
    name: context.t.phoneTransferTo(to.name),
    leftMinor: 0,
    currency: to.currency,
    transfer: true,
  );

  /// A category or Income by its id, as the phone knows them.
  PhoneCategory? _categoryOf(String id) {
    if (id == phoneIncomeId) return _income;
    for (final c in _store.categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// A split's categories, in its lines' order.
  List<PhoneCategory> get _splitCategories => [
    for (final l in _draft.lines) ?_categoryOf(l.categoryId),
  ];

  PhoneCategory? get _category {
    // A split's first category stands for it where one is asked for (its
    // currency, the accounts it can be paid from); its lines say the rest.
    if (_draft.isSplit) {
      final all = _splitCategories;
      return all.where((c) => !c.isIncome).firstOrNull ?? all.firstOrNull;
    }
    if (_draft.categoryId == phoneIncomeId) return _income;
    if (_to case final to?) return _transferTo(to);
    for (final c in _store.categories) {
      if (c.id == _draft.categoryId) return c;
    }
    return null;
  }

  /// The app's one Income, for money in that isn't a refund. It has no
  /// currency of its own: its rows are in the currency of the account the
  /// money came into.
  PhoneCategory get _income {
    final accounts = _store.snapshot.accounts;
    final into =
        accounts.where((a) => a.id == _draft.accountId).firstOrNull ??
        accounts.firstOrNull;
    return PhoneCategory(
      id: phoneIncomeId,
      name: context.t.ledgerIncome,
      leftMinor: 0,
      currency: into?.currency ?? Currency.mnt,
    );
  }

  List<PhoneAccount> get _accounts {
    final category = _category;
    // Moved from any other account in the same currency.
    if (_to case final to?) return _store.snapshot.transferTargets(to);
    return category == null || category.isIncome
        ? _store.snapshot.accounts
        : _store.snapshot.accountsFor(category);
  }

  /// The account the person chose, while it fits the category's currency.
  /// Never filled in for them (owner, 2026-10-08: "Don't autofill. I don't
  /// want to set people up for bad data entry in the name of convenience"):
  /// a guessed card is saved by mistake, as a guessed payee was. Only when
  /// there is one account it could be is there nothing to choose.
  PhoneAccount? get _account {
    final accounts = _accounts;
    for (final a in accounts) {
      if (a.id == _draft.accountId) return a;
    }
    return accounts.length == 1 ? accounts.single : null;
  }

  /// The account the entry is paid from as the screen shows it: the one
  /// picked, whatever the category, or the only one there could be.
  PhoneAccount? get _from {
    for (final a in _store.snapshot.accounts) {
      if (a.id == _draft.accountId) return a;
    }
    return _account;
  }

  /// The currency the amount is typed in: the category's, else the chosen
  /// account's, else the ledger's first account's.
  Currency get _currency =>
      _category?.currency ??
      _account?.currency ??
      _store.snapshot.accounts.firstOrNull?.currency ??
      Currency.mnt;

  /// What was just saved ("Saved · Nomin −₮12,500.00") and how to take it
  /// back: the toast, up until its time runs out or the next key or choice.
  String? _saved;
  Timer? _toastTimer;
  VoidCallback? _undo;

  /// The card's second line: what the entry left in its category
  /// ("Groceries · ₮135,500.00 left"), red once that is overspent.
  String? _savedLeft;
  var _savedOver = false;

  /// Save's own changes to the draft and the store, which don't take the
  /// line it is about to say away.
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _draft.addListener(_said);
    _store.addListener(_said);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _draft.removeListener(_said);
    _store.removeListener(_said);
    super.dispose();
  }

  /// Any change to the entry or to what is waiting, from this screen or
  /// from Budget, ends what was said: an Undo left up would write over the
  /// entry begun since.
  void _said() {
    if (_saving || (_missing == null && _saved == null)) return;
    setState(() {
      _missing = null;
      _saved = null;
      _undo = null;
    });
  }

  void _change(VoidCallback make) => _draft.change(make);

  void _press(String key) => _change(
    () => _draft.typed = pressAmountKey(_draft.typed, key, _currency),
  );

  void _save() {
    final t = context.t;
    final category = _category;
    final account = _account;
    final payee = _draft.payee;
    final amount = typedAmountMinor(_draft.typed, _currency);
    final to = _to;
    if (_draft.isSplit) return _saveSplit(amount);
    final missing = amount == 0
        ? t.phoneEnterAmount
        // Money moved between their own accounts has no one it was paid to.
        : payee == null && to == null
        ? t.phoneEnterPayee
        : category == null
        ? t.phoneChooseCategory
        : account == null
        ? t.phoneChooseAccount
        : null;
    if (missing != null) {
      setState(() {
        _missing = missing;
        _saved = null;
        _undo = null;
      });
      return;
    }
    final random = Random.secure();
    final typed = _draft.typed;
    final date = _draft.date;
    final moneyIn = _draft.moneyIn && to == null;
    final signed = moneyIn ? amount : -amount;
    final entry = PhoneEntry(
      id: [
        for (var i = 0; i < 16; i++)
          random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ].join(),
      categoryId: category!.id,
      accountId: account!.id,
      payee: to == null ? payee! : '',
      amountMinor: signed,
      date: date ?? _day(widget.now()),
      madeAt: widget.now(),
    );
    _saving = true;
    _store.add(entry);
    _draft.clear();
    _saving = false;
    // The form is empty again, so this line is what says it went in.
    // What the entry did to its category, the reason the phone is opened.
    final left = to == null ? leftNow(category, _store.waiting) : 0;
    final had = formatMoney(left.abs(), currency: category.currency);
    setState(() {
      if (to != null) {
        // A transfer changes no category: what the account it reached
        // holds now is what there is to say.
        final now = formatMoney(
          balanceNow(to, _store.waiting),
          currency: to.currency,
        );
        _saved = t.phoneSavedTransfer(
          account.name,
          to.name,
          formatMoney(amount, currency: to.currency),
        );
        _savedLeft = to.owes
            ? t.phoneTransferOwedNow(to.name, now)
            : t.phoneTransferNow(to.name, now);
        _savedOver = false;
      } else {
        _saved = t.phoneSaved(payee!, _signed(signed, category.currency));
        // Income holds no budget: there is nothing left in it to say.
        _savedLeft = category.isIncome
            ? null
            : category.madeHere
            ? t.phoneSavedNothingAssigned(category.name)
            : left < 0
            ? t.phoneSavedOver(category.name, had)
            : t.phoneSavedLeft(category.name, had);
        _savedOver = left < 0 && !category.madeHere && !category.isIncome;
      }
      _undo = () {
        _store.remove(entry.id);
        _change(() {
          _draft
            ..typed = typed
            ..moneyIn = moneyIn
            ..payee = payee
            ..categoryId = category.id
            ..accountId = account.id
            ..date = date;
        });
      };
    });
    // Like any toast it goes by itself.
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) _hideToast();
    });
  }

  /// Save for one receipt over several categories: waits until its lines
  /// add up to the amount (owner, 2026-10-17), as Add does on the computer.
  void _saveSplit(int amount) {
    final t = context.t;
    final account = _account;
    final payee = _draft.payee;
    final currency = _currency;
    final shares = [
      for (final l in _draft.lines) typedAmountMinor(l.typed, currency),
    ];
    final sum = shares.fold(0, (s, v) => s + v);
    String money(int v) => formatMoney(v.abs(), currency: currency);
    // A line whose category has gone (deleted from the waiting list, or
    // from the computer's ledger) or is in another currency would never
    // be taken in: chosen again first.
    final categories = _splitCategories;
    final lost =
        categories.length != _draft.lines.length ||
        categories.any(
          (c) =>
              !c.isIncome && account != null && c.currency != account.currency,
        );
    final missing = amount == 0
        ? t.phoneEnterAmount
        : payee == null
        ? t.phoneEnterPayee
        : account == null
        ? t.phoneChooseAccount
        : lost
        ? t.phoneChooseCategory
        : sum < amount
        ? t.rowsErrorSplitLeft(money(amount - sum))
        : sum > amount
        ? t.rowsErrorSplitTooMuch(money(sum - amount))
        : null;
    if (missing != null) {
      setState(() {
        _missing = missing;
        _saved = null;
        _undo = null;
      });
      // Not adding up, or a line to choose again: the split page opens on
      // it, as the computer's card does.
      if (amount != 0 && payee != null && account != null) _openSplit();
      return;
    }
    final random = Random.secure();
    final typed = _draft.typed;
    final date = _draft.date;
    final moneyIn = _draft.moneyIn;
    final lines = _draft.lines;
    final entry = PhoneEntry(
      id: [
        for (var i = 0; i < 16; i++)
          random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ].join(),
      categoryId: phoneSplitId,
      accountId: account!.id,
      payee: payee!,
      amountMinor: moneyIn ? amount : -amount,
      date: date ?? _day(widget.now()),
      madeAt: widget.now(),
      lines: [
        for (final (i, l) in lines.indexed)
          (
            categoryId: l.categoryId,
            amountMinor: moneyIn ? shares[i] : -shares[i],
          ),
      ],
    );
    _saving = true;
    _store.add(entry);
    _draft.clear();
    _saving = false;
    // What it did to each of its categories, one line each.
    var over = false;
    final said = <String>[];
    for (final c in categories) {
      if (c.isIncome) continue;
      final left = leftNow(c, _store.waiting);
      final had = formatMoney(left.abs(), currency: c.currency);
      said.add(
        c.madeHere
            ? t.phoneSavedNothingAssigned(c.name)
            : left < 0
            ? t.phoneSavedOver(c.name, had)
            : t.phoneSavedLeft(c.name, had),
      );
      over = over || (left < 0 && !c.madeHere);
    }
    setState(() {
      _saved = t.phoneSaved(payee, _signed(entry.amountMinor, currency));
      _savedLeft = said.isEmpty ? null : said.join('\n');
      _savedOver = over;
      _undo = () {
        _store.remove(entry.id);
        _change(() {
          _draft
            ..typed = typed
            ..moneyIn = moneyIn
            ..payee = payee
            ..categoryId = phoneSplitId
            ..lines = lines
            ..accountId = account.id
            ..date = date;
        });
      };
    });
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) _hideToast();
    });
  }

  /// The split page: on the lines there are, or on the category chosen.
  Future<void> _openSplit() async {
    final currency = _currency;
    final start = _draft.isSplit
        ? _draft.lines
        : [
            if (_category case final c? when !c.transfer)
              (categoryId: c.id, typed: ''),
          ];
    final total = typedAmountMinor(_draft.typed, currency);
    final result = await Navigator.of(context).push(
      MaterialPageRoute<List<({String categoryId, String typed})>>(
        fullscreenDialog: true,
        builder: (_) => _SplitPage(
          store: _store,
          currency: currency,
          moneyIn: _draft.moneyIn,
          payee: _draft.payee,
          total: total == 0 ? null : total,
          start: start,
          income: _draft.moneyIn ? _income : null,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final sum = result.fold(
      0,
      (s, l) => s + typedAmountMinor(l.typed, currency),
    );
    if (result.isEmpty) {
      _change(() {
        _draft.lines = [];
        if (_draft.categoryId == phoneSplitId) _draft.categoryId = null;
      });
    } else if (result.length == 1 &&
        (total == 0 ||
            typedAmountMinor(result.single.typed, currency) == total)) {
      // One category with the whole amount: an ordinary entry.
      final only = _categoryOf(result.single.categoryId);
      if (only != null) _draft.choose(only, _store.snapshot.accounts);
      if (total == 0) _change(() => _draft.typed = result.single.typed);
    } else {
      _change(() {
        _draft.lines = result;
        _draft.categoryId = phoneSplitId;
        // With no amount typed, the lines' sum is the amount.
        if (total == 0) _draft.typed = typedOfMinor(sum, currency);
        final accounts = _accounts;
        if (!accounts.any((a) => a.id == _draft.accountId)) {
          _draft.accountId = null;
        }
      });
    }
  }

  void _hideToast() {
    _toastTimer?.cancel();
    if (_saved == null) return;
    setState(() {
      _saved = null;
      _undo = null;
    });
  }

  /// Money out can instead be moved to another of their accounts: any but
  /// the one already chosen to pay from. Each has to have an account its
  /// money could come from; the one already paying, chosen or the only one
  /// there is, is not where its own money goes. None for money in.
  List<PhoneAccount> get _transferChoices => _draft.moneyIn
      ? const []
      : [
          for (final a in _store.snapshot.accounts)
            if (_store.snapshot.transferTargets(a).isNotEmpty &&
                a.id != _from?.id &&
                (_from == null || a.currency == _from!.currency))
              a,
        ];

  Future<void> _picked(PhoneCategory picked) async {
    if (picked.id == phoneSplitId) {
      await _openSplit();
    } else {
      _draft.choose(picked, _store.snapshot.accounts);
    }
  }

  Future<void> _typePayee() async {
    final snapshot = _store.snapshot;
    final category = _category;
    final typed = await showDialog<String>(
      context: context,
      builder: (context) => _PayeeDialog(
        start: _draft.payee ?? '',
        matching: (typed) => snapshot.payeesMatching(typed, category),
      ),
    );
    if (typed != null && typed.trim().isNotEmpty && mounted) {
      _change(() => _draft.payee = typed.trim());
    }
  }

  Future<void> _pickAccount() async {
    final accounts = _accounts;
    final chosen = _account;
    final picked = await showModalBottomSheet<PhoneAccount>(
      context: context,
      backgroundColor: Mid.panel,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final a in accounts)
              ListTile(
                title: Text(a.name, style: onest(16, weight: 500)),
                trailing: a.id == chosen?.id
                    ? Icon(Icons.check, color: Mid.blue)
                    : null,
                onTap: () => Navigator.of(context).pop(a),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      // With no category, or Income, the amount is in the account's currency.
      _change(() {
        _draft.accountId = picked.id;
        _draft.fit(_currency);
      });
    }
  }

  Future<void> _pickDate() async {
    final today = _day(widget.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.date ?? today,
      firstDate: DateTime(today.year - 1, today.month, today.day),
      // The phone records what was bought; what is still to come is the
      // computer's (a bill's due date, a scheduled row).
      lastDate: today,
    );
    if (picked != null && mounted) {
      _change(() => _draft.date = picked == today ? null : picked);
    }
  }

  /// What the category holds now and [after] this entry: less for money
  /// out, more for a refund. An overspent amount is said in words: a minus
  /// beside "left" reads as a sum to do.
  String _leftLine(Words t, PhoneCategory category, int left, int after) {
    // Made a moment ago on this phone: "overspent" would blame them for it.
    if (category.madeHere) return t.phoneNothingAssigned;
    String say(int minor) => formatMoney(minor.abs(), currency: _currency);
    if (after == left) {
      return left < 0 ? t.phoneOverNow(say(left)) : t.phoneLeftNow(say(left));
    }
    if (left < 0) {
      return after < 0
          ? t.phoneOverBoth(say(left), say(after))
          : t.phoneOverThenLeft(say(left), say(after));
    }
    return after < 0
        ? t.phoneOverAfter(say(left), say(after))
        : t.phoneLeftAfter(say(left), say(after));
  }

  String _waitingLine(Words t) {
    final entries = _store.waiting.length;
    final categories = _store.made.length;
    if (categories == 0) return t.phoneWaiting(entries);
    if (entries == 0) return t.phoneWaitingCategories(categories);
    return t.phoneWaitingBoth(entries, categories);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_store, _draft]),
    builder: (context, _) {
      final t = context.t;
      final category = _category;
      final split = _draft.isSplit;
      final to = _to;
      final from = to == null ? null : _account;
      final left = category == null || to != null || split
          ? 0
          : leftNow(category, _store.waiting);
      final amount = typedAmountMinor(_draft.typed, _currency);
      final moneyIn = _draft.moneyIn && to == null;
      // Moved out of [from]: what it holds once this has gone, or owes.
      final fromAfter = from == null
          ? 0
          : balanceNow(from, _store.waiting) + (from.owes ? amount : -amount);
      final after = moneyIn ? left + amount : left - amount;
      final date = _draft.date;
      final over = to != null
          ? from != null && !from.owes && fromAfter < 0
          : category != null && !category.madeHere && after < 0;
      // A category that has gone (deleted from the waiting list) isn't
      // something left to clear.
      final nothing =
          _draft.typed.isEmpty &&
          !moneyIn &&
          _draft.payee == null &&
          category == null &&
          _draft.accountId == null &&
          _draft.date == null;
      // On a tall phone the pad and Save sit at the foot; on a short one
      // the whole entry scrolls instead of running off the screen.
      return Stack(
        children: [
          LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Offered only while there is something to clear.
                        SizedBox(
                          height: 44,
                          child: nothing
                              ? null
                              : Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => _change(_draft.clear),
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(44, 44),
                                      foregroundColor: Mid.blue,
                                      textStyle: onest(16),
                                    ),
                                    child: Text(t.phoneClear),
                                  ),
                                ),
                        ),
                        Row(
                          children: [
                            // Money moved is neither out nor in: no sign to
                            // turn while an account is the "category".
                            if (to == null)
                              _SignButton(
                                moneyIn: moneyIn,
                                onTap: _draft.flipSign,
                              )
                            else
                              const SizedBox(width: _SignButton.size),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${to != null
                                      ? ''
                                      : moneyIn
                                      ? '+'
                                      : '−'}${typedAmountShown(_draft.typed, _currency)}',
                                  maxLines: 1,
                                  style: onest(
                                    52,
                                    weight: 600,
                                    letterSpacing: -1,
                                    color: _draft.typed.isEmpty
                                        ? Mid.ink3
                                        : to != null
                                        ? Mid.ink
                                        : moneyIn
                                        ? Mid.green
                                        : Mid.coral,
                                  ),
                                ),
                              ),
                            ),
                            // As wide as the button, so the amount stays in
                            // the middle of the screen.
                            const SizedBox(width: _SignButton.size),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Its place is kept while no category is chosen, so the rows
                        // under it don't move when one is.
                        SizedBox(
                          height: 22,
                          child: split
                              // Each category's share, as the register
                              // shows a split.
                              ? Text(
                                  [
                                    for (final (i, l) in _draft.lines.indexed)
                                      '${_splitCategories.elementAtOrNull(i)?.name ?? ''} ${typedAmountShown(l.typed, _currency)}',
                                  ].join(' · '),
                                  key: const ValueKey('split-line'),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: onest(15, color: Mid.ink2),
                                )
                              : category == null ||
                                    category.isIncome ||
                                    (to != null && from == null)
                              ? null
                              : Text(
                                  from != null
                                      ? (from.owes
                                            ? t.phoneTransferOwedAfter(
                                                from.name,
                                                formatMoney(
                                                  fromAfter,
                                                  currency: from.currency,
                                                ),
                                              )
                                            : t.phoneTransferAfter(
                                                from.name,
                                                formatMoney(
                                                  fromAfter,
                                                  currency: from.currency,
                                                ),
                                              ))
                                      : _leftLine(t, category, left, after),
                                  key: const ValueKey('left-line'),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: onest(
                                    15,
                                    color: over ? Mid.coral : Mid.ink2,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 12),
                        Material(
                          color: Mid.card,
                          borderRadius: BorderRadius.circular(14),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              // Between their own accounts nobody was paid.
                              if (to == null) ...[
                                _FieldRow(
                                  key: const ValueKey('payee-row'),
                                  label: t.rowsColumnPayee,
                                  value: _draft.payee ?? '',
                                  onTap: _typePayee,
                                ),
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Mid.rule,
                                ),
                              ],
                              _CategoryMenu(
                                store: _store,
                                // A category made here is in the currency
                                // being paid in.
                                currency: _currency,
                                split: true,
                                // Money in that isn't a refund is income;
                                // money out never is.
                                income: _draft.moneyIn ? _income : null,
                                transfers: _transferChoices,
                                onPicked: _picked,
                                builder: (context, open) => _FieldRow(
                                  key: const ValueKey('category-row'),
                                  label: t.rowsColumnCategory,
                                  value: split
                                      ? t.startSplitCategories(
                                          _draft.lines.length,
                                        )
                                      : category?.name ?? '',
                                  // A split opens on its lines.
                                  onTap: split ? _openSplit : open,
                                ),
                              ),
                              Divider(height: 1, thickness: 1, color: Mid.rule),
                              _FieldRow(
                                key: const ValueKey('account-row'),
                                label: to != null
                                    ? t.phoneFrom
                                    : moneyIn
                                    ? t.setupPaidInto
                                    : t.planLabelPaidFrom,
                                value: _account?.name ?? '',
                                onTap: _pickAccount,
                              ),
                              Divider(height: 1, thickness: 1, color: Mid.rule),
                              _FieldRow(
                                label: t.rowsColumnDate,
                                value: date == null ? t.today : fullDate(date),
                                onTap: _pickDate,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Spacer(),
                        _AmountPad(currency: _currency, onKey: _press),
                        const SizedBox(height: 10),
                        if (_missing != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              _missing!,
                              textAlign: TextAlign.center,
                              style: onest(15, color: Mid.gold),
                            ),
                          ),
                        FilledButton(
                          onPressed: _save,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: Mid.fill,
                            foregroundColor: Mid.onFill,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: onest(17, weight: 600),
                          ),
                          child: Text(t.rowsSave),
                        ),
                        // Offered only while there is something waiting.
                        if (_store.waiting.isNotEmpty || _store.made.isNotEmpty)
                          TextButton(
                            key: const ValueKey('waiting-link'),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => _WaitingScreen(store: _store),
                              ),
                            ),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              foregroundColor: Mid.ink2,
                              textStyle: onest(
                                14,
                              ).copyWith(decoration: TextDecoration.underline),
                            ),
                            child: Text(
                              _waitingLine(t),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // A toast (owner, 2026-10-08: "appeared and disappeared like a
          // regular toast notification"): what went in and what it did to
          // its category. At the top, where the emptied form has nothing; a
          // toast at the foot covered Save and the way to Budget.
          Positioned(
            top: 8,
            left: 20,
            right: 20,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, -0.4),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: _saved == null
                  ? const SizedBox.shrink()
                  : _SavedToast(
                      saved: _saved!,
                      left: _savedLeft,
                      over: _savedOver,
                      onUndo: _undo,
                    ),
            ),
          ),
        ],
      );
    },
  );
}

/// Turns the entry from money out to money in and back (owner, 2026-10-08:
/// returning things to a shop is a positive entry). Beside the amount, whose
/// sign and color say which it is.
class _SignButton extends StatelessWidget {
  const _SignButton({required this.moneyIn, required this.onTap});
  final bool moneyIn;
  final VoidCallback onTap;

  static const double size = 44;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      color: Mid.panel,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('sign'),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Text(
              '+/−',
              // Read out as what a tap will do, not as two signs.
              semanticsLabel: moneyIn
                  ? context.t.phoneToMoneyOut
                  : context.t.phoneToMoneyIn,
              style: onest(17, weight: 600),
            ),
          ),
        ),
      ),
    ),
  );
}

/// What Save just put in, "Saved · Nomin −₮12,500.00", and what that left in
/// its category, with Undo.
class _SavedToast extends StatelessWidget {
  const _SavedToast({
    required this.saved,
    required this.left,
    required this.over,
    required this.onUndo,
  });
  final String saved;

  /// Null for income, which has nothing left in it to say.
  final String? left;

  /// The category is overspent now: its line is red.
  final bool over;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('saved-toast'),
    color: Mid.raised,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: Mid.rule),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  saved,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: onest(15, weight: 500),
                ),
                if (left != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    left!,
                    // A split says each of its categories on its own line.
                    maxLines: '\n'.allMatches(left!).length + 1,
                    overflow: TextOverflow.ellipsis,
                    style: onest(14, color: over ? Mid.coral : Mid.ink2),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: onUndo,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              foregroundColor: Mid.blue,
              textStyle: onest(15),
            ),
            child: Text(context.t.ledgerUndo),
          ),
        ],
      ),
    ),
  );
}

/// The categories, chosen from a dropdown on the screen they're for
/// (owner, 2026-10-17: "I don't like how you have to switch to the budgets
/// page to pick stuff. Let's have users just choose from a dropdown on the
/// same screen with Split (and a split icon next to it) at the top"). Split
/// first, while [split] offers it; Income for money in; the categories with
/// what's left in each, those waiting for a bill under Bills; the accounts
/// money can be moved to; "+ New category" last.
class _CategoryMenu extends StatefulWidget {
  const _CategoryMenu({
    required this.store,
    required this.currency,
    required this.onPicked,
    required this.builder,
    this.income,
    this.transfers = const [],
    this.split = false,
    this.exclude = const {},
    this.onlyCurrency = false,
    this.controller,
  });
  final PhoneStore store;

  /// A category made here is in this currency; with [onlyCurrency], the
  /// only one offered (Income has none of its own).
  final Currency currency;
  final bool onlyCurrency;
  final PhoneCategory? income;
  final List<PhoneAccount> transfers;

  /// Split is offered first: picking it answers with [phoneSplitId].
  final bool split;

  /// Categories not offered: the ones a split's other lines have.
  final Set<String> exclude;
  final ValueChanged<PhoneCategory> onPicked;

  /// What opens it: given the way to open it.
  final Widget Function(BuildContext context, VoidCallback open) builder;

  /// To open it from outside (a split page with no lines yet).
  final MenuController? controller;

  @override
  State<_CategoryMenu> createState() => _CategoryMenuState();
}

class _CategoryMenuState extends State<_CategoryMenu> {
  late final _controller = widget.controller ?? MenuController();

  static PhoneCategory _toAccount(Words t, PhoneAccount to) => PhoneCategory(
    id: to.id,
    name: t.phoneTransferTo(to.name),
    leftMinor: 0,
    currency: to.currency,
    transfer: true,
  );

  Future<void> _newCategory() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NewCategoryDialog(store: widget.store),
    );
    if (name == null || !mounted) return;
    widget.onPicked(widget.store.categoryCalled(name, widget.currency));
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(text, style: onest(13, weight: 600, color: Mid.ink2)),
  );

  /// The dropdown's width: what opens it, the screen less its 20-point
  /// sides. A menu is as wide as its widest item, so each item is this
  /// wide (a LayoutBuilder can't sit in the entry screen, which is measured
  /// by its height).
  double get _width => MediaQuery.sizeOf(context).width - 40;

  Widget _item({
    Key? key,
    Widget? leading,
    required String name,
    String? under,
    Widget? trailing,
    required VoidCallback onPressed,
  }) => MenuItemButton(
    key: key,
    onPressed: onPressed,
    style: MenuItemButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      padding: const EdgeInsets.symmetric(horizontal: 16),
    ),
    child: SizedBox(
      width: _width - 32,
      child: Row(
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: onest(16, weight: 500),
                ),
                if (under != null)
                  Text(under, style: onest(12, color: Mid.ink2)),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing],
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final store = widget.store;
    final categories = [
      for (final c in store.categories)
        if (!widget.exclude.contains(c.id) &&
            (!widget.onlyCurrency || c.currency == widget.currency))
          c,
    ];
    final income = widget.exclude.contains(phoneIncomeId)
        ? null
        : widget.income;
    final spend = [
      for (final c in categories)
        if (c.due == null) c,
    ];
    final bills = [
      for (final c in categories)
        if (c.due != null) c,
    ];
    Widget category(PhoneCategory c) => _item(
      key: ValueKey('menu-${c.id}'),
      name: c.name,
      under: c.due != null
          ? t.phoneDue(shortDate(c.due!))
          : c.madeHere
          ? t.phoneNothingAssigned
          : null,
      trailing: c.isIncome
          ? null
          : _RoomMoney(
              leftNow(c, store.waiting),
              c.currency,
              room: 160,
              spokenFor: c.due != null,
            ),
      onPressed: () => widget.onPicked(c),
    );
    // No taller than most of a phone.
    final width = _width;
    return MenuAnchor(
      controller: _controller,
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Mid.raised),
        minimumSize: WidgetStatePropertyAll(Size(width, 0)),
        maximumSize: WidgetStatePropertyAll(Size(width, 440)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      menuChildren: [
        if (widget.split)
          _item(
            key: const ValueKey('split-option'),
            leading: Icon(Icons.call_split_rounded, color: Mid.blue),
            name: t.phoneSplitTitle,
            onPressed: () => widget.onPicked(
              const PhoneCategory(id: phoneSplitId, name: '', leftMinor: 0),
            ),
          ),
        if (widget.split) Divider(height: 1, thickness: 1, color: Mid.rule),
        if (income != null) category(income),
        for (final c in spend) category(c),
        if (bills.isNotEmpty) ...[
          _heading(t.phoneBills),
          for (final c in bills) category(c),
        ],
        if (widget.transfers.isNotEmpty) ...[
          _heading(t.phoneMoveToAccount),
          for (final a in widget.transfers)
            _item(
              key: ValueKey('menu-account-${a.id}'),
              name: t.phoneTransferTo(a.name),
              trailing: Text(
                a.owes
                    ? t.phoneOwed(
                        formatMoney(
                          balanceNow(a, store.waiting),
                          currency: a.currency,
                        ),
                      )
                    : formatMoney(
                        balanceNow(a, store.waiting),
                        currency: a.currency,
                      ),
                style: onest(14, color: Mid.ink2, tabular: true),
              ),
              onPressed: () => widget.onPicked(_toAccount(t, a)),
            ),
        ],
        Divider(height: 1, thickness: 1, color: Mid.rule),
        _item(
          key: const ValueKey('new-category'),
          name: t.phoneNewCategory,
          onPressed: _newCategory,
        ),
      ],
      builder: (context, controller, _) => widget.builder(
        context,
        () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// One receipt over several categories (owner's pick, 2026-10-17, option
/// A): the total and what's left to place, a line for each category, and
/// the pad, which types into the line that's chosen. Done answers with the
/// lines that have an amount; Cancel with null.
class _SplitPage extends StatefulWidget {
  const _SplitPage({
    required this.store,
    required this.currency,
    required this.moneyIn,
    required this.payee,
    required this.total,
    required this.start,
    this.income,
  });
  final PhoneStore store;
  final Currency currency;
  final bool moneyIn;
  final String? payee;

  /// What was typed on the entry screen; null when nothing was.
  final int? total;
  final List<({String categoryId, String typed})> start;

  /// The app's Income, a line's category only for money in.
  final PhoneCategory? income;

  @override
  State<_SplitPage> createState() => _SplitPageState();
}

class _SplitPageState extends State<_SplitPage> {
  late final List<({String categoryId, String typed})> _lines = [
    ...widget.start,
  ];

  /// The line the pad types into.
  late int _chosen = _lines.indexWhere((l) => l.typed.isEmpty) < 0
      ? 0
      : _lines.indexWhere((l) => l.typed.isEmpty);

  @override
  void initState() {
    super.initState();
    // Nothing to split yet: straight to the first category.
    if (_lines.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _another.open();
      });
    }
  }

  PhoneCategory? _categoryOf(String id) {
    if (id == phoneIncomeId) return widget.income;
    for (final c in widget.store.categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  int get _sum =>
      _lines.fold(0, (s, l) => s + typedAmountMinor(l.typed, widget.currency));

  /// "+ Another category"'s dropdown, opened at once when there are no
  /// lines yet.
  final _another = MenuController();

  /// The dropdown for line [index], or for a new line when null. The other
  /// lines' categories aren't offered: a split names each once. Nor are
  /// other currencies': a dollar Groceries isn't on a tugrik receipt.
  Widget _menu(
    int? index,
    Widget Function(BuildContext context, VoidCallback open) builder,
  ) => _CategoryMenu(
    store: widget.store,
    currency: widget.currency,
    income: widget.income,
    onlyCurrency: true,
    controller: index == null ? _another : null,
    exclude: {
      for (final (i, l) in _lines.indexed)
        if (i != index) l.categoryId,
    },
    onPicked: (picked) => _picked(index, picked),
    builder: builder,
  );

  void _picked(int? index, PhoneCategory picked) {
    setState(() {
      if (index == null) {
        _lines.add((categoryId: picked.id, typed: ''));
        _chosen = _lines.length - 1;
      } else {
        _lines[index] = (categoryId: picked.id, typed: _lines[index].typed);
        _chosen = index;
      }
    });
  }

  void _press(String key) {
    if (_chosen >= _lines.length) return;
    setState(() {
      final l = _lines[_chosen];
      _lines[_chosen] = (
        categoryId: l.categoryId,
        typed: pressAmountKey(l.typed, key, widget.currency),
      );
    });
  }

  void _remove(int index) => setState(() {
    _lines.removeAt(index);
    // The pad stays on the line it was typing into.
    if (index < _chosen) _chosen--;
    if (_chosen >= _lines.length) _chosen = _lines.length - 1;
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final currency = widget.currency;
    // As the lines and the total read: ₮37,500.
    String money(int v) => formatShort(v.abs(), currency: currency);
    final total = widget.total;
    final sum = _sum;
    final left = total == null ? null : total - sum;
    final note = switch (left) {
      null when sum != 0 => t.rowsSplitInAll(money(sum)),
      null || 0 => null,
      // Not "left": on the phone that is what a budget has.
      > 0 => t.phoneSplitToPlace(money(left)),
      _ => t.rowsSplitTooMuch(money(left)),
    };
    final shown = total ?? sum;
    return Scaffold(
      backgroundColor: Mid.ground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.phoneSplitTitle,
                      style: onest(20, weight: 600),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('split-cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      foregroundColor: Mid.blue,
                      textStyle: onest(16),
                    ),
                    child: Text(t.ledgerCancel),
                  ),
                ],
              ),
              if (widget.payee case final payee?)
                Text(payee, style: onest(15, color: Mid.ink2)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      '${widget.moneyIn ? '+' : '−'}${formatShort(shown, currency: currency)}',
                      style: onest(
                        30,
                        weight: 600,
                        color: shown == 0
                            ? Mid.ink3
                            : widget.moneyIn
                            ? Mid.green
                            : Mid.coral,
                      ),
                    ),
                  ),
                  if (note != null)
                    Text(
                      note,
                      key: const ValueKey('split-left'),
                      style: onest(15, tabular: true),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  children: [
                    if (_lines.isNotEmpty)
                      Material(
                        color: Mid.card,
                        borderRadius: BorderRadius.circular(14),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (final (i, l) in _lines.indexed) ...[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Mid.rule,
                                ),
                              _menu(
                                i,
                                (context, open) => _SplitLineRow(
                                  key: ValueKey('split-line-$i'),
                                  name: _categoryOf(l.categoryId)?.name ?? '',
                                  amount: l.typed.isEmpty
                                      ? ''
                                      : typedAmountShown(l.typed, currency),
                                  chosen: i == _chosen,
                                  // Chosen, a tap changes its category.
                                  onTap: () => i == _chosen
                                      ? open()
                                      : setState(() => _chosen = i),
                                  // Offered while there's another line to
                                  // keep.
                                  onRemove: _lines.length < 2
                                      ? null
                                      : () => _remove(i),
                                  removeLabel: t.rowsSplitRemove,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    _menu(
                      null,
                      (context, open) => Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: const ValueKey('split-another'),
                          onPressed: open,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 48),
                            foregroundColor: Mid.blue,
                            textStyle: onest(15, weight: 500),
                          ),
                          child: Text(t.rowsSplitAnother),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _AmountPad(currency: currency, onKey: _press),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('split-done'),
                onPressed: () => Navigator.of(context).pop([
                  for (final l in _lines)
                    if (typedAmountMinor(l.typed, currency) != 0) l,
                ]),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: Mid.fill,
                  foregroundColor: Mid.onFill,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: onest(17, weight: 600),
                ),
                child: Text(t.rowsSplitDone),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One line of the split page: its category and amount. Tapped, it is the
/// line the pad types into; tapped again, its category can be changed.
class _SplitLineRow extends StatelessWidget {
  const _SplitLineRow({
    super.key,
    required this.name,
    required this.amount,
    required this.chosen,
    required this.onTap,
    required this.onRemove,
    required this.removeLabel,
  });
  final String name;
  final String amount;
  final bool chosen;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final String removeLabel;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: EdgeInsets.only(left: 16, right: onRemove == null ? 16 : 0),
      decoration: BoxDecoration(
        color: chosen ? Mid.raised : null,
        border: chosen ? Border.all(color: Mid.blue, width: 2) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: onest(16, weight: 500),
            ),
          ),
          Text(
            amount.isEmpty && chosen ? '|' : amount,
            style: onest(
              16,
              weight: 500,
              tabular: true,
              color: amount.isEmpty ? Mid.blue : Mid.ink,
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              tooltip: removeLabel,
              icon: Icon(Icons.close_rounded, size: 18, color: Mid.ink3),
            ),
        ],
      ),
    ),
  );
}

/// Budget's "+ New category": its name, on the phone's keyboard.
class _NewCategoryDialog extends StatefulWidget {
  const _NewCategoryDialog({required this.store});
  final PhoneStore store;

  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final _text = TextEditingController();

  /// The name that is already a category, said under the box.
  String? _taken;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _add() {
    final name = _text.text.trim();
    if (name.isEmpty) return;
    final already = categoryNamed(widget.store.categories, name);
    // Income is the app's own category, whichever language names it.
    if (already != null || isIncomeName(name)) {
      setState(() => _taken = already?.name ?? context.t.ledgerIncome);
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return AlertDialog(
      backgroundColor: Mid.panel,
      title: Text(t.phoneNewCategoryTitle, style: onest(18, weight: 600)),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: 320,
        child: TextField(
          key: const ValueKey('new-category-name'),
          controller: _text,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: onest(17),
          cursorColor: Mid.blue,
          decoration: InputDecoration(
            hintText: t.planCategoryName,
            hintStyle: onest(17, color: Mid.ink3),
            errorText: _taken == null ? null : t.ledgerAlreadyCategory(_taken!),
            errorStyle: onest(14, color: Mid.gold),
          ),
          onChanged: (_) {
            if (_taken != null) setState(() => _taken = null);
          },
          onSubmitted: (_) => _add(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.ledgerCancel, style: onest(15, color: Mid.blue)),
        ),
        TextButton(
          onPressed: _add,
          child: Text(
            t.planAdd,
            style: onest(15, weight: 600, color: Mid.blue),
          ),
        ),
      ],
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text(label, style: onest(15, color: Mid.ink2)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: onest(16, weight: 500),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Digits, a point for a currency with cents, and delete.
class _AmountPad extends StatelessWidget {
  const _AmountPad({required this.currency, required this.onKey});
  final Currency currency;
  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    final keys = [
      '1', '2', '3', '4', '5', '6', '7', '8', '9', //
      currency.decimals == 0 ? '' : '.', '0', '<',
    ];
    return Column(
      children: [
        for (var row = 0; row < 4; row++)
          Padding(
            padding: EdgeInsets.only(top: row == 0 ? 0 : 8),
            child: Row(
              children: [
                for (var col = 0; col < 3; col++) ...[
                  if (col > 0) const SizedBox(width: 8),
                  Expanded(child: _key(context, keys[row * 3 + col])),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _key(BuildContext context, String key) {
    if (key.isEmpty) return const SizedBox(height: 52);
    return Material(
      color: Mid.panel,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('pad-$key'),
        onTap: () => onKey(key),
        child: SizedBox(
          height: 52,
          child: Center(
            child: key == '<'
                ? Icon(
                    Icons.backspace_outlined,
                    size: 24,
                    color: Mid.ink,
                    semanticLabel: context.t.phoneDeleteDigit,
                  )
                : Text(key, style: onest(22)),
          ),
        ),
      ),
    );
  }
}

/// The payee, typed on the phone's own keyboard. As it is typed, payees
/// from the ledger's history that fit are offered under it; a tap takes one.
class _PayeeDialog extends StatefulWidget {
  const _PayeeDialog({required this.start, required this.matching});
  final String start;
  final List<String> Function(String typed) matching;

  @override
  State<_PayeeDialog> createState() => _PayeeDialogState();
}

class _PayeeDialogState extends State<_PayeeDialog> {
  late final _text = TextEditingController(text: widget.start);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final offered = widget.matching(_text.text);
    return AlertDialog(
      backgroundColor: Mid.panel,
      title: Text(t.rowsColumnPayee, style: onest(18, weight: 600)),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('payee-field'),
              controller: _text,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: onest(17),
              cursorColor: Mid.blue,
              onChanged: (_) => setState(() {}),
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
            for (final p in offered)
              InkWell(
                onTap: () => Navigator.of(context).pop(p),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      p,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: onest(16, color: Mid.ink),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.ledgerCancel, style: onest(15, color: Mid.blue)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_text.text),
          child: Text(
            t.rowsSave,
            style: onest(15, weight: 600, color: Mid.blue),
          ),
        ),
      ],
    );
  }
}

class _AccountsScreen extends StatelessWidget {
  const _AccountsScreen({required this.store, required this.now});
  final PhoneStore store;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => _page(context),
  );

  Widget _page(BuildContext context) {
    final t = context.t;
    final snapshot = store.snapshot;
    return Scaffold(
      backgroundColor: Mid.ground,
      appBar: AppBar(
        backgroundColor: Mid.ground,
        foregroundColor: Mid.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(t.ledgerGroupAccounts, style: onest(20, weight: 600)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        itemCount: snapshot.accounts.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, at) {
          if (at == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _FromMac(made: snapshot.madeAt, today: now()),
            );
          }
          final a = snapshot.accounts[at - 1];
          // This phone's waiting entries are counted, as they are in what
          // each category has left.
          final balance = balanceNow(a, store.waiting);
          final amount = formatMoney(balance.abs(), currency: a.currency);
          return Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Mid.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: onest(17, weight: 500),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  a.owes
                      ? (balance < 0
                            ? t.phoneInCredit(amount)
                            : t.phoneOwed(amount))
                      : formatMoney(balance, currency: a.currency),
                  style: onest(
                    17,
                    weight: 600,
                    tabular: true,
                    color: !a.owes && balance < 0 ? Mid.coral : Mid.ink,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// What this phone has made that the Mac hasn't taken in: its entries and
/// its new categories, still the phone's to delete.
class _WaitingScreen extends StatelessWidget {
  const _WaitingScreen({required this.store});
  final PhoneStore store;

  /// Deleting a category takes the entries filed in it too, so it says how
  /// many and how much first.
  Future<void> _deleteCategory(BuildContext context, PhoneCategory c) async {
    final t = context.t;
    final inIt = [
      for (final e in store.waiting)
        if (e.categoryIds.contains(c.id)) e,
    ];
    if (inIt.isNotEmpty) {
      // What was spent in it, less what came back; a split's share in it.
      final total = inIt
          .fold<int>(
            0,
            (sum, e) =>
                sum +
                (e.isSplit
                    ? e.lines
                          .where((l) => l.categoryId == c.id)
                          .fold(0, (s, l) => s + l.amountMinor)
                    : e.amountMinor),
          )
          .abs();
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Mid.panel,
          content: Text(
            // A split goes whole, its other categories' shares too: said
            // with the whole amount.
            inIt.any((e) => e.isSplit)
                ? t.phoneDeleteCategoryWhole(
                    inIt.length,
                    c.name,
                    formatMoney(
                      inIt.fold<int>(0, (s, e) => s + e.amountMinor).abs(),
                      currency: c.currency,
                    ),
                  )
                : t.phoneDeleteCategory(
                    inIt.length,
                    c.name,
                    formatMoney(total, currency: c.currency),
                  ),
            style: onest(17, height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(t.ledgerCancel, style: onest(15, color: Mid.blue)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                t.rowsDelete,
                style: onest(15, weight: 600, color: Mid.coral),
              ),
            ),
          ],
        ),
      );
      if (sure != true) return;
    }
    store.removeCategory(c.id);
  }

  Widget _row({
    required String title,
    required String under,
    Widget? amount,
    required VoidCallback onDelete,
    required String deleteLabel,
  }) => Container(
    constraints: const BoxConstraints(minHeight: 64),
    padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
    decoration: BoxDecoration(
      color: Mid.card,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: onest(16, weight: 500),
              ),
              const SizedBox(height: 2),
              Text(
                under,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: onest(12, color: Mid.ink2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ?amount,
        TextButton(
          onPressed: onDelete,
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            foregroundColor: Mid.blue,
            textStyle: onest(14),
          ),
          child: Text(deleteLabel),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final t = context.t;
      final names = {for (final c in store.categories) c.id: c};
      final accounts = {for (final a in store.snapshot.accounts) a.id: a};
      final made = store.made;
      final entries = store.waiting.reversed.toList();
      return Scaffold(
        backgroundColor: Mid.ground,
        appBar: AppBar(
          backgroundColor: Mid.ground,
          foregroundColor: Mid.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(t.phoneWaitingTitle, style: onest(20, weight: 600)),
        ),
        body: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          itemCount: made.length + entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            if (i < made.length) {
              final c = made[i];
              return _row(
                title: c.name,
                under: t.rowsNewCategoryNote,
                onDelete: () => _deleteCategory(context, c),
                deleteLabel: t.rowsDelete,
              );
            }
            final e = entries[i - made.length];
            final category = names[e.categoryId];
            // Money moved: the two accounts are its name.
            final to = accounts[e.categoryId];
            // Only a transfer has no payee: one whose account has gone
            // from the ledger still says what it was.
            final moved = to != null || e.payee.isEmpty;
            final filed = e.isSplit
                ? t.startSplitCategories(e.lines.length)
                : e.categoryId == phoneIncomeId
                ? t.ledgerIncome
                : moved
                ? t.startTransfer
                : category?.name ?? '';
            return _row(
              title: to != null
                  ? t.phoneTransferTitle(
                      accounts[e.accountId]?.name ?? '',
                      to.name,
                    )
                  : moved
                  ? (accounts[e.accountId]?.name ?? t.startTransfer)
                  : e.payee,
              under: switch (e.lines) {
                // A category of it is gone from the ledger: the computer
                // won't take it in, so it says what to do.
                final lines
                    when lines.any(
                      (l) =>
                          l.categoryId != phoneIncomeId &&
                          names[l.categoryId] == null,
                    ) =>
                  t.phoneWaitingCategoryGone,
                final lines when lines.isNotEmpty =>
                  '${[for (final l in lines) '${l.categoryId == phoneIncomeId ? t.ledgerIncome : names[l.categoryId]!.name} ${formatShort(l.amountMinor.abs(), currency: accounts[e.accountId]?.currency ?? Currency.mnt)}'].join(' · ')} · ${fullDate(e.date)}',
                _ => '$filed · ${fullDate(e.date)}',
              },
              amount: Text(
                moved
                    ? formatMoney(
                        e.amountMinor.abs(),
                        currency:
                            to?.currency ??
                            accounts[e.accountId]?.currency ??
                            Currency.mnt,
                      )
                    : _signed(
                        e.amountMinor,
                        // An entry is in its account's currency; Income has
                        // none of its own.
                        accounts[e.accountId]?.currency ??
                            category?.currency ??
                            Currency.mnt,
                      ),
                style: onest(
                  16,
                  weight: 600,
                  tabular: true,
                  color: moved
                      ? Mid.ink
                      : e.amountMinor < 0
                      ? Mid.coral
                      : Mid.green,
                ),
              ),
              onDelete: () => store.remove(e.id),
              deleteLabel: t.rowsDelete,
            );
          },
        ),
      );
    },
  );
}
