part of 'phone_app.dart';

// An account's header and forecast on the phone's Ledger tab (#529, owner's
// pick of sketch C, ADR 0004 "Accounts on the phone"): when one account is
// chosen, a card above its rows says what it holds (Working, Cleared and
// Uncleared, when it was last reconciled) and whether it runs out; the
// Forecast opens the chart and the bills before its end, with the
// computer's ranges. It is the computer's header, worked out by the same
// code (`forecastOf`, `forecastSays`).

/// What the budget expects spent from an account, kept for the ledger it was
/// worked out for: a year of it is the slow part of a forecast, and the
/// Accounts page's "Runs out" and the header both ask (as the computer does).
final _spendingKept =
    Expando<
      Map<(int, DateTime?, DateTime), List<({DateTime date, int amount})>>
    >();

List<({DateTime date, int amount})> Function(DateTime? until) _spendingOf(
  LedgerData data,
  AccountInfo account,
  DateTime today,
) =>
    (until) => (_spendingKept[data] ??= {}).putIfAbsent((
      account.id,
      until,
      dateOnly(today),
    ), () => forecastSpending(data, account, today: today, until: until));

/// The card above one account's rows.
class _AccountHeader extends StatefulWidget {
  const _AccountHeader({
    required this.store,
    required this.account,
    required this.today,
  });
  final PhoneStore store;
  final AccountInfo account;
  final DateTime today;

  @override
  State<_AccountHeader> createState() => _AccountHeaderState();
}

class _AccountHeaderState extends State<_AccountHeader> {
  var _open = false;

  LedgerData get _data => widget.store.snapshot.data!;
  AccountInfo get _a => widget.account;

  /// The forecast for [span], kept while the ledger is the same one.
  LedgerData? _for;
  final _forecasts = <(int, ForecastSpan), Forecast>{};
  Forecast _forecast(ForecastSpan span) {
    final data = _data;
    if (!identical(_for, data)) {
      _for = data;
      _forecasts.clear();
    }
    return _forecasts.putIfAbsent((
      _a.id,
      span,
    ), () => forecastOf(data, _a, today: widget.today, span: span));
  }

  Future<void> _pickSpan(ForecastSpan span) async {
    if (span == ForecastSpan.custom) {
      final first = ForecastSpan.firstCustom(widget.today);
      final picked = await showDatePicker(
        context: context,
        initialDate:
            ForecastSpan.parseCustomEnd(
              _data.prefs[ForecastSpan.customEndKey],
              widget.today,
            ) ??
            first,
        firstDate: first,
        lastDate: ForecastSpan.lastCustom(widget.today),
      );
      if (picked == null || !mounted) return;
      await _write(PhoneSetSpan(ForecastSpan.custom, customEnd: picked));
      return;
    }
    await _write(PhoneSetSpan(span));
  }

  Future<void> _write(PhoneSetSpan act) async {
    try {
      await widget.store.actRow(act);
    } catch (e) {
      debugPrint('Choosing a forecast range on the phone failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            persist: false,
            duration: phoneSnackTime,
            backgroundColor: Mid.raised,
            content: Text(
              context.t.ledgerCouldntSave,
              style: onest(15, color: Mid.ink),
            ),
          ),
        );
    }
  }

  String _spanLabel(Words t, ForecastSpan s) => switch (s) {
    ForecastSpan.payPeriod => t.planSpanToIncome,
    ForecastSpan.days30 => t.planSpanDays(30),
    ForecastSpan.days60 => t.planSpanDays(60),
    ForecastSpan.days90 => t.planSpanDays(90),
    ForecastSpan.months6 => t.planSpanMonths(6),
    ForecastSpan.year => t.planSpanYear,
    ForecastSpan.custom => t.planSpanCustom,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final data = _data;
    final summary = data.summaryFor(_a.id);
    // A card's amounts are what is owed, positive, as the computer's header
    // shows them; owing is normal there, so never coral.
    int shown(int v) => _a.isOwed ? -v : v;
    final chosen = ForecastSpan.parse(data.prefs[ForecastSpan.prefKey]);
    // The pay period is offered only where there is pay to run to.
    final spans = [
      if (data.paySchedules.isNotEmpty) ForecastSpan.payPeriod,
      ForecastSpan.days30,
      ForecastSpan.days90,
      ForecastSpan.year,
      ForecastSpan.custom,
    ];
    final span = spans.contains(chosen) ? chosen : ForecastSpan.days30;
    final f = _forecast(span);
    String money(int v) => formatShort(v.abs(), currency: _a.currency);
    final says = forecastSays(t, f, money);
    final coral = !_a.isOwed && (f.isShort || f.shortNow);
    return Container(
      key: ValueKey('account-header-${_a.id}'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      decoration: BoxDecoration(
        color: Mid.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Mid.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Shrink(
                  Text(
                    formatMoney(shown(summary.working), currency: _a.currency),
                    key: const ValueKey('account-working'),
                    maxLines: 1,
                    style: onest(
                      26,
                      weight: 700,
                      tabular: true,
                      color: !_a.isOwed && summary.working < 0
                          ? Mid.coral
                          : Mid.ink,
                    ),
                  ),
                ),
              ),
              Text(
                _a.isOwed ? t.planOwed : t.planWorking,
                style: onest(13, color: Mid.ink2),
              ),
            ],
          ),
          if (!_a.isCash) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _figure(
                    t.startCleared,
                    formatShort(shown(summary.cleared), currency: _a.currency),
                    'account-cleared',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _figure(
                    t.startUncleared,
                    formatShort(
                      shown(summary.uncleared),
                      currency: _a.currency,
                    ),
                    'account-uncleared',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              summary.reconciledOn == null
                  ? t.planNeverReconciled
                  : t.planLastReconciled(sayDate(t, summary.reconciledOn!)),
              key: const ValueKey('account-reconciled'),
              style: onest(13, color: Mid.ink2),
            ),
          ],
          const Divider(height: 20, thickness: 1),
          InkWell(
            key: const ValueKey('account-forecast-toggle'),
            onTap: () => setState(() => _open = !_open),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      says.headline,
                      key: const ValueKey('account-says'),
                      style: onest(14, color: coral ? Mid.coral : Mid.ink2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    t.planForecast,
                    style: onest(14, weight: 600, color: Mid.blue),
                  ),
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Mid.blue,
                  ),
                ],
              ),
            ),
          ),
          if (_open) ...[
            const SizedBox(height: 4),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final s in spans)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        key: ValueKey('forecast-span-${s.name}'),
                        label: Text(_spanLabel(t, s), style: onest(14)),
                        selected: s == span,
                        showCheckmark: false,
                        selectedColor: Mid.blue,
                        backgroundColor: Mid.raised,
                        labelStyle: onest(
                          14,
                          color: s == span ? Mid.onAccent : Mid.ink2,
                        ),
                        side: BorderSide.none,
                        onSelected: (_) => unawaited(_pickSpan(s)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: CustomPaint(
                key: const ValueKey('forecast-chart'),
                painter: _PhoneForecastPainter(f),
                size: Size.infinite,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  shortDate(f.start),
                  style: onest(12, color: Mid.ink3, tabular: true),
                ),
                const Spacer(),
                Text(
                  shortDate(f.end),
                  style: onest(12, color: Mid.ink3, tabular: true),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(says.detail, style: onest(13, color: Mid.ink2)),
            const SizedBox(height: 6),
            for (final s in f.rowSteps.take(8))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(
                        shortDate(s.date),
                        style: onest(13, color: Mid.ink2, tabular: true),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: onest(14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatShort(s.row.amount, currency: _a.currency),
                      style: onest(
                        14,
                        tabular: true,
                        color: s.row.amount > 0 ? Mid.green : Mid.ink,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _figure(String label, String value, String key) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Shrink(
        Text(
          value,
          key: ValueKey(key),
          maxLines: 1,
          style: onest(15, weight: 600, tabular: true),
        ),
      ),
      Text(label, style: onest(12, color: Mid.ink2)),
    ],
  );
}

/// The forecast's balance, day by day: a step at each bill or money in,
/// the dashed zero line, coral where it is below it and its lowest day
/// marked. Drawn from the forecast's own steps (`Forecast.steps`).
class _PhoneForecastPainter extends CustomPainter {
  _PhoneForecastPainter(this.f);
  final Forecast f;

  @override
  void paint(Canvas canvas, Size size) {
    final start = f.start, end = f.end;
    final days = max(1, end.difference(start).inDays);
    final points = <(DateTime, int)>[(start, f.startBalance)];
    for (final s in f.steps) {
      points.add((s.date, s.balance));
    }
    final values = [for (final (_, v) in points) v, 0];
    final hi = values.reduce(max), lo = values.reduce(min);
    final span = max(1, hi - lo);
    const pad = 8.0;
    double x(DateTime d) =>
        pad +
        (size.width - 2 * pad) *
            (d.difference(start).inDays.clamp(0, days) / days);
    double y(int v) => pad + (size.height - 2 * pad) * (1 - (v - lo) / span);
    // The line: flat until a step, then the step.
    final path = Path()..moveTo(x(start), y(f.startBalance));
    var at = f.startBalance;
    for (final s in f.steps) {
      path
        ..lineTo(x(s.date), y(at))
        ..lineTo(x(s.date), y(s.balance));
      at = s.balance;
    }
    path.lineTo(x(end), y(at));
    final zero = y(0);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, zero));
    canvas.drawPath(path, line..color = Mid.blue);
    canvas.restore();
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, zero, size.width, size.height));
    canvas.drawPath(path, line..color = f.owed ? Mid.blue : Mid.coral);
    canvas.restore();
    final dash = Paint()
      ..color = Mid.rule
      ..strokeWidth = 1;
    for (var dx = pad; dx < size.width - pad; dx += 8) {
      canvas.drawLine(Offset(dx, zero), Offset(dx + 4, zero), dash);
    }
    // Its lowest day.
    if (!f.owed && f.steps.isNotEmpty) {
      canvas.drawCircle(
        Offset(x(f.lowDate), y(f.low)),
        4,
        Paint()..color = f.low < 0 ? Mid.coral : Mid.ink2,
      );
    }
  }

  @override
  bool shouldRepaint(_PhoneForecastPainter old) => !identical(old.f, f);
}
