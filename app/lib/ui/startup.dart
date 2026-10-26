// What happens at launch (ADR 0001). The order matters: a key is checked
// against the ledger before it's stored, so a key that doesn't fit is never
// kept, and a new key is shown before it's stored or anything is encrypted,
// so a quit or crash never leaves data locked under a key nobody saw.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;

import '../data/backup.dart';
import '../data/cloud_folder.dart';
import '../data/database.dart';
import '../data/encryption.dart';
import '../data/keys.dart';
import '../data/ledger_file.dart';
import '../data/report_problem.dart';
import '../domain/ledger.dart' show dateKey, dateOnly;
import '../domain/setup.dart' show SetupKeys;
import 'copy_details.dart';
import 'data_words.dart';
import 'fit_window.dart';
import 'language.dart';
import 'ledger_screen.dart';
import 'recovery_key_screen.dart';
import 'register.dart' show Hoverable;
import 'start_choice.dart';
import 'theme.dart';

/// The ledger, opened (and converted if it was plain), with what converting
/// its old copies did. [startDaily] starts the daily copies, only once the
/// launch has finished, so a launch that fails and is tried again leaves no
/// timer running on a ledger it closed.
typedef OpenedLedger = ({
  AppDatabase db,
  Backups backups,
  ConversionReport report,
  void Function() startDaily,
});

/// The key kept on this computer couldn't be read (the Keychain refused
/// it): nothing past reading it was tried.
class _KeyNotRead implements Exception {
  _KeyNotRead(this.error);
  final Object error;
}

sealed class _Step {}

class _Loading extends _Step {}

/// No ledger and no key here: asked first how they want to start.
class _Welcome extends _Step {}

/// Why the entry screen asks for a key. Worded at build time, under the
/// MaterialApp that knows the language.
enum _EntryWhy { keptKeyWrong, ledgerHere }

class _Entry extends _Step {
  _Entry(this.why, {required this.ledgerHere});
  final _EntryWhy why;
  final bool ledgerHere;
}

class _Setup extends _Step {
  _Setup(this.key, {required this.convertingExisting});
  final RecoveryKey key;
  final bool convertingExisting;
}

class _Running extends _Step {
  _Running(this.opened, this.dataKey, {this.offerBackup = false});
  final OpenedLedger opened;
  final Uint8List dataKey;
  final bool offerBackup;
}

/// Which step of a launch couldn't finish: the key kept here couldn't be
/// read, a new key couldn't be stored (nothing encrypted), or opening failed.
enum _FailedAt { keyNotRead, keyNotKept, open }

/// A launch that couldn't finish, with what went wrong and the step to do
/// again.
class _Failed extends _Step {
  _Failed(this.error, this.at, {required this.retry});
  final Object error;
  final _FailedAt at;
  final Future<void> Function() retry;
}

class BetterBudgetStartup extends StatefulWidget {
  const BetterBudgetStartup({
    super.key,
    required this.store,
    required this.ledgerFile,
    required this.open,
    this.clock = DateTime.now,
  });

  final KeyStore store;

  /// `Ledger.betterbudget`, which may not exist yet.
  final File ledgerFile;

  /// Opens the ledger with the key, encrypting it first if it's plain, and
  /// converts its old plain copies.
  final Future<OpenedLedger> Function(Uint8List key) open;
  final DateTime Function() clock;

  @override
  State<BetterBudgetStartup> createState() => _BetterBudgetStartupState();
}

class _BetterBudgetStartupState extends State<BetterBudgetStartup> {
  _Step _step = _Loading();

  /// False only on Linux with no Secret Service: nothing can be stored, and
  /// the key is asked for at every launch.
  bool _canPersist = true;
  bool _keySaved = false;

  /// Which way of bringing a ledger here was chosen on the first screen.
  StartFrom? _startFrom;

  /// The folder or backup file picked there, which the typed key opens.
  String? _startPath;

  /// Whether the failure screen is showing the error itself.
  bool _details = false;

  /// Whether the browser wouldn't open Report a problem…'s form; there is no
  /// popup here, so the screen says where the form is.
  bool _reportFailed = false;

  File get _file => widget.ledgerFile;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<bool> _encryptedLedgerHere() async =>
      _file.existsSync() && !await isPlainSqliteFile(_file);

  /// Never leaves the window blank: a Keychain that refuses the key (a
  /// locked Mac, -25308) or a file that can't be read is said, with Try
  /// again.
  Future<void> _start() async {
    try {
      await _resolve();
    } on _KeyNotRead catch (k) {
      debugPrint('Reading the key failed: ${_safe(k.error)}');
      _go(_Failed(k.error, _FailedAt.keyNotRead, retry: _start));
    } catch (e) {
      debugPrint('Starting failed: ${_safe(e)}');
      _go(_Failed(e, _FailedAt.open, retry: _start));
    }
  }

  /// Only Keychain reads, so a failure here has touched nothing.
  static Future<T> _readKey<T>(Future<T> Function() read) async {
    try {
      return await read();
    } catch (e) {
      throw _KeyNotRead(e);
    }
  }

  /// An error as it may be logged or shown. Only errors known to carry no
  /// key are written out; any other is named by its type (a damaged stored
  /// key fails base64 with the key's own text in its message).
  static String _safe(Object e) =>
      e is PlatformException || e is FileSystemException || e is CipherException
      ? '$e'
      : '${e.runtimeType}';

  Future<void> _resolve() async {
    final result = await _readKey(() => resolveDataKey(widget.store));
    final plain = await isPlainSqliteFile(_file);
    final encrypted = await _encryptedLedgerHere();
    switch (result) {
      case DataKeyReady(:final dataKey):
        await widget.store.forgetStoredRecoveryKey();
        _keySaved = await _readKey(widget.store.readKeySaved) ?? false;
        if (encrypted && !keyOpens(_file, dataKey)) {
          _go(_Entry(_EntryWhy.keptKeyWrong, ledgerHere: true));
          return;
        }
        await _open(dataKey);
      case DataKeyNeedsRecoveryEntry(:final canPersist):
        _canPersist = canPersist;
        if (plain) {
          // A ledger from before encryption has nothing to recover.
          _go(_Setup(RecoveryKey.generate(), convertingExisting: true));
        } else {
          _go(
            encrypted
                ? _Entry(_EntryWhy.ledgerHere, ledgerHere: true)
                : _Welcome(),
          );
        }
    }
  }

  String _entryMessage(Words t, _EntryWhy why) => switch (why) {
    _EntryWhy.keptKeyWrong => t.startEntryKeptKeyWrong,
    // Without a keychain it's asked for at every launch, and says why.
    _EntryWhy.ledgerHere =>
      _canPersist ? t.startEntryLedgerHere : t.startEntryLedgerHereEveryLaunch,
  };

  void _go(_Step step) {
    if (mounted) setState(() => _step = step);
  }

  /// A typed key: used only if it opens the ledger here (when there is one).
  /// Says why not in [t]'s words.
  Future<String?> _onKey(Words t, RecoveryKey recovery) async {
    final key = deriveDataKey(recovery);
    final here = await _encryptedLedgerHere();
    if (here && !keyOpens(_file, key)) return t.startKeyWrongHere;
    try {
      if (_canPersist) {
        await widget.store.writeDataKey(key);
        await widget.store.writeKeySaved(true);
      }
    } catch (e) {
      return t.startCouldntKeepKey('${e.runtimeType}');
    }
    _keySaved = true;
    await _open(key, newDevice: !_file.existsSync());
    return null;
  }

  /// Restore from backup or Open ledger on the first screen: the file or
  /// folder is picked first, and the key is kept only if it opens what was
  /// picked. Until then nothing is stored and no ledger is made, so a key
  /// that doesn't fit can be typed again where it was typed. Null with
  /// nothing done when the dialog was closed.
  Future<String?> _onStart(
    Words t,
    RecoveryKey recovery,
    StartFrom from,
  ) async {
    final key = deriveDataKey(recovery);
    final String path;
    final File file;
    try {
      if (from == StartFrom.folder) {
        final picked = await getDirectoryPath(
          confirmButtonText: t.ledgerUseThisFolder,
        );
        if (picked == null) return null;
        final folder = CloudFolder.folderWithLedger(picked);
        if (folder == null) {
          return t.ledgerFolderNoLedger(CloudFolder.nameOf(picked));
        }
        path = folder;
        file = File('$folder/${CloudFolder.fileName}');
      } else {
        final picked = await openFile(
          acceptedTypeGroups: [
            XTypeGroup(
              label: t.ledgerBackupFileType,
              extensions: const ['sqlite', Backups.extension],
            ),
          ],
          confirmButtonText: t.ledgerChoose,
        );
        if (picked == null) return null;
        path = picked.path;
        file = File(path);
      }
    } catch (e) {
      debugPrint('The dialog failed: $e');
      return t.ledgerCouldntOpenFileDialog;
    }
    if (!await _opensWith(file, key)) {
      return from == StartFrom.folder
          ? t.startKeyWrongFolder(CloudFolder.nameOf(path))
          : t.startRestoreWrongKey;
    }
    _startFrom = from;
    _startPath = path;
    return _onKey(t, recovery);
  }

  /// Whether [key] opens [file], read from a copy so nothing is opened
  /// inside a folder a sync app is watching. A backup from before
  /// encryption needs no key.
  Future<bool> _opensWith(File file, Uint8List key) async {
    final copy = File(
      '${Directory.systemTemp.path}/betterbudget-start-${fileStamp(widget.clock())}',
    );
    try {
      await file.copy(copy.path);
      return await isPlainSqliteFile(copy) || keyOpens(copy, key);
    } catch (e) {
      debugPrint('The picked ledger couldn’t be read: $e');
      return false;
    } finally {
      if (copy.existsSync()) await copy.delete();
    }
  }

  /// Starts fresh. A ledger already here is moved aside, never deleted.
  Future<void> _onSetUpNew() async {
    if (await _encryptedLedgerHere()) await _setAside();
    _go(_Setup(RecoveryKey.generate(), convertingExisting: false));
  }

  String get _setAsideName =>
      'Ledger.set-aside-${fileStamp(widget.clock())}.$ledgerExtension';

  Future<void> _setAside() async {
    final aside = '${_file.parent.path}/$_setAsideName';
    for (final side in ['-wal', '-shm']) {
      final f = File('${_file.path}$side');
      if (f.existsSync()) await f.rename('$aside$side');
    }
    await _file.rename(aside);
  }

  /// The key has been shown: only now is it stored and the ledger opened
  /// (and encrypted, if it was plain).
  Future<void> _onSetupDone(RecoveryKey recovery, bool kept) async {
    final key = deriveDataKey(recovery);
    try {
      if (_canPersist) {
        await widget.store.writeDataKey(key);
        await widget.store.writeKeySaved(kept);
      }
    } catch (e) {
      _go(
        _Failed(
          e,
          _FailedAt.keyNotKept,
          retry: () => _onSetupDone(recovery, kept),
        ),
      );
      return;
    }
    _keySaved = kept;
    await _open(key, newKey: true);
  }

  /// [newDevice]: the key was typed and no ledger is here. [newKey]: the key
  /// was made here, so no backup is waiting to be opened with it.
  Future<void> _open(
    Uint8List key, {
    bool newDevice = false,
    bool newKey = false,
  }) async {
    OpenedLedger? opened;
    var offerBackup = newDevice;
    try {
      opened = await widget.open(key);
      if (newKey) {
        await opened.db.setPreference(
          SetupKeys.backupOffer,
          SetupKeys.backupOfferNo,
        );
      }
      if (newDevice) {
        // A ledger coming from a backup, not the demo.
        await opened.db.setPreference(
          AppDatabase.startedKey,
          dateKey(dateOnly(widget.clock())),
        );
      }
      // An earlier build kept "saved" inside the ledger.
      if (!_keySaved && await _savedInLedger(opened.db)) {
        _keySaved = true;
        if (_canPersist) {
          await widget.store.writeKeySaved(true);
        }
      }
      // Not answered at an earlier launch (the file dialog was cancelled,
      // or the app was quit): the ledger is still empty, so it's asked again.
      offerBackup = offerBackup || await opened.db.backupOfferOpen();
    } catch (e) {
      debugPrint('Opening the ledger failed: ${_safe(e)}');
      // Try again opens it afresh: this one is closed, not left beside it.
      try {
        await opened?.db.close();
      } catch (_) {}
      _go(
        _Failed(
          e,
          _FailedAt.open,
          retry: () => _open(key, newDevice: newDevice, newKey: newKey),
        ),
      );
      return;
    }
    opened.startDaily();
    _go(_Running(opened, key, offerBackup: offerBackup));
  }

  static Future<bool> _savedInLedger(AppDatabase db) async =>
      (await db
              .customSelect(
                "SELECT value FROM preferences WHERE key = "
                "'security.recoveryKeySaved'",
              )
              .get())
          .any((r) => r.read<String>('value') == '1');

  static String? _notice(Words t, ConversionReport r) {
    final failed = r.failed;
    if (failed.isNotEmpty) {
      final names = failed
          .map((f) => f.path.split(Platform.pathSeparator).last)
          .join(', ');
      return t.startCopiesFailed(failed.length, names);
    }
    return r.converted > 0 ? t.startCopiesEncrypted(r.converted) : null;
  }

  static String _failure(Words t, _Failed f) => switch (f.at) {
    _FailedAt.keyNotRead => t.startCouldntReadKey,
    _FailedAt.keyNotKept => t.startCouldntKeepKeyNothingEncrypted,
    _FailedAt.open => t.startCouldntOpen,
  };

  /// What a failure means for the ledger, where that is known.
  static String? _failureNote(Words t, _Failed f) => switch (f.at) {
    _FailedAt.keyNotRead => t.startLedgerNotTouched,
    _FailedAt.keyNotKept => t.startNothingEncrypted,
    _FailedAt.open => null,
  };

  /// The error itself, shown only when asked for. Storing a key names only
  /// the error's type, so a key never reaches the screen.
  static String _failureDetails(Words t, _Failed f) {
    final e = f.error;
    if (f.at == _FailedAt.keyNotKept) return '${e.runtimeType}';
    return e is CipherException ? cipherProblem(t, e) : _safe(e);
  }

  void _retry(_Failed f) {
    setState(() {
      _details = false;
      _reportFailed = false;
      _step = _Loading();
    });
    unawaited(f.retry());
  }

  /// Report a problem… (#292): lls.mn's form in the browser.
  Future<void> _reportProblem(Words t) async {
    final opened = await openReportProblem(
      language: t.localeName.split('_').first,
    );
    if (mounted) setState(() => _reportFailed = !opened);
  }

  Widget _failedScreen(Words t, _Failed f) {
    final note = _failureNote(t, f);
    return Scaffold(
      backgroundColor: Mid.ground,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _failure(t, f),
                  key: const ValueKey('startup-failed'),
                  style: onest(22, weight: 600),
                ),
                if (note != null) ...[
                  const SizedBox(height: 8),
                  Text(note, style: onest(15, color: Mid.ink2, height: 1.4)),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    FilledButton(
                      key: const ValueKey('startup-try-again'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Mid.fill,
                        foregroundColor: Mid.onFill,
                        visualDensity: VisualDensity.standard,
                      ),
                      onPressed: () => _retry(f),
                      child: Text(t.startTryAgain),
                    ),
                    if (!_details) ...[
                      const SizedBox(width: 12),
                      TextButton(
                        key: const ValueKey('startup-show-details'),
                        style: TextButton.styleFrom(
                          foregroundColor: Mid.ink2,
                          visualDensity: VisualDensity.standard,
                        ),
                        onPressed: () => setState(() => _details = true),
                        child: Text(t.startShowDetails),
                      ),
                    ],
                  ],
                ),
                if (_details) ...[
                  const SizedBox(height: 20),
                  SelectableText(
                    _failureDetails(t, f),
                    key: const ValueKey('startup-details'),
                    style: onest(13, color: Mid.ink3, height: 1.4),
                  ),
                  const SizedBox(height: 4),
                  // Its left edge on the text's, as Report a problem… below.
                  Transform.translate(
                    offset: const Offset(-10, 0),
                    child: CopyDetails(
                      text: failureReport(
                        _failure(t, f),
                        _failureDetails(t, f),
                      ),
                      color: Mid.ink2,
                    ),
                  ),
                ],
                // The ledger not opening is when it's needed most; quieter
                // than Show details, like the sidebar's line.
                const SizedBox(height: 28),
                Hoverable(
                  key: const ValueKey('report-problem'),
                  onTap: () => _reportProblem(t),
                  builder: (h) => Text(
                    t.reportProblem,
                    style: onest(13, color: h ? Mid.ink2 : Mid.ink3).copyWith(
                      decoration: h ? TextDecoration.underline : null,
                      decorationColor: Mid.ink2,
                    ),
                  ),
                ),
                if (_reportFailed) ...[
                  const SizedBox(height: 6),
                  Text(
                    t.reportProblemFailed,
                    key: const ValueKey('report-problem-failed'),
                    style: onest(13, color: Mid.ink2, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BetterBudget',
    debugShowCheckedModeBanner: false,
    // Every other color switches in one frame; the page mustn't fade behind.
    themeAnimationDuration: Duration.zero,
    theme: appTheme(),
    locale: LanguageScope.maybeOf(context)?.locale,
    supportedLocales: supportedLocales,
    localizationsDelegates: Words.localizationsDelegates,
    localeListResolutionCallback: (preferred, _) => resolveLocale(preferred),
    builder: (context, child) => FitWindow(child: child!),
    // Under the MaterialApp, where the chosen language is known.
    home: Builder(builder: (context) => _screen(context.t)),
  );

  Widget _screen(Words t) => switch (_step) {
    _Loading() => Scaffold(backgroundColor: Mid.ground),
    _Welcome() => StartChoiceScreen(
      onNew: _onSetUpNew,
      onKey: (k, from) => _onStart(t, k, from),
    ),
    _Entry(:final why, :final ledgerHere) => RecoveryKeyEntryScreen(
      key: ValueKey(why),
      message: _entryMessage(t, why),
      ledgerHere: ledgerHere,
      setAsideName: _setAsideName,
      onKey: (k) => _onKey(t, k),
      onSetUpNew: _onSetUpNew,
    ),
    _Setup(:final key, :final convertingExisting) => RecoveryKeySetupScreen(
      recoveryKey: key,
      convertingExisting: convertingExisting,
      clock: widget.clock,
      onContinue: (kept) => _onSetupDone(key, kept),
    ),
    _Running(:final opened, :final dataKey, :final offerBackup) => LedgerScreen(
      db: opened.db,
      backups: opened.backups,
      clock: widget.clock,
      encrypted: true,
      recoveryKeySaved: _keySaved,
      checkRecoveryKey: (k) async => sameKey(deriveDataKey(k), dataKey),
      onRecoveryKeyChecked: () {
        _keySaved = true;
        if (_canPersist) widget.store.writeKeySaved(true);
      },
      startupNotice: _notice(t, opened.report),
      offerRestore: offerBackup,
      startFrom: offerBackup ? _startFrom : null,
      startPath: offerBackup ? _startPath : null,
    ),
    final _Failed f => _failedScreen(t, f),
  };
}
