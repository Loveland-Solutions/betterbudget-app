import 'package:betterbudget/ui/window_title_area.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// #428: the page's top row on a Mac answers a double-click and a drag as the
// window's title bar does, except where something there is clickable.
void main() {
  late List<String> calls;
  late int buttonTaps;

  // The app reads the time off each event, so the clicks carry one.
  var clock = Duration.zero;
  var pointer = 0;

  // What the Mac says its double-click speed is, in seconds.
  var speed = 0.5;

  setUp(() {
    speed = 0.5;
    calls = [];
    buttonTaps = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WindowTitleArea.channel, (call) async {
          calls.add(call.method);
          return call.method == 'doubleClickInterval' ? speed : null;
        });
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      builder: (context, child) =>
          WindowTitleArea(enabled: true, child: child!),
      home: WindowTitleArea.page(
        child: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: WindowTitleArea.height,
                child: Row(
                  children: [
                    const Text('TDB MNT'),
                    TextButton(
                      key: const ValueKey('more'),
                      onPressed: () => buttonTaps++,
                      child: const Text('···'),
                    ),
                    Builder(
                      builder: (context) => TextButton(
                        key: const ValueKey('open-dialog'),
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => const Align(
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: 300,
                              height: 200,
                              child: Material(child: Text('A window')),
                            ),
                          ),
                        ),
                        child: const Text('Open'),
                      ),
                    ),
                  ],
                ),
              ),
              const Expanded(child: SizedBox.expand()),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> click(WidgetTester tester, Offset at) async {
    final mouse = TestPointer(++pointer, PointerDeviceKind.mouse);
    clock += const Duration(milliseconds: 100);
    await tester.sendEventToBinding(mouse.down(at, timeStamp: clock));
    clock += const Duration(milliseconds: 20);
    await tester.sendEventToBinding(mouse.up(timeStamp: clock));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('a double-click on the empty top row is the title bar\'s', (
    tester,
  ) async {
    await pump(tester);
    calls.clear();
    const empty = Offset(600, 20);
    await click(tester, empty);
    expect(calls, isEmpty, reason: 'one click does nothing');
    await click(tester, empty);
    expect(calls, ['titleDoubleClick']);
    // A third click starts over rather than counting as another double.
    await click(tester, empty);
    expect(calls, ['titleDoubleClick']);
  });

  testWidgets('on the account name too', (tester) async {
    await pump(tester);
    calls.clear();
    final name = tester.getCenter(find.text('TDB MNT'));
    await click(tester, name);
    await click(tester, name);
    expect(calls, ['titleDoubleClick']);
  });

  testWidgets('two clicks too far apart in time are two clicks', (
    tester,
  ) async {
    await pump(tester);
    calls.clear();
    await click(tester, const Offset(600, 20));
    clock += const Duration(milliseconds: 600);
    await click(tester, const Offset(600, 20));
    expect(calls, isEmpty);
  });

  testWidgets('a button in the top row keeps its clicks', (tester) async {
    await pump(tester);
    calls.clear();
    final more = tester.getCenter(find.byKey(const ValueKey('more')));
    await click(tester, more);
    await click(tester, more);
    expect(calls, isEmpty);
    expect(buttonTaps, 2);
  });

  testWidgets('below the top row nothing happens', (tester) async {
    await pump(tester);
    calls.clear();
    const below = Offset(600, WindowTitleArea.height + 40);
    await click(tester, below);
    await click(tester, below);
    final g = await tester.startGesture(below, kind: PointerDeviceKind.mouse);
    await g.moveBy(const Offset(80, 30));
    await g.up();
    expect(calls, isEmpty);
  });

  testWidgets('a drag from the empty top row moves the window, once', (
    tester,
  ) async {
    await pump(tester);
    calls.clear();
    final g = await tester.startGesture(
      const Offset(600, 20),
      kind: PointerDeviceKind.mouse,
    );
    await g.moveBy(const Offset(1, 0));
    expect(calls, isEmpty, reason: 'a nudge is still a click');
    await g.moveBy(const Offset(40, 20));
    await g.moveBy(const Offset(40, 20));
    await g.up();
    expect(calls, ['startDrag']);
  });

  testWidgets('the Mac\'s own double-click speed is the one counted', (
    tester,
  ) async {
    speed = 0.1;
    await pump(tester);
    calls.clear();
    // 120 ms apart: a double-click at the Mac's default, two clicks at 0.1 s.
    await click(tester, const Offset(600, 20));
    await click(tester, const Offset(600, 20));
    expect(calls, isEmpty);
  });

  testWidgets('a dialog over the top row keeps every click', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('open-dialog')));
    await tester.pumpAndSettle();
    calls.clear();
    // Plain words in the dialog, and the dimmed page beside it.
    final words = tester.getTopLeft(find.text('A window')) + const Offset(4, 4);
    await click(tester, words);
    await click(tester, words);
    await click(tester, const Offset(40, 20));
    await click(tester, const Offset(40, 20));
    expect(calls, isEmpty);
  });

  testWidgets('a page not marked as the screen is not a title bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      const WindowTitleArea(enabled: true, child: SizedBox.expand()),
    );
    calls.clear();
    await click(tester, const Offset(600, 20));
    await click(tester, const Offset(600, 20));
    expect(calls, isEmpty);
  });

  testWidgets('off a Mac it does nothing', (tester) async {
    await tester.pumpWidget(const WindowTitleArea(child: SizedBox.expand()));
    calls.clear();
    await click(tester, const Offset(600, 20));
    await click(tester, const Offset(600, 20));
    expect(calls, isEmpty);
  });
}
