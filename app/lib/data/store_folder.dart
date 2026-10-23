// Where the Windows app keeps its files when it came from the Microsoft Store
// (#246; ADR 0001 "Where the ledger lives on Windows"). The owner, 2026-10-23:
// what's left behind on uninstall is garbage. So the Store app keeps the
// ledger, its daily copies, the saved key and its small settings files in the
// package's own folder, `%LOCALAPPDATA%\Packages\<family>\LocalState`, which
// Windows deletes with the app. It never looks in the zip download's folder
// (`%APPDATA%\Loveland Solutions\BetterBudget`): reaching in there, Windows
// would edit the zip's ledger in place but send every new file beside it to
// the package, one ledger split in two. Someone moving from the zip download
// brings their ledger over with Open ledger, as a second computer does.
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:path_provider_windows/path_provider_windows.dart';

/// Hands everything that asks path_provider for the app's folder (this app,
/// and the key store, `flutter_secure_storage`) the Store package's own
/// folder when running from one. Call it first thing in `main`; elsewhere
/// it does nothing.
void useStoreFolderIfPackaged() {
  if (!Platform.isWindows) return;
  final family = _packageFamilyName();
  final local = Platform.environment['LOCALAPPDATA'];
  if (family == null || local == null) return;
  PathProviderPlatform.instance = StorePathProvider(
    '$local\\Packages\\$family\\LocalState',
  );
}

/// The Windows paths as path_provider gives them, but the app's own folder
/// is [localState].
class StorePathProvider extends PathProviderWindows {
  StorePathProvider(this.localState);

  final String localState;

  @override
  Future<String?> getApplicationSupportPath() async {
    await Directory(localState).create(recursive: true);
    return localState;
  }
}

/// The package's family name (`LovelandSolutions.BetterBudget_k7qe4ryghfzbt`),
/// or null when the app wasn't installed from a package (the zip download).
String? _packageFamilyName() {
  final getName = DynamicLibrary.open('kernel32.dll')
      .lookupFunction<
        Int32 Function(Pointer<Uint32>, Pointer<Utf16>),
        int Function(Pointer<Uint32>, Pointer<Utf16>)
      >('GetCurrentPackageFamilyName');
  const insufficientBuffer = 122;
  final length = calloc<Uint32>();
  try {
    // Asked with no room, it says how much it needs; without a package it
    // says APPMODEL_ERROR_NO_PACKAGE (15700) instead.
    if (getName(length, nullptr) != insufficientBuffer) return null;
    final name = calloc<Uint16>(length.value).cast<Utf16>();
    try {
      if (getName(length, name) != 0) return null;
      return name.toDartString();
    } finally {
      calloc.free(name);
    }
  } finally {
    calloc.free(length);
  }
}
