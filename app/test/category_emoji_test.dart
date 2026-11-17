import 'package:betterbudget/domain/category_emoji.dart';
import 'package:betterbudget/domain/ledger.dart' show isIncomeName;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an emoji at the start of a name is split off with its space', () {
    expect(splitEmoji('🛒 Groceries'), (emoji: '🛒', rest: 'Groceries'));
    expect(splitEmoji('🛒Groceries'), (emoji: '🛒', rest: 'Groceries'));
    expect(splitEmoji('Groceries'), (emoji: null, rest: 'Groceries'));
    expect(splitEmoji('Groceries 🛒'), (emoji: null, rest: 'Groceries 🛒'));
    expect(splitEmoji('🛒'), (emoji: '🛒', rest: ''));
  });

  test('every emoji in the list is read whole', () {
    for (final (_, items) in emojiData) {
      for (final (e, _, _) in items) {
        expect(splitEmoji('$e Rent'), (emoji: e, rest: 'Rent'), reason: e);
      }
    }
  });

  test("the budget's own emoji are in the list, each with its names", () {
    for (final e in budgetEmoji) {
      expect(emojiName(e), isNotNull, reason: e);
      expect(emojiName(e, mongolian: true), isNotNull, reason: e);
    }
    expect(budgetEmoji.toSet(), hasLength(48));
  });

  test('search finds by English or Mongolian words, names first', () {
    expect(findEmoji('meat'), contains('🥩'));
    expect(findEmoji('мах'), contains('🥩'));
    expect(findEmoji('Car').first, '🚗');
    expect(findEmoji('  '), isEmpty);
    expect(findEmoji('zzzz'), isEmpty);
    // A word inside a name counts: "dumpling" finds 🥟.
    expect(findEmoji('dumpl'), contains('🥟'));
  });

  test('joined, toned, flag and keycap emoji are one emoji', () {
    expect(splitEmoji('👨‍👩‍👧 Family').emoji, '👨‍👩‍👧');
    expect(splitEmoji('👍🏽 Tips').emoji, '👍🏽');
    expect(splitEmoji('🇲🇳 Trip home').emoji, '🇲🇳');
    expect(splitEmoji('1️⃣ First').emoji, '1️⃣');
    expect(splitEmoji('1 First').emoji, isNull);
  });

  test("a transfer's arrow and plain letters aren't emoji", () {
    expect(splitEmoji('→ Golomt Visa').emoji, isNull);
    expect(splitEmoji('Өрх').emoji, isNull);
    expect(splitEmoji('₮ cash').emoji, isNull);
    expect(splitEmoji('↔️ Moves').emoji, '↔️');
  });

  test('withEmoji puts one in front, replaces, or takes it off', () {
    expect(withEmoji('🛒', 'Groceries'), '🛒 Groceries');
    expect(withEmoji('🍎', '🛒 Groceries'), '🍎 Groceries');
    expect(withEmoji(null, 'Groceries '), 'Groceries');
    expect(withEmoji('🛒', ''), '🛒');
  });

  test('names sort and match by their words', () {
    final names = ['Rent', '🛒 Groceries', 'eating out', '💡 Electricity'];
    names.sort(compareNames);
    expect(names, ['eating out', '💡 Electricity', '🛒 Groceries', 'Rent']);
    expect(sameName('🛒 Groceries', 'groceries'), isTrue);
    expect(sameName('🛒 Groceries', '🍎 Groceries'), isTrue);
    expect(sameName('Groceries', 'Grocery'), isFalse);
    expect(nameKey('🛒 Groceries').startsWith('gro'), isTrue);
  });

  test('names that are only an emoji differ; Income keeps its name', () {
    expect(sameName('🎁', '🐶'), isFalse);
    expect(sameName('🎁', '🎁'), isTrue);
    expect(isIncomeName('💰 Орлого'), isTrue);
    expect(isIncomeName('💰 Income'), isTrue);
    expect(isIncomeName('💰 Bonus'), isFalse);
  });

  test("a region's flag keeps its tag letters", () {
    const england = '🏴\u{E0067}\u{E0062}\u{E0065}\u{E006E}\u{E0067}\u{E007F}';
    expect(splitEmoji('$england Trip'), (emoji: england, rest: 'Trip'));
    expect(splitEmoji('◾ Bills').emoji, '◾');
  });
}
