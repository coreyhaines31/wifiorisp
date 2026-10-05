import Foundation
import Testing
@testable import WiFiOrISPCore

struct NDT7Tests {
    @Test func picksTheFirstSecureServer() throws {
        let json = """
        {"results":[{"machine":"mlab1","location":{"city":"Los Angeles","country":"US"},
        "urls":{"ws:///ndt/v7/download":"ws://a/download","wss:///ndt/v7/download":"wss://a/download?t=1",
        "wss:///ndt/v7/upload":"wss://a/upload?t=1"}}]}
        """
        let target = try #require(try NDT7Client.parseLocate(Data(json.utf8)))
        #expect(target.download.absoluteString == "wss://a/download?t=1")
        #expect(target.upload.absoluteString == "wss://a/upload?t=1")
        #expect(target.location == "Los Angeles, US")
    }

    @Test func noResultsMeansNoServer() throws {
        #expect(try NDT7Client.parseLocate(Data(#"{"results":[]}"#.utf8)) == nil)
    }

    @Test func readsServerMeasurements() {
        let message = #"{"TCPInfo":{"MinRTT":12000,"BytesReceived":125000000,"ElapsedTime":10000000}}"#
        let info = NDT7Client.decode(message)?.tcpInfo
        #expect(info?.minRTT == 12000)
        #expect(NDT7Client.mbps(bytes: info?.bytesReceived ?? 0, seconds: (info?.elapsedTime ?? 0) / 1_000_000) == 100)
    }
}

struct ResponsivenessTests {
    @Test func prefersHTTPSURLs() throws {
        let json = """
        {"version":1,"urls":{"small_download_url":"http://x/small","small_https_download_url":"https://x/small",
        "large_https_download_url":"https://x/large","https_upload_url":"https://x/up"}}
        """
        let config = try #require(ResponsivenessTest.Config.parse(Data(json.utf8)))
        #expect(config.small.absoluteString == "https://x/small")
        #expect(config.upload.absoluteString == "https://x/up")
        #expect(config.server == "x")
    }

    @Test func rejectsIncompleteConfig() {
        #expect(ResponsivenessTest.Config.parse(Data(#"{"urls":{}}"#.utf8)) == nil)
    }

    @Test func rpmAveragesForeignAndSelf() throws {
        // Foreign: (100 + 100 + 100) / 3 = 100 ms → 600 RPM. Self: 50 ms → 1200 RPM.
        let foreign = Array(repeating: ProbeTiming(tcp: 100, tls: 100, http: 100), count: 10)
        let rpm = try #require(ResponsivenessTest.rpm(foreign: foreign, selfHTTP: Array(repeating: 50, count: 10)))
        #expect(rpm == 900)
    }

    func result(
        rpm: Int, routerIdle: Double? = 5, routerLoaded: Double? = 8,
        internetIdle: Double = 15, internetLoaded: Double = 300
    ) -> ResponsivenessResult {
        ResponsivenessResult(
            time: now, rpm: rpm, idleLatencyMs: 20, loadedLatencyMs: 60000 / Double(rpm),
            routerIdleMs: routerIdle, routerLoadedMs: routerLoaded, internetIdleMs: internetIdle,
            internetLoadedMs: internetLoaded, downloadMbps: 300, uploadMbps: 30, server: "x"
        )
    }

    @Test func grades() {
        #expect(result(rpm: 150).grade == .low)
        #expect(result(rpm: 500).grade == .medium)
        #expect(result(rpm: 1500).grade == .high)
    }

    @Test func aQuickRouterPutsTheQueuePastIt() {
        let lagging = result(rpm: 200)
        #expect(lagging.queueLocation == .pastRouter)
        #expect(lagging.headline == "Lags under load: past your router (bufferbloat)")
    }

    @Test func aRouterSlowingWithTheInternetPutsTheQueueOnYourSide() {
        let lagging = result(rpm: 200, routerLoaded: 280)
        #expect(lagging.queueLocation == .yourSide)
        #expect(lagging.headline == "Lags under load: WiFi or router queue")
    }

    @Test func aBusyRouterAloneDoesNotCount() {
        // The router answers slowly, but forwarded traffic barely slowed.
        #expect(result(rpm: 200, routerLoaded: 400, internetLoaded: 25).queueLocation == .unknown)
    }

    @Test func unknownWithoutRouterProbes() {
        let lagging = result(rpm: 200, routerIdle: nil, routerLoaded: nil)
        #expect(lagging.queueLocation == .unknown)
        #expect(lagging.headline == "Lags under load")
    }

    @Test func highResponsivenessIsFine() {
        #expect(result(rpm: 1500).headline == "Low lag under load")
    }
}
