import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/backup.dart';
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

part 'accounts.dart';

bool get _isMac =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Top-level sections. Budget and Savings are placeholders; "Savings" is a
/// working name until the section is defined. Settings opens from the gear
/// under Net worth, not from a section header.
enum AppSection { ledger, budget, savings, settings }

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({
    super.key,
    required this.db,
    this.clock = DateTime.now,
    this.backups,
  });

  final AppDatabase db;

  /// The app's backups, whose daily copy runs from main. Tests may leave it
  /// out; one is made for "Back up to…" and "Restore from…".
  final Backups? backups;
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

  /// The new-account form is showing instead of an account.
  bool _newAccount = false;

  /// Empty accounts started at ₮0 this session: they show the register, not
  /// the balance question.
  final _startedEmpty = <int>{};

  /// Just added, and maybe not in the latest snapshot yet: stays chosen until
  /// it arrives. Any other account missing from a snapshot (a restore) gives
  /// way to the first open one.
  int? _pendingAccountId;
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

  /// A restore (or its undo or redo) is replacing everything. Input is
  /// blocked: anything saved meanwhile would land in neither copy.
  bool _restoring = false;

  /// The transaction open in the inline editor, if any.
  RegisterEditing? _editing;

  /// Last row click, to recognise a double-click without delaying single ones.
  ({int id, DateTime at})? _lastTap;
  Timer? _toastTimer;

  /// Rows of the current account, by transaction id, from the latest build.
  Map<int, RegisterRow> _rows = const {};

  AppDatabase get db => widget.db;
  late final Backups _backups = widget.backups ?? Backups(db);

  /// The latest ledger, for comparing a backup with what's here now.
  LedgerData? _data;
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
    if (_restoring) return;
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
    if (_restoring) return;
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
    if (_restoring) return KeyEventResult.handled;
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

  /// With [confirming], a scheduled row opens to be confirmed: dated today,
  /// the amount selected (bills vary), and Enter confirms.
  void _startEdit(int id, EditField field, {bool confirming = false}) {
    final row = _rows[id];
    if (row == null) return;
    // Reconciled rows open too: payee, memo and category can still change.
    final controller = EntryRowController(
      onSubmit: (draft) => _saveEdit(row, draft, confirming: confirming),
      suggestCategory: (payee) => db.lastCategoryFor(payee, _accountId!),
    )..payeeNames = _entry.payeeNames;
    setState(() {
      _editing = (
        txnId: id,
        focus: field,
        controller: controller,
        confirming: confirming,
      );
      _selected = id;
    });
  }

  void _startConfirm(RegisterRow r) {
    if (_editing != null) {
      if (_editing!.controller.isDirty()) {
        _showToast('Save with Enter, or press Esc to discard your changes');
        return;
      }
      _cancelEdit();
    }
    _startEdit(r.txnId, EditField.amount, confirming: true);
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

  Future<String?> _saveEdit(
    RegisterRow row,
    EntryDraft d, {
    bool confirming = false,
  }) async {
    final before = await db.snapshot(row.txnId);
    final TxnSnapshot after;
    final int? owedId;
    try {
      owedId = await db.editTransaction(
        transactionId: row.txnId,
        accountId: _accountId!,
        date: d.date,
        today: today,
        payee: d.payee,
        memo: d.memo,
        counterAccountId: d.counter?.id,
        amount: d.amount,
        confirm: confirming,
        keepOwed: d.keepOwed,
      );
    } on LockedException catch (e) {
      return e.message;
    } catch (e) {
      return 'Couldn’t save: $e';
    }
    // Saved: from here a failure mustn't read as "couldn't save".
    after = await db.snapshot(row.txnId);
    _entry.payeeNames = await db.payeeNames();
    _cancelEdit();
    final name = d.payee.isEmpty ? row.payee : d.payee;
    if (confirming) {
      String money(int v) => formatMoney(v.abs(), showCents: v % 100 != 0);
      final amount = d.amount ?? row.amount;
      final early = row.date.isAfter(today);
      _did(
        '$name confirmed',
        // One action: the confirm and any rest still owed come and go
        // together.
        undo: () => db.transaction(() async {
          await db.restoreSnapshot(before);
          if (owedId case final id?) {
            _expect((await db.softDeleteMany([id])).length == 1);
          }
        }),
        redo: () => db.transaction(() async {
          await db.restoreSnapshot(after);
          if (owedId case final id?) await db.restoreMany([id]);
        }),
        message:
            '$name confirmed${early ? ' early' : ''} · ${money(amount)}'
            // What's still owed, or else the plan when it wasn't what happened.
            '${owedId != null
                ? ' · ${money(row.amount - amount)} still owed, due ${shortDate(row.date)}'
                : amount == row.amount
                ? ''
                : ', planned ${money(row.amount)}'}'
            // The date, whenever it isn't the one planned.
            '${d.date == row.date ? '' : (d.date == today ? ' · posted today, ${shortDate(today)}' : ' · posted ${shortDate(d.date)}')}',
      );
      return null;
    }
    final nowScheduled = !row.scheduled && d.date.isAfter(today);
    _did(
      '$name edited',
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

  /// Moves a row entered in the wrong account. It leaves this register, so
  /// the toast names where it went.
  Future<void> _move(RegisterRow r, AccountInfo from, AccountInfo to) async {
    final MoveRecord done;
    try {
      done = await db.moveToAccount(
        transactionId: r.txnId,
        fromAccountId: from.id,
        toAccountId: to.id,
      );
    } on LockedException catch (e) {
      _showToast('Can’t move · ${e.message}');
      return;
    } on NotFoundException catch (e) {
      _showToast('Can’t move · ${e.message}');
      return;
    } catch (e) {
      debugPrint('Move failed: $e');
      _showToast('Couldn’t move it');
      return;
    }
    _clearSelection();
    final name = r.kind == RowKind.transfer
        ? 'Transfer ${r.amount < 0 ? 'to' : 'from'} ${r.payee}'
        : r.payee;
    _did(
      '$name moved to ${to.name}',
      undo: () => db.undoMove(done),
      redo: () => db.redoMove(done),
      message:
          '$name moved to ${to.name}'
          '${r.cleared == Cleared.uncleared ? '' : ' · uncleared there until it clears'}',
    );
  }

  // ---------- accounts ----------

  void _openNewAccount() => setState(() {
    _endReconcile();
    _section = AppSection.ledger;
    _newAccount = true;
    _selected = null;
    _editing = null;
    _adding = false;
  });

  Future<void> _createAccount(String name, AccountType type) async {
    final int id;
    try {
      id = await db.createAccount(name: name, type: type);
    } catch (e) {
      debugPrint('Add account failed: $e');
      _showToast('Couldn’t add the account');
      return;
    }
    if (!mounted) return;
    setState(() {
      _newAccount = false;
      _accountId = id;
      _pendingAccountId = id;
    });
    // The account appearing is the confirmation; ⌘Z takes it away again, but
    // only while it's still empty: undo never deletes rows unasked.
    _did(
      '$name added',
      undo: () async => _expect(await db.deleteEmptyAccount(id)),
      redo: () => db.undeleteAccount(DeletedAccount(id, const [])),
      toast: false,
    );
  }

  /// The balance question answered. Empty posts nothing: the account starts
  /// at ₮0 with the entry row open.
  Future<void> _startAccount(
    AccountInfo account,
    int? typed,
    DateTime date,
  ) async {
    if (typed == null || typed == 0) {
      _startedEmpty.add(account.id);
      _newEntry();
      return;
    }
    // A card's balance is typed as what's owed, positive, as the bank shows it.
    final balance = account.isOwed ? -typed : typed;
    final int id;
    try {
      id = await db.postOpeningBalance(
        accountId: account.id,
        date: date,
        balance: balance,
      );
    } catch (e) {
      debugPrint('Opening balance failed: $e');
      _showToast('Couldn’t save the balance');
      return;
    }
    // The bank's number already holds everything settled, so what's left to
    // type is what hasn't: the entry row opens, and the toast says so.
    _newEntry();
    _did(
      'Opening balance',
      undo: () async => _expect((await db.softDeleteMany([id])).length == 1),
      redo: () => db.restoreMany([id]),
      message:
          'Started at ${_money(typed)}${account.isOwed ? ' owed' : ''} · '
          'add only what hasn’t settled yet',
    );
  }

  /// Runs an account write; a failure says so instead of vanishing.
  Future<bool> _accountWrite(Future<void> Function() write) async {
    try {
      await write();
      return mounted;
    } catch (e) {
      debugPrint('Account change failed: $e');
      if (mounted) _showToast('Couldn’t change the account');
      return false;
    }
  }

  /// The open row, editor and entry row belong to the account leaving view.
  void _leaveAccount(AccountInfo account) {
    if (_accountId != account.id) return;
    _endReconcile();
    setState(() {
      _selected = null;
      _editing = null;
      _adding = false;
    });
  }

  Future<void> _rename(AccountInfo account, String name) async {
    final old = account.name;
    if (!await _accountWrite(() => db.renameAccount(account.id, name))) return;
    _did(
      'Renamed $old to $name',
      undo: () => db.renameAccount(account.id, old),
      redo: () => db.renameAccount(account.id, name),
    );
  }

  Future<void> _changeKind(AccountInfo account) async {
    final old = account.type;
    final next = account.isOwed ? AccountType.asset : AccountType.liability;
    var flipped = false;
    if (!await _accountWrite(
      () async => flipped = await db.setAccountType(account.id, next),
    )) {
      return;
    }
    final kind = next == AccountType.liability
        ? 'card or loan'
        : 'bank account';
    _did(
      '${account.name} is now a $kind',
      message: flipped
          ? '${account.name} is now a $kind · its opening balance flipped with it'
          : null,
      undo: () => db.setAccountType(account.id, old),
      redo: () => db.setAccountType(account.id, next),
    );
  }

  Future<void> _archive(LedgerData data, AccountInfo account) async {
    final warnings = _archiveWarnings(
      account,
      data.balanceOf(account.id),
      data.registerFor(account.id).scheduled,
    );
    // Nothing left behind, nothing to read first.
    if (warnings.isNotEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (_) => _AccountWarning(
          title: 'Archive ${account.name}?',
          lines: warnings,
          action: 'Archive ${account.name}',
          danger: false,
        ),
      );
      if (go != true || !mounted) return;
    }
    await _setArchived(account, true);
  }

  Future<void> _setArchived(AccountInfo account, bool archived) async {
    if (archived) _leaveAccount(account);
    if (!await _accountWrite(() => db.setArchived(account.id, archived))) {
      return;
    }
    if (!archived) {
      setState(() {
        _section = AppSection.ledger;
        _accountId = account.id;
      });
    }
    _did(
      archived
          ? '${account.name} archived'
          : '${account.name} back in the sidebar',
      message: archived
          ? '${account.name} archived · Settings brings it back'
          : null,
      undo: () => db.setArchived(account.id, !archived),
      redo: () => db.setArchived(account.id, archived),
    );
  }

  Future<void> _deleteAccount(LedgerData data, AccountInfo account) async {
    final preview = data.deletePreview(account.id);
    // Nothing in it and nothing kept elsewhere: nothing to read first.
    final empty = preview.rows == 0 && preview.keptOn.isEmpty;
    final go =
        empty ||
        await showDialog<bool>(
              context: context,
              builder: (_) => _AccountWarning(
                title: 'Delete ${account.name}?',
                lines: _deleteWarnings(
                  account,
                  data.balanceOf(account.id),
                  preview,
                ),
                action: 'Delete ${account.name}',
                danger: true,
              ),
            ) ==
            true;
    if (!go || !mounted) return;
    _leaveAccount(account);
    late DeletedAccount done;
    if (!await _accountWrite(
      () async => done = await db.deleteAccount(account.id),
    )) {
      return;
    }
    // Final, as the warning says: no Undo on the toast. ⌘Z still works, as
    // it does for everything this session.
    _did(
      '${account.name} deleted',
      undo: () => db.undeleteAccount(done),
      redo: () async => done = await db.deleteAccount(account.id),
      toast: false,
    );
    _showToast('${account.name} deleted');
  }

  /// Saves a copy of everything where the user picks: another drive, a USB
  /// stick. The daily automatic copies stay on this disk.
  Future<void> _backUpTo() async {
    final now = widget.clock();
    final FileSaveLocation? location;
    try {
      location = await getSaveLocation(
        suggestedName: 'BetterBudget ${fullDate(now)}.sqlite',
        confirmButtonText: 'Back Up',
      );
    } catch (e) {
      debugPrint('Save dialog failed: $e');
      _showToast('Couldn’t open the save dialog');
      return;
    }
    if (location == null) return;
    try {
      await _backups.saveTo(location.path, now);
    } catch (e) {
      debugPrint('Back up failed: $e');
      _showToast('Couldn’t back up · check the drive has room and try again');
      return;
    }
    final name = location.path.split(RegExp(r'[/\\]')).last;
    _showToast('Backed up · $name');
  }

  /// Puts back a backup: the daily copies (the picker opens on their folder)
  /// or one saved elsewhere. Shows what it holds against what's here, saves
  /// what's here first, and can be undone.
  Future<void> _restoreFrom() async {
    if (_restoring) return;
    // A restore replaces the rows an open edit or reconcile points at.
    if (_editing?.controller.isDirty() ?? false) {
      _showToast('Save with Enter, or press Esc to discard your changes');
      return;
    }
    _cancelEdit();
    _endReconcile();
    setState(() {
      _selected = null;
      _adding = false;
    });
    final now = widget.clock();
    final XFile? picked;
    try {
      picked = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'BetterBudget backup', extensions: ['sqlite']),
        ],
        initialDirectory: (await _backups.folder())?.path,
        confirmButtonText: 'Choose',
      );
    } catch (e) {
      debugPrint('Open dialog failed: $e');
      _showToast('Couldn’t open the file dialog');
      return;
    }
    if (picked == null) return;
    final RestoreCandidate candidate;
    try {
      candidate = await _backups.inspect(picked.path, now);
    } on RestoreException catch (e) {
      _showToast(e.message);
      return;
    } catch (e) {
      debugPrint('Restore check failed: $e');
      _showToast('Couldn’t read that backup');
      return;
    }
    if (!mounted) return;
    final data = _data;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _RestoreDialog(
        candidate: candidate,
        transactionsNow: data?.txns.length ?? 0,
        accountsNow: data?.balanceSheetAccounts.length ?? 0,
      ),
    );
    if (confirmed != true) {
      await _backups.discard(candidate);
      return;
    }
    final RestoreRecord done;
    try {
      done = await _whileRestoring(() => _backups.restore(candidate, now));
    } catch (e) {
      debugPrint('Restore failed: $e');
      _showToast('Couldn’t restore · nothing was changed');
      return;
    }
    if (!mounted) return;
    // Earlier actions point at rows the restore replaced.
    _history.clear();
    _redo.clear();
    final label = 'Restored the copy from ${fullDate(candidate.madeAt)}';
    _did(
      label,
      undo: () => _whileRestoring(
        () => _backups.replaceWith(done.before, widget.clock()),
      ),
      redo: () => _whileRestoring(
        () => _backups.replaceWith(done.restored, widget.clock()),
      ),
      message: '$label · what you had is saved',
    );
  }

  /// Runs a whole-ledger replace with input blocked, then refreshes what the
  /// entry row suggests, since the payees changed with everything else.
  Future<T> _whileRestoring<T>(Future<T> Function() replace) async {
    setState(() => _restoring = true);
    try {
      return await replace();
    } finally {
      if (mounted) setState(() => _restoring = false);
      _entry.payeeNames = await db.payeeNames();
    }
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
              _data = data;
              final accounts = data.openAccounts;
              final current = data.accounts[_accountId];
              // Archived or deleted since: the first open one takes over.
              final account = accounts.contains(current)
                  ? current!
                  : accounts.firstOrNull;
              // A just-added account isn't in this snapshot yet; it will be
              // in the next, so keep it chosen.
              if (current != null && current.id == _pendingAccountId) {
                _pendingAccountId = null;
              }
              if (account != null &&
                  _accountId != account.id &&
                  (current != null ||
                      _pendingAccountId == null ||
                      _accountId != _pendingAccountId)) {
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
                        selected: _newAccount ? null : account?.id,
                        backupHealth: _backups.health,
                        now: widget.clock,
                        onSelect: (id) => setState(() {
                          if (id != _accountId) _endReconcile();
                          _section = AppSection.ledger;
                          _newAccount = false;
                          _accountId = id;
                          _selected = null;
                        }),
                        addingAccount: _newAccount,
                        onAddAccount: _openNewAccount,
                      ),
                      Expanded(
                        child: switch (_section) {
                          AppSection.ledger
                              when _newAccount || account == null =>
                            _NewAccountPage(
                              onCreate: _createAccount,
                              onCancel: account == null
                                  ? null
                                  : () => setState(() => _newAccount = false),
                            ),
                          AppSection.ledger => _body(data, account!),
                          AppSection.settings => _SettingsPage(
                            health: _backups.health,
                            now: widget.clock,
                            onBackUp: _backUpTo,
                            onRestore: _restoreFrom,
                            archived: data.archivedAccounts.isEmpty
                                ? null
                                : _ArchivedAccounts(
                                    data: data,
                                    onUnarchive: (a) => _setArchived(a, false),
                                  ),
                          ),
                          _ => _PlaceholderSection(section: _section),
                        },
                      ),
                    ],
                  ),
                  if (_restoring)
                    const Positioned.fill(
                      child: ModalBarrier(
                        dismissible: false,
                        color: Color(0x66000000),
                      ),
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
    // Nothing in it yet: ask what's in it first.
    final fresh =
        register.posted.isEmpty &&
        register.scheduled.isEmpty &&
        !_startedEmpty.contains(account.id);
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
              Transform.translate(
                // The name's own padding (it renames in place) stays out of
                // the left edge the rest of the page lines up on.
                offset: const Offset(-8, 0),
                child: _AccountTitle(
                  account: account,
                  onRename: (name) => _rename(account, name),
                  onChangeKind: () => _changeKind(account),
                  onArchive: () => _archive(data, account),
                  onDelete: () => _deleteAccount(data, account),
                ),
              ),
              const Spacer(),
              _SearchField(
                controller: _search,
                focusNode: _searchFocus,
                onChanged: () => setState(() {}),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (fresh)
            Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _AccountStart(
                  key: ValueKey('start-${account.id}'),
                  account: account,
                  today: today,
                  onStart: (balance, date) =>
                      _startAccount(account, balance, date),
                ),
              ),
            )
          else ...[
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
                      onLock: () => _lockReconcile(
                        account,
                        _reconcileCheck(data, summary),
                      ),
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
                accountName: account.name,
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
                transferTargets: data.openAccounts
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
                  onConfirm: _startConfirm,
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
                  onMove: (r, to) => _move(r, account, to),
                ),
              ),
            ),
          ],
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
    required this.backupHealth,
    required this.now,
    required this.addingAccount,
    required this.onAddAccount,
  });
  final LedgerData data;
  final bool addingAccount;
  final VoidCallback onAddAccount;
  final ValueListenable<BackupHealth> backupHealth;
  final DateTime Function() now;
  final AppSection section;
  final ValueChanged<AppSection> onSection;
  final int? selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<AccountInfo>>{};
    for (final a in data.openAccounts) {
      groups.putIfAbsent(a.group ?? 'Accounts', () => []).add(a);
    }
    // Archived accounts still hold money, or debt.
    final net = data.balanceSheetAccounts.fold(
      0,
      (s, a) => s + data.balanceOf(a.id),
    );
    // So net worth isn't a mystery sum of the accounts above it.
    final archived = data.archivedAccounts.fold(
      0,
      (s, a) => s + data.balanceOf(a.id),
    );

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
              _AddAccountTile(active: addingAccount, onTap: onAddAccount),
              const SizedBox(height: 10),
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
          // Settings, above Net worth, laid out like a section header so its
          // icon and label line up with theirs.
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            // Full width, like the section headers, so hover fills the row.
            child: ValueListenableBuilder(
              valueListenable: backupHealth,
              builder: (context, health, _) => _SettingsGear(
                active: section == AppSection.settings,
                alert: health.alarmingAt(now()),
                onTap: () => onSection(AppSection.settings),
              ),
            ),
          ),
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
                if (archived != 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'incl. ${_money(archived)} in archived',
                      key: const ValueKey('net-worth-archived'),
                      style: onest(11.5, color: Mid.ink3, tabular: true),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens Settings, above Net worth. A coral dot says something there needs attention (the
/// daily copy is failing), since the gear is all that shows of it.
class _SettingsGear extends StatelessWidget {
  const _SettingsGear({
    required this.active,
    required this.alert,
    required this.onTap,
  });
  final bool active;
  final bool alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    // Only worth a tooltip when the dot needs explaining.
    message: alert ? 'The daily copy is failing' : '',
    child: Hoverable(
      key: const ValueKey('settings'),
      onTap: onTap,
      builder: (h) => Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: h && !active ? Mid.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.settings_outlined,
                  size: 16,
                  color: active ? Mid.blue : Mid.ink3,
                ),
                if (alert)
                  Positioned(
                    top: -2,
                    right: -3,
                    child: Container(
                      key: const ValueKey('settings-alert'),
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Mid.coral,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Text(
              'Settings',
              style: onest(
                14,
                weight: active ? 600 : 500,
                color: active ? Mid.ink : Mid.ink2,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Settings, one section per kind. Backups is the first.
class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.health,
    required this.now,
    required this.onBackUp,
    required this.onRestore,
    this.archived,
  });
  final ValueListenable<BackupHealth> health;

  /// Archived accounts, when there are any.
  final Widget? archived;
  final DateTime Function() now;
  final VoidCallback onBackUp;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    Widget line(String label, Widget value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: onest(13.5, color: Mid.ink3)),
          ),
          Expanded(child: value),
        ],
      ),
    );
    String when(DateTime t) {
      String two(int v) => v.toString().padLeft(2, '0');
      final today = dateOnly(now());
      final day = dateOnly(t) == today
          ? 'Today'
          : dateOnly(t) == today.subtract(const Duration(days: 1))
          ? 'Yesterday'
          : fullDate(t);
      return '$day ${two(t.hour)}:${two(t.minute)}';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
      child: Align(
        alignment: Alignment.topLeft,
        // Scrolls once archived accounts make it taller than the window.
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // As tall as an account's title row (it has search), so the
                // title doesn't jump when switching.
                SizedBox(
                  height: 36,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Settings',
                      style: onest(22, weight: 600, letterSpacing: -0.3),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
                  decoration: BoxDecoration(
                    color: Mid.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Mid.rule),
                  ),
                  child: ValueListenableBuilder(
                    valueListenable: health,
                    builder: (context, h, _) {
                      final failing = h.alarmingAt(now());
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Backups', style: onest(16, weight: 600)),
                          const SizedBox(height: 16),
                          line(
                            'Daily copy',
                            failing
                                ? Text(
                                    'Failing${h.newest == null ? '' : ' · the last one is from ${when(h.newest!)}'}. '
                                    'Check the disk has room, and back up to another drive.',
                                    key: const ValueKey('backup-failed'),
                                    style: onest(13.5, color: Mid.coral),
                                  )
                                : Text(
                                    h.newest == null
                                        ? 'None yet · one is made each day the app is open'
                                        : '${when(h.newest!)} · on this computer',
                                    style: onest(13.5, color: Mid.ink),
                                  ),
                          ),
                          line(
                            'Kept',
                            Text(
                              'The newest 14, plus the first of each month for a year',
                              style: onest(13.5, color: Mid.ink2),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              BarButton(
                                key: const ValueKey('back-up'),
                                label: 'Back up to…',
                                leading: const Icon(
                                  Icons.save_alt_rounded,
                                  size: 14,
                                  color: Mid.ink3,
                                ),
                                onTap: onBackUp,
                              ),
                              BarButton(
                                key: const ValueKey('restore'),
                                label: 'Restore from…',
                                leading: const Icon(
                                  Icons.settings_backup_restore_rounded,
                                  size: 14,
                                  color: Mid.ink3,
                                ),
                                onTap: onRestore,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'The daily copies are on this computer, so they won’t '
                            'help if it’s lost or breaks: back up to another drive '
                            'or a USB stick now and then. Restoring saves what you '
                            'have first, and Undo brings it back.',
                            style: onest(13, color: Mid.ink3),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                if (archived != null) ...[
                  const SizedBox(height: 16),
                  archived!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks before a restore replaces everything, with what the backup holds
/// beside what's here now.
class _RestoreDialog extends StatelessWidget {
  const _RestoreDialog({
    required this.candidate,
    required this.transactionsNow,
    required this.accountsNow,
  });
  final RestoreCandidate candidate;
  final int transactionsNow;
  final int accountsNow;

  @override
  Widget build(BuildContext context) {
    final made = candidate.madeAt;
    String two(int v) => v.toString().padLeft(2, '0');
    String counts(int t, int a) =>
        '$t ${t == 1 ? 'transaction' : 'transactions'} · $a ${a == 1 ? 'account' : 'accounts'}';
    Widget line(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: onest(13, color: Mid.ink3)),
          ),
          Text(
            value,
            style: onest(
              13.5,
              color: strong ? Mid.ink : Mid.ink2,
              tabular: true,
            ),
          ),
        ],
      ),
    );
    return Dialog(
      backgroundColor: Mid.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Mid.rule),
      ),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): () =>
              Navigator.of(context).pop(true),
        },
        child: Focus(
          autofocus: true,
          child: SizedBox(
            width: 460,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Restore this backup?',
                    style: onest(17, weight: 600, letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 16),
                  line(
                    'Backup from',
                    '${fullDate(made)}  ${two(made.hour)}:${two(made.minute)}',
                    strong: true,
                  ),
                  line(
                    'It holds',
                    counts(candidate.transactions, candidate.accounts),
                    strong: true,
                  ),
                  line('Here now', counts(transactionsNow, accountsNow)),
                  const SizedBox(height: 6),
                  Text(
                    'Everything here is replaced by the backup. What you have '
                    'now is saved first, and Undo brings it back.',
                    style: onest(13, color: Mid.ink2),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      BarButton(
                        key: const ValueKey('restore-cancel'),
                        label: 'Cancel',
                        onTap: () => Navigator.of(context).pop(false),
                      ),
                      _PrimaryButton(
                        key: const ValueKey('restore-confirm'),
                        label: 'Restore',
                        icon: Icons.settings_backup_restore_rounded,
                        tooltip: 'Enter',
                        onTap: () => Navigator.of(context).pop(true),
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
    this.tooltip,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// Its shortcut; ⌘N (Ctrl+N) unless given.
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip ?? (_isMac ? '⌘N' : 'Ctrl+N'),
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
