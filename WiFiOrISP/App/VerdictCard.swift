import PanelKit
import SwiftUI
import WiFiOrISPCore

/// The top of the menu: the verdict, why, and the numbers behind it. Follows the live monitor.
struct VerdictCard: View {
    @ObservedObject var monitor: MonitorController
    @ObservedObject var location: LocationAccess
    /// Runs a next step: opens a guide, starts a test, or exports the report.
    let perform: (NextStep.Action) -> Void

    var body: some View {
        let context = monitor.adviceContext
        BrushedCard(
            snapshot: CardSnapshot(
                verdict: monitor.verdict,
                latest: monitor.latest,
                isPaused: monitor.isPaused,
                provider: monitor.provider,
                maker: monitor.maker,
                locationAuthorized: location.isAuthorized,
                steps: Array(Advice.steps(context).prefix(4)),
                ceilings: Array(Advice.ceilings(context).prefix(2))
            ),
            perform: perform
        )
    }
}

/// Everything the card shows at one moment.
struct CardSnapshot {
    var verdict: WiFiOrISPCore.Verdict
    var latest: Sample?
    var isPaused: Bool
    var provider: Provider?
    var maker: RouterMaker?
    var locationAuthorized: Bool
    var steps: [NextStep]
    var ceilings: [Ceiling]

    /// "Office-5G", "Wired", or why there's no name.
    var networkName: String? {
        guard let sample = latest else { return nil }
        switch sample.link {
        case .wifi: return sample.wifi?.ssid ?? (locationAuthorized ? "Hidden network" : "Unknown network")
        case .wired: return "Wired"
        case .none: return "Not connected"
        }
    }
}

/// The Brushed card: twin meters for router and internet, the verdict, readings, what to do,
/// plan notices and the raw numbers.
struct BrushedCard: View {
    let snapshot: CardSnapshot
    let perform: (NextStep.Action) -> Void

    var body: some View {
        MenuCard(accent: PanelAccent.wifiOrISP) {
            CardBody(snapshot: snapshot, perform: perform)
        }
    }
}

/// The card's contents, drawn with the theme `MenuCard` sets.
private struct CardBody: View {
    let snapshot: CardSnapshot
    let perform: (NextStep.Action) -> Void

    @Environment(\.panelTheme) private var theme

    var body: some View {
        Fascia(nameplate: "Link", timestamp: snapshot.networkName) {
            TwinMeters(left: Self.channel(.router, snapshot.latest?.router),
                       right: Self.channel(.internet, snapshot.latest?.internet))
        }
        VerdictView(
            snapshot.verdict.headline,
            message: snapshot.isPaused ? "Paused while a test runs." : snapshot.verdict.detail,
            status: CardStatus.status(for: snapshot.verdict),
            statusLabel: CardStatus.word(for: snapshot.verdict)
        )
        Readings(rows: readings)
        if !snapshot.isPaused {
            if !snapshot.steps.isEmpty {
                SectionHeader("What to do")
                NumberedSteps(snapshot.steps.map(numberedStep))
            }
            ForEach(snapshot.ceilings, id: \.kind) { ceiling in
                Notice(ceiling.headline, message: ceiling.detail) {
                    Button("See what fixes this ›") { perform(.page(ceiling.recommendation)) }
                        .accessibilityHint("Opens a guide on wifiorisp.com")
                }
            }
        }
        if let details {
            Text(details)
                .font(PanelFont.body(10.5))
                .monospacedDigit()
                .foregroundStyle(theme.sub)
                .fixedSize(horizontal: false, vertical: true)
                .padding(EdgeInsets(top: 6, leading: 14, bottom: 12, trailing: 14))
        }
    }

    private func numberedStep(_ step: NextStep) -> NumberedStep {
        guard let action = step.action else { return NumberedStep(step.title) }
        let opensPage = if case .page = action { true } else { false }
        let hint = switch action {
        case .page: "Opens a guide on wifiorisp.com"
        case .runSpeedTest, .runLagTest: "Opens the Tests window"
        case .exportReport: "Exports a report for your ISP"
        }
        return NumberedStep(step.title, opensPage: opensPage, hint: hint) { perform(action) }
    }

    // MARK: - Meters

    private enum Side {
        case router, internet
    }

    /// 0 to 200 ms across the scale, red from 100 ms. No answer pins the needle past the end.
    private static let scale = MeterConfig.twin(
        zones: [0.5...1],
        labels: [.init(0, "0"), .init(0.25, "50"), .init(0.5, "100"), .init(1, "200")],
        word: "MS",
        accessibilityLabel: "Response time"
    )

    private static func channel(_ side: Side, _ probe: Probe?) -> MeterChannel {
        var config = scale
        config.accessibilityLabel = side == .router ? "Router meter" : "Internet meter"
        let value: Double
        let spoken: String
        switch probe {
        case .reply(let ms):
            value = ms / 200
            spoken = "\(Int(ms.rounded())) milliseconds"
        case .lost:
            value = 1.02
            spoken = "No answer"
        case nil:
            value = 0
            spoken = "Not measured"
        }
        return MeterChannel(
            config, value: value, accessibilityValue: spoken,
            label: side == .router ? "Router" : "Internet",
            detail: side == .router ? "Your side" : "Their side"
        )
    }

    // MARK: - Readings

    private var readings: [Reading] {
        guard let sample = snapshot.latest, sample.link != .none else { return [] }
        var rows: [Reading] = []
        if sample.link == .wifi, let wifi = sample.wifi {
            rows.append(Reading("Wi-Fi signal", PlainLanguage.signal(rssi: wifi.rssi, snr: wifi.snr)))
        }
        rows.append(Reading("Network", snapshot.networkName ?? ""))
        rows.append(Self.speed("Router", sample.router, rate: PlainLanguage.router))
        if let provider = snapshot.provider?.name {
            rows.append(Reading("Provider", provider))
        }
        rows.append(Self.speed("Internet", sample.internet, rate: PlainLanguage.internet))
        return rows
    }

    private static func speed(_ label: String, _ probe: Probe?, rate: (Double) -> PlainLanguage.Speed) -> Reading {
        let slow: Bool = switch probe {
        case .reply(let ms): rate(ms) == .slow
        case .lost: true
        case nil: false
        }
        return Reading(label, Format.speed(probe, rate: rate), hot: slow)
    }

    /// The raw numbers, for people who want them.
    private var details: String? {
        guard let wifi = snapshot.latest?.wifi, snapshot.latest?.link == .wifi else { return nil }
        var parts = ["Signal \(wifi.rssi) dBm", "noise \(wifi.noise) dBm"]
        if let generation = wifi.generationLabel {
            parts.append(generation)
        }
        if let maker = snapshot.maker {
            parts.append("\(maker.name) router")
        }
        if let band = wifi.band {
            parts.append(band.label + (wifi.channel.map { " channel \($0)" } ?? ""))
        }
        parts.append("link rate \(Int(wifi.txRate.rounded())) Mbps")
        // Keep numbers with their units when the caption wraps.
        return parts.joined(separator: " · ").replacingOccurrences(of: " GHz", with: "\u{00A0}GHz")
    }
}

/// The status light beside the headline: colour plus a word, never colour alone.
enum CardStatus {
    static func status(for verdict: WiFiOrISPCore.Verdict) -> PanelStatus {
        switch verdict.kind {
        case .good: .go
        case .goodWeakSignal: .caution
        case .measuring: .off
        default: verdict.side == .isp ? .caution : .stop
        }
    }

    static func word(for verdict: WiFiOrISPCore.Verdict) -> String {
        if let short = verdict.short { return short }
        switch verdict.kind {
        case .measuring: return "Measuring"
        case .goodWeakSignal: return "Weak signal"
        default: return "Fine"
        }
    }
}

private struct Reading {
    var label: String
    var value: String
    var hot = false

    init(_ label: String, _ value: String, hot: Bool = false) {
        self.label = label
        self.value = value
        self.hot = hot
    }
}

/// Label and value pairs, two columns.
private struct Readings: View {
    let rows: [Reading]

    @Environment(\.panelTheme) private var theme

    var body: some View {
        if !rows.isEmpty {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
                ForEach(rows, id: \.label) { row in
                    GridRow {
                        Text(row.label).foregroundStyle(theme.sub)
                        Text(row.value)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundStyle(row.hot ? theme.caution : theme.ink)
                    }
                }
            }
            .font(PanelFont.body(12))
            .padding(EdgeInsets(top: 2, leading: 14, bottom: 10, trailing: 14))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

enum Format {
    /// "Fast · 7 ms", or what happened instead.
    static func speed(_ probe: Probe?, rate: (Double) -> PlainLanguage.Speed) -> String {
        switch probe {
        case .reply(let ms): "\(rate(ms).rawValue) · \(Int(ms.rounded())) ms"
        case .lost: "No answer"
        case nil: "Not measured"
        }
    }
}
