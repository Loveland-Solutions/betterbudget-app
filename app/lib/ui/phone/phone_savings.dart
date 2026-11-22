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

  /// Writes a Savings change and says it in a snack bar with Undo, as the
  /// phone's other changes are; a refusal says so instead.
  Future<void> _act(PhoneRowAct act, String said) async {
    final PhoneActed done;
    try {
      done = await widget.store.actRow(act);
    } catch (e) {
      debugPrint('A Savings change on the phone failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            persist: false,
            duration: phoneSnackTime,
            key: const ValueKey('savings-refused'),
            backgroundColor: Mid.raised,
            content: Text(
              context.t.ledgerCouldntSave,
              style: onest(15, color: Mid.ink),
            ),
          ),
        );
      return;
    }
    if (mounted) {
      _saidWithUndo(context, widget.store, done, said, 'savings-done');
    }
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
                      act: _act,
                    ),
                  _SavingsGoalsPage(
                    key: const ValueKey('savings-page-goals'),
                    r: r,
                    store: widget.store,
                    act: _act,
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
    required this.act,
  });
  final ReadyStep step;
  final Readiness r;
  final LedgerData data;

  /// Writes a change and says [said] with Undo.
  final Future<void> Function(PhoneRowAct act, String said) act;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = r.stateOf(step);
    final current = state == ReadyState.current;
    final aside = state == ReadyState.setAside;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                children: [
                  Text(
                    stepTitle(t, step),
                    style: onest(
                      19,
                      weight: 600,
                      color: aside ? Mid.ink2 : Mid.ink,
                    ),
                  ),
                  if (current)
                    Text(t.planNow, style: onest(13, color: Mid.blue)),
                  if (aside)
                    Text(t.planSetAside, style: onest(13, color: Mid.ink2)),
                ],
              ),
            ),
            // A step done has nothing to skip.
            if (!r.isDone(step))
              SizedBox(
                width: 44,
                height: 44,
                child: PopupMenuButton<bool>(
                  key: ValueKey('savings-${step.name}-menu'),
                  color: Mid.raised,
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.more_horiz_rounded, color: Mid.ink2),
                  onSelected: (skip) => act(
                    PhoneSavingsAnswer(const {}, aside: (step, skip)),
                    skip
                        ? t.planSetAsideUndo(stepTitle(t, step))
                        : t.planBackInStepsUndo(stepTitle(t, step)),
                  ),
                  itemBuilder: (_) => [
                    PopupMenuItem<bool>(
                      key: ValueKey('savings-${step.name}-aside'),
                      value: !aside,
                      child: Text(
                        aside ? t.planBringBack : t.planSetStepAside,
                        style: onest(16),
                      ),
                    ),
                  ],
                ),
              ),
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
          if (step == ReadyStep.oneMonth) ..._safetyNet(context, t, here),
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
          if (current && step == ReadyStep.moreMonths) ...[
            _guide(t.planEnoughForJobLoss),
            ..._assignOffer(context, t),
          ],
          // The fund and the month are set on step 1 only, so they never
          // show twice; step 3 says which of three to six months.
          if (step == ReadyStep.oneMonth)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: _PhoneMonthField(
                key: const ValueKey('savings-month'),
                r: r,
                act: act,
              ),
            ),
          if (step == ReadyStep.moreMonths)
            _choices([
              for (final n in [3, 4, 5, 6])
                _SavingsChoice(
                  key: ValueKey('savings-months-$n'),
                  label: t.planMonthsChoice(n),
                  on: r.monthsTarget == n,
                  onTap: () => act(
                    PhoneSavingsAnswer({
                      ReadyKeys.months: n == 3 ? null : '$n',
                    }),
                    t.planAimingFor(n),
                  ),
                ),
            ]),
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
              act: act,
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
                act: act,
              ),
          if (r.consumerDebts.isNotEmpty)
            _PhonePayoff(key: const ValueKey('savings-payoff'), r: r, act: act),
        ];
      case ReadyStep.future:
        final said = data.prefs[ReadyKeys.longLoans];
        return [
          _part(t.planStepRetirement),
          _fact(r.retirement ? t.planRetirementYes : t.planRetirementWhat),
          if (current && !r.retirement) _guide(t.planEmployerMatch),
          _choices([
            for (final yes in [true, false])
              _SavingsChoice(
                key: ValueKey('savings-retirement-${yes ? 'yes' : 'no'}'),
                label: yes ? t.planIAm : t.planNotYet,
                on: r.retirement == yes,
                onTap: () => act(
                  PhoneSavingsAnswer({
                    ReadyKeys.retirement: yes ? 'yes' : null,
                  }),
                  yes
                      ? t.planAnswerYesUndo(t.planStepRetirement)
                      : t.planAnswerNotYetUndo(t.planStepRetirement),
                ),
              ),
          ]),
          _part(t.planStepLongLoans),
          if (!r.longMarked) ...[
            _fact(switch (said) {
              'none' => t.planLongNone,
              'yes' => t.planPayingExtra,
              _ => t.planLongAsk,
            }),
            if (r.consumerDebts.isNotEmpty && !r.longAnswer)
              _guide(t.planLongMarkThere),
            _choices([
              for (final (value, label, undo) in [
                ('none', t.planIHaveNone, t.planNoLongLoansUndo),
                ('yes', t.planPayingExtraOnThem, t.planPayingExtraUndo),
                (null, t.planNotPayingExtraYet, t.planLoansNotYetUndo),
              ])
                _SavingsChoice(
                  key: ValueKey('savings-longLoans-${value ?? 'no'}'),
                  label: label,
                  on: said == value,
                  onTap: () => act(
                    PhoneSavingsAnswer({ReadyKeys.longLoans: value}),
                    undo,
                  ),
                ),
            ]),
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
                act: act,
              ),
            if (r.longLoans.isNotEmpty)
              _choices([
                for (final yes in [true, false])
                  _SavingsChoice(
                    key: ValueKey('savings-longLoans-${yes ? 'yes' : 'no'}'),
                    label: yes ? t.planPayingExtra : t.planNotYet,
                    on: (said == 'yes') == yes,
                    onTap: () => act(
                      PhoneSavingsAnswer({
                        ReadyKeys.longLoans: yes ? 'yes' : null,
                      }),
                      yes ? t.planPayingExtraUndo : t.planNotPayingExtraUndo,
                    ),
                  ),
              ]),
          ],
        ];
    }
  }

  /// Where the safety net's money sits, what it is while empty, and what in
  /// the budget is more than it holds.
  List<Widget> _safetyNet(
    BuildContext context,
    Words t,
    String Function(int) here,
  ) {
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
      ..._assignOffer(context, t),
    ];
  }

  /// What's not assigned in the budget, and a button that assigns as much
  /// of it as fills [step], leaving this month's bills theirs.
  List<Widget> _assignOffer(BuildContext context, Words t) {
    final offer = r.offerFor(step);
    final category = r.fundCategories.length == 1
        ? r.fundCategories.single
        : null;
    if (category == null || offer <= 0) return const [];
    final c = CurrencyScope.of(context);
    final said = _saved(context, offer);
    return [
      // Whole units, as the page's other figures: the cents say nothing.
      _guide(
        t.planFundNotAssigned(
          _saved(context, r.notAssigned - r.notAssigned % c.scale),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            key: ValueKey('savings-assign-${step.name}'),
            style: FilledButton.styleFrom(
              backgroundColor: Mid.blue,
              foregroundColor: Mid.ground,
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            // Undone as what was added, not the month's new total.
            onPressed: () => act(
              PhoneAssign(category.id, r.fundAssigned + offer),
              t.planAssignUndo(said, category.name),
            ),
            child: Text(
              t.planFundAssign(said, category.name),
              style: onest(15, weight: 600, color: Mid.ground),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _choices(List<Widget> children) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Wrap(spacing: 8, runSpacing: 8, children: children),
  );
}

/// A card or loan on a step: what's owed, its rate and what that costs a
/// month, its payment, and the bar on the one getting the extra. A debt to
/// pay off opens its rate and its payment from their lines; its ⋯ pays
/// extra on it and says what it counts as.
class _PhoneDebtCard extends StatelessWidget {
  const _PhoneDebtCard({
    super.key,
    required this.debt,
    required this.r,
    this.act,
    this.paidOff = false,
  });
  final Debt debt;
  final Readiness r;

  /// Writes a change; null where nothing on the card changes anything.
  final Future<void> Function(PhoneRowAct act, String said)? act;

  /// Paid off since the step's debts last owed nothing: kept in sight.
  final bool paidOff;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final a = debt.account;
    final c = CurrencyScope.of(context);
    String here(int v) => _saved(context, v);
    final act = this.act;
    final consumer = r.consumerDebts.any((d) => d.account.id == a.id);
    final target = consumer && r.target?.account.id == a.id;
    final rate = r.rates[a.id];
    final pay = consumer ? r.payments[a.id] : null;
    final interest = consumer ? r.interestOf(debt) : null;
    final lately = r.paidLately[a.id];
    final typedHere = pay != null && pay.from == null;
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
    final rateSaid = rate == null
        ? null
        : [
            rateWords(t, rate),
            if (interest != null)
              t.planInterestAMonth(interestAbout(interest, c)),
          ].join(' · ');
    final paySaid = pay == null
        ? null
        : pay.from == null
        ? t.planPays(here(pay.amount))
        : t.planPaysFrom(here(pay.amount), pay.from!.name);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 12),
      decoration: BoxDecoration(
        color: Mid.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: target ? Mid.blueEdge : Mid.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              if (act != null && !paidOff)
                _DebtMenu(
                  account: a,
                  consumer: consumer,
                  target: target,
                  act: act,
                )
              else
                const SizedBox(width: 10, height: 44),
            ],
          ),
          if (!paidOff)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (consumer && act != null)
                    _PhoneRateField(
                      key: ValueKey('savings-debt-${a.id}-rate-open'),
                      debt: debt,
                      r: r,
                      act: act,
                      opener: (open) => _CardLink(
                        key: ValueKey('savings-debt-${a.id}-rate'),
                        label: rateSaid ?? t.planRateAdd,
                        empty: rate == null,
                        onTap: open,
                      ),
                    )
                  else if (consumer && rateSaid != null)
                    dim(rateSaid, key: ValueKey('savings-debt-${a.id}-rate')),
                  if (!consumer)
                    dim(switch (a.role) {
                      AccountRole.mortgage => t.planRoleMortgage,
                      AccountRole.paidMonthly => t.planRolePaidMonthly,
                      _ => t.planRoleConsumer,
                    }),
                  if (consumer && act != null)
                    _PhoneAmountField(
                      name: 'savings-debt-${a.id}-pay',
                      currency: a.currency,
                      start: typedHere
                          ? _typedAmount(pay.amount, a.currency)
                          : '',
                      hint: pay == null
                          ? ''
                          : formatWhole(pay.amount, a.currency),
                      wrongText: t.planPayWrong,
                      notes: [
                        if (lately != null) t.planPayLately(here(lately)),
                        if (typedHere) t.planPayEmptyToRemove,
                      ],
                      extra: lately == null
                          ? null
                          : (use) => [
                              _OutlineButton(
                                key: ValueKey(
                                  'savings-debt-${a.id}-pay-lately',
                                ),
                                label: t.planPayUse(here(lately)),
                                onTap: () => use(lately),
                              ),
                            ],
                      opener: (open) => _CardLink(
                        key: ValueKey('savings-debt-${a.id}-pay'),
                        label: paySaid ?? t.planPayAdd,
                        empty: pay == null,
                        onTap: open,
                      ),
                      onSave: (v) {
                        if (v == null) {
                          if (typedHere) {
                            unawaited(
                              act(
                                PhoneSavingsAnswer({ReadyKeys.pay(a.id): null}),
                                t.planPayRemoved(a.name),
                              ),
                            );
                          }
                        } else if (!(typedHere && pay.amount == v)) {
                          unawaited(
                            act(
                              PhoneSavingsAnswer({ReadyKeys.pay(a.id): '$v'}),
                              t.planPaySet(a.name, here(v)),
                            ),
                          );
                        }
                      },
                    )
                  else if (paySaid != null)
                    dim(paySaid, key: ValueKey('savings-debt-${a.id}-pay')),
                  // A mark, not a link: a tag beside the blue links above.
                  if (target)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Mid.blueWash,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          t.planPayExtraHere,
                          key: ValueKey('savings-debt-${a.id}-is-target'),
                          style: onest(13, weight: 600, color: Mid.blue),
                        ),
                      ),
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
              ),
            ),
        ],
      ),
    );
  }
}

/// A debt's ⋯: pay extra on it first, and what it counts as, the one it
/// is ticked.
class _DebtMenu extends StatelessWidget {
  const _DebtMenu({
    required this.account,
    required this.consumer,
    required this.target,
    required this.act,
  });
  final AccountInfo account;
  final bool consumer;
  final bool target;
  final Future<void> Function(PhoneRowAct act, String said) act;

  /// A student loan marked under the six steps is debt to pay off already.
  static AccountRole? _counted(AccountRole? r) =>
      r == AccountRole.studentLoan ? null : r;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final a = account;
    return SizedBox(
      width: 44,
      height: 44,
      child: PopupMenuButton<Object>(
        key: ValueKey('savings-debt-${a.id}-menu'),
        color: Mid.raised,
        padding: EdgeInsets.zero,
        icon: Icon(Icons.more_horiz_rounded, color: Mid.ink2),
        onSelected: (picked) {
          if (picked == true) {
            unawaited(
              act(
                PhoneSavingsAnswer({ReadyKeys.target: '${a.id}'}),
                t.planPayingExtraOn(a.name),
              ),
            );
            return;
          }
          final role = picked is AccountRole ? picked : null;
          if (_counted(a.role) == role) return;
          unawaited(
            act(
              PhoneSavingsAnswer(const {}, role: (a.id, role)),
              switch (role) {
                AccountRole.mortgage => t.planCountsAsMortgage(a.name),
                AccountRole.paidMonthly => t.planCountsAsPaidMonthly(a.name),
                _ => t.planCountsAsConsumer(a.name),
              },
            ),
          );
        },
        itemBuilder: (_) => [
          if (consumer && !target)
            PopupMenuItem<Object>(
              key: ValueKey('savings-debt-${a.id}-target'),
              value: true,
              child: Text(t.planPayExtraOnThis, style: onest(16)),
            ),
          for (final (role, label) in [
            (null, t.planRoleConsumer),
            (AccountRole.paidMonthly, t.planRolePaidMonthly),
            (AccountRole.mortgage, t.planRoleMortgage),
          ])
            PopupMenuItem<Object>(
              key: ValueKey('savings-debt-${a.id}-${role?.name ?? 'consumer'}'),
              // A menu item's value can't be null: "debt to pay off" is
              // said by false.
              value: role ?? false,
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: _counted(a.role) == role
                        ? Icon(Icons.check_rounded, size: 18, color: Mid.blue)
                        : null,
                  ),
                  Flexible(child: Text(label, style: onest(16))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Goals, the fifth stop: the computer's goal cards and the lines over
/// them, and Add a goal, which opens New category on its Goal card.
class _SavingsGoalsPage extends StatelessWidget {
  const _SavingsGoalsPage({
    super.key,
    required this.r,
    required this.store,
    required this.act,
  });
  final Readiness r;
  final PhoneStore store;
  final Future<void> Function(PhoneRowAct act, String said) act;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = CurrencyScope.of(context);
    final before = r.goals.isEmpty ? null : goalsBefore(t, r, c);
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
            store: store,
            act: act,
          ),
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('savings-goal-add'),
          style: FilledButton.styleFrom(
            backgroundColor: Mid.blue,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          // In Savings' currency, on the Goal card: the computer's panel
          // asks the same name, amount and date.
          onPressed: () => _openNewCategory(
            context,
            store: store,
            currency: c,
            type: CategoryType.goal,
          ),
          child: Text(
            t.goalAdd,
            style: onest(15, weight: 600, color: Mid.ground),
          ),
        ),
      ],
    );
  }
}

class _PhoneGoalCard extends StatelessWidget {
  const _PhoneGoalCard({
    super.key,
    required this.goal,
    required this.store,
    required this.act,
  });
  final Goal goal;
  final PhoneStore store;
  final Future<void> Function(PhoneRowAct act, String said) act;

  /// Its Edit on Budget's page, said with Undo as Budget's Edit is.
  Future<void> _edit(BuildContext context) async {
    final t = context.t;
    final id = '${goal.category.id}';
    final category = store.categories.where((c) => c.id == id).firstOrNull;
    if (category == null) return;
    final done = await _openEditCategory(
      context,
      store: store,
      category: category,
    );
    if (done == null || !context.mounted) return;
    _saidWithUndo(
      context,
      store,
      done.change,
      done.said ?? t.planEditedUndo(category.name),
      'savings-goal-edited',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final g = goal;
    final id = g.category.id;
    final name = g.category.name;
    final line = goalLine(t, g);
    final readyAt = g.readyAtUsual;
    String money(int v) => formatShort(v, currency: g.currency);
    Widget move() => _OutlineButton(
      key: ValueKey('savings-goal-move-$id'),
      label: t.goalMoveDate(goalMonth(t, readyAt!)),
      onTap: () => act(
        // Moving the date also clears a late answer, as on the computer.
        PhoneSavingsAnswer(
          {ReadyKeys.goalLate(id): null},
          plan: (id, g.movedTo(readyAt)),
        ),
        t.goalMovedUndo(name, goalMonth(t, readyAt)),
      ),
    );
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 14),
      decoration: BoxDecoration(
        color: Mid.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Mid.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: onest(15.5, weight: 600),
                ),
              ),
              TextButton(
                key: ValueKey('savings-goal-edit-$id'),
                onPressed: () => _edit(context),
                style: TextButton.styleFrom(minimumSize: const Size(56, 44)),
                child: Text(t.planEdit, style: onest(15, color: Mid.blue)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                  key: ValueKey('savings-goal-status-$id'),
                  style: onest(14.5, tabular: true),
                ),
                if (line != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      line,
                      key: ValueKey('savings-goal-line-$id'),
                      style: onest(
                        14,
                        color: Mid.ink2,
                        height: 1.4,
                        tabular: true,
                      ),
                    ),
                  ),
                // A date passed short is the person's choice (owner,
                // 2026-10-27): keep the usual, ask the rest, or done.
                if (!g.ready && g.late)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SavingsChoice(
                          key: ValueKey('savings-goal-keep-$id'),
                          label: t.goalKeepUsual(money(g.usual)),
                          on: !g.askAll && !g.finished,
                          onTap: () => act(
                            PhoneSavingsAnswer({ReadyKeys.goalLate(id): null}),
                            t.goalKeepUsualUndo(name),
                          ),
                        ),
                        _SavingsChoice(
                          key: ValueKey('savings-goal-rest-$id'),
                          label: t.goalAskRest,
                          on: g.askAll,
                          onTap: () => act(
                            PhoneSavingsAnswer({ReadyKeys.goalLate(id): 'all'}),
                            t.goalAskRestUndo(name),
                          ),
                        ),
                        _SavingsChoice(
                          key: ValueKey('savings-goal-done-$id'),
                          label: t.goalDone,
                          on: g.finished,
                          onTap: () => act(
                            PhoneSavingsAnswer({
                              ReadyKeys.goalLate(id): 'done',
                            }),
                            t.goalDoneUndo(name),
                          ),
                        ),
                        if (readyAt != null) move(),
                      ],
                    ),
                  )
                else if (!g.ready &&
                    g.behind > 0 &&
                    readyAt != null &&
                    readyAt.isAfter(g.due))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: move(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One answer of a few: the chosen one filled, as the computer's are.
/// Tapping the one already chosen does nothing.
class _SavingsChoice extends StatelessWidget {
  const _SavingsChoice({
    super.key,
    required this.label,
    required this.on,
    required this.onTap,
  });
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: on,
    child: OutlinedButton(
      onPressed: on ? () {} : onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        backgroundColor: on ? Mid.blueWash : Colors.transparent,
        side: BorderSide(color: on ? Mid.blue : Mid.rule, width: on ? 1.5 : 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: onest(
          15,
          weight: on ? 600 : 400,
          color: on ? Mid.blue : Mid.ink2,
        ),
      ),
    ),
  );
}

/// A month of expenses: a button that opens a field for one typed over the
/// budget's; empty goes back to the budget's.
class _PhoneMonthField extends StatelessWidget {
  const _PhoneMonthField({super.key, required this.r, required this.act});
  final Readiness r;
  final Future<void> Function(PhoneRowAct act, String said) act;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final m = r.month;
    final c = CurrencyScope.of(context);
    return _PhoneAmountField(
      name: 'savings-month',
      currency: c,
      start: m.typed ? _typedAmount(m.amount, c) : '',
      hint: m.amount == 0 ? t.planMonthHint : formatWhole(m.amount, c),
      wrongText: t.planMonthWrong,
      notes: [if (m.typed) t.planEmptyToAverage],
      opener: (open) => _OutlineButton(
        key: const ValueKey('savings-month-edit'),
        label: m.amount == 0
            ? t.planTypeMonth
            : m.typed
            ? t.planChangeMonth
            : t.planTypeOwnMonth,
        onTap: open,
      ),
      onSave: (v) {
        if (v == null) {
          if (m.typed) {
            unawaited(
              act(
                const PhoneSavingsAnswer({ReadyKeys.month: null}),
                t.planMonthBackToAverage,
              ),
            );
          }
          return;
        }
        unawaited(
          act(
            // With its currency, so it can't turn into dollars when Savings
            // does.
            PhoneSavingsAnswer({ReadyKeys.month: '${c.code}:$v'}),
            t.planMonthSet(formatShort(v, currency: c)),
          ),
        );
      },
    );
  }
}

/// An amount as it's typed back into a field: whole units, and the cents
/// when it has any, so Save on it saves what was there.
String _typedAmount(int minor, Currency c) =>
    '${formatWhole(minor, c)}${c.hasCents(minor) ? formatCents(minor, c) : ''}';

/// A blue outlined button, 44 tall.
class _OutlineButton extends StatelessWidget {
  const _OutlineButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        side: BorderSide(color: Mid.blue, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: onest(15, weight: 600, color: Mid.blue)),
    ),
  );
}

/// A link on a card that opens a field: blue while there's nothing yet,
/// the figure itself once there is.
class _CardLink extends StatelessWidget {
  const _CardLink({
    super.key,
    required this.label,
    required this.empty,
    required this.onTap,
  });
  final String label;
  final bool empty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: onest(
            13.5,
            color: empty ? Mid.blue : Mid.ink2,
            height: 1.35,
            tabular: true,
          ).copyWith(decoration: empty ? null : TextDecoration.underline),
        ),
      ),
    ),
  );
}

/// Cancel and Save, side by side, under a field.
class _CancelSave extends StatelessWidget {
  const _CancelSave({
    required this.name,
    required this.onCancel,
    required this.onSave,
  });
  final String name;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: ValueKey('$name-cancel'),
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              side: BorderSide(color: Mid.rule),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(t.setupCancel, style: onest(15, color: Mid.ink2)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            key: ValueKey('$name-save'),
            onPressed: onSave,
            style: FilledButton.styleFrom(
              backgroundColor: Mid.blue,
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              t.planSave,
              style: onest(15, weight: 600, color: Mid.ground),
            ),
          ),
        ),
      ],
    );
  }
}

InputDecoration _fieldLook({
  String? hint,
  required bool wrong,
  String? suffix,
}) {
  final edge = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: wrong ? Mid.coral : Mid.rule),
  );
  return InputDecoration(
    hintText: hint,
    suffixText: suffix,
    filled: true,
    fillColor: Mid.card,
    border: edge,
    enabledBorder: edge,
  );
}

/// What [opener] shows until tapped, then an amount's field with lines
/// under it ([notes], [extra]) and Cancel and Save. [onSave] gets null for
/// an empty field; something that isn't an amount above zero is said under
/// it and nothing is saved.
class _PhoneAmountField extends StatefulWidget {
  const _PhoneAmountField({
    required this.name,
    required this.currency,
    required this.start,
    required this.hint,
    required this.wrongText,
    required this.opener,
    required this.onSave,
    this.notes = const [],
    this.extra,
  });

  /// Names the field's keys: `name-field`, `name-save`, `name-cancel`,
  /// `name-wrong`.
  final String name;
  final Currency currency;
  final String start;
  final String hint;
  final String wrongText;
  final Widget Function(VoidCallback open) opener;
  final ValueChanged<int?> onSave;
  final List<String> notes;

  /// Buttons under the field that save an amount of their own (Use ₮150,000).
  final List<Widget> Function(ValueChanged<int> use)? extra;

  @override
  State<_PhoneAmountField> createState() => _PhoneAmountFieldState();
}

class _PhoneAmountFieldState extends State<_PhoneAmountField> {
  TextEditingController? _typed;
  var _wrong = false;

  @override
  void dispose() {
    _typed?.dispose();
    super.dispose();
  }

  void _open() => setState(() {
    _wrong = false;
    _typed = TextEditingController(text: widget.start);
  });

  void _close() {
    final gone = _typed;
    setState(() => _typed = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => gone?.dispose());
  }

  void _use(int v) {
    widget.onSave(v);
    _close();
  }

  void _save() {
    final text = _typed!.text.trim();
    if (text.isEmpty) {
      widget.onSave(null);
      return _close();
    }
    final v = parseAmount(text, widget.currency);
    if (v == null || v <= 0) return setState(() => _wrong = true);
    _use(v);
  }

  @override
  Widget build(BuildContext context) {
    final typed = _typed;
    if (typed == null) return widget.opener(_open);
    final name = widget.name;
    final extra = widget.extra?.call(_use) ?? const [];
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: ValueKey('$name-field'),
            controller: typed,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [GroupedAmount(widget.currency)],
            style: onest(17, tabular: true),
            onSubmitted: (_) => _save(),
            onChanged: (_) {
              if (_wrong) setState(() => _wrong = false);
            },
            decoration: _fieldLook(hint: widget.hint, wrong: _wrong),
          ),
          if (_wrong)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                widget.wrongText,
                key: ValueKey('$name-wrong'),
                style: onest(14, color: Mid.coral),
              ),
            ),
          for (final note in widget.notes)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(note, style: onest(13.5, color: Mid.ink2)),
            ),
          if (extra.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 8, runSpacing: 8, children: extra),
            ),
          const SizedBox(height: 10),
          _CancelSave(name: name, onCancel: _close, onSave: _save),
        ],
      ),
    );
  }
}

/// A debt's interest rate: what [opener] shows until tapped, then the
/// field, a month's or a year's, the tip's words, and Cancel and Save. A
/// rate that looks typed under the wrong period is said with its numbers,
/// and saved as typed all the same.
class _PhoneRateField extends StatefulWidget {
  const _PhoneRateField({
    super.key,
    required this.debt,
    required this.r,
    required this.act,
    required this.opener,
  });
  final Debt debt;
  final Readiness r;
  final Future<void> Function(PhoneRowAct act, String said) act;
  final Widget Function(VoidCallback open) opener;

  @override
  State<_PhoneRateField> createState() => _PhoneRateFieldState();
}

class _PhoneRateFieldState extends State<_PhoneRateField> {
  TextEditingController? _typed;
  var _perYear = false;
  var _wrong = false;

  AccountInfo get _a => widget.debt.account;
  DebtRate? get _had => widget.r.rates[_a.id];

  @override
  void dispose() {
    _typed?.dispose();
    super.dispose();
  }

  void _open() => setState(() {
    final had = _had;
    _wrong = false;
    _perYear = had?.perYear ?? ratePerYearFor(_a.currency);
    _typed = TextEditingController(
      text: had == null ? '' : ratePercent(had.percent),
    );
  });

  void _close() {
    final gone = _typed;
    setState(() => _typed = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => gone?.dispose());
  }

  void _save() {
    final t = context.t;
    final had = _had;
    final text = _typed!.text.trim();
    if (text.isEmpty) {
      if (had != null) {
        unawaited(
          widget.act(
            PhoneSavingsAnswer({ReadyKeys.rate(_a.id): null}),
            t.planRateRemoved(_a.name),
          ),
        );
      }
      return _close();
    }
    final percent = parseRatePercent(text);
    if (percent == null) return setState(() => _wrong = true);
    final DebtRate rate = (percent: percent, perYear: _perYear);
    if (had?.value != rate.value) {
      unawaited(
        widget.act(
          PhoneSavingsAnswer({ReadyKeys.rate(_a.id): rate.value}),
          t.planRateSet(_a.name, rateWords(t, rate)),
        ),
      );
    }
    _close();
  }

  String? _warning(Words t) {
    final percent = parseRatePercent(_typed!.text);
    if (percent == null) return null;
    final DebtRate r = (percent: percent, perYear: _perYear);
    final typed = ratePercent(percent);
    if (rateLooksYearly(r)) {
      return t.planRateLooksYearly(typed, ratePercent(percent * 12));
    }
    if (rateLooksMonthly(r, _a.currency)) {
      return t.planRateLooksMonthly(typed, ratePercent(percent / 12));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final typed = _typed;
    if (typed == null) return widget.opener(_open);
    final id = _a.id;
    final warning = _warning(t);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  key: ValueKey('savings-debt-$id-rate-field'),
                  controller: typed,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.right,
                  style: onest(17, tabular: true),
                  onSubmitted: (_) => _save(),
                  onChanged: (_) => setState(() => _wrong = false),
                  decoration: _fieldLook(wrong: _wrong, suffix: '%'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final year in [false, true])
                      _SavingsChoice(
                        key: ValueKey(
                          'savings-debt-$id-rate-${year ? 'year' : 'month'}',
                        ),
                        label: year ? t.planRatePerYear : t.planRatePerMonth,
                        on: _perYear == year,
                        onTap: () => setState(() => _perYear = year),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (_wrong)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                t.planRateWrong,
                key: ValueKey('savings-debt-$id-rate-wrong'),
                style: onest(14, color: Mid.coral),
              ),
            ),
          if (warning != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                warning,
                key: ValueKey('savings-debt-$id-rate-warning'),
                style: onest(13.5, color: Mid.ink, height: 1.4),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              t.planRateTip,
              style: onest(13.5, color: Mid.ink2, height: 1.4),
            ),
          ),
          if (_had != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                t.planRateEmptyToRemove,
                style: onest(13.5, color: Mid.ink2),
              ),
            ),
          const SizedBox(height: 10),
          _CancelSave(
            name: 'savings-debt-$id-rate',
            onCancel: _close,
            onSave: _save,
          ),
        ],
      ),
    );
  }
}

/// Under step 2's debts: Extra each month, then the way being followed and
/// Compare the two ways; or what is still needed to say when it's all paid
/// off. The computer's lines under its two cards follow.
class _PhonePayoff extends StatelessWidget {
  const _PhonePayoff({super.key, required this.r, required this.act});
  final Readiness r;
  final Future<void> Function(PhoneRowAct act, String said) act;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = CurrencyScope.of(context);
    String here(int v) => _saved(context, v);
    Widget note(String text, {Key? key, Color? color}) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        text,
        key: key,
        style: onest(14, color: color ?? Mid.ink2, height: 1.4, tabular: true),
      ),
    );
    final extra = r.extra;
    final missing = r.missingPayments;
    final small = r.payoff(PayoffMethod.smallest);
    final rate = r.payoff(PayoffMethod.highestRate);
    final rated = r.consumerDebts.length - r.missingRates.length;
    final both = small != null && rate != null && r.methodsDiffer;
    final dated = small != null && small.months != null;
    final netFirst =
        dated &&
        extra > 0 &&
        !r.isDone(ReadyStep.oneMonth) &&
        !r.setAside.contains(ReadyStep.oneMonth);
    final followed = r.method;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _PhoneAmountField(
          name: 'savings-extra',
          currency: c,
          start: extra > 0 ? _typedAmount(extra, c) : '',
          hint: '',
          wrongText: t.planPayWrong,
          notes: [if (extra > 0) t.planExtraEmptyToRemove],
          opener: (open) => Row(
            children: [
              Expanded(
                child: Text(
                  t.planExtraLabel,
                  style: onest(14, color: Mid.ink2, height: 1.35),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                key: const ValueKey('savings-extra-edit'),
                onPressed: open,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  side: BorderSide(color: Mid.blue, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  extra > 0 ? here(extra) : t.planExtraNone,
                  style: onest(15, weight: 600, color: Mid.blue, tabular: true),
                ),
              ),
            ],
          ),
          onSave: (v) {
            if (v == null) {
              if (extra > 0) {
                unawaited(
                  act(
                    const PhoneSavingsAnswer({ReadyKeys.extra: null}),
                    t.planExtraRemoved,
                  ),
                );
              }
            } else if (v != extra) {
              unawaited(
                act(
                  // With its currency, as the month of expenses is kept.
                  PhoneSavingsAnswer({ReadyKeys.extra: '${c.code}:$v'}),
                  t.planExtraSet(here(v)),
                ),
              );
            }
          },
        ),
        if (missing.isNotEmpty)
          note(
            t.planPlanNeedsPay(namesAnd(t, missing.map((d) => d.account.name))),
            key: const ValueKey('savings-payoff-needs-pay'),
          )
        else if (both) ...[
          const SizedBox(height: 12),
          // The way followed, as its card on the Compare page reads; a debt
          // picked by hand is neither way, said instead.
          if (r.picked == null)
            _PhoneWayCard(
              method: followed,
              plan: followed == PayoffMethod.smallest ? small : rate,
              gap: (small.interest - rate.interest).abs(),
              r: r,
            )
          else
            note(
              t.phonePlanPicked(r.picked!.account.name),
              key: const ValueKey('savings-payoff-picked'),
            ),
          const SizedBox(height: 10),
          _OutlineButton(
            key: const ValueKey('savings-compare'),
            label: t.phoneCompareWays,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _ComparePage(
                  store: _storeOf(context),
                  currency: c,
                  act: act,
                ),
              ),
            ),
          ),
        ] else if (small != null)
          note(
            small.months == null
                ? t.planPlanNever
                : small.interest > 0
                ? t.planPlanOne(
                    payoffMonth(t, r, small.months!),
                    interestAbout(small.interest, c),
                  )
                : t.planPlanOneNoInterest(payoffMonth(t, r, small.months!)),
            key: const ValueKey('savings-payoff-one'),
            color: Mid.ink,
          ),
        if (missing.isEmpty && !both && rated < 2 && r.consumerDebts.length > 1)
          note(
            t.planPlanNeedRates,
            key: const ValueKey('savings-payoff-need-rates'),
          ),
        ..._payoffNotes(t, c, r, netFirst: netFirst, note: note),
      ],
    );
  }
}

/// The lines under the two ways, on the step and on the Compare page:
/// a card spent on lately, the safety net first, goals out of the extra,
/// debts with no rate, and what the dates assume.
List<Widget> _payoffNotes(
  Words t,
  Currency c,
  Readiness r, {
  required bool netFirst,
  required Widget Function(String text, {Key? key, Color? color}) note,
}) {
  String here(int v) => formatShort(v, currency: c);
  final missing = r.missingPayments;
  final rated = r.consumerDebts.length - r.missingRates.length;
  return [
    if (missing.isEmpty)
      for (final d in r.debtsInOrder)
        if (r.chargedLately[d.account.id] case final v?)
          note(
            t.planPlanCharged(here(v), d.account.name),
            key: ValueKey('savings-payoff-charged-${d.account.id}'),
            color: Mid.ink,
          ),
    if (netFirst)
      note(
        t.planPlanNetFirst,
        key: const ValueKey('savings-payoff-net-first'),
        color: Mid.ink,
      ),
    if (r.extra > 0)
      if (goalsAskOf(r, c) case (final asks, final name)?)
        note(
          name == null
              ? t.goalsFromExtraMany(here(asks))
              : t.goalsFromExtraOne(here(asks), name),
          key: const ValueKey('savings-payoff-goals'),
          color: Mid.ink,
        ),
    if (missing.isEmpty && r.missingRates.isNotEmpty && rated > 0)
      note(
        t.planPlanNoRate(
          namesAnd(t, r.missingRates.map((d) => d.account.name)),
        ),
      ),
    if (missing.isEmpty)
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(t.planPlanAssume, style: onest(13, color: Mid.ink2)),
      ),
  ];
}

/// The phone's store, from the Savings tab above.
PhoneStore _storeOf(BuildContext context) =>
    context.findAncestorStateOfType<_SavingsScreenState>()!.widget.store;

/// One way: when everything is paid off, about how much interest, which
/// goes first. [onTap] picks it; the one followed is outlined and ticked.
class _PhoneWayCard extends StatelessWidget {
  const _PhoneWayCard({
    required this.method,
    required this.plan,
    required this.gap,
    required this.r,
    this.onTap,
  });
  final PayoffMethod method;
  final PayoffPlan plan;

  /// The two ways' difference in interest, which the figure is said to.
  final int gap;
  final Readiness r;
  final VoidCallback? onTap;

  String _name(int id) =>
      r.consumerDebts.firstWhere((d) => d.account.id == id).account.name;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = CurrencyScope.of(context);
    final on = r.method == method && r.picked == null;
    final order = r.orderOf(method);
    final first = plan.firstIn(order);
    // The first paid off may go by its own payments while the extra goes
    // to another: that one is named too (budget review).
    final extraTo = first != null && order.first != first.id
        ? _name(order.first)
        : null;
    Widget line(String text) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text, style: onest(14, color: Mid.ink2, tabular: true)),
    );
    return Semantics(
      selected: on,
      button: onTap != null,
      child: Material(
        color: on ? Mid.blueWash : Mid.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: on ? Mid.blue : Mid.rule, width: on ? 2 : 1),
        ),
        child: InkWell(
          key: ValueKey('savings-way-${method.name}'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      on
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: on ? Mid.blue : Mid.ink2,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        method == PayoffMethod.smallest
                            ? t.planMethodSmallest
                            : t.planMethodRate,
                        style: onest(15.5, weight: 600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  plan.months == null
                      ? t.planPlanNever
                      : t.planPlanDone(payoffMonth(t, r, plan.months!)),
                  style: onest(15, tabular: true),
                ),
                if (plan.months != null)
                  line(
                    t.planPlanInterest(payoffInterest(plan.interest, gap, c)),
                  ),
                if (first != null)
                  line(
                    t.planPlanFirst(
                      _name(first.id),
                      payoffMonth(t, r, first.month),
                    ),
                  ),
                if (extraTo != null) line(t.planPlanExtraTo(extraTo)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compare the two ways: both cards, one under the other, a tap on one
/// following it; what differs said under them.
class _ComparePage extends StatelessWidget {
  const _ComparePage({
    required this.store,
    required this.currency,
    required this.act,
  });
  final PhoneStore store;
  final Currency currency;
  final Future<void> Function(PhoneRowAct act, String said) act;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      backgroundColor: Mid.ground,
      appBar: AppBar(
        backgroundColor: Mid.ground,
        foregroundColor: Mid.ink,
        title: Text(t.phoneCompareWays, style: onest(19, weight: 600)),
      ),
      body: CurrencyScope(
        currency: currency,
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final r = _readinessFor(store.snapshot);
            final small = r?.payoff(PayoffMethod.smallest);
            final rate = r?.payoff(PayoffMethod.highestRate);
            // The two ways no longer differ (a debt paid off meanwhile):
            // nothing to compare, and the step says what's left.
            if (r == null ||
                small == null ||
                rate == null ||
                !r.methodsDiffer) {
              return const SizedBox.shrink();
            }
            final gap = (small.interest - rate.interest).abs();
            final difference = payoffDifference(t, currency, r, small, rate);
            Widget note(String text, {Key? key, Color? color}) => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                text,
                key: key,
                style: onest(
                  14.5,
                  color: color ?? Mid.ink2,
                  height: 1.4,
                  tabular: true,
                ),
              ),
            );
            final dated = small.months != null;
            final netFirst =
                dated &&
                r.extra > 0 &&
                !r.isDone(ReadyStep.oneMonth) &&
                !r.setAside.contains(ReadyStep.oneMonth);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                for (final m in PayoffMethod.values) ...[
                  if (m != PayoffMethod.values.first)
                    const SizedBox(height: 12),
                  _PhoneWayCard(
                    method: m,
                    plan: m == PayoffMethod.smallest ? small : rate,
                    gap: gap,
                    r: r,
                    onTap: () {
                      if (r.method == m && r.picked == null) return;
                      final smallest = m == PayoffMethod.smallest;
                      unawaited(
                        act(
                          PhoneSavingsAnswer({
                            ReadyKeys.method: smallest ? null : 'rate',
                            ReadyKeys.target: null,
                          }),
                          smallest
                              ? t.planMethodSmallestUndo
                              : t.planMethodRateUndo,
                        ),
                      );
                    },
                  ),
                ],
                if (difference.isNotEmpty)
                  note(
                    difference,
                    key: const ValueKey('savings-payoff-difference'),
                    color: Mid.ink,
                  ),
                if (r.picked != null)
                  note(
                    t.phonePlanPicked(r.picked!.account.name),
                    key: const ValueKey('savings-compare-picked'),
                  ),
                ..._payoffNotes(t, currency, r, netFirst: netFirst, note: note),
              ],
            );
          },
        ),
      ),
    );
  }
}
