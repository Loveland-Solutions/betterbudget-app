// The phone's asking window (ADR 0005, "How #526 is cut", piece 4 part 3;
// owner, 2026-11-20, sketch C): a thing changed on this phone and on another
// computer both is asked about once, and nothing comes in until then. Each
// thing already says what is kept (this phone's, unless changed), with a
// Change button for the few the person wants the other way; one Save makes
// the choices and brings in everything else. The same page asks the other
// question, two ledgers that can't be put together.
import 'package:flutter/material.dart';

import '../../data/phone_sync.dart' show PhoneAsking;
import '../../domain/combine.dart' show Ask, AskKind, AskSide, Pick;
import '../../domain/money.dart';
import '../language.dart';
import '../theme.dart';

/// The line across the top while something waits for an answer; tapping it
/// opens the page.
class PhoneAskingLine extends StatelessWidget {
  const PhoneAskingLine({super.key, required this.asking, required this.onTap});
  final PhoneAsking asking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Material(
      color: Mid.card,
      child: InkWell(
        key: const ValueKey('phone-asking-line'),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            asking.apart
                ? t.phoneApartTitle
                : t.phoneAskLine(asking.asks.length),
            style: onest(14, color: Mid.ink, height: 1.3),
          ),
        ),
      ),
    );
  }
}

/// What the page returns: the person's [Pick] for each thing, by its id, or
/// [keepFolder] for the question of two ledgers.
class PhoneAnswer {
  const PhoneAnswer.picks(Map<String, Pick> this.picks) : keepFolder = false;
  const PhoneAnswer.keepFolder() : picks = null, keepFolder = true;
  final Map<String, Pick>? picks;
  final bool keepFolder;
}

/// Opens the page and returns what was answered, or null for Not now.
Future<PhoneAnswer?> showPhoneAsking(
  BuildContext context,
  PhoneAsking asking,
) => Navigator.of(context).push<PhoneAnswer>(
  MaterialPageRoute(
    // Its own messenger: a snack bar from the page underneath (an edit's
    // "… edited · Undo") would lie over Save, the one button that answers.
    builder: (_) => ScaffoldMessenger(
      child: asking.apart
          ? _ApartPage(asking: asking)
          : _AsksPage(asking: asking),
    ),
  ),
);

Currency _currencyOf(String? code) => Currency.fromCode(code);

class _AsksPage extends StatefulWidget {
  const _AsksPage({required this.asking});
  final PhoneAsking asking;

  @override
  State<_AsksPage> createState() => _AsksPageState();
}

class _AsksPageState extends State<_AsksPage> {
  // This phone's, until another is picked: it changes nothing here. Not for
  // a thing one computer deleted and the other changed (owner, 2026-11-20:
  // "when in doubt have BetterBudget ask"): it waits for an answer.
  late final Map<String, Pick?> _picks = {
    for (final a in widget.asking.asks)
      if (!_doubtful(a)) a.id: Pick.mine,
  };

  bool get _answered => widget.asking.asks.every((a) => _picks[a.id] != null);
  // The thing whose ways are open.
  String? _open;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final computer = widget.asking.from ?? t.ledgerRowsOtherComputerInSentence;
    return Scaffold(
      backgroundColor: Mid.ground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('ask-not-now'),
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  minimumSize: const Size(64, 48),
                  foregroundColor: Mid.ink2,
                  textStyle: onest(15),
                ),
                child: Text(t.ledgerTwoNotNow),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Text(
                    t.phoneAskTitle(widget.asking.asks.length),
                    style: onest(21, weight: 600, height: 1.25),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.phoneAskBody,
                    style: onest(14, color: Mid.ink2, height: 1.45),
                  ),
                  const SizedBox(height: 14),
                  for (final a in widget.asking.asks)
                    _AskCard(
                      ask: a,
                      computer: computer,
                      pick: _picks[a.id],
                      open: _open == a.id || _picks[a.id] == null,
                      onOpen: () => setState(() => _open = a.id),
                      onPick: (p) => setState(() {
                        _picks[a.id] = p;
                        _open = null;
                      }),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Mid.rule)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      key: const ValueKey('ask-summary'),
                      t.phoneAskSummary(
                        _picks.values.where((p) => p == Pick.mine).length,
                        computer,
                        _picks.values.where((p) => p == Pick.theirs).length,
                        _picks.values.where((p) => p == Pick.neither).length,
                      ),
                      style: onest(13.5, color: Mid.ink2, tabular: true),
                    ),
                  ),
                  FilledButton(
                    key: const ValueKey('ask-save'),
                    onPressed: !_answered
                        ? null
                        : () => Navigator.of(context).pop(
                            PhoneAnswer.picks({
                              for (final e in _picks.entries) e.key: e.value!,
                            }),
                          ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: Mid.fill,
                      foregroundColor: Mid.onFill,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: onest(17, weight: 600),
                    ),
                    child: Text(t.phoneAskSave),
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

/// One computer deleted it and the other changed it: no way to say which is
/// meant, so it is asked with nothing chosen.
bool _doubtful(Ask ask) => ask.mine.deleted != ask.theirs.deleted;

class _AskCard extends StatelessWidget {
  const _AskCard({
    required this.ask,
    required this.computer,
    required this.pick,
    required this.open,
    required this.onOpen,
    required this.onPick,
  });
  final Ask ask;

  /// The other computer's name, for the middle of a sentence.
  final String computer;
  final Pick? pick;
  final bool open;
  final VoidCallback onOpen;
  final ValueChanged<Pick> onPick;

  /// The lines of one version, as the person reads them: every account and
  /// its amount, and what differs from the other versions in the date and
  /// payee (what all say alike is in the heading).
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
    if (side.deleted) return [t.ledgerRowsDeleted];
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

  Widget _version(BuildContext context, String who, AskSide side) {
    final t = context.t;
    final at = side.changedAtMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(side.changedAtMs!);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(who, style: onest(12, color: Mid.ink3)),
          for (final line in _say(context, side))
            Text(line, style: onest(14, color: Mid.ink2, tabular: true)),
          if (at != null)
            Text(
              t.phoneAskChanged(
                '${fullDate(at)} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
              ),
              style: onest(12, color: Mid.ink3, tabular: true),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final String heading;
    String? under;
    if (ask.kind == AskKind.assigned) {
      heading = t.ledgerRowsAssigned(
        ask.category ?? '',
        ask.date == null ? '' : shortDate(DateTime.parse(ask.date!)),
      );
    } else {
      final sides = [ask.mine, ask.theirs, ask.neither];
      heading =
          sides.map((s) => s.payee).nonNulls.firstOrNull ?? t.ledgerRowsNoPayee;
      final date = sides.map((s) => s.date).nonNulls.firstOrNull;
      under = date == null ? null : fullDate(DateTime.parse(date));
    }
    final keeping = switch (pick) {
      null => t.phoneAskChoose,
      Pick.mine =>
        ask.mine.deleted ? t.phoneAskKeepingMineDeleted : t.phoneAskKeepingMine,
      Pick.theirs =>
        ask.theirs.deleted
            ? t.phoneAskKeepingTheirsDeleted(computer)
            : t.phoneAskKeepingTheirs(computer),
      Pick.neither => t.phoneAskKeepingNeither,
    };
    Widget way(Key key, String label, Pick p) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton(
        key: key,
        onPressed: () => onPick(p),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: Mid.ink,
          backgroundColor: Mid.card,
          side: BorderSide(
            color: pick == p ? Mid.blue : Mid.rule,
            width: pick == p ? 2 : 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: onest(15),
        ),
        child: Text(label),
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Mid.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: open ? Mid.blue : Mid.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(heading, style: onest(15, weight: 600)),
                    if (under != null)
                      Text(
                        under,
                        style: onest(12.5, color: Mid.ink3, tabular: true),
                      ),
                    const SizedBox(height: 2),
                    _version(context, t.phoneAskThisPhone, ask.mine),
                    _version(context, computer, ask.theirs),
                    const SizedBox(height: 6),
                    Text(keeping, style: onest(14, weight: 600)),
                    if (ask.hasBase)
                      Text(
                        t.ledgerRowsAsItWas(
                          _say(context, ask.neither).join(' · '),
                        ),
                        style: onest(12.5, color: Mid.ink3, tabular: true),
                      ),
                  ],
                ),
              ),
              if (!open)
                OutlinedButton(
                  key: ValueKey('ask-${ask.id}-change'),
                  onPressed: onOpen,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 44),
                    foregroundColor: Mid.blue,
                    side: BorderSide(color: Mid.blue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: onest(14, weight: 600),
                  ),
                  child: Text(t.phoneAskChange),
                ),
            ],
          ),
          if (open) ...[
            way(
              ValueKey('ask-${ask.id}-mine'),
              ask.mine.deleted ? t.phoneAskKeepMineDeleted : t.phoneAskKeepMine,
              Pick.mine,
            ),
            way(
              ValueKey('ask-${ask.id}-theirs'),
              ask.theirs.deleted
                  ? t.ledgerRowsKeepDeletedTheirs(computer)
                  : t.ledgerRowsKeepTheirs(computer),
              Pick.theirs,
            ),
            if (ask.hasBase)
              way(
                ValueKey('ask-${ask.id}-neither'),
                t.ledgerRowsKeepNeither,
                Pick.neither,
              ),
          ],
        ],
      ),
    );
  }
}

/// Two ledgers that can't be put together: the phone keeps no whole ledger
/// to write to the folder, so the one choice is to take the folder's, said
/// with what would go.
class _ApartPage extends StatelessWidget {
  const _ApartPage({required this.asking});
  final PhoneAsking asking;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      backgroundColor: Mid.ground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.phoneApartTitle,
                style: onest(24, weight: 600, height: 1.25),
              ),
              const SizedBox(height: 12),
              Text(
                asking.otherChanges == 0
                    ? t.phoneApartBody(asking.notOnComputer)
                    : asking.notOnComputer == 0
                    ? t.phoneApartBodyOther
                    : t.phoneApartBodyMore(asking.notOnComputer),
                style: onest(16, color: Mid.ink2, height: 1.4),
              ),
              const SizedBox(height: 28),
              OutlinedButton(
                key: const ValueKey('apart-keep-folder'),
                onPressed: () =>
                    Navigator.of(context).pop(const PhoneAnswer.keepFolder()),
                style: _equalWay,
                child: Text(t.phoneApartKeepFolder),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                key: const ValueKey('apart-not-now'),
                onPressed: () => Navigator.of(context).pop(),
                style: _equalWay,
                child: Text(t.ledgerTwoNotNow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The computer's question of two ledgers gives its buttons the same weight,
/// none filled (owner, 2026-11-20: "What do the desktop versions do?").
final _equalWay = OutlinedButton.styleFrom(
  minimumSize: const Size.fromHeight(52),
  foregroundColor: Mid.ink,
  side: BorderSide(color: Mid.rule),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: onest(16),
);
