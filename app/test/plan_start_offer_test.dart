import 'dart:ui';

import 'package:betterbudget/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'the start offer says "1 category", not "1 categories" (#372)',
    () async {
      final t = await Words.delegate.load(const Locale('en'));
      expect(
        t.planStartOffer('₮64,210.50', 1),
        contains('in 1 category before'),
      );
      expect(t.planStartOffer('₮64,210.50', 1), contains('against it'));
      expect(
        t.planStartOffer('₮64,210.50', 3),
        contains('in 3 categories before'),
      );
    },
  );
}
