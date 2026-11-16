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

    /// Menu width; the card sits inside it with the menu's own inset.
    static let width: CGFloat = 340
    static let inset: CGFloat = 5

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = PanelTheme.resolve(colorScheme)
        VStack(alignment: .leading, spacing: 0) {
            Fascia(nameplate: "Link", timestamp: snapshot.networkName) {
                TwinMeters(left: Self.channel(.router, snapshot.latest?.router),
                           right: Self.channel(.internet, snapshot.latest?.internet))
            }
            BrushedVerdict(
                snapshot.verdict.headline,
                message: snapshot.isPaused ? "Paused while a test runs." : snapshot.verdict.detail,
                status: CardStatus.status(for: snapshot.verdict),
                statusLabel: CardStatus.word(for: snapshot.verdict)
            )
            Readings(rows: readings, theme: theme)
            if !snapshot.isPaused {
                if !snapshot.steps.isEmpty {
                    SectionHeader("What to do")
                    NextSteps(steps: snapshot.steps, theme: theme, perform: perform)
                }
                ForEach(snapshot.ceilings, id: \.kind) { ceiling in
                    CeilingNotice(ceiling: ceiling, theme: theme, perform: perform)
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
        .frame(width: Self.width - Self.inset * 2, alignment: .leading)
        .background(theme.background)
        .foregroundStyle(theme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.black.opacity(theme.isDark ? 0.5 : 0.12), lineWidth: 1)
        )
        .panelAccent(PanelAccent.wifiOrISP)
        .padding(.horizontal, Self.inset)
        .padding(.bottom, Self.inset)
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
    let theme: PanelTheme

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

/// Blue for things you can click, as on the approved card.
private func linkColor(_ theme: PanelTheme) -> Color {
    theme.isDark ? Color(red: 0.56, green: 0.69, blue: 1) : Color(red: 0.18, green: 0.39, blue: 0.83)
}

/// "What to do": numbered next steps; the ones with an action are links.
private struct NextSteps: View {
    let steps: [NextStep]
    let theme: PanelTheme
    let perform: (NextStep.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                if let action = step.action {
                    Button { perform(action) } label: { row(index, step, action: action) }
                        .buttonStyle(.plain)
                        .accessibilityHint(Self.hint(for: action))
                } else {
                    row(index, step, action: nil)
                }
            }
        }
        .font(PanelFont.body(12))
        .padding(EdgeInsets(top: 0, leading: 14, bottom: 8, trailing: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ index: Int, _ step: NextStep, action: NextStep.Action?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(index + 1).")
                .monospacedDigit()
                .foregroundStyle(theme.sub)
                .frame(width: 12, alignment: .trailing)
            Text(step.title + (Self.opensPage(action) ? " ↗" : ""))
                .foregroundStyle(action == nil ? theme.ink : linkColor(theme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .contentShape(Rectangle())
    }

    private static func opensPage(_ action: NextStep.Action?) -> Bool {
        if case .page = action { true } else { false }
    }

    private static func hint(for action: NextStep.Action) -> String {
        switch action {
        case .page: "Opens a guide on wifiorisp.com"
        case .runSpeedTest, .runLagTest: "Opens the Tests window"
        case .exportReport: "Exports a report for your ISP"
        }
    }
}

/// A limit no setting fixes, with a link to what would.
private struct CeilingNotice: View {
    let ceiling: Ceiling
    let theme: PanelTheme
    let perform: (NextStep.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ceiling.headline)
                .font(PanelFont.body(12, .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(ceiling.detail)
                .font(PanelFont.body(11.5))
                .foregroundStyle(theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            Button { perform(.page(ceiling.recommendation)) } label: {
                Text("See what fixes this ›")
                    .font(PanelFont.body(12))
                    .foregroundStyle(linkColor(theme))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens a guide on wifiorisp.com")
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.caution.opacity(0.13), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(theme.caution.opacity(0.35), lineWidth: 1))
        .padding(EdgeInsets(top: 4, leading: 14, bottom: 10, trailing: 14))
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
