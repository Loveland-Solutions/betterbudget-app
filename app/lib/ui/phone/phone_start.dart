// The phone app's first minute (ADR 0005). A phone with no key asks how to
// start, as a computer does (#534, the owner's pick of sketch A): Start fresh
// makes a ledger on the phone and shows its recovery key once; Restore from
// backup makes it from a backup file; Open ledger takes the key, then the
// folder the ledger was moved to. A phone on a folder reads it again whenever
// the app comes back to the front, and every half minute while it is open; a
// phone on its own keeps its ledger here and looks at no folder.
import 'dart:async';
import 'dart:io';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' show XFile, openFile;
import 'package:flutter/material.dart';

import '../../data/backup.dart' show RestoreException, RestoreProblem;
import '../../data/incoming_file.dart';
import '../../data/keys.dart';
import '../../data/ledger_file.dart';
import '../../data/phone_inbox.dart';
import '../../data/phone_ledger.dart';
import '../../data/phone_sync.dart';
import '../../data/problem_log.dart';
import '../../domain/phone.dart';
import '../data_words.dart';
import '../language.dart';
import '../recovery_key_screen.dart' show RecoveryKeyDisplay, copyRecoveryKey;
import '../theme.dart';
import 'phone_app.dart';
import 'phone_asking.dart' show PhoneAnswer;
import 'phone_demo.dart';

/// The phone's own ledger and the way it is kept up with the folder; swapped
/// in tests.
typedef OpenPhoneLedger = PhoneLedgerSource Function({
  required Directory dir,
  required Uint8List key,
  required String device,
  required PhoneFolder folder,
});

PhoneLedgerSource _openPhoneSync({
  required Directory dir,
  required Uint8List key,
  required String device,
  required PhoneFolder folder,
}) => PhoneSync(
  dir: dir,
  dataKey: key,
  device: device,
  io: PhoneFolderIo(folder),
);

enum _Step {
  loading,
  // How do you want to start? (#534)
  welcome,
  // Start fresh's recovery key, shown once.
  newKey,
  // Start fresh's ledger couldn't be made.
  newFailed,
  // The ledger kept on a phone on its own couldn't be opened.
  ownCantOpen,
  key,
  folder,
  noLedger,
  wrongKey,
  cantRead,
  ready,
}

/// How long the folder is given to answer before the phone stops waiting:
/// with no signal a cloud provider may never answer at all.
const phoneFolderPatience = Duration(seconds: 8);

class PhoneStart extends StatefulWidget {
  const PhoneStart({
    super.key,
    required this.keys,
    required this.dir,
    this.folder = const PhoneFolder(),
    this.open = _openPhoneSync,
    this.now = DateTime.now,
    this.every = const Duration(seconds: 30),
    this.problems,
    this.random,
  });

  /// Where Start fresh's recovery key comes from: secure, unless a test
  /// needs the same key every time.
  final Random? random;

  /// Recent problems (#294); by default the file `problems` in [dir].
  final ProblemLog? problems;

  /// How often the folder is read again while the app is open: the
  /// computer's answer to an entry arrives without the app being left.
  final Duration every;

  final KeyStore keys;

  /// Where the phone keeps its own ledger and what is waiting.
  final Directory dir;
  final PhoneFolder folder;
  final OpenPhoneLedger open;
  final DateTime Function() now;

  @override
  State<PhoneStart> createState() => _PhoneStartState();
}

class _PhoneStartState extends State<PhoneStart> with WidgetsBindingObserver {
  _Step _step = _Step.loading;
  PhoneStore? _store;
  PhoneOutbox? _outbox;
  PhoneInbox? _kept;
  PhoneLedgerSource? _source;
  String? _folder;
  Timer? _again;

  /// What was last written to the folder, so a fresh read with nothing new
  /// to say writes nothing; null after a write that failed, to try again.
  String? _sent;
  Future<void> _keeping = Future.value();

  /// The key as typed, until it has opened the ledger: only a key that fits
  /// is kept (a key that didn't would be asked about on every launch).
  Uint8List? _typedKey;
  final _keyText = TextEditingController();
  String? _keyError;

  /// Start fresh's recovery key, on screen until Continue.
  RecoveryKey? _newKey;

  /// Written when the ledger is made on this phone (#534): with no folder
  /// kept, the phone is on its own, and its ledger is shown as it stands.
  /// A phone that joined a folder and lost it is asked for the folder.
  File get _startedHere => File('${widget.dir.path}/started-here');

  /// No folder: the phone holds the only ledger.
  var _onItsOwn = false;

  /// No key is kept on this phone yet: its problem screens offer the way
  /// back to "How do you want to start?".
  var _noKeyKept = true;

  late final ProblemLog _problems =
      widget.problems ?? ProblemLog(File('${widget.dir.path}/problems'));

  /// Keeping the entries on the phone has failed since it last worked: put
  /// in the record once, not at every try (every half minute).
  var _saveFailing = false;

  /// Puts a problem in the record, in the words the phone uses.
  void _record(String Function(Words t) message, Object reason) {
    if (!mounted) return;
    unawaited(_problems.record(message(context.t), reason));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _again?.cancel();
    _store?.removeListener(_keep);
    unawaited(_source?.close());
    _keyText.dispose();
    super.dispose();
  }

  /// Back at the front: the folder may hold a newer ledger by now.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _step == _Step.ready && !_demo) {
      _load();
    }
  }

  void _go(_Step step) {
    if (mounted) setState(() => _step = step);
  }

  /// One look at a time: a pull down while the app is coming back to the
  /// front would have two looks working on the same ledger.
  Future<void>? _reading;
  var _looks = 0;

  Future<void> _load() {
    if (_answering) return Future.value();
    // Held while a reconcile is open, as the computer holds it (ADR 0005):
    // rows arriving under the statement would move the sum being matched.
    // Looked at again the moment it is locked or left.
    if (_store?.reconciling.value ?? false) return Future.value();
    // And while a bank file is picked and its import page is open (#531):
    // its counts are of the ledger as it stood.
    if (_store?.importing.value ?? false) return Future.value();
    return _reading ??= _read().whenComplete(() => _reading = null);
  }

  /// Looks at the folder: the first time the ledger in it becomes this
  /// phone's own, and from then on the other computers' changes are brought
  /// in and this phone's own file written (`phone_sync.dart`). A phone with
  /// no signal shows its own ledger as it stands, which says how old it is.
  Future<void> _read() async {
    final Uint8List? stored;
    try {
      stored = await widget.keys.readDataKey();
    } on NoSecureStoreException {
      return _go(_Step.key);
    }
    _noKeyKept = stored == null;
    final key = _typedKey ?? stored;
    if (key == null) return _go(_Step.welcome);
    // The ledger was made here (#534): the phone is on its own whatever
    // folder an earlier try left picked. A key being typed is Open ledger's.
    final onItsOwn = _typedKey == null && _startedHere.existsSync();
    _onItsOwn = onItsOwn;
    String? folder;
    if (!onItsOwn) {
      try {
        folder = await widget.folder.kept();
      } catch (e) {
        debugPrint('Asking for the kept folder failed: $e');
        // Figures already up stay up: they say how old they are.
        if (_step != _Step.ready) {
          _record((t) => t.phoneProblemFolderLost, e);
          _go(_Step.folder);
        }
        return;
      }
      if (folder == null) return _go(_Step.folder);
    }
    try {
      // What is waiting on the phone, and the phone's id, which its ledger
      // is opened as: read once, since a phone with nothing kept makes a
      // new id each time it asks.
      final outbox = _outbox ??= PhoneOutbox(
        Directory('${widget.dir.path}/waiting'),
        key,
      );
      final kept = _kept ??= outbox.load();
      final source = _source ??= widget.open(
        dir: widget.dir,
        key: key,
        device: kept.device,
        folder: widget.folder,
      );
      source.onItsOwn = onItsOwn;
      if (onItsOwn) {
        if (!source.joined) {
          // Start fresh's ledger: made the first time it is opened, so a
          // launch cut short after the key was kept still makes it.
          try {
            await source.startNew();
          } catch (e) {
            debugPrint('Making a ledger on the phone failed: $e');
            _record((t) => t.phoneNewLedgerFailed, e);
            _go(_Step.newFailed);
            return;
          }
        }
        final PhoneSnapshot own;
        try {
          own = await source.asItStands(widget.now());
        } catch (e) {
          debugPrint('Opening the ledger on the phone failed: $e');
          if (_step != _Step.ready) {
            _record((t) => t.phoneOwnCantOpen, e);
            _go(_Step.ownCantOpen);
          }
          return;
        }
        _show(own, key, null);
        return;
      }
      final inFolder = folder!;
      if (!source.joined) {
        final found = await widget.folder
            .read(inFolder, ledgerFileName)
            .timeout(phoneFolderPatience);
        if (found == null) {
          // Not there yet (the folder is still arriving): what is up, and an
          // entry half typed, stay.
          if (_step != _Step.ready) _go(_Step.noLedger);
          return;
        }
        await source.join(found.bytes);
      }
      final now = widget.now();
      // A folder that never answers (no signal) isn't waited for: the
      // phone's own ledger is shown as it stands, and the look, when it
      // finishes, brings the figures up to date.
      final looking = source.look(inFolder, now);
      final dataKey = key, at = inFolder, generation = ++_looks;
      PhoneSnapshot snapshot;
      try {
        snapshot = await looking.timeout(phoneFolderPatience);
      } on TimeoutException {
        snapshot = await source.asItStands(now);
        unawaited(
          looking.then((later) {
            // Not over a newer look's figures, nor another ledger's.
            if (generation == _looks && identical(_source, source)) {
              _show(later, dataKey, at);
            }
          }, onError: (Object e) => debugPrint('The late look failed: $e')),
        );
      }
      if (_typedKey != null) {
        await widget.keys.writeDataKey(key);
        _typedKey = null;
        _noKeyKept = false;
        // On a folder now: a mark a Start fresh cut short left isn't this
        // phone's, or losing the folder later would put it on its own.
        _dropStartedHere();
      }
      _show(snapshot, key, inFolder);
    } on WrongKeyException catch (e) {
      if (_typedKey == null) {
        // The key kept here has opened this ledger before, so it is the
        // file that is wrong: half-arrived, or another ledger in the folder.
        if (_step != _Step.ready) {
          _record((t) => t.phoneCantRead, e);
          _go(_Step.cantRead);
        }
        return;
      }
      _typedKey = null;
      // Built with the key that didn't fit: the next is tried afresh, and
      // waiting entries aren't kept under it.
      unawaited(_source?.close());
      _source = null;
      _outbox = null;
      _kept = null;
      _go(_Step.wrongKey);
    } catch (e) {
      debugPrint('Reading the ledger from the folder failed: $e');
      // A look that fails once the figures are up leaves them up: they say
      // how old they are. Only what was shown goes in the record.
      if (_step != _Step.ready) {
        _record((t) => t.phoneCantRead, e);
        _go(_Step.cantRead);
      }
    }
  }

  /// The person's answer to what waits: the choices made and the rest
  /// brought in, or the folder's whole ledger taken. The look that follows
  /// finds what is still to be asked.
  Future<bool> _answer(PhoneAnswer answer) async {
    final source = _source, store = _store;
    if (source == null || store == null) return true;
    // No look runs over the answer, and none still running shows figures
    // from before it.
    _answering = true;
    _looks++;
    var done = false;
    try {
      await _reading;
      final picks = answer.picks;
      final answered = picks != null
          ? await source.answer(picks, widget.now())
          : await source.takeFoldersLedger(widget.now());
      done = answered.done;
      if (identical(_source, source) && mounted) {
        store.snapshot = answered.snapshot;
        if (done) store.asking.value = null;
        final news = source.takeNews();
        if (news.isNotEmpty) store.news.value = news;
      }
    } catch (e) {
      debugPrint('Answering what changed on two computers failed: $e');
      _record((t) => t.phoneProblemAnswer, e);
      done = true;
    } finally {
      _answering = false;
    }
    unawaited(_load());
    return done;
  }

  var _answering = false;

  /// The two whole copies of the folder's ledger an earlier version of the
  /// app kept apart from the phone's own ledger (the private copy it read,
  /// and the one it fell back on): nothing reads them now, and each is a
  /// ledger's worth of the phone's room.
  void _dropOldCopies() {
    for (final name in ['phone', 'phone-last']) {
      try {
        final old = Directory('${widget.dir.path}/$name');
        if (old.existsSync()) old.deleteSync(recursive: true);
      } catch (e) {
        debugPrint('An old copy of the ledger couldn’t be removed: $e');
      }
    }
  }

  /// Puts [snapshot] up, the waiting entries and the half-minute look with
  /// it the first time.
  void _show(PhoneSnapshot snapshot, Uint8List key, String? folder) {
    if (!mounted) return;
    _folder = folder;
    final store = _store;
    if (store == null) {
      _dropOldCopies();
      // What was waiting when the app was last closed comes back.
      final kept = _kept!;
      _store = PhoneStore(
        snapshot,
        device: kept.device,
        waiting: kept.entries,
        made: kept.categories,
        counts: kept.counts,
      )..addListener(_keep);
      final made = _store!;
      made.reconciling.addListener(() {
        if (!made.reconciling.value && mounted && _step == _Step.ready) {
          unawaited(_load());
        }
      });
      made.importing.addListener(() {
        if (!made.importing.value && mounted && _step == _Step.ready) {
          unawaited(_load());
        }
      });
      // A bank file sent from another app, before now or while open.
      unawaited(IncomingFiles.listen((file) => made.sent.value = file));
      _store!.settle = () => _keeping;
      _store!.undoTake = (take) async {
        final source = _source;
        if (source == null) throw StateError('The phone has no ledger open');
        return source.undoTake(take, widget.now());
      };
      _store!.editRowIn = (edit) async {
        final source = _source;
        if (source == null) throw StateError('The phone has no ledger open');
        final done = await source.editRow(edit, widget.now());
        // The next look puts the change in the phone's change file.
        unawaited(_load());
        return done;
      };
      _store!.confirmRowIn = (confirm) async {
        final source = _source;
        if (source == null) throw StateError('The phone has no ledger open');
        final done = await source.confirmRow(confirm, widget.now());
        unawaited(_load());
        return done;
      };
      _store!.actRowIn = (act) async {
        final source = _source;
        if (source == null) throw StateError('The phone has no ledger open');
        final done = await source.actOnRow(act, widget.now());
        unawaited(_load());
        return done;
      };
      _store!.categoryRowsIn = (id) async {
        final source = _source;
        if (source == null) throw StateError('The phone has no ledger open');
        return source.categoryRows(id);
      };
      _store!.planImportIn = (account, rows, keys) async {
        final source = _source;
        if (source == null) throw StateError('The phone has no ledger open');
        return source.planImport(account, rows, keys);
      };
      _store!.restoreRowIn = (row, remembered) async {
        final source = _source;
        if (source == null) throw StateError('The phone has no ledger open');
        final snapshot = await source.restoreRow(
          row,
          widget.now(),
          remembered: remembered,
        );
        unawaited(_load());
        return snapshot;
      };
      // Every half minute while the app is open, whether or not anything
      // waits: the phone is another computer on the ledger (#526), so what
      // the others change is brought in as it happens, not only when the
      // app comes back to the front.
      _again ??= Timer.periodic(widget.every, (_) {
        final store = _store;
        if (_step != _Step.ready || store == null) return;
        _load();
      });
    } else {
      store.snapshot = snapshot;
    }
    final news = _source?.takeNews() ?? const <PhoneNews>[];
    if (news.isNotEmpty) _store?.news.value = news;
    _store?.asking.value = _source?.asking;
    _keep();
    setState(() => _step = _Step.ready);
  }

  /// Keeps what is waiting on the phone and writes it to the folder, one
  /// write at a time. A write that fails (no signal) is tried again at the
  /// next read.
  void _keep() {
    final store = _store, outbox = _outbox, folder = _folder;
    if (store == null || outbox == null) return;
    if (folder == null && !_onItsOwn) return;
    final inbox = store.inbox;
    final send = store.sending;
    // What is kept and what goes: entries held behind a count go once it is
    // taken, which changes only the second.
    final saying = phoneInboxSaying(inbox) + phoneInboxSaying(send);
    if (saying == _sent) return;
    // A phone that has never had anything to say writes no file.
    if (_sent == null && store.nothingWaiting && !outbox.exists) {
      return;
    }
    _sent = saying;
    // Kept on the phone at once: only the folder waits its turn, and a
    // folder that hangs with no signal can't cost an entry.
    final Uint8List bytes;
    try {
      bytes = outbox.save(inbox, send: identical(send, inbox) ? null : send);
      _saveFailing = false;
    } catch (e) {
      debugPrint('Keeping this phone’s entries failed: $e');
      if (!_saveFailing) _record((t) => t.phoneProblemNotKept, e);
      _saveFailing = true;
      _sent = null;
      return;
    }
    final source = _source;
    final nothingToTake =
        inbox.entries.isEmpty &&
        inbox.categories.isEmpty &&
        inbox.counts.isEmpty;
    if (source != null && !_demo && !nothingToTake) {
      // Into the phone's own ledger at once (#526 piece 4): the change file
      // the next look writes carries it to the others, and what was taken
      // is let go of here as the ledger lists it.
      _keeping = _keeping.then((_) async {
        try {
          final took = await source.take(inbox, widget.now());
          if (took != null) {
            store.tookInto([
              for (final e in inbox.entries) e.id,
              for (final c in inbox.counts) c.id,
              for (final c in inbox.categories) c.id,
            ], took.take);
            if (identical(_source, source) && mounted) {
              store.snapshot = took.snapshot;
            }
            if (folder != null) await _dropOwnFile(folder, inbox.device);
            unawaited(_load());
            return;
          }
        } catch (e) {
          // Kept on the phone: the next change tries again.
          debugPrint('Taking this phone’s entries into its ledger failed: $e');
          if (!_saveFailing) _record((t) => t.phoneProblemNotKept, e);
          _saveFailing = true;
          if (_sent == saying) _sent = null;
          return;
        }
        if (folder != null) await _writeOwnFile(folder, inbox, bytes, saying);
      });
      return;
    }
    // On its own the phone has no folder to write its entries to.
    if (folder == null) return;
    _keeping = _keeping.then(
      (_) => _writeOwnFile(folder, inbox, bytes, saying),
    );
  }

  /// A phone's own file of entries, which the computers took in before the
  /// phone had a ledger of its own: what is in the ledger now is carried in
  /// the change file, so the file goes, or a computer would bring an entry
  /// the person has since taken back in again.
  Future<void> _dropOwnFile(String folder, String device) async {
    try {
      await widget.folder.delete(folder, phoneInboxName(device));
    } catch (e) {
      debugPrint('The phone’s old file of entries couldn’t be removed: $e');
    }
  }

  Future<void> _writeOwnFile(
    String folder,
    PhoneInbox inbox,
    Uint8List bytes,
    String saying,
  ) async {
    try {
      await widget.folder.write(folder, phoneInboxName(inbox.device), bytes);
    } catch (e) {
      // Not a problem to keep: with no signal this is the phone working
      // as it should, and Budget says what waits for the computer.
      debugPrint('Writing this phone’s entries to the folder failed: $e');
      if (_sent == saying) _sent = null;
    }
  }

  /// The demo key was typed: invented figures, nothing read or kept.
  var _demo = false;

  /// Made-up figures, nothing read or kept: for Play's review (#303).
  void _openDemo() {
    _keyText.clear();
    setState(() {
      _demo = true;
      _keyError = null;
      _store = PhoneStore(previewSnapshot(widget.now()));
      _step = _Step.ready;
    });
  }

  void _useKey() {
    if (isPhoneDemoKey(_keyText.text)) return _openDemo();
    final problem = RecoveryKey.check(_keyText.text);
    final key = problem == null ? RecoveryKey.parse(_keyText.text) : null;
    if (key == null) {
      setState(
        () => _keyError = problem == null
            ? context.t.startKeyChecksum
            : keyProblem(context.t, problem),
      );
      return;
    }
    _typedKey = deriveDataKey(key);
    _keyText.clear();
    setState(() {
      _keyError = null;
      _step = _Step.loading;
    });
    _load();
  }

  /// The phone's own ledger as an earlier install left it, with no key to
  /// open it: moved aside, never deleted, before a new one is made here, as
  /// a computer sets aside the ledger it can't open.
  Future<void> _setAsideOwn() async {
    final own = phoneOwnDir(widget.dir);
    if (!own.existsSync()) return;
    final stamp = widget.now().toIso8601String().replaceAll(':', '-');
    await own.rename('${own.path}.set-aside-$stamp');
  }

  void _dropStartedHere() {
    try {
      if (_startedHere.existsSync()) _startedHere.deleteSync();
    } catch (e) {
      debugPrint('The mark of a ledger made here couldn’t be removed: $e');
    }
  }

  /// A folder an earlier try picked: a ledger made here isn't that folder's.
  Future<void> _forgetFolder() async {
    try {
      final before = await widget.folder.kept();
      if (before != null) await widget.folder.forget(before);
    } catch (e) {
      debugPrint('Forgetting the folder picked before failed: $e');
    }
  }

  /// Leaves a way that didn't work for "How do you want to start?": nothing
  /// typed or opened on the way is kept.
  Future<void> _backToStart() async {
    _typedKey = null;
    _keyText.clear();
    _keyError = null;
    await _reading;
    final leaving = _source;
    _source = null;
    _outbox = null;
    _kept = null;
    await leaving?.close();
    await _forgetFolder();
    _go(_Step.welcome);
  }

  /// Start fresh: a new key, shown once before anything is kept.
  void _startFresh() => setState(() {
    _typedKey = null;
    _newKey = RecoveryKey.generate(random: widget.random);
    _step = _Step.newKey;
  });

  /// Continue under the new key ([copied]: Copy was tapped): the phone is
  /// marked as on its own, the key kept, and the ledger made by the look
  /// that follows, so a launch cut short between them still ends with a
  /// ledger under the kept key, or back at the first screen. A failure
  /// takes the mark back and keeps the key on screen, so Try again uses
  /// the key the person may have written down.
  Future<void> _keepNewKey({bool copied = false}) async {
    final recovery = _newKey;
    if (recovery == null) return;
    _typedKey = null;
    try {
      await _setAsideOwn();
      await widget.dir.create(recursive: true);
      await _startedHere.writeAsString('1', flush: true);
      await widget.keys.writeDataKey(deriveDataKey(recovery));
    } catch (e) {
      debugPrint('Keeping the new key on the phone failed: $e');
      _dropStartedHere();
      _record((t) => t.phoneNewLedgerFailed, e);
      _go(_Step.newFailed);
      return;
    }
    await _keptCopied(copied);
    _newKey = null;
    await _forgetFolder();
    _go(_Step.loading);
    await _load();
  }

  /// Whether Copy was tapped, as the computer keeps it, for Check my
  /// recovery key later; nothing is lost when it can't be kept.
  Future<void> _keptCopied(bool copied) async {
    try {
      await widget.keys.writeKeySaved(copied);
    } catch (e) {
      debugPrint('Keeping whether the key was copied failed: $e');
    }
  }

  /// Restore from backup with [recovery]: the file picked, then made the
  /// phone's own ledger as a computer with no ledger restores one. Returns
  /// what to say under the row when it can't be, or null.
  Future<String?> _restore(RecoveryKey recovery) async {
    final t = context.t;
    final XFile? picked;
    try {
      picked = await openFile();
    } catch (e) {
      debugPrint('The phone\'s file picker failed: $e');
      return t.ledgerCouldntOpenFileDialog;
    }
    if (picked == null) return null;
    _typedKey = null;
    final key = deriveDataKey(recovery);
    PhoneLedgerSource? source;
    var marked = false;
    try {
      await _setAsideOwn();
      // Read, nothing set aside, until the key is known to open the backup:
      // what waits from before may be this key's on the next try.
      final outbox = PhoneOutbox(Directory('${widget.dir.path}/waiting'), key);
      final waiting = outbox.peek();
      final device = waiting?.device ?? newPhoneDevice();
      source = widget.open(
        dir: widget.dir,
        key: key,
        device: device,
        folder: widget.folder,
      );
      await source.restoreFrom(picked.path, widget.now());
      await widget.dir.create(recursive: true);
      await _startedHere.writeAsString('1', flush: true);
      marked = true;
      await widget.keys.writeDataKey(key);
      // The key opens the backup: a file it can't read isn't this ledger's.
      if (waiting == null) outbox.setAside();
      _outbox = outbox;
      _kept = waiting ?? PhoneInbox(device: device);
      _source = source;
      _noKeyKept = false;
    } on RestoreException catch (e) {
      await source?.close();
      // Its own key isn't asked for here: the one typed is the only one.
      return restoreProblem(
        t,
        e.problem == RestoreProblem.needsKey
            ? RestoreProblem.wrongKey
            : e.problem,
      );
    } catch (e) {
      debugPrint('Restoring a backup on the phone failed: $e');
      await source?.close();
      if (marked) _dropStartedHere();
      _record((t) => t.phoneRestoreFailed, e);
      return t.phoneRestoreFailed;
    } finally {
      await dropPhonePickedCopy(picked.path);
    }
    await _forgetFolder();
    _go(_Step.loading);
    await _load();
    return null;
  }

  /// Open ledger with [recovery]: the key is tried on the folder's ledger
  /// once the folder is picked, as before.
  Future<String?> _openWith(RecoveryKey recovery) async {
    await _pickFolder(withKey: deriveDataKey(recovery));
    return null;
  }

  /// [withKey]: the key typed under Open ledger, taken only once a folder
  /// is picked, so a picker cancelled leaves no key behind for Start fresh.
  Future<void> _pickFolder({Uint8List? withKey}) async {
    final String? picked;
    try {
      final before = await widget.folder.kept();
      picked = await widget.folder.pick();
      if (picked != null && before != null && before != picked) {
        await widget.folder.forget(before);
        // The ledger of the folder it leaves isn't this one's: the phone
        // takes the new folder's as its own. (Nothing is lost: what the
        // phone made waits apart, and writes nothing to its ledger yet.)
        await _reading;
        final leaving = _source;
        _source = null;
        await leaving?.leave();
      }
    } catch (e) {
      debugPrint('Picking a folder failed: $e');
      return;
    }
    if (picked == null) return;
    if (withKey != null) _typedKey = withKey;
    _go(_Step.loading);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // Before any key is kept, a way that didn't work can be left for
    // another.
    final back = _noKeyKept ? () => unawaited(_backToStart()) : null;
    return switch (_step) {
      _Step.loading => Scaffold(backgroundColor: Mid.ground),
      _Step.ready => PhoneHome(
        store: _store!,
        now: widget.now,
        // On its own there is no folder to look at again.
        onRefresh: _demo || _onItsOwn ? null : _load,
        onAnswer: _demo ? null : _answer,
        problems: _problems,
        note: _demo ? t.phoneDemoNote : null,
      ),
      _Step.welcome => _Welcome(
        onFresh: _startFresh,
        onRestore: _restore,
        onOpen: _openWith,
        onDemo: _openDemo,
      ),
      _Step.newKey => _NewKey(
        recoveryKey: _newKey!,
        onContinue: (copied) => _keepNewKey(copied: copied),
        onCancel: () => setState(() {
          _newKey = null;
          _step = _Step.welcome;
        }),
      ),
      _Step.newFailed => _Ask(
        title: t.phoneNewLedgerFailed,
        action: t.phoneTryAgain,
        // The same key while it is still on hand: it may be written down.
        onAction: _newKey != null
            ? () => _keepNewKey()
            : () {
                _go(_Step.loading);
                _load();
              },
        report: true,
      ),
      _Step.ownCantOpen => _Ask(
        title: t.phoneOwnCantOpen,
        action: t.phoneTryAgain,
        onAction: () {
          _go(_Step.loading);
          _load();
        },
        report: true,
      ),
      _Step.key => _Ask(
        onBack: back,
        title: t.phoneKeyTitle,
        body: t.phoneKeyBody,
        field: _PhoneKeyField(
          fieldKey: const ValueKey('phone-key'),
          controller: _keyText,
          error: _keyError,
          onSubmitted: _useKey,
        ),
        action: t.startContinue,
        onAction: _useKey,
      ),
      _Step.folder => _Ask(
        onBack: back,
        title: t.phoneFolderTitle,
        body: t.phoneFolderBody,
        action: t.phoneFolderChoose,
        onAction: _pickFolder,
        report: true,
      ),
      _Step.noLedger => _Ask(
        onBack: back,
        title: t.phoneNoLedger,
        body: t.phoneNoLedgerBody(ledgerFileName),
        action: t.phoneTryAgain,
        onAction: () {
          _go(_Step.loading);
          _load();
        },
        other: t.phoneChooseAnother,
        onOther: _pickFolder,
        report: true,
      ),
      _Step.wrongKey => _Ask(
        onBack: back,
        title: t.phoneKeyDoesntOpen,
        action: t.phoneEnterKeyAgain,
        onAction: () => _go(_Step.key),
        other: t.phoneChooseAnother,
        onOther: _pickFolder,
        report: true,
      ),
      _Step.cantRead => _Ask(
        onBack: back,
        title: t.phoneCantRead,
        body: t.phoneCantReadBody,
        action: t.phoneTryAgain,
        onAction: () {
          _go(_Step.loading);
          _load();
        },
        other: t.phoneChooseAnother,
        onOther: _pickFolder,
        report: true,
      ),
    };
  }
}

/// The box a recovery key is typed into on the phone: one line at the phone's
/// width, and a keyboard that neither learns the key nor offers it back.
class _PhoneKeyField extends StatelessWidget {
  const _PhoneKeyField({
    required this.fieldKey,
    required this.controller,
    required this.onSubmitted,
    this.error,
    this.onChanged,
  });
  final Key fieldKey;
  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final VoidCallback? onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) => TextField(
    key: fieldKey,
    controller: controller,
    autofocus: true,
    autocorrect: false,
    enableSuggestions: false,
    keyboardType: TextInputType.visiblePassword,
    enableIMEPersonalizedLearning: false,
    textCapitalization: TextCapitalization.characters,
    // The whole key on one line inside Open ledger's card.
    style: onest(16),
    cursorColor: Mid.blue,
    decoration: InputDecoration(
      hintText: 'ABCDE-FGHJK-LMNPQ-RSTUV-WXYZ0',
      hintStyle: onest(16, color: Mid.ink3),
      errorText: error,
      errorMaxLines: 3,
      errorStyle: onest(14, color: Mid.coral),
    ),
    onSubmitted: (_) => onSubmitted(),
    onChanged: (_) => onChanged?.call(),
  );
}

/// The ways a ledger comes to a phone with none (#534, the owner's pick of
/// sketch A: "let's do a"), the computer's three in its words: Start fresh,
/// Restore from backup, Open ledger. The two that need the recovery key open
/// where they are tapped, with the box and the button that picks, as on the
/// computer; a tap on the open one's name closes it.
class _Welcome extends StatefulWidget {
  const _Welcome({
    required this.onFresh,
    required this.onRestore,
    required this.onOpen,
    required this.onDemo,
  });
  final VoidCallback onFresh;

  /// With the key typed; each returns what to say under the box, or null.
  final Future<String?> Function(RecoveryKey key) onRestore;
  final Future<String?> Function(RecoveryKey key) onOpen;

  /// The demo key typed in either box (#303).
  final VoidCallback onDemo;

  @override
  State<_Welcome> createState() => _WelcomeState();
}

enum _Way { restore, open }

class _WelcomeState extends State<_Welcome> {
  final _controller = TextEditingController();
  _Way? _open;
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final way = _open;
    if (_busy || way == null) return;
    final t = context.t;
    if (isPhoneDemoKey(_controller.text)) return widget.onDemo();
    final problem = RecoveryKey.check(_controller.text);
    final key = problem == null ? RecoveryKey.parse(_controller.text) : null;
    if (key == null) {
      setState(
        () => _error = problem == null
            ? t.startKeyChecksum
            : keyProblem(t, problem),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final said = await (way == _Way.restore
        ? widget.onRestore(key)
        : widget.onOpen(key));
    if (mounted) {
      setState(() {
        _busy = false;
        _error = said;
      });
    }
  }

  Widget _heading(String title, String note, {Color? ink, Color? ink2}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: onest(17, weight: 600, color: ink)),
          const SizedBox(height: 4),
          Text(note, style: onest(14, color: ink2 ?? Mid.ink2, height: 1.4)),
        ],
      );

  Widget _keyed(_Way way, String key, String title, String note, String act) {
    final t = context.t;
    final open = _open == way;
    return Material(
      color: Mid.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: open
            ? BorderSide(color: Mid.blue, width: 1.5)
            : BorderSide(color: Mid.rule),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: ValueKey(key),
            onTap: _busy
                ? null
                : () => setState(() {
                    _open = open ? null : way;
                    _error = null;
                  }),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 76),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: _heading(title, note),
              ),
            ),
          ),
          if (open)
            Padding(
              key: ValueKey('$key-open'),
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t.startKeyLabel, style: onest(14, color: Mid.ink3)),
                  _PhoneKeyField(
                    fieldKey: const ValueKey('phone-key'),
                    controller: _controller,
                    error: _error,
                    onSubmitted: _submit,
                    onChanged: () {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.startKeyHint,
                    style: onest(14, color: Mid.ink3, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: ValueKey('$key-choose'),
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: Mid.fill,
                      foregroundColor: Mid.onFill,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: onest(17, weight: 600),
                    ),
                    child: Text(act),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      backgroundColor: Mid.ground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.startHowTitle, style: onest(28, weight: 600, height: 1.2)),
              const SizedBox(height: 24),
              // The way most people with only a phone take, filled.
              Material(
                color: Mid.fill,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const ValueKey('start-fresh'),
                  onTap: _busy ? null : widget.onFresh,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 76),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: _heading(
                        t.startFresh,
                        t.startFreshNote,
                        ink: Mid.onFill,
                        ink2: Mid.onFill,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _keyed(
                _Way.restore,
                'start-restore',
                t.startRestore,
                t.phoneStartRestoreNote,
                t.startChooseBackup,
              ),
              const SizedBox(height: 12),
              _keyed(
                _Way.open,
                'start-open',
                t.startOpen,
                t.phoneStartOpenNote,
                t.startChooseFolder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Start fresh's recovery key, shown once before anything is kept (#534),
/// as the computer shows it: what it is, the key, where to keep it, Copy,
/// and a warning while it hasn't been copied. Continue goes on either way
/// (warn, don't block); Cancel goes back with nothing kept.
class _NewKey extends StatefulWidget {
  const _NewKey({
    required this.recoveryKey,
    required this.onContinue,
    required this.onCancel,
  });
  final RecoveryKey recoveryKey;

  /// With whether Copy was tapped.
  final Future<void> Function(bool copied) onContinue;
  final VoidCallback onCancel;

  @override
  State<_NewKey> createState() => _NewKeyState();
}

class _NewKeyState extends State<_NewKey> {
  var _copied = false;
  var _busy = false;

  Future<void> _continue() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onContinue(_copied);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      backgroundColor: Mid.ground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.startKeyTitle, style: onest(28, weight: 600, height: 1.2)),
              const SizedBox(height: 12),
              Text(
                t.phoneNewKeyIntro,
                style: onest(16, color: Mid.ink2, height: 1.4),
              ),
              const SizedBox(height: 20),
              RecoveryKeyDisplay(display: widget.recoveryKey.display),
              const SizedBox(height: 8),
              Text(
                t.phoneNewKeyWhere,
                style: onest(14, color: Mid.ink3, height: 1.4),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey('copy-recovery-key'),
                  onPressed: () async {
                    await copyRecoveryKey(widget.recoveryKey.display);
                    if (mounted) setState(() => _copied = true);
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: Mid.blue,
                    side: BorderSide(color: Mid.rule),
                    textStyle: onest(16),
                  ),
                  icon: Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 18,
                    color: _copied ? Mid.green : Mid.blue,
                  ),
                  label: Text(_copied ? t.startCopied : t.startCopy),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _copied
                    ? t.phoneNewKeyCopiedWarning
                    : t.phoneNewKeyNotKeptWarning,
                key: const ValueKey('recovery-key-warning'),
                style: onest(
                  14,
                  color: _copied ? Mid.ink2 : Mid.coral,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey('recovery-key-continue'),
                onPressed: _busy ? null : _continue,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: Mid.fill,
                  foregroundColor: Mid.onFill,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: onest(17, weight: 600),
                ),
                child: Text(t.startContinue),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('recovery-key-cancel'),
                onPressed: _busy ? null : widget.onCancel,
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: Mid.blue,
                  textStyle: onest(16),
                ),
                child: Text(t.ledgerCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One question on a screen: what is asked, why, an optional box, a button,
/// and sometimes a second way out under it. A problem screen ends with
/// Send feedback… (#292): the ledger not opening is when it's needed most.
class _Ask extends StatelessWidget {
  const _Ask({
    required this.title,
    this.body,
    this.field,
    required this.action,
    required this.onAction,
    this.other,
    this.onOther,
    this.report = false,
    this.onBack,
  });

  /// Other ways to start, under a problem reached before any key is kept.
  final VoidCallback? onBack;
  final String title;
  final String? body;
  final Widget? field;
  final String action;
  final VoidCallback onAction;
  final String? other;
  final VoidCallback? onOther;
  final bool report;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Mid.ground,
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: onest(24, weight: 600, height: 1.25)),
            if (body != null) ...[
              const SizedBox(height: 12),
              Text(body!, style: onest(16, color: Mid.ink2, height: 1.4)),
            ],
            if (field != null) ...[const SizedBox(height: 24), field!],
            const SizedBox(height: 28),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: Mid.fill,
                foregroundColor: Mid.onFill,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: onest(17, weight: 600),
              ),
              child: Text(action),
            ),
            if (other != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onOther,
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: Mid.blue,
                  textStyle: onest(16),
                ),
                child: Text(other!),
              ),
            ],
            if (onBack != null) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('other-ways'),
                onPressed: onBack,
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: Mid.blue,
                  textStyle: onest(16),
                ),
                child: Text(context.t.phoneOtherWays),
              ),
            ],
            if (report) const ReportProblemLine(),
          ],
        ),
      ),
    ),
  );
}
