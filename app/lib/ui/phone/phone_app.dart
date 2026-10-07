// The phone app (ADR 0005; the screens are ADR 0004 "Phone screens", option B):
// it opens on what is left in each category, and a category's + opens the
// amount pad with that category already chosen. Entries wait in [PhoneStore]
// until the Mac takes them in.
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

  PhoneSnapshot get snapshot => _snapshot;
  List<PhoneEntry> get waiting => List.unmodifiable(_waiting);

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

class PhoneHome extends StatelessWidget {
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final t = context.t;
      final snapshot = store.snapshot;
      final today = now();
      final made = snapshot.madeAt;
      final waiting = store.waiting.length;
      // Money to spend first; then, under their own heading, the categories
      // whose money is waiting for a bill (owner, 2026-10-07: rent's money
      // read as money to spend). Null stands for the heading.
      final listed = <PhoneCategory?>[
        for (final c in snapshot.categories)
          if (c.due == null) c,
        if (snapshot.categories.any((c) => c.due != null)) null,
        for (final c in snapshot.categories)
          if (c.due != null) c,
      ];
      return Scaffold(
        backgroundColor: Mid.ground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
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
                                : t.phoneLeftUntil(
                                    shortDate(snapshot.periodEnd!),
                                  ),
                            style: onest(20, weight: 600),
                          ),
                          const SizedBox(height: 4),
                          _FromMac(made: made, today: today),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              _AccountsScreen(store: store, now: now),
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
                      itemCount: listed.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final category = listed[i];
                        if (category == null) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                            child: Text(
                              t.phoneBills,
                              key: const ValueKey('bills-heading'),
                              style: onest(14, weight: 600, color: Mid.ink2),
                            ),
                          );
                        }
                        return _CategoryRow(
                          category: category,
                          left: leftNow(category, store.waiting),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              fullscreenDialog: true,
                              builder: (_) => SpendScreen(
                                store: store,
                                category: category,
                                now: now,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Offered only while there is something waiting.
                if (waiting > 0)
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _WaitingScreen(store: store),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      foregroundColor: Mid.ink2,
                      textStyle: onest(14)
                          .copyWith(decoration: TextDecoration.underline),
                    ),
                    child: Text(t.phoneWaiting(waiting)),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

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
  Widget build(BuildContext context) => Material(
    color: Mid.card,
    borderRadius: BorderRadius.circular(14),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
          child: LayoutBuilder(
            builder: (context, box) {
              final nameStyle = onest(17, weight: 500);
              final name = TextPainter(
                text: TextSpan(text: category.name, style: nameStyle),
                textDirection: TextDirection.ltr,
                maxLines: 1,
              )..layout();
              // The row less the + and the two gaps, less the name: what the
              // amount can have before the name would be cut short.
              final room = box.maxWidth - 44 - 24 - name.width;
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
                        // Its money is spoken for: the bill it is saving for.
                        if (category.due != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              context.t.phoneDue(shortDate(category.due!)),
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
                  const SizedBox(width: 12),
                  Semantics(
                    label: context.t.phoneAddTo(category.name),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Mid.raised,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.add, size: 26, color: Mid.blue),
                    ),
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

/// The amount pad for one category: amount, payee, Paid from, Date, Save.
class SpendScreen extends StatefulWidget {
  const SpendScreen({
    super.key,
    required this.store,
    required this.category,
    required this.now,
  });
  final PhoneStore store;
  final PhoneCategory category;
  final DateTime Function() now;

  @override
  State<SpendScreen> createState() => _SpendScreenState();
}

class _SpendScreenState extends State<SpendScreen> {
  String _typed = '';

  /// Nothing until it is typed: a payee filled in ahead is saved by mistake.
  String? _payee;
  late PhoneAccount? _account = _startAccount();
  late DateTime _date = _day(widget.now());

  /// What Save found missing, said above it until the next key or choice.
  String? _missing;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  Currency get _currency => widget.category.currency;

  PhoneAccount? _startAccount() {
    final accounts = widget.store.snapshot.accountsFor(widget.category);
    for (final a in accounts) {
      if (a.id == widget.category.paidFromId) return a;
    }
    return accounts.firstOrNull;
  }

  void _press(String key) => setState(() {
    _typed = pressAmountKey(_typed, key, _currency);
    _missing = null;
  });

  void _save() {
    final t = context.t;
    final amount = typedAmountMinor(_typed, _currency);
    final account = _account;
    if (amount == 0) {
      setState(() => _missing = t.phoneEnterAmount);
      return;
    }
    if (_payee == null) {
      setState(() => _missing = t.phoneEnterPayee);
      return;
    }
    if (account == null) {
      setState(() => _missing = t.phoneChooseAccount);
      return;
    }
    final random = Random.secure();
    widget.store.add(
      PhoneEntry(
        id: [
          for (var i = 0; i < 16; i++)
            random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ].join(),
        categoryId: widget.category.id,
        accountId: account.id,
        payee: _payee!,
        amountMinor: -amount,
        date: _date,
        madeAt: widget.now(),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _typePayee() async {
    final snapshot = widget.store.snapshot;
    final typed = await showDialog<String>(
      context: context,
      builder: (context) => _PayeeDialog(
        start: _payee ?? '',
        matching: (typed) => snapshot.payeesMatching(typed, widget.category),
      ),
    );
    if (typed != null && typed.trim().isNotEmpty && mounted) {
      setState(() {
        _payee = typed.trim();
        _missing = null;
      });
    }
  }

  Future<void> _pickAccount() async {
    final accounts = widget.store.snapshot.accountsFor(widget.category);
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
                trailing: a.id == _account?.id
                    ? Icon(Icons.check, color: Mid.blue)
                    : null,
                onTap: () => Navigator.of(context).pop(a),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _account = picked);
  }

  Future<void> _pickDate() async {
    final today = _day(widget.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(today.year - 1, today.month, today.day),
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  /// What the category holds now and after this entry. An overspent amount
  /// is said in words: a minus beside "left" reads as a sum to do.
  String _leftLine(Words t, int left, int amount) {
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

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final category = widget.category;
    final left = leftNow(category, widget.store.waiting);
    final amount = typedAmountMinor(_typed, _currency);
    final today = _day(widget.now());
    return Scaffold(
      backgroundColor: Mid.ground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '−${typedAmountShown(_typed, _currency)}',
                  maxLines: 1,
                  style: onest(
                    52,
                    weight: 600,
                    letterSpacing: -1,
                    color: _typed.isEmpty ? Mid.ink3 : Mid.coral,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _leftLine(t, left, amount),
                textAlign: TextAlign.center,
                style: onest(
                  15,
                  color: left - amount < 0 ? Mid.coral : Mid.ink2,
                ),
              ),
              const SizedBox(height: 14),
              Material(
                color: Mid.card,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _FieldRow(
                      key: const ValueKey('payee-row'),
                      label: t.rowsColumnPayee,
                      value: _payee ?? '',
                      onTap: _typePayee,
                    ),
                    Divider(height: 1, thickness: 1, color: Mid.rule),
                    _FieldRow(
                      label: t.planLabelPaidFrom,
                      value: _account?.name ?? '',
                      onTap: _pickAccount,
                    ),
                    Divider(height: 1, thickness: 1, color: Mid.rule),
                    _FieldRow(
                      label: t.rowsColumnDate,
                      value: _date == today ? t.today : fullDate(_date),
                      onTap: _pickDate,
                    ),
                  ],
                ),
              ),
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
                  backgroundColor: Mid.blue,
                  foregroundColor: Mid.onAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: onest(17, weight: 600),
                ),
                child: Text(t.rowsSave),
              ),
            ],
          ),
        ),
      ),
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

/// This phone's entries the Mac hasn't taken in: still the phone's to delete.
class _WaitingScreen extends StatelessWidget {
  const _WaitingScreen({required this.store});
  final PhoneStore store;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final t = context.t;
      final names = {for (final c in store.snapshot.categories) c.id: c};
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
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final e = entries[i];
            final category = names[e.categoryId];
            return Container(
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
                          e.payee,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: onest(16, weight: 500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${category?.name ?? ''} · ${fullDate(e.date)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: onest(12, color: Mid.ink2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
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
                  TextButton(
                    onPressed: () => store.remove(e.id),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      foregroundColor: Mid.blue,
                      textStyle: onest(14),
                    ),
                    child: Text(t.rowsDelete),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}
