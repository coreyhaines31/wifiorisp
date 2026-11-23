import Foundation

/// One room's Wi-Fi, as the median of a few samples taken on the spot.
public struct SurveyReading: Codable, Equatable, Sendable {
    public var room: String
    public var time: Date
    /// Signal strength in dBm.
    public var rssi: Int
    /// Background noise in dBm.
    public var noise: Int
    /// The speed of the Wi-Fi link between the Mac and the router, not the internet speed.
    public var linkRateMbps: Double
    public var band: Band?
    public var channel: Int?
    /// Nil when the router didn't answer most probes, or can't be measured.
    public var routerMs: Double?

    public init(
        room: String, time: Date, rssi: Int, noise: Int, linkRateMbps: Double, band: Band? = nil,
        channel: Int? = nil, routerMs: Double? = nil
    ) {
        self.room = room
        self.time = time
        self.rssi = rssi
        self.noise = noise
        self.linkRateMbps = linkRateMbps
        self.band = band
        self.channel = channel
        self.routerMs = routerMs
    }

    /// Nil when no sample was taken over Wi-Fi.
    public init?(room: String, samples: [Sample]) {
        let wifi = samples.filter { $0.link == .wifi }.compactMap(\.wifi)
        guard let last = wifi.last, let time = samples.last?.time,
              let rssi = Statistics.median(wifi.map { Double($0.rssi) }),
              let noise = Statistics.median(wifi.map { Double($0.noise) }),
              let rate = Statistics.median(wifi.map(\.txRate))
        else { return nil }
        let router = samples.compactMap(\.router)
        let replies = router.compactMap(\.ms)
        self.init(
            room: room, time: time, rssi: Int(rssi.rounded()), noise: Int(noise.rounded()), linkRateMbps: rate,
            band: last.band, channel: last.channel,
            routerMs: replies.count * 2 > router.count ? Statistics.median(replies) : nil
        )
    }

    /// Excellent, Good, Fair, or Weak.
    public var signal: String { PlainLanguage.signal(rssi: rssi, snr: rssi - noise) }
}

/// A room in the survey: its latest reading, and the one from the pass before when there is one.
public struct SurveyRow: Equatable, Sendable {
    public var room: String
    /// Nil when the room hasn't been measured again in the latest pass.
    public var reading: SurveyReading?
    public var previous: SurveyReading?

    /// How many dB the signal moved between the passes. Positive is stronger.
    public var signalChange: Int? {
        guard let reading, let previous else { return nil }
        return reading.rssi - previous.rssi
    }
}

/// Readings room by room. A pass is one walk through the rooms; a second pass, after changing
/// something, is compared with the first.
public struct Survey: Codable, Equatable, Sendable {
    /// Oldest first.
    public private(set) var passes: [[SurveyReading]]

    public init(passes: [[SurveyReading]] = []) {
        self.passes = passes
    }

    public var isEmpty: Bool { passes.allSatisfy(\.isEmpty) }

    /// Files a reading in the latest pass, replacing an earlier one for the same room. A room keeps
    /// the spelling it was first given; the reading is returned as filed.
    @discardableResult
    public mutating func record(_ reading: SurveyReading) -> SurveyReading {
        var reading = reading
        if let known = passes.joined().first(where: { Self.same($0.room, reading.room) }) {
            reading.room = known.room
        }
        var pass = passes.popLast() ?? []
        if let index = pass.firstIndex(where: { Self.same($0.room, reading.room) }) {
            pass[index] = reading
        } else {
            pass.append(reading)
        }
        passes.append(pass)
        return reading
    }

    /// Starts the next pass. False when the latest one has no readings yet.
    public mutating func startNextPass() -> Bool {
        guard let latest = passes.last, !latest.isEmpty else { return false }
        passes.append([])
        return true
    }

    /// The latest pass against the one before: rooms in the earlier pass's order, then new ones.
    public var rows: [SurveyRow] {
        let latest = passes.last ?? []
        let earlier = passes.count > 1 ? passes[passes.count - 2] : []
        var rows = earlier.map { previous in
            SurveyRow(
                room: previous.room, reading: latest.first { Self.same($0.room, previous.room) }, previous: previous
            )
        }
        rows += latest
            .filter { reading in !earlier.contains { Self.same($0.room, reading.room) } }
            .map { SurveyRow(room: $0.room, reading: $0, previous: nil) }
        return rows
    }

    private static func same(_ one: String, _ other: String) -> Bool {
        one.compare(other, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }
}

/// The survey on disk, kept on this Mac only.
public struct SurveyStore: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "WiFi or ISP/survey.json")
    }

    /// An empty survey when there's no file yet, or it can't be read.
    public func load() -> Survey {
        guard let data = try? Data(contentsOf: url) else { return Survey() }
        return (try? CLIProtocol.decoder().decode(Survey.self, from: data)) ?? Survey()
    }

    public func save(_ survey: Survey) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try CLIProtocol.encoder().encode(survey).write(to: url, options: .atomic)
    }

    public func reset() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}
