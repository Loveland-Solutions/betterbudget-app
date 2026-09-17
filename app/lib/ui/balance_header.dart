import 'package:flutter/material.dart';

import '../domain/forecast.dart';
import '../domain/ledger.dart';
import '../domain/money.dart';
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
  });

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
        color: Mid.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Mid.rule),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _Balances(
                s: summary,
                hovered: hoveredStatus,
                active: activeStatus,
                onTap: onStatusTap,
              ),
            ),
            const SizedBox(width: 40),
            Container(width: 1, color: Mid.rule),
            const SizedBox(width: 40),
            SizedBox(
              width: 440,
              child: ForecastPanel(forecast, onOpen: onOpenScheduled),
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
  });

  final AccountSummary s;
  final ValueNotifier<Cleared?> hovered;
  final Cleared? active;
  final ValueChanged<Cleared> onTap;

  @override
  Widget build(BuildContext context) {
    final n = s.unclearedCount;
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
              amount: s.cleared,
              note: '',
              hovered: hovered,
              active: active == Cleared.cleared,
              onTap: () => onTap(Cleared.cleared),
            ),
            _StatusLine(
              status: Cleared.uncleared,
              amount: s.uncleared,
              signed: true,
              note: n == 0 ? 'Everything has cleared' : '$n not cleared yet',
              hovered: hovered,
              active: active == Cleared.uncleared,
              onTap: () => onTap(Cleared.uncleared),
            ),
            Container(
              width: _Line.amountWidth,
              height: 1,
              margin: const EdgeInsets.only(
                left: _Line.amountLeft,
                top: 2,
                bottom: 4,
              ),
              color: Mid.ink3.withValues(alpha: 0.45),
            ),
            _TotalLine(amount: s.working),
            const SizedBox(height: 10),
            _StatusLine(
              status: Cleared.reconciled,
              amount: null,
              // When matters here, not how much: no amount column.
              label: s.reconciledOn == null
                  ? 'Never reconciled'
                  : 'Last reconciled on ${shortDate(s.reconciledOn!)}',
              note: '',
              hovered: hovered,
              active: active == Cleared.reconciled,
              onTap: () => onTap(Cleared.reconciled),
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

  static const _glyph = 16.0, _gap = 6.0, _label = 84.0, _amount = 200.0;

  /// Where the amount column sits, for the rule drawn above the total.
  static const amountLeft = _glyph + _gap + _label;
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
        width: _label,
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
  const _TotalLine({required this.amount});
  final int amount;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _Line.amountLeft + _Line.amountWidth,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        const SizedBox(width: _Line._glyph + _Line._gap),
        Text('Working', style: onest(13, weight: 500)),
        const Spacer(),
        Money(
          amount,
          size: 30,
          weight: 500,
          letterSpacing: -0.6,
          centsScale: 0.55,
          color: amount < 0 ? Mid.coral : Mid.ink,
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
                      label: StatusGlyph.label(status),
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

/// The header's one chart. It exists to warn: most days it is quiet.
class ForecastPanel extends StatelessWidget {
  const ForecastPanel(this.f, {super.key, required this.onOpen});
  final Forecast f;
  final ValueChanged<RegisterRow> onOpen;

  @override
  Widget build(BuildContext context) {
    final payday = f.payday;
    final String headline;
    final String detail;
    final before = payday == null
        ? 'the next 30 days are out'
        : payday.categoryLabel.toLowerCase();
    if (f.shortNow) {
      // Already under: say so, not a future "runs out" date. The amount is
      // the Working total beside it, so it isn't repeated.
      headline = f.low < f.startBalance
          ? 'Below zero now · up to ₮${formatWhole(f.low)} short'
          : 'Below zero now';
      detail = f.causes.isEmpty
          ? 'No bills before $before'
          : '${_joinAnd(f.causes)} ${f.causes.length == 1 ? 'lands' : 'land'} before $before.';
    } else if (f.isShort) {
      headline =
          'Runs out on ${shortDate(f.firstShort!)} · up to ₮${formatWhole(f.low)} short';
      detail =
          '${_joinAnd(f.causes)} ${f.causes.length == 1 ? 'lands' : 'land'} before $before.';
    } else if (f.steps.isEmpty) {
      headline = 'Nothing scheduled';
      detail = payday == null
          ? 'No bills or income in the next 30 days'
          : 'No bills before ${payday.categoryLabel.toLowerCase()}';
    } else {
      headline = 'Lowest ₮${formatWhole(f.low)} on ${shortDate(f.lowDate)}';
      detail =
          '${f.billCount} scheduled ${f.billCount == 1 ? 'bill' : 'bills'} · ₮${formatWhole(f.billTotal)} before ${payday == null ? shortDate(f.end) : payday.categoryLabel.toLowerCase()}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          payday == null ? 'Next 30 days' : 'Until next income',
          style: onest(12, color: Mid.ink3),
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
        Text(
          detail,
          style: onest(
            13,
            color: f.isShort ? Mid.ink2 : Mid.ink3,
            tabular: true,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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

String _joinAnd(List<String> xs) => xs.length <= 1
    ? xs.join()
    : '${xs.sublist(0, xs.length - 1).join(', ')} and ${xs.last}';

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
    final last = f.steps.isEmpty ? f.startBalance : f.steps.last.balance;
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
  });
  final List<({RegisterRow row, int balanceAfter})> lines;
  final ValueChanged<RegisterRow> onOpen;
  final bool alignRight;

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
            child: IgnorePointer(child: _BillCard(lines: widget.lines)),
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
  const _BillCard({required this.lines});
  static const width = 300.0;
  final List<({RegisterRow row, int balanceAfter})> lines;

  @override
  Widget build(BuildContext context) {
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
                          l.row.kind == RowKind.transfer
                              ? '${l.row.amount < 0 ? 'To' : 'From'} ${l.row.payee}'
                              : l.row.payee,
                          style: onest(13.5, weight: 500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          l.row.memo.isNotEmpty
                              ? l.row.memo
                              : l.row.categoryLabel,
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
                Text('Balance after', style: onest(12, color: Mid.ink3)),
                const Spacer(),
                Text(
                  '${last.balanceAfter < 0 ? '−' : ''}₮${formatWhole(last.balanceAfter)}',
                  style: onest(
                    12.5,
                    color: last.balanceAfter < 0 ? Mid.coral : Mid.ink2,
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
    canvas.drawPath(path, stroke..color = Mid.coral);
    canvas.restore();

    for (final s in f.steps) {
      canvas.drawCircle(
        Offset(x(s.date), y(s.balance)),
        2.5,
        Paint()..color = s.balance < 0 ? Mid.coral : Mid.ink2,
      );
    }
    canvas.drawCircle(
      Offset(0, y(f.startBalance)),
      3.5,
      Paint()..color = Mid.panel,
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
    _label(canvas, 'Today', Offset(0, h + 6), Mid.ink3);
    final endLabel = f.payday != null
        ? '${shortDate(f.end)} ${f.payday!.categoryLabel}'
        : shortDate(f.end);
    _label(
      canvas,
      endLabel,
      Offset(w, h + 6),
      f.payday != null ? Mid.green : Mid.ink3,
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
  bool shouldRepaint(_ForecastPainter old) => old.f != f;
}
