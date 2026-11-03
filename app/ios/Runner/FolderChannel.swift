import Flutter
import UIKit
import UniformTypeIdentifiers

// The folder the ledger was moved to (ADR 0005), reached through the Files
// picker, which is how the app reads a Google Drive, OneDrive or iCloud Drive
// folder without touching the network itself. `lib/data/phone_ledger.dart`
// calls this; it answers as Android's `MainActivity.kt` does.
class FolderChannel: NSObject, UIDocumentPickerDelegate {
  // The picked folder, kept across launches as a security-scoped bookmark.
  private let bookmarkKey = "betterbudget.folder"
  // The folder's URL as resolved, which carries the right to open it; the
  // address the app holds is its string.
  private var held: URL?
  private var pendingPick: FlutterResult?

  init(messenger: FlutterBinaryMessenger) {
    super.init()
    FlutterMethodChannel(name: "betterbudget/folder", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "pick":
      // A picker already open answers its caller with nothing.
      pendingPick?(nil)
      pendingPick = result
      let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
      picker.delegate = self
      guard let top = topController() else {
        pendingPick = nil
        result(FlutterError(code: "NoWindow", message: "Nothing to show the picker on", details: nil))
        return
      }
      top.present(picker, animated: true)
    // The folder picked on an earlier launch, if the phone still lets the app read it.
    case "kept":
      result(resolveKept()?.absoluteString)
    case "read", "changed", "write":
      // Which folder is settled here, on the UI thread; the file work isn't.
      guard let dir = folder(args) else {
        result(FlutterError(code: "NotKept", message: "That folder is no longer kept", details: nil))
        return
      }
      let name = args["name"] as! String
      background(result) {
        switch call.method {
        case "read":
          return try self.read(dir, name)
        // When the file was last changed, without fetching it.
        case "changed":
          return try self.find(dir, name)?.changed
        default:
          try self.write(dir, name, (args["bytes"] as! FlutterStandardTypedData).data)
          return nil
        }
      }
    case "forget":
      // Only the folder named: a new pick has already taken the bookmark's place.
      let address = args["folder"] as? String
      if held?.absoluteString == address { held = nil }
      if resolveKept()?.absoluteString == address {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        held = nil
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pendingPick else { return }
    pendingPick = nil
    guard let url = urls.first else {
      result(nil)
      return
    }
    do {
      // Read and write: the phone's own entries will be written here too.
      try scoped(url) {
        let bookmark = try url.bookmarkData(
          options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
      }
      held = url
      result(url.absoluteString)
    } catch {
      result(FlutterError(code: "\(type(of: error))", message: error.localizedDescription, details: url.absoluteString))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingPick?(nil)
    pendingPick = nil
  }

  // The kept folder, its bookmark renewed when the system says it went stale
  // (the folder moved or was renamed); nil when there is none or it's gone.
  private func resolveKept() -> URL? {
    guard let bookmark = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
    var stale = false
    guard let url = try? URL(
      resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
    else { return nil }
    if stale, let fresh = try? scoped(url, {
      try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }) {
      UserDefaults.standard.set(fresh, forKey: bookmarkKey)
    }
    held = url
    return url
  }

  // The folder an address names, with its right to be opened.
  private func folder(_ args: [String: Any]) -> URL? {
    let address = args["folder"] as? String
    if let url = held, url.absoluteString == address { return url }
    if let url = resolveKept(), url.absoluteString == address { return url }
    return nil
  }

  // A cloud folder's provider may go to the network, so never on the UI thread.
  private func background(_ result: @escaping FlutterResult, _ work: @escaping () throws -> Any?) {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let value = try work()
        DispatchQueue.main.async { result(value) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "\(type(of: error))", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func read(_ folder: URL, _ name: String) throws -> [String: Any]? {
    guard try find(folder, name) != nil else { return nil }
    let file = folder.appendingPathComponent(name)
    // A coordinated read makes the provider fetch a file not yet on the phone.
    let bytes: Data = try coordinated(folder) { coordinator in
      var out: Result<Data, Error> = .failure(FolderError.notRead)
      var failure: NSError?
      coordinator.coordinate(readingItemAt: file, options: [], error: &failure) { url in
        out = Result { try Data(contentsOf: url) }
      }
      if let failure { throw failure }
      return try out.get()
    }
    let changed: Any = try find(folder, name)?.changed ?? NSNull()
    return ["bytes": FlutterStandardTypedData(bytes: bytes), "changed": changed]
  }

  // The phone's own entries, for the computer: written over the file of
  // that name, or as a new file the first time.
  private func write(_ folder: URL, _ name: String, _ bytes: Data) throws {
    let file = folder.appendingPathComponent(name)
    try coordinated(folder) { coordinator in
      var out: Result<Void, Error> = .success(())
      var failure: NSError?
      coordinator.coordinate(writingItemAt: file, options: .forReplacing, error: &failure) { url in
        out = Result { try bytes.write(to: url, options: .atomic) }
      }
      if let failure { throw failure }
      try out.get()
    }
  }

  // Whether the folder holds [name], and when it was changed (milliseconds).
  // iCloud Drive may show a file not yet on the phone as `.name.icloud`.
  private func find(_ folder: URL, _ name: String) throws -> (found: Bool, changed: Int64?)? {
    try coordinated(folder) { coordinator in
      var out: Result<(found: Bool, changed: Int64?)?, Error> = .success(nil)
      var failure: NSError?
      // The folder's listing as the provider has it, without fetching files.
      coordinator.coordinate(
        readingItemAt: folder, options: .immediatelyAvailableMetadataOnly, error: &failure
      ) { dir in
        out = Result {
          var file = dir.appendingPathComponent(name)
          let manager = FileManager.default
          if !manager.fileExists(atPath: file.path) {
            guard manager.fileExists(atPath: dir.appendingPathComponent(".\(name).icloud").path)
            else { return nil }
            return (true, nil)
          }
          file.removeAllCachedResourceValues()
          let at = try file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
          return (true, at.map { Int64(($0.timeIntervalSince1970 * 1000).rounded()) })
        }
      }
      if let failure { throw failure }
      return try out.get()
    }
  }

  private func coordinated<T>(_ folder: URL, _ work: (NSFileCoordinator) throws -> T) throws -> T {
    try scoped(folder) { try work(NSFileCoordinator(filePresenter: nil)) }
  }

  // Opens the folder's right for the length of [work] only.
  private func scoped<T>(_ url: URL, _ work: () throws -> T) throws -> T {
    let opened = url.startAccessingSecurityScopedResource()
    defer { if opened { url.stopAccessingSecurityScopedResource() } }
    return try work()
  }

  private func topController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
      ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
      ?? scene?.windows.first?.rootViewController
    while let shown = top?.presentedViewController { top = shown }
    return top
  }
}

enum FolderError: Error {
  case notRead
}
