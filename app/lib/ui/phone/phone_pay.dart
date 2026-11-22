part of 'phone_app.dart';

// Regular income on the phone (#528, owner's pick of sketch A, 2026-11-20):
// the Income page lists each regular income with Edit and ends with Add
// regular income; both open this one page, the computer's pay form on one
// scroll with Cancel and Save pinned under it. A pay is written as the
// computer writes it (`actOnPay` in `data/phone_sync.dart`), with Undo in a
// snack bar. How often is the same answers a category asks (`PlanAnswers`,
// `_CustomRepeatPage`), without Once or Every payday, which are a
// category's.

/// What the page handed back: the act done and what to say about it.
class _PayDone {
  const _PayDone(this.change, this.said);
  final PhoneActed change;
  final String said;
}

/// Opens the pay form for [existing], or a new regular income; after a save
/// or a stop says so with an Undo.
Future<void> _openPay(
  BuildContext context, {
  required PhoneStore store,
  required DateTime today,
  PaySchedule? existing,
}) async {
  final t = context.t;
  final data = store.snapshot.data;
  if (data == null) return;
  if (data.openAccounts.where((a) => !a.isOwed).isEmpty) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          duration: phoneSnackTime,
          backgroundColor: Mid.raised,
          content: Text(
            t.ledgerAddBankAccountFirst,
            style: onest(15, color: Mid.ink),
          ),
        ),
      );
    return;
  }
  final done = await Navigator.of(context).push(
    MaterialPageRoute<_PayDone>(
      builder: (_) => _PayPage(store: store, today: today, existing: existing),
    ),
  );
  if (done == null || !context.mounted) return;
  _saidWithUndo(context, store, done.change, done.said, 'pay-done');
}

/// A snack bar with [said] and an Undo of [change].
void _saidWithUndo(
  BuildContext context,
  PhoneStore store,
  PhoneActed change,
  String said,
  String key,
) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        persist: false,
        duration: phoneSnackTime,
        key: ValueKey(key),
        backgroundColor: Mid.raised,
        content: Text(said, style: onest(15, color: Mid.ink)),
        action: SnackBarAction(
          label: context.t.ledgerUndo,
          textColor: Mid.blue,
          onPressed: () async {
            // An undo the ledger refuses (a row entered since) says so.
            try {
              await store.replay(change.undo);
            } catch (e) {
              debugPrint('Undoing on the phone failed: $e');
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    persist: false,
                    duration: phoneSnackTime,
                    backgroundColor: Mid.raised,
                    content: Text(
                      context.t.ledgerCouldntSave,
                      style: onest(15, color: Mid.ink),
                    ),
                  ),
                );
            }
          },
        ),
      ),
    );
}

/// "I don't have regular income", or Ask me again, from the Income page.
Future<void> _sayNoPay(
  BuildContext context,
  PhoneStore store, {
  required bool none,
}) async {
  final t = context.t;
  final PhoneActed done;
  try {
    done = await store.actRow(PhoneNoPay(none));
  } catch (e) {
    debugPrint('Saying no regular income on the phone failed: $e');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          duration: phoneSnackTime,
          backgroundColor: Mid.raised,
          content: Text(t.ledgerCouldntSave, style: onest(15, color: Mid.ink)),
        ),
      );
    return;
  }
  if (!context.mounted) return;
  _saidWithUndo(
    context,
    store,
    done,
    none ? t.phoneNoRegularPayToast : t.ledgerAskForPayAgainToast,
    'pay-none-done',
  );
}

class _PayPage extends StatefulWidget {
  const _PayPage({required this.store, required this.today, this.existing});
  final PhoneStore store;
  final DateTime today;
  final PaySchedule? existing;

  @override
  State<_PayPage> createState() => _PayPageState();
}

class _PayPageState extends State<_PayPage> with _FormRows<_PayPage> {
  PhoneStore get _store => widget.store;
  LedgerData get _data => _store.snapshot.data!;
  PaySchedule? get _existing => widget.existing;

  late final List<AccountInfo> _accounts = [
    for (final a in _data.openAccounts)
      if (!a.isOwed) a,
  ];
  late AccountInfo _account =
      _accounts.where((a) => a.id == _existing?.accountId).firstOrNull ??
      _accounts.first;
  late final _name = TextEditingController(text: _existing?.name);
  late final _payee = TextEditingController(text: _existing?.payee);
  late bool _varies = _existing?.varies ?? false;

  /// Twice a month with two amounts: [_amount] is the earlier day's and
  /// [_amount2] the later day's.
  late bool _split = _existing?.split ?? false;
  late final _amount = TextEditingController(
    text: _typed(_existing?.byDay.first.amount),
  );
  late final _amount2 = TextEditingController(
    text: _typed(_split ? _existing!.byDay.last.amount : null),
  );
  late final PlanAnswers _how = _initialHow();
  bool _tried = false, _busy = false;
  late final String _opened;

  String _typed(int? v) =>
      v == null ? '' : typedAmount(v, _currencyOf(_existing?.accountId));

  Currency _currencyOf(int? id) =>
      _data.accounts[id]?.currency ??
      _accounts.firstOrNull?.currency ??
      Currency.mnt;

  @override
  Currency get _currency => _account.currency;

  @override
  DateTime get _today => widget.today;

  PlanAnswers _initialHow() {
    final p = PlanAnswers(today: widget.today, currency: _account.currency);
    final e = _existing;
    if (e != null) {
      p.show(e.asPlan(widget.today));
    } else {
      // A new one starts monthly on the 25th, as it always has.
      final t = widget.today;
      var d = DateTime(t.year, t.month, 25);
      if (d.isBefore(DateTime(t.year, t.month, t.day))) {
        d = DateTime(t.year, t.month + 1, 25);
      }
      p.show(
        CategoryPlan(
          categoryId: 0,
          kind: PlanKind.byDate,
          amount: 0,
          start: t,
          due: d,
          everyMonths: 1,
          weekend: PayWeekend.before,
        ),
      );
    }
    return p;
  }

  @override
  void initState() {
    super.initState();
    _how.amount.text = _amount.text;
    _opened = _signature();
    // A new one starts on its name, with the keyboard up; an Edit is read
    // first, so nothing is focused.
    if (_existing == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus('pay-name').requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _payee, _amount, _amount2]) {
      c.dispose();
    }
    _how.dispose();
    _disposeFocuses();
    super.dispose();
  }

  /// Everything the form holds, to tell whether leaving it drops changes.
  String _signature() => [
    _name.text.trim(),
    _payee.text.trim(),
    _account.id,
    _varies,
    _split,
    _amount.text.trim(),
    _amount2.text.trim(),
    _how.repeat.name,
    _how.custom,
    _how.unit.name,
    _how.everyN.text.trim(),
    _how.date.text.trim(),
    _how.dates.text.trim(),
    _how.day1.text.trim(),
    _how.day2.text.trim(),
    _how.weekend.name,
    _how.ends.name,
    _how.endDate.text.trim(),
    _how.endCount.text.trim(),
    [..._how.weekdays]..sort(),
    _how.nthOn,
    _how.nth,
    _how.nthWeekday,
  ].join('|');

  bool get _changed => _signature() != _opened;

  int? get _amountValue => parseAmount(_amount.text, _currency);
  int? get _amount2Value => parseAmount(_amount2.text, _currency);
  bool get _splitting => _split && _how.repeat == PlanRepeat.twice;

  /// The two days of the month, earlier first, when both read.
  (int, int)? get _days {
    final d = _how.typedMonthDays;
    return d == null ? null : (d[0], d[1]);
  }

  /// Twice a month keeps the earlier day's amount as amount2 and the later
  /// day's as amount, the order the computer shows them in.
  ({int amount, int? amount2}) get _plan => (
    amount: _splitting && _days != null ? _amount2Value! : _amountValue!,
    amount2: _splitting && _days != null ? _amountValue : null,
  );

  CategoryPlan? get _draftPlan {
    _how.currency = _currency;
    _how.amount.text = _amount.text;
    return _how.draft(categoryId: 0);
  }

  String _amountMissing(Words t, bool later) => switch (_days) {
    final d? => t.setupAmountMissingOn(payDay(t, later ? d.$2 : d.$1)),
    null => later ? t.setupAmountMissingSecond : t.setupAmountMissingFirst,
  };

  /// What's missing or unreadable, first thing only; null when it can save.
  String? _problemIn(Words t) {
    if (_name.text.trim().isEmpty) return t.setupNameMissing;
    final a = _amountValue;
    if (a == null || a <= 0) {
      return _splitting ? _amountMissing(t, false) : t.setupAmountMissing;
    }
    final b = _amount2Value;
    if (_splitting && (b == null || b <= 0)) return _amountMissing(t, true);
    _how.currency = _currency;
    _how.amount.text = _amount.text;
    return switch (_how.missing) {
      PlanMissing.date ||
      PlanMissing.dates => t.setupWhenPayday(fullDate(widget.today)),
      PlanMissing.days when _how.typedMonthDays == null =>
        _days == null &&
                int.tryParse(_how.day1.text.trim()) ==
                    int.tryParse(_how.day2.text.trim()) &&
                _how.day1.text.trim().isNotEmpty
            ? t.setupTwoDifferentDays
            : t.setupWhichTwoDays,
      PlanMissing.everyN => t.setupHowOftenMissing,
      PlanMissing.endDate || PlanMissing.endCount => t.setupEndsMissing,
      _ => _endsBeforeStart(t),
    };
  }

  String? _endsBeforeStart(Words t) {
    final plan = _draftPlan;
    final end = plan?.endDate;
    if (plan == null || end == null) return null;
    final first = plan.due ?? plan.start;
    return dateOnly(end).isBefore(dateOnly(first)) ? t.setupEndsEarly : null;
  }

  PaySchedule? _preview(Words t) {
    if (_problemIn(t) != null) return null;
    final plan = _draftPlan;
    if (plan == null) return null;
    final shape = PaySchedule.shapeOf(plan);
    return PaySchedule(
      id: 0,
      categoryId: 0,
      accountId: _account.id,
      amount: _plan.amount,
      amount2: _plan.amount2,
      varies: _varies,
      rule: shape.rule,
      day1: shape.day1,
      day2: shape.day2,
      weeks: shape.weeks,
      anchor: shape.anchor,
      repeat: shape.repeat,
      weekend: plan.weekend,
    );
  }

  /// An answer in How often changed: a choice that isn't twice a month is
  /// one amount, the larger of the two staying.
  void _howChanged() => setState(() {
    if (_how.repeat != PlanRepeat.twice && _split) {
      final a = _amountValue, b = _amount2Value;
      if (b != null && (a == null || b > a)) _amount.text = _amount2.text;
      _split = false;
    }
  });

  Future<void> _pickAccount(Words t) async {
    final picked = await _pick<int>(
      t.setupPaidInto,
      [for (final a in _accounts) (a.id, a.name)],
      chosen: _account.id,
      keyPrefix: 'pay-account',
    );
    if (picked == null || !mounted) return;
    setState(() => _account = _accounts.firstWhere((a) => a.id == picked));
  }

  Future<void> _pickRepeat(Words t) async {
    final a = _how;
    String on() => switch (a.repeat) {
      PlanRepeat.twice => 'twice',
      PlanRepeat.dates => 'dates',
      PlanRepeat.every when a.custom => 'custom',
      PlanRepeat.every => '${a.unit.name}-${a.typedEveryN}',
      _ => 'months-1',
    };
    final picked = await _pick<String>(
      t.planHowOften,
      [
        ('weeks-1', t.planRepeatWeeks(1)),
        ('weeks-2', t.planRepeatWeeks(2)),
        ('twice', t.planTwiceAMonth),
        ('months-1', t.planRepeatMonths(1)),
        ('months-3', t.planRepeatMonths(3)),
        ('years-1', t.planRepeatYears(1)),
        ('custom', t.planEveryCustom),
        ('dates', t.planOnDates),
      ],
      chosen: on(),
      keyPrefix: 'pay-repeat',
    );
    if (picked == null || !mounted) return;
    setState(() {
      switch (picked.split('-')) {
        case ['dates']:
          a.repeat = PlanRepeat.dates;
        case ['twice']:
          a.toTwice();
        case ['custom']:
          a.repeat = PlanRepeat.every;
          a.custom = true;
        case [final unit, final n]:
          a.preset(int.parse(n), PlanUnit.values.byName(unit));
      }
    });
    _howChanged();
    if (picked == 'custom') await _openCustom();
  }

  Future<void> _openCustom() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _CustomRepeatPage(answers: _how),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _pickWeekend(Words t) async {
    final picked = await _pick(
      t.setupOnWeekend,
      [for (final w in PayWeekend.values) (w, planWeekendLabel(t, w))],
      chosen: _how.weekend,
      keyPrefix: 'pay-weekend',
    );
    if (picked != null && mounted) setState(() => _how.weekend = picked);
  }

  String _customSays(Words t, PlanAnswers a) {
    final every = planEveryLabel(t, a.typedEveryN ?? 1, a.unit);
    if (a.weekdaysNow case final days?) {
      final initials = t.rowsWeekdayInitials.split('|');
      return '$every · ${[for (final d in days) initials[d - 1]].join(' ')}';
    }
    if (a.nthNow) {
      return '$every · ${planNthLabel(t, a.nth)} '
          '${planWeekdayName(t, a.nthWeekday)}';
    }
    return every;
  }

  // ---------- saving, stopping, leaving ----------

  Future<void> _save() async {
    final t = context.t;
    if (_busy) return;
    if (_problemIn(t) != null) {
      // Said, not stopped: the line above Save says what is missing, and a
      // missing name takes the cursor.
      setState(() => _tried = true);
      if (_name.text.trim().isEmpty) _focus('pay-name').requestFocus();
      return;
    }
    final plan = _draftPlan;
    if (plan == null) return;
    final shape = PaySchedule.shapeOf(plan);
    final act = PhoneSavePay(_existing?.id, (
      accountId: _account.id,
      name: _name.text,
      payee: _payee.text,
      amount: _plan.amount,
      amount2: _plan.amount2,
      varies: _varies,
      rule: shape.rule,
      day1: shape.day1,
      day2: shape.day2,
      weeks: shape.weeks,
      anchor: shape.anchor,
      repeat: shape.repeat,
      weekend: plan.weekend,
    ));
    setState(() => _busy = true);
    final PhoneActed done;
    try {
      done = await _store.actRow(act);
    } catch (e) {
      debugPrint('Saving a regular income on the phone failed: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            persist: false,
            duration: phoneSnackTime,
            key: const ValueKey('pay-refused'),
            backgroundColor: Mid.raised,
            content: Text(
              t.ledgerCouldntSave,
              style: onest(15, color: Mid.ink),
            ),
          ),
        );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(
      _PayDone(
        done,
        [
          t.ledgerPaySaved,
          if (act.replaced > 0) t.ledgerPayReplaced(act.replaced),
        ].join(' · '),
      ),
    );
  }

  /// Stop counting on this income: says what will happen, with this
  /// income's own figures, then goes ahead (warn, don't block), with Undo.
  Future<void> _stop() async {
    final t = context.t;
    final p = _existing!;
    final per = [
      for (final c in _data.categories)
        if (_data.plans[c.id]?.payScheduleId == p.id) c,
    ];
    final title = payTitle(t, _data, p);
    final next = p.nextAfter(widget.today);
    final money = formatShort(
      p.amountOn(next == payNever ? widget.today : next),
      currency: _currency,
    );
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('stop-pay-ask'),
        backgroundColor: Mid.panel,
        title: Text(t.stopPayTitle, style: onest(18, weight: 600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              next == payNever
                  ? t.phoneStopPayNoNext(title)
                  : t.phoneStopPayNext(title, money, shortDate(next)),
              style: onest(15),
            ),
            if (per.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                t.stopPayPerIt(
                  per.length,
                  [for (final c in per) c.name].join(', '),
                ),
                style: onest(14, color: Mid.ink2),
              ),
              const SizedBox(height: 6),
              Text(t.phoneStopPayMonth, style: onest(14, color: Mid.ink2)),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('stop-pay-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.setupCancel),
          ),
          TextButton(
            key: const ValueKey('stop-pay-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Mid.coral),
            child: Text(t.setupStopPay),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final PhoneActed done;
    try {
      done = await _store.actRow(PhoneStopPay(p.id));
    } catch (e) {
      debugPrint('Stopping a regular income on the phone failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            persist: false,
            duration: phoneSnackTime,
            backgroundColor: Mid.raised,
            content: Text(
              t.ledgerCouldntSave,
              style: onest(15, color: Mid.ink),
            ),
          ),
        );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(
      _PayDone(
        done,
        per.isEmpty
            ? t.ledgerPayStoppedToast
            : t.ledgerPayStoppedMoved(per.length, t.planRepeatMonths(1)),
      ),
    );
  }

  /// Going back with changes asks first; leaving is one tap (warn, don't
  /// block). An untouched form just closes.
  Future<void> _leave() async {
    final t = context.t;
    if (!_changed) {
      Navigator.of(context).pop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('pay-leave-ask'),
        backgroundColor: Mid.panel,
        title: Text(t.phoneLeaveAsk, style: onest(18, weight: 600)),
        actions: [
          TextButton(
            key: const ValueKey('pay-keep-editing'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.phoneKeepEditing),
          ),
          TextButton(
            key: const ValueKey('pay-leave'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.phoneLeaveIt),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  String _dayText(Words t, DateTime? d) => switch (d) {
    final d? => d.year == widget.today.year ? sayDate(t, d) : sayFullDate(t, d),
    null => '',
  };

  /// The label beside one payday's amount: "On the 10th", or "At least on
  /// the 10th" when pay varies; before the days are in, "On the first
  /// payday".
  String _onDay(Words t, bool later) {
    if (_days case final d?) {
      final day = payDay(t, later ? d.$2 : d.$1);
      return _varies ? t.setupAtLeastOnDay(day) : t.setupOnDay(day);
    }
    return switch ((later, _varies)) {
      (false, false) => t.setupOnFirst,
      (true, false) => t.setupOnSecond,
      (false, true) => t.setupAtLeastOnFirst,
      (true, true) => t.setupAtLeastOnSecond,
    };
  }

  /// How often, the days or dates, the weekend rule, and Ends.
  List<Widget> _howOften(Words t) {
    final a = _how;
    final missing = _tried ? a.missing : null;
    final rows = <Widget>[
      _choiceRow(
        'pay-repeat',
        t.planHowOften,
        planRepeatLabel(t, _data, a),
        () => _pickRepeat(t),
      ),
      if (a.customOn)
        _choiceRow(
          'pay-custom',
          t.planRepeatEvery,
          _customSays(t, a),
          _openCustom,
          wrong: missing == PlanMissing.everyN,
        ),
      if (a.repeat == PlanRepeat.twice) ...[
        _fieldRow(
          'pay-day1',
          t.planFirstDay,
          a.day1,
          number: true,
          wrong: missing == PlanMissing.days,
        ),
        _fieldRow(
          'pay-day2',
          t.planSecondDay,
          a.day2,
          number: true,
          wrong: missing == PlanMissing.days,
        ),
      ] else if (a.repeat == PlanRepeat.dates)
        _fieldRow(
          'pay-dates',
          t.planDatesLabel,
          a.dates,
          wrong: missing == PlanMissing.dates,
          hint: t.planDatesHint,
        )
      else
        _choiceRow(
          'pay-date',
          t.setupFirstPayday,
          _dayText(t, a.typedDate),
          () async {
            final d = await _pickDay(a.typedDate);
            if (d != null && mounted) {
              setState(() => a.date.text = fullDate(d));
            }
          },
          wrong: missing == PlanMissing.date,
        ),
      if (a.weekdaysNow == null)
        _choiceRow(
          'pay-weekend',
          t.setupOnWeekend,
          planWeekendLabel(t, a.weekend),
          () => _pickWeekend(t),
        ),
    ];
    return [
      _card(rows),
      if (a.endsOn) ...[
        const SizedBox(height: 14),
        _card([
          _asked(
            t.planEnds,
            _choices([
              for (final (e, label) in [
                (PlanEnds.never, t.planEndsNever),
                (PlanEnds.date, t.planEndsOn),
                (PlanEnds.count, t.planEndsAfter),
              ])
                (
                  'pay-ends-${e.name}',
                  label,
                  a.ends == e,
                  () => setState(() => a.ends = e),
                ),
            ]),
          ),
          if (a.ends == PlanEnds.date)
            _choiceRow(
              'pay-end-date',
              t.planEndsOn,
              a.typedEndDate == null ? '' : sayFullDate(t, a.typedEndDate!),
              () async {
                final d = await _pickDay(a.typedEndDate ?? a.typedDate);
                if (d != null && mounted) {
                  setState(() => a.endDate.text = fullDate(d));
                }
              },
              wrong: missing == PlanMissing.endDate,
            ),
          if (a.ends == PlanEnds.count)
            _fieldRow(
              'pay-end-count',
              t.planEndsAfter,
              a.endCount,
              number: true,
              wrong: missing == PlanMissing.endCount,
              after: t.planEndsTimes,
            ),
        ]),
      ],
    ];
  }

  Widget _amounts(Words t) {
    final twice = _how.repeat == PlanRepeat.twice;
    return _card([
      _asked(
        t.setupPayIs,
        _choices([
          (
            'pay-same',
            t.setupPaySame,
            !_varies,
            () => setState(() => _varies = false),
          ),
          (
            'pay-varies',
            t.setupPayVaries,
            _varies,
            () => setState(() => _varies = true),
          ),
        ]),
      ),
      if (twice)
        _choices([
          (
            'pay-one-amount',
            t.setupSameEachPaycheck,
            !_split,
            () => setState(() => _split = false),
          ),
          (
            'pay-two-amounts',
            t.setupDifferentEachPaycheck,
            _split,
            () => setState(() => _split = true),
          ),
        ]),
      if (_splitting) ...[
        _fieldRow(
          'pay-amount',
          _onDay(t, false),
          _amount,
          money: true,
          action: TextInputAction.next,
        ),
        _fieldRow(
          'pay-amount2',
          _onDay(t, true),
          _amount2,
          money: true,
          action: TextInputAction.done,
        ),
      ] else
        _fieldRow(
          'pay-amount',
          _varies ? t.setupExpectAtLeast : t.setupEachPayday,
          _amount,
          money: true,
          action: TextInputAction.done,
        ),
    ]);
  }

  /// The line above Save: what's missing (coral once Save was tried), else
  /// the next payday as the computer's form says it.
  String? _summary(Words t) {
    final problem = _problemIn(t);
    if (problem != null) return _tried ? problem : null;
    final preview = _preview(t);
    if (preview == null) return null;
    final next = preview.nextAfter(widget.today);
    if (next == payNever) return null;
    String money(int v) => formatShort(v, currency: _currency);
    final date = sayFullDate(t, next);
    final amount = money(preview.amountOn(next));
    final monthly = preview.rule == PayRule.monthly;
    return switch ((_varies, monthly)) {
      (false, true) => t.setupNextPayday(date, amount),
      (true, true) => t.setupNextPaydayOrMore(date, amount),
      (false, false) => t.setupNextPaydayMonthly(
        date,
        amount,
        money(preview.perMonth),
      ),
      (true, false) => t.setupNextPaydayOrMoreMonthly(
        date,
        amount,
        money(preview.perMonth),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: ListenableBuilder(
        listenable: Listenable.merge([
          _name,
          _payee,
          _amount,
          _amount2,
          _how.typing,
        ]),
        builder: (context, _) {
          final summary = _summary(t);
          final wrong = _tried && _problemIn(t) != null;
          return Scaffold(
            backgroundColor: Mid.ground,
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
              backgroundColor: Mid.ground,
              foregroundColor: Mid.ink,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: BackButton(onPressed: () => unawaited(_leave())),
              title: Text(
                _existing != null
                    ? t.setupYourPay
                    : _data.paySchedules.isEmpty
                    ? t.setupAddYourPay
                    : t.setupAddOtherPay,
                style: onest(20, weight: 600),
              ),
            ),
            body: ListView(
              key: const ValueKey('pay-page'),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                _card([
                  _fieldRow(
                    'pay-name',
                    t.setupName,
                    _name,
                    text: true,
                    hint: t.setupNameHint,
                    wrong: _tried && _name.text.trim().isEmpty,
                    action: TextInputAction.next,
                  ),
                  _fieldRow(
                    'pay-payee',
                    t.setupFrom,
                    _payee,
                    text: true,
                    action: TextInputAction.next,
                  ),
                  _choiceRow(
                    'pay-account',
                    t.setupPaidInto,
                    _account.name,
                    () => _pickAccount(t),
                  ),
                ]),
                const SizedBox(height: 14),
                ..._howOften(t),
                const SizedBox(height: 14),
                _amounts(t),
                _aside(t.setupAmountDeposited),
                if (_existing != null) ...[
                  const SizedBox(height: 14),
                  _card([
                    InkWell(
                      key: const ValueKey('pay-stop'),
                      onTap: _stop,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 52),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              t.setupStopPay,
                              style: onest(16, weight: 500, color: Mid.coral),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ],
              ],
            ),
            bottomNavigationBar: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Mid.panel,
                  border: Border(top: BorderSide(color: Mid.rule)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (summary != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          summary,
                          key: const ValueKey('pay-summary'),
                          style: onest(
                            13.5,
                            color: wrong ? Mid.coral : Mid.ink2,
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            key: const ValueKey('pay-cancel'),
                            onPressed: () => unawaited(_leave()),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              foregroundColor: Mid.ink2,
                              textStyle: onest(16, weight: 500),
                            ),
                            child: Text(t.setupCancel),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            key: const ValueKey('pay-save'),
                            onPressed: _save,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              backgroundColor: Mid.green,
                              foregroundColor: Colors.white,
                              textStyle: onest(16, weight: 600),
                            ),
                            child: Text(t.setupSavePay),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
