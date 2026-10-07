import SwiftUI
import WiFiOrISPCore

/// The top of the menu: the verdict, why, and the numbers behind it.
struct VerdictCard: View {
    @ObservedObject var monitor: MonitorController
    @ObservedObject var location: LocationAccess
    /// Runs a next step: opens a guide, starts a test, or exports the report.
    let perform: (NextStep.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(Format.color(for: monitor.verdict))
                    .frame(width: 9, height: 9)
                    .accessibilityHidden(true)
                Text(monitor.verdict.headline)
                    .font(.headline)
            }
            Text(monitor.isPaused ? "Paused while a test runs." : monitor.verdict.detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
                ForEach(rows, id: \.label) { row in
                    GridRow {
                        Text(row.label).foregroundStyle(.secondary)
                        Text(row.value).monospacedDigit()
                    }
                }
            }
            .font(.callout)

            if !monitor.isPaused {
                let context = monitor.adviceContext
                NextSteps(steps: Array(Advice.steps(context).prefix(4)), perform: perform)
                ForEach(Array(Advice.ceilings(context).prefix(2)), id: \.kind) { ceiling in
                    CeilingNotice(ceiling: ceiling, perform: perform)
                }
            }

            if let details {
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 320, alignment: .leading)
    }

    private struct Row {
        var label: String
        var value: String
    }

    private var rows: [Row] {
        guard let sample = monitor.latest, sample.link != .none else { return [] }
        var rows: [Row] = []
        if sample.link == .wifi {
            if let wifi = sample.wifi {
                rows.append(Row(label: "Wi-Fi signal", value: PlainLanguage.signal(rssi: wifi.rssi, snr: wifi.snr)))
            }
            let name = sample.wifi?.ssid ?? (location.isAuthorized ? "Hidden network" : "Unknown network")
            rows.append(Row(label: "Network", value: name))
        } else {
            rows.append(Row(label: "Network", value: "Wired"))
        }
        rows.append(Row(label: "Router", value: Format.speed(sample.router, rate: PlainLanguage.router)))
        if let provider = monitor.provider?.name {
            rows.append(Row(label: "Provider", value: provider))
        }
        rows.append(Row(label: "Internet", value: Format.speed(sample.internet, rate: PlainLanguage.internet)))
        return rows
    }

    /// The raw numbers, for people who want them.
    private var details: String? {
        guard let wifi = monitor.latest?.wifi, monitor.latest?.link == .wifi else { return nil }
        var parts = ["Signal \(wifi.rssi) dBm", "noise \(wifi.noise) dBm"]
        if let generation = wifi.generationLabel {
            parts.append(generation)
        }
        if let maker = monitor.maker {
            parts.append("\(maker.name) router")
        }
        if let band = wifi.band {
            parts.append(band.label + (wifi.channel.map { " channel \($0)" } ?? ""))
        }
        parts.append("link rate \(Int(wifi.txRate.rounded())) Mbps")
        return parts.joined(separator: " · ")
    }
}

/// "What to do": the next steps for the current verdict, each one a button.
private struct NextSteps: View {
    let steps: [NextStep]
    let perform: (NextStep.Action) -> Void

    var body: some View {
        if !steps.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("What to do").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    if let action = step.action {
                        Button { perform(action) } label: { row(index, step.title, link: true) }
                            .buttonStyle(.plain)
                    } else {
                        row(index, step.title, link: false)
                    }
                }
            }
        }
    }

    private func row(_ index: Int, _ title: String, link: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(index + 1).").foregroundStyle(.secondary).monospacedDigit()
            Text(title).foregroundStyle(link ? Color.accentColor : .primary)
            if link {
                Image(systemName: "arrow.up.forward").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .contentShape(Rectangle())
    }
}

/// A limit no setting fixes, with a link to what would.
private struct CeilingNotice: View {
    let ceiling: Ceiling
    let perform: (NextStep.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ceiling.headline).font(.callout.weight(.semibold))
            Text(ceiling.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button("See what fixes this") { perform(.page(ceiling.recommendation)) }
                .buttonStyle(.link)
                .font(.caption)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
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

    static func color(for verdict: Verdict) -> Color {
        switch verdict.kind {
        case .good: .green
        case .goodWeakSignal: .yellow
        case .measuring: .gray
        default: verdict.side == .isp ? .orange : .red
        }
    }
}
