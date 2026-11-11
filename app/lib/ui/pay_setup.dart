part of 'ledger_screen.dart';

// Putting in pay (ADR 0004, rule 24): when it comes, how much, into which
// account. Pay that varies is entered as the least it's likely to be, since
// the forecast counts on it: finding more on payday beats finding less.

/// What the pay setup saves.
typedef PayDraft = ({
  int accountId,
  String? name,
  String? payee,
  int amount,
  int? amount2,
  bool varies,
  PayRule rule,
  int day1,
  int day2,
  int weeks,
  DateTime anchor,
  PayRepeat? repeat,
  PayWeekend weekend,
});

/// The setup's answer: save this, or stop the schedule.
sealed class PaySetupResult {
  const PaySetupResult();
}

class PaySave extends PaySetupResult {
  const PaySave(this.draft);
  final PayDraft draft;
}

class PayStop extends PaySetupResult {
  const PayStop({this.movePlans = false, this.moveTo});

  /// Categories budgeted per this pay move to [moveTo]'s periods, or to
  /// the month with null (owner, 2026-10-05: warn, and offer to move
  /// them). False when nothing was per it.
  final bool movePlans;
  final int? moveTo;
}

/// "I don't have regular pay": stop asking for it.
class PayNone extends PaySetupResult {
  const PayNone();
}

/// The pay form in a dialog: from the forecast's "Add your pay", or the
/// Budget page's Income tab. It closes with a [PaySetupResult], or null.
class _PaySetupDialog extends StatelessWidget {
  const _PaySetupDialog({required this.form});

  /// Builds the form around what its buttons do here: close the dialog.
  final _PayForm Function(
    ValueChanged<PaySetupResult> onResult,
    VoidCallback onCancel,
  )
  form;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Mid.panel,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: Mid.rule),
    ),
    child: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
        child: form(
          (result) => Navigator.of(context).pop(result),
          () => Navigator.of(context).pop(),
        ),
      ),
    ),
  );
}

/// The pay form itself: in [_PaySetupDialog], or on setup's Pay step
/// ([page]), where the page has the heading.
class _PayForm extends StatefulWidget {
  const _PayForm({
    super.key,
    required this.accounts,
    required this.category,
    required this.account,
    required this.today,
    required this.history,
    required this.data,
    required this.onResult,
    this.onCancel,
    this.page = false,
    this.existing,
    this.perPay = const [],
    this.offerNoPay = false,
  });

  /// Save, stop, or "I don't have regular pay".
  final ValueChanged<PaySetupResult> onResult;

  /// Closes the form with nothing changed. Null when there is nothing to
  /// go back to: setup's first pay.
  final VoidCallback? onCancel;

  /// On setup's page, not in a dialog.
  final bool page;

  /// There's no pay anywhere yet: offer "I don't have regular pay".
  final bool offerNoPay;

  /// The ledger, for the other pays' names.
  final LedgerData data;

  /// Categories whose plan is per [existing]: a set amount each of its pay
  /// periods, or a bill every payday of it. Stopping asks where they go.
  final List<AccountInfo> perPay;

  /// Accounts pay can go into.
  final List<AccountInfo> accounts;

  /// Income, which pay is filed under. Null in a new ledger, where it's
  /// made with the first pay; only the preview here reads it.
  final AccountInfo? category;
  final AccountInfo account;
  final DateTime today;
  final PaySchedule? existing;

  /// Recent pay into an account from a payer, newest first.
  final Future<List<int>> Function(int accountId, String payee) history;

  @override
  State<_PayForm> createState() => _PayFormState();
}

class _PayFormState extends State<_PayForm> {
  late AccountInfo _account = widget.account;
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _payee = TextEditingController(text: widget.existing?.payee);

  /// Twice a month with two amounts: [_amount] is the earlier day's, and
  /// [_amount2] the later day's.
  late bool _split = widget.existing?.split ?? false;
  late final _amount = TextEditingController(
    text: _typed(widget.existing?.byDay.first.amount),
  );
  late final _amount2 = TextEditingController(
    text: _typed(_split ? widget.existing!.byDay.last.amount : null),
  );

  String _typed(int? v) =>
      v == null ? '' : typedAmount(v, widget.account.currency);
  late bool _varies = widget.existing?.varies ?? false;

  /// When: "No set day" (owner, 2026-10-28, #175), for pay that comes when
  /// it comes. Saving it is "I don't have regular pay": nothing is
  /// scheduled. Only where that's offered: a new pay.
  bool _noDay = false;
  bool get _offersNoDay => widget.existing == null && widget.offerNoPay;

  /// How often it comes: the answers a category's How often asks, from the
  /// same widget (#438). [shapeOf] keeps what they come to.
  late final PlanAnswers _how = _initialHow();
  final _menus = _HowOftenMenus();
  final _dateFocus = FocusNode(debugLabel: 'pay-date');
  final _amountFocus = FocusNode(debugLabel: 'pay-amount');
  List<int> _history = const [];

  PlanAnswers _initialHow() {
    final p = PlanAnswers(
      today: widget.today,
      currency: widget.account.currency,
    );
    final e = widget.existing;
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
    // On the page the register holds the keys, so autofocus doesn't take.
    if (widget.page && widget.existing == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _amountFocus.requestFocus();
      });
    }
    _loadHistory();
    _how.amount.text = _amount.text;
    _amount.addListener(() {
      // How often's answers read the amount typed here.
      if (_how.amount.text != _amount.text) _how.amount.text = _amount.text;
      setState(() {});
    });
    _amount2.addListener(() => setState(() {}));
    _how.typing.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_name, _payee, _amount, _amount2]) {
      c.dispose();
    }
    _how.dispose();
    _dateFocus.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final payee = _payee.text.trim();
    final h = await widget.history(_account.id, payee);
    // The answer to an older question: the payer was typed on since.
    if (mounted && payee == _payee.text.trim()) setState(() => _history = h);
  }

  int? get _amountValue => parseAmount(_amount.text, _account.currency);

  /// Back to one amount (the same both days, or another rule): the larger
  /// of the two stays, since the advance alone would undercount pay.
  void _oneAmount() {
    if (!_split) return;
    final a = _amountValue, b = _amount2Value;
    if (b != null && (a == null || b > a)) _amount.text = _amount2.text;
    _split = false;
  }

  int? get _amount2Value => parseAmount(_amount2.text, _account.currency);
  bool get _splitting => _split && _how.repeat == PlanRepeat.twice;

  /// The two days of the month, earlier first, when both read.
  (int, int)? get _days {
    final d = _how.typedMonthDays;
    return d == null ? null : (d[0], d[1]);
  }

  /// The label beside one payday's amount: "On the 10th" or, before the
  /// days are in, "On the first payday"; "At least, on …" when pay varies.
  String _onDay(Words t, bool later) {
    final atLeast = _varies;
    if (_days case final d?) {
      final day = payDay(t, later ? d.$2 : d.$1);
      return atLeast ? t.setupAtLeastOnDay(day) : t.setupOnDay(day);
    }
    return switch ((later, atLeast)) {
      (false, false) => t.setupOnFirst,
      (true, false) => t.setupOnSecond,
      (false, true) => t.setupAtLeastOnFirst,
      (true, true) => t.setupAtLeastOnSecond,
    };
  }

  /// Asks for one payday's amount, named as [_onDay] names it.
  String _amountMissing(Words t, bool later) => switch (_days) {
    final d? => t.setupAmountMissingOn(payDay(t, later ? d.$2 : d.$1)),
    null => later ? t.setupAmountMissingSecond : t.setupAmountMissingFirst,
  };

  /// What's saved for the amounts: twice a month keeps the earlier day's
  /// as amount2 and the later day's as amount, the order the setup shows
  /// them in.
  ({int amount, int? amount2}) get _plan => (
    amount: _splitting && _days != null ? _amount2Value! : _amountValue!,
    amount2: _splitting && _days != null ? _amountValue : null,
  );

  /// The plan the answers make: how often, from when, the weekend rule.
  CategoryPlan? get _draftPlan {
    _how.currency = _account.currency;
    return _how.draft(categoryId: widget.category?.id ?? 0);
  }

  /// What's missing or unreadable, first thing only; null when it can save.
  String? get _problem => _problemIn(context.t);

  String? _problemIn(Words t) {
    if (_noDay) return null;
    // Every paycheck has a name (owner, 2026-10-28: "they should name
    // every paycheck").
    if (_name.text.trim().isEmpty) return t.setupNameMissing;
    final a = _amountValue;
    if (a == null || a <= 0) {
      return _splitting ? _amountMissing(t, false) : t.setupAmountMissing;
    }
    final b = _amount2Value;
    if (_splitting && (b == null || b <= 0)) {
      return _amountMissing(t, true);
    }
    _how.currency = _account.currency;
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
      _ => null,
    };
  }

  PaySchedule? get _preview {
    if (_problem != null) return null;
    final plan = _draftPlan;
    if (plan == null) return null;
    final shape = PaySchedule.shapeOf(plan);
    return PaySchedule(
      id: 0,
      categoryId: widget.category?.id ?? 0,
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

  /// Stop this pay. With categories budgeted per it, first say so and
  /// ask where they go: another pay, or the month (warn, don't block).
  Future<void> _stop() async {
    if (widget.perPay.isEmpty) {
      widget.onResult(const PayStop());
      return;
    }
    final others = [
      for (final p in widget.data.paySchedules)
        if (p.id != widget.existing!.id) p,
    ];
    final picked = await showDialog<_StopPayChoice>(
      context: context,
      builder: (_) => _StopPayDialog(
        data: widget.data,
        categories: widget.perPay,
        others: others,
        // One other pay: the likely answer. More, or none: the month.
        initial: others.length == 1 ? others.single.id : null,
      ),
    );
    if (picked == null || !mounted) return;
    widget.onResult(PayStop(movePlans: true, moveTo: picked.payId));
  }

  void _save() {
    if (_noDay) return widget.onResult(const PayNone());
    if (_problem != null) return;
    final plan = _draftPlan;
    if (plan == null) return;
    final shape = PaySchedule.shapeOf(plan);
    widget.onResult(
      PaySave((
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
      )),
    );
  }

  /// An answer in How often changed: picking any of its choices ends "No
  /// set day", and a choice that isn't twice a month is one amount.
  void _howChanged() => setState(() {
    if (_noDay && _how.repeat != PlanRepeat.once) _noDay = false;
    if (_how.repeat != PlanRepeat.twice) _oneAmount();
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    String money(int v) => formatShort(v, currency: _account.currency);
    final amount = _amountValue;
    final lowest = _history.isEmpty
        ? null
        : _history.reduce((a, b) => a < b ? a : b);
    final highest = _history.isEmpty
        ? null
        : _history.reduce((a, b) => a > b ? a : b);
    // Split pay's history mixes advances and the rest: no one amount to
    // hold it against.
    final above = amount == null || _splitting
        ? 0
        : _history.where((h) => h < amount).length;
    final preview = _preview;
    final next = preview?.nextAfter(
      widget.today.subtract(const Duration(days: 1)),
    );

    Widget choice(
      String label,
      bool on,
      VoidCallback onTap,
      String key,
    ) => Hoverable(
      key: ValueKey(key),
      onTap: onTap,
      builder: (hover) => Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: on ? Mid.blueWash : (hover ? Mid.raised : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: on ? Mid.blue : Mid.ink2.withValues(alpha: 0.3),
          ),
        ),
        // Sized to the label: in a Wrap a centred Container fills the row.
        child: Center(
          widthFactor: 1,
          child: Text(label, style: onest(13, color: on ? Mid.ink : Mid.ink2)),
        ),
      ),
    );

    Widget amountField(
      TextEditingController c,
      String key, {
      bool autofocus = false,
    }) => Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 180,
        height: 30,
        child: TextField(
          key: ValueKey(key),
          controller: c,
          inputFormatters: [GroupedAmount(_account.currency)],
          focusNode: autofocus ? _amountFocus : null,
          autofocus: autofocus && widget.existing == null,
          textAlign: TextAlign.right,
          style: onest(13.5, tabular: true),
          decoration: _fieldDecoration(
            hint: formatRounded(0, currency: _account.currency),
          ),
        ),
      ),
    );

    Widget pick(
      List<AccountInfo> from,
      AccountInfo value,
      ValueChanged<AccountInfo> onPicked,
      String key,
    ) => CategoryMenu(
      categories: from,
      current: value.name,
      onPicked: onPicked,
      builder: (open, toggle) => BarButton(
        key: ValueKey(key),
        label: value.name,
        trailing: Icons.expand_more_rounded,
        active: open,
        onTap: toggle,
      ),
    );

    Widget line(String label, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            height: 30,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(label, style: onest(13.5, color: Mid.ink3)),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );

    Widget hint(String text, {Color? color, Key? key}) => Padding(
      padding: const EdgeInsets.only(left: 120, bottom: 10),
      child: Text(
        text,
        key: key,
        style: onest(12.5, color: color ?? Mid.ink3),
      ),
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _save,
        // In a dialog Esc is the dialog's own.
        if (widget.page)
          const SingleActivator(LogicalKeyboardKey.escape): ?widget.onCancel,
      },
      // A click anywhere else in the form closes the date's calendar,
      // which otherwise sits over Save.
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: _withCard(
          t,
          preview,
          next,
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.page) ...[
                Text(
                  widget.existing == null ? t.setupAddYourPay : t.setupYourPay,
                  style: onest(17, weight: 600, letterSpacing: -0.2),
                ),
                const SizedBox(height: 16),
              ],
              // Whose pay (owner, 2026-10-05: two earners): the name
              // the Budget page's view and a category's "How often"
              // call it by.
              line(
                t.setupName,
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 260,
                    height: 30,
                    child: TextField(
                      key: const ValueKey('pay-name'),
                      controller: _name,
                      style: onest(13.5),
                      decoration: _fieldDecoration(hint: t.setupNameHint),
                    ),
                  ),
                ),
              ),
              line(
                t.setupPaidInto,
                Align(
                  alignment: Alignment.centerLeft,
                  child: pick(widget.accounts, _account, (a) {
                    setState(() => _account = a);
                    _loadHistory();
                  }, 'pay-account'),
                ),
              ),
              line(
                t.setupFrom,
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 260,
                    height: 30,
                    child: TextField(
                      key: const ValueKey('pay-payee'),
                      controller: _payee,
                      style: onest(13.5),
                      decoration: _fieldDecoration(hint: t.setupEmployerHint),
                    ),
                  ),
                ),
              ),
              line(
                t.setupPayIs,
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    choice(
                      t.setupPaySame,
                      !_varies,
                      () => setState(() => _varies = false),
                      'pay-same',
                    ),
                    choice(
                      t.setupPayVaries,
                      _varies,
                      () => setState(() => _varies = true),
                      'pay-varies',
                    ),
                  ],
                ),
              ),
              if (_varies) hint(t.setupVariesHint),
              line(
                // Each payday, not the month: twice a month is two of these.
                _splitting
                    ? _onDay(t, false)
                    : _varies
                    ? t.setupExpectAtLeast
                    : t.setupEachPayday,
                amountField(_amount, 'pay-amount', autofocus: true),
              ),
              if (_splitting)
                line(_onDay(t, true), amountField(_amount2, 'pay-amount2')),
              // Typed before tax or before a salary loan comes off, the
              // forecast is too rich every payday (ADR 0004,
              // "Onboarding"). Said in setup, to someone new to it.
              if (widget.page && !_account.isCash)
                hint(t.setupPayArrives, key: const ValueKey('pay-arrives')),
              // Twice a month: an advance one day, the rest the other.
              if (_how.repeat == PlanRepeat.twice)
                Padding(
                  padding: const EdgeInsets.only(left: 120, bottom: 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      choice(
                        t.setupSameEachPaycheck,
                        !_split,
                        () => setState(_oneAmount),
                        'pay-amount-same',
                      ),
                      choice(
                        t.setupDifferentEachPaycheck,
                        _split,
                        () => setState(() => _split = true),
                        'pay-amount-split',
                      ),
                    ],
                  ),
                ),
              if (lowest != null)
                hint(
                  _history.length == 1
                      ? t.setupLastPaycheck(money(lowest))
                      : t.setupLastPaychecks(
                          _history.length,
                          money(lowest),
                          money(highest!),
                        ),
                  key: const ValueKey('pay-history'),
                ),
              if (_varies) hint(t.setupLowEndSafer),
              // Warn, don't block: a higher estimate still saves.
              if (_varies && above > 0)
                hint(
                  t.setupHigherThan(above, _history.length),
                  color: Mid.note,
                  key: const ValueKey('pay-high'),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _HowOftenRows(
                  p: _how,
                  data: widget.data,
                  today: widget.today,
                  tried: false,
                  menus: _menus,
                  onSave: _save,
                  onChanged: _howChanged,
                  dateFocus: _dateFocus,
                  offerOnce: false,
                  offerPayday: false,
                  labelWidth: 120,
                  dateLabel: t.setupFirstPayday,
                  daysLabel: t.setupPaydays,
                  showRest: !_noDay,
                  repeatLabel: _noDay ? t.setupNoSetDay : null,
                  extra: [
                    if (_offersNoDay)
                      (
                        key: 'pay-no-day',
                        label: t.setupNoSetDay,
                        on: _noDay,
                        onTap: () => setState(() {
                          _oneAmount();
                          _noDay = true;
                          // "Once" isn't a choice here: it marks this one.
                          _how.repeat = PlanRepeat.once;
                        }),
                      ),
                  ],
                ),
              ),
              // Both days past the 28th meet in short months: one
              // payday then, which is worth knowing before it happens.
              if (!_noDay &&
                  _how.repeat == PlanRepeat.twice &&
                  (_days?.$1 ?? 0) >= 28)
                hint(
                  t.setupDaysMeet,
                  color: Mid.note,
                  key: const ValueKey('pay-days-meet'),
                ),
              if (!_noDay && preview != null && preview.perYear > 24)
                hint(
                  t.setupPaydaysAYear(preview.perYear),
                  key: const ValueKey('pay-26'),
                ),
              const SizedBox(height: 4),
              // On setup's page the card beside the form says what comes
              // and when, so this line speaks only when something's wrong
              // (owner, 2026-11-11, #323: "drop it").
              if (!widget.page || _noDay || _problem != null)
                Padding(
                  padding: const EdgeInsets.only(left: 120),
                  child: Text(
                    _noDay
                        ? t.setupNoSetDayMeans
                        : _problem ??
                              switch ((
                                _varies,
                                // A doubled monthly figure shows before saving.
                                preview!.rule == PayRule.monthly,
                              )) {
                                (false, true) => t.setupNextPayday(
                                  sayFullDate(t, next!),
                                  money(preview.amountOn(next)),
                                ),
                                (true, true) => t.setupNextPaydayOrMore(
                                  sayFullDate(t, next!),
                                  money(preview.amountOn(next)),
                                ),
                                (false, false) => t.setupNextPaydayMonthly(
                                  sayFullDate(t, next!),
                                  money(preview.amountOn(next)),
                                  money(preview.perMonth),
                                ),
                                (true, false) => t.setupNextPaydayOrMoreMonthly(
                                  sayFullDate(t, next!),
                                  money(preview.amountOn(next)),
                                  money(preview.perMonth),
                                ),
                              },
                    key: const ValueKey('pay-summary'),
                    style: onest(
                      13,
                      color: _problem == null ? Mid.ink2 : Mid.ink3,
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  // Self-employed or between jobs: say so once, and
                  // nothing asks for pay again (Settings undoes it).
                  if (widget.existing == null && widget.offerNoPay)
                    BarButton(
                      key: const ValueKey('pay-none'),
                      label: t.setupNoRegularPay,
                      onTap: () => widget.onResult(const PayNone()),
                    ),
                  if (widget.existing != null)
                    BarButton(
                      key: const ValueKey('pay-stop'),
                      label: t.setupStopPay,
                      color: Mid.coral,
                      onTap: _stop,
                    ),
                  const Spacer(),
                  if (widget.onCancel case final cancel?)
                    BarButton(
                      key: const ValueKey('pay-cancel'),
                      label: t.setupCancel,
                      onTap: cancel,
                    ),
                  Opacity(
                    opacity: _problem == null ? 1 : 0.5,
                    child: _PrimaryButton(
                      key: const ValueKey('pay-save'),
                      label: t.setupSavePay,
                      icon: Icons.check_rounded,
                      tooltip: 'Enter',
                      onTap: _save,
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

  /// On setup's page the form has the card beside it, in the person's own
  /// figures (owner, 2026-10-28, #323: "a teaching moment"); a dialog has
  /// no room for it.
  Widget _withCard(Words t, PaySchedule? preview, DateTime? next, Widget form) {
    if (!widget.page) return form;
    String money(int v) => formatShort(v, currency: _account.currency);
    final amount = preview == null || next == null
        ? null
        : money(preview.amountOn(next));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 560, child: form),
        const SizedBox(width: 24),
        if (!_noDay && preview != null && next != null && amount != null)
          SizedBox(
            width: 340,
            child: _PayCard(
              key: const ValueKey('pay-card'),
              forecast: preview.split
                  ? t.setupCardForecastSplit(
                      payAmounts(t, preview, money),
                      sayFullDate(t, next),
                    )
                  : _varies
                  ? t.setupCardForecastLineMin(amount, sayFullDate(t, next))
                  : t.setupCardForecastLine(amount, sayFullDate(t, next)),
              // Every few weeks a month holds two paydays, or three: Budget
              // counts the ones that fall in it, so it isn't "a month".
              budget: preview.rule == PayRule.everyWeeks
                  ? (_varies
                        ? t.setupCardBudgetEachPaydayMin(amount)
                        : t.setupCardBudgetEachPayday(amount))
                  : _varies
                  ? t.setupCardBudgetLineMin(money(preview.perMonth))
                  : t.setupCardBudgetLine(money(preview.perMonth)),
            ),
          ),
      ],
    );
  }
}

/// What the app does with the pay being typed: one line each for the
/// forecast and the budget.
class _PayCard extends StatelessWidget {
  const _PayCard({super.key, required this.forecast, required this.budget});

  final String forecast;
  final String budget;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    Widget part(String head, String line) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(head, style: onest(12.5, weight: 600, color: Mid.ink3)),
          const SizedBox(height: 2),
          Text(line, style: onest(13.5, color: Mid.ink)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: Mid.raised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Mid.ink2.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          part(t.setupCardForecast, forecast),
          part(t.setupCardBudget, budget),
        ],
      ),
    );
  }
}

/// The answer to "where do the categories per this pay go": a pay's id,
/// or null for the month.
class _StopPayChoice {
  const _StopPayChoice(this.payId);
  final int? payId;
}

/// Stopping a pay that categories are budgeted per: names them, and asks
/// what they're budgeted by from now (owner, 2026-10-05: "warn them and
/// give them a chance to move the abandoned categories to a new income
/// source"). Stop goes ahead either way; ⌘Z puts it all back.
class _StopPayDialog extends StatefulWidget {
  const _StopPayDialog({
    required this.data,
    required this.categories,
    required this.others,
    required this.initial,
  });
  final LedgerData data;
  final List<AccountInfo> categories;
  final List<PaySchedule> others;
  final int? initial;

  @override
  State<_StopPayDialog> createState() => _StopPayDialogState();
}

class _StopPayDialogState extends State<_StopPayDialog> {
  late int? _to = widget.initial;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final names = widget.categories.map((c) => c.name).join(', ');
    final bills = [
      for (final c in widget.categories)
        if (widget.data.plans[c.id]?.kind == PlanKind.byDate) c.name,
    ];
    Widget choice(
      String label,
      bool on,
      VoidCallback onTap,
      String key,
    ) => Hoverable(
      key: ValueKey(key),
      onTap: onTap,
      builder: (hover) => Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: on ? Mid.blueWash : (hover ? Mid.raised : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: on ? Mid.blue : Mid.ink2.withValues(alpha: 0.3),
          ),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(label, style: onest(13, color: on ? Mid.ink : Mid.ink2)),
        ),
      ),
    );
    return Dialog(
      backgroundColor: Mid.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Mid.coral),
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
                t.stopPayTitle,
                style: onest(
                  17,
                  weight: 600,
                  letterSpacing: -0.2,
                  color: Mid.coral,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                t.stopPayPerIt(widget.categories.length, names),
                key: const ValueKey('stop-pay-per-it'),
                style: onest(13.5),
              ),
              const SizedBox(height: 14),
              Text(t.stopPayFromNow, style: onest(13.5, color: Mid.ink3)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  choice(
                    t.planRepeatMonths(1),
                    _to == null,
                    () => setState(() => _to = null),
                    'stop-move-month',
                  ),
                  for (final p in widget.others)
                    choice(
                      t.planEveryPayPeriodOf(payTitle(t, widget.data, p)),
                      _to == p.id,
                      () => setState(() => _to = p.id),
                      'stop-move-${p.id}',
                    ),
                ],
              ),
              if (_to == null && bills.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  t.stopPayBillsMonthly(bills.join(', ')),
                  style: onest(12.5, color: Mid.ink3),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  const Spacer(),
                  BarButton(
                    key: const ValueKey('stop-pay-cancel'),
                    label: t.setupCancel,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  _PrimaryButton(
                    key: const ValueKey('stop-pay-confirm'),
                    label: t.setupStopPay,
                    icon: Icons.check_rounded,
                    tooltip: 'Enter',
                    onTap: () => Navigator.of(context).pop(_StopPayChoice(_to)),
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
