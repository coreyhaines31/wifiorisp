import Foundation

public struct SpeedTestResult: Codable, Equatable, Sendable {
    public var time: Date
    public var downloadMbps: Double
    public var uploadMbps: Double
    /// The server's smallest observed round trip, in ms.
    public var minRTTms: Double?
    /// Where the M-Lab server was, e.g. "Los Angeles, US".
    public var server: String

    public init(time: Date, downloadMbps: Double, uploadMbps: Double, minRTTms: Double?, server: String) {
        self.time = time
        self.downloadMbps = downloadMbps
        self.uploadMbps = uploadMbps
        self.minRTTms = minRTTms
        self.server = server
    }
}

public enum SpeedTestPhase: Sendable {
    case locating
    case download
    case upload
}

public enum SpeedTestError: LocalizedError {
    case noServer
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .noServer: "Couldn't find an M-Lab server. Check your connection and try again."
        case .failed(let message): message
        }
    }
}

/// An M-Lab NDT7 client (https://github.com/m-lab/ndt-server/blob/main/spec/ndt7-protocol.md).
/// M-Lab publishes every result as open data, which the app tells people before the first test.
public final class NDT7Client: Sendable {
    public static let clientName = "wifiorisp"
    static let subprotocol = "net.measurementlab.ndt.v7"
    /// The server ends each direction after about 10 s; this is the safety net.
    static let phaseLimit: TimeInterval = 15
    static let uploadDuration: TimeInterval = 10

    private let clientVersion: String

    public init(clientVersion: String) {
        self.clientVersion = clientVersion
    }

    /// - Parameter progress: called with the phase and the throughput so far in Mbps.
    public func run(progress: @escaping @Sendable (SpeedTestPhase, Double) -> Void) async throws -> SpeedTestResult {
        progress(.locating, 0)
        let target = try await locate()
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }

        let download = try await measureDownload(session: session, url: target.download) { progress(.download, $0) }
        let upload = try await measureUpload(session: session, url: target.upload) { progress(.upload, $0) }
        return SpeedTestResult(
            time: Date(),
            downloadMbps: download.mbps,
            uploadMbps: upload.mbps,
            minRTTms: download.minRTTms ?? upload.minRTTms,
            server: target.location
        )
    }

    // MARK: - Locate

    struct Target {
        var download: URL
        var upload: URL
        var location: String
    }

    private func locate() async throws -> Target {
        var components = URLComponents(string: "https://locate.measurementlab.net/v2/nearest/ndt/ndt7")!
        components.queryItems = [
            URLQueryItem(name: "client_name", value: Self.clientName),
            URLQueryItem(name: "client_version", value: clientVersion)
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        guard let target = try Self.parseLocate(data) else { throw SpeedTestError.noServer }
        return target
    }

    static func parseLocate(_ data: Data) throws -> Target? {
        for result in try JSONDecoder().decode(LocateResponse.self, from: data).results ?? [] {
            if let download = result.urls["wss:///ndt/v7/download"].flatMap(URL.init(string:)),
               let upload = result.urls["wss:///ndt/v7/upload"].flatMap(URL.init(string:)) {
                let place = [result.location?.city, result.location?.country].compactMap { $0 }.joined(separator: ", ")
                return Target(download: download, upload: upload, location: place.isEmpty ? "M-Lab" : place)
            }
        }
        return nil
    }

    // MARK: - Measurement

    struct Measured {
        var mbps: Double
        var minRTTms: Double?
    }

    private func webSocket(session: URLSession, url: URL) -> URLSessionWebSocketTask {
        let task = session.webSocketTask(with: url, protocols: [Self.subprotocol])
        task.maximumMessageSize = 1 << 24
        task.resume()
        return task
    }

    private func measureDownload(
        session: URLSession, url: URL, progress: @escaping @Sendable (Double) -> Void
    ) async throws -> Measured {
        let task = webSocket(session: session, url: url)
        let watchdog = Task {
            try await Task.sleep(for: .seconds(Self.phaseLimit))
            task.cancel(with: .normalClosure, reason: nil)
        }
        defer { watchdog.cancel() }

        let start = Date()
        var bytes = 0
        var minRTT: Double?
        var lastReport = start
        while true {
            let message: URLSessionWebSocketTask.Message
            do {
                message = try await task.receive()
            } catch {
                break
            }
            switch message {
            case .data(let data):
                bytes += data.count
            case .string(let text):
                bytes += text.utf8.count
                if let rtt = Self.decode(text)?.tcpInfo?.minRTT {
                    minRTT = rtt / 1000
                }
            @unknown default:
                break
            }
            if Date().timeIntervalSince(lastReport) > 0.25 {
                lastReport = Date()
                progress(Self.mbps(bytes: Double(bytes), seconds: lastReport.timeIntervalSince(start)))
            }
        }
        let elapsed = Date().timeIntervalSince(start)
        guard bytes > 0 else { throw SpeedTestError.failed("The download test didn't receive any data.") }
        return Measured(mbps: Self.mbps(bytes: Double(bytes), seconds: elapsed), minRTTms: minRTT)
    }

    private func measureUpload(
        session: URLSession, url: URL, progress: @escaping @Sendable (Double) -> Void
    ) async throws -> Measured {
        let task = webSocket(session: session, url: url)
        let server = ServerReports()
        // The server reports how much it has received; that's more accurate than counting
        // what was handed to the socket.
        let reader = Task {
            while let message = try? await task.receive() {
                if case .string(let text) = message, let info = Self.decode(text)?.tcpInfo {
                    server.update(info)
                }
            }
        }
        defer {
            reader.cancel()
            task.cancel(with: .normalClosure, reason: nil)
        }

        let start = Date()
        var sent = 0.0
        var size = 1 << 13
        var lastReport = start
        while Date().timeIntervalSince(start) < Self.uploadDuration {
            do {
                try await task.send(.data(Data(count: size)))
            } catch {
                break
            }
            sent += Double(size)
            // Grow messages as the spec suggests, so fast links aren't limited by per-message overhead.
            if size < 1 << 24 && Double(size) <= sent / 16 {
                size *= 2
            }
            if Date().timeIntervalSince(lastReport) > 0.25 {
                lastReport = Date()
                progress(server.mbps ?? Self.mbps(bytes: sent, seconds: lastReport.timeIntervalSince(start)))
            }
        }
        let mbps = server.mbps ?? Self.mbps(bytes: sent, seconds: Date().timeIntervalSince(start))
        guard mbps > 0 else { throw SpeedTestError.failed("The upload test couldn't send any data.") }
        return Measured(mbps: mbps, minRTTms: server.minRTTms)
    }

    static func decode(_ text: String) -> ServerMeasurement? {
        try? JSONDecoder().decode(ServerMeasurement.self, from: Data(text.utf8))
    }

    static func mbps(bytes: Double, seconds: Double) -> Double {
        seconds > 0 ? bytes * 8 / seconds / 1_000_000 : 0
    }
}

/// The latest numbers the server sent during an upload.
private final class ServerReports: @unchecked Sendable {
    private let lock = NSLock()
    private var info: TCPInfo?

    func update(_ info: TCPInfo) {
        lock.withLock { self.info = info }
    }

    var mbps: Double? {
        lock.withLock {
            guard let bytes = info?.bytesReceived, let micros = info?.elapsedTime, micros > 0 else { return nil }
            return NDT7Client.mbps(bytes: bytes, seconds: micros / 1_000_000)
        }
    }

    var minRTTms: Double? {
        lock.withLock { info?.minRTT.map { $0 / 1000 } }
    }
}

private struct LocateResponse: Decodable {
    struct Result: Decodable {
        var urls: [String: String]
        var location: Location?
    }

    struct Location: Decodable {
        var city: String?
        var country: String?
    }

    var results: [Result]?
}

/// The parts of an NDT7 server measurement message the app uses.
struct ServerMeasurement: Decodable {
    var tcpInfo: TCPInfo?

    enum CodingKeys: String, CodingKey {
        case tcpInfo = "TCPInfo"
    }
}

struct TCPInfo: Decodable {
    var minRTT: Double?
    var bytesReceived: Double?
    var elapsedTime: Double?

    enum CodingKeys: String, CodingKey {
        case minRTT = "MinRTT"
        case bytesReceived = "BytesReceived"
        case elapsedTime = "ElapsedTime"
    }
}
