#!/usr/bin/env python3
"""The native speaker's review sheet for the Mongolian (#90).

  python3 tool/mongolian_review.py make    # from app/: writes docs/mongolian-review.csv
  python3 tool/mongolian_review.py apply   # puts the "corrected" column into app_mn.arb

`make` writes every message the app shows: its key, where it shows (the English
file's description), the English, the Mongolian draft, an empty "corrected" column
and a note. A correction already in the sheet is kept while its draft is unchanged;
the note says when a draft is new or changed since the sheet was last made. The file
starts with a byte-order mark so Excel and Numbers read the Cyrillic.

`apply` copies each filled "corrected" cell over the draft in app_mn.arb, refusing
one whose {placeholders} differ from the draft's, then `make` again empties them.
"""

import csv
import json
import re
import sys
from collections import OrderedDict
from pathlib import Path

APP = Path(__file__).resolve().parent.parent
EN = APP / 'lib/l10n/app_en.arb'
MN = APP / 'lib/l10n/app_mn.arb'
SHEET = APP.parent / 'docs/mongolian-review.csv'
HEADER = [
    'key',
    'where it shows',
    'English',
    'Монгол (draft)',
    'Монгол (corrected — leave blank if fine)',
    'note',
]
ARGS = re.compile(r'\{(\w+)\s*[,}]')


def load(path):
    return json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=OrderedDict)


def old_rows():
    if not SHEET.exists():
        return {}
    with SHEET.open(encoding='utf-8-sig', newline='') as f:
        rows = list(csv.reader(f))
    return {r[0]: r for r in rows[1:] if len(r) == len(HEADER)}


def make():
    en, mn, old = load(EN), load(MN), old_rows()
    out = [HEADER]
    for key, english in en.items():
        if key.startswith('@'):
            continue
        draft = mn.get(key, '')
        where = en.get('@' + key, {}).get('description', '')
        was = old.get(key)
        corrected, note = '', ''
        if was is None:
            note = 'new'
        elif was[3] != draft:
            note = 'draft changed'
        else:
            corrected, note = was[4], was[5]
        out.append([key, where, english, draft, corrected, note])
    with SHEET.open('w', encoding='utf-8-sig', newline='') as f:
        csv.writer(f).writerows(out)
    print(f'{len(out) - 1} messages written to {SHEET.relative_to(APP.parent)}')


def apply():
    mn = load(MN)
    changed, refused = 0, []
    for key, row in old_rows().items():
        fixed = row[4].strip()
        if not fixed or key not in mn or fixed == mn[key]:
            continue
        if set(ARGS.findall(fixed)) != set(ARGS.findall(mn[key])):
            refused.append(key)
            continue
        mn[key] = fixed
        changed += 1
    MN.write_text(json.dumps(mn, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{changed} corrections put into {MN.relative_to(APP)}')
    for key in refused:
        print(f'  not taken, its {{placeholders}} differ from the draft: {key}')


if __name__ == '__main__':
    {'make': make, 'apply': apply}[sys.argv[1] if len(sys.argv) > 1 else 'make']()
