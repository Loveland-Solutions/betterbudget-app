// A category's plan as its form asks for it (ADR 0004 rule 27, and "New
// category: one window with everything"): the computer's Edit and New
// category window, and the phone's New category page, ask the same
// questions in the same words and make the same plan from the answers.
// The forms lay it out; this holds the answers and what they add up to.
import 'package:flutter/widgets.dart';

import '../domain/budget.dart';
import '../domain/ledger.dart';
import '../domain/money.dart' hide typedAmount;
import '../domain/money.dart' as money show typedAmount;
import '../domain/pay.dart';
import 'data_words.dart' show payTitle;
import 'entry_row.dart' show parseEntryDate;
import 'language.dart';
import 'theme.dart' show fullDate, onest;

/// How a dated plan comes again, as How often asks it.
enum PlanRepeat { once, every, twice, dates, payday }

enum PlanEnds { never, date, count }

enum PlanUnit { days, weeks, months, years }

/// The plan's answers so far: what's typed, in controllers the form's
/// fields show, and what's picked.
class PlanAnswers {
  PlanAnswers({required this.today, required this.currency});

  final DateTime today;

  /// The category's currency: the amounts are typed in it.
  Currency currency;

  final amount = TextEditingController();
  final date = TextEditingController();

  /// Twice a month's Starts, apart from [date] so a look at Twice a
  /// month leaves the other repeats' date as it was (code review, #356).
  final start = TextEditingController();
  final upTo = TextEditingController();
  final everyN = TextEditingController(text: '1');
  final dates = TextEditingController();
  final day1 = TextEditingController();
  final day2 = TextEditingController();
  final daysAfter = TextEditingController();
  final endDate = TextEditingController();
  final endCount = TextEditingController(text: '12');

  /// A set amount's one period with an amount of its own (#100, "Just for
  /// December"): what's typed for it, 0 to skip it, empty for the plan's.
  final onceAmount = TextEditingController();

  /// The day that period starts, its own period around the one on screen;
  /// null where it isn't asked (a new category).
  DateTime? onceStart;

  /// Everything typed: a form rebuilds on it.
  Listenable get typing => Listenable.merge([
    amount,
    onceAmount,
    date,
    start,
    upTo,
    everyN,
    dates,
    day1,
    day2,
    daysAfter,
    endDate,
    endCount,
  ]);

  void dispose() {
    for (final c in [
      amount,
      onceAmount,
      date,
      start,
      upTo,
      everyN,
      dates,
      day1,
      day2,
      daysAfter,
      endDate,
      endCount,
    ]) {
      c.dispose();
    }
  }

  /// The one question: is there a due date? No: a set amount each period
  /// (or none, with the amount left empty). Yes: an amount by a date.
  bool hasDate = false;

  /// How often it comes, as the question is asked: once, every so many
  /// days, weeks, months or years, twice a month, on fixed dates each year,
  /// or every payday. [custom] shows the number and unit for "Every…".
  PlanRepeat repeat = PlanRepeat.once;
  bool custom = false;

  /// Twice a month asks when it starts ([start], left empty for this
  /// month): a category's bill does (owner, 2026-11-02, #356), regular
  /// income doesn't, its first payday being the first of its days.
  bool askStart = false;
  PlanUnit unit = PlanUnit.months;

  /// Custom… (owner, 2026-10-05, an Outlook-like block): every so many
  /// weeks on these weekdays (Monday 1); every so many months or years on
  /// the nth weekday instead of the day of the month; and when it ends.
  final Set<int> weekdays = {};
  bool nthOn = false;
  int nth = 1;
  int nthWeekday = 1;
  PlanEnds ends = PlanEnds.never;
  int? payScheduleId;
  PayWeekend weekend = PayWeekend.keep;
  bool rollover = true;

  /// A set amount: the money goes out within its period (groceries, gas),
  /// so the account's forecast takes it out a day at a time; false is
  /// money built up for later (car repairs), which the forecast leaves
  /// alone (#404). The phone doesn't ask, so one it makes is spent.
  bool spentEach = true;

  /// A set amount's own period: per this pay's periods, or per month
  /// (null). Owner, 2026-10-05: each category says how it's budgeted.
  int? eachPayId;

  String _amountText(int a) => a <= 0 ? '' : money.typedAmount(a, currency);

  /// Fills the answers from [p], or empties them. A new set amount starts
  /// per [periodPayId], the period the budget is seen by.
  /// [builtUp] starts a category with no plan yet on "Built up for
  /// something later": the Safety net is money put by, and starting it on
  /// the usual answer would have it draining the forecast the first time
  /// the owner gave it an amount (code review, #404).
  void show(CategoryPlan? p, {int? periodPayId, bool builtUp = false}) {
    hasDate = p?.kind == PlanKind.byDate;
    amount.text = _amountText(p?.amount ?? 0);
    date.text = p?.due == null ? '' : fullDate(p!.due!);
    custom = false;
    weekend = p?.weekend ?? PayWeekend.keep;
    payScheduleId = p?.kind == PlanKind.byDate ? p?.payScheduleId : null;
    // A set amount's own period: its own, or for a new one the period on
    // screen (budget review, 2026-10-05: made while viewing by a pay, it
    // shouldn't start as "each month · about ₮93,300 this pay period").
    eachPayId = p?.kind == PlanKind.each ? p?.payScheduleId : periodPayId;
    final after = p?.daysAfterPay ?? 0;
    daysAfter.text = after == 0 ? '' : '$after';
    dates.text = p?.onDates == null
        ? ''
        : [for (final (m, d) in p!.onDates!) monthDay(m, d)].join(', ');
    final days = p?.monthDays;
    day1.text = days == null ? '' : '${days.first}';
    day2.text = days == null ? '' : '${days.last}';
    start.text = days == null || p?.due == null ? '' : fullDate(p!.due!);
    var n = 1;
    if (p?.payScheduleId != null) {
      repeat = PlanRepeat.payday;
    } else if (p?.onDates != null) {
      repeat = PlanRepeat.dates;
    } else if (days != null) {
      repeat = PlanRepeat.twice;
    } else if (p?.everyDays case final days?) {
      repeat = PlanRepeat.every;
      unit = days % 7 == 0 ? PlanUnit.weeks : PlanUnit.days;
      n = days % 7 == 0 ? days ~/ 7 : days;
      custom = days != 7 && days != 14;
    } else if (p?.everyMonths case final months?) {
      repeat = PlanRepeat.every;
      unit = months % 12 == 0 ? PlanUnit.years : PlanUnit.months;
      n = months % 12 == 0 ? months ~/ 12 : months;
      custom = months != 1 && months != 3 && months != 12;
    } else {
      repeat = PlanRepeat.once;
      unit = PlanUnit.months;
    }
    everyN.text = '$n';
    // Custom…'s own answers: any of them makes the repeat a custom one.
    weekdays
      ..clear()
      ..addAll(p?.weekdays ?? const []);
    nthOn = p?.nth != null;
    nth = p?.nth ?? 1;
    nthWeekday = p?.nthWeekday ?? 1;
    ends = p?.endCount != null
        ? PlanEnds.count
        : p?.endDate != null
        ? PlanEnds.date
        : PlanEnds.never;
    endDate.text = p?.endDate == null ? '' : fullDate(p!.endDate!);
    endCount.text = '${p?.endCount ?? 12}';
    // A pattern makes it Custom…; an end alone doesn't, since Ends shows
    // under every repeat.
    if (p != null && (p.weekdays != null || p.nth != null)) custom = true;
    rollover = p?.rollover ?? true;
    spentEach = p?.spentEach ?? !builtUp;
    upTo.text = _amountText(p?.upTo ?? 0);
    showOnce(p);
  }

  /// [onceAmount] from [p]'s amount for the period at [onceStart].
  void showOnce(CategoryPlan? p) =>
      onceAmount.text = switch (p?.once[onceStart]) {
        null => '',
        0 => '0',
        final v => _amountText(v),
      };

  /// One of How often's ready-made choices.
  void preset(int n, PlanUnit u) {
    repeat = PlanRepeat.every;
    custom = false;
    everyN.text = '$n';
    unit = u;
  }

  /// Twice a month picked. A date typed for another repeat becomes its
  /// Starts while Starts is empty, unless it's gone by: an old bill's
  /// first date would bring back months of bills as overdue.
  void toTwice() {
    repeat = PlanRepeat.twice;
    if (!askStart || start.text.trim().isNotEmpty) return;
    if (typedDate case final d? when !d.isBefore(today)) {
      start.text = fullDate(d);
    }
  }

  /// "A weekday" picked: it starts from the date typed, its weekday and
  /// which one of the month it is.
  void startNth() {
    nthOn = true;
    if (typedDate case final d?) {
      nthWeekday = d.weekday;
      nth = (d.day - 1) ~/ 7 + 1;
      if (nth > 4) nth = -1;
    }
  }

  /// The plan the answers add up to: dated, a set amount, or none when
  /// the amount is left empty.
  PlanKind? get kind => hasDate
      ? PlanKind.byDate
      : amount.text.trim().isEmpty
      ? null
      : PlanKind.each;

  int? get typedAmount => switch (parseAmount(amount.text.trim(), currency)) {
    final a? when a > 0 => a,
    _ => null,
  };

  /// The cap, when one is typed; empty is no cap.
  int? get typedUpTo => switch (parseAmount(upTo.text.trim(), currency)) {
    final a? when a > 0 => a,
    _ => null,
  };

  /// Something is in the cap's field that isn't an amount.
  bool get wrongUpTo => upTo.text.trim().isNotEmpty && typedUpTo == null;

  /// The one period's amount, when one is typed: 0 skips it.
  int? get typedOnce => switch (parseAmount(onceAmount.text.trim(), currency)) {
    final a? when a >= 0 => a,
    _ => null,
  };

  /// Something is in the one period's field that isn't an amount.
  bool get wrongOnce =>
      onceStart != null &&
      onceAmount.text.trim().isNotEmpty &&
      typedOnce == null;

  /// A date stays where it's typed, gone by or not (owner, 2026-11-02: "If
  /// I say 11/01 and it's in the past, I still want it there"). With no
  /// year it's this year's, unless that is more than nine months back, as
  /// on a row ([parseRowDate]): `01.05` typed on 12.28 is next week.
  DateTime? get typedDate => _readDate(date.text);

  DateTime? _readDate(String typed) {
    final text = typed.trim();
    if (text.isEmpty) return null;
    final d = parseEntryDate(text, today);
    // A year far off is a slip of the hand, not a date.
    if (d == null || d.year > today.year + 100) return null;
    final pieces = text.split(RegExp(r'[.\-/]')).where((p) => p.isNotEmpty);
    if (pieces.length > 2 || today.difference(d).inDays <= 274) return d;
    final next = DateTime(d.year + 1, d.month, d.day);
    // 02.29 has no other year to fall in.
    return next.day == d.day ? next : d;
  }

  static String monthDay(int m, int d) =>
      '${m.toString().padLeft(2, '0')}.${d.toString().padLeft(2, '0')}';

  /// The number typed after "Every"; null when it isn't one.
  int? get typedEveryN => switch (int.tryParse(everyN.text.trim())) {
    final n? when n > 0 && n < 1000 => n,
    _ => null,
  };

  /// Every so many months, when that's how it repeats.
  int? get everyMonthsNow {
    if (repeat != PlanRepeat.every) return null;
    final n = typedEveryN;
    return switch (unit) {
      PlanUnit.months => n,
      PlanUnit.years => n == null ? null : n * 12,
      _ => null,
    };
  }

  /// Every so many days, when that's how it repeats.
  int? get everyDaysNow {
    if (repeat != PlanRepeat.every) return null;
    final n = typedEveryN;
    return switch (unit) {
      PlanUnit.days => n,
      PlanUnit.weeks => n == null ? null : n * 7,
      _ => null,
    };
  }

  /// Custom… is on: its block shows, and its answers count.
  bool get customOn => repeat == PlanRepeat.every && custom;

  /// The weekdays picked, every so many weeks; null for the date's own.
  List<int>? get weekdaysNow =>
      customOn && unit == PlanUnit.weeks && weekdays.isNotEmpty
      ? ([...weekdays]..sort())
      : null;

  /// On the nth weekday of the month, every so many months or years.
  bool get nthNow =>
      customOn && (unit == PlanUnit.months || unit == PlanUnit.years) && nthOn;

  DateTime? get typedEndDate {
    final d = parseEntryDate(endDate.text.trim(), today);
    if (d == null || d.year > today.year + 100) return null;
    return d;
  }

  int? get typedEndCount => switch (int.tryParse(endCount.text.trim())) {
    final n? when n > 0 && n < 1000 => n,
    _ => null,
  };

  /// Ends applies to any repeat typed as every so many (a preset or
  /// Custom…), and to twice a month: "Every month, 12 times" is an
  /// installment plan (budget review, 2026-10-05).
  bool get endsOn => repeat == PlanRepeat.every || repeat == PlanRepeat.twice;
  DateTime? get endDateNow =>
      endsOn && ends == PlanEnds.date ? typedEndDate : null;
  int? get endCountNow =>
      endsOn && ends == PlanEnds.count ? typedEndCount : null;

  /// The dates typed for "On these dates", as (month, day); null when
  /// one of them isn't a date.
  List<(int, int)>? get typedDates {
    final pieces = dates.text
        .split(RegExp(r'[,;\s]+'))
        .where((x) => x.isNotEmpty)
        .toList();
    final out = <(int, int)>[];
    for (final piece in pieces) {
      final d = parseEntryDate(piece, today);
      if (d == null) return null;
      out.add((d.month, d.day));
    }
    return out;
  }

  /// The two days of "Twice a month", earlier first; null until both are
  /// days of a month, and not the same one.
  List<int>? get typedMonthDays {
    int? day(TextEditingController c) => switch (int.tryParse(c.text.trim())) {
      final n? when n >= 1 && n <= 31 => n,
      _ => null,
    };
    final (a, b) = (day(day1), day(day2));
    if (a == null || b == null || a == b) return null;
    return a < b ? [a, b] : [b, a];
  }

  /// The first of [days] this month: one gone by stays there, like a
  /// single date (#342). Past the month's end, its last day.
  DateTime firstOfMonthDays(List<int> days) {
    final end = DateTime(today.year, today.month + 1, 0).day;
    final d = days.first;
    return DateTime(today.year, today.month, d < end ? d : end);
  }

  /// The first of [days] from [from] on, today when not given.
  DateTime nextOfMonthDays(List<int> days, {DateTime? from}) {
    final f = from ?? today;
    for (var month = f.month; ; month++) {
      final end = DateTime(f.year, month + 1, 0).day;
      for (final d in days) {
        final on = DateTime(f.year, month, d < end ? d : end);
        if (!on.isBefore(f)) return on;
      }
    }
  }

  /// The day twice a month starts from, when one is asked and typed.
  DateTime? get typedStart => askStart ? _readDate(start.text) : null;

  /// Something is in twice a month's Starts that isn't a date.
  bool get wrongStart =>
      askStart && start.text.trim().isNotEmpty && typedStart == null;

  /// What Starts says beside it, for [draft] made from these answers
  /// (#356): the bills before today that will show as overdue, with their
  /// amount (warn, don't block), or the first bill when the start falls
  /// between the two days. Nothing for a first bill the plan [old]
  /// already had: those bills were seen to before.
  String? startNote(
    Words t,
    CategoryPlan? draft,
    String Function(int) say, {
    CategoryPlan? old,
  }) {
    final first = draft?.due;
    if (!askStart || repeat != PlanRepeat.twice || first == null) return null;
    if (old?.monthDays != null && old!.due == first) return null;
    var n = 0;
    DateTime? last;
    for (; n < 1000; n++) {
      final d = Budget.dueAfter(draft!, n);
      if (!d.isBefore(today)) break;
      last = d;
    }
    if (n > 0) {
      return t.planBillsBeforeToday(
        n,
        sayDate(t, first),
        sayDate(t, last!),
        say(draft!.amount * n),
      );
    }
    final s = typedStart;
    return s != null && s != first ? t.planFirstBill(sayDate(t, first)) : null;
  }

  /// The first of the typed dates from this month on: one gone by this
  /// month stays there, like a single date (#342).
  DateTime? firstOfDates(List<(int, int)> dates) {
    DateTime? first;
    for (final (m, d) in dates) {
      var on = DateTime(today.year, m, d);
      if (m < today.month) on = DateTime(today.year + 1, m, d);
      if (first == null || on.isBefore(first)) first = on;
    }
    return first;
  }

  int get daysAfterNow => switch (int.tryParse(daysAfter.text.trim())) {
    final n? when n > 0 && n < 100 => n,
    _ => 0,
  };

  /// What's missing, in the order the form asks for it: null when nothing
  /// is, or when no plan is wanted.
  PlanMissing? get missing {
    final k = kind;
    if (k == null) return null;
    if (typedAmount == null) return PlanMissing.amount;
    if (!hasDate) {
      return rollover && wrongUpTo
          ? PlanMissing.upTo
          : wrongOnce
          ? PlanMissing.once
          : null;
    }
    switch (repeat) {
      case PlanRepeat.payday:
        return payScheduleId == null ? PlanMissing.date : null;
      case PlanRepeat.dates:
        final d = typedDates;
        return d == null || d.isEmpty ? PlanMissing.dates : null;
      case PlanRepeat.twice:
        if (typedMonthDays == null) return PlanMissing.days;
        if (wrongStart) return PlanMissing.date;
        return _missingEnd;
      case PlanRepeat.every:
        if (typedEveryN == null) return PlanMissing.everyN;
        if (typedDate == null) return PlanMissing.date;
        return _missingEnd;
      case PlanRepeat.once:
        return typedDate == null ? PlanMissing.date : null;
    }
  }

  PlanMissing? get _missingEnd {
    if (ends == PlanEnds.date && typedEndDate == null) {
      return PlanMissing.endDate;
    }
    if (ends == PlanEnds.count && typedEndCount == null) {
      return PlanMissing.endCount;
    }
    return null;
  }

  /// Twice a month's first bill. A start typed, or changed from the one
  /// it had: the first of the days from it on (#356), so a bill made on
  /// 11.20 for 12.01 has nothing in November. Empty: this month, the
  /// first of the days, for a new one and for one whose first bill was
  /// still ahead. Left as it was, the same days keep their first bill;
  /// other days come from that bill or today, whichever is later, since
  /// this month's bills were the old days' (code review).
  DateTime _twiceDue(List<int> days, CategoryPlan? old) {
    final s = typedStart;
    final had = old?.monthDays == null ? null : old!.due;
    if (had == null) {
      return s == null ? firstOfMonthDays(days) : nextOfMonthDays(days, from: s);
    }
    final ahead = had.isAfter(today);
    // Emptied while its first bill was still ahead: this month. One that
    // has gone by keeps it, its bills since seen to.
    if (askStart && s == null && ahead) return firstOfMonthDays(days);
    if (s != null && s != had) return nextOfMonthDays(days, from: s);
    if (old!.monthDays!.join(',') == days.join(',')) return had;
    return nextOfMonthDays(days, from: ahead ? had : today);
  }

  /// The plan as typed, for [categoryId], its bill paid from [paidFrom].
  /// Null with a kind picked means something is missing. [old], the plan
  /// the category has: one that's really the same keeps its day.
  CategoryPlan? draft({
    required int categoryId,
    int? paidFrom,
    CategoryPlan? old,
    bool keepOnceStart = false,
  }) {
    final k = kind;
    if (k == null || missing != null) return null;
    final amount = typedAmount!;
    final carry = k != PlanKind.each || rollover;
    final cap = k == PlanKind.each && carry ? typedUpTo : null;
    // How it comes again, and from when.
    DateTime? due;
    List<(int, int)>? onDates;
    List<int>? monthDays;
    int? payId;
    if (hasDate) {
      switch (repeat) {
        case PlanRepeat.payday:
          payId = payScheduleId;
        case PlanRepeat.dates:
          onDates = typedDates;
          due = firstOfDates(onDates!);
        case PlanRepeat.twice:
          monthDays = typedMonthDays;
          due = _twiceDue(monthDays!, old);
        case PlanRepeat.every:
        case PlanRepeat.once:
          due = typedDate;
      }
    }
    CategoryPlan make(DateTime start) => CategoryPlan(
      categoryId: categoryId,
      kind: k,
      amount: amount,
      start: start,
      due: due,
      everyMonths: hasDate ? everyMonthsNow : null,
      everyDays: hasDate ? everyDaysNow : null,
      onDates: onDates,
      monthDays: monthDays,
      payScheduleId: hasDate ? payId : eachPayId,
      daysAfterPay: payId == null ? 0 : daysAfterNow,
      // Chosen weekdays are the days; a weekend rule would move a
      // Saturday onto Friday's bill (code review).
      weekend:
          hasDate &&
              repeat != PlanRepeat.once &&
              payId == null &&
              weekdaysNow == null
          ? weekend
          : PayWeekend.keep,
      weekdays: hasDate ? weekdaysNow : null,
      nth: hasDate && nthNow ? nth : null,
      nthWeekday: hasDate && nthNow ? nthWeekday : null,
      endDate: hasDate ? endDateNow : null,
      endCount: hasDate ? endCountNow : null,
      rollover: carry,
      spentEach: k != PlanKind.each || spentEach,
      upTo: cap,
      paidFrom: paidFrom,
      once: k == PlanKind.each ? _once(old) : const {},
    );
    final fresh = make(today);
    // A dated plan's parts count from the day it was made, and a category
    // that doesn't carry over is emptied from that day on: only a plan
    // that's really the same keeps its day. One that already didn't
    // carry over keeps it through a new amount; a cap or the account a
    // bill is paid from changes nothing about the count.
    final same =
        old != null &&
        old.kind == k &&
        (k == PlanKind.each
            ? old.rollover == carry &&
                  old.payScheduleId == eachPayId &&
                  (!carry || old.amount == amount)
            : old.amount == amount && old.sameRepeat(fresh));
    // An amount by one date that stays one ([keepOnceStart], a goal)
    // keeps its day through a new amount or date.
    final once =
        keepOnceStart &&
        old != null &&
        old.kind == PlanKind.byDate &&
        !old.repeats &&
        k == PlanKind.byDate &&
        !fresh.repeats;
    return same || once ? make(old.start) : fresh;
  }

  /// The set amount's single periods: those [old] had, while its periods
  /// are still the same ones, with the one on screen as typed.
  Map<DateTime, int> _once(CategoryPlan? old) {
    final start = onceStart;
    final typed = typedOnce;
    return {
      if (old != null &&
          old.kind == PlanKind.each &&
          old.payScheduleId == eachPayId)
        for (final e in old.once.entries)
          if (e.key != start) e.key: e.value,
      if (start != null && typed != null) start: typed,
    };
  }
}

/// The answer a form asks for again when Add or Save finds it missing.
enum PlanMissing {
  amount,
  upTo,
  once,
  date,
  dates,
  days,
  everyN,
  endDate,
  endCount,
}

// ---------- the words both forms use ----------

/// Stand-ins for the boxes in a sentence like "On the [25]": the words
/// around a box come from one message, so each language puts them in its
/// own order.
const fieldMarks = ['\uE000', '\uE001'];

/// [text] as a row of words and [fields], each field where its mark is.
List<Widget> withFields(String text, List<Widget> fields) {
  final out = <Widget>[];
  var rest = text;
  while (rest.isNotEmpty) {
    var at = -1, which = -1;
    for (var i = 0; i < fields.length; i++) {
      final j = rest.indexOf(fieldMarks[i]);
      if (j >= 0 && (at < 0 || j < at)) (at, which) = (j, i);
    }
    if (at < 0) {
      out.add(Text(rest, style: onest(13.5)));
      break;
    }
    if (at > 0) out.add(Text(rest.substring(0, at), style: onest(13.5)));
    out.add(fields[which]);
    rest = rest.substring(at + 1);
  }
  return out;
}

String planEveryLabel(Words t, int n, PlanUnit unit) => switch (unit) {
  PlanUnit.days => t.planRepeatDays(n),
  PlanUnit.weeks => t.planRepeatWeeks(n),
  PlanUnit.months => t.planRepeatMonths(n),
  PlanUnit.years => t.planRepeatYears(n),
};

String planUnitLabel(Words t, PlanUnit unit) => switch (unit) {
  PlanUnit.days => t.planUnitDays,
  PlanUnit.weeks => t.planUnitWeeks,
  PlanUnit.months => t.planUnitMonths,
  PlanUnit.years => t.planUnitYears,
};

String planWeekendLabel(Words t, PayWeekend w) => switch (w) {
  PayWeekend.keep => t.planWeekendKeep,
  PayWeekend.before => t.planWeekendBefore,
  PayWeekend.after => t.planWeekendAfter,
};

/// "first" … "fourth", or "last" (-1).
String planNthLabel(Words t, int n) => switch (n) {
  1 => t.planNthFirst,
  2 => t.planNthSecond,
  3 => t.planNthThird,
  4 => t.planNthFourth,
  _ => t.planNthLast,
};

/// Monday (1) … Sunday (7), in full.
String planWeekdayName(Words t, int wd) =>
    t.planWeekdayNames.split('|')[wd - 1];

/// "Every payday", or which pay when there's more than one.
String planPaydayLabel(Words t, LedgerData data, PaySchedule s) {
  if (data.paySchedules.length < 2) return t.planEveryPayday;
  return t.planEveryPaydayOf(payTitle(t, data, s));
}

/// "Every pay period", or with more than one pay, "Every pay period ·
/// Jenny".
String planEachPayLabel(Words t, LedgerData data, PaySchedule s) {
  if (data.paySchedules.length < 2) return t.planEveryPayPeriod;
  return t.planEveryPayPeriodOf(payTitle(t, data, s));
}

/// What the How often button says.
String planRepeatLabel(Words t, LedgerData data, PlanAnswers a) =>
    switch (a.repeat) {
      PlanRepeat.once => t.planOnce,
      // Custom… open: the block under it says the pattern.
      PlanRepeat.every when a.custom => t.planCustomOn,
      PlanRepeat.every => planEveryLabel(t, a.typedEveryN ?? 1, a.unit),
      PlanRepeat.twice => t.planTwiceAMonth,
      PlanRepeat.dates => t.planDatesAYear(a.typedDates?.length ?? 0),
      PlanRepeat.payday => switch (data.payScheduleById(a.payScheduleId)) {
        final s? => planPaydayLabel(t, data, s),
        null => t.planEveryPayday,
      },
    };

/// The accounts in [currency] a category can use: cash, bank and credit
/// cards (owner, 2026-10-02: a bill planned for the Visa is the Visa's). Not
/// a mortgage or student loan. [Budget.spendable], not [Budget.counts]: the
/// latter is only where money sits, and a card holds none.
Iterable<AccountInfo> categoryAccounts(LedgerData data, Currency currency) =>
    data.openAccounts.where((a) => Budget.spendable(a, currency));

/// The pay a set amount is per, by name, when there's more than one pay to
/// tell it from; null for a monthly one, or the only pay.
String? ownPayName(Words t, LedgerData data, CategoryPlan plan) {
  if (plan.kind != PlanKind.each || plan.payScheduleId == null) return null;
  if (data.paySchedules.length < 2) return null;
  final pay = data.payScheduleById(plan.payScheduleId);
  return pay == null ? null : payTitle(t, data, pay);
}

/// What a plan says under its category's name: the plan, then whether a
/// dated one has what it should ("on track", or "₮200,000 short" in
/// full ink), or that this period's bill was paid ("paid 10.15").
typedef PlanNote = ({String text, String? state, bool behind});

PlanNote planNote(
  Words t,
  EnvelopeLine line,
  BudgetSpan period,
  DateTime today,
  Currency currency, {
  String? payName,
  PaySchedule? own,
}) {
  final p = line.plan!;
  // The period on screen, and a set amount's own (its month or its pay,
  // named when there's more than one pay to tell apart).
  final byPay = period.label == payPeriodLabel;
  final ownPay = p.plan.kind == PlanKind.each
      ? p.plan.payScheduleId != null
      : byPay;
  String money(int v) => formatShort(v, currency: currency);
  // In the last period before a date, the part is the rest: "this month".
  String each(int v) => p.lastPeriod
      ? (byPay ? t.planThisPay(money(v)) : t.planThisMonth(money(v)))
      : !ownPay
      ? t.planEachMonth(money(v))
      : payName != null
      ? t.planEachPayOf(money(v), payName)
      : t.planEachPay(money(v));
  // This year's dates need no year; a date in 2028 does.
  String date(DateTime d) =>
      d.year == today.year ? sayDate(t, d) : sayFullDate(t, d);
  final due = p.due ?? p.plan.due ?? p.plan.start;
  final once = p.plan.kind == PlanKind.byDate && !p.plan.repeats;
  // What went back is said once the period it went back in has begun;
  // looking ahead, it hasn't happened yet.
  final wentBack = p.wentBack > 0 && !period.start.isAfter(today);
  // A dated plan names its part only while it wants one.
  final wants = p.each > 0 && p.planned > 0 && !(once && p.done);
  final cap = p.plan.rollover ? p.plan.upTo : null;
  // A period given its own amount (#100): said with what comes after it.
  // Its own period's words: a monthly one seen by a pay names its month.
  String onceLine() {
    final usual = money(p.plan.amount);
    final month = monthName(t, (p.onceFrom ?? period.start).month);
    if (p.each == 0) {
      return ownPay
          ? t.planSkippedPay(usual)
          : t.planSkippedMonth(month, usual);
    }
    return ownPay
        ? t.planOncePayLine(money(p.each), usual)
        : t.planOnceMonthLine(money(p.each), month, usual);
  }

  final parts = switch (p.plan.kind) {
    PlanKind.each => [
      // Holding its cap, the line says so in place of the amount.
      if (cap != null && p.done)
        t.planSetAsideAmount(money(cap))
      else if (p.once)
        onceLine()
      else
        each(p.each),
      // Seen by another period than its own: its share of this one, by
      // days, said as about. More than one period's worth (the one before
      // was never filled, and the rest of it is in view) is said as what
      // that period still needs, plus what's toward the next (owner,
      // 2026-10-05: "₮600,000 each … · about ₮700,000 this …" read as a
      // contradiction).
      if (p.shares.length > 1 &&
          p.planned > p.each &&
          p.shares.first.amount > 0 &&
          own != null &&
          !(cap != null && p.done))
        ...() {
          final first = p.shares.first;
          final period = budgetPeriod(first.date, own);
          final rest = p.planned - first.amount;
          return [
            t.planStillFor(
              money(first.amount),
              date(period.start),
              date(period.end),
            ),
            if (rest > 0) t.planPlusNext(money(rest)),
          ];
        }()
      else if (p.approx && p.planned > 0 && !(cap != null && p.done))
        byPay
            ? t.planAboutThisPay(money(p.planned))
            : t.planAboutThisMonth(money(p.planned)),
      if (cap != null && !p.done) t.planUpTo(money(cap)),
      // Seen by its own period, "last month"; by another, the day.
      if (wentBack)
        ownPay != byPay && p.wentBackOn != null
            ? t.planWentBackOn(money(p.wentBack), date(p.wentBackOn!))
            : ownPay
            ? t.planWentBackPay(money(p.wentBack))
            : t.planWentBack(money(p.wentBack))
      else if (!p.plan.rollover)
        t.planNoCarry,
    ],
    PlanKind.byDate => [
      if (p.ended)
        t.planEnded(money(p.plan.amount), date(due))
      else if (!once)
        t.planDue(money(p.plan.amount), date(due))
      else if ((p.done || p.late) && due.isBefore(period.start))
        t.planWasDue(money(p.plan.amount), date(due))
      else
        t.planBy(money(p.plan.amount), date(due)),
      // Its last period says all it has to find, a bill before this one's
      // pay included.
      if (wants) each(p.lastPeriod ? p.planned : p.each),
    ],
  };
  final String? state;
  if (line.short > 0) {
    state = t.planShort(money(line.short));
  } else if (line.paidOn case final paid? when p.plan.kind == PlanKind.byDate) {
    // This period's bill was paid: the one thing a person asks of a bill's
    // row (#274). Short still comes first: it's about the next one.
    state = t.planPaidOn(date(paid));
  } else if (p.finished) {
    state = null;
  } else if (once && p.done) {
    state = t.planSetAsideState;
  } else if (p.plan.kind == PlanKind.each ||
      p.waiting ||
      p.done ||
      p.late ||
      // A month whose bill won't come asks nothing: nothing to be on track
      // with (#357).
      (p.noBills.isNotEmpty && p.planned == 0)) {
    state = null;
  } else if (line.toAssign == 0) {
    state = t.planOnTrack;
  } else {
    state = null;
  }
  return (text: parts.join(' · '), state: state, behind: line.short > 0);
}
