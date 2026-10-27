part of 'ledger_screen.dart';

// Step 2's payoff (owner, 2026-10-27; ADR 0004 "Paying off debt: two
// ways"): what goes into each debt a month, what extra can go on top, and
// when smallest first and highest rate first would have it all paid off,
// side by side, the person's pick marked.

/// An open amount field, its Cancel and Save, and lines under it: a click
/// away closes it when nothing was changed, Esc closes it, Enter saves.
class _AmountEditor extends StatelessWidget {
  const _AmountEditor({
    required this.what,
    required this.typed,
    required this.focus,
    required this.hint,
    required this.onSave,
    required this.onClose,
    required this.wrongText,
    required this.onEdited,
    this.extra = const [],
  });

  /// The [_SavingsKeep] key, which also names the field's keys.
  final String what;
  final _Typed typed;
  final FocusNode focus;
  final String hint;
  final VoidCallback onSave;
  final VoidCallback onClose;
  final String wrongText;

  /// Each change to the text, so a red border clears once it's fixed.
  final VoidCallback onEdited;

  /// After Save on the same line: a button, a note.
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return TapRegion(
      groupId: what,
      onTapOutside: (_) {
        if (!typed.changed) onClose();
      },
      child: TextFieldTapRegion(
        child: CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.escape): onClose},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  SizedBox(
                    width: 140,
                    height: 28,
                    child: TextField(
                      key: ValueKey('$what-field'),
                      controller: typed.text,
                      focusNode: focus,
                      style: onest(13, tabular: true),
                      textAlign: TextAlign.right,
                      onSubmitted: (_) => onSave(),
                      onChanged: (_) {
                        if (typed.wrong) {
                          typed.wrong = false;
                          onEdited();
                        }
                      },
                      decoration:
                          _fieldDecoration(
                            hint: hint,
                            wrong: typed.wrong,
                          ).copyWith(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                    ),
                  ),
                  BarButton(
                    key: ValueKey('$what-cancel'),
                    label: t.setupCancel,
                    onTap: onClose,
                  ),
                  BarButton(
                    key: ValueKey('$what-save'),
                    label: t.planSave,
                    color: Mid.blue,
                    onTap: onSave,
                  ),
                  ...extra,
                ],
              ),
              if (typed.wrong)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    wrongText,
                    key: ValueKey('$what-wrong'),
                    style: onest(12.5, color: Mid.coral),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens a [_SavingsKeep] field and puts focus back where it was on close.
mixin _OpensField<W extends StatefulWidget> on State<W> {
  final focus = FocusNode(debugLabel: 'savings-amount');
  final opener = FocusNode(debugLabel: 'savings-amount-link');

  _SavingsKeep get keep;
  String get what;
  _Typed? get typed => keep[what];

  @override
  void initState() {
    super.initState();
    keep.addListener(_changed);
    // Kept open while the page was left: the cursor goes back into it.
    if (typed != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && typed != null) focus.requestFocus();
      });
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    keep.removeListener(_changed);
    focus.dispose();
    opener.dispose();
    super.dispose();
  }

  void open(String start) {
    keep.begin(what, start);
    WidgetsBinding.instance.addPostFrameCallback((_) => focus.requestFocus());
  }

  void close() {
    keep.close(what);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) opener.requestFocus();
    });
  }

  /// What's typed as an amount above zero; null marks the field wrong.
  int? amountTyped(Currency c) {
    final v = parseAmount(typed!.text.text.trim(), c);
    if (v == null || v <= 0) {
      typed!.wrong = true;
      keep.changed();
      return null;
    }
    return v;
  }
}

/// Under a debt's line: what goes into it a month (a link that opens a
/// field), what its rate takes, and a word when that is all of it.
class _DebtPayment extends StatefulWidget {
  const _DebtPayment({
    super.key,
    required this.debt,
    required this.r,
    required this.actions,
  });
  final Debt debt;
  final Readiness r;
  final _SavingsActions actions;

  @override
  State<_DebtPayment> createState() => _DebtPaymentState();
}

class _DebtPaymentState extends State<_DebtPayment>
    with _OpensField<_DebtPayment> {
  AccountInfo get _a => widget.debt.account;

  @override
  _SavingsKeep get keep => widget.actions.keep;

  @override
  String get what => 'pay-${_a.id}';

  bool get _typedHere =>
      widget.r.payments[_a.id]?.from == null &&
      widget.r.payments[_a.id] != null;

  void _start() {
    final p = widget.r.payments[_a.id];
    open(_typedHere ? _typedText(p!.amount, _a.currency) : '');
  }

  void _write(int? v) {
    final t = context.t;
    final had = widget.r.payments[_a.id];
    if (v == null) {
      if (_typedHere) {
        widget.actions.setPref(
          ReadyKeys.pay(_a.id),
          null,
          t.planPayRemoved(_a.name),
          toast: true,
        );
      }
    } else if (!(_typedHere && had!.amount == v)) {
      widget.actions.setPref(
        ReadyKeys.pay(_a.id),
        '$v',
        t.planPaySet(_a.name, _here(context, v)),
        toast: true,
      );
    }
    close();
  }

  void _save() {
    if (typed!.text.text.trim().isEmpty) return _write(null);
    final v = amountTyped(_a.currency);
    if (v != null) _write(v);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final r = widget.r;
    final pay = r.payments[_a.id];
    final interest = r.interestOf(widget.debt);
    final lately = r.paidLately[_a.id];
    final open = typed;
    final link = Hoverable(
      key: ValueKey('debt-${_a.id}-pay'),
      focusNode: opener,
      // Open with something changed, a click keeps it, as a click away
      // does: the cursor goes back into it.
      onTap: open == null
          ? _start
          : open.changed
          ? focus.requestFocus
          : close,
      builder: (hover) => Text(
        pay == null
            ? t.planPayAdd
            : pay.from == null
            ? t.planPays(_here(context, pay.amount))
            : t.planPaysFrom(_here(context, pay.amount), pay.from!.name),
        style: onest(
          12.5,
          color: pay == null ? Mid.blue : (hover ? Mid.ink2 : Mid.ink3),
          tabular: true,
        ).copyWith(decoration: hover ? TextDecoration.underline : null),
      ),
    );
    return Padding(
      // Under what's owed, which it is worked out from.
      padding: const EdgeInsets.only(left: _debtName, top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 2,
            children: [
              TapRegion(groupId: what, child: link),
              if (interest != null)
                Text(
                  t.planInterestAMonth(_interest(context, interest)),
                  key: ValueKey('debt-${_a.id}-interest'),
                  style: onest(12.5, color: Mid.ink3),
                ),
            ],
          ),
          if (pay != null && interest != null && pay.amount <= interest)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _reads - _debtName),
                child: Text(
                  _onlyInterest(
                    t,
                    pay.amount < interest,
                    _here(context, pay.amount),
                  ),
                  key: ValueKey('debt-${_a.id}-only-interest'),
                  style: onest(12.5, color: Mid.ink, height: 1.4),
                ),
              ),
            ),
          if (open != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: _AmountEditor(
                what: what,
                typed: open,
                focus: focus,
                hint: pay == null ? '' : formatWhole(pay.amount, _a.currency),
                onSave: _save,
                onClose: close,
                wrongText: t.planPayWrong,
                onEdited: keep.changed,
                extra: [
                  if (lately != null) ...[
                    Text(
                      t.planPayLately(_here(context, lately)),
                      style: onest(12, color: Mid.ink3),
                    ),
                    BarButton(
                      key: ValueKey('$what-lately'),
                      label: t.planPayUse(_here(context, lately)),
                      onTap: () => _write(lately),
                    ),
                  ],
                  if (_typedHere)
                    Text(
                      t.planPayEmptyToRemove,
                      style: onest(12, color: Mid.ink3),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

extension on _DebtPaymentState {
  /// A payment no bigger than the interest, said as it is: what's owed
  /// grows when it's less. That it goes down once another's payment moves
  /// to it is said only of one behind another in the list, which isn't
  /// getting the extra (reviews).
  String _onlyInterest(Words t, bool below, String amount) {
    final behind = widget.r.debtsInOrder.indexOf(widget.debt) > 0;
    return below
        ? (behind
              ? t.planPayBelowInterestNext(amount)
              : t.planPayBelowInterest(amount))
        : (behind
              ? t.planPayOnlyInterestNext(amount)
              : t.planPayOnlyInterest(amount));
  }
}

/// Extra each month, on top of the payments: what it is, or a field.
class _ExtraField extends StatefulWidget {
  const _ExtraField({required this.r, required this.actions});
  final Readiness r;
  final _SavingsActions actions;

  @override
  State<_ExtraField> createState() => _ExtraFieldState();
}

class _ExtraFieldState extends State<_ExtraField>
    with _OpensField<_ExtraField> {
  @override
  _SavingsKeep get keep => widget.actions.keep;

  @override
  String get what => 'extra';

  void _save() {
    final t = context.t;
    final c = CurrencyScope.of(context);
    final had = widget.r.extra;
    if (typed!.text.text.trim().isEmpty) {
      if (had > 0) {
        widget.actions.setPref(
          ReadyKeys.extra,
          null,
          t.planExtraRemoved,
          toast: true,
        );
      }
      return close();
    }
    final v = amountTyped(c);
    if (v == null) return;
    if (v != had) {
      widget.actions.setPref(
        ReadyKeys.extra,
        // With its currency, as the month of expenses is kept.
        '${c.code}:$v',
        t.planExtraSet(_here(context, v)),
        toast: true,
      );
    }
    close();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final extra = widget.r.extra;
    final open = typed;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        Text(t.planExtraLabel, style: onest(13, color: Mid.ink2)),
        if (open == null)
          BarButton(
            key: const ValueKey('extra-edit'),
            focusNode: opener,
            label: extra > 0 ? _here(context, extra) : t.planExtraNone,
            color: Mid.blue,
            onTap: () => this.open(
              extra > 0 ? _typedText(extra, CurrencyScope.of(context)) : '',
            ),
          )
        else
          _AmountEditor(
            what: what,
            typed: open,
            focus: focus,
            hint: '',
            onSave: _save,
            onClose: close,
            wrongText: t.planPayWrong,
            onEdited: keep.changed,
            extra: [
              if (extra > 0)
                Text(
                  t.planExtraEmptyToRemove,
                  style: onest(12, color: Mid.ink3),
                ),
            ],
          ),
      ],
    );
  }
}

/// When it's all paid off: the two ways side by side, the one picked
/// marked, the difference said once; or what is still needed to say it.
class _Payoff extends StatelessWidget {
  const _Payoff({super.key, required this.r, required this.actions});
  final Readiness r;
  final _SavingsActions actions;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    Widget note(String text, {Key? key, Color? color}) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _reads),
        child: Text(
          text,
          key: key,
          style: onest(13, color: color ?? Mid.ink2, height: 1.4),
        ),
      ),
    );
    final missing = r.missingPayments;
    final small = r.payoff(PayoffMethod.smallest);
    final rate = r.payoff(PayoffMethod.highestRate);
    final rated = r.consumerDebts.length - r.missingRates.length;
    final both = small != null && rate != null && r.methodsDiffer;
    final difference = both ? _difference(context, small, rate) : '';
    // Interest on both cards to the place their difference needs, so the
    // two figures and the sentence agree (budget review).
    final c = CurrencyScope.of(context);
    final gap = both ? (small.interest - rate.interest).abs() : 0;
    final unit = gap == 0 ? 0 : _aboutUnit((gap / c.scale).round());
    String interestOf(int minor) {
      if (unit == 0) return _interest(context, minor);
      final whole = ((minor / c.scale) / unit).round() * unit;
      return formatShort(whole * c.scale, currency: c);
    }

    final dated = small != null && small.months != null;
    final netFirst =
        dated &&
        r.extra > 0 &&
        !r.isDone(ReadyStep.oneMonth) &&
        !r.setAside.contains(ReadyStep.oneMonth);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ExtraField(r: r, actions: actions),
          if (missing.isNotEmpty)
            note(
              t.planPlanNeedsPay(_names(t, missing.map((d) => d.account.name))),
              key: const ValueKey('payoff-needs-pay'),
            )
          else if (both) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _stepWidth),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, m) in PayoffMethod.values.indexed) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: _MethodCard(
                        method: m,
                        plan: m == PayoffMethod.smallest ? small : rate,
                        interest: interestOf,
                        r: r,
                        actions: actions,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (difference.isNotEmpty)
              note(difference, key: const ValueKey('payoff-difference')),
            if (r.picked != null)
              note(
                t.planPlanPicked(r.picked!.account.name),
                key: const ValueKey('payoff-picked'),
              ),
          ] else if (small != null)
            note(
              small.months == null
                  ? t.planPlanNever
                  : small.interest > 0
                  ? t.planPlanOne(
                      _month(context, r, small.months!),
                      _interest(context, small.interest),
                    )
                  : t.planPlanOneNoInterest(_month(context, r, small.months!)),
              key: const ValueKey('payoff-one'),
              color: Mid.ink,
            ),
          if (missing.isEmpty &&
              !both &&
              rated < 2 &&
              r.consumerDebts.length > 1)
            note(t.planPlanNeedRates, key: const ValueKey('payoff-need-rates')),
          // Money spent on a card lately: the dates count none of it.
          if (missing.isEmpty)
            for (final d in r.debtsInOrder)
              if (r.chargedLately[d.account.id] case final v?)
                note(
                  t.planPlanCharged(_here(context, v), d.account.name),
                  key: ValueKey('payoff-charged-${d.account.id}'),
                  color: Mid.ink,
                ),
          if (netFirst)
            note(
              t.planPlanNetFirst,
              key: const ValueKey('payoff-net-first'),
              color: Mid.ink,
            ),
          // Goals ask money each month too: the dates assume the extra as
          // typed (owner, 2026-10-27), so say what may come out of it.
          if (r.extra > 0)
            if (_goalsAsk(context, r) case (final asks, final name)?)
              note(
                name == null
                    ? t.goalsFromExtraMany(_here(context, asks))
                    : t.goalsFromExtraOne(_here(context, asks), name),
                key: const ValueKey('payoff-goals'),
                color: Mid.ink,
              ),
          if (missing.isEmpty && r.missingRates.isNotEmpty && rated > 0)
            note(
              t.planPlanNoRate(
                _names(t, r.missingRates.map((d) => d.account.name)),
              ),
            ),
          if (missing.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(t.planPlanAssume, style: onest(12, color: Mid.ink3)),
            ),
        ],
      ),
    );
  }

  /// One to three sentences: what one way saves, ends sooner, clears first.
  /// Empty when nothing differs that can be said.
  String _difference(BuildContext context, PayoffPlan s, PayoffPlan h) {
    final t = context.t;
    final c = CurrencyScope.of(context);
    final out = <String>[];
    if ((s.months == null) != (h.months == null)) {
      out.add(s.months == null ? t.planOnlyRateEnds : t.planOnlySmallestEnds);
    }
    if (s.months != null && h.months != null) {
      final saved = s.interest - h.interest;
      final about = roundAbout((saved.abs() / c.scale).round());
      if (about > 0) {
        final said = formatShort(about * c.scale, currency: c);
        out.add(saved > 0 ? t.planRateSaves(said) : t.planSmallestSaves(said));
      }
      final sooner = s.months! - h.months!;
      out.add(
        sooner == 0
            ? t.planBothEndSame
            : sooner > 0
            ? t.planRateEndsSooner(sooner)
            : t.planSmallestEndsSooner(-sooner),
      );
    }
    final fs = s.firstIn(r.orderOf(PayoffMethod.smallest));
    final fh = h.firstIn(r.orderOf(PayoffMethod.highestRate));
    if (fs != null && fh != null && fs.month != fh.month) {
      out.add(
        fs.month < fh.month
            ? t.planSmallestFirstSooner(fh.month - fs.month)
            : t.planRateFirstSooner(fs.month - fh.month),
      );
    }
    return out.join(' ');
  }
}

/// What the goals in Savings' currency ask a month while kept up with
/// (not a one-off rest), and the goal's name when there's one; null when
/// none asks anything.
(int, String?)? _goalsAsk(BuildContext context, Readiness r) {
  final currency = CurrencyScope.of(context);
  final asking = [
    for (final g in r.goals)
      if (!g.ready && !g.finished && g.usual > 0 && g.currency == currency) g,
  ];
  if (asking.isEmpty) return null;
  final sum = asking.fold(0, (s, g) => s + g.usual);
  return (sum, asking.length == 1 ? asking.single.category.name : null);
}

/// [months] after the month [r] was worked out in, as said: "June 2028".
String _month(BuildContext context, Readiness r, int months) {
  final t = context.t;
  final d = DateTime(r.today.year, r.today.month + months);
  return t.calendarMonth(monthName(t, d.month), '${d.year}', d.month);
}

/// The place [units] is said to with "about": two figures, so 53,412 is
/// said to the thousand.
int _aboutUnit(int units) {
  var step = 1;
  while (units.abs() / step >= 100) {
    step *= 10;
  }
  return step;
}

/// One way, as a card to click: when, how much interest, which goes first.
class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.method,
    required this.plan,
    required this.interest,
    required this.r,
    required this.actions,
  });
  final PayoffMethod method;
  final PayoffPlan plan;

  /// Interest as both cards say it.
  final String Function(int minor) interest;
  final Readiness r;
  final _SavingsActions actions;

  String _name(int id) =>
      r.consumerDebts.firstWhere((d) => d.account.id == id).account.name;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // A debt picked by hand is neither way: neither card is marked, and
    // either click follows that way instead.
    final on = r.method == method && r.picked == null;
    final smallest = method == PayoffMethod.smallest;
    final order = r.orderOf(method);
    final first = plan.firstIn(order);
    // The first paid off may go by its own payments while the extra goes
    // to another: that one is named too (budget review).
    final extraTo = first != null && order.first != first.id
        ? _name(order.first)
        : null;
    return Hoverable(
      key: ValueKey('method-${method.name}'),
      onTap: () {
        if (on) return;
        actions.setPrefs({
          ReadyKeys.method: smallest ? null : 'rate',
          ReadyKeys.target: null,
        }, smallest ? t.planMethodSmallestUndo : t.planMethodRateUndo);
      },
      builder: (hover) => Container(
        padding: EdgeInsets.all(on ? 13 : 14),
        decoration: BoxDecoration(
          color: Mid.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: on ? Mid.blue : (hover ? Mid.ink3 : Mid.rule),
            width: on ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  on
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: on ? Mid.blue : Mid.ink3,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    smallest ? t.planMethodSmallest : t.planMethodRate,
                    style: onest(14, weight: 600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              plan.months == null
                  ? t.planPlanNever
                  : t.planPlanDone(_month(context, r, plan.months!)),
              style: onest(13, tabular: true),
            ),
            if (plan.months != null) ...[
              const SizedBox(height: 4),
              Text(
                t.planPlanInterest(interest(plan.interest)),
                style: onest(13, color: Mid.ink2, tabular: true),
              ),
            ],
            if (first != null) ...[
              const SizedBox(height: 4),
              Text(
                t.planPlanFirst(
                  _name(first.id),
                  _month(context, r, first.month),
                ),
                style: onest(13, color: Mid.ink2, tabular: true),
              ),
            ],
            if (extraTo != null) ...[
              const SizedBox(height: 4),
              Text(
                t.planPlanExtraTo(extraTo),
                style: onest(13, color: Mid.ink2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
