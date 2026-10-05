import Foundation
import Testing
@testable import WiFiOrISPCore

struct EventDetectorTests {
    func sample(_ offset: Double, internet: Probe = .reply(ms: 20), router: Probe? = .reply(ms: 3), wifi: WiFiReading? = nil) -> Sample {
        Sample(
            time: now.addingTimeInterval(offset), link: .wifi,
            wifi: wifi ?? WiFiReading(rssi: -55, noise: -92, txRate: 400, channel: 36, band: .ghz5, ssid: "Home", bssid: "aa"),
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
        let weaker = WiFiReading(rssi: -72, noise: -92, txRate: 100, channel: 36, band: .ghz5, ssid: "Home", bssid: "bb")
        let events = detector.process(sample(40, wifi: weaker))
        #expect(events.count == 1)
        #expect(events.first?.kind == .roamed(fromBSSID: "aa", toBSSID: "bb", fromRSSI: -55, toRSSI: -72))
        #expect(events.first?.alertKind == .roamedWeaker)
    }

    @Test func roamingToAStrongerAccessPointIsLoggedButNotAlerted() {
        var detector = EventDetector()
        _ = detector.process(sample(0))
        let stronger = WiFiReading(rssi: -45, noise: -92, txRate: 800, channel: 36, band: .ghz5, ssid: "Home", bssid: "bb")
        let events = detector.process(sample(10, wifi: stronger))
        #expect(events.first?.alertKind == nil)
    }

    @Test func withoutBSSIDAChannelChangeCountsAsARoam() {
        var detector = EventDetector()
        _ = detector.process(sample(0, wifi: WiFiReading(rssi: -50, noise: -92, txRate: 400, channel: 36, band: .ghz5)))
        let events = detector.process(sample(10, wifi: WiFiReading(rssi: -50, noise: -92, txRate: 400, channel: 149, band: .ghz5)))
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
}
