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
import '../../data/problem_log.dart';
import '../../domain/phone.dart';
import '../data_words.dart';
import '../language.dart';
import '../theme.dart';
import 'phone_app.dart';

/// Reads what the phone shows from the ledger's bytes; swapped in tests.
typedef ReadPhoneLedger = Future<PhoneSnapshot> Function(
  Uint8List bytes,
  Uint8List dataKey, {
  required Directory dir,
  required DateTime today,
  required DateTime madeAt,
});

enum _Step { loading, key, folder, noLedger, wrongKey, cantRead, ready }

class PhoneStart extends StatefulWidget {
  const PhoneStart({
    super.key,
    required this.keys,
    required this.dir,
    this.folder = const PhoneFolder(),
    this.read = readPhoneLedger,
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

  /// Where the phone keeps its private copy of the ledger.
  final Directory dir;
  final PhoneFolder folder;
  final ReadPhoneLedger read;
  final DateTime Function() now;

  @override
  State<PhoneStart> createState() => _PhoneStartState();
}

class _PhoneStartState extends State<PhoneStart> with WidgetsBindingObserver {
  _Step _step = _Step.loading;
  PhoneStore? _store;
  PhoneOutbox? _outbox;
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

  /// Writing to the folder has failed since it last worked: kept once, not
  /// at every try.
  var _writeFailing = false;

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
    _keyText.dispose();
    super.dispose();
  }

  /// Back at the front: the folder may hold a newer ledger by now.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _step == _Step.ready) _load();
  }

  void _go(_Step step) {
    if (mounted) setState(() => _step = step);
  }

  /// One read at a time: a pull down while the app is coming back to the
  /// front would have two reads writing the same private copy.
  Future<void>? _reading;

  Future<void> _load({bool onlyIfNewer = false}) =>
      _reading ??= _read(onlyIfNewer: onlyIfNewer)
          .whenComplete(() => _reading = null);

  /// When the ledger last read was changed in the folder.
  DateTime? _ledgerChanged;
  var _quietLooks = 0;

  /// [onlyIfNewer] is the look taken by itself while the app is open: it
  /// asks the folder when the ledger was changed and fetches it only when
  /// that has moved, so waiting for the computer doesn't cost a copy of
  /// the whole ledger over mobile data every half minute.
  Future<void> _read({bool onlyIfNewer = false}) async {
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
      _record((t) => t.phoneProblemFolderLost, e);
      return _go(_Step.folder);
    }
    if (folder == null) return _go(_Step.folder);
    try {
      // Every fourth look fetches whatever the folder says: on the owner's
      // Pixel, Drive went on giving the old time for minutes after the
      // computer had written a newer ledger (2026-10-08).
      if (onlyIfNewer && ++_quietLooks % 4 != 0) {
        final at = await widget.folder.changed(folder, ledgerFileName);
        if (at != null && at == _ledgerChanged) {
          // Still a chance to send what an earlier write couldn't.
          _keep();
          return;
        }
      }
      final found = await widget.folder.read(folder, ledgerFileName);
      if (found == null) {
        // Not there on a later read (the folder is still arriving): what is
        // up, and an entry half typed, stay.
        if (_step != _Step.ready) _go(_Step.noLedger);
        return;
      }
      final now = widget.now();
      final snapshot = await widget.read(
        found.bytes,
        key,
        dir: Directory('${widget.dir.path}/phone'),
        today: now,
        madeAt: found.changed ?? now,
      );
      if (_typedKey != null) {
        await widget.keys.writeDataKey(key);
        _typedKey = null;
      }
      if (!mounted) return;
      _ledgerChanged = found.changed;
      _folder = folder;
      final store = _store;
      if (store == null) {
        // What was waiting when the app was last closed comes back.
        final outbox = _outbox = PhoneOutbox(
          Directory('${widget.dir.path}/waiting'),
          key,
        );
        final kept = outbox.load();
        _store = PhoneStore(
          snapshot,
          device: kept.device,
          waiting: kept.entries,
          made: kept.categories,
        )..addListener(_keep);
        // Only while something is waiting: that is all there is to wait
        // for. Coming back to the front always reads.
        _again ??= Timer.periodic(widget.every, (_) {
          final store = _store;
          if (_step != _Step.ready || store == null) return;
          if (store.waiting.isEmpty && store.made.isEmpty) return;
          _load(onlyIfNewer: true);
        });
      } else {
        store.snapshot = snapshot;
      }
      _keep();
      setState(() => _step = _Step.ready);
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
      _go(_Step.wrongKey);
    } catch (e) {
      debugPrint('Reading the ledger from the folder failed: $e');
      // A read that fails once the figures are up leaves them up: they say
      // how old they are. Only what was shown goes in the record.
      if (_step != _Step.ready) {
        _record((t) => t.phoneCantRead, e);
        _go(_Step.cantRead);
      }
    }
  }

  /// Keeps what is waiting on the phone and writes it to the folder, one
  /// write at a time. A write that fails (no signal) is tried again at the
  /// next read.
  void _keep() {
    final store = _store, outbox = _outbox, folder = _folder;
    if (store == null || outbox == null || folder == null) return;
    final inbox = store.inbox;
    final saying = [
      for (final e in inbox.entries) '${e.id}>${e.categoryId}',
      for (final c in inbox.categories) c.id,
    ].join(',');
    if (saying == _sent) return;
    // A phone that has never had anything to say writes no file.
    if (_sent == null && saying.isEmpty && !outbox.exists) return;
    _sent = saying;
    // Kept on the phone at once: only the folder waits its turn, and a
    // folder that hangs with no signal can't cost an entry.
    final Uint8List bytes;
    try {
      bytes = outbox.save(inbox);
    } catch (e) {
      debugPrint('Keeping this phone’s entries failed: $e');
      _record((t) => t.phoneProblemNotKept, e);
      _sent = null;
      return;
    }
    _keeping = _keeping.then((_) async {
      try {
        await widget.folder.write(folder, phoneInboxName(inbox.device), bytes);
        _writeFailing = false;
      } catch (e) {
        debugPrint('Writing this phone’s entries to the folder failed: $e');
        if (!_writeFailing) _record((t) => t.phoneProblemNotWritten, e);
        _writeFailing = true;
        if (_sent == saying) _sent = null;
      }
    });
  }

  void _useKey() {
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
        onRefresh: _load,
        problems: _problems,
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
/// Report a problem… (#292): the ledger not opening is when it's needed most.
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
