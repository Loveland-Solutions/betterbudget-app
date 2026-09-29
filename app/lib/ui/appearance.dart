import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

/// Light, dark, or whatever the computer is set to (Settings → Appearance).
enum Appearance { system, light, dark }

/// The appearance chosen on this computer. It lives in a small file beside
/// the ledger, not in it: a phone opening the same ledger keeps its own.
class AppearanceController extends ChangeNotifier {
  AppearanceController({Appearance initial = Appearance.system, this.file})
    : _value = initial;

  /// Where the choice is kept; null keeps it for this session only (tests).
  final File? file;
  Appearance _value;
  Appearance get value => _value;

  static Future<AppearanceController> load(File file) async {
    var initial = Appearance.system;
    try {
      final saved = (await file.readAsString()).trim();
      initial = Appearance.values.firstWhere(
        (a) => a.name == saved,
        orElse: () => Appearance.system,
      );
    } on FileSystemException {
      // Never chosen: follow the system.
    }
    return AppearanceController(initial: initial, file: file);
  }

  Future<void> _writing = Future.value();

  Future<void> set(Appearance a) {
    if (a == _value) return _writing;
    _value = a;
    notifyListeners();
    // One write at a time, so quick clicks can't finish out of order.
    return _writing = _writing.then((_) async {
      try {
        await file?.writeAsString(a.name);
      } on FileSystemException {
        // Still applied for this session; it just won't be remembered.
      }
    });
  }
}

/// Puts the chosen palette in [Mid] and redraws everything when the choice,
/// or the computer's own setting under "System", changes.
class AppearanceScope extends StatefulWidget {
  const AppearanceScope({
    super.key,
    required this.controller,
    required this.child,
  });
  final AppearanceController controller;
  final Widget child;

  static AppearanceController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_AppearanceInherited>()
      ?.controller;

  /// The palette an appearance shows right now.
  static Palette resolve(Appearance a) => switch (a) {
    Appearance.light => Palette.light,
    Appearance.dark => Palette.dark,
    Appearance.system =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.light
          ? Palette.light
          : Palette.dark,
  };

  @override
  State<AppearanceScope> createState() => _AppearanceScopeState();
}

class _AppearanceScopeState extends State<AppearanceScope>
    with WidgetsBindingObserver {
  static const _window = MethodChannel('betterbudget/window');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_apply);
    Mid.palette = AppearanceScope.resolve(widget.controller.value);
    _tellWindow();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_apply);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _apply();

  void _apply() {
    final p = AppearanceScope.resolve(widget.controller.value);
    if (!mounted) return;
    setState(() {});
    if (identical(p, Mid.palette)) return;
    Mid.palette = p;
    _tellWindow();
    // Colors are read from [Mid] directly, not through an inherited widget,
    // so nothing below knows they changed: rebuild all of it, keeping state.
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  /// The macOS title bar sits above Flutter; it takes the page's ground.
  Future<void> _tellWindow() async {
    try {
      await _window.invokeMethod('setLook', {
        'dark': !Mid.isLight,
        'ground': Mid.ground.toARGB32(),
      });
    } on MissingPluginException {
      // Tests, and platforms without the channel.
    } on PlatformException {
      // The window keeps its last look.
    }
  }

  @override
  Widget build(BuildContext context) => _AppearanceInherited(
    controller: widget.controller,
    value: widget.controller.value,
    child: widget.child,
  );
}

class _AppearanceInherited extends InheritedWidget {
  const _AppearanceInherited({
    required this.controller,
    required this.value,
    required super.child,
  });
  final AppearanceController controller;
  final Appearance value;

  @override
  bool updateShouldNotify(_AppearanceInherited old) => old.value != value;
}
