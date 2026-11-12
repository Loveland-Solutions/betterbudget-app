import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// On a Mac the window's own title bar is only the thin strip beside the
/// three buttons, the same colour as the page, so the page's top row (the
/// logo, an account's name) reads as the top bar too. There a double-click
/// does what the Mac is set to do with one on a title bar (System Settings →
/// Desktop & Dock: fill, zoom or minimize; a second puts it back), and a
/// drag moves the window (#428). Anything in that row that can be clicked
/// keeps its click: the band is only where nothing else answers.
///
/// It listens rather than joining the gesture arena, so no button anywhere
/// waits to see whether a click becomes a double-click. It sits inside
/// `FitWindow`, so the band is the page's own top 64 points at any scale,
/// and only the page answers: the screen itself is wrapped in [page], so a
/// dialog or menu laid over the top of the window keeps every click.
class WindowTitleArea extends StatefulWidget {
  const WindowTitleArea({super.key, required this.child, this.enabled});

  final Widget child;

  /// Null: on a Mac only.
  final bool? enabled;

  /// How far down the window the band reaches: the page's title row and
  /// the logo's, above the first card.
  static const height = 64.0;

  static const channel = MethodChannel('betterbudget/window');

  /// Marks the app's screen, under any dialog or menu: the band is only
  /// where a click reaches it.
  static Widget page({required Widget child}) =>
      MetaData(metaData: _pageMark, child: child);

  static const _pageMark = #windowTitleAreaPage;

  @override
  State<WindowTitleArea> createState() => _WindowTitleAreaState();
}

class _WindowTitleAreaState extends State<WindowTitleArea> {
  /// The Mac's own double-click speed (System Settings → Mouse), asked
  /// once; until it answers, the Mac's default.
  Duration _interval = const Duration(milliseconds: 500);

  /// The last press in the band, for the second of a double-click.
  Duration? _lastAt;
  Offset? _lastPos;

  /// A press in the band that hasn't moved far enough to be a drag yet.
  int? _pressed;
  Offset? _pressedAt;

  bool get _on =>
      widget.enabled ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void initState() {
    super.initState();
    if (_on) {
      WindowTitleArea.channel
          .invokeMethod<num>('doubleClickInterval')
          .then((s) {
            if (s != null && s > 0 && mounted) {
              _interval = Duration(microseconds: (s * 1e6).round());
            }
          })
          .catchError((Object _) {});
    }
  }

  /// The click lands on the screen itself and nothing there answers it: no
  /// button, link or field (anything that shows its own pointer), and no
  /// dialog or menu over it.
  bool _bare(PointerEvent e) {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, e.position, e.viewId);
    var onPage = false;
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMetaData &&
          target.metaData == WindowTitleArea._pageMark) {
        onPage = true;
      }
      if (target is RenderEditable) return false;
      // Material's buttons keep the arrow off the web; they say they're
      // buttons to the screen reader instead.
      if (target is RenderSemanticsGestureHandler &&
          (target.onTap != null || target.onLongPress != null)) {
        return false;
      }
      if (target is RenderSemanticsAnnotations) {
        final p = target.properties;
        if (p.button == true ||
            p.link == true ||
            p.textField == true ||
            p.onTap != null) {
          return false;
        }
      }
      if (target is RenderMouseRegion &&
          target.cursor != MouseCursor.defer &&
          target.cursor != SystemMouseCursors.basic) {
        return false;
      }
    }
    return onPage;
  }

  void _send(String method) =>
      WindowTitleArea.channel.invokeMethod<void>(method).catchError((_) {});

  void _down(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.mouse ||
        e.buttons != kPrimaryMouseButton ||
        e.localPosition.dy >= WindowTitleArea.height ||
        !_bare(e)) {
      _lastAt = null;
      return;
    }
    final last = _lastAt, lastPos = _lastPos;
    if (last != null &&
        lastPos != null &&
        e.timeStamp - last <= _interval &&
        (e.position - lastPos).distance <= kDoubleTapSlop) {
      _lastAt = null;
      _pressed = null;
      _send('titleDoubleClick');
      return;
    }
    _lastAt = e.timeStamp;
    _lastPos = e.position;
    _pressed = e.pointer;
    _pressedAt = e.position;
  }

  void _move(PointerMoveEvent e) {
    final at = _pressedAt;
    if (e.pointer != _pressed || at == null) return;
    if ((e.position - at).distance < kPrecisePointerPanSlop) return;
    _pressed = null;
    _lastAt = null;
    _send('startDrag');
  }

  void _up(PointerEvent e) {
    if (e.pointer == _pressed) _pressed = null;
  }

  @override
  Widget build(BuildContext context) => !_on
      ? widget.child
      : Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _up,
          child: widget.child,
        );
}
