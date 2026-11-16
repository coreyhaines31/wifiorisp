import Foundation

/// Words for numbers most people have never had to read, like dBm and milliseconds.
public enum PlainLanguage {
    public enum Speed: String, Sendable {
        case fast = "Fast"
        case okay = "OK"
        case slow = "Slow"
    }

    /// Excellent, Good, Fair, or Weak, from signal strength and how far it rises above the noise.
    public static func signal(rssi: Int, snr: Int) -> String {
        switch VerdictEngine.SignalQuality(rssi: rssi, snr: snr) {
        case .good: rssi >= -55 ? "Excellent" : "Good"
        case .fair: "Fair"
        case .weak: "Weak"
        }
    }

    /// How full the Wi-Fi icon's bars should be, 0...1. −90 dBm is empty, −50 dBm and stronger is full.
    public static func signalStrength(rssi: Int) -> Double {
        min(1, max(0, Double(rssi + 90) / 40))
    }

    /// A router answering this fast or faster reads as Fast.
    public static let fastRouterMs = 15.0
    /// An internet round trip this fast or faster reads as Fast.
    public static let fastInternetMs = 60.0
    /// An internet round trip slower than this reads as Slow.
    public static let slowInternetMs = 120.0

    /// A router on the same network should answer in a few ms.
    public static func router(_ ms: Double) -> Speed {
        switch ms {
        case ...fastRouterMs: .fast
        case ...VerdictEngine.slowRouterMs: .okay
        default: .slow
        }
    }

    /// The internet is farther away, so it gets more room.
    public static func internet(_ ms: Double) -> Speed {
        switch ms {
        case ...fastInternetMs: .fast
        case ...slowInternetMs: .okay
        default: .slow
        }
    }
}
