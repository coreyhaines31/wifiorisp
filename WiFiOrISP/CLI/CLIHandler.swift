import Foundation
import WiFiOrISPCore

/// Answers the `wifiorisp` command from the running app, so it shares the app's history,
/// Location access, router and provider detection, and test results.
@MainActor
final class CLIHandler {
    /// How long `status` waits for the first readings after the app starts.
    private static let firstReadingTimeout: TimeInterval = 45

    private let monitor: MonitorController
    private let tests: TestsModel
    private let location: LocationAccess

    init(monitor: MonitorController, tests: TestsModel, location: LocationAccess) {
        self.monitor = monitor
        self.tests = tests
        self.location = location
    }

    func handle(_ request: CLIRequest, _ connection: CLIConnection) {
        switch request.action {
        case .status: status(connection)
        case .watch: watch(connection)
        case .speed: speed(connection)
        case .lag: lag(connection)
        }
    }

    private var current: CLIStatus {
        let ssid = monitor.latest?.wifi?.ssid
        return CLIStatus(
            context: monitor.adviceContext,
            networkName: ssid ?? (location.isAuthorized ? "Hidden network" : nil),
            paused: monitor.isPaused
        )
    }

    private var isMeasuring: Bool { monitor.verdict.kind == .measuring && !monitor.isPaused }

    private func status(_ connection: CLIConnection) {
        guard isMeasuring else {
            connection.send(CLIMessage(status: current))
            connection.close()
            return
        }
        connection.send(CLIMessage(progress: "Taking the first readings…"))
        var observer: UUID?
        let answer = { [weak self] in
            guard let self, let id = observer else { return }
            monitor.stopObserving(id)
            observer = nil
            connection.send(CLIMessage(status: current))
            connection.close()
        }
        observer = monitor.observeSamples { [weak self] in
            if self?.isMeasuring == false { answer() }
        }
        monitor.sampleSoon()
        Task {
            try? await Task.sleep(for: .seconds(Self.firstReadingTimeout))
            answer()
        }
    }

    private func watch(_ connection: CLIConnection) {
        guard connection.send(CLIMessage(status: current)) else { return }
        var observer: UUID?
        observer = monitor.observeSamples { [weak self] in
            guard let self, let id = observer else { return }
            if !connection.send(CLIMessage(status: current)) {
                monitor.stopObserving(id)
            }
        }
    }

    private func speed(_ connection: CLIConnection) {
        let started = tests.runSpeedTest(
            progress: { connection.send(CLIMessage(progress: $0)) },
            completion: { result in
                switch result {
                case .success(let speed): connection.send(CLIMessage(speed: speed))
                case .failure(let error): connection.send(CLIMessage(error: error.localizedDescription))
                }
                connection.close()
            }
        )
        if !started { busy(connection) }
    }

    private func lag(_ connection: CLIConnection) {
        let started = tests.runLagTest(
            progress: { connection.send(CLIMessage(progress: $0)) },
            completion: { result in
                switch result {
                case .success(let lag): connection.send(CLIMessage(lag: CLILag(lag)))
                case .failure(let error): connection.send(CLIMessage(error: error.localizedDescription))
                }
                connection.close()
            }
        )
        if !started { busy(connection) }
    }

    private func busy(_ connection: CLIConnection) {
        connection.send(CLIMessage(error: "A speed or lag test is already running. Try again when it finishes."))
        connection.close()
    }
}
