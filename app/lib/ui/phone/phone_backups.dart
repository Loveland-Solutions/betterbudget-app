// Backups on a phone on its own (#534 piece 3, ADR 0004 "Backups on the
// phone", the owner's pick of sketch A): the computer's Backups card in the
// phone's form, a page from the foot of Accounts. A copy a day stays beside
// the ledger; Back up to… saves one where the person chooses with the
// phone's own Save to; Restore from… is the computer's, saving what was here
// first, with Undo. Under Net worth a line says only what this phone did: "No
// backup yet" until Back up to… has worked, then "Last backup 41 days ago"
// past a month.
part of 'phone_app.dart';

/// What the screens ask of whoever keeps the ledger, set only on a phone on
/// its own: a phone on a folder has its computers' copies.
class PhoneBackupActs {
  const PhoneBackupActs({
    required this.state,
    required this.backUp,
    required this.kept,
    required this.inspect,
    required this.discard,
    required this.restore,
  });

  /// How the copies stand, making today's if it is due.
  final Future<PhoneBackups?> Function() state;

  /// Back up to…: a copy through the phone's own Save to. Where it was
  /// saved, or null when nothing was chosen; throws when it couldn't be.
  final Future<SavedTo?> Function() backUp;

  /// The copies kept on this phone, newest first.
  final Future<List<PhoneKeptCopy>> Function() kept;

  /// Reads a picked backup without changing anything.
  final Future<RestoreCandidate> Function(String path) inspect;

  /// Lets go of a read backup that isn't restored.
  final Future<void> Function(RestoreCandidate candidate) discard;

  /// Puts the backup in place of the ledger, with its undo and redo.
  final Future<PhoneActed> Function(RestoreCandidate candidate) restore;
}

/// "Today 08:10", "Yesterday 08:10" or the date: the computer's way of
/// saying when a copy was made.
String _phoneWhen(Words t, DateTime at, DateTime now) {
  String two(int v) => v.toString().padLeft(2, '0');
  final today = dateOnly(now);
  final day = dateOnly(at) == today
      ? t.today
      : dateOnly(at) == today.subtract(const Duration(days: 1))
      ? t.yesterday
      : sayFullDate(t, at);
  return t.ledgerTimeAt(day, '${two(at.hour)}:${two(at.minute)}');
}

/// The line in Net worth's card: what is worth saying about backups, or
/// null for nothing. Only what this phone did, in Back up to…'s own word.
String? _backupLine(Words t, PhoneBackups b, DateTime now) {
  if (b.health.alarmingAt(now)) return t.ledgerDailyCopyFailing;
  final e = b.elsewhere;
  if (e == null) return null;
  if (e.copied == null) return t.ledgerNeverCopiedElsewhere;
  if (e.dueAt(now)) return t.ledgerLastCopiedElsewhere(e.daysAt(now));
  return null;
}

/// Under Net worth: the line and Back up to… beside it, while there is
/// something to say.
class _NetWorthBackup extends StatelessWidget {
  const _NetWorthBackup({required this.store, required this.now});
  final PhoneStore store;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: store.backups,
    builder: (context, b, _) {
      final t = context.t;
      final line = b == null ? null : _backupLine(t, b, now());
      if (line == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Divider(height: 1, color: Mid.rule),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    line,
                    key: const ValueKey('backup-line'),
                    style: onest(
                      14,
                      color: b!.health.alarmingAt(now()) ? Mid.coral : Mid.ink2,
                    ),
                  ),
                ),
                ValueListenableBuilder(
                  valueListenable: store.backingUp,
                  builder: (context, busy, _) => TextButton(
                    key: const ValueKey('net-worth-back-up'),
                    onPressed: busy
                        ? null
                        : () => unawaited(_backUp(context, store)),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      foregroundColor: Mid.blue,
                      textStyle: onest(15),
                    ),
                    child: Text(t.ledgerBackUpTo),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

/// Back up to…: the phone's Save to, then a snack bar for a copy saved, or
/// why none could be. Nothing at all for one not chosen, and a second tap
/// while one is open does nothing.
Future<void> _backUp(BuildContext context, PhoneStore store) async {
  final acts = store.backupActs;
  if (acts == null || store.backingUp.value) return;
  final messenger = ScaffoldMessenger.of(context);
  final t = context.t;
  store.backingUp.value = true;
  SavedTo? saved;
  try {
    saved = await acts.backUp();
  } catch (e) {
    debugPrint('Back up to… on the phone failed: $e');
    _backupSnack(messenger, t.phoneCouldntBackUp, key: 'back-up-failed');
    return;
  } finally {
    store.backingUp.value = false;
  }
  switch (saved) {
    case null:
      return;
    // Saved, and said so; but it's on this phone, so it isn't counted.
    case SavedTo.thisPhone:
      _backupSnack(messenger, t.phoneSavedOnPhone, key: 'saved-on-phone');
    case SavedTo.elsewhere:
      await store.refreshBackups();
      _backupSnack(messenger, t.phoneBackedUp, key: 'backed-up');
  }
}

void _backupSnack(
  ScaffoldMessengerState messenger,
  String text, {
  required String key,
  SnackBarAction? action,
}) => messenger
  ..hideCurrentSnackBar()
  ..showSnackBar(
    SnackBar(
      persist: false,
      duration: phoneSnackTime,
      key: ValueKey(key),
      backgroundColor: Mid.raised,
      content: Text(text, style: onest(15, color: Mid.ink)),
      action: action,
    ),
  );

/// The foot of Accounts: Backups, on a phone on its own.
class _BackupsRow extends StatelessWidget {
  const _BackupsRow({required this.store, required this.now});
  final PhoneStore store;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) => Material(
    color: Mid.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: Mid.rule),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: const ValueKey('to-backups'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _BackupsPage(store: store, now: now),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.t.ledgerBackupsTitle,
                  style: onest(17, weight: 500),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Mid.ink3),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The computer's Backups card in the phone's form: Daily copy, Kept,
/// Backed up, what the copies here can't do, Back up to… and Restore from….
class _BackupsPage extends StatefulWidget {
  const _BackupsPage({required this.store, required this.now});
  final PhoneStore store;
  final DateTime Function() now;

  @override
  State<_BackupsPage> createState() => _BackupsPageState();
}

class _BackupsPageState extends State<_BackupsPage> {
  PhoneStore get store => widget.store;

  /// A restore under way: the buttons wait for it.
  var _restoring = false;

  @override
  void initState() {
    super.initState();
    unawaited(store.refreshBackups().then((_) => _loadKept()));
  }

  Widget _line(String label, Widget value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: onest(13, color: Mid.ink2)),
        const SizedBox(height: 2),
        value,
      ],
    ),
  );

  /// The copies kept on this phone, for Restore from…; asked again after
  /// a restore or a backup.
  List<PhoneKeptCopy> _kept = const [];

  Future<void> _loadKept() async {
    final acts = store.backupActs;
    if (acts == null) return;
    try {
      final kept = await acts.kept();
      if (mounted) setState(() => _kept = kept);
    } catch (e) {
      debugPrint('Listing the copies on the phone failed: $e');
    }
  }

  /// Restore from…: a backup picked with the phone's own file picker.
  Future<void> _restore() async {
    final acts = store.backupActs;
    if (acts == null || _restoring) return;
    final messenger = ScaffoldMessenger.of(context);
    final t = context.t;
    final XFile? picked;
    try {
      picked = await openFile();
    } catch (e) {
      debugPrint('The phone\'s file picker failed: $e');
      _backupSnack(
        messenger,
        t.ledgerCouldntOpenFileDialog,
        key: 'restore-failed',
      );
      return;
    }
    if (picked == null) return;
    try {
      if (mounted) await _restoreFrom(picked.path);
    } finally {
      // The phone's copy of the picked file: read by now, or not wanted.
      unawaited(dropPhonePickedCopy(picked.path));
    }
  }

  /// Reads the backup at [path], asks, and puts it in with Undo: one picked,
  /// or one of the copies kept on this phone.
  Future<void> _restoreFrom(String path) async {
    final acts = store.backupActs;
    if (acts == null || _restoring) return;
    final messenger = ScaffoldMessenger.of(context);
    final t = context.t;
    setState(() => _restoring = true);
    try {
      final RestoreCandidate candidate;
      try {
        candidate = await acts.inspect(path);
      } on RestoreException catch (e) {
        _backupSnack(
          messenger,
          restoreProblem(t, e.problem),
          key: 'restore-refused',
        );
        return;
      } catch (e) {
        debugPrint('Reading a backup on the phone failed: $e');
        _backupSnack(
          messenger,
          t.ledgerCouldntReadBackup,
          key: 'restore-failed',
        );
        return;
      }
      if (!mounted) {
        await acts.discard(candidate);
        return;
      }
      final data = store.snapshot.data;
      final go = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Mid.ground,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _RestoreAsk(
          candidate: candidate,
          transactionsNow: data?.txns.length ?? 0,
          accountsNow: data?.balanceSheetAccounts.length ?? 0,
        ),
      );
      if (go != true) {
        await acts.discard(candidate);
        return;
      }
      final PhoneActed done;
      try {
        done = await store.restoreBackup(candidate);
      } catch (e) {
        debugPrint('Restoring a backup on the phone failed: $e');
        _backupSnack(messenger, t.ledgerCouldntRestore, key: 'restore-failed');
        return;
      }
      _backupSnack(
        messenger,
        t.phoneRestoredFrom(sayFullDate(t, candidate.madeAt)),
        key: 'restored',
        action: SnackBarAction(
          label: t.ledgerUndo,
          textColor: Mid.blue,
          onPressed: () => unawaited(store.replay(done.undo)),
        ),
      );
    } finally {
      if (mounted) setState(() => _restoring = false);
      unawaited(_loadKept());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      backgroundColor: Mid.ground,
      appBar: AppBar(
        backgroundColor: Mid.ground,
        foregroundColor: Mid.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(t.ledgerBackupsTitle, style: onest(20, weight: 600)),
      ),
      body: ValueListenableBuilder(
        valueListenable: store.backups,
        builder: (context, b, _) {
          final now = widget.now();
          final h = b?.health;
          final failing = h != null && h.alarmingAt(now);
          final e = b?.elsewhere;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Mid.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Mid.rule),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _line(
                      t.ledgerDailyCopy,
                      Text(
                        h?.newest == null
                            ? (failing
                                  ? t.phoneDailyCopyFailingNone
                                  : t.ledgerDailyCopyNone)
                            : failing
                            ? t.phoneDailyCopyFailingSince(
                                _phoneWhen(t, h.newest!, now),
                              )
                            : t.phoneDailyCopyWhen(
                                _phoneWhen(t, h!.newest!, now),
                              ),
                        key: const ValueKey('daily-copy'),
                        style: onest(16, color: failing ? Mid.coral : Mid.ink),
                      ),
                    ),
                    Divider(height: 1, color: Mid.rule),
                    _line(
                      t.ledgerKept,
                      Text(t.ledgerKeptWhich, style: onest(16)),
                    ),
                    Divider(height: 1, color: Mid.rule),
                    _line(
                      t.ledgerCopiedElsewhere,
                      Text(
                        e?.copied == null
                            ? t.phoneCopiedElsewhereNever
                            : _phoneWhen(t, e!.copied!, now),
                        key: const ValueKey('copied-elsewhere'),
                        style: onest(16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                defaultTargetPlatform == TargetPlatform.iOS
                    ? t.phoneBackupsNoteIos
                    : t.phoneBackupsNote,
                style: onest(15, color: Mid.ink2, height: 1.45),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder(
                valueListenable: store.backingUp,
                builder: (context, busy, _) => FilledButton(
                  key: const ValueKey('back-up'),
                  onPressed: _restoring || busy
                      ? null
                      : () => unawaited(_backUp(context, store)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: Mid.fill,
                    foregroundColor: Mid.onFill,
                    textStyle: onest(17, weight: 600),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(t.ledgerBackUpTo),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                key: const ValueKey('restore-from'),
                onPressed: _restoring ? null : () => unawaited(_restore()),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: Mid.blue,
                  side: BorderSide(color: Mid.rule),
                  textStyle: onest(17),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(t.ledgerRestoreFrom),
              ),
              // The copies kept here, which the phone's file picker can't
              // reach: each opens Restore from…'s question.
              if (_kept.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 24, 2, 6),
                  child: Text(
                    t.phoneCopiesHere,
                    style: onest(13, weight: 700, color: Mid.ink2),
                  ),
                ),
                for (final c in _kept)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Mid.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Mid.rule),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: ValueKey('kept-${c.path.split('/').last}'),
                        onTap: _restoring
                            ? null
                            : () => unawaited(_restoreFrom(c.path)),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 52),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    c.beforeRestore
                                        ? t.phoneCopyBeforeRestore(
                                            _phoneWhen(t, c.madeAt, now),
                                          )
                                        : _phoneWhen(t, c.madeAt, now),
                                    style: onest(16),
                                  ),
                                ),
                                Text(
                                  t.ledgerRestore,
                                  style: onest(15, color: Mid.blue),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The computer's "Restore this backup?" in the phone's form: when the
/// backup is from, what it holds and what is here now, the note, Cancel and
/// Restore.
class _RestoreAsk extends StatelessWidget {
  const _RestoreAsk({
    required this.candidate,
    required this.transactionsNow,
    required this.accountsNow,
  });
  final RestoreCandidate candidate;
  final int transactionsNow;
  final int accountsNow;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final made = candidate.madeAt;
    String two(int v) => v.toString().padLeft(2, '0');
    Widget line(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: onest(13, color: Mid.ink2)),
          Text(
            value,
            style: onest(
              16,
              weight: strong ? 600 : 400,
              color: strong ? Mid.ink : Mid.ink2,
              tabular: true,
            ),
          ),
        ],
      ),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          key: const ValueKey('restore-ask'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.ledgerRestoreTitle, style: onest(20, weight: 600)),
            const SizedBox(height: 16),
            line(
              t.ledgerBackupFrom,
              '${fullDate(made)}  ${two(made.hour)}:${two(made.minute)}',
              strong: true,
            ),
            line(
              t.ledgerItHolds,
              t.ledgerCounts(candidate.transactions, candidate.accounts),
              strong: true,
            ),
            line(t.ledgerHereNow, t.ledgerCounts(transactionsNow, accountsNow)),
            const SizedBox(height: 4),
            Text(
              t.ledgerRestoreNote,
              style: onest(15, color: Mid.ink2, height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('restore-cancel'),
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: Mid.blue,
                      side: BorderSide(color: Mid.rule),
                      textStyle: onest(17),
                    ),
                    child: Text(t.ledgerCancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('restore-go'),
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: Mid.fill,
                      foregroundColor: Mid.onFill,
                      textStyle: onest(17, weight: 600),
                    ),
                    child: Text(t.ledgerRestore),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
