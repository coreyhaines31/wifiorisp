import Foundation
import Testing
@testable import WiFiOrISPCore

struct AdviceTests {
    func context(
        _ list: [Sample], macSupports6GHz: Bool = false, maker: RouterMaker? = nil, provider: Provider? = nil,
        plan: Plan? = nil, profile: HomeProfile? = nil, speeds: [Double] = [], lag: ResponsivenessResult? = nil
    ) -> AdviceContext {
        AdviceContext(
            verdict: VerdictEngine.evaluate(list, now: now), latest: list.last, macSupports6GHz: macSupports6GHz,
            maker: maker, provider: provider, plan: plan, profile: profile,
            speedTests: speeds.map {
                SpeedTestResult(time: now, downloadMbps: $0, uploadMbps: 20, minRTTms: nil, server: "x")
            },
            lag: lag
        )
    }

    func lag(rpm: Int = 200, routerLoaded: Double = 8) -> ResponsivenessResult {
        ResponsivenessResult(
            time: now, rpm: rpm, idleLatencyMs: 20, loadedLatencyMs: 60000 / Double(rpm), routerIdleMs: 5,
            routerLoadedMs: routerLoaded, internetIdleMs: 15, internetLoadedMs: 300, downloadMbps: 300, uploadMbps: 30,
            server: "x"
        )
    }

    @Test func ispStepsNameTheProvider() {
        let steps = Advice.steps(context(samples(internet: .reply(ms: 200)), provider: Provider(asn: 7922)))
        #expect(steps.first == NextStep("Check Xfinity's outage page", .page("/why-is-my-xfinity-internet-slow")))
        #expect(steps.last?.action == .exportReport)
    }

    @Test func unknownProvidersGetGenericSteps() {
        let steps = Advice.steps(context(samples(internet: .reply(ms: 200)), provider: Provider(asn: 400391)))
        #expect(steps.first == NextStep("Check your provider's outage page", .page("/slow-internet")))
    }

    @Test func routerStepsLinkTheMakersGuide() {
        let steps = Advice.steps(context(samples(router: .reply(ms: 90)), maker: .eero))
        #expect(steps.first == NextStep("Restart your eero router", .page("/router-login/eero")))
        #expect(steps.count == 3)
    }

    @Test func weakSignalOn24GHzSuggests5GHz() {
        var list = samples(rssi: -80, router: .reply(ms: 90))
        list[list.count - 1].wifi?.band = .ghz2
        let titles = Advice.steps(context(list)).map(\.title)
        #expect(titles.contains("Join your router's 5 GHz network if it has one"))
    }

    @Test func goodConnectionSuggestsALagTestOnce() {
        #expect(Advice.steps(context(samples())).map(\.action) == [.runLagTest])
        #expect(Advice.steps(context(samples(), lag: lag(rpm: 1200))).isEmpty)
    }

    @Test func oldRouterHoldsBackANewMac() {
        var list = samples()
        list[list.count - 1].wifi?.generation = .wifi5
        #expect(Advice.ceilings(context(list, macSupports6GHz: true)).map(\.kind) == [.wifiGeneration])
        #expect(Advice.ceilings(context(list, macSupports6GHz: false)).isEmpty)
    }

    @Test func linkLimitedSpeed() {
        // Link 400 Mbps, tests reach ~250, plan is 1 Gbps.
        let ceilings = Advice.ceilings(context(samples(), plan: Plan(downMbps: 1000, upMbps: 40), speeds: [240, 260]))
        #expect(ceilings.map(\.kind).contains(.wifiLink))
    }

    @Test func noSmartQueueingOnAGateway() {
        let ceilings = Advice.ceilings(context(samples(), maker: .commscope, lag: lag()))
        #expect(ceilings.map(\.kind) == [.smartQueue])
        #expect(ceilings.first?.detail.hasPrefix("Your provider's gateway") == true)
    }

    @Test func routersWithSmartQueueingDontCount() {
        #expect(Advice.ceilings(context(samples(), maker: .eero, lag: lag())).isEmpty)
    }

    @Test func queueOnYourSideIsNotAGatewayProblem() {
        #expect(Advice.ceilings(context(samples(), maker: .commscope, lag: lag(routerLoaded: 280))).isEmpty)
    }

    @Test func planTooSmallForUploads() {
        let profile = HomeProfile(people: 4, videoCalls: true, gaming: false, streams4K: 1, bigUploads: true)
        let ceilings = Advice.ceilings(context(samples(), plan: Plan(downMbps: 500, upMbps: 20), profile: profile))
        #expect(ceilings.first?.kind == .plan)
        #expect(ceilings.first?.detail.contains("upload falls short") == true)
    }

    @Test func underdeliveringPlan() {
        let ceilings = Advice.ceilings(context(samples(), plan: Plan(downMbps: 500, upMbps: 20), speeds: [200, 220]))
        #expect(ceilings.first?.headline == "You're getting about 42% of your plan")
    }

    @Test func profileTargets() {
        let profile = HomeProfile(people: 3, videoCalls: true, gaming: true, streams4K: 2, bigUploads: false)
        #expect(profile.targetDownMbps == 100)
        #expect(profile.targetUpMbps == 9)
    }
}

struct HardwareTests {
    @Test func looksUpMakersByPrefix() {
        #expect(RouterMaker.lookup(mac: "4c:43:41:d7:ed:9d") == .calix)
        #expect(RouterMaker.lookup(mac: "4c:43:41:d7:ed:9") == .calix)
    }

    @Test func ignoresRandomizedAddresses() {
        #expect(RouterMaker.lookup(mac: "4e:43:41:d7:ed:9d") == nil)
    }

    @Test func parsesArpOutput() {
        let output = "? (192.168.1.1) at 4c:43:41:d7:ed:9d on en0 ifscope [ethernet]"
        #expect(GatewayHardware.parseMAC(output) == "4c:43:41:d7:ed:9d")
        #expect(GatewayHardware.parseMAC("192.168.1.1 (192.168.1.1) -- no entry") == nil)
    }

    @Test func namesWiFi6E() {
        let sixE = WiFiReading(rssi: -40, noise: -90, txRate: 2000, band: .ghz6, generation: .wifi6)
        let six = WiFiReading(rssi: -40, noise: -90, txRate: 800, band: .ghz5, generation: .wifi6)
        #expect(sixE.generationLabel == "Wi-Fi 6E")
        #expect(six.generationLabel == "Wi-Fi 6")
    }

    @Test func knowsMajorProviders() {
        #expect(Provider(asn: 20115).name == "Spectrum")
        #expect(Provider(asn: 400391).name == nil)
    }
}
