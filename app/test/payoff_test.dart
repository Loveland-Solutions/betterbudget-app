import 'package:betterbudget/domain/payoff.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 2's payoff, worked month by month (owner, 2026-10-27).
void main() {
  // The budget expert's household, in whole tugrik: a card, a pawnshop
  // loan whose payment only covers its interest, a salary loan, a car loan.
  const card = 1, pawn = 2, salary = 3, car = 4;
  final debts = <PayoffDebt>[
    (id: card, owed: 600000, monthlyRate: .03, payment: 60000),
    (id: pawn, owed: 800000, monthlyRate: .04, payment: 32000),
    (id: salary, owed: 2400000, monthlyRate: .018, payment: 150000),
    (id: car, owed: 6000000, monthlyRate: .016, payment: 250000),
  ];
  const smallest = [card, pawn, salary, car];
  const highestRate = [pawn, card, salary, car];

  test('smallest first: each payment rolls on to the next', () {
    final p = projectPayoff(debts, smallest, 100000);
    expect(p.months, 20);
    expect(p.paidOffIn, {card: 5, pawn: 9, salary: 13, car: 20});
    expect(p.interest, 1929907);
    expect(p.firstIn(smallest), (id: card, month: 5));
  });

  test('highest rate first costs less and clears a different one first', () {
    final p = projectPayoff(debts, highestRate, 100000);
    expect(p.months, 20);
    expect(p.paidOffIn[pawn], 8);
    expect(p.interest, 1900770);
    expect(p.firstIn(highestRate), (id: pawn, month: 8));
  });

  test('with nothing extra, a debt goes by its own payments', () {
    final p = projectPayoff(debts, smallest, 0);
    expect(p.paidOffIn[card], 13);
    expect(p.months, 26);
  });

  test('payments that never get ahead of the interest: never', () {
    final p = projectPayoff(
      [(id: 1, owed: 1000000, monthlyRate: .05, payment: 40000)],
      [1],
      0,
    );
    expect(p.months, isNull);
    expect(p.paidOffIn, isEmpty);
  });

  test('no rate is no interest', () {
    final p = projectPayoff(
      [(id: 1, owed: 300000, monthlyRate: 0, payment: 100000)],
      [1],
      0,
    );
    expect(p.months, 3);
    expect(p.interest, 0);
  });

  test('a debt below its interest still clears once the extra reaches it', () {
    final p = projectPayoff(
      [
        (id: 1, owed: 100000, monthlyRate: 0, payment: 50000),
        (id: 2, owed: 1000000, monthlyRate: .05, payment: 40000),
      ],
      [1, 2],
      100000,
    );
    expect(p.paidOffIn[1], 1);
    expect(p.months, isNotNull);
  });

  test('a debt already at nothing is paid off from the start', () {
    final p = projectPayoff(
      [
        (id: 1, owed: 0, monthlyRate: .03, payment: 10000),
        (id: 2, owed: 30000, monthlyRate: 0, payment: 10000),
      ],
      [1, 2],
      0,
    );
    expect(p.paidOffIn, {1: 0, 2: 2});
    expect(p.months, 2);
  });
}
