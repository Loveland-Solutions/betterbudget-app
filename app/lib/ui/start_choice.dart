// The first screen on a computer with no ledger and no key (ADR 0004, "How a
// new computer starts"): three ways to start. Start fresh makes a new
// ledger. Restore from backup and Open ledger open in place, where they
// were clicked, with the recovery key and the button that picks the file or
// the folder.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/keys.dart';
import 'data_words.dart';
import 'language.dart';
import 'ledger_screen.dart' show StartFrom;
import 'recovery_key_screen.dart' show RecoveryKeyField;
import 'register.dart' show Hoverable;
import 'theme.dart';

class StartChoiceScreen extends StatefulWidget {
  const StartChoiceScreen({
    super.key,
    required this.onNew,
    required this.onKey,
  });

  /// Start fresh: a new ledger, with a new recovery key.
  final Future<void> Function() onNew;

  /// The key typed under Restore from backup or Open ledger. Returns a
  /// reason to show when it can't be used, or null once it's in use.
  final Future<String?> Function(RecoveryKey key, StartFrom from) onKey;

  @override
  State<StartChoiceScreen> createState() => _StartChoiceScreenState();
}

class _StartChoiceScreenState extends State<StartChoiceScreen> {
  final _controller = TextEditingController();

  /// The row that is open.
  StartFrom? _open;
  String? _error;
  bool _busy = false;

  Future<void> _new() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onNew();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final from = _open;
    if (_busy || from == null) return;
    final problem = RecoveryKey.check(_controller.text);
    if (problem != null) {
      setState(() => _error = keyProblem(context.t, problem));
      return;
    }
    setState(() => _busy = true);
    final error = await widget.onKey(
      RecoveryKey.parse(_controller.text)!,
      from,
    );
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _heading(String title, String note) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: onest(16, weight: 600)),
      const SizedBox(height: 4),
      Text(note, style: onest(13.5, color: Mid.ink2, height: 1.4)),
    ],
  );

  Widget _row({
    required String key,
    required String title,
    required String note,
    required VoidCallback onTap,
  }) => Hoverable(
    key: ValueKey(key),
    onTap: _busy ? null : onTap,
    builder: (hover) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: hover ? Mid.raised : Mid.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hover ? Mid.blueEdge : Mid.rule),
      ),
      child: _heading(title, note),
    ),
  );

  /// A way that needs the recovery key: closed it is a row like the
  /// others, and open it holds the key and the button that picks.
  Widget _keyed({
    required StartFrom from,
    required String key,
    required String title,
    required String note,
    required String action,
  }) {
    if (_open != from) {
      return _row(
        key: key,
        title: title,
        note: note,
        onTap: () => setState(() {
          _open = from;
          _error = null;
        }),
      );
    }
    final t = context.t;
    return Container(
      key: ValueKey('$key-open'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: Mid.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Mid.blue, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A click on its name closes it again.
          Hoverable(
            key: ValueKey(key),
            onTap: _busy ? null : () => setState(() => _open = null),
            builder: (_) =>
                SizedBox(width: double.infinity, child: _heading(title, note)),
          ),
          const SizedBox(height: 16),
          Text(t.startKeyLabel, style: onest(13, color: Mid.ink3)),
          const SizedBox(height: 6),
          RecoveryKeyField(
            controller: _controller,
            errorText: _error,
            onSubmitted: _submit,
            onChanged: () {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 8),
          Text(t.startKeyHint, style: onest(13, color: Mid.ink3, height: 1.4)),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const ValueKey('recovery-key-submit'),
              style: FilledButton.styleFrom(
                backgroundColor: Mid.fill,
                foregroundColor: Mid.onFill,
                visualDensity: VisualDensity.standard,
              ),
              onPressed: _busy ? null : _submit,
              child: Text(action),
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
      // Esc closes the row that is open.
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (!_busy && _open != null) setState(() => _open = null);
          },
        },
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.startHowTitle,
                      style: onest(22, weight: 600, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 20),
                    _row(
                      key: 'start-fresh',
                      title: t.startFresh,
                      note: t.startFreshNote,
                      onTap: _new,
                    ),
                    const SizedBox(height: 12),
                    _keyed(
                      from: StartFrom.backup,
                      key: 'start-restore',
                      title: t.startRestore,
                      note: t.startRestoreNote,
                      action: t.startChooseBackup,
                    ),
                    const SizedBox(height: 12),
                    _keyed(
                      from: StartFrom.folder,
                      key: 'start-open',
                      title: t.startOpen,
                      note: t.startOpenNote,
                      action: t.startChooseFolder,
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
