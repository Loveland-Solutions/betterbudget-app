part of 'phone_app.dart';

/// The first steps after setup on the phone's Budget (#475, the owner's
/// pick of sketch B: "let's do B"; ADR 0004 "The first-time walkthrough"):
/// the computer's band, phone-sized, in the Savings band's spot until the
/// steps are done. The steps as marks across its top, the one on screen by
/// name, its sentence, the button that opens the real page for it (New
/// category on its Bill or Day-to-day card), and the way past it, each
/// with Undo. Where the walk is comes from [walkOf], as on the computer.
class _PhoneWalkBand extends StatefulWidget {
  const _PhoneWalkBand({required this.store, required this.walk});
  final PhoneStore store;
  final Walk walk;

  @override
  State<_PhoneWalkBand> createState() => _PhoneWalkBandState();
}

class _PhoneWalkBandState extends State<_PhoneWalkBand> {
  /// A second tap before the first is written would find nothing to
  /// change: taps wait for the one in hand, as Savings' do.
  var _acting = false;

  static String _name(Words t, WalkStep s) => switch (s) {
    WalkStep.bills => t.walkStepBills,
    WalkStep.debts => t.walkStepDebts,
    WalkStep.dayToDay => t.planTypeDay,
    WalkStep.assign => t.walkStepAssign,
  };

  /// That's all or Not now: the person's own answer, said with Undo.
  Future<void> _pass(String said) async {
    if (_acting) return;
    _acting = true;
    final PhoneActed done;
    try {
      done = await widget.store.actRow(
        PhoneSavingsAnswer({widget.walk.passKey: 'yes'}),
      );
    } catch (e) {
      debugPrint('Passing a first step on the phone failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            persist: false,
            duration: phoneSnackTime,
            key: const ValueKey('walk-refused'),
            backgroundColor: Mid.raised,
            content: Text(
              context.t.ledgerCouldntSave,
              style: onest(15, color: Mid.ink),
            ),
          ),
        );
      return;
    } finally {
      _acting = false;
    }
    if (mounted) _saidWithUndo(context, widget.store, done, said, 'walk-done');
  }

  void _add({required CategoryType type, AccountInfo? paying}) => unawaited(
    _openNewCategory(
      context,
      store: widget.store,
      currency:
          paying?.currency ??
          widget.store.snapshot.budgetCurrency ??
          Currency.mnt,
      type: type,
      paying: paying,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final w = widget.walk;
    final Walk(:step, :steps, :bills, :days, :debt) = w;
    final nextPay = w.nextPay;
    final at = steps.indexOf(step);
    final name = _name(t, step);
    final (
      String sentence,
      String? why,
      String pass,
      String said,
      (String, Key, VoidCallback)? add,
    ) = switch (step) {
      WalkStep.bills => (
        bills == 0 ? t.walkBills : t.walkBillsSome(bills),
        w.cardsNext ? t.walkBillsWhyCards : t.walkBillsWhy,
        bills == 0 ? t.walkNotNow : t.walkAllBills,
        bills == 0 ? t.planSetAsideUndo(name) : t.phoneWalkDone(name),
        (
          t.walkAddBill,
          const ValueKey('walk-add-bill'),
          () => _add(type: CategoryType.bill),
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
        t.planSetAsideUndo(debt?.account.name ?? name),
        debt == null
            ? null
            : (
                t.walkAddDebtBill(debt.account.name),
                const ValueKey('walk-add-debt-bill'),
                () => _add(type: CategoryType.bill, paying: debt.account),
              ),
      ),
      WalkStep.dayToDay => (
        t.walkDay,
        t.walkDayWhy,
        days == 0 ? t.walkNotNow : t.walkAllDay,
        days == 0 ? t.planSetAsideUndo(name) : t.phoneWalkDone(name),
        (
          t.walkAddDay,
          const ValueKey('walk-add-day'),
          () => _add(type: CategoryType.dayToDay),
        ),
      ),
      // Assign what's planned is in each category's open row on the
      // phone: the band says where, rather than a second one here.
      WalkStep.assign => (
        w.short
            ? t.walkAssignShort
            : !w.waiting
            ? t.phoneWalkAssign
            : nextPay != null
            ? t.phoneWalkAssignWait(sayDate(t, nextPay))
            : t.phoneWalkAssignNoPay,
        null,
        t.walkNotNow,
        t.planSetAsideUndo(name),
        null,
      ),
    };
    return Container(
      key: const ValueKey('walk-band'),
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: Mid.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Mid.blue.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: t.planBandStepOf(at + 1),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  for (final (i, s) in steps.indexed) ...[
                    if (i > 0)
                      Container(
                        width: 10,
                        height: 1,
                        color: Mid.ink3.withValues(alpha: 0.5),
                      ),
                    KeyedSubtree(
                      key: ValueKey('walk-step-${s.name}'),
                      child: StepMarker(
                        number: i + 1,
                        state: i < at
                            ? ReadyState.done
                            : i == at
                            ? ReadyState.current
                            : ReadyState.later,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            key: const ValueKey('walk-step-name'),
            style: onest(13, weight: 600, color: Mid.blue),
          ),
          const SizedBox(height: 4),
          Text(
            sentence,
            key: const ValueKey('walk-sentence'),
            style: onest(16, weight: 600, height: 1.35),
          ),
          if (why != null) ...[
            const SizedBox(height: 4),
            Text(why, style: onest(14, color: Mid.ink2, height: 1.4)),
          ],
          if (add case (final label, final key, final onTap)) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              key: key,
              style: FilledButton.styleFrom(
                backgroundColor: Mid.blue,
                foregroundColor: Mid.onAccent,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: onest(16, weight: 600),
              ),
              onPressed: onTap,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(label, textAlign: TextAlign.center),
            ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('walk-pass'),
              onPressed: () => _pass(said),
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                foregroundColor: Mid.blue,
                textStyle: onest(16),
              ),
              child: Text(pass),
            ),
          ),
        ],
      ),
    );
  }
}
