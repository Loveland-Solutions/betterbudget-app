import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs before every test file. On GitHub (`.github/workflows/check.yml`) a golden
/// may differ by up to `GOLDEN_TOLERANCE` (a fraction of its pixels): that Mac's
/// macOS draws the edges of letters a little differently from the one the goldens
/// were drawn on (0.30% of a picture at most when this was written). That still
/// catches a page that moved or lost a panel, not one word changed; here, with no
/// `GOLDEN_TOLERANCE`, a golden must match exactly.
///
/// Every test's computer is called [testComputerName]: the real one changes with the
/// network and would be published in the goldens (#235). Anything else asked on
/// the folder channel goes unanswered, as it does with no handler.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('betterbudget/folder'), (call) async {
      if (call.method == 'computerName') return testComputerName;
      throw MissingPluginException();
    });
  });
  final tolerance = double.tryParse(Platform.environment['GOLDEN_TOLERANCE'] ?? '');
  if (tolerance != null && goldenFileComparator is LocalFileComparator) {
    final base = (goldenFileComparator as LocalFileComparator).basedir;
    goldenFileComparator = _Tolerant(base.resolve('flutter_test_config.dart'), tolerance);
  }
  await testMain();
}

/// The made-up name every test's computer has.
const testComputerName = 'Office Mac';

class _Tolerant extends LocalFileComparator {
  _Tolerant(super.testFile, this.tolerance);

  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
