part of 'ledger_screen.dart';

// Putting in pay (ADR 0004, rule 24): when it comes, how much, into which
// account. Pay that varies is entered as the least it's likely to be, since
// the forecast counts on it: finding more on payday beats finding less.

/// What the pay setup saves.
typedef PayDraft = ({
  int categoryId,
  int accountId,
  String? payee,
  int amount,
  int? amount2,
  bool varies,
  PayRule rule,
  int day1,
  int day2,
  int weeks,
  DateTime anchor,
  bool weekendBefore,
  bool definesPeriod,
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
  const PayStop();
}

/// "I don't have regular pay": stop asking for it.
class PayNone extends PaySetupResult {
  const PayNone();
}

/// Stand-ins for the boxes in a sentence like "On the [25]": the words
/// around a box come from one message, so each language puts them in its
/// own order.
const _fieldMarks = ['\uE000', '\uE001'];

/// [text] as a row of words and [fields], each field where its mark is.
List<Widget> _withFields(String text, List<Widget> fields) {
  final out = <Widget>[];
  var rest = text;
  while (rest.isNotEmpty) {
    var at = -1, which = -1;
    for (var i = 0; i < fields.length; i++) {
      final j = rest.indexOf(_fieldMarks[i]);
      if (j >= 0 && (at < 0 || j < at)) (at, which) = (j, i);
    }
    if (at < 0) {
      out.add(Text(rest, style: onest(13.5)));
      break;
    }
    if (at > 0) out.add(Text(rest.substring(0, at), style: onest(13.5)));
    out.add(fields[which]);
    rest = rest.substring(at + 1);
  }
  return out;
}

class _PaySetupDialog extends StatefulWidget {
  const _PaySetupDialog({
    required this.categories,
    required this.accounts,
    required this.category,
    required this.account,
    required this.today,
    required this.history,
    required this.names,
    this.existing,
    this.periodBy,
    this.offerNoPay = false,
  });

  /// There's no pay anywhere yet: offer "I don't have regular pay".
  final bool offerNoPay;

  /// Another schedule the budget runs by, if one does.
  final PaySchedule? periodBy;

  /// An account or category's name, by id.
  final String Function(int id) names;

  /// Income categories to file pay under, and accounts it can go into.
  final List<AccountInfo> categories;
  final List<AccountInfo> accounts;
  final AccountInfo category;
  final AccountInfo account;
  final DateTime today;
  final PaySchedule? existing;

  /// Recent paychecks for a category and account, newest first.
  final Future<List<int>> Function(int categoryId, int accountId) history;

  @override
  State<_PaySetupDialog> createState() => _PaySetupDialogState();
}

class _PaySetupDialogState extends State<_PaySetupDialog> {
  late AccountInfo _category = widget.category;
  late AccountInfo _account = widget.account;
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

  static String _typed(int? v) =>
      v == null ? '' : formatWhole(v) + (v % 100 == 0 ? '' : formatCents(v));
  late bool _varies = widget.existing?.varies ?? false;
  late PayRule _rule = widget.existing?.rule ?? PayRule.monthly;
  late final _day1 = TextEditingController(
    text: '${widget.existing?.day1 ?? 25}',
  );
  late final _day2 = TextEditingController(
    text: '${widget.existing?.day2 ?? 10}',
  );
  late final _weeks = TextEditingController(
    text: '${widget.existing?.weeks ?? 2}',
  );
  late final _anchor = TextEditingController(
    text: fullDate(widget.existing?.anchor ?? widget.today),
  );
  final _anchorFocus = FocusNode(debugLabel: 'pay-anchor');
  late bool _weekendBefore = widget.existing?.weekendBefore ?? true;
  late bool _byPeriod = widget.existing?.definesPeriod ?? false;
  List<int> _history = const [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    for (final c in [_amount, _amount2, _day1, _day2, _weeks, _anchor]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _payee,
      _amount,
      _amount2,
      _day1,
      _day2,
      _weeks,
      _anchor,
    ]) {
      c.dispose();
    }
    _anchorFocus.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final h = await widget.history(_category.id, _account.id);
    if (mounted) setState(() => _history = h);
  }

  int? get _amountValue => parseAmount(_amount.text);

  /// Back to one amount (the same both days, or another rule): the larger
  /// of the two stays, since the advance alone would undercount pay.
  void _oneAmount() {
    if (!_splitting) return;
    final a = _amountValue, b = _amount2Value;
    if (b != null && (a == null || b > a)) _amount.text = _amount2.text;
    _split = false;
  }

  int? get _amount2Value => parseAmount(_amount2.text);
  bool get _splitting => _split && _rule == PayRule.twiceMonthly;

  /// The two days of the month, earlier first, when both read.
  (int, int)? get _days {
    final a = _day(_day1), b = _day(_day2);
    if (a == null || b == null) return null;
    return a < b ? (a, b) : (b, a);
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

  /// What's saved: twice a month keeps the earlier day as [day2] and its
  /// amount as amount2, the order the setup shows them in.
  ({int amount, int? amount2, int day1, int day2}) get _plan {
    final days = _days;
    if (_rule != PayRule.twiceMonthly || days == null) {
      return (
        amount: _amountValue!,
        amount2: null,
        day1: _day(_day1) ?? 25,
        day2: _day(_day2) ?? 10,
      );
    }
    return (
      amount: _splitting ? _amount2Value! : _amountValue!,
      amount2: _splitting ? _amountValue : null,
      day1: days.$2,
      day2: days.$1,
    );
  }

  int? _day(TextEditingController c) {
    final v = int.tryParse(c.text.trim());
    return v == null || v < 1 || v > 31 ? null : v;
  }

  int? get _weeksValue {
    final v = int.tryParse(_weeks.text.trim());
    return v == null || v < 1 || v > 8 ? null : v;
  }

  DateTime? get _anchorValue => parseEntryDate(_anchor.text, widget.today);

  /// What's missing or unreadable, first thing only; null when it can save.
  String? get _problem => _problemIn(context.t);

  String? _problemIn(Words t) {
    final a = _amountValue;
    if (a == null || a <= 0) {
      return _splitting ? _amountMissing(t, false) : t.setupAmountMissing;
    }
    final b = _amount2Value;
    if (_splitting && (b == null || b <= 0)) {
      return _amountMissing(t, true);
    }
    return switch (_rule) {
      PayRule.monthly when _day(_day1) == null => t.setupWhichDay,
      PayRule.twiceMonthly when _day(_day1) == null || _day(_day2) == null =>
        t.setupWhichTwoDays,
      PayRule.twiceMonthly when _day(_day1) == _day(_day2) =>
        t.setupTwoDifferentDays,
      PayRule.everyWeeks when _weeksValue == null => t.setupHowManyWeeks,
      PayRule.everyWeeks when _anchorValue == null => t.setupWhenPayday(
        fullDate(widget.today),
      ),
      _ => null,
    };
  }

  PaySchedule? get _preview => _problem != null
      ? null
      : PaySchedule(
          id: 0,
          categoryId: _category.id,
          accountId: _account.id,
          amount: _plan.amount,
          amount2: _plan.amount2,
          varies: _varies,
          rule: _rule,
          day1: _plan.day1,
          day2: _plan.day2,
          weeks: _weeksValue ?? 2,
          anchor: _anchorValue,
          weekendBefore: _weekendBefore,
        );

  void _save() {
    if (_problem != null) return;
    Navigator.of(context).pop(
      PaySave((
        categoryId: _category.id,
        accountId: _account.id,
        payee: _payee.text,
        amount: _plan.amount,
        amount2: _plan.amount2,
        varies: _varies,
        rule: _rule,
        day1: _plan.day1,
        day2: _plan.day2,
        weeks: _weeksValue ?? 2,
        anchor: _anchorValue ?? widget.today,
        weekendBefore: _weekendBefore,
        definesPeriod: _byPeriod,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    String money(int v) =>
        formatMoney(v, showCents: v % 100 != 0, currency: _account.currency);
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

    Widget small(TextEditingController c, String key, {double width = 56}) =>
        SizedBox(
          width: width,
          height: 30,
          child: TextField(
            key: ValueKey(key),
            controller: c,
            textAlign: TextAlign.center,
            style: onest(13.5, tabular: true),
            decoration: _fieldDecoration(),
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
          autofocus: autofocus && widget.existing == null,
          textAlign: TextAlign.right,
          style: onest(13.5, tabular: true),
          decoration: _fieldDecoration(hint: '${_account.currency.symbol}0'),
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

    return Dialog(
      backgroundColor: Mid.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Mid.rule),
      ),
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.enter): _save},
        // A click anywhere else in the dialog closes the date's calendar,
        // which otherwise sits over Save.
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.existing == null
                        ? t.setupAddYourPay
                        : t.setupYourPay,
                    style: onest(17, weight: 600, letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 16),
                  if (widget.categories.length > 1)
                    line(
                      t.setupFiledUnder,
                      Align(
                        alignment: Alignment.centerLeft,
                        child: pick(widget.categories, _category, (c) {
                          setState(() => _category = c);
                          _loadHistory();
                        }, 'pay-category'),
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
                          decoration: _fieldDecoration(
                            hint: t.setupEmployerHint,
                          ),
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
                  // Twice a month: an advance one day, the rest the other.
                  if (_rule == PayRule.twiceMonthly)
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
                      color: Mid.gold,
                      key: const ValueKey('pay-high'),
                    ),
                  line(
                    t.setupWhen,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Wraps when the words run long (Mongolian).
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            choice(
                              t.setupMonthly,
                              _rule == PayRule.monthly,
                              () => setState(() {
                                _oneAmount();
                                _rule = PayRule.monthly;
                              }),
                              'pay-monthly',
                            ),
                            choice(
                              t.setupTwiceMonthly,
                              _rule == PayRule.twiceMonthly,
                              () =>
                                  setState(() => _rule = PayRule.twiceMonthly),
                              'pay-twice',
                            ),
                            choice(
                              t.setupEveryFewWeeks,
                              _rule == PayRule.everyWeeks,
                              () => setState(() {
                                _oneAmount();
                                _rule = PayRule.everyWeeks;
                              }),
                              'pay-weeks',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: switch (_rule) {
                            PayRule.monthly => _withFields(
                              t.setupOnDayField(_fieldMarks[0]),
                              [small(_day1, 'pay-day1')],
                            ),
                            PayRule.twiceMonthly => _withFields(
                              t.setupOnDaysField(
                                _fieldMarks[0],
                                _fieldMarks[1],
                              ),
                              [
                                small(_day2, 'pay-day2'),
                                small(_day1, 'pay-day1'),
                              ],
                            ),
                            PayRule.everyWeeks => _withFields(
                              t.setupEveryWeeksField(
                                _weeksValue ?? 0,
                                _fieldMarks[0],
                                _fieldMarks[1],
                              ),
                              [
                                small(_weeks, 'pay-weeks-n', width: 44),
                                SizedBox(
                                  width: 130,
                                  height: 30,
                                  child: DateField(
                                    key: const ValueKey('pay-anchor'),
                                    controller: _anchor,
                                    focusNode: _anchorFocus,
                                    today: widget.today,
                                    small: true,
                                    onSubmitted: _save,
                                    onPicked: () {},
                                  ),
                                ),
                              ],
                            ),
                          },
                        ),
                      ],
                    ),
                  ),
                  // Both days past the 28th meet in short months: one
                  // payday then, which is worth knowing before it happens.
                  if (_rule == PayRule.twiceMonthly && (_days?.$1 ?? 0) >= 28)
                    hint(
                      t.setupDaysMeet,
                      color: Mid.gold,
                      key: const ValueKey('pay-days-meet'),
                    ),
                  line(
                    t.setupOnWeekend,
                    Row(
                      children: [
                        choice(
                          t.setupFridayBefore,
                          _weekendBefore,
                          () => setState(() => _weekendBefore = true),
                          'pay-friday',
                        ),
                        const SizedBox(width: 8),
                        choice(
                          t.setupMondayAfter,
                          !_weekendBefore,
                          () => setState(() => _weekendBefore = false),
                          'pay-monday',
                        ),
                      ],
                    ),
                  ),
                  line(
                    t.setupBudgetBy,
                    Row(
                      children: [
                        choice(
                          t.setupMonth,
                          !_byPeriod,
                          () => setState(() => _byPeriod = false),
                          'pay-by-month',
                        ),
                        const SizedBox(width: 8),
                        choice(
                          t.setupPayPeriod,
                          _byPeriod,
                          () => setState(() => _byPeriod = true),
                          'pay-by-period',
                        ),
                      ],
                    ),
                  ),
                  // Another schedule sets the period: "Month" here would only mean
                  // "not this pay", so say what's in effect.
                  if (widget.periodBy case final other? when !_byPeriod)
                    hint(
                      t.setupPeriodOther(
                        other.payee ?? widget.names(other.categoryId),
                      ),
                      key: const ValueKey('pay-period-other'),
                    ),
                  if (preview != null && preview.perYear > 24)
                    hint(
                      t.setupPaydaysAYear(preview.perYear),
                      key: const ValueKey('pay-26'),
                    ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 120),
                    child: Text(
                      _problem ??
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
                          onTap: () =>
                              Navigator.of(context).pop(const PayNone()),
                        ),
                      if (widget.existing != null)
                        BarButton(
                          key: const ValueKey('pay-stop'),
                          label: t.setupStopPay,
                          color: Mid.coral,
                          onTap: () =>
                              Navigator.of(context).pop(const PayStop()),
                        ),
                      const Spacer(),
                      BarButton(
                        key: const ValueKey('pay-cancel'),
                        label: t.setupCancel,
                        onTap: () => Navigator.of(context).pop(),
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
        ),
      ),
    );
  }
}

/// Settings: what the budget runs by, and the pay schedules behind it.
class _BudgetSettings extends StatelessWidget {
  const _BudgetSettings({
    required this.data,
    required this.onBudgetBy,
    required this.onEdit,
    required this.onAdd,
    required this.onAskAgain,
  });
  final LedgerData data;

  /// Undoes "I don't have regular pay".
  final VoidCallback onAskAgain;
  final ValueChanged<PaySchedule?> onBudgetBy;
  final ValueChanged<PaySchedule> onEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final pays = data.paySchedules;
    final by = data.periodSchedule;
    String name(int id) {
      final a = data.accounts[id];
      if (a == null) return '';
      return a.deleted
          ? t.startDeletedAccount(a.name)
          : a.archived
          ? t.setupNameArchived(a.name)
          : a.name;
    }

    Widget choice(String label, bool on, VoidCallback onTap, String key) =>
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 6),
          child: Hoverable(
            key: ValueKey(key),
            onTap: onTap,
            builder: (hover) => Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: on
                    ? Mid.blueWash
                    : (hover ? Mid.raised : Colors.transparent),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: on ? Mid.blue : Mid.ink2.withValues(alpha: 0.3),
                ),
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: onest(13, color: on ? Mid.ink : Mid.ink2),
                ),
              ),
            ),
          ),
        );

    Widget line(String label, Widget value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(label, style: onest(13.5, color: Mid.ink3)),
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );

    return Container(
      key: const ValueKey('settings-budget'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        color: Mid.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Mid.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.setupBudget, style: onest(16, weight: 600)),
          const SizedBox(height: 14),
          line(
            t.setupBudgetBy,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  children: [
                    choice(
                      t.setupMonth,
                      by == null,
                      () => onBudgetBy(null),
                      'budget-by-month',
                    ),
                    // A pay period needs a schedule to define it; with two
                    // earners, whose pay it follows is the choice.
                    for (final p in pays)
                      choice(
                        pays.length == 1
                            ? t.setupPayPeriod
                            // The employer is how people tell two apart.
                            : t.setupPayPeriodOf(
                                p.payee ??
                                    t.setupCategoryInto(
                                      name(p.categoryId),
                                      name(p.accountId),
                                    ),
                              ),
                        by?.id == p.id,
                        () => onBudgetBy(p),
                        'budget-by-${p.id}',
                      ),
                  ],
                ),
                Text(
                  pays.isEmpty
                      ? t.setupPeriodsFromPay
                      : by == null
                      ? t.setupRunsMonth
                      : t.setupRunsPeriod(payWhen(t, by)),
                  style: onest(12.5, color: Mid.ink3),
                ),
              ],
            ),
          ),
          line(
            t.setupPay,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in pays)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.setupPayLine(
                              name(p.categoryId),
                              payAmounts(
                                t,
                                p,
                                (v) => formatMoney(
                                  v,
                                  showCents: v % 100 != 0,
                                  currency:
                                      data.accounts[p.accountId]?.currency ??
                                      Currency.mnt,
                                ),
                                dotted: true,
                              ),
                              name(p.accountId),
                            ),
                            style: onest(13.5),
                          ),
                        ),
                        BarButton(
                          key: ValueKey('edit-pay-${p.id}'),
                          label: t.setupEdit,
                          onTap: () => onEdit(p),
                        ),
                      ],
                    ),
                  ),
                if (pays.isEmpty && data.prefs[noRegularPayKey] == '1')
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.setupSaidNoPay,
                            key: const ValueKey('settings-no-pay'),
                            style: onest(13.5, color: Mid.ink2),
                          ),
                        ),
                        BarButton(
                          key: const ValueKey('settings-ask-pay'),
                          label: t.setupAskAgain,
                          onTap: onAskAgain,
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: BarButton(
                    key: const ValueKey('settings-add-pay'),
                    label: pays.isEmpty
                        ? t.setupAddYourPay
                        : t.setupAddOtherPay,
                    leading: Icon(Icons.add_rounded, size: 14, color: Mid.ink3),
                    onTap: onAdd,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
