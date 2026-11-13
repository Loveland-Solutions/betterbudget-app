part of 'ledger_screen.dart';

// The four types of category, as cards at the top of the New category
// window and a category's Edit (owner, 2026-11-13, #429, sketch A; ADR 0004
// "The four kinds of category have names"). Picking one asks only that
// type's questions. Each card's picture is the same stretch of time drawn
// for its type, so the shapes tell them apart: spent down each month,
// built up with a dip, paid out on a date, ready by a date and then spent.

/// A category's type. Not stored: it comes from the answers a category
/// already has (a due date or not, spent each month or built up, shown on
/// Savings as a goal), so nothing in a ledger changes for it.
enum _CategoryType { dayToDay, fund, bill, goal }

/// "How will this money be spent?" and the four cards under it.
class _TypeCards extends StatelessWidget {
  const _TypeCards({
    required this.type,
    required this.byPay,
    required this.onPick,
  });

  /// The type the answers make now: its card is lit.
  final _CategoryType type;

  /// Set aside by pay period rather than by month: the words say so.
  final bool byPay;
  final ValueChanged<_CategoryType> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final cards = [
      (
        _CategoryType.dayToDay,
        t.planTypeDay,
        byPay ? t.planTypeDayMeansPay : t.planTypeDayMeans,
        t.planTypeDayFor,
      ),
      (
        _CategoryType.fund,
        t.planTypeFund,
        byPay ? t.planTypeFundMeansPay : t.planTypeFundMeans,
        t.planTypeFundFor,
      ),
      (
        _CategoryType.bill,
        t.planTypeBill,
        t.planTypeBillMeans,
        t.planTypeBillFor,
      ),
      (
        _CategoryType.goal,
        t.planTypeGoal,
        t.planTypeGoalMeans,
        t.planTypeGoalFor,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.planTypeQ, style: onest(14, weight: 600)),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, (kind, name, means, examples)) in cards.indexed)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 10),
                    child: _TypeCard(
                      key: ValueKey('plan-type-${kind.name}'),
                      kind: kind,
                      name: name,
                      means: means,
                      examples: examples,
                      on: kind == type,
                      onTap: () => onPick(kind),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    super.key,
    required this.kind,
    required this.name,
    required this.means,
    required this.examples,
    required this.on,
    required this.onTap,
  });

  final _CategoryType kind;
  final String name;
  final String means;
  final String examples;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: on,
    label: name,
    child: Hoverable(
      onTap: onTap,
      builder: (hover) => Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: on ? Mid.blueWash : Mid.panel,
          borderRadius: BorderRadius.circular(12),
          // The same width lit or not, so nothing moves when it's picked.
          border: Border.all(
            width: 1.5,
            color: on
                ? Mid.blue
                : hover
                ? Mid.ink3
                : Mid.rule,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 52,
              width: double.infinity,
              child: CustomPaint(
                painter: _TypePicture(
                  kind,
                  ground: Mid.ground,
                  line: Mid.ink,
                  money: Mid.fill,
                  dip: Mid.coral,
                  flag: Mid.fill,
                  quiet: Mid.ink3,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: onest(15, weight: 700, color: on ? Mid.blue : Mid.ink),
            ),
            const SizedBox(height: 4),
            Text(means, style: onest(12.5, color: Mid.ink2, height: 1.35)),
            const SizedBox(height: 4),
            Text(examples, style: onest(12, color: Mid.ink3, height: 1.35)),
          ],
        ),
      ),
    ),
  );
}

/// A type's money over the same stretch of time: a small chart drawn on
/// a 160 × 52 grid, scaled to the card.
class _TypePicture extends CustomPainter {
  const _TypePicture(
    this.kind, {
    required this.ground,
    required this.line,
    required this.money,
    required this.dip,
    required this.flag,
    required this.quiet,
  });

  final _CategoryType kind;
  final Color ground, line, money, dip, flag, quiet;

  static const _w = 160.0, _h = 52.0, _floor = 48.0;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / _w, sy = size.height / _h;
    Offset at(double x, double y) => Offset(x * sx, y * sy);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      Paint()..color = ground,
    );
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    // The money's line, and the ground under it washed in the logo's green.
    void chart(List<(double, double)> points) {
      final path = Path()
        ..moveTo(
          at(points[0].$1, points[0].$2).dx,
          at(points[0].$1, points[0].$2).dy,
        );
      for (final (x, y) in points.skip(1)) {
        final o = at(x, y);
        path.lineTo(o.dx, o.dy);
      }
      final area = Path.from(path)
        ..lineTo(at(points.last.$1, _floor).dx, at(points.last.$1, _floor).dy)
        ..lineTo(at(points.first.$1, _floor).dx, at(points.first.$1, _floor).dy)
        ..close();
      canvas.drawPath(area, Paint()..color = money.withValues(alpha: 0.28));
      canvas.drawPath(path, stroke);
    }

    switch (kind) {
      // Full at the start of each month, spent down by its end.
      case _CategoryType.dayToDay:
        chart([
          (8, 10),
          (48, 44),
          (48, 10),
          (88, 44),
          (88, 10),
          (128, 44),
          (128, 10),
          (152, 30),
        ]);
      // Up a step each month toward what it holds at most, one dip when
      // something comes up.
      case _CategoryType.fund:
        final dash = Paint()
          ..color = quiet
          ..strokeWidth = 1;
        for (var x = 8.0; x < 152; x += 8) {
          canvas.drawLine(at(x, 6), at(x + 4, 6), dash);
        }
        chart([
          (8, 44),
          (30, 44),
          (30, 38),
          (52, 38),
          (52, 32),
          (74, 32),
          (74, 26),
          (92, 26),
          (92, 40),
          (110, 40),
          (110, 34),
          (130, 34),
          (130, 28),
          (152, 28),
        ]);
        canvas.drawCircle(at(92, 40), 3.5 * sx, Paint()..color = dip);
      // Built up to the date, then all of it out at once, to someone else's
      // door.
      case _CategoryType.bill:
        chart([(8, 44), (100, 10), (100, 44)]);
        final arrow = Path()
          ..moveTo(at(110, 26).dx, at(110, 26).dy)
          ..lineTo(at(136, 26).dx, at(136, 26).dy)
          ..moveTo(at(130, 20).dx, at(130, 20).dy)
          ..lineTo(at(137, 26).dx, at(137, 26).dy)
          ..lineTo(at(130, 32).dx, at(130, 32).dy);
        canvas.drawPath(arrow, stroke);
        canvas.drawRect(
          Rect.fromPoints(at(142, 12), at(152, 40)),
          stroke..strokeWidth = 1.5,
        );
      // Ready by its date, flagged, then spent by the household in a few
      // purchases of its own.
      case _CategoryType.goal:
        chart([
          (8, 44),
          (100, 10),
          (108, 20),
          (116, 20),
          (124, 30),
          (132, 30),
          (140, 42),
          (152, 42),
        ]);
        canvas.drawLine(at(100, 10), at(100, 1), stroke..strokeWidth = 1.5);
        canvas.drawPath(
          Path()
            ..moveTo(at(100, 1).dx, at(100, 1).dy)
            ..lineTo(at(112, 4.5).dx, at(112, 4.5).dy)
            ..lineTo(at(100, 8).dx, at(100, 8).dy)
            ..close(),
          Paint()..color = flag,
        );
    }
  }

  @override
  bool shouldRepaint(_TypePicture old) =>
      old.kind != kind ||
      old.ground != ground ||
      old.line != line ||
      old.money != money ||
      old.dip != dip ||
      old.flag != flag ||
      old.quiet != quiet;
}
