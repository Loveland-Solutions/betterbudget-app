#!/usr/bin/env python3
"""Builds assets/fonts/BetterBudgetSymbols.ttf: the currency signs Manrope
lacks, taken from Noto fonts (SIL Open Font License 1.1).

Run by hand, with fonttools installed, in a folder holding the Noto files:

  python3 tool/gen_symbol_font.py <folder with Noto*-Regular.ttf> <out.ttf>

The Noto files are the hinted TTFs from github.com/notofonts. The app never
downloads anything.
"""
import sys

from fontTools import subset
from fontTools.merge import Merger
from fontTools.ttLib import TTFont

SOURCES = {
    'NotoSans': '₼₡₾₵₸₭₦₲⃀',
    'NotoSansThai': '฿',
    'NotoSansKhmer': '៛',
    'NotoSansBengali': '৳',
    'NotoSansArmenian': '֏',
}


def main(folder, out):
    parts = []
    for name, chars in SOURCES.items():
        font = TTFont(f'{folder}/{name}-Regular.ttf')
        o = subset.Options()
        o.layout_features = []
        o.hinting = False
        o.notdef_outline = True
        o.glyph_names = False
        o.drop_tables += ['GSUB', 'GPOS', 'GDEF', 'STAT', 'MVAR', 'HVAR',
                          'avar', 'fvar', 'gvar', 'meta', 'DSIG']
        s = subset.Subsetter(o)
        s.populate(unicodes=[ord(c) for c in chars])
        s.subset(font)
        part = f'{folder}/sub-{name}.ttf'
        font.save(part)
        parts.append(part)
    merged = Merger().merge(parts)
    for rec in merged['name'].names:
        if rec.nameID in (1, 4, 16):
            rec.string = 'BetterBudget Symbols'
        if rec.nameID == 6:
            rec.string = 'BetterBudgetSymbols'
    merged.save(out)


if __name__ == '__main__':
    main(*sys.argv[1:3])
