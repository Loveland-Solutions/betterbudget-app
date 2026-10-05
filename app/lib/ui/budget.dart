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
  Currency currency,
  Set<int> off,
  CategoryPlan? plan,
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
    required this.onAskAgain,
    required this.onCreate,
    required this.onUnarchive,
    required this.onShowRows,
    required this.onShowAllRows,
    required this.onSetAmount,
    required this.onBudgetBy,
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

  /// Income tab: a pay's Edit, or Add pay (null).
  final ValueChanged<PaySchedule?> onPay;

  /// Income tab: "Ask me again" after "I don't have regular pay".
  final VoidCallback onAskAgain;

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

  /// Add category: the new category's id, or null when nothing was made
  /// (the name was taken). Edit opens under the new row.
  final Future<int?> Function(String name, Currency currency) onCreate;
  final ValueChanged<AccountInfo> onUnarchive;

  /// A Put in amount was typed for the period starting on the date.
  final void Function(AccountInfo, BudgetSpan, int) onSetAmount;

  /// The view dropdown: by month (null), or by a pay's periods.
  final ValueChanged<PaySchedule?> onBudgetBy;

  @override
  State<_BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<_BudgetPage> {
  bool _adding = false;
  bool _showArchived = false;

  /// Spending (the categories) or Income (the pay, and what came in):
  /// the owner's call, 2026-10-05, from Cynthia's notes.
  _BudgetTab _tab = _BudgetTab.spending;

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

  /// ⌘N: the add box for a category, or Add pay on the Income tab.
  void addNew() {
    if (_tab == _BudgetTab.income) {
      widget.onPay(null);
      return;
    }
    setState(() {
      _open = null;
      _editing = null;
      _adding = true;
    });
  }

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
    final income = data.income;
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

    // The panel's top row: the two tabs, and over the categories their
    // column heads. A gold dot on Income says pay wants attention (not set
    // up, or an estimate to update).
    Widget tabs() => Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 12, 6),
      child: Row(
        children: [
          _PageTab(
            key: const ValueKey('budget-tab-spending'),
            label: t.planSpending,
            active: _tab == _BudgetTab.spending,
            onTap: () => setState(() => _tab = _BudgetTab.spending),
          ),
          _PageTab(
            key: const ValueKey('budget-tab-income'),
            label: t.planIncomeTab,
            active: _tab == _BudgetTab.income,
            dot: _payNote(t, data).nudge,
            // The Spending list stays mounted under Income, so an Edit
            // open there keeps what was typed (code review, 2026-10-05).
            onTap: () => setState(() => _tab = _BudgetTab.income),
          ),
          const Spacer(),
          if (_tab == _BudgetTab.spending) ...[
            for (final h in [t.planAssigned, t.planSpent, t.planLeft])
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
        ],
      ),
    );

    // This period's pay, by currency: what the schedules expect in it,
    // and what has come (the paydays confirmed in the period, on their
    // account's side).
    final moneyIds = {for (final a in data.balanceSheetAccounts) a.id};
    final expectedPay = <Currency, int>{};
    for (final p in data.paySchedules) {
      final c = data.accounts[p.accountId]?.currency ?? Currency.mnt;
      var d = p.nextAfter(
        DateTime(period.start.year, period.start.month, period.start.day - 1),
      );
      for (var i = 0; i < 40 && !d.isAfter(period.end); i++) {
        expectedPay[c] = (expectedPay[c] ?? 0) + p.amountOn(d);
        d = p.nextAfter(d);
      }
    }
    final fromPay = <Currency, int>{};
    for (final x in data.txns) {
      if (x.scheduled || x.payScheduleId == null) continue;
      if (x.date.isBefore(period.start) || x.date.isAfter(period.end)) {
        continue;
      }
      for (final e in x.entries) {
        if (e.amount > 0 && moneyIds.contains(e.accountId)) {
          fromPay[e.currency] = (fromPay[e.currency] ?? 0) + e.amount;
        }
      }
    }

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
      final planLine = line?.plan;
      final toAssign = line?.toAssign ?? 0;
      final currency = c.currency;
      final usage = data.categoryUsage[c.id];
      final row = _CategoryRow(
        key: ValueKey('category-${c.id}'),
        category: c,
        striped: striped,
        planNote: line == null || planLine == null
            ? null
            : _planNote(
                t,
                line,
                period,
                widget.today,
                currency,
                payName: _ownPayName(t, data, planLine.plan),
                own: data.payScheduleById(planLine.plan.payScheduleId),
              ),
        assignPlanned: toAssign == 0 ? null : planMoney(toAssign, currency),
        onAssignPlanned: () => widget.onSetAmount(c, period, planLine!.planned),
        open: _open == c.id,
        onOpen: () => open(c.id),
        onClose: () => open(null),
        onPlan: () => open(c.id, atPlan: true),
        onDelete: () => widget.onDelete(c),
        flags: line == null
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
        line: line,
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
                    atPlan: _openAtPlan,
                    onShowAllRows: () => widget.onShowAllRows(c),
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

    // The key (ADR 0004 "The top pane", the owner's pick B, 2026-10-05):
    // what you have, less what's assigned, is what's free, one column per
    // currency, each note on the row it's about, so colour means state,
    // not position. The first-period offer is a strip in the same card.
    Widget keyCard() {
      final pools = budget.pools;
      String tagOf(Currency c) => c == budget.currency ? '' : '-${c.code}';
      // One pool's figures: have, assigned, free; and its states.
      final held = {for (final p in pools) p.currency: p.money - p.notAssigned};
      bool over(BudgetPool p) => p.notAssigned < 0;
      Widget figure(
        String key,
        int v,
        Currency c, {
        bool big = false,
        bool coral = false,
      }) => Text(
        money(v, c),
        key: ValueKey(key),
        textAlign: TextAlign.right,
        style: big
            ? onest(
                20,
                weight: 700,
                color: coral ? Mid.coral : Mid.ink,
                tabular: true,
              )
            : onest(
                14,
                weight: 500,
                color: coral ? Mid.coral : Mid.ink,
                tabular: true,
              ),
      );
      Widget label(String text, {bool big = false, bool coral = false}) => Text(
        text,
        style: big
            ? onest(14, weight: 500, color: coral ? Mid.coral : Mid.ink)
            : onest(13, color: Mid.ink3),
      );

      Widget row(
        Widget lab,
        List<Widget> figures,
        List<Widget> notes, {
        bool big = false,
      }) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 150, child: lab),
            // Wide enough for a tugrik sum with cents at the big size.
            for (final f in figures) ...[
              SizedBox(width: 200, child: f),
              const SizedBox(width: 28),
            ],
            Expanded(
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: notes,
              ),
            ),
          ],
        ),
      );
      // Notes on "You have": rows waiting in Not categorized (money in
      // accounts, already counted), and cards owing more than there is.
      final haveNotes = <Widget>[
        for (final p in pools) ...[
          if (p.uncategorizedRows > 0)
            Hoverable(
              key: ValueKey('uncategorized-line${tagOf(p.currency)}'),
              onTap: widget.onShowUncategorized,
              builder: (hover) => Text(
                p.uncategorizedNet == 0
                    ? t.planUncategorizedRows(p.uncategorizedRows)
                    : t.planUncategorizedMoney(
                        p.uncategorizedRows,
                        p.uncategorizedNet > 0
                            ? '+${money(p.uncategorizedNet, p.currency)}'
                            : money(p.uncategorizedNet, p.currency),
                      ),
                style: onest(13, color: hover ? Mid.blue : Mid.gold),
              ),
            ),
        ],
      ];
      // Notes on "Assigned": one click for everything planned, and what
      // that would overdraw, said before it's done.
      final assignedNotes = <Widget>[];
      for (final p in pools) {
        final c = p.currency, tag = tagOf(c);
        final planned = {
          for (final x in spending)
            if (budget.lines[x.id] case final l?
                when x.currency == c && l.toAssign > 0)
              x: l.plan!.planned,
        };
        if (planned.isEmpty) continue;
        final plannedTotal = planned.keys.fold(
          0,
          (sum, x) => sum + budget.lines[x.id]!.toAssign,
        );
        final plannedOver =
            plannedTotal - (p.notAssigned > 0 ? p.notAssigned : 0);
        assignedNotes.add(
          BarButton(
            key: ValueKey('assign-planned$tag'),
            label: t.planFill(planned.length, planMoney(plannedTotal, c)),
            onTap: () {
              setState(() => _editing = null);
              widget.onAssignPlanned(period, planned);
            },
          ),
        );
        if (plannedOver > 0) {
          assignedNotes.add(
            Text(
              t.planFillOver(planMoney(plannedOver, c)),
              key: ValueKey('assign-planned-over$tag'),
              style: onest(13, color: Mid.coral, tabular: true),
            ),
          );
        }
      }
      return Container(
        key: const ValueKey('budget-key'),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(
          color: Mid.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Mid.rule),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Names only what the ledger actually holds, the way two
            // currencies are told apart only when both are there.
            row(label(cashBankLabel(t, data)), [
              for (final p in pools)
                // Cash and bank only, so it can't go below zero and has no
                // coral state: what's owed is the Savings page's business.
                figure('you-have${tagOf(p.currency)}', p.money, p.currency),
            ], haveNotes),
            row(label(t.planKeyAssigned), [
              for (final p in pools)
                figure(
                  'assigned-sum${tagOf(p.currency)}',
                  held[p.currency]!,
                  p.currency,
                ),
            ], assignedNotes),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Container(height: 1, color: Mid.rule),
            ),
            row(
              label(t.planKeyNotAssigned, big: true),
              [
                for (final p in pools)
                  // Never below zero: with more assigned than there is,
                  // nothing is left unassigned, and the row under this one
                  // says how much too much (owner, 2026-10-06).
                  figure(
                    'not-assigned${tagOf(p.currency)}',
                    over(p) ? 0 : p.notAssigned,
                    p.currency,
                    big: true,
                  ),
              ],
              const [],
              big: true,
            ),
            // The one real warning, a row of its own, there only when a
            // currency is over; the others' columns stay empty.
            if (pools.any(over))
              row(
                label(t.planKeyOver, big: true, coral: true),
                [
                  for (final p in pools)
                    over(p)
                        ? figure(
                            'assigned-over${tagOf(p.currency)}',
                            -p.notAssigned,
                            p.currency,
                            big: true,
                            coral: true,
                          )
                        : const SizedBox(),
                ],
                const [],
                big: true,
              ),
            if (offerStart)
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
        ),
      );
    }

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
                // The title is the view's dropdown once there's pay
                // (ADR 0004 "The top pane"): Month, or a pay by name.
                _ViewChoice(
                  data: data,
                  by: by,
                  title: t.planPeriodTitle(
                    _spanName(t, period, widget.today),
                    shortDate(period.start),
                    shortDate(period.end),
                  ),
                  onPick: widget.onBudgetBy,
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
                // One button for the tab that's on: a category, or a pay.
                if (_tab == _BudgetTab.income)
                  _PrimaryButton(
                    key: const ValueKey('income-add-pay'),
                    label: data.paySchedules.isEmpty
                        ? t.setupAddYourPay
                        : t.setupAddOtherPay,
                    icon: Icons.add_rounded,
                    tooltip: t.setupAddPayTip,
                    onTap: () => widget.onPay(null),
                  )
                else
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
          keyCard(),
          const SizedBox(height: 12),
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
                  tabs(),
                  if (_tab == _BudgetTab.income)
                    _IncomeTab(
                      data: data,
                      cameIn: income == null
                          ? const []
                          : _cameIn(budget.cameIn[income.id], budget.currency),
                      fromPay: fromPay,
                      expectedPay: expectedPay,
                      onShowRows: income == null
                          ? null
                          : () => widget.onShowRows(income, period),
                      onPay: widget.onPay,
                      onAskAgain: widget.onAskAgain,
                    ),
                  Offstage(
                    offstage: _tab == _BudgetTab.income,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_adding)
                          _NewCategory(
                            // A category just made opens in Edit under its row,
                            // so what it's for is asked at once (owner's
                            // request, 2026-10-05); Esc or Cancel closes the box.
                            onCreate: widget.onCreate,
                            onCreated: (id) => setState(() {
                              _adding = false;
                              _editing = null;
                              _open = id;
                              _openAtPlan = true;
                            }),
                            currencies: currencies,
                            currency: budget.currency,
                            onCancel: () => setState(() => _adding = false),
                          ),
                        for (final (i, c) in spending.indexed)
                          row(c, striped: i.isOdd),
                        const SizedBox(height: 14),
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
                                    if (budget.lines[c.id]?.left
                                        case final left? when left != 0) ...[
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
                                      key: ValueKey(
                                        'unarchive-category-${c.id}',
                                      ),
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

enum _BudgetTab { spending, income }

/// A tab in the panel's top row, drawn like the register's.
class _PageTab extends StatelessWidget {
  const _PageTab({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.dot = false,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  /// Something on the tab wants attention: a small gold dot after it.
  final bool dot;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Hoverable(
      onTap: onTap,
      builder: (hover) => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? Mid.raised : (hover ? Mid.hover : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: onest(13, color: active ? Mid.ink : Mid.ink3)),
            if (dot) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Mid.gold,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// The Income tab (owner's call, 2026-10-05, from Cynthia's notes: pay
/// "in a highly visible place like the budget income tab, not the
/// settings menu"): this period's income, each currency on its own, with
/// how much of it came from pay; then one line per pay, as Settings used
/// to list them, each with Edit. Add pay is the page's top-right button.
class _IncomeTab extends StatelessWidget {
  const _IncomeTab({
    required this.data,
    required this.cameIn,
    required this.fromPay,
    required this.expectedPay,
    required this.onShowRows,
    required this.onPay,
    required this.onAskAgain,
  });
  final LedgerData data;
  final List<(Currency, int)> cameIn;

  /// This period's pay by currency: what has come, and what the
  /// schedules expect.
  final Map<Currency, int> fromPay;
  final Map<Currency, int> expectedPay;
  final VoidCallback? onShowRows;
  final ValueChanged<PaySchedule?> onPay;
  final VoidCallback onAskAgain;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final pays = data.paySchedules;
    String name(int id) {
      final a = data.accounts[id];
      if (a == null) return '';
      return a.deleted
          ? t.startDeletedAccount(a.name)
          : a.archived
          ? t.setupNameArchived(a.name)
          : a.name;
    }

    // "₮2,100,000 received of ₮4,200,000 expected this period" (the
    // owner's words, 2026-10-05), one per currency pay is set up in.
    final split = [
      for (final MapEntry(key: c, value: expected) in expectedPay.entries)
        t.planIncomeExpected(
          formatShort(fromPay[c] ?? 0, currency: c),
          formatShort(expected, currency: c),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Row(
            children: [
              Tooltip(
                message: t.planShowTheseRows,
                waitDuration: const Duration(milliseconds: 500),
                child: Hoverable(
                  key: const ValueKey('income-line'),
                  onTap: onShowRows ?? () {},
                  builder: (hover) => Text(
                    t.planIncomeLine(
                      cameIn.isEmpty
                          ? formatMoney(0, currency: mainCurrency(data))
                          : [
                              for (final (c, v) in cameIn)
                                formatMoney(v, currency: c),
                            ].join(' · '),
                    ),
                    style: onest(15, weight: 600, tabular: true).copyWith(
                      decoration: hover ? TextDecoration.underline : null,
                      decorationColor: Mid.ink,
                    ),
                  ),
                ),
              ),
              if (split.isNotEmpty) ...[
                const SizedBox(width: 14),
                Flexible(
                  child: Text(
                    split.join(' · '),
                    key: const ValueKey('income-expected'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: onest(13, color: Mid.ink3, tabular: true),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final (i, p) in pays.indexed)
          Builder(
            builder: (context) {
              final currency =
                  data.accounts[p.accountId]?.currency ?? Currency.mnt;
              final amounts = payAmounts(
                t,
                p,
                (v) => formatShort(v, currency: currency),
                dotted: true,
              );
              final next = data
                  .registerFor(p.accountId)
                  .scheduled
                  .where((r) => r.payScheduleId == p.id)
                  .firstOrNull
                  ?.date;
              final note = _payNoteOf(t, data, p, '');
              return Container(
                key: ValueKey('pay-row-${p.id}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: i.isOdd ? Mid.stripe : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            // Its name; else the payer; two with neither
                            // are told apart by the account (budget
                            // review, 2026-10-05).
                            payTitle(t, data, p),
                            style: onest(14.5, weight: 600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            next == null
                                ? t.planPayInto(amounts, name(p.accountId))
                                : t.planPayIntoNext(
                                    amounts,
                                    name(p.accountId),
                                    sayDate(t, next),
                                  ),
                            style: onest(12.5, color: Mid.ink3, tabular: true),
                          ),
                          if (note.nudge) ...[
                            const SizedBox(height: 2),
                            Text(
                              note.text,
                              key: ValueKey('pay-nudge-${p.id}'),
                              style: onest(
                                12.5,
                                color: Mid.gold,
                                tabular: true,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    BarButton(
                      key: ValueKey('edit-pay-${p.id}'),
                      label: t.setupEdit,
                      onTap: () => onPay(p),
                    ),
                  ],
                ),
              );
            },
          ),
        if (pays.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: data.prefs[noRegularPayKey] == '1'
                ? Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.setupSaidNoPay,
                          key: const ValueKey('income-no-pay'),
                          style: onest(13.5, color: Mid.ink2),
                        ),
                      ),
                      BarButton(
                        key: const ValueKey('income-ask-pay'),
                        label: t.setupAskAgain,
                        onTap: onAskAgain,
                      ),
                    ],
                  )
                : Text(
                    t.planPaydayNotSetUp,
                    key: const ValueKey('income-not-set-up'),
                    style: onest(13.5, color: Mid.gold),
                  ),
          ),
      ],
    );
  }
}

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

/// The period title ("This month · 10.01–10.31"), which is the view's
/// dropdown once there's pay: Month, or a pay by name (ADR 0004 "The top
/// pane"; one control, like the forecast's title). Picking one asks the
/// screen to view by it; the choice is kept in the ledger (one pay at most
/// has it). Without pay, the title alone.
class _ViewChoice extends StatefulWidget {
  const _ViewChoice({
    required this.data,
    required this.by,
    required this.title,
    required this.onPick,
  });
  final LedgerData data;
  final PaySchedule? by;
  final String title;
  final ValueChanged<PaySchedule?> onPick;

  @override
  State<_ViewChoice> createState() => _ViewChoiceState();
}

class _ViewChoiceState extends State<_ViewChoice> {
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final by = widget.by;
    final title = Text(
      widget.title,
      key: const ValueKey('period-title'),
      style: onest(14.5, weight: 500, color: Mid.ink2),
    );
    if (widget.data.paySchedules.isEmpty) return title;
    Widget item(String key, String label, bool on, VoidCallback onTap) =>
        MenuItemButton(
          key: ValueKey(key),
          onPressed: onTap,
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(180, 34)),
            overlayColor: WidgetStatePropertyAll(Mid.blueWash),
          ),
          child: Text(label, style: onest(13, color: on ? Mid.ink : Mid.ink2)),
        );
    return MenuAnchor(
      controller: _menu,
      style: _menuStyle,
      onOpen: () => setState(() {}),
      onClose: () {
        if (mounted) setState(() {});
      },
      menuChildren: [
        item(
          'budget-view-month',
          t.planViewMonth,
          by == null,
          () => widget.onPick(null),
        ),
        for (final p in widget.data.paySchedules)
          item(
            'budget-view-${p.id}',
            payTitle(t, widget.data, p),
            by?.id == p.id,
            () => widget.onPick(p),
          ),
      ],
      child: Tooltip(
        message: t.planViewTip,
        waitDuration: const Duration(milliseconds: 600),
        child: Hoverable(
          key: const ValueKey('budget-view'),
          onTap: () => _menu.isOpen ? _menu.close() : _menu.open(),
          builder: (hover) {
            final color = hover || _menu.isOpen ? Mid.ink : Mid.ink3;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                title,
                const SizedBox(width: 2),
                Icon(Icons.expand_more_rounded, size: 16, color: color),
              ],
            );
          },
        ),
      ),
    );
  }
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

/// What the Budget page says about pay, beside what came in: "Pay:
/// ₮2,100,000 or more on the 10th and 25th · next 09.25", or "Pay not set
/// up" (gold, until it is). With more than one pay it's about the one that
/// wants its estimate updated, else the one the budget's period follows,
/// else the one that comes next; a click opens that one.
({String text, bool nudge, PaySchedule? schedule}) _payNote(
  Words t,
  LedgerData data,
) {
  final pays = data.paySchedules;
  if (pays.isEmpty) {
    // Said once in the pay setup: no regular pay, so nothing to nag about.
    return data.prefs[noRegularPayKey] == '1'
        ? (text: t.planPaydayNoRegular, nudge: false, schedule: null)
        : (text: t.planPaydayNotSetUp, nudge: true, schedule: null);
  }
  final more = pays.length > 1 ? t.planMorePay(pays.length - 1) : '';
  DateTime? next(PaySchedule p) => data
      .registerFor(p.accountId)
      .scheduled
      .where((r) => r.payScheduleId == p.id)
      .firstOrNull
      ?.date;
  final far = DateTime(9999);
  final soonest = [...pays]
    ..sort((a, b) => (next(a) ?? far).compareTo(next(b) ?? far));
  final notes = {for (final p in pays) p.id: _payNoteOf(t, data, p, more)};
  final lead =
      pays.where((p) => notes[p.id]!.nudge).firstOrNull ??
      data.periodSchedule ??
      soonest.first;
  final note = notes[lead.id] ?? notes[soonest.first.id]!;
  return (text: note.text, nudge: note.nudge, schedule: lead);
}

/// What there is to say about one pay. It suggests updating the amount from
/// the schedule's own paychecks, and never changes it itself:
/// - pay that varies: only when even the lowest of the last six beat the
///   estimate by 5% (a floor is meant to be beaten; one thin month mustn't
///   leave it too high);
/// - pay that's the same: when the last two came in alike and off the plan
///   (a raise, a tax change, a cut), louder when it's less.
({String text, bool nudge}) _payNoteOf(
  Words t,
  LedgerData data,
  PaySchedule p,
  String more,
) {
  String money(int v) => formatShort(
    v,
    currency: data.accounts[p.accountId]?.currency ?? Currency.mnt,
  );
  // Each paycheck beside what was planned for its own day: split pay's
  // advance is measured against the advance, not the rest.
  final came = data
      .registerAll(categoryId: p.categoryId)
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
    this.line,
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

  /// More to say under the name (the accounts it's limited to,
  /// rows that couldn't be counted), each with what a click does.
  final List<_LineFlag> flags;

  /// With a plan: what it says under the name (rule 27).
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

  /// Assigned, Spent and Left for the period on screen.
  final EnvelopeLine? line;

  /// "₮500,000 from before", when the category carried money in.
  final String? fromBefore;
  final Currency currency;

  /// Its Put in is being typed.
  final bool editing;
  final VoidCallback onEdit;

  /// Typing Put in ended: the amount (null when nothing valid was typed or
  /// it was cancelled), and whether Tab asked for the next category.
  final void Function(int? amount, {required bool next}) onAssign;

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
                      widget.flags.isEmpty
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
                            // Wrapped, it stays against the right edge
                            // instead of running into Spent.
                            textAlign: TextAlign.end,
                            style: onest(11.5, color: Mid.ink3, tabular: true),
                          ),
                      ],
                    ),
                  ),
                ],
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

/// A new spending category: its name, and its currency when there's more
/// than one.
class _NewCategory extends StatefulWidget {
  const _NewCategory({
    required this.onCreate,
    required this.onCreated,
    required this.onCancel,
    required this.currencies,
    required this.currency,
  });
  final Future<int?> Function(String name, Currency currency) onCreate;

  /// The category was made: its id, for the Edit that opens under it.
  final ValueChanged<int> onCreated;
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
  late Currency _currency = widget.currency;

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final n = _name.text.trim();
    // Nothing typed: nothing to call it, so nothing is made.
    if (n.isEmpty) return widget.onCancel();
    final id = await widget.onCreate(n, _currency);
    if (!mounted) return;
    // Made: its Edit opens under its row. Not made (the name is taken):
    // the name stays selected, ready to be changed.
    if (id != null) return widget.onCreated(id);
    _name.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _name.text.length,
    );
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
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
                if (widget.currencies.length > 1) ...[
                  const SizedBox(width: 10),
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
    final targets = widget.targets;
    final lines = [
      if (n == 0)
        merging ? t.planNothingFiled : t.planOnlyDeletedFiled
      else if (scheduled == 0)
        t.planRowsFiled(n)
      else
        t.planRowsFiledScheduled(n, scheduled),
    ];
    // Into Income the rows count as money coming in, and a scheduled one
    // can end a forecast.
    final kindNote = into == null || !into.isIncome || n == 0
        ? null
        : scheduled == 0
        ? t.planIntoIncome(into.name)
        : t.planIntoIncomeScheduled(into.name);
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

  // A strip under the key's rows, inside the same card: the one thing
  // here that's a question, gone once answered.
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('start-offer'),
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.only(top: 12),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: Mid.rule)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: onest(13.5, color: Mid.ink2)),
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

/// The pay a set amount is per, by name, when there's more than one pay to
/// tell it from; null for a monthly one, or the only pay.
String? _ownPayName(Words t, LedgerData data, CategoryPlan plan) {
  if (plan.kind != PlanKind.each || plan.payScheduleId == null) return null;
  if (data.paySchedules.length < 2) return null;
  final pay = data.payScheduleById(plan.payScheduleId);
  return pay == null ? null : payTitle(t, data, pay);
}

/// What a plan says under its category's name: the plan, then whether a
/// dated one has what it should ("on track", or "₮200,000 short" in
/// gold).
typedef _PlanNote = ({String text, String? state, bool behind});

_PlanNote _planNote(
  Words t,
  EnvelopeLine line,
  BudgetSpan period,
  DateTime today,
  Currency currency, {
  String? payName,
  PaySchedule? own,
}) {
  final p = line.plan!;
  // The period on screen, and a set amount's own (its month or its pay,
  // named when there's more than one pay to tell apart).
  final byPay = period.label == payPeriodLabel;
  final ownPay = p.plan.kind == PlanKind.each
      ? p.plan.payScheduleId != null
      : byPay;
  String money(int v) => formatShort(v, currency: currency);
  // In the last period before a date, the part is the rest: "this month".
  String each(int v) => p.lastPeriod
      ? (byPay ? t.planThisPay(money(v)) : t.planThisMonth(money(v)))
      : !ownPay
      ? t.planEachMonth(money(v))
      : payName != null
      ? t.planEachPayOf(money(v), payName)
      : t.planEachPay(money(v));
  // This year's dates need no year; a date in 2028 does.
  String date(DateTime d) =>
      d.year == today.year ? sayDate(t, d) : sayFullDate(t, d);
  final due = p.due ?? p.plan.due ?? p.plan.start;
  final once = p.plan.kind == PlanKind.byDate && !p.plan.repeats;
  // What went back is said once the period it went back in has begun;
  // looking ahead, it hasn't happened yet.
  final wentBack = p.wentBack > 0 && !period.start.isAfter(today);
  // A dated plan names its part only while it wants one.
  final wants = p.each > 0 && p.planned > 0 && !(once && p.done);
  final cap = p.plan.rollover ? p.plan.upTo : null;
  final parts = switch (p.plan.kind) {
    PlanKind.each => [
      // Holding its cap, the line says so in place of the amount.
      if (cap != null && p.done)
        t.planSetAsideAmount(money(cap))
      else
        each(p.each),
      // Seen by another period than its own: its share of this one, by
      // days, said as about. More than one period's worth (the one before
      // was never filled, and the rest of it is in view) is said as what
      // that period still needs, plus what's toward the next (owner,
      // 2026-10-05: "₮600,000 each … · about ₮700,000 this …" read as a
      // contradiction).
      if (p.shares.length > 1 &&
          p.planned > p.each &&
          p.shares.first.amount > 0 &&
          own != null &&
          !(cap != null && p.done))
        ...() {
          final first = p.shares.first;
          final period = budgetPeriod(first.date, own);
          final rest = p.planned - first.amount;
          return [
            t.planStillFor(
              money(first.amount),
              date(period.start),
              date(period.end),
            ),
            if (rest > 0) t.planPlusNext(money(rest)),
          ];
        }()
      else if (p.approx && p.planned > 0 && !(cap != null && p.done))
        byPay
            ? t.planAboutThisPay(money(p.planned))
            : t.planAboutThisMonth(money(p.planned)),
      if (cap != null && !p.done) t.planUpTo(money(cap)),
      // Seen by its own period, "last month"; by another, the day.
      if (wentBack)
        ownPay != byPay && p.wentBackOn != null
            ? t.planWentBackOn(money(p.wentBack), date(p.wentBackOn!))
            : ownPay
            ? t.planWentBackPay(money(p.wentBack))
            : t.planWentBack(money(p.wentBack))
      else if (!p.plan.rollover)
        t.planNoCarry,
    ],
    PlanKind.byDate => [
      if (p.ended)
        t.planEnded(money(p.plan.amount), date(due))
      else if (!once)
        t.planDue(money(p.plan.amount), date(due))
      else if (p.done && due.isBefore(period.start))
        t.planWasDue(money(p.plan.amount), date(due))
      else
        t.planBy(money(p.plan.amount), date(due)),
      if (wants) each(p.each),
    ],
  };
  final String? state;
  if (line.short > 0) {
    state = t.planShort(money(line.short));
  } else if (once && p.done) {
    state = t.planSetAsideState;
  } else if (p.plan.kind == PlanKind.each || p.waiting || p.done) {
    state = null;
  } else if (line.toAssign == 0) {
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

/// What came in under Income: each currency that has any, [main] alone
/// when nothing came.
List<(Currency, int)> _cameIn(Map<Currency, int>? came, Currency main) {
  final lines = [
    for (final c in Currency.values)
      if ((came?[c] ?? 0) != 0) (c, came![c]!),
  ];
  return lines.isEmpty ? [(main, 0)] : lines;
}

/// The first row of the key card names where the money is: "Cash & bank"
/// only when the ledger holds both, otherwise whichever one it has (owner,
/// 2026-10-06: don't say cash unless one of the accounts is cash).
String cashBankLabel(Words t, LedgerData data) {
  var cash = false, bank = false;
  for (final a in data.openAccounts) {
    if (a.type != AccountType.asset) continue;
    if (a.isCash) {
      cash = true;
    } else {
      bank = true;
    }
  }
  // With neither, the row is ₮0 and "Cash & bank" is the fullest name for
  // what could go there.
  if (cash && !bank) return t.planKeyCash;
  if (bank && !cash) return t.planKeyBank;
  return t.planKeyCashBank;
}

/// The accounts in [currency] a category can use: cash, bank and credit
/// cards (owner, 2026-10-02: a bill planned for the Visa is the Visa's). Not
/// a mortgage or student loan. [Budget.spendable], not [Budget.counts]: the
/// latter is only where money sits, and a card holds none.
Iterable<AccountInfo> _categoryAccounts(LedgerData data, Currency currency) =>
    data.openAccounts.where((a) => Budget.spendable(a, currency));

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
  final mine = _categoryAccounts(data, c.currency).toList();
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
/// its currency and the accounts it uses (rule 28), and its type (the
/// plan, rule 27). Enter or Save keeps all of it in one step, Esc cancels.
/// A line says what the plan comes to before it's saved.
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
    required this.atPlan,
    required this.onSave,
    required this.onCancel,
    required this.onArchive,
    required this.onShowAllRows,
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

  /// Opened from the plan's note: the cursor starts in the plan's amount.
  final bool atPlan;
  final ValueChanged<_CategoryEdit> onSave;
  final VoidCallback onCancel;
  final VoidCallback onArchive;
  final VoidCallback onShowAllRows;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final _name = TextEditingController(text: widget.category.name);
  late final _amount = TextEditingController();
  late final _date = TextEditingController();
  late final _upTo = TextEditingController();
  late final _everyN = TextEditingController(text: '1');
  late final _dates = TextEditingController();
  late final _daysAfter = TextEditingController();
  late final _endDate = TextEditingController();
  late final _endCount = TextEditingController(text: '12');
  final _nameFocus = FocusNode(debugLabel: 'category-name');
  final _amountFocus = FocusNode(debugLabel: 'plan-amount');
  final _dateFocus = FocusNode(debugLabel: 'plan-date');
  final _upToFocus = FocusNode(debugLabel: 'plan-up-to');
  final _datesFocus = FocusNode(debugLabel: 'plan-dates');
  final _repeatMenu = MenuController();
  final _eachMenu = MenuController();

  /// A set amount's own period: per this pay's periods, or per month
  /// (null). Owner, 2026-10-05: each category says how it's budgeted.
  int? _eachPayId;
  final _unitMenu = MenuController();
  final _weekendMenu = MenuController();
  final _nthMenu = MenuController();
  final _nthWeekdayMenu = MenuController();
  final _accountsMenu = MenuController();
  final _currencyMenu = MenuController();

  /// Closes a dropdown that's open in the panel: Esc and Enter are its
  /// own before they're the panel's.
  bool _closeMenu() {
    for (final m in [
      _repeatMenu,
      _unitMenu,
      _weekendMenu,
      _nthMenu,
      _nthWeekdayMenu,
      _accountsMenu,
      _currencyMenu,
    ]) {
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

  late Currency _currency = widget.category.currency;
  late Set<int> _off = {..._savedOff};

  /// The one question: is there a due date? No: a set amount each period
  /// (or none, with the amount left empty). Yes: an amount by a date.
  bool _hasDate = false;

  /// How often it comes, as the question is asked: once, every so many
  /// days, weeks, months or years, on fixed dates each year, or every
  /// payday. [_custom] shows the number and unit for "Every…".
  _Repeat _repeat = _Repeat.once;
  bool _custom = false;
  _Unit _unit = _Unit.months;

  /// Custom… (owner, 2026-10-05, an Outlook-like block): every so many
  /// weeks on these weekdays (Monday 1); every so many months or years on
  /// the nth weekday instead of the day of the month; and when it ends.
  final Set<int> _weekdays = {};
  bool _nthOn = false;
  int _nth = 1;
  int _nthWeekday = 1;
  _Ends _ends = _Ends.never;
  int? _payScheduleId;
  PayWeekend _weekend = PayWeekend.keep;
  bool _rollover = true;

  /// The account a dated plan's bill is scheduled in: the one account the
  /// category is paid from, when it's narrowed to one. One control says
  /// both (owner, 2026-10-05: "two account selectors: just have one").
  int? get _paidFromNow {
    if (!_dated) return null;
    final used = _categoryAccounts(
      widget.data,
      _currency,
    ).where((a) => !_off.contains(a.id)).toList();
    if (used.length == 1) return used.single.id;
    // A plan saved with an account (before this row, or one since
    // archived) keeps it while the checks aren't touched: nothing is
    // rewritten behind the user's back (code review, 2026-10-05).
    final saved = _plan?.paidFrom;
    if (saved != null && !_off.contains(saved) && setEquals(_off, _savedOff)) {
      return saved;
    }
    return null;
  }

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
    final atPlan = widget.atPlan;
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
    for (final f in [
      _nameFocus,
      _amountFocus,
      _dateFocus,
      _upToFocus,
      _datesFocus,
    ]) {
      f.addListener(_keepKeys);
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
    _upTo.dispose();
    _everyN.dispose();
    _dates.dispose();
    _daysAfter.dispose();
    _endDate.dispose();
    _endCount.dispose();
    _nameFocus.dispose();
    _amountFocus.dispose();
    _dateFocus.dispose();
    _upToFocus.dispose();
    _datesFocus.dispose();
    _panelFocus.dispose();
    super.dispose();
  }

  String _amountText(int a) => a <= 0 ? '' : typedAmount(a, _currency);

  /// Fills the plan's fields from [p], or empties them.
  void _showPlan(CategoryPlan? p) {
    _hasDate = p?.kind == PlanKind.byDate;
    _amount.text = _amountText(p?.amount ?? 0);
    _date.text = p?.due == null ? '' : fullDate(p!.due!);
    _custom = false;
    _weekend = p?.weekend ?? PayWeekend.keep;
    _payScheduleId = p?.kind == PlanKind.byDate ? p?.payScheduleId : null;
    // A set amount's own period: its own, or for a new one the period on
    // screen (budget review, 2026-10-05: made while viewing by a pay, it
    // shouldn't start as "each month · about ₮93,300 this pay period").
    _eachPayId = p?.kind == PlanKind.each
        ? p?.payScheduleId
        : widget.data.periodSchedule?.id;
    final after = p?.daysAfterPay ?? 0;
    _daysAfter.text = after == 0 ? '' : '$after';
    _dates.text = p?.onDates == null
        ? ''
        : [for (final (m, d) in p!.onDates!) _monthDay(m, d)].join(', ');
    var n = 1;
    if (p?.payScheduleId != null) {
      _repeat = _Repeat.payday;
    } else if (p?.onDates != null) {
      _repeat = _Repeat.dates;
    } else if (p?.everyDays case final days?) {
      _repeat = _Repeat.every;
      _unit = days % 7 == 0 ? _Unit.weeks : _Unit.days;
      n = days % 7 == 0 ? days ~/ 7 : days;
      _custom = days != 7 && days != 14;
    } else if (p?.everyMonths case final months?) {
      _repeat = _Repeat.every;
      _unit = months % 12 == 0 ? _Unit.years : _Unit.months;
      n = months % 12 == 0 ? months ~/ 12 : months;
      _custom = months != 1 && months != 3 && months != 12;
    } else {
      _repeat = _Repeat.once;
      _unit = _Unit.months;
    }
    _everyN.text = '$n';
    // Custom…'s own answers: any of them makes the repeat a custom one.
    _weekdays
      ..clear()
      ..addAll(p?.weekdays ?? const []);
    _nthOn = p?.nth != null;
    _nth = p?.nth ?? 1;
    _nthWeekday = p?.nthWeekday ?? 1;
    _ends = p?.endCount != null
        ? _Ends.count
        : p?.endDate != null
        ? _Ends.date
        : _Ends.never;
    _endDate.text = p?.endDate == null ? '' : fullDate(p!.endDate!);
    _endCount.text = '${p?.endCount ?? 12}';
    // A pattern makes it Custom…; an end alone doesn't, since Ends shows
    // under every repeat.
    if (p != null && (p.weekdays != null || p.nth != null)) _custom = true;
    _rollover = p?.rollover ?? true;
    _upTo.text = _amountText(p?.upTo ?? 0);
  }

  void _pickDated(bool yes) {
    setState(() {
      _hasDate = yes;
      _tried = false;
    });
    _amount.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _amount.text.length,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _amountFocus.requestFocus();
    });
  }

  bool get _dated => _hasDate;

  /// The plan the answers add up to: dated, a set amount, or none when
  /// the amount is left empty.
  PlanKind? get _kindNow => _hasDate
      ? PlanKind.byDate
      : _amount.text.trim().isEmpty
      ? null
      : PlanKind.each;

  int? get _typedAmount =>
      switch (parseAmount(_amount.text.trim(), _currency)) {
        final a? when a > 0 => a,
        _ => null,
      };

  /// The cap, when one is typed; empty is no cap.
  int? get _typedUpTo => switch (parseAmount(_upTo.text.trim(), _currency)) {
    final a? when a > 0 => a,
    _ => null,
  };

  /// Something is in the cap's field that isn't an amount.
  bool get _wrongUpTo => _upTo.text.trim().isNotEmpty && _typedUpTo == null;

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
    final months = _dated ? _everyMonthsNow : null;
    final days = _dated ? _everyDaysNow : null;
    if (months == null && days == null) {
      return DateTime(d.year + 1, d.month, d.day);
    }
    final day = d.day;
    while (d!.isBefore(widget.today)) {
      if (days != null) {
        d = DateTime(d.year, d.month, d.day + days);
      } else {
        final last = DateTime(d.year, d.month + months! + 1, 0).day;
        d = DateTime(d.year, d.month + months, day < last ? day : last);
      }
    }
    return d;
  }

  static String _monthDay(int m, int d) =>
      '${m.toString().padLeft(2, '0')}.${d.toString().padLeft(2, '0')}';

  /// The number typed after "Every"; null when it isn't one.
  int? get _typedEveryN => switch (int.tryParse(_everyN.text.trim())) {
    final n? when n > 0 && n < 1000 => n,
    _ => null,
  };

  /// Every so many months, when that's how it repeats.
  int? get _everyMonthsNow {
    if (_repeat != _Repeat.every) return null;
    final n = _typedEveryN;
    return switch (_unit) {
      _Unit.months => n,
      _Unit.years => n == null ? null : n * 12,
      _ => null,
    };
  }

  /// Every so many days, when that's how it repeats.
  int? get _everyDaysNow {
    if (_repeat != _Repeat.every) return null;
    final n = _typedEveryN;
    return switch (_unit) {
      _Unit.days => n,
      _Unit.weeks => n == null ? null : n * 7,
      _ => null,
    };
  }

  /// Custom… is on: its block shows, and its answers count.
  bool get _customOn => _repeat == _Repeat.every && _custom;

  /// The weekdays picked, every so many weeks; null for the date's own.
  List<int>? get _weekdaysNow =>
      _customOn && _unit == _Unit.weeks && _weekdays.isNotEmpty
      ? ([..._weekdays]..sort())
      : null;

  /// On the nth weekday of the month, every so many months or years.
  bool get _nthNow =>
      _customOn && (_unit == _Unit.months || _unit == _Unit.years) && _nthOn;

  DateTime? get _typedEndDate {
    final d = parseEntryDate(_endDate.text.trim(), widget.today);
    if (d == null || d.year > widget.today.year + 100) return null;
    return d;
  }

  int? get _typedEndCount => switch (int.tryParse(_endCount.text.trim())) {
    final n? when n > 0 && n < 1000 => n,
    _ => null,
  };

  /// Ends applies to any repeat typed as every so many (a preset or
  /// Custom…): "Every month, 12 times" is an installment plan (budget
  /// review, 2026-10-05).
  bool get _endsOn => _repeat == _Repeat.every;
  DateTime? get _endDateNow =>
      _endsOn && _ends == _Ends.date ? _typedEndDate : null;
  int? get _endCountNow =>
      _endsOn && _ends == _Ends.count ? _typedEndCount : null;

  /// The dates typed for "On these dates", as (month, day); null when
  /// one of them isn't a date.
  List<(int, int)>? get _typedDates {
    final pieces = _dates.text
        .split(RegExp(r'[,;\s]+'))
        .where((x) => x.isNotEmpty)
        .toList();
    final out = <(int, int)>[];
    for (final piece in pieces) {
      final d = parseEntryDate(piece, widget.today);
      if (d == null) return null;
      out.add((d.month, d.day));
    }
    return out;
  }

  /// The first of the typed dates from today on.
  DateTime? _firstOfDates(List<(int, int)> dates) {
    DateTime? first;
    for (final (m, d) in dates) {
      var on = DateTime(widget.today.year, m, d);
      if (on.isBefore(widget.today)) on = DateTime(widget.today.year + 1, m, d);
      if (first == null || on.isBefore(first)) first = on;
    }
    return first;
  }

  int get _daysAfterNow => switch (int.tryParse(_daysAfter.text.trim())) {
    final n? when n > 0 && n < 100 => n,
    _ => 0,
  };

  /// The plan as typed. Null with a kind picked means something is missing.
  CategoryPlan? get _draft {
    final kind = _kindNow;
    if (kind == null) return null;
    final amount = _typedAmount;
    if (amount == null) return null;
    final old = _plan;
    final rollover = kind != PlanKind.each || _rollover;
    if (kind == PlanKind.each && rollover && _wrongUpTo) return null;
    final upTo = kind == PlanKind.each && rollover ? _typedUpTo : null;
    // How it comes again, and from when.
    DateTime? due;
    List<(int, int)>? dates;
    int? payId;
    if (_dated) {
      switch (_repeat) {
        case _Repeat.payday:
          payId = _payScheduleId;
          if (payId == null) return null;
        case _Repeat.dates:
          dates = _typedDates;
          if (dates == null || dates.isEmpty) return null;
          due = _firstOfDates(dates);
        case _Repeat.every:
          if (_typedEveryN == null) return null;
          due = _typedDate;
          if (due == null) return null;
          if (_ends == _Ends.date && _typedEndDate == null) return null;
          if (_ends == _Ends.count && _typedEndCount == null) return null;
        case _Repeat.once:
          due = _typedDate;
          if (due == null) return null;
      }
    }
    CategoryPlan make(DateTime start) => CategoryPlan(
      categoryId: widget.category.id,
      kind: kind,
      amount: amount,
      start: start,
      due: due,
      everyMonths: _dated ? _everyMonthsNow : null,
      everyDays: _dated ? _everyDaysNow : null,
      onDates: dates,
      payScheduleId: _dated ? payId : _eachPayId,
      daysAfterPay: payId == null ? 0 : _daysAfterNow,
      // Chosen weekdays are the days; a weekend rule would move a
      // Saturday onto Friday's bill (code review).
      weekend:
          _dated &&
              _repeat != _Repeat.once &&
              payId == null &&
              _weekdaysNow == null
          ? _weekend
          : PayWeekend.keep,
      weekdays: _dated ? _weekdaysNow : null,
      nth: _dated && _nthNow ? _nth : null,
      nthWeekday: _dated && _nthNow ? _nthWeekday : null,
      endDate: _dated ? _endDateNow : null,
      endCount: _dated ? _endCountNow : null,
      rollover: rollover,
      upTo: upTo,
      paidFrom: _paidFromNow,
    );
    final fresh = make(widget.today);
    // A dated plan's parts count from the day it was made, and a category
    // that doesn't carry over is emptied from that day on: only a plan
    // that's really the same keeps its day. One that already didn't
    // carry over keeps it through a new amount; a cap or the account a
    // bill is paid from changes nothing about the count.
    final same =
        old != null &&
        old.kind == kind &&
        (kind == PlanKind.each
            ? old.rollover == rollover &&
                  old.payScheduleId == _eachPayId &&
                  (!rollover || old.amount == amount)
            : old.amount == amount && old.sameRepeat(fresh));
    return same ? make(old.start) : fresh;
  }

  void _save() {
    if (_done) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _tried = true);
      _nameFocus.requestFocus();
      return;
    }
    final draft = _draft;
    if (_kindNow != null && draft == null) {
      setState(() => _tried = true);
      (_typedAmount == null
              ? _amountFocus
              : !_dated
              ? _upToFocus
              : _repeat == _Repeat.dates
              ? _datesFocus
              : _dateFocus)
          .requestFocus();
      return;
    }
    _done = true;
    widget.onSave((name: name, currency: _currency, off: _off, plan: draft));
  }

  String _everyLabel(Words t, int n, _Unit unit) => switch (unit) {
    _Unit.days => t.planRepeatDays(n),
    _Unit.weeks => t.planRepeatWeeks(n),
    _Unit.months => t.planRepeatMonths(n),
    _Unit.years => t.planRepeatYears(n),
  };

  String _unitLabel(Words t, _Unit unit) => switch (unit) {
    _Unit.days => t.planUnitDays,
    _Unit.weeks => t.planUnitWeeks,
    _Unit.months => t.planUnitMonths,
    _Unit.years => t.planUnitYears,
  };

  String _weekendLabel(Words t, PayWeekend w) => switch (w) {
    PayWeekend.keep => t.planWeekendKeep,
    PayWeekend.before => t.planWeekendBefore,
    PayWeekend.after => t.planWeekendAfter,
  };

  /// "first" … "fourth", or "last" (-1).
  String _nthLabel(Words t, int n) => switch (n) {
    1 => t.planNthFirst,
    2 => t.planNthSecond,
    3 => t.planNthThird,
    4 => t.planNthFourth,
    _ => t.planNthLast,
  };

  /// Monday (1) … Sunday (7), in full.
  String _weekdayName(Words t, int wd) => t.planWeekdayNames.split('|')[wd - 1];

  /// One weekday in Custom…'s row of them, lit when picked.
  Widget _dayChip(
    String label, {
    required String key,
    required bool on,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: Hoverable(
      key: ValueKey(key),
      onTap: onTap,
      builder: (hover) => Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? Mid.blueWash : (hover ? Mid.raised : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: on ? Mid.blue : Mid.ink2.withValues(alpha: 0.3),
          ),
        ),
        child: Text(label, style: onest(12.5, color: on ? Mid.ink : Mid.ink2)),
      ),
    ),
  );

  /// "Every payday", or which pay when there's more than one.
  String _paydayLabel(Words t, PaySchedule s) {
    if (widget.data.paySchedules.length < 2) return t.planEveryPayday;
    return t.planEveryPaydayOf(payTitle(t, widget.data, s));
  }

  /// "Every pay period", or with more than one pay, "Every pay period ·
  /// Jenny".
  String _eachPayLabel(Words t, PaySchedule s) {
    if (widget.data.paySchedules.length < 2) return t.planEveryPayPeriod;
    return t.planEveryPayPeriodOf(payTitle(t, widget.data, s));
  }

  /// What the How often button says.
  String _repeatLabel(Words t) => switch (_repeat) {
    _Repeat.once => t.planOnce,
    // Custom… open: the block under it says the pattern.
    _Repeat.every when _custom => t.planCustomOn,
    _Repeat.every => _everyLabel(t, _typedEveryN ?? 1, _unit),
    _Repeat.dates => t.planDatesAYear(_typedDates?.length ?? 0),
    _Repeat.payday => switch (widget.data.payScheduleById(_payScheduleId)) {
      final s? => _paydayLabel(t, s),
      null => t.planEveryPayday,
    },
  };

  void _preset(int n, _Unit unit) => setState(() {
    _repeat = _Repeat.every;
    _custom = false;
    _everyN.text = '$n';
    _unit = unit;
  });

  /// A control that says what it is by its value (the currency, the
  /// accounts): no label over it, the label as its tooltip.
  Widget _quiet(String label, Widget child) => Padding(
    padding: const EdgeInsets.only(left: 10),
    child: Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 600),
      child: child,
    ),
  );

  /// One line of the form: a label in its column, the control, and a
  /// quiet note beside it when one is needed.
  Widget _formRow(String label, Widget child, {String? aside}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        SizedBox(
          width: 214,
          child: Text(label, style: onest(13, color: Mid.ink2)),
        ),
        child,
        if (aside != null)
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                aside,
                style: onest(12.5, color: Mid.ink3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    ),
  );

  /// The plan as a short form: is there a due date, then what that
  /// needs. [line] is the category worked out with the answers so far,
  /// for the amount a dated plan comes to each period.
  List<Widget> _planFields(
    Words t, {
    required EnvelopeLine? line,
    required CategoryPlan? draft,
  }) {
    final wrongAmount = _tried && _kindNow != null && _typedAmount == null;
    final wrongDate = _tried && _dated && _typedDate == null;
    final wrongUpTo = _tried && !_dated && _wrongUpTo;
    final data = widget.data;
    final paidAccount = data.accounts[_paidFromNow];
    final hasAmount = _amount.text.trim().isNotEmpty;
    String money(int v) => formatShort(v, currency: _currency);
    Widget amountField(
      TextEditingController controller,
      FocusNode focus, {
      required String key,
      required bool wrong,
      bool autofocus = false,
      String? hint,
    }) => SizedBox(
      width: 170,
      height: 34,
      child: TextField(
        key: ValueKey(key),
        controller: controller,
        focusNode: focus,
        autofocus: autofocus,
        textAlign: TextAlign.right,
        style: onest(13.5, tabular: true),
        onSubmitted: (_) => _save(),
        decoration: _fieldDecoration(wrong: wrong).copyWith(
          prefixText: _currency.prefix,
          prefixStyle: onest(13.5, color: Mid.ink3),
          hintText: hint,
          hintStyle: onest(13.5, color: Mid.ink3),
        ),
      ),
    );
    Widget menu(
      MenuController controller, {
      required String key,
      required String label,
      required List<Widget> items,
    }) => SizedBox(
      height: 34,
      child: MenuAnchor(
        controller: controller,
        style: _menuStyle,
        menuChildren: items,
        // Its own width: in a row, an Align would take the whole line.
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: BarButton(
            key: ValueKey(key),
            label: label,
            trailing: Icons.expand_more_rounded,
            active: controller.isOpen,
            onTap: () {
              // The date's calendar shows while the date has the keys,
              // and would sit over the rows below: a dropdown takes them.
              if (_dateFocus.hasFocus) _panelFocus.requestFocus();
              controller.isOpen ? controller.close() : controller.open();
            },
          ),
        ),
      ),
    );
    Widget item(
      String key,
      String label, {
      required bool on,
      required VoidCallback onTap,
    }) => MenuItemButton(
      key: ValueKey(key),
      onPressed: onTap,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(180, 34)),
        overlayColor: WidgetStatePropertyAll(Mid.blueWash),
      ),
      child: Text(label, style: onest(13, color: on ? Mid.ink : Mid.ink2)),
    );
    // A set amount's wording follows its own period, not the view's.
    final byPay = _eachPayId != null;
    final eachLabel = byPay ? t.planSetAsidePay : t.planSetAsideMonth;
    // What a dated plan comes to each period, worked out from the date.
    final String part;
    if (draft == null) {
      part = t.planEnterAmountDate;
    } else if ((line?.plan?.each ?? 0) > 0) {
      part = t.planWorkedOut(money(line!.plan!.each));
    } else {
      part = t.planNothingMore;
    }
    final due = line?.plan?.due ?? _typedDate;
    final dueText = due == null
        ? null
        : due.year == widget.today.year
        ? sayDate(t, due)
        : sayFullDate(t, due);
    return [
      _formRow(
        t.planDueDateQ,
        _Segmented(
          items: [
            ('plan-dated-no', t.planNo, !_hasDate, () => _pickDated(false)),
            ('plan-dated-yes', t.planYes, _hasDate, () => _pickDated(true)),
          ],
        ),
        // What the answer picked means, in one example (owner, 2026-10-05:
        // "What happens if there isn't a due date?").
        aside: _hasDate
            ? t.planDueYesMeans
            : byPay
            ? t.planDueNoMeansPay
            : t.planDueNoMeans,
      ),
      if (!_hasDate) ...[
        _formRow(
          eachLabel,
          amountField(
            _amount,
            _amountFocus,
            key: 'plan-amount',
            wrong: wrongAmount,
            autofocus: widget.atPlan,
            hint: t.planNothingSet,
          ),
          aside: hasAmount
              ? null
              : byPay
              ? t.planEmptyHintPay
              : t.planEmptyHint,
        ),
        // Per month, or per one pay's periods (owner, 2026-10-05: Jeff
        // and Jenny). Month is the default; without pay there's nothing
        // else to pick, so no row. A pay since stopped stays pickable
        // while the plan is on it.
        if (data.paySchedules.isNotEmpty || _eachPayId != null)
          _formRow(
            t.planHowOften,
            menu(
              _eachMenu,
              key: 'plan-each-period',
              label: switch (data.payScheduleById(_eachPayId)) {
                null => t.planRepeatMonths(1),
                final pay => _eachPayLabel(t, pay),
              },
              items: [
                item(
                  'plan-each-month',
                  t.planRepeatMonths(1),
                  on: _eachPayId == null,
                  onTap: () => setState(() => _eachPayId = null),
                ),
                for (final pay in [
                  ...data.paySchedules,
                  if (data.payScheduleById(_eachPayId) case final p?
                      when !data.paySchedules.any((x) => x.id == p.id))
                    p,
                ])
                  item(
                    'plan-each-pay-${pay.id}',
                    _eachPayLabel(t, pay),
                    on: _eachPayId == pay.id,
                    onTap: () => setState(() => _eachPayId = pay.id),
                  ),
              ],
            ),
          ),
        // Shown whether or not an amount is typed: it answers "do we
        // ever zero it out?" (owner, 2026-10-05).
        ...[
          _formRow(
            byPay ? t.planLeftPeriodEnd : t.planLeftMonthEnd,
            _Segmented(
              items: [
                (
                  'plan-carry-on',
                  t.planStaysHere,
                  _rollover,
                  () => setState(() => _rollover = true),
                ),
                (
                  'plan-carry-off',
                  t.planGoesBack,
                  !_rollover,
                  () => setState(() => _rollover = false),
                ),
              ],
            ),
          ),
          if (_rollover && hasAmount)
            _formRow(
              t.planStopAt,
              amountField(
                _upTo,
                _upToFocus,
                key: 'plan-up-to',
                wrong: wrongUpTo,
                hint: t.planNoLimit,
              ),
              aside: t.planStopAtHint,
            ),
        ],
        _accountsRow(t),
      ] else ...[
        _formRow(
          t.planAmountDue,
          amountField(
            _amount,
            _amountFocus,
            key: 'plan-amount',
            wrong: wrongAmount,
            autofocus: widget.atPlan,
          ),
        ),
        _formRow(
          t.planHowOften,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              menu(
                _repeatMenu,
                key: 'plan-repeat',
                label: _repeatLabel(t),
                items: [
                  item(
                    'plan-repeat-0',
                    t.planOnce,
                    on: _repeat == _Repeat.once,
                    onTap: () => setState(() => _repeat = _Repeat.once),
                  ),
                  for (final (key, n, unit, label) in [
                    ('plan-repeat-d7', 1, _Unit.weeks, t.planRepeatWeeks(1)),
                    ('plan-repeat-d14', 2, _Unit.weeks, t.planRepeatWeeks(2)),
                    ('plan-repeat-1', 1, _Unit.months, t.planRepeatMonths(1)),
                    ('plan-repeat-3', 3, _Unit.months, t.planRepeatMonths(3)),
                    ('plan-repeat-12', 1, _Unit.years, t.planRepeatYears(1)),
                  ])
                    item(
                      key,
                      label,
                      on:
                          _repeat == _Repeat.every &&
                          !_custom &&
                          _unit == unit &&
                          _typedEveryN == n,
                      onTap: () => _preset(n, unit),
                    ),
                  // Payday by payday: only with pay set up.
                  for (final pay in data.paySchedules)
                    item(
                      'plan-repeat-pay-${pay.id}',
                      _paydayLabel(t, pay),
                      on: _repeat == _Repeat.payday && _payScheduleId == pay.id,
                      onTap: () => setState(() {
                        _repeat = _Repeat.payday;
                        _payScheduleId = pay.id;
                      }),
                    ),
                  item(
                    'plan-repeat-custom',
                    t.planEveryCustom,
                    on: _repeat == _Repeat.every && _custom,
                    onTap: () => setState(() {
                      _repeat = _Repeat.every;
                      _custom = true;
                    }),
                  ),
                  item(
                    'plan-repeat-dates',
                    t.planOnDates,
                    on: _repeat == _Repeat.dates,
                    onTap: () => setState(() => _repeat = _Repeat.dates),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_repeat == _Repeat.payday)
          _formRow(
            t.planLabelDueDate,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 56,
                  height: 34,
                  child: TextField(
                    key: const ValueKey('plan-days-after'),
                    controller: _daysAfter,
                    textAlign: TextAlign.center,
                    style: onest(13.5, tabular: true),
                    onSubmitted: (_) => _save(),
                    decoration: _fieldDecoration(wrong: false).copyWith(
                      hintText: '0',
                      hintStyle: onest(13.5, color: Mid.ink3),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(t.planDaysAfterPay, style: onest(13, color: Mid.ink2)),
              ],
            ),
            aside: _daysAfterNow == 0 ? t.planOnPayday : null,
          )
        else
          _formRow(
            _repeat == _Repeat.dates ? t.planDatesLabel : t.planLabelDueDate,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_repeat == _Repeat.dates)
                  SizedBox(
                    width: 300,
                    height: 34,
                    child: TextField(
                      key: const ValueKey('plan-dates'),
                      controller: _dates,
                      focusNode: _datesFocus,
                      style: onest(13.5, tabular: true),
                      onSubmitted: (_) => _save(),
                      decoration:
                          _fieldDecoration(
                            wrong:
                                _tried &&
                                (_typedDates == null || _typedDates!.isEmpty),
                          ).copyWith(
                            hintText: t.planDatesHint,
                            hintStyle: onest(13.5, color: Mid.ink3),
                          ),
                    ),
                  )
                else
                  SizedBox(
                    width: 130,
                    height: 34,
                    child: DateField(
                      key: const ValueKey('plan-date'),
                      controller: _date,
                      focusNode: _dateFocus,
                      today: widget.today,
                      small: true,
                      // Beside, not under: under it are Paid from and Save.
                      calendarBeside: true,
                      wanted: wrongDate,
                      onSubmitted: _save,
                      onPicked: () {},
                    ),
                  ),
                // A weekend rule, for dates that can land on one (not
                // chosen weekdays: those are the days).
                if (_repeat != _Repeat.once && _weekdaysNow == null) ...[
                  const SizedBox(width: 10),
                  menu(
                    _weekendMenu,
                    key: 'plan-weekend',
                    label: _weekendLabel(t, _weekend),
                    items: [
                      for (final w in PayWeekend.values)
                        item(
                          'plan-weekend-${w.name}',
                          _weekendLabel(t, w),
                          on: w == _weekend,
                          onTap: () => setState(() => _weekend = w),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        // Custom…: the pattern laid out like a calendar app's recurrence
        // (owner, 2026-10-05), under the date it starts from: how many of
        // which unit, the weekdays or the nth weekday when the unit has
        // them, and when it ends.
        if (_customOn) ...[
          _formRow(
            t.planRepeatEvery,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 56,
                  height: 34,
                  child: TextField(
                    key: const ValueKey('plan-every-n'),
                    controller: _everyN,
                    textAlign: TextAlign.center,
                    style: onest(13.5, tabular: true),
                    onSubmitted: (_) => _save(),
                    decoration: _fieldDecoration(
                      wrong: _tried && _typedEveryN == null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                menu(
                  _unitMenu,
                  key: 'plan-every-unit',
                  label: _unitLabel(t, _unit),
                  items: [
                    for (final u in _Unit.values)
                      item(
                        'plan-every-unit-${u.name}',
                        _unitLabel(t, u),
                        on: u == _unit,
                        onTap: () => setState(() => _unit = u),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (_unit == _Unit.weeks)
            _formRow(
              t.planOnWeekdays,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, initial)
                      in t.rowsWeekdayInitials.split('|').indexed)
                    _dayChip(
                      initial,
                      key: 'plan-weekday-${i + 1}',
                      on: _weekdays.contains(i + 1),
                      onTap: () => setState(
                        () => _weekdays.contains(i + 1)
                            ? _weekdays.remove(i + 1)
                            : _weekdays.add(i + 1),
                      ),
                    ),
                ],
              ),
              aside: _weekdays.isEmpty ? t.planWeekdaysHint : null,
            ),
          if (_unit == _Unit.months || _unit == _Unit.years)
            _formRow(
              t.planOnLabel,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Segmented(
                    items: [
                      (
                        'plan-nth-off',
                        t.planDayOfMonth,
                        !_nthOn,
                        () => setState(() => _nthOn = false),
                      ),
                      (
                        'plan-nth-on',
                        t.planAWeekday,
                        _nthOn,
                        () => setState(() {
                          _nthOn = true;
                          // Start from the date typed: its weekday, and
                          // which one of the month it is.
                          if (_typedDate case final d?) {
                            _nthWeekday = d.weekday;
                            _nth = (d.day - 1) ~/ 7 + 1;
                            if (_nth > 4) _nth = -1;
                          }
                        }),
                      ),
                    ],
                  ),
                  if (_nthOn) ...[
                    const SizedBox(width: 8),
                    menu(
                      _nthMenu,
                      key: 'plan-nth',
                      label: _nthLabel(t, _nth),
                      items: [
                        for (final n in const [1, 2, 3, 4, -1])
                          item(
                            'plan-nth-$n',
                            _nthLabel(t, n),
                            on: n == _nth,
                            onTap: () => setState(() => _nth = n),
                          ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    menu(
                      _nthWeekdayMenu,
                      key: 'plan-nth-weekday',
                      label: _weekdayName(t, _nthWeekday),
                      items: [
                        for (var wd = 1; wd <= 7; wd++)
                          item(
                            'plan-nth-weekday-$wd',
                            _weekdayName(t, wd),
                            on: wd == _nthWeekday,
                            onTap: () => setState(() => _nthWeekday = wd),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
        if (_endsOn)
          _formRow(
            t.planEnds,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Segmented(
                  items: [
                    for (final (e, label) in [
                      (_Ends.never, t.planEndsNever),
                      (_Ends.date, t.planEndsOn),
                      (_Ends.count, t.planEndsAfter),
                    ])
                      (
                        'plan-ends-${e.name}',
                        label,
                        _ends == e,
                        () => setState(() => _ends = e),
                      ),
                  ],
                ),
                if (_ends == _Ends.date) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 130,
                    height: 34,
                    child: TextField(
                      key: const ValueKey('plan-end-date'),
                      controller: _endDate,
                      style: onest(13.5, tabular: true),
                      onSubmitted: (_) => _save(),
                      decoration:
                          _fieldDecoration(
                            wrong: _tried && _typedEndDate == null,
                          ).copyWith(
                            hintText: t.planEndDateHint,
                            hintStyle: onest(13.5, color: Mid.ink3),
                          ),
                    ),
                  ),
                ],
                if (_ends == _Ends.count) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 56,
                    height: 34,
                    child: TextField(
                      key: const ValueKey('plan-end-count'),
                      controller: _endCount,
                      textAlign: TextAlign.center,
                      style: onest(13.5, tabular: true),
                      onSubmitted: (_) => _save(),
                      decoration: _fieldDecoration(
                        wrong: _tried && _typedEndCount == null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(t.planEndsTimes, style: onest(13, color: Mid.ink2)),
                ],
              ],
            ),
          ),
        _accountsRow(
          t,
          // Warn, don't block: with several checked the bill is in no
          // forecast, said with the count (budget review, 2026-10-05).
          aside: paidAccount != null && dueText != null
              ? t.planPaidFromHint(paidAccount.name, dueText)
              : switch (_categoryAccounts(
                  data,
                  _currency,
                ).where((a) => !_off.contains(a.id)).length) {
                  0 => t.planPaidFromNoneChecked,
                  1 => t.planPaidFromHintNone,
                  final n => t.planPaidFromSeveral(n),
                },
        ),
        _formRow(
          eachLabel,
          Text(
            part,
            key: const ValueKey('plan-part'),
            style: onest(
              13.5,
              color: draft == null ? Mid.ink3 : Mid.ink,
              tabular: true,
            ),
          ),
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
      _quiet(
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
              if (_hasDate) _amountFocus.requestFocus();
            },
          ),
        ),
      ),
    ];
  }

  /// Paid from: the accounts in its currency, in a dropdown that stays
  /// open while they're checked and unchecked; the button says how many
  /// it uses. The one row for both what rule 28 called the accounts a
  /// category uses and the account a dated plan's bill is scheduled in.
  Widget _accountsRow(Words t, {String? aside}) {
    final accounts = _categoryAccounts(widget.data, _currency).toList();
    final used = accounts.where((a) => !_off.contains(a.id)).toList();
    return _formRow(
      t.planLabelPaidFrom,
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
      aside: aside,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = widget.category;
    final data = widget.data;
    String say(int v) => formatShort(v, currency: _currency);

    return ListenableBuilder(
      listenable: Listenable.merge([
        _amount,
        _date,
        _upTo,
        _everyN,
        _dates,
        _daysAfter,
        _endDate,
        _endCount,
      ]),
      builder: (context, _) {
        final draft = _draft;
        // What went back in earlier periods returns to the category when
        // it carries over again: said before it's saved.
        String? returns;
        // The category as the answers so far make it: the row drawn as
        // it will read, and a dated plan's part.
        EnvelopeLine? line;
        _PlanNote? note;
        if (_currency == c.currency) {
          Budget of(LedgerData d) => Budget.of(
            d,
            start: widget.period.start,
            end: widget.period.end,
            today: widget.today,
          );
          final now = of(data);
          // No plan, picked over a saved one, can bring money back too.
          final plans =
              draft != null || (_kindNow == null && _savedPlan != null);
          final after = plans ? of(data.withPlan(c.id, draft)) : now;
          line = after.lines[c.id];
          // In the category's own currency.
          int free(Budget b) =>
              b.pools
                  .where((p) => p.currency == _currency)
                  .firstOrNull
                  ?.notAssigned ??
              0;
          final back = plans ? free(now) - free(after) : 0;
          if (back > 0) {
            returns = t.planReturns(
              formatMoney(back, currency: _currency),
              c.name,
            );
          }
          if (line?.plan != null) {
            note = _planNote(
              t,
              line!,
              widget.period,
              widget.today,
              _currency,
              payName: _ownPayName(t, data, line.plan!.plan),
              own: data.payScheduleById(line.plan!.plan.payScheduleId),
            );
          }
        }
        final preview = note == null
            ? null
            : note.state == null
            ? note.text
            : '${note.text} · ${note.state}';
        // An account put away schedules nothing: said, not silent.
        String? paidArchived;
        final paidAccount = data.accounts[_paidFromNow];
        if (paidAccount != null && paidAccount.archived) {
          paidArchived = t.planPaidFromArchived(paidAccount.name);
        }

        final accounts = _categoryAccounts(data, _currency).toList();
        // In another currency its amounts and plan mean nothing: they go,
        // and the panel says so first.
        final assigned = data.budgetAmounts
            .where((b) => b.categoryId == c.id)
            .fold(0, (sum, b) => sum + b.amount);
        // A plan typed in the new currency takes the old one's place.
        final hasPlan = _savedPlan != null && draft == null;
        final loses = _currency != c.currency && (assigned != 0 || hasPlan);
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
        // Opened low in the list, or grown by a choice, Save would be
        // under the window's edge.
        // The repeat rows grow it too: Custom…, its unit, Ends.
        final shape = Object.hash(
          _hasDate,
          _kindNow,
          accounts.length,
          preview != null,
          returns != null,
          rest != null,
          loses,
          _repeat,
          _customOn,
          _unit,
          _endsOn,
          _ends,
          _nthOn,
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
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // The name is the heading; the currency sits
                          // quiet beside it, set once.
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Tooltip(
                                  message: t.planEditName,
                                  waitDuration: const Duration(
                                    milliseconds: 600,
                                  ),
                                  child: TextField(
                                    key: const ValueKey('edit-name'),
                                    controller: _name,
                                    focusNode: _nameFocus,
                                    autofocus: !widget.atPlan,
                                    style: onest(19, weight: 700),
                                    onSubmitted: (_) => _save(),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: t.planEditName,
                                      hintStyle: onest(19, color: Mid.ink3),
                                      contentPadding: const EdgeInsets.fromLTRB(
                                        2,
                                        6,
                                        2,
                                        6,
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color:
                                              _tried &&
                                                  _name.text.trim().isEmpty
                                              ? Mid.coral
                                              : Mid.rule,
                                        ),
                                      ),
                                      focusedBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(color: Mid.blue),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ..._currencyChoice(t),
                            ],
                          ),
                          const SizedBox(height: 22),
                          ..._planFields(t, line: line, draft: draft),
                          // The row, as it will read after Save.
                          const SizedBox(height: 6),
                          Text(
                            t.planRowWillRead,
                            style: onest(12, color: Mid.ink3),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: Mid.panel,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _name.text.trim().isEmpty
                                            ? c.name
                                            : _name.text.trim(),
                                        style: onest(13.5, weight: 600),
                                      ),
                                      if (preview != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  preview,
                                                  key: const ValueKey(
                                                    'plan-preview',
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: onest(
                                                    12.5,
                                                    color: note!.behind
                                                        ? Mid.gold
                                                        : Mid.ink2,
                                                    tabular: true,
                                                  ),
                                                ),
                                              ),
                                              if ((line?.toAssign ?? 0) > 0)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 10,
                                                      ),
                                                  child: Text(
                                                    t.planAssignThis(
                                                      formatShort(
                                                        line!.toAssign,
                                                        currency: _currency,
                                                      ),
                                                    ),
                                                    style: onest(
                                                      12.5,
                                                      color: Mid.blue,
                                                      tabular: true,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                for (final v in [
                                  line?.assigned ?? widget.assigned,
                                  line?.spent ?? 0,
                                  line?.left ?? 0,
                                ])
                                  SizedBox(
                                    width: 120,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Money(
                                        v,
                                        size: 13,
                                        currency: _currency,
                                        color: v == 0 ? Mid.ink3 : Mid.ink2,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (returns != null)
                      warning(returns, 'plan-returns', Mid.gold),
                    if (paidArchived != null)
                      warning(paidArchived, 'plan-paid-archived', Mid.gold),
                    if (rest != null) warning(rest, 'money-rest', Mid.ink2),
                    if (loses)
                      warning(
                        _moneyChange(t, c, assigned, hasPlan),
                        'money-change',
                        Mid.gold,
                      ),
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

/// Two or three answers side by side in one outline, the chosen one
/// washed blue: "No | Yes", "Stays here | Goes back to not assigned".
class _Segmented extends StatelessWidget {
  const _Segmented({required this.items});

  /// Key, label, whether it's the one picked, and what picking it does.
  final List<(String, String, bool, VoidCallback)> items;

  @override
  Widget build(BuildContext context) => Container(
    height: 34,
    decoration: BoxDecoration(
      border: Border.all(color: Mid.rule),
      borderRadius: BorderRadius.circular(8),
    ),
    clipBehavior: Clip.antiAlias,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, (key, label, on, onTap)) in items.indexed)
          Hoverable(
            key: ValueKey(key),
            onTap: onTap,
            builder: (hover) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on
                    ? Mid.blueWash
                    : hover
                    ? Mid.raised
                    : Colors.transparent,
                border: i == 0
                    ? null
                    : Border(left: BorderSide(color: Mid.rule)),
              ),
              child: Text(
                label,
                style: onest(
                  13,
                  color: on ? Mid.blue : Mid.ink2,
                  weight: on ? 600 : 400,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// How a dated plan comes again, as the panel asks it.
enum _Repeat { once, every, dates, payday }

/// Custom…: when a repeating plan stops.
enum _Ends { never, date, count }

/// The unit after "Every": days, weeks, months or years.
enum _Unit { days, weeks, months, years }
