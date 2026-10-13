import Cocoa
import FlutterMacOS
import IOKit

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // The register is a dense desktop layout; below this it stops fitting
    // (the header's key beside the forecast, and a payee column worth
    // reading). The same size as FitWindow.smallest: on a screen smaller
    // than this the window gets what there is and the app shrinks to fit.
    let fits = NSSize(width: 1360, height: 760)
    let room = (self.screen ?? NSScreen.main).map {
      self.contentRect(forFrameRect: $0.visibleFrame).size
    }
    self.contentMinSize = NSSize(
      width: min(fits.width, room?.width ?? fits.width),
      height: min(fits.height, room?.height ?? fits.height))
    self.setContentSize(NSSize(width: 1440, height: 900))
    self.center()
    self.title = "BetterBudget"

    // Title bar takes the page's ground so the window reads as one surface.
    // Kept (not full-size content) so native window dragging still works.
    self.appearance = NSAppearance(named: .darkAqua)
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.backgroundColor = NSColor(srgbRed: 13 / 255, green: 21 / 255, blue: 34 / 255, alpha: 1)

    // The app tells the title bar when it switches between light and dark
    // (Settings → Appearance): its ground color and whether it's dark.
    let look = FlutterMethodChannel(
      name: "betterbudget/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    look.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setLook",
        let args = call.arguments as? [String: Any],
        let dark = args["dark"] as? Bool,
        let argb = (args["ground"] as? NSNumber)?.uint32Value
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
      self?.backgroundColor = NSColor(
        srgbRed: CGFloat((argb >> 16) & 0xFF) / 255,
        green: CGFloat((argb >> 8) & 0xFF) / 255,
        blue: CGFloat(argb & 0xFF) / 255,
        alpha: 1)
      result(nil)
    }

    // The folder the ledger is kept in (Settings → Backups). The sandbox
    // forgets a folder the user picked when the app quits, so the app keeps a
    // security-scoped bookmark for it and opens that at the next launch.
    let folder = FlutterMethodChannel(
      name: "betterbudget/folder",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    folder.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "remember":
        guard let path = args?["path"] as? String else {
          result(FlutterMethodNotImplemented)
          return
        }
        do {
          let data = try URL(fileURLWithPath: path, isDirectory: true).bookmarkData(
            options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
          result(data.base64EncodedString())
        } catch {
          result(FlutterError(code: "bookmark", message: error.localizedDescription, details: nil))
        }
      case "open":
        guard let token = args?["token"] as? String,
          let data = Data(base64Encoded: token)
        else {
          result(FlutterMethodNotImplemented)
          return
        }
        var stale = false
        guard
          let url = try? URL(
            resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil,
            bookmarkDataIsStale: &stale),
          url.startAccessingSecurityScopedResource()
        else {
          result(nil)
          return
        }
        // A stale bookmark still opened the folder; a fresh one is kept so
        // it goes on opening.
        var renewed: String? = nil
        if stale {
          renewed = try? url.bookmarkData(
            options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil
          ).base64EncodedString()
        }
        result(["path": url.path, "token": renewed as Any])
      case "machineId":
        // The Mac's own id, the same for every account on it: so a row made
        // under another account of this Mac can be told from one made on
        // another Mac. The app hashes it; it is never stored as it is.
        let service = IOServiceGetMatchingService(
          kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { if service != 0 { IOObjectRelease(service) } }
        if service != 0,
          let uuid = IORegistryEntryCreateCFProperty(
            service, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String
        {
          result(uuid)
        } else {
          result(nil)
        }
      case "accountId":
        // This macOS account, so two accounts of one Mac are two computers.
        result(String(getuid()))
      case "computerName":
        // What the owner called this Mac ("Tom's MacBook Air"): written in
        // the ledger so another computer can say whose changes it opened.
        result(Host.current().localizedName)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
