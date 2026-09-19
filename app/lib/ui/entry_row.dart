import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/ledger.dart';
import '../domain/money.dart';
import 'register.dart' show Cols;
import 'theme.dart';

enum EditField { date, payee, memo, category, amount }

class EntryDraft {
  const EntryDraft({
    required this.date,
    required this.payee,
    required this.counter,
    required this.amount,
    this.memo,
    this.keepOwed = false,
    this.newCategory,
    this.account,
  });

  /// All accounts: the account the new row goes in. Null in an account's
  /// own register, where it's that account.
  final AccountInfo? account;

  /// A category typed that doesn't exist yet: the screen creates it (income
  /// when the amount had a `+`) and files the row under it. [counter] is null.
  final String? newCategory;

  /// Confirming money in that came short: keep the rest scheduled as still
  /// owed.
  final bool keepOwed;
  final DateTime date;
  final String payee;

  /// Null when the category can't be changed here (a split).
  final AccountInfo? counter;

  /// Signed from the register account's perspective. Null when the amount
  /// can't be changed here (a split).
  final int? amount;
  final String? memo;
}

/// Lets the screen focus a row (⌘N) and supply the data it needs.
class EntryRowController {
  EntryRowController({required this.onSubmit, required this.suggestCategory});

  /// Returns an error message, or null when the transaction was written.
  final Future<String?> Function(EntryDraft draft) onSubmit;
  final Future<int?> Function(String payee) suggestCategory;
  List<String> payeeNames = const [];
  final payeeFocus = FocusNode(debugLabel: 'entry-payee');

  /// All accounts: where new rows go. Kept between rows, so a batch from
  /// one account is picked once.
  AccountInfo? account;

  /// Set by the row: whether anything has been typed or changed.
  bool Function() isDirty = () => false;

  void focus() => payeeFocus.requestFocus();
}

/// What an existing transaction starts as when opened for editing.
class EditInitial {
  /// With [confirmingOn] (today), the row opens to confirm a scheduled
  /// transaction, saved with Confirm. One not due yet is dated today, since
  /// confirming means it happened. An overdue bill or transfer keeps its due
  /// date, when a standing order or auto-pay really left; overdue money in
  /// (a late salary) is dated today, since late means it didn't come then.
  EditInitial.fromRow(
    RegisterRow r, {
    this.focus = EditField.payee,
    DateTime? confirmingOn,
  }) : date =
           confirmingOn != null &&
               (r.date.isAfter(confirmingOn) ||
                   (r.amount > 0 && r.kind != RowKind.transfer))
           ? confirmingOn
           : r.date,
       plannedDate = r.date,
       confirming = confirmingOn != null,
       payee = r.kind == RowKind.simple ? r.payee : (r.txnPayee ?? ''),
       memo = r.memo,
       category = switch (r.kind) {
         RowKind.transfer => '→ ${r.payee}',
         _ => r.categoryLabel,
       },
       amount = r.amount,
       locked = r.locked,
       lockDate = r.locked,
       // A reconciled transfer can't move to another account; a reconciled
       // simple row can still change category.
       lockCategory =
           r.kind == RowKind.split ||
           r.kind == RowKind.opening ||
           (r.locked && r.kind == RowKind.transfer) ||
           r.otherClosed,
       lockAmount = r.kind == RowKind.split || r.locked,
       payeeOptional = r.kind != RowKind.simple,
       variesPay = r.estimate != null;

  final DateTime date;
  final String payee;
  final String memo;
  final String category;
  final int amount;

  /// Reconciled (here or on a transfer's other side): the date and amount
  /// match a bank statement.
  final bool locked;
  final bool lockDate;
  final bool lockCategory;
  final bool lockAmount;
  final bool payeeOptional;

  /// Pay that varies: coming in under the estimate is just what came, not
  /// "still owed".
  final bool variesPay;
  final EditField focus;

  /// Saving confirms a scheduled transaction.
  final bool confirming;

  /// The scheduled date, where anything still owed stays.
  final DateTime plannedDate;
}

/// `09.16`, `9.16`, `2026.09.16` or `2026-09-16`. Null when not a real date.
DateTime? parseEntryDate(String input, DateTime today) {
  final parts = input
      .trim()
      .split(RegExp(r'[.\-/]'))
      .where((p) => p.isNotEmpty)
      .map(int.tryParse)
      .toList();
  if (parts.any((p) => p == null)) return null;
  final int y, m, d;
  if (parts.length == 2) {
    (y, m, d) = (today.year, parts[0]!, parts[1]!);
  } else if (parts.length == 3) {
    (y, m, d) = (parts[0]!, parts[1]!, parts[2]!);
  } else {
    return null;
  }
  final date = DateTime(y, m, d);
  return date.month == m && date.day == d ? date : null;
}

/// How an amount reads in the field: `30000`, `214750.50`, `+2500000`.
String editableAmount(int minor) {
  final cents = minor.abs() % 100;
  final whole = minor.abs() ~/ 100;
  return '${minor > 0 ? '+' : ''}$whole${cents == 0 ? '' : '.${cents.toString().padLeft(2, '0')}'}';
}

/// The new-transaction row, and the same row opened on an existing
/// transaction when [initial] is set.
class EntryRow extends StatefulWidget {
  const EntryRow({
    super.key,
    required this.controller,
    required this.categories,
    required this.transferTargets,
    required this.today,
    this.initial,
    this.onCancel,
    this.accountName,
    this.accountChoices,
  });

  /// The register's account, so a transfer can say which way it goes.
  final String? accountName;

  /// All accounts, adding: the accounts a new row can go in, picked in the
  /// last column. Null in an account's own register and when editing.
  final List<AccountInfo>? accountChoices;

  final EntryRowController controller;
  final List<AccountInfo> categories;
  final List<AccountInfo> transferTargets;
  final DateTime today;
  final EditInitial? initial;

  /// Editing: Esc cancels. Adding: Esc, or leaving the row empty, closes it.
  final VoidCallback? onCancel;

  @override
  State<EntryRow> createState() => _EntryRowState();
}

class _EntryRowState extends State<EntryRow> {
  late final EditInitial? _initial = widget.initial;
  bool get _editing => _initial != null;

  late final _date = TextEditingController(
    text: fullDate(_initial?.date ?? widget.today),
  );
  late final _payee = TextEditingController(text: _initial?.payee ?? '');
  late final _memo = TextEditingController(text: _initial?.memo ?? '');
  late final _category = TextEditingController(text: _initial?.category ?? '');
  late final _amount = TextEditingController(
    text: _initial == null ? '' : editableAmount(_initial.amount),
  );
  late final List<TextEditingController> _all = [
    _date,
    _payee,
    _memo,
    _category,
    _amount,
  ];
  late final Map<TextEditingController, String> _start = {
    for (final c in _all) c: c.text,
  };

  final _dateFocus = FocusNode(debugLabel: 'entry-date');
  final _memoFocus = FocusNode(debugLabel: 'entry-memo');
  final _categoryFocus = FocusNode(debugLabel: 'entry-category');
  final _accountFocus = FocusNode(debugLabel: 'entry-account');
  final _amountFocus = FocusNode(debugLabel: 'entry-amount');
  String? _error;
  bool _busy = false;

  /// Confirming short money in: the rest is still owed, or it was paid in
  /// full. Null until chosen.
  bool? _keepOwedChoice;

  /// Still owed when more than a tenth is missing (half a salary); paid in
  /// full for small differences (deductions, a refund after the exchange rate
  /// moved), which would otherwise leave remainders nobody is owed.
  bool _keepOwedFor(int short) =>
      _keepOwedChoice ?? short * 10 > (_initial?.amount ?? 0);
  bool _active = false;

  FocusNode get _payeeFocus => widget.controller.payeeFocus;
  List<FocusNode> get _focuses => [
    _accountFocus,
    _dateFocus,
    _payeeFocus,
    _memoFocus,
    _categoryFocus,
    _amountFocus,
  ];

  /// The "+ New category" line in the list: not an account yet.
  static const _createId = -1;
  ({String label, AccountInfo account}) _createOption(String name) => (
    label: '+ New category “$name”',
    account: AccountInfo(id: _createId, name: name, type: AccountType.expense),
  );

  /// Every name the Category field knows, archived categories included: an
  /// old row filed under one keeps it when edited.
  List<({String label, AccountInfo account})> get _counterOptions => [
    for (final c in widget.categories) (label: c.name, account: c),
    for (final a in widget.transferTargets)
      // Not a transfer to the account it's coming from.
      if (!_picking || a.id != widget.controller.account?.id)
        (label: '→ ${a.name}', account: a),
  ];

  /// All accounts, adding: the row asks which account.
  bool get _picking => widget.accountChoices != null && !_editing;

  /// The account the row is in, for the transfer sentence.
  String? get _here =>
      _picking ? widget.controller.account?.name : widget.accountName;

  /// What the list offers and a payee prefills: not archived categories.
  Iterable<({String label, AccountInfo account})> get _listOptions =>
      _counterOptions.where((o) => !o.account.archived);

  /// The "+ New category" line was picked for exactly this text.
  String? _chosenNew;

  @override
  void initState() {
    super.initState();
    _start.length; // capture starting values now, before any edits
    for (final f in _focuses) {
      f.addListener(_focusChanged);
    }
    _payeeFocus.addListener(_prefillCategoryOnLeave);
    for (final c in _all) {
      c.addListener(_edited);
    }
    widget.controller.isDirty = () => _all.any((c) => c.text != _start[c]);
    if (_editing) {
      // Open with the cursor in the field that was double-clicked.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final (node, ctrl) = switch (_initial!.focus) {
          EditField.date when !_initial.lockDate => (_dateFocus, _date),
          EditField.memo => (_memoFocus, _memo),
          EditField.category when !_initial.lockCategory => (
            _categoryFocus,
            _category,
          ),
          EditField.amount when !_initial.lockAmount => (_amountFocus, _amount),
          _ => (_payeeFocus, _payee),
        };
        node.requestFocus();
        // An amount's `+` (money in) stays out of the selection, so typing
        // the real figure can't turn a refund or transfer in into money out.
        ctrl.selection = TextSelection(
          baseOffset: identical(ctrl, _amount) && ctrl.text.startsWith('+')
              ? 1
              : 0,
          extentOffset: ctrl.text.length,
        );
      });
    }
  }

  void _edited() {
    if (!mounted) return;
    setState(() => _error = null);
  }

  bool _wants(String field) =>
      _hasContent && _missing.any((m) => m.name == field);

  bool get _hasContent =>
      _editing ||
      _payee.text.trim().isNotEmpty ||
      _category.text.trim().isNotEmpty ||
      _amount.text.trim().isNotEmpty;

  bool get _isTransfer => _category.text.trim().startsWith('→');

  /// A name typed in Category that isn't one yet: saving creates it.
  String? get _newCategory {
    if (_initial?.lockCategory ?? false) return null;
    final t = _category.text.trim();
    if (t.isEmpty || t.startsWith('→')) return null;
    final known = _counterOptions.any(
      (o) => o.label.toLowerCase() == t.toLowerCase(),
    );
    return known ? null : t;
  }

  /// Why a typed name can't become a category without picking "+ New": it
  /// starts other names ("Gro" for Groceries), or it's an account ("Golomt
  /// Visa" meaning the transfer). Null when it can.
  String? get _newCategoryDoubt {
    final t = _newCategory;
    if (t == null || _chosenNew == t) return null;
    final q = t.toLowerCase();
    final account = widget.transferTargets
        .where((a) => a.name.toLowerCase() == q)
        .firstOrNull;
    if (account != null) return 'Did you mean “→ ${account.name}”?';
    final near = _listOptions
        .where((o) => o.label.toLowerCase().contains(q))
        .map((o) => o.label)
        .take(2)
        .toList();
    if (near.isEmpty) return null;
    return '“$t” isn’t a category · pick ${near.join(' or ')}, or + New category';
  }

  /// "new income category" when the amount has a `+`: income ends forecasts.
  String get _newCategoryNote => _amount.text.trim().startsWith('+')
      ? 'new income category'
      : 'new category';

  /// A transfer spelled out before it's added: "₮640,200.00 from TDB
  /// Checking to Golomt Visa". The category reads "→ Golomt Visa" either way,
  /// and only a `+` on the amount turns it around, which is easy to miss
  /// when entering it from the receiving account.
  String? get _transferLine {
    final here = _here;
    if (here == null || !_isTransfer) return null;
    final q = _category.text.trim().toLowerCase();
    final other = _counterOptions
        .where((o) => o.account.isBalanceSheet && o.label.toLowerCase() == q)
        .map((o) => o.account)
        .firstOrNull;
    if (other == null) return null;
    final raw = _amount.text.trim();
    final initial = _initial;
    final int? amount;
    if (initial != null && initial.lockAmount) {
      amount = initial.amount;
    } else {
      final parsed = parseAmount(raw.replaceFirst(RegExp(r'^\+'), ''));
      amount = parsed == null || parsed == 0
          ? null
          : (raw.startsWith('+') ? parsed.abs() : -parsed.abs());
    }
    final inflow = amount == null ? raw.startsWith('+') : amount > 0;
    final (from, to) = inflow ? (other.name, here) : (here, other.name);
    return amount == null
        ? 'From $from to $to'
        : '${formatMoney(amount.abs())} from $from to $to';
  }

  /// Confirming money in below plan: how much is missing. Null otherwise:
  /// never for bills (one that came in lower owes nothing more) or transfers
  /// (moving less is the user's own decision).
  int? get _shortBy {
    final initial = _initial;
    if (initial == null ||
        !initial.confirming ||
        initial.variesPay ||
        initial.lockAmount ||
        initial.amount <= 0) {
      return null;
    }
    final raw = _amount.text.trim();
    final parsed = parseAmount(raw.replaceFirst(RegExp(r'^\+'), ''));
    final counter = _counterOptions
        .where(
          (o) => o.label.toLowerCase() == _category.text.trim().toLowerCase(),
        )
        .firstOrNull;
    final inflow =
        raw.startsWith('+') || counter?.account.type == AccountType.income;
    if (parsed == null ||
        parsed <= 0 ||
        !inflow ||
        _isTransfer ||
        (counter?.account.isBalanceSheet ?? false)) {
      return null;
    }
    return parsed < initial.amount ? initial.amount - parsed : null;
  }

  /// Turns a transfer around: the `+` that means money in comes or goes.
  void _swapDirection() {
    final raw = _amount.text.trim();
    final text = raw.startsWith('+') ? raw.substring(1) : '+$raw';
    _amount.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Required fields still empty, in reading order. Order of entry is the
  /// user's choice; this only decides where Enter sends them next.
  List<({String name, FocusNode focus})> get _missing => [
    if (_date.text.trim().isEmpty) (name: 'date', focus: _dateFocus),
    if (_picking && widget.controller.account == null)
      (name: 'account', focus: _accountFocus),
    if (_payee.text.trim().isEmpty &&
        !_isTransfer &&
        !(_initial?.payeeOptional ?? false))
      (name: 'payee', focus: _payeeFocus),
    if (_category.text.trim().isEmpty && !(_initial?.lockCategory ?? false))
      (name: 'category', focus: _categoryFocus),
    // A bare `+` (Swap before any amount) is still no amount.
    if (_amount.text.trim().replaceFirst('+', '').isEmpty &&
        !(_initial?.lockAmount ?? false))
      (name: 'amount', focus: _amountFocus),
  ];

  @override
  void dispose() {
    for (final c in _all) {
      c.removeListener(_edited);
      c.dispose();
    }
    for (final f in [
      _dateFocus,
      _memoFocus,
      _categoryFocus,
      _amountFocus,
      _accountFocus,
    ]) {
      f.dispose();
    }
    _payeeFocus.removeListener(_focusChanged);
    _payeeFocus.removeListener(_prefillCategoryOnLeave);
    super.dispose();
  }

  /// The account list is open: focus is in its items, still in this row.
  bool _accountMenuOpen = false;

  void _focusChanged() {
    final active = _accountMenuOpen || _focuses.any((f) => f.hasFocus);
    if (active != _active) setState(() => _active = active);
    // Clicking away from a new row with nothing in it closes the row; with
    // something typed it stays, so nothing is lost.
    if (!active && !_editing && !widget.controller.isDirty()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_accountMenuOpen && !_focuses.any((f) => f.hasFocus)) {
          widget.onCancel?.call();
        }
      });
    }
  }

  Future<bool> _prefillCategory() async {
    if (_category.text.isNotEmpty || _payee.text.trim().isEmpty) return false;
    final id = await widget.controller.suggestCategory(_payee.text.trim());
    final match = _listOptions.where((o) => o.account.id == id).firstOrNull;
    if (match == null || !mounted) return false;
    setState(() => _category.text = match.label);
    return true;
  }

  void _prefillCategoryOnLeave() {
    if (!_payeeFocus.hasFocus) _prefillCategory();
  }

  void _reset({bool keepFocus = true}) {
    setState(() {
      _payee.clear();
      _category.clear();
      _amount.clear();
      _memo.clear();
      _error = null;
    });
    if (keepFocus) _payeeFocus.requestFocus();
  }

  void _escape() {
    if (_editing) {
      widget.onCancel?.call();
    } else {
      _reset(keepFocus: false);
      FocusScope.of(context).unfocus();
      widget.onCancel?.call();
    }
  }

  /// Enter in any field, or the Add/Save button, lands here.
  Future<void> _submit() async {
    if (_busy) return;
    if (_category.text.trim().isEmpty) await _prefillCategory();
    if (!mounted) return;

    final missing = _missing;
    if (missing.isNotEmpty) {
      missing.first.focus.requestFocus();
      return;
    }

    final lockCategory = _initial?.lockCategory ?? false;
    final lockAmount = _initial?.lockAmount ?? false;
    final date = parseEntryDate(_date.text, widget.today);
    final counter = lockCategory
        ? null
        : _counterOptions
              .where(
                (o) =>
                    o.label.toLowerCase() ==
                    _category.text.trim().toLowerCase(),
              )
              .firstOrNull;
    final raw = _amount.text.trim();
    final isInflow =
        raw.startsWith('+') || counter?.account.type == AccountType.income;
    final parsed = lockAmount
        ? null
        : parseAmount(raw.startsWith('+') ? raw.substring(1) : raw);

    String? error;
    FocusNode? fix;
    if (date == null) {
      (error, fix) = ('Date should look like 2026.09.16', _dateFocus);
    } else if (_picking &&
        _category.text.trim().toLowerCase() ==
            '→ ${widget.controller.account?.name}'.toLowerCase()) {
      (error, fix) = ('Can’t transfer to the same account', _categoryFocus);
    } else if (!lockCategory && counter == null && _newCategory == null) {
      (error, fix) = ('No account “${_category.text.trim()}”', _categoryFocus);
    } else if (!lockCategory && counter == null && _newCategoryDoubt != null) {
      (error, fix) = (_newCategoryDoubt!, _categoryFocus);
    } else if (!lockAmount && (parsed == null || parsed == 0)) {
      (error, fix) = ('Can’t read “$raw” as an amount', _amountFocus);
    }
    if (error != null) {
      fix!.requestFocus();
      setState(() => _error = error);
      return;
    }

    setState(() => _busy = true);
    final result = await widget.controller.onSubmit(
      EntryDraft(
        date: date!,
        payee: _payee.text.trim(),
        counter: counter?.account,
        amount: parsed == null
            ? null
            : (isInflow ? parsed.abs() : -parsed.abs()),
        memo: _memo.text,
        keepOwed: _shortBy != null && _keepOwedFor(_shortBy!),
        newCategory: counter == null ? _newCategory : null,
        account: _picking ? widget.controller.account : null,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result != null) {
      setState(() => _error = result);
    } else if (!_editing) {
      _reset();
    }
  }

  /// The note (what's missing, the sum, an error) and Add.
  Widget _submitLine(int? preview, bool showsMath) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Flexible(child: _note(preview, showsMath)),
      if (_hasContent || _active) ...[
        const SizedBox(width: 10),
        _AddButton(
          label: _initial?.confirming ?? false
              ? 'Confirm'
              : (_editing ? 'Save' : 'Add'),
          ready: _missing.isEmpty && _error == null,
          onTap: _submit,
        ),
      ],
    ],
  );

  Widget _note(int? preview, bool showsMath) {
    final String text;
    final Color color;
    if (_error != null) {
      (text, color) = (_error!, Mid.coral);
    } else if (showsMath) {
      (text, color) = (
        // The new-category note stays in sight while the sum shows.
        '= ${formatMoney(preview!)}'
            '${_newCategory == null ? '' : ' · $_newCategoryNote'}',
        Mid.ink2,
      );
    } else if (_newCategory != null) {
      // Said before saving, so a typo doesn't quietly become a category.
      (text, color) = (_newCategoryNote, Mid.gold);
    } else if (_hasContent && _missing.isNotEmpty) {
      final m = _missing;
      (text, color) = (
        m.length == 1 ? 'needs ${m.single.name}' : 'needs ${m.length} more',
        Mid.ink3,
      );
    } else if (_editing) {
      (text, color) = ('Esc to cancel', Mid.ink3);
    } else {
      return const SizedBox.shrink();
    }
    return Tooltip(
      message: text,
      child: Text(
        text,
        style: onest(12, color: color, tabular: true),
        textAlign: TextAlign.right,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  static const _reconciledTip =
      'Reconciled · this matches a bank statement, so it can’t change';

  Widget _locked(String text, {String? tip}) => Tooltip(
    message: tip ?? '',
    child: Container(
      height: 34,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        text,
        style: onest(13.5, color: Mid.ink3, tabular: true),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final preview = parseAmount(
      _amount.text.trim().replaceFirst(RegExp(r'^\+'), ''),
    );
    final showsMath =
        preview != null && RegExp(r'\d[+\-*/×]').hasMatch(_amount.text);
    final initial = _initial;
    final lit = _active || _editing;
    final transferLine = _transferLine;
    final shortBy = _shortBy;

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _escape},
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          _editing ? 2 : 0,
          12,
          _editing ? 2 : 6,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: Cols.inset.add(const EdgeInsets.symmetric(vertical: 9)),
          decoration: BoxDecoration(
            color: lit
                ? Mid.raised.withValues(alpha: _editing ? 0.8 : 0.55)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _editing
                  ? Mid.blueEdge
                  : (lit ? Mid.rule : Colors.transparent),
            ),
          ),
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: Cols.status,
                  height: 34,
                  child: Icon(
                    _editing ? Icons.edit_rounded : Icons.add_rounded,
                    size: _editing ? 14 : 16,
                    color: lit ? Mid.blue : Mid.ink3,
                  ),
                ),
                const SizedBox(width: Cols.gap),
                SizedBox(
                  width: Cols.date,
                  child: initial != null && initial.lockDate
                      ? _locked(fullDate(initial.date), tip: _reconciledTip)
                      : FocusTraversalOrder(
                          order: const NumericFocusOrder(1),
                          child: DateField(
                            controller: _date,
                            focusNode: _dateFocus,
                            today: widget.today,
                            wanted: _wants('date'),
                            onSubmitted: _submit,
                            onPicked: _payeeFocus.requestFocus,
                            // Confirming means it happened: no future days.
                            allowFuture: !(initial?.confirming ?? false),
                          ),
                        ),
                ),
                const SizedBox(width: Cols.gap),
                Expanded(
                  child: Column(
                    children: [
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(2),
                        child: _Autocomplete<String>(
                          controller: _payee,
                          focusNode: _payeeFocus,
                          hint: _editing ? 'Payee' : 'New transaction — payee',
                          wanted: _wants('payee'),
                          options: (q) => q.isEmpty
                              ? const []
                              : widget.controller.payeeNames
                                    .where(
                                      (p) => p.toLowerCase().contains(
                                        q.toLowerCase(),
                                      ),
                                    )
                                    .take(8),
                          label: (p) => p,
                          onSelected: (p) async {
                            final filled = await _prefillCategory();
                            (filled ? _amountFocus : _categoryFocus)
                                .requestFocus();
                          },
                          onSubmit: _submit,
                        ),
                      ),
                      // Adding: the memo line shows while the row is in use.
                      if (_editing || _active || _memo.text.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        FocusTraversalOrder(
                          order: const NumericFocusOrder(2.5),
                          child: _Field(
                            controller: _memo,
                            focusNode: _memoFocus,
                            hint: 'Memo',
                            small: true,
                            onSubmitted: (_) => _submit(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Cols.gap),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: Cols.category,
                          child: initial != null && initial.lockCategory
                              ? _locked(
                                  initial.category,
                                  tip:
                                      initial.locked &&
                                          initial.category.startsWith('→')
                                      ? _reconciledTip
                                      : 'Editing split lines isn’t built yet',
                                )
                              : FocusTraversalOrder(
                                  order: const NumericFocusOrder(3),
                                  child:
                                      _Autocomplete<
                                        ({String label, AccountInfo account})
                                      >(
                                        controller: _category,
                                        focusNode: _categoryFocus,
                                        hint: 'Category',
                                        wanted: _wants('category'),
                                        options: (q) => [
                                          ..._listOptions.where(
                                            (o) => o.label
                                                .toLowerCase()
                                                .contains(q.toLowerCase()),
                                          ),
                                          if (_newCategory case final n?)
                                            _createOption(n),
                                        ],
                                        label: (o) => o.account.id == _createId
                                            ? o.account.name
                                            : o.label,
                                        optionText: (o) => o.label,
                                        onSelected: (o) {
                                          // Picked on purpose: no doubt left.
                                          if (o.account.id == _createId) {
                                            _chosenNew = o.account.name;
                                          }
                                          _amountFocus.requestFocus();
                                        },
                                        onSubmit: _submit,
                                      ),
                                ),
                        ),
                        const SizedBox(width: Cols.gap),
                        SizedBox(
                          width: Cols.amount,
                          child: initial != null && initial.lockAmount
                              ? Align(
                                  alignment: Alignment.centerRight,
                                  child: _locked(
                                    // As the register shows it: out plain, in with +.
                                    initial.amount > 0
                                        ? '+${formatMoney(initial.amount)}'
                                        : formatMoney(initial.amount.abs()),
                                    tip: initial.locked
                                        ? _reconciledTip
                                        : 'A split’s total follows its lines',
                                  ),
                                )
                              : FocusTraversalOrder(
                                  order: const NumericFocusOrder(4),
                                  child: _Field(
                                    controller: _amount,
                                    focusNode: _amountFocus,
                                    hint: '0.00',
                                    tabular: true,
                                    align: TextAlign.right,
                                    wanted: _wants('amount'),
                                    onSubmitted: (_) => _submit(),
                                  ),
                                ),
                        ),
                        const SizedBox(width: Cols.gap),
                        SizedBox(
                          width: Cols.balance,
                          height: 34,
                          child: _picking
                              ? FocusTraversalOrder(
                                  // After the amount, where it sits.
                                  order: const NumericFocusOrder(4.5),
                                  child: _AccountPicker(
                                    choices: widget.accountChoices!,
                                    value: widget.controller.account,
                                    focusNode: _accountFocus,
                                    wanted: _wants('account'),
                                    onPicked: (a) => setState(() {
                                      widget.controller.account = a;
                                      _error = null;
                                    }),
                                    onMenu: (open) {
                                      _accountMenuOpen = open;
                                      _focusChanged();
                                    },
                                    onSubmit: _submit,
                                  ),
                                )
                              : _submitLine(preview, showsMath),
                        ),
                      ],
                    ),
                    // All accounts: the last column is the account, so the
                    // note and Add sit under it.
                    if (_picking && (_hasContent || _active))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: SizedBox(
                          width:
                              Cols.category +
                              Cols.amount +
                              Cols.balance +
                              2 * Cols.gap,
                          height: 30,
                          child: _submitLine(preview, showsMath),
                        ),
                      ),
                    if (shortBy != null)
                      _OwedLine(
                        short: shortBy,
                        due: initial!.plannedDate,
                        keep: _keepOwedFor(shortBy),
                        onChanged: (v) => setState(() => _keepOwedChoice = v),
                      ),
                    if (transferLine != null)
                      _TransferLine(
                        text: transferLine,
                        onSwap: initial != null && initial.lockAmount
                            ? null
                            : _swapDirection,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Money in confirmed short: is the rest still owed? Under the category and
/// amount, level with the memo line, only while it applies. "Still owed" is
/// chosen when more than a tenth is missing, so a forgotten remainder stays
/// visible; "Paid in full" for small differences.
class _OwedLine extends StatelessWidget {
  const _OwedLine({
    required this.short,
    required this.due,
    required this.keep,
    required this.onChanged,
  });
  final int short;
  final DateTime due;
  final bool keep;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget choice(String label, bool value, Key key) {
      final on = keep == value;
      return InkWell(
        key: key,
        // Out of Tab order: Enter in any field confirms, and a focused
        // choice would take Enter for itself.
        canRequestFocus: false,
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                on
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 14,
                color: on ? Mid.blue : Mid.ink3,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: onest(
                  12.5,
                  color: on ? Mid.ink : Mid.ink2,
                  tabular: true,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      key: const ValueKey('owed-line'),
      width: Cols.category + Cols.gap + Cols.amount + Cols.gap + Cols.balance,
      height: 30,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.only(left: 10),
      child: Row(
        children: [
          Text(
            '${formatMoney(short, showCents: short % 100 != 0)} less than planned:',
            style: onest(12.5, color: Mid.ink2, tabular: true),
          ),
          const SizedBox(width: 6),
          choice(
            'Still owed, due ${shortDate(due)}',
            true,
            const ValueKey('owed-keep'),
          ),
          choice('Paid in full', false, const ValueKey('owed-full')),
        ],
      ),
    );
  }
}

/// Which way a transfer goes, under its category and amount, lined up with
/// the memo line. Swap turns it around.
class _TransferLine extends StatelessWidget {
  const _TransferLine({required this.text, this.onSwap});
  final String text;
  final VoidCallback? onSwap;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('transfer-line'),
    width: Cols.category + Cols.gap + Cols.amount + Cols.gap + Cols.balance,
    height: 30,
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.only(left: 10),
    child: Row(
      children: [
        const Icon(Icons.swap_horiz_rounded, size: 14, color: Mid.ink3),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: onest(12.5, color: Mid.ink2, tabular: true),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onSwap != null) ...[
          const SizedBox(width: 10),
          Tooltip(
            message: 'Turn it around',
            child: InkWell(
              key: const ValueKey('transfer-swap'),
              onTap: onSwap,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text('Swap', style: onest(12.5, color: Mid.blue)),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// [wanted]: the row has been started and this required field is still empty.
InputDecoration _decoration(
  String hint, {
  bool wanted = false,
  bool small = false,
}) => InputDecoration(
  isDense: true,
  hintText: hint,
  hintStyle: onest(small ? 12.5 : 13.5, color: Mid.ink3),
  filled: true,
  fillColor: Mid.ground.withValues(alpha: 0.6),
  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: small ? 7 : 9),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide.none,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: wanted
        ? BorderSide(color: Mid.ink2.withValues(alpha: 0.45))
        : BorderSide.none,
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: Mid.blue, width: 1.5),
  ),
);

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.focusNode,
    required this.hint,
    this.tabular = false,
    this.align = TextAlign.left,
    this.onSubmitted,
    this.wanted = false,
    this.small = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool tabular;
  final TextAlign align;
  final ValueChanged<String>? onSubmitted;
  final bool wanted;
  final bool small;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    focusNode: focusNode,
    style: onest(
      small ? 12.5 : 13.5,
      tabular: tabular,
      color: small ? Mid.ink2 : Mid.ink,
    ),
    textAlign: align,
    decoration: _decoration(hint, wanted: wanted, small: small),
    onSubmitted: onSubmitted,
    onEditingComplete: () {}, // Enter must not drop focus; _submit moves it.
  );
}

/// The date field, with a calendar under it while it has focus. Typing still
/// works; the calendar follows what's typed.
class DateField extends StatefulWidget {
  const DateField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.today,
    required this.onSubmitted,
    required this.onPicked,
    this.wanted = false,
    this.allowFuture = true,
    this.small = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final DateTime today;
  final VoidCallback onSubmitted;

  /// A day was clicked: the date is filled in, move on.
  final VoidCallback onPicked;
  final bool wanted;

  /// False where a future date means nothing (a statement date): days after
  /// today can't be picked.
  final bool allowFuture;
  final bool small;

  @override
  State<DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<DateField> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_sync);
    widget.controller.addListener(_typed);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_sync);
    widget.controller.removeListener(_typed);
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    setState(() {
      widget.focusNode.hasFocus ? _portal.show() : _portal.hide();
    });
  }

  /// Typing after Esc brings the calendar back.
  void _typed() {
    if (mounted && widget.focusNode.hasFocus && !_portal.isShowing) _sync();
  }

  void _close() => setState(_portal.hide);

  void _pick(DateTime day) {
    widget.controller.value = TextEditingValue(
      text: fullDate(day),
      selection: TextSelection.collapsed(offset: fullDate(day).length),
    );
    _close();
    widget.onPicked();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      // Esc closes the calendar first; the next Esc reaches the row.
      bindings: {
        if (_portal.isShowing)
          const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          offset: const Offset(0, 6),
          child: Align(
            alignment: Alignment.topLeft,
            // Clicks in the calendar count as inside the field, so it keeps focus.
            child: TextFieldTapRegion(
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) => _Calendar(
                  selected: parseEntryDate(
                    widget.controller.text,
                    widget.today,
                  ),
                  today: widget.today,
                  onPick: _pick,
                  allowFuture: widget.allowFuture,
                ),
              ),
            ),
          ),
        ),
        child: CompositedTransformTarget(
          link: _link,
          child: _Field(
            controller: widget.controller,
            focusNode: widget.focusNode,
            hint: 'Date',
            tabular: true,
            wanted: widget.wanted,
            small: widget.small,
            onSubmitted: (_) => widget.onSubmitted(),
          ),
        ),
      ),
    );
  }
}

/// A month of days, Monday first. The selected day is filled, today is
/// underlined, and days after today are gold because picking one schedules
/// the transaction.
class _Calendar extends StatefulWidget {
  const _Calendar({
    required this.selected,
    required this.today,
    required this.onPick,
    this.allowFuture = true,
  });
  final DateTime? selected;
  final DateTime today;
  final ValueChanged<DateTime> onPick;
  final bool allowFuture;

  @override
  State<_Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<_Calendar> {
  late DateTime _month = _monthOf(widget.selected ?? widget.today);
  DateTime? _hover;

  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);

  static const _names = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', //
    'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void didUpdateWidget(_Calendar old) {
    super.didUpdateWidget(old);
    // Typing a date jumps to its month.
    final s = widget.selected;
    if (s != null && s != old.selected) _month = _monthOf(s);
  }

  bool _same(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  bool _future(DateTime d) => d.isAfter(
    DateTime(widget.today.year, widget.today.month, widget.today.day),
  );

  @override
  Widget build(BuildContext context) {
    final lead = _month.weekday - 1; // Monday first
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final hint = _hover ?? widget.selected;

    Widget arrow(IconData icon, int step, String tip) => Tooltip(
      message: tip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () =>
            setState(() => _month = DateTime(_month.year, _month.month + step)),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 18, color: Mid.ink2),
        ),
      ),
    );

    Widget day(DateTime d) {
      final selected = _same(widget.selected, d);
      final today = _same(widget.today, d);
      final off = !widget.allowFuture && _future(d);
      final hovered = !off && _same(_hover, d);
      final color = selected
          ? Colors.white
          : off
          ? Mid.ink3.withValues(alpha: 0.5)
          : _future(d)
          ? Mid.gold
          : Mid.ink;
      return MouseRegion(
        cursor: off ? MouseCursor.defer : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = d),
        onExit: (_) => setState(() => _hover = null),
        child: GestureDetector(
          onTap: off ? null : () => widget.onPick(d),
          child: Container(
            width: 34,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? Mid.blue
                  : hovered
                  ? Mid.chip
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '${d.day}',
              style:
                  onest(
                    13,
                    weight: today || selected ? 600 : 400,
                    color: color,
                    tabular: true,
                  ).copyWith(
                    decoration: today ? TextDecoration.underline : null,
                    decorationColor: color,
                    decorationThickness: 2,
                  ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: Mid.raised,
      elevation: 12,
      shadowColor: Colors.black,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: SizedBox(
          width: 7 * 34,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  arrow(Icons.chevron_left_rounded, -1, 'Previous month'),
                  Expanded(
                    child: Text(
                      '${_names[_month.month - 1]} ${_month.year}',
                      textAlign: TextAlign.center,
                      style: onest(13.5, weight: 600),
                    ),
                  ),
                  arrow(Icons.chevron_right_rounded, 1, 'Next month'),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final n in ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'])
                    SizedBox(
                      width: 34,
                      child: Text(
                        n,
                        textAlign: TextAlign.center,
                        style: onest(11.5, color: Mid.ink3),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                children: [
                  for (var i = 0; i < lead; i++)
                    const SizedBox(width: 34, height: 32),
                  for (var d = 1; d <= days; d++)
                    day(DateTime(_month.year, _month.month, d)),
                ],
              ),
              // Explains the gold, only when it matters.
              if (widget.allowFuture && hint != null && _future(hint))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'After today · it will be scheduled',
                    style: onest(12, color: Mid.gold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Autocomplete<T extends Object> extends StatelessWidget {
  const _Autocomplete({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.options,
    required this.label,
    required this.onSelected,
    required this.onSubmit,
    this.wanted = false,
    this.optionText,
  });

  /// How an option reads in the list, when not as it fills the field.
  final String Function(T)? optionText;

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final Iterable<T> Function(String query) options;
  final String Function(T) label;
  final ValueChanged<T> onSelected;
  final VoidCallback onSubmit;
  final bool wanted;

  @override
  Widget build(BuildContext context) => RawAutocomplete<T>(
    textEditingController: controller,
    focusNode: focusNode,
    displayStringForOption: label,
    optionsBuilder: (v) => options(v.text),
    onSelected: onSelected,
    fieldViewBuilder: (context, c, f, onFieldSubmitted) => TextField(
      controller: c,
      focusNode: f,
      style: onest(13.5),
      decoration: _decoration(hint, wanted: wanted),
      onEditingComplete: () {},
      onSubmitted: (text) {
        // A half-typed name with suggestions showing: Enter picks one.
        // Otherwise Enter means "add the transaction".
        final q = text.trim().toLowerCase();
        final opts = options(text);
        // The "+ New" line isn't a match: "Gro" + Enter picks Groceries.
        final exact = opts.any(
          (o) =>
              label(o).toLowerCase() == q &&
              (optionText == null || optionText!(o) == label(o)),
        );
        if (q.isNotEmpty && opts.isNotEmpty && !exact) {
          onFieldSubmitted();
        } else {
          onSubmit();
        }
      },
    ),
    optionsViewBuilder: (context, onPick, opts) {
      final highlighted = AutocompleteHighlightedOption.of(context);
      final list = opts.toList();
      return Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Material(
            color: Mid.raised,
            elevation: 12,
            shadowColor: Colors.black,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 280,
                maxWidth: 320,
                minWidth: 220,
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (context, i) => InkWell(
                  onTap: () => onPick(list[i]),
                  child: Container(
                    color: i == highlighted ? Mid.blueWash : Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      (optionText ?? label)(list[i]),
                      style: onest(
                        13,
                        color: i == highlighted ? Mid.ink : Mid.ink2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _AddButton extends StatefulWidget {
  const _AddButton({
    required this.label,
    required this.ready,
    required this.onTap,
  });
  final String label;
  final bool ready;
  final VoidCallback onTap;

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ready = widget.ready;
    return Tooltip(
      message: 'Or press Enter in any field',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ready
                  ? (_hover ? const Color(0xFF6B90FF) : Mid.blue)
                  : (_hover ? Mid.raised : Mid.chip),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.label,
              style: onest(
                13,
                weight: 500,
                color: ready ? Colors.white : Mid.ink2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// All accounts: which account a new row goes in. Looks like a field and
/// opens a list; Enter or Space opens it from the keyboard.
class _AccountPicker extends StatelessWidget {
  const _AccountPicker({
    required this.choices,
    required this.value,
    required this.focusNode,
    required this.onPicked,
    required this.onMenu,
    required this.onSubmit,
    this.wanted = false,
  });
  final List<AccountInfo> choices;
  final AccountInfo? value;
  final FocusNode focusNode;
  final ValueChanged<AccountInfo> onPicked;

  /// The list opened or closed: while open, focus in it is still the row's.
  final ValueChanged<bool> onMenu;

  /// Enter with an account picked adds the row, like any field.
  final VoidCallback onSubmit;
  final bool wanted;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    style: const MenuStyle(
      backgroundColor: WidgetStatePropertyAll(Mid.raised),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
    ),
    alignmentOffset: const Offset(0, 4),
    onOpen: () => onMenu(true),
    onClose: () {
      onMenu(false);
      // Back to the field, so Tab and Enter carry on from here.
      focusNode.requestFocus();
    },
    menuChildren: [
      for (final a in choices)
        MenuItemButton(
          key: ValueKey('pick-account-${a.id}'),
          onPressed: () => onPicked(a),
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(200, 34)),
            overlayColor: WidgetStatePropertyAll(Mid.blueWash),
          ),
          trailingIcon: a.id == value?.id
              ? const Icon(Icons.check_rounded, size: 14, color: Mid.blue)
              : null,
          child: Text(
            a.name,
            style: onest(13, color: a.id == value?.id ? Mid.ink : Mid.ink2),
          ),
        ),
    ],
    builder: (context, menu, _) => Focus(
      focusNode: focusNode,
      // Every key stops here but Tab and Esc: it isn't a text field, and a
      // stray C or Delete must never reach the register's row shortcuts.
      onKeyEvent: (node, e) {
        final k = e.logicalKey;
        if (k == LogicalKeyboardKey.tab || k == LogicalKeyboardKey.escape) {
          return KeyEventResult.ignored;
        }
        if (e is! KeyDownEvent) return KeyEventResult.handled;
        if ((k == LogicalKeyboardKey.enter ||
                k == LogicalKeyboardKey.numpadEnter) &&
            value != null &&
            !menu.isOpen) {
          onSubmit();
        } else if (k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.numpadEnter ||
            k == LogicalKeyboardKey.space ||
            k == LogicalKeyboardKey.arrowDown) {
          menu.isOpen ? menu.close() : menu.open();
        }
        return KeyEventResult.handled;
      },
      child: ListenableBuilder(
        listenable: focusNode,
        builder: (context, _) => GestureDetector(
          key: const ValueKey('entry-account'),
          onTap: () {
            focusNode.requestFocus();
            menu.isOpen ? menu.close() : menu.open();
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Mid.ground.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: focusNode.hasFocus || menu.isOpen
                      ? Mid.blue
                      : wanted
                      ? Mid.coral.withValues(alpha: 0.6)
                      : Colors.transparent,
                  width: focusNode.hasFocus || menu.isOpen ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value?.name ?? 'Account',
                      style: onest(
                        13.5,
                        color: value == null ? Mid.ink3 : Mid.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.expand_more_rounded,
                    size: 16,
                    color: Mid.ink3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
