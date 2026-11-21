import 'dart:io';

import 'package:betterbudget/data/picked_copy.dart';
import 'package:flutter_test/flutter_test.dart';

// The copy a phone's picker leaves of a bank file is removed once read, and
// nothing of the person's own ever is (#531).
void main() {
  late Directory own, theirs;
  setUp(() {
    final root = Directory.systemTemp.createTempSync('bb-picked');
    own = Directory('${root.path}/cache')..createSync();
    theirs = Directory('${root.path}/downloads')..createSync();
    addTearDown(() => root.deleteSync(recursive: true));
  });

  test('a copy in the folder the picker made inside the app\'s cache goes, '
      'and that folder with it', () async {
    final made = Directory('${own.path}/3f2a')..createSync();
    final copy = File('${made.path}/statement.xls')..writeAsStringSync('rows');
    expect(await dropPickedCopy(copy.path, own: [own.path]), isTrue);
    expect(copy.existsSync(), isFalse);
    expect(made.existsSync(), isFalse);
    expect(own.existsSync(), isTrue);
  });

  test('a copy straight in the app\'s temporary folder goes, and the folder '
      'stays with whatever else is in it', () async {
    final other = File('${own.path}/other')..writeAsStringSync('kept');
    final copy = File('${own.path}/statement.xls')..writeAsStringSync('rows');
    expect(await dropPickedCopy(copy.path, own: [own.path]), isTrue);
    expect(copy.existsSync(), isFalse);
    expect(other.existsSync(), isTrue);
  });

  test('a file anywhere else is the person\'s and is left alone, also one '
      'whose folder only starts with the same letters, and one reached by '
      'a link out of the app\'s folder', () async {
    final file = File('${theirs.path}/statement.xls')
      ..writeAsStringSync('rows');
    expect(await dropPickedCopy(file.path, own: [own.path]), isFalse);
    expect(file.existsSync(), isTrue);

    final near = Directory('${own.path}-kept')..createSync();
    final beside = File('${near.path}/statement.xls')
      ..writeAsStringSync('rows');
    expect(await dropPickedCopy(beside.path, own: [own.path]), isFalse);
    expect(beside.existsSync(), isTrue);

    final link = Link('${own.path}/statement.xls')..createSync(file.path);
    expect(await dropPickedCopy(link.path, own: [own.path]), isFalse);
    expect(file.existsSync(), isTrue);

    expect(await dropPickedCopy('', own: [own.path]), isFalse);
    expect(
      await dropPickedCopy('${own.path}/gone.xls', own: [own.path]),
      isFalse,
    );
  });
}
