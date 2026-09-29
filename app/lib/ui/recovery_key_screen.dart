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
/// for. Returns whether it was saved (false if the user cancelled the dialog
/// or the write failed).
Future<bool> saveRecoveryKeyToFile(String display, DateTime made) async {
  final FileSaveLocation? location;
  try {
    location = await getSaveLocation(
      suggestedName: 'BetterBudget recovery key.txt',
      confirmButtonText: 'Save',
    );
  } catch (_) {
    return false;
  }
  if (location == null) return false;
  String two(int v) => v.toString().padLeft(2, '0');
  try {
    await File(location.path).writeAsString(
      'BetterBudget recovery key\n\n'
      '$display\n\n'
      'Made ${made.year}.${two(made.month)}.${two(made.day)}.\n\n'
      'It opens your BetterBudget ledger and its backups on another computer, '
      'or on a phone that records spending. BetterBudget doesn’t keep a copy, '
      'and it can’t be replaced: without it, the ledger can’t be opened '
      'anywhere else.\n\n'
      'Keep it somewhere safe, away from this computer, where the other '
      'person who manages the money can find it. Don’t keep this file in the '
      'same folder as your backups.\n',
    );
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
  Widget build(BuildContext context) => Scaffold(
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
                  'Your recovery key',
                  style: onest(22, weight: 600, letterSpacing: -0.3),
                ),
                const SizedBox(height: 10),
                Text(
                  'BetterBudget encrypts your ledger and its backups. This key '
                  'opens them on another computer, and on each phone that '
                  'records spending. This is the only time it’s shown: '
                  'BetterBudget doesn’t keep a copy, and it can’t be replaced.',
                  style: onest(14, color: Mid.ink2, height: 1.4),
                ),
                const SizedBox(height: 20),
                RecoveryKeyDisplay(display: widget.recoveryKey.display),
                const SizedBox(height: 8),
                Text(
                  'Keep it away from this computer, where the other person who '
                  'manages the money can find it: printed with your important '
                  'papers, or on another drive.',
                  style: onest(13, color: Mid.ink3, height: 1.4),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    BarButton(
                      key: const ValueKey('save-recovery-key'),
                      label: _saved ? 'Saved' : 'Save…',
                      leading: Icon(
                        _saved ? Icons.check_rounded : Icons.save_alt_rounded,
                        size: 14,
                        color: _saved ? Mid.green : Mid.ink3,
                      ),
                      onTap: _save,
                    ),
                    BarButton(
                      key: const ValueKey('copy-recovery-key'),
                      label: _copied ? 'Copied' : 'Copy',
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
                    'Copies you saved elsewhere with Back up to… before today '
                    'aren’t encrypted. Replace them with a new Back up to….',
                    key: const ValueKey('recovery-key-old-copies'),
                    style: onest(13, color: Mid.ink2, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!_saved)
                  Text(
                    _copied
                        ? 'Copied · paste it somewhere off this computer '
                              'before you continue. The clipboard is cleared in '
                              'a minute.'
                        : 'If you continue without saving or copying it, it’s '
                              'gone: BetterBudget can’t show it again, and if '
                              'this computer is lost, your ledger and its '
                              'backups can’t be opened.',
                    key: const ValueKey('recovery-key-warning'),
                    style: onest(13, color: Mid.coral, height: 1.4),
                  ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    key: const ValueKey('recovery-key-continue'),
                    onPressed: _busy ? null : _continue,
                    child: const Text('Continue'),
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
    final problem = RecoveryKey.problem(_controller.text);
    if (problem != null) {
      setState(() => _error = problem);
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
  Widget build(BuildContext context) => Scaffold(
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
                'Enter your recovery key',
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
                            ? 'Start a new ledger instead…'
                            : 'New to BetterBudget? Set up a ledger',
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
                    child: const Text('Continue'),
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

/// Says what starting fresh does to the ledger already on this computer.
class _SetAsideWarning extends StatelessWidget {
  const _SetAsideWarning({this.name});
  final String? name;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Mid.panel,
    title: Text(
      'Start a new ledger?',
      style: onest(17, weight: 600, color: Mid.coral),
    ),
    content: SizedBox(
      width: 420,
      child: Text(
        'The ledger already on this computer can only be opened with its own '
        'recovery key. It won’t be deleted: it’s moved aside'
        '${name == null ? '' : ' as $name'}, in BetterBudget’s folder, so '
        'you can open it later if you find its key.',
        style: onest(13.5, color: Mid.ink, height: 1.4),
      ),
    ),
    actions: [
      BarButton(
        key: const ValueKey('set-aside-cancel'),
        label: 'Cancel',
        onTap: () => Navigator.of(context).pop(false),
      ),
      FilledButton(
        key: const ValueKey('set-aside-confirm'),
        style: FilledButton.styleFrom(backgroundColor: Mid.coral),
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('Move it aside and start new'),
      ),
    ],
  );
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
      builder: (_) => _KeyDialog(
        title: 'Check your recovery key',
        body:
            'Type the key you saved. BetterBudget checks whether it opens '
            'this ledger. It never shows the key.',
        action: 'Check',
        onKey: (key) async =>
            await check(key) ? null : 'No · this key doesn’t open this ledger',
        success: 'Yes · this key opens this ledger',
      ),
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
      builder: (_) => _KeyDialog(
        title: 'This backup has its own key',
        body:
            'It isn’t encrypted with this ledger’s key. It may be from another '
            'ledger: type that ledger’s recovery key to restore it. Your own '
            'key doesn’t change.',
        action: 'Open backup',
        onKey: tryKey,
      ),
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
    final problem = RecoveryKey.problem(_controller.text);
    if (problem != null) {
      setState(() => _error = problem);
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
                  label: _matched ? 'Close' : 'Cancel',
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
