// Recovery key and data key management per ADR 0001: one 256-bit data key
// encrypts the database, every backup, and the phone snapshot/inbox files.
// It is derived (HKDF-SHA256) from a recovery key the user keeps, so the
// same key opens the ledger and its backups on any device, with no key
// leaving this device except through the recovery key itself.
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 25 characters in 5 groups of 5, drawn from an alphabet with no `I` or
/// `O` (easily misread as `1` or `0`), the last character a checksum
/// against typos.
class RecoveryKey {
  RecoveryKey._(this._body);

  /// The 25 characters without dashes, uppercase.
  final String _body;

  /// `I` and `O` excluded: a typed `I` or `O` is corrected to `1`/`0` by
  /// [parse], so it always resolves to a real character in the key.
  static const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789';
  static const groupCount = 5;
  static const groupLength = 5;
  static const _totalLength = groupCount * groupLength;

  /// `ABCDE-FGHJK-LMNPQ-RSTUV-WXYZ01` for display, Print and Save.
  String get display => [
    for (var i = 0; i < groupCount; i++)
      _body.substring(i * groupLength, i * groupLength + groupLength),
  ].join('-');

  Uint8List get bytes => Uint8List.fromList(utf8.encode(_body));

  static RecoveryKey generate({Random? random}) {
    final r = random ?? Random.secure();
    final body = StringBuffer();
    for (var i = 0; i < _totalLength - 1; i++) {
      body.write(alphabet[r.nextInt(alphabet.length)]);
    }
    return RecoveryKey._(body.toString() + _checkChar(body.toString()));
  }

  /// Parses what the user typed: case-insensitive, dashes and spaces
  /// ignored, a typed `O` or `I` corrected to `0`/`1` (neither letter is in
  /// [alphabet], so the correction is unambiguous). Null if it isn't the
  /// right length or the checksum doesn't match; [problem] says which.
  static RecoveryKey? parse(String input) {
    final cleaned = _clean(input);
    if (cleaned.length != _totalLength) return null;
    final body = cleaned.substring(0, _totalLength - 1);
    final check = cleaned.substring(_totalLength - 1);
    if (_checkChar(body) != check && _firstCheckChar(body) != check) {
      return null;
    }
    return RecoveryKey._(cleaned);
  }

  /// Why [input] isn't a key, or null if it is one. The UI words it
  /// (`keyProblem` in ui/data_words.dart).
  static KeyProblem? check(String input) {
    if (RegExp('[\u0400-\u04FF]').hasMatch(input)) {
      return const KeyProblem(KeyProblemKind.cyrillic);
    }
    final cleaned = _clean(input);
    if (cleaned.length != _totalLength) {
      return KeyProblem(
        KeyProblemKind.length,
        typed: cleaned.length,
        total: _totalLength,
      );
    }
    if (parse(input) == null) return const KeyProblem(KeyProblemKind.checksum);
    return null;
  }

  /// [check], in English.
  static String? problem(String input) => check(input)?.english;

  static String _clean(String input) => input
      .toUpperCase()
      .replaceAll('O', '0')
      .replaceAll('I', '1')
      .split('')
      .where(alphabet.contains)
      .join();

  /// Weights coprime to the alphabet's 34, so changing any one character
  /// always changes the check character (B for 8, S for 5).
  static const _weights = [1, 3, 5, 7, 9, 11, 13, 15, 19, 21, 23, 25, 27];

  /// The check character as the first encryption build worked it out, until
  /// 11:50 on 2026-09-29. A key shown before then ends in this one, and it
  /// is still the key to its ledger (the data key comes from all 25
  /// characters, whichever rule made the last), so [parse] takes either.
  /// The owner's own key is one of these: for eight days the app called it
  /// mistyped, and only the Keychain's copy of the data key opened the
  /// ledger.
  static String _firstCheckChar(String body) {
    var sum = 0;
    for (var i = 0; i < body.length; i++) {
      sum = (sum + alphabet.indexOf(body[i]) * (i + 1)) % alphabet.length;
    }
    return alphabet[sum];
  }

  static String _checkChar(String body) {
    var sum = 0;
    for (var i = 0; i < body.length; i++) {
      final w = _weights[i % _weights.length];
      sum = (sum + alphabet.indexOf(body[i]) * w) % alphabet.length;
    }
    return alphabet[sum];
  }
}

enum KeyProblemKind {
  /// The keyboard is typing Cyrillic; the key is Latin letters and digits.
  cyrillic,

  /// Too few or too many characters: [KeyProblem.typed] of
  /// [KeyProblem.total].
  length,

  /// The right length, but the check character doesn't match.
  checksum,
}

/// Why a typed recovery key isn't one.
class KeyProblem {
  const KeyProblem(this.kind, {this.typed = 0, this.total = 0});
  final KeyProblemKind kind;
  final int typed;
  final int total;

  String get english => switch (kind) {
    KeyProblemKind.cyrillic =>
      'Your keyboard is typing Cyrillic · switch to ABC to type the key',
    KeyProblemKind.length => '$typed of $total characters',
    KeyProblemKind.checksum =>
      'A character is wrong · check the key against your copy',
  };
}

/// The 256-bit key that encrypts the database and every backup, derived
/// from the recovery key so it never needs to be stored anywhere on its own.
Uint8List deriveDataKey(RecoveryKey key) {
  // HKDF-SHA256 (RFC 5869): extract with a fixed salt (there is only one
  // key per recovery key, so a random salt would have to be stored
  // somewhere, defeating the point), expand to 32 bytes.
  final salt = utf8.encode('betterbudget-v1-data-key-salt');
  final prk = Hmac(sha256, salt).convert(key.bytes).bytes;
  final info = utf8.encode('betterbudget-v1-sqlcipher-key');
  final t1 = Hmac(sha256, prk).convert([...info, 0x01]).bytes;
  return Uint8List.fromList(t1);
}

/// Whether two keys are the same, in time that doesn't depend on where they
/// differ.
bool sameKey(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// `x'...'` hex literal SQLCipher's `PRAGMA key` takes as a raw (not
/// passphrase-derived) key, so opening a database never re-runs key
/// stretching.
String rawKeyLiteral(Uint8List key) {
  final hex = key
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();
  return "x'$hex'";
}

/// Thrown when there is no platform secure store to hold the data key
/// (Linux without a Secret Service running). The caller should ask for the
/// recovery key at launch instead and keep the data key in memory only.
class NoSecureStoreException implements Exception {}

/// Wraps `flutter_secure_storage` with the per-platform options ADR 0001
/// calls for: Keychain "this device only" on macOS and iOS, Android
/// Keystore, Windows DPAPI, the Secret Service on Linux. Nothing here is
/// synced between devices.
class KeyStore {
  KeyStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
              synchronizable: false,
            ),
            mOptions: MacOsOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
              synchronizable: false,
            ),
            aOptions: AndroidOptions(),
          );

  final FlutterSecureStorage _storage;
  static const _dataKeyKey = 'betterbudget.dataKey';

  /// Where an earlier build kept the recovery key's text so Settings could
  /// show it again. The recovery key is now shown once and never stored
  /// (owner, 2026-09-28), so this is only ever deleted.
  static const _legacyRecoveryKeyKey = 'betterbudget.recoveryKeyDisplay';

  /// The stored data key, or null if none has been set yet. Throws
  /// [NoSecureStoreException] on Linux with no Secret Service.
  Future<Uint8List?> readDataKey() async {
    final value = await _read(_dataKeyKey);
    return value == null ? null : base64Decode(value);
  }

  Future<void> writeDataKey(Uint8List key) =>
      _write(_dataKeyKey, base64Encode(key));

  /// Whether the recovery key was saved, copied, typed or checked here. Kept
  /// beside the data key, not in the ledger, so starting a new ledger or
  /// restoring a backup doesn't change it.
  static const _keySavedKey = 'betterbudget.recoveryKeySaved';

  Future<bool?> readKeySaved() async {
    final v = await _read(_keySavedKey);
    return v == null ? null : v == '1';
  }

  Future<void> writeKeySaved(bool saved) =>
      _write(_keySavedKey, saved ? '1' : '0');

  /// Deletes a recovery key an earlier build stored. Never throws: a store
  /// that can't be reached has nothing in it to delete.
  Future<void> forgetStoredRecoveryKey() async {
    try {
      await _storage.delete(key: _legacyRecoveryKeyKey);
    } on Object catch (e) {
      debugPrint('Couldn’t clear an old recovery key: $e');
    }
  }

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } on Object catch (e) {
      if (_isMissingSecretService(e)) throw NoSecureStoreException();
      rethrow;
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } on Object catch (e) {
      if (_isMissingSecretService(e)) throw NoSecureStoreException();
      rethrow;
    }
  }

  /// `flutter_secure_storage`'s Linux backend throws when libsecret has no
  /// Secret Service to talk to (no GNOME Keyring or KWallet running).
  static bool _isMissingSecretService(Object e) =>
      defaultTargetPlatform == TargetPlatform.linux &&
      e.toString().toLowerCase().contains('secret');
}
