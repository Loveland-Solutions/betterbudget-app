part of 'phone_app.dart';

// A row already in that may have paid a scheduled bill is asked about on
// the phone as on the computer (#527, owner's pick of sketch A, ADR 0004
// "Bills asked on the phone"): a line under the bill's row, and one under
// the row that may have paid it, each with Yes and No. A payment that is
// part of a bill or several bills' worth opens this page with the answers.

/// What the person answered on [_BillAskPage].
enum _BillAnswer { paid, rest, several, notIt }

/// The bill's date and those after it a payment for [count] bills would pay.
List<DateTime> _billDates(LedgerData data, RegisterRow bill, int count) {
  final plan = switch (bill.planCategoryId) {
    final id? => data.plans[id],
    null => null,
  };
  if (plan == null) return [bill.date];
  final pay = data.payScheduleById(plan.payScheduleId);
  final out = [bill.date];
  // Not one there won't be: those aren't paid (#357).
  final skipped = Budget.skippedBills(data, plan);
  for (var n = 0; n < 400 && out.length < count; n++) {
    final d = Budget.dueAfter(plan, n, pay: pay);
    if (d.isAfter(bill.date) && !skipped.contains(d)) out.add(d);
  }
  return out;
}

/// The line under a bill's row, or under the row that may have paid it:
/// [text] and Yes and No, each a full button.
class _PaidAsk extends StatelessWidget {
  const _PaidAsk({
    super.key,
    required this.text,
    required this.onYes,
    required this.onNo,
  });
  final String text;
  final VoidCallback onYes;
  final VoidCallback onNo;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: onest(14, weight: 600, color: Mid.ink)),
          Row(
            children: [
              TextButton(
                key: const ValueKey('paid-yes'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(72, 44),
                  foregroundColor: Mid.blue,
                ),
                onPressed: onYes,
                child: Text(t.rowsPaidYes, style: onest(15, weight: 600)),
              ),
              TextButton(
                key: const ValueKey('paid-no'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(72, 44),
                  foregroundColor: Mid.ink2,
                ),
                onPressed: onNo,
                child: Text(t.rowsPaidNo, style: onest(15)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The page for a payment that isn't near its bill: far less, part of it,
/// far more, or two or three bills' worth. Back leaves it unanswered.
class _BillAskPage extends StatelessWidget {
  const _BillAskPage({
    required this.payment,
    required this.account,
    required this.category,
    required this.dues,
  });
  final BillPayment payment;

  /// The account the row is in, when it isn't the bill's.
  final String? account;

  /// The bill's category, for what a payment over it comes out of.
  final String? category;

  /// The bill's date and those after it a payment for several would pay.
  final List<DateTime> dues;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final p = payment, bill = p.bill, row = p.row;
    String money(int v) => formatShort(v.abs(), currency: bill.currency);
    final name = rowPayee(t, bill);
    final payee = rowPayee(t, row);
    final when = sayDate(t, row.date);
    final short = bill.amount.abs() - row.amount.abs();
    final String title;
    final List<String> lines;
    final List<({String label, _BillAnswer answer, String key})> answers;
    switch (p.fit) {
      case BillFit.part:
        title = t.billRestTitle(money(short));
        lines = [t.billRestPaid(money(row.amount), money(bill.amount), name)];
        answers = [
          (
            label: t.billRestYes(sayDate(t, bill.date)),
            answer: _BillAnswer.rest,
            key: 'rest',
          ),
          (label: t.billRestNo, answer: _BillAnswer.paid, key: 'paid'),
          (label: t.rowsNotThisBill, answer: _BillAnswer.notIt, key: 'no'),
        ];
      case BillFit.several when dues.length >= 2:
        final each = money(bill.amount);
        title = t.billSeveralTitle(dues.length, name);
        lines = [
          t.billSeveralPaid(money(row.amount), when),
          dues.length == 2
              ? t.billSeveralBills2(
                  sayDate(t, dues[0]),
                  sayDate(t, dues[1]),
                  each,
                )
              : t.billSeveralBills3(
                  sayDate(t, dues[0]),
                  sayDate(t, dues[1]),
                  sayDate(t, dues[2]),
                  each,
                ),
        ];
        answers = [
          (
            label: t.billSeveralYes(dues.length),
            answer: _BillAnswer.several,
            key: 'several',
          ),
          (label: t.billSeveralOne, answer: _BillAnswer.paid, key: 'one'),
        ];
      default:
        title = t.billAskTitle(name);
        lines = [
          account == null
              ? t.billAskPaid(payee, money(row.amount), when)
              : t.billAskPaidFrom(payee, money(row.amount), account!, when),
          t.billAskBill(money(bill.amount), sayDate(t, bill.date)),
          if (short < 0 && category != null)
            t.billAskMore(money(-short), category!),
        ];
        answers = [
          (label: t.billAskYes, answer: _BillAnswer.paid, key: 'paid'),
          (label: t.billAskNo, answer: _BillAnswer.notIt, key: 'no'),
        ];
    }
    return Scaffold(
      backgroundColor: Mid.ground,
      appBar: AppBar(
        backgroundColor: Mid.ground,
        foregroundColor: Mid.ink,
        elevation: 0,
        leading: IconButton(
          key: const ValueKey('bill-back'),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            key: const ValueKey('bill-question'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: onest(22, weight: 600, color: Mid.ink)),
              const SizedBox(height: 16),
              for (final l in lines) ...[
                Text(l, style: onest(16, color: Mid.ink2)),
                const SizedBox(height: 8),
              ],
              const Spacer(),
              for (final (i, a) in answers.indexed) ...[
                if (i > 0) const SizedBox(height: 10),
                i == 0
                    ? FilledButton(
                        key: ValueKey('bill-${a.key}'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Mid.fill,
                          foregroundColor: Mid.onFill,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: () => Navigator.of(context).pop(a.answer),
                        child: Text(a.label, style: onest(16, weight: 600)),
                      )
                    : OutlinedButton(
                        key: ValueKey('bill-${a.key}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Mid.ink,
                          side: BorderSide(color: Mid.rule),
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: () => Navigator.of(context).pop(a.answer),
                        child: Text(a.label, style: onest(16)),
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
