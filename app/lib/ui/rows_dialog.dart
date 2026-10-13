part of 'ledger_screen.dart';

// Two computers changed the same thing two ways (ADR 0005, "Combine", ADR
// 0004 "Two computers: the row both changed"): each is listed with what
// each computer says, and the person keeps this computer's, the other's, or
// neither (as it was). Everything that doesn't conflict comes in with the
// answer.

/// The question's answer: a [Pick] for each [Ask], by its id; null when put
/// off.
class _RowsDialog extends StatefulWidget {
  const _RowsDialog({required this.asks, required this.computer});
  final List<Ask> asks;

  /// What the other computer is called.
  final String? computer;

  @override
  State<_RowsDialog> createState() => _RowsDialogState();
}

class _RowsDialogState extends State<_RowsDialog> {
  // This computer's way until another is chosen: nothing here changes.
  late final Map<String, Pick> _picks = {
    for (final a in widget.asks) a.id: Pick.mine,
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
                t.ledgerRowsTitle(widget.asks.length),
                style: onest(17, weight: 600, letterSpacing: -0.2),
              ),
              const SizedBox(height: 8),
              Text(
                t.ledgerRowsBody(other),
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
                          pick: _picks[a.id]!,
                          onPick: (p) => setState(() => _picks[a.id] = p),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                      onTap: () => Navigator.of(context).pop({..._picks}),
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

/// One thing both computers changed: what each says, and the three ways to
/// settle it.
class _AskCard extends StatelessWidget {
  const _AskCard({
    required this.ask,
    required this.other,
    required this.pick,
    required this.onPick,
  });
  final Ask ask;
  final String other;
  final Pick pick;
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
    if (ask.kind == AskKind.assigned) return _say(context, side).single;
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
    } else {
      final sides = [ask.mine, ask.theirs, ask.neither];
      heading =
          sides.map((s) => s.payee).nonNulls.firstOrNull ?? t.ledgerRowsNoPayee;
      final date = sides.map((s) => s.date).nonNulls.firstOrNull;
      under = date == null ? null : fullDate(DateTime.parse(date));
    }
    Widget side(String label, AskSide s) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Mid.card,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Mid.rule),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: onest(12, color: Mid.ink3)),
            const SizedBox(height: 4),
            for (final line in _say(context, s))
              Text(line, style: onest(13.5, color: Mid.ink, tabular: true)),
          ],
        ),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              side(t.ledgerRowsThisComputer, ask.mine),
              const SizedBox(width: 10),
              side(other, ask.theirs),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            t.ledgerRowsAsItWas(_summary(context, ask.neither)),
            style: onest(12.5, color: Mid.ink3, tabular: true),
          ),
          const SizedBox(height: 10),
          Wrap(
            runSpacing: 6,
            children: [
              BarButton(
                key: ValueKey('rows-${ask.id}-mine'),
                label: ask.mine.deleted
                    ? t.ledgerRowsKeepDeletedHere
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
