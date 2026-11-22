part of 'phone_app.dart';

// Counting a cash account on the phone (#119, the owner's "Both"; ADR 0004
// "Counting a cash account"): the computer's Count, phone-sized. What is in
// the wallet on the amount pad, the sentence with the numbers, where the
// difference goes, and a Save that says the act. The count waits with the
// phone's entries; the computer saves the difference once, as its own
// Count does, when it takes it in.

/// Opens the count of [account], a cash account; after a save, says so
/// with an Undo.
Future<void> _openCount(
  BuildContext context, {
  required PhoneStore store,
  required PhoneAccount account,
}) async {
  final saved = await Navigator.of(context).push(
    MaterialPageRoute<({PhoneCount count, String said})>(
      builder: (_) => _CountPage(store: store, account: account),
    ),
  );
  if (saved == null || !context.mounted) return;
  final t = context.t;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        persist: false,
        duration: phoneSnackTime,

        key: const ValueKey('count-saved'),
        backgroundColor: Mid.raised,
        content: Text(saved.said, style: onest(15, color: Mid.ink)),
        action: SnackBarAction(
          label: t.ledgerUndo,
          textColor: Mid.blue,
          onPressed: () => unawaited(store.takeBack([saved.count.id])),
        ),
      ),
    );
}

class _CountPage extends StatefulWidget {
  const _CountPage({required this.store, required this.account});
  final PhoneStore store;
  final PhoneAccount account;

  @override
  State<_CountPage> createState() => _CountPageState();
}

class _CountPageState extends State<_CountPage> {
  /// What the pad has typed; empty until the cash is counted (a count is
  /// only worth anything because it was).
  String _typed = '';

  /// Where the difference goes: null is Not categorized.
  PhoneCategory? _category;

  /// Save was pressed with nothing typed.
  bool _missing = false;

  PhoneAccount get _account => widget.account;

  /// It has an opening balance, or a count waiting here that will make it
  /// or find it: a second count is then an ordinary one, as the computer
  /// will save it.
  bool get _opened =>
      _account.opened ||
      widget.store.counts.any((c) => c.accountId == _account.id);
  Currency get _currency => _account.currency;

  void _press(String key) => setState(() {
    _typed = pressAmountKey(_typed, key, _currency);
    _missing = false;
  });

  String _money(int v) => formatShort(v, currency: _currency);
  String _signed(int v) => v > 0 ? '+${_money(v)}' : _money(v);

  void _save(int held) {
    if (_typed.isEmpty) {
      setState(() => _missing = true);
      return;
    }
    final t = context.t;
    final counted = typedAmountMinor(_typed, _currency);
    final diff = counted - held;
    final opens = !_opened && diff > 0;
    final now = widget.store.now();
    final random = Random.secure();
    final count = PhoneCount(
      id: 'count-${[for (var i = 0; i < 8; i++) random.nextInt(256).toRadixString(16).padLeft(2, '0')].join()}',
      accountId: _account.id,
      countedMinor: counted,
      date: DateTime(now.year, now.month, now.day),
      madeAt: now,
      heldMinor: held,
      categoryId: _category?.id,
    );
    widget.store.addCount(count);
    Navigator.of(context).pop((
      count: count,
      said: diff == 0
          ? t.countSavedMatch(_account.name)
          : opens
          ? t.countSavedOpening(_account.name, _money(diff))
          : t.countSaved(
              _account.name,
              _signed(diff),
              _category?.name ?? t.importUncategorized,
            ),
    ));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) => _page(context),
  );

  Widget _page(BuildContext context) {
    final t = context.t;
    // What the rows hold through today, with what waits here (an earlier
    // count too); rows dated ahead aren't in the wallet yet.
    final held = widget.store.heldToday(_account);
    final counted = _typed.isEmpty ? null : typedAmountMinor(_typed, _currency);
    final diff = counted == null ? null : counted - held;
    final opens = !_opened && diff != null && diff > 0;
    final categoryName = _category?.name ?? t.importUncategorized;
    final low = MediaQuery.sizeOf(context).height < 800;
    return Scaffold(
      backgroundColor: Mid.ground,
      appBar: AppBar(
        backgroundColor: Mid.ground,
        foregroundColor: Mid.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(t.countTitle, style: onest(20, weight: 600)),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: _TapHold(
            child: CustomMultiChildLayout(
              delegate: _EntryLayout(low: low),
              children: [
                LayoutId(
                  id: _EntryPart.top,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: onest(17, weight: 500, color: Mid.ink2),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.countInWallet,
                          style: onest(15, color: Mid.ink2),
                        ),
                        Text(
                          _typed.isEmpty
                              ? typedAmountShown('0', _currency)
                              : typedAmountShown(_typed, _currency),
                          key: const ValueKey('count-amount'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: onest(
                            40,
                            weight: 600,
                            tabular: true,
                            color: _typed.isEmpty ? Mid.ink3 : Mid.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          counted == null
                              ? t.countRowsSayOnly(_money(held))
                              : t.countRowsSay(_money(held), _money(counted)),
                          key: const ValueKey('count-sentence'),
                          style: onest(15, color: Mid.ink2, height: 1.3),
                        ),
                        // The rows are the computer's last copy: from an
                        // earlier day, it says so, and that the computer
                        // works the difference out again.
                        if (!widget.store.snapshot.onItsOwn &&
                            !_sameDay(
                              widget.store.snapshot.madeAt,
                              widget.store.now(),
                            )) ...[
                          const SizedBox(height: 4),
                          _FromMac(
                            made: widget.store.snapshot.madeAt,
                            today: widget.store.now(),
                          ),
                          Text(
                            t.phoneCountRechecked,
                            style: onest(13, color: Mid.ink2, height: 1.3),
                          ),
                        ],
                        if (diff != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              diff == 0
                                  ? t.countMatches
                                  : opens
                                  ? t.countBecomesOpening(_money(diff))
                                  : diff < 0
                                  ? t.countLess(_money(-diff))
                                  : t.countMore(_money(diff)),
                              key: const ValueKey('count-result'),
                              style: onest(
                                16,
                                weight: 600,
                                height: 1.3,
                                color: diff == 0 ? Mid.green : Mid.ink,
                              ),
                            ),
                          ),
                        if (diff != null && diff != 0 && !opens) ...[
                          const SizedBox(height: 8),
                          Material(
                            color: Mid.card,
                            borderRadius: BorderRadius.circular(14),
                            clipBehavior: Clip.antiAlias,
                            child: _CategoryMenu(
                              store: widget.store,
                              currency: _currency,
                              onlyCurrency: true,
                              first: PhoneCategory(
                                id: _notCategorizedChoice,
                                name: t.importUncategorized,
                                leftMinor: 0,
                                currency: _currency,
                              ),
                              income: PhoneCategory(
                                id: phoneIncomeId,
                                name: t.ledgerIncome,
                                leftMinor: 0,
                                currency: _currency,
                              ),
                              newCategory: false,
                              onPicked: (c) => setState(
                                () => _category = c.id == _notCategorizedChoice
                                    ? null
                                    : c,
                              ),
                              builder: (context, open) => _FieldRow(
                                key: const ValueKey('count-category'),
                                label: t.countTheDifference,
                                value: categoryName,
                                onTap: open,
                                low: low,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                LayoutId(
                  id: _EntryPart.pad,
                  child: _AmountPad(currency: _currency, onKey: _press),
                ),
                LayoutId(
                  id: _EntryPart.foot,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_missing)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            t.countNeedsAmount,
                            textAlign: TextAlign.center,
                            style: onest(15, color: Mid.gold),
                          ),
                        ),
                      FilledButton(
                        key: const ValueKey('count-save'),
                        onPressed: () => _save(held),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: Mid.fill,
                          foregroundColor: Mid.onFill,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: onest(17, weight: 600),
                        ),
                        child: Text(
                          diff == null || diff == 0
                              ? t.countSave
                              : opens
                              ? t.countSaveOpening(_money(diff))
                              : t.countSaveWith(_signed(diff), categoryName),
                          textAlign: TextAlign.center,
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

/// Not categorized as the count's list offers it: a choice, not a
/// category the phone knows.
const _notCategorizedChoice = 'not-categorized';
