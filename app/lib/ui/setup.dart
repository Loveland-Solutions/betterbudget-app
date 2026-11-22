part of 'ledger_screen.dart';

// The first half hour (ADR 0004, "Onboarding"): setup inside the app's own
// window. The sidebar is the real one and fills as accounts are added; the
// page holds one step, and the steps are named across the top: the
// accounts, then pay, then the money they have (#475). Everything is written
// as it's added, so leaving and coming back loses nothing.

enum _SetupStep { accounts, pay, money }

/// How much of a currency's money the budget uses: all, part or none.
enum _Had { all, part, none }

/// An amount as it's typed in a field: `2,000,000`, with cents only when
/// there are some.
String _fieldAmount(int v, Currency c) =>
    '${formatWhole(v, c)}${c.hasCents(v) ? formatCents(v, c) : ''}';

class _SetupPage extends StatefulWidget {
  const _SetupPage({
    super.key,
    required this.data,
    required this.today,
    required this.onDate,
    required this.onAdd,
    required this.onRemove,
    required this.onEveryday,
    required this.onStep,
    required this.onPay,
    required this.onBudgetBy,
    required this.payHistory,
    required this.onHad,
    required this.onEmergency,
    required this.onDone,
  });
  final LedgerData data;
  final DateTime today;

  /// Budget by month (null) or by a pay's paychecks (#474).
  final ValueChanged<PaySchedule?> onBudgetBy;

  /// The one day every balance is as of was changed.
  final ValueChanged<DateTime> onDate;

  /// An account and what's in it. [typed] is as the bank shows it: what's
  /// owed is positive. Null starts the account empty.
  final Future<void> Function(
    String name,
    AccountType type,
    bool cash,
    Currency currency,
    int? typed,
  )
  onAdd;
  final ValueChanged<AccountInfo> onRemove;

  /// One of [SetupKeys.everydayBank], `everydayCash`, `everydayBoth`.
  final ValueChanged<String> onEveryday;

  /// The step now on the page, [SetupKeys.stepAccounts] or `stepPay`, to
  /// come back to after a quit.
  final ValueChanged<String> onStep;

  /// What the pay form answered; [existing] is the pay that was edited.
  /// False when it couldn't be written.
  final Future<bool> Function(PaySetupResult result, PaySchedule? existing)
  onPay;

  /// Recent pay into an account from a payer, newest first.
  final Future<List<int>> Function(
    int accountId,
    String payee,
    PaySchedule? existing,
  )
  payHistory;

  /// "Money you have" was answered for a currency: [SetupKeys.hadAll],
  /// `hadNone`, or an amount in its smallest units.
  final void Function(Currency c, String value) onHad;

  /// The amount kept for emergencies was typed (null: none).
  final Future<void> Function(int? amount) onEmergency;

  /// Setup ends: [had] is what the budget uses of each currency's money,
  /// [emergency] what goes into the Safety net.
  final Future<void> Function(Map<Currency, int> had, int emergency) onDone;

  @override
  State<_SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<_SetupPage> {
  late var _step = switch (widget.data.prefs[SetupKeys.step]) {
    SetupKeys.stepPay => _SetupStep.pay,
    SetupKeys.stepMoney => _SetupStep.money,
    _ => _SetupStep.accounts,
  };

  /// Money you have: the amount typed beside Part of it, by currency, and
  /// the amount kept for emergencies. Written when left, and read again
  /// when setup ends, so what's typed and not yet left still counts.
  final _part = <Currency, TextEditingController>{};
  final _emergency = TextEditingController();
  final _emergencyFocus = FocusNode(debugLabel: 'setup-emergency');
  final _partFocus = <Currency, FocusNode>{};

  /// The answer picked on this page, ahead of the ledger: Part of it with
  /// nothing typed yet writes nothing, and a Part amount left as All or
  /// None is clicked isn't written over them (code review).
  final _picked = <Currency, _Had>{};

  /// Setup is ending: a second click waits.
  bool _finishing = false;

  /// The pay form is open for another pay, or to edit the pay with this id.
  /// With no pay and no answer yet it is open anyway.
  bool _payAdding = false;
  int? _payEditing;

  /// An answer from the pay form is being written: a second click waits.
  bool _paySaving = false;

  /// Esc from anywhere on the page: closes the pay form when there is
  /// something to go back to. False when there was nothing to close.
  bool closePayForm() {
    if (!_payAdding && _payEditing == null) return false;
    setState(() {
      _payAdding = false;
      _payEditing = null;
    });
    return true;
  }

  /// The row being typed, with the Type its button gave it.
  ({AccountType type, bool cash})? _adding;

  /// The line being typed keeps what's in it when another Type's button is
  /// clicked, and is added before setup is left.
  final _entryKey = GlobalKey<_SetupAccountEntryState>();
  Future<void>? _added;
  late final _date = TextEditingController(text: fullDate(_stored));
  final _dateFocus = FocusNode(debugLabel: 'setup-date');

  /// The day last handed to [_SetupPage.onDate], until the ledger has it.
  DateTime? _sent;

  DateTime get _stored => setupDate(widget.data, widget.today);

  @override
  void didUpdateWidget(_SetupPage old) {
    super.didUpdateWidget(old);
    // Undo put the date back: the field follows unless it's being typed in.
    if (setupDate(old.data, old.today) != _stored) _sent = null;
    // Undo took the last account away: back to where one is added, and
    // adding one doesn't jump on to Pay.
    // Undo took the money away: nothing left to ask about.
    if (_step == _SetupStep.money && !setupAsksMoney(widget.data)) {
      _step = _SetupStep.pay;
      widget.onStep(SetupKeys.stepPay);
    }
    if (_step != _SetupStep.accounts && widget.data.openAccounts.isEmpty) {
      _step = _SetupStep.accounts;
      _payAdding = false;
      _payEditing = null;
      widget.onStep(SetupKeys.stepAccounts);
    }
    if (setupDate(old.data, old.today) != _stored && !_dateFocus.hasFocus) {
      _date.text = fullDate(_stored);
    }
  }

  @override
  void dispose() {
    _date.dispose();
    _dateFocus.dispose();
    _emergency.dispose();
    _emergencyFocus.dispose();
    for (final c in _part.values) {
      c.dispose();
    }
    for (final f in _partFocus.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _dateFocus.addListener(_dateLeft);
    final kept = setupEmergency(widget.data);
    if (kept > 0) {
      _emergency.text = _fieldAmount(kept, mainCurrency(widget.data));
    }
    _emergencyFocus.addListener(() {
      if (!_emergencyFocus.hasFocus) _emergencyLeft();
    });
  }

  Currency get _main => mainCurrency(widget.data);

  /// The amount kept for emergencies, as typed: 0 when empty, null when it
  /// can't be read.
  int? get _emergencyAmount =>
      _emergency.text.trim().isEmpty ? 0 : parseAmount(_emergency.text, _main);

  /// The emergency amount that counts: only while its question is on the
  /// page, which is while the budget uses some of its own currency's money.
  /// Null when it can't be read.
  int? get _emergencyCounted {
    final held = setupHeld(widget.data)[_main];
    if (held == null || (_hadNow(_main, held) ?? 0) <= 0) return 0;
    return _emergencyAmount;
  }

  void _emergencyLeft() {
    final v = _emergencyAmount;
    if (v == null || v == setupEmergency(widget.data)) return;
    widget.onEmergency(v == 0 ? null : v);
  }

  TextEditingController _partOf(Currency c) => _part.putIfAbsent(c, () {
    final kept = widget.data.prefs[SetupKeys.had(c)];
    final v = int.tryParse(kept ?? '');
    return TextEditingController(text: v == null ? '' : _fieldAmount(v, c));
  });

  FocusNode _partFocusOf(Currency c) => _partFocus.putIfAbsent(c, () {
    final f = FocusNode(debugLabel: 'setup-part-${c.code}');
    f.addListener(() {
      if (!f.hasFocus) _partLeft(c);
    });
    return f;
  });

  int? _partAmount(Currency c) => parseAmount(_partOf(c).text, c);

  void _partLeft(Currency c) {
    final v = _partAmount(c);
    if (v == null || _choice(c) != _Had.part) return;
    if (widget.data.prefs[SetupKeys.had(c)] == '$v') return;
    widget.onHad(c, '$v');
  }

  /// How [c]'s money was answered.
  _Had _choice(Currency c) {
    if (_picked[c] case final h?) return h;
    return switch (widget.data.prefs[SetupKeys.had(c)]) {
      null || SetupKeys.hadAll => _Had.all,
      SetupKeys.hadNone => _Had.none,
      _ => _Had.part,
    };
  }

  void _pick(Currency c, _Had h) {
    setState(() => _picked[c] = h);
    switch (h) {
      case _Had.all:
        widget.onHad(c, SetupKeys.hadAll);
      case _Had.none:
        widget.onHad(c, SetupKeys.hadNone);
      case _Had.part:
        final v = _partAmount(c);
        if (v != null) widget.onHad(c, '$v');
        _partFocusOf(c).requestFocus();
    }
  }

  /// What the budget will use of [c]'s money, as the page shows it now;
  /// null while Part of it has no amount that can be read.
  int? _hadNow(Currency c, int held) => switch (_choice(c)) {
    _Had.all => held,
    _Had.none => 0,
    _Had.part => _partAmount(c),
  };

  /// Setup ends with what the page shows. An amount that can't be read is
  /// focused, and setup stays.
  Future<void> _finish() async {
    if (_finishing) return;
    final had = <Currency, int>{};
    for (final MapEntry(key: c, value: held) in setupHeld(
      widget.data,
    ).entries) {
      final v = _hadNow(c, held);
      if (v == null) {
        _partFocusOf(c).requestFocus();
        return;
      }
      had[c] = v;
    }
    final emergency = _emergencyCounted;
    if (emergency == null) {
      _emergencyFocus.requestFocus();
      return;
    }
    _finishing = true;
    try {
      await widget.onDone(had, emergency);
    } finally {
      _finishing = false;
    }
  }

  /// A date typed and left without Enter still counts; one that can't be
  /// read goes back to the date the balances are filed under.
  void _dateLeft() {
    if (_dateFocus.hasFocus) return;
    if (_day == null) {
      _date.text = fullDate(_stored);
    } else {
      _dateGiven();
    }
  }

  /// The date in the field, when it reads as a day that has come.
  DateTime? get _day => switch (parseEntryDate(_date.text, widget.today)) {
    final d? when !d.isAfter(widget.today) => d,
    _ => null,
  };

  void _dateGiven() {
    final day = _day;
    if (day == null) return;
    _date.text = fullDate(day);
    // The calendar under the field closes: it sits over the Add buttons.
    _dateFocus.unfocus();
    // Leaving the field gives the same day again: it's sent once.
    if (day == _stored || day == _sent) return;
    _sent = day;
    widget.onDate(day);
  }

  /// On to pay with a line still being typed: the line is what the person
  /// meant to add, so it's added first. One whose amount can't be read says
  /// so and the step stays.
  Future<void> _toPay() async {
    final entry = _entryKey.currentState;
    if (entry != null && entry.touched) {
      if (!entry.add()) return;
      await _added;
    }
    if (mounted) _go(_SetupStep.pay);
  }

  /// On to the money, from the step names: a line still being typed on
  /// the accounts is added first, as on the way to pay.
  Future<void> _toMoney() async {
    final entry = _entryKey.currentState;
    if (entry != null && entry.touched) {
      if (!entry.add()) return;
      await _added;
    }
    if (mounted) _go(_SetupStep.money);
  }

  /// Steps only move: everything on them is already written.
  void _go(_SetupStep step) {
    if (step == _step) return;
    setState(() {
      _step = step;
      _adding = null;
      _payAdding = false;
      _payEditing = null;
    });
    widget.onStep(switch (step) {
      _SetupStep.accounts => SetupKeys.stepAccounts,
      _SetupStep.pay => SetupKeys.stepPay,
      _SetupStep.money => SetupKeys.stepMoney,
    });
  }

  /// One step's name in the row across the top. The step on the page is
  /// underlined; one that can't be gone to yet is grey.
  Widget _stepName(
    String key,
    String label, {
    required bool current,
    VoidCallback? onTap,
  }) => Hoverable(
    key: ValueKey(key),
    onTap: current ? null : onTap,
    builder: (hover) => Container(
      padding: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            width: 2,
            color: current ? Mid.blue : Colors.transparent,
          ),
        ),
      ),
      child: Text(
        label,
        style: onest(
          13.5,
          weight: current ? 600 : 400,
          color: current || (hover && onTap != null)
              ? Mid.ink
              : (onTap == null ? Mid.ink3 : Mid.ink2),
        ),
      ),
    ),
  );

  /// The pays as a list, or the one line "No regular pay", each with the
  /// way to change it.
  Widget _payList(Words t, LedgerData data, {required bool canAdd}) {
    final pays = data.paySchedules;
    Widget row(String title, String? under, Widget button) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 9, 12, 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: onest(13.5, weight: 500)),
                if (under != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    under,
                    style: onest(12.5, color: Mid.ink2, tabular: true),
                  ),
                ],
              ],
            ),
          ),
          button,
        ],
      ),
    );
    return Container(
      key: const ValueKey('setup-pays'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Mid.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Mid.rule),
      ),
      child: Column(
        children: [
          for (final p in pays)
            Builder(
              builder: (context) {
                final account = data.accounts[p.accountId];
                final amounts = payAmounts(
                  t,
                  p,
                  (v) => formatShort(
                    v,
                    currency: account?.currency ?? Currency.mnt,
                  ),
                  dotted: true,
                );
                final next = data
                    .registerFor(p.accountId)
                    .scheduled
                    .where((r) => r.payScheduleId == p.id)
                    .firstOrNull
                    ?.date;
                return row(
                  payTitle(t, data, p),
                  next == null
                      ? t.planPayInto(amounts, account?.name ?? '')
                      : t.planPayIntoNext(
                          amounts,
                          account?.name ?? '',
                          sayDate(t, next),
                        ),
                  canAdd
                      ? BarButton(
                          key: ValueKey('setup-edit-pay-${p.id}'),
                          label: t.setupEdit,
                          onTap: () => setState(() {
                            _payAdding = false;
                            _payEditing = p.id;
                          }),
                        )
                      : const SizedBox.shrink(),
                );
              },
            ),
          if (pays.isEmpty)
            row(
              t.setupNoRegularPayLine,
              null,
              canAdd
                  ? BarButton(
                      key: const ValueKey('setup-add-pay'),
                      label: t.setupAddYourPay,
                      onTap: () => setState(() => _payAdding = true),
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  /// The Pay step: the form that exists, on the page. Open until pay is
  /// answered, by a pay or by "I don't have regular pay"; after that the
  /// answer is listed, with Edit and a way to add another earner's pay.
  ({List<Widget> body, bool answered}) _payBody(Words t, LedgerData data) {
    final into = data.openAccounts.where((a) => !a.isOwed).toList();
    final pays = data.paySchedules;
    final none = data.prefs[noRegularPayKey] == '1';
    final editing = pays.where((p) => p.id == _payEditing).firstOrNull;
    final open =
        into.isNotEmpty &&
        (editing != null || _payAdding || (pays.isEmpty && !none));
    final heading = SizedBox(
      height: 36,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          t.setupYourPay,
          style: onest(22, weight: 600, letterSpacing: -0.3),
        ),
      ),
    );
    void close() => setState(() {
      _payAdding = false;
      _payEditing = null;
    });
    return (
      answered: !open,
      body: [
        heading,
        const SizedBox(height: 16),
        if (open)
          SizedBox(
            width: 924,
            child: _PayForm(
              key: ValueKey('setup-pay-form-${editing?.id}'),
              page: true,
              accounts: into,
              category: data.income,
              account:
                  into.where((a) => a.id == editing?.accountId).firstOrNull ??
                  // Pay lands in a bank far more often than in a wallet.
                  into.where((a) => !a.isCash).firstOrNull ??
                  into.first,
              today: widget.today,
              existing: editing,
              history: (a, payee) => widget.payHistory(a, payee, editing),
              data: data,
              perPay: [
                if (editing != null)
                  for (final c in data.categories)
                    if (data.plans[c.id]?.payScheduleId == editing.id) c,
              ],
              offerNoPay: pays.isEmpty && !none,
              onResult: (result) async {
                if (_paySaving) return;
                _paySaving = true;
                try {
                  // Not written: the form stays, with what was typed.
                  if (await widget.onPay(result, editing) && mounted) close();
                } catch (e) {
                  debugPrint('Saving pay failed: $e');
                } finally {
                  _paySaving = false;
                }
              },
              // The first pay has nothing to go back to: the two answers
              // are Save pay and "I don't have regular pay".
              onCancel: pays.isEmpty && !none ? null : close,
            ),
          )
        else ...[
          // Only an account that owes: pay has nowhere to go.
          if (into.isEmpty)
            Text(
              t.setupPayNeedsAccount,
              key: const ValueKey('setup-pay-needs-account'),
              style: onest(13.5, color: Mid.ink2, height: 1.4),
            ),
          if (pays.isNotEmpty || none) ...[
            if (into.isEmpty) const SizedBox(height: 12),
            _payList(t, data, canAdd: into.isNotEmpty),
          ],
          if (pays.isNotEmpty && into.isNotEmpty) ...[
            const SizedBox(height: 16),
            _addButton(
              'setup-add-other-pay',
              t.setupAddOtherPay,
              () => setState(() => _payAdding = true),
            ),
          ],
          // Asked once there's pay: month or paycheck, month by default
          // (owner, 2026-11-16, #474).
          if (pays.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(t.setupBudgetByQ, style: onest(15, weight: 600)),
            const SizedBox(height: 4),
            Text(
              t.budgetByHint,
              style: onest(13, color: Mid.ink2, height: 1.4),
            ),
            const SizedBox(height: 10),
            _BudgetByChoice(data: data, onPick: widget.onBudgetBy),
          ],
        ],
      ],
    );
  }

  /// The Money you have step (#475): how much of what the accounts hold
  /// the budget uses, since it counts income from the day it began and
  /// never the bank; then how much of it is kept for emergencies.
  List<Widget> _moneyBody(Words t, LedgerData data) {
    final held = setupHeld(data);
    final main = _main;
    final owes = data.openAccounts.any(
      (a) => a.isOwed && data.balanceOf(a.id) != 0,
    );
    final usedMain = held.containsKey(main) ? _hadNow(main, held[main]!) : null;
    final emergency = _emergencyAmount;
    final short = (emergency ?? 0) - (usedMain ?? 0);
    Widget answers(Currency c, int amount) {
      final choice = _choice(c);
      final part = _partOf(c);
      final used = _hadNow(c, amount);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Segmented(
                items: [
                  (
                    'setup-had-all-${c.code}',
                    t.setupHadAll(formatShort(amount, currency: c)),
                    choice == _Had.all,
                    () => _pick(c, _Had.all),
                  ),
                  (
                    'setup-had-part-${c.code}',
                    t.setupHadPart,
                    choice == _Had.part,
                    () => _pick(c, _Had.part),
                  ),
                  (
                    'setup-had-none-${c.code}',
                    t.setupHadNone,
                    choice == _Had.none,
                    () => _pick(c, _Had.none),
                  ),
                ],
              ),
              if (choice == _Had.part)
                SizedBox(
                  width: 170,
                  height: 34,
                  child: TextField(
                    key: ValueKey('setup-had-amount-${c.code}'),
                    controller: part,
                    focusNode: _partFocusOf(c),
                    inputFormatters: [GroupedAmount(c)],
                    textAlign: TextAlign.right,
                    style: onest(13.5, tabular: true),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _partLeft(c),
                    decoration: _fieldDecoration(
                      hint: formatRounded(0, currency: c),
                      wrong: part.text.trim().isNotEmpty && used == null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            switch (used) {
              null when part.text.trim().isNotEmpty => t.setupCantRead(
                part.text.trim(),
              ),
              0 => t.setupHadNoneLine,
              // Said, never refused: more than there is starts it short.
              final int v when v > amount => t.setupHadMore(
                formatShort(v - amount, currency: c),
              ),
              final int v => t.setupHadUses(formatShort(v, currency: c)),
              null => '',
            },
            key: ValueKey('setup-had-line-${c.code}'),
            style: onest(
              13,
              color: used == null || used > amount ? Mid.coral : Mid.ink2,
              height: 1.4,
            ),
          ),
        ],
      );
    }

    final accounts = Container(
      key: const ValueKey('setup-money-accounts'),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: Mid.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Mid.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.setupFromAccounts, style: onest(12.5, color: Mid.ink3)),
          const SizedBox(height: 8),
          for (final a in data.openAccounts)
            if (!a.isOwed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        a.name,
                        overflow: TextOverflow.ellipsis,
                        style: onest(13.5),
                      ),
                    ),
                    Text(
                      formatMoney(data.balanceOf(a.id), currency: a.currency),
                      style: onest(13.5, tabular: true),
                    ),
                  ],
                ),
              ),
          for (final MapEntry(key: c, value: v) in held.entries) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Mid.rule)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      cashBankLabel(t, data),
                      style: onest(13.5, weight: 600),
                    ),
                  ),
                  Text(
                    formatMoney(v, currency: c),
                    style: onest(13.5, weight: 600, tabular: true),
                  ),
                ],
              ),
            ),
          ],
          if (owes) ...[
            const SizedBox(height: 10),
            Text(
              t.setupOwedNote,
              key: const ValueKey('setup-owed-note'),
              style: onest(12.5, color: Mid.ink3, height: 1.4),
            ),
          ],
        ],
      ),
    );

    return [
      SizedBox(
        height: 36,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            t.setupMoneyHeading,
            style: onest(22, weight: 600, letterSpacing: -0.3),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(t.setupMoneyLine, style: onest(13.5, color: Mid.ink2, height: 1.4)),
      const SizedBox(height: 20),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, MapEntry(key: c, value: v))
                    in held.entries.indexed) ...[
                  if (i > 0) const SizedBox(height: 18),
                  answers(c, v),
                ],
              ],
            ),
          ),
          const SizedBox(width: 32),
          SizedBox(width: 360, child: accounts),
        ],
      ),
      // Asked while the budget uses some of its own currency's money:
      // the Safety net is in that currency.
      if ((usedMain ?? 0) > 0) ...[
        const SizedBox(height: 24),
        Container(height: 1, color: Mid.rule),
        const SizedBox(height: 18),
        Text(t.setupEmergencyQ, style: onest(15, weight: 600)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 170,
              height: 34,
              child: TextField(
                key: const ValueKey('setup-emergency'),
                controller: _emergency,
                focusNode: _emergencyFocus,
                inputFormatters: [GroupedAmount(main)],
                textAlign: TextAlign.right,
                style: onest(13.5, tabular: true),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _emergencyLeft(),
                decoration: _fieldDecoration(
                  hint: formatRounded(0, currency: main),
                  wrong: emergency == null,
                ),
              ),
            ),
            Text(
              emergency == null
                  ? t.setupCantRead(_emergency.text.trim())
                  : t.setupEmergencyHint(_safetyNetName(t, data)),
              style: onest(
                13,
                color: emergency == null ? Mid.coral : Mid.ink2,
                height: 1.4,
              ),
            ),
          ],
        ),
        // Said, never refused: more than the budget uses starts it short.
        if (emergency != null && short > 0) ...[
          const SizedBox(height: 8),
          Text(
            t.setupEmergencyMore(formatShort(short, currency: main)),
            key: const ValueKey('setup-emergency-more'),
            style: onest(13, color: Mid.coral, height: 1.4),
          ),
        ],
      ],
    ];
  }

  /// The Safety net's name: the category's, once there is one.
  String _safetyNetName(Words t, LedgerData data) =>
      data.accounts.values
          .where((a) => !a.deleted && isSafetyNet(a))
          .firstOrNull
          ?.name ??
      t.planFundCategoryName;

  void _open(AccountType type, {bool cash = false}) =>
      setState(() => _adding = (type: type, cash: cash));

  String _typeWord(Words t, AccountInfo a) => a.isOwed
      ? t.setupKindOwed
      : (a.isCash ? t.setupKindCash : t.setupKindBank);

  Widget _addButton(String key, String label, VoidCallback onTap) => BarButton(
    key: ValueKey(key),
    label: label,
    leading: Icon(Icons.add_rounded, size: 15, color: Mid.ink2),
    onTap: onTap,
  );

  /// The Accounts step.
  List<Widget> _accountsBody(Words t, LedgerData data) {
    final accounts = data.openAccounts;
    final adding = _adding;
    final everyday = data.prefs[SetupKeys.everyday];
    final noCash =
        (everyday == SetupKeys.everydayCash ||
            everyday == SetupKeys.everydayBoth) &&
        !accounts.any((a) => a.isCash) &&
        !(adding?.cash ?? false);
    // One total only while every account is in one currency: currencies
    // are never added together, and the sidebar has each account's figure.
    // Each currency on its own line: they're never added together.
    final totals = <Currency, ({int held, int owed})>{};
    for (final a in accounts) {
      final was = totals[a.currency] ?? (held: 0, owed: 0);
      final b = data.balanceOf(a.id);
      totals[a.currency] = a.isOwed
          ? (held: was.held, owed: was.owed - b)
          : (held: was.held + b, owed: was.owed);
    }
    final wrongDate = _day == null;
    return [
      SizedBox(
        height: 36,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            t.setupYourAccounts,
            style: onest(22, weight: 600, letterSpacing: -0.3),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(t.setupAddTracked, style: onest(13.5, color: Mid.ink2, height: 1.4)),
      Text(
        t.setupNeverConnects,
        style: onest(13.5, color: Mid.ink2, height: 1.4),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Text(t.setupBalancesAsOf, style: onest(13.5, color: Mid.ink2)),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            height: 34,
            child: DateField(
              key: const ValueKey('setup-date'),
              controller: _date,
              focusNode: _dateFocus,
              today: widget.today,
              allowFuture: false,
              small: true,
              wanted: wrongDate,
              onSubmitted: _dateGiven,
              onPicked: _dateGiven,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Row(
        spacing: 8,
        children: [
          // With nothing added yet, the usual first account is
          // the one filled button on the page.
          if (accounts.isEmpty && adding == null)
            _PrimaryButton(
              key: const ValueKey('setup-add-bank'),
              label: t.setupKindBank,
              icon: Icons.add_rounded,
              onTap: () => _open(AccountType.asset),
            )
          else
            _addButton(
              'setup-add-bank',
              t.setupKindBank,
              () => _open(AccountType.asset),
            ),
          _addButton(
            'setup-add-cash',
            t.setupKindCash,
            () => _open(AccountType.asset, cash: true),
          ),
          _addButton(
            'setup-add-owed',
            t.setupKindOwed,
            () => _open(AccountType.liability),
          ),
        ],
      ),
      if (accounts.isNotEmpty || adding != null) ...[
        const SizedBox(height: 16),
        Container(
          key: const ValueKey('setup-accounts'),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Mid.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Mid.rule),
          ),
          child: Column(
            children: [
              for (final a in accounts)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 9, 12, 9),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          a.name,
                          overflow: TextOverflow.ellipsis,
                          style: onest(13.5, weight: 500),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          _typeWord(t, a),
                          overflow: TextOverflow.ellipsis,
                          style: onest(13.5, color: Mid.ink2),
                        ),
                      ),
                      Text(
                        a.isOwed ? t.setupYouOwe : t.setupBalance,
                        style: onest(12.5, color: Mid.ink3),
                      ),
                      SizedBox(
                        width: 170,
                        child: Text(
                          formatMoney(
                            a.isOwed
                                ? -data.balanceOf(a.id)
                                : data.balanceOf(a.id),
                            currency: a.currency,
                          ),
                          key: ValueKey('setup-balance-${a.id}'),
                          textAlign: TextAlign.right,
                          style: onest(13.5, tabular: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: t.setupRemoveAccount(a.name),
                        child: Hoverable(
                          key: ValueKey('setup-remove-${a.id}'),
                          onTap: () => widget.onRemove(a),
                          builder: (hover) => Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: hover ? Mid.raised : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: hover ? Mid.ink : Mid.ink3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (adding != null)
                _SetupAccountEntry(
                  key: _entryKey,
                  type: adding.type,
                  cash: adding.cash,
                  currency: mainCurrency(data),
                  onAdd: (name, currency, typed) {
                    _added = widget.onAdd(
                      name,
                      adding.type,
                      adding.cash,
                      currency,
                      typed,
                    );
                    setState(() => _adding = null);
                  },
                  onCancel: () => setState(() => _adding = null),
                ),
            ],
          ),
        ),
      ],
      if (accounts.isNotEmpty) const SizedBox(height: 8),
      for (final e in totals.entries)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(cashBankLabel(t, data), style: onest(13.5, color: Mid.ink2)),
              const SizedBox(width: 10),
              Text(
                formatMoney(e.value.held, currency: e.key),
                key: ValueKey('setup-held-${e.key.code}'),
                style: onest(13.5, weight: 600, tabular: true),
              ),
              if (e.value.owed != 0) ...[
                const SizedBox(width: 28),
                Text(
                  t.ledgerOwed(formatMoney(e.value.owed, currency: e.key)),
                  key: ValueKey('setup-owed-${e.key.code}'),
                  style: onest(13.5, color: Mid.coral, tabular: true),
                ),
              ],
              const SizedBox(width: 48),
            ],
          ),
        ),
      // Asked only while the answer can change something: with a
      // Cash account there, there is nothing left to warn about.
      if (accounts.isNotEmpty && !accounts.any((a) => a.isCash)) ...[
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(t.setupEverydayQ, style: onest(13.5, weight: 500)),
            ),
            for (final (value, label) in [
              (SetupKeys.everydayBank, t.setupEverydayBank),
              (SetupKeys.everydayCash, t.setupEverydayCash),
              (SetupKeys.everydayBoth, t.setupEverydayBoth),
            ])
              BarButton(
                key: ValueKey('setup-everyday-$value'),
                label: label,
                active: everyday == value,
                onTap: () => widget.onEveryday(value),
              ),
          ],
        ),
        // Said, with the way to fix it, and never required: cash
        // nobody records makes the budget read richer than it is.
        if (noCash) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                t.setupNoCashWarning,
                key: const ValueKey('setup-no-cash'),
                style: onest(13, color: Mid.note, height: 1.4),
              ),
              BarButton(
                key: const ValueKey('setup-add-cash-now'),
                label: t.setupAddCashAccount,
                onTap: () => _open(AccountType.asset, cash: true),
              ),
            ],
          ),
        ],
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final data = widget.data;
    final some = data.openAccounts.isNotEmpty;
    final asksMoney = some && setupAsksMoney(data);
    // Pay is answered, never skipped: by a pay or "I don't have regular
    // pay".
    final payAnswered =
        data.paySchedules.isNotEmpty || data.prefs[noRegularPayKey] == '1';
    // Undo took the last account away: back to where one is added; the
    // money away: back to pay.
    final step = !some
        ? _SetupStep.accounts
        : _step == _SetupStep.money && !asksMoney
        ? _SetupStep.pay
        : _step;
    final pay = step == _SetupStep.pay ? _payBody(t, data) : null;
    final emergency = asksMoney ? _emergencyCounted ?? 0 : 0;
    final finish = _PrimaryButton(
      key: const ValueKey('setup-done'),
      // A click that moves money says where it goes (owner-corrections).
      label: emergency > 0
          ? t.setupFinishAssign(
              formatShort(emergency, currency: _main),
              _safetyNetName(t, data),
            )
          : t.setupOpenLedger,
      icon: Icons.arrow_forward_rounded,
      tooltip: '',
      onTap: _finish,
    );
    final forward = switch (step) {
      // Nothing to go on to until there's an account.
      _SetupStep.accounts when some => _PrimaryButton(
        key: const ValueKey('setup-continue'),
        label: t.setupContinue,
        icon: Icons.arrow_forward_rounded,
        tooltip: '',
        onTap: _toPay,
      ),
      // Not while the pay form is open: what's typed in it would be
      // dropped.
      _SetupStep.pay when pay!.answered && asksMoney => _PrimaryButton(
        key: const ValueKey('setup-continue'),
        label: t.setupContinue,
        icon: Icons.arrow_forward_rounded,
        tooltip: '',
        onTap: () => _go(_SetupStep.money),
      ),
      _SetupStep.pay when pay!.answered => finish,
      _SetupStep.money => finish,
      _ => null,
    };
    Widget chevron() => Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 7),
      child: Icon(Icons.chevron_right_rounded, size: 16, color: Mid.ink3),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 0),
          child: Row(
            children: [
              _stepName(
                'setup-step-accounts',
                t.setupStepAccounts,
                current: step == _SetupStep.accounts,
                onTap: () => _go(_SetupStep.accounts),
              ),
              chevron(),
              _stepName(
                'setup-step-pay',
                t.setupStepPay,
                current: step == _SetupStep.pay,
                onTap: some ? _toPay : null,
              ),
              // Named only while there's money to ask about.
              if (asksMoney) ...[
                chevron(),
                _stepName(
                  'setup-step-money',
                  t.setupStepMoney,
                  current: step == _SetupStep.money,
                  onTap: payAnswered ? _toMoney : null,
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  pay?.body ??
                  (step == _SetupStep.money
                      ? _moneyBody(t, data)
                      : _accountsBody(t, data)),
            ),
          ),
        ),
        if (forward != null || step != _SetupStep.accounts)
          Container(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Mid.rule)),
            ),
            // As tall with Back alone as with the filled button beside it.
            child: SizedBox(
              height: 36,
              child: Row(
                children: [
                  if (step != _SetupStep.accounts)
                    BarButton(
                      key: const ValueKey('setup-back'),
                      label: t.setupBack,
                      leading: Icon(
                        Icons.arrow_back_rounded,
                        size: 15,
                        color: Mid.ink2,
                      ),
                      onTap: () => _go(
                        step == _SetupStep.money
                            ? _SetupStep.pay
                            : _SetupStep.accounts,
                      ),
                    ),
                  const Spacer(),
                  ?forward,
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// One account being typed in setup's list: its name, its currency and
/// what's in it, on one line. Enter from either field adds it; Esc or
/// Cancel closes the line.
class _SetupAccountEntry extends StatefulWidget {
  const _SetupAccountEntry({
    super.key,
    required this.type,
    required this.cash,
    required this.currency,
    required this.onAdd,
    required this.onCancel,
  });
  final AccountType type;
  final bool cash;

  /// Where the currency choice starts.
  final Currency currency;
  final void Function(String name, Currency currency, int? typed) onAdd;
  final VoidCallback onCancel;

  @override
  State<_SetupAccountEntry> createState() => _SetupAccountEntryState();
}

class _SetupAccountEntryState extends State<_SetupAccountEntry> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _amountFocus = FocusNode(debugLabel: 'setup-amount');
  late var _currency = widget.currency;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  bool get _empty => _amount.text.trim().isEmpty;
  int? get _parsed => parseAmount(_amount.text, _currency);

  /// Something has been typed in the line.
  bool get touched => _name.text.trim().isNotEmpty || !_empty;

  String _typeWord(Words t) => widget.type == AccountType.liability
      ? t.setupKindOwed
      : (widget.cash ? t.setupKindCash : t.setupKindBank);

  /// Adds the account; false, with the amount field focused, when the
  /// amount can't be read. A name left empty is the Type's word, which is
  /// what the field shows in grey.
  bool add() {
    if (!_empty && _parsed == null) {
      _amountFocus.requestFocus();
      return false;
    }
    final name = _name.text.trim();
    widget.onAdd(
      name.isEmpty ? _typeWord(context.t) : name,
      _currency,
      _empty ? null : _parsed,
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final owed = widget.type == AccountType.liability;
    final zero = formatRounded(0, currency: _currency);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onCancel,
      },
      child: ListenableBuilder(
        listenable: _amount,
        builder: (context, _) {
          final wrong = !_empty && _parsed == null;
          return Container(
            key: const ValueKey('setup-entry'),
            margin: const EdgeInsets.fromLTRB(6, 4, 6, 0),
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: Mid.blueWash,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 34,
                        child: TextField(
                          key: const ValueKey('setup-name'),
                          controller: _name,
                          autofocus: true,
                          style: onest(13.5),
                          onSubmitted: (_) => add(),
                          decoration: _fieldDecoration(hint: _typeWord(t)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _CurrencyMenu(
                      buttonKey: 'setup-currency',
                      itemPrefix: 'setup-currency-',
                      currencies: Currency.values,
                      currency: _currency,
                      onPick: (c) => setState(() => _currency = c),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      owed ? t.setupYouOwe : t.setupBalance,
                      style: onest(13.5, color: Mid.ink2),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 170,
                      height: 34,
                      child: TextField(
                        key: const ValueKey('setup-amount'),
                        controller: _amount,
                        inputFormatters: [GroupedAmount(_currency)],
                        focusNode: _amountFocus,
                        textAlign: TextAlign.right,
                        style: onest(13.5, tabular: true),
                        onSubmitted: (_) => add(),
                        decoration: _fieldDecoration(hint: zero, wrong: wrong),
                      ),
                    ),
                    const SizedBox(width: 12),
                    BarButton(
                      key: const ValueKey('setup-cancel'),
                      label: t.setupCancel,
                      onTap: widget.onCancel,
                    ),
                    _PrimaryButton(
                      key: const ValueKey('setup-add'),
                      label: t.setupAddAccount,
                      icon: Icons.add_rounded,
                      tooltip: 'Enter',
                      onTap: add,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // A term deposit goes here too: there's no fourth button.
                if (!owed && !widget.cash && !wrong)
                  Text(
                    t.setupKindBankHint,
                    style: onest(12.5, color: Mid.ink3),
                  ),
                Text(
                  wrong
                      ? t.setupCantRead(_amount.text.trim())
                      : owed
                      ? t.setupStartOwedHint(zero)
                      : widget.cash
                      ? t.setupStartCashHint(zero)
                      : t.setupStartBankHint(zero),
                  style: onest(12.5, color: wrong ? Mid.coral : Mid.ink3),
                ),
                // The one way the figure a bank shows for a card is wrong
                // on the day it's read.
                if (owed && !wrong)
                  Text(
                    t.setupOwedTodayHint,
                    style: onest(12.5, color: Mid.ink3),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
