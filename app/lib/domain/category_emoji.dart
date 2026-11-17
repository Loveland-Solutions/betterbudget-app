/// A category's emoji (#486): kept as the first thing in its name, so it
/// shows wherever the name does, on the computer and the phone, and the
/// file needs nothing new. Sorting and finding by name skip it.
library;

import 'emoji_data.dart';

export 'emoji_data.dart' show emojiData;

/// The emoji at the start of [name] and the words after it (one space
/// between them dropped); `emoji` is null when the name has none.
({String? emoji, String rest}) splitEmoji(String name) {
  final s = name.trimLeft();
  final end = _leadingEmojiEnd(s);
  if (end == 0) return (emoji: null, rest: name);
  return (emoji: s.substring(0, end), rest: s.substring(end).trimLeft());
}

/// [rest] with [emoji] in front, or [rest] alone when there's none. An
/// emoji already at the start of [rest] is replaced, never doubled.
String withEmoji(String? emoji, String rest) {
  final words = splitEmoji(rest.trim()).rest;
  if (emoji == null || emoji.isEmpty) return rest.trim();
  if (words.isEmpty) return emoji;
  return '$emoji $words';
}

/// A name the way it's sorted and found: without its emoji, lower case.
/// "🛒 Groceries" sorts under G, and typing "gro" finds it first.
/// A name that's only an emoji is its own key, so "🎁" and "🐶" differ.
String nameKey(String name) {
  final words = splitEmoji(name.trim()).rest;
  return (words.isEmpty ? name.trim() : words).toLowerCase();
}

/// Whether two names mean the same category: case and emoji aside, so
/// typing "Groceries" picks "🛒 Groceries" rather than making another.
bool sameName(String a, String b) => nameKey(a) == nameKey(b.trim());

/// Two names in sorting order, by their words.
int compareNames(String a, String b) {
  final r = nameKey(a).compareTo(nameKey(b));
  return r != 0 ? r : a.compareTo(b);
}

/// The chooser's first group, for what a household spends on (#486): the
/// rest of [emojiData] follows it.
const budgetEmoji = [
  '🏠', '💡', '💧', '🔥', '📱', '🌐', '🧾', '🛠️', //
  '🛒', '🍞', '🥩', '🍎', '☕', '🍽️', '🍔', '🍼', //
  '🚗', '⛽', '🚌', '🚕', '✈️', '🅿️', '🚙', '🐎', //
  '👶', '🎒', '📚', '💊', '🩺', '🦷', '👕', '🎓', //
  '🎁', '🎉', '🎬', '🎮', '🏋️', '💇', '🥟', '⛺', //
  '💰', '🏦', '🐷', '💳', '🎯', '🛡️', '💸', '🙏', //
];

final _budget = budgetEmoji.toSet();

/// Each emoji's words, English and Mongolian, lower case, built once.
final _index = [
  for (final (_, items) in emojiData)
    for (final (e, en, mn) in items)
      (e, en.toLowerCase().split('|'), mn.toLowerCase().split('|')),
];

/// An emoji's name in English, or in Mongolian when [mongolian]; null for
/// one the list doesn't have.
String? emojiName(String emoji, {bool mongolian = false}) {
  for (final (e, en, mn) in emojiData.expand((g) => g.$2)) {
    if (e == emoji) return (mongolian ? mn : en).split('|').first;
  }
  return null;
}

/// The emoji whose words match [typed], in English or Mongolian, best
/// first: a word that is just it ("car" finds 🚗 before 🤸, person
/// cartwheeling), the budget's own first; then a name with a word starting with it, then any word
/// starting with it, then a word holding it. "мах" and "meat" both find 🥩.
List<String> findEmoji(String typed) {
  final q = typed.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final split = RegExp(r'[\s:,]+');
  bool starts(String words) =>
      words.startsWith(q) || words.split(split).any((w) => w.startsWith(q));
  final ranked = <(int, int, String)>[];
  for (final (n, (e, en, mn)) in _index.indexed) {
    final names = [en.first, mn.first];
    final all = [...en, ...mn];
    final int? rank = all.contains(q)
        ? 0
        : names.any(starts)
        ? 1
        : all.any(starts)
        ? 2
        : all.any((w) => w.contains(q))
        ? 3
        : null;
    // Within a rank, the budget's own first: "car" is 🚗 before 🚃.
    if (rank != null) {
      ranked.add((rank * 2 + (_budget.contains(e) ? 0 : 1), n, e));
    }
  }
  ranked.sort(
    (a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
  );
  return [for (final r in ranked) r.$3];
}

/// How many UTF-16 units of [s] its first emoji takes, 0 when it doesn't
/// start with one. Covers a mark with its variation, skin tone, keycap,
/// a flag's two letters and a family joined by zero-width joiners. An
/// arrow such as "→" (a transfer's) isn't one unless asked to be drawn
/// as an emoji.
int _leadingEmojiEnd(String s) {
  final runes = s.runes.toList();
  if (runes.isEmpty) return 0;
  var i = 0;
  int unitsTo(int n) =>
      runes.take(n).fold(0, (sum, r) => sum + (r > 0xFFFF ? 2 : 1));

  bool modifier(int r) =>
      r == 0xFE0F ||
      r == 0x20E3 ||
      (r >= 0x1F3FB && r <= 0x1F3FF) ||
      // A region's flag (England, Scotland) is spelled in tag letters.
      (r >= 0xE0020 && r <= 0xE007F);

  // One emoji's own runes, from [i]; false when there's none there.
  bool one() {
    if (i >= runes.length) return false;
    final r = runes[i];
    if (r >= 0x1F1E6 && r <= 0x1F1FF) {
      // A flag is two letters.
      final pair =
          i + 1 < runes.length &&
          runes[i + 1] >= 0x1F1E6 &&
          runes[i + 1] <= 0x1F1FF;
      i += pair ? 2 : 1;
      return true;
    }
    final picture =
        (r >= 0x1F000 && r <= 0x1FAFF) ||
        (r >= 0x2600 && r <= 0x27BF) ||
        (r >= 0x2B00 && r <= 0x2BFF) ||
        (r >= 0x2300 && r <= 0x23FF) ||
        // ◽ ◾, squares drawn as emoji without being asked.
        r == 0x25FD ||
        r == 0x25FE;
    final asked = i + 1 < runes.length && runes[i + 1] == 0xFE0F;
    if (!picture && !asked) return false;
    i++;
    while (i < runes.length && modifier(runes[i])) {
      i++;
    }
    return true;
  }

  if (!one()) return 0;
  while (i + 1 < runes.length && runes[i] == 0x200D) {
    final at = i;
    i++;
    if (!one()) {
      i = at;
      break;
    }
  }
  return unitsTo(i);
}
