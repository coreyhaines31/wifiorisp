import AppKit
import Network
import WiFiOrISPCore

/// Runs the background measurements: samples on a pace set by `PollPolicy`, works out the
/// verdict, logs everything, and raises alerts.
@MainActor
final class MonitorController: ObservableObject {
    /// After waking or launching, Wi-Fi takes a moment to reconnect. Don't call that a drop.
    private static let settleTime: TimeInterval = 30
    /// Samples kept in memory for the verdict and the menu.
    private static let recentLimit = 120

    @Published private(set) var verdict = VerdictEngine.evaluate([], now: Date())
    @Published private(set) var latest: Sample?
    @Published private(set) var recent: [Sample] = []
    @Published private(set) var isPaused = false

    var onChange: (() -> Void)?

    let store = LogStore(directory: LogStore.defaultDirectory)
    private let sampler = Sampler()
    private let notifier = Notifier()
    private var policy = PollPolicy()
    private var detector = EventDetector()
    private var loop: Task<Void, Never>?
    private var settlingUntil = Date().addingTimeInterval(settleTime)
    private var pathMonitor: NWPathMonitor?
    private var lastSampleTime = Date.distantPast
    private var asleep = false

    func start() {
        store.prune(keepingDays: Preferences.keepDays)
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sleep() }
        }
        center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.wake() }
        }
        watchNetworkChanges()
        restartLoop()
    }

    /// Measures right away, for example when the menu opens. Never faster than the policy allows.
    func sampleSoon() {
        guard !isPaused, !asleep, Date().timeIntervalSince(lastSampleTime) >= PollPolicy.fastest else { return }
        restartLoop()
    }

    /// Stops background probes while a speed or lag test saturates the connection, so the
    /// test's own traffic isn't logged as slowness.
    func pause() {
        isPaused = true
        loop?.cancel()
    }

    func resume() {
        isPaused = false
        detector = EventDetector()
        settlingUntil = Date().addingTimeInterval(PollPolicy.fastest)
        restartLoop()
    }

    func record(_ event: NetworkEvent) {
        try? store.append(event)
    }

    // MARK: - Loop

    private func restartLoop() {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let wait = await tick()
                try? await Task.sleep(for: .seconds(wait))
            }
        }
    }

    private func tick() async -> TimeInterval {
        let now = Date()
        let readWiFi = policy.shouldReadWiFi(now: now)
        let result = await sampler.sample(readWiFi: readWiFi, now: now)
        guard !Task.isCancelled, !isPaused else { return PollPolicy.fastest }
        if readWiFi {
            policy.wifiRead(succeeded: !result.wifiReadFailed, now: now)
        }
        handle(result.sample)
        return policy.interval(after: verdict, now: now)
    }

    private func handle(_ sample: Sample) {
        lastSampleTime = sample.time
        latest = sample
        recent = Array((recent + [sample]).suffix(Self.recentLimit))
        try? store.append(sample)

        let settling = sample.time < settlingUntil
        for event in detector.process(sample) {
            // A "drop" while the network reconnects after sleep isn't one.
            if settling, event.alertKind == .drop { continue }
            try? store.append(event)
            notifier.handle(event, latest: sample)
            if event.alertKind != .drop {
                policy.reset()
            }
        }
        if settling && detector.isDropped {
            detector = EventDetector()
        }
        verdict = VerdictEngine.evaluate(recent, now: sample.time)
        onChange?()
    }

    // MARK: - System events

    private func sleep() {
        asleep = true
        loop?.cancel()
    }

    private func wake() {
        asleep = false
        detector = EventDetector()
        policy.reset()
        settlingUntil = Date().addingTimeInterval(Self.settleTime)
        if !isPaused {
            restartLoop()
        }
    }

    private func watchNetworkChanges() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.asleep else { return }
                self.policy.reset()
                self.sampleSoon()
            }
        }
        monitor.start(queue: .main)
        pathMonitor = monitor
    }
}
