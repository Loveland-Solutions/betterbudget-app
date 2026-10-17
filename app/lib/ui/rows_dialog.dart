part of 'ledger_screen.dart';

// Two computers changed the same thing two ways (ADR 0005, "Converge first,
// ask second"; ADR 0004, "Two computers, step 4: told after, not asked
// before"). Both computers settle it the same way at once, so nothing waits
// for an answer; the person whose change was replaced is told in the popup
// for the other computer's changes, and Show opens this window: each thing
// with what each computer said, the version the ledger holds now marked,
// and the three buttons to change it. A button changed is the person's own
// act, an ordinary change the other computer takes in.

/// The cards the window can show: a transaction, an amount assigned, a
/// name. What else was settled is only said in the popup.
bool _hasCard(Ask a) =>
    a.rows.isNotEmpty &&
    const {
      AskKind.transaction,
      AskKind.assigned,
      AskKind.renamed,
    }.contains(a.kind);

/// What differs between [kept] and [yours], as the person would say it:
/// the amount, else the category, the date, the payee or the memo. Null
/// when it is none of those.
({String kept, String yours})? _whatDiffers(
  BuildContext context,
  Ask ask,
  AskSide kept,
  AskSide yours,
) {
  if (ask.kind == AskKind.assigned) {
    final c = Currency.fromCode(ask.currency);
    return (
      kept: formatShort(kept.assignedMinor ?? 0, currency: c),
      yours: formatShort(yours.assignedMinor ?? 0, currency: c),
    );
  }
  if (ask.kind == AskKind.renamed) {
    return (kept: kept.name ?? '', yours: yours.name ?? '');
  }
  String money(AskSide s) => [
    for (final l in s.lines.where((l) => !l.isCategory))
      formatShort(l.amountMinor.abs(), currency: Currency.fromCode(l.currency)),
  ].join(', ');
  String categories(AskSide s) =>
      [for (final l in s.lines.where((l) => l.isCategory)) l.account]
          .join(', ');
  for (final of in <String Function(AskSide)>[
    money,
    categories,
    (s) => s.date == null ? '' : fullDate(DateTime.parse(s.date!)),
    (s) => s.payee ?? '',
    (s) => s.memo ?? '',
  ]) {
    final a = of(kept), b = of(yours);
    if (a != b && a.isNotEmpty && b.isNotEmpty) return (kept: a, yours: b);
  }
  return null;
}

/// The whole sentence the popup says about one thing of this computer's
/// that was replaced.
String _toldSentence(BuildContext context, Ask ask, String other) {
  final t = context.t;
  final now = ask.now ?? ask.theirs;
  switch (ask.kind) {
    case AskKind.transaction:
      final payee = ask.mine.payee ?? now.payee ?? t.ledgerRowsNoPayee;
      final on = ask.mine.date ?? now.date;
      final date = on == null ? '' : fullDate(DateTime.parse(on));
      if (ask.mine.deleted && !now.deleted) {
        return t.ledgerBothDeletedHere(payee, date, other);
      }
      final d = _whatDiffers(context, ask, now, ask.mine);
      return d == null
          ? t.ledgerBothRowPlain(payee, date, other)
          : t.ledgerBothRow(payee, date, other, d.kept, d.yours);
    case AskKind.assigned:
      final d = _whatDiffers(context, ask, now, ask.mine)!;
      return t.ledgerBothAssigned(
        ask.category ?? '',
        ask.date == null ? '' : fullDate(DateTime.parse(ask.date!)),
        other,
        d.kept,
        d.yours,
      );
    case AskKind.renamed:
      return t.ledgerBothRenamed(
        ask.name ?? ask.mine.name ?? '',
        other,
        now.name ?? '',
        ask.mine.name ?? '',
      );
    case AskKind.pay:
      return t.ledgerBothPay(ask.name ?? '', other);
    case AskKind.plan:
      return t.ledgerBothPlan(ask.name ?? '', other);
    case AskKind.setting:
      return t.ledgerBothSetting(other);
    case AskKind.other:
      return t.ledgerBothOther(other);
    case AskKind.stays:
      return t.ledgerBothStays(ask.name ?? '', other);
  }
}

/// The window Show opens: a [Pick] for each thing whose button was
/// changed, by its id, when Done is clicked; null when it is closed
/// otherwise.
class _RowsDialog extends StatefulWidget {
  const _RowsDialog({required this.asks, required this.computer});
  final List<Ask> asks;

  /// What the other computer is called.
  final String? computer;

  @override
  State<_RowsDialog> createState() => _RowsDialogState();
}

class _RowsDialogState extends State<_RowsDialog> {
  // The version the ledger holds now, until another is picked.
  late final Map<String, Pick?> _picks = {
    for (final a in widget.asks) a.id: a.inLedger,
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
                t.ledgerBothTitle,
                style: onest(17, weight: 600, letterSpacing: -0.2),
              ),
              const SizedBox(height: 8),
              Text(
                t.ledgerBothBody(other),
                style: onest(13, color: Mid.ink2, height: 1.4),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final a in widget.asks)
                        _AskCard(
                          ask: a,
                          other: other,
                          pick: _picks[a.id],
                          onPick: (p) => setState(() => _picks[a.id] = p),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
  });
  final Ask ask;
  final String other;
  final Pick? pick;
  final ValueChanged<Pick> onPick;

  Currency _currency(String? code) => Currency.fromCode(code);

  /// The lines of one version, as the person reads them.
  List<String> _say(BuildContext context, AskSide side) {
    final t = context.t;
    if (ask.kind == AskKind.assigned) {
      return [
        formatShort(side.assignedMinor ?? 0, currency: _currency(ask.currency)),
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
        '${l.account}  ${formatShort(l.amountMinor, currency: _currency(l.currency))}',
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
        formatShort(real.amountMinor, currency: _currency(real.currency)),
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
    final inLedger = ask.inLedger;
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
          if (inLedger == null && ask.now != null) ...[
            const SizedBox(height: 10),
            box(t.ledgerBothLedgerNow, ask.now!, now: true),
          ],
          if (ask.hasBase) ...[
            const SizedBox(height: 8),
            Text(
              inLedger == Pick.neither
                  ? '${t.ledgerRowsAsItWas(_summary(context, ask.neither))} · ${t.ledgerBothInLedger}'
                  : t.ledgerRowsAsItWas(_summary(context, ask.neither)),
              style: onest(12.5, color: Mid.ink3, tabular: true),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            runSpacing: 6,
            children: [
              BarButton(
                key: ValueKey('rows-${ask.id}-mine'),
                label: ask.mine.deleted
                    ? t.ledgerBothDeleteAnyway
                    : t.ledgerRowsKeepHere,
                active: pick == Pick.mine,
                onTap: () => onPick(Pick.mine),
              ),
              BarButton(
                key: ValueKey('rows-${ask.id}-theirs'),
                label: ask.theirs.deleted
                    ? t.ledgerRowsKeepDeletedTheirs(other)
                    : t.ledgerRowsKeepTheirs(other),
                active: pick == Pick.theirs,
                onTap: () => onPick(Pick.theirs),
              ),
              if (ask.hasBase && ask.rows.containsKey(Pick.neither))
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
