// Counting a cash account (#119, ADR 0004 "Counting a cash account", the
// owner's sketch A): in the header where Reconcile sits on a bank account,
// the day and what is in the wallet, a sentence with the numbers, and where
// the difference goes (Not categorized unless a category is picked).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/budget.dart' show isUncategorized;
import '../domain/ledger.dart';
import '../domain/money.dart';
import 'amount_input.dart';
import 'entry_row.dart';
import 'language.dart';
import 'register.dart' show BarButton, CategoryMenu, CategoryChip;
import 'theme.dart';

/// One count in progress: the day and what is in the wallet, as typed, and
/// the category picked for the difference (none: Not categorized).
class CountSession {
  CountSession({
    required this.accountId,
    required DateTime today,
    this.currency = Currency.mnt,
  }) : date = TextEditingController(text: fullDate(today)),
       // Empty: a count is only worth anything because the cash was counted.
       counted = TextEditingController();

  final int accountId;
  final Currency currency;
  final TextEditingController date;
  final TextEditingController counted;
  final dateFocus = FocusNode(debugLabel: 'count-date');
  final countedFocus = FocusNode(debugLabel: 'count-counted');
  final categoryMenu = MenuController();

  /// The category the difference goes to; null is Not categorized.
  int? categoryId;

  int? get countedAmount => parseAmount(counted.text, currency);

  void dispose() {
    date.dispose();
    counted.dispose();
    dateFocus.dispose();
    countedFocus.dispose();
  }
}

/// Replaces the balance sum in the header while counting.
class CountPanel extends StatelessWidget {
  const CountPanel({
    super.key,
    required this.session,
    required this.today,
    required this.rowsSay,
    required this.categories,
    required this.holdingName,
    required this.onPick,
    required this.onSave,
    required this.onCancel,
    this.opening = false,
  });

  /// The account has no opening balance: more cash than the rows say
  /// becomes it, not a category's (owner, 2026-11-18).
  final bool opening;
  final CountSession session;
  final DateTime today;

  /// What the account's rows hold through a day.
  final int Function(DateTime day) rowsSay;

  /// The categories the difference can go to.
  final List<AccountInfo> categories;

  /// What Not categorized is called.
  final String holdingName;
  final VoidCallback onPick;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  static const _label = 128.0;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final t = context.t;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (s.categoryMenu.isOpen) {
            s.categoryMenu.close();
          } else {
            onCancel();
          }
        },
      },
      child: ListenableBuilder(
        listenable: Listenable.merge([s.date, s.counted]),
        builder: (context, _) {
          final day = parseRowDate(s.date.text, today);
          final future = day != null && day.isAfter(today);
          final counted = s.countedAmount;
          final held = day == null ? null : rowsSay(day);
          final diff = counted == null || held == null ? null : counted - held;
          String money(int v) => formatShort(v, currency: s.currency);
          String signed(int v) => v > 0 ? '+${money(v)}' : money(v);
          final opens = opening && diff != null && diff > 0;
          final category = categories
              .where((c) => c.id == s.categoryId)
              .firstOrNull;
          final categoryName = category?.name ?? holdingName;

          Widget line(String label, Widget value) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: _label,
                  child: Text(label, style: onest(13, color: Mid.ink3)),
                ),
                value,
              ],
            ),
          );

          return FocusTraversalGroup(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.countTitle, style: onest(14, weight: 600)),
                const SizedBox(height: 6),
                line(
                  t.countDate,
                  // Fixed heights: the header sizes itself from its
                  // contents' intrinsic heights, which fields under-report.
                  SizedBox(
                    width: 130,
                    height: 30,
                    child: DateField(
                      key: const ValueKey('count-date'),
                      controller: s.date,
                      focusNode: s.dateFocus,
                      today: today,
                      allowFuture: false,
                      small: true,
                      wanted: day == null || future,
                      onSubmitted: s.countedFocus.requestFocus,
                      onPicked: s.countedFocus.requestFocus,
                    ),
                  ),
                ),
                line(
                  t.countInWallet,
                  SizedBox(
                    width: 170,
                    height: 30,
                    child: TextField(
                      key: const ValueKey('count-counted'),
                      controller: s.counted,
                      inputFormatters: [GroupedAmount(s.currency)],
                      focusNode: s.countedFocus,
                      autofocus: true,
                      textAlign: TextAlign.right,
                      style: onest(13, tabular: true),
                      onSubmitted: (_) => onSave(),
                      onEditingComplete: () {},
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: Mid.ground.withValues(alpha: 0.6),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              counted == null &&
                                  s.counted.text.trim().isNotEmpty
                              ? BorderSide(
                                  color: Mid.coral.withValues(alpha: 0.6),
                                )
                              : BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Mid.blue, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (held != null && counted != null) ...[
                  Text(
                    t.countRowsSay(money(held), money(counted)),
                    key: const ValueKey('count-sentence'),
                    style: onest(13, color: Mid.ink2),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    diff == 0
                        ? t.countMatches
                        : opens
                        ? t.countBecomesOpening(money(diff))
                        : diff! < 0
                        ? t.countLess(money(-diff))
                        : t.countMore(money(diff)),
                    key: const ValueKey('count-result'),
                    style: onest(
                      13.5,
                      weight: 600,
                      color: diff == 0 ? Mid.green : Mid.ink,
                    ),
                  ),
                ] else if (held != null)
                  Text(
                    t.countRowsSayOnly(money(held)),
                    style: onest(13, color: Mid.ink2),
                  ),
                if (diff != null && diff != 0 && !opens) ...[
                  const SizedBox(height: 6),
                  line(
                    t.countTheDifference,
                    CategoryMenu(
                      controller: s.categoryMenu,
                      categories: categories,
                      current: categoryName,
                      onPicked: (c) {
                        s.categoryId = isUncategorized(c) ? null : c.id;
                        onPick();
                        s.countedFocus.requestFocus();
                      },
                      builder: (open, toggle) => CategoryChip(
                        key: const ValueKey('count-category'),
                        label: categoryName,
                        open: open,
                        onTap: toggle,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                // Wraps under Cancel when the words are long (Mongolian),
                // never runs past the panel.
                Wrap(
                  spacing: 4,
                  runSpacing: 6,
                  children: [
                    BarButton(
                      key: const ValueKey('count-cancel'),
                      label: t.rowsCancel,
                      onTap: onCancel,
                    ),
                    _SaveButton(
                      label: diff == null || diff == 0
                          ? t.countSave
                          : opens
                          ? t.countSaveOpening(money(diff))
                          : t.countSaveWith(signed(diff), categoryName),
                      onTap: onSave,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('count-save'),
    color: Mid.green,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      hoverColor: Colors.white.withValues(alpha: 0.14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 28, maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        alignment: Alignment.center,
        child: Text(label, style: onest(13, weight: 600, color: Mid.onAccent)),
      ),
    ),
  );
}
