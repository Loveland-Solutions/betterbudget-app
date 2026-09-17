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
  });
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

  /// Set by the row: whether anything has been typed or changed.
  bool Function() isDirty = () => false;

  void focus() => payeeFocus.requestFocus();
}

/// What an existing transaction starts as when opened for editing.
class EditInitial {
  EditInitial.fromRow(RegisterRow r, {this.focus = EditField.payee})
    : date = r.date,
      payee = r.kind == RowKind.simple ? r.payee : (r.txnPayee ?? ''),
      memo = r.memo,
      category = switch (r.kind) {
        RowKind.transfer => '→ ${r.payee}',
        _ => r.categoryLabel,
      },
      amount = r.amount,
      lockCategory = r.kind == RowKind.split || r.kind == RowKind.opening,
      lockAmount = r.kind == RowKind.split,
      payeeOptional = r.kind != RowKind.simple;

  final DateTime date;
  final String payee;
  final String memo;
  final String category;
  final int amount;
  final bool lockCategory;
  final bool lockAmount;
  final bool payeeOptional;
  final EditField focus;
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
  });

  final EntryRowController controller;
  final List<AccountInfo> categories;
  final List<AccountInfo> transferTargets;
  final DateTime today;
  final EditInitial? initial;
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
  final _amountFocus = FocusNode(debugLabel: 'entry-amount');
  String? _error;
  bool _busy = false;
  bool _active = false;

  FocusNode get _payeeFocus => widget.controller.payeeFocus;
  List<FocusNode> get _focuses => [
    _dateFocus,
    _payeeFocus,
    _memoFocus,
    _categoryFocus,
    _amountFocus,
  ];

  List<({String label, AccountInfo account})> get _counterOptions => [
    for (final c in widget.categories) (label: c.name, account: c),
    for (final a in widget.transferTargets) (label: '→ ${a.name}', account: a),
  ];

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
          EditField.date => (_dateFocus, _date),
          EditField.memo => (_memoFocus, _memo),
          EditField.category when !_initial.lockCategory => (
            _categoryFocus,
            _category,
          ),
          EditField.amount when !_initial.lockAmount => (_amountFocus, _amount),
          _ => (_payeeFocus, _payee),
        };
        node.requestFocus();
        ctrl.selection = TextSelection(
          baseOffset: 0,
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

  /// Required fields still empty, in reading order. Order of entry is the
  /// user's choice; this only decides where Enter sends them next.
  List<({String name, FocusNode focus})> get _missing => [
    if (_date.text.trim().isEmpty) (name: 'date', focus: _dateFocus),
    if (_payee.text.trim().isEmpty &&
        !_isTransfer &&
        !(_initial?.payeeOptional ?? false))
      (name: 'payee', focus: _payeeFocus),
    if (_category.text.trim().isEmpty && !(_initial?.lockCategory ?? false))
      (name: 'category', focus: _categoryFocus),
    if (_amount.text.trim().isEmpty && !(_initial?.lockAmount ?? false))
      (name: 'amount', focus: _amountFocus),
  ];

  @override
  void dispose() {
    for (final c in _all) {
      c.removeListener(_edited);
      c.dispose();
    }
    for (final f in [_dateFocus, _memoFocus, _categoryFocus, _amountFocus]) {
      f.dispose();
    }
    _payeeFocus.removeListener(_focusChanged);
    _payeeFocus.removeListener(_prefillCategoryOnLeave);
    super.dispose();
  }

  void _focusChanged() {
    final active = _focuses.any((f) => f.hasFocus);
    if (active != _active) setState(() => _active = active);
  }

  Future<bool> _prefillCategory() async {
    if (_category.text.isNotEmpty || _payee.text.trim().isEmpty) return false;
    final id = await widget.controller.suggestCategory(_payee.text.trim());
    final match = _counterOptions.where((o) => o.account.id == id).firstOrNull;
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
    } else if (!lockCategory && counter == null) {
      (error, fix) = ('No category “${_category.text.trim()}”', _categoryFocus);
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

  Widget _note(int? preview, bool showsMath) {
    final String text;
    final Color color;
    if (_error != null) {
      (text, color) = (_error!, Mid.coral);
    } else if (showsMath) {
      (text, color) = ('= ${formatMoney(preview!)}', Mid.ink2);
    } else if (_hasContent && _missing.isNotEmpty) {
      final m = _missing;
      (text, color) = (
        m.length == 1 ? 'needs ${m.single.name}' : 'needs ${m.length} more',
        Mid.ink3,
      );
    } else if (_editing) {
      (text, color) = ('Esc to cancel', Mid.ink3);
    } else if (_active && !_hasContent) {
      (text, color) = ('+ for money in', Mid.ink3);
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
                  child: FocusTraversalOrder(
                    order: const NumericFocusOrder(1),
                    child: _Field(
                      controller: _date,
                      focusNode: _dateFocus,
                      hint: 'Date',
                      tabular: true,
                      wanted: _wants('date'),
                      onSubmitted: (_) => _submit(),
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
                      if (_editing) ...[
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
                SizedBox(
                  width: Cols.category,
                  child: initial != null && initial.lockCategory
                      ? _locked(
                          initial.category,
                          tip: 'Editing split lines isn’t built yet',
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
                                options: (q) => _counterOptions.where(
                                  (o) => o.label.toLowerCase().contains(
                                    q.toLowerCase(),
                                  ),
                                ),
                                label: (o) => o.label,
                                onSelected: (_) => _amountFocus.requestFocus(),
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
                            formatMoney(initial.amount),
                            tip: 'A split’s total follows its lines',
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(child: _note(preview, showsMath)),
                      if (_hasContent || _active) ...[
                        const SizedBox(width: 10),
                        _AddButton(
                          label: _editing ? 'Save' : 'Add',
                          ready: _missing.isEmpty && _error == null,
                          onTap: _submit,
                        ),
                      ],
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
  });

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
        final exact = opts.any((o) => label(o).toLowerCase() == q);
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
                      label(list[i]),
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
