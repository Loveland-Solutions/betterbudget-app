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
  // The account it's paid from (#180); null only with none in its currency.
  int? paidFrom,
  CategoryPlan? plan,
  // Counts in Savings' month of expenses ([inMonthOfExpenses]).
  bool inMonth,
  // Shown on Savings as a goal ([isGoal]): an amount by a date.
  bool goal,
  // Picked as a Fund with no amount set ([BudgetKeys.fund], #429).
  bool fund,
  // Its group on the Budget page and its note (#100): null for none.
  String? group,
  String? note,
});

class _BudgetPage extends StatefulWidget {
  const _BudgetPage({
    super.key,
    required this.data,
    required this.today,
    required this.onSave,
    required this.onArchive,
    required this.onDelete,
    required this.onEmoji,
    required this.onPay,
    required this.onAskAgain,
    required this.onAdd,
    required this.nameNote,
    required this.onUnarchive,
    required this.onShowRows,
    required this.onShowAllRows,
    required this.onShowPeriodRows,
    required this.onSetAmount,
    required this.onKeysBack,
    required this.onStartLater,
    required this.onKeepStart,
    required this.onAssignPlanned,
    required this.onClearAssigned,
    required this.onMove,
    required this.onSkipBill,
    required this.onBringBackBill,
    required this.onEditOpens,
    required this.keep,
    required this.onAssignStep,
    required this.onShowSavings,
    required this.onAddPaying,
    required this.onWalkPass,
  });

  /// The walkthrough's Add the bill that pays a credit card or loan: the
  /// category made, and the account's payments come out of it, one undo.
  final Future<_Added> Function(AccountInfo loan, _CategoryEdit e) onAddPaying;

  /// The walkthrough's That's all or Not now: the setting it writes, and
  /// what undo calls it.
  final void Function(String key, String label) onWalkPass;

  /// The step band's Assign: the Safety net's new total in the period
  /// today is in, what undo calls it, and what the popup says when that
  /// fills the step.
  final void Function(
    AccountInfo category,
    int total,
    String undo,
    String? full,
  )
  onAssignStep;

  /// The step band's name was clicked.
  final VoidCallback onShowSavings;

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

  /// An emoji was picked before a category's name, or taken off (null):
  /// the category is renamed (#486).
  final void Function(AccountInfo c, String? emoji) onEmoji;

  /// Skip this bill, on a category's line: the bill's date and what the
  /// category has left (#357).
  final Future<void> Function(AccountInfo category, DateTime due, int left)
  onSkipBill;

  /// Bring it back, on a line that says there's no bill on a date.
  final Future<void> Function(AccountInfo category, DateTime date)
  onBringBackBill;

  /// Income tab: a pay's Edit, or Add pay (null).
  final ValueChanged<PaySchedule?> onPay;

  /// Income tab: "Ask me again" after "I don't have regular pay".
  final VoidCallback onAskAgain;

  /// "Assign what's planned": each category's new Assigned for the period.
  final void Function(BudgetSpan, Map<AccountInfo, int>) onAssignPlanned;

  /// "Clear October's Assigned", after its window: these categories'
  /// amounts in the period go back to Not assigned (#100). [done] is what
  /// the popup and undo say.
  final void Function(BudgetSpan, List<AccountInfo>, String done)
  onClearAssigned;

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

  /// The totals row's Spent was clicked: every row in the period (#273).
  final ValueChanged<BudgetSpan> onShowPeriodRows;

  /// Add in the New category window: the category made with everything
  /// set in it, or the one already called that opened in Edit.
  final Future<_Added> Function(_CategoryEdit) onAdd;

  /// What the window says under a name that's taken.
  final ({String text, bool blocks})? Function(String name) nameNote;
  final ValueChanged<AccountInfo> onUnarchive;

  /// A Put in amount was typed for the period starting on the date.
  final void Function(AccountInfo, BudgetSpan, int) onSetAmount;

  @override
  State<_BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<_BudgetPage> {
  bool _showArchived = false;

  /// The Savings steps as of [_stepsOf]'s ledger and day, for the band
  /// under the sum: worked out once per ledger, not on every key typed.
  Readiness? _steps;
  (LedgerData, DateTime)? _stepsOf;
  Readiness get _readiness {
    final of = (widget.data, widget.today);
    if (_steps case final r?
        when identical(_stepsOf?.$1, of.$1) && _stepsOf?.$2 == of.$2) {
      return r;
    }
    _stepsOf = of;
    return _steps = Readiness.of(widget.data, widget.today);
  }

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

  /// The Spending list's, which the section names over its rows follow.
  final _listScroll = ScrollController();
  FocusNode _dotsOf(int id) =>
      _dots.putIfAbsent(id, () => FocusNode(debugLabel: 'category-menu'));

  @override
  void dispose() {
    for (final f in _dots.values) {
      f.dispose();
    }
    _listScroll.dispose();
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
  /// [type] is the card it opens on; [paying] a credit card or loan whose
  /// payments come out of what's made (#475).
  void _newCategory({CategoryType? type, AccountInfo? paying}) {
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
        startType: type,
        offerAnother: paying == null,
        onAdd: paying == null
            ? widget.onAdd
            : (e) => widget.onAddPaying(paying, e),
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
    final saved = fundCategoryIds(data, savingsCurrency(data));
    final listed = data.categories
        .where((c) => !c.isIncome && !isUncategorized(c))
        .toList();
    // In sections by type (owner, 2026-11-15, #469): Day-to-day, Funds,
    // Bills, Goals, each saying once what its Left is; the safety net
    // last, under Saved (#274).
    CategoryType typeIn(AccountInfo c) => typeOf(data, c.id);
    bool isBill(AccountInfo c) {
      final type = typeIn(c);
      return type == CategoryType.bill || type == CategoryType.goal;
    }

    String typeName(CategoryType type) => switch (type) {
      CategoryType.dayToDay => t.planTypeDay,
      CategoryType.fund => t.planFunds,
      CategoryType.bill => t.phoneBills,
      CategoryType.goal => t.goalsTitle,
    };

    // Day-to-day: the ones in no group first, then each group the person
    // made under its name (#100), A to Z; inside each, by name.
    final everyday = listed
        .where(
          (c) => !saved.contains(c.id) && typeIn(c) == CategoryType.dayToDay,
        )
        .toList();
    // "Food" and "food" (two computers) are one heading, as first spelt.
    String? groupOf(AccountInfo c) => c.budgetGroup?.toLowerCase();
    final groups = <String, String>{
      for (final g in [for (final c in everyday.reversed) ?c.budgetGroup])
        g.toLowerCase(): g,
    };
    final groupKeys = groups.keys.toList()..sort();
    // Bills and goals (#466): one behind first, then by the day this
    // period saves for, soonest first; paid, reached or ended last, as
    // there's nothing more to do for them (budget review). Then by name.
    List<AccountInfo> byDue(CategoryType type) {
      final xs = listed
          .where((c) => !saved.contains(c.id) && typeIn(c) == type)
          .toList();
      int rank(AccountInfo c) {
        final line = budget.lines[c.id];
        final p = line?.plan;
        if (line == null || p == null) return 2;
        if (line.short > 0) return 0;
        if (line.paidOn != null || p.done || p.ended) return 2;
        return 1;
      }

      DateTime? dueOf(AccountInfo c) => budget.lines[c.id]?.plan?.due;
      return xs..sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        final (da, db) = (dueOf(a), dueOf(b));
        if (da != null && db != null && da != db) return da.compareTo(db);
        if ((da == null) != (db == null)) return da == null ? 1 : -1;
        return compareNames(a.name, b.name);
      });
    }

    final sections = [
      (
        CategoryType.dayToDay,
        [
          ...everyday.where((c) => c.budgetGroup == null),
          for (final g in groupKeys) ...everyday.where((c) => groupOf(c) == g),
        ],
      ),
      (
        CategoryType.fund,
        listed
            .where(
              (c) => !saved.contains(c.id) && typeIn(c) == CategoryType.fund,
            )
            .toList(),
      ),
      (CategoryType.bill, byDue(CategoryType.bill)),
      (CategoryType.goal, byDue(CategoryType.goal)),
    ];
    final spending = [
      for (final (_, xs) in sections) ...xs,
      ...listed.where((c) => saved.contains(c.id)),
    ];
    // Where each group's heading goes.
    final groupAt = {
      for (final g in groupKeys)
        spending.indexWhere((c) => everyday.contains(c) && groupOf(c) == g):
            groups[g]!,
    };
    final firstSaved = spending.indexWhere((c) => saved.contains(c.id));
    // Where each section's heading goes: only with two sections or more
    // (Saved one of them), as one alone would be a label that says
    // nothing (budget review).
    final filled = sections.where((s) => s.$2.isNotEmpty).toList();
    final headed = filled.length + (firstSaved < 0 ? 0 : 1) > 1;
    final sectionAt = {
      if (headed)
        for (final (type, xs) in filled) spending.indexOf(xs.first): type,
    };
    final income = data.income;
    final archived = data.archivedCategories;
    final began = budget.began;

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

    // The two tabs sit on the panel's top edge (`tabStrip`). Inside it, over
    // the categories, their column heads; the Income tab has none.
    Widget heads() => _tab == _BudgetTab.income
        ? const SizedBox.shrink()
        : CustomPaint(
            foregroundPainter: _ColumnLines(Mid.ink3),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 12, 6),
              child: Row(
                children: [
                  const Spacer(),
                  // Each word is centred in its column as the dotted lines
                  // draw it (owner, 2026-10-07): between two lines, and for
                  // Left between its line and where the amounts end.
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
              ),
            ),
          );

    // The tabs, folder-style (owner, 2026-11-14, #435): the one you're on is
    // the panel's own color and joins it; the other sits lowered behind its
    // edge. A blue dot on Income says pay wants attention (not set up, or an
    // estimate to update).
    Widget tabStrip() => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageTab(
          key: const ValueKey('budget-tab-spending'),
          label: t.planSpending,
          hue: Mid.blue,
          active: _tab == _BudgetTab.spending,
          onTap: () => setState(() => _tab = _BudgetTab.spending),
        ),
        _PageTab(
          key: const ValueKey('budget-tab-income'),
          label: t.planIncomeTab,
          hue: Mid.green,
          active: _tab == _BudgetTab.income,
          dot: _payNote(t, data).nudge,
          // The Spending list stays mounted under Income, so an Edit
          // open there keeps what was typed (code review, 2026-10-05).
          onTap: () => setState(() => _tab = _BudgetTab.income),
        ),
      ],
    );

    // This period's pay, by currency: what the schedules expect in it,
    // and what has come.
    final pay = periodPay(
      data,
      start: period.start,
      end: period.end,
      today: widget.today,
    );
    final expectedPay = pay.expected, fromPay = pay.came;
    final payToCome = pay.toCome;
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

    // The bar after a name (#460; owner's pick 1, 2026-11-16, #465): every
    // one the same length, the colored part how much of what the category
    // had this period is left, whole and coral when it spent past it. The
    // rows the ring had (#241): not a bill, not under Saved, not one with
    // nothing had and nothing spent.
    // Spent ahead (owner, 2026-11-16, #468): not red, and counted with
    // Assigned on the top card ([spentAhead]).
    final aheadBy = spentAhead(
      data,
      budget,
      periodEnd: period.end,
      today: widget.today,
    );
    int? aheadOf(AccountInfo c) => aheadBy[c.id];

    ({double left, bool over})? barOf(AccountInfo c) {
      final line = budget.lines[c.id];
      if (line == null || saved.contains(c.id)) return null;
      // Nothing had this period: no bar, whether it was spent from or
      // holds only a refund (owner, 2026-11-16: "If nothing is assigned for
      // that category, the bars have no job and should not be there").
      if (line.usedShare == null) return null;
      // Never less than Left when a refund put it past what it had (budget
      // review), so the bar agrees with the figure beside it.
      final had = line.had > line.left ? line.had : line.left;
      return (
        left: line.left <= 0 ? 0 : line.left / had,
        // Spent ahead is no shortfall: not red.
        over: line.left < 0 && aheadOf(c) == null,
      );
    }

    // A finished period only shows what happened (owner, 2026-11-15,
    // #468): no Assign on a row, no Assign what's planned. Typing an
    // amount still works.
    final finished = period.end.isBefore(dateOnly(widget.today));
    // The first steps after setup (#475): in the Savings band's spot, in
    // the period today is in, until they're done.
    final walkCurrency = Budget.currencyOf(data);
    final owing = walkDebts(data, walkCurrency);
    final unpaid = [
      for (final a in owing)
        if (Budget.loanCategory(data, a.id) == null &&
            data.prefs[WalkKeys.debtPassed(a.id)] == null)
          a,
    ];
    final walk = !isCurrent
        ? null
        : walkStep(
            data,
            unpaidDebts: unpaid,
            anyToAssign: spending.any(
              (x) =>
                  !saved.contains(x.id) &&
                  (budget.lines[x.id]?.toAssign ?? 0) > 0,
            ),
          );
    int countOf(CategoryType type) => listed
        .where(
          (c) =>
              !saved.contains(c.id) &&
              c.currency == walkCurrency &&
              typeIn(c) == type,
        )
        .length;
    Widget row(AccountInfo c, {required bool striped}) {
      final line = budget.lines[c.id];
      final planLine = line?.plan;
      final toAssign = finished ? 0 : line?.toAssign ?? 0;
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
      // Money coming in (it's short): the ones with most to give first, so
      // Groceries isn't under three lines at ₮0 (first-time reader).
      if ((line?.left ?? 0) <= 0) {
        others.sort(
          (a, b) =>
              budget.lines[b.id]!.left.compareTo(budget.lines[a.id]!.left),
        );
      }
      // In the list's own sections (#469).
      final groups = [
        for (final type in CategoryType.values)
          (
            typeName(type),
            others.where((x) => !saved.contains(x.id) && typeIn(x) == type),
          ),
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
      // How used up it is (#241), which colors its bar; not under Saved,
      // which fills rather than empties (how far along is the Savings
      // page's, #103).
      final share = saved.contains(c.id) ? null : line?.usedShare;
      final bar = barOf(c);
      // A bill's row is one line (#365): its amount, one word when
      // something is up, and Assign while this period's part isn't in.
      // Short comes first, then skipped, paid, late, its account put away.
      final paidAccount = data.accounts[data.paidFrom[c.id]];
      final paidGone =
          paidAccount != null && (paidAccount.archived || paidAccount.deleted);
      final said = line == null || planLine == null
          ? null
          : planNote(
              t,
              line,
              period,
              widget.today,
              currency,
              payName: ownPayName(t, data, planLine.plan),
              own: data.payScheduleById(planLine.plan.payScheduleId),
              // Only seen by its own period (a set amount's month or
              // pay; a dated plan divides over the view's): by another,
              // Assigned is that period's.
              besideAssigned:
                  planLine.plan.kind != PlanKind.each ||
                  planLine.plan.payScheduleId == data.periodSchedule?.id,
              onRow: true,
            );
      // Nothing left to say once Assigned says it (#467): no line.
      final note =
          said != null &&
              said.text.isEmpty &&
              said.state == null &&
              toAssign == 0
          ? null
          : said;
      final billOne = isBill(c) && note != null;
      final String? billState = !billOne
          ? null
          : line!.short > 0
          ? note.state
          : planLine!.noBills.isNotEmpty
          ? t.planBillSkipped
          : line.paidOn != null
          ? note.state
          : planLine.late
          ? t.planBillLate
          : null;
      // The bills of this period that can be skipped or brought back,
      // each a switch in Edit (#365): the one due here, and the skipped.
      final due = planLine?.due;
      final skippable =
          planLine != null &&
          due != null &&
          planLine.plan.kind == PlanKind.byDate &&
          planLine.plan.repeats &&
          planLine.dueHere &&
          !planLine.ended &&
          !planLine.waiting &&
          line?.paidOn == null &&
          (!period.end.isBefore(widget.today) ||
              data.txns.any(
                (x) => x.scheduled && x.planCategoryId == c.id && x.date == due,
              ));
      final switches = <({DateTime date, bool skipped})>[
        if (skippable) (date: due, skipped: false),
        for (final d in planLine?.noBills ?? const <DateTime>[])
          (date: d, skipped: true),
      ]..sort((a, b) => a.date.compareTo(b.date));
      final row = _CategoryRow(
        key: ValueKey('category-${c.id}'),
        category: c,
        menuFocus: _dotsOf(c.id),
        striped: striped,
        planNote: note,
        assignPlanned: toAssign == 0 ? null : planMoney(toAssign, currency),
        onAssignPlanned: () => widget.onSetAmount(c, period, planLine!.planned),
        // A bill that comes again, due in this period and not paid yet,
        // in a period not over, or one still waiting in the ledger from a
        // month that's over (#363): a bill further ahead is skipped from
        // its own period's page.
        billState: billState,
        assignTotal: planLine == null
            ? null
            : planMoney(planLine.planned, currency),
        billBehind: (line?.short ?? 0) > 0,
        open: _open == c.id,
        onOpen: () => open(c.id),
        onClose: () => open(null),
        onPlan: () => open(c.id, atPlan: true),
        onDelete: () => widget.onDelete(c),
        onEmoji: (e) => widget.onEmoji(c, e),
        flags: line == null
            ? const []
            : _lineFlags(
                t,
                data,
                c,
                line,
                paidGone: paidGone,
                onAccounts: () => open(c.id),
                onRows: () => widget.onShowRows(c, period),
                onAllRows: () => widget.onShowAllRows(c),
              ),
        onShowRows: () => widget.onShowRows(c, period),
        line: line,
        bar: bar,
        // The bar's words: "₮612,300 of ₮900,000 spent"; nothing spent
        // yet; over, by how much. None where they would contradict the
        // row (the two reviews): in the period the budget began in, when
        // Spent shows more than counted against it; and spent ahead by a
        // paycheck, where the line under Left says the month covers it.
        usedWords:
            line == null ||
                share == null ||
                bar == null ||
                line.spent != line.counted ||
                (line.left < 0 && !bar.over)
            ? null
            : line.used == 0
            // With a refund in it, what it has now, as Left says.
            ? t.planUsedFresh(
                planMoney(
                  line.left > line.had ? line.left : line.had,
                  currency,
                ),
              )
            : bar.over
            ? t.planUsedPast(
                planMoney(-line.left, currency),
                planMoney(line.used, currency),
                planMoney(line.had, currency),
              )
            : t.planUsedOf(
                planMoney(line.used, currency),
                planMoney(line.had, currency),
              ),
        bill: isBill(c),
        ahead: switch (aheadOf(c)) {
          final a? => t.planSpentAhead(
            money(a, currency),
            monthName(t, budgetPeriod(period.end, null).start.month),
          ),
          null => null,
        },
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
                bills: switches,
                loan: Budget.loanOfCategory(data, c.id) != null,
                onBills: (skip, back) async {
                  for (final d in skip) {
                    await widget.onSkipBill(c, d, line?.left ?? 0);
                  }
                  for (final d in back) {
                    await widget.onBringBackBill(c, d);
                  }
                },
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

    // A group the person made, inside Day-to-day: small gray capitals, so
    // section, group and row each look different (#482). Right under a
    // section's top it sits closer.
    Widget heading(String text, String key, {required bool first}) => Padding(
      padding: EdgeInsets.fromLTRB(12, first ? 4 : 14, 12, 4),
      child: Text(
        text.toUpperCase(),
        key: ValueKey(key),
        style: onest(11.5, weight: 600, color: Mid.ink3, letterSpacing: 0.5),
      ),
    );

    // A type's section (#469), named above its rows (owner, 2026-11-16,
    // #489: "wasting it horizontally is a no-no. … Let's move those headers
    // above"; before it, #482's margin on the left). Bold and bigger than a
    // row's name ("Bill and Day-to-Day should look more like headers").
    // Saved, the safety net's (null), is a section too. No line under it
    // saying what Left is there: a subtitle, which the owner sent back the
    // same day (#471). The panel's color behind it, so rows scrolling
    // under it while it stays at the top don't show through.
    Widget sectionName(CategoryType? type) => Container(
      key: ValueKey(
        type == null ? 'budget-saved' : 'budget-section-${type.name}',
      ),
      color: Mid.panel,
      constraints: const BoxConstraints(minHeight: 36),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Text(
        type == null ? t.planSaved : typeName(type),
        style: onest(15, weight: 700, color: Mid.ink),
      ),
    );

    // Under the everyday categories and the bills: this period's Assigned
    // and Spent added up, a row per currency, only with two or more rows
    // to add (#273). Left's total is the key card's In categories.
    List<Widget> totals() {
      final sums = <Currency, (int, int, int)>{};
      for (final c in spending) {
        if (saved.contains(c.id)) continue;
        final l = budget.lines[c.id];
        if (l == null) continue;
        final (a, s, n) = sums[c.currency] ?? (0, 0, 0);
        sums[c.currency] = (a + l.assigned, s + l.spent, n + 1);
      }
      return [
        for (final MapEntry(key: c, value: (a, s, n)) in sums.entries)
          if (n >= 2)
            _TotalsRow(
              key: ValueKey('budget-total-${c.code}'),
              assigned: a,
              spent: s,
              currency: c,
              onShowRows: () => widget.onShowPeriodRows(period),
            ),
      ];
    }

    // The Spending tab's list. With sections, each is a [HeadedSection]:
    // its name over its rows stays at the top of the list while they
    // scroll, and a line across parts it from the one before. With one section there
    // are no names and the rows run across the panel. Stripes restart at
    // every section and group, first row plain, so the row under a
    // heading looks the same in each.
    List<Widget> spendingRows() {
      final starts = {...sectionAt.keys, if (firstSaved >= 0) firstSaved};
      final out = <Widget>[];
      var body = <Widget>[];
      CategoryType? type;
      var named = false;
      var n = 0;
      void close() {
        if (body.isEmpty) return;
        if (!named) {
          out.addAll(body);
        } else {
          if (out.isNotEmpty) {
            out.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                child: Container(height: 1, color: Mid.rule),
              ),
            );
          }
          out.add(
            HeadedSection(
              key: ValueKey('section-${type?.name ?? 'saved'}'),
              scroll: _listScroll,
              name: sectionName(type),
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: body,
              ),
            ),
          );
        }
        body = [];
      }

      for (final (i, c) in spending.indexed) {
        if (starts.contains(i)) {
          // The Total row ends the last section before Saved.
          if (i == firstSaved) body.addAll(totals());
          close();
          type = i == firstSaved ? null : sectionAt[i];
          named = true;
          n = 0;
        }
        if (groupAt[i] case final g?) {
          body.add(heading(g, 'budget-group-$g', first: body.isEmpty));
          n = 0;
        }
        body.add(row(c, striped: n.isOdd));
        n++;
      }
      if (firstSaved < 0) body.addAll(totals());
      close();
      return out;
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

    // The top card (owner, 2026-11-14, #461): one sum for each currency,
    // every figure in its own box. Income, and what the periods before
    // left or left short, less what was Assigned, Saved and Overspent, is
    // Not assigned, or Assigned too much. No bank figure has a part in it
    // ("a budget shouldn't care how much they have in the bank"): what
    // will happen to an account is the Ledger's to say. It took the place
    // of two cards that measured against two things, the bank and the
    // income. No pane round it (owner's pick C of three, 2026-11-16, #464,
    // of the pane: "looks like it's missing a label or something"): a
    // frame round framed boxes read as a titled group with its title left
    // off, so the boxes sit on the page under "Budget ‹ November 2026 ›",
    // which names them. The first-period offer, a question, is a pane of
    // its own under them.
    Widget keyCard() {
      final pools = budget.pools;
      String tagOf(Currency c) => c == budget.currency ? '' : '-${c.code}';
      final byPay = period.label == payPeriodLabel;
      final month = monthName(t, period.start.month);
      // The period before, by its name: "From October".
      final beforeMonth = monthName(
        t,
        previousBudgetPeriod(period, by).start.month,
      );
      // Notes on "Assigned": one click for everything planned, and what
      // that would overdraw, said before it's done.
      final assignedNotes = <Widget>[];
      // Clear, which starts the period over: at the right end of its
      // currency's sum, on the boxes' own row (owner, 2026-11-14, #464:
      // "the button on the right creates a space that looks weird. It
      // should be on the same row as the others").
      final clearOf = <Currency, Widget>{};
      for (final p in pools) {
        final c = p.currency, tag = tagOf(c);
        final planned = {
          for (final x in spending)
            if (budget.lines[x.id] case final l?
                when !finished && x.currency == c && l.toAssign > 0)
              x: l.plan!.planned,
        };
        if (planned.isEmpty) continue;
        final plannedTotal = planned.keys.fold(
          0,
          (sum, x) => sum + budget.lines[x.id]!.toAssign,
        );
        // What assigning it all takes from Not assigned: the part that
        // covers a category's overspending takes nothing, since that
        // already came off.
        final takes = planned.keys.fold(0, (sum, x) {
          final l = budget.lines[x.id]!;
          final covers = l.left < 0 ? -l.left : 0;
          return sum + (l.toAssign > covers ? l.toAssign - covers : 0);
        });
        final plannedOver = takes - (p.notAssigned > 0 ? p.notAssigned : 0);
        assignedNotes.add(
          _AssignPlannedButton(
            key: ValueKey('assign-planned$tag'),
            label: t.planFill(planned.length, planMoney(plannedTotal, c)),
            // More planned than there is to give out: said inside the
            // button it is about, with the figure the card shows as Not
            // assigned, so both amounts can be checked before the click.
            // It says what the click does to it, and still runs (#468).
            warning: plannedOver <= 0
                ? null
                : p.notAssigned > 0
                ? t.planFillOverBy(
                    money(p.notAssigned, c),
                    money(plannedOver, c),
                  )
                : p.notAssigned == 0
                ? t.planFillOverNone(money(plannedOver, c))
                : t.planFillOverMore(money(plannedOver, c)),
            warningKey: ValueKey('assign-planned-over$tag'),
            onTap: () {
              setState(() => _editing = null);
              widget.onAssignPlanned(period, planned);
            },
          ),
        );
      }
      // Start the period over (#100): offered while anything in it is
      // assigned. Not the Safety net's, which is kept apart.
      for (final p in pools) {
        final c = p.currency, tag = tagOf(c);
        // What was put in: a category Move money took from this period
        // (its Assigned below zero) is left as it is, or clearing would
        // quietly undo the move (code review).
        final clears = [
          for (final x in spending)
            if (x.currency == c &&
                !saved.contains(x.id) &&
                (budget.lines[x.id]?.assigned ?? 0) > 0)
              x,
        ];
        if (clears.isEmpty) continue;
        final total = clears.fold(
          0,
          (sum, x) => sum + budget.lines[x.id]!.assigned,
        );
        clearOf[c] = BarButton(
          key: ValueKey('clear-assigned$tag'),
          // The amount is in the window; with two currencies the code
          // tells the buttons apart, at the end.
          label: switch ((byPay, pools.length > 1)) {
            (false, false) => t.planClearMonth(month),
            (false, true) => t.planClearMonthIn(month, c.code),
            (true, false) => t.planClearPay,
            (true, true) => t.planClearPayIn(c.code),
          },
          onTap: () async {
            setState(() => _editing = null);
            final go = await showDialog<bool>(
              context: context,
              builder: (_) => _ClearAssignedWindow(
                sums: _clearSums(
                  t,
                  data,
                  period,
                  clears,
                  c,
                  saved,
                  today: widget.today,
                ),
                month: byPay ? null : month,
                currency: c,
              ),
            );
            if (go != true) return;
            final amount = formatShort(total, currency: c);
            widget.onClearAssigned(
              period,
              clears,
              byPay
                  ? t.planClearedPay(amount)
                  : t.planClearedMonth(month, amount),
            );
          },
        );
      }
      // One currency's sum. A figure at zero is left out, but for Income
      // and the result.
      Widget sum(BudgetPool p) {
        final c = p.currency, tag = tagOf(c);
        String short(int v) => formatShort(v, currency: c);
        final terms = BudgetSum.of(
          p,
          budget: budget,
          spending: spending,
          saved: saved,
          aheadBy: aheadBy,
        );
        final aside = terms.aside;
        final given = terms.given;
        final overspent = terms.overspent;
        final over = terms.over;
        // Below zero, the result is named by what made it (#470): giving
        // out more than there is, spending past it, or both.
        final cause = terms.cause;
        final (label: overLabel, parts: overParts) = overWords(
          t,
          cause,
          byPay: byPay,
          beforeMonth: beforeMonth,
          short: short,
        );
        Widget after(String sign, Widget child) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(sign, style: onest(18, color: Mid.ink3)),
            const SizedBox(width: 12),
            child,
          ],
        );
        return Wrap(
          key: ValueKey('budget-sum$tag'),
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _SumBox(
              label: t.planFitIncome,
              figure: short(p.income + p.toCome),
              note: p.toCome > 0 ? t.planFitToCome(short(p.toCome)) : null,
              // Green once some has come in, as on the Income tab.
              hue: p.income > 0 ? Mid.green : null,
            ),
            // What the periods before left to give out; or left short,
            // which has to be made up (owner, 2026-11-14).
            if (p.fromBefore > 0)
              after(
                '+',
                _SumBox(
                  key: ValueKey('sum-from$tag'),
                  label: byPay
                      ? t.planSumFromPay
                      : t.planSumFromMonth(beforeMonth),
                  figure: short(p.fromBefore),
                  hue: Mid.green,
                ),
              ),
            if (p.fromBefore < 0)
              after(
                '−',
                _SumBox(
                  key: ValueKey('sum-from$tag'),
                  label: byPay
                      ? t.planSumShortFromPay
                      : t.planSumShortFromMonth(beforeMonth),
                  figure: short(-p.fromBefore),
                  hue: Mid.coral,
                ),
              ),
            // What they had when the budget began, in the period it began
            // in (#461); later it is part of From October.
            if (p.hadBefore > 0)
              after(
                '+',
                _SumBox(
                  key: ValueKey('sum-had$tag'),
                  label: t.planSumHadBefore,
                  figure: short(p.hadBefore),
                  hue: Mid.green,
                ),
              ),
            // Changed into this currency, or out of it (#461).
            if (p.exchanged != 0)
              after(
                p.exchanged > 0 ? '+' : '−',
                _SumBox(
                  key: ValueKey('sum-exchanged$tag'),
                  label: t.planSumExchanged,
                  figure: short(p.exchanged.abs()),
                  hue: p.exchanged > 0 ? Mid.green : null,
                ),
              ),
            // Given out and not gone yet: gold, as Still to spend was
            // (owner, 2026-11-14: "Green is income, red is expense",
            // "Let's make still to spend yellow").
            if (given != 0)
              after(
                '−',
                _SumBox(
                  key: ValueKey('sum-assigned$tag'),
                  label: t.planAssigned,
                  figure: short(given),
                  hue: Mid.gold,
                ),
              ),
            if (aside > 0)
              after(
                '−',
                _SumBox(
                  key: ValueKey('sum-saved$tag'),
                  label: t.planFitAside,
                  figure: short(aside),
                ),
              ),
            if (overspent > 0)
              after(
                '−',
                _SumBox(
                  key: ValueKey('sum-overspent$tag'),
                  label: t.planKeyOverspent,
                  figure: short(overspent),
                  hue: Mid.coral,
                ),
              ),
            // Money out with no category yet: a term of its own, so
            // Overspent is the list's coral amounts and nothing else.
            if (p.loose > 0)
              after(
                '−',
                _SumBox(
                  key: ValueKey('sum-loose$tag'),
                  label: t.rowsTabUncategorized,
                  figure: short(p.loose),
                  hue: Mid.coral,
                ),
              ),
            // Not assigned; or, with more given out than came in, Assigned
            // too much in its place, never a minus (owner, 2026-10-06) and
            // never a ₮0 beside it (2026-11-14).
            after(
              '=',
              _SumBox(
                label: over ? overLabel : t.planKeyNotAssigned,
                figure: short(p.notAssigned.abs()),
                // More than one cause: the parts, which the boxes beside
                // it can't split.
                below: overParts,
                belowKey: ValueKey('over-parts$tag'),
                figureKey: ValueKey(
                  over ? 'assigned-over$tag' : 'not-assigned$tag',
                ),
                hue: over
                    ? Mid.coral
                    : p.notAssigned > 0
                    ? Mid.green
                    : null,
                big: true,
              ),
            ),
          ],
        );
      }

      // A currency with nothing in its sum is left out, but for the
      // budget's own.
      final shown = [
        for (final p in pools)
          if (p.currency == budget.currency ||
              p.income != 0 ||
              p.toCome != 0 ||
              p.fromBefore != 0 ||
              p.hadBefore != 0 ||
              p.exchanged != 0 ||
              p.assigned != 0 ||
              p.overspent != 0 ||
              p.loose != 0)
            p,
      ];
      final clearNotes = [
        for (final MapEntry(:key, :value) in clearOf.entries)
          if (!shown.any((p) => p.currency == key)) value,
      ];
      return Padding(
        key: const ValueKey('budget-key'),
        padding: const EdgeInsets.only(bottom: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, p) in shown.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              // The sum, and its Clear at the row's right end: apart from
              // the figures (owner, 2026-11-14: "It looks out of place
              // there"), and on their row (#464).
              if (clearOf[p.currency] case final clear?)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: sum(p)),
                    const SizedBox(width: 12),
                    clear,
                  ],
                )
              else
                sum(p),
            ],
            // Under the sum: Assign what's planned, with its warning inside
            // it. A Clear whose currency has no sum on the card ends it.
            if (assignedNotes.isNotEmpty || clearNotes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: assignedNotes,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final (i, note) in clearNotes.indexed) ...[
                          if (i > 0) const SizedBox(height: 6),
                          note,
                        ],
                      ],
                    ),
                  ],
                ),
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
                  budget.unassignedSpent.count,
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
              )
            // The Savings step they're on (#487). Not in a period that's
            // over, which only shows what happened, nor under the
            // first-period offer: one thing asked at a time.
            else if (!finished)
              if (walk case final w?)
                _WalkBand(
                  step: w,
                  steps: [
                    WalkStep.bills,
                    if (owing.isNotEmpty) WalkStep.debts,
                    WalkStep.dayToDay,
                    WalkStep.assign,
                  ],
                  bills: countOf(CategoryType.bill),
                  days: countOf(CategoryType.dayToDay),
                  debt: unpaid.isEmpty
                      ? null
                      : (
                          account: unpaid.first,
                          owes: -data.balanceOf(unpaid.first.id),
                        ),
                  cardsNext: unpaid.isNotEmpty,
                  waiting: budget.notAssigned <= 0,
                  nextPay: nextPayday(data, widget.today),
                  onAddBill: () => _newCategory(type: CategoryType.bill),
                  onAddDay: () => _newCategory(type: CategoryType.dayToDay),
                  onAddDebtBill: (a) =>
                      _newCategory(type: CategoryType.bill, paying: a),
                  // Not now on a card or loan passes that one only.
                  onPass: (step, label) => widget.onWalkPass(
                    step == WalkStep.debts && unpaid.isNotEmpty
                        ? WalkKeys.debtPassed(unpaid.first.id)
                        : WalkKeys.passed(step),
                    label,
                  ),
                )
              else if (_readiness case final r)
                if (r.current case final step?)
                  _StepBand(
                    r: r,
                    step: step,
                    currency: savingsCurrency(data),
                    // Not before the budget has begun: with nothing
                    // assigned yet, no plan has spoken for rent, and the
                    // first big button mustn't be the safety net's.
                    offers: isCurrent && budget.began != null,
                    onAssign: (category, total, undo, full) {
                      setState(() => _editing = null);
                      widget.onAssignStep(category, total, undo, full);
                    },
                    onOpen: widget.onShowSavings,
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
                    // An open Edit stays, with what was typed in it, and its
                    // row is drawn for the new period (#163).
                    _period = previousBudgetPeriod(period, by);
                  }),
                ),
                // Month or paycheck is chosen at setup and in Settings,
                // not switched here (owner, 2026-11-16, #474).
                Text(
                  // A month by its name and year (owner, 2026-11-16: "Just
                  // write November 2026"); a pay period needs its dates.
                  period.label == payPeriodLabel
                      ? t.planPeriodTitle(
                          _spanName(t, period, widget.today),
                          shortDate(period.start),
                          shortDate(period.end),
                        )
                      : t.planMonthYear(
                          monthName(t, period.start.month),
                          '${period.start.year}',
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
              ],
            ),
          ),
          const SizedBox(height: 14),
          // The key and the income card, then the categories: these keep
          // room for a few rows, and the cards scroll when the window is too
          // short for all of them (#234).
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: (box.maxHeight - _categoriesRoom).clamp(
                        0,
                        box.maxHeight,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [keyCard(), const SizedBox(height: 12)],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        // The panel starts 1 point up under the tabs' feet, so
                        // the chosen tab covers its top edge and joins it.
                        Positioned.fill(
                          top: _tabFeet,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Mid.panel,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                              border: Border.all(color: Mid.rule),
                            ),
                            // The columns' titles stay over the list
                            // (#482): they scrolled off with the first
                            // row.
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    8,
                                    12,
                                    0,
                                  ),
                                  child: heads(),
                                ),
                                Expanded(
                                  child: ListView(
                                    controller: _listScroll,
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      0,
                                      12,
                                      14,
                                    ),
                                    children: [
                                      if (_tab == _BudgetTab.income)
                                        _IncomeTab(
                                          data: data,
                                          cameIn: income == null
                                              ? const []
                                              : _cameIn(
                                                  budget.cameIn[income.id],
                                                  budget.currency,
                                                ),
                                          fromPay: fromPay,
                                          expectedPay: expectedPay,
                                          payToCome: payToCome,
                                          onShowRows: income == null
                                              ? null
                                              : () => widget.onShowRows(
                                                  income,
                                                  period,
                                                ),
                                          waiting: [
                                            for (final (c, v) in _cameIn(
                                              budget.cameInUncategorized,
                                              budget.currency,
                                            ))
                                              if (v > 0) (c, v),
                                          ],
                                          onShowWaiting: switch (data
                                              .accounts
                                              .values
                                              .where(
                                                (a) =>
                                                    !a.deleted &&
                                                    isUncategorized(a),
                                              )
                                              .firstOrNull) {
                                            final w? => () => widget.onShowRows(
                                              w,
                                              period,
                                            ),
                                            null => null,
                                          },
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              ...spendingRows(),
                                              const SizedBox(height: 14),
                                              if (archived.isNotEmpty) ...[
                                                Hoverable(
                                                  key: const ValueKey(
                                                    'show-archived-categories',
                                                  ),
                                                  onTap: () => setState(
                                                    () => _showArchived =
                                                        !_showArchived,
                                                  ),
                                                  builder: (hover) => Padding(
                                                    padding:
                                                        const EdgeInsets.fromLTRB(
                                                          12,
                                                          6,
                                                          12,
                                                          6,
                                                        ),
                                                    child: Text(
                                                      _showArchived
                                                          ? t.planHideArchived(
                                                              archived.length,
                                                            )
                                                          : t.planShowArchived(
                                                              archived.length,
                                                            ),
                                                      style: onest(
                                                        12.5,
                                                        color: hover
                                                            ? Mid.ink2
                                                            : Mid.ink3,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                if (_showArchived)
                                                  for (final c in archived)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 4,
                                                          ),
                                                      child: Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              c.name,
                                                              style: onest(
                                                                13.5,
                                                                color: Mid.ink2,
                                                              ),
                                                            ),
                                                          ),
                                                          Text(
                                                            _usageText(
                                                              t,
                                                              data.categoryUsage[c
                                                                  .id],
                                                            ),
                                                            style: onest(
                                                              12.5,
                                                              color: Mid.ink3,
                                                            ),
                                                          ),
                                                          // Money can still sit in an archived one.
                                                          if (budget
                                                                  .lines[c.id]
                                                                  ?.left
                                                              case final left?
                                                              when left !=
                                                                  0) ...[
                                                            const SizedBox(
                                                              width: 16,
                                                            ),
                                                            Money(
                                                              left,
                                                              size: 13,
                                                              currency:
                                                                  c.currency,
                                                              color: left < 0
                                                                  ? Mid.coral
                                                                  : Mid.ink2,
                                                            ),
                                                          ],
                                                          const SizedBox(
                                                            width: 16,
                                                          ),
                                                          BarButton(
                                                            key: ValueKey(
                                                              'unarchive-category-${c.id}',
                                                            ),
                                                            label: t
                                                                .planShowInMenus,
                                                            onTap: () => widget
                                                                .onUnarchive(c),
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
                              ],
                            ),
                          ),
                        ),
                        Positioned(left: 0, top: 0, child: tabStrip()),
                        // Add category sits on the tabs' row, at the list it
                        // adds to (owner, 2026-11-14). It belongs to Spending:
                        // Income's button is under the incomes (#436).
                        if (_tab == _BudgetTab.spending)
                          Positioned(
                            right: 0,
                            top: 0,
                            // The row lets the button be as wide as its
                            // words; alone it would fill the tabs' row.
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _PrimaryButton(
                                  key: const ValueKey('add-category'),
                                  label: t.planAddCategory,
                                  icon: Icons.add_rounded,
                                  onTap: _newCategory,
                                ),
                              ],
                            ),
                          ),
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

/// Assign what's planned, on the key card. When the plans come to more
/// than is not assigned, the warning is the button's own second line, in
/// coral, inside its outline (owner, 2026-11-14, of the line that stood
/// beside it: "How would the user know what that text is referring to?").
/// Without a warning it is a [BarButton].
class _AssignPlannedButton extends StatelessWidget {
  const _AssignPlannedButton({
    super.key,
    required this.label,
    required this.onTap,
    this.warning,
    this.warningKey,
  });
  final String label;
  final VoidCallback onTap;
  final String? warning;
  final Key? warningKey;

  @override
  Widget build(BuildContext context) {
    final warning = this.warning;
    if (warning == null) return BarButton(label: label, onTap: onTap);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Hoverable(
        onTap: onTap,
        builder: (hover) => Container(
          padding: const EdgeInsets.fromLTRB(10, 5, 10, 6),
          decoration: BoxDecoration(
            color: hover ? Mid.raised : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Mid.ink2.withValues(alpha: hover ? 0.6 : 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: onest(13, color: hover ? Mid.ink : Mid.ink2),
              ),
              const SizedBox(height: 2),
              Text(
                warning,
                key: warningKey,
                style: onest(12.5, color: Mid.coral, tabular: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the tabs end and the panel's top edge is: the chosen tab is one
/// point taller and covers that edge.
const double _tabFeet = 41;

/// What the categories keep under the cards at the top of the Budget page:
/// the tabs and a few rows (#234).
const double _categoriesRoom = 240;

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

/// The bar after a category's name ([UsedBar], #460, #465): how long it
/// is, the same for every category. Names keep [_barNameShare] of the
/// room before Assigned, between [_barNameMin] and [_barNameMax], so every
/// bar starts at the same place down the list.
const double _barMax = 180;

const double _barNameShare = 0.42;
const double _barNameMin = 170;
const double _barNameMax = 300;

/// Under the spending categories: this period's Assigned and Spent added
/// up, one row per currency among them (#273). Left's total is the key
/// card's In categories, so that column stays empty. Spent opens the
/// period's rows, as a category's Spent does.
class _TotalsRow extends StatelessWidget {
  const _TotalsRow({
    super.key,
    required this.assigned,
    required this.spent,
    required this.currency,
    required this.onShowRows,
  });
  final int assigned;
  final int spent;
  final Currency currency;
  final VoidCallback onShowRows;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return CustomPaint(
      foregroundPainter: _ColumnLines(Mid.ink3),
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        // Set a little apart, so it reads as the list's foot and not as
        // the bills' own total (budget review).
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Mid.rule)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                t.planTotal,
                style: onest(13, weight: 600, color: Mid.ink2),
              ),
            ),
            SizedBox(
              width: _amountWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: Money(
                  assigned,
                  key: ValueKey('total-assigned-${currency.code}'),
                  size: 13.5,
                  weight: 600,
                  currency: currency,
                  color: Mid.ink2,
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
                    key: ValueKey('total-spent-${currency.code}'),
                    onTap: onShowRows,
                    builder: (hover) => Money(
                      spent.abs(),
                      sign: spent < 0
                          ? MoneySign.plusForPositive
                          : MoneySign.none,
                      size: 13.5,
                      weight: 600,
                      currency: currency,
                      color: hover ? Mid.blue : Mid.ink2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: _leftWidth + 12 + 28),
          ],
        ),
      ),
    );
  }
}

enum _BudgetTab { spending, income }

/// A folder tab's outline: top corners rounded, sides and top stroked, the
/// bottom left open so the panel shows through, and for the chosen tab a
/// 3-point bar of its hue along the top. (A `Border` can't round corners
/// with sides of different colors.)
class _TabShape extends ShapeBorder {
  const _TabShape({required this.rule, this.bar});
  final Color rule;
  final Color? bar;

  static const _radius = Radius.circular(10);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()
    ..addRRect(
      RRect.fromRectAndCorners(rect, topLeft: _radius, topRight: _radius),
    );

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = rule;
    // Stroked half a point in, so the line lies inside the tab.
    final r = rect.deflate(0.5);
    canvas.drawPath(
      Path()
        ..moveTo(r.left, r.bottom)
        ..lineTo(r.left, r.top + _radius.x)
        ..arcToPoint(Offset(r.left + _radius.x, r.top), radius: _radius)
        ..lineTo(r.right - _radius.x, r.top)
        ..arcToPoint(Offset(r.right, r.top + _radius.x), radius: _radius)
        ..lineTo(r.right, r.bottom),
      edge,
    );
    if (bar case final c?) {
      canvas.save();
      canvas.clipPath(getOuterPath(rect));
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, rect.width, 3),
        Paint()..color = c,
      );
      canvas.restore();
    }
  }

  @override
  ShapeBorder scale(double t) => this;
}

/// A folder tab on the panel's top edge (owner's pick B, 2026-11-14, #435).
/// The one you're on is the panel's own color, 42 tall, with a 3-point bar
/// of its [hue] across the top, and covers the panel's edge so the two are
/// one piece. The other is lowered, 36 tall, on the raised gray, with the
/// panel's edge running under it. Spending's hue is the blue of what you
/// click and Income's the green of money in.
class _PageTab extends StatelessWidget {
  const _PageTab({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    required this.hue,
    this.dot = false,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color hue;

  /// Something on the tab wants attention: a small blue dot after it.
  final bool dot;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(right: 4, top: active ? 0 : _tabFeet - 36),
    child: Hoverable(
      onTap: onTap,
      builder: (hover) => Container(
        height: active ? _tabFeet + 1 : 36,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: ShapeDecoration(
          color: active ? Mid.panel : (hover ? Mid.hover : Mid.raised),
          shape: _TabShape(rule: Mid.rule, bar: active ? hue : null),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: onest(
                14,
                color: active ? Mid.ink : Mid.ink2,
                weight: active ? 600 : 400,
              ),
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
    required this.payToCome,
    required this.onShowRows,
    required this.onPay,
    required this.onAskAgain,
    this.waiting = const [],
    this.onShowWaiting,
  });
  final LedgerData data;
  final List<(Currency, int)> cameIn;

  /// Money in this period still in Not categorized, which Income doesn't
  /// count: said under it, and a click shows the rows (#182).
  final List<(Currency, int)> waiting;
  final VoidCallback? onShowWaiting;

  /// This period's pay by currency: what has come, and what the
  /// schedules expect.
  final Map<Currency, int> fromPay;
  final Map<Currency, int> expectedPay;

  /// What the sum at the top counts as still to come, so the line adds up
  /// the same way (#461).
  final Map<Currency, int> payToCome;
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

    // "₮2,500,000 received · ₮2,100,000 still to come", one per currency
    // pay is set up in. It was "received of expected" (owner, 2026-10-05),
    // but expected keeps a payday that went by without pay, so the two
    // didn't add up to the sum at the top (#461, budget reviews).
    final split = [
      for (final c in expectedPay.keys)
        if ((payToCome[c] ?? 0) > 0)
          t.planIncomeToCome(
            formatShort(fromPay[c] ?? 0, currency: c),
            formatShort(payToCome[c]!, currency: c),
          )
        else
          t.planIncomeReceived(formatShort(fromPay[c] ?? 0, currency: c)),
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
                  builder: (hover) {
                    // Each currency's amount is its own piece, green only
                    // when money came in (#327); zero or less is ink.
                    final pieces = cameIn.isEmpty
                        ? [
                            (
                              formatMoney(0, currency: mainCurrency(data)),
                              false,
                            ),
                          ]
                        : [
                            for (final (c, v) in cameIn)
                              (formatMoney(v, currency: c), v > 0),
                          ];
                    final amounts = [for (final p in pieces) p.$1].join(' · ');
                    final line = t.planIncomeLine(amounts);
                    final at = line.indexOf(amounts);
                    return Text.rich(
                      at < 0
                          ? TextSpan(text: line)
                          : TextSpan(
                              children: [
                                TextSpan(text: line.substring(0, at)),
                                for (final (i, (text, green))
                                    in pieces.indexed) ...[
                                  if (i > 0) const TextSpan(text: ' · '),
                                  TextSpan(
                                    text: text,
                                    style: green
                                        ? TextStyle(color: Mid.green)
                                        : null,
                                  ),
                                ],
                                TextSpan(
                                  text: line.substring(at + amounts.length),
                                ),
                              ],
                            ),
                      style: onest(15, weight: 600, tabular: true).copyWith(
                        decoration: hover ? TextDecoration.underline : null,
                        decorationColor: Mid.ink,
                      ),
                    );
                  },
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
        if (waiting.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Hoverable(
              key: const ValueKey('income-waiting'),
              onTap: onShowWaiting ?? () {},
              builder: (hover) => Text(
                t.planIncomeUncategorized(
                  [for (final (c, v) in waiting) formatMoney(v, currency: c)]
                      .join(' · '),
                ),
                style: onest(13, color: Mid.ink2, tabular: true).copyWith(
                  decoration: hover ? TextDecoration.underline : null,
                  decorationColor: Mid.ink2,
                ),
              ),
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
        // With the incomes it adds to, not up in the page's top row (#436).
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            children: [
              _PrimaryButton(
                key: const ValueKey('income-add-pay'),
                label: pays.isEmpty ? t.setupAddYourPay : t.setupAddOtherPay,
                icon: Icons.add_rounded,
                tooltip: t.setupAddPayTip,
                onTap: () => onPay(null),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One figure of the Budget page's sum, in a box tinted with its own
/// color (owner, 2026-11-14, of the result's: "Love the box on the end.
/// Let's put a box around each of them"): its name, then the figure. One
/// with no color of its own is in a faint tint of the ink. [big] is the
/// result, a size larger. [note] goes beside the name ("₮2,100,000 still
/// to come").
class _SumBox extends StatelessWidget {
  const _SumBox({
    super.key,
    required this.label,
    required this.figure,
    this.hue,
    this.note,
    this.below,
    this.big = false,
    this.figureKey,
    this.belowKey,
  });
  final String label, figure;
  final Color? hue;
  final String? note;

  /// A small line under the figure.
  final String? below;
  final bool big;
  final Key? figureKey, belowKey;

  @override
  Widget build(BuildContext context) => Container(
    padding: big
        ? const EdgeInsets.fromLTRB(16, 8, 16, 8)
        : const EdgeInsets.fromLTRB(14, 7, 14, 7),
    decoration: BoxDecoration(
      color: (hue ?? Mid.ink).withValues(alpha: hue == null ? 0.06 : 0.12),
      borderRadius: BorderRadius.circular(10),
      // The result is told from the terms by an edge in its own color
      // (owner, 2026-11-16: "I need it to look slightly different since
      // it's the equals card").
      border: big
          ? Border.all(
              color: (hue ?? Mid.ink2).withValues(alpha: 0.7),
              width: 1.5,
            )
          : null,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: onest(12.5, color: hue ?? Mid.ink2)),
            if (note case final note?) ...[
              const SizedBox(width: 8),
              Text(note, style: onest(12.5, color: Mid.ink3, tabular: true)),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Text(
          figure,
          key: figureKey,
          style: onest(big ? 21 : 18, weight: 600, color: hue, tabular: true),
        ),
        if (below case final below?) ...[
          const SizedBox(height: 2),
          Text(
            below,
            key: belowKey,
            style: onest(12.5, color: Mid.ink3, tabular: true),
          ),
        ],
      ],
    ),
  );
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
    required this.onEmoji,
    this.line,
    this.ahead,
    this.planNote,
    this.assignPlanned,
    this.onAssignPlanned,
    this.assignTotal,
    this.billState,
    this.billBehind = false,
    this.flags = const [],
    this.moveChoices = const [],
    this.onMove,
    this.bar,
    this.usedWords,
    this.bill = false,
  });
  final AccountInfo category;

  /// The bar after its name (#460, #465): how much of what it had this
  /// period is left, 0 to 1, and whether it spent past it. Null, no bar (a
  /// bill, or nothing to picture). [usedWords] is the bar's tooltip,
  /// "₮612,300 of ₮900,000 spent".
  final ({double left, bool over})? bar;
  final String? usedWords;

  /// Saving for a bill, listed under Bills: its Left is quieter, since
  /// that money is spoken for (owner, 2026-10-07, on the phone).
  final bool bill;

  /// What the box under Left can move money to or from: Not assigned
  /// first, then the other categories in its currency.
  final List<_MoveChoice> moveChoices;
  final void Function(AccountInfo? from, AccountInfo? to, int amount)? onMove;

  /// It's open in Edit under the row.
  final bool open;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onDelete;

  /// An emoji picked in the spot before the name, or null to take it off.
  final ValueChanged<String?> onEmoji;

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

  /// What Assigned will be once [assignPlanned] is clicked, for the
  /// link's tooltip.
  final String? assignTotal;

  /// A bill's one spot (#365): "Late", "Skipped", "paid 10.13", "₮200,000
  /// short"; null says nothing. [billBehind] (short) is in full ink. Its
  /// account put away is a warning, as on any row (#483).
  final String? billState;
  final bool billBehind;

  /// The plan's note was clicked: Edit, at the plan.
  final VoidCallback onPlan;

  /// Every other row is tinted, as in the register: the name and its
  /// amounts sit a page apart.
  final bool striped;

  /// Spent was clicked: this period's rows.
  final VoidCallback onShowRows;

  /// Assigned, Spent and Left for the period on screen.
  final EnvelopeLine? line;

  /// "₮100,000 past this pay period's part, which November's money still
  /// covers": said when Left, which is then not red (#468), is pointed
  /// at. No line under Left, here or for what the period before left
  /// (owner, 2026-11-16: "I want each row to be the same height. Kill the
  /// text").
  final String? ahead;
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
    final oneLine = widget.bill && widget.planNote != null;
    final note = widget.planNote;
    final planText = (note?.text ?? '').isEmpty ? null : note!.text;
    // What the row says after its name, in the order it reads; `rank` is
    // which is kept when there's room for one: a warning, then Late, then
    // the Assign link, then any other word (the committee, 2026-11-16).
    final some = (widget.line?.assigned ?? 0) > 0;
    final state = oneLine ? widget.billState : note?.state;
    final said = <_Said>[
      // A bill's amount: the first to give way.
      if (oneLine)
        (
          key: ValueKey('plan-note-${c.id}'),
          text: note!.amount,
          style: onest(12.5, color: Mid.ink2, tabular: true),
          tip: '${note.text}\n${t.planEditTip}',
          onTap: widget.onPlan,
          rank: 4,
        ),
      for (final (i, f) in widget.flags.indexed)
        (
          key: ValueKey('line-flag-${c.id}-$i'),
          text: f.short,
          style: onest(12, weight: 600, color: Mid.ink, tabular: true),
          tip: f.text,
          onTap: f.onTap,
          rank: 0,
        ),
      if (state != null)
        (
          key: ValueKey('plan-state-${c.id}'),
          text: state,
          style: onest(
            12,
            color: (oneLine ? widget.billBehind : note!.behind)
                ? Mid.ink
                : Mid.ink2,
            tabular: true,
          ),
          tip: planText,
          onTap: null,
          rank: state == t.planBillLate ? 1 : 3,
        ),
      if (widget.assignPlanned case final amount?)
        (
          key: ValueKey('plan-assign-${c.id}'),
          // "more" once some is in, so it can't read as replacing it.
          text: some ? t.planAssignMore(amount) : t.planAssignThis(amount),
          style: onest(12, weight: 500, color: Mid.blue, tabular: true),
          // The plan it's toward, then where the money comes from and
          // what Assigned will be: two whole sentences, a line each.
          tip: [
            ?planText,
            if (some && widget.assignTotal != null)
              t.planAssignMoreLinkTip(amount, widget.assignTotal!)
            else
              t.planAssignLinkTip(amount),
          ].join('\n'),
          onTap: widget.onAssignPlanned,
          rank: 2,
        ),
    ];
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
                // Every row is one height (owner, 2026-11-16, #471, #483).
                vertical: 0,
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
                  // Its emoji, chosen here (#486, sketch C): the spot is
                  // kept on every row so names line up, and shows a +
                  // while the pointer is on a row with none.
                  EmojiButton(
                    key: ValueKey('emoji-${c.id}'),
                    emoji: splitEmoji(c.name).emoji,
                    showEmpty: _hover,
                    enabled: !widget.open,
                    onPick: widget.onEmoji,
                  ),
                  const SizedBox(width: 8),
                  // Its name, then the one spot that says what the row
                  // needs (#483): never a second line.
                  Expanded(
                    child: _NameAndSpot(
                      category: c,
                      bill: oneLine,
                      planText: widget.planNote?.text,
                      bar: oneLine ? null : widget.bar,
                      usedWords: widget.usedWords,
                      said: said,
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
                            // Said first when Left is pointed at: spent
                            // ahead by a paycheck; or, on a bill holding
                            // money, what that money is for (it was a
                            // line under the Bills heading, #482).
                            says:
                                widget.ahead ??
                                (widget.bill && line.left > 0
                                    ? t.planBillLeftTip
                                    : null),
                            child: Money(
                              line.left,
                              key: ValueKey('left-${c.id}'),
                              size: 13.5,
                              // A bill's money is spoken for: quieter.
                              weight: widget.bill ? 400 : 600,
                              currency: widget.currency,
                              // Green has money, coral is short (#326).
                              color: line.left < 0 && widget.ahead == null
                                  ? Mid.coral
                                  : line.left < 0
                                  ? Mid.ink
                                  : line.left == 0
                                  ? Mid.ink3
                                  : Mid.green,
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

/// A category's name and, after it, the one spot that says what its row
/// needs, on one line (owner, 2026-11-16, of the lines that sat under a
/// name: "let's find another way of putting them on the row without
/// impacting the height"; pick 1 of three, #483).
///
/// After the name: the bar, then what [said] holds. When there isn't room
/// for all of it, the lowest `rank` stays and the bar is the first to go,
/// so at the window's smallest the spot holds a warning if there is one,
/// otherwise the Assign link, otherwise the bar. The bar is its full
/// length or not there. A long name is cut, never wrapped, and the note
/// the person wrote is a mark after it; each says the whole of itself
/// when pointed at.
class _NameAndSpot extends StatelessWidget {
  const _NameAndSpot({
    required this.category,
    required this.bill,
    required this.planText,
    required this.bar,
    required this.usedWords,
    required this.said,
  });

  final AccountInfo category;

  /// A bill's row: the name as wide as it is, no bar.
  final bool bill;

  /// The plan's whole sentence.
  final String? planText;
  final ({double left, bool over})? bar;
  final String? usedWords;
  final List<_Said> said;

  static const _noteMark = 20.0;

  @override
  Widget build(BuildContext context) {
    final c = category;
    // The emoji is drawn in its own spot before this (#486).
    final words = splitEmoji(c.name).rest;
    final scaler = MediaQuery.textScalerOf(context);
    // Measured as a Text draws it: over the page's own text style, whose
    // spacing a bare style would leave out, and the name came out cut.
    final base = DefaultTextStyle.of(context).style;
    double wide(String text, TextStyle style) => (TextPainter(
      text: TextSpan(text: text, style: base.merge(style)),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout()).width.ceilToDouble();
    final nameStyle = onest(13.5);

    Widget say(_Said s) {
      Text text(bool hover) => Text(
        s.text,
        key: s.onTap == null ? s.key : null,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: s.style.copyWith(
          decoration: hover ? TextDecoration.underline : null,
          decorationColor: s.style.color,
        ),
      );
      final Widget child = s.onTap == null
          ? text(false)
          : Hoverable(key: s.key, onTap: s.onTap, builder: text);
      final tip = s.tip;
      return tip == null || tip.isEmpty
          ? child
          : Tooltip(
              message: tip,
              waitDuration: const Duration(milliseconds: 400),
              child: child,
            );
    }

    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final note = c.note;
        final nameWide =
            wide(words, nameStyle) + (note == null ? 0 : _noteMark);
        // The name's column: the same down the list, so every bar and
        // every word after a name starts at one place; a bill's is as
        // wide as its name.
        final double cell = bill
            ? (nameWide + 1).clamp(0.0, width / 2)
            : (width * _barNameShare)
                  .clamp(_barNameMin, _barNameMax)
                  .clamp(0.0, width);
        final cut = nameWide > cell + 0.5;
        final room = (width - cell - 12 - 20).clamp(0.0, width);
        // What fits, the most needed first.
        final byRank = [for (final (i, s) in said.indexed) (i, s)]
          ..sort(
            (a, b) => a.$2.rank != b.$2.rank
                ? a.$2.rank.compareTo(b.$2.rank)
                : a.$1.compareTo(b.$1),
          );
        final kept = <int>{};
        var used = 0.0;
        for (final (i, s) in byRank) {
          final need = wide(s.text, s.style) + 1 + (kept.isEmpty ? 0 : 10);
          if (used + need <= room) {
            kept.add(i);
            used += need;
          }
        }
        // Not even one fits: the most needed shows anyway, cut, with its
        // sentence when pointed at.
        final squeezed = kept.isEmpty && byRank.isNotEmpty;
        if (squeezed) kept.add(byRank.first.$1);
        final barWide = room < _barMax ? room : _barMax;
        final showBar =
            bar != null &&
            barWide >= 40 &&
            used + (kept.isEmpty ? 0 : 12) + barWide <= room;
        // Pointed at, the name says what was cut, and the plan when
        // nothing on the row carries it.
        final carried = said.indexed.any(
          (x) =>
              kept.contains(x.$1) &&
              (x.$2.tip ?? '').contains(planText ?? '\u0000'),
        );
        final nameTip = [
          if (cut) words,
          if (planText != null && !carried) planText!,
        ].join('\n');
        final name = Text(
          words,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: nameStyle,
        );
        return Row(
          children: [
            SizedBox(
              width: cell,
              child: Row(
                children: [
                  Flexible(
                    child: nameTip.isEmpty
                        ? name
                        : Tooltip(
                            message: nameTip,
                            waitDuration: const Duration(milliseconds: 600),
                            child: name,
                          ),
                  ),
                  // What they wrote about it (#100): a mark, and the
                  // whole of it when pointed at.
                  if (note != null) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: note,
                      waitDuration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.sticky_note_2_outlined,
                        key: ValueKey('category-note-${c.id}'),
                        size: 14,
                        color: Mid.ink3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (showBar)
              SizedBox(
                width: barWide,
                child: UsedBar(
                  key: ValueKey('used-${c.id}'),
                  left: bar!.left,
                  over: bar!.over,
                  words: usedWords,
                ),
              ),
            for (final (n, i) in (kept.toList()..sort()).indexed) ...[
              if (n > 0 || showBar) SizedBox(width: n == 0 ? 12 : 10),
              // Each has the room it was measured for; only one that
              // doesn't fit gives way.
              squeezed ? Flexible(child: say(said[i])) : say(said[i]),
            ],
            const SizedBox(width: 20),
          ],
        );
      },
    );
  }
}

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
    this.says,
  });

  /// A sentence about this Left, first in its tooltip: spent ahead by a
  /// paycheck, which its month covers (#468); a bill's money, and what it
  /// is put aside for (#482).
  final String? says;

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
    if (onMove == null || !widget.offered) {
      return switch (widget.says) {
        final says? => Tooltip(
          key: ValueKey('left-says-${widget.category.id}'),
          message: says,
          waitDuration: const Duration(milliseconds: 400),
          child: widget.child,
        ),
        null => widget.child,
      };
    }
    final moveTip = widget.inward ? t.planMoveInTip : t.planMoveOutTip;
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
            key: widget.says == null
                ? null
                : ValueKey('left-says-${widget.category.id}'),
            // Two whole sentences, each on its own line.
            message: switch (widget.says) {
              final says? => '$says\n$moveTip',
              null => moveTip,
            },
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
    if (from == null) {
      // From Not assigned into a category that is overspent: what covers
      // the overspending takes nothing, since that already came off
      // (code review).
      final covers = widget.left < 0 ? -widget.left : 0;
      final takes = amount > covers ? amount - covers : 0;
      if (takes <= has) return null;
      return t.planMoveWarnNotAssigned(_money(has), _money(takes - has));
    }
    if (amount <= has) return null;
    final short = _money(amount - has);
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
                      inputFormatters: [GroupedAmount(widget.currency)],
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
    this.paidFrom,
    this.startType,
  });

  /// The type card each one opens on; null for the usual first.
  final CategoryType? startType;

  /// The name it starts with: what was typed in the entry row's Category.
  final String name;

  /// Its Paid from to begin with: the account of the row it's made from.
  final int? paidFrom;

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
  late int? _paidFrom = widget.paidFrom;

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
      _paidFrom = e.paidFrom;
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
                paidFrom: _paidFrom,
                startType: widget.startType,
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
/// What clearing [clears]' Assigned in [period] would do, worked out on
/// the ledger without those amounts, so the window says what the page
/// will (budget review: an overspent category's Assigned was covering
/// what it spent, and doesn't come back to Not assigned).
typedef _ClearSums = ({
  int total,
  int count,
  int freed,
  List<({String name, int before, int after})> short,
  List<({String name, DateTime due})> bills,
  ({String period, int amount})? later,
  int safetyNet,
});

_ClearSums _clearSums(
  Words t,
  LedgerData data,
  BudgetSpan period,
  List<AccountInfo> clears,
  Currency currency,
  Set<int> saved, {
  required DateTime today,
}) {
  final ids = {for (final c in clears) c.id};
  final after = data.withoutAmounts(ids, period.start, period.end);
  Budget of(LedgerData d, BudgetSpan p) =>
      Budget.of(d, start: p.start, end: p.end, today: today);
  final b0 = of(data, period), b1 = of(after, period);
  int free(Budget b) =>
      b.pools.where((p) => p.currency == currency).firstOrNull?.notAssigned ??
      0;
  final short = <({String name, int before, int after})>[];
  final bills = <({String name, DateTime due})>[];
  var total = 0;
  for (final c in clears) {
    final was = b0.lines[c.id]!, now = b1.lines[c.id]!;
    total += was.assigned;
    if (now.left < 0) {
      short.add((name: c.name, before: was.left, after: now.left));
    }
    // A bill due before the period ends, not paid yet, loses what was
    // set aside for it: "will rent bounce?" (budget review).
    final plan = was.plan;
    if (plan != null &&
        plan.plan.kind == PlanKind.byDate &&
        was.paidOn == null &&
        plan.due != null &&
        !plan.due!.isAfter(period.end) &&
        now.left < was.left &&
        now.left >= 0) {
      bills.add((name: c.name, due: plan.due!));
    }
  }
  // An earlier period: what carried from it into today's goes too.
  ({String period, int amount})? later;
  final current = budgetPeriod(today, data.periodSchedule);
  if (period.end.isBefore(current.start)) {
    final c0 = of(data, current), c1 = of(after, current);
    var less = 0;
    for (final id in ids) {
      less += (c0.lines[id]?.left ?? 0) - (c1.lines[id]?.left ?? 0);
    }
    if (less > 0) {
      later = (
        period: current.label == payPeriodLabel
            ? ''
            : monthName(t, current.start.month),
        amount: less,
      );
    }
  }
  var safetyNet = 0;
  for (final id in saved) {
    final l = b0.lines[id];
    if (l != null && l.currency == currency) safetyNet += l.assigned;
  }
  return (
    total: total,
    count: clears.length,
    freed: free(b1) - free(b0),
    short: short,
    bills: bills,
    later: later,
    safetyNet: safetyNet,
  );
}

/// "Clear October's Assigned?" (#100): what comes out, where it goes, and
/// what that leaves short, in real amounts, before it's done. It has undo.
class _ClearAssignedWindow extends StatelessWidget {
  const _ClearAssignedWindow({
    required this.sums,
    required this.month,
    required this.currency,
  });

  final _ClearSums sums;

  /// The month's name; null for a pay period.
  final String? month;
  final Currency currency;

  /// How many short ones are named before "and 3 more".
  static const _named = 6;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final month = this.month;
    final s = sums;
    String money(int v) => formatMoney(v, currency: currency);
    final covering = s.total - s.freed;
    Widget line(String text, {Key? key, Color? color}) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        text,
        key: key,
        style: onest(13.5, color: color, tabular: true),
      ),
    );
    Widget item(String name, String amount, {Key? key, Color? color}) =>
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: onest(13.5),
                ),
              ),
              Text(
                amount,
                key: key,
                style: onest(13.5, color: color, tabular: true),
              ),
            ],
          ),
        );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): () =>
            Navigator.of(context).pop(true),
      },
      child: Dialog(
        backgroundColor: Mid.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Mid.rule),
        ),
        child: SizedBox(
          width: 500,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
            child: Focus(
              autofocus: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    month == null
                        ? t.planClearPayTitle
                        : t.planClearMonthTitle(month),
                    style: onest(17, weight: 600, letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 4),
                  line(
                    t.planClearBody(money(s.total), s.count),
                    key: const ValueKey('clear-assigned-body'),
                  ),
                  // Where it goes: all of it to Not assigned, or only part
                  // when some was covering what was already spent.
                  if (covering > 0)
                    line(
                      t.planClearPart(money(s.freed), money(covering)),
                      key: const ValueKey('clear-assigned-part'),
                    )
                  else
                    line(t.planClearBack),
                  if (s.later case final later?)
                    line(
                      later.period.isEmpty
                          ? t.planClearLaterPay(money(later.amount))
                          : t.planClearLaterMonth(
                              later.period,
                              money(later.amount),
                            ),
                      key: const ValueKey('clear-assigned-later'),
                    ),
                  if (s.short.isNotEmpty) ...[
                    line(
                      month == null
                          ? t.planClearShortPay
                          : t.planClearShortMonth(month),
                    ),
                    // Red for a shortfall, with its minus; one already
                    // short says from what to what.
                    for (final x in s.short.take(_named))
                      item(
                        x.name,
                        x.before < 0
                            ? t.planClearFromTo(money(x.before), money(x.after))
                            : money(x.after),
                        key: ValueKey('clear-short-${x.name}'),
                        color: Mid.coral,
                      ),
                    if (s.short.length > _named)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 4),
                        child: Text(
                          t.planClearMore(s.short.length - _named),
                          style: onest(13.5, color: Mid.ink2),
                        ),
                      ),
                  ],
                  if (s.bills.isNotEmpty) ...[
                    line(t.planClearBills),
                    for (final b in s.bills)
                      item(
                        b.name,
                        t.phoneDue(sayDate(t, b.due)),
                        key: ValueKey('clear-bill-${b.name}'),
                      ),
                  ],
                  if (s.safetyNet != 0)
                    line(
                      t.planClearSafetyNet(money(s.safetyNet)),
                      key: const ValueKey('clear-assigned-safety'),
                      color: Mid.ink2,
                    ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      BarButton(
                        key: const ValueKey('clear-assigned-cancel'),
                        label: t.planCancel,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      _PrimaryButton(
                        key: const ValueKey('clear-assigned-confirm'),
                        label: t.planClear,
                        icon: Icons.check_rounded,
                        tooltip: 'Enter',
                        onTap: () => Navigator.of(context).pop(true),
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
  }
}

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
            inputFormatters: [GroupedAmount(widget.currency)],
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

  // A pane of its own under the sum's boxes, which have none (#464): the
  // one thing here that's a question, gone once answered.
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('start-offer'),
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
    decoration: BoxDecoration(
      color: Mid.panel,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Mid.rule),
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

/// A warning on a line: a few words for the row ([short]), the whole
/// sentence for when it's pointed at ([text]), and what a click does.
typedef _LineFlag = ({String text, String short, VoidCallback? onTap});

/// One thing a row says after its name (#483): a few words, with the
/// whole sentence in [tip] for when it's pointed at. [rank] is which is
/// kept when there isn't room for all, lowest first.
typedef _Said = ({
  Key key,
  String text,
  TextStyle style,
  String? tip,
  VoidCallback? onTap,
  int rank,
});

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

/// What a spending line says about its money (rule 28): its Paid from
/// account put away, and rows in the other currency. What its account
/// holds is no longer said here (#461): that is the Ledger's.
List<_LineFlag> _lineFlags(
  Words t,
  LedgerData data,
  AccountInfo c,
  EnvelopeLine line, {
  required bool paidGone,
  required VoidCallback onAccounts,
  required VoidCallback onRows,
  required VoidCallback onAllRows,
}) {
  String money(int v, [Currency? currency]) =>
      formatShort(v, currency: currency ?? c.currency);
  final paid = data.accounts[data.paidFrom[c.id]];
  return [
    // Its account put away: nothing of it is in a forecast until another
    // is picked (warn, don't block).
    if (paidGone && paid != null && (paid.archived || paid.deleted))
      (
        text: t.planPaidFromGone(paid.name),
        short: t.planPaidFromGoneShort,
        onTap: onAccounts,
      ),
    if (line.otherCurrency case final other? when line.otherRows > 0)
      (
        text: t.planOtherRows(
          line.otherRows,
          money(line.otherAmount, other),
          c.currency.shown,
          other.shown,
        ),
        short: t.planOtherRowsShort(money(line.otherAmount, other)),
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
    this.bills = const [],
    this.loan = false,
    this.onBills,
    this.onAdd,
    this.offerAnother = false,
    this.nameNote,
    this.keep,
    this.paidFrom,
    this.startType,
  });

  /// The type card a new one opens on (#475: the walkthrough's Add a
  /// bill); null for the usual first card.
  final CategoryType? startType;

  /// Where what's typed is kept while the page is left; null in the New
  /// category window, whose answers are its own.
  final _EditDraft? keep;

  /// A new category's Paid from to begin with: the account of the row it's
  /// made from.
  final int? paidFrom;

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

  /// This period's bills, each a switch (#365): on while it's expected.
  /// Save skips those switched off and brings back those switched on, by
  /// [onBills] (the dates to skip, the dates to bring back).
  final List<({DateTime date, bool skipped})> bills;
  final bool loan;
  final Future<void> Function(List<DateTime> skip, List<DateTime> back)?
  onBills;
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

  /// A bill's switch is on while it's expected: a skipped bill's begins
  /// off, and a flip turns it over (#365).
  bool _expected(({DateTime date, bool skipped}) b) =>
      b.skipped == _d.flips.contains(b.date);

  /// The plan's answers, and what they add up to: the phone's New
  /// category page asks the same.
  PlanAnswers get _p => _d.p;
  final _nameFocus = FocusNode(debugLabel: 'category-name');
  final _amountFocus = FocusNode(debugLabel: 'plan-amount');
  final _dateFocus = FocusNode(debugLabel: 'plan-date');
  final _upToFocus = FocusNode(debugLabel: 'plan-up-to');
  final _datesFocus = FocusNode(debugLabel: 'plan-dates');
  final _day1Focus = FocusNode(debugLabel: 'plan-day1');
  final _onceFocus = FocusNode(debugLabel: 'plan-once');
  final _noteFocus = FocusNode(debugLabel: 'category-note');
  final _newGroupFocus = FocusNode(debugLabel: 'category-new-group');
  final _groupMenu = MenuController();
  final _menus = _HowOftenMenus();
  final _eachMenu = MenuController();

  final _accountsMenu = MenuController();
  final _currencyMenu = MenuController();

  /// Closes a dropdown that's open in the panel: Esc and Enter are its
  /// own before they're the panel's.
  bool _closeMenu() {
    for (final m in [..._menus.all, _accountsMenu, _currencyMenu, _groupMenu]) {
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

  /// The account it's paid from (#180): as picked; else as saved, in the
  /// currency it's in; else the account the row it's made from is in, or
  /// the only account in its currency. Otherwise it waits to be chosen
  /// (owner, 2026-10-27: "They should specify this when they setup the
  /// given category"): no guess.
  int? get _paidFrom {
    if (_d.paidFromPicked) return _d.paidFrom;
    final open = categoryAccounts(widget.data, _currency).map((a) => a.id);
    final saved = widget.data.paidFrom[widget.category.id];
    if (saved != null && open.contains(saved)) return saved;
    if (widget.paidFrom case final a? when open.contains(a)) return a;
    return open.length == 1 ? open.single : null;
  }

  set _paidFrom(int? id) {
    _d.paidFrom = id;
    _d.paidFromPicked = true;
  }

  /// Save needs one, when its currency has an account to be paid from: for
  /// a new category, or one put in another currency. One that has none yet
  /// (the Safety net, left to every account) still saves anything else.
  bool get _wantsPaidFrom =>
      (widget.isNew || _currency != widget.category.currency) &&
      _paidFrom == null &&
      categoryAccounts(widget.data, _currency).isNotEmpty;
  bool get _inMonth =>
      _d.inMonth ??
      (widget.isNew || inMonthOfExpenses(widget.data, widget.category.id));
  set _inMonth(bool on) => _d.inMonth = on;
  bool get _goal =>
      _d.goal ??
      (!widget.isNew &&
          widget.data.prefs[ReadyKeys.goal(widget.category.id)] == 'yes');
  set _goal(bool on) => _d.goal = on;

  /// A goal: an amount by a date, once or repeating (owner, 2026-11-11),
  /// picked as the Goal card. Never the Safety net.
  bool get _isGoal => _p.hasDate && _goal && !isSafetyNet(widget.category);

  /// The type its answers make (#429): no type is stored, so a category
  /// opens on the card its plan already is.
  CategoryType get _type => _p.hasDate
      ? (_isGoal ? CategoryType.goal : CategoryType.bill)
      : _p.spentEach
      ? CategoryType.dayToDay
      : CategoryType.fund;

  /// The type cards head the form; not the Safety net's, which is built
  /// into the app as money put by and is no type to choose.
  bool get _asksType => !isSafetyNet(widget.category);

  /// How often as the window last set it for a type: while it's still
  /// that, How often wasn't picked, and another type can set its own. Any
  /// other answer in the block (the weekend rule, Ends) leaves it so.
  Object? _repeatSet = (PlanRepeat.once, false, '1', PlanUnit.months);
  Object get _repeatNow => (_p.repeat, _p.custom, _p.everyN.text, _p.unit);

  /// A day-to-day category with a cap had one when Edit opened: the row
  /// stays while it's typed in, emptied or not (code review).
  bool _capWas = false;

  /// The answers [type] stands for, as its card sets them.
  void _applyType(CategoryType type) {
    final dated = type == CategoryType.bill || type == CategoryType.goal;
    _p.hasDate = dated;
    if (!dated) _p.spentEach = type == CategoryType.dayToDay;
    if (dated) _goal = type == CategoryType.goal;
    // A new one's How often starts where its type usually is: a bill
    // every month, a goal once. Until How often is picked.
    if (widget.isNew && _repeatNow == _repeatSet) {
      if (type == CategoryType.bill) _p.preset(1, PlanUnit.months);
      if (type == CategoryType.goal) {
        _p.repeat = PlanRepeat.once;
        _p.custom = false;
      }
      _repeatSet = _repeatNow;
    }
    _tried = false;
  }

  /// A type card picked: the answers it stands for. Nothing else typed
  /// goes; an amount, a date and Paid from stay for another card.
  void _pickType(CategoryType type) {
    final dated = type == CategoryType.bill || type == CategoryType.goal;
    final was = _p.hasDate;
    setState(() => _applyType(type));
    if (was != dated) {
      _p.amount.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _p.amount.text.length,
      );
    }
    // From the name, the cursor stays to finish typing it; otherwise it
    // goes to the type's first question.
    if (!_nameFocus.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _amountFocus.requestFocus();
      });
    }
  }

  /// Savings' month of expenses can leave it out: not the Safety net,
  /// which is never in it.
  bool get _asksInMonth => !isSafetyNet(widget.category);

  /// The category as the panel has it: a new one is in whatever currency
  /// is picked, and called what's typed.
  AccountInfo get _cat => widget.isNew
      ? AccountInfo(
          id: widget.category.id,
          name: _fullName,
          type: AccountType.expense,
          currency: _currency,
        )
      : widget.category;

  /// The account a dated plan's bill is scheduled in: the category's Paid
  /// from. One control says both (owner, 2026-10-05: "two account
  /// selectors: just have one"). A plan saved with an account since
  /// archived keeps it while Paid from isn't touched: nothing is rewritten
  /// behind the user's back (code review, 2026-10-05).
  int? get _paidFromNow {
    if (!_p.hasDate) return null;
    final saved = _plan?.paidFrom;
    if (!_d.paidFromPicked &&
        saved != null &&
        widget.data.accounts[saved]?.archived == true) {
      return saved;
    }
    return _paidFrom;
  }

  /// Save was tried with something missing: say which.
  bool _tried = false;

  /// Saved: Enter reaches both the field and the panel, and must save once.
  bool _done = false;

  /// Scrolls the panel into view once the row has grown: opened on a
  /// category low in the list, its Save would be under the window's edge.
  Timer? _reveal;

  CategoryPlan? get _savedPlan => widget.data.plans[widget.category.id];

  /// The saved plan while it still means something: in another currency
  /// its amounts don't, so the plan starts over there.
  CategoryPlan? get _plan => _currency == _cat.currency ? _savedPlan : null;

  /// The set amount's own period around the one on screen: the one "Just
  /// for December" is about. None in the New category window, where
  /// there's no plan yet to set it apart from.
  DateTime? _onceStartFor(int? payId) => widget.isNew
      ? null
      : budgetPeriod(
          widget.period.start,
          widget.data.payScheduleById(payId),
        ).start;

  /// The groups the Budget page has, each once whatever its case: those
  /// of day-to-day categories, the only ones it shows (#469).
  List<String> get _groups {
    final data = widget.data;
    final byCase = <String, String>{
      for (final g in [
        for (final c in data.categories)
          if (typeOf(data, c.id) == CategoryType.dayToDay) ?c.budgetGroup,
      ])
        g.toLowerCase(): g,
    };
    final names = byCase.values.toList();
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  /// The group as Edit has it: a new one typed takes the spelling of a
  /// group already there.
  String? get _groupNow {
    final typed = _d.newGroup?.text.trim();
    if (typed == null) return _d.group;
    if (typed.isEmpty) return null;
    return _groups
            .where((g) => g.toLowerCase() == typed.toLowerCase())
            .firstOrNull ??
        typed;
  }

  @override
  void initState() {
    super.initState();
    _name.addListener(_takeTypedEmoji);
    final saved = _savedPlan;
    final onceWas = _p.onceStart;
    _p.onceStart = _onceStartFor(
      saved?.kind == PlanKind.each
          ? saved!.payScheduleId
          : widget.data.periodSchedule?.id,
    );
    // Kept typing from another period's Edit: this period's own amount.
    if (_d.filled && onceWas != _p.onceStart) _p.showOnce(saved);
    // Kept from before the page was left: the answers are already in.
    if (!_d.filled) _showPlan(_savedPlan);
    // A fund with no amount yet has no plan to say so: its mark does.
    if (!_d.filled &&
        saved == null &&
        widget.data.prefs[BudgetKeys.fund(widget.category.id)] == 'yes') {
      _p.spentEach = false;
    }
    final fresh = !_d.filled;
    _d.filled = true;
    if (widget.startType case final type? when fresh && widget.isNew) {
      _applyType(type);
    }
    _capWas = _p.upTo.text.trim().isNotEmpty;
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
      _day1Focus,
      _onceFocus,
      _noteFocus,
      _newGroupFocus,
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
    _name.removeListener(_takeTypedEmoji);
    if (widget.keep == null) _d.dispose();
    _nameFocus.dispose();
    _amountFocus.dispose();
    _dateFocus.dispose();
    _upToFocus.dispose();
    _datesFocus.dispose();
    _day1Focus.dispose();
    _onceFocus.dispose();
    _noteFocus.dispose();
    _newGroupFocus.dispose();
    _panelFocus.dispose();
    _panelScope.dispose();
    super.dispose();
  }

  /// Fills the plan's fields from [p], or empties them.
  void _showPlan(CategoryPlan? p) => _p.show(
    p,
    periodPayId: widget.data.periodSchedule?.id,
    builtUp: isSafetyNet(widget.category),
  );

  /// The plan as typed. Null with a kind picked means something is missing.
  CategoryPlan? get _draft => _p.draft(
    categoryId: widget.category.id,
    paidFrom: _paidFromNow,
    old: _plan,
    // A goal counts from where it began (#101): a new amount or date
    // keeps the deposit already paid from it saved toward it.
    keepOnceStart: _isGoal,
  );

  /// The name as it will be saved: the square's emoji, then the words.
  String get _fullName => withEmoji(_d.emoji, _name.text.trim());

  /// An emoji typed or pasted at the start of the name (the Mac's or
  /// Windows' emoji panel) goes into the square, so it's the one picked
  /// rather than a second (#486).
  void _takeTypedEmoji() {
    final s = splitEmoji(_name.text);
    final e = s.emoji;
    if (e == null) return;
    _name.value = TextEditingValue(
      text: s.rest,
      selection: TextSelection.collapsed(offset: s.rest.length),
    );
    if (mounted) {
      setState(() => _d.emoji = e);
    } else {
      _d.emoji = e;
    }
  }

  Future<void> _save({bool another = false}) async {
    if (_done) return;
    final name = _fullName;
    if (_name.text.trim().isEmpty ||
        (widget.nameNote?.call(name)?.blocks ?? false)) {
      setState(() => _tried = true);
      _nameFocus.requestFocus();
      return;
    }
    // A name that's a category already: Add opens that one, so nothing
    // here is asked of it.
    if (_wantsPaidFrom && widget.nameNote?.call(name) == null) {
      setState(() => _tried = true);
      _accountsMenu.open();
      return;
    }
    final draft = _draft;
    if (_p.kind != null && draft == null) {
      setState(() => _tried = true);
      (_p.typedAmount == null
              ? _amountFocus
              : !_p.hasDate
              ? (_p.missing == PlanMissing.once ? _onceFocus : _upToFocus)
              : _p.repeat == PlanRepeat.dates
              ? _datesFocus
              : _p.repeat == PlanRepeat.twice && _p.missing != PlanMissing.date
              ? _day1Focus
              : _dateFocus)
          .requestFocus();
      return;
    }
    _done = true;
    final edit = (
      name: name,
      currency: _currency,
      paidFrom: _paidFrom,
      plan: draft,
      inMonth: _inMonth,
      goal: _isGoal,
      fund: _asksType && _type == CategoryType.fund && draft == null,
      group: _groupNow,
      note: _d.note.text.trim().isEmpty ? null : _d.note.text.trim(),
    );
    final add = widget.onAdd;
    if (add == null) {
      // One after the other, so each one's popup reads what the last did.
      await widget.onBills?.call(
        [
          for (final b in widget.bills)
            if (!b.skipped && _d.flips.contains(b.date)) b.date,
        ],
        [
          for (final b in widget.bills)
            if (b.skipped && _d.flips.contains(b.date)) b.date,
        ],
      );
      return widget.onSave(edit);
    }
    final made = await add(edit, another: another);
    // Not made: the answers stay, to be changed and added again.
    if (!made && mounted) _done = false;
  }

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

  /// The plan as a short form: is there a due date, then what that
  /// needs. [line] is the category worked out with the answers so far,
  /// for the amount a dated plan comes to each period.
  List<Widget> _planFields(
    Words t, {
    required EnvelopeLine? line,
    required CategoryPlan? draft,
  }) {
    final wrongAmount = _tried && _p.kind != null && _p.typedAmount == null;
    // Twice a month's Starts may be left empty (#356).
    final wrongDate =
        _tried &&
        _p.hasDate &&
        (_p.repeat == PlanRepeat.twice ? _p.wrongStart : _p.typedDate == null);
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
        inputFormatters: [GroupedAmount(_currency)],
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
      part = _p.repeat == PlanRepeat.twice
          ? t.planEnterAmountDays
          : t.planEnterAmountDate;
    } else if ((line?.plan?.each ?? 0) > 0) {
      part = money(line!.plan!.each);
    } else {
      part = t.planNothingMore;
    }
    final due = line?.plan?.due ?? draft?.due ?? _p.typedDate;
    final dueText = due == null
        ? null
        : due.year == widget.today.year
        ? sayDate(t, due)
        : sayFullDate(t, due);
    // The type cards ask what "Is there a due date?", "This money is" and
    // "Show on Savings as a goal?" asked, in one go (#429). Each type gets
    // only its own questions.
    final type = _type;
    final fund = _asksType && type == CategoryType.fund;
    return [
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
        if (hasAmount && _p.onceStart != null)
          _onceRow(t, amountField, line: line),
        // Shown whether or not an amount is typed: it answers "do we
        // ever zero it out?" (owner, 2026-10-05).
        ...[
          // Whether the money goes out within its period: the one fact
          // the forecast was missing, which the carry-over answer below
          // doesn't carry (#404). The cards ask it, as Day-to-day or
          // Fund; the Safety net, which has none, asks it here.
          if (!_asksType)
            _formRow(
              t.planMoneyIs,
              _Segmented(
                items: [
                  (
                    'plan-spent-each',
                    byPay ? t.planSpentEachPay : t.planSpentEachMonth,
                    _p.spentEach,
                    () => setState(() => _p.spentEach = true),
                  ),
                  (
                    'plan-built-up',
                    t.planBuiltUp,
                    !_p.spentEach,
                    () => setState(() => _p.spentEach = false),
                  ),
                ],
              ),
            ),
          // A fund keeps what's left: the question is a day-to-day
          // category's, and a fund's only while it says otherwise.
          if (!fund || !_p.rollover)
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
          // What a fund holds at most. A day-to-day category is spent each
          // month, so it isn't asked, but one that has a cap keeps it in
          // view.
          if (_p.rollover && hasAmount && (fund || !_asksType || _capWas))
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
        _accountsRow(
          t,
          // What This money is means for this account: spent within its
          // period, the forecast takes it out a day at a time (#179);
          // built up for later, it stays there (#404).
          aside: switch (widget.data.accounts[_paidFrom]) {
            final a? when _p.kind == PlanKind.each =>
              _p.spentEach
                  ? t.planPaidFromSpendHint(a.name)
                  // Built up and swept back each period: it does not sit
                  // in the account, so don't say it does (budget-app
                  // review). The sentence is only for money that stays.
                  : _p.rollover
                  ? t.planPaidFromSaveHint(a.name)
                  : null,
            // With no account there is nothing for the forecast to take
            // the money from, so the category changes no chart at all and
            // nothing on screen would say why (#404).
            null when _p.kind == PlanKind.each && _p.spentEach =>
              t.planPaidFromNoneSpend,
            _ => null,
          },
        ),
      ] else ...[
        _formRow(
          // Nothing is owed on a goal: it's an amount to have ready.
          type == CategoryType.goal ? t.planAmountReady : t.planAmountDue,
          amountField(
            _p.amount,
            _amountFocus,
            key: 'plan-amount',
            wrong: wrongAmount,
            autofocus: widget.atPlan,
          ),
        ),
        _HowOftenRows(
          p: _p,
          data: widget.data,
          today: widget.today,
          tried: _tried,
          wrongDate: wrongDate,
          menus: _menus,
          onSave: _save,
          onChanged: () => setState(() {}),
          dateLabel: type == CategoryType.goal ? t.planReadyBy : null,
          dateFocus: _dateFocus,
          datesFocus: _datesFocus,
          day1Focus: _day1Focus,
          onMenuOpen: _panelFocus.requestFocus,
          startNote: _p.startNote(t, draft, money, old: _plan),
        ),
        _accountsRow(
          t,
          aside: switch ((paidAccount, dueText)) {
            (final a?, final due?) => t.planPaidFromHint(a.name, due),
            // No date yet: what's left to do (#163).
            (final a?, null) => t.planPaidFromHintNone(a.name),
            _ => null,
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

  /// Whether Savings counts it in a month of expenses (owner, 2026-10-26),
  /// with what the answer means beside it.
  /// "Just for December" (#100): one of the set amount's own periods
  /// asks for an amount of its own, or nothing, and the next goes back to
  /// the plan's. Said beside it with the real amounts.
  Widget _onceRow(
    Words t,
    Widget Function(
      TextEditingController controller,
      FocusNode focus, {
      required String key,
      required bool wrong,
      bool autofocus,
      String? hint,
    })
    amountField, {
    required EnvelopeLine? line,
  }) {
    final start = _p.onceStart!;
    final pay = widget.data.payScheduleById(_p.eachPayId);
    final next = nextBudgetPeriod(budgetPeriod(start, pay), pay).start;
    final month = monthName(t, start.month);
    final usual = switch (_p.typedAmount) {
      final a? => formatShort(a, currency: _currency),
      null => null,
    };
    final once = _p.typedOnce;
    // The period after has its own amount too: "back to" would be wrong.
    final nextOwn = _plan?.once.containsKey(next) ?? false;
    String? aside;
    if (once == null || usual == null || _p.wrongOnce || nextOwn) {
      aside = null;
    } else if (pay == null) {
      aside = once == 0
          ? t.planOnceSkippedMonth(month, usual, monthName(t, next.month))
          : t.planOnceBackMonth(usual, monthName(t, next.month));
    } else {
      aside = once == 0
          ? t.planOnceSkippedPay(usual, sayDate(t, next))
          : t.planOnceBackPay(usual, sayDate(t, next));
    }
    // Up to holds it down: said, with what it comes to (budget review).
    final plan = line?.plan;
    final cap = _p.rollover ? _p.typedUpTo : null;
    if (aside != null &&
        plan != null &&
        plan.once &&
        cap != null &&
        once != null &&
        plan.planned < once) {
      final held = formatShort(plan.planned, currency: _currency);
      final capText = formatShort(cap, currency: _currency);
      aside =
          '$aside ${pay == null ? t.planOnceCappedMonth(capText, month, held) : t.planOnceCappedPay(capText, held)}';
    }
    return _formRow(
      pay == null ? t.planOnceMonth(month) : t.planOncePay(sayDate(t, start)),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          amountField(
            _p.onceAmount,
            _onceFocus,
            key: 'plan-once',
            wrong: _tried && _p.wrongOnce,
          ),
          // Offered while it isn't skipped already.
          if (once != 0) ...[
            const SizedBox(width: 8),
            BarButton(
              key: const ValueKey('plan-once-skip'),
              label: pay == null ? t.planSkipMonth(month) : t.planSkipPay,
              onTap: () => setState(() => _p.onceAmount.text = '0'),
            ),
          ],
          // Back to the plan's amount by the mouse alone (budget review).
          if (_p.onceAmount.text.trim().isNotEmpty && usual != null) ...[
            const SizedBox(width: 8),
            BarButton(
              key: const ValueKey('plan-once-usual'),
              label: t.planOnceUsual(usual),
              onTap: () => setState(() => _p.onceAmount.clear()),
            ),
          ],
        ],
      ),
      aside: aside,
    );
  }

  /// Its group on the Budget page (#100): a heading it sits under. New
  /// group… is first, then none, then the groups there are.
  Widget _groupRow(Words t) {
    final typing = _d.newGroup;
    final Widget control;
    if (typing != null) {
      control = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 220,
            height: 34,
            child: TextField(
              key: const ValueKey('category-new-group'),
              controller: typing,
              focusNode: _newGroupFocus,
              style: onest(13.5),
              onSubmitted: (_) => _save(),
              decoration: _fieldDecoration(hint: t.planGroupName),
            ),
          ),
          const SizedBox(width: 8),
          // Back to the dropdown by the mouse alone (code review).
          BarButton(
            key: const ValueKey('category-new-group-cancel'),
            label: t.planCancel,
            onTap: () => setState(() {
              _d.newGroup?.dispose();
              _d.newGroup = null;
            }),
          ),
        ],
      );
    } else {
      Widget item(String key, String label, VoidCallback onTap) =>
          MenuItemButton(
            key: ValueKey(key),
            onPressed: onTap,
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(200, 34)),
              overlayColor: WidgetStatePropertyAll(Mid.blueWash),
            ),
            child: Text(label, style: onest(13, color: Mid.ink2)),
          );
      control = SizedBox(
        height: 34,
        child: MenuAnchor(
          controller: _groupMenu,
          style: _menuStyle,
          menuChildren: focusFirstOnKeys([
            item('category-group-new', t.planNewGroup, () {
              setState(() => _d.newGroup = TextEditingController());
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _newGroupFocus.requestFocus();
              });
            }),
            item(
              'category-group-none',
              t.planNoGroup,
              () => setState(() => _d.group = null),
            ),
            for (final g in _groups)
              item('category-group-$g', g, () => setState(() => _d.group = g)),
          ]),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: BarButton(
              key: const ValueKey('category-group'),
              label: _d.group ?? t.planNoGroup,
              trailing: Icons.expand_more_rounded,
              active: _groupMenu.isOpen,
              onTap: () =>
                  _groupMenu.isOpen ? _groupMenu.close() : _groupMenu.open(),
            ),
          ),
        ),
      );
    }
    return _formRow(t.planGroup, control);
  }

  /// This period's bills, a switch each (#365; owner, 2026-11-03: skipping
  /// is the category's Edit's, saved with Save).
  Widget _billsRow(Words t) => _formRow(
    widget.loan ? t.planPaymentsHere : t.planBillsHere,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in widget.bills)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                key: ValueKey('bill-switch-${dateKey(b.date)}'),
                value: _expected(b),
                onChanged: (_) => setState(() {
                  if (!_d.flips.remove(b.date)) _d.flips.add(b.date);
                }),
              ),
              const SizedBox(width: 6),
              Text(
                (widget.loan ? t.planPaymentComes : t.planBillComes)(
                  b.date.year == widget.today.year
                      ? sayDate(t, b.date)
                      : sayFullDate(t, b.date),
                ),
                style: onest(13.5),
              ),
            ],
          ),
      ],
    ),
  );

  /// What the person wants to remember about it, under its name (#100).
  Widget _noteRow(Words t) => _formRow(
    t.planNote,
    SizedBox(
      width: 420,
      height: 34,
      child: TextField(
        key: const ValueKey('category-note'),
        controller: _d.note,
        focusNode: _noteFocus,
        style: onest(13.5),
        onSubmitted: (_) => _save(),
        decoration: _fieldDecoration(),
      ),
    ),
  );

  Widget _inMonthRow(Words t) => _formRow(
    t.planInMonthQ,
    _Segmented(
      items: [
        (
          'plan-in-month-no',
          t.planNo,
          !_inMonth,
          () => setState(() => _inMonth = false),
        ),
        (
          'plan-in-month-yes',
          t.planYes,
          _inMonth,
          () => setState(() => _inMonth = true),
        ),
      ],
    ),
    aside: _inMonth ? t.planInMonthYesMeans : t.planInMonthNoMeans,
  );

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
                _d.paidFromPicked = false;
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

  /// Paid from (#180): one account in its currency, picked from a
  /// dropdown with each one's balance. The one row for both the account its
  /// bills and its forecast spending come out of; any account in its
  /// currency can still pay it.
  Widget _accountsRow(Words t, {String? aside}) {
    final accounts = categoryAccounts(widget.data, _currency).toList();
    final chosen = widget.data.accounts[_paidFrom];
    final missing = _tried && _wantsPaidFrom;
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
                onPressed: () => setState(() => _paidFrom = a.id),
                style: ButtonStyle(
                  minimumSize: const WidgetStatePropertyAll(Size(320, 34)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  overlayColor: WidgetStatePropertyAll(Mid.blueWash),
                ),
                leadingIcon: Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: a.id == chosen?.id ? Mid.blue : Colors.transparent,
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
                  style: onest(13, color: Mid.ink),
                ),
              ),
          ]),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: BarButton(
              key: const ValueKey('money-accounts'),
              label: chosen?.name ?? t.planPaidFromChoose,
              color: missing ? Mid.coral : null,
              trailing: Icons.expand_more_rounded,
              active: _accountsMenu.isOpen,
              onTap: () => _accountsMenu.isOpen
                  ? _accountsMenu.close()
                  : _accountsMenu.open(),
            ),
          ),
        ),
      ),
      aside: missing ? t.planPaidFromWanted : aside,
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
        _d.note,
        ?_d.newGroup,
        _p.amount,
        _p.onceAmount,
        _p.date,
        _p.upTo,
        _p.everyN,
        _p.dates,
        _p.day1,
        _p.day2,
        _p.daysAfter,
        _p.endDate,
        _p.endCount,
      ]),
      builder: (context, _) {
        // How Often may have moved the set amount to another period.
        _p.onceStart = _onceStartFor(_p.eachPayId);
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
        // What keeping its money in its Paid from sets aside, with the
        // real amounts (owner, 2026-10-27, #183: "say a given amount of the
        // account is only for emergency fund. It should be free to
        // budget"): only what it has left is its; the rest of the account
        // can be assigned. For one keeping money (not spent down), in a
        // cash or bank account; a card holds none.
        final kept = accounts
            .where((a) => !a.isOwed && a.id == _paidFrom)
            .firstOrNull;
        final keeps = !(_p.kind == PlanKind.each && !_p.rollover);
        final holds = _currency == c.currency ? widget.holds : null;
        // What's free there: the account less what's left in every
        // category paid from it, this one included.
        var free = 0;
        if (kept != null && keeps && holds != null && holds > 0) {
          final lines = Budget.of(
            data,
            start: widget.period.start,
            end: widget.period.end,
            today: widget.today,
          ).lines;
          free = data.balanceOf(kept.id) - holds;
          for (final MapEntry(key: id, value: l) in lines.entries) {
            if (id != c.id && data.paidFrom[id] == kept.id && l.left > 0) {
              free -= l.left;
            }
          }
        }
        final rest = kept == null || free <= 0
            ? null
            : t.planMoneyRestOne(say(holds!), kept.name, c.name, say(free));
        // Opened low in the list, or grown by a choice, Save would be
        // under the window's edge.
        // The repeat rows grow it too: Custom…, its unit, Ends.
        final shape = Object.hash(
          _p.hasDate,
          _type,
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
            : widget.nameNote?.call(_fullName);
        final String? nameNote =
            taken?.text ??
            (widget.isNew && _tried && typedName.isEmpty
                ? t.planEnterName
                : null);
        final nameNoteColor = taken == null || taken.blocks
            ? Mid.coral
            : Mid.ink2;

        final cards = _asksType
            ? TypeCards(
                type: _type,
                byPay: _p.eachPayId != null,
                onPick: _pickType,
              )
            : null;

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
                            // In the window, the type comes first: it's
                            // the window's one question (sketch A, #429).
                            if (cards != null && widget.isNew) ...[
                              cards,
                              const SizedBox(height: 20),
                            ],
                            // The name is the heading; the currency sits
                            // quiet beside it, set once.
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // The name's emoji (#486): picked here or
                                // typed at the start of the name.
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: EmojiButton(
                                    key: const ValueKey('edit-emoji'),
                                    emoji: _d.emoji,
                                    size: 34,
                                    onPick: (e) => setState(() => _d.emoji = e),
                                  ),
                                ),
                                const SizedBox(width: 10),
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
                            // In Edit, under the name it heads.
                            if (cards != null && !widget.isNew) ...[
                              cards,
                              const SizedBox(height: 22),
                            ],
                            ..._planFields(t, line: line, draft: draft),
                            // Kept for Edit: the window asks only what
                            // makes the category its type (#429).
                            if (_asksInMonth && !widget.isNew) _inMonthRow(t),
                            // Groups are inside Day-to-day (#469): a fund,
                            // bill or goal sits under its type, and the
                            // Safety net under Saved, whatever group
                            // they'd have.
                            if (_type == CategoryType.dayToDay &&
                                !isSafetyNet(widget.category) &&
                                !widget.isNew)
                              _groupRow(t),
                            if (!widget.isNew) _noteRow(t),
                            if (!widget.isNew && widget.bills.isNotEmpty)
                              _billsRow(t),
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
                                              : _fullName,
                                          style: onest(13.5, weight: 600),
                                        ),
                                        if (preview != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Row(
                                              children: [
                                                // The plan's whole
                                                // sentence, wrapped: Edit
                                                // is where it's said in
                                                // full (#483).
                                                Flexible(
                                                  child: Text(
                                                    preview,
                                                    key: const ValueKey(
                                                      'plan-preview',
                                                    ),
                                                    style: onest(
                                                      12.5,
                                                      color: note!.behind
                                                          ? Mid.ink
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
                                        if (_d.note.text.trim() case final note
                                            when note.isNotEmpty)
                                          Text(
                                            note,
                                            key: const ValueKey('note-preview'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: onest(12, color: Mid.ink3),
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
                                  label: t.planAddThenAnother,
                                  onTap: () => _save(another: true),
                                ),
                              ),
                            // The whole act (owner, 2026-11-11).
                            _PrimaryButton(
                              key: const ValueKey('new-category-add'),
                              label: t.planAddToBudget,
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

/// Budget by month, or by one pay's paychecks (#474): chosen at setup and
/// in Settings, the only places it's switched (owner, 2026-11-16).
class _BudgetByChoice extends StatelessWidget {
  const _BudgetByChoice({required this.data, required this.onPick});
  final LedgerData data;
  final ValueChanged<PaySchedule?> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final by = data.periodSchedule;
    final one = data.paySchedules.length == 1;
    return _Segmented(
      items: [
        ('budget-by-month', t.planByMonth, by == null, () => onPick(null)),
        for (final p in data.paySchedules)
          (
            'budget-by-${p.id}',
            one ? t.planByPaycheck : t.planByPaychecksOf(payTitle(t, data, p)),
            by?.id == p.id,
            () => onPick(p),
          ),
      ],
    );
  }
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
      name = TextEditingController(text: splitEmoji(c.name).rest),
      emoji = splitEmoji(c.name).emoji,
      note = TextEditingController(text: c.note ?? ''),
      group = c.budgetGroup,
      p = PlanAnswers(today: today, currency: c.currency)..askStart = true;
  final int id;

  /// The name's words; its emoji is [emoji], in the square before it.
  final TextEditingController name;
  String? emoji;
  final PlanAnswers p;

  /// The bills' switches the person turned in Edit (#365), by date: only
  /// their flips, so a bill that changes under an open Edit isn't undone
  /// by Save, and the flips stay across a page change.
  final flips = <DateTime>{};

  /// What's written about it, shown under its name (#100).
  final TextEditingController note;

  /// Its group, as picked; null for none.
  String? group;

  /// New group… was picked: its name is being typed here.
  TextEditingController? newGroup;

  /// The account it's paid from, as picked; read only once [paidFromPicked].
  int? paidFrom;
  bool paidFromPicked = false;

  /// In a month of expenses, as answered; null until it is.
  bool? inMonth;

  /// Shown on Savings as a goal, as answered; null until it is.
  bool? goal;

  /// The answers were filled from the saved plan.
  bool filled = false;

  void dispose() {
    name.dispose();
    note.dispose();
    newGroup?.dispose();
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
