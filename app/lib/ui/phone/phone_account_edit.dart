part of 'phone_app.dart';

// Adding and changing accounts on the phone (#529, owner's pick of sketch C):
// Add account on the Accounts page, and the ⋯ beside the account chosen on
// the Ledger tab with Rename, Change to…, Payments come out of, Archive… and
// Delete…. Each is the computer's, said with its words: an archive or a
// delete that leaves something behind says exactly what first, then goes
// ahead (owner, 2026-09-18: warn, don't block), and every one has an Undo in
// a snack bar and reaches the computers as an ordinary change.

/// What an account act did: the change to undo, what to say, and the
/// account the Ledger should show next.
class _AccountDone {
  const _AccountDone(this.change, this.said, {this.show, this.import = false});
  final PhoneActed change;
  final String said;
  final int? show;

  /// Add account's "Or import a file from your bank": the bank's file is
  /// opened into [show] next, and answers what was in it.
  final bool import;
}

/// Opens Add account; the page hands back what was done.
/// From setup (#534): [type] and [cash] are the button's, and every
/// balance is on [setupDate], the one day setup asks once.
Future<_AccountDone?> _openNewAccount(
  BuildContext context, {
  required PhoneStore store,
  required DateTime today,
  AccountType type = AccountType.asset,
  bool cash = false,
  DateTime? setupDate,
}) => Navigator.of(context).push(
  MaterialPageRoute<_AccountDone>(
    builder: (_) => _NewAccountPage(
      store: store,
      today: today,
      type: type,
      cash: cash,
      setupDate: setupDate,
    ),
  ),
);

/// Says [said] with an Undo of [change].
void _accountSaid(BuildContext context, PhoneStore store, _AccountDone done) =>
    _saidWithUndo(context, store, done.change, done.said, 'account-done');

/// Does [act] and says what it did; a refusal says so instead.
Future<PhoneActed?> _doAccount(
  BuildContext context,
  PhoneStore store,
  PhoneRowAct act,
) async {
  try {
    return await store.actRow(act);
  } catch (e) {
    debugPrint('An account change on the phone failed: $e');
    if (!context.mounted) return null;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          duration: phoneSnackTime,
          key: const ValueKey('account-refused'),
          backgroundColor: Mid.raised,
          content: Text(
            context.t.ledgerCouldntSave,
            style: onest(15, color: Mid.ink),
          ),
        ),
      );
    return null;
  }
}

/// What the ⋯ menu's items are.
enum _AccountAct { edit, archive, delete }

/// The ⋯ beside the account chosen.
class _AccountMenu extends StatelessWidget {
  const _AccountMenu({required this.account, required this.onPick});
  final AccountInfo account;
  final ValueChanged<_AccountAct> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return SizedBox(
      width: 40,
      height: 44,
      child: PopupMenuButton<_AccountAct>(
        key: const ValueKey('account-menu'),
        color: Mid.raised,
        padding: EdgeInsets.zero,
        iconSize: 24,
        icon: Icon(Icons.more_horiz_rounded, color: Mid.ink2),
        onSelected: onPick,
        itemBuilder: (_) => [
          for (final (act, label, color) in [
            (_AccountAct.edit, t.accountEditMenu, Mid.ink),
            (_AccountAct.archive, t.setupArchiveMenu, Mid.ink),
            (_AccountAct.delete, t.setupDeleteMenu, Mid.coral),
          ])
            PopupMenuItem<_AccountAct>(
              key: ValueKey('account-act-${act.name}'),
              value: act,
              child: Text(label, style: onest(16, color: color)),
            ),
        ],
      ),
    );
  }
}

/// Does what the ⋯ menu picked for [account]. Returns whether the account
/// has left the Ledger's view (archived or deleted).
Future<bool> _runAccountAct(
  BuildContext context, {
  required PhoneStore store,
  required AccountInfo account,
  required _AccountAct act,
  required DateTime today,
}) async {
  final t = context.t;
  final data = store.snapshot.data!;
  switch (act) {
    case _AccountAct.edit:
      final edit = await Navigator.of(context).push(
        MaterialPageRoute<AccountEdit>(
          builder: (_) => _EditAccountPage(store: store, account: account),
        ),
      );
      if (edit == null || !context.mounted) return false;
      final done = await _doAccount(
        context,
        store,
        PhoneEditAccount(account.id, edit),
      );
      if (done != null && context.mounted) {
        _accountSaid(
          context,
          store,
          _AccountDone(done, t.accountEdited(edit.name)),
        );
      }
      return false;
    case _AccountAct.archive:
      final lines = archiveWarnings(
        account,
        data.balanceOf(account.id),
        data.registerFor(account.id).scheduled,
      );
      // Nothing left behind, nothing to read first.
      if (lines.isNotEmpty) {
        final go = await showDialog<bool>(
          context: context,
          builder: (_) => _AccountAsk(
            title: t.ledgerArchiveTitle(account.name),
            lines: lines,
            action: t.ledgerArchiveAction(account.name),
            danger: false,
          ),
        );
        if (go != true || !context.mounted) return false;
      }
      final done = await _doAccount(
        context,
        store,
        PhoneArchiveAccount(account.id, true),
      );
      if (done == null || !context.mounted) return false;
      _accountSaid(
        context,
        store,
        _AccountDone(done, t.ledgerAccountArchivedToast(account.name)),
      );
      return true;
    case _AccountAct.delete:
      final preview = data.deletePreview(account.id);
      // Nothing in it and nothing kept elsewhere: nothing to read first.
      final empty = preview.rows == 0 && preview.keptOn.isEmpty;
      if (!empty) {
        final go = await showDialog<bool>(
          context: context,
          builder: (_) => _AccountAsk(
            title: t.ledgerDeleteTitle(account.name),
            lines: deleteWarnings(account, data.balanceOf(account.id), preview),
            action: t.ledgerDeleteAction(account.name),
            danger: true,
          ),
        );
        if (go != true || !context.mounted) return false;
      }
      final done = await _doAccount(
        context,
        store,
        PhoneDeleteAccount(account.id),
      );
      if (done == null || !context.mounted) return false;
      _accountSaid(
        context,
        store,
        _AccountDone(done, t.ledgerDeleted(account.name)),
      );
      return true;
  }
}

/// What archiving or deleting leaves behind, said exactly, then Cancel or
/// go ahead.
class _AccountAsk extends StatelessWidget {
  const _AccountAsk({
    required this.title,
    required this.lines,
    required this.action,
    required this.danger,
  });
  final String title, action;
  final List<Say> lines;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return AlertDialog(
      key: const ValueKey('account-ask'),
      backgroundColor: Mid.panel,
      title: Text(title, style: onest(18, weight: 600)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(line(t), style: onest(15)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('account-ask-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.setupCancel),
        ),
        TextButton(
          key: const ValueKey('account-ask-go'),
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: danger ? Mid.coral : Mid.blue,
          ),
          child: Text(action),
        ),
      ],
    );
  }
}

/// Add account: the computer's page on one scroll, with Cancel and Add
/// account pinned under it. What it starts with is asked here, where the
/// computer asks it on the next screen.
class _NewAccountPage extends StatefulWidget {
  const _NewAccountPage({
    required this.store,
    required this.today,
    this.type = AccountType.asset,
    this.cash = false,
    this.setupDate,
  });
  final PhoneStore store;
  final DateTime today;
  final AccountType type;
  final bool cash;

  /// In setup: the balance is on this day, asked on setup's page, so the
  /// page has no day of its own; and no bank file, since setup's steps
  /// come first.
  final DateTime? setupDate;

  @override
  State<_NewAccountPage> createState() => _NewAccountPageState();
}

class _NewAccountPageState extends State<_NewAccountPage>
    with _FormRows<_NewAccountPage> {
  final _name = TextEditingController();
  late var _type = widget.type;
  late var _cash = widget.cash;
  late var _currencyChosen =
      widget.store.snapshot.accounts.firstOrNull?.currency ?? Currency.mnt;
  final _rate = TextEditingController();
  bool? _perYear;
  final _balance = TextEditingController();
  late var _date = dateOnly(widget.setupDate ?? widget.today);
  var _tried = false, _busy = false;

  @override
  Currency get _currency => _currencyChosen;

  @override
  DateTime get _today => widget.today;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus('account-name').requestFocus();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    _balance.dispose();
    _disposeFocuses();
    super.dispose();
  }

  bool get _owed => _type == AccountType.liability;
  int? get _balanceValue => parseAmount(_balance.text, _currencyChosen);
  bool get _balanceWrong =>
      _balance.text.trim().isNotEmpty && _balanceValue == null;
  double? get _ratePercent => parseRatePercent(_rate.text);
  bool get _rateWrong =>
      _owed && _rate.text.trim().isNotEmpty && _ratePercent == null;

  /// [import]: "Or import a file from your bank", the account added with
  /// no balance and its bank's file opened next, as on the computer.
  Future<void> _add({bool import = false}) async {
    final t = context.t;
    if (_busy) return;
    if ((_balanceWrong && !import) || _rateWrong) {
      setState(() => _tried = true);
      return;
    }
    String? rate;
    if (_owed && _rate.text.trim().isNotEmpty) {
      final DebtRate r = (
        percent: _ratePercent!,
        perYear: _perYear ?? ratePerYearFor(_currencyChosen),
      );
      rate = r.value;
    }
    // A wallet left unnamed is the Cash it is.
    final name = _name.text.trim().isNotEmpty
        ? _name.text.trim()
        : _cash
        ? t.setupKindCash
        : t.setupNewAccount;
    final act = PhoneAddAccount(
      name: name,
      type: _type,
      currency: _currencyChosen,
      cash: _cash,
      rate: rate,
      balance: import ? null : _balanceValue,
      date: _date,
    );
    setState(() => _busy = true);
    final done = await _doAccount(context, widget.store, act);
    if (!mounted) return;
    if (done == null) {
      setState(() => _busy = false);
      return;
    }
    Navigator.of(context).pop(
      _AccountDone(done, t.ledgerAdded(name), show: act.made, import: import),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final kinds = [
      (
        'kind-bank',
        t.setupKindBank,
        _type == AccountType.asset && !_cash,
        () => setState(() {
          _type = AccountType.asset;
          _cash = false;
        }),
      ),
      (
        'kind-cash',
        t.setupKindCash,
        _type == AccountType.asset && _cash,
        () => setState(() {
          _type = AccountType.asset;
          _cash = true;
        }),
      ),
      (
        'kind-owed',
        t.setupKindOwed,
        _owed,
        () => setState(() {
          _type = AccountType.liability;
          _cash = false;
        }),
      ),
    ];
    return ListenableBuilder(
      listenable: Listenable.merge([_name, _rate, _balance]),
      builder: (context, _) {
        final perYear = _perYear ?? ratePerYearFor(_currencyChosen);
        final percent = _ratePercent;
        // A rate that looks typed under the wrong period is said with its
        // numbers, and saved as typed all the same (warn, don't block).
        final rateWarning = percent == null
            ? null
            : rateLooksYearly((percent: percent, perYear: perYear))
            ? t.planRateLooksYearly(
                ratePercent(percent),
                ratePercent(percent * 12),
              )
            : rateLooksMonthly((
                percent: percent,
                perYear: perYear,
              ), _currencyChosen)
            ? t.planRateLooksMonthly(
                ratePercent(percent),
                ratePercent(percent / 12),
              )
            : null;
        final problem = _balanceWrong
            ? t.setupCantRead(_balance.text.trim())
            : _rateWrong
            ? t.setupCantRead(_rate.text.trim())
            : null;
        String zero() => formatRounded(0, currency: _currencyChosen);
        return Scaffold(
          backgroundColor: Mid.ground,
          appBar: AppBar(
            backgroundColor: Mid.ground,
            foregroundColor: Mid.ink,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(t.setupNewAccount, style: onest(20, weight: 600)),
          ),
          body: ListView(
            key: const ValueKey('new-account-page'),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              _card([
                _fieldRow(
                  'account-name',
                  t.setupName,
                  _name,
                  text: true,
                  hint: t.setupNewAccount,
                  action: TextInputAction.done,
                ),
              ]),
              const SizedBox(height: 14),
              _card([_asked(t.setupKind, _choices(kinds))]),
              _aside(switch ((_type, _cash)) {
                (AccountType.liability, _) => t.setupKindOwedHint,
                (_, true) => t.setupKindCashHint,
                _ => t.setupKindBankHint,
              }),
              const SizedBox(height: 14),
              _card([
                _choiceRow(
                  'account-currency',
                  t.setupCurrency,
                  '${_currencyChosen.code} ${_currencyChosen.symbol}',
                  () async {
                    final picked = await _pick<Currency>(
                      t.setupCurrency,
                      [
                        for (final c in Currency.values)
                          (c, '${c.code} ${c.symbol}'),
                      ],
                      chosen: _currencyChosen,
                      keyPrefix: 'currency',
                    );
                    if (picked != null && mounted) {
                      setState(() => _currencyChosen = picked);
                    }
                  },
                ),
              ]),
              _aside(t.setupCurrencyHint),
              if (_owed) ...[
                const SizedBox(height: 14),
                _card([
                  _fieldRow(
                    'account-rate',
                    t.setupRate,
                    _rate,
                    number: true,
                    after: '%',
                    wrong: _tried && _rateWrong,
                  ),
                  _choices([
                    (
                      'rate-per-month',
                      t.planRatePerMonth,
                      !perYear,
                      () => setState(() => _perYear = false),
                    ),
                    (
                      'rate-per-year',
                      t.planRatePerYear,
                      perYear,
                      () => setState(() => _perYear = true),
                    ),
                  ]),
                ]),
                _aside(rateWarning ?? t.setupRateHint, key: 'rate-says'),
              ],
              const SizedBox(height: 14),
              // In setup the day is setup's, chosen on its page: one that
              // isn't today is said here, so what the bank app shows today
              // isn't typed as that day's (budget review, #534).
              if (widget.setupDate case final day?
                  when day != dateOnly(widget.today))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    _owed
                        ? t.setupStartOwedOn(sayDate(t, day))
                        : t.setupStartInOn(sayDate(t, day)),
                    key: const ValueKey('account-setup-day'),
                    style: onest(16, weight: 600),
                  ),
                ),
              _card([
                _fieldRow(
                  'account-balance',
                  _owed ? t.setupYouOwe : t.setupBalance,
                  _balance,
                  money: true,
                  hint: zero(),
                  wrong: _tried && _balanceWrong,
                  action: TextInputAction.done,
                ),
                if (widget.setupDate == null)
                  _choiceRow(
                    'account-date',
                    t.setupOn,
                    sayFullDate(t, _date),
                    () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(widget.today.year - 30),
                        lastDate: widget.today,
                      );
                      if (d != null && mounted) {
                        setState(() => _date = dateOnly(d));
                      }
                    },
                  ),
              ]),
              _aside(
                _owed
                    ? t.setupStartOwedHint(zero())
                    : t.setupStartBankHint(zero()),
              ),
              // The bank's file can answer what's in it instead (owner,
              // 2026-10-06): offered while nothing is typed there. Cash
              // has no file.
              if (!_cash &&
                  _balance.text.trim().isEmpty &&
                  widget.setupDate == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      key: const ValueKey('new-account-import'),
                      onPressed: () => _add(import: true),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        foregroundColor: Mid.blue,
                        side: BorderSide(color: Mid.blue, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: onest(14, weight: 600),
                      ),
                      child: Text(t.setupStartImport),
                    ),
                  ),
                ),
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
                  if (_tried && problem != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        problem,
                        key: const ValueKey('new-account-problem'),
                        style: onest(13.5, color: Mid.coral),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          key: const ValueKey('new-account-cancel'),
                          onPressed: () => Navigator.of(context).pop(),
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
                          key: const ValueKey('new-account-create'),
                          onPressed: _add,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            backgroundColor: Mid.green,
                            foregroundColor: Colors.white,
                            textStyle: onest(16, weight: 600),
                          ),
                          child: Text(t.setupAddAccount),
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

/// An account's Edit… on the phone: the computer's, on one page with Cancel
/// and Save pinned under it. A changed Type says what it does, with the real
/// numbers, before Save (warn, don't block). Hands back the edit.
class _EditAccountPage extends StatefulWidget {
  const _EditAccountPage({required this.store, required this.account});
  final PhoneStore store;
  final AccountInfo account;

  @override
  State<_EditAccountPage> createState() => _EditAccountPageState();
}

class _EditAccountPageState extends State<_EditAccountPage>
    with _FormRows<_EditAccountPage> {
  AccountInfo get _a => widget.account;
  LedgerData get _data => widget.store.snapshot.data!;
  late final _name = TextEditingController(text: _a.name);
  late var _owed = _a.isOwed;
  late final DebtRate? _rateWas = parseDebtRate(
    _data.prefs[ReadyKeys.rate(_a.id)],
  );
  late final _rate = TextEditingController(
    text: _rateWas == null ? '' : ratePercent(_rateWas.percent),
  );
  late bool _perYear = _rateWas?.perYear ?? ratePerYearFor(_a.currency);
  late int? _loan = Budget.loanCategory(_data, _a.id);
  var _tried = false;

  @override
  Currency get _currency => _a.currency;

  @override
  DateTime get _today => DateTime.now();

  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    _disposeFocuses();
    super.dispose();
  }

  bool get _rateWrong =>
      _owed &&
      _rate.text.trim().isNotEmpty &&
      parseRatePercent(_rate.text) == null;

  void _save() {
    if (_rateWrong) {
      setState(() => _tried = true);
      return;
    }
    String? rate;
    if (_owed && _rate.text.trim().isNotEmpty) {
      final DebtRate r = (
        percent: parseRatePercent(_rate.text)!,
        perYear: _perYear,
      );
      rate = r.value;
    }
    final AccountEdit edit = (
      name: _name.text.trim().isEmpty ? _a.name : _name.text.trim(),
      owed: _owed,
      rate: rate,
      loan: _loan,
    );
    Navigator.of(context).pop(edit);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return ListenableBuilder(
      listenable: Listenable.merge([_name, _rate]),
      builder: (context, _) {
        final says = accountKindSays(t, _data, _a, _owed);
        final categories = [
          for (final c in _data.categories)
            if (!c.isIncome &&
                !isUncategorized(c) &&
                (c.currency == _a.currency || c.id == _loan))
              c,
        ];
        return Scaffold(
          backgroundColor: Mid.ground,
          appBar: AppBar(
            backgroundColor: Mid.ground,
            foregroundColor: Mid.ink,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(
              t.accountEditTitle(_a.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: onest(20, weight: 600),
            ),
          ),
          body: ListView(
            key: const ValueKey('edit-account-page'),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              _card([
                _fieldRow(
                  'edit-account-name',
                  t.setupName,
                  _name,
                  text: true,
                  action: TextInputAction.done,
                ),
              ]),
              const SizedBox(height: 14),
              _card([
                _asked(
                  t.setupKind,
                  _choices([
                    (
                      'edit-kind-held',
                      _a.isCash ? t.setupKindCash : t.setupKindBank,
                      !_owed,
                      () => setState(() => _owed = false),
                    ),
                    (
                      'edit-kind-owed',
                      t.setupKindOwed,
                      _owed,
                      () => setState(() => _owed = true),
                    ),
                  ]),
                ),
              ]),
              if (_owed) ...[
                const SizedBox(height: 14),
                _card([
                  _fieldRow(
                    'edit-account-rate',
                    t.setupRate,
                    _rate,
                    number: true,
                    after: '%',
                    wrong: _tried && _rateWrong,
                  ),
                  _choices([
                    (
                      'rate-per-month',
                      t.planRatePerMonth,
                      !_perYear,
                      () => setState(() => _perYear = false),
                    ),
                    (
                      'rate-per-year',
                      t.planRatePerYear,
                      _perYear,
                      () => setState(() => _perYear = true),
                    ),
                  ]),
                  _choiceRow(
                    'edit-account-loan',
                    t.setupLoanPaidFrom,
                    _data.accounts[_loan]?.name ?? t.setupLoanNoCategory,
                    () async {
                      final picked = await _pick<int>(
                        t.setupLoanPaidFrom,
                        [
                          (0, t.setupLoanNoCategory),
                          for (final c in categories) (c.id, c.name),
                        ],
                        chosen: _loan ?? 0,
                        keyPrefix: 'loan-category',
                      );
                      if (picked != null && mounted) {
                        setState(() => _loan = picked == 0 ? null : picked);
                      }
                    },
                  ),
                ]),
              ],
              if (says != null) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    says,
                    key: const ValueKey('edit-account-says'),
                    style: onest(15, weight: 600, height: 1.4),
                  ),
                ),
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
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      key: const ValueKey('edit-account-cancel'),
                      onPressed: () => Navigator.of(context).pop(),
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
                      key: const ValueKey('edit-account-save'),
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: Mid.green,
                        foregroundColor: Colors.white,
                        textStyle: onest(16, weight: 600),
                      ),
                      child: Text(t.rowsSave),
                    ),
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
