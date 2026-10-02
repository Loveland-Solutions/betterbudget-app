part of 'ledger_screen.dart';

// The Budget section: envelopes, each spending category reading Assigned ·
// Spent · Left for the period on screen, under the money not assigned yet
// (ADR 0004 rule 26), with its plan under its name (rule 27). Also the one
// place categories are added, edited, archived and deleted (rule 22):
// double-click a row, or Edit in its menu, opens everything about it under
// the row (rule 29).

/// What Edit saves for a category: everything it has, changed or not.
typedef _CategoryEdit = ({
  String name,
  bool income,
  Currency currency,
  Set<int> off,
  CategoryPlan? plan,
  bool payday,
});

class _BudgetPage extends StatefulWidget {
  const _BudgetPage({
    super.key,
    required this.data,
    required this.today,
    required this.onSave,
    required this.onArchive,
    required this.onDelete,
    required this.onPay,
    required this.onCreate,
    required this.onUnarchive,
    required this.onShowRows,
    required this.onShowAllRows,
    required this.onSetAmount,
    required this.onKeysBack,
    required this.onStartLater,
    required this.onKeepStart,
    required this.onShowUncategorized,
    required this.onAssignPlanned,
  });

  /// Edit was saved: the category as it should be now.
  final void Function(AccountInfo, _CategoryEdit) onSave;
  final ValueChanged<AccountInfo> onArchive;
  final ValueChanged<AccountInfo> onDelete;

  /// Income: set up or change its pay.
  final ValueChanged<AccountInfo> onPay;

  /// "Assign what's planned": each category's new Assigned for the period.
  final void Function(BudgetSpan, Map<AccountInfo, int>) onAssignPlanned;

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

  /// The usage in Edit was picked: every row, all time.
  final ValueChanged<AccountInfo> onShowAllRows;
  final void Function(String name, bool income, Currency currency) onCreate;
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

  /// The category whose Assigned is being typed.
  int? _editing;

  /// The category open in Edit under its row.
  int? _open;

  /// Edit was opened from the plan's note: the cursor starts in its amount.
  bool _openAtPlan = false;

  BudgetSpan get _current =>
      budgetPeriod(widget.today, widget.data.periodSchedule);

  /// Esc reached the screen with Edit open (the click before it was
  /// outside the panel): it closes, as from inside. False with none open.
  bool closeEdit() {
    if (_open == null) return false;
    setState(() => _open = null);
    return true;
  }

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

    String money(int v, [Currency? c]) =>
        formatMoney(v, currency: c ?? budget.currency);
    // A plan's amounts, as its note says them: cents only when there are
    // some.
    String planMoney(int v, Currency c) => formatShort(v, currency: c);
    // Tugrik and dollar accounts both: a category says which it's in.
    final currencies = [
      for (final c in Currency.values)
        if (data.openAccounts.any((a) => a.currency == c)) c,
    ];
    final both = currencies.length > 1;

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

    void open(int? id, {bool atPlan = false}) {
      setState(() {
        _open = id;
        _openAtPlan = atPlan;
        if (id != null) _editing = null;
      });
      if (id == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onKeysBack();
        });
      }
    }

    final grow = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);

    Widget row(AccountInfo c, {required bool striped}) {
      final line = budget.lines[c.id];
      final planLine = c.isIncome ? null : line?.plan;
      final toAssign = c.isIncome ? 0 : line?.toAssign ?? 0;
      final currency = c.isIncome ? budget.currency : c.currency;
      final usage = data.categoryUsage[c.id];
      final row = _CategoryRow(
        key: ValueKey('category-${c.id}'),
        category: c,
        striped: striped,
        planNote: line == null || planLine == null
            ? null
            : _planNote(t, line, period, widget.today, currency),
        assignPlanned: toAssign == 0 ? null : planMoney(toAssign, currency),
        onAssignPlanned: () => widget.onSetAmount(c, period, planLine!.planned),
        open: _open == c.id,
        onOpen: () => open(c.id),
        onClose: () => open(null),
        onPlan: () => open(c.id, atPlan: true),
        onDelete: () => widget.onDelete(c),
        onPay: () => widget.onPay(c),
        flags: c.isIncome || line == null
            ? const []
            : _lineFlags(
                t,
                data,
                c,
                line,
                today: isCurrent,
                onAccounts: () => open(c.id),
                onRows: () => widget.onShowRows(c, period),
                onAllRows: () => widget.onShowAllRows(c),
              ),
        onShowRows: () => widget.onShowRows(c, period),
        payNote: c.isIncome ? _payNote(t, data, c) : null,
        cameIn: c.isIncome
            ? _cameIn(budget.cameIn[c.id], budget.currency)
            : null,
        line: c.isIncome ? null : line,
        fromBefore: carries && line != null && line.fromBefore != 0
            ? t.planFromBefore(money(line.fromBefore, currency))
            : null,
        currency: currency,
        editing: _editing == c.id,
        onEdit: () => edit(c.id),
        onAssign: (amount, {required bool next}) {
          if (amount != null && amount != (line?.assigned ?? 0)) {
            widget.onSetAmount(c, period, amount);
          }
          next ? editNext(c) : edit(null);
        },
      );
      // Edit opens under the row, which grows like a register row.
      return SmoothHeight(
        key: ValueKey('category-row-${c.id}'),
        duration: grow,
        child: _open != c.id
            ? row
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  row,
                  _CategoryEditor(
                    key: ValueKey('category-editor-${c.id}'),
                    category: c,
                    data: data,
                    period: period,
                    today: widget.today,
                    assigned: line?.assigned ?? 0,
                    holds: isCurrent ? line?.left ?? 0 : null,
                    currencies: currencies,
                    usage: usage == null ? null : _usageText(t, usage),
                    payNote: c.isIncome ? _payNote(t, data, c).text : null,
                    atPlan: _openAtPlan,
                    onShowAllRows: () => widget.onShowAllRows(c),
                    onPay: () => widget.onPay(c),
                    onArchive: () {
                      open(null);
                      widget.onArchive(c);
                    },
                    onCancel: () => open(null),
                    onSave: (e) {
                      open(null);
                      widget.onSave(c, e);
                    },
                  ),
                ],
              ),
      );
    }

    // One currency's top lines: its money not assigned, "Assign what's
    // planned" for its categories, and its rows not categorized.
    List<Widget> top(BudgetPool pool) {
      final c = pool.currency;
      // The first pool keeps the plain keys.
      final tag = c == budget.currency ? '' : '-${c.code}';
      final held = pool.money - pool.notAssigned;
      final line = pool.notAssigned > 0
          ? t.planNotAssigned(money(pool.notAssigned, c))
          : pool.notAssigned == 0
          ? t.planAllAssigned
          // Below zero with nothing held: cards owe more than there is,
          // and nothing was assigned that could be "too much".
          : held <= 0 && pool.money < 0
          ? t.planCardsOwe(money(-pool.money, c))
          : t.planAssignedOver(money(-pool.notAssigned, c));
      // What "Assign what's planned" would do: every plan's amount that
      // isn't assigned yet this period.
      final planned = {
        for (final x in spending)
          if (budget.lines[x.id] case final l?
              when x.currency == c && l.toAssign > 0)
            x: l.plan!.planned,
      };
      final plannedTotal = planned.keys.fold(
        0,
        (sum, x) => sum + budget.lines[x.id]!.toAssign,
      );
      // Said before it's done: it would take more than there is.
      final plannedOver =
          plannedTotal - (pool.notAssigned > 0 ? pool.notAssigned : 0);
      return [
        Tooltip(
          message: t.planNotAssignedTip(money(pool.money, c), money(held, c)),
          waitDuration: const Duration(milliseconds: 500),
          child: Text(
            // With two currencies, "everything is assigned" needs its own.
            both && pool.notAssigned == 0 ? t.planAllAssignedIn(c.shown) : line,
            key: ValueKey('not-assigned$tag'),
            style: onest(
              17,
              weight: 600,
              color: pool.notAssigned < 0 ? Mid.coral : Mid.ink,
              tabular: true,
            ),
          ),
        ),
        if (planned.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              BarButton(
                key: ValueKey('assign-planned$tag'),
                label: t.planFill(planned.length, planMoney(plannedTotal, c)),
                onTap: () {
                  setState(() => _editing = null);
                  widget.onAssignPlanned(period, planned);
                },
              ),
              if (plannedOver > 0)
                Text(
                  t.planFillOver(planMoney(plannedOver, c)),
                  key: ValueKey('assign-planned-over$tag'),
                  style: onest(13, color: Mid.coral, tabular: true),
                ),
            ],
          ),
        ],
        if (pool.uncategorizedRows > 0) ...[
          const SizedBox(height: 4),
          Hoverable(
            key: ValueKey('uncategorized-line$tag'),
            onTap: widget.onShowUncategorized,
            builder: (hover) => Text(
              t.planUncategorized(
                '${pool.uncategorizedRows}',
                pool.uncategorizedNet > 0
                    ? '+${money(pool.uncategorizedNet, c)}'
                    : money(pool.uncategorizedNet, c),
              ),
              style: onest(13, color: hover ? Mid.blue : Mid.gold),
            ),
          ),
        ],
      ];
    }

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
                    _open = null;
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
                    _open = null;
                    _period = nextBudgetPeriod(period, by);
                  }),
                ),
                if (!isCurrent) ...[
                  const SizedBox(width: 8),
                  Hoverable(
                    key: const ValueKey('period-today'),
                    onTap: () => setState(() {
                      _editing = null;
                      _open = null;
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
          for (final (n, pool) in budget.pools.indexed) ...[
            if (n > 0) const SizedBox(height: 10),
            ...top(pool),
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
                      currencies: currencies,
                      currency: budget.currency,
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
                                  currency: c.currency,
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
  String money(int v) => formatShort(
    v,
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

/// One category. A double-click opens it in Edit under the row; ⋯ or a
/// right-click has Edit and Delete.
class _CategoryRow extends StatefulWidget {
  const _CategoryRow({
    super.key,
    required this.category,
    required this.striped,
    required this.onShowRows,
    required this.currency,
    required this.editing,
    required this.onEdit,
    required this.onAssign,
    required this.open,
    required this.onOpen,
    required this.onClose,
    required this.onPlan,
    required this.onDelete,
    required this.onPay,
    this.payNote,
    this.line,
    this.cameIn,
    this.fromBefore,
    this.planNote,
    this.assignPlanned,
    this.onAssignPlanned,
    this.flags = const [],
  });
  final AccountInfo category;

  /// It's open in Edit under the row.
  final bool open;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onDelete;

  /// Income: the pay note was clicked.
  final VoidCallback onPay;

  /// Spending: more to say under the name (the accounts it's limited to,
  /// rows that couldn't be counted), each with what a click does.
  final List<_LineFlag> flags;

  /// Spending with a plan: what it says under the name (rule 27).
  final _PlanNote? planNote;

  /// "₮200,000" when the plan wants more assigned this period than is;
  /// clicking it assigns that.
  final String? assignPlanned;
  final VoidCallback? onAssignPlanned;

  /// The plan's note was clicked: Edit, at the plan.
  final VoidCallback onPlan;

  /// Every other row is tinted, as in the register: the name and its
  /// amounts sit a page apart.
  final bool striped;

  /// Spent was clicked: this period's rows.
  final VoidCallback onShowRows;

  /// Spending: Put in, Spent and Left for the period on screen.
  final EnvelopeLine? line;

  /// Income: what came in during the period, each currency on its own.
  final List<(Currency, int)>? cameIn;

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

  @override
  State<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<_CategoryRow> {
  final _menu = MenuController();
  bool _hover = false;
  DateTime? _lastTap;

  /// The second click of two close together opens Edit, as in the
  /// register; on the row that's open, it closes it.
  void _tap() {
    final now = DateTime.now();
    final last = _lastTap;
    _lastTap = now;
    if (last == null ||
        now.difference(last) >= const Duration(milliseconds: 450)) {
      return;
    }
    _lastTap = null;
    widget.open ? widget.onClose() : widget.onOpen();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = widget.category;
    return MenuAnchor(
      controller: _menu,
      style: _menuStyle,
      onOpen: () => setState(() {}),
      onClose: () {
        if (mounted) setState(() {});
      },
      menuChildren: _categoryMenu(
        t,
        onEdit: widget.onOpen,
        onDelete: widget.onDelete,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _tap,
          onSecondaryTapDown: (d) => _menu.open(position: d.localPosition),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical:
                  widget.fromBefore == null &&
                      widget.planNote == null &&
                      widget.flags.isEmpty &&
                      (widget.cameIn?.length ?? 0) < 2
                  ? 0
                  : 5,
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: onest(13.5)),
                      if (widget.planNote case final note?)
                        _PlanNoteLine(
                          id: c.id,
                          note: note,
                          assign: widget.assignPlanned,
                          onAssign: widget.onAssignPlanned,
                          onPlan: widget.onPlan,
                        ),
                      for (final (i, f) in widget.flags.indexed)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Hoverable(
                            key: ValueKey('line-flag-${c.id}-$i'),
                            onTap: f.onTap,
                            builder: (hover) => Text(
                              f.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: onest(12, color: f.color, tabular: true)
                                  .copyWith(
                                    decoration: hover
                                        ? TextDecoration.underline
                                        : null,
                                    decorationColor: f.color,
                                  ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.payNote case final note?) ...[
                  // Not Flexible: sharing the spare width with the name
                  // would leave the amount short of its column.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Hoverable(
                      key: ValueKey('pay-note-${c.id}'),
                      onTap: widget.onPay,
                      builder: (hover) => Text(
                        note.text,
                        style:
                            onest(
                              12.5,
                              color: note.nudge ? Mid.gold : Mid.ink2,
                            ).copyWith(
                              decoration: hover
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
                          builder: (hover) => Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final (currency, amount) in came)
                                Money(
                                  amount,
                                  size: 13.5,
                                  currency: currency,
                                  color: hover
                                      ? Mid.blue
                                      : (amount == 0 ? Mid.ink3 : Mid.ink2),
                                ),
                            ],
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

/// A category's menu: Edit, where everything about it is, and Delete.
List<Widget> _categoryMenu(
  Words t, {
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  Widget item(String label, String key, VoidCallback onTap, {Color? color}) =>
      MenuItemButton(
        key: ValueKey(key),
        onPressed: onTap,
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(160, 34)),
          overlayColor: WidgetStatePropertyAll(Mid.blueWash),
        ),
        child: Text(label, style: onest(13, color: color ?? Mid.ink2)),
      );
  return [
    item(t.planEdit, 'category-edit', onEdit),
    item(t.planDeleteMenu, 'category-delete', onDelete, color: Mid.coral),
  ];
}

/// Name and whether it's income. Income ends a forecast (payday).
class _NewCategory extends StatefulWidget {
  const _NewCategory({
    required this.onCreate,
    required this.onCancel,
    required this.currencies,
    required this.currency,
  });
  final void Function(String name, bool income, Currency currency) onCreate;
  final VoidCallback onCancel;

  /// The currencies there are accounts in. With both, a spending category
  /// is made in one of them, [currency] to begin with.
  final List<Currency> currencies;
  final Currency currency;

  @override
  State<_NewCategory> createState() => _NewCategoryState();
}

class _NewCategoryState extends State<_NewCategory> {
  final _name = TextEditingController();
  final _focus = FocusNode(debugLabel: 'new-category');
  bool _income = false;
  late Currency _currency = widget.currency;

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
    widget.onCreate(n, _income, _currency);
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
                if (!_income && widget.currencies.length > 1) ...[
                  const SizedBox(width: 18),
                  _CurrencyMenu(
                    buttonKey: 'new-category-currency',
                    itemPrefix: 'new-category-',
                    currencies: widget.currencies,
                    currency: _currency,
                    onPick: (c) => setState(() => _currency = c),
                  ),
                ],
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
      final amount = typed.isEmpty ? 0 : parseAmount(typed, widget.currency);
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
        : '${a < 0 ? '-' : ''}${typedAmount(a, widget.currency)}';
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
    final amount = typed.isEmpty ? 0 : parseAmount(typed, widget.currency);
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
              prefixText: widget.currency.prefix,
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

/// What a plan says under its category's name: the plan, then whether a
/// bill or goal has what it should ("on track", or "₮200,000 short" in
/// gold).
typedef _PlanNote = ({String text, String? state, bool behind});

_PlanNote _planNote(
  Words t,
  EnvelopeLine line,
  BudgetSpan period,
  DateTime today,
  Currency currency,
) {
  final p = line.plan!;
  String money(int v) => formatShort(v, currency: currency);
  String each(int v) => period.label == payPeriodLabel
      ? t.planEachPay(money(v))
      : t.planEachMonth(money(v));
  // This year's dates need no year; a goal for 2028 does.
  String date(DateTime d) =>
      d.year == today.year ? sayDate(t, d) : sayFullDate(t, d);
  final due = p.due ?? p.plan.due ?? p.plan.start;
  final goal = p.plan.kind == PlanKind.goal;
  // What went back is said once the period it went back in has begun;
  // looking ahead, it hasn't happened yet.
  final wentBack = p.wentBack > 0 && !period.start.isAfter(today);
  // A bill or goal names its part only while it wants one.
  final wants = p.each > 0 && p.planned > 0 && !(goal && p.done);
  final parts = switch (p.plan.kind) {
    PlanKind.spend => [
      each(p.each),
      if (wentBack)
        period.label == payPeriodLabel
            ? t.planWentBackPay(money(p.wentBack))
            : t.planWentBack(money(p.wentBack))
      else if (!p.plan.rollover)
        t.planNoCarry,
    ],
    PlanKind.saveUp => [each(p.each), t.planSavingUp],
    PlanKind.dueOn => [
      p.done
          ? t.planWasDue(money(p.plan.amount), date(due))
          : t.planDue(money(p.plan.amount), date(due)),
      if (wants) each(p.each),
    ],
    PlanKind.goal => [
      t.planBy(money(p.plan.amount), date(due)),
      if (wants) each(p.each),
    ],
  };
  final String? state;
  if (line.short > 0) {
    state = t.planShort(money(line.short));
  } else if (goal && p.done) {
    state = t.planReached;
  } else if (p.plan.kind == PlanKind.spend ||
      p.plan.kind == PlanKind.saveUp ||
      p.waiting ||
      p.done) {
    state = null;
  } else if (line.toAssign == 0 && p.held) {
    // Assigned, and still there: not spent on something else since.
    state = t.planOnTrack;
  } else {
    state = null;
  }
  return (text: parts.join(' · '), state: state, behind: line.short > 0);
}

/// The plan under a category's name. Clicking it opens Edit at the plan; "Assign
/// ₮200,000" at its end assigns what the plan wants this period.
class _PlanNoteLine extends StatelessWidget {
  const _PlanNoteLine({
    required this.id,
    required this.note,
    required this.assign,
    required this.onAssign,
    required this.onPlan,
  });
  final int id;
  final _PlanNote note;
  final String? assign;
  final VoidCallback? onAssign;
  final VoidCallback? onPlan;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Tooltip(
              message: t.planEditTip,
              waitDuration: const Duration(milliseconds: 600),
              child: Hoverable(
                key: ValueKey('plan-note-$id'),
                onTap: onPlan,
                builder: (hover) => Text(
                  note.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: onest(
                    12,
                    color: hover ? Mid.ink : Mid.ink2,
                    tabular: true,
                  ),
                ),
              ),
            ),
          ),
          if (note.state case final state?)
            Text(
              ' · $state',
              key: ValueKey('plan-state-$id'),
              style: onest(
                12,
                color: note.behind ? Mid.gold : Mid.ink2,
                tabular: true,
              ),
            ),
          if (assign case final amount?) ...[
            const SizedBox(width: 10),
            Hoverable(
              key: ValueKey('plan-assign-$id'),
              onTap: onAssign,
              builder: (hover) => Text(
                t.planAssignThis(amount),
                style: onest(12, color: Mid.blue, tabular: true).copyWith(
                  decoration: hover ? TextDecoration.underline : null,
                  decorationColor: Mid.blue,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A category's currency, picked from a list (owner, 2026-10-02: every
/// currency is to be supported, so a button each won't do).
class _CurrencyMenu extends StatefulWidget {
  const _CurrencyMenu({
    this.controller,
    required this.buttonKey,
    required this.itemPrefix,
    required this.currencies,
    required this.currency,
    required this.onPick,
  });
  final String buttonKey;

  /// The panel it's in closes it on Esc with this.
  final MenuController? controller;

  /// Each choice's key is this and its currency's code.
  final String itemPrefix;
  final List<Currency> currencies;
  final Currency currency;
  final ValueChanged<Currency> onPick;

  @override
  State<_CurrencyMenu> createState() => _CurrencyMenuState();
}

class _CurrencyMenuState extends State<_CurrencyMenu> {
  late final _menu = widget.controller ?? MenuController();
  final _search = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'currency-search');
  final _scroll = ScrollController();

  /// A list this long gets a search at its top.
  bool get _searchable => widget.currencies.length > 8;

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final q = _search.text.trim().toLowerCase();
    // The long list reads by name, which is what a row leads with; tugrik
    // and dollars, the two the app began with, stay first.
    final listed = !_searchable
        ? widget.currencies
        : [
            for (final c in widget.currencies)
              if (c == Currency.mnt || c == Currency.usd) c,
            ...[
              for (final c in widget.currencies)
                if (c != Currency.mnt && c != Currency.usd) c,
            ]..sort(
              (a, b) => currencyName(
                t,
                a,
              ).toLowerCase().compareTo(currencyName(t, b).toLowerCase()),
            ),
          ];
    final shown = [
      for (final c in listed)
        if (q.isEmpty ||
            c.code.toLowerCase().contains(q) ||
            c.symbol.toLowerCase() == q ||
            currencyName(t, c).toLowerCase().contains(q))
          c,
    ];
    void pick(Currency c) {
      widget.onPick(c);
      _menu.close();
    }

    Widget item(Currency c) => MenuItemButton(
      key: ValueKey('${widget.itemPrefix}${c.code}'),
      closeOnActivate: false,
      onPressed: () => pick(c),
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(260, 34)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        overlayColor: WidgetStatePropertyAll(Mid.blueWash),
      ),
      // Every row the same way: its symbol in a column at the start, its
      // name, its code at the end.
      leadingIcon: SizedBox(
        width: 48,
        child: Text(
          c.symbol,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: onest(13, color: c == widget.currency ? Mid.ink : Mid.ink2),
        ),
      ),
      trailingIcon: Text(c.code, style: onest(12, color: Mid.ink3)),
      child: Text(
        currencyName(t, c),
        style: onest(13, color: c == widget.currency ? Mid.ink : Mid.ink2),
      ),
    );

    return MenuAnchor(
      controller: _menu,
      style: _menuStyle,
      onOpen: () {
        setState(_search.clear);
        if (_searchable) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _searchFocus.requestFocus();
          });
        }
      },
      onClose: () {
        if (mounted) setState(() {});
      },
      menuChildren: !_searchable
          ? [for (final c in shown) item(c)]
          : [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                child: SizedBox(
                  width: 300,
                  height: 34,
                  child: TextField(
                    key: ValueKey('${widget.buttonKey}-search'),
                    controller: _search,
                    focusNode: _searchFocus,
                    style: onest(13.5),
                    onChanged: (_) => setState(() {}),
                    // Enter takes the first one left.
                    onSubmitted: (_) {
                      if (shown.isNotEmpty) pick(shown.first);
                    },
                    decoration: _fieldDecoration(hint: t.setupCurrencySearch),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                // Its own: the menu around it scrolls too.
                child: SingleChildScrollView(
                  controller: _scroll,
                  primary: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final c in shown) item(c),
                      if (shown.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            t.setupCurrencyNoMatch,
                            style: onest(13, color: Mid.ink3),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
      child: Align(
        alignment: Alignment.centerLeft,
        widthFactor: 1,
        child: BarButton(
          key: ValueKey(widget.buttonKey),
          label: currencyLabel(t, widget.currency),
          trailing: Icons.expand_more_rounded,
          active: _menu.isOpen,
          onTap: () => _menu.isOpen ? _menu.close() : _menu.open(),
        ),
      ),
    );
  }
}

/// One more thing a line says under its name, and what a click on it does.
typedef _LineFlag = ({String text, Color color, VoidCallback? onTap});

/// What came in under an income category: each currency that has any on
/// its own line, [main] alone when nothing came.
List<(Currency, int)> _cameIn(Map<Currency, int>? came, Currency main) {
  final lines = [
    for (final c in Currency.values)
      if ((came?[c] ?? 0) != 0) (c, came![c]!),
  ];
  return lines.isEmpty ? [(main, 0)] : lines;
}

/// The accounts in [currency] a category can use: cash, bank and cards
/// (owner, 2026-10-02: a bill planned for the Visa is the Visa's). Not a
/// mortgage or student loan.
Iterable<AccountInfo> _moneyAccounts(LedgerData data, Currency currency) =>
    data.openAccounts.where((a) => Budget.counts(a, currency));

/// What a spending line says about its money (rule 28): the accounts it's
/// kept in, when those hold less than is left in it ([today]: only in the
/// period today is in, since balances are today's), a payment from an
/// account it isn't kept in, and rows in the other currency.
List<_LineFlag> _lineFlags(
  Words t,
  LedgerData data,
  AccountInfo c,
  EnvelopeLine line, {
  required bool today,
  required VoidCallback onAccounts,
  required VoidCallback onRows,
  required VoidCallback onAllRows,
}) {
  String money(int v, [Currency? currency]) =>
      formatShort(v, currency: currency ?? c.currency);
  final off = data.accountsOff[c.id] ?? const <int>{};
  final mine = _moneyAccounts(data, c.currency).toList();
  final used = mine.where((a) => !off.contains(a.id)).toList();
  return [
    if (used.length < mine.length)
      (
        text: switch (used.length) {
          0 => t.planFromNone,
          1 => t.planOnlyFromOne(used.single.name),
          final n => t.planOnlyFromSome(n, mine.length),
        },
        color: Mid.ink2,
        onTap: onAccounts,
      ),
    if (line.backing case final b? when today)
      (
        text: b.categories > 1
            ? t.planBackingShared(
                money(b.setAside),
                b.categories,
                money(b.have),
              )
            : used.where((a) => !a.isOwed).length == 1
            ? t.planBackingOne(
                money(b.setAside),
                used.firstWhere((a) => !a.isOwed).name,
                money(b.have),
              )
            : t.planBackingSome(money(b.setAside), money(b.have)),
        color: Mid.coral,
        onTap: onAccounts,
      ),
    if (line.offSpent > 0)
      (
        text: line.offAccounts.length == 1
            ? t.planOffAccount(
                money(line.offSpent),
                data.accounts[line.offAccounts.single]?.name ?? '',
              )
            : t.planOffAccounts(money(line.offSpent), line.offAccounts.length),
        color: Mid.gold,
        onTap: onRows,
      ),
    if (line.otherCurrency case final other? when line.otherRows > 0)
      (
        text: t.planOtherRows(
          line.otherRows,
          money(line.otherAmount, other),
          c.currency.shown,
          other.shown,
        ),
        color: Mid.gold,
        onTap: onAllRows,
      ),
  ];
}

/// Everything about a category, opened under its row (rule 29): its name,
/// spending or income, and for spending its type (the plan, rule 27), its
/// currency and the accounts it uses (rule 28); for income, whether it's a
/// payday and its pay. Enter or Save keeps all of it in one step, Esc
/// cancels. A line says what the plan comes to before it's saved.
class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({
    super.key,
    required this.category,
    required this.data,
    required this.period,
    required this.today,
    required this.assigned,
    required this.holds,
    required this.currencies,
    required this.usage,
    required this.payNote,
    required this.atPlan,
    required this.onSave,
    required this.onCancel,
    required this.onArchive,
    required this.onShowAllRows,
    required this.onPay,
  });
  final AccountInfo category;
  final LedgerData data;
  final BudgetSpan period;
  final DateTime today;

  /// What it has assigned this period: where a new plan's amount starts.
  final int assigned;

  /// What the category has left today; null when another period is on
  /// screen, where today's balances would say nothing true.
  final int? holds;

  /// The currencies there are accounts in: the choice shows with both.
  final List<Currency> currencies;

  /// "42 rows · last 09.12 · 1 scheduled": picking it shows every row.
  final String? usage;

  /// Income: what its line says about pay.
  final String? payNote;

  /// Opened from the plan's note: the cursor starts in the plan's amount.
  final bool atPlan;
  final ValueChanged<_CategoryEdit> onSave;
  final VoidCallback onCancel;
  final VoidCallback onArchive;
  final VoidCallback onShowAllRows;
  final VoidCallback onPay;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  /// The gaps between bills offered, in months.
  static const _repeats = [1, 2, 3, 4, 6, 12, 24];

  late final _name = TextEditingController(text: widget.category.name);
  late final _amount = TextEditingController();
  late final _date = TextEditingController();
  final _nameFocus = FocusNode(debugLabel: 'category-name');
  final _amountFocus = FocusNode(debugLabel: 'plan-amount');
  final _dateFocus = FocusNode(debugLabel: 'plan-date');
  final _repeatMenu = MenuController();
  final _accountsMenu = MenuController();
  final _currencyMenu = MenuController();

  /// Closes a dropdown that's open in the panel: Esc and Enter are its
  /// own before they're the panel's.
  bool _closeMenu() {
    for (final m in [_repeatMenu, _accountsMenu, _currencyMenu]) {
      if (m.isOpen) {
        m.close();
        return true;
      }
    }
    return false;
  }

  /// Holds the keys while no field has them (a choice or an empty part of
  /// the panel was clicked), so Esc still closes and Enter still saves.
  final _panelFocus = FocusNode(debugLabel: 'category-editor');

  late bool _income = widget.category.isIncome;
  late bool _payday = widget.category.payday;
  late Currency _currency = widget.category.currency;
  late Set<int> _off = {..._savedOff};

  /// The plan's kind; null for a category with no plan.
  PlanKind? _kind;
  int? _every;
  bool _rollover = true;

  /// Save was tried with something missing: say which.
  bool _tried = false;

  /// Saved: Enter reaches both the field and the panel, and must save once.
  bool _done = false;

  /// Scrolls the panel into view once the row has grown: opened on a
  /// category low in the list, its Save would be under the window's edge.
  Timer? _reveal;

  Set<int> get _savedOff =>
      widget.data.accountsOff[widget.category.id] ?? const <int>{};
  CategoryPlan? get _savedPlan => widget.data.plans[widget.category.id];

  /// The saved plan while it still means something: in another currency
  /// its amounts don't, so the plan starts over there.
  CategoryPlan? get _plan =>
      _currency == widget.category.currency ? _savedPlan : null;

  @override
  void initState() {
    super.initState();
    _showPlan(_savedPlan);
    final atPlan = widget.atPlan && _kind != null;
    final first = atPlan ? _amount : _name;
    first.selection = TextSelection(
      baseOffset: 0,
      extentOffset: first.text.length,
    );
    // Asked for, not left to autofocus: the screen holds the keys when
    // Edit opens, and autofocus gives way to that.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) (atPlan ? _amountFocus : _nameFocus).requestFocus();
    });
    for (final f in [_nameFocus, _amountFocus, _dateFocus]) {
      f.addListener(_keepKeys);
    }
  }

  @override
  void didUpdateWidget(_CategoryEditor old) {
    super.didUpdateWidget(old);
    // Pay… set up its pay while Edit was open, which marks it a payday:
    // Save mustn't put back what was showing before.
    if (old.category.payday != widget.category.payday) {
      _payday = widget.category.payday;
    }
  }

  /// A field gave the keys up to nothing in particular: the panel takes
  /// them. Not when something else asked for them (another row's amount).
  void _keepKeys() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final has = FocusManager.instance.primaryFocus;
      if (has == null || has is FocusScopeNode) _panelFocus.requestFocus();
    });
  }

  /// What decides the panel's height, as of the last build.
  int? _shape;

  /// Once the row has grown (opened, or a choice that needs more room),
  /// scroll until Save is in view.
  void _revealSoon() {
    _reveal?.cancel();
    _reveal = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  void dispose() {
    _reveal?.cancel();
    _name.dispose();
    _amount.dispose();
    _date.dispose();
    _nameFocus.dispose();
    _amountFocus.dispose();
    _dateFocus.dispose();
    _panelFocus.dispose();
    super.dispose();
  }

  String _amountText(int a) => a <= 0 ? '' : typedAmount(a, _currency);

  /// Fills the plan's fields from [p], or empties them.
  void _showPlan(CategoryPlan? p) {
    _kind = p?.kind;
    _amount.text = _amountText(p?.amount ?? 0);
    _date.text = p?.due == null ? '' : fullDate(p!.due!);
    _every = p?.everyMonths;
    _rollover = p?.rollover ?? true;
  }

  void _pickKind(PlanKind? kind) {
    setState(() {
      _kind = kind;
      _tried = false;
      // A new plan starts from what's assigned this period.
      if (kind != null &&
          _amount.text.isEmpty &&
          _currency == widget.category.currency) {
        _amount.text = _amountText(widget.assigned);
      }
    });
    if (kind == null) return;
    _amount.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _amount.text.length,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _amountFocus.requestFocus();
    });
  }

  bool get _dated => _kind == PlanKind.dueOn || _kind == PlanKind.goal;

  int? get _typedAmount =>
      switch (parseAmount(_amount.text.trim(), _currency)) {
        final a? when a > 0 => a,
        _ => null,
      };

  /// A bill or goal is ahead: `03.15` typed in October is next March's,
  /// and a bill that repeats is its next time round (`10.10` typed on
  /// 10.15 for a monthly bill is 11.10).
  DateTime? get _typedDate {
    final text = _date.text.trim();
    var d = parseEntryDate(text, widget.today);
    // A year far off is a slip of the hand, not a date.
    if (d == null || d.year > widget.today.year + 100) return null;
    final pieces = text.split(RegExp(r'[.\-/]')).where((p) => p.isNotEmpty);
    if (pieces.length > 2 || !d.isBefore(widget.today)) return d;
    final every = _kind == PlanKind.dueOn ? _every : null;
    if (every == null) return DateTime(d.year + 1, d.month, d.day);
    final day = d.day;
    while (d!.isBefore(widget.today)) {
      final last = DateTime(d.year, d.month + every + 1, 0).day;
      d = DateTime(d.year, d.month + every, day < last ? day : last);
    }
    return d;
  }

  /// The plan as typed. Null with a kind picked means something is missing.
  CategoryPlan? get _draft {
    final kind = _kind;
    if (kind == null) return null;
    final amount = _typedAmount;
    final due = _dated ? _typedDate : null;
    if (amount == null || (_dated && due == null)) return null;
    final every = kind == PlanKind.dueOn ? _every : null;
    final old = _plan;
    final rollover = kind != PlanKind.spend || _rollover;
    // A bill's parts count from the day its plan was made, and a category
    // that doesn't carry over is emptied from that day on: only a plan
    // that's really the same keeps its day. One that already didn't
    // carry over keeps it through a new amount.
    final same =
        old != null &&
        old.kind == kind &&
        (kind == PlanKind.spend
            ? old.rollover == rollover && (!rollover || old.amount == amount)
            : old.amount == amount &&
                  old.due == due &&
                  old.everyMonths == every);
    return CategoryPlan(
      categoryId: widget.category.id,
      kind: kind,
      amount: amount,
      start: same ? old.start : widget.today,
      due: due,
      everyMonths: every,
      rollover: rollover,
    );
  }

  void _save() {
    if (_done) return;
    final c = widget.category;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _tried = true);
      _nameFocus.requestFocus();
      return;
    }
    final draft = _income ? null : _draft;
    if (!_income && _kind != null && draft == null) {
      setState(() => _tried = true);
      (_typedAmount == null ? _amountFocus : _dateFocus).requestFocus();
      return;
    }
    _done = true;
    // What doesn't apply to its kind is left as it was saved.
    widget.onSave((
      name: name,
      income: _income,
      currency: _income ? c.currency : _currency,
      off: _income ? _savedOff : _off,
      plan: _income ? _savedPlan : draft,
      payday: _income ? _payday : c.payday,
    ));
  }

  String _repeatLabel(Words t, int? months) => months == null
      ? t.planRepeatNone
      : months % 12 == 0
      ? t.planRepeatYears(months ~/ 12)
      : t.planRepeatMonths(months);

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: onest(12, color: Mid.ink2)),
  );

  Widget _labeled(String label, Widget child) => Padding(
    padding: const EdgeInsets.only(right: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [_label(label), child],
    ),
  );

  /// The plan: which type, then what that type needs.
  List<Widget> _planFields(Words t, {required bool byPay}) {
    final kind = _kind;
    final wrongAmount = _tried && _typedAmount == null;
    final wrongDate = _tried && _dated && _typedDate == null;
    return [
      _label(t.planEditType),
      Wrap(
        runSpacing: 6,
        children: [
          for (final (k, label) in [
            (null, t.planKindNone),
            (PlanKind.spend, byPay ? t.planKindSpendPay : t.planKindSpendMonth),
            (PlanKind.saveUp, t.planKindSaveUp),
            (PlanKind.dueOn, t.planKindDueOn),
            (PlanKind.goal, t.planKindGoal),
          ])
            _Choice(
              key: ValueKey('plan-kind-${k?.name ?? 'none'}'),
              label: label,
              on: kind == k,
              onTap: () => _pickKind(k),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Text(switch (kind) {
        null => t.planHelpNone,
        PlanKind.spend => byPay ? t.planHelpSpendPay : t.planHelpSpend,
        PlanKind.saveUp => byPay ? t.planHelpSaveUpPay : t.planHelpSaveUp,
        PlanKind.dueOn => t.planHelpDueOn,
        PlanKind.goal => byPay ? t.planHelpGoalPay : t.planHelpGoal,
      }, style: onest(12.5, color: Mid.ink2)),
      if (kind != null) ...[
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _labeled(
              switch (kind) {
                PlanKind.dueOn => t.planLabelBill,
                PlanKind.goal => t.planLabelGoal,
                _ => byPay ? t.planLabelEachPay : t.planLabelEachMonth,
              },
              SizedBox(
                width: 170,
                height: 34,
                child: TextField(
                  key: const ValueKey('plan-amount'),
                  controller: _amount,
                  focusNode: _amountFocus,
                  autofocus: widget.atPlan,
                  textAlign: TextAlign.right,
                  style: onest(13.5, tabular: true),
                  onSubmitted: (_) => _save(),
                  decoration: _fieldDecoration(wrong: wrongAmount).copyWith(
                    prefixText: _currency.prefix,
                    prefixStyle: onest(13.5, color: Mid.ink3),
                  ),
                ),
              ),
            ),
            if (_dated)
              _labeled(
                kind == PlanKind.goal ? t.planLabelBy : t.planLabelDue,
                SizedBox(
                  width: 130,
                  height: 34,
                  child: DateField(
                    key: const ValueKey('plan-date'),
                    controller: _date,
                    focusNode: _dateFocus,
                    today: widget.today,
                    small: true,
                    wanted: wrongDate,
                    onSubmitted: _save,
                    onPicked: () {},
                  ),
                ),
              ),
            if (kind == PlanKind.dueOn)
              _labeled(
                t.planLabelRepeats,
                SizedBox(
                  height: 34,
                  child: MenuAnchor(
                    controller: _repeatMenu,
                    style: _menuStyle,
                    menuChildren: [
                      for (final months in [null, ..._repeats])
                        MenuItemButton(
                          key: ValueKey('plan-repeat-${months ?? 0}'),
                          onPressed: () => setState(() => _every = months),
                          style: ButtonStyle(
                            minimumSize: const WidgetStatePropertyAll(
                              Size(180, 34),
                            ),
                            overlayColor: WidgetStatePropertyAll(Mid.blueWash),
                          ),
                          child: Text(
                            _repeatLabel(t, months),
                            style: onest(
                              13,
                              color: months == _every ? Mid.ink : Mid.ink2,
                            ),
                          ),
                        ),
                    ],
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: BarButton(
                        key: const ValueKey('plan-repeat'),
                        label: _repeatLabel(t, _every),
                        trailing: Icons.expand_more_rounded,
                        active: _repeatMenu.isOpen,
                        onTap: () => _repeatMenu.isOpen
                            ? _repeatMenu.close()
                            : _repeatMenu.open(),
                      ),
                    ),
                  ),
                ),
              ),
            if (kind == PlanKind.spend) ...[
              _Choice(
                key: const ValueKey('plan-carry-on'),
                label: t.planCarryOn,
                on: _rollover,
                onTap: () => setState(() => _rollover = true),
              ),
              _Choice(
                key: const ValueKey('plan-carry-off'),
                label: t.planCarryOff,
                on: !_rollover,
                onTap: () => setState(() => _rollover = false),
              ),
            ],
          ],
        ),
      ],
    ];
  }

  /// The currency, when there are accounts in more than one: before the
  /// type, whose amount is in it.
  List<Widget> _currencyChoice(Words t) {
    final c = widget.category;
    if (widget.currencies.length < 2 &&
        widget.currencies.contains(c.currency)) {
      return const [];
    }
    return [
      _labeled(
        t.planMoneyCurrency,
        SizedBox(
          height: 34,
          child: _CurrencyMenu(
            controller: _currencyMenu,
            buttonKey: 'money-currency',
            itemPrefix: 'money-currency-',
            currencies: [
              for (final x in Currency.values)
                if (widget.currencies.contains(x) || x == c.currency) x,
            ],
            currency: _currency,
            onPick: (x) {
              if (_currency == x) return;
              setState(() {
                _currency = x;
                _tried = false;
                // The accounts are another currency's now.
                _off = x == c.currency ? {..._savedOff} : {};
                // So would the plan's amount be: the type, date and
                // repeat stay, and the amount is typed again.
                if (x == c.currency) {
                  _showPlan(_savedPlan);
                } else {
                  _amount.clear();
                }
              });
              if (_kind != null) _amountFocus.requestFocus();
            },
          ),
        ),
      ),
    ];
  }

  /// The accounts in its currency, in a dropdown that stays open while
  /// they're checked and unchecked; the button says how many it uses.
  Widget _accountsChoice(Words t, List<AccountInfo> accounts) {
    final used = accounts.where((a) => !_off.contains(a.id)).toList();
    return _labeled(
      t.planMoneyAccounts,
      SizedBox(
        height: 34,
        child: MenuAnchor(
          controller: _accountsMenu,
          style: _menuStyle,
          onOpen: () => setState(() {}),
          onClose: () {
            if (mounted) setState(() {});
          },
          menuChildren: [
            for (final a in accounts)
              MenuItemButton(
                key: ValueKey('money-account-${a.id}'),
                closeOnActivate: false,
                onPressed: () => setState(
                  () =>
                      _off.contains(a.id) ? _off.remove(a.id) : _off.add(a.id),
                ),
                style: ButtonStyle(
                  minimumSize: const WidgetStatePropertyAll(Size(320, 34)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  overlayColor: WidgetStatePropertyAll(Mid.blueWash),
                ),
                leadingIcon: Icon(
                  _off.contains(a.id)
                      ? Icons.check_box_outline_blank_rounded
                      : Icons.check_box_rounded,
                  size: 18,
                  color: _off.contains(a.id) ? Mid.ink3 : Mid.blue,
                ),
                trailingIcon: Money(
                  widget.data.balanceOf(a.id),
                  size: 13,
                  currency: a.currency,
                  color: Mid.ink2,
                ),
                child: Text(
                  a.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: onest(
                    13,
                    color: _off.contains(a.id) ? Mid.ink2 : Mid.ink,
                  ),
                ),
              ),
          ],
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: BarButton(
              key: const ValueKey('money-accounts'),
              label: used.length == accounts.length
                  ? t.planAccountsAll
                  : switch (used.length) {
                      0 => t.planAccountsNone,
                      1 => used.single.name,
                      final n => t.planAccountsSome(n, accounts.length),
                    },
              trailing: Icons.expand_more_rounded,
              active: _accountsMenu.isOpen,
              onTap: () => _accountsMenu.isOpen
                  ? _accountsMenu.close()
                  : _accountsMenu.open(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = widget.category;
    final data = widget.data;
    final byPay = widget.period.label == payPeriodLabel;
    String say(int v) => formatShort(v, currency: _currency);

    return ListenableBuilder(
      listenable: Listenable.merge([_amount, _date]),
      builder: (context, _) {
        final draft = _income ? null : _draft;
        // What the line would say with this plan, before it's saved.
        String? preview;
        // What went back in earlier periods returns to the category when
        // it carries over again: said before it's saved.
        String? returns;
        // No plan, picked over a saved one, can bring money back too.
        final plans = draft != null || (_kind == null && _savedPlan != null);
        if (!_income && plans && !c.isIncome && _currency == c.currency) {
          final after = Budget.of(
            data.withPlan(c.id, draft),
            start: widget.period.start,
            end: widget.period.end,
            today: widget.today,
          );
          final line = after.lines[c.id];
          // In the category's own currency.
          int free(Budget b) =>
              b.pools
                  .where((p) => p.currency == _currency)
                  .firstOrNull
                  ?.notAssigned ??
              0;
          final back =
              free(
                Budget.of(
                  data,
                  start: widget.period.start,
                  end: widget.period.end,
                  today: widget.today,
                ),
              ) -
              free(after);
          if (back > 0) {
            returns = t.planReturns(
              formatMoney(back, currency: _currency),
              c.name,
            );
          }
          if (line?.plan != null) {
            final note = _planNote(
              t,
              line!,
              widget.period,
              widget.today,
              _currency,
            );
            preview = note.state == null
                ? note.text
                : '${note.text} · ${note.state}';
          }
        }

        final accounts = _moneyAccounts(data, _currency).toList();
        // In another currency its amounts and plan mean nothing: they go,
        // and the panel says so first.
        final assigned = data.budgetAmounts
            .where((b) => b.categoryId == c.id)
            .fold(0, (sum, b) => sum + b.amount);
        // A plan typed in the new currency takes the old one's place.
        final hasPlan = _savedPlan != null && draft == null;
        final loses =
            !_income && _currency != c.currency && (assigned != 0 || hasPlan);
        // What unchecking does and doesn't reserve, with the real amounts:
        // only what the category has left must be in the checked accounts.
        // Its money is kept in the checked cash and bank accounts; a card
        // holds none.
        final checked = accounts
            .where((a) => !a.isOwed && !_off.contains(a.id))
            .toList();
        final have = checked.fold(0, (sum, a) => sum + data.balanceOf(a.id));
        final holds = _currency == c.currency ? widget.holds : null;
        final rest =
            _income ||
                holds == null ||
                checked.isEmpty ||
                !accounts.any((a) => _off.contains(a.id)) ||
                holds < 0 ||
                have < holds
            ? null
            : checked.length == 1
            ? t.planMoneyRestOne(
                say(holds),
                checked.single.name,
                c.name,
                say(have - holds),
              )
            : t.planMoneyRestSome(say(holds), c.name, say(have - holds));
        // Made income, it holds no money: what it has left goes back.
        final goesBack = _income && !c.isIncome && (widget.holds ?? 0) != 0
            ? t.planMoneyBack(
                formatMoney(widget.holds!, currency: c.currency),
                c.name,
              )
            : null;

        // Opened low in the list, or grown by a choice, Save would be
        // under the window's edge.
        final shape = Object.hash(
          _income,
          _kind,
          accounts.length,
          preview != null,
          returns != null,
          rest != null,
          loses,
          goesBack != null,
        );
        if (shape != _shape) {
          _shape = shape;
          _revealSoon();
        }

        Widget warning(String text, String key, Color color) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            text,
            key: ValueKey(key),
            style: onest(12.5, color: color, tabular: true),
          ),
        );

        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (!_closeMenu()) widget.onCancel();
            },
            const SingleActivator(LogicalKeyboardKey.enter): () {
              if (!_closeMenu()) _save();
            },
          },
          child: Focus(
            focusNode: _panelFocus,
            skipTraversal: true,
            // A click on a choice in the panel leaves the cursor where
            // it is.
            child: TextFieldTapRegion(
              child: Container(
                margin: const EdgeInsets.fromLTRB(0, 2, 0, 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Mid.ground.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _labeled(
                                    t.planEditName,
                                    SizedBox(
                                      width: 220,
                                      height: 34,
                                      child: TextField(
                                        key: const ValueKey('edit-name'),
                                        controller: _name,
                                        focusNode: _nameFocus,
                                        autofocus:
                                            !(widget.atPlan && _kind != null),
                                        style: onest(13.5),
                                        onSubmitted: (_) => _save(),
                                        decoration: _fieldDecoration(
                                          wrong:
                                              _tried &&
                                              _name.text.trim().isEmpty,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 34,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (final income in [false, true])
                                          _Choice(
                                            key: ValueKey(
                                              'edit-kind-${income ? 'income' : 'spending'}',
                                            ),
                                            label: income
                                                ? t.planIncome
                                                : t.planSpending,
                                            on: _income == income,
                                            onTap: () => setState(
                                              () => _income = income,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (!_income) ...[
                                    ..._currencyChoice(t),
                                    _accountsChoice(t, accounts),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 14),
                              if (!_income)
                                ..._planFields(t, byPay: byPay)
                              else ...[
                                Row(
                                  children: [
                                    _Choice(
                                      key: const ValueKey('edit-payday-on'),
                                      label: t.planEditPaydayYes,
                                      on: _payday,
                                      onTap: () =>
                                          setState(() => _payday = true),
                                    ),
                                    _Choice(
                                      key: const ValueKey('edit-payday-off'),
                                      label: t.planUnmarkPayday,
                                      on: !_payday,
                                      onTap: () =>
                                          setState(() => _payday = false),
                                    ),
                                    // Its pay is set up once it's saved as
                                    // income.
                                    if (c.isIncome) ...[
                                      const SizedBox(width: 12),
                                      BarButton(
                                        key: const ValueKey('edit-pay'),
                                        label: t.planPayMenu,
                                        onTap: widget.onPay,
                                      ),
                                      if (widget.payNote case final note?) ...[
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            note,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: onest(12.5, color: Mid.ink2),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _payday
                                      ? t.planEditPaydayHelpYes
                                      : t.planEditPaydayHelpNo,
                                  key: const ValueKey('edit-payday-help'),
                                  style: onest(12.5, color: Mid.ink2),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (preview != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          preview,
                          key: const ValueKey('plan-preview'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: onest(12.5, color: Mid.ink, tabular: true),
                        ),
                      ),
                    if (returns != null)
                      warning(returns, 'plan-returns', Mid.gold),
                    if (rest != null) warning(rest, 'money-rest', Mid.ink2),
                    if (loses)
                      warning(
                        _moneyChange(t, c, assigned, hasPlan),
                        'money-change',
                        Mid.gold,
                      ),
                    if (goesBack != null)
                      warning(goesBack, 'edit-goes-back', Mid.gold),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // How much it's used decides keep, merge or archive.
                        if (widget.usage case final usage?)
                          Hoverable(
                            key: const ValueKey('edit-rows'),
                            onTap: widget.onShowAllRows,
                            builder: (hover) => Text(
                              t.planShowAllRows(usage),
                              style: onest(
                                12.5,
                                color: hover ? Mid.blue : Mid.ink2,
                                tabular: true,
                              ),
                            ),
                          ),
                        // Beside the usage, which is what decides it; apart
                        // from Cancel and Save.
                        if (widget.usage != null) const SizedBox(width: 10),
                        BarButton(
                          key: const ValueKey('edit-archive'),
                          label: t.planArchive,
                          onTap: widget.onArchive,
                        ),
                        const Spacer(),
                        BarButton(
                          key: const ValueKey('edit-cancel'),
                          label: t.planCancel,
                          onTap: widget.onCancel,
                        ),
                        _PrimaryButton(
                          key: const ValueKey('edit-save'),
                          label: t.planSave,
                          icon: Icons.check_rounded,
                          tooltip: 'Enter',
                          onTap: _save,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// What a change of currency takes from [c]: what's assigned to it, its
/// plan, or both.
String _moneyChange(Words t, AccountInfo c, int assigned, bool hasPlan) {
  final amount = formatMoney(assigned, currency: c.currency);
  return assigned == 0
      ? t.planMoneyChangePlan
      : hasPlan
      ? t.planMoneyChange(amount)
      : t.planMoneyChangeAmount(amount);
}
