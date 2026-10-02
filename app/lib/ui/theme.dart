import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/ledger.dart';
import '../domain/money.dart';
import 'schemes.dart';

/// One set of colors for the whole app. The app's own are Steppe night
/// (dark) and Steppe (light), with the same gray denim sidebar (owner,
/// 2026-09-29; ADR 0004); [Palette.of] makes a pair from any [Scheme].
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
    required this.side,
    required this.sideInk,
    required this.sideInk2,
    required this.sideInk3,
    required this.sideBlue,
    required this.sun,
  });

  final Brightness brightness;
  final Color ground, panel, card, raised, rule, ink, ink2, ink3;
  final Color blue, gold, green, coral;

  /// Text and icons on a filled blue, gold or green button or toast.
  final Color onAccent;

  /// The base of the faint chip, hover and row tints: light on dark, dark on
  /// light.
  final Color wash;

  /// The sidebar is dark in both modes, so it has its own light text.
  final Color side, sideInk, sideInk2, sideInk3, sideBlue;

  /// The sidebar's marks (open section, chosen account's edge).
  final Color sun;

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
    side: _denim,
    sideInk: _sideInk,
    sideInk2: _sideInk2,
    sideInk3: _sideInk3,
    sideBlue: _sideBlue,
    sun: _sun,
  );

  /// Steppe: a warm felt-cream page under white cards, steppe blue for what
  /// you click, a deeper gold and green that read on white.
  static const light = Palette(
    brightness: Brightness.light,
    ground: _felt,
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
    side: _denim,
    sideInk: _sideInk,
    sideInk2: _sideInk2,
    sideInk3: _sideInk3,
    sideBlue: _sideBlue,
    sun: _sun,
  );

  static const _denim = Color(0xFF243550);
  static const _sideInk = Color(0xFFECEFF4);
  static const _sideInk2 = Color(0xFFC6CFDD);
  static const _sideInk3 = Color(0xFF98A4B8);
  static const _sideBlue = Color(0xFF6FA8F0);
  static const _sun = Color(0xFFF5C518);
  static const _felt = Color(0xFFF6F1E7);

  static final _made = <(String, Brightness), Palette>{};

  /// [scheme]'s colors in light or dark. The same object each time, so a
  /// switch that changes nothing redraws nothing.
  static Palette of(Scheme scheme, Brightness brightness) {
    if (scheme.id == betterBudgetScheme.id) {
      return brightness == Brightness.light ? light : dark;
    }
    return _made.putIfAbsent((
      scheme.id,
      brightness,
    ), () => _from(scheme.colors, brightness));
  }

  /// How four colors become the app's. The darkest is the sidebar (made dark
  /// enough for its light text), the most colorful is what you click, and
  /// the page takes the darkest's hue in dark mode and the lightest's in
  /// light mode. Surfaces and text sit at the same brightness as the app's
  /// own palettes, and every color is moved until it reads, so money's
  /// green, gold and coral mean the same in every scheme.
  static Palette _from(List<Color> colors, Brightness brightness) {
    final byLight = [...colors]..sort((a, b) => _lum(a).compareTo(_lum(b)));
    final darkest = byLight.first, lightest = byLight.last;
    final byChroma = [...colors]
      ..sort((a, b) => _chroma(b).compareTo(_chroma(a)));
    // What you click never takes a money color's hue (red, gold, green), so a
    // scheme can't make a button look like a shortfall or money in; nor a
    // gray, which would read as text. With none left, the steppe sky blue.
    final raw = byChroma.firstWhere(
      (c) => _chroma(c) >= 0.12 && !_moneyHue(c, gold: true),
      orElse: () => _sideBlue,
    );
    final picked = HSLColor.fromColor(raw);
    // Never as gray as the text: a muted blue is given some color.
    final accent = picked
        .withSaturation(math.max(picked.saturation, 0.4))
        .toColor();
    // The sidebar's marks may be gold (the app's own is sun yellow), never
    // red or green.
    final mark = byChroma.firstWhere(
      (c) => c != raw && _chroma(c) >= 0.12 && !_moneyHue(c, gold: false),
      orElse: () => _sun,
    );

    final base = HSLColor.fromColor(darkest);
    Color tone(HSLColor c, double maxSat, double lum) =>
        _atLum(c.withSaturation(math.min(c.saturation, maxSat)), lum);
    final side = tone(base, 0.7, _lum(darkest).clamp(0.012, 0.04).toDouble());
    final sideHsl = HSLColor.fromColor(side);
    final sideInk3 = _until(tone(sideHsl, 0.18, 0.37), side, 4.5);

    final light = brightness == Brightness.light;
    final page = light ? HSLColor.fromColor(lightest) : base;
    final inkHue = base;
    Color surface(double lum) => tone(page, light ? 0.55 : 0.45, lum);
    final ground = surface(light ? 0.86 : 0.0075);
    final panel = light ? const Color(0xFFFFFFFF) : surface(0.011);
    final card = light ? const Color(0xFFFFFFFF) : surface(0.0165);
    final raised = surface(light ? 0.78 : 0.026);
    final inkBase = tone(inkHue, light ? 0.3 : 0.18, light ? 0.016 : 0.85);
    // Text is checked against the page, the darkest of the surfaces it sits
    // on in light mode and the lightest (raised) in dark mode.
    final behind = light ? ground : raised;
    final ink2 = _until(tone(inkHue, 0.2, light ? 0.09 : 0.44), behind, 6);
    final ink3 = _until(tone(inkHue, 0.2, light ? 0.16 : 0.30), behind, 4.5);
    final blue = _until(accent, light ? ground : card, 4.5);
    final onAccent = _contrast(light ? Colors.white : ground, blue) >= 4.5
        ? (light ? Colors.white : ground)
        : (_contrast(inkBase, blue) > _contrast(Colors.white, blue)
              ? inkBase
              : Colors.white);
    final fixed = light ? Palette.light : Palette.dark;
    return Palette(
      brightness: brightness,
      ground: ground,
      panel: panel,
      card: card,
      raised: raised,
      rule: inkBase.withValues(alpha: light ? 0.12 : 0.1),
      ink: inkBase,
      ink2: ink2,
      ink3: ink3,
      blue: blue,
      gold: fixed.gold,
      green: fixed.green,
      coral: fixed.coral,
      onAccent: onAccent,
      wash: inkBase,
      side: side,
      sideInk: tone(sideHsl, 0.18, 0.85),
      sideInk2: _until(tone(sideHsl, 0.18, 0.6), side, 7),
      sideInk3: sideInk3,
      sideBlue: _until(accent, side, 4.5),
      sun: _until(mark, side, 3),
    );
  }
}

/// Relative luminance (WCAG).
double _lum(Color c) => c.computeLuminance();

double _contrast(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

/// Near coral's red or orange, money-in green, or (with [gold]) the gold of
/// reconciled and scheduled.
bool _moneyHue(Color c, {required bool gold}) {
  final h = HSLColor.fromColor(c).hue;
  return h < 30 || h >= 335 || (h >= 85 && h < 165) || (gold && h < 65);
}

double _chroma(Color c) {
  final r = c.r, g = c.g, b = c.b;
  return math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));
}

/// [c]'s hue and saturation at the lightness that gives luminance [lum].
Color _atLum(HSLColor c, double lum) {
  var lo = 0.0, hi = 1.0;
  for (var i = 0; i < 24; i++) {
    final mid = (lo + hi) / 2;
    if (_lum(c.withLightness(mid).toColor()) < lum) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return c.withLightness((lo + hi) / 2).toColor();
}

/// [c], lighter or darker (away from [against]) until the two differ by
/// [ratio]. Hue and saturation stay.
Color _until(Color c, Color against, double ratio) {
  if (_contrast(c, against) >= ratio) return c;
  final hsl = HSLColor.fromColor(c);
  final up = _lum(against) < 0.18;
  var l = hsl.lightness;
  while (_contrast(hsl.withLightness(l).toColor(), against) < ratio) {
    l += up ? 0.005 : -0.005;
    if (l <= 0 || l >= 1) return up ? Colors.white : Colors.black;
  }
  return hsl.withLightness(l).toColor();
}

/// The colors in use, read everywhere as `Mid.ink` and so on. [AppearanceScope]
/// switches them and rebuilds the app.
abstract final class Mid {
  static Palette palette = Palette.of(defaultScheme, Brightness.dark);
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

  // The sidebar is dark in both modes, so it has its own light text.
  static Color get side => _p.side;
  static Color get sideInk => _p.sideInk;
  static Color get sideInk2 => _p.sideInk2;
  static Color get sideInk3 => _p.sideInk3;
  static Color get sideBlue => _p.sideBlue;
  static const sideCoral = Color(0xFFF08A8A);
  static const sideRule = Color(0x17FFFFFF);
  static const sideHover = Color(0x0DFFFFFF);
  static const sideSel = Color(0x1AFFFFFF);

  /// The sidebar's marks (open section, chosen account's edge): sun yellow
  /// in the app's own colors.
  static Color get sun => _p.sun;
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
  fontFamilyFallback: const ['Manrope', 'BetterBudget Symbols'],
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

/// The currency the amounts below it are in: an account's page, one row of
/// All accounts, a dialog about one account. Tugrik when nothing says.
class CurrencyScope extends InheritedWidget {
  const CurrencyScope({
    super.key,
    required this.currency,
    required super.child,
  });
  final Currency currency;

  static Currency of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CurrencyScope>()?.currency ??
      Currency.mnt;

  @override
  bool updateShouldNotify(CurrencyScope old) => old.currency != currency;
}

/// [minor] in the currency of where it's shown: `₮4,182,450.00`.
String moneyIn(BuildContext context, int minor, {bool showCents = true}) =>
    formatMoney(
      minor,
      showCents: showCents,
      currency: CurrencyScope.of(context),
    );

/// Whole units in the currency of where it's shown: `−₮4,182,450`.
String roundedIn(BuildContext context, int minor) =>
    formatRounded(minor, currency: CurrencyScope.of(context));

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
    this.currency,
  });

  /// Null: the [CurrencyScope]'s.
  final Currency? currency;

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
    final currency = this.currency ?? CurrencyScope.of(context);
    final prefix = switch (sign) {
      MoneySign.none => '',
      MoneySign.negativeOnly => minor < 0 ? '−' : '',
      MoneySign.plusForPositive => minor > 0 ? '+' : (minor < 0 ? '−' : ''),
    };
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$prefix${currency.prefix}${formatWhole(minor, currency)}',
            style: onest(
              size,
              weight: weight,
              color: color,
              tabular: true,
              letterSpacing: letterSpacing,
            ),
          ),
          TextSpan(
            text: formatCents(minor, currency),
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
