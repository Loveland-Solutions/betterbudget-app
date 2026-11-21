part of 'phone_app.dart';

// Reconcile on the phone (#530, owner's pick of sketch A, ADR 0004
// "Reconcile on the phone"): the computer's, in the account's header on the
// Ledger tab. The card that leads the account's rows turns into the
// statement's date, the bank's balance, what is cleared here and how far
// apart they are; the rows under it narrow to those not yet reconciled
// through that date, each cleared by a tap on its symbol; Cancel and Lock
// take the place of the Ledger and Budget tabs. The sums and the hint are
// the computer's (`clearedThrough`, `reconcileHint`), and so are the words.

/// One reconcile in progress: the statement's date and the bank's balance
/// as typed.
class _Reconciling {
  _Reconciling({required this.accountId, required this.date});
  final int accountId;
  DateTime date;

  /// Empty, never the cleared total: a reconcile is only worth anything
  /// because the number was read off the bank's statement.
  final balance = TextEditingController();
  final focus = FocusNode(debugLabel: 'phone-reconcile-balance');

  /// The statement's balance in the account's own sign, or null when what is
  /// typed isn't an amount. A card's is typed as what's owed, positive.
  int? statement(AccountInfo a) {
    final v = parseAmount(balance.text, a.currency);
    return v == null ? null : (a.isOwed ? -v : v);
  }

  void dispose() {
    balance.dispose();
    focus.dispose();
  }
}

/// Where a reconcile stands for the date picked and the balance typed.
typedef _ReconcileCheck = ({
  int? statement,
  int cleared,
  int toLock,

  /// One row that would explain the difference, if exactly one does.
  ReconcileHint? hint,
});

/// The header's card while reconciling.
class _ReconcileCard extends StatelessWidget {
  const _ReconcileCard({
    required this.session,
    required this.account,
    required this.check,
    required this.onPickDate,
  });
  final _Reconciling session;
  final AccountInfo account;
  final _ReconcileCheck check;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = check;
    final owed = account.isOwed;
    // Shown the way the bank shows it.
    int bank(int v) => owed ? -v : v;
    String money(int v) => formatShort(v, currency: account.currency);
    final off = c.statement == null ? null : c.statement! - c.cleared;

    Widget line(String label, Widget value) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: onest(14, color: Mid.ink2)),
          ),
          const SizedBox(width: 12),
          value,
        ],
      ),
    );

    return Container(
      key: ValueKey('reconcile-card-${account.id}'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Mid.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Mid.gold, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const StatusGlyph(Cleared.reconciled),
              const SizedBox(width: 8),
              Text(
                t.rowsReconcileTitle,
                style: onest(15, weight: 600, color: Mid.ink),
              ),
            ],
          ),
          const SizedBox(height: 4),
          line(
            t.rowsStatementDate,
            TextButton(
              key: const ValueKey('reconcile-date'),
              onPressed: onPickDate,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 36),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                backgroundColor: Mid.raised,
                foregroundColor: Mid.ink,
                textStyle: onest(15, tabular: true),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(fullDate(session.date)),
            ),
          ),
          line(
            owed ? t.rowsBankSaysYouOwe : t.rowsBankBalance,
            SizedBox(
              width: 168,
              child: TextField(
                key: const ValueKey('reconcile-balance'),
                controller: session.balance,
                focusNode: session.focus,
                autofocus: true,
                textAlign: TextAlign.end,
                inputFormatters: [GroupedAmount(account.currency)],
                // Signed: an overdrawn account's balance is below zero.
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                textInputAction: TextInputAction.done,
                // A tap on a row or anywhere else puts the keyboard away:
                // an iPhone's number pad has no Done.
                onTapOutside: (_) => session.focus.unfocus(),
                style: onest(16, weight: 600, tabular: true),
                decoration: InputDecoration(
                  isDense: true,
                  prefixText: account.currency.prefix,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 8,
                  ),
                ),
              ),
            ),
          ),
          // Bank apps show an "available" balance too, which takes off
          // pending holds and won't match.
          if (session.balance.text.trim().isEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  t.rowsNotAvailableBalance,
                  style: onest(13, color: Mid.ink2),
                ),
              ),
            ),
          line(
            t.rowsClearedHere,
            Text(
              money(bank(c.cleared)),
              key: const ValueKey('reconcile-cleared'),
              style: onest(15, tabular: true, color: Mid.ink),
            ),
          ),
          Container(height: 1, color: Mid.rule),
          line(
            t.rowsOffBy,
            off == null
                ? Text('—', style: onest(15, color: Mid.ink2))
                : off == 0
                ? Row(
                    key: const ValueKey('reconcile-matches'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusGlyph(Cleared.cleared, color: Mid.green),
                      const SizedBox(width: 6),
                      Text(
                        t.rowsMatches,
                        style: onest(15, weight: 600, color: Mid.green),
                      ),
                    ],
                  )
                : Text(
                    money(bank(off).abs()),
                    key: const ValueKey('reconcile-off'),
                    style: onest(
                      15,
                      weight: 600,
                      tabular: true,
                      color: Mid.coral,
                    ),
                  ),
          ),
          if (off != null && off != 0) ...[
            // Which way it's off points at opposite causes.
            Text(switch ((owed, bank(off) < 0)) {
              (false, true) => t.rowsBankIsLower,
              (false, false) => t.rowsBankIsHigher,
              (true, true) => t.rowsBankSaysOweLess,
              (true, false) => t.rowsBankSaysOweMore,
            }, style: onest(13, color: Mid.ink2)),
            const SizedBox(height: 2),
            Text(
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
              style: onest(13, color: Mid.ink2),
            ),
          ],
        ],
      ),
    );
  }
}

/// Cancel and Lock, where the Ledger and Budget tabs are.
class _ReconcileBar extends StatelessWidget {
  const _ReconcileBar({
    required this.account,
    required this.check,
    required this.onCancel,
    required this.onLock,
    required this.onAdjust,
    required this.typing,
  });
  final AccountInfo account;
  final _ReconcileCheck check;

  /// The bank's balance is still being typed: every digit on the way is a
  /// difference, and none of them is one to adjust away.
  final bool typing;
  final VoidCallback onCancel;
  final VoidCallback onLock;

  /// Posts the difference as an adjustment, then locks.
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = check;
    final owed = account.isOwed;
    int bank(int v) => owed ? -v : v;
    String money(int v) => formatShort(v, currency: account.currency);
    final off = c.statement == null ? null : c.statement! - c.cleared;
    return Container(
      decoration: BoxDecoration(
        color: Mid.card,
        border: Border(top: BorderSide(color: Mid.rule)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          OutlinedButton(
            key: const ValueKey('reconcile-cancel'),
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(88, 48),
              foregroundColor: Mid.ink,
              side: BorderSide(color: Mid.rule),
              textStyle: onest(15),
            ),
            child: Text(t.rowsCancel),
          ),
          const SizedBox(width: 10),
          Expanded(
            // Not matching: the way out is a visible, named adjustment, not
            // a made-up spending row. Outlined, not gold, so finding the
            // difference stays the first choice.
            child: off != null && off != 0 && !typing
                ? OutlinedButton(
                    key: const ValueKey('reconcile-adjust'),
                    onPressed: onAdjust,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: Mid.ink,
                      side: BorderSide(color: Mid.ink2, width: 1.5),
                      textStyle: onest(14, weight: 600),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    child: Text(switch ((owed, bank(off) > 0)) {
                      (false, true) => t.rowsAdjustUpAndLock(money(bank(off))),
                      (false, false) => t.rowsAdjustDownAndLock(
                        money(-bank(off)),
                      ),
                      (true, true) => t.rowsAdjustOwedUpAndLock(
                        money(bank(off)),
                      ),
                      (true, false) => t.rowsAdjustOwedDownAndLock(
                        money(-bank(off)),
                      ),
                    }, textAlign: TextAlign.center),
                  )
                : FilledButton(
                    key: const ValueKey('reconcile-lock'),
                    // Dimmed until the numbers match.
                    onPressed: off == 0 ? onLock : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: Mid.gold,
                      foregroundColor: Mid.onAccent,
                      disabledBackgroundColor: Mid.gold.withValues(alpha: 0.18),
                      disabledForegroundColor: Mid.ink2,
                      textStyle: onest(15, weight: 600),
                    ),
                    child: Text(
                      c.toLock == 0
                          ? t.rowsMarkReconciled
                          : t.rowsLockTransactions(c.toLock),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
