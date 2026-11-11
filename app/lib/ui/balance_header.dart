import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/forecast.dart';
import '../domain/ledger.dart';
import '../domain/money.dart';
import 'data_words.dart';
import 'language.dart';
import 'entry_row.dart' show Calendar;
import 'register.dart' show BarButton, Hoverable;
import 'theme.dart';

class BalanceHeader extends StatelessWidget {
  const BalanceHeader({
    super.key,
    required this.summary,
    required this.forecast,
    required this.hoveredStatus,
    required this.activeStatus,
    required this.onStatusTap,
    required this.onOpenScheduled,
    required this.onReconcile,
    this.reconcile,
    this.owed = false,
    this.onAddPay,
    this.span = ForecastSpan.payPeriod,
    this.payPeriodEnd,
    this.customEnd,
    this.onSpan,
    this.onCustomEnd,
    this.shortAhead,
    this.onShowShort,
    this.budgeted = false,
    this.maybePaid = 0,
    this.onShowMaybePaid,
  });

  /// No payday ahead: the forecast offers to put pay in.
  final VoidCallback? onAddPay;

  /// How far the forecast looks, the date a pay-period forecast would run
  /// to (null with no payday ahead here), and the choice being changed.
  final ForecastSpan span;
  final DateTime? payPeriodEnd;

  /// The day Custom… runs to, and a day being picked for it (#397).
  final DateTime? customEnd;
  final ValueChanged<ForecastSpan>? onSpan;
  final ValueChanged<DateTime>? onCustomEnd;

  /// The balance goes to zero or below past what the forecast shows: the
  /// day and how low. A coral line above the forecast says so; a click
  /// looks that far.
  final ({DateTime date, int low})? shortAhead;
  final VoidCallback? onShowShort;

  /// A credit account: every amount here is what's owed, positive.
  final bool owed;

  /// Bills here a row already in may have paid, still counted until the
  /// person says (ADR 0004, "A bill paid another way"), and the click that
  /// shows the first.
  final int maybePaid;
  final VoidCallback? onShowMaybePaid;

  /// Some category has a plan or an amount assigned.
  final bool budgeted;

  /// Shown in place of the balance sum while reconciling.
  final Widget? reconcile;
  final VoidCallback? onReconcile;

  /// A forecast dot was clicked: show that scheduled transaction.
  /// Null while a reconcile is open: the register hides scheduled rows
  /// then, so the forecast offers no clicks into them (#395).
  final ValueChanged<RegisterRow>? onOpenScheduled;
  final AccountSummary summary;
  final Forecast forecast;

  /// Shared with the register: hovering a line here lights up matching rows,
  /// hovering a row's symbol lights up its line here.
  final ValueNotifier<Cleared?> hoveredStatus;
  final Cleared? activeStatus;
  final ValueChanged<Cleared> onStatusTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 22, 32, 20),
      // Lit from its top-left corner and lifted off the page: the header is
      // the page's one answer, so it is the one card that stands forward
      // (owner, 2026-11-10: "Can you make it pop?").
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: const Alignment(0.4, 1),
          colors: [Color.lerp(Mid.card, Mid.raised, 0.55)!, Mid.card],
          stops: const [0, 0.6],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Mid.rule),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: Mid.isLight ? 0.08 : 0.30),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The balances take the width their own figures need; the chart
            // takes everything left (owner, 2026-11-08). Pinned at 440 it
            // sat against the right edge with dead space in the middle, and
            // a wide window bought the chart nothing.
            // A reconcile keeps its half; the balances are only as wide as
            // their figures. As a `Flexible` the balances were offered half
            // the card and the half they didn't use went to nobody.
            if (reconcile case final r?)
              Flexible(child: r)
            else
              _Balances(
                s: summary,
                owed: owed,
                hovered: hoveredStatus,
                active: activeStatus,
                onTap: onStatusTap,
                onReconcile: onReconcile,
              ),
            // No rule between them: the line begins beside the Working
            // figure, and a wall stood exactly where now meets ahead.
            const SizedBox(width: 44),
            Expanded(
              child: ForecastPanel(
                forecast,
                onOpen: onOpenScheduled,
                onAddPay: onAddPay,
                span: span,
                payPeriodEnd: payPeriodEnd,
                customEnd: customEnd,
                onSpan: onSpan,
                onCustomEnd: onCustomEnd,
                shortAhead: shortAhead,
                onShowShort: onShowShort,
                budgeted: budgeted,
                maybePaid: maybePaid,
                onShowMaybePaid: onShowMaybePaid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Balances extends StatelessWidget {
  const _Balances({
    required this.s,
    required this.hovered,
    required this.active,
    required this.onTap,
    required this.onReconcile,
    required this.owed,
  });

  final AccountSummary s;
  final bool owed;
  final VoidCallback? onReconcile;
  final ValueNotifier<Cleared?> hovered;
  final Cleared? active;
  final ValueChanged<Cleared> onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    int shown(int v) => owed ? -v : v;
    Widget reconciled() => Row(
      // Only as wide as it is: the chart takes the rest of the card.
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cash has no statement to be checked against, so neither
        // the line nor the button means anything on a wallet.
        if (onReconcile case final reconcile?) ...[
          _StatusLine(
            status: Cleared.reconciled,
            amount: null,
            // When matters here, not how much: no amount column.
            label: s.reconciledOn == null
                ? t.planNeverReconciled
                : t.planLastReconciled(sayDate(t, s.reconciledOn!)),
            note: '',
            hovered: hovered,
            active: active == Cleared.reconciled,
            onTap: () => onTap(Cleared.reconciled),
          ),
          BarButton(
            key: const ValueKey('reconcile'),
            label: t.planReconcile,
            onTap: reconcile,
          ),
        ],
      ],
    );
    // The answer first and biggest, its two parts hung under it, and
    // Reconcile on the card's foot (owner, 2026-11-10, sketch D). It was a
    // receipt to decode: Cleared, Uncleared, a rule, and the figure people
    // came for third. The parts still double as the key to the register's
    // symbols.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TotalLine(amount: shown(s.working), owed: owed),
            const SizedBox(height: 8),
            _StatusLine(
              status: Cleared.cleared,
              amount: shown(s.cleared),
              note: '',
              hovered: hovered,
              active: active == Cleared.cleared,
              onTap: () => onTap(Cleared.cleared),
            ),
            // No "2 not cleared yet" beside it: the Uncleared (2) button
            // under the header holds the count.
            _StatusLine(
              status: Cleared.uncleared,
              amount: shown(s.uncleared),
              signed: true,
              note: '',
              hovered: hovered,
              active: active == Cleared.uncleared,
              onTap: () => onTap(Cleared.uncleared),
            ),
          ],
        ),
        Padding(padding: const EdgeInsets.only(top: 10), child: reconciled()),
      ],
    );
  }
}

/// One line of the balance sum: symbol, name, amount, meaning. Amounts are
/// right-aligned with their sign, so the lines add up like a receipt.
class _Line extends StatelessWidget {
  const _Line({
    required this.glyph,
    required this.label,
    required this.amount,
    required this.note,
    required this.lit,
    this.signed = false,
  });

  static const _glyph = 16.0, _gap = 6.0, _amount = 200.0;

  /// The names column: "Баталгаажсан" and "Хүлээгдэж буй" need more room
  /// than "Uncleared" to stay on one line.
  static double _label(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'mn' ? 112 : 84;

  /// Where the amount column sits, for the rule drawn above the total.
  static double amountLeft(BuildContext context) =>
      _glyph + _gap + _label(context);
  static const amountWidth = _amount;

  final Widget glyph;
  final String label;
  final int? amount;
  final String note;
  final bool lit;

  /// Show `+` on positive amounts too (the uncleared line can go either way).
  final bool signed;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: _glyph,
        child: Center(child: glyph),
      ),
      const SizedBox(width: _gap),
      SizedBox(
        width: _label(context),
        child: Text(label, style: onest(13, color: lit ? Mid.ink : Mid.ink3)),
      ),
      SizedBox(
        width: _amount,
        child: Align(
          alignment: Alignment.centerRight,
          child: amount == null
              ? Text('—', style: onest(13, color: Mid.ink3))
              : Money(
                  amount!,
                  size: 13,
                  color: Mid.ink,
                  centsColor: Mid.ink,
                  sign: signed
                      ? MoneySign.plusForPositive
                      : MoneySign.negativeOnly,
                ),
        ),
      ),
      const SizedBox(width: 24),
      Flexible(
        child: Text(
          note,
          style: onest(13, color: lit ? Mid.ink2 : Mid.ink3),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

/// The answer to the sum: the working balance, and the header's one big number.
class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.amount, required this.owed});
  final int amount;

  /// "Owed" instead of "Working", and never coral: owing on a card is normal.
  final bool owed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _Line.amountLeft(context) + _Line.amountWidth,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          owed ? context.t.planOwed : context.t.planWorking,
          style: onest(13, weight: 500, color: Mid.ink2),
        ),
        // A balance in the hundreds of millions gets smaller, not cut.
        Shrink(
          Money(
            amount,
            size: 42,
            weight: 600,
            letterSpacing: -1.2,
            centsScale: 0.5,
            color: !owed && amount < 0 ? Mid.coral : Mid.ink,
          ),
        ),
      ],
    ),
  );
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.status,
    required this.amount,
    required this.note,
    required this.hovered,
    required this.active,
    required this.onTap,
    this.signed = false,
    this.label,
  });

  final Cleared status;
  final bool signed;

  /// Replaces the name-and-amount columns with one line of text.
  final String? label;
  final int? amount;
  final String note;
  final ValueNotifier<Cleared?> hovered;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Cleared?>(
      valueListenable: hovered,
      builder: (context, h, _) {
        final lit = h == status || active;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => hovered.value = status,
          onExit: (_) {
            if (hovered.value == status) hovered.value = null;
          },
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              transform: Matrix4.translationValues(-10, 0, 0),
              padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
              decoration: BoxDecoration(
                color: lit ? Mid.raised : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: label != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: _Line._glyph,
                          child: Center(child: StatusGlyph(status)),
                        ),
                        const SizedBox(width: _Line._gap),
                        Text(
                          label!,
                          style: onest(13, color: lit ? Mid.ink : Mid.ink3),
                        ),
                      ],
                    )
                  : _Line(
                      signed: signed,
                      glyph: StatusGlyph(
                        status,
                        color: lit && status == Cleared.cleared
                            ? Mid.ink
                            : null,
                      ),
                      label: clearedName(context.t, status),
                      amount: amount,
                      note: note,
                      lit: lit,
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// "· ₮2,500,000 2 days late · not counted": money in the forecast leaves
/// out until it's confirmed. The amount, not a name: it says whether the
/// warning would clear if the money came, and names can be any length.
/// Clicking it opens that row (the first, when several), like a dot, since
/// confirming it is how it gets counted.
class _LateNote extends StatelessWidget {
  const _LateNote({
    required this.late,
    required this.today,
    required this.onOpen,
  });
  final List<RegisterRow> late;
  final DateTime today;
  final ValueChanged<RegisterRow>? onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final total = roundedIn(
      context,
      late.fold(0, (s, r) => s + r.amount).abs(),
    );
    // "+… in" says which way it goes: late bills are written the same way.
    final String what;
    if (late.length > 1) {
      what = t.planLateSeveral(total, late.length);
    } else {
      final days = daysBefore(late.single.date, today);
      what = days == 0 ? t.planLateToday(total) : t.planLateDays(total, days);
    }
    final open = onOpen;
    return Hoverable(
      key: const ValueKey('forecast-late'),
      onTap: open == null ? null : () => open(late.first),
      builder: (h) {
        final style = onest(12, color: Mid.ink, tabular: true).copyWith(
          decoration: h && open != null ? TextDecoration.underline : null,
          decorationColor: Mid.ink,
        );
        // Only the amount part shrinks: "not counted" explains the warning.
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // No leading "·": the note trailed the span control on one row
            // before, and now stands on a line of its own.
            Flexible(
              child: Text(
                what,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(t.planLateNotCounted, style: style, maxLines: 1),
          ],
        );
      },
    );
  }
}

/// A bill's name in the list and on a dot: the payee, or for a transfer
/// which way it goes.
String _payeeText(Words t, RegisterRow r) => r.kind != RowKind.transfer
    ? rowPayee(t, r)
    : r.amount < 0
    ? t.planTransferTo(rowPayee(t, r))
    : t.planTransferFrom(rowPayee(t, r));

/// The header's one chart. It exists to warn: most days it is quiet.
class ForecastPanel extends StatelessWidget {
  const ForecastPanel(
    this.f, {
    super.key,
    required this.onOpen,
    this.onAddPay,
    this.span = ForecastSpan.payPeriod,
    this.payPeriodEnd,
    this.customEnd,
    this.onSpan,
    this.onCustomEnd,
    this.shortAhead,
    this.onShowShort,
    this.budgeted = false,
    this.maybePaid = 0,
    this.onShowMaybePaid,
  });
  final Forecast f;

  /// Null while a reconcile is open. The chart and the bill list still
  /// read; nothing offers a click that has nowhere to go (#395).
  final ValueChanged<RegisterRow>? onOpen;
  final VoidCallback? onAddPay;

  /// Some category has a plan or an amount assigned: with no bills here
  /// even so, "Nothing has been budgeted" would be wrong, and the line
  /// above already says there are none.
  final bool budgeted;

  /// Past this view, the balance goes to zero or below: said in coral above
  /// the title, and a click looks that far (owner, 2026-10-05: "if at any
  /// point in the paychecks tracked for that account, the balance drops to
  /// or below zero, we need to let the user know").
  final ({DateTime date, int low})? shortAhead;
  final VoidCallback? onShowShort;

  /// Bills a row already in may have paid: counted until the person says,
  /// so a line says so, and a click shows the first.
  final int maybePaid;
  final VoidCallback? onShowMaybePaid;

  /// How far it looks (owner's request, 2026-10-05): the small title is
  /// the control. [payPeriodEnd] names the pay-period choice by its date;
  /// without one, that choice isn't offered here.
  final ForecastSpan span;
  final DateTime? payPeriodEnd;

  /// The day Custom… runs to; null until a day is picked, or once the day
  /// picked has gone by.
  final DateTime? customEnd;
  final ValueChanged<ForecastSpan>? onSpan;
  final ValueChanged<DateTime>? onCustomEnd;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final payday = f.payday;
    String money(int v) => roundedIn(context, v.abs());
    final String headline;
    String detail;
    if (f.owed) {
      // A card: what will be owed once scheduled charges and payments land.
      final payments = f.rowSteps.where((s) => s.row.amount > 0).length;
      final bal = f.endBalance;
      // The budget's spending on the card counts too (#179).
      headline = f.steps.isEmpty
          ? t.planNothingScheduled
          : bal < 0
          ? t.planCreditAfter(money(bal), sayDate(t, f.steps.last.date))
          : t.planOwedAfterDate(money(bal), sayDate(t, f.steps.last.date));
      final end = sayDate(t, f.end);
      detail = f.rowSteps.isEmpty && f.spendingTotal == 0
          ? t.planCardNothing
          : f.rowSteps.isEmpty
          ? t.planNoBillsBefore(end)
          : f.billCount > 0 && payments > 0
          ? t.planCardChargesPayments(
              f.billCount,
              money(f.billTotal),
              payments,
              money(f.inTotal),
              end,
            )
          : f.billCount > 0
          ? t.planCardCharges(f.billCount, money(f.billTotal), end)
          : t.planCardPayments(payments, money(f.inTotal), end);
    } else {
      // Money due today that hasn't landed: on payday the warning is
      // conditional, not news.
      final dueToday = f.late
          .where((r) => !r.date.isBefore(f.start))
          .fold(0, (s, r) => s + r.amount);
      final unless = dueToday > 0 ? money(dueToday) : null;
      if (f.shortNow) {
        // Already under: say so, not a future "runs out" date. The amount is
        // the Working total beside it, so it isn't repeated.
        headline = unless != null
            ? t.planBelowZeroUnless(unless)
            : f.low < f.startBalance
            ? t.planBelowZeroShort(money(f.low))
            : t.planBelowZeroNow;
      } else if (f.isShort) {
        final on = sayDate(t, f.firstShort!);
        headline = unless != null
            ? t.planRunsOutUnless(on, unless)
            : f.low == 0
            ? t.planRunsOutZero(on)
            : t.planRunsOut(on, money(f.low));
      } else if (f.takeOutBy case final by?) {
        // Cash the budget's spending would take below zero: filled from
        // the bank, said in ordinary ink (owner, 2026-10-28).
        headline = t.planTakeOut(money(f.takeOut), sayDate(t, by));
      } else if (f.steps.isEmpty) {
        // The budget's spending lowers the line too (#179).
        headline = t.planNothingScheduled;
      } else if (f.low >= f.startBalance) {
        headline = t.planLowestToday(money(f.startBalance));
      } else if (f.paydayCounted &&
          f.lowDate.isAfter(
            f.rowSteps.firstWhere((s) => identical(s.row, payday)).date,
          )) {
        // That low leans on the paycheck coming on time, in full.
        headline = t.planLowestAfterPay(money(f.low), sayDate(t, f.lowDate));
      } else {
        headline = t.planLowest(money(f.low), sayDate(t, f.lowDate));
      }
      // No payee names here: they can be any length. The count opens the list.
      // Money moved in from another account, refunds: they lift the line.
      final end = sayDate(t, f.end);
      detail = f.rowSteps.isEmpty
          ? payday == null
                ? t.planNoBillsOrIncome
                : t.planNoBillsBefore(end)
          // Through a pay period the paycheck is a step, not "money in".
          : f.billCount == 0 && f.inTotal == 0
          ? t.planNoBillsBefore(end)
          : f.billCount == 0
          ? t.planInBefore(money(f.inTotal), end)
          : f.inTotal > 0
          ? t.planBillsBeforeIn(
              f.billCount,
              money(f.billTotal),
              end,
              money(f.inTotal),
            )
          : t.planBillsBefore(f.billCount, money(f.billTotal), end);
    }
    // The budget's spending used to be a tail glued onto this line, as did
    // "N of them expected". Both are gone: the tooltip's "if the budget is
    // followed" covers the first, and the bill list's own rows say which are
    // expected (ADR 0004, "The forecast's chart does the talking").

    // Late money in, named so a warning without it makes sense.
    final late = f.late;
    // Pay is known but no bills are: a chart would be a flat line with a
    // jump, meaning nothing to someone new. Say what's known in words, and
    // what to add for the forecast to be worth something.
    final knownOnly =
        !f.owed &&
        payday != null &&
        f.billCount == 0 &&
        f.spendingTotal == 0 &&
        !f.shortNow &&
        (f.paydayCounted || f.heldBack.isNotEmpty);
    // The key to the rail: what each tick is, counted on its own side with
    // its own sign. "4 bills" alone was wrong once the income had a tick
    // (owner, 2026-11-08).
    // Money moved between the person's own accounts is its own kind, named
    // by the word the register already puts on that row (owner, 2026-11-09:
    // "Money In / Money Out / Transfer"). The sign says which way it went,
    // as it does everywhere else, and each part shows only while there is
    // something for it. No counts: "4 money out" is not English, and the
    // rail's ticks are countable where they stand.
    final rail = <(_Part?, String)>[
      if (f.billTotal > 0) (_Part.out, t.planRailOut(money(f.billTotal))),
      // What the budget plans to spend. It has no tick, because it has no
      // date: it is the band between the line and the dashed one above it.
      // Without it the card's own arithmetic stopped tying — the line ended
      // below what the bills and the income came to, and nothing on the
      // card accounted for the difference (#398).
      if (f.spendingTotal > 0)
        (_Part.spend, t.planRailSpend(money(f.spendingTotal))),
      if (f.moveOut > 0) (_Part.out, t.planRailMoveOut(money(f.moveOut))),
      if (f.moveIn > 0) (_Part.income, t.planRailMoveIn(money(f.moveIn))),
      if (f.rowSteps.any(
        (s) => s.row.amount > 0 && s.row.kind != RowKind.transfer,
      ))
        (
          _Part.income,
          t.planRailIn(
            money(
              f.rowSteps
                  .where(
                    (s) => s.row.amount > 0 && s.row.kind != RowKind.transfer,
                  )
                  .fold(0, (a, s) => a + s.row.amount),
            ),
          ),
        ),
    ];
    // Words only for what the chart cannot show (owner, 2026-11-08: "I don't
    // need you to use language so much. Use the chart to explain"). With a
    // chart to read, the figures sit at their own points: the dip carries
    // its own figure and the line goes coral where it crosses ₮0, so a
    // headline would only say them again. Four things no line can draw keep
    // theirs: nothing scheduled at all, a wallet that has to be filled from
    // the bank, what a card is owed (the chart's figure can't say "owed"),
    // and a shortfall that only happens if money due today never arrives.
    final sayIt =
        f.steps.isEmpty ||
        f.takeOutBy != null ||
        f.owed ||
        f.late.any((r) => !r.date.isBefore(f.start) && r.amount > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Trouble past this view, said before anything else.
        if (shortAhead case final s?) ...[
          Hoverable(
            key: const ValueKey('forecast-short-ahead'),
            onTap: onShowShort,
            builder: (hover) => Tooltip(
              message: t.planShortAheadTip(sayDate(t, s.date)),
              waitDuration: const Duration(milliseconds: 500),
              child: Text(
                s.low == 0
                    ? t.planShortAheadZero(
                        sayDate(t, f.end),
                        sayDate(t, s.date),
                      )
                    : t.planShortAhead(
                        sayDate(t, f.end),
                        sayDate(t, s.date),
                        money(s.low),
                      ),
                // Wraps rather than cut the amount short.
                style: onest(12.5, color: Mid.coral, tabular: true).copyWith(
                  decoration: hover && onShowShort != null
                      ? TextDecoration.underline
                      : null,
                  decorationColor: Mid.coral,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        // A bill counted that may be paid already: a shortfall may not be.
        if (maybePaid > 0) ...[
          Hoverable(
            key: const ValueKey('forecast-maybe-paid'),
            onTap: onShowMaybePaid,
            builder: (hover) => Text(
              t.forecastMaybePaid(maybePaid),
              style: onest(12.5, color: Mid.ink2).copyWith(
                decoration: hover && onShowMaybePaid != null
                    ? TextDecoration.underline
                    : null,
                decorationColor: Mid.ink2,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        // The card's name and how far it looks share one row: two titles
        // were one too many, and the control sat above the figures it only
        // qualifies. "Until your income on 12.01" is gone with the dropdown
        // — the filled button says which length, and the date under the
        // chart's end says where it stops.
        Row(
          key: const ValueKey('forecast-horizon'),
          children: [
            Text(
              t.planForecast,
              key: const ValueKey('forecast-title'),
              style: onest(12.5, color: Mid.ink3),
            ),
            const SizedBox(width: 6),
            _WhatIsIt(hasBand: f.spendingTotal > 0),
            const SizedBox(width: 10),
            // Mongolian's words for these are longer, and the card narrows
            // with the window: the row of buttons shrinks rather than
            // overflow or drop one.
            Expanded(
              child: _SpanChoice(
                span: span,
                payPeriodEnd: payPeriodEnd,
                today: f.start,
                customEnd: customEnd,
                onSpan: onSpan,
                onCustomEnd: onCustomEnd,
              ),
            ),
          ],
        ),
        if (late.isNotEmpty) ...[
          const SizedBox(height: 4),
          _LateNote(late: late, today: f.start, onOpen: onOpen),
        ]
        // Nothing to run to: the forecast can't say "until payday", so it
        // asks for pay, every time, until it has some.
        else if (!f.owed && payday == null && onAddPay != null) ...[
          const SizedBox(height: 4),
          Hoverable(
            key: const ValueKey('add-pay'),
            onTap: onAddPay,
            builder: (hover) => Text(
              t.planAddPay,
              style: onest(12, color: Mid.blue).copyWith(
                decoration: hover ? TextDecoration.underline : null,
                decorationColor: Mid.blue,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        if (knownOnly) ...[
          const SizedBox(height: 8),
          Expanded(
            child: _KnownList(f: f, onOpen: onOpen, budgeted: budgeted),
          ),
        ] else ...[
          if (sayIt) ...[
            const SizedBox(height: 4),
            // An amount and a date: smaller rather than cut.
            Shrink(
              Text(
                headline,
                style: onest(
                  18,
                  weight: 500,
                  color: f.isShort ? Mid.coral : Mid.ink,
                  tabular: true,
                ),
                maxLines: 1,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Expanded(
            child: _ForecastBody(
              f: f,
              onOpen: onOpen,
              detail: detail,
              // A credit account keeps its own words: there a bill is a
              // charge and money in is a payment, and the signs run the
              // other way, so the key's "Money out −₮…" would read backwards.
              parts: f.owed || rail.isEmpty ? [(null, detail)] : rail,
            ),
          ),
        ],
      ],
    );
  }
}

/// The three things a forecast is made of, as the key names them and the
/// chart draws them: dated money out (ticks under the rail), the budget's
/// day-to-day spending (the band), and money in (green ticks).
enum _Part { out, spend, income }

/// The key and the chart it explains. They share which part the pointer is
/// on, so pointing at a word in the key lights up its marks on the chart
/// (owner, 2026-11-10, sketch D: "interactive").
class _ForecastBody extends StatefulWidget {
  const _ForecastBody({
    required this.f,
    required this.onOpen,
    required this.detail,
    required this.parts,
  });
  final Forecast f;
  final ValueChanged<RegisterRow>? onOpen;
  final String detail;
  final List<(_Part?, String)> parts;

  @override
  State<_ForecastBody> createState() => _ForecastBodyState();
}

class _ForecastBodyState extends State<_ForecastBody> {
  final _lit = ValueNotifier<_Part?>(null);

  @override
  void didUpdateWidget(_ForecastBody old) {
    super.didUpdateWidget(old);
    // A chip that goes away under the pointer never hears it leave, and
    // its part would stay lit on the next chart.
    if (_lit.value != null && !widget.parts.any((p) => p.$1 == _lit.value)) {
      _lit.value = null;
    }
  }

  @override
  void dispose() {
    _lit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.f;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (f.rowSteps.isEmpty)
          Text(widget.detail, style: onest(13, color: Mid.ink3, tabular: true))
        else
          _BillsLink(
            parts: widget.parts,
            f: f,
            onOpen: widget.onOpen,
            lit: _lit,
          ),
        const SizedBox(height: 10),
        Expanded(
          child: ConstrainedBox(
            // The chart is what the card says now, so it sets the header's
            // height rather than taking what the balances beside it leave.
            // Not higher than this: the header would take a row off the
            // register, which is the page's real work.
            constraints: const BoxConstraints(minHeight: 132),
            child: _ForecastChart(f: f, onOpen: widget.onOpen, lit: _lit),
          ),
        ),
      ],
    );
  }
}

/// One word of the key: a sample of its mark, then its name and figure.
/// The sample is what makes a key a key; without it the line read as a
/// sentence with a link under it.
class _KeyChip extends StatelessWidget {
  const _KeyChip({required this.kind, required this.text, required this.lit});
  final _Part? kind;
  final String text;
  final ValueNotifier<_Part?> lit;

  @override
  Widget build(BuildContext context) {
    final kind = this.kind;
    final chip = ValueListenableBuilder<_Part?>(
      valueListenable: lit,
      builder: (context, on, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: kind != null && on == kind
              ? Mid.rowHover.withValues(alpha: 0.16)
              : Mid.chip,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Mid.rule),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kind == _Part.spend)
              Container(
                width: 11,
                height: 8,
                decoration: BoxDecoration(
                  color: Mid.ink3.withValues(alpha: 0.4),
                  border: Border(top: BorderSide(color: Mid.ink3, width: 1.2)),
                ),
              )
            else if (kind != null)
              Container(
                width: 2.8,
                height: 10,
                decoration: BoxDecoration(
                  color: kind == _Part.income ? Mid.green : Mid.ink2,
                  borderRadius: BorderRadius.circular(1.4),
                ),
              ),
            if (kind != null) const SizedBox(width: 7),
            Text(
              text,
              maxLines: 1,
              style: onest(12.5, weight: 500, color: Mid.ink, tabular: true),
            ),
          ],
        ),
      ),
    );
    if (kind == null) return chip;
    return MouseRegion(
      onEnter: (_) => lit.value = kind,
      onExit: (_) {
        if (lit.value == kind) lit.value = null;
      },
      child: chip,
    );
  }
}

/// How far ahead the forecast looks. A row of buttons, not a dropdown
/// (owner, 2026-11-08: "Let's also make the forecast time range a little
/// more standard. I don't think a dropdown makes sense here"), the one
/// you're on filled. No colors: these are lengths of time, not kinds of
/// thing, so a color each would be noise.
class _SpanChoice extends StatefulWidget {
  const _SpanChoice({
    required this.span,
    required this.payPeriodEnd,
    required this.today,
    required this.customEnd,
    required this.onSpan,
    required this.onCustomEnd,
  });
  final ForecastSpan span;
  final DateTime? payPeriodEnd;

  /// The day the forecast starts from, which the calendar opens on.
  final DateTime today;

  /// The day Custom… runs to, once one is picked (#397).
  final DateTime? customEnd;
  final ValueChanged<ForecastSpan>? onSpan;
  final ValueChanged<DateTime>? onCustomEnd;

  @override
  State<_SpanChoice> createState() => _SpanChoiceState();

  /// 60 days and 6 months went with the dropdown (owner, 2026-11-08). Their
  /// [ForecastSpan] values and words stay, so a ledger already set to one
  /// still reads and still draws.
  static const _offered = [
    ForecastSpan.payPeriod,
    ForecastSpan.days30,
    ForecastSpan.days90,
    ForecastSpan.year,
    ForecastSpan.custom,
  ];

  static String nameOf(Words t, ForecastSpan s) => switch (s) {
    ForecastSpan.payPeriod => t.planSpanToIncome,
    ForecastSpan.days30 => t.planSpanDays(30),
    ForecastSpan.days60 => t.planSpanDays(60),
    ForecastSpan.days90 => t.planSpanDays(90),
    ForecastSpan.months6 => t.planSpanMonths(6),
    ForecastSpan.year => t.planSpanYear,
    ForecastSpan.custom => t.planSpanCustom,
  };

  /// A day picked says the date itself, so the filled button still names
  /// the range that is drawn. `2027.03.14`, the convention every row's
  /// date already uses, and the same length in both languages: a month
  /// spelled out would push the row of buttons off the card.
  static String customName(Words t, DateTime? end) =>
      end == null ? t.planSpanCustom : fullDate(end);
}

class _SpanChoiceState extends State<_SpanChoice> {
  /// The calendar hangs off the whole row, not off the button inside it:
  /// Mongolian's longer words shrink this row, and a follower inside that
  /// shrink is drawn scaled down with it.
  final _link = LayerLink();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final span = widget.span;
    final payPeriodEnd = widget.payPeriodEnd;
    final customEnd = widget.customEnd;
    final onSpan = widget.onSpan;
    if (onSpan == null) {
      return Text(
        span == ForecastSpan.custom
            ? _SpanChoice.customName(t, customEnd)
            : _SpanChoice.nameOf(t, span),
        style: onest(12, color: Mid.ink3),
      );
    }
    // The pay period needs a payday ahead in this account to run to; without
    // one, the fixed lengths are what's offered. A ledger left on a length
    // that is no longer offered keeps its own button until it's changed, so
    // nothing a person chose disappears under them.
    // With no payday ahead — every card, wallet and savings account, and a
    // new ledger — the pay-period button has nothing to run to, and the
    // forecast falls back to 30 days. Fill that one, so the row always says
    // which length is drawn instead of showing none chosen. A picked day
    // that has since gone by falls back the same way.
    final chosen =
        (span == ForecastSpan.payPeriod && payPeriodEnd == null) ||
            (span == ForecastSpan.custom && customEnd == null)
        ? ForecastSpan.days30
        : span;
    final shown = <ForecastSpan>{
      for (final s in _SpanChoice._offered)
        if (s != ForecastSpan.payPeriod || payPeriodEnd != null) s,
      chosen,
    }.toList()..sort((a, b) => a.index.compareTo(b.index));
    // An inset track with the chosen one raised out of it. By day the card
    // is white, so the track is the page's grey and the chosen chip white;
    // at night the card is lifted off a darker page, so they swap.
    return CompositedTransformTarget(
      link: _link,
      child: Shrink(end: true, _row(t, chosen, shown, onSpan)),
    );
  }

  Widget _row(
    Words t,
    ForecastSpan chosen,
    List<ForecastSpan> shown,
    ValueChanged<ForecastSpan> onSpan,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Mid.isLight ? Mid.raised : Mid.panel,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in shown)
              if (s == ForecastSpan.custom)
                _CustomSpan(
                  key: const ValueKey('forecast-span-custom-slot'),
                  link: _link,
                  chosen: chosen == ForecastSpan.custom,
                  today: widget.today,
                  end: widget.customEnd,
                  onPick: widget.onCustomEnd,
                  onBack: () => onSpan(ForecastSpan.custom),
                )
              else
                _SpanChip(
                  name: s.name,
                  label: _SpanChoice.nameOf(t, s),
                  chosen: s == chosen,
                  onTap: () => onSpan(s),
                ),
          ],
        ),
      ),
    );
  }
}

/// One length in the row. The chosen one is raised out of the track, in
/// the page's ink; the rest are quieter and light up under the mouse.
class _SpanChip extends StatelessWidget {
  const _SpanChip({
    required this.name,
    required this.label,
    required this.chosen,
    required this.onTap,
  });
  final String name, label;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Hoverable(
    key: ValueKey('forecast-span-$name'),
    onTap: onTap,
    builder: (hover) => DecoratedBox(
      decoration: BoxDecoration(
        // The one you're on is filled in the color of what you click, so
        // the range drawn is found at a glance (owner, 2026-11-10, sketch D).
        color: chosen
            ? Mid.blue
            : hover
            ? Mid.hover
            : null,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          label,
          style: onest(
            11,
            weight: chosen ? 600 : 400,
            color: chosen ? Mid.onAccent : Mid.ink3,
          ),
        ),
      ),
    ),
  );
}

/// Custom…, the last button in the row: it opens the app's calendar on
/// the day the forecast runs to, and a click on a day redraws the forecast
/// to it (owner, 2026-11-08, #397: "I want them to be able to choose a
/// date"). The presets answer a month or a year; this answers the four
/// months to Tsagaan Sar or the term's school fees, which is why there is
/// no sixth preset.
class _CustomSpan extends StatefulWidget {
  const _CustomSpan({
    super.key,
    required this.link,
    required this.chosen,
    required this.today,
    required this.end,
    required this.onPick,
    required this.onBack,
  });

  /// The row's own link: the calendar hangs off the whole row, which is
  /// outside the shrink that Mongolian's longer words can scale.
  final LayerLink link;
  final bool chosen;
  final DateTime today;
  final DateTime? end;
  final ValueChanged<DateTime>? onPick;

  /// The button already says a day, and another length is drawn: a click
  /// goes back to that day, in one click like every other button in the
  /// row, instead of making the person find it in the calendar again.
  final VoidCallback onBack;

  @override
  State<_CustomSpan> createState() => _CustomSpanState();
}

class _CustomSpanState extends State<_CustomSpan> {
  final _portal = OverlayPortalController();

  /// Where focus was before the calendar opened, so Esc and closing hand
  /// it back to the register.
  FocusNode? _returnFocus;
  final _focus = FocusNode(debugLabel: 'forecast-span-custom');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_portal.isShowing) return _close();
    _returnFocus = FocusManager.instance.primaryFocus;
    setState(_portal.show);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _close() {
    if (!_portal.isShowing) return;
    setState(_portal.hide);
    _returnFocus?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return TapRegion(
      groupId: widget.link,
      onTapOutside: (_) => _close(),
      child: OverlayPortal(
        controller: _portal,
        // Under the row and against its right end: the row sits at the
        // card's right edge, so a calendar hung from the left would
        // stand off the card.
        overlayChildBuilder: (context) => CompositedTransformFollower(
          link: widget.link,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 8),
          // The follower is handed the whole overlay's constraints, so the
          // calendar is loosened here or it stretches across the window.
          child: Align(
            alignment: Alignment.topRight,
            child: TapRegion(
              groupId: widget.link,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape): _close,
                },
                child: Focus(
                  focusNode: _focus,
                  child: Calendar(
                    key: const ValueKey('forecast-span-calendar'),
                    selected: widget.end,
                    today: widget.today,
                    // Today has nothing ahead left in it, and past two
                    // years the bills a forecast projects run out before
                    // the end does.
                    earliest: ForecastSpan.firstCustom(widget.today),
                    latest: ForecastSpan.lastCustom(widget.today),
                    // Every day here is a later one, and none of them
                    // schedules anything.
                    scheduleNote: false,
                    onPick: (d) {
                      _close();
                      widget.onPick?.call(d);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        child: Tooltip(
          message: t.planSpanCustomTip,
          waitDuration: const Duration(milliseconds: 500),
          child: _SpanChip(
            name: 'custom',
            label: _SpanChoice.customName(t, widget.end),
            chosen: widget.chosen,
            onTap: widget.end != null && !widget.chosen
                ? widget.onBack
                : _toggle,
          ),
        ),
      ),
    );
  }
}

/// What the forecast is, on an ⓘ beside the card's name: the one place on
/// the card where language lives, which is what lets the rest stay quiet.
/// The owner's own words (2026-11-08).
class _WhatIsIt extends StatefulWidget {
  const _WhatIsIt({required this.hasBand});

  /// The chart has a band for what the budget plans to spend: the sentence
  /// about it is said only while it is there to see (#398).
  final bool hasBand;

  @override
  State<_WhatIsIt> createState() => _WhatIsItState();
}

class _WhatIsItState extends State<_WhatIsIt> {
  /// The icon is a focus stop that takes the click itself, so the tooltip is
  /// opened through this rather than by its own tap trigger.
  final _tip = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final style = onest(11.5, color: Mid.ink, height: 1.45);
    return Tooltip(
      key: _tip,
      triggerMode: TooltipTriggerMode.tap,
      waitDuration: const Duration(milliseconds: 300),
      richMessage: WidgetSpan(
        child: SizedBox(
          width: 264,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Whole sentences, each its own message: Mongolian orders the
              // words inside one, never across two.
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: t.planForecastWhatOne),
                    const TextSpan(text: ' '),
                    TextSpan(text: t.planForecastWhatTwo),
                    if (widget.hasBand) ...[
                      const TextSpan(text: ' '),
                      TextSpan(text: t.planForecastWhatBand),
                    ],
                  ],
                ),
                style: style,
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: t.planForecastWhatThree),
                    const TextSpan(text: ' '),
                    TextSpan(text: t.planForecastWhatFour),
                  ],
                ),
                style: style.copyWith(color: Mid.ink2),
              ),
            ],
          ),
        ),
      ),
      // A `WidgetSpan` message reaches a screen reader as one placeholder
      // character, so the sentences go on the label itself; and the icon is
      // a real focus stop, so Tab reaches the card's only prose, as ADR 0004
      // says it should ("on hover and on focus").
      child: Semantics(
        label:
            '${t.planForecastWhatLabel}. ${t.planForecastWhatOne} '
            '${t.planForecastWhatTwo} '
            '${widget.hasBand ? '${t.planForecastWhatBand} ' : ''}'
            '${t.planForecastWhatThree} ${t.planForecastWhatFour}',
        button: true,
        excludeSemantics: true,
        child: Hoverable(
          key: const ValueKey('forecast-what'),
          onTap: () => _tip.currentState?.ensureTooltipVisible(),
          builder: (hover) => Padding(
            // A 13px glyph is a small thing to hit with a mouse alone.
            padding: const EdgeInsets.all(5),
            child: Icon(
              Icons.info_outline_rounded,
              size: 13,
              color: hover ? Mid.ink2 : Mid.ink3,
            ),
          ),
        ),
      ),
    );
  }
}

class _KnownList extends StatelessWidget {
  const _KnownList({
    required this.f,
    required this.onOpen,
    required this.budgeted,
  });
  final Forecast f;
  final ValueChanged<RegisterRow>? onOpen;
  final bool budgeted;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final payday = f.payday!;
    Widget line(
      String date,
      String what,
      String? amount, {
      RegisterRow? row,
      Key? key,
    }) {
      final body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                date,
                style: onest(13, color: Mid.ink3, tabular: true),
              ),
            ),
            Expanded(
              child: Text(
                what,
                style: onest(13, color: Mid.ink2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (amount != null)
              Text(
                amount,
                style: onest(
                  13,
                  color: amount.startsWith('+') ? Mid.green : Mid.ink,
                  tabular: true,
                ),
              ),
          ],
        ),
      );
      final open = onOpen;
      return row == null || open == null
          ? KeyedSubtree(key: key, child: body)
          : Hoverable(key: key, onTap: () => open(row), builder: (_) => body);
    }

    // Today, then each paycheck the plan expects with its amount (which
    // kind of income it is isn't known, owner 2026-09-30), and any other
    // money on the way by name.
    String plus(int v) => '+${roundedIn(context, v.abs())}';
    return Column(
      key: const ValueKey('forecast-known'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            key: const ValueKey('forecast-known-today'),
            children: [
              Expanded(
                child: Text(
                  t.planTodaysBalance,
                  style: onest(13, color: Mid.ink2),
                ),
              ),
              Text(
                roundedIn(context, f.startBalance.abs()),
                style: onest(13, color: Mid.ink, tabular: true),
              ),
            ],
          ),
        ),
        for (final s in f.rowSteps)
          line(
            shortDate(s.date),
            // A payday from the pay plan, scheduled or projected.
            identical(s.row, payday) || s.row.payScheduleId != null
                ? t.planExpectedIncome
                : _payeeText(t, s.row),
            plus(s.row.amount),
            row: s.row,
          ),
        if (f.throughPeriod)
          line(
            shortDate(f.end),
            t.planExpectedIncome,
            f.nextPayAmount == null ? null : plus(f.nextPayAmount!),
          )
        // The paycheck the forecast stops at, and anything else due on a
        // day picked with Custom… that it doesn't count as arrived (#410).
        else
          for (final held in f.heldBack)
            line(
              shortDate(f.end),
              identical(held, payday) || held.payScheduleId != null
                  ? t.planExpectedIncome
                  : _payeeText(t, held),
              plus(held.amount),
              row: held,
            ),
        if (!budgeted) ...[
          const SizedBox(height: 8),
          Text(t.planNothingBudgeted, style: onest(12.5, color: Mid.ink3)),
        ],
      ],
    );
  }
}

/// The bill count under the headline. Clicking it lists every bill before
/// the end date, with the balance after each; clicking a bill opens it.
class _BillsLink extends StatefulWidget {
  const _BillsLink({
    required this.parts,
    required this.f,
    required this.onOpen,
    required this.lit,
  });

  /// Which part of the key the pointer is on, shared with the chart.
  final ValueNotifier<_Part?> lit;

  /// One label per side of the rail, each a whole message of its own: they
  /// are separate facts set beside each other, never one sentence built
  /// from pieces.
  final List<(_Part?, String)> parts;
  final Forecast f;
  final ValueChanged<RegisterRow>? onOpen;

  @override
  State<_BillsLink> createState() => _BillsLinkState();
}

class _BillsLinkState extends State<_BillsLink> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();

  /// Where focus was before the list opened, so Esc and closing hand it
  /// back: to the register when the mouse opened it, and to the line itself
  /// when Tab and Enter did (#394). The line is a focus stop now, so
  /// whatever held focus at that moment is already the right answer.
  FocusNode? _returnFocus;
  final _cardFocus = FocusNode(debugLabel: 'forecast-bills');

  /// The line's own stop, so half the card isn't mouse-only (#394).
  final _lineFocus = FocusNode(debugLabel: 'forecast-bills-line');

  @override
  void dispose() {
    _cardFocus.dispose();
    _lineFocus.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_portal.isShowing) return _close();
    _returnFocus = FocusManager.instance.primaryFocus;
    setState(_portal.show);
    // Autofocus won't take it from the register, so ask once it's built.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _cardFocus.requestFocus(),
    );
  }

  void _close() {
    if (!_portal.isShowing) return;
    setState(_portal.hide);
    _returnFocus?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: _link,
      onTapOutside: (_) => _close(),
      child: CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (context) => CompositedTransformFollower(
            link: _link,
            targetAnchor: Alignment.bottomLeft,
            offset: const Offset(0, 10),
            child: Align(
              alignment: Alignment.topLeft,
              child: TapRegion(
                groupId: _link,
                // Takes focus while open so Esc reaches it.
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.escape): _close,
                  },
                  child: Focus(
                    focusNode: _cardFocus,
                    child: _BillsCard(
                      f: widget.f,
                      onOpen: widget.onOpen == null
                          ? null
                          : (r) {
                              _close();
                              widget.onOpen!(r);
                            },
                    ),
                  ),
                ),
              ),
            ),
          ),
          child: Hoverable(
            key: const ValueKey('forecast-bills'),
            focusNode: _lineFocus,
            onTap: _toggle,
            builder: (hover) {
              final lit = hover || _portal.isShowing;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Amounts and dates: smaller rather than cut.
                  Flexible(
                    child: Shrink(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final (i, (kind, text))
                              in widget.parts.indexed) ...[
                            if (i > 0) const SizedBox(width: 6),
                            _KeyChip(kind: kind, text: text, lit: widget.lit),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    _portal.isShowing
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: lit ? Mid.ink : Mid.ink3,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Every bill in the forecast, in order, and the income that ends it.
class _BillsCard extends StatelessWidget {
  const _BillsCard({required this.f, required this.onOpen});
  final Forecast f;

  /// Null while a reconcile is open: the list still reads, its lines just
  /// lead nowhere (#395).
  final ValueChanged<RegisterRow>? onOpen;

  static const width = 440.0;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final last = f.endBalance;
    // A list that runs into another year has two 02.16s in it, telling
    // apart only by the balance beside them, so every date here carries
    // its year (#397).
    final years = f.end.year != f.start.year;
    final open = onOpen;
    return Material(
      color: Mid.raised,
      elevation: 12,
      shadowColor: Colors.black,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: width, maxHeight: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Says what the two amount columns are.
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.planUntilDate(
                          years ? sayFullDate(t, f.end) : sayDate(t, f.end),
                        ),
                        style: onest(12, color: Mid.ink3),
                      ),
                    ),
                    Text(
                      f.owed ? t.planOwedAfter : t.planBalanceAfter,
                      style: onest(12, color: Mid.ink3),
                    ),
                  ],
                ),
              ),
              for (final s in f.rowSteps)
                _BillLine(
                  row: s.row,
                  date: s.date,
                  years: years,
                  balanceAfter: s.balance,
                  owed: f.owed,
                  onTap: open == null ? null : () => open(s.row),
                ),
              // Money due on the last day that the forecast doesn't count
              // as arrived: the paycheck a pay period ends at, and on a day
              // picked with Custom… everything money in that falls there
              // (#410). Below a rule, with their own balances, because the
              // list's header names that day too and two balances for one
              // date read as a mistake without a word saying why.
              if (f.heldBack.isNotEmpty) ...[
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: Mid.rule,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 2),
                  child: Text(
                    t.planNotCounted,
                    key: const ValueKey('forecast-not-counted'),
                    style: onest(12, color: Mid.ink3),
                  ),
                ),
                for (final (i, held) in f.heldBack.indexed)
                  _BillLine(
                    row: held,
                    date: f.end,
                    years: years,
                    balanceAfter:
                        last +
                        f.heldBack.take(i + 1).fold(0, (a, r) => a + r.amount),
                    onTap: open == null ? null : () => open(held),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BillLine extends StatefulWidget {
  const _BillLine({
    required this.row,
    required this.date,
    required this.balanceAfter,
    required this.onTap,
    this.owed = false,
    this.years = false,
  });

  /// The list crosses into another year: the date carries its year.
  final bool years;
  final RegisterRow row;
  final DateTime date;
  final int balanceAfter;
  final bool owed;

  /// Null while a reconcile is open.
  final VoidCallback? onTap;

  @override
  State<_BillLine> createState() => _BillLineState();
}

class _BillLineState extends State<_BillLine> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final b = widget.balanceAfter;
    final overdue = overdueNoteIn(context.t, r, widget.date);
    final tap = widget.onTap;
    return MouseRegion(
      cursor: tap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        key: const ValueKey('forecast-bill-line'),
        onTap: tap,
        child: Container(
          color: _hover && tap != null ? Mid.chip : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  widget.years ? fullDate(widget.date) : shortDate(widget.date),
                  style: onest(12.5, color: Mid.ink3, tabular: true),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        _payeeText(context.t, r),
                        style: onest(13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Not a row yet: what the pay plan or the category's
                    // plan expects after the scheduled one.
                    if (r.projected)
                      Text(
                        ' · ${context.t.planExpected}',
                        style: onest(12.5, color: Mid.ink3),
                        maxLines: 1,
                      ),
                    // Past due and counted as today: a transfer not made yet,
                    // or a bill not confirmed.
                    if (overdue != null)
                      Text(
                        ' · $overdue',
                        style: onest(12.5, weight: 600, color: Mid.ink),
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 104,
                child: Text(
                  // Money out in ordinary ink with its minus, as in the
                  // register (owner, 2026-10-09; #148).
                  '${r.amount > 0 ? '+' : (r.amount < 0 ? '−' : '')}${moneyIn(context, r.amount.abs(), showCents: false)}',
                  textAlign: TextAlign.right,
                  style: onest(
                    13,
                    color: r.amount > 0 ? Mid.green : Mid.ink,
                    tabular: true,
                  ),
                ),
              ),
              SizedBox(
                width: 110,
                child: Text(
                  roundedIn(context, b),
                  textAlign: TextAlign.right,
                  style: onest(
                    12.5,
                    color: !widget.owed && b < 0 ? Mid.coral : Mid.ink3,
                    tabular: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where things sit on the chart; shared by the painter and the dot targets.
class _ChartGeometry {
  _ChartGeometry(this.f, Size size) : w = size.width {
    h = size.height - _labelBand - _railBand;
    // The same walk without the budget's own spending: where the line
    // would run if only the dated rows happened (#398). It is never below
    // the line itself, so it only ever asks for room above.
    bare = <int>[];
    var running = f.startBalance, prev = f.startBalance;
    for (final s in f.steps) {
      final delta = s.balance - prev;
      prev = s.balance;
      if (!s.spending) running += delta;
      bare.add(running);
    }
    final values = [
      f.startBalance,
      ...f.steps.map((s) => s.balance),
      if (f.spendingTotal > 0) ...bare,
    ];
    var hi = values.reduce((a, b) => a > b ? a : b);
    var lo = values.reduce((a, b) => a < b ? a : b);
    // The chart is framed on the money that moves, not anchored at ₮0
    // (ADR 0004, "The forecast's chart does the talking"): a ₮1,500,000 dip
    // was drawn as a sixth of the height while the payday jump took the
    // rest. ₮0 is drawn only where it falls inside that frame, and never
    // pulls the frame to itself. A credit account keeps it: there it is the
    // paid-off mark, not a cliff.
    if (f.owed) {
      if (lo > 0) lo = 0;
      if (hi < 0) hi = 0;
    }
    // An account under water the whole time has no ₮0 inside its own range,
    // so it was framed on its negatives and drawn exactly like a healthy
    // one: no zero line, no coral fill, and the coral half of the stroke
    // skipped with it. When the account is short, ₮0 is on the chart.
    if (!f.owed && (f.isShort || f.shortNow)) {
      if (hi < 0) hi = 0;
      if (lo > 0) lo = 0;
    }
    // A month whose money barely moves is drawn as it is. Without this a 2%
    // wobble fills the box and the card shouts every month.
    final least = (hi.abs() / 4).round();
    if (hi - lo < least) lo = hi - least;
    if (hi <= lo) hi = lo + 1;
    _hi = hi;
    _lo = lo;
    // The last day's bills were drawn in the final pixel column, under the
    // chart's own border, and read as the edge of the box rather than money
    // leaving: the axis runs past the end so the step has room, and a short
    // flat run after it says the balance stays there.
    final days = f.end.difference(f.start).inDays;
    _span = days + (days * 0.08).round().clamp(1, 1 << 30);

    // Bills and the income that follows them the same day landed on one
    // pixel, so the dip was a zero-width spike. Spread them: it can be seen
    // and aimed at, and it is truer — they happened in some order that day.
    final perDay = <DateTime, int>{}, seen = <DateTime, int>{};
    for (final s in f.steps) {
      if (!s.spending) perDay[s.date] = (perDay[s.date] ?? 0) + 1;
    }
    xs = [
      for (final s in f.steps)
        if (s.spending)
          x(s.date)
        else
          () {
            final n = perDay[s.date]!;
            final i = seen[s.date] = (seen[s.date] ?? -1) + 1;
            // Never wider than the day itself: at a year a day is about a
            // pixel, and a fixed spread moved an event two days sideways,
            // so the line doubled back on itself and the wash folded over.
            final spread = (w / _span).clamp(0.0, _sameDay);
            return (x(s.date) + (i - (n - 1) / 2) * spread).clamp(0.0, w);
          }(),
    ];
  }

  static const _labelBand = 16.0, _railBand = 14.0, _sameDay = 5.0;

  /// The balance after each of [Forecast.steps] counting only the dated
  /// rows: the top of the band that shows what the budget plans to spend.
  late final List<int> bare;

  final Forecast f;
  final double w;
  late final double h;
  late final int _hi, _lo;

  /// Days across the chart, the run past the end included. Named apart from
  /// the top-level `_days(Forecast)`, which groups steps by day.
  late final int _span;

  /// Where each of [Forecast.steps] sits across the chart, same-day events
  /// spread apart.
  late final List<double> xs;

  /// ₮0 falls inside the frame, so the line and the fill under it are drawn.
  bool get showsZero => _lo <= 0 && _hi >= 0;

  /// The rail of what happens, under the plot, and the dates under that.
  double get railY => h + _railBand / 2;
  double get datesY => h + _railBand + 4;

  double x(DateTime d) =>
      (d.difference(f.start).inDays / _span.clamp(1, 4000)) * w;

  /// Air above the high point, and enough below the low one for the dip's
  /// own figure to sit under it. Above the dip is where the line itself
  /// runs, so a figure placed there lands on top of it.
  double y(int v) => 7 + (1 - (v - _lo) / (_hi - _lo)) * (h - 37);
}

/// [path] closed down to the foot of the plot, so two of them can be cut
/// from one another to leave the band between the lines.
Path _closedDown(Path path, double w, double h) => Path.from(path)
  ..lineTo(w, h + 8)
  ..lineTo(0, h + 8)
  ..close();

/// A path through [pts] with its corners rounded, so the staircase reads as
/// a path rather than a diagram (owner, 2026-11-08: the old one was "wimpy").
/// Each corner's radius shrinks to fit the shorter of its two legs.
Path _roundedThrough(List<Offset> pts, double radius) {
  final path = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (var i = 1; i < pts.length - 1; i++) {
    final (prev, here, next) = (pts[i - 1], pts[i], pts[i + 1]);
    final inLen = (here - prev).distance, outLen = (next - here).distance;
    final r = [radius, inLen / 2, outLen / 2].reduce((a, b) => a < b ? a : b);
    if (r < 0.5) {
      path.lineTo(here.dx, here.dy);
      continue;
    }
    final from = here + (prev - here) / inLen * r;
    final to = here + (next - here) / outLen * r;
    path.lineTo(from.dx, from.dy);
    path.quadraticBezierTo(here.dx, here.dy, to.dx, to.dy);
  }
  path.lineTo(pts.last.dx, pts.last.dy);
  return path;
}

/// A day's events on the chart: one stop each, as the rail's ticks and the
/// bill list group them. Where it sits across the chart is known only once
/// the chart has a size, so the layout delegate fills that in ([_Where]).
class _ChartEvent {
  _ChartEvent({required this.id, required this.steps, required this.lines});

  /// Tells one event from another, and names its marker on the rail.
  final String id;

  /// Which of [Forecast.steps] it stands for; empty for the payday past
  /// the end, which is no step.
  final List<int> steps;
  final List<({RegisterRow row, int balanceAfter})> lines;
}

/// Where the events ended up: written by the layout delegate, read by the
/// hover owner and by the card it places. Only the layout knows the size.
class _Where {
  List<double> xs = const [];
  double railY = 0, width = 0;
}

/// Every event on the chart, left to right, with the payday past the end
/// last: it sits in the right gutter, so the whole right strip belongs to
/// it (#393).
List<_ChartEvent> _eventsOf(Forecast f) {
  final byDay = <DateTime, List<int>>{};
  for (var i = 0; i < f.steps.length; i++) {
    // The budget's spending slopes a day at a time and has no row to open.
    if (f.steps[i].spending) continue;
    byDay.putIfAbsent(f.steps[i].date, () => []).add(i);
  }
  final days = byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  final out = [
    for (final day in days)
      _ChartEvent(
        id: fullDate(day.key),
        steps: day.value,
        lines: [
          for (final i in day.value)
            (row: f.steps[i].row, balanceAfter: f.steps[i].balance),
        ],
      ),
  ];
  if (f.heldBack.isNotEmpty) {
    // Every row held back lands on the same day, so they share one tick in
    // the gutter, each line carrying the balance as it would stand once
    // that row and the ones above it had arrived.
    var running = f.endBalance;
    out.add(
      _ChartEvent(
        // Not its date: a bill can fall on the same day, and two children
        // of one layout can't share a key.
        id: 'payday',
        steps: const [],
        lines: [
          for (final held in f.heldBack)
            (row: held, balanceAfter: running += held.amount),
        ],
      ),
    );
  }
  return out;
}

/// Keeps [v] between [lo] and [hi], and gives [lo] when there is no room
/// between them at all (a chart narrower than the card it shows).
double _within(double v, double lo, double hi) =>
    hi <= lo ? lo : v.clamp(lo, hi);

/// The chart plus what makes it useful: hover an event to see the bill,
/// click it to go to that transaction.
///
/// One hover owner over the plot and the rail, snapping to the nearest
/// event by x (#393). A target each meant that on a 90-day or year span
/// two bills a day or two apart overlapped and only the one laid out last
/// could be reached — the earlier ones weren't fiddly, they were
/// unhittable. Nearest wins rather than paint order, and the card is
/// placed once by the owner and clamped inside the chart instead of each
/// event guessing from its own anchor.
///
/// One focus stop for the whole chart, not one per event (#394): the
/// number of events changes with the range, so a stop each would move the
/// Tab order under the person. ← and → step event to event.
class _ForecastChart extends StatefulWidget {
  const _ForecastChart({
    required this.f,
    required this.onOpen,
    required this.lit,
  });
  final Forecast f;

  /// The part of the key the pointer is on: its marks are drawn stronger.
  final ValueNotifier<_Part?> lit;

  /// Null while a reconcile is open: no pointer cursor and no row opening,
  /// while the chart still reads and its cards still show. Nothing is taken
  /// away that there was anything for, so nothing needs reporting (#395).
  final ValueChanged<RegisterRow>? onOpen;

  @override
  State<_ForecastChart> createState() => _ForecastChartState();
}

class _ForecastChartState extends State<_ForecastChart> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  final _focus = FocusNode(debugLabel: 'forecast-chart');
  final _where = _Where();

  List<_ChartEvent> _events = const [];

  /// The event the pointer or the keyboard is on.
  int? _at;

  /// Where the pointer is when it is on no event: the chart then says that
  /// day's balance, so any day can be read, not only the ones with a bill
  /// (owner, 2026-11-10, sketch D).
  double? _scrub;

  /// How near an event the pointer has to be for its card to show. Past
  /// that the pointer is reading a day, not a bill.
  static const _reach = 24.0;

  void _hover(double dx) {
    final n = _nearest(dx);
    final onEvent = n != null && (_where.xs[n] - dx).abs() <= _reach;
    final scrub = onEvent ? null : dx;
    if (scrub != _scrub) setState(() => _scrub = scrub);
    _goTo(onEvent ? n : null);
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// The one in range, or null: a shorter range can leave [_at] past the
  /// end, and the chart may not have been laid out yet.
  int? get _on =>
      _at != null && _at! < _events.length && _at! < _where.xs.length
      ? _at
      : null;

  void _goTo(int? i) {
    if (i == _at) return;
    setState(() => _at = i);
    if (i == null) {
      if (_portal.isShowing) _portal.hide();
    } else if (!_portal.isShowing) {
      _portal.show();
    }
  }

  /// Nearest by x, with no cut-off: every point across the chart belongs to
  /// some event, and the strip past the last one belongs to it.
  int? _nearest(double dx) {
    final xs = _where.xs;
    if (xs.isEmpty) return null;
    var best = 0;
    for (var i = 1; i < xs.length; i++) {
      if ((xs[i] - dx).abs() < (xs[best] - dx).abs()) best = i;
    }
    return best;
  }

  void _step(int by) {
    if (_events.isEmpty) return;
    final from = _on ?? (by > 0 ? -1 : _events.length);
    _goTo((from + by).clamp(0, _events.length - 1));
  }

  void _open() {
    final at = _on;
    if (at == null) return;
    final row = _events[at].lines.first.row;
    _goTo(null);
    widget.onOpen?.call(row);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowRight:
        _step(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _step(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        if (_on == null) return KeyEventResult.ignored;
        _goTo(null);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
      case LogicalKeyboardKey.space:
        if (_on == null) return KeyEventResult.ignored;
        _open();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    _events = _eventsOf(widget.f);
    final at = _on;
    final canOpen = widget.onOpen != null && _events.isNotEmpty;
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) {
          if (at == null) return const SizedBox.shrink();
          return CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.topLeft,
            offset: Offset(
              _within(
                _where.xs[at] - _BillCard.width / 2,
                0,
                _where.width - _BillCard.width,
              ),
              _where.railY + 8,
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: IgnorePointer(
                child: _BillCard(lines: _events[at].lines, owed: widget.f.owed),
              ),
            ),
          );
        },
        child: Focus(
          focusNode: _focus,
          canRequestFocus: canOpen,
          skipTraversal: !canOpen,
          // Tab onto the chart lands on the first event, so the keyboard
          // alone shows where it is; leaving puts the card away.
          onFocusChange: (has) => has ? _step(1) : _goTo(null),
          onKeyEvent: _onKey,
          child: CustomMultiChildLayout(
            delegate: _ChartLayout(widget.f, _events, _where),
            children: [
              LayoutId(
                id: 'paint',
                child: CustomPaint(
                  painter: _ForecastPainter(
                    widget.f,
                    CurrencyScope.of(context),
                    highlightX: at == null ? null : _where.xs[at],
                    // Not on a card: a bare figure there doesn't say whether
                    // it is owed or in credit, and every other figure on a
                    // card's forecast does.
                    scrubX: at == null && !widget.f.owed ? _scrub : null,
                    bandLabel: widget.f.owed && widget.f.spendingTotal > 0
                        ? context.t.planBandLabel(
                            formatRounded(
                              widget.f.spendingTotal,
                              currency: CurrencyScope.of(context),
                            ),
                          )
                        : null,
                    lowWord: context.t.planLowestWord,
                    lit: widget.lit,
                  ),
                ),
              ),
              // Where each event sits, marked so a test can aim at one;
              // the owner below does all the hitting.
              for (var i = 0; i < _events.length; i++)
                LayoutId(
                  key: ValueKey('forecast-event-${_events[i].id}'),
                  id: 'event$i',
                  child: const IgnorePointer(child: SizedBox.shrink()),
                ),
              LayoutId(
                id: 'hit',
                child: MouseRegion(
                  cursor: canOpen && at != null
                      ? SystemMouseCursors.click
                      : MouseCursor.defer,
                  onHover: (e) => _hover(e.localPosition.dx),
                  onExit: (_) {
                    if (_scrub != null) setState(() => _scrub = null);
                    _goTo(null);
                  },
                  child: GestureDetector(
                    key: const ValueKey('forecast-events'),
                    behavior: HitTestBehavior.opaque,
                    onTapUp: widget.onOpen == null
                        ? null
                        : (d) {
                            // Only the bill whose card is showing: a click
                            // while reading a plain day opened one that
                            // could be weeks away.
                            _hover(d.localPosition.dx);
                            _open();
                          },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Puts the painter, the event markers and the one hover owner over the
/// plot, and tells the chart's state where each event landed.
class _ChartLayout extends MultiChildLayoutDelegate {
  _ChartLayout(this.f, this.events, this.where);
  final Forecast f;
  final List<_ChartEvent> events;
  final _Where where;

  @override
  void performLayout(Size size) {
    layoutChild('paint', BoxConstraints.tight(size));
    positionChild('paint', Offset.zero);
    final g = _ChartGeometry(f, size);
    where
      ..width = g.w
      ..railY = g.railY
      ..xs = [
        for (final e in events)
          // The middle of that day's ticks, which the geometry spreads a
          // few pixels apart: aiming at the cluster lands on the day. The
          // payday past the end sits in the right gutter.
          if (e.steps.isEmpty)
            g.w
          else
            e.steps.fold(0.0, (sum, i) => sum + g.xs[i]) / e.steps.length,
      ];
    // The plot and the rail, not the dates under them: a pointer cursor
    // over the date row would offer nothing.
    layoutChild(
      'hit',
      BoxConstraints.tight(
        Size(
          size.width,
          (g.railY + _ChartGeometry._railBand / 2).clamp(0.0, size.height),
        ),
      ),
    );
    positionChild('hit', Offset.zero);
    for (var i = 0; i < events.length; i++) {
      layoutChild('event$i', BoxConstraints.tight(const Size.square(1)));
      positionChild('event$i', Offset(where.xs[i] - 0.5, g.railY - 0.5));
    }
  }

  @override
  bool shouldRelayout(_ChartLayout old) =>
      old.f != f || old.events.length != events.length;
}

/// What a forecast dot stands for.
class _BillCard extends StatelessWidget {
  const _BillCard({required this.lines, this.owed = false});
  static const width = 300.0;
  final List<({RegisterRow row, int balanceAfter})> lines;
  final bool owed;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final last = lines.last;
    return Material(
      key: const ValueKey('forecast-bill-card'),
      color: Mid.raised,
      elevation: 12,
      shadowColor: Colors.black,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              shortDate(last.row.date),
              style: onest(12, color: Mid.ink3, tabular: true),
            ),
            const SizedBox(height: 4),
            for (final l in lines) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _payeeText(t, l.row),
                          style: onest(13.5, weight: 500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          // Pay that varies: the forecast counts on the least.
                          l.row.estimate != null
                              ? t.planAtLeastEstimate(rowCategory(t, l.row))
                              : l.row.memo.isNotEmpty
                              ? l.row.memo
                              : rowCategory(t, l.row),
                          style: onest(12, color: Mid.ink3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    // Money out plain, in with +. The register's red minus
                    // isn't used here: coral in the forecast says it runs out.
                    '${l.row.amount > 0 ? '+' : ''}${moneyIn(context, l.row.amount.abs())}',
                    style: onest(
                      13.5,
                      color: l.row.amount > 0 ? Mid.green : Mid.ink,
                      tabular: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Container(height: 1, color: Mid.rule),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  owed ? t.planOwedAfter : t.planBalanceAfter,
                  style: onest(12, color: Mid.ink3),
                ),
                const Spacer(),
                Text(
                  roundedIn(context, last.balanceAfter),
                  style: onest(
                    12.5,
                    color: !owed && last.balanceAfter < 0
                        ? Mid.coral
                        : Mid.ink2,
                    tabular: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ForecastPainter extends CustomPainter {
  _ForecastPainter(
    this.f,
    this.currency, {
    this.highlightX,
    this.scrubX,
    this.bandLabel,
    required this.lowWord,
    required this.lit,
  }) : super(repaint: lit);
  final Currency currency;
  final Forecast f;

  /// "Lowest", set before the dip's figure: with three figures on the line
  /// a first reader could not tell which was which.
  final String lowWord;

  /// The part of the key the pointer is on.
  final ValueNotifier<_Part?> lit;

  /// Names the band on a card, which has no chip to name it.
  final String? bandLabel;

  /// Where the pointer is while it is on no event: that day's balance is
  /// read off the line.
  final double? scrubX;

  /// Where the event the pointer or the keyboard is on sits. At a year the
  /// ticks are about a pixel apart, so the card alone doesn't say which one
  /// it speaks for.
  final double? highlightX;

  /// Drawn in these colors; a switch between light and dark repaints.
  final Palette palette = Mid.palette;

  @override
  void paint(Canvas canvas, Size size) {
    final g = _ChartGeometry(f, size);
    final w = g.w, h = g.h;
    final y = g.y;
    final zero = y(0);
    // Below zero is a shortfall, in coral; a wallet filled from the bank
    // isn't, and neither is a card (rule 2).
    final under = !f.owed && f.takeOut == 0;

    // Where the line goes: a flat run to each event, a step at it, and the
    // budget's spending sloping a day at a time between them.
    final pts = <Offset>[Offset(0, y(f.startBalance))];
    var prev = f.startBalance;
    for (var i = 0; i < f.steps.length; i++) {
      final s = f.steps[i];
      final sx = g.xs[i];
      if (!s.spending) pts.add(Offset(sx, y(prev)));
      pts.add(Offset(sx, y(s.balance)));
      prev = s.balance;
    }
    pts.add(Offset(w, y(prev)));
    final path = _roundedThrough(pts, 5);

    // What the budget plans to spend: the band between the line and where
    // it would run if only the dated rows happened (#398, owner 2026-11-09:
    // "a way to visualize things on the ledger's forecast that aren't bills
    // per se"). Groceries and the rest come out a day at a time, so there
    // is no one place on the line to point at; the gap between the two is
    // the whole of it, and it widens as the month goes on. Money out is
    // ordinary ink (rule 2): the band takes no colour of its own.
    if (f.spendingTotal > 0) {
      final barePts = <Offset>[Offset(0, y(f.startBalance))];
      for (var i = 0; i < f.steps.length; i++) {
        if (f.steps[i].spending) continue;
        final sx = g.xs[i];
        barePts
          ..add(Offset(sx, y(i == 0 ? f.startBalance : g.bare[i - 1])))
          ..add(Offset(sx, y(g.bare[i])));
      }
      barePts.add(Offset(w, y(g.bare.isEmpty ? f.startBalance : g.bare.last)));
      final barePath = _roundedThrough(barePts, 5);
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, -4, w, h + 4));
      // Either of the two can be the upper one, so the band is what they
      // don't share, not one cut from the other: on a credit account the
      // steps are what's owed, so budgeted spending takes the line *up*
      // and the dated-rows-only line runs below it (code review).
      canvas.drawPath(
        Path.combine(
          PathOperation.xor,
          _closedDown(barePath, w, h),
          _closedDown(path, w, h),
        ),
        // Quiet until the key's Day-to-day is pointed at.
        Paint()
          ..color = Mid.ink3.withValues(
            alpha: lit.value == _Part.spend ? 0.5 : 0.26,
          ),
      );
      // On an account the key's chip carries a sample of it, its name and
      // its figure, and pointing at the chip lights it up, so it isn't named
      // here. A card has no such chip (its line is a sentence of charges
      // and payments), so there the band keeps its name on the chart.
      // Named where it is widest, in the band's own ink: the figure sits
      // between the two lines, so what it measures is unmistakable.
      if (bandLabel case final text? when barePts.length > 2) {
        // The widest point, but kept out of the last stretch, where the
        // end balance and the final marker already sit.
        var bestX = 0.0, bestTop = 0.0, bestGap = 0.0;
        for (var i = 0; i < f.steps.length; i++) {
          if (g.xs[i] > w * 0.72) break;
          final a = y(g.bare[i]), b = y(f.steps[i].balance);
          final gap = (a - b).abs();
          if (gap > bestGap) {
            bestGap = gap;
            bestX = g.xs[i];
            bestTop = a < b ? a : b;
          }
        }
        final half = _measure(text).width / 2;
        // Only where it fits inside the band, across and down, without
        // crowding either line.
        if (bestGap >= 18 && half * 2 + 16 <= w) {
          _label(
            canvas,
            text,
            Offset(
              bestX.clamp(half + 4, w - half - 4),
              bestTop + bestGap / 2 - 7,
            ),
            Mid.ink3,
            center: true,
          );
        }
      }

      // Its top edge, dashed: nothing is scheduled up there, it is only
      // where the money would have stayed.
      final dash = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Mid.ink3.withValues(alpha: 0.75);
      for (final m in barePath.computeMetrics()) {
        for (var d = 0.0; d < m.length; d += 7) {
          canvas.drawPath(
            m.extractPath(d, (d + 3.5).clamp(0.0, m.length)),
            dash,
          );
        }
      }
      canvas.restore();
    }

    // The wash under the line carries weight near it and fades out, so the
    // shape reads without anyone having to follow the stroke.
    final washTo = g.showsZero ? zero : h;
    canvas.drawPath(
      Path.from(path)
        ..lineTo(w, washTo)
        ..lineTo(0, washTo)
        ..close(),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(0, washTo),
          [
            Mid.blue.withValues(alpha: 0.24),
            Mid.blue.withValues(alpha: 0.05),
            Mid.blue.withValues(alpha: 0),
          ],
          const [0, 0.7, 1],
        ),
    );

    if (g.showsZero) {
      final dash = Paint()
        ..color = f.isShort ? Mid.coral.withValues(alpha: 0.45) : Mid.rule
        ..strokeWidth = 1;
      for (var dx = 0.0; dx < w; dx += 7) {
        canvas.drawLine(
          Offset(dx, zero),
          Offset((dx + 3).clamp(0, w), zero),
          dash,
        );
      }
      // Inside the plot, at the line's own left end: the right gutter it
      // used to sit in put it beside where the line ends, and it was read
      // as "you end with nothing".
      _label(
        canvas,
        formatRounded(0, currency: currency),
        // Clamped: with the window's high at ₮0 the label sat above the
        // chart, on the bills line.
        Offset(0, (zero - 18).clamp(0.0, (h - 14).clamp(0.0, h))),
        Mid.ink3,
      );
      if (f.isShort) {
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(-4, zero, w + 4, h));
        canvas.drawPath(
          Path.from(path)
            ..lineTo(w, zero)
            ..lineTo(0, zero)
            ..close(),
          Paint()..color = Mid.coral.withValues(alpha: 0.18),
        );
        canvas.restore();
      }
    }

    // The event being read, from the top of the plot down to its tick on
    // the rail: the card is clamped inside the chart, so on a long span it
    // can sit well away from the event it speaks for. Drawn under the
    // line, the figures and the ticks, which all stay on top of it.
    if (highlightX case final hx?) {
      canvas.drawLine(
        Offset(hx, 0),
        Offset(hx, g.railY),
        Paint()
          ..color = Mid.ink2.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
    }

    // A glow under the stroke, then the stroke itself: lighter at the top,
    // deeper at the bottom.
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = Mid.blue.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2),
    );
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-4, -4, w + 4, g.showsZero ? zero : h + 4));
    canvas.drawPath(path, stroke..color = Mid.blue);
    canvas.restore();
    if (g.showsZero) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(-4, zero, w + 4, h + 4));
      canvas.drawPath(path, stroke..color = under ? Mid.coral : Mid.blue);
      canvas.restore();
    }

    // The rail: what happens, under the shape it causes. A tick for each
    // bill below the rail, money in above it in green. The line stops being
    // a wire with dots stuck to it.
    canvas.drawLine(
      Offset(0, g.railY),
      Offset(w, g.railY),
      Paint()
        ..color = Mid.rule
        ..strokeWidth = 1,
    );
    for (var i = 0; i < f.steps.length; i++) {
      final s = f.steps[i];
      if (s.spending) continue;
      final inward = s.row.amount > 0;
      // The part of the key under the pointer stands taller; the other
      // side steps back.
      final on = lit.value == (inward ? _Part.income : _Part.out);
      final dim = lit.value != null && lit.value != _Part.spend && !on;
      final len = on ? 12.0 : 8.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(g.xs[i] - 1.4, g.railY - (inward ? len : 0), 2.8, len),
          const Radius.circular(1.4),
        ),
        Paint()
          ..color = (inward ? Mid.green : Mid.ink2).withValues(
            alpha: dim ? 0.3 : 1,
          ),
      );
    }

    // Where the line begins: the Working balance beside it, marked so the
    // two are seen to be one number.
    final startAt = Offset(0, y(f.startBalance));
    canvas.drawCircle(
      startAt,
      9,
      Paint()..color = Mid.blue.withValues(alpha: 0.2),
    );
    canvas.drawCircle(startAt, 4.5, Paint()..color = Mid.ink);
    canvas.drawCircle(
      startAt,
      4.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Mid.blue,
    );

    // The figures sit at their points, and only where nothing else on the
    // card says them: the dip, drawn large, and where you land.
    final bigLow = !f.owed && f.low < f.startBalance;
    final placed = <Rect>[];
    void tag(
      String text,
      Offset at,
      Color color,
      double size,
      List<(bool right, bool above)> spots, {
      int weight = 400,
      bool mustShow = false,
      String? lead,
    }) {
      final tp = TextPainter(
        text: TextSpan(
          children: [
            if (lead != null)
              TextSpan(
                text: '$lead  ',
                style: onest(11, color: Mid.ink3),
              ),
            TextSpan(text: text),
          ],
          style: onest(size, color: color, weight: weight, tabular: true),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      for (final (right, above) in spots) {
        final r = Rect.fromLTWH(
          right ? at.dx + 7 : at.dx - 7 - tp.width,
          above ? at.dy - tp.height - 4 : at.dy + 4,
          tp.width,
          tp.height,
        );
        if (r.left < 0 || r.right > w || r.top < 0 || r.bottom > h) continue;
        if (placed.any((o) => o.inflate(3).overlaps(r))) continue;
        placed.add(r);
        tp.paint(canvas, r.topLeft);
        return;
      }
      // No spot fits. With no sentence to fall back on, the card's own
      // figure is the whole answer, so it is never dropped: put it where it
      // fits inside the plot rather than nowhere.
      if (!mustShow) return;
      final r = Rect.fromLTWH(
        (at.dx - tp.width / 2).clamp(0.0, (w - tp.width).clamp(0.0, w)),
        (at.dy + 4).clamp(0.0, (h - tp.height).clamp(0.0, h)),
        tp.width,
        tp.height,
      );
      placed.add(r);
      tp.paint(canvas, r.topLeft);
    }

    String amount(int v) => formatRounded(v, currency: currency);
    // The day comes first: the same balance can come round again later, and
    // since the budget's spending became steps (#179) the low is often one
    // of those, which are not spread. Matching on the amount alone put the
    // figure, its ring and its date in the wrong column.
    final lowX = () {
      for (var i = 0; i < f.steps.length; i++) {
        final s = f.steps[i];
        if (s.date == f.lowDate && s.balance == f.low && !s.spending) {
          return g.xs[i];
        }
      }
      return g.x(f.lowDate);
    }();
    // Zero counts as short (`buildForecast`, owner 2026-10-05), so a balance
    // that lands exactly on ₮0 is coral like any other shortfall.
    final lowShort = under && f.low <= 0;
    // The dip is the card's one big number now that no sentence says it.
    if (bigLow) {
      tag(
        amount(f.low),
        Offset(lowX, y(f.low)),
        lowShort ? Mid.coral : Mid.ink,
        19,
        [(false, false), (false, true), (true, false), (true, true)],
        weight: 600,
        mustShow: true,
        lead: lowWord,
      );
      canvas.drawCircle(Offset(lowX, y(f.low)), 4, Paint()..color = Mid.card);
      canvas.drawCircle(
        Offset(lowX, y(f.low)),
        4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.25
          ..color = lowShort ? Mid.coral : Mid.blue,
      );
    }
    // Where you land: the figure the card never said, and the one whose
    // absence made the end of the line read as the edge of the box. When
    // the month ends at its own lowest point the big figure has already
    // said it, so it isn't printed a second time.
    if (f.steps.isNotEmpty) {
      final endY = y(f.endBalance);
      // Not when the dip already carries it, and not when the ₮0 line's own
      // label says it: a card paid off to ₮0 printed ₮0 at both ends.
      if ((!bigLow || f.endBalance != f.low) &&
          !(g.showsZero && f.endBalance == 0)) {
        tag(
          amount(f.endBalance),
          Offset(w, endY),
          under && f.endBalance <= 0 ? Mid.coral : Mid.ink,
          15,
          // Under the last flat run first: above it is where the step down
          // to it comes through, and the line would cross the figure.
          [(false, false), (false, true)],
          weight: 600,
        );
      }
      canvas.drawCircle(
        Offset(pts.last.dx, endY),
        3.5,
        Paint()..color = Mid.card,
      );
      canvas.drawCircle(
        Offset(pts.last.dx, endY),
        3.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = under && f.endBalance <= 0 ? Mid.coral : Mid.blue,
      );
    }

    // Just dates: where it starts, the dip, and where it stops. The dip's
    // own date always shows — with no sentence left to say it, "down to
    // ₮91,000" with no day attached cannot be acted on, and in the
    // to-income range the dip is usually right before the end, which is
    // exactly where it used to be dropped. The ends give way to it instead.
    final endX = g.x(f.end);
    final showLow = !f.owed && f.low < f.startBalance;
    final (startText, lowText, endText) = (
      shortDate(f.start),
      shortDate(f.lowDate),
      shortDate(f.end),
    );
    final lowHalf = _widthOf(lowText) / 2 + 8;
    final lowAt = lowX.clamp(lowHalf, w - lowHalf);
    if (!showLow || lowAt - lowHalf > _widthOf(startText)) {
      _label(canvas, startText, Offset(0, g.datesY), Mid.ink3);
    }
    if (showLow) {
      _label(
        canvas,
        lowText,
        Offset(lowAt, g.datesY),
        lowShort ? Mid.coral : Mid.ink,
        center: true,
      );
    }
    if (!showLow || (endX - lowAt).abs() > lowHalf + _widthOf(endText) / 2) {
      _label(canvas, endText, Offset(endX, g.datesY), Mid.ink3, center: true);
    }

    // The day under the pointer: a hairline, a dot on the line, and that
    // day's date and balance. Last, so it sits over everything else.
    if (scrubX case final sx?) {
      final days = f.end.difference(f.start).inDays;
      // By the calendar, as the forecast builds its days: adding a
      // Duration lands an hour short across a daylight-saving change.
      final day = DateTime(
        f.start.year,
        f.start.month,
        f.start.day + (sx / w * g._span).round().clamp(0, days),
      );
      var balance = f.startBalance;
      for (final s in f.steps) {
        if (s.date.isAfter(day)) break;
        balance = s.balance;
      }
      final at = Offset(g.x(day), y(balance));
      canvas.drawLine(
        Offset(at.dx, 0),
        Offset(at.dx, g.railY),
        Paint()
          ..color = Mid.ink2.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(at, 5, Paint()..color = Mid.blue);
      canvas.drawCircle(
        at,
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Mid.ink,
      );
      final date = TextPainter(
        text: TextSpan(
          text: shortDate(day),
          style: onest(11, color: Mid.ink3, tabular: true),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final figure = TextPainter(
        text: TextSpan(
          text: amount(balance),
          style: onest(
            14,
            weight: 600,
            color: under && balance <= 0 ? Mid.coral : Mid.ink,
            tabular: true,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final boxW = (date.width > figure.width ? date.width : figure.width) + 20;
      final boxH = date.height + figure.height + 14;
      final left = at.dx + 12 + boxW > w ? at.dx - 12 - boxW : at.dx + 12;
      final top = (at.dy - boxH - 8).clamp(0.0, (h - boxH).clamp(0.0, h));
      final box = RRect.fromRectAndRadius(
        Rect.fromLTWH(left.clamp(0.0, w), top, boxW, boxH),
        const Radius.circular(8),
      );
      canvas.drawRRect(box, Paint()..color = Mid.ground);
      canvas.drawRRect(
        box,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Mid.rule,
      );
      date.paint(canvas, Offset(box.left + 10, box.top + 6));
      figure.paint(canvas, Offset(box.left + 10, box.top + 8 + date.height));
    }
  }

  double _widthOf(String text) => (TextPainter(
    text: TextSpan(text: text, style: onest(11, tabular: true)),
    textDirection: TextDirection.ltr,
  )..layout()).width;

  /// How wide a chart label comes out, so one can be kept inside the plot
  /// or left out when there is no room for it.
  TextPainter _measure(String text) => TextPainter(
    text: TextSpan(text: text, style: onest(11, tabular: true)),
    textDirection: TextDirection.ltr,
  )..layout();

  void _label(
    Canvas canvas,
    String text,
    Offset at,
    Color color, {
    bool alignRight = false,
    bool center = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: onest(11, color: color, tabular: true),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      alignRight
          ? at.translate(-tp.width, 0)
          : center
          ? at.translate(-tp.width / 2, 0)
          : at,
    );
  }

  @override
  bool shouldRepaint(_ForecastPainter old) =>
      old.f != f ||
      old.palette != palette ||
      old.currency != currency ||
      old.highlightX != highlightX ||
      old.scrubX != scrubX ||
      old.lowWord != lowWord;
}
