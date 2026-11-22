part of 'phone_app.dart';

// The Savings tab (#533; owner's pick of sketch B, 2026-11-22, ADR 0004
// "Savings on the phone"): five stops across the top, the four steps and
// Goals, and one stop at a time under them, a swipe or a tap from the next.
// Each step says what the computer's Savings page says of it, from the
// phone's own ledger.

/// The Savings steps of the phone's ledger, worked out once per copy rather
/// than on every entry typed; null with no ledger behind the figures (the
/// preview, the demo).
Readiness? _readinessFor(PhoneSnapshot snapshot) {
  final data = snapshot.data;
  if (data == null) return null;
  final day = dateOnly(snapshot.madeAt);
  final kept = _readinessOf[data];
  return kept != null && kept.$1 == day
      ? kept.$2
      : (_readinessOf[data] = (day, Readiness.of(data, day))).$2;
}

/// The stop Savings opens on: the step the household is on, or Goals once
/// every step is done or skipped.
int _savingsStopOf(Readiness r) => r.current?.index ?? ReadyStep.values.length;

class _SavingsScreen extends StatefulWidget {
  const _SavingsScreen({
    required this.store,
    required this.now,
    required this.show,
  });
  final PhoneStore store;
  final DateTime Function() now;

  /// A stop asked for from elsewhere (Budget's step band): set, the tab
  /// turns to it.
  final ValueNotifier<int?> show;

  @override
  State<_SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<_SavingsScreen> {
  late final PageController _pages;
  late int _at;

  @override
  void initState() {
    super.initState();
    final r = _readinessFor(widget.store.snapshot);
    _at = widget.show.value ?? (r == null ? 0 : _savingsStopOf(r));
    widget.show.value = null;
    _pages = PageController(initialPage: _at);
    widget.show.addListener(_shown);
  }

  @override
  void dispose() {
    widget.show.removeListener(_shown);
    _pages.dispose();
    super.dispose();
  }

  void _shown() {
    final stop = widget.show.value;
    if (stop == null) return;
    widget.show.value = null;
    _go(stop, animate: false);
  }

  void _go(int stop, {bool animate = true}) {
    setState(() => _at = stop);
    if (!_pages.hasClients) return;
    if (animate) {
      unawaited(
        _pages.animateToPage(
          stop,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        ),
      );
    } else {
      _pages.jumpToPage(stop);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final t = context.t;
      final snapshot = widget.store.snapshot;
      final r = _readinessFor(snapshot);
      final data = snapshot.data;
      if (r == null || data == null) return const SizedBox.shrink();
      final currency = savingsCurrency(data);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text(t.planSavings, style: onest(20, weight: 600)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(
              r.current == null ? t.planAllStepsDone : t.planOneStepAtATime,
              key: const ValueKey('savings-subtitle'),
              style: onest(14, color: Mid.ink2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                for (final s in ReadyStep.values)
                  _SavingsStop(
                    key: ValueKey('savings-stop-${s.name}'),
                    label: stepTitle(t, s),
                    chosen: _at == s.index,
                    onTap: () => _go(s.index),
                    picture: Opacity(
                      opacity: r.stateOf(s) == ReadyState.setAside ? 0.45 : 1,
                      child: SavingsPicture(stepPicture(s), size: 44),
                    ),
                    mark: StepMarker(number: s.index + 1, state: r.stateOf(s)),
                  ),
                _SavingsStop(
                  key: const ValueKey('savings-stop-goals'),
                  label: t.goalsTitle,
                  chosen: _at == ReadyStep.values.length,
                  onTap: () => _go(ReadyStep.values.length),
                  picture: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.flag_outlined,
                      size: 28,
                      color: _at == ReadyStep.values.length
                          ? Mid.blue
                          : Mid.ink2,
                    ),
                  ),
                  mark: Text(
                    t.goalsTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: onest(12, color: Mid.ink2),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: Mid.rule),
          Expanded(
            child: CurrencyScope(
              currency: currency,
              child: PageView(
                key: const ValueKey('savings-pages'),
                controller: _pages,
                onPageChanged: (i) => setState(() => _at = i),
                children: [
                  for (final s in ReadyStep.values)
                    _SavingsStepPage(
                      key: ValueKey('savings-page-${s.name}'),
                      step: s,
                      r: r,
                      data: data,
                    ),
                  _SavingsGoalsPage(
                    key: const ValueKey('savings-page-goals'),
                    r: r,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// One of the five stops: a picture, and its mark or name under it.
class _SavingsStop extends StatelessWidget {
  const _SavingsStop({
    super.key,
    required this.label,
    required this.chosen,
    required this.onTap,
    required this.picture,
    required this.mark,
  });
  final String label;
  final bool chosen;
  final VoidCallback onTap;
  final Widget picture;
  final Widget mark;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      label: label,
      selected: chosen,
      button: true,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Material(
            color: chosen ? Mid.blueWash : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: chosen ? Mid.blueEdge : Colors.transparent,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [picture, const SizedBox(height: 6), mark],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// An amount in Savings' one currency.
String _saved(BuildContext context, int v) =>
    formatShort(v, currency: CurrencyScope.of(context));

/// A step as the computer's Savings page shows it: its title, how far along
/// it is, and what it says.
class _SavingsStepPage extends StatelessWidget {
  const _SavingsStepPage({
    super.key,
    required this.step,
    required this.r,
    required this.data,
  });
  final ReadyStep step;
  final Readiness r;
  final LedgerData data;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = r.stateOf(step);
    final current = state == ReadyState.current;
    final aside = state == ReadyState.setAside;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          children: [
            Text(
              stepTitle(t, step),
              style: onest(19, weight: 600, color: aside ? Mid.ink2 : Mid.ink),
            ),
            if (current) Text(t.planNow, style: onest(13, color: Mid.blue)),
            if (aside) Text(t.planSetAside, style: onest(13, color: Mid.ink2)),
          ],
        ),
        const SizedBox(height: 10),
        ..._body(context, t, state),
      ],
    );
  }

  Widget _fact(String text, {Key? key, Color? color}) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      text,
      key: key,
      style: onest(15, color: color ?? Mid.ink, tabular: true),
    ),
  );

  Widget _guide(String text, {Key? key, Color? color}) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Text(
      text,
      key: key,
      style: onest(14, color: color ?? Mid.ink2, height: 1.4, tabular: true),
    ),
  );

  Widget _part(String text) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Text(text, style: onest(16, weight: 600)),
  );

  List<Widget> _body(BuildContext context, Words t, ReadyState state) {
    final current = state == ReadyState.current;
    final c = CurrencyScope.of(context);
    String here(int v) => _saved(context, v);
    switch (step) {
      case ReadyStep.oneMonth:
      case ReadyStep.moreMonths:
        final target = r.targetOf(step);
        final m = r.month;
        final full = r.fund >= target || r.isDone(step);
        return [
          if (target > 0 && r.hasFund) ...[
            _fact(
              full
                  ? t.planFundOf(here(r.fund), here(target))
                  : t.planFundOfToGo(
                      here(r.fund),
                      here(target),
                      here(target - r.fund),
                    ),
              key: ValueKey('savings-${step.name}-progress'),
            ),
            const SizedBox(height: 10),
            StepBar(
              value: r.fund / target,
              done: full,
              muted: !current && state != ReadyState.done,
              width: null,
            ),
          ],
          if (step == ReadyStep.oneMonth || current)
            _guide(
              monthOfExpensesSays(t, m, c),
              key: ValueKey('savings-${step.name}-month'),
            ),
          if (step == ReadyStep.oneMonth && m.outgrown)
            _guide(t.planMonthOutgrown(here(m.inBudget))),
          if (step == ReadyStep.oneMonth) ..._safetyNet(t, here),
          if (current && step == ReadyStep.oneMonth) ...[
            if (r.fund > 0) _guide(t.planKeepReachable),
            if ([
                  for (final d in r.consumerDebts)
                    if (!r.looksPaidInFull.contains(d.account.id))
                      d.account.name,
                ]
                case final names when names.isNotEmpty)
              _guide(t.planMinimumsOn(namesAnd(t, names))),
          ],
          if (current && step == ReadyStep.moreMonths)
            _guide(t.planEnoughForJobLoss),
        ];
      case ReadyStep.consumerDebt:
        return [
          _fact(
            r.consumerDebts.isEmpty
                ? t.planNoCardsOwing
                : r.paidOff.isEmpty
                ? t.planAmountOwed(here(r.consumerOwed))
                : t.planDebtsPaidOff(
                    r.paidOff.length,
                    r.paidOff.length + r.consumerDebts.length,
                    here(r.consumerOwed),
                  ),
            key: const ValueKey('savings-consumerDebt-owed'),
            color: r.consumerDebts.isEmpty ? Mid.ink2 : Mid.ink,
          ),
          if (current && r.consumerDebts.isNotEmpty)
            _guide(t.planPayExtraGuide),
          const SizedBox(height: 6),
          for (final d in r.debtsInOrder)
            _PhoneDebtCard(
              key: ValueKey('savings-debt-${d.account.id}'),
              debt: d,
              r: r,
            ),
          // What's done stays in sight while the rest is paid off.
          if (r.consumerDebts.isNotEmpty)
            for (final a in r.paidOff)
              _PhoneDebtCard(
                key: ValueKey('savings-paid-${a.id}'),
                debt: (account: a, owed: 0),
                r: r,
                paidOff: true,
              ),
          for (final a in data.openAccounts)
            if (a.isOwed &&
                a.role == AccountRole.paidMonthly &&
                a.currency == c)
              _PhoneDebtCard(
                key: ValueKey('savings-debt-${a.id}'),
                debt: (account: a, owed: -data.balanceOf(a.id)),
                r: r,
              ),
        ];
      case ReadyStep.future:
        final said = data.prefs[ReadyKeys.longLoans];
        return [
          _part(t.planStepRetirement),
          _fact(r.retirement ? t.planRetirementYes : t.planRetirementWhat),
          if (current && !r.retirement) _guide(t.planEmployerMatch),
          _part(t.planStepLongLoans),
          if (!r.longMarked) ...[
            _fact(switch (said) {
              'none' => t.planLongNone,
              'yes' => t.planPayingExtra,
              _ => t.planLongAsk,
            }),
            if (r.consumerDebts.isNotEmpty && !r.longAnswer)
              _guide(t.planLongMarkThere),
          ] else ...[
            _fact(
              r.longLoans.isEmpty
                  ? t.planPaidOff
                  : t.planAmountLeft(here(r.longOwed)),
            ),
            const SizedBox(height: 6),
            for (final d in r.longLoans)
              _PhoneDebtCard(
                key: ValueKey('savings-debt-${d.account.id}'),
                debt: d,
                r: r,
              ),
          ],
        ];
    }
  }

  /// Where the safety net's money sits, what it is while empty, and what in
  /// the budget is more than it holds.
  List<Widget> _safetyNet(Words t, String Function(int) here) {
    if (!r.hasFund) return const [];
    final banks = data.openAccounts.where((a) => !a.isOwed && !a.isCash).length;
    // Called what it's called on Budget: it can be renamed.
    final name = r.fundCategories.first.name;
    final kept = namesAnd(t, r.keptIn.map((a) => a.name));
    return [
      if (r.fund == 0) _guide(t.planWhichAccount(name)),
      if (r.keptIn.isNotEmpty && r.fund > 0)
        _guide(
          r.keptThere >= r.fund
              ? t.planFundAllIn(kept)
              : t.planFundWhere(
                  here(r.keptThere),
                  kept,
                  here(r.fund - r.keptThere),
                ),
          key: const ValueKey('savings-fund-where'),
        ),
      if (r.fund > 0 && r.overAssigned > 0)
        _guide(
          t.planFundOverAssigned(here(r.overAssigned)),
          key: const ValueKey('savings-fund-over'),
          color: Mid.coral,
        ),
      if (r.keptIn.isEmpty &&
          banks > 1 &&
          r.fund > 0 &&
          !r.isDone(ReadyStep.oneMonth))
        _guide(t.planFundSetPaidFrom(name)),
    ];
  }
}

/// A card or loan on a step: what's owed, its rate and what that costs a
/// month, its payment, and the bar on the one getting the extra.
class _PhoneDebtCard extends StatelessWidget {
  const _PhoneDebtCard({
    super.key,
    required this.debt,
    required this.r,
    this.paidOff = false,
  });
  final Debt debt;
  final Readiness r;

  /// Paid off since the step's debts last owed nothing: kept in sight.
  final bool paidOff;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final a = debt.account;
    String here(int v) => _saved(context, v);
    final consumer = r.consumerDebts.any((d) => d.account.id == a.id);
    final target = consumer && r.target?.account.id == a.id;
    final rate = r.rates[a.id];
    final pay = consumer ? r.payments[a.id] : null;
    final interest = consumer ? r.interestOf(debt) : null;
    final carried = r.carriedSince[a.id];
    final most = r.mostOwed[a.id] ?? 0;
    final bar =
        most > 0 && (target || r.longLoans.any((d) => d.account.id == a.id));
    final behind = r.debtsInOrder.indexOf(debt) > 0;
    Widget dim(String text, {Key? key, Color? color}) => Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        text,
        key: key,
        style: onest(
          13.5,
          color: color ?? Mid.ink2,
          height: 1.35,
          tabular: true,
        ),
      ),
    );
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Mid.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: target ? Mid.blueEdge : Mid.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  a.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: onest(15.5, weight: 500),
                ),
              ),
              const SizedBox(width: 12),
              if (paidOff)
                Text(t.planPaidOff, style: onest(15, color: Mid.green))
              else
                Text(
                  debt.owed > 0 ? here(debt.owed) : t.planNothingOwed,
                  style: onest(15, tabular: true),
                ),
            ],
          ),
          if (!paidOff) ...[
            if (consumer && rate != null)
              dim(
                [
                  rateWords(t, rate),
                  if (interest != null)
                    t.planInterestAMonth(
                      interestAbout(interest, CurrencyScope.of(context)),
                    ),
                ].join(' · '),
                key: ValueKey('savings-debt-${a.id}-rate'),
              ),
            if (!consumer)
              dim(switch (a.role) {
                AccountRole.mortgage => t.planRoleMortgage,
                AccountRole.paidMonthly => t.planRolePaidMonthly,
                _ => t.planRoleConsumer,
              }),
            if (pay != null)
              dim(
                pay.from == null
                    ? t.planPays(here(pay.amount))
                    : t.planPaysFrom(here(pay.amount), pay.from!.name),
                key: ValueKey('savings-debt-${a.id}-pay'),
              ),
            if (target)
              dim(
                t.planPayExtraHere,
                key: ValueKey('savings-debt-${a.id}-is-target'),
                color: Mid.blue,
              ),
            if (pay != null && interest != null && pay.amount <= interest)
              dim(
                onlyInterestSays(
                  t,
                  below: pay.amount < interest,
                  behind: behind,
                  amount: here(pay.amount),
                ),
                color: Mid.ink,
              ),
            if (bar) ...[
              const SizedBox(height: 8),
              StepBar(
                value: r.paidOffOf(debt) / most,
                done: false,
                muted: false,
                width: null,
              ),
              dim(
                t.planPaidOffOf(here(r.paidOffOf(debt)), here(most)),
                key: ValueKey('savings-debt-${a.id}-progress'),
              ),
            ],
            if (carried != null)
              dim(t.planCarried(sayFullDate(t, carried)), color: Mid.ink),
            if (consumer && r.looksPaidInFull.contains(a.id))
              dim(t.planLooksPaidInFull),
          ],
        ],
      ),
    );
  }
}

/// Goals, the fifth stop: the computer's goal cards and the lines over them.
class _SavingsGoalsPage extends StatelessWidget {
  const _SavingsGoalsPage({super.key, required this.r});
  final Readiness r;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final before = r.goals.isEmpty
        ? null
        : goalsBefore(t, r, CurrencyScope.of(context));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(t.goalsTitle, style: onest(19, weight: 600)),
        const SizedBox(height: 4),
        Text(t.goalsSubtitle, style: onest(14, color: Mid.ink2, height: 1.4)),
        for (final (i, total) in goalTotals(r.goals).indexed)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              t.goalsTotal(total),
              key: ValueKey('savings-goals-total-$i'),
              style: onest(15, weight: 500, tabular: true),
            ),
          ),
        if (before != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              before,
              key: const ValueKey('savings-goals-before'),
              style: onest(14, color: Mid.ink2, height: 1.4),
            ),
          ),
        for (final g in r.goals)
          _PhoneGoalCard(
            key: ValueKey('savings-goal-${g.category.id}'),
            goal: g,
          ),
      ],
    );
  }
}

class _PhoneGoalCard extends StatelessWidget {
  const _PhoneGoalCard({super.key, required this.goal});
  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final g = goal;
    final line = goalLine(t, g);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Mid.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Mid.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            g.category.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: onest(15.5, weight: 600),
          ),
          const SizedBox(height: 2),
          Text(
            t.goalBy(goalDate(t, g, g.due)),
            style: onest(13.5, color: Mid.ink2),
          ),
          const SizedBox(height: 10),
          StepBar(
            value: g.amount == 0 ? 1 : g.saved / g.amount,
            done: g.ready,
            muted: false,
            width: null,
          ),
          const SizedBox(height: 8),
          Text(
            goalStatus(t, g),
            key: ValueKey('savings-goal-status-${g.category.id}'),
            style: onest(14.5, tabular: true),
          ),
          if (line != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                line,
                key: ValueKey('savings-goal-line-${g.category.id}'),
                style: onest(14, color: Mid.ink2, height: 1.4, tabular: true),
              ),
            ),
        ],
      ),
    );
  }
}
