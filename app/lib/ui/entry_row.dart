import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/ledger.dart';
import '../domain/money.dart';
import 'register.dart' show Cols;
import 'theme.dart';

class EntryDraft {
  const EntryDraft({
    required this.date,
    required this.payee,
    required this.counter,
    required this.amount,
  });
  final DateTime date;
  final String payee;
  final AccountInfo counter;

  /// Signed from the register account's perspective.
  final int amount;
}

/// Lets the screen focus the entry row (⌘N) and supply data it needs.
class EntryRowController {
  EntryRowController({required this.onSubmit, required this.suggestCategory});

  /// Returns an error message, or null when the transaction was written.
  final Future<String?> Function(EntryDraft draft) onSubmit;
  final Future<int?> Function(String payee) suggestCategory;
  List<String> payeeNames = const [];
  final payeeFocus = FocusNode(debugLabel: 'entry-payee');

  void focus() => payeeFocus.requestFocus();
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

class EntryRow extends StatefulWidget {
  const EntryRow({
    super.key,
    required this.controller,
    required this.categories,
    required this.transferTargets,
    required this.today,
  });

  final EntryRowController controller;
  final List<AccountInfo> categories;
  final List<AccountInfo> transferTargets;
  final DateTime today;

  @override
  State<EntryRow> createState() => _EntryRowState();
}

class _EntryRowState extends State<EntryRow> {
  late final _date = TextEditingController(text: fullDate(widget.today));
  final _payee = TextEditingController();
  final _category = TextEditingController();
  final _amount = TextEditingController();
  final _dateFocus = FocusNode(debugLabel: 'entry-date');
  final _categoryFocus = FocusNode(debugLabel: 'entry-category');
  final _amountFocus = FocusNode(debugLabel: 'entry-amount');
  String? _error;
  bool _busy = false;
  bool _active = false;

  FocusNode get _payeeFocus => widget.controller.payeeFocus;

  List<({String label, AccountInfo account})> get _counterOptions => [
    for (final c in widget.categories) (label: c.name, account: c),
    for (final a in widget.transferTargets) (label: '→ ${a.name}', account: a),
  ];

  @override
  void initState() {
    super.initState();
    for (final f in [_dateFocus, _payeeFocus, _categoryFocus, _amountFocus]) {
      f.addListener(_focusChanged);
    }
    _payeeFocus.addListener(_prefillCategoryOnLeave);
    for (final c in [_date, _payee, _category, _amount]) {
      c.addListener(_edited);
    }
  }

  void _edited() {
    if (!mounted) return;
    setState(() => _error = null);
  }

  bool _wants(String field) =>
      _hasContent && _missing.any((m) => m.name == field);

  bool get _hasContent =>
      _payee.text.trim().isNotEmpty ||
      _category.text.trim().isNotEmpty ||
      _amount.text.trim().isNotEmpty;

  /// Required fields still empty, in reading order. Order of entry is the
  /// user's choice; this only decides where Enter sends them next.
  List<({String name, FocusNode focus})> get _missing => [
    if (_date.text.trim().isEmpty) (name: 'date', focus: _dateFocus),
    if (_payee.text.trim().isEmpty) (name: 'payee', focus: _payeeFocus),
    if (_category.text.trim().isEmpty)
      (name: 'category', focus: _categoryFocus),
    if (_amount.text.trim().isEmpty) (name: 'amount', focus: _amountFocus),
  ];

  @override
  void dispose() {
    for (final c in [_date, _payee, _category, _amount]) {
      c.removeListener(_edited);
      c.dispose();
    }
    for (final f in [_dateFocus, _categoryFocus, _amountFocus]) {
      f.dispose();
    }
    _payeeFocus.removeListener(_focusChanged);
    _payeeFocus.removeListener(_prefillCategoryOnLeave);
    super.dispose();
  }

  void _focusChanged() {
    final active = [
      _dateFocus,
      _payeeFocus,
      _categoryFocus,
      _amountFocus,
    ].any((f) => f.hasFocus);
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
      _error = null;
    });
    if (keepFocus) _payeeFocus.requestFocus();
  }

  /// Enter in any field, or the Add button, lands here.
  Future<void> _submit() async {
    if (_busy) return;
    if (_category.text.trim().isEmpty) await _prefillCategory();
    if (!mounted) return;

    final missing = _missing;
    if (missing.isNotEmpty) {
      missing.first.focus.requestFocus();
      return;
    }

    final date = parseEntryDate(_date.text, widget.today);
    final payee = _payee.text.trim();
    final counter = _counterOptions
        .where(
          (o) => o.label.toLowerCase() == _category.text.trim().toLowerCase(),
        )
        .firstOrNull;
    final raw = _amount.text.trim();
    final isInflow =
        raw.startsWith('+') || counter?.account.type == AccountType.income;
    final parsed = parseAmount(raw.startsWith('+') ? raw.substring(1) : raw);

    String? error;
    FocusNode? fix;
    if (date == null) {
      (error, fix) = ('Date should look like 2026.09.16', _dateFocus);
    } else if (counter == null) {
      (error, fix) = ('No category “${_category.text.trim()}”', _categoryFocus);
    } else if (parsed == null || parsed == 0) {
      (error, fix) = ('Can’t read “$raw” as an amount', _amountFocus);
    }
    if (error != null) {
      fix!.requestFocus();
      setState(() => _error = error);
      return;
    }

    final magnitude = parsed!.abs();
    setState(() => _busy = true);
    final result = await widget.controller.onSubmit(
      EntryDraft(
        date: date!,
        payee: payee,
        counter: counter!.account,
        amount: isInflow ? magnitude : -magnitude,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result != null) {
      setState(() => _error = result);
    } else {
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

  @override
  Widget build(BuildContext context) {
    final preview = parseAmount(
      _amount.text.trim().replaceFirst(RegExp(r'^\+'), ''),
    );
    final showsMath =
        preview != null && RegExp(r'\d[+\-*/×]').hasMatch(_amount.text);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          _reset(keepFocus: false);
          FocusScope.of(context).unfocus();
        },
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 52,
          padding: Cols.inset,
          decoration: BoxDecoration(
            color: _active
                ? Mid.raised.withValues(alpha: 0.55)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _active ? Mid.rule : Colors.transparent),
          ),
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Row(
              children: [
                SizedBox(
                  width: Cols.status,
                  child: Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: _active ? Mid.blue : Mid.ink3,
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
                      wanted: _wants('date'),
                      hint: 'Date',
                      tabular: true,
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ),
                const SizedBox(width: Cols.gap),
                Expanded(
                  child: FocusTraversalOrder(
                    order: const NumericFocusOrder(2),
                    child: _Autocomplete<String>(
                      controller: _payee,
                      focusNode: _payeeFocus,
                      wanted: _wants('payee'),
                      hint: 'New transaction — payee',
                      options: (q) => q.isEmpty
                          ? const []
                          : widget.controller.payeeNames
                                .where(
                                  (p) =>
                                      p.toLowerCase().contains(q.toLowerCase()),
                                )
                                .take(8),
                      label: (p) => p,
                      onSelected: (p) async {
                        final filled = await _prefillCategory();
                        (filled ? _amountFocus : _categoryFocus).requestFocus();
                      },
                      onSubmit: _submit,
                    ),
                  ),
                ),
                const SizedBox(width: Cols.gap),
                SizedBox(
                  width: Cols.category,
                  child: FocusTraversalOrder(
                    order: const NumericFocusOrder(3),
                    child: _Autocomplete<({String label, AccountInfo account})>(
                      controller: _category,
                      focusNode: _categoryFocus,
                      wanted: _wants('category'),
                      hint: 'Category',
                      options: (q) => _counterOptions.where(
                        (o) => o.label.toLowerCase().contains(q.toLowerCase()),
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
                  child: FocusTraversalOrder(
                    order: const NumericFocusOrder(4),
                    child: _Field(
                      controller: _amount,
                      focusNode: _amountFocus,
                      wanted: _wants('amount'),
                      hint: '0.00',
                      tabular: true,
                      align: TextAlign.right,
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ),
                const SizedBox(width: Cols.gap),
                SizedBox(
                  width: Cols.balance,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(child: _note(preview, showsMath)),
                      if (_hasContent || _active) ...[
                        const SizedBox(width: 10),
                        _AddButton(
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
InputDecoration _decoration(String hint, {bool wanted = false}) =>
    InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: onest(13.5, color: Mid.ink3),
      filled: true,
      fillColor: Mid.ground.withValues(alpha: 0.6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
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
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool tabular;
  final TextAlign align;
  final ValueChanged<String>? onSubmitted;
  final bool wanted;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    focusNode: focusNode,
    style: onest(13.5, tabular: tabular),
    textAlign: align,
    decoration: _decoration(hint, wanted: wanted),
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
  const _AddButton({required this.ready, required this.onTap});
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
              'Add',
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
