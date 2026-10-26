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
    required this.onAdd,
    required this.nameNote,
    required this.onUnarchive,
    required this.onShowRows,
    required this.onShowAllRows,
    required this.onSetAmount,
    required this.onBudgetBy,
    required this.onKeysBack,
    required this.onStartLater,
    required this.onKeepStart,
    required this.onAssignPlanned,
    required this.onMove,
    required this.onEditOpens,
    required this.keep,
  });

  /// What's typed in an open Edit, kept by the screen: leaving the page
  /// and coming back finds Edit open as it was (#163).
  final _EditKeep keep;

  /// A category's Edit opened: the popup in the page's corner would lie
  /// over its Cancel and Save, so it goes (⌘Z still undoes what it said).
  final VoidCallback onEditOpens;

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

  /// Move was clicked in the box under a Left: the amount from one side to
  /// the other in the period; null on a side is Not assigned.
  final void Function(BudgetSpan, AccountInfo? from, AccountInfo? to, int)
  onMove;

  /// The first-period offer: start the budget in the next period instead.
  final void Function(BudgetSpan period, BudgetSpan next) onStartLater;
  final VoidCallback onKeepStart;

  final LedgerData data;
  final DateTime today;

  /// Typing ended: ⌘Z and the other keys go back to the screen.
  final VoidCallback onKeysBack;

  /// Spent was clicked: the category's rows in that period, in All accounts.
  final void Function(AccountInfo, BudgetSpan) onShowRows;

  /// The usage in Edit was picked: every row, all time.
  final ValueChanged<AccountInfo> onShowAllRows;

  /// Add in the New category window: the category made with everything
  /// set in it, or the one already called that opened in Edit.
  final Future<_Added> Function(_CategoryEdit) onAdd;

  /// What the window says under a name that's taken.
  final ({String text, bool blocks})? Function(String name) nameNote;
  final ValueChanged<AccountInfo> onUnarchive;

  /// A Put in amount was typed for the period starting on the date.
  final void Function(AccountInfo, BudgetSpan, int) onSetAmount;

  /// The view dropdown: by month (null), or by a pay's periods.
  final ValueChanged<PaySchedule?> onBudgetBy;

  @override
  State<_BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<_BudgetPage> {
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    // Back on the page with an Edit left open: it opens again.
    final id = widget.keep.draft?.id;
    if (id != null && widget.data.categories.any((c) => c.id == id)) {
      _open = id;
    }
  }

  /// Each row's ⋯, by category: an Edit that closes gives focus back to
  /// its row's, not to the top of the window (#163).
  final _dots = <int, FocusNode>{};
  FocusNode _dotsOf(int id) =>
      _dots.putIfAbsent(id, () => FocusNode(debugLabel: 'category-menu'));

  @override
  void dispose() {
    for (final f in _dots.values) {
      f.dispose();
    }
    super.dispose();
  }

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

  /// Opens [id]'s Edit under its row, in the period today is in: asked for
  /// from the popup that says a phone made the category.
  void openEdit(int id) => setState(() {
    _tab = _BudgetTab.spending;
    _period = null;
    _editing = null;
    _openAtPlan = false;
    _open = id;
  });

  /// ⌘N: the add box for a category, or Add pay on the Income tab.
  void addNew() {
    if (_tab == _BudgetTab.income) {
      widget.onPay(null);
      return;
    }
    // Over an open Edit, which keeps what was typed in it (#163).
    setState(() => _editing = null);
    _newCategory();
  }

  /// The New category window (owner, 2026-10-22, #237): everything a new
  /// category can have, set before it's made, and Add another for the
  /// next. Made, its row is in the list behind; nothing opens under it.
  void _newCategory() {
    final data = widget.data;
    final currencies = [
      for (final c in Currency.values)
        if (data.openAccounts.any((a) => a.currency == c)) c,
    ];
    final budget = Budget.currencyOf(data);
    showDialog<void>(
      context: context,
      builder: (_) => _NewCategoryWindow(
        data: () => widget.data,
        period: _period ?? _current,
        today: widget.today,
        currencies: currencies,
        // In a currency there's an account in: the budget's own, unless
        // its accounts are gone (owner, 2026-10-07: a new category came
        // out in dollars with only a tugrik account left).
        currency: currencies.isEmpty || currencies.contains(budget)
            ? budget
            : currencies.first,
        nameNote: widget.nameNote,
        onAdd: widget.onAdd,
      ),
    );
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
    // Edit closed, or another opened: what was typed in it goes.
    if (widget.keep.draft?.id != _open) widget.keep.clear();
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
    // The safety net is money kept, not spent: last, under "Saved" (owner,
    // 2026-10-09: "we should probably create some type of visual
    // separation").
    final saved = fundCategoryIds(data, mainCurrency(data));
    final listed = data.categories
        .where((c) => !c.isIncome && !isUncategorized(c))
        .toList();
    final spending = [
      ...listed.where((c) => !saved.contains(c.id)),
      ...listed.where((c) => saved.contains(c.id)),
    ];
    final firstSaved = spending.indexWhere((c) => saved.contains(c.id));
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

    /// Tab goes on to the next row's Assigned, Shift+Tab back to the one
    /// before (#163).
    void editNext(AccountInfo c, int by) {
      final i = spending.indexWhere((x) => x.id == c.id) + by;
      edit(i >= 0 && i < spending.length ? spending[i].id : null);
    }

    // The panel's top row: the two tabs, and over the categories their
    // column heads. A blue dot on Income says pay wants attention (not set
    // up, or an estimate to update).
    Widget tabs() => CustomPaint(
      foregroundPainter: _tab == _BudgetTab.spending
          ? _ColumnLines(Mid.ink3)
          : null,
      child: Padding(
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
              // Each word is centred in its column as the dotted lines draw
              // it (owner, 2026-10-07): between two lines, and for Left
              // between its line and where the amounts end.
              for (final (h, from, width) in [
                (t.planAssigned, _ColumnLines._gap, _amountWidth),
                (t.planSpent, _ColumnLines._gap, _amountWidth),
                (t.planLeft, _ColumnLines._gap / 2, _leftWidth),
              ])
                SizedBox(
                  width: width,
                  child: Padding(
                    padding: EdgeInsets.only(left: from * 2),
                    child: Text(
                      h,
                      textAlign: TextAlign.center,
                      style: onest(12.5, color: Mid.ink3),
                    ),
                  ),
                ),
              const SizedBox(width: 40),
            ],
          ],
        ),
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
    // Pay that came: any row filed under a pay's category, not only a
    // payday the app scheduled, so pay typed or imported is "received"
    // too, as the Income line beside it counts it (#163).
    final payCategories = {for (final p in data.paySchedules) p.categoryId};
    final fromPay = <Currency, int>{};
    for (final x in data.txns) {
      if (x.scheduled) continue;
      if (x.payScheduleId == null &&
          !x.entries.any((e) => payCategories.contains(e.accountId))) {
        continue;
      }
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
      final was = _open;
      setState(() {
        _open = id;
        _openAtPlan = atPlan;
        if (id != null) _editing = null;
      });
      if (id != null) widget.onEditOpens();
      if (id == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          // Back on the row it was opened from, when it's still there.
          final dots = _dots[was];
          if (dots != null && dots.context != null) {
            dots.requestFocus();
          } else {
            widget.onKeysBack();
          }
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
      // What a move can trade with: Not assigned in its currency, then the
      // other categories in it (rule 28), each with what it has left.
      // Money waiting for a bill, and the safety net, under their own
      // headings, so neither reads as money to spend (budget review; the
      // phone's Bills, owner 2026-10-07).
      final pool = budget.pools.where((p) => p.currency == currency);
      final others = [
        for (final x in spending)
          if (x.id != c.id &&
              x.currency == currency &&
              budget.lines[x.id] != null)
            x,
        // Put away but still holding money: it can be moved out (#163).
        for (final x in archived)
          if (x.id != c.id &&
              x.currency == currency &&
              !spending.contains(x) &&
              (budget.lines[x.id]?.left ?? 0) > 0)
            x,
      ];
      bool isBill(AccountInfo x) =>
          budget.lines[x.id]?.plan?.plan.kind == PlanKind.byDate;
      // Money coming in (it's short): the ones with most to give first, so
      // Groceries isn't under three lines at ₮0 (first-time reader).
      if ((line?.left ?? 0) <= 0) {
        others.sort(
          (a, b) =>
              budget.lines[b.id]!.left.compareTo(budget.lines[a.id]!.left),
        );
      }
      final groups = [
        (null, others.where((x) => !saved.contains(x.id) && !isBill(x))),
        (t.phoneBills, others.where((x) => !saved.contains(x.id) && isBill(x))),
        (t.planSaved, others.where((x) => saved.contains(x.id))),
      ];
      final choices = <_MoveChoice>[
        if (pool.isNotEmpty)
          (category: null, left: pool.first.notAssigned, heading: null),
        for (final (heading, xs) in groups)
          for (final (i, x) in xs.indexed)
            (
              category: x,
              left: budget.lines[x.id]!.left,
              heading: i == 0 ? heading : null,
            ),
      ];
      final row = _CategoryRow(
        key: ValueKey('category-${c.id}'),
        category: c,
        menuFocus: _dotsOf(c.id),
        striped: striped,
        planNote: line == null || planLine == null
            ? null
            : planNote(
                t,
                line,
                period,
                widget.today,
                currency,
                payName: ownPayName(t, data, planLine.plan),
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
        moveChoices: choices,
        onMove: (from, to, amount) => widget.onMove(period, from, to, amount),
        editing: _editing == c.id,
        onEdit: () => edit(c.id),
        onAssign: (amount, {required int next}) {
          if (amount != null && amount != (line?.assigned ?? 0)) {
            widget.onSetAmount(c, period, amount);
          }
          next != 0 ? editNext(c, next) : edit(null);
        },
      );
      // Edit opens under the row, which grows like a register row.
      return SmoothHeight(
        key: ValueKey('category-row-${c.id}'),
        duration: grow,
        // The row stays in one place whether Edit is open or not, so it
        // keeps its state and its ⋯'s focus (#163).
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row,
            if (_open == c.id)
              _CategoryEditor(
                key: ValueKey('category-editor-${c.id}'),
                keep: widget.keep.of(c, widget.today),
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
      }) => Shrink(
        end: true,
        Text(
          money(v, c),
          key: ValueKey(key),
          maxLines: 1,
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
        ),
      );
      var figureWidth = 200.0;
      Widget label(String text, {bool big = false, bool coral = false}) => Text(
        text,
        style: big
            ? onest(14, weight: 500, color: coral ? Mid.coral : Mid.ink)
            : onest(13, color: coral ? Mid.coral : Mid.ink3),
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
            // Wide enough for a tugrik sum with cents at the big size;
            // narrower with many currencies, so four fit at 1360 × 760
            // (#163). The figures shrink rather than cut.
            for (final f in figures) ...[
              SizedBox(width: figureWidth, child: f),
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
        child: LayoutBuilder(
          builder: (context, box) {
            // The label's 150, then the currencies' columns and their
            // gaps, leaving a little for the notes.
            final room = (box.maxWidth - 150 - 40) / pools.length - 28;
            figureWidth = room < 200 ? (room < 120 ? 120 : room) : 200;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Names only what the ledger actually holds, the way two
                // currencies are told apart only when both are there.
                row(
                  label(cashBankLabel(t, data)),
                  [
                    for (final p in pools)
                      // Cash and bank only, so it can't go below zero and has no
                      // coral state: what's owed is the Savings page's business.
                      figure(
                        'you-have${tagOf(p.currency)}',
                        p.money,
                        p.currency,
                      ),
                  ],
                  [
                    // Another period's rows under today's money: said (#163).
                    if (!isCurrent)
                      Text(
                        t.planKeyAsOfToday,
                        key: const ValueKey('budget-key-today'),
                        style: onest(12.5, color: Mid.ink3),
                      ),
                  ],
                ),
                row(label(t.planKeyAssigned), [
                  for (final p in pools)
                    figure(
                      'assigned-sum${tagOf(p.currency)}',
                      held[p.currency]!,
                      p.currency,
                    ),
                ], assignedNotes),
                // What overspent categories went over: already out of Cash &
                // bank, so said here and not taken off again (owner,
                // 2026-10-24).
                if (pools.any((p) => p.overspent > 0))
                  row(label(t.planKeyOverspent, coral: true), [
                    for (final p in pools)
                      p.overspent > 0
                          ? figure(
                              'overspent${tagOf(p.currency)}',
                              p.overspent,
                              p.currency,
                              coral: true,
                            )
                          : const SizedBox(),
                  ], const []),
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
                // Nothing assigned yet: why a row's Left is ₮0 beside what was
                // spent (owner, 2026-10-24). Gone with the first amount.
                if (budget.began == null)
                  Padding(
                    key: const ValueKey('budget-not-begun'),
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      t.planKeyNotBegun,
                      style: onest(13, color: Mid.ink2),
                    ),
                  )
                // The budget began inside the period on screen: Spent shows
                // all of it, Left only what came after (#163).
                else if (budget.began case final b?
                    when b.isAfter(period.start) && !b.isAfter(period.end))
                  Padding(
                    key: const ValueKey('budget-began-inside'),
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      t.planKeyBeganInside(sayDate(t, b)),
                      style: onest(13, color: Mid.ink2),
                    ),
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
            );
          },
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
                    // An open Edit stays, with what was typed in it, and its
                    // row is drawn for the new period (#163).
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
                    // An open Edit stays, with what was typed in it, and its
                    // row is drawn for the new period (#163).
                    _period = nextBudgetPeriod(period, by);
                  }),
                ),
                if (!isCurrent) ...[
                  const SizedBox(width: 8),
                  Hoverable(
                    key: const ValueKey('period-today'),
                    onTap: () => setState(() {
                      _editing = null;
                      // An open Edit stays, with what was typed in it, and its
                      // row is drawn for the new period (#163).
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
                    onTap: _newCategory,
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
                    // Hidden, but kept so what was typed in it stays:
                    // Tab mustn't walk through it (#163).
                    child: ExcludeFocus(
                      excluding: _tab == _BudgetTab.income,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (i, c) in spending.indexed) ...[
                            if (i == firstSaved)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  18,
                                  12,
                                  6,
                                ),
                                child: Text(
                                  t.planSaved,
                                  key: const ValueKey('budget-saved'),
                                  style: onest(
                                    12.5,
                                    weight: 600,
                                    color: Mid.ink3,
                                  ),
                                ),
                              ),
                            row(c, striped: i.isOdd),
                          ],
                          const SizedBox(height: 14),
                          if (archived.isNotEmpty) ...[
                            Hoverable(
                              key: const ValueKey('show-archived-categories'),
                              onTap: () => setState(
                                () => _showArchived = !_showArchived,
                              ),
                              builder: (hover) => Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  6,
                                  12,
                                  6,
                                ),
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
                                          color: left < 0
                                              ? Mid.coral
                                              : Mid.ink2,
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

/// Left is wider: on the row the pointer is on, "Move money" goes beside
/// its amount (owner, 2026-10-23), in both languages.
const double _leftWidth = _amountWidth + 116;

/// Two dotted lines down the list, between Assigned and Spent and between
/// Spent and Left (owner, 2026-10-07). Each row and the headings draw their
/// own piece, so the lines stop at an open Edit.
class _ColumnLines extends CustomPainter {
  const _ColumnLines(this.color);
  final Color color;

  /// From a row's right edge to the right edge of Left: the row's padding,
  /// the ⋯ button and the gap before it.
  static const double _afterLeft = 52;

  /// Right of where a column's amounts end, so a line doesn't touch them.
  static const double _gap = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = color.withValues(alpha: 0.6);
    for (final columns in const [0, 1]) {
      final x =
          size.width - _afterLeft - _leftWidth - columns * _amountWidth + _gap;
      for (var y = 1.0; y < size.height; y += 4) {
        canvas.drawRect(Rect.fromLTWH(x, y, 1, 2), dot);
      }
    }
  }

  @override
  bool shouldRepaint(_ColumnLines old) => old.color != color;
}

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

  /// Something on the tab wants attention: a small blue dot after it.
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
            if (dot) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Mid.blue,
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
                                color: Mid.note,
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
                    style: onest(13.5, color: Mid.note),
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
      menuChildren: focusFirstOnKeys([
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
      ]),
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
/// up" (until it is). With more than one pay it's about the one that
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
    required this.menuFocus,
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
    this.moveChoices = const [],
    this.onMove,
  });
  final AccountInfo category;

  /// What the box under Left can move money to or from: Not assigned
  /// first, then the other categories in its currency.
  final List<_MoveChoice> moveChoices;
  final void Function(AccountInfo? from, AccountInfo? to, int amount)? onMove;

  /// It's open in Edit under the row.
  final bool open;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onDelete;

  /// More to say under the name (the accounts it's limited to,
  /// rows that couldn't be counted), each with what a click does.
  final List<_LineFlag> flags;

  /// Its ⋯'s focus, kept by the page so a closed Edit comes back to it.
  final FocusNode menuFocus;

  /// With a plan: what it says under the name (rule 27).
  final PlanNote? planNote;

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
  final void Function(int? amount, {required int next}) onAssign;

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
      menuChildren: focusFirstOnKeys(
        _categoryMenu(
          t,
          onEdit: widget.onOpen,
          // The app's own Safety net stays, as Income does.
          onDelete: isSafetyNet(widget.category) ? null : widget.onDelete,
        ),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _tap,
          onSecondaryTapDown: (d) => _menu.open(position: d.localPosition),
          child: CustomPaint(
            foregroundPainter: widget.line == null
                ? null
                : _ColumnLines(Mid.ink3),
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
                      width: _leftWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _MoveLeft(
                            key: ValueKey('move-${c.id}'),
                            rowHover: _hover,
                            category: c,
                            left: line.left,
                            currency: widget.currency,
                            choices: widget.moveChoices,
                            onMove: widget.onMove,
                            child: Money(
                              line.left,
                              key: ValueKey('left-${c.id}'),
                              size: 13.5,
                              weight: 600,
                              currency: widget.currency,
                              color: line.left < 0
                                  ? Mid.coral
                                  : (line.left == 0 ? Mid.ink3 : Mid.ink),
                            ),
                          ),
                          if (widget.fromBefore case final before?)
                            Text(
                              before,
                              key: ValueKey('from-before-${c.id}'),
                              // Wrapped, it stays against the right edge
                              // instead of running into Spent.
                              textAlign: TextAlign.end,
                              style: onest(
                                11.5,
                                color: Mid.ink3,
                                tabular: true,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(width: 12),
                  Hoverable(
                    key: ValueKey('category-menu-${c.id}'),
                    focusNode: widget.menuFocus,
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
      ),
    );
  }
}

/// One side a move can trade with: a category, or Not assigned (null),
/// what it has left, and the heading it starts (Bills, Saved), if any.
typedef _MoveChoice = ({AccountInfo? category, int left, String? heading});

/// A category's Left, which opens the move box under it (#99; ADR 0004
/// "Move money between categories", the owner's pick A of three). With
/// money in it, the box moves it out; at zero or below, it moves money in,
/// the shortfall filled in. Nothing to trade with: plain, not a button.
class _MoveLeft extends StatefulWidget {
  const _MoveLeft({
    super.key,
    this.rowHover = false,
    required this.category,
    required this.left,
    required this.currency,
    required this.choices,
    required this.onMove,
    required this.child,
  });

  /// The pointer is on its row: outlined, with "Move money" beside it, so
  /// it's found without hunting (owner, 2026-10-23: "it's a hidden
  /// feature").
  final bool rowHover;
  final AccountInfo category;
  final int left;
  final Currency currency;
  final List<_MoveChoice> choices;
  final void Function(AccountInfo? from, AccountInfo? to, int amount)? onMove;
  final Widget child;

  /// The box opens with money coming in (it's at zero or below), rather
  /// than going out; Swap turns it around either way (owner, 2026-10-23:
  /// "they should be able to move money in or out regardless").
  bool get inward => left <= 0;

  /// Anything to trade with: Not assigned can always take money back.
  bool get offered => choices.isNotEmpty;

  @override
  State<_MoveLeft> createState() => _MoveLeftState();
}

class _MoveLeftState extends State<_MoveLeft> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();

  /// Where focus was before the box opened, so closing hands it back.
  FocusNode? _returnFocus;

  /// It opens above the amount when there's more room there than below,
  /// with that much room for its list.
  bool _above = false;
  double _room = 600;

  void _toggle() {
    if (_portal.isShowing) return _close();
    _returnFocus = FocusManager.instance.primaryFocus;
    final box = context.findRenderObject() as RenderBox?;
    final height = MediaQuery.sizeOf(context).height;
    if (box != null && box.hasSize) {
      final top = box.localToGlobal(Offset.zero).dy;
      final below = height - top - box.size.height;
      _above = below < 480 && top > below;
      _room = (_above ? top : below) - 16;
    }
    setState(_portal.show);
  }

  void _close() {
    if (!_portal.isShowing) return;
    setState(_portal.hide);
    _returnFocus?.requestFocus();
  }

  @override
  void didUpdateWidget(_MoveLeft old) {
    super.didUpdateWidget(old);
    // Nothing left to trade with (another computer's change): it closes,
    // rather than coming back by itself later.
    if (!widget.offered && _portal.isShowing) _portal.hide();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final onMove = widget.onMove;
    if (onMove == null || !widget.offered) return widget.child;
    return TapRegion(
      groupId: _link,
      onTapOutside: (_) => _close(),
      child: CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (context) => CompositedTransformFollower(
            link: _link,
            targetAnchor: _above ? Alignment.topRight : Alignment.bottomRight,
            followerAnchor: _above ? Alignment.bottomRight : Alignment.topRight,
            offset: Offset(8, _above ? -8 : 8),
            child: Align(
              alignment: _above ? Alignment.bottomRight : Alignment.topRight,
              child: TapRegion(
                groupId: _link,
                child: _MoveBox(
                  room: _room,
                  here: widget.category,
                  left: widget.left,
                  currency: widget.currency,
                  choices: widget.choices,
                  onCancel: _close,
                  onMove: (from, to, amount) {
                    _close();
                    onMove(from, to, amount);
                  },
                ),
              ),
            ),
          ),
          child: Tooltip(
            message: widget.inward ? t.planMoveInTip : t.planMoveOutTip,
            waitDuration: const Duration(milliseconds: 600),
            child: Hoverable(
              key: ValueKey('move-left-${widget.category.id}'),
              onTap: _toggle,
              builder: (hover) {
                final lit = hover || widget.rowHover || _portal.isShowing;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  // Pulled right by its padding and edge, so the amount
                  // still ends where it did.
                  transform: Matrix4.translationValues(9, 0, 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    // Outlined, as Assigned is on hover: a click opens it.
                    border: Border.all(
                      color: lit
                          ? Mid.ink2.withValues(alpha: hover ? 0.6 : 0.4)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (lit) ...[
                        Flexible(
                          child: Text(
                            t.planMoveMoney,
                            key: ValueKey('move-label-${widget.category.id}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: onest(12.5, weight: 500, color: Mid.blue),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Flexible(child: widget.child),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The box under a Left: From, To and Amount, one side the category
/// clicked, the other chosen from a list (empty until chosen), each with
/// what it has left. More than the side it comes from has is said in plain
/// words with the real numbers, and still moves (warn, don't block).
class _MoveBox extends StatefulWidget {
  const _MoveBox({
    required this.room,
    required this.here,
    required this.left,
    required this.currency,
    required this.choices,
    required this.onMove,
    required this.onCancel,
  });

  /// How tall it can be in the window; its list takes what's spare.
  final double room;
  final AccountInfo here;
  final int left;
  final Currency currency;
  final List<_MoveChoice> choices;
  final void Function(AccountInfo? from, AccountInfo? to, int amount) onMove;
  final VoidCallback onCancel;

  @override
  State<_MoveBox> createState() => _MoveBoxState();
}

class _MoveBoxState extends State<_MoveBox> {
  late bool _inward = widget.left <= 0;

  /// What the list offers this way round: going out, Not assigned and
  /// every other category; coming in, Not assigned only while it holds
  /// money.
  List<_MoveChoice> get _offered => [
    for (final c in widget.choices)
      if (!_inward || c.category != null || c.left > 0) c,
  ];

  /// Swap: From and To change places; a choice that can't be on its new
  /// side (Not assigned with nothing in it, as From) is let go.
  void _swap() => setState(() {
    _inward = !_inward;
    _listOpen = false;
    final picked = _picked;
    if (picked != null && !_offered.contains(picked)) _picked = null;
  });
  late final _amount = TextEditingController(
    // Coming in: what it's short, the one figure the screen already says.
    text: widget.left < 0 ? typedAmount(-widget.left, widget.currency) : '',
  );
  final _focus = FocusNode(debugLabel: 'move-amount');
  _MoveChoice? _picked;
  bool _listOpen = false;

  /// Move was clicked with no category chosen, or no amount.
  bool _noPick = false;
  bool _noAmount = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      _amount.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _amount.text.length,
      );
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _money(int v) => formatMoney(v, currency: widget.currency);

  int? get _typed {
    final typed = _amount.text.trim();
    if (typed.isEmpty) return null;
    final a = parseAmount(typed, widget.currency);
    return a == null || a <= 0 ? null : a;
  }

  /// The plain words when more goes than the side it comes from has.
  String? _warning(Words t) {
    final amount = _typed;
    final picked = _picked;
    if (amount == null || (_inward && picked == null)) return null;
    final from = _inward ? picked!.category : widget.here;
    final has = _inward ? picked!.left : widget.left;
    if (amount <= has) return null;
    final short = _money(amount - has);
    if (from == null) return t.planMoveWarnNotAssigned(_money(has), short);
    return has >= 0
        ? t.planMoveWarn(from.name, _money(has), short)
        : t.planMoveWarnOver(from.name, _money(-has), short);
  }

  void _submit() {
    final amount = _typed;
    final picked = _picked;
    if (picked == null || amount == null) {
      setState(() {
        _noPick = picked == null;
        _noAmount = amount == null;
      });
      if (amount == null) _focus.requestFocus();
      return;
    }
    _inward
        ? widget.onMove(picked.category, widget.here, amount)
        : widget.onMove(widget.here, picked.category, amount);
  }

  Widget _label(String text) => SizedBox(
    width: 64,
    child: Text(text, style: onest(13, color: Mid.ink2)),
  );

  /// What a choice shows on its right: left, or overspent in coral; Not
  /// assigned its amount alone, while it has some.
  Widget _has(Words t, _MoveChoice c) {
    if (c.category == null) {
      return c.left > 0
          ? Text(_money(c.left), style: onest(13, tabular: true))
          : const SizedBox.shrink();
    }
    return c.left < 0
        ? Text(
            t.planMoveOverspent(_money(-c.left)),
            style: onest(13, color: Mid.coral, tabular: true),
          )
        : Text(
            t.planMoveLeft(_money(c.left)),
            style: onest(
              13,
              color: c.left == 0 ? Mid.ink3 : Mid.ink,
              tabular: true,
            ),
          );
  }

  String _name(Words t, _MoveChoice c) =>
      c.category?.name ?? t.planKeyNotAssigned;

  Widget _picker(Words t) {
    final picked = _picked;
    return Hoverable(
      key: const ValueKey('move-pick'),
      onTap: () => setState(() => _listOpen = !_listOpen),
      builder: (hover) => Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Mid.ground.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _noPick && picked == null
                ? Mid.coral.withValues(alpha: 0.6)
                : (_listOpen || hover ? Mid.blue : Colors.transparent),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                picked == null ? t.planMoveChoose : _name(t, picked),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: onest(13.5, color: picked == null ? Mid.ink3 : Mid.ink),
              ),
            ),
            if (picked != null) ...[_has(t, picked), const SizedBox(width: 6)],
            Icon(
              _listOpen
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Mid.ink3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(Words t) => Container(
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.all(4),
    // What's spare once the fields, a warning and the buttons are in.
    constraints: BoxConstraints(
      maxHeight: (widget.room - 240).clamp(120.0, 520.0),
    ),
    decoration: BoxDecoration(
      color: Mid.card,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Mid.rule),
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Nothing to take from: said, not an empty list (#163).
          if (_offered.isEmpty)
            Padding(
              key: const ValueKey('move-nothing'),
              padding: const EdgeInsets.all(8),
              child: Text(
                t.planMoveNothingFrom,
                style: onest(13, color: Mid.ink2),
              ),
            ),
          for (final (i, c) in _offered.indexed) ...[
            if (c.heading case final heading?)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
                child: Text(heading, style: onest(12, color: Mid.ink3)),
              ),
            Hoverable(
              key: ValueKey('move-choice-${c.category?.id ?? 'none'}'),
              onTap: () {
                setState(() {
                  _picked = c;
                  _listOpen = false;
                  _noPick = false;
                });
                // Back to the amount, so Enter moves (a click took focus
                // away from it on a Mac; #163).
                _focus.requestFocus();
              },
              builder: (hover) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: hover || identical(c, _picked)
                      ? Mid.blueWash
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _name(t, c),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: onest(13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _has(t, c),
                  ],
                ),
              ),
            ),
            // Not assigned stands apart from the categories under it.
            if (i == 0 && c.category == null && _offered.length > 1)
              Divider(height: 7, thickness: 1, color: Mid.rule),
          ],
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final here = SizedBox(
      height: 34,
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.here.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: onest(13.5, weight: 500),
            ),
          ),
          Tooltip(
            message: t.planMoveSwapTip,
            waitDuration: const Duration(milliseconds: 500),
            child: Hoverable(
              key: const ValueKey('move-swap'),
              onTap: _swap,
              builder: (hover) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swap_vert_rounded, size: 15, color: Mid.blue),
                    const SizedBox(width: 4),
                    Text(
                      t.planMoveSwap,
                      style: onest(12.5, color: Mid.blue).copyWith(
                        decoration: hover ? TextDecoration.underline : null,
                        decorationColor: Mid.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    final picker = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _picker(t),
        // Opened from the keys, its first choice takes them; ↑ ↓ walk it.
        if (_listOpen)
          Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.arrowDown): NextFocusIntent(),
              SingleActivator(LogicalKeyboardKey.arrowUp):
                  PreviousFocusIntent(),
            },
            child: focusFirstOnKeys([_list(t)]).single,
          ),
      ],
    );
    Widget line(String label, Widget field) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 34,
            child: Align(alignment: Alignment.centerLeft, child: _label(label)),
          ),
          Expanded(child: field),
        ],
      ),
    );
    final warning = _warning(t);
    // Its own focus scope: Tab stays in the box, so Esc still closes it.
    return CallbackShortcuts(
      bindings: {
        // The list first, as Edit's dropdowns close first (#163).
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_listOpen) {
            setState(() => _listOpen = false);
            _focus.requestFocus();
          } else {
            widget.onCancel();
          }
        },
        // Wherever focus is in the box, as Move does.
        const SingleActivator(LogicalKeyboardKey.enter): _submit,
      },
      child: FocusScope(
        child: Material(
          key: const ValueKey('move-box'),
          color: Mid.card,
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Mid.rule),
          ),
          child: Container(
            width: 400,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                line(t.planMoveFrom, _inward ? picker : here),
                line(t.planMoveTo, _inward ? here : picker),
                line(
                  t.planMoveAmount,
                  SizedBox(
                    height: 34,
                    child: TextField(
                      key: const ValueKey('move-amount'),
                      controller: _amount,
                      focusNode: _focus,
                      style: onest(13.5, tabular: true),
                      onChanged: (_) => setState(() => _noAmount = false),
                      onSubmitted: (_) => _submit(),
                      decoration: _fieldDecoration(wrong: _noAmount).copyWith(
                        prefixText: widget.currency.prefix,
                        prefixStyle: onest(13.5, color: Mid.ink3),
                      ),
                    ),
                  ),
                ),
                if (_noAmount)
                  Padding(
                    padding: const EdgeInsets.only(left: 64, bottom: 10),
                    child: Text(
                      t.planMoveEnterAmount,
                      style: onest(12.5, color: Mid.coral),
                    ),
                  ),
                // Said as a missing amount is, not only outlined (#163).
                if (_noPick && _picked == null)
                  Padding(
                    padding: const EdgeInsets.only(left: 64, bottom: 10),
                    child: Text(
                      t.planMoveChooseCategory,
                      key: const ValueKey('move-choose'),
                      style: onest(12.5, color: Mid.coral),
                    ),
                  ),
                if (warning != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      warning,
                      key: const ValueKey('move-warning'),
                      style: onest(13, color: Mid.ink, tabular: true),
                    ),
                  ),
                Row(
                  children: [
                    const Spacer(),
                    BarButton(
                      key: const ValueKey('move-cancel'),
                      label: t.planCancel,
                      onTap: widget.onCancel,
                    ),
                    _PrimaryButton(
                      key: const ValueKey('move-go'),
                      label: t.planMoveButton,
                      icon: Icons.arrow_forward_rounded,
                      tooltip: 'Enter',
                      onTap: _submit,
                    ),
                  ],
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
  required VoidCallback? onDelete,
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
    if (onDelete != null)
      item(t.planDeleteMenu, 'category-delete', onDelete, color: Mid.coral),
  ];
}

/// What Add did in the New category window: made the category, opened
/// the one already called that, or nothing (the window stays as it was).
enum _Added { made, opened, none }

/// The id a category not made yet has in its window: never a real one.
const _newCategoryId = -1;

/// The New category window (owner, 2026-10-22, #237): everything a new
/// category can have, asked as its Edit asks it, and Add another to set up
/// several in one go. Esc, Cancel or a click outside close it; what was
/// added stays.
class _NewCategoryWindow extends StatefulWidget {
  const _NewCategoryWindow({
    required this.data,
    required this.period,
    required this.today,
    required this.currencies,
    required this.currency,
    required this.nameNote,
    required this.onAdd,
    this.name = '',
    this.offerAnother = true,
  });

  /// The name it starts with: what was typed in the entry row's Category.
  final String name;

  /// Add another beside Add: on the Budget page, not from a row, which
  /// takes the one category.
  final bool offerAnother;

  /// The ledger as it is now: after an Add, with that category in it.
  final LedgerData Function() data;
  final BudgetSpan period;
  final DateTime today;
  final List<Currency> currencies;

  /// The currency it starts in.
  final Currency currency;
  final ({String text, bool blocks})? Function(String name) nameNote;
  final Future<_Added> Function(_CategoryEdit) onAdd;

  @override
  State<_NewCategoryWindow> createState() => _NewCategoryWindowState();
}

class _NewCategoryWindowState extends State<_NewCategoryWindow> {
  /// What Add another has made so far: the only sign of it, since the
  /// window stays open.
  final _added = <String>[];

  /// Kept from one to the next: chosen, not guessed. Everything else
  /// starts over, so a bill's Yes doesn't carry into Food unseen.
  late Currency _currency = widget.currency;

  /// Each Add another starts a fresh form.
  int _round = 0;

  Future<bool> _add(_CategoryEdit e, {required bool another}) async {
    final added = await widget.onAdd(e);
    if (!mounted || added == _Added.none) return false;
    if (added == _Added.opened || !another) {
      Navigator.of(context).pop();
      return true;
    }
    setState(() {
      _added.add(e.name);
      _currency = e.currency;
      _round++;
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Dialog(
      // A shade off the row inside it, which is drawn as it will read.
      backgroundColor: Mid.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.phoneNewCategoryTitle, style: onest(20, weight: 700)),
              if (_added.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    t.planNewAdded(_added.join(' · ')),
                    key: const ValueKey('new-category-added'),
                    style: onest(12.5, color: Mid.ink2),
                  ),
                ),
              const SizedBox(height: 18),
              _CategoryEditor(
                key: ValueKey('new-category-$_round'),
                category: AccountInfo(
                  id: _newCategoryId,
                  name: _round == 0 ? widget.name : '',
                  type: AccountType.expense,
                  currency: _currency,
                ),
                data: widget.data(),
                period: widget.period,
                today: widget.today,
                assigned: 0,
                holds: null,
                currencies: widget.currencies,
                usage: null,
                atPlan: false,
                onSave: (_) {},
                onCancel: () => Navigator.of(context).pop(),
                onArchive: () {},
                onShowAllRows: () {},
                onAdd: _add,
                offerAnother: widget.offerAnother,
                nameNote: widget.nameNote,
              ),
            ],
          ),
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
    required this.rows,
    required this.targets,
    this.into,
  });
  final AccountInfo category;
  final CategoryUsage? usage;

  /// Its rows as the database counts them: more than [usage] says when
  /// rows came in (another computer's) since the page was drawn.
  final int rows;
  final List<AccountInfo> targets;
  final AccountInfo? into;

  @override
  State<_DeleteCategoryDialog> createState() => _DeleteCategoryDialogState();
}

class _DeleteCategoryDialogState extends State<_DeleteCategoryDialog> {
  // A default, not a required choice (owner, 2026-09-18): the rows wait
  // in Not categorized unless another is picked (#163).
  late AccountInfo? _into =
      widget.into ?? widget.targets.where(isUncategorized).firstOrNull;

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
        widget.rows == 0 ? t.planNothingFiled : t.planRowsFiled(widget.rows)
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
                Text(kindNote, style: onest(13, color: Mid.note)),
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

  /// [next] is 1 for the row after, -1 for the row before, 0 to stay.
  final void Function(int? amount, {required int next}) onDone;

  @override
  State<_AssignField> createState() => _AssignFieldState();
}

class _AssignFieldState extends State<_AssignField> {
  TextEditingController? _text;
  final _focus = FocusNode(debugLabel: 'put-in');

  /// The amount shown, as a Tab stop: Enter or Esc gives focus back to it,
  /// not to the top of the window (#163).
  final _cell = FocusNode(debugLabel: 'assigned');
  bool _wrong = false;

  /// Ended by a key already: losing focus afterwards mustn't end it again.
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _text != null && !_done) _finish(next: 0);
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
          (_) => done(amount, next: 0),
        );
      }
      _close();
    }
  }

  @override
  void dispose() {
    _text?.dispose();
    _focus.dispose();
    _cell.dispose();
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

  /// After the parent's own keys-back, so this wins.
  void _focusCell() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _cell.requestFocus();
  });

  void _finish({required int next, bool back = false}) {
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
    if (back) _focusCell();
  }

  void _cancel() {
    _done = true;
    widget.onDone(null, next: 0);
    _focusCell();
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
                _finish(next: 1),
            const SingleActivator(LogicalKeyboardKey.tab, shift: true): () =>
                _finish(next: -1),
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
            onSubmitted: (_) => _finish(next: 0, back: true),
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
        focusNode: _cell,
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

/// The note after the first amount lands in a period already under
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
  final PlanNote note;
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
                // A sentence with an amount wraps rather than being cut
                // (ADR 0004 "No overflow stripe"); Left took some width.
                builder: (hover) => Text(
                  note.text,
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
                color: note.behind ? Mid.ink : Mid.ink2,
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
      menuChildren: focusFirstOnKeys(
        !_searchable
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
      ),
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
  final mine = categoryAccounts(data, c.currency).toList();
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
        color: Mid.note,
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
        color: Mid.note,
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
    this.onAdd,
    this.offerAnother = false,
    this.nameNote,
    this.keep,
  });

  /// Where what's typed is kept while the page is left; null in the New
  /// category window, whose answers are its own.
  final _EditDraft? keep;

  /// The category, or for the New category window one not made yet: its
  /// id isn't a real one, and its currency is where the window starts.
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

  /// The New category window (owner, 2026-10-22, #237): Add in place of
  /// Save, and no usage or Archive. Adds [e], and the window closes unless
  /// [another]; false when nothing was made, so the answers stay. Null in
  /// a category's Edit.
  final Future<bool> Function(_CategoryEdit e, {required bool another})? onAdd;

  /// Add another beside Add: on the Budget page, not where a row takes
  /// the one category.
  final bool offerAnother;

  /// What's said under the name as it's typed: it's taken, and what Add
  /// does then. [blocks]: Add can't go ahead with it.
  final ({String text, bool blocks})? Function(String name)? nameNote;

  bool get isNew => onAdd != null;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final _d = widget.keep ?? _EditDraft(widget.category, widget.today);
  TextEditingController get _name => _d.name;

  /// The plan's answers, and what they add up to: the phone's New
  /// category page asks the same.
  PlanAnswers get _p => _d.p;
  final _nameFocus = FocusNode(debugLabel: 'category-name');
  final _amountFocus = FocusNode(debugLabel: 'plan-amount');
  final _dateFocus = FocusNode(debugLabel: 'plan-date');
  final _upToFocus = FocusNode(debugLabel: 'plan-up-to');
  final _datesFocus = FocusNode(debugLabel: 'plan-dates');
  final _repeatMenu = MenuController();
  final _eachMenu = MenuController();

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

  /// Around the panel, as the Move box has: Tab goes round its fields and
  /// buttons, not on to the rows under it (#163). [_panelFocus] is the
  /// panel itself, inside it.
  final _panelScope = FocusScopeNode(debugLabel: 'category-editor-scope');

  Currency get _currency => _p.currency;
  set _currency(Currency c) => _p.currency = c;
  Set<int> get _off => _d.off ??= {..._savedOff};
  set _off(Set<int> off) => _d.off = off;

  /// The category as the panel has it: a new one is in whatever currency
  /// is picked, and called what's typed.
  AccountInfo get _cat => widget.isNew
      ? AccountInfo(
          id: widget.category.id,
          name: _name.text.trim(),
          type: AccountType.expense,
          currency: _currency,
        )
      : widget.category;

  /// The account a dated plan's bill is scheduled in: the one account the
  /// category is paid from, when it's narrowed to one. One control says
  /// both (owner, 2026-10-05: "two account selectors: just have one").
  int? get _paidFromNow {
    if (!_p.hasDate) return null;
    final used = categoryAccounts(
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
  CategoryPlan? get _plan => _currency == _cat.currency ? _savedPlan : null;

  @override
  void initState() {
    super.initState();
    // Kept from before the page was left: the answers are already in.
    if (!_d.filled) _showPlan(_savedPlan);
    _d.filled = true;
    final atPlan = widget.atPlan;
    final first = atPlan ? _p.amount : _name;
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
    if (widget.keep == null) _d.dispose();
    _nameFocus.dispose();
    _amountFocus.dispose();
    _dateFocus.dispose();
    _upToFocus.dispose();
    _datesFocus.dispose();
    _panelFocus.dispose();
    _panelScope.dispose();
    super.dispose();
  }

  /// Fills the plan's fields from [p], or empties them.
  void _showPlan(CategoryPlan? p) =>
      _p.show(p, periodPayId: widget.data.periodSchedule?.id);

  void _pickDated(bool yes) {
    setState(() {
      _p.hasDate = yes;
      _tried = false;
    });
    _p.amount.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _p.amount.text.length,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _amountFocus.requestFocus();
    });
  }

  /// The plan as typed. Null with a kind picked means something is missing.
  CategoryPlan? get _draft => _p.draft(
    categoryId: widget.category.id,
    paidFrom: _paidFromNow,
    old: _plan,
  );

  Future<void> _save({bool another = false}) async {
    if (_done) return;
    final name = _name.text.trim();
    if (name.isEmpty || (widget.nameNote?.call(name)?.blocks ?? false)) {
      setState(() => _tried = true);
      _nameFocus.requestFocus();
      return;
    }
    final draft = _draft;
    if (_p.kind != null && draft == null) {
      setState(() => _tried = true);
      (_p.typedAmount == null
              ? _amountFocus
              : !_p.hasDate
              ? _upToFocus
              : _p.repeat == PlanRepeat.dates
              ? _datesFocus
              : _dateFocus)
          .requestFocus();
      return;
    }
    _done = true;
    final edit = (name: name, currency: _currency, off: _off, plan: draft);
    final add = widget.onAdd;
    if (add == null) return widget.onSave(edit);
    final made = await add(edit, another: another);
    // Not made: the answers stay, to be changed and added again.
    if (!made && mounted) _done = false;
  }

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

  void _preset(int n, PlanUnit unit) => setState(() => _p.preset(n, unit));

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
    final wrongAmount = _tried && _p.kind != null && _p.typedAmount == null;
    final wrongDate = _tried && _p.hasDate && _p.typedDate == null;
    final wrongUpTo = _tried && !_p.hasDate && _p.wrongUpTo;
    final data = widget.data;
    final paidAccount = data.accounts[_paidFromNow];
    final hasAmount = _p.amount.text.trim().isNotEmpty;
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
        menuChildren: focusFirstOnKeys(items),
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
              // The panel itself, not the field it last had: a scope given
              // focus hands it back to that.
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
    final byPay = _p.eachPayId != null;
    final eachLabel = byPay ? t.planSetAsidePay : t.planSetAsideMonth;
    // What a dated plan comes to each period: the amount alone (owner,
    // 2026-10-22: "Remove 'worked out from the date'").
    final String part;
    if (draft == null) {
      part = t.planEnterAmountDate;
    } else if ((line?.plan?.each ?? 0) > 0) {
      part = money(line!.plan!.each);
    } else {
      part = t.planNothingMore;
    }
    final due = line?.plan?.due ?? _p.typedDate;
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
            ('plan-dated-no', t.planNo, !_p.hasDate, () => _pickDated(false)),
            ('plan-dated-yes', t.planYes, _p.hasDate, () => _pickDated(true)),
          ],
        ),
        // What the answer picked means, in one example (owner, 2026-10-05:
        // "What happens if there isn't a due date?").
        aside: _p.hasDate
            ? t.planDueYesMeans
            : byPay
            ? t.planDueNoMeansPay
            : t.planDueNoMeans,
      ),
      if (!_p.hasDate) ...[
        _formRow(
          eachLabel,
          amountField(
            _p.amount,
            _amountFocus,
            key: 'plan-amount',
            wrong: wrongAmount,
            autofocus: widget.atPlan,
            // No hint: the note beside it says what empty means (#163).
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
        if (data.paySchedules.isNotEmpty || _p.eachPayId != null)
          _formRow(
            t.planHowOften,
            menu(
              _eachMenu,
              key: 'plan-each-period',
              label: switch (data.payScheduleById(_p.eachPayId)) {
                null => t.planRepeatMonths(1),
                final pay => planEachPayLabel(t, widget.data, pay),
              },
              items: [
                item(
                  'plan-each-month',
                  t.planRepeatMonths(1),
                  on: _p.eachPayId == null,
                  onTap: () => setState(() => _p.eachPayId = null),
                ),
                for (final pay in [
                  ...data.paySchedules,
                  if (data.payScheduleById(_p.eachPayId) case final p?
                      when !data.paySchedules.any((x) => x.id == p.id))
                    p,
                ])
                  item(
                    'plan-each-pay-${pay.id}',
                    planEachPayLabel(t, widget.data, pay),
                    on: _p.eachPayId == pay.id,
                    onTap: () => setState(() => _p.eachPayId = pay.id),
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
                  _p.rollover,
                  () => setState(() => _p.rollover = true),
                ),
                (
                  'plan-carry-off',
                  t.planGoesBack,
                  !_p.rollover,
                  () => setState(() => _p.rollover = false),
                ),
              ],
            ),
          ),
          if (_p.rollover && hasAmount)
            _formRow(
              t.planStopAt,
              amountField(
                _p.upTo,
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
            _p.amount,
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
                label: planRepeatLabel(t, widget.data, _p),
                items: [
                  item(
                    'plan-repeat-0',
                    t.planOnce,
                    on: _p.repeat == PlanRepeat.once,
                    onTap: () => setState(() => _p.repeat = PlanRepeat.once),
                  ),
                  for (final (key, n, unit, label) in [
                    ('plan-repeat-d7', 1, PlanUnit.weeks, t.planRepeatWeeks(1)),
                    (
                      'plan-repeat-d14',
                      2,
                      PlanUnit.weeks,
                      t.planRepeatWeeks(2),
                    ),
                    (
                      'plan-repeat-1',
                      1,
                      PlanUnit.months,
                      t.planRepeatMonths(1),
                    ),
                    (
                      'plan-repeat-3',
                      3,
                      PlanUnit.months,
                      t.planRepeatMonths(3),
                    ),
                    ('plan-repeat-12', 1, PlanUnit.years, t.planRepeatYears(1)),
                  ])
                    item(
                      key,
                      label,
                      on:
                          _p.repeat == PlanRepeat.every &&
                          !_p.custom &&
                          _p.unit == unit &&
                          _p.typedEveryN == n,
                      onTap: () => _preset(n, unit),
                    ),
                  // Payday by payday: only with pay set up.
                  for (final pay in data.paySchedules)
                    item(
                      'plan-repeat-pay-${pay.id}',
                      planPaydayLabel(t, widget.data, pay),
                      on:
                          _p.repeat == PlanRepeat.payday &&
                          _p.payScheduleId == pay.id,
                      onTap: () => setState(() {
                        _p.repeat = PlanRepeat.payday;
                        _p.payScheduleId = pay.id;
                      }),
                    ),
                  item(
                    'plan-repeat-custom',
                    t.planEveryCustom,
                    on: _p.repeat == PlanRepeat.every && _p.custom,
                    onTap: () => setState(() {
                      _p.repeat = PlanRepeat.every;
                      _p.custom = true;
                    }),
                  ),
                  item(
                    'plan-repeat-dates',
                    t.planOnDates,
                    on: _p.repeat == PlanRepeat.dates,
                    onTap: () => setState(() => _p.repeat = PlanRepeat.dates),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_p.repeat == PlanRepeat.payday)
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
                    controller: _p.daysAfter,
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
            aside: _p.daysAfterNow == 0 ? t.planOnPayday : null,
          )
        else
          _formRow(
            _p.repeat == PlanRepeat.dates
                ? t.planDatesLabel
                : t.planLabelDueDate,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_p.repeat == PlanRepeat.dates)
                  SizedBox(
                    width: 300,
                    height: 34,
                    child: TextField(
                      key: const ValueKey('plan-dates'),
                      controller: _p.dates,
                      focusNode: _datesFocus,
                      style: onest(13.5, tabular: true),
                      onSubmitted: (_) => _save(),
                      decoration:
                          _fieldDecoration(
                            wrong:
                                _tried &&
                                (_p.typedDates == null ||
                                    _p.typedDates!.isEmpty),
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
                      controller: _p.date,
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
                if (_p.repeat != PlanRepeat.once && _p.weekdaysNow == null) ...[
                  const SizedBox(width: 10),
                  menu(
                    _weekendMenu,
                    key: 'plan-weekend',
                    label: planWeekendLabel(t, _p.weekend),
                    items: [
                      for (final w in PayWeekend.values)
                        item(
                          'plan-weekend-${w.name}',
                          planWeekendLabel(t, w),
                          on: w == _p.weekend,
                          onTap: () => setState(() => _p.weekend = w),
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
        if (_p.customOn) ...[
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
                    controller: _p.everyN,
                    textAlign: TextAlign.center,
                    style: onest(13.5, tabular: true),
                    onSubmitted: (_) => _save(),
                    decoration: _fieldDecoration(
                      wrong: _tried && _p.typedEveryN == null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                menu(
                  _unitMenu,
                  key: 'plan-every-unit',
                  label: planUnitLabel(t, _p.unit),
                  items: [
                    for (final u in PlanUnit.values)
                      item(
                        'plan-every-unit-${u.name}',
                        planUnitLabel(t, u),
                        on: u == _p.unit,
                        onTap: () => setState(() => _p.unit = u),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (_p.unit == PlanUnit.weeks)
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
                      on: _p.weekdays.contains(i + 1),
                      onTap: () => setState(
                        () => _p.weekdays.contains(i + 1)
                            ? _p.weekdays.remove(i + 1)
                            : _p.weekdays.add(i + 1),
                      ),
                    ),
                ],
              ),
              aside: _p.weekdays.isEmpty ? t.planWeekdaysHint : null,
            ),
          if (_p.unit == PlanUnit.months || _p.unit == PlanUnit.years)
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
                        !_p.nthOn,
                        () => setState(() => _p.nthOn = false),
                      ),
                      (
                        'plan-nth-on',
                        t.planAWeekday,
                        _p.nthOn,
                        () => setState(_p.startNth),
                      ),
                    ],
                  ),
                  if (_p.nthOn) ...[
                    const SizedBox(width: 8),
                    menu(
                      _nthMenu,
                      key: 'plan-nth',
                      label: planNthLabel(t, _p.nth),
                      items: [
                        for (final n in const [1, 2, 3, 4, -1])
                          item(
                            'plan-nth-$n',
                            planNthLabel(t, n),
                            on: n == _p.nth,
                            onTap: () => setState(() => _p.nth = n),
                          ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    menu(
                      _nthWeekdayMenu,
                      key: 'plan-nth-weekday',
                      label: planWeekdayName(t, _p.nthWeekday),
                      items: [
                        for (var wd = 1; wd <= 7; wd++)
                          item(
                            'plan-nth-weekday-$wd',
                            planWeekdayName(t, wd),
                            on: wd == _p.nthWeekday,
                            onTap: () => setState(() => _p.nthWeekday = wd),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
        if (_p.endsOn)
          _formRow(
            t.planEnds,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Segmented(
                  items: [
                    for (final (e, label) in [
                      (PlanEnds.never, t.planEndsNever),
                      (PlanEnds.date, t.planEndsOn),
                      (PlanEnds.count, t.planEndsAfter),
                    ])
                      (
                        'plan-ends-${e.name}',
                        label,
                        _p.ends == e,
                        () => setState(() => _p.ends = e),
                      ),
                  ],
                ),
                if (_p.ends == PlanEnds.date) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 130,
                    height: 34,
                    child: TextField(
                      key: const ValueKey('plan-end-date'),
                      controller: _p.endDate,
                      style: onest(13.5, tabular: true),
                      onSubmitted: (_) => _save(),
                      decoration:
                          _fieldDecoration(
                            wrong: _tried && _p.typedEndDate == null,
                          ).copyWith(
                            hintText: t.planEndDateHint,
                            hintStyle: onest(13.5, color: Mid.ink3),
                          ),
                    ),
                  ),
                ],
                if (_p.ends == PlanEnds.count) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 56,
                    height: 34,
                    child: TextField(
                      key: const ValueKey('plan-end-count'),
                      controller: _p.endCount,
                      textAlign: TextAlign.center,
                      style: onest(13.5, tabular: true),
                      onSubmitted: (_) => _save(),
                      decoration: _fieldDecoration(
                        wrong: _tried && _p.typedEndCount == null,
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
              : switch (categoryAccounts(
                  data,
                  _currency,
                ).where((a) => !_off.contains(a.id)).toList()) {
                  [] => t.planPaidFromNoneChecked,
                  // One checked, no date yet: what's left to do (#163).
                  [final one] => t.planPaidFromHintNone(one.name),
                  final n => t.planPaidFromSeveral(n.length),
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
                if (x == c.currency && !widget.isNew) {
                  _showPlan(_savedPlan);
                } else {
                  _p.amount.clear();
                }
              });
              if (_p.hasDate) _amountFocus.requestFocus();
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
    final accounts = categoryAccounts(widget.data, _currency).toList();
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
          menuChildren: focusFirstOnKeys([
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
          ]),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: BarButton(
              key: const ValueKey('money-accounts'),
              // "All accounts" only when there's more than one: with
              // one it's named (owner, 2026-10-07).
              label: used.length == accounts.length && accounts.length > 1
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
    final c = _cat;
    // A new category isn't in the ledger yet: put in, for its row.
    final data = widget.isNew ? widget.data.withCategory(c) : widget.data;
    String say(int v) => formatShort(v, currency: _currency);

    return ListenableBuilder(
      listenable: Listenable.merge([
        _name,
        _p.amount,
        _p.date,
        _p.upTo,
        _p.everyN,
        _p.dates,
        _p.daysAfter,
        _p.endDate,
        _p.endCount,
      ]),
      builder: (context, _) {
        final draft = _draft;
        // What went back in earlier periods returns to the category when
        // it carries over again: said before it's saved.
        String? returns;
        // The category as the answers so far make it: the row drawn as
        // it will read, and a dated plan's part.
        EnvelopeLine? line;
        PlanNote? note;
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
              draft != null || (_p.kind == null && _savedPlan != null);
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
            note = planNote(
              t,
              line!,
              widget.period,
              widget.today,
              _currency,
              payName: ownPayName(t, data, line.plan!.plan),
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

        final accounts = categoryAccounts(data, _currency).toList();
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
          _p.hasDate,
          _p.kind,
          accounts.length,
          preview != null,
          returns != null,
          rest != null,
          loses,
          _p.repeat,
          _p.customOn,
          _p.unit,
          _p.endsOn,
          _p.ends,
          _p.nthOn,
        );
        if (shape != _shape) {
          _shape = shape;
          _revealSoon();
        }

        // Under the name: it's taken, and what Add does then; or, Add
        // tried with nothing typed, that it needs one.
        final typedName = _name.text.trim();
        final taken = typedName.isEmpty
            ? null
            : widget.nameNote?.call(typedName);
        final String? nameNote =
            taken?.text ??
            (widget.isNew && _tried && typedName.isEmpty
                ? t.planEnterName
                : null);
        final nameNoteColor = taken == null || taken.blocks
            ? Mid.coral
            : Mid.ink2;

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
            if (widget.offerAnother) ...{
              const SingleActivator(LogicalKeyboardKey.enter, meta: true): () {
                if (!_closeMenu()) _save(another: true);
              },
              const SingleActivator(
                LogicalKeyboardKey.enter,
                control: true,
              ): () {
                if (!_closeMenu()) _save(another: true);
              },
            },
          },
          child: FocusScope(
            node: _panelScope,
            child: Focus(
              focusNode: _panelFocus,
              skipTraversal: true,
              // A click on a choice in the panel leaves the cursor where
              // it is.
              child: TextFieldTapRegion(
                // In the window, the window is its card.
                child: Container(
                  margin: widget.isNew
                      ? EdgeInsets.zero
                      : const EdgeInsets.fromLTRB(0, 2, 0, 10),
                  padding: widget.isNew
                      ? EdgeInsets.zero
                      : const EdgeInsets.all(12),
                  decoration: widget.isNew
                      ? null
                      : BoxDecoration(
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
                                        contentPadding:
                                            const EdgeInsets.fromLTRB(
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
                                          borderSide: BorderSide(
                                            color: Mid.blue,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ..._currencyChoice(t),
                              ],
                            ),
                            if (nameNote != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  nameNote,
                                  key: const ValueKey('edit-name-note'),
                                  style: onest(12.5, color: nameNoteColor),
                                ),
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
                                                // Amounts and dates: smaller
                                                // rather than cut.
                                                Flexible(
                                                  child: Shrink(
                                                    Text(
                                                      preview,
                                                      key: const ValueKey(
                                                        'plan-preview',
                                                      ),
                                                      maxLines: 1,
                                                      style: onest(
                                                        12.5,
                                                        color: note!.behind
                                                            ? Mid.ink
                                                            : Mid.ink2,
                                                        tabular: true,
                                                      ),
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
                                                      // The row as it will
                                                      // read, but not a link
                                                      // here: it does nothing
                                                      // until saved (#163).
                                                      style: onest(
                                                        12.5,
                                                        color: Mid.ink3,
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
                        warning(returns, 'plan-returns', Mid.note),
                      if (paidArchived != null)
                        warning(paidArchived, 'plan-paid-archived', Mid.note),
                      if (rest != null) warning(rest, 'money-rest', Mid.ink2),
                      if (loses)
                        warning(
                          _moneyChange(t, c, assigned, hasPlan),
                          'money-change',
                          Mid.note,
                        ),
                      const SizedBox(height: 12),
                      if (widget.isNew)
                        Row(
                          children: [
                            const Spacer(),
                            BarButton(
                              key: const ValueKey('new-category-cancel'),
                              label: t.planCancel,
                              onTap: widget.onCancel,
                            ),
                            if (widget.offerAnother)
                              Tooltip(
                                message: _isMac ? '⌘↩' : 'Ctrl+Enter',
                                waitDuration: const Duration(milliseconds: 600),
                                child: BarButton(
                                  key: const ValueKey('new-category-another'),
                                  label: t.planAddAnother,
                                  onTap: () => _save(another: true),
                                ),
                              ),
                            _PrimaryButton(
                              key: const ValueKey('new-category-add'),
                              label: t.planAdd,
                              icon: Icons.add_rounded,
                              tooltip: 'Enter',
                              onTap: _save,
                            ),
                          ],
                        )
                      else
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
                            if (!isSafetyNet(widget.category))
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

/// A category's Edit as typed: its name, its plan's answers and the
/// accounts it's paid from.
class _EditDraft {
  _EditDraft(AccountInfo c, DateTime today)
    : id = c.id,
      name = TextEditingController(text: c.name),
      p = PlanAnswers(today: today, currency: c.currency);
  final int id;
  final TextEditingController name;
  final PlanAnswers p;

  /// The accounts unticked; null until Edit first asks.
  Set<int>? off;

  /// The answers were filled from the saved plan.
  bool filled = false;

  void dispose() {
    name.dispose();
    p.dispose();
  }
}

/// The open Edit's [_EditDraft], held by the screen across pages.
class _EditKeep {
  _EditDraft? draft;

  _EditDraft of(AccountInfo c, DateTime today) {
    if (draft?.id != c.id) clear();
    return draft ??= _EditDraft(c, today);
  }

  /// A frame later: the fields may still be on screen this frame.
  void clear() {
    final d = draft;
    if (d == null) return;
    draft = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => d.dispose());
  }
}
