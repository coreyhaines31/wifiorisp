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
    /// Who made the router, and which provider the connection belongs to, for tailored advice.
    @Published private(set) var maker: RouterMaker?
    @Published private(set) var provider: Provider?
    @Published private(set) var speedTests: [SpeedTestResult] = []
    @Published private(set) var lag: ResponsivenessResult?
    private(set) var macSupports6GHz = false
    private var identifiedRouter: String?

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
        macSupports6GHz = WiFiReader().supports6GHz
        loadRecentTests()
        restartLoop()
    }

    /// What the advice is based on, right now.
    var adviceContext: AdviceContext {
        AdviceContext(
            verdict: verdict, latest: latest, macSupports6GHz: macSupports6GHz, maker: maker, provider: provider,
            plan: Preferences.plan, profile: Preferences.plan == nil ? nil : Preferences.profile,
            speedTests: speedTests, lag: lag
        )
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
        resetDetector()
        settlingUntil = Date().addingTimeInterval(PollPolicy.fastest)
        restartLoop()
    }

    func record(_ event: NetworkEvent) {
        try? store.append(event)
        remember(event)
    }

    private func remember(_ event: NetworkEvent) {
        switch event.kind {
        case .speedTest(let result): speedTests = Array((speedTests + [result]).suffix(10))
        case .responsiveness(let result): lag = result
        default: break
        }
    }

    private func loadRecentTests() {
        let store = store
        Task {
            let events = await Task.detached {
                store.load(from: Date().addingTimeInterval(-30 * 86400), to: Date()).events
            }.value
            events.forEach(remember)
        }
    }

    /// Looks up the router's maker and the provider once per router. The maker comes from the Mac's own
    /// address table; the provider takes one request to Cloudflare, skipped behind a VPN, where it
    /// would name the VPN instead.
    private func identifyNetworkIfNeeded() {
        guard let router = sampler.routerTarget?.address, router != identifiedRouter else { return }
        identifiedRouter = router
        maker = nil
        provider = nil
        Task {
            let mac = await Task.detached { GatewayHardware.macAddress(of: router) }.value
            maker = mac.flatMap(RouterMaker.lookup)
            guard Route.current()?.isTunnel != true else { return }
            provider = await Provider.detect()
        }
    }

    /// The router and the port the monitor found it answering on.
    var routerTarget: (address: String, port: UInt16)? { sampler.routerTarget }

    /// Called at quit, so a drop in progress gets an end in the log.
    func stop() {
        loop?.cancel()
        resetDetector()
    }

    /// Starts drop detection over, closing any drop in progress at the last measurement.
    private func resetDetector() {
        if let ended = detector.close(at: lastSampleTime) {
            try? store.append(ended)
        }
        detector = EventDetector()
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
        identifyNetworkIfNeeded()
        onChange?()
    }

    // MARK: - System events

    private func sleep() {
        asleep = true
        loop?.cancel()
    }

    private func wake() {
        asleep = false
        resetDetector()
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
