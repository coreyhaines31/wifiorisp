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
                + "or the router's own buffers. Try 5 or 6 GHz, or Smart Queue Management (SQM) on the router."
        case .pastRouter:
            return "\(added) \(probes) Your router stayed quick, so the queue is past it: in your modem or at your ISP. "
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

    public func run(progress: @escaping @Sendable (ResponsivenessPhase, Double) -> Void) async throws -> ResponsivenessResult {
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
            struct Response: Decodable {
                var urls: [String: String]
            }
            guard let urls = try? JSONDecoder().decode(Response.self, from: data).urls else { return nil }
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
                let counts = elapsed >= Self.rampUp
                let small = config.small
                group.addTask {
                    if let timing = await Self.foreignProbe(small), counts { await collector.add(foreign: timing) }
                }
                if let flow = flows.compactMap({ $0 as? LoadFlow }).randomElement() {
                    group.addTask {
                        if let ms = await flow.selfProbe(small), counts { await collector.add(selfHTTP: ms) }
                    }
                }
                if Date().timeIntervalSince(lastRouterProbe) >= Self.routerProbeInterval {
                    lastRouterProbe = Date()
                    group.addTask {
                        let (router, internet) = await self.pairedProbe()
                        guard counts else { return }
                        await collector.add(router: router, internet: internet)
                    }
                }
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
            probes: await collector.probes, downloadMbps: await collector.downloadMbps, uploadMbps: await collector.uploadMbps
        )
    }

    // MARK: - Probes

    /// A brand-new connection, as the draft specifies: TCP, then TLS, then one small HTTP/1.1
    /// request. Network.framework reports each handshake's time. (URLSession would pick
    /// HTTP/3 here, and QUIC sidesteps the very TCP queues this test is looking for.)
    static func foreignProbe(_ url: URL) async -> ProbeTiming? {
        guard let host = url.host() else { return nil }
        let tls = NWProtocolTLS.Options()
        sec_protocol_options_add_tls_application_protocol(tls.securityProtocolOptions, "http/1.1")
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: UInt16(url.port ?? 443)) ?? .https,
            using: NWParameters(tls: tls)
        )
        defer { connection.cancel() }
        let queue = DispatchQueue(label: "app.wifiorisp.foreign-probe")

        guard await ready(connection, queue: queue) else { return nil }
        let handshakes = await withCheckedContinuation { continuation in
            connection.requestEstablishmentReport(queue: queue) { report in
                continuation.resume(returning: report?.handshakes ?? [])
            }
        }
        var timing = ProbeTiming()
        for handshake in handshakes {
            let ms = handshake.handshakeDuration * 1000
            if handshake.definition == NWProtocolTCP.definition {
                timing.tcp = ms
            } else if handshake.definition == NWProtocolTLS.definition {
                timing.tls = ms
            }
        }

        var path = url.path(percentEncoded: true)
        if let query = url.query(percentEncoded: true) { path += "?\(query)" }
        let request = "GET \(path.isEmpty ? "/" : path) HTTP/1.1\r\nHost: \(host)\r\nConnection: close\r\n\r\n"
        let start = DispatchTime.now().uptimeNanoseconds
        let answered = await withCheckedContinuation { continuation in
            connection.send(content: Data(request.utf8), completion: .contentProcessed { _ in })
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, error in
                continuation.resume(returning: error == nil && data?.isEmpty == false)
            }
        }
        guard answered else { return nil }
        timing.http = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        return timing
    }

    private static func ready(_ connection: NWConnection, queue: DispatchQueue) async -> Bool {
        let once = Once()
        return await withCheckedContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: once.run { continuation.resume(returning: true) }
                case .failed, .cancelled: once.run { continuation.resume(returning: false) }
                default: break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 5) {
                once.run { continuation.resume(returning: false) }
            }
        }
    }

    /// The time from sending a request to the first byte of its response, in ms.
    static func requestMs(_ url: URL, session: URLSession) async -> Double? {
        let collector = MetricsCollector()
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 5)
        guard (try? await session.data(for: request, delegate: collector)) != nil else { return nil }
        return collector.requestMs
    }
}

/// One new connection's round trips: the TCP handshake, the TLS handshake, and an HTTP request.
struct ProbeTiming: Sendable {
    var tcp: Double?
    var tls: Double?
    var http: Double?
}

/// Runs a closure at most once, from any thread.
private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func run(_ body: () -> Void) {
        let first = lock.withLock {
            defer { done = true }
            return !done
        }
        if first { body() }
    }
}

private final class MetricsCollector: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var metrics: URLSessionTaskMetrics?

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        lock.withLock { self.metrics = metrics }
    }

    var requestMs: Double? {
        lock.withLock {
            guard let transaction = metrics?.transactionMetrics.last(where: { $0.resourceFetchType == .networkLoad }),
                  let start = transaction.requestStartDate, let end = transaction.responseStartDate
            else { return nil }
            return end.timeIntervalSince(start) * 1000
        }
    }
}

private actor ProbeCollector {
    private(set) var probes = ResponsivenessTest.ProbeSet()
    private(set) var downloadMbps: Double = 0
    private(set) var uploadMbps: Double = 0

    func add(foreign: ProbeTiming) { probes.foreign.append(foreign) }
    func add(selfHTTP: Double) { probes.selfHTTP.append(selfHTTP) }
    func add(router: Double?, internet: Double?) {
        if let router { probes.router.append(router) }
        if let internet { probes.internet.append(internet) }
    }
    func setThroughput(download: Double, upload: Double) {
        downloadMbps = download
        uploadMbps = upload
    }
}

protocol LoadGenerator: AnyObject, Sendable {
    var bytes: Int { get }
    var isUpload: Bool { get }
    func start()
    func stop()
}

/// One saturating download: an endless transfer, restarted if it ever finishes. Each flow has
/// its own session, so each is its own connection, and self probes ride on it.
final class LoadFlow: NSObject, LoadGenerator, URLSessionDataDelegate, @unchecked Sendable {
    static var configuration: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.httpMaximumConnectionsPerHost = 1
        return configuration
    }

    private let url: URL
    private let lock = NSLock()
    private var transferred = 0
    private var stopped = false
    private var loadTask: URLSessionTask?
    private lazy var session = URLSession(configuration: Self.configuration, delegate: self, delegateQueue: nil)

    init(download url: URL) {
        self.url = url
    }

    var bytes: Int { lock.withLock { transferred } }
    let isUpload = false

    func start() {
        let task = session.dataTask(with: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData))
        lock.withLock { loadTask = task }
        task.resume()
    }

    func stop() {
        lock.withLock { stopped = true }
        session.invalidateAndCancel()
    }

    /// A small request on this already-busy connection.
    func selfProbe(_ url: URL) async -> Double? {
        await ResponsivenessTest.requestMs(url, session: session)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.withLock {
            if dataTask === loadTask { transferred += data.count }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let restart = lock.withLock { task === loadTask && !stopped }
        if restart {
            start()
        }
    }
}

/// One saturating upload: an HTTP/1.1 POST over TLS that streams zeros until stopped.
/// Uses Network.framework because URLSession uploads over HTTP/3 can't fill a fast uplink.
final class StreamUpload: LoadGenerator, @unchecked Sendable {
    private static let chunk = Data(count: 1 << 20)
    private static let queue = DispatchQueue(label: "app.wifiorisp.upload")

    private let url: URL
    private let connection: NWConnection
    private let lock = NSLock()
    private var sent = 0
    private var stopped = false

    init(_ url: URL) {
        self.url = url
        let tls = NWProtocolTLS.Options()
        sec_protocol_options_add_tls_application_protocol(tls.securityProtocolOptions, "http/1.1")
        connection = NWConnection(
            host: NWEndpoint.Host(url.host() ?? ""),
            port: NWEndpoint.Port(rawValue: UInt16(url.port ?? 443)) ?? .https,
            using: NWParameters(tls: tls)
        )
    }

    var bytes: Int { lock.withLock { sent } }
    let isUpload = true

    func start() {
        connection.start(queue: Self.queue)
        var path = url.path(percentEncoded: true)
        if let query = url.query(percentEncoded: true) { path += "?\(query)" }
        let header = "POST \(path.isEmpty ? "/" : path) HTTP/1.1\r\nHost: \(url.host() ?? "")\r\n"
            + "Content-Type: application/octet-stream\r\nContent-Length: 4000000000\r\n\r\n"
        connection.send(content: Data(header.utf8), completion: .contentProcessed { _ in })
        sendNext()
    }

    private func sendNext() {
        connection.send(content: Self.chunk, completion: .contentProcessed { [weak self] error in
            guard let self, error == nil else { return }
            let keepGoing = lock.withLock {
                sent += Self.chunk.count
                return !stopped
            }
            if keepGoing { sendNext() }
        })
    }

    func stop() {
        lock.withLock { stopped = true }
        connection.cancel()
    }
}
