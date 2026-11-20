part of 'phone_app.dart';

// The Income page on the phone (#528, owner's pick of sketch C, 2026-11-20):
// the sum's Income line opens a page of the period's paydays by date, each
// marked came, still to come or didn't come, under the sum's own figures. It
// only reads; regular income's Edit and Add come as the next piece.

/// Opens the Income page.
Future<void> _openIncome(
  BuildContext context, {
  required PhoneStore store,
  required DateTime today,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => _IncomePage(store: store, today: today),
  ),
);

class _IncomePage extends StatelessWidget {
  const _IncomePage({required this.store, required this.today});
  final PhoneStore store;
  final DateTime today;

  /// The regular incomes, each with Edit, then Add regular income; "I
  /// don't have regular income" while there is none. Only where the phone
  /// holds the ledger (figures made up have none).
  List<Widget> _regular(
    BuildContext context,
    PhoneSnapshot snapshot,
    PhoneIncome income,
  ) {
    final t = context.t;
    final data = snapshot.data;
    if (data == null) return const [];
    final pays = data.paySchedules;
    String accountName(PaySchedule p) => data.accounts[p.accountId]?.name ?? '';
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 6),
        child: Text(
          t.setupYourPay,
          style: onest(13, weight: 700, color: Mid.ink2),
        ),
      ),
      if (pays.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
          child: Text(t.phoneIncomeRules, style: onest(13, color: Mid.ink3)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Mid.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Mid.rule),
          ),
          child: Column(
            children: [
              for (final (i, p) in pays.indexed)
                Container(
                  key: ValueKey('regular-${p.id}'),
                  constraints: const BoxConstraints(minHeight: 60),
                  padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                  decoration: BoxDecoration(
                    border: i == pays.length - 1
                        ? null
                        : Border(bottom: BorderSide(color: Mid.rule)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              payTitle(t, data, p),
                              style: onest(15, weight: 600),
                            ),
                            Text(
                              t.planPayInto(
                                payAmounts(
                                  t,
                                  p,
                                  (v) => formatShort(
                                    v,
                                    currency:
                                        data.accounts[p.accountId]?.currency ??
                                        Currency.mnt,
                                  ),
                                  dotted: true,
                                ),
                                accountName(p),
                              ),
                              style: onest(13, color: Mid.ink2, tabular: true),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        key: ValueKey('edit-pay-${p.id}'),
                        onPressed: () => unawaited(
                          _openPay(
                            context,
                            store: store,
                            today: today,
                            existing: p,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(56, 44),
                          foregroundColor: Mid.blue,
                          textStyle: onest(15, weight: 600),
                        ),
                        child: Text(t.setupEdit),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 12),
      FilledButton.icon(
        key: const ValueKey('income-add-pay'),
        onPressed: () =>
            unawaited(_openPay(context, store: store, today: today)),
        icon: const Icon(Icons.add_rounded),
        label: Text(pays.isEmpty ? t.setupAddYourPay : t.setupAddOtherPay),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: Mid.green,
          foregroundColor: Colors.white,
          textStyle: onest(16, weight: 600),
        ),
      ),
      if (pays.isEmpty)
        TextButton(
          key: const ValueKey('income-no-pay'),
          onPressed: () =>
              unawaited(_sayNoPay(context, store, none: !income.saidNone)),
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: Mid.blue,
            textStyle: onest(15),
          ),
          child: Text(income.saidNone ? t.setupAskAgain : t.setupNoRegularPay),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final t = context.t;
      final snapshot = store.snapshot;
      final income = snapshot.income;
      final title = snapshot.periodEnd == null
          ? t.phoneIncomeIn(monthName(t, today.month))
          : t.phoneIncomeUntil(shortDate(snapshot.periodEnd!));
      return Scaffold(
        backgroundColor: Mid.ground,
        appBar: AppBar(
          backgroundColor: Mid.ground,
          foregroundColor: Mid.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(title, style: onest(20, weight: 600)),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            key: const ValueKey('income-page'),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              for (final sum in snapshot.sums) _IncomeFigure(sum.pool),
              if (income.paydays.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 18, 2, 6),
                  child: Text(
                    t.setupPaydays,
                    style: onest(13, weight: 700, color: Mid.ink2),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Mid.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Mid.rule),
                  ),
                  child: Column(
                    children: [
                      for (final (i, d) in income.paydays.indexed)
                        _PaydayRow(d, last: i == income.paydays.length - 1),
                    ],
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 18, 2, 0),
                  child: Text(
                    income.saidNone
                        ? t.setupSaidNoPay
                        : snapshot.pays.isEmpty
                        ? t.planPaydayNotSetUp
                        : t.phoneNoPaydays,
                    key: const ValueKey('income-no-paydays'),
                    style: onest(14, color: Mid.ink2),
                  ),
                ),
              ..._regular(context, snapshot, income),
              if (income.waiting.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 12, 2, 0),
                  child: Text(
                    t.planIncomeUncategorized(
                      [
                        for (final (c, v) in income.waiting)
                          formatMoney(v, currency: c),
                      ].join(' · '),
                    ),
                    key: const ValueKey('income-waiting'),
                    style: onest(13, color: Mid.ink2, tabular: true),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// The period's income in one currency, as the sum at the top counts it:
/// what has come and what is still to come.
class _IncomeFigure extends StatelessWidget {
  const _IncomeFigure(this.pool);
  final BudgetPool pool;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = pool.currency;
    String short(int v) => formatShort(v, currency: c);
    final total = pool.income + pool.toCome;
    return Container(
      key: ValueKey('income-figure-${c.code}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Mid.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Mid.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            short(total),
            style: onest(
              26,
              weight: 700,
              color: pool.income > 0 ? Mid.green : Mid.ink,
              tabular: true,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            pool.toCome > 0
                ? t.planIncomeToCome(short(pool.income), short(pool.toCome))
                : t.planIncomeReceived(short(pool.income)),
            key: ValueKey('income-split-${c.code}'),
            style: onest(14, color: Mid.ink2, tabular: true),
          ),
        ],
      ),
    );
  }
}

class _PaydayRow extends StatelessWidget {
  const _PaydayRow(this.payday, {required this.last});
  final PhonePayday payday;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final d = payday;
    final title =
        d.title ??
        (d.alone
            ? t.ledgerIncome
            : t.setupCategoryInto(t.ledgerIncome, d.account));
    final (words, hue) = switch (d.state) {
      PaydayState.came => (t.phonePaydayCame, Mid.green),
      PaydayState.ahead => (t.phonePaydayAhead, Mid.ink2),
      PaydayState.missed => (t.phonePaydayMissed, Mid.ink2),
    };
    return Container(
      key: ValueKey('payday-${d.date.month}-${d.date.day}-${d.title ?? ''}'),
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: Mid.rule)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              shortDate(d.date),
              style: onest(14, color: Mid.ink2, tabular: true),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: onest(15, weight: 600)),
                if (d.account.isNotEmpty)
                  Text(
                    t.phonePaydayInto(d.account),
                    style: onest(13, color: Mid.ink2),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatShort(d.amount, currency: d.currency),
                style: onest(
                  15,
                  color: d.state == PaydayState.came ? Mid.green : Mid.ink,
                  tabular: true,
                ),
              ),
              Text(words, style: onest(12, color: hue)),
            ],
          ),
        ],
      ),
    );
  }
}
