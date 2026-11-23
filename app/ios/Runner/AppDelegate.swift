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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BetterBudgetSecret") {
      // The recovery key copied for this phone only, expiring by itself: the
      // clipboard is never read back, which would show "Allow Paste".
      let channel = FlutterMethodChannel(
        name: "betterbudget/secret", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "copy", let args = call.arguments as? [String: Any],
          let text = args["text"] as? String
        else { return result(FlutterMethodNotImplemented) }
        let seconds = args["seconds"] as? Double ?? 60
        UIPasteboard.general.setItems(
          [["public.utf8-plain-text": text]],
          options: [
            .localOnly: true,
            .expirationDate: Date().addingTimeInterval(seconds),
          ])
        result(nil)
      }
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BetterBudgetIncoming") {
      let channel = IncomingFile(messenger: registrar.messenger())
      registrar.addSceneDelegate(channel)
      incoming = channel
    }
  }

  // A bank file opened in the app from another (IncomingFile below).
  private var incoming: IncomingFile?
}

// A bank file sent to BetterBudget from another app (#531): Files, Mail or
// the bank's app, by Share or Open in. The file is read into memory and the
// copy iOS made in the app's Inbox is deleted; `lib/data/incoming_file.dart`
// takes it with "take" once the phone's ledger is up.
final class IncomingFile: NSObject, FlutterSceneLifeCycleDelegate {
  private let channel: FlutterMethodChannel
  private var pending: [String: Any]?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "betterbudget/incoming", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "take" else { return result(FlutterMethodNotImplemented) }
      result(self?.pending)
      self?.pending = nil
    }
    // Opened from Files while the app wasn't running: should the scene's
    // connection not reach this (it was added after the scene connected),
    // the copy iOS put in the Inbox is taken from there instead, and any
    // older ones left behind are deleted.
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
      self?.sweepInbox()
    }
  }

  private var seen = false

  private var inbox: URL? {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
      .appendingPathComponent("Inbox")
  }

  private func sweepInbox() {
    guard let inbox else { return }
    let files =
      (try? FileManager.default.contentsOfDirectory(
        at: inbox, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
    guard !files.isEmpty else { return }
    func changed(_ url: URL) -> Date {
      (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
        ?? .distantPast
    }
    let newest = files.max { changed($0) < changed($1) }
    for file in files where file != newest {
      try? FileManager.default.removeItem(at: file)
    }
    // A file sent within the last few minutes is the one just opened;
    // anything older was left by a run that ended first.
    if let newest, !seen, Date().timeIntervalSince(changed(newest)) < 300 {
      take(newest)
    } else if let newest {
      try? FileManager.default.removeItem(at: newest)
    }
  }

  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard let url = connectionOptions?.urlContexts.first?.url, url.isFileURL else { return false }
    take(url)
    return true
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    guard let url = URLContexts.first?.url, url.isFileURL else { return false }
    take(url)
    return true
  }

  // Each file once: the sweep and a late scene callback may name the same.
  private var taken = Set<String>()

  private func take(_ url: URL) {
    seen = true
    guard taken.insert(url.standardizedFileURL.path).inserted else { return }
    let name = url.lastPathComponent
    DispatchQueue.global(qos: .userInitiated).async {
      let scoped = url.startAccessingSecurityScopedResource()
      defer { if scoped { url.stopAccessingSecurityScopedResource() } }
      var bytes: Data?
      // No bank statement is this big; a file that is gets said unreadable.
      if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
        size <= 64 << 20
      {
        bytes = try? Data(contentsOf: url)
      }
      // The copy iOS put in the app's own Documents/Inbox goes once read.
      if let inbox = self.inbox,
        url.standardizedFileURL.path.hasPrefix(inbox.standardizedFileURL.path)
      {
        try? FileManager.default.removeItem(at: url)
      }
      DispatchQueue.main.async {
        var sent: [String: Any] = ["name": name]
        if let bytes { sent["bytes"] = FlutterStandardTypedData(bytes: bytes) }
        self.pending = sent
        self.channel.invokeMethod("arrived", arguments: nil)
      }
    }
  }
}
