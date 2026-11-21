part of 'phone_app.dart';

// Importing a bank file on the phone (#531; the owner's pick of sketch A,
// 2026-11-21: ADR 0004 "Import on the phone"). The computer's import window
// as a page: the file's own table with a choice over each column, scrolled
// sideways, then how many rows come in and how many are skipped, and
// whatever needs saying. A file shaped like the last one into this account
// skips the columns. The file is read here and nothing of it is kept but
// the rows.

/// What the page hands back once the rows are in: the act, for Undo, and
/// what the bar says.
typedef _Imported = ({PhoneActed acted, ImportRecord record, String said});

/// How long the bar after an import stays, with its Undo.
const _importSnackTime = Duration(seconds: 15);

/// **Import transactions…** in [account]'s header: the phone's own file
/// picker, then the page; after an import, says what it did with an Undo.
Future<void> _openImport(
  BuildContext context, {
  required PhoneStore store,
  required AccountInfo account,
}) async {
  // One at a time, and the folder isn't looked at meanwhile: rows arriving
  // under the page would make its counts untrue (as the computer holds the
  // folder under its import window).
  if (store.importing.value) return;
  store.importing.value = true;
  try {
    await _pickAndImport(context, store: store, account: account);
  } finally {
    store.importing.value = false;
  }
}

Future<void> _pickAndImport(
  BuildContext context, {
  required PhoneStore store,
  required AccountInfo account,
}) async {
  final t = context.t;
  final messenger = ScaffoldMessenger.of(context);
  void say(String words) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        persist: false,
        duration: phoneSnackTime,
        key: const ValueKey('import-said'),
        backgroundColor: Mid.raised,
        content: Text(words, style: onest(15, color: Mid.ink)),
      ),
    );
  final XFile? picked;
  try {
    // Every file is offered: a bank's file comes out of Drive or a mail app
    // under whatever type that app gives it, and the app tells the kinds
    // apart by what is in them.
    picked = await openFile();
  } catch (e) {
    debugPrint('The phone\'s file picker failed: $e');
    say(t.ledgerCouldntOpenFileDialog);
    return;
  }
  if (picked == null || !context.mounted) return;
  final data = store.snapshot.data;
  if (data == null) return;
  final saved = SavedMapping.decode(
    data.prefs[AppDatabase.importMappingKey(account.id)],
  );
  final OpenedBankFile opened;
  try {
    final bytes = await picked.readAsBytes();
    await _dropPickedCopy(picked.path);
    opened = openBankFile(bytes, picked.name, saved);
  } catch (e) {
    debugPrint('Reading a bank file on the phone failed: $e');
    say(
      isBankFileName(picked.name)
          ? t.importCouldntReadDamaged(picked.name)
          : t.importCouldntRead(picked.name),
    );
    return;
  }
  if (!opened.fits && !opened.mapping.hasDate) {
    say(t.importNoDates(picked.name));
    return;
  }
  if (!context.mounted) return;
  // What an earlier try said has no place over the page.
  messenger.hideCurrentSnackBar();
  final name = picked.name;
  final done = await Navigator.of(context).push(
    MaterialPageRoute<_Imported>(
      builder: (_) => _ImportPage(
        store: store,
        account: account,
        fileName: name,
        opened: opened,
      ),
    ),
  );
  if (done == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        persist: false,
        // A whole file's rows, in a sentence of several parts: longer to
        // read, and more to take back, than one entry's.
        duration: _importSnackTime,
        key: const ValueKey('import-done'),
        backgroundColor: Mid.raised,
        content: Text(done.said, style: onest(15, color: Mid.ink)),
        action: SnackBarAction(
          label: t.ledgerUndo,
          textColor: Mid.blue,
          onPressed: () async {
            try {
              await store.replay(done.acted.undo);
            } catch (e) {
              debugPrint('Undoing an import on the phone failed: $e');
              say(t.ledgerCouldntUndo(importDoneLabel(t, done.record)));
            }
          },
        ),
      ),
    );
}

/// The picker's copy of the file, in the app's own folder, is deleted once
/// read (`data/picked_copy.dart`): an iPhone's is in its temporary folder,
/// Android's in the app's cache.
Future<void> _dropPickedCopy(String path) async {
  try {
    final own = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => [Directory.systemTemp.path],
      TargetPlatform.android => [(await getTemporaryDirectory()).path],
      _ => const <String>[],
    };
    await dropPickedCopy(path, own: own);
  } catch (e) {
    debugPrint('Finding the picked file\'s copy failed: $e');
  }
}

class _ImportPage extends StatefulWidget {
  const _ImportPage({
    required this.store,
    required this.account,
    required this.fileName,
    required this.opened,
  });
  final PhoneStore store;
  final AccountInfo account;
  final String fileName;
  final OpenedBankFile opened;

  @override
  State<_ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<_ImportPage> {
  late ImportMapping _mapping = widget.opened.mapping;
  late bool _showColumns = !widget.opened.fits;
  ReadResult? _read;
  ImportPlan? _plan;
  int _asked = 0;

  /// Rows dated on or before the opening balance's day: move it before them
  /// (the default, owner 2026-09-30) or leave it and count them twice.
  bool _moveOpening = true;

  /// Import was pressed and is being written.
  bool _busy = false;

  /// Why the last press of Import wrote nothing.
  String? _failed;

  AccountInfo get _a => widget.account;
  Sheet get _sheet => widget.opened.sheet;
  bool get _owed => _a.isOwed;

  /// The ledger the plan was worked out against.
  LedgerData? _plannedOn;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_ledgerMoved);
    unawaited(_reread());
  }

  @override
  void dispose() {
    widget.store.removeListener(_ledgerMoved);
    super.dispose();
  }

  /// The ledger changed under the page (a look already under way brought
  /// rows in): what each row would do is worked out again, so the counts
  /// are never of a ledger that is gone.
  void _ledgerMoved() {
    if (_busy || !mounted) return;
    if (identical(widget.store.snapshot.data, _plannedOn)) return;
    unawaited(_reread());
  }

  Future<void> _reread() async {
    final read = _mapping.complete
        ? readRows(_sheet, _mapping, decimals: _a.currency.decimals)
        : null;
    final ask = ++_asked;
    _plannedOn = widget.store.snapshot.data;
    setState(() {
      _read = read;
      _plan = null;
      _failed = null;
    });
    if (read == null) return;
    final ImportPlan plan;
    try {
      plan = await widget.store.planImport(
        _a.id,
        read.rows,
        importKeys(_a.id, read.rows),
      );
    } catch (e) {
      debugPrint('Planning an import on the phone failed: $e');
      if (mounted && ask == _asked) {
        setState(() => _failed = context.t.importCouldntImportRows);
      }
      return;
    }
    if (!mounted || ask != _asked) return;
    setState(() => _plan = plan);
  }

  void _set(ImportMapping m) {
    _mapping = m;
    unawaited(_reread());
  }

  int _count(ImportFate f) => _plan?.rows.where((p) => p.fate == f).length ?? 0;
  int get _toWrite => _count(ImportFate.add) + _count(ImportFate.match);

  ({DateTime date, int amount})? get _openingMove {
    final b = heldByOpening(_plan);
    final opening = _plan?.opening;
    if (b == null || !_moveOpening || opening == null || opening.locked) {
      return null;
    }
    return (date: b.date, amount: b.amount);
  }

  int _shown(int v) => _owed ? -v : v;
  String _money(int v) => formatMoney(v, currency: _a.currency);

  Future<void> _import() async {
    final plan = _plan, read = _read;
    if (plan == null || read == null || _toWrite == 0 || _busy) return;
    final t = context.t;
    final check = read.check;
    final act = PhoneImport(
      _a.id,
      plan: plan.rows,
      uncategorized: t.importUncategorized,
      moveOpening: _openingMove,
      // Remembered for the next file into this account.
      mapping: SavedMapping(
        shape: fileShape(_sheet, _mapping),
        kind: widget.opened.kind,
        mapping: _mapping,
        proven: check == null || check.ok,
      ).encode(),
    );
    setState(() {
      _busy = true;
      _failed = null;
    });
    final PhoneActed acted;
    try {
      acted = await widget.store.actRow(act);
    } catch (e) {
      debugPrint('Importing on the phone failed: $e');
      if (!mounted) return;
      final failed = switch (e) {
        final DbException d => t.importCouldntImport(dbProblem(t, d)),
        _ => t.importCouldntImportRows,
      };
      _busy = false;
      // Nothing was written. The ledger may no longer be the one the plan
      // was made for, so it is made again, and the reason stays said.
      await _reread();
      if (mounted) setState(() => _failed = failed);
      return;
    }
    if (!mounted) return;
    final done = act.done;
    final data = widget.store.snapshot.data;
    if (done == null) return Navigator.of(context).pop();
    Navigator.of(context).pop<_Imported>((
      acted: acted,
      record: done.record,
      said: importSays(
        t,
        record: done.record,
        account: _a,
        accounts: data?.accounts ?? {_a.id: _a},
        uncategorized: t.importUncategorized,
        billsPaid: done.billsPaid,
        billsToCheck: done.billsToCheck,
      ),
    ));
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
    final plan = _plan;
    final nothingNew = plan != null && _toWrite == 0;
    return PopScope(
      // While the rows are being written the page stays: left then, they
      // would be in with nothing said and no Undo.
      canPop: !_busy,
      child: _scaffold(t, plan, nothingNew),
    );
  }

  Widget _scaffold(Words t, ImportPlan? plan, bool nothingNew) {
    return Scaffold(
      backgroundColor: Mid.ground,
      appBar: AppBar(
        backgroundColor: Mid.ground,
        foregroundColor: Mid.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        // A long account name goes onto a second line, whole.
        title: Text(
          t.importTitle(_a.name),
          key: const ValueKey('import-title'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: onest(19, weight: 600),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          key: const ValueKey('import-page'),
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            // The file's name whole, however long the bank made it.
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Text(
                widget.fileName,
                key: const ValueKey('import-file'),
                style: onest(13, color: Mid.ink2),
              ),
            ),
            if (_showColumns) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  t.importColumnsHint,
                  style: onest(14, color: Mid.ink2),
                ),
              ),
              const SizedBox(height: 12),
              // Its right edge runs off the screen: the table goes on, and
              // scrolls sideways.
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: _ImportColumns(
                  sheet: _sheet,
                  mapping: _mapping,
                  skipped: {
                    for (final s in _read?.skipped ?? const <SkippedRow>[])
                      s.sourceRow,
                  },
                  onRole: (col, role) => _set(_mapping.withRole(col, role)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _choices(t),
                ),
              ),
            ] else
              Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: Mid.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Mid.rule),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _note(
                      Icons.check_rounded,
                      Mid.green,
                      t.importSavedColumns,
                      ink: Mid.ink2,
                    ),
                    const SizedBox(height: 8),
                    _button(
                      'import-change-columns',
                      t.importChangeColumns,
                      () => setState(() => _showColumns = true),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: _preview(t),
            ),
          ],
        ),
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
              if (_failed case final failed?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    failed,
                    key: const ValueKey('import-failed'),
                    style: onest(14, weight: 500, color: Mid.coral),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      key: const ValueKey('import-cancel'),
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        foregroundColor: Mid.ink2,
                        textStyle: onest(16, weight: 500),
                      ),
                      child: Text(t.importCancel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: nothingNew
                        ? Text(
                            t.importNothingNew,
                            key: const ValueKey('import-nothing-new'),
                            textAlign: TextAlign.center,
                            style: onest(15, color: Mid.ink2),
                          )
                        : FilledButton(
                            key: const ValueKey('import-do'),
                            onPressed: plan == null || _busy ? null : _import,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              backgroundColor: Mid.fill,
                              foregroundColor: Mid.onFill,
                              disabledBackgroundColor: Mid.fill.withValues(
                                alpha: 0.45,
                              ),
                              disabledForegroundColor: Mid.onFill,
                              textStyle: onest(16, weight: 600),
                            ),
                            child: Text(switch ((
                              _count(ImportFate.add),
                              _count(ImportFate.match),
                            )) {
                              (final n, 0) => t.importDo(n),
                              (0, final c) => t.importDoOnlyClear(c),
                              (final n, final c) => t.importDoClear(n, c),
                            }, textAlign: TextAlign.center),
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

  /// The date order, when a text date reads both ways, and the sign, when
  /// one column holds the amount.
  List<Widget> _choices(Words t) => [
    if (dateReadBothWays(_sheet, _mapping) case final ambiguous?)
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
    if (_mapping.columnOf(ColumnRole.amount) != null)
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
    if (!_mapping.complete)
      Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Text(
          t.importNeedDateAmount,
          key: const ValueKey('import-need'),
          style: onest(15, weight: 600, color: Mid.coral),
        ),
      ),
  ];

  /// A question with its answers as buttons, the chosen one filled.
  Widget _choiceRow(
    String label,
    List<(String, bool, VoidCallback, String)> choices,
  ) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label, style: onest(14, color: Mid.ink2)),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (text, on, tap, key) in choices)
              InkWell(
                key: ValueKey(key),
                onTap: tap,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: on ? Mid.blueWash : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: on ? Mid.blue : Mid.ink2.withValues(alpha: 0.3),
                      width: on ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    text,
                    style: onest(
                      14,
                      weight: on ? 600 : 400,
                      color: on ? Mid.ink : Mid.ink2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );

  /// How many rows come in and how many are skipped, then only what needs
  /// saying, as the computer's window says it.
  Widget _preview(Words t) {
    final read = _read;
    final plan = _plan;
    if (read == null) return const SizedBox.shrink();
    if (plan == null) {
      if (_failed != null) return const SizedBox.shrink();
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final added = _count(ImportFate.add);
    final skipped = plan.rows.length - _toWrite;
    final noAmount = [
      for (final s in read.skipped)
        if (s.reason == SkipReason.noAmount) s.sourceRow + 1,
    ];
    final notes = <Widget>[];
    final before = heldByOpening(plan);
    final opening = plan.opening;
    // A reconciled one can't move: planImport skips the rows it holds.
    if (before != null && opening != null && !opening.locked) {
      notes.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _note(
              Icons.warning_amber_rounded,
              Mid.coral,
              t.importBeforeOpening(
                before.rows.length,
                _money(_shown(opening.amount)),
                sayFullDate(t, opening.asOf),
              ),
              big: true,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: _choiceRow('', [
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
    final here = _a.currency;
    final named = fileCurrency(_sheet);
    final sample = plan.rows.where((p) => p.fate != ImportFate.already);
    if (named != null && named != here && sample.isNotEmpty) {
      final v = _shown(sample.first.row.amount).abs();
      notes.add(
        _note(
          Icons.warning_amber_rounded,
          Mid.coral,
          t.importFileIn(
            currencyName(t, named),
            _a.name,
            currencyName(t, here),
            formatMoney(v, currency: named),
            formatMoney(v, currency: here),
          ),
          big: true,
        ),
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
    // Said only when it doesn't add up: the line below answers the rest.
    final check = read.check;
    if (check != null && !check.ok) {
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
            if (check.mismatches > 1) t.importBalanceOffCount(check.mismatches),
          ].join(' '),
          big: true,
        ),
      );
    }
    final cleared = widget.store.snapshot.data?.summaryFor(_a.id).cleared ?? 0;
    final against = clearedAgainstBank(
      read: read,
      plan: plan,
      cleared: cleared,
      owed: _owed,
      openingMove: _openingMove,
    );
    if (against != null) {
      final (:ours, :bank, :day, :held) = against;
      final heldWords = ours == bank || held.isEmpty
          ? ''
          : ' ${t.importHeldCome(held.length, _money(_shown(held.fold(0, (s, v) => s + v))))}';
      notes.add(
        ours == bank
            ? _note(
                Icons.check_rounded,
                Mid.green,
                day == null
                    ? t.importClearedMatches(_money(_shown(ours)))
                    : t.importClearedMatchesOn(
                        _money(_shown(ours)),
                        sayFullDate(t, day),
                      ),
                key: 'import-bank',
              )
            : _note(
                Icons.info_outline_rounded,
                Mid.note,
                (day == null
                        ? t.importClearedDiffers(
                            _money(_shown(ours)),
                            _money(_shown(bank)),
                            _money((ours - bank).abs()),
                          )
                        : t.importClearedDiffersOn(
                            _money(_shown(ours)),
                            _money(_shown(bank)),
                            sayFullDate(t, day),
                            _money((ours - bank).abs()),
                          )) +
                    heldWords,
                key: 'import-bank',
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
              padding: const EdgeInsets.only(left: 28, top: 8),
              child: _button(
                'import-leave-new-out',
                t.importLeaveNewOut,
                _leaveNewOut,
              ),
            ),
          ],
        ),
      );
    }
    // Maybe the same purchase at another amount: offered, one pair at a
    // time, never assumed (owner, 2026-10-23).
    for (final (i, p) in plan.rows.indexed) {
      final near = p.near;
      if (near == null || p.fate != ImportFate.add) continue;
      notes.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _note(
              Icons.info_outline_rounded,
              Mid.note,
              t.importMaybeSame(
                near.payee,
                _money(_shown(near.amount!).abs()),
                sayDate(t, near.date),
                _money(_shown(p.row.amount).abs()),
                sayDate(t, dateOnly(p.row.date)),
              ),
              ink: Mid.ink,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 8),
              child: _button(
                'import-same-$i',
                t.importSamePurchase(_money(_shown(p.row.amount).abs())),
                () => setState(
                  () => _plan = plan.withRows(
                    [...plan.rows]..[i] = p.samePurchase(),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final unmatched = typedNotInFile(plan);
    if (unmatched.isNotEmpty) {
      const shown = 4;
      final items = [
        for (final x in unmatched.take(shown))
          t.importUnmatchedItem(
            x.payee,
            _money(_shown(x.amount)),
            sayDate(t, x.date),
          ),
        if (unmatched.length > shown)
          t.importUnmatchedMore(unmatched.length - shown),
      ];
      notes.add(
        _note(
          Icons.info_outline_rounded,
          Mid.note,
          t.importUnmatched(
            unmatched.length,
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
          [
            t.importCountToImport(_toWrite),
            if (skipped > 0) t.importCountSkipped(skipped),
          ].join(' · '),
          key: const ValueKey('import-summary'),
          style: onest(21, weight: 700),
        ),
        for (final n in notes) ...[const SizedBox(height: 14), n],
      ],
    );
  }

  /// A line with its mark: coral and heavy for a warning ([big]), green for
  /// what agrees, plain for the rest.
  Widget _note(
    IconData icon,
    Color color,
    String text, {
    bool big = false,
    Color? ink,
    String? key,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(icon, size: 20, color: color),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          key: key == null ? null : ValueKey(key),
          style: onest(15, weight: big ? 600 : 400, color: ink ?? color),
        ),
      ),
    ],
  );

  /// A button inside the page, blue and outlined as the header's are.
  Widget _button(String key, String label, VoidCallback onTap) =>
      OutlinedButton(
        key: ValueKey(key),
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          foregroundColor: Mid.blue,
          side: BorderSide(color: Mid.blue, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: onest(14, weight: 600),
        ),
        child: Text(label),
      );
}

/// What a column holds, in the computer's words.
String _roleName(Words t, ColumnRole r) => switch (r) {
  ColumnRole.ignore => t.importRoleIgnore,
  ColumnRole.date => t.importRoleDate,
  ColumnRole.amount => t.importRoleAmount,
  ColumnRole.moneyIn => t.importRoleIn,
  ColumnRole.moneyOut => t.importRoleOut,
  ColumnRole.payee => t.importRolePayee,
  ColumnRole.memo => t.importRoleMemo,
  ColumnRole.balance => t.importRoleBalance,
};

/// The file's own columns, a choice over each, and its first rows as read:
/// the computer's table, scrolled sideways (sketch A).
class _ImportColumns extends StatelessWidget {
  const _ImportColumns({
    required this.sheet,
    required this.mapping,
    required this.skipped,
    required this.onRole,
  });

  final Sheet sheet;
  final ImportMapping mapping;
  final Set<int> skipped;
  final void Function(int col, ColumnRole role) onRole;

  static const _width = 150.0;
  static const _rows = 7;

  @override
  Widget build(BuildContext context) {
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
      key: const ValueKey('import-columns'),
      decoration: BoxDecoration(
        color: Mid.card,
        border: Border(
          top: BorderSide(color: Mid.rule),
          left: BorderSide(color: Mid.rule),
          bottom: BorderSide(color: Mid.rule),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: Mid.ground,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  for (final c in cols)
                    SizedBox(
                      width: _width,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ImportRolePicker(
                              key: ValueKey('import-role-$c'),
                              value: mapping.roleOf(c),
                              onPick: (r) => onRole(c, r),
                            ),
                            // The file's own name for it, when it has one.
                            if (labels.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: Text(
                                  labels[c] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: onest(12, color: Mid.ink2),
                                ),
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
                height: 32,
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
                              13,
                              tabular: true,
                              color:
                                  skipped.contains(r) ||
                                      mapping.roleOf(c) == ColumnRole.ignore
                                  ? Mid.ink3
                                  : Mid.ink,
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
    );
  }
}

/// What a column holds, as a menu of the roles, a finger high.
class _ImportRolePicker extends StatelessWidget {
  const _ImportRolePicker({
    super.key,
    required this.value,
    required this.onPick,
  });

  final ColumnRole value;
  final ValueChanged<ColumnRole> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
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
            height: 48,
            child: Text(
              _roleName(t, r),
              style: onest(16, weight: r == value ? 600 : 400, color: Mid.ink),
            ),
          ),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.only(left: 8, right: 2),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: used ? Mid.blueWash : Mid.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: used ? Mid.blue : Mid.ink2.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              // "Amount (+ in, − out)" on two lines, so its signs show.
              child: Text(
                _roleName(t, value),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: onest(
                  13,
                  weight: used ? 600 : 400,
                  color: used ? Mid.ink : Mid.ink2,
                  height: 1.15,
                ),
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 18, color: Mid.ink2),
          ],
        ),
      ),
    );
  }
}
