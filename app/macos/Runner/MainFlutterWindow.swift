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

    // Title bar takes the Midnight ground so the window reads as one surface.
    // Kept (not full-size content) so native window dragging still works.
    self.appearance = NSAppearance(named: .darkAqua)
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.backgroundColor = NSColor(srgbRed: 6 / 255, green: 13 / 255, blue: 30 / 255, alpha: 1)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
