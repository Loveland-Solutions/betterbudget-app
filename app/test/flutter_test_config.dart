import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs before every test file. On GitHub (`.github/workflows/check.yml`) a golden
/// may differ by up to `GOLDEN_TOLERANCE` (a fraction of its pixels): that Mac's
/// macOS draws the edges of letters a little differently from the one the goldens
/// were drawn on (0.30% of a picture at most when this was written). That still
/// catches a page that moved or lost a panel, not one word changed; here, with no
/// `GOLDEN_TOLERANCE`, a golden must match exactly.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final tolerance = double.tryParse(Platform.environment['GOLDEN_TOLERANCE'] ?? '');
  if (tolerance != null && goldenFileComparator is LocalFileComparator) {
    final base = (goldenFileComparator as LocalFileComparator).basedir;
    goldenFileComparator = _Tolerant(base.resolve('flutter_test_config.dart'), tolerance);
  }
  await testMain();
}

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
