part of 'phone_app.dart';

// Setup on the phone (#534, ADR 0004 "Setup on the phone"): the computer's
// first-time setup in the phone's form, for a ledger that has never had an
// account, as one started on the phone has. Three steps named across the
// top, Accounts, Income, and Money you have while there's money to ask
// about, with Back and the way on pinned at the foot. Everything is written
// as it's given, so leaving and coming back loses nothing; each change is
// said with an Undo, the phone's way.

enum _PhoneSetupStep { accounts, pay, money }

/// How much of a currency's money the budget uses.
enum _PhoneHad { all, part, none }

class _PhoneSetup extends StatefulWidget {
  const _PhoneSetup({required this.store, required this.now});
  final PhoneStore store;
  final DateTime Function() now;

  @override
  State<_PhoneSetup> createState() => _PhoneSetupState();
}

class _PhoneSetupState extends State<_PhoneSetup> with _FormRows<_PhoneSetup> {
  late var _step = switch (_data.prefs[SetupKeys.step]) {
    SetupKeys.stepPay => _PhoneSetupStep.pay,
    SetupKeys.stepMoney => _PhoneSetupStep.money,
    _ => _PhoneSetupStep.accounts,
  };

  /// Money you have: Some of it's amount by currency, the answer picked on
  /// this page ahead of the ledger, and what is kept for emergencies.
  final _part = <Currency, TextEditingController>{};
  final _picked = <Currency, _PhoneHad>{};
  late final _emergency = TextEditingController(
    text: switch (setupEmergency(_data)) {
      0 => '',
      final v => _typedAmount(v, mainCurrency(_data)),
    },
  );

  /// A write is under way: a second tap waits.
  var _busy = false;

  LedgerData get _data => widget.store.snapshot.data!;

  @override
  Currency get _currency => mainCurrency(_data);

  @override
  DateTime get _today => dateOnly(widget.now());

  @override
  void initState() {
    super.initState();
    // Kept the moment setup opens, as on the computer: it is the day the
    // balances are as of, and says setup is under way, so the first
    // account added doesn't end it.
    if (_data.prefs[SetupKeys.date] == null) {
      unawaited(_keep({SetupKeys.date: dateKey(_today)}));
    }
    // An amount is kept when its field is left, as on the computer, so
    // closing the app loses nothing typed.
    final emergency = _focus('setup-emergency');
    emergency.addListener(() {
      if (!emergency.hasFocus) _keepEmergency();
    });
  }

  void _keepEmergency() {
    final v = _emergencyAmount;
    if (v == null || v == setupEmergency(_data)) return;
    unawaited(_keep({SetupKeys.emergency: v == 0 ? null : '$v'}));
  }

  void _keepPart(Currency c) {
    final v = _partAmount(c);
    if (v == null || _choice(c) != _PhoneHad.part) return;
    if (_data.prefs[SetupKeys.had(c)] == '$v') return;
    unawaited(_keep({SetupKeys.had(c): '$v'}));
  }

  @override
  void dispose() {
    for (final c in _part.values) {
      c.dispose();
    }
    _emergency.dispose();
    _disposeFocuses();
    super.dispose();
  }

  static String _typedAmount(int v, Currency c) =>
      '${formatWhole(v, c)}${c.hasCents(v) ? formatCents(v, c) : ''}';

  /// Does [act]; a refusal is said, and nothing else changes.
  Future<PhoneActed?> _act(PhoneRowAct act) async {
    try {
      return await widget.store.actRow(act);
    } catch (e) {
      debugPrint('A setup change on the phone failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              persist: false,
              duration: phoneSnackTime,
              key: const ValueKey('setup-refused'),
              backgroundColor: Mid.raised,
              content: Text(
                context.t.ledgerCouldntSave,
                style: onest(15, color: Mid.ink),
              ),
            ),
          );
      }
      return null;
    }
  }

  /// Does [act] and says [said] with its Undo.
  Future<void> _actSaid(PhoneRowAct act, String said) async {
    if (_busy) return;
    _busy = true;
    try {
      final done = await _act(act);
      if (done != null && mounted) {
        _saidWithUndo(context, widget.store, done, said, 'setup-said');
      }
    } finally {
      _busy = false;
    }
  }

  /// An answer kept as it's given, with nothing to say: where setup is, and
  /// Money you have's answers, as the computer keeps them.
  Future<void> _keep(Map<String, String?> values) async {
    try {
      await widget.store.actRow(PhoneSavingsAnswer(values));
    } catch (e) {
      debugPrint('Keeping a setup answer failed: $e');
    }
  }

  void _go(_PhoneSetupStep step) {
    if (step == _step) return;
    // The last step's Undo would sit over this one's questions.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _step = step);
    unawaited(
      _keep({
        SetupKeys.step: switch (step) {
          _PhoneSetupStep.accounts => SetupKeys.stepAccounts,
          _PhoneSetupStep.pay => SetupKeys.stepPay,
          _PhoneSetupStep.money => SetupKeys.stepMoney,
        },
      }),
    );
  }

  Future<void> _addAccount(AccountType type, {bool cash = false}) async {
    // Setup under way before its first account, or that account ends it.
    if (_data.prefs[SetupKeys.date] == null) {
      await _keep({SetupKeys.date: dateKey(_today)});
      if (!mounted) return;
    }
    final done = await _openNewAccount(
      context,
      store: widget.store,
      today: _today,
      type: type,
      cash: cash,
      setupDate: setupDate(_data, _today),
    );
    if (done != null && mounted) _accountSaid(context, widget.store, done);
  }

  Future<void> _pickDate() async {
    final now = setupDate(_data, _today);
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(_today.year - 30),
      lastDate: _today,
    );
    if (d == null || !mounted || dateOnly(d) == now) return;
    await _actSaid(PhoneSetupDate(dateOnly(d)), context.t.setupDateChanged);
  }

  // ---------- Money you have ----------

  TextEditingController _partOf(Currency c) => _part.putIfAbsent(c, () {
    final focus = _focus('setup-had-${c.code}');
    focus.addListener(() {
      if (!focus.hasFocus) _keepPart(c);
    });
    final v = int.tryParse(_data.prefs[SetupKeys.had(c)] ?? '');
    return TextEditingController(text: v == null ? '' : _typedAmount(v, c));
  });

  _PhoneHad _choice(Currency c) {
    if (_picked[c] case final h?) return h;
    return switch (_data.prefs[SetupKeys.had(c)]) {
      null || SetupKeys.hadAll => _PhoneHad.all,
      SetupKeys.hadNone => _PhoneHad.none,
      _ => _PhoneHad.part,
    };
  }

  int? _partAmount(Currency c) => parseAmount(_partOf(c).text, c);

  /// What the budget will use of [c]'s money as the page shows it; null
  /// while Some of it has nothing that can be read.
  int? _hadNow(Currency c, int held) => switch (_choice(c)) {
    _PhoneHad.all => held,
    _PhoneHad.none => 0,
    _PhoneHad.part => _partAmount(c),
  };

  void _pickHad(Currency c, _PhoneHad h) {
    setState(() => _picked[c] = h);
    final v = switch (h) {
      _PhoneHad.all => SetupKeys.hadAll,
      _PhoneHad.none => SetupKeys.hadNone,
      _PhoneHad.part => switch (_partAmount(c)) {
        final int v => '$v',
        null => null,
      },
    };
    if (v != null) unawaited(_keep({SetupKeys.had(c): v}));
    if (h == _PhoneHad.part) _focus('setup-had-${c.code}').requestFocus();
  }

  /// The emergency amount as typed: 0 when empty, null when unreadable.
  int? get _emergencyAmount => _emergency.text.trim().isEmpty
      ? 0
      : parseAmount(_emergency.text, _currency);

  /// It counts only while its question is on the page.
  int? get _emergencyCounted {
    final held = setupHeld(_data)[_currency];
    if (held == null || (_hadNow(_currency, held) ?? 0) <= 0) return 0;
    return _emergencyAmount;
  }

  String _safetyNetName(Words t) =>
      _data.accounts.values
          .where((a) => !a.deleted && isSafetyNet(a))
          .firstOrNull
          ?.name ??
      t.planFundCategoryName;

  /// Setup ends with what the page shows: an amount that can't be read is
  /// focused and setup stays.
  Future<void> _finish() async {
    if (_busy) return;
    final t = context.t;
    final messenger = ScaffoldMessenger.of(context);
    final had = <Currency, int>{};
    for (final MapEntry(key: c, value: held) in setupHeld(_data).entries) {
      final v = _hadNow(c, held);
      if (v == null) {
        _focus('setup-had-${c.code}').requestFocus();
        return;
      }
      had[c] = v;
    }
    final emergency = _emergencyCounted;
    if (emergency == null) {
      _focus('setup-emergency').requestFocus();
      return;
    }
    // Held from the first tap: a second one would finish a finished setup,
    // and its Undo would put back "done" (code review).
    _busy = true;
    try {
      // What was typed is kept with the finish.
      await _keep({
        for (final MapEntry(key: c, value: v) in had.entries)
          if (_choice(c) == _PhoneHad.part) SetupKeys.had(c): '$v',
        SetupKeys.emergency: emergency == 0 ? null : '$emergency',
      });
      if (!mounted) return;
      final done = await _act(
        PhoneFinishSetup(
          had: had,
          emergency: emergency,
          safetyNetName: _safetyNetName(t),
        ),
      );
      // Setup has left the screen: the bar goes on Budget.
      if (done != null) {
        _saidWithUndoOn(
          messenger,
          widget.store,
          done,
          t.setupFinished,
          undo: t.ledgerUndo,
          refused: t.ledgerCouldntSave,
        );
      }
    } finally {
      _busy = false;
    }
  }

  // ---------- the page ----------

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: onest(26, weight: 600, height: 1.2)),
  );

  Widget _line(String text, {String? key, Color? color}) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      key: key == null ? null : ValueKey(key),
      style: onest(15, color: color ?? Mid.ink2, height: 1.4),
    ),
  );

  Widget _outlined(String key, String label, VoidCallback onTap) =>
      OutlinedButton.icon(
        key: ValueKey(key),
        onPressed: onTap,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 48),
          foregroundColor: Mid.blue,
          side: BorderSide(color: Mid.rule),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: onest(15, weight: 500),
        ),
      );

  Widget _filled(String key, String label, VoidCallback? onTap) => FilledButton(
    key: ValueKey(key),
    onPressed: onTap,
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      backgroundColor: Mid.fill,
      foregroundColor: Mid.onFill,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: onest(17, weight: 600),
    ),
    child: Text(label, textAlign: TextAlign.center),
  );

  String _typeWord(Words t, AccountInfo a) => a.isOwed
      ? t.setupKindOwed
      : (a.isCash ? t.setupKindCash : t.setupKindBank);

  List<Widget> _accountsBody(Words t) {
    final data = _data;
    final accounts = data.openAccounts;
    final everyday = data.prefs[SetupKeys.everyday];
    final noCash =
        (everyday == SetupKeys.everydayCash ||
            everyday == SetupKeys.everydayBoth) &&
        !accounts.any((a) => a.isCash);
    // Each currency on its own line: they're never added together. A total
    // is shown only over two or more accounts: over one it repeats it.
    final held = <Currency, int>{}, owing = <Currency, int>{};
    for (final a in accounts) {
      final count = a.isOwed ? owing : held;
      count[a.currency] = (count[a.currency] ?? 0) + 1;
    }
    final totals = <Currency, ({int held, int owed})>{};
    for (final a in accounts) {
      final was = totals[a.currency] ?? (held: 0, owed: 0);
      final b = data.balanceOf(a.id);
      totals[a.currency] = a.isOwed
          ? (held: was.held, owed: was.owed - b)
          : (held: was.held + b, owed: was.owed);
    }
    return [
      _heading(t.setupYourAccounts),
      _line(t.setupAddTracked),
      _line(t.setupNeverConnects),
      const SizedBox(height: 16),
      _card([
        _choiceRow(
          'setup-date',
          t.setupBalancesAsOf,
          sayFullDate(t, setupDate(data, _today)),
          _pickDate,
        ),
      ]),
      const SizedBox(height: 16),
      if (accounts.isNotEmpty) ...[
        Material(
          key: const ValueKey('setup-accounts'),
          color: Mid.card,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, a) in accounts.indexed) ...[
                if (i > 0) Divider(height: 1, thickness: 1, color: Mid.rule),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.name,
                              overflow: TextOverflow.ellipsis,
                              style: onest(16, weight: 500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _typeWord(t, a),
                              style: onest(14, color: Mid.ink2),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatMoney(
                              a.isOwed
                                  ? -data.balanceOf(a.id)
                                  : data.balanceOf(a.id),
                              currency: a.currency,
                            ),
                            key: ValueKey('setup-balance-${a.id}'),
                            style: onest(16, tabular: true),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            a.isOwed ? t.setupYouOwe : t.setupBalance,
                            style: onest(13, color: Mid.ink3),
                          ),
                        ],
                      ),
                      IconButton(
                        key: ValueKey('setup-remove-${a.id}'),
                        tooltip: t.setupRemoveAccount(a.name),
                        onPressed: () => _actSaid(
                          PhoneDeleteAccount(a.id),
                          t.ledgerDeleted(a.name),
                        ),
                        icon: Icon(Icons.close_rounded, color: Mid.ink3),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        for (final e in totals.entries)
          if ((held[e.key] ?? 0) > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      cashBankLabel(t, data),
                      style: onest(15, color: Mid.ink2),
                    ),
                  ),
                  Text(
                    formatMoney(e.value.held, currency: e.key),
                    key: ValueKey('setup-held-${e.key.code}'),
                    style: onest(15, weight: 600, tabular: true),
                  ),
                ],
              ),
            ),
        for (final e in totals.entries)
          if (e.value.owed != 0 && (owing[e.key] ?? 0) > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  t.ledgerOwed(formatMoney(e.value.owed, currency: e.key)),
                  key: ValueKey('setup-owed-${e.key.code}'),
                  // Owed isn't a shortfall: ordinary ink (owner's colours).
                  style: onest(15, color: Mid.ink2, tabular: true),
                ),
              ),
            ),
        const SizedBox(height: 16),
      ],
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // With nothing added yet, the usual first account is the one
          // filled button on the page.
          if (accounts.isEmpty)
            FilledButton.icon(
              key: const ValueKey('setup-add-bank'),
              onPressed: () => _addAccount(AccountType.asset),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(t.setupKindBank),
              style: FilledButton.styleFrom(
                minimumSize: const Size(44, 48),
                backgroundColor: Mid.fill,
                foregroundColor: Mid.onFill,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: onest(15, weight: 600),
              ),
            )
          else
            _outlined(
              'setup-add-bank',
              t.setupKindBank,
              () => _addAccount(AccountType.asset),
            ),
          _outlined(
            'setup-add-cash',
            t.setupKindCash,
            () => _addAccount(AccountType.asset, cash: true),
          ),
          _outlined(
            'setup-add-owed',
            t.setupKindOwed,
            () => _addAccount(AccountType.liability),
          ),
        ],
      ),
      // Asked only while the answer can change something: with a Cash
      // account there, there is nothing left to warn about.
      if (accounts.isNotEmpty && !accounts.any((a) => a.isCash)) ...[
        const SizedBox(height: 20),
        _card([
          _asked(
            t.setupEverydayQ,
            _choices([
              for (final (value, label) in [
                (SetupKeys.everydayBank, t.setupEverydayBank),
                (SetupKeys.everydayCash, t.setupEverydayCash),
                (SetupKeys.everydayBoth, t.setupEverydayBoth),
              ])
                (
                  'setup-everyday-$value',
                  label,
                  everyday == value,
                  () => unawaited(_keep({SetupKeys.everyday: value})),
                ),
            ]),
          ),
        ]),
        // Said, with the way to fix it, and never required.
        if (noCash) ...[
          _aside(t.setupNoCashWarning, key: 'setup-no-cash', color: Mid.note),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _outlined(
                'setup-add-cash-now',
                t.setupAddCashAccount,
                () => _addAccount(AccountType.asset, cash: true),
              ),
            ),
          ),
        ],
      ],
    ];
  }

  List<Widget> _payBody(Words t) {
    final data = _data;
    final into = data.openAccounts.where((a) => !a.isOwed).toList();
    final pays = data.paySchedules;
    final none = data.prefs[noRegularPayKey] == '1';
    return [
      _heading(t.setupYourPay),
      const SizedBox(height: 8),
      if (into.isEmpty)
        _line(t.setupPayNeedsAccount, key: 'setup-pay-needs-account')
      else ...[
        if (pays.isNotEmpty || none)
          _card([
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
                  return InkWell(
                    key: ValueKey('setup-edit-pay-${p.id}'),
                    onTap: () => unawaited(
                      _openPay(
                        context,
                        store: widget.store,
                        today: _today,
                        existing: p,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  payTitle(t, data, p),
                                  style: onest(16, weight: 500),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  t.planPayInto(amounts, account?.name ?? ''),
                                  style: onest(14, color: Mid.ink2),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: Mid.ink3),
                        ],
                      ),
                    ),
                  );
                },
              ),
            if (pays.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  t.setupNoRegularPayLine,
                  key: const ValueKey('setup-no-pay-line'),
                  style: onest(16),
                ),
              ),
          ]),
        const SizedBox(height: 12),
        if (pays.isEmpty && !none)
          FilledButton.icon(
            key: const ValueKey('setup-add-pay'),
            onPressed: () => unawaited(
              _openPay(context, store: widget.store, today: _today),
            ),
            icon: const Icon(Icons.add_rounded),
            label: Text(t.setupAddYourPay),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: Mid.fill,
              foregroundColor: Mid.onFill,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: onest(17, weight: 600),
            ),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: _outlined(
              'setup-add-pay',
              pays.isEmpty ? t.setupAddYourPay : t.setupAddOtherPay,
              () => unawaited(
                _openPay(context, store: widget.store, today: _today),
              ),
            ),
          ),
        if (pays.isEmpty)
          TextButton(
            key: const ValueKey('setup-no-pay'),
            onPressed: () =>
                unawaited(_sayNoPay(context, widget.store, none: !none)),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: Mid.blue,
              textStyle: onest(16),
            ),
            child: Text(none ? t.setupAskAgain : t.setupNoRegularPay),
          ),
        // Asked once there's pay: month or paycheck, month by default
        // (owner, 2026-11-16, #474).
        if (pays.isNotEmpty) ...[
          const SizedBox(height: 20),
          _card([
            _asked(
              t.setupBudgetByQ,
              _choices([
                (
                  'budget-by-month',
                  t.planByMonth,
                  data.periodSchedule == null,
                  () => _budgetBy(null),
                ),
                for (final p in pays)
                  (
                    'budget-by-${p.id}',
                    pays.length == 1
                        ? t.planByPaycheck
                        : t.planByPaychecksOf(payTitle(t, data, p)),
                    data.periodSchedule?.id == p.id,
                    () => _budgetBy(p),
                  ),
              ]),
            ),
          ]),
          _aside(t.budgetByHint),
        ],
      ],
    ];
  }

  void _budgetBy(PaySchedule? p) {
    if (p?.id == _data.periodSchedule?.id) return;
    final t = context.t;
    unawaited(
      _actSaid(
        PhoneBudgetBy(p?.id),
        p == null
            ? t.ledgerBudgetByMonth
            : t.ledgerBudgetByPayPeriod(payTitle(t, _data, p)),
      ),
    );
  }

  /// A field for an amount in [c], on its own line.
  Widget _amountField(
    String key,
    TextEditingController controller,
    Currency c, {
    required bool wrong,
    VoidCallback? onDone,
  }) => TextField(
    key: ValueKey(key),
    controller: controller,
    focusNode: _focus(key),
    onChanged: (_) => setState(() {}),
    onSubmitted: (_) => onDone?.call(),
    inputFormatters: [GroupedAmount(c)],
    keyboardType: TextInputType.numberWithOptions(decimal: c.decimals > 0),
    textInputAction: TextInputAction.done,
    style: onest(17, weight: 500, tabular: true),
    cursorColor: Mid.blue,
    decoration: InputDecoration(
      prefixText: c.prefix,
      hintText: formatRounded(0, currency: c),
      hintStyle: onest(17, color: Mid.ink3),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: wrong ? Mid.coral : Mid.rule),
      ),
    ),
  );

  List<Widget> _moneyBody(Words t) {
    final data = _data;
    final held = setupHeld(data);
    final main = _currency;
    final owes = data.openAccounts.any(
      (a) => a.isOwed && data.balanceOf(a.id) != 0,
    );
    final usedMain = held.containsKey(main) ? _hadNow(main, held[main]!) : null;
    final emergency = _emergencyAmount;
    final short = (emergency ?? 0) - (usedMain ?? 0);
    return [
      _heading(t.setupMoneyHeading),
      _line(t.setupMoneyLine),
      const SizedBox(height: 16),
      Material(
        key: const ValueKey('setup-money-accounts'),
        color: Mid.card,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.setupFromAccounts, style: onest(14, color: Mid.ink3)),
              const SizedBox(height: 6),
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
                            style: onest(15),
                          ),
                        ),
                        Text(
                          formatMoney(
                            data.balanceOf(a.id),
                            currency: a.currency,
                          ),
                          style: onest(15, tabular: true),
                        ),
                      ],
                    ),
                  ),
              for (final MapEntry(key: c, value: v) in held.entries)
                // Over one account the total only repeats it.
                if (data.openAccounts
                        .where((a) => !a.isOwed && a.currency == c)
                        .length >
                    1)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Mid.rule)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            cashBankLabel(t, data),
                            style: onest(15, weight: 600),
                          ),
                        ),
                        Text(
                          formatMoney(v, currency: c),
                          style: onest(15, weight: 600, tabular: true),
                        ),
                      ],
                    ),
                  ),
              if (owes) ...[
                const SizedBox(height: 8),
                Text(
                  t.setupOwedNote,
                  key: const ValueKey('setup-owed-note'),
                  style: onest(14, color: Mid.ink3, height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ),
      for (final MapEntry(key: c, value: amount) in held.entries) ...[
        const SizedBox(height: 16),
        Builder(
          builder: (context) {
            final choice = _choice(c);
            final part = _partOf(c);
            final used = _hadNow(c, amount);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _card([
                  _choices([
                    (
                      'setup-had-all-${c.code}',
                      t.setupHadAll(formatShort(amount, currency: c)),
                      choice == _PhoneHad.all,
                      () => _pickHad(c, _PhoneHad.all),
                    ),
                    (
                      'setup-had-part-${c.code}',
                      t.setupHadPart,
                      choice == _PhoneHad.part,
                      () => _pickHad(c, _PhoneHad.part),
                    ),
                    (
                      'setup-had-none-${c.code}',
                      t.setupHadNone,
                      choice == _PhoneHad.none,
                      () => _pickHad(c, _PhoneHad.none),
                    ),
                  ]),
                  if (choice == _PhoneHad.part)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _amountField(
                        'setup-had-${c.code}',
                        part,
                        c,
                        wrong: part.text.trim().isNotEmpty && used == null,
                        onDone: () => _keepPart(c),
                      ),
                    ),
                ]),
                _aside(
                  switch (used) {
                    null when part.text.trim().isNotEmpty => t.setupCantRead(
                      part.text.trim(),
                    ),
                    null => t.phoneSetupHadType,
                    0 => t.setupHadNoneLine,
                    // Said, never refused: more than there is starts short.
                    final int v when v > amount => t.setupHadMore(
                      formatShort(v - amount, currency: c),
                    ),
                    // The phone has no Settings page yet to point to.
                    final int v => t.phoneSetupHadUses(
                      formatShort(v, currency: c),
                    ),
                  },
                  key: 'setup-had-line-${c.code}',
                  color:
                      (used == null && part.text.trim().isNotEmpty) ||
                          (used != null && used > amount)
                      ? Mid.coral
                      : Mid.ink2,
                ),
              ],
            );
          },
        ),
      ],
      // Asked while the budget uses some of its own currency's money: the
      // Safety net is in that currency.
      if ((usedMain ?? 0) > 0) ...[
        const SizedBox(height: 20),
        _card([
          _asked(
            t.setupEmergencyQ,
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _amountField(
                'setup-emergency',
                _emergency,
                main,
                wrong: emergency == null,
                onDone: _keepEmergency,
              ),
            ),
          ),
        ]),
        _aside(
          emergency == null
              ? t.setupCantRead(_emergency.text.trim())
              : t.setupEmergencyHint(_safetyNetName(t)),
          color: emergency == null ? Mid.coral : Mid.ink2,
        ),
        // Said, never refused: more than the budget uses starts it short.
        if (emergency != null && short > 0)
          _aside(
            t.setupEmergencyMore(formatShort(short, currency: main)),
            key: 'setup-emergency-more',
            color: Mid.coral,
          ),
      ],
    ];
  }

  /// One step's name across the top; the one on the page underlined, one
  /// that can't be gone to yet grey.
  Widget _stepName(
    String key,
    String label, {
    required bool current,
    VoidCallback? onTap,
  }) => InkWell(
    key: ValueKey(key),
    onTap: current ? null : onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Center(
        widthFactor: 1,
        child: Container(
          padding: const EdgeInsets.only(bottom: 4),
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
              15,
              weight: current ? 600 : 400,
              color: current ? Mid.ink : (onTap == null ? Mid.ink3 : Mid.ink2),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final t = context.t;
      final data = _data;
      final some = data.openAccounts.isNotEmpty;
      final asksMoney = some && setupAsksMoney(data);
      // Pay is answered, never skipped: by a pay or "I don't have regular
      // income".
      final payAnswered =
          data.paySchedules.isNotEmpty || data.prefs[noRegularPayKey] == '1';
      // Undo took the last account away: back to where one is added; the
      // money away: back to pay.
      final step = !some
          ? _PhoneSetupStep.accounts
          : _step == _PhoneSetupStep.money && !asksMoney
          ? _PhoneSetupStep.pay
          : _step;
      final emergency = asksMoney ? _emergencyCounted ?? 0 : 0;
      final finish = _filled(
        'setup-done',
        // A tap that moves money says where it goes (owner-corrections).
        emergency > 0
            ? t.setupFinishAssign(
                formatShort(emergency, currency: _currency),
                _safetyNetName(t),
              )
            : t.setupOpenLedger,
        _finish,
      );
      final forward = switch (step) {
        // Nothing to go on to until there's an account.
        _PhoneSetupStep.accounts when some => _filled(
          'setup-continue',
          t.setupContinue,
          () => _go(_PhoneSetupStep.pay),
        ),
        _PhoneSetupStep.pay when payAnswered && asksMoney => _filled(
          'setup-continue',
          t.setupContinue,
          () => _go(_PhoneSetupStep.money),
        ),
        _PhoneSetupStep.pay when payAnswered => finish,
        _PhoneSetupStep.money => finish,
        _ => null,
      };
      Widget chevron() =>
          Icon(Icons.chevron_right_rounded, size: 18, color: Mid.ink3);
      final before = _before(step);
      // The way on in the bar at the foot, which a snack bar's Undo rises
      // above instead of covering; Back before the step names, and the
      // phone's own back goes to the step before too.
      return PopScope(
        canPop: before == null,
        onPopInvokedWithResult: (popped, _) {
          if (!popped && before != null) _go(before);
        },
        child: Scaffold(
          backgroundColor: Mid.ground,
          bottomNavigationBar: forward == null
              ? null
              : SafeArea(child: _foot(forward)),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    before == null ? 16 : 4,
                    8,
                    16,
                    0,
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (before != null)
                        IconButton(
                          key: const ValueKey('setup-back'),
                          tooltip: t.setupBack,
                          onPressed: () => _go(before),
                          icon: Icon(Icons.arrow_back_rounded, color: Mid.blue),
                        ),
                      _stepName(
                        'setup-step-accounts',
                        t.setupStepAccounts,
                        current: step == _PhoneSetupStep.accounts,
                        onTap: () => _go(_PhoneSetupStep.accounts),
                      ),
                      chevron(),
                      _stepName(
                        'setup-step-pay',
                        t.setupStepPay,
                        current: step == _PhoneSetupStep.pay,
                        onTap: some ? () => _go(_PhoneSetupStep.pay) : null,
                      ),
                      // Named only while there's money to ask about.
                      if (asksMoney) ...[
                        chevron(),
                        _stepName(
                          'setup-step-money',
                          t.setupStepMoney,
                          current: step == _PhoneSetupStep.money,
                          onTap: payAnswered
                              ? () => _go(_PhoneSetupStep.money)
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    children: switch (step) {
                      _PhoneSetupStep.accounts => _accountsBody(t),
                      _PhoneSetupStep.pay => _payBody(t),
                      _PhoneSetupStep.money => _moneyBody(t),
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _foot(Widget forward) => Container(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
    decoration: BoxDecoration(
      color: Mid.panel,
      border: Border(top: BorderSide(color: Mid.rule)),
    ),
    child: forward,
  );

  /// The step before [step], where Back and the phone's back go.
  static _PhoneSetupStep? _before(_PhoneSetupStep step) => switch (step) {
    _PhoneSetupStep.accounts => null,
    _PhoneSetupStep.pay => _PhoneSetupStep.accounts,
    _PhoneSetupStep.money => _PhoneSetupStep.pay,
  };
}

/// [_saidWithUndo] on [messenger], for a change that takes its own page
/// off the screen (setup's finish): the words are given, since the page's
/// context is gone by the time Undo is tapped.
void _saidWithUndoOn(
  ScaffoldMessengerState messenger,
  PhoneStore store,
  PhoneActed change,
  String said, {
  required String undo,
  required String refused,
}) => messenger
  ..hideCurrentSnackBar()
  ..showSnackBar(
    SnackBar(
      persist: false,
      duration: phoneSnackTime,
      key: const ValueKey('setup-said'),
      backgroundColor: Mid.raised,
      content: Text(said, style: onest(15, color: Mid.ink)),
      action: SnackBarAction(
        label: undo,
        textColor: Mid.blue,
        onPressed: () async {
          try {
            await store.replay(change.undo);
          } catch (e) {
            debugPrint('Undoing on the phone failed: $e');
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  persist: false,
                  duration: phoneSnackTime,
                  backgroundColor: Mid.raised,
                  content: Text(refused, style: onest(15, color: Mid.ink)),
                ),
              );
          }
        },
      ),
    ),
  );
