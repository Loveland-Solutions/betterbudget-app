#!/usr/bin/env python3
"""Builds lib/domain/emoji_data.dart: every emoji the category chooser offers
(#486), in Unicode's groups and order, with the words search finds each by in
English and Mongolian.

Run by hand in a folder holding Unicode's emoji-test.txt and CLDR's
annotations (common/annotations and common/annotationsDerived, saved as
en.xml, en_d.xml, mn.xml, mn_d.xml):

  python3 tool/gen_emoji.py <folder> lib/domain/emoji_data.dart

Those files are © Unicode, Inc., under the Unicode License v3, which allows
this use. The app never downloads anything: the list is built into it.

Left out: skin tones and other variants of one emoji (the plain one is
there), the Component group, and emoji newer than Emoji 13.1, which an older
Windows or Android draws as an empty box.
"""
import re
import sys
import xml.etree.ElementTree as ET

MAX_VERSION = 13.1
GROUPS = {
    'Smileys & Emotion': 'smileys',
    'People & Body': 'people',
    'Animals & Nature': 'nature',
    'Food & Drink': 'food',
    'Travel & Places': 'travel',
    'Activities': 'activities',
    'Objects': 'objects',
    'Symbols': 'symbols',
    'Flags': 'flags',
}
TONES = set(range(0x1F3FB, 0x1F400))
HAIR = set(range(0x1F9B0, 0x1F9B4))


def words(folder, lang):
    """Each emoji's words, keyed without its variation selector."""
    names, rest = {}, {}
    for name in (f'{lang}.xml', f'{lang}_d.xml'):
        root = ET.parse(f'{folder}/{name}').getroot()
        for a in root.iter('annotation'):
            cp = a.get('cp').replace('️', '')
            parts = [w.strip() for w in (a.text or '').split('|')]
            if a.get('type') == 'tts':
                names[cp] = parts[0]
            else:
                rest.setdefault(cp, []).extend(parts)
    # The name first, then the other words, each once.
    out = {}
    for cp in set(names) | set(rest):
        have = [names[cp]] if cp in names else []
        have.extend(w for w in rest.get(cp, []) if w not in have)
        out[cp] = have
    return out


def main(folder, target):
    en, mn = words(folder, 'en'), words(folder, 'mn')
    groups, group = [], None
    line_re = re.compile(
        r'^([0-9A-F ]+?)\s*; fully-qualified\s*# (\S+) E(\d+\.\d+) ')
    for line in open(f'{folder}/emoji-test.txt', encoding='utf-8'):
        if line.startswith('# group: '):
            key = GROUPS.get(line[9:].strip())
            group = (key, []) if key else None
            if group:
                groups.append(group)
            continue
        m = line_re.match(line)
        if not m or group is None:
            continue
        cps = [int(c, 16) for c in m.group(1).split()]
        if float(m.group(3)) > MAX_VERSION:
            continue
        if any(c in TONES for c in cps):
            continue
        if any(c in HAIR for c in cps) and len(cps) > 1:
            continue
        e = m.group(2)
        bare = e.replace('️', '')
        group[1].append((e, en.get(bare, []), mn.get(bare, [])))

    def lit(s):
        return "'" + s.replace('\\', '\\\\').replace("'", "\\'") + "'"

    count = sum(len(g[1]) for g in groups)
    with open(target, 'w', encoding='utf-8') as f:
        f.write('// Made by tool/gen_emoji.py from Unicode\'s emoji-test.txt '
                '(Emoji 15.1) and\n// CLDR 45\'s annotations, © Unicode, Inc., '
                'Unicode License v3. Don\'t edit.\n')
        f.write('// ignore_for_file: lines_longer_than_80_chars\n\n')
        f.write('/// Every emoji the chooser offers, in Unicode\'s groups: '
                f'{count} of them.\n')
        f.write('/// Each is the emoji, then its English words and its '
                'Mongolian words, the\n/// name first, joined by "|".\n')
        f.write('const emojiData = <(String, List<(String, String, String)>)>[\n')
        for key, items in groups:
            f.write(f'  ({lit(key)}, [\n')
            for e, ew, mw in items:
                f.write(f'    ({lit(e)}, {lit("|".join(ew))}, '
                        f'{lit("|".join(mw))}),\n')
            f.write('  ]),\n')
        f.write('];\n')
    print(count, 'emoji')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
