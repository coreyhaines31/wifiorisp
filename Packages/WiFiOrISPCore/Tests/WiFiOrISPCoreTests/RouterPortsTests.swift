import Foundation
import Testing
@testable import WiFiOrISPCore

struct RouterPortsTests {
    @Test func aLostRouterWithTheInternetUpMeansThePortIsFiltered() {
        var ports = RouterPorts()
        ports.use(router: "192.168.1.1")
        ports.discovered(port: 53, router: "192.168.1.1", now: now)
        #expect(ports.record(router: .lost, internet: .reply(ms: 20)) == nil)
        #expect(!ports.needsDiscovery(now: now))
        #expect(ports.record(router: .lost, internet: .reply(ms: 20)) == nil)
        #expect(ports.needsDiscovery(now: now))
    }

    @Test func bothLostIsARealLoss() {
        var ports = RouterPorts()
        ports.use(router: "192.168.1.1")
        #expect(ports.record(router: .lost, internet: .lost) == .lost)
    }

    @Test func retriesDiscoveryLater() {
        var ports = RouterPorts()
        ports.use(router: "10.0.0.1")
        ports.discovered(port: nil, router: "10.0.0.1", now: now)
        #expect(!ports.needsDiscovery(now: now.addingTimeInterval(60)))
        #expect(ports.needsDiscovery(now: now.addingTimeInterval(RouterPorts.retryAfter + 1)))
    }

    @Test func aNewRouterStartsOver() {
        var ports = RouterPorts()
        ports.use(router: "10.0.0.1")
        ports.discovered(port: 80, router: "10.0.0.1", now: now)
        ports.use(router: "192.168.0.1")
        #expect(ports.port == nil)
        #expect(ports.needsDiscovery(now: now))
    }
}
