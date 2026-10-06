import Foundation
import Testing
@testable import WiFiOrISPCore

/// Builds samples ten seconds apart ending at `now`.
func samples(
    _ count: Int = 6,
    link: Link = .wifi,
    rssi: Int = -55,
    noise: Int = -92,
    router: Probe? = .reply(ms: 3),
    internet: Probe? = .reply(ms: 20),
    now: Date = Date(timeIntervalSince1970: 1_000_000)
) -> [Sample] {
    (0..<count).map { index in
        Sample(
            time: now.addingTimeInterval(Double(index - count + 1) * 10),
            link: link,
            wifi: link == .wifi ? WiFiReading(rssi: rssi, noise: noise, txRate: 400) : nil,
            router: router,
            internet: internet
        )
    }
}

let now = Date(timeIntervalSince1970: 1_000_000)

struct VerdictTests {
    @Test func measuresBeforeEnoughSamples() {
        #expect(VerdictEngine.evaluate([], now: now).kind == .measuring)
        #expect(VerdictEngine.evaluate(samples(2), now: now).kind == .measuring)
    }

    @Test func allGood() {
        let verdict = VerdictEngine.evaluate(samples(), now: now)
        #expect(verdict.kind == .good)
        #expect(verdict.short == nil)
        #expect(!verdict.isProblem)
    }

    @Test func slowInternetWithFastRouterIsTheISP() {
        let verdict = VerdictEngine.evaluate(samples(internet: .reply(ms: 180)), now: now)
        #expect(verdict.kind == .isp)
        #expect(verdict.headline == "Slow: ISP, not WiFi")
        #expect(verdict.side == .isp)
    }

    @Test func wiredSaysNetworkNotWiFi() {
        let verdict = VerdictEngine.evaluate(samples(link: .wired, internet: .reply(ms: 180)), now: now)
        #expect(verdict.headline == "Slow: ISP, not your network")
    }

    @Test func slowRouterWithWeakSignalIsTheSignal() {
        let list = samples(rssi: -80, router: .reply(ms: 90), internet: .reply(ms: 110))
        let verdict = VerdictEngine.evaluate(list, now: now)
        #expect(verdict.kind == .weakSignal)
        #expect(verdict.side == .yours)
    }

    @Test func slowRouterWithGoodSignalIsTheRouterOrChannel() {
        let verdict = VerdictEngine.evaluate(samples(router: .reply(ms: 90), internet: .reply(ms: 110)), now: now)
        #expect(verdict.kind == .localNetwork)
        #expect(verdict.headline == "Slow: WiFi or router, not ISP")
    }

    @Test func lowSNRCountsAsWeak() {
        let verdict = VerdictEngine.evaluate(samples(rssi: -60, noise: -70, router: .reply(ms: 90)), now: now)
        #expect(verdict.kind == .weakSignal)
    }

    @Test func routerLossIsYourSide() {
        var list = samples()
        list[1].router = .lost
        list[3].router = .lost
        #expect(VerdictEngine.evaluate(list, now: now).kind == .localNetwork)
    }

    @Test func internetLossWithHealthyRouterIsTheISP() {
        var list = samples()
        list[1].internet = .lost
        list[3].internet = .lost
        #expect(VerdictEngine.evaluate(list, now: now).kind == .isp)
    }

    @Test func outageWithRouterUpIsTheISP() {
        var list = samples()
        list[4].internet = .lost
        list[5].internet = .lost
        let verdict = VerdictEngine.evaluate(list, now: now)
        #expect(verdict.kind == .ispDown)
        #expect(verdict.headline == "Offline: ISP is down, WiFi is fine")
    }

    @Test func outageWithRouterDownIsYourSide() {
        var list = samples()
        for index in 4...5 {
            list[index].internet = .lost
            list[index].router = .lost
        }
        #expect(VerdictEngine.evaluate(list, now: now).kind == .routerUnreachable)
    }

    @Test func outageWithoutRouterProbesCantTell() {
        #expect(VerdictEngine.evaluate(samples(router: nil, internet: .lost), now: now).kind == .offline)
    }

    @Test func oneLostProbeIsNotAnOutage() {
        var list = samples()
        list[5].internet = .lost
        #expect(VerdictEngine.evaluate(list, now: now).kind == .good)
    }

    @Test func unmeasurableRouterHedges() {
        let verdict = VerdictEngine.evaluate(samples(router: nil, internet: .reply(ms: 200)), now: now)
        #expect(verdict.kind == .isp)
        #expect(verdict.headline == "Slow: likely ISP, not WiFi")
    }

    @Test func weakSignalButWorking() {
        #expect(VerdictEngine.evaluate(samples(rssi: -78), now: now).kind == .goodWeakSignal)
    }

    @Test func notConnected() {
        let verdict = VerdictEngine.evaluate(samples(link: .none, router: nil, internet: nil), now: now)
        #expect(verdict.kind == .notConnected)
    }

    @Test func ignoresStaleSamples() {
        let old = samples(internet: .reply(ms: 300), now: now.addingTimeInterval(-3600))
        #expect(VerdictEngine.evaluate(old, now: now).kind == .measuring)
    }

    @Test func detailCarriesTheNumbers() {
        let verdict = VerdictEngine.evaluate(samples(internet: .reply(ms: 180)), now: now)
        #expect(verdict.detail.hasPrefix("Your router answers in 3 ms, but the internet takes 180 ms."))
    }

    @Test func signalQualityThresholds() {
        #expect(VerdictEngine.SignalQuality(rssi: -50, snr: 40) == .good)
        #expect(VerdictEngine.SignalQuality(rssi: -67, snr: 40) == .fair)
        #expect(VerdictEngine.SignalQuality(rssi: -50, snr: 20) == .fair)
        #expect(VerdictEngine.SignalQuality(rssi: -75, snr: 40) == .weak)
    }
}

struct PlainLanguageTests {
    @Test func describesAGoodConnectionWithoutUnits() {
        let detail = VerdictEngine.evaluate(samples(rssi: -40), now: now).detail
        #expect(detail == "Your Wi-Fi signal is excellent, and your router and the internet both answer quickly.")
        #expect(!detail.contains("dBm"))
    }

    @Test func mentionsMissedChecks() {
        var list = samples(router: .reply(ms: 60))
        list[2].router = .lost
        #expect(VerdictEngine.evaluate(list, now: now).detail.contains("missing 17% of checks"))
    }

    @Test func words() {
        #expect(PlainLanguage.signal(rssi: -40, snr: 50) == "Excellent")
        #expect(PlainLanguage.signal(rssi: -62, snr: 30) == "Good")
        #expect(PlainLanguage.signal(rssi: -80, snr: 10) == "Weak")
        #expect(PlainLanguage.router(6) == .fast)
        #expect(PlainLanguage.router(90) == .slow)
        #expect(PlainLanguage.internet(15) == .fast)
        #expect(PlainLanguage.internet(90) == .okay)
        #expect(PlainLanguage.signalStrength(rssi: -37) == 1)
        #expect(PlainLanguage.signalStrength(rssi: -95) == 0)
    }
}

struct StatisticsTests {
    @Test func median() {
        #expect(Statistics.median([3, 1, 2]) == 2)
        #expect(Statistics.median([1, 2, 3, 4]) == 2.5)
        #expect(Statistics.median([]) == nil)
    }

    @Test func trimmedMeanDropsTheTop() {
        let values = Array(repeating: 10.0, count: 19) + [1000]
        #expect(Statistics.trimmedMean(values) == 10)
    }
}

struct ProbeCodingTests {
    @Test func roundTrips() throws {
        let data = try JSONEncoder().encode([Probe.reply(ms: 12.345), .lost])
        #expect(String(bytes: data, encoding: .utf8) == "[12.3,-1]")
        #expect(try JSONDecoder().decode([Probe].self, from: data) == [.reply(ms: 12.3), .lost])
    }
}
