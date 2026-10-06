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
        guard let sample = monitor.latest else { return [] }
        var rows: [Row] = []
        switch sample.link {
        case .wifi:
            let name = sample.wifi?.ssid ?? (location.isAuthorized ? "Hidden network" : "Unknown network")
            rows.append(Row(label: "Network", value: name))
            if let wifi = sample.wifi {
                rows.append(Row(label: "Signal", value: "\(wifi.rssi) dBm (\(Format.quality(wifi)))"))
                rows.append(Row(label: "Noise", value: "\(wifi.noise) dBm, SNR \(wifi.snr) dB"))
                rows.append(Row(label: "Transmit rate", value: "\(Int(wifi.txRate.rounded())) Mbps"))
                if let band = wifi.band {
                    let channel = wifi.channel.map { ", channel \($0)" } ?? ""
                    rows.append(Row(label: "Band", value: "\(band.label)\(channel)"))
                }
            }
        case .wired:
            rows.append(Row(label: "Network", value: "Wired"))
        case .none:
            return []
        }
        rows.append(Row(label: "Router", value: Format.probe(sample.router, unmeasured: "doesn't answer probes")))
        rows.append(Row(label: "Internet", value: Format.probe(sample.internet, unmeasured: "not measured")))
        return rows
    }
}

enum Format {
    static func probe(_ probe: Probe?, unmeasured: String) -> String {
        switch probe {
        case .reply(let ms): "\(Int(ms.rounded())) ms"
        case .lost: "no answer"
        case nil: unmeasured
        }
    }

    static func quality(_ wifi: WiFiReading) -> String {
        switch VerdictEngine.SignalQuality(rssi: wifi.rssi, snr: wifi.snr) {
        case .good: wifi.rssi >= -55 ? "excellent" : "good"
        case .fair: "fair"
        case .weak: "weak"
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
