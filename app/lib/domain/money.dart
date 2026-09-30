/// Money is always integer minor units. MNT has exponent 2 (ADR 0001).
library;

const int mntExponent = 2;
const int _scale = 100;

/// The currencies an account can be in. Both have two decimals, so minor
/// units work the same way; totals across them are never added together
/// (ROADMAP E: each currency is shown on its own line).
enum Currency {
  mnt('MNT', '₮'),
  usd('USD', r'$');

  const Currency(this.code, this.symbol);

  /// As stored in `accounts.currency` and `entries.currency`.
  final String code;
  final String symbol;

  static Currency fromCode(String? code) =>
      values.where((c) => c.code == code).firstOrNull ?? Currency.mnt;
}

/// `4182450` for 418245000 minor units, with thousands separators.
String formatWhole(int minor) {
  final digits = (minor.abs() ~/ _scale).toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// `.00` part, always two digits.
String formatCents(int minor) =>
    '.${(minor.abs() % _scale).toString().padLeft(2, '0')}';

/// `₮4,182,450.00` or `$1,250.00`, with a leading minus sign for negatives.
String formatMoney(
  int minor, {
  bool showCents = true,
  Currency currency = Currency.mnt,
}) =>
    '${minor < 0 ? '−' : ''}${currency.symbol}${formatWhole(minor)}${showCents ? formatCents(minor) : ''}';

/// Tugrik per dollar, in minor units, from the two sides of a transfer
/// between them (either way round). Null until both are there.
int? mntPerDollar(int? a, Currency ca, int? b, Currency cb) {
  if (a == null || b == null || a == 0 || b == 0 || ca == cb) return null;
  final (mnt, usd) = ca == Currency.mnt
      ? (a.abs(), b.abs())
      : (b.abs(), a.abs());
  return (mnt * 100 / usd).round();
}

/// `₮4,182,450` or `−$1,250`: whole units only.
String formatRounded(int minor, {Currency currency = Currency.mnt}) =>
    '${minor < 0 ? '−' : ''}${currency.symbol}${formatWhole(minor)}';

/// Parses what a person types into an amount field, including arithmetic:
/// `12000+8500`, `3 * 4500`, `1,250.50`. Returns minor units, or null when the
/// input is not a valid expression. `*` and `/` bind tighter than `+` and `-`.
int? parseAmount(String input) {
  final src = input.replaceAll(RegExp(r'[\s,₮$]'), '');
  if (src.isEmpty) return null;
  final tokens = RegExp(r'\d+(?:\.\d{0,2})?|\.\d{1,2}|[+\-*/×]')
      .allMatches(src)
      .toList();
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
    final frac = parts.length > 1 ? parts[1].padRight(2, '0') : '00';
    return sign * (whole * _scale + int.parse(frac));
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
        acc = (acc! * _scale / rhs).round();
      } else {
        acc = (acc! * rhs / _scale).round();
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
