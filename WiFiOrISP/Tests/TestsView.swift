import SwiftUI
import WiFiOrISPCore

/// Runs one test at a time and keeps the latest results.
@MainActor
final class TestsModel: ObservableObject {
    enum Running: Equatable {
        case speed(phase: String, mbps: Double)
        case lag(phase: String, fraction: Double)
    }

    @Published private(set) var running: Running?
    @Published private(set) var speed: SpeedTestResult?
    @Published private(set) var lag: ResponsivenessResult?
    @Published private(set) var error: String?

    private let monitor: MonitorController

    init(monitor: MonitorController) {
        self.monitor = monitor
        let store = monitor.store
        Task {
            let events = await Task.detached {
                store.load(from: Date().addingTimeInterval(-30 * 86400), to: Date()).events
            }.value
            // Newest first, and never over a result from a test run while this loaded.
            for event in events.reversed() {
                switch event.kind {
                case .speedTest(let result): speed = speed ?? result
                case .responsiveness(let result): lag = lag ?? result
                default: break
                }
            }
        }
    }

    func runSpeedTest() {
        guard running == nil else { return }
        Preferences.acceptedMLabTerms = true
        start(.speed(phase: "Finding the nearest M-Lab server", mbps: 0))
        let client = NDT7Client(clientVersion: Bundle.main.version)
        Task {
            do {
                let result = try await client.run { phase, mbps in
                    Task { @MainActor in
                        guard case .speed = self.running else { return }
                        self.running = .speed(phase: Self.label(phase), mbps: mbps)
                    }
                }
                speed = result
                monitor.record(NetworkEvent(time: result.time, kind: .speedTest(result)))
            } catch {
                self.error = error.localizedDescription
            }
            finish()
        }
    }

    func runLagTest() {
        guard running == nil else { return }
        start(.lag(phase: ResponsivenessPhase.idle.rawValue, fraction: 0))
        // Probe the router on the port the monitor found it answering on, so idle and loaded match.
        let router = monitor.routerTarget
        let test = ResponsivenessTest(configURL: Preferences.responsivenessServer) {
            guard let router else { return nil }
            let timeout = ResponsivenessTest.loadedProbeTimeout
            return await TCPProbe.roundTrip(to: router.address, port: router.port, timeout: timeout)
        }
        Task {
            do {
                let result = try await test.run { phase, fraction in
                    Task { @MainActor in
                        guard case .lag = self.running else { return }
                        self.running = .lag(phase: phase.rawValue, fraction: fraction)
                    }
                }
                lag = result
                monitor.record(NetworkEvent(time: result.time, kind: .responsiveness(result)))
            } catch {
                self.error = error.localizedDescription
            }
            finish()
        }
    }

    private func start(_ state: Running) {
        error = nil
        running = state
        monitor.pause()
    }

    private func finish() {
        running = nil
        monitor.resume()
    }

    static func label(_ phase: SpeedTestPhase) -> String {
        switch phase {
        case .locating: "Finding the nearest M-Lab server"
        case .download: "Download"
        case .upload: "Upload"
        }
    }
}

struct TestsView: View {
    @ObservedObject var model: TestsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            speedSection
            Divider()
            lagSection
            if let error = model.error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        }
        .padding(20)
        .frame(width: 520)
    }

    private var speedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Speed").font(.title3.bold())
            Text("Measures download and upload speed against the nearest Measurement Lab (M-Lab) server. "
                + "M-Lab is a nonprofit research project that publishes every result, including your IP address, "
                + "as open data. That's the price of a free, independent test.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Link("About M-Lab's data policy", destination: URL(string: "https://www.measurementlab.net/privacy/")!)
                .font(.callout)

            if case .speed(let phase, let mbps) = model.running {
                ProgressView {
                    Text("\(phase)\(mbps > 0 ? ": \(Int(mbps.rounded())) Mbps" : "")").monospacedDigit()
                }
            } else {
                HStack {
                    Button(Preferences.acceptedMLabTerms ? "Run Speed Test" : "Agree and Run Speed Test") {
                        model.runSpeedTest()
                    }
                    .disabled(model.running != nil)
                    if let speed = model.speed {
                        Text("Last: \(ISPReport.mbps(speed.downloadMbps)) down, "
                            + "\(ISPReport.mbps(speed.uploadMbps)) up, "
                            + "\(speed.time.formatted(.relative(presentation: .named)))")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var lagSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lag under load").font(.title3.bold())
            Text("Fills your connection in both directions for about 15 seconds and measures how slow round trips get, "
                + "using the IETF responsiveness test. High lag under load (bufferbloat) is why video calls stutter "
                + "while something uploads. Uses a few hundred MB on a fast connection.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if case .lag(let phase, let fraction) = model.running {
                ProgressView(value: fraction) { Text(phase) }
            } else {
                Button("Test Lag Under Load") { model.runLagTest() }
                    .disabled(model.running != nil)
            }
            if let lag = model.lag {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(lag.headline).font(.headline)
                        Spacer()
                        Text("\(lag.rpm) RPM, \(lag.grade.rawValue)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Text(lag.detail)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(lag.time.formatted(date: .abbreviated, time: .shortened)), server \(lag.server)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

extension Bundle {
    var version: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }
}
