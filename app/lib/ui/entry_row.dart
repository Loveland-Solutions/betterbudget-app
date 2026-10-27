import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/budget.dart' show categoryTakes, isUncategorized;
import '../domain/ledger.dart';
import '../domain/money.dart';
import 'data_words.dart';
import 'language.dart';
import 'register.dart' show BarButton, Cols, SourceColumn;
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
    this.otherAmount,
    this.payId,
    this.remember = false,
    this.splits,
    this.amountUnlocked = false,
  });

  /// Change… was used on an amount a reconcile locked: saving takes back
  /// the reconciles from that one on, as the row said.
  final bool amountUnlocked;

  /// A split (one receipt for groceries and clothing): each category and
  /// its share, signed as [amount] is, adding up to it. [counter] is null.
  /// A category with a negative id is a new one by that name, picked as
  /// "+ New category" on its line: the screen makes it with the row.
  final List<({AccountInfo category, int amount})>? splits;

  /// The box under the row was ticked: remember the category for the payee
  /// (owner, 2026-10-12: "a check box on the transaction for associating
  /// the payee with the category").
  final bool remember;

  /// The pay whose paycheck this is, when one was picked in Category
  /// ("Income · Loveland Solutions"). [counter] is then Income.
  final int? payId;

  /// A transfer to or from an account in another currency: what arrived in
  /// it or left it, in its currency, unsigned. Null otherwise.
  final int? otherAmount;

  /// All accounts: the account the new row goes in. Null in an account's
  /// own register, where it's that account.
  final AccountInfo? account;

  /// A category typed that doesn't exist yet: the screen creates it and
  /// files the row under it. [counter] is null.
  final String? newCategory;

  /// Confirming money in that came short: keep the rest scheduled as still
  /// owed.
  final bool keepOwed;
  final DateTime date;
  final String payee;

  /// Null for a split, and when the category can't be changed here.
  final AccountInfo? counter;

  /// Signed from the register account's perspective. Null when the amount
  /// can't be changed here (reconciled).
  final int? amount;
  final String? memo;
}

/// Lets the screen focus a row (⌘N) and supply the data it needs.
class EntryRowController {
  EntryRowController({required this.onSubmit, required this.suggestCategory});

  /// Returns an error message, or null when the transaction was written.
  final Future<String?> Function(EntryDraft draft) onSubmit;
  final Future<int?> Function(String payee) suggestCategory;

  /// Set by the screen: why the row couldn't be saved, shown as a popup at
  /// the bottom. Null takes it down once the row is edited.
  void Function(String? message) onProblem = (_) {};

  /// Set by the screen: whether this payee is already remembered as this
  /// category (and pay) on the row's account, so the box isn't offered.
  bool Function(String payee, int categoryId, int? payId)? remembered;

  /// Set by the screen: "+ New category" opens the New category window
  /// with the name typed and the row's currency (owner, 2026-10-22, #237).
  /// The category it made or picked, or null when it closed without one.
  Future<AccountInfo?> Function(String name, Currency currency)? newCategory;
  List<String> payeeNames = const [];
  final payeeFocus = FocusNode(debugLabel: 'entry-payee');

  /// All accounts: where new rows go. Kept between rows, so a batch from
  /// one account is picked once.
  AccountInfo? account;

  /// Set by the row: whether anything has been typed or changed.
  bool Function() isDirty = () => false;

  /// Set by the row: what Esc or Cancel does, for when focus is elsewhere.
  void Function() cancel = () {};

  /// Set by the screen while an Edit is open: for an amount a reconcile
  /// locked, what saving a new one takes back, as a sentence; null when it
  /// can't be changed that way (a transfer locked by the other account).
  String? Function()? changeLockedAmount;

  /// Set by the row: whether keyboard focus is anywhere in it, a button
  /// (a split's Category, Swap) as well as a field.
  bool Function() holdsFocus = () => false;

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
         // Its lines are in the split card.
         RowKind.split => '',
         _ => r.categoryLabel,
       },
       row = r,
       amount = r.amount,
       otherAmount = r.otherAmount?.abs(),
       locked = r.locked,
       lockDate = r.locked,
       // A reconciled transfer can't move to another account; a reconciled
       // simple row can still change category.
       lockCategory =
           r.kind == RowKind.opening ||
           (r.locked && r.kind == RowKind.transfer) ||
           r.otherClosed,
       lockAmount = r.locked,
       payeeOptional = r.kind != RowKind.simple,
       variesPay = r.estimate != null;

  final DateTime date;
  final String payee;
  final String memo;
  final String category;

  /// The row opened, for wording [category] when it's locked.
  final RegisterRow row;

  /// [category] as shown when it can't be changed: a transfer to a deleted
  /// account, an opening balance, in the user's language.
  String lockedCategory(Words t) => row.kind == RowKind.transfer
      ? '→ ${rowPayee(t, row)}'
      : rowCategory(t, row);
  final int amount;

  /// A transfer between currencies: the other account's side, unsigned.
  final int? otherAmount;

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

/// A row's date, as [parseEntryDate] reads it, but a month and day with no
/// year is this year's unless that is more than six months ahead (last
/// year's: `12.30` typed on 01.03 is last week's receipt, not next
/// December's) or more than nine months back (next year's: `01.05` typed on
/// 12.28 is next week). Most rows typed are of days gone by.
DateTime? parseRowDate(String input, DateTime today) {
  final d = parseEntryDate(input, today);
  if (d == null) return null;
  final pieces = input.trim().split(RegExp(r'[.\-/]'));
  if (pieces.where((p) => p.isNotEmpty).length != 2) return d;
  final ahead = d.difference(dateOnly(today)).inDays;
  final y = ahead > 183
      ? d.year - 1
      : ahead < -274
      ? d.year + 1
      : d.year;
  final moved = DateTime(y, d.month, d.day);
  // 02.29 has no other year to fall in.
  return moved.day == d.day ? moved : d;
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

/// Why a row's category can't be changed while it's edited.
String _lockedCategoryTip(Words t, RegisterRow r, String reconciledTip) =>
    switch (r.kind) {
      RowKind.transfer when r.locked => reconciledTip,
      RowKind.transfer when r.deletedOther != null => t.rowsOtherAccountDeleted,
      RowKind.transfer => t.rowsOtherAccountArchived,
      RowKind.opening when r.equity == AppEquity.adjustments =>
        t.rowsAdjustmentTip,
      RowKind.opening => t.rowsOpeningBalanceTip,
      _ => reconciledTip,
    };

/// How an amount reads in the field: `30000`, `214750.50`, `+2500000`.
String editableAmount(int minor, [Currency currency = Currency.mnt]) {
  final whole = minor.abs() ~/ currency.scale;
  return '${minor > 0 ? '+' : ''}$whole${currency.hasCents(minor) ? formatCents(minor, currency) : ''}';
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
    this.currency = Currency.mnt,
    this.pays = const [],
    this.notice,
  });

  /// Something the row has to say before it's saved, under its fields.
  final Widget? notice;

  /// Adding: each pay the new row could be a paycheck of, as Category
  /// names it. In All accounts, only those paid into the account picked.
  final List<({int id, int accountId, String label})> pays;

  /// The register's account's currency; All accounts uses the picked one's.
  final Currency currency;

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
    text: _initial == null
        ? ''
        : editableAmount(_initial.amount, widget.currency),
  );
  late final _otherAmount = TextEditingController(
    text: _initial?.otherAmount == null
        ? ''
        : editableAmount(
            _initial!.otherAmount!,
            _initial.row.otherCurrency ?? widget.currency,
          ),
  );
  late final List<TextEditingController> _all = [
    _date,
    _payee,
    _memo,
    _category,
    _amount,
    _otherAmount,
  ];
  late final Map<TextEditingController, String> _start = {
    for (final c in _all) c: c.text,
  };

  final _dateFocus = FocusNode(debugLabel: 'entry-date');
  final _memoFocus = FocusNode(debugLabel: 'entry-memo');
  final _categoryFocus = FocusNode(debugLabel: 'entry-category');
  final _accountFocus = FocusNode(debugLabel: 'entry-account');
  final _amountFocus = FocusNode(debugLabel: 'entry-amount');
  final _otherAmountFocus = FocusNode(debugLabel: 'entry-other-amount');

  /// A split: the row's amount shared over these categories, one line
  /// each. Null for a row with one category.
  /// A category on two lines (left by merging two categories) opens as one
  /// line: a split names each category once (owner, 2026-10-17).
  late List<_SplitLine>? _split = switch (_initial?.row) {
    final r? when r.kind == RowKind.split => [
      for (final (l, share) in _onceEach(r.splitLines))
        _newLine(
          category: l.deleted ?? l.name,
          amount: _lineText(r.amount > 0 ? share : -share),
          accountId: l.accountId,
        ),
    ],
    _ => null,
  };

  static List<(SplitLine, int)> _onceEach(List<SplitLine> lines) {
    final byId = <int, (SplitLine, int)>{};
    for (final l in lines) {
      final had = byId[l.accountId];
      byId[l.accountId] = (had?.$1 ?? l, (had?.$2 ?? 0) + l.amount);
    }
    return byId.values.toList();
  }

  /// The split card is open under the row.
  bool _splitOpen = false;

  /// What the card was opened on, for its Cancel: the lines (null when it
  /// was opened to start a split) and what Category said.
  ({List<(String, String, int?)>? lines, String category})? _splitBefore;

  /// What Category said before "Split" was picked, which
  /// puts its own words in the field.
  String _categoryTyped = '';

  late final String? _splitStart = _splitSig;
  String? get _splitSig => _split
      ?.map((l) => '${l.category.text}\u0000${l.amount.text}')
      .join('\u0001');
  String? _error;
  bool _busy = false;

  /// The box under the row: remember the category for the payee.
  bool _remember = false;

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
    _otherAmountFocus,
    for (final l in _split ?? const <_SplitLine>[]) ...[
      l.categoryFocus,
      l.amountFocus,
    ],
  ];

  /// The "+ New category" line in the list: not an account yet.
  static const _createId = -1;
  ({String label, AccountInfo account}) _createOption(String name) => (
    label: context.t.rowsNewCategoryOption(name),
    account: AccountInfo(id: _createId, name: name, type: AccountType.expense),
  );

  /// "New category" at the top of the list, beside Split, while nothing
  /// new is typed (owner, 2026-10-22: it wasn't in the list to see): the
  /// window, with no name yet. Its label is what the field says, so
  /// picking it leaves the field as it was.
  static const _blankId = -4;
  ({String label, AccountInfo account}) _blankOption(String typed) => (
    label: context.t.rowsNewCategoryBlank,
    account: AccountInfo(id: _blankId, name: typed, type: AccountType.expense),
  );

  /// The "Split" line, at the top of the list (owner, 2026-10-17, as on
  /// the phone). Last in the options, so the keys start on a category.
  static const _splitId = -3;
  ({String label, AccountInfo account}) get _splitOption => (
    label: context.t.rowsSplitOption,
    account: AccountInfo(
      id: _splitId,
      name: context.t.rowsSplitOption,
      type: AccountType.expense,
    ),
  );

  /// Every name the Category field knows, archived categories included: an
  /// old row filed under one keeps it when edited.
  List<({String label, AccountInfo account})> get _counterOptions => [
    ..._payOptions,
    for (final c in widget.categories) (label: c.name, account: c),
    for (final a in widget.transferTargets)
      // Not a transfer to the account it's coming from.
      if (!_picking || a.id != widget.controller.account?.id)
        (label: '→ ${a.name}', account: a),
  ];

  /// All accounts, adding: the row asks which account.
  bool get _picking => widget.accountChoices != null && !_editing;

  /// Whether the row can offer to remember its category for its payee: a
  /// payee, and a category (a new one too; not a transfer, not Not
  /// categorized) that isn't already remembered for it.
  bool get _canRemember {
    if (!(_hasContent || _active)) return false;
    if (_split != null) return false;
    if (_initial?.lockCategory ?? false) return false;
    final payee = _payee.text.trim();
    final q = _category.text.trim().toLowerCase();
    if (payee.isEmpty || q.isEmpty) return false;
    final counter = _counterOptions
        .where((o) => o.label.toLowerCase() == q)
        .firstOrNull
        ?.account;
    if (counter == null) return _newCategory != null;
    if (!counter.isCategory || isUncategorized(counter)) return false;
    return !(widget.controller.remembered?.call(
          payee,
          counter.id,
          _payPicked,
        ) ??
        false);
  }

  /// What this row's amount is in.
  Currency get _hereCurrency => _picking
      ? (widget.controller.account?.currency ?? widget.currency)
      : widget.currency;

  /// The account a transfer typed in Category goes to or comes from.
  AccountInfo? get _transferOther {
    if (!_isTransfer) return null;
    final q = _category.text.trim().toLowerCase();
    return _counterOptions
        .where((o) => o.account.isBalanceSheet && o.label.toLowerCase() == q)
        .map((o) => o.account)
        .firstOrNull;
  }

  /// A transfer with an account in another currency: both sides are asked
  /// for, since no rate is stored (ROADMAP E).
  AccountInfo? get _exchangeWith {
    if (_initial?.lockCategory ?? false) {
      final r = _initial!.row;
      return r.otherCurrency == null
          ? null
          : AccountInfo(
              id: -2,
              name: r.payee,
              type: AccountType.asset,
              currency: r.otherCurrency!,
            );
    }
    final other = _transferOther;
    return other != null && other.currency != _hereCurrency ? other : null;
  }

  /// The account the row is in, for the transfer sentence.
  String? get _here =>
      _picking ? widget.controller.account?.name : widget.accountName;

  /// A new row can be a pay's paycheck: each pay by its name, filed under
  /// Income (owner, 2026-10-06). Not while editing.
  List<({String label, AccountInfo account})> get _payOptions {
    if (_editing) return const [];
    final income = widget.categories.where((c) => c.isIncome).firstOrNull;
    if (income == null) return const [];
    return [
      for (final p in widget.pays)
        if (!_picking || p.accountId == widget.controller.account?.id)
          (label: p.label, account: income),
    ];
  }

  /// The pay named in Category, if one is.
  int? get _payPicked {
    final q = _category.text.trim().toLowerCase();
    if (_payOptions.every((o) => o.label.toLowerCase() != q)) return null;
    return widget.pays.where((p) => p.label.toLowerCase() == q).firstOrNull?.id;
  }

  /// What the list offers: not archived categories, nor ones in another
  /// currency than the row's (a typed name still finds either). With `+`
  /// typed before the amount it's money in, and the income choices come
  /// first; otherwise the spending categories do (owner, 2026-10-06).
  Iterable<({String label, AccountInfo account})> get _listOptions {
    final all = _counterOptions.where(
      (o) =>
          !o.account.archived &&
          (o.account.isBalanceSheet || categoryTakes(o.account, _hereCurrency)),
    );
    final income = all.where((o) => o.account.isIncome);
    final spending = all.where(
      (o) => !o.account.isIncome && !o.account.isBalanceSheet,
    );
    final transfers = all.where((o) => o.account.isBalanceSheet);
    return _amount.text.trim().startsWith('+')
        ? [...income, ...spending, ...transfers]
        : [...spending, ...income, ...transfers];
  }

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
    _category.addListener(_rememberTyped);
    _splitStart; // the lines it opened with
    widget.controller.isDirty = () =>
        _all.any((c) => c.text != _start[c]) || _splitSig != _splitStart;
    widget.controller.cancel = _escape;
    widget.controller.holdsFocus = () {
      final f = FocusManager.instance.primaryFocus?.context;
      return f != null &&
          f.mounted &&
          f.findAncestorStateOfType<_EntryRowState>() == this;
    };
    // A split's category double-clicked: its card opens.
    if (_split != null && _initial!.focus == EditField.category) {
      _splitBefore = (lines: _linesNow, category: '');
      _splitOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _split!.first.categoryFocus.requestFocus();
      });
    }
    if (_editing) {
      // Open with the cursor in the field that was double-clicked.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final (node, ctrl) = switch (_initial!.focus) {
          EditField.date when !_initial.lockDate => (_dateFocus, _date),
          EditField.memo => (_memoFocus, _memo),
          EditField.category when _split != null => (null, null),
          EditField.category when !_initial.lockCategory => (
            _categoryFocus,
            _category,
          ),
          EditField.amount when !_lockAmount => (_amountFocus, _amount),
          _ => (_payeeFocus, _payee),
        };
        if (node == null || ctrl == null) return;
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
    _problem(null);
  }

  /// Why the row can't be saved. The screen says it in a popup: beside Add
  /// there was only room for its first few words.
  void _problem(String? message) {
    final changed = message != _error;
    setState(() => _error = message);
    if (changed) widget.controller.onProblem(message);
  }

  bool _wants(String field) =>
      _hasContent && _missing.any((m) => m.name == field);

  bool get _hasContent =>
      _editing ||
      _payee.text.trim().isNotEmpty ||
      _category.text.trim().isNotEmpty ||
      _amount.text.trim().isNotEmpty;

  bool get _isTransfer => _category.text.trim().startsWith('→');

  /// "+ New category" in Category: the New category window, and the
  /// category it made in the field. Closed without one, the name stays
  /// typed, and saving the row still makes it, bare, as before.
  Future<void> _pickNew(String name) async {
    final open = widget.controller.newCategory;
    final made = open == null ? null : await open(name, _hereCurrency);
    if (!mounted) return;
    if (open == null) {
      // Picked on purpose: no doubt left.
      _chosenNew = name;
      _amountFocus.requestFocus();
      return;
    }
    if (made == null) {
      _categoryFocus.requestFocus();
      return;
    }
    setState(() {
      _category.text = made.name;
      _chosenNew = null;
    });
    _amountFocus.requestFocus();
  }

  /// "+ New category" on a split's line: the same window, and the
  /// category it made on the line.
  Future<void> _pickNewOnLine(_SplitLine l, String name) async {
    final made = await widget.controller.newCategory!(name, _hereCurrency);
    if (!mounted) return;
    setState(() {
      if (made == null) {
        // Closed: a name typed stays picked as new; with none, as it was.
        if (name.isNotEmpty) {
          l.accountId = null;
          l.newName = name;
        }
      } else {
        l.accountId = made.id;
        l.newName = null;
        l.category.text = made.name;
      }
    });
    (made == null ? l.categoryFocus : l.amountFocus).requestFocus();
  }

  /// A name typed in Category that isn't one yet: saving creates it.
  String? get _newCategory {
    if (_split != null || (_initial?.lockCategory ?? false)) return null;
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
    final typed = _newCategory;
    if (typed == null || _chosenNew == typed) return null;
    final t = context.t;
    final q = typed.toLowerCase();
    final account = widget.transferTargets
        .where((a) => a.name.toLowerCase() == q)
        .firstOrNull;
    if (account != null) return t.rowsDidYouMeanTransfer(account.name);
    final near = _listOptions
        .where((o) => o.label.toLowerCase().contains(q))
        .map((o) => o.label)
        .take(2)
        .toList();
    return switch (near) {
      [] => null,
      [final one] => t.rowsNotACategoryPickOne(typed, one),
      [final first, final second, ...] => t.rowsNotACategoryPickTwo(
        typed,
        first,
        second,
      ),
    };
  }

  String get _newCategoryNote => context.t.rowsNewCategoryNote;

  /// With a `+` on a new category, what money in will be: a refund to it,
  /// not income. Its own line under the row, since the note by Add is too
  /// narrow to hold it.
  String? get _refundLine {
    final typed = _newCategory;
    if (typed == null || !_amount.text.trim().startsWith('+')) return null;
    return context.t.rowsNewCategoryRefundNote(typed);
  }

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
    if (initial != null && _lockAmount) {
      amount = initial.amount;
    } else {
      final parsed = parseAmount(
        raw.replaceFirst(RegExp(r'^\+'), ''),
        _hereCurrency,
      );
      amount = parsed == null || parsed == 0
          ? null
          : (raw.startsWith('+') ? parsed.abs() : -parsed.abs());
    }
    final inflow = amount == null ? raw.startsWith('+') : amount > 0;
    final (from, to) = inflow ? (other.name, here) : (here, other.name);
    return amount == null
        ? context.t.rowsTransferFromTo(from, to)
        : context.t.rowsTransferAmountFromTo(
            formatMoney(amount.abs(), currency: _hereCurrency),
            from,
            to,
          );
  }

  /// Confirming money in below plan: how much is missing. Null otherwise:
  /// never for bills (one that came in lower owes nothing more) or transfers
  /// (moving less is the user's own decision).
  int? get _shortBy {
    final initial = _initial;
    if (initial == null ||
        _split != null ||
        !initial.confirming ||
        initial.variesPay ||
        _lockAmount ||
        initial.amount <= 0) {
      return null;
    }
    final raw = _amount.text.trim();
    final parsed = parseAmount(
      raw.replaceFirst(RegExp(r'^\+'), ''),
      _hereCurrency,
    );
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
    if (_category.text.trim().isEmpty &&
        _split == null &&
        !(_initial?.lockCategory ?? false))
      (name: 'category', focus: _categoryFocus),
    // A bare `+` (Swap before any amount) is still no amount.
    if (_amount.text.trim().replaceFirst('+', '').isEmpty && !_lockAmount)
      (name: 'amount', focus: _amountFocus),
    // A transfer to an account in another currency: what the other side
    // sent or got is wanted too.
    if (_exchangeWith != null &&
        _otherAmount.text.trim().replaceFirst('+', '').isEmpty &&
        !_lockAmount)
      (name: 'amount', focus: _otherAmountFocus),
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
      _otherAmountFocus,
    ]) {
      f.dispose();
    }
    for (final l in _split ?? const <_SplitLine>[]) {
      l.dispose();
    }
    _payeeFocus.removeListener(_focusChanged);
    _payeeFocus.removeListener(_prefillCategoryOnLeave);
    super.dispose();
  }

  /// The account list is open: focus is in its items, still in this row.
  bool _accountMenuOpen = false;

  /// Change… on an amount an older reconcile locked: open for typing, and
  /// saving takes back the reconciles from that one on (owner, 2026-10-23).
  bool _amountUnlocked = false;
  bool get _lockAmount => (_initial?.lockAmount ?? false) && !_amountUnlocked;

  void _focusChanged() {
    final active = _accountMenuOpen || _focuses.any((f) => f.hasFocus);
    if (active != _active) setState(() => _active = active);
    // Clicking away from a row with nothing typed or changed in it closes
    // the row (a new one or an Edit); otherwise it stays, so nothing is lost.
    if (!active && !widget.controller.isDirty()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_accountMenuOpen && !_focuses.any((f) => f.hasFocus)) {
          widget.onCancel?.call();
        }
      });
    }
  }

  Future<bool> _prefillCategory() async {
    if (_split != null) return false;
    if (_category.text.isNotEmpty || _payee.text.trim().isEmpty) return false;
    final id = await widget.controller.suggestCategory(_payee.text.trim());
    // The category itself, never a pay that's filed under it.
    final match = _listOptions
        .where((o) => o.account.id == id && o.label == o.account.name)
        .firstOrNull;
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
      _otherAmount.clear();
      _memo.clear();
      _remember = false;
      _dropLines(_split);
      _split = null;
      _splitOpen = false;
      _linesInChosen = null;
    });
    // The next row starts here: a date kept from the last one isn't typing,
    // so ⌘Z after Add still undoes the Add.
    for (final c in _all) {
      _start[c] = c.text;
    }
    _problem(null);
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

  // ---------- the split card ----------

  _SplitLine _newLine({
    String category = '',
    String amount = '',
    int? accountId,
  }) {
    final l = _SplitLine(category: category, amount: amount)
      ..accountId = accountId;
    l.category.addListener(_splitEdited);
    l.amount.addListener(_splitEdited);
    l.categoryFocus.addListener(_focusChanged);
    l.amountFocus.addListener(_focusChanged);
    return l;
  }

  /// Lines taken off: disposed once the card no longer shows them.
  void _dropLines(Iterable<_SplitLine>? lines) {
    final gone = [...?lines];
    if (gone.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final l in gone) {
        l.dispose();
      }
    });
  }

  /// A line's share as it's typed: the amount alone, with a minus when it
  /// goes the other way from the row (a return on the same receipt).
  String _lineText(int share) =>
      // editableAmount marks money in with `+`; a line has no direction of
      // its own, so it's given the amount as money out.
      '${share < 0 ? '-' : ''}${editableAmount(-share.abs(), _hereCurrency)}';

  List<(String, String, int?)>? get _linesNow => _split
      ?.map((l) => (l.category.text, l.amount.text, l.accountId))
      .toList();

  /// The lines as last seen: a controller also speaks up when only its
  /// selection moves, which mustn't take down why the row wasn't saved.
  String? _splitSeen;

  void _splitEdited() {
    if (!mounted) return;
    final now = _splitSig;
    if (now == _splitSeen) return;
    _splitSeen = now;
    setState(() {});
    _problem(null);
  }

  void _rememberTyped() {
    final text = _category.text;
    if (text != context.t.rowsSplitOption) _categoryTyped = text;
  }

  /// The row's total, unsigned: typed, or locked by a reconciliation.
  /// Null while Amount is empty.
  int? get _splitTotal {
    final initial = _initial;
    if (initial != null && _lockAmount) return initial.amount.abs();
    final parsed = parseAmount(
      _amount.text.trim().replaceFirst(RegExp(r'^\+'), ''),
      _hereCurrency,
    );
    return parsed?.abs();
  }

  int? _lineValue(_SplitLine l) => parseAmount(l.amount.text, _hereCurrency);

  int get _splitSum => (_split ?? const <_SplitLine>[]).fold(
    0,
    (s, l) => s + (_lineValue(l) ?? 0),
  );

  /// The categories a line can take: the row's currency, not archived (a
  /// typed name still finds one), no transfers or pay. Not Not categorized:
  /// a split never shows in its tab, so money put there would be forgotten.
  /// Nor a category another line already has.
  /// A name no category has gets "+ New category", as the row's own list
  /// does, in the row's currency (owner's call, 2026-10-17).
  Iterable<AccountInfo> _lineOptions(_SplitLine line, String q) {
    final others = [
      for (final o in _split ?? const <_SplitLine>[])
        if (!identical(o, line)) o,
    ];
    final taken = {for (final o in others) ?_lineCategory(o)?.id};
    final found = widget.categories.where(
      (c) =>
          !c.archived &&
          categoryTakes(c, _hereCurrency) &&
          !isUncategorized(c) &&
          !taken.contains(c.id) &&
          c.name.toLowerCase().contains(q.toLowerCase()),
    );
    final name = q.trim();
    final lower = name.toLowerCase();
    final fresh =
        name.isNotEmpty &&
        _categoryNamed(name) == null &&
        // Not Not categorized, nor a name another line is making.
        !widget.categories.any(
          (c) => isUncategorized(c) && c.name.toLowerCase() == lower,
        ) &&
        !others.any((o) => _lineNew(o)?.toLowerCase() == lower);
    return [
      ...found,
      if (fresh)
        AccountInfo(
          id: _createId,
          name: name,
          type: AccountType.expense,
          currency: _hereCurrency,
        ),
      // Nothing new typed: the window, to name one there. It keeps what
      // the line says, so closing it changes nothing.
      if (!fresh && widget.controller.newCategory != null)
        AccountInfo(id: _blankId, name: q, type: AccountType.expense),
    ];
  }

  /// The new category a line makes: "+ New category" picked for the name
  /// it still says, which no category has.
  String? _lineNew(_SplitLine l) {
    final name = l.category.text.trim();
    final picked = l.newName;
    if (picked == null || name.toLowerCase() != picked.toLowerCase()) {
      return null;
    }
    return _lineCategory(l) == null ? name : null;
  }

  /// The category a line will be saved under: one there is, or a new one
  /// by its name (a negative id, made by the screen with the row).
  AccountInfo? _lineTarget(_SplitLine l) =>
      _lineCategory(l) ??
      switch (_lineNew(l)) {
        final name? => AccountInfo(
          id: _createId,
          name: name,
          type: AccountType.expense,
          currency: _hereCurrency,
        ),
        null => null,
      };

  /// The category a name means in this row's currency: a tugrik and a
  /// dollar Groceries can both exist. Archived ones last.
  AccountInfo? _categoryNamed(String name) {
    final q = name.trim().toLowerCase();
    final found = widget.categories.where(
      (c) =>
          c.name.toLowerCase() == q &&
          categoryTakes(c, _hereCurrency) &&
          !isUncategorized(c),
    );
    return found.where((c) => !c.archived).firstOrNull ?? found.firstOrNull;
  }

  /// A line's category: the one picked or opened with, while its name is
  /// still what the line says; otherwise by name.
  AccountInfo? _lineCategory(_SplitLine l) {
    final name = l.category.text.trim().toLowerCase();
    final kept = widget.categories
        .where((c) => c.id == l.accountId && c.name.toLowerCase() == name)
        .firstOrNull;
    return kept ?? _categoryNamed(name);
  }

  /// Every named line is Income: money in, as a row filed under Income is.
  bool get _splitIsIncome {
    final named = [
      for (final l in _split ?? const <_SplitLine>[])
        if (l.category.text.trim().isNotEmpty) _lineCategory(l),
    ];
    return named.isNotEmpty && named.every((c) => c?.isIncome ?? false);
  }

  /// Opens the card: on the lines there are, or on two new ones, the first
  /// taking the category Category named, if it named one.
  void _openSplit() {
    final fresh = _split == null;
    setState(() {
      _splitBefore = (lines: _linesNow, category: fresh ? _categoryTyped : '');
      if (fresh) {
        final named = _categoryNamed(_categoryTyped);
        _split = [
          _newLine(category: named?.name ?? '', accountId: named?.id),
          _newLine(),
        ];
      }
      _category.text = '';
      _splitOpen = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _split == null) return;
      final next = _split!
          .where((l) => l.category.text.isEmpty || l.amount.text.isEmpty)
          .firstOrNull;
      (next == null
              ? _split!.first.categoryFocus
              : next.category.text.isEmpty
              ? next.categoryFocus
              : next.amountFocus)
          .requestFocus();
    });
  }

  /// Cancel, or Esc in the card: the lines as they were when it opened.
  void _cancelSplit() {
    final before = _splitBefore;
    setState(() {
      _dropLines(_split);
      _split = before?.lines == null
          ? null
          : [
              for (final (c, a, id) in before!.lines!)
                _newLine(category: c, amount: a, accountId: id),
            ];
      if (_split == null) _category.text = before?.category ?? '';
      _splitOpen = false;
    });
    _problem(null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _categoryFocus.requestFocus();
    });
  }

  /// Done: the card closes on its lines. Empty lines go; with none left the
  /// row has one category again, and one line that takes the whole amount
  /// becomes the row's category. With Amount empty, it takes the lines' sum.
  void _doneSplit({bool focus = true}) {
    final lines = _split ?? const <_SplitLine>[];
    final kept = lines
        .where(
          (l) =>
              l.category.text.trim().isNotEmpty ||
              l.amount.text.trim().isNotEmpty,
        )
        .toList();
    setState(() {
      _dropLines(lines.where((l) => !kept.contains(l)));
      _split = kept;
      _totalFromLines();
      final one = kept.length == 1 ? kept.single : null;
      if (kept.isEmpty) {
        _split = null;
        _category.text = _splitBefore?.category ?? '';
      } else if (one != null &&
          _lineTarget(one) != null &&
          (one.amount.text.trim().isEmpty || _lineValue(one) == _splitTotal)) {
        final target = _lineTarget(one)!;
        _category.text = target.name;
        // A new one, picked on purpose: no doubt left about the name.
        if (target.id == _createId) _chosenNew = target.name;
        _dropLines(kept);
        _split = null;
      }
      _splitOpen = false;
    });
    if (!focus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final locked = _lockAmount;
      (locked ? _categoryFocus : _amountFocus).requestFocus();
    });
  }

  /// With Amount empty, the lines' sum goes in it, as a typed amount: money
  /// out unless the row says in.
  void _totalFromLines() {
    final sum = _splitSum;
    if (_splitTotal != null || _lockAmount) return;
    if (sum == 0) {
      // Lines that even out: a total of 0, nothing in or out.
      if (_splitEven) _amount.text = editableAmount(0, _hereCurrency);
      return;
    }
    _amount.text = editableAmount(_linesIn ? sum : -sum, _hereCurrency);
  }

  /// Lines typed with Amount empty: whether their total is money in. Money
  /// out unless the row says in (a `+`, or every line Income), or the card's
  /// button was clicked: a default, not a question (owner, 2026-09-18).
  bool? _linesInChosen;
  bool get _linesIn =>
      _linesInChosen ?? (_amount.text.trim().startsWith('+') || _splitIsIncome);

  /// The lines go both ways and come to 0: an even exchange on one
  /// receipt, a ₮37,500 shirt returned for ₮37,500 of groceries.
  bool get _splitEven {
    final values = [
      for (final l in _split ?? const <_SplitLine>[]) ?_lineValue(l),
    ];
    return values.any((v) => v > 0) &&
        values.any((v) => v < 0) &&
        values.fold(0, (s, v) => s + v) == 0;
  }

  /// Enter in a line's amount: on to the next line still missing its
  /// category or amount; a new line while some of the total is left to
  /// place, or while no total is typed (a receipt of three, added up as
  /// it's typed); Enter on a line left empty is Done, and the line goes.
  void _lineEntered(_SplitLine l) {
    final lines = _split!;
    if (l.category.text.trim().isEmpty && l.amount.text.trim().isEmpty) {
      if (lines.length > 2) _removeLine(l);
      _doneSplit();
      return;
    }
    final after = [
      ...lines.skip(lines.indexOf(l) + 1),
      ...lines.take(lines.indexOf(l)),
    ];
    final next = after
        .where(
          (o) => o.category.text.trim().isEmpty || o.amount.text.trim().isEmpty,
        )
        .firstOrNull;
    final total = _splitTotal;
    if (next != null) {
      (next.category.text.trim().isEmpty
              ? next.categoryFocus
              : next.amountFocus)
          .requestFocus();
    } else if (total == null || total - _splitSum > 0) {
      _addLine();
    } else {
      _doneSplit();
    }
  }

  void _addLine() {
    final l = _newLine();
    setState(() => _split = [..._split!, l]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) l.categoryFocus.requestFocus();
    });
  }

  void _removeLine(_SplitLine l) {
    setState(() {
      _split = [..._split!]..remove(l);
      _dropLines([l]);
    });
  }

  /// The lines as saved, or why they can't be and where to fix it. A line
  /// with a category and no amount counts as nothing; Add waits until the
  /// lines add up to the total (owner, 2026-10-17).
  ({
    List<({AccountInfo category, int amount})>? parts,
    (String, FocusNode)? error,
  })
  _checkSplit(bool inflow, int? typedTotal) {
    final t = context.t;
    String money(int v) => formatMoney(v.abs(), currency: _hereCurrency);
    final parts = <({AccountInfo category, int amount})>[];
    final seen = <String>{};
    var sum = 0;
    for (final l in _split!) {
      final name = l.category.text.trim();
      final typed = l.amount.text.trim();
      final v = _lineValue(l);
      if (name.isEmpty && typed.isEmpty) continue;
      if (typed.isNotEmpty && v == null) {
        return (parts: null, error: (t.rowsErrorAmount(typed), l.amountFocus));
      }
      if (name.isEmpty) {
        return (
          parts: null,
          error: (t.rowsErrorSplitNoCategory(money(v!)), l.categoryFocus),
        );
      }
      final category = _lineTarget(l);
      if (category == null) {
        return (
          parts: null,
          error: (t.rowsErrorSplitUnknown(name), l.categoryFocus),
        );
      }
      final key = category.id == _createId
          ? 'new ${category.name.toLowerCase()}'
          : '${category.id}';
      if (!seen.add(key)) {
        return (
          parts: null,
          error: (t.rowsErrorSplitTwice(category.name), l.categoryFocus),
        );
      }
      if (v == null || v == 0) continue;
      sum += v;
      parts.add((category: category, amount: inflow ? v : -v));
    }
    final total = typedTotal ?? _splitTotal ?? sum;
    final last = _split!.last;
    if (total - sum > 0) {
      final empty = _split!
          .where((l) => l.amount.text.trim().isEmpty)
          .firstOrNull;
      return (
        parts: null,
        error: (
          t.rowsErrorSplitLeft(money(total - sum)),
          (empty ?? last).amountFocus,
        ),
      );
    }
    if (total - sum < 0) {
      return (
        parts: null,
        error: (t.rowsErrorSplitTooMuch(money(sum - total)), last.amountFocus),
      );
    }
    if (parts.isEmpty) {
      return (
        parts: null,
        error: (t.rowsErrorSplitLeft(money(total)), last.amountFocus),
      );
    }
    return (parts: parts, error: null);
  }

  /// How many categories: while the card is open, its lines; once Done,
  /// the categories they name, one named twice counted once.
  int get _splitCount {
    if (_splitOpen) return _split!.length;
    final names = {
      for (final l in _split!)
        if (l.category.text.trim().isNotEmpty)
          l.category.text.trim().toLowerCase(),
    };
    return names.isEmpty ? _split!.length : names.length;
  }

  /// What Category shows for a split: how many categories, a click opening
  /// the card.
  Widget _splitButton(Words t) => Tooltip(
    message: _split!
        .map((l) => l.category.text)
        .where((n) => n.isNotEmpty)
        .join(' · '),
    child: InkWell(
      key: const ValueKey('split-categories'),
      focusNode: _categoryFocus,
      borderRadius: BorderRadius.circular(7),
      onTap: _splitOpen ? null : _openSplit,
      child: Container(
        height: 34,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Mid.card,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: _splitOpen ? Mid.blue : Mid.rule),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                t.startSplitCategories(_splitCount),
                style: onest(13.5, color: Mid.ink2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.call_split_rounded, size: 14, color: Mid.ink3),
          ],
        ),
      ),
    ),
  );

  /// The card under the row (owner's pick, 2026-10-17, option C): the
  /// receipt's total at the top with what's left to place, a category and
  /// an amount on each line, Cancel and Done.
  Widget _splitCard(Words t, double width) {
    final total = _splitTotal;
    final sum = _splitSum;
    String money(int v) => formatMoney(v.abs(), currency: _hereCurrency);
    final payee = _payee.text.trim();
    final title = total == null
        ? payee
        : payee.isEmpty
        ? money(total)
        : t.rowsSplitTitle(payee, money(total));
    final left = total == null ? null : total - sum;
    final note = switch (left) {
      null when sum != 0 => t.rowsSplitInAll(money(sum)),
      null || 0 => null,
      > 0 => t.rowsSplitLeft(money(left)),
      _ => t.rowsSplitTooMuch(money(left)),
    };
    final lines = _split!;
    final even = _splitEven && (total == null || total == 0);
    final way = even
        ? t.rowsSplitEven
        : total != null || sum == 0 || _lockAmount
        ? null
        : (_linesIn ? t.rowsSplitIsIn : t.rowsSplitIsOut);
    Widget label(String text, {TextAlign align = TextAlign.left}) => Padding(
      padding: const EdgeInsets.only(left: 2, right: 2, bottom: 4),
      child: Text(
        text,
        textAlign: align,
        style: onest(12, color: Mid.ink3),
      ),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _cancelSplit,
      },
      child: Container(
        key: const ValueKey('split-card'),
        width: width,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: BoxDecoration(
          color: Mid.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Mid.rule),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: Mid.isLight ? 0.10 : 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: onest(15, weight: 600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (note != null)
                  Text(
                    note,
                    key: const ValueKey('split-left'),
                    style: onest(12.5, color: Mid.ink2, tabular: true),
                  ),
              ],
            ),
            // Amount empty: which way the lines' total goes, said before
            // Add, with the other way one click off.
            if (way != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        way,
                        key: const ValueKey('split-way'),
                        style: onest(12.5, color: Mid.ink2),
                      ),
                    ),
                    if (!even) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        key: const ValueKey('split-switch-way'),
                        onPressed: () =>
                            setState(() => _linesInChosen = !_linesIn),
                        style: TextButton.styleFrom(
                          foregroundColor: Mid.blue,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(0, 26),
                          visualDensity: VisualDensity.standard,
                          textStyle: onest(12.5, weight: 500),
                        ),
                        child: Text(
                          _linesIn ? t.rowsSplitMakeOut : t.rowsSplitMakeIn,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: label(t.rowsColumnCategory)),
                const SizedBox(width: 12),
                SizedBox(
                  width: 150,
                  child: label(t.rowsColumnAmount, align: TextAlign.right),
                ),
                const SizedBox(width: 34),
              ],
            ),
            for (final l in lines)
              Padding(
                key: ObjectKey(l),
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: _Autocomplete<AccountInfo>(
                        controller: l.category,
                        focusNode: l.categoryFocus,
                        hint: t.rowsHintCategory,
                        options: (q) => _lineOptions(l, q),
                        label: (c) => c.name,
                        optionText: (c) => c.id == _createId
                            ? t.rowsNewCategoryOption(c.name)
                            : c.id == _blankId
                            ? t.rowsNewCategoryBlank
                            : c.name,
                        pinned: (c) => c.id == _blankId,
                        pinnedIcon: (_) => Icons.add_rounded,
                        onSelected: (c) {
                          if (c.id == _blankId) {
                            _pickNewOnLine(l, '');
                            return;
                          }
                          if (c.id == _createId &&
                              widget.controller.newCategory != null) {
                            _pickNewOnLine(l, c.name);
                            return;
                          }
                          if (c.id == _createId) {
                            l.accountId = null;
                            l.newName = c.name;
                          } else {
                            l.accountId = c.id;
                            l.newName = null;
                          }
                          setState(() {});
                          l.amountFocus.requestFocus();
                        },
                        onSubmit: l.amountFocus.requestFocus,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 150,
                      child: _Field(
                        controller: l.amount,
                        focusNode: l.amountFocus,
                        hint: zeroHint(_hereCurrency),
                        tabular: true,
                        align: TextAlign.right,
                        onSubmitted: (_) => _lineEntered(l),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 28,
                      height: 28,
                      // Offered while there's more than one line to keep.
                      child: lines.length < 2
                          ? null
                          : Tooltip(
                              message: t.rowsSplitRemove,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                canRequestFocus: false,
                                onTap: () => _removeLine(l),
                                child: Semantics(
                                  button: true,
                                  label: t.rowsSplitRemove,
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: Mid.ink3,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton(
                  key: const ValueKey('split-another'),
                  onPressed: _addLine,
                  style: TextButton.styleFrom(
                    foregroundColor: Mid.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 30),
                    textStyle: onest(12.5, weight: 500),
                  ),
                  child: Text(t.rowsSplitAnother),
                ),
                const Spacer(),
                _AddButton(
                  key: const ValueKey('split-cancel'),
                  label: t.rowsCancelEdit,
                  keyName: 'Esc',
                  quiet: true,
                  ready: false,
                  onTap: _cancelSplit,
                ),
                const SizedBox(width: 6),
                _AddButton(
                  key: const ValueKey('split-done'),
                  label: t.rowsSplitDone,
                  ready: true,
                  onTap: _doneSplit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Enter in any field, or the Add/Save button, lands here.
  Future<void> _submit() async {
    if (_busy) return;
    // Add with the card open: its lines as they stand, an empty Amount
    // taking their sum as Done would.
    if (_splitOpen) _totalFromLines();
    if (_category.text.trim().isEmpty && _split == null) {
      await _prefillCategory();
    }
    if (!mounted) return;
    final t = context.t;

    final missing = _missing;
    if (missing.isNotEmpty) {
      final name = missing.first.name;
      _problem(context.t.rowsEnterMissing(name == 'date' ? 'when' : name));
      missing.first.focus.requestFocus();
      return;
    }

    final lockCategory = _initial?.lockCategory ?? false;
    final lockAmount = _lockAmount;
    final date = parseRowDate(_date.text, widget.today);
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
        raw.startsWith('+') ||
        (_split == null
            ? counter?.account.type == AccountType.income
            : _splitIsIncome);
    final parsed = lockAmount
        ? null
        : parseAmount(
            raw.startsWith('+') ? raw.substring(1) : raw,
            _hereCurrency,
          );

    String? error;
    FocusNode? fix;
    if (date == null) {
      (error, fix) = (t.rowsErrorDate, _dateFocus);
    } else if (_picking &&
        _category.text.trim().toLowerCase() ==
            '→ ${widget.controller.account?.name}'.toLowerCase()) {
      (error, fix) = (t.rowsErrorSameAccount, _categoryFocus);
    } else if (_split == null &&
        !lockCategory &&
        counter == null &&
        _newCategory == null) {
      (error, fix) = (
        t.rowsErrorNoAccount(_category.text.trim()),
        _categoryFocus,
      );
    } else if (_split == null &&
        !lockCategory &&
        counter == null &&
        _newCategoryDoubt != null) {
      (error, fix) = (_newCategoryDoubt!, _categoryFocus);
    } else if (!lockAmount &&
        (parsed == null || (parsed == 0 && !(_split != null && _splitEven)))) {
      // 0 only for an even exchange on one receipt: lines both ways.
      (error, fix) = (t.rowsErrorAmount(raw), _amountFocus);
    } else if (_exchangeWith case final other?
        when !lockAmount && (_otherParsed ?? 0) == 0) {
      (error, fix) = (
        isInflow
            ? t.rowsErrorLeftOther(other.name)
            : t.rowsErrorArrivesOther(other.name),
        _otherAmountFocus,
      );
    }
    if (error != null) {
      fix!.requestFocus();
      _problem(error);
      return;
    }

    // A split's lines, checked; one line left that takes the whole amount
    // is saved as an ordinary row in that category.
    var splitCounter = _split == null ? counter?.account : null;
    var newCategory = _split == null && splitCounter == null
        ? _newCategory
        : null;
    final wasSplit = _initial?.row.kind == RowKind.split;
    List<({AccountInfo category, int amount})>? splits;
    // A split opened and saved with its lines and total as they were (a
    // new memo): its entries stay as they are, a deleted category too.
    final splitUntouched =
        _editing &&
        _split != null &&
        _splitSig == _splitStart &&
        _amount.text == _start[_amount];
    if (_split != null && !splitUntouched) {
      final checked = _checkSplit(isInflow, parsed?.abs());
      if (checked.error case (final message, final node)) {
        if (!_splitOpen) _openSplit();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) node.requestFocus();
        });
        _problem(message);
        return;
      }
      final parts = checked.parts!;
      setState(() => _splitOpen = false);
      if (parts.length == 1 && !wasSplit) {
        final only = parts.single.category;
        // A new category on the one line: made with the row, as Category's
        // own "+ New category" is.
        if (only.id == _createId) {
          newCategory = only.name;
        } else {
          splitCounter = only;
        }
      } else {
        splits = parts;
      }
    } else if (wasSplit &&
        _split == null &&
        ((splitCounter != null && splitCounter.isCategory) ||
            newCategory != null)) {
      // A split brought down to one category: its lines become one, as a
      // split's do, rather than the two-entry path.
      final total = parsed?.abs() ?? _initial!.amount.abs();
      final one =
          splitCounter ??
          AccountInfo(
            id: _createId,
            name: newCategory!,
            type: AccountType.expense,
            currency: _hereCurrency,
          );
      splits = [(category: one, amount: isInflow ? total : -total)];
      splitCounter = null;
      newCategory = null;
    }

    setState(() => _busy = true);
    final result = await widget.controller.onSubmit(
      EntryDraft(
        date: date!,
        payee: _payee.text.trim(),
        counter: splitCounter,
        splits: splits,
        amount: parsed == null || splitUntouched
            ? null
            : (isInflow ? parsed.abs() : -parsed.abs()),
        memo: _memo.text,
        keepOwed: _shortBy != null && _keepOwedFor(_shortBy!),
        newCategory: newCategory,
        payId: _payPicked,
        account: _picking ? widget.controller.account : null,
        otherAmount: _exchangeWith == null ? null : _otherParsed?.abs(),
        remember: _remember && _canRemember && splits == null,
        amountUnlocked: _amountUnlocked,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result != null) {
      _problem(result);
    } else if (!_editing) {
      _reset();
    }
  }

  int? get _otherParsed => parseAmount(
    _otherAmount.text.trim().replaceFirst(RegExp(r'^\+'), ''),
    _exchangeWith?.currency ?? _hereCurrency,
  );

  /// The new row's Cancel, under Add.
  Widget _cancelLine() => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: SizedBox(
      width:
          Cols.category +
          Cols.amount +
          Cols.balance +
          2 * Cols.gap +
          (SourceColumn.showing(context) ? Cols.source + Cols.gap : 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _AddButton(
            key: const ValueKey('cancel-entry'),
            label: context.t.rowsCancelEdit,
            keyName: 'Esc',
            quiet: true,
            ready: false,
            onTap: _escape,
          ),
        ],
      ),
    ),
  );

  /// The note (what's missing, the sum) and Add.
  Widget _submitLine(int? preview, bool showsMath) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Flexible(child: _note(preview, showsMath)),
      // A new row's Cancel is on a line of its own ([_cancelLine]), so it
      // doesn't squeeze what's missing; under All accounts' wide line it
      // fits here.
      if (_editing || (_picking && _hasContent)) ...[
        const SizedBox(width: 6),
        _AddButton(
          key: ValueKey(_editing ? 'cancel-edit' : 'cancel-entry'),
          label: context.t.rowsCancelEdit,
          keyName: 'Esc',
          quiet: true,
          ready: false,
          onTap: _escape,
        ),
      ],
      if (_hasContent || _active) ...[
        SizedBox(width: _editing ? 4 : 10),
        _AddButton(
          key: const ValueKey('entry-submit'),
          label: _initial?.confirming ?? false
              ? context.t.rowsConfirm
              : (_editing ? context.t.rowsSave : context.t.rowsAdd),
          ready: _missing.isEmpty && _error == null,
          onTap: _submit,
        ),
      ],
    ],
  );

  Widget _note(int? preview, bool showsMath) {
    final t = context.t;
    final String text;
    final Color color;
    if (showsMath) {
      (text, color) = (
        // The new-category note stays in sight while the sum shows.
        _newCategory == null
            ? t.rowsSum(formatMoney(preview!, currency: _hereCurrency))
            : t.rowsSumWithNote(
                formatMoney(preview!, currency: _hereCurrency),
                _newCategoryNote,
              ),
        Mid.ink2,
      );
    } else if (_newCategory != null) {
      // Said before saving, so a typo doesn't quietly become a category.
      (text, color) = (_newCategoryNote, Mid.note);
    } else if (_hasContent && _missing.isNotEmpty) {
      final m = _missing;
      (text, color) = (
        m.length == 1
            ? t.rowsNeeds(m.single.name == 'date' ? 'when' : m.single.name)
            : t.rowsNeedsMore(m.length),
        Mid.ink3,
      );
    } else {
      return const SizedBox.shrink();
    }
    // Two short lines when it doesn't fit beside Add ("Type an / amount"),
    // rather than cut off.
    return Tooltip(
      message: text,
      child: Text(
        text,
        style: onest(12, color: color, tabular: true, height: 1.15),
        textAlign: TextAlign.right,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

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
      _hereCurrency,
    );
    final showsMath =
        preview != null && RegExp(r'\d[+\-*/×]').hasMatch(_amount.text);
    final initial = _initial;
    final lit = _active || _editing;
    final transferLine = _transferLine;
    final refundLine = _refundLine;
    final shortBy = _shortBy;
    final t = context.t;
    // An amount a reconcile locked, and what changing it would take back.
    final takesBack = (initial?.lockAmount ?? false)
        ? widget.controller.changeLockedAmount?.call()
        : null;
    final reconciledTip = t.rowsReconciledTip;

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _escape},
      // A click on the row's own buttons isn't a click away from its fields:
      // Confirm on an untouched row must land before the row closes.
      child: TextFieldTapRegion(
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
              child: Column(
                children: [
                  Row(
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
                            ? _locked(
                                fullDate(initial.date),
                                tip: reconciledTip,
                              )
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
                                hint: _editing
                                    ? t.rowsHintPayee
                                    : t.rowsHintNewPayee,
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
                            if (_editing ||
                                _active ||
                                _memo.text.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              FocusTraversalOrder(
                                order: const NumericFocusOrder(2.5),
                                child: _Field(
                                  controller: _memo,
                                  focusNode: _memoFocus,
                                  hint: t.rowsHintMemo,
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
                                        initial.lockedCategory(t),
                                        tip: _lockedCategoryTip(
                                          t,
                                          initial.row,
                                          reconciledTip,
                                        ),
                                      )
                                    : _split != null
                                    ? FocusTraversalOrder(
                                        order: const NumericFocusOrder(3),
                                        child: _splitButton(t),
                                      )
                                    : FocusTraversalOrder(
                                        order: const NumericFocusOrder(3),
                                        child:
                                            _Autocomplete<
                                              ({
                                                String label,
                                                AccountInfo account,
                                              })
                                            >(
                                              controller: _category,
                                              focusNode: _categoryFocus,
                                              hint: t.rowsHintCategory,
                                              wanted: _wants('category'),
                                              options: (q) => [
                                                ..._listOptions.where(
                                                  (o) => o.label
                                                      .toLowerCase()
                                                      .contains(
                                                        q.toLowerCase(),
                                                      ),
                                                ),
                                                if (_newCategory case final n?)
                                                  _createOption(n)
                                                else if (!_isTransfer &&
                                                    widget
                                                            .controller
                                                            .newCategory !=
                                                        null)
                                                  _blankOption(q),
                                                // Whatever's typed: it starts
                                                // from the category named.
                                                if (!_isTransfer) _splitOption,
                                              ],
                                              label: (o) =>
                                                  o.account.id == _createId ||
                                                      o.account.id == _blankId
                                                  ? o.account.name
                                                  : o.label,
                                              optionText: (o) => o.label,
                                              pinned: (o) =>
                                                  o.account.id == _splitId ||
                                                  o.account.id == _blankId,
                                              pinnedIcon: (o) =>
                                                  o.account.id == _blankId
                                                  ? Icons.add_rounded
                                                  : Icons.call_split_rounded,
                                              onSelected: (o) {
                                                if (o.account.id == _splitId) {
                                                  _openSplit();
                                                  return;
                                                }
                                                if (o.account.id == _createId) {
                                                  _pickNew(o.account.name);
                                                  return;
                                                }
                                                if (o.account.id == _blankId) {
                                                  _pickNew('');
                                                  return;
                                                }
                                                _amountFocus.requestFocus();
                                              },
                                              onSubmit: _submit,
                                            ),
                                      ),
                              ),
                              const SizedBox(width: Cols.gap),
                              if (SourceColumn.showing(context)) ...[
                                const SizedBox(width: Cols.source),
                                const SizedBox(width: Cols.gap),
                              ],
                              SizedBox(
                                width: Cols.amount,
                                child: initial != null && _lockAmount
                                    ? Align(
                                        alignment: Alignment.centerRight,
                                        child: _locked(
                                          // As the register shows it: out plain, in with +.
                                          initial.amount > 0
                                              ? '+${formatMoney(initial.amount, currency: _hereCurrency)}'
                                              : formatMoney(
                                                  initial.amount.abs(),
                                                  currency: _hereCurrency,
                                                ),
                                          tip: reconciledTip,
                                        ),
                                      )
                                    : FocusTraversalOrder(
                                        order: const NumericFocusOrder(4),
                                        child: _Field(
                                          controller: _amount,
                                          focusNode: _amountFocus,
                                          hint: zeroHint(_hereCurrency),
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
                                          onPicked: (a) {
                                            setState(
                                              () =>
                                                  widget.controller.account = a,
                                            );
                                            _problem(null);
                                          },
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
                          if (_splitOpen && _split != null)
                            FocusTraversalOrder(
                              // Under Category, before Amount.
                              order: const NumericFocusOrder(3.5),
                              child: FocusTraversalGroup(
                                child: _splitCard(
                                  t,
                                  Cols.category +
                                      Cols.amount +
                                      Cols.balance +
                                      2 * Cols.gap +
                                      (SourceColumn.showing(context)
                                          ? Cols.source + Cols.gap
                                          : 0),
                                ),
                              ),
                            ),
                          if (takesBack != null)
                            _ChangeLockedLine(
                              open: _amountUnlocked,
                              takesBack: takesBack,
                              width:
                                  Cols.category +
                                  Cols.amount +
                                  Cols.balance +
                                  2 * Cols.gap +
                                  (SourceColumn.showing(context)
                                      ? Cols.source + Cols.gap
                                      : 0),
                              onChange: () {
                                setState(() => _amountUnlocked = true);
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!mounted) return;
                                  _amountFocus.requestFocus();
                                  _amount.selection = TextSelection(
                                    baseOffset: 0,
                                    extentOffset: _amount.text.length,
                                  );
                                });
                              },
                            ),
                          if (shortBy != null)
                            _OwedLine(
                              short: shortBy,
                              due: initial!.plannedDate,
                              keep: _keepOwedFor(shortBy),
                              currency: _hereCurrency,
                              onChanged: (v) =>
                                  setState(() => _keepOwedChoice = v),
                            ),
                          if (_canRemember)
                            _RememberLine(
                              on: _remember,
                              onChanged: (v) => setState(() => _remember = v),
                            ),
                          if (transferLine != null)
                            _TransferLine(
                              text: transferLine,
                              onSwap: initial != null && _lockAmount
                                  ? null
                                  : _swapDirection,
                            ),
                          if (refundLine != null) _RefundLine(text: refundLine),
                          if (_exchangeWith case final other?)
                            _ExchangeLine(
                              other: other,
                              inflow: _amount.text.trim().startsWith('+'),
                              here: _hereCurrency,
                              hereAmount: preview,
                              controller: _otherAmount,
                              focusNode: _otherAmountFocus,
                              locked: initial != null && _lockAmount,
                              wanted: _hasContent && (_otherParsed ?? 0) == 0,
                              onSubmitted: _submit,
                            ),
                          // A new row with something in it can be thrown away
                          // with the mouse too; an empty one closes with a
                          // click away.
                          if (!_editing &&
                              !_picking &&
                              _hasContent &&
                              !_splitOpen)
                            _cancelLine(),
                        ],
                      ),
                    ],
                  ),
                  // The row's whole width: it names another row.
                  ?widget.notice,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The box under the row (owner, 2026-10-12): tick it and the category is
/// remembered for the payee when the row is saved, as the popup's offer
/// does. Out of Tab order, so Enter still saves.
class _RememberLine extends StatelessWidget {
  const _RememberLine({required this.on, required this.onChanged});
  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    width: Cols.category + Cols.gap + Cols.amount + Cols.gap + Cols.balance,
    height: 30,
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.only(left: 4),
    alignment: Alignment.centerLeft,
    child: InkWell(
      key: const ValueKey('remember-line'),
      canRequestFocus: false,
      onTap: () => onChanged(!on),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              on
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 16,
              color: on ? Mid.blue : Mid.ink3,
            ),
            const SizedBox(width: 6),
            Text(
              context.t.rowsRemember,
              style: onest(12.5, color: on ? Mid.ink : Mid.ink2),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Under a row whose amount an older reconcile locked: Change… opens it,
/// and once open the line says what saving takes back.
class _ChangeLockedLine extends StatelessWidget {
  const _ChangeLockedLine({
    required this.open,
    required this.takesBack,
    required this.width,
    required this.onChange,
  });
  final bool open;
  final String takesBack;
  final double width;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: SizedBox(
      width: width,
      child: open
          ? Text(
              takesBack,
              key: const ValueKey('change-locked-note'),
              style: onest(12.5, color: Mid.ink2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                BarButton(
                  key: const ValueKey('change-locked-amount'),
                  label: context.t.rowsChangeLockedAmount,
                  onTap: onChange,
                ),
              ],
            ),
    ),
  );
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
    this.currency = Currency.mnt,
  });
  final Currency currency;
  final int short;
  final DateTime due;
  final bool keep;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
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
            t.rowsLessThanPlanned(formatShort(short, currency: currency)),
            style: onest(12.5, color: Mid.ink2, tabular: true),
          ),
          const SizedBox(width: 6),
          choice(
            t.rowsStillOwedDue(sayDate(t, due)),
            true,
            const ValueKey('owed-keep'),
          ),
          choice(t.rowsPaidInFull, false, const ValueKey('owed-full')),
        ],
      ),
    );
  }
}

/// A transfer with an account in another currency: what arrived there (or
/// left it) in that currency, and the rate the two amounts make.
class _ExchangeLine extends StatelessWidget {
  const _ExchangeLine({
    required this.other,
    required this.inflow,
    required this.here,
    required this.hereAmount,
    required this.controller,
    required this.focusNode,
    required this.locked,
    required this.wanted,
    required this.onSubmitted,
  });
  final AccountInfo other;
  final bool inflow;
  final Currency here;
  final int? hereAmount;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool locked;
  final bool wanted;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final there = parseAmount(
      controller.text.trim().replaceFirst(RegExp(r'^\+'), ''),
      other.currency,
    );
    final rate = exchangeRate(hereAmount, here, there, other.currency);
    return Container(
      key: const ValueKey('exchange-line'),
      width: Cols.category + Cols.gap + Cols.amount + Cols.gap + Cols.balance,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.only(left: 10),
      child: Row(
        children: [
          Icon(Icons.currency_exchange_rounded, size: 14, color: Mid.ink3),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              inflow
                  ? t.rowsLeftOther(other.name)
                  : t.rowsArrivesOther(other.name),
              style: onest(12.5, color: Mid.ink2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 130,
            child: locked
                ? Text(
                    there == null
                        ? ''
                        : formatMoney(there, currency: other.currency),
                    style: onest(12.5, color: Mid.ink3, tabular: true),
                  )
                : _Field(
                    key: const ValueKey('exchange-amount'),
                    controller: controller,
                    focusNode: focusNode,
                    hint: zeroHint(other.currency),
                    tabular: true,
                    small: true,
                    align: TextAlign.right,
                    wanted: wanted,
                    onSubmitted: (_) => onSubmitted(),
                  ),
          ),
          if (rate != null) ...[
            const SizedBox(width: 10),
            Text(
              t.rowsRatePer(
                formatMoney(rate.rate, currency: rate.quote),
                formatRounded(rate.base.scale, currency: rate.base),
              ),
              style: onest(12, color: Mid.ink3, tabular: true),
            ),
          ],
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
        Icon(Icons.swap_horiz_rounded, size: 14, color: Mid.ink3),
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
            message: context.t.rowsTurnItAround,
            child: InkWell(
              key: const ValueKey('transfer-swap'),
              onTap: onSwap,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  context.t.rowsSwap,
                  style: onest(12.5, color: Mid.blue),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Under a new category with money in: it will be a refund to it.
class _RefundLine extends StatelessWidget {
  const _RefundLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('refund-line'),
    width: Cols.category + Cols.gap + Cols.amount + Cols.gap + Cols.balance,
    height: 30,
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.only(left: 10),
    alignment: Alignment.centerLeft,
    child: Tooltip(
      message: text,
      child: Text(
        text,
        style: onest(12.5, color: Mid.note),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
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
    borderSide: BorderSide(color: Mid.blue, width: 1.5),
  ),
);

class _Field extends StatelessWidget {
  const _Field({
    super.key,
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
    this.calendarBeside = false,
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

  /// The calendar opens to the right of the field instead of under it:
  /// in a form, under it is where the next rows are.
  final bool calendarBeside;

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
          targetAnchor: widget.calendarBeside
              ? Alignment.topRight
              : Alignment.bottomLeft,
          offset: widget.calendarBeside
              ? const Offset(10, 0)
              : const Offset(0, 6),
          child: Align(
            alignment: Alignment.topLeft,
            // Clicks in the calendar count as inside the field, so it keeps focus.
            child: TextFieldTapRegion(
              // For the mouse: the keys type the date. Tab mustn't step
              // into it, or the field loses focus and the calendar goes
              // with focus inside it (#163).
              child: ExcludeFocus(
                child: ListenableBuilder(
                  listenable: widget.controller,
                  builder: (context, _) => _Calendar(
                    selected: parseRowDate(
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
        ),
        child: CompositedTransformTarget(
          link: _link,
          child: _Field(
            controller: widget.controller,
            focusNode: widget.focusNode,
            hint: context.t.rowsHintDate,
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
/// underlined. Days after today are plain: the line under the month says
/// picking one schedules the transaction.
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
    final t = context.t;

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
          ? Mid.onAccent
          : off
          ? Mid.ink3.withValues(alpha: 0.5)
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
                  arrow(Icons.chevron_left_rounded, -1, t.rowsPreviousMonth),
                  Expanded(
                    child: Text(
                      t.calendarMonth(
                        monthName(t, _month.month),
                        '${_month.year}',
                        _month.month,
                      ),
                      textAlign: TextAlign.center,
                      style: onest(13.5, weight: 600),
                    ),
                  ),
                  arrow(Icons.chevron_right_rounded, 1, t.rowsNextMonth),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final n in t.rowsWeekdayInitials.split('|'))
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
              // Says what a later day does, only when it matters.
              if (widget.allowFuture && hint != null && _future(hint))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    t.rowsAfterTodayScheduled,
                    style: onest(12, color: Mid.note),
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
    this.pinned,
    this.pinnedIcon,
  });

  /// How an option reads in the list, when not as it fills the field.
  final String Function(T)? optionText;

  /// Options kept above the list, over a line, rather than scrolled to
  /// ("Split"). They come last in [options], so the highlight starts on
  /// the first match and Up from it reaches them.
  final bool Function(T)? pinned;

  /// Drawn before a pinned option's words.
  final IconData? Function(T)? pinnedIcon;

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
      final all = opts.toList();
      final list = [
        for (final o in all)
          if (!(pinned?.call(o) ?? false)) o,
      ];
      final above = [
        for (final o in all)
          if (pinned?.call(o) ?? false) o,
      ];
      Widget item(T o, int i, {IconData? icon}) => InkWell(
        onTap: () => onPick(o),
        child: Container(
          color: i == highlighted ? Mid.blueWash : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: Mid.blue),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  (optionText ?? label)(o),
                  style: onest(
                    13,
                    color: i == highlighted ? Mid.ink : Mid.ink2,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (above.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (j, o) in above.indexed)
                            item(o, list.length + j, icon: pinnedIcon?.call(o)),
                        ],
                      ),
                    ),
                    if (list.isNotEmpty) Divider(height: 1, color: Mid.rule),
                  ],
                  if (list.isNotEmpty)
                    Flexible(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (context, i) => item(list[i], i),
                      ),
                    ),
                ],
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
    super.key,
    required this.label,
    required this.ready,
    required this.onTap,
    this.keyName = 'Enter',
    this.quiet = false,
  });
  final String label;
  final bool ready;
  final VoidCallback onTap;

  /// The key that does the same, named in the tooltip.
  final String keyName;

  /// Cancel beside Save: no fill until hovered, so Save stays the one
  /// button that stands out.
  final bool quiet;

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ready = widget.ready;
    return Tooltip(
      message: context.t.rowsOrPressKey(widget.keyName),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 30,
            padding: EdgeInsets.symmetric(horizontal: widget.quiet ? 10 : 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ready
                  ? (_hover ? Color.lerp(Mid.fill, Mid.ink, 0.15)! : Mid.fill)
                  : widget.quiet
                  ? (_hover ? Mid.chip : Colors.transparent)
                  : (_hover ? Mid.raised : Mid.chip),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.label,
              style: onest(
                13,
                weight: 500,
                color: ready ? Mid.onFill : Mid.ink2,
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
    style: MenuStyle(
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
              ? Icon(Icons.check_rounded, size: 14, color: Mid.blue)
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
                      value?.name ?? context.t.rowsHintAccount,
                      style: onest(
                        13.5,
                        color: value == null ? Mid.ink3 : Mid.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.expand_more_rounded, size: 16, color: Mid.ink3),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// One line of the split card: a category and its share of the total.
class _SplitLine {
  _SplitLine({String category = '', String amount = ''})
    : category = TextEditingController(text: category),
      amount = TextEditingController(text: amount);

  final TextEditingController category;
  final TextEditingController amount;

  /// The category picked from the list, or the one the line was opened
  /// with; kept while the line's name still says it.
  int? accountId;

  /// "+ New category" was picked on this line for this name: the category
  /// is made when the row is added.
  String? newName;
  final categoryFocus = FocusNode(debugLabel: 'split-category');
  final amountFocus = FocusNode(debugLabel: 'split-amount');

  void dispose() {
    category.dispose();
    amount.dispose();
    categoryFocus.dispose();
    amountFocus.dispose();
  }
}
