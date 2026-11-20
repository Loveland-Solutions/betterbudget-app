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

  /// The rows that may have paid a bill, by the row's transaction, and the
  /// bills they may have paid, by the bill's.
  final _paidBy = <int, BillPayment>{};
  Map<int, BillPayment> _paymentOf = const {};

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
    // The rows already in that may have paid a bill, by bill and by row.
    final payments = billPayments(
      _data,
      today,
      uncategorizedId: _uncategorizedId,
    );
    _paidBy
      ..clear()
      ..addAll({for (final p in payments.values) p.row.txnId: p});
    _paymentOf = payments;
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
              today: widget.now(),
              onSave: (edit) => _save(r, edit),
              onConfirm: (edit, keepOwed) => _confirm(r, edit, keepOwed),
              more: _more(t, r),
            ),
          ?_paidLine(t, r),
        ],
      ),
    );
  }

  /// Under a scheduled bill a row already in may have paid, or under that
  /// row: asked, Yes or No (#527).
  Widget? _paidLine(Words t, RegisterRow r) {
    final data = _data;
    final asBill = r.scheduled ? _paymentOf[r.txnId] : null;
    final asRow = r.scheduled ? null : _paidBy[r.txnId];
    final p = asBill ?? asRow;
    if (p == null) return null;
    final found = p.row;
    final String text;
    if (asBill != null) {
      final amount = formatMoney(found.amount, currency: found.currency);
      text = found.accountId == r.accountId
          ? t.rowsPaidOnAsk(sayDate(t, found.date), rowPayee(t, found), amount)
          : t.rowsPaidOnAskFrom(
              sayDate(t, found.date),
              rowPayee(t, found),
              amount,
              data.accounts[found.accountId]?.name ?? '',
            );
    } else {
      text = t.billAskTitle(rowPayee(t, p.bill));
    }
    return _PaidAsk(
      key: ValueKey('looks-paid-${p.bill.txnId}-${found.txnId}'),
      text: text,
      onYes: () => unawaited(_answerPaid(p)),
      onNo: () => unawaited(_notIt(p)),
    );
  }

  /// Yes: a row near its bill paid it; one that isn't is asked about first.
  Future<void> _answerPaid(BillPayment p) async {
    if (p.fit == BillFit.paid) return _tie(p);
    final data = _data;
    final answer = await Navigator.of(context).push<_BillAnswer>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _BillAskPage(
          payment: p,
          account: p.row.accountId == p.bill.accountId
              ? null
              : data.accounts[p.row.accountId]?.name,
          category: switch (p.bill.planCategoryId ?? p.bill.categoryId) {
            final id? => data.accounts[id]?.name,
            null => null,
          },
          dues: _billDates(data, p.bill, p.bills),
        ),
      ),
    );
    if (!mounted) return;
    switch (answer) {
      case _BillAnswer.paid:
        await _tie(p);
      case _BillAnswer.rest:
        await _tie(p, keepRest: true);
      case _BillAnswer.several:
        await _tie(p, bills: p.bills);
      case _BillAnswer.notIt:
        await _notIt(p);
      case null:
        break;
    }
  }

  Future<void> _tie(BillPayment p, {bool keepRest = false, int bills = 1}) {
    final t = context.t;
    final bill = p.bill;
    final name = rowPayee(t, bill);
    final rest = keepRest && bill.kind == RowKind.simple
        ? (bill.amount - p.row.amount).abs()
        : null;
    return _act(
      p.row,
      PhoneBillPaid(bill, p.row, keepRest: keepRest, bills: bills),
      '',
      said: (e) => t.ledgerCouldntSaveBecause(dbProblem(t, e as DbException)),
      // The next bill's date is known once it is scheduled: said after.
      then: (after) {
        final next = _nextBill(after, bill.planCategoryId);
        if (rest != null) {
          return t.ledgerBillRest(
            name,
            formatShort(rest, currency: bill.currency),
            sayDate(t, bill.date),
          );
        }
        if (bills > 1 && next != null) {
          return t.ledgerBillsPaidNext(bills, name, sayDate(t, next));
        }
        return next != null
            ? t.ledgerBillPaidNext(name, sayDate(t, next))
            : t.ledgerBillPaidOnly(name);
      },
    );
  }

  /// The soonest bill of [category]'s plan still scheduled, or null.
  DateTime? _nextBill(PhoneSnapshot after, int? category) {
    final data = after.data;
    if (data == null || category == null) return null;
    DateTime? next;
    for (final r in data.registerAll().scheduled) {
      if (r.planCategoryId == category &&
          (next == null || r.date.isBefore(next))) {
        next = r.date;
      }
    }
    return next;
  }

  /// No: that row isn't this bill, which stops asking about it.
  Future<void> _notIt(BillPayment p) {
    final t = context.t;
    return _act(
      p.bill,
      PhoneNotIt(p.bill.txnId, p.row.txnId),
      t.ledgerNotTheBill(rowPayee(t, p.bill), sayDate(t, p.bill.date)),
      said: (_) => t.ledgerCouldntSave,
    );
  }

  /// "Not this bill" on a row that was taken as a bill paid.
  Future<void> _notThisBill(RegisterRow r) {
    final t = context.t;
    final record = decodeBillPaid(_data.prefs[billPaidKey(r.txnId)]);
    final name = switch (r.planCategoryId) {
      final id? => _data.accounts[id]?.name,
      null => null,
    };
    return _act(
      r,
      PhoneNotTheBill(r),
      t.ledgerNotTheBill(
        name ?? rowPayee(t, r),
        sayDate(t, record?.date ?? r.date),
      ),
      said: (_) => t.ledgerCouldntSave,
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
          case 'nobill':
            unawaited(_noBill(r));
          case 'notthis':
            unawaited(_notThisBill(r));
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
        // Taken as a bill paid: it may not have been.
        if (!r.scheduled && _data.prefs.containsKey(billPaidKey(r.txnId)))
          PopupMenuItem<String>(
            value: 'notthis',
            child: Text(t.rowsNotThisBill, style: onest(16, color: Mid.ink)),
          ),
        // A category's bill: deleting it was always skipping it, so the
        // item says so (as on the computer).
        if (r.scheduled && r.planCategoryId != null && r.amount < 0)
          PopupMenuItem<String>(
            value: 'nobill',
            child: Text(t.rowsNoBillThisTime, style: onest(16, color: Mid.ink)),
          )
        else
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
    String Function(PhoneSnapshot after)? then,
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
          content: Text(
            then == null ? label : then(done.snapshot),
            style: onest(15, color: Mid.ink),
          ),
          action: SnackBarAction(
            label: t.ledgerUndo,
            textColor: Mid.blue,
            onPressed: () => unawaited(store.replay(done.undo)),
          ),
        ),
      );
  }

  /// No bill this time on a category's scheduled bill (#527).
  Future<void> _noBill(RegisterRow r) {
    final t = context.t;
    final planned = r.planCategoryId!;
    return _act(
      r,
      PhoneNoBill(r.txnId, planned, r.date),
      t.ledgerNoBillLast(rowPayee(t, r), sayDate(t, r.date)),
      said: (_) => r.lockedIn != null
          ? t.ledgerCantDeleteTransfer(r.lockedIn!)
          : t.ledgerCantDeleteReconciled,
    );
  }

  /// Confirms a scheduled row. Null when it went in, else what to say.
  Future<String?> _confirm(
    RegisterRow r,
    PhoneRowEdit edit,
    bool keepOwed,
  ) async {
    final t = context.t;
    final store = widget.store;
    final PhoneActed done;
    try {
      done = await store.confirmRow((
        edit: edit,
        paySchedule: r.payScheduleId,
        planCategory: r.planCategoryId,
        keepOwed: keepOwed,
      ));
    } on LockedException catch (e) {
      return dbProblem(t, e);
    } on DbException catch (e) {
      return t.ledgerCouldntSaveBecause(dbProblem(t, e));
    } catch (e) {
      debugPrint('Confirming a row on the phone failed: $e');
      return t.ledgerCouldntSave;
    }
    if (!mounted) return null;
    setState(() => _open = null);
    final name = (edit.payee ?? '').isEmpty ? rowPayee(t, r) : edit.payee!;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const ValueKey('row-confirmed'),
          backgroundColor: Mid.raised,
          content: Text(
            [
              t.ledgerConfirmed(name),
              if (keepOwed && (edit.amount ?? r.amount) < r.amount)
                t.ledgerStillOwed(
                  formatShort(
                    r.amount - (edit.amount ?? r.amount),
                    currency: r.currency,
                  ),
                  sayDate(t, r.date),
                ),
            ].join(' · '),
            style: onest(15, color: Mid.ink),
          ),
          action: SnackBarAction(
            label: t.ledgerUndo,
            textColor: Mid.blue,
            onPressed: () => unawaited(store.replay(done.undo)),
          ),
        ),
      );
    return null;
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
            onPressed: () => unawaited(
              store.restoreRow(done.before, remembered: done.remembered),
            ),
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
    required this.onConfirm,
    required this.today,
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

  /// Confirms a scheduled row; returns what to say when it didn't go in.
  final Future<String?> Function(PhoneRowEdit edit, bool keepOwed) onConfirm;
  final DateTime today;

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

  /// The box under the row: remember the category for the payee (#403).
  var _remember = false;

  /// Confirming money in that came short: the rest is still owed, or it was
  /// paid in full. Null until chosen.
  bool? _keepOwedChoice;

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
    // The line about money that came short follows what is typed.
    _amount.addListener(() {
      if (mounted && _r.scheduled) setState(() {});
    });
    _payee.addListener(() {
      if (mounted) setState(() {});
    });
    // A scheduled row opens to be confirmed: it happened, so dated today.
    final day = _r.scheduled ? widget.today : _r.date;
    _date = DateTime(day.year, day.month, day.day);
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

  /// Confirming money in below plan: how much is missing. Null otherwise:
  /// never for a bill (one that came in lower owes nothing more), a paycheck
  /// that varies, or a transfer.
  int? get _shortBy {
    final typed = _typed;
    if (!_r.scheduled ||
        !_simple ||
        !_moneyIn ||
        _r.amount <= 0 ||
        _r.estimate != null ||
        typed == null ||
        typed == 0) {
      return null;
    }
    return typed < _r.amount ? _r.amount - typed : null;
  }

  /// Still owed when more than a tenth is missing (half a salary); paid in
  /// full for small differences, which would leave remainders nobody is
  /// owed (as on the computer).
  bool _keepOwedFor(int short) => _keepOwedChoice ?? short * 10 > _r.amount;

  /// Whether the row offers to remember its category for its payee: a
  /// payee and a category that isn't already remembered for it.
  bool get _canRemember {
    final category = _category;
    final payee = _payee.text.trim();
    if (!_simple || payee.isEmpty || category == null) return false;
    final info = widget.categories.where((c) => c.id == category).firstOrNull;
    if (info == null || isUncategorized(info)) return false;
    final covering = PayeeRuleInfo.pick(
      widget.store.snapshot.data!.payeeRules,
      _r.accountId,
      payee,
      null,
    );
    return !(covering != null &&
        covering.categoryId == category &&
        covering.payId == null);
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
    final short = _shortBy;
    final edit = (
      txn: _r.txnId,
      account: _r.accountId,
      date: _date,
      payee: _simple ? _payee.text.trim() : _r.txnPayee,
      memo: _memo.text,
      counter: _simple && _category != _r.categoryId ? _category : null,
      amount: amount != null && amount != _r.amount ? amount : null,
      splits: splits,
      remember: _remember && _canRemember ? _category : null,
    );
    final said = await (_r.scheduled
        ? widget.onConfirm(edit, short != null && _keepOwedFor(short))
        : widget.onSave(edit));
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
            if (_shortBy case final short?)
              _ChoiceLine(
                key: const ValueKey('owed-line'),
                lead: t.rowsLessThanPlanned(
                  formatShort(short, currency: _r.currency),
                ),
                choices: [
                  (
                    key: 'owed-keep',
                    label: t.rowsStillOwedDue(sayDate(t, _r.date)),
                    on: _keepOwedFor(short),
                    value: true,
                  ),
                  (
                    key: 'owed-paid',
                    label: t.rowsPaidInFull,
                    on: !_keepOwedFor(short),
                    value: false,
                  ),
                ],
                onPick: (v) => setState(() => _keepOwedChoice = v),
              ),
            if (_canRemember)
              _RememberTick(
                on: _remember,
                onTap: () => setState(() => _remember = !_remember),
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
                  child: Text(
                    _r.scheduled ? t.rowsConfirm : t.rowsSave,
                    style: onest(15, weight: 600),
                  ),
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

/// A line of words and a choice of two or three, under a row's fields: what
/// to do about money that came in short (#527).
class _ChoiceLine extends StatelessWidget {
  const _ChoiceLine({
    super.key,
    required this.lead,
    required this.choices,
    required this.onPick,
  });
  final String lead;
  final List<({String key, String label, bool on, bool value})> choices;
  final ValueChanged<bool> onPick;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lead, style: onest(14, color: Mid.ink2)),
        for (final c in choices)
          InkWell(
            key: ValueKey(c.key),
            onTap: () => onPick(c.value),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  Icon(
                    c.on
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: c.on ? Mid.blue : Mid.ink3,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(c.label, style: onest(15, color: Mid.ink)),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

/// The box under the category: remember it for the payee (#403). Off until
/// ticked.
class _RememberTick extends StatelessWidget {
  const _RememberTick({required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: const ValueKey('remember-line'),
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(
              on
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              color: on ? Mid.blue : Mid.ink3,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.t.rowsRemember,
                style: onest(15, color: Mid.ink),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
