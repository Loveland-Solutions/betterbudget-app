import 'package:flutter/material.dart';

import '../domain/money.dart';
import '../domain/readiness.dart';
import 'language.dart';
import 'theme.dart';

/// The pieces of a Savings step that the computer's Savings page, its
/// Budget page's band and the phone's Budget share (#487): the step's
/// name and picture, its numbered mark, its bar, and the line under it.

String stepTitle(Words t, ReadyStep s) => switch (s) {
  ReadyStep.oneMonth => t.planStepOneMonth,
  ReadyStep.consumerDebt => t.planStepConsumerDebt,
  ReadyStep.moreMonths => t.planStepMoreMonths,
  ReadyStep.future => t.planStepFuture,
};

/// The owner's picture for a step, by its file's name.
String stepPicture(ReadyStep s) => switch (s) {
  ReadyStep.oneMonth => 'safety-net',
  ReadyStep.consumerDebt => 'eliminate-debt',
  ReadyStep.moreMonths => 'three-to-six-months',
  ReadyStep.future => 'save-for-the-future',
};

/// How far along [step] is, as the band says it: the words under its name
/// and how full its bar is. Either may be null (step 4 has neither; a debt
/// with nothing known of what it once owed has no bar). [fundChange] is what
/// the phone's entries not yet on the computer put into or took out of the
/// fund.
({String? words, double? value}) stepProgress(
  Words t,
  Readiness r,
  ReadyStep step,
  Currency currency, {
  int fundChange = 0,
}) {
  String m(int v) => formatShort(v, currency: currency);
  final target = r.targetOf(step);
  final fund = r.fund + fundChange;
  switch (step) {
    case ReadyStep.oneMonth:
    case ReadyStep.moreMonths:
      if (target > 0 && r.hasFund && fund < target) {
        return (
          words: t.planFundOfToGo(m(fund), m(target), m(target - fund)),
          value: fund / target,
        );
      }
      // A month of expenses isn't known yet: what the step is.
      return (
        words: step == ReadyStep.oneMonth ? t.planBandNoMonth : null,
        value: null,
      );
    case ReadyStep.consumerDebt:
      final words = r.paidOff.isEmpty
          ? t.planAmountOwed(m(r.consumerOwed))
          : t.planDebtsPaidOff(
              r.paidOff.length,
              r.paidOff.length + r.consumerDebts.length,
              m(r.consumerOwed),
            );
      // Of the most these debts ever owed together, how much is gone.
      final most = [
        for (final d in r.consumerDebts) r.mostOwed[d.account.id] ?? d.owed,
        for (final a in r.paidOff) r.mostOwed[a.id] ?? 0,
      ].fold(0, (s, v) => s + v);
      return (words: words, value: most > 0 ? 1 - r.consumerOwed / most : null);
    case ReadyStep.future:
      return (words: null, value: null);
  }
}

/// One, two, three, four: done, the one they're on, skipped, and still to
/// come, as Savings marks them.
class StepMarker extends StatelessWidget {
  const StepMarker({super.key, required this.number, required this.state});
  final int number;
  final ReadyState state;

  @override
  Widget build(BuildContext context) {
    final (fill, edge, ink) = switch (state) {
      ReadyState.done => (
        Mid.green.withValues(alpha: 0.16),
        Mid.green,
        Mid.green,
      ),
      ReadyState.current => (Mid.blue, Mid.blue, Mid.ink),
      ReadyState.later => (Colors.transparent, Mid.ink3, Mid.ink2),
      ReadyState.setAside => (Colors.transparent, Mid.rule, Mid.ink3),
    };
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: edge),
      ),
      child: state == ReadyState.done
          ? Icon(Icons.check_rounded, size: 14, color: Mid.green)
          : Text('$number', style: onest(11.5, weight: 600, color: ink)),
    );
  }
}

/// The four marks in a row, joined by short lines, read out as "Step 2 of
/// 4".
class StepMarkers extends StatelessWidget {
  const StepMarkers({super.key, required this.r, required this.step});
  final Readiness r;
  final ReadyStep step;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.t.planBandStepOf(step.index + 1),
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in ReadyStep.values) ...[
            if (s.index > 0)
              Container(
                width: 10,
                height: 1,
                color: Mid.ink3.withValues(alpha: 0.5),
              ),
            StepMarker(number: s.index + 1, state: r.stateOf(s)),
          ],
        ],
      ),
    ),
  );
}

/// A step's bar. With no [width] it takes the width it's given.
class StepBar extends StatelessWidget {
  const StepBar({
    super.key,
    required this.value,
    required this.done,
    required this.muted,
    this.width = 360,
  });
  final double value;
  final bool done;
  final bool muted;
  final double? width;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: SizedBox(
      height: 6,
      width: width ?? double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(color: Mid.ground.withValues(alpha: 0.7)),
          ),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            heightFactor: 1,
            child: Container(
              color: done ? Mid.green : (muted ? Mid.ink3 : Mid.blue),
            ),
          ),
        ],
      ),
    ),
  );
}
