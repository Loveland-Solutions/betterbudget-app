/// A bank file sent to BetterBudget from another app (#531): the bank's
/// app, Files or mail. Android hands it over by an intent
/// (`MainActivity.kt`), an iPhone by opening it in the app
/// (`IncomingFile` in `ios/Runner/AppDelegate.swift`). Each reads the file into memory and
/// keeps nothing of it; this side takes it once the phone's ledger is up.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A file sent to the app: its name as the other app gave it, and what is
/// in it.
typedef SentFile = ({String name, Uint8List bytes});

/// The channel the phone's own code answers.
abstract final class IncomingFiles {
  static const _channel = MethodChannel('betterbudget/incoming');

  /// Calls [onFile] with a file sent before now, if one waits, and with
  /// each one sent while the app is open.
  static Future<void> listen(void Function(SentFile file) onFile) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'arrived') await _take(onFile);
    });
    await _take(onFile);
  }

  static Future<void> _take(void Function(SentFile file) onFile) async {
    try {
      final sent = await _channel.invokeMapMethod<String, Object?>('take');
      if (sent == null) return;
      final name = sent['name'], bytes = sent['bytes'];
      // One the phone couldn't read comes with no bytes, and is said to be
      // unreadable as a picked one is.
      if (name is String) {
        onFile((name: name, bytes: bytes is Uint8List ? bytes : Uint8List(0)));
      }
    } on MissingPluginException {
      // A computer, or a build without it: nothing is ever sent.
    } catch (e) {
      debugPrint('Taking a file sent to the app failed: $e');
    }
  }
}
