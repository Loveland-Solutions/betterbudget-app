import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../domain/ledger.dart';
import '../domain/money.dart';
import 'entry_row.dart';
import 'theme.dart';

enum RegisterFilter { all, uncleared, cleared, reconciled, scheduled }

bool get _isMac =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;

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
    required this.onBulkCategorize,
    required this.onBulkCleared,
    required this.onBulkDelete,
    required this.onClearSelection,
    required this.onEditSelected,
    required this.onCancelEdit,
  });

  final ValueChanged<RegisterFilter> onFilter;

  /// [order] is the visible row order, for Shift-click ranges. [field] is the
  /// cell clicked, so a double-click opens the editor with the cursor there.
  final void Function(int txnId, List<int> order, EditField field) onRowTap;
  final ValueChanged<RegisterRow> onToggleCleared;
  final ValueChanged<RegisterRow> onConfirm;
  final void Function(RegisterRow row, AccountInfo category) onSetCategory;
  final ValueChanged<AccountInfo> onBulkCategorize;
  final ValueChanged<Cleared> onBulkCleared;
  final VoidCallback onBulkDelete;
  final VoidCallback onClearSelection;
  final VoidCallback onEditSelected;
  final VoidCallback onCancelEdit;
}

/// The transaction open for editing, if any.
typedef RegisterEditing = ({
  int txnId,
  EditField focus,
  EntryRowController controller,
});

class RegisterPanel extends StatelessWidget {
  const RegisterPanel({
    super.key,
    required this.posted,
    required this.scheduled,
    required this.filter,
    required this.search,
    required this.selection,
    required this.hoveredStatus,
    required this.categories,
    required this.transferTargets,
    required this.entryController,
    required this.today,
    required this.actions,
    this.editing,
  });

  final RegisterEditing? editing;
  final List<RegisterRow> posted;
  final List<RegisterRow> scheduled;
  final RegisterFilter filter;
  final String search;
  final Set<int> selection;
  final ValueNotifier<Cleared?> hoveredStatus;
  final List<AccountInfo> categories;
  final List<AccountInfo> transferTargets;
  final EntryRowController entryController;
  final DateTime today;
  final RegisterActions actions;

  bool _matches(RegisterRow r) {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return true;
    final digits = q.replaceAll(RegExp(r'[,\s₮]'), '');
    return r.payee.toLowerCase().contains(q) ||
        r.memo.toLowerCase().contains(q) ||
        r.categoryLabel.toLowerCase().contains(q) ||
        (digits.isNotEmpty &&
            RegExp(r'^\d+$').hasMatch(digits) &&
            formatWhole(r.amount).replaceAll(',', '').contains(digits));
  }

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
    final visiblePosted = posted.reversed
        .where((r) => status == null || r.cleared == status)
        .where(_matches)
        .toList();
    final visibleScheduled = scheduled.where(_matches).toList();
    final showScheduled = filter == RegisterFilter.scheduled;
    final showNext =
        filter == RegisterFilter.all &&
        visibleScheduled.isNotEmpty &&
        search.isEmpty;

    final order = [
      if (showScheduled) ...visibleScheduled.map((r) => r.txnId),
      if (showNext) visibleScheduled.first.txnId,
      if (!showScheduled) ...visiblePosted.map((r) => r.txnId),
    ];
    void tap(int id, [EditField field = EditField.payee]) =>
        actions.onRowTap(id, order, field);

    Widget? editor(RegisterRow r) {
      final e = editing;
      if (e == null || e.txnId != r.txnId) return null;
      return EntryRow(
        key: ValueKey('edit-${r.txnId}'),
        controller: e.controller,
        categories: categories,
        transferTargets: transferTargets,
        today: today,
        initial: EditInitial.fromRow(r, focus: e.focus),
        onCancel: actions.onCancelEdit,
      );
    }

    final children = <Widget>[];
    if (showScheduled) {
      if (visibleScheduled.isEmpty) children.add(_empty('Nothing scheduled'));
      for (final r in visibleScheduled) {
        children.add(
          editor(r) ??
              _ScheduledRow(
                row: r,
                onConfirm: () => actions.onConfirm(r),
                extra: null,
                selected: selection.contains(r.txnId),
                onTap: () => tap(r.txnId),
              ),
        );
      }
    } else {
      if (showNext) {
        final next = visibleScheduled.first;
        children.add(
          editor(next) ??
              _ScheduledRow(
                row: next,
                onConfirm: () => actions.onConfirm(next),
                extra: visibleScheduled.length > 1
                    ? 'next of ${visibleScheduled.length} scheduled'
                    : 'scheduled',
                onMore: () => actions.onFilter(RegisterFilter.scheduled),
                selected: selection.contains(next.txnId),
                onTap: () => tap(next.txnId),
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
      for (final r in visiblePosted) {
        children.add(
          editor(r) ??
              _PostedRow(
                row: r,
                selected: selection.contains(r.txnId),
                onTap: (field) => tap(r.txnId, field),
                onToggleCleared: () => actions.onToggleCleared(r),
                categories: categories,
                onSetCategory: (c) => actions.onSetCategory(r, c),
                hoveredStatus: hoveredStatus,
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
              child: selection.isEmpty
                  ? _Tabs(
                      filter: filter,
                      uncleared: uncleared,
                      scheduled: scheduled.length,
                      onFilter: actions.onFilter,
                    )
                  : _BulkBar(
                      count: selection.length,
                      categories: categories,
                      actions: actions,
                    ),
            ),
          ),
          const _HeaderRow(),
          EntryRow(
            controller: entryController,
            categories: categories,
            transferTargets: transferTargets,
            today: today,
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
              const SizedBox(width: 6),
              Text(
                '$count',
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

/// Replaces the tabs while rows are selected. Shows up on a single selection
/// too, so the bulk actions (and how to select more) are discoverable.
class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.count,
    required this.categories,
    required this.actions,
  });

  final int count;
  final List<AccountInfo> categories;
  final RegisterActions actions;

  @override
  Widget build(BuildContext context) {
    final mod = _isMac ? '⌘' : 'Ctrl';
    return Row(
      children: [
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Mid.blueWash,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count selected',
            style: onest(13, weight: 500, color: Mid.ink, tabular: true),
          ),
        ),
        const SizedBox(width: 12),
        if (count == 1)
          _BarButton(
            label: 'Edit',
            leading: const Icon(Icons.edit_rounded, size: 13, color: Mid.ink3),
            onTap: actions.onEditSelected,
          ),
        CategoryMenu(
          categories: categories,
          onPicked: actions.onBulkCategorize,
          builder: (open, toggle) => _BarButton(
            label: 'Categorize',
            trailing: Icons.keyboard_arrow_down_rounded,
            active: open,
            onTap: toggle,
          ),
        ),
        _BarButton(
          label: 'Mark cleared',
          leading: const StatusGlyph(Cleared.cleared),
          onTap: () => actions.onBulkCleared(Cleared.cleared),
        ),
        _BarButton(
          label: 'Mark uncleared',
          leading: const StatusGlyph(Cleared.uncleared),
          onTap: () => actions.onBulkCleared(Cleared.uncleared),
        ),
        _BarButton(
          label: 'Delete',
          color: Mid.coral,
          onTap: actions.onBulkDelete,
        ),
        const Spacer(),
        Text(
          count == 1
              ? 'Double-click or Enter to edit · $mod-click to select more'
              : 'Esc to clear',
          style: onest(12, color: Mid.ink3),
        ),
        const SizedBox(width: 8),
        Hoverable(
          onTap: actions.onClearSelection,
          builder: (h) => Icon(
            Icons.close_rounded,
            size: 16,
            color: h ? Mid.ink : Mid.ink3,
          ),
        ),
      ],
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
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
    padding: const EdgeInsets.only(right: 4),
    child: Hoverable(
      onTap: onTap,
      builder: (hover) => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: hover || active ? Mid.raised : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
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
  const _HeaderRow();

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
              child: Text('Balance', style: s, textAlign: TextAlign.right),
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
    required this.selected,
    required this.onTap,
    required this.onToggleCleared,
    required this.categories,
    required this.onSetCategory,
    required this.hoveredStatus,
  });

  final RegisterRow row;
  final bool selected;

  /// Which cell was clicked, so a double-click edits that field.
  final ValueChanged<EditField> onTap;
  final VoidCallback onToggleCleared;
  final List<AccountInfo> categories;
  final ValueChanged<AccountInfo> onSetCategory;
  final ValueNotifier<Cleared?> hoveredStatus;

  @override
  Widget build(BuildContext context) {
    final r = row;
    final memo = r.kind == RowKind.split && r.memo.isEmpty
        ? r.splitLines
              .map((l) => '${l.name} ₮${formatWhole(l.amount)}')
              .join(' · ')
        : r.memo;
    final statusTip = switch (r.cleared) {
      Cleared.uncleared => 'Uncleared — not settled at the bank yet, even if it shows there as pending. Click once it clears.',
      Cleared.cleared =>
        'Cleared — settled at the bank. Click to mark uncleared.',
      Cleared.reconciled => 'Reconciled — matched to a statement and locked.',
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
            height: 52,
            padding: Cols.inset,
            decoration: BoxDecoration(
              color: selected
                  ? Mid.blueWash
                  : (hover ? Mid.hover : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? Mid.blueEdge : Colors.transparent,
              ),
            ),
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
                      if (memo.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        GestureDetector(
                          onTap: () => onTap(EditField.memo),
                          child: Text(
                            memo,
                            style: onest(12.5, color: Mid.ink3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10),
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
                    child: Money(
                      r.balance,
                      color: r.balance < 0
                          ? Mid.coral
                          : (r.cleared == Cleared.uncleared
                                ? Mid.ink2
                                : Mid.ink),
                    ),
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

class _ScheduledRow extends StatelessWidget {
  const _ScheduledRow({
    required this.row,
    required this.onConfirm,
    required this.extra,
    required this.selected,
    required this.onTap,
    this.onMore,
  });

  final RegisterRow row;
  final VoidCallback onConfirm;
  final String? extra;
  final VoidCallback? onMore;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = row;
    final label = r.kind == RowKind.transfer
        ? '${r.amount < 0 ? 'To' : 'From'} ${r.payee}'
        : r.payee;
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
            height: 46,
            padding: Cols.inset,
            decoration: BoxDecoration(
              color: selected ? Mid.blueWash : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: Cols.status,
                  child: Tooltip(
                    message: 'Scheduled — not in any balance until confirmed',
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
                      if (extra != null) ...[
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

/// A category list that opens in place. No modal.
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
        for (final c in categories)
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
