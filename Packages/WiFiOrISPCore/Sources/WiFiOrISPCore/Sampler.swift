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

    /// The router and the port it answers on, for tests that probe it themselves.
    public var routerTarget: (address: String, port: UInt16)? {
        guard let address = routerPorts.router, let port = routerPorts.port else { return nil }
        return (address, port)
    }

    /// - Parameter readWiFi: false while CoreWLAN is backed off; the sample then has no Wi-Fi reading.
    public func sample(readWiFi: Bool = true, now: Date = Date()) async -> Result {
        let route = Route.current()
        let wifiInterface = wifiReader.interfaceName
        let wifiResult: WiFiReader.Result = readWiFi ? wifiReader.read() : .notAssociated
        let wifiReading: WiFiReading? = if case .reading(let reading) = wifiResult { reading } else { nil }

        // With a VPN up, the default route is the tunnel; traffic still rides Wi-Fi if Wi-Fi has a router.
        let wifiRouter = wifiInterface.flatMap(Route.router(for:))
        let overWiFi = route.map { $0.interface == wifiInterface || ($0.isTunnel && wifiRouter != nil) } ?? false
        let link: Link = if route != nil {
            overWiFi ? .wifi : .wired
        } else {
            wifiReading != nil ? .wifi : .none
        }
        let wifiReadFailed = readWiFi && wifiReading == nil && overWiFi

        guard link != .none else {
            return Result(sample: Sample(time: now, link: .none), wifiReadFailed: false)
        }

        let routerAddress = link == .wifi ? (wifiRouter ?? route?.router) : route?.router
        routerPorts.use(router: routerAddress)
        var discovery: UInt16??
        if routerPorts.needsDiscovery(now: now), let routerAddress {
            let port = await RouterPorts.discoverPort(router: routerAddress)
            discovery = .some(port)
            if let port {
                routerPorts.discovered(port: port, router: routerAddress, now: now)
            }
        }

        async let internet = Self.probeInternet()
        async let router = Self.probeRouter(routerAddress, port: routerPorts.port)
        let (internetProbe, routerProbe) = await (internet, router)
        // No port answered. If the internet answers, the router is ignoring probes: wait before
        // trying again. If it doesn't, the router may just be down right now, so try next sample.
        if case .some(.none) = discovery, !internetProbe.isLost, let routerAddress {
            routerPorts.discovered(port: nil, router: routerAddress, now: now)
        }
        let recordedRouter = routerProbe.flatMap { routerPorts.record(router: $0, internet: internetProbe) }

        return Result(
            sample: Sample(time: now, link: link, wifi: wifiReading, router: recordedRouter, internet: internetProbe),
            wifiReadFailed: wifiReadFailed
        )
    }

    /// The faster of the two targets; lost only if both are.
    nonisolated static func probeInternet(timeout: TimeInterval = 2) async -> Probe {
        await withTaskGroup(of: Probe.self) { group in
            for target in internetTargets {
                group.addTask { await TCPProbe.roundTrip(to: target, port: internetPort, timeout: timeout) }
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
