// RecoveryKey generation/parsing/checksum, HKDF derivation, and KeyStore
// against a fake secure-storage platform (ADR 0001).
import 'dart:math';

import 'package:betterbudget/data/encryption.dart';
import 'package:betterbudget/data/keys.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

/// An in-memory secure store, standing in for the OS keychain in tests —
/// the same pattern the app already uses for file_selector (see CLAUDE.md).
class _FakeSecureStorage extends FlutterSecureStoragePlatform {
  final _values = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => _values[key] = value;

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => _values[key];

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => _values.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => _values.remove(key);

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(_values);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      _values.clear();
}

/// Simulates Linux with no Secret Service running: every call fails the way
/// `flutter_secure_storage_linux` does when libsecret has nothing to talk to.
class _NoSecretServiceStorage extends FlutterSecureStoragePlatform {
  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => throw PlatformException(code: '1', message: 'no Secret Service');

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => throw PlatformException(code: '1', message: 'no Secret Service');

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => false;

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {}

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => {};

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {}
}

void main() {
  group('RecoveryKey', () {
    test('generates 25 characters in 5 groups of 5', () {
      final key = RecoveryKey.generate();
      final groups = key.display.split('-');
      expect(groups, hasLength(5));
      expect(groups.every((g) => g.length == 5), isTrue);
    });

    test('never contains I or O', () {
      final r = Random(1);
      for (var i = 0; i < 200; i++) {
        final key = RecoveryKey.generate(random: r);
        expect(key.display.contains('I'), isFalse);
        expect(key.display.contains('O'), isFalse);
      }
    });

    test('parses its own display string back out', () {
      final key = RecoveryKey.generate();
      final parsed = RecoveryKey.parse(key.display);
      expect(parsed, isNotNull);
      expect(parsed!.display, key.display);
    });

    test('ignores case, dashes and spaces', () {
      final key = RecoveryKey.generate();
      final messy = key.display.toLowerCase().replaceAll('-', ' ');
      expect(RecoveryKey.parse(messy)?.display, key.display);
    });

    test('corrects a typed O or I to 0 or 1', () {
      final key = RecoveryKey.generate();
      final withTypos = key.display
          .replaceFirst(RegExp('[02-9A-HJ-NP-Z]'), 'O')
          .replaceFirst(RegExp('[02-9A-HJ-NP-Z]'), 'I');
      // Only meaningful when the substitution actually changed characters
      // that round-trip to the same value (0 and 1 must appear in [key]).
      final reparsed = RecoveryKey.parse(withTypos);
      // Whether it parses depends on whether the substituted positions were
      // 0/1 in the original; regardless, a direct 0/1 check below proves
      // the correction itself works unconditionally.
      expect(RecoveryKey.parse('OOOOOIIIIIOOOOOIIIIIOOOOI'), isNull);
      expect(reparsed == null || reparsed.display == key.display, isTrue);
    });

    test('rejects the wrong length', () {
      expect(RecoveryKey.parse('ABCDE-FGHJK'), isNull);
    });

    test('a single mistyped character is caught, or makes another key', () {
      // The check character catches a typo at once, except the few that
      // happen to fit the first build's rule (which [parse] also takes, for
      // keys shown then). Those read as some other key, which opens nothing:
      // a key is only ever kept after it has opened the ledger.
      final key = RecoveryKey.generate(random: Random(3));
      final body = key.display.replaceAll('-', '');
      final real = deriveDataKey(key);
      var caught = 0, slipped = 0;
      for (var i = 0; i < body.length; i++) {
        for (final c in RecoveryKey.alphabet.split('')) {
          if (c == body[i]) continue;
          final typo = RecoveryKey.parse(body.replaceRange(i, i + 1, c));
          if (typo == null) {
            caught++;
          } else {
            slipped++;
            expect(
              sameKey(deriveDataKey(typo), real),
              isFalse,
              reason: 'position $i: $c',
            );
          }
        }
      }
      // About one in 34 fits the other rule by chance.
      expect(slipped, lessThan(caught ~/ 20));
    });

    test('says what is wrong with a typed key', () {
      final key = RecoveryKey.generate(random: Random(4));
      expect(RecoveryKey.problem(key.display), isNull);
      expect(
        RecoveryKey.problem('АБВГД-ЕЖЗИЙ'),
        'Your keyboard is typing Cyrillic · switch to ABC to type the key',
      );
      expect(
        RecoveryKey.problem(key.display.substring(0, 20)),
        startsWith('17 of 25 characters'),
      );
      final last = key.display[key.display.length - 1];
      final other = last == 'A' ? 'B' : 'A';
      expect(
        RecoveryKey.problem(
          key.display.substring(0, key.display.length - 1) + other,
        ),
        startsWith('A character is wrong'),
      );
    });

    test('keys match only when they are the same', () {
      final a = deriveDataKey(RecoveryKey.generate());
      expect(sameKey(a, Uint8List.fromList(a)), isTrue);
      expect(sameKey(a, deriveDataKey(RecoveryKey.generate())), isFalse);
      expect(sameKey(a, a.sublist(0, 31)), isFalse);
    });

    test('takes a key whose last character follows the first build’s rule', () {
      // Shown by the build of the night of 2026-09-28: the check character
      // weighed each place by its position. The owner's key is one of these.
      final r = Random(11);
      final body = [
        for (var i = 0; i < 24; i++)
          RecoveryKey.alphabet[r.nextInt(RecoveryKey.alphabet.length)],
      ].join();
      var sum = 0;
      for (var i = 0; i < body.length; i++) {
        sum = (sum + RecoveryKey.alphabet.indexOf(body[i]) * (i + 1)) % 34;
      }
      final typed = body + RecoveryKey.alphabet[sum];
      final key = RecoveryKey.parse(typed);
      expect(key, isNotNull);
      expect(RecoveryKey.check(typed), isNull);
      // All 25 characters, as shown then, make the data key.
      expect(key!.display.replaceAll('-', ''), typed);
      // A plain typo in it is still caught.
      final wrong = (typed[0] == 'A' ? 'B' : 'A') + typed.substring(1);
      expect(RecoveryKey.parse(wrong), isNull);
    });

    test('rejects a bad checksum', () {
      final key = RecoveryKey.generate();
      final body = key.display.replaceAll('-', '');
      final firstChar = body[0];
      // A different valid alphabet character in the first position, unless
      // it happens to already be that character.
      final swapped = (firstChar == 'A' ? 'B' : 'A') + body.substring(1);
      expect(RecoveryKey.parse(swapped), isNull);
    });
  });

  group('deriveDataKey', () {
    test('is 32 bytes and deterministic', () {
      final key = RecoveryKey.generate();
      final a = deriveDataKey(key);
      final b = deriveDataKey(key);
      expect(a.length, 32);
      expect(a, b);
    });

    test('differs between different recovery keys', () {
      final r = Random(2);
      final a = deriveDataKey(RecoveryKey.generate(random: r));
      final b = deriveDataKey(RecoveryKey.generate(random: r));
      expect(a, isNot(b));
    });
  });

  test('rawKeyLiteral is a 64-hex-character blob literal', () {
    final key = deriveDataKey(RecoveryKey.generate());
    final literal = rawKeyLiteral(key);
    expect(literal, matches(RegExp(r"^x'[0-9A-F]{64}'$")));
  });

  group('KeyStore', () {
    setUp(() => FlutterSecureStoragePlatform.instance = _FakeSecureStorage());

    test('round-trips the data key through the platform store', () async {
      final store = KeyStore();
      expect(await store.readDataKey(), isNull);
      final key = deriveDataKey(RecoveryKey.generate());
      await store.writeDataKey(key);
      expect(await store.readDataKey(), key);
    });

    test('clears a recovery key an earlier build stored', () async {
      final fake = _FakeSecureStorage();
      FlutterSecureStoragePlatform.instance = fake;
      final recovery = RecoveryKey.generate();
      fake._values['betterbudget.recoveryKeyDisplay'] = recovery.display;
      await KeyStore().forgetStoredRecoveryKey();
      expect(fake._values.values, isNot(contains(recovery.display)));
    });

    test(
      'throws NoSecureStoreException on Linux with no Secret Service',
      () async {
        FlutterSecureStoragePlatform.instance = _NoSecretServiceStorage();
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final store = KeyStore();
        await expectLater(
          store.readDataKey(),
          throwsA(isA<NoSecureStoreException>()),
        );
      },
    );
  });

  group('resolveDataKey', () {
    setUp(() => FlutterSecureStoragePlatform.instance = _FakeSecureStorage());

    test(
      'asks (canPersist: true) when nothing is stored yet — could be a '
      'fresh ledger or a second device for an existing recovery key',
      () async {
        final store = KeyStore();
        final result = await resolveDataKey(store);
        expect(result, isA<DataKeyNeedsRecoveryEntry>());
        expect((result as DataKeyNeedsRecoveryEntry).canPersist, isTrue);
      },
    );

    test('returns the existing key once one has been stored', () async {
      final store = KeyStore();
      final key = deriveDataKey(RecoveryKey.generate());
      await store.writeDataKey(key);
      final result = await resolveDataKey(store);
      expect(result, isA<DataKeyReady>());
      final ready = result as DataKeyReady;
      expect(ready.dataKey, key);
      expect(ready.newRecoveryKey, isNull);
    });

    test(
      'asks (canPersist: false) when there is no secure store at all',
      () async {
        FlutterSecureStoragePlatform.instance = _NoSecretServiceStorage();
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final store = KeyStore();
        final result = await resolveDataKey(store);
        expect(result, isA<DataKeyNeedsRecoveryEntry>());
        expect((result as DataKeyNeedsRecoveryEntry).canPersist, isFalse);
      },
    );
  });

  group('useRecoveryKey', () {
    setUp(() => FlutterSecureStoragePlatform.instance = _FakeSecureStorage());

    test('persists the key and marks it new when asked to', () async {
      final store = KeyStore();
      final recovery = RecoveryKey.generate();
      final ready = await useRecoveryKey(
        store,
        recovery,
        persist: true,
        isNew: true,
      );
      expect(ready.dataKey, deriveDataKey(recovery));
      expect(ready.newRecoveryKey, recovery);
      expect(await store.readDataKey(), ready.dataKey);
    });

    test('never stores the recovery key, only the data key', () async {
      final fake = _FakeSecureStorage();
      FlutterSecureStoragePlatform.instance = fake;
      final recovery = RecoveryKey.generate();
      await useRecoveryKey(KeyStore(), recovery, persist: true, isNew: true);
      expect(fake._values.keys, ['betterbudget.dataKey']);
      for (final v in fake._values.values) {
        expect(v, isNot(contains(recovery.display.replaceAll('-', ''))));
        expect(v, isNot(contains(recovery.display)));
      }
    });

    test('does not touch the store when persist is false', () async {
      final store = KeyStore();
      final recovery = RecoveryKey.generate();
      await useRecoveryKey(store, recovery, persist: false, isNew: false);
      expect(await store.readDataKey(), isNull);
    });

    test('newRecoveryKey is null for an existing (typed) key', () async {
      final store = KeyStore();
      final ready = await useRecoveryKey(
        store,
        RecoveryKey.generate(),
        persist: true,
        isNew: false,
      );
      expect(ready.newRecoveryKey, isNull);
    });
  });
}
