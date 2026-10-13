import Foundation

/// What the `wifiorisp` command prints when it isn't asked for JSON. Same words as the menu.
public enum CLIText {
    public static func status(_ status: CLIStatus) -> String {
        var lines = [status.verdict.headline, status.paused ? "Paused while a test runs." : status.verdict.detail, ""]
        var rows: [(String, String)] = []
        if let wifi = status.wifi {
            var radio = ["\(wifi.rssiDBm) dBm"]
            if let band = wifi.band { radio.append(band + (wifi.channel.map { " channel \($0)" } ?? "")) }
            if let generation = wifi.generation { radio.append(generation) }
            rows.append(("Wi-Fi signal", "\(wifi.signal) (\(radio.joined(separator: ", ")))"))
            rows.append(("Network", wifi.network ?? "Unknown (allow Location access in the app to see it)"))
        } else if status.link == Link.wired.rawValue {
            rows.append(("Network", "Wired"))
        }
        if status.link != Link.none.rawValue {
            rows.append(("Router", timing(status.router) + (status.routerMaker.map { " (\($0))" } ?? "")))
            if let provider = status.provider { rows.append(("Provider", provider)) }
            rows.append(("Internet", timing(status.internet)))
        }
        let width = rows.map(\.0.count).max() ?? 0
        lines += rows.map { $0.0.padding(toLength: width + 2, withPad: " ", startingAt: 0) + $0.1 }

        if !status.nextSteps.isEmpty {
            lines += ["", "What to do"]
            for (index, step) in status.nextSteps.enumerated() {
                let target = step.command.map { "  → run: \($0)" } ?? step.url.map { "  → \($0)" } ?? ""
                lines.append("  \(index + 1). \(step.title)\(target)")
            }
        }
        for limit in status.limits {
            lines += ["", "Limit: \(limit.headline)", "  \(limit.detail)", "  → \(limit.url)"]
        }
        return lines.joined(separator: "\n")
    }

    /// One line per sample, for `watch`.
    public static func watchLine(_ status: CLIStatus) -> String {
        let time = (status.time ?? Date()).formatted(date: .omitted, time: .standard)
        var parts = [status.verdict.headline]
        if let wifi = status.wifi { parts.append("Wi-Fi \(wifi.signal) (\(wifi.rssiDBm) dBm)") }
        if status.link != Link.none.rawValue {
            parts.append("router \(timing(status.router))")
            parts.append("internet \(timing(status.internet))")
        }
        return "\(time)  " + parts.joined(separator: " · ")
    }

    public static func speed(_ result: SpeedTestResult) -> String {
        var line = "Download \(ISPReport.mbps(result.downloadMbps)), upload \(ISPReport.mbps(result.uploadMbps))"
        line += " (M-Lab server in \(result.server)"
        if let rtt = result.minRTTms { line += ", \(ISPReport.ms(rtt)) away" }
        return line + ")"
    }

    public static func lag(_ lag: CLILag) -> String {
        [
            lag.headline,
            lag.detail,
            "",
            "Responsiveness: \(lag.rpm) RPM (\(lag.grade))",
            "Idle \(ISPReport.ms(lag.idleMs)), under load \(ISPReport.ms(lag.loadedMs))",
            "Throughput during the test: \(ISPReport.mbps(lag.downloadMbps)) down, "
                + "\(ISPReport.mbps(lag.uploadMbps)) up",
            "Server: \(lag.server)"
        ].joined(separator: "\n")
    }

    /// A summary of the log, then what happened in it.
    public static func history(_ log: Log, start: Date, end: Date) -> String {
        guard !log.samples.isEmpty else {
            return "No measurements since \(when(start)). Is WiFi or ISP running?"
        }
        let summary = ReportSummary(log: log, start: start, end: end)
        var lines = ["Since \(when(start)): \(summary.sampleCount) measurements"
            + (summary.networks.isEmpty ? "" : " on \(summary.networks.joined(separator: ", "))")]
        if let router = summary.routerMedianMs { lines.append("Router: typically \(ISPReport.ms(router))") }
        if let internet = summary.internetMedianMs {
            var line = "Internet: typically \(ISPReport.ms(internet))"
            if let p95 = summary.internetP95Ms { line += ", \(ISPReport.ms(p95)) at its slowest 5%" }
            if summary.internetLoss > 0 { line += ", \(ISPReport.percent(summary.internetLoss)) of checks unanswered" }
            lines.append(line)
        }
        lines.append("Slow on the ISP's side \(ISPReport.percent(summary.ispSlowShare)) of the time, "
            + "on your side \(ISPReport.percent(summary.yourSideSlowShare))")

        let described = events(log.events)
        lines += ["", described.isEmpty ? "No drops, roams, or tests." : "What happened"]
        lines += described.map { "  \(when($0.time))  \($0.text)" }
        return lines.joined(separator: "\n")
    }

    /// Events in plain words. A drop that ended is one line; one still going is shown as it started.
    static func events(_ events: [NetworkEvent]) -> [(time: Date, text: String)] {
        var lines: [(time: Date, text: String)] = []
        for (index, event) in events.enumerated() {
            if case .dropStarted = event.kind {
                let ended = events[(index + 1)...].contains { if case .dropEnded = $0.kind { true } else { false } }
                if !ended { lines.append((event.time, "Internet dropped, and hasn't come back yet")) }
            } else if case .dropEnded(let since, let routerAnswered) = event.kind {
                let side = switch routerAnswered {
                case true?: " (router kept answering: ISP's side)"
                case false?: " (router stopped answering too: your side)"
                case nil: ""
                }
                let duration = ISPReport.format(.seconds(event.time.timeIntervalSince(since)))
                lines.append((since, "Internet dropped for \(duration)\(side)"))
            } else if let text = describe(event.kind) {
                lines.append((event.time, text))
            }
        }
        return lines.sorted { $0.time < $1.time }
    }

    private static func describe(_ kind: NetworkEvent.Kind) -> String? {
        switch kind {
        case .roamed(_, _, let from, let to): "Switched access point (\(from) → \(to) dBm)"
        case .bandChanged(let from, let to): "Moved from \(from.label) to \(to.label)"
        case .networkChanged(let from, let to): "Changed network from \(from ?? "none") to \(to ?? "none")"
        case .speedTest(let result): "Speed test: " + speed(result)
        case .responsiveness(let result): "Lag test: \(result.headline), \(result.rpm) RPM"
        case .dropStarted, .dropEnded: nil
        }
    }

    static func timing(_ timing: CLIStatus.Timing) -> String {
        timing.ms.map { "\(timing.rating) · \(Int($0.rounded())) ms" } ?? timing.rating
    }

    private static func when(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
