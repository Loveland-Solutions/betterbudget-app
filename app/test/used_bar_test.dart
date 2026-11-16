import 'package:betterbudget/ui/theme.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Budget page's bar and the phone's ring (#465): three colors and no
/// shade between, the colored part what's left.
void main() {
  testWidgets('the bar and the ring: green untouched, gold as it is spent, '
      'bare at zero, whole and coral when over', (tester) async {
    tester.view.physicalSize = const Size(600, 560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    const states = <({double left, bool over})>[
      (left: 1, over: false),
      (left: 0.7, over: false),
      (left: 0.35, over: false),
      (left: 0.02, over: false),
      (left: 0, over: false),
      (left: 0, over: true),
    ];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: Mid.panel,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in states)
                  SizedBox(
                    height: 40,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 180,
                          child: UsedBar(left: s.left, over: s.over),
                        ),
                        const SizedBox(width: 32),
                        UsedRing(left: s.left, over: s.over, size: 16),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(usedColor(left: 1, over: false), Mid.green);
    expect(usedColor(left: 0.7, over: false), Mid.gold);
    expect(usedColor(left: 0, over: false), Mid.gold);
    expect(usedColor(left: 0, over: true), Mid.coral);
    await expectLater(
      find.byType(ColoredBox),
      matchesGoldenFile('goldens/used_bar.png'),
    );
  });
}
