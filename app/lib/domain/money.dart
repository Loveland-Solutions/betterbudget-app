/// Money is always integer minor units, counted in the currency's own
/// decimals: 2 for tugrik and dollars, none for yen, 3 for a Kuwaiti dinar
/// (ADR 0001).
library;

part 'currencies.dart';

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

  /// Whether [minor] has a part smaller than one whole unit.
  bool hasCents(int minor) => minor % scale != 0;

  static final _byCode = {for (final c in values) c.code: c};

  /// A code this build doesn't know reads as tugrik.
  static Currency fromCode(String? code) => _byCode[code] ?? Currency.mnt;

  @override
  String toString() => code;
}

/// `4182450` for 418245000 minor units, with thousands separators.
String formatWhole(int minor, [Currency currency = Currency.mnt]) {
  final digits = (minor.abs() ~/ currency.scale).toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// The `.00` part, as many digits as the currency has; nothing for one
/// with none.
String formatCents(int minor, [Currency currency = Currency.mnt]) =>
    currency.decimals == 0
    ? ''
    : '.${(minor.abs() % currency.scale).toString().padLeft(currency.decimals, '0')}';

/// `₮4,182,450.00`, `$1,250.00` or `¥1,250`, with a leading minus sign for
/// negatives.
String formatMoney(
  int minor, {
  bool showCents = true,
  Currency currency = Currency.mnt,
}) =>
    '${minor < 0 ? '−' : ''}${currency.prefix}${formatWhole(minor, currency)}${showCents ? formatCents(minor, currency) : ''}';

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
    '${currency.prefix}0${formatCents(0, currency)}';

/// An amount as it's typed back into a field: `900,000`, `276,650.50`.
String typedAmount(int minor, Currency currency) =>
    '${formatWhole(minor, currency)}${currency.hasCents(minor) ? formatCents(minor, currency) : ''}';

/// `₮4,182,450` or `−$1,250`: whole units only.
String formatRounded(int minor, {Currency currency = Currency.mnt}) =>
    '${minor < 0 ? '−' : ''}${currency.prefix}${formatWhole(minor, currency)}';

/// Parses what a person types into an amount field, including arithmetic:
/// `12000+8500`, `3 * 4500`, `1,250.50`. Returns minor units, or null when the
/// input is not a valid expression. `*` and `/` bind tighter than `+` and `-`.
/// [currency] decides how many decimals count: `1200.5` isn't yen.
int? parseAmount(String input, [Currency currency = Currency.mnt]) {
  final scale = currency.scale;
  final d = currency.decimals;
  final src = input
      .replaceAll(currency.long, '')
      .replaceAll(currency.symbol, '')
      .replaceAll(RegExp(r'[\s,₮$]'), '');
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
      if (op == '/') {
        if (rhs == 0) return null;
        acc = (acc! * scale / rhs).round();
      } else {
        acc = (acc! * rhs / scale).round();
      }
    }
    return acc;
  }

  var total = term();
  if (total == null) return null;
  while (peek() == '+' || peek() == '-') {
    final op = tokens[pos++].group(0);
    final rhs = term();
    if (rhs == null) return null;
    total = op == '+' ? total! + rhs : total! - rhs;
  }
  return pos == tokens.length ? total : null;
}
