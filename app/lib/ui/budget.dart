part of 'ledger_screen.dart';

// The Budget section: envelopes, each spending category reading Assigned ·
// Spent · Left for the period on screen, under the money not assigned yet
// (ADR 0004 rule 26), with its plan under its name (rule 27). Also the one
// place categories are added, renamed, archived and deleted (rule 22).

/// What can be done to a category, from ⋯ on its row or a right-click.
class _CategoryActions {
  const _CategoryActions({
    required this.rename,
    required this.changeKind,
    required this.archive,
    required this.delete,
    this.pay,
    this.togglePayday,
    this.plan,
    this.accounts,
    this.accountsLabel,
  });
  final ValueChanged<String> rename;
  final VoidCallback changeKind;
  final VoidCallback archive;
  final VoidCallback delete;

  /// Income only: set up or edit its pay, and mark it payday or not.
  final VoidCallback? pay;
  final VoidCallback? togglePayday;

  /// Spending only: open its plan (rule 27).
  final VoidCallback? plan;

  /// Spending only: open its currency and accounts (rule 28).
  final VoidCallback? accounts;
  final String? accountsLabel;
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
    required this.onSetPlan,
    required this.onAssignPlanned,
    required this.onSetMoney,
  });

  /// A category's currency and the accounts it doesn't use were saved.
  final void Function(AccountInfo, Currency, Set<int> off) onSetMoney;

  /// A category's plan was saved, or removed with null.
  final void Function(AccountInfo, CategoryPlan?) onSetPlan;

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

  /// The usage in the ⋯ menu was picked: every row, all time.
  final ValueChanged<AccountInfo> onShowAllRows;
  final _CategoryActions Function(AccountInfo) actionsFor;
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

  /// The category whose plan is open under its row.
  int? _planning;

  /// The category whose currency and accounts are open under its row.
  int? _accounts;

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

    String money(int v, [Currency? c]) =>
        formatMoney(v, currency: c ?? budget.currency);
    // A plan's amounts, as its note says them: cents only when there are
    // some.
    String planMoney(int v, Currency c) =>
        formatMoney(v, showCents: v % 100 != 0, currency: c);
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

    void plan(int? id, {bool accounts = false}) {
      setState(() {
        _planning = accounts ? null : id;
        _accounts = accounts ? id : null;
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
      void accounts() =>
          plan(_accounts == c.id ? null : c.id, accounts: _accounts != c.id);
      final row = _CategoryRow(
        key: ValueKey('category-${c.id}'),
        category: c,
        striped: striped,
        planNote: line == null || planLine == null
            ? null
            : _planNote(t, line, period, widget.today, currency),
        assignPlanned: toAssign == 0 ? null : planMoney(toAssign, currency),
        onAssignPlanned: () => widget.onSetAmount(c, period, planLine!.planned),
        onPlan: c.isIncome ? null : () => plan(_planning == c.id ? null : c.id),
        onAccounts: c.isIncome ? null : accounts,
        accountsLabel: both ? t.planMoneyMenuBoth : t.planMoneyMenu,
        flags: c.isIncome || line == null
            ? const []
            : _lineFlags(
                t,
                data,
                c,
                line,
                today: isCurrent,
                onAccounts: accounts,
                onRows: () => widget.onShowRows(c, period),
                onAllRows: () => widget.onShowAllRows(c),
              ),
        usage: data.categoryUsage[c.id],
        actions: widget.actionsFor(c),
        onShowAllRows: () => widget.onShowAllRows(c),
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
      // The plan opens under the row, which grows like a register row.
      return SmoothHeight(
        key: ValueKey('category-row-${c.id}'),
        duration: grow,
        child: _accounts == c.id
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  row,
                  _CategoryMoneyEditor(
                    key: ValueKey('money-editor-${c.id}'),
                    category: c,
                    data: data,
                    holds: isCurrent ? line?.left ?? 0 : null,
                    currencies: currencies,
                    onCancel: () => plan(null),
                    onSave: (currency, off) {
                      widget.onSetMoney(c, currency, off);
                      plan(null);
                    },
                  ),
                ],
              )
            : _planning != c.id
            ? row
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  row,
                  _PlanEditor(
                    key: ValueKey('plan-editor-${c.id}'),
                    category: c,
                    plan: data.plans[c.id],
                    data: data,
                    period: period,
                    today: widget.today,
                    assigned: line?.assigned ?? 0,
                    onCancel: () => plan(null),
                    onSave: (p) {
                      if (p != data.plans[c.id]) widget.onSetPlan(c, p);
                      plan(null);
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
            both && pool.notAssigned == 0
                ? t.planAllAssignedIn(c.symbol)
                : line,
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
                    _planning = null;
                    _accounts = null;
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
                    _planning = null;
                    _accounts = null;
                    _period = nextBudgetPeriod(period, by);
                  }),
                ),
                if (!isCurrent) ...[
                  const SizedBox(width: 8),
                  Hoverable(
                    key: const ValueKey('period-today'),
                    onTap: () => setState(() {
                      _editing = null;
                      _planning = null;
                      _accounts = null;
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
    this.planNote,
    this.assignPlanned,
    this.onAssignPlanned,
    this.onPlan,
    this.onAccounts,
    this.accountsLabel,
    this.flags = const [],
  });
  final AccountInfo category;

  /// Spending: opens or closes its currency and accounts under the row;
  /// [accountsLabel] is what the menu calls that.
  final VoidCallback? onAccounts;
  final String? accountsLabel;

  /// Spending: more to say under the name (the accounts it's limited to,
  /// rows that couldn't be counted), each with what a click does.
  final List<_LineFlag> flags;

  /// Spending with a plan: what it says under the name (rule 27).
  final _PlanNote? planNote;

  /// "₮200,000" when the plan wants more assigned this period than is;
  /// clicking it assigns that.
  final String? assignPlanned;
  final VoidCallback? onAssignPlanned;

  /// Spending: opens or closes its plan under the row.
  final VoidCallback? onPlan;

  /// Every other row is tinted, as in the register: the name and its
  /// amounts sit a page apart.
  final bool striped;

  /// Spent was clicked: this period's rows.
  final VoidCallback onShowRows;

  /// The usage in the menu was picked: every row.
  final VoidCallback onShowAllRows;

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
          plan: widget.onPlan,
          accounts: widget.onAccounts,
          accountsLabel: widget.accountsLabel,
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
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Tooltip(
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
                                    style:
                                        onest(
                                          12,
                                          color: f.color,
                                          tabular: true,
                                        ).copyWith(
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
    if (act.plan case final plan?) item(t.planPlanMenu, 'category-plan', plan),
    if (act.accounts case final accounts?)
      item(act.accountsLabel ?? t.planMoneyMenu, 'category-accounts', accounts),
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
                  for (final c in widget.currencies)
                    _Choice(
                      key: ValueKey('new-category-${c.code}'),
                      label: _currencyName(t, c),
                      on: _currency == c,
                      onTap: () => setState(() => _currency = c),
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
  String money(int v) =>
      formatMoney(v, showCents: v % 100 != 0, currency: currency);
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

/// The plan under a category's name. Clicking it opens the plan; "Assign
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

/// A category's plan, opened under its row (rule 27): which of the four
/// kinds it is, its amount, and for a bill or goal its date. Enter or Save
/// keeps it, Esc cancels. A line says what it comes to before it's saved.
class _PlanEditor extends StatefulWidget {
  const _PlanEditor({
    super.key,
    required this.category,
    required this.plan,
    required this.data,
    required this.period,
    required this.today,
    required this.assigned,
    required this.onSave,
    required this.onCancel,
  });
  final AccountInfo category;
  final CategoryPlan? plan;
  final LedgerData data;
  final BudgetSpan period;
  final DateTime today;

  /// What it has assigned this period: where a new plan's amount starts.
  final int assigned;

  /// The plan to keep, or null to remove it.
  final ValueChanged<CategoryPlan?> onSave;
  final VoidCallback onCancel;

  @override
  State<_PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<_PlanEditor> {
  /// The gaps between bills offered, in months.
  static const _repeats = [1, 2, 3, 4, 6, 12, 24];

  late PlanKind _kind = widget.plan?.kind ?? PlanKind.spend;
  late final _amount = TextEditingController(
    text: switch (widget.plan?.amount ?? widget.assigned) {
      <= 0 => '',
      final a =>
        '${formatWhole(a)}${formatCents(a) == '.00' ? '' : formatCents(a)}',
    },
  );
  late final _date = TextEditingController(
    text: widget.plan?.due == null ? '' : fullDate(widget.plan!.due!),
  );
  final _amountFocus = FocusNode(debugLabel: 'plan-amount');
  final _dateFocus = FocusNode(debugLabel: 'plan-date');
  final _repeatMenu = MenuController();
  late int? _every = widget.plan?.everyMonths;
  late bool _rollover = widget.plan?.rollover ?? true;

  /// Save was tried with something missing: say which.
  bool _tried = false;

  /// Scrolls the plan into view once the row has grown: opened on a
  /// category low in the list, its Save would be under the window's edge.
  Timer? _reveal;

  @override
  void initState() {
    super.initState();
    _amount.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _amount.text.length,
    );
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
    _amount.dispose();
    _date.dispose();
    _amountFocus.dispose();
    _dateFocus.dispose();
    super.dispose();
  }

  bool get _dated => _kind == PlanKind.dueOn || _kind == PlanKind.goal;

  int? get _typedAmount => switch (parseAmount(_amount.text.trim())) {
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

  CategoryPlan? get _draft {
    final amount = _typedAmount;
    final due = _dated ? _typedDate : null;
    if (amount == null || (_dated && due == null)) return null;
    final every = _kind == PlanKind.dueOn ? _every : null;
    final old = widget.plan;
    final rollover = _kind != PlanKind.spend || _rollover;
    // A bill's parts count from the day its plan was made, and a category
    // that doesn't carry over is emptied from that day on: only a plan
    // that's really the same keeps its day. One that already didn't
    // carry over keeps it through a new amount.
    final same =
        old != null &&
        old.kind == _kind &&
        (_kind == PlanKind.spend
            ? old.rollover == rollover && (!rollover || old.amount == amount)
            : old.amount == amount &&
                  old.due == due &&
                  old.everyMonths == every);
    return CategoryPlan(
      categoryId: widget.category.id,
      kind: _kind,
      amount: amount,
      start: same ? old.start : widget.today,
      due: due,
      everyMonths: every,
      rollover: rollover,
    );
  }

  void _save() {
    final draft = _draft;
    if (draft == null) {
      setState(() => _tried = true);
      (_typedAmount == null ? _amountFocus : _dateFocus).requestFocus();
      return;
    }
    widget.onSave(draft);
  }

  String _repeatLabel(Words t, int? months) => months == null
      ? t.planRepeatNone
      : months % 12 == 0
      ? t.planRepeatYears(months ~/ 12)
      : t.planRepeatMonths(months);

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final byPay = widget.period.label == payPeriodLabel;
    final currency = widget.category.currency;

    Widget labeled(String label, Widget child) => Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: onest(12, color: Mid.ink2)),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );

    return ListenableBuilder(
      listenable: Listenable.merge([_amount, _date]),
      builder: (context, _) {
        final draft = _draft;
        // What the line would say with this plan, before it's saved.
        String? preview;
        // What went back in earlier periods returns to the category when
        // it carries over again: said before it's saved.
        String? returns;
        if (draft != null) {
          final after = Budget.of(
            widget.data.withPlan(widget.category.id, draft),
            start: widget.period.start,
            end: widget.period.end,
            today: widget.today,
          );
          final line = after.lines[widget.category.id];
          // In the category's own currency.
          int free(Budget b) =>
              b.pools
                  .where((p) => p.currency == currency)
                  .firstOrNull
                  ?.notAssigned ??
              0;
          final back =
              free(
                Budget.of(
                  widget.data,
                  start: widget.period.start,
                  end: widget.period.end,
                  today: widget.today,
                ),
              ) -
              free(after);
          if (back > 0) {
            returns = t.planReturns(
              formatMoney(back, currency: currency),
              widget.category.name,
            );
          }
          if (line?.plan != null) {
            final note = _planNote(
              t,
              line!,
              widget.period,
              widget.today,
              currency,
            );
            preview = note.state == null
                ? note.text
                : '${note.text} · ${note.state}';
          }
        }
        final wrongAmount = _tried && _typedAmount == null;
        final wrongDate = _tried && _dated && _typedDate == null;
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): widget.onCancel,
          },
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
                Wrap(
                  runSpacing: 6,
                  children: [
                    for (final (kind, label) in [
                      (
                        PlanKind.spend,
                        byPay ? t.planKindSpendPay : t.planKindSpendMonth,
                      ),
                      (PlanKind.saveUp, t.planKindSaveUp),
                      (PlanKind.dueOn, t.planKindDueOn),
                      (PlanKind.goal, t.planKindGoal),
                    ])
                      _Choice(
                        key: ValueKey('plan-kind-${kind.name}'),
                        label: label,
                        on: _kind == kind,
                        onTap: () => setState(() {
                          _kind = kind;
                          _tried = false;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(switch (_kind) {
                  PlanKind.spend =>
                    byPay ? t.planHelpSpendPay : t.planHelpSpend,
                  PlanKind.saveUp =>
                    byPay ? t.planHelpSaveUpPay : t.planHelpSaveUp,
                  PlanKind.dueOn => t.planHelpDueOn,
                  PlanKind.goal => byPay ? t.planHelpGoalPay : t.planHelpGoal,
                }, style: onest(12.5, color: Mid.ink2)),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    labeled(
                      switch (_kind) {
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
                          autofocus: true,
                          textAlign: TextAlign.right,
                          style: onest(13.5, tabular: true),
                          onSubmitted: (_) => _save(),
                          decoration: _fieldDecoration(wrong: wrongAmount)
                              .copyWith(
                                prefixText: currency.symbol,
                                prefixStyle: onest(13.5, color: Mid.ink3),
                              ),
                        ),
                      ),
                    ),
                    if (_dated)
                      labeled(
                        _kind == PlanKind.goal ? t.planLabelBy : t.planLabelDue,
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
                    if (_kind == PlanKind.dueOn)
                      labeled(
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
                                  onPressed: () =>
                                      setState(() => _every = months),
                                  style: ButtonStyle(
                                    minimumSize: const WidgetStatePropertyAll(
                                      Size(180, 34),
                                    ),
                                    overlayColor: WidgetStatePropertyAll(
                                      Mid.blueWash,
                                    ),
                                  ),
                                  child: Text(
                                    _repeatLabel(t, months),
                                    style: onest(
                                      13,
                                      color: months == _every
                                          ? Mid.ink
                                          : Mid.ink2,
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
                    if (_kind == PlanKind.spend) ...[
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
                if (returns != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    returns,
                    key: const ValueKey('plan-returns'),
                    style: onest(12.5, color: Mid.gold, tabular: true),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        preview ?? '',
                        key: const ValueKey('plan-preview'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: onest(12.5, color: Mid.ink, tabular: true),
                      ),
                    ),
                    if (widget.plan != null)
                      BarButton(
                        key: const ValueKey('plan-remove'),
                        label: t.planRemove,
                        color: Mid.coral,
                        onTap: () => widget.onSave(null),
                      ),
                    BarButton(
                      key: const ValueKey('plan-cancel'),
                      label: t.planCancel,
                      onTap: widget.onCancel,
                    ),
                    _PrimaryButton(
                      key: const ValueKey('plan-save'),
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
        );
      },
    );
  }
}

String _currencyName(Words t, Currency c) =>
    c == Currency.usd ? t.setupCurrencyUsd : t.setupCurrencyMnt;

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

/// The cash and bank accounts in [currency]: where a category's money can
/// be kept. A card holds none.
Iterable<AccountInfo> _moneyAccounts(LedgerData data, Currency currency) => data
    .openAccounts
    .where((a) => a.type == AccountType.asset && Budget.counts(a, currency));

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
      formatMoney(v, showCents: v % 100 != 0, currency: currency ?? c.currency);
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
            : used.length == 1
            ? t.planBackingOne(
                money(b.setAside),
                used.single.name,
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
          c.currency.symbol,
          other.symbol,
        ),
        color: Mid.gold,
        onTap: onAllRows,
      ),
  ];
}

/// A category's currency and the accounts it uses, opened under its row
/// (rule 28). Every account in its currency is checked to begin with;
/// unchecking one keeps that account's money out of the category.
class _CategoryMoneyEditor extends StatefulWidget {
  const _CategoryMoneyEditor({
    super.key,
    required this.category,
    required this.data,
    required this.currencies,
    required this.holds,
    required this.onSave,
    required this.onCancel,
  });
  final AccountInfo category;
  final LedgerData data;

  /// What the category has left today; null when another period is on
  /// screen, where today's balances would say nothing true.
  final int? holds;

  /// The currencies there are accounts in: the choice shows with both.
  final List<Currency> currencies;
  final void Function(Currency currency, Set<int> off) onSave;
  final VoidCallback onCancel;

  @override
  State<_CategoryMoneyEditor> createState() => _CategoryMoneyEditorState();
}

class _CategoryMoneyEditorState extends State<_CategoryMoneyEditor> {
  late Currency _currency = widget.category.currency;
  late Set<int> _off = {...?widget.data.accountsOff[widget.category.id]};
  Timer? _reveal;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = widget.category;
    final data = widget.data;
    final accounts = _moneyAccounts(data, _currency).toList();
    // In another currency its amounts and plan mean nothing: they go,
    // and the panel says so first.
    final assigned = data.budgetAmounts
        .where((b) => b.categoryId == c.id)
        .fold(0, (sum, b) => sum + b.amount);
    final hasPlan = data.plans.containsKey(c.id);
    final loses = _currency != c.currency && (assigned != 0 || hasPlan);
    // What unchecking does and doesn't reserve, with the real amounts:
    // only what the category has left must be in the checked accounts.
    final checked = accounts.where((a) => !_off.contains(a.id)).toList();
    final have = checked.fold(0, (sum, a) => sum + data.balanceOf(a.id));
    final holds = _currency == c.currency ? widget.holds : null;
    String say(int v) =>
        formatMoney(v, showCents: v % 100 != 0, currency: _currency);
    final rest =
        holds == null ||
            checked.isEmpty ||
            checked.length == accounts.length ||
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
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: onest(12, color: Mid.ink2)),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onCancel,
        const SingleActivator(LogicalKeyboardKey.enter): () =>
            widget.onSave(_currency, _off),
      },
      child: Focus(
        autofocus: true,
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
              if (widget.currencies.length > 1 ||
                  !widget.currencies.contains(c.currency)) ...[
                label(t.planMoneyCurrency),
                Row(
                  children: [
                    for (final x in Currency.values)
                      if (widget.currencies.contains(x) || x == c.currency)
                        _Choice(
                          key: ValueKey('money-currency-${x.code}'),
                          label: _currencyName(t, x),
                          on: _currency == x,
                          onTap: () => setState(() {
                            if (_currency == x) return;
                            _currency = x;
                            // The accounts are another currency's now.
                            _off = x == c.currency
                                ? {...?data.accountsOff[c.id]}
                                : {};
                          }),
                        ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              label(t.planMoneyAccounts),
              for (final a in accounts)
                Hoverable(
                  key: ValueKey('money-account-${a.id}'),
                  onTap: () => setState(
                    () => _off.contains(a.id)
                        ? _off.remove(a.id)
                        : _off.add(a.id),
                  ),
                  builder: (hover) => Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: hover ? Mid.rowHover : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _off.contains(a.id)
                              ? Icons.check_box_outline_blank_rounded
                              : Icons.check_box_rounded,
                          size: 18,
                          color: _off.contains(a.id) ? Mid.ink3 : Mid.blue,
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 240,
                          child: Text(
                            a.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: onest(
                              13.5,
                              color: _off.contains(a.id) ? Mid.ink2 : Mid.ink,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Money(
                              data.balanceOf(a.id),
                              size: 13,
                              currency: a.currency,
                              color: Mid.ink2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (rest != null) ...[
                const SizedBox(height: 10),
                Text(
                  rest,
                  key: const ValueKey('money-rest'),
                  style: onest(12.5, color: Mid.ink2, tabular: true),
                ),
              ],
              if (loses) ...[
                const SizedBox(height: 10),
                Text(
                  _moneyChange(t, c, assigned, hasPlan),
                  key: const ValueKey('money-change'),
                  style: onest(12.5, color: Mid.gold, tabular: true),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  BarButton(
                    key: const ValueKey('money-cancel'),
                    label: t.planCancel,
                    onTap: widget.onCancel,
                  ),
                  _PrimaryButton(
                    key: const ValueKey('money-save'),
                    label: t.planSave,
                    icon: Icons.check_rounded,
                    tooltip: 'Enter',
                    onTap: () => widget.onSave(_currency, _off),
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
