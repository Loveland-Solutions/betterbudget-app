// The phone screens on invented figures, to look at them on a real phone before
// the Mac can send a snapshot (ADR 0005). Built on its own with
// `flutter build apk --debug -t lib/phone_preview.dart`; `main.dart` doesn't use it.
// Entries saved here live only until the app is closed.
import 'package:flutter/material.dart';

import 'ui/phone/phone_app.dart';
import 'ui/phone/phone_demo.dart';

export 'ui/phone/phone_demo.dart' show previewSnapshot;

void main() {
  usePhoneColors();
  final now = DateTime.now();
  runApp(
    PhoneApp(
      store: PhoneStore(
        previewSnapshot(DateTime(now.year, now.month, now.day, 8, 10)),
      ),
    ),
  );
}
