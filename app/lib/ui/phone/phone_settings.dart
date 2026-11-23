part of 'phone_app.dart';

// Settings on the phone (#534 piece 5, the owner's pick of sketch A, ADR
// 0004 "Settings on the phone"): the computer's Settings in the phone's
// form, one scroll of its cards in its order, opened by the gear beside
// Accounts on Budget. Backups and Another phone or computer stay on
// Accounts.

void _openSettings(
  BuildContext context, {
  required PhoneStore store,
  required DateTime Function() now,
  ProblemLog? problems,
}) => unawaited(
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          _SettingsPage(store: store, now: now, problems: problems),
    ),
  ),
);

/// A card of Settings: its title over what it holds.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    super.key,
    required this.title,
    required this.children,
  });
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
    decoration: BoxDecoration(
      color: Mid.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Mid.rule),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: onest(17, weight: 600)),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

/// One of a row of choices, outlined in blue while it is the one set.
class _SettingTap extends StatelessWidget {
  const _SettingTap({
    super.key,
    required this.label,
    required this.chosen,
    required this.onTap,
  });
  final String label;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: chosen ? Mid.blueWash : Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(
        color: chosen ? Mid.blue : Mid.ink2.withValues(alpha: 0.3),
        width: chosen ? 2 : 1,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: onest(
                14,
                weight: chosen ? 600 : 400,
                color: chosen ? Mid.ink : Mid.ink2,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Choices side by side, each as wide and as tall as the others.
Widget _settingRow(List<Widget> choices) => IntrinsicHeight(
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < choices.length; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(child: choices[i]),
      ],
    ],
  ),
);

/// A color scheme to pick: its four colors over its name.
class _PhoneSchemeTile extends StatelessWidget {
  const _PhoneSchemeTile({
    required this.scheme,
    required this.chosen,
    required this.onTap,
  });
  final Scheme scheme;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    key: ValueKey('scheme-${scheme.id}'),
    color: chosen ? Mid.blueWash : Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(
        color: chosen ? Mid.blue : Mid.ink2.withValues(alpha: 0.3),
        width: chosen ? 2 : 1,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 22,
                child: Row(
                  children: [
                    for (final c in scheme.colors)
                      Expanded(
                        child: ColoredBox(
                          color: c,
                          child: const SizedBox.expand(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              schemeName(context.t, scheme),
              maxLines: 2,
              style: onest(
                12,
                weight: chosen ? 600 : 400,
                color: chosen ? Mid.ink : Mid.ink2,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Schemes three to a row.
Widget _schemeGrid(List<Widget> tiles) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (var i = 0; i < tiles.length; i += 3) ...[
      if (i > 0) const SizedBox(height: 8),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var j = i; j < i + 3; j++) ...[
              if (j > i) const SizedBox(width: 8),
              Expanded(
                child: j < tiles.length ? tiles[j] : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ),
    ],
  ],
);

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({required this.store, required this.now, this.problems});
  final PhoneStore store;
  final DateTime Function() now;
  final ProblemLog? problems;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  PhoneStore get store => widget.store;

  /// Every color scheme shown, not only the one set.
  var _allColors = false;

  /// Version and build, for a bug report; null until read, or where it
  /// can't be (tests).
  (String, String)? _version;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then(
      (info) {
        if (mounted) setState(() => _version = (info.version, info.buildNumber));
      },
      onError: (Object _) {},
    );
  }

  Future<PhoneActed?> _act(PhoneRowAct act) async {
    try {
      return await store.actRow(act);
    } catch (e) {
      debugPrint('A setting on the phone wasn’t saved: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              persist: false,
              duration: phoneSnackTime,
              key: const ValueKey('settings-refused'),
              backgroundColor: Mid.raised,
              content: Text(
                context.t.ledgerCouldntSave,
                style: onest(15, color: Mid.ink),
              ),
            ),
          );
      }
      return null;
    }
  }

  Widget _appearance(BuildContext context, AppearanceController c) {
    final t = context.t;
    Widget choice(Appearance a, String label) => _SettingTap(
      key: ValueKey('appearance-${a.name}'),
      label: label,
      chosen: c.value == a,
      // No toast: the whole page changing says it happened, and a tap on
      // the one before puts it back.
      onTap: () => unawaited(c.set(a)),
    );
    return _SettingsCard(
      key: const ValueKey('settings-appearance'),
      title: t.ledgerAppearanceTitle,
      children: [
        _settingRow([
          choice(Appearance.system, t.languageSameAsPhone),
          choice(Appearance.light, t.ledgerAppearanceLight),
          choice(Appearance.dark, t.ledgerAppearanceDark),
        ]),
        if (c.value == Appearance.system) ...[
          const SizedBox(height: 8),
          Text(
            (Mid.isLight ? t.ledgerShowingLightNow : t.ledgerShowingDarkNow)(
              t.thePhone,
            ),
            style: onest(14, color: Mid.ink2),
          ),
        ],
        const SizedBox(height: 18),
        Text(t.appearanceColorsTitle, style: onest(17, weight: 600)),
        const SizedBox(height: 12),
        if (!_allColors)
          _schemeGrid([
            _PhoneSchemeTile(
              scheme: c.scheme,
              chosen: true,
              onTap: () => setState(() => _allColors = true),
            ),
          ])
        else ...[
          _schemeGrid([
            _PhoneSchemeTile(
              scheme: betterBudgetScheme,
              chosen: c.scheme.id == betterBudgetScheme.id,
              onTap: () => unawaited(c.setScheme(betterBudgetScheme)),
            ),
          ]),
          for (final g in SchemeGroup.values) ...[
            const SizedBox(height: 16),
            Text(
              schemeGroupName(t, g),
              style: onest(14, weight: 500, color: Mid.ink2),
            ),
            const SizedBox(height: 8),
            _schemeGrid([
              for (final s in schemes.where((s) => s.group == g))
                _PhoneSchemeTile(
                  scheme: s,
                  chosen: s.id == c.scheme.id,
                  onTap: () => unawaited(c.setScheme(s)),
                ),
            ]),
          ],
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const ValueKey('colors-all'),
            onPressed: () => setState(() => _allColors = !_allColors),
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: EdgeInsets.zero,
              foregroundColor: Mid.blue,
              textStyle: onest(15),
            ),
            child: Text(
              _allColors
                  ? t.appearanceColorsHide
                  : t.appearanceColorsShowAll(schemes.length),
            ),
          ),
        ),
      ],
    );
  }

  Widget _language(BuildContext context, LanguageController c) {
    final t = context.t;
    Widget choice(Language l, String label) => _SettingTap(
      key: ValueKey('language-${l.name}'),
      label: label,
      chosen: c.value == l,
      onTap: () => unawaited(c.set(l)),
    );
    return _SettingsCard(
      key: const ValueKey('settings-language'),
      title: t.languageTitle,
      children: [
        _settingRow([
          choice(Language.system, t.languageSameAsPhone),
          choice(Language.english, t.languageEnglish),
          choice(Language.mongolian, t.languageMongolian),
        ]),
        if (c.value == Language.system) ...[
          const SizedBox(height: 8),
          Text(
            t.languageShowingNow(
              Localizations.localeOf(context).languageCode == 'mn'
                  ? t.languageMongolian
                  : t.languageEnglish,
              t.thePhone,
            ),
            style: onest(14, color: Mid.ink2),
          ),
        ],
      ],
    );
  }

  /// By month or by paycheck, and what was had before the budget: the
  /// computer's Budget card.
  Widget _budget(BuildContext context, LedgerData data) {
    final t = context.t;
    final main = Budget.currencyOf(data);
    final currencies = <Currency>[main];
    for (final a in data.accounts.values) {
      if (Budget.counts(a, a.currency) &&
          !a.archived &&
          !currencies.contains(a.currency)) {
        currencies.add(a.currency);
      }
    }
    final began = data.prefs[BudgetKeys.began];
    final by = data.periodSchedule;
    final one = data.paySchedules.length == 1;
    return _SettingsCard(
      key: const ValueKey('settings-budget'),
      title: t.settingsBudgetTitle,
      children: [
        if (data.paySchedules.isNotEmpty) ...[
          Text(t.budgetByHint, style: onest(14, color: Mid.ink2)),
          const SizedBox(height: 10),
          for (final row in [
            (key: 'budget-by-month', label: t.planByMonth, schedule: null),
            for (final p in data.paySchedules)
              (
                key: 'budget-by-${p.id}',
                label: one
                    ? t.planByPaycheck
                    : t.planByPaychecksOf(payTitle(t, data, p)),
                schedule: p.id as int?,
              ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _SettingTap(
                key: ValueKey(row.key),
                label: row.label,
                chosen: by?.id == row.schedule,
                onTap: () async {
                  if (by?.id == row.schedule) return;
                  // A view, as on the computer: no toast.
                  await _act(PhoneBudgetBy(row.schedule));
                },
              ),
            ),
          const SizedBox(height: 10),
        ],
        for (final c in currencies)
          _PhoneHadBefore(
            key: ValueKey('had-before-${c.code}'),
            currency: c,
            amount: hadBeforeOf(
              data,
              c,
              switch (data.prefs[BudgetKeys.beganIn(c)] ?? began) {
                final String d => parseDateKey(d),
                null => null,
              },
            ),
            onSave: (v) => unawaited(_hadBefore(c, v)),
          ),
        Text(
          began == null
              ? t.settingsHadBeforeHintOff
              : t.settingsHadBeforeHintOn(sayDate(t, parseDateKey(began))),
          style: onest(14, color: Mid.ink2),
        ),
      ],
    );
  }

  /// A figure typed takes the place of setup's, which followed the
  /// accounts (#618).
  Future<void> _hadBefore(Currency c, int? v) async {
    final t = context.t;
    final done = await _act(
      PhoneSetPrefs({
        BudgetKeys.hadBefore(c): v?.toString(),
        BudgetKeys.hadFrom(c): null,
      }),
    );
    if (done == null || !mounted) return;
    _saidWithUndo(
      context,
      store,
      done,
      v == null
          ? t.settingsHadBeforeCleared
          : t.settingsHadBeforeSet(formatMoney(v, currency: c)),
      'had-before-done',
    );
  }

  Widget _thisPhone(BuildContext context, LedgerData data) {
    final t = context.t;
    final key = '$phoneNamePrefix${store.device}';
    return _SettingsCard(
      key: const ValueKey('settings-this-phone'),
      title: t.phoneSettingsThisPhone,
      children: [
        _PhoneNameField(
          name: data.prefs[key] ?? '',
          // Saved quietly, as the computer's names are.
          onSave: (name) =>
              unawaited(_act(PhoneSetPrefs({key: name.isEmpty ? null : name}))),
        ),
        const SizedBox(height: 8),
        Text(t.phoneSettingsNameNote, style: onest(14, color: Mid.ink2)),
      ],
    );
  }

  Widget _security(BuildContext context) {
    final t = context.t;
    final check = store.checkKey;
    return _SettingsCard(
      key: const ValueKey('settings-security'),
      title: t.ledgerSecurityTitle,
      children: [
        Text(t.phoneSecurityNote, style: onest(15, color: Mid.ink)),
        if (check != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            key: const ValueKey('check-recovery-key'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _CheckKeyPage(check: check),
              ),
            ),
            style: _outlined(Mid.blue),
            child: Text(t.ledgerCheckRecoveryKey),
          ),
        ],
      ],
    );
  }

  Widget _archived(BuildContext context, LedgerData data) {
    final t = context.t;
    return _SettingsCard(
      key: const ValueKey('settings-archived'),
      title: t.setupArchived,
      children: [
        for (final a in data.archivedAccounts)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.name, style: onest(16, weight: 500)),
                      Text(
                        formatMoney(
                          data.balanceOf(a.id),
                          currency: a.currency,
                        ),
                        style: onest(14, color: Mid.ink2, tabular: true),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  key: ValueKey('unarchive-${a.id}'),
                  onPressed: () async {
                    final done = await _act(PhoneArchiveAccount(a.id, false));
                    if (done == null || !context.mounted) return;
                    _saidWithUndo(
                      context,
                      store,
                      done,
                      t.phoneBackInAccounts(a.name),
                      'unarchived',
                    );
                  },
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: Mid.blue,
                    textStyle: onest(15),
                  ),
                  child: Text(t.phoneShowInAccounts),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _startOver(BuildContext context, LedgerData data) {
    final t = context.t;
    return _SettingsCard(
      key: const ValueKey('settings-start-over'),
      title: t.ledgerStartOverTitle,
      children: [
        Text(t.ledgerStartOverNote, style: onest(15, color: Mid.ink)),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const ValueKey('start-over'),
          onPressed: () => unawaited(_eraseAsk(context, data)),
          style: _outlined(Mid.coral),
          child: Text(t.ledgerEraseAndStartOverButton),
        ),
      ],
    );
  }

  /// Says everything that goes, with real figures, then erases it with
  /// Undo: the computer's Start over.
  Future<void> _eraseAsk(BuildContext context, LedgerData data) async {
    final t = context.t;
    final keep = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Mid.ground,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EraseAsk(data: data),
    );
    if (keep == null || !mounted) return;
    final done = await _act(PhoneStartOver(keepCategories: keep));
    if (done == null || !mounted) return;
    _saidWithUndo(
      this.context,
      store,
      done,
      t.ledgerEverythingErased,
      'erased',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final appearance = AppearanceScope.maybeOf(context);
    final language = LanguageScope.maybeOf(context);
    return Scaffold(
      backgroundColor: Mid.ground,
      appBar: AppBar(
        backgroundColor: Mid.ground,
        foregroundColor: Mid.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(t.ledgerSettings, style: onest(20, weight: 600)),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final data = store.snapshot.data;
          final problems = widget.problems;
          return ListView(
            key: const ValueKey('settings-list'),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              for (final card in [
                if (appearance != null) _appearance(context, appearance),
                if (language != null) _language(context, language),
                if (data != null) _budget(context, data),
                if (data != null) _thisPhone(context, data),
                _security(context),
                if (data != null && data.archivedAccounts.isNotEmpty)
                  _archived(context, data),
                if (problems != null)
                  _RecentProblemsLine(log: problems, now: widget.now),
                // Where its copy is kept: a phone on a computer's folder
                // has no Backups to put it back from, and the computer
                // starts over for everyone.
                if (data != null && store.backupActs != null)
                  _startOver(context, data),
              ]) ...[card, const SizedBox(height: 12)],
              if (_version case (final name, final build))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    t.settingsVersion(name, build),
                    key: const ValueKey('settings-version'),
                    textAlign: TextAlign.center,
                    style: onest(13, color: Mid.ink2),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  t.settingsCredit,
                  textAlign: TextAlign.center,
                  style: onest(13, color: Mid.ink3),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

ButtonStyle _outlined(Color color) => OutlinedButton.styleFrom(
  minimumSize: const Size.fromHeight(48),
  foregroundColor: color,
  side: BorderSide(
    color: color == Mid.coral ? Mid.coral.withValues(alpha: 0.5) : Mid.rule,
  ),
  textStyle: onest(16),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
);

/// One currency's Had before the budget: saved as it is left or submitted,
/// emptied to take it out. Only what was typed is saved, so leaving the
/// page never rewrites a figure that follows the accounts (#618).
class _PhoneHadBefore extends StatefulWidget {
  const _PhoneHadBefore({
    super.key,
    required this.currency,
    required this.amount,
    required this.onSave,
  });
  final Currency currency;
  final int? amount;
  final ValueChanged<int?> onSave;

  @override
  State<_PhoneHadBefore> createState() => _PhoneHadBeforeState();
}

class _PhoneHadBeforeState extends State<_PhoneHadBefore> {
  late final _controller = TextEditingController(text: _shown(widget.amount));
  final _focus = FocusNode();
  var _wrong = false;
  late int? _saved = widget.amount == 0 ? null : widget.amount;
  var _edited = false;

  String _shown(int? v) {
    if (v == null || v == 0) return '';
    final c = widget.currency, abs = v.abs();
    return '${v < 0 ? '-' : ''}${formatWhole(abs, c)}'
        '${c.hasCents(abs) ? formatCents(abs, c) : ''}';
  }

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _save();
    });
  }

  void _save() {
    if (!_edited) return;
    final text = _controller.text.trim();
    final v = text.isEmpty ? null : parseAmount(text, widget.currency);
    // A minus is an overdrawn start, which setup can set (#617).
    if (text.isNotEmpty && v == null) {
      if (mounted) setState(() => _wrong = true);
      return;
    }
    final now = v == 0 ? null : v;
    _edited = false;
    if (now == _saved) return;
    _saved = now;
    widget.onSave(now);
  }

  @override
  void didUpdateWidget(_PhoneHadBefore old) {
    super.didUpdateWidget(old);
    // Changed by Undo or on another computer; what is being typed stays.
    if (!_focus.hasFocus && widget.amount != old.amount) {
      _saved = widget.amount == 0 ? null : widget.amount;
      _controller.text = _shown(widget.amount);
      _edited = false;
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
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        key: ValueKey('had-before-field-${widget.currency.code}'),
        controller: _controller,
        focusNode: _focus,
        keyboardType: const TextInputType.numberWithOptions(
          signed: true,
          decimal: true,
        ),
        inputFormatters: [GroupedAmount(widget.currency)],
        style: onest(16, color: Mid.ink, tabular: true),
        decoration: InputDecoration(
          labelText: t.settingsHadBefore,
          labelStyle: onest(14, color: Mid.ink2),
          hintText: '0',
          suffixText: widget.currency.symbol,
          errorText: _wrong ? '' : null,
        ),
        onChanged: (_) {
          _edited = true;
          if (_wrong) setState(() => _wrong = false);
        },
        onSubmitted: (_) => _save(),
      ),
    );
  }
}

/// This phone's name: saved as it is left or submitted.
class _PhoneNameField extends StatefulWidget {
  const _PhoneNameField({required this.name, required this.onSave});
  final String name;
  final ValueChanged<String> onSave;

  @override
  State<_PhoneNameField> createState() => _PhoneNameFieldState();
}

class _PhoneNameFieldState extends State<_PhoneNameField> {
  late final _controller = TextEditingController(text: widget.name);
  final _focus = FocusNode();
  late var _saved = widget.name.trim();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _save();
    });
  }

  void _save() {
    final v = _controller.text.trim();
    if (v == _saved) return;
    _saved = v;
    widget.onSave(v);
  }

  @override
  void didUpdateWidget(_PhoneNameField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && widget.name != old.name) {
      _controller.text = widget.name;
      _saved = widget.name.trim();
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
    return TextField(
      key: const ValueKey('phone-name-field'),
      controller: _controller,
      focusNode: _focus,
      textCapitalization: TextCapitalization.words,
      style: onest(16, color: Mid.ink),
      decoration: InputDecoration(
        labelText: t.phoneSettingsName,
        labelStyle: onest(14, color: Mid.ink2),
        hintText: t.settingsPhoneNameHint,
      ),
      onSubmitted: (_) => _save(),
    );
  }
}

/// Check my recovery key…: the key typed is worked out as the ledger's is
/// and compared; it is never shown or kept.
class _CheckKeyPage extends StatefulWidget {
  const _CheckKeyPage({required this.check});
  final Future<bool> Function(RecoveryKey key) check;

  @override
  State<_CheckKeyPage> createState() => _CheckKeyPageState();
}

class _CheckKeyPageState extends State<_CheckKeyPage> {
  final _text = TextEditingController();
  String? _error;
  bool? _opens;
  var _busy = false;

  Future<void> _go() async {
    if (_busy) return;
    final problem = RecoveryKey.check(_text.text);
    final key = problem == null ? RecoveryKey.parse(_text.text) : null;
    if (key == null) {
      setState(() {
        _error = problem == null
            ? context.t.startKeyChecksum
            : keyProblem(context.t, problem);
        _opens = null;
      });
      return;
    }
    setState(() => _busy = true);
    final bool opens;
    try {
      opens = await widget.check(key);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) {
      setState(() {
        _opens = opens;
        _error = null;
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      backgroundColor: Mid.ground,
      appBar: AppBar(
        backgroundColor: Mid.ground,
        foregroundColor: Mid.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(t.startCheckTitle, style: onest(20, weight: 600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text(t.startCheckBody, style: onest(16, color: Mid.ink)),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('check-key-field'),
            controller: _text,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            enableIMEPersonalizedLearning: false,
            textCapitalization: TextCapitalization.characters,
            style: onest(16),
            cursorColor: Mid.blue,
            decoration: InputDecoration(
              hintText: 'ABCDE-FGHJK-LMNPQ-RSTUV-WXYZ0',
              hintStyle: onest(16, color: Mid.ink3),
              errorText: _error,
              errorMaxLines: 3,
              errorStyle: onest(14, color: Mid.coral),
            ),
            onChanged: (_) {
              if (_opens != null || _error != null) {
                setState(() {
                  _opens = null;
                  _error = null;
                });
              }
            },
            onSubmitted: (_) => unawaited(_go()),
          ),
          if (_opens case final opens?) ...[
            const SizedBox(height: 12),
            Text(
              opens ? t.startCheckYes : t.startCheckNo,
              key: const ValueKey('check-key-said'),
              style: onest(16, weight: 600, color: opens ? Mid.green : Mid.coral),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            key: const ValueKey('check-key-go'),
            onPressed: _busy ? null : () => unawaited(_go()),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: Mid.fill,
              foregroundColor: Mid.onFill,
              textStyle: onest(17, weight: 600),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(t.startCheckAction),
          ),
        ],
      ),
    );
  }
}

/// Start over's question: everything that goes, with its figures, the
/// categories kept or erased, then Cancel or Erase everything. Pops whether
/// the categories stay, or null for Cancel.
class _EraseAsk extends StatefulWidget {
  const _EraseAsk({required this.data});
  final LedgerData data;

  @override
  State<_EraseAsk> createState() => _EraseAskState();
}

class _EraseAskState extends State<_EraseAsk> {
  var _keep = true;

  /// Accounts listed by name before "+ N more".
  static const _shown = 6;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final data = widget.data;
    final accounts = data.balanceSheetAccounts;
    final dates = data.txns.map((x) => x.date).toList()..sort();
    final first = dates.firstOrNull, last = dates.lastOrNull;
    // Income isn't one of theirs: it stays either way.
    final categories = data.categories.where((c) => !c.isIncome).length;
    final also = [
      if (data.paySchedules.isNotEmpty) t.ledgerYourPay,
      if (data.reconciliations.isNotEmpty)
        t.ledgerReconciles(data.reconciliations.length),
      t.ledgerPayees,
      t.ledgerBudgetSavingsSettings,
    ].join(' · ');
    Widget item(String left, String right) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(left, style: onest(15))),
          const SizedBox(width: 8),
          Text(right, style: onest(15, tabular: true)),
        ],
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('erase-ask'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.ledgerEraseTitle,
              style: onest(20, weight: 600, color: Mid.coral),
            ),
            const SizedBox(height: 12),
            Text(t.ledgerAllOfThisErased, style: onest(15, weight: 600)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              decoration: BoxDecoration(
                color: Mid.coral.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Mid.coral.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final a in accounts.take(_shown))
                    item(
                      a.archived ? t.ledgerArchivedName(a.name) : a.name,
                      formatMoney(data.balanceOf(a.id), currency: a.currency),
                    ),
                  if (accounts.length > _shown)
                    item(t.ledgerMoreAccounts(accounts.length - _shown), ''),
                  item(
                    t.ledgerTransactionCount(data.txns.length),
                    first == null || last == null
                        ? ''
                        : first == last
                        ? fullDate(first)
                        : '${fullDate(first)} – ${fullDate(last)}',
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(also, style: onest(15)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(t.ledgerStartWithNothing, style: onest(15)),
            if (categories > 0) ...[
              const SizedBox(height: 16),
              Text(
                t.ledgerYourCategories(categories),
                style: onest(15, weight: 600),
              ),
              const SizedBox(height: 8),
              _settingRow([
                _SettingTap(
                  key: const ValueKey('erase-keep'),
                  label: t.ledgerKeepThemEmpty,
                  chosen: _keep,
                  onTap: () => setState(() => _keep = true),
                ),
                _SettingTap(
                  key: const ValueKey('erase-drop'),
                  label: t.ledgerEraseThemToo,
                  chosen: !_keep,
                  onTap: () => setState(() => _keep = false),
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                _keep ? t.ledgerKeptNoRows : t.ledgerAddCategoriesAgain,
                style: onest(14, color: Mid.ink2),
              ),
            ],
            const SizedBox(height: 16),
            Text(t.ledgerEraseNote, style: onest(14, color: Mid.ink2)),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('erase-go'),
              onPressed: () =>
                  Navigator.of(context).pop(_keep && categories > 0),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: Mid.coral,
                foregroundColor: Mid.onAccent,
                textStyle: onest(17, weight: 600),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(t.ledgerEraseEverything),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              key: const ValueKey('erase-cancel'),
              onPressed: () => Navigator.of(context).pop(),
              style: _outlined(Mid.blue),
              child: Text(t.ledgerCancel),
            ),
          ],
        ),
      ),
    );
  }
}
