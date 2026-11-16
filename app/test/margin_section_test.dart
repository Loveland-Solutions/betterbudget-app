// A section's name in the margin stays at the top of the list while its
// rows scroll, and leaves with the section's last row (#482).
import 'package:betterbudget/ui/margin_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the name stays at the top of the list within its section, '
      'and the next section pushes it away', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    Widget section(String name, double height) => MarginSection(
      key: ValueKey(name),
      margin: 148,
      scroll: scroll,
      name: SizedBox(height: 40, child: Text(name)),
      body: SizedBox(height: height),
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
    RenderMarginSection of(String name) =>
        tester.renderObject<RenderMarginSection>(find.byKey(ValueKey(name)));
    // The body has the width the margin leaves.
    expect(
      tester.getSize(find.byKey(const ValueKey('Day-to-day'))),
      const Size(600, 400),
    );
    expect(of('Day-to-day').nameShift, 0);
    expect(of('Bills').nameShift, 0);

    // Scrolled into the first section: its name has come down as far.
    scroll.jumpTo(150);
    await tester.pump();
    expect(of('Day-to-day').nameShift, 150);
    expect(of('Bills').nameShift, 0);

    // Its last row leaving: the name stops at the section's end and goes
    // with it, so two are never stuck at once.
    scroll.jumpTo(390);
    await tester.pump();
    expect(of('Day-to-day').nameShift, 360);
    expect(of('Bills').nameShift, 0);

    // Into the second: its name is the one at the top.
    scroll.jumpTo(500);
    await tester.pump();
    expect(of('Bills').nameShift, 500 - 433);

    // Back at the top, both are where they began.
    scroll.jumpTo(0);
    await tester.pump();
    expect(of('Day-to-day').nameShift, 0);
  });

  testWidgets('a name taller than its rows makes the section as tall', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 500,
            child: MarginSection(
              margin: 148,
              scroll: scroll,
              name: const SizedBox(height: 60),
              body: const SizedBox(height: 40),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(MarginSection)), const Size(500, 60));
  });
}
