import Foundation

/// Something that happened, for the timeline, the ISP report, and alerts.
public struct NetworkEvent: Codable, Equatable, Sendable {
    public enum Kind: Codable, Equatable, Sendable {
        /// The internet stopped answering.
        case dropStarted
        /// The internet came back. `routerAnswered` says whether the router kept answering
        /// throughout: true puts the outage on the ISP's side, false on yours, nil if unknown.
        case dropEnded(since: Date, routerAnswered: Bool?)
        case roamed(fromBSSID: String?, toBSSID: String?, fromRSSI: Int, toRSSI: Int)
        case bandChanged(from: Band, to: Band)
        case networkChanged(from: String?, to: String?)
        case speedTest(SpeedTestResult)
        case responsiveness(ResponsivenessResult)
    }

    public var time: Date
    public var kind: Kind

    public init(time: Date, kind: Kind) {
        self.time = time
        self.kind = kind
    }

    public var dropDuration: TimeInterval? {
        if case .dropEnded(let since, _) = kind { time.timeIntervalSince(since) } else { nil }
    }
}

/// Watches the stream of samples for drops, roaming, and band changes.
public struct EventDetector: Sendable {
    /// Consecutive lost internet probes (or samples with no connection) that make a drop.
    public static let lostToDrop = 2
    /// A roam counts as "to a weaker access point" when the new signal is this much worse
    /// than the old access point's typical signal.
    public static let weakerByDB = 6

    private var previous: Sample?
    private var lostRun: [Sample] = []
    private var dropStart: Date?
    private var routerAnsweredDuringDrop: Bool?
    /// Recent signal on the current access point, to judge a roam against its typical level
    /// rather than the dip that usually comes right before roaming.
    private var recentRSSI: [Int] = []

    public init() {}

    public var isDropped: Bool { dropStart != nil }

    /// Ends an open drop, for when monitoring stops (sleep, a test, quitting) before the internet
    /// is seen coming back. Logging the end keeps the outage from looking like it never ended.
    public mutating func close(at time: Date) -> NetworkEvent? {
        guard let start = dropStart else { return nil }
        dropStart = nil
        lostRun = []
        let ended = NetworkEvent.Kind.dropEnded(since: start, routerAnswered: routerAnsweredDuringDrop)
        return NetworkEvent(time: max(time, start), kind: ended)
    }

    public mutating func process(_ sample: Sample) -> [NetworkEvent] {
        var events = dropEvents(sample)
        if let previous, let old = previous.wifi, let new = sample.wifi, previous.link == .wifi, sample.link == .wifi {
            events += wifiEvents(old: old, new: new, time: sample.time)
        } else if sample.wifi == nil {
            recentRSSI = []
        }
        if let rssi = sample.wifi?.rssi {
            recentRSSI = Array((recentRSSI + [rssi]).suffix(6))
        }
        previous = sample
        return events
    }

    private mutating func dropEvents(_ sample: Sample) -> [NetworkEvent] {
        let lost = sample.link == .none || sample.internet?.isLost == true
        guard lost else {
            lostRun = []
            guard let start = dropStart else { return [] }
            dropStart = nil
            let ended = NetworkEvent.Kind.dropEnded(since: start, routerAnswered: routerAnsweredDuringDrop)
            return [NetworkEvent(time: sample.time, kind: ended)]
        }
        lostRun.append(sample)
        if dropStart != nil {
            noteRouter(sample)
            return []
        }
        guard lostRun.count >= Self.lostToDrop, let first = lostRun.first else { return [] }
        dropStart = first.time
        routerAnsweredDuringDrop = nil
        lostRun.forEach { noteRouter($0) }
        return [NetworkEvent(time: first.time, kind: .dropStarted)]
    }

    private mutating func noteRouter(_ sample: Sample) {
        if sample.link == .none {
            routerAnsweredDuringDrop = false
            return
        }
        switch sample.router {
        case .reply: routerAnsweredDuringDrop = routerAnsweredDuringDrop ?? true
        case .lost: routerAnsweredDuringDrop = false
        case nil: break
        }
    }

    private mutating func wifiEvents(old: WiFiReading, new: WiFiReading, time: Date) -> [NetworkEvent] {
        if old.ssid != new.ssid, old.ssid != nil || new.ssid != nil {
            recentRSSI = []
            return [NetworkEvent(time: time, kind: .networkChanged(from: old.ssid, to: new.ssid))]
        }
        var events: [NetworkEvent] = []
        // Without Location access there's no BSSID; a channel change on the same network
        // is the best sign of a roam.
        let roamed = if let oldBSSID = old.bssid, let newBSSID = new.bssid {
            oldBSSID != newBSSID
        } else {
            old.channel != nil && old.channel != new.channel
        }
        if roamed {
            let typical = Statistics.median(recentRSSI.map(Double.init)).map { Int($0.rounded()) } ?? old.rssi
            events.append(NetworkEvent(
                time: time,
                kind: .roamed(fromBSSID: old.bssid, toBSSID: new.bssid, fromRSSI: typical, toRSSI: new.rssi)
            ))
            recentRSSI = []
        }
        if let from = old.band, let to = new.band, from != to {
            events.append(NetworkEvent(time: time, kind: .bandChanged(from: from, to: to)))
        }
        return events
    }
}

/// Which events are worth a notification.
public enum AlertKind: String, CaseIterable, Sendable {
    case drop
    case fellTo24GHz
    case roamedWeaker
}

extension NetworkEvent {
    public var alertKind: AlertKind? {
        switch kind {
        case .dropStarted, .dropEnded: .drop
        case .bandChanged(_, let to): to == .ghz2 ? .fellTo24GHz : nil
        case .roamed(_, _, let from, let to): to <= from - EventDetector.weakerByDB ? .roamedWeaker : nil
        default: nil
        }
    }
}
