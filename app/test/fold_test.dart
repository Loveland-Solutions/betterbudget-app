// Another computer's changes folded into what combine compares (ADR 0005,
// step 3): from this computer's rows and the other's change records, the
// base and the other's ledger.
import 'package:betterbudget/domain/combine.dart';
import 'package:betterbudget/domain/fold.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Row txn(int id, String memo) => {
    'id': id,
    'date': '2026-10-05',
    'memo': memo,
    'created_at': 100,
    'updated_at': 100,
  };
  FoldChange change(String op, Row? before, Row? after) => FoldChange(
    tbl: 'transactions',
    pk: {'id': (before ?? after)!['id']},
    op: op,
    before: before,
    after: after,
  );
  Row? find(LedgerRows of, int id) =>
      of['transactions']!.where((t) => t['id'] == id).firstOrNull;

  test('a change to a row as it is here: the base is this row, the other’s '
      'is the change', () {
    final mine = {
      'transactions': [txn(1, 'a')],
    };
    final out = foldChanges(mine, [change('update', txn(1, 'a'), txn(1, 'b'))]);
    expect(find(out.base, 1)!['memo'], 'a');
    expect(find(out.theirs, 1)!['memo'], 'b');
    // This computer's rows are untouched.
    expect(find(mine, 1)!['memo'], 'a');
  });

  test('a row changed here too: the base is what the other found, so '
      'combine sees two changes', () {
    final mine = {
      'transactions': [txn(1, 'mine')],
    };
    final out = foldChanges(mine, [change('update', txn(1, 'a'), txn(1, 'b'))]);
    expect(find(out.base, 1)!['memo'], 'a');
    expect(find(out.theirs, 1)!['memo'], 'b');
  });

  test('several changes to one row: the first before, the last after', () {
    final mine = {
      'transactions': [txn(1, 'a')],
    };
    final out = foldChanges(mine, [
      change('update', txn(1, 'a'), txn(1, 'b')),
      change('update', txn(1, 'b'), txn(1, 'c')),
    ]);
    expect(find(out.base, 1)!['memo'], 'a');
    expect(find(out.theirs, 1)!['memo'], 'c');
  });

  test('the other saw this computer’s version along the way (an answer to a '
      'question): the base is this row and its answer stands', () {
    // The other edited a→b, then, shown this computer's "mine", chose it:
    // a change from mine to mine.
    final mine = {
      'transactions': [txn(1, 'mine')],
    };
    final out = foldChanges(mine, [
      change('update', txn(1, 'a'), txn(1, 'b')),
      change('update', txn(1, 'mine'), txn(1, 'mine')),
    ]);
    expect(find(out.base, 1)!['memo'], 'mine');
    expect(find(out.theirs, 1)!['memo'], 'mine');
    // Or chose its own: a change from mine to b.
    final chose = foldChanges(mine, [
      change('update', txn(1, 'a'), txn(1, 'b')),
      change('update', txn(1, 'mine'), txn(1, 'b')),
    ]);
    expect(find(chose.base, 1)!['memo'], 'mine');
    expect(find(chose.theirs, 1)!['memo'], 'b');
  });

  test('what this computer did since isn’t in the other’s ledger, nor the '
      'base', () {
    // Both changed the assigned amount: each deleted the old row and made
    // its own. Theirs must not hold this computer's new row.
    final mine = {
      'budget_amounts': [
        {'id': 50, 'category_id': 3, 'date': '2026-10-01', 'amount_minor': 500},
      ],
    };
    final old = {
      'id': 1,
      'category_id': 3,
      'date': '2026-10-01',
      'amount_minor': 400,
    };
    FoldChange b(String op, Row? before, Row? after) => FoldChange(
      tbl: 'budget_amounts',
      pk: {'id': (before ?? after)!['id']},
      op: op,
      before: before,
      after: after,
    );
    final out = foldChanges(
      mine,
      [
        b('delete', old, null),
        b('insert', null, {...old, 'id': 45, 'amount_minor': 450}),
      ],
      mineSince: [
        b('delete', old, null),
        b('insert', null, mine['budget_amounts']![0]),
      ],
    );
    int sum(LedgerRows of) =>
        of['budget_amounts']!.fold(0, (s, r) => s + (r['amount_minor'] as int));
    expect(sum(out.base), 400);
    expect(sum(out.theirs), 450);
    expect(sum(mine), 500);
    // Changed here alone: the other's is the base, and this one's stands.
    final alone = foldChanges(
      mine,
      const [],
      mineSince: [
        b('delete', old, null),
        b('insert', null, mine['budget_amounts']![0]),
      ],
    );
    expect(sum(alone.base), 400);
    expect(sum(alone.theirs), 400);
  });

  test('an insert and a delete', () {
    final mine = {
      'transactions': [txn(1, 'a')],
    };
    final out = foldChanges(mine, [
      change('insert', null, txn(2, 'new')),
      change('delete', txn(1, 'a'), null),
    ]);
    expect(find(out.base, 2), isNull);
    expect(find(out.theirs, 2)!['memo'], 'new');
    expect(find(out.base, 1)!['memo'], 'a');
    expect(find(out.theirs, 1), isNull);
  });

  test('a row both made under one id: no base, the other’s version', () {
    final mine = {
      'transactions': [txn(7, 'x')..['created_at'] = 100],
    };
    final out = foldChanges(mine, [
      change('insert', null, txn(7, 'x')..['created_at'] = 300),
    ]);
    expect(find(out.base, 7), isNull);
    expect(find(out.theirs, 7)!['created_at'], 300);
  });

  test('a table this build doesn’t know is left out', () {
    final mine = {
      'transactions': [txn(1, 'a')],
    };
    final out = foldChanges(mine, [
      FoldChange(
        tbl: 'goals',
        pk: {'id': 1},
        op: 'insert',
        before: null,
        after: {'id': 1},
      ),
    ]);
    expect(out.theirs.containsKey('goals'), isFalse);
  });

  test('folded into combine: a change comes in; a crossed one is asked', () {
    final base = {
      'accounts': [
        {
          'id': 1,
          'name': 'Checking',
          'type': 'asset',
          'currency': 'MNT',
          'archived_at': null,
          'deleted_at': null,
          'role': null,
        },
        {
          'id': 3,
          'name': 'Groceries',
          'type': 'expense',
          'currency': 'MNT',
          'archived_at': null,
          'deleted_at': null,
          'role': null,
        },
      ],
      'payees': <Row>[],
      'pay_schedules': <Row>[],
      'transactions': [
        {
          'id': 10,
          'date': '2026-10-05',
          'payee_id': null,
          'memo': null,
          'scheduled': 0,
          'pay_schedule_id': null,
          'plan_category_id': null,
          'created_at': 100,
          'updated_at': 100,
          'deleted_at': null,
        },
      ],
      'entries': [
        {
          'id': 20,
          'transaction_id': 10,
          'account_id': 1,
          'amount_minor': -5000,
          'currency': 'MNT',
          'rate': null,
          'cleared': 0,
          'reconciliation_id': null,
          'import_key': null,
        },
        {
          'id': 21,
          'transaction_id': 10,
          'account_id': 3,
          'amount_minor': 5000,
          'currency': 'MNT',
          'rate': null,
          'cleared': 0,
          'reconciliation_id': null,
          'import_key': null,
        },
      ],
      'reconciliations': <Row>[],
      'budget_amounts': <Row>[],
      'category_plans': <Row>[],
      'category_accounts_off': <Row>[],
      'preferences': <Row>[],
    };
    // The other cleared the row.
    final cleared = {...base['entries']![0], 'cleared': 1};
    var folded = foldChanges(base, [
      FoldChange(
        tbl: 'entries',
        pk: {'id': 20},
        op: 'update',
        before: base['entries']![0],
        after: cleared,
      ),
    ]);
    var found = combine(base: folded.base, mine: base, theirs: folded.theirs);
    expect(found.conflict, isNull);
    expect(found.ops.single.row!['cleared'], 1);
    // This computer changed the amount meanwhile, the other too: asked.
    final mine = {
      ...base,
      'entries': [
        {...base['entries']![0], 'amount_minor': -6000},
        {...base['entries']![1], 'amount_minor': 6000},
      ],
    };
    folded = foldChanges(mine, [
      FoldChange(
        tbl: 'entries',
        pk: {'id': 20},
        op: 'update',
        before: base['entries']![0],
        after: {...base['entries']![0], 'amount_minor': -7000},
      ),
      FoldChange(
        tbl: 'entries',
        pk: {'id': 21},
        op: 'update',
        before: base['entries']![1],
        after: {...base['entries']![1], 'amount_minor': 7000},
      ),
    ]);
    found = combine(base: folded.base, mine: mine, theirs: folded.theirs);
    expect(found.asking, isTrue);
    expect(found.asks.single.id, 'transaction|10');
    // Answered "mine": the answer is written down as the change from the
    // other's version to this one's, so the other takes it.
    found = combine(
      base: folded.base,
      mine: mine,
      theirs: folded.theirs,
      picks: {'transaction|10': Pick.mine},
    );
    expect(found.asking, isFalse);
    final r = found.resolutions.where((r) => r.key['id'] == 20).single;
    expect(r.before!['amount_minor'], -7000);
    expect(r.after!['amount_minor'], -6000);
  });
}
