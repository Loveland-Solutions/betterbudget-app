#!/usr/bin/env python3
"""Writes lib/domain/number_styles.dart: how each currency's people write an
amount (#621).

Run by hand when CLDR changes; the app never downloads anything.

  python3 tool/gen_number_styles.py <cldr-core> <cldr-numbers-full>

Both are the `package` folders of Unicode CLDR's JSON packages (npm
`cldr-core` and `cldr-numbers-full`).

A currency is written as in the country with the most people that pays in
it, in that country's most spoken official language: the rupiah as in
Indonesia, `1.000.000,95`; the euro as in Germany, `1.234,95`; the dollar as
in the United States, `1,234.95`. Its marks are that language's: what stands
before the cents, and what goes between thousands. A space between
thousands is a no-break space, so an amount never breaks across lines.

`whole` marks a currency whose people don't write cents though ISO gives it
some (the rupiah, the forint): its amounts show cents only when there are
some. What's stored doesn't change.

Only currencies written otherwise than `1,234.95` with cents are listed.
"""
import json, os, sys

# Where what people see on their statements isn't CLDR's: South African banks
# and receipts print `R1 234.56`, a point before the cents (review of #621).
OVERRIDES = {'ZAR': ('.', 'space')}

sys.path.insert(0, os.path.dirname(__file__))
from gen_currencies import glyphs  # noqa: E402


def main(core, numbers):
    sup = os.path.join(core, 'supplemental')
    cd = json.load(open(os.path.join(sup, 'currencyData.json')))[
        'supplemental']['currencyData']
    ti = json.load(open(os.path.join(sup, 'territoryInfo.json')))[
        'supplemental']['territoryInfo']
    ls = json.load(open(os.path.join(sup, 'likelySubtags.json')))[
        'supplemental']['likelySubtags']
    main_dir = os.path.join(numbers, 'main')
    src = open('lib/domain/currencies.dart').read()
    import re
    codes = ['MNT', 'USD'] + re.findall(r"Currency\('([A-Z]{3})'", src)
    decimals = {'MNT': 2, 'USD': 2}
    decimals.update((c, int(d)) for c, d in re.findall(
        r"Currency\('([A-Z]{3})', r?'(?:[^'\\]|\\.)*', (\d)", src))

    # Where each currency is money people pay with today.
    where = {}
    for terr, lst in cd['region'].items():
        for e in lst:
            for cur, v in e.items():
                if '_to' not in v and v.get('_tender') != 'false':
                    where.setdefault(cur, []).append(terr)

    def people(t):
        return float(ti.get(t, {}).get('_population', 0))

    def language(t):
        lp = ti.get(t, {}).get('languagePopulation', {})
        official = sorted(
            ((float(v.get('_populationPercent', 0)), k) for k, v in lp.items()
             if 'official' in v.get('_officialStatus', '')), reverse=True)
        if official:
            return official[0][1].replace('_', '-')
        # CLDR leaves English out of the likely languages: it's the default.
        return ls.get('und-' + t, 'en-Latn-US').split('-')[0]

    def locale(t, lang):
        script = None
        if '-' in lang:
            lang, script = lang.split('-', 1)
        if not script:
            p = (ls.get(lang + '-' + t) or ls.get(lang, '')).split('-')
            script = p[1] if len(p) > 2 else None
        tries = ([f'{lang}-{script}-{t}'] if script else []) + [f'{lang}-{t}']
        tries += ([f'{lang}-{script}'] if script else []) + [lang]
        for c in tries:
            if os.path.exists(os.path.join(main_dir, c, 'numbers.json')):
                return c
        return None

    onest = glyphs('assets/fonts/Onest-Variable.ttf')
    space = chr(0x202F) if 0x202F in onest else chr(0xA0)

    fractions = cd['fractions']
    styles = {}
    for code in codes:
        terrs = sorted(where.get(code, []), key=people, reverse=True)
        loc = next((l for l in (locale(t, language(t)) for t in terrs) if l),
                   None)
        point, group = '.', ','
        if loc:
            n = json.load(open(os.path.join(main_dir, loc, 'numbers.json')))[
                'main'][loc]['numbers']['symbols-numberSystem-latn']
            point, group = n['decimal'], n['group']
        if code in OVERRIDES:
            point, group = OVERRIDES[code]
            loc = (loc or '') + ', point as on statements'
        if group in (chr(0xA0), chr(0x202F), ' ', 'space'):
            group = space
        assert point in '.,' and group in (',', '.', space, "'", '’'), (
            code, point, group)
        assert all(ord(ch) in onest for ch in point + group) or group == space
        cldr = int(fractions.get(code, fractions['DEFAULT'])['_digits'])
        whole = cldr == 0 and decimals.get(code, 2) > 0
        if (point, group, whole) != ('.', ',', False):
            styles[code] = (point, group, whole, loc)
    assert 'MNT' not in styles and 'USD' not in styles, 'tugrik and dollars'
    assert styles['IDR'][:2] == (',', '.')

    def q(s):
        named = {"'": "'\\''", chr(0xA0): "'\\u00a0'", chr(0x202F): "'\\u202f'"}
        return named.get(s, "'%s'" % s)

    out = ['// Made by tool/gen_number_styles.py from Unicode CLDR. Change the '
           'tool,\n// not this file.\n',
           "part of 'money.dart';\n",
           '/// How the people of each currency write an amount, where it '
           "isn't\n/// `1,234.95`; the locale it's taken from after each.",
           'const _styles = <String, NumberStyle>{']
    for code in sorted(styles):
        point, group, whole, loc = styles[code]
        args = [f'point: {q(point)}' if point != '.' else None,
                f'group: {q(group)}' if group != ',' else None,
                'whole: true' if whole else None]
        out.append("  '%s': NumberStyle(%s), // %s" % (
            code, ', '.join(a for a in args if a), loc))
    out.append('};\n')
    open('lib/domain/number_styles.dart', 'w').write('\n'.join(out))
    print(len(styles), 'currencies not written 1,234.95')


if __name__ == '__main__':
    main(*sys.argv[1:3])
