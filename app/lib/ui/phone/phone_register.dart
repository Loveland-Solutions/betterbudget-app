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
                          child: Text(
                            a.name,
                            style: onest(16, color: Mid.ink),
                          ),
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
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            color: Mid.ink2,
                          ),
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
                labelStyle: onest(
                  14,
                  color: s == on ? Mid.onAccent : Mid.ink2,
                ),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _open = open ? null : key),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
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
              if (open) _details(t, r, account),
            ],
          ),
        ),
      ),
    );
  }

  Widget _details(Words t, RegisterRow r, PhoneAccount? account) {
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: onest(13, color: Mid.ink2)),
          ),
          Expanded(child: Text(value, style: onest(15, color: Mid.ink))),
        ],
      ),
    );
    return Column(
      key: ValueKey('register-open-${r.txnId}-${r.entryId}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Divider(height: 1, color: Mid.rule),
        if (account != null) line(t.rowsColumnAccount, account.name),
        line(t.rowsColumnDate, fullDate(r.date)),
        line(t.rowsColumnCategory, rowCategory(t, r)),
        if (r.memo.isNotEmpty) line(t.rowsHintMemo, r.memo),
        line('', clearedName(t, r.cleared)),
      ],
    );
  }
}
