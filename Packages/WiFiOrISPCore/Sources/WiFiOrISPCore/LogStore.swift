import Foundation

/// Samples and events over a time range, oldest first.
public struct Log: Sendable {
    public var samples: [Sample]
    public var events: [NetworkEvent]

    public init(samples: [Sample] = [], events: [NetworkEvent] = []) {
        self.samples = samples
        self.events = events
    }
}

/// The background log: one JSON Lines file per day, kept on this Mac only.
public final class LogStore: Sendable {
    public static let defaultKeepDays = 30

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "WiFi or ISP/Log", directoryHint: .isDirectory)
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    private static let dayFormat = Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day()

    private func file(for date: Date) -> URL {
        directory.appending(path: "\(date.formatted(Self.dayFormat)).jsonl")
    }

    public func append(_ sample: Sample) throws {
        try append(.sample(sample))
    }

    public func append(_ event: NetworkEvent) throws {
        try append(.event(event))
    }

    private func append(_ entry: Entry) throws {
        var line = try Self.encoder().encode(entry)
        line.append(UInt8(ascii: "\n"))
        let url = file(for: entry.time)
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
    }

    /// Everything logged in the range. Unreadable lines (say, one cut off by a crash) are skipped.
    public func load(from start: Date, to end: Date) -> Log {
        var log = Log()
        let decoder = Self.decoder()
        var day = Calendar.gmt.startOfDay(for: start)
        while day <= end {
            if let data = try? Data(contentsOf: file(for: day)) {
                for line in data.split(separator: UInt8(ascii: "\n")) {
                    guard let entry = try? decoder.decode(Entry.self, from: line),
                          entry.time >= start, entry.time <= end
                    else { continue }
                    switch entry {
                    case .sample(let sample): log.samples.append(sample)
                    case .event(let event): log.events.append(event)
                    }
                }
            }
            day = day.addingTimeInterval(86400)
        }
        log.samples.sort { $0.time < $1.time }
        log.events.sort { $0.time < $1.time }
        return log
    }

    /// Deletes day files older than `days`.
    public func prune(keepingDays days: Int, now: Date = Date()) {
        let cutoff = Calendar.gmt.startOfDay(for: now).addingTimeInterval(-Double(days) * 86400)
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for url in files where url.pathExtension == "jsonl" {
            let name = url.deletingPathExtension().lastPathComponent
            if let day = try? Date(name, strategy: Self.dayFormat), day < cutoff {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    public func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
    }
}

/// One line of a log file.
private enum Entry: Codable {
    case sample(Sample)
    case event(NetworkEvent)

    private enum CodingKeys: String, CodingKey {
        case sample = "s"
        case event = "e"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let sample = try container.decodeIfPresent(Sample.self, forKey: .sample) {
            self = .sample(sample)
        } else {
            self = .event(try container.decode(NetworkEvent.self, forKey: .event))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .sample(let sample): try container.encode(sample, forKey: .sample)
        case .event(let event): try container.encode(event, forKey: .event)
        }
    }

    var time: Date {
        switch self {
        case .sample(let sample): sample.time
        case .event(let event): event.time
        }
    }
}

extension Calendar {
    static let gmt: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()
}
