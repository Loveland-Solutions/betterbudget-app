part of 'ledger_screen.dart';

// Goals on Savings (#101, #102; ADR 0004 "Goals on Savings"): an amount by
// a date, such as a wedding or a car, under the four steps. Each is a
// once-only "On a date" line on Budget, which asks for its parts; here it
// says how far along it is, and what to do when it falls behind.

/// The New goal panel's answers, held by the screen as the other Savings
/// fields are ([_SavingsKeep]), so another page or ⌘N doesn't lose them.
class _GoalDraft {
  final name = TextEditingController();
  final amount = TextEditingController();
  final date = TextEditingController();

  /// The field Add found missing or unreadable, said under it.
  String? wrong;

  List<TextEditingController> get _all => [name, amount, date];
  Listenable get typing => Listenable.merge(_all);

  /// Something was typed: a click away keeps it open.
  bool get changed => _all.any((c) => c.text.trim().isNotEmpty);

  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
  }
}

/// The Goals heading, a card for each goal, and Add a goal.
class _Goals extends StatelessWidget {
  const _Goals({
    required this.r,
    required this.data,
    required this.today,
    required this.actions,
  });
  final Readiness r;
  final LedgerData data;
  final DateTime today;
  final _SavingsActions actions;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final keep = actions.keep;
    return ListenableBuilder(
      listenable: keep,
      builder: (context, _) {
        final open = keep.goal != null;
        final owed = r.consumerDebts.fold(0, (sum, d) => sum + d.owed);
        // Said while there's a goal or one is being added: what saving for
        // it now costs the steps before it. A warning; nothing is stopped.
        final String? before = r.goals.isEmpty && !open
            ? null
            : owed > 0
            ? t.goalsDebtNote(_here(context, owed))
            : r.stateOf(ReadyStep.oneMonth) == ReadyState.current
            ? t.goalsNetNote
            : null;
        return Padding(
          key: const ValueKey('goals'),
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 1, color: Mid.rule),
              const SizedBox(height: 16),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 14,
                children: [
                  Text(t.goalsTitle, style: onest(16, weight: 600)),
                  Text(t.goalsSubtitle, style: onest(13, color: Mid.ink3)),
                ],
              ),
              // Several goals together can ask more than a pay holds: their
              // total, each currency on its own (owner, 2026-10-27).
              for (final (i, total) in _totals(r.goals).indexed)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    t.goalsTotal(total),
                    key: ValueKey('goals-total-$i'),
                    style: onest(13.5, weight: 500, tabular: true),
                  ),
                ),
              if (before != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _reads),
                    child: Text(
                      before,
                      key: const ValueKey('goals-before'),
                      style: onest(13, color: Mid.ink2, height: 1.4),
                    ),
                  ),
                ),
              for (final g in r.goals)
                _GoalCard(
                  key: ValueKey('goal-${g.category.id}'),
                  goal: g,
                  actions: actions,
                ),
              const SizedBox(height: 12),
              if (open)
                _GoalPanel(r: r, data: data, today: today, actions: actions)
              else
                BarButton(
                  key: const ValueKey('goal-add'),
                  focusNode: keep.goalOpener,
                  label: t.goalAdd,
                  color: Mid.blue,
                  onTap: keep.beginGoal,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// What two or more goals ask this month, by currency, said as money.
List<String> _totals(List<Goal> goals) {
  final sums = <Currency, int>{}, count = <Currency, int>{};
  for (final g in goals) {
    if (g.asks <= 0 || g.ready || g.finished) continue;
    sums[g.currency] = (sums[g.currency] ?? 0) + g.asks;
    count[g.currency] = (count[g.currency] ?? 0) + 1;
  }
  return [
    for (final MapEntry(key: c, value: v) in sums.entries)
      if (count[c]! > 1) formatShort(v, currency: c),
  ];
}

/// One goal: how far along it is, and, behind or late, what it takes.
class _GoalCard extends StatelessWidget {
  const _GoalCard({super.key, required this.goal, required this.actions});
  final Goal goal;
  final _SavingsActions actions;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final g = goal;
    final id = g.category.id;
    String money(int v) => formatShort(v, currency: g.currency);
    String date(DateTime d) =>
        d.year == g.today.year ? sayDate(t, d) : sayFullDate(t, d);
    String month(DateTime d) =>
        t.calendarMonth(monthName(t, d.month), '${d.year}', d.month);
    final readyAt = g.readyAtUsual;
    final thisMonth =
        g.due.year == g.today.year && g.due.month == g.today.month;
    final status = g.ready
        ? t.goalReady(money(g.amount))
        : g.finished
        ? t.goalDoneStatus
        : [
            t.planFundOf(money(g.saved), money(g.amount)),
            if (!g.late)
              g.behind > 0 ? t.goalBehind(money(g.behind)) : t.goalOnTrack,
          ].join(' · ');
    Widget line(String text, {Key? key}) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _reads),
        child: Text(
          text,
          key: key,
          style: onest(13, color: Mid.ink2, height: 1.4, tabular: true),
        ),
      ),
    );
    Widget move() => BarButton(
      key: ValueKey('goal-move-$id'),
      label: t.goalMoveDate(month(readyAt!)),
      onTap: () => actions.setPlan(
        g.category,
        g.movedTo(readyAt),
        t.goalMovedUndo(g.category.name, month(readyAt)),
      ),
    );
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Mid.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  g.category.name,
                  overflow: TextOverflow.ellipsis,
                  style: onest(14.5, weight: 600),
                ),
              ),
              const SizedBox(width: 12),
              Text(t.goalBy(date(g.due)), style: onest(13, color: Mid.ink3)),
              const Spacer(),
              BarButton(
                key: ValueKey('goal-edit-$id'),
                label: t.planEdit,
                onTap: () => actions.editCategory(id),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              _Progress(
                value: g.amount == 0 ? 1 : g.saved / g.amount,
                done: g.ready,
                muted: false,
                width: 320,
              ),
              Text(
                status,
                key: ValueKey('goal-status-$id'),
                style: onest(13, tabular: true),
              ),
            ],
          ),
          if (g.ready)
            const SizedBox.shrink()
          else if (g.late) ...[
            line(
              !g.finished
                  ? t.goalLate(date(g.due), money(g.toGo))
                  : g.left > 0
                  ? t.goalDoneLeft(money(g.left), g.category.name)
                  : t.goalDoneNote,
              key: ValueKey('goal-late-$id'),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                runSpacing: 8,
                children: [
                  _Choice(
                    key: ValueKey('goal-keep-$id'),
                    label: t.goalKeepUsual(money(g.usual)),
                    on: !g.askAll && !g.finished,
                    onTap: () => actions.setPref(
                      ReadyKeys.goalLate(id),
                      null,
                      t.goalKeepUsualUndo(g.category.name),
                    ),
                  ),
                  _Choice(
                    key: ValueKey('goal-rest-$id'),
                    label: t.goalAskRest,
                    on: g.askAll,
                    onTap: () => actions.setPref(
                      ReadyKeys.goalLate(id),
                      'all',
                      t.goalAskRestUndo(g.category.name),
                    ),
                  ),
                  _Choice(
                    key: ValueKey('goal-done-$id'),
                    label: t.goalDone,
                    on: g.finished,
                    onTap: () => actions.setPref(
                      ReadyKeys.goalLate(id),
                      'done',
                      t.goalDoneUndo(g.category.name),
                    ),
                  ),
                  if (readyAt != null) move(),
                ],
              ),
            ),
          ] else if (g.behind > 0) ...[
            line(
              [
                t.goalCatchUp(date(g.due), money(g.asks)),
                if (readyAt != null)
                  t.goalAtUsual(money(g.usual), month(readyAt)),
              ].join(' '),
              key: ValueKey('goal-behind-$id'),
            ),
            if (readyAt != null && readyAt.isAfter(g.due))
              Padding(padding: const EdgeInsets.only(top: 10), child: move()),
          ] else
            line(
              thisMonth
                  ? t.goalAsksThisMonth(money(g.asks))
                  : t.goalAsks(money(g.asks)),
              key: ValueKey('goal-asks-$id'),
            ),
        ],
      ),
    );
  }
}

/// New goal: what it's for, how much and by when; then what Budget will
/// ask, said before Add. Money already saved for it is assigned on Budget,
/// as for any line, so what's said here is what Budget asks.
class _GoalPanel extends StatefulWidget {
  const _GoalPanel({
    required this.r,
    required this.data,
    required this.today,
    required this.actions,
  });
  final Readiness r;
  final LedgerData data;
  final DateTime today;
  final _SavingsActions actions;

  @override
  State<_GoalPanel> createState() => _GoalPanelState();
}

class _GoalPanelState extends State<_GoalPanel> {
  final _nameFocus = FocusNode(debugLabel: 'goal-name');
  final _amountFocus = FocusNode(debugLabel: 'goal-amount');
  final _dateFocus = FocusNode(debugLabel: 'goal-date');
  bool _adding = false;

  _SavingsKeep get _keep => widget.actions.keep;
  _GoalDraft get _d => _keep.goal!;
  Currency get _currency => savingsCurrency(widget.data);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final f in [_nameFocus, _amountFocus, _dateFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  int? get _amount => switch (parseAmount(_d.amount.text.trim(), _currency)) {
    final a? when a > 0 => a,
    _ => null,
  };

  DateTime? get _date {
    final d = parseEntryDate(_d.date.text.trim(), widget.today);
    return d == null || d.year > widget.today.year + 100 ? null : d;
  }

  void _close() => _keep.closeGoal();

  void _wrong(String what, FocusNode focus) {
    _d.wrong = what;
    _keep.changed();
    focus.requestFocus();
  }

  Future<void> _add() async {
    if (_adding) return;
    final name = _d.name.text.trim();
    if (name.isEmpty) return _wrong('name', _nameFocus);
    final amount = _amount;
    if (amount == null) return _wrong('amount', _amountFocus);
    final due = _date;
    if (due == null) return _wrong('date', _dateFocus);
    _adding = true;
    final made = await widget.actions.addGoal((
      name: name,
      currency: _currency,
      // The account pay goes into, as any category made without one.
      paidFrom: null,
      plan: CategoryPlan(
        categoryId: 0,
        kind: PlanKind.byDate,
        amount: amount,
        start: widget.today,
        due: due,
      ),
      // A goal isn't a month's spending: in it, a wedding would make the
      // safety net look too small. Its Edit can put it back.
      inMonth: false,
      goal: true,
      group: null,
      note: null,
    ));
    _adding = false;
    if (made && mounted) _close();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _d.typing,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final t = context.t;
    final d = _d;
    String money(int v) => formatShort(v, currency: _currency);
    String date(DateTime x) =>
        x.year == widget.today.year ? sayDate(t, x) : sayFullDate(t, x);
    void typed(String what) {
      if (d.wrong == what) {
        d.wrong = null;
        _keep.changed();
      }
    }

    Widget wrong(String what, String text) => d.wrong == what
        ? Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              key: ValueKey('goal-wrong-$what'),
              style: onest(12.5, color: Mid.coral),
            ),
          )
        : const SizedBox.shrink();

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: onest(13, color: Mid.ink2)),
    );

    Widget field(
      String key,
      TextEditingController c,
      FocusNode focus, {
      double width = 180,
    }) => SizedBox(
      width: width,
      height: 32,
      child: TextField(
        key: ValueKey('goal-$key'),
        controller: c,
        focusNode: focus,
        style: onest(13.5, tabular: true),
        onSubmitted: (_) => _add(),
        onChanged: (_) => typed(key),
        decoration: _fieldDecoration(wrong: d.wrong == key).copyWith(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
        ),
      ),
    );

    // What Budget will ask, worked out by Budget itself on the line as it
    // would be made, so the two can't disagree.
    final amount = _amount, due = _date;
    String? asks;
    if (amount != null && due != null) {
      const draftId = -1;
      final draft = widget.data
          .withCategory(
            AccountInfo(
              id: draftId,
              name: '',
              type: AccountType.expense,
              currency: _currency,
            ),
          )
          .withPlan(
            draftId,
            CategoryPlan(
              categoryId: draftId,
              kind: PlanKind.byDate,
              amount: amount,
              start: widget.today,
              due: due,
            ),
          );
      final p = monthBudget(draft, widget.today).lines[draftId]?.plan;
      if (p != null && p.planned > 0) {
        asks = p.lastPeriod || p.done
            ? t.goalWillAskNow(money(p.planned))
            : t.goalWillAsk(money(p.each), date(due));
      }
    }
    final name = d.name.text.trim();

    final examples = [
      t.goalExWedding,
      t.goalExMission,
      t.goalExUniversity,
      t.goalExHome,
      t.goalExCar,
    ];
    return TapRegion(
      onTapOutside: (_) {
        if (!d.changed) _close();
      },
      child: TextFieldTapRegion(
        child: CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
          child: Container(
            key: const ValueKey('goal-panel'),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Mid.blueEdge, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.goalNew, style: onest(15, weight: 600)),
                const SizedBox(height: 14),
                label(t.goalWhatFor),
                Wrap(
                  runSpacing: 8,
                  children: [
                    for (final (i, e) in examples.indexed)
                      _Choice(
                        key: ValueKey('goal-example-$i'),
                        label: e,
                        on: name == e,
                        onTap: () {
                          d.name.text = e;
                          typed('name');
                          _amountFocus.requestFocus();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                field('name', d.name, _nameFocus, width: 360),
                wrong('name', t.planEnterName),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        label(t.goalHowMuch),
                        field('amount', d.amount, _amountFocus),
                        wrong('amount', t.planMonthWrong),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        label(t.goalByWhen),
                        SizedBox(
                          width: 180,
                          child: DateField(
                            key: const ValueKey('goal-date'),
                            controller: d.date,
                            focusNode: _dateFocus,
                            today: widget.today,
                            small: true,
                            calendarBeside: true,
                            wanted: d.wrong == 'date',
                            onSubmitted: _add,
                            onPicked: () {},
                          ),
                        ),
                        wrong('date', t.goalEnterDate),
                      ],
                    ),
                  ],
                ),
                if (asks != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    decoration: BoxDecoration(
                      color: Mid.chip,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asks,
                          key: const ValueKey('goal-will-ask'),
                          style: onest(13.5, tabular: true),
                        ),
                        if (name.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              t.goalGoesOnBudget(name),
                              style: onest(13, color: Mid.ink2),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    BarButton(
                      key: const ValueKey('goal-cancel'),
                      label: t.setupCancel,
                      onTap: _close,
                    ),
                    BarButton(
                      key: const ValueKey('goal-save'),
                      label: t.goalAddButton,
                      color: Mid.blue,
                      onTap: _add,
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
