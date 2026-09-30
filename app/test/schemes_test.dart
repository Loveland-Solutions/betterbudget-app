import 'dart:io';
import 'dart:math' as math;

import 'package:betterbudget/ui/schemes.dart';
import 'package:betterbudget/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  test("Figma's 100 combinations, in its seven groups, plus the app's own", () {
    expect(schemes.length, 101);
    expect(schemes.first, betterBudgetScheme);
    expect(schemes.map((s) => s.id).toSet().length, 101);
    expect(schemes.every((s) => s.colors.length == 4), isTrue);
    expect(
      schemes.where((s) => s.group == SchemeGroup.monochromatic).length,
      11,
    );
    expect(schemes.where((s) => s.group == SchemeGroup.seasonal).length, 12);
    expect(schemeById('stormy-morning').colors.first, const Color(0xFF6A89A7));
    // Blue eclipse is the default (owner, 2026-09-30), and the same one as in
    // the list.
    expect(defaultScheme.id, 'blue-eclipse');
    expect(schemes.where((s) => identical(s, defaultScheme)).length, 1);
    expect(schemeById('purple'), defaultScheme);
    expect(schemeById(null), defaultScheme);
  });

  test("the app's own scheme is the hand-drawn Steppe pair", () {
    expect(Palette.of(betterBudgetScheme, Brightness.dark), same(Palette.dark));
    expect(
      Palette.of(betterBudgetScheme, Brightness.light),
      same(Palette.light),
    );
    final s = schemeById('harvest-moon');
    expect(
      Palette.of(s, Brightness.dark),
      same(Palette.of(s, Brightness.dark)),
    );
  });

  for (final b in Brightness.values) {
    test('every scheme reads in ${b.name} mode', () {
      for (final s in schemes) {
        final p = Palette.of(s, b);
        final why = '${s.id} ${b.name}';
        expect(p.brightness, b, reason: why);
        for (final surface in [p.ground, p.panel, p.card]) {
          expect(
            contrast(p.ink, surface),
            greaterThanOrEqualTo(7),
            reason: why,
          );
          // The app's own light ink3 on felt cream is 4.2 (hand-picked,
          // 2026-09-29); every made palette reaches 4.5.
          expect(
            contrast(p.ink3, surface),
            greaterThanOrEqualTo(identical(p, Palette.light) ? 4.2 : 4.5),
            reason: why,
          );
          expect(
            contrast(p.blue, surface),
            greaterThanOrEqualTo(4.5),
            reason: why,
          );
          // Money means the same in every scheme, and still reads.
          for (final m in [p.green, p.coral, p.gold]) {
            expect(
              contrast(m, surface),
              greaterThanOrEqualTo(3.5),
              reason: why,
            );
          }
        }
        expect(
          contrast(p.onAccent, p.blue),
          greaterThanOrEqualTo(4.5),
          reason: why,
        );
        // Surfaces are told apart in dark mode.
        if (b == Brightness.dark) {
          expect(p.ground, isNot(p.card), reason: why);
        }
        // What you click is a color, not a text gray, and never a money
        // color's hue; the sidebar's marks are never red or green.
        final blue = HSLColor.fromColor(p.blue);
        expect(blue.saturation, greaterThan(0.25), reason: why);
        expect(
          blue.hue >= 65 && blue.hue < 85 || blue.hue >= 165 && blue.hue < 335,
          isTrue,
          reason: '$why accent hue ${blue.hue}',
        );
        final sun = HSLColor.fromColor(p.sun).hue;
        expect(
          sun >= 30 && sun < 85 || sun >= 165 && sun < 335,
          isTrue,
          reason: '$why sun hue $sun',
        );
        // The sidebar is dark with light text in both modes.
        expect(
          contrast(p.sideInk, p.side),
          greaterThanOrEqualTo(7),
          reason: why,
        );
        expect(
          contrast(p.sideInk3, p.side),
          greaterThanOrEqualTo(4.5),
          reason: why,
        );
        expect(
          contrast(p.sideBlue, p.side),
          greaterThanOrEqualTo(4.5),
          reason: why,
        );
        expect(contrast(p.sun, p.side), greaterThanOrEqualTo(3), reason: why);
        expect(
          contrast(Mid.sideCoral, p.side),
          greaterThanOrEqualTo(4.5),
          reason: why,
        );
      }
    });
  }

  test('the dark-mode logo reads on every sidebar', () {
    // Every color the two files draw with, except the body's black stripes
    // (the gold between them shows the body's shape).
    final colors = <Color>{};
    for (final f in ['bee-dark', 'wordmark-dark']) {
      final svg = File('assets/brand/$f.svg').readAsStringSync();
      for (final m in RegExp(r'fill:#([0-9a-fA-F]{6})').allMatches(svg)) {
        colors.add(Color(int.parse('FF${m[1]}', radix: 16)));
      }
    }
    colors.remove(const Color(0xFF000000));
    expect(colors, isNot(contains(const Color(0xFF031A42))));
    expect(colors, contains(const Color(0xFF6FA3FF)));
    for (final s in schemes) {
      for (final b in Brightness.values) {
        final side = Palette.of(s, b).side;
        for (final c in colors) {
          // Gold is the body, a shape: 3:1. The rest is lettering: 4.5.
          final need = c == const Color(0xFFC9A96B) ? 3.0 : 4.5;
          expect(
            contrast(c, side),
            greaterThanOrEqualTo(need),
            reason: '${s.id} ${b.name} $c',
          );
        }
      }
    }
  });
}
