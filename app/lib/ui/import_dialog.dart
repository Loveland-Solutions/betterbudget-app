part of 'ledger_screen.dart';

// Importing a bank file (ADR 0002, ADR 0004 "Import"). The file's own
// columns are shown with a choice over each (option A, owner 2026-09-30);
// below them, the rows as they'll come in. A file shaped like the last one
// into this account skips the columns and opens on the preview.

/// What the import window hands back: the columns as set, and what each row
/// will do.
typedef ImportPick = ({
  ImportMapping mapping,
  List<ImportPlanRow> plan,
  bool proven,
  ({DateTime date, int amount})? moveOpening,
});

class _ImportDialog extends StatefulWidget {
  const _ImportDialog({
    required this.accountName,
    required this.fileName,
    required this.sheet,
    required this.mapping,
    required this.fromSaved,
    required this.accountId,
    required this.currency,
    required this.plan,
    required this.cleared,
    required this.owed,
  });

  final String accountName;

  /// The account's: how many decimals the file's amounts are read with.
  final Currency currency;
  final String fileName;
  final Sheet sheet;
  final ImportMapping mapping;

  /// The mapping is the one saved for this account and the file fits it.
  final bool fromSaved;
  final int accountId;
  final Future<ImportPlan> Function(List<ImportRow>, List<String>) plan;

  /// The account's cleared balance now, as stored.
  final int cleared;
  final bool owed;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  late ImportMapping _mapping = widget.mapping;
  late bool _showColumns = !widget.fromSaved;
  ReadResult? _read;
  ImportPlan? _plan;
  int _asked = 0;

  /// Rows dated before the opening balance: move it before them (the
  /// default, owner 2026-09-30) or leave it and count them twice.
  bool _moveOpening = true;

  /// New rows the opening balance already holds, and where it would move
  /// so today's balance stays: the day before them, less what they add.
  ({List<ImportPlanRow> rows, DateTime date, int amount})? get _beforeOpening {
    final plan = _plan;
    final opening = plan?.opening;
    if (plan == null || opening == null) return null;
    final rows = [
      for (final p in plan.rows)
        if (p.fate == ImportFate.add &&
            dateOnly(p.row.date).isBefore(opening.date))
          p,
    ];
    if (rows.isEmpty) return null;
    final first = rows
        .map((p) => dateOnly(p.row.date))
        .reduce((a, b) => a.isBefore(b) ? a : b);
    return (
      rows: rows,
      date: first.subtract(const Duration(days: 1)),
      amount: opening.amount - rows.fold(0, (s, p) => s + p.row.amount),
    );
  }

  ({DateTime date, int amount})? get _openingMove {
    final b = _beforeOpening;
    final opening = _plan?.opening;
    if (b == null || !_moveOpening || opening == null || opening.locked) {
      return null;
    }
    return (date: b.date, amount: b.amount);
  }

  @override
  void initState() {
    super.initState();
    _reread();
  }

  Future<void> _reread() async {
    final read = _mapping.complete
        ? readRows(widget.sheet, _mapping, decimals: widget.currency.decimals)
        : null;
    final ask = ++_asked;
    setState(() {
      _read = read;
      _plan = null;
    });
    if (read == null) return;
    final plan = await widget.plan(
      read.rows,
      importKeys(widget.accountId, read.rows),
    );
    if (!mounted || ask != _asked) return;
    setState(() => _plan = plan);
  }

  void _set(ImportMapping m) {
    _mapping = m;
    _reread();
  }

  int _count(ImportFate f) => _plan?.rows.where((p) => p.fate == f).length ?? 0;

  int get _toWrite => _count(ImportFate.add) + _count(ImportFate.match);

  void _import() {
    final plan = _plan;
    if (plan == null || _toWrite == 0) return;
    final check = _read?.check;
    Navigator.of(context).pop<ImportPick>((
      mapping: _mapping,
      plan: plan.rows,
      proven: check == null || check.ok,
      moveOpening: _openingMove,
    ));
  }

  /// A row's tag, clicked: a match becomes its own row, then left out, then
  /// a match again; a new row is left out and back.
  void _cycle(int i) {
    final plan = _plan;
    if (plan == null) return;
    final p = plan.rows[i];
    final next = switch (p.fate) {
      ImportFate.match => ImportFate.add,
      ImportFate.add when p.match != null => ImportFate.leftOut,
      ImportFate.add => ImportFate.leftOut,
      ImportFate.leftOut when p.match != null => ImportFate.match,
      ImportFate.leftOut => ImportFate.add,
      ImportFate.already => ImportFate.already,
    };
    if (next == p.fate) return;
    setState(
      () => _plan = plan.withRows([...plan.rows]..[i] = p.withFate(next)),
    );
  }

  void _leaveNewOut() {
    final plan = _plan;
    if (plan == null) return;
    setState(
      () => _plan = plan.withRows([
        for (final p in plan.rows)
          p.fate == ImportFate.add ? p.withFate(ImportFate.leftOut) : p,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Mid.panel,
      insetPadding: const EdgeInsets.all(32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Mid.rule),
      ),
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.enter): _import},
        child: Focus(
          autofocus: true,
          child: SizedBox(
            width: (size.width - 64).clamp(600, 1180),
            height: (size.height - 64).clamp(420, 860),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t.importTitle(widget.accountName),
                    style: onest(17, weight: 600, letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 2),
                  Text(widget.fileName, style: onest(12.5, color: Mid.ink3)),
                  const SizedBox(height: 16),
                  if (_showColumns) ...[
                    Text(
                      t.importColumnsHint,
                      style: onest(13, color: Mid.ink2),
                    ),
                    const SizedBox(height: 10),
                    _Columns(
                      sheet: widget.sheet,
                      mapping: _mapping,
                      skipped: {
                        for (final s in _read?.skipped ?? const <SkippedRow>[])
                          s.sourceRow,
                      },
                      onRole: (col, role) => _set(_mapping.withRole(col, role)),
                    ),
                    ..._choices(t),
                  ] else
                    Row(
                      children: [
                        Icon(Icons.check_rounded, size: 16, color: Mid.green),
                        const SizedBox(width: 6),
                        Text(
                          t.importSavedColumns,
                          style: onest(13, color: Mid.ink2),
                        ),
                        const SizedBox(width: 12),
                        BarButton(
                          key: const ValueKey('import-change-columns'),
                          label: t.importChangeColumns,
                          onTap: () => setState(() => _showColumns = true),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  Container(height: 1, color: Mid.rule),
                  const SizedBox(height: 12),
                  Expanded(child: _preview(t)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Spacer(),
                      BarButton(
                        key: const ValueKey('import-cancel'),
                        label: t.importCancel,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      if (_plan != null && _toWrite == 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            t.importNothingNew,
                            style: onest(13, color: Mid.ink2),
                          ),
                        )
                      else
                        Opacity(
                          opacity: _plan == null ? 0.5 : 1,
                          child: _PrimaryButton(
                            key: const ValueKey('import-do'),
                            label: switch ((
                              _count(ImportFate.add),
                              _count(ImportFate.match),
                            )) {
                              (final n, 0) => t.importDo(n),
                              (0, final c) => t.importDoOnlyClear(c),
                              (final n, final c) => t.importDoClear(n, c),
                            },
                            icon: Icons.download_rounded,
                            tooltip: 'Enter',
                            onTap: _import,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The date order, when a text date reads both ways, and the sign, when
  /// one column holds the amount.
  List<Widget> _choices(Words t) {
    final out = <Widget>[];
    final dateCol = _mapping.columnOf(ColumnRole.date);
    if (dateCol != null) {
      final texts = [
        for (
          var r = (_mapping.headerRow ?? -1) + 1;
          r < widget.sheet.rows.length;
          r++
        )
          if (widget.sheet.cell(r, dateCol) case final String s)
            if (parseDateText(s, DateOrder.dmy) != null ||
                parseDateText(s, DateOrder.mdy) != null)
              s,
      ];
      final fits = fittingOrders(texts);
      final ambiguous = texts
          .where(
            (s) =>
                parseDateText(s, DateOrder.dmy) !=
                parseDateText(s, DateOrder.mdy),
          )
          .firstOrNull;
      if (fits.contains(DateOrder.dmy) &&
          fits.contains(DateOrder.mdy) &&
          ambiguous != null) {
        out.add(
          _choiceRow(t.importDateOrder, [
            (
              t.importDayFirst(
                sayFullDate(t, parseDateText(ambiguous, DateOrder.dmy)!),
              ),
              _mapping.dateOrder == DateOrder.dmy,
              () => _set(_mapping.copyWith(dateOrder: DateOrder.dmy)),
              'import-dmy',
            ),
            (
              t.importMonthFirst(
                sayFullDate(t, parseDateText(ambiguous, DateOrder.mdy)!),
              ),
              _mapping.dateOrder == DateOrder.mdy,
              () => _set(_mapping.copyWith(dateOrder: DateOrder.mdy)),
              'import-mdy',
            ),
          ]),
        );
      }
    }
    if (_mapping.columnOf(ColumnRole.amount) != null) {
      out.add(
        _choiceRow(t.importSignLabel, [
          (
            t.importMinusOut,
            !_mapping.spendingPositive,
            () => _set(_mapping.copyWith(spendingPositive: false)),
            'import-minus-out',
          ),
          (
            t.importPlusOut,
            _mapping.spendingPositive,
            () => _set(_mapping.copyWith(spendingPositive: true)),
            'import-plus-out',
          ),
        ]),
      );
    }
    if (!_mapping.complete) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            t.importNeedDateAmount,
            style: onest(13.5, weight: 500, color: Mid.coral),
          ),
        ),
      );
    }
    return out;
  }

  Widget _choiceRow(
    String label,
    List<(String, bool, VoidCallback, String)> choices,
  ) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (label.isNotEmpty) Text(label, style: onest(13, color: Mid.ink2)),
        for (final (text, on, tap, key) in choices)
          Hoverable(
            key: ValueKey(key),
            onTap: tap,
            builder: (hover) => Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: on
                    ? Mid.blueWash
                    : (hover ? Mid.raised : Colors.transparent),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: on ? Mid.blue : Mid.ink2.withValues(alpha: 0.3),
                ),
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  text,
                  style: onest(12.5, color: on ? Mid.ink : Mid.ink2),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  int _shown(int v) => widget.owed ? -v : v;
  String _money(int v) => moneyIn(context, v);

  Widget _preview(Words t) {
    final read = _read;
    final plan = _plan;
    if (read == null) return const SizedBox.shrink();
    if (plan == null) {
      return const Center(
        child: SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final added = _count(ImportFate.add);
    final matched = _count(ImportFate.match);
    final already = _count(ImportFate.already);
    final leftOut = _count(ImportFate.leftOut);
    final noDate = read.skipped
        .where((s) => s.reason == SkipReason.noDate)
        .length;
    final noAmount = [
      for (final s in read.skipped)
        if (s.reason == SkipReason.noAmount) s.sourceRow + 1,
    ];
    final summary = [
      t.importCountNew(added),
      if (matched > 0) t.importCountMatch(matched),
      if (already > 0) t.importCountAlready(already),
      if (leftOut > 0) t.importCountLeftOut(leftOut),
    ].join(' · ');

    final notes = <Widget>[];
    final before = _beforeOpening;
    final opening = plan.opening;
    if (before != null && opening != null) {
      notes.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _note(
              Icons.warning_amber_rounded,
              Mid.coral,
              opening.locked
                  ? t.importBeforeOpeningLocked(
                      before.rows.length,
                      _money(_shown(opening.amount)),
                      sayFullDate(t, opening.date),
                    )
                  : t.importBeforeOpening(
                      before.rows.length,
                      _money(_shown(opening.amount)),
                      sayFullDate(t, opening.date),
                    ),
              big: true,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 18),
              child: opening.locked
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: BarButton(
                        key: const ValueKey('import-leave-before-out'),
                        label: t.importLeaveBeforeOut,
                        onTap: () => setState(
                          () => _plan = plan.withRows([
                            for (final p in plan.rows)
                              before.rows.contains(p)
                                  ? p.withFate(ImportFate.leftOut)
                                  : p,
                          ]),
                        ),
                      ),
                    )
                  : _choiceRow('', [
                      (
                        t.importMoveOpening(
                          sayFullDate(t, before.date),
                          _money(_shown(before.amount)),
                        ),
                        _moveOpening,
                        () => setState(() => _moveOpening = true),
                        'import-move-opening',
                      ),
                      (
                        t.importKeepOpening,
                        !_moveOpening,
                        () => setState(() => _moveOpening = false),
                        'import-keep-opening',
                      ),
                    ]),
            ),
          ],
        ),
      );
    }
    // Amounts come in as they are, so a file in the other currency would be
    // a thousand times off: said big, with a real row.
    final here = CurrencyScope.of(context);
    final named = fileCurrency(widget.sheet);
    final sample = plan.rows.where((p) => p.fate != ImportFate.already);
    if (named != null && named != here && sample.isNotEmpty) {
      final v = _shown(sample.first.row.amount).abs();
      final example = formatMoney(v, currency: named);
      final asIs = formatMoney(v, currency: here);
      notes.add(
        _note(
          Icons.warning_amber_rounded,
          Mid.coral,
          t.importFileIn(
            currencyName(t, named),
            widget.accountName,
            currencyName(t, here),
            example,
            asIs,
          ),
          big: true,
        ),
      );
    }
    if (noDate > 0) {
      notes.add(
        Text(t.importCountNoDate(noDate), style: onest(12.5, color: Mid.ink3)),
      );
    }
    if (noAmount.isNotEmpty) {
      notes.add(
        _note(
          Icons.warning_amber_rounded,
          Mid.coral,
          t.importNoAmountRows(noAmount.length, noAmount.join(', ')),
          big: true,
        ),
      );
    }

    final check = read.check;
    if (check != null) {
      if (check.ok) {
        notes.add(
          _note(
            Icons.check_rounded,
            Mid.green,
            t.importBalanceOk(
              _money(_shown(check.opening)),
              _money(_shown(check.closing)),
            ),
          ),
        );
      } else {
        notes.add(
          _note(
            Icons.warning_amber_rounded,
            Mid.coral,
            [
              t.importBalanceOff(
                check.firstMismatchRow! + 1,
                _money(_shown(check.found!)),
                _money(_shown(check.expected!)),
              ),
              if (check.mismatches > 1)
                t.importBalanceOffCount(check.mismatches),
            ].join(' '),
            big: true,
          ),
        );
      }
      // What the account's cleared balance will be, against the bank's.
      var ours = widget.cleared;
      if (_openingMove case final m?) ours += m.amount - opening!.amount;
      for (final p in plan.rows) {
        if (p.fate == ImportFate.add) ours += p.row.amount;
        if (p.fate == ImportFate.match &&
            p.match!.cleared == Cleared.uncleared) {
          ours += p.row.amount;
        }
      }
      final bank = check.closing;
      notes.add(
        ours == bank
            ? _note(
                Icons.check_rounded,
                Mid.green,
                t.importClearedMatches(_money(_shown(ours))),
              )
            : _note(
                Icons.info_outline_rounded,
                Mid.gold,
                t.importClearedDiffers(
                  _money(_shown(ours)),
                  _money(_shown(bank)),
                  _money((ours - bank).abs()),
                ),
              ),
      );
    }

    if (plan.importedBefore > 0 && added > 0) {
      notes.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _note(
              Icons.warning_amber_rounded,
              Mid.coral,
              t.importOverlap(
                sayFullDate(t, plan.firstDay!),
                sayFullDate(t, plan.lastDay!),
                plan.importedBefore,
              ),
              big: true,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 6),
              child: BarButton(
                key: const ValueKey('import-leave-new-out'),
                label: t.importLeaveNewOut,
                onTap: _leaveNewOut,
              ),
            ),
          ],
        ),
      );
    }

    if (plan.unmatched.isNotEmpty) {
      const shown = 4;
      final u = plan.unmatched;
      final items = [
        for (final x in u.take(shown))
          t.importUnmatchedItem(
            x.payee,
            _money(_shown(x.amount)),
            sayDate(t, x.date),
          ),
        if (u.length > shown) t.importUnmatchedMore(u.length - shown),
      ];
      notes.add(
        _note(
          Icons.info_outline_rounded,
          Mid.gold,
          t.importUnmatched(
            u.length,
            sayFullDate(t, plan.firstDay!),
            sayFullDate(t, plan.lastDay!),
            items.join(', '),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          summary,
          key: const ValueKey('import-summary'),
          style: onest(14, weight: 500),
        ),
        for (final n in notes) ...[const SizedBox(height: 6), n],
        const SizedBox(height: 10),
        Text(t.importTagHint, style: onest(12, color: Mid.ink3)),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.builder(
            itemCount: plan.rows.length,
            itemExtent: 30,
            itemBuilder: (context, i) => _PlanLine(
              plan.rows[i],
              owed: widget.owed,
              onTap: () => _cycle(i),
              key: ValueKey('import-row-$i'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _note(IconData icon, Color color, String text, {bool big = false}) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: big ? 18 : 15, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: big
                  ? onest(14.5, weight: 600, color: color)
                  : onest(13, color: color == Mid.gold ? Mid.ink2 : color),
            ),
          ),
        ],
      );
}

/// One row of the preview: date, payee and memo, amount, and what happens.
class _PlanLine extends StatelessWidget {
  const _PlanLine(this.p, {super.key, required this.owed, required this.onTap});
  final ImportPlanRow p;
  final bool owed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final r = p.row;
    final dim = p.fate == ImportFate.already || p.fate == ImportFate.leftOut;
    final ink = dim ? Mid.ink3 : Mid.ink;
    final shown = owed ? -r.amount : r.amount;
    final (tag, tagColor) = switch (p.fate) {
      ImportFate.add => (t.importFateNew, Mid.blue),
      ImportFate.match => (
        [
          p.match!.payee.isEmpty
              ? t.importFateMatchDate(sayDate(t, p.match!.date))
              : t.importFateMatch(p.match!.payee, sayDate(t, p.match!.date)),
          // Another month: it takes the bank's date.
          if (matchedDate(p.match!, r.date) != p.match!.date)
            t.importFateRedated(sayDate(t, dateOnly(r.date))),
        ].join(' · '),
        Mid.green,
      ),
      ImportFate.already => (t.importFateAlready, Mid.ink3),
      ImportFate.leftOut => (t.importFateLeftOut, Mid.ink3),
    };
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            fullDate(r.date),
            style: onest(13, color: dim ? Mid.ink3 : Mid.ink2, tabular: true),
          ),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: r.payee,
                  style: onest(13.5, color: ink),
                ),
                if (r.memo != null)
                  TextSpan(
                    text: '   ${r.memo}',
                    style: onest(12.5, color: Mid.ink3),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 150,
          child: Align(
            alignment: Alignment.centerRight,
            child: Money(
              shown,
              size: 13.5,
              sign: MoneySign.plusForPositive,
              color: dim ? Mid.ink3 : (shown > 0 ? Mid.green : Mid.ink),
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 260,
          child: Align(
            alignment: Alignment.centerLeft,
            child: p.fate == ImportFate.already
                ? Text(
                    tag,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: onest(12.5, weight: 500, color: tagColor),
                  )
                : Hoverable(
                    onTap: onTap,
                    builder: (hover) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: hover ? Mid.raised : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: onest(12.5, weight: 500, color: tagColor),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// The file's own columns, a choice over each, and its first rows as read.
class _Columns extends StatelessWidget {
  const _Columns({
    required this.sheet,
    required this.mapping,
    required this.skipped,
    required this.onRole,
  });

  final Sheet sheet;
  final ImportMapping mapping;
  final Set<int> skipped;
  final void Function(int col, ColumnRole role) onRole;

  static const _width = 168.0;
  static const _rows = 7;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final dataRows = dataRowsOf(sheet, mapping);
    final labels = headerLabels(sheet, mapping.headerRow, dataRows);
    // Columns with something on a transaction row; before there's a date
    // column, every column with anything in it.
    final cols =
        dataRows.isEmpty
              ? [
                  for (var c = 0; c < sheet.width; c++)
                    if (sheet.rows.any((r) => c < r.length && r[c] != null)) c,
                ]
              : {
                  ...dataColumns(sheet, dataRows),
                  ...mapping.roles.keys,
                }.toList()
          ..sort();
    final first = (mapping.headerRow ?? -1) + 1;
    final rows = <int>[
      for (var r = first; r < sheet.rows.length; r++)
        if (sheet.rows[r].any((c) => c != null && '$c'.trim().isNotEmpty)) r,
    ].take(_rows).toList();

    String role(ColumnRole r) => switch (r) {
      ColumnRole.ignore => t.importRoleIgnore,
      ColumnRole.date => t.importRoleDate,
      ColumnRole.amount => t.importRoleAmount,
      ColumnRole.moneyIn => t.importRoleIn,
      ColumnRole.moneyOut => t.importRoleOut,
      ColumnRole.payee => t.importRolePayee,
      ColumnRole.memo => t.importRoleMemo,
      ColumnRole.balance => t.importRoleBalance,
    };

    String cell(Object? v) => switch (v) {
      null => '',
      DateTime d =>
        d.hour == 0 && d.minute == 0
            ? fullDate(d)
            : '${fullDate(d)} ${d.hour.toString().padLeft(2, '0')}:'
                  '${d.minute.toString().padLeft(2, '0')}',
      // As the file has it: a figure, no currency sign.
      double n =>
        '${n < 0 ? '−' : ''}${formatWhole((n * 100).round())}'
            '${formatCents((n * 100).round())}',
      bool b => b ? '✓' : '',
      _ => '$v'.trim(),
    };

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Mid.rule),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: Mid.card,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    for (final c in cols)
                      SizedBox(
                        width: _width,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _RolePicker(
                                key: ValueKey('import-role-$c'),
                                value: mapping.roleOf(c),
                                label: role,
                                onPick: (r) => onRole(c, r),
                              ),
                              // The file's own name for it, when it has one.
                              if (labels.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  labels[c] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: onest(11.5, color: Mid.ink3),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              for (final r in rows)
                Container(
                  height: 26,
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Mid.rule)),
                  ),
                  child: Row(
                    children: [
                      for (final c in cols)
                        SizedBox(
                          width: _width,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              cell(sheet.cell(r, c)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: onest(
                                12.5,
                                tabular: true,
                                color: skipped.contains(r)
                                    ? Mid.ink3
                                    : (mapping.roleOf(c) == ColumnRole.ignore
                                          ? Mid.ink3
                                          : Mid.ink),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What a column holds, as a menu of the roles.
class _RolePicker extends StatelessWidget {
  const _RolePicker({
    super.key,
    required this.value,
    required this.label,
    required this.onPick,
  });

  final ColumnRole value;
  final String Function(ColumnRole) label;
  final ValueChanged<ColumnRole> onPick;

  @override
  Widget build(BuildContext context) {
    final used = value != ColumnRole.ignore;
    return PopupMenuButton<ColumnRole>(
      tooltip: '',
      initialValue: value,
      onSelected: onPick,
      color: Mid.raised,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        for (final r in const [
          ColumnRole.date,
          ColumnRole.amount,
          ColumnRole.moneyIn,
          ColumnRole.moneyOut,
          ColumnRole.payee,
          ColumnRole.memo,
          ColumnRole.balance,
          ColumnRole.ignore,
        ])
          PopupMenuItem(
            value: r,
            height: 34,
            child: Text(
              label(r),
              style: onest(13, weight: r == value ? 600 : 400),
            ),
          ),
      ],
      child: Container(
        height: 28,
        padding: const EdgeInsets.only(left: 8, right: 4),
        decoration: BoxDecoration(
          color: used ? Mid.blueWash : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: used ? Mid.blueEdge : Mid.ink2.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: onest(
                  12.5,
                  weight: used ? 600 : 400,
                  color: used ? Mid.ink : Mid.ink3,
                ),
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 16, color: Mid.ink3),
          ],
        ),
      ),
    );
  }
}
