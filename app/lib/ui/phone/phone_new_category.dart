part of 'phone_app.dart';

// The phone's New category (owner, 2026-10-22, #237: "+ New category" on the
// phone opens the computer's window too, phone-sized). One page with every
// question the computer's window asks, in its order and words (ADR 0004 "New
// category: one window with everything"; laid out as one page, the owner's
// pick of three). [PlanAnswers] makes the plan as the computer's form does;
// the category waits with the phone's entries and comes in with its plan.

/// Opens New category. [forEntry]: from an entry's Category list, in the
/// entry's [currency] with no other offered, and no Add another; the
/// category made, or the one already called that, comes back for the entry.
/// [editing]: a category made here and still waiting, opened filled in to
/// be changed, with Save in place of Add (#243).
Future<PhoneCategory?> _openNewCategory(
  BuildContext context, {
  required PhoneStore store,
  required Currency currency,
  String name = '',
  bool forEntry = false,
  PhoneCategory? editing,
}) {
  final now = store.now();
  final today = DateTime(now.year, now.month, now.day);
  return Navigator.of(context).push(
    MaterialPageRoute<PhoneCategory>(
      fullscreenDialog: true,
      builder: (_) => _NewCategoryPage(
        store: store,
        today: today,
        currency: currency,
        name: editing?.name ?? name,
        forEntry: forEntry,
        editing: editing,
      ),
    ),
  );
}

class _NewCategoryPage extends StatefulWidget {
  const _NewCategoryPage({
    required this.store,
    required this.today,
    required this.currency,
    required this.name,
    required this.forEntry,
    this.editing,
  });
  final PhoneStore store;
  final DateTime today;
  final Currency currency;
  final String name;
  final bool forEntry;
  final PhoneCategory? editing;

  @override
  State<_NewCategoryPage> createState() => _NewCategoryPageState();
}

/// Stands for the category in the ledger it is worked out in until the
/// computer makes it.
const _pageCategoryId = -1;

class _NewCategoryPageState extends State<_NewCategoryPage> {
  late final _name = TextEditingController(text: widget.name);
  late PlanAnswers _p = widget.editing == null
      ? _fresh(widget.currency)
      : (_fresh(widget.editing!.currency)
          ..show(widget.editing!.plan, periodPayId: _data.periodSchedule?.id));

  /// The accounts in its currency it isn't paid from (rule 28).
  late Set<int> _off = {
    for (final a in widget.editing?.off ?? const <String>{}) ?int.tryParse(a),
  };

  /// The computer took in the category being changed while the page was
  /// open: there's nothing left here to change.
  bool get _takenMeanwhile =>
      widget.editing != null &&
      !widget.store.made.any((c) => c.id == widget.editing!.id);

  /// The ledger's categories and the ones made here, but for the one
  /// being changed: its own name isn't taken.
  List<PhoneCategory> get _others => [
    for (final c in widget.store.categories)
      if (c.id != widget.editing?.id) c,
  ];

  /// What Add another has made so far: the only sign of it, since the
  /// page stays open.
  final _added = <String>[];

  /// Add was tried with something missing: say which.
  bool _tried = false;

  /// Each Add another starts the name's field afresh, keyboard up.
  int _round = 0;

  PlanAnswers _fresh(Currency currency) =>
      PlanAnswers(today: widget.today, currency: currency)
        ..show(null, periodPayId: _data.periodSchedule?.id);

  /// The ledger the computer last stored, or for made-up figures one
  /// with just the phone's accounts.
  late final LedgerData _data =
      widget.store.snapshot.data ??
      LedgerData(
        accounts: [
          for (final (i, a) in widget.store.snapshot.accounts.indexed)
            AccountInfo(
              id: int.tryParse(a.id) ?? -2 - i,
              name: a.name,
              type: a.owes ? AccountType.liability : AccountType.asset,
              group: a.owes ? LedgerGroups.credit : LedgerGroups.bank,
              currency: a.currency,
            ),
        ],
        txns: const [],
      );

  Currency get _currency => _p.currency;

  /// The currencies there are accounts in: the choice shows with two.
  List<Currency> get _currencies => [
    for (final c in Currency.values)
      if (widget.store.snapshot.accounts.any((a) => a.currency == c)) c,
  ];

  List<AccountInfo> get _accounts =>
      categoryAccounts(_data, _currency).toList();

  /// The account a dated plan's bill is scheduled in: the one account
  /// it's paid from, when it's narrowed to one.
  int? get _paidFrom {
    if (!_p.hasDate) return null;
    final used = _accounts.where((a) => !_off.contains(a.id)).toList();
    return used.length == 1 ? used.single.id : null;
  }

  CategoryPlan? get _draft => _p.draft(
    categoryId: _pageCategoryId,
    paidFrom: _paidFrom,
    old: widget.editing?.plan,
  );

  /// Each typed field's focus, by its key: a tap on its row puts the
  /// cursor there.
  final _focuses = <String, FocusNode>{};
  FocusNode _focus(String key) =>
      _focuses.putIfAbsent(key, () => FocusNode(debugLabel: key));

  @override
  void dispose() {
    _name.dispose();
    _p.dispose();
    for (final f in _focuses.values) {
      f.dispose();
    }
    super.dispose();
  }

  /// What's said under the name as it's typed: it's taken, and what Add
  /// does then. [blocks]: Add can't go ahead with it.
  ({String text, bool blocks})? _nameNote(Words t, String name) {
    if (name.isEmpty || _takenMeanwhile) return null;
    final key = name.toLowerCase();
    for (final a in widget.store.snapshot.accounts) {
      if (a.name.trim().toLowerCase() == key) {
        return (text: t.planNameIsAccount(a.name), blocks: true);
      }
    }
    // Income is the app's own category, whichever language names it.
    if (isIncomeName(name)) {
      return (text: t.ledgerAlreadyCategory(t.ledgerIncome), blocks: true);
    }
    final already = categoryNamed(_others, name);
    if (already == null) return null;
    // An entry takes the one there is; Budget has it already.
    return widget.forEntry
        ? (text: t.planNameIsCategoryInRow(already.name), blocks: false)
        : (text: t.ledgerAlreadyCategory(already.name), blocks: true);
  }

  void _add({bool another = false}) {
    final t = context.t;
    final name = _name.text.trim();
    // Its own name is the ledger's now: Save says it was taken in.
    if (widget.editing case final c? when _takenMeanwhile) {
      _save(c, name);
      return;
    }
    final note = _nameNote(t, name);
    final already = categoryNamed(_others, name);
    // A name that's a category already goes in the entry as it is: the
    // plan's answers don't count for it.
    final fromList = widget.forEntry && already != null;
    if (name.isEmpty ||
        (note?.blocks ?? false) ||
        (!fromList && _p.missing != null)) {
      setState(() => _tried = true);
      return;
    }
    if (already != null) {
      Navigator.of(context).pop(already);
      return;
    }
    if (widget.editing case final c?) {
      _save(c, name);
      return;
    }
    final made = widget.store.categoryCalled(
      name,
      _currency,
      plan: _draft,
      off: {for (final a in _off) '$a'},
    );
    if (!another) {
      Navigator.of(context).pop(made);
      return;
    }
    final keep = _currency;
    final old = _p;
    setState(() {
      _added.add(made.name);
      _name.clear();
      // Only the currency stays: a bill's Yes kept from Rent would make
      // Food a bill unseen.
      _p = _fresh(keep);
      _off = {};
      _tried = false;
      _round++;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  /// Save, for a category still waiting: in place, or, when the computer
  /// took it in while the page was open, said so.
  Future<void> _save(PhoneCategory c, String name) async {
    final kept = widget.store.changeCategory(
      c.id,
      name,
      _currency,
      plan: _draft,
      off: {for (final a in _off) '$a'},
    );
    if (!kept) {
      final t = context.t;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Mid.panel,
          content: Text(
            t.phoneCategoryTakenMeanwhile(c.name),
            style: onest(17, height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                t.startClose,
                style: onest(15, weight: 600, color: Mid.blue),
              ),
            ),
          ],
        ),
      );
      if (!mounted) return;
    }
    Navigator.of(context).pop();
  }

  // ---------- pickers ----------

  /// A list to pick one of, from the bottom: the phone's way of a menu.
  Future<T?> _pick<T>(
    String title,
    List<(T, String)> items, {
    required T chosen,
    String keyPrefix = 'pick',
  }) => showModalBottomSheet<T>(
    context: context,
    backgroundColor: Mid.panel,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(title, style: onest(14, color: Mid.ink2)),
            ),
            for (final (i, (value, label)) in items.indexed)
              ListTile(
                key: ValueKey('$keyPrefix-$i'),
                title: Text(label, style: onest(16, weight: 500)),
                trailing: value == chosen
                    ? Icon(Icons.check, color: Mid.blue)
                    : null,
                onTap: () => Navigator.of(context).pop(value),
              ),
          ],
        ),
      ),
    ),
  );

  /// A due date or an end is ahead: the calendar starts today, as a date
  /// typed on the computer is rolled to its next time round.
  Future<DateTime?> _pickDay(DateTime? from) => showDatePicker(
    context: context,
    initialDate: from == null || from.isBefore(widget.today)
        ? widget.today
        : from,
    firstDate: widget.today,
    lastDate: DateTime(widget.today.year + 30),
  );

  Future<void> _pickCurrency(Words t) async {
    final picked = await _pick(t.planMoneyCurrency, [
      for (final c in _currencies) (c, '${c.code} ${c.symbol}'),
    ], chosen: _currency);
    if (picked == null || picked == _currency || !mounted) return;
    setState(() {
      _p.currency = picked;
      // The accounts are another currency's now, and so would the
      // amounts be: the rest stays, and the amounts are typed again.
      _off = {};
      _p.amount.clear();
      _p.upTo.clear();
      _tried = false;
    });
  }

  Future<void> _pickEachPeriod(Words t) async {
    final picked = await _pick<int>(t.planHowOften, [
      (0, t.planRepeatMonths(1)),
      for (final pay in _data.paySchedules)
        (pay.id, planEachPayLabel(t, _data, pay)),
    ], chosen: _p.eachPayId ?? 0);
    if (picked == null || !mounted) return;
    setState(() => _p.eachPayId = picked == 0 ? null : picked);
  }

  Future<void> _pickRepeat(Words t) async {
    final a = _p;
    String on() => switch (a.repeat) {
      PlanRepeat.once => 'once',
      PlanRepeat.dates => 'dates',
      PlanRepeat.payday => 'pay-${a.payScheduleId}',
      PlanRepeat.every when a.custom => 'custom',
      PlanRepeat.every => '${a.unit.name}-${a.typedEveryN}',
    };
    final picked = await _pick<String>(
      t.planHowOften,
      [
        ('once', t.planOnce),
        ('weeks-1', t.planRepeatWeeks(1)),
        ('weeks-2', t.planRepeatWeeks(2)),
        ('months-1', t.planRepeatMonths(1)),
        ('months-3', t.planRepeatMonths(3)),
        ('years-1', t.planRepeatYears(1)),
        // Payday by payday: only with pay set up.
        for (final pay in _data.paySchedules)
          ('pay-${pay.id}', planPaydayLabel(t, _data, pay)),
        ('custom', t.planEveryCustom),
        ('dates', t.planOnDates),
      ],
      chosen: on(),
      keyPrefix: 'plan-repeat',
    );
    if (picked == null || !mounted) return;
    setState(() {
      switch (picked.split('-')) {
        case ['once']:
          a.repeat = PlanRepeat.once;
        case ['dates']:
          a.repeat = PlanRepeat.dates;
        case ['custom']:
          a.repeat = PlanRepeat.every;
          a.custom = true;
        case ['pay', final id]:
          a.repeat = PlanRepeat.payday;
          a.payScheduleId = int.parse(id);
        case [final unit, final n]:
          a.preset(int.parse(n), PlanUnit.values.byName(unit));
      }
    });
    if (picked == 'custom') await _openCustom();
  }

  Future<void> _openCustom() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _CustomRepeatPage(answers: _p),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _pickWeekend(Words t) async {
    final picked = await _pick(
      t.setupOnWeekend,
      [for (final w in PayWeekend.values) (w, planWeekendLabel(t, w))],
      chosen: _p.weekend,
      keyPrefix: 'plan-weekend',
    );
    if (picked != null && mounted) setState(() => _p.weekend = picked);
  }

  Future<void> _pickAccounts(Words t) async {
    final accounts = _accounts;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Mid.panel,
      builder: (context) => StatefulBuilder(
        builder: (context, again) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  t.planLabelPaidFrom,
                  style: onest(14, color: Mid.ink2),
                ),
              ),
              for (final a in accounts)
                CheckboxListTile(
                  key: ValueKey('money-account-${a.id}'),
                  value: !_off.contains(a.id),
                  activeColor: Mid.blue,
                  title: Text(a.name, style: onest(16, weight: 500)),
                  onChanged: (_) {
                    setState(
                      () => _off.contains(a.id)
                          ? _off.remove(a.id)
                          : _off.add(a.id),
                    );
                    again(() {});
                  },
                ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      foregroundColor: Mid.blue,
                      textStyle: onest(16, weight: 600),
                    ),
                    child: Text(t.rowsSplitDone),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- the page ----------

  /// A card of rows with lines between, as the phone's lists are.
  Widget _card(List<Widget> rows) => Material(
    color: Mid.card,
    borderRadius: BorderRadius.circular(14),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (final (i, r) in rows.indexed) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: Mid.rule),
          r,
        ],
      ],
    ),
  );

  /// A row that opens a choice: its label, and what's chosen.
  Widget _choiceRow(
    String key,
    String label,
    String value,
    VoidCallback onTap, {
    bool wrong = false,
  }) => InkWell(
    key: ValueKey(key),
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text(label, style: onest(15, color: wrong ? Mid.coral : Mid.ink2)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: onest(16, weight: 500, tabular: true),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: Mid.ink3),
          ],
        ),
      ),
    ),
  );

  /// A row with a field to type in.
  Widget _fieldRow(
    String key,
    String label,
    TextEditingController controller, {
    bool money = false,
    bool number = false,
    bool wrong = false,
    String? hint,
    String? after,
  }) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => _focus(key).requestFocus(),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: onest(15, color: wrong ? Mid.coral : Mid.ink2),
              ),
            ),
            const SizedBox(width: 12),
            // The field as wide as what's in it, the ₮ right beside it; the
            // row around it puts the cursor there.
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (money && controller.text.isNotEmpty)
                    Text(_currency.prefix, style: onest(16, color: Mid.ink3)),
                  Flexible(
                    child: IntrinsicWidth(
                      child: TextField(
                        key: ValueKey(key),
                        controller: controller,
                        focusNode: _focus(key),
                        textAlign: TextAlign.end,
                        keyboardType: money
                            ? TextInputType.numberWithOptions(
                                decimal: _currency.decimals > 0,
                              )
                            : number
                            ? TextInputType.number
                            : TextInputType.datetime,
                        style: onest(16, weight: 500, tabular: true),
                        cursorColor: Mid.blue,
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: hint,
                          hintStyle: onest(16, color: Mid.ink3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (after != null) ...[
              const SizedBox(width: 8),
              Text(after, style: onest(15, color: Mid.ink2)),
            ],
          ],
        ),
      ),
    ),
  );

  /// Two or three answers side by side, the one picked lit.
  Widget _segments(List<(String, String, bool, VoidCallback)> items) => Padding(
    padding: const EdgeInsets.all(6),
    child: Row(
      children: [
        for (final (key, label, on, onTap) in items)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Material(
                color: on ? Mid.blueWash : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  key: ValueKey(key),
                  borderRadius: BorderRadius.circular(10),
                  onTap: onTap,
                  child: Semantics(
                    selected: on,
                    button: true,
                    child: SizedBox(
                      height: 44,
                      child: Center(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: onest(
                            15,
                            weight: on ? 600 : 400,
                            color: on ? Mid.blue : Mid.ink2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  /// A question's label over its answers.
  Widget _asked(String label, Widget answers) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(label, style: onest(15, color: Mid.ink2)),
      ),
      answers,
    ],
  );

  /// A quiet line under a card: what an answer means, or what's missing.
  Widget _aside(String text, {String? key, Color? color}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Text(
      text,
      key: key == null ? null : ValueKey(key),
      style: onest(14, color: color ?? Mid.ink3),
    ),
  );

  List<Widget> _planRows(Words t, {required EnvelopeLine? line}) {
    final a = _p;
    final draft = _draft;
    final byPay = a.eachPayId != null;
    final hasAmount = a.amount.text.trim().isNotEmpty;
    final missing = _tried ? a.missing : null;
    String money(int v) => formatShort(v, currency: _currency);
    final accounts = _accounts;
    final used = accounts.where((x) => !_off.contains(x.id)).toList();
    final accountsLabel = used.length == accounts.length && accounts.length > 1
        ? t.planAccountsAll
        : switch (used.length) {
            0 => t.planAccountsNone,
            1 => used.single.name,
            final n => t.planAccountsSome(n, accounts.length),
          };
    final paidRow = _choiceRow(
      'money-accounts',
      t.planLabelPaidFrom,
      accountsLabel,
      () => _pickAccounts(t),
    );
    final dueRow = switch (a.repeat) {
      PlanRepeat.payday => _fieldRow(
        'plan-days-after',
        t.planLabelDueDate,
        a.daysAfter,
        number: true,
        hint: '0',
        after: t.planDaysAfterPay,
      ),
      PlanRepeat.dates => _fieldRow(
        'plan-dates',
        t.planDatesLabel,
        a.dates,
        wrong: missing == PlanMissing.dates,
        hint: t.planDatesHint,
      ),
      _ => _choiceRow(
        'plan-date',
        t.planLabelDueDate,
        switch (a.typedDate) {
          final d? =>
            d.year == widget.today.year ? sayDate(t, d) : sayFullDate(t, d),
          null => '',
        },
        () async {
          final d = await _pickDay(a.typedDate);
          if (d != null && mounted) setState(() => a.date.text = fullDate(d));
        },
        wrong: missing == PlanMissing.date,
      ),
    };
    if (!a.hasDate) {
      return [
        _card([
          _fieldRow(
            'plan-amount',
            byPay ? t.planSetAsidePay : t.planSetAsideMonth,
            a.amount,
            money: true,
            wrong: missing == PlanMissing.amount,
            hint: t.planNothingSet,
          ),
          // Per month, or per one pay's periods. Without pay there's
          // nothing else to pick, so no row.
          if (_data.paySchedules.isNotEmpty)
            _choiceRow('plan-each-period', t.planHowOften, switch (_data
                .payScheduleById(a.eachPayId)) {
              null => t.planRepeatMonths(1),
              final pay => planEachPayLabel(t, _data, pay),
            }, () => _pickEachPeriod(t)),
        ]),
        if (!hasAmount) _aside(byPay ? t.planEmptyHintPay : t.planEmptyHint),
        const SizedBox(height: 14),
        _card([
          _asked(
            byPay ? t.planLeftPeriodEnd : t.planLeftMonthEnd,
            _segments([
              (
                'plan-carry-on',
                t.planStaysHere,
                a.rollover,
                () => setState(() => a.rollover = true),
              ),
              (
                'plan-carry-off',
                t.planGoesBack,
                !a.rollover,
                () => setState(() => a.rollover = false),
              ),
            ]),
          ),
          if (a.rollover && hasAmount)
            _fieldRow(
              'plan-up-to',
              t.planStopAt,
              a.upTo,
              money: true,
              wrong: missing == PlanMissing.upTo,
              hint: t.planNoLimit,
            ),
          paidRow,
        ]),
        if (a.rollover && hasAmount) _aside(t.planStopAtHint),
      ];
    }
    final paidAccount = _data.accounts[_paidFrom];
    final due = line?.plan?.due ?? a.typedDate;
    final dueText = due == null
        ? null
        : due.year == widget.today.year
        ? sayDate(t, due)
        : sayFullDate(t, due);
    final String part;
    if (draft == null) {
      part = t.planEnterAmountDate;
    } else if ((line?.plan?.each ?? 0) > 0) {
      part = money(line!.plan!.each);
    } else {
      part = t.planNothingMore;
    }
    return [
      _card([
        _fieldRow(
          'plan-amount',
          t.planAmountDue,
          a.amount,
          money: true,
          wrong: missing == PlanMissing.amount,
        ),
        _choiceRow(
          'plan-repeat',
          t.planHowOften,
          planRepeatLabel(t, _data, a),
          () => _pickRepeat(t),
        ),
        if (a.customOn)
          _choiceRow(
            'plan-custom',
            t.planRepeatEvery,
            _customSays(t, a),
            _openCustom,
            wrong: missing == PlanMissing.everyN,
          ),
        dueRow,
        // A weekend rule, for dates that can land on one (not chosen
        // weekdays: those are the days).
        if (a.repeat != PlanRepeat.once &&
            a.repeat != PlanRepeat.payday &&
            a.weekdaysNow == null)
          _choiceRow(
            'plan-weekend',
            t.setupOnWeekend,
            planWeekendLabel(t, a.weekend),
            () => _pickWeekend(t),
          ),
      ]),
      if (a.repeat == PlanRepeat.payday && a.daysAfterNow == 0)
        _aside(t.planOnPayday),
      if (a.endsOn) ...[
        const SizedBox(height: 14),
        _card([
          _asked(
            t.planEnds,
            _segments([
              for (final (e, label) in [
                (PlanEnds.never, t.planEndsNever),
                (PlanEnds.date, t.planEndsOn),
                (PlanEnds.count, t.planEndsAfter),
              ])
                (
                  'plan-ends-${e.name}',
                  label,
                  a.ends == e,
                  () => setState(() => a.ends = e),
                ),
            ]),
          ),
          if (a.ends == PlanEnds.date)
            _choiceRow(
              'plan-end-date',
              t.planEndsOn,
              switch (a.typedEndDate) {
                final d? => sayFullDate(t, d),
                null => '',
              },
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
              'plan-end-count',
              t.planEndsAfter,
              a.endCount,
              number: true,
              wrong: missing == PlanMissing.endCount,
              after: t.planEndsTimes,
            ),
        ]),
      ],
      const SizedBox(height: 14),
      _card([
        paidRow,
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // The amount has the room; the label goes to two lines.
                Expanded(
                  child: Text(
                    t.planSetAsideMonth,
                    style: onest(15, color: Mid.ink2),
                  ),
                ),
                const SizedBox(width: 12),
                // The biggest amount: smaller rather than cut.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Shrink(
                    end: true,
                    Text(
                      part,
                      key: const ValueKey('plan-part'),
                      style: onest(
                        16,
                        weight: 500,
                        color: draft == null ? Mid.ink3 : Mid.ink,
                        tabular: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
      // Warn, don't block: with several checked the bill is in no
      // forecast, said with the count.
      _aside(
        paidAccount != null && dueText != null
            ? t.planPaidFromHint(paidAccount.name, dueText)
            : switch (used) {
                [] => t.planPaidFromNoneChecked,
                [final one] => t.planPaidFromHintNone(one.name),
                final n => t.planPaidFromSeveral(n.length),
              },
      ),
    ];
  }

  /// Custom…'s pattern, as its row says it: "Every 2 weeks", the weekdays
  /// or the nth weekday after it.
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

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return ListenableBuilder(
      listenable: Listenable.merge([_name, _p.typing, widget.store]),
      builder: (context, _) {
        final name = _name.text.trim();
        final note = _nameNote(t, name);
        final draft = _draft;
        // The category as the answers so far make it, in the ledger: the
        // row as it will read on the computer's Budget page, and a dated
        // plan's part each period.
        final category = AccountInfo(
          id: _pageCategoryId,
          name: name,
          type: AccountType.expense,
          currency: _currency,
        );
        final period = budgetPeriod(widget.today, _data.periodSchedule);
        final data = _data
            .withCategory(category)
            .withPlan(_pageCategoryId, draft);
        final line = Budget.of(
          data,
          start: period.start,
          end: period.end,
          today: widget.today,
        ).lines[_pageCategoryId];
        final plan = line?.plan;
        final preview = plan == null
            ? null
            : () {
                final n = planNote(
                  t,
                  line!,
                  period,
                  widget.today,
                  _currency,
                  payName: ownPayName(t, data, plan.plan),
                  own: data.payScheduleById(plan.plan.payScheduleId),
                );
                return n.state == null ? n.text : '${n.text} · ${n.state}';
              }();
        final nameNote =
            note?.text ?? (_tried && name.isEmpty ? t.planEnterName : null);
        // Not once an entry is filed in it: that entry's money is in its
        // account's currency.
        final offerCurrency =
            !widget.forEntry &&
            !(widget.editing != null &&
                widget.store.hasEntriesIn(widget.editing!.id)) &&
            (_currencies.length > 1 || !_currencies.contains(_currency));
        return Scaffold(
          backgroundColor: Mid.ground,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.editing == null
                              ? t.phoneNewCategoryTitle
                              : t.ledgerEditCategory(widget.editing!.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: onest(20, weight: 600),
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('new-category-cancel'),
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          foregroundColor: Mid.blue,
                          textStyle: onest(16),
                        ),
                        child: Text(t.ledgerCancel),
                      ),
                    ],
                  ),
                  if (_added.isNotEmpty)
                    Text(
                      t.planNewAdded(_added.join(' · ')),
                      key: const ValueKey('new-category-added'),
                      style: onest(14, color: Mid.ink2),
                    ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      key: ValueKey('new-category-$_round'),
                      children: [
                        _card([
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: TextField(
                              key: const ValueKey('new-category-name'),
                              controller: _name,
                              // Changing a waiting one opens on what it
                              // says, not under the keyboard.
                              autofocus: widget.editing == null,
                              textCapitalization: TextCapitalization.sentences,
                              style: onest(18, weight: 600),
                              cursorColor: Mid.blue,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: t.planCategoryName,
                                hintStyle: onest(18, color: Mid.ink3),
                              ),
                            ),
                          ),
                          if (offerCurrency)
                            _choiceRow(
                              'money-currency',
                              t.planMoneyCurrency,
                              '${_currency.code} ${_currency.symbol}',
                              () => _pickCurrency(t),
                            ),
                        ]),
                        if (nameNote != null)
                          _aside(
                            nameNote,
                            key: 'new-category-note',
                            color: note == null || note.blocks
                                ? Mid.coral
                                : Mid.ink2,
                          ),
                        const SizedBox(height: 14),
                        _card([
                          _asked(
                            t.planDueDateQ,
                            _segments([
                              (
                                'plan-dated-no',
                                t.planNo,
                                !_p.hasDate,
                                () => setState(() {
                                  _p.hasDate = false;
                                  _tried = false;
                                }),
                              ),
                              (
                                'plan-dated-yes',
                                t.planYes,
                                _p.hasDate,
                                () => setState(() {
                                  _p.hasDate = true;
                                  _tried = false;
                                }),
                              ),
                            ]),
                          ),
                        ]),
                        // What the answer picked means, in one example.
                        _aside(
                          _p.hasDate
                              ? t.planDueYesMeans
                              : _p.eachPayId != null
                              ? t.planDueNoMeansPay
                              : t.planDueNoMeans,
                        ),
                        const SizedBox(height: 14),
                        ..._planRows(t, line: line),
                        const SizedBox(height: 18),
                        // The row, as it will read on the computer's
                        // Budget page once the computer has it.
                        Padding(
                          padding: const EdgeInsets.only(left: 16, bottom: 6),
                          child: Text(
                            t.planRowWillRead,
                            style: onest(14, color: Mid.ink3),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Mid.panel,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isEmpty ? t.planCategoryName : name,
                                style: onest(
                                  16,
                                  weight: 600,
                                  color: name.isEmpty ? Mid.ink3 : Mid.ink,
                                ),
                              ),
                              if (preview != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    preview,
                                    key: const ValueKey('plan-preview'),
                                    style: onest(
                                      14,
                                      color: Mid.ink2,
                                      tabular: true,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (!widget.forEntry && widget.editing == null) ...[
                        Expanded(
                          child: OutlinedButton(
                            key: const ValueKey('new-category-another'),
                            onPressed: () => _add(another: true),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              foregroundColor: Mid.blue,
                              side: BorderSide(color: Mid.rule),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: onest(16, weight: 600),
                            ),
                            child: Text(t.planAddAnother),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: FilledButton(
                          key: const ValueKey('new-category-add'),
                          onPressed: _add,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: Mid.fill,
                            foregroundColor: Mid.onFill,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: onest(17, weight: 600),
                          ),
                          child: Text(
                            widget.editing == null ? t.planAdd : t.planSave,
                          ),
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
    );
  }
}

/// Custom…: how many of which unit, and the weekdays or the nth weekday
/// when the unit has them (owner, 2026-10-05, a calendar app's
/// recurrence). Its own page, as the owner picked; the answers are the
/// New category page's, so Done only goes back.
class _CustomRepeatPage extends StatefulWidget {
  const _CustomRepeatPage({required this.answers});
  final PlanAnswers answers;

  @override
  State<_CustomRepeatPage> createState() => _CustomRepeatPageState();
}

class _CustomRepeatPageState extends State<_CustomRepeatPage> {
  PlanAnswers get _a => widget.answers;

  Widget _chip(
    String label, {
    required String key,
    required bool on,
    required VoidCallback onTap,
  }) => Material(
    color: on ? Mid.blueWash : Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: on ? Mid.blue : Mid.rule),
    ),
    child: InkWell(
      key: ValueKey(key),
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Semantics(
        selected: on,
        button: true,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Text(
              label,
              style: onest(15, color: on ? Mid.ink : Mid.ink2),
            ),
          ),
        ),
      ),
    ),
  );

  Future<T?> _pick<T>(String title, List<(T, String)> items, T chosen) =>
      showModalBottomSheet<T>(
        context: context,
        backgroundColor: Mid.panel,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(title, style: onest(14, color: Mid.ink2)),
              ),
              for (final (value, label) in items)
                ListTile(
                  title: Text(label, style: onest(16, weight: 500)),
                  trailing: value == chosen
                      ? Icon(Icons.check, color: Mid.blue)
                      : null,
                  onTap: () => Navigator.of(context).pop(value),
                ),
            ],
          ),
        ),
      );

  Widget _row(String label, Widget child) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 52),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: onest(15, color: Mid.ink2)),
          ),
          const SizedBox(width: 12),
          child,
        ],
      ),
    ),
  );

  Widget _picker(String key, String label, VoidCallback onTap) => InkWell(
    key: ValueKey(key),
    borderRadius: BorderRadius.circular(10),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: onest(16, weight: 500)),
          Icon(Icons.expand_more_rounded, color: Mid.ink3),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final a = _a;
    return Scaffold(
      backgroundColor: Mid.ground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(t.planCustomOn, style: onest(20, weight: 600)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    Material(
                      color: Mid.card,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _row(
                            t.planRepeatEvery,
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 56,
                                  child: TextField(
                                    key: const ValueKey('plan-every-n'),
                                    controller: a.everyN,
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    style: onest(
                                      16,
                                      weight: 500,
                                      tabular: true,
                                    ),
                                    cursorColor: Mid.blue,
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: a.typedEveryN == null
                                              ? Mid.coral
                                              : Mid.rule,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                _picker(
                                  'plan-every-unit',
                                  planUnitLabel(t, a.unit),
                                  () async {
                                    final u = await _pick(t.planRepeatEvery, [
                                      for (final u in PlanUnit.values)
                                        (u, planUnitLabel(t, u)),
                                    ], a.unit);
                                    if (u != null && mounted) {
                                      setState(() => a.unit = u);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          if (a.unit == PlanUnit.weeks) ...[
                            Divider(height: 1, thickness: 1, color: Mid.rule),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: Text(
                                t.planOnWeekdays,
                                style: onest(15, color: Mid.ink2),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  for (final (i, initial)
                                      in t.rowsWeekdayInitials
                                          .split('|')
                                          .indexed)
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        child: _chip(
                                          initial,
                                          key: 'plan-weekday-${i + 1}',
                                          on: a.weekdays.contains(i + 1),
                                          onTap: () => setState(
                                            () => a.weekdays.contains(i + 1)
                                                ? a.weekdays.remove(i + 1)
                                                : a.weekdays.add(i + 1),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          if (a.unit == PlanUnit.months ||
                              a.unit == PlanUnit.years) ...[
                            Divider(height: 1, thickness: 1, color: Mid.rule),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: Text(
                                t.planOnLabel,
                                style: onest(15, color: Mid.ink2),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Row(
                                children: [
                                  for (final (key, label, on, onTap)
                                      in <(String, String, bool, VoidCallback)>[
                                        (
                                          'plan-nth-off',
                                          t.planDayOfMonth,
                                          !a.nthOn,
                                          () => setState(() => a.nthOn = false),
                                        ),
                                        (
                                          'plan-nth-on',
                                          t.planAWeekday,
                                          a.nthOn,
                                          () => setState(a.startNth),
                                        ),
                                      ])
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(2),
                                        child: Material(
                                          color: on
                                              ? Mid.blueWash
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: InkWell(
                                            key: ValueKey(key),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            onTap: onTap,
                                            child: SizedBox(
                                              height: 44,
                                              child: Center(
                                                child: Text(
                                                  label,
                                                  style: onest(
                                                    15,
                                                    weight: on ? 600 : 400,
                                                    color: on
                                                        ? Mid.blue
                                                        : Mid.ink2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (a.nthOn)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                                child: Row(
                                  children: [
                                    _picker(
                                      'plan-nth',
                                      planNthLabel(t, a.nth),
                                      () async {
                                        final n = await _pick(t.planOnLabel, [
                                          for (final n in const [
                                            1,
                                            2,
                                            3,
                                            4,
                                            -1,
                                          ])
                                            (n, planNthLabel(t, n)),
                                        ], a.nth);
                                        if (n != null && mounted) {
                                          setState(() => a.nth = n);
                                        }
                                      },
                                    ),
                                    _picker(
                                      'plan-nth-weekday',
                                      planWeekdayName(t, a.nthWeekday),
                                      () async {
                                        final wd = await _pick(t.planOnLabel, [
                                          for (var wd = 1; wd <= 7; wd++)
                                            (wd, planWeekdayName(t, wd)),
                                        ], a.nthWeekday);
                                        if (wd != null && mounted) {
                                          setState(() => a.nthWeekday = wd);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    if (a.unit == PlanUnit.weeks && a.weekdays.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(
                          t.planWeekdaysHint,
                          style: onest(14, color: Mid.ink3),
                        ),
                      ),
                  ],
                ),
              ),
              FilledButton(
                key: const ValueKey('custom-done'),
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: Mid.fill,
                  foregroundColor: Mid.onFill,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: onest(17, weight: 600),
                ),
                child: Text(t.rowsSplitDone),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
