part of 'ledger_screen.dart';

// The Payees section (owner, 2026-10-12: "I don't want to hide this… it
// deserves its own dedicated section", then "Let's make this a real
// feature"): every payee the app remembers a category for, each a line that
// reads as a sentence and opens into its Edit (ADR 0004 "Payees: the real
// feature", layout B). The rules are [PayeeRuleInfo] rows; the screen
// records each change for undo.

/// What the page changes.
class _PayeesActions {
  const _PayeesActions({
    required this.save,
    required this.delete,
    required this.unsaved,
    required this.opened,
  });

  /// An Edit opened.
  final VoidCallback opened;

  /// Another Edit or a new payee was asked for while one holds typing.
  final VoidCallback unsaved;

  /// A payee saved from its Edit: new ([before] null) or changed. False
  /// when it wasn't saved (the words are another line's): the Edit stays.
  final Future<bool> Function(PayeeRuleInfo? before, PayeeRuleInfo after) save;
  final Future<void> Function(PayeeRuleInfo rule) delete;
}

/// The posted rows of its accounts that [probe] fits: by any of its
/// spellings, or by its name.
List<RegisterRow> _fitting(LedgerData data, PayeeRuleInfo probe) => [
  for (final a in data.openAccounts)
    if (probe.accountIds.contains(a.id))
      for (final r in data.registerFor(a.id).posted)
        if (r.kind == RowKind.simple && probe.fits(r.txnPayee, r.memo)) r,
];

/// Of [rows], the ones still in Not categorized that [rule] would file
/// now: in this period, the ones the Not categorized tab shows (owner,
/// 2026-10-26); not one a longer line wins, as an import would decide; in
/// a currency its category takes; money in only, for a pay's paycheck.
List<RegisterRow> _waitingOf(
  LedgerData data,
  List<RegisterRow> rows,
  PayeeRuleInfo rule,
  DateTime today,
) {
  final holding = data.categories.where(isUncategorized).firstOrNull?.id;
  final category = data.accounts[rule.categoryId];
  if (holding == null || category == null) return const [];
  final pay = data.payScheduleById(rule.payId);
  final period = budgetPeriod(today, data.periodSchedule);
  final rules = [
    for (final r in data.payeeRules)
      if (r.id != rule.id) r,
    rule,
  ];
  return [
    for (final r in rows)
      if (r.categoryId == holding &&
          !r.date.isBefore(period.start) &&
          !r.date.isAfter(period.end) &&
          categoryTakes(category, r.currency) &&
          (pay == null || r.accountId == pay.accountId) &&
          PayeeRuleInfo.pick(
                rules,
                r.accountId,
                r.txnPayee,
                r.memo,
                amount: r.amount,
              )?.id ==
              rule.id)
        r,
  ];
}

List<RegisterRow> _waitingFor(
  LedgerData data,
  PayeeRuleInfo rule,
  DateTime today,
) => _waitingOf(data, _fitting(data, rule), rule, today);

/// The category a payee goes to, as a row's chip names it: a pay by its
/// name, a category by its own; a deleted one said so.
String _ruleLabel(
  Words t,
  LedgerData data,
  PayeeRuleInfo rule,
  List<({int id, int accountId, String label})> pays,
) {
  final c = data.accounts[rule.categoryId];
  if (c == null || c.deleted) return t.payeesCategoryGone;
  // An import doesn't file into an archived one: said, not left to look
  // as if it works (code review, 2026-10-26).
  if (c.archived) return t.payeesCategoryArchived(c.name);
  return pays.where((p) => p.id == rule.payId).firstOrNull?.label ?? c.name;
}

/// The accounts a payee holds on, by name: never "All accounts", which
/// would read as taking in an account opened later (budget review,
/// 2026-10-26).
String _accountsLabel(Words t, LedgerData data, Set<int> ids) {
  // An archived one is named too: it holds there again when it is back.
  final on = [
    for (final a in data.balanceSheetAccounts)
      if (ids.contains(a.id)) a,
  ];
  if (on.isEmpty) return t.payeesNoAccount;
  return on.map((a) => a.name).join(', ');
}

/// A sentence with the payee's words in «…»: the words in ink, the rest
/// quiet, whatever order the language puts them in.
class _Quoted extends StatelessWidget {
  const _Quoted(this.text);
  final String text;
  static const size = 14.0;

  @override
  Widget build(BuildContext context) {
    final quiet = onest(size - 1, color: Mid.ink3);
    final ink = onest(size, weight: 500, color: Mid.ink);
    // Each «…» in ink, with several spellings too.
    final spans = <TextSpan>[];
    var at = 0;
    for (final m in RegExp('«[^»]*»').allMatches(text)) {
      if (m.start > at) {
        spans.add(TextSpan(text: text.substring(at, m.start), style: quiet));
      }
      spans.add(TextSpan(text: m.group(0), style: ink));
      at = m.end;
    }
    if (spans.isEmpty) return Text(text, style: quiet);
    if (at < text.length) {
      spans.add(TextSpan(text: text.substring(at), style: quiet));
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _PayeesPage extends StatefulWidget {
  const _PayeesPage({
    super.key,
    required this.data,
    required this.today,
    required this.pays,
    required this.actions,
    required this.keep,
  });
  final LedgerData data;
  final DateTime today;
  final _PayeeKeep keep;

  /// Each pay as a row's dropdown names it.
  final List<({int id, int accountId, String label})> pays;
  final _PayeesActions actions;

  @override
  State<_PayeesPage> createState() => _PayeesPageState();
}

class _PayeesPageState extends State<_PayeesPage> {
  _PayeeKeep get _keep => widget.keep;
  int? get _open => _keep.open;
  bool get _adding => _keep.adding;

  /// The open Edit's way to close a dropdown of its own, while it has one.
  bool Function()? _closeEditMenu;

  /// Each line's focus, so it can be given back after its Edit closes.
  final _lineFocus = <int, FocusNode>{};
  final _addFocus = FocusNode(debugLabel: 'payee-add');

  FocusNode _focusOf(int id) =>
      _lineFocus[id] ??= FocusNode(debugLabel: 'payee-line-$id');

  @override
  void dispose() {
    for (final f in _lineFocus.values) {
      f.dispose();
    }
    _addFocus.dispose();
    super.dispose();
  }

  /// After the frame: the line or button is on screen again by then.
  void _focusLater(FocusNode Function() which) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final f = which();
        if (f.context != null) f.requestFocus();
      });

  /// Esc reached the screen with an Edit open: a dropdown open in it closes
  /// first, else the Edit, as from inside. False with none open. Focus goes
  /// back to the line it was opened from, or Add a payee.
  bool closeEdit() {
    if (_open == null && !_adding) return false;
    if (_closeEditMenu?.call() ?? false) return true;
    final was = _open;
    setState(_keep.close);
    _focusLater(() => was == null ? _addFocus : _focusOf(was));
    return true;
  }

  /// "+ Add a payee", and ⌘N on this page. False when an open Edit holds
  /// typing, which isn't thrown away: the screen says so.
  bool addNew() {
    if (_adding) return true;
    if (_keep.dirty) return false;
    setState(() {
      _keep.close();
      _keep.adding = true;
    });
    widget.actions.opened();
    return true;
  }

  /// A line clicked: its Edit opens, unless another holds typing.
  bool _openLine(int id) {
    if (_keep.dirty && _open != id) return false;
    setState(() {
      if (_open != id) _keep.close();
      _keep.open = id;
    });
    widget.actions.opened();
    return true;
  }

  /// An undo or redo changed [id]: an Edit open on it is out of date.
  void changed(int id) {
    if (_open == id) setState(_keep.close);
  }

  void _menus(bool Function()? close, bool Function()? gone) {
    if (close != null) {
      _closeEditMenu = close;
    } else if (identical(_closeEditMenu, gone)) {
      _closeEditMenu = null;
    }
  }

  /// Deleted: focus goes to the next line, or Add a payee with none left.
  void _deleted(List<PayeeRuleInfo> rules, PayeeRuleInfo r) {
    final i = rules.indexOf(r);
    final next = i + 1 < rules.length
        ? rules[i + 1]
        : (i > 0 ? rules[i - 1] : null);
    widget.actions.delete(r);
    _focusLater(() => next == null ? _addFocus : _focusOf(next.id));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final data = widget.data;
    // By what each is called. The same order on every reload: two lines
    // called the same on different accounts don't swap.
    String called(PayeeRuleInfo r) => payeeWords(r.title);
    final rules = [...data.payeeRules]
      ..sort(
        (x, y) => called(x) != called(y)
            ? called(x).compareTo(called(y))
            : x.id.compareTo(y.id),
      );
    // With one account there is nothing for the column to tell apart.
    final accounts = data.openAccounts.length > 1;
    Widget heading(String label) =>
        Text(label, style: onest(12, color: Mid.ink3));
    final editor = _adding
        ? _PayeeEditor(
            key: const ValueKey('payee-edit-new'),
            data: data,
            today: widget.today,
            pays: widget.pays,
            draft: _keep.of(null, data),
            onCancel: closeEdit,
            menus: _menus,
            onSave: (after) async {
              final saved = await widget.actions.save(null, after);
              if (saved && mounted) closeEdit();
              return saved;
            },
          )
        : null;
    return GestureDetector(
      // A click on the page away from the Edit closes it, as away from a row.
      behavior: HitTestBehavior.translucent,
      onTap: () => closeEdit(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 36,
              child: Row(
                children: [
                  Text(
                    t.ledgerSectionPayees,
                    style: onest(22, weight: 600, letterSpacing: -0.3),
                  ),
                  const Spacer(),
                  _PrimaryButton(
                    key: const ValueKey('payee-add'),
                    label: t.payeesAdd,
                    icon: Icons.add_rounded,
                    focusNode: _addFocus,
                    onTap: () {
                      if (!addNew()) widget.actions.unsaved();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // What a line does, said once where the lines are.
            if (rules.isNotEmpty)
              Text(t.payeesWhatLinesDo, style: onest(13, color: Mid.ink2)),
            const SizedBox(height: 14),
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: Mid.panel,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Mid.rule),
                ),
                child: rules.isEmpty && !_adding
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          t.payeesEmpty,
                          key: const ValueKey('payees-empty'),
                          style: onest(13.5, color: Mid.ink2),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: heading(t.payeesColumnPayee),
                                ),
                                if (accounts)
                                  Expanded(
                                    flex: 3,
                                    child: heading(t.payeesColumnAccounts),
                                  ),
                                Expanded(
                                  flex: 4,
                                  child: heading(t.payeesColumnFiled),
                                ),
                                const SizedBox(width: _PayeeLine.endWidth),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: Mid.rule),
                          Flexible(
                            child: ListView(
                              shrinkWrap: true,
                              padding: const EdgeInsets.only(bottom: 8),
                              children: [
                                ?editor,
                                for (final r in rules)
                                  if (_open == r.id)
                                    _PayeeEditor(
                                      key: ValueKey('payee-edit-${r.id}'),
                                      data: data,
                                      today: widget.today,
                                      pays: widget.pays,
                                      rule: r,
                                      draft: _keep.of(r, data),
                                      onCancel: closeEdit,
                                      menus: _menus,
                                      onSave: (after) async {
                                        final saved = await widget.actions.save(
                                          r,
                                          after,
                                        );
                                        if (saved && mounted) closeEdit();
                                        return saved;
                                      },
                                      onDelete: () {
                                        closeEdit();
                                        _deleted(rules, r);
                                      },
                                    )
                                  else
                                    _PayeeLine(
                                      key: ValueKey('payee-${r.id}'),
                                      rule: r,
                                      data: data,
                                      pays: widget.pays,
                                      showAccounts: accounts,
                                      focusNode: _focusOf(r.id),
                                      onOpen: () {
                                        if (!_openLine(r.id)) {
                                          widget.actions.unsaved();
                                        }
                                      },
                                      onDelete: () => _deleted(rules, r),
                                    ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A payee as a closed line: the sentence, its accounts, its category, and
/// Delete. A click opens its Edit.
class _PayeeLine extends StatelessWidget {
  const _PayeeLine({
    super.key,
    required this.rule,
    required this.data,
    required this.pays,
    required this.showAccounts,
    required this.onOpen,
    required this.onDelete,
    this.focusNode,
  });
  final FocusNode? focusNode;
  final PayeeRuleInfo rule;
  final LedgerData data;
  final List<({int id, int accountId, String label})> pays;
  final bool showAccounts;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  static const endWidth = 84.0;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Hoverable(
      onTap: onOpen,
      focusNode: focusNode,
      builder: (hover) => Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: hover ? Mid.rowHover : Colors.transparent,
        child: Row(
          children: [
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, right: 16),
                // Its name in ink, how the bank writes it quiet after it;
                // with no name, each spelling as a sentence.
                child: rule.shownAs.trim().isNotEmpty
                    ? Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: rule.shownAs.trim(),
                              style: onest(14, weight: 600, color: Mid.ink),
                            ),
                            TextSpan(
                              text:
                                  '   ${rule.spellings.map((s) => s.text).join(' · ')}',
                              style: onest(13, color: Mid.ink3),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : _Quoted(
                        [
                          for (final s in rule.spellings)
                            switch (s.how) {
                              PayeeMatch.contains => t.payeesHasAnywhere(
                                s.text,
                              ),
                              PayeeMatch.starts => t.payeesStartsWith(s.text),
                              PayeeMatch.exactly => t.payeesIsExactly(s.text),
                            },
                        ].join(' · '),
                      ),
              ),
            ),
            if (showAccounts)
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    _accountsLabel(t, data, rule.accountIds),
                    style: onest(13.5, color: Mid.ink2),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            Expanded(
              flex: 4,
              child: Align(
                alignment: Alignment.centerLeft,
                // Part of the line, which opens the Edit: not a Tab stop of
                // its own, and no ▾ (it isn't a list).
                child: ExcludeFocus(
                  child: CategoryChip(
                    label: _ruleLabel(t, data, rule, pays),
                    open: false,
                    onTap: onOpen,
                    arrow: false,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: endWidth,
              child: Align(
                alignment: Alignment.centerRight,
                // Quiet: red is for a shortfall, and a page of red buttons
                // reads as one (Undo puts a payee back).
                child: BarButton(
                  key: const ValueKey('payee-delete'),
                  label: t.payeesDelete,
                  onTap: onDelete,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A payee's Edit, in the list where its line was (the owner's pick,
/// 2026-11-18, sketch A, "the payee's card"): the name the ledger shows as
/// the heading; on the left how the bank writes it, a line per spelling
/// with how it is looked for and how many rows it finds, then Accounts
/// (with more than one) and Category; on the right one row as the bank
/// sends it and the same row as the ledger will show it. Enter saves, Esc
/// and Cancel close it.
class _PayeeEditor extends StatefulWidget {
  const _PayeeEditor({
    super.key,
    required this.data,
    required this.today,
    required this.pays,
    required this.onCancel,
    required this.onSave,
    required this.draft,
    this.rule,
    this.onDelete,
    this.menus,
  });

  /// Told how to close a dropdown open in the Edit, so Esc from anywhere
  /// closes that before the Edit; and when that one is gone ([gone]).
  final void Function(bool Function()? close, bool Function()? gone)? menus;

  /// What's typed, held by the screen so another page or ⌘N doesn't lose it.
  final _PayeeDraft draft;
  final LedgerData data;
  final DateTime today;
  final List<({int id, int accountId, String label})> pays;

  /// The payee being changed; null for a new one.
  final PayeeRuleInfo? rule;
  final VoidCallback onCancel;

  /// False when a spelling is another line's: its field is marked.
  final Future<bool> Function(PayeeRuleInfo after) onSave;
  final VoidCallback? onDelete;

  @override
  State<_PayeeEditor> createState() => _PayeeEditorState();
}

class _PayeeEditorState extends State<_PayeeEditor> {
  _PayeeDraft get _d => widget.draft;
  TextEditingController get _name => _d.name;
  List<_SpellingDraft> get _spellings => _d.spellings;
  Set<int> get _accounts => _d.accounts;
  int? get _categoryId => _d.categoryId;
  set _categoryId(int? v) => _d.categoryId = v;
  int? get _payId => _d.payId;
  set _payId(int? v) => _d.payId = v;

  /// Save found a spelling to be another line's.
  bool get _clash => _d.clash;
  set _clash(bool v) => _d.clash = v;

  /// Save was tried: what's missing is said.
  bool get _tried => _d.tried;
  set _tried(bool v) => _d.tried = v;
  final _nameFocus = FocusNode(debugLabel: 'payee-name');
  final _categoryFocus = FocusNode(debugLabel: 'payee-category');
  final _panelFocus = FocusNode(debugLabel: 'payee-edit', skipTraversal: true);
  final _accountsMenu = MenuController();
  final _categoryMenu = MenuController();
  bool _saving = false;

  /// The spellings with something typed in them.
  List<PayeeSpelling> get _typed => [
    for (final s in _spellings)
      if (s.spelling.words.isNotEmpty) s.spelling,
  ];

  Set<Currency> get _currencies => {
    for (final a in widget.data.balanceSheetAccounts)
      if (_accounts.contains(a.id)) a.currency,
  };

  @override
  void initState() {
    super.initState();
    // Opened low in the list: its Cancel and Save come into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 180),
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
    _nameFocus.addListener(_keepKeys);
    widget.menus?.call(_closeMenu, null);
  }

  /// The field gave the keys up to nothing in particular (a click on a
  /// choice in a dropdown): the panel takes them, so Enter still saves and
  /// Esc still closes. Not when something else asked for them.
  void _keepKeys() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final has = FocusManager.instance.primaryFocus;
      if (has == null || has is FocusScopeNode) _panelFocus.requestFocus();
    });
  }

  /// After a pick in Category the keys go back to it, so Tab goes on to
  /// Cancel and Save, and Enter still saves and Esc closes (the panel's).
  void _takeKeys() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_inField) _categoryFocus.requestFocus();
      });
      // That second frame comes now, not with the next key: a Tab pressed
      // straight after the pick would otherwise be undone by it.
      WidgetsBinding.instance.ensureVisualUpdate();
    });
  }

  /// The cursor is in the name or a spelling.
  bool get _inField =>
      _nameFocus.hasFocus || _spellings.any((s) => s.focus.hasFocus);

  /// Closes a dropdown that's open in the panel: Esc is its own before it
  /// is the panel's.
  bool _closeMenu() {
    for (final m in [
      _accountsMenu,
      _categoryMenu,
      for (final s in _spellings) s.menu,
    ]) {
      if (m.isOpen) {
        m.close();
        return true;
      }
    }
    return false;
  }

  bool get _menuOpen =>
      _accountsMenu.isOpen ||
      _categoryMenu.isOpen ||
      _spellings.any((s) => s.menu.isOpen);

  /// Something typed in the name or a spelling: a line for the next
  /// spelling is always there, empty, after the last.
  void _onTyped() => setState(() {
    _clash = false;
    _d.tidy();
  });

  @override
  void dispose() {
    // Only its own: a new Edit may have told the page its own already.
    widget.menus?.call(null, _closeMenu);
    _nameFocus.dispose();
    _categoryFocus.dispose();
    _panelFocus.dispose();
    super.dispose();
  }

  /// The categories a payee on these accounts can go to: those every
  /// account's currency takes, so a dollar row never lands in a tugrik
  /// category (code review, 2026-10-26); spending first, Income last.
  List<AccountInfo> _categories() {
    final currencies = _currencies;
    final all = widget.data.categories.where(
      (c) =>
          !isUncategorized(c) && currencies.every((x) => categoryTakes(c, x)),
    );
    return [...all.where((c) => !c.isIncome), ...all.where((c) => c.isIncome)];
  }

  /// An account ticked or not: a pay paid into one no longer ticked, or a
  /// category the accounts' currencies don't all take, is let go.
  void _tick(int id) => setState(() {
    _accounts.contains(id) ? _accounts.remove(id) : _accounts.add(id);
    final pay = widget.data.payScheduleById(_payId);
    if (pay != null && !_accounts.contains(pay.accountId)) _payId = null;
    final c = widget.data.accounts[_categoryId];
    if (c != null && !_currencies.every((x) => categoryTakes(c, x))) {
      _categoryId = null;
      _payId = null;
    }
  });

  Future<void> _save() async {
    if (_saving) return;
    // Nothing changed: nothing to remember again, no popup, no empty undo.
    if (widget.rule != null && !_d.changed) return widget.onCancel();
    final category = _categoryId;
    final spellings = _typed;
    if (spellings.isEmpty || category == null || _accounts.isEmpty) {
      setState(() => _tried = true);
      return;
    }
    final after =
        widget.rule?.copyWith(
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
          accountIds: _accounts,
        );
    setState(() => _saving = true);
    try {
      final saved = await widget.onSave(after);
      if (!saved && mounted) setState(() => _clash = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The payee another line already goes by [s] on one of these accounts,
  /// as its category names it; null when it is free. A twin of this line
  /// (the same payee remembered on two computers) isn't another's.
  String? _takenBy(Words t, PayeeSpelling s) {
    final mine = widget.rule;
    final probe = PayeeRuleInfo(
      id: mine?.id ?? -1,
      spellings: [s],
      categoryId: 0,
      accountIds: _accounts,
    );
    for (final x in widget.data.payeeRules) {
      if (x.id == mine?.id || x.deleted) continue;
      if (mine != null && x.sameSpellings(mine)) continue;
      if (probe.sharedWith(x) != null) {
        return _ruleLabel(t, widget.data, x, widget.pays);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final data = widget.data;
    final open = data.openAccounts;
    final typed = _typed;
    final name = _name.text.trim();
    final probe = PayeeRuleInfo(
      // This line's own id, so it isn't counted as losing to itself.
      id: widget.rule?.id ?? -1,
      spellings: typed,
      shownAs: name,
      categoryId: _categoryId ?? 0,
      payId: _payId,
      accountIds: _accounts,
    );
    final rows = typed.isEmpty ? const <RegisterRow>[] : _fitting(data, probe);
    final holding = data.categories.where(isUncategorized).firstOrNull?.id;
    // The ones the button after Save would file: money in only, for a pay.
    final waiting = _waitingOf(data, rows, probe, widget.today);
    final already = rows.where((r) => r.categoryId == _categoryId).length;
    final elsewhere = rows
        .where((r) => r.categoryId != holding && r.categoryId != _categoryId)
        .length;
    final pays = [
      for (final p in widget.pays)
        if (_accounts.contains(p.accountId)) p,
    ];
    final category = data.accounts[_categoryId];
    final categoryLabel =
        pays.where((p) => p.id == _payId).firstOrNull?.label ?? category?.name;
    // The row drawn: one still under the bank's own words if there is one
    // (a row that shows the name already has them in its memo); of those,
    // one still waiting, else one in the category, else the newest.
    final shown = payeeWords(name);
    bool named(RegisterRow r) =>
        shown.isNotEmpty && payeeWords(r.txnPayee ?? '') == shown;
    final plain = rows.where((r) => !named(r)).toList();
    final from = plain.isEmpty ? rows : plain;
    final example =
        waiting.where(from.contains).lastOrNull ??
        from.where((r) => r.categoryId == _categoryId).lastOrNull ??
        from.lastOrNull;
    final exampleAccount = example == null
        ? null
        : data.accounts[example.accountId];
    // What the bank wrote: the row's payee, or its memo once the row shows
    // the name; with no row yet, the first spelling as typed.
    final bankPayee = example == null
        ? typed.firstOrNull?.text
        : named(example)
        ? (example.memo.trim().isEmpty ? example.txnPayee : example.memo)
        : example.txnPayee;
    final bankMemo = example == null || named(example) ? null : example.memo;
    final ledgerPayee = name.isEmpty ? bankPayee : name;
    final ledgerMemo = name.isEmpty
        ? bankMemo
        : memoKeeping(bankPayee, bankMemo);
    final missing = <String>[
      if (_tried && typed.isEmpty) t.payeesNeedsWords,
      if (_tried && _accounts.isEmpty) t.payeesNeedsAccount,
      if (_tried && _categoryId == null) t.payeesNeedsCategory,
    ];
    final fits = typed.isEmpty
        ? t.payeesNeedsWords
        : _accounts.isEmpty
        ? t.payeesNeedsAccount
        : [
            t.payeesFitsTotal(rows.length),
            if (waiting.isNotEmpty) t.payeesWaiting(waiting.length),
            // In Not categorized but not filed by Save's offer: an earlier
            // period's, or one another line takes.
            if (rows.where((r) => r.categoryId == holding).length -
                    waiting.length
                case final stay when stay > 0)
              t.payeesWaitingStay(stay),
            if (already > 0 && categoryLabel != null)
              t.payeesAlreadyIn(already, categoryLabel),
            if (elsewhere > 0) t.payeesElsewhere(elsewhere),
          ].join(' · ');

    String howLabel(PayeeMatch how) => switch (how) {
      PayeeMatch.contains => t.payeesHowContains,
      PayeeMatch.starts => t.payeesHowStarts,
      PayeeMatch.exactly => t.payeesHowExactly,
    };

    Widget spellingLine(int i) {
      final s = _spellings[i];
      final sp = s.spelling;
      final empty = sp.words.isEmpty;
      final taken = empty ? null : _takenBy(t, sp);
      final count = empty || _accounts.isEmpty
          ? null
          : _fitting(
              data,
              PayeeRuleInfo(
                id: -1,
                spellings: [sp],
                categoryId: 0,
                accountIds: _accounts,
              ),
            ).length;
      // The first is "payee-words", as the one field was.
      final suffix = i == 0 ? '' : '-$i';
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            FocusTraversalOrder(
              order: NumericFocusOrder(2 + i * 0.01),
              child: MenuAnchor(
                controller: s.menu,
                style: _menuStyle,
                onOpen: () => setState(() {}),
                onClose: () {
                  if (mounted) setState(() {});
                },
                menuChildren: focusFirstOnKeys([
                  for (final how in PayeeMatch.values)
                    MenuItemButton(
                      key: ValueKey('payee-how$suffix-${how.name}'),
                      onPressed: () {
                        setState(() => s.how = how);
                        s.focus.requestFocus();
                      },
                      style: ButtonStyle(
                        minimumSize: const WidgetStatePropertyAll(
                          Size(150, 34),
                        ),
                        overlayColor: WidgetStatePropertyAll(Mid.blueWash),
                      ),
                      trailingIcon: s.how == how
                          ? Icon(Icons.check_rounded, size: 14, color: Mid.blue)
                          : null,
                      child: Text(
                        howLabel(how),
                        style: onest(
                          13,
                          color: s.how == how ? Mid.ink : Mid.ink2,
                        ),
                      ),
                    ),
                ]),
                child: SizedBox(
                  width: 124,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: BarButton(
                      key: ValueKey('payee-how$suffix'),
                      label: howLabel(s.how),
                      color: empty ? Mid.ink3 : null,
                      trailing: Icons.expand_more_rounded,
                      active: s.menu.isOpen,
                      onTap: () =>
                          s.menu.isOpen ? s.menu.close() : s.menu.open(),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: FocusTraversalOrder(
                order: NumericFocusOrder(2 + i * 0.01 + 0.001),
                child: TextField(
                  key: ValueKey('payee-words$suffix'),
                  controller: s.text,
                  focusNode: s.focus,
                  style: onest(14, weight: 500),
                  onChanged: (_) => _onTyped(),
                  onSubmitted: (_) => _save(),
                  decoration: _fieldDecoration(
                    hint: i == 0 && _spellings.length == 1
                        ? t.payeesSpellingFirstHint
                        : t.payeesSpellingHint,
                    wrong:
                        taken != null ||
                        (_clash && !empty) ||
                        (_tried && typed.isEmpty && i == 0),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 116,
              child: taken != null
                  ? Text(
                      t.payeesSpellingTaken(taken),
                      key: ValueKey('payee-taken$suffix'),
                      style: onest(12.5, color: Mid.coral),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  : count == null
                  ? const SizedBox.shrink()
                  : Text(
                      t.payeesSpellingRows(count),
                      key: ValueKey('payee-rows$suffix'),
                      style: onest(13, color: Mid.ink2),
                    ),
            ),
            SizedBox(
              width: 32,
              // The empty line at the foot is the place for the next one:
              // nothing to remove.
              child: empty && i == _spellings.length - 1
                  ? null
                  : FocusTraversalOrder(
                      order: NumericFocusOrder(2 + i * 0.01 + 0.002),
                      child: Tooltip(
                        message: t.payeesRemoveSpelling,
                        child: Hoverable(
                          key: ValueKey('payee-remove$suffix'),
                          onTap: () => setState(() {
                            _clash = false;
                            _d.remove(s);
                          }),
                          builder: (hover) => Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: hover ? Mid.raised : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 15,
                              color: Mid.ink3,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    // One row of the preview: as the bank sends it (quiet, no category),
    // or as the ledger shows it.
    Widget strip({
      required String label,
      required String? payee,
      required String? memo,
      required bool ledger,
      required Key key,
    }) => Container(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        color: ledger ? Mid.ground : Mid.ground.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: onest(11.5, color: Mid.ink3)),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Row(
              children: [
                if (example != null) ...[
                  SizedBox(
                    width: 92,
                    child: Text(
                      fullDate(example.date),
                      style: onest(13, color: ledger ? Mid.ink2 : Mid.ink3),
                    ),
                  ),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payee ?? '',
                        style: onest(
                          14,
                          weight: ledger ? 600 : 400,
                          color: ledger ? Mid.ink : Mid.ink2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((memo ?? '').trim().isNotEmpty)
                        Text(
                          memo!,
                          style: onest(12, color: Mid.ink3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (ledger && (categoryLabel ?? example?.categoryLabel) != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 170),
                      // A picture of the row: no Tab stop, no pointer, no ▾.
                      child: ExcludeFocus(
                        child: IgnorePointer(
                          child: CategoryChip(
                            label: categoryLabel ?? example!.categoryLabel,
                            open: false,
                            onTap: () {},
                            arrow: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (example != null && exampleAccount != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Money(
                      example.amount,
                      size: 14,
                      currency: exampleAccount.currency,
                      sign: MoneySign.plusForPositive,
                      color: ledger ? null : Mid.ink2,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        SingleActivator(LogicalKeyboardKey.enter): _SaveIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              if (!_closeMenu()) widget.onCancel();
              return null;
            },
          ),
          // With a list open, Enter is its item's (code review, 2026-10-26).
          _SaveIntent: _WhenNoMenu(() => !_menuOpen, _save),
        },
        child: Focus(
          focusNode: _panelFocus,
          skipTraversal: true,
          // A click in the panel leaves the cursor where it is, and isn't a
          // click away from it.
          child: TextFieldTapRegion(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Container(
                key: const ValueKey('payee-editor'),
                margin: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  color: Mid.blueWash,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Mid.blueEdge),
                ),
                // Tab goes round the Edit and stays in it: the name, each
                // spelling, Accounts, Category, Cancel, Save, then Delete
                // (#284).
                child: FocusScope(
                  child: FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.payeesNameLabel,
                          style: onest(12.5, color: Mid.ink2),
                        ),
                        const SizedBox(height: 5),
                        SizedBox(
                          width: 440,
                          child: FocusTraversalOrder(
                            order: const NumericFocusOrder(1),
                            child: TextField(
                              key: const ValueKey('payee-name'),
                              controller: _name,
                              focusNode: _nameFocus,
                              autofocus: true,
                              style: onest(19, weight: 700),
                              onChanged: (_) => _onTyped(),
                              onSubmitted: (_) => _save(),
                              decoration: _fieldDecoration(
                                hint: t.payeesNameHint,
                              ).copyWith(hintStyle: onest(19, color: Mid.ink3)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.payeesSpellingsLabel,
                                    style: onest(12.5, color: Mid.ink2),
                                  ),
                                  for (var i = 0; i < _spellings.length; i++)
                                    spellingLine(i),
                                  const SizedBox(height: 16),
                                  if (open.length > 1)
                                    _FormLine(
                                      label: t.payeesColumnAccounts,
                                      child: FocusTraversalOrder(
                                        order: const NumericFocusOrder(4),
                                        child: MenuAnchor(
                                          controller: _accountsMenu,
                                          style: _menuStyle,
                                          onOpen: () => setState(() {}),
                                          onClose: () {
                                            if (mounted) setState(() {});
                                          },
                                          menuChildren: focusFirstOnKeys([
                                            // An archived one it still holds
                                            // on is listed, so it can be
                                            // unticked.
                                            for (final a in [
                                              ...open,
                                              for (final x
                                                  in data.balanceSheetAccounts)
                                                if (x.archived &&
                                                    _accounts.contains(x.id))
                                                  x,
                                            ])
                                              MenuItemButton(
                                                key: ValueKey(
                                                  'payee-account-${a.id}',
                                                ),
                                                closeOnActivate: false,
                                                onPressed: () => _tick(a.id),
                                                style: ButtonStyle(
                                                  minimumSize:
                                                      const WidgetStatePropertyAll(
                                                        Size(320, 34),
                                                      ),
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  padding:
                                                      const WidgetStatePropertyAll(
                                                        EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 8,
                                                        ),
                                                      ),
                                                  overlayColor:
                                                      WidgetStatePropertyAll(
                                                        Mid.blueWash,
                                                      ),
                                                ),
                                                leadingIcon: Icon(
                                                  _accounts.contains(a.id)
                                                      ? Icons.check_box_rounded
                                                      : Icons
                                                            .check_box_outline_blank_rounded,
                                                  size: 18,
                                                  color:
                                                      _accounts.contains(a.id)
                                                      ? Mid.blue
                                                      : Mid.ink3,
                                                ),
                                                child: Text(
                                                  a.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: onest(
                                                    13,
                                                    color:
                                                        _accounts.contains(a.id)
                                                        ? Mid.ink
                                                        : Mid.ink2,
                                                  ),
                                                ),
                                              ),
                                          ]),
                                          child: BarButton(
                                            key: const ValueKey(
                                              'payee-accounts',
                                            ),
                                            label: _accounts.isEmpty
                                                ? t.payeesNeedsAccount
                                                : _accountsLabel(
                                                    t,
                                                    data,
                                                    _accounts,
                                                  ),
                                            color: _tried && _accounts.isEmpty
                                                ? Mid.coral
                                                : null,
                                            trailing: Icons.expand_more_rounded,
                                            active: _accountsMenu.isOpen,
                                            onTap: () => _accountsMenu.isOpen
                                                ? _accountsMenu.close()
                                                : _accountsMenu.open(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  _FormLine(
                                    label: t.payeesColumnFiled,
                                    child: FocusTraversalOrder(
                                      order: const NumericFocusOrder(5),
                                      child: CategoryMenu(
                                        controller: _categoryMenu,
                                        consumeOutsideTap: true,
                                        leading: [
                                          for (final p in pays)
                                            (
                                              label: p.label,
                                              onTap: () {
                                                setState(() {
                                                  _payId = p.id;
                                                  _categoryId = data.income?.id;
                                                });
                                                _takeKeys();
                                              },
                                            ),
                                        ],
                                        categories: _categories(),
                                        current: categoryLabel,
                                        onPicked: (c) {
                                          setState(() {
                                            _categoryId = c.id;
                                            _payId = null;
                                          });
                                          _takeKeys();
                                        },
                                        builder: (menuOpen, toggle) =>
                                            CategoryChip(
                                              key: const ValueKey(
                                                'payee-category',
                                              ),
                                              focusNode: _categoryFocus,
                                              // Not the label beside it
                                              // again: what to do.
                                              label:
                                                  categoryLabel ??
                                                  t.payeesNeedsCategory,
                                              open: menuOpen,
                                              onTap: toggle,
                                            ),
                                      ),
                                    ),
                                  ),
                                  if (missing.isNotEmpty)
                                    Text(
                                      missing.join(' · '),
                                      key: const ValueKey('payee-missing'),
                                      style: onest(13, color: Mid.coral),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 32),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (bankPayee != null) ...[
                                    Text(
                                      t.payeesNextFromBank,
                                      style: onest(12.5, color: Mid.ink2),
                                    ),
                                    const SizedBox(height: 6),
                                    strip(
                                      key: const ValueKey('payee-bank-row'),
                                      label: t.payeesAsBankSends,
                                      payee: bankPayee,
                                      memo: bankMemo,
                                      ledger: false,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 3,
                                      ),
                                      child: Icon(
                                        Icons.arrow_downward_rounded,
                                        size: 16,
                                        color: Mid.blue,
                                      ),
                                    ),
                                    strip(
                                      key: const ValueKey('payee-example'),
                                      label: t.payeesAsLedgerShows,
                                      payee: ledgerPayee,
                                      memo: ledgerMemo,
                                      ledger: true,
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  // Not when the red line beside it says
                                  // the same.
                                  if (!missing.contains(fits))
                                    Text(
                                      fits,
                                      key: const ValueKey('payee-fits'),
                                      style: onest(
                                        13,
                                        color: typed.isEmpty
                                            ? Mid.ink3
                                            : Mid.ink2,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            // Quiet, beside the other two: Undo puts a
                            // payee back.
                            if (widget.onDelete case final del?)
                              BarButton(
                                key: const ValueKey('payee-edit-delete'),
                                label: t.payeesDelete,
                                onTap: del,
                              ),
                            const Spacer(),
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(6),
                              child: BarButton(
                                key: const ValueKey('payee-cancel'),
                                label: t.planCancel,
                                onTap: widget.onCancel,
                              ),
                            ),
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(7),
                              child: _PrimaryButton(
                                key: const ValueKey('payee-save'),
                                label: t.planSave,
                                icon: Icons.check_rounded,
                                tooltip: 'Enter',
                                onTap: _save,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}

/// [run], but only while [enabled]: otherwise the key goes on, to an open
/// list's item.
class _WhenNoMenu extends Action<_SaveIntent> {
  _WhenNoMenu(this.enabled, this.run);
  final bool Function() enabled;
  final VoidCallback run;

  @override
  bool isEnabled(_SaveIntent intent) => enabled();

  @override
  Object? invoke(_SaveIntent intent) {
    run();
    return null;
  }
}

/// One spelling being typed in a payee's Edit.
class _SpellingDraft {
  _SpellingDraft([PayeeSpelling? s])
    // A new one is looked for anywhere: where a bank row has the shop's
    // name is the bank's choice, in the middle as often as at the start.
    : how = s?.how ?? PayeeMatch.contains,
      text = TextEditingController(text: s?.text ?? '');

  PayeeMatch how;
  final TextEditingController text;
  final menu = MenuController();
  final focus = FocusNode(debugLabel: 'payee-spelling');

  PayeeSpelling get spelling => PayeeSpelling(how, text.text.trim());

  void dispose() {
    text.dispose();
    focus.dispose();
  }
}

/// What's typed in a payee's Edit: kept by the screen while the page is
/// left (as Budget keeps its Edit, #272), and compared with how it opened.
class _PayeeDraft {
  _PayeeDraft(PayeeRuleInfo? rule, LedgerData data)
    : id = rule?.id,
      name = TextEditingController(text: rule?.shownAs ?? ''),
      spellings = [
        for (final s in rule?.spellings ?? const <PayeeSpelling>[])
          _SpellingDraft(s),
      ],
      // Nothing is filled in for them (owner: no autofill); with one
      // account there is no choice to make. A deleted account isn't kept
      // unseen: it couldn't be unticked.
      accounts = {
        for (final id in rule?.accountIds ?? const <int>{})
          if (data.accounts[id] case final a? when !a.deleted) id,
        if (rule == null && data.openAccounts.length == 1)
          data.openAccounts.single.id,
      },
      categoryId = rule?.categoryId,
      payId = rule?.payId {
    tidy();
    _start = _now;
  }

  /// The payee's id; null for a new one.
  final int? id;

  /// The name the ledger shows.
  final TextEditingController name;

  /// Each way it is written; the last is always empty, the place for the
  /// next.
  final List<_SpellingDraft> spellings;
  final Set<int> accounts;
  int? categoryId;
  int? payId;
  bool clash = false;
  bool tried = false;
  late final String _start;

  /// Keeps one empty line after the last spelling, and only one.
  void tidy() {
    bool empty(_SpellingDraft s) => s.text.text.trim().isEmpty;
    while (spellings.length > 1 &&
        empty(spellings.last) &&
        empty(spellings[spellings.length - 2]) &&
        !spellings.last.focus.hasFocus) {
      spellings.removeLast().dispose();
    }
    if (spellings.isEmpty || !empty(spellings.last)) {
      spellings.add(_SpellingDraft());
    }
  }

  /// A spelling taken off its line.
  void remove(_SpellingDraft s) {
    if (spellings.remove(s)) {
      // After the frame: its field is still on screen in this one.
      WidgetsBinding.instance.addPostFrameCallback((_) => s.dispose());
    }
    tidy();
  }

  String get _now =>
      '${name.text}|'
      '${[for (final s in spellings)
        if (s.text.text.trim().isNotEmpty) '${s.how.name}:${s.text.text}'].join('\n')}|'
      '${(accounts.toList()..sort()).join(',')}|'
      '$categoryId|$payId';

  /// Something was changed since it opened.
  bool get changed => _now != _start;

  void dispose() {
    name.dispose();
    for (final s in spellings) {
      s.dispose();
    }
  }
}

/// Which Edit is open on the Payees page and what's typed in it, held by
/// the screen across pages.
class _PayeeKeep {
  /// The payee whose Edit is open, or null; [adding] for a new one.
  int? open;
  bool adding = false;
  _PayeeDraft? draft;

  /// The draft for [rule] (null: a new payee), made when it opens.
  _PayeeDraft of(PayeeRuleInfo? rule, LedgerData data) {
    final d = draft;
    if (d != null && d.id == rule?.id) return d;
    clear();
    return draft = _PayeeDraft(rule, data);
  }

  /// Something typed would be lost by opening another.
  bool get dirty => draft?.changed ?? false;

  void close() {
    open = null;
    adding = false;
    clear();
  }

  /// A frame later: the fields may still be on screen this frame.
  void clear() {
    final d = draft;
    if (d == null) return;
    draft = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => d.dispose());
  }
}
