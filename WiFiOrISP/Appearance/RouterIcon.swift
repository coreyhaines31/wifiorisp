import AppKit

/// The router drawn for the menu bar and the app icon. Drawn in code so it looks like a router,
/// not the system's own Wi-Fi glyph sitting next to it.
enum RouterIcon {
    /// What the menu bar router shows.
    enum Lights: Equatable {
        /// 0 to 3 lit LEDs, for signal strength.
        case bars(Int)
        /// LEDs off: something is wrong (the menu bar text says what).
        case dark
        /// Not connected: the router is struck through.
        case off
    }

    /// The menu bar image, as a template so it follows the menu bar's color.
    static func menuBarImage(_ lights: Lights) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            drawMenuBar(lights)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Converts a 0...1 signal strength to lit LEDs.
    static func bars(strength: Double) -> Int {
        Int((min(max(strength, 0), 1) * 3).rounded(.up))
    }

    private static func drawMenuBar(_ lights: Lights) {
        NSColor.black.set()
        let body = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 3, width: 15, height: 6.5), xRadius: 2, yRadius: 2)
        body.lineWidth = 1.5
        body.stroke()

        for (bottom, top) in [(NSPoint(x: 4.5, y: 9.5), NSPoint(x: 3.5, y: 16.5)),
                              (NSPoint(x: 13.5, y: 9.5), NSPoint(x: 14.5, y: 16.5))] {
            let antenna = NSBezierPath()
            antenna.move(to: bottom)
            antenna.line(to: top)
            antenna.lineWidth = 1.5
            antenna.lineCapStyle = .round
            antenna.stroke()
        }

        if case .bars(let lit) = lights {
            for index in 0..<min(lit, 3) {
                dot(at: NSPoint(x: 5.5 + Double(index) * 3.5, y: 6.25), radius: 1.1).fill()
            }
        }

        if lights == .off {
            let slash = NSBezierPath()
            slash.move(to: NSPoint(x: 2, y: 17))
            slash.line(to: NSPoint(x: 16, y: 1))
            slash.lineCapStyle = .round
            // Cut a gap around the slash so it reads against the router.
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            slash.lineWidth = 3.5
            slash.stroke()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            slash.lineWidth = 1.5
            slash.stroke()
        }
    }

    /// The app icon's router, drawn into `plate` (the rounded square), white with amber details.
    static func drawAppIcon(in plate: NSRect) {
        let unit = plate.width
        func point(_ x: Double, _ y: Double) -> NSPoint {
            NSPoint(x: plate.minX + unit * x, y: plate.minY + unit * y)
        }
        let white = NSColor.white
        let amber = NSColor(red: 1.0, green: 0.68, blue: 0.22, alpha: 1)

        // Signal waves rising from the router, between the antennas.
        amber.setStroke()
        for radius in [0.13, 0.22] {
            let wave = NSBezierPath()
            wave.appendArc(withCenter: point(0.5, 0.47), radius: unit * radius, startAngle: 50, endAngle: 130)
            wave.lineWidth = unit * 0.045
            wave.lineCapStyle = .round
            wave.stroke()
        }

        white.setStroke()
        white.setFill()
        for (bottom, top) in [((0.29, 0.44), (0.24, 0.80)), ((0.71, 0.44), (0.76, 0.80))] {
            let antenna = NSBezierPath()
            antenna.move(to: point(bottom.0, bottom.1))
            antenna.line(to: point(top.0, top.1))
            antenna.lineWidth = unit * 0.05
            antenna.lineCapStyle = .round
            antenna.stroke()
            dot(at: point(top.0, top.1), radius: unit * 0.04).fill()
        }

        let bodyRect = NSRect(origin: point(0.17, 0.24), size: NSSize(width: unit * 0.66, height: unit * 0.22))
        NSBezierPath(roundedRect: bodyRect, xRadius: unit * 0.06, yRadius: unit * 0.06).fill()

        amber.setFill()
        for index in 0..<3 {
            dot(at: point(0.31 + Double(index) * 0.09, 0.35), radius: unit * 0.028).fill()
        }
    }

    private static func dot(at center: NSPoint, radius: CGFloat) -> NSBezierPath {
        NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}
