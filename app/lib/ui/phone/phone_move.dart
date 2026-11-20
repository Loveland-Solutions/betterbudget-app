part of 'phone_app.dart';

// Move money on the phone (#528, owner's pick of sketch A): from a
// category's open row, the computer's Move money box as a page. Which
// way, who it trades with and how much; what would be overspent is said
// before Move, which goes ahead anyway (warn, don't block). One change
// the computers see, with Undo in a snack bar.

/// Opens Move money for [category]; after a move says so with an Undo.
Future<void> _openMove(
  BuildContext context, {
  required PhoneStore store,
  required PhoneCategory category,
}) async {
  final moved = await Navigator.of(context).push(
    MaterialPageRoute<({PhoneActed done, String said})>(
      builder: (_) => _MovePage(store: store, category: category),
    ),
  );
  if (moved == null || !context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        persist: false,
        duration: phoneSnackTime,

        key: const ValueKey('move-done'),
        backgroundColor: Mid.raised,
        content: Text(moved.said, style: onest(15, color: Mid.ink)),
        action: SnackBarAction(
          label: context.t.ledgerUndo,
          textColor: Mid.blue,
          onPressed: () => unawaited(store.replay(moved.done.undo)),
        ),
      ),
    );
}

/// What Move money can trade with: [category] null is Not assigned.
typedef _Trade = ({PhoneCategory? category, int left});

class _MovePage extends StatefulWidget {
  const _MovePage({required this.store, required this.category});
  final PhoneStore store;
  final PhoneCategory category;

  @override
  State<_MovePage> createState() => _MovePageState();
}

class _MovePageState extends State<_MovePage> {
  late final TextEditingController _amount;
  late bool _inward;
  _Trade? _picked;
  bool _noPick = false, _noAmount = false, _busy = false;

  PhoneStore get _store => widget.store;
  PhoneCategory get _here => widget.category;
  Currency get _currency => _here.currency;
  int get _left => leftNow(_here, _store.waiting);

  @override
  void initState() {
    super.initState();
    _inward = _left <= 0;
    // Coming in: what it's short, the one figure the screen already says.
    _amount = TextEditingController(
      text: _left < 0 ? typedAmount(-_left, _currency) : '',
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int? get _notAssigned => _store.snapshot.sums
      .where((s) => s.pool.currency == _currency)
      .map((s) => s.pool.notAssigned)
      .firstOrNull;

  /// Not assigned, then the other categories in this currency; coming in,
  /// the ones with most to give first, and Not assigned only while it has
  /// money.
  List<_Trade> get _offered {
    final others = [
      for (final c in _store.categories)
        if (c.id != _here.id &&
            !c.transfer &&
            !c.madeHere &&
            c.currency == _currency &&
            int.tryParse(c.id) != null)
          (category: c, left: leftNow(c, _store.waiting)),
    ];
    if (_inward) others.sort((a, b) => b.left.compareTo(a.left));
    final none = _notAssigned;
    return [
      if (none != null && (!_inward || none > 0)) (category: null, left: none),
      ...others,
    ];
  }

  String _money(int v) => formatMoney(v, currency: _currency);

  int? get _typed {
    final typed = _amount.text.trim();
    if (typed.isEmpty) return null;
    final a = parseAmount(typed, _currency);
    return a == null || a <= 0 ? null : a;
  }

  /// The plain words when more goes than the side it comes from has.
  String? _warning(Words t) {
    final amount = _typed;
    final picked = _picked;
    if (amount == null || picked == null) return null;
    final from = _inward ? picked.category : _here;
    final has = _inward ? picked.left : _left;
    if (from == null) {
      // From Not assigned into a category that is overspent: what covers
      // the overspending takes nothing, since that already came off.
      final covers = _left < 0 ? -_left : 0;
      final takes = amount > covers ? amount - covers : 0;
      if (takes <= has) return null;
      return t.planMoveWarnNotAssigned(_money(has), _money(takes - has));
    }
    if (amount <= has) return null;
    final short = _money(amount - has);
    return has >= 0
        ? t.planMoveWarn(from.name, _money(has), short)
        : t.planMoveWarnOver(from.name, _money(-has), short);
  }

  Future<void> _move() async {
    final t = context.t;
    final amount = _typed, picked = _picked;
    if (picked == null || amount == null) {
      setState(() {
        _noPick = picked == null;
        _noAmount = amount == null;
      });
      return;
    }
    final from = _inward ? picked.category : _here;
    final to = _inward ? _here : picked.category;
    setState(() => _busy = true);
    final PhoneActed done;
    try {
      done = await _store.actRow(
        PhoneMove(
          from == null ? null : int.parse(from.id),
          to == null ? null : int.parse(to.id),
          amount,
        ),
      );
    } catch (e) {
      debugPrint('Moving money on the phone failed: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            persist: false,
            duration: phoneSnackTime,

            key: const ValueKey('move-refused'),
            backgroundColor: Mid.raised,
            content: Text(
              t.ledgerCouldntSave,
              style: onest(15, color: Mid.ink),
            ),
          ),
        );
      return;
    }
    if (!mounted) return;
    final shown = _money(amount);
    final said = switch ((from, to)) {
      (final f?, final c?) => t.planMoved(shown, f.name, c.name),
      (null, final c?) => t.planMovedMore(shown, c.name),
      (final f?, null) => t.planMovedBack(shown, f.name),
      _ => '',
    };
    Navigator.of(context).pop((done: done, said: said));
  }

  Widget _has(Words t, _Trade c) {
    if (c.category == null) {
      return c.left > 0
          ? Text(_money(c.left), style: onest(15, tabular: true))
          : const SizedBox.shrink();
    }
    return c.left < 0
        ? Text(
            t.planMoveOverspent(_money(-c.left)),
            style: onest(15, color: Mid.coral, tabular: true),
          )
        : Text(
            t.planMoveLeft(_money(c.left)),
            style: onest(
              15,
              color: c.left == 0 ? Mid.ink3 : Mid.ink,
              tabular: true,
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final offered = _offered;
    final warning = _warning(t);
    final picked = _picked;
    return Scaffold(
      backgroundColor: Mid.ground,
      appBar: AppBar(
        backgroundColor: Mid.ground,
        foregroundColor: Mid.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(t.planMoveMoney, style: onest(20, weight: 600)),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_inward ? t.planMoveTo : t.planMoveFrom}  ${_here.name}',
                      key: const ValueKey('move-here'),
                      style: onest(17, weight: 600),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('move-swap'),
                    onPressed: () => setState(() {
                      _inward = !_inward;
                      final p = _picked;
                      if (p != null && !_offered.contains(p)) _picked = null;
                    }),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      foregroundColor: Mid.blue,
                      textStyle: onest(16),
                    ),
                    child: Text(t.planMoveSwap),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                _inward ? t.planMoveFrom : t.planMoveTo,
                style: onest(14, color: _noPick ? Mid.coral : Mid.ink2),
              ),
            ),
            Expanded(
              child: offered.isEmpty
                  ? Padding(
                      key: const ValueKey('move-nothing'),
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        t.planMoveNothingFrom,
                        style: onest(15, color: Mid.ink2),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final c in offered)
                          InkWell(
                            key: ValueKey(
                              'move-choice-${c.category?.id ?? 'none'}',
                            ),
                            onTap: () => setState(() {
                              _picked = c;
                              _noPick = false;
                            }),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              color:
                                  identical(c, picked) ||
                                      (picked != null &&
                                          picked.category?.id == c.category?.id)
                                  ? Mid.blueWash
                                  : null,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      c.category?.name ?? t.planKeyNotAssigned,
                                      style: onest(16),
                                    ),
                                  ),
                                  _has(t, c),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                key: const ValueKey('move-amount'),
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: onest(17, weight: 600, tabular: true),
                onChanged: (_) => setState(() => _noAmount = false),
                decoration: InputDecoration(
                  labelText: t.planMoveAmount,
                  prefixText: _currency.prefix,
                  errorText: _noAmount ? t.planMoveEnterAmount : null,
                ),
              ),
            ),
            if (warning != null)
              Padding(
                key: const ValueKey('move-warning'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(warning, style: onest(15, color: Mid.coral)),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      key: const ValueKey('move-cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: Mid.blue,
                        textStyle: onest(17),
                      ),
                      child: Text(t.ledgerCancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      key: const ValueKey('move-go'),
                      onPressed: _busy ? null : _move,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: Mid.fill,
                        foregroundColor: Mid.onFill,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: onest(17, weight: 600),
                      ),
                      child: Text(t.planMoveButton),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
