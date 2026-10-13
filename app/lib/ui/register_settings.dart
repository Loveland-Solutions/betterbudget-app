part of 'ledger_screen.dart';

/// Settings' own panel for the register: the Source column on or off, and
/// a name for each computer and phone that has made a transaction here (ADR
/// 0004, "Where a row came from"). A name belongs to the id a row keeps, so
/// a rename shows on every row.
class _RegisterSettings extends StatelessWidget {
  const _RegisterSettings({
    required this.showSource,
    required this.onShowSource,
    required this.here,
    required this.computers,
    required this.phones,
    required this.onName,
  });

  final bool showSource;
  final ValueChanged<bool> onShowSource;

  /// This computer's id, listed first.
  final String? here;

  /// Each computer's and phone's id and the name given it, '' for none.
  final Map<String, String> computers;
  final Map<String, String> phones;

  /// [key] is the setting that holds the name.
  final void Function(String key, String name) onName;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    String short(String id) => id.length > 4 ? id.substring(0, 4) : id;
    final others = [
      for (final id in computers.keys)
        if (id != here) id,
    ];
    return Container(
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
          Text(t.settingsRegisterTitle, style: onest(16, weight: 600)),
          const SizedBox(height: 12),
          InkWell(
            key: const ValueKey('show-source'),
            onTap: () => onShowSource(!showSource),
            child: Row(
              children: [
                Checkbox(
                  value: showSource,
                  onChanged: (v) => onShowSource(v ?? false),
                ),
                Expanded(
                  child: Text(
                    t.settingsSourceColumn,
                    style: onest(13.5, color: Mid.ink),
                  ),
                ),
              ],
            ),
          ),
          if (here != null || others.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(t.settingsComputersTitle, style: onest(13.5, color: Mid.ink3)),
            const SizedBox(height: 8),
            if (here case final id?)
              _SourceName(
                key: ValueKey('computer-$id'),
                label: t.settingsComputerThis,
                settingKey: '$computerNamePrefix$id',
                name: computers[id] ?? '',
                hint: null,
                onName: onName,
              ),
            for (final id in others)
              _SourceName(
                key: ValueKey('computer-$id'),
                label: t.settingsComputerName(short(id)),
                settingKey: '$computerNamePrefix$id',
                name: computers[id] ?? '',
                hint: null,
                onName: onName,
              ),
          ],
          if (phones.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(t.settingsPhonesTitle, style: onest(13.5, color: Mid.ink3)),
            const SizedBox(height: 8),
            for (final e in phones.entries)
              _SourceName(
                key: ValueKey('phone-${e.key}'),
                label: t.settingsPhoneName(short(e.key)),
                settingKey: '$phoneNamePrefix${e.key}',
                name: e.value,
                hint: t.settingsPhoneNameHint,
                onName: onName,
              ),
          ],
        ],
      ),
    );
  }
}

/// One computer's or phone's name box: saved as it is left, submitted, or
/// the page is left.
class _SourceName extends StatefulWidget {
  const _SourceName({
    super.key,
    required this.label,
    required this.settingKey,
    required this.name,
    required this.hint,
    required this.onName,
  });

  /// An example in the empty box, if one helps.
  final String? hint;
  final String label;
  final String settingKey;
  final String name;
  final void Function(String key, String name) onName;

  @override
  State<_SourceName> createState() => _SourceNameState();
}

class _SourceNameState extends State<_SourceName> {
  late final _controller = TextEditingController(text: widget.name);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _save();
    });
  }

  void _save() {
    if (_controller.text.trim() != widget.name.trim()) {
      widget.onName(widget.settingKey, _controller.text);
    }
  }

  @override
  void didUpdateWidget(_SourceName old) {
    super.didUpdateWidget(old);
    // Named on another computer meanwhile; what is being typed stays.
    if (!_focus.hasFocus && widget.name != old.name) {
      _controller.text = widget.name;
    }
  }

  @override
  void dispose() {
    // Typed and then clicked away to another page: kept.
    _save();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(widget.label, style: onest(13.5, color: Mid.ink2)),
          ),
          SizedBox(
            width: 260,
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              style: onest(13.5, color: Mid.ink),
              decoration: InputDecoration(isDense: true, hintText: widget.hint),
              onSubmitted: (_) => _save(),
            ),
          ),
        ],
      ),
    );
  }
}
