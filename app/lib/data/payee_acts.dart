// What saving, deleting and filing a payee write, once for the computer's
// Payees page and the phone's (#532). Each hands back its own undo and redo;
// what to say, and what the screen holds open, is the screen's.

import '../domain/budget.dart' show isUncategorized;
import '../domain/ledger.dart';
import '../domain/payee_offers.dart';
import '../domain/payee_rules.dart';
import 'database.dart';

/// Of the payees already there, which Save of [after] meets: [twins] are
/// this payee's own copies (the same payee remembered on two computers),
/// taken into it; [clash] is another's, which holds the same words on one
/// of its accounts, so Save can't go ahead.
({List<PayeeRuleInfo> twins, PayeeRuleInfo? clash}) payeeOverlaps(
  LedgerData data,
  PayeeRuleInfo? before,
  PayeeRuleInfo after,
) {
  bool overlaps(PayeeRuleInfo x) =>
      x.id != before?.id && after.sharedWith(x) != null;
  final twins = [
    for (final x in data.payeeRules)
      if (overlaps(x) && before != null && x.sameSpellings(before)) x,
  ];
  final clash = data.payeeRules
      .where((x) => overlaps(x) && !twins.contains(x))
      .firstOrNull;
  return (twins: twins, clash: clash);
}

/// A payee saved: [saved] as it is now, with the way back and forward.
typedef PayeeSaved = ({
  PayeeRuleInfo saved,
  Future<void> Function() undo,
  Future<void> Function() redo,
});

/// Writes a new payee ([before] null) or a changed one, and deletes its
/// [twins] with it, as one change.
Future<PayeeSaved> writePayee(
  AppDatabase db,
  PayeeRuleInfo? before,
  PayeeRuleInfo after,
  List<PayeeRuleInfo> twins,
) async {
  final PayeeRuleInfo saved;
  if (before == null) {
    saved = await db.addPayeeRule(
      spellings: after.spellings,
      shownAs: after.shownAs,
      categoryId: after.categoryId,
      payId: after.payId,
      accountIds: after.accountIds,
    );
  } else {
    saved = after;
    await db.transaction(() async {
      await db.putPayeeRule(after);
      for (final x in twins) {
        await db.putPayeeRule(x.copyWith(deleted: true));
      }
    });
  }
  return (
    saved: saved,
    undo: () => before == null
        ? db.removePayeeRule(saved.id)
        : db.transaction(() async {
            await db.putPayeeRule(before);
            for (final x in twins) {
              await db.putPayeeRule(x);
            }
          }),
    redo: () => db.transaction(() async {
      await db.putPayeeRule(saved);
      for (final x in twins) {
        await db.putPayeeRule(x.copyWith(deleted: true));
      }
    }),
  );
}

/// The rows of a payee that are still in Not categorized, filed under its
/// category (as its pay's paychecks, for a pay; as transfers, for money
/// moved to another account). [write] does it, again for a redo; [undo]
/// takes it back. The payee itself is left as it is.
class WaitingFiling {
  WaitingFiling(this.db, this.data, this.rule, this.waiting, this.today);
  final AppDatabase db;
  /// The ledger when the offer was made; [write] reads it again, so a redo
  /// meets a pay or category changed since.
  LedgerData data;
  final PayeeRuleInfo rule;
  final List<RegisterRow> waiting;
  final DateTime today;

  var _previous = <int, Map<int, int>>{};
  var _paychecks = <PayTaken>[];
  var _moved = <int, FiledTransfers>{};

  int? get _holding => data.categories.where(isUncategorized).firstOrNull?.id;

  Future<void> write() async {
    data = await db.loadLedger();
    final byAccount = <int, List<int>>{};
    // Oldest first, so each paycheck takes its own payday's place.
    for (final r in waiting.reversed) {
      (byAccount[r.accountId] ??= []).add(r.txnId);
    }
    _previous = {};
    _paychecks = [];
    _moved = {};
    final movedTo = payeeMovedTo(data, rule);
    final pay = data.payScheduleById(rule.payId);
    for (final e in byAccount.entries) {
      if (movedTo != null) {
        // Money moved: joined with the other account's own bank row where it
        // has one waiting, so it isn't there twice.
        _moved[e.key] = await db.fileAsTransfers(
          transactionIds: e.value,
          accountId: e.key,
          toAccountId: movedTo.id,
          holdingId: _holding!,
        );
      } else if (pay != null && pay.accountId == e.key) {
        for (final id in e.value) {
          _paychecks.add(
            await db.takeAsPay(
              transactionId: id,
              accountId: e.key,
              scheduleId: pay.id,
              today: today,
            ),
          );
        }
      } else {
        _previous[e.key] = await db.setCategoryMany(
          transactionIds: e.value,
          accountId: e.key,
          categoryId: rule.categoryId,
          // A row filed by hand while the offer was up stays.
          onlyFrom: _holding,
        );
      }
    }
  }

  Future<void> undo() async {
    for (final p in _paychecks.reversed) {
      await db.undoTakeAsPay(p);
    }
    for (final e in _previous.entries) {
      await db.restoreCategories(e.value, e.key);
    }
    for (final e in _moved.entries) {
      await db.unfileTransfers(e.value, e.key);
    }
  }
}
