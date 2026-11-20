part of 'phone_app.dart';

// The phone's Ledger tab is the register (#527, owner's pick of sketch C,
// ADR 0004 "The register on the phone"): every account's rows, newest first,
// narrowed to one account by the chip at the top, with the computer's filter
// tabs and a search. A tapped row opens where it is. Add a transaction opens
// the amount pad.

/// Which rows the tabs show.
enum _Show { all, uncleared, scheduled, uncategorized }

class _RegisterScreen extends StatefulWidget {
  const _RegisterScreen({
    required this.store,
    required this.now,
    required this.onAdd,
  });
  final PhoneStore store;
  final DateTime Function() now;

  /// Opens the amount pad.
  final VoidCallback onAdd;

  @override
  State<_RegisterScreen> createState() => _RegisterState();
}

class _RegisterState extends State<_RegisterScreen> {
  /// The account shown, or null for all of them.
  int? _account;
  var _show = _Show.all;
  var _searching = false;
  final _search = TextEditingController();

  /// The row opened in place, by its entry.
  ({int txn, int entry})? _open;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  LedgerData get _data => widget.store.snapshot.data!;

  ({List<RegisterRow> posted, List<RegisterRow> scheduled}) get _rows {
    final data = _data;
    final id = _account;
    // An account that is gone from the ledger shows all of them.
    return id != null && data.accounts.containsKey(id)
        ? data.registerFor(id)
        : data.registerAll();
  }

  int? get _uncategorizedId =>
      _data.categories.where(isUncategorized).firstOrNull?.id;

  bool _waiting(RegisterRow r) =>
      _uncategorizedId != null && r.categoryId == _uncategorizedId;

  bool _matches(Words t, RegisterRow r, String typed) {
    final want = typed.trim().toLowerCase();
    if (want.isEmpty) return true;
    final amount = formatMoney(r.amount.abs(), currency: r.currency);
    return [
      rowPayee(t, r),
      r.memo,
      rowCategory(t, r),
      amount,
    ].any((s) => s.toLowerCase().contains(want));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final rows = _rows;
        final waiting = rows.posted.where(_waiting).length;
        final unclear = rows.posted
            .where((r) => r.cleared == Cleared.uncleared)
            .length;
        // A tab is offered only while there's something for it.
        final shows = [
          _Show.all,
          if (unclear > 0) _Show.uncleared,
          if (rows.scheduled.isNotEmpty) _Show.scheduled,
          if (waiting > 0) _Show.uncategorized,
        ];
        final show = shows.contains(_show) ? _show : _Show.all;
        final shown = switch (show) {
          _Show.all => rows.posted.reversed.toList(),
          _Show.uncleared =>
            rows.posted.reversed
                .where((r) => r.cleared == Cleared.uncleared)
                .toList(),
          _Show.scheduled => rows.scheduled,
          _Show.uncategorized => rows.posted.reversed.where(_waiting).toList(),
        }.where((r) => _matches(t, r, _search.text)).toList();
        return Stack(
          children: [
            Column(
              children: [
                _top(t),
                if (shows.length > 1) _tabs(t, shows, show, waiting),
                Expanded(child: _list(t, shown)),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                key: const ValueKey('add-transaction'),
                backgroundColor: Mid.fill,
                foregroundColor: Mid.onFill,
                onPressed: widget.onAdd,
                icon: const Icon(Icons.add_rounded),
                label: Text(t.ledgerAdd, style: onest(16, weight: 600)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _top(Words t) {
    final accounts = widget.store.snapshot.accounts;
    final chosen = accounts
        .where((a) => a.id == '${_account ?? ''}')
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: SizedBox(
        height: 48,
        child: _searching
            ? Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('register-search'),
                      controller: _search,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      style: onest(16, color: Mid.ink),
                      cursorColor: Mid.blue,
                      decoration: InputDecoration(
                        hintText: t.ledgerSearchHint,
                        hintStyle: onest(16, color: Mid.ink3),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('register-search-close'),
                    icon: Icon(Icons.close_rounded, color: Mid.ink2),
                    onPressed: () => setState(() {
                      _searching = false;
                      _search.clear();
                    }),
                  ),
                ],
              )
            : Row(
                children: [
                  Text(
                    t.ledgerSectionLedger,
                    style: onest(22, weight: 600, color: Mid.ink),
                  ),
                  const Spacer(),
                  PopupMenuButton<int?>(
                    key: const ValueKey('register-account'),
                    color: Mid.raised,
                    onSelected: (id) => setState(() {
                      _account = id;
                      _open = null;
                    }),
                    itemBuilder: (_) => [
                      PopupMenuItem<int?>(
                        value: null,
                        child: Text(
                          t.ledgerAllAccounts,
                          style: onest(16, color: Mid.ink),
                        ),
                      ),
                      for (final a in accounts)
                        PopupMenuItem<int?>(
                          value: int.tryParse(a.id),
                          child: Text(a.name, style: onest(16, color: Mid.ink)),
                        ),
                    ],
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Mid.card,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              chosen?.name ?? t.ledgerAllAccounts,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: onest(15, weight: 600, color: Mid.ink),
                            ),
                          ),
                          Icon(Icons.arrow_drop_down_rounded, color: Mid.ink2),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('register-search-open'),
                    icon: Icon(Icons.search_rounded, color: Mid.ink2),
                    onPressed: () => setState(() => _searching = true),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _tabs(Words t, List<_Show> shows, _Show on, int waiting) {
    String name(_Show s) => switch (s) {
      _Show.all => t.rowsTabAll,
      _Show.uncleared => t.rowsTabUncleared,
      _Show.scheduled => t.rowsTabScheduled,
      _Show.uncategorized => '${t.rowsTabUncategorized} $waiting',
    };
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (final s in shows)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: ValueKey('register-tab-${s.name}'),
                label: Text(name(s), style: onest(14)),
                selected: s == on,
                showCheckmark: false,
                selectedColor: Mid.blue,
                backgroundColor: Mid.raised,
                labelStyle: onest(14, color: s == on ? Mid.onAccent : Mid.ink2),
                side: BorderSide.none,
                onSelected: (_) => setState(() {
                  _show = s;
                  _open = null;
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _list(Words t, List<RegisterRow> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final today = widget.now();
    final children = <Widget>[];
    DateTime? day;
    for (final r in rows) {
      final d = DateTime(r.date.year, r.date.month, r.date.day);
      if (day != d) {
        day = d;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              DateTime(today.year, today.month, today.day) == d
                  ? t.today
                  : shortDate(d),
              style: onest(13, weight: 500, color: Mid.ink2),
            ),
          ),
        );
      }
      children.add(_row(t, r));
    }
    return ListView(
      key: const ValueKey('register-list'),
      // Room for Add under the last row.
      padding: const EdgeInsets.only(bottom: 88),
      children: children,
    );
  }

  Widget _row(Words t, RegisterRow r) {
    final key = (txn: r.txnId, entry: r.entryId);
    final open = _open == key;
    final all = _account == null;
    final account = widget.store.snapshot.accounts
        .where((a) => a.id == '${r.accountId}')
        .firstOrNull;
    final category = rowCategory(t, r);
    final line2 = all && account != null
        ? '$category · ${account.name}'
        : category;
    return Container(
      key: ValueKey('register-row-${r.txnId}-${r.entryId}'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      decoration: BoxDecoration(
        color: Mid.card,
        borderRadius: BorderRadius.circular(12),
        border: open ? Border.all(color: Mid.blue, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _open = open ? null : key),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    StatusGlyph(
                      r.cleared,
                      color: r.cleared == Cleared.reconciled ? Mid.gold : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rowPayee(t, r),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: onest(16, weight: 500, color: Mid.ink),
                          ),
                          Text(
                            line2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: onest(13, color: Mid.ink2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Money(
                        r.amount,
                        currency: r.currency,
                        size: 16,
                        weight: 600,
                        sign: MoneySign.plusForPositive,
                        color: r.amount > 0 ? Mid.green : Mid.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open)
            _RowEdit(
              key: ValueKey('register-open-${r.txnId}-${r.entryId}'),
              row: r,
              store: widget.store,
              categories: [
                for (final c in _data.knownCategories)
                  if (c.currency == r.currency) c,
              ],
              onCancel: () => setState(() => _open = null),
              onSave: (edit) => _save(r, edit),
              more: _more(t, r),
            ),
        ],
      ),
    );
  }

  /// The ⋯ beside Save and Cancel: Mark cleared or uncleared, Move to,
  /// Delete (#527).
  Widget _more(Words t, RegisterRow r) {
    final cleared = r.cleared == Cleared.uncleared;
    return PopupMenuButton<String>(
      key: const ValueKey('row-more'),
      color: Mid.raised,
      icon: Icon(Icons.more_horiz_rounded, color: Mid.ink2),
      onSelected: (what) {
        switch (what) {
          case 'cleared':
            unawaited(_markCleared(r));
          case 'move':
            unawaited(_move(r));
          case 'delete':
            unawaited(_delete(r));
        }
      },
      itemBuilder: (_) => [
        if (!r.scheduled)
          PopupMenuItem<String>(
            value: 'cleared',
            child: Text(
              cleared ? t.rowsMarkCleared : t.rowsMarkUncleared,
              style: onest(16, color: Mid.ink),
            ),
          ),
        PopupMenuItem<String>(
          value: 'move',
          child: Text(t.rowsMoveTo, style: onest(16, color: Mid.ink)),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(t.rowsDelete, style: onest(16, color: Mid.ink)),
        ),
      ],
    );
  }

  /// Does [act]; says why when the ledger refuses. [name] and [label] word
  /// the snack bar that offers Undo, [lock] the refusal of a locked row.
  Future<void> _act(
    RegisterRow r,
    PhoneRowAct act,
    String label, {
    required String Function(Object e) said,
  }) async {
    final t = context.t;
    final store = widget.store;
    final PhoneActed done;
    try {
      done = await store.actRow(act);
    } on DbException catch (e) {
      _say(said(e));
      return;
    } catch (e) {
      debugPrint('A row action on the phone failed: $e');
      _say(t.ledgerCouldntSave);
      return;
    }
    if (!mounted) return;
    setState(() => _open = null);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const ValueKey('row-acted'),
          backgroundColor: Mid.raised,
          content: Text(label, style: onest(15, color: Mid.ink)),
          action: SnackBarAction(
            label: t.ledgerUndo,
            textColor: Mid.blue,
            onPressed: () => unawaited(store.replay(done.undo)),
          ),
        ),
      );
  }

  void _say(String words) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const ValueKey('row-refused'),
          backgroundColor: Mid.raised,
          content: Text(words, style: onest(15, color: Mid.ink)),
        ),
      );
  }

  Future<void> _markCleared(RegisterRow r) {
    final t = context.t;
    final to = r.cleared == Cleared.uncleared
        ? Cleared.cleared
        : Cleared.uncleared;
    return _act(
      r,
      PhoneMarkCleared(r.entryId, to),
      to == Cleared.cleared
          ? t.ledgerMarkedCleared(rowPayee(t, r))
          : t.ledgerMarkedUncleared(rowPayee(t, r)),
      said: (_) => t.ledgerCantUnclearReconciled,
    );
  }

  Future<void> _delete(RegisterRow r) {
    final t = context.t;
    return _act(
      r,
      PhoneDeleteRow(r.txnId),
      t.ledgerDeleted(rowPayee(t, r)),
      said: (_) => r.lockedIn != null
          ? t.ledgerCantDeleteTransfer(r.lockedIn!)
          : t.ledgerCantDeleteReconciled,
    );
  }

  /// Move to: the accounts this row could be in, in its currency.
  Future<void> _move(RegisterRow r) async {
    final t = context.t;
    final to = await showModalBottomSheet<AccountInfo>(
      context: context,
      backgroundColor: Mid.raised,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final a in _data.accounts.values)
              if (a.id != r.accountId &&
                  !a.deleted &&
                  !a.archived &&
                  (a.type == AccountType.asset ||
                      a.type == AccountType.liability) &&
                  a.currency == r.currency)
                ListTile(
                  key: ValueKey('row-move-${a.id}'),
                  minTileHeight: 48,
                  title: Text(a.name, style: onest(16, color: Mid.ink)),
                  onTap: () => Navigator.pop(context, a),
                ),
          ],
        ),
      ),
    );
    if (to == null || !mounted) return;
    final payee = rowPayee(t, r);
    await _act(
      r,
      PhoneMoveRow(r.txnId, r.accountId, to.id),
      t.ledgerMovedTo(payee, to.name),
      said: (e) => e is LockedException || e is NotFoundException
          ? t.ledgerCantMove(dbProblem(t, e as DbException))
          : t.ledgerCouldntMove,
    );
  }

  /// Saves the edit into the phone's ledger. Null when it went in, else
  /// what to say: the ledger's own words when it refuses.
  Future<String?> _save(RegisterRow r, PhoneRowEdit edit) async {
    final t = context.t;
    final store = widget.store;
    final PhoneEdited done;
    try {
      done = await store.editRow(edit);
    } on LockedException catch (e) {
      return dbProblem(t, e);
    } on DbException catch (e) {
      return t.ledgerCouldntSaveBecause(dbProblem(t, e));
    } catch (e) {
      debugPrint('Saving a row on the phone failed: $e');
      return t.ledgerCouldntSave;
    }
    if (!mounted) return null;
    setState(() => _open = null);
    final name = (edit.payee ?? '').isEmpty ? rowPayee(t, r) : edit.payee!;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const ValueKey('row-saved'),
          backgroundColor: Mid.raised,
          content: Text(t.ledgerEdited(name), style: onest(15, color: Mid.ink)),
          action: SnackBarAction(
            label: t.ledgerUndo,
            textColor: Mid.blue,
            onPressed: () => unawaited(store.restoreRow(done.before)),
          ),
        ),
      );
    return null;
  }
}

/// A row opened in place: its fields, then Save and Cancel (#527). A split,
/// a transfer or an opening balance has its date and memo here; the rest is
/// the computer's for now.
class _RowEdit extends StatefulWidget {
  const _RowEdit({
    super.key,
    required this.row,
    required this.store,
    required this.categories,
    required this.onCancel,
    required this.onSave,
    required this.more,
  });
  final RegisterRow row;
  final PhoneStore store;

  /// The ⋯ button.
  final Widget more;
  final List<AccountInfo> categories;
  final VoidCallback onCancel;

  /// Saves; returns what to say when it didn't go in.
  final Future<String?> Function(PhoneRowEdit edit) onSave;

  @override
  State<_RowEdit> createState() => _RowEditState();
}

class _RowEditState extends State<_RowEdit> {
  late final TextEditingController _payee;
  late final TextEditingController _amount;
  late final TextEditingController _memo;
  late DateTime _date;
  late int? _category;
  late bool _moneyIn;
  String? _said;
  var _saving = false;

  /// A split's lines as the split page has them, or as changed there; null
  /// for a row of one category.
  List<_Line>? _lines;
  var _linesChanged = false;

  RegisterRow get _r => widget.row;
  bool get _simple => _r.kind == RowKind.simple;

  /// A reconciled row's date and amount stay as they are.
  bool get _locked => _r.locked;

  @override
  void initState() {
    super.initState();
    _payee = TextEditingController(text: _r.txnPayee ?? _r.payee);
    _amount = TextEditingController(
      text: groupTyped(typedOfMinor(_r.amount, _r.currency), const []).text,
    );
    _memo = TextEditingController(text: _r.memo);
    _date = DateTime(_r.date.year, _r.date.month, _r.date.day);
    _category = _r.categoryId;
    _moneyIn = _r.amount > 0;
    if (_r.kind == RowKind.split) {
      final data = widget.store.snapshot.data!;
      _lines = [
        for (final l in _r.splitLines)
          (
            categoryId: data.accounts[l.accountId]?.type == AccountType.income
                ? phoneIncomeId
                : '${l.accountId}',
            typed: typedOfMinor(l.amount, _r.currency),
            back: (l.amount > 0) != (_r.amount > 0),
          ),
      ];
    }
  }

  /// The split page, on this row's lines. Its total is the row's.
  Future<void> _openLines() async {
    final t = context.t;
    final result = await Navigator.of(context).push(
      MaterialPageRoute<List<_Line>>(
        fullscreenDialog: true,
        builder: (_) => _SplitPage(
          store: widget.store,
          currency: _r.currency,
          moneyIn: _r.amount > 0,
          payee: _r.txnPayee,
          total: _r.amount.abs(),
          start: _lines!,
          income: _r.amount > 0
              ? PhoneCategory(
                  id: phoneIncomeId,
                  name: t.ledgerIncome,
                  leftMinor: 0,
                  currency: _r.currency,
                )
              : null,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _lines = result;
      _linesChanged = true;
      _said = null;
    });
  }

  /// The lines as the ledger takes them, or what to say when they aren't
  /// ready: the sum, a category gone.
  ({List<SplitPart>? parts, String? said}) _linePartsOf() {
    final t = context.t;
    final data = widget.store.snapshot.data!;
    final lines = _lines!;
    final currency = _r.currency;
    final shares = [for (final l in lines) _share(l, currency)];
    final sum = shares.fold(0, (s, v) => s + v);
    final total = _r.amount.abs();
    String money(int v) => formatMoney(v.abs(), currency: currency);
    if (sum < total) {
      return (parts: null, said: t.rowsErrorSplitLeft(money(total - sum)));
    }
    if (sum > total) {
      return (parts: null, said: t.rowsErrorSplitTooMuch(money(sum - total)));
    }
    final income = data.accounts.values
        .where((a) => a.type == AccountType.income)
        .firstOrNull
        ?.id;
    final parts = <SplitPart>[];
    for (final (i, l) in lines.indexed) {
      final id = l.categoryId == phoneIncomeId
          ? income
          : int.tryParse(l.categoryId);
      if (id == null) return (parts: null, said: t.phoneChooseCategory);
      parts.add((
        categoryId: id,
        amount: _r.amount > 0 ? shares[i] : -shares[i],
      ));
    }
    return (parts: parts, said: null);
  }

  @override
  void dispose() {
    _payee.dispose();
    _amount.dispose();
    _memo.dispose();
    super.dispose();
  }

  int? get _typed => parseAmount(_amount.text, _r.currency)?.abs();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final t = context.t;
    final typed = _typed;
    if (_simple && (typed == null || typed == 0)) {
      setState(() => _said = t.rowsColumnAmount);
      return;
    }
    List<SplitPart>? splits;
    if (_lines != null && _linesChanged) {
      final made = _linePartsOf();
      if (made.said != null) {
        setState(() => _said = made.said);
        return;
      }
      splits = made.parts;
    }
    setState(() {
      _saving = true;
      _said = null;
    });
    final amount = !_simple ? null : (_moneyIn ? typed! : -typed!);
    final said = await widget.onSave((
      txn: _r.txnId,
      account: _r.accountId,
      date: _date,
      payee: _simple ? _payee.text.trim() : _r.txnPayee,
      memo: _memo.text,
      counter: _simple && _category != _r.categoryId ? _category : null,
      amount: amount != null && amount != _r.amount ? amount : null,
      splits: splits,
    ));
    if (mounted && said != null) {
      setState(() {
        _saving = false;
        _said = said;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    InputDecoration box(String label) => InputDecoration(
      labelText: label,
      labelStyle: onest(14, color: Mid.ink2),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Mid.rule),
      ),
    );
    final category = widget.categories
        .where((c) => c.id == _category)
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, color: Mid.rule),
          if (_simple) ...[
            TextField(
              key: const ValueKey('row-payee'),
              controller: _payee,
              style: onest(16, color: Mid.ink),
              decoration: box(t.rowsHintPayee),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('row-amount'),
                    controller: _amount,
                    enabled: !_locked,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [GroupedAmount(_r.currency)],
                    style: onest(16, color: Mid.ink),
                    decoration: box(t.rowsColumnAmount),
                  ),
                ),
                const SizedBox(width: 8),
                if (!_locked)
                  _SignButton(
                    moneyIn: _moneyIn,
                    onTap: () => setState(() => _moneyIn = !_moneyIn),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: PopupMenuButton<int>(
                key: const ValueKey('row-category'),
                color: Mid.raised,
                onSelected: (id) => setState(() => _category = id),
                itemBuilder: (_) => [
                  for (final c in widget.categories)
                    PopupMenuItem<int>(
                      value: c.id,
                      child: Text(c.name, style: onest(16, color: Mid.ink)),
                    ),
                ],
                child: InputDecorator(
                  decoration: box(t.rowsColumnCategory),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          category?.name ?? _r.categoryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: onest(16, color: Mid.ink),
                        ),
                      ),
                      Icon(Icons.arrow_drop_down_rounded, color: Mid.ink2),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (_lines != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: InkWell(
                key: const ValueKey('row-lines'),
                onTap: _openLines,
                child: InputDecorator(
                  decoration: box(t.rowsColumnCategory),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.rowsSplitSummary(_lines!.length),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: onest(16, color: Mid.ink),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Mid.ink2),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: InkWell(
              key: const ValueKey('row-date'),
              onTap: _locked ? null : _pickDate,
              child: InputDecorator(
                decoration: box(t.rowsColumnDate),
                child: Text(
                  fullDate(_date),
                  style: onest(16, color: _locked ? Mid.ink3 : Mid.ink),
                ),
              ),
            ),
          ),
          TextField(
            key: const ValueKey('row-memo'),
            controller: _memo,
            style: onest(16, color: Mid.ink),
            decoration: box(t.rowsHintMemo),
          ),
          if (_locked)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                t.rowsReconciledLocked,
                style: onest(13, color: Mid.ink2),
              ),
            ),
          if (_said != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _said!,
                key: const ValueKey('row-said'),
                style: onest(14, color: Mid.coral),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const ValueKey('row-save'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Mid.fill,
                    foregroundColor: Mid.onFill,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  onPressed: _saving ? null : _save,
                  child: Text(t.rowsSave, style: onest(15, weight: 600)),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: const ValueKey('row-cancel'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(88, 44),
                  foregroundColor: Mid.ink2,
                ),
                onPressed: widget.onCancel,
                child: Text(t.rowsCancel, style: onest(15)),
              ),
              widget.more,
            ],
          ),
        ],
      ),
    );
  }
}
