import Foundation
import Network

/// One new connection's round trips: the TCP handshake, the TLS handshake, and an HTTP request.
struct ProbeTiming: Sendable {
    var tcp: Double?
    var tls: Double?
    var http: Double?
}

extension ResponsivenessTest {
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

        // A server that connects but never answers would otherwise hold up the whole test.
        queue.asyncAfter(deadline: .now() + 5) { connection.cancel() }
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
}

struct ConfigResponse: Decodable {
    var urls: [String: String]
}

/// Runs a closure at most once, from any thread.
final class Once: @unchecked Sendable {
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

final class MetricsCollector: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
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

actor ProbeCollector {
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
    private var startedAt = Date()
    private lazy var session = URLSession(configuration: Self.configuration, delegate: self, delegateQueue: nil)

    init(download url: URL) {
        self.url = url
    }

    var bytes: Int { lock.withLock { transferred } }
    let isUpload = false

    func start() {
        let task = session.dataTask(with: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData))
        lock.withLock {
            loadTask = task
            startedAt = Date()
        }
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
        // A transfer that ends almost at once (an error page, a dropped connection) would
        // otherwise restart in a tight loop; give up on this flow instead.
        let restart = lock.withLock {
            task === loadTask && !stopped && Date().timeIntervalSince(startedAt) >= 1
        }
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
