import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/forecast.dart';
import '../domain/ledger.dart';
import '../domain/money.dart';
import 'data_words.dart';
import 'language.dart';
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
    this.onImport,
    this.reconcile,
    this.owed = false,
    this.onAddPay,
  });

  /// No payday ahead: the forecast offers to put pay in.
  final VoidCallback? onAddPay;

  /// A credit account: every amount here is what's owed, positive.
  final bool owed;

  /// Shown in place of the balance sum while reconciling.
  final Widget? reconcile;
  final VoidCallback onReconcile;

  /// Brings a bank file's rows in.
  final VoidCallback? onImport;

  /// A forecast dot was clicked: show that scheduled transaction.
  final ValueChanged<RegisterRow> onOpenScheduled;
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
      padding: const EdgeInsets.fromLTRB(32, 26, 32, 22),
      decoration: BoxDecoration(
        color: Mid.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Mid.rule),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child:
                  reconcile ??
                  _Balances(
                    s: summary,
                    owed: owed,
                    hovered: hoveredStatus,
                    active: activeStatus,
                    onTap: onStatusTap,
                    onReconcile: onReconcile,
                    onImport: onImport,
                  ),
            ),
            const SizedBox(width: 40),
            Container(width: 1, color: Mid.rule),
            const SizedBox(width: 40),
            SizedBox(
              width: 440,
              child: ForecastPanel(
                forecast,
                onOpen: onOpenScheduled,
                onAddPay: onAddPay,
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
    this.onImport,
  });

  final AccountSummary s;
  final bool owed;
  final VoidCallback onReconcile;
  final VoidCallback? onImport;
  final ValueNotifier<Cleared?> hovered;
  final Cleared? active;
  final ValueChanged<Cleared> onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final n = s.unclearedCount;
    int shown(int v) => owed ? -v : v;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Written as a sum, so the header teaches why working and cleared
        // differ, and doubles as the key to the register's symbols.
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusLine(
              status: Cleared.cleared,
              amount: shown(s.cleared),
              note: '',
              hovered: hovered,
              active: active == Cleared.cleared,
              onTap: () => onTap(Cleared.cleared),
            ),
            _StatusLine(
              status: Cleared.uncleared,
              amount: shown(s.uncleared),
              signed: true,
              note: n == 0 ? t.planEverythingCleared : t.planNotClearedYet(n),
              hovered: hovered,
              active: active == Cleared.uncleared,
              onTap: () => onTap(Cleared.uncleared),
            ),
            Container(
              width: _Line.amountWidth,
              height: 1,
              margin: EdgeInsets.only(
                left: _Line.amountLeft(context),
                top: 2,
                bottom: 4,
              ),
              color: Mid.ink3.withValues(alpha: 0.45),
            ),
            _TotalLine(amount: shown(s.working), owed: owed),
            const SizedBox(height: 10),
            Row(
              children: [
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
                  onTap: onReconcile,
                ),
                if (onImport != null)
                  BarButton(
                    key: const ValueKey('import'),
                    label: t.importButton,
                    onTap: onImport!,
                  ),
              ],
            ),
          ],
        ),
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
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        const SizedBox(width: _Line._glyph + _Line._gap),
        Text(
          owed ? context.t.planOwed : context.t.planWorking,
          style: onest(13, weight: 500),
        ),
        const Spacer(),
        Money(
          amount,
          size: 30,
          weight: 500,
          letterSpacing: -0.6,
          centsScale: 0.55,
          color: !owed && amount < 0 ? Mid.coral : Mid.ink,
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
  final ValueChanged<RegisterRow> onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final total = '₮${formatWhole(late.fold(0, (s, r) => s + r.amount))}';
    // "+… in" says which way it goes: late bills use the same gold.
    final String what;
    if (late.length > 1) {
      what = t.planLateSeveral(total, late.length);
    } else {
      final days = daysBefore(late.single.date, today);
      what = days == 0 ? t.planLateToday(total) : t.planLateDays(total, days);
    }
    return Hoverable(
      key: const ValueKey('forecast-late'),
      onTap: () => onOpen(late.first),
      builder: (h) {
        final style = onest(12, color: Mid.gold, tabular: true).copyWith(
          decoration: h ? TextDecoration.underline : null,
          decorationColor: Mid.gold,
        );
        // Only the amount part shrinks: "not counted" explains the warning.
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(' · ', style: onest(12, color: Mid.ink3)),
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
  const ForecastPanel(this.f, {super.key, required this.onOpen, this.onAddPay});
  final Forecast f;
  final ValueChanged<RegisterRow> onOpen;
  final VoidCallback? onAddPay;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final payday = f.payday;
    String money(int v) => '₮${formatWhole(v)}';
    final String headline;
    final String detail;
    if (f.owed) {
      // A card: what will be owed once scheduled charges and payments land.
      final payments = f.steps.where((s) => s.row.amount > 0).length;
      final bal = f.endBalance;
      headline = f.steps.isEmpty
          ? t.planNothingScheduled
          : bal < 0
          ? t.planCreditAfter(money(bal), sayDate(t, f.steps.last.date))
          : t.planOwedAfterDate(money(bal), sayDate(t, f.steps.last.date));
      final end = sayDate(t, f.end);
      detail = f.steps.isEmpty
          ? t.planCardNothing
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
            : t.planRunsOut(on, money(f.low));
      } else if (f.steps.isEmpty) {
        headline = t.planNothingScheduled;
      } else {
        headline = t.planLowest(money(f.low), sayDate(t, f.lowDate));
      }
      // No payee names here: they can be any length. The count opens the list.
      // Money moved in from another account, refunds: they lift the line.
      final end = sayDate(t, f.end);
      detail = f.steps.isEmpty
          ? payday == null
                ? t.planNoBillsOrIncome
                : t.planNoBillsBefore(end)
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

    // Late money in, named so a warning without it makes sense.
    final late = f.late;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          key: const ValueKey('forecast-horizon'),
          children: [
            Text(
              payday == null ? t.planNext30Days : t.planUntilNextIncome,
              style: onest(12, color: Mid.ink3),
            ),
            if (late.isNotEmpty)
              Flexible(
                child: _LateNote(late: late, today: f.start, onOpen: onOpen),
              )
            // Nothing to run to: the forecast can't say "until payday", so it
            // asks for pay, every time, until it has some.
            else if (!f.owed && payday == null && onAddPay != null)
              Flexible(
                child: Hoverable(
                  key: const ValueKey('add-pay'),
                  onTap: onAddPay,
                  builder: (hover) => Text(
                    t.planAddPay,
                    style: onest(12, color: Mid.gold).copyWith(
                      decoration: hover ? TextDecoration.underline : null,
                      decorationColor: Mid.gold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          headline,
          style: onest(
            18,
            weight: 500,
            color: f.isShort ? Mid.coral : Mid.ink,
            tabular: true,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        if (f.steps.isEmpty)
          Text(detail, style: onest(13, color: Mid.ink3, tabular: true))
        else
          _BillsLink(label: detail, f: f, onOpen: onOpen),
        const SizedBox(height: 14),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: _ForecastChart(f: f, onOpen: onOpen),
          ),
        ),
      ],
    );
  }
}

/// The bill count under the headline. Clicking it lists every bill before
/// the end date, with the balance after each; clicking a bill opens it.
class _BillsLink extends StatefulWidget {
  const _BillsLink({
    required this.label,
    required this.f,
    required this.onOpen,
  });
  final String label;
  final Forecast f;
  final ValueChanged<RegisterRow> onOpen;

  @override
  State<_BillsLink> createState() => _BillsLinkState();
}

class _BillsLinkState extends State<_BillsLink> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  bool _hover = false;

  /// Where focus was before the list opened, so Esc and closing hand it back.
  FocusNode? _returnFocus;
  final _cardFocus = FocusNode(debugLabel: 'forecast-bills');

  @override
  void dispose() {
    _cardFocus.dispose();
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
    final lit = _hover || _portal.isShowing;
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
                      onOpen: (r) {
                        _close();
                        widget.onOpen(r);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: GestureDetector(
              key: const ValueKey('forecast-bills'),
              onTap: _toggle,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style:
                        onest(
                          13,
                          color: lit
                              ? Mid.ink
                              : (widget.f.isShort ? Mid.ink2 : Mid.ink3),
                          tabular: true,
                        ).copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: Mid.ink3.withValues(alpha: 0.6),
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
              ),
            ),
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
  final ValueChanged<RegisterRow> onOpen;

  static const width = 440.0;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final payday = f.payday;
    final last = f.endBalance;
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
                        t.planUntilDate(sayDate(t, f.end)),
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
              for (final s in f.steps)
                _BillLine(
                  row: s.row,
                  date: s.date,
                  balanceAfter: s.balance,
                  owed: f.owed,
                  onTap: () => onOpen(s.row),
                ),
              if (payday != null) ...[
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: Mid.rule,
                ),
                _BillLine(
                  row: payday,
                  date: f.end,
                  balanceAfter: last + payday.amount,
                  onTap: () => onOpen(payday),
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
  });
  final RegisterRow row;
  final DateTime date;
  final int balanceAfter;
  final bool owed;
  final VoidCallback onTap;

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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        key: const ValueKey('forecast-bill-line'),
        onTap: widget.onTap,
        child: Container(
          color: _hover ? Mid.chip : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  shortDate(widget.date),
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
                    // Past due and counted as today: a transfer not made yet,
                    // or a bill not confirmed.
                    if (overdue != null)
                      Text(
                        ' · $overdue',
                        style: onest(12.5, color: Mid.gold),
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 104,
                child: Text(
                  '${r.amount > 0 ? '+' : ''}${formatMoney(r.amount.abs(), showCents: false)}',
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
                  '${b < 0 ? '−' : ''}₮${formatWhole(b)}',
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
  _ChartGeometry(this.f, Size size)
    : w = size.width - _rightGutter,
      h = size.height - _labelBand {
    final values = [f.startBalance, ...f.steps.map((s) => s.balance)];
    _hi = values.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 62);
    _lo = values.reduce((a, b) => a < b ? a : b).clamp(-(1 << 62), 0);
  }

  static const _labelBand = 20.0, _rightGutter = 24.0;
  final Forecast f;
  final double w, h;
  late final int _hi, _lo;

  double x(DateTime d) =>
      (d.difference(f.start).inDays /
          f.end.difference(f.start).inDays.clamp(1, 1000)) *
      w;
  double y(int v) => 6 + (1 - (v - _lo) / (_hi - _lo)) * (h - 12);
}

/// Bills that land on the same day share one dot.
List<List<ForecastStep>> _days(Forecast f) {
  final byDay = <DateTime, List<ForecastStep>>{};
  for (final s in f.steps) {
    byDay.putIfAbsent(s.date, () => []).add(s);
  }
  return byDay.values.toList();
}

/// The chart plus what makes it useful: hover a dot to see the bill, click
/// it to go to that transaction.
class _ForecastChart extends StatelessWidget {
  const _ForecastChart({required this.f, required this.onOpen});
  final Forecast f;
  final ValueChanged<RegisterRow> onOpen;

  @override
  Widget build(BuildContext context) {
    final days = _days(f);
    final payday = f.payday;
    final last = f.endBalance;
    return CustomMultiChildLayout(
      delegate: _ChartLayout(f, days),
      children: [
        LayoutId(
          id: 'paint',
          child: CustomPaint(painter: _ForecastPainter(f)),
        ),
        for (var i = 0; i < days.length; i++)
          LayoutId(
            key: ValueKey('forecast-dot-${shortDate(days[i].first.date)}'),
            id: 'dot$i',
            child: _DotTarget(
              lines: [
                for (final s in days[i]) (row: s.row, balanceAfter: s.balance),
              ],
              owed: f.owed,
              onOpen: onOpen,
            ),
          ),
        if (payday != null)
          LayoutId(
            key: const ValueKey('forecast-payday'),
            id: 'payday',
            child: _DotTarget(
              lines: [(row: payday, balanceAfter: last + payday.amount)],
              onOpen: onOpen,
              alignRight: true,
            ),
          ),
      ],
    );
  }
}

/// Puts each dot's hover target over the dot the painter draws.
class _ChartLayout extends MultiChildLayoutDelegate {
  _ChartLayout(this.f, this.days);
  final Forecast f;
  final List<List<ForecastStep>> days;

  @override
  void performLayout(Size size) {
    layoutChild('paint', BoxConstraints.tight(size));
    positionChild('paint', Offset.zero);
    final g = _ChartGeometry(f, size);
    const dot = 22.0;
    for (var i = 0; i < days.length; i++) {
      layoutChild('dot$i', BoxConstraints.tight(const Size(dot, dot)));
      positionChild(
        'dot$i',
        Offset(g.x(days[i].first.date), g.y(days[i].last.balance)) -
            const Offset(dot / 2, dot / 2),
      );
    }
    if (hasChild('payday')) {
      const label = Size(120, _ChartGeometry._labelBand);
      layoutChild('payday', BoxConstraints.tight(label));
      positionChild('payday', Offset(g.w - label.width, g.h));
    }
  }

  @override
  bool shouldRelayout(_ChartLayout old) => old.f != f;
}

class _DotTarget extends StatefulWidget {
  const _DotTarget({
    required this.lines,
    required this.onOpen,
    this.alignRight = false,
    this.owed = false,
  });
  final List<({RegisterRow row, int balanceAfter})> lines;
  final ValueChanged<RegisterRow> onOpen;
  final bool alignRight;
  final bool owed;

  @override
  State<_DotTarget> createState() => _DotTargetState();
}

class _DotTargetState extends State<_DotTarget> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: widget.alignRight
              ? Alignment.bottomRight
              : Alignment.bottomCenter,
          offset: Offset(
            widget.alignRight ? -_BillCard.width : -_BillCard.width / 2,
            6,
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: IgnorePointer(
              child: _BillCard(lines: widget.lines, owed: widget.owed),
            ),
          ),
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(_portal.show),
          onExit: (_) => setState(_portal.hide),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(_portal.hide);
              widget.onOpen(widget.lines.first.row);
            },
          ),
        ),
      ),
    );
  }
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
                    // As the register shows it: money out plain, in with +.
                    '${l.row.amount > 0 ? '+' : ''}${formatMoney(l.row.amount.abs())}',
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
                  '${last.balanceAfter < 0 ? '−' : ''}₮${formatWhole(last.balanceAfter)}',
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
  _ForecastPainter(this.f);
  final Forecast f;

  /// Drawn in these colors; a switch between light and dark repaints.
  final Palette palette = Mid.palette;

  @override
  void paint(Canvas canvas, Size size) {
    final g = _ChartGeometry(f, size);
    final w = g.w, h = g.h;
    final x = g.x, y = g.y;
    final values = [f.startBalance, ...f.steps.map((s) => s.balance)];

    // Balance only changes on the day a bill lands, so draw steps, not curves.
    final path = Path()..moveTo(0, y(f.startBalance));
    var prev = f.startBalance;
    for (final s in f.steps) {
      path
        ..lineTo(x(s.date), y(prev))
        ..lineTo(x(s.date), y(s.balance));
      prev = s.balance;
    }
    path.lineTo(w, y(values.last));

    final zero = y(0);
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
    _label(canvas, '₮0', Offset(w + 8, zero - 7), Mid.ink3);

    if (f.isShort) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(-4, zero, w + 4, h));
      final fill = Path.from(path)
        ..lineTo(w, zero)
        ..lineTo(0, zero)
        ..close();
      canvas.drawPath(fill, Paint()..color = Mid.coral.withValues(alpha: 0.16));
      canvas.restore();
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.75
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-4, -4, w + 4, zero));
    canvas.drawPath(path, stroke..color = Mid.blue);
    canvas.restore();
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-4, zero, w + 4, h + 4));
    canvas.drawPath(path, stroke..color = f.owed ? Mid.blue : Mid.coral);
    canvas.restore();

    for (final s in f.steps) {
      canvas.drawCircle(
        Offset(x(s.date), y(s.balance)),
        2.5,
        Paint()..color = !f.owed && s.balance < 0 ? Mid.coral : Mid.ink2,
      );
    }
    canvas.drawCircle(
      Offset(0, y(f.startBalance)),
      3.5,
      Paint()..color = Mid.card,
    );
    canvas.drawCircle(
      Offset(0, y(f.startBalance)),
      3.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Mid.ink,
    );

    if (f.payday != null) {
      canvas.drawLine(
        Offset(w, 2),
        Offset(w, h),
        Paint()..color = Mid.green.withValues(alpha: 0.5),
      );
    }
    // Just the dates the chart spans. The headline already says what ends it,
    // and hovering the end date shows that income.
    _label(canvas, shortDate(f.start), Offset(0, h + 6), Mid.ink3);
    _label(
      canvas,
      shortDate(f.end),
      Offset(w, h + 6),
      Mid.ink3,
      alignRight: true,
    );
  }

  void _label(
    Canvas canvas,
    String text,
    Offset at,
    Color color, {
    bool alignRight = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: onest(11, color: color, tabular: true),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, alignRight ? at.translate(-tp.width, 0) : at);
  }

  @override
  bool shouldRepaint(_ForecastPainter old) =>
      old.f != f || old.palette != palette;
}
