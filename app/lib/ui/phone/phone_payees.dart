part of 'phone_app.dart';

// Payees on the phone (#532, owner's pick of sketch A, 2026-11-22): a page
// reached from Accounts, a flat list, and a tap on a payee opens its card as
// a page of its own with Cancel and Save pinned, as Edit account does. The
// computer's Payees page, said the same way: the ways the bank writes it
// (contains, starts with or is exactly), its accounts and category, the
// offer to file what is still in Not categorized, and the offer to show the
// name on rows already in. Each change has an Undo and reaches the
// computers as an ordinary change.

Future<void> _openPayees(
  BuildContext context, {
  required PhoneStore store,
  required DateTime Function() now,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => _PayeesPage(store: store, now: now),
  ),
);

/// What a payee's card hands back: Save, or Delete from its ⋯.
class _PayeeAnswer {
  const _PayeeAnswer.save(PayeeRuleInfo this.saved)
    : delete = false,
      showName = false;
  const _PayeeAnswer.delete() : saved = null, delete = true, showName = false;

  /// The card's "Show «name» on the rows already in", as on the computer's.
  const _PayeeAnswer.showName() : saved = null, delete = false, showName = true;
  final PayeeRuleInfo? saved;
  final bool delete;
  final bool showName;
}

/// What the list counts, worked out once per ledger rather than on every
/// letter typed in the search box: the rows each payee's words find, and
/// the rows still in Not categorized this period that each would file.
typedef _PayeeCounts = ({
  Map<int, int> fits,
  List<({PayeeRuleInfo rule, List<RegisterRow> rows})> waiting,
});

/// A pay's name in a Category list, as the computer's names it.
String _payeePayLabel(Words t, LedgerData data, PaySchedule p) {
  final title = payTitle(t, data, p);
  return title == t.ledgerIncome
      ? t.rowsIncomePaycheck
      : t.rowsIncomeFrom(title);
}

/// A payee's category as its line names it: a pay by its name, a category
/// by its own, money moved to an account with an arrow.
String _payeeWhere(Words t, LedgerData data, PayeeRuleInfo rule) {
  final c = data.accounts[rule.categoryId];
  if (c == null || c.deleted) return t.payeesCategoryGone;
  if (c.archived) return t.payeesCategoryArchived(c.name);
  final pay = data.payScheduleById(rule.payId);
  return pay != null ? _payeePayLabel(t, data, pay) : counterLabel(c);
}

class _PayeesPage extends StatefulWidget {
  const _PayeesPage({required this.store, required this.now});
  final PhoneStore store;
  final DateTime Function() now;

  @override
  State<_PayeesPage> createState() => _PayeesPageState();
}

class _PayeesPageState extends State<_PayeesPage> {
  PhoneStore get store => widget.store;
  final _find = TextEditingController();

  @override
  void dispose() {
    _find.dispose();
    super.dispose();
  }

  /// Opens a payee's card (null: a new one) and does what it answers.
  Future<void> _open(PayeeRuleInfo? rule) async {
    final answer = await Navigator.of(context).push(
      MaterialPageRoute<_PayeeAnswer>(
        builder: (_) =>
            _PayeeCardPage(store: store, rule: rule, now: widget.now),
      ),
    );
    if (answer == null || !mounted) return;
    final t = context.t;
    if (answer.showName && rule != null) {
      final act = PhoneShowPayeeNames([rule.id]);
      final done = await _doAccount(context, store, act);
      if (done == null || !mounted) return;
      _saidWithUndo(
        context,
        store,
        done,
        t.payeesNameShown(act.shown, rule.shownAs.trim()),
        'payee-done',
      );
      return;
    }
    if (answer.delete && rule != null) {
      final data = store.snapshot.data!;
      final done = await _doAccount(context, store, PhoneDeletePayee(rule));
      if (done == null || !mounted) return;
      _saidWithUndo(context, store, done, switch (payeeMovedTo(data, rule)) {
        final a? => t.payeesDeletedTransfer(a.name),
        null => t.payeesDeletedMessage(_payeeWhere(t, data, rule)),
      }, 'payee-done');
      return;
    }
    final after = answer.saved;
    if (after == null) return;
    final act = PhoneSavePayee(rule, after);
    final done = await _doAccount(context, store, act);
    final saved = act.saved;
    if (done == null || saved == null || !mounted) return;
    final data = store.snapshot.data!;
    _saidWithUndo(context, store, done, switch (payeeMovedTo(data, saved)) {
      final a? => t.payeesTransferRemembered(a.name),
      null => t.ledgerAlwaysFiled(0, _payeeWhere(t, data, saved)),
    }, 'payee-done');
  }

  Future<void> _file(List<PayeeRuleInfo> rules) async {
    final act = PhoneFilePayees([for (final r in rules) r.id]);
    final done = await _doAccount(context, store, act);
    if (done == null || !mounted) return;
    _saidWithUndo(
      context,
      store,
      done,
      context.t.phonePayeesFiled(act.filed),
      'payee-done',
    );
  }

  Widget _offer(
    String key,
    String says,
    List<String> lines,
    String button,
    VoidCallback onTap,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    decoration: BoxDecoration(
      color: Mid.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Mid.rule),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(says, style: onest(14, color: Mid.ink2, height: 1.35)),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l,
              style: onest(14, color: Mid.ink, height: 1.35, tabular: true),
            ),
          ),
        const SizedBox(height: 10),
        FilledButton(
          key: ValueKey(key),
          onPressed: onTap,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            backgroundColor: Mid.green,
            foregroundColor: Colors.white,
            textStyle: onest(15, weight: 600),
          ),
          child: Text(button, textAlign: TextAlign.center),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([store, _find]),
    builder: (context, _) => _page(context),
  );

  LedgerData? _countedFor;
  _PayeeCounts _counts = (fits: const {}, waiting: const []);

  _PayeeCounts _countsOf(LedgerData data, List<PayeeRuleInfo> rules) {
    if (identical(_countedFor, data)) return _counts;
    _countedFor = data;
    final today = widget.now();
    return _counts = (
      fits: {for (final r in rules) r.id: payeeFitting(data, r).length},
      waiting: [
        for (final r in rules)
          if (payeeWaitingFor(data, r, today) case final rows
              when rows.isNotEmpty)
            (rule: r, rows: rows),
      ],
    );
  }

  /// Where one payee's waiting rows go, with what they come to, so the
  /// button says where money is filed before it is pressed.
  String _fileLine(
    Words t,
    LedgerData data,
    PayeeRuleInfo rule,
    List<RegisterRow> rows,
  ) {
    final sums = <Currency, int>{};
    for (final r in rows) {
      sums[r.currency] = (sums[r.currency] ?? 0) + r.amount;
    }
    return t.phonePayeesFileLine(
      rows.length,
      rule.title,
      [for (final e in sums.entries) formatShort(e.value, currency: e.key)]
          .join(' · '),
      _payeeWhere(t, data, rule),
    );
  }

  Widget _page(BuildContext context) {
    final t = context.t;
    final data = store.snapshot.data;
    final rules = data == null
        ? const <PayeeRuleInfo>[]
        : ([
            for (final r in data.payeeRules)
              if (!r.deleted) r,
          ]..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          ));
    final counts = data == null
        ? (
            fits: const <int, int>{},
            waiting: const <({PayeeRuleInfo rule, List<RegisterRow> rows})>[],
          )
        : _countsOf(data, rules);
    final fits = counts.fits;
    final waiting = counts.waiting.fold(0, (n, w) => n + w.rows.length);
    final want = payeeWords(_find.text);
    final shown = [
      for (final r in rules)
        if (want.isEmpty ||
            payeeWords(r.title).contains(want) ||
            r.spellings.any((s) => s.words.contains(want)))
          r,
    ];
    return Scaffold(
      backgroundColor: Mid.ground,
      appBar: AppBar(
        backgroundColor: Mid.ground,
        foregroundColor: Mid.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(t.ledgerPayees, style: onest(20, weight: 600)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: OutlinedButton(
              key: const ValueKey('add-payee'),
              onPressed: data == null ? null : () => unawaited(_open(null)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                foregroundColor: Mid.blue,
                side: BorderSide(color: Mid.blue, width: 1.5),
                textStyle: onest(15, weight: 600),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(t.payeesAdd),
            ),
          ),
        ],
      ),
      body: ListView(
        key: const ValueKey('payees-page'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          if (waiting > 0)
            _offer(
              'payees-file',
              t.phonePayeesFit(waiting),
              [
                for (final w in counts.waiting)
                  _fileLine(t, data!, w.rule, w.rows),
              ],
              t.payeesFileWaiting(waiting),
              () => unawaited(_file([for (final w in counts.waiting) w.rule])),
            ),
          if (rules.isEmpty && data != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
              child: Text(
                t.payeesEmpty,
                key: const ValueKey('payees-empty'),
                style: onest(15, color: Mid.ink2, height: 1.4),
              ),
            ),
          // Offered only while the list is long enough to need finding in.
          if (rules.length > 7)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                key: const ValueKey('payees-find'),
                controller: _find,
                style: onest(16),
                cursorColor: Mid.blue,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: t.phonePayeesFind,
                  hintStyle: onest(16, color: Mid.ink3),
                  prefixIcon: Icon(Icons.search_rounded, color: Mid.ink3),
                  filled: true,
                  fillColor: Mid.panel,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Mid.rule),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Mid.rule),
                  ),
                ),
              ),
            ),
          for (final r in shown)
            InkWell(
              key: ValueKey('payee-${r.id}'),
              onTap: () => unawaited(_open(r)),
              child: Container(
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Mid.rule)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: onest(16, weight: 600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _payeeWhere(t, data!, r),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: onest(13, color: Mid.ink2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      t.payeesSpellingRows(fits[r.id] ?? 0),
                      style: onest(13, color: Mid.ink3),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Mid.ink3),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One way a payee is written, as it is typed: its words and how they are
/// looked for. The last line is always empty, the place for the next.
class _WayDraft {
  _WayDraft([PayeeSpelling? s])
    : how = s?.how ?? PayeeMatch.contains,
      text = TextEditingController(text: s?.text ?? '');
  PayeeMatch how;
  final TextEditingController text;
  PayeeSpelling get spelling => PayeeSpelling(how, text.text.trim());
}

/// A payee's card on the phone: the computer's, on one page with Cancel and
/// Save pinned under it. Hands back [_PayeeAnswer].
class _PayeeCardPage extends StatefulWidget {
  const _PayeeCardPage({
    required this.store,
    required this.rule,
    required this.now,
  });
  final PhoneStore store;

  /// The payee opened; null for a new one.
  final PayeeRuleInfo? rule;
  final DateTime Function() now;

  @override
  State<_PayeeCardPage> createState() => _PayeeCardPageState();
}

class _PayeeCardPageState extends State<_PayeeCardPage>
    with _FormRows<_PayeeCardPage> {
  PayeeRuleInfo? get _rule => widget.rule;
  LedgerData get _data => widget.store.snapshot.data!;
  late final _name = TextEditingController(text: _rule?.shownAs ?? '');
  late final List<_WayDraft> _ways = [
    for (final s in _rule?.spellings ?? const <PayeeSpelling>[]) _WayDraft(s),
  ];
  late final Set<int> _accounts = {
    for (final id in _rule?.accountIds ?? const <int>{})
      if (_data.accounts[id] case final a? when !a.deleted) id,
    // Nothing is filled in for them (owner: no autofill); with one account
    // there is no choice to make.
    if (_rule == null && _data.openAccounts.length == 1)
      _data.openAccounts.single.id,
  };
  late int? _categoryId = _rule?.categoryId;
  late int? _payId = _rule?.payId;
  final _spare = <TextEditingController>[];
  var _tried = false;
  String? _clash;

  /// What the card held when it opened, to tell a Save that changed nothing.
  late final String _start = _now;
  String get _now =>
      '${_name.text.trim()}|'
      '${[for (final s in _typed) '${s.how.name}:${s.text}'].join('\n')}|'
      '${(_accounts.toList()..sort()).join(',')}|$_categoryId|$_payId';

  @override
  Currency get _currency =>
      _data.openAccounts.firstOrNull?.currency ?? Currency.mnt;

  @override
  DateTime get _today => widget.now();

  @override
  void initState() {
    super.initState();
    _tidy();
    _start;
  }

  @override
  void dispose() {
    _name.dispose();
    for (final w in _ways) {
      w.text.dispose();
    }
    for (final c in _spare) {
      c.dispose();
    }
    _disposeFocuses();
    super.dispose();
  }

  /// One empty line after the last way, and only one.
  void _tidy() {
    bool empty(_WayDraft w) => w.text.text.trim().isEmpty;
    while (_ways.length > 1 &&
        empty(_ways.last) &&
        empty(_ways[_ways.length - 2])) {
      // Disposed with the page: its field is still on screen this frame.
      _spare.add(_ways.removeLast().text);
    }
    if (_ways.isEmpty || !empty(_ways.last)) _ways.add(_WayDraft());
  }

  List<PayeeSpelling> get _typed => [
    for (final w in _ways)
      if (w.spelling.words.isNotEmpty) w.spelling,
  ];

  Set<Currency> get _currencies => {
    for (final a in _data.balanceSheetAccounts)
      if (_accounts.contains(a.id)) a.currency,
  };

  List<AccountInfo> get _categories {
    final all = _data.categories.where(
      (c) =>
          !isUncategorized(c) && _currencies.every((x) => categoryTakes(c, x)),
    );
    return [...all.where((c) => !c.isIncome), ...all.where((c) => c.isIncome)];
  }

  /// The accounts a payee's rows can be money moved to or from (#117).
  List<AccountInfo> get _transfers {
    if (_currencies.length > 1) return const [];
    return [
      for (final a in _data.openAccounts)
        if (!_accounts.contains(a.id) &&
            _currencies.every((x) => a.currency == x))
          a,
    ];
  }

  /// An account ticked or not: a pay paid into one no longer ticked, or a
  /// category the accounts' currencies don't all take, is let go.
  void _tick(int id) => setState(() {
    _clash = null;
    _accounts.contains(id) ? _accounts.remove(id) : _accounts.add(id);
    final pay = _data.payScheduleById(_payId);
    if (pay != null && !_accounts.contains(pay.accountId)) _payId = null;
    final c = _data.accounts[_categoryId];
    if (c != null &&
        (!_currencies.every((x) => categoryTakes(c, x)) ||
            c.isBalanceSheet && _accounts.contains(c.id))) {
      _categoryId = null;
      _payId = null;
    }
  });

  PayeeRuleInfo _after() {
    final spellings = _typed;
    final category = _categoryId!;
    return _rule?.copyWith(
          spellings: spellings,
          shownAs: _name.text.trim(),
          categoryId: category,
          payId: () => _payId,
          accountIds: _accounts,
        ) ??
        PayeeRuleInfo(
          id: 0,
          spellings: spellings,
          shownAs: _name.text.trim(),
          categoryId: category,
          payId: _payId,
          accountIds: {..._accounts},
        );
  }

  void _save() {
    // Nothing changed: nothing to remember again, no empty undo.
    if (_rule != null && _now == _start) {
      Navigator.of(context).pop();
      return;
    }
    if (_name.text.trim().isEmpty ||
        _typed.isEmpty ||
        _categoryId == null ||
        _accounts.isEmpty) {
      setState(() => _tried = true);
      return;
    }
    final after = _after();
    final t = context.t;
    // Another payee that goes by the same words on one of these accounts:
    // said, and the card stays open.
    final clash = payeeOverlaps(_data, _rule, after).clash;
    if (clash != null) {
      setState(
        () => _clash = t.payeesAlreadyListed(
          clash.sharedWith(after)!.text,
          _payeeWhere(t, _data, clash),
        ),
      );
      return;
    }
    Navigator.of(context).pop(_PayeeAnswer.save(after));
  }

  Future<void> _pickCategory() async {
    final t = context.t;
    final pays = [
      for (final p in _data.paySchedules)
        if (_accounts.contains(p.accountId)) p,
    ];
    final picked = await _pick<String>(
      t.payeesColumnFiled,
      [
        for (final p in pays) ('p${p.id}', _payeePayLabel(t, _data, p)),
        for (final c in _categories) ('c${c.id}', c.name),
        for (final a in _transfers) ('c${a.id}', counterLabel(a)),
      ],
      chosen: _payId != null ? 'p$_payId' : 'c$_categoryId',
      keyPrefix: 'payee-category',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _clash = null;
      if (picked.startsWith('p')) {
        _payId = int.parse(picked.substring(1));
        _categoryId = _data.income?.id;
      } else {
        _categoryId = int.parse(picked.substring(1));
        _payId = null;
      }
    });
  }

  String? get _categoryLabel {
    final t = context.t;
    final pay = _data.payScheduleById(_payId);
    if (pay != null) return _payeePayLabel(t, _data, pay);
    final c = _data.accounts[_categoryId];
    return c == null ? null : counterLabel(c);
  }

  Widget _segments(_WayDraft w, int i) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
    child: Row(
      children: [
        for (final (how, label) in [
          (PayeeMatch.contains, context.t.payeesHowContains),
          (PayeeMatch.starts, context.t.payeesHowStarts),
          (PayeeMatch.exactly, context.t.payeesHowExactly),
        ])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Material(
                color: w.how == how ? Mid.blueWash : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  key: ValueKey('way-$i-${how.name}'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() {
                    _clash = null;
                    w.how = how;
                  }),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: w.how == how ? Mid.blue : Mid.rule,
                      ),
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      style: onest(
                        13.5,
                        weight: w.how == how ? 600 : 400,
                        color: w.how == how ? Mid.ink : Mid.ink2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  /// The newest row these words fit, drawn as the next one from the bank
  /// will be: what the bank wrote, and what the ledger will show.
  Widget? _example(Words t, PayeeRuleInfo probe, String name) {
    final rows = payeeFitting(_data, probe);
    if (rows.isEmpty) return null;
    final plain = rows.where((r) => r.bankPayee == null).toList();
    final row = (plain.isEmpty ? rows : plain).last;
    final moved = payeeMovedTo(_data, probe);
    if (moved != null || name.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.payeesNextFromBank, style: onest(13, color: Mid.ink2)),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              style: onest(14, color: Mid.ink2, height: 1.45),
              children: [
                TextSpan(text: '${t.payeesAsBankSends}: '),
                TextSpan(
                  text: row.payeeWritten,
                  style: onest(14, color: Mid.ink),
                ),
                const TextSpan(text: '\n'),
                TextSpan(text: '${t.payeesAsLedgerShows}: '),
                TextSpan(
                  text: name,
                  style: onest(14, color: Mid.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    _tidy();
    final data = _data;
    final typed = _typed;
    final name = _name.text.trim();
    final probe = PayeeRuleInfo(
      id: _rule?.id ?? -1,
      spellings: typed,
      shownAs: name,
      categoryId: _categoryId ?? 0,
      payId: _payId,
      accountIds: _accounts,
    );
    final missing = <String>[
      if (_tried && name.isEmpty) t.payeesNeedsName,
      if (_tried && typed.isEmpty) t.payeesNeedsWords,
      if (_tried && _accounts.isEmpty) t.payeesNeedsAccount,
      if (_tried && _categoryId == null) t.payeesNeedsCategory,
    ];
    final open = [
      ...data.openAccounts,
      // An archived one it still holds on is listed, so it can be unticked.
      for (final x in data.balanceSheetAccounts)
        if (x.archived && _accounts.contains(x.id)) x,
    ];
    final example = typed.isEmpty || _accounts.isEmpty
        ? null
        : _example(t, probe, name);
    return Scaffold(
      backgroundColor: Mid.ground,
      appBar: AppBar(
        backgroundColor: Mid.ground,
        foregroundColor: Mid.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _rule?.title ?? t.payeesAdd,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: onest(20, weight: 600),
        ),
        actions: [
          if (_rule != null)
            PopupMenuButton<bool>(
              key: const ValueKey('payee-menu'),
              color: Mid.raised,
              icon: Icon(Icons.more_horiz_rounded, color: Mid.ink2),
              onSelected: (_) =>
                  Navigator.of(context).pop(const _PayeeAnswer.delete()),
              itemBuilder: (_) => [
                PopupMenuItem<bool>(
                  key: const ValueKey('payee-delete'),
                  value: true,
                  child: Text(
                    t.payeesDelete,
                    style: onest(16, color: Mid.coral),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        key: const ValueKey('payee-card'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          _card([
            _fieldRow(
              'payee-name',
              t.payeesNameLabel,
              _name,
              text: true,
              hint: t.payeesNameHint,
              wrong: _tried && name.isEmpty,
            ),
          ]),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Text(
              t.payeesSpellingsLabel,
              style: onest(13, weight: 600, color: Mid.ink2),
            ),
          ),
          for (final (i, w) in _ways.indexed) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _card([
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: TextField(
                    key: ValueKey('way-$i'),
                    controller: w.text,
                    onChanged: (_) => setState(() => _clash = null),
                    textCapitalization: TextCapitalization.none,
                    style: onest(16, weight: 500),
                    cursorColor: Mid.blue,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: i == 0
                          ? t.payeesSpellingFirstHint
                          : t.payeesSpellingHint,
                      hintStyle: onest(
                        16,
                        color: _tried && typed.isEmpty && i == 0
                            ? Mid.coral
                            : Mid.ink3,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (w.text.text.trim().isNotEmpty) ...[
                  _segments(w, i),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _accounts.isEmpty
                                ? ''
                                : t.payeesSpellingRows(
                                    payeeFitting(
                                      data,
                                      PayeeRuleInfo(
                                        id: -1,
                                        spellings: [w.spelling],
                                        categoryId: 0,
                                        accountIds: _accounts,
                                      ),
                                    ).length,
                                  ),
                            style: onest(13, color: Mid.ink2),
                          ),
                        ),
                        TextButton(
                          key: ValueKey('way-remove-$i'),
                          onPressed: () => setState(() {
                            _clash = null;
                            // Disposed with the page: its field is still on
                            // screen this frame.
                            if (_ways.remove(w)) _spare.add(w.text);
                            _tidy();
                          }),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            foregroundColor: Mid.ink2,
                            textStyle: onest(14),
                          ),
                          child: Text(t.payeesRemoveSpelling),
                        ),
                      ],
                    ),
                  ),
                ],
              ]),
            ),
          ],
          if (_clash != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                _clash!,
                key: const ValueKey('payee-clash'),
                style: onest(13.5, color: Mid.coral),
              ),
            ),
          const SizedBox(height: 6),
          _card([
            _asked(
              t.payeesColumnAccounts,
              Column(
                children: [
                  for (final a in open)
                    InkWell(
                      key: ValueKey('payee-account-${a.id}'),
                      onTap: () => _tick(a.id),
                      child: Semantics(
                        checked: _accounts.contains(a.id),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Icon(
                                  _accounts.contains(a.id)
                                      ? Icons.check_box_rounded
                                      : Icons.check_box_outline_blank_rounded,
                                  color: _accounts.contains(a.id)
                                      ? Mid.blue
                                      : Mid.ink3,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    a.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: onest(16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          _card([
            _choiceRow(
              'payee-category',
              t.payeesColumnFiled,
              _categoryLabel ??
                  (_accounts.isEmpty
                      ? t.payeesNeedsAccount
                      : t.payeesNeedsCategory),
              _accounts.isEmpty ? () {} : () => unawaited(_pickCategory()),
              wrong: _tried && _categoryId == null,
            ),
          ]),
          if (missing.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Text(
                missing.join(' · '),
                key: const ValueKey('payee-missing'),
                style: onest(13.5, color: Mid.coral),
              ),
            ),
          ?example,
          // As on the computer's card: the payee as saved, while nothing
          // typed here says otherwise.
          if (_rule case final saved?
              when _now == _start &&
                  payeeUnnamedFor(data, saved).isNotEmpty) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              key: const ValueKey('payee-show-name'),
              onPressed: () =>
                  Navigator.of(context).pop(const _PayeeAnswer.showName()),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                foregroundColor: Mid.blue,
                side: BorderSide(color: Mid.blue, width: 1.5),
                textStyle: onest(15, weight: 600),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                t.payeesShowName(
                  payeeUnnamedFor(data, saved).length,
                  saved.shownAs.trim(),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Mid.panel,
            border: Border(top: BorderSide(color: Mid.rule)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  key: const ValueKey('payee-cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: Mid.ink2,
                    textStyle: onest(16, weight: 500),
                  ),
                  child: Text(t.setupCancel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  key: const ValueKey('payee-save'),
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: Mid.green,
                    foregroundColor: Colors.white,
                    textStyle: onest(16, weight: 600),
                  ),
                  child: Text(t.rowsSave),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
