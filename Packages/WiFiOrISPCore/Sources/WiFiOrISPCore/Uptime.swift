import Darwin
import Foundation

/// How long the Mac has been awake since its last restart, against the macOS 26 TCP clock freeze.
///
/// The kernel's TCP clock, `tcp_now`, counts milliseconds of awake time in 32 bits. In macOS 26
/// (xnu-12377) `calculate_tcp_clock()` only lets it move forward, so when the count wraps after
/// 2^32 ms (about 49.7 days) the clock stops. Closed connections then never expire, the Mac runs
/// out of ports, and new connections fail while existing ones and ping keep working, until a
/// restart. macOS 15 and earlier count up a different way and keep ticking. The clock runs on
/// `mach_absolute_time`, which stops during sleep, so sleep doesn't count toward the limit.
/// https://photon.codes/blog/we-found-a-ticking-time-bomb-in-macos-tcp-networking
public struct UptimeCheck: Equatable, Sendable {
    public enum Stage: String, Codable, Sendable {
        case fine
        /// Within `headsUp` of the limit.
        case approaching
        /// Past the limit: new connections may be failing.
        case past
    }

    /// 2^32 milliseconds.
    public static let freezeAfter: TimeInterval = 4_294_967.296
    public static let headsUp: TimeInterval = 5 * 86400
    public static let firstAffectedMajor = 26

    /// Seconds awake since the last restart.
    public var awake: TimeInterval
    /// Whether this version of macOS has the frozen clock.
    public var affectedOS: Bool

    public init(awake: TimeInterval, osMajor: Int) {
        self.awake = awake
        affectedOS = osMajor >= Self.firstAffectedMajor
    }

    /// This Mac, now. `CLOCK_UPTIME_RAW` is the clock the kernel's TCP clock is built on.
    public static func current() -> UptimeCheck {
        UptimeCheck(
            awake: Double(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) / 1e9,
            osMajor: ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        )
    }

    public var stage: Stage {
        guard affectedOS else { return .fine }
        if awake >= Self.freezeAfter { return .past }
        if awake >= Self.freezeAfter - Self.headsUp { return .approaching }
        return .fine
    }

    public var days: Int { Int(awake / 86400) }

    /// "52 days", "1 day", or "less than a day".
    public var daysText: String {
        switch days {
        case 0: "less than a day"
        case 1: "1 day"
        default: "\(days) days"
        }
    }
}

/// What the popover says about uptime, when there's something to say.
public struct UptimeNotice: Equatable, Sendable {
    public enum Tone: String, Sendable {
        /// Past the limit while the connection is failing: likely the cause.
        case cause
        /// Past the limit, but everything answers.
        case warning
        /// A few days before the limit.
        case headsUp
    }

    public var tone: Tone
    public var headline: String
    public var detail: String
    /// The guide on wifiorisp.com.
    public static let guide = "/mac-internet-stops-working-after-weeks"
}

extension Advice {
    /// Verdicts a frozen TCP clock could explain: probes that fail or time out. A weak signal is its own thing.
    static func uptimeCouldExplain(_ verdict: Verdict) -> Bool {
        switch verdict.kind {
        case .localNetwork, .routerUnreachable, .offline, .isp, .ispDown: true
        default: false
        }
    }

    public static func uptimeNotice(_ context: AdviceContext) -> UptimeNotice? {
        guard let uptime = context.uptime else { return nil }
        let running = "Your Mac has been on for \(uptime.daysText) without a restart (sleep doesn't count)."
        let limit = "After about 49.7 days, macOS 26 can stop opening new connections"
        switch uptime.stage {
        case .fine:
            return nil
        case .approaching:
            return UptimeNotice(
                tone: .headsUp, headline: "Restart your Mac this week",
                detail: "\(running) \(limit) until you restart. Restart before then and it won't happen."
            )
        case .past where uptimeCouldExplain(context.verdict):
            return UptimeNotice(
                tone: .cause, headline: "Restart your Mac first",
                detail: "\(running) \(limit), which looks just like bad Wi-Fi or a bad ISP. A restart fixes it."
            )
        case .past:
            return UptimeNotice(
                tone: .warning, headline: "Time to restart your Mac",
                detail: "\(running) \(limit). Everything answers right now. If apps start timing out, "
                    + "restart before blaming your Wi-Fi or ISP."
            )
        }
    }
}
