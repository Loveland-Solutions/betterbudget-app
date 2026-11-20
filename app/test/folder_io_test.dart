// The two ways into the shared folder (ADR 0005, "The phone joins as another
// computer"): by path on a computer, through the system's picker on a phone.
import 'dart:io';

import 'package:betterbudget/data/folder_io.dart';
import 'package:betterbudget/data/phone_ledger.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a folder by path: stat, names, read, write over, delete', () async {
    const io = DirectoryFolderIo();
    final root = Directory.systemTemp.createTempSync('folder_io_');
    addTearDown(() => root.deleteSync(recursive: true));
    Directory('${root.path}/sub').createSync();
    expect(await io.stat(root.path, 'a.bin'), isNull);
    expect(await io.read(root.path, 'a.bin'), isNull);
    expect(await io.names('${root.path}/missing'), isEmpty);

    await io.write(root.path, 'a.bin', [1, 2, 3]);
    expect((await io.stat(root.path, 'a.bin'))!.size, 3);
    expect(await io.read(root.path, 'a.bin'), [1, 2, 3]);
    // Over the same file, cut short, not a second one.
    await io.write(root.path, 'a.bin', [9]);
    expect(await io.read(root.path, 'a.bin'), [9]);
    expect(await io.names(root.path), ['a.bin']);

    await io.delete(root.path, 'a.bin');
    await io.delete(root.path, 'a.bin');
    expect(await io.stat(root.path, 'a.bin'), isNull);
  });

  test(
    'a folder through the picker: each call goes to the channel with the '
    'folder and name, and its answers come back as the same shapes',
    () async {
      const channel = MethodChannel('betterbudget/folder');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            switch (call.method) {
              case 'stat':
                return call.arguments['name'] == 'gone'
                    ? null
                    : {'changed': 5000, 'size': 12};
              case 'list':
                return ['one', 'two'];
              case 'read':
                return {
                  'bytes': Uint8List.fromList([4, 5]),
                  'changed': 7,
                };
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      const io = PhoneFolderIo();
      final stat = await io.stat('content://f', 'x');
      expect(stat!.modified, DateTime.fromMillisecondsSinceEpoch(5000));
      expect(stat.size, 12);
      expect(await io.stat('content://f', 'gone'), isNull);
      expect(await io.names('content://f'), ['one', 'two']);
      expect(await io.read('content://f', 'x'), [4, 5]);
      await io.write('content://f', 'x', [1]);
      await io.delete('content://f', 'x');
      expect(calls.map((c) => c.method), [
        'stat',
        'stat',
        'list',
        'read',
        'write',
        'delete',
      ]);
      expect(calls.last.arguments, {'folder': 'content://f', 'name': 'x'});
    },
  );
}
