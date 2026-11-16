import AppKit
import WiFiOrISPCore

/// The menu bar glyph: two small meters, your router on the left and the internet on the right.
/// Geometry matches mac-app-kit `Scripts/glyphs/glyphs.mjs` (`wifi`), drawn in code so the needles
/// can follow the live readings. Needles stand high when a side is quick and drop when it's slow.
enum TwinMeterGlyph {
    /// Needle positions, 0 (left stop, slow) to 1 (right stop, quick).
    struct Needles: Equatable {
        var router: Double
        var internet: Double
        /// Not connected: both needles at rest and the meters struck through.
        var offline = false
    }

    /// The glyph's `good` state.
    static let good = Needles(router: 0.8, internet: 0.75)
    /// The glyph's `offline` state.
    static let offline = Needles(router: 0, internet: 0, offline: true)

    /// Where a needle sits for a reading. 0 ms is near the top, 200 ms or more near the bottom.
    static func needle(_ probe: Probe?) -> Double {
        switch probe {
        case .reply(let ms): 0.85 - 0.75 * min(max(ms, 0), 200) / 200
        case .lost: 0.05
        case nil: 0.5
        }
    }

    /// The highest a needle can sit when that side is the problem.
    static let problemCeiling = 0.15

    /// Needles for the current verdict. A weak Wi-Fi signal lowers the router needle, the way the
    /// old router's LEDs went out, and the side the verdict blames always reads low.
    static func needles(for verdict: Verdict, latest: Sample?) -> Needles {
        if verdict.kind == .notConnected { return offline }
        var router = needle(latest?.router)
        var internet = needle(latest?.internet)
        if latest?.link == .wifi, let wifi = latest?.wifi {
            router = min(router, 0.1 + 0.75 * PlainLanguage.signalStrength(rssi: wifi.rssi))
        }
        if verdict.isProblem {
            switch verdict.side {
            case .yours: router = min(router, problemCeiling)
            case .isp: internet = min(internet, problemCeiling)
            case nil:
                router = min(router, problemCeiling)
                internet = min(internet, problemCeiling)
            }
        }
        return Needles(router: router, internet: internet)
    }

    /// The menu bar image, as a template so it follows the menu bar's colour.
    static func menuBarImage(_ needles: Needles) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            draw(needles)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func draw(_ needles: Needles) {
        NSColor.black.set()
        meter(x: 0.75, value: needles.router)
        meter(x: 9.75, value: needles.internet)

        if needles.offline {
            let slash = NSBezierPath()
            slash.move(to: NSPoint(x: 1.5, y: 16.8))
            slash.line(to: NSPoint(x: 16.5, y: 1.2))
            slash.lineCapStyle = .round
            // Cut a gap around the slash so it reads against the meters.
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            slash.lineWidth = 3.4
            slash.stroke()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            slash.lineWidth = 1.4
            slash.stroke()
        }
    }

    /// One meter window, 7.5 x 10 pt at (x, 4), with its needle and pivot.
    private static func meter(x: Double, value: Double) {
        let y = 4.0, width = 7.5, height = 10.0
        let frame = NSRect(x: x, y: y, width: width, height: height)
        let window = NSBezierPath(roundedRect: frame, xRadius: 1.8, yRadius: 1.8)
        window.lineWidth = 1.5
        window.stroke()

        let pivot = NSPoint(x: x + width / 2, y: y + height - 1.6)
        let radius = height - 3.6 + 0.4
        let degrees = -48 + min(max(value, 0), 1) * 96
        let angle = (degrees - 90) * .pi / 180
        let needle = NSBezierPath()
        needle.move(to: pivot)
        needle.line(to: NSPoint(x: pivot.x + radius * cos(angle), y: pivot.y + radius * sin(angle)))
        needle.lineWidth = 1.1
        needle.lineCapStyle = .round
        needle.stroke()

        let dot = 0.94
        NSBezierPath(ovalIn: NSRect(x: pivot.x - dot, y: pivot.y - dot, width: dot * 2, height: dot * 2)).fill()
    }
}
