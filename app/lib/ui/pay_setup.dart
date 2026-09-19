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
  });

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
  late final _amount = TextEditingController(
    text: widget.existing == null
        ? ''
        : formatMoney(
            widget.existing!.amount,
            showCents: widget.existing!.amount % 100 != 0,
          ).replaceAll('₮', ''),
  );
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
    for (final c in [_amount, _day1, _day2, _weeks, _anchor]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_payee, _amount, _day1, _day2, _weeks, _anchor]) {
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
  String? get _problem {
    final a = _amountValue;
    if (a == null || a <= 0) return 'Put in how much comes';
    return switch (_rule) {
      PayRule.monthly when _day(_day1) == null => 'Which day of the month?',
      PayRule.twiceMonthly when _day(_day1) == null || _day(_day2) == null =>
        'Which two days of the month?',
      PayRule.twiceMonthly when _day(_day1) == _day(_day2) =>
        'Two different days of the month',
      PayRule.everyWeeks when _weeksValue == null => 'Every how many weeks?',
      PayRule.everyWeeks when _anchorValue == null =>
        'When is a payday? (${fullDate(widget.today)})',
      _ => null,
    };
  }

  PaySchedule? get _preview => _problem != null
      ? null
      : PaySchedule(
          id: 0,
          categoryId: _category.id,
          accountId: _account.id,
          amount: _amountValue!,
          rule: _rule,
          day1: _day(_day1) ?? 25,
          day2: _day(_day2) ?? 10,
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
        amount: _amountValue!,
        varies: _varies,
        rule: _rule,
        day1: _day(_day1) ?? 25,
        day2: _day(_day2) ?? 10,
        weeks: _weeksValue ?? 2,
        anchor: _anchorValue ?? widget.today,
        weekendBefore: _weekendBefore,
        definesPeriod: _byPeriod,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    String money(int v) => formatMoney(v, showCents: v % 100 != 0);
    final amount = _amountValue;
    final lowest = _history.isEmpty
        ? null
        : _history.reduce((a, b) => a < b ? a : b);
    final highest = _history.isEmpty
        ? null
        : _history.reduce((a, b) => a > b ? a : b);
    final above = amount == null ? 0 : _history.where((h) => h < amount).length;
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

    Widget hint(String text, {Color color = Mid.ink3, Key? key}) => Padding(
      padding: const EdgeInsets.only(left: 120, bottom: 10),
      child: Text(
        text,
        key: key,
        style: onest(12.5, color: color),
      ),
    );

    return Dialog(
      backgroundColor: Mid.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Mid.rule),
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
                    widget.existing == null ? 'Add your pay' : 'Your pay',
                    style: onest(17, weight: 600, letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 16),
                  if (widget.categories.length > 1)
                    line(
                      'Filed under',
                      Align(
                        alignment: Alignment.centerLeft,
                        child: pick(widget.categories, _category, (c) {
                          setState(() => _category = c);
                          _loadHistory();
                        }, 'pay-category'),
                      ),
                    ),
                  line(
                    'Paid into',
                    Align(
                      alignment: Alignment.centerLeft,
                      child: pick(widget.accounts, _account, (a) {
                        setState(() => _account = a);
                        _loadHistory();
                      }, 'pay-account'),
                    ),
                  ),
                  line(
                    'From',
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
                            hint: 'Employer (optional)',
                          ),
                        ),
                      ),
                    ),
                  ),
                  line(
                    'Pay is',
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        choice(
                          'About the same each time',
                          !_varies,
                          () => setState(() => _varies = false),
                          'pay-same',
                        ),
                        choice(
                          'It varies',
                          _varies,
                          () => setState(() => _varies = true),
                          'pay-varies',
                        ),
                      ],
                    ),
                  ),
                  if (_varies)
                    hint(
                      'Hourly, shifts, overtime: it changes each time. Leave '
                      'bonuses out; they aren’t every payday.',
                    ),
                  line(
                    // Each payday, not the month: twice a month is two of these.
                    _varies ? 'Expect at least' : 'Each payday',
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 180,
                        height: 30,
                        child: TextField(
                          key: const ValueKey('pay-amount'),
                          controller: _amount,
                          autofocus: widget.existing == null,
                          textAlign: TextAlign.right,
                          style: onest(13.5, tabular: true),
                          decoration: _fieldDecoration(hint: '₮0'),
                        ),
                      ),
                    ),
                  ),
                  if (lowest != null)
                    hint(
                      _history.length == 1
                          ? 'Your last paycheck: ${money(lowest)}'
                          : 'Your last ${_history.length}: lowest '
                                '${money(lowest)} · highest ${money(highest!)}',
                      key: const ValueKey('pay-history'),
                    ),
                  if (_varies)
                    hint(
                      'The forecast counts on this, so the low end is safer: '
                      'finding more on payday is better than finding less.',
                    ),
                  // Warn, don't block: a higher estimate still saves.
                  if (_varies && above > 0)
                    hint(
                      'Higher than $above of your last ${_history.length} '
                      'paychecks: the forecast may look better than it’ll be.',
                      color: Mid.gold,
                      key: const ValueKey('pay-high'),
                    ),
                  line(
                    'When',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            choice(
                              'Monthly',
                              _rule == PayRule.monthly,
                              () => setState(() => _rule = PayRule.monthly),
                              'pay-monthly',
                            ),
                            const SizedBox(width: 8),
                            choice(
                              'Twice a month',
                              _rule == PayRule.twiceMonthly,
                              () =>
                                  setState(() => _rule = PayRule.twiceMonthly),
                              'pay-twice',
                            ),
                            const SizedBox(width: 8),
                            choice(
                              'Every few weeks',
                              _rule == PayRule.everyWeeks,
                              () => setState(() => _rule = PayRule.everyWeeks),
                              'pay-weeks',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: switch (_rule) {
                            PayRule.monthly => [
                              Text('On the ', style: onest(13.5)),
                              small(_day1, 'pay-day1'),
                            ],
                            PayRule.twiceMonthly => [
                              Text('On the ', style: onest(13.5)),
                              small(_day2, 'pay-day2'),
                              Text('  and the ', style: onest(13.5)),
                              small(_day1, 'pay-day1'),
                            ],
                            PayRule.everyWeeks => [
                              Text('Every ', style: onest(13.5)),
                              small(_weeks, 'pay-weeks-n', width: 44),
                              Text(
                                _weeksValue == 1
                                    ? ' week, from '
                                    : ' weeks, from ',
                                style: onest(13.5),
                              ),
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
                          },
                        ),
                      ],
                    ),
                  ),
                  line(
                    'On a weekend',
                    Row(
                      children: [
                        choice(
                          'Friday before',
                          _weekendBefore,
                          () => setState(() => _weekendBefore = true),
                          'pay-friday',
                        ),
                        const SizedBox(width: 8),
                        choice(
                          'Monday after',
                          !_weekendBefore,
                          () => setState(() => _weekendBefore = false),
                          'pay-monday',
                        ),
                      ],
                    ),
                  ),
                  line(
                    'Budget by',
                    Row(
                      children: [
                        choice(
                          'Month',
                          !_byPeriod,
                          () => setState(() => _byPeriod = false),
                          'pay-by-month',
                        ),
                        const SizedBox(width: 8),
                        choice(
                          'Pay period',
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
                      'The budget follows '
                      '${other.payee ?? widget.names(other.categoryId)}’s pay '
                      'periods. Pay period here moves it to this pay.',
                      key: const ValueKey('pay-period-other'),
                    ),
                  if (preview != null && preview.perYear > 24)
                    hint(
                      '${preview.perYear} paydays a year: two months a year '
                      'have three. Budgeting by pay period follows your '
                      'paychecks.',
                      key: const ValueKey('pay-26'),
                    ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 120),
                    child: Text(
                      _problem ??
                          'Next payday ${fullDate(next!)} · '
                              '${money(amount!)}${_varies ? ' or more' : ''}'
                              // A doubled monthly figure shows before saving.
                              '${preview!.rule == PayRule.monthly ? '' : ' · about ${money(amount * preview.perYear ~/ 12)} a month'}',
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
                      if (widget.existing != null)
                        BarButton(
                          key: const ValueKey('pay-stop'),
                          label: 'Stop scheduling pay',
                          color: Mid.coral,
                          onTap: () =>
                              Navigator.of(context).pop(const PayStop()),
                        ),
                      const Spacer(),
                      BarButton(
                        key: const ValueKey('pay-cancel'),
                        label: 'Cancel',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      Opacity(
                        opacity: _problem == null ? 1 : 0.5,
                        child: _PrimaryButton(
                          key: const ValueKey('pay-save'),
                          label: 'Save pay',
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
  });
  final LedgerData data;
  final ValueChanged<PaySchedule?> onBudgetBy;
  final ValueChanged<PaySchedule> onEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final pays = data.paySchedules;
    final by = data.periodSchedule;
    String name(int id) {
      final a = data.accounts[id];
      if (a == null) return '';
      return a.deleted
          ? '${a.name} (deleted)'
          : a.archived
          ? '${a.name} (archived · no paydays until it’s back)'
          : a.name;
    }

    String money(int v) => formatMoney(v, showCents: v % 100 != 0);

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
          Text('Budget', style: onest(16, weight: 600)),
          const SizedBox(height: 14),
          line(
            'Budget by',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  children: [
                    choice(
                      'Month',
                      by == null,
                      () => onBudgetBy(null),
                      'budget-by-month',
                    ),
                    // A pay period needs a schedule to define it; with two
                    // earners, whose pay it follows is the choice.
                    for (final p in pays)
                      choice(
                        pays.length == 1
                            ? 'Pay period'
                            // The employer is how people tell two apart.
                            : 'Pay period · '
                                  '${p.payee ?? '${name(p.categoryId)} into ${name(p.accountId)}'}',
                        by?.id == p.id,
                        () => onBudgetBy(p),
                        'budget-by-${p.id}',
                      ),
                  ],
                ),
                Text(
                  pays.isEmpty
                      ? 'Pay periods come from your pay: add it below to '
                            'budget by them.'
                      : by == null
                      ? 'Each budget runs from the 1st to the month’s end.'
                      : 'Each budget runs from one payday to the day before '
                            'the next (${by.describe}).',
                  style: onest(12.5, color: Mid.ink3),
                ),
              ],
            ),
          ),
          line(
            'Pay',
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
                            '${name(p.categoryId)} · ${money(p.amount)}'
                            '${p.varies ? ' or more' : ''} · ${p.describe} · '
                            'into ${name(p.accountId)}',
                            style: onest(13.5),
                          ),
                        ),
                        BarButton(
                          key: ValueKey('edit-pay-${p.id}'),
                          label: 'Edit',
                          onTap: () => onEdit(p),
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: BarButton(
                    key: const ValueKey('settings-add-pay'),
                    label: pays.isEmpty ? 'Add your pay' : 'Add other pay',
                    leading: const Icon(
                      Icons.add_rounded,
                      size: 14,
                      color: Mid.ink3,
                    ),
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
