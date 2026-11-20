// The phone app's first minute (ADR 0005): the recovery key, once; the folder
// the ledger was moved to, once; then the ledger read from that folder, and
// read again whenever the app comes back to the front, and every half minute
// while it is open. What is typed here is kept on the phone and written to the
// same folder, in the phone's own file, for the computer to take in.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/keys.dart';
import '../../data/ledger_file.dart';
import '../../data/phone_inbox.dart';
import '../../data/phone_ledger.dart';
import '../../data/phone_sync.dart';
import '../../data/problem_log.dart';
import '../../domain/phone.dart';
import '../data_words.dart';
import '../language.dart';
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

enum _Step { loading, key, folder, noLedger, wrongKey, cantRead, ready }

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
  });

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
    return _reading ??= _read().whenComplete(() => _reading = null);
  }

  /// Looks at the folder: the first time the ledger in it becomes this
  /// phone's own, and from then on the other computers' changes are brought
  /// in and this phone's own file written (`phone_sync.dart`). A phone with
  /// no signal shows its own ledger as it stands, which says how old it is.
  Future<void> _read() async {
    final Uint8List? key;
    try {
      key = _typedKey ?? await widget.keys.readDataKey();
    } on NoSecureStoreException {
      return _go(_Step.key);
    }
    if (key == null) return _go(_Step.key);
    final String? folder;
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
      if (!source.joined) {
        final found = await widget.folder
            .read(folder, ledgerFileName)
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
      final looking = source.look(folder, now);
      final dataKey = key, at = folder, generation = ++_looks;
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
      }
      _show(snapshot, key, folder);
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
  void _show(PhoneSnapshot snapshot, Uint8List key, String folder) {
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
      _store!.restoreRowIn = (row) async {
        final source = _source;
        if (source == null) throw StateError('The phone has no ledger open');
        final snapshot = await source.restoreRow(row, widget.now());
        unawaited(_load());
        return snapshot;
      };
      // Only while something is waiting: that is all there is to wait
      // for. Coming back to the front always reads.
      _again ??= Timer.periodic(widget.every, (_) {
        final store = _store;
        if (_step != _Step.ready || store == null) return;
        // Also while the computers haven't applied what the phone entered.
        if (store.nothingOnTheWay) return;
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
    if (store == null || outbox == null || folder == null) return;
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
            await _dropOwnFile(folder, inbox.device);
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
        await _writeOwnFile(folder, inbox, bytes, saying);
      });
      return;
    }
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

  void _useKey() {
    if (isPhoneDemoKey(_keyText.text)) {
      _keyText.clear();
      setState(() {
        _demo = true;
        _keyError = null;
        _store = PhoneStore(previewSnapshot(widget.now()));
        _step = _Step.ready;
      });
      return;
    }
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

  Future<void> _pickFolder() async {
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
    _go(_Step.loading);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return switch (_step) {
      _Step.loading => Scaffold(backgroundColor: Mid.ground),
      _Step.ready => PhoneHome(
        store: _store!,
        now: widget.now,
        onRefresh: _demo ? null : _load,
        onAnswer: _demo ? null : _answer,
        problems: _problems,
        note: _demo ? t.phoneDemoNote : null,
      ),
      _Step.key => _Ask(
        title: t.phoneKeyTitle,
        body: t.phoneKeyBody,
        field: TextField(
          key: const ValueKey('phone-key'),
          controller: _keyText,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          // The keyboard isn't to learn the key or offer it back.
          keyboardType: TextInputType.visiblePassword,
          enableIMEPersonalizedLearning: false,
          textCapitalization: TextCapitalization.characters,
          style: onest(16, letterSpacing: 0.5),
          cursorColor: Mid.blue,
          decoration: InputDecoration(
            hintText: 'ABCDE-FGHJK-LMNPQ-RSTUV-WXYZ0',
            hintStyle: onest(16, color: Mid.ink3, letterSpacing: 0.5),
            errorText: _keyError,
            errorMaxLines: 3,
            errorStyle: onest(14, color: Mid.coral),
          ),
          onSubmitted: (_) => _useKey(),
        ),
        action: t.startContinue,
        onAction: _useKey,
      ),
      _Step.folder => _Ask(
        title: t.phoneFolderTitle,
        body: t.phoneFolderBody,
        action: t.phoneFolderChoose,
        onAction: _pickFolder,
        report: true,
      ),
      _Step.noLedger => _Ask(
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
        title: t.phoneKeyDoesntOpen,
        action: t.phoneEnterKeyAgain,
        onAction: () => _go(_Step.key),
        other: t.phoneChooseAnother,
        onOther: _pickFolder,
        report: true,
      ),
      _Step.cantRead => _Ask(
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
  });
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
            if (report) const ReportProblemLine(),
          ],
        ),
      ),
    ),
  );
}
