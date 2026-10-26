part of 'ledger_screen.dart';

// The Savings section (ADR 0004, rule 25 and "Four Savings steps"): the
// owner's four steps, each with the picture they drew for it. Every step
// shows; the current one is the first not done, and any can be set aside. The
// app works out what it can from the ledger and asks only what it can't know.

/// What the page changes, each recorded for undo by the screen.
class _SavingsActions {
  const _SavingsActions({
    required this.setRole,
    required this.setPref,
    required this.setAside,
    required this.assign,
  });

  /// Sets what is assigned to [category] this calendar month to [total].
  final void Function(AccountInfo category, int total) assign;

  /// Sets a step aside or brings it back, from the newest ledger so two
  /// quick clicks both count.
  final void Function(ReadyStep step, bool aside, String label) setAside;

  /// Marks an account (or clears it); [label] names the change for undo.
  final void Function(AccountInfo account, AccountRole? role, String label)
  setRole;

  /// Sets a `ready.*` preference; null removes it. [toast] for saved
  /// changes; answers are quick clicks, quiet like clearing a row.
  final void Function(String key, String? value, String label, {bool toast})
  setPref;
}

/// An amount in Savings' one currency (the page's [CurrencyScope]).
String _here(BuildContext context, int v) =>
    formatShort(v, currency: CurrencyScope.of(context));

class _SavingsPage extends StatelessWidget {
  const _SavingsPage({
    required this.data,
    required this.today,
    required this.actions,
  });
  final LedgerData data;
  final DateTime today;
  final _SavingsActions actions;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final r = Readiness.of(data, today);
    final main = savingsCurrency(data);
    final others = [
      for (final a in data.openAccounts)
        if (a.currency != main)
          if (data.balanceOf(a.id) case final b when a.isOwed && b < 0)
            t.savingsOtherOwed(a.name, _money(-b, a.currency))
          else
            t.savingsOtherHeld(
              a.name,
              _money(data.balanceOf(a.id), a.currency),
            ),
    ].join(', ');
    return CurrencyScope(
      currency: main,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 36,
                  child: Row(
                    children: [
                      Text(
                        t.planSavings,
                        style: onest(22, weight: 600, letterSpacing: -0.3),
                      ),
                      const SizedBox(width: 14),
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          r.current == null
                              ? t.planAllStepsDone
                              : t.planOneStepAtATime,
                          key: const ValueKey('savings-subtitle'),
                          style: onest(13.5, color: Mid.ink3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Mid.panel,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Mid.rule),
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                      children: [
                        for (final s in ReadyStep.values)
                          _StepRow(
                            key: ValueKey('step-${s.name}'),
                            step: s,
                            r: r,
                            data: data,
                            actions: actions,
                          ),
                        if (others.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                            child: Text(
                              t.savingsOnlyOne(others, currencyName(t, main)),
                              key: const ValueKey('savings-one-currency'),
                              style: onest(12, color: Mid.ink3),
                            ),
                          ),
                      ],
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

String _stepTitle(Words t, ReadyStep s) => switch (s) {
  ReadyStep.oneMonth => t.planStepOneMonth,
  ReadyStep.consumerDebt => t.planStepConsumerDebt,
  ReadyStep.moreMonths => t.planStepMoreMonths,
  ReadyStep.future => t.planStepFuture,
};

/// The owner's picture for a step, by its file's name.
String _stepPicture(ReadyStep s) => switch (s) {
  ReadyStep.oneMonth => 'safety-net',
  ReadyStep.consumerDebt => 'eliminate-debt',
  ReadyStep.moreMonths => 'three-to-six-months',
  ReadyStep.future => 'save-for-the-future',
};

class _StepRow extends StatelessWidget {
  const _StepRow({
    super.key,
    required this.step,
    required this.r,
    required this.data,
    required this.actions,
  });
  final ReadyStep step;
  final Readiness r;
  final LedgerData data;
  final _SavingsActions actions;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = r.stateOf(step);
    final current = state == ReadyState.current;
    final aside = state == ReadyState.setAside;
    final number = ReadyStep.values.indexOf(step) + 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: BoxDecoration(
        color: current ? Mid.blueWash : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: current ? Mid.blueEdge : Colors.transparent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: aside ? 0.45 : 1,
            child: SavingsPicture(_stepPicture(step), size: 96),
          ),
          const SizedBox(width: 20),
          _StepMarker(number: number, state: state),
          const SizedBox(width: 12),
          Expanded(
            // The page fills the window; a step's sentences stay a width
            // that reads ([_reads]), its debt lines a little wider.
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _stepWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _stepTitle(t, step),
                            style: onest(
                              14.5,
                              weight: current ? 600 : 500,
                              color: aside ? Mid.ink3 : Mid.ink,
                            ),
                          ),
                        ),
                        if (current) ...[
                          const SizedBox(width: 10),
                          Text(t.planNow, style: onest(12, color: Mid.blue)),
                        ],
                        if (aside) ...[
                          const SizedBox(width: 10),
                          Text(
                            t.planSetAside,
                            style: onest(12, color: Mid.ink3),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    ..._body(context, t, state),
                  ],
                ),
              ),
            ),
          ),
          _StepMenu(
            step: step,
            r: r,
            aside: aside,
            onSetAside: (a) => actions.setAside(
              step,
              a,
              a
                  ? t.planSetAsideUndo(_stepTitle(t, step))
                  : t.planBackInStepsUndo(_stepTitle(t, step)),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context, Words t, ReadyState state) {
    final current = state == ReadyState.current;
    Widget fact(String text, {Key? key, Color? color}) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _reads),
      child: Text(
        text,
        key: key,
        style: onest(13, color: color ?? Mid.ink2, tabular: true),
      ),
    );
    Widget guide(String text) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _reads),
        child: Text(text, style: onest(13, color: Mid.ink2, height: 1.4)),
      ),
    );
    Widget controls(List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(runSpacing: 8, children: children),
    );

    switch (step) {
      case ReadyStep.oneMonth:
      case ReadyStep.moreMonths:
        final target = r.targetOf(step);
        final m = r.month;
        final loans = m.loanPayments > 0 ? 'yes' : 'no';
        final aboutMonth = m.amount == 0
            ? (m.days < MonthOfSpending.minDays
                  ? t.planMonthUnknown
                  : t.planMonthNoSpending(m.days))
            : m.typed
            ? t.planMonthTyped(_here(context, m.amount))
            : m.fromBudget
            ? t.planMonthBudget(_here(context, m.amount))
            : m.days >= MonthOfSpending.spanDays
            ? t.planMonthAverage3(_here(context, m.amount), loans)
            : t.planMonthAverageDays(_here(context, m.amount), m.days, loans);
        final noFund = !r.hasFund;
        return [
          if (target > 0 && !noFund) ...[
            fact(
              r.fund >= target
                  ? t.planFundOf(_here(context, r.fund), _here(context, target))
                  : t.planFundOfToGo(
                      _here(context, r.fund),
                      _here(context, target),
                      _here(context, target - r.fund),
                    ),
              key: ValueKey('step-${step.name}-progress'),
              color: Mid.ink,
            ),
            const SizedBox(height: 8),
            _Progress(
              value: r.fund / target,
              done: r.fund >= target,
              muted: !current && state != ReadyState.done,
            ),
            const SizedBox(height: 8),
          ],
          if (step == ReadyStep.oneMonth || current) fact(aboutMonth),
          if (step == ReadyStep.oneMonth && m.outgrown)
            guide(t.planMonthOutgrown(_here(context, m.inBudget))),
          if (step == ReadyStep.oneMonth) ..._safetyNet(context, t, guide),
          if (current && step == ReadyStep.oneMonth) ...[
            if (r.fund > 0) guide(t.planKeepReachable),
            if (r.consumerDebts case final debts
                when debts.any(
                  (d) => !r.looksPaidInFull.contains(d.account.id),
                ))
              guide(
                t.planMinimumsOn(
                  _names(t, [
                    for (final d in debts)
                      if (!r.looksPaidInFull.contains(d.account.id))
                        d.account.name,
                  ]),
                ),
              ),
          ],
          if (current && step == ReadyStep.moreMonths)
            guide(t.planEnoughForJobLoss),
          if (current && step == ReadyStep.moreMonths)
            ..._assignOffer(context, t, guide, step),
          // The fund and the month are set on step 1 only, so they never
          // show twice; step 3 adds how many months.
          if (step == ReadyStep.oneMonth)
            controls([_MonthField(r: r, actions: actions)]),
          // The title says three to six; this says which, and changes it.
          if (step == ReadyStep.moreMonths)
            controls([_MonthsChoice(r: r, actions: actions)]),
        ];
      case ReadyStep.consumerDebt:
        return [
          fact(
            r.consumerDebts.isEmpty
                ? t.planNoCardsOwing
                : t.planAmountOwed(_here(context, r.consumerOwed)),
            key: const ValueKey('step-consumerDebt-owed'),
            color: r.consumerDebts.isEmpty ? Mid.ink2 : Mid.ink,
          ),
          if (current && r.consumerDebts.isNotEmpty) guide(t.planPayExtraGuide),
          // Keyed by account: the lines reorder as rates change, and an
          // open rate field stays with its own debt.
          for (final d in r.debtsByCost)
            _DebtLine(
              key: ValueKey('debt-line-${d.account.id}'),
              debt: d,
              r: r,
              actions: actions,
            ),
          for (final a in data.openAccounts)
            if (a.isOwed &&
                a.role == AccountRole.paidMonthly &&
                a.currency == CurrencyScope.of(context))
              _DebtLine(
                key: ValueKey('debt-line-${a.id}'),
                debt: (account: a, owed: -data.balanceOf(a.id)),
                r: r,
                actions: actions,
              ),
        ];
      case ReadyStep.future:
        Widget part(String text) => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(text, style: onest(13, weight: 600, color: Mid.ink)),
        );
        void answer(String? v, String label) =>
            actions.setPref(ReadyKeys.longLoans, v, label);
        final said = data.prefs[ReadyKeys.longLoans];
        return [
          part(t.planStepRetirement),
          fact(r.retirement ? t.planRetirementYes : t.planRetirementWhat),
          if (current && !r.retirement) guide(t.planEmployerMatch),
          controls([
            _Answer(
              stepKey: 'retirement',
              yes: r.retirement,
              yesLabel: t.planIAm,
              onChanged: (v) => actions.setPref(
                ReadyKeys.retirement,
                v ? 'yes' : null,
                v
                    ? t.planAnswerYesUndo(t.planStepRetirement)
                    : t.planAnswerNotYetUndo(t.planStepRetirement),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          part(t.planStepLongLoans),
          if (!r.longMarked) ...[
            fact(switch (said) {
              'none' => t.planLongNone,
              'yes' => t.planPayingExtra,
              _ => t.planLongAsk,
            }),
            if (r.consumerDebts.isNotEmpty && !r.longAnswer)
              guide(t.planLongMarkThere),
            controls([
              _Choice(
                key: const ValueKey('answer-longLoans-none'),
                label: t.planIHaveNone,
                on: said == 'none',
                onTap: () => answer('none', t.planNoLongLoansUndo),
              ),
              _Choice(
                key: const ValueKey('answer-longLoans-yes'),
                label: t.planPayingExtraOnThem,
                on: said == 'yes',
                onTap: () => answer('yes', t.planPayingExtraUndo),
              ),
              _Choice(
                key: const ValueKey('answer-longLoans-no'),
                label: t.planNotYet,
                on: said == null,
                onTap: () => answer(null, t.planLoansNotYetUndo),
              ),
            ]),
          ] else ...[
            fact(
              r.longLoans.isEmpty
                  ? t.planPaidOff
                  : t.planAmountLeft(_here(context, r.longOwed)),
            ),
            for (final d in r.longLoans)
              _DebtLine(
                key: ValueKey('debt-line-${d.account.id}'),
                debt: d,
                r: r,
                actions: actions,
              ),
            if (r.longLoans.isNotEmpty)
              controls([
                _Answer(
                  stepKey: 'longLoans',
                  yes: said == 'yes',
                  yesLabel: t.planPayingExtra,
                  onChanged: (v) => answer(
                    v ? 'yes' : null,
                    v ? t.planPayingExtraUndo : t.planNotPayingExtraUndo,
                  ),
                ),
              ]),
          ],
        ];
    }
  }
}

extension on _StepRow {
  /// The safety net is a budget category: what it is while there is none,
  /// then where its money sits and what in the budget could still go to it.
  List<Widget> _safetyNet(
    BuildContext context,
    Words t,
    Widget Function(String) guide,
  ) {
    if (!r.hasFund) return const [];
    // Savings accounts it could be kept in: a wallet isn't one.
    final banks = data.openAccounts.where((a) => !a.isOwed && !a.isCash).length;
    return [
      // Nothing in it yet: what it is and where to keep it.
      if (r.fund == 0) guide(t.planWhichAccount),
      if (r.keptIn.isNotEmpty && r.fund > 0)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            r.keptThere >= r.fund
                ? t.planFundAllIn(_names(t, r.keptIn.map((a) => a.name)))
                : t.planFundWhere(
                    _here(context, r.keptThere),
                    _names(t, r.keptIn.map((a) => a.name)),
                    _here(context, r.fund - r.keptThere),
                  ),
            key: const ValueKey('fund-where'),
            style: onest(13, color: Mid.ink2, tabular: true),
          ),
        ),
      if (r.fund > 0 && r.overAssigned > 0)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            t.planFundOverAssigned(_here(context, r.overAssigned)),
            key: const ValueKey('fund-over'),
            style: onest(13, color: Mid.coral, tabular: true),
          ),
        ),
      if (r.keptIn.isEmpty &&
          banks > 1 &&
          r.fund > 0 &&
          !r.isDone(ReadyStep.oneMonth))
        guide(t.planFundSetPaidFrom),
      ..._assignOffer(context, t, guide, ReadyStep.oneMonth),
    ];
  }

  /// What's not assigned in the budget, and a button that assigns as much
  /// of it as fills [step], leaving this month's bills theirs.
  List<Widget> _assignOffer(
    BuildContext context,
    Words t,
    Widget Function(String) guide,
    ReadyStep step,
  ) {
    final offer = r.offerFor(step);
    final category = r.fundCategories.length == 1
        ? r.fundCategories.single
        : null;
    if (category == null || offer <= 0) return const [];
    return [
      guide(t.planFundNotAssigned(_here(context, r.notAssigned))),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: BarButton(
          key: ValueKey('fund-assign-${step.name}'),
          label: t.planAssignUndo(_here(context, offer), category.name),
          color: Mid.blue,
          onTap: () => actions.assign(category, r.fundAssigned + offer),
        ),
      ),
    ];
  }
}

/// An amount as it's typed back into a field: whole units, and the cents
/// when it has any, so Enter on it saves what was there.
String _typedText(int minor, Currency c) =>
    '${formatWhole(minor, c)}${c.hasCents(minor) ? formatCents(minor, c) : ''}';

String _names(Words t, Iterable<String> names) {
  final l = names.toList();
  if (l.length < 2) return l.join();
  return t.planNamesAnd(l.sublist(0, l.length - 1).join(', '), l.last);
}

class _StepMarker extends StatelessWidget {
  const _StepMarker({required this.number, required this.state});
  final int number;
  final ReadyState state;

  @override
  Widget build(BuildContext context) {
    final (fill, edge, ink) = switch (state) {
      ReadyState.done => (
        Mid.green.withValues(alpha: 0.16),
        Mid.green,
        Mid.green,
      ),
      ReadyState.current => (Mid.blue, Mid.blue, Mid.ink),
      ReadyState.later => (Colors.transparent, Mid.ink3, Mid.ink2),
      ReadyState.setAside => (Colors.transparent, Mid.rule, Mid.ink3),
    };
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: edge),
      ),
      child: state == ReadyState.done
          ? Icon(Icons.check_rounded, size: 14, color: Mid.green)
          : Text('$number', style: onest(11.5, weight: 600, color: ink)),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({
    required this.value,
    required this.done,
    required this.muted,
  });
  final double value;
  final bool done;
  final bool muted;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: SizedBox(
      height: 6,
      width: 360,
      child: Stack(
        children: [
          Container(color: Mid.ground.withValues(alpha: 0.7)),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              color: done ? Mid.green : (muted ? Mid.ink3 : Mid.blue),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A month of expenses, typed over the average. Empty goes back to it.
class _MonthField extends StatefulWidget {
  const _MonthField({required this.r, required this.actions});
  final Readiness r;
  final _SavingsActions actions;

  @override
  State<_MonthField> createState() => _MonthFieldState();
}

class _MonthFieldState extends State<_MonthField> {
  TextEditingController? _editing;
  final _focus = FocusNode(debugLabel: 'month-of-expenses');
  bool _wrong = false;

  @override
  void dispose() {
    _editing?.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _start() {
    final m = widget.r.month;
    setState(() {
      _wrong = false;
      _editing = TextEditingController(
        text: m.typed ? _typedText(m.amount, CurrencyScope.of(context)) : '',
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _close() {
    // Back to the screen's keys, so ⌘Z works straight after.
    _focus.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    final c = _editing;
    setState(() => _editing = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => c?.dispose());
  }

  void _save() {
    final text = _editing!.text.trim();
    final m = widget.r.month;
    if (text.isEmpty) {
      if (m.typed) {
        widget.actions.setPref(
          ReadyKeys.month,
          null,
          context.t.planMonthBackToAverage,
          toast: true,
        );
      }
      return _close();
    }
    final v = parseAmount(text, CurrencyScope.of(context));
    if (v == null || v <= 0) return setState(() => _wrong = true);
    widget.actions.setPref(
      ReadyKeys.month,
      // With its currency, so it can't turn into dollars when Savings does.
      '${CurrencyScope.of(context).code}:$v',
      context.t.planMonthSet(_here(context, v)),
      toast: true,
    );
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final m = widget.r.month;
    if (_editing == null) {
      return BarButton(
        key: const ValueKey('month-edit'),
        label: m.amount == 0
            ? t.planTypeMonth
            : m.typed
            ? t.planChangeMonth
            : t.planTypeOwnMonth,
        color: m.amount == 0 ? Mid.blue : null,
        onTap: _start,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 180,
              height: 28,
              child: TextField(
                key: const ValueKey('month-field'),
                controller: _editing,
                focusNode: _focus,
                style: onest(13, tabular: true),
                onSubmitted: (_) => _save(),
                decoration:
                    _fieldDecoration(
                      hint: m.amount == 0
                          ? t.planMonthHint
                          : formatWhole(m.amount, CurrencyScope.of(context)),
                      wrong: _wrong,
                    ).copyWith(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
              ),
            ),
            const SizedBox(width: 8),
            BarButton(
              key: const ValueKey('month-save'),
              label: t.planSave,
              onTap: _save,
            ),
            if (m.typed)
              Text(t.planEmptyToAverage, style: onest(12, color: Mid.ink3)),
          ],
        ),
      ),
    );
  }
}

/// How many months the bigger fund aims for: the course says three to six.
class _MonthsChoice extends StatelessWidget {
  const _MonthsChoice({required this.r, required this.actions});
  final Readiness r;
  final _SavingsActions actions;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final n in [3, 4, 5, 6])
        BarButton(
          key: ValueKey('months-$n'),
          label: context.t.planMonthsChoice(n),
          active: r.monthsTarget == n,
          color: r.monthsTarget == n ? Mid.blue : Mid.ink2,
          onTap: () => actions.setPref(
            ReadyKeys.months,
            n == 3 ? null : '$n',
            context.t.planAimingFor(n),
          ),
        ),
    ],
  );
}

class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.label,
    required this.on,
    required this.onTap,
  });
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => BarButton(
    label: label,
    active: on,
    color: on ? Mid.blue : Mid.ink2,
    onTap: onTap,
  );
}

class _Answer extends StatelessWidget {
  const _Answer({
    required this.stepKey,
    required this.yes,
    required this.yesLabel,
    required this.onChanged,
  });
  final String stepKey;
  final bool yes;
  final String yesLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      BarButton(
        key: ValueKey('answer-$stepKey-yes'),
        label: yesLabel,
        active: yes,
        color: yes ? Mid.green : Mid.ink2,
        onTap: () => onChanged(true),
      ),
      BarButton(
        key: ValueKey('answer-$stepKey-no'),
        label: context.t.planNotYet,
        active: !yes,
        onTap: () => onChanged(false),
      ),
    ],
  );
}

/// What Savings counts a card or loan as: a student loan (marked when it
/// waited with the mortgage) is debt to pay off like an unmarked one.
bool _sameRole(AccountRole? a, AccountRole? b) {
  AccountRole? counted(AccountRole? r) =>
      r == AccountRole.studentLoan ? null : r;
  return counted(a) == counted(b);
}

String _roleWords(Words t, AccountRole? role) => switch (role) {
  AccountRole.mortgage => t.planRoleMortgage,
  AccountRole.paidMonthly => t.planRolePaidMonthly,
  _ => t.planRoleConsumer,
};

/// The undo label for marking [name] as [role].
String _countsAs(Words t, String name, AccountRole? role) => switch (role) {
  AccountRole.mortgage => t.planCountsAsMortgage(name),
  AccountRole.paidMonthly => t.planCountsAsPaidMonthly(name),
  _ => t.planCountsAsConsumer(name),
};

/// A card or loan, what's owed on it, and what it counts as; a debt to pay
/// off also its interest rate, and what that costs a month.
class _DebtLine extends StatefulWidget {
  const _DebtLine({
    super.key,
    required this.debt,
    required this.r,
    required this.actions,
  });
  final Debt debt;
  final Readiness r;
  final _SavingsActions actions;

  @override
  State<_DebtLine> createState() => _DebtLineState();
}

class _DebtLineState extends State<_DebtLine> {
  /// The rate being typed, while the field is open.
  TextEditingController? _rate;
  final _focus = FocusNode(debugLabel: 'debt-rate');
  var _perYear = false;
  var _wrong = false;

  @override
  void dispose() {
    _rate?.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _start() {
    final had = widget.r.rates[widget.debt.account.id];
    setState(() {
      _wrong = false;
      _perYear = had?.perYear ?? ratePerYearFor(widget.debt.account.currency);
      _rate = TextEditingController(
        text: had == null ? '' : ratePercent(had.percent),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _close() {
    // Back to the screen's keys, so ⌘Z works straight after.
    _focus.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    final c = _rate;
    setState(() => _rate = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => c?.dispose());
  }

  void _save() {
    final t = context.t;
    final a = widget.debt.account;
    final had = widget.r.rates[a.id];
    final text = _rate!.text.trim();
    if (text.isEmpty) {
      if (had != null) {
        widget.actions.setPref(
          ReadyKeys.rate(a.id),
          null,
          t.planRateRemoved(a.name),
          toast: true,
        );
      }
      return _close();
    }
    final percent = parseRatePercent(text);
    if (percent == null) return setState(() => _wrong = true);
    final DebtRate rate = (percent: percent, perYear: _perYear);
    if (had?.value != rate.value) {
      widget.actions.setPref(
        ReadyKeys.rate(a.id),
        rate.value,
        t.planRateSet(a.name, _rateWords(t, rate)),
        toast: true,
      );
    }
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final debt = widget.debt;
    final r = widget.r;
    final actions = widget.actions;
    final a = debt.account;
    final consumer = r.consumerDebts.any((d) => d.account.id == a.id);
    final target = consumer && r.target?.account.id == a.id;
    final carried = r.carriedSince[a.id];
    final rate = r.rates[a.id];
    final interest = consumer ? r.interestOf(debt) : null;
    final line = Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          SizedBox(
            width: _debtName,
            child: Text(
              a.name,
              style: onest(13, color: Mid.ink2),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: _debtOwed,
            child: Text(
              debt.owed > 0 ? _here(context, debt.owed) : t.planNothingOwed,
              style: onest(13, color: Mid.ink2, tabular: true),
            ),
          ),
          if (consumer)
            SizedBox(
              width: _debtRate,
              child: Row(
                children: [
                  Flexible(
                    child: Hoverable(
                      key: ValueKey('debt-${a.id}-rate'),
                      onTap: _rate == null ? _start : _close,
                      builder: (hover) => Text(
                        rate == null ? t.planRateAdd : _rateWords(t, rate),
                        overflow: TextOverflow.ellipsis,
                        style:
                            onest(
                              12.5,
                              color: rate == null
                                  ? Mid.blue
                                  : (hover ? Mid.ink2 : Mid.ink3),
                              tabular: true,
                            ).copyWith(
                              decoration: hover
                                  ? TextDecoration.underline
                                  : null,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: t.planRateTip,
                    waitDuration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.info_outline_rounded,
                      key: ValueKey('debt-${a.id}-rate-tip'),
                      size: 14,
                      color: Mid.ink3,
                    ),
                  ),
                ],
              ),
            ),
          // The last two give way with "…" before the line runs out of room.
          Flexible(
            child: MenuAnchor(
              style: _menuStyle,
              menuChildren: [
                if (consumer && !target)
                  MenuItemButton(
                    key: ValueKey('debt-${a.id}-target'),
                    onPressed: () => actions.setPref(
                      ReadyKeys.target,
                      '${a.id}',
                      t.planPayingExtraOn(a.name),
                      toast: true,
                    ),
                    style: ButtonStyle(
                      minimumSize: const WidgetStatePropertyAll(Size(240, 34)),
                      overlayColor: WidgetStatePropertyAll(Mid.blueWash),
                    ),
                    child: Text(
                      t.planPayExtraOnThis,
                      style: onest(13, color: Mid.ink2),
                    ),
                  ),
                for (final role in <AccountRole?>[
                  null,
                  AccountRole.paidMonthly,
                  AccountRole.mortgage,
                ])
                  MenuItemButton(
                    key: ValueKey('debt-${a.id}-${role?.name ?? 'consumer'}'),
                    // An account marked a student loan under the six steps is
                    // debt to pay off already: picking that leaves its mark.
                    onPressed: () {
                      if (_sameRole(a.role, role)) return;
                      actions.setRole(a, role, _countsAs(t, a.name, role));
                    },
                    leadingIcon: Icon(
                      _sameRole(a.role, role) ? Icons.check_rounded : null,
                      size: 16,
                      color: Mid.blue,
                    ),
                    style: ButtonStyle(
                      minimumSize: const WidgetStatePropertyAll(Size(240, 34)),
                      overlayColor: WidgetStatePropertyAll(Mid.blueWash),
                    ),
                    child: Text(
                      _roleWords(t, role),
                      style: onest(13, color: Mid.ink2),
                    ),
                  ),
              ],
              builder: (context, menu, _) => Hoverable(
                key: ValueKey('debt-${a.id}-role'),
                onTap: () => menu.isOpen ? menu.close() : menu.open(),
                builder: (hover) => Text(
                  _roleWords(t, a.role),
                  overflow: TextOverflow.ellipsis,
                  style: onest(12.5, color: hover ? Mid.ink2 : Mid.ink3)
                      .copyWith(
                        decoration: hover ? TextDecoration.underline : null,
                      ),
                ),
              ),
            ),
          ),
          if (target) ...[
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                t.planPayExtraHere,
                key: ValueKey('debt-${a.id}-is-target'),
                overflow: TextOverflow.ellipsis,
                style: onest(12.5, color: Mid.blue),
              ),
            ),
          ],
        ],
      ),
    );
    final editing = _rate;
    if (carried == null && interest == null && editing == null) return line;
    // Said only when what's shown differs: two that read "about ₮48,000"
    // aren't one costing more.
    final rated = r.ratedByCost;
    final most =
        r.costliest?.account.id == a.id &&
        _interest(context, r.interestOf(rated[0])!) !=
            _interest(context, r.interestOf(rated[1])!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line,
        if (interest != null)
          Padding(
            // Under what's owed, which it is worked out from.
            padding: const EdgeInsets.only(left: _debtName, top: 2),
            child: Text(
              most
                  ? t.planInterestCostsMost(_interest(context, interest))
                  : t.planInterestAMonth(_interest(context, interest)),
              key: ValueKey('debt-${a.id}-interest'),
              style: onest(12.5, color: most ? Mid.ink : Mid.ink3),
            ),
          ),
        if (editing != null)
          Padding(
            padding: const EdgeInsets.only(left: _debtName, top: 6, bottom: 2),
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): _close,
              },
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.start,
                spacing: 8,
                runSpacing: 6,
                children: [
                  _RateInput(
                    fieldKey: ValueKey('debt-${a.id}-rate-field'),
                    currency: a.currency,
                    controller: editing,
                    focusNode: _focus,
                    perYear: _perYear,
                    wrong: _wrong,
                    onPerYear: (v) => setState(() => _perYear = v),
                    onEdited: () {
                      if (_wrong) setState(() => _wrong = false);
                    },
                    onSubmitted: _save,
                  ),
                  BarButton(
                    key: ValueKey('debt-${a.id}-rate-cancel'),
                    label: t.setupCancel,
                    onTap: _close,
                  ),
                  BarButton(
                    key: ValueKey('debt-${a.id}-rate-save'),
                    label: t.planSave,
                    color: Mid.blue,
                    onTap: _save,
                  ),
                  if (rate != null)
                    Text(
                      t.planRateEmptyToRemove,
                      style: onest(12, color: Mid.ink3),
                    ),
                ],
              ),
            ),
          ),
        if (carried != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              t.planCarried(sayFullDate(t, carried)),
              key: ValueKey('debt-${a.id}-carried'),
              style: onest(12.5, color: Mid.ink, height: 1.4),
            ),
          ),
        if (consumer && r.looksPaidInFull.contains(a.id))
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              t.planLooksPaidInFull,
              key: ValueKey('debt-${a.id}-paid-in-full'),
              style: onest(12.5, color: Mid.ink2, height: 1.4),
            ),
          ),
      ],
    );
  }
}

/// A step's sentences are held to a width that reads; the step itself is
/// wider, for a debt line's columns.
const double _reads = 640, _stepWidth = 760;

/// A debt line's columns: the name, what's owed, the rate. What it counts
/// as and "Pay extra here" take what's left of [_stepWidth], and give way
/// with "…" only when even that is too little.
const double _debtName = 170, _debtOwed = 116, _debtRate = 130;

/// A rate as said: "2% a month", "24% a year".
String _rateWords(Words t, DebtRate r) => r.perYear
    ? t.planRateYearly(ratePercent(r.percent))
    : t.planRateMonthly(ratePercent(r.percent));

/// Interest a month, as said with "about": ₮48,000, not ₮47,836.
String _interest(BuildContext context, int minor) {
  final c = CurrencyScope.of(context);
  return formatShort(
    roundAbout((minor / c.scale).round()) * c.scale,
    currency: c,
  );
}

/// A rate's field, its %, and whether it is a month's or a year's: on a
/// debt's line in Savings and on Add account for a card or loan.
class _RateInput extends StatelessWidget {
  const _RateInput({
    required this.fieldKey,
    required this.controller,
    required this.perYear,
    required this.onPerYear,
    required this.currency,
    this.focusNode,
    this.onEdited,
    this.wrong = false,
    this.onSubmitted,
  });
  final Key fieldKey;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool perYear;
  final ValueChanged<bool> onPerYear;
  final Currency currency;

  /// Each change to the text, so a red border can clear once it's fixed.
  final VoidCallback? onEdited;
  final bool wrong;
  final VoidCallback? onSubmitted;

  /// A rate that looks typed under the wrong period, said with its
  /// numbers; it is saved as typed all the same (warn, don't block).
  String? _warning(Words t) {
    final percent = parseRatePercent(controller.text);
    if (percent == null) return null;
    final DebtRate r = (percent: percent, perYear: perYear);
    final typed = ratePercent(percent);
    if (rateLooksYearly(r)) {
      return t.planRateLooksYearly(typed, ratePercent(percent * 12));
    }
    if (rateLooksMonthly(r, currency)) {
      return t.planRateLooksMonthly(typed, ratePercent(percent / 12));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final warning = _warning(t);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row(t),
            if (warning != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(
                    warning,
                    key: const ValueKey('rate-warning'),
                    style: onest(12.5, color: Mid.ink, height: 1.4),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _row(Words t) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: 30,
          child: TextField(
            key: fieldKey,
            controller: controller,
            focusNode: focusNode,
            style: onest(13, tabular: true),
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
            onChanged: (_) => onEdited?.call(),
            decoration: _fieldDecoration(wrong: wrong).copyWith(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 8),
          child: Text('%', style: onest(13, color: Mid.ink2)),
        ),
        _Choice(
          key: const ValueKey('rate-per-month'),
          label: t.planRatePerMonth,
          on: !perYear,
          onTap: () => onPerYear(false),
        ),
        _Choice(
          key: const ValueKey('rate-per-year'),
          label: t.planRatePerYear,
          on: perYear,
          onTap: () => onPerYear(true),
        ),
      ],
    );
  }
}

/// ⋯ on a step: set it aside, or bring it back.
class _StepMenu extends StatelessWidget {
  const _StepMenu({
    required this.step,
    required this.r,
    required this.aside,
    required this.onSetAside,
  });
  final ReadyStep step;
  final Readiness r;
  final bool aside;
  final ValueChanged<bool> onSetAside;

  @override
  Widget build(BuildContext context) {
    if (r.isDone(step)) return const SizedBox(width: 28);
    return MenuAnchor(
      style: _menuStyle,
      menuChildren: [
        MenuItemButton(
          key: ValueKey('step-${step.name}-aside'),
          onPressed: () => onSetAside(!aside),
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(220, 34)),
            overlayColor: WidgetStatePropertyAll(Mid.blueWash),
          ),
          child: Text(
            aside ? context.t.planBringBack : context.t.planSetStepAside,
            style: onest(13, color: Mid.ink2),
          ),
        ),
      ],
      builder: (context, menu, _) => Hoverable(
        key: ValueKey('step-${step.name}-menu'),
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
        builder: (hover) => Container(
          width: 28,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hover ? Mid.raised : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.more_horiz_rounded,
            size: 18,
            color: hover ? Mid.ink2 : Mid.ink3,
          ),
        ),
      ),
    );
  }
}
