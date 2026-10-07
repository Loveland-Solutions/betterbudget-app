part of 'ledger_screen.dart';

// The first half hour (ADR 0004, "Onboarding"): setup inside the app's own
// window. The sidebar is the real one and fills as accounts are added; the
// page holds one step, and the steps are named across the top. So far:
// the accounts, then pay. Everything is written as it's added, so leaving
// and coming back loses nothing.

enum _SetupStep { accounts, pay }

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
    required this.payHistory,
    required this.onDone,
  });
  final LedgerData data;
  final DateTime today;

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
  final VoidCallback onDone;

  @override
  State<_SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<_SetupPage> {
  late var _step = widget.data.prefs[SetupKeys.step] == SetupKeys.stepPay
      ? _SetupStep.pay
      : _SetupStep.accounts;

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
    if (_step == _SetupStep.pay && widget.data.openAccounts.isEmpty) {
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
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _dateFocus.addListener(_dateLeft);
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
            width: 560,
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
        ],
      ],
    );
  }

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
                style: onest(13, color: Mid.gold, height: 1.4),
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
    // Undo took the last account away: back to where one is added.
    final step = some ? _step : _SetupStep.accounts;
    final pay = step == _SetupStep.pay ? _payBody(t, data) : null;
    final forward = switch (step) {
      // Nothing to go on to until there's an account.
      _SetupStep.accounts when some => _PrimaryButton(
        key: const ValueKey('setup-continue'),
        label: t.setupContinue,
        icon: Icons.arrow_forward_rounded,
        tooltip: '',
        onTap: _toPay,
      ),
      // Pay is the last step built. Not while the form is open: what's
      // typed in it would be dropped.
      _SetupStep.pay when pay!.answered => _PrimaryButton(
        key: const ValueKey('setup-done'),
        label: t.setupOpenLedger,
        icon: Icons.arrow_forward_rounded,
        tooltip: '',
        onTap: widget.onDone,
      ),
      _ => null,
    };
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
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 7),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: Mid.ink3,
                ),
              ),
              _stepName(
                'setup-step-pay',
                t.setupStepPay,
                current: step == _SetupStep.pay,
                onTap: some ? _toPay : null,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: pay?.body ?? _accountsBody(t, data),
            ),
          ),
        ),
        if (forward != null || step == _SetupStep.pay)
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
                  if (step == _SetupStep.pay)
                    BarButton(
                      key: const ValueKey('setup-back'),
                      label: t.setupBack,
                      leading: Icon(
                        Icons.arrow_back_rounded,
                        size: 15,
                        color: Mid.ink2,
                      ),
                      onTap: () => _go(_SetupStep.accounts),
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
