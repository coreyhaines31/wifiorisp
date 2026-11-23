import Foundation

/// What `wifiorisp survey` prints when it isn't asked for JSON.
public enum SurveyText {
    /// A link rate has to move this much, as a share, to count as faster or slower.
    static let meaningfulChange = 0.05

    static let linkRateNote =
        "Link rate is the speed of the Wi-Fi link between this Mac and the router, not your internet speed."

    /// One line for a reading just taken.
    public static func reading(_ reading: SurveyReading) -> String {
        "\(reading.room): \(reading.signal) signal (\(reading.rssi) dBm), link rate \(mbps(reading.linkRateMbps)), "
            + "router \(router(reading.routerMs))"
    }

    public static func table(_ survey: Survey) -> String {
        let rows = survey.rows
        guard !rows.isEmpty else {
            return "No rooms yet. Carry this Mac to a room and run: wifiorisp survey room Kitchen"
        }
        let compares = rows.contains { $0.previous != nil }
        var lines = compares ? comparison(rows) : single(rows)
        lines += ["", linkRateNote]
        if !compares {
            lines.append("After you change something, run `wifiorisp survey again` and take the readings again.")
        }
        return lines.joined(separator: "\n")
    }

    private static func single(_ rows: [SurveyRow]) -> [String] {
        let readings = rows.compactMap(\.reading)
        var lines = columns([["Room", "Signal", "Link rate", "Router"]] + readings.map {
            [$0.room, "\($0.signal) (\($0.rssi) dBm)", mbps($0.linkRateMbps), router($0.routerMs)]
        })
        if readings.count > 1, let weakest = readings.min(by: { $0.rssi < $1.rssi }) {
            lines += ["", "Weakest signal: \(weakest.room)."]
        }
        return lines
    }

    private static func comparison(_ rows: [SurveyRow]) -> [String] {
        var lines = columns([["Room", "Signal", "Link rate", "Router"]] + rows.map { row in
            [
                row.room,
                pair(row.previous.map { "\($0.rssi)" }, row.reading.map { "\($0.rssi)" }, unit: "dBm"),
                pair(
                    row.previous.map { rate($0.linkRateMbps) }, row.reading.map { rate($0.linkRateMbps) }, unit: "Mbps"
                ) + (row.linkRateChange.map { " (\(percent($0)))" } ?? ""),
                pair(row.previous.map { ms($0.routerMs) }, row.reading.map { ms($0.routerMs) }, unit: "ms")
            ]
        })
        if let summary = summary(rows) { lines += ["", summary] }
        let waiting = rows.filter { $0.reading == nil }.map(\.room)
        if !waiting.isEmpty { lines.append("Not measured again yet: \(waiting.joined(separator: ", ")).") }
        return lines
    }

    /// "Faster link in 3 of 5 rooms. Slower in: Hallway."
    static func summary(_ rows: [SurveyRow]) -> String? {
        let changes = rows.compactMap { row in row.linkRateChange.map { (row.room, $0) } }
        guard !changes.isEmpty else { return nil }
        let faster = changes.filter { $0.1 > meaningfulChange }.count
        let slower = changes.filter { $0.1 < -meaningfulChange }.map(\.0)
        var text = "Faster link in \(faster) of \(changes.count) \(changes.count == 1 ? "room" : "rooms")."
        if !slower.isEmpty { text += " Slower in: \(slower.joined(separator: ", "))." }
        return text
    }

    /// "408 → 720 Mbps", with a dash for a side that wasn't measured.
    private static func pair(_ before: String?, _ after: String?, unit: String) -> String {
        "\(before ?? "–") → \(after ?? "–") \(unit)"
    }

    /// Pads every column to its widest cell.
    private static func columns(_ rows: [[String]]) -> [String] {
        let widths = (0..<(rows.first?.count ?? 0)).map { column in rows.map { $0[column].count }.max() ?? 0 }
        return rows.map { row in
            row.enumerated()
                .map { $0.element.padding(toLength: widths[$0.offset] + 3, withPad: " ", startingAt: 0) }
                .joined()
                .replacing(/\s+$/, with: "")
        }
    }

    private static func rate(_ value: Double) -> String { "\(Int(value.rounded()))" }

    private static func mbps(_ value: Double) -> String { "\(rate(value)) Mbps" }

    private static func ms(_ value: Double?) -> String { value.map { "\(Int($0.rounded()))" } ?? "–" }

    private static func router(_ value: Double?) -> String {
        value.map { "\(PlainLanguage.router($0).rawValue) · \(Int($0.rounded())) ms" } ?? "No answer"
    }

    private static func percent(_ change: Double) -> String {
        let whole = Int((change * 100).rounded())
        return (whole > 0 ? "+" : "") + "\(whole)%"
    }
}

/// `wifiorisp survey --json`.
public struct CLISurvey: Codable, Equatable, Sendable {
    public struct Reading: Codable, Equatable, Sendable {
        public var time: Date
        /// "Excellent", "Good", "Fair", or "Weak".
        public var signal: String
        public var rssiDBm: Int
        public var noiseDBm: Int
        /// The speed of the Wi-Fi link to the router, not the internet speed.
        public var linkRateMbps: Int
        public var band: String?
        public var channel: Int?
        /// Nil when the router didn't answer.
        public var routerMs: Double?

        init(_ reading: SurveyReading) {
            time = reading.time
            signal = reading.signal
            rssiDBm = reading.rssi
            noiseDBm = reading.noise
            linkRateMbps = Int(reading.linkRateMbps.rounded())
            band = reading.band?.label
            channel = reading.channel
            routerMs = reading.routerMs.map { ($0 * 10).rounded() / 10 }
        }
    }

    public struct Room: Codable, Equatable, Sendable {
        public var room: String
        /// The latest pass. Nil when the room hasn't been measured again yet.
        public var reading: Reading?
        /// The pass before, when there is one.
        public var previous: Reading?
        /// The change in link rate between the passes, as a share: 0.76 is 76% faster.
        public var linkRateChange: Double?
    }

    /// How many passes have readings: 2 or more means `previous` is filled in.
    public var passes: Int
    public var rooms: [Room]
    /// The room with the weakest signal in the latest pass.
    public var weakest: String?

    public init(_ survey: Survey) {
        passes = survey.passes.filter { !$0.isEmpty }.count
        rooms = survey.rows.map { row in
            Room(
                room: row.room, reading: row.reading.map(Reading.init), previous: row.previous.map(Reading.init),
                linkRateChange: row.linkRateChange.map { ($0 * 1000).rounded() / 1000 }
            )
        }
        weakest = survey.rows.compactMap(\.reading).min { $0.rssi < $1.rssi }?.room
    }
}
