import Foundation

/// How often to sample. Fast while something is wrong, slower the longer things stay fine,
/// and exponential backoff for CoreWLAN when it stops answering, so the app never adds to an
/// airportd request storm (the bug that hit Stats on macOS 27).
public struct PollPolicy: Sendable {
    /// Never sample faster than this, whatever happens.
    public static let fastest: TimeInterval = 5
    public static let normal: TimeInterval = 10
    public static let relaxed: TimeInterval = 20
    public static let slowest: TimeInterval = 30
    /// CoreWLAN backoff tops out here.
    public static let maxWiFiBackoff: TimeInterval = 300

    private var calmSince: Date?
    private var wifiFailures = 0
    public private(set) var nextWiFiRead: Date = .distantPast

    public init() {}

    /// Call after each sample with its verdict; returns how long to wait before the next one.
    public mutating func interval(after verdict: Verdict, now: Date) -> TimeInterval {
        guard !verdict.isProblem && verdict.kind != .measuring else {
            calmSince = nil
            return Self.fastest
        }
        let calmFor = now.timeIntervalSince(calmSince ?? now)
        if calmSince == nil {
            calmSince = now
        }
        switch calmFor {
        case ..<120: return Self.normal
        case ..<600: return Self.relaxed
        default: return Self.slowest
        }
    }

    /// Something changed (network, access point, wake): sample at the normal pace again.
    public mutating func reset() {
        calmSince = nil
    }

    public func shouldReadWiFi(now: Date) -> Bool {
        now >= nextWiFiRead
    }

    public mutating func wifiRead(succeeded: Bool, now: Date) {
        if succeeded {
            wifiFailures = 0
            nextWiFiRead = .distantPast
        } else {
            wifiFailures += 1
            nextWiFiRead = now.addingTimeInterval(wifiBackoff)
        }
    }

    /// 10, 20, 40… seconds, capped at five minutes.
    public var wifiBackoff: TimeInterval {
        guard wifiFailures > 0 else { return 0 }
        return min(Self.maxWiFiBackoff, Self.normal * pow(2, Double(wifiFailures - 1)))
    }
}
