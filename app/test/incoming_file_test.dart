import 'package:betterbudget/data/incoming_file.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// A bank file sent to the app from another (#531), as the phone's own code
// hands it over on `betterbudget/incoming`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('betterbudget/incoming');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'a file waiting from before is taken at once; one the phone could '
    'not read comes with nothing in it; nothing waiting is nothing',
    () async {
      final waiting = <Object?>[
        {
          'name': 'statement.xls',
          'bytes': Uint8List.fromList([1, 2, 3]),
        },
        {'name': 'broken.xls', 'bytes': null},
        null,
        {'name': 7},
      ];
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'take');
        return waiting.removeAt(0);
      });
      final got = <SentFile>[];
      await IncomingFiles.listen(got.add);
      expect(got.single.name, 'statement.xls');
      expect(got.single.bytes, [1, 2, 3]);

      // The phone says another arrived.
      Future<void> arrived() => messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('arrived'),
        ),
        (_) {},
      );
      await arrived();
      expect(got.last.name, 'broken.xls');
      expect(got.last.bytes, isEmpty);
      await arrived();
      await arrived();
      expect(got, hasLength(2));
    },
  );

  test('a computer, with nothing answering, never has one', () async {
    final got = <SentFile>[];
    await IncomingFiles.listen(got.add);
    expect(got, isEmpty);
  });
}
