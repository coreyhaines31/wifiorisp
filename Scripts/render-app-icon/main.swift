// Renders the app icon set: Wi-Fi arcs where the inner arcs (your side) are white and the
// outer arc (the ISP's side) is amber.
// Usage (from the repo root):
//   swiftc Scripts/render-app-icon/main.swift -o /tmp/render-icon && /tmp/render-icon
import AppKit

let outputDirectory = URL(filePath: "WiFiOrISP/Assets.xcassets/AppIcon.appiconset")

func arc(center: NSPoint, radius: CGFloat, width: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    path.appendArc(withCenter: center, radius: radius, startAngle: 45, endAngle: 135)
    path.lineWidth = width
    path.lineCapStyle = .round
    return path
}

func render(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let size = CGFloat(pixels)
    let canvas = NSRect(x: 0, y: 0, width: size, height: size)

    // macOS icon grid: the rounded square fills 824/1024 of the canvas.
    let plate = canvas.insetBy(dx: size * 100 / 1024, dy: size * 100 / 1024)
    let plateShape = NSBezierPath(roundedRect: plate, xRadius: plate.width * 0.2237, yRadius: plate.height * 0.2237)
    NSGradient(colors: [
        NSColor(red: 0.13, green: 0.25, blue: 0.55, alpha: 1),
        NSColor(red: 0.04, green: 0.08, blue: 0.20, alpha: 1)
    ])!.draw(in: plateShape, angle: -90)

    let unit = plate.width
    let center = NSPoint(x: plate.midX, y: plate.minY + unit * 0.22)
    let stroke = unit * 0.085
    let white = NSColor(white: 1, alpha: 1)
    let amber = NSColor(red: 1.0, green: 0.68, blue: 0.22, alpha: 1)

    white.setFill()
    let dotRadius = unit * 0.06
    NSBezierPath(ovalIn: NSRect(x: center.x - dotRadius, y: center.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)).fill()
    white.setStroke()
    arc(center: center, radius: unit * 0.22, width: stroke).stroke()
    arc(center: center, radius: unit * 0.38, width: stroke).stroke()
    amber.setStroke()
    arc(center: center, radius: unit * 0.54, width: stroke).stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let sizes: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)
]
var images: [[String: String]] = []
for entry in sizes {
    let name = "icon_\(entry.points)x\(entry.points)@\(entry.scale)x.png"
    try! render(entry.points * entry.scale).write(to: outputDirectory.appending(path: name))
    images.append(["filename": name, "idiom": "mac", "scale": "\(entry.scale)x", "size": "\(entry.points)x\(entry.points)"])
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try! json.write(to: outputDirectory.appending(path: "Contents.json"))
print("Wrote \(images.count) icons to \(outputDirectory.path)")
