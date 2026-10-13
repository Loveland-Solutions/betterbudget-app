// Two computers changed the ledger apart (ADR 0005, "Combine"): what the
// other one changed is worked out by comparing three ledgers, row by row:
// the one both last agreed on, this computer's, and the folder's. A row
// only the other changed comes in; a row both changed in ways that can't
// both stand is a conflict, and then nothing at all is combined: the person
// is asked instead.
//
// Rows are compared by their ids, which are the same on every computer
// ([newRowId]). The few things each computer makes for itself (Income, a
// payee's name, the next payday, a bank row, a phone's entry) are found by
// what they are and counted once.
//
// Pure: rows are plain maps as SQLite gives them, by table.
import 'dart:convert';
import 'dart:math';

import 'forecast.dart' show ForecastSpan;
import 'ledger.dart' show alreadyInDays;
import 'phone.dart'
    show
        PhoneTaken,
        computerMachinePrefix,
        computerNamePrefix,
        phoneNamePrefix,
        phoneTakenKey,
        showSourceKey;
import 'sync.dart' show SyncKeys, isSharedRowId;

typedef Row = Map<String, Object?>;

/// Every row of a ledger, by table.
typedef LedgerRows = Map<String, List<Row>>;

/// One change to make to this computer's ledger.
class RowOp {
  const RowOp.insert(this.table, Row this.row) : key = const {}, insert = true;
  const RowOp.update(this.table, this.key, Row this.row) : insert = false;
  const RowOp.delete(this.table, this.key) : row = null, insert = false;

  final String table;

  /// The columns that say which row, for an update or a delete.
  final Row key;

  /// The whole row as it is to be; null deletes it.
  final Row? row;
  final bool insert;

  @override
  String toString() => row == null
      ? 'delete $table $key'
      : '${insert ? 'insert' : 'update'} $table $row';
}

/// What the person chose for one thing both computers changed.
enum Pick {
  /// This computer's way: left as it is here.
  mine,

  /// The other computer's way.
  theirs,

  /// Neither: as it was before either changed it.
  neither,
}

enum AskKind { transaction, assigned }

/// One line of a transaction, as the person reads it.
class AskLine {
  const AskLine({
    required this.account,
    required this.amountMinor,
    required this.currency,
    required this.isCategory,
  });
  final String account;
  final int amountMinor;
  final String currency;

  /// A category rather than a bank, cash or credit account.
  final bool isCategory;
}

/// What one version of a thing says.
class AskSide {
  const AskSide({
    this.deleted = false,
    this.date,
    this.payee,
    this.memo,
    this.lines = const [],
    this.assignedMinor,
  });

  /// A transaction taken away in this version.
  final bool deleted;
  final String? date;
  final String? payee;
  final String? memo;
  final List<AskLine> lines;

  /// For [AskKind.assigned]: what the category is assigned for the period.
  final int? assignedMinor;
}

/// One thing both computers changed in ways that can't both stand: the
/// person chooses [Pick] for it. Everything else in the two comes in
/// without a question.
class Ask {
  const Ask({
    required this.id,
    required this.kind,
    required this.mine,
    required this.theirs,
    required this.neither,
    this.hasBase = true,
    this.transaction,
    this.category,
    this.date,
    this.currency,
  });

  /// There was a version before either computer changed it. Not so for a
  /// row both made under one id ([sharedRowId]): "neither" would then be
  /// no row at all, and isn't offered.
  final bool hasBase;

  /// Stable for the same two ledgers; what a [Pick] is given under.
  final String id;
  final AskKind kind;
  final AskSide mine;
  final AskSide theirs;
  final AskSide neither;

  /// The transaction, for [AskKind.transaction].
  final int? transaction;

  /// For [AskKind.assigned]: the category's name, the period's first day
  /// and the currency.
  final String? category;
  final String? date;
  final String? currency;
}

/// What one computer chose for a thing both changed, as a change the other
/// computers apply (ADR 0005, step 3): the row as the other computer had it
/// and as it is now, by table and key. A row the other had and this choice
/// took away has a null [after]; one it lacked, a null [before]. Logged on
/// the choosing computer as its own changes, so the others take the answer
/// instead of asking the same question.
class Resolution {
  const Resolution(this.table, this.key, this.before, this.after);
  final String table;
  final Row key;
  final Row? before;
  final Row? after;
}

/// What [combine] found.
class Combined {
  const Combined(
    this.ops, {
    this.transactions = 0,
    this.others = 0,
    this.alike = const [],
    this.asks = const [],
    this.resolutions = const [],
  }) : conflict = null,
       asking = false;
  const Combined.conflict(String this.conflict)
    : ops = const [],
      transactions = 0,
      others = 0,
      alike = const [],
      asks = const [],
      resolutions = const [],
      asking = false;

  /// Things both computers changed that need an answer, with nothing
  /// brought in until each has one ([ops] is empty then).
  const Combined.asking(this.asks)
    : ops = const [],
      transactions = 0,
      others = 0,
      alike = const [],
      resolutions = const [],
      conflict = null,
      asking = true;

  /// The things the person has to choose for. When [combine] was given a
  /// [Pick] for each, the ones that were chosen.
  final List<Ask> asks;

  /// Some of [asks] have no [Pick] yet: nothing is to be brought in until
  /// each has one.
  final bool asking;

  /// What the picks settled, as changes for the other computers.
  final List<Resolution> resolutions;

  /// What to change here so this ledger also holds what the other changed.
  /// Empty: it holds all of it already.
  final List<RowOp> ops;

  /// How many transactions [ops] add, and how many other things they
  /// change (a transaction changed or taken away, an account, a category's
  /// plan, an amount assigned).
  final int transactions;
  final int others;

  /// The transactions among those that came which look the same as one
  /// made here since the two last agreed (the same account and amount,
  /// within [alreadyInDays] days): a purchase one typed and the other
  /// imported. Both are in; the person is told, and shown. Each with the
  /// account it is alike in.
  final List<({int transaction, int account})> alike;

  /// Why the two can't be combined without asking; for the log, not the
  /// screen. Null when they can.
  final String? conflict;
}

class _Conflict implements Exception {
  _Conflict(this.why);
  final String why;
}

/// The columns that say which row, by table. A table that isn't here can't
/// be combined: one added to the schema has to be added.
const combineKeys = <String, List<String>>{
  'accounts': ['id'],
  'pay_schedules': ['id'],
  'payees': ['id'],
  'transactions': ['id'],
  'entries': ['id'],
  'reconciliations': ['id'],
  'category_plans': ['category_id'],
  'category_accounts_off': ['category_id', 'account_id'],
  'preferences': ['key'],
  // By category and day, as a sum ([_budgetAmounts]).
  'budget_amounts': ['id'],
  'payee_rules': ['id'],
  'payee_rule_accounts': ['rule_id', 'account_id'],
};

/// Tables where each side may change a different column of one row: the
/// name of an account on one computer, archived on the other. Elsewhere a
/// row is one thing (a pay's days make no sense taken from two answers).
const _byColumn = {
  'accounts',
  'payees',
  'transactions',
  'entries',
  'payee_rules',
};

/// Parents before children: the order rows are put in. Taken away in the
/// reverse.
const combineOrder = [
  'accounts',
  'pay_schedules',
  'payees',
  'transactions',
  'reconciliations',
  'entries',
  'preferences',
  'budget_amounts',
  'category_plans',
  'category_accounts_off',
  'payee_rules',
  'payee_rule_accounts',
];

/// Every column that names a row of another table.
const _references = <(String, String, String)>[
  ('pay_schedules', 'category_id', 'accounts'),
  ('pay_schedules', 'account_id', 'accounts'),
  ('transactions', 'payee_id', 'payees'),
  ('transactions', 'pay_schedule_id', 'pay_schedules'),
  ('transactions', 'plan_category_id', 'accounts'),
  ('entries', 'transaction_id', 'transactions'),
  ('entries', 'account_id', 'accounts'),
  ('entries', 'reconciliation_id', 'reconciliations'),
  ('reconciliations', 'account_id', 'accounts'),
  ('budget_amounts', 'category_id', 'accounts'),
  ('category_plans', 'category_id', 'accounts'),
  ('category_plans', 'pay_schedule_id', 'pay_schedules'),
  ('category_plans', 'paid_from_id', 'accounts'),
  ('category_accounts_off', 'category_id', 'accounts'),
  ('category_accounts_off', 'account_id', 'accounts'),
  ('payee_rules', 'category_id', 'accounts'),
  ('payee_rules', 'pay_schedule_id', 'pay_schedules'),
  ('payee_rule_accounts', 'rule_id', 'payee_rules'),
  ('payee_rule_accounts', 'account_id', 'accounts'),
];

/// Settings that only change what a page shows: when both changed one,
/// this computer keeps its own and nobody is asked.
const _viewOnly = {ForecastSpan.prefKey, showSourceKey};

/// Settings whose key ends in a row's id.
const _keyedById = [
  'budget.from.',
  'budget.loan.',
  'import.mapping.',
  'import.rules.',
];

/// Settings whose whole value is a row's id.
bool _valueIsId(String key) =>
    key == 'ready.fundCategories' || key.startsWith('budget.loan.');

bool _same(Row? a, Row? b) {
  if (a == null || b == null) return a == null && b == null;
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (!b.containsKey(e.key) || b[e.key] != e.value) return false;
  }
  return true;
}

String _keyOf(String table, Row row) =>
    [for (final c in combineKeys[table]!) '${row[c]}'].join('|');

Map<String, Row> _index(String table, List<Row>? rows) => {
  for (final r in rows ?? const <Row>[]) _keyOf(table, r): r,
};

/// The most things asked about at once; more than that is a ledger the
/// person had better choose whole.
const _mostAsks = 25;

/// What to change in [mine] so that it also holds everything [theirs]
/// changed since [base], or why that can't be done without asking. [base]
/// is the ledger both computers last agreed on; nothing given is changed.
///
/// A thing both changed in ways that can't both stand (one transaction's
/// amount, what one category is assigned for one period, a transaction
/// deleted on one and changed on the other) is left as it is here and
/// comes back in [Combined.asks]. With a [Pick] for each in [picks] it is
/// settled as chosen; with none for some, nothing is brought in yet
/// ([Combined.asking]). Anything else that can't stand is a conflict, and
/// the person chooses a whole ledger.
/// The v21 columns, no part of what a transaction holds.
const _madeBy = {'made_how', 'made_on'};

/// [of] with the v21 columns on every transaction, empty where it had none.
LedgerRows _withMadeBy(LedgerRows of) {
  final rows = of['transactions'];
  if (rows == null ||
      rows.every(
        (r) => r.containsKey('made_how') && r.containsKey('made_on'),
      )) {
    return of;
  }
  return {
    ...of,
    'transactions': [
      for (final r in rows) {'made_how': null, 'made_on': null, ...r},
    ],
  };
}

Combined combine({
  required LedgerRows base,
  required LedgerRows mine,
  required LedgerRows theirs,
  Map<String, Pick> picks = const {},
  Set<Object?>? madeHere,
}) {
  // A row from a computer before v21 has no `made_how` or `made_on`: it is
  // the same row with them empty.
  base = _withMadeBy(base);
  mine = _withMadeBy(mine);
  theirs = _withMadeBy(theirs);
  // What was already chosen is left out of the comparison from the start:
  // this computer's ledger holds the choice, and the other's version of it
  // mustn't come in again over it.
  final units = <String, _Unit>{
    for (final id in picks.keys) id: _Unit.parse(id),
  };
  while (true) {
    try {
      final run = _Combine(base, mine, theirs, units, picks, madeHere);
      final found = run.run();
      if (units.isEmpty) return found;
      final asks = run.asks();
      if (units.keys.any((id) => !picks.containsKey(id))) {
        return Combined.asking(asks);
      }
      return Combined(
        found.ops,
        transactions: found.transactions,
        others: found.others,
        alike: found.alike,
        asks: asks,
        resolutions: run.resolutions,
      );
    } on _Ask catch (a) {
      // Asked about twice: left out of the comparison and still in the way.
      if (units.containsKey(a.unit.id) || units.length >= _mostAsks) {
        return Combined.conflict(a.why);
      }
      units[a.unit.id] = a.unit;
    } on _Conflict catch (c) {
      return Combined.conflict(c.why);
    }
  }
}

/// A thing that is chosen for as a whole: a transaction with its entries,
/// or what one category is assigned for one period.
class _Unit {
  _Unit.transaction(this.transaction) : category = null, date = null;
  _Unit.assigned(this.category, this.date) : transaction = null;
  final Object? transaction;
  final Object? category;
  final String? date;

  /// Made again from its [id].
  factory _Unit.parse(String id) {
    final p = id.split('|');
    if (p.first == 'transaction') return _Unit.transaction(int.parse(p[1]));
    return _Unit.assigned(int.parse(p[1]), p[2]);
  }

  String get id => transaction != null
      ? 'transaction|$transaction'
      : 'assigned|$category|$date';
}

class _Ask implements Exception {
  _Ask(this.unit, this.why);
  final _Unit unit;
  final String why;
}

class _Combine {
  _Combine(
    LedgerRows base,
    this.mine,
    LedgerRows theirs,
    this.units,
    this.picks,
    this.madeHere,
  ) : base = {
        for (final e in base.entries) e.key: [...e.value],
      },
      theirs = {
        for (final e in theirs.entries)
          e.key: [
            for (final r in e.value) {...r},
          ],
      };

  /// The transactions this computer made that the other hasn't seen, by
  /// id, when the caller knows (from this computer's own log, on change
  /// files); else what is in [mine] and not in the other's. What a row that
  /// came may look the same as ([Combined.alike]).
  final Set<Object?>? madeHere;

  /// What was already asked about: left out of the comparison (it reads as
  /// unchanged on the other computer) until it is settled.
  final Map<String, _Unit> units;
  final Map<String, Pick> picks;

  /// The rows of those, as the other computer and the agreed ledger had
  /// them, by table. What the other computer renamed is renamed in them.
  final _heldTheirs = <String, List<Row>>{};
  final _heldBase = <String, List<Row>>{};

  final LedgerRows base;
  final LedgerRows mine;

  /// A copy: what each computer made for itself is renamed in it to this
  /// computer's before the two are compared.
  LedgerRows theirs;

  /// [theirs] before what was asked about was made to read as unchanged:
  /// the checks of what must still hold are made against it.
  LedgerRows? _theirsFull;

  final ops = <RowOp>[];

  /// This computer's ledger with [ops] made, by table and key.
  late final Map<String, Map<String, Row>> result = {
    for (final t in combineKeys.keys) t: {..._index(t, mine[t])},
  };

  Never _stop(String why) => throw _Conflict(why);

  Set<Object?> _ids(LedgerRows of, String table) => {
    for (final r in of[table] ?? const <Row>[]) r['id'],
  };

  Combined run() {
    for (final rows in [base, mine, theirs]) {
      for (final t in rows.keys) {
        if (!combineKeys.containsKey(t)) {
          _stop('a table this build doesn’t know: $t');
        }
      }
    }
    _oneOfEach();
    _checkDescends();
    _freeze();
    for (final t in combineOrder) {
      if (t == 'budget_amounts') {
        _budgetAmounts();
      } else if (t == 'preferences') {
        _preferences();
      } else {
        _table(t);
      }
    }
    _resolve();
    _moveToReplacements();
    _checkTransactions();
    // Against what the other computer really has: a version chosen from it
    // mustn't put a row in a deleted account or inside a statement.
    final frozen = theirs;
    theirs = _theirsFull ?? theirs;
    try {
      _checkDeletedAccounts();
      _checkReconciliations();
    } finally {
      theirs = frozen;
    }
    _checkReferences();
    return Combined(
      ops,
      transactions: _arrived.length,
      others: _others + _touched.difference(_arrived).length,
      alike: _alike(),
    );
  }

  List<({int transaction, int account})> _alike() {
    bool counts(Row t) => t['scheduled'] != 1 && t['deleted_at'] == null;
    final real = {
      for (final a in result['accounts']!.values)
        if (a['type'] == 'asset' || a['type'] == 'liability') a['id'],
    };
    DateTime? day(Row t) => DateTime.tryParse('${t['date']}');
    // What was made here since, by account and amount, each matched once.
    final here = <String, List<DateTime>>{};
    final since = madeHere;
    final fresh = since == null
        ? _onlyIn(mine, theirs)
        : (mine['transactions'] ?? const <Row>[]).where(
            (t) => since.contains(t['id']),
          );
    for (final t in fresh.where(counts)) {
      final on = day(t);
      if (on == null) continue;
      for (final e in _entriesOf(mine, t['id'])) {
        if (real.contains(e['account_id'])) {
          (here['${e['account_id']}|${e['amount_minor']}'] ??= []).add(on);
        }
      }
    }
    final out = <({int transaction, int account})>[];
    final entries = _byTransaction(result['entries']!.values);
    for (final id in _arrived) {
      final t = result['transactions']!['$id'];
      final on = t == null || !counts(t) ? null : day(t);
      if (on == null) continue;
      for (final e in entries[id] ?? const <Row>[]) {
        final days = here['${e['account_id']}|${e['amount_minor']}'];
        final same = days
            ?.where((d) => d.difference(on).inDays.abs() <= alreadyInDays)
            .firstOrNull;
        if (same == null) continue;
        days!.remove(same);
        out.add((transaction: id as int, account: e['account_id'] as int));
        break;
      }
    }
    return out;
  }

  // ---------- what the person is asked about ----------

  bool _inUnit(_Unit u, String table, Row r) {
    if (u.transaction != null) {
      return table == 'transactions'
          ? r['id'] == u.transaction
          : table == 'entries' && r['transaction_id'] == u.transaction;
    }
    return table == 'budget_amounts' &&
        r['category_id'] == u.category &&
        r['date'] == u.date;
  }

  static const _unitTables = {
    'transactions': ['transactions', 'entries'],
    'assigned': ['budget_amounts'],
  };

  List<String> _tablesOf(_Unit u) =>
      _unitTables[u.transaction != null ? 'transactions' : 'assigned']!;

  /// Each thing already asked about is made to read as unchanged on the
  /// other computer, so the rest of the two can be compared without it.
  /// What the other computer and the agreed ledger said of it is kept
  /// aside for the answer.
  void _freeze() {
    if (units.isEmpty) return;
    _theirsFull = {
      for (final e in theirs.entries) e.key: [...e.value],
    };
    for (final u in units.values) {
      for (final table in _tablesOf(u)) {
        final here = [
          for (final r in mine[table] ?? const <Row>[])
            if (_inUnit(u, table, r)) r,
        ];
        void swap(LedgerRows side, Map<String, List<Row>> held) {
          final rows = side[table] ??= [];
          for (final r in rows) {
            if (_inUnit(u, table, r)) (held[table] ??= []).add({...r});
          }
          rows.removeWhere((r) => _inUnit(u, table, r));
          rows.addAll([
            for (final r in here) {...r},
          ]);
        }

        swap(theirs, _heldTheirs);
        swap(base, _heldBase);
      }
    }
  }

  /// A thing both changed, to be chosen for as a whole: unless it holds a
  /// reconciled row, whose lock stays whatever is chosen.
  Never _ask(_Unit u, String why) {
    if (u.transaction != null) {
      for (final of in [base, mine, theirs]) {
        for (final e in of['entries'] ?? const <Row>[]) {
          if (e['transaction_id'] == u.transaction &&
              e['reconciliation_id'] != null) {
            _stop(why);
          }
        }
      }
    }
    throw _Ask(u, why);
  }

  /// The transaction a row of the transactions or entries tables is of.
  Never _askAbout(String table, Iterable<Row?> rows, String why) {
    for (final r in rows) {
      if (r == null) continue;
      if (table == 'transactions') _ask(_Unit.transaction(r['id']), why);
      if (table == 'entries') {
        _ask(_Unit.transaction(r['transaction_id']), why);
      }
    }
    _stop(why);
  }

  /// Makes [table]'s rows of one thing in the result as [wanted] has them.
  void _setRows(String table, Iterable<Row> current, List<Row> wanted) {
    final by = {for (final r in wanted) _keyOf(table, r): r};
    final has = {for (final r in current) _keyOf(table, r): r};
    for (final e in has.entries) {
      if (!by.containsKey(e.key)) _delete(table, e.value);
    }
    for (final e in by.entries) {
      final was = has[e.key];
      if (was == null) {
        // Under an id that is another thing's here.
        if (result[table]!.containsKey(e.key)) {
          _stop('$table ${e.key} is taken, choosing a version of another');
        }
        _insert(table, {...e.value});
      } else if (!_same(was, e.value)) {
        _update(table, {...e.value});
      }
    }
  }

  /// What the picks settled, for the other computers ([Resolution]).
  final resolutions = <Resolution>[];

  /// Settles what was asked as it was chosen. This computer's way is what
  /// is here already. Each choice is also written down as the change from
  /// the other computer's version to the one chosen, whatever was chosen,
  /// so the other computer takes the answer rather than asking again.
  void _resolve() {
    for (final u in units.values) {
      final pick = picks[u.id];
      if (pick == null) continue;
      if (pick != Pick.mine) {
        final from = pick == Pick.theirs ? _heldTheirs : _heldBase;
        for (final table in _tablesOf(u)) {
          _setRows(
            table,
            [
              for (final r in result[table]!.values)
                if (_inUnit(u, table, r)) r,
            ],
            [for (final r in from[table] ?? const <Row>[]) r],
          );
        }
      }
      for (final table in _tablesOf(u)) {
        final theirRows = {
          for (final r in _heldTheirs[table] ?? const <Row>[])
            if (_inUnit(u, table, r)) _keyOf(table, r): r,
        };
        final finalRows = {
          for (final r in result[table]!.values)
            if (_inUnit(u, table, r)) _keyOf(table, r): r,
        };
        for (final k in {...theirRows.keys, ...finalRows.keys}) {
          final any = theirRows[k] ?? finalRows[k]!;
          resolutions.add(
            Resolution(
              table,
              {for (final c in combineKeys[table]!) c: any[c]},
              theirRows[k],
              finalRows[k],
            ),
          );
        }
      }
    }
  }

  String? _nameIn(String table, Object? id, String column) {
    for (final of in [mine, theirs, base]) {
      for (final r in of[table] ?? const <Row>[]) {
        if (r['id'] == id) return r[column] as String?;
      }
    }
    return null;
  }

  /// What each of the three said of what was asked about, for the screen.
  List<Ask> asks() => [for (final u in units.values) _describe(u)];

  Ask _describe(_Unit u) {
    if (u.transaction != null) {
      AskSide side(Map<String, List<Row>> rows) {
        final t = (rows['transactions'] ?? const <Row>[]).firstOrNull;
        return AskSide(
          deleted: t == null || t['deleted_at'] != null,
          date: t?['date'] as String?,
          payee: t == null ? null : _nameIn('payees', t['payee_id'], 'name'),
          memo: t?['memo'] as String?,
          lines: [
            for (final e in rows['entries'] ?? const <Row>[])
              AskLine(
                account: _nameIn('accounts', e['account_id'], 'name') ?? '',
                amountMinor: e['amount_minor'] as int,
                currency: '${e['currency']}',
                isCategory: const {
                  'income',
                  'expense',
                  'equity',
                }.contains(_nameIn('accounts', e['account_id'], 'type')),
              ),
          ],
        );
      }

      Map<String, List<Row>> of(LedgerRows rows) => {
        for (final table in const ['transactions', 'entries'])
          table: [
            for (final r in rows[table] ?? const <Row>[])
              if (_inUnit(u, table, r)) r,
          ],
      };
      return Ask(
        id: u.id,
        kind: AskKind.transaction,
        transaction: u.transaction as int?,
        mine: side(of(mine)),
        theirs: side(_heldTheirs),
        neither: side(_heldBase),
        hasBase: (_heldBase['transactions'] ?? const <Row>[]).isNotEmpty,
      );
    }
    AskSide side(Map<String, List<Row>> rows) => AskSide(
      assignedMinor: (rows['budget_amounts'] ?? const <Row>[]).fold<int>(
        0,
        (sum, r) => sum + (r['amount_minor'] as int),
      ),
    );
    return Ask(
      id: u.id,
      kind: AskKind.assigned,
      category: _nameIn('accounts', u.category, 'name'),
      currency: _nameIn('accounts', u.category, 'currency'),
      date: u.date,
      mine: side({
        'budget_amounts': [
          for (final r in mine['budget_amounts'] ?? const <Row>[])
            if (_inUnit(u, 'budget_amounts', r)) r,
        ],
      }),
      theirs: side(_heldTheirs),
      neither: side(_heldBase),
    );
  }

  // ---------- the same thing made on both computers ----------

  void _oneOfEach() {
    _samePayees();
    _sameCategories();
    _staleScheduled();
    _sameScheduled();
    _sameBankRows();
    _samePhoneEntries();
  }

  void _rename(String table, String column, Object? from, Object? to) {
    for (final r in [...?theirs[table], ...?_heldTheirs[table]]) {
      if (r[column] == from) r[column] = to;
    }
  }

  /// A payee or category this computer has from the agreed ledger, which
  /// the other computer has since counted as one with its own of the same
  /// name ([_samePayees], when it combined): by table, the id here to the
  /// id that took its place there. What still names the old one here is
  /// moved to the new.
  final _replaced = <String, Map<Object?, Object?>>{
    'payees': {},
    'accounts': {},
  };

  void _moveToReplacements() {
    for (final (table, column, parent) in _references) {
      final moved = _replaced[parent];
      if (moved == null || moved.isEmpty) continue;
      // Where the column says which row it is, the row can't be moved:
      // left, and found below as naming a row that is gone.
      if (combineKeys[table]!.contains(column)) continue;
      for (final r in result[table]!.values.toList()) {
        if (moved.containsKey(r[column])) {
          _update(table, {...r, column: moved[r[column]]});
        }
      }
    }
  }

  /// The folder's ledger has to have come from the agreed one by ordinary
  /// changes, which never take a transaction or an account out of the
  /// tables (a deleted one stays, marked). One that lacks them was replaced
  /// whole on the other computer (a restore, "Erase everything and start
  /// over", "Keep this computer’s ledger"): bringing that in row by row
  /// would delete here whatever it lacks, under a popup that says
  /// transactions came. Asked about instead.
  void _checkDescends() {
    final there = _ids(theirs, 'transactions');
    for (final t in base['transactions'] ?? const <Row>[]) {
      // A waiting payday or bill is taken away when its pay or plan
      // changes, or when the other's took its place.
      if (t['scheduled'] != 1 && !there.contains(t['id'])) {
        _stop('the folder’s ledger lacks transaction ${t['id']}');
      }
    }
    final accounts = _ids(theirs, 'accounts');
    for (final a in base['accounts'] ?? const <Row>[]) {
      if (!accounts.contains(a['id']) &&
          !_replaced['accounts']!.containsKey(a['id'])) {
        _stop('the folder’s ledger lacks account ${a['id']}');
      }
    }
  }

  /// A payee is its name: both typed "Nomin", and it is one payee.
  void _samePayees() {
    final had = _ids(base, 'payees');
    final thereIds = _ids(theirs, 'payees');
    final here = {
      for (final p in mine['payees'] ?? const <Row>[]) p['name']: p['id'],
    };
    final hereIds = here.values.toSet();
    for (final p in [...?theirs['payees']]) {
      final id = p['id'];
      final same = here[p['name']];
      if (same == null || same == id) continue;
      if (had.contains(id) || hereIds.contains(id)) continue;
      // The other computer already made the two one, and kept its own.
      if (had.contains(same) && !thereIds.contains(same)) {
        _replaced['payees']![same] = id;
        continue;
      }
      theirs['payees']!.remove(p);
      _rename('transactions', 'payee_id', id, same);
    }
  }

  /// A category each computer made for itself under one name is one
  /// category: Income and Safety net, which the app makes, and one a phone
  /// made that both took in. A bank account isn't: two of one name may well
  /// be two accounts.
  void _sameCategories() {
    const kinds = {'income', 'expense', 'equity'};
    final had = _ids(base, 'accounts');
    final there = _ids(theirs, 'accounts');
    String name(Row a) => '${a['name']}'.trim().toLowerCase();
    bool own(Row a, Set<Object?> other) =>
        kinds.contains(a['type']) &&
        a['deleted_at'] == null &&
        !had.contains(a['id']) &&
        !other.contains(a['id']);
    final here = [
      for (final a in mine['accounts'] ?? const <Row>[])
        if (own(a, there)) a,
    ];
    final hereIds = _ids(mine, 'accounts');
    // There is one Income and one Safety net, whatever language named them
    // on each computer.
    bool one(Row m, Row a) =>
        m['type'] == a['type'] &&
        (a['type'] == 'income' ||
            (m['currency'] == a['currency'] &&
                (name(m) == name(a) ||
                    (a['role'] == 'emergencyFund' &&
                        m['role'] == 'emergencyFund'))));
    for (final a in [...?theirs['accounts']]) {
      if (!own(a, hereIds)) continue;
      // The other computer already made the two one, and kept its own.
      final gone = (mine['accounts'] ?? const <Row>[])
          .where(
            (m) =>
                had.contains(m['id']) &&
                !there.contains(m['id']) &&
                kinds.contains(m['type']) &&
                one(m, a),
          )
          .firstOrNull;
      if (gone != null) {
        _replaced['accounts']![gone['id']] = a['id'];
        continue;
      }
      final same = here.where((m) => one(m, a)).firstOrNull;
      if (same == null) continue;
      theirs['accounts']!.remove(a);
      _renameAccount(a['id'], same['id']);
    }
  }

  void _renameAccount(Object? from, Object? to) {
    for (final (table, column, parent) in _references) {
      if (parent == 'accounts') _rename(table, column, from, to);
    }
    // A row that named both is now there twice.
    final seen = <String>{};
    theirs['category_accounts_off']?.retainWhere(
      (r) => seen.add(_keyOf('category_accounts_off', r)),
    );
    final was = _index('preferences', base['preferences']);
    final number = RegExp('(?<![0-9])$from(?![0-9])');
    for (final p in theirs['preferences'] ?? const <Row>[]) {
      var key = p['key'] as String;
      var value = p['value'] as String;
      if (key.startsWith(SyncKeys.prefix)) continue;
      for (final prefix in _keyedById) {
        if (key == '$prefix$from') key = '$prefix$to';
      }
      if (_valueIsId(key) && value == '$from') value = '$to';
      if (key == phoneTakenKey) {
        final taken = PhoneTaken.decode(value);
        value = PhoneTaken.encode({
          for (final e in taken.entries)
            e.key: PhoneTaken(
              entries: e.value.entries,
              categories: {
                for (final c in e.value.categories.entries)
                  c.key: c.value == '$from' ? '$to' : c.value,
              },
            ),
        });
      }
      // Any other setting that still names it (a payee rule filing rows
      // under it) can't be told from one that only holds the same digits.
      if (!_same({'key': key, 'value': value}, was[key]) &&
          key != phoneTakenKey &&
          (number.hasMatch(value) ||
              (number.hasMatch(key) &&
                  !_keyedById.any((x) => key == '$x$to')))) {
        _stop('a setting names a category both computers made: $key');
      }
      p['key'] = key;
      p['value'] = value;
    }
  }

  List<Row> _entriesOf(LedgerRows of, Object? transaction) => [
    for (final e in of['entries'] ?? const <Row>[])
      if (e['transaction_id'] == transaction) e,
  ];

  void _dropTheirs(Row transaction) {
    theirs['transactions']!.remove(transaction);
    theirs['entries']?.removeWhere(
      (e) => e['transaction_id'] == transaction['id'],
    );
  }

  /// What a transaction says, leaving out which rows say it and when they
  /// were written.
  String _says(LedgerRows of, Row t) {
    final entries = [
      for (final e in _entriesOf(of, t['id']))
        jsonEncode([
          e['account_id'],
          e['amount_minor'],
          e['currency'],
          e['rate'],
          e['cleared'],
          e['import_key'],
        ]),
    ]..sort();
    return jsonEncode([
      t['date'],
      t['payee_id'],
      t['memo'],
      t['scheduled'],
      t['pay_schedule_id'],
      t['plan_category_id'],
      t['deleted_at'] == null,
      entries,
    ]);
  }

  Iterable<Row> _onlyIn(LedgerRows of, LedgerRows other) {
    final had = _ids(base, 'transactions');
    final others = _ids(other, 'transactions');
    return [
      for (final t in of['transactions'] ?? const <Row>[])
        if (!had.contains(t['id']) && !others.contains(t['id'])) t,
    ];
  }

  static bool _waiting(Row t) => t['scheduled'] == 1 && t['deleted_at'] == null;

  void _mineGoes(Row transaction) {
    for (final e in _entriesOf(mine, transaction['id'])) {
      _delete('entries', e);
    }
    _delete('transactions', transaction);
  }

  /// The next payday, or a plan's next bill, which each computer schedules
  /// for itself when it opens: one, not two. Where one of the two has been
  /// confirmed or skipped since, that is the one kept, whatever day it was
  /// confirmed on.
  void _sameScheduled() {
    bool here(Row t) => result['transactions']!.containsKey('${t['id']}');
    for (final column in ['pay_schedule_id', 'plan_category_id']) {
      final mineOnly = [
        for (final t in _onlyIn(mine, theirs))
          if (t[column] != null && here(t)) t,
      ];
      for (final t in _onlyIn(theirs, mine).toList()) {
        if (t[column] == null) continue;
        final same = mineOnly
            .where(
              (m) =>
                  here(m) && m[column] == t[column] && m['date'] == t['date'],
            )
            .firstOrNull;
        if (same == null) continue;
        if (_says(theirs, t) == _says(mine, same)) {
          _dropTheirs(t);
        } else if (_waiting(same) && !_waiting(t)) {
          _mineGoes(same);
        } else if (_waiting(t) && !_waiting(same)) {
          _dropTheirs(t);
        } else {
          _stop('one payday or bill changed on both: ${t['date']}');
        }
      }
      // One confirmed on another day than it was scheduled for: the one
      // still waiting on the other computer is the same payday.
      bool confirmed(Row t) => t['scheduled'] != 1 && t['deleted_at'] == null;
      final theirsOnly = [
        for (final t in _onlyIn(theirs, mine))
          if (t[column] != null) t,
      ];
      for (final t in theirsOnly.where(confirmed)) {
        for (final m in mineOnly) {
          if (here(m) && _waiting(m) && m[column] == t[column]) _mineGoes(m);
        }
      }
      for (final m in mineOnly.where((m) => here(m) && confirmed(m))) {
        for (final t in theirsOnly) {
          if (_waiting(t) &&
              t[column] == m[column] &&
              theirs['transactions']!.contains(t)) {
            _dropTheirs(t);
          }
        }
      }
    }
  }

  /// A pay or a plan changed on one computer has its waiting payday or
  /// bill made again there. The one the other computer scheduled for
  /// itself from the pay as it was goes, or the salary would be waiting
  /// twice; scheduling makes the right one after.
  void _staleScheduled() {
    for (final (column, table, key) in [
      ('pay_schedule_id', 'pay_schedules', 'id'),
      ('plan_category_id', 'category_plans', 'category_id'),
    ]) {
      Set<Object?> changed(LedgerRows of) {
        final was = _index(table, base[table]);
        final now = _index(table, of[table]);
        return {
          for (final k in {...was.keys, ...now.keys})
            if (!_same(was[k], now[k])) (was[k] ?? now[k])![key],
        };
      }

      bool waiting(Row t) => t[column] != null && _waiting(t);
      final there = changed(theirs), here = changed(mine);
      for (final t in _onlyIn(mine, theirs)) {
        if (!waiting(t) || !there.contains(t[column])) continue;
        _mineGoes(t);
      }
      for (final t in _onlyIn(theirs, mine).toList()) {
        if (waiting(t) && here.contains(t[column])) _dropTheirs(t);
      }
    }
  }

  /// A bank row both imported is one row. Filed differently on each, it
  /// is a row both changed.
  void _sameBankRows() {
    final here = <Object?, Row>{
      for (final e in mine['entries'] ?? const <Row>[])
        if (e['import_key'] != null) e['import_key']: e,
    };
    final mineOnly = {for (final t in _onlyIn(mine, theirs)) t['id']: t};
    final theirsOnly = {for (final t in _onlyIn(theirs, mine)) t['id']: t};
    final dropped = <Object?>{};
    for (final e in [...?theirs['entries']]) {
      final same = here[e['import_key']];
      if (same == null || same['id'] == e['id']) continue;
      // Gone with an earlier entry of the same transaction.
      if (dropped.contains(e['transaction_id'])) continue;
      final t = theirsOnly[e['transaction_id']];
      final m = mineOnly[same['transaction_id']];
      if (t == null || m == null || _says(theirs, t) != _says(mine, m)) {
        _stop('one bank row in both, not the same: ${e['import_key']}');
      }
      _dropTheirs(t);
      dropped.add(t['id']);
    }
  }

  /// A phone's entry both computers took in is one transaction. Nothing on
  /// the row says which entry it came from, so it is found by what it says;
  /// one changed since on either computer can't be found, and is asked
  /// about rather than counted twice.
  void _samePhoneEntries() {
    Map<String, PhoneTaken> taken(LedgerRows of) => PhoneTaken.decode(
      _index('preferences', of['preferences'])[phoneTakenKey]?['value']
          as String?,
    );
    final was = taken(base), here = taken(mine), there = taken(theirs);
    var both = 0;
    for (final device in there.keys) {
      final before = was[device]?.entries ?? const <String>{};
      both += there[device]!.entries
          .difference(before)
          .intersection(here[device]?.entries.difference(before) ?? const {})
          .length;
    }
    if (both == 0) return;
    final mineOnly = _onlyIn(mine, theirs).toList();
    for (final t in _onlyIn(theirs, mine).toList()) {
      if (both == 0) break;
      final says = _says(theirs, t);
      final same = mineOnly.where((m) => _says(mine, m) == says).firstOrNull;
      if (same == null) continue;
      mineOnly.remove(same);
      _dropTheirs(t);
      both--;
    }
    // Still one unfound, and a transaction on each side that could be it.
    // (With none on one side there is nothing to count twice: the two were
    // combined before, and this computer holds the other's already.)
    if (both > 0 && mineOnly.isNotEmpty && _onlyIn(theirs, mine).isNotEmpty) {
      _stop('a phone’s entry taken in on both and changed on one');
    }
  }

  // ---------- row by row ----------

  final _touched = <Object?>{};

  /// The transactions that are new here: what "4 transactions from the
  /// laptop" counts. One changed or deleted is another change.
  final _arrived = <Object?>{};
  var _others = 0;

  void _count(String table, Row row, {bool insert = false}) {
    switch (table) {
      case 'transactions':
        _touched.add(row['id']);
      case 'entries':
        _touched.add(row['transaction_id']);
      case 'payees':
        // A new payee comes with its transaction, and isn't a change by
        // itself to the person; one renamed is.
        if (!insert) _others++;
      case 'preferences':
        if (row['key'] != phoneTakenKey) _others++;
      default:
        _others++;
    }
  }

  void _insert(String table, Row row) {
    if (table == 'transactions') _arrived.add(row['id']);
    ops.add(RowOp.insert(table, row));
    result[table]![_keyOf(table, row)] = row;
    _count(table, row, insert: true);
  }

  void _update(String table, Row row, {bool count = true}) {
    final key = {for (final c in combineKeys[table]!) c: row[c]};
    ops.add(RowOp.update(table, key, row));
    result[table]![_keyOf(table, row)] = row;
    if (count) _count(table, row);
  }

  void _delete(String table, Row row) {
    final key = {for (final c in combineKeys[table]!) c: row[c]};
    ops.add(RowOp.delete(table, key));
    result[table]!.remove(_keyOf(table, row));
    _count(table, row);
  }

  void _table(String table) {
    final b = _index(table, base[table]);
    final m = _index(table, mine[table]);
    final t = _index(table, theirs[table]);
    for (final k in {...b.keys, ...m.keys, ...t.keys}) {
      // Taken away above, for one of theirs that came instead.
      if (m.containsKey(k) && !result[table]!.containsKey(k)) continue;
      final was = b[k], here = m[k], there = t[k];
      // They changed nothing, or the very thing this computer did.
      if (_same(there, was) || _same(here, there)) continue;
      if (_same(here, was)) {
        if (there == null) {
          _delete(table, here!);
        } else if (here == null) {
          _insert(table, there);
        } else {
          _update(table, there);
        }
        continue;
      }
      if (was == null) {
        // One id on both from the same fact ([sharedRowId]): a payday or
        // bill each scheduled, a phone's entry each took in, a bank row
        // each imported, Income. The same but for when each wrote it: one
        // row, its times merged. One side's still the waiting payday and
        // the other's the confirmed paycheck: the waiting one is what the
        // other was made from, so it stands as the base.
        final merged = _sameMade(here!, there!);
        if (merged != null) {
          // Only when each wrote it: not a change to the person.
          if (!_same(merged, here)) _update(table, merged, count: false);
          continue;
        }
        final base = _waitingOf(table, k, here, there);
        if (base != null) {
          if (_same(base, here)) _update(table, there);
          continue;
        }
        // Income or the Safety net, named or ordered differently on each
        // (a label): one of the two, the same one on both computers.
        if (table == 'accounts' && isSharedRowId(here['id'] as int)) {
          if (jsonEncode(_sorted(there)).compareTo(jsonEncode(_sorted(here))) <
              0) {
            _update(table, there, count: false);
          }
          continue;
        }
        _askAbout(table, [here, there], '$table $k made on both, not the same');
      }
      if (here == null || there == null) {
        _askAbout(table, [
          was,
          here,
          there,
        ], '$table $k changed on one and deleted on the other');
      }
      if (!_byColumn.contains(table)) _stop('$table $k changed on both');
      final merged = {...here};
      for (final c in here.keys) {
        if (there[c] == was[c] || there[c] == here[c]) continue;
        if (here[c] == was[c]) {
          merged[c] = there[c];
        } else if ((c == 'deleted_at' || c == 'archived_at') &&
            was[c] == null) {
          // Deleted, or put away, on both: they agree, whatever the time;
          // the earlier time, the same on both computers.
          final a = here[c], o = there[c];
          merged[c] = a is int && o is int && o < a ? o : a;
        } else if (table == 'transactions' && c == 'updated_at') {
          final a = here[c], o = there[c];
          merged[c] = a is int && o is int && o > a ? o : a;
        } else {
          _askAbout(table, [was, here, there], '$table $k: $c changed on both');
        }
      }
      if (!_same(merged, here)) _update(table, merged);
    }
  }

  static const _times = {'created_at', 'updated_at'};

  /// [a] and [b] as one row when they differ only in when each computer
  /// wrote them (and both are deleted or put away, whenever): the earlier
  /// made, the later updated, this computer's marks. Null otherwise.
  Row? _sameMade(Row a, Row b) {
    if (a.length != b.length) return null;
    final out = {...a};
    for (final c in a.keys) {
      if (!b.containsKey(c)) return null;
      final x = a[c], y = b[c];
      if (x == y) continue;
      if (_times.contains(c) && x is int && y is int) {
        out[c] = c == 'created_at' ? min(x, y) : max(x, y);
      } else if ((c == 'deleted_at' || c == 'archived_at') &&
          x is int &&
          y is int) {
        // Agreed, whatever the time: the earlier, the same on both.
        out[c] = min(x, y);
      } else if (_madeBy.contains(c)) {
        // Who made it (v21): each computer says itself. The smaller word
        // wins, a missing one yields, so both computers keep the same.
        out[c] = x == null
            ? y
            : y == null
            ? x
            : '$x'.compareTo('$y') <= 0
            ? x
            : y;
      } else {
        return null;
      }
    }
    return out;
  }

  /// Of two rows under one id made on both, the one that is still the
  /// waiting payday or bill (or its entry) where the other is the confirmed
  /// one: the base the confirmed one was made from. Null when neither, or
  /// both, wait.
  Row? _waitingOf(String table, String k, Row here, Row there) {
    bool waits(LedgerRows of, Row r) {
      final t = table == 'transactions'
          ? r
          : table == 'entries'
          ? _index('transactions', of['transactions'])['${r['transaction_id']}']
          : null;
      return t != null && t['scheduled'] == 1 && t['deleted_at'] == null;
    }

    final hereWaits = waits(mine, here), thereWaits = waits(theirs, there);
    if (hereWaits == thereWaits) return null;
    return hereWaits ? here : there;
  }

  /// What a category was assigned for a period is the sum of its rows for
  /// that day, and a change of it writes new rows: so it is compared by
  /// category and day, never row by row (each computer's new rows would
  /// both stay, and the amount would be assigned twice).
  void _budgetAmounts() {
    Map<String, List<Row>> groups(LedgerRows of) {
      final out = <String, List<Row>>{};
      for (final r in of['budget_amounts'] ?? const <Row>[]) {
        (out['${r['category_id']}|${r['date']}'] ??= []).add(r);
      }
      return out;
    }

    int sum(List<Row>? rows) =>
        (rows ?? const []).fold(0, (s, r) => s + (r['amount_minor'] as int));
    final b = groups(base), m = groups(mine), t = groups(theirs);
    final changed = <String>[];
    for (final k in {...b.keys, ...m.keys, ...t.keys}) {
      final was = sum(b[k]), here = sum(m[k]), there = sum(t[k]);
      if (there == was || there == here) continue;
      if (here != was) {
        final any = [...?t[k], ...?m[k], ...?b[k]].first;
        throw _Ask(
          _Unit.assigned(any['category_id'], any['date'] as String),
          'assigned on both: $k',
        );
      }
      changed.add(k);
    }
    // What goes, from every one of them, before anything comes: a row
    // moved from one category or day to another keeps its id.
    for (final k in changed) {
      final kept = {for (final r in t[k] ?? const <Row>[]) r['id']};
      for (final r in m[k] ?? const <Row>[]) {
        if (!kept.contains(r['id'])) _delete('budget_amounts', r);
      }
    }
    for (final k in changed) {
      final mineIds = {for (final r in m[k] ?? const <Row>[]) r['id']};
      for (final r in t[k] ?? const <Row>[]) {
        // A row of theirs under an id this computer has elsewhere can't
        // come in as it is: asked about, never renumbered silently.
        if (!mineIds.contains(r['id']) &&
            result['budget_amounts']!.containsKey('${r['id']}')) {
          _stop('an assigned amount’s id is taken: ${r['id']}');
        }
      }
      for (final r in t[k] ?? const <Row>[]) {
        if (!mineIds.contains(r['id'])) {
          _insert('budget_amounts', r);
        } else if (!_same(r, result['budget_amounts']!['${r['id']}'])) {
          _update('budget_amounts', r);
        }
      }
    }
  }

  void _preferences() {
    bool kept(Row r) => !(r['key'] as String).startsWith(SyncKeys.prefix);
    Map<String, Row> index(LedgerRows of) => {
      for (final r in of['preferences'] ?? const <Row>[])
        if (kept(r)) r['key'] as String: r,
    };
    final b = index(base), m = index(mine), t = index(theirs);
    for (final k in {...b.keys, ...m.keys, ...t.keys}) {
      final was = b[k], here = m[k], there = t[k];
      if (_same(there, was) || _same(here, there)) continue;
      if (k == phoneTakenKey) {
        // What either has taken in from a phone, both have now.
        final all = PhoneTaken.decode(here?['value'] as String?);
        PhoneTaken.decode(there?['value'] as String?).forEach((device, o) {
          final a = all[device] ?? const PhoneTaken();
          all[device] = PhoneTaken(
            entries: {...a.entries, ...o.entries},
            categories: {...o.categories, ...a.categories},
          );
        });
        final value = PhoneTaken.encode(all);
        if (here == null) {
          _insert('preferences', {'key': k, 'value': value});
        } else if (here['value'] != value) {
          _update('preferences', {'key': k, 'value': value});
        }
        continue;
      }
      if (_same(here, was)) {
        if (there == null) {
          _delete('preferences', here!);
        } else if (here == null) {
          _insert('preferences', there);
        } else {
          _update('preferences', there);
        }
        continue;
      }
      if (_viewOnly.contains(k)) continue;
      // A phone named on both, differently: the same one on both computers.
      if ((k.startsWith(phoneNamePrefix) ||
              k.startsWith(computerNamePrefix) ||
              k.startsWith(computerMachinePrefix)) &&
          here != null &&
          there != null) {
        if ('${there['value']}'.compareTo('${here['value']}') < 0) {
          _update('preferences', there);
        }
        continue;
      }
      _stop('the setting $k changed on both');
    }
  }

  // ---------- what must still hold ----------

  /// A transaction with its entries, as one thing.
  String? _whole(
    Map<String, Row> transactions,
    List<Row> entries,
    Object? id, {
    Set<String> but = const {},
  }) {
    final t = transactions['$id'];
    if (t == null && entries.isEmpty) return null;
    final rows = [for (final e in entries) jsonEncode(_sorted(e))]..sort();
    return jsonEncode([
      if (t != null)
        _sorted({
          for (final c in t.keys)
            // Where a row came from is not what it holds (v21).
            if (!but.contains(c) && !_madeBy.contains(c)) c: t[c],
        }),
      rows,
    ]);
  }

  static List<Object?> _sorted(Row r) => [
    for (final c in r.keys.toList()..sort()) ...[c, r[c]],
  ];

  Map<Object?, List<Row>> _byTransaction(Iterable<Row> entries) {
    final out = <Object?, List<Row>>{};
    for (final e in entries) {
      (out[e['transaction_id']] ??= []).add(e);
    }
    return out;
  }

  void _checkTransactions() {
    final bt = _index('transactions', base['transactions']);
    final mt = _index('transactions', mine['transactions']);
    final tt = _index('transactions', theirs['transactions']);
    final be = _byTransaction(base['entries'] ?? const []);
    final me = _byTransaction(mine['entries'] ?? const []);
    final te = _byTransaction(theirs['entries'] ?? const []);
    final re = _byTransaction(result['entries']!.values);
    final rt = result['transactions']!;
    for (final id in _touched) {
      final entries = re[id] ?? const <Row>[];
      final header = rt['$id'];
      if (header == null) {
        if (entries.isNotEmpty) _stop('transaction $id: entries left behind');
        continue;
      }
      // Every write keeps this (ADR 0003); so must this one.
      final sums = <Object?, int>{};
      for (final e in entries) {
        sums[e['currency']] =
            (sums[e['currency']] ?? 0) + (e['amount_minor'] as int);
      }
      if (entries.length < 2 || sums.values.any((s) => s != 0)) {
        _stop('transaction $id wouldn’t add up');
      }
      // Deleted on one computer and changed on the other: the change would
      // land in a row that is gone, or a paycheck confirmed there would go.
      bool deleted(Map<String, Row> of) => of['$id']?['deleted_at'] != null;
      if (bt.containsKey('$id') && !deleted(bt) && deleted(mt) != deleted(tt)) {
        const but = {'updated_at', 'deleted_at'};
        // What a delete of a waiting payday also clears.
        final (ot, oe) = deleted(mt) ? (tt, te) : (mt, me);
        if (_whole(ot, oe[id] ?? const [], id, but: but) !=
            _whole(bt, be[id] ?? const [], id, but: but)) {
          _ask(
            _Unit.transaction(id),
            'transaction $id deleted on one and changed on the other',
          );
        }
      }
      final was = _whole(bt, be[id] ?? const [], id);
      final here = _whole(mt, me[id] ?? const [], id);
      final there = _whole(tt, te[id] ?? const [], id);
      if (here == was || there == was || here == there) continue;
      // Both changed it. Each computer writes an edit's entries as new
      // rows, so two edits would leave both sets and the amount twice.
      Set<Object?> ids(List<Row>? rows) => {
        for (final e in rows ?? []) e['id'],
      };
      if (!_sameSet(ids(me[id]), ids(te[id]))) {
        _ask(_Unit.transaction(id), 'transaction $id edited on both');
      }
      // A reconciled row keeps what it was reconciled as: its amount, its
      // account, its date. One computer locking it while the other changed
      // one of those is for the person to settle.
      for (final e in entries) {
        if (e['reconciliation_id'] == null) continue;
        final side = [me[id], te[id]]
            .expand((rows) => rows ?? const <Row>[])
            .where(
              (x) =>
                  x['id'] == e['id'] &&
                  x['reconciliation_id'] == e['reconciliation_id'],
            )
            .firstOrNull;
        final sideHeader = (me[id] ?? const <Row>[]).contains(side)
            ? mt['$id']
            : tt['$id'];
        if (side == null ||
            sideHeader == null ||
            side['amount_minor'] != e['amount_minor'] ||
            side['account_id'] != e['account_id'] ||
            side['currency'] != e['currency'] ||
            sideHeader['date'] != header['date'] ||
            sideHeader['deleted_at'] != header['deleted_at']) {
          _stop('transaction $id reconciled on one and changed on the other');
        }
      }
    }
  }

  static bool _sameSet(Set<Object?> a, Set<Object?> b) =>
      a.length == b.length && a.containsAll(b);

  /// An account or category deleted on one computer while the other put a
  /// row in it: the row would be in something that is gone.
  void _checkDeletedAccounts() {
    final was = _index('accounts', base['accounts']);
    final here = _index('accounts', mine['accounts']);
    final there = _index('accounts', theirs['accounts']);
    bool gone(Row? a) => a == null || a['deleted_at'] != null;
    Set<Object?> used(LedgerRows of) {
      final old = {
        for (final e in base['entries'] ?? const <Row>[])
          e['id']: e['account_id'],
      };
      return {
        for (final e in of['entries'] ?? const <Row>[])
          if (old[e['id']] != e['account_id']) e['account_id'],
      };
    }

    final usedHere = used(mine), usedThere = used(theirs);
    for (final k in was.keys) {
      if (gone(was[k])) continue;
      final id = was[k]!['id'];
      if (gone(there[k]) && !gone(here[k]) && usedHere.contains(id) ||
          gone(here[k]) && !gone(there[k]) && usedThere.contains(id)) {
        _stop('account $k deleted on one and used on the other');
      }
    }
  }

  /// Each computer reconciling one account apart leaves two statements
  /// whose locked rows don't add up to either.
  void _checkReconciliations() {
    final had = _ids(base, 'reconciliations');
    Set<Object?> made(LedgerRows of) => {
      for (final r in of['reconciliations'] ?? const <Row>[])
        if (!had.contains(r['id'])) r['account_id'],
    };
    Set<Object?> undone(LedgerRows of) {
      final has = _ids(of, 'reconciliations');
      return {
        for (final r in base['reconciliations'] ?? const <Row>[])
          if (!has.contains(r['id'])) r['account_id'],
      };
    }

    final here = {...made(mine), ...undone(mine)};
    final there = {...made(theirs), ...undone(theirs)};
    if (here.intersection(there).isNotEmpty) {
      _stop('one account reconciled on both');
    }
    // A statement reconciled on one computer, and on the other a cleared
    // row in that account dated within it, new or changed: the statement
    // would still read as matching, and the next one would be off by that
    // row with nothing to show why.
    final old = _index('entries', base['entries']);
    for (final (side, other) in [(mine, theirs), (theirs, mine)]) {
      final dates = {
        for (final t in other['transactions'] ?? const <Row>[])
          if (t['deleted_at'] == null && t['scheduled'] != 1)
            t['id']: t['date'] as String,
      };
      for (final r in side['reconciliations'] ?? const <Row>[]) {
        if (had.contains(r['id'])) continue;
        final until = r['statement_date'];
        if (until is! String) continue;
        for (final e in other['entries'] ?? const <Row>[]) {
          final date = dates[e['transaction_id']];
          if (e['account_id'] != r['account_id'] ||
              e['cleared'] == 0 ||
              date == null ||
              date.compareTo(until) > 0) {
            continue;
          }
          final was = old['${e['id']}'];
          if (was == null ||
              was['cleared'] == 0 ||
              was['amount_minor'] != e['amount_minor'] ||
              was['account_id'] != e['account_id']) {
            _stop('a cleared row inside a statement reconciled on the other');
          }
        }
      }
    }
  }

  void _checkReferences() {
    for (final (table, column, parent) in _references) {
      final parents = result[parent]!;
      for (final r in result[table]!.values) {
        final to = r[column];
        if (to != null && !parents.containsKey('$to')) {
          _stop('$table.$column names a $parent row that is gone: $to');
        }
      }
    }
  }
}
