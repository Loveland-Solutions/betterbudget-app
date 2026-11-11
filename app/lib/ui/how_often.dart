part of 'ledger_screen.dart';

/// The dropdowns How often has, held by whoever shows it so Esc can close
/// one that is open.
class _HowOftenMenus {
  final repeat = MenuController();
  final unit = MenuController();
  final weekend = MenuController();
  final nth = MenuController();
  final nthWeekday = MenuController();

  List<MenuController> get all => [repeat, unit, weekend, nth, nthWeekday];
}

/// One line of a form: a label in its column, the control, and a quiet
/// note beside it when one is needed.
Widget _formRow(String label, Widget child, {String? aside}) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Row(
    children: [
      SizedBox(
        width: 214,
        child: Text(label, style: onest(13, color: Mid.ink2)),
      ),
      child,
      if (aside != null)
        Flexible(
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              aside,
              style: onest(12.5, color: Mid.ink3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
    ],
  ),
);

/// One weekday in Custom…'s row of them, lit when picked.
Widget _dayChip(
  String label, {
  required String key,
  required bool on,
  required VoidCallback onTap,
}) => Padding(
  padding: const EdgeInsets.only(right: 6),
  child: Hoverable(
    key: ValueKey(key),
    onTap: onTap,
    builder: (hover) => Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? Mid.blueWash : (hover ? Mid.raised : Colors.transparent),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: on ? Mid.blue : Mid.ink2.withValues(alpha: 0.3),
        ),
      ),
      child: Text(label, style: onest(12.5, color: on ? Mid.ink : Mid.ink2)),
    ),
  ),
);

/// How often, from "Every month" to Custom…, and what it needs: the date it
/// starts from or its days, the weekend rule, the pattern of a custom one,
/// and when it ends. A category's plan and an income's pay ask it the same
/// way, from the same [PlanAnswers] (#438); each says what its own first
/// date is called and what else its list holds.
class _HowOftenRows extends StatelessWidget {
  const _HowOftenRows({
    required this.p,
    required this.data,
    required this.today,
    required this.tried,
    required this.menus,
    required this.onSave,
    required this.onChanged,
    required this.dateFocus,
    this.datesFocus,
    this.day1Focus,
    this.onMenuOpen,
    this.wrongDate = false,
    this.offerOnce = true,
    this.offerPayday = true,
    this.extra = const [],
    this.dateLabel,
    this.showRest = true,
  });

  final PlanAnswers p;
  final LedgerData data;
  final DateTime today;

  /// Save was tried: what's missing is marked.
  final bool tried;
  final bool wrongDate;
  final _HowOftenMenus menus;
  final VoidCallback onSave;

  /// An answer changed: the form shows it.
  final VoidCallback onChanged;
  final FocusNode dateFocus;
  final FocusNode? datesFocus;
  final FocusNode? day1Focus;

  /// A dropdown is about to open: the date's calendar steps aside.
  final VoidCallback? onMenuOpen;

  /// "Once" and "Every payday of …" are a category's; an income has neither.
  final bool offerOnce;
  final bool offerPayday;

  /// Choices a form adds to the end of the list.
  final List<({String key, String label, bool on, VoidCallback onTap})> extra;

  /// What the first date is called; null: "Due date".
  final String? dateLabel;

  /// False when [extra]'s choice was picked and says it needs nothing more.
  final bool showRest;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    void setState(VoidCallback f) {
      f();
      onChanged();
    }

    Widget dayBox(
      TextEditingController controller,
      String key, {
      FocusNode? focus,
    }) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        width: 56,
        height: 34,
        child: TextField(
          key: ValueKey(key),
          controller: controller,
          focusNode: focus,
          textAlign: TextAlign.center,
          style: onest(13.5, tabular: true),
          onSubmitted: (_) => onSave(),
          decoration: _fieldDecoration(
            wrong: tried && p.typedMonthDays == null,
          ),
        ),
      ),
    );
    Widget menu(
      MenuController controller, {
      required String key,
      required String label,
      required List<Widget> items,
    }) => SizedBox(
      height: 34,
      child: MenuAnchor(
        controller: controller,
        style: _menuStyle,
        menuChildren: focusFirstOnKeys(items),
        // Its own width: in a row, an Align would take the whole line.
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: BarButton(
            key: ValueKey(key),
            label: label,
            trailing: Icons.expand_more_rounded,
            active: controller.isOpen,
            onTap: () {
              // The date's calendar shows while the date has the keys,
              // and would sit over the rows below: a dropdown takes them.
              if (dateFocus.hasFocus) onMenuOpen?.call();
              controller.isOpen ? controller.close() : controller.open();
            },
          ),
        ),
      ),
    );
    Widget item(
      String key,
      String label, {
      required bool on,
      required VoidCallback onTap,
    }) => MenuItemButton(
      key: ValueKey(key),
      onPressed: onTap,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(180, 34)),
        overlayColor: WidgetStatePropertyAll(Mid.blueWash),
      ),
      child: Text(label, style: onest(13, color: on ? Mid.ink : Mid.ink2)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _formRow(
          t.planHowOften,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              menu(
                menus.repeat,
                key: 'plan-repeat',
                label: planRepeatLabel(t, data, p),
                items: [
                  if (offerOnce)
                    item(
                      'plan-repeat-0',
                      t.planOnce,
                      on: p.repeat == PlanRepeat.once,
                      onTap: () => setState(() => p.repeat = PlanRepeat.once),
                    ),
                  for (final (key, n, unit, label) in [
                    ('plan-repeat-d7', 1, PlanUnit.weeks, t.planRepeatWeeks(1)),
                    (
                      'plan-repeat-d14',
                      2,
                      PlanUnit.weeks,
                      t.planRepeatWeeks(2),
                    ),
                  ])
                    item(
                      key,
                      label,
                      on:
                          p.repeat == PlanRepeat.every &&
                          !p.custom &&
                          p.unit == unit &&
                          p.typedEveryN == n,
                      onTap: () => setState(() => p.preset(n, unit)),
                    ),
                  item(
                    'plan-repeat-twice',
                    t.planTwiceAMonth,
                    on: p.repeat == PlanRepeat.twice,
                    onTap: () => setState(() => p.repeat = PlanRepeat.twice),
                  ),
                  for (final (key, n, unit, label) in [
                    (
                      'plan-repeat-1',
                      1,
                      PlanUnit.months,
                      t.planRepeatMonths(1),
                    ),
                    (
                      'plan-repeat-3',
                      3,
                      PlanUnit.months,
                      t.planRepeatMonths(3),
                    ),
                    ('plan-repeat-12', 1, PlanUnit.years, t.planRepeatYears(1)),
                  ])
                    item(
                      key,
                      label,
                      on:
                          p.repeat == PlanRepeat.every &&
                          !p.custom &&
                          p.unit == unit &&
                          p.typedEveryN == n,
                      onTap: () => setState(() => p.preset(n, unit)),
                    ),
                  // Payday by payday: only with pay set up.
                  if (offerPayday)
                    for (final pay in data.paySchedules)
                      item(
                        'plan-repeat-pay-${pay.id}',
                        planPaydayLabel(t, data, pay),
                        on:
                            p.repeat == PlanRepeat.payday &&
                            p.payScheduleId == pay.id,
                        onTap: () => setState(() {
                          p.repeat = PlanRepeat.payday;
                          p.payScheduleId = pay.id;
                        }),
                      ),
                  item(
                    'plan-repeat-custom',
                    t.planEveryCustom,
                    on: p.repeat == PlanRepeat.every && p.custom,
                    onTap: () => setState(() {
                      p.repeat = PlanRepeat.every;
                      p.custom = true;
                    }),
                  ),
                  item(
                    'plan-repeat-dates',
                    t.planOnDates,
                    on: p.repeat == PlanRepeat.dates,
                    onTap: () => setState(() => p.repeat = PlanRepeat.dates),
                  ),
                  for (final e in extra)
                    item(e.key, e.label, on: e.on, onTap: e.onTap),
                ],
              ),
            ],
          ),
        ),
        if (showRest) ...[
          if (p.repeat == PlanRepeat.payday)
            _formRow(
              t.planLabelDueDate,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 56,
                    height: 34,
                    child: TextField(
                      key: const ValueKey('plan-days-after'),
                      controller: p.daysAfter,
                      textAlign: TextAlign.center,
                      style: onest(13.5, tabular: true),
                      onSubmitted: (_) => onSave(),
                      decoration: _fieldDecoration(wrong: false).copyWith(
                        hintText: '0',
                        hintStyle: onest(13.5, color: Mid.ink3),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(t.planDaysAfterPay, style: onest(13, color: Mid.ink2)),
                ],
              ),
              aside: p.daysAfterNow == 0 ? t.planOnPayday : null,
            )
          else
            _formRow(
              p.repeat == PlanRepeat.dates
                  ? t.planDatesLabel
                  : dateLabel ?? t.planLabelDueDate,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (p.repeat == PlanRepeat.dates)
                    SizedBox(
                      width: 300,
                      height: 34,
                      child: TextField(
                        key: const ValueKey('plan-dates'),
                        controller: p.dates,
                        focusNode: datesFocus,
                        style: onest(13.5, tabular: true),
                        onSubmitted: (_) => onSave(),
                        decoration:
                            _fieldDecoration(
                              wrong:
                                  tried &&
                                  (p.typedDates == null ||
                                      p.typedDates!.isEmpty),
                            ).copyWith(
                              hintText: t.planDatesHint,
                              hintStyle: onest(13.5, color: Mid.ink3),
                            ),
                      ),
                    )
                  else if (p.repeat == PlanRepeat.twice)
                    ...withFields(
                      t.setupOnDaysField(fieldMarks[0], fieldMarks[1]),
                      [
                        dayBox(p.day1, 'plan-day1', focus: day1Focus),
                        dayBox(p.day2, 'plan-day2'),
                      ],
                    )
                  else
                    SizedBox(
                      width: 130,
                      height: 34,
                      child: DateField(
                        key: const ValueKey('plan-date'),
                        controller: p.date,
                        focusNode: dateFocus,
                        today: today,
                        small: true,
                        // Beside, not under: under it are Paid from and Save.
                        calendarBeside: true,
                        wanted: wrongDate,
                        onSubmitted: onSave,
                        onPicked: () {},
                      ),
                    ),
                  // A weekend rule, for dates that can land on one (not
                  // chosen weekdays: those are the days).
                  if (p.repeat != PlanRepeat.once && p.weekdaysNow == null) ...[
                    const SizedBox(width: 10),
                    menu(
                      menus.weekend,
                      key: 'plan-weekend',
                      label: planWeekendLabel(t, p.weekend),
                      items: [
                        for (final w in PayWeekend.values)
                          item(
                            'plan-weekend-${w.name}',
                            planWeekendLabel(t, w),
                            on: w == p.weekend,
                            onTap: () => setState(() => p.weekend = w),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          // Custom…: the pattern laid out like a calendar app's recurrence
          // (owner, 2026-10-05), under the date it starts from: how many of
          // which unit, the weekdays or the nth weekday when the unit has
          // them, and when it ends.
          if (p.customOn) ...[
            _formRow(
              t.planRepeatEvery,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 56,
                    height: 34,
                    child: TextField(
                      key: const ValueKey('plan-every-n'),
                      controller: p.everyN,
                      textAlign: TextAlign.center,
                      style: onest(13.5, tabular: true),
                      onSubmitted: (_) => onSave(),
                      decoration: _fieldDecoration(
                        wrong: tried && p.typedEveryN == null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  menu(
                    menus.unit,
                    key: 'plan-every-unit',
                    label: planUnitLabel(t, p.unit),
                    items: [
                      for (final u in PlanUnit.values)
                        item(
                          'plan-every-unit-${u.name}',
                          planUnitLabel(t, u),
                          on: u == p.unit,
                          onTap: () => setState(() => p.unit = u),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (p.unit == PlanUnit.weeks)
              _formRow(
                t.planOnWeekdays,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, initial)
                        in t.rowsWeekdayInitials.split('|').indexed)
                      _dayChip(
                        initial,
                        key: 'plan-weekday-${i + 1}',
                        on: p.weekdays.contains(i + 1),
                        onTap: () => setState(
                          () => p.weekdays.contains(i + 1)
                              ? p.weekdays.remove(i + 1)
                              : p.weekdays.add(i + 1),
                        ),
                      ),
                  ],
                ),
                aside: p.weekdays.isEmpty ? t.planWeekdaysHint : null,
              ),
            if (p.unit == PlanUnit.months || p.unit == PlanUnit.years)
              _formRow(
                t.planOnLabel,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Segmented(
                      items: [
                        (
                          'plan-nth-off',
                          t.planDayOfMonth,
                          !p.nthOn,
                          () => setState(() => p.nthOn = false),
                        ),
                        (
                          'plan-nth-on',
                          t.planAWeekday,
                          p.nthOn,
                          () => setState(p.startNth),
                        ),
                      ],
                    ),
                    if (p.nthOn) ...[
                      const SizedBox(width: 8),
                      menu(
                        menus.nth,
                        key: 'plan-nth',
                        label: planNthLabel(t, p.nth),
                        items: [
                          for (final n in const [1, 2, 3, 4, -1])
                            item(
                              'plan-nth-$n',
                              planNthLabel(t, n),
                              on: n == p.nth,
                              onTap: () => setState(() => p.nth = n),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      menu(
                        menus.nthWeekday,
                        key: 'plan-nth-weekday',
                        label: planWeekdayName(t, p.nthWeekday),
                        items: [
                          for (var wd = 1; wd <= 7; wd++)
                            item(
                              'plan-nth-weekday-$wd',
                              planWeekdayName(t, wd),
                              on: wd == p.nthWeekday,
                              onTap: () => setState(() => p.nthWeekday = wd),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
          ],
          if (p.endsOn)
            _formRow(
              t.planEnds,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Segmented(
                    items: [
                      for (final (e, label) in [
                        (PlanEnds.never, t.planEndsNever),
                        (PlanEnds.date, t.planEndsOn),
                        (PlanEnds.count, t.planEndsAfter),
                      ])
                        (
                          'plan-ends-${e.name}',
                          label,
                          p.ends == e,
                          () => setState(() => p.ends = e),
                        ),
                    ],
                  ),
                  if (p.ends == PlanEnds.date) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 130,
                      height: 34,
                      child: TextField(
                        key: const ValueKey('plan-end-date'),
                        controller: p.endDate,
                        style: onest(13.5, tabular: true),
                        onSubmitted: (_) => onSave(),
                        decoration:
                            _fieldDecoration(
                              wrong: tried && p.typedEndDate == null,
                            ).copyWith(
                              hintText: t.planEndDateHint,
                              hintStyle: onest(13.5, color: Mid.ink3),
                            ),
                      ),
                    ),
                  ],
                  if (p.ends == PlanEnds.count) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 56,
                      height: 34,
                      child: TextField(
                        key: const ValueKey('plan-end-count'),
                        controller: p.endCount,
                        textAlign: TextAlign.center,
                        style: onest(13.5, tabular: true),
                        onSubmitted: (_) => onSave(),
                        decoration: _fieldDecoration(
                          wrong: tried && p.typedEndCount == null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(t.planEndsTimes, style: onest(13, color: Mid.ink2)),
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }
}
