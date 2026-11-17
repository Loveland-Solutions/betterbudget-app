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

/// Settings' Budget card: by month or by a pay's paychecks, the one place
/// after setup it's switched (owner, 2026-11-16, #474); and what the
/// household had when the budget began, by currency (#461).
class _BudgetSettings extends StatelessWidget {
  const _BudgetSettings({
    required this.data,
    required this.onPick,
    required this.onHadBefore,
  });
  final LedgerData data;
  final ValueChanged<PaySchedule?> onPick;
  final void Function(Currency currency, int? amount) onHadBefore;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final main = Budget.currencyOf(data);
    // The budget's currency, then any other its cash or bank is in.
    final currencies = <Currency>[main];
    for (final a in data.accounts.values) {
      if (Budget.counts(a, a.currency) &&
          !a.archived &&
          !currencies.contains(a.currency)) {
        currencies.add(a.currency);
      }
    }
    final began = data.prefs[BudgetKeys.began];
    return Container(
      key: const ValueKey('settings-budget'),
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
          Text(t.settingsBudgetTitle, style: onest(16, weight: 600)),
          if (data.paySchedules.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              t.budgetByHint,
              style: onest(13, color: Mid.ink2, height: 1.4),
            ),
            const SizedBox(height: 12),
            _BudgetByChoice(data: data, onPick: onPick),
            const SizedBox(height: 20),
          ] else
            const SizedBox(height: 12),
          for (final c in currencies)
            _HadBefore(
              key: ValueKey('had-before-${c.code}'),
              currency: c,
              amount: int.tryParse(data.prefs[BudgetKeys.hadBefore(c)] ?? ''),
              onSave: (v) => onHadBefore(c, v),
            ),
          Text(
            began == null
                ? t.settingsHadBeforeHintOff
                : t.settingsHadBeforeHintOn(sayDate(t, parseDateKey(began))),
            style: onest(13, color: Mid.ink2, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// One currency's Had before the budget: saved as it is left or
/// submitted, emptied to take it out.
class _HadBefore extends StatefulWidget {
  const _HadBefore({
    super.key,
    required this.currency,
    required this.amount,
    required this.onSave,
  });
  final Currency currency;
  final int? amount;
  final ValueChanged<int?> onSave;

  @override
  State<_HadBefore> createState() => _HadBeforeState();
}

class _HadBeforeState extends State<_HadBefore> {
  late final _controller = TextEditingController(text: _shown(widget.amount));
  final _focus = FocusNode();
  var _wrong = false;

  String _shown(int? v) =>
      v == null || v == 0 ? '' : formatWhole(v, widget.currency);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _save();
    });
  }

  void _save() {
    final text = _controller.text.trim();
    final v = text.isEmpty ? null : parseAmount(text, widget.currency);
    if (text.isNotEmpty && (v == null || v < 0)) {
      if (mounted) setState(() => _wrong = true);
      return;
    }
    final now = v == 0 ? null : v;
    if (now != (widget.amount == 0 ? null : widget.amount)) widget.onSave(now);
  }

  @override
  void didUpdateWidget(_HadBefore old) {
    super.didUpdateWidget(old);
    // Changed by undo or on another computer; what is being typed stays.
    if (!_focus.hasFocus && widget.amount != old.amount) {
      _controller.text = _shown(widget.amount);
    }
  }

  @override
  void dispose() {
    _save();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(
              t.settingsHadBefore,
              style: onest(13.5, color: Mid.ink2),
            ),
          ),
          SizedBox(
            width: 200,
            child: TextField(
              key: ValueKey('had-before-field-${widget.currency.code}'),
              controller: _controller,
              focusNode: _focus,
              inputFormatters: [GroupedAmount(widget.currency)],
              style: onest(13.5, color: Mid.ink, tabular: true),
              decoration: InputDecoration(
                isDense: true,
                hintText: '0',
                suffixText: widget.currency.symbol,
                errorText: _wrong ? '' : null,
              ),
              onChanged: (_) {
                if (_wrong) setState(() => _wrong = false);
              },
              onSubmitted: (_) => _save(),
            ),
          ),
        ],
      ),
    );
  }
}
