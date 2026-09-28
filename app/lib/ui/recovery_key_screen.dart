// The recovery key setup screen (ADR 0001): shown once when a new key is
// created, with Save and Copy. BetterBudget never stores the recovery key,
// so it can't be shown again (owner, 2026-09-28: "you can only view it once,
// and the app doesn't store it"). Skippable (warn, don't block), and
// Settings says in coral if it wasn't saved or copied.
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

/// Writes the key to a `.txt` file the user picks, with a line on what it's
/// for. Returns whether it was saved (false if the user cancelled the
/// dialog or the write failed).
Future<bool> saveRecoveryKeyToFile(String display) async {
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
  try {
    await File(location.path).writeAsString(
      'BetterBudget recovery key\n\n'
      '$display\n\n'
      'Keep this somewhere safe, separate from this computer. It is the '
      'only way to open your BetterBudget backups on another device, or '
      'if this computer is lost. BetterBudget doesn’t keep a copy.\n',
    );
    return true;
  } catch (_) {
    return false;
  }
}

/// Shown once, right after a new data key is created (a fresh install, or
/// the first time an existing plain ledger is encrypted). The only time the
/// key is ever on screen. Skippable (warn, don't block); [onDone] says
/// whether it was saved or copied, for Settings' warning.
class RecoveryKeySetupScreen extends StatefulWidget {
  const RecoveryKeySetupScreen({
    super.key,
    required this.recoveryKey,
    required this.onDone,
  });
  final RecoveryKey recoveryKey;

  /// Called once, when the user continues, with whether they saved or
  /// copied it.
  final ValueChanged<bool> onDone;

  @override
  State<RecoveryKeySetupScreen> createState() => _RecoveryKeySetupScreenState();
}

class _RecoveryKeySetupScreenState extends State<RecoveryKeySetupScreen> {
  bool _saved = false;
  bool _copied = false;
  bool _saving = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.recoveryKey.display));
    if (mounted) setState(() => _copied = true);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final ok = await saveRecoveryKeyToFile(widget.recoveryKey.display);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = _saved || ok;
    });
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
                'Your recovery key',
                style: onest(22, weight: 600, letterSpacing: -0.3),
              ),
              const SizedBox(height: 10),
              Text(
                'BetterBudget encrypts your ledger and its backups. This key '
                'is the only way to open them on another computer, or if '
                'this one is lost. This is the only time it’s shown: '
                'BetterBudget doesn’t keep a copy.',
                style: onest(14, color: Mid.ink2, height: 1.4),
              ),
              const SizedBox(height: 20),
              RecoveryKeyDisplay(display: widget.recoveryKey.display),
              const SizedBox(height: 8),
              Text(
                'Save it somewhere that survives this computer being lost — '
                'printed, or on another drive, not just its Desktop.',
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
              const SizedBox(height: 20),
              if (!_saved && !_copied)
                Text(
                  'If you continue without saving or copying it, it’s gone: '
                  'BetterBudget can’t show it again, and if this computer is '
                  'lost, your ledger and its backups can’t be opened.',
                  key: const ValueKey('recovery-key-warning'),
                  style: onest(13, color: Mid.coral, height: 1.4),
                ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const ValueKey('recovery-key-continue'),
                  onPressed: () => widget.onDone(_saved || _copied),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Shown whenever this device has no data key yet (ADR 0001): either
/// nothing is stored here (a fresh ledger, or a second or replacement
/// device for someone who already has a recovery key — "adding a
/// device"), or — on Linux with no Secret Service — there's nowhere to
/// keep one at all, so this asks at every launch instead, deriving the
/// data key in memory for the session only. The only screen in the app
/// where the user types anything to do with encryption.
class RecoveryKeyEntryScreen extends StatefulWidget {
  const RecoveryKeyEntryScreen({
    super.key,
    required this.onKey,
    required this.onGenerateNew,
    this.hasSecureStore = true,
  });
  final ValueChanged<RecoveryKey> onKey;

  /// No existing recovery key to type: generates a new one. The caller
  /// must still show it (this screen doesn't), since it's the one chance
  /// to save it.
  final VoidCallback onGenerateNew;

  /// False only on Linux with no Secret Service — changes why this screen
  /// is asking.
  final bool hasSecureStore;

  @override
  State<RecoveryKeyEntryScreen> createState() => _RecoveryKeyEntryScreenState();
}

class _RecoveryKeyEntryScreenState extends State<RecoveryKeyEntryScreen> {
  final _controller = TextEditingController();
  String? _error;

  void _submit() {
    final key = RecoveryKey.parse(_controller.text);
    if (key == null) {
      setState(() => _error = 'Check the key and try again');
      return;
    }
    widget.onKey(key);
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
                widget.hasSecureStore
                    ? 'This computer doesn’t have a ledger yet. If you’ve '
                          'used BetterBudget before, type your recovery key '
                          'to open your ledger and its backups here too.'
                    : 'This computer has no keychain BetterBudget can use, '
                          'so it needs your recovery key each time it opens.',
                style: onest(14, color: Mid.ink2, height: 1.4),
              ),
              const SizedBox(height: 20),
              TextField(
                key: const ValueKey('recovery-key-field'),
                controller: _controller,
                autofocus: true,
                style: onest(18, tabular: true, letterSpacing: 1.5),
                decoration: InputDecoration(
                  hintText: 'ABCDE-FGHJK-LMNPQ-RSTUV-WXYZ0',
                  errorText: _error,
                ),
                onSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    key: const ValueKey('recovery-key-generate-new'),
                    onPressed: widget.onGenerateNew,
                    child: const Text('Setting up for the first time?'),
                  ),
                  FilledButton(
                    key: const ValueKey('recovery-key-submit'),
                    onPressed: _submit,
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
