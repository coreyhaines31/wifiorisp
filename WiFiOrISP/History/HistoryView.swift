import Charts
import SwiftUI
import WiFiOrISPCore

/// The timeline: latency to the router and the internet, signal, and what happened.
@MainActor
final class HistoryModel: ObservableObject {
    enum Range: String, CaseIterable, Identifiable {
        case hour = "1 Hour"
        case sixHours = "6 Hours"
        case day = "24 Hours"
        case week = "7 Days"
        case month = "30 Days"

        var id: String { rawValue }

        var seconds: TimeInterval {
            switch self {
            case .hour: 3600
            case .sixHours: 6 * 3600
            case .day: 86400
            case .week: 7 * 86400
            case .month: 30 * 86400
            }
        }
    }

    @Published var range: Range = .hour {
        didSet { reload() }
    }
    @Published private(set) var points: [TimelinePoint] = []
    @Published private(set) var events: [NetworkEvent] = []
    @Published private(set) var summary: ReportSummary?
    @Published private(set) var start = Date()
    @Published private(set) var end = Date()

    let store: LogStore

    init(store: LogStore) {
        self.store = store
    }

    func reload() {
        let end = Date()
        let start = end.addingTimeInterval(-range.seconds)
        let store = store
        Task {
            let result = await Task.detached {
                let log = store.load(from: start, to: end)
                let points = Timeline.points(log.samples, from: start, to: end)
                return (points, log.events, ReportSummary(log: log, start: start, end: end))
            }.value
            self.start = start
            self.end = end
            points = result.0
            events = result.1
            summary = result.2
        }
    }
}

struct HistoryView: View {
    @ObservedObject var model: HistoryModel
    let exportReport: () -> Void
    let exportCSV: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Picker("Range", selection: $model.range) {
                    ForEach(HistoryModel.Range.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 380)
                Spacer()
                Button("Export CSV…", action: exportCSV)
                Button("Export Report for Your ISP…", action: exportReport)
                    .buttonStyle(.borderedProminent)
            }

            if let summary = model.summary {
                summaryRow(summary)
            }

            if model.points.isEmpty {
                ContentUnavailableView(
                    "No history yet", systemImage: "chart.xyaxis.line",
                    description: Text("Measurements show up here as they're taken.")
                )
                .frame(maxHeight: .infinity)
            } else {
                Text("Round trip (ms)").font(.headline)
                latencyChart.frame(height: 200)
                Text("Wi-Fi signal (dBm)").font(.headline)
                signalChart.frame(height: 120)
            }

            if !model.events.isEmpty {
                Text("Events").font(.headline)
                List(Array(model.events.reversed().enumerated()), id: \.offset) { _, event in
                    HStack(alignment: .firstTextBaseline) {
                        Text(event.time.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                            .frame(width: 150, alignment: .leading)
                        Text(Self.describe(event))
                    }
                    .font(.callout)
                }
                .frame(minHeight: 120)
            }
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 640, alignment: .top)
        .onAppear { model.reload() }
    }

    private func summaryRow(_ summary: ReportSummary) -> some View {
        HStack(spacing: 24) {
            stat("Outages", "\(summary.outages.count)")
            stat("ISP side slow", ISPReport.percent(summary.ispSlowShare))
            stat("Your side slow", ISPReport.percent(summary.yourSideSlowShare))
            stat("Router", summary.routerMedianMs.map(ISPReport.ms) ?? "–")
            stat("Internet", summary.internetMedianMs.map(ISPReport.ms) ?? "–")
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title2.monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var latencyChart: some View {
        Chart {
            ForEach(model.points.filter { $0.internetLoss >= 0.5 }) { point in
                RectangleMark(
                    xStart: .value("Time", point.start),
                    xEnd: .value("Time", point.start.addingTimeInterval(bucketWidth)),
                    yStart: nil, yEnd: nil
                )
                .foregroundStyle(.red.opacity(0.18))
            }
            ForEach(model.points) { point in
                if let ms = point.internetMs {
                    line(point, ms: ms, probe: "Internet")
                }
                if let ms = point.routerMs {
                    line(point, ms: ms, probe: "Router")
                }
            }
        }
        .chartForegroundStyleScale(["Internet": Color.orange, "Router": Color.blue])
        .chartXScale(domain: model.start...model.end)
        .chartYScale(domain: 0...yCap)
    }

    private func line(_ point: TimelinePoint, ms: Double, probe: String) -> some ChartContent {
        LineMark(x: .value("Time", point.start), y: .value("ms", min(ms, yCap)), series: .value("Probe", probe))
            .foregroundStyle(by: .value("Probe", probe))
            .symbol(.circle)
            .symbolSize(isSparse ? 20 : 0)
    }

    /// With only a few points, lines alone can be invisible; mark each point too.
    private var isSparse: Bool { model.points.count < 30 }

    private var signalChart: some View {
        Chart(model.points.filter { $0.rssi != nil }) { point in
            LineMark(x: .value("Time", point.start), y: .value("dBm", point.rssi ?? 0))
                .foregroundStyle(.teal)
                .symbol(.circle)
                .symbolSize(isSparse ? 20 : 0)
        }
        .chartXScale(domain: model.start...model.end)
        .chartYScale(domain: -90 ... -30)
    }

    private var bucketWidth: TimeInterval {
        model.end.timeIntervalSince(model.start) / 300
    }

    /// Keeps one huge spike from flattening the rest of the chart.
    private var yCap: Double {
        let values = model.points.compactMap(\.internetMs) + model.points.compactMap(\.routerMs)
        return max(50, (Statistics.percentile(values, 0.98) ?? 50) * 1.2)
    }

    static func describe(_ event: NetworkEvent) -> String {
        switch event.kind {
        case .dropStarted:
            return "Internet dropped"
        case .dropEnded(_, let routerAnswered):
            let duration = ISPReport.format(.seconds(event.dropDuration ?? 0))
            let side = switch routerAnswered {
            case true: "router answered throughout (ISP side)"
            case false: "router or Wi-Fi was down too (your side)"
            case nil: "router not measured"
            }
            return "Back online after \(duration), \(side)"
        case .roamed(_, _, let from, let to):
            return "Roamed to another access point (\(from) → \(to) dBm)"
        case .bandChanged(let from, let to):
            return "Band changed from \(from.label) to \(to.label)"
        case .networkChanged(let from, let to):
            return "Network changed from \(from ?? "unknown") to \(to ?? "unknown")"
        case .speedTest(let result):
            return "Speed test: \(ISPReport.mbps(result.downloadMbps)) down, \(ISPReport.mbps(result.uploadMbps)) up"
        case .responsiveness(let result):
            return "Lag under load: \(result.rpm) RPM (\(result.grade.rawValue))"
        }
    }
}
