import Foundation

/// How the `wifiorisp` command talks to the running app: a Unix socket in Application Support
/// that only the signed-in user can open. The command sends one request per connection, and the
/// app answers with JSON messages, one per line, then closes the connection.
public enum CLIProtocol {
    public static let bundleIdentifier = "app.wifiorisp.WiFiOrISP"

    public static var socketURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "WiFi or ISP/cli.sock")
    }

    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

public struct CLIRequest: Codable, Equatable, Sendable {
    public enum Action: String, Codable, Sendable {
        /// The verdict right now. Waits for the first readings if the app just started.
        case status
        /// A status after every new sample, until the command hangs up.
        case watch
        case speed
        case lag
    }

    public var action: Action

    public init(action: Action) {
        self.action = action
    }
}

/// One line of the app's answer. Exactly one field is set.
public struct CLIMessage: Codable, Equatable, Sendable {
    /// What a test is doing, for the terminal while it runs.
    public var progress: String?
    public var status: CLIStatus?
    public var speed: SpeedTestResult?
    public var lag: CLILag?
    public var error: String?

    public init(
        progress: String? = nil, status: CLIStatus? = nil, speed: SpeedTestResult? = nil, lag: CLILag? = nil,
        error: String? = nil
    ) {
        self.progress = progress
        self.status = status
        self.speed = speed
        self.lag = lag
        self.error = error
    }
}

/// The menu's verdict card, as data.
public struct CLIStatus: Codable, Equatable, Sendable {
    public struct Judgment: Codable, Equatable, Sendable {
        public var kind: String
        /// "yours" (Wi-Fi or router) or "isp", when one side is at fault.
        public var side: String?
        public var problem: Bool
        public var headline: String
        public var detail: String
    }

    public struct Timing: Codable, Equatable, Sendable {
        /// Nil when there was no answer, or it wasn't measured.
        public var ms: Double?
        /// "Fast", "OK", "Slow", "No answer", or "Not measured".
        public var rating: String
    }

    public struct WiFi: Codable, Equatable, Sendable {
        /// "Excellent", "Good", "Fair", or "Weak".
        public var signal: String
        public var rssiDBm: Int
        public var noiseDBm: Int
        /// Nil when macOS hides it, which it does from apps without Location access.
        public var network: String?
        public var band: String?
        public var channel: Int?
        public var generation: String?
        public var linkRateMbps: Int
    }

    public struct Step: Codable, Equatable, Sendable {
        public var title: String
        /// A guide on wifiorisp.com.
        public var url: String?
        /// A `wifiorisp` command that does it.
        public var command: String?
    }

    public struct Limit: Codable, Equatable, Sendable {
        public var headline: String
        public var detail: String
        public var url: String
    }

    public var time: Date?
    /// "wifi", "wired", or "none".
    public var link: String
    public var verdict: Judgment
    /// True while a speed or lag test runs; measurements pause so the test isn't logged as slowness.
    public var paused: Bool
    public var wifi: WiFi?
    public var router: Timing
    public var internet: Timing
    public var routerMaker: String?
    public var provider: String?
    public var nextSteps: [Step]
    /// Limits no setting fixes: the router, the Wi-Fi link, or the plan itself.
    public var limits: [Limit]

    public static let site = "https://wifiorisp.com"

    public init(context: AdviceContext, networkName: String?, paused: Bool) {
        let verdict = context.verdict
        let sample = context.latest
        time = sample?.time
        link = sample?.link.rawValue ?? Link.none.rawValue
        self.verdict = Judgment(
            kind: verdict.kind.rawValue, side: verdict.side?.rawValue, problem: verdict.isProblem,
            headline: verdict.headline, detail: verdict.detail
        )
        self.paused = paused
        if sample?.link == .wifi, let reading = sample?.wifi {
            wifi = WiFi(
                signal: PlainLanguage.signal(rssi: reading.rssi, snr: reading.snr), rssiDBm: reading.rssi,
                noiseDBm: reading.noise, network: networkName, band: reading.band?.label, channel: reading.channel,
                generation: reading.generationLabel, linkRateMbps: Int(reading.txRate.rounded())
            )
        }
        router = Self.timing(sample?.router, rate: PlainLanguage.router)
        internet = Self.timing(sample?.internet, rate: PlainLanguage.internet)
        routerMaker = context.maker?.name
        provider = context.provider?.name
        nextSteps = paused ? [] : Advice.steps(context).map(Self.step)
        limits = paused ? [] : Advice.ceilings(context).map {
            Limit(headline: $0.headline, detail: $0.detail, url: Self.site + $0.recommendation)
        }
    }

    static func timing(_ probe: Probe?, rate: (Double) -> PlainLanguage.Speed) -> Timing {
        switch probe {
        case .reply(let ms): Timing(ms: (ms * 10).rounded() / 10, rating: rate(ms).rawValue)
        case .lost: Timing(ms: nil, rating: "No answer")
        case nil: Timing(ms: nil, rating: "Not measured")
        }
    }

    static func step(_ step: NextStep) -> Step {
        switch step.action {
        case .page(let path): Step(title: step.title, url: site + path)
        case .runSpeedTest: Step(title: step.title, command: "wifiorisp speed")
        case .runLagTest: Step(title: step.title, command: "wifiorisp lag")
        case .exportReport: Step(title: step.title, command: "wifiorisp report")
        case nil: Step(title: step.title)
        }
    }
}

/// A lag-under-load result, with the app's reading of it.
public struct CLILag: Codable, Equatable, Sendable {
    public var time: Date
    /// Round trips per minute under load. Higher is better.
    public var rpm: Int
    /// "Low", "Medium", or "High" responsiveness.
    public var grade: String
    public var headline: String
    public var detail: String
    public var idleMs: Double
    public var loadedMs: Double
    public var routerAddedMs: Double?
    public var internetAddedMs: Double?
    /// "yourSide", "pastRouter", or "unknown": where the queue builds up.
    public var queue: String
    public var downloadMbps: Double
    public var uploadMbps: Double
    public var server: String

    public init(_ result: ResponsivenessResult) {
        let round = { (value: Double) in (value * 10).rounded() / 10 }
        time = result.time
        rpm = result.rpm
        grade = result.grade.rawValue
        headline = result.headline
        detail = result.detail
        idleMs = round(result.idleLatencyMs)
        loadedMs = round(result.loadedLatencyMs)
        routerAddedMs = result.routerAddedMs.map(round)
        internetAddedMs = result.internetAddedMs.map(round)
        queue = switch result.queueLocation {
        case .yourSide: "yourSide"
        case .pastRouter: "pastRouter"
        case .unknown: "unknown"
        }
        downloadMbps = round(result.downloadMbps)
        uploadMbps = round(result.uploadMbps)
        server = result.server
    }
}

/// `wifiorisp history --json`: the summary and events in plain words. Raw samples are in `--csv`.
public struct CLIHistory: Codable, Equatable, Sendable {
    public struct Event: Codable, Equatable, Sendable {
        public var time: Date
        public var text: String
    }

    public var start: Date
    public var end: Date
    public var measurements: Int
    public var networks: [String]
    public var routerMedianMs: Double?
    public var internetMedianMs: Double?
    public var internetP95Ms: Double?
    /// Shares of the period, 0 to 1.
    public var internetLoss: Double
    public var ispSlow: Double
    public var yourSideSlow: Double
    public var events: [Event]

    public init(log: Log, start: Date, end: Date) {
        let summary = ReportSummary(log: log, start: start, end: end)
        let round = { (value: Double) in (value * 10).rounded() / 10 }
        let share = { (value: Double) in (value * 1000).rounded() / 1000 }
        self.start = start
        self.end = end
        measurements = summary.sampleCount
        networks = summary.networks
        routerMedianMs = summary.routerMedianMs.map(round)
        internetMedianMs = summary.internetMedianMs.map(round)
        internetP95Ms = summary.internetP95Ms.map(round)
        internetLoss = share(summary.internetLoss)
        ispSlow = share(summary.ispSlowShare)
        yourSideSlow = share(summary.yourSideSlowShare)
        events = CLIText.events(log.events).map { Event(time: $0.time, text: $0.text) }
    }
}
