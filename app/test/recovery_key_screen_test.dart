import 'dart:io';
import 'dart:math';

import 'package:betterbudget/data/keys.dart';
import 'package:betterbudget/ui/recovery_key_screen.dart';
import 'package:betterbudget/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFont(String family, String path) async {
  final bytes = await File(path).readAsBytes();
  await (FontLoader(
    family,
  )..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
}

void main() {
  setUpAll(() async {
    await _loadFont('Onest', 'assets/fonts/Onest-Variable.ttf');
    await _loadFont('Manrope', 'assets/fonts/Manrope-Variable.ttf');
    await _loadFont(
      'BetterBudget Symbols',
      'assets/fonts/BetterBudgetSymbols.ttf',
    );
    final icons =
        '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    if (File(icons).existsSync()) await _loadFont('MaterialIcons', icons);
  });

  testWidgets('the key is shown once, on one line, and Copy counts as kept', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        if (call.method == 'Clipboard.getData') {
          return {'text': clipboard};
        }
        return null;
      },
    );
    final key = RecoveryKey.generate(random: Random(7));
    bool? kept;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        home: RecoveryKeySetupScreen(
          recoveryKey: key,
          onContinue: (k) async => kept = k,
        ),
      ),
    );
    expect(find.textContaining('This is the only time it’s shown'), findsOne);
    expect(find.byKey(const ValueKey('recovery-key-warning')), findsOne);
    // One line: as tall as a single line of the key's text.
    final text = tester.getSize(find.text(key.display));
    expect(text.height, lessThan(40));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/recovery_key_setup.png'),
    );

    await tester.tap(find.byKey(const ValueKey('copy-recovery-key')));
    await tester.pumpAndSettle();
    expect(clipboard, key.display);
    expect(find.text('Copied'), findsOne);
    // Copying isn't keeping: the line says to paste it somewhere first.
    expect(
      find.textContaining('paste it somewhere off this computer'),
      findsOne,
    );

    await tester.tap(find.byKey(const ValueKey('recovery-key-continue')));
    await tester.pump();
    expect(kept, isTrue);

    // A minute later the clipboard no longer holds the key.
    await tester.pump(const Duration(seconds: 61));
    expect(clipboard, '');
  });

  testWidgets('continuing without saving or copying reports it', (
    tester,
  ) async {
    bool? kept;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: RecoveryKeySetupScreen(
          recoveryKey: RecoveryKey.generate(),
          onContinue: (k) async => kept = k,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('recovery-key-continue')));
    expect(kept, isFalse);
  });
}
