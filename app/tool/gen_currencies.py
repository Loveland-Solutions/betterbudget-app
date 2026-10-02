#!/usr/bin/env python3
"""Writes lib/domain/currencies.dart and lib/l10n/currency_names.dart.

Run by hand when ISO 4217 changes; the app never downloads anything.

  python3 tool/gen_currencies.py list-one.xml cldr-en.json cldr-mn.json

- list-one.xml: ISO 4217 "List One" from SIX (the standard's maintainer).
- cldr-en.json, cldr-mn.json: `currencies.json` for `en` and `mn` from
  Unicode CLDR's cldr-numbers-full.

Every currency has a symbol (owner, 2026-10-02): the one people who use it
write. CLDR's short one where it has one (`$` for every dollar and peso,
`¥`, `zł`, `R`); for the rest, SYMBOLS below. Many share one, so each also
has a long form for a ledger that holds two of them: CLDR's longer symbol
(`CA$`, `CN¥`) or its code. The long forms are all different.

Every symbol must be drawable by Manrope or BetterBudget Symbols
(tool/gen_symbol_font.py); the tool stops if one isn't.
"""
import collections, json, struct, sys
import xml.etree.ElementTree as ET

# Currencies CLDR gives no short symbol: the sign or abbreviation in common
# use (central banks, price tags), checked against xsolla/currency-format
# where it has one. Where the native symbol is in Arabic script, the Latin
# abbreviation used beside English is given (`KD`, `Dh`): the app's
# languages run left to right.
SYMBOLS = {
    'AED': 'Dh', 'AFN': 'Af', 'ALL': 'L', 'AMD': '֏', 'AWG': 'ƒ',
    'AZN': '₼', 'BDT': '৳', 'BHD': 'BD', 'BIF': 'FBu', 'BTN': 'Nu.',
    'BYN': 'Br', 'CDF': 'FC', 'CHF': 'Fr.', 'CRC': '₡', 'CVE': 'Esc',
    'DJF': 'Fdj', 'DZD': 'DA', 'ERN': 'Nfk', 'ETB': 'Br', 'GEL': '₾',
    'GHS': 'GH₵', 'GMD': 'D', 'HTG': 'G', 'IQD': 'ID', 'IRR': 'Rl',
    'JOD': 'JD', 'KES': 'KSh', 'KGS': '⃀', 'KHR': '៛', 'KWD': 'KD',
    'KZT': '₸', 'LAK': '₭', 'LSL': 'L', 'LYD': 'LD', 'MAD': 'DH',
    'MDL': 'L', 'MKD': 'ден', 'MOP': 'MOP$', 'MRU': 'UM', 'MVR': 'Rf',
    'MWK': 'MK', 'MZN': 'MT', 'NGN': '₦', 'OMR': 'RO', 'PAB': 'B/.',
    'PEN': 'S/', 'PGK': 'K', 'PYG': '₲', 'QAR': 'QR', 'RSD': 'дин.',
    'SAR': 'SR', 'SCR': 'SR', 'SDG': 'LS', 'SLE': 'Le', 'SOS': 'Sh.So.',
    'SVC': '₡', 'SZL': 'E', 'THB': '฿', 'TJS': 'SM', 'TMT': 'm',
    'TND': 'DT', 'TZS': 'TSh', 'UGX': 'USh', 'UZS': 'so’m', 'VED': 'Bs.D',
    'VES': 'Bs.S', 'VUV': 'VT', 'WST': 'WS$', 'XOF': 'CFA', 'YER': 'YR',
    'ZWG': 'ZiG',
}

# Not in CLDR's Mongolian yet: drafts for the native speaker's check.
MN_MISSING = {
    'SVC': 'Сальвадорын колон',
    'VED': 'Венесуэлийн боливар соберано',
}


def glyphs(path):
    d = open(path, 'rb').read()
    n = struct.unpack('>H', d[4:6])[0]
    tabs = {}
    for i in range(n):
        tag, _, off, ln = struct.unpack('>4sIII', d[12 + 16 * i:28 + 16 * i])
        tabs[tag] = off
    off = tabs[b'cmap']
    cps = set()
    for i in range(struct.unpack('>H', d[off + 2:off + 4])[0]):
        _, _, so = struct.unpack('>HHI', d[off + 4 + 8 * i:off + 12 + 8 * i])
        o = off + so
        fmt = struct.unpack('>H', d[o:o + 2])[0]
        if fmt == 4:
            x2 = struct.unpack('>H', d[o + 6:o + 8])[0]
            sc = x2 // 2
            ends = struct.unpack('>%dH' % sc, d[o + 14:o + 14 + x2])
            starts = struct.unpack('>%dH' % sc, d[o + 16 + x2:o + 16 + 2 * x2])
            deltas = struct.unpack('>%dh' % sc,
                                   d[o + 16 + 2 * x2:o + 16 + 3 * x2])
            ro = o + 16 + 3 * x2
            ros = struct.unpack('>%dH' % sc, d[ro:ro + x2])
            for k in range(sc):
                for c in range(starts[k], ends[k] + 1):
                    if c == 0xFFFF:
                        continue
                    if ros[k] == 0:
                        g = (c + deltas[k]) & 0xFFFF
                    else:
                        p = ro + 2 * k + ros[k] + 2 * (c - starts[k])
                        g = struct.unpack('>H', d[p:p + 2])[0]
                    if g:
                        cps.add(c)
        elif fmt == 12:
            for k in range(struct.unpack('>I', d[o + 12:o + 16])[0]):
                s, e, _ = struct.unpack('>III', d[o + 16 + 12 * k:o + 28 + 12 * k])
                cps.update(range(s, e + 1))
    return cps


def main(iso, cldr_en, cldr_mn):
    root = ET.parse(iso).getroot()
    cur = collections.OrderedDict()
    for e in root.iter('CcyNtry'):
        code = e.findtext('Ccy')
        if not code:
            continue
        nm = e.find('CcyNm')
        minor = e.findtext('CcyMnrUnts')
        # Funds, metals, bond units, the test code: not money a person holds.
        if nm.get('IsFund') == 'true' or minor == 'N.A.':
            continue
        cur.setdefault(code, int(minor))
    en = json.load(open(cldr_en))['main']['en']['numbers']['currencies']
    mn = json.load(open(cldr_mn))['main']['mn']['numbers']['currencies']
    font = glyphs('assets/fonts/Manrope-Variable.ttf') | glyphs(
        'assets/fonts/BetterBudgetSymbols.ttf')
    drawn = lambda s: all(ord(ch) in font for ch in s)
    symbol, long = {}, {}
    for c in cur:
        en[c].setdefault('symbol', c)
    for c in cur:
        n = en[c].get('symbol-alt-narrow') or en[c]['symbol']
        if n == c or not drawn(n):
            n = SYMBOLS[c]
        assert drawn(n), 'no glyph for %s %s' % (c, n)
        assert n != c
        symbol[c] = n
        l = en[c]['symbol']
        long[c] = l if drawn(l) else c
    # USD is `$` in both: every other dollar has a longer form or its code.
    count = collections.Counter(long.values())
    for c in cur:
        if count[long[c]] > 1 and c != 'USD':
            long[c] = c
    assert len(set(long.values())) == len(long), 'two share a long form'
    order = ['MNT', 'USD'] + sorted(c for c in cur if c not in ('MNT', 'USD'))

    def q(s):
        return "r'%s'" % s if '$' in s else "'%s'" % s.replace("'", "\\'")

    head = ('// Made by tool/gen_currencies.py from ISO 4217 List One (published '
            '%s)\n// and Unicode CLDR. Change the tool, not this file.\n'
            % root.get('Pblshd'))
    out = [head, "part of 'money.dart';\n",
           '/// Every currency a person can hold, tugrik and dollars first '
           '(the two the\n/// app began with), then by code.',
           'const _currencies = <Currency>[', '  Currency.mnt,', '  Currency.usd,']
    for c in order[2:]:
        out.append('  Currency(%s, %s, %d%s),' % (
            q(c), q(symbol[c]), cur[c],
            '' if long[c] == c else ', ' + q(long[c])))
    out.append('];\n')
    open('lib/domain/currencies.dart', 'w').write('\n'.join(out))
    assert symbol['MNT'] == '₮' and symbol['USD'] == '$'
    assert cur['MNT'] == 2 and cur['USD'] == 2

    def title(s):
        # CLDR's English names are in title case but for a few new ones.
        return ' '.join(w if w in ('and', 'of') else w[:1].upper() + w[1:]
                        for w in s.split(' '))

    def cap(s):
        return s[:1].upper() + s[1:]

    names = [head,
             '/// What each currency is called, by its ISO code, in English '
             'and in\n/// Mongolian (a draft, like the rest of the Mongolian).',
             'const currencyNamesEn = <String, String>{']
    for c in order:
        names.append('  %s: %s,' % (q(c), q(title(en[c]['displayName']))))
    names += ['};\n', 'const currencyNamesMn = <String, String>{']
    for c in order:
        name = mn.get(c, {}).get('displayName') or MN_MISSING[c]
        names.append('  %s: %s,' % (q(c), q(cap(name))))
    names.append('};\n')
    open('lib/l10n/currency_names.dart', 'w').write('\n'.join(names))
    print(len(order), 'currencies')
    return order, symbol, cur, en, mn


if __name__ == '__main__':
    main(*sys.argv[1:4])
