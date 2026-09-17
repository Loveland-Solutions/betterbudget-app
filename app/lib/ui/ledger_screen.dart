import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/database.dart';
import '../data/demo_seed.dart';
import '../domain/forecast.dart';
import '../domain/ledger.dart';
import '../domain/money.dart';
import 'balance_header.dart';
import 'entry_row.dart';
import 'reconcile.dart';
import 'register.dart';
import 'theme.dart';

bool get _isMac =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Top-level sections. Budget and Savings are placeholders; "Savings" is a
/// working name until the section is defined.
enum AppSection { ledger, budget, savings }

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key, required this.db, this.clock = DateTime.now});

  final AppDatabase db;
  final DateTime Function() clock;

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  late final Stream<LedgerData> _ledger;
  var _section = AppSection.ledger;
  int? _accountId;

  /// The clicked row; its actions show in a bar under it.
  int? _selected;

  /// On the selected row, so it can be scrolled into view.
  final _selectedKey = GlobalKey();
  var _filter = RegisterFilter.all;
  final _hoveredStatus = ValueNotifier<Cleared?>(null);
  final _search = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'search');

  /// Holds keyboard focus for the register, so row shortcuts reach [_onKey].
  final _registerFocus = FocusNode(debugLabel: 'register');
  late final EntryRowController _entry;

  /// The new-transaction row is open. It opens from Add or ⌘N.
  bool _adding = false;
  ({String message, VoidCallback? undo})? _toast;

  /// Everything undoable done this session, oldest first. ⌘Z / Ctrl+Z undoes
  /// the newest; a toast's Undo works only while its action is the newest.
  final _history = <_Undoable>[];

  /// Undone actions, newest last. ⌘⇧Z (Ctrl+Y on Windows) redoes them; any
  /// new action clears it.
  final _redo = <_Undoable>[];

  /// A reconcile in progress, if any.
  ReconcileSession? _reconcile;

  /// Lock was pressed and the write hasn't returned; a second click waits.
  bool _locking = false;

  /// The transaction open in the inline editor, if any.
  RegisterEditing? _editing;

  /// Last row click, to recognise a double-click without delaying single ones.
  ({int id, DateTime at})? _lastTap;
  Timer? _toastTimer;

  /// Rows of the current account, by transaction id, from the latest build.
  Map<int, RegisterRow> _rows = const {};

  AppDatabase get db => widget.db;
  DateTime get today => dateOnly(widget.clock());

  @override
  void initState() {
    super.initState();
    _ledger = Stream.fromFuture(seedDemoIfEmpty(db, today))
        .asyncExpand((_) => db.watchLedger());
    _entry = EntryRowController(
      onSubmit: _post,
      suggestCategory: (payee) => db.lastCategoryFor(payee, _accountId!),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _registerFocus.dispose();
    _hoveredStatus.dispose();
    _entry.payeeFocus.dispose();
    _toastTimer?.cancel();
    _reconcile?.dispose();
    super.dispose();
  }

  Future<String?> _post(EntryDraft d) async {
    try {
      final id = await db.postSimple(
        accountId: _accountId!,
        date: d.date,
        today: today,
        payee: d.payee,
        // The new-transaction row always supplies both.
        counterAccountId: d.counter!.id,
        amount: d.amount!,
        memo: (d.memo?.trim().isEmpty ?? true) ? null : d.memo!.trim(),
      );
      _entry.payeeNames = await db.payeeNames();
      _did(
        '${d.payee} added',
        undo: () async => _expect((await db.softDeleteMany([id])).length == 1),
        redo: () => db.restoreMany([id]),
        toast: false,
      );
      if (d.date.isAfter(today)) {
        _showToast(
          'Scheduled for ${fullDate(d.date)} · not in balances until confirmed',
        );
      }
      return null;
    } catch (e) {
      return 'Couldn’t save: $e';
    }
  }

  /// Records an undoable action. Toasts are for saved changes and deletes;
  /// quick clicks like clearing a row stay quiet and rely on ⌘Z.
  void _did(
    String label, {
    required Future<void> Function() undo,
    required Future<void> Function() redo,
    bool toast = true,
    String? message,
  }) {
    final action = _Undoable(label, undo, redo);
    _history.add(action);
    _redo.clear();
    if (toast) {
      _showToast(
        message ?? label,
        undo: () async {
          // Undo runs newest first, so an older toast can't jump the queue:
          // restoring its state would silently wipe the newer changes.
          if (!identical(_history.lastOrNull, action)) {
            _showToast(
              'Undo the newer changes first · ${_isMac ? '⌘Z' : 'Ctrl+Z'}',
            );
            return;
          }
          await _undo();
        },
      );
    }
  }

  /// Throws when a database write changed less than undo or redo expected,
  /// usually because the row was locked or changed since.
  void _expect(bool ok) {
    if (!ok) throw StateError('changed since');
  }

  /// Undoes the newest action.
  Future<void> _undo() async {
    final a = _history.lastOrNull;
    if (a == null) {
      _showToast('Nothing to undo');
      return;
    }
    _history.removeLast();
    try {
      await a.undo();
    } catch (e) {
      _showToast('Couldn’t undo “${a.label}” · it changed since');
      return;
    }
    _redo.add(a);
    _showToast('Undone · ${a.label}');
  }

  Future<void> _redoLast() async {
    final a = _redo.lastOrNull;
    if (a == null) {
      _showToast('Nothing to redo');
      return;
    }
    _redo.removeLast();
    try {
      await a.redo();
    } catch (e) {
      _showToast('Couldn’t redo “${a.label}” · it changed since');
      return;
    }
    _history.add(a);
    _showToast('Redone · ${a.label}');
  }

  void _showToast(String message, {Future<void> Function()? undo}) {
    _toastTimer?.cancel();
    setState(
      () => _toast = (
        message: message,
        undo: undo == null
            ? null
            : () async {
                setState(() => _toast = null);
                await undo();
              },
      ),
    );
    _toastTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  /// True while a text field has focus. The focus node's own widget is the
  /// Focus inside EditableText, so look up the tree rather than at it.
  bool get _typing {
    final context = FocusManager.instance.primaryFocus?.context;
    return context != null &&
        (context.widget is EditableText ||
            context.findAncestorWidgetOfExactType<EditableText>() != null);
  }

  /// Single keys that act on selected rows. They must never be claimed while
  /// typing: returning `ignored` passes the key on to the text field.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final keys = HardwareKeyboard.instance;
    // ⌘Z / Ctrl+Z undoes the last action and ⌘⇧Z (Ctrl+Y or Ctrl+Shift+Z)
    // redoes it, except in a text field, where they act on typing.
    final command = _isMac ? keys.isMetaPressed : keys.isControlPressed;
    final z = event.logicalKey == LogicalKeyboardKey.keyZ;
    final undo = command && z && !keys.isShiftPressed;
    final redo =
        command &&
        ((z && keys.isShiftPressed) ||
            (!_isMac && event.logicalKey == LogicalKeyboardKey.keyY));
    if (undo || redo) {
      if (_typing) return KeyEventResult.ignored;
      if (event is KeyDownEvent) undo ? _undo() : _redoLast();
      return KeyEventResult.handled;
    }
    if (_typing ||
        keys.isMetaPressed ||
        keys.isControlPressed ||
        keys.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final row = _rows[_selected];
    if (row == null) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.delete || LogicalKeyboardKey.backspace:
        _delete(row);
      // C: cleared ⇄ uncleared, as clicking the row's symbol does.
      case LogicalKeyboardKey.keyC:
        if (event is KeyRepeatEvent || row.scheduled) {
          return KeyEventResult.ignored;
        }
        _toggleCleared(row);
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
        if (_editing != null) return KeyEventResult.ignored;
        _startEdit(row.txnId, EditField.payee);
      case LogicalKeyboardKey.escape:
        _clearSelection();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ---------- selection ----------

  void _tapRow(int id, EditField field) {
    if (_editing != null) {
      if (_editing!.controller.isDirty()) {
        _showToast('Save with Enter, or press Esc to discard your changes');
        return;
      }
      _cancelEdit();
    }

    final now = DateTime.now();
    final last = _lastTap;
    if (last != null &&
        last.id == id &&
        now.difference(last.at) < const Duration(milliseconds: 450)) {
      _lastTap = null;
      _startEdit(id, field);
      return;
    }
    _lastTap = (id: id, at: now);

    // Clicking a row leaves any text field, so Delete and C act on the row.
    _registerFocus.requestFocus();
    // Clicking the selected row again closes its actions.
    setState(() => _selected = _selected == id ? null : id);
  }

  void _clearSelection() => setState(() => _selected = null);

  /// From a forecast dot: show that scheduled transaction, selected.
  void _openScheduled(RegisterRow r) {
    // The register hides scheduled rows while reconciling, and keys would act
    // on a row nobody can see.
    if (_reconcile != null) {
      _showToast('Finish or cancel the reconcile first');
      return;
    }
    if (_editing != null) {
      if (_editing!.controller.isDirty()) {
        _showToast('Save with Enter, or press Esc to discard your changes');
        return;
      }
      _cancelEdit();
    }
    _search.clear();
    setState(() {
      _filter = RegisterFilter.scheduled;
      _selected = r.txnId;
    });
    _registerFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = _selectedKey.currentContext;
      if (row == null || !row.mounted) return;
      Scrollable.ensureVisible(
        row,
        alignment: 0.2,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _newEntry() {
    setState(() {
      _section = AppSection.ledger;
      _adding = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _entry.focus());
  }

  // ---------- editing ----------

  void _startEdit(int id, EditField field) {
    final row = _rows[id];
    if (row == null) return;
    // Reconciled rows open too: payee, memo and category can still change.
    final controller = EntryRowController(
      onSubmit: (draft) => _saveEdit(row, draft),
      suggestCategory: (payee) => db.lastCategoryFor(payee, _accountId!),
    )..payeeNames = _entry.payeeNames;
    setState(() {
      _editing = (txnId: id, focus: field, controller: controller);
      _selected = id;
    });
  }

  void _cancelEdit() {
    final editing = _editing;
    if (editing == null) return;
    setState(() => _editing = null);
    _registerFocus.requestFocus();
    // The row's widgets still hold the focus node until this frame ends.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => editing.controller.payeeFocus.dispose(),
    );
  }

  Future<String?> _saveEdit(RegisterRow row, EntryDraft d) async {
    final before = await db.snapshot(row.txnId);
    final TxnSnapshot after;
    try {
      await db.editTransaction(
        transactionId: row.txnId,
        accountId: _accountId!,
        date: d.date,
        today: today,
        payee: d.payee,
        memo: d.memo,
        counterAccountId: d.counter?.id,
        amount: d.amount,
      );
      after = await db.snapshot(row.txnId);
    } on LockedException catch (e) {
      return e.message;
    } catch (e) {
      return 'Couldn’t save: $e';
    }
    _entry.payeeNames = await db.payeeNames();
    _cancelEdit();
    final nowScheduled = !row.scheduled && d.date.isAfter(today);
    _did(
      '${d.payee.isEmpty ? row.payee : d.payee} edited',
      undo: () => db.restoreSnapshot(before),
      redo: () => db.restoreSnapshot(after),
      message: nowScheduled
          ? 'Moved to ${fullDate(d.date)} · now scheduled, out of balances until confirmed'
          : 'Changes saved',
    );
    return null;
  }

  // ---------- reconcile ----------

  void _startReconcile(LedgerData data, AccountInfo account) {
    if (_editing != null) {
      if (_editing!.controller.isDirty()) {
        _showToast('Save with Enter, or press Esc to discard your changes');
        return;
      }
      _cancelEdit();
    }
    _reconcile?.dispose();
    final session = ReconcileSession(
      accountId: account.id,
      owed: account.isOwed,
      today: today,
    );
    // The register shows rows through the statement date as it's typed.
    session.date.addListener(() {
      if (mounted && _reconcile == session) setState(() {});
    });
    setState(() {
      _reconcile = session;
      _selected = null;
      _adding = false;
    });
    // The register holds focus, so the field's autofocus wouldn't take it.
    // The bank's number is what comes next.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_reconcile == session) session.balanceFocus.requestFocus();
    });
  }

  void _endReconcile() {
    final s = _reconcile;
    if (s == null) return;
    setState(() => _reconcile = null);
    _registerFocus.requestFocus();
    // The panel's fields still hold the controllers until this frame ends.
    WidgetsBinding.instance.addPostFrameCallback((_) => s.dispose());
  }

  ReconcileCheck _reconcileCheck(LedgerData data, AccountSummary summary) {
    final s = _reconcile!;
    final date = parseEntryDate(s.date.text, today);
    final last = summary.reconciledOn;
    final problem = date == null
        ? 'Type a date like ${shortDate(today)}'
        : date.isAfter(today)
        ? 'The statement can’t be after today'
        : last != null && date.isBefore(last)
        ? 'Already reconciled through ${shortDate(last)}'
        : null;
    final cleared = data.clearedThrough(s.accountId, date ?? today);
    final statement = s.statementBalance;
    return (
      date: date,
      dateProblem: problem,
      statement: statement,
      cleared: cleared.balance,
      toLock: cleared.toLock,
      hint: date == null || statement == null
          ? null
          : data.reconcileHint(s.accountId, date, statement - cleared.balance),
    );
  }

  /// With [adjust], a difference is posted as a "Reconcile adjustment" first.
  Future<void> _lockReconcile(
    AccountInfo account,
    ReconcileCheck c, {
    bool adjust = false,
  }) async {
    final s = _reconcile;
    if (s == null || _locking || c.date == null || c.statement == null) return;
    final ReconcileRecord done;
    _locking = true;
    try {
      done = await db.reconcile(
        accountId: s.accountId,
        statementDate: c.date!,
        today: today,
        balance: c.statement!,
        adjust: adjust,
      );
    } on ReconcileMismatchException {
      _showToast('The cleared rows changed · check the difference again');
      return;
    } on ReconcileDateException catch (e) {
      _showToast(e.message);
      return;
    } finally {
      _locking = false;
    }
    _endReconcile();
    final n = done.entryIds.length - (done.adjustmentTxnId == null ? 0 : 1);
    final off = c.statement! - c.cleared;
    final shownOff = account.isOwed ? -off : off;
    _did(
      '${account.name} reconciled through ${shortDate(c.date!)}',
      undo: () => db.unreconcile(done),
      redo: () => db.relock(done),
      message:
          '${account.name} reconciled through ${shortDate(c.date!)}'
          '${n == 0 ? '' : ' · $n locked'}'
          '${done.adjustmentTxnId == null ? '' : ' · ${formatMoney(shownOff.abs(), showCents: off % 100 != 0)} adjustment added'}',
    );
  }

  // ---------- actions ----------

  Future<void> _toggleCleared(RegisterRow r) async {
    final next = r.cleared == Cleared.uncleared
        ? Cleared.cleared
        : Cleared.uncleared;
    final previous = await db.setClearedMany({r.entryId: next});
    if (previous.isEmpty) return;
    // The symbol changing is the confirmation; no toast.
    _did(
      '${r.payee} marked ${StatusGlyph.label(next).toLowerCase()}',
      undo: () async => _expect(
        (await db.setClearedMany(previous)).length == previous.length,
      ),
      redo: () async =>
          _expect((await db.setClearedMany({r.entryId: next})).length == 1),
      toast: false,
    );
  }

  String _lockMessage(RegisterRow r) => r.lockedIn != null
      ? 'Can’t delete · this transfer is reconciled in ${r.lockedIn}'
      : 'Can’t delete · it matches a bank statement';

  Future<void> _delete(RegisterRow r) async {
    final deleted = await db.softDeleteMany([r.txnId]);
    if (deleted.isEmpty) {
      _showToast(_lockMessage(r));
      return;
    }
    _clearSelection();
    _did(
      '${r.payee} deleted',
      undo: () async {
        await db.restoreMany(deleted);
        if (mounted) setState(() => _selected = r.txnId);
      },
      redo: () async =>
          _expect((await db.softDeleteMany(deleted)).length == deleted.length),
    );
  }

  /// Takes back the account's latest reconcile, whenever it was done.
  Future<void> _unreconcile(AccountInfo account) async {
    final ReconcileRecord done;
    try {
      done = await db.unreconcileLast(account.id);
    } on NotFoundException {
      return;
    }
    final n = done.entryIds.length;
    _did(
      'Reconcile of ${shortDate(done.date)} undone',
      undo: () => db.relock(done),
      redo: () => db.unreconcile(done),
      message:
          'Reconcile of ${shortDate(done.date)} undone'
          '${n == 0 ? '' : ' · $n ${n == 1 ? 'row' : 'rows'} back to cleared'}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): _newEntry,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            _newEntry,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _searchFocus.requestFocus,
      },
      child: Focus(
        focusNode: _registerFocus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          body: StreamBuilder<LedgerData>(
            stream: _ledger,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Text(
                    'Couldn’t open the ledger: ${snap.error}',
                    style: onest(14, color: Mid.coral),
                  ),
                );
              }
              final data = snap.data;
              if (data == null) return const SizedBox.shrink();
              final accounts = data.balanceSheetAccounts;
              if (accounts.isEmpty) {
                return Center(
                  child: Text(
                    'No accounts yet',
                    style: onest(14, color: Mid.ink3),
                  ),
                );
              }
              final account = data.accounts[_accountId] ?? accounts.first;
              if (_accountId != account.id) {
                _accountId = account.id;
                db.payeeNames().then((p) => _entry.payeeNames = p);
              }
              return Stack(
                children: [
                  Row(
                    children: [
                      _Sidebar(
                        data: data,
                        section: _section,
                        onSection: (sec) => setState(() {
                          if (sec != _section) _endReconcile();
                          _section = sec;
                          _selected = null;
                          _editing = null;
                        }),
                        selected: account.id,
                        onSelect: (id) => setState(() {
                          if (id != _accountId) _endReconcile();
                          _section = AppSection.ledger;
                          _accountId = id;
                          _selected = null;
                        }),
                      ),
                      Expanded(
                        child: _section == AppSection.ledger
                            ? _body(data, account)
                            : _PlaceholderSection(section: _section),
                      ),
                    ],
                  ),
                  if (_toast != null)
                    _Toast(
                      toast: _toast!,
                      onClose: () => setState(() => _toast = null),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _body(LedgerData data, AccountInfo account) {
    final summary = data.summaryFor(account.id);
    final register = data.registerFor(account.id);
    _rows = {
      for (final r in [...register.posted, ...register.scheduled]) r.txnId: r,
    };
    // Drop the selection when its row is gone (deleted, other account).
    if (!_rows.containsKey(_selected)) _selected = null;
    if (_editing != null && !_rows.containsKey(_editing!.txnId)) {
      _editing = null;
    }
    final forecast = buildForecast(
      working: summary.working,
      today: today,
      scheduled: register.scheduled,
      owed: account.isOwed,
    );
    final activeStatus = switch (_filter) {
      RegisterFilter.uncleared => Cleared.uncleared,
      RegisterFilter.cleared => Cleared.cleared,
      RegisterFilter.reconciled => Cleared.reconciled,
      _ => null,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                account.name,
                style: onest(22, weight: 600, letterSpacing: -0.3),
              ),
              if (account.mask != null) ...[
                const SizedBox(width: 12),
                Text(
                  '··${account.mask}',
                  style: onest(13, color: Mid.ink3, tabular: true),
                ),
              ],
              const Spacer(),
              _SearchField(
                controller: _search,
                focusNode: _searchFocus,
                onChanged: () => setState(() {}),
              ),
            ],
          ),
          const SizedBox(height: 20),
          BalanceHeader(
            owed: account.isOwed,
            summary: summary,
            forecast: forecast,
            hoveredStatus: _hoveredStatus,
            activeStatus: activeStatus,
            onOpenScheduled: _openScheduled,
            onReconcile: () => _startReconcile(data, account),
            reconcile: _reconcile == null
                ? null
                : ReconcilePanel(
                    session: _reconcile!,
                    today: today,
                    check: () => _reconcileCheck(data, summary),
                    onLock: () =>
                        _lockReconcile(account, _reconcileCheck(data, summary)),
                    onAdjust: () => _lockReconcile(
                      account,
                      _reconcileCheck(data, summary),
                      adjust: true,
                    ),
                    onCancel: _endReconcile,
                  ),
            onStatusTap: (s) => setState(() {
              final f = switch (s) {
                Cleared.uncleared => RegisterFilter.uncleared,
                Cleared.cleared => RegisterFilter.cleared,
                Cleared.reconciled => RegisterFilter.reconciled,
              };
              _filter = _filter == f ? RegisterFilter.all : f;
            }),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: RegisterPanel(
              owed: account.isOwed,
              posted: register.posted,
              scheduled: register.scheduled,
              reconcileThrough: _reconcile == null
                  ? null
                  : parseEntryDate(_reconcile!.date.text, today) ?? today,
              filter: _filter,
              search: _search.text,
              selected: _selected,
              selectedKey: _selectedKey,
              editing: _editing,
              hoveredStatus: _hoveredStatus,
              categories: data.categories,
              transferTargets: data.balanceSheetAccounts
                  .where((a) => a.id != account.id)
                  .toList(),
              entryController: _entry,
              today: today,
              adding: _adding,
              addButton: _PrimaryButton(
                label: 'Add',
                icon: Icons.add_rounded,
                key: const ValueKey('add-transaction'),
                onTap: _newEntry,
              ),
              onCloseEntry: () => setState(() => _adding = false),
              actions: RegisterActions(
                onFilter: (f) => setState(() => _filter = f),
                onRowTap: _tapRow,
                onToggleCleared: _toggleCleared,
                onConfirm: (r) async {
                  final before = await db.snapshot(r.txnId);
                  await db.confirmScheduled(r.txnId, today);
                  final after = await db.snapshot(r.txnId);
                  _did(
                    '${r.payee} confirmed',
                    undo: () => db.restoreSnapshot(before),
                    redo: () => db.restoreSnapshot(after),
                    message: r.date.isAfter(today)
                        ? '${r.payee} confirmed early · posted today, ${shortDate(today)}'
                        : '${r.payee} confirmed · ${formatMoney(r.amount)}',
                  );
                },
                onSetCategory: (r, c) async {
                  final previous = await db.setCategoryMany(
                    transactionIds: [r.txnId],
                    accountId: account.id,
                    categoryId: c.id,
                  );
                  if (previous.isEmpty) return;
                  _did(
                    '${r.payee} → ${c.name}',
                    undo: () async => _expect(
                      (await db.restoreCategories(
                            previous,
                            account.id,
                          )).length ==
                          previous.length,
                    ),
                    redo: () async => _expect(
                      (await db.setCategoryMany(
                            transactionIds: [r.txnId],
                            accountId: account.id,
                            categoryId: c.id,
                          )).length ==
                          1,
                    ),
                  );
                },
                onDelete: _delete,
                onClearSelection: _clearSelection,
                onEdit: (r) => _startEdit(r.txnId, EditField.payee),
                onCancelEdit: _cancelEdit,
                onUnreconcile: (_) => _unreconcile(account),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A class, not a record: a toast checks its action is still the newest by
/// identity, which records don't have.
class _Undoable {
  _Undoable(this.label, this.undo, this.redo);
  final String label;
  final Future<void> Function() undo;
  final Future<void> Function() redo;
}

/// One sidebar: the section you're in expands, the others collapse to a line.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.data,
    required this.section,
    required this.onSection,
    required this.selected,
    required this.onSelect,
  });
  final LedgerData data;
  final AppSection section;
  final ValueChanged<AppSection> onSection;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final accounts = data.balanceSheetAccounts;
    final groups = <String, List<AccountInfo>>{};
    for (final a in accounts) {
      groups.putIfAbsent(a.group ?? 'Accounts', () => []).add(a);
    }
    final net = accounts.fold(0, (s, a) => s + data.balanceOf(a.id));

    Widget header(
      AppSection sec,
      IconData icon,
      String label, {
      bool later = false,
    }) => _SectionHeader(
      icon: icon,
      label: label,
      expanded: section == sec,
      later: later,
      onTap: () => onSection(sec),
    );

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Mid.rule)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 26, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
            child: Row(
              children: [
                const Diamond(),
                const SizedBox(width: 12),
                Text(
                  'BetterBudget',
                  style: onest(16, weight: 600, letterSpacing: -0.2),
                ),
              ],
            ),
          ),
          header(
            AppSection.ledger,
            Icons.format_list_bulleted_rounded,
            'Ledger',
          ),
          _Spill(
            open: section == AppSection.ledger,
            children: [
              const SizedBox(height: 10),
              for (final g in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(38, 0, 12, 6),
                  child: Text(g.key, style: onest(12, color: Mid.ink3)),
                ),
                for (final a in g.value)
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: _AccountTile(
                      account: a,
                      balance: data.balanceOf(a.id),
                      active: a.id == selected,
                      onTap: () => onSelect(a.id),
                    ),
                  ),
                const SizedBox(height: 14),
              ],
            ],
          ),
          const SizedBox(height: 2),
          header(
            AppSection.budget,
            Icons.pie_chart_outline_rounded,
            'Budget',
            later: true,
          ),
          const SizedBox(height: 2),
          header(
            AppSection.savings,
            Icons.savings_outlined,
            'Savings',
            later: true,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Mid.rule)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Net worth', style: onest(12, color: Mid.ink3)),
                const SizedBox(height: 4),
                Text(
                  '${net < 0 ? '−' : ''}₮${formatWhole(net)}',
                  style: onest(18, weight: 500, tabular: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatefulWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.later,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool expanded;

  /// A placeholder section that isn't built yet.
  final bool later;
  final VoidCallback onTap;

  @override
  State<_SectionHeader> createState() => _SectionHeaderState();
}

class _SectionHeaderState extends State<_SectionHeader> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.expanded;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _hover && !on ? Mid.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: on ? Mid.blue : Mid.ink3),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: onest(
                  14,
                  weight: on ? 600 : 500,
                  color: on ? Mid.ink : Mid.ink2,
                ),
              ),
              const Spacer(),
              if (widget.later)
                Text('Later', style: onest(11.5, color: Mid.ink3)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A section's contents: opening makes room smoothly while the children
/// spill down one after another; closing plays it back quicker.
class _Spill extends StatefulWidget {
  const _Spill({required this.open, required this.children});
  final bool open;
  final List<Widget> children;

  static const openTime = Duration(milliseconds: 360);
  static const closeTime = Duration(milliseconds: 200);

  @override
  State<_Spill> createState() => _SpillState();
}

class _SpillState extends State<_Spill> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: _Spill.openTime,
    reverseDuration: _Spill.closeTime,
    value: widget.open ? 1 : 0,
  );

  @override
  void didUpdateWidget(_Spill old) {
    super.didUpdateWidget(old);
    if (old.open == widget.open) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = widget.open ? 1 : 0;
    } else if (widget.open) {
      _c.forward();
    } else {
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        if (_c.isDismissed) return const SizedBox.shrink();
        final n = widget.children.length;
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: Curves.easeOutCubic.transform(_c.value),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < n; i++)
                  _item(widget.children[i], i / n * 0.55),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Each child fades in and drops a few pixels into place, starting a
  /// little after the one above it.
  Widget _item(Widget child, double start) {
    final t = Curves.easeOut.transform(
      ((_c.value - start) / 0.45).clamp(0.0, 1.0),
    );
    if (t == 1) return child;
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, -8 * (1 - t)), child: child),
    );
  }
}

/// Stands in for Budget and Savings until they're designed.
class _PlaceholderSection extends StatelessWidget {
  const _PlaceholderSection({required this.section});
  final AppSection section;

  @override
  Widget build(BuildContext context) {
    final (icon, name) = switch (section) {
      AppSection.budget => (Icons.pie_chart_outline_rounded, 'Budget'),
      _ => (Icons.savings_outlined, 'Savings'),
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: Mid.ink3),
          const SizedBox(height: 14),
          Text(name, style: onest(22, weight: 600, letterSpacing: -0.3)),
          const SizedBox(height: 6),
          Text(
            'Not built yet. The ledger comes first.',
            style: onest(14, color: Mid.ink3),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatefulWidget {
  const _AccountTile({
    required this.account,
    required this.balance,
    required this.active,
    required this.onTap,
  });
  final AccountInfo account;
  final int balance;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_AccountTile> createState() => _AccountTileState();
}

class _AccountTileState extends State<_AccountTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: widget.active
              ? Mid.panel
              : (_hover ? Mid.hover : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: widget.active
              ? const Border(left: BorderSide(color: Mid.blue, width: 2))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.account.name,
              style: onest(13.5, color: widget.active ? Mid.ink : Mid.ink2),
            ),
            const SizedBox(height: 2),
            Text(
              // A card shows what's owed, positive, as the bank does; owing
              // isn't a warning.
              widget.account.isOwed
                  ? '${widget.balance > 0 ? '−' : ''}₮${formatWhole(widget.balance)} owed'
                  : '${widget.balance < 0 ? '−' : ''}₮${formatWhole(widget.balance)}',
              style: onest(
                12.5,
                color: !widget.account.isOwed && widget.balance < 0
                    ? Mid.coral
                    : Mid.ink3,
                tabular: true,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 280,
    height: 36,
    child: TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: (_) => onChanged(),
      style: onest(13),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Mid.panel,
        hintText: 'Search payee, memo, amount',
        hintStyle: onest(13, color: Mid.ink3),
        prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Mid.ink3),
        prefixIconConstraints: const BoxConstraints(minWidth: 36),
        suffixIcon: controller.text.isEmpty
            ? Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Center(
                  widthFactor: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Mid.raised,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isMac)
                          const Icon(
                            Icons.keyboard_command_key_rounded,
                            size: 11,
                            color: Mid.ink3,
                          )
                        else
                          Text('Ctrl ', style: onest(11.5, color: Mid.ink3)),
                        Text('K', style: onest(11.5, color: Mid.ink3)),
                      ],
                    ),
                  ),
                ),
              )
            : IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: Mid.ink3,
                ),
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Mid.blue, width: 1.5),
        ),
      ),
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: _isMac ? '⌘N' : 'Ctrl+N',
    child: Material(
      color: Mid.gold,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        hoverColor: Colors.white.withValues(alpha: 0.14),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, size: 16, color: Mid.ground),
              const SizedBox(width: 8),
              Text(label, style: onest(13, weight: 600, color: Mid.ground)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Toast extends StatelessWidget {
  const _Toast({required this.toast, required this.onClose});
  final ({String message, VoidCallback? undo}) toast;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    // Gold so it gets noticed: a toast reports something that just changed.
    return Positioned(
      bottom: 28,
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Mid.gold,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    toast.message,
                    style: onest(13.5, weight: 500, color: Mid.ground),
                  ),
                  const SizedBox(width: 12),
                  if (toast.undo != null)
                    TextButton(
                      onPressed: toast.undo,
                      child: Text(
                        'Undo',
                        style: onest(
                          13.5,
                          weight: 700,
                          color: Mid.ground,
                        ).copyWith(decoration: TextDecoration.underline),
                      ),
                    ),
                  IconButton(
                    onPressed: onClose,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Mid.ground.withValues(alpha: 0.6),
                    ),
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
