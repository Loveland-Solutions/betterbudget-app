part of 'ledger_screen.dart';

// The Payees section (owner, 2026-10-12: "I don't want to hide this… it
// deserves its own dedicated section", then "Let's make this a real
// feature"): every payee the app remembers a category for, each a line that
// reads as a sentence and opens into its Edit (ADR 0004 "Payees: the real
// feature", layout B). The rules are [PayeeRuleInfo] rows; the screen
// records each change for undo.

/// What the page changes.
class _PayeesActions {
  const _PayeesActions({required this.save, required this.delete});

  /// A payee saved from its Edit: new ([before] null) or changed. False
  /// when it wasn't saved (the words are another line's): the Edit stays.
  final Future<bool> Function(PayeeRuleInfo? before, PayeeRuleInfo after) save;
  final Future<void> Function(PayeeRuleInfo rule) delete;
}

/// The posted rows of [accounts] a payee with these [words] fits.
List<RegisterRow> _fitting(
  LedgerData data,
  String words,
  bool anywhere,
  Set<int> accounts,
) {
  if (words.isEmpty) return const [];
  final probe = PayeeRuleInfo(
    id: 0,
    words: words,
    name: words,
    anywhere: anywhere,
    categoryId: 0,
    accountIds: accounts,
  );
  return [
    for (final a in data.openAccounts)
      if (accounts.contains(a.id))
        for (final r in data.registerFor(a.id).posted)
          if (r.kind == RowKind.simple && probe.fits(r.txnPayee, r.memo)) r,
  ];
}

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
) => _waitingOf(
  data,
  _fitting(data, rule.words, rule.anywhere, rule.accountIds),
  rule,
  today,
);

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

String _dayText(DateTime d) {
  String two(int n) => n < 10 ? '0$n' : '$n';
  return '${d.year}.${two(d.month)}.${two(d.day)}';
}

/// A sentence with the payee's words in «…»: the words in ink, the rest
/// quiet, whatever order the language puts them in.
class _Quoted extends StatelessWidget {
  const _Quoted(this.text);
  final String text;
  static const size = 14.0;

  @override
  Widget build(BuildContext context) {
    final a = text.indexOf('«'), b = text.lastIndexOf('»');
    final quiet = onest(size - 1, color: Mid.ink3);
    if (a < 0 || b < a) return Text(text, style: quiet);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, a), style: quiet),
          TextSpan(
            text: text.substring(a, b + 1),
            style: onest(size, weight: 500, color: Mid.ink),
          ),
          TextSpan(text: text.substring(b + 1), style: quiet),
        ],
      ),
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
  });
  final LedgerData data;
  final DateTime today;

  /// Each pay as a row's dropdown names it.
  final List<({int id, int accountId, String label})> pays;
  final _PayeesActions actions;

  @override
  State<_PayeesPage> createState() => _PayeesPageState();
}

class _PayeesPageState extends State<_PayeesPage> {
  /// The payee whose Edit is open, or null; [_adding] for a new one.
  int? _open;
  bool _adding = false;

  /// The open Edit's way to close a dropdown of its own, while it has one.
  bool Function()? _closeEditMenu;

  /// Esc reached the screen with an Edit open: a dropdown open in it closes
  /// first, else the Edit, as from inside. False with none open.
  bool closeEdit() {
    if (_open == null && !_adding) return false;
    if (_closeEditMenu?.call() ?? false) return true;
    setState(() {
      _open = null;
      _adding = false;
    });
    return true;
  }

  /// "+ Add a payee", and ⌘N on this page.
  void addNew() => setState(() {
    _open = null;
    _adding = true;
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final data = widget.data;
    final rules = [...data.payeeRules]
      ..sort((x, y) => x.words.compareTo(y.words));
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
            onCancel: closeEdit,
            menus: (close) => _closeEditMenu = close,
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
                    onTap: addNew,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
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
                                      onCancel: closeEdit,
                                      menus: (close) => _closeEditMenu = close,
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
                                        widget.actions.delete(r);
                                      },
                                    )
                                  else
                                    _PayeeLine(
                                      key: ValueKey('payee-${r.id}'),
                                      rule: r,
                                      data: data,
                                      pays: widget.pays,
                                      showAccounts: accounts,
                                      onOpen: () => setState(() {
                                        _adding = false;
                                        _open = r.id;
                                      }),
                                      onDelete: () => widget.actions.delete(r),
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
  });
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
                child: _Quoted(
                  rule.anywhere
                      ? t.payeesHasAnywhere(rule.name)
                      : t.payeesStartsWith(rule.name),
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
                child: CategoryChip(
                  label: _ruleLabel(t, data, rule, pays),
                  open: false,
                  onTap: onOpen,
                ),
              ),
            ),
            SizedBox(
              width: endWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: BarButton(
                  key: const ValueKey('payee-delete'),
                  label: t.payeesDelete,
                  color: Mid.coral,
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

/// A payee's Edit, in the list where its line was: the words as the
/// heading, Where, Accounts (with more than one), Category, how many rows
/// it fits in real numbers, and one of them drawn as it will read. Enter
/// saves, Esc and Cancel close it.
class _PayeeEditor extends StatefulWidget {
  const _PayeeEditor({
    super.key,
    required this.data,
    required this.today,
    required this.pays,
    required this.onCancel,
    required this.onSave,
    this.rule,
    this.onDelete,
    this.menus,
  });

  /// Told how to close a dropdown open in the Edit (null once it's gone),
  /// so Esc from anywhere closes that before the Edit.
  final void Function(bool Function()? close)? menus;
  final LedgerData data;
  final DateTime today;
  final List<({int id, int accountId, String label})> pays;

  /// The payee being changed; null for a new one.
  final PayeeRuleInfo? rule;
  final VoidCallback onCancel;

  /// False when the words are another line's: the field is marked.
  final Future<bool> Function(PayeeRuleInfo after) onSave;
  final VoidCallback? onDelete;

  @override
  State<_PayeeEditor> createState() => _PayeeEditorState();
}

class _PayeeEditorState extends State<_PayeeEditor> {
  late final _name = TextEditingController(text: widget.rule?.name ?? '');
  final _nameFocus = FocusNode(debugLabel: 'payee-words');
  final _panelFocus = FocusNode(debugLabel: 'payee-edit', skipTraversal: true);
  final _accountsMenu = MenuController();
  final _categoryMenu = MenuController();
  late bool _anywhere = widget.rule?.anywhere ?? false;

  /// Nothing is filled in for them (owner: no autofill); with one account
  /// there is no choice to make.
  late final Set<int> _accounts = {
    // A deleted account isn't kept unseen: it can't be unticked.
    for (final id in widget.rule?.accountIds ?? const <int>{})
      if (widget.data.accounts[id] case final a? when !a.deleted) id,
    if (widget.rule == null && widget.data.openAccounts.length == 1)
      widget.data.openAccounts.single.id,
  };

  /// Save found the words to be another line's.
  bool _clash = false;
  late int? _categoryId = widget.rule?.categoryId;
  late int? _payId = widget.rule?.payId;

  /// Save was tried: what's missing is said.
  bool _tried = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() => _clash = false));
    _nameFocus.addListener(_keepKeys);
    widget.menus?.call(_closeMenu);
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

  /// After a pick in a dropdown the keys are nobody's: the panel takes
  /// them, so Enter saves and Esc closes.
  void _takeKeys() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_nameFocus.hasFocus) _panelFocus.requestFocus();
      });
    });
  }

  /// Closes a dropdown that's open in the panel: Esc is its own before it
  /// is the panel's.
  bool _closeMenu() {
    for (final m in [_accountsMenu, _categoryMenu]) {
      if (m.isOpen) {
        m.close();
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    widget.menus?.call(null);
    _name.dispose();
    _nameFocus.dispose();
    _panelFocus.dispose();
    super.dispose();
  }

  String get _words => payeeWords(_name.text);

  Set<Currency> get _currencies => {
    for (final a in widget.data.balanceSheetAccounts)
      if (_accounts.contains(a.id)) a.currency,
  };

  /// The categories a payee on these accounts can go to: those every
  /// account's currency takes, so a dollar row never lands in a tugrik
  /// category (code review, 2026-10-26); spending first, Income last.
  List<AccountInfo> _categories() {
    final currencies = _currencies;
    final all = widget.data.categories.where(
      (c) => !isUncategorized(c) && currencies.every((x) => categoryTakes(c, x)),
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
    final category = _categoryId;
    if (_words.isEmpty || category == null || _accounts.isEmpty) {
      setState(() => _tried = true);
      return;
    }
    final after =
        widget.rule?.copyWith(
          words: _words,
          name: _name.text.trim(),
          anywhere: _anywhere,
          categoryId: category,
          payId: () => _payId,
          accountIds: _accounts,
        ) ??
        PayeeRuleInfo(
          id: 0,
          words: _words,
          name: _name.text.trim(),
          anywhere: _anywhere,
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

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final data = widget.data;
    final open = data.openAccounts;
    final words = _words;
    final rows = _fitting(data, words, _anywhere, _accounts);
    final holding = data.categories.where(isUncategorized).firstOrNull?.id;
    final probe = PayeeRuleInfo(
      // This line's own id, so it isn't counted as losing to itself.
      id: widget.rule?.id ?? -1,
      words: words,
      name: words,
      anywhere: _anywhere,
      categoryId: _categoryId ?? 0,
      payId: _payId,
      accountIds: _accounts,
    );
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
    // A row still waiting, else one already in the category: never one in
    // another category drawn as if it were moved (it won't be). The newest.
    final example =
        waiting.lastOrNull ??
        rows.where((r) => r.categoryId == _categoryId).lastOrNull;
    final exampleAccount = example == null
        ? null
        : data.accounts[example.accountId];
    final missing = <String>[
      if (_tried && words.isEmpty) t.payeesNeedsWords,
      if (_tried && _accounts.isEmpty) t.payeesNeedsAccount,
      if (_tried && _categoryId == null) t.payeesNeedsCategory,
    ];
    // What "at the start" misses that "anywhere" would take: said, so a
    // name the bank puts in the middle doesn't read as misspelt.
    final wouldAnywhere = !_anywhere && rows.isEmpty && words.isNotEmpty
        ? _fitting(data, words, true, _accounts).length
        : 0;
    final fits = words.isEmpty
        ? t.payeesNeedsWords
        : _accounts.isEmpty
        ? t.payeesNeedsAccount
        : [
            _anywhere
                ? t.payeesFitsAnywhere(rows.length)
                : t.payeesFitsStarts(rows.length),
            if (wouldAnywhere > 0) t.payeesAnywhereWould(wouldAnywhere),
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

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!_closeMenu()) widget.onCancel();
        },
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!_closeMenu()) _save();
        },
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: BoxDecoration(
                color: Mid.blueWash,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Mid.blueEdge),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        t.payeesWordsLabel,
                        style: onest(12, color: Mid.ink3),
                      ),
                      const Spacer(),
                      if (widget.onDelete case final del?)
                        BarButton(
                          key: const ValueKey('payee-edit-delete'),
                          label: t.payeesDelete,
                          color: Mid.coral,
                          onTap: del,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 420,
                    child: TextField(
                      key: const ValueKey('payee-words'),
                      controller: _name,
                      focusNode: _nameFocus,
                      autofocus: true,
                      style: onest(19, weight: 700),
                      onSubmitted: (_) => _save(),
                      decoration: _fieldDecoration(
                        wrong: (_tried && words.isEmpty) || _clash,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FormLine(
                    label: t.payeesWhere,
                    child: Row(
                      children: [
                        BarButton(
                          key: const ValueKey('payee-where-starts'),
                          label: t.payeesAtStart,
                          active: !_anywhere,
                          color: !_anywhere ? Mid.blue : Mid.ink2,
                          onTap: () => setState(() => _anywhere = false),
                        ),
                        BarButton(
                          key: const ValueKey('payee-where-anywhere'),
                          label: t.payeesAnywhere,
                          active: _anywhere,
                          color: _anywhere ? Mid.blue : Mid.ink2,
                          onTap: () => setState(() => _anywhere = true),
                        ),
                      ],
                    ),
                  ),
                  if (open.length > 1)
                    _FormLine(
                      label: t.payeesColumnAccounts,
                      child: MenuAnchor(
                        controller: _accountsMenu,
                        style: _menuStyle,
                        onOpen: () => setState(() {}),
                        onClose: () {
                          if (mounted) setState(() {});
                        },
                        menuChildren: focusFirstOnKeys([
                          // An archived one it still holds on is listed,
                          // so it can be unticked.
                          for (final a in [
                            ...open,
                            for (final x in data.balanceSheetAccounts)
                              if (x.archived && _accounts.contains(x.id)) x,
                          ])
                            MenuItemButton(
                              key: ValueKey('payee-account-${a.id}'),
                              closeOnActivate: false,
                              onPressed: () => _tick(a.id),
                              style: ButtonStyle(
                                minimumSize: const WidgetStatePropertyAll(
                                  Size(320, 34),
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const WidgetStatePropertyAll(
                                  EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                overlayColor: WidgetStatePropertyAll(
                                  Mid.blueWash,
                                ),
                              ),
                              leadingIcon: Icon(
                                _accounts.contains(a.id)
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                size: 18,
                                color: _accounts.contains(a.id)
                                    ? Mid.blue
                                    : Mid.ink3,
                              ),
                              child: Text(
                                a.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: onest(
                                  13,
                                  color: _accounts.contains(a.id)
                                      ? Mid.ink
                                      : Mid.ink2,
                                ),
                              ),
                            ),
                        ]),
                        child: BarButton(
                          key: const ValueKey('payee-accounts'),
                          label: _accounts.isEmpty
                              ? t.payeesNeedsAccount
                              : _accountsLabel(t, data, _accounts),
                          color: _tried && _accounts.isEmpty ? Mid.coral : null,
                          trailing: Icons.expand_more_rounded,
                          active: _accountsMenu.isOpen,
                          onTap: () => _accountsMenu.isOpen
                              ? _accountsMenu.close()
                              : _accountsMenu.open(),
                        ),
                      ),
                    ),
                  _FormLine(
                    label: t.payeesColumnFiled,
                    child: CategoryMenu(
                      controller: _categoryMenu,
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
                      builder: (menuOpen, toggle) => CategoryChip(
                        key: const ValueKey('payee-category'),
                        label: categoryLabel ?? t.payeesColumnFiled,
                        open: menuOpen,
                        onTap: toggle,
                      ),
                    ),
                  ),
                  Text(
                    fits,
                    key: const ValueKey('payee-fits'),
                    style: onest(
                      13,
                      color: words.isEmpty ? Mid.ink3 : Mid.ink2,
                    ),
                  ),
                  if (missing.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      missing.join(' · '),
                      key: const ValueKey('payee-missing'),
                      style: onest(13, color: Mid.coral),
                    ),
                  ],
                  if (example != null && exampleAccount != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      t.payeesHowRowReads,
                      style: onest(12, color: Mid.ink3),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      key: const ValueKey('payee-example'),
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      constraints: const BoxConstraints(maxWidth: 760),
                      decoration: BoxDecoration(
                        color: Mid.ground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 110,
                            child: Text(
                              _dayText(example.date),
                              style: onest(13.5, color: Mid.ink2),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  example.txnPayee ?? '',
                                  style: onest(14, weight: 500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (example.memo.trim().isNotEmpty)
                                  Text(
                                    example.memo,
                                    style: onest(12, color: Mid.ink3),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 160,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: CategoryChip(
                                label: categoryLabel ?? example.categoryLabel,
                                open: false,
                                onTap: () {},
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 140,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Money(
                                example.amount,
                                size: 14,
                                currency: exampleAccount.currency,
                                sign: MoneySign.plusForPositive,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Spacer(),
                      BarButton(
                        key: const ValueKey('payee-cancel'),
                        label: t.planCancel,
                        onTap: widget.onCancel,
                      ),
                      _PrimaryButton(
                        key: const ValueKey('payee-save'),
                        label: t.planSave,
                        icon: Icons.check_rounded,
                        tooltip: 'Enter',
                        onTap: _save,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
