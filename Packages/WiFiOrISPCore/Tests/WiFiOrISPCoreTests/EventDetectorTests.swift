import Foundation
import Testing
@testable import WiFiOrISPCore

struct EventDetectorTests {
    func reading(
        rssi: Int, channel: Int = 36, band: Band = .ghz5, ssid: String? = "Home", bssid: String? = "aa"
    ) -> WiFiReading {
        WiFiReading(rssi: rssi, noise: -92, txRate: 400, channel: channel, band: band, ssid: ssid, bssid: bssid)
    }

    func sample(
        _ offset: Double, internet: Probe = .reply(ms: 20), router: Probe? = .reply(ms: 3), wifi: WiFiReading? = nil
    ) -> Sample {
        Sample(
            time: now.addingTimeInterval(offset), link: .wifi,
            wifi: wifi ?? reading(rssi: -55),
            router: router, internet: internet
        )
    }

    @Test func twoLostProbesMakeADrop() {
        var detector = EventDetector()
        #expect(detector.process(sample(0)).isEmpty)
        #expect(detector.process(sample(10, internet: .lost)).isEmpty)
        let started = detector.process(sample(20, internet: .lost))
        #expect(started == [NetworkEvent(time: now.addingTimeInterval(10), kind: .dropStarted)])
        let ended = detector.process(sample(60))
        #expect(ended.first?.kind == .dropEnded(since: now.addingTimeInterval(10), routerAnswered: true))
        #expect(ended.first?.dropDuration == 50)
    }

    @Test func routerLostDuringADropIsYourSide() {
        var detector = EventDetector()
        _ = detector.process(sample(0, internet: .lost))
        _ = detector.process(sample(10, internet: .lost, router: .lost))
        let ended = detector.process(sample(20))
        #expect(ended.first?.kind == .dropEnded(since: now, routerAnswered: false))
    }

    @Test func oneLostProbeIsNotADrop() {
        var detector = EventDetector()
        #expect(detector.process(sample(0, internet: .lost)).isEmpty)
        #expect(detector.process(sample(10)).isEmpty)
    }

    @Test func roamingToAWeakerAccessPointAlerts() {
        var detector = EventDetector()
        for offset in 0..<4 {
            _ = detector.process(sample(Double(offset) * 10))
        }
        let weaker = reading(rssi: -72, bssid: "bb")
        let events = detector.process(sample(40, wifi: weaker))
        #expect(events.count == 1)
        #expect(events.first?.kind == .roamed(fromBSSID: "aa", toBSSID: "bb", fromRSSI: -55, toRSSI: -72))
        #expect(events.first?.alertKind == .roamedWeaker)
    }

    @Test func roamingToAStrongerAccessPointIsLoggedButNotAlerted() {
        var detector = EventDetector()
        _ = detector.process(sample(0))
        let stronger = reading(rssi: -45, bssid: "bb")
        let events = detector.process(sample(10, wifi: stronger))
        #expect(events.first?.alertKind == nil)
    }

    @Test func withoutBSSIDAChannelChangeCountsAsARoam() {
        var detector = EventDetector()
        _ = detector.process(sample(0, wifi: reading(rssi: -50, ssid: nil, bssid: nil)))
        let events = detector.process(sample(10, wifi: reading(rssi: -50, channel: 149, ssid: nil, bssid: nil)))
        #expect(events.first?.kind == .roamed(fromBSSID: nil, toBSSID: nil, fromRSSI: -50, toRSSI: -50))
    }

    @Test func fallingTo24GHzAlerts() {
        var detector = EventDetector()
        _ = detector.process(sample(0))
        let slow = WiFiReading(rssi: -60, noise: -92, txRate: 70, channel: 6, band: .ghz2, ssid: "Home", bssid: "aa")
        let events = detector.process(sample(10, wifi: slow))
        #expect(events.contains { $0.kind == .bandChanged(from: .ghz5, to: .ghz2) && $0.alertKind == .fellTo24GHz })
    }

    @Test func joiningAnotherNetworkIsNotARoam() {
        var detector = EventDetector()
        _ = detector.process(sample(0))
        let other = WiFiReading(rssi: -50, noise: -92, txRate: 400, channel: 6, band: .ghz2, ssid: "Cafe", bssid: "cc")
        #expect(detector.process(sample(10, wifi: other)).map(\.kind) == [.networkChanged(from: "Home", to: "Cafe")])
    }

    @Test func closingEndsAnOpenDrop() {
        var detector = EventDetector()
        _ = detector.process(sample(0, internet: .lost))
        _ = detector.process(sample(10, internet: .lost))
        let ended = detector.close(at: now.addingTimeInterval(10))
        #expect(ended?.kind == .dropEnded(since: now, routerAnswered: true))
        #expect(!detector.isDropped)
        #expect(detector.close(at: now) == nil)
    }
}
