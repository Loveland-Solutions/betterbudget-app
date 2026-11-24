/// Money is always integer minor units, counted in the currency's own
/// decimals: 2 for tugrik and dollars, none for yen, 3 for a Kuwaiti dinar
/// (ADR 0001).
library;

part 'currencies.dart';
part 'number_styles.dart';

/// How a currency's people write an amount: the mark before the cents and
/// the one between thousands, `1.000.000,95` in rupiah, `1 234,95` in
/// rubles (#621). Taken from Unicode CLDR by `tool/gen_number_styles.py`.
class NumberStyle {
  const NumberStyle({this.point = '.', this.group = ',', this.whole = false});

  /// `1,234.95`, tugrik's and the dollar's.
  static const plain = NumberStyle();

  /// What stands before the cents: `.` or `,`.
  final String point;

  /// What goes between thousands: `,`, `.`, a no-break space or `'`.
  final String group;

  /// Its people don't write cents, though it has some (the rupiah, the
  /// forint): amounts show them only when there are some.
  final bool whole;
}

/// A currency an account can be in: any ISO 4217 currency a person can
/// hold (`docs/currencies.md`). Totals across currencies are never added
/// together (ROADMAP E: each is shown on its own line).
class Currency {
  const Currency(this.code, this.symbol, this.decimals, [String? long])
    : long = long ?? code;

  static const mnt = Currency('MNT', '₮', 2);
  static const usd = Currency('USD', r'$', 2, r'$');

  /// Every currency, tugrik and dollars first, then by code.
  static const List<Currency> values = _currencies;

  /// As stored in `accounts.currency` and `entries.currency`.
  final String code;

  /// What the people who use it write: `₮`, `$` (every dollar and peso),
  /// `¥`, `zł`, `KD`. Every currency has one; many share one.
  final String symbol;

  /// What tells it from another currency with the same [symbol]: `CA$`,
  /// `CN¥`, or its code. No two currencies share one.
  final String long;

  /// The currencies of the ledger that's open that share a symbol with
  /// another one in it: a Canadian account beside a US one. Set by [hold].
  static Set<Currency> _clashing = const {};

  /// Tells amounts which currencies the open ledger holds, so two that
  /// share a symbol are told apart ([shown]) and one alone reads as its
  /// people write it.
  static void hold(Iterable<Currency> held) {
    final by = <String, Set<Currency>>{};
    for (final c in held) {
      by.putIfAbsent(c.symbol, () => {}).add(c);
    }
    _clashing = {
      for (final group in by.values)
        if (group.length > 1) ...group,
    };
  }

  /// The symbol as amounts show it in the open ledger: [symbol], or [long]
  /// while another currency in the ledger has the same symbol.
  String get shown => _clashing.contains(this) ? long : symbol;

  /// The digits after the point.
  final int decimals;

  /// Minor units in one whole unit: 100 for tugrik, 1 for yen.
  int get scale => const [1, 10, 100, 1000, 10000][decimals];

  /// [shown] as it stands before an amount: a sign sits against it
  /// (`₮1,200.00`, `CA$1,200.00`), letters and the like are set off by a
  /// space (`kr 1,200.00`, `S/ 1,200.00`, `Fr. 1,200.00`).
  String get prefix {
    final s = shown;
    return RegExp(r'\p{Sc}$', unicode: true).hasMatch(s) ? s : '$s ';
  }

  /// How its people write an amount (#621).
  NumberStyle get style => _styles[code] ?? NumberStyle.plain;

  /// The mark before the cents: `.`, or `,` for the rupiah or the euro.
  String get point => style.point;

  /// Whether [minor] has a part smaller than one whole unit.
  bool hasCents(int minor) => minor % scale != 0;

  static final _byCode = {for (final c in values) c.code: c};

  /// A code this build doesn't know reads as tugrik.
  static Currency fromCode(String? code) => _byCode[code] ?? Currency.mnt;

  @override
  String toString() => code;
}

/// `4,182,450` for 418245000 minor units, grouped in thousands as the
/// currency's people do: `4.182.450` in rupiah.
String formatWhole(int minor, [Currency currency = Currency.mnt]) =>
    _grouped((minor.abs() ~/ currency.scale).toString(), currency.style.group);

String _grouped(String digits, String group) {
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(group);
    out.write(digits[i]);
  }
  return out.toString();
}

/// The `.00` part (`,00` in rupiah), as many digits as the currency has;
/// nothing for one with none.
String formatCents(int minor, [Currency currency = Currency.mnt]) =>
    currency.decimals == 0
    ? ''
    : '${currency.point}${(minor.abs() % currency.scale).toString().padLeft(currency.decimals, '0')}';

/// [formatCents] where an amount shows its cents: always, but for a
/// currency whose people don't write them ([NumberStyle.whole]), only
/// when there are some.
String shownCents(int minor, Currency currency) =>
    currency.style.whole && !currency.hasCents(minor)
    ? ''
    : formatCents(minor, currency);

/// `₮4,182,450.00`, `$1,250.00` or `¥1,250`, with a leading minus sign for
/// negatives.
String formatMoney(
  int minor, {
  bool showCents = true,
  Currency currency = Currency.mnt,
}) =>
    '${minor < 0 ? '−' : ''}${currency.prefix}${formatWhole(minor, currency)}${showCents ? shownCents(minor, currency) : ''}';

/// As [formatMoney], with the cents only when there are some: `₮900,000`,
/// `₮276,650.50`.
String formatShort(int minor, {Currency currency = Currency.mnt}) =>
    formatMoney(minor, showCents: currency.hasCents(minor), currency: currency);

/// The rate the two sides of a transfer between currencies make (either
/// way round): what one whole unit of the dearer currency ([base]) costs in
/// the other, in that one's minor units. `₮3,450.00 per $1`. Null until
/// both amounts are there.
({int rate, Currency quote, Currency base})? exchangeRate(
  int? a,
  Currency ca,
  int? b,
  Currency cb,
) {
  if (a == null || b == null || a == 0 || b == 0 || ca == cb) return null;
  // The dearer currency is the one fewer whole units of changed hands.
  final aIsBase = a.abs() * cb.scale <= b.abs() * ca.scale;
  final (base, baseMinor, quote, quoteMinor) = aIsBase
      ? (ca, a.abs(), cb, b.abs())
      : (cb, b.abs(), ca, a.abs());
  return (
    rate: (quoteMinor * base.scale / baseMinor).round(),
    quote: quote,
    base: base,
  );
}

/// What an amount field shows before anything is typed: `₮0.00`, `¥0`.
String zeroHint(Currency currency) =>
    '${currency.prefix}0${shownCents(0, currency)}';

/// An amount as it's typed back into a field: `900,000`, `276,650.50`.
String typedAmount(int minor, Currency currency) =>
    '${formatWhole(minor, currency)}${currency.hasCents(minor) ? formatCents(minor, currency) : ''}';

/// What's typed in an amount field with each number's whole part grouped in
/// thousands, as the field shows it while typing: `2500000` is `2,500,000`,
/// `12000+8500` is `12,000+8,500`, and in rupiah `2.500.000` (#621); digits
/// after the point aren't grouped (#324).
///
/// The mark between thousands goes wherever it is, as the field puts its
/// own, and so does a space between digits. Any other `.` or `,` is the
/// point. In a currency that puts `.` between thousands (the rupiah, the
/// euro), the `.` just typed at [typedAt] is the point too, as the number
/// pad's key and a phone's decimal key type it: `12.50` typed in euros is
/// `12,50`. There a point with exactly three digits after it stands between
/// thousands, so `50.000` typed in rupiah is fifty thousand. [offsets] are
/// places in [text] (the caret, a selection's ends); each comes back after
/// the same digit or sign it was after.
({String text, List<int> offsets}) groupTyped(
  String text,
  List<int> offsets, [
  Currency currency = Currency.mnt,
  int? typedAt,
]) {
  final style = currency.style;
  final dotGroups = style.group == '.';
  bool isMark(String c) => c == '.' || c == ',';
  // A digit next to [i] in direction [step], past any mark between thousands.
  bool digitBeside(int i, int step) {
    var j = i + step;
    while (j >= 0 && j < text.length && text[j] == style.group) {
      j += step;
    }
    return j >= 0 && j < text.length && _isDigit(text, j);
  }

  int digitsAfter(int i) {
    var j = i + 1;
    while (j < text.length && _isDigit(text, j)) {
      j++;
    }
    return j - i - 1;
  }

  // What the character at [i] becomes: itself, the point, or nothing.
  String? kept(int i) {
    final c = text[i];
    final point =
        (isMark(c) && c != style.group) ||
        (dotGroups && c == '.' && i == typedAt);
    if (point) {
      // Three digits after a point stand between thousands where a point does.
      if (dotGroups && currency.decimals < 3 && digitsAfter(i) == 3) {
        return null;
      }
      return style.point;
    }
    if (c == style.group) return null;
    if (RegExp(r'\s').hasMatch(c) && digitBeside(i, -1) && digitBeside(i, 1)) {
      return null;
    }
    return c;
  }

  final bare = StringBuffer();
  // For each place, how many characters other than those dropped came before.
  final kept0 = List.filled(offsets.length, 0);
  for (var i = 0; i < text.length; i++) {
    final k = kept(i);
    if (k == null) continue;
    for (var o = 0; o < offsets.length; o++) {
      if (i < offsets[o]) kept0[o]++;
    }
    bare.write(k);
  }
  final s = bare.toString();
  final out = StringBuffer();
  // Where each character of [s] lands in [out].
  final at = <int>[];
  var i = 0;
  while (i < s.length) {
    if (!_isDigit(s, i)) {
      at.add(out.length);
      out.write(s[i++]);
      continue;
    }
    var end = i;
    while (end < s.length && _isDigit(s, end)) {
      end++;
    }
    final grouped = i == 0 || s[i - 1] != style.point;
    for (var j = i; j < end; j++) {
      if (grouped && j > i && (end - j) % 3 == 0) out.write(style.group);
      at.add(out.length);
      out.write(s[j]);
    }
    i = end;
  }
  // Right after the character before it, ahead of any mark that follows.
  return (
    text: out.toString(),
    offsets: [for (final k in kept0) k == 0 ? 0 : at[k - 1] + 1],
  );
}

/// Each number in [src] with its marks read as the currency's people write
/// them, and written back with `.` before the cents and nothing between
/// thousands: `1.000.000,95` in rupiah is `1000000.95` (#621).
///
/// A number with both `.` and `,` has its cents after the last of them,
/// whichever currency it's in, so `1,000,000.95` typed in rupiah is read
/// as meant. With one kind of mark, the currency's mark between thousands
/// is that, where three digits follow each (`1.500` in rupiah, `1,500` in
/// dollars); the other is the point. One mark between thousands with fewer
/// digits after it than the cents have is a point too: `12,5` in dollars
/// is twelve and a half, not 125. Two points that aren't a thousands
/// pattern stay, for the reader to call it wrong.
String _plainNumbers(String src, Currency currency) {
  final style = currency.style;
  final g = style.group == '.' || style.group == ',' ? style.group : null;
  final d = currency.decimals;
  return src.replaceAllMapped(RegExp(r'[\d.,]+'), (m) {
    final n = m.group(0)!;
    final dot = n.lastIndexOf('.');
    final comma = n.lastIndexOf(',');
    if (dot >= 0 && comma >= 0) {
      final last = dot > comma ? dot : comma;
      return '${n.substring(0, last).replaceAll(RegExp('[.,]'), '')}.'
          '${n.substring(last + 1)}';
    }
    if (dot < 0 && comma < 0) return n;
    final mark = dot >= 0 ? '.' : ',';
    final count = mark.allMatches(n).length;
    final thousands = RegExp('^\\d{1,3}(?:${RegExp.escape(mark)}\\d{3})+\$')
        .hasMatch(n);
    if (mark != g) {
      // In rupiah or euros, `1,500` is what the field makes of `1.500` typed.
      final after = n.length - n.lastIndexOf(mark) - 1;
      if (count == 1 && g == '.' && d < 3 && after == 3) {
        return n.replaceAll(mark, '');
      }
      if (count == 1) return n.replaceAll(mark, '.');
      return thousands ? n.replaceAll(mark, '') : n.replaceAll(mark, '.');
    }
    if (thousands) return n.replaceAll(mark, '');
    final after = n.length - n.lastIndexOf(mark) - 1;
    if (count == 1 && d > 0 && after >= 1 && after < 3 && after <= d) {
      return n.replaceAll(mark, '.');
    }
    return n.replaceAll(mark, '');
  });
}

bool _isDigit(String s, int i) {
  final c = s.codeUnitAt(i);
  return c >= 0x30 && c <= 0x39;
}

/// `₮4,182,450` or `−$1,250`: whole units only, rounded to the nearest,
/// as the name says. It used to cut the part under a whole unit off, which
/// is right where the cents are shown beside it ([formatMoney]) and wrong
/// on its own: the forecast card's figures are all shown this way, and a
/// budget spread a day at a time leaves fractions, so the sum the card
/// draws could land ₮1 from the sum a person adds up (budget-app review;
/// arithmetic that's right can still confuse).
String formatRounded(int minor, {Currency currency = Currency.mnt}) {
  final scale = currency.scale;
  final whole = ((minor.abs() + scale ~/ 2) ~/ scale) * scale;
  return '${minor < 0 ? '−' : ''}${currency.prefix}'
      '${formatWhole(whole, currency)}';
}

/// Parses what a person types into an amount field, including arithmetic:
/// `12000+8500`, `3 * 4500`, `1,250.50`, `1.250,50` in rupiah ([_plainNumbers]).
/// Returns minor units, or null when the
/// input is not a valid expression. `*` and `/` bind tighter than `+` and `-`;
/// `×`, `x` between numbers, `÷` and `−` are read as those too (#547).
/// [currency] decides how many decimals count: `1200.5` isn't yen.
/// More than [mostWholeDigits] whole digits, typed or worked out, isn't an
/// amount: it would wrap round to a minus or throw (#163).
int? parseAmount(String input, [Currency currency = Currency.mnt]) {
  final most = _mostWhole * currency.scale;
  int? kept(int? v) => v == null || v.abs() > most ? null : v;
  final scale = currency.scale;
  final d = currency.decimals;
  final src = _plainNumbers(
    input
        .replaceAll(currency.long, '')
        .replaceAll(currency.symbol, '')
        // Spaces and apostrophes are only ever between thousands.
        .replaceAll(RegExp(r"[\s'’₮$]"), '')
        .replaceAllMapped(_otherSigns, (m) => _signFor[m.group(0)] ?? '*'),
    currency,
  );
  if (src.isEmpty) return null;
  // A point with nothing after it is fine while typing; digits after it
  // are only what the currency has.
  final digits = d == 0 ? r'\d+\.?' : '\\d+(?:\\.\\d{0,$d})?|\\.\\d{1,$d}';
  final tokens = RegExp('$digits|[+\\-*/×]').allMatches(src).toList();
  if (tokens.map((m) => m.group(0)!).join() != src) return null;

  var pos = 0;
  String? peek() => pos < tokens.length ? tokens[pos].group(0) : null;

  int? number() {
    var sign = 1;
    while (peek() == '-' || peek() == '+') {
      if (tokens[pos].group(0) == '-') sign = -sign;
      pos++;
    }
    final t = peek();
    if (t == null || !RegExp(r'^[\d.]').hasMatch(t)) return null;
    pos++;
    final parts = t.split('.');
    if (parts[0].length > mostWholeDigits) return null;
    final whole = parts[0].isEmpty ? 0 : int.parse(parts[0]);
    final frac = d == 0 || parts.length < 2 ? '' : parts[1];
    return sign *
        (whole * scale + int.parse(frac.padRight(d, '0').padLeft(1, '0')));
  }

  int? term() {
    var acc = number();
    if (acc == null) return null;
    while (peek() == '*' || peek() == '×' || peek() == '/') {
      final op = tokens[pos++].group(0);
      final rhs = number();
      if (rhs == null) return null;
      // As doubles: the product of two big amounts wraps round as ints.
      final worked = op == '/'
          ? (rhs == 0 ? null : acc!.toDouble() * scale / rhs)
          : acc!.toDouble() * rhs / scale;
      if (worked == null || worked.abs() > most) return null;
      acc = worked.round();
    }
    return acc;
  }

  var total = term();
  if (total == null) return null;
  while (peek() == '+' || peek() == '-') {
    final op = tokens[pos++].group(0);
    final rhs = term();
    if (rhs == null) return null;
    total = kept(op == '+' ? total! + rhs : total! - rhs);
    if (total == null) return null;
  }
  return pos == tokens.length ? total : null;
}

/// The signs people type or paste for a sum, other than `+ - * / ×`: `÷`,
/// the app's own minus `−`, and `x` or `X` between two numbers (#547), or
/// the Cyrillic `х` a Mongolian keyboard types in its place.
final _otherSigns = RegExp(r'[÷−]|(?<=[\d.,])[xXхХ](?=[\d.,])');
const _signFor = {'÷': '/', '−': '-'};

/// A sign that makes [text] a sum rather than one amount: one after a number.
final _sumSign = RegExp(r'[\d.,]\s*[+\-*/×÷−xXхХ]\s*[\d.,]');

/// [text] is a sum, not one amount: a sign after a number (`22+2`, `+22+2`).
bool isSum(String text) => _sumSign.hasMatch(text);

/// What an amount box shows once it's left (#547): a sum that works out, as
/// its answer, written the way the box would have it typed: `22+2` is `24`,
/// `12,000+8,500` is `20,500`, `10/3` is `3.33`. A `+` in front, which makes
/// a row money in, stays in front. Null when [text] is no sum, or a sum that
/// doesn't work out (`5/0`, `12+`): the box keeps what was typed, and shows
/// its usual problem.
String? sumAnswer(String text, [Currency currency = Currency.mnt]) {
  final t = text.trim();
  final plus = t.startsWith('+');
  final body = plus ? t.substring(1) : t;
  if (!isSum(body)) return null;
  final v = parseAmount(body, currency);
  // `+20-30` is money in of a minus: left as typed for the box to call wrong.
  if (v == null || (plus && v < 0)) return null;
  final answer = '${v < 0 ? '-' : ''}${typedAmount(v.abs(), currency)}';
  return plus ? '+$answer' : answer;
}

/// The most whole digits an amount typed may have: ₮999 trillion.
const mostWholeDigits = 15;
const _mostWhole = 999999999999999;
