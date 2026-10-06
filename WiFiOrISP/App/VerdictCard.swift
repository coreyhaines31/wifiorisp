import SwiftUI
import WiFiOrISPCore

/// The top of the menu: the verdict, why, and the numbers behind it.
struct VerdictCard: View {
    @ObservedObject var monitor: MonitorController
    @ObservedObject var location: LocationAccess

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
        rows.append(Row(label: "Internet", value: Format.speed(sample.internet, rate: PlainLanguage.internet)))
        return rows
    }

    /// The raw numbers, for people who want them.
    private var details: String? {
        guard let wifi = monitor.latest?.wifi, monitor.latest?.link == .wifi else { return nil }
        var parts = ["Signal \(wifi.rssi) dBm", "noise \(wifi.noise) dBm"]
        if let band = wifi.band {
            parts.append(band.label + (wifi.channel.map { " channel \($0)" } ?? ""))
        }
        parts.append("link rate \(Int(wifi.txRate.rounded())) Mbps")
        return parts.joined(separator: " · ")
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
