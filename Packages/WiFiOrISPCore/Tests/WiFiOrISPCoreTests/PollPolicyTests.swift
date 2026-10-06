import Foundation
import Testing
@testable import WiFiOrISPCore

struct PollPolicyTests {
    let good = Verdict(kind: .good, headline: "", short: nil, detail: "")
    let problem = Verdict(kind: .isp, headline: "", short: "ISP", detail: "")

    @Test func samplesFastWhileSomethingIsWrong() {
        var policy = PollPolicy()
        #expect(policy.interval(after: problem, now: now) == PollPolicy.fastest)
    }

    @Test func slowsDownTheLongerThingsStayFine() {
        var policy = PollPolicy()
        #expect(policy.interval(after: good, now: now) == PollPolicy.normal)
        #expect(policy.interval(after: good, now: now.addingTimeInterval(300)) == PollPolicy.relaxed)
        #expect(policy.interval(after: good, now: now.addingTimeInterval(900)) == PollPolicy.slowest)
    }

    @Test func aProblemResetsTheCalm() {
        var policy = PollPolicy()
        _ = policy.interval(after: good, now: now)
        _ = policy.interval(after: problem, now: now.addingTimeInterval(900))
        #expect(policy.interval(after: good, now: now.addingTimeInterval(901)) == PollPolicy.normal)
    }

    @Test func backsOffCoreWLANExponentially() {
        var policy = PollPolicy()
        #expect(policy.shouldReadWiFi(now: now))
        policy.wifiRead(succeeded: false, now: now)
        #expect(policy.wifiBackoff == 10)
        #expect(!policy.shouldReadWiFi(now: now.addingTimeInterval(5)))
        #expect(policy.shouldReadWiFi(now: now.addingTimeInterval(10)))
        policy.wifiRead(succeeded: false, now: now)
        policy.wifiRead(succeeded: false, now: now)
        #expect(policy.wifiBackoff == 40)
        for _ in 0..<10 { policy.wifiRead(succeeded: false, now: now) }
        #expect(policy.wifiBackoff == PollPolicy.maxWiFiBackoff)
        policy.wifiRead(succeeded: true, now: now)
        #expect(policy.shouldReadWiFi(now: now))
    }
}
