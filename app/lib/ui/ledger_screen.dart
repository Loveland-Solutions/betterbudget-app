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
    super.dispose();
  }

  Future<String?> _post(EntryDraft d) async {
    try {
      await db.postSimple(
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
    if (row.cleared == Cleared.reconciled) {
      _showToast(
        'Reconciled transactions are locked · they match a bank statement',
      );
      return;
    }
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
    } on LockedException catch (e) {
      return e.message;
    } catch (e) {
      return 'Couldn’t save: $e';
    }
    _entry.payeeNames = await db.payeeNames();
    _cancelEdit();
    final nowScheduled = !row.scheduled && d.date.isAfter(today);
    _showToast(
      nowScheduled
          ? 'Moved to ${fullDate(d.date)} · now scheduled, out of balances until confirmed'
          : 'Changes saved',
      undo: () => db.restoreSnapshot(before),
    );
    return null;
  }

  // ---------- actions ----------

  Future<void> _toggleCleared(RegisterRow r) async {
    final next = r.cleared == Cleared.uncleared
        ? Cleared.cleared
        : Cleared.uncleared;
    final previous = await db.setClearedMany({r.entryId: next});
    if (previous.isEmpty) return;
    _showToast(
      '${r.payee} marked ${StatusGlyph.label(next).toLowerCase()}',
      undo: () => db.setClearedMany(previous),
    );
  }

  Future<void> _delete(RegisterRow r) async {
    final deleted = await db.softDeleteMany([r.txnId]);
    if (deleted.isEmpty) {
      _showToast(
        'Reconciled transactions are locked · they match a bank statement',
      );
      return;
    }
    _clearSelection();
    _showToast(
      '${r.payee} deleted',
      undo: () async {
        await db.restoreMany(deleted);
        if (mounted) setState(() => _selected = r.txnId);
      },
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
                          _section = sec;
                          _selected = null;
                          _editing = null;
                        }),
                        selected: account.id,
                        onSelect: (id) => setState(() {
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
            summary: summary,
            forecast: forecast,
            hoveredStatus: _hoveredStatus,
            activeStatus: activeStatus,
            onOpenScheduled: _openScheduled,
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
              posted: register.posted,
              scheduled: register.scheduled,
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
                  await db.confirmScheduled(r.txnId, today);
                  _showToast(
                    r.date.isAfter(today)
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
                  _showToast(
                    '${r.payee} → ${c.name}',
                    undo: () => db.restoreCategories(previous, account.id),
                  );
                },
                onDelete: _delete,
                onClearSelection: _clearSelection,
                onEdit: (r) => _startEdit(r.txnId, EditField.payee),
                onCancelEdit: _cancelEdit,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
              '${widget.balance < 0 ? '−' : ''}₮${formatWhole(widget.balance)}',
              style: onest(
                12.5,
                color: widget.balance < 0 ? Mid.coral : Mid.ink3,
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
