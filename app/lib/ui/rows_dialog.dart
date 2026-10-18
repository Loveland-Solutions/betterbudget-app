part of 'ledger_screen.dart';

// Two computers changed the same thing two ways (ADR 0005, "Converge first,
// ask second"; ADR 0004, "Two computers, step 4: told after, not asked
// before"). Both computers settle it the same way at once, so nothing waits
// for an answer; the person whose change was replaced is told in a popup
// that stays, and Show opens this window: each thing with what each
// computer said, the version the ledger holds now marked, and the three
// buttons to change it. A button changed is the person's own act, an
// ordinary change the other computer takes in. What has no card (a pay, a
// plan, a setting, something that stays) is its sentence, with no buttons.
//
// With three or more computers on the ledger, the same window asks before
// anything comes in, as step 3 did ([_RowsDialog.asking]).

/// The cards the window can show buttons for: a transaction, an amount
/// assigned, a name.
bool _hasCard(Ask a) =>
    a.rows.isNotEmpty &&
    const {
      AskKind.transaction,
      AskKind.assigned,
      AskKind.renamed,
    }.contains(a.kind);

Currency _currencyOf(String? code) => Currency.fromCode(code);

List<AskLine> _realLines(AskSide s) => [
  for (final l in s.lines)
    if (!l.isCategory) l,
];

List<AskLine> _categoryLines(AskSide s) => [
  for (final l in s.lines)
    if (l.isCategory) l,
];

/// A transaction's money as a person says it: the amount once (a transfer
/// is one amount), with its sign only where the two versions go opposite
/// ways (a refund against a purchase), and its account where the two
/// differ.
String _moneySaid(BuildContext context, AskSide s, AskSide other) {
  final line = _realLines(s).firstOrNull;
  if (line == null) return '';
  final o = _realLines(other).firstOrNull;
  final signed = o != null && (line.amountMinor < 0) != (o.amountMinor < 0);
  final amount = formatShort(
    signed ? line.amountMinor : line.amountMinor.abs(),
    currency: _currencyOf(line.currency),
  );
  return o != null && o.account != line.account
      ? context.t.ledgerBothAmountIn(amount, line.account)
      : amount;
}

/// Its categories: one by name, a split with each one's amount.
String _filingSaid(AskSide s) {
  final lines = _categoryLines(s);
  if (lines.length == 1) return lines.single.account;
  return [
    for (final l in lines)
      '${l.account} ${formatShort(l.amountMinor.abs(), currency: _currencyOf(l.currency))}',
  ].join(', ');
}

/// The parts of a transaction a person changes, each as a key to compare
/// and the words for it.
List<({String Function(AskSide) key, String Function(AskSide, AskSide) say})>
_partsOf(BuildContext context) {
  final t = context.t;
  String lines(List<AskLine> ls, {bool cleared = false}) => [
    for (final l in ls)
      '${l.account}|${l.amountMinor}|${l.currency}${cleared ? '|${l.cleared}' : ''}',
  ].join(';');
  return [
    (
      key: (s) => lines(_realLines(s)),
      say: (s, o) => _moneySaid(context, s, o),
    ),
    (
      key: (s) => s.date ?? '',
      say: (s, _) => s.date == null ? '' : fullDate(DateTime.parse(s.date!)),
    ),
    (key: (s) => lines(_categoryLines(s)), say: (s, _) => _filingSaid(s)),
    (key: (s) => s.payee ?? '', say: (s, _) => s.payee ?? t.ledgerBothNoPayee),
    (
      key: (s) => s.memo ?? '',
      say: (s, _) => s.memo == null || s.memo!.isEmpty
          ? t.ledgerBothNoMemo
          : t.ledgerBothMemo(s.memo!),
    ),
  ];
}

/// The first part this computer changed (from what it was) that isn't in
/// what is kept now: the index into [_partsOf], or -1 for its cleared tick,
/// or null when none of those.
int? _lostPart(BuildContext context, Ask a) {
  final now = a.now ?? a.theirs;
  final was = a.hasBase ? a.neither : null;
  final parts = _partsOf(context);
  bool lost(String Function(AskSide) key) => was == null
      ? key(a.mine) != key(now)
      : key(a.mine) != key(was) && key(now) != key(a.mine);
  for (final (i, p) in parts.indexed) {
    if (lost(p.key)) return i;
  }
  String cleared(AskSide s) =>
      [for (final l in _realLines(s)) l.cleared].join(',');
  if (lost(cleared)) return -1;
  return null;
}

/// "In October", or the pay period by its first day.
String _whenSaid(BuildContext context, String? date) {
  final t = context.t;
  final d = date == null ? null : DateTime.tryParse(date);
  if (d == null) return '';
  return d.day == 1
      ? t.ledgerBothWhenMonth(monthName(t, d.month))
      : t.ledgerBothWhenPay(fullDate(d));
}

/// A pay as a person says it: its amount, and the day of the month it
/// comes on.
String _paySaid(BuildContext context, Ask a, AskSide s) {
  final amount = formatShort(
    s.amountMinor ?? 0,
    currency: _currencyOf(a.currency),
  );
  final day = s.day;
  if (day == null) return amount;
  final ending = (day % 100 >= 11 && day % 100 <= 13)
      ? 'th'
      : switch (day % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return context.t.ledgerBothPayOn(
    amount,
    context.t.ledgerDayOrdinal(day, ending),
  );
}

/// The whole sentence the popup and the window say about one thing of
/// this computer's that was replaced: built from what this computer
/// changed, and, where a fact decided, the fact rather than the computer.
String _toldSentence(BuildContext context, Ask ask, String other) {
  final t = context.t;
  final now = ask.now ?? ask.theirs;
  switch (ask.kind) {
    case AskKind.transaction:
      final payee = ask.mine.payee ?? now.payee ?? t.ledgerRowsNoPayee;
      final on = ask.mine.date ?? now.date;
      final date = on == null ? '' : fullDate(DateTime.parse(on));
      if (ask.mine.deleted && !now.deleted) {
        final gone = _realLines(ask.mine).firstOrNull;
        final back = _realLines(now).firstOrNull;
        if (back == null) return t.ledgerBothDeletedHere(payee, date, other);
        final c = _currencyOf(back.currency);
        final amount = formatShort(
          (gone ?? back).amountMinor.abs(),
          currency: _currencyOf((gone ?? back).currency),
        );
        final change = formatShort(back.amountMinor.abs(), currency: c);
        return back.amountMinor < 0
            ? t.ledgerBothDeletedLower(
                payee,
                amount,
                back.account,
                date,
                other,
                change,
              )
            : t.ledgerBothDeletedHigher(
                payee,
                amount,
                back.account,
                date,
                other,
                change,
              );
      }
      final part = _lostPart(context, ask);
      if (part == -1) {
        final line = _realLines(ask.mine).firstOrNull;
        final amount = line == null
            ? ''
            : formatShort(
                line.amountMinor.abs(),
                currency: _currencyOf(line.currency),
              );
        return (line?.cleared ?? 0) > 0
            ? t.ledgerBothClearedLost(payee, amount, date, other)
            : t.ledgerBothUnclearedLost(payee, amount, date, other);
      }
      if (part == null) return t.ledgerBothRowPlain(payee, date, other);
      final say = _partsOf(context)[part].say;
      final kept = say(now, ask.mine), yours = say(ask.mine, now);
      if (part == 0 && ask.lock == 'bank') {
        return t.ledgerBothRowBank(payee, date, kept, yours);
      }
      if (part == 0 && ask.lock == 'reconciled') {
        final d = ask.lockDate == null
            ? null
            : DateTime.tryParse(ask.lockDate!);
        return t.ledgerBothRowReconciled(
          payee,
          date,
          d == null ? '' : fullDate(d),
          kept,
          yours,
        );
      }
      return t.ledgerBothRow(payee, date, other, kept, yours);
    case AskKind.assigned:
      final c = _currencyOf(ask.currency);
      final kept = formatShort(now.assignedMinor ?? 0, currency: c);
      final yours = formatShort(ask.mine.assignedMinor ?? 0, currency: c);
      final when = _whenSaid(context, ask.date);
      if (ask.also.isNotEmpty) {
        final also = ask.also.first;
        return t.ledgerBothAssignedMoved(
          ask.category ?? '',
          also.category,
          when,
          other,
          kept,
          formatShort(also.amountMinor, currency: c),
          yours,
        );
      }
      return t.ledgerBothAssigned(ask.category ?? '', when, other, kept, yours);
    case AskKind.renamed:
      return t.ledgerBothRenamed(
        ask.name ?? ask.mine.name ?? '',
        other,
        now.name ?? '',
        ask.mine.name ?? '',
      );
    case AskKind.pay:
      final kept = _paySaid(context, ask, now);
      final yours = _paySaid(context, ask, ask.mine);
      return kept == yours
          ? t.ledgerBothPay(ask.name ?? '', other)
          : t.ledgerBothPayKept(ask.name ?? '', other, kept, yours);
    case AskKind.plan:
      final c = _currencyOf(ask.currency);
      if (now.amountMinor != null &&
          ask.mine.amountMinor != null &&
          now.amountMinor != ask.mine.amountMinor) {
        return t.ledgerBothPlanKept(
          ask.name ?? '',
          other,
          formatShort(now.amountMinor!, currency: c),
          formatShort(ask.mine.amountMinor!, currency: c),
        );
      }
      return t.ledgerBothPlan(ask.name ?? '', other);
    case AskKind.setting:
      final key = ask.setting ?? '';
      final String? name = key == noRegularPayKey
          ? t.ledgerSettingNameNoPay
          : key.startsWith('import.')
          ? t.ledgerSettingNameImport
          : key.startsWith('budget.')
          ? t.ledgerSettingNameBudget
          : key.startsWith('ready.')
          ? t.ledgerSettingNameSavings
          : key.startsWith(phoneNamePrefix)
          ? t.ledgerSettingNamePhone
          : null;
      return name == null
          ? t.ledgerBothSetting(other)
          : t.ledgerBothSettingNamed(name, other);
    case AskKind.other:
      return t.ledgerBothOther(other);
    case AskKind.stays:
      final put = ask.theirs;
      final line = _realLines(put).firstOrNull ?? put.lines.firstOrNull;
      if (put.payee == null && line == null) {
        return t.ledgerBothStays(ask.name ?? '', other);
      }
      return t.ledgerBothStaysWith(
        ask.name ?? '',
        other,
        put.payee ?? t.ledgerRowsNoPayee,
        line == null
            ? ''
            : formatShort(
                line.amountMinor.abs(),
                currency: _currencyOf(line.currency),
              ),
        put.date == null ? '' : fullDate(DateTime.parse(put.date!)),
      );
  }
}

/// The window Show opens: a [Pick] for each thing whose button was
/// changed, by its id, when Done is clicked; null when it is closed
/// otherwise. [asking]: the question asked with three or more computers,
/// a [Pick] for every thing on Save my choices.
class _RowsDialog extends StatefulWidget {
  const _RowsDialog({
    required this.asks,
    required this.computer,
    this.asking = false,
  });
  final List<Ask> asks;

  /// What the other computer is called.
  final String? computer;
  final bool asking;

  @override
  State<_RowsDialog> createState() => _RowsDialogState();
}

class _RowsDialogState extends State<_RowsDialog> {
  // The version the ledger holds now, until another is picked; asked, this
  // computer's, which changes nothing here.
  late final Map<String, Pick?> _picks = {
    for (final a in widget.asks) a.id: widget.asking ? Pick.mine : a.inLedger,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final other = widget.computer ?? t.ledgerRowsOtherComputer;
    return Dialog(
      backgroundColor: Mid.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Mid.rule),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.asking
                    ? t.ledgerRowsTitle(widget.asks.length)
                    : t.ledgerBothTitle,
                style: onest(17, weight: 600, letterSpacing: -0.2),
              ),
              const SizedBox(height: 8),
              Text(
                widget.asking ? t.ledgerRowsBody : t.ledgerBothBody(other),
                style: onest(13, color: Mid.ink2, height: 1.4),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final a in widget.asks)
                        if (widget.asking || _hasCard(a))
                          _AskCard(
                            ask: a,
                            other: other,
                            pick: _picks[a.id],
                            asking: widget.asking,
                            onPick: (p) => setState(() => _picks[a.id] = p),
                          )
                        else
                          // Nothing to pick for it: its sentence.
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            decoration: BoxDecoration(
                              color: Mid.panel,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Mid.rule),
                            ),
                            child: Text(
                              _toldSentence(context, a, other),
                              key: ValueKey('rows-${a.id}-said'),
                              style: onest(13.5, color: Mid.ink, height: 1.4),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (widget.asking)
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      BarButton(
                        key: const ValueKey('rows-not-now'),
                        label: t.ledgerTwoNotNow,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      BarButton(
                        key: const ValueKey('rows-save'),
                        label: t.ledgerRowsSave,
                        active: true,
                        onTap: () => Navigator.of(context).pop({
                          for (final a in widget.asks)
                            a.id: _picks[a.id] ?? Pick.mine,
                        }),
                      ),
                    ],
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerRight,
                  child: BarButton(
                    key: const ValueKey('rows-done'),
                    label: t.ledgerBothDone,
                    active: true,
                    onTap: () => Navigator.of(context).pop({
                      for (final a in widget.asks)
                        if (_picks[a.id] case final p? when p != a.inLedger)
                          a.id: p,
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One thing both computers changed: what each says, which the ledger holds
/// now, and the three ways to change it.
class _AskCard extends StatelessWidget {
  const _AskCard({
    required this.ask,
    required this.other,
    required this.pick,
    required this.onPick,
    this.asking = false,
  });
  final Ask ask;
  final String other;
  final Pick? pick;
  final ValueChanged<Pick> onPick;
  final bool asking;

  /// The lines of one version, as the person reads them.
  List<String> _say(BuildContext context, AskSide side) {
    final t = context.t;
    if (ask.kind == AskKind.assigned) {
      return [
        formatShort(
          side.assignedMinor ?? 0,
          currency: _currencyOf(ask.currency),
        ),
      ];
    }
    if (ask.kind == AskKind.renamed) return [side.name ?? ''];
    if (side.deleted) return [t.ledgerRowsDeleted];
    // What all three say alike is in the heading, not said three times.
    bool differs(String? Function(AskSide) of) =>
        {of(ask.mine), of(ask.theirs), of(ask.neither)}.length > 1;
    return [
      if (side.date != null && differs((s) => s.date))
        fullDate(DateTime.parse(side.date!)),
      if (side.payee != null && differs((s) => s.payee)) side.payee!,
      if (side.memo != null) side.memo!,
      for (final l in side.lines)
        '${l.account}  ${formatShort(l.amountMinor, currency: _currencyOf(l.currency))}',
    ];
  }

  /// What it said, on a line: the amount of the account and the category.
  String _summary(BuildContext context, AskSide side) {
    final t = context.t;
    if (ask.kind != AskKind.transaction) return _say(context, side).single;
    if (side.deleted) return t.ledgerRowsDeleted;
    final real = side.lines.where((l) => !l.isCategory).firstOrNull;
    final category = side.lines.where((l) => l.isCategory).firstOrNull;
    return [
      if (real != null)
        formatShort(real.amountMinor, currency: _currencyOf(real.currency)),
      if (category != null) category.account,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final String heading;
    final String? under;
    if (ask.kind == AskKind.assigned) {
      heading = t.ledgerRowsAssigned(
        ask.category ?? '',
        ask.date == null ? '' : shortDate(DateTime.parse(ask.date!)),
      );
      under = null;
    } else if (ask.kind == AskKind.renamed) {
      heading = ask.name ?? ask.mine.name ?? '';
      under = null;
    } else {
      final sides = [ask.mine, ask.theirs, ask.neither];
      heading =
          sides.map((s) => s.payee).nonNulls.firstOrNull ?? t.ledgerRowsNoPayee;
      final date = sides.map((s) => s.date).nonNulls.firstOrNull;
      under = date == null ? null : fullDate(DateTime.parse(date));
    }
    final inLedger = asking ? null : ask.inLedger;
    final lockDate = ask.lockDate == null
        ? null
        : DateTime.tryParse(ask.lockDate!);
    final lock = asking
        ? null
        : switch (ask.lock) {
            'reconciled' => t.ledgerBothLockReconciled(
              lockDate == null ? '' : fullDate(lockDate),
            ),
            'bank' => t.ledgerBothLockBank,
            _ => null,
          };
    Widget box(String label, AskSide s, {bool now = false}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Mid.card,
        borderRadius: BorderRadius.circular(9),
        // The version in the ledger now: gold, done and safe.
        border: Border.all(color: now ? Mid.gold : Mid.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(label, style: onest(12, color: Mid.ink3)),
              if (now && label != t.ledgerBothLedgerNow)
                Text(
                  t.ledgerBothInLedger,
                  key: ValueKey('rows-${ask.id}-now'),
                  style: onest(12, weight: 600, color: Mid.gold),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (final line in _say(context, s))
            Text(line, style: onest(13.5, color: Mid.ink, tabular: true)),
        ],
      ),
    );
    final asItWas = _summary(context, ask.neither);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Mid.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Mid.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: onest(14, weight: 600)),
          if (under != null)
            Text(under, style: onest(12.5, color: Mid.ink3, tabular: true)),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: box(
                    t.ledgerRowsThisComputer,
                    ask.mine,
                    now: inLedger == Pick.mine,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: box(other, ask.theirs, now: inLedger == Pick.theirs),
                ),
              ],
            ),
          ),
          // Put together from the two: what the ledger holds is neither.
          if (!asking && inLedger == null && ask.now != null) ...[
            const SizedBox(height: 10),
            box(t.ledgerBothLedgerNow, ask.now!, now: true),
          ],
          if (ask.hasBase) ...[
            const SizedBox(height: 8),
            Text(
              inLedger == Pick.neither
                  ? t.ledgerRowsAsItWasNow(asItWas)
                  : t.ledgerRowsAsItWas(asItWas),
              style: onest(12.5, color: Mid.ink3, tabular: true),
            ),
          ],
          if (lock != null) ...[
            const SizedBox(height: 8),
            Text(
              lock,
              key: ValueKey('rows-${ask.id}-lock'),
              style: onest(12.5, color: Mid.ink2, height: 1.4),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            runSpacing: 6,
            children: [
              BarButton(
                key: ValueKey('rows-${ask.id}-mine'),
                label: ask.mine.deleted && lock == null
                    ? t.ledgerBothDeleteAnyway
                    : t.ledgerRowsKeepHere,
                active: pick == Pick.mine,
                onTap: () => onPick(Pick.mine),
              ),
              BarButton(
                key: ValueKey('rows-${ask.id}-theirs'),
                label: ask.theirs.deleted && lock == null
                    ? t.ledgerRowsKeepDeletedTheirs(other)
                    : t.ledgerRowsKeepTheirs(other),
                active: pick == Pick.theirs,
                onTap: () => onPick(Pick.theirs),
              ),
              if (ask.hasBase && (asking || ask.rows.containsKey(Pick.neither)))
                BarButton(
                  key: ValueKey('rows-${ask.id}-neither'),
                  label: t.ledgerRowsKeepNeither,
                  active: pick == Pick.neither,
                  onTap: () => onPick(Pick.neither),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
