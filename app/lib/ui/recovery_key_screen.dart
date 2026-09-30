// The recovery key screens (ADR 0001). The setup screen shows a new key
// once, before anything is stored or encrypted, with Save and Copy.
// BetterBudget never stores the recovery key, so it can't be shown again
// (owner, 2026-09-28: "you can only view it once, and the app doesn't store
// it"). Skippable (warn, don't block). The entry screen asks for a key when
// this device has none, or the one it has doesn't fit. Two dialogs check a
// typed key: against this ledger (Settings), or to open a backup made under
// another ledger's key.
import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/keys.dart';
import 'data_words.dart';
import 'language.dart';
import 'register.dart' show BarButton;
import 'theme.dart';

/// The key's five groups on one line, in a bordered block that reads like a
/// code, not a sentence. A key broken across lines is easy to copy wrong.
class RecoveryKeyDisplay extends StatelessWidget {
  const RecoveryKeyDisplay({super.key, required this.display});
  final String display;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
    decoration: BoxDecoration(
      color: Mid.raised,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Mid.rule),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        display,
        maxLines: 1,
        softWrap: false,
        style: onest(
          20,
          weight: 600,
          color: Mid.gold,
          tabular: true,
          letterSpacing: 1.5,
        ),
      ),
    ),
  );
}

/// Writes the key to a `.txt` file the user picks, dated, with what it's
/// for, in [t]'s language. Returns whether it was saved (false if the user
/// cancelled the dialog or the write failed).
Future<bool> saveRecoveryKeyToFile(
  Words t,
  String display,
  DateTime made,
) async {
  final FileSaveLocation? location;
  try {
    location = await getSaveLocation(
      suggestedName: t.startKeyFileName,
      confirmButtonText: t.startSave,
    );
  } catch (_) {
    return false;
  }
  if (location == null) return false;
  try {
    await File(location.path)
        .writeAsString(t.startKeyFileText(display, fullDate(made)));
    return true;
  } catch (_) {
    return false;
  }
}

/// Clears the clipboard a minute after the key was copied, unless something
/// else has been copied since. Clipboard history and other devices shouldn't
/// keep it longer than it takes to paste.
Timer? _clipboardTimer;
Future<void> copyRecoveryKey(String display) async {
  await Clipboard.setData(ClipboardData(text: display));
  _clipboardTimer?.cancel();
  _clipboardTimer = Timer(const Duration(minutes: 1), () async {
    final now = await Clipboard.getData(Clipboard.kTextPlain);
    if (now?.text == display) {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
  });
}

/// Shown once, when a new key is made (a fresh install, or the first time a
/// ledger from before encryption opens), before the key is stored or
/// anything is encrypted: quitting here leaves everything as it was, and the
/// next launch shows a new key. The only time the key is ever on screen.
/// Skippable (warn, don't block); [onContinue] gets whether it was saved or
/// copied, for Settings' warning.
class RecoveryKeySetupScreen extends StatefulWidget {
  const RecoveryKeySetupScreen({
    super.key,
    required this.recoveryKey,
    required this.onContinue,
    this.convertingExisting = false,
    this.clock = DateTime.now,
  });
  final RecoveryKey recoveryKey;
  final Future<void> Function(bool kept) onContinue;

  /// A ledger from before encryption is about to be encrypted: copies the
  /// user saved elsewhere before today stay readable.
  final bool convertingExisting;
  final DateTime Function() clock;

  @override
  State<RecoveryKeySetupScreen> createState() => _RecoveryKeySetupScreenState();
}

class _RecoveryKeySetupScreenState extends State<RecoveryKeySetupScreen> {
  bool _saved = false;
  bool _copied = false;
  bool _busy = false;

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await saveRecoveryKeyToFile(
      context.t,
      widget.recoveryKey.display,
      widget.clock(),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _saved = _saved || ok;
    });
  }

  Future<void> _copy() async {
    await copyRecoveryKey(widget.recoveryKey.display);
    if (mounted) setState(() => _copied = true);
  }

  Future<void> _continue() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onContinue(_saved || _copied);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      backgroundColor: Mid.ground,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.startKeyTitle,
                    style: onest(22, weight: 600, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t.startKeyIntro,
                    style: onest(14, color: Mid.ink2, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  RecoveryKeyDisplay(display: widget.recoveryKey.display),
                  const SizedBox(height: 8),
                  Text(
                    t.startKeyWhere,
                    style: onest(13, color: Mid.ink3, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      BarButton(
                        key: const ValueKey('save-recovery-key'),
                        label: _saved ? t.startSaved : t.startSaveEllipsis,
                        leading: Icon(
                          _saved ? Icons.check_rounded : Icons.save_alt_rounded,
                          size: 14,
                          color: _saved ? Mid.green : Mid.ink3,
                        ),
                        onTap: _save,
                      ),
                      BarButton(
                        key: const ValueKey('copy-recovery-key'),
                        label: _copied ? t.startCopied : t.startCopy,
                        leading: Icon(
                          _copied ? Icons.check_rounded : Icons.copy_rounded,
                          size: 14,
                          color: _copied ? Mid.green : Mid.ink3,
                        ),
                        onTap: _copy,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (widget.convertingExisting) ...[
                    Text(
                      t.startOldCopies,
                      key: const ValueKey('recovery-key-old-copies'),
                      style: onest(13, color: Mid.ink2, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (!_saved)
                    Text(
                      _copied ? t.startCopiedWarning : t.startNotKeptWarning,
                      key: const ValueKey('recovery-key-warning'),
                      style: onest(13, color: Mid.coral, height: 1.4),
                    ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      key: const ValueKey('recovery-key-continue'),
                      onPressed: _busy ? null : _continue,
                      child: Text(t.startContinue),
                    ),
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

/// The field a recovery key is typed into, shared by the entry screen and
/// the dialogs.
class RecoveryKeyField extends StatelessWidget {
  const RecoveryKeyField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.errorText,
    this.onChanged,
  });
  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final String? errorText;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    key: const ValueKey('recovery-key-field'),
    controller: controller,
    autofocus: true,
    style: onest(18, tabular: true, letterSpacing: 1.5),
    decoration: InputDecoration(
      hintText: 'ABCDE-FGHJK-LMNPQ-RSTUV-WXYZ0',
      errorText: errorText,
      errorMaxLines: 2,
    ),
    onSubmitted: (_) => onSubmitted(),
    onChanged: (_) => onChanged?.call(),
  );
}

/// Asks for a recovery key when this device has no key, or the one it has
/// doesn't open the ledger here (ADR 0001). [message] says which.
/// [ledgerHere] is set when an encrypted ledger is on this computer: then
/// starting fresh warns that it can't be opened afterwards, and it's moved
/// aside, never deleted.
class RecoveryKeyEntryScreen extends StatefulWidget {
  const RecoveryKeyEntryScreen({
    super.key,
    required this.message,
    required this.onKey,
    required this.onSetUpNew,
    this.ledgerHere = false,
    this.setAsideName,
  });
  final String message;

  /// Returns a reason to show when the key doesn't fit, or null once it's
  /// in use.
  final Future<String?> Function(RecoveryKey key) onKey;
  final Future<void> Function() onSetUpNew;
  final bool ledgerHere;

  /// Where the ledger here would be moved, for the warning.
  final String? setAsideName;

  @override
  State<RecoveryKeyEntryScreen> createState() => _RecoveryKeyEntryScreenState();
}

class _RecoveryKeyEntryScreenState extends State<RecoveryKeyEntryScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    if (_busy) return;
    final problem = RecoveryKey.check(_controller.text);
    if (problem != null) {
      setState(() => _error = keyProblem(context.t, problem));
      return;
    }
    setState(() => _busy = true);
    final error = await widget.onKey(RecoveryKey.parse(_controller.text)!);
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  Future<void> _setUpNew() async {
    if (_busy) return;
    if (widget.ledgerHere) {
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => _SetAsideWarning(name: widget.setAsideName),
      );
      if (go != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await widget.onSetUpNew();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      backgroundColor: Mid.ground,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.startEnterTitle,
                  style: onest(22, weight: 600, letterSpacing: -0.3),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.message,
                  key: const ValueKey('recovery-key-message'),
                  style: onest(14, color: Mid.ink2, height: 1.4),
                ),
                const SizedBox(height: 20),
                RecoveryKeyField(
                  controller: _controller,
                  errorText: _error,
                  onSubmitted: _submit,
                  onChanged: () {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: TextButton(
                        key: const ValueKey('recovery-key-generate-new'),
                        onPressed: _busy ? null : _setUpNew,
                        child: Text(
                          widget.ledgerHere
                              ? t.startNewLedgerInstead
                              : t.startNewToApp,
                          style: TextStyle(
                            color: widget.ledgerHere ? Mid.coral : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      key: const ValueKey('recovery-key-submit'),
                      onPressed: _busy ? null : _submit,
                      child: Text(t.startContinue),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Says what starting fresh does to the ledger already on this computer.
class _SetAsideWarning extends StatelessWidget {
  const _SetAsideWarning({this.name});
  final String? name;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return AlertDialog(
      backgroundColor: Mid.panel,
      title: Text(
        t.startSetAsideTitle,
        style: onest(17, weight: 600, color: Mid.coral),
      ),
      content: SizedBox(
        width: 420,
        child: Text(switch (name) {
          final n? => t.startSetAsideBodyNamed(n),
          null => t.startSetAsideBody,
        }, style: onest(13.5, color: Mid.ink, height: 1.4)),
      ),
      actions: [
        BarButton(
          key: const ValueKey('set-aside-cancel'),
          label: t.startCancel,
          onTap: () => Navigator.of(context).pop(false),
        ),
        FilledButton(
          key: const ValueKey('set-aside-confirm'),
          style: FilledButton.styleFrom(backgroundColor: Mid.coral),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(t.startSetAsideConfirm),
        ),
      ],
    );
  }
}

/// Settings → Security's "Check my recovery key…": the user types the key
/// they saved and learns whether it opens this ledger. Nothing is ever
/// shown. Resolves to whether a matching key was typed.
Future<bool> showCheckRecoveryKeyDialog(
  BuildContext context,
  Future<bool> Function(RecoveryKey key) check,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) {
        final t = context.t;
        return _KeyDialog(
          title: t.startCheckTitle,
          body: t.startCheckBody,
          action: t.startCheckAction,
          onKey: (key) async => await check(key) ? null : t.startCheckNo,
          success: t.startCheckYes,
        );
      },
    ) ??
    false;

/// Asks for the recovery key of a backup made under another ledger's key.
/// [tryKey] returns a reason when it doesn't open the backup, or null once
/// the backup is ready to restore. Resolves to whether it was.
Future<bool> showBackupKeyDialog(
  BuildContext context,
  Future<String?> Function(RecoveryKey key) tryKey,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) {
        final t = context.t;
        return _KeyDialog(
          title: t.startBackupKeyTitle,
          body: t.startBackupKeyBody,
          action: t.startBackupKeyAction,
          onKey: tryKey,
        );
      },
    ) ??
    false;

class _KeyDialog extends StatefulWidget {
  const _KeyDialog({
    required this.title,
    required this.body,
    required this.action,
    required this.onKey,
    this.success,
  });
  final String title;
  final String body;
  final String action;

  /// Null when the key is right; otherwise why not.
  final Future<String?> Function(RecoveryKey key) onKey;

  /// Shown in green when the key is right, with Close; without it the
  /// dialog closes at once.
  final String? success;

  @override
  State<_KeyDialog> createState() => _KeyDialogState();
}

class _KeyDialogState extends State<_KeyDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _matched = false;
  bool _busy = false;

  Future<void> _submit() async {
    if (_busy) return;
    final problem = RecoveryKey.check(_controller.text);
    if (problem != null) {
      setState(() => _error = keyProblem(context.t, problem));
      return;
    }
    setState(() => _busy = true);
    final error = await widget.onKey(RecoveryKey.parse(_controller.text)!);
    if (!mounted) return;
    if (error == null && widget.success == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
      _matched = error == null;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Mid.panel,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: Mid.rule),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      child: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: onest(17, weight: 600, letterSpacing: -0.2),
            ),
            const SizedBox(height: 10),
            Text(widget.body, style: onest(13.5, color: Mid.ink2, height: 1.4)),
            const SizedBox(height: 16),
            RecoveryKeyField(
              controller: _controller,
              errorText: _error,
              onSubmitted: _submit,
              onChanged: () {
                if (_error != null || _matched) {
                  setState(() {
                    _error = null;
                    _matched = false;
                  });
                }
              },
            ),
            if (_matched) ...[
              const SizedBox(height: 10),
              Text(
                widget.success!,
                key: const ValueKey('key-check-yes'),
                style: onest(13.5, color: Mid.green),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                BarButton(
                  key: const ValueKey('key-dialog-close'),
                  label: _matched
                      ? context.t.startClose
                      : context.t.startCancel,
                  onTap: () => Navigator.of(context).pop(_matched),
                ),
                FilledButton(
                  key: const ValueKey('key-dialog-submit'),
                  onPressed: _busy ? null : _submit,
                  child: Text(widget.action),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
