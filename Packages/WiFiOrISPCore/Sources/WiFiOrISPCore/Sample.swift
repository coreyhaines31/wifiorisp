import Foundation

/// One timed round trip: a reply after some milliseconds, or nothing before the timeout.
public enum Probe: Equatable, Sendable {
    case reply(ms: Double)
    case lost

    public var ms: Double? {
        if case .reply(let ms) = self { ms } else { nil }
    }

    public var isLost: Bool { self == .lost }
}

extension Probe: Codable {
    // Stored as a bare number to keep the log small: milliseconds, or -1 when lost.
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(Double.self)
        self = value < 0 ? .lost : .reply(ms: value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(ms.map { ($0 * 10).rounded() / 10 } ?? -1)
    }
}

public enum Band: String, Codable, Sendable, CaseIterable {
    case ghz2 = "2.4"
    case ghz5 = "5"
    case ghz6 = "6"

    public var label: String { "\(rawValue) GHz" }
}

/// What CoreWLAN reports about the current Wi-Fi association.
public struct WiFiReading: Codable, Equatable, Sendable {
    /// Signal strength in dBm (−30 is excellent, −80 is barely usable).
    public var rssi: Int
    /// Background noise in dBm.
    public var noise: Int
    /// The rate the Mac is currently sending at, in Mbps.
    public var txRate: Double
    public var channel: Int?
    public var band: Band?
    /// Only available with Location access.
    public var ssid: String?
    /// The access point's MAC address. Only available with Location access.
    public var bssid: String?
    /// The Wi-Fi generation of the connection, which is the lower of the Mac's and the router's.
    public var generation: WiFiGeneration?
    /// Channel width in MHz.
    public var widthMHz: Int?

    public init(
        rssi: Int, noise: Int, txRate: Double, channel: Int? = nil, band: Band? = nil,
        ssid: String? = nil, bssid: String? = nil, generation: WiFiGeneration? = nil, widthMHz: Int? = nil
    ) {
        self.rssi = rssi
        self.noise = noise
        self.txRate = txRate
        self.channel = channel
        self.band = band
        self.ssid = ssid
        self.bssid = bssid
        self.generation = generation
        self.widthMHz = widthMHz
    }

    /// Signal-to-noise ratio in dB. Above 25 is good, below 15 is poor.
    public var snr: Int { rssi - noise }
}

/// Wi-Fi generations by their marketing names. Wi-Fi 6E is Wi-Fi 6 on the 6 GHz band.
public enum WiFiGeneration: Int, Codable, Sendable, Comparable {
    case legacy = 3
    case wifi4 = 4
    case wifi5 = 5
    case wifi6 = 6
    case wifi7 = 7

    public var label: String {
        self == .legacy ? "older than Wi-Fi 4" : "Wi-Fi \(rawValue)"
    }

    public static func < (lhs: WiFiGeneration, rhs: WiFiGeneration) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum Link: String, Codable, Sendable {
    case wifi
    case wired
    /// No network interface with a route out.
    case none
}

/// Everything measured at one moment. Router and internet are probed at the same time,
/// so the two latencies are directly comparable.
public struct Sample: Codable, Equatable, Sendable {
    public var time: Date
    public var link: Link
    public var wifi: WiFiReading?
    /// Nil when the router couldn't be measured (no gateway, or it ignores probes).
    public var router: Probe?
    public var internet: Probe?

    public init(time: Date, link: Link, wifi: WiFiReading? = nil, router: Probe? = nil, internet: Probe? = nil) {
        self.time = time
        self.link = link
        self.wifi = wifi
        self.router = router
        self.internet = internet
    }

    private enum CodingKeys: String, CodingKey {
        case time = "t"
        case link
        case wifi
        case router = "r"
        case internet = "i"
    }
}
