import Foundation

/// Samples squeezed into evenly spaced buckets, so a month of history charts as fast as an hour.
public struct TimelinePoint: Identifiable, Equatable, Sendable {
    public var start: Date
    public var routerMs: Double?
    public var internetMs: Double?
    /// The weakest signal in the bucket: dips matter more than averages.
    public var rssi: Int?
    /// Share of internet probes lost, 0...1.
    public var internetLoss: Double

    public var id: Date { start }
}

public enum Timeline {
    public static func points(_ samples: [Sample], from start: Date, to end: Date, buckets: Int = 300) -> [TimelinePoint] {
        guard end > start, buckets > 0 else { return [] }
        let width = end.timeIntervalSince(start) / Double(buckets)
        var grouped: [Int: [Sample]] = [:]
        for sample in samples where sample.time >= start && sample.time <= end {
            let index = min(buckets - 1, Int(sample.time.timeIntervalSince(start) / width))
            grouped[index, default: []].append(sample)
        }
        return grouped.keys.sorted().map { index in
            let group = grouped[index] ?? []
            let internet = group.compactMap(\.internet)
            return TimelinePoint(
                start: start.addingTimeInterval(Double(index) * width),
                routerMs: Statistics.median(group.compactMap { $0.router?.ms }),
                internetMs: Statistics.median(internet.compactMap(\.ms)),
                rssi: group.compactMap { $0.wifi?.rssi }.min(),
                internetLoss: internet.isEmpty ? 0 : Double(internet.filter(\.isLost).count) / Double(internet.count)
            )
        }
    }
}
