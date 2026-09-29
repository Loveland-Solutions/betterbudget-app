// What happens at launch (ADR 0001). The order matters: a key is checked
// against the ledger before it's stored, so a key that doesn't fit is never
// kept, and a new key is shown before it's stored or anything is encrypted,
// so a quit or crash never leaves data locked under a key nobody saw.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/backup.dart';
import '../data/database.dart';
import '../data/encryption.dart';
import '../data/keys.dart';
import '../domain/ledger.dart' show dateOnly;
import 'ledger_screen.dart';
import 'recovery_key_screen.dart';
import 'theme.dart';

/// The ledger, opened (and converted if it was plain), with what converting
/// its old copies did.
typedef OpenedLedger = ({
  AppDatabase db,
  Backups backups,
  ConversionReport report,
});

sealed class _Step {}

class _Loading extends _Step {}

class _Entry extends _Step {
  _Entry(this.message, {required this.ledgerHere});
  final String message;
  final bool ledgerHere;
}

class _Setup extends _Step {
  _Setup(this.key, {required this.convertingExisting});
  final RecoveryKey key;
  final bool convertingExisting;
}

class _Running extends _Step {
  _Running(this.opened, this.dataKey, {this.notice, this.newDevice = false});
  final OpenedLedger opened;
  final Uint8List dataKey;
  final String? notice;
  final bool newDevice;
}

class _Failed extends _Step {
  _Failed(this.message);
  final String message;
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

  /// `betterbudget.sqlite`, which may not exist yet.
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

  File get _file => widget.ledgerFile;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<bool> _encryptedLedgerHere() async =>
      _file.existsSync() && !await isPlainSqliteFile(_file);

  Future<void> _start() async {
    final result = await resolveDataKey(widget.store);
    final plain = await isPlainSqliteFile(_file);
    final encrypted = await _encryptedLedgerHere();
    switch (result) {
      case DataKeyReady(:final dataKey):
        await widget.store.forgetStoredRecoveryKey();
        _keySaved = await widget.store.readKeySaved() ?? false;
        if (encrypted && !keyOpens(_file, dataKey)) {
          _go(
            _Entry(
              'The key kept on this computer doesn’t open the ledger here. '
              'Type the ledger’s recovery key to open it.',
              ledgerHere: true,
            ),
          );
          return;
        }
        await _open(dataKey);
      case DataKeyNeedsRecoveryEntry(:final canPersist):
        _canPersist = canPersist;
        if (plain) {
          // A ledger from before encryption has nothing to recover.
          _go(_Setup(RecoveryKey.generate(), convertingExisting: true));
        } else {
          _go(_Entry(_entryMessage(encrypted), ledgerHere: encrypted));
        }
    }
  }

  String _entryMessage(bool ledgerHere) {
    final everyLaunch = _canPersist
        ? ''
        : 'This computer has no keychain BetterBudget can use, so it asks for '
              'your recovery key each time it opens. ';
    return ledgerHere
        ? '${everyLaunch}There’s a ledger on this computer. Type its recovery '
              'key to open it.'
        : '${everyLaunch}This computer doesn’t have a ledger yet. If you’ve '
              'used BetterBudget before, type your recovery key, then open a '
              'backup you saved with Back up to….';
  }

  void _go(_Step step) {
    if (mounted) setState(() => _step = step);
  }

  /// A typed key: used only if it opens the ledger here (when there is one).
  Future<String?> _onKey(RecoveryKey recovery) async {
    final key = deriveDataKey(recovery);
    final here = await _encryptedLedgerHere();
    if (here && !keyOpens(_file, key)) {
      return 'That key doesn’t open the ledger on this computer';
    }
    try {
      if (_canPersist) {
        await widget.store.writeDataKey(key);
        await widget.store.writeKeySaved(true);
      }
    } catch (e) {
      return 'Couldn’t keep the key on this computer · ${e.runtimeType}';
    }
    _keySaved = true;
    await _open(key, newDevice: !_file.existsSync());
    return null;
  }

  /// Starts fresh. A ledger already here is moved aside, never deleted.
  Future<void> _onSetUpNew() async {
    if (await _encryptedLedgerHere()) await _setAside();
    _go(_Setup(RecoveryKey.generate(), convertingExisting: false));
  }

  String get _setAsideName =>
      'betterbudget.set-aside-${fileStamp(widget.clock())}.sqlite';

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
          'Couldn’t keep the key on this computer · ${e.runtimeType}. '
          'Nothing was encrypted.',
        ),
      );
      return;
    }
    _keySaved = kept;
    await _open(key);
  }

  Future<void> _open(Uint8List key, {bool newDevice = false}) async {
    final OpenedLedger opened;
    try {
      opened = await widget.open(key);
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
    } catch (e) {
      debugPrint('Opening the ledger failed: $e');
      _go(_Failed('Couldn’t open the ledger · $e'));
      return;
    }
    _go(
      _Running(
        opened,
        key,
        notice: _notice(opened.report),
        newDevice: newDevice,
      ),
    );
  }

  static Future<bool> _savedInLedger(AppDatabase db) async =>
      (await db
              .customSelect(
                "SELECT value FROM preferences WHERE key = "
                "'security.recoveryKeySaved'",
              )
              .get())
          .any((r) => r.read<String>('value') == '1');

  static String? _notice(ConversionReport r) {
    String copies(int n) => n == 1 ? '1 old copy' : '$n old copies';
    final failed = r.failed;
    if (failed.isNotEmpty) {
      final names = failed
          .map((f) => f.path.split(Platform.pathSeparator).last)
          .join(', ');
      return '${copies(failed.length)} couldn’t be encrypted and '
          '${failed.length == 1 ? 'is' : 'are'} still readable: $names';
    }
    return r.converted > 0
        ? 'Encrypted ${copies(r.converted)} of your ledger'
        : null;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BetterBudget',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    home: switch (_step) {
      _Loading() => Scaffold(backgroundColor: Mid.ground),
      _Entry(:final message, :final ledgerHere) => RecoveryKeyEntryScreen(
        key: ValueKey(message),
        message: message,
        ledgerHere: ledgerHere,
        setAsideName: _setAsideName,
        onKey: _onKey,
        onSetUpNew: _onSetUpNew,
      ),
      _Setup(:final key, :final convertingExisting) => RecoveryKeySetupScreen(
        recoveryKey: key,
        convertingExisting: convertingExisting,
        clock: widget.clock,
        onContinue: (kept) => _onSetupDone(key, kept),
      ),
      _Running(
        :final opened,
        :final dataKey,
        :final notice,
        :final newDevice,
      ) =>
        LedgerScreen(
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
          startupNotice: notice,
          offerRestore: newDevice,
        ),
      _Failed(:final message) => Scaffold(
        backgroundColor: Mid.ground,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              message,
              key: const ValueKey('startup-failed'),
              style: onest(14, color: Mid.coral),
            ),
          ),
        ),
      ),
    },
  );
}
