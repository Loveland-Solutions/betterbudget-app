// Makes the macOS app icon: the logo on a white tile, upright and sized to fit
// (owner's drawing, 2026-10-08; before that the bee, tilted 45°).
//   rsvg-convert -h 1024 assets/logo/prepared/logo.svg -o mark.png
//   swift design/icon/app_icon.swift mark.png app_icon_1024.png 0 110
// Then `sips -z N N` it to 16…512 into app/macos/Runner/Assets.xcassets/AppIcon.appiconset.
// Arguments: mark PNG, output PNG, angle in degrees (negative = clockwise), margin in px.
import AppKit
let a = CommandLine.arguments
let mark = NSImage(contentsOfFile: a[1])!
let angle = Double(a[3])!   // degrees, negative = clockwise
let margin = Double(a[4])!  // gap kept between the logo and the tile edge
let aspect = Double(mark.size.width / mark.size.height)  // the logo is taller than wide
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let radius = 185.0

func render(_ side: Double, _ dx: Double, _ dy: Double, tile: Bool) -> NSBitmapImageRep {
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  let path = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)
  if tile {
    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow(); sh.shadowColor = NSColor.black.withAlphaComponent(0.28)
    sh.shadowBlurRadius = 24; sh.shadowOffset = NSSize(width: 0, height: -10); sh.set()
    NSColor.white.setFill(); path.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor.black.withAlphaComponent(0.06).setStroke(); path.lineWidth = 2; path.stroke()
  }
  let t = NSAffineTransform()
  t.translateX(by: 512 + dx, yBy: 512 + dy)
  t.rotate(byDegrees: angle)
  t.concat()
  mark.draw(in: NSRect(x: -side * aspect / 2, y: -side / 2, width: side * aspect, height: side))
  NSGraphicsContext.restoreGraphicsState()
  return rep
}
// Opaque pixels of the logo alone.
func opaque(_ rep: NSBitmapImageRep) -> [(Double, Double)] {
  var pts: [(Double, Double)] = []
  let p = rep.bitmapData!, bpr = rep.bytesPerRow
  for y in 0..<1024 { for x in 0..<1024 where p[y * bpr + x * 4 + 3] > 40 { pts.append((Double(x) + 0.5, 1024 - Double(y) - 0.5)) } }
  return pts
}
// Inside the tile shrunk by the margin (rounded rect test).
func inside(_ x: Double, _ y: Double) -> Bool {
  let r = max(radius - margin, 1), lo = 100 + margin, hi = 924 - margin
  if x < lo || x > hi || y < lo || y > hi { return false }
  let cx = min(max(x, lo + r), hi - r), cy = min(max(y, lo + r), hi - r)
  return (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r
}
// Center on the logo's own bounding box, then grow until it touches the margin.
let probe = opaque(render(600, 0, 0, tile: false))
let xs = probe.map { $0.0 }, ys = probe.map { $0.1 }
let ox = 512 - (xs.min()! + xs.max()!) / 2, oy = 512 - (ys.min()! + ys.max()!) / 2
var best = 600.0
var side = 600.0
while side < 1400 {
  let k = side / 600
  let pts = opaque(render(side, ox * k, oy * k, tile: false))
  if !pts.allSatisfy({ inside($0.0, $0.1) }) { break }
  best = side; side += 10
}
let k = best / 600
let out = render(best, ox * k, oy * k, tile: true)
try! out.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[2]))
print("logo drawn \(Int(best))px tall")
