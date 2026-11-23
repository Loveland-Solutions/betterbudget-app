// Another phone or computer (#534 piece 4, ADR 0004 "Another phone or
// computer", the owner's pick of sketch B): a ledger made on this phone moves
// to a folder the phone's own picker reaches (Google Drive, iCloud Drive), and
// a second phone or a computer opens it from there with Open ledger. A row at
// the foot of Accounts opens a page of two steps: 1, on this phone, Move my
// ledger to a folder…; 2, on the other, what to do there, then who has opened
// it. The move is the computer's, in its words, with Undo.
part of 'phone_app.dart';

/// What the page asks of whoever keeps the ledger, set only when the ledger
/// was made on this phone.
class PhoneShareActs {
  const PhoneShareActs({
    required this.pick,
    required this.move,
    required this.back,
    required this.folder,
    required this.members,
  });

  /// The phone's own folder picker: the folder's address, or null.
  final Future<String?> Function() pick;

  /// Moves the ledger to the folder; with `replace`, over a ledger there.
  final Future<LedgerMove> Function(String folder, {bool replace}) move;

  /// Moves it back to this phone: the file in the folder stays.
  final Future<void> Function() back;

  /// Where the ledger was moved, and what the phone called the folder;
  /// null while it is only on this phone.
  final ({String address, String? name})? Function() folder;

  /// What each phone or computer that has opened it calls itself.
  final List<String?> Function() members;
}

/// The foot of Accounts, under Backups.
class _ShareRow extends StatelessWidget {
  const _ShareRow({required this.store});
  final PhoneStore store;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final acts = store.shareActs!;
    final at = acts.folder();
    final members = acts.members();
    final under = at == null
        ? t.phoneShareRowAlone
        : members.isNotEmpty
        ? (members.first == null
              ? t.phoneShareOpenedUnnamed
              : t.phoneShareRowAlso(members.first!))
        : at.name == null
        ? t.phoneShareRowStoredNoName
        : t.phoneShareRowStored(at.name!);
    return Material(
      color: Mid.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Mid.rule),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('to-share'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => _SharePage(store: store)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.phoneShareRow, style: onest(17, weight: 500)),
                      const SizedBox(height: 2),
                      Text(
                        under,
                        key: const ValueKey('share-row-under'),
                        style: onest(14, color: Mid.ink2),
                      ),
                    ],
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
}

class _SharePage extends StatefulWidget {
  const _SharePage({required this.store});
  final PhoneStore store;

  @override
  State<_SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<_SharePage> {
  PhoneStore get store => widget.store;

  /// A move or a move back under way: the buttons wait for it.
  var _busy = false;

  bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _move() async {
    final acts = store.shareActs;
    if (acts == null || _busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final t = context.t;
    final String? folder;
    try {
      folder = await acts.pick();
    } catch (e) {
      debugPrint('Picking a folder failed: $e');
      _backupSnack(messenger, t.ledgerFolderCouldnt, key: 'move-failed');
      return;
    }
    if (folder == null || !mounted) return;
    setState(() => _busy = true);
    try {
      var done = await acts.move(folder);
      if (done == LedgerMove.folderHasLedger) {
        if (!mounted) return;
        final replace = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Mid.panel,
            title: Text(
              t.phoneShareHasLedgerTitle,
              style: onest(19, weight: 600),
            ),
            content: Text(
              t.phoneShareHasLedgerBody,
              style: onest(16, height: 1.4),
            ),
            actions: [
              TextButton(
                key: const ValueKey('has-ledger-cancel'),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(t.ledgerCancel, style: onest(15, color: Mid.blue)),
              ),
              TextButton(
                key: const ValueKey('has-ledger-replace'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  t.ledgerFolderReplace,
                  style: onest(15, weight: 600, color: Mid.coral),
                ),
              ),
            ],
          ),
        );
        if (replace != true) return;
        done = await acts.move(folder, replace: true);
      }
      if (done != LedgerMove.moved) return;
      final name = acts.folder()?.name;
      _backupSnack(
        messenger,
        name == null ? t.phoneShareMovedNoName : t.phoneShareMoved(name),
        key: 'moved',
        action: SnackBarAction(
          label: t.ledgerUndo,
          textColor: Mid.blue,
          onPressed: () => unawaited(_undoMove()),
        ),
      );
    } catch (e) {
      debugPrint('Moving the ledger to a folder failed: $e');
      _backupSnack(messenger, t.ledgerFolderCouldnt, key: 'move-failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The toast's Undo of a move: back on this phone, said with no second
  /// toast. Nothing has opened the ledger in the few seconds since.
  Future<void> _undoMove() async {
    final acts = store.shareActs;
    if (acts == null) return;
    try {
      await acts.back();
    } catch (e) {
      debugPrint('Undoing the move failed: $e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _moveBack() async {
    final acts = store.shareActs;
    final at = acts?.folder();
    if (acts == null || at == null || _busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final t = context.t;
    // Others use it from the folder: what they lose is said first, and
    // they can go ahead (warn, don't block).
    final members = acts.members();
    if (members.isNotEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const ValueKey('move-back-ask'),
          backgroundColor: Mid.panel,
          title: Text(t.phoneShareBackAskTitle, style: onest(19, weight: 600)),
          content: Text(
            members.length == 1 && members.single != null
                ? t.phoneShareBackAskOne(members.single!)
                : t.phoneShareBackAskOthers,
            style: onest(16, height: 1.4),
          ),
          actions: [
            TextButton(
              key: const ValueKey('move-back-cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(t.ledgerCancel, style: onest(15, color: Mid.blue)),
            ),
            TextButton(
              key: const ValueKey('move-back-go'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                t.phoneShareMoveBack,
                style: onest(15, weight: 600, color: Mid.coral),
              ),
            ),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await acts.back();
      _backupSnack(
        messenger,
        at.name == null ? t.phoneShareBackNoName : t.phoneShareBack(at.name!),
        key: 'moved-back',
        action: SnackBarAction(
          label: t.ledgerUndo,
          textColor: Mid.blue,
          onPressed: () => unawaited(_redoMove(at.address)),
        ),
      );
    } catch (e) {
      debugPrint('Moving the ledger back to the phone failed: $e');
      _backupSnack(messenger, t.ledgerFolderCouldnt, key: 'move-failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The toast's Undo of Move it back: into the same folder, onto the
  /// ledger's own file there.
  Future<void> _redoMove(String folder) async {
    final acts = store.shareActs;
    if (acts == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final t = context.t;
    var moved = false;
    try {
      moved = await acts.move(folder) == LedgerMove.moved;
    } catch (e) {
      debugPrint('Moving the ledger to its folder again failed: $e');
    }
    // Its own file there is moved onto with nothing asked; anything else
    // (the folder gone, another ledger put there since) is said.
    if (!moved) {
      _backupSnack(messenger, t.ledgerFolderCouldnt, key: 'move-failed');
    }
    if (mounted) setState(() {});
  }

  Widget _step({
    required Key key,
    required Widget mark,
    required String title,
    required List<Widget> children,
  }) => Container(
    key: key,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Mid.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Mid.rule),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            mark,
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: onest(17, weight: 600))),
          ],
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    ),
  );

  Widget _number(int n, {required bool filled}) => Container(
    width: 28,
    height: 28,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: filled ? Mid.fill : null,
      border: filled ? null : Border.all(color: Mid.ink3, width: 1.5),
    ),
    child: Text(
      '$n',
      style: onest(15, weight: 700, color: filled ? Mid.onFill : Mid.ink2),
    ),
  );

  Widget get _done => Container(
    width: 28,
    height: 28,
    alignment: Alignment.center,
    decoration: BoxDecoration(shape: BoxShape.circle, color: Mid.fill),
    child: Icon(Icons.check_rounded, size: 18, color: Mid.onFill),
  );

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
        title: Text(t.phoneShareTitle, style: onest(20, weight: 600)),
      ),
      body: ListenableBuilder(
        // A look that hears from another phone or computer names it.
        listenable: store,
        builder: (context, _) {
          final acts = store.shareActs;
          if (acts == null) return const SizedBox.shrink();
          final at = acts.folder();
          final members = acts.members();
          final body = onest(15, height: 1.45);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              if (at == null) ...[
                Text(
                  _ios ? t.phoneShareIntroIos : t.phoneShareIntro,
                  style: onest(15, color: Mid.ink2, height: 1.45),
                ),
                const SizedBox(height: 16),
              ],
              _step(
                key: const ValueKey('share-step-here'),
                mark: at == null ? _number(1, filled: true) : _done,
                title: t.phoneShareStepHere,
                children: at == null
                    ? [
                        Text(
                          _ios
                              ? t.phoneShareStepHereBodyIos
                              : t.phoneShareStepHereBody,
                          style: body,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          key: const ValueKey('move-to-folder'),
                          onPressed: _busy ? null : () => unawaited(_move()),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: Mid.fill,
                            foregroundColor: Mid.onFill,
                            textStyle: onest(16, weight: 600),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(t.ledgerFolderChoose),
                        ),
                      ]
                    : [
                        Text(
                          at.name == null
                              ? t.phoneShareStoredInNoName
                              : t.phoneShareStoredIn(at.name!),
                          key: const ValueKey('share-stored-in'),
                          style: body,
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            key: const ValueKey('move-back'),
                            onPressed: _busy
                                ? null
                                : () => unawaited(_moveBack()),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              t.phoneShareMoveBack,
                              style: onest(15, color: Mid.blue),
                            ),
                          ),
                        ),
                      ],
              ),
              const SizedBox(height: 16),
              _step(
                key: const ValueKey('share-step-there'),
                mark: _number(2, filled: false),
                title: t.phoneShareStepThere,
                children: [
                  Text(t.phoneShareStepThereBody, style: body),
                  const SizedBox(height: 6),
                  // Said in both states: the other person reads step 2 at
                  // the moment they type the key.
                  Text(
                    t.phoneShareKeyNote,
                    style: onest(15, color: Mid.ink2, height: 1.45),
                  ),
                  if (at != null) const SizedBox(height: 6),
                  if (at == null)
                    const SizedBox.shrink()
                  else if (members.isEmpty)
                    Text(
                      t.phoneShareNoneYet,
                      key: const ValueKey('share-none-yet'),
                      style: onest(15, color: Mid.ink2, height: 1.45),
                    )
                  else
                    for (final m in members)
                      Text(
                        m == null
                            ? t.phoneShareOpenedUnnamed
                            : t.phoneShareOpenedOn(m),
                        style: body,
                      ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
