import 'dart:io';

import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart' show Words, lookupWords;

/// English, Mongolian, or whatever the computer is set to (Settings →
/// Language).
enum Language { system, english, mongolian }

/// The languages the app has words for; any other system language gets
/// English.
const supportedLocales = [Locale('en'), Locale('mn')];

/// The language chosen on this computer. Like the appearance, it lives in a
/// small file beside the ledger, not in it.
class LanguageController extends ChangeNotifier {
  LanguageController({Language initial = Language.system, this.file})
    : _value = initial;

  /// Where the choice is kept; null keeps it for this session only (tests).
  final File? file;
  Language _value;
  Language get value => _value;

  static Future<LanguageController> load(File file) async {
    var initial = Language.system;
    try {
      final saved = (await file.readAsString()).trim();
      initial = Language.values.firstWhere(
        (l) => l.name == saved,
        orElse: () => Language.system,
      );
    } on FileSystemException {
      // Never chosen: follow the system.
    }
    return LanguageController(initial: initial, file: file);
  }

  Future<void> _writing = Future.value();

  Future<void> set(Language l) {
    if (l == _value) return _writing;
    _value = l;
    notifyListeners();
    // One write at a time, so quick clicks can't finish out of order.
    return _writing = _writing.then((_) async {
      try {
        await file?.writeAsString(l.name);
      } on FileSystemException {
        // Still applied for this session; it just won't be remembered.
      }
    });
  }

  /// The locale to hand the app; null follows the system.
  Locale? get locale => switch (_value) {
    Language.system => null,
    Language.english => const Locale('en'),
    Language.mongolian => const Locale('mn'),
  };
}

/// Mongolian if it's anywhere in the computer's preferred languages ahead of
/// English, otherwise English.
Locale resolveLocale(List<Locale>? preferred) {
  for (final l in preferred ?? const <Locale>[]) {
    if (l.languageCode == 'mn') return const Locale('mn');
    if (l.languageCode == 'en') return const Locale('en');
  }
  return const Locale('en');
}

/// Hands [LanguageController] down and redraws when the choice changes.
class LanguageScope extends StatelessWidget {
  const LanguageScope({
    super.key,
    required this.controller,
    required this.child,
  });
  final LanguageController controller;
  final Widget child;

  static LanguageController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_LanguageInherited>()
      ?.controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => _LanguageInherited(
      controller: controller,
      value: controller.value,
      child: child,
    ),
  );
}

class _LanguageInherited extends InheritedWidget {
  const _LanguageInherited({
    required this.controller,
    required this.value,
    required super.child,
  });
  final LanguageController controller;
  final Language value;

  @override
  bool updateShouldNotify(_LanguageInherited old) => old.value != value;
}

final _english = lookupWords(const Locale('en'));

extension WordsOf on BuildContext {
  /// The words in the chosen language. English where no app set up the
  /// translations (widget tests that build a bare MaterialApp).
  Words get t => Localizations.of<Words>(this, Words) ?? _english;
}

String _two(int v) => v.toString().padLeft(2, '0');

/// A date inside a sentence or list, year left out: `09.16`, `9-р сарын 16`.
/// Rows and the chart keep [shortDate] in both languages.
String sayDate(Words t, DateTime d) =>
    t.dayMonth(_two(d.month), _two(d.day), d.month, d.day);

/// A full date inside a sentence or list: `2026.09.16`,
/// `2026 оны 9-р сарын 16`. Rows keep [fullDate].
String sayFullDate(Words t, DateTime d) =>
    t.dayMonthYear('${d.year}', _two(d.month), _two(d.day), d.month, d.day);

/// The name of month [m] (1–12).
String monthName(Words t, int m) => t.monthNames.split('|')[m - 1];
