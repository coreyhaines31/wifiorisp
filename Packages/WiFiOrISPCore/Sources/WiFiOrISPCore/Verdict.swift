import Foundation

/// The answer to "is it my Wi-Fi or my ISP?" for the last minute or so.
///
/// "Your side" is everything up to and including your router: the Wi-Fi radio, the air,
/// and the router itself. "ISP side" is everything past the router.
public struct Verdict: Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case measuring
        case notConnected
        case good
        /// Works fine, but the signal is weak enough to cause trouble soon.
        case goodWeakSignal
        case weakSignal
        case localNetwork
        case isp
        case routerUnreachable
        case ispDown
        case offline
    }

    public enum Side: String, Sendable {
        case yours
        case isp
    }

    public var kind: Kind
    /// One line for the top of the menu, e.g. "Slow: ISP, not WiFi".
    public var headline: String
    /// A word or two for the menu bar, or nil when there's nothing wrong.
    public var short: String?
    /// The numbers behind the call, in a sentence or two.
    public var detail: String

    public var side: Side? {
        switch kind {
        case .weakSignal, .localNetwork, .routerUnreachable: .yours
        case .isp, .ispDown: .isp
        default: nil
        }
    }

    public var isProblem: Bool {
        switch kind {
        case .measuring, .good, .goodWeakSignal: false
        default: true
        }
    }
}

/// Turns recent samples into a verdict. All thresholds live here so they can be tested.
public enum VerdictEngine {
    /// How many recent samples the verdict looks at.
    public static let window = 6
    /// Samples older than this don't count, so a long sleep doesn't leave a stale verdict.
    public static let maxAge: TimeInterval = 180
    public static let minimumSamples = 3

    /// The router normally answers in a few ms over Wi-Fi. Slower than this is a problem on your side.
    public static let slowRouterMs = 40.0
    /// How much slower the internet can be than the router before it counts as the ISP's problem.
    public static let slowISPGapMs = 100.0
    /// Losing this share of probes counts as slow.
    public static let lossThreshold = 0.25

    public static let weakRSSI = -75
    public static let fairRSSI = -67
    public static let weakSNR = 15
    public static let fairSNR = 25

    public enum SignalQuality: Sendable {
        case good
        case fair
        case weak

        public init(rssi: Int, snr: Int) {
            if rssi <= VerdictEngine.weakRSSI || snr < VerdictEngine.weakSNR {
                self = .weak
            } else if rssi <= VerdictEngine.fairRSSI || snr < VerdictEngine.fairSNR {
                self = .fair
            } else {
                self = .good
            }
        }
    }

    /// The recent samples a verdict would look at, oldest first.
    public static func recent(_ samples: [Sample], now: Date) -> [Sample] {
        Array(samples.suffix(window).filter { now.timeIntervalSince($0.time) <= maxAge })
    }

    public static func evaluate(_ samples: [Sample], now: Date) -> Verdict {
        let recent = recent(samples, now: now)
        guard let last = recent.last else {
            return Verdict(kind: .measuring, headline: "Measuring…", short: nil, detail: "Taking the first readings.")
        }
        if last.link == .none {
            return Verdict(
                kind: .notConnected, headline: "Not connected", short: "Off",
                detail: "Your Mac isn't connected to Wi-Fi or a wired network."
            )
        }
        if let offline = offlineVerdict(recent) {
            return offline
        }
        guard recent.count >= minimumSamples else {
            return Verdict(kind: .measuring, headline: "Measuring…", short: nil, detail: "Taking the first readings.")
        }
        return slownessVerdict(Measurements(recent))
    }

    // MARK: - Offline

    private static func offlineVerdict(_ recent: [Sample]) -> Verdict? {
        let lastTwo = recent.suffix(2)
        guard lastTwo.count == 2, lastTwo.allSatisfy({ $0.internet?.isLost == true }) else { return nil }
        let wired = recent.last?.link == .wired
        switch recent.last?.router {
        case .lost:
            return Verdict(
                kind: .routerUnreachable, headline: "Offline: can't reach your router", short: "Router",
                detail: wired
                    ? "Your router stopped answering. Check the cable and that the router is on."
                    : "Your router stopped answering over Wi-Fi. Move closer, or restart the router."
            )
        case .reply:
            return Verdict(
                kind: .ispDown,
                headline: wired ? "Offline: ISP is down, not your network" : "Offline: ISP is down, WiFi is fine",
                short: "ISP",
                detail: "Your router answers, but nothing past it does. The outage is on your ISP's side "
                    + "(or between your router and modem)."
            )
        case nil:
            return Verdict(
                kind: .offline, headline: "Offline", short: "Offline",
                detail: "The internet isn't answering, and your router doesn't respond to probes, "
                    + "so the app can't tell which side is down."
            )
        }
    }

    // MARK: - Slowness

    struct Measurements {
        var link: Link
        var routerMeasured: Bool
        var routerMedian: Double?
        var routerLoss: Double
        var internetMedian: Double?
        var internetLoss: Double
        var signal: SignalQuality?
        var rssi: Int?
        var snr: Int?

        init(_ recent: [Sample]) {
            link = recent.last?.link ?? .none
            let routerProbes = recent.compactMap(\.router)
            let internetProbes = recent.compactMap(\.internet)
            routerMeasured = routerProbes.count >= VerdictEngine.minimumSamples
            routerMedian = Statistics.median(routerProbes.compactMap(\.ms))
            routerLoss = Self.loss(routerProbes)
            internetMedian = Statistics.median(internetProbes.compactMap(\.ms))
            internetLoss = Self.loss(internetProbes)

            let readings = link == .wifi ? recent.compactMap(\.wifi) : []
            if let rssi = Statistics.median(readings.map { Double($0.rssi) }),
               let snr = Statistics.median(readings.map { Double($0.snr) }) {
                self.rssi = Int(rssi.rounded())
                self.snr = Int(snr.rounded())
                signal = SignalQuality(rssi: Int(rssi.rounded()), snr: Int(snr.rounded()))
            }
        }

        static func loss(_ probes: [Probe]) -> Double {
            probes.isEmpty ? 0 : Double(probes.filter(\.isLost).count) / Double(probes.count)
        }

        var routerSlow: Bool {
            routerMeasured
                && (routerLoss >= VerdictEngine.lossThreshold || (routerMedian ?? 0) > VerdictEngine.slowRouterMs)
        }

        var ispSlow: Bool {
            let gap = (internetMedian ?? 0) - (routerMedian ?? 0)
            return internetLoss >= VerdictEngine.lossThreshold || gap > VerdictEngine.slowISPGapMs
        }

        /// "4 ms", plus how many checks went unanswered, if any.
        static func timing(_ ms: Double?, loss: Double) -> String {
            let time = ms.map { "\(Int($0.rounded())) ms" } ?? "no answer"
            return loss > 0 ? "\(time), missing \(Int((loss * 100).rounded()))% of checks" : time
        }

        var router: String { Self.timing(routerMedian, loss: routerLoss) }
        var internet: String { Self.timing(internetMedian, loss: internetLoss) }

        /// "excellent", "weak", and so on, for use mid-sentence.
        var signalWord: String {
            guard let rssi, let snr else { return "unknown" }
            return PlainLanguage.signal(rssi: rssi, snr: snr).lowercased()
        }
    }

    static func slownessVerdict(_ measured: Measurements) -> Verdict {
        let wifi = measured.link == .wifi
        if measured.routerSlow {
            return yourSideVerdict(measured)
        }
        if measured.ispSlow {
            return ispVerdict(measured)
        }
        if wifi && measured.signal == .weak {
            return Verdict(
                kind: .goodWeakSignal, headline: "Fine, but WiFi signal is weak", short: nil,
                detail: "Everything answers on time for now, but your Wi-Fi signal is weak enough to cause drops. "
                    + "Moving closer to the router helps."
            )
        }
        return Verdict(
            kind: .good,
            headline: wifi ? "Fine: WiFi and ISP both OK" : "Fine: network and ISP both OK", short: nil,
            detail: wifi
                ? "Your Wi-Fi signal is \(measured.signalWord), and your router and the internet both answer quickly."
                : "Your router and the internet both answer quickly."
        )
    }

    /// The router itself is slow: the problem is on your side of the line.
    private static func yourSideVerdict(_ measured: Measurements) -> Verdict {
        let wifi = measured.link == .wifi
        let router = "Your router takes \(measured.router) to answer, when it should take a few."
        if wifi && measured.signal == .weak {
            return Verdict(
                kind: .weakSignal, headline: "Slow: weak WiFi signal", short: "WiFi",
                detail: "\(router) Your Wi-Fi signal is weak, so move closer to the router or add an access point."
            )
        }
        return Verdict(
            kind: .localNetwork,
            headline: wifi ? "Slow: WiFi or router, not ISP" : "Slow: your router, not ISP",
            short: wifi ? "WiFi" : "Router",
            detail: "\(router) "
                + (wifi
                    ? "Your signal is \(measured.signalWord), so it's a busy channel, interference, or an "
                        + "overloaded router. Try restarting the router or changing its channel."
                    : "Try restarting it.")
        )
    }

    /// The router answers fine but the internet doesn't: the problem is past the router.
    private static func ispVerdict(_ measured: Measurements) -> Verdict {
        let wifi = measured.link == .wifi
        if !measured.routerMeasured && wifi && measured.signal == .weak {
            return Verdict(
                kind: .weakSignal, headline: "Slow: likely weak WiFi signal", short: "WiFi",
                detail: "The internet takes \(measured.internet) to answer and your Wi-Fi signal is weak. "
                    + "Your router doesn't answer checks, so the app can't tell for sure."
            )
        }
        let hedge = measured.routerMeasured ? "" : "likely "
        return Verdict(
            kind: .isp,
            headline: "Slow: \(hedge)ISP, not \(wifi ? "WiFi" : "your network")", short: "ISP",
            detail: measured.routerMeasured
                ? "Your router answers in \(measured.router), but the internet takes \(measured.internet). "
                    + "The delay is past your router: your ISP, or your modem."
                : "The internet takes \(measured.internet) to answer. Your router doesn't answer checks, "
                    + "but your Wi-Fi signal is \(measured.signalWord), so the delay is likely past it."
        )
    }
}
