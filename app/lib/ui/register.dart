import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../domain/budget.dart' show BillFit, BillPayment, categoryTakes;
import '../domain/ledger.dart';
import '../domain/money.dart';
import '../domain/sync.dart' show MadeHow;
import 'data_words.dart';
import 'entry_row.dart';
import 'language.dart';
import 'theme.dart';

enum RegisterFilter {
  all,
  uncleared,
  cleared,
  reconciled,
  scheduled,

  /// Rows waiting in "Not categorized".
  uncategorized,
}

/// Column layout shared by the header, entry row and every register row.
abstract final class Cols {
  static const status = 24.0;
  static const date = 114.0;
  // Kept to what they hold, so the payee has room in the smallest window.
  static const category = 190.0;
  static const amount = 156.0;
  static const balance = 156.0;
  static const gap = 16.0;

  /// The Source column, when it is turned on (Settings): see [SourceColumn].
  static const source = 128.0;
  static const inset = EdgeInsets.symmetric(horizontal: 20);
  static const outer = EdgeInsets.symmetric(horizontal: 12);
}

/// Whether the register shows where each transaction came from, and the
/// names the person gave their phones. Set above the register so the
/// header, the rows and the entry row all follow it.
class SourceColumn extends InheritedWidget {
  const SourceColumn({
    super.key,
    required this.shown,
    this.here,
    this.machines = const {},
    this.computers = const {},
    this.phones = const {},
    required super.child,
  });

  final bool shown;

  /// This computer's id: a row made on it says "here".
  final String? here;

  /// The Mac each computer is on, by id: a row made under another account
  /// of the same Mac says "here" too.
  final Map<String, String> machines;

  bool _isHere(String on) =>
      on == here ||
      (here != null && machines[on] != null && machines[on] == machines[here]);

  /// The computers that made a row, by id, and the name given each ('' for
  /// none), and the same for the phones.
  final Map<String, String> computers;
  final Map<String, String> phones;

  static SourceColumn? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SourceColumn>();

  /// True when a column is to be drawn.
  static bool showing(BuildContext context) => maybeOf(context)?.shown ?? false;

  /// The row's source in words, or an empty string when it isn't known.
  String words(Words t, RegisterRow r) {
    final on = r.madeOn;
    return switch (r.madeHow) {
      MadeHow.typed =>
        on == null
            ? t.sourceTyped
            : _isHere(on)
            ? t.sourceTypedHere
            : _named(computers[on])?.let(t.sourceTypedOn) ??
                  t.sourceTypedElsewhere,
      MadeHow.imported =>
        on == null
            ? t.sourceImported
            : _isHere(on)
            ? t.sourceImportedHere
            : _named(computers[on])?.let(t.sourceImportedOn) ??
                  t.sourceImportedElsewhere,
      MadeHow.phone => _phone(t, on),
      MadeHow.scheduled => t.sourceScheduled,
      // The payee already says it ("Opening balance"), and a blank is not
      // a gap: nothing is said twice.
      _ => '',
    };
  }

  static String? _named(String? name) =>
      name == null || name.trim().isEmpty ? null : name.trim();

  /// A phone by the name it was given, else "your phone" while it is the
  /// only one, else its first four characters.
  String _phone(Words t, String? id) {
    final named = _named(phones[id]);
    if (named != null) return t.sourcePhone(named);
    if (id == null || phones.length <= 1) return t.sourceYourPhone;
    return t.sourcePhoneId(id.length > 4 ? id.substring(0, 4) : id);
  }

  @override
  bool updateShouldNotify(SourceColumn old) =>
      shown != old.shown ||
      here != old.here ||
      !mapEquals(machines, old.machines) ||
      !mapEquals(phones, old.phones) ||
      !mapEquals(computers, old.computers);
}

extension on String {
  T let<T>(T Function(String) f) => f(this);
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
    this.pays = const [],
    this.onSetPay,
    this.onBillPaid,
    this.onNotIt,
    this.onNotThisBill,
    this.onNoBill,
    this.onPoint,
    this.onShowRow,
  });

  /// The "Looks paid" line was clicked while its bill is being confirmed:
  /// bring the row it names into sight.
  final ValueChanged<RegisterRow>? onPoint;

  /// The "Looks paid" line was clicked on a bill not open: go to the row
  /// it names, in its own account.
  final ValueChanged<RegisterRow>? onShowRow;

  /// Yes to "Paid on 10.13?": [payment]'s row paid its bill (ADR 0004,
  /// "A bill paid another way"); a row that isn't near the bill is asked
  /// about first.
  final ValueChanged<BillPayment>? onBillPaid;

  /// No to "Paid on 10.13?": the row is something else, and the bill stays.
  final void Function(RegisterRow bill, RegisterRow found)? onNotIt;

  /// "Not this bill" on a row that was taken as a bill paid: the bill
  /// comes back to pay.
  final ValueChanged<RegisterRow>? onNotThisBill;

  /// "No bill this time" on a category's scheduled bill: it won't come.
  final ValueChanged<RegisterRow>? onNoBill;

  /// Each pay set up, by the name the dropdown says it under ("Income ·
  /// Loveland Solutions"), and the account it's paid into. Picking one on
  /// a row of money in makes the row that pay's paycheck.
  final List<({int id, int accountId, String label})> pays;
  final void Function(RegisterRow row, int payId)? onSetPay;

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

/// The dropdown's categories in the order that suits [r] (owner,
/// 2026-10-06): for money in, Income first; for money out, the spending
/// categories first. Only those in the row's currency (owner, 2026-10-06:
/// dollar categories don't belong in a tugrik account's list), and the one
/// the row is filed under now, so its tick still shows.
List<AccountInfo> categoriesFor(RegisterRow r, List<AccountInfo> all) {
  final offered = all.where(
    (c) => c.id == r.categoryId || categoryTakes(c, r.currency),
  );
  final income = offered.where((c) => c.isIncome);
  final spending = offered.where((c) => !c.isIncome);
  return r.amount > 0 ? [...income, ...spending] : [...spending, ...income];
}

/// The pays [r] could be a paycheck of: money in, into the pay's account.
List<({int id, int accountId, String label})> paysFor(
  RegisterRow r,
  RegisterActions actions,
) => r.amount > 0 && actions.onSetPay != null
    ? [
        for (final p in actions.pays)
          if (p.accountId == r.accountId) p,
      ]
    : const [];

/// What a row's category chip says: its pay's name when it's a paycheck.
String categoryShown(RegisterRow r, RegisterActions actions) =>
    actions.pays.where((p) => p.id == r.payScheduleId).firstOrNull?.label ??
    r.categoryLabel;

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
    this.everyPosted,
    required this.scheduled,
    required this.filter,
    required this.search,
    required this.selected,
    this.selectedKey,
    required this.hoveredStatus,
    required this.categories,
    required this.transferTargets,
    this.currency = Currency.mnt,
    this.allAccounts,
    required this.unclearedCheck,
    this.pointed,
    this.pointedKey,
    required this.entryController,
    required this.today,
    required this.actions,
    this.editing,
    this.adding = false,
    this.shown,
    this.onCloseEntry,
    this.addButton,
    this.searchBox,
    this.reconcileThrough,
    this.owed = false,
    this.accountName,
    this.uncategorizedId,
    this.uncategorizedFrom,
    this.uncategorizedTo,
    this.looksPaid = const {},
    this.notItFor = _noNotIt,
    this.paysBill = _paysNoBill,
    this.accountNamed,
  });

  static bool _paysNoBill(int _) => false;

  /// A row taken as a bill paid ([billPaidKey]): its bar has Not this bill.
  final bool Function(int txnId) paysBill;

  static Set<int> _noNotIt(int _) => const {};

  /// The rows said not to have paid a bill ([billNotIt]).
  final Set<int> Function(int billTxnId) notItFor;

  /// Each scheduled bill a row already in may have paid, by the bill's
  /// transaction (`billPayments`): the bill's row asks.
  final Map<int, BillPayment> looksPaid;

  /// Any account's name, for a bill paid from another account.
  final String? Function(int accountId)? accountNamed;

  /// The "Not categorized" category, if the ledger has one: its rows get a
  /// tab of their own while there are any (owner, 2026-10-06: they're said
  /// here, where they're fixed, not on the Budget page).
  final int? uncategorizedId;

  /// The budget period today is in: the tab holds the rows waiting within
  /// it (owner, 2026-10-06). Older ones change nothing the budget shows.
  final DateTime? uncategorizedFrom, uncategorizedTo;

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

  /// The search box: in the tab row, beside what it narrows (owner,
  /// 2026-09-30), not at the top of the page.
  final Widget? searchBox;

  /// The new-transaction row is open (from Add or ⌘N).
  final bool adding;

  /// Filled with the rows drawn, so the screen's keys act only on a row
  /// that's on screen (a tab or search hides the others).
  final Set<int>? shown;
  final VoidCallback? onCloseEntry;

  final RegisterEditing? editing;
  final List<RegisterRow> posted;

  /// Every account's rows, unfiltered, for the row already in that a bill
  /// being confirmed would put in twice: it may be in another account, or
  /// out of the filter shown (#141). Asked only while confirming.
  final Iterable<RegisterRow> Function()? everyPosted;
  final List<RegisterRow> scheduled;
  final RegisterFilter filter;
  final String search;
  final int? selected;

  /// Put on the selected row so the screen can scroll it into view.
  final Key? selectedKey;
  final ValueNotifier<Cleared?> hoveredStatus;
  final List<AccountInfo> categories;
  final List<AccountInfo> transferTargets;

  /// The register's account's currency, for the row that adds.
  final Currency currency;

  /// All accounts: each row's account by id. The last column names it, in
  /// place of a running balance that would mix accounts, and the entry row
  /// asks which account a new row goes in.
  final Map<int, AccountInfo>? allAccounts;

  /// What an account's uncleared rows are held against, for the note an
  /// old one gets (`LedgerData.unclearedCheck`).
  final UnclearedCheck? Function(int accountId) unclearedCheck;

  /// The row the "Already in this account" line led to, outlined, with
  /// [pointedKey] on it so the screen can scroll it into view.
  final int? pointed;
  final Key? pointedKey;
  final EntryRowController entryController;
  final DateTime today;
  final RegisterActions actions;

  /// Matches what the row shows, in the language shown.
  bool _matches(Words t, RegisterRow r) {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return true;
    // The sign a row shows is typed as often as not: "-30000" finds it.
    final digits = q
        .replaceAll(RegExp(r'[,\s₮$]'), '')
        .replaceFirst(RegExp(r'^[-−+]'), '');
    return rowPayee(t, r).toLowerCase().contains(q) ||
        r.memo.toLowerCase().contains(q) ||
        (_accountOf(r)?.toLowerCase().contains(q) ?? false) ||
        rowCategory(t, r).toLowerCase().contains(q) ||
        // A split by any of its lines' categories.
        r.splitLines.any(
          (l) => splitLineName(t, l).toLowerCase().contains(q),
        ) ||
        (digits.isNotEmpty &&
            RegExp(r'^\d+$').hasMatch(digits) &&
            formatWhole(
              r.amount,
              r.currency,
            ).replaceAll(',', '').contains(digits));
  }

  String? _accountOf(RegisterRow r) => allAccounts?[r.accountId]?.name;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final uncleared = posted
        .where((r) => r.cleared == Cleared.uncleared)
        .length;
    bool waiting(RegisterRow r) =>
        uncategorizedId != null &&
        r.categoryId == uncategorizedId &&
        !(uncategorizedFrom?.isAfter(r.date) ?? false) &&
        !(uncategorizedTo?.isBefore(r.date) ?? false);
    final uncategorized = posted.where(waiting).length;
    // The last one categorized: the tab goes, and so does its filter.
    final filter =
        this.filter == RegisterFilter.uncategorized && uncategorized == 0
        ? RegisterFilter.all
        : this.filter;
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
              ? (status == null || r.cleared == status) &&
                    (filter != RegisterFilter.uncategorized || waiting(r))
              : r.cleared != Cleared.reconciled && !r.date.isAfter(through),
        )
        .where((r) => _matches(t, r))
        .toList();
    final visibleScheduled = scheduled.where((r) => _matches(t, r)).toList();
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
            paysBill: paysBill(r.txnId),
          )
        : null;

    // A bill that a row already in looks to have paid: confirming it
    // would put it in twice, so its row says so, open or not.
    BillPayment? paidBy(RegisterRow r) {
      final e = editing;
      if (actions.onBillPaid == null || through != null) return null;
      if (e != null && e.txnId == r.txnId && !e.confirming) return null;
      if (looksPaid[r.txnId] case final p?) return p;
      // Confirming anything else (a transfer, money in): a row already in
      // here would still be put in twice.
      if (e == null || e.txnId != r.txnId) return null;
      final found = alreadyIn(
        r,
        everyPosted?.call() ?? posted,
        today,
        uncategorizedId: uncategorizedId,
        notIt: notItFor(r.txnId),
      );
      if (found == null) return null;
      return (bill: r, row: found, fit: BillFit.paid, bills: 1);
    }

    // Drawn in this register: the same account, or All accounts.
    bool here(RegisterRow found, RegisterRow bill) =>
        allAccounts != null || found.accountId == bill.accountId;

    Widget? paidLine(RegisterRow r, {required bool open}) {
      final p = paidBy(r);
      if (p == null) return null;
      final found = p.row;
      return _PaidAskLine(
        key: ValueKey('looks-paid-${r.txnId}-${found.txnId}'),
        found: found,
        account: found.accountId == r.accountId
            ? null
            : accountNamed?.call(found.accountId),
        // In the Scheduled tab the row is drawn right under this one.
        onShow: showScheduled && here(found, r)
            ? null
            : open && here(found, r)
            ? (actions.onPoint == null ? null : () => actions.onPoint!(found))
            : (actions.onShowRow == null
                  ? null
                  : () => actions.onShowRow!(found)),
        onYes: () => actions.onBillPaid!(p),
        onNo: actions.onNotIt == null ? null : () => actions.onNotIt!(r, found),
      );
    }

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
        currency: r.currency,
        initial: EditInitial.fromRow(
          r,
          focus: e.focus,
          confirmingOn: e.confirming ? today : null,
        ),
        notice: paidLine(r, open: true),
        onCancel: actions.onCancelEdit,
      );
    }

    // A row opening into the editor (or its action bar) grows smoothly, and
    // shrinks back when it closes. Keyed by transaction so the animation
    // follows the row, not its place in the list.
    final grow = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    Widget sized(RegisterRow r, Widget row) => SmoothHeight(
      key: ValueKey('row-${r.txnId}'),
      duration: grow,
      child: r.txnId == selected && selectedKey != null
          ? KeyedSubtree(key: selectedKey, child: row)
          : r.txnId == pointed && pointedKey != null
          ? KeyedSubtree(key: pointedKey, child: row)
          : row,
    );
    shown?.clear();
    Widget keyed(RegisterRow r, Widget row) {
      shown?.add(r.txnId);
      return sized(r, row);
    }

    Widget postedRow(int i, RegisterRow r, {bool? isPointed}) => _PostedRow(
      row: r,
      today: today,
      check: unclearedCheck(r.accountId),
      owed: owed,
      accountName: _accountOf(r),
      striped: i.isOdd,
      pointed: isPointed ?? r.txnId == pointed,
      reconciling: through != null,
      bar: bar(r),
      onTap: (field) => tap(r.txnId, field),
      onToggleCleared: () => actions.onToggleCleared(r),
      categories: categoriesFor(r, categories),
      onSetCategory: (c) => actions.onSetCategory(r, c),
      pays: paysFor(r, actions),
      onSetPay: (id) => actions.onSetPay?.call(r, id),
      categoryShown: categoryShown(r, actions),
      hoveredStatus: hoveredStatus,
    );

    final children = <Widget>[];
    if (showScheduled) {
      if (visibleScheduled.isEmpty) {
        children.add(_empty(t.rowsNothingScheduled));
      }
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
                  paid: paidLine(r, open: false),
                  bar: bar(r),
                  onTap: () => tap(r.txnId),
                ),
          ),
        );
        // This tab lists no rows already in, so the one the line names is
        // drawn under it.
        if (paidBy(r)?.row case final found? when here(found, r)) {
          children.add(
            KeyedSubtree(
              key: const ValueKey('already-in-row'),
              child: postedRow(0, found, isPointed: true),
            ),
          );
        }
      }
    } else {
      if (showNext) {
        final next = visibleScheduled.first;
        // Bills that look paid show here too, not only the first: their
        // line is the one thing left to do with them.
        final paidToo = [
          for (final r in visibleScheduled.skip(1))
            if (paidBy(r) != null) r,
        ];
        // Only the first shows here, so a second late bill would go unsaid.
        final late = visibleScheduled
            .where((r) => overdueDays(r, today) != null)
            .length;
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
                            ? t.rowsNextOfScheduled(visibleScheduled.length)
                            : t.rowsScheduledOnly),
                  accountName: _accountOf(next),
                  overdueMore: late > 1 ? t.rowsMoreOverdue(late - 1) : null,
                  onMore: () => actions.onFilter(RegisterFilter.scheduled),
                  paid: paidLine(next, open: false),
                  bar: bar(next),
                  onTap: () => tap(next.txnId),
                ),
          ),
        );
        for (final r in paidToo) {
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
                    paid: paidLine(r, open: false),
                    bar: bar(r),
                    onTap: () => tap(r.txnId),
                  ),
            ),
          );
        }
      }
      if (visiblePosted.isEmpty) {
        children.add(
          _empty(
            search.isEmpty
                ? t.rowsNoTransactions
                : t.rowsNothingMatches(search),
          ),
        );
      }
      for (final (i, r) in visiblePosted.indexed) {
        children.add(keyed(r, editor(r) ?? postedRow(i, r)));
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
                            t.rowsNotReconciledThrough(sayFullDate(t, through)),
                            style: onest(13, color: Mid.ink2),
                          )
                        : _Tabs(
                            filter: filter,
                            uncleared: uncleared,
                            scheduled: scheduled.length,
                            uncategorized: uncategorized,
                            onFilter: actions.onFilter,
                          ),
                  ),
                  if (searchBox case final box?) ...[
                    box,
                    const SizedBox(width: 10),
                  ],
                  ?addButton,
                ],
              ),
            ),
          ),
          _HeaderRow(
            balance: allAccounts != null
                ? t.rowsColumnAccount
                : through != null
                ? t.rowsColumnClearedBalance
                : (owed ? t.rowsColumnOwed : t.rowsColumnBalance),
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
                    currency: currency,
                    accountChoices: allAccounts == null
                        ? null
                        : transferTargets,
                    pays: actions.onSetPay == null ? const [] : actions.pays,
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
    required this.uncategorized,
    required this.onFilter,
  });

  final RegisterFilter filter;
  final int uncleared;
  final int scheduled;
  final int uncategorized;
  final ValueChanged<RegisterFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final statusTab = switch (filter) {
      RegisterFilter.cleared => Cleared.cleared,
      RegisterFilter.reconciled => Cleared.reconciled,
      _ => null,
    };
    final t = context.t;
    return Row(
      children: [
        _Tab(
          t.rowsTabAll,
          null,
          filter == RegisterFilter.all,
          () => onFilter(RegisterFilter.all),
        ),
        _Tab(
          t.rowsTabUncleared,
          uncleared,
          filter == RegisterFilter.uncleared,
          () => onFilter(RegisterFilter.uncleared),
        ),
        _Tab(
          t.rowsTabScheduled,
          scheduled,
          filter == RegisterFilter.scheduled,
          () => onFilter(RegisterFilter.scheduled),
        ),
        // Only while rows wait there: nothing to say otherwise.
        if (uncategorized > 0)
          _Tab(
            key: const ValueKey('tab-uncategorized'),
            t.rowsTabUncategorized,
            uncategorized,
            filter == RegisterFilter.uncategorized,
            () => onFilter(RegisterFilter.uncategorized),
          ),
        // Cleared and reconciled are reached from the header's key; show the
        // tab only while it's the active filter, with a way back out.
        if (statusTab != null)
          _Tab(
            clearedName(t, statusTab),
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
    super.key,
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
          // The tab you're on is tinted like the row you've chosen.
          color: active
              ? Mid.blueWash
              : (hover ? Mid.hover : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              // Color only: a heavier word would nudge the tabs beside it.
              style: onest(13, color: active ? Mid.blue : Mid.ink3),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 4),
              Text(
                '($count)',
                style: onest(11.5, color: Mid.ink3, tabular: true),
              ),
            ],
            if (closable) ...[
              const SizedBox(width: 6),
              Icon(Icons.close_rounded, size: 13, color: Mid.ink2),
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
    this.paysBill = false,
  });

  /// Taken as a bill paid: it may not have been.
  final bool paysBill;

  final RegisterRow row;
  final List<AccountInfo> categories;

  /// The other accounts, for Move to.
  final List<AccountInfo> accounts;
  final RegisterActions actions;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final r = row;
    final locked = r.cleared == Cleared.reconciled;
    final edit = BarButton(
      label: t.rowsEdit,
      leading: Icon(Icons.edit_rounded, size: 13, color: Mid.ink3),
      onTap: () => actions.onEdit(r),
    );
    final categorize = r.kind == RowKind.simple
        ? CategoryMenu(
            categories: categoriesFor(r, categories),
            onPicked: (c) => actions.onSetCategory(r, c),
            leading: [
              for (final p in paysFor(r, actions))
                (label: p.label, onTap: () => actions.onSetPay!(r, p.id)),
            ],
            current: categoryShown(r, actions),
            builder: (open, toggle) => BarButton(
              label: t.rowsCategorize,
              trailing: Icons.keyboard_arrow_down_rounded,
              active: open,
              onTap: toggle,
            ),
          )
        : null;
    final clearButton = r.cleared == Cleared.uncleared
        ? BarButton(
            label: t.rowsMarkCleared,
            leading: const StatusGlyph(Cleared.cleared),
            onTap: () => actions.onToggleCleared(r),
          )
        : BarButton(
            label: t.rowsMarkUncleared,
            leading: const StatusGlyph(Cleared.uncleared),
            onTap: () => actions.onToggleCleared(r),
          );
    // A transfer can't move onto its own other side; an opening balance
    // belongs to its account.
    // In All accounts the list has every account, its own included.
    // Only accounts in the same currency: the amount means something else
    // in another one, and a transfer between currencies stays where it is.
    final targets = r.otherAmount != null
        ? const <AccountInfo>[]
        : accounts
              .where(
                (a) =>
                    a.id != r.accountId &&
                    a.currency == r.currency &&
                    !(r.kind == RowKind.transfer && a.name == r.payee),
              )
              .toList();
    final move = r.kind != RowKind.opening && targets.isNotEmpty
        ? CategoryMenu(
            categories: targets,
            onPicked: (a) => actions.onMove(r, a),
            builder: (open, toggle) => BarButton(
              key: const ValueKey('move-to'),
              label: t.rowsMoveTo,
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
                  // What can still change, not only what can't.
                  switch (r.reconciledOn) {
                    null => t.rowsReconciledLocked,
                    final on when r.kind == RowKind.transfer =>
                      t.rowsReconciledOnCanChangeTransfer(sayDate(t, on)),
                    final on => t.rowsReconciledOnCanChange(sayDate(t, on)),
                  },
                  style: onest(13, color: Mid.ink3),
                ),
              ),
              // Only the newest reconcile comes undone, so they unwind in
              // order and every older lock still matches its statement.
              if (r.latestReconcile)
                BarButton(
                  key: const ValueKey('unreconcile'),
                  label: t.rowsUndoThisReconcile,
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
                  t.rowsReconciledInLocked(r.lockedIn!),
                  style: onest(13, color: Mid.ink3),
                ),
              ),
            ] else ...[
              edit,
              ?categorize,
              if (!r.scheduled) clearButton,
              ?move,
              // Taken as a category's bill paid: it may not have been.
              if (!r.scheduled && paysBill && actions.onNotThisBill != null)
                BarButton(
                  key: const ValueKey('not-this-bill'),
                  label: t.rowsNotThisBill,
                  onTap: () => actions.onNotThisBill!(r),
                ),
              // A category's bill: deleting it was always skipping it, so
              // the button says so, and its money stays for the next.
              if (r.scheduled &&
                  r.planCategoryId != null &&
                  actions.onNoBill != null)
                BarButton(
                  key: const ValueKey('no-bill'),
                  label: t.rowsNoBillThisTime,
                  onTap: () => actions.onNoBill!(r),
                )
              else
                BarButton(
                  label: t.rowsDelete,
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
    this.color,
    this.active = false,
  });

  final String label;
  final VoidCallback onTap;
  final Widget? leading;
  final IconData? trailing;
  final Color? color;
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
            color: (color ?? Mid.ink2).withValues(
              alpha: hover || active ? 0.6 : 0.3,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 6)],
            // A name chosen in it (an account's) can be any length.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: onest(
                  13,
                  color: hover || active
                      ? (color ?? Mid.ink)
                      : (color ?? Mid.ink2),
                ),
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
    final t = context.t;
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
              child: Text(t.rowsColumnDate, style: s),
            ),
            const SizedBox(width: Cols.gap),
            Expanded(child: Text(t.rowsColumnPayee, style: s)),
            const SizedBox(width: Cols.gap),
            SizedBox(
              width: Cols.category,
              child: Text(t.rowsColumnCategory, style: s),
            ),
            const SizedBox(width: Cols.gap),
            if (SourceColumn.showing(context)) ...[
              SizedBox(
                width: Cols.source,
                child: Text(t.rowsColumnSource, style: s),
              ),
              const SizedBox(width: Cols.gap),
            ],
            SizedBox(
              width: Cols.amount,
              child: Text(
                t.rowsColumnAmount,
                style: s,
                textAlign: TextAlign.right,
              ),
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
    required this.check,
    required this.owed,
    this.accountName,
    required this.striped,
    this.pointed = false,
    required this.reconciling,
    required this.bar,
    required this.onTap,
    required this.onToggleCleared,
    required this.categories,
    required this.onSetCategory,
    this.pays = const [],
    this.onSetPay,
    this.categoryShown,
    required this.hoveredStatus,
  });

  /// The pays this row could be a paycheck of, first in the dropdown.
  final List<({int id, int accountId, String label})> pays;
  final ValueChanged<int>? onSetPay;

  /// The chip's words when they aren't the category's own (a paycheck).
  final String? categoryShown;

  final RegisterRow row;
  final DateTime today;

  /// The row a line elsewhere names: outlined so it's found at a glance.
  final bool pointed;

  /// What this row's account holds an uncleared row against.
  final UnclearedCheck? check;
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
  Widget build(BuildContext context) => CurrencyScope(
    currency: row.currency,
    child: Builder(builder: _build),
  );

  Widget _build(BuildContext context) {
    final t = context.t;
    final selected = bar != null;
    final r = row;
    final rate = r.otherAmount == null
        ? null
        : exchangeRate(r.amount, r.currency, r.otherAmount, r.otherCurrency!);
    // A split's breakdown, then its memo: "Groceries ₮98,000 · Clothing
    // ₮37,500 · birthday". Each share as money shows elsewhere, unrounded.
    final memo = r.kind == RowKind.split
        ? [
            for (final l in r.splitLines)
              // A line the other way from the row (a return on the same
              // receipt) carries its sign, as an amount does.
              '${splitLineName(t, l)} ${(l.amount > 0) != (r.amount > 0) ? (l.amount > 0 ? '+' : '−') : ''}${formatShort(l.amount.abs(), currency: r.currency)}',
            if (r.memo.isNotEmpty) r.memo,
          ].join(' · ')
        : r.otherAmount != null
        ? [
            if (r.memo.isNotEmpty) r.memo,
            t.rowsExchangeNote(
              rowPayee(t, r),
              formatMoney(r.otherAmount!.abs(), currency: r.otherCurrency!),
              rate == null ? '' : formatMoney(rate.rate, currency: rate.quote),
              rate == null
                  ? ''
                  : formatRounded(rate.base.scale, currency: rate.base),
            ),
          ].join(' · ')
        : r.memo;
    final stale = unclearedNoteIn(t, r, today, check);
    final statusTip = r.clearedIn == null
        ? t.rowsStatusTip(r.cleared.name)
        : t.rowsStatusTipIn(r.clearedIn!, r.cleared.name);
    final (toBefore, toAfter) = r.amount < 0
        ? (t.rowsTransferToBefore, t.rowsTransferToAfter)
        : (t.rowsTransferFromBefore, t.rowsTransferFromAfter);

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
          focusable: false,
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
                color: selected || pointed ? Mid.blueEdge : Colors.transparent,
              ),
            ),
            child: Column(
              children: [
                // The row's line is chosen with ↑ ↓; only its bar takes Tab.
                ExcludeFocus(
                  child: SizedBox(
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
                                  // The direction word goes before or after
                                  // the account's name, as the language has it.
                                  if (r.kind == RowKind.transfer &&
                                      toBefore.isNotEmpty) ...[
                                    Text(
                                      toBefore,
                                      style: onest(14.5, color: Mid.ink3),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Flexible(
                                    child: Text(
                                      rowPayee(t, r),
                                      style: onest(14.5, weight: 500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (r.kind == RowKind.transfer &&
                                      toAfter.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        toAfter,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: onest(14.5, color: Mid.ink3),
                                      ),
                                    ),
                                  ],
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
                                          // Cut with "…" in the row, a split's
                                          // shares too: the row opens to them
                                          // whole.
                                          child: Text(
                                            memo,
                                            key: const ValueKey('row-memo'),
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
                                    current: categoryShown ?? r.categoryLabel,
                                    onPicked: onSetCategory,
                                    leading: [
                                      for (final p in pays)
                                        (
                                          label: p.label,
                                          onTap: () => onSetPay?.call(p.id),
                                        ),
                                    ],
                                    builder: (open, toggle) => CategoryChip(
                                      label: categoryShown ?? r.categoryLabel,
                                      open: open,
                                      onTap: toggle,
                                    ),
                                  )
                                : Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Text(
                                      rowCategory(t, r),
                                      style: onest(12.5, color: Mid.ink3),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: Cols.gap),
                        if (SourceColumn.showing(context)) ...[
                          _SourceCell(r),
                          const SizedBox(width: Cols.gap),
                        ],
                        _Cell(
                          width: Cols.amount,
                          onTap: () => onTap(EditField.amount),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _Amount(r.amount, lit: hover || selected),
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
                                        centsColor: hover || selected
                                            ? Mid.ink2
                                            : null,
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

/// Under a scheduled row being confirmed: the row already in that looks
/// to be the same bill, as its own row reads, and the way out that doesn't
/// put it in twice.
/// Under a scheduled bill: the row already in that may have paid it,
/// asked (ADR 0004, "A bill paid another way"). The person answers.
class _PaidAskLine extends StatelessWidget {
  const _PaidAskLine({
    super.key,
    required this.found,
    required this.account,
    required this.onShow,
    required this.onYes,
    required this.onNo,
  });
  final RegisterRow found;

  /// The account [found] is in, when it isn't the bill's.
  final String? account;

  /// Brings that row into sight; null where it is already beside this line.
  final VoidCallback? onShow;
  final VoidCallback onYes;
  final VoidCallback? onNo;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final amount = formatMoney(found.amount, currency: found.currency);
    final text = account == null
        ? t.rowsPaidOnAsk(sayDate(t, found.date), rowPayee(t, found), amount)
        : t.rowsPaidOnAskFrom(
            sayDate(t, found.date),
            rowPayee(t, found),
            amount,
            account!,
          );
    Widget button(String label, Key key, VoidCallback? onTap, Color color) =>
        Hoverable(
          onTap: onTap,
          builder: (h) => Container(
            key: key,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: h ? Mid.blueWash : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label, style: onest(13, weight: 500, color: color)),
          ),
        );
    return Padding(
      key: const ValueKey('looks-paid'),
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Hoverable(
              onTap: onShow,
              builder: (h) => Text(
                text,
                key: const ValueKey('looks-paid-text'),
                style: onest(13, weight: 600, color: Mid.ink, tabular: true)
                    .copyWith(
                      decoration: onShow != null && h
                          ? TextDecoration.underline
                          : null,
                      decorationColor: Mid.ink,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          ),
          const SizedBox(width: 10),
          button(
            t.rowsPaidYes,
            const ValueKey('looks-paid-yes'),
            onYes,
            Mid.blue,
          ),
          if (onNo != null)
            button(
              t.rowsPaidNo,
              const ValueKey('looks-paid-no'),
              onNo,
              Mid.ink2,
            ),
        ],
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
    this.overdueMore,
    this.paid,
  });

  /// "Looks paid · …": a row already in that looks to have paid this bill.
  final Widget? paid;

  /// "2 more overdue", when this late row is not the only late one; it opens the
  /// Scheduled tab, as [extra] does.
  final String? overdueMore;

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
  Widget build(BuildContext context) => CurrencyScope(
    currency: row.currency,
    child: Builder(builder: _build),
  );

  Widget _build(BuildContext context) {
    final t = context.t;
    final selected = bar != null;
    final r = row;
    final label = r.kind == RowKind.transfer
        ? (r.amount < 0
              ? t.rowsScheduledTransferTo(rowPayee(t, r))
              : t.rowsScheduledTransferFrom(rowPayee(t, r)))
        : rowPayee(t, r);
    final overdue = overdueNoteIn(t, r, today);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Hoverable(
        onTap: onTap,
        focusable: false,
        builder: (hover) => CustomPaint(
          painter: _DashedBorder(
            color: selected
                ? Mid.blueEdge
                // "Not real yet", in gray: gold is for what is done (owner,
                // 2026-10-09). Stronger on white, where a faint dash vanishes.
                : Mid.ink3.withValues(alpha: (hover ? 0.75 : 0.55)),
          ),
          child: Container(
            padding: Cols.inset,
            decoration: BoxDecoration(
              color: selected ? Mid.blueWash : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                // The row's line is chosen with ↑ ↓; only its bar takes Tab.
                ExcludeFocus(
                  child: SizedBox(
                    height: 46,
                    child: Row(
                      children: [
                        SizedBox(
                          width: Cols.status,
                          child: Tooltip(
                            message: t.rowsScheduledTip,
                            child: Icon(
                              Icons.event_repeat_rounded,
                              size: 14,
                              color: Mid.ink3,
                            ),
                          ),
                        ),
                        const SizedBox(width: Cols.gap),
                        SizedBox(
                          width: Cols.date,
                          child: Text(
                            fullDate(r.date),
                            style: onest(13, color: Mid.ink2, tabular: true),
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
                                Flexible(
                                  child: Text(
                                    '· $overdue',
                                    key: const ValueKey('overdue-note'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    // Full ink and heavier: late is the one thing on this
                                    // row to notice, now that it isn't gold.
                                    style: onest(
                                      14,
                                      weight: 600,
                                      color: Mid.ink,
                                    ),
                                  ),
                                ),
                              ],
                              if (overdue != null && overdueMore != null) ...[
                                const SizedBox(width: 8),
                                Hoverable(
                                  onTap: onMore,
                                  builder: (h) => Text(
                                    '· $overdueMore',
                                    key: const ValueKey('overdue-count'),
                                    style:
                                        onest(
                                          14,
                                          weight: 600,
                                          color: Mid.ink,
                                        ).copyWith(
                                          decoration: onMore != null && h
                                              ? TextDecoration.underline
                                              : null,
                                          decorationColor: Mid.ink,
                                        ),
                                  ),
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
                                Flexible(
                                  child: Hoverable(
                                    onTap: onMore,
                                    builder: (h) => Text(
                                      '· $extra',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: onest(14, color: Mid.ink3)
                                          .copyWith(
                                            decoration: onMore != null && h
                                                ? TextDecoration.underline
                                                : null,
                                            decorationColor: Mid.ink3,
                                          ),
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
                              rowCategory(t, r),
                              style: onest(12.5, color: Mid.ink3),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: Cols.gap),
                        if (SourceColumn.showing(context)) ...[
                          _SourceCell(r),
                          const SizedBox(width: Cols.gap),
                        ],
                        SizedBox(
                          width: Cols.amount,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _Amount(r.amount, lit: hover || selected),
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
                                  color: h ? Mid.blueWash : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  t.rowsConfirm,
                                  style: onest(
                                    13,
                                    weight: 500,
                                    color: Mid.blue,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ?paid,
                ?bar,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One row's source, kept to a line (the whole words are the tooltip).
class _SourceCell extends StatelessWidget {
  const _SourceCell(this.row);
  final RegisterRow row;

  @override
  Widget build(BuildContext context) {
    final words = SourceColumn.maybeOf(context)?.words(context.t, row) ?? '';
    return SizedBox(
      width: Cols.source,
      // Two lines, so a name isn't cut: the column is narrow, the row tall.
      child: Text(
        words,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: onest(12.5, color: Mid.ink3),
      ),
    );
  }
}

/// A row's amount, told apart at a glance (owner, 2026-10-06: "it's hard
/// to tell if the values are negative or positive"): money out has a minus
/// in front, money in is green with a plus. Money out is in ordinary ink, not
/// red (owner, 2026-10-09): red is for a shortfall, and spending isn't one.
class _Amount extends StatelessWidget {
  const _Amount(this.minor, {this.lit = false});
  final int minor;

  /// Under the pointer or chosen: the cents a step darker, so they still
  /// read on the row's tint (#148).
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final cents = lit ? Mid.ink2 : null;
    if (minor == 0) {
      return Money(minor, sign: MoneySign.none, centsColor: cents);
    }
    if (minor < 0) {
      return Money(
        minor,
        color: Mid.ink,
        centsColor: cents,
        sign: MoneySign.plusForPositive,
      );
    }
    return Money(
      minor,
      color: Mid.green,
      // Quieter at night, without fading into a hovered row.
      centsColor: Mid.isLight ? Mid.green : Mid.green.withValues(alpha: 0.8),
      sign: MoneySign.plusForPositive,
    );
  }
}

/// A row's category as a pill that opens its dropdown; the Payees page
/// shows a payee's the same way.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
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
            Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Mid.ink2),
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
    this.leading = const [],
    this.controller,
  });

  /// For a panel that wants to close the list itself (Esc closes a dropdown
  /// before it closes the panel).
  final MenuController? controller;

  /// Choices that aren't categories, listed first (a pay, by its name).
  final List<({String label, VoidCallback onTap})> leading;

  final List<AccountInfo> categories;
  final ValueChanged<AccountInfo> onPicked;
  final String? current;
  final Widget Function(bool open, VoidCallback toggle) builder;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: controller,
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Mid.raised),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 6),
        ),
        maximumSize: const WidgetStatePropertyAll(Size(260, 360)),
      ),
      alignmentOffset: const Offset(0, 4),
      menuChildren: focusFirstOnKeys([
        for (final l in leading)
          MenuItemButton(
            onPressed: l.onTap,
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(220, 34)),
              overlayColor: WidgetStatePropertyAll(Mid.blueWash),
            ),
            trailingIcon: l.label == current
                ? Icon(Icons.check_rounded, size: 14, color: Mid.blue)
                : null,
            child: Text(
              l.label,
              style: onest(13, color: l.label == current ? Mid.ink : Mid.ink2),
            ),
          ),
        for (final c in categories.where((c) => !c.archived))
          MenuItemButton(
            onPressed: () => onPicked(c),
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(220, 34)),
              overlayColor: WidgetStatePropertyAll(Mid.blueWash),
            ),
            trailingIcon: c.name == current
                ? Icon(Icons.check_rounded, size: 14, color: Mid.blue)
                : null,
            child: Text(
              c.name,
              style: onest(13, color: c.name == current ? Mid.ink : Mid.ink2),
            ),
          ),
      ]),
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
  const Hoverable({
    super.key,
    required this.builder,
    this.onTap,
    this.focusable = true,
    this.focusNode,
  });
  final Widget Function(bool hover) builder;
  final VoidCallback? onTap;

  /// Its own, when focus is to come back to it (an amount typed in it,
  /// an editor it opened, closed).
  final FocusNode? focusNode;

  /// False for a register row, which ↑ ↓ choose: Tab goes to its buttons
  /// once it's chosen, not through every row.
  final bool focusable;

  @override
  State<Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<Hoverable> {
  bool _hover = false;

  /// Reached with Tab: drawn as under the pointer, so the keyboard alone
  /// shows where it is (#162).
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    final region = MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: widget.builder(_hover || _focused),
      ),
    );
    if (onTap == null || !widget.focusable) return region;
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      // Its own, so Enter presses it before the register's keys see it.
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onTap();
            return null;
          },
        ),
      },
      child: region,
    );
  }
}

/// A menu's items, the first taking focus when the menu was opened from
/// the keyboard, so ↑ ↓, Enter and Esc work in it (#163). Opened with the
/// mouse, focus stays where it was.
List<Widget> focusFirstOnKeys(List<Widget> items) => [
  if (items.isNotEmpty) _FocusFirstOnKeys(child: items.first),
  ...items.skip(1),
];

class _FocusFirstOnKeys extends StatefulWidget {
  const _FocusFirstOnKeys({required this.child});
  final Widget child;

  @override
  State<_FocusFirstOnKeys> createState() => _FocusFirstOnKeysState();
}

class _FocusFirstOnKeysState extends State<_FocusFirstOnKeys> {
  @override
  void initState() {
    super.initState();
    if (FocusManager.instance.highlightMode != FocusHighlightMode.traditional) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // The item's own focus: the first Focus under it.
      FocusNode? first;
      void visit(Element e) {
        if (first != null) return;
        if (e.widget is Focus) {
          e.visitChildElements(
            (c) => first ??= Focus.maybeOf(c, createDependency: false),
          );
          if (first != null) return;
        }
        e.visitChildElements(visit);
      }

      context.visitChildElements(visit);
      first?.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
