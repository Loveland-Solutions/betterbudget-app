import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // The register is a dense desktop layout; below this it stops fitting.
    self.contentMinSize = NSSize(width: 1200, height: 760)
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

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
