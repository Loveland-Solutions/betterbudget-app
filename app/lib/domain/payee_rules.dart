// A payee the app remembers a category for (owner, 2026-10-06: "the app
// should offer to remember that for the future"; made a feature of its own
// on 2026-10-12, ADR 0004 "Payees: the real feature"). Words, where they are
// looked for, the accounts it holds on, and the category (or a pay, whose
// paycheck money in is). Pure: the table is in data/database.dart.

/// Trimmed, one space between words, lower case: how payees are compared,
/// whatever the bank's capitals or spacing.
String payeeWords(String s) =>
    s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

class PayeeRuleInfo {
  const PayeeRuleInfo({
    required this.id,
    required this.words,
    required this.name,
    required this.anywhere,
    required this.categoryId,
    required this.accountIds,
    this.payId,
    this.createdAt = 0,
    this.deleted = false,
    this.deletedAt,
  });

  final int id;

  /// What is looked for, as [payeeWords] makes it.
  final String words;

  /// The same as the person wrote it, for showing.
  final String name;

  /// Looked for anywhere in the payee or the bank's description; otherwise
  /// the payee has to start with [words].
  final bool anywhere;

  final int categoryId;

  /// The pay whose paycheck money in from this payee is, when it's pay.
  final int? payId;

  /// The accounts it holds on.
  final Set<int> accountIds;

  /// When it was made, in ms; the later of two that fit alike wins.
  final int createdAt;

  /// Deleted by the person: no longer followed, but kept so an import
  /// doesn't put that payee back where it went last ([deletedBlocks]).
  final bool deleted;

  /// When, in ms; null while not deleted.
  final int? deletedAt;

  /// Whether a row with this [payee] and [memo] is one of this payee.
  bool fits(String? payee, String? memo) {
    if (words.isEmpty) return false;
    final p = payeeWords(payee ?? '');
    if (!anywhere) return p.startsWith(words);
    return p.contains(words) || payeeWords(memo ?? '').contains(words);
  }

  /// Whether this rule is on [accountId] and [fits].
  bool fitsOn(int accountId, String? payee, String? memo) =>
      accountIds.contains(accountId) && fits(payee, memo);

  /// Which of [rules] a row falls under: the longest words win, then the one
  /// made later, so the latest decision counts. Deleted ones never do.
  static PayeeRuleInfo? pick(
    Iterable<PayeeRuleInfo> rules,
    int accountId,
    String? payee,
    String? memo,
  ) {
    PayeeRuleInfo? best;
    for (final r in rules) {
      if (r.deleted || !r.fitsOn(accountId, payee, memo)) continue;
      if (best == null ||
          r.words.length > best.words.length ||
          (r.words.length == best.words.length &&
              (r.createdAt > best.createdAt ||
                  (r.createdAt == best.createdAt && r.id > best.id)))) {
        best = r;
      }
    }
    return best;
  }

  /// Whether a rule the person deleted says this payee is not to go to
  /// [categoryId] by itself any more: an import with no rule files a payee
  /// where it went last, which would put it straight back. A row the person
  /// filed there after the Delete ([filedAt], ms) counts again: that was
  /// their decision, made later.
  static bool deletedBlocks(
    Iterable<PayeeRuleInfo> rules,
    int accountId,
    String? payee,
    String? memo,
    int categoryId, {
    int? filedAt,
  }) => rules.any(
    (r) =>
        r.deleted &&
        r.categoryId == categoryId &&
        (filedAt == null || r.deletedAt == null || filedAt < r.deletedAt!) &&
        r.fitsOn(accountId, payee, memo),
  );

  PayeeRuleInfo copyWith({
    String? words,
    String? name,
    bool? anywhere,
    int? categoryId,
    int? Function()? payId,
    Set<int>? accountIds,
    bool? deleted,
  }) => PayeeRuleInfo(
    id: id,
    words: words ?? this.words,
    name: name ?? this.name,
    anywhere: anywhere ?? this.anywhere,
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
      other.words == words &&
      other.name == name &&
      other.anywhere == anywhere &&
      other.categoryId == categoryId &&
      other.payId == payId &&
      other.deleted == deleted &&
      other.createdAt == createdAt &&
      other.accountIds.length == accountIds.length &&
      other.accountIds.containsAll(accountIds);

  @override
  int get hashCode => Object.hash(id, words, categoryId, deleted);
}

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
