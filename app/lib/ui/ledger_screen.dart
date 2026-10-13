import 'dart:async';
import 'dart:io'
    show Directory, File, FileSystemEntityType, FileSystemException;
import 'dart:ui' show AppExitResponse;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/backup.dart';
import '../data/cloud_folder.dart';
import '../data/database.dart';
import '../data/demo_seed.dart';
import '../data/encryption.dart';
import '../data/keys.dart';
import '../data/phone_inbox.dart';
import '../domain/budget.dart';
import '../domain/combine.dart' show Ask, AskKind, AskSide, Pick;
import '../domain/forecast.dart';
import '../domain/ledger.dart';
import '../domain/money.dart';
import '../domain/pay.dart';
import '../domain/payee_rules.dart';
import '../domain/phone.dart'
    show computerNamePrefix, phoneNamePrefix, showSourceKey;
import '../domain/readiness.dart';
import '../domain/setup.dart';
import '../domain/sync.dart' show MadeHow;
import '../import/mapping.dart';
import '../import/sheet.dart';
import 'balance_header.dart';
import 'entry_row.dart';
import 'reconcile.dart';
import 'recovery_key_screen.dart';
import 'register.dart';
import 'appearance.dart';
import 'schemes.dart';
import 'language.dart';
import 'brand.dart';
import 'data_words.dart';
import 'theme.dart';

part 'accounts.dart';
part 'budget.dart';
part 'import_dialog.dart';
part 'pay_setup.dart';
part 'payees.dart';
part 'register_settings.dart';
part 'rows_dialog.dart';
part 'savings.dart';
part 'setup.dart';

bool get _isMac =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Top-level sections. Savings holds the steps to getting financially
/// prepared (rule 25). Settings opens from the gear
/// under Net worth, not from a section header.
enum AppSection { ledger, budget, savings, payees, settings }

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({
    super.key,
    required this.db,
    this.clock = DateTime.now,
    this.backups,
    this.encrypted = false,
    this.recoveryKeySaved = false,
    this.checkRecoveryKey,
    this.onRecoveryKeyChecked,
    this.startupNotice,
    this.offerRestore = false,
    this.startFrom,
    this.startPath,
    this.demo = false,
    this.folderAccess = const FolderAccess(),
  });

  final AppDatabase db;

  /// Fills an empty ledger with the made-up demo data. The app never does:
  /// a new ledger opens on setup (ADR 0004). Most tests do.
  final bool demo;

  /// The app's backups, whose daily copy runs from main. Tests may leave it
  /// out; one is made for "Back up to…" and "Restore from…".
  final Backups? backups;
  final DateTime Function() clock;

  /// The ledger is encrypted (ADR 0001): Settings says so, and whether the
  /// recovery key was saved when it was shown. False in tests.
  final bool encrypted;

  /// The recovery key was saved, copied, typed or checked (kept beside the
  /// data key, not in the ledger).
  final bool recoveryKeySaved;

  /// Whether a typed key is this ledger's, for "Check my recovery key…".
  final Future<bool> Function(RecoveryKey key)? checkRecoveryKey;
  final VoidCallback? onRecoveryKeyChecked;

  /// Said once, as a toast, when the ledger opens: what encrypting its old
  /// copies did.
  final String? startupNotice;

  /// A key was just typed on a computer with no ledger: offer to open a
  /// backup before anything else.
  final bool offerRestore;

  /// With [offerRestore]: where the person said their ledger is, before
  /// the key was typed. Null asks.
  final StartFrom? startFrom;

  /// With [startFrom]: the folder or the backup file already picked on the
  /// first screen, and found to open with this ledger's key.
  final String? startPath;

  /// How a picked folder is remembered between launches; faked in tests.
  final FolderAccess folderAccess;

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  late final Stream<LedgerData> _ledger;
  var _section = AppSection.ledger;

  /// The Budget page, for a key that reaches the screen while it has a
  /// category open in Edit.
  final _budgetKey = GlobalKey<_BudgetPageState>();
  final _payeesKey = GlobalKey<_PayeesPageState>();
  final _setupKey = GlobalKey<_SetupPageState>();
  int? _accountId;

  /// The clicked row; its actions show in a bar under it.
  int? _selected;

  /// On the selected row, so it can be scrolled into view.
  final _selectedKey = GlobalKey();

  /// The row the "Already in this account" line led to, while its bill is
  /// still open.
  int? _pointed;
  final _pointedKey = GlobalKey();
  var _filter = RegisterFilter.all;
  final _hoveredStatus = ValueNotifier<Cleared?>(null);
  final _search = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'search');

  /// Holds keyboard focus for the register, so row shortcuts reach [_onKey].
  final _registerFocus = FocusNode(debugLabel: 'register');
  late final EntryRowController _entry;

  /// The new-transaction row is open. It opens from Add or ⌘N.
  bool _adding = false;

  /// The new-account form is showing instead of an account.
  bool _newAccount = false;

  /// Empty accounts started at ₮0 this session: they show the register, not
  /// the balance question.
  final _startedEmpty = <int>{};

  /// Just added, and maybe not in the latest snapshot yet: stays chosen until
  /// it arrives. Any other account missing from a snapshot (a restore) gives
  /// way to the first open one.
  int? _pendingAccountId;

  /// All accounts is open in the ledger, instead of one account.
  bool _all = false;

  /// All accounts, narrowed to the rows filed under this category.
  int? _categoryFilter;

  /// All accounts, narrowed to a budget period (month or pay period): a
  /// category's Spent opened from Budget shows the period it was in.
  BudgetSpan? _periodFilter;

  /// Bumped by Rename in the sidebar's right-click menu: the account opens
  /// with its name ready to edit in the header.
  var _renameRequest = 0;
  ({
    String message,
    String? detail,
    VoidCallback? undo,
    ({String label, VoidCallback onTap})? more,
  })?
  _toast;

  /// Everything undoable done this session, oldest first. ⌘Z / Ctrl+Z undoes
  /// the newest; a toast's Undo works only while its action is the newest.
  final _history = <_Undoable>[];

  /// Undone actions, newest last. ⌘⇧Z (Ctrl+Y on Windows) redoes them; any
  /// new action clears it.
  final _redo = <_Undoable>[];

  /// A reconcile in progress, if any.
  ReconcileSession? _reconcile;

  /// Lock was pressed and the write hasn't returned; a second click waits.
  bool _locking = false;

  /// A restore (or its undo or redo) is replacing everything. Input is
  /// blocked: anything saved meanwhile would land in neither copy.
  bool _restoring = false;

  /// The transaction open in the inline editor, if any.
  RegisterEditing? _editing;

  /// Last row click, to recognise a double-click without delaying single ones.
  ({int id, DateTime at})? _lastTap;
  Timer? _toastTimer;

  /// The popup's own time is up; it leaves once the pointer is off it.
  bool _toastDue = false;

  /// Where the pointer last moved or clicked on the popup; null once off it.
  Offset? _toastPointer;

  /// The little longer the popup stays once the pointer leaves it.
  Timer? _toastGrace;
  final _toastKey = GlobalKey();
  String? _entryProblemShown;

  /// Rows of the current account, by transaction id, from the latest build.
  Map<int, RegisterRow> _rows = const {};

  AppDatabase get db => widget.db;
  late final Backups _backups = widget.backups ?? Backups(db);

  /// The ledger kept in a folder the user picked (ADR 0005).
  late final CloudFolder _cloud = CloudFolder(
    _backups,
    access: widget.folderAccess,
  );
  bool _ledgerSeen = false;
  AppLifecycleListener? _exit;

  /// Looks in the folder while the ledger is stored in one: at the ledger
  /// there, which another computer may have written, and for what the
  /// phones have written.
  Timer? _phones;
  bool _takingPhones = false;
  bool _lookingInFolder = false;

  /// The folder's ledger the question was last asked about, by its digest:
  /// asked once by itself, and after that from Settings.
  String? _askedAbout;

  /// A folder's ledger that couldn't be taken in, by its digest: not tried
  /// again until the file changes.
  String? _folderRefused;

  void _watchPhones() {
    if (_cloud.value.path == null) {
      _phones?.cancel();
      _phones = null;
    } else if (_phones == null) {
      _phones = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _lookInFolder(),
      );
      unawaited(_lookInFolder());
    }
  }

  /// One look in the folder (ADR 0005, "Never write blind"): the ledger
  /// there first, written over only if it holds nothing this computer
  /// lacks, then the phones' entries.
  Future<void> _lookInFolder() async {
    if (_cloud.value.path == null || _lookingInFolder) return;
    _lookingInFolder = true;
    try {
      await _cloud.check(widget.clock());
      if (!mounted) return;
      await _folderNews();
      // Not while the folder's ledger is waiting to be taken in or chosen:
      // an entry taken in now would be a change here, and gone again if the
      // folder's ledger is the one kept.
      if (mounted && _cloud.value.standing == FolderStanding.ok) {
        await _takePhones();
      }
    } catch (e) {
      debugPrint('Looking in the folder failed: $e');
    } finally {
      _lookingInFolder = false;
    }
  }

  /// Something is open that a whole new ledger mustn't land in the middle
  /// of: the next look brings it.
  bool get _busyForFolder =>
      !mounted ||
      _restoring ||
      _reconcile != null ||
      _toast != null ||
      (_editing?.controller.isDirty() ?? false) ||
      (_adding && _entry.isDirty()) ||
      !(ModalRoute.of(context)?.isCurrent ?? true);

  /// Acts on what the last look found: a newer ledger is taken in, and one
  /// changed apart from this computer's is asked about, once.
  Future<void> _folderNews({bool justMoved = false}) async {
    switch (_cloud.value.standing) {
      case FolderStanding.newer:
        await _openFolderLedger();
      case FolderStanding.combine:
        await _bringInFolderChanges();
        // Found not to combine after all: asked about like any other.
        if (mounted && _cloud.value.standing == FolderStanding.apart) {
          await _folderNews(justMoved: justMoved);
        }
      case FolderStanding.rows:
        final digest = _cloud.theirs?.look.digest;
        if (digest == null || digest == _askedAbout || _busyForFolder) return;
        await _chooseRows();
        // Found not to combine after all: asked about like any other.
        if (mounted && _cloud.value.standing == FolderStanding.apart) {
          await _folderNews(justMoved: justMoved);
        }
      case FolderStanding.apart:
        final digest = _cloud.theirs?.look.digest;
        if (digest == null || digest == _askedAbout || _busyForFolder) return;
        await _chooseLedger(justMoved: justMoved);
      default:
    }
  }

  /// Takes in the ledger another computer saved to the folder, which has
  /// everything this one has and more. What was here is saved first, in
  /// Backups.
  Future<void> _openFolderLedger({bool atLaunch = false}) async {
    if (!atLaunch && _busyForFolder) return;
    final now = widget.clock();
    // Worked out afresh, trusting nothing remembered: this replaces
    // everything here.
    if (await _cloud.check(now, fresh: true) != FolderStanding.newer) return;
    final theirs = _cloud.theirs;
    if (theirs == null || theirs.look.digest == _folderRefused || !mounted) {
      return;
    }
    // What this computer held when it was found to have nothing the
    // folder's lacks: the take goes ahead only if it still holds that.
    final unchanged = _cloud.mineDigest;
    if (unchanged == null) return;
    final RestoreCandidate candidate;
    try {
      candidate = await _backups.inspect(theirs.copy.path, now);
    } catch (e) {
      debugPrint('The folder’s ledger couldn’t be opened: $e');
      _folderRefused = theirs.look.digest;
      _couldntOpenFolderLedger();
      return;
    }
    // The folder's file was read again meanwhile, or something was opened
    // here: not this one, not now. The next look brings it.
    if (!identical(_cloud.theirs, theirs) || (!atLaunch && _busyForFolder)) {
      await _backups.discard(candidate);
      return;
    }
    await _takeFolderLedger(candidate, theirs, onlyIfDigest: unchanged);
  }

  void _couldntOpenFolderLedger() {
    final path = _cloud.value.path;
    if (!mounted || path == null) return;
    _showToast(context.t.ledgerFolderCouldntOpen(_folderName(path)));
  }

  /// Replaces what's here with [candidate], the folder's ledger, as it is.
  Future<void> _takeFolderLedger(
    RestoreCandidate candidate,
    FolderTheirs theirs, {
    String? onlyIfDigest,
  }) async {
    final path = _cloud.value.path;
    if (!mounted || path == null) {
      await _backups.discard(candidate);
      return;
    }
    _cancelEdit();
    _endReconcile();
    setState(() {
      _selected = null;
      _adding = false;
    });
    try {
      await _whileRestoring(
        () => _backups.restore(
          candidate,
          widget.clock(),
          fromFolder: true,
          onlyIfDigest: onlyIfDigest,
        ),
      );
    } on ChangedSinceException {
      // Something was changed here while the folder's was being read: it
      // stays, and the next look finds the two changed apart.
      return;
    } catch (e) {
      debugPrint('Taking in the folder’s ledger failed: $e');
      _folderRefused = theirs.look.digest;
      _couldntOpenFolderLedger();
      return;
    }
    // Its paydays and bills are scheduled after it is in, never before: a
    // row this computer scheduled first would be a change made here.
    try {
      await db.ensurePaydays(today);
      await db.ensurePlanBills(today);
    } catch (e) {
      debugPrint('Scheduling after the folder’s ledger failed: $e');
    }
    // Earlier actions point at rows the folder's ledger replaced.
    _history.clear();
    _redo.clear();
    await _cloud.check(widget.clock(), fresh: true);
    if (!mounted) return;
    final t = context.t;
    final label = switch (theirs.look.savedByName) {
      final name? => t.ledgerFolderOpenedFrom(name),
      null => t.ledgerFolderOpened,
    };
    final detail = t.ledgerFolderCopied(
      _folderName(path),
      _sayWhen(t, theirs.look.savedAt ?? theirs.modified, widget.clock()),
    );
    // No Undo (owner, 2026-10-10: "Only undo what the user in front of
    // the computer did or decided. Nothing else"): this was the other
    // computer's doing. What was here is in Backups, for Restore from….
    _showToast(label, detail: detail);
  }

  /// This computer and another both changed the ledger, in ways that can
  /// both stand (ADR 0005, "Combine"): what the other changed is brought in
  /// here, and the two together are written to the folder. This computer's
  /// ledger as it was is saved first, in Backups. The popup says what came,
  /// and what the person would want to look at: a row that looks the same
  /// as one already here, and more assigned than there is.
  ///
  /// With [picks], the person's choice for what both changed in a way that
  /// can't both stand ([_chooseRows]).
  Future<void> _bringInFolderChanges({Map<String, Pick>? picks}) async {
    final path = _cloud.value.path;
    if (path == null || _busyForFolder) return;
    _cancelEdit();
    setState(() {
      _selected = null;
      _adding = false;
    });
    // How much more is assigned than there is, by currency.
    Map<Currency, int> over(LedgerData? data) {
      if (data == null) return const {};
      final p = budgetPeriod(today, data.periodSchedule);
      return {
        for (final pool in Budget.of(
          data,
          start: p.start,
          end: p.end,
          today: today,
        ).pools)
          if (pool.notAssigned < 0) pool.currency: -pool.notAssigned,
      };
    }

    final overBefore = over(_data);
    final CombinedIn? done;
    try {
      done = await _whileRestoring(
        () => _cloud.bringIn(widget.clock(), picks: picks),
      );
    } catch (e) {
      debugPrint('Bringing in the folder’s changes failed: $e');
      return;
    }
    if (done == null) {
      // Chosen for, and then not brought in: something changed here while
      // the question was open.
      if (picks != null && mounted) {
        _showToast(context.t.ledgerRowsChangedMeanwhile);
      }
      return;
    }
    // What the two plans and pays ask for now, as after a ledger is taken
    // in.
    try {
      await db.ensurePaydays(today);
      await db.ensurePlanBills(today);
    } catch (e) {
      debugPrint('Scheduling after the folder’s changes failed: $e');
    }
    if (!done.quiet) {
      // Earlier actions may point at rows the other computer changed.
      _history.clear();
      _redo.clear();
    }
    // The two together go to the folder.
    await _cloud.check(widget.clock(), fresh: true);
    // What the two had made alike, settled, and nothing else: nothing to
    // say.
    if (done.quiet) return;
    Map<Currency, int> overNow = const {};
    try {
      overNow = over(await db.loadLedger());
    } catch (e) {
      debugPrint('The budget after the folder’s changes couldn’t be read: $e');
    }
    if (!mounted) return;
    final t = context.t;
    final n = done.transactions;
    final label = switch (done.from.savedByName) {
      _ when picks != null && n == 0 && done.others == 0 => t.ledgerRowsSaved(
        picks.length,
      ),
      final name? when n == 0 => t.ledgerCombinedOtherFrom(name),
      final name? when done.others == 0 => t.ledgerCombinedFrom(n, name),
      final name? => t.ledgerCombinedMoreFrom(n, name),
      null when n == 0 => t.ledgerCombinedOther,
      null when done.others == 0 => t.ledgerCombined(n),
      null => t.ledgerCombinedMore(n),
    };
    // More assigned than there is, where it wasn't or was less before.
    final short = overNow.entries
        .where((e) => e.value > (overBefore[e.key] ?? 0))
        .firstOrNull;
    final lines = [
      if (done.alike.isNotEmpty) t.ledgerCombinedAlike(done.alike.length),
      if (short != null)
        t.ledgerCombinedOverAssigned(
          formatShort(short.value, currency: short.key),
        ),
    ];
    // No Undo (owner, 2026-10-10: "Only undo what the user in front of the
    // computer did or decided. Nothing else"). ⌘Z undoes what is done here
    // from now on; this computer's ledger as it was is in Backups.
    _showToast(
      label,
      detail: lines.isEmpty
          ? t.ledgerFolderCopied(
              _folderName(path),
              _sayWhen(t, done.from.savedAt ?? done.modified, widget.clock()),
            )
          : lines.join('\n'),
      more: done.alike.isEmpty
          ? null
          : (
              label: t.ledgerShowMoved,
              onTap: () => _showIn(
                done!.alike.first.account,
                done.alike.first.transaction,
              ),
            ),
    );
  }

  /// Both computers changed some of the same things in ways that can't both
  /// stand: lists each with both versions and what it was, and brings in the
  /// rest with the person's choices. Nothing is written until then.
  Future<void> _chooseRows() async {
    final theirs = _cloud.theirs;
    final path = _cloud.value.path;
    final asks = _cloud.asks;
    if (theirs == null || path == null || asks.isEmpty || _restoring) return;
    _askedAbout = theirs.look.digest;
    final picks = await showDialog<Map<String, Pick>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) =>
          _RowsDialog(asks: asks, computer: theirs.look.savedByName),
    );
    if (picks == null || !mounted) return;
    await _bringInFolderChanges(picks: picks);
  }

  /// Both this computer's ledger and the folder's were changed: shows what
  /// each holds and lets the person choose. Nothing is written until then.
  Future<void> _chooseLedger({bool justMoved = false}) async {
    if (_cloud.value.standing == FolderStanding.rows) return _chooseRows();
    final theirs = _cloud.theirs;
    final path = _cloud.value.path;
    if (theirs == null || path == null || _restoring) return;
    _askedAbout = theirs.look.digest;
    final now = widget.clock();
    final t = context.t;
    final RestoreCandidate candidate;
    try {
      candidate = await _backups.inspect(theirs.copy.path, now);
    } catch (e) {
      debugPrint('The folder’s ledger couldn’t be read: $e');
      _couldntOpenFolderLedger();
      return;
    }
    if (!mounted) {
      await _backups.discard(candidate);
      return;
    }
    final data = _data;
    final choice = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _TwoLedgersDialog(
        title: justMoved ? t.ledgerTwoTitleFolder : t.ledgerTwoTitle,
        folder: _folderName(path),
        theirs: candidate,
        savedBy: theirs.look.savedByName,
        savedWhen: _sayWhen(t, theirs.look.savedAt ?? theirs.modified, now),
        transactionsHere: data?.txns.length ?? 0,
        accountsHere: data?.balanceSheetAccounts.length ?? 0,
      ),
    );
    if (choice == null || !mounted) {
      await _backups.discard(candidate);
      return;
    }
    if (choice) {
      await _takeFolderLedger(candidate, theirs);
      return;
    }
    await _backups.discard(candidate);
    late KeptMine kept;
    try {
      kept = await _cloud.keepMine(widget.clock());
    } catch (e) {
      debugPrint('Writing this computer’s ledger to the folder failed: $e');
      _showToast(t.ledgerFolderCouldnt);
      return;
    }
    if (!mounted) return;
    if (!kept.undoable) {
      // On change files the choice went out to the other computer the
      // moment it was made: nothing to take back.
      _showToast(t.ledgerFolderKeptMine(_folderName(path)));
      return;
    }
    _did(
      t.ledgerFolderKeptMine(_folderName(path)),
      undo: () => _cloud.undoKeepMine(kept, widget.clock()),
      redo: () async => kept = await _cloud.keepMine(widget.clock()),
    );
  }

  /// The Budget page with [id]'s Edit open under its row.
  void _editCategory(int id) {
    setState(() => _section = AppSection.budget);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _budgetKey.currentState?.openEdit(id),
    );
  }

  /// Adds the phones' entries to the ledger as uncleared rows (ADR 0005):
  /// straight in, with one undo for the lot.
  Future<void> _takePhones() async {
    final path = _cloud.value.path;
    if (path == null || _takingPhones) return;
    // Not into the middle of a restore, a reconcile or setup: the next
    // look brings them.
    if (_restoring || _reconcile != null) return;
    if (_data case final d? when inSetup(d)) return;
    // Nor over a popup still on screen, whose Undo would be lost.
    if (_toast != null) return;
    // Nor while the folder's ledger isn't this computer's.
    if (_cloud.value.standing != FolderStanding.ok) return;
    _takingPhones = true;
    try {
      final inboxes = await readPhoneInboxes(
        Directory(path),
        _backups.dataKey,
        scratch: Directory('${Directory.systemTemp.path}/betterbudget-phones'),
      );
      if (inboxes.isEmpty) return;
      final take = await db.takePhoneEntries(inboxes, today: today);
      if (take == null || !mounted) return;
      final t = context.t;
      final label = take.transactionIds.isEmpty
          ? t.ledgerCategoryFromPhone(take.categoryIds.length)
          : t.ledgerFromPhone(take.transactionIds.length);
      // Not in ⌘Z's history (owner, 2026-10-08): ⌘Z pressed for something
      // just typed would take out rows the phone has already let go of.
      // Only this popup's Undo does, and ⌘⇧Z brings them back.
      final action = _Undoable(
        label,
        () => db.undoPhoneTake(take),
        () => db.redoPhoneTake(take),
      );
      _showToast(
        label,
        // One new category, with nothing assigned yet: its Edit is where
        // that is done.
        more: take.categoryIds.length == 1
            ? (
                label: t.ledgerEditCategory(take.categoryNames.single),
                onTap: () => _editCategory(take.categoryIds.single),
              )
            : null,
        undo: () async {
          try {
            await action.undo();
          } catch (e) {
            if (mounted) _showToast(context.t.ledgerCouldntUndo(label));
            return;
          }
          _redo.add(action);
          if (mounted) _showToast(context.t.ledgerUndone(label));
        },
      );
    } catch (e) {
      debugPrint('Taking in the phones’ entries failed: $e');
    } finally {
      _takingPhones = false;
    }
  }

  /// The latest ledger, for comparing a backup with what's here now.
  LedgerData? _data;

  /// The ledger as the database gave it, and the word Income was named
  /// with: [_data] is made again only when one of them changes.
  LedgerData? _loaded;
  String? _incomeWord;
  DateTime get today => dateOnly(widget.clock());

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_keepKeys);
    // What each row typed or imported here is stamped with (ADR 0005, "Where
    // a row came from"): this computer's id, so a rename shows on every row.
    final named = _cloud.computerId().then((id) {
      if (mounted) db.thisComputer = id;
    });
    // Each pay schedule's next payday is scheduled before the first look,
    // and after the folder has been looked at (ADR 0005): a row this
    // computer scheduled before taking in a newer ledger would be a change
    // made here, and the two would look changed apart.
    _ledger =
        Stream.fromFuture(
          (widget.demo ? seedDemoIfEmpty(db, today) : Future<void>.value())
              // Before any row is made: it is stamped with the name.
              .then((_) => named)
              .then((_) => _firstLookInFolder())
              .then((_) => _nameThisComputer())
              .then((_) => db.ensurePaydays(today))
              .then((_) => db.ensurePlanBills(today)),
        ).asyncExpand((_) => db.watchLedger()).map((data) {
          _ensureSafetyNet(data);
          // The first look isn't a change; [CloudFolder.load] copies at launch.
          if (_ledgerSeen) _cloud.ledgerChanged(widget.clock);
          _ledgerSeen = true;
          return data;
        });
    // A change made in the last few seconds is written before the app goes.
    _exit = AppLifecycleListener(
      // Back at the front: another computer or a phone may have written
      // since.
      onResume: _lookInFolder,
      onExitRequested: () async {
        await _cloud.flush().timeout(
          const Duration(seconds: 5),
          onTimeout: () {},
        );
        return AppExitResponse.exit;
      },
    );
    _entry =
        EntryRowController(
            onSubmit: _post,
            suggestCategory: (payee) =>
                db.suggestedCategory(payee, _entryAccountId ?? _accountId!),
          )
          ..onProblem = _entryProblem
          ..remembered = (payee, category, pay) => _rememberedSo(
            _entryAccountId ?? _accountId,
            payee,
            category,
            pay,
          );
    _keySaved = widget.recoveryKeySaved;
    PackageInfo.fromPlatform().then(
      (p) {
        if (mounted) setState(() => _version = (p.version, p.buildNumber));
      },
      // No bundle to read (widget tests): Settings leaves the line out.
      onError: (_) {},
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.startupNotice case final n?) _showToast(n);
      if (widget.offerRestore) _offerRestore();
    });
  }

  /// The folder is looked at before anything is scheduled or shown: a
  /// newer ledger there is taken in first. A folder that doesn't answer
  /// doesn't hold the app up for long.
  Future<void> _firstLookInFolder() async {
    try {
      await _cloud
          .load(widget.clock())
          .timeout(const Duration(seconds: 20), onTimeout: () {});
      if (mounted && _cloud.value.standing == FolderStanding.newer) {
        await _openFolderLedger(atLaunch: true);
      } else if (mounted && _cloud.value.standing == FolderStanding.combine) {
        // The other computer's changes, before anything is scheduled here.
        await _bringInFolderChanges();
      }
    } catch (e) {
      debugPrint('The first look in the folder failed: $e');
    }
    if (mounted) _cloud.addListener(_watchPhones);
    if (mounted) _watchPhones();
  }

  late bool _keySaved;

  /// The app's version and build number from its bundle, for Settings.
  (String, String)? _version;

  /// On a new computer whose person already uses BetterBudget, the ledger
  /// is brought from where it is: the folder it is stored in, or a backup.
  /// [LedgerScreen.startFrom] is what they answered before the key was
  /// typed, and goes straight to its dialog. Asked again until a ledger is
  /// here or the answer is to start empty: Cancel in the dialog comes back
  /// here, and setup has no other way to either.
  Future<void> _offerRestore() async {
    var from = widget.startFrom;
    var picked = widget.startPath;
    while (mounted) {
      final where = switch (from) {
        StartFrom.folder => _Where.folder,
        StartFrom.backup => _Where.backup,
        null => await _askWhereLedger(),
      };
      final path = from == null ? null : picked;
      from = null;
      picked = null;
      // Closed without an answer: asked at the next launch.
      if (where == null || !mounted) return;
      switch (where) {
        case _Where.empty:
          try {
            await db.setPreference(
              SetupKeys.backupOffer,
              SetupKeys.backupOfferNo,
            );
          } catch (e) {
            debugPrint('Keeping "Start empty" failed: $e');
          }
          return;
        case _Where.backup:
          if (await _restoreFrom(picked: path)) return;
        case _Where.folder:
          if (await _openLedgerInFolder(picked: path)) return;
      }
    }
  }

  Future<_Where?> _askWhereLedger() => showDialog<_Where>(
    context: context,
    builder: (context) {
      final t = context.t;
      return Dialog(
        backgroundColor: Mid.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Mid.rule),
        ),
        child: SizedBox(
          width: 480,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.startWhereTitle,
                  style: onest(17, weight: 600, letterSpacing: -0.2),
                ),
                const SizedBox(height: 14),
                WhereRow(
                  key: const ValueKey('offer-restore-open'),
                  title: t.startWhereBackup,
                  note: t.startWhereBackupNote,
                  onTap: () => Navigator.of(context).pop(_Where.backup),
                ),
                const SizedBox(height: 10),
                WhereRow(
                  key: const ValueKey('offer-restore-folder'),
                  title: t.startWhereFolder,
                  note: t.startWhereFolderNote,
                  onTap: () => Navigator.of(context).pop(_Where.folder),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: BarButton(
                    key: const ValueKey('offer-restore-empty'),
                    label: t.ledgerStartEmpty,
                    onTap: () => Navigator.of(context).pop(_Where.empty),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  /// Opens the ledger stored in a folder the person points to (Google
  /// Drive, OneDrive, Box, Dropbox), and keeps this computer on it: one
  /// pick. Offered while the ledger here is still empty, so nothing is
  /// asked about what it replaces. Resolves to whether a ledger was opened.
  Future<bool> _openLedgerInFolder({String? picked}) async {
    if (_restoring) return false;
    final t = context.t;
    var pointed = picked;
    if (pointed == null) {
      try {
        pointed = await getDirectoryPath(
          confirmButtonText: t.ledgerUseThisFolder,
        );
      } catch (e) {
        debugPrint('Folder dialog failed: $e');
        _showToast(t.ledgerCouldntOpenFileDialog);
        return false;
      }
    }
    if (pointed == null || !mounted) return false;
    // Not there: the wrong folder, or one the sync service is still
    // filling. Nothing is written into it. Nor is the app's own folder one
    // a ledger can be shared from.
    final folder = CloudFolder.folderWithLedger(pointed);
    if (folder == null ||
        await _cloud.folderOfLedger('$folder/${CloudFolder.fileName}') ==
            null) {
      _showToast(t.ledgerFolderNoLedger(_folderName(pointed)));
      return false;
    }
    if (!mounted) return false;
    final name = _folderName(folder);
    final file = File('$folder/${CloudFolder.fileName}');
    final RestoreCandidate candidate;
    try {
      candidate = await _backups.inspect(file.path, widget.clock());
    } on RestoreNeedsKeyException {
      _showToast(t.ledgerFolderWrongKey(name));
      return false;
    } on RestoreException catch (e) {
      _showToast(restoreProblem(t, e.problem));
      return false;
    } catch (e) {
      debugPrint('The folder’s ledger couldn’t be read: $e');
      _showToast(t.ledgerFolderCouldntOpen(name));
      return false;
    }
    if (!mounted) {
      await _backups.discard(candidate);
      return false;
    }
    final data = _data;
    return _finishRestore(
      candidate,
      folder,
      nothingHere:
          data == null ||
          (data.txns.isEmpty && data.balanceSheetAccounts.isEmpty),
    );
  }

  Future<void> _checkRecoveryKey() async {
    final check = widget.checkRecoveryKey;
    if (check == null) return;
    final ok = await showCheckRecoveryKeyDialog(context, check);
    if (ok && mounted) {
      setState(() => _keySaved = true);
      widget.onRecoveryKeyChecked?.call();
    }
  }

  /// Where the new-transaction row posts: the open account, or in All
  /// accounts the one picked in the row.
  int? get _entryAccountId => _all ? _entry.account?.id : _accountId;

  @override
  void dispose() {
    FocusManager.instance.removeListener(_keepKeys);
    _search.dispose();
    _searchFocus.dispose();
    _registerFocus.dispose();
    _hoveredStatus.dispose();
    _entry.payeeFocus.dispose();
    _toastTimer?.cancel();
    _toastGrace?.cancel();
    _reconcile?.dispose();
    _exit?.dispose();
    _phones?.cancel();
    _cloud.dispose();
    super.dispose();
  }

  /// A category typed that didn't exist yet is made in the same write as
  /// the row. Money coming into it is a refund: income is the app's own
  /// Income (rule 30).
  Future<int?> _makeCategory(EntryDraft d) async {
    final name = d.newCategory;
    if (name == null) return null;
    // Income's word in the other language is still Income.
    if (isIncomeName(name)) return db.incomeCategory();
    // A new spending category is in the currency of the account the row
    // is in (rule 28).
    final data = _data;
    final account = d.account ?? data?.accounts[_accountId];
    return db.createCategory(
      name,
      currency:
          account?.currency ??
          (data == null ? Currency.mnt : Budget.currencyOf(data)),
    );
  }

  /// Wraps an undo and redo so a category made with the row goes and comes
  /// back with it: one ⌘Z for both.
  /// Whether [payee] is already remembered as [categoryId] (and [payId]) on
  /// [accountId], by its own words or wider ones: then a row's box isn't
  /// offered.
  bool _rememberedSo(int? accountId, String payee, int categoryId, int? payId) {
    final data = _data;
    if (data == null || accountId == null) return false;
    final covering = PayeeRuleInfo.pick(
      data.payeeRules,
      accountId,
      payee,
      null,
    );
    return covering != null &&
        covering.categoryId == categoryId &&
        covering.payId == payId;
  }

  /// The box under a row was ticked and the row saved: the category is
  /// remembered for the payee in the same write. Undo and redo fold it in
  /// with the row's own.
  ({Future<void> Function() undo, Future<void> Function() redo}) _alsoRemember(
    ({PayeeRuleInfo? was, PayeeRuleInfo now})? remembered,
    Future<void> Function() undo,
    Future<void> Function() redo,
  ) => remembered == null
      ? (undo: undo, redo: redo)
      : (
          undo: () => db.transaction(() async {
            // The rule first: it may name a category the row's undo takes.
            if (remembered.was case final was?) {
              await db.putPayeeRule(was);
            } else {
              await db.removePayeeRule(remembered.now.id);
            }
            await undo();
          }),
          redo: () => db.transaction(() async {
            await redo();
            await db.putPayeeRule(remembered.now);
          }),
        );

  /// After a row was saved with its box ticked: the clause for the popup,
  /// and the offer to file the rows of that payee still in Not categorized.
  ({String said, ({String label, VoidCallback onTap})? more}) _rememberedWords(
    ({PayeeRuleInfo? was, PayeeRuleInfo now}) remembered,
  ) {
    final t = context.t;
    final data = _data;
    final rule = remembered.now;
    final label = data == null
        ? ''
        : _ruleLabel(t, data, rule, _payChoices(data));
    final waiting = data == null
        ? const <RegisterRow>[]
        : _waitingFor(data, rule);
    return (
      said: t.ledgerAlwaysFiled(0, label),
      more: waiting.isEmpty
          ? null
          : (
              label: t.payeesFileWaiting(waiting.length),
              onTap: () => _fileWaiting(rule, waiting, label),
            ),
    );
  }

  ({Future<void> Function() undo, Future<void> Function() redo}) _alsoCategory(
    int? made,
    Future<void> Function() undo,
    Future<void> Function() redo,
  ) => made == null
      ? (undo: undo, redo: redo)
      : (
          // Each in one write: a half-done undo would leave the row gone and
          // the category behind, or the reverse.
          undo: () => db.transaction(() async {
            await undo();
            _expect(await db.deleteEmptyAccount(made));
          }),
          redo: () => db.transaction(() async {
            await db.undeleteAccount(DeletedAccount(made, const []));
            await redo();
          }),
        );

  Future<String?> _post(EntryDraft d) async {
    final t = context.t;
    int? made;
    PayTaken? paycheck;
    ({PayeeRuleInfo? was, PayeeRuleInfo now})? remembered;
    try {
      late final int id;
      // One write: a crash between them can't leave an empty category.
      await db.transaction(() async {
        made = await _makeCategory(d);
        final here = d.account?.id ?? _accountId!;
        final other = d.otherAmount;
        final amount = d.amount!;
        id = other != null && d.counter != null
            // Between currencies: both sides, from the side money leaves.
            ? await db.postExchange(
                fromAccountId: amount < 0 ? here : d.counter!.id,
                toAccountId: amount < 0 ? d.counter!.id : here,
                sent: amount < 0 ? amount.abs() : other,
                received: amount < 0 ? other : amount.abs(),
                date: d.date,
                today: today,
                payee: d.payee,
                memo: d.memo,
              )
            : await db.postSimple(
                accountId: here,
                date: d.date,
                today: today,
                payee: d.payee,
                // The new-transaction row always supplies one or the other.
                counterAccountId: made ?? d.counter!.id,
                amount: amount,
                memo: (d.memo?.trim().isEmpty ?? true) ? null : d.memo!.trim(),
              );
        // A pay picked in Category: the row is its paycheck. One dated
        // ahead is only scheduled, and stays plain income until it comes.
        if (d.payId case final pay? when !d.date.isAfter(today)) {
          paycheck = await db.takeAsPay(
            transactionId: id,
            accountId: here,
            scheduleId: pay,
            today: today,
          );
        }
        // The box under the row: the category remembered for the payee.
        final category = made ?? d.counter?.id;
        if (d.remember && category != null && d.payee.trim().isNotEmpty) {
          remembered = await db.rememberPayee(
            accountId: here,
            payee: d.payee,
            categoryId: category,
            payId: d.payId,
          );
        }
      });
      _entry.payeeNames = await db.payeeNames();
      final taken = paycheck;
      final rowPair = _alsoCategory(
        made,
        () async {
          if (taken != null) await db.undoTakeAsPay(taken);
          _expect((await db.softDeleteMany([id])).length == 1);
        },
        () async {
          await db.restoreMany([id]);
          if (taken != null) await db.redoTakeAsPay(taken);
        },
      );
      final pair = _alsoRemember(remembered, rowPair.undo, rowPair.redo);
      final kept = remembered == null ? null : _rememberedWords(remembered!);
      // A row that won't show under the filter or search in force says where
      // it went, or it looks lost and gets typed again.
      final hidden =
          _search.text.trim().isNotEmpty ||
          (_all &&
              _categoryFilter != null &&
              (made ?? d.counter?.id) != _categoryFilter);
      final added = d.account == null
          ? t.ledgerAdded(d.payee)
          : t.ledgerAddedTo(d.payee, d.account!.name);
      _did(
        t.ledgerAdded(d.payee),
        undo: pair.undo,
        redo: pair.redo,
        toast: made != null || hidden || kept != null,
        detail: kept == null ? null : d.payee,
        more: kept?.more,
        // Whole clauses joined by " · ", as every toast is.
        message: made != null || hidden || kept != null
            ? [
                added,
                if (made != null) t.ledgerNewCategory(d.newCategory!),
                if (made != null && d.date.isAfter(today))
                  t.ledgerScheduledFor(sayFullDate(t, d.date)),
                if (kept != null) kept.said,
                if (hidden) t.ledgerNotInThisView,
              ].join(' · ')
            : null,
      );
      if (made == null && !hidden && kept == null && d.date.isAfter(today)) {
        _showToast(t.ledgerScheduledToast(sayFullDate(t, d.date)));
      }
      return null;
    } on DbException catch (e) {
      return t.ledgerCouldntSave(dbProblem(t, e));
    } catch (e) {
      return t.ledgerCouldntSave('$e');
    }
  }

  /// Records an undoable action. Toasts are for saved changes and deletes;
  /// quick clicks like clearing a row stay quiet and rely on ⌘Z.
  void _did(
    String label, {
    required Future<void> Function() undo,
    required Future<void> Function() redo,
    bool toast = true,
    String? message,
    String? detail,
    ({String label, VoidCallback onTap})? more,
  }) {
    final action = _Undoable(label, undo, redo, detail: detail);
    _history.add(action);
    _redo.clear();
    if (toast) {
      _showToast(
        message ?? label,
        detail: detail,
        more: more,
        undo: () async {
          // Undo runs newest first, so an older toast can't jump the queue:
          // restoring its state would silently wipe the newer changes.
          if (!identical(_history.lastOrNull, action)) {
            _showToast(
              context.t.ledgerUndoNewerFirst(_isMac ? '⌘Z' : 'Ctrl+Z'),
            );
            return;
          }
          await _undo();
        },
      );
    }
  }

  /// Throws when a database write changed less than undo or redo expected,
  /// usually because the row was locked or changed since.
  void _expect(bool ok) {
    if (!ok) throw StateError('changed since');
  }

  /// Undoes the newest action.
  Future<void> _undo() async {
    if (_restoring) return;
    final a = _history.lastOrNull;
    if (a == null) {
      _showToast(context.t.ledgerNothingToUndo);
      return;
    }
    _history.removeLast();
    try {
      await a.undo();
    } catch (e) {
      if (mounted) {
        _showToast(context.t.ledgerCouldntUndo(a.label), detail: a.detail);
      }
      return;
    }
    _redo.add(a);
    if (mounted) _showToast(context.t.ledgerUndone(a.label), detail: a.detail);
  }

  Future<void> _redoLast() async {
    if (_restoring) return;
    final a = _redo.lastOrNull;
    if (a == null) {
      _showToast(context.t.ledgerNothingToRedo);
      return;
    }
    _redo.removeLast();
    try {
      await a.redo();
    } catch (e) {
      if (mounted) {
        _showToast(context.t.ledgerCouldntRedo(a.label), detail: a.detail);
      }
      return;
    }
    _history.add(a);
    if (mounted) _showToast(context.t.ledgerRedone(a.label), detail: a.detail);
  }

  /// Why an entry row couldn't be saved, as a popup; gone once the row is
  /// edited, unless another popup has taken its place.
  void _entryProblem(String? message) {
    if (!mounted) return;
    if (message != null) {
      _showToast(message);
    } else if (_entryProblemShown != null &&
        _toast?.message == _entryProblemShown) {
      _closeToast();
    }
    _entryProblemShown = message;
  }

  void _showToast(
    String message, {
    String? detail,
    Future<void> Function()? undo,
    ({String label, VoidCallback onTap})? more,
  }) {
    _toastTimer?.cancel();
    _toastGrace?.cancel();
    _toastGrace = null;
    _toastDue = false;
    setState(
      () => _toast = (
        message: message,
        // A row with no payee has no line of its own.
        detail: detail == null || detail.trim().isEmpty ? null : detail,
        more: more == null
            ? null
            : (
                label: more.label,
                onTap: () {
                  _toastClicked();
                  more.onTap();
                },
              ),
        undo: undo == null
            ? null
            : () async {
                _toastClicked();
                await undo();
              },
      ),
    );
    // An offer takes longer to read than a report.
    _toastTimer = Timer(Duration(seconds: more == null ? 6 : 12), () {
      _toastDue = true;
      _toastMayLeave();
    });
    // It took the place of a popup the pointer was on (its Undo or its
    // offer was clicked, or ⌘Z pressed): it stays if the pointer is on it
    // too, so the next click can't land on the row beneath.
    if (_toastPointer case final at?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _toastPointer != at) return;
        final box = _toastKey.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.size.contains(box.globalToLocal(at))) {
          _toastPointerAt(null);
        }
      });
    }
  }

  /// The popup leaves when its time is up, the pointer is off it and has
  /// been for a little while.
  void _toastMayLeave() {
    if (!mounted || _toast == null) return;
    if (_toastDue && _toastPointer == null && _toastGrace == null) {
      _closeToast();
    }
  }

  void _closeToast() {
    _toastTimer?.cancel();
    _toastGrace?.cancel();
    _toastGrace = null;
    _toastPointer = null;
    _toastDue = false;
    if (_toast != null) setState(() => _toast = null);
  }

  /// A button on the popup was clicked: it goes, and the popup that
  /// reports the click is held to the pointer as this one was.
  void _toastClicked() {
    final at = _toastPointer;
    _closeToast();
    _toastPointer = at;
    // Only for the popup that follows at once.
    _toastGrace = Timer(const Duration(seconds: 2), () {
      _toastGrace = null;
      if (_toast == null) _toastPointer = null;
    });
  }

  /// The popup stays while the pointer is on it, so it can't go from under
  /// a click, and at least four seconds once the pointer leaves. Only a
  /// pointer that moved or clicked there holds it: one appearing under a
  /// pointer left in that corner leaves in its own time.
  void _toastPointerAt(Offset? at) {
    if (_toast == null) return;
    _toastPointer = at;
    _toastGrace?.cancel();
    _toastGrace = at != null
        ? null
        : Timer(const Duration(seconds: 4), () {
            _toastGrace = null;
            _toastMayLeave();
          });
  }

  /// True while a text field has focus. The focus node's own widget is the
  /// Focus inside EditableText, so look up the tree rather than at it.
  bool get _typing {
    final context = FocusManager.instance.primaryFocus?.context;
    return context != null &&
        (context.widget is EditableText ||
            context.findAncestorWidgetOfExactType<EditableText>() != null);
  }

  /// Single keys that act on selected rows. They must never be claimed while
  /// typing: returning `ignored` passes the key on to the text field.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final keys = HardwareKeyboard.instance;
    // ⌘Z / Ctrl+Z undoes the last action and ⌘⇧Z (Ctrl+Y or Ctrl+Shift+Z)
    // redoes it, except in a text field, where they act on typing.
    final command = _isMac ? keys.isMetaPressed : keys.isControlPressed;
    final z = event.logicalKey == LogicalKeyboardKey.keyZ;
    final undo = command && z && !keys.isShiftPressed;
    final redo =
        command &&
        ((z && keys.isShiftPressed) ||
            (!_isMac && event.logicalKey == LogicalKeyboardKey.keyY));
    if (_restoring) return KeyEventResult.handled;
    if (undo || redo) {
      if (_typing) return KeyEventResult.ignored;
      if (event is KeyDownEvent) undo ? _undo() : _redoLast();
      return KeyEventResult.handled;
    }
    // Esc closes a category's Edit on the Budget page, wherever the last
    // click was.
    if (_section == AppSection.budget &&
        !_typing &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        (_budgetKey.currentState?.closeEdit() ?? false)) {
      return KeyEventResult.handled;
    }
    // And a payee's Edit on the Payees page.
    if (_section == AppSection.payees &&
        !_typing &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        (_payeesKey.currentState?.closeEdit() ?? false)) {
      return KeyEventResult.handled;
    }
    // Esc closes setup's pay form, wherever the last click was.
    if (!_typing &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        (_setupKey.currentState?.closePayForm() ?? false)) {
      return KeyEventResult.handled;
    }
    // Row keys act on the register; elsewhere its selection is out of sight.
    if (_section != AppSection.ledger ||
        // Setup is over the register: its rows are out of sight.
        (_data != null && inSetup(_data!)) ||
        _typing ||
        keys.isMetaPressed ||
        keys.isControlPressed ||
        keys.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final row = _rows[_selected];
    if (row == null) {
      // Esc with nothing selected takes the category filter off.
      if (event.logicalKey == LogicalKeyboardKey.escape &&
          (_categoryFilter != null || _periodFilter != null) &&
          _all) {
        setState(() {
          _categoryFilter = null;
          _periodFilter = null;
        });
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.delete || LogicalKeyboardKey.backspace:
        _delete(row);
      // C: cleared ⇄ uncleared, as clicking the row's symbol does.
      case LogicalKeyboardKey.keyC:
        if (event is KeyRepeatEvent || row.scheduled) {
          return KeyEventResult.ignored;
        }
        _toggleCleared(row);
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
        if (_editing != null) return KeyEventResult.ignored;
        _startEdit(row.txnId, EditField.payee);
      case LogicalKeyboardKey.escape:
        _clearSelection();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ---------- selection ----------

  void _tapRow(int id, EditField field) {
    if (_editing != null) {
      if (_editing!.controller.isDirty()) {
        _showToast(context.t.ledgerSaveOrDiscard);
        return;
      }
      _cancelEdit();
    }

    final now = DateTime.now();
    final last = _lastTap;
    if (last != null &&
        last.id == id &&
        now.difference(last.at) < const Duration(milliseconds: 450)) {
      _lastTap = null;
      _startEdit(id, field);
      return;
    }
    _lastTap = (id: id, at: now);

    // Clicking a row leaves any text field, so Delete and C act on the row.
    _registerFocus.requestFocus();
    // Clicking the selected row again closes its actions.
    setState(() => _selected = _selected == id ? null : id);
  }

  void _clearSelection() => setState(() => _selected = null);

  /// From a forecast dot: show that scheduled transaction, selected.
  void _openScheduled(RegisterRow r) {
    // The register hides scheduled rows while reconciling, and keys would act
    // on a row nobody can see.
    if (_reconcile != null) {
      _showToast(context.t.ledgerFinishReconcileFirst);
      return;
    }
    if (_editing != null) {
      if (_editing!.controller.isDirty()) {
        _showToast(context.t.ledgerSaveOrDiscard);
        return;
      }
      _cancelEdit();
    }
    _search.clear();
    setState(() {
      _filter = RegisterFilter.scheduled;
      _selected = r.txnId;
    });
    _registerFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = _selectedKey.currentContext;
      if (row == null || !row.mounted) return;
      Scrollable.ensureVisible(
        row,
        alignment: 0.2,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _newEntry() {
    // Setup has no register to add a row to.
    if (_data case final d? when inSetup(d)) return;
    // On the Budget page, ⌘N adds a category (or pay on the Income tab),
    // not a ledger row somewhere else (interaction review, 2026-10-05).
    if (_section == AppSection.budget) {
      _budgetKey.currentState?.addNew();
      return;
    }
    // On the Payees page it adds a payee.
    if (_section == AppSection.payees) {
      _payeesKey.currentState?.addNew();
      return;
    }
    // One row open for typing at a time: an untouched Edit closes, one
    // with changes keeps the floor.
    if (_editing != null) {
      if (_editing!.controller.isDirty()) {
        _showToast(context.t.ledgerSaveOrDiscard);
        return;
      }
      _cancelEdit();
    }
    setState(() {
      _section = AppSection.ledger;
      _adding = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _entry.focus());
  }

  /// The payday after [row] by its pay plan, so the forecast can run
  /// through the whole period. Null for income typed by hand: it belongs
  /// to no plan.
  /// How far every forecast looks: the user's choice, kept in the ledger.
  ForecastSpan _span(LedgerData data) =>
      ForecastSpan.parse(data.prefs[ForecastSpan.prefKey]);

  /// An account's forecast, as its header shows it: through the next pay
  /// period, or to the date the chosen span ends on ([span] overrides the
  /// ledger's choice), with the paydays and plan bills after the scheduled
  /// ones projected that far.
  Forecast _forecastFor(
    LedgerData data,
    AccountInfo account, {
    ForecastSpan? span,
  }) {
    final scheduled = data.registerFor(account.id).scheduled;
    final until = (span ?? _span(data)).endFrom(today);
    return buildForecast(
      working: data.summaryFor(account.id).working,
      today: today,
      scheduled: scheduled,
      owed: account.isOwed,
      paydayAfter: (row) => _paydayAfter(data, row),
      payIsSetUp: data.paySchedules.isNotEmpty,
      until: until,
      projected: until == null
          ? const []
          : projectScheduled(
              scheduled,
              until: until,
              payById: data.payScheduleById,
              planOf: (id) => data.plans[id],
            ),
    );
  }

  /// The Source column was turned on or off: a view, kept quietly.
  Future<void> _setShowSource(bool on) async {
    try {
      // On is the ordinary state, so only off is kept.
      await db.setPreference(showSourceKey, on ? null : '0');
    } catch (e) {
      if (mounted) _showToast(context.t.ledgerCouldntSave('$e'));
    }
  }

  /// A computer or a phone was given a name (or had it cleared): [key] is
  /// the setting that holds it.
  Future<void> _nameSource(String key, String name) async {
    try {
      final v = name.trim();
      await db.setPreference(key, v.isEmpty ? null : v);
    } catch (e) {
      if (mounted) _showToast(context.t.ledgerCouldntSave('$e'));
    }
  }

  /// A computer that has no name yet is called what the system calls it,
  /// once, after the first look at the folder (a write before it would be a
  /// change made here). The person can rename it in Settings.
  Future<void> _nameThisComputer() async {
    try {
      final id = db.thisComputer;
      if (id == null) return;
      final key = '$computerNamePrefix$id';
      if (await db.preference(key) != null) return;
      await db.setPreference(key, await _cloud.access.computerName());
    } catch (e) {
      debugPrint('This computer couldn’t be named: $e');
    }
  }

  /// Each computer and each phone that has made a transaction here, by id,
  /// with the name the person (or the system) gave it, '' for none. This
  /// computer is always among the computers.
  ({Map<String, String> computers, Map<String, String> phones}) _sourcesOf(
    LedgerData data,
  ) {
    final computers = <String, String>{};
    final phones = <String, String>{};
    final here = db.thisComputer;
    if (here != null) {
      computers[here] = data.prefs['$computerNamePrefix$here'] ?? '';
    }
    for (final t in data.txns) {
      final on = t.madeOn;
      if (on == null) continue;
      if (t.madeHow == MadeHow.phone) {
        phones[on] = data.prefs['$phoneNamePrefix$on'] ?? '';
      } else if (MadeHow.onComputer(t.madeHow ?? '')) {
        computers[on] = data.prefs['$computerNamePrefix$on'] ?? '';
      }
    }
    return (computers: computers, phones: phones);
  }

  Widget _withSources(LedgerData data, Widget child) {
    final s = _sourcesOf(data);
    return SourceColumn(
      shown: data.prefs[showSourceKey] != '0',
      here: db.thisComputer,
      computers: s.computers,
      phones: s.phones,
      child: child,
    );
  }

  /// The forecast's span was picked: one choice for every account, kept
  /// quietly like the Budget page's period (a view, not a change to the
  /// ledger's money).
  Future<void> _setSpan(ForecastSpan span) async {
    try {
      await db.setPreference(ForecastSpan.prefKey, span.name);
    } catch (e) {
      if (mounted) _showToast(context.t.ledgerCouldntSave('$e'));
    }
    _keysBack();
  }

  /// The day an account's balance first goes to zero or below, and the
  /// balance that day, or null when it doesn't (or is below zero already,
  /// which its balance says). An account pay goes into is looked at a
  /// year of paychecks ahead, whatever span is on screen (the owner's
  /// "paychecks tracked for that account"); any other account only as far
  /// as its forecast shows, since nothing feeds it there but transfers
  /// (budget review, 2026-10-05).
  ({DateTime date, int low})? _shortAhead(LedgerData data, AccountInfo a) {
    if (a.isOwed) return null;
    final paidInto = data.paySchedules.any((p) => p.accountId == a.id);
    final f = paidInto
        ? _forecastFor(data, a, span: ForecastSpan.year)
        : _forecastFor(data, a);
    if (!f.isShort || f.shortNow) return null;
    return (date: f.firstShort!, low: f.firstShortBalance);
  }

  /// Accounts whose balance goes to zero or below within a year of
  /// paychecks, with the header's own warning for each: a dot beside the
  /// account in the sidebar says so from anywhere in the app (owner's
  /// request, 2026-10-05). One already below zero shows its balance in
  /// coral there instead.
  Map<int, String> _runsOut(LedgerData data) {
    // Worked out once per ledger snapshot (and language), not on every
    // hover or keystroke: it's a year's projection per account.
    final t = context.t;
    if (identical(_runsOutFor, data) && _runsOutWords == t) {
      return _runsOutCache;
    }
    _runsOutFor = data;
    _runsOutWords = t;
    return _runsOutCache = {
      for (final a in data.openAccounts)
        if (_shortAhead(data, a) case final s?)
          a.id: s.low == 0
              ? t.planRunsOutZero(sayDate(t, s.date))
              : t.planRunsOutBy(
                  sayDate(t, s.date),
                  roundedIn(context, s.low.abs()),
                ),
    };
  }

  LedgerData? _runsOutFor;
  Words? _runsOutWords;
  Map<int, String> _runsOutCache = const {};

  ({DateTime date, int amount})? _paydayAfter(
    LedgerData data,
    RegisterRow row,
  ) {
    final plan = data.paySchedules
        .where((p) => p.id == row.payScheduleId)
        .firstOrNull;
    if (plan == null) return null;
    // From the payday it was planned as, by amount for split pay: one moved
    // a few days by hand mustn't make that same payday the next.
    final next = plan.nextAfter(plan.plannedFor(row.date, paid: row.amount));
    return (date: next, amount: plan.amountOn(next));
  }

  /// Esc on the new-transaction row: it closes, and ⌘Z works again at
  /// once. The row drops focus on its way out, which left the screen's keys
  /// unreachable until a click.
  Widget _searchBox() => _SearchField(
    controller: _search,
    focusNode: _searchFocus,
    onChanged: () => setState(() {}),
  );

  void _closeEntry() {
    setState(() => _adding = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keysBack();
    });
  }

  // ---------- editing ----------

  /// With [confirming], a scheduled row opens to be confirmed: dated today,
  /// the amount selected (bills vary), and Enter confirms.
  void _startEdit(int id, EditField field, {bool confirming = false}) {
    final row = _rows[id];
    if (row == null) return;
    // The new-transaction row gives way the same way: closed when empty,
    // kept when it holds typing.
    if (_adding && _entry.isDirty()) {
      _showToast(context.t.ledgerSaveOrDiscard);
      return;
    }
    // Reconciled rows open too: payee, memo and category can still change.
    final controller =
        EntryRowController(
            onSubmit: (draft) => _saveEdit(row, draft, confirming: confirming),
            suggestCategory: (payee) =>
                db.suggestedCategory(payee, row.accountId),
          )
          ..payeeNames = _entry.payeeNames
          ..onProblem = _entryProblem
          ..remembered = (payee, category, pay) =>
              _rememberedSo(row.accountId, payee, category, pay);
    // The popup in the corner would lie over the Cancel and Save of a row
    // near the bottom; ⌘Z still undoes what it said.
    _closeToast();
    setState(() {
      _editing = (
        txnId: id,
        focus: field,
        controller: controller,
        confirming: confirming,
      );
      _selected = id;
      _adding = false;
    });
  }

  void _startConfirm(RegisterRow r) {
    if (_editing != null) {
      if (_editing!.controller.isDirty()) {
        _showToast(context.t.ledgerSaveOrDiscard);
        return;
      }
      _cancelEdit();
    }
    _startEdit(r.txnId, EditField.amount, confirming: true);
  }

  void _cancelEdit() {
    final editing = _editing;
    if (editing == null) return;
    setState(() {
      _editing = null;
      _pointed = null;
    });
    _registerFocus.requestFocus();
    // The row's widgets still hold the focus node until this frame ends.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => editing.controller.payeeFocus.dispose(),
    );
  }

  Future<String?> _saveEdit(
    RegisterRow row,
    EntryDraft d, {
    bool confirming = false,
  }) async {
    final t = context.t;
    final before = await db.snapshot(row.txnId);
    final TxnSnapshot after;
    final int? owedId;
    int? made;
    ({PayeeRuleInfo? was, PayeeRuleInfo now})? remembered;
    try {
      owedId = await db.transaction(() async {
        made = await _makeCategory(d);
        final owed = await db.editTransaction(
          transactionId: row.txnId,
          accountId: row.accountId,
          date: d.date,
          today: today,
          payee: d.payee,
          memo: d.memo,
          counterAccountId: made ?? d.counter?.id,
          amount: d.amount,
          counterAmount: d.otherAmount,
          confirm: confirming,
          keepOwed: d.keepOwed,
        );
        // The box under the row: the category remembered for the payee.
        final category = made ?? d.counter?.id;
        if (d.remember && category != null && d.payee.trim().isNotEmpty) {
          remembered = await db.rememberPayee(
            accountId: row.accountId,
            payee: d.payee,
            categoryId: category,
            payId: d.payId,
          );
        }
        return owed;
      });
    } on LockedException catch (e) {
      return dbProblem(t, e);
    } on DbException catch (e) {
      return t.ledgerCouldntSave(dbProblem(t, e));
    } catch (e) {
      return t.ledgerCouldntSave('$e');
    }
    // Saved: from here a failure mustn't read as "couldn't save".
    after = await db.snapshot(row.txnId);
    _entry.payeeNames = await db.payeeNames();
    _cancelEdit();
    final name = d.payee.isEmpty ? rowPayee(t, row) : d.payee;
    if (confirming) {
      String money(int v) => formatShort(
        v.abs(),
        currency: _data?.accounts[row.accountId]?.currency ?? Currency.mnt,
      );
      final amount = d.amount ?? row.amount;
      final early = row.date.isAfter(today);
      // A payday confirmed: its schedule's next one, from the plan; a
      // plan's bill confirmed: the plan's next one. Only its own:
      // confirming a bill never touches pay.
      var next = const <int>[];
      var nextBills = const <int>[];
      final schedule = row.payScheduleId;
      final planned = row.planCategoryId;
      if (schedule != null) {
        try {
          next = await db.ensurePaydays(today, only: schedule);
        } catch (e) {
          debugPrint('Scheduling the next payday failed: $e');
        }
      }
      if (planned != null) {
        try {
          nextBills = await db.ensurePlanBills(today, only: planned);
        } catch (e) {
          debugPrint('Scheduling the next bill failed: $e');
        }
      }
      final pair = _alsoCategory(
        made,
        // One action: the confirm, any rest still owed and the next payday
        // or bill come and go together.
        () => db.transaction(() async {
          await db.dropPaydays(next);
          await db.dropPlanBills(nextBills);
          await db.restoreSnapshot(before);
          if (owedId case final id?) {
            _expect((await db.softDeleteMany([id])).length == 1);
          }
        }),
        () => db.transaction(() async {
          await db.restoreSnapshot(after);
          if (owedId case final id?) await db.restoreMany([id]);
          if (schedule != null) await db.bringBackPaydays(next, schedule);
          if (planned != null) {
            await db.bringBackPlanBills(nextBills, planned);
          }
        }),
      );
      // Under an estimate is the direction that hurts: said once, here.
      final under = row.estimate == null || amount >= row.estimate!
          ? null
          : row.estimate! - amount;
      final when = early ? 'early' : 'other';
      _did(
        t.ledgerConfirmed(name),
        undo: pair.undo,
        redo: pair.redo,
        message: [
          // What's still owed, or else the plan when it wasn't what happened.
          if (owedId == null && amount != row.amount)
            t.ledgerConfirmedAmountPlanned(
              when,
              name,
              money(amount),
              money(row.amount),
            )
          else
            t.ledgerConfirmedAmount(when, name, money(amount)),
          if (owedId != null)
            t.ledgerStillOwed(money(row.amount - amount), sayDate(t, row.date)),
          // The date, whenever it isn't the one planned.
          if (d.date != row.date)
            d.date == today
                ? t.ledgerPostedToday(sayDate(t, today))
                : t.ledgerPostedOn(sayDate(t, d.date)),
          if (under != null) t.ledgerUnderEstimate(money(under)),
        ].join(' · '),
      );
      return null;
    }
    final nowScheduled = !row.scheduled && d.date.isAfter(today);
    final rowPair = _alsoCategory(
      made,
      () => db.restoreSnapshot(before),
      () => db.restoreSnapshot(after),
    );
    final pair = _alsoRemember(remembered, rowPair.undo, rowPair.redo);
    final kept = remembered == null ? null : _rememberedWords(remembered!);
    _did(
      t.ledgerEdited(name),
      undo: pair.undo,
      redo: pair.redo,
      detail: kept == null ? null : d.payee,
      more: kept?.more,
      // Whole clauses joined by " · ", as every toast is.
      message: [
        nowScheduled
            ? t.ledgerMovedToFuture(sayFullDate(t, d.date))
            : t.ledgerChangesSaved,
        if (made != null) t.ledgerNewCategory(d.newCategory!),
        if (kept != null) kept.said,
      ].join(' · '),
    );
    return null;
  }

  // ---------- reconcile ----------

  void _startReconcile(LedgerData data, AccountInfo account) {
    if (_editing != null) {
      if (_editing!.controller.isDirty()) {
        _showToast(context.t.ledgerSaveOrDiscard);
        return;
      }
      _cancelEdit();
    }
    _reconcile?.dispose();
    final session = ReconcileSession(
      accountId: account.id,
      owed: account.isOwed,
      today: today,
      currency: account.currency,
    );
    // The register shows rows through the statement date as it's typed.
    session.date.addListener(() {
      if (mounted && _reconcile == session) setState(() {});
    });
    setState(() {
      _reconcile = session;
      _selected = null;
      _adding = false;
    });
    // The register holds focus, so the field's autofocus wouldn't take it.
    // The bank's number is what comes next.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_reconcile == session) session.balanceFocus.requestFocus();
    });
  }

  void _endReconcile() {
    final s = _reconcile;
    if (s == null) return;
    setState(() => _reconcile = null);
    _registerFocus.requestFocus();
    // The panel's fields still hold the controllers until this frame ends.
    WidgetsBinding.instance.addPostFrameCallback((_) => s.dispose());
  }

  ReconcileCheck _reconcileCheck(LedgerData data, AccountSummary summary) {
    final t = context.t;
    final s = _reconcile!;
    final date = parseEntryDate(s.date.text, today);
    final last = summary.reconciledOn;
    final problem = date == null
        // The form to type, so numeric in both languages.
        ? t.ledgerTypeADate(shortDate(today))
        : date.isAfter(today)
        ? t.ledgerStatementAfterToday
        : last != null && date.isBefore(last)
        ? t.ledgerAlreadyReconciled(sayDate(t, last))
        : null;
    final cleared = data.clearedThrough(s.accountId, date ?? today);
    final statement = s.statementBalance;
    return (
      date: date,
      dateProblem: problem,
      statement: statement,
      cleared: cleared.balance,
      toLock: cleared.toLock,
      hint: date == null || statement == null
          ? null
          : data.reconcileHint(s.accountId, date, statement - cleared.balance),
    );
  }

  /// With [adjust], a difference is posted as a "Reconcile adjustment" first.
  Future<void> _lockReconcile(
    AccountInfo account,
    ReconcileCheck c, {
    bool adjust = false,
  }) async {
    final t = context.t;
    final s = _reconcile;
    if (s == null || _locking || c.date == null || c.statement == null) return;
    final ReconcileRecord done;
    _locking = true;
    try {
      done = await db.reconcile(
        accountId: s.accountId,
        statementDate: c.date!,
        today: today,
        balance: c.statement!,
        adjust: adjust,
      );
    } on ReconcileMismatchException {
      _showToast(t.ledgerClearedRowsChanged);
      return;
    } on ReconcileDateException catch (e) {
      _showToast(dbProblem(t, e));
      return;
    } finally {
      _locking = false;
    }
    _endReconcile();
    final n = done.entryIds.length - (done.adjustmentTxnId == null ? 0 : 1);
    final off = c.statement! - c.cleared;
    final shownOff = account.isOwed ? -off : off;
    final label = t.ledgerReconciledThrough(account.name, sayDate(t, c.date!));
    _did(
      label,
      undo: () => db.unreconcile(done),
      redo: () => db.relock(done),
      message: [
        label,
        if (n != 0) t.ledgerLocked(n),
        if (done.adjustmentTxnId != null)
          t.ledgerAdjustmentAdded(
            formatShort(shownOff.abs(), currency: account.currency),
          ),
      ].join(' · '),
    );
  }

  // ---------- actions ----------

  Future<void> _toggleCleared(RegisterRow r) async {
    final next = r.cleared == Cleared.uncleared
        ? Cleared.cleared
        : Cleared.uncleared;
    final previous = await db.setClearedMany({r.entryId: next});
    if (previous.isEmpty) return;
    // The symbol changing is the confirmation; no toast.
    if (!mounted) return;
    _did(
      next == Cleared.cleared
          ? context.t.ledgerMarkedCleared(rowPayee(context.t, r))
          : context.t.ledgerMarkedUncleared(rowPayee(context.t, r)),
      undo: () async => _expect(
        (await db.setClearedMany(previous)).length == previous.length,
      ),
      redo: () async =>
          _expect((await db.setClearedMany({r.entryId: next})).length == 1),
      toast: false,
    );
  }

  String _lockMessage(RegisterRow r) => r.lockedIn != null
      ? context.t.ledgerCantDeleteTransfer(r.lockedIn!)
      : context.t.ledgerCantDeleteReconciled;

  Future<void> _delete(RegisterRow r) async {
    final deleted = await db.softDeleteMany([r.txnId]);
    if (!mounted) return;
    if (deleted.isEmpty) {
      _showToast(_lockMessage(r));
      return;
    }
    _clearSelection();
    _did(
      context.t.ledgerDeleted(rowPayee(context.t, r)),
      undo: () async {
        await db.restoreMany(deleted);
        if (mounted) setState(() => _selected = r.txnId);
      },
      redo: () async =>
          _expect((await db.softDeleteMany(deleted)).length == deleted.length),
    );
  }

  /// Outlines [found], the row a bill's "Already in this account" line names,
  /// and scrolls just far enough to see it: it can be a screen or more down
  /// the list, where rows aren't built until they're near.
  Future<void> _pointTo(RegisterRow found) async {
    setState(() => _pointed = found.txnId);
    final open = _selectedKey.currentContext;
    final position = open == null ? null : Scrollable.maybeOf(open)?.position;
    if (position == null) return;
    for (var i = 0; i < 60; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || _pointed != found.txnId) return;
      final row = _pointedKey.currentContext;
      if (row != null && row.mounted) {
        await Scrollable.ensureVisible(
          row,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
        return;
      }
      if (position.pixels >= position.maxScrollExtent) return;
      final next = position.pixels + position.viewportDimension * 0.8;
      position.jumpTo(
        next > position.maxScrollExtent ? position.maxScrollExtent : next,
      );
    }
  }

  /// Confirming [r] would put a bill in twice: [found] is it, already in.
  /// The scheduled one goes instead, and the next of its plan or pay is
  /// scheduled as a confirm would, all one action.
  Future<void> _alreadyIn(RegisterRow r, RegisterRow found) async {
    final t = context.t;
    final deleted = await db.softDeleteMany([r.txnId]);
    if (!mounted) return;
    if (deleted.isEmpty) {
      _showToast(_lockMessage(r));
      return;
    }
    _cancelEdit();
    _clearSelection();
    var nextBills = const <int>[];
    final planned = r.planCategoryId;
    // A category's bill: the row in that category is the bill paid, so the
    // plan counts it and the next bill doesn't find it again.
    final tie =
        planned != null &&
        found.planCategoryId == null &&
        found.categoryId == planned;
    if (planned != null) {
      try {
        if (tie) await db.setPlanBill(found.txnId, planned);
        nextBills = await db.ensurePlanBills(today, only: planned);
      } catch (e) {
        debugPrint('Scheduling the next bill failed: $e');
      }
    }
    if (!mounted) return;
    final short = r.amount.abs() - found.amount.abs();
    _did(
      t.ledgerScheduledDeleted(rowPayee(t, r)),
      undo: () => db.transaction(() async {
        await db.dropPlanBills(nextBills);
        if (tie) await db.setPlanBill(found.txnId, null);
        await db.restoreMany(deleted);
      }),
      redo: () => db.transaction(() async {
        _expect((await db.softDeleteMany(deleted)).length == deleted.length);
        if (tie) await db.setPlanBill(found.txnId, planned);
        if (planned != null) await db.bringBackPlanBills(nextBills, planned);
      }),
      message: short > 0
          ? t.ledgerScheduledDeletedShort(
              rowPayee(t, r),
              formatShort(short, currency: r.currency),
            )
          : t.ledgerScheduledDeletedAlreadyIn(
              rowPayee(t, r),
              sayDate(t, found.date),
            ),
    );
  }

  /// Moves a row entered in the wrong account. It leaves this register, so
  /// the toast names where it went.
  Future<void> _move(RegisterRow r, AccountInfo from, AccountInfo to) async {
    final t = context.t;
    final MoveRecord done;
    try {
      done = await db.moveToAccount(
        transactionId: r.txnId,
        fromAccountId: from.id,
        toAccountId: to.id,
      );
    } on LockedException catch (e) {
      _showToast(t.ledgerCantMove(dbProblem(t, e)));
      return;
    } on NotFoundException catch (e) {
      _showToast(t.ledgerCantMove(dbProblem(t, e)));
      return;
    } catch (e) {
      debugPrint('Move failed: $e');
      _showToast(t.ledgerCouldntMove);
      return;
    }
    _clearSelection();
    final payee = rowPayee(t, r);
    final label = r.kind != RowKind.transfer
        ? t.ledgerMovedTo(payee, to.name)
        : r.amount < 0
        ? t.ledgerTransferToMovedTo(payee, to.name)
        : t.ledgerTransferFromMovedTo(payee, to.name);
    _did(
      label,
      undo: () => db.undoMove(done),
      redo: () => db.redoMove(done),
      message: r.cleared == Cleared.uncleared
          ? label
          : '$label · ${t.ledgerUnclearedThere}',
      // It left this register: one click to where it went.
      more: (
        label: t.ledgerShowMoved,
        onTap: () => _showIn(to.id, r.txnId, scheduled: r.scheduled),
      ),
    );
  }

  /// Leaving the view: an edit with changes stops it, as clicking another
  /// row does; otherwise the editor closes. False means stay.
  bool _mayLeave() {
    final e = _editing;
    if (e == null) return true;
    if (e.controller.isDirty()) {
      _showToast(context.t.ledgerSaveOrDiscard);
      return false;
    }
    _cancelEdit();
    return true;
  }

  /// One account's register, from anywhere: the sidebar, a rename, a new or
  /// unarchived account.
  void _openAccount(int id) {
    if (!_mayLeave()) return;
    setState(() {
      if (id != _accountId || _all) _endReconcile();
      _section = AppSection.ledger;
      _newAccount = false;
      _all = false;
      _accountId = id;
      _selected = null;
    });
  }

  /// [accountId]'s register with row [txnId] chosen and in sight.
  /// A [scheduled] one is shown in the Scheduled tab: All draws only the
  /// next of them.
  void _showIn(int accountId, int txnId, {bool scheduled = false}) {
    _openAccount(accountId);
    if (_accountId != accountId || _all) return;
    _search.clear();
    setState(() {
      _filter = scheduled ? RegisterFilter.scheduled : RegisterFilter.all;
      _selected = txnId;
    });
    _registerFocus.requestFocus();
    // Two frames: the new register is built on the first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final row = _selectedKey.currentContext;
        if (row == null || !row.mounted) return;
        Scrollable.ensureVisible(row, alignment: 0.2);
      });
    });
  }

  // ---------- pay ----------

  /// Opens the pay setup: from the forecast's "Add your pay", or Settings.
  /// [existing] edits one.
  Future<void> _openPaySetup({
    AccountInfo? account,
    PaySchedule? existing,
  }) async {
    final t = context.t;
    final data = _data;
    if (data == null) return;
    final income = data.income;
    final into = data.openAccounts.where((a) => !a.isOwed).toList();
    // Income may not be there yet: a new ledger makes it with the first pay.
    if (into.isEmpty) {
      _showToast(t.ledgerAddBankAccountFirst);
      return;
    }
    AccountInfo? byId(List<AccountInfo> from, int? id) =>
        from.where((a) => a.id == id).firstOrNull;
    final result = await showDialog<PaySetupResult>(
      context: context,
      builder: (_) => _PaySetupDialog(
        form: (onResult, onCancel) => _PayForm(
          accounts: into,
          category: income,
          account:
              byId(into, existing?.accountId ?? account?.id ?? _accountId) ??
              into.first,
          today: today,
          existing: existing,
          history: (a, payee) =>
              db.payHistory(a, scheduleId: existing?.id, payee: payee),
          data: data,
          perPay: _perPay(data, existing),
          offerNoPay:
              data.paySchedules.isEmpty && data.prefs[noRegularPayKey] == null,
          onResult: onResult,
          onCancel: onCancel,
        ),
      ),
    );
    if (result == null || !mounted) return;
    await _applyPay(result, existing: existing);
  }

  /// Categories whose plan is per [existing]; stopping it asks where they go.
  static List<AccountInfo> _perPay(LedgerData data, PaySchedule? existing) => [
    if (existing != null)
      for (final c in data.categories)
        if (data.plans[c.id]?.payScheduleId == existing.id) c,
  ];

  /// What the pay form answered, written with its undo. Setup passes
  /// [toast] false: there the pay appearing on the page is the confirmation.
  /// False when the write failed, which a toast has said.
  Future<bool> _applyPay(
    PaySetupResult result, {
    PaySchedule? existing,
    bool toast = true,
  }) async {
    final t = context.t;
    final data = _data;
    if (data == null) return false;
    late PayChange change;
    switch (result) {
      case PayNone():
        await _setNoRegularPay(true, toast: toast);
      case PayStop(:final movePlans, :final moveTo):
        // The categories per this pay go where the dialog said: another
        // pay's periods, or the month; one undo with the stop.
        final moved = <int, CategoryPlan>{};
        if (movePlans) {
          final next = existing!.nextAfter(today);
          for (final p in data.plans.values) {
            if (p.payScheduleId == existing.id) {
              moved[p.categoryId] = p.movedToPay(moveTo, nextPayday: next);
            }
          }
        }
        final planChanges = <int, PlanChange>{};
        if (!await _accountWrite(() async {
          change = await db.stopPaySchedule(existing!.id, today);
          for (final e in moved.entries) {
            planChanges[e.key] = await db.changeCategoryPlan(
              e.key,
              e.value,
              today,
            );
          }
        }, what: 'pay')) {
          return false;
        }
        final movedTo = moved.isEmpty
            ? null
            : moveTo == null
            ? t.planRepeatMonths(1)
            : t.planEveryPayPeriodOf(
                payTitle(t, data, data.payScheduleById(moveTo)!),
              );
        _did(
          t.ledgerPayStopped,
          toast: toast,
          message: movedTo == null
              ? t.ledgerPayStoppedToast
              : t.ledgerPayStoppedMoved(moved.length, movedTo),
          undo: () async {
            for (final e in planChanges.entries) {
              await db.undoPlanChange(e.key, e.value);
            }
            await db.undoPayChange(change);
          },
          redo: () async {
            await db.redoPayChange(change);
            for (final e in planChanges.entries) {
              await db.redoPlanChange(e.key, moved[e.key], e.value);
            }
          },
        );
      case PaySave(:final draft):
        if (!await _accountWrite(
          () async => change = await db.savePaySchedule(
            id: existing?.id,
            accountId: draft.accountId,
            name: draft.name,
            payee: draft.payee,
            amount: draft.amount,
            amount2: draft.amount2,
            varies: draft.varies,
            rule: draft.rule,
            day1: draft.day1,
            day2: draft.day2,
            weeks: draft.weeks,
            anchor: draft.anchor,
            weekend: draft.weekend,
            // The Budget page's view is chosen there; editing a pay
            // leaves it as it is.
            definesPeriod: existing?.definesPeriod ?? false,
            today: today,
          ),
          what: 'pay',
        )) {
          return false;
        }
        // Pay added after "I don't have regular pay": the saying no longer
        // holds, so stopping this pay later asks again. Undone together.
        final wasNone = existing == null ? data.prefs[noRegularPayKey] : null;
        if (wasNone != null) await db.setPreference(noRegularPayKey, null);
        final next = await db.loadLedger();
        final payday = next.txns
            .where((t) => change.created.contains(t.id))
            .firstOrNull;
        _did(
          t.ledgerPaySaved,
          toast: toast,
          message: [
            payday == null
                ? t.ledgerPaySaved
                : t.ledgerPaySavedNext(sayFullDate(t, payday.date)),
            // Said, since it's the user's own row that went.
            if (change.replaced.isNotEmpty)
              t.ledgerPayReplaced(change.replaced.length),
          ].join(' · '),
          undo: () async {
            await db.undoPayChange(change);
            if (wasNone != null) {
              await db.setPreference(noRegularPayKey, wasNone);
            }
          },
          redo: () async {
            await db.redoPayChange(change);
            if (wasNone != null) {
              await db.setPreference(noRegularPayKey, null);
            }
          },
        );
    }
    return true;
  }

  /// "I don't have regular pay" (from the pay setup), or asking again
  /// (Settings). Only the asking changes: "Add your pay" stays in Settings.
  Future<void> _setNoRegularPay(bool none, {bool toast = true}) async {
    final t = context.t;
    final old = _data?.prefs[noRegularPayKey];
    final value = none ? '1' : null;
    if (old == value) return;
    try {
      await db.setPreference(noRegularPayKey, value);
    } catch (e) {
      _showToast(t.ledgerCouldntSave('$e'));
      return;
    }
    _did(
      none ? t.ledgerNoRegularPay : t.ledgerAskingForPayAgain,
      toast: toast,
      message: none ? t.ledgerNoRegularPayToast : t.ledgerAskForPayAgainToast,
      undo: () => db.setPreference(noRegularPayKey, old),
      redo: () => db.setPreference(noRegularPayKey, value),
    );
  }

  /// Light, dark or the system's. Kept on this computer, not in the ledger;
  /// no toast, the whole window changing says it happened. ⌘Z switches back.
  void _setAppearance(AppearanceController c, Appearance a) {
    final before = c.value;
    if (a == before) return;
    c.set(a);
    final t = context.t;
    _did(
      t.ledgerAppearanceUndoLabel(switch (a) {
        Appearance.system =>
          _isMac ? t.languageSameAsMac : t.languageSameAsWindows,
        Appearance.light => t.ledgerAppearanceLight,
        Appearance.dark => t.ledgerAppearanceDark,
      }),
      toast: false,
      undo: () => c.set(before),
      redo: () => c.set(a),
    );
  }

  /// A color scheme, kept on this computer like the appearance; no toast,
  /// the whole window changing says it happened. ⌘Z goes back.
  void _setScheme(AppearanceController c, Scheme s) {
    final before = c.scheme;
    if (s.id == before.id) return;
    c.setScheme(s);
    _did(
      context.t.appearanceColorsUndoLabel(schemeName(context.t, s)),
      toast: false,
      undo: () => c.setScheme(before),
      redo: () => c.setScheme(s),
    );
  }

  /// English, Mongolian or the system's. Kept on this computer like the
  /// appearance; no toast, every word changing says it happened. ⌘Z switches
  /// back.
  void _setLanguage(LanguageController c, Language l) {
    final before = c.value;
    if (l == before) return;
    c.set(l);
    final t = context.t;
    _did(
      t.languageUndoLabel(switch (l) {
        Language.system =>
          _isMac ? t.languageSameAsMac : t.languageSameAsWindows,
        Language.english => t.languageEnglish,
        Language.mongolian => t.languageMongolian,
      }),
      toast: false,
      undo: () => c.set(before),
      redo: () => c.set(l),
    );
  }

  /// The Budget page viewed by month, or by [schedule]'s pay periods (the
  /// dropdown beside the period; owner, 2026-10-05). A view, so no toast;
  /// ⌘Z still puts the last one back.
  Future<void> _budgetBy(PaySchedule? schedule) async {
    final t = context.t;
    // The view it already is: nothing to write or undo.
    if (schedule?.id == _data?.periodSchedule?.id) return;
    late List<int> before;
    if (!await _accountWrite(
      () async => before = await db.setPeriodSchedule(schedule?.id),
      what: 'budget period',
    )) {
      return;
    }
    _did(
      schedule == null
          ? t.ledgerBudgetByMonth
          : t.ledgerBudgetByPayPeriod(payTitle(t, _data!, schedule)),
      toast: false,
      undo: () async {
        await db.setPeriodSchedule(before.firstOrNull);
      },
      redo: () async {
        await db.setPeriodSchedule(schedule?.id);
      },
    );
  }

  // ---------- all accounts ----------

  /// All accounts, optionally narrowed to a category and a budget period
  /// (from the Budget screen).
  void _openAll({int? category, BudgetSpan? period}) {
    if (!_mayLeave()) return;
    setState(() {
      _endReconcile();
      _section = AppSection.ledger;
      _newAccount = false;
      _all = true;
      _categoryFilter = category;
      _periodFilter = period;
      _selected = null;
      _adding = false;
      // Each visit starts new rows in the account last open, so a pick from
      // days ago doesn't quietly carry on; within a batch it stays.
      _entry.account = null;
    });
  }

  /// The "Not categorized" category, for the register's tab.
  int? _uncategorizedId(LedgerData data) =>
      data.categories.where(isUncategorized).firstOrNull?.id;

  Widget _allBody(LedgerData data) {
    final t = context.t;
    final filter = data.accounts[_categoryFilter];
    final all = data.registerAll(categoryId: filter?.id);
    // A budget period: a month, or a pay period.
    final period = _periodFilter;
    bool inPeriod(RegisterRow r) =>
        period == null ||
        (!r.date.isBefore(period.start) && !r.date.isAfter(period.end));
    final register = (
      posted: all.posted.where(inPeriod).toList(),
      scheduled: all.scheduled.where(inPeriod).toList(),
    );
    _rows = {
      for (final r in [...register.posted, ...register.scheduled]) r.txnId: r,
    };
    if (!_rows.containsKey(_selected)) _selected = null;
    if (_editing != null && !_rows.containsKey(_editing!.txnId)) {
      _editing = null;
    }
    final open = data.openAccounts;
    // A new row starts in the account last open, then stays on the last one
    // picked. By id: every snapshot has fresh AccountInfo objects.
    AccountInfo? openById(int? id) => open.where((a) => a.id == id).firstOrNull;
    _entry.account =
        openById(_entry.account?.id) ??
        openById(_accountId) ??
        open.firstOrNull;
    AccountInfo accountOf(RegisterRow r) => data.accounts[r.accountId]!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                t.ledgerAllAccounts,
                style: onest(22, weight: 600, letterSpacing: -0.3),
              ),
            ],
          ),
          if (filter != null || period != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (filter != null) ...[
                  _FilterChip(
                    key: const ValueKey('filter-chip'),
                    label: t.ledgerCategoryChip(filter.name),
                    onClear: () => setState(() => _categoryFilter = null),
                  ),
                  const SizedBox(width: 8),
                ],
                if (period != null) ...[
                  _FilterChip(
                    key: const ValueKey('period-chip'),
                    label: t.ledgerPeriodChip(
                      _spanName(t, period, today),
                      shortDate(period.start),
                      shortDate(period.end),
                    ),
                    onClear: () => setState(() => _periodFilter = null),
                  ),
                  const SizedBox(width: 8),
                ],
                const SizedBox(width: 6),
                if (filter != null)
                  Text(
                    _filterTotal(t, data, filter, register, period),
                    key: const ValueKey('filter-total'),
                    style: onest(13, color: Mid.ink2, tabular: true),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: RegisterPanel(
              owed: false,
              accountName: null,
              posted: register.posted,
              scheduled: register.scheduled,
              reconcileThrough: null,
              filter:
                  _filter == RegisterFilter.cleared ||
                      _filter == RegisterFilter.reconciled
                  ? RegisterFilter.all
                  : _filter,
              uncategorizedId: _uncategorizedId(data),
              uncategorizedFrom: budgetPeriod(today, data.periodSchedule).start,
              uncategorizedTo: budgetPeriod(today, data.periodSchedule).end,
              search: _search.text,
              selected: _selected,
              selectedKey: _selectedKey,
              editing: _editing,
              hoveredStatus: _hoveredStatus,
              categories: data.knownCategories,
              transferTargets: open,
              allAccounts: data.accounts,
              unclearedCheck: data.unclearedCheck,
              pointed: _pointed,
              pointedKey: _pointedKey,
              entryController: _entry,
              today: today,
              adding: _adding,
              searchBox: _searchBox(),
              addButton: _PrimaryButton(
                label: t.ledgerAdd,
                icon: Icons.add_rounded,
                key: const ValueKey('add-transaction'),
                onTap: _newEntry,
              ),
              onCloseEntry: _closeEntry,
              actions: RegisterActions(
                onFilter: (f) => setState(() => _filter = f),
                onRowTap: _tapRow,
                onToggleCleared: _toggleCleared,
                onConfirm: _startConfirm,
                onAlreadyIn: _alreadyIn,
                onPoint: _pointTo,
                onSetCategory: (r, c) => _setCategory(r, c),
                onDelete: _delete,
                onClearSelection: _clearSelection,
                onEdit: (r) => _startEdit(r.txnId, EditField.payee),
                onCancelEdit: _cancelEdit,
                onUnreconcile: (r) => _unreconcile(accountOf(r)),
                onMove: (r, to) => _move(r, accountOf(r), to),
                pays: _payChoices(data),
                onSetPay: _setPay,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "2 rows · ₮276,650.50 spent since 2026.08.31 · 1 scheduled": the rows
  /// the total covers (posted), the span, and scheduled apart since they
  /// aren't in it. More back than spent reads as refunded.
  String _filterTotal(
    Words t,
    LedgerData data,
    AccountInfo c,
    ({List<RegisterRow> posted, List<RegisterRow> scheduled}) register,
    ({DateTime start, DateTime end, String label})? period,
  ) {
    final posted = register.posted.length;
    final totals = data.categoryTotals(
      c.id,
      from: period?.start,
      to: period?.end,
    );
    // Each currency on its own, each with its own words: a dollar refund
    // beside tugrik spending reads as a refund.
    String kindOf(int v) => c.isIncome
        ? (v >= 0 ? 'received' : 'paidBack')
        : (v >= 0 ? 'spent' : 'refunded');
    String money(MapEntry<Currency, int> e) =>
        formatShort(e.value.abs(), currency: e.key);
    final parts = totals.entries.toList();
    // With a period chip the span is on the chip; all time says since when,
    // once, after the last.
    final since = period != null || register.posted.isEmpty
        ? null
        : sayFullDate(t, register.posted.first.date);
    final what = [
      for (final (i, e) in parts.indexed)
        since != null && i == parts.length - 1
            ? t.ledgerFilterTotalSince(kindOf(e.value), money(e), since)
            : t.ledgerFilterTotal(kindOf(e.value), money(e)),
    ].join(' · ');
    final sched = register.scheduled.length;
    return [
      t.ledgerFilterRows(posted),
      what,
      if (sched != 0) t.ledgerFilterScheduled(sched),
    ].join(' · ');
  }

  /// A row's category from its inline menu, in whichever account it's in.
  Future<void> _setCategory(RegisterRow r, AccountInfo c) async {
    final t = context.t;
    final payee = rowPayee(t, r);
    final previous = await db.setCategoryMany(
      transactionIds: [r.txnId],
      accountId: r.accountId,
      categoryId: c.id,
    );
    if (previous.isEmpty) return;
    _did(
      t.ledgerFiledUnder(c.name),
      detail: payee,
      more: _alwaysOffer(r, c),
      undo: () async => _expect(
        (await db.restoreCategories(previous, r.accountId)).length ==
            previous.length,
      ),
      redo: () async => _expect(
        (await db.setCategoryMany(
              transactionIds: [r.txnId],
              accountId: r.accountId,
              categoryId: c.id,
            )).length ==
            1,
      ),
    );
  }

  /// Each pay as the category dropdown names it.
  List<({int id, int accountId, String label})> _payChoices(
    LedgerData data, {
    int? into,
  }) {
    final t = context.t;
    return [
      for (final p in data.paySchedules)
        if (into == null || p.accountId == into)
          (id: p.id, accountId: p.accountId, label: _payLabel(t, data, p)),
    ];
  }

  String _payLabel(Words t, LedgerData data, PaySchedule p) {
    final title = payTitle(t, data, p);
    return title == t.ledgerIncome
        ? t.rowsIncomePaycheck
        : t.rowsIncomeFrom(title);
  }

  /// A pay picked from a row's dropdown: the row is that pay's paycheck
  /// (owner, 2026-10-06). The Income tab counts it as received and the
  /// payday it stands for stops being expected.
  Future<void> _setPay(RegisterRow r, int payId) async {
    final t = context.t;
    final data = _data;
    final pay = data?.payScheduleById(payId);
    final income = data?.income;
    if (data == null || pay == null || income == null) return;
    final PayTaken taken;
    try {
      taken = await db.takeAsPay(
        transactionId: r.txnId,
        accountId: r.accountId,
        scheduleId: payId,
        today: today,
      );
    } catch (e) {
      debugPrint('Paycheck failed: $e');
      if (mounted) _showToast(t.ledgerCouldntChangeCategory);
      return;
    }
    if (!mounted) return;
    final label = _payLabel(t, data, pay);
    _did(
      t.ledgerFiledUnder(label),
      detail: rowPayee(t, r),
      more: _alwaysOffer(r, income, pay: pay, label: label),
      undo: () => db.undoTakeAsPay(taken),
      redo: () => db.redoTakeAsPay(taken),
    );
  }

  /// After a row is given a category from the dropdown: the offer to
  /// remember it for the payee (owner, 2026-10-06: "the app should offer
  /// to remember that for the future"; income the same as any category),
  /// with how many rows of that payee are still waiting. Null when there's
  /// no payee to go by, the category is the holding one, or it's already so.
  ({String label, VoidCallback onTap})? _alwaysOffer(
    RegisterRow r,
    AccountInfo c, {
    PaySchedule? pay,
    String? label,
  }) {
    final data = _data;
    final name = (r.txnPayee ?? '').trim();
    if (data == null || name.isEmpty || isUncategorized(c)) return null;
    if (r.kind != RowKind.simple) return null;
    final words = payeeWords(name);
    // Already remembered so, by these words or by wider ones.
    final covering = PayeeRuleInfo.pick(
      data.payeeRules,
      r.accountId,
      name,
      r.memo,
    );
    if (covering != null &&
        covering.categoryId == c.id &&
        covering.payId == pay?.id) {
      return null;
    }
    final holding = _uncategorizedId(data);
    final waiting = [
      for (final x in data.registerFor(r.accountId).posted)
        if (x.txnId != r.txnId &&
            holding != null &&
            x.categoryId == holding &&
            // A paycheck is money in.
            (pay == null || x.amount > 0) &&
            payeeWords(x.txnPayee ?? '').startsWith(words))
          x.txnId,
    ];
    final t = context.t;
    return (
      label: t.ledgerAlwaysFile(waiting.length),
      onTap: () => _alwaysFile(
        accountId: r.accountId,
        payee: name,
        category: c,
        pay: pay,
        label: label ?? c.name,
        waiting: waiting,
      ),
    );
  }

  /// The offer taken: the payee is remembered (a rule on this account, by
  /// the start of its name; one already going by these words on this
  /// account is changed, not doubled) and the rows of it still waiting move
  /// now. One undo.
  Future<void> _alwaysFile({
    required int accountId,
    required String payee,
    required AccountInfo category,
    required String label,
    PaySchedule? pay,
    required List<int> waiting,
  }) async {
    final t = context.t;
    final words = payeeWords(payee);
    final was = _data?.payeeRules
        .where((x) => x.words == words && x.accountIds.contains(accountId))
        .firstOrNull;
    PayeeRuleInfo? rule;
    var previous = <int, int>{};
    var paychecks = <PayTaken>[];
    Future<void> write() async {
      final made = rule;
      if (made != null) {
        await db.putPayeeRule(made);
      } else if (was != null) {
        rule = was.copyWith(
          categoryId: category.id,
          payId: () => pay?.id,
          name: payee,
        );
        await db.putPayeeRule(rule!);
      } else {
        rule = await db.addPayeeRule(
          name: payee,
          anywhere: false,
          categoryId: category.id,
          payId: pay?.id,
          accountIds: {accountId},
        );
      }
      if (pay == null) {
        previous = waiting.isEmpty
            ? {}
            : await db.setCategoryMany(
                transactionIds: waiting,
                accountId: accountId,
                categoryId: category.id,
              );
        return;
      }
      // Oldest first, so each paycheck takes its own payday's place.
      paychecks = [
        for (final id in waiting.reversed)
          await db.takeAsPay(
            transactionId: id,
            accountId: accountId,
            scheduleId: pay.id,
            today: today,
          ),
      ];
    }

    try {
      await write();
    } catch (e) {
      debugPrint('Remembering a payee failed: $e');
      if (mounted) _showToast(t.ledgerCouldntChangeCategory);
      return;
    }
    if (!mounted) return;
    _did(
      // The undo's popup doesn't say rows were filed: they're back.
      t.ledgerAlwaysFiled(0, label),
      message: t.ledgerAlwaysFiled(
        pay == null ? previous.length : paychecks.length,
        label,
      ),
      detail: payee,
      undo: () async {
        for (final p in paychecks.reversed) {
          await db.undoTakeAsPay(p);
        }
        await db.restoreCategories(previous, accountId);
        if (was != null) {
          await db.putPayeeRule(was);
        } else if (rule case final made?) {
          await db.removePayeeRule(made.id);
        }
      },
      redo: write,
    );
  }

  // ---------- payees ----------

  /// A payee saved from its Edit on the Payees page: new ([before] null)
  /// or changed. The popup offers to file the rows it fits that are still
  /// in Not categorized; rows already in a category are never moved
  /// (owner, 2026-10-12: "that would be really bad").
  Future<bool> _savePayeeRule(
    PayeeRuleInfo? before,
    PayeeRuleInfo after,
  ) async {
    final data = _data;
    if (data == null) return false;
    final t = context.t;
    // Two payees can't go by one set of words on one account: the Edit
    // stays open, and the popup names the one that is there.
    final twin = data.payeeRules
        .where(
          (x) =>
              x.id != before?.id &&
              x.words == after.words &&
              x.accountIds.intersection(after.accountIds).isNotEmpty,
        )
        .firstOrNull;
    if (twin != null) {
      _showToast(
        t.payeesAlreadyListed(
          twin.name,
          _ruleLabel(t, data, twin, _payChoices(data)),
        ),
      );
      return false;
    }
    final PayeeRuleInfo saved;
    try {
      if (before == null) {
        saved = await db.addPayeeRule(
          name: after.name,
          anywhere: after.anywhere,
          categoryId: after.categoryId,
          payId: after.payId,
          accountIds: after.accountIds,
        );
      } else {
        saved = after;
        await db.putPayeeRule(after);
      }
    } catch (e) {
      debugPrint('Saving a payee failed: $e');
      if (mounted) _showToast(t.ledgerCouldntSave('$e'));
      return false;
    }
    if (!mounted) return true;
    final label = _ruleLabel(t, data, saved, _payChoices(data));
    final waiting = _waitingFor(data, saved);
    _did(
      t.ledgerAlwaysFiled(0, label),
      detail: saved.name,
      more: waiting.isEmpty
          ? null
          : (
              label: t.payeesFileWaiting(waiting.length),
              onTap: () => _fileWaiting(saved, waiting, label),
            ),
      undo: () => before == null
          ? db.removePayeeRule(saved.id)
          : db.putPayeeRule(before),
      redo: () => db.putPayeeRule(saved),
    );
    return true;
  }

  /// Delete on the Payees page: the app stops putting that payee in the
  /// category by itself. Rows already filed stay where they are. The rule
  /// is kept as deleted, so an import doesn't put the payee back where it
  /// went last.
  Future<void> _deletePayeeRule(PayeeRuleInfo rule) async {
    final data = _data;
    if (data == null) return;
    final t = context.t;
    final gone = rule.copyWith(deleted: true);
    try {
      await db.putPayeeRule(gone);
    } catch (e) {
      debugPrint('Deleting a payee failed: $e');
      if (mounted) _showToast(t.ledgerCouldntSave('$e'));
      return;
    }
    if (!mounted) return;
    _did(
      t.payeesDeleted,
      message: t.payeesDeletedMessage(
        _ruleLabel(t, data, rule, _payChoices(data)),
      ),
      detail: rule.name,
      undo: () => db.putPayeeRule(rule),
      redo: () => db.putPayeeRule(gone),
    );
  }

  /// The rows a payee fits that are still in Not categorized, filed under
  /// its category now (as its pay's paychecks, for a pay). One undo; the
  /// payee itself is left as it is.
  Future<void> _fileWaiting(
    PayeeRuleInfo rule,
    List<RegisterRow> waiting,
    String label,
  ) async {
    final t = context.t;
    final byAccount = <int, List<int>>{};
    // Oldest first, so each paycheck takes its own payday's place.
    for (final r in waiting.reversed) {
      (byAccount[r.accountId] ??= []).add(r.txnId);
    }
    var previous = <int, Map<int, int>>{};
    var paychecks = <PayTaken>[];
    Future<void> write() async {
      previous = {};
      paychecks = [];
      final pay = _data?.payScheduleById(rule.payId);
      for (final e in byAccount.entries) {
        if (pay != null && pay.accountId == e.key) {
          for (final id in e.value) {
            paychecks.add(
              await db.takeAsPay(
                transactionId: id,
                accountId: e.key,
                scheduleId: pay.id,
                today: today,
              ),
            );
          }
        } else {
          previous[e.key] = await db.setCategoryMany(
            transactionIds: e.value,
            accountId: e.key,
            categoryId: rule.categoryId,
          );
        }
      }
    }

    try {
      await write();
    } catch (e) {
      debugPrint('Filing a payee’s rows failed: $e');
      if (mounted) _showToast(t.ledgerCouldntChangeCategory);
      return;
    }
    if (!mounted) return;
    _did(
      t.payeesFiled(waiting.length, label),
      detail: rule.name,
      undo: () async {
        for (final p in paychecks.reversed) {
          await db.undoTakeAsPay(p);
        }
        for (final e in previous.entries) {
          await db.restoreCategories(e.value, e.key);
        }
      },
      redo: write,
    );
  }

  // ---------- setup ----------

  /// The write that marks setup as begun is on its way.
  bool _beginningSetup = false;

  /// Setup is on screen and nothing says so yet: the day its balances are
  /// as of is kept, which also keeps setup open once an account exists, and
  /// the ledger is the person's own from here.
  void _beginSetup(LedgerData data) {
    if (_beginningSetup || data.prefs[SetupKeys.date] != null) return;
    _beginningSetup = true;
    () async {
      try {
        await db.transaction(() async {
          await db.setPreference(AppDatabase.startedKey, dateKey(today));
          await db.setPreference(SetupKeys.date, dateKey(today));
        });
      } catch (e) {
        debugPrint('Starting setup failed: $e');
      } finally {
        _beginningSetup = false;
      }
    }();
  }

  /// An account and what's in it on setup's one date: one write, one undo.
  Future<void> _setupAddAccount(
    String name,
    AccountType type,
    bool cash,
    Currency currency,
    int? typed,
  ) async {
    final data = _data;
    if (data == null) return;
    final date = setupDate(data, today);
    late int id;
    int? balance;
    try {
      await db.transaction(() async {
        id = await db.createAccount(
          name: name,
          type: type,
          currency: currency,
          cash: cash,
        );
        if (typed != null && typed != 0) {
          // What's owed is typed positive, as the bank shows it.
          balance = await db.postOpeningBalance(
            accountId: id,
            date: date,
            balance: type == AccountType.liability ? -typed : typed,
          );
        }
      });
    } catch (e) {
      debugPrint('Add account failed: $e');
      if (mounted) _showToast(context.t.ledgerCouldntAddAccount);
      return;
    }
    if (!mounted) return;
    final txn = balance;
    // The row appearing is the confirmation.
    _did(
      context.t.ledgerAdded(name),
      undo: () => db.transaction(() async {
        if (txn != null) {
          _expect((await db.softDeleteMany([txn])).length == 1);
        }
        _expect(await db.deleteEmptyAccount(id));
      }),
      redo: () => db.undeleteAccount(DeletedAccount(id, [?txn])),
      toast: false,
    );
  }

  Future<void> _setupRemoveAccount(AccountInfo account) async {
    final t = context.t;
    late DeletedAccount done;
    if (!await _accountWrite(
      () async => done = await db.deleteAccount(account.id),
    )) {
      return;
    }
    _did(
      t.ledgerDeleted(account.name),
      undo: () => db.undeleteAccount(done),
      redo: () async => done = await db.deleteAccount(account.id),
    );
  }

  /// The one date changed: every balance typed so far moves to it.
  Future<void> _setupSetDate(DateTime date) async {
    final old = _data?.prefs[SetupKeys.date];
    final key = dateKey(date);
    if (old == key) return;
    final t = context.t;
    late Map<int, String> was;
    Future<void> write() => db.transaction(() async {
      was = await db.redateOpeningBalances(date);
      await db.setPreference(SetupKeys.date, key);
    });
    if (!await _accountWrite(write)) return;
    _did(
      t.setupDateChanged,
      undo: () => db.transaction(() async {
        await db.setTransactionDates(was);
        await db.setPreference(SetupKeys.date, old);
      }),
      redo: write,
      toast: false,
    );
  }

  /// Setup is left for the ledger, and doesn't open again.
  Future<void> _finishSetup() async {
    await _setPref(SetupKeys.done, '1', context.t.setupFinished);
    if (!mounted) return;
    setState(() {
      _section = AppSection.ledger;
      _all = false;
      _newAccount = false;
    });
  }

  // ---------- accounts ----------

  void _openNewAccount() {
    if (!_mayLeave()) return;
    setState(() {
      _endReconcile();
      _section = AppSection.ledger;
      _newAccount = true;
      _selected = null;
      _adding = false;
    });
  }

  Future<void> _createAccount(
    String name,
    AccountType type,
    Currency currency,
    bool cash,
  ) async {
    final int id;
    try {
      id = await db.createAccount(
        name: name,
        type: type,
        currency: currency,
        cash: cash,
      );
    } catch (e) {
      debugPrint('Add account failed: $e');
      if (mounted) _showToast(context.t.ledgerCouldntAddAccount);
      return;
    }
    if (!mounted) return;
    setState(() {
      _newAccount = false;
      _all = false;
      _accountId = id;
      _pendingAccountId = id;
    });
    // The account appearing is the confirmation; ⌘Z takes it away again, but
    // only while it's still empty: undo never deletes rows unasked.
    _did(
      context.t.ledgerAdded(name),
      undo: () async => _expect(await db.deleteEmptyAccount(id)),
      redo: () => db.undeleteAccount(DeletedAccount(id, const [])),
      toast: false,
    );
  }

  /// The balance question answered. Empty posts nothing: the account starts
  /// at ₮0 with the entry row open.
  Future<void> _startAccount(
    AccountInfo account,
    int? typed,
    DateTime date,
  ) async {
    if (typed == null || typed == 0) {
      _startedEmpty.add(account.id);
      _newEntry();
      return;
    }
    final t = context.t;
    // A card's balance is typed as what's owed, positive, as the bank shows it.
    final balance = account.isOwed ? -typed : typed;
    final int id;
    try {
      id = await db.postOpeningBalance(
        accountId: account.id,
        date: date,
        balance: balance,
      );
    } catch (e) {
      debugPrint('Opening balance failed: $e');
      _showToast(t.ledgerCouldntSaveBalance);
      return;
    }
    // The bank's number already holds everything cleared, so what's left to
    // type is what hasn't: the entry row opens. No toast (owner, 2026-09-30):
    // the account was just made on purpose; ⌘Z still takes the balance back.
    _newEntry();
    _did(
      t.startOpeningBalance,
      undo: () async => _expect((await db.softDeleteMany([id])).length == 1),
      redo: () => db.restoreMany([id]),
      toast: false,
    );
  }

  /// Runs an account write; a failure says so instead of vanishing.
  Future<bool> _accountWrite(
    Future<void> Function() write, {
    String what = 'account',
  }) async {
    try {
      await write();
      return mounted;
    } catch (e) {
      debugPrint('Change to $what failed: $e');
      if (mounted) {
        final t = context.t;
        _showToast(switch (what) {
          'pay' => t.ledgerCouldntChangePay,
          'budget period' => t.ledgerCouldntChangeBudgetPeriod,
          'category' => t.ledgerCouldntChangeCategory,
          _ => t.ledgerCouldntChangeAccount,
        });
      }
      return false;
    }
  }

  /// The open row, editor and entry row belong to the account leaving view.
  void _leaveAccount(AccountInfo account) {
    if (_accountId != account.id) return;
    _endReconcile();
    setState(() {
      _selected = null;
      _editing = null;
      _adding = false;
    });
  }

  // ---------- categories ----------

  /// What [c] has assigned for [period]. Quiet, like clearing a row: on
  /// payday it's typed a dozen times in a row, and ⌘Z takes any of them
  /// back. The first amount ever also fixes the day the budget began and
  /// its currency, so neither moves on its own later.
  /// How a new Assigned [amount] for [period] is written for [c]: one row
  /// at the period's start, or, when the category's own period (its set
  /// amount's month or pay) isn't the one on screen and the span holds
  /// more than one of them, the rows already dated in the span kept and
  /// the difference spread over its periods ([Budget.spread]), so an
  /// emptying category isn't handed the lot in its first period.
  List<({DateTime date, int amount})> _budgetRows(
    LedgerData data,
    Budget budget,
    AccountInfo c,
    BudgetSpan period,
    int amount,
  ) {
    final plan = data.plans[c.id];
    final own = plan?.kind == PlanKind.each
        ? data.payScheduleById(plan!.payScheduleId)
        : data.periodSchedule;
    final onePeriod =
        own?.id == data.periodSchedule?.id ||
        !budgetPeriod(period.start, own).end.isBefore(period.end);
    if (onePeriod) return [(date: period.start, amount: amount)];
    final kept = [
      for (final b in data.budgetAmounts)
        if (b.categoryId == c.id &&
            !b.date.isBefore(period.start) &&
            !b.date.isAfter(period.end))
          (date: dateOnly(b.date), amount: b.amount),
    ];
    final have = kept.fold(0, (sum, r) => sum + r.amount);
    return [
      ...kept,
      ...Budget.spread(
        span: period,
        own: own,
        shares: budget.lines[c.id]?.plan?.shares ?? const [],
        delta: amount - have,
      ),
    ];
  }

  Future<void> _setBudgetAmount(
    AccountInfo c,
    BudgetSpan period,
    int amount,
  ) async {
    final t = context.t;
    final data = _data!;
    final first = data.prefs[BudgetKeys.began] == null;
    final currency = Budget.currencyOf(data);
    final start = period.start, end = period.end;
    final rows = _budgetRows(
      data,
      Budget.of(data, start: start, end: end, today: today),
      c,
      period,
      amount,
    );
    Future<List<BudgetAmount>> write() async {
      final before = await db.setBudgetAmount(
        c.id,
        start,
        end,
        amount,
        rows: rows,
      );
      if (first) {
        await db.setPreference(BudgetKeys.began, dateKey(start));
        await db.setPreference(BudgetKeys.currency, currency.code);
      }
      return before;
    }

    late List<BudgetAmount> before;
    if (!await _accountWrite(
      () async => before = await write(),
      what: 'category',
    )) {
      return;
    }
    _did(
      t.planAssignUndo(formatMoney(amount, currency: c.currency), c.name),
      toast: false,
      undo: () async {
        await db.restoreBudgetAmounts(c.id, start, end, before);
        if (first) {
          await db.setPreference(BudgetKeys.began, null);
          await db.setPreference(BudgetKeys.currency, null);
        }
      },
      redo: () async => before = await write(),
    );
  }

  /// "Assign what's planned": each category in [amounts] gets its plan's
  /// amount for [period], in one write and one undo. It's allowed past the
  /// money there is; the page says by how much first, and the top line
  /// turns coral.
  Future<void> _assignPlanned(
    BudgetSpan period,
    Map<AccountInfo, int> amounts,
  ) async {
    if (amounts.isEmpty) return;
    final t = context.t;
    final data = _data!;
    final first = data.prefs[BudgetKeys.began] == null;
    final currency = Budget.currencyOf(data);
    final start = period.start, end = period.end;
    final b = Budget.of(data, start: start, end: end, today: today);
    final total = amounts.entries.fold(
      0,
      (sum, e) => sum + e.value - (b.lines[e.key.id]?.assigned ?? 0),
    );
    final byId = {
      for (final e in amounts.entries)
        e.key.id: _budgetRows(data, b, e.key, period, e.value),
    };
    late Map<int, List<BudgetAmount>> before;
    Future<void> write() async {
      before = await db.setBudgetAmounts(byId, start, end);
      if (first) {
        await db.setPreference(BudgetKeys.began, dateKey(start));
        await db.setPreference(BudgetKeys.currency, currency.code);
      }
    }

    if (!await _accountWrite(write, what: 'category')) return;
    _did(
      t.planFilled(
        amounts.length,
        formatShort(
          total,
          // One currency's button: its categories are all in it.
          currency: amounts.keys.first.currency,
        ),
      ),
      undo: () async {
        await db.restoreBudgetAmountsOf(before, start, end);
        if (first) {
          await db.setPreference(BudgetKeys.began, null);
          await db.setPreference(BudgetKeys.currency, null);
        }
      },
      redo: write,
    );
  }

  /// Puts [c] in [currency], using every account in it but [off] (rule
  /// 28). Unchecking an account is quiet; a change of currency takes back
  /// what was assigned and removes the plan, and says so, with Undo.
  Future<void> _setCategoryMoney(
    AccountInfo c,
    Currency currency,
    Set<int> off,
  ) async {
    final t = context.t;
    final data = _data!;
    final was = data.accountsOff[c.id] ?? const <int>{};
    final changed = currency != c.currency;
    if (!changed && was.length == off.length && was.containsAll(off)) return;
    final assigned = data.budgetAmounts
        .where((b) => b.categoryId == c.id)
        .fold(0, (sum, b) => sum + b.amount);
    final loses = changed && (assigned != 0 || data.plans.containsKey(c.id));
    final label = changed
        ? t.planMoneyCurrencyUndo(c.name, currency.shown)
        : t.planMoneyUndo(c.name);
    // In its new currency it counts from this period on: what was paid
    // in that currency before was never counted against it.
    final fromKey = '${BudgetKeys.fromPrefix}${c.id}';
    final fromWas = data.prefs[fromKey];
    final from = dateKey(budgetPeriod(today, data.periodSchedule).start);
    late CategoryMoney before;
    Future<void> write() async {
      before = await db.setCategoryMoney(c.id, currency: currency, off: off);
      if (changed) await db.setPreference(fromKey, from);
    }

    if (!await _accountWrite(write, what: 'category')) return;
    _did(
      label,
      toast: changed,
      message: loses
          ? '$label · ${_moneyChange(t, c, assigned, data.plans.containsKey(c.id))}'
          : null,
      undo: () async {
        await db.restoreCategoryMoney(c.id, before);
        if (changed) await db.setPreference(fromKey, fromWas);
      },
      redo: write,
    );
  }

  /// Saves [c]'s plan, or removes it with null. Saving is quiet (the plan
  /// shows under the name); removing says so, with Undo, and so does a
  /// change that moves money.
  Future<void> _setCategoryPlan(AccountInfo c, CategoryPlan? plan) async {
    final t = context.t;
    // What earlier periods sent back returns to a category that carries
    // over again: the toast says how much.
    final data = _data!;
    final p = budgetPeriod(today, data.periodSchedule);
    int free(LedgerData d) =>
        Budget.of(d, start: p.start, end: p.end, today: today).pools
            .where((pool) => pool.currency == c.currency)
            .firstOrNull
            ?.notAssigned ??
        0;
    final back = free(data) - free(data.withPlan(c.id, plan));
    final label = plan == null
        ? t.planRemoveUndo(c.name)
        : t.planSetUndo(c.name);
    // A dated plan paid from an account keeps its next bill scheduled
    // there from the moment it's saved; undo brings back the very bill
    // the change took away.
    late PlanChange change;
    if (!await _accountWrite(
      () async => change = await db.changeCategoryPlan(c.id, plan, today),
      what: 'category',
    )) {
      return;
    }
    _did(
      label,
      toast: plan == null || back > 0,
      message: back > 0
          ? '$label · ${t.planReturns(formatMoney(back, currency: c.currency), c.name)}'
          : null,
      undo: () => db.undoPlanChange(c.id, change),
      redo: () => db.redoPlanChange(c.id, plan, change),
    );
  }

  /// The first-period offer, taken: what was assigned in [period] moves to
  /// the next period, and the budget begins there.
  Future<void> _startBudgetLater(BudgetSpan period, BudgetSpan next) async {
    final t = context.t;
    final began = _data!.prefs[BudgetKeys.began];
    late List<BudgetAmount> moved;
    Future<void> write() async {
      moved = await db.moveBudgetAmounts(period.start, period.end, next.start);
      await db.setPreference(BudgetKeys.began, dateKey(next.start));
    }

    if (!await _accountWrite(write, what: 'category')) return;
    _did(
      t.planStartLaterUndo(sayDate(t, next.start)),
      undo: () async {
        await db.unmoveBudgetAmounts(moved);
        await db.setPreference(BudgetKeys.began, began);
      },
      redo: write,
    );
  }

  /// The loan's payments come out of [category] (null: of the money not
  /// assigned).
  Future<void> _setLoanCategory(AccountInfo loan, AccountInfo? category) async {
    final t = context.t;
    final key = '${BudgetKeys.loanPrefix}${loan.id}';
    final old = _data?.prefs[key];
    final value = category?.id.toString();
    if (old == value) return;
    if (!await _accountWrite(() => db.setPreference(key, value))) return;
    _did(
      category == null
          ? t.setupLoanNoCategoryUndo(loan.name)
          : t.setupLoanPaidFromUndo(loan.name, category.name),
      undo: () => db.setPreference(key, old),
      redo: () => db.setPreference(key, value),
    );
  }

  /// "₮150,000 assigned to Dining out goes back to not assigned", when [c]
  /// holds money in this period's budget; null when it holds none.
  String? _moneyBack(LedgerData data, AccountInfo c) {
    final p = budgetPeriod(today, data.periodSchedule);
    final b = Budget.of(data, start: p.start, end: p.end, today: today);
    final left = b.lines[c.id]?.left ?? 0;
    if (left == 0) return null;
    return context.t.planMoneyBack(
      formatMoney(left, currency: c.currency),
      c.name,
    );
  }

  /// Edit was saved (rule 29): [e] is the category as it should be now.
  /// One change goes the way it always has; several are written together
  /// and undone together.
  Future<void> _saveCategory(AccountInfo c, _CategoryEdit e) async {
    final t = context.t;
    final data = _data!;
    final renamed = e.name != c.name;
    // A name another category has is a merge: nothing else applies to one
    // that's gone.
    if (renamed && _categoryNamed(data, e.name, except: c.id) != null) {
      return _renameCategory(data, c, e.name);
    }
    final off = data.accountsOff[c.id] ?? const <int>{};
    final oldPlan = data.plans[c.id];
    final currency = e.currency != c.currency;
    final money =
        currency || off.length != e.off.length || !off.containsAll(e.off);
    // A change of currency removes the plan itself.
    final plan = e.plan != (currency ? null : oldPlan);
    final changes = [renamed, money, plan].where((x) => x);
    if (changes.isEmpty) return;
    if (changes.length == 1) {
      if (renamed) return _renameCategory(data, c, e.name);
      if (money) return _setCategoryMoney(c, e.currency, e.off);
      return _setCategoryPlan(c, e.plan);
    }
    final assigned = data.budgetAmounts
        .where((b) => b.categoryId == c.id)
        .fold(0, (sum, b) => sum + b.amount);
    // A plan saved in the new currency takes the old one's place.
    final removesPlan = oldPlan != null && e.plan == null;
    final loses = currency && (assigned != 0 || removesPlan);
    // What earlier periods sent back returns to a category that carries
    // over again, or has no plan now: the toast says how much.
    String? returns;
    if (plan && !currency) {
      final p = budgetPeriod(today, data.periodSchedule);
      int free(LedgerData d) =>
          Budget.of(d, start: p.start, end: p.end, today: today).pools
              .where((pool) => pool.currency == c.currency)
              .firstOrNull
              ?.notAssigned ??
          0;
      final went = free(data) - free(data.withPlan(c.id, e.plan));
      if (went > 0) {
        returns = t.planReturns(
          formatMoney(went, currency: c.currency),
          e.name,
        );
      }
    }
    // In its new currency it counts from this period on.
    final fromKey = '${BudgetKeys.fromPrefix}${c.id}';
    final fromWas = data.prefs[fromKey];
    final from = dateKey(budgetPeriod(today, data.periodSchedule).start);
    late CategoryMoney moneyBefore;
    PlanChange? planChange;
    Future<void> write() => db.transaction(() async {
      if (renamed) await db.renameAccount(c.id, e.name);
      if (money) {
        moneyBefore = await db.setCategoryMoney(
          c.id,
          currency: e.currency,
          off: e.off,
        );
        if (currency) await db.setPreference(fromKey, from);
      }
      if (plan) planChange = await db.changeCategoryPlan(c.id, e.plan, today);
    });

    if (!await _accountWrite(write, what: 'category')) return;
    final label = t.planEditedUndo(e.name);
    _did(
      label,
      message: [
        label,
        if (loses) _moneyChange(t, c, assigned, removesPlan),
        ?returns,
      ].join(' · '),
      undo: () => db.transaction(() async {
        if (plan) await db.undoPlanChange(c.id, planChange!);
        if (money) {
          await db.restoreCategoryMoney(c.id, moneyBefore);
          if (currency) await db.setPreference(fromKey, fromWas);
          // A plan a currency change took away comes back with its bill.
          await db.ensurePlanBills(today, only: c.id);
        }
        if (renamed) await db.renameAccount(c.id, c.name);
      }),
      redo: write,
    );
  }

  /// A category already called [name], ignoring case, archived included.
  /// Income's name in any language is Income's.
  AccountInfo? _categoryNamed(LedgerData data, String name, {int? except}) =>
      isIncomeName(name) && data.income?.id != except
      ? data.income
      : data.knownCategories
            .where(
              (c) =>
                  c.id != except && c.name.toLowerCase() == name.toLowerCase(),
            )
            .firstOrNull;

  /// A name that's already taken makes nothing new: an archived one comes
  /// back instead, so there's never two of it.
  /// The new category's id, so its Edit can open; null when nothing was
  /// made. A name that's an archived category's brings that one back.
  Future<int?> _createCategory(String name, Currency currency) async {
    final t = context.t;
    final data = _data;
    final existing = data == null ? null : _categoryNamed(data, name);
    if (existing != null) {
      if (existing.archived) {
        await _archiveCategory(existing, false);
        return existing.id;
      }
      _showToast(t.ledgerAlreadyCategory(existing.name));
      return null;
    }
    late int id;
    if (!await _accountWrite(
      () async => id = await db.createCategory(name, currency: currency),
      what: 'category',
    )) {
      return null;
    }
    _did(
      t.ledgerAdded(name),
      undo: () async => _expect(await db.deleteEmptyAccount(id)),
      redo: () => db.undeleteAccount(DeletedAccount(id, const [])),
    );
    return id;
  }

  /// Renaming onto another category's name is what merging looks like, so
  /// it offers that (the same as Delete with rows moving there).
  Future<void> _renameCategory(
    LedgerData data,
    AccountInfo c,
    String name,
  ) async {
    final t = context.t;
    final other = _categoryNamed(data, name, except: c.id);
    if (other != null) return _deleteCategory(data, c, into: other);
    final old = c.name;
    if (!await _accountWrite(
      () => db.renameAccount(c.id, name),
      what: 'category',
    )) {
      return;
    }
    _did(
      t.ledgerRenamed(old, name),
      undo: () => db.renameAccount(c.id, old),
      redo: () => db.renameAccount(c.id, name),
    );
  }

  /// Nothing is lost by archiving a category, so no dialog: its rows keep
  /// its name, and it leaves the menus.
  Future<void> _archiveCategory(AccountInfo c, bool archived) async {
    final t = context.t;
    if (!await _accountWrite(
      () => db.setArchived(c.id, archived),
      what: 'category',
    )) {
      return;
    }
    _did(
      archived ? t.ledgerArchived(c.name) : t.ledgerBackInMenus(c.name),
      message: archived ? t.ledgerCategoryArchivedToast(c.name) : null,
      undo: () => db.setArchived(c.id, !archived),
      redo: () => db.setArchived(c.id, archived),
    );
  }

  /// With no rows at all it just goes. With rows (deleted ones count: undoing
  /// their delete must find a category), they need a new home: the dialog
  /// asks where, and the delete is a merge. [into] preselects it (a rename
  /// onto another name).
  Future<void> _deleteCategory(
    LedgerData data,
    AccountInfo c, {
    AccountInfo? into,
  }) async {
    final t = context.t;
    final u = data.categoryUsage[c.id];
    final merging = into != null;
    final int anyRows;
    try {
      anyRows = await db.categoryEntryCount(c.id);
    } catch (e) {
      debugPrint('Counting rows failed: $e');
      _showToast(t.ledgerCouldntChangeCategory);
      return;
    }
    if (!mounted) return;
    if (anyRows > 0 || into != null) {
      into = await showDialog<AccountInfo>(
        context: context,
        builder: (_) => _DeleteCategoryDialog(
          category: c,
          usage: u,
          into: into,
          targets: data.categories.where((t) => t.id != c.id).toList(),
        ),
      );
      if (into == null || !mounted) return;
    }
    final target = into;
    late DeletedCategory done;
    if (!await _accountWrite(
      () async => done = await db.deleteCategory(c.id, into: target?.id),
      what: 'category',
    )) {
      return;
    }
    final moved = (u?.rows ?? 0) + (u?.scheduled ?? 0);
    // Its money goes back unless it moves with the merge: Income holds
    // none, and in another currency it would be read as that one's.
    final back =
        target == null || target.isIncome || target.currency != c.currency
        ? _moneyBack(data, c)
        : null;
    final said = target == null || (!merging && moved == 0)
        ? t.ledgerDeleted(c.name)
        : merging
        ? [
            t.ledgerMergedInto(c.name, target.name),
            if (moved != 0) t.ledgerRowsMoved(moved),
          ].join(' · ')
        : t.ledgerDeletedRowsMovedTo(c.name, moved, target.name);
    _did(
      t.ledgerDeleted(c.name),
      message: [said, ?back].join(' · '),
      undo: () => db.undeleteCategory(done),
      redo: () async => done = await db.deleteCategory(c.id, into: target?.id),
    );
  }

  _AccountActions _actionsFor(LedgerData data, AccountInfo account) =>
      _AccountActions(
        rename: () {
          _openAccount(account.id);
          if (_accountId != account.id || _all) return;
          // A frame later: coming from All accounts or Budget, the title it
          // opens in is only built by then.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _renameRequest++);
          });
        },
        changeKind: () => _changeKind(account),
        archive: () => _archive(data, account),
        delete: () => _deleteAccount(data, account),
        loanPaidFrom: account.isOwed
            ? (
                // In the card's currency: a payment is counted against no
                // other (and the one picked before, so its tick shows).
                categories: data.categories
                    .where(
                      (c) =>
                          !c.isIncome &&
                          !isUncategorized(c) &&
                          (c.currency == account.currency ||
                              c.id == Budget.loanCategory(data, account.id)),
                    )
                    .toList(),
                current: Budget.loanCategory(data, account.id),
                pick: (c) => _setLoanCategory(account, c),
              )
            : null,
      );

  /// Import a bank file into [account] (ADR 0002): pick it, read it, show
  /// the columns and the rows, write what the user confirms as one undoable
  /// action. The file type used last on this account is offered first.
  Future<void> _startImport(
    LedgerData data,
    AccountInfo account,
    int cleared, {
    bool starting = false,
  }) async {
    final t = context.t;
    if (!_mayLeave()) return;
    _endReconcile();
    final saved = SavedMapping.decode(
      data.prefs[AppDatabase.importMappingKey(account.id)],
    );
    final excel = XTypeGroup(
      label: t.importExcelFiles,
      extensions: const ['xls', 'xlsx', 'XLS', 'XLSX'],
      uniformTypeIdentifiers: const [
        'com.microsoft.excel.xls',
        'org.openxmlformats.spreadsheetml.sheet',
      ],
    );
    final text = XTypeGroup(
      label: t.importTextFiles,
      extensions: const ['csv', 'txt', 'tsv', 'CSV', 'TXT'],
      uniformTypeIdentifiers: const [
        'public.comma-separated-values-text',
        'public.plain-text',
        'public.tab-separated-values-text',
      ],
    );
    // No uniform type: macOS has none of its own for these, and the
    // extension is enough for it to offer them.
    final ofx = XTypeGroup(
      label: t.importOfxFiles,
      extensions: const ['ofx', 'qfx', 'qbo', 'OFX', 'QFX', 'QBO'],
    );
    final XFile? picked;
    try {
      picked = await openFile(
        acceptedTypeGroups: switch (saved?.kind) {
          FileKind.csv => [text, excel, ofx],
          FileKind.ofx => [ofx, excel, text],
          _ => [excel, text, ofx],
        },
        confirmButtonText: t.ledgerChoose,
      );
    } catch (e) {
      debugPrint('Open dialog failed: $e');
      _showToast(t.ledgerCouldntOpenFileDialog);
      return;
    }
    if (picked == null || !mounted) return;
    final Sheet sheet;
    final FileKind kind;
    final bool fits;
    final ImportMapping mapping;
    try {
      final bytes = await picked.readAsBytes();
      kind =
          fileKindOf(bytes, picked.name) ??
          (throw const UnreadableFileException('unknown kind'));
      sheet = readSheet(bytes, picked.name);
      fits =
          saved != null &&
          saved.current &&
          saved.proven &&
          mappingFits(sheet, saved);
      mapping = fits ? saved.mapping : guessMapping(sheet);
    } catch (e) {
      debugPrint('Import read failed: $e');
      if (mounted) _showToast(t.importCouldntRead(picked.name));
      return;
    }
    if (!fits && !mapping.hasDate) {
      _showToast(t.importNoDates(picked.name));
      return;
    }
    if (!mounted) return;
    final pick = await showDialog<ImportPick>(
      context: context,
      builder: (_) => CurrencyScope(
        currency: account.currency,
        child: _ImportDialog(
          accountName: account.name,
          fileName: picked!.name,
          sheet: sheet,
          mapping: mapping,
          fromSaved: fits,
          accountId: account.id,
          currency: account.currency,
          plan: (rows, keys) => db.planImport(account.id, rows, keys),
          cleared: cleared,
          owed: account.isOwed,
          starting: starting,
          today: today,
          periodStart: starting
              ? budgetPeriod(today, data.periodSchedule).start
              : null,
        ),
      ),
    );
    if (pick == null || !mounted) return;
    final uncategorized = t.importUncategorized;
    final ImportRecord record;
    try {
      record = await db.applyImport(
        accountId: account.id,
        plan: pick.plan,
        moveOpening: pick.moveOpening,
        start: pick.start,
        today: today,
        uncategorizedNames: {uncategorized, ...uncategorizedNames}.toList(),
      );
    } catch (e) {
      debugPrint('Import failed: $e');
      if (mounted) {
        _showToast(
          t.importCouldntImport(switch (e) {
            final DbException d => dbProblem(t, d),
            _ => '$e',
          }),
        );
      }
      return;
    }
    if (!mounted) return;
    final newlyCleared = record.matched
        .where((m) => m.before == Cleared.uncleared)
        .length;
    final label = record.added.isNotEmpty
        ? t.importDone(record.added.length)
        : t.importMatchedToast(record.matched.length);
    _did(
      label,
      undo: () => db.undoImport(record),
      redo: () => db.redoImport(record, account.id),
      message: [
        label,
        if (record.added.isNotEmpty && newlyCleared > 0)
          t.importMatchedToast(newlyCleared),
        if (record.uncategorizedCount > 0)
          t.importUncategorizedToast(record.uncategorizedCount, uncategorized),
        if (record.openingMove case final o?)
          t.importOpeningMovedToast(
            sayDate(t, o.toDate),
            formatMoney(
              account.isOwed ? -o.toAmount : o.toAmount,
              currency: account.currency,
            ),
          ),
      ].join(' · '),
    );
    // Remembered for the next file into this account. The rows are in
    // either way, so a failure here only costs guessing again next time.
    try {
      await db.setPreference(
        AppDatabase.importMappingKey(account.id),
        SavedMapping(
          shape: fileShape(sheet, pick.mapping),
          kind: kind,
          mapping: pick.mapping,
          proven: pick.proven,
        ).encode(),
      );
    } catch (e) {
      debugPrint('Saving the import columns failed: $e');
    }
    _keysBack();
  }

  /// Marks what an account is for on the Savings steps.
  Future<void> _setRole(
    AccountInfo account,
    AccountRole? role,
    String label,
  ) async {
    final old = account.role;
    if (old == role) return;
    if (!await _accountWrite(() => db.setAccountRole(account.id, role))) {
      return;
    }
    _did(
      label,
      undo: () => db.setAccountRole(account.id, old),
      redo: () => db.setAccountRole(account.id, role),
    );
    _keysBack();
  }

  /// A click out of a text field drops focus onto the page itself, above
  /// the screen's keys, so ⌘F and ⌘Z went dead until a row was clicked.
  /// Whenever nothing on the page holds focus, the register takes it. A
  /// dialog has its own scope, so this leaves it alone.
  void _keepKeys() {
    if (_registerFocus.context == null) return;
    if (FocusManager.instance.primaryFocus == _registerFocus.enclosingScope) {
      _registerFocus.requestFocus();
    }
  }

  /// A menu closing leaves focus on the page, out of reach of ⌘Z; give it
  /// back to the screen's keys unless someone is typing.
  void _keysBack() {
    if (!_typing) _registerFocus.requestFocus();
  }

  /// A Savings answer or setting. Answers are quiet, like clearing a row;
  /// ⌘Z undoes them.
  bool _safetyNetAsked = false;

  /// Safety net is built in (ADR 0004 "Four Savings steps"): a ledger past
  /// setup that has none gets it, once. A category the user made for it
  /// under the build before, or one already called that, becomes it.
  void _ensureSafetyNet(LedgerData data) {
    if (_safetyNetAsked || inSetup(data)) return;
    if (data.accounts.values.any(isSafetyNet)) return;
    _safetyNetAsked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final name = context.t.planFundCategoryName;
      final made = data
          .accounts[int.tryParse(data.prefs[ReadyKeys.fundCategories] ?? '')];
      final named = _categoryNamed(data, name);
      bool own(AccountInfo? a) =>
          a != null && a.type == AccountType.expense && !a.deleted;
      try {
        await db.safetyNetCategory(
          name: name,
          currency: mainCurrency(data),
          adopt: own(made)
              ? made!.id
              : own(named)
              ? named!.id
              : null,
        );
      } catch (_) {
        // Tried again the next time the app opens.
      }
    });
  }

  Future<void> _setPref(
    String key,
    String? value,
    String label, {
    bool toast = false,
  }) async {
    // The newest ledger: two quick clicks mustn't both start from the same
    // old answer.
    final old = _data?.prefs[key];
    if (old == value) return;
    final t = context.t;
    try {
      await db.setPreference(key, value);
    } catch (e) {
      _showToast(t.ledgerCouldntSave('$e'));
      return;
    }
    _did(
      label,
      toast: toast,
      undo: () => db.setPreference(key, old),
      redo: () => db.setPreference(key, value),
    );
    _keysBack();
  }

  Future<void> _rename(AccountInfo account, String name) async {
    final t = context.t;
    final old = account.name;
    if (!await _accountWrite(() => db.renameAccount(account.id, name))) return;
    _did(
      t.ledgerRenamed(old, name),
      undo: () => db.renameAccount(account.id, old),
      redo: () => db.renameAccount(account.id, name),
    );
  }

  Future<void> _changeKind(AccountInfo account) async {
    final t = context.t;
    final old = account.type;
    final next = account.isOwed ? AccountType.asset : AccountType.liability;
    var flipped = false;
    if (!await _accountWrite(
      () async => flipped = await db.setAccountType(account.id, next),
    )) {
      return;
    }
    final label = next == AccountType.liability
        ? t.ledgerIsNowCardOrLoan(account.name)
        : t.ledgerIsNowBankAccount(account.name);
    _did(
      label,
      message: flipped ? '$label · ${t.ledgerOpeningBalanceFlipped}' : null,
      undo: () => db.setAccountType(account.id, old),
      redo: () => db.setAccountType(account.id, next),
    );
  }

  Future<void> _archive(LedgerData data, AccountInfo account) async {
    final warnings = _archiveWarnings(
      account,
      data.balanceOf(account.id),
      data.registerFor(account.id).scheduled,
    );
    // Nothing left behind, nothing to read first.
    if (warnings.isNotEmpty) {
      final t = context.t;
      final go = await showDialog<bool>(
        context: context,
        builder: (_) => _AccountWarning(
          title: t.ledgerArchiveTitle(account.name),
          lines: warnings,
          action: t.ledgerArchiveAction(account.name),
          danger: false,
        ),
      );
      if (go != true || !mounted) return;
    }
    await _setArchived(account, true);
  }

  Future<void> _setArchived(AccountInfo account, bool archived) async {
    final t = context.t;
    if (archived) _leaveAccount(account);
    if (!await _accountWrite(() => db.setArchived(account.id, archived))) {
      return;
    }
    if (!archived) _openAccount(account.id);
    _did(
      archived
          ? t.ledgerArchived(account.name)
          : t.ledgerBackInSidebar(account.name),
      message: archived ? t.ledgerAccountArchivedToast(account.name) : null,
      undo: () => db.setArchived(account.id, !archived),
      redo: () => db.setArchived(account.id, archived),
    );
  }

  Future<void> _deleteAccount(LedgerData data, AccountInfo account) async {
    final t = context.t;
    final preview = data.deletePreview(account.id);
    // Nothing in it and nothing kept elsewhere: nothing to read first.
    final empty = preview.rows == 0 && preview.keptOn.isEmpty;
    final go =
        empty ||
        await showDialog<bool>(
              context: context,
              builder: (_) => _AccountWarning(
                title: t.ledgerDeleteTitle(account.name),
                lines: _deleteWarnings(
                  account,
                  data.balanceOf(account.id),
                  preview,
                ),
                action: t.ledgerDeleteAction(account.name),
                danger: true,
              ),
            ) ==
            true;
    if (!go || !mounted) return;
    _leaveAccount(account);
    late DeletedAccount done;
    if (!await _accountWrite(
      () async => done = await db.deleteAccount(account.id),
    )) {
      return;
    }
    // Final, as the warning says: no Undo on the toast. ⌘Z still works, as
    // it does for everything this session.
    _did(
      t.ledgerDeleted(account.name),
      undo: () => db.undeleteAccount(done),
      redo: () async => done = await db.deleteAccount(account.id),
      toast: false,
    );
    _showToast(t.ledgerDeleted(account.name));
  }

  /// Saves a copy of everything where the user picks: another drive, a USB
  /// stick. The daily automatic copies stay on this disk.
  Future<void> _backUpTo() async {
    final t = context.t;
    final now = widget.clock();
    final FileSaveLocation? location;
    try {
      location = await getSaveLocation(
        suggestedName: 'BetterBudget ${fullDate(now)}.${Backups.extension}',
        confirmButtonText: t.ledgerBackUpButton,
      );
    } catch (e) {
      debugPrint('Save dialog failed: $e');
      _showToast(t.ledgerCouldntOpenSaveDialog);
      return;
    }
    if (location == null) return;
    try {
      await _backups.saveTo(location.path, now);
    } catch (e) {
      debugPrint('Back up failed: $e');
      _showToast(t.ledgerCouldntBackUp);
      return;
    }
    await _backups.copiedElsewhere(now);
    if (!mounted) return;
    final name = location.path.split(RegExp(r'[/\\]')).last;
    _showToast(t.ledgerBackedUp(name));
  }

  /// A folder as it's named on screen: its last two parts, which for a Drive
  /// folder reads "My Drive/BetterBudget".
  static String _folderName(String path) => CloudFolder.nameOf(path);

  /// Keeps the whole ledger in a folder the user picks, as an encrypted copy
  /// written again after each change: a folder Google Drive, OneDrive, Box or
  /// Dropbox keeps on this computer (ADR 0005).
  Future<void> _keepInFolder() async {
    final t = context.t;
    final String? picked;
    try {
      picked = await getDirectoryPath(
        confirmButtonText: t.ledgerFolderPickButton,
      );
    } catch (e) {
      debugPrint('Folder dialog failed: $e');
      _showToast(t.ledgerCouldntOpenSaveDialog);
      return;
    }
    if (picked == null) return;
    final before = _cloud.value.path;
    final to = picked;
    // A ledger already there is never written over without a look: one
    // this computer can't read is asked about here, and a readable one is
    // taken in or asked about below, as at any other look.
    var replace = false;
    try {
      try {
        await _cloud.keepIn(to, widget.clock());
      } on FolderLedgerUnreadable {
        if (!mounted) return;
        final go = await showDialog<bool>(
          context: context,
          builder: (_) => _AccountWarning(
            title: t.ledgerFolderUnreadableTitle,
            lines: [
              (t) => t.ledgerFolderUnreadableBody(_folderName(to)),
              (t) => t.ledgerFolderUnreadableKept,
            ],
            action: t.ledgerFolderReplace,
            danger: true,
          ),
        );
        if (go != true || !mounted) return;
        replace = true;
        await _cloud.keepIn(to, widget.clock(), replaceUnreadable: true);
      }
    } on FolderLedgerNewer {
      _showToast(t.ledgerFolderNewerApp);
      return;
    } catch (e) {
      debugPrint('Keeping the ledger in a folder failed: $e');
      _showToast(t.ledgerFolderCouldnt);
      return;
    }
    if (!mounted) return;
    final found = _cloud.value.standing;
    _did(
      t.ledgerFolderKept(_folderName(to)),
      undo: () => before == null
          ? _cloud.stop()
          : _cloud.keepIn(before, widget.clock()),
      redo: () => _cloud.keepIn(to, widget.clock(), replaceUnreadable: replace),
      // The folder had a ledger of its own: what is said next is what
      // became of it.
      toast: found == FolderStanding.ok,
    );
    if (found != FolderStanding.ok) await _folderNews(justMoved: true);
  }

  /// Stops writing the copy. The one in the folder is left where it is.
  Future<void> _stopFolder() async {
    final before = _cloud.value.path;
    if (before == null) return;
    await _cloud.stop();
    if (!mounted) return;
    _did(
      context.t.ledgerFolderStopped(_folderName(before)),
      undo: () => _cloud.keepIn(before, widget.clock()),
      redo: _cloud.stop,
    );
  }

  /// Puts back a backup: the daily copies (the picker opens on their folder)
  /// or one saved elsewhere. Shows what it holds against what's here, saves
  /// what's here first, and can be undone. Resolves to whether a backup was
  /// put back.
  Future<bool> _restoreFrom({String? picked}) async {
    if (_restoring) return false;
    final t = context.t;
    // A restore replaces the rows an open edit or reconcile points at.
    if (_editing?.controller.isDirty() ?? false) {
      _showToast(context.t.ledgerSaveOrDiscard);
      return false;
    }
    _cancelEdit();
    _endReconcile();
    setState(() {
      _selected = null;
      _adding = false;
    });
    final now = widget.clock();
    final String? chosen;
    if (picked != null) {
      chosen = picked;
    } else {
      try {
        chosen = (await openFile(
          acceptedTypeGroups: [
            XTypeGroup(
              label: t.ledgerBackupFileType,
              // A daily copy or a "Back up to…" file, or the ledger as it is
              // stored in a folder ([CloudFolder.fileName]).
              extensions: const ['sqlite', Backups.extension],
            ),
          ],
          initialDirectory: (await _backups.folder())?.path,
          confirmButtonText: t.ledgerChoose,
        ))?.path;
      } catch (e) {
        debugPrint('Open dialog failed: $e');
        _showToast(t.ledgerCouldntOpenFileDialog);
        return false;
      }
    }
    if (chosen == null) return false;
    final path = chosen;
    RestoreCandidate? found;
    // Opened by this ledger's own key, as the ledger in a folder has to be
    // for this computer to be kept on it.
    var ownKey = true;
    try {
      found = await _backups.inspect(path, now);
    } on RestoreNeedsKeyException {
      // Made under another ledger's key: its own recovery key opens it.
      if (!mounted) return false;
      ownKey = false;
      await showBackupKeyDialog(context, (key) async {
        try {
          found = await _backups.inspect(
            path,
            now,
            backupKey: deriveDataKey(key),
          );
          return null;
        } on RestoreException catch (e) {
          return restoreProblem(t, e.problem);
        } catch (e) {
          debugPrint('Restore check failed: $e');
          return t.ledgerCouldntReadBackup;
        }
      });
      if (found == null) return false;
    } on RestoreException catch (e) {
      _showToast(restoreProblem(t, e.problem));
      return false;
    } catch (e) {
      debugPrint('Restore check failed: $e');
      _showToast(t.ledgerCouldntReadBackup);
      return false;
    }
    if (!mounted) return false;
    final candidate = found!;
    // The ledger another computer keeps in a folder: this computer can be
    // kept on it in the same step (a second computer set up). Offered only
    // while the ledger here is stored on this computer.
    String? folder;
    if (ownKey && _cloud.loaded.value && _cloud.value.path == null) {
      try {
        folder = await _cloud.folderOfLedger(path);
      } catch (e) {
        debugPrint('The picked file’s folder couldn’t be worked out: $e');
      }
      if (!mounted) {
        await _backups.discard(candidate);
        return false;
      }
    }
    final data = _data;
    String? to;
    // The folder chosen in the Mac's dialog is the one the file was picked
    // in: by its path, or (where the sandbox won't resolve a path it wasn't
    // given) by holding that very file.
    bool holdsPicked(String chosen) {
      if (CloudFolder.sameFolder(chosen, folder!)) return true;
      try {
        final there = File('$chosen/${CloudFolder.fileName}').statSync();
        final was = File(path).statSync();
        return there.type == FileSystemEntityType.file &&
            there.size == was.size &&
            there.modified == was.modified;
      } on FileSystemException {
        return false;
      }
    }

    while (true) {
      final answer = await showDialog<_RestoreAnswer>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        builder: (_) => _RestoreDialog(
          candidate: candidate,
          transactionsNow: data?.txns.length ?? 0,
          accountsNow: data?.balanceSheetAccounts.length ?? 0,
          folder: folder == null ? null : _folderName(folder),
          macAsks: _cloud.access.folderMustBePicked,
        ),
      );
      if (answer == null || !mounted) {
        await _backups.discard(candidate);
        return false;
      }
      if (folder == null || answer == _RestoreAnswer.restore) break;
      if (!_cloud.access.folderMustBePicked) {
        to = folder;
        break;
      }
      // The Mac gave the app the file and not its folder: its own dialog
      // opens on the folder, to be chosen there.
      String? chosen;
      try {
        chosen = await getDirectoryPath(
          initialDirectory: folder,
          confirmButtonText: t.ledgerUseThisFolder,
        );
      } catch (e) {
        debugPrint('Folder dialog failed: $e');
        _showToast(t.ledgerCouldntOpenSaveDialog);
      }
      if (!mounted) {
        await _backups.discard(candidate);
        return false;
      }
      if (chosen != null && holdsPicked(chosen)) {
        to = chosen;
        break;
      }
      // Not chosen, or another folder: back to the question, nothing done.
    }
    return _finishRestore(candidate, to);
  }

  /// Puts [candidate] in place of what's here, and when [to] is the folder
  /// it came from, keeps this computer on that folder's ledger. One action,
  /// with its undo. [nothingHere]: the ledger here was empty, so the popup
  /// has nothing saved to speak of.
  Future<bool> _finishRestore(
    RestoreCandidate candidate,
    String? to, {
    bool nothingHere = false,
  }) async {
    final t = context.t;
    final now = widget.clock();
    var kept = false;
    // The folder's ledger is taken in as the folder's own, with its counts
    // and seal, and the folder kept before anything is scheduled here: the
    // look then finds the two the same and asks nothing.
    Future<RestoreRecord> bringFromFolder(RestoreCandidate from) async {
      var record = await _backups.restore(
        from,
        widget.clock(),
        fromFolder: true,
      );
      // Earlier actions point at rows the restore replaced.
      _history.clear();
      _redo.clear();
      kept = false;
      try {
        await _cloud.keepIn(to!, widget.clock());
        kept = true;
        // The folder's ledger moved on since the file was picked (the other
        // computer wrote, or the sync service delivered a later one): that
        // one is taken in now, before a row scheduled here would make the
        // two look changed apart.
        final theirs = _cloud.theirs;
        final unchanged = _cloud.mineDigest;
        if (_cloud.value.standing == FolderStanding.newer &&
            theirs != null &&
            unchanged != null) {
          final later = await _backups.restore(
            await _backups.inspect(theirs.copy.path, widget.clock()),
            widget.clock(),
            fromFolder: true,
            onlyIfDigest: unchanged,
          );
          record = (before: record.before, restored: later.restored);
          await _cloud.check(widget.clock(), fresh: true);
        } else if (_cloud.value.standing == FolderStanding.combine) {
          // On change files the later changes are in the other computer's
          // file: brought in now, the same way, before anything is
          // scheduled here.
          for (
            var i = 0;
            i < 5 && _cloud.value.standing == FolderStanding.combine;
            i++
          ) {
            if (await _cloud.bringIn(widget.clock()) == null) break;
            await _cloud.check(widget.clock(), fresh: true);
          }
        }
      } catch (e) {
        debugPrint('Keeping this computer on the folder failed: $e');
      }
      return record;
    }

    Future<void> schedule() async {
      // A restored file's pay schedules get their next paydays, and its
      // plans their next bills, as at launch.
      try {
        await db.ensurePaydays(today);
        await db.ensurePlanBills(today);
      } catch (e) {
        debugPrint('Scheduling paydays after restore failed: $e');
      }
    }

    late RestoreRecord done;
    try {
      done = await _whileRestoring(() async {
        if (to != null) return bringFromFolder(candidate);
        final record = await _backups.restore(candidate, now);
        _history.clear();
        _redo.clear();
        return record;
      });
    } catch (e) {
      debugPrint('Restore failed: $e');
      if (!mounted) return false;
      _showToast(t.ledgerCouldntRestore);
      return false;
    }
    if (!mounted) return false;
    await schedule();
    if (!mounted) return false;
    final label = kept
        ? t.ledgerRestoredOnFolder(_folderName(to!))
        : t.ledgerRestoredFrom(sayFullDate(t, candidate.madeAt));
    _did(
      label,
      // Off the folder first: what was here before is this computer's own,
      // and isn't written over the ledger the other computers share.
      undo: () async {
        if (to != null) await _cloud.stop();
        await _whileRestoring(
          () => _backups.replaceWith(done.before, widget.clock()),
        );
      },
      // On the folder, the step is done again as it was the first time: the
      // ledger there now is the one brought here.
      redo: () async {
        final onFolder = to;
        if (onFolder == null) {
          await _whileRestoring(
            () => _backups.replaceWith(done.restored, widget.clock()),
          );
          return;
        }
        final again = await _backups.inspect(
          '$onFolder/${CloudFolder.fileName}',
          widget.clock(),
        );
        done = await _whileRestoring(() => bringFromFolder(again));
        await schedule();
      },
      message: to != null && !kept
          ? t.ledgerRestoredNotOnFolder(_folderName(to))
          : nothingHere
          ? label
          : '$label · ${t.ledgerWhatYouHadIsSaved}',
    );
    return true;
  }

  /// Clears everything for a real start once trying things out is done.
  /// What's here is saved first, and Undo puts it back.
  Future<void> _startNewLedger() async {
    if (_restoring) return;
    final t = context.t;
    if (_editing?.controller.isDirty() ?? false) {
      _showToast(context.t.ledgerSaveOrDiscard);
      return;
    }
    final data = _data;
    if (data == null) return;
    final keep = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _NewLedgerDialog(
        accounts: [
          for (final a in data.balanceSheetAccounts)
            (
              name: a.archived ? t.ledgerArchivedName(a.name) : a.name,
              balance: _balanceText(t, a, data.balanceOf(a.id)),
            ),
        ],
        transactions: data.txns.length,
        first: data.txns
            .map((t) => t.date)
            .fold<DateTime?>(
              null,
              (m, d) => m == null || d.isBefore(m) ? d : m,
            ),
        last: data.txns
            .map((t) => t.date)
            .fold<DateTime?>(null, (m, d) => m == null || d.isAfter(m) ? d : m),
        pay: data.paySchedules.length,
        reconciles: data.reconciliations.length,
        // Income isn't one of theirs: it stays either way.
        categories: data.categories.where((c) => !c.isIncome).length,
      ),
    );
    if (keep == null || !mounted) return;
    _cancelEdit();
    _endReconcile();
    setState(() {
      _selected = null;
      _adding = false;
      _all = false;
      _newAccount = false;
    });
    final now = widget.clock();
    final File before;
    try {
      before = await _whileRestoring(() async {
        final saved = await _backups.saveBeforeNewLedger(now);
        await db.startNewLedger(now, keepCategories: keep);
        return saved;
      });
    } catch (e) {
      debugPrint('New ledger failed: $e');
      _showToast(t.ledgerCouldntStartNewLedger);
      return;
    }
    if (!mounted) return;
    // Earlier actions point at rows that are gone.
    _history.clear();
    _redo.clear();
    _did(
      t.ledgerNewLedgerStarted,
      undo: () =>
          _whileRestoring(() => _backups.replaceWith(before, widget.clock())),
      redo: () => _whileRestoring(
        () => db.startNewLedger(widget.clock(), keepCategories: keep),
      ),
      message: t.ledgerEverythingErased,
    );
  }

  /// Runs a whole-ledger replace with input blocked, then refreshes what the
  /// entry row suggests, since the payees changed with everything else.
  Future<T> _whileRestoring<T>(Future<T> Function() replace) async {
    setState(() => _restoring = true);
    try {
      return await replace();
    } finally {
      if (mounted) setState(() => _restoring = false);
      _entry.payeeNames = await db.payeeNames();
    }
  }

  /// Takes back the account's latest reconcile, whenever it was done.
  Future<void> _unreconcile(AccountInfo account) async {
    final t = context.t;
    final ReconcileRecord done;
    try {
      done = await db.unreconcileLast(account.id);
    } on NotFoundException {
      return;
    }
    final n = done.entryIds.length;
    final label = t.ledgerReconcileUndone(sayDate(t, done.date));
    _did(
      label,
      undo: () => db.relock(done),
      redo: () => db.unreconcile(done),
      message: n == 0 ? label : '$label · ${t.ledgerBackToCleared(n)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): _newEntry,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            _newEntry,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _searchFocus.requestFocus,
      },
      child: Focus(
        focusNode: _registerFocus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          body: StreamBuilder<LedgerData>(
            stream: _ledger,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Text(
                    context.t.ledgerCouldntOpenLedger(switch (snap.error) {
                      final CipherException e => cipherProblem(context.t, e),
                      NewerLedgerException _ => context.t.ledgerNewerLedger,
                      final e => '$e',
                    }),
                    style: onest(14, color: Mid.coral),
                  ),
                );
              }
              final loaded = snap.data;
              if (loaded == null) return const SizedBox.shrink();
              final incomeWord = context.t.ledgerIncome;
              if (!identical(loaded, _loaded) || incomeWord != _incomeWord) {
                _loaded = loaded;
                _incomeWord = incomeWord;
                _data = loaded.withIncomeNamed(incomeWord);
              }
              final data = _data!;
              final setup = inSetup(data);
              if (setup) _beginSetup(data);
              final accounts = data.openAccounts;
              final current = data.accounts[_accountId];
              // Archived or deleted since: the first open one takes over.
              final account = accounts.contains(current)
                  ? current!
                  : accounts.firstOrNull;
              // A just-added account isn't in this snapshot yet; it will be
              // in the next, so keep it chosen.
              if (current != null && current.id == _pendingAccountId) {
                _pendingAccountId = null;
              }
              if (account != null &&
                  _accountId != account.id &&
                  (current != null ||
                      _pendingAccountId == null ||
                      _accountId != _pendingAccountId)) {
                _accountId = account.id;
                db.payeeNames().then((p) => _entry.payeeNames = p);
              }
              return Stack(
                children: [
                  Row(
                    children: [
                      _Sidebar(
                        data: data,
                        runsOut: _runsOut(data),
                        section: _section,
                        onSection: (sec) {
                          if (!_mayLeave()) return;
                          setState(() {
                            if (sec != _section) _endReconcile();
                            _section = sec;
                            _selected = null;
                          });
                        },
                        setup: setup,
                        selected: setup || _newAccount || _all
                            ? null
                            : account?.id,
                        backupHealth: _backups.health,
                        elsewhere: _backups.elsewhere,
                        folder: _cloud,
                        folderLoaded: _cloud.loaded,
                        now: widget.clock,
                        onSelect: _openAccount,
                        allActive: _all && !_newAccount,
                        onAll: () => _openAll(),
                        addingAccount: _newAccount,
                        onAddAccount: _openNewAccount,
                        actionsFor: (a) => _actionsFor(data, a),
                      ),
                      Expanded(
                        child: setup
                            ? _SetupPage(
                                data: data,
                                today: today,
                                onDate: _setupSetDate,
                                onAdd: _setupAddAccount,
                                onRemove: _setupRemoveAccount,
                                onEveryday: (v) => _setPref(
                                  SetupKeys.everyday,
                                  v,
                                  context.t.setupEverydayQ,
                                ),
                                key: _setupKey,
                                onStep: (step) async {
                                  try {
                                    await db.setPreference(
                                      SetupKeys.step,
                                      step,
                                    );
                                  } catch (e) {
                                    debugPrint('Keeping the step failed: $e');
                                  }
                                },
                                onPay: (result, existing) => _applyPay(
                                  result,
                                  existing: existing,
                                  toast: false,
                                ),
                                payHistory: (a, payee, existing) =>
                                    db.payHistory(
                                      a,
                                      scheduleId: existing?.id,
                                      payee: payee,
                                    ),
                                onDone: _finishSetup,
                              )
                            : switch (_section) {
                                AppSection.ledger
                                    when _newAccount || account == null =>
                                  _NewAccountPage(
                                    onCreate: _createAccount,
                                    // The one most accounts are in, not whichever
                                    // is on screen: ₮ for a first account.
                                    currency: mainCurrency(data),
                                    onCancel: account == null
                                        ? null
                                        : () => setState(
                                            () => _newAccount = false,
                                          ),
                                  ),
                                AppSection.ledger when _all => _withSources(
                                  data,
                                  _allBody(data),
                                ),
                                AppSection.ledger => _withSources(
                                  data,
                                  CurrencyScope(
                                    currency: account!.currency,
                                    child: _body(data, account),
                                  ),
                                ),
                                AppSection.settings => _SettingsPage(
                                  health: _backups.health,
                                  backedUp: _backups.elsewhere,
                                  now: widget.clock,
                                  onBackUp: _backUpTo,
                                  onRestore: _restoreFrom,
                                  folder: _cloud,
                                  folderName: _folderName,
                                  onKeepInFolder: _keepInFolder,
                                  onStopFolder: _stopFolder,
                                  onChooseLedger: _chooseLedger,
                                  onNewLedger: _startNewLedger,
                                  version: _version,
                                  encrypted: widget.encrypted,
                                  recoveryKeySaved: _keySaved,
                                  onCheckRecoveryKey:
                                      widget.checkRecoveryKey == null
                                      ? null
                                      : _checkRecoveryKey,
                                  appearance: switch (AppearanceScope.maybeOf(
                                    context,
                                  )) {
                                    null => null,
                                    final c => _AppearanceSettings(
                                      value: c.value,
                                      onChanged: (a) => _setAppearance(c, a),
                                      scheme: c.scheme,
                                      onScheme: (x) => _setScheme(c, x),
                                    ),
                                  },
                                  language: switch (LanguageScope.maybeOf(
                                    context,
                                  )) {
                                    null => null,
                                    final c => _LanguageSettings(
                                      value: c.value,
                                      onChanged: (l) => _setLanguage(c, l),
                                    ),
                                  },
                                  register: _RegisterSettings(
                                    showSource:
                                        data.prefs[showSourceKey] != '0',
                                    onShowSource: _setShowSource,
                                    here: db.thisComputer,
                                    computers: _sourcesOf(data).computers,
                                    phones: _sourcesOf(data).phones,
                                    onName: _nameSource,
                                  ),
                                  archived: data.archivedAccounts.isEmpty
                                      ? null
                                      : _ArchivedAccounts(
                                          data: data,
                                          onUnarchive: (a) =>
                                              _setArchived(a, false),
                                        ),
                                ),
                                AppSection.budget => _BudgetPage(
                                  key: _budgetKey,
                                  data: data,
                                  today: today,
                                  onShowRows: (c, period) =>
                                      _openAll(category: c.id, period: period),
                                  onShowAllRows: (c) =>
                                      _openAll(category: c.id),
                                  onSetAmount: _setBudgetAmount,
                                  onBudgetBy: _budgetBy,
                                  onStartLater: _startBudgetLater,
                                  onAssignPlanned: _assignPlanned,
                                  onKeepStart: () => _setPref(
                                    BudgetKeys.keptStart,
                                    '1',
                                    context.t.planStartKeep,
                                  ),
                                  onKeysBack: _keysBack,
                                  onAskAgain: () => _setNoRegularPay(false),
                                  onSave: _saveCategory,
                                  onArchive: (c) => _archiveCategory(c, true),
                                  onDelete: (c) => _deleteCategory(data, c),
                                  onPay: (p) => _openPaySetup(existing: p),
                                  onCreate: _createCategory,
                                  onEditOpens: _closeToast,
                                  onUnarchive: (c) =>
                                      _archiveCategory(c, false),
                                ),
                                AppSection.payees => _PayeesPage(
                                  key: _payeesKey,
                                  data: data,
                                  pays: _payChoices(data),
                                  actions: _PayeesActions(
                                    save: _savePayeeRule,
                                    delete: _deletePayeeRule,
                                  ),
                                ),
                                AppSection.savings => _SavingsPage(
                                  data: data,
                                  today: dateOnly(widget.clock()),
                                  actions: _SavingsActions(
                                    setRole: _setRole,
                                    setPref:
                                        (key, value, label, {toast = false}) =>
                                            _setPref(
                                              key,
                                              value,
                                              label,
                                              toast: toast,
                                            ),
                                    assign: (category, total) {
                                      final day = dateOnly(widget.clock());
                                      _setBudgetAmount(category, (
                                        start: DateTime(day.year, day.month),
                                        end: DateTime(
                                          day.year,
                                          day.month + 1,
                                          0,
                                        ),
                                        label: '',
                                      ), total);
                                    },
                                    setAside: (step, aside, label) => _setPref(
                                      ReadyKeys.setAside,
                                      Readiness.of(
                                        _data ?? data,
                                        widget.clock(),
                                      ).setAsideWith(step, aside),
                                      label,
                                      toast: true,
                                    ),
                                  ),
                                ),
                              },
                      ),
                    ],
                  ),
                  if (_restoring)
                    const Positioned.fill(
                      child: ModalBarrier(
                        dismissible: false,
                        color: Color(0x66000000),
                      ),
                    ),
                  if (_toast != null)
                    _Toast(
                      key: _toastKey,
                      toast: _toast!,
                      onPointer: _toastPointerAt,
                      onClose: _closeToast,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _body(LedgerData data, AccountInfo account) {
    final summary = data.summaryFor(account.id);
    final register = data.registerFor(account.id);
    // Nothing in it yet: ask what's in it first.
    final fresh =
        register.posted.isEmpty &&
        register.scheduled.isEmpty &&
        !_startedEmpty.contains(account.id);
    _rows = {
      for (final r in [...register.posted, ...register.scheduled]) r.txnId: r,
    };
    // Drop the selection when its row is gone (deleted, other account).
    if (!_rows.containsKey(_selected)) _selected = null;
    if (_editing != null && !_rows.containsKey(_editing!.txnId)) {
      _editing = null;
    }
    final forecast = _forecastFor(data, account);
    // The pay-period choice is named by its date: the date that forecast
    // would run to, worked out when another span is on.
    final span = _span(data);
    final byPay = span == ForecastSpan.payPeriod
        ? forecast
        : _forecastFor(data, account, span: ForecastSpan.payPeriod);
    final payPeriodEnd = byPay.payday != null ? byPay.end : null;
    // Trouble past this view: said above the forecast, and a click picks
    // the shortest span that shows it. Within the view, the headline
    // already says it.
    final ahead = _shortAhead(data, account);
    final beyond = ahead != null && ahead.date.isAfter(forecast.end)
        ? ahead
        : null;
    final activeStatus = switch (_filter) {
      RegisterFilter.uncleared => Cleared.uncleared,
      RegisterFilter.cleared => Cleared.cleared,
      RegisterFilter.reconciled => Cleared.reconciled,
      _ => null,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Transform.translate(
                // The name's own padding (it renames in place) stays out of
                // the left edge the rest of the page lines up on.
                offset: const Offset(-8, 0),
                child: _AccountTitle(
                  account: account,
                  onRename: (name) => _rename(account, name),
                  actions: _actionsFor(data, account),
                  renameRequest: _renameRequest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (fresh)
            Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _AccountStart(
                  key: ValueKey('start-${account.id}'),
                  account: account,
                  today: today,
                  onStart: (balance, date) =>
                      _startAccount(account, balance, date),
                  onImport: account.isCash
                      ? null
                      : () => _startImport(data, account, 0, starting: true),
                ),
              ),
            )
          else ...[
            BalanceHeader(
              owed: account.isOwed,
              summary: summary,
              forecast: forecast,
              span: span,
              payPeriodEnd: payPeriodEnd,
              onSpan: _setSpan,
              shortAhead: beyond,
              onShowShort: beyond == null
                  ? null
                  : () => _setSpan(
                      ForecastSpan.values
                          .skip(1)
                          .firstWhere(
                            (s) => !s.endFrom(today)!.isBefore(beyond.date),
                            orElse: () => ForecastSpan.year,
                          ),
                    ),
              hoveredStatus: _hoveredStatus,
              activeStatus: activeStatus,
              onOpenScheduled: _openScheduled,
              // Cash: no statement to reconcile against, no bank file.
              onReconcile: account.isCash
                  ? null
                  : () => _startReconcile(data, account),
              onImport: account.isCash
                  ? null
                  : () => _startImport(data, account, summary.cleared),
              // Asked until there's pay anywhere; once there is, an account
              // it doesn't go into doesn't nag, and a click can't start a
              // second Salary by mistake.
              // "I don't have regular pay" said once stops the asking.
              onAddPay:
                  account.isOwed ||
                      data.paySchedules.isNotEmpty ||
                      data.prefs[noRegularPayKey] == '1'
                  ? null
                  : () => _openPaySetup(account: account),
              reconcile: _reconcile == null
                  ? null
                  : ReconcilePanel(
                      session: _reconcile!,
                      today: today,
                      check: () => _reconcileCheck(data, summary),
                      onLock: () => _lockReconcile(
                        account,
                        _reconcileCheck(data, summary),
                      ),
                      onAdjust: () => _lockReconcile(
                        account,
                        _reconcileCheck(data, summary),
                        adjust: true,
                      ),
                      onCancel: _endReconcile,
                    ),
              onStatusTap: (s) => setState(() {
                final f = switch (s) {
                  Cleared.uncleared => RegisterFilter.uncleared,
                  Cleared.cleared => RegisterFilter.cleared,
                  Cleared.reconciled => RegisterFilter.reconciled,
                };
                _filter = _filter == f ? RegisterFilter.all : f;
              }),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: RegisterPanel(
                owed: account.isOwed,
                accountName: account.name,
                posted: register.posted,
                scheduled: register.scheduled,
                reconcileThrough: _reconcile == null
                    ? null
                    : parseEntryDate(_reconcile!.date.text, today) ?? today,
                filter: _filter,
                uncategorizedId: _uncategorizedId(data),
                uncategorizedFrom: budgetPeriod(
                  today,
                  data.periodSchedule,
                ).start,
                uncategorizedTo: budgetPeriod(today, data.periodSchedule).end,
                search: _search.text,
                selected: _selected,
                selectedKey: _selectedKey,
                editing: _editing,
                hoveredStatus: _hoveredStatus,
                // Archived too, so an old row keeps its category when
                // edited; menus and lists leave them out.
                categories: data.knownCategories,
                transferTargets: data.openAccounts
                    .where((a) => a.id != account.id)
                    .toList(),
                currency: account.currency,
                unclearedCheck: data.unclearedCheck,
                pointed: _pointed,
                pointedKey: _pointedKey,
                entryController: _entry,
                today: today,
                adding: _adding,
                searchBox: _searchBox(),
                addButton: _PrimaryButton(
                  label: context.t.ledgerAdd,
                  icon: Icons.add_rounded,
                  key: const ValueKey('add-transaction'),
                  onTap: _newEntry,
                ),
                onCloseEntry: _closeEntry,
                actions: RegisterActions(
                  onFilter: (f) => setState(() => _filter = f),
                  onRowTap: _tapRow,
                  onToggleCleared: _toggleCleared,
                  onConfirm: _startConfirm,
                  onAlreadyIn: _alreadyIn,
                  onPoint: _pointTo,
                  onSetCategory: _setCategory,
                  onDelete: _delete,
                  onClearSelection: _clearSelection,
                  onEdit: (r) => _startEdit(r.txnId, EditField.payee),
                  onCancelEdit: _cancelEdit,
                  onUnreconcile: (_) => _unreconcile(account),
                  onMove: (r, to) => _move(r, account, to),
                  pays: _payChoices(data, into: account.id),
                  onSetPay: _setPay,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A class, not a record: a toast checks its action is still the newest by
/// identity, which records don't have.
/// "Today 14:32", "Yesterday 21:40", or the date in full with the time.
String _sayWhen(Words t, DateTime at, DateTime now) {
  String two(int v) => v.toString().padLeft(2, '0');
  final today = dateOnly(now);
  final day = dateOnly(at) == today
      ? t.today
      : dateOnly(at) == today.subtract(const Duration(days: 1))
      ? t.yesterday
      : sayFullDate(t, at);
  return t.ledgerTimeAt(day, '${two(at.hour)}:${two(at.minute)}');
}

class _Undoable {
  _Undoable(this.label, this.undo, this.redo, {this.detail});
  final String label;

  /// The row it was done to, when [label] doesn't name it: the popup's
  /// second line, so an undo still says which row changed (rule 9).
  final String? detail;
  final Future<void> Function() undo;
  final Future<void> Function() redo;
}

/// One sidebar: the section you're in expands, the others collapse to a line.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.data,
    required this.section,
    required this.onSection,
    required this.selected,
    required this.onSelect,
    required this.backupHealth,
    required this.elsewhere,
    required this.folderLoaded,
    required this.folder,
    required this.now,
    required this.addingAccount,
    required this.onAddAccount,
    required this.actionsFor,
    required this.allActive,
    required this.onAll,
    required this.runsOut,
    this.setup = false,
  });

  /// Setup is on the page: the accounts and what they come to, and nothing
  /// to go to, since there is nothing behind the sections yet.
  final bool setup;
  final bool allActive;
  final VoidCallback onAll;

  /// Accounts whose forecast goes below zero, each with the warning.
  final Map<int, String> runsOut;

  /// For the right-click menu on each account.
  final _AccountActions Function(AccountInfo) actionsFor;
  final LedgerData data;
  final bool addingAccount;
  final VoidCallback onAddAccount;
  final ValueListenable<BackupHealth> backupHealth;

  /// When the ledger was last copied off this computer, for the reminder
  /// under Net worth.
  final ValueListenable<CopiedElsewhere?> elsewhere;

  /// Whether it is known yet where the ledger is stored.
  final ValueListenable<bool> folderLoaded;

  /// The folder the ledger was moved to: failing to write it lights the
  /// gear too.
  final ValueListenable<CloudFolderState> folder;
  final DateTime Function() now;
  final AppSection section;
  final ValueChanged<AppSection> onSection;
  final int? selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // Grouped by what the ledger stores; the groups the app makes are named
    // in the language showing, any other as it's stored.
    final groups = <String?, List<AccountInfo>>{};
    for (final a in data.openAccounts) {
      groups.putIfAbsent(a.group, () => []).add(a);
    }
    String groupName(String? g) => switch (g) {
      null => t.ledgerGroupAccounts,
      LedgerGroups.cash => t.ledgerGroupCash,
      LedgerGroups.bank => t.ledgerGroupBank,
      LedgerGroups.credit => t.ledgerGroupCredit,
      // A ledger made before cash was its own Type, not yet reopened.
      'Cash & bank' => t.ledgerGroupCashBank,
      final other => other,
    };
    // Archived accounts still hold money, or debt. Each currency on its
    // own line: they're never added together (ROADMAP E).
    final net = data.balancesByCurrency(data.balanceSheetAccounts);
    // So net worth isn't a mystery sum of the accounts above it.
    final archived = data.balancesByCurrency(data.archivedAccounts)
      ..removeWhere((_, v) => v == 0);

    Widget header(AppSection sec, IconData icon, String label) =>
        _SectionHeader(
          icon: icon,
          label: label,
          expanded: section == sec,
          onTap: () => onSection(sec),
        );

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Mid.side,
        border: Border(right: BorderSide(color: Mid.sideRule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The dark-mode logo: the sidebar is dark in every scheme.
          // On its own layer: the mark is some 1,100 drawing steps, and
          // nothing about it changes while the page repaints.
          const RepaintBoundary(
            child: Padding(
              key: ValueKey('logo'),
              padding: EdgeInsets.fromLTRB(24, 30, 24, 6),
              child: Row(
                children: [
                  Mark(height: 40),
                  SizedBox(width: 10),
                  Wordmark(height: 22),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 22, 12, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The sections scroll when the accounts outgrow the
                  // window; Settings and Net worth stay put below.
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!setup)
                            header(
                              AppSection.ledger,
                              Icons.format_list_bulleted_rounded,
                              t.ledgerSectionLedger,
                            ),
                          _Spill(
                            open: setup || section == AppSection.ledger,
                            children: [
                              const SizedBox(height: 10),
                              if (!setup)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 26,
                                    bottom: 12,
                                  ),
                                  child: _AllAccountsTile(
                                    active: allActive,
                                    onTap: onAll,
                                  ),
                                ),
                              for (final g in groups.entries) ...[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    38,
                                    0,
                                    12,
                                    6,
                                  ),
                                  child: Text(
                                    groupName(g.key),
                                    style: onest(12, color: Mid.sideInk3),
                                  ),
                                ),
                                for (final a in g.value)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 26),
                                    // In setup the list on the page is
                                    // where an account is changed; here
                                    // it only shows what's been added.
                                    child: IgnorePointer(
                                      ignoring: setup,
                                      child: _AccountTile(
                                        account: a,
                                        runsOut: runsOut[a.id],
                                        balance: data.balanceOf(a.id),
                                        active: a.id == selected,
                                        onTap: () => onSelect(a.id),
                                        actions: actionsFor(a),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 14),
                              ],
                              if (!setup)
                                _AddAccountTile(
                                  active: addingAccount,
                                  onTap: onAddAccount,
                                ),
                              const SizedBox(height: 10),
                            ],
                          ),
                          if (!setup) ...[
                            const SizedBox(height: 2),
                            header(
                              AppSection.budget,
                              Icons.pie_chart_outline_rounded,
                              t.ledgerSectionBudget,
                            ),
                            const SizedBox(height: 2),
                            header(
                              AppSection.savings,
                              Icons.savings_outlined,
                              t.ledgerSectionSavings,
                            ),
                            const SizedBox(height: 2),
                            header(
                              AppSection.payees,
                              Icons.storefront_outlined,
                              t.ledgerSectionPayees,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Settings, above Net worth, laid out like a section header so its
                  // icon and label line up with theirs.
                  if (!setup)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      // Full width, like the section headers, so hover fills the row.
                      child: ListenableBuilder(
                        listenable: Listenable.merge([backupHealth, folder]),
                        builder: (context, _) => _SettingsGear(
                          active: section == AppSection.settings,
                          alert:
                              folder.value.standing == FolderStanding.apart ||
                                  folder.value.standing == FolderStanding.rows
                              ? context.t.ledgerFolderApartAlert
                              : folder.value.held
                              ? context.t.ledgerFolderAlert
                              : backupHealth.value.alarmingAt(now())
                              ? context.t.ledgerDailyCopyFailing
                              : null,
                          onTap: () => onSection(AppSection.settings),
                        ),
                      ),
                    ),
                  // In setup with no account yet, ₮0.00 would be noise.
                  if (!setup || data.balanceSheetAccounts.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: Mid.sideRule)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.ledgerNetWorth,
                            style: onest(12, color: Mid.sideInk3),
                          ),
                          const SizedBox(height: 4),
                          for (final e in net.entries)
                            Text(
                              formatMoney(e.value, currency: e.key),
                              key: ValueKey('net-worth-${e.key.code}'),
                              style: onest(
                                net.length > 1 ? 16 : 18,
                                weight: 500,
                                color: Mid.sideInk,
                                tabular: true,
                              ),
                            ),
                          if (archived.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                t.ledgerInclArchived(
                                  archived.entries
                                      .map((e) => _money(e.value, e.key))
                                      .join(' · '),
                                ),
                                key: const ValueKey('net-worth-archived'),
                                style: onest(
                                  11.5,
                                  color: Mid.sideInk3,
                                  tabular: true,
                                ),
                              ),
                            ),
                          // The daily copies share a disk with the ledger:
                          // said here, on every page, once it has been a
                          // month, and never while the ledger is in a folder.
                          if (!setup)
                            ListenableBuilder(
                              listenable: Listenable.merge([
                                elsewhere,
                                folder,
                                folderLoaded,
                              ]),
                              builder: (context, _) {
                                final e = elsewhere.value;
                                if (e == null ||
                                    !folderLoaded.value ||
                                    folder.value.path != null ||
                                    !e.dueAt(now())) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Hoverable(
                                    key: const ValueKey('backup-reminder'),
                                    onTap: () => onSection(AppSection.settings),
                                    builder: (h) => Text(
                                      e.copied == null
                                          ? t.ledgerNeverCopiedElsewhere
                                          : t.ledgerLastCopiedElsewhere(
                                              e.daysAt(now()),
                                            ),
                                      // 11: the longest of the two fits the sidebar on one line.
                                      style: onest(11, color: Mid.sideInk2)
                                          .copyWith(
                                            decoration: h
                                                ? TextDecoration.underline
                                                : null,
                                            decorationColor: Mid.sideInk2,
                                          ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens Settings, above Net worth. A coral dot says something there needs attention (the
/// daily copy is failing), since the gear is all that shows of it.
class _SettingsGear extends StatelessWidget {
  const _SettingsGear({
    required this.active,
    required this.alert,
    required this.onTap,
  });
  final bool active;

  /// What needs attention in Settings, said as the dot's tooltip; null for
  /// no dot.
  final String? alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    // Only worth a tooltip when the dot needs explaining.
    message: alert ?? '',
    child: Hoverable(
      key: const ValueKey('settings'),
      onTap: onTap,
      builder: (h) => Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: h && !active ? Mid.sideHover : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.settings_outlined,
                  size: 16,
                  color: active ? Mid.sun : Mid.sideInk3,
                ),
                if (alert != null)
                  Positioned(
                    top: -2,
                    right: -3,
                    child: Container(
                      key: const ValueKey('settings-alert'),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: Mid.sideCoral,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Text(
              context.t.ledgerSettings,
              style: onest(
                14,
                weight: active ? 600 : 500,
                color: active ? Mid.sideInk : Mid.sideInk2,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Settings, one section per kind. Backups is the first.
class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.health,
    required this.backedUp,
    required this.now,
    required this.onBackUp,
    required this.onRestore,
    required this.folder,
    required this.folderName,
    required this.onKeepInFolder,
    required this.onStopFolder,
    required this.onChooseLedger,
    required this.onNewLedger,
    required this.recoveryKeySaved,
    this.version,
    this.encrypted = false,
    this.onCheckRecoveryKey,
    this.archived,
    this.appearance,
    this.language,
    this.register,
  });
  final ValueListenable<BackupHealth> health;

  /// The register's own choices (the Source column, and naming phones).
  final Widget? register;

  /// When "Back up to…" last worked, said beside it.
  final ValueListenable<CopiedElsewhere?> backedUp;

  /// Light, dark or the system's; null without an [AppearanceScope] (tests).
  final Widget? appearance;

  /// English, Mongolian or the system's; null without a [LanguageScope]
  /// (tests).
  final Widget? language;

  /// Archived accounts, when there are any.
  final Widget? archived;
  final DateTime Function() now;
  final VoidCallback onBackUp;
  final VoidCallback onRestore;

  /// The folder the whole ledger is kept in, if one was picked.
  final ValueListenable<CloudFolderState> folder;
  final String Function(String path) folderName;
  final VoidCallback onKeepInFolder;
  final VoidCallback onStopFolder;

  /// Opens the question of which ledger to keep, while this computer's and
  /// the folder's were both changed.
  final VoidCallback onChooseLedger;
  final VoidCallback onNewLedger;

  /// Whether the recovery key was saved or copied when it was shown (ADR
  /// 0001): drives the coral warning below.
  final bool recoveryKeySaved;

  /// Version and build number, shown at the bottom so a bug report can say
  /// which build it came from; null when unknown (tests).
  final (String, String)? version;

  /// Shows the Security section; false in tests.
  final bool encrypted;

  /// "Check my recovery key…"; null hides the button.
  final VoidCallback? onCheckRecoveryKey;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    Widget line(String label, Widget value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: onest(13.5, color: Mid.ink3)),
          ),
          Expanded(child: value),
        ],
      ),
    );
    String when(DateTime at) => _sayWhen(t, at, now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
      child: Align(
        alignment: Alignment.topLeft,
        // Scrolls once archived accounts make it taller than the window.
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // As tall as an account's title row (it has search), so the
                // title doesn't jump when switching.
                SizedBox(
                  height: 36,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      t.ledgerSettings,
                      style: onest(22, weight: 600, letterSpacing: -0.3),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
                  decoration: BoxDecoration(
                    color: Mid.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Mid.rule),
                  ),
                  child: ListenableBuilder(
                    listenable: Listenable.merge([health, folder, backedUp]),
                    builder: (context, _) {
                      final h = health.value;
                      final kept = folder.value;
                      final keptIn = kept.path;
                      final failing = h.alarmingAt(now());
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.ledgerBackupsTitle,
                            style: onest(16, weight: 600),
                          ),
                          const SizedBox(height: 16),
                          line(
                            t.ledgerDailyCopy,
                            failing
                                ? Text(
                                    h.newest == null
                                        ? t.ledgerDailyCopyFailingNone
                                        : t.ledgerDailyCopyFailingSince(
                                            when(h.newest!),
                                          ),
                                    key: const ValueKey('backup-failed'),
                                    style: onest(13.5, color: Mid.coral),
                                  )
                                : Text(
                                    h.newest == null
                                        ? t.ledgerDailyCopyNone
                                        : t.ledgerDailyCopyWhen(
                                            when(h.newest!),
                                          ),
                                    style: onest(13.5, color: Mid.ink),
                                  ),
                          ),
                          line(
                            t.ledgerKept,
                            Text(
                              t.ledgerKeptWhich,
                              style: onest(13.5, color: Mid.ink2),
                            ),
                          ),
                          // Always said, moved or not: where the ledger is now.
                          if (keptIn == null) ...[
                            line(
                              t.ledgerFolderLabel,
                              Text(
                                t.ledgerFolderHere,
                                key: const ValueKey('stored-in'),
                                style: onest(13.5, color: Mid.ink),
                              ),
                            ),
                            // What the sidebar's reminder counts from, beside
                            // the button that answers it.
                            if (backedUp.value case final e?)
                              line(
                                t.ledgerCopiedElsewhere,
                                Text(
                                  e.copied == null
                                      ? t.ledgerCopiedElsewhereNever
                                      : when(e.copied!),
                                  key: const ValueKey('copied-elsewhere'),
                                  style: onest(13.5, color: Mid.ink),
                                ),
                              ),
                          ] else
                            line(
                              t.ledgerFolderLabel,
                              Tooltip(
                                message: keptIn,
                                child: Text(
                                  switch (kept.standing) {
                                    FolderStanding.failing =>
                                      kept.copiedAt == null
                                          ? t.ledgerFolderFailingNone(
                                              folderName(keptIn),
                                            )
                                          : t.ledgerFolderFailing(
                                              folderName(keptIn),
                                              when(kept.copiedAt!),
                                            ),
                                    FolderStanding.rows ||
                                    FolderStanding.apart => t.ledgerFolderApart(
                                      folderName(keptIn),
                                    ),
                                    FolderStanding.newerApp =>
                                      t.ledgerFolderNewerAppLine(
                                        folderName(keptIn),
                                      ),
                                    FolderStanding.arriving =>
                                      t.ledgerFolderArriving(
                                        folderName(keptIn),
                                      ),
                                    FolderStanding.ok ||
                                    FolderStanding.newer ||
                                    FolderStanding.combine =>
                                      t.ledgerFolderCopied(
                                        folderName(keptIn),
                                        when(kept.copiedAt ?? now()),
                                      ),
                                  },
                                  key: const ValueKey('stored-in'),
                                  style: onest(
                                    13.5,
                                    color: kept.held ? Mid.coral : Mid.ink,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            runSpacing: 8,
                            children: [
                              BarButton(
                                key: const ValueKey('back-up'),
                                label: t.ledgerBackUpTo,
                                leading: Icon(
                                  Icons.save_alt_rounded,
                                  size: 14,
                                  color: Mid.ink3,
                                ),
                                onTap: onBackUp,
                              ),
                              BarButton(
                                key: const ValueKey('restore'),
                                label: t.ledgerRestoreFrom,
                                leading: Icon(
                                  Icons.settings_backup_restore_rounded,
                                  size: 14,
                                  color: Mid.ink3,
                                ),
                                onTap: onRestore,
                              ),
                              BarButton(
                                key: const ValueKey('keep-in-folder'),
                                label: keptIn == null
                                    ? t.ledgerFolderChoose
                                    : t.ledgerFolderChange,
                                leading: Icon(
                                  Icons.folder_open_rounded,
                                  size: 14,
                                  color: Mid.ink3,
                                ),
                                onTap: onKeepInFolder,
                              ),
                              // Offered only while there are two to choose
                              // between.
                              if (kept.standing == FolderStanding.apart ||
                                  kept.standing == FolderStanding.rows)
                                BarButton(
                                  key: const ValueKey('choose-ledger'),
                                  label: t.ledgerFolderChooseWhich,
                                  onTap: onChooseLedger,
                                ),
                              // Offered only while there is a folder to stop.
                              if (keptIn != null)
                                BarButton(
                                  key: const ValueKey('stop-folder'),
                                  label: t.ledgerFolderStop,
                                  onTap: onStopFolder,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            t.ledgerBackupsNote,
                            style: onest(13, color: Mid.ink3),
                          ),
                          if (keptIn == null) ...[
                            const SizedBox(height: 8),
                            Text(
                              t.ledgerFolderNote,
                              style: onest(13, color: Mid.ink3),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                if (appearance != null) ...[
                  const SizedBox(height: 16),
                  appearance!,
                ],
                if (language != null) ...[
                  const SizedBox(height: 16),
                  language!,
                ],
                if (register != null) ...[
                  const SizedBox(height: 16),
                  register!,
                ],
                if (archived != null) ...[
                  const SizedBox(height: 16),
                  archived!,
                ],
                if (encrypted) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
                    decoration: BoxDecoration(
                      color: Mid.panel,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Mid.rule),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.ledgerSecurityTitle,
                          style: onest(16, weight: 600),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          recoveryKeySaved
                              ? t.ledgerSecurityKeySaved
                              : t.ledgerSecurityKeyNotSaved,
                          key: const ValueKey('security-status'),
                          style: onest(
                            13,
                            color: recoveryKeySaved ? Mid.ink3 : Mid.coral,
                            height: 1.4,
                          ),
                        ),
                        if (onCheckRecoveryKey != null) ...[
                          const SizedBox(height: 12),
                          BarButton(
                            key: const ValueKey('check-recovery-key'),
                            label: t.ledgerCheckRecoveryKey,
                            leading: Icon(
                              Icons.key_rounded,
                              size: 14,
                              color: Mid.ink3,
                            ),
                            onTap: onCheckRecoveryKey!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
                  decoration: BoxDecoration(
                    color: Mid.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Mid.rule),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.ledgerStartOverTitle,
                        style: onest(16, weight: 600),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t.ledgerStartOverNote,
                        style: onest(13, color: Mid.ink3),
                      ),
                      const SizedBox(height: 12),
                      BarButton(
                        key: const ValueKey('new-ledger'),
                        label: t.ledgerEraseAndStartOverButton,
                        leading: Icon(
                          Icons.restart_alt_rounded,
                          size: 14,
                          color: Mid.ink3,
                        ),
                        onTap: onNewLedger,
                      ),
                    ],
                  ),
                ),
                if (version case (final name, final build)) ...[
                  const SizedBox(height: 16),
                  SelectableText(
                    t.settingsVersion(name, build),
                    key: const ValueKey('app-version'),
                    style: onest(13, color: Mid.ink3),
                  ),
                ],
                SizedBox(height: version == null ? 16 : 6),
                SelectableText(
                  t.settingsCredit,
                  key: const ValueKey('app-credit'),
                  style: onest(13, color: Mid.ink3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks before a restore replaces everything, with what the backup holds
/// beside what's here now.
/// Which ledger to go on with, when this computer's and the folder's were
/// both changed (ADR 0005, "Never write blind"): what each holds, in real
/// numbers. Pops true for the folder's, false for this computer's, and
/// null when it is put off.
class _TwoLedgersDialog extends StatelessWidget {
  const _TwoLedgersDialog({
    required this.title,
    required this.folder,
    required this.theirs,
    required this.savedBy,
    required this.savedWhen,
    required this.transactionsHere,
    required this.accountsHere,
  });
  final String title;
  final String folder;
  final RestoreCandidate theirs;

  /// What the computer that saved the folder's ledger is called, if known.
  final String? savedBy;
  final String savedWhen;
  final int transactionsHere;
  final int accountsHere;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    Widget line(String label, String value, [String? under]) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: onest(13, color: Mid.ink3)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: onest(13.5, color: Mid.ink, tabular: true)),
                if (under != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(under, style: onest(13, color: Mid.ink2)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    return Dialog(
      backgroundColor: Mid.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Mid.rule),
      ),
      child: SizedBox(
        width: 520,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: onest(17, weight: 600, letterSpacing: -0.2)),
              const SizedBox(height: 16),
              line(
                t.ledgerTwoInFolder,
                t.ledgerCounts(theirs.transactions, theirs.accounts),
                savedBy == null
                    ? t.ledgerTwoSavedWhen(savedWhen)
                    : t.ledgerTwoSavedOn(savedBy!, savedWhen),
              ),
              line(
                t.ledgerTwoHere,
                t.ledgerCounts(transactionsHere, accountsHere),
              ),
              const SizedBox(height: 4),
              Text(
                t.ledgerTwoBody(folder),
                style: onest(13, color: Mid.ink2, height: 1.4),
              ),
              const SizedBox(height: 20),
              // At the right, like every other dialog's buttons.
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    BarButton(
                      key: const ValueKey('two-not-now'),
                      label: t.ledgerTwoNotNow,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    BarButton(
                      key: const ValueKey('two-use-mine'),
                      label: t.ledgerTwoUseMine,
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                    BarButton(
                      key: const ValueKey('two-use-folder'),
                      label: t.ledgerTwoUseFolder,
                      onTap: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the restore dialog was answered with; closed any other way, nothing
/// is restored.
enum _RestoreAnswer {
  restore,

  /// And this computer stays on the folder the file was picked in.
  restoreAndKeep,
}

/// Where someone who already uses BetterBudget keeps their ledger.
enum StartFrom { folder, backup }

enum _Where { folder, backup, empty }

/// One answer to "Where is your ledger?": what it is, and a line on what
/// choosing it does.
class WhereRow extends StatelessWidget {
  const WhereRow({
    super.key,
    required this.title,
    required this.note,
    required this.onTap,
  });
  final String title;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Hoverable(
    onTap: onTap,
    builder: (hover) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: hover ? Mid.raised : Mid.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hover ? Mid.blueEdge : Mid.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: onest(15, weight: 600)),
          const SizedBox(height: 3),
          Text(note, style: onest(13.5, color: Mid.ink2, height: 1.4)),
        ],
      ),
    ),
  );
}

class _RestoreDialog extends StatefulWidget {
  const _RestoreDialog({
    required this.candidate,
    required this.transactionsNow,
    required this.accountsNow,
    this.folder,
    this.macAsks = false,
  });
  final RestoreCandidate candidate;
  final int transactionsNow;
  final int accountsNow;

  /// The folder the file was picked in, as it's named on screen, when it is
  /// the ledger another computer keeps there: the dialog then offers to
  /// keep this computer on it, ticked.
  final String? folder;

  /// The Mac's own folder dialog follows Restore: the note says so.
  final bool macAsks;

  @override
  State<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<_RestoreDialog> {
  bool _keep = true;

  _RestoreAnswer get _answer => widget.folder != null && _keep
      ? _RestoreAnswer.restoreAndKeep
      : _RestoreAnswer.restore;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final candidate = widget.candidate;
    final transactionsNow = widget.transactionsNow;
    final accountsNow = widget.accountsNow;
    final made = candidate.madeAt;
    String two(int v) => v.toString().padLeft(2, '0');
    Widget line(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: onest(13, color: Mid.ink3)),
          ),
          Text(
            value,
            style: onest(
              13.5,
              color: strong ? Mid.ink : Mid.ink2,
              tabular: true,
            ),
          ),
        ],
      ),
    );
    return Dialog(
      backgroundColor: Mid.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Mid.rule),
      ),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): () =>
              Navigator.of(context).pop(_answer),
        },
        child: Focus(
          autofocus: true,
          child: SizedBox(
            width: 460,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.folder == null
                        ? t.ledgerRestoreTitle
                        : t.ledgerBringLedgerTitle,
                    style: onest(17, weight: 600, letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 16),
                  line(
                    widget.folder == null
                        ? t.ledgerBackupFrom
                        : t.ledgerLastChanged,
                    '${fullDate(made)}  ${two(made.hour)}:${two(made.minute)}',
                    strong: true,
                  ),
                  line(
                    t.ledgerItHolds,
                    t.ledgerCounts(candidate.transactions, candidate.accounts),
                    strong: true,
                  ),
                  line(
                    t.ledgerHereNow,
                    t.ledgerCounts(transactionsNow, accountsNow),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.folder == null
                        ? t.ledgerRestoreNote
                        : t.ledgerBringLedgerNote,
                    style: onest(13, color: Mid.ink2),
                  ),
                  if (widget.folder case final folder?) ...[
                    const SizedBox(height: 16),
                    Hoverable(
                      key: const ValueKey('restore-keep-on-folder'),
                      onTap: () => setState(() => _keep = !_keep),
                      builder: (_) => Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _keep
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            size: 18,
                            color: _keep ? Mid.blue : Mid.ink3,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.ledgerRestoreKeepOnFolder(folder),
                                  style: onest(13.5, color: Mid.ink),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  !_keep
                                      ? t.ledgerRestoreNotKeptNote(folder)
                                      : widget.macAsks
                                      ? '${t.ledgerRestoreKeepOnFolderNote(folder)} ${t.ledgerRestoreMacAsks}'
                                      : t.ledgerRestoreKeepOnFolderNote(folder),
                                  style: onest(
                                    13,
                                    color: Mid.ink2,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      BarButton(
                        key: const ValueKey('restore-cancel'),
                        label: t.ledgerCancel,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      _PrimaryButton(
                        key: const ValueKey('restore-confirm'),
                        label: t.ledgerRestore,
                        icon: Icons.settings_backup_restore_rounded,
                        tooltip: 'Enter',
                        onTap: () => Navigator.of(context).pop(_answer),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A balance as the sidebar shows it: a card as what's owed, positive, as
/// the bank does.
String _balanceText(Words t, AccountInfo a, int balance) => a.isOwed
    ? t.ledgerOwed(formatMoney(-balance, currency: a.currency))
    : formatMoney(balance, currency: a.currency);

/// Asks before everything is erased for a clean start, naming what goes:
/// each account and its balance, the transactions' dates, pay. Whether the
/// categories stay is a choice in plain sight; keeping them is the default.
class _NewLedgerDialog extends StatefulWidget {
  const _NewLedgerDialog({
    required this.accounts,
    required this.transactions,
    required this.first,
    required this.last,
    required this.pay,
    required this.reconciles,
    required this.categories,
  });
  final List<({String name, String balance})> accounts;
  final int transactions;
  final DateTime? first;
  final DateTime? last;
  final int pay;
  final int reconciles;
  final int categories;

  @override
  State<_NewLedgerDialog> createState() => _NewLedgerDialogState();
}

class _NewLedgerDialogState extends State<_NewLedgerDialog> {
  bool _keep = true;

  /// Accounts listed by name before "+ N more".
  static const _shown = 8;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final first = widget.first, last = widget.last;
    final also = [
      if (widget.pay > 0) t.ledgerYourPay,
      if (widget.reconciles > 0) t.ledgerReconciles(widget.reconciles),
      t.ledgerPayees,
      t.ledgerBudgetSavingsSettings,
    ];
    final alsoText = also.join(' · ');

    Widget item(String left, String right, {Key? key}) => Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(left, style: onest(13.5, color: Mid.ink)),
          ),
          Text(right, style: onest(13.5, color: Mid.ink, tabular: true)),
        ],
      ),
    );

    Widget choice(
      String label,
      bool on,
      VoidCallback onTap,
      String key,
    ) => Hoverable(
      key: ValueKey(key),
      onTap: onTap,
      builder: (hover) => Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: on ? Mid.blueWash : (hover ? Mid.raised : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: on ? Mid.blue : Mid.ink2.withValues(alpha: 0.3),
          ),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(label, style: onest(13, color: on ? Mid.ink : Mid.ink2)),
        ),
      ),
    );

    return Dialog(
      backgroundColor: Mid.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Mid.coral.withValues(alpha: 0.5)),
      ),
      child: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.ledgerEraseTitle,
                style: onest(
                  17,
                  weight: 600,
                  letterSpacing: -0.2,
                  color: Mid.coral,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                t.ledgerAllOfThisErased,
                style: onest(13.5, weight: 600, color: Mid.ink),
              ),
              const SizedBox(height: 10),
              Container(
                key: const ValueKey('new-ledger-goes'),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                decoration: BoxDecoration(
                  color: Mid.coral.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Mid.coral.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final a in widget.accounts.take(_shown))
                      item(a.name, a.balance),
                    if (widget.accounts.length > _shown)
                      item(
                        t.ledgerMoreAccounts(widget.accounts.length - _shown),
                        '',
                      ),
                    item(
                      t.ledgerTransactionCount(widget.transactions),
                      first == null || last == null
                          ? ''
                          : first == last
                          ? fullDate(first)
                          : '${fullDate(first)} – ${fullDate(last)}',
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(alsoText, style: onest(13.5, color: Mid.ink)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                t.ledgerStartWithNothing,
                style: onest(13.5, color: Mid.ink),
              ),
              if (widget.categories > 0) ...[
                const SizedBox(height: 18),
                Text(
                  t.ledgerYourCategories(widget.categories),
                  style: onest(13.5, weight: 600, color: Mid.ink),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    choice(
                      t.ledgerKeepThemEmpty,
                      _keep,
                      () => setState(() => _keep = true),
                      'new-ledger-keep',
                    ),
                    choice(
                      t.ledgerEraseThemToo,
                      !_keep,
                      () => setState(() => _keep = false),
                      'new-ledger-drop',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _keep ? t.ledgerKeptNoRows : t.ledgerAddCategoriesAgain,
                  key: const ValueKey('new-ledger-categories'),
                  style: onest(12.5, color: Mid.ink3),
                ),
              ],
              const SizedBox(height: 18),
              Text(t.ledgerEraseNote, style: onest(13, color: Mid.ink2)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  BarButton(
                    key: const ValueKey('new-ledger-cancel'),
                    label: t.ledgerCancel,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  Material(
                    key: const ValueKey('new-ledger-confirm'),
                    color: Mid.coral,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () =>
                          Navigator.of(context)
                              .pop(_keep && widget.categories > 0),
                      borderRadius: BorderRadius.circular(8),
                      hoverColor: Colors.white.withValues(alpha: 0.14),
                      child: Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        child: Text(
                          t.ledgerEraseEverything,
                          style: onest(13, weight: 600, color: Mid.onAccent),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatefulWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool expanded;
  final VoidCallback onTap;

  @override
  State<_SectionHeader> createState() => _SectionHeaderState();
}

class _SectionHeaderState extends State<_SectionHeader> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.expanded;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _hover && !on ? Mid.sideHover : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: on ? Mid.sun : Mid.sideInk3),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: onest(
                  14,
                  weight: on ? 600 : 500,
                  color: on ? Mid.sideInk : Mid.sideInk2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A section's contents: opening makes room smoothly while the children
/// spill down one after another; closing plays it back quicker.
class _Spill extends StatefulWidget {
  const _Spill({required this.open, required this.children});
  final bool open;
  final List<Widget> children;

  static const openTime = Duration(milliseconds: 360);
  static const closeTime = Duration(milliseconds: 200);

  @override
  State<_Spill> createState() => _SpillState();
}

class _SpillState extends State<_Spill> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: _Spill.openTime,
    reverseDuration: _Spill.closeTime,
    value: widget.open ? 1 : 0,
  );

  @override
  void didUpdateWidget(_Spill old) {
    super.didUpdateWidget(old);
    if (old.open == widget.open) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = widget.open ? 1 : 0;
    } else if (widget.open) {
      _c.forward();
    } else {
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        if (_c.isDismissed) return const SizedBox.shrink();
        final n = widget.children.length;
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: Curves.easeOutCubic.transform(_c.value),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < n; i++)
                  _item(widget.children[i], i / n * 0.55),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Each child fades in and drops a few pixels into place, starting a
  /// little after the one above it.
  Widget _item(Widget child, double start) {
    final t = Curves.easeOut.transform(
      ((_c.value - start) / 0.45).clamp(0.0, 1.0),
    );
    if (t == 1) return child;
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, -8 * (1 - t)), child: child),
    );
  }
}

class _AccountTile extends StatefulWidget {
  const _AccountTile({
    required this.account,
    required this.balance,
    required this.active,
    required this.onTap,
    required this.actions,
    this.runsOut,
  });
  final AccountInfo account;
  final int balance;
  final bool active;
  final VoidCallback onTap;
  final _AccountActions actions;

  /// Its forecast goes below zero: the header's warning, for a coral dot
  /// beside the name.
  final String? runsOut;

  @override
  State<_AccountTile> createState() => _AccountTileState();
}

class _AccountTileState extends State<_AccountTile> {
  bool _hover = false;
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) => MenuAnchor(
    controller: _menu,
    style: _menuStyle,
    // Lit while its menu is open, so it's clear which account it's for.
    onOpen: () => setState(() {}),
    onClose: () {
      if (mounted) setState(() {});
    },
    menuChildren: _accountMenu(widget.account, widget.actions),
    child: _tile(),
  );

  Widget _tile() => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      onTap: widget.onTap,
      // Right-click: the same menu as ⋯ beside the name, where the click was.
      onSecondaryTapDown: (d) => _menu.open(position: d.localPosition),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: widget.active
              ? Mid.sideSel
              : (_hover || _menu.isOpen ? Mid.sideHover : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: widget.active
              ? Border(left: BorderSide(color: Mid.sun, width: 2))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    widget.account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: onest(
                      13.5,
                      color: widget.active ? Mid.sideInk : Mid.sideInk2,
                    ),
                  ),
                ),
                if (widget.runsOut case final why?) ...[
                  const SizedBox(width: 7),
                  Tooltip(
                    message: why,
                    waitDuration: const Duration(milliseconds: 400),
                    child: Container(
                      key: ValueKey('runs-out-${widget.account.id}'),
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Mid.sideCoral,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              // A card shows what's owed, positive, as the bank does; owing
              // isn't a warning.
              _balanceText(context.t, widget.account, widget.balance),
              style: onest(
                12.5,
                color: !widget.account.isOwed && widget.balance < 0
                    ? Mid.sideCoral
                    // The account being worked in reads clearly on its
                    // highlight; the others stay quiet.
                    : (widget.active || _hover ? Mid.sideInk2 : Mid.sideInk3),
                tabular: true,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 280,
    height: 36,
    child: TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: (_) => onChanged(),
      style: onest(13),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Mid.panel,
        hintText: context.t.ledgerSearchHint,
        hintStyle: onest(13, color: Mid.ink3),
        prefixIcon: Icon(Icons.search_rounded, size: 16, color: Mid.ink3),
        prefixIconConstraints: const BoxConstraints(minWidth: 36),
        suffixIcon: controller.text.isEmpty
            ? Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Center(
                  widthFactor: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Mid.raised,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isMac)
                          Icon(
                            Icons.keyboard_command_key_rounded,
                            size: 11,
                            color: Mid.ink3,
                          )
                        else
                          Text('Ctrl ', style: onest(11.5, color: Mid.ink3)),
                        Text('F', style: onest(11.5, color: Mid.ink3)),
                      ],
                    ),
                  ),
                ),
              )
            : IconButton(
                icon: Icon(Icons.close_rounded, size: 14, color: Mid.ink3),
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: Mid.blue, width: 1.5),
        ),
      ),
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// Its shortcut; ⌘N (Ctrl+N) unless given.
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip ?? (_isMac ? '⌘N' : 'Ctrl+N'),
    child: Material(
      color: Mid.fill,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        hoverColor: Mid.onFill.withValues(alpha: 0.12),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, size: 16, color: Mid.onFill),
              const SizedBox(width: 8),
              Text(label, style: onest(13, weight: 600, color: Mid.onFill)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The popup that reports a saved change: a card of one width in the page's
/// bottom-right corner, so it never lies over the sidebar and Undo and ×
/// are always in the same place (owner, 2026-10-06, option A of two). What
/// happened, then the row it happened to on a line of its own (a bank's
/// payee is data, not part of the sentence), then the one further thing on
/// offer as a button.
class _Toast extends StatelessWidget {
  const _Toast({
    super.key,
    required this.toast,
    required this.onClose,
    required this.onPointer,
  });
  final ({
    String message,
    String? detail,
    VoidCallback? undo,
    ({String label, VoidCallback onTap})? more,
  })
  toast;
  final VoidCallback onClose;

  /// Where the pointer moved or clicked on the card; null when it left.
  final ValueChanged<Offset?> onPointer;

  static const width = 440.0;

  @override
  Widget build(BuildContext context) {
    final ink = Mid.onToast;
    final light = Mid.isLight;
    return Positioned(
      bottom: 36,
      right: 40,
      width: width,
      // A click on it isn't a click away from a row open for typing.
      child: TextFieldTapRegion(
        child: MouseRegion(
          onHover: (e) => onPointer(e.position),
          onExit: (_) => onPointer(null),
          child: Listener(
            onPointerDown: (e) => onPointer(e.position),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  // Gold so it gets noticed: it reports something that changed.
                  color: Mid.toast,
                  borderRadius: BorderRadius.circular(12),
                  border: light ? Border.all(color: Mid.gold) : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: light ? 0.18 : 0.45,
                      ),
                      blurRadius: light ? 24 : 32,
                      offset: Offset(0, light ? 8 : 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            // Every line of it: the last clause is often the
                            // amount, so nothing is cut.
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              toast.message,
                              key: const ValueKey('toast-message'),
                              style: onest(14, weight: 600, color: ink),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (toast.undo != null)
                          TextButton(
                            onPressed: toast.undo,
                            style: TextButton.styleFrom(
                              foregroundColor: ink,
                              // A Mac draws buttons 8 shorter, which left
                              // Undo above the sentence it sits beside.
                              visualDensity: VisualDensity.standard,
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              context.t.ledgerUndo,
                              style: onest(13, weight: 700, color: ink),
                            ),
                          ),
                        IconButton(
                          onPressed: onClose,
                          constraints: const BoxConstraints.tightFor(
                            width: 32,
                            height: 32,
                          ),
                          padding: EdgeInsets.zero,
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: ink.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    if (toast.detail case final detail?)
                      Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 2),
                        child: Text(
                          detail,
                          key: const ValueKey('toast-detail'),
                          // Two things to say are a line each.
                          maxLines: detail.contains('\n') ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: onest(
                            12.5,
                            weight: 500,
                            color: ink.withValues(alpha: 0.72),
                          ),
                        ),
                      ),
                    if (toast.more case final more?)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 10,
                          right: 8,
                          bottom: 4,
                        ),
                        child: OutlinedButton(
                          key: const ValueKey('toast-more'),
                          onPressed: more.onTap,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ink,
                            visualDensity: VisualDensity.standard,
                            side: BorderSide(
                              color: ink.withValues(alpha: 0.55),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            minimumSize: const Size(0, 34),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          // Two lines when it needs them (Mongolian does).
                          child: Text(
                            more.label,
                            textAlign: TextAlign.center,
                            style: onest(13, weight: 600, color: ink),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Settings → Appearance: System, Light or Dark. Under System, says which one
/// the computer is showing now, so the choice never looks like it did nothing.
/// Below, the color scheme showing, and on request all of them: the app's
/// own, then Figma's 100 in their groups (owner, 2026-09-30), each as its four
/// colors over its name. Folded by default so the cards below it (Language,
/// the recovery key) stay in view.
class _AppearanceSettings extends StatefulWidget {
  const _AppearanceSettings({
    required this.value,
    required this.onChanged,
    required this.scheme,
    required this.onScheme,
  });
  final Appearance value;
  final ValueChanged<Appearance> onChanged;
  final Scheme scheme;
  final ValueChanged<Scheme> onScheme;

  @override
  State<_AppearanceSettings> createState() => _AppearanceSettingsState();
}

class _AppearanceSettingsState extends State<_AppearanceSettings> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final value = widget.value, scheme = widget.scheme;
    final onChanged = widget.onChanged, onScheme = widget.onScheme;
    Widget choice(Appearance a, String label) => _SettingChoice(
      key: ValueKey('appearance-${a.name}'),
      label: label,
      chosen: a == value,
      onTap: () => onChanged(a),
    );
    final system = _isMac ? t.languageSameAsMac : t.languageSameAsWindows;
    return Container(
      key: const ValueKey('settings-appearance'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
      decoration: BoxDecoration(
        color: Mid.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Mid.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.ledgerAppearanceTitle, style: onest(16, weight: 600)),
          const SizedBox(height: 16),
          Row(
            children: [
              choice(Appearance.system, system),
              choice(Appearance.light, t.ledgerAppearanceLight),
              choice(Appearance.dark, t.ledgerAppearanceDark),
            ],
          ),
          if (value == Appearance.system) ...[
            const SizedBox(height: 10),
            Text(
              (Mid.isLight ? t.ledgerShowingLightNow : t.ledgerShowingDarkNow)(
                _isMac ? t.theMac : t.windowsName,
              ),
              style: onest(12.5, color: Mid.ink3),
            ),
          ],
          const SizedBox(height: 24),
          Text(t.appearanceColorsTitle, style: onest(14, weight: 600)),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!_all) ...[
                _SchemeTile(
                  scheme: scheme,
                  chosen: true,
                  onTap: () => setState(() => _all = true),
                ),
                const SizedBox(width: 14),
              ],
              _SettingChoice(
                key: const ValueKey('colors-all'),
                label: _all
                    ? t.appearanceColorsHide
                    : t.appearanceColorsShowAll(schemes.length),
                chosen: false,
                onTap: () => setState(() => _all = !_all),
              ),
            ],
          ),
          if (_all) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _SchemeTile(
                  scheme: betterBudgetScheme,
                  chosen: scheme.id == betterBudgetScheme.id,
                  onTap: () => onScheme(betterBudgetScheme),
                ),
              ],
            ),
          ],
          if (_all)
            for (final g in SchemeGroup.values) ...[
              const SizedBox(height: 18),
              Text(
                schemeGroupName(t, g),
                style: onest(12.5, weight: 500, color: Mid.ink2),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final s in schemes.where((s) => s.group == g))
                    _SchemeTile(
                      scheme: s,
                      chosen: s.id == scheme.id,
                      onTap: () => onScheme(s),
                    ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}

/// A color scheme to pick: its four colors over its name, outlined when it's
/// the one showing.
class _SchemeTile extends StatelessWidget {
  const _SchemeTile({
    required this.scheme,
    required this.chosen,
    required this.onTap,
  });
  final Scheme scheme;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Hoverable(
    key: ValueKey('scheme-${scheme.id}'),
    onTap: onTap,
    builder: (hover) => Container(
      width: 124,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: chosen
            ? Mid.blueWash
            : (hover ? Mid.raised : Colors.transparent),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: chosen ? Mid.blue : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 30,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final c in scheme.colors)
                    Expanded(child: ColoredBox(color: c)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            schemeName(context.t, scheme),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: onest(12, color: chosen ? Mid.ink : Mid.ink2),
          ),
        ],
      ),
    ),
  );
}

/// One choice in a row of them (Appearance, Language).
class _SettingChoice extends StatelessWidget {
  const _SettingChoice({
    super.key,
    required this.label,
    required this.chosen,
    required this.onTap,
  });
  final String label;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Hoverable(
      onTap: onTap,
      builder: (hover) => Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: chosen
              ? Mid.blueWash
              : (hover ? Mid.raised : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: chosen ? Mid.blue : Mid.ink2.withValues(alpha: 0.3),
          ),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: onest(13, color: chosen ? Mid.ink : Mid.ink2),
          ),
        ),
      ),
    ),
  );
}

/// Settings → Language: the system's, English or Монгол. Under the system's,
/// says which one is showing now, as Appearance does.
class _LanguageSettings extends StatelessWidget {
  const _LanguageSettings({required this.value, required this.onChanged});
  final Language value;
  final ValueChanged<Language> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    Widget choice(Language l, String label) => _SettingChoice(
      key: ValueKey('language-${l.name}'),
      label: label,
      chosen: l == value,
      onTap: () => onChanged(l),
    );
    final showing = Localizations.localeOf(context).languageCode == 'mn'
        ? t.languageMongolian
        : t.languageEnglish;
    return Container(
      key: const ValueKey('settings-language'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
      decoration: BoxDecoration(
        color: Mid.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Mid.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.languageTitle, style: onest(16, weight: 600)),
          const SizedBox(height: 16),
          Row(
            children: [
              choice(
                Language.system,
                _isMac ? t.languageSameAsMac : t.languageSameAsWindows,
              ),
              choice(Language.english, t.languageEnglish),
              choice(Language.mongolian, t.languageMongolian),
            ],
          ),
          if (value == Language.system) ...[
            const SizedBox(height: 10),
            Text(
              t.languageShowingNow(showing, _isMac ? t.theMac : t.windowsName),
              style: onest(12.5, color: Mid.ink3),
            ),
          ],
        ],
      ),
    );
  }
}
