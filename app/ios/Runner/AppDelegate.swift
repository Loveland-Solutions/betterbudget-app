import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    forgetKeyFromEarlierInstall()
    keepOutOfBackups()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Deleting the app empties its UserDefaults but not the Keychain. On the
  // first launch of an install, a key left there by a copy since deleted is
  // removed before anything reads it, so a new install asks for the recovery
  // key as Android's does.
  private func forgetKeyFromEarlierInstall() {
    let installed = "betterbudget.installed"
    guard !UserDefaults.standard.bool(forKey: installed) else { return }
    SecItemDelete([
      kSecClass: kSecClassGenericPassword,
      kSecAttrSynchronizable: kSecAttrSynchronizableAny,
    ] as CFDictionary)
    UserDefaults.standard.set(true, forKey: installed)
  }

  // What the phone keeps (the ledger's copy, its waiting entries, the record
  // of problems) stays on this phone: not in iCloud backups, as Android's
  // allowBackup="false" keeps it out of Google's.
  private func keepOutOfBackups() {
    let manager = FileManager.default
    guard var support = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    else { return }
    try? manager.createDirectory(at: support, withIntermediateDirectories: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? support.setResourceValues(values)
  }

  // The cloud folder (FolderChannel.swift), kept as long as the engine is.
  private var folder: FolderChannel?

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BetterBudgetFolder") {
      folder = FolderChannel(messenger: registrar.messenger())
    }
  }
}
