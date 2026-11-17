// A section's name over its rows stays at the top of the list while they
// scroll, and leaves with the section's last row (#482, #489).
import 'package:betterbudget/ui/headed_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the name is over the rows, both full width; it stays at the '
      'top of the list within its section, and the next section pushes it '
      'away', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    Widget section(String name, double height) => HeadedSection(
      key: ValueKey(name),
      scroll: scroll,
      name: SizedBox(height: 40, child: Text(name, key: ValueKey('n-$name'))),
      body: SizedBox(key: ValueKey('b-$name'), height: height),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 600,
            height: 300,
            child: ListView(
              controller: scroll,
              children: [
                Column(
                  children: [
                    section('Day-to-day', 400),
                    const SizedBox(height: 33),
                    section('Bills', 400),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    RenderHeadedSection of(String name) =>
        tester.renderObject<RenderHeadedSection>(find.byKey(ValueKey(name)));
    // The name above, the rows under it, each the section's whole width.
    expect(
      tester.getSize(find.byKey(const ValueKey('Day-to-day'))),
      const Size(600, 440),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('b-Day-to-day'))).width,
      600,
    );
    final top = tester.getTopLeft(find.byKey(const ValueKey('Day-to-day')));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('b-Day-to-day'))),
      top + const Offset(0, 40),
    );
    expect(of('Day-to-day').nameShift, 0);
    expect(of('Bills').nameShift, 0);

    // Scrolled into the first section: its name has come down as far,
    // and is drawn at the top of the list.
    scroll.jumpTo(150);
    await tester.pump();
    expect(of('Day-to-day').nameShift, 150);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('n-Day-to-day'))).dy,
      top.dy,
    );
    expect(of('Bills').nameShift, 0);

    // Its last row leaving: the name stops at the section's end and goes
    // with it, so two are never stuck at once.
    scroll.jumpTo(430);
    await tester.pump();
    expect(of('Day-to-day').nameShift, 400);
    expect(of('Bills').nameShift, 0);

    // Into the second: its name is the one at the top.
    scroll.jumpTo(550);
    await tester.pump();
    expect(of('Bills').nameShift, 550 - 473);

    // Back at the top, both are where they began.
    scroll.jumpTo(0);
    await tester.pump();
    expect(of('Day-to-day').nameShift, 0);
  });

  testWidgets('a click on the name stuck at the top reaches the name, not '
      'the row under it', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    var name = 0, row = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 500,
            height: 200,
            child: ListView(
              controller: scroll,
              children: [
                HeadedSection(
                  scroll: scroll,
                  name: GestureDetector(
                    onTap: () => name++,
                    child: const ColoredBox(
                      color: Colors.white,
                      child: SizedBox(height: 40, width: double.infinity),
                    ),
                  ),
                  body: GestureDetector(
                    onTap: () => row++,
                    child: const ColoredBox(
                      color: Colors.black,
                      child: SizedBox(height: 600, width: double.infinity),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    scroll.jumpTo(200);
    await tester.pump();
    await tester.tapAt(const Offset(250, 20));
    expect((name, row), (1, 0));
    await tester.tapAt(const Offset(250, 100));
    expect((name, row), (1, 1));
  });
}
