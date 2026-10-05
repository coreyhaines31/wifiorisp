import Foundation

/// Takes one sample: reads Wi-Fi, then probes the router and the internet at the same moment.
@MainActor
public final class Sampler {
    /// Two independent anycast resolvers, so one having a bad moment isn't blamed on the ISP.
    nonisolated public static let internetTargets = ["1.1.1.1", "8.8.8.8"]
    nonisolated public static let internetPort: UInt16 = 443

    public struct Result: Sendable {
        public var sample: Sample
        /// CoreWLAN gave no reading even though traffic goes over Wi-Fi, which means it's misbehaving.
        public var wifiReadFailed: Bool
    }

    private let wifiReader = WiFiReader()
    private var routerPorts = RouterPorts()

    public init() {}

    public var wifiInterfaceName: String? { wifiReader.interfaceName }

    /// - Parameter readWiFi: false while CoreWLAN is backed off; the sample then has no Wi-Fi reading.
    public func sample(readWiFi: Bool = true, now: Date = Date()) async -> Result {
        let route = Route.current()
        let wifiInterface = wifiReader.interfaceName
        let wifiResult: WiFiReader.Result = readWiFi ? wifiReader.read() : .notAssociated
        let wifiReading: WiFiReading? = if case .reading(let reading) = wifiResult { reading } else { nil }

        let link: Link
        if let route {
            if route.interface == wifiInterface {
                link = .wifi
            } else if route.isTunnel {
                link = wifiReading != nil ? .wifi : .wired
            } else {
                link = .wired
            }
        } else {
            link = wifiReading != nil ? .wifi : .none
        }
        let wifiReadFailed = readWiFi && wifiReading == nil && route != nil && route?.interface == wifiInterface

        guard link != .none else {
            return Result(sample: Sample(time: now, link: .none), wifiReadFailed: false)
        }

        var routerAddress = route?.router
        if link == .wifi, let wifiInterface {
            routerAddress = Route.router(for: wifiInterface) ?? routerAddress
        }
        routerPorts.use(router: routerAddress)
        if routerPorts.needsDiscovery(now: now), let routerAddress {
            let port = await RouterPorts.discoverPort(router: routerAddress)
            routerPorts.discovered(port: port, router: routerAddress, now: now)
        }

        async let internet = Self.probeInternet()
        async let router = Self.probeRouter(routerAddress, port: routerPorts.port)
        let (internetProbe, routerProbe) = await (internet, router)
        let recordedRouter = routerProbe.flatMap { routerPorts.record(router: $0, internet: internetProbe) }

        return Result(
            sample: Sample(time: now, link: link, wifi: wifiReading, router: recordedRouter, internet: internetProbe),
            wifiReadFailed: wifiReadFailed
        )
    }

    /// The faster of the two targets; lost only if both are.
    nonisolated static func probeInternet() async -> Probe {
        await withTaskGroup(of: Probe.self) { group in
            for target in internetTargets {
                group.addTask { await TCPProbe.roundTrip(to: target, port: internetPort) }
            }
            var best = Probe.lost
            for await probe in group {
                if let ms = probe.ms, ms < best.ms ?? .infinity {
                    best = probe
                }
            }
            return best
        }
    }

    nonisolated static func probeRouter(_ address: String?, port: UInt16?) async -> Probe? {
        guard let address, let port else { return nil }
        return await TCPProbe.roundTrip(to: address, port: port)
    }
}

/// Which TCP port the router answers on. A closed port still answers (with a reset), but
/// some routers silently drop probes on some ports, so try a few.
struct RouterPorts {
    static let candidates: [UInt16] = [53, 80, 443]
    /// After finding no answering port, try again this much later.
    static let retryAfter: TimeInterval = 600

    private(set) var router: String?
    private(set) var port: UInt16?
    private var discoveredAt: Date?
    private var suspectLosses = 0

    mutating func use(router: String?) {
        guard router != self.router else { return }
        self = RouterPorts()
        self.router = router
    }

    func needsDiscovery(now: Date) -> Bool {
        guard router != nil else { return false }
        guard let discoveredAt else { return true }
        return port == nil && now.timeIntervalSince(discoveredAt) > Self.retryAfter
    }

    mutating func discovered(port: UInt16?, router: String, now: Date) {
        guard router == self.router else { return }
        discoveredAt = now
        self.port = port
        suspectLosses = 0
    }

    static func discoverPort(router: String) async -> UInt16? {
        let probes = await withTaskGroup(of: (UInt16, Probe).self) { group in
            for candidate in Self.candidates {
                group.addTask { (candidate, await TCPProbe.roundTrip(to: router, port: candidate, timeout: 1)) }
            }
            return await group.reduce(into: [UInt16: Probe]()) { $0[$1.0] = $1.1 }
        }
        return candidates.first { probes[$0]?.isLost == false }
    }

    /// What to log for the router given both probes from the same moment.
    /// If the router "loses" a probe while the internet (which is reached through it) answers,
    /// the router is ignoring this port, not down: record nothing, and look for another port.
    mutating func record(router: Probe, internet: Probe) -> Probe? {
        guard router.isLost, !internet.isLost else {
            if !router.isLost { suspectLosses = 0 }
            return router
        }
        suspectLosses += 1
        if suspectLosses >= 2 {
            discoveredAt = nil
        }
        return nil
    }
}
