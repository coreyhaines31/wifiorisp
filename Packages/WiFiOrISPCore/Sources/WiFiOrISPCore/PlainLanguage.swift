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

    /// A router on the same network should answer in a few ms.
    public static func router(_ ms: Double) -> Speed {
        switch ms {
        case ...15: .fast
        case ...VerdictEngine.slowRouterMs: .okay
        default: .slow
        }
    }

    /// The internet is farther away, so it gets more room.
    public static func internet(_ ms: Double) -> Speed {
        switch ms {
        case ...60: .fast
        case ...120: .okay
        default: .slow
        }
    }
}
