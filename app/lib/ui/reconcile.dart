import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/ledger.dart';
import '../domain/money.dart';
import 'entry_row.dart';
import 'register.dart' show BarButton;
import 'theme.dart';

/// One reconcile in progress: the statement's date and balance as typed.
class ReconcileSession {
  ReconcileSession({
    required this.accountId,
    required this.owed,
    required DateTime today,
    required int clearedToday,
  }) : date = TextEditingController(text: fullDate(today)),
       balance = TextEditingController(
         text: _editable(owed ? -clearedToday : clearedToday),
       );

  final int accountId;

  /// A credit account: the bank shows what you owe as a positive number.
  final bool owed;
  final TextEditingController date;
  final TextEditingController balance;
  final dateFocus = FocusNode(debugLabel: 'reconcile-date');
  final balanceFocus = FocusNode(debugLabel: 'reconcile-balance');

  /// The statement balance in the account's own sign, or null if unreadable.
  int? get statementBalance {
    final v = parseAmount(balance.text);
    return v == null ? null : (owed ? -v : v);
  }

  void dispose() {
    date.dispose();
    balance.dispose();
    dateFocus.dispose();
    balanceFocus.dispose();
  }

  static String _editable(int minor) {
    final cents = minor.abs() % 100;
    return '${minor < 0 ? '-' : ''}${minor.abs() ~/ 100}'
        '${cents == 0 ? '' : '.${cents.toString().padLeft(2, '0')}'}';
  }
}

/// Where a reconcile stands for the typed date and balance.
typedef ReconcileCheck = ({
  DateTime? date,
  String? dateProblem,
  int? statement,
  int cleared,
  int toLock,
});

/// Replaces the balance sum in the header while reconciling: the statement
/// on one side, what's cleared here on the other, and how far apart they are.
/// Locking is only possible once they match.
class ReconcilePanel extends StatelessWidget {
  const ReconcilePanel({
    super.key,
    required this.session,
    required this.today,
    required this.check,
    required this.onLock,
    required this.onCancel,
  });

  final ReconcileSession session;
  final DateTime today;
  final ReconcileCheck Function() check;
  final VoidCallback onLock;
  final VoidCallback onCancel;

  static const _label = 128.0, _amount = 200.0;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onCancel},
      child: ListenableBuilder(
        listenable: Listenable.merge([s.date, s.balance]),
        builder: (context, _) {
          final c = check();
          final off = c.statement == null || c.date == null
              ? null
              : c.statement! - c.cleared;
          final ready = off == 0 && c.dateProblem == null;
          // Shown the way the bank shows it.
          int bank(int v) => s.owed ? -v : v;

          Widget line(String label, Widget value, {Widget? note}) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: _label,
                  child: Text(label, style: onest(13, color: Mid.ink3)),
                ),
                SizedBox(
                  width: _amount,
                  child: Align(alignment: Alignment.centerRight, child: value),
                ),
                if (note != null) ...[
                  const SizedBox(width: 20),
                  Flexible(child: note),
                ],
              ],
            ),
          );

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _label + _amount,
                child: Row(
                  children: [
                    const StatusGlyph(Cleared.reconciled),
                    const SizedBox(width: 8),
                    Text('Reconcile', style: onest(14, weight: 600)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              line(
                'Statement date',
                // Fixed heights: the header sizes itself from its contents'
                // intrinsic heights, which text fields under-report.
                SizedBox(
                  width: 130,
                  height: 30,
                  child: DateField(
                    key: const ValueKey('reconcile-date'),
                    controller: s.date,
                    focusNode: s.dateFocus,
                    today: today,
                    allowFuture: false,
                    small: true,
                    wanted: c.dateProblem != null,
                    onSubmitted: s.balanceFocus.requestFocus,
                    onPicked: s.balanceFocus.requestFocus,
                  ),
                ),
                note: c.dateProblem == null
                    ? null
                    : Text(
                        c.dateProblem!,
                        style: onest(12.5, color: Mid.coral),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
              line(
                s.owed ? 'Bank says you owe' : 'Bank balance',
                SizedBox(
                  width: 170,
                  height: 30,
                  child: TextField(
                    key: const ValueKey('reconcile-balance'),
                    controller: s.balance,
                    focusNode: s.balanceFocus,
                    autofocus: true,
                    textAlign: TextAlign.right,
                    style: onest(13, tabular: true),
                    onTap: () => s.balance.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: s.balance.text.length,
                    ),
                    onSubmitted: (_) {
                      if (ready) onLock();
                    },
                    onEditingComplete: () {},
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Mid.ground.withValues(alpha: 0.6),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: c.statement == null
                            ? BorderSide(
                                color: Mid.coral.withValues(alpha: 0.6),
                              )
                            : BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Mid.blue,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              line(
                'Cleared here',
                Money(
                  bank(c.cleared),
                  size: 13,
                  color: Mid.ink,
                  centsColor: Mid.ink,
                ),
              ),
              Container(
                width: _amount,
                height: 1,
                margin: const EdgeInsets.only(left: _label, top: 3, bottom: 3),
                color: Mid.ink3.withValues(alpha: 0.45),
              ),
              line(
                'Off by',
                off == null
                    ? Text('—', style: onest(13, color: Mid.ink3))
                    : off == 0
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const StatusGlyph(Cleared.cleared, color: Mid.green),
                          const SizedBox(width: 6),
                          Text(
                            'Matches',
                            style: onest(13, weight: 500, color: Mid.green),
                          ),
                        ],
                      )
                    : Money(
                        bank(off).abs(),
                        size: 13,
                        weight: 500,
                        color: Mid.coral,
                        centsColor: Mid.coral,
                      ),
                note: off == null || off == 0
                    ? null
                    : Text(
                        'Clear the rows your bank shows',
                        style: onest(12.5, color: Mid.ink3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: _label),
                child: Row(
                  children: [
                    BarButton(
                      key: const ValueKey('reconcile-cancel'),
                      label: 'Cancel',
                      onTap: onCancel,
                    ),
                    _LockButton(
                      label: c.toLock == 0
                          ? 'Mark reconciled'
                          : 'Lock ${c.toLock} ${c.toLock == 1 ? 'transaction' : 'transactions'}',
                      onTap: ready ? onLock : null,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Gold, like the diamond it hands out; dimmed until the numbers match.
class _LockButton extends StatelessWidget {
  const _LockButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return Material(
      key: const ValueKey('reconcile-lock'),
      color: on ? Mid.gold : Mid.gold.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.white.withValues(alpha: 0.14),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Text(
            label,
            style: onest(
              13,
              weight: 600,
              color: on ? Mid.ground : Mid.gold.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }
}
