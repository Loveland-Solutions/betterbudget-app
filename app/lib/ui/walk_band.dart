part of 'ledger_screen.dart';

/// The first steps after setup, on the Budget page (owner, 2026-11-22,
/// #475, sketch B of three: "let's do B"; ADR 0004 "The first-time
/// walkthrough"). In the Savings band's spot, until the steps are done: the
/// steps named across its top, then one at a time, a sentence, the button
/// that opens the real window for it, and the way past it. A step is done
/// by what's in the ledger or by the person's own That's all or Not now, so
/// a quit comes back to it.
class _WalkBand extends StatelessWidget {
  const _WalkBand({
    required this.step,
    required this.steps,
    required this.bills,
    required this.days,
    required this.debt,
    required this.cardsNext,
    required this.waiting,
    required this.nextPay,
    required this.onAddBill,
    required this.onAddDay,
    required this.onAddDebtBill,
    required this.onPass,
  });

  /// The step on screen, and every step named across the top, in order.
  final WalkStep step;
  final List<WalkStep> steps;

  /// How many bills and day-to-day categories there are: once there's one,
  /// the way past the step is That's all rather than Not now.
  final int bills, days;

  /// The credit card or loan the debts step is asking about, and what it
  /// owes, as the bank shows it.
  final ({AccountInfo account, int owes})? debt;

  /// The credit cards and loans step comes after the bills: the bills'
  /// line says so.
  final bool cardsNext;

  /// Nothing to give out yet: Assign waits for the income.
  final bool waiting;

  /// The next payday, when there's regular income.
  final DateTime? nextPay;

  final VoidCallback onAddBill;
  final VoidCallback onAddDay;
  final ValueChanged<AccountInfo> onAddDebtBill;

  /// That's all, or Not now: [label] is what undo calls it.
  final void Function(WalkStep step, String label) onPass;

  String _name(Words t, WalkStep s) => switch (s) {
    WalkStep.bills => t.walkStepBills,
    WalkStep.debts => t.walkStepDebts,
    WalkStep.dayToDay => t.planTypeDay,
    WalkStep.assign => t.walkStepAssign,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final at = steps.indexOf(step);
    final debt = this.debt;
    final (
      String sentence,
      String? why,
      String pass,
      Widget? add,
    ) = switch (step) {
      WalkStep.bills => (
        bills == 0 ? t.walkBills : t.walkBillsSome(bills),
        cardsNext ? t.walkBillsWhyCards : t.walkBillsWhy,
        bills == 0 ? t.walkNotNow : t.walkAllBills,
        _PrimaryButton(
          key: const ValueKey('walk-add-bill'),
          label: t.walkAddBill,
          icon: Icons.add_rounded,
          tooltip: '',
          onTap: onAddBill,
        ),
      ),
      WalkStep.debts => (
        t.walkDebt(
          debt?.account.name ?? '',
          formatShort(
            debt?.owes ?? 0,
            currency: debt?.account.currency ?? Currency.mnt,
          ),
        ),
        null,
        t.walkNotNow,
        debt == null
            ? null
            : _PrimaryButton(
                key: const ValueKey('walk-add-debt-bill'),
                label: t.walkAddDebtBill(debt.account.name),
                icon: Icons.add_rounded,
                tooltip: '',
                onTap: () => onAddDebtBill(debt.account),
              ),
      ),
      WalkStep.dayToDay => (
        t.walkDay,
        t.walkDayWhy,
        days == 0 ? t.walkNotNow : t.walkAllDay,
        _PrimaryButton(
          key: const ValueKey('walk-add-day'),
          label: t.walkAddDay,
          icon: Icons.add_rounded,
          tooltip: '',
          onTap: onAddDay,
        ),
      ),
      // Assign what's planned is already above, under the sum: the
      // band points to it rather than putting a second one here.
      WalkStep.assign => (
        !waiting
            ? t.walkAssign
            : nextPay != null
            ? t.walkAssignWait(sayDate(t, nextPay!))
            : t.walkAssignNoPay,
        null,
        t.walkNotNow,
        null,
      ),
    };
    Widget marker(int i, WalkStep s) {
      final done = i < at, now = i == at;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: now ? Mid.blue : Colors.transparent,
              border: now
                  ? null
                  : Border.all(color: done ? Mid.green : Mid.ink3, width: 1.2),
            ),
            child: done
                ? Icon(Icons.check_rounded, size: 13, color: Mid.green)
                : Text(
                    '${i + 1}',
                    style: onest(
                      11.5,
                      weight: 600,
                      color: now ? Mid.onAccent : Mid.ink3,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Text(
            _name(t, s),
            style: onest(
              12.5,
              weight: now ? 600 : 400,
              color: now ? Mid.ink : Mid.ink2,
            ),
          ),
        ],
      );
    }

    return Container(
      key: const ValueKey('walk-band'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(18, 12, 16, 14),
      decoration: BoxDecoration(
        color: Mid.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Mid.blue.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final (i, s) in steps.indexed) ...[
                if (i > 0) Container(width: 22, height: 1, color: Mid.rule),
                KeyedSubtree(
                  key: ValueKey('walk-step-${s.name}'),
                  child: marker(i, s),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sentence,
                      key: const ValueKey('walk-sentence'),
                      style: onest(15, weight: 600, height: 1.35),
                    ),
                    if (why != null) ...[
                      const SizedBox(height: 3),
                      Text(why, style: onest(13, color: Mid.ink2, height: 1.4)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              BarButton(
                key: const ValueKey('walk-pass'),
                label: pass,
                onTap: () => onPass(step, pass),
              ),
              if (add != null) ...[const SizedBox(width: 8), add],
            ],
          ),
        ],
      ),
    );
  }
}
