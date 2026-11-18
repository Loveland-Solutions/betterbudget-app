part of 'ledger_screen.dart';

/// The Savings step the person is on, in a band under the Budget page's
/// sum (owner, 2026-11-17, #487: "I want the budget screen to encourage
/// them to feed money into these categories and track their progress …
/// something on the budget page that shows what step the user is on";
/// sketch A of three). The step's picture, the four marks, its name (a
/// click opens Savings), its progress, and, while money is spare after
/// every plan has its share, Savings' own Assign button.
class _StepBand extends StatelessWidget {
  const _StepBand({
    required this.r,
    required this.step,
    required this.currency,
    required this.offers,
    required this.onAssign,
    required this.onOpen,
  });

  final Readiness r;

  /// [Readiness.current]: the first step not done and not skipped.
  final ReadyStep step;

  /// Savings' own ([savingsCurrency]).
  final Currency currency;

  /// The period on screen is the one today is in, and the budget has
  /// begun: the step counts what the Safety net holds today, so only there
  /// does a click move it.
  final bool offers;

  /// Assign was clicked: the new total for today's period of the Safety
  /// net, or on step 2 of the category that pays the debt, what undo calls
  /// it, and what to say when that fills the step.
  final void Function(
    AccountInfo category,
    int total,
    String undo,
    String? full,
  )
  onAssign;

  /// The step's name was clicked: Savings.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    String m(int v) => formatShort(v, currency: currency);
    final fundStep = step == ReadyStep.oneMonth || step == ReadyStep.moreMonths;
    final target = r.targetOf(step);
    final (:words, :value) = stepProgress(t, r, step, currency);
    final category = r.fundCategories.length == 1
        ? r.fundCategories.single
        : null;
    final offer = offers && fundStep && category != null ? r.offerFor(step) : 0;
    // Step 2: this month's extra, to the category that pays the debt it
    // goes to first.
    final extra = offers && step == ReadyStep.consumerDebt
        ? r.extraOffer
        : null;
    return Container(
      key: const ValueKey('step-band'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Mid.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Mid.rule),
      ),
      child: Row(
        children: [
          ExcludeSemantics(child: SavingsPicture(stepPicture(step), size: 48)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StepMarkers(r: r, step: step),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Hoverable(
                        key: const ValueKey('step-band-title'),
                        onTap: onOpen,
                        builder: (hover) => Text(
                          stepTitle(t, step),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: onest(
                            15,
                            weight: 600,
                            color: hover ? Mid.blue : Mid.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (words != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (value != null) ...[
                        StepBar(
                          value: value,
                          done: false,
                          muted: false,
                          width: 240,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Flexible(
                        child: Text(
                          words,
                          key: const ValueKey('step-band-progress'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: onest(13, color: Mid.ink2, tabular: true),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (offer > 0 && category != null) ...[
            const SizedBox(width: 16),
            // A long category name ends in an ellipsis; the progress
            // beside it keeps its room.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: BarButton(
                key: const ValueKey('step-band-assign'),
                label: t.planFundAssign(m(offer), category.name),
                color: Mid.blue,
                onTap: () => onAssign(
                  category,
                  r.fundAssigned + offer,
                  t.planAssignUndo(m(offer), category.name),
                  offer < target - r.fundLeft
                      ? null
                      : step == ReadyStep.oneMonth
                      ? t.planBandFull(category.name, m(target))
                      : t.planBandFullMonths(
                          category.name,
                          m(target),
                          r.monthsTarget,
                        ),
                ),
              ),
            ),
          ],
          if (extra != null) ...[
            const SizedBox(width: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: BarButton(
                key: const ValueKey('step-band-extra'),
                label: t.planFundAssign(m(extra.offer), extra.category.name),
                color: Mid.blue,
                onTap: () => onAssign(
                  extra.category,
                  extra.total,
                  t.planAssignUndo(m(extra.offer), extra.category.name),
                  null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
