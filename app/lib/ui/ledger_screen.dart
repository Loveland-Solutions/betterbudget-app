import 'dart:async';
import 'dart:io' show File;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/backup.dart';
import '../data/database.dart';
import '../data/demo_seed.dart';
import '../data/encryption.dart';
import '../data/keys.dart';
import '../domain/budget.dart';
import '../domain/forecast.dart';
import '../domain/ledger.dart';
import '../domain/money.dart';
import '../domain/pay.dart';
import '../domain/readiness.dart';
import '../import/mapping.dart';
import '../import/sheet.dart';
import 'balance_header.dart';
import 'entry_row.dart';
import 'reconcile.dart';
import 'recovery_key_screen.dart';
import 'register.dart';
import 'appearance.dart';
import 'language.dart';
import 'brand.dart';
import 'data_words.dart';
import 'theme.dart';

part 'accounts.dart';
part 'budget.dart';
part 'import_dialog.dart';
part 'pay_setup.dart';
part 'savings.dart';

bool get _isMac =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Top-level sections. Savings holds the steps to getting financially
/// prepared (rule 25). Settings opens from the gear
/// under Net worth, not from a section header.
enum AppSection { ledger, budget, savings, settings }

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({
    super.key,
    required this.db,
    this.clock = DateTime.now,
    this.backups,
    this.encrypted = false,
    this.recoveryKeySaved = false,
    this.checkRecoveryKey,
    this.onRecoveryKeyChecked,
    this.startupNotice,
    this.offerRestore = false,
  });

  final AppDatabase db;

  /// The app's backups, whose daily copy runs from main. Tests may leave it
  /// out; one is made for "Back up to…" and "Restore from…".
  final Backups? backups;
  final DateTime Function() clock;

  /// The ledger is encrypted (ADR 0001): Settings says so, and whether the
  /// recovery key was saved when it was shown. False in tests.
  final bool encrypted;

  /// The recovery key was saved, copied, typed or checked (kept beside the
  /// data key, not in the ledger).
  final bool recoveryKeySaved;

  /// Whether a typed key is this ledger's, for "Check my recovery key…".
  final Future<bool> Function(RecoveryKey key)? checkRecoveryKey;
  final VoidCallback? onRecoveryKeyChecked;

  /// Said once, as a toast, when the ledger opens: what encrypting its old
  /// copies did.
  final String? startupNotice;

  /// A key was just typed on a computer with no ledger: offer to open a
  /// backup before anything else.
  final bool offerRestore;

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

  /// All accounts is open in the ledger, instead of one account.
  bool _all = false;

  /// All accounts, narrowed to the rows filed under this category.
  int? _categoryFilter;

  /// All accounts, narrowed to a budget period (month or pay period): a
  /// category's Spent opened from Budget shows the period it was in.
  BudgetSpan? _periodFilter;

  /// Bumped by Rename in the sidebar's right-click menu: the account opens
  /// with its name ready to edit in the header.
  var _renameRequest = 0;
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
    // Each pay schedule's next payday is scheduled before the first look.
    _ledger = Stream.fromFuture(
      seedDemoIfEmpty(db, today).then((_) => db.ensurePaydays(today)),
    ).asyncExpand((_) => db.watchLedger());
    _entry = EntryRowController(
      onSubmit: _post,
      suggestCategory: (payee) =>
          db.lastCategoryFor(payee, _entryAccountId ?? _accountId!),
    );
    _keySaved = widget.recoveryKeySaved;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.startupNotice case final n?) _showToast(n);
      if (widget.offerRestore) _offerRestore();
    });
  }

  late bool _keySaved;

  /// On a new computer, the ledger usually comes from a backup saved with
  /// Back up to…: offer it first. Starting empty is one click away.
  Future<void> _offerRestore() async {
    final t = context.t;
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Mid.panel,
        title: Text(t.ledgerOfferRestoreTitle, style: onest(17, weight: 600)),
        content: SizedBox(
          width: 440,
          child: Text(
            t.ledgerOfferRestoreBody,
            style: onest(13.5, color: Mid.ink2, height: 1.4),
          ),
        ),
        actions: [
          BarButton(
            key: const ValueKey('offer-restore-empty'),
            label: t.ledgerStartEmpty,
            onTap: () => Navigator.of(context).pop(false),
          ),
          FilledButton(
            key: const ValueKey('offer-restore-open'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.ledgerOpenABackup),
          ),
        ],
      ),
    );
    if (open == true && mounted) await _restoreFrom();
  }

  Future<void> _checkRecoveryKey() async {
    final check = widget.checkRecoveryKey;
    if (check == null) return;
    final ok = await showCheckRecoveryKeyDialog(context, check);
    if (ok && mounted) {
      setState(() => _keySaved = true);
      widget.onRecoveryKeyChecked?.call();
    }
  }

  /// Where the new-transaction row posts: the open account, or in All
  /// accounts the one picked in the row.
  int? get _entryAccountId => _all ? _entry.account?.id : _accountId;

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

  /// A category typed that didn't exist yet is made in the same write as
  /// the row: income when the money comes in ([fallback] is the row's own
  /// amount when this one can't change, e.g. reconciled).
  Future<int?> _makeCategory(EntryDraft d, {int fallback = 0}) async {
    final name = d.newCategory;
    if (name == null) return null;
    return db.createCategory(name, income: (d.amount ?? fallback) > 0);
  }

  /// Wraps an undo and redo so a category made with the row goes and comes
  /// back with it: one ⌘Z for both.
  ({Future<void> Function() undo, Future<void> Function() redo}) _alsoCategory(
    int? made,
    Future<void> Function() undo,
    Future<void> Function() redo,
  ) => made == null
      ? (undo: undo, redo: redo)
      : (
          // Each in one write: a half-done undo would leave the row gone and
          // the category behind, or the reverse.
          undo: () => db.transaction(() async {
            await undo();
            _expect(await db.deleteEmptyAccount(made));
          }),
          redo: () => db.transaction(() async {
            await db.undeleteAccount(DeletedAccount(made, const []));
            await redo();
          }),
        );

  Future<String?> _post(EntryDraft d) async {
    final t = context.t;
    int? made;
    try {
      late final int id;
      // One write: a crash between them can't leave an empty category.
      await db.transaction(() async {
        made = await _makeCategory(d);
        final here = d.account?.id ?? _accountId!;
        final other = d.otherAmount;
        final amount = d.amount!;
        id = other != null && d.counter != null
            // Between currencies: both sides, from the side money leaves.
            ? await db.postExchange(
                fromAccountId: amount < 0 ? here : d.counter!.id,
                toAccountId: amount < 0 ? d.counter!.id : here,
                sent: amount < 0 ? amount.abs() : other,
                received: amount < 0 ? other : amount.abs(),
                date: d.date,
                today: today,
                payee: d.payee,
                memo: d.memo,
              )
            : await db.postSimple(
                accountId: here,
                date: d.date,
                today: today,
                payee: d.payee,
                // The new-transaction row always supplies one or the other.
                counterAccountId: made ?? d.counter!.id,
                amount: amount,
                memo: (d.memo?.trim().isEmpty ?? true) ? null : d.memo!.trim(),
              );
      });
      _entry.payeeNames = await db.payeeNames();
      final pair = _alsoCategory(
        made,
        () async => _expect((await db.softDeleteMany([id])).length == 1),
        () => db.restoreMany([id]),
      );
      // A row that won't show under the filter or search in force says where
      // it went, or it looks lost and gets typed again.
      final hidden =
          _search.text.trim().isNotEmpty ||
          (_all &&
              _categoryFilter != null &&
              (made ?? d.counter?.id) != _categoryFilter);
      final added = d.account == null
          ? t.ledgerAdded(d.payee)
          : t.ledgerAddedTo(d.payee, d.account!.name);
      _did(
        t.ledgerAdded(d.payee),
        undo: pair.undo,
        redo: pair.redo,
        toast: made != null || hidden,
        // Whole clauses joined by " · ", as every toast is.
        message: made != null || hidden
            ? [
                added,
                if (made != null)
                  d.amount! > 0
                      ? t.ledgerNewIncomeCategory(d.newCategory!)
                      : t.ledgerNewCategory(d.newCategory!),
                if (made != null && d.date.isAfter(today))
                  t.ledgerScheduledFor(sayFullDate(t, d.date)),
                if (hidden) t.ledgerNotInThisView,
              ].join(' · ')
            : null,
      );
      if (made == null && !hidden && d.date.isAfter(today)) {
        _showToast(t.ledgerScheduledToast(sayFullDate(t, d.date)));
      }
      return null;
    } on DbException catch (e) {
      return t.ledgerCouldntSave(dbProblem(t, e));
    } catch (e) {
      return t.ledgerCouldntSave('$e');
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
              context.t.ledgerUndoNewerFirst(_isMac ? '⌘Z' : 'Ctrl+Z'),
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
      _showToast(context.t.ledgerNothingToUndo);
      return;
    }
    _history.removeLast();
    try {
      await a.undo();
    } catch (e) {
      if (mounted) _showToast(context.t.ledgerCouldntUndo(a.label));
      return;
    }
    _redo.add(a);
    if (mounted) _showToast(context.t.ledgerUndone(a.label));
  }

  Future<void> _redoLast() async {
    if (_restoring) return;
    final a = _redo.lastOrNull;
    if (a == null) {
      _showToast(context.t.ledgerNothingToRedo);
      return;
    }
    _redo.removeLast();
    try {
      await a.redo();
    } catch (e) {
      if (mounted) _showToast(context.t.ledgerCouldntRedo(a.label));
      return;
    }
    _history.add(a);
    if (mounted) _showToast(context.t.ledgerRedone(a.label));
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
    // Row keys act on the register; elsewhere its selection is out of sight.
    if (_section != AppSection.ledger ||
        _typing ||
        keys.isMetaPressed ||
        keys.isControlPressed ||
        keys.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final row = _rows[_selected];
    if (row == null) {
      // Esc with nothing selected takes the category filter off.
      if (event.logicalKey == LogicalKeyboardKey.escape &&
          (_categoryFilter != null || _periodFilter != null) &&
          _all) {
        setState(() {
          _categoryFilter = null;
          _periodFilter = null;
        });
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
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
        _showToast(context.t.ledgerSaveOrDiscard);
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
      _showToast(context.t.ledgerFinishReconcileFirst);
      return;
    }
    if (_editing != null) {
      if (_editing!.controller.isDirty()) {
        _showToast(context.t.ledgerSaveOrDiscard);
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

  /// The payday after [row] by its pay plan, so the forecast can run
  /// through the whole period. Pay scheduled by hand uses the plan for that
  /// category and account, unless that plan has its own payday ahead (then
  /// [row] is extra, a bonus, and the plan's payday is the next one). Null
  /// with no plan.
  ({DateTime date, int amount})? _paydayAfter(
    LedgerData data,
    List<RegisterRow> scheduled,
    RegisterRow row,
  ) {
    final plan =
        data.paySchedules.where((p) => p.id == row.payScheduleId).firstOrNull ??
        data.paySchedules
            .where(
              (p) =>
                  p.accountId == row.accountId &&
                  p.categoryId == row.categoryId,
            )
            .firstOrNull;
    if (plan == null) return null;
    if (row.payScheduleId == null &&
        scheduled.any((r) => r.payScheduleId == plan.id)) {
      return null;
    }
    // From the payday it was planned as, by amount for split pay: one moved
    // a few days by hand mustn't make that same payday the next.
    final next = plan.nextAfter(plan.plannedFor(row.date, paid: row.amount));
    return (date: next, amount: plan.amountOn(next));
  }

  /// Esc on the new-transaction row: it closes, and ⌘Z works again at
  /// once. The row drops focus on its way out, which left the screen's keys
  /// unreachable until a click.
  Widget _searchBox() => _SearchField(
    controller: _search,
    focusNode: _searchFocus,
    onChanged: () => setState(() {}),
  );

  void _closeEntry() {
    setState(() => _adding = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keysBack();
    });
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
      suggestCategory: (payee) => db.lastCategoryFor(payee, row.accountId),
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
        _showToast(context.t.ledgerSaveOrDiscard);
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
    final t = context.t;
    final before = await db.snapshot(row.txnId);
    final TxnSnapshot after;
    final int? owedId;
    int? made;
    try {
      owedId = await db.transaction(() async {
        made = await _makeCategory(d, fallback: row.amount);
        return db.editTransaction(
          transactionId: row.txnId,
          accountId: row.accountId,
          date: d.date,
          today: today,
          payee: d.payee,
          memo: d.memo,
          counterAccountId: made ?? d.counter?.id,
          amount: d.amount,
          counterAmount: d.otherAmount,
          confirm: confirming,
          keepOwed: d.keepOwed,
        );
      });
    } on LockedException catch (e) {
      return dbProblem(t, e);
    } on DbException catch (e) {
      return t.ledgerCouldntSave(dbProblem(t, e));
    } catch (e) {
      return t.ledgerCouldntSave('$e');
    }
    // Saved: from here a failure mustn't read as "couldn't save".
    after = await db.snapshot(row.txnId);
    _entry.payeeNames = await db.payeeNames();
    _cancelEdit();
    final name = d.payee.isEmpty ? rowPayee(t, row) : d.payee;
    if (confirming) {
      String money(int v) => formatMoney(
        v.abs(),
        showCents: v % 100 != 0,
        currency: _data?.accounts[row.accountId]?.currency ?? Currency.mnt,
      );
      final amount = d.amount ?? row.amount;
      final early = row.date.isAfter(today);
      // A payday confirmed: its schedule's next one, from the plan. Only
      // its own: confirming a bill never touches pay.
      var next = const <int>[];
      final schedule = row.payScheduleId;
      if (schedule != null) {
        try {
          next = await db.ensurePaydays(today, only: schedule);
        } catch (e) {
          debugPrint('Scheduling the next payday failed: $e');
        }
      }
      final pair = _alsoCategory(
        made,
        // One action: the confirm, any rest still owed and the next payday
        // come and go together.
        () => db.transaction(() async {
          await db.dropPaydays(next);
          await db.restoreSnapshot(before);
          if (owedId case final id?) {
            _expect((await db.softDeleteMany([id])).length == 1);
          }
        }),
        () => db.transaction(() async {
          await db.restoreSnapshot(after);
          if (owedId case final id?) await db.restoreMany([id]);
          if (schedule != null) await db.bringBackPaydays(next, schedule);
        }),
      );
      // Under an estimate is the direction that hurts: said once, here.
      final under = row.estimate == null || amount >= row.estimate!
          ? null
          : row.estimate! - amount;
      final when = early ? 'early' : 'other';
      _did(
        t.ledgerConfirmed(name),
        undo: pair.undo,
        redo: pair.redo,
        message: [
          // What's still owed, or else the plan when it wasn't what happened.
          if (owedId == null && amount != row.amount)
            t.ledgerConfirmedAmountPlanned(
              when,
              name,
              money(amount),
              money(row.amount),
            )
          else
            t.ledgerConfirmedAmount(when, name, money(amount)),
          if (owedId != null)
            t.ledgerStillOwed(money(row.amount - amount), sayDate(t, row.date)),
          // The date, whenever it isn't the one planned.
          if (d.date != row.date)
            d.date == today
                ? t.ledgerPostedToday(sayDate(t, today))
                : t.ledgerPostedOn(sayDate(t, d.date)),
          if (under != null) t.ledgerUnderEstimate(money(under)),
        ].join(' · '),
      );
      return null;
    }
    final nowScheduled = !row.scheduled && d.date.isAfter(today);
    final pair = _alsoCategory(
      made,
      () => db.restoreSnapshot(before),
      () => db.restoreSnapshot(after),
    );
    _did(
      t.ledgerEdited(name),
      undo: pair.undo,
      redo: pair.redo,
      message: nowScheduled
          ? t.ledgerMovedToFuture(sayFullDate(t, d.date))
          : made != null
          ? '${t.ledgerChangesSaved} · ${t.ledgerNewCategory(d.newCategory!)}'
          : t.ledgerChangesSaved,
    );
    return null;
  }

  // ---------- reconcile ----------

  void _startReconcile(LedgerData data, AccountInfo account) {
    if (_editing != null) {
      if (_editing!.controller.isDirty()) {
        _showToast(context.t.ledgerSaveOrDiscard);
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
    final t = context.t;
    final s = _reconcile!;
    final date = parseEntryDate(s.date.text, today);
    final last = summary.reconciledOn;
    final problem = date == null
        // The form to type, so numeric in both languages.
        ? t.ledgerTypeADate(shortDate(today))
        : date.isAfter(today)
        ? t.ledgerStatementAfterToday
        : last != null && date.isBefore(last)
        ? t.ledgerAlreadyReconciled(sayDate(t, last))
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
    final t = context.t;
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
      _showToast(t.ledgerClearedRowsChanged);
      return;
    } on ReconcileDateException catch (e) {
      _showToast(dbProblem(t, e));
      return;
    } finally {
      _locking = false;
    }
    _endReconcile();
    final n = done.entryIds.length - (done.adjustmentTxnId == null ? 0 : 1);
    final off = c.statement! - c.cleared;
    final shownOff = account.isOwed ? -off : off;
    final label = t.ledgerReconciledThrough(account.name, sayDate(t, c.date!));
    _did(
      label,
      undo: () => db.unreconcile(done),
      redo: () => db.relock(done),
      message: [
        label,
        if (n != 0) t.ledgerLocked(n),
        if (done.adjustmentTxnId != null)
          t.ledgerAdjustmentAdded(
            formatMoney(
              shownOff.abs(),
              showCents: off % 100 != 0,
              currency: account.currency,
            ),
          ),
      ].join(' · '),
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
    if (!mounted) return;
    _did(
      next == Cleared.cleared
          ? context.t.ledgerMarkedCleared(rowPayee(context.t, r))
          : context.t.ledgerMarkedUncleared(rowPayee(context.t, r)),
      undo: () async => _expect(
        (await db.setClearedMany(previous)).length == previous.length,
      ),
      redo: () async =>
          _expect((await db.setClearedMany({r.entryId: next})).length == 1),
      toast: false,
    );
  }

  String _lockMessage(RegisterRow r) => r.lockedIn != null
      ? context.t.ledgerCantDeleteTransfer(r.lockedIn!)
      : context.t.ledgerCantDeleteReconciled;

  Future<void> _delete(RegisterRow r) async {
    final deleted = await db.softDeleteMany([r.txnId]);
    if (!mounted) return;
    if (deleted.isEmpty) {
      _showToast(_lockMessage(r));
      return;
    }
    _clearSelection();
    _did(
      context.t.ledgerDeleted(rowPayee(context.t, r)),
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
    final t = context.t;
    final MoveRecord done;
    try {
      done = await db.moveToAccount(
        transactionId: r.txnId,
        fromAccountId: from.id,
        toAccountId: to.id,
      );
    } on LockedException catch (e) {
      _showToast(t.ledgerCantMove(dbProblem(t, e)));
      return;
    } on NotFoundException catch (e) {
      _showToast(t.ledgerCantMove(dbProblem(t, e)));
      return;
    } catch (e) {
      debugPrint('Move failed: $e');
      _showToast(t.ledgerCouldntMove);
      return;
    }
    _clearSelection();
    final payee = rowPayee(t, r);
    final label = r.kind != RowKind.transfer
        ? t.ledgerMovedTo(payee, to.name)
        : r.amount < 0
        ? t.ledgerTransferToMovedTo(payee, to.name)
        : t.ledgerTransferFromMovedTo(payee, to.name);
    _did(
      label,
      undo: () => db.undoMove(done),
      redo: () => db.redoMove(done),
      message: r.cleared == Cleared.uncleared
          ? label
          : '$label · ${t.ledgerUnclearedThere}',
    );
  }

  /// Leaving the view: an edit with changes stops it, as clicking another
  /// row does; otherwise the editor closes. False means stay.
  bool _mayLeave() {
    final e = _editing;
    if (e == null) return true;
    if (e.controller.isDirty()) {
      _showToast(context.t.ledgerSaveOrDiscard);
      return false;
    }
    _cancelEdit();
    return true;
  }

  /// One account's register, from anywhere: the sidebar, a rename, a new or
  /// unarchived account.
  void _openAccount(int id) {
    if (!_mayLeave()) return;
    setState(() {
      if (id != _accountId || _all) _endReconcile();
      _section = AppSection.ledger;
      _newAccount = false;
      _all = false;
      _accountId = id;
      _selected = null;
    });
  }

  // ---------- pay ----------

  /// Opens the pay setup: from the forecast's "Add your pay", a payday
  /// category on the Budget screen, or Settings. [existing] edits one.
  Future<void> _openPaySetup({
    AccountInfo? category,
    AccountInfo? account,
    PaySchedule? existing,
  }) async {
    final t = context.t;
    final data = _data;
    if (data == null) return;
    final incomes = data.categories.where((c) => c.isIncome).toList()
      ..sort((a, b) => (b.payday ? 1 : 0) - (a.payday ? 1 : 0));
    final into = data.openAccounts.where((a) => !a.isOwed).toList();
    if (incomes.isEmpty || into.isEmpty) {
      _showToast(
        incomes.isEmpty
            ? t.ledgerAddIncomeCategoryFirst
            : t.ledgerAddBankAccountFirst,
      );
      return;
    }
    AccountInfo? byId(List<AccountInfo> from, int? id) =>
        from.where((a) => a.id == id).firstOrNull;
    final result = await showDialog<PaySetupResult>(
      context: context,
      builder: (_) => _PaySetupDialog(
        categories: incomes,
        accounts: into,
        category:
            byId(incomes, existing?.categoryId ?? category?.id) ??
            incomes.first,
        account:
            byId(into, existing?.accountId ?? account?.id ?? _accountId) ??
            into.first,
        today: today,
        existing: existing,
        history: (c, a) => db.payHistory(c, a, scheduleId: existing?.id),
        periodBy: data.periodSchedule?.id == existing?.id
            ? null
            : data.periodSchedule,
        names: (id) => data.accounts[id]?.name ?? '',
        offerNoPay:
            data.paySchedules.isEmpty && data.prefs[noRegularPayKey] == null,
      ),
    );
    if (result == null || !mounted) return;
    late PayChange change;
    switch (result) {
      case PayNone():
        await _setNoRegularPay(true);
      case PayStop():
        if (!await _accountWrite(
          () async => change = await db.stopPaySchedule(existing!.id, today),
          what: 'pay',
        )) {
          return;
        }
        _did(
          t.ledgerPayStopped,
          message: t.ledgerPayStoppedToast,
          undo: () => db.undoPayChange(change),
          redo: () => db.redoPayChange(change),
        );
      case PaySave(:final draft):
        if (!await _accountWrite(
          () async => change = await db.savePaySchedule(
            id: existing?.id,
            categoryId: draft.categoryId,
            accountId: draft.accountId,
            payee: draft.payee,
            amount: draft.amount,
            amount2: draft.amount2,
            varies: draft.varies,
            rule: draft.rule,
            day1: draft.day1,
            day2: draft.day2,
            weeks: draft.weeks,
            anchor: draft.anchor,
            weekend: draft.weekend,
            definesPeriod: draft.definesPeriod,
            today: today,
          ),
          what: 'pay',
        )) {
          return;
        }
        // Pay added after "I don't have regular pay": the saying no longer
        // holds, so stopping this pay later asks again. Undone together.
        final wasNone = existing == null ? data.prefs[noRegularPayKey] : null;
        if (wasNone != null) await db.setPreference(noRegularPayKey, null);
        final next = await db.loadLedger();
        final payday = next.txns
            .where((t) => change.created.contains(t.id))
            .firstOrNull;
        _did(
          t.ledgerPaySaved,
          message: payday == null
              ? t.ledgerPaySaved
              : t.ledgerPaySavedNext(sayFullDate(t, payday.date)),
          undo: () async {
            await db.undoPayChange(change);
            if (wasNone != null) {
              await db.setPreference(noRegularPayKey, wasNone);
            }
          },
          redo: () async {
            await db.redoPayChange(change);
            if (wasNone != null) {
              await db.setPreference(noRegularPayKey, null);
            }
          },
        );
    }
  }

  /// "I don't have regular pay" (from the pay setup), or asking again
  /// (Settings). Only the asking changes: "Add your pay" stays in Settings.
  Future<void> _setNoRegularPay(bool none) async {
    final t = context.t;
    final old = _data?.prefs[noRegularPayKey];
    final value = none ? '1' : null;
    if (old == value) return;
    try {
      await db.setPreference(noRegularPayKey, value);
    } catch (e) {
      _showToast(t.ledgerCouldntSave('$e'));
      return;
    }
    _did(
      none ? t.ledgerNoRegularPay : t.ledgerAskingForPayAgain,
      message: none ? t.ledgerNoRegularPayToast : t.ledgerAskForPayAgainToast,
      undo: () => db.setPreference(noRegularPayKey, old),
      redo: () => db.setPreference(noRegularPayKey, value),
    );
  }

  /// Light, dark or the system's. Kept on this computer, not in the ledger;
  /// no toast, the whole window changing says it happened. ⌘Z switches back.
  void _setAppearance(AppearanceController c, Appearance a) {
    final before = c.value;
    if (a == before) return;
    c.set(a);
    final t = context.t;
    _did(
      t.ledgerAppearanceUndoLabel(switch (a) {
        Appearance.system =>
          _isMac ? t.languageSameAsMac : t.languageSameAsWindows,
        Appearance.light => t.ledgerAppearanceLight,
        Appearance.dark => t.ledgerAppearanceDark,
      }),
      toast: false,
      undo: () => c.set(before),
      redo: () => c.set(a),
    );
  }

  /// English, Mongolian or the system's. Kept on this computer like the
  /// appearance; no toast, every word changing says it happened. ⌘Z switches
  /// back.
  void _setLanguage(LanguageController c, Language l) {
    final before = c.value;
    if (l == before) return;
    c.set(l);
    final t = context.t;
    _did(
      t.languageUndoLabel(switch (l) {
        Language.system =>
          _isMac ? t.languageSameAsMac : t.languageSameAsWindows,
        Language.english => t.languageEnglish,
        Language.mongolian => t.languageMongolian,
      }),
      toast: false,
      undo: () => c.set(before),
      redo: () => c.set(l),
    );
  }

  /// Budget by month, or by [schedule]'s pay periods.
  Future<void> _budgetBy(PaySchedule? schedule) async {
    final t = context.t;
    late List<int> before;
    if (!await _accountWrite(
      () async => before = await db.setPeriodSchedule(schedule?.id),
      what: 'budget period',
    )) {
      return;
    }
    _did(
      schedule == null ? t.ledgerBudgetByMonth : t.ledgerBudgetByPayPeriod,
      undo: () async {
        await db.setPeriodSchedule(before.firstOrNull);
      },
      redo: () async {
        await db.setPeriodSchedule(schedule?.id);
      },
    );
  }

  // ---------- all accounts ----------

  /// All accounts, optionally narrowed to a category and a budget period
  /// (from the Budget screen).
  void _openAll({int? category, BudgetSpan? period}) {
    if (!_mayLeave()) return;
    setState(() {
      _endReconcile();
      _section = AppSection.ledger;
      _newAccount = false;
      _all = true;
      _categoryFilter = category;
      _periodFilter = period;
      _selected = null;
      _adding = false;
      // Each visit starts new rows in the account last open, so a pick from
      // days ago doesn't quietly carry on; within a batch it stays.
      _entry.account = null;
    });
  }

  Widget _allBody(LedgerData data) {
    final t = context.t;
    final filter = data.accounts[_categoryFilter];
    final all = data.registerAll(categoryId: filter?.id);
    // A budget period: a month, or a pay period.
    final period = _periodFilter;
    bool inPeriod(RegisterRow r) =>
        period == null ||
        (!r.date.isBefore(period.start) && !r.date.isAfter(period.end));
    final register = (
      posted: all.posted.where(inPeriod).toList(),
      scheduled: all.scheduled.where(inPeriod).toList(),
    );
    _rows = {
      for (final r in [...register.posted, ...register.scheduled]) r.txnId: r,
    };
    if (!_rows.containsKey(_selected)) _selected = null;
    if (_editing != null && !_rows.containsKey(_editing!.txnId)) {
      _editing = null;
    }
    final open = data.openAccounts;
    // A new row starts in the account last open, then stays on the last one
    // picked. By id: every snapshot has fresh AccountInfo objects.
    AccountInfo? openById(int? id) => open.where((a) => a.id == id).firstOrNull;
    _entry.account =
        openById(_entry.account?.id) ??
        openById(_accountId) ??
        open.firstOrNull;
    AccountInfo accountOf(RegisterRow r) => data.accounts[r.accountId]!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                t.ledgerAllAccounts,
                style: onest(22, weight: 600, letterSpacing: -0.3),
              ),
            ],
          ),
          if (filter != null || period != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (filter != null) ...[
                  _FilterChip(
                    key: const ValueKey('filter-chip'),
                    label: t.ledgerCategoryChip(filter.name),
                    onClear: () => setState(() => _categoryFilter = null),
                  ),
                  const SizedBox(width: 8),
                ],
                if (period != null) ...[
                  _FilterChip(
                    key: const ValueKey('period-chip'),
                    label: t.ledgerPeriodChip(
                      _spanName(t, period, today),
                      shortDate(period.start),
                      shortDate(period.end),
                    ),
                    onClear: () => setState(() => _periodFilter = null),
                  ),
                  const SizedBox(width: 8),
                ],
                const SizedBox(width: 6),
                if (filter != null)
                  Text(
                    _filterTotal(t, data, filter, register, period),
                    key: const ValueKey('filter-total'),
                    style: onest(13, color: Mid.ink2, tabular: true),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: RegisterPanel(
              owed: false,
              accountName: null,
              posted: register.posted,
              scheduled: register.scheduled,
              reconcileThrough: null,
              filter:
                  _filter == RegisterFilter.cleared ||
                      _filter == RegisterFilter.reconciled
                  ? RegisterFilter.all
                  : _filter,
              search: _search.text,
              selected: _selected,
              selectedKey: _selectedKey,
              editing: _editing,
              hoveredStatus: _hoveredStatus,
              categories: data.knownCategories,
              transferTargets: open,
              allAccounts: data.accounts,
              entryController: _entry,
              today: today,
              adding: _adding,
              searchBox: _searchBox(),
              addButton: _PrimaryButton(
                label: t.ledgerAdd,
                icon: Icons.add_rounded,
                key: const ValueKey('add-transaction'),
                onTap: _newEntry,
              ),
              onCloseEntry: _closeEntry,
              actions: RegisterActions(
                onFilter: (f) => setState(() => _filter = f),
                onRowTap: _tapRow,
                onToggleCleared: _toggleCleared,
                onConfirm: _startConfirm,
                onSetCategory: (r, c) => _setCategory(r, c),
                onDelete: _delete,
                onClearSelection: _clearSelection,
                onEdit: (r) => _startEdit(r.txnId, EditField.payee),
                onCancelEdit: _cancelEdit,
                onUnreconcile: (r) => _unreconcile(accountOf(r)),
                onMove: (r, to) => _move(r, accountOf(r), to),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "2 rows · ₮276,650.50 spent since 2026.08.31 · 1 scheduled": the rows
  /// the total covers (posted), the span, and scheduled apart since they
  /// aren't in it. More back than spent reads as refunded.
  String _filterTotal(
    Words t,
    LedgerData data,
    AccountInfo c,
    ({List<RegisterRow> posted, List<RegisterRow> scheduled}) register,
    ({DateTime start, DateTime end, String label})? period,
  ) {
    final posted = register.posted.length;
    final totals = data.categoryTotals(
      c.id,
      from: period?.start,
      to: period?.end,
    );
    // Each currency on its own, each with its own words: a dollar refund
    // beside tugrik spending reads as a refund.
    String kindOf(int v) => c.isIncome
        ? (v >= 0 ? 'received' : 'paidBack')
        : (v >= 0 ? 'spent' : 'refunded');
    String money(MapEntry<Currency, int> e) => formatMoney(
      e.value.abs(),
      showCents: e.value % 100 != 0,
      currency: e.key,
    );
    final parts = totals.entries.toList();
    // With a period chip the span is on the chip; all time says since when,
    // once, after the last.
    final since = period != null || register.posted.isEmpty
        ? null
        : sayFullDate(t, register.posted.first.date);
    final what = [
      for (final (i, e) in parts.indexed)
        since != null && i == parts.length - 1
            ? t.ledgerFilterTotalSince(kindOf(e.value), money(e), since)
            : t.ledgerFilterTotal(kindOf(e.value), money(e)),
    ].join(' · ');
    final sched = register.scheduled.length;
    return [
      t.ledgerFilterRows(posted),
      what,
      if (sched != 0) t.ledgerFilterScheduled(sched),
    ].join(' · ');
  }

  /// A row's category from its inline menu, in whichever account it's in.
  Future<void> _setCategory(RegisterRow r, AccountInfo c) async {
    final payee = rowPayee(context.t, r);
    final previous = await db.setCategoryMany(
      transactionIds: [r.txnId],
      accountId: r.accountId,
      categoryId: c.id,
    );
    if (previous.isEmpty) return;
    _did(
      '$payee → ${c.name}',
      undo: () async => _expect(
        (await db.restoreCategories(previous, r.accountId)).length ==
            previous.length,
      ),
      redo: () async => _expect(
        (await db.setCategoryMany(
              transactionIds: [r.txnId],
              accountId: r.accountId,
              categoryId: c.id,
            )).length ==
            1,
      ),
    );
  }

  // ---------- accounts ----------

  void _openNewAccount() {
    if (!_mayLeave()) return;
    setState(() {
      _endReconcile();
      _section = AppSection.ledger;
      _newAccount = true;
      _selected = null;
      _adding = false;
    });
  }

  Future<void> _createAccount(
    String name,
    AccountType type,
    Currency currency,
  ) async {
    final int id;
    try {
      id = await db.createAccount(name: name, type: type, currency: currency);
    } catch (e) {
      debugPrint('Add account failed: $e');
      if (mounted) _showToast(context.t.ledgerCouldntAddAccount);
      return;
    }
    if (!mounted) return;
    setState(() {
      _newAccount = false;
      _all = false;
      _accountId = id;
      _pendingAccountId = id;
    });
    // The account appearing is the confirmation; ⌘Z takes it away again, but
    // only while it's still empty: undo never deletes rows unasked.
    _did(
      context.t.ledgerAdded(name),
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
    final t = context.t;
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
      _showToast(t.ledgerCouldntSaveBalance);
      return;
    }
    // The bank's number already holds everything cleared, so what's left to
    // type is what hasn't: the entry row opens. No toast (owner, 2026-09-30):
    // the account was just made on purpose; ⌘Z still takes the balance back.
    _newEntry();
    _did(
      t.startOpeningBalance,
      undo: () async => _expect((await db.softDeleteMany([id])).length == 1),
      redo: () => db.restoreMany([id]),
      toast: false,
    );
  }

  /// Runs an account write; a failure says so instead of vanishing.
  Future<bool> _accountWrite(
    Future<void> Function() write, {
    String what = 'account',
  }) async {
    try {
      await write();
      return mounted;
    } catch (e) {
      debugPrint('Change to $what failed: $e');
      if (mounted) {
        final t = context.t;
        _showToast(switch (what) {
          'pay' => t.ledgerCouldntChangePay,
          'budget period' => t.ledgerCouldntChangeBudgetPeriod,
          'category' => t.ledgerCouldntChangeCategory,
          _ => t.ledgerCouldntChangeAccount,
        });
      }
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

  // ---------- categories ----------

  /// What [c] has assigned for [period]. Quiet, like clearing a row: on
  /// payday it's typed a dozen times in a row, and ⌘Z takes any of them
  /// back. The first amount ever also fixes the day the budget began and
  /// its currency, so neither moves on its own later.
  Future<void> _setBudgetAmount(
    AccountInfo c,
    BudgetSpan period,
    int amount,
  ) async {
    final t = context.t;
    final data = _data!;
    final first = data.prefs[BudgetKeys.began] == null;
    final currency = Budget.currencyOf(data);
    final start = period.start, end = period.end;
    Future<List<BudgetAmount>> write() async {
      final before = await db.setBudgetAmount(c.id, start, end, amount);
      if (first) {
        await db.setPreference(BudgetKeys.began, dateKey(start));
        await db.setPreference(BudgetKeys.currency, currency.code);
      }
      return before;
    }

    late List<BudgetAmount> before;
    if (!await _accountWrite(
      () async => before = await write(),
      what: 'category',
    )) {
      return;
    }
    _did(
      t.planAssignUndo(formatMoney(amount, currency: currency), c.name),
      toast: false,
      undo: () async {
        await db.restoreBudgetAmounts(c.id, start, end, before);
        if (first) {
          await db.setPreference(BudgetKeys.began, null);
          await db.setPreference(BudgetKeys.currency, null);
        }
      },
      redo: () async => before = await write(),
    );
  }

  /// The first-period offer, taken: what was assigned in [period] moves to
  /// the next period, and the budget begins there.
  Future<void> _startBudgetLater(BudgetSpan period, BudgetSpan next) async {
    final t = context.t;
    final began = _data!.prefs[BudgetKeys.began];
    late List<BudgetAmount> moved;
    Future<void> write() async {
      moved = await db.moveBudgetAmounts(period.start, period.end, next.start);
      await db.setPreference(BudgetKeys.began, dateKey(next.start));
    }

    if (!await _accountWrite(write, what: 'category')) return;
    _did(
      t.planStartLaterUndo(sayDate(t, next.start)),
      undo: () async {
        await db.unmoveBudgetAmounts(moved);
        await db.setPreference(BudgetKeys.began, began);
      },
      redo: write,
    );
  }

  /// The loan's payments come out of [category] (null: of the money not
  /// assigned).
  Future<void> _setLoanCategory(AccountInfo loan, AccountInfo? category) async {
    final t = context.t;
    final key = '${BudgetKeys.loanPrefix}${loan.id}';
    final old = _data?.prefs[key];
    final value = category?.id.toString();
    if (old == value) return;
    if (!await _accountWrite(() => db.setPreference(key, value))) return;
    _did(
      category == null
          ? t.setupLoanNoCategoryUndo(loan.name)
          : t.setupLoanPaidFromUndo(loan.name, category.name),
      undo: () => db.setPreference(key, old),
      redo: () => db.setPreference(key, value),
    );
  }

  /// "₮150,000 assigned to Dining out goes back to not assigned", when [c]
  /// holds money in this period's budget; null when it holds none.
  String? _moneyBack(LedgerData data, AccountInfo c) {
    if (c.isIncome) return null;
    final p = budgetPeriod(today, data.periodSchedule);
    final b = Budget.of(data, start: p.start, end: p.end, today: today);
    final left = b.lines[c.id]?.left ?? 0;
    if (left == 0) return null;
    return context.t.planMoneyBack(
      formatMoney(left, currency: b.currency),
      c.name,
    );
  }

  _CategoryActions _categoryActions(LedgerData data, AccountInfo c) =>
      _CategoryActions(
        rename: (name) => _renameCategory(data, c, name),
        changeKind: () => _changeCategoryKind(c),
        archive: () => _archiveCategory(c, true),
        delete: () => _deleteCategory(data, c),
        pay: c.isIncome
            ? () => _openPaySetup(
                category: c,
                existing: data.paySchedules
                    .where((p) => p.categoryId == c.id)
                    .firstOrNull,
              )
            : null,
        togglePayday: c.isIncome ? () => _setPayday(c, !c.payday) : null,
      );

  Future<void> _setPayday(AccountInfo c, bool payday) async {
    final t = context.t;
    if (!await _accountWrite(
      () => db.setPayday(c.id, payday),
      what: 'category',
    )) {
      return;
    }
    _did(
      payday ? t.ledgerMarksPayday(c.name) : t.ledgerIsntPayday(c.name),
      message: payday
          ? t.ledgerIsPaydayToast(c.name)
          : t.ledgerIsntPaydayToast(c.name),
      undo: () => db.setPayday(c.id, !payday),
      redo: () => db.setPayday(c.id, payday),
    );
  }

  /// A category already called [name], ignoring case, archived included.
  AccountInfo? _categoryNamed(LedgerData data, String name, {int? except}) =>
      data.knownCategories
          .where(
            (c) => c.id != except && c.name.toLowerCase() == name.toLowerCase(),
          )
          .firstOrNull;

  /// A name that's already taken makes nothing new: an archived one comes
  /// back instead, so there's never two of it.
  Future<void> _createCategory(String name, bool income) async {
    final t = context.t;
    final data = _data;
    final existing = data == null ? null : _categoryNamed(data, name);
    if (existing != null) {
      if (existing.archived) return _archiveCategory(existing, false);
      _showToast(t.ledgerAlreadyCategory(existing.name));
      return;
    }
    late int id;
    if (!await _accountWrite(
      () async => id = await db.createCategory(name, income: income),
      what: 'category',
    )) {
      return;
    }
    _did(
      t.ledgerAdded(name),
      undo: () async => _expect(await db.deleteEmptyAccount(id)),
      redo: () => db.undeleteAccount(DeletedAccount(id, const [])),
    );
  }

  /// Renaming onto another category's name is what merging looks like, so
  /// it offers that (the same as Delete with rows moving there).
  Future<void> _renameCategory(
    LedgerData data,
    AccountInfo c,
    String name,
  ) async {
    final t = context.t;
    final other = _categoryNamed(data, name, except: c.id);
    if (other != null) return _deleteCategory(data, c, into: other);
    final old = c.name;
    if (!await _accountWrite(
      () => db.renameAccount(c.id, name),
      what: 'category',
    )) {
      return;
    }
    _did(
      t.ledgerRenamed(old, name),
      undo: () => db.renameAccount(c.id, old),
      redo: () => db.renameAccount(c.id, name),
    );
  }

  Future<void> _changeCategoryKind(AccountInfo c) async {
    final t = context.t;
    final back = _data == null ? null : _moneyBack(_data!, c);
    final old = c.type;
    final next = c.isIncome ? AccountType.expense : AccountType.income;
    if (!await _accountWrite(
      () => db.setCategoryType(c.id, next),
      what: 'category',
    )) {
      return;
    }
    _did(
      next == AccountType.income
          ? t.ledgerIsNowIncome(c.name)
          : t.ledgerIsNowSpending(c.name),
      message: next == AccountType.income
          ? [t.ledgerIsNowIncomeToast(c.name), ?back].join(' · ')
          : null,
      undo: () => db.setCategoryType(c.id, old),
      redo: () => db.setCategoryType(c.id, next),
    );
  }

  /// Nothing is lost by archiving a category, so no dialog: its rows keep
  /// its name, and it leaves the menus.
  Future<void> _archiveCategory(AccountInfo c, bool archived) async {
    final t = context.t;
    if (!await _accountWrite(
      () => db.setArchived(c.id, archived),
      what: 'category',
    )) {
      return;
    }
    _did(
      archived ? t.ledgerArchived(c.name) : t.ledgerBackInMenus(c.name),
      message: archived ? t.ledgerCategoryArchivedToast(c.name) : null,
      undo: () => db.setArchived(c.id, !archived),
      redo: () => db.setArchived(c.id, archived),
    );
  }

  /// With no rows at all it just goes. With rows (deleted ones count: undoing
  /// their delete must find a category), they need a new home: the dialog
  /// asks where, and the delete is a merge. [into] preselects it (a rename
  /// onto another name).
  Future<void> _deleteCategory(
    LedgerData data,
    AccountInfo c, {
    AccountInfo? into,
  }) async {
    final t = context.t;
    final u = data.categoryUsage[c.id];
    final merging = into != null;
    final int anyRows;
    try {
      anyRows = await db.categoryEntryCount(c.id);
    } catch (e) {
      debugPrint('Counting rows failed: $e');
      _showToast(t.ledgerCouldntChangeCategory);
      return;
    }
    if (!mounted) return;
    if (anyRows > 0 || into != null) {
      into = await showDialog<AccountInfo>(
        context: context,
        builder: (_) => _DeleteCategoryDialog(
          category: c,
          usage: u,
          into: into,
          targets: data.categories.where((t) => t.id != c.id).toList(),
        ),
      );
      if (into == null || !mounted) return;
    }
    final target = into;
    late DeletedCategory done;
    if (!await _accountWrite(
      () async => done = await db.deleteCategory(c.id, into: target?.id),
      what: 'category',
    )) {
      return;
    }
    final moved = (u?.rows ?? 0) + (u?.scheduled ?? 0);
    // Its money goes back unless a spending category takes it.
    final back = target == null || target.isIncome ? _moneyBack(data, c) : null;
    final said = target == null || (!merging && moved == 0)
        ? t.ledgerDeleted(c.name)
        : merging
        ? [
            t.ledgerMergedInto(c.name, target.name),
            if (moved != 0) t.ledgerRowsMoved(moved),
          ].join(' · ')
        : t.ledgerDeletedRowsMovedTo(c.name, moved, target.name);
    _did(
      t.ledgerDeleted(c.name),
      message: [said, ?back].join(' · '),
      undo: () => db.undeleteCategory(done),
      redo: () async => done = await db.deleteCategory(c.id, into: target?.id),
    );
  }

  _AccountActions _actionsFor(LedgerData data, AccountInfo account) =>
      _AccountActions(
        rename: () {
          _openAccount(account.id);
          if (_accountId != account.id || _all) return;
          // A frame later: coming from All accounts or Budget, the title it
          // opens in is only built by then.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _renameRequest++);
          });
        },
        changeKind: () => _changeKind(account),
        archive: () => _archive(data, account),
        delete: () => _deleteAccount(data, account),
        loanPaidFrom: Budget.isLongLoan(account)
            ? (
                categories: data.categories
                    .where((c) => !c.isIncome && !isUncategorized(c))
                    .toList(),
                current: Budget.loanCategory(data, account.id),
                pick: (c) => _setLoanCategory(account, c),
              )
            : null,
      );

  /// Import a bank file into [account] (ADR 0002): pick it, read it, show
  /// the columns and the rows, write what the user confirms as one undoable
  /// action. The file type used last on this account is offered first.
  Future<void> _startImport(
    LedgerData data,
    AccountInfo account,
    int cleared,
  ) async {
    final t = context.t;
    if (!_mayLeave()) return;
    _endReconcile();
    final saved = SavedMapping.decode(
      data.prefs[AppDatabase.importMappingKey(account.id)],
    );
    final excel = XTypeGroup(
      label: t.importExcelFiles,
      extensions: const ['xls', 'xlsx', 'XLS', 'XLSX'],
      uniformTypeIdentifiers: const [
        'com.microsoft.excel.xls',
        'org.openxmlformats.spreadsheetml.sheet',
      ],
    );
    final text = XTypeGroup(
      label: t.importTextFiles,
      extensions: const ['csv', 'txt', 'tsv', 'CSV', 'TXT'],
      uniformTypeIdentifiers: const [
        'public.comma-separated-values-text',
        'public.plain-text',
        'public.tab-separated-values-text',
      ],
    );
    final XFile? picked;
    try {
      picked = await openFile(
        acceptedTypeGroups: saved?.kind == FileKind.csv
            ? [text, excel]
            : [excel, text],
        confirmButtonText: t.ledgerChoose,
      );
    } catch (e) {
      debugPrint('Open dialog failed: $e');
      _showToast(t.ledgerCouldntOpenFileDialog);
      return;
    }
    if (picked == null || !mounted) return;
    final Sheet sheet;
    final FileKind kind;
    final bool fits;
    final ImportMapping mapping;
    try {
      final bytes = await picked.readAsBytes();
      kind =
          fileKindOf(bytes, picked.name) ??
          (throw const UnreadableFileException('unknown kind'));
      sheet = readSheet(bytes, picked.name);
      fits = saved != null && saved.proven && mappingFits(sheet, saved);
      mapping = fits ? saved.mapping : guessMapping(sheet);
    } catch (e) {
      debugPrint('Import read failed: $e');
      if (mounted) _showToast(t.importCouldntRead(picked.name));
      return;
    }
    if (!fits && !mapping.hasDate) {
      _showToast(t.importNoDates(picked.name));
      return;
    }
    if (!mounted) return;
    final pick = await showDialog<ImportPick>(
      context: context,
      builder: (_) => CurrencyScope(
        currency: account.currency,
        child: _ImportDialog(
          accountName: account.name,
          fileName: picked!.name,
          sheet: sheet,
          mapping: mapping,
          fromSaved: fits,
          accountId: account.id,
          plan: (rows, keys) => db.planImport(account.id, rows, keys),
          cleared: cleared,
          owed: account.isOwed,
        ),
      ),
    );
    if (pick == null || !mounted) return;
    final uncategorized = t.importUncategorized;
    final ImportRecord record;
    try {
      record = await db.applyImport(
        accountId: account.id,
        plan: pick.plan,
        moveOpening: pick.moveOpening,
        uncategorizedNames: {uncategorized, ...uncategorizedNames}.toList(),
      );
    } catch (e) {
      debugPrint('Import failed: $e');
      if (mounted) {
        _showToast(
          t.importCouldntImport(switch (e) {
            final DbException d => dbProblem(t, d),
            _ => '$e',
          }),
        );
      }
      return;
    }
    if (!mounted) return;
    final newlyCleared = record.matched
        .where((m) => m.before == Cleared.uncleared)
        .length;
    final label = record.added.isNotEmpty
        ? t.importDone(record.added.length)
        : t.importMatchedToast(record.matched.length);
    _did(
      label,
      undo: () => db.undoImport(record),
      redo: () => db.redoImport(record, account.id),
      message: [
        label,
        if (record.added.isNotEmpty && newlyCleared > 0)
          t.importMatchedToast(newlyCleared),
        if (record.uncategorizedCount > 0)
          t.importUncategorizedToast(record.uncategorizedCount, uncategorized),
        if (record.openingMove case final o?)
          t.importOpeningMovedToast(
            sayDate(t, o.toDate),
            formatMoney(
              account.isOwed ? -o.toAmount : o.toAmount,
              currency: account.currency,
            ),
          ),
      ].join(' · '),
    );
    // Remembered for the next file into this account. The rows are in
    // either way, so a failure here only costs guessing again next time.
    try {
      await db.setPreference(
        AppDatabase.importMappingKey(account.id),
        SavedMapping(
          shape: fileShape(sheet, pick.mapping),
          kind: kind,
          mapping: pick.mapping,
          proven: pick.proven,
        ).encode(),
      );
    } catch (e) {
      debugPrint('Saving the import columns failed: $e');
    }
    _keysBack();
  }

  /// Marks what an account is for on the Savings steps.
  Future<void> _setRole(
    AccountInfo account,
    AccountRole? role,
    String label,
  ) async {
    final old = account.role;
    if (old == role) return;
    if (!await _accountWrite(() => db.setAccountRole(account.id, role))) {
      return;
    }
    _did(
      label,
      undo: () => db.setAccountRole(account.id, old),
      redo: () => db.setAccountRole(account.id, role),
    );
    _keysBack();
  }

  /// A menu closing leaves focus on the page, out of reach of ⌘Z; give it
  /// back to the screen's keys unless someone is typing.
  void _keysBack() {
    if (!_typing) _registerFocus.requestFocus();
  }

  /// A Savings answer or setting. Answers are quiet, like clearing a row;
  /// ⌘Z undoes them.
  Future<void> _setPref(
    String key,
    String? value,
    String label, {
    bool toast = false,
  }) async {
    // The newest ledger: two quick clicks mustn't both start from the same
    // old answer.
    final old = _data?.prefs[key];
    if (old == value) return;
    final t = context.t;
    try {
      await db.setPreference(key, value);
    } catch (e) {
      _showToast(t.ledgerCouldntSave('$e'));
      return;
    }
    _did(
      label,
      toast: toast,
      undo: () => db.setPreference(key, old),
      redo: () => db.setPreference(key, value),
    );
    _keysBack();
  }

  Future<void> _rename(AccountInfo account, String name) async {
    final t = context.t;
    final old = account.name;
    if (!await _accountWrite(() => db.renameAccount(account.id, name))) return;
    _did(
      t.ledgerRenamed(old, name),
      undo: () => db.renameAccount(account.id, old),
      redo: () => db.renameAccount(account.id, name),
    );
  }

  Future<void> _changeKind(AccountInfo account) async {
    final t = context.t;
    final old = account.type;
    final next = account.isOwed ? AccountType.asset : AccountType.liability;
    var flipped = false;
    if (!await _accountWrite(
      () async => flipped = await db.setAccountType(account.id, next),
    )) {
      return;
    }
    final label = next == AccountType.liability
        ? t.ledgerIsNowCardOrLoan(account.name)
        : t.ledgerIsNowBankAccount(account.name);
    _did(
      label,
      message: flipped ? '$label · ${t.ledgerOpeningBalanceFlipped}' : null,
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
      final t = context.t;
      final go = await showDialog<bool>(
        context: context,
        builder: (_) => _AccountWarning(
          title: t.ledgerArchiveTitle(account.name),
          lines: warnings,
          action: t.ledgerArchiveAction(account.name),
          danger: false,
        ),
      );
      if (go != true || !mounted) return;
    }
    await _setArchived(account, true);
  }

  Future<void> _setArchived(AccountInfo account, bool archived) async {
    final t = context.t;
    if (archived) _leaveAccount(account);
    if (!await _accountWrite(() => db.setArchived(account.id, archived))) {
      return;
    }
    if (!archived) _openAccount(account.id);
    _did(
      archived
          ? t.ledgerArchived(account.name)
          : t.ledgerBackInSidebar(account.name),
      message: archived ? t.ledgerAccountArchivedToast(account.name) : null,
      undo: () => db.setArchived(account.id, !archived),
      redo: () => db.setArchived(account.id, archived),
    );
  }

  Future<void> _deleteAccount(LedgerData data, AccountInfo account) async {
    final t = context.t;
    final preview = data.deletePreview(account.id);
    // Nothing in it and nothing kept elsewhere: nothing to read first.
    final empty = preview.rows == 0 && preview.keptOn.isEmpty;
    final go =
        empty ||
        await showDialog<bool>(
              context: context,
              builder: (_) => _AccountWarning(
                title: t.ledgerDeleteTitle(account.name),
                lines: _deleteWarnings(
                  account,
                  data.balanceOf(account.id),
                  preview,
                ),
                action: t.ledgerDeleteAction(account.name),
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
      t.ledgerDeleted(account.name),
      undo: () => db.undeleteAccount(done),
      redo: () async => done = await db.deleteAccount(account.id),
      toast: false,
    );
    _showToast(t.ledgerDeleted(account.name));
  }

  /// Saves a copy of everything where the user picks: another drive, a USB
  /// stick. The daily automatic copies stay on this disk.
  Future<void> _backUpTo() async {
    final t = context.t;
    final now = widget.clock();
    final FileSaveLocation? location;
    try {
      location = await getSaveLocation(
        suggestedName: 'BetterBudget ${fullDate(now)}.sqlite',
        confirmButtonText: t.ledgerBackUpButton,
      );
    } catch (e) {
      debugPrint('Save dialog failed: $e');
      _showToast(t.ledgerCouldntOpenSaveDialog);
      return;
    }
    if (location == null) return;
    try {
      await _backups.saveTo(location.path, now);
    } catch (e) {
      debugPrint('Back up failed: $e');
      _showToast(t.ledgerCouldntBackUp);
      return;
    }
    final name = location.path.split(RegExp(r'[/\\]')).last;
    _showToast(t.ledgerBackedUp(name));
  }

  /// Puts back a backup: the daily copies (the picker opens on their folder)
  /// or one saved elsewhere. Shows what it holds against what's here, saves
  /// what's here first, and can be undone.
  Future<void> _restoreFrom() async {
    if (_restoring) return;
    final t = context.t;
    // A restore replaces the rows an open edit or reconcile points at.
    if (_editing?.controller.isDirty() ?? false) {
      _showToast(context.t.ledgerSaveOrDiscard);
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
        acceptedTypeGroups: [
          XTypeGroup(
            label: t.ledgerBackupFileType,
            extensions: const ['sqlite'],
          ),
        ],
        initialDirectory: (await _backups.folder())?.path,
        confirmButtonText: t.ledgerChoose,
      );
    } catch (e) {
      debugPrint('Open dialog failed: $e');
      _showToast(t.ledgerCouldntOpenFileDialog);
      return;
    }
    if (picked == null) return;
    RestoreCandidate? found;
    try {
      found = await _backups.inspect(picked.path, now);
    } on RestoreNeedsKeyException {
      // Made under another ledger's key: its own recovery key opens it.
      if (!mounted) return;
      await showBackupKeyDialog(context, (key) async {
        try {
          found = await _backups.inspect(
            picked!.path,
            now,
            backupKey: deriveDataKey(key),
          );
          return null;
        } on RestoreException catch (e) {
          return restoreProblem(t, e.problem);
        } catch (e) {
          debugPrint('Restore check failed: $e');
          return t.ledgerCouldntReadBackup;
        }
      });
      if (found == null) return;
    } on RestoreException catch (e) {
      _showToast(restoreProblem(t, e.problem));
      return;
    } catch (e) {
      debugPrint('Restore check failed: $e');
      _showToast(t.ledgerCouldntReadBackup);
      return;
    }
    if (!mounted) return;
    final candidate = found!;
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
      _showToast(t.ledgerCouldntRestore);
      return;
    }
    if (!mounted) return;
    // A restored file's pay schedules get their next paydays, as at launch.
    try {
      await db.ensurePaydays(today);
    } catch (e) {
      debugPrint('Scheduling paydays after restore failed: $e');
    }
    // Earlier actions point at rows the restore replaced.
    _history.clear();
    _redo.clear();
    final label = t.ledgerRestoredFrom(sayFullDate(t, candidate.madeAt));
    _did(
      label,
      undo: () => _whileRestoring(
        () => _backups.replaceWith(done.before, widget.clock()),
      ),
      redo: () => _whileRestoring(
        () => _backups.replaceWith(done.restored, widget.clock()),
      ),
      message: '$label · ${t.ledgerWhatYouHadIsSaved}',
    );
  }

  /// Clears everything for a real start once trying things out is done.
  /// What's here is saved first, and Undo puts it back.
  Future<void> _startNewLedger() async {
    if (_restoring) return;
    final t = context.t;
    if (_editing?.controller.isDirty() ?? false) {
      _showToast(context.t.ledgerSaveOrDiscard);
      return;
    }
    final data = _data;
    if (data == null) return;
    final keep = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _NewLedgerDialog(
        accounts: [
          for (final a in data.balanceSheetAccounts)
            (
              name: a.archived ? t.ledgerArchivedName(a.name) : a.name,
              balance: _balanceText(t, a, data.balanceOf(a.id)),
            ),
        ],
        transactions: data.txns.length,
        first: data.txns
            .map((t) => t.date)
            .fold<DateTime?>(
              null,
              (m, d) => m == null || d.isBefore(m) ? d : m,
            ),
        last: data.txns
            .map((t) => t.date)
            .fold<DateTime?>(null, (m, d) => m == null || d.isAfter(m) ? d : m),
        pay: data.paySchedules.length,
        reconciles: data.reconciliations.length,
        categories: data.categories.length,
      ),
    );
    if (keep == null || !mounted) return;
    _cancelEdit();
    _endReconcile();
    setState(() {
      _selected = null;
      _adding = false;
      _all = false;
      _newAccount = false;
    });
    final now = widget.clock();
    final File before;
    try {
      before = await _whileRestoring(() async {
        final saved = await _backups.saveBeforeNewLedger(now);
        await db.startNewLedger(now, keepCategories: keep);
        return saved;
      });
    } catch (e) {
      debugPrint('New ledger failed: $e');
      _showToast(t.ledgerCouldntStartNewLedger);
      return;
    }
    if (!mounted) return;
    // Earlier actions point at rows that are gone.
    _history.clear();
    _redo.clear();
    _did(
      t.ledgerNewLedgerStarted,
      undo: () =>
          _whileRestoring(() => _backups.replaceWith(before, widget.clock())),
      redo: () => _whileRestoring(
        () => db.startNewLedger(widget.clock(), keepCategories: keep),
      ),
      message: t.ledgerEverythingErased,
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
    final t = context.t;
    final ReconcileRecord done;
    try {
      done = await db.unreconcileLast(account.id);
    } on NotFoundException {
      return;
    }
    final n = done.entryIds.length;
    final label = t.ledgerReconcileUndone(sayDate(t, done.date));
    _did(
      label,
      undo: () => db.relock(done),
      redo: () => db.unreconcile(done),
      message: n == 0 ? label : '$label · ${t.ledgerBackToCleared(n)}',
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
                    context.t.ledgerCouldntOpenLedger(switch (snap.error) {
                      final CipherException e => cipherProblem(context.t, e),
                      NewerLedgerException _ => context.t.ledgerNewerLedger,
                      final e => '$e',
                    }),
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
                        onSection: (sec) {
                          if (!_mayLeave()) return;
                          setState(() {
                            if (sec != _section) _endReconcile();
                            _section = sec;
                            _selected = null;
                          });
                        },
                        selected: _newAccount || _all ? null : account?.id,
                        backupHealth: _backups.health,
                        now: widget.clock,
                        onSelect: _openAccount,
                        allActive: _all && !_newAccount,
                        onAll: () => _openAll(),
                        addingAccount: _newAccount,
                        onAddAccount: _openNewAccount,
                        actionsFor: (a) => _actionsFor(data, a),
                      ),
                      Expanded(
                        child: switch (_section) {
                          AppSection.ledger
                              when _newAccount || account == null =>
                            _NewAccountPage(
                              onCreate: _createAccount,
                              // The one most accounts are in, not whichever
                              // is on screen: ₮ for a first account.
                              currency: mainCurrency(data),
                              onCancel: account == null
                                  ? null
                                  : () => setState(() => _newAccount = false),
                            ),
                          AppSection.ledger when _all => _allBody(data),
                          AppSection.ledger => CurrencyScope(
                            currency: account!.currency,
                            child: _body(data, account),
                          ),
                          AppSection.settings => _SettingsPage(
                            health: _backups.health,
                            now: widget.clock,
                            onBackUp: _backUpTo,
                            onRestore: _restoreFrom,
                            onNewLedger: _startNewLedger,
                            encrypted: widget.encrypted,
                            recoveryKeySaved: _keySaved,
                            onCheckRecoveryKey: widget.checkRecoveryKey == null
                                ? null
                                : _checkRecoveryKey,
                            appearance: switch (AppearanceScope.maybeOf(
                              context,
                            )) {
                              null => null,
                              final c => _AppearanceSettings(
                                value: c.value,
                                onChanged: (a) => _setAppearance(c, a),
                              ),
                            },
                            language: switch (LanguageScope.maybeOf(context)) {
                              null => null,
                              final c => _LanguageSettings(
                                value: c.value,
                                onChanged: (l) => _setLanguage(c, l),
                              ),
                            },
                            budget: _BudgetSettings(
                              data: data,
                              onBudgetBy: _budgetBy,
                              onEdit: (p) => _openPaySetup(existing: p),
                              onAdd: () => _openPaySetup(),
                              onAskAgain: () => _setNoRegularPay(false),
                            ),
                            archived: data.archivedAccounts.isEmpty
                                ? null
                                : _ArchivedAccounts(
                                    data: data,
                                    onUnarchive: (a) => _setArchived(a, false),
                                  ),
                          ),
                          AppSection.budget => _BudgetPage(
                            data: data,
                            today: today,
                            onShowRows: (c, period) =>
                                _openAll(category: c.id, period: period),
                            onShowAllRows: (c) => _openAll(category: c.id),
                            onSetAmount: _setBudgetAmount,
                            onStartLater: _startBudgetLater,
                            onKeepStart: () => _setPref(
                              BudgetKeys.keptStart,
                              '1',
                              context.t.planStartKeep,
                            ),
                            onShowUncategorized: () {
                              final c = data.categories
                                  .where(isUncategorized)
                                  .firstOrNull;
                              if (c != null) _openAll(category: c.id);
                            },
                            onKeysBack: _keysBack,
                            actionsFor: (c) => _categoryActions(data, c),
                            onCreate: _createCategory,
                            onUnarchive: (c) => _archiveCategory(c, false),
                          ),
                          AppSection.savings => _SavingsPage(
                            data: data,
                            today: dateOnly(widget.clock()),
                            actions: _SavingsActions(
                              setRole: _setRole,
                              setPref: (key, value, label, {toast = false}) =>
                                  _setPref(key, value, label, toast: toast),
                              setAside: (step, aside, label) => _setPref(
                                ReadyKeys.setAside,
                                Readiness.of(
                                  _data ?? data,
                                  widget.clock(),
                                ).setAsideWith(step, aside),
                                label,
                                toast: true,
                              ),
                            ),
                          ),
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
      paydayAfter: (row) => _paydayAfter(data, register.scheduled, row),
    );
    final activeStatus = switch (_filter) {
      RegisterFilter.uncleared => Cleared.uncleared,
      RegisterFilter.cleared => Cleared.cleared,
      RegisterFilter.reconciled => Cleared.reconciled,
      _ => null,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 24),
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
                  actions: _actionsFor(data, account),
                  renameRequest: _renameRequest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
              onImport: () => _startImport(data, account, summary.cleared),
              // Asked until there's pay anywhere; once there is, an account
              // it doesn't go into doesn't nag, and a click can't start a
              // second Salary by mistake.
              // "I don't have regular pay" said once stops the asking.
              onAddPay:
                  account.isOwed ||
                      data.paySchedules.isNotEmpty ||
                      data.prefs[noRegularPayKey] == '1'
                  ? null
                  : () => _openPaySetup(account: account),
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
                // Archived too, so an old row keeps its category when
                // edited; menus and lists leave them out.
                categories: data.knownCategories,
                transferTargets: data.openAccounts
                    .where((a) => a.id != account.id)
                    .toList(),
                currency: account.currency,
                entryController: _entry,
                today: today,
                adding: _adding,
                searchBox: _searchBox(),
                addButton: _PrimaryButton(
                  label: context.t.ledgerAdd,
                  icon: Icons.add_rounded,
                  key: const ValueKey('add-transaction'),
                  onTap: _newEntry,
                ),
                onCloseEntry: _closeEntry,
                actions: RegisterActions(
                  onFilter: (f) => setState(() => _filter = f),
                  onRowTap: _tapRow,
                  onToggleCleared: _toggleCleared,
                  onConfirm: _startConfirm,
                  onSetCategory: _setCategory,
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
    required this.actionsFor,
    required this.allActive,
    required this.onAll,
  });
  final bool allActive;
  final VoidCallback onAll;

  /// For the right-click menu on each account.
  final _AccountActions Function(AccountInfo) actionsFor;
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
    final t = context.t;
    // Grouped by what the ledger stores; the groups the app makes are named
    // in the language showing, any other as it's stored.
    final groups = <String?, List<AccountInfo>>{};
    for (final a in data.openAccounts) {
      groups.putIfAbsent(a.group, () => []).add(a);
    }
    String groupName(String? g) => switch (g) {
      null => t.ledgerGroupAccounts,
      'Cash & bank' => t.ledgerGroupCashBank,
      'Credit' => t.ledgerGroupCredit,
      final other => other,
    };
    // Archived accounts still hold money, or debt. Each currency on its
    // own line: they're never added together (ROADMAP E).
    final net = data.balancesByCurrency(data.balanceSheetAccounts);
    // So net worth isn't a mystery sum of the accounts above it.
    final archived = data.balancesByCurrency(data.archivedAccounts)
      ..removeWhere((_, v) => v == 0);

    Widget header(AppSection sec, IconData icon, String label) =>
        _SectionHeader(
          icon: icon,
          label: label,
          expanded: section == sec,
          onTap: () => onSection(sec),
        );

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Mid.side,
        border: Border(right: BorderSide(color: Mid.sideRule)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 26, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
            child: const Row(
              children: [
                Bee(height: 40),
                SizedBox(width: 10),
                Wordmark(height: 22),
              ],
            ),
          ),
          header(
            AppSection.ledger,
            Icons.format_list_bulleted_rounded,
            t.ledgerSectionLedger,
          ),
          _Spill(
            open: section == AppSection.ledger,
            children: [
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 26, bottom: 12),
                child: _AllAccountsTile(active: allActive, onTap: onAll),
              ),
              for (final g in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(38, 0, 12, 6),
                  child: Text(
                    groupName(g.key),
                    style: onest(12, color: Mid.sideInk3),
                  ),
                ),
                for (final a in g.value)
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: _AccountTile(
                      account: a,
                      balance: data.balanceOf(a.id),
                      active: a.id == selected,
                      onTap: () => onSelect(a.id),
                      actions: actionsFor(a),
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
            t.ledgerSectionBudget,
          ),
          const SizedBox(height: 2),
          header(
            AppSection.savings,
            Icons.savings_outlined,
            t.ledgerSectionSavings,
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
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Mid.sideRule)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.ledgerNetWorth, style: onest(12, color: Mid.sideInk3)),
                const SizedBox(height: 4),
                for (final e in net.entries)
                  Text(
                    formatMoney(e.value, currency: e.key),
                    key: ValueKey('net-worth-${e.key.code}'),
                    style: onest(
                      net.length > 1 ? 16 : 18,
                      weight: 500,
                      color: Mid.sideInk,
                      tabular: true,
                    ),
                  ),
                if (archived.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      t.ledgerInclArchived(
                        archived.entries
                            .map((e) => _money(e.value, e.key))
                            .join(' · '),
                      ),
                      key: const ValueKey('net-worth-archived'),
                      style: onest(11.5, color: Mid.sideInk3, tabular: true),
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
    message: alert ? context.t.ledgerDailyCopyFailing : '',
    child: Hoverable(
      key: const ValueKey('settings'),
      onTap: onTap,
      builder: (h) => Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: h && !active ? Mid.sideHover : Colors.transparent,
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
                  color: active ? Mid.sun : Mid.sideInk3,
                ),
                if (alert)
                  Positioned(
                    top: -2,
                    right: -3,
                    child: Container(
                      key: const ValueKey('settings-alert'),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: Mid.sideCoral,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Text(
              context.t.ledgerSettings,
              style: onest(
                14,
                weight: active ? 600 : 500,
                color: active ? Mid.sideInk : Mid.sideInk2,
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
    required this.onNewLedger,
    required this.recoveryKeySaved,
    this.encrypted = false,
    this.onCheckRecoveryKey,
    this.archived,
    this.budget,
    this.appearance,
    this.language,
  });
  final ValueListenable<BackupHealth> health;

  /// Light, dark or the system's; null without an [AppearanceScope] (tests).
  final Widget? appearance;

  /// English, Mongolian or the system's; null without a [LanguageScope]
  /// (tests).
  final Widget? language;

  /// Budget by month or pay period, and pay schedules.
  final Widget? budget;

  /// Archived accounts, when there are any.
  final Widget? archived;
  final DateTime Function() now;
  final VoidCallback onBackUp;
  final VoidCallback onRestore;
  final VoidCallback onNewLedger;

  /// Whether the recovery key was saved or copied when it was shown (ADR
  /// 0001): drives the coral warning below.
  final bool recoveryKeySaved;

  /// Shows the Security section; false in tests.
  final bool encrypted;

  /// "Check my recovery key…"; null hides the button.
  final VoidCallback? onCheckRecoveryKey;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
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
    String when(DateTime at) {
      String two(int v) => v.toString().padLeft(2, '0');
      final today = dateOnly(now());
      final day = dateOnly(at) == today
          ? t.today
          : dateOnly(at) == today.subtract(const Duration(days: 1))
          ? t.yesterday
          : sayFullDate(t, at);
      return t.ledgerTimeAt(day, '${two(at.hour)}:${two(at.minute)}');
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
                      t.ledgerSettings,
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
                          Text(
                            t.ledgerBackupsTitle,
                            style: onest(16, weight: 600),
                          ),
                          const SizedBox(height: 16),
                          line(
                            t.ledgerDailyCopy,
                            failing
                                ? Text(
                                    h.newest == null
                                        ? t.ledgerDailyCopyFailingNone
                                        : t.ledgerDailyCopyFailingSince(
                                            when(h.newest!),
                                          ),
                                    key: const ValueKey('backup-failed'),
                                    style: onest(13.5, color: Mid.coral),
                                  )
                                : Text(
                                    h.newest == null
                                        ? t.ledgerDailyCopyNone
                                        : t.ledgerDailyCopyWhen(
                                            when(h.newest!),
                                          ),
                                    style: onest(13.5, color: Mid.ink),
                                  ),
                          ),
                          line(
                            t.ledgerKept,
                            Text(
                              t.ledgerKeptWhich,
                              style: onest(13.5, color: Mid.ink2),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              BarButton(
                                key: const ValueKey('back-up'),
                                label: t.ledgerBackUpTo,
                                leading: Icon(
                                  Icons.save_alt_rounded,
                                  size: 14,
                                  color: Mid.ink3,
                                ),
                                onTap: onBackUp,
                              ),
                              BarButton(
                                key: const ValueKey('restore'),
                                label: t.ledgerRestoreFrom,
                                leading: Icon(
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
                            t.ledgerBackupsNote,
                            style: onest(13, color: Mid.ink3),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                if (budget != null) ...[const SizedBox(height: 16), budget!],
                if (appearance != null) ...[
                  const SizedBox(height: 16),
                  appearance!,
                ],
                if (language != null) ...[
                  const SizedBox(height: 16),
                  language!,
                ],
                if (archived != null) ...[
                  const SizedBox(height: 16),
                  archived!,
                ],
                if (encrypted) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
                    decoration: BoxDecoration(
                      color: Mid.panel,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Mid.rule),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.ledgerSecurityTitle,
                          style: onest(16, weight: 600),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          recoveryKeySaved
                              ? t.ledgerSecurityKeySaved
                              : t.ledgerSecurityKeyNotSaved,
                          key: const ValueKey('security-status'),
                          style: onest(
                            13,
                            color: recoveryKeySaved ? Mid.ink3 : Mid.coral,
                            height: 1.4,
                          ),
                        ),
                        if (onCheckRecoveryKey != null) ...[
                          const SizedBox(height: 12),
                          BarButton(
                            key: const ValueKey('check-recovery-key'),
                            label: t.ledgerCheckRecoveryKey,
                            leading: Icon(
                              Icons.key_rounded,
                              size: 14,
                              color: Mid.ink3,
                            ),
                            onTap: onCheckRecoveryKey!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
                  decoration: BoxDecoration(
                    color: Mid.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Mid.rule),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.ledgerStartOverTitle,
                        style: onest(16, weight: 600),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t.ledgerStartOverNote,
                        style: onest(13, color: Mid.ink3),
                      ),
                      const SizedBox(height: 12),
                      BarButton(
                        key: const ValueKey('new-ledger'),
                        label: t.ledgerEraseAndStartOverButton,
                        leading: Icon(
                          Icons.restart_alt_rounded,
                          size: 14,
                          color: Mid.ink3,
                        ),
                        onTap: onNewLedger,
                      ),
                    ],
                  ),
                ),
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
    final t = context.t;
    final made = candidate.madeAt;
    String two(int v) => v.toString().padLeft(2, '0');
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
        side: BorderSide(color: Mid.rule),
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
                    t.ledgerRestoreTitle,
                    style: onest(17, weight: 600, letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 16),
                  line(
                    t.ledgerBackupFrom,
                    '${fullDate(made)}  ${two(made.hour)}:${two(made.minute)}',
                    strong: true,
                  ),
                  line(
                    t.ledgerItHolds,
                    t.ledgerCounts(candidate.transactions, candidate.accounts),
                    strong: true,
                  ),
                  line(
                    t.ledgerHereNow,
                    t.ledgerCounts(transactionsNow, accountsNow),
                  ),
                  const SizedBox(height: 6),
                  Text(t.ledgerRestoreNote, style: onest(13, color: Mid.ink2)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      BarButton(
                        key: const ValueKey('restore-cancel'),
                        label: t.ledgerCancel,
                        onTap: () => Navigator.of(context).pop(false),
                      ),
                      _PrimaryButton(
                        key: const ValueKey('restore-confirm'),
                        label: t.ledgerRestore,
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

/// A balance as the sidebar shows it: a card as what's owed, positive, as
/// the bank does.
String _balanceText(Words t, AccountInfo a, int balance) => a.isOwed
    ? t.ledgerOwed(formatMoney(-balance, currency: a.currency))
    : formatMoney(balance, currency: a.currency);

/// Asks before everything is erased for a clean start, naming what goes:
/// each account and its balance, the transactions' dates, pay. Whether the
/// categories stay is a choice in plain sight; keeping them is the default.
class _NewLedgerDialog extends StatefulWidget {
  const _NewLedgerDialog({
    required this.accounts,
    required this.transactions,
    required this.first,
    required this.last,
    required this.pay,
    required this.reconciles,
    required this.categories,
  });
  final List<({String name, String balance})> accounts;
  final int transactions;
  final DateTime? first;
  final DateTime? last;
  final int pay;
  final int reconciles;
  final int categories;

  @override
  State<_NewLedgerDialog> createState() => _NewLedgerDialogState();
}

class _NewLedgerDialogState extends State<_NewLedgerDialog> {
  bool _keep = true;

  /// Accounts listed by name before "+ N more".
  static const _shown = 8;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final first = widget.first, last = widget.last;
    final also = [
      if (widget.pay > 0) t.ledgerYourPay,
      if (widget.reconciles > 0) t.ledgerReconciles(widget.reconciles),
      t.ledgerPayees,
      t.ledgerBudgetSavingsSettings,
    ];
    final alsoText = also.join(' · ');

    Widget item(String left, String right, {Key? key}) => Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(left, style: onest(13.5, color: Mid.ink)),
          ),
          Text(right, style: onest(13.5, color: Mid.ink, tabular: true)),
        ],
      ),
    );

    Widget choice(
      String label,
      bool on,
      VoidCallback onTap,
      String key,
    ) => Hoverable(
      key: ValueKey(key),
      onTap: onTap,
      builder: (hover) => Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: on ? Mid.blueWash : (hover ? Mid.raised : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: on ? Mid.blue : Mid.ink2.withValues(alpha: 0.3),
          ),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(label, style: onest(13, color: on ? Mid.ink : Mid.ink2)),
        ),
      ),
    );

    return Dialog(
      backgroundColor: Mid.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Mid.coral.withValues(alpha: 0.5)),
      ),
      child: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.ledgerEraseTitle,
                style: onest(
                  17,
                  weight: 600,
                  letterSpacing: -0.2,
                  color: Mid.coral,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                t.ledgerAllOfThisErased,
                style: onest(13.5, weight: 600, color: Mid.ink),
              ),
              const SizedBox(height: 10),
              Container(
                key: const ValueKey('new-ledger-goes'),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                decoration: BoxDecoration(
                  color: Mid.coral.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Mid.coral.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final a in widget.accounts.take(_shown))
                      item(a.name, a.balance),
                    if (widget.accounts.length > _shown)
                      item(
                        t.ledgerMoreAccounts(widget.accounts.length - _shown),
                        '',
                      ),
                    item(
                      t.ledgerTransactionCount(widget.transactions),
                      first == null || last == null
                          ? ''
                          : first == last
                          ? fullDate(first)
                          : '${fullDate(first)} – ${fullDate(last)}',
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(alsoText, style: onest(13.5, color: Mid.ink)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                t.ledgerStartWithNothing,
                style: onest(13.5, color: Mid.ink),
              ),
              if (widget.categories > 0) ...[
                const SizedBox(height: 18),
                Text(
                  t.ledgerYourCategories(widget.categories),
                  style: onest(13.5, weight: 600, color: Mid.ink),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    choice(
                      t.ledgerKeepThemEmpty,
                      _keep,
                      () => setState(() => _keep = true),
                      'new-ledger-keep',
                    ),
                    choice(
                      t.ledgerEraseThemToo,
                      !_keep,
                      () => setState(() => _keep = false),
                      'new-ledger-drop',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _keep ? t.ledgerKeptNoRows : t.ledgerAddCategoriesAgain,
                  key: const ValueKey('new-ledger-categories'),
                  style: onest(12.5, color: Mid.ink3),
                ),
              ],
              const SizedBox(height: 18),
              Text(t.ledgerEraseNote, style: onest(13, color: Mid.ink2)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  BarButton(
                    key: const ValueKey('new-ledger-cancel'),
                    label: t.ledgerCancel,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  Material(
                    key: const ValueKey('new-ledger-confirm'),
                    color: Mid.coral,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () =>
                          Navigator.of(context)
                              .pop(_keep && widget.categories > 0),
                      borderRadius: BorderRadius.circular(8),
                      hoverColor: Colors.white.withValues(alpha: 0.14),
                      child: Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        child: Text(
                          t.ledgerEraseEverything,
                          style: onest(13, weight: 600, color: Mid.onAccent),
                        ),
                      ),
                    ),
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

class _SectionHeader extends StatefulWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool expanded;
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
            color: _hover && !on ? Mid.sideHover : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: on ? Mid.sun : Mid.sideInk3),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: onest(
                  14,
                  weight: on ? 600 : 500,
                  color: on ? Mid.sideInk : Mid.sideInk2,
                ),
              ),
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

class _AccountTile extends StatefulWidget {
  const _AccountTile({
    required this.account,
    required this.balance,
    required this.active,
    required this.onTap,
    required this.actions,
  });
  final AccountInfo account;
  final int balance;
  final bool active;
  final VoidCallback onTap;
  final _AccountActions actions;

  @override
  State<_AccountTile> createState() => _AccountTileState();
}

class _AccountTileState extends State<_AccountTile> {
  bool _hover = false;
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) => MenuAnchor(
    controller: _menu,
    style: _menuStyle,
    // Lit while its menu is open, so it's clear which account it's for.
    onOpen: () => setState(() {}),
    onClose: () {
      if (mounted) setState(() {});
    },
    menuChildren: _accountMenu(widget.account, widget.actions),
    child: _tile(),
  );

  Widget _tile() => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      onTap: widget.onTap,
      // Right-click: the same menu as ⋯ beside the name, where the click was.
      onSecondaryTapDown: (d) => _menu.open(position: d.localPosition),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: widget.active
              ? Mid.sideSel
              : (_hover || _menu.isOpen ? Mid.sideHover : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: widget.active
              ? const Border(left: BorderSide(color: Mid.sun, width: 2))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.account.name,
              style: onest(
                13.5,
                color: widget.active ? Mid.sideInk : Mid.sideInk2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              // A card shows what's owed, positive, as the bank does; owing
              // isn't a warning.
              _balanceText(context.t, widget.account, widget.balance),
              style: onest(
                12.5,
                color: !widget.account.isOwed && widget.balance < 0
                    ? Mid.sideCoral
                    // The account being worked in reads clearly on its
                    // highlight; the others stay quiet.
                    : (widget.active || _hover ? Mid.sideInk2 : Mid.sideInk3),
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
        hintText: context.t.ledgerSearchHint,
        hintStyle: onest(13, color: Mid.ink3),
        prefixIcon: Icon(Icons.search_rounded, size: 16, color: Mid.ink3),
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
                          Icon(
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
                icon: Icon(Icons.close_rounded, size: 14, color: Mid.ink3),
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
          borderSide: BorderSide(color: Mid.blue, width: 1.5),
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
      color: Mid.blue,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        hoverColor: Mid.onAccent.withValues(alpha: 0.12),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, size: 16, color: Mid.onAccent),
              const SizedBox(width: 8),
              Text(label, style: onest(13, weight: 600, color: Mid.onAccent)),
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
                    style: onest(13.5, weight: 500, color: Mid.onAccent),
                  ),
                  const SizedBox(width: 12),
                  if (toast.undo != null)
                    TextButton(
                      onPressed: toast.undo,
                      child: Text(
                        context.t.ledgerUndo,
                        style: onest(
                          13.5,
                          weight: 700,
                          color: Mid.onAccent,
                        ).copyWith(decoration: TextDecoration.underline),
                      ),
                    ),
                  IconButton(
                    onPressed: onClose,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Mid.onAccent.withValues(alpha: 0.6),
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

/// Settings → Appearance: System, Light or Dark. Under System, says which one
/// the computer is showing now, so the choice never looks like it did nothing.
class _AppearanceSettings extends StatelessWidget {
  const _AppearanceSettings({required this.value, required this.onChanged});
  final Appearance value;
  final ValueChanged<Appearance> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    Widget choice(Appearance a, String label) => _SettingChoice(
      key: ValueKey('appearance-${a.name}'),
      label: label,
      chosen: a == value,
      onTap: () => onChanged(a),
    );
    final system = _isMac ? t.languageSameAsMac : t.languageSameAsWindows;
    return Container(
      key: const ValueKey('settings-appearance'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
      decoration: BoxDecoration(
        color: Mid.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Mid.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.ledgerAppearanceTitle, style: onest(16, weight: 600)),
          const SizedBox(height: 16),
          Row(
            children: [
              choice(Appearance.system, system),
              choice(Appearance.light, t.ledgerAppearanceLight),
              choice(Appearance.dark, t.ledgerAppearanceDark),
            ],
          ),
          if (value == Appearance.system) ...[
            const SizedBox(height: 10),
            Text(
              (Mid.isLight ? t.ledgerShowingLightNow : t.ledgerShowingDarkNow)(
                _isMac ? t.theMac : t.windowsName,
              ),
              style: onest(12.5, color: Mid.ink3),
            ),
          ],
        ],
      ),
    );
  }
}

/// One choice in a row of them (Appearance, Language).
class _SettingChoice extends StatelessWidget {
  const _SettingChoice({
    super.key,
    required this.label,
    required this.chosen,
    required this.onTap,
  });
  final String label;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Hoverable(
      onTap: onTap,
      builder: (hover) => Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: chosen
              ? Mid.blueWash
              : (hover ? Mid.raised : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: chosen ? Mid.blue : Mid.ink2.withValues(alpha: 0.3),
          ),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: onest(13, color: chosen ? Mid.ink : Mid.ink2),
          ),
        ),
      ),
    ),
  );
}

/// Settings → Language: the system's, English or Монгол. Under the system's,
/// says which one is showing now, as Appearance does.
class _LanguageSettings extends StatelessWidget {
  const _LanguageSettings({required this.value, required this.onChanged});
  final Language value;
  final ValueChanged<Language> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    Widget choice(Language l, String label) => _SettingChoice(
      key: ValueKey('language-${l.name}'),
      label: label,
      chosen: l == value,
      onTap: () => onChanged(l),
    );
    final showing = Localizations.localeOf(context).languageCode == 'mn'
        ? t.languageMongolian
        : t.languageEnglish;
    return Container(
      key: const ValueKey('settings-language'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
      decoration: BoxDecoration(
        color: Mid.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Mid.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.languageTitle, style: onest(16, weight: 600)),
          const SizedBox(height: 16),
          Row(
            children: [
              choice(
                Language.system,
                _isMac ? t.languageSameAsMac : t.languageSameAsWindows,
              ),
              choice(Language.english, t.languageEnglish),
              choice(Language.mongolian, t.languageMongolian),
            ],
          ),
          if (value == Language.system) ...[
            const SizedBox(height: 10),
            Text(
              t.languageShowingNow(showing, _isMac ? t.theMac : t.windowsName),
              style: onest(12.5, color: Mid.ink3),
            ),
          ],
        ],
      ),
    );
  }
}
