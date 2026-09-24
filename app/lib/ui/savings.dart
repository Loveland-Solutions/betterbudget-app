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
    final r = Readiness.of(data, today);
    return Padding(
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
                      'Savings',
                      style: onest(22, weight: 600, letterSpacing: -0.3),
                    ),
                    const SizedBox(width: 14),
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        r.current == null
                            ? 'Every step is done'
                            : 'Getting prepared, one step at a time',
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                        child: Text(
                          'In the order of Personal Finances for '
                          'Self-Reliance: each step makes the next one safer.',
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
    );
  }
}

String _stepTitle(ReadyStep s, Readiness r) => switch (s) {
  ReadyStep.oneMonth => 'One month of expenses set aside',
  ReadyStep.health => 'Health coverage',
  ReadyStep.consumerDebt => 'No consumer debt',
  ReadyStep.moreMonths => '${r.monthsTarget} months of expenses set aside',
  ReadyStep.retirement => 'Saving for retirement',
  ReadyStep.longLoans => 'Paying off the mortgage and student loans',
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
                        _stepTitle(step, r),
                        style: onest(
                          14.5,
                          weight: current ? 600 : 500,
                          color: aside ? Mid.ink3 : Mid.ink,
                        ),
                      ),
                    ),
                    if (current) ...[
                      const SizedBox(width: 10),
                      Text('Now', style: onest(12, color: Mid.blue)),
                    ],
                    if (aside) ...[
                      const SizedBox(width: 10),
                      Text('Set aside', style: onest(12, color: Mid.ink3)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                ..._body(state),
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
                  ? '“${_stepTitle(step, r)}” set aside'
                  : '“${_stepTitle(step, r)}” back in the steps',
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(ReadyState state) {
    final current = state == ReadyState.current;
    Widget fact(String text, {Key? key, Color color = Mid.ink2}) => Text(
      text,
      key: key,
      style: onest(13, color: color, tabular: true),
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
        final aboutMonth = m.amount == 0
            ? (m.days < MonthOfSpending.minDays
                  ? 'A month of your spending isn’t known yet '
                        '(${m.days} ${m.days == 1 ? 'day' : 'days'} of rows). '
                        'Type it, or come back in a few weeks.'
                  : 'No spending in the last ${m.days} days to go by. '
                        'Type a month of your expenses.')
            : m.typed
            ? 'A month of expenses: ${_money(m.amount)}, as you typed it'
            : 'A month of expenses: ${_money(m.amount)}, the average of '
                  'the last ${m.days >= MonthOfSpending.spanDays ? '3 months' : '${m.days} days'}'
                  '${m.loanPayments > 0 ? ', loan payments included' : ''}';
        final noFund = r.fundAccounts.isEmpty;
        return [
          if (target > 0 && !noFund) ...[
            fact(
              '${_money(r.fund)} of ${_money(target)}'
              '${r.fund >= target ? '' : ' · ${_money(target - r.fund)} to go'}',
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
          if (current && noFund)
            guide(
              'Which account holds it? Pick one below. A savings account you '
              'can reach but don’t spend from works best.',
            ),
          if (current && step == ReadyStep.oneMonth) ...[
            guide(
              'Keep it where you can reach it. If you use it, fill it back up '
              'before anything else.',
            ),
            if (r.consumerDebts.isNotEmpty)
              guide(
                'Until it’s full, pay only the minimums on '
                '${_names(r.consumerDebts.map((d) => d.account.name))}.',
              ),
          ],
          if (current && step == ReadyStep.moreMonths)
            guide('Enough to get through losing a job or a long illness.'),
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
                ? (yes
                      ? 'You have it'
                      : 'Insurance, or some other way to get medical care')
                : (yes
                      ? 'You’re putting money into it'
                      : 'Into a retirement plan, from your pay or on your own'),
          ),
          if (current && step == ReadyStep.retirement)
            guide(
              'If your employer matches what you put in, put in at least '
              'enough to get all of it.',
            ),
          controls([
            _Answer(
              stepKey: step.name,
              yes: yes,
              yesLabel: step == ReadyStep.health ? 'I have it' : 'I am',
              onChanged: (v) => actions.setPref(
                key,
                v ? 'yes' : null,
                v
                    ? '${_stepTitle(step, r)}: yes'
                    : '${_stepTitle(step, r)}: not yet',
              ),
            ),
          ]),
        ];
      case ReadyStep.consumerDebt:
        return [
          fact(
            r.consumerDebts.isEmpty
                ? 'No cards or loans owing'
                : '${_money(r.consumerOwed)} owed',
            key: const ValueKey('step-consumerDebt-owed'),
            color: r.consumerDebts.isEmpty ? Mid.ink2 : Mid.ink,
          ),
          if (current && r.consumerDebts.isNotEmpty)
            guide(
              'Pay extra on one at a time, smallest balance or highest '
              'interest first; both get you there. When one is paid off, '
              'put its payment toward the next.',
            ),
          for (final d in r.consumerDebts)
            _DebtLine(debt: d, r: r, actions: actions),
          for (final a in data.openAccounts)
            if (a.isOwed && a.role == AccountRole.paidMonthly)
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
            fact(
              r.answers[step]!
                  ? 'You have none'
                  : 'Do you have a mortgage or student loans?',
            ),
            if (r.consumerDebts.isNotEmpty && !r.answers[step]!)
              guide('If a loan under No consumer debt is one, mark it there.'),
            controls([
              _Choice(
                key: const ValueKey('answer-longLoans-none'),
                label: 'I have none',
                on: said == 'none',
                onTap: () => answer('none', 'No mortgage or student loans'),
              ),
              _Choice(
                key: const ValueKey('answer-longLoans-yes'),
                label: 'Paying extra on them',
                on: said == 'yes',
                onTap: () => answer('yes', 'Paying extra on loans'),
              ),
              _Choice(
                key: const ValueKey('answer-longLoans-no'),
                label: 'Not yet',
                on: said == null,
                onTap: () => answer(null, 'Loans: not yet'),
              ),
            ]),
          ];
        }
        return [
          fact(r.longLoans.isEmpty ? 'Paid off' : '${_money(r.longOwed)} left'),
          for (final d in r.longLoans)
            _DebtLine(debt: d, r: r, actions: actions),
          if (r.longLoans.isNotEmpty)
            controls([
              _Answer(
                stepKey: step.name,
                yes: said == 'yes',
                yesLabel: 'Paying extra',
                onChanged: (v) => answer(
                  v ? 'yes' : null,
                  v ? 'Paying extra on loans' : 'Not paying extra on loans',
                ),
              ),
            ]),
        ];
    }
  }
}

String _names(Iterable<String> names) {
  final l = names.toList();
  if (l.length < 2) return l.join();
  return '${l.sublist(0, l.length - 1).join(', ')} and ${l.last}';
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
          ? const Icon(Icons.check_rounded, size: 14, color: Mid.green)
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
    final banks = data.openAccounts.where((a) => !a.isOwed).toList();
    final label = r.fundAccounts.isEmpty
        ? 'Pick the account'
        : 'Kept in ${_names(r.fundAccounts.map((a) => a.name))}';
    return MenuAnchor(
      style: _menuStyle,
      menuChildren: [
        for (final a in banks)
          MenuItemButton(
            key: ValueKey('fund-${a.id}'),
            onPressed: () {
              final on = a.role == AccountRole.emergencyFund;
              actions.setRole(
                a,
                on ? null : AccountRole.emergencyFund,
                on
                    ? '${a.name} no longer holds the emergency fund'
                    : '${a.name} holds the emergency fund',
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
              '${a.name}  ${_money(data.balanceOf(a.id))}',
              style: onest(13, color: Mid.ink2, tabular: true),
            ),
          ),
      ],
      builder: (context, menu, _) => BarButton(
        key: const ValueKey('fund-picker'),
        label: label,
        trailing: Icons.expand_more_rounded,
        color: r.fundAccounts.isEmpty ? Mid.gold : Mid.ink2,
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
          'A month of expenses: back to your average',
          toast: true,
        );
      }
      return _close();
    }
    final v = parseAmount(text);
    if (v == null || v <= 0) return setState(() => _wrong = true);
    widget.actions.setPref(
      ReadyKeys.month,
      '$v',
      'A month of expenses: ${_money(v)}',
      toast: true,
    );
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.r.month;
    if (_editing == null) {
      return BarButton(
        key: const ValueKey('month-edit'),
        label: m.amount == 0
            ? 'Type a month of expenses'
            : m.typed
            ? 'Change the month'
            : 'Type your own month',
        color: m.amount == 0 ? Mid.gold : Mid.ink2,
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
                          ? 'A month of expenses'
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
              label: 'Save',
              onTap: _save,
            ),
            if (m.typed)
              Text(
                'Empty goes back to your average',
                style: onest(12, color: Mid.ink3),
              ),
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
          label: '$n months',
          active: r.monthsTarget == n,
          color: r.monthsTarget == n ? Mid.blue : Mid.ink2,
          onTap: () => actions.setPref(
            ReadyKeys.months,
            n == 3 ? null : '$n',
            'Aiming for $n months',
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
        label: 'Not yet',
        active: !yes,
        onTap: () => onChanged(false),
      ),
    ],
  );
}

String _roleWords(AccountRole? role) => switch (role) {
  AccountRole.mortgage => 'Mortgage',
  AccountRole.studentLoan => 'Student loan',
  AccountRole.paidMonthly => 'Paid in full every month',
  _ => 'Consumer debt',
};

/// A card or loan, what's owed on it, and what it counts as.
class _DebtLine extends StatelessWidget {
  const _DebtLine({required this.debt, required this.r, required this.actions});
  final Debt debt;
  final Readiness r;
  final _SavingsActions actions;

  @override
  Widget build(BuildContext context) {
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
              debt.owed > 0 ? _money(debt.owed) : 'nothing owed',
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
                    'Paying extra on ${a.name}',
                    toast: true,
                  ),
                  style: ButtonStyle(
                    minimumSize: const WidgetStatePropertyAll(Size(240, 34)),
                    overlayColor: WidgetStatePropertyAll(Mid.blueWash),
                  ),
                  child: Text(
                    'Pay extra on this one',
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
                  onPressed: () => actions.setRole(
                    a,
                    role,
                    '${a.name} counts as ${_roleWords(role).toLowerCase()}',
                  ),
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
                    _roleWords(role),
                    style: onest(13, color: Mid.ink2),
                  ),
                ),
            ],
            builder: (context, menu, _) => Hoverable(
              key: ValueKey('debt-${a.id}-role'),
              onTap: () => menu.isOpen ? menu.close() : menu.open(),
              builder: (hover) => Text(
                _roleWords(a.role),
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
              'Pay extra here',
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
            'Owed every day since ${fullDate(carried)}: a balance is carrying '
            'over. It’s left out of consumer debt only because it’s marked '
            'paid in full.',
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
            aside ? 'Bring it back' : 'Set this step aside',
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
