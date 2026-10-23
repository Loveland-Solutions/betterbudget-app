import 'dart:io';

import 'package:betterbudget/data/store_folder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  test('the Store folder is the app folder, made if missing', () async {
    final tmp = await Directory.systemTemp.createTemp('store_folder');
    addTearDown(() => tmp.delete(recursive: true));
    final localState = '${tmp.path}/Packages/family/LocalState';

    final path = await StorePathProvider(localState).getApplicationSupportPath();

    expect(path, localState);
    expect(Directory(localState).existsSync(), isTrue);
  });

  test('outside Windows nothing changes', () {
    final before = PathProviderPlatform.instance;
    useStoreFolderIfPackaged();
    expect(PathProviderPlatform.instance, same(before));
  });
}
