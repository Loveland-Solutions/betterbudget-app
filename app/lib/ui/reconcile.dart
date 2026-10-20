import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/ledger.dart';
import '../domain/money.dart';
import 'data_words.dart';
import 'entry_row.dart';
import 'language.dart';
import 'register.dart' show BarButton;
import 'theme.dart';

/// One reconcile in progress: the statement's date and balance as typed.
class ReconcileSession {
  ReconcileSession({
    required this.accountId,
    required this.owed,
    required DateTime today,
    this.currency = Currency.mnt,
  }) : date = TextEditingController(text: fullDate(today)),
       // Empty, never the cleared total: a reconcile is only worth anything
       // because the number was read off the bank's statement.
       balance = TextEditingController();

  final int accountId;

  /// The account's: how the typed balance is read.
  final Currency currency;

  /// A credit account: the bank shows what you owe as a positive number.
  final bool owed;
  final TextEditingController date;
  final TextEditingController balance;
  final dateFocus = FocusNode(debugLabel: 'reconcile-date');
  final balanceFocus = FocusNode(debugLabel: 'reconcile-balance');

  /// The statement balance in the account's own sign, or null if unreadable.
  int? get statementBalance {
    final v = parseAmount(balance.text, currency);
    return v == null ? null : (owed ? -v : v);
  }

  void dispose() {
    date.dispose();
    balance.dispose();
    dateFocus.dispose();
    balanceFocus.dispose();
  }
}

/// Where a reconcile stands for the typed date and balance.
typedef ReconcileCheck = ({
  DateTime? date,
  String? dateProblem,
  int? statement,
  int cleared,
  int toLock,

  /// One row that would explain the difference, if exactly one does.
  ReconcileHint? hint,
});

/// Replaces the balance sum in the header while reconciling: the statement
/// on one side, what's cleared here on the other, and how far apart they are.
/// Locking is only possible once they match.
class ReconcilePanel extends StatelessWidget {
  const ReconcilePanel({
    super.key,
    required this.session,
    required this.today,
    required this.check,
    required this.onLock,
    required this.onAdjust,
    required this.onCancel,
  });

  final ReconcileSession session;
  final DateTime today;
  final ReconcileCheck Function() check;
  final VoidCallback onLock;

  /// Posts the difference as an adjustment, then locks.
  final VoidCallback onAdjust;
  final VoidCallback onCancel;

  static const _label = 128.0, _amount = 200.0;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final t = context.t;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onCancel},
      child: ListenableBuilder(
        listenable: Listenable.merge([s.date, s.balance]),
        builder: (context, _) {
          final c = check();
          final off = c.statement == null || c.date == null
              ? null
              : c.statement! - c.cleared;
          final ready = off == 0 && c.dateProblem == null;
          final canAdjust = off != null && off != 0 && c.dateProblem == null;
          // Shown the way the bank shows it.
          int bank(int v) => s.owed ? -v : v;
          String money(int v) =>
              formatShort(v, currency: CurrencyScope.of(context));

          Widget line(String label, Widget value, {Widget? note}) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: _label,
                  child: Text(label, style: onest(13, color: Mid.ink3)),
                ),
                SizedBox(
                  width: _amount,
                  child: Align(alignment: Alignment.centerRight, child: value),
                ),
                if (note != null) ...[
                  const SizedBox(width: 20),
                  Flexible(child: note),
                ],
              ],
            ),
          );

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _label + _amount,
                child: Row(
                  children: [
                    const StatusGlyph(Cleared.reconciled),
                    const SizedBox(width: 8),
                    Text(t.rowsReconcileTitle, style: onest(14, weight: 600)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              line(
                t.rowsStatementDate,
                // Fixed heights: the header sizes itself from its contents'
                // intrinsic heights, which text fields under-report.
                SizedBox(
                  width: 130,
                  height: 30,
                  child: DateField(
                    key: const ValueKey('reconcile-date'),
                    controller: s.date,
                    focusNode: s.dateFocus,
                    today: today,
                    allowFuture: false,
                    small: true,
                    wanted: c.dateProblem != null,
                    onSubmitted: s.balanceFocus.requestFocus,
                    onPicked: s.balanceFocus.requestFocus,
                  ),
                ),
                note: c.dateProblem == null
                    ? null
                    : Text(
                        c.dateProblem!,
                        style: onest(12.5, color: Mid.coral),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
              line(
                s.owed ? t.rowsBankSaysYouOwe : t.rowsBankBalance,
                SizedBox(
                  width: 170,
                  height: 30,
                  child: TextField(
                    key: const ValueKey('reconcile-balance'),
                    controller: s.balance,
                    focusNode: s.balanceFocus,
                    autofocus: true,
                    textAlign: TextAlign.right,
                    style: onest(13, tabular: true),
                    onTap: () => s.balance.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: s.balance.text.length,
                    ),
                    onSubmitted: (_) {
                      if (ready) onLock();
                    },
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
                        // Coral only for something typed that isn't a number;
                        // empty is simply the next thing to fill in.
                        borderSide:
                            c.statement == null &&
                                s.balance.text.trim().isNotEmpty
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
                note: s.balance.text.trim().isEmpty
                    ? Text(
                        // Bank apps show an "available" balance too, which
                        // takes off pending holds and won't match.
                        t.rowsNotAvailableBalance,
                        style: onest(12.5, color: Mid.ink3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
              ),
              line(
                t.rowsClearedHere,
                Money(
                  bank(c.cleared),
                  size: 13,
                  color: Mid.ink,
                  centsColor: Mid.ink,
                ),
              ),
              Container(
                width: _amount,
                height: 1,
                margin: const EdgeInsets.only(left: _label, top: 3, bottom: 3),
                color: Mid.ink3.withValues(alpha: 0.45),
              ),
              line(
                t.rowsOffBy,
                off == null
                    ? Text('—', style: onest(13, color: Mid.ink3))
                    : off == 0
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StatusGlyph(Cleared.cleared, color: Mid.green),
                          const SizedBox(width: 6),
                          Text(
                            t.rowsMatches,
                            style: onest(13, weight: 500, color: Mid.green),
                          ),
                        ],
                      )
                    : Money(
                        bank(off).abs(),
                        size: 13,
                        weight: 500,
                        color: Mid.coral,
                        centsColor: Mid.coral,
                      ),
                // Which way it's off points at opposite causes.
                note: off == null || off == 0
                    ? null
                    : Text(
                        switch ((s.owed, bank(off) < 0)) {
                          (false, true) => t.rowsBankIsLower,
                          (false, false) => t.rowsBankIsHigher,
                          (true, true) => t.rowsBankSaysOweLess,
                          (true, false) => t.rowsBankSaysOweMore,
                        },
                        style: onest(12.5, color: Mid.ink2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
              if (off != null && off != 0)
                Padding(
                  padding: const EdgeInsets.only(left: _label, top: 2),
                  child: Text(
                    switch (c.hint) {
                      null => t.rowsHintClearRows,
                      final h => switch (h.cause) {
                        ReconcileCause.notCleared => t.rowsHintNotCleared(
                          rowPayee(t, h.row),
                          sayDate(t, h.date),
                          money(off.abs()),
                        ),
                        ReconcileCause.datedAfter => t.rowsHintDatedAfter(
                          rowPayee(t, h.row),
                          sayDate(t, h.date),
                          money(off.abs()),
                        ),
                        ReconcileCause.clearedEarly => t.rowsHintClearedEarly(
                          rowPayee(t, h.row),
                          sayDate(t, h.date),
                          money(off.abs()),
                        ),
                      },
                    },
                    key: const ValueKey('reconcile-hint'),
                    // Wraps rather than cut the amount, the clue to the
                    // statement's difference.
                    style: onest(12.5, color: Mid.ink3),
                  ),
                ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: _label),
                child: Row(
                  children: [
                    BarButton(
                      key: const ValueKey('reconcile-cancel'),
                      label: t.rowsCancel,
                      onTap: onCancel,
                    ),
                    // Not matching: the way out is a visible, named
                    // adjustment, not a made-up spending row. Outlined, not
                    // gold, so finding the difference stays the first choice.
                    if (canAdjust)
                      BarButton(
                        key: const ValueKey('reconcile-adjust'),
                        label: t.rowsAddAdjustmentAndLock(
                          money(bank(off).abs()),
                        ),
                        onTap: onAdjust,
                      )
                    else
                      _LockButton(
                        label: c.toLock == 0
                            ? t.rowsMarkReconciled
                            : t.rowsLockTransactions(c.toLock),
                        onTap: ready ? onLock : null,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Gold, like the diamond it hands out; dimmed until the numbers match.
class _LockButton extends StatelessWidget {
  const _LockButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return Material(
      key: const ValueKey('reconcile-lock'),
      color: on ? Mid.gold : Mid.gold.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.white.withValues(alpha: 0.14),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Text(
            label,
            style: onest(
              13,
              weight: 600,
              color: on ? Mid.onAccent : Mid.gold.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }
}
