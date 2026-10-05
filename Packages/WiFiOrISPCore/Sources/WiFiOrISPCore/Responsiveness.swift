import Foundation
import Network

/// Lag under load, in round trips per minute (RPM), following the IETF draft
/// "Responsiveness under Working Conditions" (draft-ietf-ippm-responsiveness).
public struct ResponsivenessResult: Codable, Equatable, Sendable {
    public var time: Date
    public var rpm: Int
    /// One round trip on an idle connection, measured the same way as under load.
    public var idleLatencyMs: Double
    /// One round trip while the connection is saturated (60000 / RPM).
    public var loadedLatencyMs: Double
    public var routerIdleMs: Double?
    public var routerLoadedMs: Double?
    /// TCP handshakes to the internet (the same probe the background monitor uses).
    public var internetIdleMs: Double?
    public var internetLoadedMs: Double?
    public var downloadMbps: Double
    public var uploadMbps: Double
    public var server: String

    public enum Grade: String, Sendable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
    }

    public var grade: Grade {
        switch rpm {
        case ..<300: .low
        case ..<1000: .medium
        default: .high
        }
    }

    public var addedLatencyMs: Double { max(0, loadedLatencyMs - idleLatencyMs) }

    public var routerAddedMs: Double? {
        guard let routerIdleMs, let routerLoadedMs else { return nil }
        return max(0, routerLoadedMs - routerIdleMs)
    }

    public var internetAddedMs: Double? {
        guard let internetIdleMs, let internetLoadedMs else { return nil }
        return max(0, internetLoadedMs - internetIdleMs)
    }

    /// Where the queue builds up. Packets to the internet pass through the router, so if the
    /// router's own answers slow down as much as the internet's, the queue is on your side.
    /// A router that slows down far more than the internet is just busy answering, which
    /// doesn't delay the traffic it forwards, so that alone doesn't count.
    public enum QueueLocation: Sendable {
        case yourSide
        case pastRouter
        case unknown
    }

    public var queueLocation: QueueLocation {
        guard let routerAddedMs, let internetAddedMs, internetAddedMs >= 20 else { return .unknown }
        return min(routerAddedMs, internetAddedMs) >= internetAddedMs / 2 ? .yourSide : .pastRouter
    }

    /// Where the lag comes from, using the router and internet probes taken during the test.
    public var headline: String {
        if grade == .high { return "Low lag under load" }
        switch queueLocation {
        case .yourSide: return "Lags under load: WiFi or router queue"
        case .pastRouter: return "Lags under load: past your router (bufferbloat)"
        case .unknown: return "Lags under load"
        }
    }

    public var detail: String {
        let added = "Under load, each round trip took \(Int(loadedLatencyMs.rounded())) ms instead of "
            + "\(Int(idleLatencyMs.rounded())) ms."
        if grade == .high {
            return "\(added) Video calls and games should stay smooth while something downloads."
        }
        guard let routerIdleMs, let routerLoadedMs, let internetIdleMs, let internetLoadedMs else {
            return "\(added) Your router doesn't answer probes, so the app can't tell where the queue is."
        }
        let probes = "Router \(Int(routerIdleMs.rounded())) → \(Int(routerLoadedMs.rounded())) ms, "
            + "internet \(Int(internetIdleMs.rounded())) → \(Int(internetLoadedMs.rounded())) ms."
        switch queueLocation {
        case .yourSide:
            return "\(added) \(probes) The delay builds up between your Mac and the router: a busy Wi-Fi channel, "
                + "or the router's own buffers. A less crowded channel, or Smart Queue Management (SQM) "
                + "on the router, usually helps."
        case .pastRouter:
            return "\(added) \(probes) Your router stayed quick, so the queue is past it: "
                + "in your modem or at your ISP. "
                + "Turning on Smart Queue Management (SQM) or QoS on your router usually fixes this. If it can't, "
                + "send this result to your ISP."
        case .unknown:
            return "\(added) \(probes)"
        }
    }
}

public enum ResponsivenessPhase: String, Sendable {
    case idle = "Measuring idle latency"
    case loaded = "Saturating your connection"
}

public enum ResponsivenessError: LocalizedError {
    case badConfig
    case noProbes

    public var errorDescription: String? {
        switch self {
        case .badConfig: "The responsiveness server's configuration couldn't be read."
        case .noProbes: "No latency probes finished. The connection may have dropped during the test."
        }
    }
}

public final class ResponsivenessTest: Sendable {
    /// Cloudflare publishes an IETF responsiveness server for anyone to use.
    public static let defaultConfigURL = URL(string: "https://aim.cloudflare.com/responsiveness/api/v1/config")!

    static let phaseDuration: TimeInterval = 14
    /// Probes from the first seconds, while flows ramp up, don't count.
    static let rampUp: TimeInterval = 4
    static let initialFlows = 8
    static let maxFlows = 16
    static let probeInterval: TimeInterval = 0.2
    static let routerProbeInterval: TimeInterval = 0.5
    static let idleProbes = 5

    private let configURL: URL
    private let routerProbe: @Sendable () async -> Probe?

    /// - Parameter routerProbe: times one round trip to the router, or returns nil if it can't be measured.
    public init(configURL: URL = defaultConfigURL, routerProbe: @escaping @Sendable () async -> Probe?) {
        self.configURL = configURL
        self.routerProbe = routerProbe
    }

    /// Router and internet together, like the background monitor.
    private func pairedProbe() async -> (router: Double?, internet: Double?) {
        async let router = routerProbe()
        async let internet = Sampler.probeInternet()
        return await (router?.ms, internet.ms)
    }

    public func run(
        progress: @escaping @Sendable (ResponsivenessPhase, Double) -> Void
    ) async throws -> ResponsivenessResult {
        let config = try await Config.load(configURL)
        let total = 1 + Self.phaseDuration

        progress(.idle, 0)
        var idle: [ProbeTiming] = []
        var routerIdle: [Double] = []
        var internetIdle: [Double] = []
        for _ in 0..<Self.idleProbes {
            async let timing = Self.foreignProbe(config.small)
            async let paired = pairedProbe()
            if let timing = await timing { idle.append(timing) }
            let (router, internet) = await paired
            if let router { routerIdle.append(router) }
            if let internet { internetIdle.append(internet) }
        }

        // Download and upload at the same time, like a video call during a backup.
        let phase = await runLoaded(config: config) { progress(.loaded, (1 + $0) / total) }
        let loaded = phase.probes
        guard let rpm = Self.rpm(foreign: loaded.foreign, selfHTTP: loaded.selfHTTP),
              let idleLatency = Self.roundTripMs(idle, trimmed: false)
        else { throw ResponsivenessError.noProbes }

        return ResponsivenessResult(
            time: Date(),
            rpm: Int(rpm.rounded()),
            idleLatencyMs: idleLatency,
            loadedLatencyMs: 60000 / rpm,
            routerIdleMs: Statistics.median(routerIdle),
            routerLoadedMs: Statistics.median(loaded.router),
            internetIdleMs: Statistics.median(internetIdle),
            internetLoadedMs: Statistics.median(loaded.internet),
            downloadMbps: phase.downloadMbps,
            uploadMbps: phase.uploadMbps,
            server: config.server
        )
    }

    // MARK: - Math

    /// The draft's formula: the average of the foreign (new connection) and self (loaded
    /// connection) responsiveness, each 60000 / trimmed-mean latency.
    static func rpm(foreign: [ProbeTiming], selfHTTP: [Double]) -> Double? {
        let foreignMs = roundTripMs(foreign, trimmed: true)
        let selfMs = Statistics.trimmedMean(selfHTTP)
        let parts = [foreignMs, selfMs].compactMap { $0 }.filter { $0 > 0 }.map { 60000 / $0 }
        guard !parts.isEmpty else { return nil }
        return parts.reduce(0, +) / Double(parts.count)
    }

    /// One round trip, from the TCP, TLS, and HTTP times of new connections.
    static func roundTripMs(_ timings: [ProbeTiming], trimmed: Bool) -> Double? {
        func summarize(_ values: [Double]) -> Double? {
            trimmed ? Statistics.trimmedMean(values) : Statistics.median(values)
        }
        let parts = [
            summarize(timings.compactMap(\.tcp)),
            summarize(timings.compactMap(\.tls)),
            summarize(timings.compactMap(\.http))
        ].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.reduce(0, +) / Double(parts.count)
    }

    // MARK: - Config

    struct Config {
        var small: URL
        var large: URL
        var upload: URL
        var server: String

        static func load(_ url: URL) async throws -> Config {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let config = parse(data) else { throw ResponsivenessError.badConfig }
            return config
        }

        static func parse(_ data: Data) -> Config? {
            guard let urls = try? JSONDecoder().decode(ConfigResponse.self, from: data).urls else { return nil }
            func url(_ keys: String...) -> URL? {
                keys.lazy.compactMap { urls[$0].flatMap(URL.init(string:)) }.first
            }
            guard let small = url("small_https_download_url", "small_download_url"),
                  let large = url("large_https_download_url", "large_download_url"),
                  let upload = url("https_upload_url", "upload_url")
            else { return nil }
            return Config(small: small, large: large, upload: upload, server: large.host() ?? "unknown")
        }
    }

    // MARK: - Phases

    struct PhaseResult {
        var probes: ProbeSet
        var downloadMbps: Double
        var uploadMbps: Double
    }

    struct ProbeSet {
        var foreign: [ProbeTiming] = []
        var selfHTTP: [Double] = []
        var router: [Double] = []
        var internet: [Double] = []

    }

    private func runLoaded(config: Config, progress: @escaping @Sendable (Double) -> Void) async -> PhaseResult {
        func makeFlow(_ index: Int) -> any LoadGenerator {
            index.isMultiple(of: 2) ? LoadFlow(download: config.large) : StreamUpload(config.upload)
        }
        var flows = (0..<Self.initialFlows).map(makeFlow)
        flows.forEach { $0.start() }
        let collector = ProbeCollector()
        let start = Date()
        var lastFlowAdded = start
        var lastRouterProbe = Date.distantPast

        await withTaskGroup(of: Void.self) { group in
            while case let elapsed = Date().timeIntervalSince(start), elapsed < Self.phaseDuration {
                progress(elapsed)
                let routerDue = Date().timeIntervalSince(lastRouterProbe) >= Self.routerProbeInterval
                if routerDue {
                    lastRouterProbe = Date()
                }
                let round = ProbeRound(
                    small: config.small, downloads: flows.compactMap { $0 as? LoadFlow },
                    routerDue: routerDue, counts: elapsed >= Self.rampUp
                )
                addProbes(round, to: &group, collector: collector)
                if flows.count < Self.maxFlows, Date().timeIntervalSince(lastFlowAdded) >= 0.5 {
                    lastFlowAdded = Date()
                    let flow = makeFlow(flows.count)
                    flow.start()
                    flows.append(flow)
                }
                try? await Task.sleep(for: .seconds(Self.probeInterval))
            }
            let seconds = Date().timeIntervalSince(start)
            func mbps(_ upload: Bool) -> Double {
                let bytes = flows.filter { $0.isUpload == upload }.reduce(0) { $0 + $1.bytes }
                return NDT7Client.mbps(bytes: Double(bytes), seconds: seconds)
            }
            await collector.setThroughput(download: mbps(false), upload: mbps(true))
            flows.forEach { $0.stop() }
        }
        return PhaseResult(
            probes: await collector.probes,
            downloadMbps: await collector.downloadMbps,
            uploadMbps: await collector.uploadMbps
        )
    }

    /// One round of probes: a new connection, a request on a loaded one, and (every other
    /// round) the router and internet. Probes from the ramp-up are taken but not counted.
    struct ProbeRound {
        var small: URL
        var downloads: [LoadFlow]
        var routerDue: Bool
        var counts: Bool
    }

    private func addProbes(_ round: ProbeRound, to group: inout TaskGroup<Void>, collector: ProbeCollector) {
        let (small, counts) = (round.small, round.counts)
        group.addTask {
            if let timing = await Self.foreignProbe(small), counts { await collector.add(foreign: timing) }
        }
        if let flow = round.downloads.randomElement() {
            group.addTask {
                if let ms = await flow.selfProbe(small), counts { await collector.add(selfHTTP: ms) }
            }
        }
        if round.routerDue {
            group.addTask {
                let (router, internet) = await self.pairedProbe()
                guard counts else { return }
                await collector.add(router: router, internet: internet)
            }
        }
    }

    // MARK: - Probes

    /// The time from sending a request to the first byte of its response, in ms.
    static func requestMs(_ url: URL, session: URLSession) async -> Double? {
        let collector = MetricsCollector()
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 5)
        guard (try? await session.data(for: request, delegate: collector)) != nil else { return nil }
        return collector.requestMs
    }
}
