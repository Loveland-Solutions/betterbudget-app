import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../domain/ledger.dart';
import '../domain/money.dart';
import 'entry_row.dart';
import 'theme.dart';

enum RegisterFilter { all, uncleared, cleared, reconciled, scheduled }

/// Column layout shared by the header, entry row and every register row.
abstract final class Cols {
  static const status = 24.0;
  static const date = 114.0;
  static const category = 220.0;
  static const amount = 170.0;
  static const balance = 170.0;
  static const gap = 16.0;
  static const inset = EdgeInsets.symmetric(horizontal: 20);
  static const outer = EdgeInsets.symmetric(horizontal: 12);
}

/// Everything the register can ask the screen to do.
class RegisterActions {
  const RegisterActions({
    required this.onFilter,
    required this.onRowTap,
    required this.onToggleCleared,
    required this.onConfirm,
    required this.onSetCategory,
    required this.onDelete,
    required this.onClearSelection,
    required this.onEdit,
    required this.onCancelEdit,
    required this.onUnreconcile,
    required this.onMove,
  });

  final ValueChanged<RegisterFilter> onFilter;

  /// [field] is the cell clicked, so a double-click opens the editor with the
  /// cursor there.
  final void Function(int txnId, EditField field) onRowTap;
  final ValueChanged<RegisterRow> onToggleCleared;
  final ValueChanged<RegisterRow> onConfirm;
  final void Function(RegisterRow row, AccountInfo category) onSetCategory;
  final ValueChanged<RegisterRow> onDelete;
  final VoidCallback onClearSelection;
  final ValueChanged<RegisterRow> onEdit;
  final VoidCallback onCancelEdit;

  /// Takes back the reconcile that locked this row (the account's latest).
  final ValueChanged<RegisterRow> onUnreconcile;

  /// Moves the row's side to another account (entered in the wrong one).
  final void Function(RegisterRow row, AccountInfo account) onMove;
}

/// The transaction open for editing, if any.
typedef RegisterEditing = ({
  int txnId,
  EditField focus,
  EntryRowController controller,

  /// Opened from Confirm: dated today, amount selected, and saving confirms.
  bool confirming,
});

class RegisterPanel extends StatelessWidget {
  const RegisterPanel({
    super.key,
    required this.posted,
    required this.scheduled,
    required this.filter,
    required this.search,
    required this.selected,
    this.selectedKey,
    required this.hoveredStatus,
    required this.categories,
    required this.transferTargets,
    this.allAccounts,
    required this.entryController,
    required this.today,
    required this.actions,
    this.editing,
    this.adding = false,
    this.onCloseEntry,
    this.addButton,
    this.reconcileThrough,
    this.owed = false,
    this.accountName,
  });

  /// The account shown, so a transfer being entered can say which way it goes.
  final String? accountName;

  /// A credit account: the Balance column shows what's owed, positive, and
  /// is never coral.
  final bool owed;

  /// Reconciling: only rows not yet reconciled, dated on or before this
  /// statement date, so they can be ticked off against it.
  final DateTime? reconcileThrough;

  /// Opens the new-transaction row; sits at the end of the tab row, above
  /// where the row opens.
  final Widget? addButton;

  /// The new-transaction row is open (from Add or ⌘N).
  final bool adding;
  final VoidCallback? onCloseEntry;

  final RegisterEditing? editing;
  final List<RegisterRow> posted;
  final List<RegisterRow> scheduled;
  final RegisterFilter filter;
  final String search;
  final int? selected;

  /// Put on the selected row so the screen can scroll it into view.
  final Key? selectedKey;
  final ValueNotifier<Cleared?> hoveredStatus;
  final List<AccountInfo> categories;
  final List<AccountInfo> transferTargets;

  /// All accounts: each row's account by id. The last column names it, in
  /// place of a running balance that would mix accounts, and the entry row
  /// asks which account a new row goes in.
  final Map<int, AccountInfo>? allAccounts;
  final EntryRowController entryController;
  final DateTime today;
  final RegisterActions actions;

  bool _matches(RegisterRow r) {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return true;
    final digits = q.replaceAll(RegExp(r'[,\s₮]'), '');
    return r.payee.toLowerCase().contains(q) ||
        r.memo.toLowerCase().contains(q) ||
        (_accountOf(r)?.toLowerCase().contains(q) ?? false) ||
        r.categoryLabel.toLowerCase().contains(q) ||
        (digits.isNotEmpty &&
            RegExp(r'^\d+$').hasMatch(digits) &&
            formatWhole(r.amount).replaceAll(',', '').contains(digits));
  }

  String? _accountOf(RegisterRow r) => allAccounts?[r.accountId]?.name;

  @override
  Widget build(BuildContext context) {
    final uncleared = posted
        .where((r) => r.cleared == Cleared.uncleared)
        .length;
    final status = switch (filter) {
      RegisterFilter.uncleared => Cleared.uncleared,
      RegisterFilter.cleared => Cleared.cleared,
      RegisterFilter.reconciled => Cleared.reconciled,
      _ => null,
    };
    final through = reconcileThrough;
    final visiblePosted = posted.reversed
        .where(
          (r) => through == null
              ? status == null || r.cleared == status
              : r.cleared != Cleared.reconciled && !r.date.isAfter(through),
        )
        .where(_matches)
        .toList();
    final visibleScheduled = scheduled.where(_matches).toList();
    final showScheduled = through == null && filter == RegisterFilter.scheduled;
    final showNext =
        through == null &&
        filter == RegisterFilter.all &&
        visibleScheduled.isNotEmpty &&
        search.isEmpty;

    void tap(int id, [EditField field = EditField.payee]) =>
        actions.onRowTap(id, field);
    Widget? bar(RegisterRow r) => selected == r.txnId
        ? _RowActions(
            row: r,
            categories: categories,
            accounts: transferTargets,
            actions: actions,
          )
        : null;

    Widget? editor(RegisterRow r) {
      final e = editing;
      if (e == null || e.txnId != r.txnId) return null;
      return EntryRow(
        key: ValueKey('edit-${r.txnId}'),
        controller: e.controller,
        categories: categories,
        // Never a transfer to its own account.
        transferTargets: transferTargets
            .where((a) => a.id != r.accountId)
            .toList(),
        today: today,
        accountName: _accountOf(r) ?? accountName,
        initial: EditInitial.fromRow(
          r,
          focus: e.focus,
          confirmingOn: e.confirming ? today : null,
        ),
        onCancel: actions.onCancelEdit,
      );
    }

    // A row opening into the editor (or its action bar) grows smoothly, and
    // shrinks back when it closes. Keyed by transaction so the animation
    // follows the row, not its place in the list.
    final grow = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    Widget keyed(RegisterRow r, Widget row) => SmoothHeight(
      key: ValueKey('row-${r.txnId}'),
      duration: grow,
      child: r.txnId == selected && selectedKey != null
          ? KeyedSubtree(key: selectedKey, child: row)
          : row,
    );

    final children = <Widget>[];
    if (showScheduled) {
      if (visibleScheduled.isEmpty) children.add(_empty('Nothing scheduled'));
      for (final r in visibleScheduled) {
        children.add(
          keyed(
            r,
            editor(r) ??
                _ScheduledRow(
                  row: r,
                  today: today,
                  onConfirm: () => actions.onConfirm(r),
                  extra: null,
                  accountName: _accountOf(r),
                  bar: bar(r),
                  onTap: () => tap(r.txnId),
                ),
          ),
        );
      }
    } else {
      if (showNext) {
        final next = visibleScheduled.first;
        children.add(
          keyed(
            next,
            editor(next) ??
                _ScheduledRow(
                  row: next,
                  today: today,
                  onConfirm: () => actions.onConfirm(next),
                  // All accounts: which account, not how many (the
                  // Scheduled tab counts them), so the payee keeps its room.
                  extra: _accountOf(next) != null
                      ? null
                      : (visibleScheduled.length > 1
                            ? 'next of ${visibleScheduled.length} scheduled'
                            : 'scheduled'),
                  accountName: _accountOf(next),
                  onMore: () => actions.onFilter(RegisterFilter.scheduled),
                  bar: bar(next),
                  onTap: () => tap(next.txnId),
                ),
          ),
        );
      }
      if (visiblePosted.isEmpty) {
        children.add(
          _empty(
            search.isEmpty ? 'No transactions' : 'Nothing matches “$search”',
          ),
        );
      }
      for (final (i, r) in visiblePosted.indexed) {
        children.add(
          keyed(
            r,
            editor(r) ??
                _PostedRow(
                  row: r,
                  today: today,
                  owed: owed,
                  accountName: _accountOf(r),
                  striped: i.isOdd,
                  reconciling: through != null,
                  bar: bar(r),
                  onTap: (field) => tap(r.txnId, field),
                  onToggleCleared: () => actions.onToggleCleared(r),
                  categories: categories,
                  onSetCategory: (c) => actions.onSetCategory(r, c),
                  hoveredStatus: hoveredStatus,
                ),
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Mid.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Mid.rule),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: through != null
                        ? Text(
                            'Not reconciled, through ${fullDate(through)}',
                            style: onest(13, color: Mid.ink2),
                          )
                        : _Tabs(
                            filter: filter,
                            uncleared: uncleared,
                            scheduled: scheduled.length,
                            onFilter: actions.onFilter,
                          ),
                  ),
                  ?addButton,
                ],
              ),
            ),
          ),
          _HeaderRow(
            balance: allAccounts != null
                ? 'Account'
                : through != null
                ? 'Cleared balance'
                : (owed ? 'Owed' : 'Balance'),
          ),
          SmoothHeight(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 160),
            child: adding
                ? EntryRow(
                    controller: entryController,
                    categories: categories,
                    transferTargets: transferTargets,
                    today: today,
                    accountName: accountName,
                    accountChoices: allAccounts == null
                        ? null
                        : transferTargets,
                    onCancel: onCloseEntry,
                  )
                : const SizedBox(width: double.infinity),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 12),
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Center(
      child: Text(text, style: onest(13, color: Mid.ink3)),
    ),
  );
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.filter,
    required this.uncleared,
    required this.scheduled,
    required this.onFilter,
  });

  final RegisterFilter filter;
  final int uncleared;
  final int scheduled;
  final ValueChanged<RegisterFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final statusTab = switch (filter) {
      RegisterFilter.cleared => Cleared.cleared,
      RegisterFilter.reconciled => Cleared.reconciled,
      _ => null,
    };
    return Row(
      children: [
        _Tab(
          'All',
          null,
          filter == RegisterFilter.all,
          () => onFilter(RegisterFilter.all),
        ),
        _Tab(
          'Uncleared',
          uncleared,
          filter == RegisterFilter.uncleared,
          () => onFilter(RegisterFilter.uncleared),
        ),
        _Tab(
          'Scheduled',
          scheduled,
          filter == RegisterFilter.scheduled,
          () => onFilter(RegisterFilter.scheduled),
        ),
        // Cleared and reconciled are reached from the header's key; show the
        // tab only while it's the active filter, with a way back out.
        if (statusTab != null)
          _Tab(
            StatusGlyph.label(statusTab),
            null,
            true,
            () => onFilter(RegisterFilter.all),
            closable: true,
          ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab(
    this.label,
    this.count,
    this.active,
    this.onTap, {
    this.closable = false,
  });
  final String label;
  final int? count;
  final bool active;
  final VoidCallback onTap;
  final bool closable;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Hoverable(
      onTap: onTap,
      builder: (hover) => Container(
        height: 28,
        padding: EdgeInsets.only(left: 12, right: closable ? 8 : 12),
        decoration: BoxDecoration(
          color: active ? Mid.raised : (hover ? Mid.hover : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: onest(13, color: active ? Mid.ink : Mid.ink3)),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 4),
              Text(
                '($count)',
                style: onest(11.5, color: Mid.ink3, tabular: true),
              ),
            ],
            if (closable) ...[
              const SizedBox(width: 6),
              const Icon(Icons.close_rounded, size: 13, color: Mid.ink2),
            ],
          ],
        ),
      ),
    ),
  );
}

/// The clicked row's actions, attached under it. Only what applies to this
/// row shows: one of Mark cleared / Mark uncleared, no Categorize on splits
/// and transfers. Reconciled rows keep Edit and Categorize (payee, memo and
/// category aren't on a statement) but not Move, Delete or clearing.
class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.row,
    required this.categories,
    required this.accounts,
    required this.actions,
  });

  final RegisterRow row;
  final List<AccountInfo> categories;

  /// The other accounts, for Move to.
  final List<AccountInfo> accounts;
  final RegisterActions actions;

  @override
  Widget build(BuildContext context) {
    final r = row;
    final locked = r.cleared == Cleared.reconciled;
    final edit = BarButton(
      label: 'Edit',
      leading: const Icon(Icons.edit_rounded, size: 13, color: Mid.ink3),
      onTap: () => actions.onEdit(r),
    );
    final categorize = r.kind == RowKind.simple
        ? CategoryMenu(
            categories: categories,
            onPicked: (c) => actions.onSetCategory(r, c),
            builder: (open, toggle) => BarButton(
              label: 'Categorize',
              trailing: Icons.keyboard_arrow_down_rounded,
              active: open,
              onTap: toggle,
            ),
          )
        : null;
    final clearButton = r.cleared == Cleared.uncleared
        ? BarButton(
            label: 'Mark cleared',
            leading: const StatusGlyph(Cleared.cleared),
            onTap: () => actions.onToggleCleared(r),
          )
        : BarButton(
            label: 'Mark uncleared',
            leading: const StatusGlyph(Cleared.uncleared),
            onTap: () => actions.onToggleCleared(r),
          );
    // A transfer can't move onto its own other side; an opening balance
    // belongs to its account.
    // In All accounts the list has every account, its own included.
    final targets = accounts
        .where(
          (a) =>
              a.id != r.accountId &&
              !(r.kind == RowKind.transfer && a.name == r.payee),
        )
        .toList();
    final move = r.kind != RowKind.opening && targets.isNotEmpty
        ? CategoryMenu(
            categories: targets,
            onPicked: (a) => actions.onMove(r, a),
            builder: (open, toggle) => BarButton(
              key: const ValueKey('move-to'),
              label: 'Move to',
              trailing: Icons.keyboard_arrow_down_rounded,
              active: open,
              onTap: toggle,
            ),
          )
        : null;
    // Taps between the buttons mustn't reach the row and deselect it.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        height: 40,
        padding: const EdgeInsets.fromLTRB(
          Cols.status + Cols.gap - 10,
          0,
          0,
          4,
        ),
        child: Row(
          children: [
            if (locked) ...[
              edit,
              ?categorize,
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 12),
                child: Text(
                  r.reconciledOn == null
                      ? 'Reconciled · date and amount locked'
                      : 'Reconciled on ${shortDate(r.reconciledOn!)} · date and amount locked',
                  style: onest(13, color: Mid.ink3),
                ),
              ),
              // Only the newest reconcile comes undone, so they unwind in
              // order and every older lock still matches its statement.
              if (r.latestReconcile)
                BarButton(
                  key: const ValueKey('unreconcile'),
                  label: 'Undo this reconcile',
                  onTap: () => actions.onUnreconcile(r),
                ),
            ]
            // This side of a transfer can still clear; the rest is locked.
            else if (r.lockedIn != null) ...[
              edit,
              clearButton,
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'Reconciled in ${r.lockedIn} · date and amount locked',
                  style: onest(13, color: Mid.ink3),
                ),
              ),
            ] else ...[
              edit,
              ?categorize,
              if (!r.scheduled) clearButton,
              ?move,
              BarButton(
                label: 'Delete',
                color: Mid.coral,
                onTap: () => actions.onDelete(r),
              ),
            ],
            const Spacer(),
            Hoverable(
              onTap: actions.onClearSelection,
              builder: (h) => Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: h ? Mid.ink : Mid.ink3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An outlined button, so it reads as a button and not a label.
class BarButton extends StatelessWidget {
  const BarButton({
    super.key,
    required this.label,
    required this.onTap,
    this.leading,
    this.trailing,
    this.color = Mid.ink2,
    this.active = false,
  });

  final String label;
  final VoidCallback onTap;
  final Widget? leading;
  final IconData? trailing;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Hoverable(
      onTap: onTap,
      builder: (hover) => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: hover || active ? Mid.raised : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          // Outlined so each reads as a button, not a label.
          border: Border.all(
            color: (color == Mid.ink2 ? Mid.ink2 : color).withValues(
              alpha: hover || active ? 0.6 : 0.3,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 6)],
            Text(
              label,
              style: onest(
                13,
                color: hover || active
                    ? (color == Mid.ink2 ? Mid.ink : color)
                    : color,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 2),
              Icon(trailing, size: 14, color: Mid.ink3),
            ],
          ],
        ),
      ),
    ),
  );
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.balance});

  /// The last column's name: it shows cleared rows only while reconciling.
  final String balance;

  @override
  Widget build(BuildContext context) {
    final s = onest(12, color: Mid.ink3);
    return Padding(
      padding: Cols.outer,
      child: Container(
        height: 30,
        padding: Cols.inset,
        child: Row(
          children: [
            const SizedBox(width: Cols.status),
            const SizedBox(width: Cols.gap),
            SizedBox(
              width: Cols.date,
              child: Text('Date', style: s),
            ),
            const SizedBox(width: Cols.gap),
            Expanded(child: Text('Payee', style: s)),
            const SizedBox(width: Cols.gap),
            SizedBox(
              width: Cols.category,
              child: Text('Category', style: s),
            ),
            const SizedBox(width: Cols.gap),
            SizedBox(
              width: Cols.amount,
              child: Text('Amount', style: s, textAlign: TextAlign.right),
            ),
            const SizedBox(width: Cols.gap),
            SizedBox(
              width: Cols.balance,
              child: Text(balance, style: s, textAlign: TextAlign.right),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostedRow extends StatelessWidget {
  const _PostedRow({
    required this.row,
    required this.today,
    required this.owed,
    this.accountName,
    required this.striped,
    required this.reconciling,
    required this.bar,
    required this.onTap,
    required this.onToggleCleared,
    required this.categories,
    required this.onSetCategory,
    required this.hoveredStatus,
  });

  final RegisterRow row;
  final DateTime today;
  final bool owed;

  /// All accounts: the row's account, shown where the balance would be.
  final String? accountName;

  /// Every other row is tinted, to tell transactions apart at a glance.
  final bool striped;

  /// While reconciling, the Balance column runs over cleared rows only, to
  /// compare line by line with the statement's running balance. Uncleared
  /// rows show none.
  final bool reconciling;

  /// The row's actions, attached under it while it's selected.
  final Widget? bar;

  /// Which cell was clicked, so a double-click edits that field.
  final ValueChanged<EditField> onTap;
  final VoidCallback onToggleCleared;
  final List<AccountInfo> categories;
  final ValueChanged<AccountInfo> onSetCategory;
  final ValueNotifier<Cleared?> hoveredStatus;

  @override
  Widget build(BuildContext context) {
    final selected = bar != null;
    final r = row;
    final memo = r.kind == RowKind.split && r.memo.isEmpty
        ? r.splitLines
              .map((l) => '${l.name} ₮${formatWhole(l.amount)}')
              .join(' · ')
        : r.memo;
    final stale = staleNote(r, today);
    final statusTip =
        (r.clearedIn == null ? '' : 'In ${r.clearedIn}: ') +
        switch (r.cleared) {
          Cleared.uncleared => 'Uncleared — not settled at the bank yet, even if it shows there as pending. Click once it clears.',
          Cleared.cleared =>
            'Cleared — settled at the bank. Click to mark uncleared.',
          Cleared.reconciled => 'Reconciled — matches a statement, so its date and amount are locked.',
        };

    return ValueListenableBuilder<Cleared?>(
      valueListenable: hoveredStatus,
      builder: (context, hovered, child) => AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: hovered == null || hovered == r.cleared ? 1 : 0.35,
        child: child,
      ),
      child: Padding(
        padding: Cols.outer,
        child: Hoverable(
          onTap: () => onTap(EditField.payee),
          builder: (hover) => Container(
            padding: Cols.inset,
            decoration: BoxDecoration(
              // Hover lays over the stripe, so it still shows on tinted rows.
              color: selected
                  ? Mid.blueWash
                  : Color.alphaBlend(
                      hover ? Mid.rowHover : Colors.transparent,
                      striped ? Mid.stripe : Colors.transparent,
                    ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? Mid.blueEdge : Colors.transparent,
              ),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      SizedBox(
                        width: Cols.status,
                        child: MouseRegion(
                          onEnter: (_) => hoveredStatus.value = r.cleared,
                          onExit: (_) {
                            if (hoveredStatus.value == r.cleared) {
                              hoveredStatus.value = null;
                            }
                          },
                          child: Tooltip(
                            message: statusTip,
                            child: Hoverable(
                              onTap: r.cleared == Cleared.reconciled
                                  ? null
                                  : onToggleCleared,
                              builder: (h) => Container(
                                height: 28,
                                decoration: BoxDecoration(
                                  color: h && r.cleared != Cleared.reconciled
                                      ? Mid.raised
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(child: StatusGlyph(r.cleared)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Cols.gap),
                      _Cell(
                        width: Cols.date,
                        onTap: () => onTap(EditField.date),
                        child: Text(
                          fullDate(r.date),
                          style: onest(13, color: Mid.ink3, tabular: true),
                        ),
                      ),
                      const SizedBox(width: Cols.gap),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (r.kind == RowKind.transfer) ...[
                                  Text(
                                    r.amount < 0 ? 'To' : 'From',
                                    style: onest(14.5, color: Mid.ink3),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Flexible(
                                  child: Text(
                                    r.payee,
                                    style: onest(14.5, weight: 500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (r.kind == RowKind.transfer ||
                                    r.kind == RowKind.split) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    r.kind == RowKind.transfer
                                        ? Icons.swap_horiz_rounded
                                        : Icons.call_split_rounded,
                                    size: 14,
                                    color: Mid.ink3,
                                  ),
                                ],
                              ],
                            ),
                            if (memo.isNotEmpty || stale != null) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (memo.isNotEmpty)
                                    Flexible(
                                      child: GestureDetector(
                                        onTap: () => onTap(EditField.memo),
                                        child: Text(
                                          memo,
                                          style: onest(12.5, color: Mid.ink3),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  // Brighter than the memo: it's why Working
                                  // may be lower than it should be.
                                  // Whole, with the memo shrinking first; it's
                                  // short enough to fit any payee column.
                                  if (stale != null)
                                    Text(
                                      '${memo.isEmpty ? '' : ' · '}$stale',
                                      key: const ValueKey('stale-note'),
                                      style: onest(12.5, color: Mid.ink2),
                                      maxLines: 1,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: Cols.gap),
                      SizedBox(
                        width: Cols.category,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: r.kind == RowKind.simple
                              ? CategoryMenu(
                                  categories: categories,
                                  current: r.categoryLabel,
                                  onPicked: onSetCategory,
                                  builder: (open, toggle) => _CategoryChip(
                                    label: r.categoryLabel,
                                    open: open,
                                    onTap: toggle,
                                  ),
                                )
                              : Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Text(
                                    r.categoryLabel,
                                    style: onest(12.5, color: Mid.ink3),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: Cols.gap),
                      _Cell(
                        width: Cols.amount,
                        onTap: () => onTap(EditField.amount),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: r.amount > 0
                              ? Money(
                                  r.amount,
                                  color: Mid.green,
                                  centsColor: Mid.green.withValues(alpha: 0.6),
                                  sign: MoneySign.plusForPositive,
                                )
                              : Money(r.amount, sign: MoneySign.none),
                        ),
                      ),
                      const SizedBox(width: Cols.gap),
                      SizedBox(
                        width: Cols.balance,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: accountName != null
                              ? Text(
                                  accountName!,
                                  style: onest(13, color: Mid.ink2),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : reconciling && r.cleared == Cleared.uncleared
                              ? null
                              : Builder(
                                  builder: (context) {
                                    final raw = reconciling
                                        ? r.clearedBalance
                                        : r.balance;
                                    final b = owed ? -raw : raw;
                                    return Money(
                                      b,
                                      color: !owed && b < 0
                                          ? Mid.coral
                                          : (r.cleared == Cleared.uncleared
                                                ? Mid.ink2
                                                : Mid.ink),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                ?bar,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduledRow extends StatelessWidget {
  const _ScheduledRow({
    required this.row,
    required this.today,
    required this.onConfirm,
    required this.extra,
    required this.bar,
    required this.onTap,
    this.onMore,
    this.accountName,
  });

  /// All accounts: which account it's in, shown even when overdue.
  final String? accountName;

  final RegisterRow row;
  final DateTime today;
  final VoidCallback onConfirm;
  final String? extra;
  final VoidCallback? onMore;

  /// The row's actions, attached under it while it's selected.
  final Widget? bar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = bar != null;
    final r = row;
    final label = r.kind == RowKind.transfer
        ? '${r.amount < 0 ? 'To' : 'From'} ${r.payee}'
        : r.payee;
    final overdue = overdueNote(r, today);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Hoverable(
        onTap: onTap,
        builder: (hover) => CustomPaint(
          painter: _DashedBorder(
            color: selected
                ? Mid.blueEdge
                : Mid.gold.withValues(alpha: hover ? 0.55 : 0.35),
          ),
          child: Container(
            padding: Cols.inset,
            decoration: BoxDecoration(
              color: selected ? Mid.blueWash : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 46,
                  child: Row(
                    children: [
                      const SizedBox(
                        width: Cols.status,
                        child: Tooltip(
                          message:
                              'Scheduled — not in any balance until confirmed',
                          child: Icon(
                            Icons.event_repeat_rounded,
                            size: 14,
                            color: Mid.gold,
                          ),
                        ),
                      ),
                      const SizedBox(width: Cols.gap),
                      SizedBox(
                        width: Cols.date,
                        child: Text(
                          fullDate(r.date),
                          style: onest(13, color: Mid.gold, tabular: true),
                        ),
                      ),
                      const SizedBox(width: Cols.gap),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                label,
                                style: onest(14, color: Mid.ink2),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Past its date and not confirmed: it isn't in
                            // Working, though it probably happened.
                            if (overdue != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '· $overdue',
                                key: const ValueKey('overdue-note'),
                                style: onest(14, color: Mid.gold),
                              ),
                            ],
                            // The overdue note takes the place of "next of
                            // N scheduled", which the Scheduled tab also
                            // counts, so the payee keeps its room.
                            if (accountName != null) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '· $accountName',
                                  style: onest(14, color: Mid.ink3),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            if (extra != null && overdue == null) ...[
                              const SizedBox(width: 8),
                              Hoverable(
                                onTap: onMore,
                                builder: (h) => Text(
                                  '· $extra',
                                  style: onest(14, color: Mid.ink3).copyWith(
                                    decoration: onMore != null && h
                                        ? TextDecoration.underline
                                        : null,
                                    decorationColor: Mid.ink3,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: Cols.gap),
                      SizedBox(
                        width: Cols.category,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            r.categoryLabel,
                            style: onest(12.5, color: Mid.ink3),
                          ),
                        ),
                      ),
                      const SizedBox(width: Cols.gap),
                      SizedBox(
                        width: Cols.amount,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: r.amount > 0
                              ? Money(
                                  r.amount,
                                  color: Mid.green,
                                  centsColor: Mid.green.withValues(alpha: 0.6),
                                  sign: MoneySign.plusForPositive,
                                )
                              : Money(
                                  r.amount,
                                  color: Mid.ink2,
                                  sign: MoneySign.none,
                                ),
                        ),
                      ),
                      const SizedBox(width: Cols.gap),
                      SizedBox(
                        width: Cols.balance,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Hoverable(
                            onTap: onConfirm,
                            builder: (h) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: h
                                    ? Mid.gold.withValues(alpha: 0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Confirm',
                                style: onest(13, weight: 500, color: Mid.gold),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ?bar,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.open,
    required this.onTap,
  });
  final String label;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Hoverable(
    onTap: onTap,
    builder: (hover) => Container(
      height: 28,
      padding: const EdgeInsets.fromLTRB(10, 0, 8, 0),
      decoration: BoxDecoration(
        color: open ? Mid.ground : (hover ? Mid.raised : Mid.chip),
        borderRadius: BorderRadius.circular(open ? 8 : 14),
        border: Border.all(
          color: open ? Mid.blue : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: open
            ? [
                BoxShadow(
                  color: Mid.blue.withValues(alpha: 0.18),
                  spreadRadius: 4,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: onest(12.5, color: open ? Mid.ink : Mid.ink2),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hover || open) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: Mid.ink2,
            ),
          ],
        ],
      ),
    ),
  );
}

/// A list of categories (or accounts, for Move to) that opens in place.
/// No modal.
class CategoryMenu extends StatelessWidget {
  const CategoryMenu({
    super.key,
    required this.categories,
    required this.onPicked,
    required this.builder,
    this.current,
  });

  final List<AccountInfo> categories;
  final ValueChanged<AccountInfo> onPicked;
  final String? current;
  final Widget Function(bool open, VoidCallback toggle) builder;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Mid.raised),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 6),
        ),
        maximumSize: const WidgetStatePropertyAll(Size(260, 360)),
      ),
      alignmentOffset: const Offset(0, 4),
      menuChildren: [
        for (final c in categories.where((c) => !c.archived))
          MenuItemButton(
            onPressed: () => onPicked(c),
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(220, 34)),
              overlayColor: WidgetStatePropertyAll(Mid.blueWash),
            ),
            trailingIcon: c.name == current
                ? const Icon(Icons.check_rounded, size: 14, color: Mid.blue)
                : null,
            child: Text(
              c.name,
              style: onest(13, color: c.name == current ? Mid.ink : Mid.ink2),
            ),
          ),
      ],
      builder: (context, menu, _) =>
          builder(menu.isOpen, () => menu.isOpen ? menu.close() : menu.open()),
    );
  }
}

/// Eases its height to its child's whenever the child's height changes, from
/// wherever it is at that moment. Flutter's AnimatedSize snaps instead when
/// the size changes again mid-animation, which is exactly a double-click: the
/// first click opens the action bar, the second opens the editor.
class SmoothHeight extends StatefulWidget {
  const SmoothHeight({super.key, required this.duration, required this.child});
  final Duration duration;
  final Widget child;

  @override
  State<SmoothHeight> createState() => _SmoothHeightState();
}

class _SmoothHeightState extends State<SmoothHeight>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );

  @override
  void didUpdateWidget(SmoothHeight old) {
    super.didUpdateWidget(old);
    _controller.duration = widget.duration;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _SmoothHeightBox(controller: _controller, child: widget.child);
}

class _SmoothHeightBox extends SingleChildRenderObjectWidget {
  const _SmoothHeightBox({required this.controller, super.child});
  final AnimationController controller;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSmoothHeight(controller);
}

/// Only for rows in a scrolling list: intrinsic and dry sizes come from the
/// child, since lists never ask for them.
class _RenderSmoothHeight extends RenderProxyBox {
  _RenderSmoothHeight(this.controller);
  final AnimationController controller;
  double? _from, _to, _width;
  final _clip = LayerHandle<ClipRectLayer>();

  /// A new target is set and the animation starts after this frame.
  bool _starting = false;

  /// The height shown this frame.
  double get _height {
    if (_starting) return _from!;
    // Exactly the target once done, or a rounding error would clip for good.
    if (controller.value == 1) return _to!;
    final t = Curves.easeOutCubic.transform(controller.value);
    return _from! * (1 - t) + _to! * t;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    controller.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    controller.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void performLayout() {
    final child = this.child!;
    child.layout(constraints.copyWith(minHeight: 0), parentUsesSize: true);
    final target = child.size.height;
    // A new width (the window resized) snaps: only opening and closing ease.
    final resized = _width != null && _width != constraints.maxWidth;
    _width = constraints.maxWidth;
    if (_to == null || resized || controller.duration == Duration.zero) {
      _from = _to = target;
    } else if (target != _to) {
      // Start from what's on screen now, even mid-animation.
      _from = _height;
      _to = target;
      // Not during layout: the controller's listener would ask for another.
      if (!_starting) {
        _starting = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _starting = false;
          if (attached) controller.forward(from: 0);
        });
      }
    }
    size = constraints.constrain(Size(child.size.width, _height));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_height >= child!.size.height) {
      _clip.layer = null;
      super.paint(context, offset);
    } else {
      _clip.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        super.paint,
        oldLayer: _clip.layer,
      );
    }
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }
}

class Hoverable extends StatefulWidget {
  const Hoverable({super.key, required this.builder, this.onTap});
  final Widget Function(bool hover) builder;
  final VoidCallback? onTap;

  @override
  State<Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<Hoverable> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: widget.builder(_hover),
    ),
  );
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(10),
    ).deflate(0.5);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, d + 3.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

/// A register cell that reports its own click, so a double-click can open the
/// editor on the matching field.
class _Cell extends StatelessWidget {
  const _Cell({required this.width, required this.onTap, required this.child});
  final double width;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: SizedBox(
      width: width,
      height: 52,
      child: Align(alignment: Alignment.centerLeft, child: child),
    ),
  );
}
