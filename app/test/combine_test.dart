// Two computers changed the ledger apart (ADR 0005, "Combine"): what one
// brings in from the other, and what it asks about instead. Three ledgers
// each time: the one both agreed on, this computer's, the other's.
import 'package:betterbudget/domain/combine.dart';
import 'package:betterbudget/domain/forecast.dart';
import 'package:betterbudget/domain/phone.dart';
import 'package:flutter_test/flutter_test.dart';

Row account(int id, String name, {String type = 'asset', int? deletedAt}) => {
  'id': id,
  'name': name,
  'type': type,
  'currency': 'MNT',
  'archived_at': null,
  'deleted_at': deletedAt,
  'role': null,
};

Row txn(
  int id,
  String date, {
  int? payee,
  String? memo,
  int scheduled = 0,
  int? pay,
  int? plan,
  int? deletedAt,
  int updatedAt = 100,
}) => {
  'id': id,
  'date': date,
  'payee_id': payee,
  'memo': memo,
  'scheduled': scheduled,
  'pay_schedule_id': pay,
  'plan_category_id': plan,
  'made_how': null,
  'made_on': null,
  'created_at': 100,
  'updated_at': updatedAt,
  'deleted_at': deletedAt,
};

Row entry(
  int id,
  int transaction,
  int account,
  int amount, {
  int cleared = 0,
  int? reconciliation,
  String? importKey,
}) => {
  'id': id,
  'transaction_id': transaction,
  'account_id': account,
  'amount_minor': amount,
  'currency': 'MNT',
  'rate': null,
  'cleared': cleared,
  'reconciliation_id': reconciliation,
  'import_key': importKey,
};

Row pref(String key, String value) => {'key': key, 'value': value};

/// A ledger: checking (1), cash (2), Groceries (3), Income (4), and one
/// purchase (transaction 10, entries 20 and 21).
LedgerRows ledger() => {
  'accounts': [
    account(1, 'Checking'),
    account(2, 'Cash'),
    account(3, 'Groceries', type: 'expense'),
    account(4, 'Income', type: 'income'),
  ],
  'payees': [
    {'id': 1, 'name': 'Nomin'},
  ],
  'pay_schedules': [
    {'id': 1, 'category_id': 4, 'account_id': 1, 'day1': 25},
  ],
  'transactions': [txn(10, '2026-10-05', payee: 1)],
  'entries': [entry(20, 10, 1, -5000), entry(21, 10, 3, 5000)],
  'reconciliations': [],
  'budget_amounts': [
    {'id': 1, 'category_id': 3, 'date': '2026-10-01', 'amount_minor': 40000},
  ],
  'category_plans': [],
  'category_accounts_off': [],
  'preferences': [pref('budget.began', '2026-10-01')],
};

LedgerRows copy(LedgerRows of) => {
  for (final e in of.entries)
    e.key: [
      for (final r in e.value) {...r},
    ],
};

/// [of] with [ops] made, as the database makes them.
LedgerRows after(LedgerRows of, List<RowOp> ops) {
  final out = copy(of);
  bool hits(Row r, Row key) => key.entries.every((k) => r[k.key] == k.value);
  for (final op in ops) {
    final rows = out[op.table]!;
    if (op.row == null) {
      rows.removeWhere((r) => hits(r, op.key));
    } else if (op.insert) {
      rows.add(op.row!);
    } else {
      rows[rows.indexWhere((r) => hits(r, op.key))] = op.row!;
    }
  }
  return out;
}

Row row(LedgerRows of, String table, int id) =>
    of[table]!.singleWhere((r) => r['id'] == id);

void main() {
  late LedgerRows base, mine, theirs;

  setUp(() {
    base = ledger();
    mine = copy(base);
    theirs = copy(base);
  });

  Combined run() => combine(base: base, mine: mine, theirs: theirs);

  /// Combines, and checks that doing it again finds nothing more to do.
  LedgerRows combined() {
    final found = run();
    expect(found.conflict, isNull);
    final result = after(mine, found.ops);
    final again = combine(base: base, mine: result, theirs: theirs);
    expect(again.conflict, isNull);
    expect(again.ops, isEmpty, reason: 'brought in twice');
    return result;
  }

  void spend(LedgerRows on, int id, {int account = 1, int amount = 7000}) {
    on['transactions']!.add(txn(id, '2026-10-06'));
    on['entries']!
      ..add(entry(id * 10, id, account, -amount))
      ..add(entry(id * 10 + 1, id, 3, amount));
  }

  test('nothing changed on the other: nothing to do', () {
    spend(mine, 50);
    final found = run();
    expect(found.conflict, isNull);
    expect(found.ops, isEmpty);
  });

  test('each added a transaction: the other’s comes in whole', () {
    spend(mine, 50);
    spend(theirs, 60);
    final found = run();
    expect(found.transactions, 1);
    expect(found.others, 0);
    final result = combined();
    expect(result['transactions']!.map((t) => t['id']), [10, 50, 60]);
    expect(
      result['entries']!.where((e) => e['transaction_id'] == 60),
      hasLength(2),
    );
  });

  test('one that came looks the same as one made here: both in, and named', () {
    spend(mine, 50);
    spend(theirs, 60);
    row(theirs, 'transactions', 60)['date'] = '2026-10-09';
    spend(theirs, 70, amount: 3000);
    final found = run();
    expect(found.transactions, 2);
    expect(found.alike, [(transaction: 60, account: 1)]);
    // A week apart isn't the same purchase.
    row(theirs, 'transactions', 60)['date'] = '2026-10-20';
    expect(run().alike, isEmpty);
  });

  test('what the other changed, deleted and added in other tables', () {
    row(theirs, 'accounts', 2)['name'] = 'Wallet';
    theirs['accounts']!.add(account(7, 'Rent', type: 'expense'));
    theirs['budget_amounts']!.add({
      'id': 9,
      'category_id': 7,
      'date': '2026-10-01',
      'amount_minor': 900000,
    });
    theirs['category_plans']!.add({'category_id': 7, 'kind': 'byDate'});
    theirs['category_accounts_off']!.add({'category_id': 7, 'account_id': 2});
    theirs['preferences']!.removeWhere((p) => p['key'] == 'budget.began');
    theirs['preferences']!.add(pref('budget.from.7', '2026-10-01'));
    spend(mine, 50);
    final found = run();
    expect(found.transactions, 0);
    expect(found.others, greaterThan(0));
    final result = combined();
    expect(row(result, 'accounts', 2)['name'], 'Wallet');
    expect(result['category_plans'], hasLength(1));
    expect(result['category_accounts_off'], hasLength(1));
    expect(result['preferences']!.map((p) => p['key']), ['budget.from.7']);
    expect(result['transactions'], hasLength(2));
  });

  test('one renamed an account and the other archived it: both', () {
    row(mine, 'accounts', 2)['name'] = 'Wallet';
    row(theirs, 'accounts', 2)['archived_at'] = 500;
    final result = combined();
    expect(row(result, 'accounts', 2)['name'], 'Wallet');
    expect(row(result, 'accounts', 2)['archived_at'], 500);
  });

  test('one account given two names is asked about', () {
    row(mine, 'accounts', 2)['name'] = 'Wallet';
    row(theirs, 'accounts', 2)['name'] = 'Pocket';
    expect(run().conflict, contains('name changed on both'));
  });

  test('one cleared a row and the other filed it: both', () {
    row(mine, 'entries', 20)['cleared'] = 1;
    theirs['accounts']!.add(account(7, 'Eating out', type: 'expense'));
    row(theirs, 'entries', 21)['account_id'] = 7;
    row(theirs, 'transactions', 10)['updated_at'] = 300;
    row(mine, 'transactions', 10)['updated_at'] = 200;
    final result = combined();
    expect(row(result, 'entries', 20)['cleared'], 1);
    expect(row(result, 'entries', 21)['account_id'], 7);
    expect(row(result, 'transactions', 10)['updated_at'], 300);
  });

  test('a payee renamed there counts as a change; a new one comes with its '
      'row and doesn’t', () {
    row(theirs, 'payees', 1)['name'] = 'Nomin Supermarket';
    expect(run().others, 1);
    theirs = copy(base);
    theirs['payees']!.add({'id': 2, 'name': 'Unitel'});
    spend(theirs, 50);
    row(theirs, 'transactions', 50)['payee_id'] = 2;
    final found = run();
    expect(found.transactions, 1);
    expect(found.others, 0);
  });

  test('one transaction edited on both is asked about, never doubled', () {
    // Each edit wrote its entries as new rows.
    for (final (side, first, amount) in [
      (mine, 30, 6000),
      (theirs, 40, 8000),
    ]) {
      side['entries']!
        ..clear()
        ..add(entry(first, 10, 1, -amount))
        ..add(entry(first + 1, 10, 3, amount));
    }
    final found = run();
    expect(found.conflict, isNull);
    expect(found.asking, isTrue);
    expect(found.ops, isEmpty);
    expect(found.asks.single.id, 'transaction|10');
    expect(found.asks.single.mine.lines.map((l) => l.amountMinor), [
      -6000,
      6000,
    ]);
    expect(found.asks.single.theirs.lines.map((l) => l.amountMinor), [
      -8000,
      8000,
    ]);
    expect(found.asks.single.neither.lines.map((l) => l.amountMinor), [
      -5000,
      5000,
    ]);
    for (final (pick, amount) in [
      (Pick.mine, 6000),
      (Pick.theirs, 8000),
      (Pick.neither, 5000),
    ]) {
      final settled = combine(
        base: base,
        mine: mine,
        theirs: theirs,
        picks: {'transaction|10': pick},
      );
      expect(settled.conflict, isNull);
      expect(settled.asking, isFalse);
      final result = after(mine, settled.ops);
      expect(
        [for (final e in result['entries']!) e['amount_minor']],
        [-amount, amount],
        reason: '$pick',
      );
    }
  });

  test('an amount changed on both entries of one row is one question', () {
    row(mine, 'entries', 20)['amount_minor'] = -6000;
    row(mine, 'entries', 21)['amount_minor'] = 6000;
    row(theirs, 'entries', 20)['amount_minor'] = -9000;
    row(theirs, 'entries', 21)['amount_minor'] = 9000;
    // Something else the other did comes in with the answer, not before.
    spend(theirs, 50);
    final found = run();
    expect(found.asking, isTrue);
    expect(found.asks, hasLength(1));
    final settled = combine(
      base: base,
      mine: mine,
      theirs: theirs,
      picks: {'transaction|10': Pick.theirs},
    );
    final result = after(mine, settled.ops);
    expect(row(result, 'entries', 20)['amount_minor'], -9000);
    expect(row(result, 'entries', 21)['amount_minor'], 9000);
    expect(row(result, 'transactions', 50)['date'], '2026-10-06');
    expect(settled.transactions, 1);
    // Done again, nothing is left to do or to ask.
    final again = combine(base: base, mine: result, theirs: theirs);
    expect(again.asking, isFalse);
    expect(again.ops, isEmpty);
  });

  test('a row both gave another payee and memo keeps the chosen one whole', () {
    mine['payees']!.add({'id': 2, 'name': 'Unitel'});
    row(mine, 'transactions', 10)
      ..['payee_id'] = 2
      ..['memo'] = 'a';
    row(theirs, 'transactions', 10)['memo'] = 'b';
    final found = run();
    expect(found.asking, isTrue);
    expect(found.asks.single.theirs.memo, 'b');
    expect(found.asks.single.mine.payee, 'Unitel');
    final result = after(
      mine,
      combine(
        base: base,
        mine: mine,
        theirs: theirs,
        picks: {'transaction|10': Pick.theirs},
      ).ops,
    );
    final t = row(result, 'transactions', 10);
    expect(t['memo'], 'b');
    // Taken whole: the payee is the other's too, which was unchanged.
    expect(t['payee_id'], 1);
  });

  test('amounts changed on both sides of one transaction don’t add up', () {
    row(mine, 'entries', 20)['amount_minor'] = -6000;
    row(theirs, 'entries', 21)['amount_minor'] = 6000;
    final result = combined();
    expect(row(result, 'entries', 20)['amount_minor'], -6000);
    expect(row(result, 'entries', 21)['amount_minor'], 6000);
    // Only one side of it changed: that is refused.
    theirs = copy(base);
    row(theirs, 'transactions', 10)['memo'] = 'milk';
    row(mine, 'entries', 21)['amount_minor'] = 5000;
    expect(run().conflict, contains('wouldn’t add up'));
  });

  test('changed on one and deleted on the other is asked about', () {
    // A delete marks the row; it stays in the table.
    row(mine, 'transactions', 10)['deleted_at'] = 900;
    row(theirs, 'entries', 20)['amount_minor'] = -50000;
    row(theirs, 'entries', 21)['amount_minor'] = 50000;
    var found = run();
    expect(found.conflict, isNull);
    expect(found.asks.single.mine.deleted, isTrue);
    expect(found.asks.single.theirs.deleted, isFalse);
    // Neither: as it was, not deleted and not changed.
    final result = after(
      mine,
      combine(
        base: base,
        mine: mine,
        theirs: theirs,
        picks: {'transaction|10': Pick.neither},
      ).ops,
    );
    expect(row(result, 'transactions', 10)['deleted_at'], isNull);
    expect(row(result, 'entries', 20)['amount_minor'], -5000);
    // And the other way about.
    (mine, theirs) = (theirs, mine);
    found = run();
    expect(found.asks.single.mine.deleted, isFalse);
    expect(found.asks.single.theirs.deleted, isTrue);
  });

  test('a payday confirmed here isn’t taken away by a change of the pay '
      'there', () {
    base['transactions']!.add(txn(50, '2026-10-25', scheduled: 1, pay: 1));
    base['entries']!
      ..add(entry(500, 50, 1, 250000))
      ..add(entry(501, 50, 4, -250000));
    mine = copy(base);
    theirs = copy(base);
    // Confirmed here; there the pay changed, which drops its waiting payday.
    row(mine, 'transactions', 50)
      ..['scheduled'] = 0
      ..['date'] = '2026-10-24';
    row(theirs, 'pay_schedules', 1)['day1'] = 20;
    row(theirs, 'transactions', 50)
      ..['deleted_at'] = 300
      ..['pay_schedule_id'] = null;
    // Never taken away on its own: the person says.
    final found = run();
    expect(found.conflict, isNull);
    expect(found.asks.single.id, 'transaction|50');
    expect(found.asks.single.theirs.deleted, isTrue);
    expect(found.asks.single.mine.deleted, isFalse);
  });

  test('deleted on the other and untouched here: it goes', () {
    row(theirs, 'transactions', 10)['deleted_at'] = 900;
    // One deleted there isn't one that came from there.
    expect(run().transactions, 0);
    expect(run().others, 1);
    expect(row(combined(), 'transactions', 10)['deleted_at'], 900);
  });

  test('deleted on both, or put away on both: they agree', () {
    row(mine, 'transactions', 10)['deleted_at'] = 900;
    row(theirs, 'transactions', 10)['deleted_at'] = 950;
    row(mine, 'accounts', 2)['archived_at'] = 900;
    row(theirs, 'accounts', 2)['archived_at'] = 950;
    final found = run();
    expect(found.conflict, isNull);
    expect(found.ops, isEmpty);
  });

  test('a folder’s ledger that lacks what both agreed on was replaced '
      'there: asked about, not brought in as deletions', () {
    theirs['transactions']!.clear();
    theirs['entries']!.clear();
    spend(mine, 50);
    expect(run().conflict, contains('lacks transaction'));
    theirs = copy(base);
    theirs['accounts']!.removeWhere((a) => a['id'] == 2);
    expect(run().conflict, contains('lacks account'));
  });

  test('a cleared row inside a statement the other reconciled is asked '
      'about', () {
    mine['reconciliations']!.add({
      'id': 5,
      'account_id': 1,
      'statement_date': '2026-10-05',
    });
    spend(theirs, 60);
    row(theirs, 'transactions', 60)['date'] = '2026-10-03';
    // Not cleared: it only waits for the next statement.
    expect(run().conflict, isNull);
    row(theirs, 'entries', 600)['cleared'] = 1;
    expect(run().conflict, contains('inside a statement'));
    // After the statement's date it is the next statement's.
    row(theirs, 'transactions', 60)['date'] = '2026-10-06';
    expect(run().conflict, isNull);
  });

  test('assigned amounts moved from one category to another there', () {
    // A category merged into another moves its rows where they are.
    theirs['accounts']!.add(account(7, 'Food', type: 'expense'));
    row(theirs, 'budget_amounts', 1)['category_id'] = 7;
    final result = combined();
    expect(result['budget_amounts']!.single['category_id'], 7);
  });

  test('a row reconciled here and changed there is asked about', () {
    mine['reconciliations']!.add({'id': 5, 'account_id': 1});
    row(mine, 'entries', 20)
      ..['cleared'] = 2
      ..['reconciliation_id'] = 5;
    row(theirs, 'transactions', 10)['date'] = '2026-10-04';
    expect(run().conflict, contains('reconciled on one'));
    // Filed under another category there: that a locked row allows.
    theirs = copy(base);
    theirs['accounts']!.add(account(7, 'Eating out', type: 'expense'));
    row(theirs, 'entries', 21)['account_id'] = 7;
    final result = combined();
    expect(row(result, 'entries', 20)['reconciliation_id'], 5);
    expect(row(result, 'entries', 21)['account_id'], 7);
  });

  test('one account reconciled on both is asked about', () {
    mine['reconciliations']!.add({'id': 5, 'account_id': 1});
    theirs['reconciliations']!.add({'id': 6, 'account_id': 1});
    expect(run().conflict, contains('reconciled on both'));
  });

  test('an account deleted here and spent from there is asked about', () {
    row(mine, 'accounts', 2)['deleted_at'] = 900;
    spend(theirs, 60, account: 2);
    expect(run().conflict, contains('deleted on one and used'));
  });

  test('an amount assigned on one computer comes in as one amount', () {
    // A change of what is assigned writes a new row.
    theirs['budget_amounts'] = [
      {'id': 8, 'category_id': 3, 'date': '2026-10-01', 'amount_minor': 55000},
    ];
    final result = combined();
    expect(result['budget_amounts']!.single['amount_minor'], 55000);
  });

  test('one category assigned on both for one period is asked about', () {
    mine['budget_amounts'] = [
      {'id': 7, 'category_id': 3, 'date': '2026-10-01', 'amount_minor': 60000},
    ];
    theirs['budget_amounts'] = [
      {'id': 8, 'category_id': 3, 'date': '2026-10-01', 'amount_minor': 55000},
    ];
    final found = run();
    expect(found.conflict, isNull);
    expect(found.asks.single.kind, AskKind.assigned);
    expect(found.asks.single.category, 'Groceries');
    expect(found.asks.single.mine.assignedMinor, 60000);
    expect(found.asks.single.theirs.assignedMinor, 55000);
    expect(found.asks.single.neither.assignedMinor, 40000);
    for (final (pick, amount) in [
      (Pick.mine, 60000),
      (Pick.theirs, 55000),
      (Pick.neither, 40000),
    ]) {
      final result = after(
        mine,
        combine(
          base: base,
          mine: mine,
          theirs: theirs,
          picks: {found.asks.single.id: pick},
        ).ops,
      );
      expect(result['budget_amounts']!.single['amount_minor'], amount);
    }
    // Another period is no conflict.
    theirs['budget_amounts'] = [
      ...base['budget_amounts']!,
      {'id': 8, 'category_id': 3, 'date': '2026-11-01', 'amount_minor': 55000},
    ];
    expect(combined()['budget_amounts'], hasLength(2));
  });

  test('what is asked about is still held to the reconcile and deleted-'
      'account checks against what the other really has', () {
    // A memo changed two ways makes the transaction a question; the other
    // also cleared its row inside the statement this computer reconciled.
    mine['reconciliations']!.add({
      'id': 5,
      'account_id': 1,
      'statement_date': '2026-10-05',
    });
    row(mine, 'transactions', 10)['memo'] = 'a';
    row(theirs, 'transactions', 10)['memo'] = 'b';
    row(theirs, 'entries', 20)['cleared'] = 1;
    expect(run().conflict, contains('statement reconciled on the other'));
    // And a row moved into an account deleted here.
    mine = copy(base);
    theirs = copy(base);
    row(mine, 'accounts', 2)['deleted_at'] = 900;
    row(mine, 'transactions', 10)['memo'] = 'a';
    row(theirs, 'transactions', 10)['memo'] = 'b';
    row(theirs, 'entries', 20)['account_id'] = 2;
    expect(run().conflict, contains('deleted on one and used'));
  });

  test('a pay changed on both is asked about, whichever days', () {
    row(mine, 'pay_schedules', 1)['day1'] = 10;
    row(theirs, 'pay_schedules', 1)['account_id'] = 2;
    expect(run().conflict, contains('pay_schedules 1 changed on both'));
  });

  test('a setting changed on both: asked, unless it only changes a view', () {
    mine['preferences'] = [pref('budget.began', '2026-09-01')];
    theirs['preferences'] = [pref('budget.began', '2026-08-01')];
    expect(run().conflict, contains('budget.began'));
    mine['preferences'] = [
      ...base['preferences']!,
      pref(ForecastSpan.prefKey, 'a'),
    ];
    theirs['preferences'] = [
      ...base['preferences']!,
      pref(ForecastSpan.prefKey, 'b'),
    ];
    final found = run();
    expect(found.conflict, isNull);
    expect(found.ops, isEmpty);
  });

  test('the counts each computer keeps are never brought in', () {
    theirs['preferences']!.add(pref('sync.seal', 'abc'));
    mine['preferences']!.add(pref('sync.seal', 'def'));
    expect(run().ops, isEmpty);
  });

  group('the same thing made on both', () {
    test('a payee both typed is one payee', () {
      for (final (side, payee, id) in [(mine, 31, 50), (theirs, 32, 60)]) {
        side['payees']!.add({'id': payee, 'name': 'E-Mart'});
        spend(side, id);
        row(side, 'transactions', id)['payee_id'] = payee;
      }
      final result = combined();
      expect(result['payees']!.map((p) => p['id']), [1, 31]);
      expect(row(result, 'transactions', 60)['payee_id'], 31);
    });

    test('a payee the other already made one with its own: on the next '
        'round this computer follows', () {
      // Both typed E-Mart (31 here). The other combined, kept its own 32,
      // and wrote; this computer has gone on using 31 meanwhile.
      base['payees']!.add({'id': 31, 'name': 'E-Mart'});
      spend(base, 40);
      row(base, 'transactions', 40)['payee_id'] = 31;
      mine = copy(base);
      theirs = copy(base);
      theirs['payees']!
        ..removeWhere((p) => p['id'] == 31)
        ..add({'id': 32, 'name': 'E-Mart'});
      row(theirs, 'transactions', 40)['payee_id'] = 32;
      spend(mine, 50);
      row(mine, 'transactions', 50)['payee_id'] = 31;
      final result = combined();
      expect(result['payees']!.map((p) => p['id']), [1, 32]);
      expect(row(result, 'transactions', 40)['payee_id'], 32);
      expect(row(result, 'transactions', 50)['payee_id'], 32);
    });

    test('Income, which each made for itself, is one', () {
      base['accounts']!.removeWhere((a) => a['id'] == 4);
      base['pay_schedules']!.clear();
      mine = copy(base);
      theirs = copy(base);
      mine['accounts']!.add(account(41, 'Income', type: 'income'));
      theirs['accounts']!.add(account(42, 'Орлого', type: 'income'));
      theirs['transactions']!.add(txn(60, '2026-10-06'));
      theirs['entries']!
        ..add(entry(600, 60, 1, 250000))
        ..add(entry(601, 60, 42, -250000));
      final result = combined();
      expect(
        result['accounts']!.where((a) => a['type'] == 'income').single['id'],
        41,
      );
      expect(row(result, 'entries', 601)['account_id'], 41);
    });

    test('a category a phone made, taken in by both, is one', () {
      String taken(int category, String entry) => PhoneTaken.encode({
        'pixel': PhoneTaken(entries: {entry}, categories: {'p1': '$category'}),
      });
      mine['accounts']!.add(account(51, 'Coffee', type: 'expense'));
      mine['preferences']!.add(pref(phoneTakenKey, taken(51, 'e1')));
      spend(mine, 50);
      row(mine, 'entries', 501)['account_id'] = 51;
      theirs['accounts']!.add(account(52, 'coffee', type: 'expense'));
      theirs['preferences']!
        ..add(pref(phoneTakenKey, taken(52, 'e1')))
        ..add(pref('budget.from.52', '2026-10-01'));
      spend(theirs, 60);
      row(theirs, 'entries', 601)['account_id'] = 52;
      final result = combined();
      // One category, one transaction, and the setting names the one kept.
      expect(result['accounts']!.where((a) => a['id'] == 52), isEmpty);
      expect(result['transactions']!.map((t) => t['id']), [10, 50]);
      expect(
        result['preferences']!.map((p) => p['key']),
        contains('budget.from.51'),
      );
    });

    test('a phone’s entry both took in and one changed is asked about', () {
      String taken(String entry) => PhoneTaken.encode({
        'pixel': PhoneTaken(entries: {entry}),
      });
      for (final (side, id) in [(mine, 50), (theirs, 60)]) {
        side['preferences']!.add(pref(phoneTakenKey, taken('e1')));
        spend(side, id);
      }
      row(theirs, 'transactions', 60)['memo'] = 'beans';
      expect(run().conflict, contains('phone’s entry'));
    });

    test('entries each took from a phone alone both stay taken', () {
      String taken(String entry) => PhoneTaken.encode({
        'pixel': PhoneTaken(entries: {entry}),
      });
      mine['preferences']!.add(pref(phoneTakenKey, taken('e1')));
      spend(mine, 50);
      theirs['preferences']!.add(pref(phoneTakenKey, taken('e2')));
      spend(theirs, 60);
      final result = combined();
      final all = PhoneTaken.decode(
        result['preferences']!.singleWhere(
              (p) => p['key'] == phoneTakenKey,
            )['value']
            as String,
      );
      expect(all['pixel']!.entries, {'e1', 'e2'});
      expect(result['transactions'], hasLength(3));
    });

    test('the payday each scheduled for itself is one', () {
      for (final (side, id) in [(mine, 50), (theirs, 60)]) {
        side['transactions']!.add(txn(id, '2026-10-25', scheduled: 1, pay: 1));
        side['entries']!
          ..add(entry(id * 10, id, 1, 250000))
          ..add(entry(id * 10 + 1, id, 4, -250000));
      }
      final found = run();
      expect(found.ops, isEmpty);
      // Confirmed there since: theirs is the one kept.
      row(theirs, 'transactions', 60)['scheduled'] = 0;
      final result = combined();
      expect(result['transactions']!.map((t) => t['id']), [10, 60]);
      expect(result['entries']!.map((e) => e['transaction_id']).toSet(), {
        10,
        60,
      });
    });

    test('a payday both scheduled under one id is one row, its times merged, '
        'and nothing to tell', () {
      const id = 0x4000000000000070;
      for (final (side, made) in [(mine, 100), (theirs, 300)]) {
        side['transactions']!.add(
          txn(id, '2026-10-25', scheduled: 1, pay: 1, updatedAt: made)
            ..['created_at'] = made,
        );
        side['entries']!
          ..add(entry(0x4000000000000700, id, 1, 250000))
          ..add(entry(0x4000000000000701, id, 4, -250000));
      }
      final found = run();
      expect(found.conflict, isNull);
      expect(found.transactions, 0);
      expect(found.others, 0);
      final result = after(mine, found.ops);
      expect(result['transactions']!.where((t) => t['id'] == id), hasLength(1));
      expect(row(result, 'transactions', id)['created_at'], 100);
      expect(row(result, 'transactions', id)['updated_at'], 300);
      expect(
        result['entries']!.where((e) => e['transaction_id'] == id),
        hasLength(2),
      );
    });

    test('a bank row imported on both under one id, each saying where: one '
        'row, nothing to tell, the same word kept on either side', () {
      const id = 0x4000000000000071;
      for (final (side, on) in [
        (mine, 'Tom’s MacBook Air'),
        (theirs, 'Mac mini'),
      ]) {
        side['transactions']!.add(
          txn(id, '2026-10-20')
            ..['made_how'] = 'imported'
            ..['made_on'] = on,
        );
        side['entries']!
          ..add(entry(0x4000000000000710, id, 1, -12000))
          ..add(entry(0x4000000000000711, id, 4, 12000));
      }
      var found = run();
      expect(found.conflict, isNull);
      expect(found.asking, isFalse);
      expect(found.transactions, 0);
      var result = after(mine, found.ops);
      final kept = row(result, 'transactions', id)['made_on'];
      expect(kept, 'Mac mini');
      // The other computer reaches the same word.
      (mine, theirs) = (theirs, mine);
      found = run();
      result = after(mine, found.ops);
      expect(row(result, 'transactions', id)['made_on'], kept);
      expect(row(result, 'transactions', id)['made_how'], 'imported');
    });

    test('a row from a computer before v21 (no where-it-came-from) is the same '
        'row as one made on both, and a delete there is no question', () {
      const id = 0x4000000000000072;
      for (final side in [mine, theirs]) {
        side['transactions']!.add(txn(id, '2026-10-21', scheduled: 1, pay: 1));
        side['entries']!
          ..add(entry(0x4000000000000720, id, 1, 250000))
          ..add(entry(0x4000000000000721, id, 4, -250000));
      }
      // This computer is v21 and stamped it; the other is v20 and has no keys.
      row(mine, 'transactions', id)
        ..['made_how'] = 'scheduled'
        ..['made_on'] = null;
      row(theirs, 'transactions', id)
        ..remove('made_how')
        ..remove('made_on');
      var found = run();
      expect(found.conflict, isNull);
      expect(found.asking, isFalse);

      // The other, v20, deletes a row this computer made and left alone;
      // its base copy has no keys either.
      mine = copy(base);
      theirs = copy(base);
      base['transactions']!.add(txn(80, '2026-10-01'));
      base['entries']!
        ..add(entry(800, 80, 1, -1000))
        ..add(entry(801, 80, 4, 1000));
      mine = copy(base);
      theirs = copy(base);
      for (final r in base['transactions']!) {
        r.remove('made_how');
        r.remove('made_on');
      }
      row(mine, 'transactions', 80)['made_how'] = 'typed';
      row(theirs, 'transactions', 80)
        ..remove('made_how')
        ..remove('made_on')
        ..['deleted_at'] = 500;
      found = run();
      expect(found.conflict, isNull);
      expect(found.asking, isFalse);
    });

    test('Source turned on on one computer and off on the other is no '
        'question, and a phone named two ways is named the same on both', () {
      for (final (side, on, name) in [
        (mine, '1', 'Pixel'),
        (theirs, null, 'Galaxy'),
      ]) {
        if (on != null) {
          side['preferences']!.add({'key': showSourceKey, 'value': on});
        }
        side['preferences']!.add({
          'key': '${phoneNamePrefix}7b8a',
          'value': name,
        });
      }
      final found = run();
      expect(found.conflict, isNull);
      expect(found.asking, isFalse);
      var result = after(mine, found.ops);
      final kept = result['preferences']!.singleWhere(
        (p) => p['key'] == '${phoneNamePrefix}7b8a',
      )['value'];
      expect(kept, 'Galaxy');
      (mine, theirs) = (theirs, mine);
      result = after(mine, run().ops);
      expect(
        result['preferences']!.singleWhere(
          (p) => p['key'] == '${phoneNamePrefix}7b8a',
        )['value'],
        kept,
      );
    });

    test('a computer renamed two ways is named the same on both, and no '
        'question', () {
      const key = '${computerNamePrefix}aaaa';
      mine['preferences']!.add({'key': key, 'value': 'Mac mini'});
      theirs['preferences']!.add({'key': key, 'value': 'Desk'});
      var found = run();
      expect(found.conflict, isNull);
      expect(found.asking, isFalse);
      final kept = after(
        mine,
        found.ops,
      )['preferences']!.singleWhere((p) => p['key'] == key)['value'];
      expect(kept, 'Desk');
      (mine, theirs) = (theirs, mine);
      found = run();
      expect(
        after(
          mine,
          found.ops,
        )['preferences']!.singleWhere((p) => p['key'] == key)['value'],
        kept,
      );
    });

    test('a payday both scheduled under one id, confirmed on one: the '
        'confirmed one is kept, whichever side', () {
      const id = 0x4000000000000070;
      for (final side in [mine, theirs]) {
        side['transactions']!.add(txn(id, '2026-10-25', scheduled: 1, pay: 1));
        side['entries']!
          ..add(entry(0x4000000000000700, id, 1, 250000))
          ..add(entry(0x4000000000000701, id, 4, -250000));
      }
      // Confirmed there, a day early and for a little more.
      row(theirs, 'transactions', id)
        ..['scheduled'] = 0
        ..['date'] = '2026-10-24'
        ..['updated_at'] = 400;
      row(theirs, 'entries', 0x4000000000000700)['amount_minor'] = 260000;
      row(theirs, 'entries', 0x4000000000000701)['amount_minor'] = -260000;
      var result = combined();
      expect(row(result, 'transactions', id)['scheduled'], 0);
      expect(row(result, 'transactions', id)['date'], '2026-10-24');
      expect(
        row(result, 'entries', 0x4000000000000700)['amount_minor'],
        260000,
      );
      // Confirmed here: nothing to do.
      (mine, theirs) = (theirs, mine);
      final found = run();
      expect(found.conflict, isNull);
      expect(found.ops, isEmpty);
      // Confirmed on both for different amounts: asked, as a block.
      row(theirs, 'transactions', id)
        ..['scheduled'] = 0
        ..['updated_at'] = 500;
      row(theirs, 'entries', 0x4000000000000700)['amount_minor'] = 270000;
      row(theirs, 'entries', 0x4000000000000701)['amount_minor'] = -270000;
      final asked = run();
      expect(asked.conflict, isNull);
      expect(asked.asking, isTrue);
      expect(asked.asks.single.id, 'transaction|$id');
      // Nothing was there before either: "neither" isn't offered.
      expect(asked.asks.single.hasBase, isFalse);
      result = after(
        mine,
        combine(
          base: base,
          mine: mine,
          theirs: theirs,
          picks: {'transaction|$id': Pick.theirs},
        ).ops,
      );
      expect(
        row(result, 'entries', 0x4000000000000700)['amount_minor'],
        270000,
      );
    });

    test('Income made on both under one id, named differently: this '
        'computer’s stays', () {
      const id = 0x4000000000000004;
      for (final (side, name) in [(mine, 'Income'), (theirs, 'Орлого')]) {
        side['accounts']!.add(account(id, name, type: 'income'));
      }
      final found = run();
      expect(found.conflict, isNull);
      expect(found.ops, isEmpty);
    });

    test('the payday each scheduled, confirmed there on another day, edited '
        'or skipped: theirs is the one kept', () {
      void each() {
        mine = copy(base);
        theirs = copy(base);
        for (final (side, id) in [(mine, 50), (theirs, 60)]) {
          side['transactions']!.add(
            txn(id, '2026-10-25', scheduled: 1, pay: 1),
          );
          side['entries']!
            ..add(entry(id * 10, id, 1, 250000))
            ..add(entry(id * 10 + 1, id, 4, -250000));
        }
      }

      // Confirmed a day early.
      each();
      row(theirs, 'transactions', 60)
        ..['scheduled'] = 0
        ..['date'] = '2026-10-24';
      expect(combined()['transactions']!.map((t) => t['id']), [10, 60]);
      // Skipped.
      each();
      row(theirs, 'transactions', 60)['deleted_at'] = 700;
      expect(combined()['transactions']!.map((t) => t['id']), [10, 60]);
      // Another amount, still waiting: which is right isn't known.
      each();
      row(theirs, 'entries', 600)['amount_minor'] = 230000;
      row(theirs, 'entries', 601)['amount_minor'] = -230000;
      expect(run().conflict, contains('changed on both'));
    });

    test('a pay changed there: the payday scheduled here from the old one '
        'goes', () {
      // Here the 25th was scheduled; there the pay moved to the 20th, and
      // its payday with it.
      mine['transactions']!.add(txn(50, '2026-10-25', scheduled: 1, pay: 1));
      mine['entries']!
        ..add(entry(500, 50, 1, 250000))
        ..add(entry(501, 50, 4, -250000));
      row(theirs, 'pay_schedules', 1)['day1'] = 20;
      theirs['transactions']!.add(txn(60, '2026-10-20', scheduled: 1, pay: 1));
      theirs['entries']!
        ..add(entry(600, 60, 1, 250000))
        ..add(entry(601, 60, 4, -250000));
      final result = combined();
      expect(result['transactions']!.map((t) => t['id']), [10, 60]);
      expect(row(result, 'pay_schedules', 1)['day1'], 20);
    });

    test('a bank row both imported is one; filed two ways, asked about', () {
      for (final (side, id) in [(mine, 50), (theirs, 60)]) {
        spend(side, id);
        row(side, 'entries', id * 10)['import_key'] = 'a1|2026-10-06|7000';
      }
      expect(combined()['transactions']!.map((t) => t['id']), [10, 50]);
      theirs['accounts']!.add(account(7, 'Eating out', type: 'expense'));
      row(theirs, 'entries', 601)['account_id'] = 7;
      expect(run().conflict, contains('one bank row in both'));
    });
  });

  test('rows of one id that aren’t one row are asked about, as a block', () {
    // Made on two computers by a build that counted ids from 1.
    spend(mine, 11, amount: 3000);
    spend(theirs, 11, amount: 9000);
    final found = run();
    expect(found.conflict, isNull);
    expect(found.asking, isTrue);
    expect(found.asks.single.id, 'transaction|11');
  });

  test('a table this build doesn’t know stops it', () {
    theirs['goals'] = [];
    expect(run().conflict, contains('goals'));
  });
}
