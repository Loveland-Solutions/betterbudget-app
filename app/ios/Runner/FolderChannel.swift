import Flutter
import UIKit
import UniformTypeIdentifiers

// The folder the ledger was moved to (ADR 0005), reached through the Files
// picker, which is how the app reads a Google Drive, OneDrive or iCloud Drive
// folder without touching the network itself. `lib/data/phone_ledger.dart`
// calls this; it answers as Android's `MainActivity.kt` does.
class FolderChannel: NSObject, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
  // The picked folder, kept across launches as a security-scoped bookmark.
  private let bookmarkKey = "betterbudget.folder"
  // The folder's URL as resolved from the bookmark, which carries the right
  // to open it; the address the app holds is its string. Touched on the UI
  // thread only.
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
      // Swiping the sheet down closes it without Cancel.
      picker.presentationController?.delegate = self
    // The folder picked on an earlier launch, if the phone still lets the app
    // read it. A bookmark that no longer opens is an error, not "none".
    case "kept":
      background(result) {
        let url = try self.resolveKept()
        DispatchQueue.main.async { self.held = url }
        return url?.absoluteString
      }
    case "read", "changed", "write":
      guard let address = args["folder"] as? String, let name = args["name"] as? String else {
        return result(badArguments(call))
      }
      switch call.method {
      case "read":
        inFolder(address, result) { try self.read($0, name) }
      // When the file was last changed, without fetching it.
      case "changed":
        inFolder(address, result) { try self.find($0, name) }
      default:
        guard let bytes = args["bytes"] as? FlutterStandardTypedData else {
          return result(badArguments(call))
        }
        // An entry saved just before the phone is locked still reaches the folder.
        var task = UIBackgroundTaskIdentifier.invalid
        let finish = {
          if task != .invalid { UIApplication.shared.endBackgroundTask(task) }
          task = .invalid
        }
        task = UIApplication.shared.beginBackgroundTask(withName: "Write to the folder", expirationHandler: finish)
        inFolder(address, { result($0); finish() }) {
          try self.write($0, name, bytes.data)
          return nil
        }
      }
    case "forget":
      guard let address = args["folder"] as? String else { return result(badArguments(call)) }
      // Only the folder named: a new pick has already taken the bookmark's place.
      if let url = held, same(url, address) { held = nil }
      background(result) {
        if let url = try? self.resolveKept(), self.same(url, address) {
          UserDefaults.standard.removeObject(forKey: self.bookmarkKey)
        }
        return nil
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pendingPick else { return }
    pendingPick = nil
    guard let url = urls.first else { return result(nil) }
    // Read and write: the phone's own entries will be written here too. The
    // answer is the bookmark's own URL, so it reads the same as "kept" will.
    background({ answer in
      if let address = answer as? String { self.held = URL(string: address) }
      result(answer)
    }) {
      let bookmark = try self.scoped(url) {
        try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
      }
      UserDefaults.standard.set(bookmark, forKey: self.bookmarkKey)
      return try self.resolveKept()?.absoluteString
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingPick?(nil)
    pendingPick = nil
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    pendingPick?(nil)
    pendingPick = nil
  }

  // The kept folder, its bookmark renewed when the system says it went stale
  // (the folder moved or was renamed); nil when none was kept. Off the UI
  // thread: a cloud provider may be slow to answer.
  private func resolveKept() throws -> URL? {
    guard let bookmark = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
    var stale = false
    let url = try URL(
      resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
    if stale, let fresh = try? scoped(url, {
      try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }) {
      UserDefaults.standard.set(fresh, forKey: bookmarkKey)
    }
    return url
  }

  // One folder however its address is written: iOS may give /private/var
  // for what was /var.
  private func same(_ url: URL, _ address: String) -> Bool {
    guard let other = URL(string: address) else { return false }
    return url.standardizedFileURL.resolvingSymlinksInPath().path
      == other.standardizedFileURL.resolvingSymlinksInPath().path
  }

  // Runs [work] on the folder an address names, with its right to be opened.
  private func inFolder(_ address: String, _ result: @escaping FlutterResult, _ work: @escaping (URL) throws -> Any?) {
    let known = held
    background(result) {
      if let known, self.same(known, address) { return try work(known) }
      guard let url = try self.resolveKept(), self.same(url, address) else {
        throw FolderError.notKept
      }
      DispatchQueue.main.async { self.held = url }
      return try work(url)
    }
  }

  // A cloud folder's provider may go to the network, so never on the UI thread.
  private func background(_ result: @escaping FlutterResult, _ work: @escaping () throws -> Any?) {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let value = try work()
        DispatchQueue.main.async { result(value) }
      } catch {
        let code = (error as? FolderError)?.code ?? "\(type(of: error))"
        DispatchQueue.main.async {
          result(FlutterError(code: code, message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func badArguments(_ call: FlutterMethodCall) -> FlutterError {
    FlutterError(code: "BadArguments", message: "\(call.method) needs folder, name and bytes", details: nil)
  }

  // The file and when it was changed, or nil when the folder has no such
  // file. A coordinated read makes the provider fetch a file not yet on the
  // phone, so it isn't looked for on disk first.
  private func read(_ folder: URL, _ name: String) throws -> [String: Any]? {
    let file = folder.appendingPathComponent(name)
    return try scoped(folder) {
      var out: Result<[String: Any], Error> = .failure(FolderError.notRead)
      var failure: NSError?
      NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: file, options: [], error: &failure) { url in
        out = Result {
          let bytes = try Data(contentsOf: url)
          let at = try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
          return ["bytes": FlutterStandardTypedData(bytes: bytes), "changed": at.map(milliseconds) ?? NSNull()]
        }
      }
      do {
        if let failure { throw failure }
        return try out.get()
      } catch where isMissing(error) {
        return nil
      }
    }
  }

  // The phone's own entries, for the computer: written over the file of
  // that name, or as a new file the first time.
  private func write(_ folder: URL, _ name: String, _ bytes: Data) throws {
    let file = folder.appendingPathComponent(name)
    try scoped(folder) {
      var out: Result<Void, Error> = .success(())
      var failure: NSError?
      NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: file, options: .forReplacing, error: &failure) { url in
        out = Result { try bytes.write(to: url, options: .atomic) }
      }
      if let failure { throw failure }
      try out.get()
    }
  }

  // When [name] in the folder was changed (milliseconds), from the listing
  // the provider has, without fetching the file; nil when it isn't there or
  // can't say. iCloud Drive may show a file not yet on the phone as
  // `.name.icloud`.
  private func find(_ folder: URL, _ name: String) throws -> Int64? {
    try scoped(folder) {
      var out: Result<Int64?, Error> = .success(nil)
      var failure: NSError?
      NSFileCoordinator(filePresenter: nil).coordinate(
        readingItemAt: folder, options: .immediatelyAvailableMetadataOnly, error: &failure
      ) { dir in
        out = Result {
          var file = dir.appendingPathComponent(name)
          guard FileManager.default.fileExists(atPath: file.path) else { return nil }
          file.removeAllCachedResourceValues()
          let at = try file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
          return at.map(milliseconds)
        }
      }
      if let failure { throw failure }
      return try out.get()
    }
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

private func milliseconds(_ date: Date) -> Int64 {
  Int64((date.timeIntervalSince1970 * 1000).rounded())
}

// No such file, however the provider words it.
private func isMissing(_ error: Error) -> Bool {
  let e = error as NSError
  if e.domain == NSCocoaErrorDomain && (e.code == NSFileReadNoSuchFileError || e.code == NSFileNoSuchFileError) {
    return true
  }
  if e.domain == NSPOSIXErrorDomain && e.code == Int(ENOENT) { return true }
  if let under = e.userInfo[NSUnderlyingErrorKey] as? Error { return isMissing(under) }
  return false
}

enum FolderError: Error {
  // An address that isn't the folder the phone keeps (it was given up).
  case notKept
  case notRead

  var code: String {
    switch self {
    case .notKept: return "NotKept"
    case .notRead: return "NotRead"
    }
  }
}
