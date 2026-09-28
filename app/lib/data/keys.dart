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
  /// right length or the checksum doesn't match.
  static RecoveryKey? parse(String input) {
    final cleaned = input
        .toUpperCase()
        .replaceAll(RegExp('[^A-Z0-9]'), '')
        .replaceAll('O', '0')
        .replaceAll('I', '1');
    if (cleaned.length != _totalLength) return null;
    for (final c in cleaned.split('')) {
      if (!alphabet.contains(c)) return null;
    }
    final body = cleaned.substring(0, _totalLength - 1);
    final check = cleaned.substring(_totalLength - 1);
    if (_checkChar(body) != check) return null;
    return RecoveryKey._(cleaned);
  }

  static String _checkChar(String body) {
    var sum = 0;
    for (var i = 0; i < body.length; i++) {
      sum = (sum + alphabet.indexOf(body[i]) * (i + 1)) % alphabet.length;
    }
    return alphabet[sum];
  }
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
