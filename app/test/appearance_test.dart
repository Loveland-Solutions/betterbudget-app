import 'dart:io';

import 'package:betterbudget/ui/appearance.dart';
import 'package:betterbudget/ui/schemes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('bb-appearance'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('a phone\'s look (#534 piece 5)', () {
    test('a phone in use before Settings keeps dark Blue eclipse, kept in '
        'its file', () async {
      final file = File('${dir.path}/appearance');
      final c = await AppearanceController.loadForPhone(file, inUse: true);
      expect(c.value, Appearance.dark);
      expect(c.scheme.id, blueEclipseScheme.id);
      await c.set(Appearance.dark); // waits for the write already going
      final again = await AppearanceController.load(file);
      expect(again.value, Appearance.dark);
      expect(again.scheme.id, blueEclipseScheme.id);
    });

    test('a phone started fresh begins as the computer does', () async {
      final c = await AppearanceController.loadForPhone(
        File('${dir.path}/appearance'),
        inUse: false,
      );
      expect(c.value, Appearance.system);
      expect(c.scheme.id, defaultScheme.id);
    });

    test('a phone started fresh keeps its look on the launches after '
        'setup made its key', () async {
      final file = File('${dir.path}/appearance');
      await AppearanceController.loadForPhone(file, inUse: false);
      final again = await AppearanceController.loadForPhone(
        file,
        inUse: true,
      );
      expect(again.value, Appearance.system);
      expect(again.scheme.id, defaultScheme.id);
    });

    test('a choice made in Settings is kept over the one a phone in use '
        'started with', () async {
      final file = File('${dir.path}/appearance');
      final first = await AppearanceController.loadForPhone(
        file,
        inUse: true,
      );
      await first.set(Appearance.light);
      await first.setScheme(betterBudgetScheme);
      final c = await AppearanceController.loadForPhone(file, inUse: true);
      expect(c.value, Appearance.light);
      expect(c.scheme.id, betterBudgetScheme.id);
    });
  });
}
