import 'package:flutter/material.dart';

import '../domain/ledger.dart';
import '../domain/money.dart';

/// One set of colors for the whole app. Dark is Steppe night, light is Steppe;
/// the sidebar is the same gray denim in both (owner, 2026-09-29; ADR 0004).
class Palette {
  const Palette({
    required this.brightness,
    required this.ground,
    required this.panel,
    required this.card,
    required this.raised,
    required this.rule,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.blue,
    required this.gold,
    required this.green,
    required this.coral,
    required this.onAccent,
    required this.wash,
  });

  final Brightness brightness;
  final Color ground, panel, card, raised, rule, ink, ink2, ink3;
  final Color blue, gold, green, coral;

  /// Text and icons on a filled blue, gold or green button or toast.
  final Color onAccent;

  /// The base of the faint chip, hover and row tints: light on dark, dark on
  /// light.
  final Color wash;

  /// Steppe night: a blue-black page, steppe sky blue for what you click,
  /// gold for reconciled or scheduled.
  static const dark = Palette(
    brightness: Brightness.dark,
    ground: Color(0xFF0D1522),
    panel: Color(0xFF141D2D),
    card: Color(0xFF1A2436),
    raised: Color(0xFF222E44),
    rule: Color(0x1AECEFF4),
    ink: Color(0xFFECEFF4),
    ink2: Color(0xFFAAB3C2),
    ink3: Color(0xFF8D97AA),
    blue: Color(0xFF6FA8F0),
    gold: Color(0xFFE8C15A),
    green: Color(0xFF5CCB8E),
    coral: Color(0xFFF08A8A),
    onAccent: Color(0xFF0D1522),
    wash: Color(0xFFECEFF4),
  );

  /// Steppe: a warm felt-cream page under white cards, steppe blue for what
  /// you click, a deeper gold and green that read on white.
  static const light = Palette(
    brightness: Brightness.light,
    ground: Color(0xFFF6F1E7),
    panel: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    raised: Color(0xFFEEE8DC),
    rule: Color(0x1F1A2230),
    ink: Color(0xFF1A2230),
    ink2: Color(0xFF4E5666),
    ink3: Color(0xFF6C7382),
    blue: Color(0xFF1B5BA8),
    gold: Color(0xFF8A6414),
    green: Color(0xFF2E7D4F),
    // Toward orange, so a shortfall doesn't read as a stop sign.
    coral: Color(0xFFB8442A),
    onAccent: Color(0xFFFFFFFF),
    wash: Color(0xFF1A2230),
  );
}

/// The colors in use, read everywhere as `Mid.ink` and so on. [AppearanceScope]
/// switches them and rebuilds the app.
abstract final class Mid {
  static Palette palette = Palette.dark;
  static Palette get _p => palette;
  static bool get isLight => _p.brightness == Brightness.light;

  static Color get ground => _p.ground;
  static Color get panel => _p.panel;

  /// The balance header, a step above the register (white in light mode).
  static Color get card => _p.card;
  static Color get raised => _p.raised;
  static Color get rule => _p.rule;
  static Color get ink => _p.ink;
  static Color get ink2 => _p.ink2;
  static Color get ink3 => _p.ink3;
  static Color get blue => _p.blue;
  static Color get gold => _p.gold;
  static Color get green => _p.green;
  static Color get coral => _p.coral;
  static Color get onAccent => _p.onAccent;

  static Color get blueWash => blue.withValues(alpha: isLight ? 0.10 : 0.12);
  static Color get blueEdge => blue.withValues(alpha: 0.35);
  static Color get chip => _p.wash.withValues(alpha: isLight ? 0.06 : 0.08);
  static Color get hover => _p.wash.withValues(alpha: isLight ? 0.04 : 0.05);

  /// Every other register row: a faint lift of the blue, so the eye
  /// can follow a transaction across the wide row.
  static Color get stripe => blue.withValues(alpha: isLight ? 0.04 : 0.05);

  /// A register row under the pointer: clearly lighter than [stripe], so
  /// hovering never looks like the row next door. Below the selected row's
  /// [blueWash] and outline.
  static Color get rowHover => _p.wash.withValues(alpha: isLight ? 0.06 : 0.08);

  // The sidebar is gray denim in both modes, so it has its own light text.
  static const side = Color(0xFF243550);
  static const sideInk = Color(0xFFECEFF4);
  static const sideInk2 = Color(0xFFC6CFDD);
  static const sideInk3 = Color(0xFF98A4B8);
  static const sideBlue = Color(0xFF6FA8F0);
  static const sideCoral = Color(0xFFF08A8A);
  static const sideRule = Color(0x17FFFFFF);
  static const sideHover = Color(0x0DFFFFFF);
  static const sideSel = Color(0x1AFFFFFF);

  /// Sun yellow: the sidebar's marks (open section, chosen account's edge).
  static const sun = Color(0xFFF5C518);
}

const _weights = {
  400: FontWeight.w400,
  500: FontWeight.w500,
  600: FontWeight.w600,
};

/// Onest is bundled as a variable font; weight has to go through the axis.
TextStyle onest(
  double size, {
  int weight = 400,
  Color? color,
  bool tabular = false,
  double? letterSpacing,
  double? height,
}) => TextStyle(
  fontFamily: 'Onest',
  fontFamilyFallback: const ['Manrope'],
  fontSize: size,
  fontWeight: _weights[weight],
  fontVariations: [FontVariation('wght', weight.toDouble())],
  fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
  color: color ?? Mid.ink,
  letterSpacing: letterSpacing,
  height: height,
);

ThemeData appTheme() => ThemeData(
  brightness: Mid.palette.brightness,
  scaffoldBackgroundColor: Mid.ground,
  fontFamily: 'Onest',
  // Not generated from a seed: any Material default stays in the palette.
  colorScheme:
      (Mid.isLight ? const ColorScheme.light() : const ColorScheme.dark())
          .copyWith(
            primary: Mid.blue,
            onPrimary: Mid.onAccent,
            surface: Mid.panel,
            onSurface: Mid.ink,
            error: Mid.coral,
          ),
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(
      color: Mid.raised,
      borderRadius: BorderRadius.circular(6),
    ),
    textStyle: onest(12, color: Mid.ink),
    waitDuration: const Duration(milliseconds: 400),
  ),
  textSelectionTheme: TextSelectionThemeData(
    cursorColor: Mid.blue,
    selectionColor: Mid.blue.withValues(alpha: 0.35),
  ),
  splashFactory: NoSplash.splashFactory,
  highlightColor: Colors.transparent,
);

/// `09.16`, for places where the year is obvious (header notes, chart).
String shortDate(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

/// `2026.09.16` — the YYYY.MM.DD convention used on every transaction.
String fullDate(DateTime d) => '${d.year}.${shortDate(d)}';

/// Amount with the cents quieter than the whole part.
class Money extends StatelessWidget {
  const Money(
    this.minor, {
    super.key,
    this.size = 14.5,
    this.weight = 400,
    this.color,
    this.centsColor,
    this.centsScale = 1,
    this.sign = MoneySign.negativeOnly,
    this.letterSpacing,
  });

  final int minor;
  final double size;
  final int weight;
  final Color? color;
  final Color? centsColor;
  final double centsScale;
  final MoneySign sign;
  final double? letterSpacing;

  @override
  Widget build(BuildContext context) {
    final prefix = switch (sign) {
      MoneySign.none => '',
      MoneySign.negativeOnly => minor < 0 ? '−' : '',
      MoneySign.plusForPositive => minor > 0 ? '+' : (minor < 0 ? '−' : ''),
    };
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$prefix₮${formatWhole(minor)}',
            style: onest(
              size,
              weight: weight,
              color: color,
              tabular: true,
              letterSpacing: letterSpacing,
            ),
          ),
          TextSpan(
            text: formatCents(minor),
            style: onest(
              size * centsScale,
              weight: 400,
              color: centsColor ?? Mid.ink3,
              tabular: true,
            ),
          ),
        ],
      ),
      maxLines: 1,
      softWrap: false,
    );
  }
}

enum MoneySign { none, negativeOnly, plusForPositive }

/// Cleared state: clock = uncleared (waiting to clear) · ✓ cleared ·
/// ◆ reconciled (gold, from the mark). Not an empty circle, which reads as a
/// checkbox, and not a dash, which reads as a minus in the header's sum.
class StatusGlyph extends StatelessWidget {
  const StatusGlyph(this.status, {super.key, this.color});

  final Cleared status;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 12,
    height: 12,
    child: switch (status) {
      Cleared.uncleared => CustomPaint(
        painter: _ClockPainter(color ?? Mid.ink3),
      ),
      Cleared.cleared => CustomPaint(painter: _CheckPainter(color ?? Mid.ink2)),
      Cleared.reconciled => Center(
        child: Diamond(size: 7, color: color ?? Mid.gold),
      ),
    },
  );
}

class _ClockPainter extends CustomPainter {
  _ClockPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, 5, paint);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - 2.8)
        ..lineTo(c.dx, c.dy)
        ..lineTo(c.dx + 2.2, c.dy + 1.3),
      paint..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ClockPainter old) => old.color != color;
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(2.2, 6.4)
      ..lineTo(4.9, 9.1)
      ..lineTo(9.8, 3.2);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.color != color;
}

class Diamond extends StatelessWidget {
  const Diamond({super.key, this.size = 10, this.color});
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: 0.785398,
    child: Container(width: size, height: size, color: color ?? Mid.gold),
  );
}
