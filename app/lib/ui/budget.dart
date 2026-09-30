part of 'ledger_screen.dart';

// The Budget section's first version: the one place categories are added,
// renamed, archived and deleted (ADR 0004, rule 22). No amounts yet; the
// budget model (envelopes or targets) adds its columns to these rows later.

/// What can be done to a category, from ⋯ on its row or a right-click.
class _CategoryActions {
  const _CategoryActions({
    required this.rename,
    required this.changeKind,
    required this.archive,
    required this.delete,
    this.pay,
    this.togglePayday,
  });
  final ValueChanged<String> rename;
  final VoidCallback changeKind;
  final VoidCallback archive;
  final VoidCallback delete;

  /// Income only: set up or edit its pay, and mark it payday or not.
  final VoidCallback? pay;
  final VoidCallback? togglePayday;
}

class _BudgetPage extends StatefulWidget {
  const _BudgetPage({
    required this.data,
    required this.actionsFor,
    required this.onCreate,
    required this.onUnarchive,
    required this.onShowRows,
  });
  final LedgerData data;

  /// The usage text was clicked: its rows, in All accounts.
  final ValueChanged<AccountInfo> onShowRows;
  final _CategoryActions Function(AccountInfo) actionsFor;
  final void Function(String name, bool income) onCreate;
  final ValueChanged<AccountInfo> onUnarchive;

  @override
  State<_BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<_BudgetPage> {
  bool _adding = false;
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final data = widget.data;
    final spending = data.categories.where((c) => !c.isIncome).toList();
    final income = data.categories.where((c) => c.isIncome).toList();
    final archived = data.archivedCategories;

    Widget group(String title, List<AccountInfo> list) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Text(title, style: onest(12.5, color: Mid.ink3)),
        ),
        for (final c in list)
          _CategoryRow(
            key: ValueKey('category-${c.id}'),
            category: c,
            usage: data.categoryUsage[c.id],
            actions: widget.actionsFor(c),
            onShowRows: () => widget.onShowRows(c),
            payNote: c.isIncome ? _payNote(t, data, c) : null,
          ),
        const SizedBox(height: 14),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 36,
                child: Row(
                  children: [
                    Text(
                      t.planBudget,
                      style: onest(22, weight: 600, letterSpacing: -0.3),
                    ),
                    const Spacer(),
                    _PrimaryButton(
                      key: const ValueKey('add-category'),
                      label: t.planAddCategory,
                      icon: Icons.add_rounded,
                      tooltip: t.planAddCategoryTip,
                      onTap: () => setState(() => _adding = true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Mid.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Mid.rule),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                    children: [
                      if (_adding)
                        _NewCategory(
                          // Stays open for the next one, like the entry row;
                          // Esc or Cancel closes it.
                          onCreate: widget.onCreate,
                          onCancel: () => setState(() => _adding = false),
                        ),
                      group(t.planSpending, spending),
                      if (income.isNotEmpty) group(t.planIncome, income),
                      if (archived.isNotEmpty) ...[
                        Hoverable(
                          key: const ValueKey('show-archived-categories'),
                          onTap: () =>
                              setState(() => _showArchived = !_showArchived),
                          builder: (hover) => Padding(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                            child: Text(
                              _showArchived
                                  ? t.planHideArchived(archived.length)
                                  : t.planShowArchived(archived.length),
                              style: onest(
                                12.5,
                                color: hover ? Mid.ink2 : Mid.ink3,
                              ),
                            ),
                          ),
                        ),
                        if (_showArchived)
                          for (final c in archived)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      c.name,
                                      style: onest(13.5, color: Mid.ink2),
                                    ),
                                  ),
                                  Text(
                                    _usageText(t, data.categoryUsage[c.id]),
                                    style: onest(12.5, color: Mid.ink3),
                                  ),
                                  const SizedBox(width: 16),
                                  BarButton(
                                    key: ValueKey('unarchive-category-${c.id}'),
                                    label: t.planShowInMenus,
                                    onTap: () => widget.onUnarchive(c),
                                  ),
                                ],
                              ),
                            ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What an income category's line says about pay: "payday · ₮2,100,000 or
/// more on the 10th and 25th · next 09.25", "payday · pay not set up" (gold,
/// until it is), or "not a payday". It suggests updating the amount from
/// the schedule's own paychecks, and never changes it itself:
/// - pay that varies: only when even the lowest of the last six beat the
///   estimate by 5% (a floor is meant to be beaten; one thin month mustn't
///   leave it too high);
/// - pay that's the same: when the last two came in alike and off the plan
///   (a raise, a tax change, a cut), louder when it's less.
({String text, bool nudge}) _payNote(Words t, LedgerData data, AccountInfo c) {
  if (!c.payday) return (text: t.planNotPayday, nudge: false);
  final pays = data.paySchedules.where((p) => p.categoryId == c.id).toList();
  if (pays.isEmpty) {
    // Said once in the pay setup: no regular pay, so nothing to nag about.
    return data.prefs[noRegularPayKey] == '1'
        ? (text: t.planPaydayNoRegular, nudge: false)
        : (text: t.planPaydayNotSetUp, nudge: true);
  }
  final p = pays.first;
  final more = pays.length > 1 ? t.planMorePay(pays.length - 1) : '';
  String money(int v) => formatMoney(v, showCents: v % 100 != 0);
  // Each paycheck beside what was planned for its own day: split pay's
  // advance is measured against the advance, not the rest.
  final came = data
      .registerAll(categoryId: c.id)
      .posted
      .where((r) => r.payScheduleId == p.id && r.amount > 0)
      .map(
        (r) => (
          amount: r.amount,
          plan: p.amountOn(p.plannedFor(r.date, paid: r.amount)),
        ),
      )
      .toList()
      .reversed
      .toList();
  if (p.varies && came.length >= 6) {
    final last6 = came.take(6);
    if (last6.every((x) => x.amount * 20 > x.plan * 21)) {
      final low = last6.map((x) => x.amount).reduce((a, b) => a < b ? a : b);
      return (
        text: p.split
            ? '${t.planRaiseSplit}$more'
            : '${t.planRaiseLowest(money(low))}$more',
        nudge: true,
      );
    }
  }
  // Pay that's the same: the last two for the same day came in alike.
  final same = came.isEmpty
      ? const <({int amount, int plan})>[]
      : came.where((x) => x.plan == came[0].plan).take(2).toList();
  if (!p.varies && same.length == 2 && same[0].amount == same[1].amount) {
    final now = same[0].amount, plan = same[0].plan;
    // More than 2% off the plan either way.
    if ((now - plan).abs() * 50 > plan) {
      return (
        text: now < plan
            ? '${t.planLastTwoLess(money(now))}$more'
            : '${t.planLastTwoMore(money(now))}$more',
        nudge: true,
      );
    }
  }
  final next = data
      .registerFor(p.accountId)
      .scheduled
      .where((r) => r.payScheduleId == p.id)
      .firstOrNull;
  final pay = payAmounts(t, p, money);
  final note = next == null
      ? t.planPaydayPay(pay)
      : t.planPaydayPayNext(pay, sayDate(t, next.date));
  return (text: '$note$more', nudge: false);
}

/// "09.12" this year; the full date before, since a category last used in
/// another year is the one worth archiving.
String _lastDate(Words t, DateTime d) =>
    d.year == DateTime.now().year ? sayDate(t, d) : sayFullDate(t, d);

String _usageText(Words t, CategoryUsage? u) {
  if (u == null) return t.planNoRows;
  final parts = [
    if (u.rows > 0)
      u.last == null
          ? t.planUsageRows(u.rows)
          : t.planUsageRowsLast(u.rows, _lastDate(t, u.last!)),
    if (u.scheduled > 0) t.planUsageScheduled(u.scheduled),
  ];
  return parts.isEmpty ? t.planNoRows : parts.join(' · ');
}

/// One category: its name renames in place when clicked; ⋯ or a right-click
/// for the rest.
class _CategoryRow extends StatefulWidget {
  const _CategoryRow({
    super.key,
    required this.category,
    required this.usage,
    required this.actions,
    required this.onShowRows,
    this.payNote,
  });
  final AccountInfo category;
  final VoidCallback onShowRows;

  /// Income: whether it's payday, its pay, and any nudge about the estimate.
  final ({String text, bool nudge})? payNote;
  final CategoryUsage? usage;
  final _CategoryActions actions;

  @override
  State<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<_CategoryRow> {
  final _menu = MenuController();
  final _focus = FocusNode(debugLabel: 'category-name');
  TextEditingController? _editing;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing != null) _save();
    });
  }

  @override
  void dispose() {
    _editing?.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startRename() {
    final name = widget.category.name;
    setState(
      () => _editing = TextEditingController(text: name)
        ..selection = TextSelection(baseOffset: 0, extentOffset: name.length),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _save() {
    final name = _editing?.text.trim() ?? '';
    _cancel();
    if (name.isNotEmpty && name != widget.category.name) {
      widget.actions.rename(name);
    }
  }

  void _cancel() {
    final c = _editing;
    if (c == null) return;
    setState(() => _editing = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = widget.category;
    final a = widget.actions;
    return MenuAnchor(
      controller: _menu,
      style: _menuStyle,
      onOpen: () => setState(() {}),
      onClose: () {
        if (mounted) setState(() {});
      },
      menuChildren: _categoryMenu(
        t,
        c,
        _CategoryActions(
          rename: (_) => _startRename(),
          changeKind: a.changeKind,
          archive: a.archive,
          delete: a.delete,
          pay: a.pay,
          togglePayday: a.togglePayday,
        ),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTapDown: (d) => _menu.open(position: d.localPosition),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _hover || _menu.isOpen ? Mid.hover : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _editing != null
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 280,
                            height: 32,
                            child: CallbackShortcuts(
                              bindings: {
                                const SingleActivator(
                                  LogicalKeyboardKey.escape,
                                ): _cancel,
                              },
                              child: TextField(
                                key: const ValueKey('category-name-field'),
                                controller: _editing,
                                focusNode: _focus,
                                style: onest(13.5),
                                onSubmitted: (_) => _save(),
                                decoration: _fieldDecoration(),
                              ),
                            ),
                          ),
                        )
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Tooltip(
                            message: t.planClickToRename,
                            waitDuration: const Duration(milliseconds: 600),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.text,
                              child: GestureDetector(
                                onTap: _startRename,
                                child: Text(c.name, style: onest(13.5)),
                              ),
                            ),
                          ),
                        ),
                ),
                if (widget.payNote case final note?) ...[
                  Flexible(
                    child: Hoverable(
                      key: ValueKey('pay-note-${c.id}'),
                      onTap: widget.actions.pay,
                      builder: (hover) => Text(
                        note.text,
                        style:
                            onest(
                              12.5,
                              color: note.nudge ? Mid.gold : Mid.ink2,
                            ).copyWith(
                              decoration: hover && widget.actions.pay != null
                                  ? TextDecoration.underline
                                  : null,
                              decorationColor: note.nudge ? Mid.gold : Mid.ink2,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // Its rows, in All accounts: what the count is counting.
                if (widget.usage == null)
                  Text(
                    _usageText(t, widget.usage),
                    style: onest(12.5, color: Mid.ink3, tabular: true),
                  )
                else
                  Tooltip(
                    message: t.planShowTheseRows,
                    waitDuration: const Duration(milliseconds: 500),
                    child: Hoverable(
                      key: ValueKey('category-rows-${c.id}'),
                      onTap: widget.onShowRows,
                      builder: (hover) => Text(
                        _usageText(t, widget.usage),
                        style:
                            onest(
                              12.5,
                              color: hover ? Mid.blue : Mid.ink3,
                              tabular: true,
                            ).copyWith(
                              decoration: hover
                                  ? TextDecoration.underline
                                  : null,
                              decorationColor: Mid.blue,
                            ),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Hoverable(
                  key: ValueKey('category-menu-${c.id}'),
                  onTap: () => _menu.isOpen ? _menu.close() : _menu.open(),
                  builder: (hover) => Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: hover ? Mid.raised : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: 18,
                      color: hover || _hover ? Mid.ink2 : Mid.ink3,
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

List<Widget> _categoryMenu(Words t, AccountInfo c, _CategoryActions act) {
  Widget item(String label, String key, VoidCallback onTap, {Color? color}) =>
      MenuItemButton(
        key: ValueKey(key),
        onPressed: onTap,
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(220, 34)),
          overlayColor: WidgetStatePropertyAll(Mid.blueWash),
        ),
        child: Text(label, style: onest(13, color: color ?? Mid.ink2)),
      );
  return [
    item(t.planRename, 'category-rename', () => act.rename(c.name)),
    if (act.pay case final pay?) item(t.planPayMenu, 'category-pay', pay),
    if (act.togglePayday case final toggle?)
      item(
        c.payday ? t.planUnmarkPayday : t.planMarkPayday,
        'category-payday',
        toggle,
      ),
    item(
      c.isIncome ? t.planChangeToSpending : t.planChangeToIncome,
      'category-kind',
      act.changeKind,
    ),
    Divider(height: 9, color: Mid.rule),
    item(t.planArchive, 'category-archive', act.archive),
    item(t.planDeleteMenu, 'category-delete', act.delete, color: Mid.coral),
  ];
}

/// Name and whether it's income. Income ends a forecast (payday).
class _NewCategory extends StatefulWidget {
  const _NewCategory({required this.onCreate, required this.onCancel});
  final void Function(String name, bool income) onCreate;
  final VoidCallback onCancel;

  @override
  State<_NewCategory> createState() => _NewCategoryState();
}

class _NewCategoryState extends State<_NewCategory> {
  final _name = TextEditingController();
  final _focus = FocusNode(debugLabel: 'new-category');
  bool _income = false;

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _create() {
    final n = _name.text.trim();
    // Nothing typed: nothing to call it, so nothing is made.
    if (n.isEmpty) return widget.onCancel();
    widget.onCreate(n, _income);
    // Ready for the next: setting up several is one after another.
    _name.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    Widget kind(bool income, String label) {
      final on = _income == income;
      return Hoverable(
        key: ValueKey('category-kind-${income ? 'income' : 'spending'}'),
        onTap: () => setState(() => _income = income),
        builder: (hover) => Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on
                ? Mid.blueWash
                : (hover ? Mid.raised : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: on ? Mid.blue : Mid.ink2.withValues(alpha: 0.3),
            ),
          ),
          child: Text(label, style: onest(13, color: on ? Mid.ink : Mid.ink2)),
        ),
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onCancel,
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Mid.ground.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 260,
                  height: 34,
                  child: TextField(
                    key: const ValueKey('new-category-name'),
                    controller: _name,
                    focusNode: _focus,
                    autofocus: true,
                    style: onest(13.5),
                    onSubmitted: (_) => _create(),
                    decoration: _fieldDecoration(hint: t.planCategoryName),
                  ),
                ),
                const SizedBox(width: 10),
                kind(false, t.planSpending),
                const SizedBox(width: 6),
                kind(true, t.planIncome),
                const Spacer(),
                BarButton(
                  key: const ValueKey('new-category-cancel'),
                  label: t.planCancel,
                  onTap: widget.onCancel,
                ),
                _PrimaryButton(
                  key: const ValueKey('new-category-create'),
                  label: t.planAdd,
                  icon: Icons.add_rounded,
                  tooltip: 'Enter',
                  onTap: _create,
                ),
              ],
            ),
            if (_income)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 2),
                child: Text(
                  t.planIncomeEndsForecast,
                  style: onest(12.5, color: Mid.ink3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Deleting a category with rows: they need somewhere to go, so the dialog
/// asks where, and says how many move. Opened from a rename onto another
/// category's name, it's the same merge with that one already picked.
class _DeleteCategoryDialog extends StatefulWidget {
  const _DeleteCategoryDialog({
    required this.category,
    required this.usage,
    required this.targets,
    this.into,
  });
  final AccountInfo category;
  final CategoryUsage? usage;
  final List<AccountInfo> targets;
  final AccountInfo? into;

  @override
  State<_DeleteCategoryDialog> createState() => _DeleteCategoryDialogState();
}

class _DeleteCategoryDialogState extends State<_DeleteCategoryDialog> {
  late AccountInfo? _into = widget.into;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = widget.category;
    final posted = widget.usage?.rows ?? 0;
    final scheduled = widget.usage?.scheduled ?? 0;
    final n = posted + scheduled;
    final merging = widget.into != null;
    final into = _into;
    // Same kind first: spending rows usually belong in spending.
    final targets = [
      ...widget.targets.where((t) => t.isIncome == c.isIncome),
      ...widget.targets.where((t) => t.isIncome != c.isIncome),
    ];
    final lines = [
      if (n == 0)
        merging ? t.planNothingFiled : t.planOnlyDeletedFiled
      else if (scheduled == 0)
        t.planRowsFiled(n)
      else
        t.planRowsFiledScheduled(n, scheduled),
    ];
    // Moving between kinds changes what the rows count as, and where a
    // forecast ends.
    final kindNote = into == null || into.isIncome == c.isIncome || n == 0
        ? null
        : into.isIncome
        ? (scheduled == 0
              ? t.planIntoIncome(into.name)
              : t.planIntoIncomeScheduled(into.name))
        : (scheduled == 0
              ? t.planIntoSpending(into.name)
              : t.planIntoSpendingScheduled(into.name));
    return Dialog(
      backgroundColor: Mid.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Mid.coral.withValues(alpha: 0.5)),
      ),
      child: SizedBox(
        width: 480,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                merging
                    ? t.planMergeTitle(c.name, widget.into!.name)
                    : t.planDeleteTitle(c.name),
                style: onest(
                  17,
                  weight: 600,
                  letterSpacing: -0.2,
                  color: Mid.coral,
                ),
              ),
              const SizedBox(height: 14),
              for (final l in lines) Text(l, style: onest(13.5)),
              const SizedBox(height: 10),
              if (targets.isEmpty)
                Text(
                  t.planNoOtherCategory,
                  style: onest(13.5, color: Mid.coral),
                )
              else if (!merging)
                CategoryMenu(
                  categories: targets,
                  current: into?.name,
                  onPicked: (t) => setState(() => _into = t),
                  builder: (open, toggle) => BarButton(
                    key: const ValueKey('delete-category-into'),
                    label: into?.name ?? t.planPickCategory,
                    trailing: Icons.expand_more_rounded,
                    active: open,
                    onTap: toggle,
                  ),
                ),
              if (kindNote != null) ...[
                const SizedBox(height: 10),
                Text(kindNote, style: onest(13, color: Mid.gold)),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  BarButton(
                    key: const ValueKey('warning-cancel'),
                    label: t.planCancel,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  Material(
                    key: const ValueKey('warning-confirm'),
                    color: into == null
                        ? Mid.coral.withValues(alpha: 0.25)
                        : Mid.coral,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: into == null
                          ? null
                          : () => Navigator.of(context).pop(into),
                      borderRadius: BorderRadius.circular(8),
                      hoverColor: Colors.white.withValues(alpha: 0.14),
                      child: Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        child: Text(
                          into == null
                              ? t.planDeleteButton(c.name)
                              : merging
                              ? t.planMergeButton(into.name)
                              : t.planMoveAndDelete(into.name),
                          style: onest(
                            13,
                            weight: 600,
                            color: into == null
                                ? Mid.coral.withValues(alpha: 0.6)
                                : Mid.onAccent,
                          ),
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
