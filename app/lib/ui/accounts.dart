part of 'ledger_screen.dart';

// Adding, renaming, archiving and deleting accounts (ADR 0004, rule 21).
// Nothing is refused for the user's own good: an archive or delete that
// leaves something behind says exactly what, and then does it.

/// Whole tögrög, with the fraction only when there is one: a ₮0.40 leftover
/// mustn't read as ₮0.
String _money(int v) => formatMoney(v, showCents: v % 100 != 0);

/// What an account's balance is, in words that fit its kind and sign.
String _balanceWords(AccountInfo a, int balance) => a.isOwed
    ? (balance <= 0
          ? 'You still owe ${_money(-balance)} on it.'
          : 'It’s ${_money(balance)} in credit: the bank owes you.')
    : (balance >= 0
          ? '${_money(balance)} is still in it.'
          : 'It’s ${_money(-balance)} overdrawn.');

/// Quiet, under the accounts in the sidebar.
class _AddAccountTile extends StatelessWidget {
  const _AddAccountTile({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 26),
    child: Hoverable(
      key: const ValueKey('add-account'),
      onTap: onTap,
      builder: (hover) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? Mid.sideSel
              : (hover ? Mid.sideHover : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.add_rounded,
              size: 15,
              color: hover || active ? Mid.sideInk2 : Mid.sideInk3,
            ),
            const SizedBox(width: 6),
            Text(
              'Add account',
              style: onest(
                13,
                color: hover || active ? Mid.sideInk2 : Mid.sideInk3,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Name and kind. Its balance is asked for on the account's first screen.
class _NewAccountPage extends StatefulWidget {
  const _NewAccountPage({required this.onCreate, this.onCancel});
  final void Function(String name, AccountType type) onCreate;

  /// Null when there is no account to go back to.
  final VoidCallback? onCancel;

  @override
  State<_NewAccountPage> createState() => _NewAccountPageState();
}

class _NewAccountPageState extends State<_NewAccountPage> {
  static const _defaultName = 'New account';
  final _name = TextEditingController();
  var _type = AccountType.asset;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() {
    final n = _name.text.trim();
    widget.onCreate(n.isEmpty ? _defaultName : n, _type);
  }

  @override
  Widget build(BuildContext context) {
    Widget kind(AccountType t, String label) {
      final on = _type == t;
      return Hoverable(
        key: ValueKey('kind-${t.name}'),
        onTap: () => setState(() => _type = t),
        builder: (hover) => Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on
                ? Mid.blueWash
                : (hover ? Mid.raised : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: on ? Mid.blue : Mid.ink2.withValues(alpha: 0.3),
            ),
          ),
          child: Text(label, style: onest(13, color: on ? Mid.ink : Mid.ink2)),
        ),
      );
    }

    return CallbackShortcuts(
      bindings: {
        if (widget.onCancel != null)
          const SingleActivator(LogicalKeyboardKey.escape): widget.onCancel!,
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 36,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'New account',
                      style: onest(22, weight: 600, letterSpacing: -0.3),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
                  decoration: BoxDecoration(
                    color: Mid.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Mid.rule),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FormLine(
                        label: 'Name',
                        child: SizedBox(
                          width: 280,
                          height: 34,
                          child: TextField(
                            key: const ValueKey('new-account-name'),
                            controller: _name,
                            autofocus: true,
                            style: onest(13.5),
                            onSubmitted: (_) => _create(),
                            decoration: _fieldDecoration(hint: _defaultName),
                          ),
                        ),
                      ),
                      _FormLine(
                        label: 'Kind',
                        child: Row(
                          children: [
                            kind(AccountType.asset, 'Bank account'),
                            const SizedBox(width: 8),
                            kind(AccountType.liability, 'Card or loan'),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 100, bottom: 6),
                        child: Text(
                          _type == AccountType.liability
                              ? 'A credit card, a loan or Storepay: shows what you owe, as a positive amount, the way the bank does.'
                              : 'Checking, savings or cash. Accounts are in tögrög for now.',
                          style: onest(12.5, color: Mid.ink3),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(left: 100),
                        child: Row(
                          children: [
                            if (widget.onCancel != null)
                              BarButton(
                                key: const ValueKey('new-account-cancel'),
                                label: 'Cancel',
                                onTap: widget.onCancel!,
                              ),
                            _PrimaryButton(
                              key: const ValueKey('new-account-create'),
                              label: 'Add account',
                              icon: Icons.add_rounded,
                              tooltip: 'Enter',
                              onTap: _create,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormLine extends StatelessWidget {
  const _FormLine({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: onest(13.5, color: Mid.ink3)),
        ),
        child,
      ],
    ),
  );
}

InputDecoration _fieldDecoration({String? hint, bool wrong = false}) =>
    InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Mid.ground.withValues(alpha: 0.6),
      hintText: hint,
      hintStyle: onest(13.5, color: Mid.ink3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: wrong
            ? BorderSide(color: Mid.coral.withValues(alpha: 0.6))
            : BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Mid.blue, width: 1.5),
      ),
    );

/// An account with no rows yet: what's in it, so the ledger starts from the
/// real balance and the first reconcile can match. Empty starts at ₮0.
class _AccountStart extends StatefulWidget {
  const _AccountStart({
    super.key,
    required this.account,
    required this.today,
    required this.onStart,
  });
  final AccountInfo account;
  final DateTime today;

  /// [balance] as typed (what's owed, positive, on a card), or null if empty.
  final void Function(int? balance, DateTime date) onStart;

  @override
  State<_AccountStart> createState() => _AccountStartState();
}

class _AccountStartState extends State<_AccountStart> {
  final _balance = TextEditingController();
  late final _date = TextEditingController(text: fullDate(widget.today));
  final _balanceFocus = FocusNode(debugLabel: 'start-balance');
  final _dateFocus = FocusNode(debugLabel: 'start-date');

  @override
  void dispose() {
    _balance.dispose();
    _date.dispose();
    _balanceFocus.dispose();
    _dateFocus.dispose();
    super.dispose();
  }

  int? get _parsed => parseAmount(_balance.text);
  bool get _empty => _balance.text.trim().isEmpty;
  DateTime? get _day => parseEntryDate(_date.text, widget.today);

  void _start() {
    final day = _day;
    if (day == null) {
      _dateFocus.requestFocus();
      return;
    }
    if (_empty) return widget.onStart(null, day);
    final v = _parsed;
    if (v == null) {
      _balanceFocus.requestFocus();
      return;
    }
    widget.onStart(v, day);
  }

  @override
  Widget build(BuildContext context) {
    final owed = widget.account.isOwed;
    return ListenableBuilder(
      listenable: Listenable.merge([_balance, _date]),
      builder: (context, _) {
        final wrongAmount = !_empty && _parsed == null;
        final day = _day;
        final wrongDate = day == null;
        return Container(
          key: const ValueKey('account-start'),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
          decoration: BoxDecoration(
            color: Mid.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Mid.rule),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(switch ((owed, day == null || day == widget.today)) {
                (true, true) => 'What do you owe on it today?',
                (false, true) => 'What’s in this account today?',
                (true, false) =>
                  'What did you owe on it on ${shortDate(day!)}?',
                (false, false) => 'What was in it on ${shortDate(day!)}?',
              }, style: onest(16, weight: 600)),
              const SizedBox(height: 16),
              _FormLine(
                label: owed ? 'You owe' : 'Balance',
                child: SizedBox(
                  width: 180,
                  height: 34,
                  child: TextField(
                    key: const ValueKey('start-balance'),
                    controller: _balance,
                    focusNode: _balanceFocus,
                    autofocus: true,
                    textAlign: TextAlign.right,
                    style: onest(13.5, tabular: true),
                    onSubmitted: (_) => _start(),
                    decoration: _fieldDecoration(
                      hint: '₮0',
                      wrong: wrongAmount,
                    ),
                  ),
                ),
              ),
              _FormLine(
                label: 'On',
                child: SizedBox(
                  width: 130,
                  height: 34,
                  child: DateField(
                    key: const ValueKey('start-date'),
                    controller: _date,
                    focusNode: _dateFocus,
                    today: widget.today,
                    allowFuture: false,
                    small: true,
                    wanted: wrongDate,
                    onSubmitted: _start,
                    onPicked: _balanceFocus.requestFocus,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 100, bottom: 14),
                child: Text(
                  wrongAmount
                      ? 'Can’t read “${_balance.text.trim()}” as an amount'
                      : wrongDate
                      ? 'Date should look like ${fullDate(widget.today)}'
                      // Shown before typing: the number is looked up first.
                      // It becomes a cleared row, so the first reconcile
                      // starts from it: the number the bank shows. Card apps
                      // show the available limit most prominently.
                      : owed
                      ? 'What you’ve used, not the available limit · empty starts at ₮0'
                      : 'From the bank app, a statement or what you count, not the “available” balance · empty starts at ₮0',
                  style: onest(
                    12.5,
                    color: wrongAmount || wrongDate ? Mid.coral : Mid.ink3,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 100),
                child: Row(
                  children: [
                    _PrimaryButton(
                      key: const ValueKey('start-account'),
                      label: 'Start account',
                      icon: Icons.check_rounded,
                      tooltip: 'Enter',
                      onTap: _start,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// What can be done to an account, from ⋯ beside its name or a right-click
/// on it in the sidebar.
class _AccountActions {
  _AccountActions({
    required this.rename,
    required this.changeKind,
    required this.archive,
    required this.delete,
  });
  final VoidCallback rename;
  final VoidCallback changeKind;
  final VoidCallback archive;
  final VoidCallback delete;
}

MenuStyle get _menuStyle => MenuStyle(
  backgroundColor: WidgetStatePropertyAll(Mid.raised),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
  ),
  padding: WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
);

List<Widget> _accountMenu(AccountInfo a, _AccountActions act) {
  Widget item(String label, String key, VoidCallback onTap, {Color? color}) =>
      MenuItemButton(
        key: ValueKey(key),
        onPressed: onTap,
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(220, 34)),
          overlayColor: WidgetStatePropertyAll(Mid.blueWash),
        ),
        child: Text(label, style: onest(13, color: color ?? Mid.ink2)),
      );
  return [
    item('Rename', 'menu-rename', act.rename),
    item(
      a.isOwed ? 'Change to bank account' : 'Change to card or loan',
      'menu-kind',
      act.changeKind,
    ),
    Divider(height: 9, color: Mid.rule),
    item('Archive…', 'menu-archive', act.archive),
    item('Delete…', 'menu-delete', act.delete, color: Mid.coral),
  ];
}

/// The account's name, which renames in place when clicked, and a menu for
/// the rest.
class _AccountTitle extends StatefulWidget {
  const _AccountTitle({
    required this.account,
    required this.onRename,
    required this.actions,
    this.renameRequest = 0,
  });
  final AccountInfo account;
  final ValueChanged<String> onRename;

  /// Its rename is the field here, whatever [actions] says.
  final _AccountActions actions;

  /// Bumped to open the name for renaming (Rename from the sidebar).
  final int renameRequest;

  @override
  State<_AccountTitle> createState() => _AccountTitleState();
}

class _AccountTitleState extends State<_AccountTitle> {
  TextEditingController? _editing;
  final _focus = FocusNode(debugLabel: 'account-name');

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing != null) _save();
    });
  }

  @override
  void didUpdateWidget(_AccountTitle old) {
    super.didUpdateWidget(old);
    if (old.account.id != widget.account.id) _cancel();
    if (old.renameRequest != widget.renameRequest) _startRename();
  }

  @override
  void dispose() {
    _editing?.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startRename() {
    final c = TextEditingController(text: widget.account.name)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.account.name.length,
      );
    setState(() => _editing = c);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _save() {
    final name = _editing?.text.trim() ?? '';
    _cancel();
    // Emptied: nothing to call it, so it keeps its name.
    if (name.isNotEmpty && name != widget.account.name) widget.onRename(name);
  }

  void _cancel() {
    final c = _editing;
    if (c == null) return;
    setState(() => _editing = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final style = onest(22, weight: 600, letterSpacing: -0.3);
    final a = widget.account;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_editing != null)
          SizedBox(
            width: 320,
            height: 36,
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): _cancel,
              },
              child: TextField(
                key: const ValueKey('account-name-field'),
                controller: _editing,
                focusNode: _focus,
                style: style,
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Mid.panel,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Mid.blue, width: 1.5),
                  ),
                ),
              ),
            ),
          )
        else
          Tooltip(
            message: 'Click to rename',
            waitDuration: const Duration(milliseconds: 600),
            child: MouseRegion(
              cursor: SystemMouseCursors.text,
              child: GestureDetector(
                key: const ValueKey('account-name'),
                onTap: _startRename,
                child: Padding(
                  // Lines up with the field's text when it opens.
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(a.name, style: style),
                ),
              ),
            ),
          ),
        if (a.mask != null) ...[
          const SizedBox(width: 4),
          Text('··${a.mask}', style: onest(13, color: Mid.ink3, tabular: true)),
        ],
        const SizedBox(width: 6),
        MenuAnchor(
          style: _menuStyle,
          alignmentOffset: const Offset(0, 4),
          menuChildren: _accountMenu(
            a,
            _AccountActions(
              rename: _startRename,
              changeKind: widget.actions.changeKind,
              archive: widget.actions.archive,
              delete: widget.actions.delete,
            ),
          ),
          builder: (context, menu, _) => Hoverable(
            key: const ValueKey('account-menu'),
            onTap: () => menu.isOpen ? menu.close() : menu.open(),
            builder: (hover) => Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: hover || menu.isOpen ? Mid.raised : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.more_horiz_rounded,
                size: 18,
                color: hover || menu.isOpen ? Mid.ink2 : Mid.ink3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A dialog that says what an account action will do, and does it on the
/// button that names it. Enter doesn't press it: these are read first.
class _AccountWarning extends StatelessWidget {
  const _AccountWarning({
    required this.title,
    required this.lines,
    required this.action,
    required this.danger,
  });
  final String title;
  final List<String> lines;
  final String action;
  final bool danger;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Mid.panel,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: danger ? Mid.coral.withValues(alpha: 0.5) : Mid.rule,
      ),
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
              title,
              style: onest(
                17,
                weight: 600,
                letterSpacing: -0.2,
                color: danger ? Mid.coral : Mid.ink,
              ),
            ),
            const SizedBox(height: 14),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(l, style: onest(13.5, color: Mid.ink)),
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                BarButton(
                  key: const ValueKey('warning-cancel'),
                  label: 'Cancel',
                  onTap: () => Navigator.of(context).pop(false),
                ),
                Material(
                  key: const ValueKey('warning-confirm'),
                  color: danger ? Mid.coral : Mid.gold,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(true),
                    borderRadius: BorderRadius.circular(8),
                    hoverColor: Colors.white.withValues(alpha: 0.14),
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      child: Text(
                        action,
                        style: onest(13, weight: 600, color: Mid.onAccent),
                      ),
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
}

/// What archiving leaves behind, or nothing if it leaves nothing.
List<String> _archiveWarnings(
  AccountInfo a,
  int balance,
  List<RegisterRow> scheduled,
) {
  String list(Iterable<RegisterRow> rows) =>
      '${rows.take(3).map((r) => '${r.payee} ${shortDate(r.date)}').join(', ')}'
      '${rows.length > 3 ? ', …' : ''}';
  final own = scheduled.where((r) => r.kind != RowKind.transfer).toList();
  // A scheduled transfer still shows on the other account, as money coming
  // or going there.
  final transfers = scheduled.where((r) => r.kind == RowKind.transfer).toList();
  return [
    if (balance != 0)
      '${_balanceWords(a, balance)} It stays in net worth, but the account '
          'won’t be in the sidebar.',
    if (own.isNotEmpty)
      '${own.length} scheduled ${own.length == 1 ? 'row' : 'rows'} '
          '(${list(own)}) won’t show in any forecast.',
    if (transfers.isNotEmpty)
      '${transfers.length} scheduled '
          '${transfers.length == 1 ? 'transfer stays' : 'transfers stay'} on '
          'the other account’s forecast (${list(transfers)}). Delete '
          '${transfers.length == 1 ? 'it' : 'them'} there if cancelled.',
  ];
}

List<String> _deleteWarnings(
  AccountInfo a,
  int balance,
  AccountDeletePreview p,
) {
  final rows = p.rows == 0
      ? 'This deletes the account. It has no rows of its own.'
      : 'This deletes the account and its ${p.rows} '
            '${p.rows == 1 ? 'row' : 'rows'}'
            '${p.reconciled == 0 ? '' : ', ${p.reconciled} of them reconciled'}.';
  // Net worth loses the account's balance: an asset takes it down, a debt
  // no longer counted takes it up.
  final worth = balance == 0
      ? null
      : 'Net worth goes ${balance > 0 ? 'down' : 'up'} by '
            '${_money(balance.abs())}'
            '${a.isOwed && balance < 0 ? ', since what you owe on it is no longer counted' : ''}.';
  final pending = p.keptScheduled;
  final pendingLine = pending.isEmpty
      ? null
      : '${pending.length == 1 ? 'One is' : '${pending.length} are'} still '
            'scheduled (${pending.take(3).map((k) => '${k.on} ${shortDate(k.date)}').join(', ')}'
            '${pending.length > 3 ? ', …' : ''}). Confirmed later, '
            '${pending.length == 1 ? 'it moves' : 'they move'} money from an '
            'account that no longer exists; delete '
            '${pending.length == 1 ? 'it' : 'them'} there if cancelled.';
  final kept = p.keptOn.entries.toList();
  final keptLine = switch (kept.length) {
    0 => null,
    1 =>
      'Its ${kept.single.value} '
          '${kept.single.value == 1 ? 'transfer' : 'transfers'} with '
          '${kept.single.key.name} stay on ${kept.single.key.name} as '
          '“${a.name} (deleted)”.',
    _ =>
      'Its transfers stay on the other accounts as “${a.name} (deleted)”: '
          '${kept.map((e) => '${e.value} on ${e.key.name}').join(', ')}.',
  };
  return [rows, ?worth, ?keptLine, ?pendingLine];
}

/// Settings: accounts taken out of the sidebar, to put back.
class _ArchivedAccounts extends StatelessWidget {
  const _ArchivedAccounts({required this.data, required this.onUnarchive});
  final LedgerData data;
  final ValueChanged<AccountInfo> onUnarchive;

  @override
  Widget build(BuildContext context) => Container(
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
        Text('Archived accounts', style: onest(16, weight: 600)),
        const SizedBox(height: 12),
        for (final a in data.archivedAccounts)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(child: Text(a.name, style: onest(13.5))),
                Text(
                  a.isOwed
                      ? '${_money(-data.balanceOf(a.id))} owed'
                      : _money(data.balanceOf(a.id)),
                  style: onest(13, color: Mid.ink3, tabular: true),
                ),
                const SizedBox(width: 16),
                BarButton(
                  key: ValueKey('unarchive-${a.id}'),
                  label: 'Show in sidebar',
                  onTap: () => onUnarchive(a),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Every account's rows in one register, above the account groups.
class _AllAccountsTile extends StatelessWidget {
  const _AllAccountsTile({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Hoverable(
    key: const ValueKey('all-accounts'),
    onTap: onTap,
    builder: (hover) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: active
            ? Mid.sideSel
            : (hover ? Mid.sideHover : Colors.transparent),
        borderRadius: BorderRadius.circular(8),
        border: active
            ? Border(left: BorderSide(color: Mid.sun, width: 2))
            : null,
      ),
      child: Text(
        'All accounts',
        style: onest(13.5, color: active ? Mid.sideInk : Mid.sideInk2),
      ),
    ),
  );
}

/// A filter in force on All accounts, with ✕ to take it off (Esc does too).
class _FilterChip extends StatelessWidget {
  const _FilterChip({super.key, required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
    height: 30,
    padding: const EdgeInsets.only(left: 12, right: 4),
    decoration: BoxDecoration(
      color: Mid.blueWash,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Mid.blue.withValues(alpha: 0.5)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: onest(13, color: Mid.ink)),
        const SizedBox(width: 4),
        Tooltip(
          message: 'Show every row · Esc',
          child: Hoverable(
            key: const ValueKey('filter-clear'),
            onTap: onClear,
            builder: (hover) => Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: hover ? Mid.raised : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.close_rounded, size: 14, color: Mid.ink2),
            ),
          ),
        ),
      ],
    ),
  );
}
