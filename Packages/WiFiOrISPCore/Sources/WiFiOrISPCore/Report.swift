import Foundation

/// The numbers behind an ISP report, so they can be tested apart from the wording.
public struct ReportSummary: Equatable, Sendable {
    public struct Outage: Equatable, Sendable {
        public var start: Date
        /// Nil while the outage is still going on.
        public var end: Date?
        public var routerAnswered: Bool?

        public func duration(now: Date) -> TimeInterval {
            (end ?? now).timeIntervalSince(start)
        }
    }

    public var start: Date
    public var end: Date
    public var sampleCount: Int
    public var outages: [Outage]
    /// Share of measured time each side was the problem, 0...1.
    public var ispSlowShare: Double
    public var yourSideSlowShare: Double
    public var routerMedianMs: Double?
    public var internetMedianMs: Double?
    public var internetP95Ms: Double?
    public var internetLoss: Double
    public var networks: [String]
    public var speedTests: [SpeedTestResult]
    public var responsiveness: [ResponsivenessResult]

    /// Gaps longer than this (sleep, app not running) don't count as measured time.
    static let maxGap: TimeInterval = 120

    public init(log: Log, start: Date, end: Date) {
        self.start = start
        self.end = end
        sampleCount = log.samples.count
        outages = Self.outages(log.events, samples: log.samples)
        (ispSlowShare, yourSideSlowShare) = Self.slowShares(log.samples)

        let samples = log.samples
        routerMedianMs = Statistics.median(samples.compactMap { $0.router?.ms })
        let internet = samples.compactMap(\.internet)
        let internetMs = internet.compactMap(\.ms)
        internetMedianMs = Statistics.median(internetMs)
        internetP95Ms = Statistics.percentile(internetMs, 0.95)
        internetLoss = internet.isEmpty ? 0 : Double(internet.filter(\.isLost).count) / Double(internet.count)

        var seen = Set<String>()
        networks = samples.compactMap { $0.wifi?.ssid }.filter { seen.insert($0).inserted }
        speedTests = log.events.compactMap { if case .speedTest(let result) = $0.kind { result } else { nil } }
        responsiveness = log.events.compactMap {
            if case .responsiveness(let result) = $0.kind { result } else { nil }
        }
    }

    /// Pairs drop starts with their ends. A start with no end (the app quit mid-drop) ends at
    /// the first sample afterwards where the internet answered, so it can't run on forever.
    static func outages(_ events: [NetworkEvent], samples: [Sample]) -> [Outage] {
        func recovery(after start: Date) -> Date? {
            samples.first { $0.time > start && $0.internet?.ms != nil }?.time
        }
        var outages: [Outage] = []
        var openStart: Date?
        for event in events {
            switch event.kind {
            case .dropStarted:
                if let openStart {
                    let end = recovery(after: openStart) ?? event.time
                    outages.append(Outage(start: openStart, end: end, routerAnswered: nil))
                }
                openStart = event.time
            case .dropEnded(let since, let routerAnswered):
                outages.append(Outage(start: since, end: event.time, routerAnswered: routerAnswered))
                openStart = nil
            default:
                break
            }
        }
        if let openStart {
            // Never answered again: count it up to the last measurement, not to the end of the report.
            let lastSeen = samples.last.map(\.time).flatMap { $0 > openStart ? $0 : nil }
            outages.append(Outage(start: openStart, end: recovery(after: openStart) ?? lastSeen, routerAnswered: nil))
        }
        return outages
    }

    /// Replays the verdict over the log, weighting each sample by the time until the next one.
    private static func slowShares(_ samples: [Sample]) -> (isp: Double, yours: Double) {
        var ispTime = 0.0
        var yourTime = 0.0
        var measured = 0.0
        for index in samples.indices {
            let next = index + 1 < samples.count ? samples[index + 1].time : samples[index].time
            let weight = min(next.timeIntervalSince(samples[index].time), maxGap)
            guard weight > 0 else { continue }
            let window = Array(samples[max(0, index - VerdictEngine.window + 1)...index])
            measured += weight
            switch VerdictEngine.evaluate(window, now: samples[index].time).side {
            case .isp: ispTime += weight
            case .yours: yourTime += weight
            case nil: break
            }
        }
        guard measured > 0 else { return (0, 0) }
        return (ispTime / measured, yourTime / measured)
    }

    public var ispOutages: [Outage] { outages.filter { $0.routerAnswered == true } }

    public func totalDowntime(now: Date) -> TimeInterval {
        outages.reduce(0) { $0 + $1.duration(now: now) }
    }
}

/// A plain-text report to send an ISP: what happened, when, and why it's on their side.
public enum ISPReport {
    public static func text(
        log: Log, start: Date, end: Date, generated: Date = Date(), timeZone: TimeZone = .current, plan: Plan? = nil
    ) -> String {
        let summary = ReportSummary(log: log, start: start, end: end)
        let style = Date.FormatStyle(date: .abbreviated, time: .shortened, timeZone: timeZone)
        let when = { (date: Date) in date.formatted(style) }

        var lines = [
            "Connection report",
            String(repeating: "=", count: 17),
            "Period: \(when(start)) to \(when(end)) (\(timeZone.identifier))"
        ]
        if !summary.networks.isEmpty {
            lines.append("Network: \(summary.networks.joined(separator: ", "))")
        }
        lines.append("Generated by WiFi or ISP (wifiorisp.com) on \(when(generated))")
        lines.append("")

        guard summary.sampleCount > 0 else {
            lines.append("No measurements were taken in this period.")
            return lines.joined(separator: "\n") + "\n"
        }
        lines += summarySection(summary)
        lines += planSection(summary, plan: plan)
        lines += outagesSection(summary, when: when)
        lines += testsSection(summary, when: when)
        lines += methodSection(summary)
        return lines.joined(separator: "\n") + "\n"
    }

    private static func heading(_ title: String) -> [String] {
        [title, String(repeating: "-", count: title.count)]
    }

    private static func summarySection(_ summary: ReportSummary) -> [String] {
        var lines = heading("Summary")
        let downtime = Duration.seconds(summary.totalDowntime(now: summary.end))
        if summary.outages.isEmpty {
            lines.append("- Outages: none.")
        } else {
            lines.append("- Outages: \(summary.outages.count), \(format(downtime)) in total.")
            let isp = summary.ispOutages.count
            lines.append("  During \(isp) of them, my router kept answering while nothing past it did,")
            lines.append("  so the connection inside my home was working and the outage was on the ISP's side.")
        }
        lines.append("- Slow because of the ISP's side: \(percent(summary.ispSlowShare)) of the time measured.")
        lines.append("- Slow because of my home network: \(percent(summary.yourSideSlowShare)) of the time measured.")
        if let router = summary.routerMedianMs {
            lines.append("- Typical round trip to my router: \(ms(router)).")
        }
        if let internet = summary.internetMedianMs, let p95 = summary.internetP95Ms {
            lines.append("- Typical round trip to the internet: \(ms(internet)) (95th percentile \(ms(p95))).")
        }
        lines.append("- Internet probes lost: \(percent(summary.internetLoss)).")
        return lines + [""]
    }

    /// What the plan promises against what speed tests measured.
    private static func planSection(_ summary: ReportSummary, plan: Plan?) -> [String] {
        guard let plan else { return [] }
        var lines = heading("My plan")
        lines.append("- I pay for \(mbps(plan.downMbps)) down and \(mbps(plan.upMbps)) up.")
        if let download = Statistics.median(summary.speedTests.map(\.downloadMbps)),
           let upload = Statistics.median(summary.speedTests.map(\.uploadMbps)) {
            lines.append("- Speed tests in this period: typically \(mbps(download)) down "
                + "(\(percent(download / plan.downMbps)) of the plan) and \(mbps(upload)) up "
                + "(\(percent(upload / plan.upMbps))).")
        }
        return lines + [""]
    }

    private static func outagesSection(_ summary: ReportSummary, when: (Date) -> String) -> [String] {
        guard !summary.outages.isEmpty else { return [] }
        var lines = heading("Outages")
        for outage in summary.outages {
            let range = "\(when(outage.start)) to \(outage.end.map(when) ?? "ongoing")"
            let side = switch outage.routerAnswered {
            case true: "router answered throughout: ISP side"
            case false: "router or Wi-Fi was also down"
            case nil: "router not measured"
            }
            lines.append("- \(range), \(format(.seconds(outage.duration(now: summary.end)))) (\(side))")
        }
        return lines + [""]
    }

    private static func testsSection(_ summary: ReportSummary, when: (Date) -> String) -> [String] {
        var lines: [String] = []
        if !summary.speedTests.isEmpty {
            lines += heading("Speed tests (M-Lab NDT7)")
            for test in summary.speedTests {
                lines.append("- \(when(test.time)): \(mbps(test.downloadMbps)) down, \(mbps(test.uploadMbps)) up, "
                    + "server \(test.server)")
            }
            lines.append("")
        }
        if !summary.responsiveness.isEmpty {
            lines += heading("Lag under load (IETF responsiveness test)")
            for test in summary.responsiveness {
                lines.append("- \(when(test.time)): \(test.rpm) RPM (\(test.grade.rawValue)), round trips went from "
                    + "\(ms(test.idleLatencyMs)) to \(ms(test.loadedLatencyMs)) under load")
            }
            lines.append("")
        }
        return lines
    }

    private static func methodSection(_ summary: ReportSummary) -> [String] {
        heading("How this was measured") + [
            "Every 5 to 30 seconds, my Mac timed a TCP handshake to my router and, at the same moment, to",
            "1.1.1.1 and 8.8.8.8. A handshake is one network round trip. When the router answers quickly but",
            "the internet doesn't, the delay is past the router. An outage starts after two missed probes",
            "in a row. \(summary.sampleCount) measurements were taken in this period."
        ]
    }

    public static func format(_ duration: Duration) -> String {
        duration.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2))
    }

    public static func percent(_ share: Double) -> String {
        share > 0 && share < 0.001 ? "<0.1%" : share.formatted(.percent.precision(.fractionLength(0...1)))
    }

    public static func ms(_ value: Double) -> String { "\(Int(value.rounded())) ms" }

    public static func mbps(_ value: Double) -> String { "\(Int(value.rounded())) Mbps" }
}

/// Every sample as CSV, for spreadsheets.
public enum SampleCSV {
    public static let header = "time,link,network,access_point,band,channel,signal_dbm,noise_dbm,snr_db,tx_rate_mbps,"
        + "router_ms,router_lost,internet_ms,internet_lost"

    public static func text(_ samples: [Sample]) -> String {
        let time = Date.ISO8601FormatStyle(timeZone: .current)
        var lines = [header]
        for sample in samples {
            let wifi = sample.wifi
            let fields: [String] = [
                sample.time.formatted(time),
                sample.link.rawValue,
                escape(wifi?.ssid ?? ""),
                wifi?.bssid ?? "",
                wifi?.band?.rawValue ?? "",
                wifi?.channel.map(String.init) ?? "",
                wifi.map { String($0.rssi) } ?? "",
                wifi.map { String($0.noise) } ?? "",
                wifi.map { String($0.snr) } ?? "",
                wifi.map { String(Int($0.txRate.rounded())) } ?? "",
                probeMs(sample.router),
                probeLost(sample.router),
                probeMs(sample.internet),
                probeLost(sample.internet)
            ]
            lines.append(fields.joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func probeMs(_ probe: Probe?) -> String {
        probe?.ms.map { String(format: "%.1f", $0) } ?? ""
    }

    static func probeLost(_ probe: Probe?) -> String {
        probe.map { $0.isLost ? "1" : "0" } ?? ""
    }

    static func escape(_ field: String) -> String {
        // A leading = + - or @ would run as a formula in a spreadsheet.
        let field = field.first.map { "=+-@".contains($0) } == true ? "'" + field : field
        guard field.contains(where: { ",\"\n".contains($0) }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
