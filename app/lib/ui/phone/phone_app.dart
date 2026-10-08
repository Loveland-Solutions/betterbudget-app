// The phone app (ADR 0005; the screens are ADR 0004 "Phone screens"): it opens
// on Ledger, everything a transaction needs, with the category picked or typed
// from a list that can also make one; Budget, what is left in each category,
// is the other screen. Entries and new categories wait in [PhoneStore] until
// the Mac takes them in.
import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/money.dart';
import '../../domain/phone.dart';
import '../language.dart';
import '../theme.dart';

/// The snapshot and this phone's waiting entries. Where they are kept and how
/// they reach the Mac is the store's business; the screens only read and add.
class PhoneStore extends ChangeNotifier {
  PhoneStore(this._snapshot, {List<PhoneEntry> waiting = const []})
    : _waiting = [...waiting];

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
    _waiting.removeWhere((e) => e.categoryId == id);
    notifyListeners();
  }

  set snapshot(PhoneSnapshot value) {
    _snapshot = value;
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

  /// Nothing until it is typed: a payee filled in ahead is saved by mistake.
  String? payee;
  String? categoryId;

  /// The account chosen by hand; null while Paid from follows the category.
  String? accountId;

  /// Null is today.
  DateTime? date;

  void change(VoidCallback make) {
    make();
    notifyListeners();
  }

  /// Files the entry in [category]. Cents its currency can't hold are cut
  /// from what is typed: read in the new currency they'd be another amount.
  void choose(PhoneCategory category) => change(() {
    categoryId = category.id;
    final point = typed.indexOf('.');
    if (point < 0) return;
    final decimals = category.currency.decimals;
    typed = decimals == 0
        ? typed.substring(0, point)
        : typed.substring(0, min(typed.length, point + 1 + decimals));
  });

  /// Ready for the next entry. An account chosen by hand was for that one
  /// entry: kept, a cash taxi would put every later entry on Cash.
  void clear() => change(() {
    typed = '';
    payee = null;
    categoryId = null;
    accountId = null;
    date = null;
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
                        _draft.choose(category);
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
    this.first = false,
  });
  final PhoneCategory category;
  final int left;
  final VoidCallback onTap;

  /// The one the keyboard's Done would take.
  final bool first;

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
      color: first ? Mid.raised : Mid.card,
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
                    const SizedBox(width: 12),
                    _RoomMoney(
                      left,
                      category.currency,
                      room: room,
                      spokenFor: category.due != null,
                    ),
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
/// on the pad, then Category, Payee, Paid from, Date and Save, in any order.
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

  PhoneCategory? get _category {
    for (final c in _store.categories) {
      if (c.id == _draft.categoryId) return c;
    }
    return null;
  }

  List<PhoneAccount> get _accounts {
    final category = _category;
    return category == null
        ? _store.snapshot.accounts
        : _store.snapshot.accountsFor(category);
  }

  /// The account chosen by hand while it fits the category's currency;
  /// else the category's own, else the one this phone last paid from.
  PhoneAccount? get _account {
    final accounts = _accounts;
    PhoneAccount? called(String? id) {
      for (final a in accounts) {
        if (a.id == id) return a;
      }
      return null;
    }

    return called(_draft.accountId) ??
        called(_category?.paidFromId) ??
        called(_store.waiting.lastOrNull?.accountId) ??
        accounts.firstOrNull;
  }

  Currency get _currency =>
      _category?.currency ?? _account?.currency ?? Currency.mnt;

  /// What was just saved ("Saved · Nomin −₮12,500.00") and how to take it
  /// back, said above Save until the next key or choice. On the page, not
  /// in a popup: a popup at the foot covers the way to Budget.
  String? _saved;
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
    final missing = amount == 0
        ? t.phoneEnterAmount
        : category == null
        ? t.phoneChooseCategory
        : payee == null
        ? t.phoneEnterPayee
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
    final entry = PhoneEntry(
      id: [
        for (var i = 0; i < 16; i++)
          random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ].join(),
      categoryId: category!.id,
      accountId: account!.id,
      payee: payee!,
      amountMinor: -amount,
      date: date ?? _day(widget.now()),
      madeAt: widget.now(),
    );
    _saving = true;
    _store.add(entry);
    _draft.clear();
    _saving = false;
    // The form is empty again, so this line is what says it went in.
    // What the entry did to its category, the reason the phone is opened.
    final left = leftNow(category, _store.waiting);
    final had = formatMoney(left.abs(), currency: category.currency);
    setState(() {
      _saved = t.phoneSaved(
        payee,
        formatMoney(-amount, currency: category.currency),
      );
      _savedLeft = category.madeHere
          ? t.phoneSavedNothingAssigned(category.name)
          : left < 0
          ? t.phoneSavedOver(category.name, had)
          : t.phoneSavedLeft(category.name, had);
      _savedOver = left < 0 && !category.madeHere;
      _undo = () {
        _store.remove(entry.id);
        _change(() {
          _draft
            ..typed = typed
            ..payee = payee
            ..categoryId = category.id
            ..accountId = account.id
            ..date = date;
        });
      };
    });
  }

  Future<void> _pickCategory() async {
    final picked = await Navigator.of(context).push(
      MaterialPageRoute<PhoneCategory>(
        fullscreenDialog: true,
        builder: (_) => _CategoryPage(
          store: _store,
          // A category made here is in the currency being paid in.
          currency: _account?.currency ?? Currency.mnt,
        ),
      ),
    );
    if (picked != null && mounted) _draft.choose(picked);
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
      _change(() => _draft.accountId = picked.id);
    }
  }

  Future<void> _pickDate() async {
    final today = _day(widget.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.date ?? today,
      firstDate: DateTime(today.year - 1, today.month, today.day),
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    if (picked != null && mounted) {
      _change(() => _draft.date = picked == today ? null : picked);
    }
  }

  /// What the category holds now and after this entry. An overspent amount
  /// is said in words: a minus beside "left" reads as a sum to do.
  String _leftLine(Words t, PhoneCategory category, int left, int amount) {
    // Made a moment ago on this phone: "overspent" would blame them for it.
    if (category.madeHere) return t.phoneNothingAssigned;
    String say(int minor) => formatMoney(minor.abs(), currency: _currency);
    final after = left - amount;
    if (amount == 0) {
      return left < 0 ? t.phoneOverNow(say(left)) : t.phoneLeftNow(say(left));
    }
    if (left < 0) return t.phoneOverBoth(say(left), say(after));
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
      final left = category == null ? 0 : leftNow(category, _store.waiting);
      final amount = typedAmountMinor(_draft.typed, _currency);
      final date = _draft.date;
      final over = category != null && !category.madeHere && left - amount < 0;
      // A category that has gone (deleted from the waiting list) isn't
      // something left to clear.
      final nothing =
          _draft.typed.isEmpty &&
          _draft.payee == null &&
          category == null &&
          _draft.accountId == null &&
          _draft.date == null;
      // On a tall phone the pad and Save sit at the foot; on a short one
      // the whole entry scrolls instead of running off the screen.
      return LayoutBuilder(
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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '−${typedAmountShown(_draft.typed, _currency)}',
                        maxLines: 1,
                        style: onest(
                          52,
                          weight: 600,
                          letterSpacing: -1,
                          color: _draft.typed.isEmpty ? Mid.ink3 : Mid.coral,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Its place is kept while no category is chosen, so the rows
                    // under it don't move when one is.
                    SizedBox(
                      height: 22,
                      child: category == null
                          ? null
                          : Text(
                              _leftLine(t, category, left, amount),
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
                          _FieldRow(
                            key: const ValueKey('category-row'),
                            label: t.rowsColumnCategory,
                            value: category?.name ?? '',
                            onTap: _pickCategory,
                          ),
                          Divider(height: 1, thickness: 1, color: Mid.rule),
                          _FieldRow(
                            key: const ValueKey('payee-row'),
                            label: t.rowsColumnPayee,
                            value: _draft.payee ?? '',
                            onTap: _typePayee,
                          ),
                          Divider(height: 1, thickness: 1, color: Mid.rule),
                          _FieldRow(
                            key: const ValueKey('account-row'),
                            label: t.planLabelPaidFrom,
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
                    // A toast that is part of the page (owner, 2026-10-08): what went
                    // in and what it did to the category, until the next key.
                    if (_saved != null)
                      Container(
                        key: const ValueKey('saved-toast'),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                        decoration: BoxDecoration(
                          color: Mid.raised,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _saved!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: onest(15, weight: 500),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _savedLeft ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: onest(
                                      14,
                                      color: _savedOver ? Mid.coral : Mid.ink2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: _undo,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(44, 44),
                                foregroundColor: Mid.blue,
                                textStyle: onest(15),
                              ),
                              child: Text(t.ledgerUndo),
                            ),
                          ],
                        ),
                      ),
                    FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: Mid.blue,
                        foregroundColor: Mid.onAccent,
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
                          textStyle: onest(14)
                              .copyWith(decoration: TextDecoration.underline),
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
      );
    },
  );
}

/// The list a category is chosen from: every category with what is left in
/// it, a box at the top that narrows the list as a name is typed, and
/// "+ New category" at the foot (owner, 2026-10-08).
class _CategoryPage extends StatefulWidget {
  const _CategoryPage({required this.store, required this.currency});
  final PhoneStore store;

  /// The currency a category made here is in.
  final Currency currency;

  @override
  State<_CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<_CategoryPage> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _typed => _text.text.trim();

  void _make() =>
      Navigator.of(context)
          .pop(widget.store.categoryCalled(_typed, widget.currency));

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final store = widget.store;
    final all = store.categories;
    final typed = _typed;
    final listed = typed.isEmpty
        ? _spendThenBills(all)
        : categoriesMatching(all, typed);
    return Scaffold(
      backgroundColor: Mid.ground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.rowsColumnCategory,
                      style: onest(20, weight: 600),
                    ),
                  ),
                  TextButton(
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
              // Not focused on open: the keyboard would cover half the
              // list they may want to scroll instead.
              TextField(
                key: const ValueKey('category-field'),
                controller: _text,
                focusNode: _focus,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                style: onest(17),
                cursorColor: Mid.blue,
                decoration: InputDecoration(
                  hintText: t.planCategoryName,
                  hintStyle: onest(17, color: Mid.ink3),
                  filled: true,
                  fillColor: Mid.card,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
                // Done takes the first that fits. With none it does nothing:
                // a misspelt name isn't to make a category unasked.
                onSubmitted: (_) {
                  final first = categoryNamed(all, typed) ?? listed.firstOrNull;
                  if (typed.isNotEmpty && first != null) {
                    Navigator.of(context).pop(first);
                  }
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: listed.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final category = listed[i];
                    if (category == null) return const _BillsHeading();
                    return _CategoryRow(
                      category: category,
                      left: leftNow(category, store.waiting),
                      first: typed.isNotEmpty && i == 0,
                      onTap: () => Navigator.of(context).pop(category),
                    );
                  },
                ),
              ),
              // Always in the same place, above the keyboard. A name that
              // is already a category is in the list, not offered again.
              if (typed.isEmpty || categoryNamed(all, typed) == null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const ValueKey('new-category'),
                    // With nothing typed there is no name yet: the box
                    // takes it.
                    onPressed: typed.isEmpty ? _focus.requestFocus : _make,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 48),
                      foregroundColor: Mid.blue,
                      textStyle: onest(16),
                    ),
                    child: Text(
                      typed.isEmpty
                          ? t.phoneNewCategory
                          : t.rowsNewCategoryOption(typed),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
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
    if (already != null) {
      setState(() => _taken = already.name);
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
    if (key.isEmpty) return const SizedBox(height: 48);
    return Material(
      color: Mid.panel,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('pad-$key'),
        onTap: () => onKey(key),
        child: SizedBox(
          height: 48,
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
        if (e.categoryId == c.id) e,
    ];
    if (inIt.isNotEmpty) {
      final total = inIt.fold<int>(0, (sum, e) => sum + e.amountMinor.abs());
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Mid.panel,
          content: Text(
            t.phoneDeleteCategory(
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
            return _row(
              title: e.payee,
              under: '${category?.name ?? ''} · ${fullDate(e.date)}',
              amount: Text(
                formatMoney(
                  e.amountMinor,
                  currency: category?.currency ?? Currency.mnt,
                ),
                style: onest(
                  16,
                  weight: 600,
                  tabular: true,
                  color: e.amountMinor < 0 ? Mid.coral : Mid.green,
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
