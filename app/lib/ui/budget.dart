part of 'ledger_screen.dart';

// The Budget section: envelopes, each spending category reading Put in ·
// Spent · Left for the period on screen, under the money not given out yet
// (ADR 0004 rule 26). Also the one place categories are added, renamed,
// archived and deleted (rule 22).

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
    required this.today,
    required this.actionsFor,
    required this.onCreate,
    required this.onUnarchive,
    required this.onShowRows,
    required this.onShowAllRows,
    required this.onSetAmount,
    required this.onKeysBack,
    required this.onStartLater,
    required this.onKeepStart,
    required this.onShowUncategorized,
  });

  /// The first-period offer: start the budget in the next period instead.
  final void Function(BudgetSpan period, BudgetSpan next) onStartLater;
  final VoidCallback onKeepStart;

  /// The "Not categorized" line was clicked: its rows.
  final VoidCallback onShowUncategorized;
  final LedgerData data;
  final DateTime today;

  /// Typing ended: ⌘Z and the other keys go back to the screen.
  final VoidCallback onKeysBack;

  /// Spent was clicked: the category's rows in that period, in All accounts.
  final void Function(AccountInfo, BudgetSpan) onShowRows;

  /// The usage in the ⋯ menu was picked: every row, all time.
  final ValueChanged<AccountInfo> onShowAllRows;
  final _CategoryActions Function(AccountInfo) actionsFor;
  final void Function(String name, bool income) onCreate;
  final ValueChanged<AccountInfo> onUnarchive;

  /// A Put in amount was typed for the period starting on the date.
  final void Function(AccountInfo, BudgetSpan, int) onSetAmount;

  @override
  State<_BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<_BudgetPage> {
  bool _adding = false;
  bool _showArchived = false;

  /// The period on screen; null for the one today is in.
  BudgetSpan? _period;

  /// The category whose Put in is being typed.
  int? _editing;

  BudgetSpan get _current =>
      budgetPeriod(widget.today, widget.data.periodSchedule);

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final data = widget.data;
    final by = data.periodSchedule;
    // Switching between months and pay periods in Settings starts over at
    // today's period.
    var period = _period ?? _current;
    // So does a period that no longer is one (the pay schedule changed):
    // amounts typed there would land between periods.
    if (period.label != _current.label ||
        budgetPeriod(period.start, by).start != period.start) {
      period = _current;
    }
    final isCurrent =
        !widget.today.isBefore(period.start) &&
        !widget.today.isAfter(period.end);
    final budget = Budget.of(
      data,
      start: period.start,
      end: period.end,
      today: widget.today,
    );
    // "Not categorized" holds no money: its rows count in the top line.
    final spending = data.categories
        .where((c) => !c.isIncome && !isUncategorized(c))
        .toList();
    final income = data.categories.where((c) => c.isIncome).toList();
    final archived = data.archivedCategories;
    final began = budget.began;
    // "From before" means something once the budget had begun before this
    // period.
    final carries = began != null && began.isBefore(period.start);

    String money(int v) => formatMoney(v, currency: budget.currency);

    void edit(int? id) {
      setState(() => _editing = id);
      if (id == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onKeysBack();
        });
      }
    }

    void editNext(AccountInfo c) {
      final i = spending.indexWhere((x) => x.id == c.id);
      edit(i >= 0 && i + 1 < spending.length ? spending[i + 1].id : null);
    }

    Widget columns(String title, List<String> heads) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: onest(12.5, color: Mid.ink3)),
          ),
          for (final h in heads)
            SizedBox(
              width: _amountWidth,
              child: Text(
                h,
                textAlign: TextAlign.right,
                style: onest(12.5, color: Mid.ink3),
              ),
            ),
          const SizedBox(width: 40),
        ],
      ),
    );

    Widget row(AccountInfo c, {required bool striped}) {
      final line = budget.lines[c.id];
      return _CategoryRow(
        key: ValueKey('category-${c.id}'),
        category: c,
        striped: striped,
        usage: data.categoryUsage[c.id],
        actions: widget.actionsFor(c),
        onShowAllRows: () => widget.onShowAllRows(c),
        onShowRows: () => widget.onShowRows(c, period),
        payNote: c.isIncome ? _payNote(t, data, c) : null,
        cameIn: c.isIncome ? budget.cameIn[c.id] ?? 0 : null,
        line: c.isIncome ? null : line,
        fromBefore: carries && line != null && line.fromBefore != 0
            ? t.planFromBefore(money(line.fromBefore))
            : null,
        currency: budget.currency,
        editing: _editing == c.id,
        onEdit: () => edit(c.id),
        onAssign: (amount, {required bool next}) {
          if (amount != null && amount != (line?.assigned ?? 0)) {
            widget.onSetAmount(c, period, amount);
          }
          next ? editNext(c) : edit(null);
        },
      );
    }

    final held = budget.money - budget.notAssigned;
    final top = budget.notAssigned > 0
        ? t.planNotAssigned(money(budget.notAssigned))
        : budget.notAssigned == 0
        ? t.planAllAssigned
        // Below zero with nothing held: cards owe more than there is, and
        // nothing was assigned that could be "too much".
        : held <= 0 && budget.money < 0
        ? t.planCardsOwe(money(-budget.money))
        : t.planAssignedOver(money(-budget.notAssigned));
    // Started partway through a period, with spending in categories
    // nothing was assigned to: offer the next period instead (owner's
    // call). Answered once, it goes.
    final offerStart =
        began != null &&
        data.prefs[BudgetKeys.keptStart] == null &&
        !began.isBefore(period.start) &&
        !began.isAfter(period.end) &&
        widget.today.isAfter(period.start) &&
        budget.unassignedSpent.count > 0;
    final other = {
      for (final a in data.openAccounts)
        if (a.currency != budget.currency) a.currency,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
      // As wide as the page, like an account's register.
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
                const SizedBox(width: 20),
                _PeriodArrow(
                  key: const ValueKey('period-prev'),
                  icon: Icons.chevron_left_rounded,
                  tooltip: t.planPeriodPrev,
                  onTap: () => setState(() {
                    _editing = null;
                    _period = previousBudgetPeriod(period, by);
                  }),
                ),
                Text(
                  t.planPeriodTitle(
                    _spanName(t, period, widget.today),
                    shortDate(period.start),
                    shortDate(period.end),
                  ),
                  key: const ValueKey('period-title'),
                  style: onest(14.5, weight: 500, color: Mid.ink2),
                ),
                _PeriodArrow(
                  key: const ValueKey('period-next'),
                  icon: Icons.chevron_right_rounded,
                  tooltip: t.planPeriodNext,
                  onTap: () => setState(() {
                    _editing = null;
                    _period = nextBudgetPeriod(period, by);
                  }),
                ),
                if (!isCurrent) ...[
                  const SizedBox(width: 8),
                  Hoverable(
                    key: const ValueKey('period-today'),
                    onTap: () => setState(() {
                      _editing = null;
                      _period = null;
                    }),
                    builder: (hover) => Text(
                      t.planBackToToday,
                      style: onest(13, color: hover ? Mid.blue : Mid.ink3),
                    ),
                  ),
                ],
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
          const SizedBox(height: 14),
          Tooltip(
            message: t.planNotAssignedTip(money(budget.money), money(held)),
            waitDuration: const Duration(milliseconds: 500),
            child: Text(
              top,
              key: const ValueKey('not-assigned'),
              style: onest(
                17,
                weight: 600,
                color: budget.notAssigned < 0 ? Mid.coral : Mid.ink,
                tabular: true,
              ),
            ),
          ),
          if (budget.uncategorizedRows > 0) ...[
            const SizedBox(height: 4),
            Hoverable(
              key: const ValueKey('uncategorized-line'),
              onTap: widget.onShowUncategorized,
              builder: (hover) => Text(
                t.planUncategorized(
                  '${budget.uncategorizedRows}',
                  budget.uncategorizedNet > 0
                      ? '+${money(budget.uncategorizedNet)}'
                      : money(budget.uncategorizedNet),
                ),
                style: onest(13, color: hover ? Mid.blue : Mid.gold),
              ),
            ),
          ],
          if (offerStart) ...[
            const SizedBox(height: 10),
            _StartOffer(
              text: t.planStartOffer(
                money(budget.unassignedSpent.amount),
                '${budget.unassignedSpent.count}',
              ),
              later: t.planStartLater(
                sayDate(t, nextBudgetPeriod(period, by).start),
              ),
              onLater: () {
                final next = nextBudgetPeriod(period, by);
                widget.onStartLater(period, next);
                setState(() {
                  _editing = null;
                  _period = next;
                });
              },
              onKeep: widget.onKeepStart,
            ),
          ],
          if (other.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              t.planOtherCurrency(other.map((c) => c.symbol).join(', ')),
              style: onest(12.5, color: Mid.ink3),
            ),
          ],
          const SizedBox(height: 16),
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
                  columns(t.planSpending, [
                    t.planAssigned,
                    t.planSpent,
                    t.planLeft,
                  ]),
                  for (final (i, c) in spending.indexed)
                    row(c, striped: i.isOdd),
                  const SizedBox(height: 14),
                  if (income.isNotEmpty) ...[
                    columns(t.planIncome, [t.planCameIn]),
                    for (final (i, c) in income.indexed)
                      row(c, striped: i.isOdd),
                    const SizedBox(height: 14),
                  ],
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
                              // Money can still sit in an archived one.
                              if (budget.lines[c.id]?.left case final left?
                                  when left != 0) ...[
                                const SizedBox(width: 16),
                                Money(
                                  left,
                                  size: 13,
                                  currency: budget.currency,
                                  color: left < 0 ? Mid.coral : Mid.ink2,
                                ),
                              ],
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
    );
  }
}

const double _amountWidth = 136;

/// "This month" or "This pay period" for the one today is in; otherwise
/// the month's name (with its year when it isn't this year's), or "Pay
/// period". The dates beside it say which.
String _spanName(Words t, BudgetSpan p, DateTime today) {
  if (!today.isBefore(p.start) && !today.isAfter(p.end)) {
    return periodName(t, p);
  }
  if (p.label == payPeriodLabel) return t.planPayPeriod;
  final m = monthName(t, p.start.month);
  return p.start.year == today.year ? m : '$m ${p.start.year}';
}

class _PeriodArrow extends StatelessWidget {
  const _PeriodArrow({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    waitDuration: const Duration(milliseconds: 500),
    child: Hoverable(
      onTap: onTap,
      builder: (hover) => Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: hover ? Mid.raised : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: hover ? Mid.ink : Mid.ink2),
      ),
    ),
  );
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
  String money(int v) => formatMoney(
    v,
    showCents: v % 100 != 0,
    currency: data.accounts[p.accountId]?.currency ?? Currency.mnt,
  );
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
    required this.striped,
    required this.usage,
    required this.actions,
    required this.onShowRows,
    required this.onShowAllRows,
    required this.currency,
    required this.editing,
    required this.onEdit,
    required this.onAssign,
    this.payNote,
    this.line,
    this.cameIn,
    this.fromBefore,
  });
  final AccountInfo category;

  /// Every other row is tinted, as in the register: the name and its
  /// amounts sit a page apart.
  final bool striped;

  /// Spent was clicked: this period's rows.
  final VoidCallback onShowRows;

  /// The usage in the menu was picked: every row.
  final VoidCallback onShowAllRows;

  /// Spending: Put in, Spent and Left for the period on screen.
  final EnvelopeLine? line;

  /// Income: what came in during the period.
  final int? cameIn;

  /// "₮500,000 from before", when the category carried money in.
  final String? fromBefore;
  final Currency currency;

  /// Its Put in is being typed.
  final bool editing;
  final VoidCallback onEdit;

  /// Typing Put in ended: the amount (null when nothing valid was typed or
  /// it was cancelled), and whether Tab asked for the next category.
  final void Function(int? amount, {required bool next}) onAssign;

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
        usage: widget.usage == null ? null : _usageText(t, widget.usage),
        showRows: widget.onShowAllRows,
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
            constraints: const BoxConstraints(minHeight: 40),
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: widget.fromBefore == null ? 0 : 5,
            ),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                _hover || _menu.isOpen ? Mid.rowHover : Colors.transparent,
                widget.striped ? Mid.stripe : Colors.transparent,
              ),
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
                  // Not Flexible: sharing the spare width with the name
                  // would leave the amount short of its column.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
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
                if (widget.line case final line?) ...[
                  SizedBox(
                    width: _amountWidth,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _AssignField(
                        key: ValueKey('assigned-${c.id}'),
                        amount: line.assigned,
                        currency: widget.currency,
                        editing: widget.editing,
                        onEdit: widget.onEdit,
                        onDone: widget.onAssign,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: _amountWidth,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Tooltip(
                        message: t.planShowTheseRows,
                        waitDuration: const Duration(milliseconds: 500),
                        child: Hoverable(
                          key: ValueKey('spent-${c.id}'),
                          onTap: widget.onShowRows,
                          // Spending reads as what was spent, no sign; more
                          // back than spent shows as a plus.
                          builder: (hover) => Money(
                            line.spent.abs(),
                            sign: line.spent < 0
                                ? MoneySign.plusForPositive
                                : MoneySign.none,
                            size: 13.5,
                            currency: widget.currency,
                            color: hover
                                ? Mid.blue
                                : (line.spent == 0 ? Mid.ink3 : Mid.ink2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: _amountWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Money(
                          line.left,
                          key: ValueKey('left-${c.id}'),
                          size: 13.5,
                          weight: 600,
                          currency: widget.currency,
                          color: line.left < 0
                              ? Mid.coral
                              : (line.left == 0 ? Mid.ink3 : Mid.ink),
                        ),
                        if (widget.fromBefore case final before?)
                          Text(
                            before,
                            key: ValueKey('from-before-${c.id}'),
                            style: onest(11.5, color: Mid.ink3, tabular: true),
                          ),
                      ],
                    ),
                  ),
                ],
                if (widget.cameIn case final came?)
                  SizedBox(
                    width: _amountWidth,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Tooltip(
                        message: t.planShowTheseRows,
                        waitDuration: const Duration(milliseconds: 500),
                        child: Hoverable(
                          key: ValueKey('came-in-${c.id}'),
                          onTap: widget.onShowRows,
                          builder: (hover) => Money(
                            came,
                            size: 13.5,
                            currency: widget.currency,
                            color: hover
                                ? Mid.blue
                                : (came == 0 ? Mid.ink3 : Mid.ink2),
                          ),
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

List<Widget> _categoryMenu(
  Words t,
  AccountInfo c,
  _CategoryActions act, {
  String? usage,
  VoidCallback? showRows,
}) {
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
    // How much it's used decides keep, merge or archive, which is what
    // this menu is for; picking it shows every row.
    if (usage != null && showRows != null) ...[
      item(t.planShowAllRows(usage), 'category-rows', showRows),
      Divider(height: 9, color: Mid.rule),
    ],
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

/// A category's Put in: the amount, and a field in its place while typing.
/// Enter or leaving the field saves, Tab saves and goes to the next
/// category, Esc cancels. Sums work, as in the entry row (`300000+50000`).
class _AssignField extends StatefulWidget {
  const _AssignField({
    super.key,
    required this.amount,
    required this.currency,
    required this.editing,
    required this.onEdit,
    required this.onDone,
  });
  final int amount;
  final Currency currency;
  final bool editing;
  final VoidCallback onEdit;
  final void Function(int? amount, {required bool next}) onDone;

  @override
  State<_AssignField> createState() => _AssignFieldState();
}

class _AssignFieldState extends State<_AssignField> {
  TextEditingController? _text;
  final _focus = FocusNode(debugLabel: 'put-in');
  bool _wrong = false;

  /// Ended by a key already: losing focus afterwards mustn't end it again.
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _text != null && !_done) _finish(next: false);
    });
    if (widget.editing) _open();
  }

  @override
  void didUpdateWidget(_AssignField old) {
    super.didUpdateWidget(old);
    if (widget.editing && _text == null) _open();
    if (!widget.editing && _text != null) {
      // Closed from outside (an arrow, Back to today) mid-typing: what was
      // typed is kept, as clicking away would.
      final typed = _text!.text.trim();
      final amount = typed.isEmpty ? 0 : parseAmount(typed);
      if (!_done && amount != null && amount != widget.amount) {
        _done = true;
        // The old callback: the page may already show another period.
        final done = old.onDone;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => done(amount, next: false),
        );
      }
      _close();
    }
  }

  @override
  void dispose() {
    _text?.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _open() {
    final a = widget.amount;
    final shown = a == 0
        ? ''
        : '${a < 0 ? '-' : ''}${formatWhole(a)}'
              '${formatCents(a) == '.00' ? '' : formatCents(a)}';
    _text = TextEditingController(text: shown)
      ..selection = TextSelection(baseOffset: 0, extentOffset: shown.length);
    _done = false;
    _wrong = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _close() {
    final c = _text;
    _text = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => c?.dispose());
  }

  void _finish({required bool next}) {
    final typed = _text?.text.trim() ?? '';
    // Emptied: nothing goes in.
    final amount = typed.isEmpty ? 0 : parseAmount(typed);
    if (amount == null) {
      // Not an amount: stay, outlined, so the typing isn't lost.
      setState(() => _wrong = true);
      _focus.requestFocus();
      return;
    }
    _done = true;
    widget.onDone(amount, next: next);
  }

  void _cancel() {
    _done = true;
    widget.onDone(null, next: false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final text = _text;
    if (text != null) {
      return SizedBox(
        width: _amountWidth - 8,
        height: 30,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): _cancel,
            const SingleActivator(LogicalKeyboardKey.tab): () =>
                _finish(next: true),
          },
          child: TextField(
            key: const ValueKey('assign-field'),
            controller: text,
            focusNode: _focus,
            textAlign: TextAlign.right,
            style: onest(13.5, tabular: true),
            onChanged: (_) {
              if (_wrong) setState(() => _wrong = false);
            },
            onSubmitted: (_) => _finish(next: false),
            decoration: _fieldDecoration(wrong: _wrong).copyWith(
              prefixText: widget.currency.symbol,
              prefixStyle: onest(13.5, color: Mid.ink3),
            ),
          ),
        ),
      );
    }
    return Tooltip(
      message: t.planAssignTip,
      waitDuration: const Duration(milliseconds: 600),
      child: Hoverable(
        onTap: widget.onEdit,
        builder: (hover) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            // Outlined on hover: it's a field, and a click types in it.
            border: Border.all(
              color: hover
                  ? Mid.ink2.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Money(
            widget.amount,
            size: 13.5,
            currency: widget.currency,
            color: widget.amount == 0 ? Mid.ink3 : Mid.ink2,
          ),
        ),
      ),
    );
  }
}

/// The gold note after the first amount lands in a period already under
/// way: what it counts, and the choice to start in the next period.
class _StartOffer extends StatelessWidget {
  const _StartOffer({
    required this.text,
    required this.later,
    required this.onLater,
    required this.onKeep,
  });
  final String text;
  final String later;
  final VoidCallback onLater;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('start-offer'),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: Mid.gold.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Mid.gold.withValues(alpha: 0.4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: onest(13.5, color: Mid.ink)),
        const SizedBox(height: 10),
        Row(
          children: [
            _PrimaryButton(
              key: const ValueKey('start-later'),
              label: later,
              icon: Icons.arrow_forward_rounded,
              onTap: onLater,
            ),
            const SizedBox(width: 8),
            BarButton(
              key: const ValueKey('start-keep'),
              label: context.t.planStartKeep,
              onTap: onKeep,
            ),
          ],
        ),
      ],
    ),
  );
}
