// A payee the app remembers a category for (owner, 2026-10-06: "the app
// should offer to remember that for the future"; made a feature of its own
// on 2026-10-12, ADR 0004 "Payees: the real feature"). Its spellings and how
// each is looked for, the name the ledger shows for it, the accounts it
// holds on, and the category (or a pay, whose paycheck money in is). Pure:
// the table is in data/database.dart.

import 'dart:convert';

/// Trimmed, one space between words, lower case: how payees are compared,
/// whatever the bank's capitals or spacing.
String payeeWords(String s) =>
    s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// The memo of a row that takes a payee's name: the words it had as its
/// payee come first, so the bank's own text is never lost, then the memo
/// it had. Unchanged when the memo already holds those words.
String? memoKeeping(String? payee, String? memo) {
  final p = (payee ?? '').trim(), m = (memo ?? '').trim();
  if (p.isEmpty) return m.isEmpty ? null : m;
  if (m.isEmpty) return p;
  if (payeeWords(m).contains(payeeWords(p))) return m;
  return '$p · $m';
}

/// How a spelling is looked for, in the owner's words (2026-11-18:
/// "Starts with", "contains" or "exact match"). The names are stored:
/// don't rename them.
enum PayeeMatch {
  /// Anywhere in the payee or the memo (the bank's description).
  contains,

  /// The payee starts with it.
  starts,

  /// The payee is it, nothing more.
  exactly,
}

/// One way a payee is written, and how it is looked for.
class PayeeSpelling {
  const PayeeSpelling(this.how, this.text);

  final PayeeMatch how;

  /// As the person wrote it, for showing.
  final String text;

  /// What is looked for, as [payeeWords] makes it.
  String get words => payeeWords(text);

  /// Whether a row whose payee and memo are [p] and [m], both already as
  /// [payeeWords] makes them, is written this way.
  bool fitsWords(String p, String m) {
    final w = words;
    if (w.isEmpty) return false;
    return switch (how) {
      PayeeMatch.contains => p.contains(w) || m.contains(w),
      PayeeMatch.starts => p.startsWith(w),
      PayeeMatch.exactly => p == w,
    };
  }

  Map<String, Object?> toJson() => {'how': how.name, 'text': text};

  /// The spellings a rule's column holds; empty when there is nothing
  /// that reads as one.
  static List<PayeeSpelling> decode(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      return [
        for (final e in jsonDecode(json) as List)
          if (e is Map && e['text'] is String)
            PayeeSpelling(
              PayeeMatch.values.asNameMap()[e['how']] ?? PayeeMatch.starts,
              e['text'] as String,
            ),
      ];
    } on Object {
      return const [];
    }
  }

  static String encode(List<PayeeSpelling> spellings) =>
      jsonEncode([for (final s in spellings) s.toJson()]);

  @override
  bool operator ==(Object other) =>
      other is PayeeSpelling && other.how == how && other.text == text;

  @override
  int get hashCode => Object.hash(how, text);
}

class PayeeRuleInfo {
  const PayeeRuleInfo({
    required this.id,
    required this.spellings,
    this.shownAs = '',
    required this.categoryId,
    required this.accountIds,
    this.payId,
    this.createdAt = 0,
    this.deleted = false,
    this.deletedAt,
  });

  final int id;

  /// Every way it is written (owner, 2026-11-18: "there should be multiple
  /// ways of spelling the same payee"), each looked for in its own way.
  /// Never empty for a rule that is kept.
  final List<PayeeSpelling> spellings;

  /// The name the ledger shows for it ("Nomin Supermarket" for the bank's
  /// "NOMIN HOS 0123"): a row brought in from a bank file that fits takes
  /// it as its payee and keeps the bank's words in its memo. Empty: rows
  /// keep the bank's words. A row whose payee is this name fits too.
  final String shownAs;

  /// The first spelling's words: what every payee went by before it could
  /// have more than one, and what two lines made from the same row share.
  String get words => spellings.firstOrNull?.words ?? '';

  /// The first spelling as the person wrote it.
  String get name => spellings.firstOrNull?.text ?? '';

  /// Whether the first spelling is looked for anywhere.
  bool get anywhere => spellings.firstOrNull?.how == PayeeMatch.contains;

  /// What it is called on screen: its name, else its first spelling.
  String get title => shownAs.trim().isNotEmpty ? shownAs.trim() : name;

  final int categoryId;

  /// The pay whose paycheck money in from this payee is, when it's pay.
  final int? payId;

  /// The accounts it holds on.
  final Set<int> accountIds;

  /// When it was made, in ms; the later of two that fit alike wins.
  final int createdAt;

  /// Deleted by the person: no longer followed, but kept, so another
  /// computer's copy of the line combines as deleted too.
  final bool deleted;

  /// When, in ms; null while not deleted.
  final int? deletedAt;

  /// Whether a row with this [payee] and [memo] is one of this payee.
  bool fits(String? payee, String? memo) => fitLength(payee, memo) > 0;

  /// How many letters of a row this payee goes by: the longest spelling
  /// that fits it, or its name when the row's payee is that; 0 when it
  /// isn't one of this payee.
  int fitLength(String? payee, String? memo) {
    final p = payeeWords(payee ?? '');
    final m = payeeWords(memo ?? '');
    var best = 0;
    final shown = payeeWords(shownAs);
    if (shown.isNotEmpty && p == shown) best = shown.length;
    for (final s in spellings) {
      if (s.fitsWords(p, m) && s.words.length > best) best = s.words.length;
    }
    return best;
  }

  /// A spelling of this payee that [other] goes by too (the same words,
  /// however each looks for them), on an account both hold on: two payees
  /// can't go by one set of words on one account. Null when there is none.
  PayeeSpelling? sharedWith(PayeeRuleInfo other) {
    if (accountIds.intersection(other.accountIds).isEmpty) return null;
    final theirs = {for (final s in other.spellings) s.words};
    return spellings
        .where((s) => s.words.isNotEmpty && theirs.contains(s.words))
        .firstOrNull;
  }

  /// Whether [other] is written the same ways, each looked for the same.
  bool sameSpellings(PayeeRuleInfo other) =>
      other.spellings.length == spellings.length &&
      [
        for (var i = 0; i < spellings.length; i++)
          other.spellings[i].how == spellings[i].how &&
              other.spellings[i].words == spellings[i].words,
      ].every((same) => same);

  /// Whether this rule is on [accountId] and [fits].
  bool fitsOn(int accountId, String? payee, String? memo) =>
      accountIds.contains(accountId) && fits(payee, memo);

  /// Which of [rules] a row falls under: the longest words win, then the one
  /// made later, so the latest decision counts. Deleted ones never do. A
  /// pay's line is for money in only: [amount] on the account, above zero
  /// (budget review, 2026-10-26: a Unitel bill isn't Unitel's paycheck).
  static PayeeRuleInfo? pick(
    Iterable<PayeeRuleInfo> rules,
    int accountId,
    String? payee,
    String? memo, {
    int? amount,
  }) {
    PayeeRuleInfo? best;
    var bestLength = 0;
    for (final r in rules) {
      if (r.deleted || !r.accountIds.contains(accountId)) continue;
      if (r.payId != null && (amount == null || amount <= 0)) continue;
      final length = r.fitLength(payee, memo);
      if (length == 0) continue;
      if (best == null ||
          length > bestLength ||
          (length == bestLength &&
              (r.createdAt > best.createdAt ||
                  (r.createdAt == best.createdAt && r.id > best.id)))) {
        best = r;
        bestLength = length;
      }
    }
    return best;
  }

  PayeeRuleInfo copyWith({
    List<PayeeSpelling>? spellings,
    String? shownAs,
    int? categoryId,
    int? Function()? payId,
    Set<int>? accountIds,
    bool? deleted,
  }) => PayeeRuleInfo(
    id: id,
    spellings: spellings ?? this.spellings,
    shownAs: shownAs ?? this.shownAs,
    categoryId: categoryId ?? this.categoryId,
    payId: payId == null ? this.payId : payId(),
    accountIds: accountIds ?? this.accountIds,
    createdAt: createdAt,
    deleted: deleted ?? this.deleted,
    deletedAt: (deleted ?? this.deleted) ? deletedAt : null,
  );

  @override
  bool operator ==(Object other) =>
      other is PayeeRuleInfo &&
      other.id == id &&
      other.shownAs == shownAs &&
      other.spellings.length == spellings.length &&
      [
        for (var i = 0; i < spellings.length; i++)
          other.spellings[i] == spellings[i],
      ].every((same) => same) &&
      other.categoryId == categoryId &&
      other.payId == payId &&
      other.deleted == deleted &&
      other.createdAt == createdAt &&
      other.accountIds.length == accountIds.length &&
      other.accountIds.containsAll(accountIds);

  @override
  int get hashCode => Object.hash(id, words, categoryId, deleted);
}

/// What a row had before it took a payee's name, and the payee it was
/// given ([nowId]), for undo.
typedef PayeeBefore = ({
  int? payeeId,
  String? memo,
  String? bankPayee,
  int? nowId,
});

/// What remembering a payee from a row changed, for undo: the line it
/// changed ([was] before, [now] after; [was] null when one was made), and
/// a line it took this account off ([left]): one shared with other
/// accounts, which the person's choice on this account doesn't change.
typedef Remembered = ({
  PayeeRuleInfo? was,
  PayeeRuleInfo now,
  ({PayeeRuleInfo was, PayeeRuleInfo now})? left,
});

/// The id a rule carried over from the setting an older build kept gets:
/// the same on every computer that upgrades the same setting, so two
/// ledgers upgraded apart hold one rule, not two (ADR 0005, "Combine").
int carriedRuleId(int accountId, String starts) {
  // FNV-1a over the key, kept positive and clear of ids made at runtime
  // (those are the time in ms shifted 20 bits: around 2^60).
  var h = 0xcbf29ce484222325;
  for (final unit in 'payee-rule|$accountId|$starts'.codeUnits) {
    h ^= unit;
    h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return (h & 0x0FFFFFFFFFFFFFFF) | 0x0100000000000000;
}
