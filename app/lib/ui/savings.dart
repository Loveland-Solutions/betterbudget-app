part of 'ledger_screen.dart';

// The Savings section (ADR 0004, rule 25): getting financially prepared, one
// step at a time, in the order of the self-reliance course. Every step shows;
// the current one is the first not done, and any can be set aside. The app
// works out what it can from the ledger and asks only what it can't know.

/// What the page changes, each recorded for undo by the screen.
class _SavingsActions {
  const _SavingsActions({
    required this.setRole,
    required this.setPref,
    required this.setAside,
  });

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
String _here(BuildContext context, int v) => formatMoney(
  v,
  showCents: v % 100 != 0,
  currency: CurrencyScope.of(context),
);

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
    final main = mainCurrency(data);
    final others = [
      for (final a in data.openAccounts)
        if (a.currency != main)
          '${a.name} ${_money(data.balanceOf(a.id).abs(), a.currency)}',
    ].join(', ');
    return CurrencyScope(
      currency: main,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
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
                              main == Currency.usd
                                  ? t.savingsOnlyUsd(others)
                                  : t.savingsOnlyMnt(others),
                              key: const ValueKey('savings-one-currency'),
                              style: onest(12, color: Mid.ink3),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                          child: Text(
                            t.planCourseNote,
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

String _stepTitle(Words t, ReadyStep s, Readiness r) => switch (s) {
  ReadyStep.oneMonth => t.planStepOneMonth,
  ReadyStep.health => t.planStepHealth,
  ReadyStep.consumerDebt => t.planStepConsumerDebt,
  ReadyStep.moreMonths => t.planStepMoreMonths(r.monthsTarget),
  ReadyStep.retirement => t.planStepRetirement,
  ReadyStep.longLoans => t.planStepLongLoans,
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
          _StepMarker(number: number, state: state),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _stepTitle(t, step, r),
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
                      Text(t.planSetAside, style: onest(12, color: Mid.ink3)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                ..._body(context, t, state),
              ],
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
                  ? t.planSetAsideUndo(_stepTitle(t, step, r))
                  : t.planBackInStepsUndo(_stepTitle(t, step, r)),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context, Words t, ReadyState state) {
    final current = state == ReadyState.current;
    Widget fact(String text, {Key? key, Color? color}) => Text(
      text,
      key: key,
      style: onest(13, color: color ?? Mid.ink2, tabular: true),
    );
    Widget guide(String text) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(text, style: onest(13, color: Mid.ink2, height: 1.4)),
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
                  ? t.planMonthUnknown(m.days)
                  : t.planMonthNoSpending(m.days))
            : m.typed
            ? t.planMonthTyped(_here(context, m.amount))
            : m.days >= MonthOfSpending.spanDays
            ? t.planMonthAverage3(_here(context, m.amount), loans)
            : t.planMonthAverageDays(_here(context, m.amount), m.days, loans);
        final noFund = r.fundAccounts.isEmpty;
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
          if (current && noFund) guide(t.planWhichAccount),
          if (current && step == ReadyStep.oneMonth) ...[
            guide(t.planKeepReachable),
            if (r.consumerDebts.isNotEmpty)
              guide(
                t.planMinimumsOn(
                  _names(t, r.consumerDebts.map((d) => d.account.name)),
                ),
              ),
          ],
          if (current && step == ReadyStep.moreMonths)
            guide(t.planEnoughForJobLoss),
          // The fund and the month are set on step 1 only, so they never
          // show twice; step 4 adds how many months.
          if (step == ReadyStep.oneMonth)
            controls([
              _FundPicker(data: data, r: r, actions: actions),
              _MonthField(r: r, actions: actions),
            ]),
          if (step == ReadyStep.moreMonths && current)
            controls([_MonthsChoice(r: r, actions: actions)]),
        ];
      case ReadyStep.health:
      case ReadyStep.retirement:
        final yes = r.answers[step]!;
        final key = step == ReadyStep.health
            ? ReadyKeys.health
            : ReadyKeys.retirement;
        return [
          fact(
            step == ReadyStep.health
                ? (yes ? t.planHealthYes : t.planHealthWhat)
                : (yes ? t.planRetirementYes : t.planRetirementWhat),
          ),
          if (current && step == ReadyStep.retirement)
            guide(t.planEmployerMatch),
          controls([
            _Answer(
              stepKey: step.name,
              yes: yes,
              yesLabel: step == ReadyStep.health ? t.planIHaveIt : t.planIAm,
              onChanged: (v) => actions.setPref(
                key,
                v ? 'yes' : null,
                v
                    ? t.planAnswerYesUndo(_stepTitle(t, step, r))
                    : t.planAnswerNotYetUndo(_stepTitle(t, step, r)),
              ),
            ),
          ]),
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
          for (final d in r.consumerDebts)
            _DebtLine(debt: d, r: r, actions: actions),
          for (final a in data.openAccounts)
            if (a.isOwed &&
                a.role == AccountRole.paidMonthly &&
                a.currency == CurrencyScope.of(context))
              _DebtLine(
                debt: (account: a, owed: -data.balanceOf(a.id)),
                r: r,
                actions: actions,
              ),
        ];
      case ReadyStep.longLoans:
        void answer(String? v, String label) =>
            actions.setPref(ReadyKeys.longLoans, v, label);
        final said = data.prefs[ReadyKeys.longLoans];
        if (!r.longMarked) {
          return [
            fact(r.answers[step]! ? t.planLongNone : t.planLongAsk),
            if (r.consumerDebts.isNotEmpty && !r.answers[step]!)
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
          ];
        }
        return [
          fact(
            r.longLoans.isEmpty
                ? t.planPaidOff
                : t.planAmountLeft(_here(context, r.longOwed)),
          ),
          for (final d in r.longLoans)
            _DebtLine(debt: d, r: r, actions: actions),
          if (r.longLoans.isNotEmpty)
            controls([
              _Answer(
                stepKey: step.name,
                yes: said == 'yes',
                yesLabel: t.planPayingExtra,
                onChanged: (v) => answer(
                  v ? 'yes' : null,
                  v ? t.planPayingExtraUndo : t.planNotPayingExtraUndo,
                ),
              ),
            ]),
        ];
    }
  }
}

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

/// Which bank accounts hold the fund: a menu of them, ticked when marked.
class _FundPicker extends StatelessWidget {
  const _FundPicker({
    required this.data,
    required this.r,
    required this.actions,
  });
  final LedgerData data;
  final Readiness r;
  final _SavingsActions actions;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final banks = data.openAccounts.where((a) => !a.isOwed).toList();
    final main = CurrencyScope.of(context);
    final label = r.fundAccounts.isEmpty
        ? t.planPickAccount
        : t.planKeptIn(_names(t, r.fundAccounts.map((a) => a.name)));
    return MenuAnchor(
      style: _menuStyle,
      menuChildren: [
        for (final a in banks)
          MenuItemButton(
            key: ValueKey('fund-${a.id}'),
            // Savings counts one currency for now: another can't hold the
            // fund until it can be counted, and the line says so.
            onPressed: a.currency != main
                ? null
                : () {
                    final on = a.role == AccountRole.emergencyFund;
                    actions.setRole(
                      a,
                      on ? null : AccountRole.emergencyFund,
                      on ? t.planFundOffUndo(a.name) : t.planFundOnUndo(a.name),
                    );
                  },
            leadingIcon: Icon(
              a.role == AccountRole.emergencyFund ? Icons.check_rounded : null,
              size: 16,
              color: Mid.blue,
            ),
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(240, 34)),
              overlayColor: WidgetStatePropertyAll(Mid.blueWash),
            ),
            child: Text(
              a.currency == main
                  ? '${a.name}  ${_money(data.balanceOf(a.id), a.currency)}'
                  : t.savingsOtherCurrencyItem(
                      a.name,
                      _money(data.balanceOf(a.id), a.currency),
                    ),
              style: onest(
                13,
                color: a.currency == main ? Mid.ink2 : Mid.ink3,
                tabular: true,
              ),
            ),
          ),
      ],
      builder: (context, menu, _) => BarButton(
        key: const ValueKey('fund-picker'),
        label: label,
        trailing: Icons.expand_more_rounded,
        color: r.fundAccounts.isEmpty ? Mid.gold : null,
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
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
        text: m.typed ? formatWhole(m.amount) : '',
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
    final v = parseAmount(text);
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
        color: m.amount == 0 ? Mid.gold : null,
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
                          : formatWhole(m.amount),
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

String _roleWords(Words t, AccountRole? role) => switch (role) {
  AccountRole.mortgage => t.planRoleMortgage,
  AccountRole.studentLoan => t.planRoleStudentLoan,
  AccountRole.paidMonthly => t.planRolePaidMonthly,
  _ => t.planRoleConsumer,
};

/// The undo label for marking [name] as [role].
String _countsAs(Words t, String name, AccountRole? role) => switch (role) {
  AccountRole.mortgage => t.planCountsAsMortgage(name),
  AccountRole.studentLoan => t.planCountsAsStudentLoan(name),
  AccountRole.paidMonthly => t.planCountsAsPaidMonthly(name),
  _ => t.planCountsAsConsumer(name),
};

/// A card or loan, what's owed on it, and what it counts as.
class _DebtLine extends StatelessWidget {
  const _DebtLine({required this.debt, required this.r, required this.actions});
  final Debt debt;
  final Readiness r;
  final _SavingsActions actions;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final a = debt.account;
    final consumer = r.consumerDebts.any((d) => d.account.id == a.id);
    final target = consumer && r.target?.account.id == a.id;
    final carried = r.carriedSince[a.id];
    final line = Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            child: Text(
              a.name,
              style: onest(13, color: Mid.ink2),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 130,
            child: Text(
              debt.owed > 0 ? _here(context, debt.owed) : t.planNothingOwed,
              style: onest(13, color: Mid.ink2, tabular: true),
            ),
          ),
          MenuAnchor(
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
                AccountRole.studentLoan,
              ])
                MenuItemButton(
                  key: ValueKey('debt-${a.id}-${role?.name ?? 'consumer'}'),
                  onPressed: () =>
                      actions.setRole(a, role, _countsAs(t, a.name, role)),
                  leadingIcon: Icon(
                    a.role == role ? Icons.check_rounded : null,
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
                style: onest(
                  12.5,
                  color: hover ? Mid.ink2 : Mid.ink3,
                ).copyWith(decoration: hover ? TextDecoration.underline : null),
              ),
            ),
          ),
          if (target) ...[
            const SizedBox(width: 12),
            Text(
              t.planPayExtraHere,
              key: ValueKey('debt-${a.id}-is-target'),
              style: onest(12.5, color: Mid.blue),
            ),
          ],
        ],
      ),
    );
    if (carried == null) return line;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line,
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            t.planCarried(sayFullDate(t, carried)),
            key: ValueKey('debt-${a.id}-carried'),
            style: onest(12.5, color: Mid.gold, height: 1.4),
          ),
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
